# How the Version 2 review fits the repository documentation

September 24, 2026

**Assessment of:** the local `AI-Fiscal-V2.0` branch at `60ea2c13dd89ad744de33ac3d360dc6d2b109ab4`, including the September 19–21 planning documents. **Release constraints:** one researcher; federal taxes and income distribution first.

## Recommendation

Use the [review and roadmap](v2_review_and_roadmap.md) to amend the existing decision log, flow network, and build plan. The repository already has a useful structure for managing this work. The highest-value next step is to reconcile its economic specifications and narrow the release scope, then implement against the corrected documents.

Three changes should lead that revision:

1. **Correct the definitions that determine the aggregate tax bases.** Reconcile survey coverage, mixed income, corporate-profit concepts, and the ownership universe before selecting transmission coefficients.
2. **Specify annual timing and distributional income before writing the cascade.** Production income, asset revaluation, realization, retirement withdrawals, and tax incidence need separate, reconciled objects.
3. **Replace the parallel labor lane with a later extension.** Preserve the existing labor-distribution cases and schedule the capital/tax work as a sequential solo project, with early real-data runs and explicit scope cuts.

My first review's main economic recommendations survive this comparison. Its engineering discussion needs qualification: several safeguards it emphasized are already implemented and explicitly marked complete in the local architecture. The build plan also already includes synthetic regression tests and real-data checkpoints. Those are strengths to retain.

## What was reviewed and what was saved

The September 23 review was copied, unchanged, into this folder as [Markdown](v2_review_and_roadmap.md) and [PDF](v2_review_and_roadmap.pdf). Its stated evidence base remains the original DOCX and public repository snapshot `fbea6d7f`; this companion adds the local planning context at `60ea2c13`.

I read all 15 active Markdown documents that were present before adding the review, inspected the plan-figure generator, and checked selected current code and calibration receipts. I used the archive's status notices and the archived Word document's opening to establish their historical role; I did not conduct a new line-by-line review of that archived manuscript. I rechecked the principal CRS realization source and CBO corporate-tax material. This assessment does not rerun the restricted-data model, validate a cluster installation, or establish the current status of upstream GitHub issues.

The existing planning documents and model code have not been edited as part of this assessment. Recommendations below are proposed amendments; they are not newly recorded `SET` decisions.

## The role each document should play

| Document | What it contributes | How the review should affect it |
|---|---|---|
| [v2_decisions.md](v2_decisions.md) | Active record of choices, evidence, and affected nodes; nothing is SET | Make this the controlling record of accepted decisions. Revise D1–D7, defer the first-release displacement choice in D8, and promote ownership, timing, and income definitions into early decisions. |
| [v2_flow_network.md](v2_flow_network.md) | Most precise map of equations, parameters, sources, and outputs | Revise this before implementation. Insert ownership and valuation/state modules; correct N13/N16, N19–N22, reconciliation, and the fiscal-output definitions. |
| [v2_build_plan.md](v2_build_plan.md) | Best implementation sequence and test framework; supersedes architecture §9 | Retain its phases, legacy regression mode, receipts, and real-data checkpoints. Replace problematic tests, add ownership explicitly, and remove the parallel labor commitment. |
| [v2_data_gathering.md](v2_data_gathering.md) | Concrete source inventory tied to decisions | Convert several collection tasks into definition/reconciliation tasks. Add ownership, tax-wrapper, asset-state, annual-file, and calendar/fiscal-year inputs. |
| [v2_architecture.md](v2_architecture.md) | Economic motivation and module rationale | Preserve the upstream redesign and reusable interfaces. Rewrite the claim that the production cascade subsumes the wealth problem; update the stages and reuse table after decisions are accepted. |
| [realization_and_wealth_extensions.md](realization_and_wealth_extensions.md) | Historical motivation, candidate formulas, retirement source inventory | Retain as research history until its calibration sections are corrected. Its present authority over realization and retirement specifications should be withdrawn. |
| [lit_macro_to_micro_structures.md](lit_macro_to_micro_structures.md) | Useful connections to CBO, distributional accounts, macro–micro linkage, and labor studies | Keep the source map. Separate methods that can be borrowed from assumptions that need estimation or judgment; qualify novelty and causal claims. |
| [labor_exposure_extension.md](labor_exposure_extension.md) | Detailed later extension, nonlinear-tax rationale, useful implementation constraints | Preserve for a later release. Its warning about limited transfer coverage is valuable; occupation imputation, worker splitting, and UI should not gate this first release. |
| [k_calibration_memo.md](k_calibration_memo.md) | Honest account of the provisional dispersion calibration | Retain its explicit uncertainty. Prefer a directly specified dispersion scenario; preserve the legacy GDP-linked `k` mapping for comparison. |
| [ai_fiscal_methodology.md](ai_fiscal_methodology.md) | Published-model reference and explanation of the existing pipeline | Preserve a versioned Version 1 reference. Correct unsupported identities and accounting language in the living document, while documenting any changes to historical exposition. |
| [ai_fiscal_methodology_appendix.md](ai_fiscal_methodology_appendix.md) | Precise Version 1 retirement allocation and mechanical realization | Use to reproduce the old specification. Its pooled taxable-income allocation is not an estimate of the marginal response of retirement withdrawals to new returns. |
| [data_requirements.md](data_requirements.md) | Input schema, imputation provenance, and distribution restrictions | Extend with a Version 2 availability matrix and units/concepts. The current schema identifies several limits on the proposed mixed-income and retirement treatments. |
| [environment_setup.md](environment_setup.md) | Practical cluster bring-up and year-range requirements | Make a pinned environment and usable two-year test input an early operational deliverable. Keep BLSMM optional for the first release. |
| [tax_simulator_patches.md](tax_simulator_patches.md) | Dependency risks and known local workarounds | Recheck against the selected calculator revision during setup. Record the patch diff and effects on outputs; do not make release timing depend on external maintainers merging changes. |
| [repo_consolidation.md](repo_consolidation.md) | Provenance and naming history | Treat older release checklists as historical. Use the current decisions log for active carry-over items and the build plan for branch policy. |

