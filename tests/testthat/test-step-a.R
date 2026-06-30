# Step A: each labor-incidence scenario must rescale aggregate y_l to
# hit the Y1^L target derived from g_l on the data baseline.

test_that("Step A aggregate matches Y1^L target for S0 / S2 / S3", {
  for (scenario in c("S0", "S2", "S3")) {
    dt <- shock_labor(dt_baseline, params, scenario = scenario)
    meta <- attr(dt, "step_a")
    resid <- meta$y1_l_actual / meta$y1_l_target - 1
    expect_lt(abs(resid), 1e-6,
              label = sprintf("Step A %s residual", scenario))
  }
})

test_that("S0 scales every positive-y_l unit by a single multiplier", {
  # The test's intent is uniformity on the positive subset (S0 holds
  # negatives fixed; positives all scale by rho_pos =
  # (Y1^L − neg_baseline) / Y0^L_pos). Compare unit-level ratios against
  # each other rather than against the step_a$rho aggregate, which
  # equals rho_pos only when neg_baseline = 0.
  dt <- shock_labor(dt_baseline, params, scenario = "S0")
  pos <- dt$y_l > 0
  ratios <- dt$y_l1[pos] / dt$y_l[pos]
  expect_lt(max(ratios) - min(ratios), 1e-9)
})

test_that("Unknown labor scenarios abort", {
  expect_error(
    shock_labor(dt_baseline, params, scenario = "S1"),
    regexp = "Unknown"
  )
})

test_that("S2 / S3 lambda equals 1 -/+ k * g_y and rescales log dispersion", {
  k     <- params$k_inequality
  g_y   <- params$g_y
  cases <- list(S2 = 1 - k * g_y, S3 = 1 + k * g_y)

  pos_idx <- which(dt_baseline$y_l > 0)
  w0      <- dt_baseline$weight[pos_idx]
  ln0     <- log(dt_baseline$y_l[pos_idx])
  mu0     <- sum(w0 * ln0) / sum(w0)
  sd0     <- sqrt(sum(w0 * (ln0 - mu0)^2) / sum(w0))

  for (scn in names(cases)) {
    expected_lambda <- cases[[scn]]
    dt_a <- shock_labor(dt_baseline, params, scenario = scn)
    expect_equal(attr(dt_a, "step_a")$lambda, expected_lambda, tolerance = 1e-12)

    keep <- dt_a$y_l1[pos_idx] > 0
    ln1  <- log(dt_a$y_l1[pos_idx][keep])
    w1   <- w0[keep]
    mu1  <- sum(w1 * ln1) / sum(w1)
    sd1  <- sqrt(sum(w1 * (ln1 - mu1)^2) / sum(w1))
    expect_equal(sd1 / sd0, expected_lambda, tolerance = 1e-6,
                 label = sprintf("%s log-sd ratio", scn))
  }
})

test_that("S2 / S3 hold negative-y_l units at baseline", {
  neg_idx <- which(dt_baseline$y_l < 0)
  skip_if(length(neg_idx) == 0,
          "Fixture has no negative-y_l units; cannot exercise this invariant.")
  for (scn in c("S2", "S3")) {
    dt_a <- shock_labor(dt_baseline, params, scenario = scn)
    expect_equal(dt_a$y_l1[neg_idx], dt_baseline$y_l[neg_idx],
                 tolerance = 1e-12,
                 label = sprintf("%s negative-y_l baseline preserved", scn))
  }
})

test_that("S2 aborts when k * g_y >= 1 (lambda <= 0)", {
  bad_params <- params
  bad_params$k_inequality <- 1 / params$g_y   # forces lambda_S2 = 0
  expect_error(
    shock_labor(dt_baseline, bad_params, scenario = "S2"),
    regexp = "lambda must be positive"
  )
})
