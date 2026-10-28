# Rung 0 reproduction, layer 2 (docs/v1_2_plan.md): build the full release
# grid under the legacy_v1_0_1 setting on the real Tax-Data vintage, through
# the run store, and check every input the pipeline hands Tax-Simulator
# against v1.0.1:
#   1. md5 of the 54 counterfactual tax-unit files and 54 factor_channels
#      sidecars, against tests/reference/v1_0_1_counterfactual_md5.csv;
#   2. the per-cell macro parameters (g_k, X, delta_R_CIT, ...), against
#      the erratum result set's run D;
#   3. the parameter_index built from the run's merged parameters, against
#      run D's.
# Tax-Simulator is not run. The check deletes its scratch files and Tax-Data
# links on exit. Needs the real vintage; run on the cluster with
#   sbatch --output=<log dir>/%x-%j.out tests/server/legacy_inputs.sbatch
# Prints LAYER2 PASS or exits with status 1.

suppressMessages(source("code/00_ai_fiscal_sim.R"))

REF_MD5         <- "tests/reference/v1_0_1_counterfactual_md5.csv"
REF_RUN_D       <- "results/erratum_v1.0.1/runs/D_v1.0.1/parameters"
CHECK_RUNS_DIR  <- "output/checks"
REL_TOL         <- 1e-12

# Returns the list of failures; the cleanup runs when it returns.
check_legacy_inputs <- function() {
  run           <- new_run(.LEGACY_SETTING, new_vintage(), runs_dir = CHECK_RUNS_DIR)
  vintage_paths <- tax_data_vintage()
  # A check run keeps nothing in scratch, pass or fail. (on.exit only fires
  # inside a function, hence check_legacy_inputs().)
  on.exit(cleanup_run(run, vintage_paths, succeeded = TRUE), add = TRUE)
  cat("Check run:", run$id, "\n")

  rs_path <- build_ai_fiscal_runs(release_specs(), run, vintage_paths = vintage_paths)
  rs      <- fread(rs_path)
  failures <- character()

  # 1. Counterfactual files.
  ref_md5 <- fread(REF_MD5)
  if (!setequal(rs$ID[rs$ID != "baseline"], unique(ref_md5$scenario_id))) {
    failures <- c(failures, "scenario set differs from the v1.0.1 reference")
  }
  got_md5 <- ref_md5[, .(scenario_id, file)]
  got_md5[, md5 := unname(tools::md5sum(file.path(run$tax_data, scenario_id, file)))]
  md5_cmp <- merge(ref_md5[, .(scenario_id, file, ref = md5)], got_md5,
                   by = c("scenario_id", "file"))
  md5_bad <- md5_cmp[is.na(md5) | md5 != ref]
  cat(sprintf("Files: %d of %d match v1.0.1\n", nrow(md5_cmp) - nrow(md5_bad), nrow(md5_cmp)))
  if (nrow(md5_bad)) {
    print(md5_bad)
    failures <- c(failures, sprintf("%d counterfactual files differ", nrow(md5_bad)))
  }

  # 2. Per-cell macro parameters.
  key      <- c("variant", "share_mode", "labor_scenario")
  cell     <- fread(sub("\\.csv$", "_cell_params.csv", rs_path), key = key)
  cell_ref <- fread(file.path(REF_RUN_D, "cell_params.csv"), key = key)
  cell_cmp <- all.equal(as.data.frame(cell), as.data.frame(cell_ref),
                        tolerance = REL_TOL, check.attributes = FALSE)
  cat("Cell parameters:", if (isTRUE(cell_cmp)) "match run D" else "DIFFER", "\n")
  if (!isTRUE(cell_cmp)) {
    print(cell_cmp)
    failures <- c(failures, "cell parameters differ from run D")
  }

  # 3. parameter_index, compared as text (both sides written by fwrite).
  idx_fp <- file.path(run$inputs, "parameter_index.csv")
  fwrite(.build_parameter_index(run$params_yaml), idx_fp)
  idx     <- fread(idx_fp, colClasses = "character")
  idx_ref <- fread(file.path(REF_RUN_D, "parameter_index.csv"), colClasses = "character")
  idx_cmp <- all.equal(idx, idx_ref, check.attributes = FALSE)
  cat("parameter_index:", if (isTRUE(idx_cmp)) "matches run D" else "DIFFERS", "\n")
  if (!isTRUE(idx_cmp)) {
    print(idx_cmp)
    failures <- c(failures, "parameter_index differs from run D")
  }
  failures
}

# quit() would skip on.exit handlers, so it stays outside the function.
failures <- check_legacy_inputs()
if (length(failures)) {
  cat("LAYER2 FAIL:", paste(failures, collapse = "; "), "\n")
  quit(status = 1)
}
cat("LAYER2 PASS\n")
