# Validate the pinned vintage's per-unit aggregates and distributional
# moments against published benchmarks (CBO/Treasury IIT, NIPA capital
# income by type, IRS SOI components, Federal Reserve DFA / SCF top
# shares). Loads benchmarks from
# config/calibration/validation_benchmarks.csv and the tax-units file
# from the pinned vintage; reports per-benchmark absolute and percent
# differences with a pass/flag column.
#
# Scope: validates inputs to the pipeline (income components, asset
# holdings, top shares). The federal IIT / CIT totals require running
# Tax-Simulator first; when a receipts.csv path is supplied we read
# it and compare. With no Tax-Simulator output, those rows are skipped
# and reported as missing.
#
# Run from repo root:
#   module load R/4.4.2-gfbf-2024a
#   Rscript code/11_validation.R                     # year from scenario_params.yaml
#   Rscript code/11_validation.R --year 2024         # specific year
#   Rscript code/11_validation.R --receipts <path>   # also include IIT/CIT
#
# CLI args:
#   --year      tax-units file year to validate (default: baseline_year from yaml)
#   --receipts  path to a Tax-Simulator receipts.csv (optional)
#   --tol       fractional tolerance for the pass/flag column (default 0.10)

suppressPackageStartupMessages({
  library(data.table)
  library(yaml)
})

source("code/00_utils.R")
source("code/01_load_data.R")
source("code/02_params.R")

# ---- benchmark loader ------------------------------------------------ #

load_benchmarks <- function(path = "config/calibration/validation_benchmarks.csv") {
  if (!file.exists(path)) {
    cli::cli_abort("Benchmarks file not found at {.path {path}}.")
  }
  fread(path)
}

# ---- aggregate computations ------------------------------------------ #

# Compute weighted-sum aggregates from the tax-units table that have
# benchmark counterparts. Returns a named list indexed by benchmark_id.
# Units are dollars (the benchmarks file stores billions; conversion
# happens at compare-time).
compute_aggregates <- function(dt) {
  w <- dt$weight
  wsum <- function(x) sum(w * x, na.rm = TRUE)

  scorp_e_net <- (dt$scorp_active - dt$scorp_active_loss) +
                 (dt$scorp_passive - dt$scorp_passive_loss)
  part_e_net  <- (dt$part_active  - dt$part_active_loss) +
                 (dt$part_passive - dt$part_passive_loss)

  list(
    # Labor income (SOI tax-base concept)
    wages_soi_2022                = wsum(dt$wages),

    # Capital income components on individual returns
    taxable_interest_soi_2022     = wsum(dt$txbl_int),
    ordinary_dividends_soi_2022   = wsum(dt$div_ord + dt$div_pref),
    capital_gains_net_soi_2022    = wsum(dt$kg_lt + dt$kg_st),

    # Passthrough business income
    sole_prop_soi_2022            = wsum(dt$sole_prop + dt$farm),
    schedule_e_soi_2022           = wsum(scorp_e_net + part_e_net),

    # Retirement (gross SS is in the schema but the taxable-portion split is
    # computed inside Tax-Simulator via the provisional-income worksheet, so
    # the SOI taxable-SS benchmark is auto-skipped here).
    pensions_soi_2022             = wsum(dt$txbl_pens_dist),
    ira_distributions_soi_2022    = wsum(dt$txbl_ira_dist),

    # Pipeline-derived L0 / K0 / Y0 (after passthrough split)
    L0_data                       = wsum(dt$YiL),
    K0_data                       = wsum(dt$YiK),
    Y0_data                       = wsum(dt$YiL + dt$YiK)
  )
}

# Pull only the asset aggregates that the pinned vintage carries.
# Names match the SCF-imputed wealth columns on the merged file.
compute_asset_aggregates <- function(dt) {
  asset_cols <- c("cash", "equities", "bonds", "retirement",
                  "pass_throughs", "primary_home", "other_home",
                  "annuities", "trusts", "life_ins",
                  "other_fin", "re_fund", "other_nonfin")
  out <- lapply(asset_cols, function(col) {
    if (col %in% names(dt)) sum(dt$weight * dt[[col]], na.rm = TRUE) else NA_real_
  })
  names(out) <- asset_cols
  out
}

