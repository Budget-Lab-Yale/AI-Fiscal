# AI-Fiscal v2 — architecture sketch

**Status:** Ideation. Drafted 2026-06-11 from a design conversation;
nothing here is implemented. Companion docs:
`realization_and_wealth_extensions.md` (the earlier wealth-frame /
realization plan, which §6 below subsumes) and
`ai_fiscal_methodology.md` (the shipped v0.1.0 model).
**Version label:** "v2" names the second *model generation*
(re-architecture), not necessarily the git tag it ships under —
release numbering TBD (could land as the 0.2.x series).

## 1. The idea in one paragraph

v0.1.0 sizes the AI shock directly in realized-1040 units
(`X = g_k · K_0` with `K_0 = Σ w · YiK`) and pushes it onto PUF income
lines in one step, with corporate tax bolted on as an output-stage
macro wedge. v2 inverts this: a **baseline module** ports the CBO
macro baseline (GDP path, factor shares, revenue levels); a **shock
specification** perturbs that baseline (GDP growth + labor/capital
share shift, calibrated to Karger et al. or successors); and two
**propagation modules** — labor and capital — carry the factor-level
shocks down to the PUF. The capital shock is applied far *upstream*
of taxable income (entity-level returns at the national-accounts
level) and flows *downstream* in a model-driven way: entity legal
form → entity tax → retention vs payout → asset-class flows →
realization → PUF lines. Realization and entity taxation become
modeled stages instead of by-construction assumptions.

```
[1. CBO baseline module]
    GDP path Y_t, labor share L_t, capital share K_t,
    IIT/CIT/payroll baselines, rev/GDP anchors
        │
[2. Shock spec]  (variant × share mode, Karger-calibrated)
    Δlog Y, Δ(labor share)  →  g_L (labor income), g_K (capital income,
    national-accounts level, PRE-tax, PRE-realization)
        │                                  │
[3a. LABOR MODULE]                [3b. CAPITAL MODULE]
    target: L1 = L0·(1+g_L)           target: ΔΠ = g_K · K0_upstream
    forms: S0/S2/S3 (now),            stage 1: entity split
      CPS×AI-exposure cells (next)      (C-corp / pass-through /
    contract: per-unit YiL1,             household-direct / retirement)
      Σw·YiL1 = L1                    stage 2: entity tax (CIT here,
        │                                not at output stage)
        │                             stage 3: retention vs payout
        │                             stage 4: across/within-unit
        │                                allocation (v0.1.0 machinery)
        │                             stage 5: realization module
        │                                (rates per class; was Step C)
        └──────────┬──────────────────────┘
[4. Counterfactual PUF writer]  (v0.1.0 step 06, survives)
        │
[5. Tax-Simulator]  →  [6. Aggregation / deliverables / BLSMM]
```

## 2. Baseline module (new)

Port the CBO baseline as a first-class, validated data object rather
than hand-transcribed scalars.

- **Contents:** year-indexed GDP (level + growth), CBO revenue
  baseline by source (IIT, CIT, payroll), and factor shares (CBO
  doesn't publish a labor share directly — derive from NIPA/BLS with
  the CBO GDP path; calibration receipt required).
- **Why:** the v0.1.0 review found the CBO inputs scattered and
  fragile — `g_2026`/`g_2027plus` keys consumed positionally in
  `02_params.R:136-139` (rolling the baseline forward silently
  corrupts `gy`), CBO yaml fragments re-read inline mid-output in
  `09_tables_figures.R`, and GDP scaling hardcoded as one year of
  growth. All of that becomes `load_cbo_baseline()` → a single typed
  object consumed by 02, 04, 09, and 15.
- **Validation:** promote GDP and rev/GDP rows into
  `config/calibration/validation_benchmarks.csv` and extend
  `11_validation.R::compute_revenue_aggregates` to payroll/total
  (currently IIT/CIT only) — the benchmarks CSV already carries the
  NIPA factor rows a share-shock block needs.

## 3. Labor module

**Contract** (unchanged in spirit from Step A, formalized): consume
`(id, weight, YiL)` plus a target `L1`; emit per-unit `YiL1` with
`Σ w·YiL1 = L1` and documented treatment of non-positive baseline
units. The v0.1.0 review confirmed Step A is already fully separable
— its only capital-side tie is deriving `L1` internally from
`(alpha, gk)`; v2 passes `L1` (or `g_L`) in explicitly from the shock
spec, severing that tie.

**Forms:**
- **S0/S2/S3** (proportional / compressive / expansive) — carry over
  as-is. The log-affine + uniroot-renormalization machinery
  (`03_shock_labor.R`) survives unchanged.
