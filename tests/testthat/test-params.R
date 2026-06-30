# 02_params.R: derivation algebra and validation guards. Pure unit
# tests against the committed yaml — no tax-units data involved.

.params_yaml <- here::here("config", "scenario_params.yaml")

test_that("share_mode = F collapses to g_k = g_l = g_y", {
  p <- load_params(.params_yaml, variant = "M", share_mode = "F")
  expect_equal(p$theta1_k, p$theta0_k, tolerance = 1e-12)
  expect_equal(p$g_k, p$g_y,           tolerance = 1e-12)
  expect_equal(p$g_l, p$g_y,           tolerance = 1e-12)
})

test_that("share_mode = R reproduces the documented derivation", {
  for (v in names(.AXIS_VARIANTS)) {
    p        <- load_params(.params_yaml, variant = v, share_mode = "R")
    theta1_l <- 1 - p$theta1_k
    g_k_exp  <- (p$theta1_k * (1 + p$g_y) - p$theta0_k) / p$theta0_k
    g_l_exp  <- (theta1_l   * (1 + p$g_y) - p$theta0_l) / p$theta0_l
    expect_equal(p$g_k, g_k_exp, tolerance = 1e-12, info = v)
    expect_equal(p$g_l, g_l_exp, tolerance = 1e-12, info = v)
  }
})

test_that("unknown variant / share_mode abort", {
  expect_error(load_params(.params_yaml, variant = "Z"), "variant")
  expect_error(load_params(.params_yaml, variant = "M", share_mode = "X"),
               "share_mode")
})

test_that("a missing required key aborts naming the gap", {
  raw <- yaml::read_yaml(.params_yaml)
  raw$labor_inequality$k <- NULL
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(raw, tmp)
  # Key validation fires before retirement_calibration.yaml resolution,
  # so no sibling copy is needed next to the temp file.
  expect_error(load_params(tmp), "labor_inequality.k", fixed = TRUE)
})

test_that("out-of-range theta1_k aborts (typo guard)", {
  raw <- yaml::read_yaml(.params_yaml)
  raw$shock$variants$M$theta1_k <- 46.2  # percent typed as level
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(raw, tmp)
  expect_error(load_params(tmp, variant = "M"), "theta1_k")
})

test_that("rolling horizon_start_year forward aborts until the keys move", {
  raw <- yaml::read_yaml(.params_yaml)
  raw$cbo_baseline$horizon_start_year <- 2026L
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(raw, tmp)
  expect_error(load_params(tmp, variant = "M"), "2025")
})
