# Assemble the deliverable tables and figures from the aggregator output
# and the orchestrator's per-variant macro summary.
#
# Inputs:
#   - results/aggregates/{revenue,gini,share}_deltas_<year>.csv  (from 08)
#   - <runscript_path-without-.csv>_macro.csv                  (from 00)
#   - <runscript_path>                                         (from 00)
# Outputs (under out_dir, default results/aggregates/):
#   - revenue_grid_<year>.csv      long form: (variant, labor, realization
#                                              and their *_label factors,
#                                              instrument) + delta with
#                                              macro CIT delta layered in.
#   - revenue_grid_wide_<year>.csv wide form: scenario_id + axis pairs ×
#                                             instrument.
#   - decile_panel_<year>.csv      long form: (variant, labor, realization
#                                              and their *_label factors,
#                                              income_concept, decile,
#                                              share_baseline, share_cf,
#                                              delta).
#   - revenue_grid_<year>.pdf      bar chart per realization (only if
#                                  ggplot2 is available).
#   - decile_panel_<year>.pdf      faceted decile-share-delta panel
#                                  (only if ggplot2 is available).
#
# CIT note: Tax-Simulator does not modify revenues_corp_tax in our runs,
# so the per-instrument 'revenues_corp_tax' delta from 08 stays at 0.
# The macro CIT wedge from step B is added separately as
# 'macro_cit_delta'; the publishable bottom-line is total_with_macro_cit.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")
source("code/08_aggregate.R")

# Resolve a path inside the repo, robust to the caller's CWD. Walks up
# from getwd() until it finds the `.git` anchor at the repo root, then
# returns <root>/<relpath>. Falls back to the bare `relpath` if no
# anchor is reachable (e.g. running outside a checkout), so callers can
# still file.exists()-test the result.
.resolve_repo_path <- function(relpath) {
  dir <- normalizePath(getwd(), mustWork = FALSE)
  repeat {
    if (file.exists(file.path(dir, ".git"))) {
      return(file.path(dir, relpath))
    }
    parent <- dirname(dir)
    if (parent == dir) return(relpath)
    dir <- parent
  }
}

# scenario_id format is ai_<variant>_<share_mode>_<labor>_<realization>,
# e.g. ai_M_R_S0_V1 (Moderate, reallocate) or ai_M_F_S0_V1 (Moderate,
# fixed labor-capital share). Parses to a 4-column data.table (drops
# "baseline" rows).
.parse_scenario_axes <- function(scenario_ids) {
  m <- regmatches(
    scenario_ids,
    regexec(.scenario_id_regex(), scenario_ids)
  )
  axes <- vapply(m, function(parts) {
    if (length(parts) < 5L) rep(NA_character_, 4L) else parts[2:5]
  }, character(4))
  # `_LO`/`_CO` decomposition IDs are *meant* to parse to NA here (they
  # are joined back by base ID downstream, never shown as grid rows).
  # Anything else that fails to parse is drift — a scenario silently
  # vanishing from the deliverable — so say it out loud.
  unexpected <- scenario_ids[
    is.na(axes[1, ]) &
      scenario_ids != "baseline" &
      !grepl(.flavor_suffix_regex(), scenario_ids)
  ]
  if (length(unexpected)) {
    cli::cli_warn(c(
      "{length(unexpected)} scenario ID{?s} did not parse against the axis registry and will be DROPPED from the deliverable grid.",
      x = "{.val {unexpected}}.",
      i = "If these are new axis codes, register them in the axis registry in {.path code/00_utils.R} first."
    ))
  }
  # All four axes are factors with explicit level orders so downstream
  # `order()` and ggplot fill / facet aesthetics carry the intended
  # narrative ordering (Slow→Rapid, Reallocate→Fixed, S0→S3, V1)
  # instead of falling back to alphabetical.
  data.table(
    scenario_id = scenario_ids,
    variant     = factor(axes[1, ], levels = names(.AXIS_VARIANTS)),
    share_mode  = factor(axes[2, ], levels = names(.AXIS_SHARE_MODES)),
    labor       = factor(axes[3, ], levels = names(.AXIS_LABOR)),
    realization = factor(axes[4, ], levels = names(.AXIS_REALIZATION))
  )
}

# Attach human-readable label columns (factors) next to the code
# columns. Single source of truth: .build_scenario_guide()'s `name`
# column. Modifies `dt` in place; returns `dt` for chaining.
.attach_axis_labels <- function(dt) {
  guide <- .build_scenario_guide()
  lookup <- function(axis_name) {
    g <- guide[axis == axis_name]
    setNames(g$name, g$code)
  }
  v_map  <- lookup("variant")
  sm_map <- lookup("share_mode")
  l_map  <- lookup("labor")
  r_map  <- lookup("realization")

  dt[, variant_label     := factor(v_map[as.character(variant)],
                                   levels = v_map)]
  if ("share_mode" %in% names(dt)) {
    dt[, share_mode_label := factor(sm_map[as.character(share_mode)],
                                    levels = sm_map)]
  }
  dt[, labor_label       := factor(l_map[as.character(labor)],
                                   levels = l_map)]
  dt[, realization_label := factor(r_map[as.character(realization)],
                                   levels = r_map)]

  axis_cols <- c("variant", "variant_label",
                 "share_mode", "share_mode_label",
                 "labor", "labor_label",
                 "realization", "realization_label")
  present   <- intersect(axis_cols, names(dt))
  others    <- setdiff(names(dt), present)
  scenario_first <- "scenario_id" %in% others
  if (scenario_first) {
    others <- setdiff(others, "scenario_id")
    setcolorder(dt, c("scenario_id", present, others))
  } else {
    setcolorder(dt, c(present, others))
  }
  dt
}

# Read the orchestrator's macro summary and the runscript, return a
# scenario-indexed table with macro CIT delta per cell. Unparseable
# scenario IDs (e.g. legacy runs) get NA macro fields and are dropped
# from the deliverable.
.load_macro_per_scenario <- function(runscript_path) {
  macro_path <- sub("\\.csv$", "_macro.csv", runscript_path)
  if (!file.exists(macro_path)) {
    cli::cli_abort(c(
      "Macro summary not found at {.path {macro_path}}.",
      i = "Re-run {.run Rscript code/00_ai_fiscal_sim.R} to regenerate."
    ))
  }
  macro <- fread(macro_path)
  # Convert raw-dollar macro columns to $ billions so the join with the
  # microsim deltas (which 08 emits in $B, mirroring Tax-Simulator's
  # receipts.csv units) lines up. Only the columns 09 actually consumes
  # are converted; K0_dollar / Y0_dollar in the source CSV remain in raw
  # $ for the parameters sheet of 08's bundle.
  macro[, c("X", "X_to_units", "delta_R_CIT", "L0_dollar") :=
          lapply(.SD, function(x) x / 1e9),
        .SDcols = c("X", "X_to_units", "delta_R_CIT", "L0_dollar")]
  # Gross labor expansion implied by the (variant, share_mode) pair
  # (mirrors shock_labor()'s L1d = L0d * (1 + alpha * gk)).
  macro[, delta_L_dollar := L0_dollar * alpha * gk]
  rs    <- fread(runscript_path)
  axes  <- .parse_scenario_axes(rs$ID)
  axes  <- axes[!is.na(variant)]
  # Coerce join columns to character (axes carries factors). Keep the
  # factor versions on `axes`; the join writes new char columns we drop
  # after merging.
  axes[, `:=`(variant_chr = as.character(variant),
              share_mode_chr = as.character(share_mode))]
  macro_keep <- macro[, .(variant_chr = variant,
                          share_mode_chr = share_mode,
                          X, X_to_units, delta_R_CIT, eta_corp,
                          kappa_corp, cit_statutory,
                          L0_dollar, delta_L_dollar)]
  out <- merge(axes, macro_keep,
               by = c("variant_chr", "share_mode_chr"),
               all.x = TRUE)
  out[, c("variant_chr", "share_mode_chr") := NULL]
  # A parsed scenario with no macro row (stale macro CSV after a grid
  # edit; partial rerun) would carry delta_R_CIT = NA, and
  # total_with_macro_cit downstream would silently become NA in the
  # publishable bundle.
  unmatched <- out[is.na(delta_R_CIT), scenario_id]
  if (length(unmatched)) {
    cli::cli_abort(c(
      "{length(unmatched)} scenario{?s} found no (variant, share_mode) row in the macro summary.",
      x = "{.val {unmatched}}.",
      i = "The macro CSV at {.path {macro_path}} is stale relative to the runscript - re-run the orchestrator."
    ))
  }
  out
}

