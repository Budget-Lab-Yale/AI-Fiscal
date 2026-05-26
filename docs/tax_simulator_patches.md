# Tax-Simulator patches required by AI-Fiscal

AI-Fiscal runs the Budget Lab [Tax-Simulator](https://github.com/Budget-Lab-Yale/Tax-Simulator)
as a subprocess (see `code/07_run_tax_sim.R`). Getting the 18-cell ×
3-flavor release grid through Tax-Simulator currently requires three
local edits to the Tax-Simulator working tree. None are
AI-Fiscal-specific — they're general robustness / portability issues
that any caller with a similar input distribution or cluster setup
would hit — so the intent is to upstream them rather than carry the
diffs out-of-tree.

This document is the detailed write-up behind the short "three
local-fork patches" note in the AI-Fiscal `README.md`. It is the
basis for the issues / PRs to file against Tax-Simulator.

**Line numbers below are against `Budget-Lab-Yale/Tax-Simulator@main`
as of 2026-05-26.** (The AI-Fiscal README cites different numbers
because those refer to the *patched* local fork, where commenting out
the two calls shifts subsequent lines.)

| # | Issue | Location | Severity | PR-ready? |
|---|---|---|---|---|
| 1 | `build_timeburden_table` segfaults under `--multicore scenario` | `src/sim/run.R:90` → `src/data/post_processing/time_burden.R:234` | Blocks parallel runs | No — root cause unverified |
| 2 | `build_horizontal_table` errors "breaks are not unique" | `src/sim/run.R:93` → `src/data/post_processing/horizontal.R:66` | Blocks post-processing on degenerate income distributions | Maybe — touches binning semantics |
| 3 | `mc.cores` ignores the scheduler allocation | `src/main.R:110`, `src/sim/run.R:142` | Oversubscribes shared SLURM nodes | Yes — clean, mechanical |

---

## Issue 1 — `build_timeburden_table` segfaults under `--multicore scenario`

**Symptom.** With `multicore = 'scenario'`, the post-processing step
segfaults (hard crash, not an R error) inside `build_timeburden_table()`.
Runs with `multicore = 'none'` complete fine.

**Trigger / location.** `build_timeburden_table(ID)` is called at
`src/sim/run.R:90`. The crash is in `calc_time_burden()`, at the
matrix multiply inside a `dplyr::mutate` (`src/data/post_processing/time_burden.R:234`):

```r
burden = (
  across(.cols = all_of(provisions)) %>%
            as.matrix %*% time_costs
            - was_hoh * (rowSums(across(.cols = all_of(hoh_item))) * 11 + 34)
            + (no_tax == 0) * fixed_cost
) %>% as.vector()
```

**Root-cause hypothesis.** A matrix multiply (`%*%`) that segfaults
*only* under `mclapply`-forked workers is the classic signature of a
**multithreaded BLAS that isn't fork-safe**. OpenBLAS / MKL spin up a
thread pool; when the parent process has already initialized that pool
and then `fork()`s, the child inherits locks in an inconsistent state
and crashes on the next BLAS call. This is an environment/BLAS
interaction, not a bug in the R logic — `calc_time_burden` is correct
single-threaded.

**Likely real fix (not yet verified).** Force single-threaded BLAS in
the workers, e.g. `RhpcBLASctl::blas_set_num_threads(1)` at the top of
the forked function, or set `OMP_NUM_THREADS=1` for the run, or
replace the BLAS `%*%` with a non-BLAS row-sum formulation. Each needs
testing on the cluster + real data; AI-Fiscal can't verify a fix in
isolation.

**AI-Fiscal's current stopgap.** Comment out the `build_timeburden_table(ID)`
call. This is *not* an upstreamable fix — it removes the time-burden
report for every caller. Flagged here for the maintainer to diagnose
with the actual environment.

---

## Issue 2 — `build_horizontal_table` errors "breaks are not unique"

**Symptom.** Post-processing aborts with
`Error: 'breaks' are not unique` from a `cut()` call.

**Trigger / location.** `build_horizontal_table(ID)` is called at
`src/sim/run.R:93`. The failing `cut()` is in the `inc_pctile`
assignment (`src/data/post_processing/horizontal.R:66`):

```r
inc_pctile = cut(
  x      = inc,
  breaks = c(-Inf, Hmisc::wtd.quantile(inc, weight, seq(0.01, 0.99, 0.01)), Inf),
  labels = 1:100,
  include.lowest = TRUE
)
```

When the weighted income distribution has point masses (many units at
identical income — which a counterfactual that shifts a block of units
to the same value can induce), adjacent percentiles in
`wtd.quantile(inc, weight, seq(0.01, 0.99, 0.01))` collapse to the
same number. `cut()` rejects the resulting non-unique `breaks`.

**Candidate fix.** De-duplicate the breaks before `cut()`. But note
that dropping a break also drops a percentile bin, so the
`labels = 1:100` 1:1 correspondence no longer holds. Two clean options:

1. `breaks <- unique(c(-Inf, wtd.quantile(...), Inf))` and switch to
   `labels = FALSE` (integer bin indices, not forced to 1:100), then
   derive quintiles from the rank rather than the literal label.
2. Compute percentile rank directly from the weighted ECDF and bin on
   that, sidestepping `cut()` entirely.

**Why this needs the maintainer's call.** Both options change how
percentile bins are assigned when quantiles collapse, which affects
the horizontal-equity measure's grouping semantics. That's an analytic
choice for the Tax-Simulator owner, not a mechanical fix AI-Fiscal
should impose unilaterally.

**AI-Fiscal's current stopgap.** Comment out the
`build_horizontal_table(ID)` call.

---

## Issue 3 — `mc.cores` ignores the scheduler allocation

**Symptom.** On a shared SLURM node, a job allocated N cores
(`--cpus-per-task=N`) spawns far more than N parallel workers,
oversubscribes the node, and is throttled or killed.

**Trigger / location.** Both `mclapply` calls hardcode the worker
count to the *physical* core count of the whole machine:

- `src/main.R:110` (scenario-level parallelism):
  ```r
  mc.cores = min(32, detectCores(logical = F))
  ```
- `src/sim/run.R:142` (year-level parallelism): identical expression.

`detectCores()` reports the machine's cores, not the cores the
scheduler granted the job, so on a shared node the two diverge badly.

**Proposed fix (clean, mechanical, PR-ready).** Respect the
allocation, falling back to the current expression:

```r
.mc_cores <- function() {
  env <- Sys.getenv("MC_CORES", Sys.getenv("SLURM_CPUS_PER_TASK", ""))
  if (nzchar(env)) return(as.integer(env))
  min(32, parallel::detectCores(logical = FALSE))
}
```

then `mc.cores = .mc_cores()` at both sites. `MC_CORES` lets a caller
override explicitly; `SLURM_CPUS_PER_TASK` makes the default
scheduler-aware on SLURM with no caller action. Backward-compatible:
absent both env vars, behavior is unchanged.

**AI-Fiscal's current stopgap.** A local patch makes `mc.cores` read
`MC_CORES` (the orchestrator forwards it to the subprocess — see
`code/07_run_tax_sim.R`). This is the one of the three that is
genuinely ready to upstream as-is.

---

## Recommended dispatch

- **Issue 3** → PR. Self-contained and low-risk.
- **Issue 2** → issue first (or a PR with the candidate fix flagged as
  "needs your call on binning semantics"). The diagnosis is solid; the
  fix direction touches analytic intent.
- **Issue 1** → issue, not PR. Hand the maintainer the root-cause
  hypothesis (fork × multithreaded BLAS) and the exact crash site; the
  real fix needs the cluster + data to verify.
