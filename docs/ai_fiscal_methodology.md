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
on-1040 realized base, so the baseline realization rate is already
embedded in the construction. Under this assumption, AI capital
income is realized in-year at the same rate as the baseline stock.
A natural extension is to relax this assumption and parameterize the
realization rate separately, or to redefine $X$ at the wealth level
so the shock can act on unrealized accruals. We treat both as future
work; see `docs/realization_and_wealth_extensions.md`.

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
on firm capital. SYZ apply $W^\star$ as a firm-level threshold; we
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
\mathrm{cum\_base} \;=\; (1 + g^{\mathrm{CBO}}_{2026}) \cdot (1 + g^{\mathrm{CBO}}_{2027+})^{H-1}
$$

be cumulative CBO growth from 2025 to 2030. Then

$$
g_y \;=\; \frac{(1 + r^{\mathrm{AI}})^H}{\mathrm{cum\_base}} - 1
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
rules — proportional (S0), compressive (S2), and expansive (S3) — and
briefly discuss a potential extension based on occupation-level AI
exposure. None of the rules imply any extensive-margin adjustment;
employment is held constant.

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

### AI exposure (future extension)

A future extension is to scale labor income by an occupation's
exposure to AI. The infrastructure supports an exposure-based rule
of the form $\mathrm{YiL}_{1,i} = (1 + \beta \cdot e_i) \cdot \mathrm{YiL}_i$,
where $e_i$ is an occupation-level AI-exposure index (Eloundou et
al. 2023 or Felten-Raj-Seamans), and $\beta$ is solved so the
aggregate matches $L_1$. We have not yet imputed an occupation
index onto the tax-unit file.

## Capital-side allocation

This section details the allocation of the excess capital income
generated by the shock to individual tax units and — within tax
units — across streams of capital income. Given how we define the
baseline capital-income flow ($K_0$ as a function of taxable income
reported on tax returns), we are growing an already-realized stream
of taxable income. For this initial version of the model, we assume
that realization rates are held constant, meaning that capital income
is not realized (and therefore taxed) at a different rate due to the
productivity shock or the capital-labor shift. Future work will
consider parameterizations of the shock that impact either overall
wealth or total income (realized and unrealized); see
`docs/realization_and_wealth_extensions.md` for the planned design.

### From the macro shock to dollars flowing to households

The aggregate capital income flow added by the shock is

$$
X \;=\; g_k \cdot K_0.
$$

Corporate income tax operates **upstream** of household realizations,
so the AI capital flow $X$ reaches tax units in full
($X_{\mathrm{to\_units}} = X$). We capture the corporate-tax effect
of the shock as a macro bolt-on, anchored to CBO's baseline-year CIT
level, rather than as a household-side wedge that mechanically
subtracts from $X$.

A fraction $\kappa$ of $K_0$ flows through C-corporations in the
household-realized frame. To scale that household-realized slice up
to the pre-realization corporate tax base — and absorb the
statutory-vs-effective gap (avoidance, NOLs, credits, profit
shifting) — we calibrate a single dimensionless factor $\eta$ at
runtime against CBO's baseline-year CIT level
$\Delta R^{\mathrm{CIT}}_{\mathrm{CBO}}$:

$$
\eta \;=\; \frac{\tau_C^{\mathrm{stat}} \cdot K_0 \cdot \kappa}{\Delta R^{\mathrm{CIT}}_{\mathrm{CBO}}},
\qquad
\Delta R^{\mathrm{CIT}}_{\mathrm{CBO}} \;=\; \mathtt{cit\_to\_gdp\_baseline\_year} \cdot \mathtt{gdp\_baseline\_year\_B}.
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
($\mathtt{cit\_to\_gdp\_baseline\_year} = 0.013$ times nominal GDP),
$\eta$ falls out to roughly one in practice; its exact value is
reported on the `parameters` sheet of every run.

The corporate-tax delta enters aggregate revenue as a single number
layered onto the microsim revenue total; it is **not** attributed
back to individual households. As a result, every distributional
figure in our output reflects the full capital flow $X$ that reaches
households. This is a deliberate choice: we do not adopt a
per-household corporate-incidence assumption (such as the JCT 75/25
capital/labor split).

### Across-unit allocation

We distribute $X_{\mathrm{to\_units}} = X$ across tax units in
proportion to each unit's share of a chosen base:

$$
X_i \;=\; X_{\mathrm{to\_units}} \cdot \frac{A_i^{\mathrm{base}}}{\sum_j w_j A_j^{\mathrm{base}}}.
$$

