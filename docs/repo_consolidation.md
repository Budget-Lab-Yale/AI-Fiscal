# Repo consolidation: `ai_fiscal` → `AI-Fiscal`

**Decision (2026-06-11):** This repo (`Budget-Lab-Yale/AI-Fiscal`) is
the single canonical repo for the model going forward. The original
development tree (`Budget-Lab-Yale/ai_fiscal`) will be archived
(read-only, private) once the v0.1.0 tag lands here.

## Background

`AI-Fiscal` began (2026-05-25) as a history-squashed fork of
`ai_fiscal`'s `release-v0.1.0` branch (commit `c29ec56`), with the
alternative-assumption machinery stripped so external reviewers could
read the released code end-to-end. The original plan
(`ai_fiscal/docs/AI_FISCAL_PUBLIC_REPO.md`) kept `ai_fiscal` as the
primary dev tree with a manual forward-port checklist.

Two weeks in, the split was already inverted: this repo accumulated
the release engineering (`renv.lock`, CI, runnable synthetic-fixture
test suite, CITATION.cff, methodology appendix, code fixes) that the
"dev tree" lacked, and every numbers change faced a hand-executed
port with an R4→R1 rename mapping. The split's legibility goal is
served equally well by a release *tag* on a single repo.

## Why this repo survives (and not `ai_fiscal`)

1. All release infrastructure lives here; back-porting it would cost
   more than forward-porting dev machinery.
2. `ai_fiscal`'s git history contains the NBER w35046 PDFs
   (redistribution problem) and hardcoded `/nfs/roberts/.../ji252`
   cluster paths — it can never go public without a history rewrite.
   This repo was built clean from its first commit.
3. The hyphenated TitleCase name matches the org convention
   (`Tax-Simulator`, `Tax-Data`).

## Operating model going forward

- `main` is the development tree. Releases are **tags** (`v0.1.0`,
  `v0.2.0`, …); a tag is the frozen, citable state. Only tags are
  guaranteed clean/validated — `main` may carry work in progress.
- `report_commit_history.md` maps each publication to its tag SHA.
- `ai_fiscal` (archived) remains the provenance record for
  pre-release history and the source to cherry-pick dormant variant
  machinery from (V2/V3 realization, legacy retirement cascades,
  alternative asset bases, S1 labor scenario, diagnostics
  `12_retire_zero.R` / `14_wealth_composition_table.R` /
  `99_diagnostics.R`).

## Naming guard

The retirement-cascade label **R1 means different things in the two
repos**: R1 here = the income-flow cascade (called R4 in `ai_fiscal`);
R1 in `ai_fiscal` = a full-deferral cascade this repo never carried.
When porting variant code from the archive, rename legacy R1/R2/R3 to
descriptive names (`full_deferral`, `soi_wealth_frame`, …) — do not
reuse numbered R-labels.

## Consolidation checklist

- [x] Decision documented in both repos (this file;
  `ai_fiscal/docs/AI_FISCAL_PUBLIC_REPO.md` tombstone note).
- [ ] Port from `ai_fiscal`: `docs/realization_and_wealth_extensions.md`
  (v2 planning input), `config/calibration/cit_avoidance_calculation.csv`.
- [ ] Tag `v0.1.0` here (after fixture regen + native cluster
  `renv::snapshot()`; see `todo.md` §"Post-review status").
- [ ] Archive `Budget-Lab-Yale/ai_fiscal` on GitHub (Settings →
  Archive). Keep private.
- [ ] Verified already: the four post-fork BLSMM commits on
  `ai_fiscal@main` (`b9ff857..b052636`) are represented here; nothing
  code-wise is stranded.
