# Changelog

All notable changes to AI-Fiscal are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BLSMM version pin.** The debt/GDP step (`code/15_blsmm_debt_gdp.R`)
  now checks that the `BLSMM_DIR` clone is at the ref pinned in
  `config/scenario_params.yaml` (`blsmm_ref: v1.8.0`) with no local
  edits under `model/` or `data/`, and stops the pipeline otherwise
  (a missing `BLSMM_DIR` still skips the step with a warning). `BLSMM_REF`
  overrides the pin. The BLSMM ref and commit are recorded in the
  `blsmm_debt_to_gdp` CSV and sheet and in `run_info`. Against
  `v1.8.0` the step reproduces the v1.0.1 debt/GDP results to within
  1e-7 percentage points.

## [1.0.1] — 2026-10-09

Erratum release. Corrects two input errors; see
[`docs/erratum_v1.0.1.md`](docs/erratum_v1.0.1.md) and the
with/without-correction result set in
[`results/erratum_v1.0.1/`](results/erratum_v1.0.1/).

### Fixed

- **Karger labor shares.** 2030 labor shares now come from the
  Economists column of Karger et al. (2026) Table 39 (55.0 / 54.0 /
  52.0%), matching the GDP growth rates already taken from that
  column of Table 19. v1.0.0 used the pooled Total column (55.0 / 53.8
  / 51.3%). `theta1_k`: Moderate 0.462 → 0.460, Rapid 0.487 → 0.480.
- **CBO baseline ratios.** `cit_to_gdp_baseline_year` 0.013 →
  0.0127663 and `rev_to_gdp_baseline_year` 0.177 → 0.176381, from
  CBO's Table 1-1 data supplement rather than the rounded report
  table. The rounded CIT ratio overstated the macro CIT delta by 1.8%.
- **Labels.** "CBO no-AI baseline" → "CBO baseline" (CBO's baseline
  embeds +0.1 pp/yr of AI-driven TFP growth).

### Changed

- FY2030 revenue change (reallocate, proportional): Moderate $105.2B →
  $113.3B; Rapid $170.7B → $200.8B. Rapid aggregate labor income now
  rises 0.4% instead of falling 0.9%.

## [1.0.0] — 2026-07-20

Initial public release, accompanying the Budget Lab report
["How potential AI futures would play out in the current tax system"](https://budgetlab.yale.edu/research/how-potential-ai-futures-would-play-out-current-tax-system).

Income-frame microsimulation of an AI-driven labor-to-capital income
shift, built on the Budget Lab Tax-Simulator.

### Added

- **Scenario grid.** Canonical 18-cell grid: 3 Karger shock variants
  (Slow / Moderate / Rapid, NBER w35046) × 2 factor-share modes
  (Reallocate / Fixed) × 3 labor-side scenarios (Proportional /
  Compressive / Expansive) × V1 mechanical LTCG realization × R1
  income-flow retirement cascade.
- **Tax-Simulator decomposition.** Each cell runs three Tax-Simulator
  scenarios (`both` / `labor_only` / `capital_only`) so labor / capital
  / interaction attribution is reported per instrument.
- **Macro CIT wedge.** Off-microsim corporate-tax delta calibrated
  against the CBO baseline-year CIT level, layered onto the publishable
  bottom line.
- **BLSMM tie-in (optional).** Pipes per-scenario revenue/GDP deltas
  through the Budget Lab Small Macro Model to recover scenario-specific
  2030 debt/GDP. Skipped automatically when `BLSMM_DIR` is unset.
- **Self-documenting `.xlsx` bundles** with `run_info`,
  `scenario_guide`, `parameter_index`, `cell_params`, `key_parameters`,
  `calibration_receipts_*`, `variable_list`, and `revenue_to_gdp`
  sheets — readable without the code. Per-unit income notation is
  unified as `Y_{j,i}^X` across code, tests, docs, and reader-facing
  workbook columns.
- **testthat suite** plus a synthetic PUF + SCF fixture
  (`tests/fixtures/synthetic_tax_data/`) for I/O / schema smoke testing
  without PUF access. GitHub Actions runs the suite on every push and
  PR against the fixture.
- **Documentation.** Main methodology in
  `docs/ai_fiscal_methodology.md`; full R1 and V1 derivations in
  `docs/ai_fiscal_methodology_appendix.md`; architecture reference in
  `CLAUDE.md`; cold-start setup in `docs/environment_setup.md`;
  v2 ideation sketch in `docs/v2_architecture.md`.
- **Reproducibility.** R package versions pinned via `renv.lock` (R
  4.4.2, matching the cluster module); `requirements.txt` companion
  mirrors the Tax-Simulator convention.

### Out of scope for v1.0 (planned for later releases)

- Wealth-frame definition of $X$ (current model sizes $X$ off the
  on-1040 realized base; see Future work §"Wealth-frame redefinition
  of X" in the methodology).
- Labor-side AI-exposure scenario (S1) using occupation-level exposure
  scores.
- Alternative realization treatments (V2, V3).
- Behavioral-response modeling (labor-supply ETI, realization-rate
  elasticity).
- General-equilibrium re-pricing of the asset stock.

[1.0.0]: https://github.com/Budget-Lab-Yale/AI-Fiscal/releases/tag/v1.0.0
[1.0.1]: https://github.com/Budget-Lab-Yale/AI-Fiscal/releases/tag/v1.0.1
