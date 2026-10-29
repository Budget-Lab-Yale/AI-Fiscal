# Version 1.2: implementation plan

Branch `AI-Fiscal-V1.2`, cut from `main` at `d2fe81a` (v1.0.1 plus the
relative-paths change). Written 2026-10-28 from the Version 2 discussion deck
(OneDrive `AI-Fiscal-V2.0/slides/2026_10_discussion/`, the 2026-10-27 build)
and the decisions log on branch `AI-Fiscal-V2.0` (`docs/v2_decisions.md`).
Figure production for this version has its own plan:
[`v1_2_figure_pipeline_plan.md`](v1_2_figure_pipeline_plan.md).

## What Version 1.2 is

Version 1.2 keeps the Version 1 design and fixes the simplifications behind
Issues 1–3 in the deck. The shock is still sized on income reported on tax
returns, capital is still allocated by asset holdings, labor is still
allocated under the three distributional rules, and Tax-Simulator still
computes individual and payroll taxes. It is the low-cost extension, and it
keeps the published scenarios comparable.

What changes, as listed on the "Version 1.2 explained" slide:

1. **How the shock is mapped.** Apply the survey's share change within
   nonfarm business and bridge to the whole economy; measure it against the
   Budget Lab Macro-Projections baseline path rather than today's share; run
   annual paths for ten fiscal years.
2. **The accounting.** Bridge to national income with the Saez–Zucman split
   Version 1 already uses on the tax file, and account for each part of
   national income that is not assigned; make the corporate ratio consistent;
   hold rent and interest on baseline paths; attribute corporate tax to
   households in the distribution tables with Tax-Simulator's existing key.
3. **Whether AI income faces the average tax rate.** Payout and realization
   become explicit parameters, including a separate realization rate for AI
   gains; a capital allocator that concentrates AI gains at the top sits
   alongside the asset-proportional rule; and the corporate increment gets
   sensitivities for profits booked abroad or as export income and for
   returns paid out as deductible interest.

The shock also becomes generic annual paths, so Karger et al. (2026) is one
preset among several.

**Not in Version 1.2.** Sizing the shock in the national accounts, the
corporate module, ownership before households, and the asset ledger are
Version 2.0. Labor-side modeling (wages and employment across workers,
replacing the three fixed rules, and a pure inequality scenario) is
Version 2.1. Retirement balances and withdrawals (D11) stay as in Version 1.
Generating the shock with a diffusion, task-based, or macro model is out of
scope.

## The rule for every change: v1.0.1 is a setting

Each change enters as a parameter or switch in
`config/scenario_params.yaml` (with `_status` and `_source` siblings and an
entry in `.REQUIRED_PARAM_KEYS`) whose **legacy value reproduces v1.0.1**.
Two named settings sit on top:

- `legacy_v1_0_1`: every switch at its Version 1 value. A regression test
  requires this setting to reproduce `results/v1.0.1/` exactly on the real
  vintage (server) and the current fixture outputs in CI.
- `v1_2_reference`: the Version 1.2 choices.

Changes land one rung at a time, in the order below, and each rung records
its revenue effect against the previous rung. The result is a bridge table
from v1.0.1 to v1.2 for every headline cell, built the same way as the
erratum's A/B/C/D runs (`code/erratum_v1_0_1_export.R`). Readers of the
Version 1.2 release will want to see which change moved the number.

## Workstreams

### A. Mapping the shock

