# Step B: allocate aggregate capital flow X across tax units and across
# income types, after the macro corporate-income-tax wedge.
#
# Pipeline:
#   1. Baseline aggregates from data: L0$, K0$, Y0$.
#   2. Apply normalized growth rates derived in 02_params.R to the data
#      baseline: K1$ = K0$ * (1 + gk),  X = K1$ - K0$ = K0$ * gk.
#   3. Macro CIT wedge (acts upstream of household realizations):
#        cbo_cit_baseline$ = cit_to_gdp_baseline_year * gdp_baseline_year_B$
#        eta_corp          = cit_statutory * K0$ * kappa_corp / cbo_cit_baseline$
#        delta_R_CIT       = cit_statutory * kappa_corp * X / eta_corp
#                          ≡ X * cbo_cit_baseline$ / K0$            (algebraic)
#        X_to_units        = X                                       (no reduction)
#      eta absorbs both the household-realized-vs-pre-realization wedge
#      and the statutory-vs-effective gap.
#   4. Across units: X_i proportional to A_i (sum of all-assets wealth
#      columns for unit i).
#   5. Within unit: distribute X_i across the income-bearing asset classes
#      {equities, bonds, pass_throughs, retirement} only. Map to taxable
#      income types via config/asset_to_income_map.csv. Hard-coded
#      fixed-income tax-exempt split: per-unit exempt_int / (txbl_int +
#      exempt_int).
#   6. Retirement cascade (R4, income-flow). Pool the full retirement
#      slice (no r_R), route to units with positive baseline taxable
#      retirement income weighted by SCF retirement wealth, split into
#      taxable pension and taxable IRA only. See
#      apply_retirement_cascade() and the "Retirement flow treatment"
#      section of docs/ai_fiscal_methodology.md.
#
# Realization (V1 mechanical) is applied downstream in 05_realization.R.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

# Taxable retirement-distribution columns used by the R4 cascade. R4's
# receiving set is conditioned on positive YiK retirement income.
.RETIREMENT_TXBL_DIST_COLS <- c("txbl_ira_dist", "txbl_pens_dist")

allocate_capital <- function(dt, params,
                             asset_map_path = "config/asset_to_income_map.csv") {
  macro <- compute_macro_targets(dt, params)
  dt    <- allocate_across_units(dt, macro$X_to_units)
  dt    <- allocate_within_unit(dt)
  out   <- map_to_income_types(dt, asset_map_path, params)

  setattr(out, "macro", c(macro, list(
    total_base       = attr(dt, "total_base"),
    retirement_F     = attr(out, "retirement_F"),
    syz_W_star       = attr(dt, "syz_W_star"),
    kappa_corp       = params$raw$corporate$kappa_corp,
    cit_statutory    = params$raw$corporate$cit_statutory
  )))
  out
}

# 1-3. Compute baseline aggregates ($), apply (gk, alpha) growth rates, and
# split off the macro corporate-tax wedge.
compute_macro_targets <- function(dt, params) {
  corp <- params$raw$corporate
  cbo  <- params$raw$cbo_baseline

  L0_dollar <- sum(dt$weight * dt$YiL)
  K0_dollar <- sum(dt$weight * dt$YiK)
  Y0_dollar <- L0_dollar + K0_dollar
  K1_dollar <- K0_dollar * (1 + params$gk)
  L1_dollar <- L0_dollar * (1 + params$alpha * params$gk)
  Y1_dollar <- K1_dollar + L1_dollar
  X         <- K1_dollar - K0_dollar

  cbo_cit_baseline_dollar <- cbo$cit_to_gdp_baseline_year *
    cbo$gdp_baseline_year_B * 1e9
  if (cbo_cit_baseline_dollar <= 0) {
    cli::cli_abort(c(
      "CBO baseline CIT anchor is non-positive.",
      x = "{.code cit_to_gdp_baseline_year * gdp_baseline_year_B * 1e9 = {cbo_cit_baseline_dollar}}.",
      i = "Check {.field cbo_baseline.cit_to_gdp_baseline_year} and {.field cbo_baseline.gdp_baseline_year_B} in {.path config/scenario_params.yaml}."
    ))
  }
  eta_corp <- corp$cit_statutory * K0_dollar * corp$kappa_corp /
    cbo_cit_baseline_dollar
  delta_R_CIT <- corp$cit_statutory * corp$kappa_corp * X / eta_corp
  X_to_units  <- X

  list(
    L0_dollar = L0_dollar, K0_dollar = K0_dollar, Y0_dollar = Y0_dollar,
    K1_dollar = K1_dollar, L1_dollar = L1_dollar, Y1_dollar = Y1_dollar,
    X = X,
    cbo_cit_baseline_dollar = cbo_cit_baseline_dollar,
    eta_corp                = eta_corp,
    delta_R_CIT             = delta_R_CIT,
    X_to_units              = X_to_units
  )
}

