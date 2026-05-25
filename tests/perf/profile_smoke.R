# Per-section timing of the smoke pipeline (load -> SYZ split -> step B+C ->
# Step A -> build_counterfactual). Intended use: run before/after a
# perf-sensitive change to spot regressions and verify wins. Writes a
# machine-readable CSV at tests/perf/last_run.csv (gitignored).
#
# Usage from repo root:
#   module load R/4.4.2-gfbf-2024a
#   Rscript tests/perf/profile_smoke.R [--profvis] [--data-dir DIR]
#                                      [--cells N] [--variant V]
#
# Flags:
#   --profvis     also write tests/perf/profvis.html (requires profvis pkg)
#   --data-dir    PUF dir (default: data/tax_data; pass
#                 tests/fixtures/synthetic_tax_data for a sandbox-safe run)
#   --cells       repeat build_counterfactual N times to amortize JIT noise
#                 and approximate full-grid wall time (default 1)
#   --variant     shock variant (L|M|H, default M)
#
# Sections timed:
#   load_tax_units, apply_passthrough_split, allocate_capital,
#   apply_realization, compute_baseline_cache, shock_labor (per call),
#   build_counterfactual (per call).

suppressPackageStartupMessages({
  library(data.table)
})

# --- arg parsing ---------------------------------------------------
argv <- commandArgs(trailingOnly = TRUE)
get_flag <- function(name, default = NULL) {
  i <- match(paste0("--", name), argv)
  if (is.na(i)) return(default)
  if (i + 1L > length(argv) || startsWith(argv[i + 1L], "--")) return(TRUE)
  argv[i + 1L]
}
profvis_on <- isTRUE(get_flag("profvis"))
data_dir   <- get_flag("data-dir", "data/tax_data")
n_cells    <- as.integer(get_flag("cells", "1"))
variant    <- get_flag("variant", "M")

setwd(here::here())

source("code/00_utils.R")
source("code/01_load_data.R")
source("code/02_params.R")
source("code/03_shock_labor.R")
source("code/04_allocate_capital.R")
source("code/05_realization.R")
source("code/06_build_counterfactual.R")

# --- timing harness ------------------------------------------------
timings <- list()
time_it <- function(label, expr) {
  gc(verbose = FALSE)
  t <- system.time(out <- force(expr))
  timings[[length(timings) + 1L]] <<- data.table(
    section = label,
    elapsed = unname(t["elapsed"]),
    user    = unname(t["user.self"]),
    sys     = unname(t["sys.self"])
  )
  cat(sprintf("  %-28s  %8.3fs\n", label, t["elapsed"]))
  out
}

# --- pipeline ------------------------------------------------------
cat("ai_fiscal smoke profile\n")
cat(sprintf("  data_dir = %s\n", data_dir))
cat(sprintf("  variant  = %s\n", variant))
cat(sprintf("  cells    = %d\n\n", n_cells))

params <- load_params("config/scenario_params.yaml", variant = variant)
year   <- params$raw$baseline_year

dt_raw <- time_it("load_tax_units",
                  load_tax_units(year, data_dir = data_dir))
dt_split <- time_it("apply_passthrough_split",
                    apply_passthrough_split(dt_raw, params))
step_b <- time_it("allocate_capital",
                  allocate_capital(dt_split, params,
                                    asset_map_path = "config/asset_to_income_map.csv"))
step_b <- time_it("apply_realization",
                  apply_realization(step_b, params))
bc <- time_it("compute_baseline_cache",
              compute_baseline_cache(dt_split))

# Per-cell sections — repeat n_cells times to estimate full-grid cost.
cell_times <- list()
for (k in seq_len(n_cells)) {
  dt_a <- time_it(sprintf("shock_labor[%d]", k),
                  shock_labor(dt_split, params, scenario = "S0"))
  dt_cf <- time_it(sprintf("build_counterfactual[%d]", k),
                   build_counterfactual(dt_split, dt_a, step_b,
                                        params = params,
                                        baseline_cache = bc))
  cell_times[[k]] <- list(shock = dt_a, cf = dt_cf)
}

# --- output --------------------------------------------------------
out <- rbindlist(timings)
csv_fp <- "tests/perf/last_run.csv"
fwrite(out, csv_fp)
cat(sprintf("\nWrote %s (%d rows)\n", csv_fp, nrow(out)))
cat(sprintf("Total elapsed: %.3fs\n", sum(out$elapsed)))

if (profvis_on) {
  if (!requireNamespace("profvis", quietly = TRUE)) {
    cat("profvis not installed; skipping HTML output.\n")
  } else {
    p <- profvis::profvis({
      dt_a <- shock_labor(dt_split, params, scenario = "S0")
      dt_cf <- build_counterfactual(dt_split, dt_a, step_b,
                                    params = params, baseline_cache = bc)
    })
    htmlwidgets::saveWidget(p, "tests/perf/profvis.html", selfcontained = TRUE)
    cat("Wrote tests/perf/profvis.html\n")
  }
}