The `archived/` material supplies historical evidence, not an additional task list. The existing `plans/` figures visualize the proposed flow; their generator should be revised only after the network is corrected. In particular, the capital figure presently sends retention straight to accrual/realization and the other channels straight toward the tax file, so it inherits the conceptual gaps discussed below.

## Where the local documents strengthen or qualify the first review

**Engineering safeguards are already recognized.** Architecture §8 marks the join-order fixes, centralized scenario-axis registry, and corporate-tax double-counting check complete. The current code confirms these safeguards; `02_params.R` also rejects a starting year incompatible with its positional growth keys. Build step 1.2 explicitly replaces that guard with a year-indexed baseline. My first review's §12 was too broad when it suggested that the architecture still budgeted several of these as new work. The remaining implementation work includes module ownership, a defined macro return structure, and extending the safeguards to the new interfaces.

**The synthetic golden test is correctly framed in the build plan.** Principle 1 and step 0.1 call for reproducing the existing pipeline's outputs on the synthetic fixture, not reproducing the report's dollar estimates from synthetic records. Keep that test. My recommendation adds a separate comparison against published results using the pinned restricted-data vintage. Regenerate and document the synthetic fixture before freezing its golden outputs, as carry-over item V1-1 already recognizes.

**Early real-data runs are already scheduled.** Phases 3, 4, and 6 include them. Preserve that practice. The solo roadmap makes the first two deadlines explicit and adds the missing ownership stage to the first integrated run.

**Retirement and household wrappers are anticipated.** Architecture §3.2 distinguishes production from holding wrappers, and §4.2 acknowledges that the existing R1 justification changes under upstream sizing. The review's contribution is to specify a full ownership boundary, the ordering of wrapper treatment, and the economic limits of applying average retirement withdrawal ratios to marginal returns.

**Several data checks are already on the right path.** The decisions log calls the near-match between the constructed labor share and 55.5% an unverified hypothesis. It recognizes that the CBO baseline contains AI. The data checklist requests the survey instrument, a full national-income reconciliation, and primary documentation for the corporate-receipts decline. These are well-chosen tasks. The review supplies evidence that changes some proposed defaults and prioritizes their resolution.

## Changes that matter before implementation

### 1. Resolve D1–D3 as a single accounting specification

D1, build step 0.2, and N13 currently search for a matching national-accounts triple. The survey's nonfarm-business coverage makes a sector-to-economy bridge necessary; numerical similarity to a national ratio is insufficient. The review also identifies a respondent-column discrepancy that must be reconciled against the archived source vintage before changing published calibrations.

D3, N16, and data task 1.3 treat 13.1% of national income as the unexplained remainder after labor and capital. That calculation omits the labor half of proprietors' income. Restoring that component reduces the remainder to about 8.91% using the frozen receipt. This is a partial accounting repair, not a completed national factor decomposition.

The schema adds a further constraint: `sole_prop` and `farm` enter micro labor income in full, while the upstream receipt treats half of proprietors' income as capital; S-corporation profits also receive different macro and micro factor classifications. A common mapping must reconcile these choices. If the proprietors' capital share is `phi`, its labor counterpart is `1-phi`; N13 currently uses `phi` for the labor addition, which happens to work only at 0.5.

