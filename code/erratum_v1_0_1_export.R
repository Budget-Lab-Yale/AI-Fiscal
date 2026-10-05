# Export the v1.0.1 erratum result set: every run's CSVs plus side-by-side
# comparisons that attribute each change to one of the two fixes.
#
# Usage: Rscript code/erratum_v1_0_1_export.R <runs_dir> <dest_dir>
#   <runs_dir> holds one folder per run (RUNS below), each a snapshot of that
#   run's results/aggregates CSVs + *_latest.xlsx bundles, figure_data_2030.xlsx
#   and paper_figure_data_2030.xlsx.
#   <dest_dir> is created; it receives runs/<run>/... and comparison/....
#
# Runs (2 x 2 grid of the two fixes):
#   A  v1.0.0 as published  (pooled labor shares,     rounded CBO ratios)
#   B  Karger fix only      (Economists labor shares, rounded CBO ratios)
#   C  CBO fix only         (pooled labor shares,     exact CBO ratios)
#   D  v1.0.1               (Economists labor shares, exact CBO ratios)
# Effects reported per number: karger_fix = B - A, cbo_fix = C - A,
# total = D - A, interaction = D - B - C + A.

suppressPackageStartupMessages(library(data.table))

RUNS <- c(A = "A_v1.0.0_published", B = "B_karger_fix",
          C = "C_cbo_fix",          D = "D_v1.0.1")
YEAR <- 2030L
PARAM_SHEETS <- c("parameter_index", "cell_params", "parameters")

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
runs_dir <- args[[1]]; dest <- args[[2]]

run_path <- function(run, f) file.path(runs_dir, RUNS[[run]], f)
pub_xlsx <- function(run) run_path(run, sprintf("ai_fiscal_publishable_%d_latest.xlsx", YEAR))

for (run in names(RUNS)) {
  required <- c(pub_xlsx(run), run_path(run, sprintf("figure_data_%d.xlsx", YEAR)),
                run_path(run, sprintf("paper_figure_data_%d.xlsx", YEAR)))
  missing <- required[!file.exists(required)]
  if (length(missing)) stop("Missing inputs for run ", run, ":\n  ", paste(missing, collapse = "\n  "))
}

sheet_to_csv <- function(xlsx, sheet, out_dir, col_names = TRUE) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  d <- openxlsx::read.xlsx(xlsx, sheet, colNames = col_names, skipEmptyRows = FALSE)
  fwrite(d, file.path(out_dir, paste0(gsub("[^A-Za-z0-9_.-]+", "_", sheet), ".csv")),
         col.names = col_names)
}

# ---- 1. Per-run CSV exports ----------------------------------------------
for (run in names(RUNS)) {
  out <- file.path(dest, "runs", RUNS[[run]])
  agg <- file.path(out, "aggregates")
  dir.create(agg, recursive = TRUE, showWarnings = FALSE)
  csvs <- list.files(file.path(runs_dir, RUNS[[run]]), pattern = "\\.csv$", full.names = TRUE)
  stopifnot(length(csvs) > 0L)
  file.copy(csvs, agg, overwrite = TRUE)

  fig_xlsx <- run_path(run, sprintf("figure_data_%d.xlsx", YEAR))
  for (s in openxlsx::getSheetNames(fig_xlsx)) sheet_to_csv(fig_xlsx, s, file.path(out, "figure_data"))

  # Paper exhibits are formatted tables (titles, notes rows), so keep raw cells.
  paper_xlsx <- run_path(run, sprintf("paper_figure_data_%d.xlsx", YEAR))
  for (s in openxlsx::getSheetNames(paper_xlsx))
    sheet_to_csv(paper_xlsx, s, file.path(out, "paper_figure_data"), col_names = FALSE)

  for (s in PARAM_SHEETS) sheet_to_csv(pub_xlsx(run), s, file.path(out, "parameters"))
}

# ---- 2. Side-by-side comparisons -----------------------------------------
cmp_dir <- file.path(dest, "comparison")
dir.create(cmp_dir, recursive = TRUE, showWarnings = FALSE)

add_effects <- function(w) {
  w[, `:=`(karger_fix  = B - A,
           cbo_fix     = C - A,
           total       = D - A,
           interaction = D - B - C + A)]
  w
}

