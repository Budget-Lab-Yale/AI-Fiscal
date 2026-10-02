# AI Fiscal Version 2 review and research roadmap

September 23 2026

Evaluation of the September 21 methodology plan and the model underlying The Budget Lab report on AI and the current tax system

## Recommended direction

**Proceed with the upstream redesign, but revise the economic accounting before implementing the proposed cascade.** The plan identifies the right limitation of Version 1: the tax-return base fixes several important relationships that Version 2 should expose. Its strongest features are the year-indexed baseline, separation of production from household ownership, channel-level allocation, explicit reconciliation, and conservation tests. Those features are worth building.

The present design is not yet a sufficiently specified model of the transmission from aggregate AI shocks to federal taxes and income distribution. Three changes matter most. First, establish a consistent bridge from the GDP and labor-share inputs to economic income. Second, separate economic profits, asset revaluation, cash distributions, and taxable income. Third, identify which claims belong to US taxable households, retirement accounts, foreign owners, and other institutions before allocating income to tax units. A larger national-accounts base without these distinctions can make the estimates less reliable even as the model becomes more detailed.

For **one researcher working alone**, I recommend a **16-week planning envelope** for a bounded Version 2.0 release, followed by separately scoped extensions. The release should answer: given an annual path for aggregate output and its distribution across factors, what happens to federal individual income taxes, payroll taxes, corporate income taxes, and the distribution of household income under explicitly stated transmission assumptions? Keep the existing labor-distribution scenarios. Defer occupation imputation, endogenous employment, major spending responses, debt feedback, and tax-reform behavior.

The main research contribution should be a quantified explanation of **why the tax system captures different amounts of an otherwise identical aggregate gain**. Show the effects of factor shares, entity composition, ownership, tax preferences, and timing. Do not make the release depend on predicting the size of AI's aggregate effect or building a general-equilibrium model.

### What the evaluation establishes

This evaluation reads the supplied DOCX, the published report and methodology, the public repository at commit `fbea6d7fa803a1668d9c157853ba485bb49626ac`, and selected primary sources. It checks the proposed accounting and relevant implementation points. It does not run the restricted PUF–SCF production pipeline or reproduce published revenue estimates. Numerical examples below are diagnostic calculations, not revised fiscal estimates.

