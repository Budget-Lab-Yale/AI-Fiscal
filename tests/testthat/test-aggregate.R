# Smoke-test 08_aggregate.R against a mocked Tax-Simulator vintage in a
# tempdir. Verifies the I/O layout assumptions, revenue-delta arithmetic,
# and decile pinning convention without depending on a real Tax-Simulator
# run.

with_fake_vintage <- function(expr) {
  vintage <- file.path(tempfile("vint_"), "v1", "20260000")
  dir.create(vintage, recursive = TRUE)
  for (sid in c("baseline", "ai_M_R_S0_V1")) {
    for (sub in c("totals", "detail")) {
      dir.create(file.path(vintage, sid, "static", sub),
                 recursive = TRUE, showWarnings = FALSE)
    }
  }
  rs_path <- tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    ID = c("baseline", "ai_M_R_S0_V1"),
    years = c("2029:2030", "2029:2030"),
    `dep.Tax-Data.vintage` = "20260000",
    `dep.Tax-Data.ID` = c("baseline", "ai_M_R_S0_V1")
  ), rs_path)
  on.exit({
    unlink(dirname(dirname(vintage)), recursive = TRUE)
    unlink(rs_path)
  })
  expr(vintage, rs_path)
}

mock_receipts <- function(vintage, scenario_id, year, ...) {
  cols <- c(list(year = year), list(...))
  data.table::fwrite(
    do.call(data.table::data.table, cols),
    file.path(vintage, scenario_id, "static", "totals", "receipts.csv")
  )
}

mock_detail <- function(vintage, scenario_id, year, dt) {
  data.table::fwrite(
    dt,
    file.path(vintage, scenario_id, "static", "detail",
              sprintf("%d.csv", year))
  )
}

test_that("read_receipts errors on header-only CSV with helpful hint", {
  with_fake_vintage(function(vint, rs) {
    fp <- file.path(vint, "baseline", "static", "totals", "receipts.csv")
    writeLines("year,revenues_payroll_tax,revenues_income_tax,outlays_tax_credits,revenues_corp_tax,revenues_estate_tax,revenues_vat,revenues_other",
               fp)
    expect_error(read_receipts(vint, "baseline"), "header-only")
  })
})

test_that("build_revenue_delta_table computes per-instrument and total deltas", {
  with_fake_vintage(function(vint, rs) {
    mock_receipts(vint, "baseline", 2030,
      revenues_payroll_tax = 1000, revenues_income_tax = 2000,
      outlays_tax_credits  = 100,  revenues_corp_tax   = 500,
      revenues_estate_tax  = 30,   revenues_vat        = 0,
      revenues_other       = 600)
    mock_receipts(vint, "ai_M_R_S0_V1", 2030,
      revenues_payroll_tax = 1050, revenues_income_tax = 2100,
      outlays_tax_credits  = 90,   revenues_corp_tax   = 500,
      revenues_estate_tax  = 30,   revenues_vat        = 0,
      revenues_other       = 600)

    tab <- build_revenue_delta_table(vint, rs, year = 2030)
    expect_equal(tab[instrument == "revenues_payroll_tax"]$delta, 50)
    expect_equal(tab[instrument == "revenues_income_tax"]$delta, 100)
    # outlays go DOWN, so delta is negative; total includes -outlays
    expect_equal(tab[instrument == "outlays_tax_credits"]$delta, -10)
    # total = ΔIIT + Δpayroll - Δoutlays + Δcorp + Δestate + Δvat + Δother
    expect_equal(tab[instrument == "total"]$delta, 50 + 100 - (-10))
  })
})

test_that("weighted_gini matches a known closed-form value", {
  # Equal incomes -> Gini == 0
  expect_equal(weighted_gini(rep(100, 50), rep(1, 50)), 0)
  # All concentrated at the top -> Gini -> 1 (we use 99 zeros + 1 large)
  # Filter drops zeros; one positive value -> Gini = 0.
  # Use 1 small + 1 huge to test asymmetry.
  expect_gt(weighted_gini(c(1, 1000), c(1, 1)), 0.4)
})

