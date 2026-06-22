# ==============================================================================
# Scenario-specific 2030 debt/GDP via the Budget Lab Small Macro Model (BLSMM).
#
# For each AI-Fiscal scenario in results/aggregates/revenue_to_gdp_<year>.csv:
#   - Apply the CBO-anchored revenue/GDP delta as a linear ramp to BLSMM's
#     rgfr_star over 2026-<year> (held at full level after <year>).
#   - Solve for a constant per-year productivity bump (added to glqstar) such
#     that BLSMM's annualized HORIZON_START_YEAR->year real GDP growth equals
#     Karger et al. (2026) r_ai_annual for that variant.
#   - Record BLSMM's 2030 debt/GDP and write to CSV + xlsx bundles + bar plots.
#
# Methodology notes
#   * BLSMM's CBO-rules-of-thumb fiscal feedback (psi_1, psi_2) means outlays
#     fall mechanically as potential output rises. As discussed in the
#     methodology doc, an AI shock may instead lead policymakers to raise
#     outlays for displaced-worker support; if so, debt/GDP will be higher.
#   * The revenue/GDP series fed in is the CBO-anchored delta
#     (delta_rev_to_gdp_cbo), since BLSMM's baseline rev/GDP is already
#     anchored to CBO (~17.6% in 2030).
#   * The growth target is the *annualized* 5-yr rate (compounding from
#     HORIZON_START_YEAR to year), matching how code/02_params.R
#     derives g_y from r_ai_annual.
#
# External dependency
#   The cloned Budget-Lab-Small-Macro-Model repo. Resolution order:
#     1. BLSMM_DIR env var
#     2. ../Budget-Lab-Small-Macro-Model relative to this repo
#   If unresolved or unreadable, all three functions in this file warn and
#   return NULL, leaving the rest of the AI-Fiscal pipeline untouched.
#
# Outputs (under results/aggregates/ + results/figures/<year>/)
#   blsmm_debt_to_gdp_<year>.csv
#   blsmm_debt_to_gdp_fixed_<year>.png        (full: title/subtitle/caption)
#   blsmm_debt_to_gdp_fixed_<year>_clean.png  (paper-ready: title/subtitle/caption stripped)
#   blsmm_debt_to_gdp_reallocate_<year>.png
#   blsmm_debt_to_gdp_reallocate_<year>_clean.png
#   `blsmm_debt_to_gdp` sheet appended to:
#     ai_fiscal_<year>_{<vintage>,latest}.xlsx
#     ai_fiscal_publishable_<year>_{<vintage>,latest}.xlsx
#
# Figure formatting reuses the YBL palette + theme defined in 10_figures.R
# (.fig_theme, PAL_LABOR, .fig_caption, .fig_save) so the BLSMM bars match
# the publishable figure suite.
# ==============================================================================

# Pull in the shared figure palette / theme / save helpers. The orchestrator
# already sources 10_figures.R before this file, but standalone
# `Rscript code/15_blsmm_debt_gdp.R` runs need it loaded here too. Sourced
# unconditionally for idempotence; 10's bottom-of-file entry guard means no
# top-level side effects fire.
source("code/10_figures.R")

# Karger et al. 2026 NBER w35046 Table 19, median annualized 2030 GDP growth.
# Sourced from config/scenario_params.yaml: shock.variants.{S,M,R}.r_ai_annual
# at every call site so this file never drifts from the yaml.
.load_karger_r_ai_annual <- function(yaml_path = "config/scenario_params.yaml") {
  variants <- yaml::read_yaml(yaml_path)$shock$variants
  vapply(variants, function(v) as.numeric(v$r_ai_annual), numeric(1))
}

