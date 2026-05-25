# Step A: each labor-incidence scenario must rescale aggregate YiL to
# hit the L1 target derived from (gk, alpha) on the data baseline.

test_that("Step A aggregate matches L1 target for S0 / S2 / S3", {
  for (scenario in c("S0", "S2", "S3")) {
    dt <- shock_labor(dt_baseline, params, scenario = scenario)
    meta <- attr(dt, "step_a")
    resid <- meta$L1_actual / meta$L1_target - 1
    expect_lt(abs(resid), 1e-6,
              label = sprintf("Step A %s residual", scenario))
  }
})

test_that("S0 scales every positive-YiL unit by a single multiplier", {
  # The test's intent is uniformity on the positive subset (S0 holds
  # negatives fixed; positives all scale by rho_pos =
  # (L1 − neg_baseline) / L0_pos). Compare unit-level ratios against
  # each other rather than against the step_a$rho aggregate, which
  # equals rho_pos only when neg_baseline = 0.
  dt <- shock_labor(dt_baseline, params, scenario = "S0")
  pos <- dt$YiL > 0
  ratios <- dt$YiL1[pos] / dt$YiL[pos]
  expect_lt(max(ratios) - min(ratios), 1e-9)
})

test_that("Unknown labor scenarios abort", {
  expect_error(
    shock_labor(dt_baseline, params, scenario = "S1"),
    regexp = "Unknown"
  )
})

test_that("S2 / S3 sigma equals 1 -/+ k * g_y and rescales log dispersion", {
  k     <- params$k_inequality
  gy    <- params$gy
  cases <- list(S2 = 1 - k * gy, S3 = 1 + k * gy)

  pos_idx <- which(dt_baseline$YiL > 0)
  w0      <- dt_baseline$weight[pos_idx]
  ln0     <- log(dt_baseline$YiL[pos_idx])
  mu0     <- sum(w0 * ln0) / sum(w0)
  sd0     <- sqrt(sum(w0 * (ln0 - mu0)^2) / sum(w0))

  for (scn in names(cases)) {
    expected_sigma <- cases[[scn]]
    dt_a <- shock_labor(dt_baseline, params, scenario = scn)
    expect_equal(attr(dt_a, "step_a")$sigma, expected_sigma, tolerance = 1e-12)

    keep <- dt_a$YiL1[pos_idx] > 0
    ln1  <- log(dt_a$YiL1[pos_idx][keep])
    w1   <- w0[keep]
    mu1  <- sum(w1 * ln1) / sum(w1)
    sd1  <- sqrt(sum(w1 * (ln1 - mu1)^2) / sum(w1))
    expect_equal(sd1 / sd0, expected_sigma, tolerance = 1e-6,
                 label = sprintf("%s log-sd ratio", scn))
  }
})

test_that("S2 / S3 hold negative-YiL units at baseline", {
  neg_idx <- which(dt_baseline$YiL < 0)
  skip_if(length(neg_idx) == 0,
          "Fixture has no negative-YiL units; cannot exercise this invariant.")
  for (scn in c("S2", "S3")) {
    dt_a <- shock_labor(dt_baseline, params, scenario = scn)
    expect_equal(dt_a$YiL1[neg_idx], dt_baseline$YiL[neg_idx],
                 tolerance = 1e-12,
                 label = sprintf("%s negative-YiL baseline preserved", scn))
  }
})

test_that("S2 aborts when k * g_y >= 1 (sigma <= 0)", {
  bad_params <- params
  bad_params$k_inequality <- 1 / params$gy   # forces sigma_S2 = 0
  expect_error(
    shock_labor(dt_baseline, bad_params, scenario = "S2"),
    regexp = "sigma must be positive"
  )
})