Reframe D2 as shock coverage within complete accounts. Dropping rental and interest from the affected channels requires rebuilding the mapping from the aggregate target. It cannot generally be interpreted as the same experiment with a capital increment mechanically reduced by 21%.

**Acceptance evidence:** a baseline table and one toy shock that reconcile sector coverage, GDP/national income, compensation/wages, mixed income, and named residual components. Source definitions and accounting identities should determine the table; residual policy should not conceal inconsistent definitions.

### 2. Add ownership before applying household tax treatment

The architecture distinguishes entity form from wrappers, but the flow network lacks a complete owner-sector partition. C6 is a retirement slice, A3 applies the legacy retirement cascade, and foreign ownership is mainly deferred under Q2.5. That is insufficient once the increment starts from national production income.

Insert an explicit entity-by-owner-by-wrapper allocation before household realization and tax-line mapping. It must conserve the entire flow across US taxable owners, traditional retirement accounts, Roth/exempt destinations, foreign owners, and any other retained institutional destinations. Intermediary holdings require a consistent look-through rule. Foreign ownership and the domestic/foreign corporate-tax-base bridge are related but distinct concepts.

This is a core scope requirement even if detailed multinational taxation is deferred. Allocating the entire increment among PUF owners and subsequently applying an unexplained reconciliation haircut would hide the very transmission mechanism Version 2 is meant to expose.

**Acceptance evidence:** the review's $100 example, plus all-foreign, all-retirement, zero-dividend, and intermediary-ownership cases. Verify which tax is collected and where the rest of each dollar resides.

### 3. Replace the claimed retention-to-gains identity with an explicit valuation rule

Architecture §7 says upstream income sizing subsumes the wealth-frame plan and sidesteps the income-to-wealth conversion. N21→N22 and C2 then translate retained profit directly into realized capital gains. This relocates the conversion assumption; it does not resolve it.

Use a production ledger for current profit and an asset ledger for values, basis, revaluation, realizations, and deferred balances. A permanent profit change may be capitalized when announced, and current retention need not create a dollar-for-dollar market-value gain. A deliberately simple valuation rule is feasible for the first release if its timing and interpretation are exposed as assumptions.

This also limits the reuse claims in architecture §6. The allocation functions may be reusable, but their input objects, eligible owners, and treatment of retained income change. The retirement cascade can help implement allocation of an already determined taxable flow; it does not determine that flow from upstream returns.

### 4. Correct the realization source and its interpretation throughout the dependency chain