# Locate the cloned BLSMM repo. Returns NULL with a warning if not resolvable.
.resolve_blsmm_dir <- function(blsmm_dir = NULL) {
  candidates <- c(
    blsmm_dir,
    Sys.getenv("BLSMM_DIR", unset = NA_character_),
    "../Budget-Lab-Small-Macro-Model"
  )
  for (cand in candidates) {
    if (is.null(cand) || is.na(cand) || !nzchar(cand)) next
    if (dir.exists(cand) &&
        file.exists(file.path(cand, "model/v1_8/simulation.R"))) {
      return(normalizePath(cand))
    }
  }
  cli::cli_warn(c(
    "BLSMM directory not found; skipping debt/GDP step.",
    i = "Set the {.envvar BLSMM_DIR} env var to a clone of {.url https://github.com/Budget-Lab-Yale/Budget-Lab-Small-Macro-Model}."
  ))
  NULL
}

# Source the v1_8 module set inside the BLSMM working directory.
# Restores cwd via on.exit so a failing source() can't strand the
# caller inside the BLSMM tree; the sourced functions persist in the
# global env regardless, so subsequent simulate() calls still see them.
.source_blsmm <- function(blsmm_dir) {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(blsmm_dir)
  for (f in c("simulation", "parameters", "equations", "debt_proxy",
              "forcing", "neutral_rate", "presim_block", "solver",
              "user_deltas")) {
    source(file.path("model/v1_8", paste0(f, ".R")), local = FALSE)
  }
}

# Append a sheet to an existing openxlsx workbook on disk. If the sheet
# already exists it is replaced (so re-running the step doesn't pile up
# duplicate sheets across iterations).
.append_xlsx_sheet <- function(xlsx_fp, sheet_name, df) {
  if (!file.exists(xlsx_fp)) return(invisible(FALSE))
  wb <- openxlsx::loadWorkbook(xlsx_fp)
  if (sheet_name %in% openxlsx::sheets(wb)) {
    openxlsx::removeWorksheet(wb, sheet_name)
  }
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet_name, df, headerStyle = openxlsx::createStyle(
    textDecoration = "bold"
  ))
  openxlsx::saveWorkbook(wb, xlsx_fp, overwrite = TRUE)
  invisible(TRUE)
}