# Wide ΔR grid: one row per scenario_id, columns for each microsim
# instrument plus macro_cit_delta and total_with_macro_cit. Long form is
# also written for downstream filters / plotting. When `decomp` is
# supplied (from build_revenue_decomp_table), the bottom-line
# decomposition is added as `total_labor`, `total_capital`,
# `total_interaction` columns on `wide` (and corresponding rows on long).
build_revenue_deliverable <- function(rev_long, macro_per_scn, decomp = NULL) {
  axis_keys <- c("scenario_id", "variant", "share_mode", "labor", "realization")

  # Long form augmented with axes + macro CIT row per scenario.
  rev <- merge(rev_long,
               macro_per_scn[, c(axis_keys, "delta_R_CIT"), with = FALSE],
               by = "scenario_id", all.x = TRUE)

  cit_rows <- unique(macro_per_scn[, .(
    scenario_id, variant, share_mode, labor, realization,
    instrument     = "macro_cit_delta",
    baseline       = NA_real_,
    counterfactual = NA_real_,
    delta          = delta_R_CIT,
    delta_R_CIT
  )])

  long <- rbind(
    rev[, .(scenario_id, variant, share_mode, labor, realization, instrument,
            baseline, counterfactual, delta, delta_R_CIT)],
    cit_rows
  )

  # Tripwire against CIT double-counting: layering the off-microsim
  # delta_R_CIT on top assumes Tax-Simulator never moves corporate-tax
  # revenue in our (household-only) counterfactuals. The moment a
  # capital module models CIT inside the microsim (v2 entity-tax stage,
  # docs/v2_architecture.md §4), this must fail rather than silently
  # add the wedge twice.
  corp_moved <- rev[instrument == "revenues_corp_tax" & abs(delta) > 1e-9,
                    unique(scenario_id)]
  if (length(corp_moved)) {
    cli::cli_abort(c(
      "Microsim corporate-tax deltas are non-zero, but the macro CIT wedge is about to be layered on top.",
      x = "{length(corp_moved)} scenario{?s}, e.g. {.val {head(corp_moved, 3)}}.",
      i = "Double-counting risk: zero the microsim CIT channel or disable the {.field delta_R_CIT} layering."
    ))
  }

  microsim_total <- rev[instrument == "total",
                        .(scenario_id, microsim_total = delta)]
  total_with_cit <- merge(microsim_total,
                          macro_per_scn[, .(scenario_id, delta_R_CIT)],
                          by = "scenario_id")
  total_with_cit[, delta := microsim_total + delta_R_CIT]
  total_with_cit <- merge(
    total_with_cit,
    macro_per_scn[, .(scenario_id, variant, share_mode, labor, realization)],
    by = "scenario_id"
  )

  long <- rbind(
    long,
    total_with_cit[, .(scenario_id, variant, share_mode, labor, realization,
                       instrument     = "total_with_macro_cit",
                       baseline       = NA_real_,
                       counterfactual = NA_real_,
                       delta          = delta,
                       delta_R_CIT    = delta_R_CIT)]
  )

  if (!is.null(decomp)) {
    decomp_total <- decomp[instrument == "total"]
    decomp_total <- merge(
      decomp_total,
      macro_per_scn[, .(scenario_id, variant, share_mode, labor, realization,
                        delta_R_CIT)],
      by = "scenario_id"
    )
    pieces <- c(total_labor = "delta_labor",
                total_capital = "delta_capital",
                total_interaction = "interaction")
    for (out_name in names(pieces)) {
      long <- rbind(long, decomp_total[, .(
        scenario_id, variant, share_mode, labor, realization,
        instrument     = out_name,
        baseline       = NA_real_,
        counterfactual = NA_real_,
        delta          = get(pieces[[out_name]]),
        delta_R_CIT
      )])
    }
  }

  wide <- dcast(long,
                scenario_id + variant + share_mode + labor + realization
                  ~ instrument,
                value.var = "delta")

  long <- .attach_axis_labels(long)
  wide <- .attach_axis_labels(wide)

  list(long = long[order(variant, share_mode, labor, realization, instrument)],
       wide = wide[order(variant, share_mode, labor, realization)])
}

# Paired comparison of share-mode twins. For each (variant, labor,
# realization) cell, joins the R (reallocate) and F (fixed share) rows
# of the revenue_grid_wide and reports the bottom-line ΔR under each,
# the reallocation delta (R - F), and its share of the R bottom line.
# Returns NULL when fewer than two share modes were run.
build_share_mode_comparison <- function(rev_wide) {
  if (!"share_mode" %in% names(rev_wide)) return(NULL)
  if (uniqueN(rev_wide$share_mode) < 2L) return(NULL)

  key_cols <- c("variant", "variant_label", "labor", "labor_label",
                "realization", "realization_label")
  cast_input <- rev_wide[, c(key_cols, "share_mode", "scenario_id",
                             "total_with_macro_cit"), with = FALSE]

  totals <- dcast(
    cast_input, ... ~ share_mode,
    value.var = c("scenario_id", "total_with_macro_cit"),
    fun.aggregate = function(x) x[1]
  )

  if (!all(c("total_with_macro_cit_R", "total_with_macro_cit_F") %in%
           names(totals))) return(NULL)

  setnames(totals,
           c("scenario_id_R", "scenario_id_F",
             "total_with_macro_cit_R", "total_with_macro_cit_F"),
           c("scenario_id_reallocate", "scenario_id_fixed",
             "total_R", "total_F"))
  totals <- totals[!is.na(total_R) & !is.na(total_F)]
  if (!nrow(totals)) return(NULL)

  totals[, reallocation_delta := total_R - total_F]
  totals[, reallocation_share := fifelse(total_R == 0, NA_real_,
                                         reallocation_delta / total_R)]
  setcolorder(totals, c(key_cols,
                        "scenario_id_reallocate", "scenario_id_fixed",
                        "total_R", "total_F",
                        "reallocation_delta", "reallocation_share"))
  totals[order(variant, labor, realization)]
}

