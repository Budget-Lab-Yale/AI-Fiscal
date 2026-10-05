# AI-Fiscal v2.0 — decisions log

**Status:** opened 2026-09-21; **amended 2026-10-02** to absorb the
September 23 review ([`v2_review_and_roadmap.md`](v2_review_and_roadmap.md))
and its repo mapping ([`v2_review_context.md`](v2_review_context.md)).
Nothing is SET yet. The amendment changes what each question asks; it
does not choose answers. The "recommended position" lines are the
review's proposals, written down as the defaults to argue against.

Principle 2 of [`v2_build_plan.md`](v2_build_plan.md): *every node tagged
`decision` in the flow network gets a numbered entry here before the code
that depends on it is written.* Phase 0's exit gate was **D1–D8
written**. It is now **D1–D13 settled at the concept level**: meaning,
denominator, admissible range, and relationship to the other decisions.
A coefficient can stay an open calibration or a named scenario axis past
the gate; its concept cannot (review, "Decisions to record").

Companion docs — read in this order when picking up a decision:

- [`v2_review_and_roadmap.md`](v2_review_and_roadmap.md) — findings 1–12
  and the 16-week solo roadmap whose week numbers appear under *Settle
  by* below.
- [`v2_flow_network.md`](v2_flow_network.md) §7 — the shape-changing
  decisions and which nodes each one moves. Node registry in §5. **Not
  yet revised for the review**: it has no ownership or asset-state
  nodes. That revision is the next step after this file.
- [`v2_architecture.md`](v2_architecture.md) §11 — the full open-question
  list (Q1.1–Q3.4) these D-numbers draw from.
- [`v2_data_gathering.md`](v2_data_gathering.md) — the pull that unblocks
  each decision, by row number.
- [`labor_exposure_extension.md`](labor_exposure_extension.md) — the
  labor extension, now deferred past v2.0 (D8).

## How to use this file

**Status vocabulary.** `OPEN` (question posed, no lead), `PROPOSED` (a
default is written down and is the one to argue against), `SET` (chosen —
records the date, the option, and the receipt), `DEFERRED` (out of the
v2.0 release by decision; the question is preserved for a later one).

**Setting a decision** means four things, not one: flip the status here
with a date; land or update the receipt in `config/calibration/` with its
`_status`/`_source` siblings; update every node listed under *Moves*; and
add the yaml leaf if the choice introduces a parameter. A number here
that has no receipt behind it is not SET, whatever this file says. Per
the review, a SET entry also records the alternatives considered and a
**reopen condition**.

**Amendments.** An amended entry keeps its 2026-09-21 text under
*Original framing* so references from the network and build plan still
resolve. The revised question above it is the controlling one.

**Numbering.** This file is the single registry for D-numbers; no other
doc reserves one. D1–D13 are the Phase 0 gate. Deferred questions in §2
get the next free number when their phase opens. **Next free number:
D15.** (The labor-lane table in `v2_build_plan.md` used to claim D9 for
its exposure gate; that reservation is withdrawn — the gate gets a
number if and when the labor extension opens.)

**Label collisions to keep straight in prose and output labels:**
reconciliation node `R1` (flow network) ≠ the v1.0 `R1` retirement
cascade (≠ the archived dev tree's `R1`); model version "v2" ≠
historical realization variant `V2`.

---

## 1. Phase 0 decisions (the exit gate)

| ID | Topic | Status | Settle by (roadmap week) | Amended 2026-10-02 |
|---|---|---|---|---|
| D1 | Survey source, sector, and share bridge | **respondent group SET 2026-10-05** (pooled); bridge PROPOSED | 1 | reframed |
| D2 | Shock coverage within complete accounts | PROPOSED | 2 | reframed |
| D3 | Factor accounts and named non-factor components | **φ rule SET 2026-10-05**; `Q` rules PROPOSED | 2 | reframed |
| D4 | Corporate tax: baseline bridge vs marginal response | PROPOSED | 4 | reframed |
| D5 | Reconciliation ordering | PROPOSED | 4 | proposal replaced |
| D6 | Baseline, counterfactual, time and prices | **baseline source SET 2026-10-05** (Macro-Projections); rest PROPOSED | 1–2 | widened |
| D7 | Payout ratio on a matched universe | OPEN | 6 | narrowed |
| D8 | Labor displacement | PROPOSED: defer | 1 | reframed |
| D9 | Ownership and wrapper boundary | PROPOSED; **granularity widened 2026-10-05** | 2 | **new** |
| D10 | Capital-gains object, timing, basis at death | **valuation rule SET 2026-10-05** (Rule A default, Rule B built); realization calibration PROPOSED | 2 concept, 9 calibration | **new** (absorbs Q2.3) |
| D11 | Retirement balances and withdrawals | PROPOSED | 2 concept, 6 calibration | **new** |
| D12 | Distributional estimand and CIT incidence | **lead panel + incidence SET 2026-10-05** | 2 definition, 10 implementation | **new** (absorbs the CIT-burden node) |
| D13 | Release horizon and required outputs | **horizon SET 2026-10-05** (10-year window); outputs PROPOSED | 1 | **new** |
| D14 | Revenue-parameter register as a model output | **SET 2026-10-05** (concept); contents PROPOSED | 2 definition, 12–13 sensitivities | **new 2026-10-05** |

**2026-10-05 — John's review of the methodology proposal** (PDF comments on
`v2_methodology_proposal_2026-10-02_v1.pdf`). Each decision below is a
concept choice; receipts are still to land, so the "SET" is for the
choice, not a number.

