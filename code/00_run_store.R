# Run store (docs/v1_2_plan.md, workstream E).
#
# Each orchestrator run gets a run directory and a scratch directory:
#
#   results/runs/<run_id>/                 permanent record (gitignored)
#     manifest.yaml                        setting, versions, vintages, status
#     inputs/                              merged params, config copies,
#                                          runscript + _macro / _cell_params
#     tables/                              aggregate CSVs and workbooks
#     figures/                             figure suite
#     run.log
#   $TAXSIM_LOCAL_ROOT/ai_fiscal/<run_id>/tax_data/<scenario_id>/
#                                          counterfactual tax units and the
#                                          factor_channels sidecar
#                                          (reproducible, deleted after a
#                                          successful run)
#
# Tax-Simulator reads inputs only from <production>/model_data/Tax-Data/
# v1/<vintage>/<ID>, so the shared vintage receives one run-specific
# symlink per scenario, `aif-<run_id>--<scenario_id>`, pointing into
# scratch. The symlink name is the runscript's dep.Tax-Data.ID; the
# Tax-Simulator scenario ID stays `<scenario_id>`. Links are removed when
# the run ends, whether it succeeds or fails.
#
# run_id = <setting>-<stamp>, where <stamp> is also the Tax-Simulator
# output vintage, so the two always line up.

.RUNS_DIR          <- "results/runs"
.RUN_SUBDIRS       <- c("inputs", "tables", "figures")
.SCRATCH_SUBDIR    <- "ai_fiscal"
.TAX_DATA_LINK_PFX <- "aif-"
.RUN_CONFIG_COPIES <- c("config/retirement_calibration.yaml",
                        "config/asset_to_income_map.csv")

scratch_root <- function() {
  root <- Sys.getenv("TAXSIM_LOCAL_ROOT", unset = "")
  if (!nzchar(root)) {
    cli::cli_abort(c(
      "{.envvar TAXSIM_LOCAL_ROOT} is not set.",
      i = "Set it in {.path ~/.Renviron} to your scratch directory; runs keep their counterfactual files there."
    ))
  }
  root
}

# Create the run and scratch directories and return the run's paths.
new_run <- function(setting, stamp,
                    runs_dir = .RUNS_DIR, scratch = scratch_root()) {
  id  <- paste0(setting, "-", stamp)
  dir <- file.path(runs_dir, id)
  if (dir.exists(dir)) {
    cli::cli_abort(c(
      "Run directory already exists: {.path {dir}}.",
      i = "Each run needs a fresh stamp; omit {.arg --vintage} to use the current time."
    ))
  }
  for (sub in .RUN_SUBDIRS) {
    dir.create(file.path(dir, sub), recursive = TRUE, showWarnings = FALSE)
  }
  scratch_dir <- file.path(scratch, .SCRATCH_SUBDIR, id)
  dir.create(file.path(scratch_dir, "tax_data"), recursive = TRUE,
             showWarnings = FALSE)
  list(
    id          = id,
    stamp       = stamp,
    setting     = setting,
    dir         = dir,
    inputs      = file.path(dir, "inputs"),
    tables      = file.path(dir, "tables"),
    figures     = file.path(dir, "figures"),
    log         = file.path(dir, "run.log"),
    manifest    = file.path(dir, "manifest.yaml"),
    runscript   = file.path(dir, "inputs", "runscript.csv"),
    params_yaml = file.path(dir, "inputs", "params.yaml"),
    scratch     = scratch_dir,
    tax_data    = file.path(scratch_dir, "tax_data")
  )
}

# Sys.readlink() gives "" for a regular file and NA for a missing path.
.symlink_target <- function(path) {
  target <- Sys.readlink(path)
  if (is.na(target) || !nzchar(target)) NA_character_ else target
}

tax_data_link_id <- function(run, scenario_id) {
  paste0(.TAX_DATA_LINK_PFX, run$id, "--", scenario_id)
}

