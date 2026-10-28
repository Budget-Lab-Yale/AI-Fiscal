# Version 1.2: figure pipeline plan

Branch `AI-Fiscal-V1.2`. Written 2026-10-28. Companion to
[`v1_2_plan.md`](v1_2_plan.md).

## Goal

Produce the published figures from this repository, in the Budget Lab chart
engine's own format, so that:

- (a) we see every figure as it will appear on the website, from the model
  outputs, before anything is published;
- (b) publishing the website figures is copying a folder and opening a pull
  request, with no hand reshaping of data;
- (c) an alternative version of a figure (another scenario, a different
  title, a slide-sized export) is a few lines of configuration.

## How figures are made today

There are three separate paths, and only one of them is automated.

1. **`code/10_figures.R`** draws the model figure suite in ggplot with a
   "YBL brand kit" (`code/00_utils.R:170-270`). The palette was matched by
   eye to the Budget Lab's Datawrapper charts, so these PNGs approximate the
   site style and do not reproduce it. It also writes
   `figure_data_<year>.xlsx`.
2. **`code/paper_figure_data.R`** selects, orders, and relabels the draft's
   exhibits into `paper_figure_data_<year>.xlsx`, and rebuilds appendix
   figures A1 and A2 from FRED.
3. **The website figures** are 13 specs (11 charts, 2 tables) in the
   `budget-lab-charts` repository at
   `charts/articles/2026/07/ai-fiscal/<figure>/` (`chart.yaml` or
   `table.yaml`, plus `data.csv`). Their `data.csv` files were reshaped by
   hand from the workbooks. For v1.0.1 all 13 had to be rebuilt and checked
   one by one against `results/erratum_v1.0.1/runs/D_v1.0.1`. The site
   folder names (`revenue-headline`, `atr-by-decile`, ...) are not the
   model's figure slugs (`01_headline_revenue`, `14_atr_decile_ai_M_R_S0_V1`,
   ...), and nothing in this repository records the mapping.

Slide versions are a fourth, one-off path. The September 30 talk used a
script in the event folder (`render_figures.mjs`) that renders the site specs
with the engine and patches the export height.

## Design

### 1. Chart specs live in this repository

Add a top-level `charts/` folder with one subfolder per published figure,
named exactly as on the site:

```
charts/
  ai-fiscal/                 <- one collection per article
    article.yaml             <- copied from / to budget-lab-charts
    revenue-headline/
      chart.yaml             <- engine schema, committed
      data.csv               <- generated, committed only for releases
    atr-by-decile/ ...
  variants/                  <- alternative versions (section 4)
```

The specs are written to the engine's strict schema (`ENGINE-CONFIG-SPEC.md`
in `budget-lab-charts`), so the collection folder can be copied into
`budget-lab-charts/charts/articles/<yyyy>/<mm>/<slug>/` unchanged. The first
step imports the 13 published v1.0.1 specs as they are.

### 2. The model writes each figure's data

A new numbered step, `code/16_chart_data.R`, builds every published figure's
`data.csv` from a run's tables in the run store (`results/runs/<run_id>/tables/`,
model plan workstream E) plus the FRED pulls in `paper_figure_data.R`. It
does not read the workbooks, which become views of the same store. It is
driven by one manifest, `config/charts.yaml`:

```yaml
revenue-headline:
  figure: "Figure 1"
  type: chart                 # chart | table
  builder: chart_revenue_headline
  source: revenue_grid_wide   # model output it reads
  model_slug: 01_headline_revenue
```

Each builder is a small R function returning the long-format table the spec
expects, with the column names the spec's `columns:` block uses. The writer
follows the engine's CSV rules (UTF-8 without a BOM, ISO dates, no thousands
separators). The live site CSVs start with a BOM, left by the hand workflow;
the generated files will not.

The manifest replaces the hand-maintained mapping in the header of
`paper_figure_data.R`, so the model slug, draft exhibit, and site folder
of each figure are recorded in one place.

**Acceptance test:** run against the v1.0.1 run directory, `16_chart_data.R`
reproduces the 13 live `data.csv` files (live URL pattern
`https://charts.budgetlab.yale.edu/ai-fiscal/<chart>/data.csv`) exactly,
apart from the BOM. Those files become committed test fixtures.

**The figure set will change.** Every Version 1 figure is a 2030
cross-section; with ten fiscal years most will be replaced by annual paths
and window totals, and some single-year cuts may survive as views of one
year. The 13 v1.0.1 figures are therefore a test of the plumbing (specs,
manifest, builders, rendering, publishing), not a commitment to keep them.
Builders for them stay minimal, and choosing the Version 1.2 figure set
(published and diagnostic) waits for the ten-year outputs (F5).

### 3. Rendering: see figures as the site shows them (goal a)

Add a minimal Node toolchain at the repository root:

- `package.json` pins `budget-lab-chart-engine` to the **same tag**
  `budget-lab-charts` pins (`v1.18.0` on its `main` today; the engine
  repository is public, so no token is needed) plus `playwright` for PNGs.
  A check fails if the two pins differ, so what we preview is what the site
  will render.
- `npm run charts:validate`: `tbl-chart validate` on every spec.
- `npm run charts:render`: `tbl-chart render` to self-contained HTML under
  `results/charts/html/` (gitignored), one page per figure, interactive as on
  the site.
