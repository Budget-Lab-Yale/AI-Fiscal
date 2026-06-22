# Aggregate Tax-Simulator output into deliverable tables: ΔR by
# instrument and after-tax income deltas by decile. Inputs are the
# Tax-Simulator output vintage (one timestamped folder containing
# baseline + counterfactual scenario subfolders) and the runscript that
# produced it.
#
# The CIT delta is computed in 04_allocate_capital.R from the macro
# wedge — Tax-Simulator does not modify revenues_corp_tax in our runs.
# To assemble a complete ΔR row, take revenue_deltas$delta where
# instrument == "total" and add the macro CIT delta from
# attr(step_b, "macro")$dR_CIT.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")
source("code/06_build_counterfactual.R")  # tax_data_vintage()

# Resolve the latest Tax-Simulator output vintage under a scratch root.
# `scratch_root` must be supplied or set via the AI_FISCAL_SCRATCH_ROOT
# env var; there is no built-in default — point this at the scratch
# directory configured in your local Tax-Simulator output_roots.yaml.
latest_tax_sim_vintage <- function(
  scratch_root = Sys.getenv("AI_FISCAL_SCRATCH_ROOT", unset = ""),
  version      = "v1"
) {
  if (!nzchar(scratch_root)) {
    cli::cli_abort(c(
      "{.arg scratch_root} not provided and {.envvar AI_FISCAL_SCRATCH_ROOT} not set.",
      i = "Set {.envvar AI_FISCAL_SCRATCH_ROOT} to the scratch root your Tax-Simulator output_roots.yaml writes into."
    ))
  }
  parent <- file.path(scratch_root, "model_data", "Tax-Simulator", version)
  if (!dir.exists(parent)) {
    cli::cli_abort(c(
      "No Tax-Simulator output dir at {.path {parent}}.",
      i = "Run {.run Rscript code/00_ai_fiscal_sim.R} then Tax-Simulator first."
    ))
  }
  vintages <- list.dirs(parent, recursive = FALSE, full.names = FALSE)
  if (!length(vintages)) {
    cli::cli_abort(c(
      "No vintages under {.path {parent}}.",
      i = "Run Tax-Simulator at least once."
    ))
  }
  file.path(parent, sort(vintages, decreasing = TRUE)[1])
}

# Decomposition helpers: extract the flavor suffix (from the registry
# in 00_utils.R) from scenario IDs produced under --decomp. IDs without
# a suffix are the canonical "both" flavor. IDs that are neither
# baseline, nor a canonical grid ID, nor a canonical ID plus a
# registered suffix ABORT: before this check, an unregistered suffix
# (e.g. a future `_KO`) was silently classified "both" and aggregated
# as a canonical cell.
.scenario_flavor <- function(scenario_ids, baseline_id = "baseline") {
  base    <- sub(.flavor_suffix_regex(), "", scenario_ids)
  unknown <- scenario_ids[
    scenario_ids != baseline_id & !grepl(.scenario_id_regex(), base)
  ]
  if (length(unknown)) {
    cli::cli_abort(c(
      "Scenario ID{?s} {.val {unknown}} not recognized by the axis registry.",
      x = "Neither {.val {baseline_id}}, nor a canonical grid ID, nor canonical + a registered flavor suffix ({.val {names(.FLAVOR_SUFFIX_MAP)}}).",
      i = "Register new axis codes / suffixes in {.path code/00_utils.R} before aggregating them."
    ))
  }
  m <- regmatches(scenario_ids, regexec(.flavor_suffix_regex(), scenario_ids))
  suffix <- vapply(m, function(parts) {
    if (length(parts) >= 2L) parts[2] else NA_character_
  }, character(1))
  fifelse(is.na(suffix), "both", unname(.FLAVOR_SUFFIX_MAP[suffix]))
}
.scenario_base <- function(scenario_ids) {
  sub(.flavor_suffix_regex(), "", scenario_ids)
}

# Subset of runscript IDs corresponding to canonical "both" scenarios
# (excluding baseline). Used by per-scenario aggregators that should
# return one row per cell regardless of whether --decomp is in effect.
.both_scenarios <- function(rs, baseline_id = "baseline") {
  ids <- setdiff(rs$ID, baseline_id)
  ids[.scenario_flavor(ids) == "both"]
}

read_receipts <- function(output_root, scenario_id, runtype = "static") {
  fp <- file.path(output_root, scenario_id, runtype, "totals", "receipts.csv")
  if (!file.exists(fp)) {
    cli::cli_abort(c(
      "{.path receipts.csv} missing for scenario {.val {scenario_id}}.",
      x = "Looked for {.path {fp}}.",
      i = "Did Tax-Simulator finish post-processing this scenario?"
    ))
  }
  dt <- fread(fp)
  if (!nrow(dt)) {
    cli::cli_abort(c(
      "{.path {fp}} is header-only.",
      i = "FY adjustment drops the earliest year — re-run with {.field years} >= 2 years."
    ))
  }
  dt
}

read_detail <- function(output_root, scenario_id, year, runtype = "static") {
  fp <- file.path(output_root, scenario_id, runtype, "detail",
                  sprintf("%d.csv", year))
  if (!file.exists(fp)) {
    cli::cli_abort(c(
      "Detail file missing.",
      x = "Looked for {.path {fp}}.",
      i = "Confirm {.val {year}} is in the runscript {.field years} range."
    ))
  }
  fread(fp)
}

# Long-form revenue-delta table for one year, comparing each non-baseline
# scenario in the runscript to baseline. One row per (scenario_id,
# instrument). `total` is the sum of all positive instruments minus
# outlays_tax_credits, matching Tax-Simulator's revenue_estimates.csv.
build_revenue_delta_table <- function(output_root, runscript_path, year,
                                      runtype = "static") {
  rs <- fread(runscript_path)
  baseline_id <- "baseline"
  if (!baseline_id %in% rs$ID) {
    cli::cli_abort(c(
      "Runscript missing {.field ID = {.val baseline}} row.",
      x = "{.path {runscript_path}}"
    ))
  }
  yr <- year  # avoid shadowing the `year` column inside data.table i-expressions

  baseline <- read_receipts(output_root, baseline_id, runtype)[year == yr]
  if (!nrow(baseline)) {
    cli::cli_abort("Baseline receipts.csv has no row for year {.val {yr}}.")
  }
  instruments <- setdiff(names(baseline), "year")

  # Skip flavor-suffixed scenarios under --decomp; they are aggregated
  # separately via build_revenue_decomp_table.
  scenarios <- .both_scenarios(rs, baseline_id)
  rows <- lapply(scenarios, function(sid) {
    cf <- read_receipts(output_root, sid, runtype)[year == yr]
    if (!nrow(cf)) {
      cli::cli_abort("Scenario {.val {sid}} receipts.csv has no row for year {.val {yr}}.")
    }
    per_instr <- data.table(
      scenario_id    = sid,
      instrument     = instruments,
      baseline       = unlist(baseline[, ..instruments], use.names = FALSE),
      counterfactual = unlist(cf[, ..instruments],       use.names = FALSE)
    )
    per_instr[, delta := counterfactual - baseline]

    bl_total <- .receipts_total(baseline)
    cf_total <- .receipts_total(cf)
    rbind(per_instr, data.table(
      scenario_id    = sid,
      instrument     = "total",
      baseline       = bl_total,
      counterfactual = cf_total,
      delta          = cf_total - bl_total
    ))
  })

  rbindlist(rows)
}

.receipts_total <- function(r) {
  r$revenues_payroll_tax + r$revenues_income_tax - r$outlays_tax_credits +
    r$revenues_corp_tax + r$revenues_estate_tax + r$revenues_vat +
    r$revenues_other
}

