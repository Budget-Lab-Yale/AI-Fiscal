---
title: "Methodology (Version 2 draft plan): How potential AI futures interact with the current tax system"
subtitle: "Draft for internal review — not for circulation"
author: "John Iselin and Ryan Nunn, The Budget Lab at Yale"
date: "October 5, 2026"
---

*This is a draft plan for the second version of the model behind The
Budget Lab's report "How potential AI futures would play out in the
current tax system." It follows the structure of the published
Version 1 methodology so the two can be read side by side. Items marked
**[Open: D*n*]** are decisions still to be made; the numbers refer to
the project's decisions log (`docs/v2_decisions.md`). Items marked
**[Set]** were decided on October 5, 2026. Generated from
`docs/plans/v2_methodology_plan_source.md`; edit the Word file directly
once review begins.*

This document describes the planned methodology for Version 2 of The
Budget Lab's model of how AI-driven economic change interacts with the
federal tax system. As in Version 1, we combine projections of the
economic effects of AI from Karger et al. (2026) with the microdata that
powers our tax microsimulation model, and we estimate the mechanical
revenue and distributional effects of three interacting features of an
AI scenario: faster GDP growth, a shift in factor income from labor to
capital, and a change in the distribution of labor income.

What changes is where the shock enters. Version 1 grew the capital
income that already appears on tax returns, which meant that realization
rates, the mix of business forms, and the share of capital income held
by foreigners, nonprofits, and retirement accounts were all fixed at
their baseline values by construction. Version 2 applies the shock to
the national accounts instead, and then follows each new dollar of
income through the corporate tax, payout decisions, ownership, and
realization before it reaches a tax return. This lets us explain *why*
the tax system collects more from some kinds of growth than others,
rather than only how much it collects.

# What changes in Version 2

- **A ten-year window.** Version 1 reported a single year, 2030.
  Version 2 produces annual estimates over a ten-year budget window,
  built on the same economic baseline our other models use. **[Set]**
- **The shock is sized in the national accounts, not on tax returns.**
  The AI-driven increase in capital income is computed from national
  income and only then mapped to taxable income. This makes realization,
  retirement accounts, and foreign ownership explicit rather than
  implicit.
- **A corporate tax module replaces the single macro wedge.** We compute
  the corporate tax on the incremental C-corporation profit directly,
  on a tax base consistent with CBO's corporate projections.
- **Ownership is modeled before households are.** Every dollar of new
  capital income is assigned to an owner — US taxable households,
  retirement accounts, tax-exempt institutions, or foreign investors —
  before any of it is written onto a tax return.
- **Realized capital gains come from an explicit annual ledger.**
  Retained corporate earnings are no longer treated as capital gains
  realized in the same year; gains accrue, are realized over time, and
  some are never taxed because of the step-up in basis at death.
- **Revenue remains the headline.** We model non-revenue destinations
  (foreign, exempt, deferred) only as far as they determine what reaches
  a tax base.
- **The parameters that shape AI revenue are themselves an output.**
  Every run reports the assumptions that determine how much revenue AI
  generates — such as how much corporate profit is retained rather than
  paid out — with their values, sources, plausible ranges, and the
  revenue at stake across each range. **[Set: D14]**

# Data and baseline construction

## The baseline economic path

Version 2 takes its baseline from The Budget Lab's Macro-Projections
model, the same baseline that our tax microsimulation model and its
input data already use. **[Set: D6]** Macro-Projections translates CBO's
10-year economic projections, revenue projections, and long-term outlook
into annual series for GDP and its income-side components —
compensation, wages and salaries, proprietors' income, rental income,
net interest, dividends, and corporate profits — along with price
indexes, interest rates, and revenue by source (individual income,
payroll, corporate, and other taxes). Using it means the AI scenario,
the aged tax data, and the microsimulation's corporate tax baseline all
rest on one economic forecast by construction.

