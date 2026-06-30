# Orchestrator: build the 18-cell counterfactual grid for the v1.0
# release, run Tax-Simulator, and assemble the publishable deliverables.
#
# Usage:
#   Rscript code/00_ai_fiscal_sim.R [--data-dir PATH]
#                                   [--years 2029:2030]
#                                   [--runscript-path PATH]
#                                   [--vintage YYYYMMDDHHMM]
#                                   [--multicore none|scenario|year]
#                                   [--overwrite]
#                                   [--log PATH]
#
# Behavior is fixed (no spec flags):
#   * Loop  : 3 shock variants (S, M, R) × 2 share modes (R, F) × 3 labor
#             scenarios (S0, S2, S3) × V1 realization = 18 cells.
#   * Retirement cascade : R1 (income-flow).
#   * Asset base         : all_assets.
#   * Realization        : V1 (mechanical, all gains realized in-year).
#   * Decomposition      : on. Each cell runs three Tax-Simulator
#                          scenarios (both / labor_only / capital_only)
#                          so 08 can compute the labor / capital /
#                          interaction split.
#   * Deliverables       : 08 (microsim bundle) + 09 (publishable
#                          workbook + decile panel + grid) + 10
#                          (publishable figure suite).
#   * Log file           : tee'd to logs/release_<timestamp>.log unless
#                          --log overrides.
#
# `--data-dir PATH` points at a Tax-Data root (defaults to the symlink
# at data/tax_data). Pass `tests/fixtures/synthetic_tax_data` for a
# no-PUF smoke test.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")
source("code/01_load_data.R")
source("code/02_params.R")
source("code/03_shock_labor.R")
source("code/04_allocate_capital.R")
source("code/05_realization.R")
source("code/06_build_counterfactual.R")
source("code/07_run_tax_sim.R")
source("code/08_aggregate.R")
source("code/09_tables_figures.R")
source("code/10_figures.R")
source("code/13_macro_params_table.R")
source("code/15_blsmm_debt_gdp.R")

# Canonical 18-cell grid: 3 variants × 2 share modes × 3 labor scenarios
# × V1 realization. The release pipeline does not accept overrides.
release_specs <- function() {
  grid <- expand.grid(
    variant        = names(.AXIS_VARIANTS),
    share_mode     = names(.AXIS_SHARE_MODES),
    labor_scenario = names(.AXIS_LABOR),
    realization    = names(.AXIS_REALIZATION),
    stringsAsFactors = FALSE
  )
  lapply(seq_len(nrow(grid)), function(i) as.list(grid[i, ]))
}

# Default destination for the Tax-Simulator runscript.
default_runscript_path <- function() {
  file.path(tax_sim_root(),
            "config", "runscripts", "private", "ai_fiscal.csv")
}