# Decompose ΔIIT (and other instruments) into labor / capital /
# interaction components, using the labor-only (LO) and capital-only
# (CO) Tax-Simulator runs that --decomp produces. Returns NULL when
# the runscript has no LO/CO scenarios (i.e. --decomp wasn't used).
#
# delta_labor       = T(LO)   − T(baseline)
# delta_capital     = T(CO)   − T(baseline)
# delta_both        = T(both) − T(baseline)
# interaction       = delta_both − delta_labor − delta_capital
#
# The interaction term captures non-linear effects of the joint shock
# (bracket creep, AMT, phase-outs); attributing it would require an
# economic assumption we don't make.
build_revenue_decomp_table <- function(output_root, runscript_path, year,
                                       runtype = "static") {
  rs <- fread(runscript_path)
  baseline_id <- "baseline"

  ids <- setdiff(rs$ID, baseline_id)
  if (!any(.scenario_flavor(ids) %in% c("labor_only", "capital_only"))) {
    return(invisible(NULL))
  }

  yr <- year
  baseline <- read_receipts(output_root, baseline_id, runtype)[year == yr]
  if (!nrow(baseline)) {
    cli::cli_abort("Baseline receipts.csv has no row for year {.val {yr}}.")
  }
  instruments <- setdiff(names(baseline), "year")

  # Each base cell needs all three flavors to decompose; warn and skip
  # any base that's missing one.
  flavors_per_base <- split(.scenario_flavor(ids), .scenario_base(ids))
  bases <- names(flavors_per_base)[vapply(
    flavors_per_base,
    function(f) all(c("both", "labor_only", "capital_only") %in% f),
    logical(1)
  )]
  if (!length(bases)) {
    cli::cli_warn(c(
      "{.code --decomp} runscript has no base scenarios with all three flavors.",
      i = "Expected each base id to appear with no suffix and with both _LO and _CO."
    ))
    return(invisible(NULL))
  }
  incomplete <- setdiff(names(flavors_per_base), bases)
  if (length(incomplete)) {
    cli::cli_warn(c(
      "Skipping {length(incomplete)} base scenario(s) missing LO/CO/both flavors.",
      i = "Incomplete: {.val {incomplete}}."
    ))
  }

  one_run <- function(sid) {
    cf <- read_receipts(output_root, sid, runtype)[year == yr]
    if (!nrow(cf)) {
      cli::cli_abort("Scenario {.val {sid}} receipts.csv has no row for year {.val {yr}}.")
    }
    c(unlist(cf[, ..instruments], use.names = FALSE),
      total = .receipts_total(cf))
  }
  bl_vals <- one_run(baseline_id)
  rows <- lapply(bases, function(base) {
    v_both <- one_run(base)
    v_LO   <- one_run(paste0(base, "_LO"))
    v_CO   <- one_run(paste0(base, "_CO"))
    delta_labor   <- v_LO   - bl_vals
    delta_capital <- v_CO   - bl_vals
    delta_both    <- v_both - bl_vals
    data.table(
      scenario_id   = base,
      instrument    = c(instruments, "total"),
      delta_labor   = delta_labor,
      delta_capital = delta_capital,
      delta_both    = delta_both,
      interaction   = delta_both - delta_labor - delta_capital
    )
  })
  rbindlist(rows)
}

# Per-scenario aggregate income totals (pretax, aftertax) for one year.
# Mirrors build_revenue_delta_table: long form with one row per
# (scenario_id, income_type), values in $B. Filters dependents to match
# income_series convention.
build_income_total_table <- function(output_root, runscript_path, year,
                                     runtype = "static",
                                     tax_set = c("iit", "iit_pr")) {
  tax_set <- match.arg(tax_set)
  rs <- fread(runscript_path)
  baseline_id <- "baseline"
  scenarios <- .both_scenarios(rs, baseline_id)

  totals <- function(scenario_id) {
    s <- income_series(read_detail(output_root, scenario_id, year, runtype),
                       tax_set)
    c(pretax = sum(s$weight * s$pretax) / 1e9,
      aftertax = sum(s$weight * s$aftertax) / 1e9)
  }
  bl <- totals(baseline_id)
  rows <- lapply(scenarios, function(sid) {
    cf <- totals(sid)
    data.table(
      scenario_id    = sid,
      income_type    = c("pretax", "aftertax"),
      baseline       = bl,
      counterfactual = cf,
      delta          = cf - bl
    )
  })
  rbindlist(rows)
}

# Distributional summary for one scenario × year. Returns aftertax and
# pretax income series (expanded_inc and expanded_inc - liab_iit_net)
# for use in inequality measures. `tax_set` is "iit" (default; aftertax
# = expanded - liab_iit_net) or "iit_pr" (aftertax = expanded - IIT
# - total payroll). Filters out dependent returns to match
# Tax-Simulator's distribution-table convention.
income_series <- function(detail, tax_set = c("iit", "iit_pr")) {
  tax_set <- match.arg(tax_set)
  d <- detail[dep_status == 0]
  list(
    weight   = d$weight,
    pretax   = d$expanded_inc,
    aftertax = if (tax_set == "iit_pr") {
      d$expanded_inc - d$liab_iit_net - d$liab_pr
    } else {
      d$expanded_inc - d$liab_iit_net
    }
  )
}

# Income-concentration shares for one scenario, one income concept.
# Within-scenario ranking: each scenario forms its own deciles + top
# groups, so shares describe the inequality *of that scenario* (not
# how baseline-defined units fare under the shock — that's the role of
# the revenue-delta table). Returns long-form rows (group, share).
# Top groups overlap with decile 10 by construction; report both.
income_share_table <- function(x, w,
                               decile_count = 10L,
                               top_pcts = c(0.10, 0.05, 0.01, 0.001)) {
  keep <- !is.na(x) & x > 0 & w > 0
  x <- x[keep]; w <- w[keep]
  ord <- order(x)
  x <- x[ord]; w <- w[ord]
  cw <- cumsum(w) / sum(w)
  cy <- cumsum(w * x) / sum(w * x)

  cy_at <- function(p) {
    if (p <= 0) return(0)
    if (p >= 1) return(1)
    # Linear interpolation: cy[i] is share at population fraction cw[i]
    i <- which(cw >= p)[1]
    if (i == 1L) return(cy[i] * (p / cw[i]))
    cy[i - 1L] + (cy[i] - cy[i - 1L]) *
      (p - cw[i - 1L]) / (cw[i] - cw[i - 1L])
  }

  # Decile shares: cy_at(k/n) - cy_at((k-1)/n) for k = 1..n
  d_breaks <- seq(0, 1, by = 1 / decile_count)
  d_cum    <- vapply(d_breaks, cy_at, numeric(1))
  decile_shares <- diff(d_cum)

  # Top-share: 1 - cy_at(1 - p)
  top_shares <- vapply(top_pcts, function(p) 1 - cy_at(1 - p), numeric(1))

  rbind(
    data.table(
      group_type = "decile",
      group      = sprintf("decile_%d", seq_len(decile_count)),
      share      = decile_shares
    ),
    data.table(
      group_type = "top",
      group      = sprintf("top_%g_pct", top_pcts * 100),
      share      = top_shares
    )
  )
}