# Decile panel: one row per (scenario_id, income_concept, decile).
build_decile_deliverable <- function(shares_long, macro_per_scn) {
  d <- shares_long[group_type == "decile"]
  d <- merge(d,
             macro_per_scn[, .(scenario_id, variant, share_mode, labor,
                               realization)],
             by = "scenario_id", all.x = TRUE)
  d <- d[!is.na(variant)]
  d[, decile_num := as.integer(sub("decile_", "", group))]
  out <- d[, .(scenario_id, variant, share_mode, labor, realization,
               income_concept,
               decile = decile_num,
               share_baseline, share_cf, delta)]
  .attach_axis_labels(out)
  out[order(variant, share_mode, labor, realization, income_concept, decile)]
}

# Revenue-to-GDP table for the publishable bundle. One row per
# scenario_id. Two pairs of columns:
#
#   *_model — uses Tax-Simulator microsim total (baseline) and microsim
#     total + macro CIT wedge (counterfactual) over the yaml-anchored
#     baseline-year GDP and baseline_gdp * (1 + g_y). The microsim
#     baseline has corporate-tax revenue = 0 by construction, so this
#     pair understates the level by ~1.3 pp (the missing baseline CIT)
#     but the within-model delta is internally consistent.
#
#   *_cbo   — anchors the baseline to CBO's published rev/GDP
#     (cbo_baseline.rev_to_gdp_baseline_year). Treats the model's
#     bottom-line ΔR (microsim cf + macro CIT − microsim baseline) as an
#     additive change on top of the CBO level. Defensible under the
#     assumption that revenue streams the model omits (notably the
#     baseline CIT level) don't respond to the AI shock except through
#     channels already in ΔR (macro_cit_delta).
#
# Denominator scales by (1 + g_y) on the counterfactual side per Step
# B's macro accounting: AI productivity bump routes through GDP. g_y is
# variant-specific.
build_revenue_to_gdp <- function(rev_long, cell_params,
                                  gdp_baseline_year_B,
                                  cbo_rev_to_gdp_baseline_year) {
  rev_total <- rev_long[instrument == "total",
                        .(scenario_id, variant, variant_label,
                          share_mode, share_mode_label,
                          labor, labor_label,
                          realization, realization_label,
                          microsim_baseline       = baseline,
                          microsim_counterfactual = counterfactual,
                          delta_R_CIT             = delta_R_CIT)]
  gy_per_variant <- unique(cell_params[, .(variant, g_y)])
  rev_total <- merge(rev_total, gy_per_variant, by = "variant",
                     all.x = TRUE)

  rev_total[, baseline_revenue_B  := microsim_baseline]
  rev_total[, scenario_revenue_B  := microsim_counterfactual + delta_R_CIT]
  rev_total[, baseline_gdp_B      := gdp_baseline_year_B]
  rev_total[, scenario_gdp_B      := gdp_baseline_year_B * (1 + g_y)]

  # Model-internal ratios (microsim baseline; CIT = 0 by construction).
  rev_total[, baseline_rev_to_gdp := baseline_revenue_B / baseline_gdp_B]
  rev_total[, scenario_rev_to_gdp := scenario_revenue_B / scenario_gdp_B]
  rev_total[, delta_rev_to_gdp    := scenario_rev_to_gdp - baseline_rev_to_gdp]

  # CBO-anchored ratios. Baseline level = CBO's published rev/GDP applied
  # to baseline_gdp_B; the model's ΔR (scenario_revenue_B − baseline_revenue_B)
  # is added on top.
  rev_total[, baseline_revenue_B_cbo :=
              cbo_rev_to_gdp_baseline_year * baseline_gdp_B]
  rev_total[, scenario_revenue_B_cbo :=
              baseline_revenue_B_cbo +
                (scenario_revenue_B - baseline_revenue_B)]
  rev_total[, baseline_rev_to_gdp_cbo := cbo_rev_to_gdp_baseline_year]
  rev_total[, scenario_rev_to_gdp_cbo :=
              scenario_revenue_B_cbo / scenario_gdp_B]
  rev_total[, delta_rev_to_gdp_cbo    :=
              scenario_rev_to_gdp_cbo - baseline_rev_to_gdp_cbo]

  rev_total[, .(
    scenario_id,
    variant, variant_label,
    share_mode, share_mode_label,
    labor, labor_label,
    realization, realization_label,
    g_y,
    baseline_revenue_B, scenario_revenue_B,
    baseline_gdp_B, scenario_gdp_B,
    baseline_rev_to_gdp, scenario_rev_to_gdp, delta_rev_to_gdp,
    baseline_revenue_B_cbo, scenario_revenue_B_cbo,
    baseline_rev_to_gdp_cbo, scenario_rev_to_gdp_cbo,
    delta_rev_to_gdp_cbo
  )][order(scenario_id)]
}

# Variant code -> Karger label. Used by .write_key_parameters_sheet to
# title the per-variant columns of the key_parameters layout.
# Alias of the axis registry (00_utils.R) kept for existing call sites.
.VARIANT_LABEL_MAP <- .AXIS_VARIANTS

# Tidy macro-summary table that drives the publishable bundle's
# `key_parameters` sheet. Returns a list:
#   $tbl   data.table: one row per shock variant present in cell_params
#                       (filtered to share_mode = R, reallocate). Columns:
#                         variant            (factor, S < M < R)
#                         r_ai_annual        Karger Table 19 input (or NA
#                                            when shock_params is NULL)
#                         theta_1_K          post-shock capital share (s_1
#                                            in 02_params.R)
#                         theta_1_L          post-shock labor share
#                                            (1 - s_1)
#                         g_y                AI bump on GDP, cumulative
#                                            over the Karger horizon and
#                                            above the CBO no-AI baseline
#                         g_k                implied capital growth bump
#                         labor_growth       L1_B / L0_B - 1
#                         S0, S2, S3         sigma per labor scenario
#   $meta  list: scalars surfaced as footer notes
#                         baseline_labor_share, k_inequality
#
# F twins, when present, get their own row in cell_params and surface
# in share_mode_comparison. S0 carries NA in cell_params (no dispersion
# shift) and is reported as 1.0 here.
#
# `shock_params` is the parsed `shock` slice of scenario_params.yaml
# (i.e., the result of `yaml::read_yaml(yaml_path)$shock`). When NULL,
# the r_ai_annual column is filled with NA and the writer suppresses
# that row from the sheet.
build_key_parameters_table <- function(cell_params, shock_params = NULL,
                                        baseline_year = NULL,
                                        horizon_start_year = NULL) {
  cp <- as.data.table(cell_params)
  sm_pref <- if ("R" %in% cp$share_mode) "R" else cp$share_mode[1]
  cp      <- cp[share_mode == sm_pref]

  macro <- cp[, .(
    theta_0_L    = theta_0_L[1],
    theta_1_K    = theta_1_K[1],
    theta_1_L    = theta_1_L[1],
    g_y          = g_y[1],
    g_k          = g_k[1],
    labor_growth = L1_B[1] / L0_B[1] - 1
  ), by = variant]

  sigma <- dcast(
    cp[labor_scenario %in% c("S0", "S2", "S3"),
       .(variant, labor_scenario, sigma)],
    variant ~ labor_scenario,
    value.var = "sigma"
  )
  for (col in c("S0", "S2", "S3")) {
    if (!col %in% names(sigma)) sigma[, (col) := NA_real_]
  }
  sigma[is.na(S0), S0 := 1]

  out <- merge(macro, sigma, by = "variant", sort = FALSE)

  # Karger input: r_ai_annual. Pulled from the yaml slice the caller
  # passes in; we never invert the (g_y, horizon, CBO-baseline-path)
  # arithmetic because that would couple this writer to an off-bundle
  # parameter (cum_base).
  r_by_variant <- function(v) {
    if (is.null(shock_params)) return(NA_real_)
    val <- shock_params$variants[[as.character(v)]]$r_ai_annual
    if (is.null(val)) NA_real_ else as.numeric(val)
  }
  out[, r_ai_annual := vapply(as.character(variant), r_by_variant, numeric(1))]

  variant_order <- intersect(c("S", "M", "R"), as.character(out$variant))
  out[, variant := factor(variant, levels = variant_order)]
  out <- out[order(variant)]

  # Metadata for the footer / subtitle rows.
  baseline_labor_share <- out$theta_0_L[1]
  # k = (1 - sigma_S2) / g_y, recovered from any variant where g_y != 0.
  # Falls back to NA when the only available cells have g_y == 0 (e.g. a
  # degenerate single-variant smoke run with the S variant pre-rounded
  # to zero), in which case the writer omits the k annotation.
  has_g <- !is.na(out$g_y) & out$g_y != 0
  k_inequality <- if (any(has_g)) {
    (1 - out$S2[which(has_g)[1]]) / out$g_y[which(has_g)[1]]
  } else NA_real_

  list(
    tbl  = out[, .(variant, r_ai_annual, theta_1_K, theta_1_L,
                   g_y, g_k, labor_growth, S0, S2, S3)],
    meta = list(
      baseline_labor_share = baseline_labor_share,
      k_inequality         = k_inequality,
      share_mode           = sm_pref,
      baseline_year        = baseline_year,
      horizon_start_year   = horizon_start_year
    )
  )
}

