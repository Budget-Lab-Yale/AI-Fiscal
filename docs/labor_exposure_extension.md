# AI-exposure labor shocks — extension proposal

**Status:** Proposal for review, 2026-08-11. Nothing implemented. Labor
side only, severable from the v2 capital re-architecture and shippable
against v1.0; when v2 lands it becomes lane P3 and this doc is that
lane's authoritative source. Companion: `v2_architecture.md` §5.

## Why

v1.0 moves labor income on the **intensive margin only** — every unit
keeps its job and its labor income scales by one per-unit ratio (S0
proportional, S2/S3 compress/expand by income rank).
`ai_fiscal_methodology.md:237-239` says it outright: "employment is held
constant."

That forfeits the most interesting fiscal content, because the tax and
transfer schedule is nonlinear exactly where job loss bites: payroll tax
collapses to zero on a lost job, and EITC/ACTC swing across phase-in and
phase-out kinks. No calibration of a smooth proportional wage cut
reproduces that. Three pieces are needed — an extensive margin, an
exposure-based way to target it, and a position on what "job loss" means
over a tax year.

## 1. The extensive margin

**Recommendation: deterministic weight-splitting.** Split each unit's
weight into an employed part `w·(1−π(e_i))` and a displaced part
`w·π(e_i)`, with `π` increasing in exposure `e_i`; the displaced row
takes the job-loss treatment of §3.

This beats shading `y_l` down by expected loss on two counts. Because
the tax function is nonlinear, `E[T(y)] ≠ T(E[y])`: shading everyone's
earnings *is* the intensive margin, and it smooths away the very
kink-crossing that motivates the exercise. And determinism keeps Monte
Carlo noise out of the LO/CO decomposition, where across 54 scenarios it
would land in the interaction residual and be absorbed silently. The
stochastic alternative has an in-repo precedent — Tax-Simulator's
`behavior/employment/bastian.R` draws per record — and would make
`set.seed(globals$random_seed)` mandatory. Weight-splitting costs growing
row counts, so the aggregate identity and per-unit tests must be
restated over post-split weights, and ID/runscript plumbing in
`06_build_counterfactual.R` needs revisiting.

Three blockers in today's Step A (`03_shock_labor.R`), all cheap to fix,
none optional:

- **`y_l == 0` is an inert third class.** The partition at `:57-58` is
  `pos` and `neg`; zero is in neither and is never written. Displaced
  units land there permanently, so re-employment and mixed margins are
  inexpressible until the contract is redefined.
- **The positive-subset guard at `:59-70` becomes binding.** Its comment
  notes it is latent only because the grid is expansionary. Displacement
  is contractionary: it shrinks `y0_l_pos` while `y1_l_pos` must still
  be hit.
- **The `uniroot` call is fragile.** `:119-123` brackets the new log-mean
  on `[-10, 10]` when `mu0 ≈ log(30000) ≈ 10.3`, so `extendInt = "yes"`
  carries every call today.

Free opportunity: `wages1`/`wages2` are already split by earner, so
displacing one spouse in a joint unit needs no new data.

## 2. Exposure metric and the CPS→PUF mapping

