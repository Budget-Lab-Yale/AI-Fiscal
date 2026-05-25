# R4 income-flow retirement cascade — see the "Retirement flow
# treatment" section of docs/ai_fiscal_methodology.md.
# The yaml default is R4 as of 2026-05-21, but tests run under whatever
# the loaded params resolve to; this file mints its own params with
# retirement.variant pinned to R4 to keep the test independent of yaml
# drift.

suppressPackageStartupMessages({
  library(data.table)
})

params_r4 <- load_params(here::here("config", "scenario_params.yaml"))

step_b_r4 <- allocate_capital(
  dt_baseline, params_r4,
  asset_map_path = here::here("config", "asset_to_income_map.csv")
)

cal      <- params_r4$retirement_cal
macro_r4 <- attr(step_b_r4, "macro")

test_that("R4 pools the entire retirement slice (no r_R discount)", {
  # The cascade's F_total equals the residual = X_to_units - non-retirement
  # aggregates. Macro carries the same number on `retirement_F`.
  non_retirement <- sum(step_b_r4$weight *
                          (step_b_r4$X_qualified_div +
                           step_b_r4$X_taxable_int + step_b_r4$X_tax_exempt_int +
                           step_b_r4$X_ltcg_gross +
                           step_b_r4$X_passthrough_ordinary))
  slice <- macro_r4$X_to_units - non_retirement
  expect_lt(abs(macro_r4$retirement_F / slice - 1), 1e-9)
})

test_that("R4 gross == taxable on both pension and IRA (taxable-only framing)", {
  expect_equal(step_b_r4$X_pens_gross, step_b_r4$X_pens_txbl)
  expect_equal(step_b_r4$X_ira_gross,  step_b_r4$X_ira_txbl)
})

test_that("R4 per-unit pens + IRA = F_i; aggregate sums to F_total", {
  per_unit <- step_b_r4$X_pens_txbl + step_b_r4$X_ira_txbl
  agg      <- sum(step_b_r4$weight * per_unit)
  expect_lt(abs(agg / macro_r4$retirement_F - 1), 1e-9)
})

test_that("R4 pension/IRA split matches taxable-shares t_P / t_I", {
  T_P <- cal$s_P * cal$tau_P
  T_I <- cal$s_I * cal$tau_I
  t_P <- T_P / (T_P + T_I)
  t_I <- T_I / (T_P + T_I)
  active <- (step_b_r4$X_pens_txbl + step_b_r4$X_ira_txbl) > 0
  expect_true(any(active))
  pens_share <- step_b_r4$X_pens_txbl[active] /
                  (step_b_r4$X_pens_txbl[active] + step_b_r4$X_ira_txbl[active])
  ira_share  <- step_b_r4$X_ira_txbl[active] /
                  (step_b_r4$X_pens_txbl[active] + step_b_r4$X_ira_txbl[active])
  expect_lt(max(abs(pens_share - t_P)), 1e-9)
  expect_lt(max(abs(ira_share  - t_I)), 1e-9)
})

test_that("R4 flow lands only on units with positive taxable retirement income", {
  has_txbl <- (dt_baseline$txbl_ira_dist + dt_baseline$txbl_pens_dist) > 0
  joined   <- merge(step_b_r4[, .(id, X_pens_txbl, X_ira_txbl)],
                    dt_baseline[, .(id, txbl_ira_dist, txbl_pens_dist)],
                    by = "id", all.x = TRUE)
  off_set  <- joined[(txbl_ira_dist + txbl_pens_dist) <= 0]
  expect_equal(sum(off_set$X_pens_txbl), 0)
  expect_equal(sum(off_set$X_ira_txbl),  0)
})

test_that("R4 aborts cleanly when calibration produces a zero taxable denominator", {
  bad_params <- params_r4
  bad_params$retirement_cal$tau_P <- 0
  bad_params$retirement_cal$tau_I <- 0
  expect_error(
    allocate_capital(dt_baseline, bad_params,
                     asset_map_path = here::here("config", "asset_to_income_map.csv")),
    "zero taxable-share denominator"
  )
})