# Write the key-parameters layout to `sheet_name` on `wb`. The sheet
# mixes label and numeric cells on the same row, carries a merged
# header band over the variant columns, and uses percent formatting on
# the growth-rate / share blocks plus a 3-decimal numeric format on the
# sigma block — none of which the generic .add_xlsx_sheet wrapper
# handles — so this writer goes through openxlsx directly.
#
# Takes the list returned by build_key_parameters_table (`$tbl` data
# row plus `$meta` scalars for the footer notes). Rows that depend on
# missing inputs (notably r_ai_annual when shock_params was NULL) are
# silently suppressed and downstream rows shift up to fill the gap.
.write_key_parameters_sheet <- function(wb, sheet_name, key_params,
                                         header_text = "AI Adoption Scenarios via Karger et al. (2026)") {
  kp   <- key_params$tbl
  meta <- key_params$meta
  variant_codes  <- as.character(kp$variant)
  variant_labels <- unname(.VARIANT_LABEL_MAP[variant_codes])
  n_var          <- length(variant_codes)
  if (n_var < 1L) return(invisible(NULL))

  # Year-dependent labels are driven by baseline_year / horizon_start_year
  # (from the yaml via build_key_parameters_table) rather than hardcoded
  # literals, so a rolled-forward baseline relabels the sheet correctly.
  # Fall back to generic, year-free phrasing if either is unavailable.
  by_yr  <- meta$baseline_year
  hsy_yr <- meta$horizon_start_year
  have_yrs <- is.numeric(by_yr) && length(by_yr) == 1L && !is.na(by_yr) &&
    is.numeric(hsy_yr) && length(hsy_yr) == 1L && !is.na(hsy_yr) &&
    by_yr > hsy_yr
  karger_hdr <- if (have_yrs) {
    sprintf("Karger AI-adoption inputs (%d-year horizon, %d-%d)",
            by_yr - hsy_yr, hsy_yr, by_yr)
  } else "Karger AI-adoption inputs (over the Karger horizon)"
  cap_share_lbl  <- if (have_yrs) sprintf("%d capital share (s_1)", by_yr)
                    else "Horizon capital share (s_1)"
  lab_share_lbl  <- if (have_yrs) sprintf("%d labor share (1 - s_1)", by_yr)
                    else "Horizon labor share (1 - s_1)"
  base_share_yr  <- if (have_yrs) sprintf(" (%d)", hsy_yr) else ""

  openxlsx::addWorksheet(wb, sheet_name)

  num_cols <- 2:(1 + n_var)
  notes_span <- 1:(1 + n_var)

  # Styles.
  title_style    <- openxlsx::createStyle(textDecoration = "bold",
                                          halign = "center",
                                          border = "Bottom")
  header_style   <- openxlsx::createStyle(textDecoration = "bold",
                                          halign = "center")
  code_style     <- openxlsx::createStyle(fontSize = 9,
                                          halign = "center",
                                          fontColour = "#555555")
  section_style  <- openxlsx::createStyle(textDecoration = "bold",
                                          fontSize = 11)
  caption_style  <- openxlsx::createStyle(textDecoration = "italic",
                                          fontSize = 10,
                                          fontColour = "#444444")
  notes_style    <- openxlsx::createStyle(textDecoration = "italic",
                                          fontSize = 10,
                                          fontColour = "#444444",
                                          wrapText = TRUE,
                                          valign = "top")
  pct1_style     <- openxlsx::createStyle(numFmt = "0.0%",
                                          halign = "right")
  pct2_style     <- openxlsx::createStyle(numFmt = "0.00%",
                                          halign = "right")
  num_style      <- openxlsx::createStyle(numFmt = "0.000",
                                          halign = "right")
  label_style    <- openxlsx::createStyle(halign = "left")

  # Tracked row cursor. Each writer-step advances it, so suppressing an
  # earlier row (e.g. the r_ai_annual line when shock_params was NULL)
  # cleanly shifts everything below up.
  cur <- 1L
  bump <- function(n = 1L) { cur <<- cur + n; invisible(cur) }

  put_section <- function(text) {
    openxlsx::writeData(wb, sheet_name, x = text,
                        startRow = cur, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, section_style,
                       rows = cur, cols = 1, stack = TRUE)
    bump()
  }

  put_caption <- function(text) {
    openxlsx::writeData(wb, sheet_name, x = text,
                        startRow = cur, startCol = 1)
    openxlsx::mergeCells(wb, sheet_name, rows = cur, cols = notes_span)
    openxlsx::addStyle(wb, sheet_name, caption_style,
                       rows = cur, cols = 1, stack = TRUE)
    bump()
  }

  put_data_row <- function(label, values, style) {
    openxlsx::writeData(wb, sheet_name, x = label,
                        startRow = cur, startCol = 1)
    openxlsx::writeData(wb, sheet_name,
                        x = matrix(values, nrow = 1),
                        startRow = cur, startCol = 2, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, label_style,
                       rows = cur, cols = 1, stack = TRUE)
    openxlsx::addStyle(wb, sheet_name, style,
                       rows = cur, cols = num_cols,
                       gridExpand = TRUE, stack = TRUE)
    bump()
  }

  put_note <- function(text) {
    openxlsx::writeData(wb, sheet_name, x = text,
                        startRow = cur, startCol = 1)
    openxlsx::mergeCells(wb, sheet_name, rows = cur, cols = notes_span)
    openxlsx::addStyle(wb, sheet_name, notes_style,
                       rows = cur, cols = 1, stack = TRUE)
    openxlsx::setRowHeights(wb, sheet_name, rows = cur, heights = 30)
    bump()
  }

  put_blank <- function() bump()

  # Row 1: merged title.
  openxlsx::writeData(wb, sheet_name, x = header_text,
                      startRow = cur, startCol = 2)
  openxlsx::mergeCells(wb, sheet_name, rows = cur, cols = num_cols)
  openxlsx::addStyle(wb, sheet_name, title_style,
                     rows = cur, cols = 2, stack = TRUE)
  bump()

  # Row 2: variant labels (Slow / Moderate / Rapid).
  openxlsx::writeData(wb, sheet_name,
                      x = matrix(variant_labels, nrow = 1),
                      startRow = cur, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, header_style,
                     rows = cur, cols = num_cols,
                     gridExpand = TRUE, stack = TRUE)
  bump()

  # Row 3: variant codes in parentheses (improvement F).
  openxlsx::writeData(wb, sheet_name,
                      x = matrix(sprintf("(%s)", variant_codes), nrow = 1),
                      startRow = cur, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, code_style,
                     rows = cur, cols = num_cols,
                     gridExpand = TRUE, stack = TRUE)
  bump()
  put_blank()

  # Karger inputs section (improvements E + B).
  put_section(karger_hdr)
  if (!all(is.na(kp$r_ai_annual))) {
    put_data_row("Annual GDP growth under AI (r_ai_annual)",
                 kp$r_ai_annual, pct1_style)
  }
  put_data_row(cap_share_lbl,
               kp$theta_1_K, pct1_style)
  put_data_row(lab_share_lbl,
               kp$theta_1_L, pct1_style)
  put_blank()

  # Derived bumps section (improvement A: cumulative, above-baseline).
  put_section("Derived growth bumps")
  put_caption("Cumulative over the Karger 5-year horizon, above the CBO no-AI baseline path.")
  put_data_row("GDP                  (g_y)", kp$g_y,          pct2_style)
  put_data_row("Capital              (g_k)", kp$g_k,          pct2_style)
  put_data_row("Labor                (L_1/L_0 - 1)",
               kp$labor_growth, pct2_style)
  put_blank()

  # Sigma section (improvement D: explicit formula + k value).
  put_section("Labor-income inequality parameter (sigma)")
  k_text <- if (is.finite(meta$k_inequality)) {
    sprintf("sigma = 1 \U00B1 k · g_y on log(YiL);   k = %.3f",
            meta$k_inequality)
  } else {
    "sigma = 1 \U00B1 k · g_y on log(YiL)"
  }
  put_caption(k_text)
  put_data_row("Compressive",  kp$S2, num_style)
  put_data_row("Proportional", kp$S0, num_style)
  put_data_row("Expansive",    kp$S3, num_style)
  put_blank()

  # Notes block (improvements C + G).
  put_section("Notes")
  baseline_share_pct <- if (is.finite(meta$baseline_labor_share)) {
    sprintf("%.1f%%", 100 * meta$baseline_labor_share)
  } else {
    "n/a"
  }
  share_mode_text <- if (identical(meta$share_mode, "R")) {
    "Share mode shown: Reallocate (R). The Karger labor-share decline is imposed. Fixed-share (F) twins live in the share_mode_comparison sheet."
  } else if (identical(meta$share_mode, "F")) {
    "Share mode shown: Fixed (F). The labor-capital split is held at baseline (g_k = g_y, alpha = 1). Reallocate (R) twins live in the share_mode_comparison sheet."
  } else {
    sprintf("Share mode shown: %s.", meta$share_mode)
  }
  put_note(sprintf(
    paste0("Baseline labor share%s: %s. Source: ",
           "Karger, Buehler, Cox, Saint-Jacques, and Bjorkegren (2026), ",
           "CBO (2026), and TBL Calculations."),
    base_share_yr, baseline_share_pct))
  put_note(share_mode_text)
  put_note(paste0(
    "Negative labor growth occurs when the labor share falls fast enough ",
    "to outweigh productivity gains over the horizon. Aggregate labor ",
    "income levels remain positive - see L0_B / L1_B in cell_params."))

  # Column widths: a roomy label column, then uniform variant columns.
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 46)
  openxlsx::setColWidths(wb, sheet_name, cols = num_cols, widths = 14)

  invisible(NULL)
}

