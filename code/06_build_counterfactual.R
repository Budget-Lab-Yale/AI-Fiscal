# Construct the counterfactual tax-units dataframe by combining baseline
# microdata, Step A labor shock, Step B capital allocation, and Step C
# realization. Output schema matches the baseline merged file so it can be
# read by the Tax-Simulator scenario-based pipeline.
#
# Tax-Simulator integration (see the "Building the counterfactual"
# section of docs/ai_fiscal_methodology.md):
#   1. build_counterfactual() produces a per-unit data.table for one
#      (variant, labor scenario, realization) cell.
#   2. write_counterfactual_scenario() drops the CSV into a sibling
#      scenario folder under the pinned Tax-Data vintage, mirroring the
#      other baseline files as symlinks so the Tax-Simulator parser can
#      read the scenario like any other Tax-Data ID.
#   3. write_runscript() emits a CSV that Tax-Simulator's main.R can
#      consume; each non-baseline row sets `dep.Tax-Data.ID` to the
#      scenario folder created in step 2.
#   4. Aggregate / difference per-unit liabilities downstream
#      (08_aggregate.R).

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

# Columns that scale uniformly with rho_i = YiL1 / YiL
.labor_scale_cols <- c(
  "wages", "wages1", "wages2",
  "ot", "ot1", "ot2",
  "tips", "tips1", "tips2", "tips_lh1", "tips_lh2",
  "sole_prop", "sole_prop1", "sole_prop2",
  "farm", "farm1", "farm2",
  "part_se", "part_se1", "part_se2"
)

# Reconstruct one passthrough sub-bucket (kind ∈ {scorp, part},
# status ∈ {active, passive}) given the SYZ-implied labor/capital split,
# the unit's labor scaling rho, and a capital flow share.
.update_passthrough <- function(pos, loss, cap_share, rho, flow) {
  net       <- pos - loss
  labor_new <- (1 - cap_share) * net * rho
  cap_new   <- cap_share * net + flow
  new_net   <- labor_new + cap_new
  list(pos = pmax(new_net, 0), loss = pmax(-new_net, 0))
}

# Add `add_ltcg` to dt$kg_lt and populate kg_lt_years_held / kg_lt_basis
# consistently. Tax-Simulator's calc_kg_cpi_ratio() requires both columns
# non-NA whenever kg_lt != 0; baseline has them NA for the ~62% of units
# with kg_lt == 0 (and non-NA for both kg_lt > 0 and kg_lt < 0 units), so
# units newly receiving gains need defaults. We use the baseline
# kg_lt-weighted means (treating new flows as having the same average
# holding period and basis ratio as existing realized LTCG). For units
# already with kg_lt > 0, holding period is a gain-weighted blend of old
# and default. Units that receive no new gains keep their baseline values
# (critical: do NOT blanket-set NA for new_kg <= 0, since that corrupts
# baseline loss units with kg_lt < 0).
#
# `yh_default` and `basis_ratio` are baseline-only constants; the
# orchestrator precomputes them via compute_baseline_cache() and passes
# them in so we don't recompute per cell.
.augment_kg_lt <- function(dt, add_ltcg, yh_default, basis_ratio) {
  old_kg <- dt$kg_lt
  old_yh <- dt$kg_lt_years_held
  old_b  <- dt$kg_lt_basis
  new_kg <- old_kg + add_ltcg

  yh <- fifelse(
    add_ltcg > 0 & old_kg > 0 & !is.na(old_yh),
    (old_yh * old_kg + yh_default * add_ltcg) / new_kg,
    fifelse(add_ltcg > 0, yh_default, old_yh)
  )
  basis <- fifelse(
    add_ltcg > 0,
    fifelse(is.na(old_b), 0, old_b) + basis_ratio * add_ltcg,
    old_b
  )

  dt[, kg_lt            := new_kg]
  dt[, kg_lt_years_held := yh]
  dt[, kg_lt_basis      := basis]
  dt
}