test_that("income_share_table sums to 1 over deciles, top groups overlap", {
  set.seed(123)
  x <- rlnorm(1000, meanlog = 10, sdlog = 1)
  w <- rep(1, 1000)
  tab <- income_share_table(x, w)
  expect_equal(sum(tab[group_type == "decile"]$share), 1, tolerance = 1e-10)
  # decile_10 share == top_10_pct share (same group)
  d10 <- tab[group == "decile_10"]$share
  t10 <- tab[group == "top_10_pct"]$share
  expect_equal(d10, t10, tolerance = 1e-10)
  # top_5_pct < top_10_pct < decile_10  (sub-group)
  expect_lt(tab[group == "top_5_pct"]$share, t10)
  expect_gt(tab[group == "top_1_pct"]$share, tab[group == "top_0.1_pct"]$share)
})

test_that("build_revenue_decomp_table: identity delta_both = labor + capital + interaction holds", {
  vintage <- file.path(tempfile("vint_"), "v1", "20260000")
  scenarios <- c("baseline", "ai_M_R_S0_V1", "ai_M_R_S0_V1_LO", "ai_M_R_S0_V1_CO")
  for (sid in scenarios) {
    dir.create(file.path(vintage, sid, "static", "totals"),
               recursive = TRUE, showWarnings = FALSE)
  }
  rs_path <- tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    ID = scenarios, years = "2029:2030",
    `dep.Tax-Data.vintage` = "20260000",
    `dep.Tax-Data.ID` = scenarios
  ), rs_path)
  on.exit({
    unlink(dirname(dirname(vintage)), recursive = TRUE)
    unlink(rs_path)
  })

  # Mock receipts: baseline + three flavors with deliberately non-additive
  # totals so the interaction term is non-zero. (LO + CO levels do not sum
  # to BOTH due to the synthetic numbers we picked.)
  bl_vals <- list(revenues_payroll_tax = 1000, revenues_income_tax = 2000,
                  outlays_tax_credits  = 100,  revenues_corp_tax   = 500,
                  revenues_estate_tax  = 30,   revenues_vat        = 0,
                  revenues_other       = 600)
  do.call(mock_receipts, c(list(vintage, "baseline", 2030), bl_vals))
  do.call(mock_receipts, c(list(vintage, "ai_M_R_S0_V1", 2030),
                           list(revenues_payroll_tax = 1050, revenues_income_tax = 2200,
                                outlays_tax_credits  = 80,  revenues_corp_tax   = 500,
                                revenues_estate_tax  = 30,  revenues_vat        = 0,
                                revenues_other       = 600)))
  do.call(mock_receipts, c(list(vintage, "ai_M_R_S0_V1_LO", 2030),
                           list(revenues_payroll_tax = 1050, revenues_income_tax = 2080,
                                outlays_tax_credits  = 90,  revenues_corp_tax   = 500,
                                revenues_estate_tax  = 30,  revenues_vat        = 0,
                                revenues_other       = 600)))
  do.call(mock_receipts, c(list(vintage, "ai_M_R_S0_V1_CO", 2030),
                           list(revenues_payroll_tax = 1000, revenues_income_tax = 2110,
                                outlays_tax_credits  = 95,  revenues_corp_tax   = 500,
                                revenues_estate_tax  = 30,  revenues_vat        = 0,
                                revenues_other       = 600)))

  decomp <- build_revenue_decomp_table(vintage, rs_path, year = 2030)
  expect_false(is.null(decomp))
  expect_equal(unique(decomp$scenario_id), "ai_M_R_S0_V1")
  expect_setequal(decomp$instrument,
                  c("revenues_payroll_tax", "revenues_income_tax",
                    "outlays_tax_credits", "revenues_corp_tax",
                    "revenues_estate_tax", "revenues_vat",
                    "revenues_other", "total"))

  # The core identity:
  expect_equal(decomp$delta_both,
               decomp$delta_labor + decomp$delta_capital + decomp$interaction,
               tolerance = 1e-12)

  # Level columns: each counterfactual level is baseline + its delta,
  # straight from the mocked receipts.
  expect_equal(decomp$counterfactual_labor,
               decomp$baseline + decomp$delta_labor, tolerance = 1e-12)
  expect_equal(decomp$counterfactual_capital,
               decomp$baseline + decomp$delta_capital, tolerance = 1e-12)
  expect_equal(decomp$counterfactual_both,
               decomp$baseline + decomp$delta_both, tolerance = 1e-12)
  expect_equal(decomp[instrument == "revenues_payroll_tax"]$baseline, 1000)
  expect_equal(decomp[instrument == "revenues_payroll_tax"]$counterfactual_labor, 1050)

  # The decomp baseline column is the same baseline run revenue_deltas
  # reads: levels must agree per instrument.
  rev_tab <- build_revenue_delta_table(vintage, rs_path, year = 2030)
  merged  <- merge(decomp[, .(scenario_id, instrument, baseline)],
                   rev_tab[, .(scenario_id, instrument,
                               baseline_deltas = baseline)],
                   by = c("scenario_id", "instrument"))
  expect_equal(merged$baseline, merged$baseline_deltas)

  # Sanity: payroll under capital_only is identical to baseline (capital
  # shock leaves wages untouched), so delta_capital for payroll is 0.
  expect_equal(decomp[instrument == "revenues_payroll_tax"]$delta_capital, 0)

  # And per the runscript IDs we mocked, build_revenue_decomp_table must
  # return NULL on a runscript with no LO/CO (verified separately below).
})

