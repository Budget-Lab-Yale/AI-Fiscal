# Environment setup (cold start)

AI-Fiscal is **deliberately not self-contained**: the microdata, the
Tax-Simulator engine and its required local-fork patches, the package
libraries, and the cluster job driver all live *outside* this repo
(several are gitignored or — in the data's case — cannot be
redistributed at all; see [`docs/data_requirements.md`](data_requirements.md)).
A fresh clone therefore cannot run until the environment is assembled.

This document is that assembly checklist. It captures the one-time
bring-up so the *next* cold start is a single `sbatch`. Once the steps
below are done, the only per-run command is submitting the driver.

The concrete module name and library paths below are **Yale-Roberts
(`mccleary`/EasyBuild) specific** — adapt them for another cluster. The
*shape* of each step is portable.

## What you need before anything runs

| Precondition | How it's satisfied | Notes |
|---|---|---|
| R 4.4.2 | `module load R/4.4.2-gfbf-2024a` | The canonical cluster interpreter (matches `renv.lock`). Not on `PATH` by default. |
| Tax-Data vintage | `data/tax_data` symlink → shared vintage | Privacy-restricted; never committed. See [`docs/data_requirements.md`](data_requirements.md). |
| Tax-Simulator tree + 3 patches | clone + apply (Step 3) | The engine AI-Fiscal drives via `callr`. Patches kept out-of-tree on purpose. |
| AI-Fiscal package library | `renv::restore()` (Step 2) | 81 packages; binaries from Posit PPM. |
| Two extra Tax-Simulator packages | side library (Step 4) | `usincometaxes`, `dineq` — not in the cluster's R bundle. |
| `BLSMM_DIR` (optional) | clone of Budget-Lab-Small-Macro-Model | Enables the debt/GDP step; skips gracefully if unset. |

## Step 1 — R on `PATH`

```bash
source /etc/profile.d/z01_lmodinit.sh      # initialize Lmod in non-interactive shells
module load R/4.4.2-gfbf-2024a
Rscript --version                          # expect R 4.4.2
```

## Step 2 — restore AI-Fiscal's renv library

From the repo root:

```bash
Rscript -e 'renv::restore(prompt = FALSE)'
```

renv rewrites the Posit PPM repo in `renv.lock` to the platform's
binary URL automatically (RHEL9 here), so this is package downloads,
not source builds — a few minutes, not 20+.

## Step 3 — Tax-Simulator working tree + the three patches

```bash
git clone https://github.com/Budget-Lab-Yale/Tax-Simulator.git ../Tax-Simulator
```

Apply the three local-fork patches documented in
[`docs/tax_simulator_patches.md`](tax_simulator_patches.md). Apply them
**by content, not line number** (upstream drifts). All three carry an
`AI-Fiscal patch (...)` comment marker when applied:

1. **Issue 1** — comment out the `build_timeburden_table(ID)` call in
   `src/sim/run.R` (segfaults under `--multicore scenario`).
