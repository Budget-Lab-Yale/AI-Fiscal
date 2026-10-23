# v1.0.1 results (archived)

These are the v1.0.1 erratum outputs, copied unchanged from the canonical
`results/aggregates/` and `results/figures/2030/` folders at the `v1.0.1`
tag (2026-10-09) so they stay readable after later versions overwrite
those folders. Every file is byte-identical to the tagged version.

| Folder | Contents |
|---|---|
| `aggregates/` | `ai_fiscal_2030_latest.xlsx` and `ai_fiscal_publishable_2030_latest.xlsx` with the v1.0.1 corrections |
| `figures/2030/` | the v1.0.1 figure PNGs and figure-data workbooks (A1/A2 pinned to the 2026-07-09 FRED vintage) |

v1.0.1 corrects two v1.0.0 input errors:

- **V1-8** — the 2030 labor shares now come from the economists' column of
  Karger et al. (2026) Table 39 (54.0% / 52.0%), matching the GDP growth
  rates already taken from that column of Table 19; v1.0.0 used the pooled
  column (53.8% / 51.3%).
- **V1-9** — the FY2030 CBO corporate and total revenue baselines use CBO's
  exact Table 1-1 values rather than the rounded report ratios.

See [`docs/erratum_v1.0.1.md`](../../docs/erratum_v1.0.1.md) for the
erratum note, [`results/erratum_v1.0.1/`](../erratum_v1.0.1/) for the full
with/without-correction CSV result set, and [`results/v1.0.0/`](../v1.0.0/)
for the published v1.0.0 outputs.
