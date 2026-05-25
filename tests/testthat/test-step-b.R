# Step B: the across-units allocation and the income-type map must each
# preserve the X_to_units aggregate to machine epsilon.

test_that("sum(w * X_i) equals X_to_units", {
  total <- sum(step_b$weight * step_b$X_i)
  expect_lt(abs(total / macro$X_to_units - 1), 1e-6)
})

test_that("sum of per-income-type flows equals X_to_units", {
  # Under R1 the retirement slice maps entirely to X_pens_gross +
  # X_ira_gross (no deferred remainder). The taxable columns
  # X_pens_txbl / X_ira_txbl are components of the gross flows, not
  # separate masses.
  inc_cols <- c("X_qualified_div", "X_taxable_int", "X_tax_exempt_int",
                "X_ltcg_gross", "X_passthrough_ordinary",
                "X_pens_gross", "X_ira_gross")
  inc_sums <- sapply(inc_cols, function(col) {
    sum(step_b$weight * step_b[[col]])
  })
  total <- sum(inc_sums)
  expect_lt(abs(total / macro$X_to_units - 1), 1e-6)
})

test_that("X reaches tax units in full (CIT acts upstream)", {
  expect_equal(macro$X_to_units, macro$X, tolerance = 1e-9)
})

test_that("CIT delta scales with X relative to K0$", {
  expected_ratio <- macro$cbo_cit_baseline_dollar / macro$K0_dollar
  expect_equal(macro$delta_R_CIT / macro$X, expected_ratio,
               tolerance = 1e-9)
})

test_that("eta calibration recovers CBO CIT level at baseline", {
  corp <- params$raw$corporate
  baseline_cit <- corp$cit_statutory * macro$K0_dollar * corp$kappa_corp /
    macro$eta_corp
  expect_equal(baseline_cit, macro$cbo_cit_baseline_dollar,
               tolerance = 1e-6 * macro$cbo_cit_baseline_dollar)
})
