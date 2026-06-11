# 02_params.R: derivation algebra and validation guards. Pure unit
# tests against the committed yaml — no tax-units data involved.

.params_yaml <- here::here("config", "scenario_params.yaml")

test_that("share_mode = F collapses to gk = gy, alpha = 1", {
  p <- load_params(.params_yaml, variant = "M", share_mode = "F")
  expect_equal(p$s1, 1 - p$L0, tolerance = 1e-12)
  expect_equal(p$gk, p$gy,     tolerance = 1e-12)
  expect_equal(p$alpha, 1,     tolerance = 1e-12)
})

test_that("share_mode = R reproduces the documented derivation", {
  for (v in names(.AXIS_VARIANTS)) {
    p  <- load_params(.params_yaml, variant = v, share_mode = "R")
    K1 <- p$s1 * (1 + p$gy)
    L1 <- (1 - p$s1) * (1 + p$gy)
    expect_equal(p$K1, K1, tolerance = 1e-12, info = v)
    expect_equal(p$gk, (K1 - p$K0) / p$K0, tolerance = 1e-12, info = v)
    expect_equal(p$alpha, (1 / p$gk) * (L1 - p$L0) / p$L0,
                 tolerance = 1e-12, info = v)
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

test_that("out-of-range s1 aborts (typo guard)", {
  raw <- yaml::read_yaml(.params_yaml)
  raw$shock$variants$M$s1 <- 46.2  # percent typed as level
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(raw, tmp)
  expect_error(load_params(tmp, variant = "M"), "s1")
})

test_that("rolling horizon_start_year forward aborts until the keys move", {
  raw <- yaml::read_yaml(.params_yaml)
  raw$cbo_baseline$horizon_start_year <- 2026L
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(raw, tmp)
  expect_error(load_params(tmp, variant = "M"), "2025")
})