# Run BLSMM for every row of revenue_to_gdp_<year>.csv. Returns the
# results data frame (or NULL on failure).
assemble_blsmm_debt_gdp <- function(year      = NULL,
                                    agg_dir   = "results/aggregates",
                                    runscript_path = NULL,
                                    blsmm_dir = NULL,
                                    horizon_start_year = 2025) {
  blsmm_dir <- .resolve_blsmm_dir(blsmm_dir)
  if (is.null(blsmm_dir)) return(invisible(NULL))

  if (is.null(year)) {
    if (is.null(runscript_path) || !file.exists(runscript_path)) {
      cli::cli_warn("BLSMM step: year not given and runscript not resolvable; skipping.")
      return(invisible(NULL))
    }
    year <- .runscript_policy_year(runscript_path)
  }

  rev_gdp_fp <- file.path(agg_dir, sprintf("revenue_to_gdp_%d.csv", year))
  if (!file.exists(rev_gdp_fp)) {
    cli::cli_warn(c(
      "BLSMM step: missing input {.path {rev_gdp_fp}}.",
      i = "09's revenue_to_gdp builder needs cell_params + CBO yaml to fire."
    ))
    return(invisible(NULL))
  }

  cli::cli_inform("BLSMM debt/GDP step: BLSMM_DIR = {.path {blsmm_dir}}")
  ai_fiscal_root <- getwd()
  r_ai_annual_by_variant <- .load_karger_r_ai_annual()
  .source_blsmm(blsmm_dir)

  # Switch into BLSMM for the runs (its read.csv calls use relative paths
  # in places); restore on exit.
  setwd(blsmm_dir); on.exit(setwd(ai_fiscal_root), add = TRUE)

  baseline_exog  <- read.csv("data/blsmm_v1_8_forecast_exog.csv",  check.names = FALSE)
  baseline_resid <- read.csv("data/blsmm_v1_8_forecast_resid.csv", check.names = FALSE)
  hist_data      <- read.csv("data/blsmm_v1_8_historical.csv",     check.names = FALSE)

  n_periods <- nrow(baseline_exog)
  GDP_start <- hist_data$GDP[hist_data$year == horizon_start_year]
  if (length(GDP_start) != 1 || is.na(GDP_start))
    cli::cli_abort("BLSMM step: missing GDP for {horizon_start_year} in historical data.")

  if (!(year %in% baseline_exog$year))
    cli::cli_abort("BLSMM step: forecast does not cover year {year}.")
  horizon_len <- year - horizon_start_year

  make_user_deltas <- function(prod_bump_pp, rgfr_delta_pp_target) {
    uds <- create_user_deltas(n_periods)
    years <- baseline_exog$year[seq_len(n_periods)]
    ramp <- pmax(0, pmin(1, (years - horizon_start_year) / horizon_len))
    uds$user_delta_prod <- prod_bump_pp
    uds$user_delta_rgfr <- rgfr_delta_pp_target * ramp
    uds
  }

  run_scenario <- function(prod_bump_pp, rgfr_delta_pp_target) {
    simulate_blsmm_v1_8(
      n_periods         = n_periods,
      baseline_exog     = baseline_exog,
      baseline_resid    = baseline_resid,
      hist_data         = hist_data,
      user_deltas       = make_user_deltas(prod_bump_pp, rgfr_delta_pp_target),
      forcing_spec      = NULL,
      params            = NULL,
      expectations_speed = FALSE,
      verbose           = FALSE
    )
  }

  annualized_growth <- function(sim) {
    g <- sim$GDP[sim$year == year]
    (g / GDP_start)^(1 / horizon_len) - 1
  }

  solve_prod_bump <- function(rgfr_delta_pp_target, target_g) {
    f <- function(b) annualized_growth(run_scenario(b, rgfr_delta_pp_target)) - target_g
    uniroot(f, lower = -1, upper = 5, tol = 1e-7, maxiter = 100)$root
  }

  # Baseline reference run.
  baseline_sim   <- run_scenario(0, 0)
  baseline_2030  <- baseline_sim[baseline_sim$year == year, ]
  baseline_2029  <- baseline_sim[baseline_sim$year == year - 1L, ]
  baseline_g5    <- annualized_growth(baseline_sim)

  rev_gdp <- data.table::fread(file.path(ai_fiscal_root, rev_gdp_fp))
  rev_gdp$delta_rev_to_gdp_cbo_pp <- rev_gdp$delta_rev_to_gdp_cbo * 100

  results <- vector("list", nrow(rev_gdp))
  for (i in seq_len(nrow(rev_gdp))) {
    row <- rev_gdp[i, ]
    variant <- as.character(row$variant)
    # r_ai_annual_by_variant is a named numeric vector: [["unknown"]]
    # throws subscript-out-of-bounds rather than returning NULL, so an
    # is.null() guard here can never fire — check membership instead.
    if (!variant %in% names(r_ai_annual_by_variant)) {
      cli::cli_abort(c(
        "BLSMM step: unknown variant code {.val {variant}}.",
        i = "Known variants: {.val {names(r_ai_annual_by_variant)}} (from {.field shock.variants} in scenario_params.yaml)."
      ))
    }
    target_g <- r_ai_annual_by_variant[[variant]]

    bump <- solve_prod_bump(row$delta_rev_to_gdp_cbo_pp, target_g)
    sim  <- run_scenario(bump, row$delta_rev_to_gdp_cbo_pp)
    s_y  <- sim[sim$year == year, ]
    s_ym <- sim[sim$year == year - 1L, ]

    results[[i]] <- data.frame(
      scenario_id                = row$scenario_id,
      variant                    = variant,
      variant_label              = row$variant_label,
      share_mode                 = row$share_mode,
      share_mode_label           = row$share_mode_label,
      labor                      = row$labor,
      labor_label                = row$labor_label,
      realization                = row$realization,
      r_ai_annual_target         = target_g,
      delta_rev_to_gdp_cbo_pp    = row$delta_rev_to_gdp_cbo_pp,
      prod_bump_pp_per_yr        = bump,
      blsmm_gstar_year_pct       = s_y$gstar,
      blsmm_annualized_growth_horizon = annualized_growth(sim),
      blsmm_year_real_growth     = s_y$GDP / s_ym$GDP - 1,
      blsmm_rgfr_year_pct        = s_y$rgfr_star,
      blsmm_rgfop_year_pct       = s_y$rgfop_star,
      blsmm_debt_year_B          = s_y$D,
      blsmm_gdp_nominal_year_B   = s_y[["GDP$"]],
      blsmm_debt_to_gdp_year_pct = s_y$D_pct_GDP,
      delta_debt_to_gdp_vs_baseline_pp = s_y$D_pct_GDP - baseline_2030$D_pct_GDP,
      stringsAsFactors = FALSE
    )
  }
  results_df <- data.table::rbindlist(results)

  baseline_row <- data.frame(
    scenario_id                = "blsmm_baseline",
    variant                    = NA_character_,
    variant_label              = NA_character_,
    share_mode                 = NA_character_,
    share_mode_label           = NA_character_,
    labor                      = NA_character_,
    labor_label                = NA_character_,
    realization                = NA_character_,
    r_ai_annual_target         = NA_real_,
    delta_rev_to_gdp_cbo_pp    = 0,
    prod_bump_pp_per_yr        = 0,
    blsmm_gstar_year_pct       = baseline_2030$gstar,
    blsmm_annualized_growth_horizon = baseline_g5,
    blsmm_year_real_growth     = baseline_2030$GDP / baseline_2029$GDP - 1,
    blsmm_rgfr_year_pct        = baseline_2030$rgfr_star,
    blsmm_rgfop_year_pct       = baseline_2030$rgfop_star,
    blsmm_debt_year_B          = baseline_2030$D,
    blsmm_gdp_nominal_year_B   = baseline_2030[["GDP$"]],
    blsmm_debt_to_gdp_year_pct = baseline_2030$D_pct_GDP,
    delta_debt_to_gdp_vs_baseline_pp = 0,
    stringsAsFactors = FALSE
  )
  results_df <- rbind(baseline_row, results_df)

  # Restore cwd for the writes (paths under AI-Fiscal repo).
  setwd(ai_fiscal_root)

  out_csv <- file.path(agg_dir, sprintf("blsmm_debt_to_gdp_%d.csv", year))
  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(results_df, out_csv)
  cli::cli_inform("Wrote {.path {out_csv}} ({nrow(results_df)} rows)")

  # Public-facing column headers for the xlsx sheet (this feeds the paper
  # workbook's Figure A4). The internal `blsmm_*` names stay on results_df
  # for the CSV and the plot code below; only the displayed sheet is renamed.
  # rgfr* is BLSMM's federal-revenue path (see docs/ai_fiscal_methodology.md);
  # rgfop* is left as its model token (undocumented here — don't mislabel).
  results_pub <- results_df
  .PUB_COLS <- c(
    scenario_id                      = "Scenario ID",
    variant                          = "Variant",
    variant_label                    = "AI Adoption",
    share_mode                       = "Share Mode",
    share_mode_label                 = "Share Mode (label)",
    labor                            = "Labor",
    labor_label                      = "Labor Scenario",
    realization                      = "Realization",
    r_ai_annual_target               = "AI GDP CAGR Target",
    delta_rev_to_gdp_cbo_pp          = "Δ Revenue-to-GDP vs CBO (pp)",
    prod_bump_pp_per_yr              = "Productivity Bump (pp/yr)",
    blsmm_gstar_year_pct             = "GDP Growth g* (%)",
    blsmm_annualized_growth_horizon  = "Annualized Growth (2025–Year)",
    blsmm_year_real_growth           = "Real GDP Growth (Year)",
    blsmm_rgfr_year_pct              = "Federal Revenue Path rgfr* (%)",
    blsmm_rgfop_year_pct             = "rgfop* (%)",
    blsmm_debt_year_B                = "Debt ($B)",
    blsmm_gdp_nominal_year_B         = "Nominal GDP ($B)",
    blsmm_debt_to_gdp_year_pct       = "Debt-to-GDP (%)",
    delta_debt_to_gdp_vs_baseline_pp = "Δ Debt-to-GDP vs Baseline (pp)"
  )
  hit <- names(results_pub) %in% names(.PUB_COLS)
  names(results_pub)[hit] <- .PUB_COLS[names(results_pub)[hit]]

  # Append to xlsx bundles where present. Mirrors 08 + 09's vintage / _latest
  # convention. We don't know the vintage stamp here, so glob.
  for (pat in c(sprintf("ai_fiscal_%d_.*\\.xlsx",             year),
                sprintf("ai_fiscal_publishable_%d_.*\\.xlsx", year))) {
    fps <- list.files(agg_dir, pattern = pat, full.names = TRUE)
    for (fp in fps) {
      ok <- tryCatch(.append_xlsx_sheet(fp, "blsmm_debt_to_gdp", results_pub),
                     error = function(e) {
                       cli::cli_warn(c(
                         "Failed to append BLSMM sheet to {.path {fp}}.",
                         x = conditionMessage(e)
                       ))
                       FALSE
                     })
      if (isTRUE(ok))
        cli::cli_inform("Appended {.field blsmm_debt_to_gdp} sheet to {.path {fp}}")
    }
  }

  invisible(results_df)
}

