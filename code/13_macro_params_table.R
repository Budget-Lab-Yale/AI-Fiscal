# Per-cell macro / shock parameters table for the publishable bundle.
# One row per (variant, share_mode, labor_scenario). Realization is not
# included — it doesn't change macro params, so a per-cell row would
# duplicate. Sigma is labor-scenario specific: NA for S0, and
# (1 -/+ k * g_y) for S2 / S3.

suppressPackageStartupMessages({
  library(data.table)
})

.sigma_for_labor <- function(scenario, k, gy) {
  switch(scenario,
    "S0" = NA_real_,
    "S2" = 1 - k * gy,
    "S3" = 1 + k * gy,
    NA_real_
  )
}

build_macro_params_table <- function(per_variant, labor_scenarios) {
  rows <- list()
  for (key in names(per_variant)) {
    pv    <- per_variant[[key]]
    parts <- strsplit(key, "|", fixed = TRUE)[[1]]
    p     <- pv$params
    m     <- attr(pv$step_b, "macro")
    k     <- p$k_inequality
    for (lbr in labor_scenarios) {
      rows[[length(rows) + 1L]] <- data.table(
        variant         = parts[1],
        share_mode      = parts[2],
        labor_scenario  = lbr,
        theta_0_L       = p$L0,
        theta_0_K       = p$K0,
        theta_1_L       = 1 - p$s1,
        theta_1_K       = p$s1,
        g_y             = p$gy,
        g_k             = p$gk,
        alpha           = p$alpha,
        sigma           = .sigma_for_labor(lbr, k, p$gy),
        L0_B            = m$L0_dollar / 1e9,
        L1_B            = m$L1_dollar / 1e9,
        K0_B            = m$K0_dollar / 1e9,
        K1_B            = m$K1_dollar / 1e9,
        X_B             = m$X         / 1e9,
        X_to_units_B    = m$X_to_units / 1e9,
        kappa_corp      = m$kappa_corp,
        cit_statutory   = m$cit_statutory,
        eta_corp        = m$eta_corp,
        delta_R_CIT_B   = m$delta_R_CIT / 1e9
      )
    }
  }
  rbindlist(rows)
}

# Write the table as a sibling to the runscript at
# <runscript>_cell_params.csv. 09_tables_figures.R reads this back to
# embed it as a sheet in the publishable workbook.
write_macro_params_table <- function(per_variant, labor_scenarios,
                                     runscript_path) {
  tbl <- build_macro_params_table(per_variant, labor_scenarios)
  fp  <- sub("\\.csv$", "_cell_params.csv", runscript_path)
  fwrite(tbl, fp)
  cli::cli_inform("Wrote per-cell macro-params {.path {fp}} ({nrow(tbl)} rows)")
  fp
}