2. **Issue 2** — comment out the `build_horizontal_table(ID)` call in
   `src/sim/run.R` (`cut()` "breaks are not unique" on the
   counterfactual's point-mass income distribution).
3. **Issue 3** — make both `mc.cores = min(32, detectCores(...))` sites
   (`src/main.R`, `src/sim/run.R`) honor `MC_CORES` /
   `SLURM_CPUS_PER_TASK` before falling back to the core count.

Sanity-check that the patched files still parse:

```bash
Rscript -e 'invisible(parse("../Tax-Simulator/src/sim/run.R")); cat("OK\n")'
Rscript -e 'invisible(parse("../Tax-Simulator/src/main.R"));    cat("OK\n")'
```

## Step 4 — Tax-Simulator's package dependencies

Tax-Simulator has **no renv**; it loads everything in its
`requirements.txt` from the ambient R library. On the Yale-Roberts
cluster the EasyBuild R bundle already provides 8 of the 10
(`tidyverse`, `magrittr`, `rlang`, `yaml`, `data.table`, `openxlsx`,
`Hmisc`, `parallel`). Only two are missing — install them into a
**dedicated side library** so they don't pollute AI-Fiscal's renv:

```bash
mkdir -p ~/r_libs_taxsim
Rscript -e '
  options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/rhel9/latest"))
  install.packages(c("usincometaxes", "dineq"), lib = "~/r_libs_taxsim")
'
```

## Step 5 — the renv ✕ `callr` libpath gotcha (the non-obvious one)

The orchestrator runs Tax-Simulator in a `callr` subprocess
(`code/07_run_tax_sim.R`) whose library paths are **inherited from the
parent** orchestrator session. But that parent runs under AI-Fiscal's
renv, and **renv replaces `.libPaths()` with its project library and
strips the EasyBuild site bundle** (`R-bundle-CRAN`, etc.) — the very
place Tax-Simulator's `tidyverse` / `Hmisc` live. Result: the
subprocess can't find Tax-Simulator's packages, and it dies on
`library(tidyverse)` even though everything is installed.

The fix is to tell renv to **keep** those libraries on `.libPaths()`,
via `RENV_CONFIG_EXTERNAL_LIBRARIES` (colon-separated). renv then keeps
them, and `callr` propagates them to the child — while AI-Fiscal's renv
library stays first, so its locked versions still win:

```bash
export RENV_CONFIG_EXTERNAL_LIBRARIES="\
$HOME/r_libs_taxsim:\
/apps/software/2024a/software/R-bundle-CRAN/2024.11-foss-2024a:\
/apps/software/2024a/software/R-bundle-Bioconductor/3.20-foss-2024a-R-4.4.2:\
/apps/software/2024a/software/arrow-R/17.0.0.1-foss-2024a-R-4.4.2"
```

Verify the subprocess can see *all* of Tax-Simulator's requirements
before burning a job allocation — this checks in a real child process,
the environment that actually matters:

```bash
export TAX_SIMULATOR_DIR=$(readlink -f ../Tax-Simulator)
Rscript -e '
  reqs <- trimws(readLines(file.path(Sys.getenv("TAX_SIMULATOR_DIR"), "requirements.txt")))
  reqs <- reqs[nzchar(reqs)]
  chk <- tempfile(fileext = ".R")
  writeLines(sprintf(
    "r <- trimws(readLines(\"%s\")); r <- r[nzchar(r)];
     m <- r[!vapply(r, function(p) requireNamespace(p, quietly=TRUE), logical(1))];
     cat(\"MISSING:\", if(length(m)) paste(m, collapse=\", \") else \"(none)\", \"\\n\")",
    file.path(Sys.getenv("TAX_SIMULATOR_DIR"), "requirements.txt")), chk)
  p <- callr::rscript_process$new(options = callr::rscript_process_options(
    script = chk, wd = Sys.getenv("TAX_SIMULATOR_DIR"), env = callr::rcmd_safe_env()))
  p$wait(); cat(p$read_all_output_lines(), sep = "\n")
'
# expect: MISSING: (none)
```

## Step 6 — create the private runscript directory

The orchestrator writes its runscript to
`<Tax-Simulator>/config/runscripts/private/ai_fiscal.csv` and assumes
the `private/` directory exists. A fresh clone doesn't have it:

```bash
mkdir -p ../Tax-Simulator/config/runscripts/private
```

## Step 7 — environment variables for the run

```bash
export TAX_SIMULATOR_DIR=$(readlink -f ../Tax-Simulator)
export BLSMM_DIR=$(readlink -f ../Budget-Lab-Small-Macro-Model)   # optional
export MC_CORES="${SLURM_CPUS_PER_TASK:-8}"                       # Tax-Simulator mclapply (patch 3)
# plus RENV_CONFIG_EXTERNAL_LIBRARIES from Step 5
```

## Step 8 — submit

The full 18-cell × 3-flavor grid is an ~18-hour, multi-GB job; submit
it via SLURM rather than running it in a login session. The local
driver lives at `slurm_run.sh` (gitignored — it is per-user / per-
cluster and bundles Steps 1, 5, 7 + the submit). A minimal version:

```bash
#!/bin/bash
#SBATCH --job-name=AI-Fiscal_release
#SBATCH --output=<repo>/logs/sbatch_%j.out
#SBATCH --error=<repo>/logs/sbatch_%j.err
#SBATCH --time=18:00:00
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8

set -uo pipefail
source /etc/profile.d/z01_lmodinit.sh
module load R/4.4.2-gfbf-2024a

export TAX_SIMULATOR_DIR=<repo>/../Tax-Simulator
export BLSMM_DIR=<repo>/../Budget-Lab-Small-Macro-Model
export MC_CORES="${SLURM_CPUS_PER_TASK:-8}"
export RENV_CONFIG_EXTERNAL_LIBRARIES="$HOME/r_libs_taxsim:/apps/software/2024a/software/R-bundle-CRAN/2024.11-foss-2024a:/apps/software/2024a/software/R-bundle-Bioconductor/3.20-foss-2024a-R-4.4.2:/apps/software/2024a/software/arrow-R/17.0.0.1-foss-2024a-R-4.4.2"

cd <repo>
Rscript code/00_ai_fiscal_sim.R --overwrite --multicore scenario
```

```bash
sbatch slurm_run.sh
squeue -u "$USER"
```

The orchestrator prints a pre-flight banner first (resolved
Tax-Simulator dir/rev, Tax-Data vintage, BLSMM dir, `MC_CORES`); a
mis-set path or vintage shows up there in the first seconds. Logs land
in `logs/sbatch_<jobid>.{out,err}` and `logs/release_<timestamp>.log`.

## Gotchas, in one place

- **R isn't on `PATH`** until you `module load`; in non-interactive
  shells you must `source` the Lmod init first.
- **renv hides the system R bundle.** Without
  `RENV_CONFIG_EXTERNAL_LIBRARIES` (Step 5) the `callr` Tax-Simulator
  subprocess can't find `tidyverse`/`Hmisc` even though they're
  installed — it dies on `library(tidyverse)`. This is the single most
  surprising failure.
- **`private/` must exist** in the Tax-Simulator config tree (Step 6),
  or the first runscript write aborts with a `fwrite` "No such file or
  directory" error.
- **`usincometaxes` + `dineq`** are the only two Tax-Simulator
  requirements not in the cluster bundle (Step 4).
- **Don't pipe `module load`** (`module load X | tail`) — the load runs
  in a subshell and its environment changes are lost.
- **Single-year runs produce empty output.** Leave `--years` at its
  default (`baseline_year-1 : baseline_year`); Tax-Simulator's FY
  adjustment drops the earliest year, so the range must span ≥ 2 years.
- **The module name and the EasyBuild library paths are
  cluster-specific.** Re-derive them (`module avail R`,
  `Rscript -e '.libPaths()'`) on a different system.
