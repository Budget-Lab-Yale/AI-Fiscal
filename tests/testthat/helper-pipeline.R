# Sourced once by testthat before any test-*.R file. Loads the active-variant
# baseline + runs SYZ split, Step A (S0), Step B, and Step C, exposing the
# results as objects that the test files read. The pipeline is deterministic
# (no RNG), so caching at the suite level keeps test runtime to ~load + ~1s.

suppressPackageStartupMessages({
  library(data.table)
})

# Each code module sources 00_utils.R via the relative path "code/00_utils.R",
# which only resolves from the repo root. testthat changes the wd to the test
# directory, so we temporarily switch back while sourcing.
withr::with_dir(here::here(), {
  source("code/00_utils.R")
  source("code/01_load_data.R")
  source("code/02_params.R")
  source("code/03_shock_labor.R")
  source("code/04_allocate_capital.R")
  source("code/05_realization.R")
  source("code/06_build_counterfactual.R")
  source("code/08_aggregate.R")
})

params <- load_params(here::here("config", "scenario_params.yaml"))
year   <- params$raw$baseline_year

dt_baseline <- load_tax_units(year, data_dir = here::here("data", "tax_data"))
dt_baseline <- apply_passthrough_split(dt_baseline, params)

dt_step_a <- shock_labor(dt_baseline, params, scenario = "S0")
step_b    <- allocate_capital(
  dt_baseline, params,
  asset_map_path = here::here("config", "asset_to_income_map.csv")
)
step_b    <- apply_realization(step_b)

dt_cf <- build_counterfactual(
  dt_baseline, dt_step_a, step_b,
  params = params
)

macro <- attr(step_b, "macro")
rmeta <- attr(step_b, "realization")
