# Erratum: "How potential AI futures would play out in the current tax system" (model v1.0.1)

*DRAFT for review, 2026-10-05. Not yet published.*

## Public note

We have corrected two input errors in the model behind our July 2026
report, ["How potential AI futures would play out in the current tax system"](https://budgetlab.yale.edu/research/how-potential-ai-futures-would-play-out-current-tax-system).
The report's qualitative conclusions are unchanged. Faster AI adoption
still raises federal revenue, and inequality assumptions still drive the
distributional results. However, the estimated revenue gain under the
Moderate and Rapid scenarios is larger than we reported, and labor
income no longer falls under the Rapid scenario.

**1. Survey respondent group for the labor share.** Our AI scenarios
are calibrated to the expert survey in Karger et al. (2026, NBER
w35046). We described the inputs as the economists' forecasts, and the
GDP growth rates (2.0, 2.6 and 3.3 percent a year for Slow, Moderate
and Rapid) are the economists' medians. The 2030 labor shares we used
(55.0, 53.8 and 51.3 percent), however, were the medians across all
respondent groups. The economists' medians are 55.0, 54.0 and 52.0
percent. We now use the economists' forecasts for both inputs. The
Slow scenario is unaffected, because both groups give 55.0 percent.

**2. Rounding in the CBO baseline.** We sized CBO's projected fiscal
2030 corporate income tax and total revenue from the rounded shares of
GDP printed in CBO's report (1.3 and 17.7 percent). We now use the
unrounded figures from CBO's data supplement: $477 billion (1.28
percent of GDP) and $6,595 billion (17.64 percent). This overstated
our estimate of the change in corporate tax revenue by 1.8 percent in
every scenario.

**What changed.** Change in federal revenue in fiscal 2030, in billions
of dollars, for the scenarios where AI shifts income from labor to
capital and labor income grows proportionally:

| Scenario | Published | Corrected |
|---|---|---|
| Slow | 8.2 | 8.0 |
| Moderate | 105.2 | 113.3 |
| Rapid | 170.7 | 200.8 |

- **Rapid labor income.** Aggregate labor income in the Rapid scenario
  now rises 0.4 percent over the five years instead of falling 0.9
  percent. Revenue from labor income therefore rises by $15.6 billion
  instead of falling by $36.0 billion. Payroll tax revenue rises rather
  than falls.
- **Revenue relative to GDP.** Revenue still falls as a share of GDP
  in every scenario, but by less: by 0.68 percentage points rather than
  0.76 points in Rapid, and by 0.32 rather than 0.34 points in Moderate.
- **Inequality.** The rise in the Gini coefficient under Rapid is
  about 15 percent smaller (0.0049 rather than 0.0057, after tax).
- **Debt.** The projected 2030 debt-to-GDP improvement in Rapid is
  slightly larger: 7.3 rather than 7.1 percentage points.
- **Unchanged.** Fixed-share scenarios change by less than $1 billion
  (only through the CBO rounding).

Corrected figures, tables and data are posted with model version 1.0.1
at github.com/Budget-Lab-Yale/AI-Fiscal. The repository also includes
the full results with and without each correction.

---

## Internal appendix: exhibit-by-exhibit changes

Source for every number below:
`results/erratum_v1.0.1/comparison/paper_exhibits_2030.csv` (keyed by
exhibit sheet, row and column, with the effect of each correction).
`$B` = billions of dollars, fiscal 2030. "Karger" is correction 1 and
"CBO" is correction 2.

**Table 1 (key parameters).**
- 2030 labor share: Moderate 53.8% → 54.0%, Rapid 51.3% → 52.0%.
- Capital share: 46.2% → 46.0% (Moderate), 48.7% → 48.0% (Rapid).
- Capital growth bump g_K (cumulative capital-income growth above the
  CBO baseline): 7.54% → 7.08% (Moderate), 17.28% → 15.60% (Rapid).
- Labor growth bump g_L: +0.41% → +0.78% (Moderate), **−0.94% → +0.41%**
  (Rapid).
- Unchanged: the GDP rows and the λ rows, the slope of the
  labor-income redistribution in the compressive and expansive labor
  scenarios.

