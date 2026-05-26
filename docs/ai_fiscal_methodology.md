---
output:
  word_document: default
  html_document: default
---
# Methodology: How potential AI futures interact with the current tax system

## Introduction

This document describes the methodology behind The Budget Lab's report
*How potential AI futures interact with the current tax system*. We
combine projections of the economic effects of AI over the medium term
from Karger et al. (2026) with the same microdata that powers our tax
microsimulation model to produce a counterfactual estimate of each tax
unit's capital and labor income under different AI scenarios. The
analysis isolates the mechanical revenue impact of the three
interacting features of any potential AI growth scenario: increased
GDP growth, a shift in the labor- and capital-share of factor income,
and a change in the distribution of labor income.

The simulation runs end-to-end at the tax-unit level, and almost every
distributional output is computed from per-unit microdata. The one
exception is the corporate income tax (CIT): we capture the revenue
effect of the shock on the CIT base through a single macro wedge,
rather than re-deriving corporate liability from per-firm data, and
discuss the implications of that choice below.

The model is calibrated as a *constant-realization* simulation: $X$ —
the aggregate AI-induced capital income flow — is sized off the
on-1040 realized taxable base, so the baseline realization rate (and other 
factors like the taxation of retirement income) is already
embedded in the construction. Under this assumption, AI capital
income is realized in-year at the same rate as the baseline stock.

## Data and baseline construction

### The tax microsimulation file

