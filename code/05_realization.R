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

# capital_flow.ai_gains_realized (m_AI, Version 1.2 rung 3, C1) scales the
# in-year gains below the mechanical V1 value: the AI gains flow is
# realized at m_AI times the baseline rate already in the reported base.
# The unrealized part is deferred past the year or stepped up at death and
# reaches no tax base. m_AI = 1 is V1.
apply_realization <- function(step_b, ai_gains_realized = 1) {
  step_b[, X_ltcg_V1 := X_ltcg_gross * ai_gains_realized]
  setattr(step_b, "realization", list(variant = "V1",
                                      ai_gains_realized = ai_gains_realized))
  step_b
}
