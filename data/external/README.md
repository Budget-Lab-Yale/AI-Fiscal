# External data sources

Public-domain US-government data files used as reference inputs for
the input-side validation diagnostic (`code/11_validation.R`) and
for downstream calibration receipts.

The pipeline itself does not consume these CSV / xlsx files directly;
they are committed so that future contributors can re-derive the
canonical benchmark values in
[`config/calibration/validation_benchmarks.csv`](../../config/calibration/validation_benchmarks.csv)
without re-downloading. Per-benchmark source URLs are tracked in the
`source` and `url` columns of that file.

All sources are in the US public domain. No license restriction
applies. Retrieval was done in the days leading up to the 2026-05-25
initial release commit (`8b5ab04`); refresh by re-downloading from
the source URLs below.

## `fed_dfa/`

**Source.** Federal Reserve Board, Distributional Financial Accounts
(DFA), <https://www.federalreserve.gov/releases/efa/efa-distributional-financial-accounts.htm>.

**Contents.** Quarterly observations of household net-worth components
and shares split by age, education, generation, income decile,
net-worth percentile, and race. For each split: a "levels" file and a
"shares" file, each in both summary and "detail" variants. The
`dfa-data-definitions.txt` file in the directory enumerates the
column conventions.

**How it's used.** `code/11_validation.R` cross-checks the
microsim's per-asset aggregates and top-1% / top-10% wealth shares
against the DFA totals. The specific benchmark rows that pull from
DFA are tagged `*_share_dfa_*` in
`config/calibration/validation_benchmarks.csv`.

**Refresh.** The DFA is released quarterly. To update, download the
zipped CSV bundle from the URL above and replace the directory
contents.

## `soi_pub1304/`

**Source.** IRS Statistics of Income, *Individual Income Tax Returns*
(Publication 1304), tax year 2022 edition.
<https://www.irs.gov/statistics/soi-tax-stats-individual-income-tax-returns-publication-1304-complete-report>.

**Contents.** `22in14ar.xls` is the SOI tabulation from Pub 1304 used
as the source for the `*_soi_2022` benchmark rows in
`validation_benchmarks.csv` (wages, taxable interest, ordinary
dividends, capital gains, sole-prop / Schedule E, pensions, IRA
distributions, taxable social security). The IRS naming convention
is `<year><pub>14<variant>` — here, year `22`, individual returns
(`in`), table 14, all returns (`ar`).

**How it's used.** Input-side validation: weighted aggregates from
the merged PUF + SCF baseline file are compared against the
corresponding SOI line items. See `code/11_validation.R`. Note that
several benchmark rows in `validation_benchmarks.csv` cite a Tax
Foundation summary of Pub 1304 rather than the raw xls — both point
to the same underlying IRS data.

**Refresh.** New tax-year editions are released roughly 18 months
after the filing year. Replace with the latest available edition and
update the `value` and `year` columns of the matching benchmark rows.

## `soi_ira/`

**Source.** IRS Statistics of Income, *Individual Retirement
Arrangements (IRA) Bulletin*, tax year 2022 edition.
<https://www.irs.gov/statistics/soi-tax-stats-accumulation-and-distribution-of-individual-retirement-arrangements>.

**Contents.** `22in01ira.xlsx` is the SOI IRA Bulletin Table 1
(accumulation and distribution of IRAs by type and age group) for
tax year 2022.

**How it's used.** Calibration source for the retirement-cascade
constants in
[`config/retirement_calibration.yaml`](../../config/retirement_calibration.yaml)
($r_R$, $s_P$, $s_I$, $\tau_P$, $\tau_I$ — see §B of
`docs/ai_fiscal_methodology_appendix.md`). Used to build the
67.6% / 32.4% pension-vs-IRA split applied by
`apply_retirement_cascade_R1` in `code/04_allocate_capital.R`.

**Refresh.** Annual release. Replace with the latest edition and
re-derive the calibration constants. The receipt cell-by-cell
derivation should be recorded in `config/calibration/` alongside the
other calibration receipts (e.g.
`kappa_corp_calculation.csv`).
