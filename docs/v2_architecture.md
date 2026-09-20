# AI-Fiscal v2 — architecture & design plan

**Status:** Design plan for review. Drafted 2026-06-11 from a design
conversation; expanded 2026-07-24 to mechanism level with real
baseline numbers (folded in the former `v2_design_sketch.md`). Nothing
here is implemented. Companion docs:
`realization_and_wealth_extensions.md` (the realization-rate
calibration + retirement constants, which §5 stage 6 depends on) and
`ai_fiscal_methodology.md` (the shipped v1.0 model).

**Version label:** "v2" names the second *model generation*
(re-architecture), not necessarily the git tag it ships under —
release numbering TBD (could land as the 0.2.x series). See open
question Q5.4.

This plan sketches, in order: the core inversion (§1); the CBO
baseline module (§2); the entity-flow spine that routes the capital
increment through C-corps vs. other business down to PUF income lines
(§3); the capital / corporate-tax module (§4); the labor-exposure
module and its metric × margin taxonomy (§5); what survives from v1.0
(§6); the relationship to the wealth-frame plan (§7); pre-work in the
current codebase (§8); the consolidated build plan and dependency
graph (§9); module testing (§10); and the open questions to debate
(§11).

---

## 1. The core inversion (the idea in one paragraph)

v1.0 sizes the AI shock **forward, off the realized-1040 base**:

$$ X = g_K \cdot Y_0^K, \qquad Y_0^K = \sum_i w_i \, y_{k,i} $$

where $y_{k,i}$ is *realized, taxable* capital income. It pushes $X$
onto PUF income lines in one step (100% distributed by wealth), with
corporate tax bolted on at the output stage as a scalar macro wedge.
Realization rates are baked in by construction — they are already
inside $Y_0^K$.

v2 **inverts this** and sizes the shock **upstream, off the
national-accounts base**:

$$ \Delta\Pi = g_K \cdot K_0^{\text{upstream}} $$

where $K_0^{\text{upstream}}$ is NIPA capital income (§3.1), **not**
the on-1040 realized base. A **baseline module** ports the CBO macro
baseline; a **shock specification** perturbs it (Karger-calibrated);
and two **propagation modules** — labor and capital — carry the
factor-level shocks down to the PUF. The capital shock is applied far
*upstream* of taxable income (entity-level returns at the
national-accounts level) and flows *downstream* in a model-driven way:
entity legal form → entity tax → retention vs. payout → asset-class
flows → realization → PUF lines. Realization and entity taxation
become modeled stages instead of by-construction assumptions.

The PUF becomes the microdata *carrier*, reconciled to CBO/NIPA
control totals; the aggregate comes from the macro baseline and the
micro data is bent to fit, rather than the reverse. The "inference"
this enables is the cascade run as an accounting identity: CBO
baseline + Karger AI parameters + our structural parameters (entity
shares, effective CIT, payout ratio, realization rates) *jointly
imply* the adjustment to each observed income line. It is
calibration/accounting, not statistical estimation (see Q1.4 on
whether we ever invert it to back out a shock from a target).

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
    metric × margin (§5)              entity split → entity tax →
        │                               retention/payout → allocation →
        │                               realization (§3, §4)
        └──────────┬──────────────────────┘
[4. Counterfactual PUF writer]  (v1.0 step 06, survives)
        │
