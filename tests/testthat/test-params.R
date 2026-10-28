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

# Rung 0 reproduction, layer 1 (docs/v1_2_plan.md): the legacy setting
# derives the v1.0.1 parameters. Reference is run D (v1.0.1) of the erratum
# result set, which records them per cell; they do not vary by labor rule.
test_that("legacy_v1_0_1 reproduces the v1.0.1 derived parameters", {
  ref <- data.table::fread(here::here(
    "results", "erratum_v1.0.1", "comparison", "cell_params_2030.csv"))
  ref <- ref[labor_scenario == "S0"]
  metric_to_field <- c(g_y = "g_y", g_k = "g_k", g_l = "g_l",
                       theta_0_L = "theta0_l", theta_1_K = "theta1_k")
  for (v in names(.AXIS_VARIANTS)) for (m in names(.AXIS_SHARE_MODES)) {
    p <- load_params(.params_yaml, variant = v, share_mode = m,
                     setting = "legacy_v1_0_1")
    for (name in names(metric_to_field)) {
      expected <- ref[variant == v & share_mode == m & metric == name, D]
      expect_length(expected, 1L)
      expect_equal(p[[metric_to_field[[name]]]], expected, tolerance = 1e-12,
                   info = paste(v, m, name))
    }
  }
})

# Build a throwaway config dir holding a copy of the base yaml, its
# retirement calibration, and one overlay named `trial`.
.setting_fixture <- function(overlay) {
  dir <- tempfile("settings_fixture_")
  dir.create(file.path(dir, "settings"), recursive = TRUE)
  file.copy(.params_yaml, file.path(dir, "scenario_params.yaml"))
  file.copy(here::here("config", "retirement_calibration.yaml"), dir)
  yaml::write_yaml(overlay, file.path(dir, "settings", "trial.yaml"))
  file.path(dir, "scenario_params.yaml")
}

test_that("a setting overlay overrides only the keys it lists", {
  yml <- .setting_fixture(list(labor_inequality = list(k = 2, k_rung = 0L)))
  p   <- load_params(yml, variant = "M", setting = "trial")
  p0  <- load_params(yml, variant = "M")
  expect_identical(p$setting, "trial")
  expect_equal(p$k_inequality, 2)
  expect_null(p$raw$labor_inequality$k_rung)
  p$raw$labor_inequality$k <- p0$raw$labor_inequality$k
  expect_identical(p$raw, p0$raw)
})

test_that("an overlay key absent from the base yaml aborts", {
  yml <- .setting_fixture(list(labor_inequality = list(kk = 2)))
  expect_error(load_params(yml, setting = "trial"), "labor_inequality.kk",
               fixed = TRUE)
})

test_that("an overlay null value aborts instead of deleting the key", {
  yml <- .setting_fixture(list(labor_inequality = list(k = NULL)))
  expect_error(load_params(yml, setting = "trial"), "null")
})

test_that("an unknown setting aborts naming the available ones", {
  expect_error(load_params(.params_yaml, setting = "no_such_setting"),
               "Unknown setting")
})

test_that("the committed v1_2_reference overlay loads", {
  p <- load_params(.params_yaml, variant = "M", setting = "v1_2_reference")
  expect_identical(p$setting, "v1_2_reference")
})
