# Build the two calibration receipts behind the Version 1.2 baseline path
# and nonfarm-business bridge (docs/v1_2_plan.md, rung 1: A1 and A2).
# Standalone; not in the orchestrator. The pipeline reads only the
# committed CSVs, so CI and contributor machines never need the sources.
#
#   config/calibration/cbo_2026_02_baseline_path.csv
#     CBO February 2026 baseline, calendar years 2025-2036: real GDP,
#     real gross value added in nonfarm business, nominal GDP, and
#     compensation of employees. Source: the "2. Calendar Year" sheet of
#     CBO's Economic-Projections.xlsx, the workbook Macro-Projections
#     vintage 2026071916 is built from (its dependencies.csv:
#     CBO_Econ_Proj v3 20260211). Macro-Projections itself starts its
#     income lines and real-GDP index in 2026; the survey's base year is
#     2025, so the receipt reads the workbook.
#
#   config/calibration/cbo_2026_02_budget_path.csv
#     CBO February 2026 baseline, fiscal years 2025-2036: GDP, total
#     revenues, and revenues by source (individual income, payroll,
#     corporate income taxes). Source: Table 1-1 of CBO's
#     Budget-Projections.xlsx (CBO_Budget_Proj v3 20260211). The annual
#     window's CBO anchors (rung 4, A3) and the FY2026 receipts comparison
#     (A5).
#
#   config/calibration/nipa_sector_gva_2025.csv
#     BEA NIPA, 2025: gross value added by sector (Table 1.3.5),
#     compensation of employees in each sector outside nonfarm business
#     (Tables 1.13 and 6.2D), and the income side of GDP (Table 1.10),
#     from BEA's public annual flat file.
#
# Usage (from repo root):
#   Rscript code/12_baseline_receipts.R <CBO Economic-Projections.xlsx> \
#     <CBO Budget-Projections.xlsx> [BEA download dir]

suppressPackageStartupMessages({
  library(data.table)
  library(readxl)
})

.PATH_YEARS <- 2025:2036
.NIPA_YEAR  <- 2025L
.BEA_URL    <- "https://apps.bea.gov/national/Release/TXT/NipaDataA.txt"
.CBO_SHEET  <- "2. Calendar Year"

# Row labels in the CBO sheet; the units column disambiguates rows that
# share a label.
.CBO_ROWS <- list(
  real_gdp_B2017     = c("Real GDP", "Billions of chained (2017) dollars"),
  real_gva_nfb_B2017 = c("Real gross value added: nonfarm business", "Billions of chained (2017) dollars"),
  gdp_B              = c("Gross domestic product (GDP)", "Billions of dollars"),
  comp_paid_B        = c("Compensation of employees, paid", "Billions of dollars")
)

# NIPA series codes (BEA SeriesRegister) and where they print.
# The gdi_* rows are the income side of GDP (Table 1.10), for the
# national-income reconciliation (09_tables_figures.R, plan item B1):
# GDP = compensation + production taxes - subsidies + net operating
# surplus + depreciation + statistical discrepancy.
.NIPA_ROWS <- data.table(
  component = c("gdp", "gva_nonfarm_business", "gva_farm", "gva_households",
                "gva_npish", "gva_general_government",
                "comp_farms", "comp_households", "comp_npish",
                "comp_general_government",
                "gdi_compensation", "gdi_taxes_on_production", "gdi_subsidies",
                "gdi_net_interest", "gdi_business_transfers", "gdi_proprietors",
                "gdi_rental", "gdi_corporate_profits", "gdi_gov_enterprise_surplus",
                "gdi_depreciation", "gdi_statistical_discrepancy"),
  nipa_code = c("A191RC", "A358RC", "B359RC", "B701RC", "B702RC", "A765RC",
                "N4005C", "W151RC", "W152RC", "A194RC",
                "A4002C", "W056RC", "A107RC", "W272RC", "B029RC", "A041RC",
                "A048RC", "A445RC", "A108RC", "A262RC", "A030RC"),
  nipa_line = c("T10305:1", "T10305:3", "T10305:4", "T10305:6", "T10305:7",
                "T10305:8", "T60200D:5", "T11300:43", "T11300:50", "T11300:56",
                "T11000:2", "T11000:7", "T11000:8", "T11000:11", "T11000:12",
                "T11000:13", "T11000:14", "T11000:15", "T11000:20", "T11000:21",
                "T11000:24")
)

