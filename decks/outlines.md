# Deck outlines — corrected Version 1 and Version 1.2

Draft 2, 2026-10-29. External audience. Chart data for each slide is in
`decks/<deck>/data/` (file names start with the slide number), built by
`decks/build_deck_data.R`; see `decks/README.md`. Both decks on Budget Lab Template A (16:9).
**Titles are John's**: fill in each `Title:` line (left blank on purpose). Edit freely;
cut or add slides. Numbers are from the runs named in each section and are $ billions
unless noted.

Terms used below:
- *Labor share falls*: Karger's nonfarm-business labor share decline is applied.
  *Shares fixed*: the same extra growth, split between labor and capital as today.
- *Proportional / compressive / expansive*: how a change in total labor income is spread
  across workers (same percentage for everyone / narrows the distribution / widens it).
- `g_y`: how much higher GDP is under the AI scenario than in CBO's baseline.
  `g_k`, `g_l`: the same for capital income and labor income.
- `X`: the AI-driven change in capital income received by households.

Methodology in both decks is a from-scratch series. How the version differs from the
previous one is in the appendix only, linked from the methodology section's last slide.

---

## Deck 1 — Corrected Version 1 (FY2030)

Run: `results/runs/v1_0_1_corrected-202610290913`. Bridge from v1.0.1: the four
`v1_0_1_fix*` runs.

### Main

1. **Title slide.** Title:
2. **The question and the answer in one slide.** AI may raise output and shift income
   from workers to owners of capital; what does that do to federal revenue in FY2030?
   Headline number with the range. Title:
3. **Results: revenue change by scenario.** Grouped bars, FY2030, proportional rule.
   Labor share falls: Slow −5.1, Moderate 114.7, Rapid 205.3.
   Shares fixed: 23.8, 203.7, 420.2. Title:

**Methodology (from scratch)**

4. **How the model works.** Diagram: scenarios → GDP and the labor/capital split →
   household incomes on tax returns → Budget Lab Tax-Simulator (current law) → revenue,
   plus the corporate tax on top. Title:
5. **The scenarios.** Karger et al. (2026), survey of economists: annual GDP growth
   2025–2030 of 2.0 / 2.6 / 3.3% (Slow / Moderate / Rapid) and a 2030 nonfarm-business
   labor share of 55.0 / 54.0 / 52.0%, against 55.5% in 2025. Dot plot. Title:
6. **From scenarios to income growth.** GDP above CBO's baseline path in 2030 (`g_y`) and
   how it splits: Moderate `g_y` +3.4%, capital income `g_k` +6.9%, labor income `g_l`
   +0.6% with the labor share falling; +3.4% for both with shares fixed. Small bars. Title:
7. **Labor income.** Wages and the labor part of business income grow at `g_l`; the three
   rules for spreading it across workers. Illustrative chart of the three rules. Title:
8. **Capital income: who receives it.** `X` = `g_k` × capital income on tax returns
   (Moderate ≈ $311B). Shared out in proportion to financial and investment wealth
   (equities, bonds, business equity, retirement accounts, investment real estate,
   trusts and other financial assets; not the primary home, cash or vehicles). Title:
9. **Capital income: what form it takes.** Equities → 30% dividends, 70% capital gains;
   business equity → pass-through income; retirement accounts → pension and IRA
   distributions; interest stays on its baseline path. Stacked bar of `X` by type. Title:
10. **The corporate tax.** Grows at the same rate as household capital income: CBO's
    FY2030 corporate receipts ($477B) × `g_k`. Moderate +32.9. Title:
11. **Scoring and fiscal years.** Tax-Simulator scores tax years 2029 and 2030; fiscal
    year 2030 receipts blend them (about 26% / 74%). Debt via the Budget Lab Small Macro
    Model. Title:
12. **What the model does not do.** No behavioral responses, no general equilibrium,
    shock sized on income reported on tax returns. Text. Link → appendix A1. Title:

**Results (continued)**

13. **By tax.** Stacked bars, labor share falls: Moderate income 72.1, payroll 8.8,
    corporate 32.9; Rapid 128.1, 3.3, 73.5. Title:
14. **Why the labor share matters.** Labor share falls vs fixed, all three scenarios.
    Title:
15. **How labor gains are spread.** Moderate, labor share falls: proportional 114.7,
    compressive 89.3, expansive 141.8. Dot plot. Title:
16. **Relative to GDP, and debt.** Revenue/GDP change (Moderate −0.24 pp, labor share
    falls) and 2030 debt/GDP vs baseline (Moderate −3.8 pp). Two charts. Title:
17. **Distribution.** After-tax Gini change: Moderate +0.0024, Rapid +0.0056. Title:
18. **Takeaways.** Text. Title:

### Appendix

