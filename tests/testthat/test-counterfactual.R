# Counterfactual data construction: the output schema must match what the
# Tax-Simulator expects, and each capital-income column must absorb its
# corresponding aggregate flow from Step B.

test_that("counterfactual retains all required PUF columns", {
  required <- c("wages", "wages1", "wages2", "sole_prop", "farm",
                "scorp_active", "scorp_active_loss", "scorp_passive",
                "part_active", "part_passive",
                "txbl_int", "exempt_int", "div_ord", "div_pref",
                "kg_st", "kg_lt", "filing_status", "weight", "id")
  expect_true(all(required %in% names(dt_cf)))
})

test_that("CF wages obey wages_cf == wages_base * rho_i per unit", {
  # build_counterfactual scales wages by rho_i = y_l1 / y_l on every
  # unit (rho_i = 1 where y_l = 0). The aggregate ratio
  # sum(wages_cf) / sum(wages_base) equals attr(step_a)$rho only when
  # the wage composition lines up exactly with the y_l composition,
  # which it doesn't in general (some units have positive wages but
  # y_l ≤ 0 due to passthrough losses). Test the identity at the unit
  # level instead.
  step_a_dt <- as.data.table(dt_step_a)[, .(id, y_l, y_l1)]
  setkey(step_a_dt, id)
  base <- as.data.table(dt_baseline)[, .(id, wages_base = wages)]
  cf   <- as.data.table(dt_cf)[, .(id, wages_cf = wages)]
  m    <- merge(merge(step_a_dt, base, by = "id"), cf, by = "id")
  m[, rho_i := fifelse(y_l != 0, y_l1 / y_l, 1)]
  m[, pred  := wages_base * rho_i]
  expect_lt(max(abs(m$wages_cf - m$pred)), 1e-3)
})

# Identity tolerances are RELATIVE to the flow magnitude (floor $1):
# an absolute $1e-3 is ~1e-16 relative against full-PUF trillion-scale
# sums — within long-double reassociation error at n ~ 2e5 — so the
# old form passed on the 10k synthetic fixture but could flake on real
# data. 1e-12 relative is ~$1 per $1T: tight but reassociation-proof.
.rel_tol <- function(scale) 1e-12 * max(1, abs(scale))

test_that("CF div_pref absorbs X_qualified_div", {
  d_b  <- sum(dt_baseline$weight * dt_baseline$div_pref)
  d_cf <- sum(dt_cf$weight       * dt_cf$div_pref)
  qd   <- sum(step_b$weight      * step_b$X_qualified_div)
  expect_lt(abs((d_cf - d_b) - qd), .rel_tol(d_b))
})

test_that("CF kg_lt absorbs X_ltcg_V1", {
  k_b  <- sum(dt_baseline$weight * dt_baseline$kg_lt)
  k_cf <- sum(dt_cf$weight       * dt_cf$kg_lt)
  v1   <- sum(step_b$weight      * step_b$X_ltcg_V1)
  expect_lt(abs((k_cf - k_b) - v1), .rel_tol(k_b))
})

test_that("CF kg_lt_years_held and kg_lt_basis are non-NA wherever kg_lt != 0", {
  # Tax-Simulator's calc_kg_cpi_ratio rejects NA on either side for
  # kg_lt != 0, including loss units (kg_lt < 0).
  bad_yh <- sum(dt_cf$kg_lt != 0 & is.na(dt_cf$kg_lt_years_held))
  bad_b  <- sum(dt_cf$kg_lt != 0 & is.na(dt_cf$kg_lt_basis))
  expect_equal(bad_yh, 0L)
  expect_equal(bad_b,  0L)
})

test_that("CF interest absorbs X_taxable_int + X_tax_exempt_int", {
  int_b  <- sum(dt_baseline$weight *
                  (dt_baseline$txbl_int + dt_baseline$exempt_int))
  int_cf <- sum(dt_cf$weight *
                  (dt_cf$txbl_int + dt_cf$exempt_int))
  flow   <- sum(step_b$weight *
                  (step_b$X_taxable_int + step_b$X_tax_exempt_int))
  expect_lt(abs((int_cf - int_b) - flow), .rel_tol(int_b))
})