- `npm run charts:serve`: `tbl-chart serve charts/` for a local gallery of
  every figure.
- `npm run charts:png`: the site's own "Image" export, driven headlessly
  (render, load in Chromium, click the download button), so the PNG matches
  what a reader downloads from the site. This generalizes the September 30
  `render_figures.mjs`.

The R orchestrator calls `charts:validate` and `charts:render` after
`16_chart_data.R` when Node is available, and skips with a message when it is
not (the cluster may not have Node; renders then happen on the laptop from
the pushed outputs). Calls go through `system2()` with `shQuote(type = "cmd")`
on Windows.

### 4. Alternative versions (goal c)

A variant is a short YAML file in `charts/variants/` that names a base figure
and changes only what differs:

```yaml
# charts/variants/revenue-headline-fixed.yaml
base: revenue-headline
data:
  filter: {share_mode: Fixed}        # rows of the base data.csv to keep
spec:
  subtitle: "Change in federal revenue, fixed factor shares, FY 2030, Billions USD"
export:
  height: 535                        # slide-sized PNG (2000x1070)
```

A Node script merges the base spec and data with the variant and writes a
complete spec folder to `results/charts/variants/<name>/`. That folder
renders, previews, and exports like any other figure. Because the merged spec
is validated against the engine schema, a variant cannot carry a field the
site would reject. Variants that become published figures are promoted into
the collection with a permanent folder name.

Common variants this covers: other scenarios or labor rules than the
published cut, Version 1.0.1 against Version 1.2 side by side, slide-sized
exports, and relabeled series for talks (the September 30 "Macro CIT" →
"Corporate income tax" change).

Export height is the one setting the engine does not expose: the site export
frame is 1000 px wide at 2x and a fixed 750 px tall for single charts. The
PNG step overrides it with the same one-line patch the September 30 script
used, and fails loudly if the engine no longer contains that line.

### 5. Publishing (goal b)

`npm run charts:publish -- <path-to-budget-lab-charts>`:

1. checks the target checkout is clean and on a new branch cut from its
   `main`;
2. copies `charts/<collection>/` into the article folder;
3. runs that repository's `npm run validate`;
4. prints the `git add` list of explicit paths for review (that repository
   forbids `git add -A`; its `charts/trackers/` is untracked and not
   ignored).

The pull request itself stays a deliberate human step. Its CI posts a live
preview, and merging publishes. Figure folder names and the collection slug
are permanent public embed URLs, so a new folder name is always agreed before
the first copy.

### 6. What happens to the ggplot suite

`10_figures.R` keeps the diagnostic figures that are never published
(today: sensitivity heatmap, waterfalls, scatter diagnostics; the Version 1.2
set is chosen at F5, see section 2). For the published
figures the engine render becomes the reference, and their ggplot versions are
retired once the engine path covers them, so two styles of the same figure do
not drift. The YBL palette constants then serve the diagnostic figures only.
They should take their values from the engine's house palette (categorical
ramp `blue amber violet green red rose russet`; `navy` and `sky` are brand
tokens, not series colors) so that diagnostics and site figures read as one
system.

## Steps

| Step | Work | Done when |
|---|---|---|
| F0 | Import the 13 v1.0.1 site specs into `charts/ai-fiscal/`; write `config/charts.yaml` with the full mapping (site folder, figure number, model slug, source output) | manifest covers all 13 figures |
| F1 | `16_chart_data.R` builders, reading the run store | acceptance test reproduces all 13 live CSVs from the v1.0.1 run directory |
| F2 | Node toolchain: validate, render, serve, png; pin check | gallery shows all 13; PNGs match site downloads |
| F3 | Variants: merge script and three worked examples (fixed shares, slide size, relabeled series) | the September 30 slide set rebuilds from variants |
| F4 | Publish script; dry run into a scratch branch of `budget-lab-charts` | that repository's `npm run validate` passes |
| F5 | Choose the Version 1.2 figure set (published and diagnostic) from the ten-year outputs; likely annual fiscal-year paths (line and stacked-bar charts by year), the v1.0.1 → v1.2 bridge, the national-income reconciliation, the early-evidence exhibit | specs reviewed by John before identity is fixed |
| F6 | CI: a Node job in `.github/workflows/test.yml` running `charts:validate` and the F1 acceptance test | green on the branch |

F0–F2 can run alongside rungs 0–1 of the model plan; F5 waits for the
ten-year outputs.

## Open points

1. **Release form for Version 1.2.** A new article (new collection slug, new
   figure folders) or an updated `ai-fiscal` article. Decide before F5;
   folder names are permanent once merged.
2. **Engine pin policy.** Follow `budget-lab-charts` `main` automatically
   (the pin check fails, then we bump), or pin per release and bump on
   purpose. The proposal is the second option, since a repin re-renders
   every figure.
3. **Committed data.** Generated `data.csv` files are committed only for
   tagged releases (as `results/v1.0.1/` is today), not on every run.
4. **Tables.** The two published tables (`key-parameters`,
   `key-parameters-symbols`) use inline math; check that their
   `table.yaml` round-trips unchanged before relying on the pipeline for
   them.
