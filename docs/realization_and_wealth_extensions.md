# Realization and wealth-frame extensions

> Ported 2026-06-11 from the archived dev repo
> (`ai_fiscal/docs/realization_and_wealth_extensions.md`) as part of
> the repo consolidation (`docs/repo_consolidation.md`). Variant
> labels follow the archived repo's history; note this repo's R1
> cascade is the archived repo's R4. The V2/V3 realization variants
> referenced here exist only in the archived repo's code.

**Status:** Planning. Drafted 2026-05-22 by merging the prior
`realization_rate_memo.Rmd` and `wealth_frame_migration.md`.
**Last reviewed:** 2026-05-22.
**Phase:** 0 — v0.1.0 ships under constant realization (V1, income
frame); no extension work begun yet.
**Companion:** `docs/ai_fiscal_methodology.md` (live methodology doc).

This document is the detailed implementation plan for two extensions
that the v0.1.0 methodology deliberately defers. They are presented
together because they are inseparable: under the current V1 income
frame the realization rate is mechanically 1, so any meaningful
parameterization of $r$ requires first redefining $X$ to include
unrealized accruals — which is exactly the wealth-frame
redefinition.

## 1. Why these extensions matter

The published model defines

$$
X \;=\; g_k \cdot K_0, \qquad K_0 = \sum_i w_i \cdot \mathrm{YiK}_i,
$$

where $\mathrm{YiK}_i$ is realized, taxable capital income on the
PUF. Under that construction the baseline realization rate is
already inside $K_0$, and the model holds it constant as $g_k$ is
applied. The choice is internally consistent — it is the V1 default
documented in the realization-timing section of the methodology —
but it forecloses two kinds of analysis that the model will
eventually need to support:

1. **Realization-rate parameterization.** Once we want to evaluate
   policy changes that affect the *rate* of realization (a step-up
   reform, an accrual-tax proposal, a holding-period change), the
   model has to expose $r$ explicitly rather than burying it in the
   construction of $X$.
2. **Wealth-frame shock.** If AI-driven returns can show up as
   higher asset valuations as well as higher cash flow, the shock
   should be on wealth growth ($\Delta W$), not on realized-income
   growth ($X$). The per-class realization rules then convert
   wealth accrual back into PUF income lines.

These two extensions plug together: a wealth-frame $\Delta W$ on the
input side, with explicit per-class realization rules on the output
side. The rest of the document describes the redefinition and the
calibration choices that go with it.

## 2. Wealth-frame redefinition of $X$

### 2.1 The frame mismatch in the current code

The model has an internal inconsistency that the constant-realization
assumption papers over but does not resolve. Three observations:

1. **$X$ is calibrated as an income flow.**
   `compute_macro_targets()` computes
   $K_0 = \sum_i w_i \cdot \mathrm{YiK}_i$ and $X = K_0 \cdot g_k$.
   $\mathrm{YiK}$ is realized, taxable capital income (it includes
   `txbl_pens_dist + txbl_ira_dist`, the *taxable* portion of
   retirement distributions, and the realized LTCG flows already on
   the PUF). So $X$ is denominated in dollars of realized, taxable
   capital income.

2. **The within-unit allocation is wealth-weighted.**
   `allocate_across_units()` distributes $X_{\mathrm{to\_units}}$
   across tax units proportional to gross asset holdings
   $A^{\mathrm{base}}$. `allocate_within_unit()` then splits each
   $X_i$ across the four income-bearing classes (equities, bonds,
   pass-throughs, retirement) proportional to *wealth* in each
   class — not proportional to the class's contribution to the
   unit's income.

3. **Realization is applied piecewise.** The interest, dividend,
   and pass-through slices implicitly assume 100% realization
   (everything flows as current-year ordinary income). The retirement
   procedure inherits the baseline realization rate by construction.
   The LTCG slice is treated as fully realized under V1.

