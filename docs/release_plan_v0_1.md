# Release plan — v0.1.0

**Status.** Drafted 2026-05-21 against vintage `202605211533` (SLURM job
12384049, 18-cell V1 grid, R4 retirement cascade default). Headline
artifact: `results/aggregates/ai_fiscal_publishable_2030_202605211533.xlsx`.

## Scope

Ship the V1 grid (3 variants × {R,F} × {S0,S2,S3} = 18 cells) as the
first public release, with the methodology doc and code available for
audit. V2 / V3 realization variants stay available as code paths
(`--realization V1,V2`) but are not part of the headline. Iteration
continues on `main` post-tag with semver versioning.

**Frame framing.** v0.1.0 ships *income-frame* numbers — `X = g_k · K_0`
denominated in realized-income units, with the R4 retirement cascade
treating the wealth-allocated slice as already-realized flow. The
medium-term direction is to make the frame itself a user toggle
(realized-income flow vs wealth accrual; see
`docs/realization_and_wealth_extensions.md`); v0.2.0+ will land the wealth-frame
leg and the toggle. Release notes name this explicitly so external
readers expect future numbers to revise under the alternative frame.

## Spot-check verification (2026-05-21, vintage 202605211533)

- `parameters` sheet in the publishable bundle shows `R4` as the
  cascade variant across all rows.
- Retirement aggregate split is present with descriptive headers from
  `code/08_aggregate.R:877–879`: slice (pre-cascade), realized this
  year, unrealized / deferred. Under R4, realized = slice and
  unrealized = 0 (snapped to zero by the `ifelse(abs(x) < 1e-5, 0, x)`
  guard in `code/00_ai_fiscal_sim.R::.write_macro_summary`).
- `cell_params` sheet contains 18 rows — V1-only headline grid as
  intended.
- Fig 15 (`results/figures/2030/15_x_waterfall_V1_2030.png`) sourced
  from `code/10_figures.R:1086,1107` uses the renamed `Retirement
  (unrealized)` label — the R4 slice is no longer mislabeled as
  deferred.

## Pre-release punch list

Concrete file-level work needed before tagging `v0.1.0`. Items marked
`(decision)` need user input. Items resolved during the 2026-05-21
review are marked ✅.

### Legal / citation

- ✅ **LICENSE** — MIT, added at repo root.
- [ ] **CITATION.cff** — added at repo root listing John Iselin and
  Ryan Nunn (both Budget Lab at Yale) as authors. ORCID IDs still
  TODO before tagging if either author wants them embedded.
- [ ] **`.zenodo.json`** — deferred to v0.2.0+ (per Zenodo decision
  below). Not required at v0.1.0.

### README polish

- [ ] **Pin Tax-Simulator commit hash.** README currently references
  the upstream pin `c0aa34be...`. Publish a fork branch/tag at
  `Budget-Lab-Yale/Tax-Simulator` (e.g. `ai-fiscal-v0.1.0`) carrying
  the three local-fork patches (`src/sim/run.R:95`, `:104`,
  `src/main.R:110` + `src/sim/run.R:153`), then pin THAT tag in
  README. Closes the reproducer gap that the bare upstream SHA leaves.
- [ ] **Pin data vintage.** Document `202605211533` as the vintage the
  v0.1.0 headline numbers were built against (Tax-Data + PUF inputs).
  Add a "Reproducing the v0.1.0 headline" subsection that lists
  vintage, Tax-Simulator fork tag, R version (see
  `docs/v0_1_0_session.txt`), and the exact
  `Rscript code/00_ai_fiscal_sim.R --full ...` invocation.
- [ ] **Document the reproducibility limit.** Add a short paragraph
  near the top explaining that external readers can audit code and
  methodology but cannot exactly reproduce headline figures without
  PUF access; the synthetic-fixture path is the recommended pipeline
  smoke-test for external users.
- ✅ **CLI `--data-dir` flag added.** `code/00_ai_fiscal_sim.R` now
  accepts `--data-dir PATH`, so external users can run
  `Rscript code/00_ai_fiscal_sim.R --no-sim --data-dir tests/fixtures/synthetic_tax_data`
  for a no-PUF smoke test. README documents this.
