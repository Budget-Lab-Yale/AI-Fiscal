# Step C: realization timing for the gross LTCG flows from Step B.
#
# Release version uses V1 (mechanical) exclusively: all gross LTCG gains
# are treated as realized in-year. Justified because Y0^K is built from
# the on-1040 realized base, so the baseline realization rate is
# already implicit in X — applying r again would double-count the
# discount (parallel to the R1 retirement argument). See the
# "Realization timing" section of docs/ai_fiscal_methodology.md.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

apply_realization <- function(step_b) {
  step_b[, X_ltcg_V1 := X_ltcg_gross]
  setattr(step_b, "realization", list(variant = "V1"))
  step_b
}