# Per-column dictionary for 09's publishable bundle data sheets.
.build_variable_list_publishable <- function(include_decomp = FALSE) {
  base <- data.table(
    sheet = c(rep("revenue_grid_wide", 12),
              rep("revenue_grid_long", 5),
              rep("decile_panel", 5)),
    column = c("scenario_id",
               "variant", "variant_label",
               "share_mode", "share_mode_label",
               "labor", "labor_label",
               "realization", "realization_label",
               "<instrument>", "macro_cit_delta", "total_with_macro_cit",
               "scenario_id + axis columns (codes & labels)", "instrument",
               "baseline / counterfactual", "delta", "delta_R_CIT",
               "scenario_id + axis columns (codes & labels)", "income_concept",
               "decile", "share_baseline / share_cf", "delta"),
    description = c(
      "Scenario identifier in the form ai_<variant>_<share_mode>_<labor>_<realization> (for example, ai_M_R_S0_V1 is the Moderate shock with the labor-capital share reallocating per Karger; ai_M_F_S0_V1 is the paired twin with the labor-capital share held at baseline). Realization is V1 (mechanical) for every cell in the release grid. See the scenario_guide sheet for the meaning of each code.",
      "Shock variant code (S = Slow, M = Moderate, R = Rapid). Controls the size of the 5-year productivity and capital-share targets.",
      "Human-readable label for the shock variant, used on plot axes and tables: Slow, Moderate, or Rapid.",
      "Factor-share mode. R = reallocate (Karger labor-share decline). F = fixed (labor-capital split preserved; same gy as R, no share reallocation).",
      "Human-readable label for the share mode: Reallocate or Fixed share.",
      "Labor distribution scenario code. S0 scales all wages proportionally; S2 compresses the wage distribution toward the mean; S3 stretches it away from the mean.",
      "Human-readable label for the labor scenario: Proportional, Compressive, or Expansive.",
      "Long-term capital gains realization treatment. The release grid uses V1 (mechanical: all new gains are realized in-year) exclusively.",
      "Human-readable label for the realization treatment: Mechanical.",
      "One column per Tax-Simulator revenue or outlay instrument (income tax, payroll tax, refundable credit outlays, corporate tax, estate tax, VAT, and other receipts), plus a 'total' column that nets refundable credits out of revenues. All values are in $ billions. The corporate-tax column is zero by construction here because the corporate-tax response is computed outside Tax-Simulator and lives in the macro_cit_delta column.",
      "Additional federal corporate-tax revenue collected on the new capital flow, in $ billions. Same value for every cell sharing a (variant, share_mode) pair. See the corporate_tax sheet for the derivation.",
      "BOTTOM-LINE revenue delta in $ billions: the Tax-Simulator total plus the macro CIT delta. This is the publishable revenue figure for the scenario.",

      "Scenario identifier plus the same eight axis columns (variant, variant_label, share_mode, share_mode_label, labor, labor_label, realization, realization_label) as the wide grid.",
      "Tax-Simulator instrument name, plus the synthetic rows 'total' (microsim sum), 'macro_cit_delta' (corporate tax computed outside Tax-Simulator), and 'total_with_macro_cit' (the publishable bottom line).",
      "Baseline and counterfactual dollar levels for the instrument, in $ billions. These are blank for the macro_cit_delta and total_with_macro_cit rows, which only carry a delta.",
      "Counterfactual minus baseline in $ billions. For the macro_cit_delta and total_with_macro_cit synthetic rows, this is the level itself.",
      "The cell's macro CIT delta in $ billions, repeated on every row for convenience. The value is constant within a scenario.",

      "Scenario identifier plus the same eight axis columns (variant, variant_label, share_mode, share_mode_label, labor, labor_label, realization, realization_label) as the wide grid.",
      "Income concept used to rank households into deciles: 'pretax' uses expanded income; 'aftertax' subtracts net income-tax liability. The macro CIT burden is already embedded because only the after-CIT capital flow is distributed to households inside the simulation.",
      "Decile of households ranked by the income concept, where 1 is the lowest tenth and 10 is the highest tenth.",
      "Share of total income held by the decile, expressed as a fraction between 0 and 1.",
      "Counterfactual share minus baseline share."
    )
  )
  smc_rows <- data.table(
    sheet = rep("share_mode_comparison", 4),
    column = c("scenario_id_reallocate / scenario_id_fixed",
               "total_R / total_F",
               "reallocation_delta",
               "reallocation_share"),
    description = c(
      "Scenario IDs for the paired Reallocate and Fixed-share runs sharing the same (variant, labor, realization). One row per (variant, labor, realization) cell.",
      "Bottom-line ΔR (total_with_macro_cit) in $ billions under share_mode = R (Karger reallocation) and share_mode = F (labor-capital share held at baseline).",
      "total_R - total_F in $ billions. The portion of the bottom-line ΔR attributable to the labor-capital reallocation channel; the productivity channel is identical on both sides.",
      "reallocation_delta / total_R, as a fraction. NA when total_R == 0."
    )
  )
  base <- rbind(base, smc_rows)

  key_params_rows <- data.table(
    sheet = rep("key_parameters", 5),
    column = c("(column headers)",
               "Karger AI-adoption inputs",
               "Derived growth bumps",
               "Labor-income inequality parameter (sigma)",
               "Notes block"),
    description = c(
      "One column per Karger shock variant - Slow (S), Moderate (M), Rapid (R). The variant code (S/M/R) is shown in parentheses under each label to cross-reference cell_params and the rest of the bundle.",
      "Karger Table 19 and Table 39 inputs that drive the scenario. r_ai_annual is the AI-conditional annual GDP growth rate from Table 19 (Total / median). 2030 capital share (s_1) and 2030 labor share (1 - s_1) come from Table 39. All three are sourced inputs, not derived. Pulled from config/scenario_params.yaml (shock slice).",
      "Cumulative growth bumps over the Karger 5-year horizon, expressed above the CBO no-AI baseline path (so a value of 0% means the AI shock contributes nothing on top of CBO at the horizon, not that the level is flat). g_y = AI bump on GDP; g_k = implied capital growth bump; labor row = L1_B / L0_B - 1. Negative labor values arise when the labor-share decline outweighs the productivity gain; aggregate labor income levels remain positive (see L0_B / L1_B in cell_params). All three rows are pulled from cell_params (share_mode = R).",
      "Ratio of post- to pre-shock standard deviation of log(YiL) on the positive subset. Compressive = sigma_S2 = 1 - k * g_y; Proportional = sigma_S0 = 1 (no dispersion shift); Expansive = sigma_S3 = 1 + k * g_y. Row labels match the labor_label column elsewhere in the bundle (Compressive = S2, Proportional = S0, Expansive = S3 in cell_params and scenario_id). k is the labor_inequality.k multiplier from config/scenario_params.yaml (default 1.0) and is reported in the sigma section caption.",
      "Three free-text rows explaining the baseline labor share (the Karger Table 39 anchor value, shown as a percentage), the share mode the sheet filters to (Reallocate vs. Fixed - see share_mode_comparison for the paired twin comparison), and the sign convention on the Labor row of the derived bumps section."
    )
  )

  cell_params_rows <- data.table(
    sheet = rep("cell_params", 21),
    column = c("variant", "share_mode", "labor_scenario",
               "theta_0_L", "theta_0_K", "theta_1_L", "theta_1_K",
               "g_y", "g_k", "alpha", "sigma",
               "L0_B", "L1_B", "K0_B", "K1_B",
               "X_B", "X_to_units_B", "kappa_corp", "cit_statutory",
               "eta_corp", "delta_R_CIT_B"),
    description = c(
      "Shock variant code (S = Slow, M = Moderate, R = Rapid).",
      "Factor-share mode. R = reallocate (Karger labor-share decline); F = fixed (s1 := 1 - L0, no factor-share shift).",
      "Labor distribution scenario: S0 (proportional), S2 (compressive), S3 (expansive).",
      "Baseline labor share of factor income, NIPA-based (= raw$shock$baseline_labor_share, default 0.555).",
      "Baseline capital share, 1 - theta_0_L (default 0.445).",
      "Post-shock labor share, 1 - theta_1_K. Equals theta_0_L under share_mode = F.",
      "Post-shock capital share. Equals the Karger Table 39 target under share_mode = R; theta_0_K under share_mode = F.",
      "AI productivity bump on top of the no-AI CBO baseline at the policy horizon. See §3.1 of the model doc.",
      "Implied normalized growth rate of capital (microsim dollars). See §3.2.",
      "Implied normalized growth rate of labor as a multiple of g_k. alpha = 1 under share_mode = F (no reallocation); alpha < 1 under share_mode = R.",
      "Ratio of post- to pre-shock standard deviation of log(YiL) on the positive subset. NA for S0; 1 - k * g_y for S2; 1 + k * g_y for S3. k from labor_inequality.k (default 1).",
      "Baseline aggregate labor income in microsim dollars ($ billions). Sum of weight × YiL across tax units.",
      "Post-shock aggregate labor income in $ billions. L0_B * (1 + alpha * g_k).",
      "Baseline aggregate capital income in microsim dollars ($ billions). Sum of weight × YiK.",
      "Post-shock aggregate capital income in $ billions. K0_B * (1 + g_k).",
      "Aggregate AI capital flow in $ billions, before the off-microsim CIT wedge. X = K1_B - K0_B.",
      "Aggregate capital flow that reaches tax units, in $ billions. CIT acts upstream of household realizations, so X reaches households in full: X_to_units = X.",
      "C-corp share of the capital base used in the CIT wedge (corporate.kappa_corp, narrow definition with S-corps stripped; see config/calibration/kappa_corp_calculation.csv).",
      "Statutory corporate income tax rate (corporate.cit_statutory, TCJA IRC §11). Cancels algebraically against eta_corp in delta_R_CIT; carried for transparency.",
      "Calibrated corporate-base scale factor. eta = cit_statutory * (K0$ * kappa_corp) / CBO_CIT_baseline$ so that the baseline-year CIT level matches CBO. Absorbs both the household-realized-vs-pre-realization wedge and the statutory-vs-effective gap. Constant within a (variant, share_mode) cell.",
      "Off-microsim CIT revenue change in $ billions. cit_statutory * kappa_corp * X / eta_corp ≡ X * CBO_CIT_baseline / K0$."
    )
  )
  base <- rbind(base, key_params_rows, cell_params_rows)

  rev_gdp_rows <- data.table(
    sheet = rep("revenue_to_gdp", 14),
    column = c("scenario_id + axis columns (codes & labels)",
               "g_y",
               "baseline_revenue_B", "scenario_revenue_B",
               "baseline_gdp_B", "scenario_gdp_B",
               "baseline_rev_to_gdp", "scenario_rev_to_gdp",
               "delta_rev_to_gdp",
               "baseline_revenue_B_cbo", "scenario_revenue_B_cbo",
               "baseline_rev_to_gdp_cbo", "scenario_rev_to_gdp_cbo",
               "delta_rev_to_gdp_cbo"),
    description = c(
      "Same axis columns as revenue_grid_wide.",
      "AI productivity bump over the Karger horizon; variant-specific.",
      "Tax-Simulator microsim total under the baseline scenario ($ billions). Sum across instruments from the 'total' row of revenue_grid_long. Has corporate-tax revenue = 0 by construction (CIT is modeled outside Tax-Simulator and only the AI-driven delta enters via macro_cit_delta).",
      "Microsim counterfactual total plus the off-microsim macro CIT wedge ($ billions). Equals baseline_revenue_B + 'total' row delta + 'macro_cit_delta' row delta from revenue_grid_long.",
      "Baseline nominal GDP at baseline_year ($ billions). Sourced from cbo_baseline.gdp_baseline_year_B in scenario_params.yaml.",
      "Counterfactual nominal GDP at baseline_year ($ billions). Equals baseline_gdp_B * (1 + g_y) — Step B's macro accounting routes the AI productivity bump through GDP.",
      "Model-internal baseline revenue / GDP, as a fraction (multiply by 100 for pp). Understates the published level by ~1.3 pp at the default baseline_year (2030) because the microsim baseline has CIT = 0; use baseline_rev_to_gdp_cbo for level comparisons.",
      "Model-internal counterfactual revenue / counterfactual GDP, as a fraction.",
      "scenario_rev_to_gdp - baseline_rev_to_gdp, in fractional points. Internally consistent but applies the GDP-growth dilution drag to the model's smaller baseline; use delta_rev_to_gdp_cbo for the publishable response.",
      "CBO-anchored baseline revenue level in $ billions. Equals cbo_baseline.rev_to_gdp_baseline_year * baseline_gdp_B — the level implied by CBO's published rev/GDP at baseline_year. Constant across cells.",
      "CBO-anchored counterfactual revenue level in $ billions. Equals baseline_revenue_B_cbo + (scenario_revenue_B - baseline_revenue_B). Adds the model's bottom-line ΔR (microsim cf + macro CIT − microsim baseline) on top of the CBO baseline, under the assumption that streams the model omits (notably the baseline CIT level) don't respond to the AI shock except through channels already captured in ΔR.",
      "CBO-anchored baseline revenue / GDP, as a fraction. Equals cbo_baseline.rev_to_gdp_baseline_year and is constant across cells.",
      "CBO-anchored counterfactual revenue / counterfactual GDP, as a fraction.",
      "scenario_rev_to_gdp_cbo - baseline_rev_to_gdp_cbo, in fractional points. Publishable response: anchors the baseline to CBO's level so the GDP-growth dilution drag is applied to a realistic revenue base. Algebraically equals ΔR / (GDP * (1 + g_y)) − cbo_baseline.rev_to_gdp_baseline_year * g_y / (1 + g_y), where ΔR = scenario_revenue_B - baseline_revenue_B."
    )
  )
  base <- rbind(base, rev_gdp_rows)

  if (!include_decomp) return(base)

  rbind(base, data.table(
    sheet = c(rep("revenue_grid_wide", 3), rep("revenue_decomp", 6)),
    column = c("total_labor", "total_capital", "total_interaction",
               "scenario_id", "instrument",
               "delta_labor", "delta_capital", "delta_both", "interaction"),
    description = c(
      "Portion of the bottom-line revenue change attributable to the labor side of the shock, in $ billions. Computed as the revenue change from running a labor-only counterfactual against baseline. Payroll tax mechanically counts as labor.",
      "Portion attributable to the capital side, in $ billions. Computed as the revenue change from running a capital-only counterfactual against baseline. Microsim only; the corporate-tax piece is reported separately in macro_cit_delta.",
      "Non-linear interaction term in $ billions: the joint shock total minus the labor-only and capital-only pieces. Captures bracket effects, AMT, and phase-outs that depend on both shocks happening together.",

      "Base scenario identifier (no _LO/_CO suffix). One row per (scenario x instrument).",
      "Tax-Simulator instrument name plus the synthetic 'total' row.",
      "Revenue change from a labor-only counterfactual versus baseline, in $ billions. Payroll tax mechanically counts as labor.",
      "Revenue change from a capital-only counterfactual versus baseline, in $ billions. The payroll component is essentially zero by construction.",
      "Revenue change from the joint counterfactual versus baseline, in $ billions. Equals the matching row in the long revenue grid.",
      "Non-linear interaction in $ billions: the joint delta minus the labor-only and capital-only deltas. Cannot be attributed cleanly to either side."
    )
  ))
}