- **D1:** use the **pooled (Total) column** of Karger Table 39 — the
  column v1.0 actually used (yaml `baseline_labor_share_source`). The
  published methodology's "economist subsample" wording is therefore the
  thing to correct, not the numbers. *Follow-up:* confirm the GDP growth
  rates (Table 19: 2.0 / 2.6 / 3.3, which the review attributes to the
  economists' group) are taken from the same pooled column, or record why
  the two tables use different groups.
- **D6:** adopt **Macro-Projections** (`projections.csv`, the vintage
  Tax-Simulator reads) as the v2 baseline module. *Added concern:* if CBO's
  baseline embeds AI effects, and especially if CBO publishes larger-AI
  alternative scenarios, we may need to back out CBO's AI contribution
  before layering ours. Feasibility depends on how much CBO discloses —
  make this a data-gathering item (extends 2.4).
- **D9:** ownership shares by entity type **and by income group** (not
  only wealth group).
- **D12:** the **cash** panel leads; the incidence convention is **the
  Budget Lab's own** (Tax-Simulator `distribution.R`: labor share of
  corporate-tax changes phasing 0 → 20% over ten years).
- **D13:** build out a **10-year window** (not the 2030 endpoint only).
  Consequences: a post-2030 shock path (Karger's horizon ends in 2030),
  annual tax-unit files for every scored year, and the asset/retirement
  ledgers (D10, D11) carrying balances across the full window.
- **Scope principle (general comment):** the primary output is federal
  revenue. Model non-revenue destinations (foreign, exempt, deferred)
  only as far as they determine what reaches a tax base; don't build
  full estimates of those components where that needs heavier
  assumptions.
- **Walk-throughs requested** before deciding: D10 reference valuation
  rule; BLSMM as the source of v2's GDP path; the single mixed-income φ
  (D3). *Resolved in the second round below.*

**2026-10-05, second round — John's answers to the walk-throughs.**

- **D10 valuation: Rule A is the default.** Share values rise one-for-one
  with retained earnings attributed to each owner (`A_t = RE_t`); no
  announcement revaluation. **Rule B must also be built**: a
  capitalization rule in which the change in after-tax profits is valued
  at a user-specified discount rate `r`, with the growth rate `g` taken
  from the model's own profit path (not a separate input). The code must
  guard `r > g` and must not also accrue retained earnings under Rule B
  (that would count the same profits twice).
- **BLSMM: use our own GDP paths.** v2 builds the GDP path from Karger
  growth rates over the Macro-Projections baseline, as v1.0 did. BLSMM
  stays downstream (debt/GDP). Flag in the methodology that the two could
  be integrated later — BLSMM's own Karger-based AI scenarios could
  supply the GDP, price, and interest-rate paths — but it is not in v2.0.
- **D3 φ: one aggregate φ, derived from the tax file.** Compute the
  aggregate capital share of mixed income implied by the Saez–Zucman rule
  on the tax file (sole-proprietor and farm income counted as labor, as
  in v1.0) and use that value upstream in the production accounts, so the
  macro and micro classifications agree by construction. Tax-Simulator's
  80/20 split stays only inside the Budget Lab incidence overlay (D12),
  documented as part of that convention.
- **New D14: a revenue-parameter register is a required output** (see
  entry below).

**2026-10-05 — What CBO's February 2026 outlook says about AI (D6
back-out question).** Read from the full report PDF (`61882-Outlook-2026.pdf`;
the web landing page is pub 62105 — note both numbers in receipts).

- *What CBO embeds* (p. 38 of the report, Ch. 2 "potential output"):
  annual TFP growth 2026–2036 is **0.1 pp higher** than without generative
  AI diffusion, raising **nonfarm business output 1% by 2036**; effects
  described as gradual. Separately, AI-related business investment (data
  centers, computers, IP) drives 2026 investment growth and part of a GDP
  level 2.4% above the Jan-2025 projection in 2035 (p. 99 of the report) — that
  investment effect is **not** separated from the reconciliation act's.