Before use, we will confirm the definition of the corporate profits
series (whether it includes the inventory valuation and capital
consumption adjustments), because the corporate tax base below depends
on it.

## AI in the CBO baseline

CBO's baseline already contains an assessment of AI's effect on growth,
which in its 2026 projections was roughly 10 basis points per year on
average. Our scenarios are therefore measured *relative to CBO's
baseline*, not relative to a world without AI. That is the right
comparison for a budget analysis, but it means part of any surveyed AI
effect may already be in the baseline. If CBO publishes enough detail —
for example, alternative scenarios with larger AI effects, or a
separate AI contribution to productivity and income shares — we will
back out CBO's AI component before layering ours on top, so that the
two are not added together. How far we can go depends on what CBO
discloses. **[Open: D6, data item 2.4]**

## The tax microsimulation file

All individual income and payroll tax computations use The Budget
Lab's tax microsimulation model, unchanged from Version 1. The base file
is the 2015 IRS Public Use File (PUF), supplemented with non-filer
imputations, aged through SSA population weights and the CBO economic
forecast, and matched to the Federal Reserve's Survey of Consumer
Finances (SCF) to impute asset holdings for every tax unit.

The ten-year window requires an aged tax-unit file for each year scored.
Because the tax calculator's fiscal-year adjustment uses the prior tax
year, each scored fiscal year also needs the adjacent earlier tax year.
We will confirm that the pinned data vintage carries every required year
before the first full run.

We keep Version 1's notation. A tax unit's income is $Y_{j,i}^{X}$,
where $X$ is the income type, $j \in \{0,1\}$ denotes before or after
the shock, and $i$ indexes tax units; aggregates drop the $i$ subscript.
Version 2 adds a year subscript $t$ where it matters, so that
$Y_{j,t}^{X}$ is aggregate income of type $X$ in year $t$. Each tax
unit carries a weight $w_{i,t}$.

## Per-unit labor and capital aggregates

As in Version 1, we group each tax unit's baseline income into labor
income $Y_{0,i}^{L}$ (wages, the labor portion of self-employment and
pass-through income) and capital income $Y_{0,i}^{K}$ (interest,
dividends, realized gains, rents, the capital portion of pass-through
income, and taxable retirement distributions). In Version 1 these totals
determined the *size* of the shock. In Version 2 they no longer do —
the size comes from the national accounts — but they still determine
*which tax units* receive labor income changes, and they are the basis
for distributional reporting.

## Splitting mixed income between labor and capital

Self-employment and pass-through income mixes pay for work with returns
on invested capital. Version 1 used the Saez and Zucman (2020) split for
pass-through income on the tax file. Version 2 also needs a split on the
national-accounts side, because proprietors' income must be divided
between labor and capital before the shock is applied. Three
conventions are currently in use across our models: an even split of
proprietors' income in the national-accounts calibration, the Saez and
Zucman rule in this model's tax file, and an 80 percent labor share in
the microsimulation model's distributional tables. Version 2 uses a
single parameter $\varphi$, the aggregate capital share of mixed income,
on both sides. We compute it from the tax file: applying Version 1's
Saez and Zucman rule to every tax unit (with sole-proprietor and farm
income counted as labor, as before) and taking the weighted aggregate
gives

$$\varphi = \frac{\sum_i w_i \left(Y_{0,i}^{K,PT} + Y_{0,i}^{K,Pass}\right)}{\sum_i w_i \left(Y_{0,i}^{PT} + Y_{0,i}^{Pass} + Y_{0,i}^{SP}\right)},$$

where $Y^{SP}$ is sole-proprietor and farm income. We then use this
$\varphi$ to divide proprietors' and pass-through income in the national
accounts. Income classified as capital upstream is therefore the same
income classified as capital on the tax file. **[Set: D3]** The
microsimulation model's 80 percent labor convention remains only inside
its corporate-incidence calculation (see Distributional analysis),
where it is part of The Budget Lab's standard assumption.