# Publishable bundle: same metadata sheets as the microsim bundle plus
# the post-CIT-layered grid (wide + long) and decile panel. When
# `decomp` is non-NULL, an additional `revenue_decomp` sheet is added.
# When the run includes both R and F share modes, a
# `share_mode_comparison` sheet is added with the paired bottom-line
# revenue twin comparison.
write_publishable_excel_bundle <- function(out_dir, year,
                                            rev_long, rev_wide, decile,
                                            output_root, runscript_path,
                                            decomp = NULL,
                                            share_mode_comparison = NULL,
                                            revenue_to_gdp = NULL,
                                            argv = NULL) {
  ctx <- .init_xlsx_bundle(year, output_root, runscript_path, argv,
                           bundle_type = "Publishable (microsim + macro CIT layered)",
                           publishable = TRUE)
  if (is.null(ctx)) return(invisible(NULL))

  ctx$add_sheet("variable_list",
                .build_variable_list_publishable(
                  include_decomp = !is.null(decomp)
                ),
                wrap_cols = "description")
  ctx$add_sheet("revenue_grid_wide", rev_wide)
  ctx$add_sheet("revenue_grid_long", rev_long)
  ctx$add_sheet("decile_panel",      decile)
  if (!is.null(decomp)) ctx$add_sheet("revenue_decomp", decomp)
  if (!is.null(share_mode_comparison))
    ctx$add_sheet("share_mode_comparison", share_mode_comparison)
  if (!is.null(revenue_to_gdp))
    ctx$add_sheet("revenue_to_gdp", revenue_to_gdp)

  cell_params_fp <- sub("\\.csv$", "_cell_params.csv", runscript_path)
  if (file.exists(cell_params_fp)) {
    cell_params_tbl <- fread(cell_params_fp)
    ctx$add_sheet("cell_params", cell_params_tbl)
    # Pull the yaml so the key_parameters sheet can surface r_ai_annual
    # alongside the derived bumps, and label the year-dependent rows from
    # baseline_year / horizon_start_year rather than hardcoded literals.
    # Falls back to NULL when the file is unreachable; the writer
    # suppresses the r_ai row and uses generic (year-free) labels then.
    yaml_path_kp <- .resolve_repo_path("config/scenario_params.yaml")
    yaml_kp <- tryCatch(
      if (file.exists(yaml_path_kp)) yaml::read_yaml(yaml_path_kp) else NULL,
      error = function(e) NULL
    )
    kp <- build_key_parameters_table(
      cell_params_tbl,
      shock_params       = yaml_kp$shock,
      baseline_year      = yaml_kp$baseline_year,
      horizon_start_year = yaml_kp$cbo_baseline$horizon_start_year
    )
    .write_key_parameters_sheet(ctx$wb, "key_parameters", kp)
    # Bump the at-a-glance summary up to position 2 (right after
    # run_info) so it's the first thing a reader sees on opening the
    # bundle.
    sheet_names <- names(ctx$wb)
    kp_idx      <- match("key_parameters", sheet_names)
    if (!is.na(kp_idx) && kp_idx != 2L) {
      target  <- c("run_info", "key_parameters",
                   setdiff(sheet_names, c("run_info", "key_parameters")))
      openxlsx::worksheetOrder(ctx$wb) <- match(target, sheet_names)
    }
  }

  fp        <- file.path(out_dir,
                         sprintf("ai_fiscal_publishable_%d_%s.xlsx", year, ctx$vintage))
  latest_fp <- file.path(out_dir,
                         sprintf("ai_fiscal_publishable_%d_latest.xlsx", year))
  openxlsx::saveWorkbook(ctx$wb, fp, overwrite = TRUE)
  file.copy(fp, latest_fp, overwrite = TRUE)
  cli::cli_inform(c(
    "Wrote {.path {fp}} ({length(openxlsx::sheets(ctx$wb))} sheets)",
    "Updated {.path {latest_fp}} (tracked canonical bundle)"
  ))
  fp
}