Observations (1) and (2) are inconsistent: if $X$ is income-units,
splitting it by wealth-shares makes the retirement and LTCG slices
systematically mis-sized relative to interest, dividends, and
pass-through. The constant-realization assumption resolves this by
holding everything at the baseline rate; a non-trivial extension
forces the question.

The clean resolution is to redefine $X$ at the wealth level so the
within-unit step and the per-class realization step are doing the
same thing for every income class.

### 2.2 Target architecture

```
[macro shock]
  gW = wealth growth rate (new; calibrated against DFA / SCF totals)
  ΔW = K0_wealth · gW                 ← wealth accrual (was X)

[CIT wedge]
  ΔR_CIT = τ_C · κ_corp · ΔW           ← unchanged in form
  ΔW_to_units = ΔW · (1 − τ_C · κ_corp)

[across units]
  ΔW_i ∝ A_base_i                     ← unchanged

[within unit]
  ΔW_i^{class} = ΔW_i · A_class_i / A_inc_i   ← unchanged in form,
  but now all four classes are wealth accruals (not income flows)

[per-class realization]
  Each class has an explicit realization rule R_class(·):
    equities       → r_div · ΔW^{eq}   becomes dividends
                     r_lt  · ΔW^{eq}   becomes LTCG (with step-up φ)
                     (1 − r_div − r_lt) stays unrealized
    bonds          → 100% realized as taxable / tax-exempt interest
    pass-throughs  → 100% realized as ordinary K-1 income
    retirement     → r_R · ΔW^{ret}   becomes pension/IRA distribution
                     (1 − r_R) stays deferred
```

The output PUF columns remain `txbl_int`, `exempt_int`, `div_ord`,
`div_pref`, `kg_lt`, `scorp_*`, `part_*`, `gross_pens_dist`,
`txbl_pens_dist`, `txbl_ira_dist` — same shape as today, just
driven by a wealth-frame allocator.

### 2.3 What is calibrated where today, and where it needs to come from

| Quantity            | Today                              | Wealth-frame source                                                                                |
|---------------------|------------------------------------|----------------------------------------------------------------------------------------------------|
| `gk`                | NIPA capital-income share shift    | Replace with `gW` calibrated against DFA wealth aggregates or a documented `gW = f(gk)` mapping     |
| `K0`                | $\sum w \cdot \mathrm{YiK}$ (income)| `K0_wealth = $\sum w \cdot A^{\mathrm{base}}$` (wealth)                                            |
| Equity realization  | V1/V2/V3 LTCG rate $r$, step-up $\varphi$; div/LTCG split 0.30/0.70 fixed in `asset_to_income_map.csv` | Decompose into `r_div`, `r_lt` with explicit sources (NIPA personal dividends / NIPA realized LTCG over DFA equity stock) |
| Bond realization    | 100% implicit                       | `r_int = 1.0` explicit; exempt share already per-unit                                              |
| Pass-through        | 100% implicit                       | `r_pt = 1.0` explicit                                                                              |
| Retirement          | Inherits baseline rate              | `r_R = 0.0492` from SOI/DFA (see §4 below) applied consistently against wealth accrual              |
| CIT wedge           | Applied to income $X$               | Apply to $\Delta W$ instead — economically the same wedge, but the magnitude shifts with the base   |

Two non-trivial calibration questions, both deserving their own
investigation tickets:

1. **`gW` vs `gk`.** These are not the same number. NIPA capital
   income / NIPA wealth ≈ aggregate return on wealth ≈ 5–7%. If the
   AI shock changes capital income by `gk · K0` and the implied
   wealth change is `gk · K0 / r̄`, then
   `gW = gk · K0 / (r̄ · W₀) = gk · (K0 / W₀) / r̄`. Whether this
   collapses to `gW = gk` depends on how AI-induced returns split
   between higher current-year cash flow and higher asset
   valuations. **TODO:** literature/data review on AI capital-share
   projections to ground this.
2. **Per-class realization rates `r_div`, `r_lt`.** Pull from NIPA
   personal dividends and SOI realized LTCG, divided by DFA equity
   stock. Same vintage as the retirement-income calibration in §4.