# Macro shock parameterization

## Scenario inputs

We continue to use three intensity variants from Karger et al. (2026) —
Slow, Moderate, and Rapid (S, M, R) — and take both the GDP growth rate
and the labor share from the survey's pooled responses across all
respondent groups. **[Set: D1]**^[Version 1's published methodology
describes these as estimates for the economist subsample. The labor
shares we used (55.0, 53.8, and 51.3 percent) are in fact the pooled
values. Version 2 adopts the pooled column deliberately and corrects the
description. We will confirm that the GDP growth rates are drawn from
the same column.] Table 1 reports the inputs and the 2030 values they
imply.

| | Slow | Moderate | Rapid |
|--------------------------------------------|-----------:|-----------:|-----------:|
| Annualized real GDP growth, 2025–2030 ($r_{ai}$) | 2.0% | 2.6% | 3.3% |
| Labor share in 2030 ($\theta_{1}^{L}$) | 55.0% | 53.8% | 51.3% |
| GDP above CBO baseline in 2030 ($g_{Y}$) | ≈ 0.6% | ≈ 3.6% | ≈ 7.2% |

: Table 1. Scenario inputs (values for 2030 carried over from Version 1; to be recomputed on the Macro-Projections baseline path).

The survey asks about the labor share of the **nonfarm business
sector**, not of the whole economy. Version 2 therefore applies the
labor share change within that sector and treats the rest of the
economy (government, households and nonprofits, and owner-occupied
housing) separately, as described below. **[Open: D1]**

## Extending the shock beyond 2030

Karger et al. (2026) forecast the economy through 2030, while our
budget window runs ten years. Between 2025 and 2030 we build annual
paths by compounding the scenario growth rate and moving the labor
share linearly from its 2025 value to its 2030 value:

$$g_{Y,t} = \frac{(1+r_{ai})^{t-2025}}{G_{CBO,t}} - 1, \qquad \theta_{1,t}^{L} = \theta_{0}^{L} + \frac{t-2025}{5}\left(\theta_{1}^{L} - \theta_{0}^{L}\right), \qquad 2025 < t \le 2030,$$

where $G_{CBO,t}$ is cumulative baseline growth from 2025 to year $t$.
After 2030 the survey is silent. Our proposed reference case holds the
2030 gap constant — GDP stays the same percentage above baseline and the
labor share stays at its 2030 value — so AI raises the *level* of
output permanently but does not keep raising its growth rate. A
continued-growth path (excess growth persisting at the 2025–2030 rate)
would be a sensitivity. **[Open: D13]**

## From GDP and the labor share to factor income

Version 1 converted the GDP and labor-share inputs into growth rates
for labor and capital income using shares that summed to one. In the
national accounts they do not: labor and capital income together fall
short of national income, and the remainder includes taxes on
production and imports, business transfer payments, and the surplus of
government enterprises. Version 2 therefore starts from an accounting
identity that holds every year, before and after the shock:

$$Y_{j,t} = L_{j,t} + K_{j,t} + Q_{j,t},$$

where $L$ is labor income, $K$ is capital income, and $Q$ collects the
named components that are neither. Each component of $Q$ follows an
explicit rule in the scenario (for example, taxes on production rise
with output). **[Open: D3]**

Within the nonfarm business sector (NFB), the survey's labor share
determines how the change in output divides between labor and
everything else:

$$\Delta L_{t}^{NFB} = \theta_{1,t}^{L}\, Y_{1,t}^{NFB} - \theta_{0,t}^{L}\, Y_{0,t}^{NFB}, \qquad \Delta K_{t}^{NFB} = \Delta Y_{t}^{NFB} - \Delta L_{t}^{NFB} - \Delta Q_{t}^{NFB}.$$