All tax-side computations use The Budget Lab's tax microsimulation.
The base file is the 2015 IRS Public Use File (PUF, ~150,000 records),
supplemented with non-filer imputations and aged to the baseline year
through SSA population weights and CBO economic scaling. The
Tax-Simulator calculator handles individual income tax (AGI, standard
and itemized deductions, ordinary and preferential rates, AMT, NIIT,
EITC, CTC, CDCTC, education credits, Saver's, QBI) and the payroll-tax
module. It does not handle the corporate income tax or the estate tax;
we address the CIT through the wedge described below.

The tax microsimulation alone does not carry asset-level wealth, which
we need to allocate AI-driven capital income across households. To
address this, each year pairs the PUF income columns with imputed
asset holdings drawn from the Federal Reserve's Survey of Consumer
Finances (SCF): cash, equities, bonds, retirement balances, life
insurance, annuities, trusts, real-estate funds, primary and other
home equity, and pass-through equity, as well as active/passive
splits for S-Corp and partnership profit. The PUF-SCF match is
validated against aggregates from NIPA, SOI, and the Distributional
Financial Accounts (DFA) upstream in the data pipeline. This project
uses the PUF-SCF matched file as the ground truth.

### Per-unit labor and capital aggregates

Once the merged file is loaded, we construct two per-unit aggregates
that drive all downstream redistribution:

- **Analytic labor income** ($\mathrm{YiL}_i$): wages, sole-proprietor
  and farm income, and the labor portion of each unit's S-Corp and
  partnership net profit.
- **Analytic capital income** ($\mathrm{YiK}_i$): interest (taxable
  and exempt), dividends (ordinary and preferential), realized capital
  gains, other gains, net rent and estate income, taxable IRA and
  pension distributions, plus the capital portion of S-Corp and
  partnership net profit.

These analytic aggregates are used only for designing the shock; the
counterfactual file ultimately uses the underlying PUF columns, not
$\mathrm{YiL}$ or $\mathrm{YiK}$.

### Splitting pass-through profit between labor and capital

S-Corp and partnership profit blends true entrepreneurial labor ("a
partner is paid for working") with returns on invested capital ("a
partner is paid for owning"). The split matters: a shift from wages
to capital income carries different tax consequences than a shift
from wages to pass-through active income, even when the dollar
amount is the same. To address this we adopt the Saez and Zucman
(2020) decomposition, which applies the wage threshold $W^\star$
directly at the tax-unit level.

For each tax unit, let $W^\star$ be the 99.99th percentile of positive
wages. Within each active pass-through bucket (S-Corp active,
partnership active), profit up to $W^\star$ is classified as 25%
capital / 75% labor; profit above $W^\star$ is 75% capital / 25%
labor. Passive profit is flat 75% capital. The intuition is that an
active partner earning at or below typical top-end wages looks like
they are being paid mostly for their labor, while an active partner
whose draw vastly exceeds top wages is more plausibly receiving rents
on firm capital. SZ (2020) apply $W^\star$ as a firm-level threshold; we
apply it directly at the tax-unit level (no owner-manager $\bar n$
bridging), which collapses the multi-owner dimension. The simplification
matters most at the very top of the wage distribution, where a small
share of pass-through profit sits above $W^\star$ either way.

## Macro shock parameterization

Table 1 reports the values that are implied by our implementation of
Karger et al. (2026) economic forecasts. The three key parameters
are:

- a post-shock labor / capital share of factor income ($\theta_1^L$,
  $\theta_1^K$) at the policy horizon, reported as a 5-year-ahead
  median across analyst forecasts; and
- an annualized real GDP growth rate $r^{\mathrm{AI}}$ over the same
  horizon, again as a median across forecasts.

Three intensity variants are published: Slow, Moderate, and Rapid
(labeled S, M, R). We take 2030 as the baseline year to match
Karger's 5-year horizon and pin every variant from Tables 19 (growth
rates) and 39 (labor shares).

Karger et al. (2026) surveys several different groups of AI experts;
we use estimates for the economist subsample. Our microsimulation
already ages the IRS PUF to the baseline year along the Congressional
Budget Office's (CBO) no-AI growth path (2026 = 2.2%, 2027+ = 1.8%).

### Table 1. Key parameters

|                                                            | **Slow (S)** | **Moderate (M)** | **Rapid (R)** |
|------------------------------------------------------------|-------------:|-----------------:|--------------:|
| *AI-adoption inputs (5-year horizon, 2025–2030)*           |              |                  |               |
| Annual GDP growth under AI ($r^{\mathrm{AI}}$)             |       2.0%   |        2.6%      |       3.3%    |
| 2030 capital share ($\theta_1^K$)                          |      45.0%   |       46.2%      |      48.7%    |
| 2030 labor share ($\theta_1^L = 1 - \theta_1^K$)           |      55.0%   |       53.8%      |      51.3%    |
| *Derived growth bumps, cumulative over 5 years, above CBO* |              |                  |               |
| GDP ($g_y$)                                                |      0.59%   |        3.58%     |       7.17%   |
| Capital ($g_k$)                                            |      1.72%   |        7.54%     |      17.28%   |
| Labor ($\alpha \cdot g_k$)                                 |     −0.32%   |        0.41%     |      −0.94%   |
| *Labor-income inequality parameter $\sigma$ (k = 1)*       |              |                  |               |
| Compressive ($\sigma_{S2} = 1 - k \cdot g_y$)              |      0.994   |        0.964     |       0.928   |
| Proportional ($\sigma_{S0}$)                               |      1.000   |        1.000     |       1.000   |
| Expansive ($\sigma_{S3} = 1 + k \cdot g_y$)                |      1.006   |        1.036     |       1.072   |

*Sources.* Karger, Buehler, Cox, Saint-Jacques, and Bjorkegren (2026);
CBO (2025); Budget Lab calculations.

*Notes.* The Slow / Moderate / Rapid columns correspond to Karger's
AI-adoption variants, which differ in two paired targets: the
annualized GDP growth rate under AI and the post-shock capital share.
All derived growth rates are cumulative over the Karger 5-year horizon
(2025–2030) and net of the no-AI CBO baseline path — i.e., they
isolate the AI contribution.

### From shares and growth to growth rates by factor

Let $\theta_0^L$ and $\theta_1^L$ be the baseline and post-shock labor
shares of factor income, with capital shares
$\theta_t^K = 1 - \theta_t^L$. Let $H = 5$ be the Karger horizon and

$$
\mathrm{G_{CBO}} \;=\; (1 + g^{\mathrm{CBO}}_{2026}) \cdot (1 + g^{\mathrm{CBO}}_{2027+})^{H-1}
$$

be cumulative CBO growth from 2025 to 2030. Then

$$
g_y \;=\; \frac{(1 + r^{\mathrm{AI}})^H}{\mathrm{G_{CBO}}} - 1
$$

is the additional 5-year growth in nominal factor income caused by
AI. For the three variants this deviation works out to roughly +0.6%
(S), +3.6% (M), and +7.2% (R) above the CBO baseline at year 2030.

We then derive the per-factor growth rates from the share and growth
targets:

$$
\begin{aligned}
g_k &= \frac{\theta_1^K \cdot (1 + g_y) - \theta_0^K}{\theta_0^K}, \\
\alpha &= \frac{1}{g_k} \cdot \frac{\theta_1^L \cdot (1 + g_y) - \theta_0^L}{\theta_0^L}.
\end{aligned}
$$

We refer to $\alpha$ as the normalized labor growth rate: under a
reallocation shock $\alpha < 1$ (labor grows more slowly than
capital); under no reallocation, $\alpha = 1$. We apply $\alpha
\cdot g_k$ as the growth rate on per-unit labor income and $g_k$ as
the growth rate on per-unit capital income.

We apply $(g_k, \alpha)$ as growth rates, not as level targets. The
microsimulation's measured labor share differs from the NIPA share
Karger reports — the microsim aggregates exclude employer FICA,
undistributed C-corp profits, and imputed housing rent — but the
growth rate of each factor is comparable across data sources, so the
shock translates cleanly. We document the level gap and the implied
reasonableness checks in the validation section.

### Two share modes: reallocation vs. fixed share

We run every variant under two different factor-share settings to let
readers separate the productivity and reallocation channels:

- **Reallocate (R)** — use $\theta_1^K$ from Karger: capital grows
  faster than labor.
- **Fixed share (F)** — pin $\theta_1^K := \theta_0^K$ so the
  post-shock factor split equals the baseline. Same $g_y$, but
  $g_k = g_y$ and $\alpha = 1$: labor and capital both grow at the
  productivity rate.

The fixed-share option isolates the productivity increase from the
factor reallocation. Together, the two share modes let us decompose
"AI's effects on revenue and distribution" into "more taxable output"
and "the mix of who earns that output has shifted."

## Labor-side redistribution

The labor-side step computes a counterfactual labor income aggregate

$$
L_1 \;=\; L_0 \cdot \bigl(1 + \alpha \cdot g_k\bigr)
$$

and redistributes it across tax units. We offer three redistribution
rules — proportional (S0), compressive (S2), and expansive (S3).
None of the rules imply any extensive-margin adjustment; employment
is held constant. The omitted S1 is a planned future expansion involving 
occupation-level AI exposure. 

### Proportional (S0)

We hold constant the labor income for tax units with negative
baseline labor income and scale the labor income of all tax units
with positive baseline labor income by a single multiplier $\rho$ so
the aggregate hits $L_1$:

$$
\mathrm{YiL}_{1,i} \;=\;
\begin{cases}
\rho \cdot \mathrm{YiL}_i & \text{if } \mathrm{YiL}_i > 0, \\
\mathrm{YiL}_i           & \text{otherwise.}
\end{cases}
$$

By construction, $\sum_i w_i \cdot \mathrm{YiL}_{1,i} = L_1$. The
proportional scenario preserves the baseline distribution of
positive labor income.

### Compressive (S2) and Expansive (S3)

It is empirically uncertain whether the labor-side adjustment induced
by AI will compress (S2) or stretch (S3) the distribution of labor
income. We consider both and implement them via opposing
dispersion-shift specifications using a log-affine transformation
applied to tax units with positive labor income:

$$
\ln \mathrm{YiL}_{1,i} \;=\; \mu_1 + \sigma \cdot \bigl(\ln \mathrm{YiL}_i - \mu_0\bigr),
$$

where $\mu_0$ is the weighted log-mean of positive baseline labor
income, $\mu_1$ is solved so the positive-subset aggregate matches
$L_1$ after scaling, and $\sigma$ is the ratio of post- to pre-shock
standard deviation of $\ln \mathrm{YiL}$ on the positive subset. We
tie $\sigma$ to the productivity shock $g_y$ through

$$
\sigma_{S2} \;=\; 1 - k \cdot g_y \quad\text{(compressive)}, \qquad
\sigma_{S3} \;=\; 1 + k \cdot g_y \quad\text{(expansive)}.
$$

For now we assume $k = 1$ — a proportional mapping between growth and
dispersion. The code supports a scalar multiplier if a different
calibration becomes appropriate; sensitivity values of 0.5 (mute the
dispersion bite) and 2 (amplify it) are the documented ranges.

The compressive scenario captures the world in which AI's labor-side
cost falls hardest on the top end of the wage distribution
(substitution at the high end, e.g. cognitive professional work).
The expansive scenario captures the opposite — AI raises the
productivity (and pay) of high-skill labor while displacing or
stagnating mid- and bottom-wages. We do not take a view on which is
more likely.

## Capital-side allocation

This section details the allocation of the excess capital income
generated by the shock to individual tax units and — within tax
units — across streams of capital income. Given how we define the
baseline capital-income flow ($K_0$ as a function of taxable income
reported on tax returns), we are growing an already-realized stream
of taxable income. For this initial version of the model, we assume
that realization rates are held constant, meaning that capital income
is not realized (and therefore taxed) at a different rate due to the
productivity shock or the capital-labor shift.

### From the macro shock to dollars flowing to households

The aggregate capital income flow added by the shock is

$$
X \;=\; g_k \cdot K_0.
$$

Corporate income tax operates **upstream** of household realizations,
so the AI capital flow $X$ reaches tax units in full. We capture the 
corporate-tax effect of the shock as a macro bolt-on, anchored to CBO's 
baseline-year CIT level, rather than as a household-side wedge that 
mechanically subtracts from $X$.

A fraction $\kappa$ of $K_0$ flows through C-corporations in the
household-realized frame. To scale that household-realized slice up
to the pre-realization corporate tax base — and absorb the
statutory-vs-effective gap (avoidance, NOLs, credits, profit
shifting) — we calibrate a single factor $\eta$ against CBO's 
baseline-year CIT level $R^{\mathrm{CIT}}_{\mathrm{CBO}}$, calculated by 
multiplying the baseline (2030 in this case) CIT revenue to GDP ratio (from 
CBO's 2026 Budget and Economic Outlook) by baseline GDP:

$$
\eta \;=\; \frac{\tau_C^{\mathrm{stat}} \cdot K_0 \cdot \kappa}{ R^{\mathrm{CIT}}_{\mathrm{CBO}}}
$$

The AI CIT delta then scales linearly with $X$:

$$
\Delta R^{\mathrm{CIT}} \;=\; \frac{\tau_C^{\mathrm{stat}} \cdot \kappa \cdot X}{\eta}
\;\equiv\; \frac{X}{K_0} \cdot \Delta R^{\mathrm{CIT}}_{\mathrm{CBO}}.
$$

The compact form on the right is exact and intuitive: the AI CIT
delta equals the AI capital flow's share of baseline capital income
times the CBO baseline CIT level. With $\tau_C^{\mathrm{stat}} =
21\%$ (TCJA), $\kappa \approx 0.50$ (the narrow C-corp share of
capital income from NIPA 2024, with S-Corp profit stripped from the
numerator), and CBO's 2030 CIT anchor of $\sim \$486$B
(or CIT-to-GDP equaling $0.013$ times GDP),
$\eta$ falls out to roughly one in practice; its exact value is
reported on the `parameters` sheet of every run.

The corporate-tax delta enters aggregate revenue as a single number
layered onto the microsim revenue total; it is **not** attributed
back to individual households. As a result, every distributional
figure in our output reflects the full capital flow $X$ that reaches
households. This is a deliberate choice: we do not adopt a
per-household corporate-incidence assumption.
### Across-unit allocation

We distribute $X$ across tax units in
proportion to each unit's share of total household wealth:

$$
X_i \;=\; X \cdot \frac{A_i}{\sum_j w_j A_j},
$$

where $A_i$ is the sum of the unit's SCF-imputed wealth columns
(cash, equities, bonds, retirement balances, life insurance,
annuities, trusts, real-estate funds, primary and other home equity,
pass-through equity, and miscellaneous non-financial assets).
Allocating to total wealth assumes the AI shock raises returns
proportionally across asset classes; pinning to a narrower base
would push the distributional incidence further toward the top and is 
an area we plan to explore in the future. 

### Within-unit allocation across income types

The asset base contains both income-bearing and non-income-bearing
classes. Of the income-bearing classes, four matter for tax
purposes: equities (taxable), bonds, pass-through equity, and
retirement balances. Let $A_{i,{\mathrm{inc}}}$ be their sum for a
given tax unit. We allocate each unit's $X_i$ across the four
classes proportional to its baseline holdings within
$A_{i,{\mathrm{inc}}}$.

Units with zero income-bearing holdings route their entire $X_i$ to
retirement, preserving the aggregate identity $\sum_i w_i X_i =
X_{\mathrm{to\_units}}$. This fallback affects roughly 33% of tax
units in 2030 but only 6.7% of $X$; most of the affected mass sits
in tax units whose wealth is only in housing. If we redefine the
asset base to exclude housing, only 2.4% of $X$ is routed through
retirement via this fallback.

Each class then flows through to specific taxable-income types:

- **Taxable public-equity flow** splits between qualified dividends
  and gross long-term capital gains using a fixed share table (30%
  dividend / 70% gross LTCG).
- **Fixed-income flow** splits between taxable and tax-exempt
  interest at each unit's baseline ratio.
- **Pass-through equity flow** becomes pass-through ordinary income,
  further allocated across S-Corp and partnership active/passive
  sub-buckets using baseline positive capital holdings as weights.
- **Retirement flow** runs through the procedure described in the
  next section.

## Building the counterfactual and running the tax calculator

For every cell in the scenario grid — a tuple of (variant, share
mode, labor scenario, realization) — we construct a tax-unit file
with the same schema as the baseline and write it to a sibling
scenario folder under the pinned Tax-Data vintage. The construction
steps:

1. **Labor scaling.** Each unit's labor scaling factor
   $\rho_i = \mathrm{YiL}_{1,i} / \mathrm{YiL}_i$ is applied to
   every uniformly-labor PUF column: wages, overtime, tips,
   sole-prop, farm, partnership self-employment, plus the
   per-spouse splits.

2. **Pass-through reconstruction.** Each of the four pass-through
   sub-buckets (S-Corp active and passive, partnership active and
   passive) gets its labor side scaled by $\rho_i$ and its capital
   side augmented by the relevant share of the AI pass-through
   flow. The new net is decomposed back into positive and loss
   columns so the calculator sees a normal pass-through structure.

3. **Pure-capital flow add-ons.** Per-unit AI flows are added to
   the relevant PUF columns: qualified dividends, taxable and
   exempt interest, long-term capital gains, and the retirement
   procedure outputs from the previous section (gross pension
   distributions, taxable pension distributions, and taxable IRA
   distributions). For new long-term gains we populate cost basis
   and holding period using gain-weighted blends of the unit's
   baseline values, which the calculator needs to compute the
   inflation-adjusted basis.

4. **Schema restoration.** Every analytic column we constructed
   along the way ($\mathrm{YiL}, \mathrm{YiK}, \rho_i$, the $X_*$
   flows, capital-share blends) is dropped, so the output reads
   as a vanilla baseline file with shifted income totals.

Tax-Simulator then reads the counterfactual file as a sibling
Tax-Data ID and runs the full IIT + payroll calculation on it. The
shock parameters never enter the tax calculator — they reach it
only through the income totals on the counterfactual file.

### Decomposing the revenue change into labor and capital contributions

Two separate channels move revenue in a typical scenario: shifting
labor income and adding capital income. The interaction between
them is non-linear (because the tax schedule itself is non-linear:
brackets, phase-outs, AMT), so a clean "labor versus capital"
attribution requires care.

Each cell produces three Tax-Simulator runs:

- **Both** — labor and capital shocks both applied (the standard
  scenario).
- **Labor-only** — labor side shocked; capital flows held at
  baseline.
- **Capital-only** — capital side shocked; labor flows held at
  baseline.

We then decompose the total revenue change as

$$
\Delta T_{\mathrm{both}} \;=\; \Delta T_{\mathrm{labor}} + \Delta T_{\mathrm{capital}} + \mathrm{interaction},
$$

where

$$
\mathrm{interaction} \;=\; T_{\mathrm{both}} - T_{\mathrm{LO}} - T_{\mathrm{CO}} + T_{\mathrm{baseline}}.
$$

The interaction term captures non-linear bracket effects (the
combined shock can push a unit across an AMT or NIIT threshold that
neither side would have triggered alone). Payroll tax counts
mechanically as labor: the capital-only run leaves wages at
baseline, so its payroll delta is zero.

## Aggregation and the revenue-to-GDP anchor

The final step reads Tax-Simulator output and produces the
publishable aggregates: revenue deltas per instrument, pre-tax and
after-tax income deltas, Gini deltas on pre-tax and after-tax
income, decile shares, and top-1, top-0.1, top-0.01 shares. We also
layer the macro CIT delta onto the microsim revenue total to
produce the bottom-line revenue change.

Because the microsim does not include a baseline corporate income
tax level — Tax-Simulator handles only the individual-and-payroll
base — the model's internal revenue / GDP ratio understates the
published level by roughly 1.3 percentage points at 2030. For the
publishable revenue-to-GDP comparison we therefore anchor the
baseline to CBO's published 2030 ratio (17.7%; CBO publication
62105) and add the model's $\Delta R$ on top:

$$
R^{\mathrm{cbo}}_{\mathrm{scen}} \;=\; \bigl(\frac{R}{Y}\bigr)^{\mathrm{CBO}}_{\mathrm{base}} \cdot Y_{\mathrm{base}} + \Delta R.
$$

The publishable change in the revenue-to-GDP ratio is then

$$
\Delta\!\left(\frac{R}{Y}\right)^{\mathrm{cbo}} \;=\; \frac{R^{\mathrm{cbo}}_{\mathrm{scen}}}{Y_{\mathrm{base}} (1 + g_y)} - \bigl(\frac{R}{Y}\bigr)^{\mathrm{CBO}}_{\mathrm{base}} \;=\; \frac{\Delta R}{Y_{\mathrm{base}} (1 + g_y)} - \bigl(\frac{R}{Y}\bigr)^{\mathrm{CBO}}_{\mathrm{base}} \cdot \frac{g_y}{1 + g_y}.
$$

The second term is the **dilution drag**: even with no revenue
change, GDP growth alone would push revenue / GDP down by
$(R/Y)^{\mathrm{CBO}}_{\mathrm{base}} \cdot g_y / (1 + g_y)$.
Anchoring to CBO applies that drag to a realistic revenue base, so
the published response number is meaningful relative to the
forecast level. The maintained assumption is that revenue streams
the model omits (notably the baseline CIT level and any pieces of
"other" revenue not captured by Tax-Simulator) are unchanged in
the scenario except through channels already in $\Delta R$.

### Connecting to the macro model

The revenue-to-GDP delta is the natural handoff into the **Budget
Lab Small Macro Model (BLSMM)**, which carries baseline projections
for federal debt. For each scenario in
`revenue_to_gdp_<year>.csv` the optional step
`code/15_blsmm_debt_gdp.R`:

1. Applies the CBO-anchored revenue/GDP delta as a linear ramp on
   BLSMM's federal-revenue path ($\mathtt{rgfr\_star}$) from
   2026 through the baseline year, held at full level thereafter.
2. Solves for a constant per-year productivity bump (added to
   BLSMM's potential-output path $\mathtt{glqstar}$) such that the
   annualized 2025–baseline-year real GDP growth in BLSMM matches
   the Karger variant's $r^{\mathrm{AI}}$ target.
3. Reads off BLSMM's 2030 federal debt and debt/GDP and writes the
   results to `blsmm_debt_to_gdp_<year>.csv` plus a sheet on both
   xlsx bundles and per-share-mode bar plots.

BLSMM's CBO-style fiscal feedback (the model's $\psi_1$, $\psi_2$
elasticities) mechanically lowers outlays as potential output
rises. Under an AI shock policymakers may instead raise outlays
for displaced-worker support; the BLSMM number therefore reads
as a baseline-feedback estimate of debt/GDP rather than an
all-things-considered projection. The step requires a local clone
of the BLSMM repo (env var `BLSMM_DIR`); if absent, the rest of
the pipeline finishes normally without the BLSMM outputs.

## The scenario grid

The canonical run covers

$$
\{S,\, M,\, R\} \times \{R,\, F\} \times \{S0,\, S2,\, S3\} \;=\; 18 \text{ cells}.
$$

The 18-cell grid yields a layered comparison: across columns
(variants), across the factor-share axis (R versus F), and across
labor-side specifications. We use the comparison to bound any
single headline estimate.

## Validation

The model is built on several layers of upstream calibration; we
check each before relying on a result. The internal identities hold
by construction and are asserted in the test suite:

- The post-shock labor aggregate $L_1$ equals $L_0 (1 + \alpha g_k)$
  exactly for every implemented labor scenario.
- The per-unit capital flow $\sum_i w_i X_i$ equals
  $X_{\mathrm{to\_units}}$ exactly.
- The within-unit class allocations sum to each unit's $X_i$, with
  the residual routed to retirement when income-bearing assets are
  zero.
- The decomposition identity
  $\Delta T_{\mathrm{both}} = \Delta T_{\mathrm{labor}} + \Delta T_{\mathrm{capital}} + \mathrm{interaction}$
  holds at the dollar.
- The publishable revenue total equals the microsim revenue total
  plus the macro CIT delta.

The upstream-data benchmarks compare the baseline (no-AI)
aggregates to external published series:

- Microsim revenue totals are reconciled to CBO / Treasury IIT and
  CIT projections for the baseline year.
- $\sum_i w_i \mathrm{YiL}_i$ and $\sum_i w_i \mathrm{YiK}_i$
  reconcile to NIPA and SOI line items within the microsim's
  calibration tolerance.
- Per-asset aggregates match Distributional Financial Accounts
  totals post-match.
- Top-1% and top-10% shares of asset and capital-income holdings
  match published SCF and SOI tabulations.

A planned gap to flag: the microsim-implied capital share of factor
income is well below the NIPA share, because the microsim
aggregates exclude employer FICA, undistributed C-corp profits, and
imputed housing rent. This is why we apply the shock as a growth
rate on the microsim baseline rather than as a level target — a
level target on a non-NIPA base would over-correct.

**Per-scenario sanity checks.** Aggregate $Y_1 = L_1 + K_1$ equals
$Y_0 (1 + g_y)$ on the microsim baseline (a per-cell identity),
and the revenue change is bounded above in absolute terms by the
mechanical swap $|L_0 - L_1| \cdot |\bar\tau^L - \bar\tau^K|$,
where $\bar\tau$ are average effective rates by factor.

## Limitations

We flag four limitations explicitly so the headline numbers can be
read in context.

- **Behavioral response.** The primary specification is mechanical.
  Labor-supply and realization responses to the change in net-of-tax
  returns are not modeled.

- **Corporate microsim.** We capture corporate income tax through a
  single macro bolt-on rather than re-deriving corporate liability
  from per-firm data. Per-household corporate-incidence assumptions 
  are deliberately not applied; corporate tax operates upstream of household
  realizations, so the full $X$ reaches households, and the macro
  CIT delta is layered onto aggregate revenue separately. Any
  distributional spillover of CIT changes is absorbed into the
  aggregate delta, not the per-household totals.

- **General equilibrium.** Prices and wages outside the shock, and
  the asset stock $A_i$ itself, are held at baseline. We
  distribute the *flow* $X$; we do not revalue the stock. A full
  GE pass would allow asset prices to re-equilibrate as AI capital
  returns rise, which would push the distributional results further
  toward the top — current results should be read as a lower bound
  on that effect.

- **2015 PUF base.** The aging procedure assumes the current
  structure of the economy. A multi-percentage-point labor-share
  shift is a material deviation, and the validation checks above
  bound (but do not eliminate) the resulting uncertainty.

## Future work

The release described above is the first publishable cut. We flag
five directions where the model can be extended.

### Labor-side AI exposure

A natural fourth labor-incidence rule scales each unit's labor
income by an occupation's exposure to AI: $\mathrm{YiL}_{1,i} = (1 +
\beta \cdot e_i) \cdot \mathrm{YiL}_i$, where $e_i$ is an
occupation-level AI-exposure index, and $\beta$ is solved so the aggregate 
matches $L_1$. The mechanic is straightforward; the missing piece is an
occupation-level exposure imputation onto the tax-unit file. Once
that imputation exists, the AI-exposure scenario slots into the
labor-scenario axis alongside the existing proportional /
compressive / expansive rules.

