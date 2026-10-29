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

test_that("CIT delta scales with X relative to Y0^K$", {
  expected_ratio <- macro$cbo_cit_baseline_dollar / macro$y0_k_dollar
  expect_equal(macro$delta_R_CIT / macro$X, expected_ratio,
               tolerance = 1e-9)
})

test_that("eta calibration recovers CBO CIT level at baseline", {
  corp <- params$raw$corporate
  baseline_cit <- corp$cit_statutory * macro$y0_k_dollar * corp$kappa_corp /
    macro$eta_corp
  expect_equal(baseline_cit, macro$cbo_cit_baseline_dollar,
               tolerance = 1e-6 * macro$cbo_cit_baseline_dollar)
})

# Rung 2 (docs/v1_2_plan.md B3): with interest on its baseline path, the
# bond slice moves to the other classes and X keeps its dollar size.
test_that("capital_flow.interest = baseline_path routes no X to interest", {
  p <- params
  p$raw$capital_flow$interest <- "baseline_path"
  sb <- allocate_capital(copy(dt_baseline), p,
                         asset_map_path = here::here("config", "asset_to_income_map.csv"))
  expect_equal(sum(sb$X_taxable_int), 0)
  expect_equal(sum(sb$X_tax_exempt_int), 0)
  expect_equal(sb$X_i, step_b$X_i)
  inc_cols <- c("X_qualified_div", "X_ltcg_gross", "X_passthrough_ordinary",
                "X_pens_gross", "X_ira_gross")
  total <- sum(vapply(inc_cols, function(col) sum(sb$weight * sb[[col]]), numeric(1)))
  expect_lt(abs(total / attr(sb, "macro")$X_to_units - 1), 1e-6)
  expect_identical(attr(sb, "macro")$delta_R_CIT, macro$delta_R_CIT)
})

# Rung 2: the primary residence, cash, and other nonfinancial assets can be
# left out of the wealth that sets each unit's share of X.
test_that("capital_flow.allocation_base = ex_home_cash_nonfin drops those assets", {
  p <- params
  p$raw$capital_flow$allocation_base <- "ex_home_cash_nonfin"
  sb_dt <- allocate_across_units(copy(dt_baseline), macro$X_to_units,
                                 p$raw$capital_flow$allocation_base)
  kept <- setdiff(.ASSET_BASE_ALL_ASSETS, c("primary_home", "cash", "other_nonfin"))
  expect_equal(sb_dt$A_base, rowSums(sb_dt[, ..kept]))
  expect_lt(abs(sum(sb_dt$weight * sb_dt$X_i) / macro$X_to_units - 1), 1e-9)
  only_excluded <- sb_dt$A_base == 0
  expect_true(all(sb_dt$X_i[only_excluded] == 0))
})

# Rung 3 (docs/v1_2_plan.md C1-C3).
test_that("the concentrating allocator hits its top-1% and top-0.1% targets", {
  p <- params
  p$raw$capital_flow$allocator <- "concentrating"
  sb <- allocate_capital(copy(dt_baseline), p,
                         asset_map_path = here::here("config", "asset_to_income_map.csv"))
  nw <- .net_worth(dt_baseline)
  top <- function(q) nw >= weighted_quantile(nw, dt_baseline$weight, q)
  X <- sum(sb$weight * sb$X_i)
  expect_equal(X, attr(sb, "macro")$X_to_units, tolerance = 1e-9)
  expect_equal(sum((sb$weight * sb$X_i)[top(0.99)]) / X,
               p$raw$capital_flow$concentration_top1, tolerance = 1e-9)
  expect_equal(sum((sb$weight * sb$X_i)[top(0.999)]) / X,
               p$raw$capital_flow$concentration_top01, tolerance = 1e-9)
})

test_that("payout splits the public-equity flow into dividends and gains", {
  p <- params
  p$raw$capital_flow$payout <- 0.5
  sb <- allocate_capital(copy(dt_baseline), p,
                         asset_map_path = here::here("config", "asset_to_income_map.csv"))
  expect_equal(sb$X_qualified_div, sb$X_ltcg_gross)
  expect_equal(sb$X_qualified_div + sb$X_ltcg_gross,
               step_b$X_qualified_div + step_b$X_ltcg_gross)
})

test_that("ai_gains_realized scales in-year gains only", {
  half <- apply_realization(copy(step_b), 0.5)
  expect_equal(half$X_ltcg_V1, 0.5 * step_b$X_ltcg_gross)
  expect_equal(half$X_qualified_div, step_b$X_qualified_div)
})

test_that("corporate sensitivities scale the corporate change", {
  p <- params
  p$raw$corporate$share_abroad   <- 0.25
  p$raw$corporate$share_interest <- 0.10
  m <- compute_macro_targets(dt_baseline, p)
  corp <- p$raw$corporate
  expect_equal(m$delta_R_CIT / macro$delta_R_CIT,
               1 - 0.25 * (1 - corp$abroad_rate / corp$cit_statutory) - 0.10)
  expect_equal(m$X, macro$X)
})