In the reference case, the AI-driven increase in output lands in the
nonfarm business sector in proportion to its baseline share of GDP,
other sectors keep their baseline factor shares, and owner-occupied
housing is not shocked. Rental income from the market rental sector
and net interest are held on their baseline paths in the reference
case and shocked only in sensitivities. **[Open: D2]** An alternative,
economy-wide mapping will be reported as a sensitivity.

Labor income in the national accounts is compensation, which includes
employer contributions for social insurance, pensions, and health
insurance. We convert the change in compensation into a change in
taxable wages using baseline ratios of wages to compensation.

## Two share modes: reallocation versus fixed share

We keep Version 1's two share modes. *Reallocate* (R) uses the Karger
labor share; *fixed share* (F) holds the labor share at its baseline
value so that labor and capital income both grow with output. Comparing
the two isolates the revenue effect of the shift from labor to capital
from the effect of faster growth.

# Labor-side redistribution

The labor side is unchanged in kind from Version 1. We compute the
post-shock aggregate of labor income in each year and redistribute it
across tax units using one of three rules: proportional (S0),
compressive (S2), or expansive (S3). The proportional rule scales all
positive labor income by a common factor $\rho_t$; the compressive and
expansive rules apply the log-affine transformation

$$Y_{1,i,t}^{L} = \exp\!\left(\mu_{1,t} + \lambda_t \left(\ln Y_{0,i,t}^{L} - \mu_{0,t}\right)\right)$$

to tax units with positive labor income, with $\mu_{1,t}$ solved so the
aggregate matches its target. Payroll taxes are computed worker by
worker, so the Social Security wage cap applies to each earner
separately.

Two changes are planned. First, in Version 1 the dispersion parameter
$\lambda$ was tied to the size of the GDP shock ($\lambda = 1 \pm k\,
g_Y$). Version 2 loosens that link so we can also run a pure inequality
scenario with no change in GDP. Second, tax units with zero or negative
labor income get explicit treatment rather than being held fixed by
default.

Job loss, occupation-level AI exposure, and unemployment insurance
remain outside Version 2. **[Open: D8]** The labor income target can be
reached through many combinations of job loss, wage changes, hours, and
reemployment, and the aggregate alone cannot tell them apart; we
prefer to add these channels once the capital side is complete.

# Capital-side transmission

This section replaces Version 1's capital-side allocation. Figure 1
shows the full path from the AI shock to federal revenue and the
distribution of income.

![Figure 1. How the AI shock reaches federal tax revenue and household income in Version 2. Blue boxes are new in Version 2; cream boxes are outputs; dashed boxes are optional.](fig3_v2_transmission.png){width=5.4in}

## Capital income by legal form

The increase in business capital income is divided among
C-corporations, S-corporations, and partnerships and sole
proprietorships, starting from their shares of baseline capital income:

$$\Delta K_{t}^{bus} = \Delta\Pi_{C,t} + \Delta\Pi_{S,t} + \Delta\Pi_{P,t}.$$

In the 2024 national accounts, C-corporations earn about 63 percent of
business capital income (about half of capital income broadly defined,
including rent and interest). Because AI-related income may be concentrated
in large corporations, we will also report a scenario in which a larger
share of the increase is earned by C-corporations, holding the total
fixed.

## The corporate income tax

Version 1 calculated the change in corporate income tax as the change
in capital income times the ratio of CBO's baseline corporate tax to
baseline capital income. Version 2 computes it directly on the
incremental C-corporation profit:

$$\Delta R_{t}^{CIT} = \tau_{t}^{m} \cdot \Delta\Pi_{C,t}.$$

The marginal rate $\tau^{m}$ is built in two steps. First, we calibrate
a baseline bridge from economic profits to corporate tax receipts,
following the structure of CBO's corporate tax projections: profits
measured consistently with the tax data, less foreign-source and
loss-firm adjustments, less depreciation and other deductions, times
the statutory rate, less credits, converted from tax-year liabilities
to fiscal-year receipts. Second, we specify how an *additional* dollar
of AI-driven profit moves through that bridge — in particular whether
it is mostly a normal return on new investment (heavily sheltered by
full expensing, which is now permanent for eligible equipment) or a rent on
existing or scarce assets (closer to fully taxed). The reference case
uses the baseline bridge; the two cases above bracket it. **[Open: D4]**