## 3. Realization-rate parameterization (V2 and V3)

This section anchors the explicit realization rate $r$ that V2 and
V3 require once $X$ (or $\Delta W$) captures unrealized accruals.

### 3.1 Where $r$ enters the simulation

Under the wealth-frame extension, the LTCG portion of $\Delta W$
flows to the PUF `kg_lt` column according to a realization rule:

- **V1** (mechanical): $X^{\mathrm{LTCG}}_{V1} = X^{\mathrm{LTCG}}_{\mathrm{gross}}$.
  Defensible only when $X$ is constructed off the already-realized
  base (the current v0.1.0 default).
- **V2** (realization-adjusted):
  $X^{\mathrm{LTCG}}_{V2} = r \cdot X^{\mathrm{LTCG}}_{\mathrm{gross}}$.
  Requires $X$ to capture unrealized as well as realized gains.
- **V3** (lifetime PV): treats the unrealized pool as compounding at
  $\rho$, realized at hazard rate $r$, discounted at $\delta$, with
  whatever remains at horizon $T$ subjected to a step-up haircut
  $\varphi$. Not consumed by Tax-Simulator (annual-flow object),
  reported as a diagnostic.

The current placeholder value in `config/scenario_params.yaml` is
`realization.rate_r: 0.60`. The remainder of this section documents
the calibration anchors and the labelling questions that need
resolution before that value enters a publishable run.

### 3.2 Primary anchor: CRS R41364

CRS report **R41364**, *Capital Gains Tax Options: Behavioral
Responses and Revenues* (Hungerford et al., March 3, 2026 update;
original August 10, 2010), reports a
**realizations-to-accruals ratio of 61%** over the period 1987–2023.
CRS uses this figure to bound elasticity estimates: realized gains
cannot exceed accrued gains in the long run, so the realization rate
is a hard ceiling on the long-run behavioral response of revenue to
rate changes. The report also presents a sensitivity at 80% (a
near-full-realization counterfactual) to illustrate the upper bound.

The 61% figure is best read as a **lifetime / cumulative** concept:
across a long enough horizon, 61% of accrued equity gains
eventually find their way onto a Schedule D and the remaining 39%
escape via step-up at death (or other realization-suppressing
channels). This differs from the year-by-year marginal realization
rate that an annual budget projection works with.

### 3.3 Counter-anchors and the annual-vs-cumulative distinction

Three alternative anchors point at lower values of $r$. None refutes
the CRS reading — they describe a *different concept*.

#### A. PUF-implied annual rate

| Aggregate                                | $B (weighted, 2030) | % of GDP |
|------------------------------------------|-----------:|---------:|
| Net long-term gains (`kg_lt`)            |        857 |   2.38%  |
| Net short-term gains (`kg_st`)           |       −298 |  −0.83%  |
| Other gains (`other_gains`)              |         22 |   0.06%  |
| Total net realized gains                 |        581 |   1.61%  |
| Tax-Data imputed equity accruals         |      5,526 |  15.35%  |
| Tax-Data imputed passthrough accruals    |      2,007 |   5.58%  |
| Tax-Data imputed primary-home accruals   |      2,599 |   7.22%  |

The PUF's own ratio of realized LTCG to imputed equity accruals is
**15.5%** in 2030 — the *annual* equity realization rate implicit in
the Tax-Data projection. This is far below CRS's 61%, but the two
are not contradictory: 15.5% per year compounded over the holding
period plausibly accumulates to a 60%-range lifetime ratio, with
the residual escaping via step-up.

#### B. CBO 3.7%-of-GDP long-run R/Y anchor

CBO's February 2023 *Projections of Realized Capital Gains Subject
to the Individual Income Tax* (publication 58914) reports realized
gains averaging **3.7% of GDP over the past 40 years**, with the
2033 baseline projection returning to that level. Inverting this
target against the Tax-Data accruals series produces a within-year
$r$:

$$
r_{\mathrm{CBO}} \;=\; \frac{0.037 \cdot Y}{\mathrm{accruals.equities}}
                  \;=\; \frac{0.037}{0.1535} \;\approx\; 0.24.
$$

This is also an annual-flow concept (R/Y measured year-by-year),
and also lands well below 0.60.

#### C. JCT / Auerbach–Hassett literature range

JCT methodology, Auerbach–Hassett (1991), and DMM (2015) collectively
anchor the annual marginal realization rate at **0.20–0.35**. This
is the conventional default for short-run revenue scoring of a
within-year capital-income shock.

#### D. Side-by-side

| Concept                                                  | Anchor          | $r$ implied |
|----------------------------------------------------------|-----------------|------------:|
| Lifetime / cumulative realization-to-accruals (1987–2023)| **CRS R41364**  |   **0.61**  |
| Annual R/Y pinned to 40-year mean                        | CBO 58914       |     0.24    |
| Annual marginal — kg_lt / accruals.equities (PUF 2030)   | Tax-Data        |     0.16    |
| Annual marginal — literature range                       | JCT / AH        | 0.20–0.35   |

### 3.4 Why $r = 0.60$ is a defensible choice (and where it stings)

**Defense.** The AI-shock channel in this simulation is not a
within-year revenue score on existing realized flows; it is an
**incremental gain flow** generated by a structural shift toward
capital that compounds over many years. Applying CRS R41364's 61%
to that incremental flow says: of every new dollar of accrued
AI-driven gain, ~60 cents will eventually be realized and taxed;
~40 cents will escape via step-up. That is the right object for a
long-run revenue projection driven by a persistent shock.

The CBO 3.7%-of-GDP anchor and the JCT/AH annual-rate range
describe a *steady-state distribution* of within-year realizations
across a typical historical year. They are appropriate for
short-run scoring of small perturbations, not for the cumulative
revenue tail of a multi-decade structural change.

**Sting.** Treating $r$ as a cumulative coefficient but applying it
to an annual gross-gain flow without explicit horizon discounting
will over-count revenue if the analyst reads the V2 output as a
within-year number. Two mitigations exist already in the code:

- `X_ltcg_V2_lifetime = (1 - (1-r) · phi) · X_ltcg_gross` is the
  eventual taxable base once step-up is netted off. At $r = 0.60$
  and $\varphi = 0.40$, the lifetime factor is 0.84 — i.e., 84% of
  gross gains are eventually taxed (60% realized in life + 24%
  realized by heirs after a 40%-haircut step-up).
- V3 is the explicit lifetime-PV variant. With $\rho = \delta =
  0.04$ and horizon 30, V3's PV factor at $r = 0.60$ is well-behaved
  ($q$ far below 1) and bounded.

The honest read: V2 with $r = 0.60$ is closer to a lifetime concept
than an annual one, and the labelling should reflect that. A reader
expecting an annual marginal realization rate will need a footnote.

### 3.5 Calibration options for the V2 sensitivity table

| Option                                                  | Description                                                                                              | Pros                                                                                  | Cons                                                                                          |
|---------------------------------------------------------|----------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| **A. Keep $r = 0.60$** (status quo)                     | Anchored to CRS R41364's 61% lifetime ratio. Treat V2 as a lifetime/cumulative concept.                  | Single anchor for a long-run structural shock; matches the eventual revenue tail.      | Reader-confusing if V2 is read as a within-year coefficient; need explicit footnote.          |
| **B. Switch to $r \approx 0.24$** (CBO-anchored annual) | Anchored to CBO 3.7% of GDP, derived from accruals.equities / Y.                                          | Restores comparability with JCT/AH annual scoring; transparent CBO receipt.            | Throws away CRS R41364 as the headline anchor; less defensible for multi-decade tails.        |
| **C. Hybrid: $r$ per concept**                          | V2 at the annual rate (~0.25) for short-run scoring; V2_lifetime / V3 at $r = 0.60$ for the long-run tail.| Discloses both concepts; readers can pick the relevant horizon.                        | Two numbers to explain; doubles the output surface.                                            |
| **D. Per-variant derivation**                           | Compute $r$ per S/M/R variant from a shock-conditioned R/Y rule.                                          | Variant-specific; R/Y preserved under each shock.                                      | Three different $r$ values; small numerical movement around current value.                    |