# Top-1% / top-10% shares of distribution-target variables. Includes a
# net-worth proxy (sum of asset columns minus primary_mortgage if present)
# for direct comparison against SCF wealth-share benchmarks.
compute_top_shares <- function(dt) {
  asset_cols <- c("cash", "equities", "bonds", "retirement", "life_ins",
                  "annuities", "trusts", "other_fin", "pass_throughs",
                  "primary_home", "other_home", "re_fund", "other_nonfin")
  asset_cols <- intersect(asset_cols, names(dt))
  net_worth <- Reduce(`+`, lapply(asset_cols, function(c) dt[[c]]),
                      init = rep(0, nrow(dt)))
  if ("primary_mortgage" %in% names(dt)) net_worth <- net_worth - dt$primary_mortgage

  list(
    top1_wages              = weighted_top_share(dt$wages,         dt$weight, 0.01),
    top1_YiL                = weighted_top_share(dt$YiL,           dt$weight, 0.01),
    top1_YiK                = weighted_top_share(dt$YiK,           dt$weight, 0.01),
    top1_equities           = weighted_top_share(dt$equities,      dt$weight, 0.01),
    top1_pass_throughs      = weighted_top_share(dt$pass_throughs, dt$weight, 0.01),
    top1_retirement         = weighted_top_share(dt$retirement,    dt$weight, 0.01),
    top1_net_worth_proxy    = weighted_top_share(net_worth,        dt$weight, 0.01),
    top10_wages             = weighted_top_share(dt$wages,         dt$weight, 0.10),
    top10_YiK               = weighted_top_share(dt$YiK,           dt$weight, 0.10),
    top10_equities          = weighted_top_share(dt$equities,      dt$weight, 0.10),
    top10_net_worth_proxy   = weighted_top_share(net_worth,        dt$weight, 0.10)
  )
}

# Optional: pull IIT / CIT totals from a Tax-Simulator receipts.csv.
# The Tax-Simulator output schema is one row per fiscal year with
# per-instrument columns; we take the row matching `year` — the
# pipeline's two-year runs (FY-adjustment compensation) leave multiple
# rows, and the year-specific benchmarks (iit_total_2030 etc.) must
# not be compared against whichever year happens to sit in row 1.
compute_revenue_aggregates <- function(receipts_path, year) {
  if (is.null(receipts_path) || !nzchar(receipts_path) || !file.exists(receipts_path)) {
    return(list())
  }
  rec <- fread(receipts_path)
  yr_col <- intersect(c("year", "fy", "fiscal_year"), names(rec))[1]
  if (is.na(yr_col)) {
    cli::cli_warn("Could not find a year column in {.path {receipts_path}}; skipping revenue aggregates.")
    return(list())
  }
  rec <- rec[rec[[yr_col]] == year, ]
  if (!nrow(rec)) {
    cli::cli_warn("No row for year {.val {year}} in {.path {receipts_path}}; skipping revenue aggregates.")
    return(list())
  }
  if (nrow(rec) > 1L) {
    cli::cli_warn("{nrow(rec)} rows for year {.val {year}} in {.path {receipts_path}}; using the first.")
  }
  iit_col <- intersect(c("revenues_iit", "iit", "individual_income_tax"), names(rec))[1]
  cit_col <- intersect(c("revenues_corp_tax", "cit", "corporate_income_tax"), names(rec))[1]
  out <- list()
  if (!is.na(iit_col)) out$iit_total <- rec[[iit_col]][1] * 1e9  # receipts.csv is in $B
  if (!is.na(cit_col)) out$cit_total <- rec[[cit_col]][1] * 1e9
  out
}

# ---- comparison ------------------------------------------------------ #

