# Annual-window tables (docs/v1_2_plan.md, rung 4, A3 and E1b).
#
# 08 and 09 write one set of tables per fiscal year (<stem>_<year>.csv).
# For an annual window this step stacks each set into one long table with a
# `year` column (<stem>_by_year.csv) and sums revenue over the budget window
# (revenue_window_totals.csv). The first fiscal year scored before the
# window (FY2026) is the nowcast year: it is in the by-year tables but not
# in the window totals.

suppressPackageStartupMessages({
  library(data.table)
})

.ANNUAL_TABLE_STEMS <- c(
  "revenue_grid", "revenue_grid_wide", "revenue_deltas", "revenue_decomp",
  "income_deltas", "gini_deltas", "share_deltas", "atr_decile",
  "decile_panel", "revenue_to_gdp", "share_mode_comparison",
  "national_income_reconciliation"
)

# Columns of revenue_grid_wide that identify a scenario rather than hold a
# revenue amount.
.REVENUE_ID_COLS <- c("scenario_id", "variant", "variant_label", "share_mode",
                      "share_mode_label", "labor", "labor_label", "realization",
                      "realization_label")

stack_annual_tables <- function(tables_dir, years) {
  written <- character()
  for (stem in .ANNUAL_TABLE_STEMS) {
    fps <- file.path(tables_dir, sprintf("%s_%d.csv", stem, years))
    present <- file.exists(fps)
    if (!any(present)) next
    if (!all(present)) {
      cli::cli_abort("{.val {stem}} is missing for fiscal year{?s} {.val {years[!present]}}.")
    }
    stacked <- rbindlist(lapply(seq_along(years), function(i) {
      tbl <- fread(fps[i])
      if (!"year" %in% names(tbl)) tbl[, year := years[i]]
      setcolorder(tbl, "year")
    }), use.names = TRUE)
    out <- file.path(tables_dir, sprintf("%s_by_year.csv", stem))
    fwrite(stacked, out)
    written <- c(written, out)
  }
  written
}

# Ten-year revenue totals by scenario: every revenue column of
# revenue_grid_wide summed over the window's fiscal years.
build_window_totals <- function(tables_dir, window_years) {
  wide <- fread(file.path(tables_dir, "revenue_grid_wide_by_year.csv"))
  missing <- setdiff(window_years, wide$year)
  if (length(missing)) cli::cli_abort("revenue_grid_wide_by_year lacks fiscal years {.val {missing}}.")
  amounts <- setdiff(names(wide), c("year", .REVENUE_ID_COLS))
  totals <- wide[year %in% window_years,
                 lapply(.SD, sum), by = .REVENUE_ID_COLS, .SDcols = amounts]
  totals[, window := sprintf("FY%d-%d", min(window_years), max(window_years))]
  setcolorder(totals, c("window", .REVENUE_ID_COLS))
  totals[]
}

# Orchestrator entry: stack the per-year tables and write the window totals.
write_annual_tables <- function(tables_dir, report_years, window_years) {
  written <- stack_annual_tables(tables_dir, report_years)
  # A window that reports one fiscal year (e.g. tax years 2029-2030 for a
  # full-year FY2030) has no multi-year total.
  if (!length(window_years)) {
    cli::cli_inform("Wrote {length(written)} by-year table{?s}; no window totals for a single fiscal year.")
    return(invisible(written))
  }
  totals  <- build_window_totals(tables_dir, window_years)
  fp <- file.path(tables_dir, "revenue_window_totals.csv")
  fwrite(totals, fp)
  cli::cli_inform("Wrote {length(written)} by-year table{?s} and {.path {fp}}.")
  invisible(c(written, fp))
}