### Parameterizing the realization rate

The current release treats AI capital gains as recognized
immediately at accrual, because $K_0$ is built from the on-1040
realized base and re-applying a realization discount would
double-count. A natural extension is to begin with a definition of
$X$ that includes unrealized capital gains and apply an explicit
realization rate $r$ — the share of the annual gain stock realized
each year — as a separate parameter:

$$
X^{\mathrm{LTCG}}_{\mathrm{realized}} \;=\; r \cdot X^{\mathrm{LTCG}}_{\mathrm{gross}}.
$$

This requires (a) that $X$ capture unrealized as well as realized
gains (see the wealth-frame extension below) and (b) an estimate of
$r$ from the literature. Counter-anchors include CRS R41364 (which
reports a 20-year realization rate near 0.6). Further work would 
condition $r$ on individual or economy-level characteristics: the 
marginal tax rates a unit faces, the composition of its wealth and income, 
and the relative size of its capital versus labor base.


### Lifetime present value

The single-year flow treatment misses a longer-term dimension of
capital-gains taxation: gains can compound unrealized, get realized
at some hazard rate, or escape tax entirely via step-up at death. A
present-value formulation — unrealized pool compounding at $\rho$,
realized at hazard rate $r$, discounted at $\delta$, with a
step-up haircut $\varphi$ on the residual at horizon $T$ — captures
this. Tax-Simulator is an annual-flow object and cannot natively
consume a lifetime-PV input, so this extension requires either an
out-of-model aggregation step or a redesign of the Tax-Simulator
handoff.

