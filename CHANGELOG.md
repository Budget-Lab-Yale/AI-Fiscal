# Changelog

All notable changes to AI-Fiscal are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