# Per-scenario (Gini, top-shares) for one year, comparing each
# non-baseline scenario in the runscript to baseline. Returns two
# tables in a list:
#   $gini:   one row per (scenario_id, income_concept).
#   $shares: one row per (scenario_id, income_concept, group).
# All values are within-scenario rankings.
build_inequality_delta_tables <- function(output_root, runscript_path, year,
                                          runtype = "static",
                                          tax_set = c("iit", "iit_pr")) {
  tax_set <- match.arg(tax_set)
  rs <- fread(runscript_path)
  baseline_id <- "baseline"

  summarise_one <- function(scenario_id) {
    s <- income_series(read_detail(output_root, scenario_id, year, runtype),
                       tax_set)
    list(
      gini = data.table(
        income_concept = c("pretax", "aftertax"),
        gini           = c(weighted_gini(s$pretax,   s$weight),
                           weighted_gini(s$aftertax, s$weight))
      ),
      shares = rbind(
        income_share_table(s$pretax,   s$weight)[, income_concept := "pretax"],
        income_share_table(s$aftertax, s$weight)[, income_concept := "aftertax"]
      )
    )
  }

  bl <- summarise_one(baseline_id)

  scenarios <- .both_scenarios(rs, baseline_id)
  per_scenario <- lapply(scenarios, function(sid) {
    cf <- summarise_one(sid)
    gini <- merge(
      bl$gini[, .(income_concept, gini_baseline = gini)],
      cf$gini[, .(income_concept, gini_cf = gini)],
      by = "income_concept"
    )
    gini[, scenario_id := sid]
    gini[, delta := gini_cf - gini_baseline]

    shares <- merge(
      bl$shares[, .(income_concept, group_type, group, share_baseline = share)],
      cf$shares[, .(income_concept, group_type, group, share_cf       = share)],
      by = c("income_concept", "group_type", "group")
    )
    shares[, scenario_id := sid]
    shares[, delta := share_cf - share_baseline]

    list(gini = gini, shares = shares)
  })

  list(
    gini   = rbindlist(lapply(per_scenario, `[[`, "gini")
                       )[order(scenario_id, income_concept)],
    shares = rbindlist(lapply(per_scenario, `[[`, "shares")
                       )[order(scenario_id, income_concept, group_type, group)]
  )
}

# Per-(scenario_id, decile) building blocks for the ATR-by-decile
# figures. Deciles are anchored to BASELINE pretax (expanded_inc) so
# the same household stays in the same decile across the baseline-vs-cf
# comparison — the standard convention for plotting ΔATR by decile.
#
# Drops scenarios whose factor-channels sidecar is missing (e.g., runs
# that pre-date the sidecar wiring); emits one row per (sid, decile)
# for every "both"-flavor scenario that has one.
#
# Columns (level totals in $ billions):
#   scenario_id, decile,
#   pretax_base_d_B, pretax_cf_d_B,
#   tax_base_d_B,    tax_cf_d_B,
#   dY_factor_d_B
#
# Tax = liab_iit_net (+ liab_pr when tax_set = "iit_pr"). Non-dependents
# only (dep_status == 0), matching build_income_total_table's filter.
build_atr_decile <- function(output_root, runscript_path, year,
                             vintage_paths = NULL,
                             runtype       = "static",
                             tax_set       = c("iit", "iit_pr"),
                             n_deciles     = 10L) {
  tax_set <- match.arg(tax_set)
  if (is.null(vintage_paths)) vintage_paths <- tax_data_vintage()
  rs <- fread(runscript_path)
  scenarios <- .both_scenarios(rs)

  bl <- read_detail(output_root, "baseline", year, runtype)[dep_status == 0]
  bl_has_pr <- "liab_pr" %in% names(bl)
  bl <- bl[, .(id, weight,
               expanded_inc_b = expanded_inc,
               liab_iit_b     = liab_iit_net,
               liab_pr_b      = if (bl_has_pr) liab_pr else 0)]

  cuts <- weighted_quantile(bl$expanded_inc_b, bl$weight,
                             seq_len(n_deciles - 1L) / n_deciles)
  bl[, decile := findInterval(expanded_inc_b, c(-Inf, cuts, Inf),
                               rightmost.closed = TRUE)]
  bl[decile > n_deciles, decile := n_deciles]

  tax_b_expr <- if (tax_set == "iit_pr") {
    quote(liab_iit_b + liab_pr_b)
  } else quote(liab_iit_b)

  per_scenario <- lapply(scenarios, function(sid) {
    cf <- read_detail(output_root, sid, year, runtype)[dep_status == 0]
    cf_has_pr <- "liab_pr" %in% names(cf)
    cf <- cf[, .(id,
                 expanded_inc_c = expanded_inc,
                 liab_iit_c     = liab_iit_net,
                 liab_pr_c      = if (cf_has_pr) liab_pr else 0)]

    sid_row     <- rs[ID == sid][1L]
    scen_dir    <- file.path(vintage_paths$path,
                              sid_row[["dep.Tax-Data.ID"]])
    fch_fp      <- file.path(scen_dir, sprintf("factor_channels_%d.csv", year))
    if (!file.exists(fch_fp)) {
      cli::cli_warn(c(
        "Missing factor_channels sidecar for {.val {sid}}; skipping.",
        x = "Looked for {.path {fch_fp}}.",
        i = "Re-run the cell so the orchestrator emits the sidecar."
      ))
      return(NULL)
    }
    fch <- fread(fch_fp)[, .(id, dY_factor_unit)]

    d <- merge(bl,  cf,  by = "id", all.x = TRUE)
    d <- merge(d,   fch, by = "id", all.x = TRUE)
    d[is.na(expanded_inc_c), expanded_inc_c := expanded_inc_b]
    d[is.na(liab_iit_c),     liab_iit_c     := liab_iit_b]
    d[is.na(liab_pr_c),      liab_pr_c      := liab_pr_b]
    d[is.na(dY_factor_unit), dY_factor_unit := 0]

    d[, tax_b := eval(tax_b_expr)]
    d[, tax_c := if (tax_set == "iit_pr") {
      liab_iit_c + liab_pr_c
    } else liab_iit_c]

    out <- d[, .(
      pretax_base_d_B = sum(weight * expanded_inc_b) / 1e9,
      pretax_cf_d_B   = sum(weight * expanded_inc_c) / 1e9,
      tax_base_d_B    = sum(weight * tax_b)          / 1e9,
      tax_cf_d_B      = sum(weight * tax_c)          / 1e9,
      dY_factor_d_B   = sum(weight * dY_factor_unit) / 1e9
    ), by = decile]
    out[, scenario_id := sid]
    out[order(decile)]
  })

  out <- rbindlist(Filter(Negate(is.null), per_scenario))
  if (!nrow(out)) return(out)
  setcolorder(out, c("scenario_id", "decile",
                     "pretax_base_d_B", "pretax_cf_d_B",
                     "tax_base_d_B",    "tax_cf_d_B",
                     "dY_factor_d_B"))
  out[]
}

# --- Shared helpers reused by 09's publishable bundle -------------

