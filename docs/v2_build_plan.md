# AI-Fiscal v2.0 — build and test plan

**Status:** Proposed plan, 2026-09-20, branch `AI-Fiscal-V2.0`. Combines
`v2_flow_network.md` (what has to exist, by node) with
`lit_macro_to_micro_structures.md` (what to borrow, by node) into an
ordered sequence of build steps, each with its tests and its exit
gate. Supersedes the P0–P4 sketch in `v2_architecture.md` §9 where they
differ. Node IDs refer to the flow network.

## Principles

1. **v1.0 stays reproducible at every step.** A `frame` switch
   (`realized` = v1.0, `upstream` = v2) gates every new stage. A golden
   regression test, frozen before the first code change, asserts that
   `frame = realized` reproduces today's outputs on the synthetic
   fixture to the last dollar. No phase merges with that test red.
2. **Decide before coding.** Every node tagged *decision* in the flow
   network gets a numbered entry in a new `docs/v2_decisions.md` before
   the code that depends on it is written. Phase 0 exists for this.
3. **One definition per computation.** Receipts in
   `config/calibration/` are the source; yaml leaves and code constants
   derive from them, never duplicate them (the 0.30/0.70 asset-map
   split is the standing example of what to avoid).
4. **Contract tests at every module boundary**, in the style of the
   existing Step A invariant tests: conservation identities asserted,
   not assumed.
5. **Branch discipline.** `AI-Fiscal-V2.0` is the integration branch.
   Each phase is a feature branch merged by PR with CI green; `main`
   receives v2 only at release.

---

## Phase 0 — Gates, decisions, data pulls (no model code)

**Goal:** settle the shape-changing decisions and collect the inputs
that do not yet exist in the repo.

