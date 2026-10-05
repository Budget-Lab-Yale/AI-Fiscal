# v1.0.1 erratum: results with and without each correction

This folder holds the full 2030 result set for four runs of the v1.0
release pipeline. Together they isolate the effect of the two
corrections in v1.0.1. Every number in the published Table 1, Figures
1–7 and the appendix figures can be regenerated from these CSVs, in
both their published and corrected versions.

## The two corrections

1. **Karger labor shares (respondent-group mix-up).** v1.0.0 took
   2025–30 GDP growth from the *Economists* column of Karger et al.
   (2026, NBER w35046) Table 19 (2.0 / 2.6 / 3.3%). But it took the 2030
   nonfarm-business labor share from the pooled all-respondents
   (*Total*) column of Table 39 (55.0 / 53.8 / 51.3%). The Economists
   column gives 55.0 / **54.0** / **52.0**. v1.0.1 uses Economists for
   both, so the post-shock capital share `theta1_k` changes from 0.462
   to 0.460 (Moderate) and from 0.487 to 0.480 (Rapid). Only the
   reallocate-mode Moderate and Rapid cells move. Slow is 55.0% in both
   columns, and fixed-share cells hold the capital share at baseline.
2. **CBO baseline ratios (rounding).** v1.0.0 sized two CBO FY2030
   baseline levels from the rounded shares of GDP printed in the
   report's Table 1. The corrected values come from CBO's Table 1-1
   data supplement (www.cbo.gov/publication/61882):

   | Item | v1.0.0 | v1.0.1 |
   |---|---|---|
   | Corporate income taxes / GDP (`cit_to_gdp_baseline_year`) | 1.3% → $486.1B | 1.2766% → $477.3B |
   | Total revenues / GDP (`rev_to_gdp_baseline_year`) | 17.7% → $6,618.2B | 17.638% → $6,595.0B |

   The macro corporate-tax change is proportional to the corporate-tax
   baseline. It is the CIT effect computed outside the microsimulation:
   `delta_R_CIT = X × CIT_baseline / Y0_K`, where `X` is the AI-driven
   capital-income flow and `Y0_K` is baseline capital income. So v1.0.0
   overstated it by 1.8% in every cell. The total-revenue ratio is the
   baseline for the CBO-anchored revenue-to-GDP figures. The
   microsimulation results (individual income and payroll taxes, credits,
   income and the distributional tables) are unaffected.

## The four runs

| Folder | Labor shares | CBO ratios | What it is |
|---|---|---|---|
| `runs/A_v1.0.0_published` | pooled (Total) | rounded | v1.0.0 as published (reproduced exactly; see below) |
| `runs/B_karger_fix` | Economists | rounded | correction 1 only |
| `runs/C_cbo_fix` | pooled (Total) | exact | correction 2 only |
| `runs/D_v1.0.1` | Economists | exact | v1.0.1, both corrections |

Each run folder contains:

- `aggregates/`: the pipeline's CSV outputs (`revenue_grid`,
  `revenue_deltas`, `decile_panel`, `gini_deltas`, `share_deltas`,
  `atr_decile`, `revenue_to_gdp`, `blsmm_debt_to_gdp`, ...).
- `figure_data/`: one CSV per figure in the full figure suite (the
  data behind each PNG from `code/10_figures.R`).
- `paper_figure_data/`: one CSV per exhibit in the policy draft (`T1`,
  `F1`–`F7`, `FA1`–`FA4`), from `code/paper_figure_data.R`. These are
  written cell for cell, title and note rows included.
- `parameters/`: the parameter index, the derived parameters per
  variant, and the per-cell parameters (`cell_params`).

## Comparison tables (`comparison/`)

Each row carries the value in all four runs (`A`, `B`, `C`, `D`) and
the attributed effects:

- `karger_fix = B − A`
- `cbo_fix = C − A`
- `total = D − A`
- `interaction = D − B − C + A`

The interaction term is small; at most $0.15B, in Rapid.

| File | Contents |
|---|---|
| `revenue_2030.csv` | Revenue change by scenario and component, $B. The published headline is `total_with_macro_cit`. |
| `revenue_to_gdp_2030.csv` | Change in revenue/GDP vs the CBO baseline (`delta_rev_to_gdp_cbo`, a fraction; ×100 for pp) |
| `gini_delta_2030.csv` | Gini change, pre-tax and after-tax |
| `decile_share_delta_2030.csv` | Change in income share by decile |
| `cell_params_2030.csv` | Per-cell shock parameters (`theta1_k`, `g_y`, `g_k`, `g_l`, `X_B`, `delta_R_CIT_B`, ...) |
| `paper_exhibits_2030.csv` | Every numeric cell of every draft exhibit, keyed by exhibit sheet, row and column, with the exhibit's own row and column labels |

## Headline effects (2030, proportional labor scenario S0)

`total_with_macro_cit` is the change in federal revenue in $B. The pp
column is the change in revenue/GDP vs the CBO baseline.

| Cell | v1.0.0 | Karger fix | CBO fix | v1.0.1 | rev/GDP pp, v1.0.0 → v1.0.1 |
|---|---|---|---|---|---|
| Slow, reallocate | 8.2 | 0.00 | −0.15 | 8.0 | −0.082 → −0.082 |
| Moderate, reallocate | 105.2 | +8.73 | −0.66 | 113.3 | −0.341 → −0.318 |
| Rapid, reallocate | 170.7 | +31.41 | −1.51 | 200.8 | −0.758 → −0.678 |
| Moderate, fixed share | 179.7 | 0.00 | −0.31 | 179.4 | −0.149 → −0.147 |
| Rapid, fixed share | 360.7 | 0.00 | −0.63 | 360.1 | −0.284 → −0.281 |

The Karger fix raises the labor share in Moderate and Rapid. In Rapid,
aggregate labor income now rises slightly (+0.41%) instead of falling
(−0.94%), and capital income rises less (+15.6% instead of +17.3%).
The after-tax Gini increase in Rapid falls from 0.0057 to 0.0049.

## Reproduction and provenance

- **Code:** run A is tag `v1.0.0`. Runs B–D are tag `v1.0.1` with one or
  both `config/scenario_params.yaml` edits. Nothing else changed in the
  model code. B and D also carry label-only edits: "CBO no-AI baseline"
  becomes "CBO baseline", since CBO's baseline already embeds +0.1 pp a
  year of AI-driven total factor productivity growth.
- **Inputs:** Tax-Data vintage `2026050315`; Tax-Simulator commit
  `256f03ea9` with the three local patches documented in
  `docs/tax_simulator_patches.md` (Tax-Simulator issues #128–#130);
  Budget Lab Small Macro Model at `adce14d`. Each run is one full
  pipeline run (`Rscript code/00_ai_fiscal_sim.R --multicore scenario
  --overwrite`) followed by `Rscript code/paper_figure_data.R`.
- **Reproducing v1.0.0:** run A reproduces the published v1.0.0 exactly.
  All 54 counterfactual tax-unit files were byte-identical to the
  published run's, and every sheet of both published workbooks matched
  to within 1e-9.
- **Appendix A1 and A2:** these two charts are historical series pulled
  live from FRED. All four runs used the same pull (2026-10-05). FRED's
  revisions since the July 2026 publication move the historical values
  by at most 0.005, so run A's `FA1`/`FA2` differ from the published
  workbook by that much. The model-driven exhibits (`T1`, `F1`–`F7`,
  `FA3`, `FA4`) match the published workbook exactly.
- **Regenerating these CSVs:** `code/erratum_v1_0_1_export.R` builds
  them from the four runs' result snapshots.