# --- Phase-1 flavor decomposition: build_counterfactual(flavor = ...) -----
#
# `dt_cf` (default `flavor = "both"`) is the baseline regression target.
# `dt_cf_LO` (`flavor = "labor_only"`) modifies labor columns only;
# capital columns must equal baseline. `dt_cf_CO` (`flavor = "capital_only"`)
# modifies capital columns only; labor columns must equal baseline.
# Passthrough columns mix labor and capital and are tested via aggregate
# absorption rather than bit-equality.

dt_cf_LO <- build_counterfactual(
  dt_baseline, dt_step_a, step_b,
  params = params, flavor = "labor_only"
)
dt_cf_CO <- build_counterfactual(
  dt_baseline, dt_step_a, step_b,
  params = params, flavor = "capital_only"
)

test_that("flavor attribute is set", {
  expect_identical(attr(dt_cf,    "counterfactual")$flavor, "both")
  expect_identical(attr(dt_cf_LO, "counterfactual")$flavor, "labor_only")
  expect_identical(attr(dt_cf_CO, "counterfactual")$flavor, "capital_only")
})

test_that("labor_only leaves capital columns at baseline", {
  cap_cols <- c("div_pref", "txbl_int", "exempt_int", "kg_lt")
  for (col in cap_cols) {
    expect_equal(dt_cf_LO[[col]], dt_baseline[[col]],
                 info = paste("col =", col))
  }
})

test_that("labor_only scales labor columns identically to both", {
  labor_cols <- c("wages", "wages1", "wages2", "sole_prop")
  for (col in labor_cols) {
    if (col %in% names(dt_cf)) {
      expect_equal(dt_cf_LO[[col]], dt_cf[[col]],
                   info = paste("col =", col))
    }
  }
})

test_that("capital_only leaves labor columns at baseline", {
  labor_cols <- c("wages", "wages1", "wages2", "sole_prop")
  for (col in labor_cols) {
    if (col %in% names(dt_cf)) {
      expect_equal(dt_cf_CO[[col]], dt_baseline[[col]],
                   info = paste("col =", col))
    }
  }
})

test_that("capital_only augments capital columns identically to both", {
  cap_cols <- c("div_pref", "txbl_int", "exempt_int", "kg_lt",
                "kg_lt_years_held", "kg_lt_basis")
  for (col in cap_cols) {
    expect_equal(dt_cf_CO[[col]], dt_cf[[col]],
                 info = paste("col =", col))
  }
})

test_that("LO and CO each absorb their share of the aggregate flows", {
  # Labor: aggregate wages under labor_only equal aggregate wages under both
  # (rho scaling is identical); both differ from baseline by rho - 1.
  wages_b  <- sum(dt_baseline$weight * dt_baseline$wages)
  wages_LO <- sum(dt_cf_LO$weight    * dt_cf_LO$wages)
  wages_CO <- sum(dt_cf_CO$weight    * dt_cf_CO$wages)
  expect_lt(abs(wages_LO - sum(dt_cf$weight * dt_cf$wages)),
            .rel_tol(wages_b))
  expect_lt(abs(wages_CO - wages_b), .rel_tol(wages_b))

  # Capital: aggregate kg_lt under capital_only equals aggregate kg_lt under
  # both; labor_only leaves kg_lt at baseline.
  kg_b  <- sum(dt_baseline$weight * dt_baseline$kg_lt)
  kg_LO <- sum(dt_cf_LO$weight    * dt_cf_LO$kg_lt)
  kg_CO <- sum(dt_cf_CO$weight    * dt_cf_CO$kg_lt)
  expect_lt(abs(kg_LO - kg_b), .rel_tol(kg_b))
  expect_lt(abs(kg_CO - sum(dt_cf$weight * dt_cf$kg_lt)), .rel_tol(kg_b))
})
