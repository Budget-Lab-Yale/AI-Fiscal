# Invoke Tax-Simulator's src/main.R from the orchestrator without a
# manual second step. Runs in a clean R subprocess (callr) with cwd set
# to the Tax-Simulator working tree, so its tidyverse/usincometaxes
# loads and global assignments don't pollute this session.
#
# Public surface:
#   - tax_sim_root()              resolve the Tax-Simulator working tree
#   - tax_sim_output_root(v)      compute the output dir parse_globals() will write
#   - runscript_name_from_path()  convert an absolute runscript CSV path to main.R's
#                                 expected `<subdir>/<basename>` form
#   - run_tax_sim(...)            invoke main.R with our runscript and explicit vintage

suppressPackageStartupMessages({
  library(yaml)
})

# Resolve the Tax-Simulator working tree from the TAX_SIMULATOR_DIR env
# var. There is no default — public reproducers must point this at their
# own clone of https://github.com/Budget-Lab-Yale/Tax-Simulator.
tax_sim_root <- function() {
  cand <- Sys.getenv("TAX_SIMULATOR_DIR", unset = "")
  if (!nzchar(cand)) {
    cli::cli_abort(c(
      "{.envvar TAX_SIMULATOR_DIR} is not set.",
      i = "Clone {.url https://github.com/Budget-Lab-Yale/Tax-Simulator} and set {.envvar TAX_SIMULATOR_DIR} to its working tree."
    ))
  }
  ok <- dir.exists(cand) &&
    file.exists(file.path(cand, "src", "main.R")) &&
    dir.exists(file.path(cand, "config", "runscripts")) &&
    file.exists(file.path(cand, "config", "interfaces", "output_roots.yaml")) &&
    file.exists(file.path(cand, "config", "interfaces", "interface_versions.yaml"))
  if (!ok) {
    cli::cli_abort(c(
      "{.envvar TAX_SIMULATOR_DIR} does not point at a valid Tax-Simulator tree.",
      x = "Looked at {.path {cand}}.",
      i = "A valid tree must contain {.path src/main.R}, {.path config/runscripts/}, and {.path config/interfaces/*.yaml}."
    ))
  }
  normalizePath(cand, mustWork = TRUE)
}

# Compute the output_root that parse_globals() will write into, given a
# vintage string. Reads output_roots.yaml + interface_versions.yaml from
# the Tax-Simulator tree to mirror the same path construction.
tax_sim_output_root <- function(vintage,
                                local   = TRUE,
                                ts_root = tax_sim_root()) {
  roots <- yaml::read_yaml(
    file.path(ts_root, "config", "interfaces", "output_roots.yaml")
  )
  vers  <- yaml::read_yaml(
    file.path(ts_root, "config", "interfaces", "interface_versions.yaml")
  )
  base <- if (isTRUE(local)) roots$local else roots$production
  if (is.null(base) || !nzchar(base)) {
    cli::cli_abort(c(
      "output_roots.yaml is missing the {.field {if (local) 'local' else 'production'}} key.",
      i = "Inspect {.path {file.path(ts_root, 'config/interfaces/output_roots.yaml')}}."
    ))
  }
  ver <- vers[["Tax-Simulator"]]$version
  file.path(base, "model_data", "Tax-Simulator", paste0("v", ver), vintage)
}

# Convert an absolute runscript CSV path (e.g.
# `<ts_root>/config/runscripts/private/ai_fiscal.csv`) to the form
# main.R expects as its first argv: `private/ai_fiscal` (relative to
# `config/runscripts/`, no `.csv`).
runscript_name_from_path <- function(runscript_path,
                                     ts_root = tax_sim_root()) {
  rs_dir <- normalizePath(file.path(ts_root, "config", "runscripts"),
                          mustWork = TRUE)
  abs    <- normalizePath(runscript_path, mustWork = TRUE)
  prefix <- paste0(rs_dir, .Platform$file.sep)
  if (!startsWith(abs, prefix)) {
    cli::cli_abort(c(
      "Runscript is not under the Tax-Simulator config tree.",
      x = "Runscript: {.path {abs}}.",
      x = "Expected prefix: {.path {prefix}}.",
      i = "Emit the runscript under {.path config/runscripts/} of {.path {ts_root}}."
    ))
  }
  sub("\\.csv$", "", substr(abs, nchar(prefix) + 1L, nchar(abs)))
}

# Mint a fresh vintage stamp matching parse_globals()'s default format.
new_vintage <- function() format(Sys.time(), "%Y%m%d%H%M")