# Per-variant macro summary CSV: one row per (variant, share_mode).
.write_macro_summary <- function(per_variant, runscript_path) {
  rows <- lapply(names(per_variant), function(key) {
    pv <- per_variant[[key]]
    m  <- attr(pv$step_b, "macro")
    sb <- pv$step_b
    agg_B <- function(col) {
      if (col %in% names(sb)) sum(sb$weight * sb[[col]]) / 1e9
      else NA_real_
    }
    # Per-income-type aggregates of the capital flow X_to_units (all in
    # $B). X_retirement_slice_B is the residual: X_to_units minus the
    # four non-retirement income-type aggregates equals Σ w·X_retirement_dc_ira.
    # Under R1 the realized aggregate equals the slice by construction.
    income_types_B <- list(
      X_qualified_div_B        = agg_B("X_qualified_div"),
      X_taxable_int_B          = agg_B("X_taxable_int"),
      X_tax_exempt_int_B       = agg_B("X_tax_exempt_int"),
      X_passthrough_ordinary_B = agg_B("X_passthrough_ordinary"),
      X_ltcg_gross_B           = agg_B("X_ltcg_gross"),
      X_ltcg_V1_realized_B     = agg_B("X_ltcg_V1")
    )
    income_types_B$X_retirement_slice_B <-
      m$X_to_units / 1e9 -
      (income_types_B$X_qualified_div_B +
       income_types_B$X_taxable_int_B +
       income_types_B$X_tax_exempt_int_B +
       income_types_B$X_passthrough_ordinary_B +
       income_types_B$X_ltcg_gross_B)
    income_types_B$X_retirement_realized_B   <- (m$retirement_F %||% 0) / 1e9
    # Snap floating-point noise to zero — under R1 the realized aggregate
    # equals the slice by construction.
    unreal <- income_types_B$X_retirement_slice_B - income_types_B$X_retirement_realized_B
    income_types_B$X_retirement_unrealized_B <-
      ifelse(abs(unreal) < 1e-5, 0, unreal)

    do.call(data.table, c(list(
      variant        = pv$params$active_variant,
      share_mode     = pv$params$share_mode,
      theta1_k       = pv$params$theta1_k,
      g_y            = pv$params$g_y,
      g_k            = pv$params$g_k,
      g_l            = pv$params$g_l,
      k_inequality   = pv$params$k_inequality,
      lambda_S2      = 1 - pv$params$k_inequality * pv$params$g_y,
      lambda_S3      = 1 + pv$params$k_inequality * pv$params$g_y,
      y0_l_dollar    = m$y0_l_dollar,
      y0_k_dollar    = m$y0_k_dollar,
      y0_dollar      = m$y0_dollar,
      X              = m$X,
      X_to_units     = m$X_to_units,
      kappa_corp     = m$kappa_corp,
      cit_statutory  = m$cit_statutory,
      cbo_cit_baseline_dollar = m$cbo_cit_baseline_dollar,
      eta_corp       = m$eta_corp,
      delta_R_CIT    = m$delta_R_CIT
    ), income_types_B))
  })
  out <- rbindlist(rows)
  fp  <- sub("\\.csv$", "_macro.csv", runscript_path)
  fwrite(out, fp)
  cli::cli_inform("Wrote macro summary {.path {fp}}")
  fp
}

