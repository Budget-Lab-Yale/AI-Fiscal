# Run store (code/00_run_store.R): run and scratch directories, Tax-Data
# links, manifest, and cleanup. Everything happens under a tempdir; the
# shared model_data tree is never touched.

# A sandbox with a "shared" vintage (baseline/ holding one file) and a
# scratch root, mirroring the real layout.
.run_store_sandbox <- function() {
  root <- tempfile("run_store_")
  vintage_path <- file.path(root, "Tax-Data", "v1", "20260000")
  dir.create(file.path(vintage_path, "baseline"), recursive = TRUE)
  writeLines("shared", file.path(vintage_path, "baseline", "tax_units_2017.csv"))
  dir.create(file.path(root, "scratch"))
  list(root    = root,
       runs    = file.path(root, "runs"),
       scratch = file.path(root, "scratch"),
       vintage = list(root = dirname(vintage_path), vintage = "20260000",
                      path = vintage_path))
}

# A scenario folder in the run's scratch area, shaped like the ones
# write_counterfactual_scenario() makes: one written file plus a symlink
# back to the shared baseline.
.fake_scenario <- function(run, sb, sid) {
  dir <- file.path(run$tax_data, sid)
  dir.create(dir)
  writeLines("cf", file.path(dir, "tax_units_2030.csv"))
  file.symlink(file.path(sb$vintage$path, "baseline", "tax_units_2017.csv"),
               file.path(dir, "tax_units_2017.csv"))
  dir
}

test_that("new_run creates the run and scratch layout and refuses to reuse an id", {
  sb  <- .run_store_sandbox(); on.exit(unlink(sb$root, recursive = TRUE))
  run <- new_run("legacy_v1_0_1", "202610281200",
                 runs_dir = sb$runs, scratch = sb$scratch)
  expect_identical(run$id, "legacy_v1_0_1-202610281200")
  for (d in c(run$inputs, run$tables, run$figures, run$tax_data)) {
    expect_true(dir.exists(d), info = d)
  }
  expect_error(new_run("legacy_v1_0_1", "202610281200",
                       runs_dir = sb$runs, scratch = sb$scratch),
               "already exists")
})

test_that("cleanup after success removes links and scratch, never shared files", {
  sb  <- .run_store_sandbox(); on.exit(unlink(sb$root, recursive = TRUE))
  run <- new_run("s", "1", runs_dir = sb$runs, scratch = sb$scratch)
  for (sid in c("ai_M_R_S0_V1", "ai_M_R_S0_V1_CO")) {
    link_id <- link_scenario_into_vintage(run, sid, .fake_scenario(run, sb, sid),
                                          sb$vintage)
    expect_identical(link_id, paste0("aif-s-1--", sid))
    expect_identical(readLines(file.path(sb$vintage$path, link_id,
                                         "tax_units_2030.csv")), "cf")
  }
  # A link from another run whose id extends this one must survive.
  other <- new_run("s", "12", runs_dir = sb$runs, scratch = sb$scratch)
  link_scenario_into_vintage(other, "ai_M_R_S0_V1",
                             .fake_scenario(other, sb, "ai_M_R_S0_V1"),
                             sb$vintage)

  expect_equal(cleanup_run(run, sb$vintage, succeeded = TRUE), 2L)
  left <- list.files(sb$vintage$path)
  expect_setequal(left, c("baseline", "aif-s-12--ai_M_R_S0_V1"))
  expect_false(dir.exists(run$scratch))
  expect_true(dir.exists(other$scratch))
  expect_identical(readLines(file.path(sb$vintage$path, "baseline",
                                       "tax_units_2017.csv")), "shared")
})

test_that("cleanup after failure removes links but keeps scratch", {
  sb  <- .run_store_sandbox(); on.exit(unlink(sb$root, recursive = TRUE))
  run <- new_run("s", "1", runs_dir = sb$runs, scratch = sb$scratch)
  link_scenario_into_vintage(run, "ai_M_R_S0_V1",
                             .fake_scenario(run, sb, "ai_M_R_S0_V1"), sb$vintage)
  cleanup_run(run, sb$vintage, succeeded = FALSE)
  expect_setequal(list.files(sb$vintage$path), "baseline")
  expect_true(file.exists(file.path(run$tax_data, "ai_M_R_S0_V1",
                                    "tax_units_2030.csv")))
})

