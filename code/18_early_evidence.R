# Early-evidence check (docs/v1_2_plan.md, rung 4, A5).
#
# Compares what each scenario implies for the first years of the window
# with what is already observable. Observed data never feed the scenarios.
# Two tables, written to <run dir>/tables/:
#
#   early_evidence_inputs.csv
#     The quantities the scenarios assume, 2025 to 2026: the change in the
#     nonfarm-business labor share (BLS PRS85006173, an index) and real GDP
#     growth (BEA GDPC1), observed against CBO's February 2026 baseline and
#     each preset's path. Changes, not levels: the labor-share index has no
#     level, and Karger's 2025 base (55.48%) is not tied to a quarter.
#
#   early_evidence_receipts.csv
#     FY2026 receipts (Monthly Treasury Statement, Table 4) minus CBO's
#     February 2026 projection, by category, next to the model's FY2026
#     nowcast change for each preset. The pattern is the test, not the
#     level: observed deviations also carry everything that is not AI.
#
# Observed values come from a dated snapshot,
# config/calibration/early_evidence_observed.csv, rebuilt with --refresh.
#
# Usage: Rscript code/18_early_evidence.R <run dir> [--refresh]

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")
source("code/02_params.R")

.OBSERVED_SNAPSHOT <- "config/calibration/early_evidence_observed.csv"
.FRED_CSV          <- "https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s"
.MTS_TABLE4        <- paste0("https://api.fiscaldata.treasury.gov/services/api/fiscal_service/",
                             "v1/accounting/mts/mts_table_4?filter=record_date:eq:%s&page%%5Bsize%%5D=200")
.NOWCAST_FY        <- 2026L
.BASE_YEAR         <- 2025L
.MTS_LINES <- c(individual = "Total -- Individual Income Taxes",
                payroll    = "Total -- Social Insurance and Retirement Receipts",
                corporate  = "Corporation Income Taxes",
                total      = "Total -- Receipts")

# --- observed snapshot -------------------------------------------------- #

.fred_quarters <- function(id) {
  x <- fread(sprintf(.FRED_CSV, id))
  setnames(x, c("date", "value"))
  d <- as.Date(x$date)
  x[, `:=`(series = id,
           period = sprintf("%sQ%d", format(d, "%Y"), (as.integer(format(d, "%m")) - 1L) %/% 3L + 1L))]
  x[as.Date(date) >= as.Date("2024-01-01"), .(series, period, value)]
}

.mts_fytd <- function(fy) {
  url  <- sprintf(.MTS_TABLE4, sprintf("%d-09-30", fy))
  rows <- jsonlite::fromJSON(url)$data
  rows <- as.data.table(rows)[classification_desc %in% .MTS_LINES]
  data.table(series = paste0("mts_", names(.MTS_LINES)[match(rows$classification_desc, .MTS_LINES)]),
             period = sprintf("FY%d", fy),
             value  = as.numeric(rows$current_fytd_net_rcpt_amt) / 1e9)
}

refresh_observed <- function(fp = .OBSERVED_SNAPSHOT) {
  snap <- rbind(.fred_quarters("PRS85006173"), .fred_quarters("GDPC1"),
                .mts_fytd(.NOWCAST_FY))
  snap[, retrieved := format(Sys.Date())]
  fwrite(snap, fp)
  cli::cli_inform("Wrote {.path {fp}} ({nrow(snap)} rows).")
  snap
}

# --- the two tables ----------------------------------------------------- #

# A calibration receipt the run's parameters name, from its inputs/ copy.
.run_receipt <- function(run_dir, key) {
  file <- yaml::read_yaml(file.path(run_dir, "inputs", "params.yaml"))$cbo_baseline[[key]]
  fread(file.path(run_dir, "inputs", basename(file)))
}

# Annual-average change from 2025 to the latest observed quarters of 2026,
# matched quarter by quarter (2026 so far against the same quarters of 2025).
.observed_change <- function(snap, series_id) {
  x <- snap[series == series_id]
  x[, `:=`(year = as.integer(substr(period, 1, 4)), q = substr(period, 6, 6))]
  q26 <- x[year == .BASE_YEAR + 1L, q]
  if (!length(q26)) cli::cli_abort("No {.BASE_YEAR + 1L} quarters of {.val {series_id}} in the snapshot.")
  later <- mean(x[year == .BASE_YEAR + 1L, value])
  base  <- mean(x[year == .BASE_YEAR & q %in% q26, value])
  list(change = later / base - 1,
       note   = sprintf("%d Q%s vs the same quarters of %d", .BASE_YEAR + 1L,
                        paste(q26, collapse = "-"), .BASE_YEAR))
}

