# AI-Fiscal — Budget Lab at Yale

Internal architecture reference for contributors and AI agents. Pairs
with [`README.md`](README.md) (user-facing setup / run / outputs)
and [`docs/ai_fiscal_methodology.md`](docs/ai_fiscal_methodology.md)
(the model itself). This document covers the *how* — code layout,
conventions, integration with Tax-Simulator, common gotchas.

## What this model does — and doesn't

AI-Fiscal estimates the change in federal revenue and the
distribution of post-tax-and-transfer income under a one-shot shift in
factor income shares driven by AI adoption. Inputs are calibrated
against Karger et al. 2026 (NBER w35046); outputs are produced by
running the Budget Lab Tax-Simulator on counterfactual tax-unit files
that this pipeline constructs.

**What it is NOT:**

- Not a corporate microsim — corporate income tax enters via a single
  macro wedge calibrated against the CBO baseline-year CIT level. No
  per-firm modelling.
- Not a general-equilibrium model — prices, wages outside the shock,
  and the asset stock are held at baseline. Capital flow is
  distributed across households without revaluing the stock.
- Not a wealth-frame simulation in v0.1.0 — $X$ is sized off the
  on-1040 *realized* base, so realization rates are built in by
  construction. Wealth-frame migration is on the v0.2.0+ roadmap.
- Not behavioral — labor supply and realization-rate responses are
  not modeled in the primary specification.

## Scope of v0.1.0

The release pipeline runs a fixed 18-cell scenario grid with no CLI
overrides for the scenario axes. Everything is in
[`config/scenario_params.yaml`](config/scenario_params.yaml).

| Axis        | Codes | Meaning |
|---|---|---|
| Variant     | `S`, `M`, `R`     | Karger Slow / Moderate / Rapid AI adoption (Tables 19 / 39 of NBER w35046) |
| Share mode  | `R`, `F`          | R = reallocate (Karger labor-share decline); F = fixed (s1 := 1 - L0) |
| Labor       | `S0`, `S2`, `S3`  | Proportional / Compressive / Expansive labor-income redistribution |
| Realization | `V1`              | Mechanical (all gross LTCG realized in-year) |

Scenario IDs encode the four axes: `ai_<variant>_<share_mode>_<labor>_<realization>`
— e.g. `ai_M_R_S0_V1` (Moderate, reallocate, proportional, mechanical).
The grid lives in `release_specs()` in
[`code/00_ai_fiscal_sim.R`](code/00_ai_fiscal_sim.R).

Decomposition runs append a flavor suffix to the scenario ID:
`ai_M_R_S0_V1_LO` (labor-only) and `ai_M_R_S0_V1_CO` (capital-only).
The aggregator at
[`code/08_aggregate.R`](code/08_aggregate.R)::`.scenario_flavor`
parses these so the `labor / capital / interaction` revenue split is
computed automatically.

## Pipeline architecture

The orchestrator at
[`code/00_ai_fiscal_sim.R`](code/00_ai_fiscal_sim.R) is the single
entry point. It runs end-to-end:

```
orchestrator (00_ai_fiscal_sim.R)
  ├── load merged baseline (01_load_data.R)
  │     - load_tax_units(year, data_dir)
  │     - apply_passthrough_split(dt, params)   <- Smith-Yagan-Zidar
  │
  ├── resolve (gk, alpha) per (variant, share_mode) (02_params.R)
  │     - load_params(yaml_path, variant, share_mode)
  │     - derives (gk, alpha) from (s1, gy, L0)
  │
  ├── for each (variant, share_mode):
  │     - Step B (04_allocate_capital.R) once, cached
  │         - macro CIT wedge
  │         - across-unit allocation (proportional to all-assets wealth)
  │         - within-unit allocation (asset_to_income_map.csv)
  │         - R1 retirement cascade
  │     - Step C (05_realization.R) once, cached
  │         - X_ltcg_V1 := X_ltcg_gross
  │
  ├── for each (variant, share_mode, labor_scenario):
  │     - Step A (03_shock_labor.R)
  │         - S0: rho_pos = L1_pos$ / L0_pos$
  │         - S2/S3: log-affine map with sigma = 1 ∓ k * g_y
  │     - for each flavor in {both, labor_only, capital_only}:
  │         - build_counterfactual(dt_baseline, step_a, step_b, flavor)
  │         - write_counterfactual_scenario(dt_cf, year, sid)
  │         - write_factor_channels(dt, sid)   <- ATR-by-decile sidecar
  │         - append runscript_row(sid, ...) to runscript
  │     - write_runscript(rows, runscript_path)
  │     - write <runscript>_macro.csv (per-variant aggregates)
  │     - write <runscript>_cell_params.csv (per-cell summary for the bundle)
  │
  ├── run_tax_sim()  (07_run_tax_sim.R)
  │     - callr subprocess invoking <TAX_SIMULATOR_DIR>/src/main.R
  │     - streams stdout/stderr to terminal + log file
  │
  ├── aggregate_tax_sim_output()  (08_aggregate.R)
  │     - revenue_deltas / income_deltas / gini_deltas / share_deltas
  │     - revenue_decomp (LO/CO decomposition)
  │     - atr_decile (via factor_channels sidecar)
  │     - microsim xlsx bundle
  │
  ├── assemble_deliverables()  (09_tables_figures.R)
  │     - revenue_grid (long + wide) with macro CIT layered
  │     - decile_panel
  │     - revenue_to_gdp (CBO-anchored)
  │     - share_mode_comparison (R vs F twins)
  │     - publishable xlsx bundle
  │
  ├── assemble_figures()  (10_figures.R)
  │     - PNG+PDF figure suite under results/figures/<year>/
  │     - figure_data_<year>.xlsx
  │
  └── run_blsmm_step()  (15_blsmm_debt_gdp.R)  -- optional
        - per-scenario 2030 debt/GDP via Budget Lab Small Macro Model
        - skips gracefully when BLSMM_DIR is unset
```

### File-by-file table

| File | Role |
|---|---|
| `code/00_ai_fiscal_sim.R` | Orchestrator. Loops the 18-cell grid; CLI parser; log tee. |
| `code/00_utils.R` | Shared helpers + asset-column registry. **Source first** in every other file. |
| `code/01_load_data.R` | Load merged PUF + SCF; SYZ pass-through split. Handles vintage column rename (`value.*` → bare; `dc` → `retirement`). |
| `code/02_params.R` | Resolve `(gk, alpha)` from `(s1, gy, L0)`. Validates yaml keys present. |
| `code/03_shock_labor.R` | **Step A** — labor redistribution (S0 / S2 / S3). |
| `code/04_allocate_capital.R` | **Step B** — macro CIT, across-unit allocation, within-unit allocation, R1 cascade. |
| `code/05_realization.R` | **Step C** — V1 mechanical realization. Tiny file by design. |
| `code/06_build_counterfactual.R` | Build per-unit cf data; write to sibling scenario folder under Tax-Data vintage; emit runscript rows. |
| `code/07_run_tax_sim.R` | Invoke Tax-Simulator's `src/main.R` via `callr` in a clean subprocess. |
| `code/08_aggregate.R` | Read Tax-Simulator output; build revenue / income / inequality / decomp / ATR tables; microsim xlsx. |
| `code/09_tables_figures.R` | Layer macro CIT onto microsim totals; build publishable grid; CBO-anchored rev/GDP; publishable xlsx. |
| `code/10_figures.R` | YBL-palette PNG figure suite; figure_data xlsx. |
| `code/11_validation.R` | Standalone input-side diagnostic against CBO / SOI / NIPA / DFA. Not in main pipeline. |
| `code/13_macro_params_table.R` | Helper for 09's `cell_params` sheet. |
| `code/15_blsmm_debt_gdp.R` | Optional BLSMM debt/GDP tie-in. Reads `revenue_to_gdp_<year>.csv`. |
| `code/make_synthetic_tax_units.R` | Regenerate the committed synthetic fixture from a real vintage. |

## Config conventions

### `config/scenario_params.yaml` is the single source of truth

Every tunable parameter is here. Each leaf carries two sibling keys:

- `<param>_status`: one of `sourced` / `preliminary` / `derived` / `choice`
- `<param>_source`: short citation or pointer to a calibration receipt

[`code/02_params.R`](code/02_params.R)::`load_params()` validates that
every required key in `.REQUIRED_PARAM_KEYS` is present and aborts
with a list of any gaps. **Adding a new parameter:** add it to the
yaml with `_status` / `_source` siblings, then add the dotted path to
`.REQUIRED_PARAM_KEYS`.

The `parameter_index` sheet on every xlsx bundle is auto-generated
from the yaml — readers can see every parameter's value, status, and
source without leaving the workbook.

### Other config files