**Recommendation: Option A with the footnote.** Keep
`realization.rate_r = 0.60` cited to CRS R41364, but add a one-line
header to the V2 outputs in the publishable workbook stating that
the rate is calibrated to a *lifetime* realizations-to-accruals
concept and that an *annual-marginal* sensitivity at $r = 0.25$ is
in the appendix table.

### 3.6 Concrete next steps

1. **Add a sensitivity panel** to the publishable bundle showing
   revenue at $r \in \{0.20, 0.25, 0.35, 0.60, 0.80\}$. This range
   spans the JCT/AH lower bound, the prior model value, the
   literature ceiling, the CRS central anchor, and CRS's
   high-realization scenario.
2. **Re-label V2** in the figures and the publishable workbook from
   "realization-adjusted (annual)" to "realization-adjusted
   (lifetime, CRS R41364)". V1 and V3 captions already disclose
   horizon.
3. **Send the PUF–SCF questions in §3.7** before deciding whether to
   level-shift the `kg_lt` baseline. The 1.3 pp gap to CBO may be
   deliberate; we should not silently override it.
4. **Land the labeling/horizon discussion** in the
   realization-timing section of
   `docs/ai_fiscal_methodology.md` once V2 is wired into the
   publishable grid.

### 3.7 Questions for the PUF–SCF team

1. What long-run R/Y target is embedded in the Tax-Data `kg_lt`
   projection module? Is it explicitly calibrated to CBO's 3.7%
   anchor, or does the value fall out of a separate behavioral /
   aging procedure?
2. The Tax-Data 2030 projection of $857B in net LTCG runs ~1.3 pp
   of GDP below CBO's published 40-year mean. Is this a deliberate
   forecast difference (e.g. adjusting for projected tax-rate
   changes) or an unintentional undershoot?
3. How was `accruals.equities` calibrated? Is the implied
   15.5% annual realization rate (the `kg_lt / accruals.equities`
   ratio) considered an output of the model, an input, or
   unanchored? Does it compound over a holding period to something
   near CRS's 61% lifetime ratio?
4. For our downstream use — adding an incremental gain flow on top
   of the baseline and projecting its tax consequences over a
   multi-decade horizon — does the PUF–SCF team view the CRS R41364
   lifetime ratio or the Auerbach–Hassett annual marginal rate as
   the appropriate coefficient?

## 4. Implications for retirement income

The retirement procedure documented in the methodology assumes the
flow of taxable retirement income embedded in $X$ already captures
both the realization rate of capital assets held in retirement
accounts and the share of those realizations that are taxable. Most
retirement wealth is held in tax-deferred vehicles (401(k), IRA,
traditional pensions); if we move to a realization-adjusted model,
the marginal AI dollar flowing into those accounts will not be
taxed in-year. The extension therefore requires modeling not just a
realization rate $r_R$ but also the flow of assets into taxable and
non-taxable income streams.

We propose to discipline these rates using published IRS statistics
on gross and taxable pension and IRA income, along with overall
measures of retirement wealth. IRS SOI Publication 1304 Table 1.4
reports the size of gross and taxable pension distributions as well
as taxable IRA distributions by AGI bracket through 2023. IRS SOI
*Accumulation and Distribution of Individual Retirement Arrangements*
Table 1 reports overall withdrawals and the fair market value of
IRAs by type of plan through 2022. Combined with the Federal
Reserve's Distributional Financial Accounts measure of pension
program value, these give an overview of retirement wealth and
income.

### 4.1 Five national constants

