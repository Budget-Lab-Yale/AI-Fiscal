# Scenario-ID layer: the axis registry (00_utils.R), 09's
# .parse_scenario_axes, and 08's .scenario_flavor / .scenario_base.
# This is the layer CLAUDE.md flags as "must change with any new axis";
# before these tests it shipped with zero coverage and every failure
# mode was a silent row drop.

test_that(".parse_scenario_axes parses canonical IDs with registry levels", {
  ax <- .parse_scenario_axes(c("ai_M_R_S0_V1", "ai_S_F_S3_V1"))
  expect_equal(as.character(ax$variant),     c("M", "S"))
  expect_equal(as.character(ax$share_mode),  c("R", "F"))
  expect_equal(as.character(ax$labor),       c("S0", "S3"))
  expect_equal(as.character(ax$realization), c("V1", "V1"))
  expect_equal(levels(ax$variant),     names(.AXIS_VARIANTS))
  expect_equal(levels(ax$share_mode),  names(.AXIS_SHARE_MODES))
  expect_equal(levels(ax$labor),       names(.AXIS_LABOR))
  expect_equal(levels(ax$realization), names(.AXIS_REALIZATION))
})

test_that("baseline and flavor-suffixed IDs parse to NA without warning", {
  expect_no_warning(
    ax <- .parse_scenario_axes(c("baseline", "ai_M_R_S0_V1_LO",
                                 "ai_M_R_S0_V1_CO"))
  )
  expect_true(all(is.na(ax$variant)))
})

test_that("unregistered IDs warn before being dropped from the grid", {
  expect_warning(
    ax <- .parse_scenario_axes(c("ai_M_R_E1_V1", "ai_M_R_S0_V1")),
    "registry"
  )
  expect_true(is.na(ax$variant[1]))
  expect_equal(as.character(ax$variant[2]), "M")
})

test_that(".scenario_flavor classifies registered suffixes", {
  expect_equal(
    .scenario_flavor(c("baseline", "ai_M_R_S0_V1",
                       "ai_M_R_S0_V1_LO", "ai_M_R_S0_V1_CO")),
    c("both", "both", "labor_only", "capital_only")
  )
})

test_that(".scenario_flavor aborts on an unregistered suffix or ID", {
  expect_error(.scenario_flavor("ai_M_R_S0_V1_KO"), "registry")
  expect_error(.scenario_flavor("ai_M_R_E1_V1"),    "registry")
})

test_that(".scenario_base strips registered suffixes only", {
  expect_equal(
    .scenario_base(c("ai_M_R_S0_V1_LO", "ai_M_R_S0_V1_CO", "ai_M_R_S0_V1")),
    rep("ai_M_R_S0_V1", 3)
  )
})

test_that("scenario_guide stays in lockstep with the axis registry", {
  guide <- .build_scenario_guide()
  expect_setequal(guide[axis == "variant"]$code,     names(.AXIS_VARIANTS))
  expect_setequal(guide[axis == "labor"]$name,       unname(.AXIS_LABOR))
  expect_setequal(guide[axis == "share_mode"]$name,  unname(.AXIS_SHARE_MODES))
})