# Map computed-name → benchmark_id. Benchmarks the script can't compute
# from inputs alone (e.g. iit_total_2030) are matched at runtime if the
# user supplied receipts.
benchmark_to_data_map <- function(year) {
  list(
    wages_soi_2022                = "wages_soi_2022",
    taxable_interest_soi_2022     = "taxable_interest_soi_2022",
    ordinary_dividends_soi_2022   = "ordinary_dividends_soi_2022",
    capital_gains_net_soi_2022    = "capital_gains_net_soi_2022",
    sole_prop_soi_2022            = "sole_prop_soi_2022",
    schedule_e_soi_2022           = "schedule_e_soi_2022",
    pensions_soi_2022             = "pensions_soi_2022",
    ira_distributions_soi_2022    = "ira_distributions_soi_2022",
    social_security_soi_2022      = "social_security_soi_2022",
    iit_total_2024                = if (year == 2024) "iit_total" else NA_character_,
    iit_total_2030                = if (year == 2030) "iit_total" else NA_character_,
    cit_total_2024                = if (year == 2024) "cit_total" else NA_character_,
    cit_total_2030                = if (year == 2030) "cit_total" else NA_character_,

    # Distributional benchmarks (SCF/DFA) — fraction units, no $-conversion.
    top1_wealth_share_scf_2022    = "top1_net_worth_proxy",
    top10_wealth_share_scf_2022   = "top10_net_worth_proxy",
    top1_equities_share_dfa_q4_2024 = "top1_equities",
    top1_stocks_share_scf_2022    = "top1_equities",
    top10_stocks_share_scf_2022   = "top10_equities"
  )
}

# Build the comparison table: for each benchmark, look up the computed
# value (if any) and report absolute and percent differences plus a
# pass/flag/skip status.
build_comparison <- function(benchmarks, computed, tol) {
  bm <- as.data.frame(benchmarks)
  rows <- lapply(seq_len(nrow(bm)), function(i) {
    row <- bm[i, ]
    bm_id <- row$benchmark_id
    bm_val_dollars <- row$value * if (row$units == "billions_usd") 1e9 else 1
    data_val <- computed[[bm_id]]
    if (is.null(data_val) || (is.numeric(data_val) && is.na(data_val))) {
      return(data.table(
        benchmark_id = bm_id,
        group        = row$group,
        bm_value     = row$value,
        units        = row$units,
        data_value   = NA_real_,
        abs_diff     = NA_real_,
        pct_diff     = NA_real_,
        status       = "skip",
        notes        = "no matching data computation"
      ))
    }
    data_val_in_units <- data_val / (if (row$units == "billions_usd") 1e9 else 1)
    abs_diff <- data_val_in_units - row$value
    pct_diff <- abs_diff / row$value
    status <- if (abs(pct_diff) <= tol) "pass" else "flag"
    data.table(
      benchmark_id = bm_id,
      group        = row$group,
      bm_value     = row$value,
      units        = row$units,
      data_value   = data_val_in_units,
      abs_diff     = abs_diff,
      pct_diff     = pct_diff,
      status       = status,
      notes        = ""
    )
  })
  rbindlist(rows)
}

# ---- pretty printing ------------------------------------------------- #

print_comparison <- function(cmp, tol) {
  # Group + sort
  cmp <- cmp[order(group, benchmark_id)]
  cat("\n  Comparison (data minus benchmark):\n\n")
  fmt_pct_signed <- function(x) {
    if (is.na(x)) "      —" else sprintf("%+7.1f%%", 100 * x)
  }
  fmt_signed <- function(x) {
    if (is.na(x)) "          —" else sprintf("%+11.1f", x)
  }
  fmt_unsigned <- function(x) {
    if (is.na(x)) "         —" else sprintf("%10.1f", x)
  }

  hdr <- sprintf("  %-32s %-14s %10s %10s %11s %8s %-8s",
                 "benchmark_id", "group", "bm", "data", "abs_diff",
                 "pct_diff", "status")
  cat(hdr, "\n")
  cat("  ", strrep("-", nchar(hdr) - 2), "\n", sep = "")

  for (i in seq_len(nrow(cmp))) {
    r <- cmp[i]
    cat(sprintf("  %-32s %-14s %s %s %s %s %-8s\n",
                substr(r$benchmark_id, 1, 32),
                substr(r$group, 1, 14),
                fmt_unsigned(r$bm_value),
                fmt_unsigned(r$data_value),
                fmt_signed(r$abs_diff),
                fmt_pct_signed(r$pct_diff),
                r$status))
  }

  # Summary
  n_pass <- sum(cmp$status == "pass")
  n_flag <- sum(cmp$status == "flag")
  n_skip <- sum(cmp$status == "skip")
  cat(sprintf("\n  Pass: %d   Flag: %d   Skip: %d   (tolerance |pct_diff| <= %.1f%%)\n",
              n_pass, n_flag, n_skip, 100 * tol))
}

# ---- top-share comparison ------------------------------------------- #