# Precompute baseline-only quantities reused across every cell:
#   - cap_holdings: per-unit positive capital holdings in each of the four
#     passthrough sub-buckets, used to allocate X_passthrough_ordinary.
#   - cap_holdings_total: row-wise sum of the four positive holdings.
#   - yh_default, basis_ratio: gain-weighted means used by .augment_kg_lt
#     to populate kg_lt_years_held / kg_lt_basis on units newly receiving
#     LTCG flow.
# All depend only on dt_baseline (= the post-SYZ-split table) and the
# SYZ passive capital share, so the orchestrator computes this once
# before the cell loop and passes it into build_counterfactual via
# `baseline_cache`. Tests / diagnostics pass NULL and we recompute
# inline. `params` supplies passthrough.passive_capital_share — the
# same parameter 01_load_data.R uses to build YiL/YiK, so the two
# stay in sync with the yaml.
compute_baseline_cache <- function(dt_baseline, params) {
  psh <- params$raw$passthrough$passive_capital_share
  cap_holdings <- list(
    scorp_active  = pmax(dt_baseline$scorp_active_cap_share *
                           dt_baseline$scorp_active_net, 0),
    scorp_passive = pmax(psh * (dt_baseline$scorp_passive -
                                  dt_baseline$scorp_passive_loss), 0),
    part_active   = pmax(dt_baseline$part_active_cap_share *
                           dt_baseline$part_active_net, 0),
    part_passive  = pmax(psh * (dt_baseline$part_passive -
                                  dt_baseline$part_passive_loss), 0)
  )
  cap_holdings_total <- Reduce(`+`, cap_holdings)

  mask        <- dt_baseline$kg_lt > 0 & !is.na(dt_baseline$kg_lt_years_held)
  yh_default  <- weighted.mean(dt_baseline$kg_lt_years_held[mask],
                               dt_baseline$kg_lt[mask])
  basis_ratio <- weighted.mean(dt_baseline$kg_lt_basis[mask] /
                                 dt_baseline$kg_lt[mask],
                               dt_baseline$kg_lt[mask])

  list(cap_holdings       = cap_holdings,
       cap_holdings_total = cap_holdings_total,
       yh_default         = yh_default,
       basis_ratio        = basis_ratio)
}

