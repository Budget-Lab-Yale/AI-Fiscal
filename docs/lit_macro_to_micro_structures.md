# Who else runs macro → corporate tax → microdata? A survey

**Status:** Research memo, 2026-09-19. Companion to
`v2_architecture.md` and `v2_flow_network.md`; node IDs (`N4`, `R1`,
…) refer to the flow network. Sources were checked on the day of
writing; where a document could not be opened (CBO PDFs return 403 to
scripted fetches) the entry says so and relies on the abstract or
secondary summaries.

## Bottom line

Nobody runs the full v2 chain — an AI factor-share shock sized on
national-accounts capital income, pushed through an entity-level
corporate tax, a payout/retention split, and explicit realization onto
a tax-return microfile — as one pipeline. But every stage has a mature
analogue somewhere, and four of them are close enough to borrow
directly:

1. **CBO's two revenue methods, read together,** are the v2 spine
   without the shock. The individual-tax method calibrates the SOI
   microfile to NIPA personal-income components; the corporate method
   maps NIPA domestic economic profits to the corporate tax base with
   explicit adjustments for S-corps, book-tax differences, and foreign
   income. That is N4 → N9 → R1 on one side and N5 → N8 → N19 on the
   other.
2. **Distributional national accounts** (Piketty-Saez-Zucman,
   Auten-Splinter, Blanchet-Saez-Zucman) are the only published systems
   that land *all* of NIPA corporate profits — including retained
   earnings and the corporate tax itself — on tax-unit microdata. Their
   allocation keys are the missing N21 → A1 bridge, and their
   "stable distribution of capital income components" assumption is
   exactly the R1 "inherit" option.
3. **Doorley et al. (2023)** is the labor-lane template: an exposure
   shock estimated at the demographic-cell level, mapped onto microdata
   as wage and employment changes, then run through EUROMOD. It is P3
   with robots instead of generative AI.
4. **Penn Wharton** has the integrated architecture (household and
   corporate calculators in one codebase, entity-choice module, OLG
   feedback) but drives it with a TFP path, not a factor-share shift,
   and its 2025 AI work does not split labor from capital income.

The survey also surfaced one channel v2 does not have: the
**investment/expensing side of the corporate base.** FY2026 corporate
receipts are running 25% below FY2025 with AI capex under permanent
100% bonus depreciation the cited cause. v2 taxes an AI *profit*
increment at a fixed effective rate; the current data say the
effective rate on the AI increment is itself moving, and downward,
during the build-out. Q2.1 should absorb this.

---

## A. Revenue-estimating shops: macro aggregates → income by type → micro alignment → receipts

These are the structures closest to what v2's baseline module (N4,
N9) and reconciliation stage (R1) need.

