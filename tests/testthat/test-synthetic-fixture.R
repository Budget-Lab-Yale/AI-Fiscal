# Schema-level checks on the committed synthetic tax-units fixture.
# Confirms that load_tax_units() can consume the fixture and that
# apply_passthrough_split() produces a plausible y_l / y_k split, so
# environments without PUF access can still smoke-test the pipeline.
# No economic assertions — the fixture has no economic significance.

fixture_dir <- here::here("tests", "fixtures", "synthetic_tax_data")

test_that("synthetic fixture loads and matches PUF schema", {
  skip_if_not(dir.exists(fixture_dir), "synthetic fixture not present")
  fp <- file.path(fixture_dir, "baseline", "tax_units_2030.csv")
  skip_if_not(file.exists(fp), "synthetic CSV not generated")
  dt <- load_tax_units(2030L, data_dir = fixture_dir)
  expect_equal(nrow(dt), 10000L)
  expect_true("id" %in% names(dt))
  expect_equal(uniqueN(dt$id), nrow(dt))
  expect_true(all(dt$weight > 0))
  # SYZ split runs and produces non-trivial y_l + y_k
  dt2 <- apply_passthrough_split(dt, params)
  expect_true(all(c("y_l", "y_k") %in% names(dt2)))
  expect_gt(sum(dt2$weight * dt2$y_l), 0)
  expect_gt(sum(dt2$weight * dt2$y_k), 0)
})
