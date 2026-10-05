# v1.0.0 results (archived)

These are the published v1.0.0 outputs, copied unchanged from the
`v1.0.0` tag (commit `53a92aa`, 2026-07-20) so they can be read next to
the corrected v1.0.1 outputs. Every file is byte-identical to the tagged
version.

| Folder | Contents |
|---|---|
| `aggregates/` | `ai_fiscal_2030_latest.xlsx` and `ai_fiscal_publishable_2030_latest.xlsx` as published |
| `figures/2030/` | the published figure PNGs and figure-data workbooks |

**These numbers are superseded.** The canonical `results/aggregates/` and
`results/figures/` folders hold v1.0.1, which corrects two errors:

- **V1-8** — the 2030 labor shares came from the pooled column of Karger
  et al. (2026) Table 39 (53.8% / 51.3%) while GDP growth came from the
  economists' column of Table 19; v1.0.1 uses the economists' column for
  both (54.0% / 52.0%).
- **V1-9** — the FY2030 CBO corporate and total revenue baselines were sized
  from rounded report ratios (1.3% / 17.7% of GDP); v1.0.1 uses CBO's exact
  values.

See [`docs/erratum_v1.0.1.md`](../../docs/erratum_v1.0.1.md) for the
erratum note, and [`results/erratum_v1.0.1/`](../erratum_v1.0.1/) for the
four-run comparison (A = v1.0.0 as published, B = labor-share fix only,
C = CBO fix only, D = v1.0.1) as CSVs.