The default base is total household wealth, which assumes that all
wealth is equally impacted by the AI shock. Three alternative bases
are available as sensitivities: non-housing wealth (drops primary
and other home equity); a narrower "productive capital" base
(pass-through ownership and equities only, the slice most likely to
be exposed to AI-driven returns); and taxable capital income (per
unit, $\mathrm{YiK}_i - \mathrm{exempt\_int}_i$). The taxable-capital-income
base is the capital mirror of the proportional (S0) labor rule —
a single multiplier $z$ scales every unit's taxable capital income
so that the weighted aggregate hits $X_{\mathrm{to\_units}}$. Unlike
the labor side, negative bases scale along with positives, so units
with negative taxable capital income absorb a (negative) share of
$X$.

### Within-unit allocation across income types

The asset base contains both income-bearing and non-income-bearing
classes. Of the income-bearing classes, four matter for tax
purposes: equities (taxable), bonds, pass-through equity, and
retirement balances. Let $A_i^{\mathrm{inc}}$ be their sum for a
given tax unit. We allocate each unit's $X_i$ across the four
classes proportional to its baseline holdings within
$A_i^{\mathrm{inc}}$.

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

## Retirement flow treatment

Retirement assets sit awkwardly in this setting because while
retirement wealth is held by many households across the age
distribution, retirement *income* is generally realized by older
households alone. Allocating the AI retirement increment in
proportion to retirement wealth alone would distribute the flow to
working-age households who are not yet drawing from their accounts —
producing distributional numbers that misrepresent how AI
retirement income would actually land. We therefore apply the
following procedure.

**First**, compute the realization pool at the population level:

$$
F \;=\; \sum_i w_i \cdot X_{i,r}^{\mathrm{alloc}},
$$

where $X_{i,r}^{\mathrm{alloc}}$ is unit $i$'s retirement slice from
the within-unit allocation.

**Second**, define the receiving set of tax units as those with
positive taxable retirement income on their baseline return:

$$
\mathcal R \;=\; \{ i : \mathrm{txbl\_pens\_dist}_i + \mathrm{txbl\_ira\_dist}_i > 0 \}.
$$

**Third**, distribute $F$ across $\mathcal R$ in proportion to SCF
retirement wealth $W_i^{\mathrm{ret}}$:

$$
F_i \;=\; \mathbf{1}_{i \in \mathcal R} \cdot
         \frac{F \cdot W_i^{\mathrm{ret}}}
              {\sum_{j \in \mathcal R} w_j \cdot W_j^{\mathrm{ret}}},
\qquad \sum_i w_i F_i \;=\; F.
$$

Conditioning the receiving set on taxable retirement income while
weighting by wealth forces the allocation of retirement income to
concentrate in older tax units — the ones actually drawing from
their accounts.

**Fourth**, $F_i$ is split at the tax-unit level between taxable
pension distributions and taxable IRA distributions. We pull from
2022 IRS statistics to construct fixed ratios for this allocation:
67.6% to pension distributions and 32.4% to IRA distributions. The
two PUF columns (`txbl_pens_dist`, `txbl_ira_dist`) are updated
accordingly; `gross_pens_dist` is incremented by the same amount as
the taxable component, since under the constant-realization
assumption no new non-taxable rollover flow is generated.

### A diagnostic: average tax rate on baseline retirement income

Independently of the AI counterfactual, readers often want a sense
of the level of taxation on retirement income today. We compute this
by running a stacked zero-out counterfactual: a separate
Tax-Simulator scenario that zeros each unit's `txbl_ira_dist`,
`gross_pens_dist`, and `txbl_pens_dist`, then comparing tax
liability with and without retirement income. The decile-level
result on the 2030 baseline, non-dependent filers ($n = 201{,}166$):

### Table 2. Baseline retirement ATR by decile, 2030

| decile | $Y_R$ ($B) | $\Delta$ IIT ($B) | implied ATR |
|------:|-----------:|------------------:|------------:|
| 1     |       55.8 |               5.0 |        9.0% |
| 2     |       25.6 |               0.9 |        3.4% |
| 3     |       50.6 |               2.4 |        4.8% |
| 4     |       79.9 |               6.3 |        7.8% |
| 5     |      134.6 |              13.4 |        9.9% |
| 6     |      151.1 |              15.7 |       10.4% |
| 7     |      256.5 |              31.2 |       12.2% |
| 8     |      499.1 |              67.8 |       13.6% |
| 9     |      632.5 |              90.6 |       14.3% |
| 10    |     1296.9 |             134.3 |       10.4% |

Population total ATR is 11.6%. The decile-10 dip relative to decile 9
is structural rather than a measurement artifact: at the very top,
retirement is a smaller share of total income and non-retirement
income already sits in the top bracket, so zeroing retirement
income removes ordinary-rate mass with limited bracket interaction.
Decile-9 units more often fall out of the top bracket when their
retirement income is removed, exposing more dollars to the
difference.