build_counterfactual <- function(dt_baseline, step_a_dt, step_b,
                                 params,
                                 flavor = c("both", "labor_only",
                                            "capital_only"),
                                 baseline_cache = NULL) {
  flavor        <- match.arg(flavor)
  apply_labor   <- flavor != "capital_only"
  apply_capital <- flavor != "labor_only"
  if (is.null(baseline_cache)) {
    baseline_cache <- compute_baseline_cache(dt_baseline, params)
  }

  dt <- copy(dt_baseline)
  # allocate_capital mutates its input in place (data.table convention),
  # so dt may carry leftover analytic columns. Drop them before merging
  # the per-unit flows back in to avoid name collisions.
  collide <- grep("^(X_|A_)", names(dt), value = TRUE)
  collide <- c(collide, intersect("exempt_share", names(dt)))
  if (length(collide)) dt[, (collide) := NULL]

  flows <- step_b[, .(id,
                      X_qualified_div, X_taxable_int, X_tax_exempt_int,
                      X_passthrough_ordinary,
                      X_ltcg_in_year = X_ltcg_V1,
                      X_pens_gross, X_pens_txbl,
                      X_ira_gross,  X_ira_txbl)]

  # Order-preserving update joins. merge(by = "id") would re-sort dt by
  # id, while baseline_cache and the direct dt_baseline$ column reads in
  # steps 2-3 below stay in file order — a silent per-unit row scramble
  # whenever the vintage CSV isn't already id-sorted. Update joins leave
  # dt in dt_baseline's row order, so the positional combination below
  # is correct by construction (tripwire asserted after the joins).
  if (anyDuplicated(step_a_dt$id) || anyDuplicated(flows$id)) {
    cli::cli_abort(c(
      "Duplicate {.field id} values in Step A / Step B inputs.",
      x = "Per-unit update joins would be ambiguous.",
      i = "Both tables must carry exactly one row per baseline tax unit."
    ))
  }
  dt[step_a_dt, on = "id", YiL1 := i.YiL1]
  flow_cols <- setdiff(names(flows), "id")
  dt[flows, on = "id",
     (flow_cols) := mget(paste0("i.", flow_cols))]
  if (!identical(dt$id, dt_baseline$id)) {
    cli::cli_abort(
      "Row order diverged from {.arg dt_baseline} after the update joins; positional contract broken."
    )
  }
  # Ids missing from step_a/step_b would otherwise leave NAs that
  # propagate silently into the written tax-units CSV.
  na_cols <- c("YiL1", flow_cols)
  na_hit  <- na_cols[vapply(dt[, ..na_cols], anyNA, logical(1))]
  if (length(na_hit)) {
    cli::cli_abort(c(
      "NA values after joining Step A / Step B outputs onto the baseline.",
      x = "Columns with NAs: {.field {na_hit}}.",
      i = "Some baseline {.field id}s are missing from the step tables (or the steps produced NAs)."
    ))
  }

  dt[, rho_i := fifelse(YiL != 0, YiL1 / YiL, 1)]

  # 1. Scale uniform-labor columns by rho_i (skip under capital_only).
  if (apply_labor) {
    for (col in .labor_scale_cols) {
      if (col %in% names(dt)) dt[, (col) := get(col) * rho_i]
    }
  }

  # 2. Allocate X_passthrough_ordinary across the four sub-buckets in
  #    proportion to baseline positive capital holdings. Under
  #    labor_only the capital flow to units is zero; under capital_only
  #    the labor side of passthrough is held at baseline (rho = 1).
  w     <- baseline_cache$cap_holdings
  w_tot <- baseline_cache$cap_holdings_total
  flow_share <- function(wi) {
    if (!apply_capital) return(rep(0, nrow(dt)))
    fifelse(w_tot > 0, dt$X_passthrough_ordinary * wi / w_tot, 0)
  }
  flow_sa <- flow_share(w$scorp_active)
  flow_sp <- flow_share(w$scorp_passive)
  flow_pa <- flow_share(w$part_active)
  flow_pp <- flow_share(w$part_passive)

  # Units with X_passthrough_ordinary != 0 but no positive baseline
  # holdings in any sub-bucket (w_tot == 0) have no allocation weights:
  # their flow is not written anywhere and the counterfactual undershoots
  # X_to_units by that mass. Surface it rather than dropping silently.
  if (apply_capital) {
    no_base <- w_tot <= 0 & dt$X_passthrough_ordinary != 0
    if (any(no_base)) {
      dropped_B <- sum(dt$weight[no_base] *
                         dt$X_passthrough_ordinary[no_base]) / 1e9
      cli::cli_warn(c(
        "Passthrough flow dropped for {sum(no_base)} unit{?s} with no positive baseline passthrough capital holdings.",
        x = sprintf("$%.4fB weighted flow not written to the counterfactual.",
                    dropped_B),
        i = "These units carry SCF {.field pass_throughs} wealth but no positive sub-bucket to receive the flow."
      ))
    }
  }

  # 3. Reconstruct passthrough columns. `psh` is the SYZ passive capital
  # share from the yaml — must match what compute_baseline_cache and
  # 01_load_data.R use.
  psh    <- params$raw$passthrough$passive_capital_share
  rho_pt <- if (apply_labor) dt$rho_i else 1
  sa <- .update_passthrough(dt_baseline$scorp_active,  dt_baseline$scorp_active_loss,
                            dt_baseline$scorp_active_cap_share, rho_pt, flow_sa)
  sp <- .update_passthrough(dt_baseline$scorp_passive, dt_baseline$scorp_passive_loss,
                            psh,                               rho_pt, flow_sp)
  pa <- .update_passthrough(dt_baseline$part_active,   dt_baseline$part_active_loss,
                            dt_baseline$part_active_cap_share, rho_pt, flow_pa)
  pp <- .update_passthrough(dt_baseline$part_passive,  dt_baseline$part_passive_loss,
                            psh,                               rho_pt, flow_pp)
  dt[, scorp_active       := sa$pos]
  dt[, scorp_active_loss  := sa$loss]
  dt[, scorp_passive      := sp$pos]
  dt[, scorp_passive_loss := sp$loss]
  dt[, part_active        := pa$pos]
  dt[, part_active_loss   := pa$loss]
  dt[, part_passive       := pp$pos]
  dt[, part_passive_loss  := pp$loss]

  # 4. Add pure-capital flows to PUF columns (skip under labor_only).
  if (apply_capital) {
    dt[, div_pref   := div_pref   + X_qualified_div]
    dt[, txbl_int   := txbl_int   + X_taxable_int]
    dt[, exempt_int := exempt_int + X_tax_exempt_int]
    dt <- .augment_kg_lt(dt, dt$X_ltcg_in_year,
                         baseline_cache$yh_default,
                         baseline_cache$basis_ratio)
    # R1 retirement cascade: X_pens_gross == X_pens_txbl and
    # X_ira_gross == X_ira_txbl (income-flow framing — no non-taxable
    # piece is modeled).
    dt[, gross_pens_dist := gross_pens_dist + X_pens_gross]
    dt[, txbl_pens_dist  := txbl_pens_dist  + X_pens_txbl]
    dt[, txbl_ira_dist   := txbl_ira_dist   + X_ira_txbl]
  }

  # Drop our analytic columns; restore baseline schema.
  drop_cols <- c("YiL", "YiK", "YiL1", "rho_i",
                 "scorp_active_net", "part_active_net",
                 "scorp_active_cap_share", "part_active_cap_share",
                 "rent_net", "estate_net",
                 "scorp_passive_net", "part_passive_net",
                 "X_qualified_div", "X_taxable_int", "X_tax_exempt_int",
                 "X_passthrough_ordinary", "X_ltcg_in_year",
                 "X_pens_gross", "X_pens_txbl",
                 "X_ira_gross",  "X_ira_txbl")
  drop_cols <- intersect(drop_cols, names(dt))
  dt[, (drop_cols) := NULL]

  setattr(dt, "counterfactual", list(
    realization_variant = "V1",
    labor_scenario      = attr(step_a_dt, "step_a")$scenario,
    shock_variant       = params$active_variant,
    flavor              = flavor,
    macro               = attr(step_b, "macro")
  ))
  dt
}