build_inputs_table <- function(snap, run_dir, params_yaml, setting) {
  path <- .run_receipt(run_dir, "path_file")
  cbo_growth <- path[year == .BASE_YEAR + 1L, real_gdp_B2017] /
    path[year == .BASE_YEAR, real_gdp_B2017] - 1
  ls_obs  <- .observed_change(snap, "PRS85006173")
  gdp_obs <- .observed_change(snap, "GDPC1")
  rows <- list(
    data.table(quantity = "labor_share_change", source = "observed",
               value = ls_obs$change, note = ls_obs$note),
    data.table(quantity = "labor_share_change", source = "cbo_baseline",
               value = 0, note = "CBO holds nonfarm-business factor shares constant"),
    data.table(quantity = "real_gdp_growth", source = "observed",
               value = gdp_obs$change, note = gdp_obs$note),
    data.table(quantity = "real_gdp_growth", source = "cbo_baseline",
               value = cbo_growth, note = "CBO February 2026, calendar-year average")
  )
  for (v in names(.AXIS_VARIANTS)) {
    p25 <- load_params(params_yaml, variant = v, setting = setting, year = .BASE_YEAR)
    p26 <- load_params(params_yaml, variant = v, setting = setting, year = .BASE_YEAR + 1L)
    rows[[length(rows) + 1L]] <- data.table(
      quantity = c("labor_share_change", "real_gdp_growth"),
      source   = paste0("path_", v),
      value    = c(p26$theta1_l / p25$theta1_l - 1,
                   (1 + p26$g_y) * (1 + cbo_growth) - 1),
      note     = .AXIS_VARIANTS[[v]])
  }
  rbindlist(rows)
}

build_receipts_table <- function(snap, run_dir) {
  budget <- .run_receipt(run_dir, "budget_path_file")
  proj <- budget[fy == .NOWCAST_FY]
  projected <- c(individual = proj$individual_B, payroll = proj$payroll_B,
                 corporate = proj$corporate_B, total = proj$revenues_B)
  observed <- setNames(snap[period == sprintf("FY%d", .NOWCAST_FY), value],
                       sub("^mts_", "", snap[period == sprintf("FY%d", .NOWCAST_FY), series]))
  out <- data.table(category = names(projected),
                    cbo_projection_B = unname(projected),
                    actual_B = unname(observed[names(projected)]))
  out[, deviation_B := actual_B - cbo_projection_B]

  # The model's FY2026 nowcast: change in each category, reallocated shares,
  # proportional labor rule, for each preset.
  grid <- fread(file.path(run_dir, "tables", "revenue_grid_wide_by_year.csv"))
  cut  <- grid[year == .NOWCAST_FY & share_mode == "R" & labor == "S0"]
  model <- cut[, .(variant,
                   individual = revenues_income_tax, payroll = revenues_payroll_tax,
                   corporate = macro_cit_delta, total = total_with_macro_cit)]
  model <- melt(model, id.vars = "variant", variable.name = "category",
                value.name = "model_B", variable.factor = FALSE)
  model <- dcast(model, category ~ paste0("model_", variant, "_B"), value.var = "model_B")
  merge(out, model, by = "category", sort = FALSE)
}

write_early_evidence <- function(run_dir, refresh = FALSE) {
  setting <- yaml::read_yaml(file.path(run_dir, "manifest.yaml"))$setting
  snap <- if (refresh) refresh_observed() else fread(.OBSERVED_SNAPSHOT)
  # load_params needs the config tree (settings, receipts), not the run copy.
  inputs   <- build_inputs_table(snap, run_dir, "config/scenario_params.yaml", setting)
  receipts <- build_receipts_table(snap, run_dir)
  fwrite(inputs,   file.path(run_dir, "tables", "early_evidence_inputs.csv"))
  fwrite(receipts, file.path(run_dir, "tables", "early_evidence_receipts.csv"))
  invisible(list(inputs = inputs, receipts = receipts))
}

if (!interactive() && sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) || startsWith(args[1], "--")) {
    stop("Usage: Rscript code/18_early_evidence.R <run dir> [--refresh]")
  }
  out <- write_early_evidence(args[1], refresh = "--refresh" %in% args)
  print(out$inputs, digits = 3)
  print(out$receipts, digits = 4)
}