- [ ] **Smoke-test the synthetic-fixture CLI path** end-to-end with
  the new flag before tagging.
- [ ] **Link methodology doc.** README should link to
  `docs/ai_fiscal_methodology.md` (the combined methodology document
  — public-voice narrative plus internal methodology detail, merged
  from the prior `ai_fiscal_methodology.md` + `ai_fiscal_model.md`
  pair) explicitly.

### Repository hygiene

- [ ] **CHANGELOG.md** — initial v0.1.0 entry summarizing the model
  scope. Going forward, every PR that lands on main updates this.
- ✅ **Methodology doc format settled.** Ship `.md` only; no `.docx`
  or `.pdf` release artifacts. Readers render their own from the .md
  if they want a typeset version. The locally-generated `.tex`/
  `.html`/`.docx` artifacts remain untracked in git.
- ✅ **`docs/v0_1_0_session.txt`** — committed; pins R version and
  attached/loaded package versions at the time of tagging (developer
  machine, not the SLURM build node — see file header).
- [ ] **Run testthat suite locally + record result.** Execute
  `Rscript tests/testthat.R` against vintage `202605211533`; record
  the pass count and any expected skips in the v0.1.0 CHANGELOG.md
  entry. No CI infrastructure required at v0.1.0; advisory check only.

## Release execution

1. **Tag** the release commit as `v0.1.0` on `main`.
2. **GitHub release** at the tag with attached binaries:
   - `ai_fiscal_publishable_2030_202605211533.xlsx`
   - `ai_fiscal_2030_202605211533.xlsx` (internal companion)
   - A zipped `results/figures/2030/` directory
3. **Zenodo deposit** — deferred to v0.2.0+ per the decision below.
   No DOI minting at v0.1.0; the GitHub URL + tag SHA is the canonical
   reference until then.
4. **Release-notes body** must include the methodology-evolution
   caveat: "v0.1.0 publishes R4 income-frame numbers; a future
   release will add a wealth-frame toggle (`docs/realization_and_wealth_extensions.md`)
   under which headline numbers may revise." This is the single most
   important caveat for an external reader to internalize before
   citing the v0.1.0 figures.

## Post-release iteration

- **Branching.** `main` is the public-stable line; feature work in
  branches/PRs.
- **Versioning.** Semver going forward — `v0.2.0` for additive grid
  changes (new variants, new figures, the wealth-frame toggle),
  `v0.1.1` for bugfixes that don't change headline numbers.
  Numbers-changing patches bump minor.
- **CHANGELOG discipline.** Every PR landing on main updates
  `CHANGELOG.md` under an `Unreleased` heading; release-tag commits
  promote the section to a dated version block.
- **Followups carried from v0.1.0:**
  - Wealth-frame migration (Phase 1+) per `docs/realization_and_wealth_extensions.md`.
  - README "TODOs" section sweep — promote relevant items to
    GitHub issues so iteration is tracked in the open.
  - Enable GitHub→Zenodo integration and mint a DOI at the v0.2.0 tag;
    amend CITATION.cff with the DOI on the next patch tag.
  - Consider adding GitHub Actions CI running testthat against the
    synthetic fixture (now feasible since `--data-dir` is wired).

## Resolved decisions (2026-05-21 review)

1. **License.** MIT. `LICENSE` committed.
2. **CITATION authors.** CITATION.cff committed listing John Iselin
   and Ryan Nunn (both Budget Lab at Yale). ORCIDs not yet embedded
   (TODO before tagging if either author wants them in).
3. **Zenodo DOI.** Deferred to v0.2.0+. No GitHub→Zenodo integration
   flipped on for v0.1.0.
4. **Methodology doc format.** `.md` only; no `.docx` or `.pdf`
   shipped with the release.
5. **`renv.lock`.** Skipped. `docs/v0_1_0_session.txt` captures R
   version and key package versions instead.
