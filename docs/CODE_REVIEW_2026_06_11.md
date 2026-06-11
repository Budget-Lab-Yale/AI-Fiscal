# Full-repo code review — 2026-06-11

**Status update (same day):** ALL FIVE WAVES FIXED. Docs `f2b070a`;
wave 1–2 `61093df` (C1, M1, M2, M3, M4, M5, M9, M10); wave 3
`6f16e10` (M12, M13, M14); wave 4 `4ec4cb9` (axis registry, 08
unknown-suffix abort, 09 CIT zero-delta tripwire, M8); wave 5
`5341c41` (M6, M7, M11, M15, test items T1–T4, new test-params.R +
test-scenario-ids.R). Suite: 132 PASS / 0 FAIL / 2 Windows skips
(was 95 PASS). Empirical note: the M2 warning fires even on the
synthetic fixture (1,915 units' passthrough flow unwritten) — the
leak is real; quantify on real data at the next full run.
**Still open:** the "Selected minors" list below only (CLI-parser
quirks in 00, 08 receipts-total instrument assertion, stale-prose
sheets, 06 overwrite leftovers, sheet-name truncation, etc.) — none
results-critical; queue for v0.1.1.

Four parallel reviewers over code/, tests/, config conventions, with
a v2-readiness lens (see `docs/v2_architecture.md`). Line numbers as
of commit `79fb365`. Severity: **C** = can corrupt results or block
the pipeline; **M** = wrong behavior on plausible inputs / silent
data loss; **m** = polish. The v0.1.1 queue in `todo.md` §C4 still
stands; items below are new findings.

## Critical

- **C1. `06_build_counterfactual.R:146-190` — merge-order vs
  file-order row misalignment (latent).** `merge(dt, ..., by="id")`
  re-sorts `dt` by id, but `baseline_cache$cap_holdings` (built
  positionally from `dt_baseline` at 96-107) and the direct
  `dt_baseline$scorp_*`/`part_*` column references at 175-182 stay in
  fread file order. Steps 2-3 combine them element-wise. Correct
  *only* while the vintage CSV is stored in id-sorted order with id
  read as integer; an unsorted vintage or character-typed id silently
  scrambles every unit's passthrough reconstruction, and no existing
  invariant test would catch it (verified: no `setkey`/`setorder`
  anywhere in code/; `write_factor_channels` at 322-332 does the same
  merges *safely* using merged-table columns). Fix: key/sort
  `dt_baseline` once on load, derive the cache from the merged table,
  and add `stopifnot(identical(dt$id, dt_baseline$id))` after the
  merges. **Verified directly, not just by a reviewer agent.**

## Major — correctness

- **M1. `07_run_tax_sim.R:72-84` — Windows path-separator failure in
  `runscript_name_from_path()`.** `normalizePath()` default
  `winslash="\\"` vs `.Platform$file.sep "/"` means
  `startsWith(abs, prefix)` is always FALSE on Windows → spurious
  "Runscript is not under the Tax-Simulator config tree" abort.
  Pipeline cannot start on a Windows box. Fix: `winslash = "/"` both
  sides.
- **M2. `06:164-171` — silently dropped passthrough mass.** Units
  with `w_tot == 0` (no positive baseline passthrough capital
  holdings) but `X_passthrough_ordinary > 0` get flow_share 0 and the
  flow vanishes from the written counterfactual — a second,
  undocumented aggregate-identity leak distinct from the known 04
  clamp. Log the dropped total at minimum; better, route residual.
- **M3. `06:100,104,178,182` — passive capital share 0.75 hard-coded
  4×,** duplicating `passthrough.passive_capital_share` from the yaml
  that `01_load_data.R` consumes parametrically. Editing the yaml
  silently desynchronizes YiL/YiK from 06's reconstruction. Pass
  `params` into `compute_baseline_cache`.
- **M4. `06:146-149` — NA propagation after left joins.** An id in
  `dt_baseline` missing from step_a/step_b gives NA `rho_i` → NA
  wages/income written to the cf CSV with no error. The sidecar
  writer defends the identical joins (327-328); the cf builder
  doesn't. Add NA-fill or `stopifnot(!anyNA(...))`.
- **M5. `06:285` — `file.symlink` return ignored.** On Windows
  without developer mode it returns FALSE with only a warning →
  scenario folder missing every baseline file → failure surfaces deep
  inside Tax-Simulator. Check the return; abort with a hint (or
  `file.copy` fallback).
- **M6. `15_blsmm_debt_gdp.R:208-211` — dead error guard.**
  `r_ai_annual_by_variant` is a named numeric vector;
  `vec[["unknown"]]` throws subscript-out-of-bounds, so
  `if (is.null(target_g))` never fires — unknown variant dies with an
  opaque base-R error instead of the intended `cli_abort`. Use
  `variant %in% names(...)` / NA check.
- **M7. `make_synthetic_tax_units.R:63` — `sample()` scalar gotcha.**
  For an integer column with a single non-NA constant `k>1`,
  `sample(prof$unique, n, TRUE)` draws from `1:k` not `rep(k, n)`
  (reviewer executed R to confirm); an all-NA integer column passes
  the `!is.null` guard as `integer(0)` and crashes the generator.
  Latent until the next vintage adds a constant flag / coded column —
  and occupation codes for the v2 labor module would route exactly
  here. Fix: `prof$unique[sample.int(length(prof$unique), n, TRUE)]`.
- **M8. `09_tables_figures.R:157-198` — NA into the headline
  number.** A scenario whose `(variant, share_mode)` is missing from
  the macro CSV (stale after grid edit / partial rerun) yields
  `delta_R_CIT = NA` → `total_with_macro_cit = NA` flowing into the
  publishable bundle with no warning. Assert every parsed scenario
  matched a macro row.
- **M9. `04_allocate_capital.R:111 vs 127` — across-unit base is
  unclamped.** Negative `pass_throughs` enter `A_base` rowSums, so
  the header claim "X_i is always non-negative" is unverified; a unit
  with negatives exceeding other assets gets X_i < 0 → negative
  retirement residual, no guard/log. Add a check + dropped-mass log
  (extends the known clamp item, which covers only within-unit).
- **M10. `04:248-251` — `lookup_shares` zero validation.** Missing
  map row → `numeric(0)` arithmetic with a cryptic error; shares not
  summing to 1 silently leak mass, and existing invariants check only
  class-level sums. Validate the map at load (coverage + share sums).
- **M11. `11_validation.R:129-145` — receipts year never filtered.**
  `yr_col` is located, warned about, then unused; `rec[[iit_col]][1]`
  takes row 1 regardless of year, so two-year runs can compare 2029
  receipts against 2030 benchmarks silently — in the only code path
  `--receipts` exists for.
- **M12. `00_ai_fiscal_sim.R:156-165` — single-year `--years` passes
  the FY guard** (file for years_min exists) → Tax-Simulator's FY
  adjustment drops the only year → empty receipts after a full run.
  Assert ≥ 2 distinct years.
- **M13. `00_utils.R:8-14` + `01_load_data.R:117-132` —
  `weighted_quantile` silent NA** at p≈1 (float cumsum), empty input,
  or NA-containing wage subset; feeds SYZ `W_star` → NA cap shares →
  NA YiL/YiK cascade with no error. Clamp `cw` tail, guard empties,
  abort on NA `W_star`, and `anyNA(YiL/YiK)` check post-split.
- **M14. `02_params.R:136-139` — CBO growth keys consumed
  positionally.** `g_2026`/`g_2027plus` assume
  `horizon_start_year == 2025`; rolling the baseline forward silently
  shifts the compounding. Stopgap: assert the year; real fix is the
  v2 baseline module. Also (`:142-150`) no value-range validation on
  `s1`/`L0`/`gy` — a typo'd `s1: 6.2` sails through.
- **M15. `10_figures.R:1705-1766` — eager figure construction.** All
  `fig_*()` run during list construction; the tryCatch wraps only
  `.fig_save`, so one data-prep error kills the whole suite before
  any PNG/xlsx is written. Wrap construction per-figure.

## Major — v2-blocking pattern (silent axis drops)

The scenario-axis knowledge is hand-synced across ≥6 sites, and every
one fails by NA-coercion → silent row drop, never an abort:
`09:61` regex (any non-`S[0-9]` labor code or 5th axis → scenario
vanishes from the grid), `09:72-75` + `10:1532-1554` factor levels,
`08:54-61` flavor parser (**unknown suffix → silently treated as
"both" and aggregated as a canonical cell**), `08:507-568` guide
table, `09:386` label map, `15:338-360` figure layer (pinned to
exactly 3 variants). Consolidate into one generated axis registry +
abort-on-unknown before any new axis lands. Also add the 09
zero-CIT-delta assertion (`revenues_corp_tax` microsim delta == 0
before macro layering) as the v2 entity-tax double-count tripwire.

## Test-suite findings

- **T1. Shared-state contamination:** `helper-pipeline.R:47-50` —
  `allocate_capital` mutates the shared `dt_baseline` by reference;
  every later test file sees the analytic columns. Benign today only
  because all tests use identical params. `copy()` in the helper.
- **T2. Coverage holes:** 02_params (zero tests — share-mode-F
  algebra is ideal unit-test material), 09 (zero — the axis parser
  CLAUDE.md says must change with any new axis ships green), 10
  (zero). 01 SYZ split is positivity-smoke only: a sign error keeping
  both aggregates positive passes everything.
- **T3. Absolute $1e-3 tolerances** on trillion-scale weighted sums
  (test-counterfactual.R:36,43,62,140-141) are ~1e-16 relative —
  potentially flaky on full PUF; use relative form.
- **T4. Substrate silence:** helper messages on synthetic fallback
  but not when real PUF is present — local-vs-CI run different data
  with no marker. One-line message.

## Selected minors (full agent transcripts not retained; top items)

- `00:274-279` CLI parser consumes a following `--flag` as a value;
  `--flag=` empty values accepted; bad `--years` shapes → NA with
  misleading abort; `--multicore`/`--vintage` validated only after
  all 54 folders are built.
- `00:129` `sub("\\.csv$", ...)` no-match → macro CSV overwrites the
  runscript when `--runscript-path` lacks `.csv`.
- `04` Step B internals not dot-prefixed (repo convention); NA in
  asset columns → cryptic guard errors rather than cli_abort.
- `06:18` header still says 08 "not yet implemented"; `06:272-290`
  overwrite doesn't clear stale files/dangling symlinks from the
  scenario dir; `06:357` default `years = "2029:2030"` hardcoded.
- `08:156-160` receipts total hardcodes 7 instruments while the
  per-instrument list is dynamic — new column → inconsistent table;
  `08:541-551,680-684,732-733` prose sheets hardcode yaml-derived
  numbers (s1, sigma, $486.1B) that go stale on recalibration.
- `09:492,609-617` key_parameters sheet hardcodes year labels
  ("2026", "2025-2030", "2030") despite parameterized `year`.
- `10:60-63` comment claims an `ai_exposure` gate exists in 03 —
  false in this repo (true only in the archived dev tree); `10:274`
  31-char sheet-name truncation collides once a second realization
  axis exists; `10:367,458` `unname()` makes two palettes positional.
- `11:17` usage says `10_validation.R`; zero-valued benchmark →
  NaN kills the non-fatal contract (none today).
- `15:338-346` figure layer pinned to S/M/R and `x = 3.5` baseline
  annotation (assumes exactly 3 variants).
- `make_synthetic:227-233` CLI lacks `source_dir` despite the abort
  hint telling users to set it.

## Clean (verified, not just unflagged)

No absolute paths, no `setwd()` outside the documented on.exit
pattern, no base read.csv/write.csv except 15's deliberate
`check.names=FALSE` BLSMM inputs (correct — keep, add a comment),
seeds present and correctly placed everywhere RNG exists, naming
conventions uniform, 07's env/exit-code handling sound, 08's gini /
decile / interpolation arithmetic verified correct, fwrite/fread
conversion in 15 left no bugs, `.augment_kg_lt` and the R1 cascade
internally consistent, CI workflow matches local entry point.

## Suggested fix order

1. C1 + M1 (results integrity; Windows bootstrap).
2. M2/M3/M4/M9/M10 — the 04/06 identity-leak cluster (one PR).
3. M12/M13/M14 — the silent-NA / guard cluster in 00/01/02.
4. Axis registry + 08 suffix abort + 09 CIT tripwire (v2 pre-work,
   see `v2_architecture.md` §7).
5. M6/M7/M8/M11/M15 + test items as a follow-up PR.