# Step 4: distribute X_to_units across tax units in proportion to total
# wealth (all-assets base).
allocate_across_units <- function(dt, X_to_units) {
  base_cols <- .ASSET_BASE_ALL_ASSETS
  missing   <- setdiff(base_cols, names(dt))
  if (length(missing)) {
    cli::cli_abort(c(
      "Missing asset columns on input.",
      x = "Not found: {.field {missing}}.",
      i = "Check the merged-file schema; the loader normalizes {.code value.*} prefixes."
    ))
  }

  dt[, A_base := rowSums(.SD), .SDcols = base_cols]
  total_base <- sum(dt$weight * dt$A_base)
  if (total_base <= 0) {
    cli::cli_abort(c(
      "Weighted asset base is non-positive.",
      x = "{.code sum(weight * A_base) = {total_base}}.",
      i = "Cannot allocate {.var X_to_units} proportionally to a zero base."
    ))
  }
  dt[, X_i := X_to_units * A_base / total_base]
  setattr(dt, "total_base", total_base)
  dt
}

# Step 5a: distribute X_i across income-bearing asset classes only. Units
# with no income-bearing holdings get their residual routed to retirement
# (deferred) so that sum_i w_i * X_i is preserved. Under the all-assets
# base X_i is always non-negative.
allocate_within_unit <- function(dt) {
  inc_cols <- unname(.INCOME_BEARING_COLS)
  # Clamp per-class holdings at zero before computing proportional
  # shares: a handful of SCF-imputed `pass_throughs` rows carry small
  # negative values (artifact of the donor-pool blend).
  pos_mat <- as.matrix(dt[, ..inc_cols])
  pos_mat[pos_mat < 0] <- 0
  dt[, A_inc := rowSums(pos_mat)]
  for (cls in names(.INCOME_BEARING_COLS)) {
    col <- .INCOME_BEARING_COLS[[cls]]
    pos_col <- pos_mat[, col]
    dt[, (paste0("X_", cls)) := fifelse(A_inc > 0, X_i * pos_col / A_inc, 0)]
  }

  dt[, X_residual := X_i - (X_public_equity_taxable + X_fixed_income +
                            X_passthrough_equity + X_retirement_dc_ira)]
  dt[, X_retirement_dc_ira := X_retirement_dc_ira + X_residual]
  dt[, X_residual := NULL]
  dt
}

# Step 5b: map per-unit asset-class flows to taxable income types using
# the share table at `asset_map_path`. Retirement flow follows the R4
# income-flow cascade. Returns a slim output table with id, weight, and
# X_<type>.
map_to_income_types <- function(dt, asset_map_path, params) {
  amap <- fread(asset_map_path)
  pe <- lookup_shares(amap, "public_equity_taxable")
  pt <- lookup_shares(amap, "passthrough_equity")

  dt[, X_qualified_div := X_public_equity_taxable * pe$qualified_dividend]
  dt[, X_ltcg_gross    := X_public_equity_taxable * pe$ltcg]

  dt[, exempt_share := fifelse((txbl_int + exempt_int) > 0,
                               exempt_int / (txbl_int + exempt_int),
                               0)]
  dt[, X_tax_exempt_int := X_fixed_income * exempt_share]
  dt[, X_taxable_int    := X_fixed_income * (1 - exempt_share)]

  dt[, X_passthrough_ordinary := X_passthrough_equity *
       pt$passthrough_ordinary]

  apply_retirement_cascade_R4(dt, params)

  out_cols <- c("id", "weight",
                "X_i", "X_qualified_div", "X_taxable_int", "X_tax_exempt_int",
                "X_ltcg_gross", "X_passthrough_ordinary",
                "X_pens_gross", "X_pens_txbl",
                "X_ira_gross",  "X_ira_txbl")
  out <- dt[, ..out_cols]
  setattr(out, "retirement_F", attr(dt, "retirement_F"))
  out
}