### Wealth-frame redefinition of X

The two realization extensions above only have a clean economic
interpretation if $X$ is sized at the wealth level, before
realization decisions, rather than off the on-1040 realized base.
Migrating to a wealth-frame definition would require:

- Replacing the $K_0$ baseline with a wealth aggregate (e.g. SCF
  net worth or DFA household wealth), and re-deriving $X = g_k
  \cdot W_0$.
- Calibrating the realization rate $r$ as discussed above.
- For retirement income specifically, modeling not just $r$ but the
  share of realizations that are taxable. Most retirement wealth
  sits in tax-deferred vehicles (401(k), IRA, traditional
  pensions); the marginal AI dollar flowing into those accounts
  would not be taxed in-year. We propose disciplining the relevant
  rates with five national constants from published tabulations:
  the realization rate $r_R$; pension and IRA shares of gross
  retirement distributions ($s_P$, $s_I$); and taxable shares of
  each ($\tau_P$, $\tau_I$). IRS SOI Publication 1304, the SOI IRA
  Bulletin, and the Federal Reserve's Distributional Financial
  Accounts supply the constants. With these, the gross and taxable
  distributions can be derived as $s_P \cdot r_R \cdot W_0$ and
  $\tau_P \cdot s_P \cdot r_R \cdot W_0$, respectively (IRA
  components defined symmetrically).