The corporate tax is added to revenue once, here. The microsimulation
model's own corporate tax baseline is carried unchanged.

## Dividends and retained earnings

After-tax C-corporation profits are either paid out or retained:

$$D_{t} = p \cdot \Pi_{C,t}^{AT}, \qquad RE_{t} = (1-p)\cdot \Pi_{C,t}^{AT}, \qquad \Pi_{C,t}^{AT} = \Delta\Pi_{C,t} - \Delta R_{t}^{CIT}.$$

The payout ratio $p$ is measured on a matched group of corporations —
their dividends divided by their own after-tax profits. **[Open: D7]**
Retained earnings are profits kept inside the firm, not capital gains;
whether and when they become taxable gains is handled by the asset
ledger described below. Share buybacks are not modeled separately in
Version 2.

## Who owns the income: owners and tax wrappers

Not every dollar of corporate or business income belongs to a US
household that will pay tax on it. Before allocating income to tax
units, we assign each dollar of dividends, retained earnings, and
pass-through income to an owner category $o$: US taxable households,
traditional defined-contribution plans and IRAs, Roth accounts,
defined-benefit pensions, tax-exempt institutions, and foreign
investors. Shares $\omega_{e,o,g}$ vary by entity type $e$ and by the
income group $g$ of household owners: **[Set: D9]**

$$F_{o,g,t} = \sum_{e} \omega_{e,o,g}\left(D_{e,t} + RE_{e,t} + \Pi_{e,t}^{PT}\right), \qquad \sum_{o,g} \omega_{e,o,g} = 1.$$

Income to foreign and tax-exempt owners does not reach individual tax
returns. Consistent with our focus on revenue, we track these flows in
aggregate only — enough to show how much of the new income escapes the
individual tax base, without estimating those owners' incomes in
detail. The shares come from the Federal Reserve's Financial Accounts,
the SCF, and IRS retirement account statistics. Holdings through mutual
funds and other intermediaries are attributed to the ultimate owner.

## Retained earnings, asset values, and realized gains

Version 1 assumed that the new capital income was realized at the same
rate as baseline capital income. In Version 2, capital gains come from
an annual ledger kept separately for each owner group. Let $U_t$ be
the stock of unrealized gains, $A_t$ new accrued gains, $G_t$ realized
gains, and $E_t$ gains that escape tax through the step-up in basis at
death:

$$U_{t+1} = U_{t} + A_{t} - G_{t} - E_{t}.$$

Realizations follow a schedule calibrated to observed realizations over
many years, and step-up is applied using mortality rates by age. The
same rules run in the baseline and the scenario, and we report the
difference. Because gains are not part of national income, they sit
outside the accounting identity above.

The accrual $A_t$ depends on how retained earnings and expected future
profits translate into higher share prices. The model supports two
rules. **[Set: D10]**

*Rule A (default): accumulation.* Share values rise one-for-one with the
retained earnings attributed to each owner group:

$$A_{o,t} = RE_{o,t}.$$

Gains build gradually as profits are retained, and there is no
revaluation when AI's effects are first anticipated.

*Rule B (option): capitalization.* Markets value the expected stream of
additional after-tax profits as soon as it is anticipated. The value of
owner group $o$'s claim on the AI-driven profits is

$$V_{o,t} = \frac{\omega_{o}\,\Pi_{C,t+1}^{AT}}{r - g_{t}}, \qquad A_{o,t} = V_{o,t} - V_{o,t-1}, \qquad r > g_t,$$