- [`config/retirement_calibration.yaml`](config/retirement_calibration.yaml)
  — R1 cascade constants ($r_R$, $s_P$, $s_I$, $\tau_P$, $\tau_I$).
- [`config/asset_to_income_map.csv`](config/asset_to_income_map.csv)
  — within-unit map from asset class to taxable-income type.
- [`config/calibration/`](config/calibration/) — calibration receipts
  (`kappa_corp_calculation.csv`, `nipa_2024_z1_f3.csv`,
  `validation_benchmarks.csv`).

### Asset registry

The canonical wealth-column universe lives in
[`code/00_utils.R`](code/00_utils.R) as `.ASSET_KNOWN`,
`.ASSET_BASE_ALL_ASSETS`, and `.INCOME_BEARING_COLS`. If a future
Tax-Data vintage adds a new `value.*` column,
`load_tax_units()` warns at load time — surface it, then update
`.ASSET_KNOWN` (and likely `.ASSET_BASE_ALL_ASSETS`).

## Tax-Simulator integration

AI-Fiscal **consumes** Tax-Simulator; it doesn't fork it. The
contract:

1. **Counterfactual data.** Orchestrator writes a `tax_units_<year>.csv`
   per scenario into a sibling scenario folder under the pinned
   Tax-Data vintage. Every other baseline file (other-year tax-units,
   factor_ledger, dependencies, etc.) is **symlinked** into the
   scenario folder so Tax-Simulator's parser finds them. See
   `write_counterfactual_scenario()` in
   [`code/06_build_counterfactual.R`](code/06_build_counterfactual.R).
2. **Runscript.** A CSV at
   `<TAX_SIMULATOR_DIR>/config/runscripts/private/ai_fiscal.csv`
   lists `baseline` + 54 cells (18 × 3 flavors). The
   `dep.Tax-Data.ID` column points each row at the matching
   scenario folder.
3. **Invocation.**
   [`code/07_run_tax_sim.R`](code/07_run_tax_sim.R)::`run_tax_sim()`
   spawns a `callr::rscript_process` cwd'd to `TAX_SIMULATOR_DIR`,
   running `src/main.R private/ai_fiscal NULL <user> 1 <vintage> 1 0 NULL 0 <multicore>`
   (the 7th arg, `stacked`, is `0`: the release sets `stacked <- FALSE`
   because LO/CO/both are parallel scenarios, not stacked estimates).
4. **Output.** Lands at
   `<output_roots.local>/model_data/Tax-Simulator/v<N>/<vintage>/<scenario_id>/...`.
   `tax_sim_output_root()` computes the path by reading
   `config/interfaces/{output_roots,interface_versions}.yaml` from
   the Tax-Simulator tree.
5. **Local-fork patches.** Three are required; see README §"Tax
   calculator (Tax-Simulator)". `B6` in `todo.md` is the long-term
   plan to upstream them.

### Why `callr` instead of `source()`

Tax-Simulator unconditionally `library(tidyverse)` and does some
top-level assignments. Sourcing it in-process pollutes the
orchestrator's global env and risks ggplot2 / scales version
collisions. A clean subprocess avoids both. Tradeoff: subprocess
overhead per run (~3s at startup), which is invisible against an
18-hour pipeline.

## Testing

- [`tests/testthat.R`](tests/testthat.R) is the suite entry point.
- [`tests/testthat/helper-pipeline.R`](tests/testthat/helper-pipeline.R)
  runs once per suite, sets up shared objects (`dt_baseline`,
  `params`, `step_b`, etc.), and **falls back to the synthetic
  fixture** at `tests/fixtures/synthetic_tax_data/` when
  `data/tax_data` is absent — so the suite works in CI and on
  contributor machines without PUF access.
- Tests are mostly invariants (Step A aggregate identity, sum(w·X) =
  X_to_units, decomposition algebra) that hold against any
  well-formed baseline. The synthetic fixture is for I/O / schema
  smoke only — no economic content.
- `code/11_validation.R` is the **standalone** input-side diagnostic.
  Reconciles per-unit aggregates against CBO IIT/CIT, SOI components,
  NIPA labor/capital splits, and DFA wealth-share benchmarks. Not in
  the orchestrator path; run manually after refreshing the vintage.

### CI

[`.github/workflows/test.yml`](.github/workflows/test.yml) runs the
testthat suite on every push and PR against `main`, ubuntu-latest /
R 4.5 / `renv::restore()`. Posit Public Package Manager is enabled
so package installs use pre-built binaries (renv from source would
take 20+ min per CI run).