[5. Tax-Simulator]  →  [6. Aggregation / deliverables / BLSMM]
```

---

## 2. Baseline module (new)

Port the CBO baseline as a first-class, validated data object rather
than hand-transcribed scalars. Replace today's scattered leaves
(`cbo_baseline.{g_2026, g_2027plus, gdp_baseline_year_B,
rev_to_gdp_baseline_year, cit_to_gdp_baseline_year}`, consumed
*positionally* in `02_params.R:139-153` behind an abort-guard) with a
typed `load_cbo_baseline()` object.

| Field | v1.0 source (2030) | Value |
|---|---|---|
| Nominal GDP $Y$ | CBO Feb-2026 (pub 62105), 2030 nominal GDP | $37,391B |
| Real GDP growth | CBO Tbl 1 | 2.2% (2026), 1.8% (2027+) |
| Revenue / GDP | CBO Tbl 1 | 17.7% |
| CIT / GDP | CBO Tbl 1 | 1.3% → ≈ $486B (2030) |
| Labor share $\theta_0^L$ | Karger Tbl 39 (2025) | 0.555 |
| Factor income levels | **new** — NIPA/BLS on the CBO GDP path | see §3.1 |

- **Why:** the v1.0 review found the CBO inputs scattered and fragile
  — `g_2026`/`g_2027plus` consumed positionally (rolling the baseline
  forward silently corrupts `g_y`), CBO yaml fragments re-read inline
  mid-output in `09_tables_figures.R`, and GDP scaling hardcoded as one
  year of growth. All of that becomes `load_cbo_baseline()` → a single
  typed object consumed by 02, 04, 09, and 15. It carries
  `_status`/`_source` metadata per leaf like the existing yamls.
- **Validation:** promote GDP and rev/GDP rows into
  `config/calibration/validation_benchmarks.csv` and extend
  `11_validation.R::compute_revenue_aggregates` to payroll/total
  (currently IIT/CIT only) — the benchmarks CSV already carries the
  NIPA factor rows a share-shock block needs.
- **Macro sizing** (unchanged in spirit from `02_params.R`, now
  feeding the national-accounts base): horizon $h=5$;
  $g_y = (1+r_{\text{ai}})^h/\text{cum\_base} - 1$ with
  $\text{cum\_base} = (1+g_{2026})(1+g_{2027+})^{h-1}$;
  $g_K = (\theta_1^K(1+g_y)-\theta_0^K)/\theta_0^K$ with
  $\theta_0^K = 0.445$ and $\theta_1^K \in \{0.450, 0.462, 0.487\}$
  for S/M/R.

**This is the #1 enabler:** every downstream stage multiplies the
paths through the code; a single validated baseline object is the
thing all of §3–§5 read from.

---

## 3. The entity flow (the new spine)

### 3.1 Sizing at the national-accounts level

$K_0^{\text{upstream}}$ decomposes by **where capital income is
generated and how it is taxed at the entity level**. Using the
existing `config/calibration/kappa_corp_calculation.csv` receipt (NIPA
Z.1 F.3, 2024):

| Entity channel | NIPA component | 2024 $B | Share of $K_0$ | Entity tax? |
|---|---|---:|---:|---|
| **C-corp profits** | Corp profits × (1 − S-corp 20%) | 3,007.4 | 49.7% | **CIT** |
| Pass-through — S-corp | Corp profits × 20% | 751.8 | 12.4% | none (K-1) |
| Pass-through — proprietor/partnership (capital half) | Proprietors' income × 50% | 1,017.7 | 16.8% | none (Sch C/E) |
| Household-direct — rental | Rental income of persons | 1,072.3 | 17.7% | none |
| Household-direct — interest | Net interest & misc | 197.1 | 3.3% | none |
| **Total broad capital income** $K_0^{\text{upstream}}$ | | **6,046.2** | 100% | |

So $\kappa_{\text{corp}} = 3007.4/6046.2 = 0.497 \approx 0.50$ (the
"narrow" C-corp share already adopted in the yaml). $\Delta\Pi$ splits
across these five channels by these shares, with an **AI tilt**
sensitivity (software/IP capital is C-corp-concentrated, pushing
$\kappa_{\text{corp}}$ toward the 0.65 high case — see Q2.4).

### 3.2 Two orthogonal decompositions (the subtlety to get right)

There are **two different cuts**, and v1.0 conflates them:

1. **Production / entity split** (§3.1) — *where* $\Delta\Pi$ is
   generated and taxed at the entity level. Drives CIT.
2. **Household holding / wrapper split** — *who* holds the claim and in
   *what tax wrapper* (taxable brokerage / retirement account /
   direct). Drives individual-level realization, timing, and rate.

These are orthogonal: a C-corp dollar of profit can be paid out as a
dividend into a taxable account (taxed now as a qualified dividend) or
into a 401(k) (deferred). The v1.0 across-unit (wealth-proportional) +
within-unit (`asset_to_income_map.csv`) allocators already handle cut
#2 and **survive**. The new work is cut #1 upstream, plus the
retention/payout and realization bridge between them (§4).

### 3.3 The full flow

```
[CBO baseline]  Y_t, θ0_L, rev/GDP, CIT/GDP, factor levels          (§2)
      │
