# AI-Fiscal v2.0 — information to gather before building

**Status:** Phase 0 checklist, 2026-09-20. Everything the build plan
(`v2_build_plan.md`) needs that is not already in the repo. Grouped by
what it unblocks. Tick items off here; receipts land in
`config/calibration/` with `_status`/`_source` siblings; decisions land
in `docs/v2_decisions.md`.

Already in hand and **not** on this list: NIPA Z.1 F.3 2024 factor
levels, the κ and CIT-avoidance receipts, Karger Table 19/39 values,
CBO Feb-2026 GDP path and 2030 revenue ratios, the retirement
constants (SOI 1304 + IRA Bulletin + DFA), SOI 2022 line totals, DFA
and SCF top-share holdings, the Tax-Data 2030 vintage on the cluster,
the local Tax-Simulator clone. Rental has an allocation base already
(`other_home`, `re_fund` on the tax-unit file).

---

## 1. Definitions to verify (unblock D1, D3 — the adding-up identity)

| # | What | Where | Why |
|---|---|---|---|
| 1.1 | **Karger et al. w35046 Table 39: exact definition of "labor share"** — numerator (compensation only? plus a proprietors' share?), denominator (GDP, national income, nonfarm business output?), and whether 2025 = 0.555 is a data value or a respondent median | NBER w35046 PDF, Table 39 notes and the survey instrument in the appendix | Decides which NIPA triple (Y, L0, K0) v2 sizes on. Hypothesis to test: (comp + ½ proprietors)/GDP = 0.557 |
| 1.2 | **BLS labor share (nonfarm business)** 2024–2025 value and definition | BLS Productivity and Costs, labor share series | Second candidate if 1.1 is BLS-based |
| 1.3 | **NIPA Table 1.12 full 2024 column**: national income and all components including taxes on production and imports less subsidies, business current transfer payments, current surplus of government enterprises | BEA interactive tables, Table 1.12 | Pins the 13% residual outside L0 + K0_up so D3 can name what it holds fixed |
| 1.4 | **2024 nominal GDP and GDP–national-income bridge** (consumption of fixed capital, statistical discrepancy) | BEA Table 1.7.5 | If D1 chooses a GDP denominator, the bridge from national income to GDP has to be explicit |

## 2. CBO tables to pull (unblock D6, Phase 1 baseline module)

| # | What | Where | Why |
|---|---|---|---|
| 2.1 | **10-Year Economic Projections xlsx, Feb 2026**, income block by calendar year 2025–2036: wages and salaries, domestic economic profits, proprietors' income; check whether rental income, personal interest, personal dividend income are carried | CBO Budget and Economic Outlook 2026–2036 supplementary data (pub 61882) | N4 → N9: baseline-year factor levels from CBO rather than GDP-scaling 2024 NIPA |
| 2.2 | **Revenue Projections by Category**, fiscal years 2025–2036: individual income, payroll, corporate income, other | Same release, revenue supplementary table | N3 validation; replaces the interpolated 3,200 / 470 benchmark rows |
| 2.3 | **Nominal GDP by calendar and fiscal year**, real GDP growth by year | Same release, economic projections | Year-indexed `cbo_baseline.csv`; retires positional `g_2026`/`g_2027plus` |
| 2.4 | **CBO's AI productivity assumption** as stated in the outlook (+0.1pp/yr) and any factor-share statement | Outlook chapter 2; *Understanding Productivity Growth in CBO's Economic Forecast* (pub 62564) | Baseline already contains some AI; document to avoid double-counting against Karger |
| 2.5 | **CBO 59436 method detail** (profits → tax base: the three wedges and their recent magnitudes) — PDF blocked to scripted fetch, download by hand | *How CBO Projects Corporate Income Tax Revenues*, Oct 2023 | Template for splitting the single avoidance scalar (D4) |

## 3. Corporate-side receipts (unblock D4, D7 — Phase 3)

| # | What | Where | Why |
|---|---|---|---|
| 3.1 | **NIPA Table 1.12, 2015–2024**: corporate profits before tax, taxes on corporate income (federal separately, from Table 3.2), profits after tax, net dividends, undistributed profits | BEA Table 1.12 and 3.2 | Payout ratio p and its recent trend; replaces the unverified "≈0.4–0.5" |
| 3.2 | **Buybacks**: net equity issuance or gross repurchases, nonfinancial corporate sector, 2015–2024 | Fed Z.1 Table F.103 (net equity issuance); S&P Dow Jones buyback series as a cross-check | Buyback share b (Q2.2) |
| 3.3 | **S-corp share of BEA corporate profits**, most recent SOI year | IRS SOI Corporation Complete Report, S-corp returns Table 1; SOI Integrated Business Data | Refresh the 0.20 (currently "preliminary") |
| 3.4 | **Federal corporate receipts FY2024–FY2026 monthly**, and CBO's stated attribution of the FY2026 decline | CBO Monthly Budget Review (Sep 2026); Treasury MTS | Evidence base for the time-varying expensing wedge; settles whether the AI-expensing attribution is CBO's or Politico's |
| 3.5 | **Depreciation wedge**: bonus depreciation rules under the 2025 reconciliation act (asset classes, permanence), and JCT/Treasury tax-expenditure estimates for expensing 2026–2030 | JCT tax expenditure list (latest JCX); the act text; CRS summary | `expensing_path` receipt with a vintage date |
| 3.6 | **Effective capital tax rates on software/equipment** post-TCJA and post-2025 act | Acemoglu-Manera-Restrepo (2020) tables; any 2025–2026 update | Lower bound on τ\* for the increment |

## 4. Realization and reconciliation inputs (unblock D5, Phase 4)

| # | What | Where | Why |
|---|---|---|---|
| 4.1 | **SOI Publication 1304 line totals, TY2022 and TY2023**: wages; taxable interest; ordinary and qualified dividends; net capital gains; Schedule C; Schedule E split into partnership/S-corp, **rental real estate**, royalties, estates/trusts; taxable pensions; IRA distributions | SOI Pub 1304 Table 1.4 (TY2023 now published) | Per-channel SOI/NIPA ratios for R1; adds the missing rental and net-dividend benchmark rows |
| 4.2 | **Matching NIPA components for the same years** (dividends received by persons, personal interest income, rental income of persons, proprietors' income) | NIPA Table 2.1 and 7.x | Denominators for the R1 ratios |
| 4.3 | **Historical realized gains / GDP** and CBO's current long-run realization assumption | CBO pub 58914 (Feb 2023) and the Feb-2026 outlook's capital-gains discussion | Annual-concept anchor for r_lt |
| 4.4 | **CRS R41364 (Mar 2026 update)**: the 61% realizations-to-accruals figure and its period | CRS report | Lifetime-concept anchor for r_lt |
| 4.5 | **Tax-Data 2030 vintage aggregates**: `kg_lt`, `div_ord`, `div_pref`, `txbl_int`, `rent`, `scorp_*`, `part_*`, imputed accruals (equities, pass-through, housing) | Cluster run of `11_validation.R` on the current vintage | PUF-side numerators for R1; the 2030 PUF-implied r = 0.16 refresh |
| 4.6 | **Qualified share of dividends** at the unit level (`div_pref/(div_ord+div_pref)`) distribution | Same vintage | Dividend-flow routing in the PUF writer |

## 5. Household allocation keys (Phase 4–5)

| # | What | Where | Why |
|---|---|---|---|
| 5.1 | **Auten-Splinter retained-earnings key** (75% dividends / 25% realized gains) and their corporate-tax key ("wages/corporate ownership") — exact appendix text | AS online appendix (already downloaded to the session scratch; copy the relevant section into the decisions log) | Named sensitivity against the v1.0 wealth-proportional allocator |
| 5.2 | **PSZ / DINA corporate allocation rules** — retained earnings by equity wealth; corporate tax to capital | PSZ 2018 data appendix §; `usdina` code | Same |
| 5.3 | **CIT incidence rules**: OTA 2021 summary (81.5/18.5, supernormal → shareholders), TPC Nunns 2012 (60/20/20), CBO DHI method (75/25 with gains scaled to long-run level) | Already located; extract the allocation *bases* each uses | `distribute_cit_burden()` rules |
| 5.4 | **Does the vintage identify supernormal vs normal capital income?** It does not directly; decide a proxy (equity-derived income vs interest) | Tax-unit file schema | OTA rule needs the split |

## 6. Labor lane (unblock D8, L0–L2)

| # | What | Where | Why |
|---|---|---|---|
| 6.1 | **Tracker team's internal SOC-level exposure/automation/augmentation file**, with construction notes (core/supplemental task weights, OES weighting) | Budget Lab AI labor tracker team — ask | The metric; published workbook is chart data only |
| 6.2 | **Fallbacks**: Eloundou et al. (2023) occupation scores via Brookings; Anthropic Economic Index O\*NET/SOC releases through 2026-06 (CC-BY) | Hugging Face; Brookings data appendix | If 6.1 is unavailable or restricted |
| 6.3 | **CPS ASEC extract** with SOC occupation, age, sex, education, annual earnings, weeks worked, UI receipt — most recent year | IPUMS CPS via the shared `common_ipums_download` machinery | Cell construction and the between/within-cell variance gate (L0) |
| 6.4 | **Tracker's unemployment-duration cuts** of exposure (the four bins) | Tracker team file or the published F-sheets | Duration mixture parameters |
| 6.5 | **Karger Table 39 labor-force participation and unemployment expectations** by scenario, if present | w35046 | Whether the survey itself implies an extensive margin to calibrate π to |

## 7. Reading to finish (no data, but blocks decisions)

| # | What | Unblocks |
|---|---|---|
| 7.1 | CBO *Projection and Alignment Methods for Static Microsimulation Models* (Perese 2016) — whether the NIPA-to-SOI ratios by income type are listed | D5 method, R1 |
| 7.2 | CBO 59436 in full (see 2.5) | D4 |
| 7.3 | Doorley et al. (2023) §3–4 method — cell definition, mapping to micro, EUROMOD hand-off | L1–L2 design |
| 7.4 | PWBM Tax Module documentation on entity-form choice | Whether κ can be modeled rather than fixed |
| 7.5 | Kaymak-Schott (2023) mechanism section | Q3.4 wording in the methodology |
| 7.6 | IMF SDN 2024/002 Annex 1 model | Framing of static-vs-GE limits (Q5.3) |

## 8. People to ask

| Who | For |
|---|---|
| Tracker team (Budget Lab) | 6.1, 6.4; whether AI-Fiscal may reuse the SOC file and under what citation |
| PUF–SCF / Tax-Data team | 4.5, 4.6; whether a future vintage can carry a real-estate *income* base beyond `other_home`/`re_fund`; whether `ui` will ever be split by earner |
| Tax-Simulator maintainers | Confirmation that `revenues_corp_tax` stays a CBO pass-through (tripwire assumption); whether `trad_contr_er1` should be zeroed with wages in an extensive template |
| Co-author (Ryan Nunn) | Sign-off on D1–D8 before Phase 1 code |

---

## Order of attack

Week 1: 1.1–1.4, 2.1–2.3, 3.1 (all desk pulls) → draft D1, D3, D6, D7.
Week 2: 3.2–3.6, 4.1–4.4, 7.1–7.2 → draft D4, D5. Send the two
asks in §8 on day one so 6.1 and 4.5 arrive in time for L0 and Phase 4.