Two tests use `skip_on_os("windows")` — `file.symlink()` requires
admin / developer mode on Windows and silently fails otherwise. They
pass on Linux and Mac.

## Common gotchas

- **`data/tax_data` is a symlink.** Always. The pipeline calls
  `normalizePath()` to follow it. If the symlink is missing
  `tax_data_vintage()` aborts with "Tax-Data symlink not found";
  that's the correct message but it's actually saying "you're either
  not in the project root or the symlink isn't set."
- **Vintage column rename (2026050315+).** The merged file prefixes
  wealth columns with `value.` and splits retirement into `dc` + `db`.
  `load_tax_units()` strips the prefix and renames `dc` → `retirement`
  so downstream code is vintage-agnostic. `value.db` (DB pension
  wealth) is loaded but intentionally not in `.ASSET_BASE_ALL_ASSETS`
  — see the `.ASSET_KNOWN` comment in `code/00_utils.R`.
- **`AI_FISCAL_SCRATCH_ROOT`** is only for the standalone
  `Rscript code/08_aggregate.R` entry point. The orchestrator
  passes `output_root` directly so the env var isn't required for
  the main pipeline. (Easy to mis-read because the README mentions
  the env var without that caveat.)
- **Tax-Simulator FY adjustment drops the earliest year of each
  scenario.** The orchestrator defaults `years` to
  `(baseline_year - 1):baseline_year` to compensate; single-year runs
  produce empty `receipts.csv`. The orchestrator aborts at the input
  check (`build_ai_fiscal_runs:159-165`) if the earlier-year file
  isn't present in the vintage.
- **`revenue_to_gdp_<year>.csv` is the handoff to BLSMM.** 09
  produces it only when both `cell_params` and the CBO yaml are
  loaded; without it, 15 skips with a warning. Don't be surprised if
  a dry-run with a tiny grid skips BLSMM.
- **Decomposition uses suffixed scenario IDs.** `_LO` and `_CO`
  suffixes are mechanical — `08_aggregate.R::.scenario_flavor()` and
  `.scenario_base()` are the canonical parsers. Don't introduce new
  suffixes without updating those.
- **`pass_throughs` SCF column can have small negatives** (artifact
  of the donor-pool blend). `04_allocate_capital.R:135` clamps them
  to zero before computing within-unit shares. Magnitude is tiny;
  worth noting if you ever debug allocations that don't sum to
  `X_to_units`.
- **xlsx sheet append is replace-not-add.** `15_blsmm_debt_gdp.R::.append_xlsx_sheet`
  removes any existing sheet with the target name before writing,
  so re-running the BLSMM step against an existing bundle doesn't
  pile up duplicate sheets.
- **The scenario ID `baseline` is reserved by Tax-Simulator.** Don't
  use it as a cell ID. The runscript always includes one explicit
  `baseline` row pointing at the un-shocked Tax-Data baseline.
- **Output volume.** A full release run produces several dozen figure
  PNGs + publishable xlsx + ~10 CSVs per year, plus the Tax-Simulator
  detail tree (large — multi-GB at full sample). The detail tree and
  timestamp-vintaged xlsx are gitignored; only the canonical
  `*_latest.xlsx` bundles and the figure suite are tracked.

## When in doubt

- **Adding a parameter:** yaml entry with `_status`/`_source` siblings,
  add to `.REQUIRED_PARAM_KEYS` in `02_params.R`, optionally
  surface in the appropriate `_xlsx` sheet builder in 08 or 09.
- **Adding a scenario axis:** update `release_specs()` in
  `00_ai_fiscal_sim.R`, the scenario_id regex in
  `09_tables_figures.R::.parse_scenario_axes`, the `scenario_guide`
  table in `08_aggregate.R::.build_scenario_guide`, and the variable
  list builders. The release is intentionally rigid here.
- **Adding a new figure:** add a `fig_*()` function to `10_figures.R`,
  register it in `assemble_figures()` via `.fig_entry()`. Reuse the
  shared palette / theme (`.fig_theme()`, `PAL_VARIANT`, etc.) so
  the new figure colors-match the suite.
- **Touching the synthetic fixture's structure:** update the
  generator (`code/make_synthetic_tax_units.R`), regenerate from a
  real vintage if available, **and** consider whether the existing
  committed CSV needs a one-off patch (joint constraints can be
  applied directly via `.apply_joint_constraints()` without
  regenerating). The fixture is the CI smoke-test target — breaking
  it breaks `main`.