| input               | value         | source                                            |
|---------------------|---------------|---------------------------------------------------|
| pensions gross dist | $1{,}528.4$B  | SOI Pub 1304 Table 1.4                            |
| pensions taxable    | $911.7$B      | SOI Pub 1304 Table 1.4                            |
| IRA gross dist      | $499.2$B      | SOI IRA Bulletin Table 1                          |
| IRA taxable         | $437.8$B      | SOI Pub 1304 Table 1.4                            |
| retirement wealth   | $41.2$T       | DFA (DB + DC) + SOI IRA FMV                       |

### 4.2 Derived ratios

$$
r_R \;=\; \frac{G_P + G_I}{W_R}, \quad
s_P \;=\; \frac{G_P}{G_P + G_I}, \quad
s_I \;=\; 1 - s_P, \quad
\tau_P \;=\; \frac{T_P}{G_P}, \quad
\tau_I \;=\; \frac{T_I}{G_I}.
$$

Plugging in the 2022 numbers:

$$
r_R \;=\; 0.0492, \quad
s_P \;=\; 0.7538, \quad
s_I \;=\; 0.2462, \quad
\tau_P \;=\; 0.5965, \quad
\tau_I \;=\; 0.8770.
$$

Under the wealth-frame extension, the retirement realization rule
becomes:

- $r_R \cdot \Delta W^{\mathrm{ret}}$ becomes a current-year
  pension/IRA distribution flow.
- The flow is split $s_P / s_I$ between pension and IRA.
- The gross-to-taxable conversion uses $\tau_P$ and $\tau_I$ on
  each side.
- The remaining $(1 - r_R) \cdot \Delta W^{\mathrm{ret}}$ stays
  deferred.

Applying these statistics to a value of $X$ based on wealth or
unrealized gains gives a static estimate of the distribution of
retirement income due to AI growth. Extensions could then layer
behavioral responses on top.

### 4.3 SCF DB caveat

The Survey of Consumer Finances measures self-reported
defined-benefit balance / surrender value; the Distributional
Financial Accounts measure actuarial PV of future entitlements. At
2022, the microsim DB aggregate is $2.6$T against $16.8$T DFA — a
six-fold structural gap. This is why $r_R$ is anchored to DFA
aggregates rather than the microsim sum; closing the gap is upstream
tax-data work, not an in-scope extension.

## 5. Code changes (in dependency order)

| # | File                                                | Change                                                                                                                                                                                                                                                                  |
|---|-----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `config/scenario_params.yaml`                       | New top-level `frame: wealth` (`income` for back-compat); when `wealth`, expect new `gW` and per-class realization keys.                                                                                                                                                  |
| 2 | `config/wealth_frame_calibration.yaml` *(new)*      | Source-cited values for `gW`, `r_div`, `r_lt`, `r_int`, `r_pt`. Same `_status` / `_source` metadata convention as the existing yamls.                                                                                                                                     |
| 3 | `code/02_params.R`                                  | Load wealth-frame calibration when `frame = wealth`; keep `gk` path live for `frame = income`.                                                                                                                                                                            |
| 4 | `code/04_allocate_capital.R::compute_macro_targets()` | Branch on frame: under `wealth`, compute `K0_wealth = Σ w · A_base` and `ΔW = K0_wealth · gW`. CIT wedge still in dollars (same form).                                                                                                                                  |
| 5 | `code/04_allocate_capital.R::map_to_income_types()` | Per-class realization. Equity: split `ΔW^{eq}` into `r_div · ΔW^{eq}` (`div_pref` column) and `r_lt · ΔW^{eq}` (LTCG, fed into the existing `05_realization.R` step-up haircut). Bonds: 100% to taxable/exempt per the existing exempt-share split. Pass-throughs: 100% to ordinary. Retirement: apply $r_R \cdot s_P \cdot \tau_P$ etc. per §4.2. |
| 6 | `code/05_realization.R`                             | Strictly a step-up function under wealth frame (LTCG quantity now comes pre-realized from step 5); behavior under income frame unchanged.                                                                                                                                  |
| 7 | `code/06_build_counterfactual.R`                    | No change to PUF column updates; the inputs (`X_qualified_div` etc.) are framework-agnostic.                                                                                                                                                                              |
| 8 | `code/08_aggregate.R`                               | Add wealth-frame parameter sheets; the existing slice / realized / unrealized triad on the retirement aggregates lines up naturally with the new wealth-frame retirement rule.                                                                                            |
| 9 | `code/11_validation.R`                              | Add wealth-frame validation: `Σ w · ΔW = ΔW_aggregate` (preserved), per-class realized aggregates ≈ NIPA-implied targets.                                                                                                                                                 |