The [published report](https://budgetlab.yale.edu/research/how-potential-ai-futures-would-play-out-current-tax-system) estimates a maximum $216 billion increase in 2030 revenue in its rapid-growth scenarios and emphasizes the offset from a declining labor share. Version 2 should preserve that question while testing the transmission assumptions more directly. The [published methodology](https://budgetlab.yale.edu/research/methodology-how-potential-ai-futures-interact-current-tax-system) provides the comparison specification, not a target that the new model must reproduce after substantive assumptions change.

## Findings that should change the plan

### 1 Resolve the labor share definition and the source column

The plan correctly identifies the mismatch between the survey labor share and national-accounts compensation. That issue can now be narrowed substantially. Karger and coauthors ask about the **nonfarm business sector**, not economy-wide compensation divided by national income. Their GDP question covers the beginning of 2025 to the beginning of 2030. In the paper currently linked from the Budget Lab report, Table 19 gives economists' GDP medians of 2.0%, 2.6%, and 3.3%; Table 39 gives economists' labor-share medians of 55.0%, 54.0%, and 52.0%. The plan's 53.8% and 51.3% are in Table 39's pooled Total column. Archive and reconcile the exact source vintage before changing the published calibration. [Karger et al., Tables 19 and 39 and Appendix H.4](https://static1.squarespace.com/static/635693acf15a3e2a14a56a4a/t/69cbb9d509ada447b6d9013f/1774959061185/forecasting-the-economic-effects-of-ai.pdf)

This discrepancy can affect interpretation, not just rounding. Holding the existing five-year growth convention and 55.5% starting share fixed, the rapid scenario's 3.3% annual GDP growth implies output 7.17% above baseline. A 51.3% terminal labor share implies labor income 0.94% below baseline; a 52.0% share implies 0.41% above baseline. This is an algebraic diagnostic within the old mapping. A corrected sector bridge is still needed before using either result as a national labor-income estimate.

BLS's nonfarm business measure uses compensation, including an imputation for proprietors' labor, over sector output. The complement includes more than net profits available to shareholders. The sector also excludes important parts of the economy. The numerical similarity between 55.5% and the plan's economy-wide constructed ratio therefore does not validate the latter. [BLS measurement discussion](https://www.bls.gov/opub/mlr/2017/article/estimating-the-us-labor-share.htm)

**Revision:** Replace D1's search for a matching ratio with a short sector-to-economy bridge. Specify how much of the GDP shock falls in nonfarm business; apply the survey share change within that sector; account separately for other sectors, depreciation, and production taxes. If a reduced-form national mapping is retained, label it as an assumption and test an alternative mapping. Reconcile beginning-of-year survey dates with calendar-year tax files. Distinguish changes relative to today's share from changes relative to the projected baseline share.

### 2 Rebuild the national income identity before choosing the capital base

The proposed 13.1% residual is not entirely unexplained production taxes and transfers. Using the plan's own numbers, its capital base includes half of proprietors' income, but its labor comparison includes only employee compensation. The other half of proprietors' income is missing. Adding approximately $1,018 billion to labor reduces that residual from 13.07% to **8.91%** of national income. These calculations use the repository's frozen 2024 receipt, not a new national-accounts vintage. [Repository receipt](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/config/calibration/nipa_2024_z1_f3.csv)

There is a second bridge from GDP to national income: domestic versus national coverage, consumption of fixed capital, and the statistical discrepancy. There is a third bridge from compensation to taxable earnings: employer social-insurance contributions, pension contributions, health benefits, and other supplements. An identity that labels all of these differences a single residual can balance while assigning the wrong amounts to tax bases. [BEA accounting framework](https://www.bea.gov/resources/methodologies/nipa-handbook)

**Revision:** Build a complete baseline accounting table first. Keep mixed income split consistently between labor and capital in both macro and micro files. Give each nonfactor or excluded component a name and a scenario rule. Distinguish an actual statistical discrepancy from an economic component deliberately held fixed. Do not absorb an unexplained imbalance into taxable capital income.

D2 should consequently cease to be a choice between two convenient totals. Maintain the broad accounting universe and explicitly identify which components receive the AI shock. A business-focused shock can leave housing unshocked without deleting housing from the accounts. Narrowing the shock's coverage requires re-deriving the mapping from the aggregate target; it is not just a 21% reduction in the same experiment.

### 3 Separate current production income from asset gains

Retained earnings are a flow of corporate saving. Capital gains are changes in the value of claims. Expected future profits, discount rates, risk, new investment, and payouts can all affect market value. A permanent profit increase can be capitalized before the associated profits are earned. Conversely, accounting retention need not produce a dollar-for-dollar market-value increase. BEA distinguishes profits from current production from holding gains. [BEA corporate profits concepts](https://www.bea.gov/resources/methodologies/nipa-handbook/pdf/chapter-13.pdf)

This is the largest missing economic mechanism in the proposed cascade. Writing retained profits directly into a capital-gains pool is an assumption, not a conservation identity. Adding an announcement revaluation later could also count the same expected profits twice.

**Revision:** Use two linked ledgers. The production ledger follows compensation, operating profits, entity taxes, dividends, and retained income. The asset ledger follows claim values, basis, new saving or issuance, valuation changes, realizations, and deferred balances. Keep capital gains outside the GDP adding-up identity.

For the first release, use a deliberately simple annual rule relating profit news and retained income to equity revaluation, with its parameters and timing exposed. A zero-announcement-revaluation reference case is useful, provided it is labeled. A second case can capitalize a specified persistent after-tax cash-flow change. Neither case should be described as mechanically implied by GDP. Avoid a full asset-pricing model in the core release.

### 4 Repair the realization calibration and remove the 84 percent shortcut

The CRS figure requires a different interpretation from the plan's. CRS estimates a long-period ratio of realizations to eligible accruals over 1987–2023: 52.17% before an adjustment for noncompliance and 61.374% after reducing the accrual denominator by 15%. It excludes several tax-preferred asset categories. This is not a cohort estimate of the probability that a particular accrued gain is realized during its owner's lifetime, and it is not an annual hazard applied to the outstanding unrealized-gains stock. [CRS R48562, pages 1–2](https://www.congress.gov/crs_external_products/R/PDF/R48562/R48562.1.pdf)

The PUF-implied 0.16 and CBO-implied 0.24 also divide realized flows by estimated accrual flows. They do not become annual stock hazards merely because both observations have annual dates. Differences in asset coverage, gain concepts, and imputed accruals can explain their disagreement. Require exact sources and denominators for the asserted 0.20–0.35 literature range before treating it as a calibrated range.

The proposed factor `1 - (1-r) × phi = 0.84` does not supply an annual realization schedule. It treats part of the initially unrealized gain as eventually taxable, without modeling when or why. Generally, inherited property receives a basis equal to its value at death; an heir's later sale does not recover tax on the gain eliminated by that adjustment. New post-inheritance appreciation is a different gain. [IRS Publication 551](https://www.irs.gov/publications/p551)

The proposed dividend fraction `p / [p + (1-p) × r]` also needs a label. Under the plan's simplified assumptions, it is the dividend share of income that becomes realized, not the share of the original after-tax profit flow. Preserve the realized total and the unrealized remainder separately; normalizing the two taxable destinations to sum to one must not force the entire gross flow onto tax returns.

**Revision:** Define the annual tax object before comparing numerical fits. Use either an explicit unrealized-gains stock and realization hazard, or a reduced-form distributed lag from accruals to realizations. Calibrate that mechanism against matched asset universes and multi-year realizations. Model death-related basis adjustment once, or use an all-in realization coefficient that already incorporates it. Keep lifetime present-value analysis outside annual revenue tables. Do not choose the concept after observing which revenue result seems plausible.

### 5 Add ownership and tax wrappers before allocating to the PUF

Separating production entities from holding vehicles is a major improvement in the plan. But the household allocation step still needs an explicit boundary: **not all income generated by the modeled corporate sector belongs to US taxable households**. Claims can belong to foreign investors, nonprofits, traditional retirement plans, Roth accounts, insurers, or other corporations. Intermediaries require consolidation to prevent counting an equity interest directly and again through a fund. The Financial Accounts distinguish foreign holdings, domestic holdings, and fund shares. [Federal Reserve instrument definitions](https://www.federalreserve.gov/releases/z1/preview/html/table_desc_instruments.htm)

**Revision:** Introduce an entity-by-owner-by-wrapper matrix. Every production dollar must reach a named owner category, but only the appropriate share should reach US tax-return lines. Preserve foreign and exempt flows as reported destinations rather than renormalizing them onto PUF households. Carry foreign-source income of US residents separately from US-source income of foreign owners; domestic GDP and the US tax base have different boundaries. For the first release, use documented aggregate ownership shares, a simplified foreign-income bridge, and sensitivity cases rather than a multinational firm microsimulation.

The conservation test should read “sum across all owner destinations equals the distributable flow,” followed by a separate test that the PUF allocation equals the eligible US household flow. A test that allocates the entire upstream increment to households would certify the wrong result.

### 6 Use a corporate receipts bridge with compatible denominators

The plan's 14.7% rate is derived from the repository's $491.7 billion federal accrual receipts divided by approximately $3,343 billion of C-corporation profits **without** the inventory valuation and capital consumption adjustments. Its proposed $3,007 billion C-corporation base uses profits **with** those adjustments. Applying 14.71% to the latter produces approximately $442 billion, not $492 billion. Merely dividing the same receipt by the smaller denominator would give 16.35%; that is a consistency check, not a recommended AI marginal rate. [Rate receipt](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/config/calibration/cit_avoidance_calculation.csv)

CBO's corporate methodology explicitly bridges production profits to the tax base, including accounting adjustments, pass-through exclusions, profitable versus loss-making firms, and deductions. It also distinguishes tax liabilities from fiscal-year collections. Adopt that structure at a coarser level. [CBO corporate tax methodology](https://www.cbo.gov/publication/59436)

Acemoglu, Manera, and Restrepo's effective tax rates measure wedges in investment returns and incorporate more than federal corporate receipts. They are not directly applicable lower bounds for tax collected on an extra dollar of AI profit. Distinguish the normal return on newly installed capital from rents on existing or scarce assets. [Acemoglu, Manera, and Restrepo, Section II](https://www.brookings.edu/wp-content/uploads/2020/12/Acemoglu-FINAL-WEB.pdf)

The plan's attribution question can be resolved: CBO itself reports a 25% decline in corporate receipts in the **first 11 months of FY2026**, and attributes part of the weakness to larger investment deductions under the 2025 reconciliation act. This is not a completed fiscal-year observation and does not identify an AI-specific marginal tax rate. [CBO August 2026 review, page 3](https://www.cbo.gov/system/files/2026-09/61984-MBR.pdf)

**Revision:** Use a baseline-calibrated corporate tax-base bridge and separate incremental assumptions for profit composition, investment deductions, losses, and credits. A reduced-form receipt response is acceptable initially if labeled and stress-tested. Do not call the full statutory-to-effective gap “avoidance.” Preserve the distinction between federal CIT and all entity taxes when calculating income available to owners. IRS guidance confirms permanent 100% additional first-year depreciation for eligible property acquired after January 19, 2025; continuing investment means aggregate deductions need not simply disappear after the build-out. [IRS guidance](https://www.irs.gov/newsroom/treasury-irs-issue-guidance-on-the-additional-first-year-depreciation-deduction-amended-as-part-of-the-one-big-beautiful-bill)

### 7 Redesign the rental interest and pass through mappings

**Rental income:** The $1,072 billion national-accounts component includes imputed income from owner-occupied housing, which is not a taxable Schedule E rental receipt. Separate owner-occupied housing, market rental activity, and other covered rental income before deciding what a writer should receive. A real-estate asset column does not by itself establish taxability. [BEA rental income methods](https://www.bea.gov/resources/methodologies/nipa-handbook/pdf/chapter-12.pdf)

**Interest:** Net interest and miscellaneous payments in national income are not the same object as household monetary interest receipts. They include offsetting flows and imputations. Existing fixed-rate claims also do not automatically receive a higher coupon when AI raises profits. For the core reference case, a fixed financing-cost path can be explicit; broader interest-income responses belong in a sensitivity with a corresponding debtor-side treatment. [BEA net interest methods](https://www.bea.gov/resources/methodologies/nipa-handbook/pdf/chapter-14.pdf)

**Pass-throughs:** Taxable distributive income is not contingent on a cash payout. It can differ from economic income through deductions, losses, and basis rules. “Realization equals one” is a reasonable timing shorthand only after constructing the relevant taxable distributive share. Keep the labor/capital classification separate from the legal tax treatment, including self-employment tax and QBI. Earnings already taxed through a pass-through also affect basis; they must not be taxed a second time as a fresh retained-earnings gain. [IRS S-corporation basis guidance](https://www.irs.gov/businesses/small-businesses-self-employed/s-corporation-stock-and-debt-basis) and [Publication 541](https://www.irs.gov/publications/p541)

**Revision:** Replace a generic per-channel realization switch with channel-specific transformations. Include mutually exclusive entity categories, loss-making cases, and an explicit fallback when a household has no qualifying asset or income base. Never route an unexplained allocation residual to retirement solely to make totals balance.

### 8 Do not assume the retirement cascade survives economically unchanged

Traditional retirement accounts generally defer tax until distributions, whereas qualified Roth distributions are tax-free. Defined-benefit pensions promise benefits under a formula; a higher portfolio return need not immediately increase retirees' checks. [IRS retirement definitions](https://www.irs.gov/retirement-plans/plan-participant-employee/retirement-plans-definitions) and [defined-benefit guidance](https://www.irs.gov/retirement-plans/defined-benefit-plan)

The existing R1 routine pools a flow already denominated as taxable retirement income and sends it to recipients. That is an implementation component, not an identified response of pension distributions to upstream capital income. A baseline distribution-to-balance ratio is an average withdrawal measure, not automatically the marginal response to one extra dollar of current returns.

**Revision:** Track incremental traditional DC/IRA balances with an age-sensitive withdrawal rule or a documented aggregate approximation. Distinguish Roth holdings. Hold near-term DB benefit formulas fixed in the reference case and report improved funding or sponsor gains separately. A full retirement lifecycle model is unnecessary; a correctly labeled aggregate stock-and-withdrawal approximation is sufficient. Report deferred economic gains even when current tax receipts are zero.

### 9 Reconcile once and separate coverage from behavior

The plan's benchmark-versus-inherit decision is useful but too coarse. A historical PUF/NIPA ratio can already embody foreign ownership, exempt holders, realization timing, reporting, and definitional differences. If the upstream cascade models those mechanisms explicitly and then multiplies by the original ratio, it can remove the same income twice.

**Revision:** Factor the bridge into concept and coverage adjustments, ownership and wrapper allocation, timing and realization, and a final measurement calibration. The final coefficient should address only the unexplained remainder. Ratios should use comparable universes and years; some are not fractions bounded by one because their numerators and denominators measure different objects. Use additive adjustments when a denominator is near zero or net income changes sign. BEA's personal-income-to-AGI comparison provides a starting taxonomy. [BEA Table 7.19 presentation](https://apps.bea.gov/scb/pdf/2006/09September/0906_New_NIPA.pdf)

CBO's use of historical relationships supports estimating income-specific bridges; it does not justify one undifferentiated coverage haircut. Its revenue evaluation explicitly recognizes deviations between national income components and tax bases. [CBO revenue projection evaluation](https://www.cbo.gov/publication/62707)

### 10 Specify distributional income and corporate incidence together

There are three different outputs: cash received, economic income earned, and tax burden. Retained corporate earnings can raise economic income without raising current cash; retirement withdrawals can include previously accumulated principal; realized gains can reflect earlier income or revaluation. A single expanded-income total should not sum all of these without adjustments.

Subtracting corporate tax from profits before allocation already reduces owners' receipts. Adding a separate corporate-tax burden deduction to those same receipts would count the tax twice. Conversely, assigning no incidence is insufficient for a table labeled comprehensive after-tax economic income. Treasury's incidence conventions are distributional assumptions, not evidence identifying the marginal incidence of an AI shock under unchanged tax law. [Treasury methodology](https://home.treasury.gov/system/files/131/TP-5.pdf)

**Revision:** Publish two clearly defined panels: disposable cash income, and an accrual-based economic-income measure that attributes retained income and deferred returns while excluding duplicated realizations. Report valuation changes separately. Use an owner-burden reference convention consistent with the cash-flow cascade; construct alternative labor/capital incidence allocations as a reconciled reporting overlay. Freeze the household ranking in baseline income for main comparisons. Add reranked results only as a supplement.

### 11 Treat displacement as a later conditional scenario

The labor section correctly identifies an aggregate constraint, but its framing is too restrictive. Job losses and a fixed aggregate labor-income target can coexist if surviving workers earn more, hours change, or jobs are created elsewhere. This is a conditional allocation of a supplied total; it need not be interpreted as a literal transfer from displaced workers. The problem is identification: the aggregate target alone cannot determine job loss, wage gains, hours, and reemployment.

**Revision:** Keep S0/S2/S3 in Version 2.0, with explicit targets and treatment of nonpositive incomes. Decouple their dispersion parameter from GDP growth enough to permit a pure inequality experiment at unchanged GDP. Later add a transparent displacement stress test before occupation imputation. Preserve workers within joint tax units, payroll caps by worker, spell duration, UI eligibility, and household composition. Deterministic weight splitting is useful, but evaluate taxes on the split records: tax of expected income is generally not expected tax.

Occupation exposure should remain a distinct research project. An exposure score is not a probability of displacement, and an imputed cell mean is not a measured occupation. It is lower priority than capital ownership and tax timing for the first release.

### 12 Update the engineering claims and validation standard

The current repository already has a guard against rolling the positional growth keys beyond their intended starting year, order-preserving update joins in the counterfactual writer, a centralized scenario-axis registry, and a CIT double-counting check. The older architecture sketch lists several of these as future work. Preserve and extend them rather than budgeting to implement them again. [Parameters](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/code/02_params.R), [writer](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/code/06_build_counterfactual.R), [registry](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/code/00_utils.R), and [aggregation](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/code/09_tables_figures.R)

The synthetic fixture cannot reproduce the report's economic results to the dollar: it intentionally uses fabricated records. It can support stable synthetic regressions and internal identities. Published-output regression requires the pinned restricted data, calculator version, local patches, policy baseline, and run environment. Keep both test classes, and allow intentional model changes to alter economic results through a documented change comparison. [Repository reproducibility guidance](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/README.md)

Calibration to CBO is not independent validation against CBO. A hard gate should apply to identities, schemas, missing data, impossible states, and mismatched source vintages. Economic benchmark deviations need predefined tolerances and explanations; not every historical ratio is an invariant under a novel AI shock. Retain diagnostic workbooks even when a publication gate fails.

## The model to build for the first release

### A conditional annual transmission model

Use a common baseline and scenario object with annual rows. For the initial publication, emphasize the 2030 endpoint and the annual transition from the chosen starting year. Carry the baseline through 2036 where available, but do not promise a full ten-year fiscal score until post-2030 shocks and annual microdata are specified. A five-year annual model is already a material improvement over converting one endpoint into an assumed revenue ramp.

The preferred input is an externally supplied real GDP path plus factor-share and distribution assumptions. If the user instead supplies TFP, a separate macro adapter must supply GDP, employment/hours, investment, and factor incomes under its own closure. Do not apply independent TFP and GDP multipliers to the same income base. Productivity and GDP are not interchangeable when employment and capital accumulation change.

Annual state calculations do not require pretending that independently aged tax files form an observed household panel. Carry deferred balances in stable age/owner/wrapper cells unless the data support consistent record-level transitions; allocate each year's taxable flow onto that year's microdata with explicit weights. Confirm this handoff early. If only a 2030 file is ready, use the aggregate annual ledger to generate its endpoint inputs and label interim tax estimates as provisional until annual files are validated.

Explicitly distinguish a scenario relative to CBO from an AI-versus-no-AI counterfactual. The CBO baseline can already include expected AI effects. Default to a common price path for a controlled real-growth experiment, and label that choice. Keep separate inputs for the GDP deflator, consumer-price indexing, and wage indexing; a price-path sensitivity should update relevant tax parameters consistently with current law.

### Module contracts

| Module | Required input | Output and responsibility |
|---|---|---|
| Baseline and shock | Dated macro paths, tax law, source definitions | Annual baseline/scenario levels with explicit units and sector coverage |
| Production accounts | GDP path, affected-sector shares, depreciation and mixed-income assumptions | Labor compensation, net capital components, named nonfactor items |
| Entity tax | Compatible economic profits, investment deductions, losses, credits | Federal CIT, other entity-tax treatment, after-tax income |
| Ownership and wrappers | Entity claims, resident and foreign ownership, intermediation | Flows to taxable US owners, deferred and exempt owners, foreign owners |
| Household income and asset state | Eligible flows, holdings, gain/basis state, withdrawal rules | Cash income, attributed accrual income, valuation changes, taxable lines |
| Tax calculation | Baseline and counterfactual records, policy-year parameters | IIT, worker-level payroll, refundable credits, household net resources |
| Reporting and checks | Module ledgers and calculator outputs | Tax totals, distribution, reconciliation, sensitivity and provenance |

Keep the interface small: scenario identifier, year, channel, source concept, destination, units, baseline amount, scenario amount, and delta. Household outputs additionally require a stable tax-unit ID, weight, and relevant worker IDs. Do not depend on row position. Aggregate state should be separate from mutable microdata so a sensitivity run cannot silently alter another scenario's baseline.

### Core accounting relationships

For each year, require a production identity of the form `Y = L + K + Q`, where all three components use the same domestic/national and gross/net convention. Here `Q` contains named components outside the chosen labor and capital definitions. Require the same identity for changes. Derive labor and capital growth from target levels in this system; do not reuse a survey complement as a net-profit share.

For each entity, after-tax economic income is allocated across dividends or other distributions and retained income. Buybacks require a separate financing/payout classification: the cash paid for shares is not all taxable gain, and net issuance or borrowing may finance payouts. A dividend parameter should measure dividends of a matched entity universe divided by that universe's after-tax profits. Personal dividends divided by all corporate profits can mix entities, foreign flows, and owner categories.

For a gains ledger, an illustrative annual recursion is `U_end = U_start + A - G - E`, where `U` is outstanding unrealized gain, `A` is new valuation accrual, `G` is gain recognized, and `E` is gain removed through basis adjustment or other specified exclusions. Define the ordering of accrual, sale, and death. Apply the same rules in baseline and counterfactual states and take differences; do not apply a nonnegative-stock constraint to a possibly negative scenario delta. A full implementation also needs a loss/basis convention.

For aggregate revenue, add federal CIT once to individual and payroll receipts. Report refundable credits' receipt and outlay components separately so “revenue” matches the chosen federal accounting convention. Carry residual federal receipts explicitly with a reference assumption and a sensitivity rather than silently describing modeled taxes as the entire tax system.

Where `g` is the nominal GDP deviation and `z0 = R0/Y0`, the change in the revenue share is `delta_z = (delta_R/Y0 - z0 × g)/(1 + g)`. The GDP-denominator term has a negative sign. The public methodology's displayed rearrangement contains a positive sign even though its accompanying explanation describes a decline. The inspected repository code computes the difference of ratios correctly, and its Markdown methodology uses the negative sign. Treat this as a public-document consistency correction, not evidence that the code's revenue-share results are wrong.

### A small example to use as a design test

Suppose an extra $100 of C-corporation economic profit incurs $20 of federal CIT, with other entity taxes held at zero for this illustration. Of the remaining $80, $40 is paid as dividends and $40 retained. Suppose taxable US owners hold 50% of the claims, traditional retirement accounts 30%, and foreign owners 20%. These are illustrative assumptions, not calibration recommendations.

| Destination | Dividend flow | Attributed retained income | Total after entity tax |
|---|---:|---:|---:|
| US taxable owners | $20 | $20 | $40 |
| Traditional retirement accounts | $12 | $12 | $24 |
| Foreign owners | $8 | $8 | $16 |
| All owners | $40 | $40 | $80 |

At an illustrative 15% household dividend rate, US taxable owners owe $3. If retirement withdrawals and gain realizations do not respond that year, modeled federal receipts rise by $23 before any foreign-owner withholding. Domestic owners still receive $64 of after-entity-tax economic income, of which $24 accrues inside retirement accounts. They have $61 after the additional household tax; foreign owners have $16, and federal tax is $23. Those destinations sum to $100.

This example exposes the role of each mechanism without conflating it with a GDP forecast. Additional taxable gains require a valuation and realization rule; they cannot be inferred from the $40 of retained income alone. A separate gain tax would reduce household net resources, while realization of already attributed retained income would not create a second increment of economic income. Use variants of this example as module tests, including full foreign ownership, full retirement ownership, and zero dividends.

### What belongs in Version 2 and what should wait

| Include in the first release | Reason |
|---|---|
| Explicit GDP-to-income and compensation-to-wages bridges | Establishes valid aggregate tax bases |
| Year-indexed baseline and current-law vintage | Makes timing and future updates reproducible |
| C-corporation and pass-through separation | Determines legal tax treatment |
| Resident, foreign, exempt and retirement ownership | Determines which gains enter US household taxation |
| Annual gains and retirement timing approximation | Prevents annual/lifetime and flow/stock confusion |
| Existing labor distributions and payroll detail | Preserves the central distributional question |
| Cash and economic-income distribution panels | Makes deferred gains visible without double counting |
| Focused structural sensitivities and restricted-data validation | Shows what conclusions depend on assumptions |

| Defer to a later release | Retain now to make extension possible |
|---|---|
| Occupation exposure and worker displacement | A labor-target interface and worker/tax-unit identifiers |
| UI and major spending responses | Separate transfer and fiscal-year output fields |
| Endogenous GDP, investment and interest-rate feedback | A macro adapter contract |
| Tax-reform behavioral scoring | Tax-base and realization parameters with clear concepts |
| Detailed multinational and corporate microsimulation | Aggregate foreign-income and tax-base bridges |
| Full lifecycle retirement and estate model | Age cells, wrapper categories, deferred balances |
| Endogenous buyback policy and portfolio choice | Separate payout, basis and financing categories |

Some deferred mechanisms must have a simplified core treatment. Deferring multinational modeling does not permit allocating all profits to US households; deferring a pension model does not permit distributing all retirement returns immediately. Simplify the mechanism while preserving the boundary.

## Research work that should precede and accompany coding

### Build six short research packets

Each packet should produce a two-to-four-page decision memo, a machine-readable receipt, and a small diagnostic table. The purpose is to choose and defend a mechanism, not collect citations without a modeling consequence.

| Packet | Main sources and data to assemble | Concrete decision |
|---|---|---|
| Accounting and shock definitions | Karger questionnaire and tables; BLS sector definitions; BEA Tables 1.7.5, 1.10, 1.12 and 1.13; dated CBO path | Affected sector, gross/net mapping, mixed-income split, baseline comparison |
| Entity tax base | BEA profits and tax-return reconciliation; CBO corporate methodology and supplements; SOI corporate/S-corporation aggregates; enacted tax provisions | Compatible denominator, marginal versus average response, investment/loss treatment |
| Ownership and wrappers | Financial Accounts stocks and sector descriptions; SCF; tax-data imputations; IRA and pension aggregates | Domestic taxable share, foreign share, intermediary look-through, wrapper allocation |
| Gains and distributions | CRS R48562 and underlying definitions; CBO capital-gains projections; SOI gains; equity revaluations, dividends and net issuance | Accrual universe, realization timing, death/basis convention, dividend definition |
| Household tax lines | BEA personal-income/AGI reconciliation; SOI income categories; PUF schema; Tax-Simulator writer/calculator | Channel crosswalk, income concept, qualified-dividend handling, loss treatment |
| Validation and presentation | Published outputs; restricted-vintage aggregates; historical series; baseline and scenario tables | Tolerances, comparison cases, income ranking, publication gates |

Use a source receipt with release date, observation year, table and line/series identifier, units, coverage, transformation, and file hash. Distinguish a sourced statistic, a parameter estimated from data, and a scenario assumption. Maintain a confidence/status column, but do not assign empirical confidence intervals to judgmental scenarios.

The Financial Accounts changed table numbering in June 2026. The old F.224/L.224 corporate-equity tables, for example, have new identifiers. Archive historical tables when reproducing the old calibration and store persistent series IDs for updates. [Federal Reserve table descriptions](https://www.federalreserve.gov/releases/z1/preview/html/table_desc_instruments.htm)

### Research priorities within the packets

Spend the first effort on definitions and denominator compatibility. Then estimate the fraction of marginal income reaching each tax base. Only after that refine household distribution within a tax base. An exquisitely estimated distribution cannot repair a wrong aggregate base.

Use multi-year matched series for payout and realization diagnostics. A single year's profits, gains, or withdrawals can be unusually high, low, or negative. Report how coefficients change with the sample window, whether ratios use sums or averages, and how foreign and retirement holdings are removed. Do not infer a marginal response from an average ratio without an explicit maintained assumption.

For AI-specific entity composition, distinguish gains earned by AI suppliers, gains earned by adopting firms, and losses to displaced incumbent assets. A “software is concentrated in C-corporations” argument does not identify the legal form of all marginal AI income. Start with broad versus C-corporation/rent-concentrated scenarios and document their economic interpretation. Negative gains to some groups can coexist with a positive aggregate shock; any later treatment must preserve that possibility.

Use the normal-return versus rent distinction to organize corporate sensitivities. It is useful for current-law transmission even though estimating optimal AI tax policy is outside the release. Korinek and Lockwood provide a broader tax-design framework; they do not supply a ready-made empirical calibration for this model. [Public Finance in the Age of AI](https://www.nber.org/books-and-chapters/economics-transformative-ai/public-finance-age-ai-primer)

## A feasible roadmap for one researcher

### Planning assumptions

Budget **16 calendar weeks with roughly 12 focused research weeks and four weeks of equivalent capacity for data delays, debugging, reruns, and documentation**. This assumes usable access to the existing production tax infrastructure and substantial protected time. At half-time, plan on approximately twice the elapsed calendar time. This is a planning estimate, not a guarantee.

The original capital phases add to about 11–14 weeks as written. Adding a 4–6 week labor lane cannot be treated as free parallel capacity for one researcher, especially when real-vintage runs have historically needed retries. The recommended schedule removes that lane from the first release and integrates documentation and validation throughout.

| Weeks | Main work | Reviewable result and exit gate |
|---|---|---|
| 1–2 | Freeze Version 1; audit source definitions and data availability; write release contract | Source manifest; baseline/legacy output snapshot; corrected accounting table; decisions on sector, timing and outputs |
| 3–4 | Implement annual baseline and production bridge; separate compensation, wages and mixed income | Baseline and one simple shock reconcile before tax; zero-shock case works; annual tax-file availability confirmed |
| 5–6 | Build entity tax and owner/wrapper allocation with conservative timing placeholders | Every flow reaches a named destination; first restricted-data end-to-end run for one year and one scenario |
| 7–9 | Implement dividend, gains and retirement timing; complete tax-line writers and coverage calibration | Second restricted-data run; annual gains/withdrawals reconcile; all major household lines benchmarked |
| 10–11 | Integrate existing labor cases, income concepts and tax incidence reporting | Cash and economic-income panels; worker payroll checks; full reference scenarios run |
| 12–13 | Test sensitivities, historical diagnostics and comparison with Version 1 | Differences explained by mechanism; ranked uncertainty table; complete annual reference paths |
| 14–16 | Resolve material findings; rerun; write methods and release package | Frozen production vintage; reproducible release; signed-off checks; publication-ready evidence |

### Gates that prevent an open ended rewrite

**End of week 2:** Approve the accounting definitions, release horizon, and gain concept. If source definitions cannot be reconciled, use a clearly labeled reduced-form mapping and include its alternative as a required sensitivity. Do not let unresolved concepts become undocumented defaults in code.

**End of week 6:** Require a real-vintage run. If the data bridge is still unstable, stop expanding scenario features. Complete one scenario across a small number of channels, then add the rest. A synthetic end-to-end run alone is not enough to pass this gate.

**End of week 9:** Choose the simplest gains and retirement mechanism that can be defended and validated. If a richer revaluation model remains unidentified, release the transparent reduced-form version with a valuation sensitivity. Do not revert to mixing lifetime coefficients with annual flows.

**End of week 13:** Freeze scope. Use the remaining capacity for explanation, failures, and reruns. No occupation lane, full GE module, or new policy menu enters the release at this point.

If work slips by two weeks, cut optional valuation detail, finer ownership cells, and extra chart variants first. Keep ownership boundaries, accounting consistency, annual timing, and restricted-data validation. If it slips by four weeks, make the 2030 tax result the publication focus while retaining the annual state calculations needed to generate it. Do not present unvalidated cumulative receipts as a completed ten-year score.

## Decisions to record in the revised plan

The eight original decisions are a useful start, but they omit several choices that determine the economic object. Replace the log with the following short list. Each decision should record the preferred option, evidence, alternatives, owner, decision date, and a condition for reopening it.

| Decision | Recommended first-release position | When to settle |
|---|---|---|
| Macro input and counterfactual | GDP-level path relative to a dated baseline; TFP adapter separate | Week 1 |
| Survey source and sector | Pin respondent group and vintage; map nonfarm business explicitly | Week 1 |
| Time and prices | Annual nominal tax accounting; common price path reference; align survey/tax dates | Week 2 |
| Factor accounts | Consistent mixed-income split; named depreciation and nonfactor components | Week 2 |
| Shock coverage | Broad accounts with explicit affected channels; housing can be unshocked | Week 2 |
| Owners and wrappers | Domestic taxable, deferred, exempt and foreign destinations | Week 2 |
| Capital gains mechanism | Annual stock or distributed-lag model; valuation sensitivity separate | Week 2 concept; week 9 calibration |
| Corporate tax response | Compatible baseline bridge plus separate incremental assumptions | Week 4 |
| Reconciliation | Explicit transformations first; residual measurement factor last | Week 4 |
| Payout and retirement | Matched dividend definition; separate DC/IRA, Roth and DB treatment | Week 6 |
| Distributional estimand | Cash and accrual-income panels; baseline ranking; reconciled incidence | Week 2 definition; week 10 implementation |
| Labor extension and feedback | Existing conditional labor rules only; later releases for employment and GE | Week 1 |

Do not settle a poorly identified parameter merely to close a decision item. A parameter can remain a documented scenario axis. What must be settled is its meaning, denominator, admissible range, and relationship to other assumptions.

## Validation and the research outputs that make the release credible

### Four distinct forms of evidence

**Accounting validation:** Every baseline and scenario satisfies the production, entity, ownership, household-allocation, and asset-state identities. The zero-shock case produces zero deltas. Income excluded from one tax base appears in a named alternative destination or deferred balance. Corporate tax is included once.

**Implementation validation:** Shuffling rows changes no tax-unit result. Scenario runs leave the baseline unchanged. Unknown channels fail explicitly. Tax years use the intended law. Single-channel tests exercise ordinary and qualified dividends, self-employment income, rental losses, capital-loss carryforwards, NIIT, QBI, and worker-level payroll caps. Check negative and zero income cases. Use tolerances justified by rounding and solver precision.

**Economic validation:** Baseline comparisons use matched year, universe, and income concept. Test tax responses on simplified households against the calculator's intended treatment. Compare model-implied dividends, realized gains, wages and retirement distributions with external totals after reconciling definitions. Where time permits, estimate bridge coefficients on an earlier window and assess a held-out window; label pandemic and major tax-law episodes separately. A historical fit cannot identify AI effects, but it can reveal an implausible transmission mechanism.

**Publication validation:** Reproduce Version 1 with its original restricted vintage and settings, separately from the new model. Decompose the change into source corrections, base definition, entity tax, ownership, realization, retirement, allocation, and income-concept changes. Freeze the order of a sequential comparison and show the interaction remainder, or use an order-averaged allocation if feasible. Reconcile all displayed totals back to the saved run manifest.

### Sensitivities with the highest value

Retain the recognizable three growth cases and the fixed-share versus changing-share comparison. Add uncertainty selectively rather than crossing every parameter into an unmanageable grid.

1. **Source and sector mapping:** corrected survey group; alternative defensible sector-to-national mapping; baseline-share path.
2. **Marginal entity composition:** economy-wide versus C-corporation/rent-concentrated gains, keeping the same aggregate income increment.
3. **Tax exposure:** resident ownership and traditional/Roth/exempt proportions, with the entire ownership matrix rebalanced.
4. **Gains:** persistence and announcement timing, realization schedule, and an alternative matched-coverage calibration.
5. **Corporate tax:** normal-return/investment-heavy versus rent-heavy cases, loss utilization, and tax-base response.
6. **Household distribution:** wealth-based versus income-based allocation where justified; top-tail sensitivity; existing labor-dispersion cases.
7. **Retirement and prices:** withdrawal response, DB treatment, and a limited price/indexing sensitivity.

Begin with local perturbations around a small reference set, then run two or three coherent combined cases. Report ranges as scenario uncertainty, not probability intervals. Do not choose independent extremes that imply an inconsistent economy. Tax-line sensitivity and household heterogeneity can interact strongly, so show at least the largest identified interactions.

### Required exhibits

The release should contain a flow reconciliation from aggregate income to federal tax bases; annual revenue by instrument; 2030 cash and economic-income changes by baseline income group; a table of income retained, deferred, exempt, or accruing abroad; a comparison with Version 1; and a ranked sensitivity table. Show aggregate gains and losses as well as average rates. A revenue-to-incremental-GDP ratio can be unstable when the GDP deviation is small, so accompany it with dollar levels and the ordinary revenue/GDP ratio.

### Completion criteria

Version 2.0 is ready when a researcher can change a documented aggregate shock and trace the resulting tax and distributional changes through saved, reconcilable intermediate outputs; the reference cases run on real data; the principal assumptions have dated receipts or explicit scenario status; the source discrepancies are resolved; and no unresolved accounting or timing issue can materially change the main interpretation. Agreement with the old headline is not a completion criterion.

## The first ten working days

**Days 1–2:** Freeze the source DOCX, public code commit, restricted-data vintage, calculator and patches, and published comparison outputs. Write a one-page release contract reflecting the solo staffing and tax/distribution scope. Archive the exact survey tables and questions.

**Days 3–4:** Build the baseline accounting table from GDP through factor income and household tax concepts. Correct the missing proprietors' labor component. Document the sector mapping and whether survey dates map to 2029 or 2030 tax-year quantities. Produce the old-versus-consistent survey-column diagnostic.

**Days 5–6:** Audit legal-form shares and ownership data. Reconcile the corporate effective-rate denominator. Draw the destinations of a dollar of C-corporation income, pass-through income, and owner-occupied housing income. Include a foreign owner and a retirement owner in the examples.

**Days 7–8:** Write the gains/retirement concept memo. Specify annual state variables and distinguish a flow ratio from a stock hazard. Remove the lifetime-61% and 84%-shortcut language from the proposed specification. Define the two distributional income panels.

**Days 9–10:** Implement a small aggregate prototype and its identities, using toy cases rather than the full cluster grid. Confirm annual microdata availability and schedule the first real-vintage run. Finalize the week-2 decisions and a prioritized implementation backlog.

The ten-day deliverable should be a corrected accounting specification, six research-packet outlines with data inventories, a source manifest, a runnable aggregate prototype, and a dated 16-week work plan. That package makes the larger implementation concrete enough to manage.

## Suggested replacement statement of purpose

“Version 2.0 estimates how a specified annual path of AI-related output and factor-income changes affects federal taxes and the distribution of household income under current law. It reconciles aggregate production income with entity tax bases, ownership and tax wrappers, household cash flows, and taxable realizations. The model distinguishes current income from asset revaluation and deferred income, exposes uncertain transmission parameters as scenarios, and preserves accounting identities at each stage. Its first release covers individual income taxes, payroll taxes, corporate income taxes, and household distribution. Employment transitions, broader spending responses, and endogenous macroeconomic feedback are subsequent extensions.”

## Source and implementation notes

The citations throughout identify the primary evidence supporting factual findings. BEA table numbers in the research packets are a proposed extraction list; the full calibration dataset still needs to be assembled and vintage-matched. The 2024 amounts used in diagnostics come from the repository receipt, and should not be silently replaced with revised values during replication.

The two public design notes, [Version 2 architecture](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/docs/v2_architecture.md) and [realization and wealth extensions](https://github.com/Budget-Lab-Yale/AI-Fiscal/blob/fbea6d7fa803a1668d9c157853ba485bb49626ac/docs/realization_and_wealth_extensions.md), are useful records of intended work. They contain assumptions and older implementation diagnoses that require rechecking against current code. In particular, the realization note should be revised together with the plan; otherwise the misleading lifetime interpretation will remain an apparent calibration authority.

The source plan's statement that double taxation “finally appears” in Version 2 should also be revised. Version 1 already records corporate and household tax layers in reduced form; Version 2's advance is to connect the underlying flows and expose their composition and timing. Similarly, change “ground truth” language around imputed wealth to a description of the measurement and imputation assumptions. Aggregate wealth validation does not alone validate the joint distribution of wealth, income, and tax rates that determines marginal revenue.

This roadmap leaves a clear path to the broader economic and fiscal system: add worker transitions and transfers after the tax/distribution ledger is stable, then connect annual revenue and spending deltas to a macro/fiscal model with an explicit feedback convention. That order protects the central contribution while keeping the first release feasible for one researcher.