[macro sizing]  g_y, g_K  →  ΔΠ = g_K · K0_upstream                 (§2)
      │
[entity split]  ΔΠ → {C-corp, S-corp, propr-K, rental, interest}   (§3.1)
      │
      ├── C-corp slice ────────────────► [ENTITY CIT]              (§4.2)
      │        │                              │
      │   after-tax C-corp profit ◄───────────┘
      │        │
      │   [retention / payout split]                              (§4.3)
      │        ├── payout  → dividends
      │        └── retention → equity accrual → [realization] → LTCG
      │
      ├── pass-through slices → ordinary K-1 / Sch C-E (≈100% realized)
      ├── rental slice        → Schedule E rental (≈100%)
      └── interest slice      → taxable / exempt interest (≈100%)
      │
[household holding/wrapper allocation]   ← v1.0 across+within allocators
      (taxable vs retirement wrapper; wealth-proportional; per-channel)
      │
[realization rules per channel]  r_div, r_lt, r_R, r_int=r_pt=1  (realization doc §3)
      │
[counterfactual PUF writer]  → div_ord/div_pref/kg_lt/scorp_*/part_*/txbl_int/…
      │
[Tax-Simulator]  → individual IIT on the new lines
      │
[aggregate]  ΔR = ΔR_CIT(entity) + ΔR_IIT(microsim) + ΔR_payroll
```

### 3.4 Reconciliation: the hard coupling

Sizing off NIPA forces a reconciliation step v1.0 never needed.
PUF-realized capital income ≪ NIPA capital income (most accrual is
unrealized; realized LTCG runs ~1.3pp of GDP *below* CBO's 40-yr mean;
the DB-pension microsim aggregate is 6× *below* DFA):

- **You cannot land NIPA-sized flows on the PUF without a realization
  stage** — §3 is not complete without the realization module
  (§4 stage 6; `realization_and_wealth_extensions.md` §3). This is the
  coupling the wealth-frame doc calls "inseparable."
- **Reconciliation policy per channel** must be decided (Q1.3):
  benchmark (accept PUF distribution, scale level to NIPA), inherit
  (PUF as-is), or hybrid. The Affordability-Index "benchmark, don't
  inherit" lesson applies — decide explicitly, don't let the PUF
  silently set the aggregate.

---

## 4. Capital module (corporate tax + allocation cascade)

The center of the re-architecture. v1.0's single step
`X = g_k·Y0^K → wealth-proportional allocation → PUF lines` becomes a
staged cascade.

### 4.1 What v1.0 does (and why it's a shortcut)

CIT is a single scalar wedge layered at the output stage in
`09_tables_figures.R`:

$$ \eta = \frac{\tau_{\text{cit}}\,\kappa_{\text{corp}}\,Y_0^K}{(\text{CIT/GDP})\cdot Y}, \qquad
\Delta R_{\text{CIT}} = \frac{\tau_{\text{cit}}\,\kappa_{\text{corp}}\,X}{\eta}
= X \cdot \frac{\text{CIT}_{\text{baseline}}}{Y_0^K}. $$

The statutory rate and $\kappa$ **cancel algebraically** — the wedge
is really just "scale the increment by the baseline ratio of CIT to
capital income." It assumes the AI capital increment is taxed at the
same *average effective* CIT-to-capital ratio as the baseline, and it
never touches the microsim (the `09_tables_figures.R:227` tripwire
aborts if Tax-Simulator moved corporate tax, guaranteeing no
double-count). And `04_allocate_capital.R:86` hard-codes
`X_to_units <- X` — a 100%-distributed assumption with no retention
concept at all.

### 4.2 Staged cascade

1. **Upstream sizing.** $\Delta\Pi = g_K \cdot K_0^{\text{upstream}}$
   (§3.1). Calibration receipts exist in
   `config/calibration/{nipa_2024_z1_f3.csv, kappa_corp_calculation.csv}`.
2. **Entity split.** Decompose $\Delta\Pi$ across the five channels of
   §3.1. AI-specific tilt (Q2.4) is a sensitivity axis.
3. **Entity CIT** (replaces the v1.0 output-stage wedge). Apply CIT
   directly to the C-corp slice at the *effective* rate, from
   `config/calibration/cit_avoidance_calculation.csv`:
   - statutory $\tau_C = 0.21$ (TCJA IRC §11);
   - effective $\tau_C^{\text{eff}} = 0.21\,(1-0.30) = 0.147$
     (avoidance 30%, narrow NIPA basis; sensitivity [0.25, 0.55]
     avoidance → $\tau_C^{\text{eff}} \in [0.0945, 0.1575]$).

   $$ \Delta R_{\text{CIT}} = \tau_C^{\text{eff}}\,\Delta\Pi_{\text{ccorp}},
   \quad \Pi^{\text{after}}_{\text{ccorp}} = (1-\tau_C^{\text{eff}})\,\Delta\Pi_{\text{ccorp}}. $$

   **Double-count tripwire** (already in place): the moment CIT is
   modeled here, the `09` output-stage layering must switch off. The
   `09_tables_figures.R:227` assertion aborts if the two ever run
   together — it flips from guarding the microsim to guarding *this*
   stage.
4. **Retention vs. payout** (genuinely new — no home in v1.0). After-tax
   C-corp profit splits:

   $$ \Pi^{\text{after}}_{\text{ccorp}} = \underbrace{p\,\Pi^{\text{after}}}_{\text{payout}}
   + \underbrace{(1-p)\,\Pi^{\text{after}}}_{\text{retention}} $$

   - **Payout $p$**: calibrate to NIPA personal dividends / after-tax
     corporate profits (≈ 0.4–0.5 historically). Flows to the PUF as
     dividends (`div_ord`/`div_pref`), **taxed again** at the
     individual level in Tax-Simulator → this is where classic double
     taxation of corporate income finally appears. Buybacks are
     economically payout but taxed as realization (Q2.2).
   - **Retention $(1-p)$**: accrues to equity value → realized as LTCG
     over time at rate $r_{\text{lt}}$ (stage 6) → `kg_lt`, taxed at
     the individual level.

   The dormant `scale_gross` machinery in 06's factor-channels sidecar
   (X_macro ≠ X_distributed) is the vestigial hook; the insertion
   point is between `compute_macro_targets` and `allocate_across_units`.
5. **Household allocation.** The v1.0 across-unit (wealth-proportional)
   and within-unit (asset-class share) allocators survive — both are
   frame-agnostic given an arbitrary scalar/per-class flow. What
   changes: allocation happens **per channel** (dividend flow, accrual
   flow, pass-through flow, interest flow), each against the
   appropriate holdings base. `config/asset_to_income_map.csv` is the
   right *shape* but needs a dispatch column (static-share vs.
   unit-ratio vs. cascade-handler) and load-time validation.
   Pass-through / rental / interest channels (§3.1) carry **no entity
   tax** and flow ≈100% to K-1 (`scorp_*`, `part_*`) / Schedule E /
   interest lines; the individual side picks up the QBI §199A
   deduction automatically in Tax-Simulator.
6. **Realization module** (was Step C, becomes real). Retained-earnings
   accrual → realized LTCG via explicit per-class rates. Calibration
   groundwork is in `realization_and_wealth_extensions.md` §3: the CRS
   R41364 61% lifetime anchor vs. annual anchors (CBO-implied 0.24,
   PUF-implied 0.16, JCT/AH 0.20–0.35), the lifetime-vs-annual labeling
   decision (Q2.3), and the step-up haircut. The retirement slice keeps
   the existing R1 cascade but its *no-discount* justification is
   income-frame-specific and must be revisited — under upstream sizing
   the flow arrives pre-realization, so the $r_R$-based conversion from
   the extensions doc §4 applies.

### 4.3 The revenue identity

$$ \Delta R_{\text{total}} = \underbrace{\Delta R_{\text{CIT}}}_{\text{entity, outside microsim}}
+ \underbrace{\Delta R_{\text{IIT}}}_{\text{microsim on new div/gain/K-1/interest lines}}
+ \underbrace{\Delta R_{\text{payroll}}}_{\text{labor side}} $$

with the accounting conformance test:
$\Delta\Pi = \text{CIT} + \text{payout} + \text{retention} + \text{passthrough} + \text{direct}$,
and $\sum_i w_i \cdot (\text{per-unit PUF deltas}) =$ distributed-flow
total. These become module tests (§10).

---

## 5. Labor module (metric × margin taxonomy)

> **See `labor_exposure_extension.md`** — it builds this section out into
> a concrete proposal (deterministic weight-splitting, the tracker's
> SOC-level exposure file, and a duration-mixture treatment of job loss)
> and is the authoritative source for the P3 lane, as
> `realization_and_wealth_extensions.md` is for P4. Two corrections it
> carries: §5.3's transfer-side claim below is wrong — SNAP is not
> modeled in Tax-Simulator at all and ACA premium credits are an
> exogenous pass-through, so the endogenous response is EITC / CTC / SS
> taxability only; and the `y_l == 0` units are a third, inert class in
> today's Step A, which blocks the "explicit weight/zeroing convention"
> the contract below asks for until it is redefined.

**Contract** (formalized from Step A): consume `(id, weight, y_l, e)`
plus a target `L1`; emit per-unit `y_l1` with $\sum w\cdot y_{l1} = L_1$
and documented treatment of non-positive baseline units (and, for
extensive, an explicit weight/zeroing convention). The v1.0 review
confirmed Step A is already fully separable — its only capital-side tie
is deriving `L1` internally from `(g_l, g_k)`; v2 passes `L1` (or
`g_L`) in explicitly from the shock spec, severing the tie. So the
labor module can be built **in parallel** with the capital
re-architecture.

Today's S0/S2/S3 forms are one corner of a 2-axis space. Making both
axes explicit turns the whole space into a menu.

### 5.1 Axis A — the exposure metric $e_i$ (how exposure is distributed)

| Metric | $e_i$ | Maps to today | New? |
|---|---|---|---|
| **Uniform** | $e_i = 1\ \forall i$ | S0 proportional | no |
| **Function of income** | $e_i = f(\text{rank}(y_{l,i}))$, monotone | S2 (compress) / S3 (expand) | no |
| **Function of occupation** | $e_i = e_{c(i)}$, cell exposure from CPS | — | **yes** |
| **Composite / ensemble** | blend + a sensitivity axis | — | **yes** |

**Occupation-metric construction:** take occupation-level AI exposure
scores (Eloundou et al. GPTs-are-GPTs, Felten et al. AIOE, Webb
patent-based, Anthropic Economic Index task-usage — pick and document;
possibly an ensemble with a sensitivity axis), merge onto CPS ASEC,
collapse to **PUF-visible cells** (`age-band × sex × wage-decile ×
filing status` — the PUF carries no occupation, industry, or education;
the synthetic fixture confirms nothing to key on beyond
age × sex × income), cell exposure $e_c$ = CPS earnings-weighted mean
exposure, assign to PUF units by cell.

**Honest constraint:** on the PUF, *every* metric collapses to a
function of observable columns. The occupation metric adds information
only to the extent occupation varies across those cells; within-cell
heterogeneity is the resolution ceiling (Q3.3), and CPS topcoding at
high wages is exactly where the PUF is the better source — blend
exposure gradients only up to the CPS-reliable range, revert to
decile-rank extrapolation above.

### 5.2 Axis B — the margin (how the shock acts, given $e_i$)

| Margin | Mechanism | Aggregate constraint solved by |
|---|---|---|
| **Intensive** | $y_{l1,i} = (1+\beta e_i)\,y_{l,i}$ — all keep jobs, wages move | solve $\beta$ (uniroot + rescale) |
| **Extensive** | subset selected by $e_i$ has $y_l \to 0$ (displacement) | solve displacement mass |
| **Mixed** | displacement prob $\pi(e_i)$ **and** wage pressure on survivors | solve $(\pi, \beta)$ jointly |

All three hit the same macro target
$\sum_i w_i\, y_{l1,i} = L_1 = L_0(1+g_L)$; they differ only in *how*
the labor-income change is distributed. Intensive spreads it thin;
extensive concentrates it on a displaced subset. The S0/S2/S3
log-affine + uniroot-renormalization machinery (`03_shock_labor.R`)
survives for the intensive column.

### 5.3 What extensive margin newly requires (the real design fork)

Extensive is not "intensive with a big $\beta$" — it opens three
questions intensive never touches:

1. **Selection rule.** Which units are displaced? Deterministic
   exposure-rank threshold, or a probability $\pi(e_i)$ applied to the
   *weight* in each cell (zero labor income on an exposure-weighted
   fraction of the cell's weight)? Probabilistic + weighted is the
   microsim-natural choice.
2. **Where displaced income goes** (Q3.1 — the biggest new decision).
   A displaced worker's wage → 0. In a static model: (a) pure loss
   (offset in aggregate by the capital gain elsewhere), (b) routed to
   transfers — and Tax-Simulator will **endogenously** move EITC/CTC/
   SNAP as units cross eligibility thresholds, or (c) partial
   reallocation to other labor.
3. **Transfer-side blowup.** Intensive barely moves refundable-credit
   eligibility; extensive pushes people across EITC phase-in/out kinks
   and SNAP thresholds → large, realistic, but volatile
   refundable-credit deltas. A feature, but it makes the labor module's
   output far more sensitive than today's.

### 5.4 The clean contract & naming

Every (metric × margin) form satisfies the §5 contract. This
generalizes the existing `check_labor_contract()` invariant style
directly.

**Naming guard:** do **not** reuse `S1` for any exposure form — it is
the archived internal development tree's different AI-exposure
construction. Use descriptive codes (e.g. `EXPu`/`EXPy`/`EXPocc` ×
`INT`/`EXT`/`MIX`); see §11 Q5.1 on the scenario-ID explosion.

---

## 6. What survives from v1.0 (review-verified)

| Component | Verdict |
|---|---|
| `03_shock_labor.R` S0/S2/S3 machinery | survives as the intensive column; takes `L1` as input |
| `04` across-unit + within-unit allocators, R1 cascade | survive as capital-module stages 5–6 |
| `04::compute_macro_targets` (X = g_k·Y0^K, eta_corp wedge) | replaced wholesale by §4 stages 1–4 |
| `05_realization.R` | grows from placeholder into the stage-6 module |
| `06` PUF writer, kg_lt augmentation, runscript plumbing | survives (its `X_<type>` column interface is exactly the contract the capital module should emit) |
| `07_run_tax_sim.R` | survives untouched (axis-agnostic) |
| `08_aggregate.R` aggregators | survive; suffix parser needs an allowlist |
| `09` CBO fragments, macro-CIT layering | absorbed into baseline module / entity-tax stage |
| `15` BLSMM tie-in numeric core | survives; feed it the baseline module's GDP path instead of re-deriving growth |

---

## 7. Relationship to the wealth-frame plan

`realization_and_wealth_extensions.md` proposed re-denominating X in
wealth units (ΔW = gW·K0_wealth) with per-class realization rules. The
v2 capital module **subsumes** that plan: upstream entity-level sizing
+ retention/payout + explicit realization delivers everything the
wealth frame was for (realization-rate policy levers, accrual vs.
cash-flow distinction) while staying denominated in income flows at the
national-accounts level — which sidesteps the `gW = f(g_k, r̄)`
conversion problem the extensions doc flagged as its hardest open
question (§2.3). The extensions doc remains the authoritative source
for the realization-rate calibration (§3) and the retirement constants
(§4); its Phase 1–6 plumbing plan (frame toggle in the yaml) is
superseded by the module architecture here.

---

## 8. Pre-work in the current codebase

From the 2026-06-11 full-repo review — these get strictly more
dangerous once a second sizing frame and per-entity flows multiply the
paths through the code. **Status updated 2026-07-24:**

1. ✅ **Criticals/majors fixed** (per `docs/CODE_REVIEW_2026_06_11.md`,
   all five waves): 06 merge-order misalignment, 07 Windows `winslash`
   bug, 15 dead variant guard, fixture-generator `sample()` bug, 06's
   hard-coded 0.75 passive share, symlink return-value check, NA-join
   guards in 06.
2. ✅ **Scenario-axis registry consolidated** into `code/00_utils.R`,
   consumed by 00/08/09/10; 08 aborts on unknown suffixes. (This is the
   single highest-value enabler because v2 adds axes — capital-module
   variant, labor metric × margin — almost immediately.)
3. ✅ **CIT zero-delta assertion landed** (`09_tables_figures.R:227`,
   the tripwire for §4 stage 3).
4. ⬜ **Module-ownership discipline for the shared `data.table`.**
   Modules receiving the baseline table must not leak by-reference
   columns into each other's view — the review found this contract
   undocumented in 01/04 and already biting the test suite's shared
   fixtures. **Still open.**
5. ⬜ **Make Step B's macro block a schema'd return value** instead of
   an undocumented `attr()` contract. **Still open.**

Items 4–5 are folded into P0 (§9).

---

## 9. Consolidated build plan

### 9.1 Dependency graph

```
        ┌─────────────────────────────────────────┐
        │ P0  load_cbo_baseline() + finish pre-work │  ← unblocks everything
        │     (module-ownership discipline;         │
        │      schema Step B macro return)          │
        └───────────────┬───────────────┬───────────┘
                        │               │
     ┌──────────────────┘               └──────────────────┐
     ▼                                                      ▼
