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

**E1. Run store.** Each run writes `results/runs/<run_id>/` (`run_id` =
setting and timestamp):

- `manifest.yaml`: setting, merged parameters, AI-Fiscal and Tax-Simulator
  commits, Tax-Data and Macro-Projections vintages, years, timing;
- `inputs/`: the per-cell and per-variant sidecars, copied out of the
  Tax-Simulator repository at run time;
- `tables/`: long-format CSVs (revenue, income, distribution,
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

**E3. Large intermediates in scratch.** Counterfactual tax-unit files are
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

Also fix: `code/07_run_tax_sim.R:56` reads a `local:` key that current
Tax-Simulator removed in favor of `TAXSIM_LOCAL_ROOT`.

## Order of work

Each rung ends with tests passing, the legacy setting still reproducing
v1.0.1, and the rung's revenue effect recorded.

| Rung | Work | Runs on |
|---|---|---|
| 0 | Switch scaffolding, `legacy_v1_0_1` and `v1_2_reference` settings; output layer E1–E3; regression test against the run store; chart pipeline F0–F2 in parallel | laptop + CI, then server |
| 1 | A1 baseline path, A2 nonfarm bridge (2030 only) | laptop, then server |
| 2 | B1 reconciliation, B2 corporate ratio, B3 rent and interest | laptop, then server |
| 3 | C1 payout and realization, C2 allocator, C3 sensitivities | laptop, then server |
| 4 | A3 annual paths and A4 generic shock input (ten fiscal years); A5 early-evidence check | server |
| 5 | B4 incidence table, register, outputs, figures; methodology doc and CHANGELOG | server + laptop |

Rungs 1–3 stay single-year (2030) so each effect is comparable to the
published numbers. The ten-year window comes last because it multiplies run
time and changes every output's shape.

**Rung 0 choices (SET 2026-10-28).**

- *Settings are overlays.* `config/scenario_params.yaml` stays the legacy
  file; each rung adds its new keys there at their Version 1 values.
  `config/settings/v1_2_reference.yaml` lists only the keys that differ,
  each tagged with its rung (`legacy_v1_0_1.yaml` is empty).
  `load_params()` gains a `setting` argument, merges before key
  validation, and aborts on an overlay key absent from the base; the
  orchestrator gains `--setting`. `08_aggregate.R:628` and
  `09_tables_figures.R:944` re-read the yaml from disk and must take the
  merged parameters instead (superseded by the manifest once E1 lands).
- *Tax-Simulator pin.* Rungs 0–3 run on `256f03ea9` plus the three local
  patches, the build that produced v1.0.1; rung 4 fixes the window's pin,
  and any change of pin is its own rung in the bridge.
- *v1.0.1 counterfactual checksums first.* Before any run overwrites
  them, record checksums of the 54 scenario folders in the shared
  Tax-Data vintage (written 2026-10-05). Only the Karger labor-share fix
  changes tax-unit files (the CBO-ratio fix acts on the macro CIT wedge
  alone), so these files are either the A/C or the B/D erratum version;
  regenerating under `legacy_v1_0_1` and matching checksums settles which.
- *Reproduction tests, three layers:* (1) derived parameters against the
  `D` column of `results/erratum_v1.0.1/comparison/cell_params_2030.csv`
  (CI); (2) macro targets and counterfactual-file checksums or weighted
  sums (synthetic fixture in CI, real vintage on the server); (3) a full
  legacy run whose tables match run D's aggregates within a relative
  tolerance of 1e-9 (server). "Reproduces exactly" means layer 3, since
  workbooks carry timestamps.

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