**A1. Baseline path (D6, baseline source SET).** Replace the fixed
`shock.baseline_labor_share` (0.555, today's share) and the CBO growth keys
with annual paths from `Budget-Lab-Yale/Macro-Projections`
(`projections.csv`, the vintage Tax-Simulator reads). The share change is
measured against the projected path, which is already drifting for reasons
unrelated to AI. Touches `code/02_params.R` (growth-rate derivation) and the
`cbo_baseline` and `shock` blocks of the yaml.
*Check first:* which Macro-Projections series gives a labor share on the
survey's concept, and what `corp_profits_adj` measures (unverified).

**A2. Nonfarm-business bridge (D1, bridge PROPOSED).** The survey's labor
share is for the nonfarm business sector (BLS series PRS85006173). Apply the
share change to nonfarm business income only and hold the rest of the
economy at its baseline share. The bridge needs the nonfarm business share of
GDP and of factor income on the baseline path. Output: the economy-wide
`g_K` and `g_L` implied by each preset, reported next to the Version 1 values.

**A3. Annual paths for ten fiscal years (D13, horizon SET).** Today the
pipeline scores one year (`baseline_year: 2030`, Tax-Simulator years
`2029:2030`). Version 1.2 scores the ten-year budget window:

- Interpolate the survey's 2025 and 2030 observations into annual paths for
  `g_Y` and the labor share.
- After 2030, a three-way setting: hold the 2030 gap (proposed reference),
  interpolate toward Karger's 2050 values (Tables 20 and 40), or continue the
  2025–2030 excess growth.
- Write one counterfactual tax-unit file per year per scenario
  (`write_counterfactual_scenario()` already writes by year) and run
  Tax-Simulator over the full range. Its fiscal-year adjustment drops the
  first year, so the range starts one year before the window.
- `08` and `09` aggregate by year and fiscal year; the CBO anchors
  (`cit_to_gdp`, `rev_to_gdp`, GDP) become annual series from the same
  baseline.

*Check first:* how long a 10-year grid takes on the cluster (the pinned
Tax-Data vintage `2026050315` has `tax_units_<year>.csv` for 2017–2046,
checked 2026-10-28) (the 18-cell, 54-flavor grid is about 10 minutes for one year).
This is the largest engineering item; budget for it accordingly.

**A4. Generic shock input.** A shock is a table of annual `g_Y` and
labor-share paths with a name. Karger Slow, Moderate, and Rapid become
presets built by the interpolation in A3, and the scenario-axis registry in
`00_utils.R` gains the preset as its variant axis. A user-supplied path
(for example from BLSMM's AI scenarios) is a CSV in the same format.

**A5. Early-evidence check (D13, SET 2026-10-28).** A published validation
exhibit comparing what each scenario implies for the first years of the
window with what is already observable. Observed data never feed the
scenarios; replacing the interpolated 2025–2026 path with observed values
would turn a validation into a calibration. Both sides are measured as
deviations from CBO's February 2026 baseline, the same object every model
output is. Three pieces:

- *Inputs against paths.* Observed nonfarm-business labor share (FRED
  PRS85006173, already pulled in `code/paper_figure_data.R`) and real GDP
  growth for 2025–2026, against each preset's interpolated annual path.
  The cleanest test, since these are the quantities the scenarios assume.
- *Receipts pattern.* FY2026 actual receipts minus the February 2026
  projection (Monthly Treasury Statement, CBO Monthly Budget Review), split
  into withheld individual income tax plus payroll tax (labor side),
  non-withheld individual income tax (gains and pass-through), and
  corporate tax, against the signs the model predicts. The pattern is the
  test, not the level: observed deviations also carry non-AI surprises
  (asset prices, the macro outlook).
- *FY2026 nowcast year.* Tax-Simulator starts in 2025 rather than 2026, so
  FY2026 is scored and reported as a nowcast year outside the ten-year
  headline. Tax-Data `2026050315` has the 2025 file; the cost is about one
  extra year per cell.

### B. The accounting

**B1. Bridge to national income (D3, φ rule SET).** Use the Saez–Zucman
split Version 1 already applies on the tax file (`01_load_data.R`,
`scenario_params.yaml` `passthrough` block) to split proprietors' income in
the national accounts, and name every remaining part of national income
(about 13 percent in 2024: the labor part of proprietors' income, taxes on
production and imports net of subsidies, business transfers, government
enterprise surplus). Each is held at its baseline share of GDP unless a rule
says otherwise. Output: a reconciliation table from GDP to labor
compensation, capital income, and the named residual, by year.
Version 1's flat 0.50 proprietors' split in
`config/calibration/kappa_corp_calculation.csv` never reached results,
because `kappa_corp` and the statutory rate cancel in
`code/04_allocate_capital.R:83-85`. Retire that receipt or relabel it as
documentation.

**B2. A consistent corporate ratio.** The corporate change is
`ΔR_CIT = X · R_CBO / Y0^K`. The deck's issue is that the ratio was computed
on profits without inventory and capital-consumption adjustments but applied
to a base that includes them; done consistently, the 2024 benchmark is about
$442 billion rather than $492 billion. *First task:* locate exactly where
each side of that ratio enters (the calibration receipts and
`validation_benchmarks.csv` versus the live wedge) before changing anything,
and write the receipt.

**B3. Rent and interest on baseline paths.** `y_k` includes `rent_net`,
`estate_net`, and taxable and exempt interest (`01_load_data.R:204`), so the
Version 1 increment grows them with business profits, although most rental
income is imputed rent on owner-occupied housing and most interest comes from
fixed-rate claims. In Version 1.2 they grow on their baseline paths and the
capital increment applies to profit-type income only. *Decision needed:*
whether `g_K` is re-derived on the narrower base (so the dollar increment
from the survey is unchanged) or applied to the narrower base at the same
rate (so it shrinks). The first keeps the survey's capital share intact; it
is the proposed default.

**B4. Corporate incidence in the distribution tables (D12, SET).** The cash
panel stays the lead. A secondary table attributes the corporate change to
households with Tax-Simulator's existing key (`distribution.R:232/484`: the
labor share of the burden phases from zero to 20 percent over ten years).
Version 1 left the corporate change out of the distribution tables
altogether.

### C. Whether AI income faces the average tax rate

**C1. Payout and realization as parameters.** Two parameters replace
hard-coded values:

- payout `p`, the dividend share of the equity increment (Version 1: 0.30 in
  `config/asset_to_income_map.csv`, with 0.70 to long-term gains);
- an AI realization multiplier `m_AI` applied to the gains part of the
  increment (Version 1: 1, every gain realized in-year in `05_realization.R`).

`m_AI` is relative to the baseline realization rate already built into the
reported base, which avoids the double count that `05_realization.R`
warns about. With `m_AI < 1`, the unrealized part is deferred past the window
or stepped up at death. Calibration range: concentrated holders rarely sell
(Gordon, Joulfaian, and Poterba 2016 find unrealized gains were 44 percent of
non-cash assets in large 2010 estates); the range goes in the register.

**C2. A concentrating allocator.** Version 1 allocates the capital increment
in proportion to all-asset wealth. Add a rule that tilts it toward the top
by holdings of business and public equity, calibrated to a target share of
the increment for the top 1 and 0.1 percent (the Fed DFA files are already in
`data/external/fed_dfa/`). The asset-proportional rule stays the default;
the concentrating rule is a preset.

**C3. Corporate-increment sensitivities.** Two shares of the corporate
increment, both zero in Version 1:

- booked abroad or as export income: taxed at 12.6 to 14 percent (NCTI) or
  14 percent (FDDEI) rather than 21 percent;
- paid out as deductible interest: no corporate tax, and taxed at the lender
  only to the extent the lender is taxable.

These scale the wedge; they are sensitivities, not the reference.

### D. Outputs

- Revenue by instrument for each fiscal year in the window and the ten-year
  total, for every preset and labor rule.
- The bridge table from v1.0.1 to v1.2 (one rung per change).
- The national-income reconciliation by year (B1).
- The early-evidence exhibit, including the FY2026 nowcast year (A5).
- Distribution: the cash panel, plus the corporate-incidence table (B4).
- A light parameter register (D14) for the Version 1.2 parameters: value,
  source, range, and revenue at stake, ranked. The full register is a
  Version 2.0 output.
- Figures through the new chart pipeline (separate plan).

### E. The output layer (SET 2026-10-28)

The outputs are used only internally, so Version 1.2 redesigns them rather
than adding a year dimension to the Version 1 layout. Version 1 writes
about 125 files at five levels: counterfactual tax-unit files and the
`factor_channels` sidecar inside the shared Tax-Data vintage (54 folders,
overwritten in place); the runscript and its `_macro` and `_cell_params`
sidecars inside the Tax-Simulator repository; the Tax-Simulator output tree
(about 23 GB per run); 12 aggregate CSVs with mixed grain, no year column
and no run identifier; and five presentation products (two workbooks, 35
PNGs in two copies, `figure_data`, `paper_figure_data`, and the website
CSVs reshaped by hand). The same headline number is stored up to five
times, and nothing in this repository records which Tax-Simulator commit or
run produced a workbook.

**E1. Run store.** Split 2026-10-28: **E1a (run directory) done in rung
0** (`code/00_run_store.R`); **E1b (long-format tables) and E2 move to
rung 4**, because the ten-year window changes every table and figure
anyway. E1a keeps the v1.0 table and workbook layouts in `tables/`, so the
legacy reproduction test compares files directly against the erratum's
run D. Each run writes `results/runs/<run_id>/` (`run_id` =
`<setting>-<stamp>`, the stamp also being the Tax-Simulator output
vintage):

- `manifest.yaml`: setting, status, AI-Fiscal and Tax-Simulator commits
  (and whether Tax-Simulator was patched), Tax-Data vintage, years, timing
  (Macro-Projections vintage from rung 1);
- `inputs/`: merged parameters (`params.yaml`), copies of the retirement
  calibration and asset map, the runscript and its per-cell and
  per-variant sidecars (no longer written into the Tax-Simulator
  repository), and the local Tax-Simulator changes (`src/` patches
  and dependency vintages);
- `tables/` (E1b, rung 4): long-format CSVs (revenue, income, distribution,
  reconciliation, ...) sharing one key: run, variant, share mode, labor
  rule, realization, flavor (both / labor only / capital only), calendar or
  fiscal year, measure, value, unit. Labels are decoded once from the axis
  registry in `00_utils.R`.

CSV rather than parquet: the tables are small, and the cluster's personal
Arrow build lacks zstd. Run directories are gitignored except for tagged
releases; `results/v1.0.1/` and `results/erratum_v1.0.1/` become run
directories (the erratum's run D is the reference for the legacy test).
Timestamped workbook copies stop.

**E2. Views.** Everything presented is rebuilt from the run store: one
internal workbook (the analyst and publishable workbooks merge), the
website `data.csv` files (figure pipeline F1 reads the store), the BLSMM
handoff, and the bridge table, which becomes a query across runs. The
ggplot suite shrinks to the diagnostics we use; the published figures come
from the chart engine. The figure set itself will change substantially
with the move from one year to ten (every Version 1 figure is a 2030
cross-section), so which published and diagnostic figures exist is
decided from the ten-year outputs (figure plan F5), not in rung 0.

**E3. Large intermediates in scratch — done in rung 0** (except writing
each capital-only file once, which moves to rung 4). Counterfactual tax-unit files are
reproducible (no random draws in `03`–`06`; the manifest records the code,
vintage, and setting), so they move to
`$TAXSIM_LOCAL_ROOT/ai_fiscal/<run_id>/tax_data/<scenario>/`, with the
runscript and the Tax-Simulator output tree beside them (Tax-Simulator's
local mode already writes there). Tax-Simulator only reads inputs from
`<production root>/model_data/Tax-Data/v1/<vintage>/<ID>`
(`src/misc/config_parser.R:56-63`), so:

- *Now:* the shared vintage gets one run-specific symlink per scenario,
  `aif-<run_id>--<scenario_id>` pointing into scratch, set as
  `dep.Tax-Data.ID`; the Tax-Simulator scenario `ID` stays
  `<scenario_id>`. Runs cannot overwrite each other, and the links are
  removed after the run. Works with both the `256f03ea9` pin and current
  Tax-Simulator.
- *Later:* propose an input-root override upstream (for example a
  `dep.Tax-Data.root` runscript column) with the three local patches
  (`B6`); switch when rung 4 fixes the window's Tax-Simulator pin.

Retention: counterfactual files are deleted once Tax-Simulator finishes,
and the Tax-Simulator tree once the run's tables are written and checked;
a flag keeps them for debugging. Scale: a 2025–2036 run is about 126 GB of
counterfactual files and roughly 250 GB of Tax-Simulator output; scratch
is purged on inactivity, so the run store is the permanent record. After
the v1.0.1 checksums are taken, the 54 v1.0.1 scenario folders in the
shared vintage (about 10 GB) can be removed.

Done with E3: `tax_sim_output_root()` falls back to `TAXSIM_LOCAL_ROOT`
when `output_roots.yaml` has no `local:` key (current Tax-Simulator); every
pipeline read of parameters after `02` uses the run's `inputs/params.yaml`
(the `parameter_index` and `key_parameters` sheets, the CBO baseline in
`09`'s revenue-to-GDP table, and the Karger growth rates in `15`);
`run_release.sbatch` requires `TAX_SIMULATOR_DIR` instead of falling back
to a sibling checkout. `code/paper_figure_data.R` still reads the base
yaml; it is a standalone post-processor whose exhibits are replaced in
rung 4.

## Order of work

Each rung ends with tests passing, the legacy setting still reproducing
v1.0.1, and the rung's revenue effect recorded.

| Rung | Work | Runs on |
|---|---|---|
| 0 | Switch scaffolding, `legacy_v1_0_1` and `v1_2_reference` settings; output layer E1–E3; regression test against the run store; chart pipeline F0–F2 in parallel | laptop + CI, then server |
| 1 | A1 baseline path, A2 nonfarm bridge (2030 only) — **DONE 2026-10-28** | laptop, then server |
| 2 | B1 reconciliation, B2 corporate ratio, B3 rent and interest — **DONE 2026-10-28** | laptop, then server |
| 3 | C1 payout and realization, C2 allocator, C3 sensitivities — **DONE 2026-10-28** | laptop, then server |
| 4 | A3 annual paths and A4 generic shock input (ten fiscal years); A5 early-evidence check — **DONE 2026-10-28** | server |
| 5 | B4 incidence table, register, outputs, figures; methodology doc and CHANGELOG | server + laptop |

Rungs 1–3 stay single-year (2030) so each effect is comparable to the
published numbers. The ten-year window comes last because it multiplies run
time and changes every output's shape.

**Rung 0 choices (SET 2026-10-28).**

- *Settings are overlays.* `config/scenario_params.yaml` stays the legacy
  file; each rung adds its new keys there at their Version 1 values.
  `config/settings/v1_2_reference.yaml` lists only the keys that differ,
  each tagged with its rung. `legacy_v1_0_1` has no overlay file: it is
  the base yaml by definition, so no file exists that could drift.
  `load_params()` gains a `setting` argument, merges before key
  validation, and aborts on an overlay key absent from the base; the
  orchestrator gains `--setting`. `08_aggregate.R:628` and
  `09_tables_figures.R:944` re-read the yaml from disk and must take the
  merged parameters instead (superseded by the manifest once E1 lands).
- *Tax-Simulator pin.* Rungs 0–3 run on `256f03ea9` plus the three local
  patches, the build that produced v1.0.1; rung 4 fixes the window's pin,
  and any change of pin is its own rung in the bridge.
- *v1.0.1 counterfactual checksums — DONE 2026-10-28.* The 108 files
  (54 `tax_units_2030.csv` + 54 `factor_channels_2030.csv`) in the shared
  Tax-Data vintage, all written in one run on 2026-10-05, are hashed in
  `tests/reference/v1_0_1_counterfactual_md5.csv`. Three cells regenerated
  under `legacy_v1_0_1` into scratch (`ai_M_R_S0_V1_CO`, `ai_M_R_S0_V1`,
  `ai_S_F_S2_V1_LO`) match byte for byte, with `theta1_k = 0.460` for
  Moderate: the files are the B/D (v1.0.1 labor shares) version, and the
  pipeline's counterfactual files are reproducible, as E3 assumes.
  Capital-only files are identical across the three labor rules (12 of
  the 54 are duplicates), so E3 can write one per variant and share mode.
- *Reproduction tests, three layers:* (1) derived parameters against the
  `D` column of `results/erratum_v1.0.1/comparison/cell_params_2030.csv`
  (CI; DONE in `tests/testthat/test-params.R`); (2) the full legacy grid
  built through the run store on the real vintage: all 108 counterfactual
  files against the v1.0.1 checksums, per-cell macro parameters and
  `parameter_index` against run D (DONE 2026-10-28, job 31161818:
  `tests/server/legacy_inputs.sbatch`, about 5 minutes, re-run at every
  rung); (3) a full legacy run whose tables match run D's aggregates within
  a relative tolerance of 1e-9 (DONE 2026-10-28, job 31177402:
  `tests/server/legacy_full.sbatch` + `tests/server/compare_run_tables.R`,
  12 of 12 tables match; 10m42s on 16 cores, peak job memory 99 GB of the
  128 GB requested). "Reproduces exactly" means layer 3, since workbooks
  carry timestamps. The comparison was validated on the erratum's own runs
  (D vs D passes; B vs D fails on exactly the five tables carrying the
  macro corporate tax, the only thing B and D differ in).
- *Wealth-Tax-Simulator vintage substitution.* The `256f03ea9` pin's default
  Wealth-Tax-Simulator vintage `2025011312` was deleted from the shared
  filer on 2026-10-24 (no snapshot predates it). Tax-Simulator at that
  commit only checks the folder exists (`src/misc/config_parser.R:201`) and
  never reads it, so the pin worktree points it at `2025032414`; layer 3
  passing confirms the substitution changes no result. The edit is
  recorded in each run's `inputs/tax_simulator_local.diff`. Old dependency
  vintages on the shared filer are not guaranteed to persist.

**Rung 1 choices (2026-10-28).** Three switches in the base yaml, each at
its v1.0.1 value there; two take a new value in
`config/settings/v1_2_reference.yaml`:

| Switch | v1.0.1 | Version 1.2 | Plan item |
|---|---|---|---|
| `cbo_baseline.growth_path` | `flat`: 2.2% in 2026, then 1.8% a year | `annual`: CBO's calendar-year real GDP path | A1 |
| `shock.share_baseline` | `survey_2025`: 0.555 | unchanged, `survey_2025` (SET 2026-10-28); `projected` (0.555 plus CBO's 2025→2030 drift in compensation / GDP) is a sensitivity | A1 |
| `shock.sector` | `whole_economy` | `nonfarm_business` | A2 |

- *Data.* Two committed receipts in `config/calibration/`, built by the
  standalone `code/12_baseline_receipts.R`:
  `cbo_2026_02_baseline_path.csv` (CBO February 2026 calendar-year real
  GDP, real nonfarm-business output, nominal GDP, and compensation,
  2025–2036, from CBO's `Economic-Projections.xlsx`, the workbook
  Macro-Projections `2026071916` is built from) and
  `nipa_sector_gva_2025.csv` (BEA 2025 value added by sector, Table 1.3.5,
  and compensation outside nonfarm business, Tables 1.13 and 6.2D).
  Macro-Projections itself starts its income lines and real-GDP index in
  2026, so it cannot supply the survey's 2025 base; its 2026–2036 values
  match the receipt exactly. Both receipts are copied into each run's
  `inputs/`.
- *Answers to A1's "check first".* No Macro-Projections or CBO series is a
  labor share on the survey's concept (the BLS nonfarm-business share).
  CBO's production function holds the nonfarm-business capital share at
  0.329 in every year, and its income projections give compensation /
  GDP, which drifts from 0.5137 (2025) to 0.5145 (2030), +0.08 points. The
  `projected` option adds that drift to the survey's 0.555, so 0.5558 in
  2030. The reference keeps 0.555 (no drift), consistent with CBO's
  production function; the drift is small (+$9B of `X` for Moderate) and
  rests on a proxy for the survey's concept. `gdp_corp` is NIPA corporate profits with inventory valuation and
  capital consumption adjustments (the CBO row
  "Profits, corporate, with IVA & CCAdj"); it bears on B2, not rung 1.
- *Shares, not changes.* The survey's 2030 share is a level, compared with
  the baseline share in 2030, the same way `g_y` compares Karger's growth
  with the CBO path. With no projected drift, that baseline share is the
  2025 share.
- *The `annual` growth path* uses calendar-year real GDP: 2.36% in 2026
  (CBO's 2.2% is fourth quarter to fourth quarter), 1.75–1.86% after. The
  cumulative 2025→2030 baseline growth rises from 9.75% to 9.94%, so
  `g_y` falls by about 0.17 points in every preset.
- *The bridge (A2).* Nonfarm business is 76.3% of 2025 GDP (BEA), moved to
  77.3% in 2030 by CBO's faster projected growth of real nonfarm-business
  output than of real GDP. Outside nonfarm business, the labor share is
  employee compensation over value added: 0.530 (government 77%, nonprofit
  institutions 82%, households including owner-occupied housing about 1%,
  farms 21%; farm proprietors' labor is not imputed). The economy-wide
  baseline labor share is then 0.550, and the share shift for Moderate is
  −1.21 points rather than −1.50. Formulas are in `code/02_params.R`'s
  header; `cell_params` gains `theta_0_L_economy`, `theta_1_L_economy`,
  and `nfb_gva_share`.
- *Effect on the derived growth rates* (2030, reallocated shares; X uses
  the 2030 `y_k` of $4.51T, so it is approximate):

  | Step | Slow `g_k` / `g_l` | Moderate `g_k` / `g_l` | Rapid `g_k` / `g_l` | Moderate X |
  |---|---|---|---|---|
  | v1.0.1 | 1.72% / −0.32% | 7.08% / 0.79% | 15.6% / 0.41% | $319B |
  | + A1 growth path | 1.55% / −0.48% | 6.90% / 0.62% | 15.4% / 0.24% | $311B |
  | + A1 share baseline | 1.73% / −0.62% | 7.09% / 0.48% | 15.6% / 0.10% | $320B |
  | + A2 nonfarm bridge | 1.42% / −0.39% | 6.20% / 1.13% | 13.6% / 1.58% | $280B |
  | Reference (A1 growth path + A2, no share drift) | 1.28% / −0.28% | 6.06% / 1.24% | 13.4% / 1.69% | $273B |

  A2 is the large step: the capital increment falls by about an eighth and
  labor income grows more, because all of the excess growth lands in
  nonfarm business, where labor still takes 54% of it.
- *Revenue effect of rung 1* (FY2030 change in federal revenue including
  the macro corporate tax, $ billions; run
  `results/runs/v1_2_reference-202610281825/`, job 31200709, against the
  layer-3 legacy run `legacy_v1_0_1-202610281529`; same Tax-Simulator pin):

  | Cell | v1.0.1 | Version 1.2 rung 1 | Change |
  |---|---|---|---|
  | Moderate, reallocated, proportional (headline) | 113.3 | 118.7 | +5.5 |
  | Rapid, reallocated, proportional | 200.8 | 224.1 | +23.3 |
  | Slow, reallocated, proportional | 8.0 | 4.3 | −3.8 |
  | Moderate, fixed, proportional | 179.4 | 171.6 | −7.8 |

  Under reallocated shares revenue rises for Moderate and Rapid although
  `X` falls by about a seventh: the bridge moves income from capital to
  labor, which carries payroll tax and here also raises individual income
  tax (Rapid: income tax +$16.8B, payroll +$15.2B, corporate −$10.3B).
  Fixed-share and Slow cells fall by $3–9B, mostly the 0.17-point lower
  `g_y` from the annual growth path. The same pattern holds across the
  three labor rules. Run time 11m on 16 cores, peak memory 99 GB. (An
  earlier run with the share drift, job 31196091, gave 116.1 for the
  headline.) Layer 2 still passes after the rung (job 31196090): 108 of 108
  files, cell parameters, and run D's `parameter_index` rows unchanged.

**Rung 2 (2026-10-28).** B1–B3 as decided on 2026-10-28: B3 as a switch,
B2 as documentation, B1 as an output table.

- *B2: the corporate ratio.* The deck's $442B vs $492B inconsistency is in
  the retired `cit_avoidance_calculation.csv` (14.7% = receipts over profits
  without IVA/CCAdj, applied to a base with them) and in the Version 2
  proposal; no model step reads it. The live change is
  `ΔR_CIT = X · CBO_CIT / Y0^K = g_k · CBO_CIT` (`kappa_corp` and
  `cit_statutory` cancel), so the corporate tax grows at the rate of
  tax-unit capital income. Kept, with the full `Y0^K` denominator after B3
  (narrowing it would add about 16% by definition alone). Written up in
  `config/calibration/README.md`.
- *B3: interest on its baseline path.* New switch `capital_flow.interest`:
  `by_holdings` (v1.0.1; the bond slice of each unit's `X_i` becomes
  interest) or `baseline_path` (reference; the bond slice goes to the
  unit's equities, pass-throughs, and retirement). Rent and estate income
  never received `X` (no real-estate class), so only interest moves:
  about $16B of Moderate's $273B. `X` keeps its dollar size (decision 2).
- *B1: national-income reconciliation.* `code/14_reconciliation.R`, called
  by `09`, writes `national_income_reconciliation_<year>.csv`: for each
  variant and share mode, GDP in the policy year split into labor
  (compensation, proprietors' labor), capital (corporate profits,
  proprietors' capital, rental income, net interest, government
  enterprise surplus), and the rest of GDP (depreciation, production
  taxes less subsidies, business transfers, statistical discrepancy), at
  baseline and under the shock, next to tax units' labor and capital
  income. Baseline shares are BEA's 2025 income side of GDP (Table 1.10,
  added to `nipa_sector_gva_2025.csv`); proprietors' income is split with
  the tax file's Saez–Zucman capital share on the national-accounts
  coverage (sole proprietorships, farms, partnerships: 0.165), new in
  `cell_params` as `proprietors_capital_share`. Rules for the change: the
  rest of GDP holds its share of GDP; labor grows at `g_l`; rent, net
  interest, and government enterprises stay on their baseline paths; the
  remainder goes to corporate profits and proprietors' capital. Moderate,
  reallocated, 2030 ($B): GDP +1,288; labor +265; corporate profits +653;
  proprietors' capital +62; rest of GDP +299. Tax units carry +194 of
  labor income and +273 of capital income (`X`): about 38% of the
  profit-type increment. For scale, applying CBO's ratio of corporate
  receipts to domestic profits (about 12.8% in 2030) to the +653 would give
  about $83B of corporate tax, against the model's $28.9B; that gap is the
  Version 2.0 question of sizing the shock in the national accounts.
- *Revenue effect of rung 2* (run `v1_2_reference-202610281847`, job
  31204272, against rung 1's `v1_2_reference-202610281825`): headline
  118.7 → 118.2 ($B, −0.5); Rapid reallocated proportional 224.1 → 223.0;
  fixed-share cells −0.04 to −0.57. All of it is individual income tax
  (interest moved to dividends, gains, pass-through, and retirement
  income); payroll and corporate are unchanged. Layer 2 passes (job
  31204271), now listing `capital_flow.interest` as an added key.
- *Allocation base (decided 2026-10-28).* New switch
  `capital_flow.allocation_base`: `all_assets` (v1.0.1: every SCF asset
  column except DB pensions) or `ex_home_cash_nonfin` (reference: also
  without the primary residence, cash, and `other_nonfin`, which is
  vehicles plus the SCF's other nonfinancial assets). Each unit's share of
  `X` follows its wealth in the base. Moderate, 2030: the base falls from
  $242T to $164T; the share of it in assets that cannot receive income
  directly falls from 45% to 19%; the flow to retirement accounts falls
  from $117.7B to $90.6B, to equities rises from $91.6B to $105.1B, to
  pass-throughs from $63.9B to $77.5B; units with no income-bearing
  holdings, whose share defaults to retirement, fall from 67M carrying
  $18.3B to 16M carrying $3.9B. Revenue barely moves (run
  `v1_2_reference-202610281936`, job 31212180): headline 118.24 → 118.10
  ($B), Rapid reallocated proportional 222.95 → 222.29, every cell within
  $0.8B, all of it individual income tax. The change is mainly in who
  receives the flow, not how much of it is taxed.
- *The rest of the base is treated as financial wealth.* The remaining
  columns that cannot receive the flow directly keep their place in the
  base, and their share goes to the unit's equities, pass-throughs, and
  retirement accounts (bonds too under `by_holdings`). This includes
  `other_home` (second homes and residential rentals held directly, SCF
  `ORESRE`) and `re_fund` (equity in nonresidential real estate, SCF
  `NNRESRE`), treated as investment assets (decided 2026-10-28), so their
  AI return is reported as the unit's financial income rather than as
  Schedule E rent. Where each column's income would be reported, for
  reference (Moderate's approximate share of `X` under the new base):

  | Column | Reported as | Share of `X` |
  |---|---|---|
  | `other_home` | Schedule E rents (rentals); Schedule D gains incl. §1250 on sale | ~$21B |
  | `re_fund` | Schedule E rents; Schedule D or Form 4797 gains | ~$9B |
  | `trusts` (trusts, managed accounts) | Owner's dividends, interest, gains (grantor trusts, managed accounts); Schedule E part III (other trusts) | ~$12B |
  | `other_fin` (loans to others, royalties, deferred pay, private stock) | Interest, royalties (Schedule E part I), other income, gains | ~$4B |
  | `life_ins` (cash value) | Nothing until surrender (line 5); tax-free at death | ~$3B |
  | `annuities` | Taxable part of payouts on line 5 | ~$2B |

  Life insurance and annuities share the retirement accounts' timing
  issue: their income is deferred, but the model reports it now. That is
  taken up with the retirement step below.
- *Open: the retirement step* (`04_allocate_capital.R`,
  `apply_retirement_cascade_R1`). The retirement slice of `X` is pooled
  and paid in full this year as taxable pension and IRA distributions to
  the units now taking distributions, by retirement wealth; 57% of it
  starts with units that take none. Candidates: route the residual
  across units with income-bearing holdings rather than to retirement;
  a sensitivity that taxes only the withdrawal share in-year (`r_R` =
  4.9% of balances). D11 assigns retirement balances to Version 2, so
  any change here is a scope decision.

**Rung 3 (2026-10-28).** C1–C3 as parameters, all at their v1.0.1 values
in the base yaml and in the reference (decision 4); the sensitivities are
settings that inherit the reference (`inherits:`, new in `02_params.R`).

- *C1.* `capital_flow.payout` (0.30, moved from
  `config/asset_to_income_map.csv`, whose public-equity rows now point to
  it) and `capital_flow.ai_gains_realized` (`m_AI`, 1), which scales the
  in-year AI gains in `05_realization.R`; the unrealized part reaches no
  tax base.
- *C2.* `capital_flow.allocator`: `proportional` (v1.0.1, reference) or
  `concentrating`, which scales up the allocation-base wealth of the top
  1% and top 0.1% of tax units by net worth so they receive
  `concentration_top1` = 0.514 and `concentration_top01` = 0.258 of `X`
  (the DFA 2025Q4 shares from decision 4, weighted by the vintage's equity
  and pass-through holdings). Ranking is by net worth (all SCF assets
  except DB pensions, less liabilities): top 1% above $15.7M, top 0.1%
  above $77.6M in 2030. The proportional allocator already gives those
  groups 46.3% and 19.1% of `X`, so the calibrated tilt is mild. The
  vintage is more concentrated than the DFA: its top 1% hold 58% of
  equities and 63% of pass-through equity, against the DFA's 50% and 53%.
- *C3.* `corporate.share_abroad` (taxed at `abroad_rate` 0.14 rather than
  0.21), `corporate.share_interest` (deductible interest, no corporate
  tax; the lender side is not modeled), both 0. They scale the
  off-microsim corporate change, so their effect is exact without a run.
  Moderate reallocated (corporate change $28.9B): 25% abroad −$2.4B; 25%
  as interest −$7.2B; both at 25% −$9.6B. Rapid ($64.2B): −$5.4B, −$16.0B,
  −$21.4B.
- *Paired sensitivities (decision 4)*, FY2030 revenue including the
  corporate tax ($B), reallocated shares (jobs 31215042, 31215557,
  31215716, 31215720; runs `v1_2_sens_concentrated*-20261028*`):

  | Cell | Reference | Concentrating, `m_AI` = 1 | 0.75 | 0.5 | 0.25 |
  |---|---|---|---|---|---|
  | Moderate, proportional (headline) | 118.1 | 119.2 | 116.0 | 112.8 | 109.7 |
  | Rapid, proportional | 222.3 | 224.7 | 217.8 | 210.7 | 203.7 |
  | Slow, proportional | 4.1 | 4.3 | 3.7 | 3.0 | 2.4 |
  | Moderate, fixed shares | 171.3 | 171.8 | 170.1 | 168.3 | 166.6 |

  Concentration alone adds about $1B (higher rates at the top); each 0.25
  step in `m_AI` takes about $3.2B off the headline and $7B off Rapid.
  The pattern holds under the other labor rules. Layer 2 passes after
  the rung (job 31215041).
- *Run stamps.* Runs that start in the same minute share a stamp and so a
  Tax-Simulator output folder (`<root>/<stamp>/`), which cleanup deletes.
  The four sensitivity jobs were staggered by hand; the orchestrator now
  aborts if the folder already exists.

**Rung 4 (2026-10-28).** The ten-year window, annual shock paths, the
retirement step, and the early-evidence check. Decisions (John,
2026-10-28): 2025-2030 paths as below; post-2030 reference holds the 2030
gap; Tax-Simulator pin unchanged (`256f03ea9`, current law as of
2026-07, after the 2025 reconciliation act); retirement fix folded in;
negative `X` scaled down in proportion.

- *Window.* New top-level `window`: `single_year` (v1.0.1) or `annual`
  (reference) over tax years `window_first_year`-`window_last_year`
  (2025-2036). Tax-Simulator runs the whole range; its fiscal-year
  adjustment drops 2025, so tables cover FY2026 (the nowcast year, A5) and
  FY2027-2036 (the window). `08` and `09` run once per fiscal year as
  before (`<table>_<year>.csv`); `code/17_annual_tables.R` stacks them into
  `<table>_by_year.csv` and sums `revenue_grid_wide` over FY2027-2036 in
  `revenue_window_totals.csv`. The figure suite, BLSMM step, and website
  figures stay a view of `baseline_year` (2030) until F5.
- *Shock paths (A3, A4).* `load_params()` takes a `year`. Through 2030 the
  AI growth rate is Karger's `r_ai_annual` against CBO's annual real GDP
  path (2030 unchanged) and the nonfarm-business labor share moves
  linearly from 0.555 (2025) to its 2030 value. After 2030,
  `shock.post_2030`: `hold_gap` (reference: `g_y` and the share stay at
  their 2030 values), `to_2050` (the growth rate moves linearly to
  Karger's 2045-2050 rate in 2050, the share linearly to its 2050 value),
  `continue_growth` (the 2025-2030 rate continues; share held). Karger's
  2050 inputs, Economists column medians from the online appendix
  (`https://www.nber.org/data-appendix/w35046`, dated 2026-04-01; Tables
  19 and 39 match the 2030 inputs): Table 20, 2045-2050 GDP growth
  2.0 / 2.8 / 3.5%; Table 40, 2050 labor share 52.0 / 50.0 / 45.0%
  (Slow / Moderate / Rapid).
- *Slow starts below the baseline.* Karger's Slow growth (2.0%) is below
  CBO's 2026 calendar-year growth (2.36%), so Slow's `g_y` is negative in
  2026-2028 (-0.36% in 2026) and `X` with it (-$7.7B reallocated, -$14.8B
  fixed in 2026). A negative `X` cannot follow wealth (it gave tens of
  thousands of units negative dividends and pension income, which
  crashed Tax-Simulator): `allocate_negative_flow()` scales every unit's
  income in the channels `X` reaches by one rate, `X` over their weighted
  total (-0.13% and -0.26% in 2026).
- *CBO anchors by year.* `config/calibration/cbo_2026_02_budget_path.csv`
  (CBO February 2026 Table 1-1, FY2025-2036: GDP, revenues by source) gives
  each year's corporate receipts / GDP, revenue / GDP, and GDP; the
  single-year window keeps the yaml scalars (identical for 2030).
  `_macro.csv` and `_cell_params.csv` carry a `year` column; readers use
  `read_runscript_sidecar()` to take one year.
- *Capital-only dedupe.* Capital-only files do not depend on the labor
  rule: the first is written and the others are directory links to it in
  scratch (12 fewer files per year).
- *Retirement step.* `capital_flow.residual`: `retirement` (v1.0.1) or
  `spread` (reference: units with no income-bearing holdings receive none
  of `X`; their share is spread over units with such holdings).
  `capital_flow.retirement_flow`: `distributed` (v1.0.1, reference) or
  `deferred` (sensitivity `v1_2_sens_retirement_deferred`): the slice
  accrues to an AI-attributable balance and `r_R` (4.9%) of the balance,
  carried across years, is distributed and taxed each year.
- *The fiscal-year blend.* Tax-Simulator's FY2030 individual income tax is
  about 26% tax year 2029 and 74% tax year 2030. Single-year runs,
  v1.0.1 included, score tax year 2029 at baseline, so their "FY2030"
  carried only about three-quarters of a year's effect. In the annual
  run the Moderate headline for FY2030 is $133.8B against $118.1B in the
  rung-3 reference; most of the difference is this blend (individual
  income tax 85.2 against 72.8, payroll 18.2 against 14.8; corporate is
  computed by fiscal year and unchanged at 28.9). It is its own step in
  the bridge table.
- *Run.* `v1_2_reference-202610282217` (job 31233677): 31 min on 12 cores,
  peak memory 281 GB (16 cores at 192 GB ran out of memory; request 340
  GB), about 233 GB of scratch (96 GB counterfactual files, 137 GB
  Tax-Simulator output), deleted after the run. The pipeline's figure step
  failed on an unfiltered macro read (fixed); figures, BLSMM, and charts
  were finished from the run's tables (`output/rung4/finish_run.R`,
  recorded in its manifest). Layer 2 passes after the rung (job
  31223058).
- *Results, reference* ($B, change in federal revenue including the
  corporate tax, reallocated shares, proportional labor rule):

  | Preset | FY2026 | FY2027 | FY2030 | FY2036 | FY2027-2036 |
  |---|---|---|---|---|---|
  | Slow | -18.1 | -20.8 | 1.1 | 1.5 | -31.6 |
  | Moderate | 1.7 | 24.1 | 133.8 | 173.3 | 1,259.8 |
  | Rapid | 19.8 | 64.7 | 249.6 | 317.1 | 2,364.0 |

  Fixed shares, FY2027-2036: Slow 200.4, Moderate 1,982.1, Rapid 4,121.7.
  Under the compressive and expansive labor rules the Moderate totals are
  1,016.5 and 1,516.8 (reallocated).
- *Early evidence (A5).* `code/18_early_evidence.R <run dir>` writes
  `early_evidence_inputs.csv` and `early_evidence_receipts.csv` from a
  dated snapshot (`config/calibration/early_evidence_observed.csv`,
  FRED and the Monthly Treasury Statement, retrieved 2026-10-28; CBO's
  site blocks scripted downloads). First half of 2026 against the first
  half of 2025: the nonfarm-business labor share index fell 3.2%, against
  paths of -0.2% (Slow), -0.5% (Moderate), -1.3% (Rapid) and 0 in CBO's
  baseline; real GDP grew 2.4%, against CBO's 2.36% and the paths' 2.0 /
  2.6 / 3.3%. FY2026 receipts against CBO's February projection:
  individual income tax +$94B (non-withheld +9.0% on FY2025, withheld
  +5.6%), payroll -$14B, corporate -$23B; the model's FY2026 changes are
  small (Moderate +0.8, -1.9, +3.0; Rapid +12.0, -0.7, +8.5), so the
  observed deviations are mostly not AI. Signs agree for individual and
  payroll tax under Moderate and Rapid and disagree for the corporate tax.
- *Sensitivities* (FY2027-2036 totals, $B, proportional labor rule; jobs
  31237717-31237719, 29-33 min each, peak 278-281 GB):

  | Cell | Reference (hold gap) | Deferred retirement | Post-2030 to 2050 | Post-2030 continue growth |
  |---|---|---|---|---|
  | Slow, reallocated | -31.6 | -61.4 | 131.5 | 307.9 |
  | Moderate, reallocated | 1,259.8 | 1,111.9 | 2,313.1 | 2,525.2 |
  | Rapid, reallocated | 2,364.0 | 2,029.7 | 4,328.7 | 4,765.8 |
  | Moderate, fixed | 1,982.1 | 1,900.9 | 3,310.5 | 3,268.5 |

  The post-2030 rule is the largest single choice in the window: holding
  the 2030 gap puts Moderate's FY2036 change at $173B against $506B
  (to 2050) and $571B (continue). Deferring the retirement slice lowers
  the ten-year totals by 12% (Moderate) and 14% (Rapid), less than the
  slice's size suggests because the AI-attributable balance builds up and
  its distributions grow over the window.

Full runs need the cluster; the laptop cannot reach it over ssh, so work moves
between machines through pushes to this branch.

## Decisions

Decisions 1–4 were settled by John on 2026-10-28; 5 is still open.

1. **A2 bridge method — SET.** The survey's labor-share change applies
   within nonfarm business only; other sectors stay at their baseline
   shares. All of Karger's excess GDP growth is placed in nonfarm business,
   consistent with how CBO frames its own AI assumption. Nonfarm business is
   roughly three-quarters of GDP (to be pulled from BLS in rung 1), so the
   economy-wide share shift is about a quarter smaller than in Version 1.
   The Version 1 whole-economy rule remains the `legacy_v1_0_1` value.
2. **B3 base — SET.** Re-derive `g_K` on the profit-type base so the
   survey-implied dollar increment `X` is unchanged; taking rent and
   interest out moves `X` into dividends, gains, and pass-through income
   rather than shrinking it. For scale, the 2030 `y_k` on the real vintage
   is $4.51T: retirement distributions 49%, gains 13%, pass-through capital
   13%, dividends 12%, interest 10%, rent and estate 4%. Because `X` is held
   in dollars, how retirement distributions are classified does not move
   its size (retirement stays as in Version 1, D11). Interaction with B2 to
   resolve there: if the corporate ratio's `Y0^K` denominator also narrows,
   the corporate increment rises by about 16 percent.
3. **A3 window — SET.** FY2027–2036, the CBO February 2026 budget window.
   Frozen vintages: Macro-Projections `2026071916` (built on the February
   2026 outlook), Tax-Data `2026050315` (as v1.0.1, so the legacy setting
   still reproduces; it carries tax-unit files for 2017–2046), and a pinned
   Tax-Simulator commit at current law. Tax-Simulator runs 2025–2036: the
   window plus the dropped first year plus the FY2026 nowcast year (A5).
   The gap between what each scenario implies for the early years and what
   is already observable is a published validation exhibit (A5): inputs
   against paths, the FY2026 receipts pattern, and the nowcast year. A
   monthly FY2027 tracker was considered and not adopted.
4. **C1 `m_AI` and C2 concentration — SET: sensitivities, paired.** The
   reference keeps `m_AI = 1` and the asset-proportional allocator, which
   are internally consistent: with proportional allocation the holders of
   AI gains look like today's holders, whose realization rate is already in
   the base. The sensitivities pair the concentrating allocator (targets
   anchored on the Fed DFA, 2025 Q4: top 1 percent hold 50 percent of
   corporate equities and mutual funds and 53 percent of private
   businesses; top 0.1 percent 24 and 28 percent) with `m_AI` in
   {0.75, 0.5, 0.25}.
5. **Release form — OPEN.** A new article for Version 1.2 or an update to the
   existing one. This determines the chart collection slug, which is
   permanent once published. Needed before figure step F5.