# Static reference table: one row per axis code with formula, defaults,
# and notes. Used as the scenario_guide sheet in both 08's microsim
# bundle and 09's publishable bundle.
.build_scenario_guide <- function(publishable = FALSE) {
  dt <- data.table(
    axis = c(rep("variant", 3), rep("share_mode", 2),
             rep("labor", 3), "realization"),
    code = c("S", "M", "R",
             "R", "F",
             "S2", "S0", "S3",
             "V1"),
    name = c("Slow", "Moderate", "Rapid",
             "Reallocate", "Fixed share",
             "Compressive", "Proportional", "Expansive",
             "Mechanical"),
    mechanism = c(
      "5-yr cumulative shock target",
      "5-yr cumulative shock target",
      "5-yr cumulative shock target",
      "Karger labor-share decline: s1 from yaml",
      "Hold labor-capital share at baseline: s1 := 1 - L0",
      "Log-affine, sigma_S2 = 1 - k_inequality * gy",
      "Uniform scaling",
      "Log-affine, sigma_S3 = 1 + k_inequality * gy",
      "All gross gains realized in-year"
    ),
    formula = c(
      "K1 = s1*(1+gy); L1 = (1-s1)*(1+gy); gk = (K1-K0)/K0; alpha = (1/gk) * (L1-L0)/L0",
      "(same as S)",
      "(same as S)",
      "s1 from yaml shock.variants.<variant>.s1; gk and alpha derived as above.",
      "s1 = 1 - L0 = K0  =>  gk = gy, alpha = 1; labor and capital both grow at gy.",
      "ln(YiL1) = mu1 + sigma_S2 * (ln(YiL0) - mu0); sigma_S2 = 1 - k_inequality * gy; mu1 via uniroot to hit L1$",
      "YiL1 = rho * YiL0, rho = L1$ / L0$",
      "ln(YiL1) = mu1 + sigma_S3 * (ln(YiL0) - mu0); sigma_S3 = 1 + k_inequality * gy; mu1 via uniroot to hit L1$",
      "X_ltcg_V1 = X_ltcg_gross"
    ),
    defaults_implied = c(
      "s1=0.450, gy=0.0060 -> gk ≈ +1.7%,  alpha ≈ -0.18 -> labor -0.3%  (Slow)",
      "s1=0.462, gy=0.0358 -> gk ≈ +7.5%,  alpha ≈ +0.05 -> labor +0.4%  (Moderate)",
      "s1=0.487, gy=0.0716 -> gk ≈ +17.3%, alpha ≈ -0.05 -> labor -0.9% (Rapid)",
      "Canonical AI-growth-plus-reallocation shock.",
      "Paired twin of R: same gy, labor and capital both scale by (1+gy).",
      "k_inequality = 1 by default (config: labor_inequality.k). See labor_inequality sheet for per-variant sigma_S2.",
      "—",
      "k_inequality = 1 by default (config: labor_inequality.k). See labor_inequality sheet for per-variant sigma_S3.",
      "—"
    ),
    notes = c(
      "Mildest variant. Karger 2026 NBER w35046: Table 39 (labor share) and Table 19 (median 2030 annualized GDP growth under AI), Total column, median.",
      "Karger Tables 39 / 19.",
      "Most capital-biased. Karger Tables 39 / 19.",
      "Reallocate mode: the post-shock capital share equals the Karger target for the variant.",
      "Fixed-share mode: the labor-capital split is preserved. Isolates the AI growth channel from the reallocation channel.",
      "Reduces labor-income inequality. Rationale: AI commoditizes high-skill premia (top wages pulled toward mean).",
      "Leaves labor-income inequality unchanged.",
      "Increases labor-income inequality. Rationale: AI super-charges top earners (winner-take-most).",
      "Publishable default: K0 is built from the on-1040 realized base, so the baseline realization rate is already implicit in X."
    )
  )
  # Guide rows are hand-written (prose per row, presentational order);
  # assert the (axis, code, name) triples stay in lockstep with the axis
  # registry in 00_utils.R so neither can drift alone.
  registry <- rbind(
    data.table(axis = "variant",     code = names(.AXIS_VARIANTS),
               name = unname(.AXIS_VARIANTS)),
    data.table(axis = "share_mode",  code = names(.AXIS_SHARE_MODES),
               name = unname(.AXIS_SHARE_MODES)),
    data.table(axis = "labor",       code = names(.AXIS_LABOR),
               name = unname(.AXIS_LABOR)),
    data.table(axis = "realization", code = names(.AXIS_REALIZATION),
               name = unname(.AXIS_REALIZATION))
  )
  key_of <- function(d) sort(paste(d$axis, d$code, d$name, sep = "|"))
  if (!identical(key_of(dt), key_of(registry))) {
    cli::cli_abort(c(
      "scenario_guide rows out of sync with the axis registry.",
      x = "Guide-only: {.val {setdiff(key_of(dt), key_of(registry))}}; registry-only: {.val {setdiff(key_of(registry), key_of(dt))}}.",
      i = "Update {.fn .build_scenario_guide} and the registry in {.path code/00_utils.R} together."
    ))
  }
  if (publishable) {
    dt[, notes := NULL]
  }
  dt
}

# Flatten the scenario_params.yaml into a flat (block, parameter, value,
# status, source) table. Auto-generated on every run so the .xlsx bundle
# carries the same parameter inventory that the pipeline read.
#
# yaml schema convention (see config/scenario_params.yaml header): every
# leaf parameter K has optional sibling keys K_status and K_source. This
# function walks every named list, skips *_status / *_source keys, and
# attaches them as metadata on the leaf row.
#
# Block is the top-level yaml key (e.g. "shock", "realization") so the
# sheet reads at a glance instead of carrying long dotted prefixes.
.build_parameter_index <- function(
  params_yaml_path = "config/scenario_params.yaml"
) {
  if (!file.exists(params_yaml_path)) {
    cli::cli_abort(c(
      "Parameter config not found.",
      "x" = "Looked for {.path {params_yaml_path}}.",
      "i" = "The publishable bundle requires the live yaml to build parameter_index."
    ))
  }
  raw  <- yaml::read_yaml(params_yaml_path)
  rows <- .flatten_yaml_with_metadata(raw, prefix = "")
  out  <- rbindlist(rows)
  out[, block := vapply(parameter, function(p) {
    segs <- strsplit(p, ".", fixed = TRUE)[[1]]
    if (length(segs) == 1L) "(root)" else segs[1]
  }, character(1))]
  setcolorder(out, c("block", "parameter", "value", "status", "source"))
  out[]
}

# Recursive helper for .build_parameter_index. Returns a list of one-row
# data.tables, one per leaf parameter encountered. Status/source keys
# (suffix `_status` / `_source`) are not emitted as their own rows;
# instead they are looked up as siblings of the leaf they describe.
.flatten_yaml_with_metadata <- function(x, prefix) {
  if (!is.list(x) || is.null(names(x))) return(list())
  out <- list()
  for (nm in names(x)) {
    if (grepl("_(status|source)$", nm)) next
    full <- if (nzchar(prefix)) paste0(prefix, ".", nm) else nm
    val  <- x[[nm]]
    if (is.list(val) && !is.null(names(val))) {
      out <- c(out, .flatten_yaml_with_metadata(val, full))
    } else {
      out[[length(out) + 1L]] <- data.table(
        parameter = full,
        value     = .scalarize_yaml_leaf(val),
        status    = x[[paste0(nm, "_status")]] %||% NA_character_,
        source    = x[[paste0(nm, "_source")]] %||% NA_character_
      )
    }
  }
  out
}

# Render a yaml leaf (numeric / character / logical / vector / NULL) as
# a single display string for the parameter_index sheet.
.scalarize_yaml_leaf <- function(v) {
  if (is.null(v))      return("(null)")
  if (length(v) == 1L) return(as.character(v))
  paste0("[", paste(as.character(v), collapse = ", "), "]")
}

# Load a calibration receipt CSV (e.g. config/calibration/kappa_corp_calculation.csv)
# into a data.table for embedding as a sheet. Returns NULL if the file
# is missing so the bundle doesn't fail on partial calibration setups.
.load_calibration_receipt <- function(path) {
  if (!file.exists(path)) return(NULL)
  fread(path)
}

# One-row-per-receipt index: name, source path, brief description.
# Lets a reader see at a glance what receipts are embedded and where the
# canonical CSV lives in the repo.
.build_calibration_index <- function(
  calibration_dir = "config/calibration"
) {
  receipts <- list(
    list(name        = "kappa_corp",
         file        = "kappa_corp_calculation.csv",
         description = "Narrow C-corp share of capital income on NIPA 2024 Z.1 F.3 basis (S-corps stripped from numerator).")
  )
  rbindlist(lapply(receipts, function(r) {
    fp <- file.path(calibration_dir, r$file)
    data.table(
      receipt     = r$name,
      sheet       = paste0("calibration_", r$name),
      source_path = fp,
      embedded    = file.exists(fp),
      description = r$description
    )
  }))
}