- **CPS × AI-occupation-exposure (sketch, next form to build):**
  1. Take occupation-level AI exposure scores (candidates: Eloundou
     et al. GPTs-are-GPTs, Felten et al. AIOE, Webb patent-based,
     Anthropic Economic Index task-usage measures — pick and
     document; possibly an ensemble with a sensitivity axis).
  2. Merge onto CPS ASEC at the occupation level; collapse to cells
     defined on dimensions the PUF can also see. **Constraint:** the
     PUF carries age, sex, filing status, dependents, and full income
     composition — but no occupation, industry, or education (and the
     synthetic fixture confirms: nothing to key on beyond
     age × sex × income). So cells are something like
     age-band × sex × wage-decile (× filing status), with cell
     exposure `e_c` = CPS earnings-weighted mean exposure.
  3. Assign `e_c` to PUF units by cell; apply a cell-conditional
     transform `YiL1_i = (1 + β·e_c(i)) · YiL_i` (sign of β per
     scenario: displacement vs augmentation), solving β by the same
     uniroot-to-aggregate + rescale pattern S2/S3 use.
  4. Module-specific validation: cell-level wage bill CPS-vs-PUF
     reconciliation before applying any shock.
  - **Open questions:** exposure ≠ displacement (need an explicit
    mapping assumption); within-cell heterogeneity is lost (cells are
    the resolution ceiling); CPS topcoding at high wages where the
    PUF is precisely the better source — consider blending exposure
    gradients only up to the CPS-reliable range and reverting to
    decile-rank extrapolation above.

**Naming guard:** don't reuse "S1" for the exposure form (S1 is the
archived dev repo's AI-exposure scenario, different construction).
Give v2 forms descriptive codes; see §7 on the scenario-ID problem.

## 4. Capital module

The center of the re-architecture. v0.1.0's single step
`X = g_k·K_0 → wealth-proportional allocation → PUF lines` becomes a
staged cascade. Per stage:

1. **Upstream sizing.** `ΔΠ = g_K · K0_upstream` where `K0_upstream`
   is a national-accounts capital-income base (NIPA: corporate
   profits + proprietors' capital share + rental + net interest),
   *not* the on-1040 realized base. The calibration receipts for this
   base already exist in `config/calibration/nipa_2024_z1_f3.csv`.
2. **Entity split.** Decompose ΔΠ by where it accrues: C-corp
   profits / pass-through (S-corp, partnership, proprietor) /
   household-direct (interest, rental) / retirement-account-held
   claims. Shares from NIPA × SOI legal-form data (the S-corp ~20%
   share receipt exists in `kappa_corp_calculation.csv`); an
   AI-specific tilt (software/IP capital concentrated in C-corps) is
   a sensitivity axis the calibration README already anticipates.
3. **Entity tax.** CIT applies here — statutory rate × effective
   wedge on the C-corp slice — *replacing* the v0.1.0 output-stage
   `eta_corp` layering in 09. **Double-count tripwire** (from the
   review): 09 adds `delta_R_CIT` unconditionally on the assumption
   that the microsim never touches `revenues_corp_tax`; the moment v2
   models CIT upstream, that layering must be switched off, and an
   assertion (`microsim corp-tax delta == 0` before layering) should
   land *now* so the conflict can't happen silently.
4. **Retention vs payout.** After-tax C-corp profits split into
   payout (dividends; calibrate payout ratio to NIPA personal
   dividends — buybacks raise a classification question: economically
   payout, taxed as realization) and retention (wealth accrual on
   equity holders, queued for the realization module). This stage has
   *no home* in v0.1.0 — `X_to_units = X` at `04_allocate_capital.R:85`
   is a hard-coded 100%-distributed assumption. The natural insertion
   point (per the review) is between `compute_macro_targets` and
   `allocate_across_units`. The dormant `scale_gross` machinery in
   06's factor-channels sidecar (X_macro ≠ X_distributed) is the
   vestigial hook for exactly this distinction.
5. **Household allocation.** The v0.1.0 across-unit (wealth-
   proportional) and within-unit (asset-class share) allocators
   survive — the review confirms both are frame-agnostic given an
   arbitrary scalar/per-class flow. What changes: allocation happens
   per channel (dividend flow, accrual flow, pass-through flow,
   interest flow), each against the appropriate holdings base, rather
   than once for a single X. `config/asset_to_income_map.csv` is the
   right *shape* for the channel map but needs a dispatch column
   (static-share vs unit-ratio vs cascade-handler) and load-time
   validation (the review found it consumed with zero checks and only
   half-alive).
6. **Realization module** (was Step C, becomes real). Retained-
   earnings accrual → realized LTCG via explicit per-class rates.
   All the calibration groundwork is in
   `realization_and_wealth_extensions.md` §3: CRS R41364 61% lifetime
   anchor vs annual anchors (CBO-implied 0.24, PUF-implied 0.16,
   JCT/AH 0.20–0.35), the lifetime-vs-annual labeling decision, and
   the step-up haircut. The retirement slice keeps the existing R1
   cascade (review: self-contained, reusable) but its *no-discount*
   justification is income-frame-specific and must be revisited —
   under upstream sizing the flow arrives pre-realization, so the
   `r_R`-based conversion from the extensions doc §4 applies.

**Aggregate contract:** the staged flows must satisfy an accounting
identity — ΔΠ = entity tax + payout + retention + pass-through +
direct, and the sum of per-unit PUF deltas equals the
distributed-flow total. These become module conformance tests (§8).

## 5. What survives from v0.1.0 (review-verified)

| Component | Verdict |
|---|---|
| `03_shock_labor.R` S0/S2/S3 machinery | survives; take `L1` as input |
| `04` across-unit + within-unit allocators, R1 cascade | survive as capital-module stages 5–6 |
| `04::compute_macro_targets` (X = gk·K0, eta_corp wedge) | replaced wholesale by stages 1–4 |
| `05_realization.R` | grows from placeholder into the stage-6 module |
| `06` PUF writer, kg_lt augmentation, runscript plumbing | survives (after the alignment fix; its `X_<type>` column interface is exactly the contract the capital module should emit) |
| `07_run_tax_sim.R` | survives untouched (axis-agnostic) |
| `08_aggregate.R` aggregators | survive; suffix parser needs an allowlist |
| `09` CBO fragments, macro-CIT layering | absorbed into baseline module / entity-tax stage |
| `15` BLSMM tie-in numeric core | survives; feed it the baseline module's GDP path instead of re-deriving growth |

## 6. Relationship to the wealth-frame plan

`realization_and_wealth_extensions.md` proposed re-denominating X in
wealth units (ΔW = gW·K0_wealth) with per-class realization rules.
The v2 capital module **subsumes** that plan: upstream entity-level
sizing + retention/payout + explicit realization delivers everything
the wealth frame was for (realization-rate policy levers, accrual vs
cash-flow distinction) while staying denominated in income flows at
the national-accounts level — which sidesteps the `gW = f(gk, r̄)`
conversion problem the extensions doc flagged as its hardest open
question (§2.3). The extensions doc remains the authoritative source
for the realization-rate calibration (§3) and the retirement
constants (§4); its Phase 1–6 plumbing plan (frame toggle in the
yaml) is superseded by the module architecture here.

## 7. Pre-work in the current codebase (do before the re-architecture)

From the 2026-06-11 full-repo review — these get strictly more
dangerous once a second sizing frame and per-entity flows multiply
the paths through the code:

1. **Fix the criticals/majors:** 06 merge-order misalignment (the
   one that can silently scramble per-unit results), 07 Windows
   `winslash` bug, 15 dead variant guard, fixture-generator
   `sample()` scalar bug, 06's hard-coded 0.75 passive share (yaml
   duplication), symlink return-value check, NA-join guards in 06.