┌─────────────────────────────┐              ┌──────────────────────────────┐
│ P1  Entity split (§3.1)      │              │ P3  Labor exposure (§5)      │
│     ΔΠ → 5 channels          │              │     — fully separable from   │
└──────────────┬──────────────┘              │       capital; runs parallel │
               ▼                              │  P3a metric plumbing         │
┌─────────────────────────────┐              │  P3b CPS×exposure cells      │
│ P2a Entity CIT (§4.2 st.3)   │              │  P3c extensive-margin design │
│     flip off 09 wedge        │              │      (decide BEFORE coding)  │
└──────────────┬──────────────┘              └──────────────────────────────┘
               ▼
┌─────────────────────────────┐
│ P2b Retention/payout (§4.2   │
│     st.4) + double taxation  │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ P4  Realization module       │  ← completes §3.4 reconciliation
│     (per-channel r_div/r_lt/ │
│      r_R); realization doc §3 │
└─────────────────────────────┘
```

### 9.2 Recommended order

1. **P0** — `load_cbo_baseline()` + the two open pre-work items.
   Highest value; everything reads from it. Low economic risk (refactor
   + validation).
2. **P1** — entity split. Data-only; receipts already exist. Introduces
   the 5-channel decomposition of $\Delta\Pi$.
3. **P2a** — entity CIT; flip off the `09` wedge (tripwire makes this
   safe). Small, well-bounded.
4. **P2b + P4** — retention/payout + realization. The heart of the
   re-architecture and the hardest calibration. P4 completes §3.
5. **P3** — labor exposure, in parallel throughout (severable). Settle
   the extensive-margin accounting (§5.3, Q3.1) *before* writing code.

**Prerequisite investigation** (blocks P1): resolve the labor-share
definitional mismatch (Q1.2) — Karger's 55.5% vs. NIPA
compensation/national-income of 62.2% — before sizing off NIPA.

---

## 10. Testing the modules

The existing invariant-test style generalizes directly: extract
`check_labor_contract()` / `check_capital_contract()` helpers asserting
the conservation identities, and run every registered module form
through them. New clauses for v2: the §4.3 accounting identity per
stage; labor-module cell-incidence monotonicity for the exposure form
and the displacement-mass identity for the extensive margin; the LO/CO
decomposition identity already in `test-aggregate.R` carries over
unchanged. The synthetic fixture needs occupation/exposure columns only
if the vintage ever carries them — the CPS-cell design in §5
deliberately keys on columns the PUF already has.

---

## 11. Open questions & issues to debate

### On the upstream flow (§1–3)

- **Q1.1 — the base $K_0^{\text{upstream}}$.** Broad NIPA capital
  income ($6,046B) vs. a narrower "AI-relevant" base? Do rental + net
  interest belong in the shock at all, or only corporate + pass-through
  business income? (Rental/interest are 17.7% + 3.3% of the base —
  non-trivial.)
- **Q1.2 — labor-share definitional mismatch (blocks P1).** v1.0
  derives $g_K$ from the share shift on the *realized* base. On the
  NIPA base the same $\theta$ arithmetic applies, but Karger Tbl 39's
  "labor share" (55.5%) does **not** match the NIPA
  compensation/national-income ratio ($15,227/24,473 = 62.2\%$). The
  definitions differ; this gap must be resolved before sizing off NIPA.
- **Q1.3 — reconciliation policy.** Benchmark vs. inherit per channel
  (§3.4). Where the PUF undershoots NIPA, scale levels, accept the gap,
  or treat it as unrealized (→ realization module)?
- **Q1.4 — is "inference" the right frame?** The cascade is accounting,
  not estimation. Should we ever *invert* it (observe a revenue/share
  target and back out the implied shock), or only run it forward from
  Karger? The brief hints at inversion; pin down scope.

### On corporate tax (§4)

- **Q2.1 — effective vs. statutory rate on the *increment*.** Is the AI
  capital increment taxed at the baseline average effective rate
  (14.7%), the statutory rate (21%, if AI profits are cleaner/newer
  with fewer shelters), or a marginal effective rate? The choice moves
  $\Delta R_{\text{CIT}}$ by ~40%.
- **Q2.2 — payout ratio $p$ and buybacks.** Buybacks are economically
  payout but taxed as realization (LTCG), not dividends. Split payout
  into dividends vs. buyback-driven gains? Calibrate $p$ to which
  vintage of NIPA personal dividends?
- **Q2.3 — timing / horizon.** CIT is on current profits (a flow), but
  retention → realization → LTCG has a multi-year lag. In a one-shot
  static 2030 model, realize retained gains in-year (V1 mechanical), or
  is a lifetime/PV treatment needed (realization doc §3.4, the $r=0.60$
  lifetime vs. $0.24$ annual debate)?
- **Q2.4 — AI tilt on $\kappa_{\text{corp}}$.** Software/IP capital is
  C-corp-concentrated. Is the entity split of $\Delta\Pi$ the same as
  the baseline split, or does AI capital tilt toward C-corps (the 0.65
  high case)? First-order lever on the CIT share.
- **Q2.5 — international.** GILTI/foreign profits/profit-shifting are
  all inside the 30% avoidance number as a black box. Explicitly out of
  scope, or does the AI increment change the foreign share?

### On labor exposure (§5)

- **Q3.1 — extensive-margin income destination.** The single biggest
  decision (§5.3 #2): pure loss, transfers, or reallocation? Determines
  whether the transfer side moves and how the module validates.
- **Q3.2 — exposure source.** One score or an ensemble? Which (Eloundou
  / AIOE / Webb / Anthropic Economic Index)? Displacement vs.
  augmentation sign is scenario-dependent and *not* given by exposure
  alone — needs an explicit mapping assumption.
- **Q3.3 — cell resolution.** Is `age × sex × wage-decile × filing`
  enough to carry occupation signal, given the PUF can't see
  occupation? If most exposure variation is *within* cell, the
  occupation metric collapses toward the income metric — is the CPS
  machinery worth it?
- **Q3.4 — does the labor margin interact with the capital side?** v1.0
  treats them as separable (labor is a flow; capital is the headline
  knob). Under extensive displacement, is the displaced labor income
  *mechanically* the capital gain (adding-up), or independently
  parameterized and only reconciled at the aggregate share? (The share
  arithmetic implies the former; the code treats them as the latter.)

### Cross-cutting

- **Q5.1 — scenario-grid explosion.** variants (3) × share modes (2) ×
  labor metrics (4) × margins (3) × capital payout/realization
  sensitivities (≥3) is a combinatorial blowup. Need a "headline grid +
  named sensitivity runs" split, and the scenario-axis registry (now in
  `00_utils.R`) must absorb the new axes cleanly.
- **Q5.2 — where do elasticities enter?** The brief names "realizations,
  elasticities." Realization rates are structural (P4). Elasticities
  are behavioral (realization response to rates, labor-supply response,
  CIT base response) — all currently out of scope. Do any move into the
  *primary* spec, or stay parked as a behavioral layer?
- **Q5.3 — still no GE.** Upstream sizing makes the model *look* more
  structural than it is (prices, wages outside the shock, and the asset
  stock stay at baseline). Restate this prominently so readers don't
  over-read the entity-flow detail as general equilibrium.
- **Q5.4 — versioning.** Does this land as a `0.2.x` series, or is the
  re-architecture large enough to be a "v2" model generation with its
  own headline release?

### Parked (from the original sketch)

- **Behavioral:** realization-rate response to the shock (ETI-style) is
  the first behavioral margin the staged design could host; out of
  scope for the first v2 cut.
- **Karger calibration:** does w35046 (or successors) give enough to
  pin $g_K$ at the national-accounts level separately from $g_L$, or do
  we keep deriving one from the other via the share path?
- **BLSMM:** feed it the baseline module's GDP path directly (the
  current solve-for-productivity inversion becomes redundant).