.build_labor_inequality <- function(publishable = FALSE) {
  dt <- data.table(
    component = c(
      "Inequality multiplier",
      "Compressive slope (S2)",
      "Expansive slope (S3)",
      "Aggregate anchor"
    ),
    symbol = c(
      "k_inequality",
      "sigma_S2 = 1 - k_inequality * gy",
      "sigma_S3 = 1 + k_inequality * gy",
      "mu1 via uniroot s.t. sum(weight * exp(mu1 + sigma * (ln(YiL0) - mu0))) = L1$"
    ),
    default_value = c(
      "1.0",
      "S: 0.949 | M: 0.933 | R: 0.896  (at k=1)",
      "S: 1.051 | M: 1.067 | R: 1.104  (at k=1)",
      "varies by cell"
    ),
    meaning = if (publishable) c(
      "A dial that controls how strongly the AI growth shock changes labor-income inequality. The default value of 1 says a 5% AI growth bump shifts the dispersion parameter by 5 percentage points; setting it to 0 would leave inequality unchanged.",
      "Under the compressive labor scenario (S2), top earners are pulled toward the mean. This is the slope of the log-affine map applied to baseline log labor income; values below 1 compress the distribution. Calculated as 1 - k_inequality * (AI growth bump gy).",
      "Under the expansive labor scenario (S3), top earners pull further away from the mean. This is the slope of the log-affine map applied to baseline log labor income; values above 1 stretch the distribution. Calculated as 1 + k_inequality * (AI growth bump gy).",
      "After applying the inequality map, the intercept of the map is solved so that aggregate labor income still matches the macro target. Without this anchor, changing inequality alone would also shift the total wage bill."
    ) else c(
      "Multiplier on the AI growth bump gy that sets the size of the dispersion shift in the log-affine map. Same value across all variants in a run; per-variant sigma values differ because gy differs.",
      "Compressive map: top of the ln(YiL) distribution is pulled toward the mean by (1 - sigma_S2). Rationale: AI commoditizes high-skill premia. Larger gy => more compression.",
      "Expansive map: top of the ln(YiL) distribution is stretched away from the mean by (sigma_S3 - 1). Rationale: AI super-charges top earners (winner-take-most). Larger gy => more expansion.",
      "Intercept mu1 is solved to preserve the aggregate labor income target L1$ from the macro step. mu0 is the weighted mean of ln(YiL) on positive-labor units in the baseline."
    ),
    source = c(
      "scenario_params.yaml: labor_inequality.k (default 1).",
      "Computed in 03_shock_labor.R; gy from the macro step (per-variant). See parameters sheet.",
      "Computed in 03_shock_labor.R; gy from the macro step (per-variant). See parameters sheet.",
      "Computed in 03_shock_labor.R."
    )
  )
  if (publishable) dt[, source := NULL]
  dt
}

.build_corporate_tax <- function(publishable = FALSE) {
  dt <- data.table(
    component = c(
      "Statutory C-corp rate",
      "C-corp share of new capital income",
      "CBO baseline-year CIT level",
      "Calibrated corporate-base scale factor",
      "Capital flow (gross)",
      "Flow to households",
      "Macro CIT delta",
      "Publishable revenue delta"
    ),
    symbol = c(
      "tau_stat",
      "kappa_corp",
      "CBO_CIT$ = cit_to_gdp_baseline_year * gdp_baseline_year_B$",
      "eta = tau_stat * (K0$ * kappa_corp) / CBO_CIT$",
      "X = K0$ * gk",
      "X_to_units = X",
      "delta_R_CIT = tau_stat * kappa_corp * X / eta ≡ X * CBO_CIT$ / K0$",
      "ΔR_total = (revenue_deltas: instrument='total') + delta_R_CIT"
    ),
    default_value = c(
      "0.21", "0.50 (narrow definition)",
      "cit_to_gdp_baseline_year * gdp_baseline_year_B$ (from scenario_params.yaml)",
      "Calibrated at runtime from K0$",
      "varies by variant", "X (unchanged)",
      "varies by variant only", "varies by cell"
    ),
    meaning = if (publishable) c(
      "The statutory federal corporate tax rate assumed by this simulation.",
      "The fraction of new capital income that is taxed at the corporate level. The narrow definition used here excludes S-corp and partnership profits, since those flow directly to households and are taxed under the individual income tax inside Tax-Simulator.",
      "Baseline-year federal corporate-tax revenue from CBO. The CIT side of the model is calibrated so that, at baseline, the simulated CIT level matches this number.",
      "Single calibrated scale factor that absorbs both the gap between household-realized capital income (K0$) and the pre-realization corporate tax base, and the gap between the statutory rate and the effective rate (avoidance, NOLs, credits, profit shifting). One value per (variant, share_mode) cell.",
      "The estimated excess capital income created by the AI growth shock, calculated by taking baseline capital income and multiplying it by the excess capital growth rate.",
      "The full AI capital flow reaches households. Corporate tax is modeled upstream of household realizations, so there is no household-side CIT reduction in the microsim base.",
      "The additional federal corporate-tax revenue collected on the new capital flow, computed outside of Tax-Simulator. Scales linearly with X: the AI CIT delta equals X divided by baseline capital income, times the CBO baseline CIT level. Same value across every household-level scenario that shares a shock variant (S, M, or R).",
      "Bottom-line revenue change for a scenario. Equals the Tax-Simulator total (income tax + payroll - refundable credit outlays) plus the macro CIT delta for the matching variant."
    ) else c(
      "TCJA federal C-corp rate (IRC §11).",
      "Narrow definition. S-corp + partnership profits are routed separately to households via the Smith-Yagan-Zidar 2019 split in 01_load_data.R, so they're already in the IIT side. Inclusive definition (S-corp counted) gives 0.62. Sensitivity range [0.45, 0.65].",
      "CBO 2025 Budget and Economic Outlook (publication 62105), Table 1, 2030 federal CIT / GDP, applied to 2030 nominal GDP.",
      "Calibrated at runtime by compute_macro_targets() so that tau_stat * (K0$ * kappa_corp) / eta matches CBO_CIT$ at baseline. eta absorbs household-realized-vs-pre-realization wedge plus statutory-vs-effective gap.",
      "Aggregate dollar flow from baseline to counterfactual capital income — the 'extra' capital income created by the shock.",
      "CIT acts upstream of household realizations: the full AI capital flow X reaches tax units, and the corporate-tax response enters the bottom line via delta_R_CIT (computed off-microsim) rather than via a reduction in the household-side base.",
      "Off-microsim corporate-tax contribution to ΔR. NOT in receipts.csv (Tax-Simulator copies the CBO baseline corp tax through both runs, so revenues_corp_tax delta is 0). Same value applies to all cells sharing a (variant, share_mode) pair.",
      "BOTTOM LINE. To get the full ΔR for a cell, take the 'total' row from revenue_deltas (microsim, IIT + payroll - credit outlays) and add delta_R_CIT for the matching variant. Done in 09_tables_figures.R."
    ),
    source = c(
      "scenario_params.yaml: corporate.cit_statutory.",
      "scenario_params.yaml: corporate.kappa_corp; NIPA 2024 Z.1 F.3.",
      "scenario_params.yaml: cbo_baseline.cit_to_gdp_baseline_year × gdp_baseline_year_B.",
      "Derived in 04_allocate_capital.R::compute_macro_targets. See parameters sheet.",
      "Computed in 04_allocate_capital.R::compute_macro_targets. See parameters sheet.",
      "Equals X by construction; CIT no longer subtracted from the household-side flow.",
      "Computed in 04_allocate_capital.R; see parameters sheet for S/M/R values.",
      "Derived; not in any single sheet of this workbook."
    )
  )
  if (publishable) dt[, source := NULL]
  dt
}