# Build counterfactual folders + runscript for the 18-cell release grid.
# Returns the runscript path written.
build_ai_fiscal_runs <- function(specs,
                                 runscript_path  = default_runscript_path(),
                                 params_yaml     = "config/scenario_params.yaml",
                                 data_dir        = "data/tax_data",
                                 vintage_paths   = NULL,
                                 years           = NULL,
                                 overwrite       = FALSE) {

  force(runscript_path)
  # Sibling artifacts (_macro.csv, _cell_params.csv) are derived by
  # replacing the `.csv` suffix. A path without it would make that
  # substitution a no-op and overwrite the runscript itself.
  if (!grepl("\\.csv$", runscript_path)) {
    cli::cli_abort(c(
      "Runscript path must end in {.code .csv}.",
      x = "Got {.path {runscript_path}}.",
      i = "Sibling summaries are written by replacing the {.code .csv} suffix; without it they would clobber the runscript."
    ))
  }
  if (is.null(vintage_paths)) vintage_paths <- tax_data_vintage(symlink = data_dir)
  force(vintage_paths)

  params0 <- load_params(params_yaml)
  year    <- params0$raw$baseline_year
  # Default years starts one year before baseline_year. Tax-Simulator's
  # FY-adjustment drops the earliest year of each scenario, so a single-
  # year run produces an empty receipts.csv.
  years_str <- years %||% sprintf("%d:%d", year - 1L, year)

  # Validate the range shape AND that it spans >= 2 years: Tax-Simulator's
  # FY adjustment drops the earliest year of each scenario, so a
  # single-year run (e.g. --years 2030 or 2030:2030) passes the
  # file-exists check below but produces an empty receipts.csv after the
  # full run.
  years_parts <- strsplit(years_str, ":", fixed = TRUE)[[1]]
  years_int   <- suppressWarnings(as.integer(years_parts))
  if (length(years_int) != 2L || anyNA(years_int) ||
      years_int[1] >= years_int[2]) {
    cli::cli_abort(c(
      "Invalid {.arg years} range: {.val {years_str}}.",
      x = "Expected {.code <start>:<end>} with start < end (e.g. {.val 2029:2030}).",
      i = "Tax-Simulator's FY adjustment drops the earliest year, so the range must span at least two years."
    ))
  }
  years_min <- years_int[1]
  prior_fp  <- file.path(vintage_paths$path, "baseline",
                         sprintf("tax_units_%d.csv", years_min))
  if (!file.exists(prior_fp)) {
    cli::cli_abort(c(
      "Earliest-year tax-unit file missing for {.code years = {years_str}}.",
      x = "Looked for {.path {prior_fp}}.",
      i = "Tax-Simulator's FY adjustment drops the earliest year, so {.val {years_min}} must be present in the vintage."
    ))
  }

  # 1. Load + SZ split once (variant-independent).
  dt_split <- apply_passthrough_split(
    load_tax_units(year, data_dir = data_dir),
    params0
  )
  baseline_cache <- compute_baseline_cache(dt_split, params0)

  # 2. Cache (params, step_b) per unique (variant, share_mode). share_mode
  # changes theta1_k → (g_k, g_l, X, CIT wedge), so step_b must be recomputed.
  unique_keys <- unique(vapply(specs, function(s) {
    paste(s$variant, s$share_mode, sep = "|")
  }, character(1)))
  per_variant <- lapply(unique_keys, function(key) {
    parts <- strsplit(key, "|", fixed = TRUE)[[1]]
    p  <- load_params(params_yaml,
                      variant    = parts[1],
                      share_mode = parts[2])
    sb <- allocate_capital(dt_split, p,
                           asset_map_path = "config/asset_to_income_map.csv")
    sb <- apply_realization(sb)
    list(params = p, step_b = sb)
  })
  names(per_variant) <- unique_keys

  .write_macro_summary(per_variant, runscript_path)

  labor_scenarios <- unique(vapply(specs, function(s) s$labor_scenario,
                                   character(1)))
  write_macro_params_table(per_variant, labor_scenarios, runscript_path)

  rows <- list(runscript_row(
    "baseline",
    tax_data_id      = "baseline",
    tax_data_vintage = vintage_paths$vintage,
    years            = years_str
  ))

  # Decomposition is always on for the release pipeline. Suffix map is
  # the inverse of .FLAVOR_SUFFIX_MAP (axis registry, 00_utils.R) so the
  # writer and 08's parser cannot drift apart.
  flavor_suffix <- c(
    both = "",
    setNames(paste0("_", names(.FLAVOR_SUFFIX_MAP)),
             unname(.FLAVOR_SUFFIX_MAP))
  )
  flavors <- names(flavor_suffix)

  for (spec in specs) {
    sid_base <- ai_fiscal_scenario_id(spec$variant, spec$share_mode,
                                      spec$labor_scenario,
                                      spec$realization)
    pv   <- per_variant[[paste(spec$variant, spec$share_mode, sep = "|")]]
    # Step A is (variant, share_mode, labor) specific; identical across
    # flavors of this cell, so compute once.
    dt_a <- shock_labor(dt_split, pv$params,
                        scenario = spec$labor_scenario)
    for (flavor in flavors) {
      sid <- paste0(sid_base, flavor_suffix[[flavor]])
      cli::cli_inform("Building scenario {.val {sid}}")
      dt_cf <- build_counterfactual(
        dt_split, dt_a, pv$step_b,
        params = pv$params,
        flavor = flavor, baseline_cache = baseline_cache
      )
      scenario_dir <- write_counterfactual_scenario(
        dt_cf, year, sid,
        vintage_paths = vintage_paths,
        overwrite     = overwrite
      )
      write_factor_channels(dt_split, dt_a, pv$step_b,
                            year = year, scenario_dir = scenario_dir,
                            flavor = flavor)
      rows[[length(rows) + 1L]] <- runscript_row(
        sid,
        tax_data_id      = sid,
        tax_data_vintage = vintage_paths$vintage,
        years            = years_str
      )
    }
  }

  write_runscript(rows, runscript_path)
  cli::cli_inform("Wrote runscript {.path {runscript_path}} ({length(specs)} cells × 3 flavors)")
  runscript_path
}

