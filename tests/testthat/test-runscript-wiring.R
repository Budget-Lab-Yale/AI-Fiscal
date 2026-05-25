# Smoke-test the Tax-Simulator handoff helpers without touching the
# shared model_data tree. Builds a fake vintage in a tempdir with a
# baseline/ subfolder containing a few placeholder files, then verifies
# write_counterfactual_scenario() mirrors them as symlinks and overrides
# the chosen year, and that runscript_row() / write_runscript() emit a
# CSV with the dotted column names Tax-Simulator expects.

with_fake_vintage <- function(expr) {
  fake_root <- file.path(tempfile("v1_"), "v1")
  vintage   <- "20260000"
  dir.create(file.path(fake_root, vintage, "baseline"), recursive = TRUE)
  # Touch enough baseline files to exercise the symlink loop.
  baseline_files <- c(
    "tax_units_2017.csv", "tax_units_2030.csv", "tax_units_2031.csv",
    "factor_ledger.rds", "dependencies.csv"
  )
  for (f in baseline_files) {
    fp <- file.path(fake_root, vintage, "baseline", f)
    if (grepl("\\.csv$", f)) {
      data.table::fwrite(data.table::data.table(id = 1L, value = 0), fp)
    } else {
      file.create(fp)
    }
  }
  vintage_paths <- list(
    root    = fake_root,
    vintage = vintage,
    path    = file.path(fake_root, vintage)
  )
  on.exit(unlink(dirname(fake_root), recursive = TRUE))
  expr(vintage_paths)
}

test_that("write_counterfactual_scenario mirrors baseline files as symlinks", {
  with_fake_vintage(function(vp) {
    cf <- data.table::data.table(id = 1L, value = 99)
    scenario_dir <- write_counterfactual_scenario(
      cf, year = 2030, scenario_id = "ai_M_R_S0_V1", vintage_paths = vp
    )
    # Override is a real file
    override <- file.path(scenario_dir, "tax_units_2030.csv")
    expect_true(file.exists(override))
    expect_equal(Sys.readlink(override), "")
    expect_equal(data.table::fread(override)$value, 99)
    # Other baseline files are symlinks back to baseline
    other <- file.path(scenario_dir, "tax_units_2017.csv")
    expect_true(nzchar(Sys.readlink(other)))
  })
})

test_that("write_counterfactual_scenario refuses to overwrite without flag", {
  with_fake_vintage(function(vp) {
    cf <- data.table::data.table(id = 1L, value = 99)
    write_counterfactual_scenario(cf, 2030, "ai_M_R_S0_V1", vintage_paths = vp)
    expect_error(
      write_counterfactual_scenario(cf, 2030, "ai_M_R_S0_V1", vintage_paths = vp),
      "already exists"
    )
    expect_silent(
      write_counterfactual_scenario(
        cf, 2030, "ai_M_R_S0_V1", vintage_paths = vp, overwrite = TRUE
      )
    )
  })
})

test_that("ai_fiscal_scenario_id encodes the four axes", {
  expect_equal(ai_fiscal_scenario_id("M", "R", "S0", "V1"), "ai_M_R_S0_V1")
  expect_equal(ai_fiscal_scenario_id("S", "F", "S2", "V1"), "ai_S_F_S2_V1")
})

test_that("write_runscript emits dotted-column Tax-Data fields", {
  rows <- list(
    runscript_row("baseline", tax_data_id = "baseline", tax_data_vintage = "20260000"),
    runscript_row("ai_M_R_S0_V1", tax_data_id = "ai_M_R_S0_V1",
                  tax_data_vintage = "20260000")
  )
  fp <- tempfile(fileext = ".csv")
  on.exit(unlink(fp))
  write_runscript(rows, fp)

  rs <- data.table::fread(fp)
  expect_setequal(
    names(rs),
    c("ID", "tax_law", "behavior", "years", "dist_years",
      "mtr_vars", "mtr_types", "dep.Tax-Data.vintage", "dep.Tax-Data.ID")
  )
  expect_equal(rs$ID, c("baseline", "ai_M_R_S0_V1"))
  expect_equal(rs[["dep.Tax-Data.ID"]], c("baseline", "ai_M_R_S0_V1"))
})