2. **Consolidate the scenario-axis registry.** Today the axis
   knowledge lives in ≥6 hand-synced places (`release_specs()`,
   09's regex + factor levels + label map, 08's guide table + suffix
   parser, 10's `.restore_axes`, 15's figure layer) and *every* one
   fails silently (NA-coerce → drop) rather than loudly. One
   generated spec structure consumed everywhere, plus
   abort-on-unknown-suffix in 08 — this is the single highest-value
   v2 enabler, because v2 adds axes (capital-module variant,
   labor-form family) almost immediately.
3. **Land the CIT zero-delta assertion in 09** (tripwire for §4
   stage 3).
4. **Decide the module ownership discipline for the shared
   data.table** (modules receiving the baseline table must not leak
   by-reference columns into each other's view — the review found
   this contract undocumented in 01/04 and already biting the test
   suite's shared fixtures).
5. **Make Step B's macro block a schema'd return value** instead of
   an undocumented `attr()` contract.

## 8. Testing the modules

The existing invariant-test style generalizes directly (review §(a)):
extract `check_labor_contract()` / `check_capital_contract()` helpers
asserting the conservation identities, and run every registered
module form through them. New clauses for v2: the §4 accounting
identity per stage; labor-module cell-incidence monotonicity for the
exposure form; the LO/CO decomposition identity already in
`test-aggregate.R` carries over unchanged. The synthetic fixture
needs occupation/exposure columns only if the vintage ever carries
them — the CPS-cell design in §3 deliberately keys on columns the
PUF already has.

## 9. Open questions (parked)

- Scenario-grid size: variants × share modes × labor forms × capital
  payout/realization sensitivities explodes combinatorially; v2
  likely needs a "headline grid + named sensitivity runs" split
  rather than a full cross.
- GE: still none — prices, wages outside the shock, and the asset
  stock stay at baseline. Worth restating prominently since upstream
  sizing makes the model *look* more structural than it is.
- Behavioral: realization-rate response to the shock (ETI-style) is
  the first behavioral margin the staged design could host; out of
  scope for the first v2 cut.
- Karger calibration: does w35046 (or successors) give enough to pin
  `g_K` at the national-accounts level separately from `g_L`, or do
  we keep deriving one from the other via the share path?
- BLSMM: feed it the baseline module's GDP path directly (the
  current solve-for-productivity inversion becomes redundant).