# Resolve the on-disk Tax-Data vintage path. Returns a list with `root`
# (parent directory containing all vintages, e.g. .../Tax-Data/v1),
# `vintage` (the pinned vintage folder name), and `path` (their join).
# Defaults to the project's data/tax_data symlink so the runscript is
# always pinned to whatever vintage the rest of the pipeline consumes.
tax_data_vintage <- function(symlink = "data/tax_data") {
  if (!file.exists(symlink)) {
    cli::cli_abort(c(
      "Tax-Data symlink not found.",
      x = "Looked for {.path {symlink}} relative to {.path {getwd()}}.",
      i = "Run from the project root, or pass an explicit {.arg symlink}."
    ))
  }
  resolved <- normalizePath(symlink, mustWork = TRUE)
  list(
    root    = dirname(resolved),
    vintage = basename(resolved),
    path    = resolved
  )
}

# Drop a counterfactual year into a sibling scenario folder under the
# pinned Tax-Data vintage. All files in baseline/ that are *not* the
# overridden year are mirrored as symlinks so the Tax-Simulator parser
# (which reads tax_units_2017.csv to seed sample IDs and may read other
# years if `years` spans them) sees an otherwise-identical Tax-Data ID.
# Returns the absolute scenario directory path.
write_counterfactual_scenario <- function(dt_cf, year, scenario_id,
                                          vintage_paths = tax_data_vintage(),
                                          overwrite     = FALSE) {
  baseline_dir <- file.path(vintage_paths$path, "baseline")
  if (!dir.exists(baseline_dir)) {
    cli::cli_abort(c(
      "Baseline Tax-Data folder not found.",
      x = "Looked for {.path {baseline_dir}}.",
      i = "Confirm the pinned vintage has a {.path baseline/} subfolder."
    ))
  }
  scenario_dir <- file.path(vintage_paths$path, scenario_id)
  override_csv <- sprintf("tax_units_%d.csv", year)

  if (dir.exists(scenario_dir) && !overwrite) {
    cli::cli_abort(c(
      "Scenario directory already exists: {.path {scenario_dir}}.",
      i = "Pass {.arg overwrite = TRUE} to replace, or choose a fresh {.arg scenario_id}."
    ))
  }
  dir.create(scenario_dir, recursive = TRUE, showWarnings = FALSE)

  for (f in list.files(baseline_dir, full.names = FALSE)) {
    if (f == override_csv) next
    target <- file.path(baseline_dir, f)
    link   <- file.path(scenario_dir, f)
    unlink(link, force = TRUE)
    ok <- file.symlink(target, link)
    if (!isTRUE(ok)) {
      cli::cli_abort(c(
        "Failed to symlink {.path {f}} into the scenario folder.",
        x = "{.path {link}} -> {.path {target}}.",
        i = "On Windows, {.fn file.symlink} needs Developer Mode or admin rights; otherwise Tax-Simulator would fail much later on the missing baseline files."
      ))
    }
  }

  fp <- file.path(scenario_dir, override_csv)
  fwrite(dt_cf, fp)
  scenario_dir
}

