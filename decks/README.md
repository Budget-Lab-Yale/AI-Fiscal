# decks/ — the two release decks

The Version 1.2 work ends in two decks for an external audience, both on the
Budget Lab slide template (Template A, 16:9): a **corrected Version 1**
(v1.0.1's design with four corrections; FY2030) and **Version 1.2** (FY2026-2036).

| Path | What |
|---|---|
| `outlines.md` | Slide-by-slide outline of both decks, with the numbers each slide shows. Titles are left for the author. |
| `corrected_v1/data/`, `v1_2/data/` | One long-format CSV per chart slide (file name starts with the slide number in `outlines.md`; `a*`/`b*` are appendix slides). |
| `build_deck_data.R` | Rebuilds the CSVs from the finished runs in `results/runs/` (cluster only; run ids are listed at the top). |

## Building a chart slide

The charts are made with the `slide-charts` skill of the `budget-lab-charts`
repository (open Claude Code in that repository so the skill loads), from new
data:

1. Make a working folder beside the deck: `Slide charts/<name>/`.
2. Copy the slide's CSV there as `data.csv` and write a `chart.yaml` for it
   (schema: `ENGINE-CONFIG-SPEC.md` in budget-lab-charts; series colors from the
   categorical ramp only). The chart title and subtitle are the author's.
3. Render: `node scripts/slides/render-slide.mjs "<folder>" --frame below-title`
   (or `half` / `full`), and check the PNG.
4. Insert: `scripts/slides/insert-slide.ps1` (Windows with desktop PowerPoint).

The skill does not put tables on slides: the appendix tables
(`a2_revenue_grid`, `b4_window_totals`, the reconciliation) are built in
PowerPoint from the CSVs.

Every CSV is in billions of dollars unless its column name says otherwise
(`_pct`, `_pp` for percentage points, `gini_change`).
