# AI-Fiscal — v0.1.0 release build

Simulating the fiscal impact of an AI-driven labor-to-capital income
shift, using the Budget Lab tax microsimulation.

**Objective.** Estimate the change in federal revenue (total and by
instrument) and the distribution of post-tax-and-transfer income under
shocks to productivity and the capital-labor share. This is the
simplified release build: the pipeline runs a single, fixed grid and
is intended to be read end-to-end by external reviewers.

Methodology lives in `docs/ai_fiscal_methodology.md`.

## What this version runs

A single 18-cell grid, hard-coded into the orchestrator:

| Axis        | Values                       | Notes                       |
|-------------|------------------------------|-----------------------------|
| Shock variant   | S, M, R                  | Karger Slow / Moderate / Rapid (Tables 19 / 39 of NBER w35046) |
| Share mode      | R, F                     | R = reallocate (Karger), F = fixed labor-capital split |
| Labor scenario  | S0, S2, S3               | Proportional, Compressive, Expansive |
| Realization     | V1                       | Mechanical (all gains realized in-year) |
| Retirement      | R1                       | Income-flow cascade (full slice realized) |
| Asset base      | all_assets               | All wealth columns |

Every run produces:

1. The microsim counterfactual for each cell (× 3 decomposition
   flavors: both, labor-only, capital-only).
2. The publishable workbook + figure suite + decomposition table.
3. A timestamped log file at `logs/release_<timestamp>.log`.

This is the v0.1.0 income-frame release. Alternative realization
treatments (V2 / V3), retirement cascades (R1 / R2), labor-side AI
exposure (S1), and asset bases (non_housing / productive_capital /
taxable_capital_income) have all been removed from this branch so
reviewers see only the published methodology. The full development
history (including those code paths) is on the `main` branch.

## External dependencies

### R environment