**Figure 1 (headline revenue, reallocate cells).** All nine bars move.
- Slow: −$0.15B each (CBO).
- Moderate: +$8.1B (Karger +8.7, CBO −0.7), e.g. 105.2 → 113.3.
- Rapid: +$30B (Karger +31.4, CBO −1.5), e.g. 170.7 → 200.8 (S0),
  131.7 → 161.5 (S2), 216.0 → 246.3 (S3).
- The title still holds: revenue rises with adoption speed and with
  labor-income inequality.

**Figure 2 (revenue by type of income).**
- Labor bars: Moderate +$14.3B; Rapid +$51.6B. Two signs flip:
  Moderate-Compressive −4.5 → +9.7, and Rapid-Proportional −36.0 → +15.6.
- Capital bars: Moderate 52.7 → 49.4; Rapid 122.9 → 110.7.
- Corporate (macro CIT) bars: Moderate 36.7 → 33.8; Rapid 84.0 → 74.4;
  Slow 8.4 → 8.2.
- **The title needs revisiting.** "Capital and corporate revenue
  increases offset labor revenue losses in most scenarios": labor
  revenue now falls in 4 of the 9 reallocate scenarios (the three Slow
  scenarios and Rapid-Compressive), down from 6 of 9. Revised title:
  "Capital and corporate revenue gains drive the increase; labor
  revenue falls mainly under slow adoption."

**Figure 3 (by instrument).** In Rapid-Proportional, three signs flip:
- payroll tax −$11.3B → +$4.9B;
- refundable-credit outlays +$0.9B → −$0.7B;
- individual income tax 99.0 → 120.7.

In Rapid-Compressive, individual income tax goes from −$1.4B to
+$19.3B. The macro CIT bars move as in Figure 2.

**Figure 4 (revenue vs gross factor income expansion).**
- Gross factor income expansion: Moderate 404 → 442; Rapid 633 → 767 ($B).
- Microsimulation revenue: Moderate 68.5 → 79.5; Rapid-Proportional
  86.8 → 126.3.

**Figure 5 (reallocate vs fixed shares).**
- Reallocate bars: as in Figure 1.
- Fixed-share bars: down $0.05–0.63B (CBO only).
- The title still holds.

**Figure 6 (Gini).**
- Moderate reallocate: each Gini change is about 0.0002 lower.
- Rapid reallocate: about 0.0008 lower; Proportional 0.0057 → 0.0049
  after tax.
- Fixed-share and Slow: unchanged. The title still holds.

**Figure 7 (change in average tax rate by decile, Moderate,
proportional).**
- Deciles 2–10 each rise 0.016–0.033 pp more than published, e.g. the
  top decile goes from +0.108 to +0.127 pp.
- The bottom decile's change is slightly more negative (−0.019 →
  −0.027 pp).
- The title still holds, and the pattern is strengthened.

**Appendix figures.**
- A1 (GDP growth history): unchanged; the scenario GDP rates are the
  same.
- A2 (labor-share history): the Moderate and Rapid reference lines move
  to 54.0% and 52.0%. The historical series is unchanged: A1 and A2 use
  the FRED data as of publication (2026-07-09 vintage), so the 2026
  point is still the first-quarter value (53.7%), now labelled
  year-to-date.
- A3 (revenue vs income): moves as in Figures 1–4.
- A4 (debt-to-GDP change, Budget Lab Small Macro Model): Rapid-Proportional
  −7.07 → −7.31 pp; Moderate-Proportional −3.61 → −3.68 pp; fixed-share
  cells move by less than 0.01 pp.

**Text to check against the published page.** Any sentence that says:
- labor income or payroll tax revenue falls under Rapid;
- quotes $105 billion (Moderate) or $171 billion (Rapid);
- quotes the 53.8% / 51.3% labor shares;
- describes the labor-share inputs as the economists' forecasts while
  quoting the pooled values.

**Other corrections to fold into the web methodology (no change to
results).**
- **V1-7:** the sign of the GDP-denominator term in the displayed
  revenue-share formula.
- **The baseline description:** "CBO no-AI baseline" should read "CBO
  baseline", because CBO's baseline already embeds +0.1 percentage point
  a year of AI-driven total factor productivity growth.

**Release steps remaining (V1-8 step 6).**
- Tag `v1.0.1`.
- Bump `CITATION.cff` to 1.0.1 and add the release date.
- Attach the publishable xlsx bundle, `paper_figure_data_2030.xlsx` and
  the figure PNGs to the GitHub release.
- Merge `v1.0.1-erratum` to `main`.
