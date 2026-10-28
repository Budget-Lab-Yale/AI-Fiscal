# National-income reconciliation (docs/v1_2_plan.md B1): components add up
# to GDP at baseline and under the shock, and the rules for each row hold.

.recon_nipa  <- data.table::fread(here::here("config", "calibration", "nipa_sector_gva_2025.csv"))
.recon_cells <- data.table::data.table(
  variant = c("M", "M"), share_mode = c("R", "F"), labor_scenario = "S0",
  g_y = c(0.034, 0.034), g_l = c(0.012, 0.034),
  y0_l_B = 15000, y1_l_B = c(15180, 15510), y0_k_B = 4500, X_B = c(270, 153),
  proprietors_capital_share = 0.2
)
.recon <- build_national_income_reconciliation(.recon_cells, .recon_nipa,
                                               gdp_B = 37742.5, year = 2030)

test_that("components sum to GDP and their changes to the change in GDP", {
  for (m in c("R", "F")) {
    cell  <- .recon[share_mode == m]
    parts <- cell[!group %in% c("total", "tax_returns")]
    expect_equal(sum(parts$baseline_B), cell[component == "gdp", baseline_B], tolerance = 1e-6)
    expect_equal(sum(parts$change_B), cell[component == "gdp", change_B], tolerance = 1e-9)
  }
})

test_that("each row follows its rule", {
  cell <- .recon[share_mode == "R"]
  expect_true(all(cell[component %in% c("rental", "net_interest", "gov_enterprise_surplus"), change_B] == 0))
  held <- cell[component %in% c("depreciation", "business_transfers")]
  expect_equal(held$change_B / held$baseline_B, rep(0.034, 2))
  expect_equal(cell[component == "compensation", change_B / baseline_B], 0.012)
  expect_equal(cell[component == "capital_income", change_B], 270)
  expect_equal(cell[component == "labor_income", change_B], 180)
  profit <- cell[component %in% c("corporate_profits", "proprietors_capital")]
  expect_equal(profit$change_B[1] / profit$change_B[2],
               profit$baseline_B[1] / profit$baseline_B[2])
})

test_that("the reconciliation needs the proprietors' capital share", {
  expect_error(
    build_national_income_reconciliation(.recon_cells[, !"proprietors_capital_share"],
                                         .recon_nipa, 37742.5, 2030),
    "proprietors_capital_share")
})