R 4.4 or newer. Package versions are pinned via [`renv`](https://rstudio.github.io/renv/).
From a fresh clone:

```r
# in R, from the project root:
renv::restore()
```

This installs the locked versions of every package recorded in
`renv.lock`. `requirements.txt` is a human-readable companion listing
the same packages without version pins, mirroring the Tax-Simulator
convention. The lockfile was generated against R 4.5.2.

### Tax microsimulation data (Budget Lab PUF + SCF, merged)

Reproducers need access to the Budget Lab Tax-Data vintage (PUF +
SCF, merged). External readers without PUF access can use the
synthetic fixture below for I/O / schema smoke tests.

Per-year tax-unit files at `tax_data/baseline/tax_units_<year>.csv`
carry PUF income/deduction columns plus SCF-imputed asset values.
`code/01_load_data.R` strips the `value.` prefix and renames
`dc → retirement` at load time so downstream code is schema-agnostic.

`data/tax_data` should symlink (or copy) the vintage into the
project root. Not committed.

#### Synthetic fixture (no PUF access)

A 10,000-row fake PUF + SCF file is committed at
`tests/fixtures/synthetic_tax_data/baseline/tax_units_2030.csv`. It
shares the real schema but draws values from generic distributions —
no row-level economic information from the source is preserved.
Intended for I/O / schema smoke tests, not economic validation:

```bash
Rscript code/00_ai_fiscal_sim.R \
  --data-dir tests/fixtures/synthetic_tax_data
```

To regenerate from a real vintage (requires PUF access):

```bash
Rscript code/make_synthetic_tax_units.R [year] [n_rows] [out_dir]
```

### Tax calculator (Tax-Simulator)

Cloned out-of-tree. Upstream:
https://github.com/Budget-Lab-Yale/Tax-Simulator. The release pipeline
requires a resolvable Tax-Simulator working tree (set
`TAX_SIMULATOR_DIR` or rely on the pinned default).

Three local-fork patches are required (kept in the Tax-Simulator
working tree, not part of upstream):

1. **`src/sim/run.R:95` — `build_timeburden_table(ID)` commented out.**
   Segfaults under `--multicore scenario` from a concurrent
   `dplyr::mutate(... %*% time_costs - ...)` evaluation.
2. **`src/sim/run.R:104` — `build_horizontal_table(ID)` commented out.**
   `'breaks' are not unique` when a counterfactual pushes any unit's
   `expanded_inc` across zero.
3. **`src/main.R:110` and `src/sim/run.R:153` — `mc.cores` honors
   `MC_CORES` env var.**

### Macro model (optional — for debt/GDP step)

`code/15_blsmm_debt_gdp.R` consumes the per-scenario revenue/GDP
deltas and pipes them through the **Budget Lab Small Macro Model**
to recover scenario-specific 2030 debt/GDP. Clone separately and
point `BLSMM_DIR` at the working tree:

```bash
export BLSMM_DIR=/path/to/Budget-Lab-Small-Macro-Model
```

Upstream: <https://github.com/Budget-Lab-Yale/Budget-Lab-Small-Macro-Model>.
If `BLSMM_DIR` is unset (or doesn't point at a valid clone), the
step skips with a warning and the rest of the pipeline finishes
normally — the BLSMM CSV / xlsx sheet / figures just won't be
produced.

### Environment variables

The pipeline reads these env vars (CLI flags override where noted):

| Variable | Read by | Purpose |
|---|---|---|
| `TAX_SIMULATOR_DIR` | `code/07_run_tax_sim.R` | Path to a Tax-Simulator working tree. Required. |
| `BLSMM_DIR` | `code/15_blsmm_debt_gdp.R` | Path to a Budget Lab Small Macro Model clone. Optional — step skips with a warning when unset. |
| `AI_FISCAL_SCRATCH_ROOT` | `code/08_aggregate.R` | Scratch root configured in your local Tax-Simulator `config/interfaces/output_roots.yaml`. Read only by the standalone aggregator entry point (`Rscript code/08_aggregate.R`); the orchestrator passes the resolved output root directly and doesn't require this var. |
| `MC_CORES` | `code/07_run_tax_sim.R` | Forwarded to the Tax-Simulator subprocess so the local-fork `mclapply` patch can read it. Set explicitly under SLURM. |

## Layout

```
code/       # R scripts (numbered in pipeline order)
config/     # scenario_params.yaml + asset map + retirement calibration
data/
  tax_data/    # symlink -> shared Tax-Data vintage
  aggregates/  # output: deliverable CSVs + XLSX bundles + PDFs
docs/       # methodology
tests/      # testthat suite (Rscript tests/testthat.R)
  fixtures/synthetic_tax_data/  # 10k-row schema-equivalent fake PUF
```

## Pipeline

| Script | Role |
|---|---|
| `00_ai_fiscal_sim.R` | Orchestrator. Loops the 18-cell grid, invokes Tax-Simulator, runs 08+09+10, then 15 (skipped if BLSMM unavailable). |
| `00_utils.R` | Shared helpers (weighted quantile / top share / Gini, asset-column registry). |
| `01_load_data.R` | Load merged PUF + SCF tax-units; Smith-Yagan-Zidar passthrough split. |
| `02_params.R` | Read `scenario_params.yaml`; derive `(gk, alpha)` from `(s1, gy, L0)` per variant + share mode. |
| `03_shock_labor.R` | **Step A** — labor-income redistribution (S0 / S2 / S3). |
| `04_allocate_capital.R` | **Step B** — CIT wedge + across-units allocation (all_assets) + within-unit map + R1 retirement cascade. |
| `05_realization.R` | **Step C** — V1 mechanical realization. |
| `06_build_counterfactual.R` | Build the counterfactual tax-units dataset; write to `<Tax-Data vintage>/<scenario_id>/`. |
| `07_run_tax_sim.R` | Invoke Tax-Simulator via `callr` in a clean R subprocess. |
| `08_aggregate.R` | Revenue + income-totals + inequality deltas + decomp + microsim `.xlsx` bundle. |
| `09_tables_figures.R` | Layer macro CIT onto microsim totals; assemble publishable grid + decile panel + `.xlsx` bundle. |
| `10_figures.R` | Publishable PNG+PDF figure suite. |
| `11_validation.R` | Input-side benchmark check (CBO / SOI / NIPA / DFA / SCF). Standalone diagnostic — not in the main pipeline. |
| `13_macro_params_table.R` | Helper used by 09 to assemble the per-cell `cell_params` sheet. |
| `15_blsmm_debt_gdp.R` | Pipe per-scenario revenue/GDP deltas through the Budget Lab Small Macro Model to recover scenario-specific 2030 debt/GDP. Requires `BLSMM_DIR`; skips gracefully if unset. |
| `make_synthetic_tax_units.R` | Regenerate the synthetic PUF/SCF fixture. |

## Running

A single command:

```bash
Rscript code/00_ai_fiscal_sim.R
```

That builds all 18 cells, runs Tax-Simulator in three flavors per
cell (both / labor-only / capital-only), aggregates the output, and
emits the publishable workbook + figure suite. Output streams to the
terminal *and* to `logs/release_<timestamp>.log`.

### CLI flags (overrides for plumbing only)

| Flag | Effect |
|---|---|
| `--data-dir PATH` | Tax-Data root. Default: `data/tax_data`. Pass `tests/fixtures/synthetic_tax_data` for a no-PUF smoke. |
| `--years YYYY:YYYY` | Year range. Default: `(baseline_year - 1):baseline_year`. |
| `--runscript-path PATH` | Where to write the Tax-Simulator runscript. |
| `--vintage YYYYMMDDHHMM` | Override the Tax-Simulator output vintage stamp. |
| `--multicore none\|scenario\|year` | Tax-Simulator parallelization. |
| `--overwrite` | Overwrite existing counterfactual scenario folders. |
| `--log PATH` | Override the default log path. |

There are no flags for variant / labor / realization / retirement /
asset_base selection — the grid is fixed.

### SLURM

The 18-cell grid × 3 flavors fits in 128 G / 8 CPUs / 18 hr.
`scripts/` is gitignored. Starter:

```bash
#!/bin/bash
#SBATCH --job-name=AI-Fiscal_release
#SBATCH --output=logs/sbatch_%j.out
#SBATCH --error=logs/sbatch_%j.err
#SBATCH --time=18:00:00
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8

set -euo pipefail
cd /path/to/your/AI-Fiscal
module load R/4.4.2-gfbf-2024a

MC_CORES="${MC_CORES:-8}" Rscript code/00_ai_fiscal_sim.R \
  --overwrite --multicore scenario
```

### Outputs

All artifacts land in `results/aggregates/`. Per year (default 2030):

| File | Source | Contents |
|---|---|---|
| `revenue_deltas_<year>.csv` | 08 | Receipts deltas per scenario × instrument ($B) |
| `income_deltas_<year>.csv` | 08 | Pretax / aftertax aggregate income deltas ($B) |
| `gini_deltas_<year>.csv` | 08 | Gini deltas per scenario × concept |
| `share_deltas_<year>.csv` | 08 | Decile + top-share deltas |
| `revenue_decomp_<year>.csv` | 08 | Per scenario × instrument: `delta_labor`, `delta_capital`, `delta_both`, `interaction` |
| `atr_decile_<year>.csv` | 08 | Per scenario × decile: baseline + counterfactual ATR-by-decile inputs |
| `revenue_grid_<year>.csv` (+ `_wide`) | 09 | Microsim deltas with macro CIT layered (`total_with_macro_cit` is the bottom line) |
| `decile_panel_<year>.csv` | 09 | Decile shares for plotting |
| `revenue_to_gdp_<year>.csv` | 09 | Per-scenario federal revenue and GDP; CBO-anchored rev/GDP |
| `ai_fiscal_<year>_<vintage>.xlsx` + `ai_fiscal_<year>_latest.xlsx` | 08 | Microsim bundle |
| `ai_fiscal_publishable_<year>_<vintage>.xlsx` + `ai_fiscal_publishable_<year>_latest.xlsx` | 09 | Publishable bundle |
| `results/figures/<year>/*.{png,pdf}` | 10 | Publishable figure suite |
| `blsmm_debt_to_gdp_<year>.csv` + `blsmm_debt_to_gdp` xlsx sheet + `results/figures/<year>/blsmm_debt_to_gdp_<year>_{fixed,reallocate}.{png,pdf}` | 15 | Optional — per-scenario 2030 debt/GDP from BLSMM; produced only if `BLSMM_DIR` is set |

Both `.xlsx` bundles are self-documenting. The `variable_list` sheet
describes every column on every data sheet; the `scenario_guide`
sheet documents the axis codes; the `cell_params` sheet carries the
per-cell macro / shock parameters; the `parameter_index` sheet is
auto-generated from `config/scenario_params.yaml`.

Identity checks: `Rscript tests/testthat.R`.

## Parameters

All scenario parameters live in `config/scenario_params.yaml`. Each
leaf carries sibling `_status` and `_source` keys.
`02_params.R::load_params()` validates that every required key is
present and aborts with a list of any gaps.

| Section | Keys | What it controls |
|---|---|---|
| `baseline_year` | scalar | Microsim year aged to match Karger's 5-yr horizon (default 2030). |
| `cbo_baseline` | growth rates, GDP, rev/GDP, CIT/GDP | CBO 2025 baseline (publication 62105). |
| `shock` | `baseline_labor_share`, `variants.{S,M,R}.{s1, r_ai_annual}` | Karger 2026 NBER w35046 (Tables 19/39). |
| `labor_inequality` | `k` | Multiplier on g_y that sets the S2/S3 dispersion shift. |
| `passthrough` | wage-threshold + capital shares | Smith-Yagan-Zidar 2019, applied at the tax-unit level. |
| `corporate` | `kappa_corp`, `cit_statutory` | Macro CIT wedge calibrated against the CBO baseline-year CIT level. |

Retirement cascade calibration constants (R1) live in
`config/retirement_calibration.yaml`. The kappa_corp calibration receipt
lives in `config/calibration/` and is embedded as a sheet in every
publishable bundle.

## License

MIT. See `LICENSE`.

## Citation

See `CITATION.cff`.