# R4 = income-flow cascade. X_retirement_dc_ira is itself the increment
# to realized taxable retirement income (no r_R conversion — X = gk · K0
# is already built from a YiK base that includes realized, taxable
# distributions, so the baseline realization rate is already encoded).
# Pool the retirement slice and route to units with positive baseline
# taxable pension or IRA distributions, weighted by SCF retirement
# wealth. Split into the two YiK retirement components using the
# baseline taxable composition.
apply_retirement_cascade_R4 <- function(dt, params) {
  cal <- params$retirement_cal
  needed <- c(.RETIREMENT_TXBL_DIST_COLS, "retirement")
  missing <- setdiff(needed, names(dt))
  if (length(missing)) {
    cli::cli_abort(c(
      "R4 requires baseline taxable-distribution columns and SCF retirement wealth.",
      x = "Not found: {.field {missing}}.",
      i = "Taxable cols are Form 1040 lines 4b/5b-equivalent; {.field retirement} is the SCF DC/IRA balance column."
    ))
  }

  # Pool the entire retirement slice. The whole amount flows out as
  # taxable distributions on the receiving set.
  F_total <- sum(dt$weight * dt$X_retirement_dc_ira)

  # Receiving set: positive YiK retirement income.
  txbl_dist  <- dt[, rowSums(.SD), .SDcols = .RETIREMENT_TXBL_DIST_COLS]
  has_dist   <- txbl_dist > 0
  ret_wealth <- dt$retirement
  denom      <- sum(dt$weight[has_dist] * ret_wealth[has_dist])
  if (denom <= 0) {
    cli::cli_abort(c(
      "R4 cascade has no qualifying receivers (wealth × taxable-distribution mass = 0).",
      x = "{.code sum(weight * retirement, where = txbl_pens_dist + txbl_ira_dist > 0) = {denom}}.",
      i = "Check the merged baseline for tax-unit retirement wealth and taxable distributions."
    ))
  }
  dt[, F_i := fifelse(has_dist, F_total * ret_wealth / denom, 0)]

  # Taxable-only pension/IRA split derived from calibration.
  T_P <- cal$s_P * cal$tau_P
  T_I <- cal$s_I * cal$tau_I
  if ((T_P + T_I) <= 0) {
    cli::cli_abort(c(
      "R4 calibration produces a zero taxable-share denominator.",
      x = "{.code s_P*tau_P + s_I*tau_I = {T_P + T_I}}.",
      i = "Check {.path config/retirement_calibration.yaml} for sensible nonzero {.field s_P, s_I, tau_P, tau_I}."
    ))
  }
  t_P <- T_P / (T_P + T_I)
  t_I <- T_I / (T_P + T_I)

  # Under R4 the gross and taxable PUF columns both go up by the same
  # amount (no non-taxable piece is modeled).
  dt[, X_pens_txbl  := t_P * F_i]
  dt[, X_pens_gross := X_pens_txbl]
  dt[, X_ira_txbl   := t_I * F_i]
  dt[, X_ira_gross  := X_ira_txbl]
  dt[, F_i := NULL]

  setattr(dt, "retirement_F", F_total)
  invisible(dt)
}

# Pull a named list of {income_type: share} for a given asset class out
# of the asset_to_income_map.csv table.
lookup_shares <- function(amap, class_name) {
  sub <- amap[asset_class == class_name]
  setNames(as.list(sub$share), sub$income_type)
}