- A1. **Corrections to v1.0.1** (linked from slide 12): waterfall, Moderate labor share
  falls, 113.3 → 104.8 (calendar-year CBO growth) → 116.5 (fiscal-year blend) → 115.5
  (households with no financial assets) → 114.7 (allocation base and interest); one line
  on each fix; bridge for all cells.
- A2. Full 18-cell revenue grid (table, built in PowerPoint).
- A3. Parameters and sources.
- A4. Revenue decomposition: labor-only, capital-only, interaction.

---

## Deck 2 — Version 1.2 (FY2027–2036)

Run: `results/runs/v1_2_reference-202610282217`; sensitivities in the
`v1_2_sens_*-20261028*/29*` runs.

### Main

1. **Title slide.** Title:
2. **The question and the answer in one slide.** Ten-year revenue effect with the range.
   Title:
3. **Results: the annual path.** Lines by scenario, FY2026–2036, labor share falls,
   FY2026 marked as the nowcast year. Title:
4. **Results: ten-year totals.** Bars: Slow −32, Moderate 1,260, Rapid 2,364 (labor
   share falls); shares fixed 200, 1,982, 4,122. Title:

**Methodology (from scratch)**

5. **How the model works.** Same diagram as Deck 1, run every year 2025–2036. Title:
6. **The scenarios as annual paths.** Karger's 2025–2030 growth and labor share, then
   after 2030 the gap to CBO's baseline is held (alternatives on slide 15). Chart of `g_y`
   and the labor share by year. Note: Slow starts slightly below CBO's baseline. Title:
7. **Where the shock lands.** The labor-share change and the extra growth happen in
   nonfarm business (77% of GDP); government, households and nonprofits keep their
   income and labor share (53%). Economy-wide: Moderate `g_k` +6.1%, `g_l` +1.2% in 2030.
   Title:
8. **Labor income.** As Deck 1, applied each year. Title:
9. **Capital income: who receives it and in what form.** As Deck 1; interest on its
   baseline path; households with no financial assets receive none; a year where AI
   capital income is below baseline lowers everyone's capital income by the same
   percentage. Title:
10. **The corporate tax.** CBO's corporate receipts each year × `g_k`. Title:
11. **Scoring.** Tax-Simulator over tax years 2025–2036; FY2026 nowcast, FY2027–2036
    window; CBO's February 2026 budget path for every year. Title:
12. **Checking the scale against national income.** GDP → labor, capital, rest of GDP;
    how much of the national-accounts increment reaches tax returns (Moderate 2030:
    $273B of $715B profit-type income). Title:
13. **What the model does not do.** Text. Link → appendix B1. Title:

**Results (continued)**

14. **By tax over the window.** Moderate: income 811, payroll 168, corporate 267. Title:
15. **After 2030.** Hold the gap / interpolate to Karger's 2050 values / continue
    2025–2030 growth. Moderate FY2036: 173 / 506 / 571; ten-year totals 1,260 / 2,313 /
    2,525. The largest uncertainty. Title:
16. **Other sensitivities.** Moderate ten-year totals: reference 1,260; concentrated
    ownership 1,269; with in-year realization of AI gains at 0.75 / 0.5 / 0.25:
    1,239 / 1,209 / 1,179; deferred retirement 1,112. Dot plot. Title:
17. **How labor gains are spread.** Moderate ten-year: compressive 1,016, proportional
    1,260, expansive 1,517. Title:
18. **Early evidence: inputs.** Labor share −3.2% (first half 2026 vs 2025) against paths
    of −0.2 to −1.3%; real GDP +2.4% against CBO 2.36% and paths 2.0–3.3%. Title:
19. **Early evidence: FY2026 receipts.** Actual minus CBO projection (income +94, payroll
    −14, corporate −23) next to the model's FY2026 nowcast; mostly not AI. Title:
20. **Distribution.** After-tax Gini change by year, labor share falls: Moderate
    +0.0004 (FY2026) rising to +0.0020 by FY2030 and holding (+0.0021 in FY2036); Rapid
    +0.0008 to +0.0046 (+0.0047); Slow +0.0001 to +0.0005. Shares fixed: Moderate
    +0.0009 in FY2036. Lines. Title:
21. **Takeaways.** Title:

### Appendix

- B1. **Changes from Version 1** (linked from slide 13): FY2030 bridge from corrected
  Version 1, Moderate 114.7 → 133.8 (the nonfarm-business bridge); Rapid +44.3; list of
  what else is new (annual window, retirement and allocation choices).
- B2. Karger inputs: 2030 and 2050 values (Tables 19, 20, 39, 40).
- B3. National-income reconciliation table.
- B4. Full window-totals table (table, built in PowerPoint).
- B5. Parameters and sources.
- B6. Retirement and realization assumptions.