# Point the shared vintage at a scenario folder in scratch. Returns the
# link name, which is the runscript's dep.Tax-Data.ID for that scenario.
link_scenario_into_vintage <- function(run, scenario_id, scenario_dir,
                                       vintage_paths) {
  link_id <- tax_data_link_id(run, scenario_id)
  link    <- file.path(vintage_paths$path, link_id)
  if (file.exists(link) || !is.na(.symlink_target(link))) {
    cli::cli_abort("Tax-Data link already exists: {.path {link}}.")
  }
  if (!isTRUE(file.symlink(normalizePath(scenario_dir, mustWork = TRUE), link))) {
    cli::cli_abort(c(
      "Failed to link {.path {scenario_dir}} into the Tax-Data vintage.",
      x = "{.path {link}}."
    ))
  }
  link_id
}

# Snapshot what the run reads: merged parameters (the setting applied) and
# copies of the other config files the pipeline consumes.
write_run_inputs <- function(run, params_raw) {
  yaml::write_yaml(params_raw, run$params_yaml)
  for (fp in .RUN_CONFIG_COPIES) file.copy(fp, run$inputs)
  invisible(run)
}

# Diff of the Tax-Simulator source tree against its commit, i.e. the local
# patches the run used. Restricted to src/ so no machine paths from
# config/interfaces/output_roots.yaml end up in the run record.
.tax_sim_src_diff <- function(ts_root) {
  out <- tryCatch(
    suppressWarnings(system2("git", c("-C", shQuote(ts_root), "diff", "--", "src"),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  out
}

# Write or update manifest.yaml; `fields` are merged over existing entries.
write_manifest <- function(run, fields) {
  current <- if (file.exists(run$manifest)) yaml::read_yaml(run$manifest) else list()
  current[names(fields)] <- fields
  yaml::write_yaml(current, run$manifest)
  invisible(current)
}

start_manifest <- function(run, argv, vintage_paths, ts_root) {
  ts_diff <- .tax_sim_src_diff(ts_root)
  if (length(ts_diff)) {
    writeLines(ts_diff, file.path(run$inputs, "tax_simulator_src.diff"))
  }
  write_manifest(run, list(
    run_id           = run$id,
    setting          = run$setting,
    status           = "running",
    started          = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    ai_fiscal_rev    = .git_short_rev(getwd()),
    ai_fiscal_dirty  = length(suppressWarnings(system2(
      "git", c("status", "--porcelain", "--untracked-files=no"),
      stdout = TRUE, stderr = FALSE))) > 0L,
    tax_simulator_rev   = .git_short_rev(ts_root),
    tax_simulator_patched = length(ts_diff) > 0L,
    tax_data_vintage = vintage_paths$vintage,
    tax_simulator_vintage = run$stamp,
    r_version        = R.version.string,
    argv             = if (length(argv)) paste(argv, collapse = " ") else ""
  ))
}

# Remove this run's Tax-Data links and the run-specific runscript copy in
# the Tax-Simulator tree. On success (and unless `keep`), also delete the
# scratch counterfactual files and the Tax-Simulator output tree.
cleanup_run <- function(run, vintage_paths, succeeded,
                        keep = FALSE, ts_runscript = NULL,
                        tax_sim_output = NULL) {
  prefix <- tax_data_link_id(run, "")
  names  <- list.files(vintage_paths$path)
  links  <- file.path(vintage_paths$path, names[startsWith(names, prefix)])
  for (link in links) {
    # Only ever remove symlinks that point into this run's scratch folder.
    target <- .symlink_target(link)
    if (!is.na(target) && startsWith(target, normalizePath(run$scratch))) {
      file.remove(link)
    } else {
      cli::cli_warn("Left {.path {link}} in place: not a link into this run's scratch.")
    }
  }
  if (!is.null(ts_runscript) && file.exists(ts_runscript)) file.remove(ts_runscript)

  if (succeeded && !keep) {
    unlink(run$scratch, recursive = TRUE)
    if (!is.null(tax_sim_output)) unlink(tax_sim_output, recursive = TRUE)
  }
  invisible(length(links))
}