# Driver. Resolves inputs from defaults in 08_aggregate.R; pass an
# explicit `runscript_path` when the runscript lives outside Tax-Simulator
# (e.g. dev runs).
assemble_deliverables <- function(
  year           = NULL,
  runscript_path = file.path(
    Sys.getenv("TAX_SIMULATOR_DIR", unset = NA_character_),
    "config", "runscripts", "private", "ai_fiscal.csv"
  ),
  agg_dir        = "results/aggregates",
  out_dir        = "results/aggregates",
  output_root    = NULL,
  argv           = NULL
) {
  if (is.null(output_root)) output_root <- latest_tax_sim_vintage()
  if (is.null(year)) year <- .runscript_policy_year(runscript_path)

  rev_fp    <- file.path(agg_dir, sprintf("revenue_deltas_%d.csv", year))
  shares_fp <- file.path(agg_dir, sprintf("share_deltas_%d.csv",   year))
  for (fp in c(rev_fp, shares_fp)) {
    if (!file.exists(fp)) {
      cli::cli_abort(c(
        "Aggregator output missing.",
        x = "Looked for {.path {fp}}.",
        i = "Run {.run Rscript code/08_aggregate.R} first."
      ))
    }
  }

  rev_long    <- fread(rev_fp)
  shares_long <- fread(shares_fp)
  macro_per_scn <- .load_macro_per_scenario(runscript_path)

  decomp_fp <- file.path(agg_dir, sprintf("revenue_decomp_%d.csv", year))
  decomp <- if (file.exists(decomp_fp)) fread(decomp_fp) else NULL

  rev_out  <- build_revenue_deliverable(rev_long, macro_per_scn, decomp)
  decile   <- build_decile_deliverable(shares_long, macro_per_scn)
  smc      <- build_share_mode_comparison(rev_out$wide)

  cell_params_fp <- sub("\\.csv$", "_cell_params.csv", runscript_path)
  rev_gdp <- NULL
  if (file.exists(cell_params_fp)) {
    cell_params <- fread(cell_params_fp)
    yaml_path <- .resolve_repo_path("config/scenario_params.yaml")
    if (file.exists(yaml_path)) {
      cbo_y <- yaml::read_yaml(yaml_path)$cbo_baseline
      gdp_B <- cbo_y$gdp_baseline_year_B
      rev_share <- cbo_y$rev_to_gdp_baseline_year
      if (is.numeric(gdp_B) && gdp_B > 0 &&
          is.numeric(rev_share) && rev_share > 0) {
        rev_gdp <- build_revenue_to_gdp(rev_out$long, cell_params,
                                        gdp_B, rev_share)
      }
    }
  }

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  long_fp <- file.path(out_dir, sprintf("revenue_grid_%d.csv",      year))
  wide_fp <- file.path(out_dir, sprintf("revenue_grid_wide_%d.csv", year))
  dec_fp  <- file.path(out_dir, sprintf("decile_panel_%d.csv",      year))
  fwrite(rev_out$long, long_fp)
  fwrite(rev_out$wide, wide_fp)
  fwrite(decile,       dec_fp)

  msgs <- c(
    "Wrote {.path {long_fp}} ({nrow(rev_out$long)} rows)",
    "Wrote {.path {wide_fp}} ({nrow(rev_out$wide)} rows)",
    "Wrote {.path {dec_fp}} ({nrow(decile)} rows)"
  )
  smc_fp <- NULL
  if (!is.null(smc)) {
    smc_fp <- file.path(out_dir,
                        sprintf("share_mode_comparison_%d.csv", year))
    fwrite(smc, smc_fp)
    msgs <- c(msgs,
              "Wrote {.path {smc_fp}} ({nrow(smc)} rows)")
  }
  rev_gdp_fp <- NULL
  if (!is.null(rev_gdp)) {
    rev_gdp_fp <- file.path(out_dir, sprintf("revenue_to_gdp_%d.csv", year))
    fwrite(rev_gdp, rev_gdp_fp)
    msgs <- c(msgs,
              "Wrote {.path {rev_gdp_fp}} ({nrow(rev_gdp)} rows)")
  }
  cli::cli_inform(msgs)

  # Figures are produced by code/10_figures.R (publishable PNG+PDF suite
  # in results/figures/<year>/). 09 owns the CSVs and the .xlsx bundle only.

  write_publishable_excel_bundle(
    out_dir = out_dir, year = year,
    rev_long = rev_out$long, rev_wide = rev_out$wide, decile = decile,
    output_root = output_root, runscript_path = runscript_path,
    decomp = decomp, share_mode_comparison = smc,
    revenue_to_gdp = rev_gdp, argv = argv
  )

  invisible(list(revenue_long = rev_out$long, revenue_wide = rev_out$wide,
                 decile = decile, decomp = decomp,
                 share_mode_comparison = smc))
}

if (!interactive() && sys.nframe() == 0L) {
  assemble_deliverables(argv = commandArgs(trailingOnly = TRUE))
}
