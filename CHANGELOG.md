# Changelog

All notable changes to AI-Fiscal are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Repo consolidation: this is now the single canonical repo (the
  internal development tree is archived). Lineage is documented in `CLAUDE.md`.
- `docs/v2_architecture.md` — ideation sketch for the v2 model
  generation (CBO baseline module, separable labor/capital modules,
  upstream capital sizing).

### Changed

- **Notation migration to align the codebase with the methodology
  document.** Unified per-unit income notation `Y_{j,i}^X` throughout
  code, tests, and docs. Symbol renames: the labor-inequality parameter
  `sigma` → `lambda` (`λ`); the normalized-labor-growth scalar `alpha`
  is removed in favor of the direct cumulative labor-growth rate `g_l`
  (`g_l = (θ1_l·(1+g_Y) − θ0_l)/θ0_l`); growth bumps `gy/gk` → `g_y/g_k`;
  per-unit columns `YiL/YiK` → `y_l/y_k`; aggregate-dollar fields
  `L0_dollar/K0_dollar/Y0_dollar` → `y0_l_dollar/y0_k_dollar/y0_dollar`;
  share variables `L0/K0/s1` → `theta0_l/theta0_k/theta1_k`. These
  propagate to **reader-facing workbook columns** (`parameters`,
  `cell_params`, `labor_inequality` sheets): `sigma_S2/S3` →
  `lambda_S2/S3`, `alpha` → `g_l`, `L0_B/L1_B/K0_B/K1_B` →
  `y0_l_B/y1_l_B/y0_k_B/y1_k_B`.
- **Config key rename:** `shock.variants.{S,M,R}.s1` →
  `shock.variants.{S,M,R}.theta1_k` in `config/scenario_params.yaml`
  (post-shock capital share).
- Corporate-tax wedge `eta` documented consistently with the code's
  definition `η = τ_C·κ·Y0^K / R^{CIT}_CBO`, so that
  `ΔR^CIT = X · R^{CIT}_CBO / Y0^K` (no behavioral change; the methodology
  doc previously stated `η` reciprocally).

### Removed

- `docs/ai_fiscal_methodology.docx` (superseded by the markdown
  methodology doc and the standalone review docx).

### Fixed

Review waves 1–2 (numbers-identical to v1.0 except new guards):

- Counterfactual builder: order-preserving update joins replace the
  re-sorting `merge()` calls, closing a latent row-misalignment hazard
  between merge-sorted flows and file-ordered baseline vectors; id
  uniqueness, row-order, and post-join NA assertions added (C1, M4).
- `runscript_name_from_path()`: `winslash = "/"` so the containment
  check works on Windows (M1).
- Passthrough flow dropped for units with no positive sub-bucket
  holdings is now surfaced with a `cli_warn` carrying the weighted
  dollar mass (M2) — it fires on the synthetic fixture, so expect it
  on real runs too.
- SYZ passive capital share is read from
  `passthrough.passive_capital_share` in the yaml everywhere
  (`compute_baseline_cache()` gained a `params` arg); previously
  hard-coded as 0.75 in four places in 06 (M3).
- `allocate_across_units()` warns when any unit carries a negative
  all-assets base (would receive X_i < 0) (M9).
- `lookup_shares()` validates the asset-to-income map: required
  income types present exactly once, numeric shares, sum to 1 (M10).
- `write_counterfactual_scenario()` aborts with a Windows-specific
  hint when `file.symlink()` fails instead of ignoring the return
  value (M5).
- Documentation staleness fixes across 06/09/10/11, README, CLAUDE.md,
  and the methodology (gross-home-values wording; 21-column
  cell_params variable list).

Review waves 3–5 (guards, registry, test hardening):

- `--years` validated for shape and a >= 2-year span;
  `weighted_quantile` hardened (empty/NA/zero-weight aborts,
  float-proof tail); SYZ W* sample and percentile validated; YiL/YiK
  NA tripwire after the split; `load_params` asserts
  `horizon_start_year == 2025` (positional CBO growth keys) and
  validates `r_ai_annual`, `L0`, `s1` ranges.
- **Scenario-axis registry** in `00_utils.R` — single source for axis
  codes/labels/flavor suffixes, consumed by 00/08/09/10/15 (was six
  hand-synced literal vectors, each failing by silent NA-drop). 08
  aborts on unregistered IDs/suffixes; 09 warns before dropping
  unparseable IDs; the scenario_guide is asserted registry-consistent;
  10 names any value it coerces to NA.
- Tripwires: 09 aborts if microsim corp-tax deltas are non-zero before
  layering the macro CIT wedge (v2 entity-tax double-count guard), and
  if a parsed scenario finds no macro-summary row (stale-CSV NA
  headline).
- BLSMM variant lookup fixed (dead `is.null` guard on a named vector);
  fixture generator immune to the `sample()` scalar gotcha; validation
  receipts comparison filters to the requested year; one failing
  figure no longer kills the whole suite.
- Tests: helper no longer leaks Step B columns into shared state;
  new coverage for 02 derivation algebra and the scenario-ID layer;
  identity tolerances converted to relative form; helper announces
  real-vintage vs synthetic substrate. 132 PASS (was 95).

## [1.0.0] — 2026-06-22

Initial public release. Income-frame microsimulation of an AI-driven
labor-to-capital income shift, built on the Budget Lab Tax-Simulator.

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
  sheets — readable without the code.
- **testthat suite** plus a synthetic PUF + SCF fixture
  (`tests/fixtures/synthetic_tax_data/`) for I/O / schema smoke testing
  without PUF access.
- **Documentation.** Main methodology in
  `docs/ai_fiscal_methodology.md`; full R1 and V1 derivations in
  `docs/ai_fiscal_methodology_appendix.md`.
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

[unreleased]: https://github.com/Budget-Lab-Yale/AI-Fiscal/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Budget-Lab-Yale/AI-Fiscal/releases/tag/v1.0.0
