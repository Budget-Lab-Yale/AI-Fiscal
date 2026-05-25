# Step C: V1 (mechanical) is the only realization variant in the
# release pipeline.

test_that("V1 equals the gross LTCG flow by definition", {
  expect_equal(step_b$X_ltcg_V1, step_b$X_ltcg_gross)
})

test_that("realization metadata records V1", {
  expect_identical(rmeta$variant, "V1")
})