- *What CBO does not embed:* no AI effect on factor shares. Wage and profit
  shares are revised for data reasons (wages and salaries/GDP down ~1.4 pp
  a year 2027–35 toward the post-pandemic ~42%; domestic corporate
  profits/GDP fall to 2030, then rise to 10.1% in 2036 "consistent with
  their historical long-run trend").
- *Other AI touchpoints:* higher long-run interest rates partly because AI
  raises returns on capital (relevant to Rule B's `r` and to interest
  income); AI capex deductions are inside the FY2026 CIT baseline.
- *No quantified AI alternative scenario* in this report — uncertainty is
  qualitative (faster or slower diffusion). Pub 62184 ("How Budgetary and
  Economic Outcomes Might Differ…") may have one; not yet read (cbo.gov
  blocks scripted access — needs a manual download).

**Implications (proposed):**
1. *GDP: no back-out needed in the reference case.* Karger's `r_ai` is
   total real GDP growth, and `g_Y = (1+r_ai)^h / G_CBO − 1` measures it
   against CBO's total path, so CBO's AI is netted out by construction.
   The estimand is "AI beyond what CBO assumes." State this explicitly.
2. *Optional AI-vs-no-AI framing:* an ex-AI baseline is constructible from
   what CBO discloses (remove 0.1 pp/yr of NFB TFP; NFB output −1% by
   2036, roughly −0.5% by 2030 if diffusion were linear — CBO gives only
   the endpoint). Offer as an alternative presentation, not the default.
3. *Shares:* nothing AI-specific to back out, but the scenario's labor
   share change must be layered on CBO's own (non-AI) share path — the
   open D1 question of "change relative to today's share vs the projected
   baseline share" matters more than thought, because CBO's wage share
   is itself moving.
4. *CIT:* the incremental rate `τ^m` (D4) applies to investment beyond
   CBO's; AI capex already in the baseline must not be expensed twice.

---

### D14 — Revenue-parameter register as a model output  *(new)*

**Status: SET 2026-10-05 (concept); contents PROPOSED** · **Settle by:**
definition week 2; sensitivities weeks 12–13

**Decision.** Identifying and recording the parameters that determine
how much future revenue AI generates is itself a product of v2, not
just internal bookkeeping (John: "e.g. the retained earnings point").
Every run writes a register with, for each parameter: symbol and plain
description; module; value used; source or `_status`; admissible range;
and the change in ten-year and 2030 revenue from moving it across that
range, holding the others at reference values. The publishable bundle
gets a ranked version (largest revenue effect first). This turns the
`parameter_index` sheet v1.0 already writes into an analytical output
and is the backbone of the review's "ranked sensitivity table" (D13).

**Proposed initial contents** (add as modules land):

| Parameter | Module | Why it moves revenue |
|---|---|---|
| Sector bridge / NFB share of the GDP shock | D1 | sets how much of ΔY is labor vs capital |
| φ (mixed-income capital share) | D3 | moves ~$200B of base per 0.1 between labor and capital |
| `Q` scenario rules | D3 | income that reaches no factor base |
| Shock coverage (rent, interest) | D2 | size of the capital increment |
| κ, legal-form split of ΔΠ | Q2.4 | CIT vs pass-through taxation |
| Marginal CIT rate τ^m (normal return vs rent, expensing, losses) | D4 | CIT per dollar of profit |
| Payout ratio p (**retained earnings**) | D7 | dividends taxed now vs gains taxed later or never |
| Valuation rule (A/B), discount rate r | D10 | timing and size of accrued gains |
| Realization hazard / lag | D10 | when gains reach tax returns |
| Step-up at death (mortality by age) | D10 | gains that are never taxed |
| Ownership shares ω (foreign, exempt, retirement, by income group) | D9 | share of income that reaches individual returns |
| Retirement withdrawal rates, DB treatment | D11 | timing of tax on wrapper income |
| Reconciliation residual by channel | D5 | measurement gap to the tax file |
| Labor dispersion λ / k | Step A | progressivity and the payroll cap |
| Post-2030 shock path | D13 | years 6–10 of the window |
| CBO embedded-AI back-out | D6 | baseline vs scenario attribution |

**Moves:** the output contract (new sheet/CSV), and the sensitivity
design — perturbations are generated from the register's ranges rather
than hand-listed.

Dependency order: **D13 and D6 first** (they fix what is being
estimated and over which years), then **D1 → D3 → D2** as one accounting
specification, then D9, D10, D11, D12 (concepts), then D4, D5, D7
(coefficients that live inside those concepts). D8 can be recorded on
day one.

---

### D1 — Survey source, sector, and share bridge

**Nodes:** N13, N16 · **Question:** Q1.2 · **Build plan:** 0.2 ·
**Review:** finding 1 · **Status: PROPOSED** · **Settle by:** week 1

**Revised question.** Which Karger respondent group and paper vintage
does v2 calibrate to, and how does a *nonfarm-business-sector* labor
share (the survey's object) map to the economy-wide factor accounts
the tax bases are built from?

**Why revised.** The original entry searched for a NIPA ratio that
happens to equal 0.555. The survey asks about the nonfarm business
sector, whose BLS labor share imputes proprietors' labor and excludes
large parts of the economy, so a numerical match to an economy-wide
ratio validates nothing. Separately, the review found a source-column
discrepancy: Table 39's **economists'** medians are 55.0 / 54.0 / 52.0,
while the plan's 53.8 and 51.3 come from the pooled **Total** column.
Within the old mapping that switch moves rapid-scenario labor income
from −0.94% to +0.41% of baseline, a sign flip.

**Recommended position (review).** Pin the respondent group and the
archived paper vintage first, before touching the published
calibration. Then build a short sector-to-economy bridge: the share of
the GDP shock falling in nonfarm business; the survey's share change
applied within that sector; other sectors, depreciation, and production
taxes accounted for separately. If a reduced-form national mapping is
kept, label it an assumption and carry an alternative mapping as a
required sensitivity. Map the survey's beginning-of-2025 → beginning-of-2030
window onto tax years explicitly (2029 or 2030 quantities), and say
whether the share change is relative to today's share or to the
projected baseline share.

**Unblocked by:** data-gathering 1.1 (Table 39 notes and the survey
instrument, now with the respondent-group question added), 1.2 (BLS
nonfarm-business labor share and its sector coverage), 1.4 (GDP ↔
national-income bridge).

**Moves:** `g_L`, `g_K` for every variant; whether v1.0's published
calibration needs an erratum (decide separately, after the vintage is
archived).

**Original framing (2026-09-21, superseded).** *Which NIPA triple
`(Y, L0, K0)` does v2 size the shock on? Karger Table 39's 0.555 does not
match compensation over national income (15,227 / 24,473 = 0.622). Lead
(unverified): `(comp + ½·proprietors)/GDP` 2024 = (15,227 + 1,018) /
29,185 ≈ 0.557. Decide D1 before D3.*

---

### D2 — Shock coverage within complete accounts

**Nodes:** N7, N18 · **Question:** Q1.1 · **Build plan:** 0.3 ·
**Review:** findings 2, 7 · **Status: PROPOSED** · **Settle by:** week 2

**Revised question.** Keeping the full accounting universe, which
components *receive* the AI shock, and what is the composition of the
marginal increment across them?

**Why revised.** The original choice was between two totals: broad
capital income ($6,046B) or business-only ($4,777B). The review's point
is that narrowing coverage is a different experiment, not the same one
scaled down by 21%: the shock mapping has to be re-derived from the
aggregate target. Housing can stay in the accounts and simply be
unshocked. Two concept bridges also come before any writer question:
NIPA rental income includes imputed owner-occupied rent, which is not
Schedule E income, and NIPA net interest is not household taxable
interest (it includes offsetting flows and imputations, and fixed-rate
claims don't reprice when profits rise).

**Recommended position (review).** Broad accounts; business sector
shocked; owner-occupied housing unshocked; a fixed financing-cost path
for interest in the reference case, with a broader interest response
(and its debtor side) as a sensitivity. Split market rental from
owner-occupied before deciding whether the Phase 4 rental writer is
needed.

**Moves:** `ΔΠ` and its channel mix; whether the P4 rental writer
(flow-network gap #2) is needed in v2.0.

**Original framing (2026-09-21, superseded).** *Broad NIPA capital
income ($6,046B) or business-only ($4,777B)? Rental (17.7%) and net
interest (3.3%) either belong in the shock or they don't. Keeping rental
obliges a `rent`/`rent_loss` writer that `06_build_counterfactual.R`
doesn't have. Moves `ΔΠ` by −21%.*

---

### D3 — Factor accounts and named non-factor components

**Node:** N16 · **Question:** Q1.2 (the half Q1.2 doesn't cover) ·
**Build plan:** 0.4 · **Review:** finding 2 · **Status: PROPOSED** ·
**Settle by:** week 2

**Revised question.** What is the complete baseline identity
`Y = L + K + Q`, with the same domestic/national and gross/net
convention on every term, and what scenario rule does each named
component of `Q` follow?

**Why revised.** The 13.1% "residual" was partly an accounting error:
the capital base included half of proprietors' income but the labor
comparison left out the other half. Restoring ~$1,018B to labor cuts the
remainder to **8.91%** of national income (on the frozen 2024 receipt).
Two more bridges sit outside that residual: GDP → national income (CFC,
domestic vs national, statistical discrepancy) and compensation →
taxable wages (employer social insurance, pensions, health benefits).
And the micro side disagrees with the macro side: `sole_prop` and `farm`
enter micro labor income in full while the upstream receipt treats half
of proprietors' income as capital, and S-corp profits are classified
differently on the two sides. If the proprietors' capital share is `φ`,
labor gets `1−φ`; N13 currently uses `φ` for the labor addition, which
works only at 0.5.

**Recommended position (review).** One mixed-income split `φ`, used
identically in macro and micro files. Every component of `Q` named and
given a rule (held fixed in levels, scaled with `g_Y`, or shocked); a
true statistical discrepancy kept distinct from components deliberately
held fixed. No unexplained imbalance absorbed into taxable capital
income. Capital gains stay *outside* this identity (see D10).

**Acceptance evidence:** a baseline table plus one toy shock that
reconciles sector coverage, GDP/NI, compensation/wages, mixed income,
and named residual components.

**Unblocked by:** data-gathering 1.3 (full NIPA Table 1.12 2024 column),
plus BEA 1.7.5, 1.10, 1.13 per the review's accounting packet.

**Moves:** the assertion at the N11/N14/N15 interface. **Decide jointly
with D1 and D2** — together they are one accounting specification.

**Original framing (2026-09-21, superseded).** *`resid = g_y·Y0 − ΔΠ −
ΔL` is zero only if `L0 + K0_up = Y0`. On NIPA 2024 L0/NI = 0.622,
K0_up/NI = 0.247, leaving 13.1%. Held fixed, scaled with `g_y`, or
absorbed into the shocked factors? Decide jointly with D8.* (The D8
coupling is dropped: D8 is now deferred.)

---

### D4 — Corporate tax: baseline bridge vs marginal response

**Node:** N19 · **Question:** Q2.1 · **Build plan:** 0.5 ·
**Review:** finding 6 · **Status: PROPOSED** · **Settle by:** week 4

**Revised question.** Two objects, decided separately: (a) a baseline
bridge from economic profits to federal CIT receipts on *compatible*
concepts; (b) the incremental tax on AI-driven profits, built from
separate assumptions for profit composition (normal return vs rent),
investment deductions, losses, credits, and entity/foreign coverage.

**Why revised.** Three problems with the original framing.
(1) **Denominator mismatch:** the 14.7% rate is $491.7B of receipts over
~$3,343B of C-corp profits *without* IVA/CCAdj, but the proposed $3,007B
base is profits *with* them; 14.71% × $3,007B ≈ $442B, not $492B.
(2) Acemoglu–Manera–Restrepo's 5–10% is an effective tax wedge on
investment returns, not a lower bound on receipts per marginal dollar
of profit — **drop it as a bound**. (3) CBO's August 2026 review
reports the −25% corporate receipts over the *first 11 months* of FY2026
and attributes part of it to larger investment deductions under the
2025 act; it does not quantify an AI-specific contribution. Narrow the
attribution in `lit_macro_to_micro_structures.md` accordingly. Also
stop calling the full statutory-to-effective gap "avoidance."

**Recommended position (review).** A coarse version of CBO 59436's
profits → tax-base bridge for (a). For (b), a labeled reduced-form
reference rule plus a small set of interpretable sensitivities
(investment-heavy vs rent-heavy; loss utilization). Permanent 100%
bonus depreciation for property acquired after 2025-01-19 means the
deductions don't simply vanish after a build-out year. Keep federal CIT
distinct from all entity taxes when computing income available to owners.

**Moves:** `ΔR_CIT`. Retires the v1.0 `09` macro-CIT wedge and the
zero-delta tripwire at `09_tables_figures.R:227` — but state where the
existing microsim CIT *baseline* is carried and add the single
incremental amount once (review-context §7: don't add a second baseline
while retiring the old delta formula).

**Original framing (2026-09-21, superseded).** *Baseline average
effective rate (0.147), statutory (0.21), or a time-varying depreciation
wedge? Bounded below by Acemoglu-Manera-Restrepo's 5–10%. FY2026
corporate receipts fell ~25% with AI capex expensing named as a driver.
Borrow CBO 59436's three-wedge decomposition. Moves `ΔR_CIT` by ~40%.*

---

### D5 — Reconciliation ordering

**Node:** R1 (reconciliation, not the retirement cascade) ·
**Question:** Q1.3 · **Build plan:** 0.6 · **Review:** finding 9 ·
**Status: PROPOSED (replaced)** · **Settle by:** week 4

**Revised question.** In what order are the macro-to-PUF adjustments
applied, what does each one mean, and what is left for a final
measurement factor?

**Why revised.** The original proposal applied the historical
SOI-line/NIPA ratio per channel. Once v2 models foreign ownership,
exempt holders, wrappers, and realization timing explicitly (D9–D11),
that historical ratio already *contains* those mechanisms; multiplying
by it afterwards removes the same income twice.

**Recommended position (review).** Factor the bridge into, in order:
(1) concept and coverage adjustments (e.g. imputed rent out, personal
interest vs NIPA net interest); (2) ownership and wrapper allocation
(D9); (3) timing and realization (D10, D11); (4) a final measurement
calibration that addresses **only the unexplained remainder**. Ratios
on comparable universes and years only; additive adjustments where a
denominator is near zero or income changes sign. BEA's personal
income → AGI reconciliation (Table 7.19 lineage) as the starting
taxonomy. Confirm whether Tax-Data's `div_ord` stores ordinary-only or
ordinary-including-qualified dividends before any dividend crosswalk.

**Unblocked by:** data-gathering 4.1, 4.2, 4.5 (unchanged), plus the
`div_ord` convention check.

**Moves:** the level of every PUF delta v2 writes.

**Original framing (2026-09-21, superseded).** *Per channel:
`flow_PUF = flow_NIPA` (benchmark), `flow_NIPA · PUF0/NIPA0` (inherit),
or hybrid. Proposal: the historical SOI-line-to-NIPA-component ratio —
CBO's own individual-side method.*

---

### D6 — Baseline, counterfactual, time and prices

**Node:** N9 (and N4) · **Build plan:** 0.7, 0.10 · **Review:** "A
conditional annual transmission model"; finding 12 ·
**Status: PROPOSED** · **Settle by:** weeks 1–2

**Revised question.** What is the baseline object, what is the
scenario measured against, and how are years and prices handled?
Specifically: (a) annual factor levels by constant-share scaling of 2024
NIPA, or CBO's income projections directly; (b) scenario relative to
the CBO baseline vs an AI-vs-no-AI counterfactual; (c) the macro input
(a GDP-level path, with any TFP input routed through a separate macro
adapter); (d) annual availability of the tax-unit files; (e) policy
vintage; (f) the tax-year / calendar-year / fiscal-year mapping;
(g) price paths (GDP deflator, CPI indexing, wage indexing).

**Why widened.** The original entry was (a) only. The review makes (b),
(c), (f), and (g) week-1/2 concept decisions. On (d): Tax-Simulator's FY
adjustment drops the earliest year, so a single reported year needs the
adjacent tax-year file. Confirm what the vintage actually carries in
week 1 rather than discovering it at the first cluster run.

**Recommended position (review).** Externally supplied real GDP level
path relative to a dated CBO baseline; TFP only through an adapter with
its own closure (never TFP and GDP multipliers on the same base).
Scenario labeled "relative to CBO," with CBO's embedded AI assumption
(+0.1pp/yr, data-gathering 2.4) documented, not silently stacked.
Annual nominal accounting; a common price path for the controlled
real-growth experiment, labeled; a limited price/indexing sensitivity
that updates tax parameters consistently with current law.

**Unblocked by:** data-gathering 2.1–2.4 (unchanged). Outputs
`config/calibration/cbo_2026_02_income.csv`, `cbo_2026_02_revenue.csv`,
then build plan 1.1's `config/cbo_baseline.csv`. Still settles build
plan 0.10 (the CIT 2030 benchmark: 470 vs the 486 implied by the CBO
revenue table — derive from 2.2, don't interpolate).

**Moves:** every annual row; the output contract's year columns.

**Original framing (2026-09-21).** *2030 factor levels by constant-share
scaling of 2024 NIPA, or straight from CBO's income projections (N4 →
N9)? Watch for double-counting CBO's +0.1pp/yr AI assumption.*

---

### D7 — Payout ratio on a matched universe

**Node:** N21 · **Question:** Q2.2 (part) · **Build plan:** 0.8 ·
**Review:** findings 3, "Core accounting relationships" ·
**Status: OPEN** · **Settle by:** week 6

**Revised question.** `p` = dividends of a matched entity universe ÷
that universe's after-tax profits. What is the universe, the level, and
does `p` respond to the share shift? And what happens to `(1−p)`: it is
**retained production income**, not a capital gain. Any effect on
equity values goes through D10's valuation rule.

**Why narrowed.** Personal dividends over all corporate profits mixes
entities, foreign flows, and owner categories. And the original N21 →
N22 path wrote retained profit straight into a capital-gains pool,
which is an assumption, not a conservation identity. The build plan's
step 3.4 test (`dividend share = p/[p+(1−p)r]`) is a share of the
*realized* pool and must not be applied to total after-tax profit.

**Unblocked by:** data-gathering 3.1 → `config/calibration/nipa_1_12_payout.csv`,
restricted to a matched universe. Behavioral response (Karabarbounis–
Neiman, Chen et al.) can motivate a payout sensitivity; it does not
identify the causal coefficient for an AI shock.

**Still retires the implicit duplicate** (flow-network gap #3): the
0.30 / 0.70 public-equity split in `asset_to_income_map.csv` is a payout
ratio and must derive from `p` once `p` exists.

**Scope note:** buybacks (`b`) stay deferred (§2) but need a separate
financing/payout category so they can be added without re-plumbing.

**Original framing (2026-09-21, superseded).** *`div = p·Π_after`,
`ret = (1−p)·Π_after`. Level of `p` (replacing the unverified
"≈0.4–0.5") and whether it responds to the share shift.*

---

### D8 — Labor displacement

**Question:** Q3.1, sharpened · **Build plan:** 0.9, parallel lane ·
**Source:** `labor_exposure_extension.md` decision 1 · **Review:**
finding 11 · **Status: PROPOSED — DEFER** · **Settle by:** week 1

**Revised question.** Is worker displacement in v2.0 at all?

**Recommended position (review).** No. v2.0 keeps S0/S2/S3 as
conditional allocations of a supplied labor total, with explicit
targets and explicit treatment of nonpositive incomes (v1.0's
`y_l == 0` inert class). Decouple the dispersion parameter from GDP
growth enough to run a pure inequality experiment at unchanged GDP.
Occupation imputation, worker splitting, and UI move to a later
release. Reasons: the parallel lane isn't free capacity for one
researcher (the capital phases alone are ~11–14 weeks), and ownership
and tax timing matter more for the first release.

**What the original dilemma becomes.** Job loss and a fixed aggregate
labor-income target *can* coexist (survivor wages, hours, jobs created
elsewhere); the target is a conditional allocation, not a literal
transfer from displaced workers. The real problem is identification:
one aggregate cannot pin down job loss, wages, hours, and
re-employment. Preserved for the later release, together with the
review's implementation notes (workers within joint units, per-worker
payroll caps, tax of expected income ≠ expected tax under weight
splitting).

**Keep now so the extension stays possible:** a labor-target
interface, and worker/tax-unit identifiers in the output contract.

**Original framing (2026-09-21, superseded).** *`Y_1^L = Y_0^L·(1+g_L)`
is given by the Karger path, so "displaced income is pure loss" and the
aggregate target cannot both hold. Relax the target, or accept
reallocation as a modeling choice. D3's labor-side twin.*

---

### D9 — Ownership and wrapper boundary  *(new)*

**Nodes:** new owner stage between entity tax (N19–N21) and household
allocation (A1–A3); absorbs part of Q2.5 · **Review:** finding 5 ·
**Status: PROPOSED** · **Settle by:** week 2

**Question.** Which owner destinations does every production dollar
reach, and in what order are wrappers applied? Every dollar of after-
entity-tax income must reach a named owner category; only the
appropriate share reaches US tax-return lines.

**Recommended position (review).** An entity × owner × wrapper matrix
with at least: US taxable households; traditional DC/IRA; Roth;
DB pensions; tax-exempt institutions; foreign owners; other retained
institutional destinations. A consistent look-through rule for
intermediaries (funds, insurers) so an equity claim isn't counted
directly and again through a fund. Foreign and exempt flows kept as
**reported destinations**, never renormalized onto PUF households.
Foreign-source income of US residents tracked separately from US-source
income of foreign owners. First release: documented aggregate
ownership shares, a simplified foreign-income bridge, and sensitivity
cases — no multinational microsimulation.

**Acceptance evidence:** the review's $100 example (§"A small
example"), plus all-foreign, all-retirement, zero-dividend, and
intermediary-ownership cases. Two tests, not one: (1) sum over all owner
destinations = the distributable flow; (2) the PUF allocation = the
eligible US household flow.

**Data:** Financial Accounts stocks and sector tables (renumbered June
2026 — archive the old F.224/L.224 tables, store persistent series IDs),
SCF, IRA and pension aggregates. To be added to `v2_data_gathering.md`.

**Moves:** the size of every household channel; adds the owner stage to
the flow network and build plan Phase 3.

---

### D10 — Capital-gains object, timing, and basis at death  *(new)*

**Nodes:** N22 (realization); new asset-state ledger · **Question:**
absorbs Q2.3 · **Review:** findings 3, 4 · **Status: PROPOSED** ·
**Settle by:** concept week 2; calibration week 9

**Question.** What is the annual tax object for capital gains, and
what state does the model carry to produce it?

**Why it is a Phase 0 concept decision.** Build plan Phase 4 currently
picks annual vs lifetime *after* seeing real-data results; that's the
wrong order. And the existing calibration chain misreads its source:
CRS R48562's 61.374% (52.17% before the noncompliance adjustment) is a
long-period ratio of realizations to eligible accruals, 1987–2023 — not
an annual hazard on the outstanding stock and not a lifetime
probability. The PUF-implied 0.16 and CBO-implied 0.24 are also
flow/flow ratios. The 0.84 shortcut `1 − (1−r)·φ` treats some
unrealized gain as eventually taxable without saying when, and inherited
property's basis step-up means an heir's sale does not recover the gain
eliminated at death.

**Recommended position (review).** Two linked ledgers. The
**production ledger** carries compensation, operating profits, entity
taxes, dividends, and retained income. The **asset ledger** carries
claim values, basis, new saving/issuance, valuation changes,
realizations, and deferred balances, with the recursion
`U_end = U_start + A − G − E` (unrealized gain, new accrual, gain
recognized, gain removed by basis adjustment) and a defined ordering of
accrual, sale, and death. Run identical rules in baseline and
counterfactual and difference them; no nonnegativity constraint on a
scenario delta. Valuation rule for the first release: a labeled
zero-announcement-revaluation reference case, plus a case that
capitalizes a specified persistent after-tax cash-flow change. Either a
stock-and-hazard or a distributed-lag realization mechanism, calibrated
on matched asset universes. Basis at death modeled once (or an all-in
coefficient that already contains it). Lifetime present values stay out
of the annual revenue tables. Capital gains stay outside the D3 GDP
identity.

**Must also be corrected downstream:** `realization_and_wealth_extensions.md`
§§3.2–3.5 (its authority over realization is withdrawn), architecture
§4.2 and §7 (the claim that upstream sizing "subsumes" the wealth
problem), N22, data task 4.4, and build step 4.1 (drop the
`lifetime factor = 0.84` and `realized ≤ gross flow` tests; replace with
reconciliation of new gains, realizations, basis adjustments, and
closing balance against the eligible pool).

**Moves:** realized LTCG — the original Q2.3 note put this at up to 4×.

---

### D11 — Retirement balances and withdrawals  *(new)*

**Nodes:** A3 (wrapper split); v1.0 `R1` cascade · **Review:**
finding 8 · **Status: PROPOSED** · **Settle by:** concept week 2;
calibration week 6

**Question.** How do upstream returns that accrue inside retirement
wrappers turn into taxable income, and when?

**Why it is needed.** The v1.0 `R1` cascade pools a flow that is
*already* denominated as taxable retirement income and sends it to
recipients. Under upstream sizing that justification breaks: it is an
allocation routine, not an identified response of distributions to new
returns. A baseline distribution/balance ratio is an average
withdrawal rate, not the marginal response to an extra dollar of return.

**Recommended position (review).** Track incremental traditional
DC/IRA balances with an age-sensitive withdrawal rule or a documented
aggregate approximation. Roth separate (qualified distributions are
tax-free). DB benefit formulas held fixed in the near-term reference
case, with funding improvements / sponsor gains reported separately.
Carry deferred balances in stable age × owner × wrapper cells rather
than pretending independently aged tax files form a household panel.
Report deferred economic gains even when the current-year tax is zero.
The `R1` code can still *implement* the allocation of a taxable flow
once this decision determines its size.

**Moves:** retirement-distribution channel levels and timing; the
"deferred" row of the destinations table.

---

### D12 — Distributional estimand and CIT incidence  *(new)*

**Node:** the missing CIT-burden node (formerly a §2 note) ·
**Review:** finding 10 · **Status: PROPOSED** · **Settle by:**
definition week 2; implementation week 10

**Question.** Which household income concepts does v2 publish, and how
is corporate tax incidence represented without double counting?

**Recommended position (review).** Two panels. **Disposable cash
income**, and an **accrual-based economic-income** measure that
attributes retained income and deferred returns once and excludes
duplicated realizations. Valuation changes reported separately.
Owner-burden reference convention consistent with the cash-flow
cascade: CIT is already deducted before profits are allocated, so a
second burden deduction on the same after-entity-tax income would count
it twice. Alternative labor/capital incidence conventions (OTA
81.5/18.5, TPC 60/20/20, CBO 75/25 — recorded in
`lit_macro_to_micro_structures.md`) as a reconciled reporting overlay
with an auditable reconciliation; they are distributional conventions,
not evidence on AI incidence. Rank households by baseline income for
the main comparisons; reranked results as a supplement only.

**Acceptance:** total incidence reconciles across all owners (including
foreign and exempt) and separately for the domestic household subset;
replaces build step 5.1's "household burdens sum to the full CIT
increment" test.

**Moves:** every distributional table; build plan Phase 5.

---

### D13 — Release horizon and required outputs  *(new)*

**Review:** "Recommended direction," "Required exhibits," roadmap
weeks 1–2 · **Status: PROPOSED** · **Settle by:** week 1 (the release
contract)

**Question.** What does v2.0 promise to publish, over which years, and
in what units?

**Recommended position (review).** Scope: federal individual income,
payroll, and corporate income taxes, plus household distribution, given
an annual output and factor-share path, under stated transmission
assumptions. Publication focus on 2030 with annual intermediate
accounting from the starting year; baseline carried through 2036 where
available, but **no ten-year score** until post-2030 shocks and annual
microdata are specified. Required exhibits: a flow reconciliation from
aggregate income to federal tax bases; annual revenue by instrument;
2030 cash and economic-income changes by baseline income group; a table
of income retained / deferred / exempt / accruing abroad; a v1.0
comparison decomposed by mechanism; a ranked sensitivity table.
Refundable credits reported as receipts and outlays separately before
any net fiscal measure (flow-network E2 currently nets them). Revenue
to incremental GDP always shown alongside dollar levels and the
ordinary revenue/GDP ratio. Agreement with the v1.0 headline is **not**
a completion criterion.

**Moves:** the output contract; exit gates of Phases 5–6.

---

## 2. Deferred decisions

Real decisions with no Phase 0 gate. Each gets a D number when its phase
opens, so the numbering stays dense. Rows marked *absorbed* now live in
§1 and are kept here only as a pointer.

| Question | Node | Phase | The question |
|---|---|---|---|
| Q1.4 | — | 6 | Is "inference" the right frame? Only forward from Karger, or ever invert (observe a revenue/share target, back out the implied shock)? Pin down scope before the paper claims one |
| Q2.2 (`b`) | N21 | 3 | Buybacks are payout economically but taxed as realization. Split payout into dividends vs buyback-driven gains? Needs data-gathering 3.2 (Z.1 net equity issuance — note the June 2026 renumbering). Cash paid for shares is not all taxable gain |
| ~~Q2.3~~ | N22 | — | *Absorbed into D10* (annual vs lifetime realization concept) |
| Q2.4 | N17 | 2 | κ tilt: is the entity split of `ΔΠ` the baseline split (0.497) or C-corp-tilted (0.65)? Review: distinguish AI-supplier gains, adopter gains, and losses to displaced incumbent assets; "software is C-corp-concentrated" doesn't identify the legal form of all marginal AI income. Becomes sensitivity 2 (broad vs C-corp/rent-concentrated) |
| Q2.5 | — | out | International **detail** — GILTI, profit-shifting, multinational microsim — stays out. The ownership **boundary** (foreign owners as a destination) is now in D9 and is not optional |
| Q3.2 | P3 | later release | Exposure metric: one score or an ensemble? An exposure score is not a displacement probability. Deferred with D8 |
| Q3.3 | P3 | later release | Cell resolution for occupation signal on the PUF. Deferred with D8 |
| Q3.4 | — | later release | Does the labor margin interact with the capital side? Deferred with D8; the D1/D3 accounting must still let labor and capital changes be read off one identity |
| ~~CIT burden~~ | — | — | *Absorbed into D12* |

---

## 3. Carried-over open items from v1.0

Migrated 2026-09-21 from the gitignored `todo.md` (the v0.1.0
public-release punch list), which is retired — everything else in it was
done or superseded by the v1.0.0 release. Verified against the tree at
`c4b6794`. Numbered `V1-*` to keep them out of the D sequence: these are
operational, not design decisions.

| # | Item | Verified state | Gates |
|---|---|---|---|
| V1-1 | Regenerate the synthetic fixture deterministically | `tests/fixtures/synthetic_tax_data/baseline/tax_units_2030.csv` untouched since `fb41110` (2026-05-26) — still the hand-patched version. The joint-constraints fix is committed, so the generator is authoritative and supersedes the patch | Build plan 0.1 — the golden fixture is frozen *on* this file |
| V1-2 | Native `renv::snapshot()` under cluster R 4.4.2 | `renv.lock` last touched at `968bbf9`, the relabel commit: 4.5.2-resolved versions carrying `"Version": "4.4.2"`. CI-validated, never natively snapshotted | Any v2 phase that adds a package |
| V1-3 | Quantify the M2 pass-through leak on real data | Logging landed (`06_build_counterfactual.R:215-227`, weighted dropped mass). Fires on the synthetic fixture at $2.6B / 1,915 units. The 2026-07-09 full run would have emitted the real number to a gitignored log — **no value is recorded anywhere in the repo**. Review: quantify at the **first usable real-data run** (week 6), not at release | Phase 4's conservation tests, which assume the leak is bounded |
| V1-4 | Archive `Budget-Lab-Yale/ai_fiscal` | Confirmed still open: `isArchived: false`, private, last push 2026-06-11. Checklist in `repo_consolidation.md`; that doc can go once this is done | Nothing — five minutes |
| V1-5 | Attach release assets to `v1.0.0` | `gh release view v1.0.0` returns `"assets": []`. The publishable xlsx and figure PNGs were never attached, so non-R readers can't get the deliverables | Nothing — five minutes |
| V1-6 | Upstream the three Tax-Simulator patches | Filed as issues **#128** (timeburden segfault under `--multicore scenario`), **#129** (non-unique `breaks` in `build_horizontal_table`), **#130** (`mc.cores` oversubscribes shared SLURM nodes) on 2026-06-22 — all three still **OPEN**, no PRs. Diagnosis in `tax_simulator_patches.md`. Review: record the patch diff and its effect on outputs; don't let release timing depend on upstream merging | Phase 6's release candidate, which re-runs the grid through Tax-Simulator and hits all three again |
| V1-7 | Public-methodology sign in the revenue-share formula | Review: the published methodology's displayed rearrangement of `Δz = (ΔR/Y0 − z0·g)/(1+g)` shows a positive sign on the GDP-denominator term; the repo's Markdown and code use the negative sign correctly. A web-document correction only, not a results error. Not re-verified against the live page | Nothing |

Two `todo.md` §C4 leftovers judged not worth carrying: replacing the
hand-rolled `.parse_cli_args` with `optparse`, and standardizing the
`# ====` banner style that only `15_blsmm_debt_gdp.R` uses. One that is
worth a line — there is no `here::` call anywhere in `code/`, though
`here` sits in `requirements.txt`. Bare relative paths work only because
`tax_data_vintage()` aborts outside the project root, and that abort
message names the vintage rather than the working directory, which sends
the reader to the wrong problem.

---

## Appendix A — Tax-Simulator patterns deliberately not adopted

Migrated verbatim from `todo.md` §D (written 2026-05-26 during the
Tax-Simulator comparison), so the divergence isn't relitigated. Kept
because v2 re-opens the interface with Tax-Simulator and these will come
up again.

- **Globbed `source(./src/, recursive = TRUE)`.** Tax-Simulator's
  `src/main.R` walks the tree and sources every `.R` file. We use
  explicit ordered `source(...)` calls in `00_ai_fiscal_sim.R` —
  readable, and a deterministic load order.
- **Committing `.claude/` to the repo.** Tax-Simulator does; we gitignore
  it (per-user state, not portable).
- **No LICENSE.** Tax-Simulator has none. We keep MIT.
- **Hard-coded Yale-Roberts paths in tracked config**
  (`config/interfaces/output_roots.yaml`). We keep env-var-driven paths
  (`AI_FISCAL_SCRATCH_ROOT`, `TAX_SIMULATOR_DIR`, `BLSMM_DIR`).
- **No version pinning** (Tax-Simulator's `requirements.txt` carries bare
  package names). We add `renv.lock`.
- **`config/interfaces/` for dependency-model versioning.**
  Tax-Simulator's `interface_versions.yaml` is elegant for declaring
  dependency vintages. We encode this in the Tax-Simulator runscript
  itself (the `dep.Tax-Data.vintage` column) and in env vars for sibling
  repos. The original note said "worth revisiting if we accumulate more
  sibling deps" — v2's CBO baseline module and the labor lane's exposure
  file are two more, so **revisit this in Phase 1**.