# Per-unit factor-channel sidecar for the ATR-by-decile aggregator
# (see 08_aggregate.R::build_atr_decile). Lives next to the cf
# tax_units file in `scenario_dir`. Carries the analytic columns
# build_counterfactual consumes-and-discards before writing the
# Tax-Simulator-facing tax_units CSV.
#
# Columns:
#   id              join key (matches Tax-Simulator detail/<year>.csv)
#   dL_unit         YiL1 - YiL on the labor side; zero under capital_only
#   X_gross_unit    gross capital-flow allocation, $; zero under
#                   labor_only. Scaled from step_b$X_i by
#                   macro$X / macro$X_to_units — identically 1 today
#                   because compute_macro_targets sets X_to_units = X
#                   (CIT wedge is off-microsim). The scaling is kept so
#                   a future macro-vs-distributed split (e.g. a v2
#                   retention/payout stage) flows through unchanged.
#   dY_factor_unit  convenience: dL_unit + X_gross_unit
#
# `flavor` zeros out the channel turned off in build_counterfactual so
# the sidecar matches the cf microsim Tax-Simulator actually saw.
write_factor_channels <- function(dt_baseline, step_a_dt, step_b,
                                  year, scenario_dir,
                                  flavor = c("both", "labor_only",
                                             "capital_only")) {
  flavor        <- match.arg(flavor)
  apply_labor   <- flavor != "capital_only"
  apply_capital <- flavor != "labor_only"

  macro       <- attr(step_b, "macro")
  scale_gross <- if (isTRUE(macro$X_to_units > 0)) {
    macro$X / macro$X_to_units
  } else 0

  channels <- data.table(id = dt_baseline$id, YiL_base = dt_baseline$YiL)
  channels <- merge(channels, step_a_dt[, .(id, YiL1)],
                    by = "id", all.x = TRUE)
  channels <- merge(channels, step_b[, .(id, X_i)],
                    by = "id", all.x = TRUE)
  channels[is.na(YiL1), YiL1 := YiL_base]
  channels[is.na(X_i),  X_i  := 0]

  channels[, dL_unit      := if (apply_labor)   YiL1 - YiL_base else 0]
  channels[, X_gross_unit := if (apply_capital) X_i * scale_gross else 0]
  channels[, dY_factor_unit := dL_unit + X_gross_unit]

  out <- channels[, .(id, dL_unit, X_gross_unit, dY_factor_unit)]
  fp  <- file.path(scenario_dir, sprintf("factor_channels_%d.csv", year))
  fwrite(out, fp)
  fp
}

# Encoded scenario ID: ai_<variant>_<share_mode>_<labor>_<realization>,
# e.g. ai_M_R_S0_V1 (Moderate shock, reallocating factor shares) and
# ai_M_F_S0_V1 (same shock with the labor-capital share held at baseline).
ai_fiscal_scenario_id <- function(variant, share_mode, labor_scenario,
                                  realization) {
  sprintf("ai_%s_%s_%s_%s", variant, share_mode, labor_scenario, realization)
}

# One row of a Tax-Simulator runscript. `tax_data_id` and `tax_data_vintage`
# point at the Tax-Data folder this scenario should consume; defaults
# match the pinned baseline. Use NA for unset optional columns.
runscript_row <- function(id,
                          tax_data_id      = "baseline",
                          tax_data_vintage = tax_data_vintage()$vintage,
                          tax_law          = "baseline",
                          behavior         = NA_character_,
                          years            = "2029:2030",
                          dist_years       = NA_character_,
                          mtr_vars         = NA_character_,
                          mtr_types        = NA_character_) {
  row <- data.frame(
    ID         = id,
    tax_law    = tax_law,
    behavior   = behavior,
    years      = years,
    dist_years = dist_years,
    mtr_vars   = mtr_vars,
    mtr_types  = mtr_types,
    check.names      = FALSE,
    stringsAsFactors = FALSE
  )
  row[["dep.Tax-Data.vintage"]] <- tax_data_vintage
  row[["dep.Tax-Data.ID"]]      <- tax_data_id
  row
}

# Concatenate runscript rows and write as a CSV at `path`. The first row
# should be the baseline scenario (Tax-Simulator treats `ID = "baseline"`
# as reserved). Returns the path written.
#
# Creates `dirname(path)` only if its own parent already exists — i.e.
# at most one missing leaf level — so a typo or missing Tax-Simulator
# tree can't silently materialize a multi-level phantom path.
write_runscript <- function(rows, path) {
  rs    <- do.call(rbind, rows)
  pdir  <- dirname(path)
  ppdir <- dirname(pdir)
  if (!dir.exists(pdir)) {
    if (!dir.exists(ppdir)) {
      cli::cli_abort(c(
        "Cannot write runscript: parent of {.path {pdir}} does not exist.",
        x = "Looked for {.path {ppdir}}.",
        i = "Confirm the Tax-Simulator tree is at the expected location, or pass {.arg --runscript-path} to a path whose grandparent exists."
      ))
    }
    dir.create(pdir, recursive = FALSE, showWarnings = TRUE)
  }
  fwrite(rs, path)
  path
}