test_that("keep = TRUE keeps scratch after success", {
  sb  <- .run_store_sandbox(); on.exit(unlink(sb$root, recursive = TRUE))
  run <- new_run("s", "1", runs_dir = sb$runs, scratch = sb$scratch)
  cleanup_run(run, sb$vintage, succeeded = TRUE, keep = TRUE)
  expect_true(dir.exists(run$scratch))
})

test_that("write_manifest merges fields over earlier ones", {
  sb  <- .run_store_sandbox(); on.exit(unlink(sb$root, recursive = TRUE))
  run <- new_run("s", "1", runs_dir = sb$runs, scratch = sb$scratch)
  write_manifest(run, list(status = "running", setting = "s"))
  write_manifest(run, list(status = "succeeded"))
  expect_identical(yaml::read_yaml(run$manifest),
                   list(status = "succeeded", setting = "s"))
})

test_that("tax_sim_output_root falls back to TAXSIM_LOCAL_ROOT without a local key", {
  ts <- tempfile("ts_"); on.exit(unlink(ts, recursive = TRUE))
  dir.create(file.path(ts, "config", "interfaces"), recursive = TRUE)
  yaml::write_yaml(list(production = "/prod"),
                   file.path(ts, "config", "interfaces", "output_roots.yaml"))
  yaml::write_yaml(list(`Tax-Simulator` = list(version = 1)),
                   file.path(ts, "config", "interfaces", "interface_versions.yaml"))
  withr::with_envvar(c(TAXSIM_LOCAL_ROOT = "/scratch/me"), {
    expect_identical(tax_sim_output_root("V", local = TRUE, ts_root = ts),
                     "/scratch/me/model_data/Tax-Simulator/v1/V")
  })
  withr::with_envvar(c(TAXSIM_LOCAL_ROOT = ""), {
    expect_error(tax_sim_output_root("V", local = TRUE, ts_root = ts), "output root")
  })
})

# Wiring: build one release cell from the synthetic fixture into a
# throwaway vintage and check where everything landed.
test_that("build_ai_fiscal_runs writes to scratch, links into the vintage, and records inputs", {
  skip_on_os("windows")  # file.symlink needs developer mode there
  sb <- .run_store_sandbox(); on.exit(unlink(sb$root, recursive = TRUE))
  fixture <- here::here("tests", "fixtures", "synthetic_tax_data", "baseline",
                        "tax_units_2030.csv")
  for (yr in c(2029, 2030)) {
    file.symlink(fixture, file.path(sb$vintage$path, "baseline",
                                    sprintf("tax_units_%d.csv", yr)))
  }
  withr::with_dir(here::here(), suppressMessages({
    source("code/00_ai_fiscal_sim.R")
    run <- new_run("legacy_v1_0_1", "1", runs_dir = sb$runs, scratch = sb$scratch)
    spec <- list(variant = "M", share_mode = "R", labor_scenario = "S0",
                 realization = "V1")
    rs_path <- suppressWarnings(build_ai_fiscal_runs(
      list(spec), run, data_dir = sb$vintage$path, vintage_paths = sb$vintage))
  }))

  rs <- data.table::fread(rs_path)
  expect_identical(rs_path, run$runscript)
  expect_identical(rs$ID, c("baseline", "ai_M_R_S0_V1", "ai_M_R_S0_V1_LO",
                            "ai_M_R_S0_V1_CO"))
  expect_identical(rs[["dep.Tax-Data.ID"]],
                   c("baseline", paste0("aif-legacy_v1_0_1-1--", rs$ID[-1])))
  for (link_id in rs[["dep.Tax-Data.ID"]][-1]) {
    link <- file.path(sb$vintage$path, link_id)
    expect_true(startsWith(Sys.readlink(link), normalizePath(run$scratch)))
    expect_true(file.exists(file.path(link, "tax_units_2030.csv")))
    expect_true(file.exists(file.path(link, "factor_channels_2030.csv")))
  }
  for (f in c("params.yaml", "runscript_macro.csv", "runscript_cell_params.csv",
              "retirement_calibration.yaml", "asset_to_income_map.csv",
              "cbo_2026_02_baseline_path.csv", "nipa_sector_gva_2025.csv")) {
    expect_true(file.exists(file.path(run$inputs, f)), info = f)
  }
  expect_identical(yaml::read_yaml(run$params_yaml),
                   load_params(here::here("config", "scenario_params.yaml"))$raw)

  cleanup_run(run, sb$vintage, succeeded = TRUE)
  expect_setequal(list.files(sb$vintage$path), "baseline")
  expect_false(dir.exists(run$scratch))
})