where the discount rate $r$ is specified by the user and the growth
rate $g_t$ is the growth of incremental after-tax profits on the
model's own path (after 2030, the baseline growth rate, since the AI
gap is held constant). Under Rule B, value rises sharply in the year AI
is first anticipated, and retained earnings are *not* accrued a second
time — the capitalized value already includes them. Dividends are paid
under both rules. The year of anticipation is a separate input, set to
the first scenario year by default.

Because realizations are drawn from the stock of unrealized gains,
Rule B produces larger realized gains early in the window. We report
Rule B as a sensitivity. One caution applies to it: current share
prices, which underlie CBO's projections of capital gains, may already
reflect expectations about AI, so part of any Rule B revaluation could
already be in the baseline.

## Retirement accounts

Income earned inside traditional retirement accounts is taxed only when
withdrawn. Version 2 tracks the additional balances in these accounts
and pays them out according to age-specific withdrawal rates:

$$B_{a,t+1} = (B_{a,t} + F_{a,t})(1 + r_t) - W_{a,t}, \qquad W_{a,t} = s_{a}\, B_{a,t},$$

where $a$ indexes age groups and $s_a$ is the withdrawal rate. Roth
withdrawals are untaxed. Defined-benefit pension formulas are held
fixed over the window, so higher returns improve plan funding rather
than retirees' benefits. Only the taxable withdrawals are allocated to
tax units. **[Open: D11]** Over a ten-year window this matters more
than it did for a single year: balances build up, and withdrawals
increase toward the end of the window.

## Pass-through, rental, and interest income

Pass-through income is taxed to owners each year whether or not it is
distributed, so the incremental profits of S-corporations and
partnerships flow to their US taxable owners in the year they are
earned. The tax calculator applies self-employment tax and the
qualified business income deduction. Rental and interest income stay
on their baseline paths in the reference case.

# Building the counterfactual and running the tax calculator

## Reconciling aggregate flows to the tax file

National-accounts income and income reported on tax returns differ for
well-understood reasons. We bridge them in a fixed order:
(1) definitions and coverage, such as removing imputed income that
never appears on a return; (2) ownership, handled above; (3) timing and
realization, handled above; and (4) a final adjustment for any
remaining measurement gap between the two sources, by income type.
**[Open: D5]** The last step covers only what the first three do not
explain, which avoids removing the same income twice. Baseline
reconciliation uses CBO's projections of income reported on tax
returns, which our tax data already incorporate.

## Allocation to tax units

Each type of taxable flow is allocated to tax units in proportion to
their holdings of the relevant asset, within the income groups used for
ownership: dividends and realized gains by equity holdings,
pass-through income by pass-through holdings, and retirement
withdrawals by retirement balances. Within a tax unit, income is
written to the matching tax-return lines. The counterfactual file
then goes to the tax calculator exactly as in Version 1.

## Decomposing the revenue change

We keep Version 1's decomposition into labor-only, capital-only, and
interaction effects. We add a second decomposition that explains the
difference between Version 1 and Version 2 by mechanism: the change in
the size of the capital base, the corporate tax, ownership, realization
timing, retirement accounts, and allocation, applied in a fixed order
with the remaining interaction shown.

# Aggregation, distribution, and the revenue-to-GDP anchor

## Federal revenue by instrument

For each year we report the change in individual income tax, payroll
tax, and corporate income tax revenue:

$$\Delta R_{t} = \Delta R_{t}^{CIT} + \Delta R_{t}^{IIT} + \Delta R_{t}^{PAY}.$$

Refundable tax credit outlays are shown separately from receipts. We
report annual and ten-year totals.

## Distributional analysis

Our main distributional measure is cash income, ranked by baseline
income. **[Set: D12]** It captures what households can spend: wages,
dividends, interest, pass-through income, realized gains, and
retirement withdrawals. For corporate taxes we apply The Budget Lab's
standard incidence assumption, in which a share of a change in
corporate tax is borne by workers — phasing in from zero to 20 percent
over ten years — and the rest by owners of capital. **[Set: D12]**
Because the corporate tax already reduces the after-tax profits that
reach owners in our model, the incidence adjustment only moves the
labor share of the burden from owners to workers; it does not subtract
the tax a second time. A supplementary measure that also counts
retained earnings and gains accruing inside retirement accounts will
be reported as an appendix table.