| Shop | Chain | What maps to v2 | Notes |
|---|---|---|---|
| **CBO — individual income tax** | Macro forecast → NIPA personal-income components (wages, interest, dividends, proprietors' income) → estimated NIPA-to-IRS relationships → adjust SOI microfile so simulated current law matches the revenue baseline | N4 → N9 → R1. The "NIPA-to-IRS relationships" step is R1 made explicit and estimated, not assumed | Overview in *An Overview of CBO's Microsimulation Tax Model* (2018) and *How CBO Projects Income* (2013). The alignment methodology itself is in a 2016 presentation (Perese, APPAM) that surveys other static microsims' reweighting methods |
| **CBO — corporate income tax** | NIPA domestic economic profits → corporate tax base, adjusting for (i) conceptual differences between economic and tax profits (depreciation, book-tax), (ii) entity coverage (S-corps and other pass-throughs excluded), (iii) foreign income | N5 → N6 → N8 → N19. This is the published template for turning a NIPA profits increment into a CIT increment | *How CBO Projects Corporate Income Tax Revenues* (Oct 2023, pub 59436). PDF blocked to scripted fetch; description from abstract and Tax Notes summary. Also *Recent Changes in CBO's Projections of Corporate Income Tax Revenues* (pub 56121) on the growing profits-vs-receipts gap |
| **JCT** | Individual microsim ↔ MEG macro model iterated to convergence on average and marginal rates; OLG model recently extended with corporate tax | The iteration loop is what v2 would need if labor/capital shocks ever feed back into rates (parked; v2 is static) | *The JCT Revenue Estimating Process* (2019); *Macroeconomic Analysis of the Conference Agreement* (2017); CRS R43381 reviews the models |
| **Treasury OTA** | Distribution methodology: all federal taxes including CIT distributed to families on a pre-tax cash-income basis | See §B for the CIT allocation | *Summary of OTA Distribution Methodology* (May 2021) |
| **Penn Wharton Budget Model** | Tax Module = microsim with individual, payroll, corporate, estate calculators in one codebase; SOI returns matched to CPS; projected with PWBM's own microsim; produces effective-rate functions for the OLG; entity-form choice modeled and passed to OLG | Integrated household+corporate calculator is the architecture v2 §4 describes. Entity-choice module is a modeled version of N6/N17 | Tax Module and Dynamic Integration pages; 2019 OLG documentation |
| **Tax Foundation TAG / GE model** | Tax simulator (individual, corporate, payroll…) → marginal rates → Cobb-Douglas production function → output, capital, labor → income growth factors fed back to the microsim for dynamic revenue and distribution | "Income growth factors by type" is N12 → N9 in reverse: they derive factor growth from rates, v2 imposes it from Karger | *Overview of the Tax Foundation's General Equilibrium Model* |
| **UK OBR — onshore CT** | Economy forecast (profits by sector, business investment, equity prices) → three sectors → income less capital allowances, group relief, losses → effective rate → cash receipts → time-shifted accrual | A clean three-stage CIT chain with the deductions side explicit — the piece v2 §4 leaves inside the 30% avoidance black box | *Forecasts in depth: onshore corporation tax* |
| **Heritage** | Note on calibrating macro and microsim models to CBO's baseline | Confirms the "calibrate to CBO baseline" convention is standard across shops | *Calibrating Macroeconomic and Microsimulation Models to CBO's Baseline Projections* |

**Takeaway for N4/N9.** CBO already publishes the income-side
projections the baseline module wants (wages and salaries, domestic
economic profits, proprietors' income) alongside the GDP path, and its
individual-tax method treats the NIPA-to-tax-base mapping as an
estimated relationship per income type. v2 should adopt both: pull the
CBO income lines for 2030 rather than scaling 2024 NIPA by GDP, and
make R1 a per-channel ratio estimated from history (SOI line / NIPA
component) rather than a binary benchmark-vs-inherit switch.

**Takeaway for N19.** CBO's corporate method is explicit that
economic profits ≠ tax base for three separable reasons. v2 currently
collapses all three into one avoidance scalar. At minimum, the S-corp
exclusion (already separate in the receipt) and the depreciation
timing wedge (see §D, expensing) should be distinct multipliers.

---

## B. Distributional national accounts and CIT incidence: landing corporate profits and the corporate tax on households

This is the literature that does what v2 §3.4 calls the "hard
coupling": it takes NIPA totals — including the parts households never
see on a 1040 — and distributes 100% of them to microdata.

### B.1 Allocation keys for retained earnings

| System | Retained earnings (undistributed profits) | Corporate income tax | Notes |
|---|---|---|---|
| **Piketty-Saez-Zucman (2018 QJE)** | Included in national income on an accrual basis; distributed to equity owners so that pre-tax income sums to national income. Simplified DINA (2019 P&P): nontaxable capital income distributed like taxable capital income | Attributed to capital owners | Data appendix and `usdina` files public |
| **Auten-Splinter (2024 JPE + online appendix)** | "Three-quarters of retained earnings are allocated based on a tax filer's share of dividends and one-quarter based on their share of capital gains, including Schedule D and Form 4797 gains" — dividends primary per Smith et al. (2019), gains added because some corporations pay none | Their sensitivity table contrasts "corporate taxes by wages/corp. ownership" (their choice) with "by capital ownership" (PSZ); the difference moves top shares by about 0.2pp | The most directly reusable key for N21 → A1 |
| **Blanchet-Saez-Zucman, Real-Time Inequality (2022)** | Monthly/quarterly: rescale each national-income component to its seasonally adjusted aggregate; capital-income components assume **stable distributions** across the base micro-file; labor income does not (updated from CPS/QCEW) | Follows PSZ | The "stable distribution" step is R1-inherit. Their code and data are public |

**Implication.** v2 does not need to invent the household-side key for
retained earnings. Auten-Splinter's 75/25 dividends/gains key or PSZ's
equity-wealth key are both defensible and citable; the v1.0
wealth-proportional allocator (A1) is closer to PSZ. Carry the two as a
named sensitivity, not a decision.

### B.2 Distributing the corporate tax *burden* (a stage v2 lacks)

Every distributional shop distributes the CIT to households; v2
computes ΔR_CIT (N19) as revenue and stops. If the paper reports
distributional results at all, readers will expect the corporate tax
increment to appear in household burdens. The conventions:

| Shop | Rule |
|---|---|
| **Treasury OTA** (Cronin, Lin, Power, Cooper 2013 NTJ; 2021 summary) | Share on supernormal returns → shareholders; share that is a cash-flow tax → no long-run burden; remainder (normal return) split equally between labor and positive normal capital income. Realized split in the 2021 summary: **81.5% capital / 18.5% labor** |
| **Tax Policy Center** (Nunns 2012) | **60% supernormal returns to corporate equity, 20% normal returns to all capital, 20% labor** |
| **CBO** (Distribution of Household Income series) | **75% capital** (in proportion to interest, dividends, rents, and capital gains scaled to their long-run level) / **25% labor** |
| **JCT** | Similar supernormal/normal decomposition (Toder 2025 chapter reviews all four) |

This is a new node between N19 and E6: `ΔR_CIT` → household burden
by an incidence rule ∈ {OTA, TPC, CBO}. Cheap to add because A1's
wealth base and P7's labor base are already on the file.

---

## C. Macro-micro linkage methodology and the closest applied analogues

### C.1 Method

- **Bourguignon, Bussolo, Cockburn (2010); Bourguignon & Bussolo
  (2013)** — the top-down / top-down-bottom-up / fully-integrated
  taxonomy for CGE-microsim linkage. v2 is top-down: macro solves,
  micro receives.
- **Peichl (2009)** *The benefits and problems of linking micro and
  macro models* — the flat-tax case study; the documented failure mode
  is inconsistency between micro aggregates and macro identities
  ("(dis)aggregation errors"). This is N16 (adding-up residual) by
  another name. His recommendation is to enforce the identity
  explicitly at the interface, which is what `check_capital_contract()`
  should do.
- **International Journal of Microsimulation** macro-micro editorial
  and comparison papers (Cockburn et al.) for the alternatives.

### C.2 Applied analogues

| Study | Structure | Maps to |
|---|---|---|
| **Doorley, Gromadzki, Lewandowski, Tuda, Van Kerm (2023), *Automation and Income Inequality in Europe*, IZA DP 16499** | Robot-exposure IV at the level of 30 demographic cells per country (age × gender × education) → estimated wage and employment changes per cell → mapped onto EU-SILC individuals → EUROMOD computes taxes and benefits → counterfactual disposable income, Gini. Finding: tax-benefit systems and household income pooling absorbed most of the shock | **P3 template.** Same cell-level design the labor doc proposes; they did it with 30 cells because that is where the exposure regression has power — the same resolution constraint as the PUF |
| **JRC CORTAX + DiRECT** | CORTAX = CGE for macro effects of CIT reforms (Orbis-calibrated); DiRECT = firm-level CIT microsim (depreciation, interest limits, dividend exemption, loss offset, group consolidation) developed to complement it | The entity-CIT stage (N19) as a *firm* microsim instead of a scalar τ*. Out of reach for v2's first cut but the right long-run design; SOI corporate microdata are the US analogue |
| **IMF SDN 2024/002, *Broadening the Gains from Generative AI*** (Brollo, Dabla-Norris, de Mooij, Garcia-Macia, Hanappi, Liu, Nguyen) | HANK-DSGE with search frictions (Ravn-Sterk 2021) extended with automatable capital in one of two sectors; shock = acceleration in productivity of automated capital sized to McKinsey (2023) 20–30% task replacement by 2030; **extensive margin only**; UI and ALMP modeled; welfare analysis of a temporary automation tax. Fiscal recommendation: strengthen capital-income taxation generally rather than tax AI | Structural GE complement to v2's static accounting. Their extensive-margin-only choice is the mirror image of v1.0's intensive-only |
| **Kaymak & Schott (2023 Econometrica)** | Industry equilibrium with heterogeneous capital intensity; lower CIT raises market share of capital-intensive firms and lowers the labor share; 30–60% of the observed manufacturing labor-share decline attributed to CIT cuts | Says the causal arrow can run CIT → labor share, not only share → CIT. Relevant to Q3.4 and to how Karger's share path should be read |
| **Karabarbounis & Neiman (2012, 2014); Chen, Karabarbounis, Neiman (2017)** | Global labor-share decline coincides with the rise of corporate saving; the corporate sector now finances its investment from retained earnings | Direct evidence for N21: a falling labor share has historically meant *higher retention*, not higher payout. The payout ratio p should be allowed to fall with the share shift, not held at its baseline |
| **Smith, Yagan, Zidar, Zwick (2019 QJE); Cooper et al. (2016)** | 75% of top pass-through profit is human-capital (labor) income; pass-throughs are >50% of business income, ownership opaque, average federal rate 19% | Already the source for the SZ split at P3 and φ_propK at N6; Cooper et al. is the citation for s_scorp and for the K-1 opacity caveat |

---

## D. AI-specific fiscal work (2024–2026)

| Source | What it does | What it does not do |
|---|---|---|
| **Karger et al. (2026), *Forecasting the Economic Effects of AI*, NBER w35046** | Surveys five groups (economists, AI-lab staff, policy researchers, superforecasters, public) on 2030 outcomes; median GDP growth 2.5%/yr; labor-share path by scenario. Disagreement driven by beliefs about effects of capable AI, not its pace | Provides a labor share and a growth rate, **not** a separate capital-income growth rate or an entity split. Answers the parked question in `v2_architecture.md` §11: g_K must still be derived from the share path |
| **Penn Wharton (Sep 2025), *Projected Impact of Generative AI on Future Productivity Growth*** | Eloundou et al. task exposure (T0–T4 → 0/70/95/100% weights) × BLS OEWS → 40% of GDP exposed; × 23% profitably automatable (Svanberg et al.) × 25–40% labor-cost savings → long-run TFP; diffusion curve from PC/internet/smartphone/cloud → 1.5% GDP by 2035, 3.7% by 2075 | "Assumes the share of GDP exposed to AI is the same as the share of labor income." **No factor split, no revenue by tax type.** Budget effect via CBO rules of thumb (Third Way: −$435B debt by 2035) |
| **CBO (Jan–Feb 2026 Outlook; *Understanding Productivity Growth in CBO's Economic Forecast*)** | First explicit AI productivity assumption: +0.1pp/yr, +1% output by 2036; business fixed investment +3.9% in 2026 driven by AI and the 2025 reconciliation act's incentives | No factor-share or composition-of-revenue channel published |
| **Third Way (2026), *How Will AI Impact the Federal Budget?*** | Compares CBO, PWBM, and Budget Lab; notes income could shift from labor to capital "which is taxed differently" and cites the Budget Lab result that rapid-scenario revenue gains would be twice as large at fixed shares | Descriptive |
| **Brookings — Korinek & Lockwood, *A public finance framework for the age of AI*** | Conceptual: ~3/4 of federal revenue rests on labor; recommends shifting toward consumption taxation, taxing AI services not AI capital | No quantitative model |
| **Brookings/TPC (Sep 2026), *AI tax debate misses the threat that's already here*** | Argues narrow AI taxes (Wyden data-center proposal, excise) cannot fill the fiscal hole; only broader capital-income taxation can | Policy commentary |
| **TaxProf Blog / Politico (Sep 2026), *Is the AI boom hollowing out corporate tax receipts?*** (Speck; Faler) | CBO monthly review: FY2026 corporate receipts −25% YoY through 11 months ($390B → $294B), after −15% FY2024→FY2025; permanent 100% bonus depreciation under the 2025 act lets AI data-center capex (≈$600B/yr, Goldman) be expensed; Microsoft's tax bill cited falling from $14.1B to $2.5B | **This is the channel v2 lacks.** v2 taxes an AI profit increment at τ_eff = 0.147 calibrated on 2024 receipts. During the build-out the marginal effective rate on AI-related profit is far lower and the *baseline* CIT path is itself moving |
| **Acemoglu, Manera, Restrepo (2020 BPEA)** | Effective tax on labor 25.5–33.5% vs on software and equipment 10% (2010s) and 5% post-TCJA; tax code biased toward automation; optimal reform raises labor share 0.78pp | Provides the effective-capital-tax numbers that should bound τ* on the *increment* (Q2.1) from below |
| **IMF SDN 2024/002** | See §C.2 | — |
| **Robot-tax theory** — Guerreiro, Rebelo, Teles (ReStud 2022); Thuemmel (JEEA 2023); Costinot & Werning (ReStud 2023) | Optimal taxation of automation when other instruments are constrained; generally "tax robots, for a while" | Normative; context for the paper's framing only |
| **Doorley et al. (2023)** | See §C.2 | — |

---

## E. Where v2 is genuinely new, and what to borrow

**New:** the combination. No published pipeline sizes an AI shock as a
factor-share shift on national-accounts capital income, runs it
through entity taxation, payout/retention, and realization, and lands
it on a tax-return microfile with a full individual calculator. PWBM
has the plumbing but not the shock; DINA has the shock-agnostic
allocation but no calculator; CBO has both halves as separate
published methods for baseline projection, never joined for a
counterfactual.

**Borrow, by node:**

| Node | Borrow | From |
|---|---|---|
| N4, N9 | Pull CBO's income-side projections (wages & salaries, domestic economic profits, proprietors' income) for the baseline year instead of GDP-scaling 2024 NIPA | CBO Outlook supplementary economic tables |
| N19 | Separate the three profits→base wedges (concept/book-tax, entity coverage, foreign) rather than one avoidance scalar; treat the depreciation wedge as time-varying during the AI capex build-out | CBO pub 59436; OBR CT chain; TaxProf/Politico receipts evidence |
| N21 | Let p fall with the share shift (retention rises when labor share falls); pull p from NIPA 1.12 | Karabarbounis-Neiman; Chen et al. |
| N21 → A1 | Household key for retained earnings: 75% dividends / 25% realized gains (AS) vs equity wealth (PSZ) as a named sensitivity | Auten-Splinter appendix; PSZ 2018 |
| R1 | Estimate per-channel NIPA→SOI ratios from history instead of a binary benchmark/inherit switch; "stable distribution" = inherit | CBO individual method; Blanchet-Saez-Zucman |
| N16 | Enforce the macro identity at the micro interface as a hard test | Peichl (2009) |
| New node N19 → E6 | Distribute ΔR_CIT to households under OTA (81.5/18.5), TPC (60/20/20), CBO (75/25) rules | OTA 2021 summary; Nunns 2012; CBO |
| P3 (labor lane) | Cell-level exposure shock → wage/employment change per cell → microdata → calculator | Doorley et al. 2023 |
| Q2.1 bound | Effective capital tax on software/equipment 5–10% as a lower bound for τ* on the increment | Acemoglu-Manera-Restrepo |
| Q3.4 | CIT → labor share causality runs both ways; say so | Kaymak-Schott |

**Open after this survey.** Whether any shop has published the
*estimated* NIPA-to-SOI ratios by income type (CBO uses them
internally; the 2016 Perese presentation may list them). Whether
PWBM's entity-choice module documentation is public in enough detail to
replicate its κ. Whether CBO's monthly budget review or a 2026 CBO
report attributes the corporate-receipts decline to AI expensing
quantitatively, or whether that attribution is Politico's.

---

## Sources

Revenue-estimating shops
- CBO, *An Overview of CBO's Microsimulation Tax Model* (2018) — https://www.cbo.gov/system/files/2018-06/54096-taxmodel.pdf
- CBO, *How CBO Projects Income* (2013) — https://www.cbo.gov/publication/44433
- CBO, *Projection and Alignment Methods for Static Microsimulation Models* (Perese, 2016) — https://www.cbo.gov/publication/52147
- CBO, *How CBO Projects Corporate Income Tax Revenues* (Oct 2023, pub 59436) — https://www.cbo.gov/publication/59436
- CBO, *Recent Changes in CBO's Projections of Corporate Income Tax Revenues* (pub 56121) — https://www.cbo.gov/publication/56121
- JCT, *The JCT Revenue Estimating Process* (Feb 2019) — https://www.jct.gov/getattachment/5a50d049-0af4-4658-a174-d35777b4418e/Revenue-Estimating-Process-February-2019-5162.pdf
- JCT, *Macroeconomic Analysis of the Conference Agreement* (2017) — https://www.jct.gov/getattachment/53ad7658-20ac-4c10-b4d0-2759305432aa/x-69-17-5055.pdf
- CRS R43381, *Dynamic Scoring for Tax Legislation: A Review of Models* — https://www.congress.gov/crs-product/R43381
- PWBM, Tax Module — https://budgetmodel.wharton.upenn.edu/tax-module ; Dynamic integration — https://budgetmodel.wharton.upenn.edu/dynamic-integration ; OLG documentation (2019) — https://pwbm.squarespace.com/s/2019-05-30-DynamicModel-Documentation.pdf
- Tax Foundation, *Overview of the Tax Foundation's General Equilibrium Model* — https://taxfoundation.org/research/all/federal/general-equilibrium-model/
- OBR, *Onshore corporation tax* — https://obr.uk/forecasts-in-depth/tax-by-tax-spend-by-spend/onshore-corporation-tax/
- Heritage, *Calibrating Macroeconomic and Microsimulation Models to CBO's Baseline Projections* — https://www.heritage.org/taxes/report/calibrating-macroeconomic-and-microsimulation-models-cbos-baseline-projections
- Budget Lab, *Tax Microsimulation at The Budget Lab* — https://budgetlab.yale.edu/research/tax-microsimulation-budget-lab

Distributional national accounts and CIT incidence
- Piketty, Saez, Zucman (2018 QJE) — https://gabriel-zucman.eu/files/PSZ2018QJE.pdf ; data appendix — http://gabriel-zucman.eu/files/PSZ2018DataAppendix.pdf ; Simplified DNA (2019 P&P) — https://www.aeaweb.org/articles?id=10.1257/pandp.20191035
- Auten & Splinter, online appendix — https://davidsplinter.com/AutenSplinter-Tax_Data_and_Inequality_onlineapp.pdf ; 2025 update — https://davidsplinter.com/AS-Update-2025.pdf
- Blanchet, Saez, Zucman, *Real-Time Inequality* — https://eml.berkeley.edu/~saez/BSZ2022-rev1.pdf ; methodology page — https://realtimeinequality.org/methodology/
- Cronin, Lin, Power, Cooper (2013), *Distributing the Corporate Income Tax: Revised U.S. Treasury Methodology*, OTA TP-5 — https://home.treasury.gov/system/files/131/TP-5.pdf
- OTA, *Summary of OTA Distribution Methodology* (May 2021) — https://home.treasury.gov/system/files/131/Summary-of-OTA-Distribution-Methodology-05102021.pdf
- Nunns (2012), *How TPC Distributes the Corporate Income Tax* — https://www.urban.org/sites/default/files/publication/25796/412651-How-TPC-Distributes-the-Corporate-Income-Tax.PDF
- Toder (2025), *The incidence of the corporate tax* (chapter) — https://taxpolicycenter.org/sites/default/files/2025-02/Toder-chapter%204-Incidence%20of%20Corporate%20Tax.pdf
- CBO, *The Distribution of Household Income in 2021* — https://www.cbo.gov/publication/60706

Macro-micro linkage and applied analogues
- Peichl (2009), *The Benefits and Problems of Linking Micro and Macro Models* — https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1405203 ; *Linking microsimulation and CGE models* (IJM) — https://microsimulation.pub/articles/00132
- Bourguignon & Bussolo, IJM editorial on macro-micro analytics — https://microsimulation.pub/articles/00020 ; Cockburn et al., *Linking CGE and microsimulation models: a comparison* — https://microsimulation.pub/articles/00026
- Doorley, Gromadzki, Lewandowski, Tuda, Van Kerm (2023), *Automation and Income Inequality in Europe*, IZA DP 16499 — https://docs.iza.org/dp16499.pdf
- JRC CORTAX — https://joint-research-centre.ec.europa.eu/scientific-activities/fiscal-policy-analysis/corporate-taxation/cortax-model_en ; DiRECT — https://joint-research-centre.ec.europa.eu/scientific-activities/fiscal-policy-analysis/corporate-taxation/corporate-tax-microsimulation-model-direct_en
- IMF SDN 2024/002, *Broadening the Gains from Generative AI: The Role of Fiscal Policies* — https://www.imf.org/-/media/files/publications/sdn/2024/english/sdnea2024002.pdf
- Kaymak & Schott (2023 Econometrica) — https://www.econometricsociety.org/doi/10.3982/ECTA17702
- Karabarbounis & Neiman (2012) — https://www.nber.org/system/files/working_papers/w18154/w18154.pdf ; Chen, Karabarbounis, Neiman (2017) — https://researchdatabase.minneapolisfed.org/downloads/m900nt49x
- Smith, Yagan, Zidar, Zwick (2019 QJE) — https://www.nber.org/papers/w25442 ; Cooper et al. (2016) — https://www.nber.org/papers/w21651

AI-specific
- Karger et al. (2026), NBER w35046 — https://www.nber.org/papers/w35046
- PWBM (Sep 2025), *The Projected Impact of Generative AI on Future Productivity Growth* — https://budgetmodel.wharton.upenn.edu/p/2025-09-08-the-projected-impact-of-generative-ai-on-future-productivity-growth/
- CBO, *Understanding Productivity Growth in CBO's Economic Forecast* — https://www.cbo.gov/publication/62564 ; *Budget and Economic Outlook 2026–2036* — https://www.cbo.gov/publication/61882
- Third Way, *How Will AI Impact the Federal Budget?* — https://www.thirdway.org/memo/how-will-ai-impact-the-federal-budget
- Korinek & Lockwood (Brookings), *A public finance framework for the age of AI* — https://www.brookings.edu/articles/future-tax-policy-a-public-finance-framework-for-the-age-of-ai/
- Brookings/TPC (Sep 2026), *AI tax debate misses the threat that's already here* — https://www.brookings.edu/articles/ai-tax-debate-misses-the-threat-thats-already-here/
- TaxProf Blog (Speck, 2026-09-19), *Is the AI Boom Hollowing Out Corporate Tax Receipts?* — https://taxprofblog.aals.org/2026/09/19/is-the-ai-boom-hollowing-out-corporate-tax-receipts/
- Acemoglu, Manera, Restrepo (2020), *Does the US Tax Code Favor Automation?* — https://www.brookings.edu/wp-content/uploads/2020/12/Acemoglu-FINAL-WEB.pdf
- Guerreiro, Rebelo, Teles, *Should Robots Be Taxed?* — https://www.nber.org/system/files/working_papers/w23806/w23806.pdf ; Thuemmel, *Optimal Taxation of Robots* (JEEA 2023) — https://academic.oup.com/jeea/article/21/3/1154/6798383 ; Costinot & Werning, *Robots, Trade, and Luddism* — https://www.nber.org/papers/w25103
