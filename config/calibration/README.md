# Corporate parameter calibration — `kappa_corp`

Snapshot of the NIPA-anchored calibration pass for
`config/scenario_params.yaml::corporate.kappa_corp`. The CIT delta on
the AI flow is anchored by a single runtime-calibrated scale factor
`eta_corp` (see `04_allocate_capital.R::compute_macro_targets`) that
fits the simulated baseline-year CIT to CBO's published level.
`eta_corp` absorbs both the corporate-avoidance wedge and the gap
between the microsim's household-realized capital income and the
pre-realization NIPA corporate base.

## Files

- `nipa_2024_z1_f3.csv` — raw national-income-by-type inputs (Federal
  Reserve Z.1 Distribution of National Income, Table F.3) plus NIPA
  corporate profits before tax and federal CIT receipts.
- `kappa_corp_calculation.csv` — derivation of `kappa_corp` from the
  NIPA decomposition. Narrow (S-corps stripped from numerator) and
  inclusive (BEA convention) variants laid out so the chosen value is
  reproducible.
- `cit_avoidance_calculation.csv` — **historical documentation only.**
  Derivation of the retired standalone `cit_avoidance` parameter
  (superseded by the runtime-calibrated `eta_corp`). Kept because the
  NIPA effective-rate arithmetic remains a useful cross-check on
  `eta_corp`'s magnitude. Ported from the archived internal development tree 2026-06-11.
- `validation_benchmarks.csv` — published benchmarks used by
  `code/11_validation.R` to spot-check the pinned vintage against
  CBO/Treasury (federal IIT, CIT, payroll, total revenue), IRS SOI
  (component income on individual returns), Federal Reserve Z.1 / DFA
  (national income, household net worth), and SCF (top-1% / top-10%
  wealth and stock shares). One row per benchmark with source URL.

## Adopted values

| Parameter | Value | Tier | Sensitivity range |
|---|---|---|---|
| `kappa_corp` | 0.50 | Preliminary (NIPA-anchored) | [0.45, 0.65] |
| `cit_statutory` | 0.21 | Sourced (TCJA IRC §11) | — |
| `eta_corp` | Derived at runtime | Calibrated to CBO baseline | — |

`kappa_corp = 0.50` adopts the **narrow** C-corp share definition:
S-corp profits (~20% of BEA's "corporate profits with IVA & CCAdj"
line) are stripped from the numerator because S-corps do not pay CIT.
This is conceptually correct because `04_allocate_capital.R` routes
`passthrough_equity` flow (S-corp + partnership) separately from the
`kappa_corp` wedge.

`eta_corp` is derived per (variant, share_mode) cell from the
microsim's baseline aggregate capital income `Y0^K$` so that
`tau_cit * (Y0^K$ * kappa_corp) / eta_corp` equals CBO's baseline-year
CIT level. The AI CIT delta then equals
`tau_cit * (X * kappa_corp) / eta_corp`, which algebraically reduces
to `X * CBO_CIT$ / Y0^K$`.

## Sources

- Federal Reserve Z.1 (Financial Accounts of the United States),
  Table F.3 — Distribution of National Income, Q4 2024 release
  (March 13, 2025): <https://www.federalreserve.gov/releases/z1/20250313/html/f3.htm>
- BEA NIPA Table 1.12 — National Income by Type of Income (corporate
  profits before tax, taxes on corporate income).
- GAO-23-105384 — *Corporate Income Tax: Effective Rates Before and
  After 2017 Law Change*, December 2022:
  <https://www.gao.gov/products/gao-23-105384>
- JCT JCX-48-24 — *Estimates of Federal Tax Expenditures for Fiscal
  Years 2024-2028*: <https://www.jct.gov/publications/2024/jcx-48-24/>
- IRS SOI corporation statistics — used for the S-corp ~20% share of
  BEA corporate profits assumption:
  <https://www.irs.gov/statistics/soi-tax-stats-corporation-tax-statistics>

## Validation usage

Run `Rscript code/11_validation.R` from repo root to compare the active
baseline-year tax-units file against `validation_benchmarks.csv`. The
script prints a table with absolute and percent differences plus a
pass / flag / skip status (default tolerance 10%). Optional flags:

- `--year <Y>` — override the year (default: `baseline_year` from
  `scenario_params.yaml`).
- `--receipts <path>` — point to a Tax-Simulator `receipts.csv` so the
  script can also compare federal IIT and CIT against CBO/Treasury
  benchmarks (otherwise those rows auto-skip).
- `--tol <frac>` — adjust the pass tolerance (default 0.10).

The script is non-fatal: it always prints a table. Treat "flag" rows as
calibration follow-ups rather than build breaks. Year-of-data caveats
are documented per benchmark in the CSV's `notes` column.

## To revisit

- The S-corp share of BEA corporate profits is rounded to 20% based on
  IRS SOI; refine to a per-year value once SOI 2023 corporate complete
  report is available.
- The `proprietors_capital_share = 0.50` assumption inherits the
  Smith-Yagan-Zidar 2019 passthrough split; revisit if `passthrough.*`
  parameters move.
- For AI-specific kappa_corp, software/IP capital is more concentrated
  in C-corps than the population average; the high-end sensitivity
  (0.65) is a placeholder for that adjustment and should be refined
  with sectoral data (BEA fixed-asset accounts by industry × legal form).
- `validation_benchmarks.csv`: refine the `iit_total_2030` /
  `cit_total_2030` rows once CBO's Feb-2026 supplemental revenue tables
  are loaded (currently interpolated from the 2027–2036 averages).
  Flesh out per-asset DFA aggregates (equities, retirement, private
  business) once Q4 2024 raw figures are pulled.
- The SOI 2022 benchmarks use a tax-base income concept and should be
  compared against the microsim's *aged* aggregates after rescaling for
  CBO economic projections; year-of-data caveat applies — interpret
  flags as roughly directional rather than as exact pass/fail.