# Generic sheet writer used by both 08 and 09 bundle helpers.
# `wrap_cols` may be column names (character) or 1-based indices.
# Names are preferred — they survive column reorderings.
.add_xlsx_sheet <- function(wb, name, data, hdr_style, wrap_style,
                             wrap_cols = NULL, wrap_width = 60) {
  openxlsx::addWorksheet(wb, name)
  openxlsx::writeData(wb, name, data, headerStyle = hdr_style)
  openxlsx::freezePane(wb, name, firstRow = TRUE)

  wrap_idx <- if (is.null(wrap_cols))      integer(0)
              else if (is.character(wrap_cols)) match(wrap_cols, names(data))
              else                              as.integer(wrap_cols)
  wrap_idx <- wrap_idx[!is.na(wrap_idx)]

  auto_cols <- setdiff(seq_len(ncol(data)), wrap_idx)
  if (length(auto_cols)) {
    openxlsx::setColWidths(wb, name, cols = auto_cols, widths = "auto")
  }
  if (length(wrap_idx)) {
    openxlsx::setColWidths(wb, name, cols = wrap_idx, widths = wrap_width)
    openxlsx::addStyle(wb, name, wrap_style,
                       rows = 2:(nrow(data) + 1L),
                       cols = wrap_idx,
                       gridExpand = TRUE, stack = TRUE)
  }
}

# Two-column run-metadata table (field, value). When `bundle_type` is
# supplied, an extra row is inserted after "Generated" identifying the
# bundle flavor (microsim / publishable).
.build_run_info <- function(year, output_root, runscript_path, scenarios,
                            argv, bundle_type = NULL) {
  fields <- c("Generated", "Policy year", "Tax-Simulator vintage",
              "Tax-Simulator output root", "Runscript", "Scenarios",
              "Number of scenarios", "R version", "AI-Fiscal git rev",
              "Orchestrator argv")
  values <- c(format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              as.character(year),
              basename(output_root),
              output_root,
              runscript_path,
              paste(scenarios, collapse = ", "),
              as.character(length(scenarios)),
              R.version.string,
              .git_short_rev(),
              if (!is.null(argv) && length(argv))
                paste(argv, collapse = " ") else "(run directly)")
  if (!is.null(bundle_type)) {
    fields <- append(fields, "Bundle type", after = 1L)
    values <- append(values, bundle_type, after = 1L)
  }
  data.table(field = fields, value = values)
}

# Rename the macro-summary columns to plain-English headers for the
# publishable bundle's `parameters` sheet. Symbol is kept in parentheses
# so the row remains identifiable to anyone reading the model code.
# Unknown columns pass through unchanged.
.friendly_parameters_sheet <- function(dt) {
  rename_map <- c(
    variant                    = "Shock variant (S/M/R)",
    share_mode                 = "Factor-share mode (R reallocate / F fixed)",
    s1                         = "Post-shock capital share (s1)",
    gy                         = "AI growth bump over CBO baseline (gy)",
    gk                         = "Capital growth rate (gk)",
    alpha                      = "Labor-to-capital growth ratio (alpha)",
    k_inequality               = "Inequality multiplier (k_inequality)",
    sigma_S2                   = "Compressive slope (sigma_S2)",
    sigma_S3                   = "Expansive slope (sigma_S3)",
    L0_dollar                  = "Baseline labor income, $ (L0)",
    K0_dollar                  = "Baseline capital income, $ (K0)",
    Y0_dollar                  = "Baseline total income, $ (Y0)",
    X                          = "Capital flow from shock, $ (X, gross)",
    X_to_units                 = "Capital flow to households, $ (X reaches units in full)",
    kappa_corp                  = "C-corp share of new capital income (kappa_corp)",
    cit_statutory              = "Statutory C-corp rate (cit_statutory)",
    cbo_cit_baseline_dollar    = "CBO baseline-year CIT level, $",
    eta_corp                   = "Calibrated corporate-base scale factor (eta_corp)",
    delta_R_CIT                = "Macro CIT revenue delta, $",
    X_qualified_div_B          = "Allocated to qualified dividends, $B",
    X_taxable_int_B            = "Allocated to taxable interest, $B",
    X_tax_exempt_int_B         = "Allocated to tax-exempt interest, $B",
    X_passthrough_ordinary_B   = "Allocated to passthrough ordinary income, $B",
    X_ltcg_gross_B             = "Allocated to long-term capital gains, gross, $B",
    X_ltcg_V1_realized_B       = "LTCG realized under V1 (mechanical), $B",
    X_retirement_slice_B       = "Retirement slice (pre-cascade allocation), $B",
    X_retirement_realized_B    = "Retirement slice realized this year (F), $B",
    X_retirement_unrealized_B  = "Retirement slice unrealized / deferred, $B"
  )
  nm  <- names(dt)
  new <- ifelse(nm %in% names(rename_map), rename_map[nm], nm)
  setnames(dt, nm, new)
  dt
}

# Initialize an .xlsx bundle. Reads the runscript + macro CSV, builds a
# workbook with the metadata sheets populated (run_info, scenario_guide,
# parameter_index, parameters_per_variant, labor_inequality, corporate_tax,
# calibration_receipts_index + per-receipt sheets), and returns a context
# with a closed-over `add_sheet` so the caller only adds its own data
# sheets. Returns NULL when openxlsx is unavailable; callers short-circuit.
#
# parameter_index is auto-generated from config/scenario_params.yaml on
# every run, replacing the hand-maintained config/parameter_tracker.xlsx.
# Calibration receipts (kappa_corp) are embedded directly
# from config/calibration/*.csv so the bundle is self-contained.
.init_xlsx_bundle <- function(year, output_root, runscript_path, argv,
                               bundle_type    = NULL,
                               publishable    = FALSE,
                               params_yaml    = "config/scenario_params.yaml",
                               calibration_dir = "config/calibration") {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    cli::cli_warn(c(
      "{.pkg openxlsx} not installed; skipping .xlsx bundle.",
      i = "Install with {.code install.packages('openxlsx')} to enable."
    ))
    return(NULL)
  }

  vintage   <- basename(output_root)
  rs        <- fread(runscript_path)
  scenarios <- .both_scenarios(rs)

  macro_csv  <- sub("\\.csv$", "_macro.csv", runscript_path)
  params_tbl <- if (file.exists(macro_csv)) fread(macro_csv) else
    data.table(note = sprintf("Macro summary not found at %s", macro_csv))
  if (publishable) params_tbl <- .friendly_parameters_sheet(params_tbl)

  wb   <- openxlsx::createWorkbook()
  hdr  <- openxlsx::createStyle(textDecoration = "bold")
  wrap <- openxlsx::createStyle(wrapText = TRUE, valign = "top")
  add_sheet <- function(name, data, wrap_cols = NULL, wrap_width = 60) {
    .add_xlsx_sheet(wb, name, data, hdr, wrap, wrap_cols, wrap_width)
  }

  add_sheet("run_info", .build_run_info(year, output_root, runscript_path,
                                        scenarios, argv, bundle_type))
  sg_wrap <- if (publishable) c("mechanism", "formula", "defaults_implied")
             else             c("mechanism", "formula", "defaults_implied", "notes")
  add_sheet("scenario_guide", .build_scenario_guide(publishable = publishable),
            wrap_cols = sg_wrap)
  add_sheet("parameter_index", .build_parameter_index(params_yaml),
            wrap_cols = c("source"))
  add_sheet(if (publishable) "parameters" else "parameters_per_variant",
            params_tbl)
  li_wrap <- if (publishable) "meaning" else c("meaning", "source")
  add_sheet("labor_inequality",
            .build_labor_inequality(publishable = publishable),
            wrap_cols = li_wrap)
  ct_wrap <- if (publishable) "meaning" else c("meaning", "source")
  add_sheet("corporate_tax",
            .build_corporate_tax(publishable = publishable),
            wrap_cols = ct_wrap)

  # Calibration receipts: an index sheet + one sheet per CSV receipt.
  cal_idx <- .build_calibration_index(calibration_dir)
  add_sheet("calibration_receipts_index", cal_idx,
            wrap_cols = c("description"))
  for (i in seq_len(nrow(cal_idx))) {
    if (!cal_idx$embedded[i]) next
    receipt_data <- .load_calibration_receipt(cal_idx$source_path[i])
    if (!is.null(receipt_data)) {
      add_sheet(cal_idx$sheet[i], receipt_data,
                wrap_cols = intersect(c("formula_or_source", "notes"),
                                       names(receipt_data)))
    }
  }

  list(vintage = vintage, wb = wb, add_sheet = add_sheet)
}

