# Compare a run's tables/ against a reference set of aggregate CSVs (rung 0
# reproduction, layer 3: the legacy run against the erratum's run D).
#
# Usage: Rscript tests/server/compare_run_tables.R <run tables dir> <reference dir>
#
# Every CSV in the reference directory must exist in the run with the same
# columns and rows. Rows are matched after sorting on the text columns;
# text columns must match exactly and numeric columns to REL_TOL (relative,
# as in the v1.0.1 erratum's reproduction of v1.0.0). Prints one line per
# file and LAYER3 PASS, or exits with status 1.

suppressPackageStartupMessages(library(data.table))

REL_TOL <- 1e-9

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
run_dir <- args[[1]]; ref_dir <- args[[2]]

compare_table <- function(name) {
  run_fp <- file.path(run_dir, name)
  if (!file.exists(run_fp)) return("missing from the run")
  run <- fread(run_fp); ref <- fread(file.path(ref_dir, name))
  if (!identical(names(run), names(ref))) return("columns differ")
  if (nrow(run) != nrow(ref)) return(sprintf("%d rows vs %d", nrow(run), nrow(ref)))

  text_cols <- names(ref)[vapply(ref, is.character, logical(1))]
  if (length(text_cols)) { setorderv(run, text_cols); setorderv(ref, text_cols) }
  for (col in names(ref)) {
    a <- run[[col]]; b <- ref[[col]]
    if (is.numeric(a) && is.numeric(b)) {
      if (!identical(is.na(a), is.na(b))) return(sprintf("%s: NA pattern differs", col))
      cmp <- all.equal(a, b, tolerance = REL_TOL)
      if (!isTRUE(cmp)) {
        return(sprintf("%s: %s (max abs diff %.3g)", col, cmp[1],
                       max(abs(a - b), na.rm = TRUE)))
      }
    } else if (!identical(as.character(a), as.character(b))) {
      return(sprintf("%s: values differ", col))
    }
  }
  "ok"
}

ref_files <- sort(list.files(ref_dir, pattern = "\\.csv$"))
results   <- vapply(ref_files, compare_table, character(1))
for (f in ref_files) cat(sprintf("%-36s %s\n", f, results[[f]]))

failed <- results != "ok"
if (any(failed)) {
  cat(sprintf("LAYER3 FAIL: %d of %d tables differ\n", sum(failed), length(results)))
  quit(status = 1)
}
cat(sprintf("LAYER3 PASS: %d of %d tables match\n", length(results), length(results)))