**Source it from the tracker team's internal SOC-level file.** The
workbook published with
[Tracking the Impact of AI on the Labor Market](https://budgetlab.yale.edu/research/tracking-impact-ai-labor-market)
is chart data only (sheets `F1`–`F18`, one per figure), so the
occupation-level scores are not public. Reuse is the cheapest path and
the only way AI-Fiscal and the tracker share one exposure definition.
Fallback: Eloundou et al. (2023) via Brookings plus the Anthropic
Economic Index on Hugging Face (CC-BY, O*NET/SOC releases through
2026-06-26).

The tracker carries two measures and deliberately keeps them apart:
**exposure** (Eloundou — theoretical, share of tasks a model could do)
and **usage** split into **automation** vs **augmentation** (Anthropic —
present-focused, ~1M conversations mapped to O*NET tasks), aggregated
core-task weight 1 / supplemental 0.5, collapsed to SOC and
OES-employment weighted. **Take a position: automation share is the
displacement-relevant measure, exposure is the intensive-margin
measure.** Augmentation should not drive job loss. Carry both as a
sensitivity axis, not blended into one index.

The cell universe is tightly constrained. The tax-unit file has
`age1`/`age2`, `male1`/`male2`, `filing_status`, `n_dep`/`n_dep_eitc`,
wage rank, and a self-employed-vs-wage-earner split. It has **no**
occupation, industry, education, hours, weeks, employment status, or
region — so on the PUF every metric collapses to a function of those
columns.

**Gate the element on one diagnostic before writing code.** On CPS,
decompose occupation-level exposure variance into between-cell and
within-cell components. If the between-cell share is small, `EXPocc`
collapses toward the income-rank metric already shipping as S2/S3 and
the CPS machinery is not worth building. Decisive, roughly a day's work.

Two data notes. The tracker uses monthly basic CPS, but cell
construction wants annual earnings comparable to the PUF's wage concept,
so **ASEC is the better merge substrate** — cross-check the result
against the tracker's series. And CPS topcoding at high wages is where
the PUF is stronger, so blend gradients only to the CPS-reliable range.
Output artifact: a committed cell-exposure CSV under `config/` with
`_status`/`_source` siblings, plus a `config/calibration/` receipt.

## 3. What job loss means fiscally

The tracker supplies an anchor rather than a guess: it already cuts
exposure and automation **by unemployment duration** (<5, 5–14, 15–26,
27+ weeks), which is the natural parameterization of permanent versus
temporary.

- **(a) Permanent displacement / labor-force exit.** Earnings → 0 for the
  year; payroll tax → 0; EITC and ACTC collapse. Needs no UI and no
  duration distribution — the **minimum viable first cut**.
- **(b) Temporary unemployment.** Earnings scaled to a weeks-worked
  fraction plus UI for part of the year. UI is federally taxable, so it
  partially offsets the loss — a different fiscal path, not a scaled (a).
- **(c) A higher steady-state unemployment rate.** A level shift rather
  than its own mechanism; cleanest as a duration mixture.
- **(d) Mixture — recommended general form.** An exposure-tilted
  distribution over the four bins, mapping duration → (fraction of year
  employed, UI weeks, UI amount). (a) is the 52-week tail and (b) the
  interior; report (a) and pure-intensive as bounding sensitivities.

What the calculator will and will not do — this **corrects
`v2_architecture.md` §5.3**, which expects SNAP to respond. `ui` exists
on the tax-unit file, is fully taxable with no exclusion parameter,
enters AGI, and raises the taxable share of Social Security; it passes
through `build_counterfactual()` untouched today, so a UI module needs
one mutation and no new plumbing. EITC and CTC/ACTC respond endogenously
off earned income (`ei = wages + se`), with one subtlety — the EITC
prior-year lookback switches off when current earnings hit zero.
`gross_ss` is gross only (no `txbl_ss`), so SS taxability responds for
free. But **ACA premium tax credits are an exogenous pass-through and
SNAP is not modeled at all**: the transfer-side response is EITC, CTC,
and SS taxability, nothing else.

## Decisions to settle before coding

1. **The aggregate target versus pure loss** — this blocks everything and
   sharpens `v2_architecture.md` Q3.1 into something decidable.
   `Y_1^L = Y_0^L·(1+g_L)` is *given* by the Karger share path, so we
   cannot have both "displaced income is a pure loss" and the existing
   target: displacement must be offset by a survivor wage adjustment to
   hit `Y_1^L`, i.e. displaced income is implicitly reallocated to
   survivors. Either relax the target and reconcile the share identity
   elsewhere, or accept reallocation and document it.
2. **UI accounting.** UI is a transfer, not factor income — keep it out
   of the `sum(w·y_l1) = Y_1^L` identity and give it its own column in
   `write_factor_channels()`, which today emits only `id`, `dL_unit`,
   `X_gross_unit`, `dY_factor_unit`.
3. **Selection.** Weight-splitting versus per-record draws, and whether
   `π` is calibrated to a displacement mass or an unemployment-rate path.

## Sequencing

- **Phase 0 — gate, no code.** Variance decomposition; confirm cell
  columns on a real vintage; settle decision 1.
- **Phase 1.** Extensive-margin machinery with uniform exposure and
  permanent job loss — plumbing end to end with no new data. Introduce
  `check_labor_contract()`, which `v2_architecture.md` references but
  which does not exist.
- **Phase 2.** Exposure metric plumbed in from the cell CSV; register the
  new code in `.AXIS_LABOR` and update the six consumers named in
  `00_utils.R:135-138`.
- **Phase 3.** Duration mixture plus UI.
- **Phase 4.** Grid integration, sensitivity axes, figures.

**Naming guard:** do not reuse `S1` — it belongs to the archived
development tree's different construction. Use `EXPu`/`EXPy`/`EXPocc` ×
`INT`/`EXT`/`MIX` per `v2_architecture.md` §5.4.

## Risks

Grid explosion (keep a headline grid plus named sensitivity runs, not
every axis crossed); refundable-credit volatility, making labor-side
output far more sensitive than today's — realistic but harder to explain;
the PUF resolution ceiling, which Phase 0 measures; row-count churn from
weight-splitting; and the dependency on the tracker team's file.

One side benefit: `15_blsmm_debt_gdp.R:16` already flags that the
debt/GDP tie-in omits displaced-worker outlays, understating fiscal cost.
This partially closes that gap.

---

## Appendix — verified implementation constraints

Checked against AI-Fiscal `main` at `53a92aa` and the local
Tax-Simulator clone on branch `state-tax` at `ab45a6661` (2026-08-02).

- `rho_i` (`06_build_counterfactual.R:187`) is a single scalar applied to
  the 20 columns in `.labor_scale_cols` (`:27-34`) plus 8 reconstructed
  passthrough columns via `.update_passthrough` (`:39-45`).
  Self-employment and K-1 labor are **not** scaled separately.
- **Zeroing `wages1` is not enough to zero payroll tax.** `pr.R:118`
  computes
  `gross_wages1 = wages1 + trad_contr_er1 − tips1·exempt − ot1·exempt`,
  so the employer deferral stays in the FICA base. Tax-Simulator's own
  extensive-margin template (`do_taxes.R:544-553`) zeroes
  `wages1`/`tips1`/`ot1` and decrements the unit totals but does **not**
  touch `trad_contr_er1` — a starting point, not a complete recipe.
- `wagebill_sole_prop`/`_part`/`_scorp` (the §199A W-2 wage-bill
  limitation inputs) are not scaled, so a labor shock leaves the QBI
  limitation at baseline.
- Tax-Simulator's non-baseline wage gross-up (`do_taxes.R:48-62`, 85%
  fringe) is guarded by `wages1 != 0`: fully zeroed records pass through
  untouched, but *reduced* records get re-scaled. Matters for the
  partial-year treatment in (b)/(d).
- Units with `wages > 0` but `y_l ≤ 0` (passthrough losses) are invisible
  to any displacement rule keyed on `y_l`.
- The Step A aggregate identity is enforced by construction, not
  assertion: S0 is algebraic via `rho_pos` (`:104` — note
  `rho_pos ≠ rho`, the attribute value), S2/S3 is `uniroot` plus a hard
  renormalization at `:129-130`.
- `ui` is tax-unit-level with no `ui1`/`ui2`, so there is no per-earner
  allocation when one spouse in a joint unit loses a job.
- `10_figures.R:50-60` already reserves an unreachable `AI-exposure`
  entry in `PAL_LABOR` and `PAL_LABOR_SHAPE`, so the figure suite accepts
  a fourth labor code as soon as one is registered. Its comment at
  `:48-49` points at `v2_architecture.md` §3; the CPS-cell sketch is now
  §5.