| Step | What | Source / borrow | Output |
|---|---|---|---|
| 0.1 | **Freeze the golden.** Run the current pipeline on the synthetic fixture for the full release grid; commit per-scenario revenue deltas, income deltas, and macro params to `tests/fixtures/golden_v1/`. Write `test-golden-v1.R` asserting equality under `frame = realized` | — | golden fixture + test |
| 0.2 | **Q1.2 share bridge (N13).** Read Karger w35046 Table 39's labor-share definition. Test the hypothesis `(comp + ½ proprietors)/GDP = 0.557 ≈ 0.555`. Decide the (Y, L0, K0) triple v2 sizes on | flow network §8.1; NIPA F.3 receipt | D1 |
| 0.3 | **Q1.1 base (N7/N18).** Broad $6,046B vs business-only $4,777B; rental in or out | — | D2 |
| 0.4 | **N16 residual policy.** Given D1, decide whether the 13% of NI outside L0 + K0_up is held fixed, scaled with g_y, or absorbed | Peichl 2009 (enforce identity at the interface) | D3 |
| 0.5 | **Q2.1 τ\* menu (N19).** Effective 0.147 / statutory 0.21 / a time-varying depreciation wedge for the build-out years. Bound below by AMR's 5–10% effective rate on software and equipment | CBO 59436 three-wedge decomposition; TaxProf/Politico FY2026 receipts | D4 |
| 0.6 | **Q1.3 reconciliation (R1).** Per channel: benchmark / inherit / historical ratio. Default proposal: historical SOI-line-to-NIPA-component ratio, i.e. CBO's method | CBO individual method; BSZ stable distributions | D5 |
| 0.7 | **N9 method.** Pull CBO Feb-2026 10-year economic projections income block (wages & salaries, domestic economic profits, proprietors' income; check for rental/interest/dividends) and revenue by category (IIT, payroll, CIT by FY). Decide constant-share vs CBO lines | CBO supplementary tables | D6 + `config/calibration/cbo_2026_02_income.csv`, `cbo_2026_02_revenue.csv` |
| 0.8 | **Payout inputs (N21).** Pull NIPA Table 1.12: profits after tax, net dividends, undistributed profits, 2015–2024. Decide whether p responds to the share shift | Karabarbounis-Neiman; Chen et al. | D7 + `config/calibration/nipa_1_12_payout.csv` |
| 0.9 | **Labor lane decision 1.** Aggregate target vs pure loss under displacement — this is D3's labor-side twin and must be decided jointly | labor doc "Decisions to settle" | D8 |
| 0.10 | **Fix the self-disagreeing benchmark.** `validation_benchmarks.csv` CIT 2030 470 → derived from 0.7 | — | receipt edit |

**Exit gate:** `docs/v2_decisions.md` D1–D8 written; three new receipt
CSVs committed with `_status`/`_source` siblings; golden test green.
Roughly one to two weeks, mostly reading and pulls.

---

## Phase 1 — Baseline module (N1–N4, N9, N11–N12)

**Goal:** one typed, year-indexed CBO baseline object replacing the
positional yaml leaves.

| Step | Build | Test |
|---|---|---|
| 1.1 | `config/cbo_baseline.csv`: rows by calendar year 2025–2036 with nominal GDP, real growth, wages & salaries, domestic profits, proprietors' income, IIT, payroll, CIT; `_source` column per row | schema test: required columns, contiguous years, no NA in horizon |
| 1.2 | `load_cbo_baseline(path, baseline_year)` in `02_params.R`, returning a list with `gdp_B`, `growth_path`, `factor_levels`, `revenue`. Remove `g_2026`/`g_2027plus` positional consumption; drop the `horizon_start_year == 2025` abort | `cum_base` and `g_y` for 2030 equal v1.0 values to 1e-12 (regression); rolling `baseline_year` to 2031 changes `cum_base` by exactly one more factor |
| 1.3 | Consumers 02, 04, 09, 15 read from the object; 15 takes the GDP path instead of re-deriving growth | golden test green; 15's productivity inversion equals its previous output |
| 1.4 | Pre-work items 4–5 from `v2_architecture.md` §8: `copy()` discipline for the shared `data.table` documented and enforced in 01/04; Step B macro block returned as a schema'd list with a validator | new `test-module-ownership.R`: mutating a module's return does not alter the caller's table; schema validator rejects a missing field |
| 1.5 | `11_validation.R::compute_revenue_aggregates` extended to payroll and total; validation rows for GDP, rev/GDP, IIT, payroll, CIT 2030 from the CBO revenue file | validation report lists all five with pass/fail |

**Exit gate:** golden green; `parameter_index` sheet shows the baseline
object's leaves; PR merged. About one week.

---

## Phase 2 — Upstream sizing, entity split, adding-up (N5–N7, N13–N18)

**Goal:** compute ΔΠ on the NIPA base and split it across entity
channels, with the macro identity enforced.

| Step | Build | Test |
|---|---|---|
| 2.1 | `config/entity_split.csv` *generated* from `kappa_corp_calculation.csv` by a small script (`code/make_entity_split.R`), never hand-edited; channel shares C/S/P/rent/int with an `ai_tilt` variant column (κ = 0.65) | shares sum to 1 ± 1e-9; κ_baseline = 0.4974 reproduced from the receipt; regenerating the CSV is a no-op diff |
| 2.2 | `frame` parameter in `scenario_params.yaml` (`realized` default until Phase 6) and in `load_params()` | unknown frame aborts |
| 2.3 | `size_upstream_increment(baseline, params)` in `04_allocate_capital.R`: `K0_up(2030)` per D6, `ΔΠ = g_K · K0_up`, `ΔL = g_L · L0` | ΔΠ matches hand calculation for M variant; `frame = realized` path untouched (golden) |
| 2.4 | `check_adding_up(ΔΠ, ΔL, g_y, Y0, policy = D3)` — hard assertion with the residual reported to the macro sidecar | identity holds to 1e-6 under each residual policy; a deliberately inconsistent θ triple fails loudly |
| 2.5 | `split_entity(ΔΠ, shares, tilt)` → five channel increments | channels sum to ΔΠ; tilt moves only C-corp and pass-through shares |
| 2.6 | `write_factor_channels()` sidecar gains per-channel columns | schema test on the sidecar |

**Exit gate:** golden green; `frame = upstream` runs end to end on the
fixture with the *old* downstream (channels collapsed to X) so the
plumbing is exercised before any tax logic changes. About one to two
weeks.

---

## Phase 3 — Entity CIT and payout/retention (N19–N21)

**Goal:** corporate tax modeled at the entity stage; the output-stage
wedge retired under `frame = upstream`.

| Step | Build | Test |
|---|---|---|
| 3.1 | `compute_entity_cit(ΔΠ_C, tau_rule)` with `tau_rule ∈ {effective, statutory, expensing_path}` per D4; `expensing_path` reads a year-indexed wedge from a receipt | ΔR_CIT = τ\*·ΔΠ_C for each rule; effective/statutory ratio = 0.70 |
| 3.2 | `split_payout(Π_after, p, b)` per D7: dividends, retention, optional buyback share routed to realization | payout + retention = Π_after; p-response option lowers p when θ1_K > θ0_K |
| 3.3 | Flip the `09_tables_figures.R:227` tripwire: under `upstream` the macro wedge is off and `delta_R_CIT` comes from 3.1; under `realized` unchanged. Instrument row relabeled `entity_cit_delta` for upstream | both-on aborts; realized golden green; upstream total = microsim total + entity CIT |
| 3.4 | Retire the duplicate payout definition: `asset_to_income_map.csv` public-equity split becomes `derived_from = p, r_lt` under upstream; realized frame keeps the literal for golden fidelity | test that the upstream split equals `p/(p + (1−p)·r_lt)` and its complement |
| 3.5 | Stage accounting test `check_capital_contract()`: `ΔΠ = CIT + payout + retention + ΔΠ_S + ΔΠ_P + ΔΠ_rent + ΔΠ_int` | identity to 1e-6 on fixture for all variants |

**Exit gate:** golden green; first real-vintage run of `frame =
upstream` on the cluster, headline ΔR_CIT compared against v1.0's wedge
for S/M/R and written to a memo. About two weeks.

---

## Phase 4 — Realization, reconciliation, per-channel allocation, PUF writer (N22, R1, A1–A3, P1–P6)

**Goal:** land NIPA-sized channel flows on the PUF with explicit
realization and a documented reconciliation policy.

| Step | Build | Test |
|---|---|---|
| 4.1 | `05_realization.R` becomes real: `apply_realization(channels, rates)` with `r_lt ∈ {annual, lifetime}` concepts, step-up φ, `r_R` from the retirement yaml, `r = 1` for interest, pass-through, rental. `realization.rate_r` and `realization.concept` enter the yaml with receipts | realized flow ≤ gross flow per channel; lifetime factor `1 − (1−r)φ` = 0.84 at defaults; V1 path (`r = 1` on all) reproduces the old `X_ltcg_V1` |
| 4.2 | `reconcile_to_puf(channel_flows, policy = D5)`: per-channel ratio table from `validation_benchmarks.csv` SOI rows over NIPA rows (extend the CSV with SOI Schedule E rental and net dividends rows) | benchmark policy leaves flows unchanged; inherit policy scales by the historical ratio; ratios logged to the sidecar |
| 4.3 | Per-channel across-unit allocation: dividends and LTCG against `equities`; pass-through against `pass_throughs`; interest against `bonds`; retirement against `retirement`; **rental** against real-estate holdings if `.ASSET_KNOWN` carries one, else by baseline `rent − rent_loss` (inherit) — decided in 0.3 | each channel's `Σ w·X_i` equals its flow; negative-base warning path still fires |
| 4.4 | `asset_to_income_map.csv` gains a `dispatch` column (`static_share` / `unit_ratio` / `cascade`) with load-time validation | unknown dispatch aborts; every class has exactly one dispatch |
| 4.5 | `06_build_counterfactual.R`: new writer for `rent`/`rent_loss` (P4); dividend flow to `div_pref`/`div_ord` by the unit's baseline qualified share; retention-realized to `kg_lt` via the existing `.augment_kg_lt` | `Σ w·ΔPUF` per line equals the realized channel flow; `kg_lt_years_held`/`basis` consistency test still green; rental delta lands only on units with a rental base under inherit |
| 4.6 | Extend the synthetic fixture generator if a rental base column is needed; regenerate deterministically | fixture test suite green; fixture diff reviewed |

**Exit gate:** golden green; `check_capital_contract()` extended to the
PUF stage; second real-vintage run with full upstream frame; income-by-
type deltas tabulated against SOI 2022 lines. About three weeks. This
is the hardest phase; realization concept (Q2.3) may need a second
decision entry after seeing real numbers.

---

## Phase 5 — CIT burden, targets, validation (new node N19→E6, E5, E7)

**Goal:** the evaluation outputs the flow network's §6 promises.

| Step | Build | Test |
|---|---|---|
| 5.1 | `distribute_cit_burden(ΔR_CIT, rule ∈ {none, OTA, TPC, CBO})` in `08_aggregate.R`: OTA 81.5/18.5 with supernormal share to equity holders; TPC 60/20/20; CBO 75/25 by capital income and labor income shares already on the file | burden sums to ΔR_CIT; `none` reproduces current decile tables |
| 5.2 | Income-by-type growth table (E5): Δ by line ÷ baseline line, with the SOI/NIPA benchmark column | table rows match the sidecar totals |
| 5.3 | Validation report extended: rev/GDP, CIT 2030, IIT, payroll against the CBO revenue file; per-channel realized/NIPA ratios against history | report generated in CI on the fixture; on real data flags any ratio outside its historical range |
| 5.4 | LO/CO decomposition carries through unchanged; add a third "entity" component so `ΔR_total = LO + CO + entity + interaction` | existing `test-aggregate.R` identity extended |

**Exit gate:** publishable workbook gains `entity_cit`, `cit_burden`,
`income_by_type`, `validation` sheets. About one to two weeks.

---

## Phase 6 — Scenario axes, grid, figures, docs, release candidate

| Step | Build | Test |
|---|---|---|
| 6.1 | Register new axes in the `00_utils.R` registry: `frame`, `tau_rule`, `payout`, `realization_concept`, `cit_burden`. Headline grid = 3 variants × 2 share modes × 3 labor × upstream defaults; everything else as named sensitivity runs (Q5.1) | `test-scenario-ids.R` extended; 08 suffix allowlist rejects unregistered codes |
| 6.2 | Figures: CIT split figure (`02_macro_cit_split`) redrawn from entity stage; new payout/retention and realization sensitivity panels | figure smoke tests on fixture |
| 6.3 | Docs: `ai_fiscal_methodology.md` v2 sections; `v2_architecture.md` marked as implemented-with-deviations; CHANGELOG `2.0.0-dev`; parameter_index regenerated | doc-code consistency check: every yaml leaf appears in the methodology parameter table |
| 6.4 | Full real-vintage run on the cluster; v1.0 vs v2 headline memo; quantify the M2 pass-through leak on real data (open since v1.0) | — |
| 6.5 | Flip `frame` default to `upstream`; keep `realized` as a documented legacy mode with its golden test | golden green under `realized`; new golden frozen for `upstream` |

**Exit gate:** release candidate on `AI-Fiscal-V2.0`, PR to `main`
opened. About two weeks.

---

## Parallel lane — labor extension (P3), per `labor_exposure_extension.md`

Runs alongside Phases 2–5 once D8 is set. Its own phases are already
specified in the labor doc; the additions here are the tests and the
tie-ins.

| Step | Build | Test |
|---|---|---|
| L0 | Gate: between/within-cell variance decomposition of SOC exposure on CPS ASEC; confirm cell columns on a real vintage | decision entry D9: build `EXPocc` or not |
| L1 | Extensive machinery with uniform exposure and permanent job loss: weight-splitting, fix the `y_l == 0` inert class, the positive-subset guard, the `uniroot` bracket; introduce `check_labor_contract()` | post-split weights sum to pre-split; `Σ w·y_l1 = L1` under D8's rule; displaced rows have zero labor lines and zero FICA including `trad_contr_er1` |
| L2 | Exposure metric from the cell CSV; register `EXP*` × `INT/EXT/MIX` codes | monotonicity of cell incidence in exposure; contract test per form |
| L3 | Duration mixture and UI: `ui` column mutation, UI kept out of the factor identity, own column in the sidecar | UI total equals weeks × amount; factor identity unchanged by UI |
| L4 | Grid integration, figures, the debt/GDP tie-in's displaced-worker outlays | 15's flag at `:16` retired |

---

## Test architecture summary

| Layer | What | Where |
|---|---|---|
| Golden regression | `frame = realized` reproduces v1.0 on the fixture, all scenarios | `test-golden-v1.R` (Phase 0.1); `test-golden-v2.R` after 6.5 |
| Contract tests | `check_capital_contract()` per stage (N16, E7); `check_labor_contract()` per form | `test-capital-contract.R`, `test-labor-contract.R` |
| Receipt-to-config | generated CSVs are no-op on regeneration; yaml leaves equal receipt values | `test-receipts.R` |
| Schema | baseline object, sidecar, asset map dispatch, scenario IDs | existing + `test-baseline.R` |
| Fixture CI | full pipeline on the synthetic fixture on every push | existing GitHub Actions |
| Real-vintage runs | end of Phases 3, 4, 6 on the cluster; memo each time | `results/` vintages |
| Validation gate | publishable workbook only if the validation sheet has no fails | 11 + 08 |

## Dependencies and order

```
Phase 0 ──► Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
   │                                                                  ▲
   └── D8 ──► L0 ──► L1 ──► L2 ──► L3 ──► L4 ───────────────────────┘
```

Phases 1–5 are strictly sequential (each reads the previous stage's
object). The labor lane joins at Phase 6 for grid integration. Total
elapsed for the capital spine is on the order of ten to twelve weeks of
focused work; the labor lane adds four to six in parallel.

## Risks specific to this plan

- **D1/D3 may not close cleanly.** If Karger's share cannot be mapped
  to a NIPA aggregate, N13 becomes a stated assumption rather than a
  derivation; the adding-up test then asserts against the assumed
  triple. Acceptable, but say so in the methodology.
- **Realization concept (Q2.3) moves realized LTCG by up to 4×.**
  Phase 4 should run both concepts on real data before D-entry, not
  pick from the desk.
- **The expensing wedge is a moving target.** FY2026 receipts are
  still coming in; `expensing_path` should be a receipt with a vintage
  date, refreshed at release.
- **Rental base column.** If the vintage has no real-estate holdings
  column, rental allocation is inherit-only, which weakens the
  household-side story for 17.7% of the base. Decide in 0.3 whether
  that is acceptable or rental is dropped.