print_top_share_diagnostic <- function(top_shares, benchmarks) {
  cat("\n  Top-share diagnostics:\n\n")
  bm <- benchmarks[group == "distribution"]
  for (n in names(top_shares)) {
    cat(sprintf("    %-22s  %.3f\n", n, top_shares[[n]]))
  }
  cat("\n  Reference benchmarks (group=distribution):\n")
  for (i in seq_len(nrow(bm))) {
    cat(sprintf("    %-32s  %.3f   (%s)\n",
                bm$benchmark_id[i], bm$value[i], bm$year[i]))
  }
}

print_asset_aggregates <- function(asset_agg) {
  cat("\n  Asset aggregates ($T) [no DFA per-class benchmark in v1]:\n")
  for (n in names(asset_agg)) {
    val <- asset_agg[[n]]
    if (is.na(val)) {
      cat(sprintf("    %-15s   —\n", n))
    } else {
      cat(sprintf("    %-15s %s\n", n, fmt_T(val)))
    }
  }
}

# ---- main entry ------------------------------------------------------ #

parse_args <- function(args) {
  out <- list(year = NULL, receipts = NULL, tol = 0.10)
  i <- 1
  while (i <= length(args)) {
    a <- args[i]
    if (a == "--year") {
      out$year <- as.integer(args[i + 1]); i <- i + 2
    } else if (a == "--receipts") {
      out$receipts <- args[i + 1]; i <- i + 2
    } else if (a == "--tol") {
      out$tol <- as.numeric(args[i + 1]); i <- i + 2
    } else {
      cli::cli_abort("Unknown argument: {.val {a}}")
    }
  }
  out
}

run_validation <- function(year = NULL, receipts = NULL, tol = 0.10) {
  section("1. Load benchmarks + parameters")
  benchmarks <- load_benchmarks()
  params <- load_params("config/scenario_params.yaml")
  if (is.null(year)) year <- params$raw$baseline_year
  cat(sprintf("  validating tax_units_%d.csv against %d benchmarks (tol=%.0f%%)\n",
              year, nrow(benchmarks), 100 * tol))

  section("2. Load tax-units + apply passthrough split")
  dt <- load_tax_units(year)
  cat(sprintf("  %d rows; weight sum = %.1fM tax units\n",
              nrow(dt), sum(dt$weight) / 1e6))
  dt <- apply_passthrough_split(dt, params)

  section("3. Compute aggregates")
  agg        <- compute_aggregates(dt)
  rev_agg    <- compute_revenue_aggregates(receipts, year)
  top_shares <- compute_top_shares(dt)
  computed   <- c(agg, rev_agg, top_shares)

  # Apply benchmark→data mapping (some benchmarks are year-specific).
  remap <- benchmark_to_data_map(year)
  for (bm_id in names(remap)) {
    src <- remap[[bm_id]]
    if (!is.na(src) && !is.null(computed[[src]])) {
      computed[[bm_id]] <- computed[[src]]
    }
  }

  section("4. Compare to benchmarks")
  cmp <- build_comparison(benchmarks, computed, tol)
  print_comparison(cmp, tol)

  section("5. Distributional moments")
  print_top_share_diagnostic(top_shares, benchmarks)

  section("6. Asset aggregates")
  asset_agg <- compute_asset_aggregates(dt)
  print_asset_aggregates(asset_agg)

  section("7. Macro K/Y diagnostic")
  L0d <- agg$L0_data; K0d <- agg$K0_data; Y0d <- agg$Y0_data
  cat(sprintf("  L0$ = %s\n", fmt_T(L0d)))
  cat(sprintf("  K0$ = %s\n", fmt_T(K0d)))
  cat(sprintf("  Y0$ = %s\n", fmt_T(Y0d)))
  cat(sprintf("  data K0/Y0 = %.4f   param 1-L0 = %.4f   diff = %+5.2f pp\n",
              K0d / Y0d, params$K0, 100 * (K0d / Y0d - params$K0)))
  cat("  Expected: large negative gap. NIPA includes employer FICA, retained\n")
  cat("  corporate earnings, and imputed housing rent that fall outside the\n")
  cat("  microsim's tax-base income concept.\n")

  invisible(list(comparison = cmp, top_shares = top_shares,
                 asset_aggregates = asset_agg))
}

# ---- script entry point --------------------------------------------- #

if (sys.nframe() == 0) {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  run_validation(year = args$year, receipts = args$receipts, tol = args$tol)
}