## Connecting to the macro model

As in Version 1, we use the Budget Lab Small Macro Model (BLSMM) to
translate each scenario's revenue changes into changes in federal debt
as a share of GDP, now over the full window. As in Version 1, we build
the GDP path ourselves from the Karger et al. (2026) growth rates and
pass BLSMM a productivity adjustment that reproduces it. **[Set]**

BLSMM also publishes its own AI scenarios built on the Karger et al.
(2026) forecasts. A later version could integrate the two models, taking
the GDP, price, and interest-rate paths from BLSMM's scenarios so that
both describe the same economy year by year. We do not do so in
Version 2 because BLSMM's scenarios separate productivity and labor
force effects in ways that do not map directly onto our Slow, Moderate,
and Rapid variants.

We correct one point of exposition from Version 1. With $Z = R/Y$ and
$g_Y$ the GDP deviation, the change in the revenue-to-GDP ratio is

$$\Delta Z_{t} = \frac{\Delta R_{t}}{Y_{0,t}(1+g_{Y,t})} - Z_{0,t}\,\frac{g_{Y,t}}{1+g_{Y,t}}.$$

Higher GDP alone lowers the ratio, so the second term enters with a
negative sign. Version 1's code used this formula; the sign was printed
incorrectly in one equation of the published document.

# Parameters that shape revenue from AI

How much revenue AI generates depends on a set of parameters — several
of them uncertain and some of them, like how much profit corporations
retain, almost invisible in a model built on tax returns alone. Making
them explicit is one of the main purposes of Version 2. **[Set: D14]**
Every run therefore produces a parameter register: for each parameter,
its value, source, plausible range, and the change in 2030 and ten-year
revenue when it moves across that range with all others held at their
reference values. The published results rank the parameters by the
revenue at stake. Table 2 lists the initial set.

| Parameter | Where it enters | Why it matters for revenue |
|------------------------------|--------------------|------------------------------------------------|
| Share of the GDP increase in the nonfarm business sector | Production accounts | How much of the new output is labor versus capital income |
| Capital share of mixed income ($\varphi$) | Production accounts | Moves income between the more heavily and more lightly taxed bases |
| Rules for non-factor income ($Q$) | Production accounts | Income that reaches no individual tax base |
| Coverage of rental and interest income | Production accounts | Size of the capital income increase |
| C-corporation share of new profits | Legal form | Corporate tax versus pass-through taxation |
| Marginal corporate tax rate ($\tau^m$) | Corporate tax | Tax collected on each dollar of new profit |
| Payout ratio ($p$) | Dividends and retained earnings | Dividends are taxed now; retained earnings are taxed later as gains, or never |
| Valuation rule and discount rate ($r$) | Asset ledger | Size and timing of accrued gains |
| Realization schedule | Asset ledger | When gains reach tax returns |
| Step-up in basis at death | Asset ledger | Gains that are never taxed |
| Ownership shares ($\omega$) | Ownership | Share of income held by foreign, tax-exempt, and retirement owners |
| Retirement withdrawal rates | Retirement accounts | When income in tax-deferred accounts is taxed |
| Final reconciliation adjustment | Reconciliation | Measurement gap between national accounts and tax data |
| Labor income dispersion ($\lambda$) | Labor side | Progressivity of the income tax and the payroll tax cap |
| Path after 2030 | Scenario inputs | Revenue in years six through ten |
| CBO's embedded AI assumption | Baseline | How much of the AI effect is already in the baseline |

: Table 2. Parameters recorded in the register (initial list).

