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

*Check first:* that the pinned Tax-Data vintage has `tax_units_<year>.csv`
for every year in the window, and how long a 10-year grid takes on the
cluster (the 18-cell, 54-flavor grid is about 10 minutes for one year).
This is the largest engineering item; budget for it accordingly.

**A4. Generic shock input.** A shock is a table of annual `g_Y` and
labor-share paths with a name. Karger Slow, Moderate, and Rapid become
presets built by the interpolation in A3, and the scenario-axis registry in
`00_utils.R` gains the preset as its variant axis. A user-supplied path
(for example from BLSMM's AI scenarios) is a CSV in the same format.

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
- Distribution: the cash panel, plus the corporate-incidence table (B4).
- A light parameter register (D14) for the Version 1.2 parameters: value,
  source, range, and revenue at stake, ranked. The full register is a
  Version 2.0 output.
- Figures through the new chart pipeline (separate plan).

## Order of work

Each rung ends with tests passing, the legacy setting still reproducing
v1.0.1, and the rung's revenue effect recorded.

| Rung | Work | Runs on |
|---|---|---|
| 0 | Switch scaffolding, `legacy_v1_0_1` and `v1_2_reference` settings, regression test; chart pipeline F0–F2 in parallel | laptop + CI |
| 1 | A1 baseline path, A2 nonfarm bridge (2030 only) | laptop, then server |
| 2 | B1 reconciliation, B2 corporate ratio, B3 rent and interest | laptop, then server |
| 3 | C1 payout and realization, C2 allocator, C3 sensitivities | laptop, then server |
| 4 | A3 annual paths and A4 generic shock input (ten fiscal years) | server |
| 5 | B4 incidence table, register, outputs, figures; methodology doc and CHANGELOG | server + laptop |

Rungs 1–3 stay single-year (2030) so each effect is comparable to the
published numbers. The ten-year window comes last because it multiplies run
time and changes every output's shape.

Full runs need the cluster; the laptop cannot reach it over ssh, so work moves
between machines through pushes to this branch.

## Decisions needed from John

1. **A2 bridge method**: share change within nonfarm business only, with the
   rest of the economy at baseline (proposed), or another rule.
2. **B3 base**: re-derive `g_K` on the profit-type base (proposed) or apply
   it at the same rate.
3. **A3 window**: which ten fiscal years, and the frozen data and policy
   vintages.
4. **C1 range for `m_AI`** and **C2 target concentration**: reference values
   or sensitivity-only.
5. **Release form**: a new article for Version 1.2 or an update to the
   existing one. This determines the chart collection slug, which is
   permanent once published.