# Per-column dictionary of the data sheets in 08's microsim bundle.
.build_variable_list_microsim <- function(include_decomp = FALSE) {
  base <- data.table(
    sheet = c(rep("revenue_deltas", 5),
              rep("income_deltas", 5),
              rep("gini_deltas", 5),
              rep("share_deltas", 7),
              rep("parameters_per_variant", 28)),
    column = c("scenario_id", "instrument", "baseline", "counterfactual", "delta",
               "scenario_id", "income_type", "baseline", "counterfactual", "delta",
               "scenario_id", "income_concept", "gini_baseline", "gini_cf", "delta",
               "scenario_id", "income_concept", "group_type", "group",
               "share_baseline", "share_cf", "delta",
               "variant", "share_mode",
               "s1", "gy", "gk", "alpha",
               "k_inequality", "sigma_S2", "sigma_S3",
               "L0_dollar", "K0_dollar", "Y0_dollar", "X", "X_to_units",
               "kappa_corp", "cit_statutory", "cbo_cit_baseline_dollar",
               "eta_corp", "delta_R_CIT",
               "X_qualified_div_B", "X_taxable_int_B", "X_tax_exempt_int_B",
               "X_passthrough_ordinary_B", "X_ltcg_gross_B",
               "X_ltcg_V1_realized_B",
               "X_retirement_slice_B", "X_retirement_realized_B",
               "X_retirement_unrealized_B"),
    description = c(
      "Scenario ID. Format: ai_<variant>_<share_mode>_<labor>_<realization>; e.g. ai_M_R_S0_V1 (Moderate, reallocate) and ai_M_F_S0_V1 (Moderate, fixed share). Realization is V1 (mechanical) for every cell in the release grid. See scenario_guide sheet.",
      "Tax-Simulator receipts column: revenues_payroll_tax, revenues_income_tax, outlays_tax_credits, revenues_corp_tax, revenues_estate_tax, revenues_vat, revenues_other; plus 'total' (sum of revenues minus credit outlays). Corp tax delta is zero by construction; layer the macro CIT wedge in 09_tables_figures.R.",
      "Baseline FY <year> receipts in $ billions.",
      "Counterfactual FY <year> receipts in $ billions.",
      "counterfactual - baseline ($B). Positive = revenue gain.",

      "Scenario ID.",
      "'pretax' = sum(weight * expanded_inc) over non-dependents; 'aftertax' = sum(weight * (expanded_inc - liab_iit_net)) over non-dependents (or further less liab_pr if tax_set='iit_pr').",
      "Baseline aggregate income in $ billions.",
      "Counterfactual aggregate income in $ billions.",
      "counterfactual - baseline ($B).",

      "Scenario ID.",
      "'pretax' = expanded_inc; 'aftertax' = expanded_inc - liab_iit_net (tax_set='iit', default) or further less liab_pr (tax_set='iit_pr').",
      "Within-scenario weighted Gini on baseline (0-1).",
      "Within-scenario weighted Gini on counterfactual.",
      "gini_cf - gini_baseline. Positive = inequality up.",

      "Scenario ID.",
      "pretax / aftertax (see gini_deltas).",
      "'decile' or 'top'.",
      "decile_1..decile_10, or top_10_pct / top_5_pct / top_1_pct / top_0.1_pct.",
      "Baseline share of total income held by group (fraction 0-1).",
      "Counterfactual share.",
      "share_cf - share_baseline.",

      "Shock variant: S (Slow), M (Moderate), R (Rapid). Karger 2026 NBER w35046, Tables 19 / 39.",
      "Factor-share mode. R = reallocate (Karger s1 from yaml). F = fixed (s1 := 1 - L0 so the labor-capital split is preserved). Same gy under both modes; F has gk = gy and alpha = 1 by construction.",
      "Period-1 capital share target = 1 - period-1 labor share.",
      "Multiplicative AI bump on the no-AI baseline-year level: (1 + r_ai_annual)^horizon / cum_base - 1, where r_ai_annual is Karger Table 19 median GDP CAGR under AI and cum_base = (1 + g_2026) * (1 + g_2027plus)^(horizon-1) is the CBO baseline path (publication 62105). Horizon = baseline_year - 2025 (= 5 for 2030).",
      "Capital factor growth rate over the horizon; derived in 02_params.R from (s1, gy, L0).",
      "Labor growth as a multiple of capital growth; labor grows at alpha * gk.",
      "Multiplier on g_y that sets the S2/S3 dispersion shift. From config: labor_inequality.k. Same value across all variants in a run.",
      "S2 (compressive) log-affine slope = 1 - k_inequality * gy. Per-variant since gy varies.",
      "S3 (expansive) log-affine slope = 1 + k_inequality * gy. Per-variant since gy varies.",
      "Microsim baseline aggregate labor income, sum(weight*YiL) in $.",
      "Microsim baseline aggregate capital income, sum(weight*YiK) in $.",
      "L0_dollar + K0_dollar.",
      "Implied capital flow = K0_dollar * gk ($).",
      "X reaches households in full: CIT is modeled upstream of household realizations, so X_to_units = X ($).",
      "C-corp share of new capital income (kappa_corp). Narrow definition; S-corps stripped from numerator.",
      "Statutory federal C-corp rate (cit_statutory). TCJA IRC §11.",
      "CBO baseline-year CIT revenue level ($). cit_to_gdp_baseline_year * gdp_baseline_year_B * 1e9. Anchors the eta calibration.",
      "Calibrated corporate-base scale factor (eta_corp). cit_statutory * (K0_dollar * kappa_corp) / cbo_cit_baseline_dollar. Absorbs both household-realized-vs-pre-realization wedge and the statutory-vs-effective gap.",
      "Off-microsim CIT revenue change ($). cit_statutory * kappa_corp * X / eta_corp; algebraically equals X * cbo_cit_baseline_dollar / K0_dollar. Add to microsim total in 09_tables_figures.R.",

      "Capital flow X_to_units allocated to qualified dividends ($B). 30% of public-equity allocation (per config/asset_to_income_map.csv).",
      "Capital flow allocated to taxable interest ($B). Fixed-income allocation × (1 - exempt_share), where exempt_share is the unit's baseline tax-exempt share of bond holdings.",
      "Capital flow allocated to tax-exempt interest ($B). Inclusion in expanded_inc but not in IIT base.",
      "Capital flow allocated to ordinary passthrough income ($B). 100% of passthrough-equity allocation; subject to QBI deduction at the unit level.",
      "Capital flow allocated to LTCG, GROSS ($B). 70% of public-equity allocation.",
      "In-year realized LTCG under V1 (mechanical): equals X_ltcg_gross_B by definition. X is sized off the on-1040 realized base; re-applying r would double-count.",
      "Pre-cascade retirement slice ($B). Computed as X_to_units minus the sum of the four non-retirement aggregates above. Equals Σ w · X_retirement_dc_ira after the within-unit allocation.",
      "Portion of the retirement slice realized this year as taxable pension + IRA distributions ($B). Equals the full slice under R1 (income-flow framing). This is the F aggregate from the cascade.",
      "Portion of the retirement slice that does not enter current-year expanded_inc or IIT ($B). = X_retirement_slice_B - X_retirement_realized_B. Zero under R1 by construction."
    )
  )
  # Defensive invariant: the three vectors must be the same length, or
  # data.table() recycles silently and the sheet→column→description
  # alignment drifts. Trips at the next edit if a column is added /
  # removed without updating both the names and descriptions.
  stopifnot(length(base$sheet) == length(base$column),
            length(base$column) == length(base$description))
  if (!include_decomp) return(base)

  decomp <- data.table(
    sheet = rep("revenue_decomp", 6),
    column = c("scenario_id", "instrument",
               "delta_labor", "delta_capital", "delta_both", "interaction"),
    description = c(
      "Base scenario ID (no _LO/_CO suffix). Each row reports the labor/capital decomposition of one instrument's delta for this cell.",
      "As in revenue_deltas, plus the synthetic 'total' row.",
      "T(labor_only) - T(baseline) in $B. The labor-side contribution: includes payroll (mechanically a function of wages) and the labor portion of the IIT response.",
      "T(capital_only) - T(baseline) in $B. The capital-side contribution: dividends, interest, LTCG, passthrough capital flows. Payroll component is ~0 by construction.",
      "T(both) - T(baseline) in $B. The full microsim delta — equals the matching row in revenue_deltas.",
      "delta_both - delta_labor - delta_capital in $B. Non-linear interaction (bracket effects, AMT, phase-outs); cannot be attributed to either side without an additional assumption."
    )
  )
  stopifnot(length(decomp$sheet) == length(decomp$column),
            length(decomp$column) == length(decomp$description))
  rbind(base, decomp)
}