## Realization timing

As noted at the start of this document, the definition of $X$
implies that we are growing realized (and generally taxable) income
that appears on tax returns. This embeds a specific assumption about
realization: all gains generated by the shock are recognized
immediately at accrual. We label this assumption V1 and adopt it as
the model's default. V1 holds as long as $X$ already captures the
appropriate rate of realizations, which is the case by construction
when $K_0$ is the on-1040 base.

There are alternative ways to conceptualize this parameter. If we
begin with a definition of $X$ that includes unrealized capital
gains, then we can separately parameterize a realization rate $r$
— the fraction of the annual gain stock realized each year — and
apply it. Such a parameterization would also let $r$ vary with a
tax unit's changing share of labor and capital income: realization
rates might increase if capital becomes a larger share of a tax
unit's income (the unit consumes out of capital rather than labor),
or decrease if future returns to capital are higher (trading off
one unit of current consumption for $1 \cdot r$ units of future
consumption). Growth might also accrue heterogeneously across types
of wealth, which would require modeling at the wealth level prior
to realization decisions. Eventually we would like to use this
model to understand the revenue and distributional effects of
proposed changes to the system of capital taxation; some of those
changes affect unrealized gains as well as those realized on a tax
return, and that requires modeling how AI shocks impact wealth and
capital income separately from the forms that appear on a tax
return.

### V1 — mechanical (current default)

All gains realized in-year:

$$
X^{\mathrm{LTCG}}_{V1} \;=\; X^{\mathrm{LTCG}}_{\mathrm{gross}}.
$$

V1 treats AI capital gains as if they were recognized immediately
at accrual, which holds as long as $X$ already embeds the baseline
realization rate. This is the parallel argument to the
constant-realization choice for retirement: $K_0$ is sized off the
on-1040 realized base, so re-applying a realization discount inside
the model would double-count.

### V2 — realization-adjusted (future work)

In-year flow scaled by an explicit realization rate $r$:

$$
X^{\mathrm{LTCG}}_{V2} \;=\; r \cdot X^{\mathrm{LTCG}}_{\mathrm{gross}}.
$$

V2 requires that (a) $X$ captures unrealized as well as realized
gains, and (b) we have an estimate of $r$ from the literature.
Further work would condition $r$ on individual- or
economy-level characteristics (the tax rates a unit faces, levels of
capital and labor income, the composition of wealth). The
calibration target and the menu of anchors are documented in
`docs/realization_and_wealth_extensions.md`.

### V3 — lifetime present value (future work)

An alternative that moves away from the single-year treatment and
captures longer-term effects is V3. The unrealized pool compounds
at rate $\rho$, is realized at hazard rate $r$, discounted at
$\delta$, and whatever remains at horizon $T$ is subjected to a
step-up haircut $\varphi$ (the fraction of unrealized gains
escaping tax at death). This captures several longitudinal
dimensions of capital-gains taxation but is not consumed by
Tax-Simulator, which is an annual-flow object. The proposed
treatment is documented in
`docs/realization_and_wealth_extensions.md`.

### Implications for retirement income

The retirement-income procedure described above assumes that the
flow of taxable retirement income embedded in $X$ captures not just
the realization rate of capital assets held in retirement accounts
but also the share of those realizations that are taxable. Most
retirement wealth is held in tax-deferred vehicles (401(k), IRA,
traditional pensions); if we were to move to a realization-adjusted
model, the marginal AI dollar flowing into those accounts would not
be taxed in-year. The future-work extensions therefore require
modeling not just a realization rate $r$ but also the flow of
assets into taxable and non-taxable income — and the relevant
calibration constants (gross and taxable pension distributions,
gross IRA distributions and FMVs, DB and DC pension entitlements)
are documented in the extension plan referenced above.

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

Under the optional decomposition mode, each cell produces three
Tax-Simulator runs:

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
R^{\mathrm{cbo}}_{\mathrm{scen}} \;=\; \bigl(R/Y\bigr)^{\mathrm{CBO}}_{\mathrm{base}} \cdot Y_{\mathrm{base}} + \Delta R.
$$

The publishable change in the revenue-to-GDP ratio is then

$$
\Delta\!\left(\frac{R}{Y}\right)^{\mathrm{cbo}} \;=\; \frac{R^{\mathrm{cbo}}_{\mathrm{scen}}}{Y_{\mathrm{base}} (1 + g_y)} - \bigl(R/Y\bigr)^{\mathrm{CBO}}_{\mathrm{base}} \;=\; \frac{\Delta R}{Y_{\mathrm{base}} (1 + g_y)} - \bigl(R/Y\bigr)^{\mathrm{CBO}}_{\mathrm{base}} \cdot \frac{g_y}{1 + g_y}.
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