build_cbo_baseline_path <- function(workbook) {
  sheet <- as.data.frame(read_excel(workbook, .CBO_SHEET, col_names = FALSE,
                                    .name_repair = "minimal"))
  header_row <- which(sheet[[2]] == "Units")[1]
  years      <- suppressWarnings(as.integer(unlist(sheet[header_row, ])))
  cols       <- match(.PATH_YEARS, years)
  if (anyNA(cols)) cli::cli_abort("{.path {workbook}} lacks years {.val {.PATH_YEARS[is.na(cols)]}}.")
  out <- data.table(year = .PATH_YEARS)
  for (name in names(.CBO_ROWS)) {
    row <- which(sheet[[1]] == .CBO_ROWS[[name]][1] & sheet[[2]] == .CBO_ROWS[[name]][2])
    if (length(row) != 1L) cli::cli_abort("Expected one {.val {.CBO_ROWS[[name]][1]}} row in {.path {workbook}}; found {length(row)}.")
    out[[name]] <- as.numeric(unlist(sheet[row, cols]))
  }
  out
}

.BUDGET_SHEET <- "Table 1-1"
.BUDGET_ROWS  <- c(individual_B = "Individual income taxes", payroll_B = "Payroll taxes",
                   corporate_B = "Corporate income taxes", revenues_B = "Total",
                   gdp_fy_B = "GDP")

# Table 1-1 in billions: the first block of rows. "Total" appears again for
# outlays, so each label's first match is taken.
build_cbo_budget_path <- function(workbook) {
  sheet <- as.data.frame(read_excel(workbook, .BUDGET_SHEET, col_names = FALSE,
                                    .name_repair = "minimal"))
  year_row <- which(vapply(seq_len(nrow(sheet)), function(i)
    all(c("2025", "2036") %in% as.character(unlist(sheet[i, ]))), logical(1)))[1]
  years <- suppressWarnings(as.integer(unlist(sheet[year_row, ])))
  cols  <- match(.PATH_YEARS, years)
  if (anyNA(cols)) cli::cli_abort("{.path {workbook}} lacks fiscal years {.val {.PATH_YEARS[is.na(cols)]}}.")
  out <- data.table(fy = .PATH_YEARS)
  for (name in names(.BUDGET_ROWS)) {
    row <- which(sheet[[1]] == .BUDGET_ROWS[[name]])[1]
    if (is.na(row)) cli::cli_abort("No {.val {.BUDGET_ROWS[[name]]}} row in {.path {workbook}}.")
    out[[name]] <- as.numeric(unlist(sheet[row, cols]))
  }
  out
}

build_nipa_sector_gva <- function(bea_dir) {
  fp <- file.path(bea_dir, basename(.BEA_URL))
  if (!file.exists(fp)) {
    dir.create(bea_dir, recursive = TRUE, showWarnings = FALSE)
    utils::download.file(.BEA_URL, fp, quiet = TRUE)
  }
  nipa <- fread(fp, colClasses = "character")
  setnames(nipa, c("nipa_code", "year", "value"))
  nipa <- nipa[year == .NIPA_YEAR & nipa_code %in% .NIPA_ROWS$nipa_code]
  out  <- merge(.NIPA_ROWS, nipa[, .(nipa_code, value_B = as.numeric(gsub(",", "", value)) / 1e3)],
                by = "nipa_code", all.x = TRUE, sort = FALSE)
  if (anyNA(out$value_B)) cli::cli_abort("NIPA {.NIPA_YEAR} values missing for {.val {out[is.na(value_B), nipa_code]}}.")
  out[, `:=`(year = .NIPA_YEAR, retrieved = format(file.mtime(fp), "%Y-%m-%d"))]
  out[match(.NIPA_ROWS$component, component),
      .(component, year, value_B, nipa_code, nipa_line, retrieved)]
}

if (!interactive() && sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) %in% 2:3) {
    stop("Usage: Rscript code/12_baseline_receipts.R <CBO Economic-Projections.xlsx> <CBO Budget-Projections.xlsx> [BEA download dir]")
  }
  bea_dir <- if (length(args) == 3L) args[[3]] else file.path("output", "bea")
  path <- build_cbo_baseline_path(args[[1]])
  fwrite(path, "config/calibration/cbo_2026_02_baseline_path.csv")
  budget <- build_cbo_budget_path(args[[2]])
  fwrite(budget, "config/calibration/cbo_2026_02_budget_path.csv")
  print(budget)
  sector <- build_nipa_sector_gva(bea_dir)
  fwrite(sector, "config/calibration/nipa_sector_gva_2025.csv")
  print(path)
  print(sector)
}