# Microsim bundle: run_info, scenario_guide, parameter_index,
# parameters_per_variant, labor_inequality, corporate_tax, and
# calibration_receipts_* sheets (via .init_xlsx_bundle), then
# variable_list + the three microsim data sheets. Writes two files:
# the timestamp-vintaged archival copy (local-only; gitignored) and
# `ai_fiscal_<year>_latest.xlsx` (the canonical, tracked deliverable
# that is overwritten on every run). See `.gitignore` and §9 of the
# model doc.
write_excel_bundle <- function(out_dir, year, rev, gini, shares, inc,
                                output_root, runscript_path,
                                decomp = NULL, argv = NULL) {
  ctx <- .init_xlsx_bundle(year, output_root, runscript_path, argv)
  if (is.null(ctx)) return(invisible(NULL))

  ctx$add_sheet("variable_list",
                .build_variable_list_microsim(include_decomp = !is.null(decomp)),
                wrap_cols = "description")
  ctx$add_sheet("revenue_deltas", rev)
  ctx$add_sheet("income_deltas",  inc)
  ctx$add_sheet("gini_deltas",    gini)
  ctx$add_sheet("share_deltas",   shares)
  if (!is.null(decomp)) ctx$add_sheet("revenue_decomp", decomp)

  fp        <- file.path(out_dir, sprintf("ai_fiscal_%d_%s.xlsx", year, ctx$vintage))
  latest_fp <- file.path(out_dir, sprintf("ai_fiscal_%d_latest.xlsx", year))
  openxlsx::saveWorkbook(ctx$wb, fp, overwrite = TRUE)
  file.copy(fp, latest_fp, overwrite = TRUE)
  cli::cli_inform(c(
    "Wrote {.path {fp}} ({length(openxlsx::sheets(ctx$wb))} sheets)",
    "Updated {.path {latest_fp}} (tracked canonical bundle)"
  ))
  fp
}

# Driver: aggregate one Tax-Simulator vintage into the deliverable
# tables (revenue deltas, Gini deltas, income-share deltas) and write
# them to `out_dir`. Also emits an .xlsx bundle with run metadata and
# a variable-list sheet. Returns a list with $revenue, $gini, $shares.
aggregate_tax_sim_output <- function(
  output_root    = latest_tax_sim_vintage(),
  runscript_path = file.path(
    Sys.getenv("TAX_SIMULATOR_DIR", unset = NA_character_),
    "config", "runscripts", "private", "ai_fiscal.csv"
  ),
  year           = NULL,
  runtype        = "static",
  tax_set        = "iit",
  out_dir        = "results/aggregates",
  argv           = NULL
) {
  if (is.null(year)) year <- .runscript_policy_year(runscript_path)

  rev <- build_revenue_delta_table(output_root, runscript_path, year, runtype)
  ineq <- build_inequality_delta_tables(output_root, runscript_path, year,
                                        runtype, tax_set)
  inc_totals <- build_income_total_table(output_root, runscript_path, year,
                                         runtype, tax_set)
  decomp <- build_revenue_decomp_table(output_root, runscript_path, year, runtype)
  atr_dec <- tryCatch(
    build_atr_decile(output_root, runscript_path, year,
                     runtype = runtype, tax_set = tax_set),
    error = function(e) {
      cli::cli_warn(c("build_atr_decile failed: {conditionMessage(e)}",
                       i = "Skipping atr_decile_{year}.csv this run."))
      NULL
    }
  )

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  fwrite(rev,         file.path(out_dir, sprintf("revenue_deltas_%d.csv", year)))
  fwrite(ineq$gini,   file.path(out_dir, sprintf("gini_deltas_%d.csv",   year)))
  fwrite(ineq$shares, file.path(out_dir, sprintf("share_deltas_%d.csv",  year)))
  fwrite(inc_totals,  file.path(out_dir, sprintf("income_deltas_%d.csv", year)))
  msgs <- c(
    "Wrote {.path {out_dir}}/revenue_deltas_{year}.csv ({nrow(rev)} rows)",
    "Wrote {.path {out_dir}}/gini_deltas_{year}.csv ({nrow(ineq$gini)} rows)",
    "Wrote {.path {out_dir}}/share_deltas_{year}.csv ({nrow(ineq$shares)} rows)",
    "Wrote {.path {out_dir}}/income_deltas_{year}.csv ({nrow(inc_totals)} rows)"
  )
  if (!is.null(atr_dec) && nrow(atr_dec)) {
    fwrite(atr_dec, file.path(out_dir, sprintf("atr_decile_%d.csv", year)))
    msgs <- c(msgs,
      "Wrote {.path {out_dir}}/atr_decile_{year}.csv ({nrow(atr_dec)} rows)")
  }
  if (!is.null(decomp)) {
    fwrite(decomp, file.path(out_dir, sprintf("revenue_decomp_%d.csv", year)))
    msgs <- c(msgs,
      "Wrote {.path {out_dir}}/revenue_decomp_{year}.csv ({nrow(decomp)} rows)")
  }
  cli::cli_inform(msgs)

  write_excel_bundle(
    out_dir = out_dir, year = year,
    rev = rev, gini = ineq$gini, shares = ineq$shares, inc = inc_totals,
    decomp = decomp,
    output_root = output_root, runscript_path = runscript_path,
    argv = argv
  )

  list(revenue = rev, gini = ineq$gini, shares = ineq$shares,
       income = inc_totals, decomp = decomp)
}

# Pull the policy year from the runscript's `years` column. Assumes all
# rows share the same range and the policy year is the upper bound.
.runscript_policy_year <- function(runscript_path) {
  rs <- fread(runscript_path)
  parts <- as.integer(strsplit(rs$years[1], ":")[[1]])
  parts[length(parts)]
}

if (!interactive() && sys.nframe() == 0L) {
  aggregate_tax_sim_output(argv = commandArgs(trailingOnly = TRUE))
}
