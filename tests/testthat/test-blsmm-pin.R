# BLSMM pin check in code/15_blsmm_debt_gdp.R. Builds a throwaway git repo
# shaped like a BLSMM clone, so the test needs git but not BLSMM itself.

withr::with_dir(here::here(), source("code/15_blsmm_debt_gdp.R"))

skip_if(Sys.which("git") == "", "git not available")

make_fake_blsmm <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  git <- function(...) {
    out <- system2("git", c("-C", shQuote(dir), ...), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(out, "status")))
    out
  }
  git("init", "-q")
  git("config", "user.email", "test@example.com")
  git("config", "user.name", "test")
  dir.create(file.path(dir, "model", "v1_8"), recursive = TRUE)
  writeLines("# v1", file.path(dir, "model", "v1_8", "simulation.R"))
  git("add", "-A")
  git("commit", "-q", "-m", "v1")
  git("tag", "v-pinned")
  list(dir = dir, git = git)
}

write_yaml_ref <- function(ref) {
  fp <- withr::local_tempfile(fileext = ".yaml", .local_envir = parent.frame())
  writeLines(sprintf("blsmm_ref: %s", ref), fp)
  fp
}

test_that("pin check passes at the pinned ref and returns the commit", {
  withr::local_envvar(BLSMM_REF = NA)
  b <- make_fake_blsmm()
  pin <- .check_blsmm_pin(b$dir, write_yaml_ref("v-pinned"))
  expect_equal(pin$ref, "v-pinned")
  expect_equal(pin$commit, b$git("rev-parse", "HEAD"))
})

test_that("pin check stops when the clone is on another commit", {
  withr::local_envvar(BLSMM_REF = NA)
  b <- make_fake_blsmm()
  writeLines("# v2", file.path(b$dir, "model", "v1_8", "simulation.R"))
  b$git("commit", "-q", "-am", "v2")
  expect_error(.check_blsmm_pin(b$dir, write_yaml_ref("v-pinned")), "pinned ref")
})

test_that("pin check stops on uncommitted edits under model/", {
  withr::local_envvar(BLSMM_REF = NA)
  b <- make_fake_blsmm()
  writeLines("# edited", file.path(b$dir, "model", "v1_8", "simulation.R"))
  expect_error(.check_blsmm_pin(b$dir, write_yaml_ref("v-pinned")), "uncommitted")
})

test_that("pin check stops when the ref does not exist", {
  withr::local_envvar(BLSMM_REF = NA)
  b <- make_fake_blsmm()
  expect_error(.check_blsmm_pin(b$dir, write_yaml_ref("v-missing")), "failed")
})

test_that("BLSMM_REF overrides the configured ref and is recorded as the source", {
  b <- make_fake_blsmm()
  writeLines("# v2", file.path(b$dir, "model", "v1_8", "simulation.R"))
  b$git("commit", "-q", "-am", "v2")
  withr::local_envvar(BLSMM_REF = "HEAD")
  pin <- .check_blsmm_pin(b$dir, write_yaml_ref("v-pinned"))
  expect_equal(pin$ref_source, "BLSMM_REF env var")
  expect_equal(pin$commit, b$git("rev-parse", "HEAD"))
})

test_that("the shipped config pins a BLSMM ref", {
  ref <- yaml::read_yaml(here::here("config", "scenario_params.yaml"))$blsmm_ref
  expect_true(is.character(ref) && nzchar(ref))
})
