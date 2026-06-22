# Data requirements

AI-Fiscal does not ship the microdata it runs on, and it cannot — the
inputs derive from the restricted IRS Public Use File and cannot be
redistributed. This document describes **what the input data is, how it
is built, and the exact columns the pipeline needs**, so a reproducer
with the appropriate access can assemble an equivalent vintage, and a
reader without access can understand the model's data footprint.

For a no-data smoke test, use the committed synthetic fixture
(`tests/fixtures/synthetic_tax_data/`) — it reproduces the schema below
with values drawn from generic distributions and no row-level economic
content. See the README §"Synthetic fixture (no PUF access)".

## Provenance

The pipeline consumes a single per-year tax-unit file — the **Budget
Lab Tax-Data vintage** (merged PUF + SCF). Its construction, upstream of
this repo, is:

1. **Base file — 2015 IRS Public Use File (PUF, ~150k records),** the
   standard input to the Budget Lab Tax-Simulator.
2. **Non-filer imputation + aging.** The PUF is supplemented with
   non-filer imputations and aged to the baseline year (default 2030)
   via SSA population weights and CBO economic scaling. This is the
   standard Tax-Data / Tax-Simulator aging procedure — see
   [Tax-Data](https://github.com/Budget-Lab-Yale/Tax-Data) and
   [`docs/ai_fiscal_methodology.md`](ai_fiscal_methodology.md) §"Data".
3. **SCF asset merge.** Because the PUF carries no asset-level wealth
   (which AI-Fiscal needs to allocate AI-driven capital income across
   households), each year's PUF income record is paired with imputed
   asset holdings drawn from the Federal Reserve's Survey of Consumer
   Finances (SCF). The PUF–SCF match is validated upstream against NIPA,
   SOI, and the Distributional Financial Accounts (DFA). AI-Fiscal
   treats this matched file as ground truth and does not re-do the
   match.

The result is the file the pipeline reads at
`data/tax_data/baseline/tax_units_<year>.csv`. `data/tax_data` is a
symlink (or copy) to the shared vintage and is never committed.

## Required columns

`code/01_load_data.R` loads the file and `code/00_utils.R` holds the
canonical column registries. There are two groups of columns the
AI-Fiscal layer requires (on top of whatever Tax-Simulator's own tax
calculation needs — AI-Fiscal only adds and reshapes columns, so the
full upstream tax-unit schema must also be present).

### PUF income / deduction columns (for the SYZ labor/capital split)

Enforced by `.REQUIRED_TAX_UNIT_COLS` in `01_load_data.R`; a missing
column aborts at load with an explicit message rather than failing later.

| Column | Role |
|---|---|
| `weight` | Tax-unit sampling weight. |
| `wages` | W-2 wages; also sets the SYZ `W*` threshold. |
| `scorp_active`, `scorp_active_loss`, `scorp_passive`, `scorp_passive_loss` | S-corp profit/loss, active & passive (SYZ split). |
| `part_active`, `part_active_loss`, `part_passive`, `part_passive_loss` | Partnership profit/loss, active & passive (SYZ split). |
| `sole_prop`, `farm` | Schedule C / F — counted as labor income (`YiL`). |
| `txbl_int`, `exempt_int`, `div_ord`, `div_pref` | Interest and dividends — capital income (`YiK`). |
| `kg_st`, `kg_lt`, `other_gains` | Capital gains (short/long/other) — capital income. |
| `rent`, `rent_loss`, `estate`, `estate_loss` | Rental and estate/trust income, net of loss — capital income. |
| `txbl_ira_dist`, `txbl_pens_dist` | Taxable retirement distributions — capital income. |

### SCF-imputed wealth columns (for the capital-income allocation)

The canonical wealth universe is `.ASSET_KNOWN` in `00_utils.R`. The
allocation base actually used (`.ASSET_BASE_ALL_ASSETS`) is the gross
asset subset — liabilities are loaded but excluded.

| Group | Columns |
|---|---|
| **Assets (allocation base)** | `cash`, `equities`, `bonds`, `retirement`, `life_ins`, `annuities`, `trusts`, `other_fin`, `pass_throughs`, `primary_home`, `other_home`, `re_fund`, `other_nonfin` |
| **Loaded, not in base** | `db` (defined-benefit pension wealth) |
| **Liabilities (loaded, excluded from base)** | `primary_mortgage`, `other_mortgage`, `credit_lines`, `credit_cards`, `installment_debt`, `other_debt` |

A subset of the asset columns is income-bearing for the within-unit
allocation step (`.INCOME_BEARING_COLS`): `equities`, `bonds`,
`pass_throughs`, `retirement` — mapped to taxable-income types via
[`config/asset_to_income_map.csv`](../config/asset_to_income_map.csv).

### Schema normalization at load

Vintages `2026050315+` prefix wealth columns with `value.` and split
retirement into `dc` + `db`. `load_tax_units()` normalizes this so
downstream code is vintage-agnostic:

- strips the `value.` prefix (`value.equities` → `equities`);
- renames `dc` → `retirement`;
- preserves `db` as-is (not in the allocation base);
- **warns** if the vintage carries a `value.*` column not in
  `.ASSET_KNOWN` — a signal to update the registry rather than silently
  drop a new asset class.

## Privacy

The merged PUF + SCF file derives from the restricted IRS PUF and the
SCF and **cannot be committed or redistributed**. Reproducers need
their own access to the Budget Lab Tax-Data vintage. Everyone else can
exercise the full I/O and schema path against the synthetic fixture.