### Behavioral response

The current specification is mechanical. Two behavioral channels
are worth modeling: labor-supply responses to the change in
net-of-tax returns (Elasticity of Taxable Income $\sim 0.25$ per
Saez-Slemrod-Giertz), and realization-rate responses to capital
gains tax exposure.

### General equilibrium

The current model holds prices, wages, and the asset stock $A_i$
at baseline and distributes the flow $X$ without revaluing the
stock. A full GE pass would let asset prices re-equilibrate as AI
capital returns rise, pushing the distributional results further
toward the top.

## References

- Karger, E., Bredemeier, C., et al. (2026). *AI and the Macroeconomy:
  Productivity, Income, and Distribution.* NBER working paper w35046.
- Smith, M., Yagan, D., Zidar, O., and Zwick, E. (2019). "Capitalists
  in the Twenty-First Century." *Quarterly Journal of Economics*
  134(4).
- Saez, E., and Zucman, G. (2020). "The Rise of Income and Wealth
  Inequality in America: Evidence from Distributional Macroeconomic
  Accounts." *Journal of Economic Perspectives* 34(4).
- Saez, E., Slemrod, J., and Giertz, S. (2012). "The Elasticity of
  Taxable Income with Respect to Marginal Tax Rates." *Journal of
  Economic Literature.*
- Piketty, T., Saez, E., and Zucman, G. (2018). "Distributional
  National Accounts."
- Eloundou, T., Manning, S., Mishkin, P., and Rock, D. (2023). "GPTs
  are GPTs: An Early Look at the Labor Market Impact Potential of
  Large Language Models."
- Felten, E., Raj, M., and Seamans, R. "How will Language Modelers
  like ChatGPT Affect Occupations and Industries?"
- Chodorow-Reich, G., et al. (2024). "The Effects of the 2017 Tax
  Cuts and Jobs Act on US Corporations."
- Congressional Budget Office (2025). *Budget and Economic Outlook*
  (publication 62105).
- Federal Reserve Board. *Distributional Financial Accounts.*
- The Budget Lab at Yale. *Tax Microsimulation at The Budget Lab.*
- The Budget Lab at Yale. *Estimating the Distributional Impact of
  Policy Reforms.*
