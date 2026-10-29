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
# retirement calibration and baseline receipts, and one overlay named `trial`.
.setting_fixture <- function(overlay) {
  dir <- tempfile("settings_fixture_")
  dir.create(file.path(dir, "settings"), recursive = TRUE)
  dir.create(file.path(dir, "calibration"))
  file.copy(.params_yaml, file.path(dir, "scenario_params.yaml"))
  file.copy(here::here("config", "retirement_calibration.yaml"), dir)
  file.copy(here::here("config", "calibration",
                       c("cbo_2026_02_baseline_path.csv", "nipa_sector_gva_2025.csv")),
            file.path(dir, "calibration"))
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

# Rung 1 (docs/v1_2_plan.md A1, A2): each switch moves only its own piece.
.rung1 <- function(...) {
  yml <- .setting_fixture(list(...))
  lapply(setNames(nm = c("R", "F")), function(m)
    load_params(yml, variant = "M", share_mode = m, setting = "trial"))
}
.legacy_m <- lapply(setNames(nm = c("R", "F")), function(m)
  load_params(.params_yaml, variant = "M", share_mode = m))

test_that("growth_path = annual measures g_y against CBO's real GDP path", {
  p    <- .rung1(cbo_baseline = list(growth_path = "annual"))$R
  path <- data.table::fread(here::here("config", "calibration",
                                       "cbo_2026_02_baseline_path.csv"))
  expect_equal(p$cum_base, path[year == 2030, real_gdp_B2017] /
                           path[year == 2025, real_gdp_B2017])
  expect_equal(p$g_y, (1 + p$r_ai_annual)^p$horizon / p$cum_base - 1)
  expect_identical(p$theta0_l, .legacy_m$R$theta0_l)
})

test_that("share_baseline = projected moves theta0_l by the CBO compensation drift", {
  p    <- .rung1(shock = list(share_baseline = "projected"))$R
  path <- data.table::fread(here::here("config", "calibration",
                                       "cbo_2026_02_baseline_path.csv"))
  drift <- path[year == 2030, comp_paid_B / gdp_B] - path[year == 2025, comp_paid_B / gdp_B]
  expect_equal(p$theta0_l, .legacy_m$R$theta0_l + drift)
  expect_identical(p$g_y, .legacy_m$R$g_y)
  expect_identical(p$theta1_k, .legacy_m$R$theta1_k)
})

test_that("sector = nonfarm_business keeps the economy's factor income adding up", {
  for (p in .rung1(shock = list(sector = "nonfarm_business"))) {
    expect_true(p$nfb_gva_share > 0.7 && p$nfb_gva_share < 0.85)
    expect_true(p$labor_other > 0.4 && p$labor_other < 0.7)
    # Labor plus capital growth, weighted by baseline shares, is g_y.
    expect_equal(p$g_l * p$theta0_l_economy + p$g_k * (1 - p$theta0_l_economy),
                 p$g_y, tolerance = 1e-12)
    expect_equal((1 + p$g_l) * p$theta0_l_economy, p$theta1_l_economy * (1 + p$g_y),
                 tolerance = 1e-12)
    expect_identical(p$g_y, .legacy_m[[p$share_mode]]$g_y)
  }
})

test_that("the nonfarm-business bridge damps the economy-wide share shift", {
  p <- .rung1(shock = list(sector = "nonfarm_business"))$R
  shift_economy <- p$theta1_l_economy - p$theta0_l_economy
  expect_true(shift_economy < 0)
  expect_true(abs(shift_economy) < abs(p$theta1_l - p$theta0_l))
  expect_true(p$g_k < .legacy_m$R$g_k)
})

test_that("an unknown switch value aborts naming the choices", {
  yml <- .setting_fixture(list(shock = list(sector = "nonfarm")))
  expect_error(load_params(yml, setting = "trial"), "whole_economy")
})

test_that("a setting can inherit another setting's overlay", {
  yml <- .setting_fixture(list(labor_inequality = list(k = 2)))
  dir <- dirname(yml)
  yaml::write_yaml(list(inherits = "trial", capital_flow = list(payout = 0.4)),
                   file.path(dir, "settings", "child.yaml"))
  p <- load_params(yml, variant = "M", setting = "child")
  expect_equal(p$k_inequality, 2)
  expect_equal(p$raw$capital_flow$payout, 0.4)
  expect_null(p$raw$inherits)
  yaml::write_yaml(list(inherits = "loop_b"), file.path(dir, "settings", "loop_a.yaml"))
  yaml::write_yaml(list(inherits = "loop_a"), file.path(dir, "settings", "loop_b.yaml"))
  expect_error(load_params(yml, setting = "loop_a"), "loop")
})

test_that("rung-3 shares outside [0, 1] abort", {
  yml <- .setting_fixture(list(capital_flow = list(ai_gains_realized = 1.5)))
  expect_error(load_params(yml, setting = "trial"), "ai_gains_realized")
  yml <- .setting_fixture(list(corporate = list(share_abroad = 0.7, share_interest = 0.5)))
  expect_error(load_params(yml, setting = "trial"), "exceeds 1")
})

test_that("the committed sensitivity settings load", {
  for (s in sub("\\.yaml$", "", list.files(here::here("config", "settings"), "^v1_2_sens_"))) {
    p <- load_params(.params_yaml, variant = "M", setting = s)
    expect_identical(p$raw$capital_flow$allocator, "concentrating", info = s)
    expect_identical(p$raw$shock$sector, "nonfarm_business", info = s)
  }
})