# Invoke Tax-Simulator's src/main.R in a clean R subprocess, with cwd
# set to the Tax-Simulator working tree. Streams stdout/stderr to the
# parent terminal; aborts on non-zero exit. Returns the resolved
# output_root path so callers can chain 08_aggregate.R against it.
#
# Args mirror main.R's argv:
#   runscript_name   relative path under config/runscripts/, no `.csv`
#                    (e.g. "private/ai_fiscal")
#   vintage          YYYYMMDDHHMM string. Auto-minted if NULL — but we
#                    always pass it through explicitly so we know where
#                    output landed.
#   pct_sample       sample share in (0, 1]
#   local            TRUE → output_roots$local; FALSE → production
#   stacked          TRUE → run stacked post-processing
#   delete_detail    TRUE → purge per-unit microdata after stacked step
#   multicore        'none' | 'scenario' | 'year'
#   scenario_id      NULL → run all non-baseline rows in the runscript
#   baseline_vintage NULL → run baseline; otherwise reuse an existing one
run_tax_sim <- function(runscript_name,
                        vintage          = new_vintage(),
                        pct_sample       = 1,
                        local            = TRUE,
                        stacked          = TRUE,
                        delete_detail    = FALSE,
                        multicore        = "none",
                        scenario_id      = NULL,
                        baseline_vintage = NULL,
                        user_id          = Sys.info()[["user"]],
                        ts_root          = tax_sim_root(),
                        log_con          = NULL) {

  if (!requireNamespace("callr", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg callr} required to invoke Tax-Simulator in-process.",
      i = "Install with {.code install.packages('callr')} into {.envvar R_LIBS_USER}."
    ))
  }
  stopifnot(
    is.character(runscript_name), length(runscript_name) == 1L,
    is.character(vintage), length(vintage) == 1L, nzchar(vintage),
    is.numeric(pct_sample), pct_sample > 0, pct_sample <= 1,
    multicore %in% c("none", "scenario", "year")
  )

  cmdargs <- c(
    runscript_name,
    if (is.null(scenario_id))      "NULL" else as.character(scenario_id),
    user_id,
    as.character(as.integer(isTRUE(local))),
    vintage,
    format(pct_sample, scientific = FALSE),
    as.character(as.integer(isTRUE(stacked))),
    if (is.null(baseline_vintage)) "NULL" else as.character(baseline_vintage),
    as.character(as.integer(isTRUE(delete_detail))),
    multicore
  )

  cli::cli_inform(c(
    "Running Tax-Simulator",
    "*" = "runscript: {.val {runscript_name}}",
    "*" = "vintage:   {.val {vintage}}",
    "*" = "cwd:       {.path {ts_root}}",
    "*" = "argv:      {.code {paste(cmdargs, collapse = ' ')}}"
  ))

  # When log_con is set, capture subprocess output via a pipe and
  # dual-write each chunk to terminal + log file (via the supplied
  # connection — owned by the caller, not closed here). Otherwise
  # inherit the parent terminal directly (current behaviour).
  tee <- !is.null(log_con)
  # callr's default env is rcmd_safe_env() — a curated R-related
  # subset, which strips arbitrary parent vars like MC_CORES. Forward
  # MC_CORES explicitly when set so the local-fork mclapply override
  # in src/main.R / src/sim/run.R can read it.
  child_env <- callr::rcmd_safe_env()
  mc <- Sys.getenv("MC_CORES", unset = "")
  if (nzchar(mc)) child_env <- c(child_env, MC_CORES = mc)
  proc <- callr::rscript_process$new(
    options = callr::rscript_process_options(
      script  = file.path(ts_root, "src", "main.R"),
      cmdargs = cmdargs,
      wd      = ts_root,
      stdout  = if (tee) "|" else "",
      stderr  = "2>&1",
      env     = child_env
    )
  )

  if (tee) {
    cat(sprintf("\n# tax-sim subprocess @ %s\n# argv: %s\n\n",
                format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
                paste(cmdargs, collapse = " ")),
        file = log_con)
    while (proc$is_alive()) {
      proc$poll_io(200)
      chunk <- proc$read_output()
      if (length(chunk) && nzchar(chunk)) {
        cat(chunk)
        cat(chunk, file = log_con); flush(log_con)
      }
    }
    remaining <- proc$read_all_output()
    if (length(remaining) && nzchar(remaining)) {
      cat(remaining)
      cat(remaining, file = log_con); flush(log_con)
    }
  } else {
    proc$wait()
  }
  status <- proc$get_exit_status()
  if (!identical(as.integer(status), 0L)) {
    cli::cli_abort(c(
      "Tax-Simulator exited with status {.val {status}}.",
      i = "Inspect the streamed log above for the underlying error."
    ))
  }

  out <- tax_sim_output_root(vintage, local = local, ts_root = ts_root)
  if (!dir.exists(out)) {
    cli::cli_abort(c(
      "Tax-Simulator finished but the expected output dir is missing.",
      x = "Expected {.path {out}}.",
      i = "Re-check {.path config/interfaces/output_roots.yaml} and the run log."
    ))
  }
  cli::cli_inform("Tax-Simulator output: {.path {out}}")
  out
}
