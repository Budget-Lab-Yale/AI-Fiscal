# Test-suite entry point. Run from the repo root:
#   module load R/4.4.2-gfbf-2024a
#   Rscript tests/testthat.R
#
# Anchors paths via here::here() so each test can reach config/, data/, and
# code/ regardless of the working directory testthat installs while running
# individual test files.

suppressPackageStartupMessages({
  library(testthat)
})

testthat::test_dir(here::here("tests", "testthat"))