## 6. Phasing

1. **Phase 0 — current state (2026-05-22).** v0.1.0 ships under
   constant realization (V1, income frame). The retirement procedure
   inherits the baseline realization rate by construction. Both
   extensions described here are deferred.
2. **Phase 1 — calibration.** Build
   `config/wealth_frame_calibration.yaml` with sourced values for
   `gW`, `r_div`, `r_lt`. Cross-check that
   $r_{\mathrm{div}} + r_{\mathrm{lt}} + (1 - r_{\mathrm{div}} - r_{\mathrm{lt}})$
   matches the equity composition in the current
   `asset_to_income_map.csv` at the *income* frame (sanity check;
   not a hard constraint).
3. **Phase 2 — toggle plumbing.** Add `frame: income | wealth` knob
   to `scenario_params.yaml` and the loader. Default stays `income`
   until Phase 4 validates.
4. **Phase 3 — wealth-frame allocator.** Implement the changes in
   `04_allocate_capital.R` and `05_realization.R` per the table
   above. Both frames live side-by-side, selected by config.
5. **Phase 4 — validation.** Run both frames on the same year,
   compare aggregate revenue effects and decile incidence.
   Reconcile differences against NIPA / DFA / SOI benchmarks.
   Expect a meaningful but not wild divergence — if it's wild,
   the Phase 1 calibration is wrong.
6. **Phase 5 — switch default.** Flip `frame: wealth` in
   `scenario_params.yaml`. Mark `frame: income` as legacy.
7. **Phase 6 — doc & figures.** Update the capital-side and
   retirement-flow sections of `docs/ai_fiscal_methodology.md` to
   describe the wealth frame as the headline model; the V2/V3
   realization variants enter the publishable grid as sensitivities.

## 7. Open questions

- **How does the labor side respond?** $L_1 = L_0 \cdot (1 + \alpha \cdot g_k)$
  is in income units. Under the wealth frame, do we still
  parameterize via $g_k$, or do we need a separate labor-shock
  parameter? Probably the former (labor compensation is naturally
  a flow), but the bookkeeping needs to be explicit when $g_k$ is
  no longer the headline capital knob.
- **Should the CIT wedge be on $\Delta W$ or on the realized
  portion?** Statutory CIT applies to corporate profits (a flow),
  not to wealth accrual. Strictly, the wedge should apply to
  $r_{\mathrm{div}} \cdot \Delta W^{\mathrm{eq}}$ +
  retained-earnings-share. The current shortcut of applying it to
  all of $X$ is defensible only because everything's already
  realized. The wealth-frame migration forces a more careful
  treatment.
- **Top-share sensitivities.** Wealth shares are more concentrated
  than income shares; the wealth-frame allocator will push more of
  every shock to the top decile. Worth a sanity check against the
  current figures (figures 5/6 in the 2030 suite).
- **Backward comparability.** Once the default flips, prior runs
  are not directly comparable. Pin a `frame: income` parallel run
  for every figure for at least one release cycle.

## 8. Out of scope

- ETI behavioral response.
- Macro feedback loops (wealth growth → savings → wealth growth).
- Endogenous portfolio rebalancing in response to AI shocks.

All three are documented elsewhere as longer-term extensions.