# Minimal flag parser. Supports `--flag value`, `--flag=value`, and bare
# boolean `--flag`. Unknown flags abort.
.parse_cli_args <- function(argv) {
  known_value <- c("data-dir", "years", "runscript-path",
                   "vintage", "multicore", "log")
  known_bool  <- c("overwrite")
  out <- list()
  i <- 1L
  while (i <= length(argv)) {
    a <- argv[i]
    if (!startsWith(a, "--")) {
      cli::cli_abort("Unexpected argument {.val {a}} (flags must start with --).")
    }
    eq <- regexpr("=", a, fixed = TRUE)
    if (eq > 0) {
      flag <- substr(a, 3, eq - 1)
      val  <- substr(a, eq + 1, nchar(a))
      if (!flag %in% known_value) {
        cli::cli_abort("Flag {.val --{flag}} does not take a value or is unknown.")
      }
      out[[flag]] <- val
      i <- i + 1L
    } else {
      flag <- substr(a, 3, nchar(a))
      if (flag %in% known_bool) {
        out[[flag]] <- TRUE
        i <- i + 1L
      } else if (flag %in% known_value) {
        if (i + 1L > length(argv)) {
          cli::cli_abort("Flag {.val --{flag}} requires a value.")
        }
        nxt <- argv[i + 1L]
        if (startsWith(nxt, "--")) {
          # Guard the common typo `--years --overwrite`, which would
          # otherwise silently set years = "--overwrite".
          cli::cli_abort(c(
            "Flag {.val --{flag}} requires a value but is followed by another flag ({.val {nxt}}).",
            i = "Use {.code --{flag} <value>} or {.code --{flag}=<value>}."
          ))
        }
        out[[flag]] <- nxt
        i <- i + 2L
      } else {
        cli::cli_abort("Unknown flag {.val --{flag}}.")
      }
    }
  }
  out
}

.default_log_path <- function() {
  file.path("logs",
            sprintf("release_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S")))
}

# Print a pre-flight banner with the resolved versions / paths the run
# depends on, before any heavy work, so a misconfigured environment is
# obvious up front rather than partway into the Tax-Simulator run. Every
# lookup is non-fatal: an unresolved value prints a marker and the run
# proceeds to abort at the natural point with the proper error message.
# `.git_short_rev` is provided by 00_utils.R (sourced first).
.print_preflight <- function(data_dir, runscript_label) {
  safe <- function(expr) tryCatch(expr, error = function(e) "(unresolved)")

  ai_rev  <- safe(.git_short_rev(getwd()))
  ts_root <- safe(tax_sim_root())
  ts_rev  <- if (identical(ts_root, "(unresolved)")) "(unresolved)"
             else safe(.git_short_rev(ts_root))
  vintage <- safe(tax_data_vintage(symlink = data_dir)$vintage)
  blsmm   <- Sys.getenv("BLSMM_DIR", unset = "")
  blsmm_s <- if (nzchar(blsmm) && dir.exists(blsmm)) blsmm
             else "(unset — BLSMM debt/GDP step will skip)"
  mc      <- Sys.getenv("MC_CORES", unset = "(unset — Tax-Simulator default)")

  cli::cli_inform(c(
    "AI-Fiscal pre-flight",
    "*" = "R:                 {R.version.string}",
    "*" = "AI-Fiscal rev:     {ai_rev}",
    "*" = "Tax-Simulator dir: {ts_root}",
    "*" = "Tax-Simulator rev: {ts_rev}",
    "*" = "Tax-Data dir:      {data_dir}",
    "*" = "Tax-Data vintage:  {vintage}",
    "*" = "BLSMM dir:         {blsmm_s}",
    "*" = "MC_CORES:          {mc}",
    "*" = "Runscript:         {runscript_label}"
  ))
}