## The scenario grid

The v0.1.0 publishable grid covers

$$
\{S,\, M,\, R\} \times \{R,\, F\} \times \{S0,\, S2,\, S3\} \times \{V1\} \;=\; 18 \text{ cells}.
$$

The 18-cell grid yields a layered comparison: across columns
(variants), across the factor-share axis (R versus F), and across
labor-side specifications. We use the comparison to bound any
single headline estimate. S1 (AI-exposure) is excluded because it
requires an occupation-level exposure imputation onto the tax-unit
file that is not yet built; V2 and V3 realization variants are
treated as future work and described in
`docs/realization_and_wealth_extensions.md`.

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

## Limitations and forward work

We flag five limitations explicitly so the headline numbers can be
read in context.

- **Behavioral response.** The primary specification is mechanical.
  We could consider shocks to labor supply (Elasticity of Taxable
  Income) and to realization stemming from AI.

- **Corporate microsim.** We capture corporate income tax through a
  single macro bolt-on rather than re-deriving corporate liability
  from per-firm data. Per-household corporate-incidence assumptions
  (such as the JCT 75/25 capital/labor split) are deliberately not
  applied; corporate tax operates upstream of household
  realizations, so the full $X$ reaches households, and the macro
  CIT delta is layered onto aggregate revenue separately. This is
  conservative for distributional figures: any distributional
  spillover of CIT changes is absorbed into the aggregate delta,
  not the per-household totals.

- **General equilibrium.** Prices and wages outside the shock, and
  the asset stock $A_i$ itself, are held at baseline. We
  distribute the *flow* $X$; we do not revalue the stock. A full
  GE pass would allow asset prices to re-equilibrate as AI capital
  returns rise, which would push the distributional results further
  toward the top — current results should be read as a lower bound
  on that effect.

- **AI exposure not yet implemented.** The AI-exposure labor shock
  needs an occupation-level exposure imputation onto the tax-unit
  file. The mechanic is implemented; the input is not.

- **2015 PUF base.** The aging procedure assumes the current
  structure of the economy. A multi-percentage-point labor-share
  shift is a material deviation, and the validation checks above
  bound (but do not eliminate) the resulting uncertainty.

**Methodology evolution.** v0.1.0 ships under the constant-realization
assumption: $X$ acts on the realized-income flow $K_0$, and the
retirement procedure inherits the baseline realization rate by
construction. The natural next step is to parameterize the
realization rate explicitly and / or redefine $X$ at the wealth
level so the shock can act on unrealized accruals. The detailed
plan — anchors for the realization rate, target architecture for
the wealth-frame allocator, retirement-income calibration constants,
and a phased implementation — lives in
`docs/realization_and_wealth_extensions.md`.

## References

- Karger, E., Bredemeier, C., et al. (2026). *AI and the Macroeconomy:
  Productivity, Income, and Distribution.* NBER working paper w35046.
- Saez, E., and Zucman, G. (2020). "The Rise of Income and Wealth
  Inequality in America: Evidence from Distributional Macroeconomic
  Accounts." *Journal of Economic Perspectives* 34(4).
- Eloundou, T., Manning, S., Mishkin, P., and Rock, D. (2023). "GPTs
  are GPTs: An Early Look at the Labor Market Impact Potential of
  Large Language Models."
- Felten, E., Raj, M., and Seamans, R. "How will Language Modelers
  like ChatGPT Affect Occupations and Industries?"
- Hungerford, T. (March 2026 update). *The Federal Tax System and
  Capital Gains.* Congressional Research Service R41364.
- Poterba, J. and Weisbenner, S. (2001). "The Distributional Burden
  of Taxing Estates and Unrealized Capital Gains at Death." In
  *Rethinking Estate and Gift Taxation.*
- Joint Committee on Taxation. *Methodology for Modeling Capital
  Gains Realizations* (JCX-33-21).
- Saez, E., Slemrod, J., and Giertz, S. (2012). "The Elasticity of
  Taxable Income with Respect to Marginal Tax Rates." *Journal of
  Economic Literature.*
- Piketty, T., Saez, E., and Zucman, G. (2018). "Distributional
  National Accounts."
- Chodorow-Reich, G., et al. (2024). "The Effects of the 2017 Tax
  Cuts and Jobs Act on US Corporations."
- Congressional Budget Office (2025). *Budget and Economic Outlook*
  (publication 62105).
- Federal Reserve Board. *Distributional Financial Accounts.*
- The Budget Lab at Yale. *Tax Microsimulation at The Budget Lab.*
- The Budget Lab at Yale. *Estimating the Distributional Impact of
  Policy Reforms.*