# Wide-by-run table for numeric columns of a keyed sheet.
compare_keyed <- function(sheet, keys, metrics) {
  long <- rbindlist(lapply(names(RUNS), function(run) {
    d <- as.data.table(openxlsx::read.xlsx(pub_xlsx(run), sheet))
    melt(d[, c(keys, metrics), with = FALSE], id.vars = keys,
         variable.name = "metric", variable.factor = FALSE)[, run := run]
  }))
  w <- dcast(long, as.formula(paste(paste(c(keys, "metric"), collapse = " + "), "~ run")),
             value.var = "value")
  # A structural NA (e.g. lambda for proportional S0 cells) must be NA in
  # every run; an NA in only some runs means a row failed to line up.
  na_runs <- rowSums(is.na(w[, names(RUNS), with = FALSE]))
  stopifnot(all(na_runs %in% c(0L, length(RUNS))))
  add_effects(w)
}

REV_METRICS <- c("total_with_macro_cit", "total", "macro_cit_delta", "total_labor",
                 "total_capital", "total_interaction", "revenues_income_tax",
                 "revenues_payroll_tax", "revenues_corp_tax", "outlays_tax_credits")
fwrite(compare_keyed("revenue_grid_wide", "scenario_id", REV_METRICS),
       file.path(cmp_dir, sprintf("revenue_%d.csv", YEAR)))

fwrite(compare_keyed("revenue_to_gdp", "scenario_id",
                     c("delta_rev_to_gdp_cbo", "scenario_rev_to_gdp_cbo", "baseline_rev_to_gdp_cbo",
                       "baseline_revenue_B_cbo", "delta_rev_to_gdp", "g_y")),
       file.path(cmp_dir, sprintf("revenue_to_gdp_%d.csv", YEAR)))

fwrite(compare_keyed("decile_panel", c("scenario_id", "income_concept", "decile"), "delta"),
       file.path(cmp_dir, sprintf("decile_share_delta_%d.csv", YEAR)))

fwrite(compare_keyed("cell_params", c("variant", "share_mode", "labor_scenario"),
                     setdiff(names(openxlsx::read.xlsx(pub_xlsx("A"), "cell_params", rows = 1:2)),
                             c("variant", "share_mode", "labor_scenario"))),
       file.path(cmp_dir, sprintf("cell_params_%d.csv", YEAR)))

# Gini lives in the microsim bundle.
gini <- rbindlist(lapply(names(RUNS), function(run) {
  f <- run_path(run, sprintf("ai_fiscal_%d_latest.xlsx", YEAR))
  as.data.table(openxlsx::read.xlsx(f, "gini_deltas"))[, run := run]
}))
gini_w <- add_effects(dcast(gini, scenario_id + income_concept ~ run, value.var = "delta"))
fwrite(gini_w, file.path(cmp_dir, sprintf("gini_delta_%d.csv", YEAR)))

# Paper exhibits (Table 1, Figures 1-7, appendix): every numeric cell, by run.
# Cells are keyed by (sheet, row, col); row_label / col_label give the
# exhibit's own first-column and header text so a reader can find the number.
paper_cells <- function(run) {
  f <- run_path(run, sprintf("paper_figure_data_%d.xlsx", YEAR))
  rbindlist(lapply(setdiff(openxlsx::getSheetNames(f), "Data TOC"), function(s) {
    m <- as.matrix(openxlsx::read.xlsx(f, s, colNames = FALSE, skipEmptyRows = FALSE,
                                       skipEmptyCols = FALSE))
    num <- suppressWarnings(matrix(as.numeric(m), nrow(m)))
    idx <- which(!is.na(num), arr.ind = TRUE)
    if (!nrow(idx)) return(NULL)
    # Header row = last row above the first numeric cell that has text in it.
    first_num_row <- min(idx[, 1])
    hdr_row <- max(c(1L, which(rowSums(!is.na(m[seq_len(first_num_row - 1L), , drop = FALSE])) > 1L)))
    data.table(sheet = s, row = idx[, 1], col = idx[, 2],
               row_label = m[cbind(idx[, 1], 1L)], col_label = m[cbind(hdr_row, idx[, 2])],
               value = num[idx], run = run)
  }))
}
paper <- rbindlist(lapply(names(RUNS), paper_cells))
paper_w <- dcast(paper, sheet + row + col ~ run, value.var = "value")
labels  <- unique(paper[run == "A", .(sheet, row, col, row_label, col_label)])
paper_w <- add_effects(merge(labels, paper_w, by = c("sheet", "row", "col"), all.y = TRUE))
fwrite(paper_w[order(sheet, row, col)], file.path(cmp_dir, sprintf("paper_exhibits_%d.csv", YEAR)))

cat("Wrote", length(list.files(dest, recursive = TRUE)), "files under", dest, "\n")