.cli_main <- function(argv) {
  flags    <- .parse_cli_args(argv)
  log_file <- flags$log %||% .default_log_path()

  log_dir <- dirname(log_file)
  if (nzchar(log_dir) && !dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }
  log_con <- file(log_file, open = "wt")
  cat(sprintf("# AI-Fiscal release run @ %s\n# argv: %s\n\n",
              format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              paste(argv, collapse = " ")),
      file = log_con)
  on.exit(close(log_con), add = TRUE)

  log_handler <- function(c) {
    cat(conditionMessage(c), file = log_con); flush(log_con)
  }
  err_handler <- function(c) {
    cat("\nERROR: ", conditionMessage(c), "\n", sep = "", file = log_con)
    if (!is.null(c$trace)) {
      cat("Backtrace:\n", file = log_con)
      cat(format(c$trace), sep = "\n", file = log_con)
      cat("\n", file = log_con)
    }
    flush(log_con)
  }
  cli::cli_inform("Logging to {.path {log_file}}")
  withCallingHandlers(
    .cli_main_body(argv, flags, log_con = log_con),
    message = log_handler,
    warning = log_handler,
    error   = err_handler
  )
}

.cli_main_body <- function(argv, flags, log_con) {
  specs          <- release_specs()
  data_dir       <- flags[["data-dir"]] %||% "data/tax_data"
  runscript_flag <- flags[["runscript-path"]]

  # Banner first: shows whether TAX_SIMULATOR_DIR / data_dir resolve
  # before runscript-path resolution (which aborts if Tax-Simulator
  # is unreachable) or any counterfactual building begins.
  .print_preflight(data_dir, runscript_flag %||% "(Tax-Simulator default)")

  runscript_path <- runscript_flag %||% default_runscript_path()

  build_ai_fiscal_runs(
    specs,
    runscript_path = runscript_path,
    data_dir       = data_dir,
    years          = flags$years,
    overwrite      = isTRUE(flags$overwrite)
  )

  vintage    <- flags$vintage %||% new_vintage()
  multicore  <- flags$multicore %||% "none"
  # Decomp is always on; LO/CO/both are parallel scenarios, not stacked.
  stacked    <- FALSE

  ts_root     <- tax_sim_root()
  rs_name     <- runscript_name_from_path(runscript_path, ts_root = ts_root)
  output_root <- run_tax_sim(
    runscript_name = rs_name,
    vintage        = vintage,
    pct_sample     = 1,
    multicore      = multicore,
    stacked        = stacked,
    ts_root        = ts_root,
    log_con        = log_con
  )

  aggregate_tax_sim_output(
    output_root    = output_root,
    runscript_path = runscript_path,
    argv           = argv
  )

  assemble_deliverables(
    runscript_path = runscript_path,
    out_dir        = "results/aggregates",
    output_root    = output_root,
    argv           = argv
  )

  assemble_figures(
    runscript_path = runscript_path,
    agg_dir        = "results/aggregates",
    argv           = argv
  )

  # Optional macro tie-in: pipe the per-scenario revenue/GDP deltas through
  # the Budget Lab Small Macro Model to recover scenario-specific 2030
  # debt/GDP. Skips with a warning if BLSMM_DIR is unset or the BLSMM repo
  # isn't reachable, so the rest of the pipeline doesn't depend on it.
  run_blsmm_step(
    agg_dir        = "results/aggregates",
    runscript_path = runscript_path
  )

  invisible(output_root)
}

if (!interactive() && sys.nframe() == 0L) {
  .cli_main(commandArgs(trailingOnly = TRUE))
}