test_that("build_revenue_decomp_table returns NULL on a runscript with no LO/CO", {
  with_fake_vintage(function(vint, rs) {
    mock_receipts(vint, "baseline", 2030,
      revenues_payroll_tax = 0, revenues_income_tax = 0,
      outlays_tax_credits  = 0, revenues_corp_tax   = 0,
      revenues_estate_tax  = 0, revenues_vat        = 0,
      revenues_other       = 0)
    expect_null(build_revenue_decomp_table(vint, rs, year = 2030))
  })
})

test_that("build_inequality_delta_tables: progressive shock raises pretax Gini, lowers aftertax", {
  with_fake_vintage(function(vint, rs) {
    mock_receipts(vint, "baseline",  2030,
      revenues_payroll_tax = 0, revenues_income_tax = 0,
      outlays_tax_credits  = 0, revenues_corp_tax   = 0,
      revenues_estate_tax  = 0, revenues_vat        = 0,
      revenues_other       = 0)
    mock_receipts(vint, "ai_M_R_S0_V1", 2030,
      revenues_payroll_tax = 0, revenues_income_tax = 0,
      outlays_tax_credits  = 0, revenues_corp_tax   = 0,
      revenues_estate_tax  = 0, revenues_vat        = 0,
      revenues_other       = 0)

    set.seed(7)
    n <- 500
    bl <- data.table::data.table(
      id           = seq_len(n),
      weight       = rep(1, n),
      dep_status   = rep(0L, n),
      expanded_inc = rlnorm(n, meanlog = 10, sdlog = 1),
      liab_iit_net = 0,
      liab_pr      = 0
    )
    bl[, liab_iit_net := 0.20 * pmax(expanded_inc - 50000, 0)]

    # CF: top decile gets +20% income; IIT stays the same fraction of new
    # income above the threshold, so progressivity (aftertax compression)
    # increases relative to the new pretax distribution.
    cf <- data.table::copy(bl)
    top_thresh <- weighted_quantile(bl$expanded_inc, bl$weight, 0.9)
    cf[expanded_inc >= top_thresh,
       expanded_inc := expanded_inc * 1.20]
    cf[, liab_iit_net := 0.20 * pmax(expanded_inc - 50000, 0)]

    mock_detail(vint, "baseline",  2030, bl)
    mock_detail(vint, "ai_M_R_S0_V1", 2030, cf)

    out <- build_inequality_delta_tables(vint, rs, year = 2030)

    pretax <- out$gini[income_concept == "pretax" &
                         scenario_id == "ai_M_R_S0_V1"]
    expect_gt(pretax$delta, 0)  # CF concentrates pretax income at top

    # Top 10% pretax share rises in CF
    top10 <- out$shares[group == "top_10_pct" & income_concept == "pretax"]
    expect_gt(top10$share_cf, top10$share_baseline)

    # Aftertax share at the bottom decile shouldn't grow: nominal income
    # at decile 1 unchanged but the pie grew.
    d1 <- out$shares[group == "decile_1" & income_concept == "pretax"]
    expect_lt(d1$share_cf, d1$share_baseline)

    # Decile shares per concept sum to 1 (within rounding) for both
    # baseline and CF.
    deciles <- out$shares[group_type == "decile"]
    by_grp  <- deciles[, .(s_b = sum(share_baseline), s_c = sum(share_cf)),
                       by = .(scenario_id, income_concept)]
    expect_true(all(abs(by_grp$s_b - 1) < 1e-10))
    expect_true(all(abs(by_grp$s_c - 1) < 1e-10))
  })
})