The register also organizes the sensitivity analysis: rather than
choosing sensitivities by hand, we generate them from each parameter's
documented range, and report a small number of coherent combined cases
alongside.

# Validation

We will check the model in four ways:

- **Accounting.** Every identity holds in every year: the production
  identity, the corporate cash flows, the ownership shares, and the
  asset and retirement ledgers. A zero shock produces zero changes, and
  every dollar of new income ends up in a named place.
- **Implementation.** Results do not depend on the order of records,
  scenario runs do not alter the baseline, and individual tax features
  (qualified dividends, self-employment tax, the net investment income
  tax, the qualified business income deduction, payroll caps) respond
  as intended in simple test cases.
- **Economic.** Baseline levels match external totals for the same
  year and concept; scenario changes are explained by their mechanism.
- **Comparison with Version 1.** We reproduce Version 1 on its original
  data and explain the difference by mechanism. Matching the Version 1
  result is not a goal in itself.

# Future work

Several extensions remain outside Version 2:

- **Job loss and AI exposure by occupation.** Version 2 keeps the
  intensive-margin labor rules. Adding displacement, reemployment, and
  occupation-level exposure, together with unemployment insurance, is
  the natural next step.
- **Spending responses.** We do not model changes in federal spending
  other than outlays that run through the tax code.
- **Macroeconomic feedback.** GDP, investment, and interest rates are
  taken as given rather than responding to the shock and to fiscal
  policy.
- **Behavioral responses.** Labor supply and realization behavior do not
  respond to changes in tax rates.
- **International detail.** Foreign ownership is modeled in aggregate;
  profit shifting and the taxation of multinational income are not.
- **Buybacks and portfolio choice.** Payout through share repurchases
  and changes in household portfolios are left for later work.
- **Integration with BLSMM.** Taking GDP, price, and interest-rate paths
  from BLSMM's AI scenarios, so that a single scenario definition drives
  both models.

# Open decisions

| Decision | Status | Question |
|----------|----------------|------------------------------------------------------|
| D1 | Partly set | Respondent group set (pooled); sector-to-economy mapping open |
| D2 | Open | Which components of capital income receive the shock |
| D3 | Partly set | $\varphi$ derived from the tax file and used upstream; rules for $Q$ open |
| D4 | Open | How an additional dollar of AI profit moves through the corporate tax base |
| D5 | Open | Final measurement adjustment between national accounts and tax data |
| D6 | Partly set | Baseline set (Macro-Projections); removal of CBO's AI component open |
| D7 | Open | Payout ratio and the matched group of corporations |
| D8 | Proposed | Defer job loss and occupation exposure to a later version |
| D9 | Partly set | Ownership shares by entity and income group; calibration open |
| D10 | Partly set | Rule A default, Rule B available; realization schedule open |
| D11 | Open | Withdrawal rates and treatment of defined-benefit plans |
| D12 | Set | Cash income leads; Budget Lab incidence assumptions |
| D13 | Partly set | Ten-year window set; path after 2030 open |
| D14 | Set | Parameter register as an output; contents to grow with the model |
| — | Set | Own GDP paths; BLSMM integration flagged for later |

# References

Congressional Budget Office (2026). *The Budget and Economic Outlook:
2026 to 2036.* Publication 62105.

Congressional Budget Office. *How CBO Projects Corporate Income Tax
Revenues.* Publication 59436.

Karger, E., et al. (2026). "Forecasting the Economic Effects of AI."
NBER Working Paper 35046.

Saez, E., and G. Zucman (2020). "The Rise of Income and Wealth
Inequality in America: Evidence from Distributional Macroeconomic
Accounts." *Journal of Economic Perspectives* 34(4): 3–26.

The Budget Lab at Yale (2026). "How potential AI futures would play out
in the current tax system."

The Budget Lab at Yale (2026). "Methodology: How potential AI futures
interact with the current tax system."

The Budget Lab at Yale. "Budget Lab Small Macro Model (BLSMM)."