# Bar plots of 2030 debt/GDP, one per share_mode.
assemble_blsmm_figures <- function(year       = NULL,
                                   agg_dir    = "results/aggregates",
                                   fig_dir    = NULL,
                                   runscript_path = NULL,
                                   results_df = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_warn("ggplot2 not available; skipping BLSMM figures.")
    return(invisible(NULL))
  }
  if (is.null(year)) {
    if (is.null(runscript_path) || !file.exists(runscript_path)) {
      cli::cli_warn("BLSMM figures: year not given and runscript not resolvable; skipping.")
      return(invisible(NULL))
    }
    year <- .runscript_policy_year(runscript_path)
  }
  if (is.null(fig_dir)) fig_dir <- file.path("results/figures", year)
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(results_df)) {
    csv_fp <- file.path(agg_dir, sprintf("blsmm_debt_to_gdp_%d.csv", year))
    if (!file.exists(csv_fp)) {
      cli::cli_warn("BLSMM figures: missing {.path {csv_fp}}; skipping.")
      return(invisible(NULL))
    }
    results_df <- data.table::fread(csv_fp)
  }

  baseline_row     <- results_df[results_df$scenario_id == "blsmm_baseline", ]
  if (nrow(baseline_row) != 1) {
    cli::cli_warn("BLSMM figures: baseline row not found; skipping.")
    return(invisible(NULL))
  }
  baseline_debtgdp <- baseline_row$blsmm_debt_to_gdp_year_pct
  scen_df          <- results_df[results_df$scenario_id != "blsmm_baseline", ]
  # Variant / labor labels match the convention used in the 09 scenario
  # guide and PAL_VARIANT / PAL_LABOR keys in 10_figures.R, so the shared
  # scale_*_manual calls below resolve colours by name.
  scen_df$variant  <- factor(scen_df$variant,
                             levels = names(.AXIS_VARIANTS),
                             labels = unname(.AXIS_VARIANTS))
  scen_df$labor    <- factor(scen_df$labor,
                             levels = names(.AXIS_LABOR),
                             labels = unname(.AXIS_LABOR))
  r_ai_pct  <- .load_karger_r_ai_annual() * 100
  variant_g <- setNames(r_ai_pct[names(.AXIS_VARIANTS)],
                        unname(.AXIS_VARIANTS))

  make_plot <- function(sub, label) {
    ymin <- min(sub$blsmm_debt_to_gdp_year_pct, baseline_debtgdp) - 1
    ymax <- max(sub$blsmm_debt_to_gdp_year_pct, baseline_debtgdp) + 1
    ggplot2::ggplot(sub, ggplot2::aes(
        x = variant, y = blsmm_debt_to_gdp_year_pct, fill = labor)) +
      ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.72) +
      ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f", blsmm_debt_to_gdp_year_pct)),
                         position = ggplot2::position_dodge(width = 0.8),
                         vjust = -0.4, size = 3.2, color = YBL_TEXT) +
      ggplot2::geom_hline(yintercept = baseline_debtgdp,
                          linetype = "dashed", color = YBL_CAPTION, linewidth = 0.4) +
      ggplot2::annotate("text",
                        x = length(.AXIS_VARIANTS) + 0.5, y = baseline_debtgdp,
                        label = sprintf("BLSMM baseline: %.1f%%", baseline_debtgdp),
                        hjust = 1, vjust = -0.5, size = 3.2, color = YBL_CAPTION) +
      ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.06))) +
      ggplot2::coord_cartesian(ylim = c(ymin, ymax)) +
      ggplot2::scale_x_discrete(labels = function(v) {
        sprintf("%s\n(%.1f%% / yr)", v, variant_g[v])
      }) +
      ggplot2::scale_fill_manual(values = PAL_LABOR, name = "Labor scenario") +
      ggplot2::labs(
        title    = sprintf("%d debt-to-GDP via BLSMM — %s", year, label),
        subtitle = "Rev/GDP delta ramped 2026-2030; productivity bump set to hit Karger annualized growth.",
        x        = "Karger variant (2025-2030 annualized GDP growth)",
        y        = sprintf("Federal debt / GDP, %d (%%)", year),
        caption  = .fig_caption(year)
      ) +
      .fig_theme()
  }

  pairs <- list(
    list(mode = "F", label = "Capital share held constant (Fixed)",
         slug = "blsmm_debt_to_gdp_fixed"),
    list(mode = "R", label = "Labor-to-capital share shifts (Reallocate)",
         slug = "blsmm_debt_to_gdp_reallocate")
  )
  written <- character()
  for (pp in pairs) {
    sub <- scen_df[scen_df$share_mode == pp$mode, ]
    if (!nrow(sub)) next
    plt  <- make_plot(sub, pp$label)
    # .fig_save emits both <slug>_<year>.png (full) and <slug>_<year>_clean.png
    # (paper-ready, title/subtitle/caption stripped) — same convention as
    # 10_figures.R uses for the rest of the figure suite.
    out  <- .fig_save(plt, fig_dir, pp$slug, year, w = 9, h = 5.5)
    written <- c(written, unname(out))
  }
  if (length(written))
    cli::cli_inform(c(
      "Wrote BLSMM figures:",
      stats::setNames(paste0("{.path ", written, "}"), rep(" ", length(written)))
    ))
  invisible(written)
}

# Orchestrator entry point: run the BLSMM step end-to-end, swallowing
# (and logging) any failure so the rest of the AI-Fiscal pipeline can
# continue.
run_blsmm_step <- function(year      = NULL,
                           agg_dir   = "results/aggregates",
                           fig_dir   = NULL,
                           runscript_path = NULL,
                           blsmm_dir = NULL) {
  tryCatch({
    res <- assemble_blsmm_debt_gdp(
      year = year, agg_dir = agg_dir,
      runscript_path = runscript_path,
      blsmm_dir = blsmm_dir
    )
    if (is.null(res)) return(invisible(NULL))
    assemble_blsmm_figures(
      year = year, agg_dir = agg_dir, fig_dir = fig_dir,
      runscript_path = runscript_path, results_df = res
    )
    invisible(res)
  }, error = function(e) {
    cli::cli_warn(c(
      "BLSMM step failed; continuing without BLSMM outputs.",
      x = conditionMessage(e)
    ))
    invisible(NULL)
  })
}

if (!interactive() && sys.nframe() == 0L) {
  argv <- commandArgs(trailingOnly = TRUE)
  year_arg <- if (length(argv) >= 1) as.integer(argv[1]) else NULL
  run_blsmm_step(year = year_arg)
}