The main source for the detailed 1987–2023 calculation is [CRS R48562, pages 1–2](https://www.congress.gov/crs_external_products/R/PDF/R48562/R48562.1.pdf). It reports a long-period realizations-to-eligible-accruals ratio, adjusted for noncompliance. It does not estimate an annual stock hazard or a cohort's lifetime realization probability.

The problematic interpretation originates in `realization_and_wealth_extensions.md` §§3.2–3.5 and is then inherited by architecture §4.2, N22, the parameter/source registries, data task 4.4, and build step 4.1. Correcting only the original DOCX would leave this chain intact. Replace the recommendation to retain 0.60 with a labeling footnote, and remove the 0.84 shortcut as a required result. The [review](v2_review_and_roadmap.md) explains the associated basis-at-death problem and cites the IRS source.

Promote the annual tax object and state convention to Phase 0. Estimate its parameters later. Phase 4's suggestion to choose annual versus lifetime concepts after seeing real-data results reverses the proper order: the output's economic meaning must be settled before selecting numerical fits.

### 5. Keep corporate-tax evidence separate from the coefficient it may inform

D4 and build step 0.5 inherit two weaknesses from the literature memo. The effective investment tax wedge in Acemoglu–Manera–Restrepo is not a numerical lower bound for federal CIT receipts divided by an incremental economic-profit flow. Also, the aggregate receipts decline does not identify a marginal tax response for AI firms.

[CBO's August 2026 budget review](https://www.cbo.gov/system/files/2026-09/61984-MBR.pdf), published in September, reports a 25% corporate-receipts decline for the first eleven fiscal-year months and attributes reduced payments to larger investment deductions under the 2025 act. It does not quantify an AI-specific causal contribution. The literature memo's stronger attribution should be narrowed.

There is also a concrete denominator mismatch: the CIT receipt uses pretax profits without IVA/CCAdj, whereas the entity-split receipt uses profits with those adjustments. [CBO's corporate projection method](https://www.cbo.gov/publication/59436) provides a useful framework for the necessary tax-base bridge. It does not supply an automatically transferable AI marginal rate.

**Required amendment:** define baseline profits and tax receipts on compatible concepts, then specify the incremental response with separate assumptions for investment deductions, losses, credits, and entity/foreign coverage. Preserve a simple reference rule and a small number of interpretable sensitivities.

### 6. Reconciliation and distributional accounting must be designed together

D5's historical SOI/NIPA ratio is useful evidence, but it cannot automatically be multiplied after explicit ownership, wrappers, and realization. The historical ratio may already incorporate those mechanisms. Give each adjustment a named conceptual purpose and reserve any residual scaling for the remaining measurement gap.

NIPA rental income is not uniformly cash rental income eligible for Schedule E, and net interest is not uniformly household taxable interest. Add those concept bridges before treating the missing rental writer as the main issue. Confirm the Tax-Data definition of `div_ord`: a raw SOI ordinary-dividend total contains qualified dividends, while a calculator may store ordinary-only and preferential amounts separately. The source crosswalk must establish which convention each field uses.

The literature memo and build Phase 5 correctly identify a missing corporate-incidence report. But deducting CIT before distributing profits already reduces owners' income. Applying a second burden deduction to the same after-entity-tax income would count it twice. Define pre-tax income, after-tax income, and the incidence overlay together; preserve an auditable reconciliation when reallocating burden from owners to workers.

Distributional national accounts help allocate economic income. That allocation is not automatically a rule for household cash receipts or taxable realizations. Publish separate cash and economic-income panels, with retained income and retirement accruals represented once and valuation changes reported separately.

### 7. Make the fiscal calendar and validation objects explicit

The flow network juxtaposes scenario CIT changes and CBO baseline CIT levels; §6 also places 2030 projected income changes beside historical SOI totals. These comparisons can orient the reader but cannot serve as direct pass/fail targets. Validate baseline levels against matched baseline levels; reconcile scenario deltas against their mechanism and counterfactual; align historical diagnostics by year and concept.

The local implementation exposes an important distinction between corporate-tax **levels** and **changes**. `09_tables_figures.R` describes an existing microsimulation CIT baseline and checks that its scenario delta is zero. Methodology text says that baseline is zero. The new specification should state which baseline is already carried through and where the single incremental entity-CIT amount is added. Do not add a second baseline while retiring the old delta formula.

The setup guide and `00_ai_fiscal_sim.R` require at least two input years because Tax-Simulator's fiscal-year adjustment drops the earliest one. Thus the roadmap's first run for one reported year requires the adjacent supporting tax-year files under the current interface. Specify tax year, calendar year, fiscal year, and the conversion rule in the baseline/output contracts. Confirm annual data availability in week 1; do not discover the dependency at the first cluster run.

Finally, E2 nets refundable-credit outlays against income-tax receipts. That is a useful fiscal-balance contribution, but it needs a distinct label from federal receipts. Report receipts and credit outlays separately before constructing a net fiscal measure or comparing to CBO revenue/GDP.

## Acceptance tests that should change

The build plan's insistence on tests is sound. Some proposed assertions encode disputed assumptions and should be replaced before implementation.

| Current specification | Problem | Better acceptance criterion |
|---|---|---|
| Step 3.4: dividend share equals `p/[p+(1-p)r]` | This is a share conditional on the flow being realized; it can erase the unrealized remainder if applied to total after-tax profit | Preserve dividend, realized-gain, and deferred amounts separately; use any normalized share only against its explicitly realized pool. |
| Step 4.1: lifetime factor must equal 0.84 | Locks in the disputed interpretation of realization and step-up | Given a stated annual state/lag rule, reconcile new gains, realizations, basis adjustments, and the closing balance. |
| Step 4.1: realized flow never exceeds gross flow | With accumulated prior gains, this year's realizations can exceed this year's new gains | Bound realizations against the eligible available pool under the chosen state convention; handle losses separately. |
| Step 3.1: effective/statutory revenue ratio must equal 0.70 | Freezes the old rounded avoidance factor even if the base or calibration changes | Check against the chosen rule and dated receipt; test a hand-calculated compatible-base example. |
| Step 5.1: household CIT burdens sum to the full CIT increment | May assign foreign/exempt incidence to US households; says nothing about double subtraction | Reconcile total incidence across all owners and the domestic household subset; reconcile the burden overlay with after-entity-tax income. |
| Publication allowed only when all validation rows pass | Mechanical identity failures differ from explained coverage gaps and modeling diagnostics | Make identity/schema failures blocking; require documented dispositions for material economic gaps; retain diagnostic outputs on failed runs. |

Two additional claims in the existing methodology should not migrate into Version 2 tests. Its assertion that the micro income total grows exactly at `g_Y` generally fails when micro factor shares differ from the shares used to derive `g_L` and `g_K`. In a toy 70/30 micro split, the existing rapid-scenario growth rates imply roughly 4.52% micro-income growth versus 7.17% GDP growth. This is an algebraic illustration, not an estimate from actual microdata. The claimed absolute revenue bound based on a labor/capital tax-rate swap also does not bound a scenario with aggregate growth. Replace both with identities specific to the new accounting system.

## Amend the existing decision log without losing its history

Keep D1–D8 identifiers so references in the network and build plan remain useful. Record the old proposal, the reason for revision, and the accepted successor specification.

| Decision | Proposed amendment |
|---|---|
| D1: share bridge | Fix respondent group, source vintage, survey dates, sector coverage, and the sector-to-national mapping. |
| D2: capital base | Distinguish the accounting universe from affected channels and marginal entity composition. |
| D3: residual | Correct mixed-income treatment, then name and assign rules to all remaining components. |
| D4: incremental CIT | Separate baseline average calibration from the marginal response; remove the investment-wedge lower bound. |
| D5: reconciliation | Order conceptual adjustments explicitly and define the residual measurement adjustment. |
| D6: baseline | Include annual availability, policy vintage, prices, baseline AI assumptions, and calendar/fiscal mapping. |
| D7: payouts | Define the matched dividend/profit universe and distinguish cash payout, retained production income, and valuation. |
| D8: labor displacement | Record that occupation/displacement/UI are deferred from the first release under the agreed solo tax/distribution scope. Preserve the question for the later extension. |

Add early decisions on **ownership boundaries; annual gains and death/basis treatment; retirement balances and withdrawals; cash versus economic-income definitions and CIT incidence; and publication horizon/required outputs**. Their concepts should be set early even when calibration remains open. There is no need to estimate every coefficient in Phase 0.

Allocate new IDs from one registry. The decisions log says D9 is next, while the labor-lane build table already calls its exposure gate D9. Resolve that reservation when the log is updated. Also distinguish reconciliation node `R1` from retirement treatment `R1`, and model Version 2 from historical realization variant `V2`, in prose and output labels.

## A practical revision sequence for one researcher

Use the existing build plan as the implementation backbone and the [16-week roadmap](v2_review_and_roadmap.md) as its capacity budget. Its phase estimates sum to roughly 11–14 weeks before the proposed labor lane; saying that labor adds four to six weeks “in parallel” does not create capacity for a solo researcher.

1. **First two days: revise the release contract and decision dependencies.** Retain the 2030 publication focus, annual intermediate accounting, existing labor cases, and named sensitivities. Confirm the data and calculator-year requirements. Move the newly identified concept decisions into the early gate.
2. **Days three to five: revise the network and acceptance criteria.** Work through the accounting table and $100 examples; insert ownership and asset-state nodes; correct output units and comparisons. Update the figure specification only after these choices are stable.
3. **During week two: revise the build and data plans.** Add an explicit owner/wrapper stage, matched tax-base bridges, a limited annual timing mechanism, and two income panels. Retain the real-data checkpoints and quantify the pass-through allocation leak at the first usable run, rather than leaving it until release.
4. **Then update architecture and source memos to match the decisions.** Correct the realization memo's source interpretation and the literature memo's borrowed-method claims. Replace strong novelty assertions such as “nobody runs the full chain” with a scoped statement about what the reviewed sources document. Correlations between labor shares and corporate saving can motivate a payout sensitivity; they do not identify its causal coefficient for an AI shock.
5. **Implement with the existing phase structure.** Weeks 3–4 cover baseline and production mapping; weeks 5–6 entity tax plus ownership and the first integrated restricted-data run; weeks 7–9 timing and tax-line writers; weeks 10–11 distribution and existing labor cases; weeks 12–13 comparisons and sensitivities; weeks 14–16 resolution, reruns, and release documentation.

These document revisions belong inside the first two weeks, not in an additional open-ended planning phase. A small aggregate prototype can test the definitions while they are being written. The first publication should not depend on a complete lifecycle model, detailed multinational microsimulation, occupation imputation, or endogenous macro feedback.

Before committing major implementation time, the revised package should let another economist follow one aggregate shock through a complete national-income reconciliation, entity taxes, ownership, annual taxable flows, and two distributional income definitions. Before publication, it should do the same on the real-data reference cases, with deviations from Version 1 explained by mechanism.
