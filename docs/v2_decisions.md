# AI-Fiscal v2.0 — decisions log

**Status:** opened 2026-09-21, Phase 0 in progress. Nothing is SET yet.

Principle 2 of [`v2_build_plan.md`](v2_build_plan.md): *every node tagged
`decision` in the flow network gets a numbered entry here before the code
that depends on it is written.* Phase 0's exit gate is **D1–D8 written**
(build plan §"Phase 0", steps 0.2–0.9). This file is that gate.

Companion docs — read in this order when picking up a decision:

- [`v2_flow_network.md`](v2_flow_network.md) §7 — the shape-changing
  decisions and which nodes each one moves. Node registry in §5.
- [`v2_architecture.md`](v2_architecture.md) §11 — the full open-question
  list (Q1.1–Q3.4) these D-numbers draw from.
- [`v2_data_gathering.md`](v2_data_gathering.md) — the pull that unblocks
  each decision, by row number.
- [`labor_exposure_extension.md`](labor_exposure_extension.md) §"Decisions
  to settle" — the labor lane's own three.

## How to use this file

**Status vocabulary.** `OPEN` (question posed, no lead), `PROPOSED` (a
default is written down and is the one to argue against), `SET` (chosen —
records the date, the option, and the receipt).

**Setting a decision** means four things, not one: flip the status here
with a date; land or update the receipt in `config/calibration/` with its
`_status`/`_source` siblings; update every node listed under *Moves*; and
add the yaml leaf if the choice introduces a parameter. A number here
that has no receipt behind it is not SET, whatever this file says.

**Numbering.** D1–D8 are the Phase 0 gate. Deferred questions in §2 get
the next free number when their phase starts. **Next free number: D9.**

---

## 1. Phase 0 decisions (the exit gate)

### D1 — Share-definition bridge

**Nodes:** N13, N16 · **Question:** Q1.2 · **Build plan:** 0.2 ·
**Status: OPEN**

Which NIPA triple `(Y, L0, K0)` does v2 size the shock on? v1.0 derives
`g_K` from the share shift on the *realized* base; the same θ arithmetic
on the NIPA base needs Karger Table 39's "labor share" (0.555) to mean
something in NIPA terms, and it does not match compensation over national
income (15,227 / 24,473 = 0.622).

**Lead (hypothesis, not verified):** `(comp + ½·proprietors)/GDP` for
2024 = (15,227 + 1,018) / 29,185 ≈ 0.557 against Karger's 0.555. This
ratio was derived while writing the flow network — it has *not* been
checked against the Table 39 definition, and the agreement may be
coincidence.

**Unblocked by:** data-gathering 1.1 (Table 39 notes + survey instrument
— numerator, denominator, and whether 0.555 is a data value or a
respondent median), with 1.2 (BLS nonfarm-business labor share) as the
fallback candidate and 1.4 (GDP ↔ national-income bridge) if a GDP
denominator wins.

**Moves:** whether `ΔΠ + ΔL = g_y·Y0` closes at all. Feeds D3 directly —
decide D1 first.

---

### D2 — The upstream capital base

**Nodes:** N7, N18 · **Question:** Q1.1 · **Build plan:** 0.3 ·
**Status: OPEN**

Broad NIPA capital income ($6,046B) or business-only ($4,777B)? Rental
(17.7% of the base) and net interest (3.3%) either belong in the shock or
they don't.

**Coupling to watch:** keeping rental in obliges the Phase 4 PUF writer
to gain a `rent`/`rent_loss` channel. Flow-network gap #2: the tax-unit
file carries those columns but `06_build_counterfactual.R` never writes
them and `asset_to_income_map.csv` has no rental asset class, so the
17.7% channel is dead on arrival unless D2 drops it or 4.5 builds the
writer. Rental does already have an allocation base (`other_home`,
`re_fund`).

**Moves:** `ΔΠ` by −21%; whether the P4 writer is needed at all.

---

### D3 — Adding-up residual policy

**Node:** N16 · **Question:** Q1.2 (the half Q1.2 doesn't cover) ·
**Build plan:** 0.4 · **Status: OPEN**

`resid = g_y·Y0 − ΔΠ − ΔL` is zero only if `L0 + K0_up = Y0` in the same
accounting. On NIPA 2024 it isn't: L0/NI = 0.622, K0_up/NI = 0.247,
leaving a 13.1% residual (taxes on production and imports less subsidies,
business current transfer payments, current surplus of government
enterprises). Given D1, is that residual held fixed, scaled with `g_y`,
or absorbed into the shocked factors?

**Borrow:** Peichl (2009) — enforce the identity at the interface rather
than letting it fail silently downstream.

**Unblocked by:** data-gathering 1.3 (full NIPA Table 1.12 2024 column,
so D3 can *name* what it holds fixed).

**Moves:** the assertion at the N11/N14/N15 interface, and whether v2 can
claim an adding-up identity at all. **Decide jointly with D8** — same
question on the labor side.

---

### D4 — τ\* on the AI capital increment

**Node:** N19 · **Question:** Q2.1 · **Build plan:** 0.5 ·
**Status: OPEN**

Baseline average effective rate (0.147), statutory (0.21, if AI profits
are newer and less sheltered), or a time-varying depreciation wedge for
the build-out years?

**Bounds and evidence:** bounded below by Acemoglu-Manera-Restrepo's
5–10% effective rate on software and equipment (data-gathering 3.6).
FY2026 federal corporate receipts fell ~25% year-over-year with AI capex
expensing named as a driver — which makes τ\* on the increment
time-varying rather than a scalar, and is the strongest argument for the
wedge option. Settle whose attribution that is (CBO's or a press
reading) via 3.4 before leaning on it.

**Borrow:** CBO 59436's three-wedge decomposition (profits → tax base) as
the template for splitting today's single avoidance scalar; 3.5 for the
2025 reconciliation act's bonus-depreciation rules and the JCT expensing
estimates, which would become an `expensing_path` receipt with a vintage
date.

**Moves:** `ΔR_CIT` by ~40%. Retires the v1.0 `09` macro-CIT wedge and
flips the zero-delta tripwire at `09_tables_figures.R:227`.

---

### D5 — Reconciliation policy, per channel

**Node:** R1 · **Question:** Q1.3 · **Build plan:** 0.6 ·
**Status: PROPOSED**

For each channel: `flow_PUF = flow_NIPA` (benchmark), or
`flow_PUF = flow_NIPA · PUF0/NIPA0` (inherit), or a hybrid.

**Proposal:** the historical SOI-line-to-NIPA-component ratio — i.e.
CBO's own individual-side method (see
[`lit_macro_to_micro_structures.md`](lit_macro_to_micro_structures.md)).
Argue against this one rather than starting from scratch.

**Unblocked by:** data-gathering 4.1 (SOI Pub 1304 line totals, TY2022
and TY2023 — Table 1.4 now has TY2023, and it adds the missing rental and
net-dividend benchmark rows), 4.2 (matching NIPA components), 4.5
(Tax-Data 2030 vintage aggregates from a cluster run of
`11_validation.R`).

**Moves:** the level of *every* PUF delta v2 writes.

---

### D6 — N9 baseline-level method

**Node:** N9 · **Build plan:** 0.7 · **Status: OPEN**

2030 factor levels by constant-share scaling of 2024 NIPA
(`K0_up(2030) = K0_up(2024)·Y_2030/Y_2024`), or straight from CBO's
income projections (N4 → N9)?

**Unblocked by:** data-gathering 2.1 (CBO Feb-2026 10-year economic
projections income block — wages and salaries, domestic economic profits,
proprietors' income; check whether rental, personal interest, and
personal dividend income are carried), 2.2 (revenue by category, FY
2025–2036), 2.3 (nominal GDP calendar and fiscal, real growth).

**Outputs:** `config/calibration/cbo_2026_02_income.csv` and
`cbo_2026_02_revenue.csv`, then build plan 1.1's `config/cbo_baseline.csv`.

**Also settles build plan 0.10** — the self-disagreeing benchmark. The
CIT 2030 row in `validation_benchmarks.csv` says 470 where the CBO
revenue table implies 486; whichever D6 picks, the receipt gets derived
from 2.2 rather than interpolated.

**Watch for double-counting:** CBO's baseline already contains an AI
productivity assumption (+0.1pp/yr). Document it (2.4) so the Karger
shock isn't stacked on top of it silently.

---

### D7 — Payout ratio `p`

**Node:** N21 · **Question:** Q2.2 (part) · **Build plan:** 0.8 ·
**Status: OPEN**

`div = p·Π_after`, `ret = (1−p)·Π_after`. Two things to decide: the level
of `p` (replacing today's unverified "≈0.4–0.5"), and whether `p`
*responds* to the labor-to-capital share shift or is held at its
historical mean.

**Unblocked by:** data-gathering 3.1 (NIPA Table 1.12 2015–2024: profits
before tax, federal taxes on corporate income from Table 3.2, profits
after tax, net dividends, undistributed profits) → receipt
`config/calibration/nipa_1_12_payout.csv`. Behavioral response:
Karabarbounis-Neiman, Chen et al.

**Must also retire an implicit duplicate** (flow-network gap #3):
`asset_to_income_map.csv` already splits public equity 0.30 dividends /
0.70 LTCG, which *is* a payout ratio. Once `p` exists the map's split
derives from `p` — two definitions of the same quantity is exactly what
build-plan principle 3 forbids.

**Scope note:** the dividends-vs-buybacks split (`b`) is the rest of
Q2.2 and stays deferred to §2 — D7 is `p` only.

---

### D8 — Labor lane: aggregate target vs pure loss

**Question:** Q3.1, sharpened · **Build plan:** 0.9 · **Source:**
`labor_exposure_extension.md` decision 1 · **Status: OPEN**

`Y_1^L = Y_0^L·(1+g_L)` is *given* by the Karger share path. So "displaced
income is a pure loss" and the existing aggregate target cannot both
hold: hitting `Y_1^L` after displacement requires a survivor wage
adjustment, which means displaced income is implicitly reallocated to
survivors. Either relax the target and reconcile the share identity
elsewhere, or accept the reallocation and document it as a modeling
choice.

**Moves:** whether the extensive margin is buildable at all; how the
labor module validates. This is D3's labor-side twin — **decide the two
together.**

**Adjacent, not blocking:** UI accounting (a transfer, so out of the
`sum(w·y_l1) = Y_1^L` identity, with its own column in
`write_factor_channels()`) and selection (weight-splitting vs per-record
draws) are labor-doc decisions 2 and 3. They don't gate Phase 0.

---

## 2. Deferred decisions

Real decisions with no Phase 0 gate. Each gets a D number when its phase
opens, so the numbering stays dense.

| Question | Node | Phase | The question |
|---|---|---|---|
| Q1.4 | — | 6 | Is "inference" the right frame? Only forward from Karger, or ever invert (observe a revenue/share target, back out the implied shock)? Pin down scope before the paper claims one |
| Q2.2 (`b`) | N21 | 3 | Buybacks are payout economically but taxed as realization. Split payout into dividends vs buyback-driven gains? Needs data-gathering 3.2 (Z.1 F.103 net equity issuance) |
| Q2.3 | N22 | 4 | `r_lt` concept: annual (0.16–0.35) vs lifetime (0.61). Moves realized LTCG by up to 4× |
| Q2.4 | N17 | 2 | κ tilt: is the entity split of `ΔΠ` the baseline split (0.497) or C-corp-tilted because software/IP is C-corp-concentrated (0.65)? `ΔR_CIT` +31% |
| Q2.5 | — | out? | International — GILTI, foreign profits, profit-shifting all sit inside the 30% avoidance number as a black box. Explicitly out of scope, or does the AI increment change the foreign share? |
| Q3.2 | P3 | labor 2 | Exposure metric: one score or an ensemble (Eloundou / AIOE / Webb / Anthropic Economic Index)? Displacement-vs-augmentation sign is not given by exposure alone and needs an explicit mapping |
| Q3.3 | P3 | labor 2 | Cell resolution: does `age × sex × wage-decile × filing` carry occupation signal, given the PUF can't see occupation? If variation is mostly within-cell, the CPS machinery may not earn its keep |
| Q3.4 | — | 2 / labor | Does the labor margin interact with the capital side? The share arithmetic implies displaced labor income *is* mechanically the capital gain; v1.0's code treats them as separable. Related to D3/D8 |

Also on the list, and **not** a Q-number: v2 has no CIT-burden node.
`lit_macro_to_micro_structures.md` records the three incidence
conventions in use (OTA 81.5/18.5, TPC 60/20/20, CBO 75/25); build plan
Phase 5 introduces the node. It will need a D number then.

---

## 3. Carried-over open items from v1.0

Migrated 2026-09-21 from the gitignored `todo.md` (the v0.1.0
public-release punch list), which is retired — everything else in it was
done or superseded by the v1.0.0 release. Verified against the tree at
`c4b6794`. Numbered `V1-*` to keep them out of the D sequence: these are
operational, not design decisions.

| # | Item | Verified state | Gates |
|---|---|---|---|
| V1-1 | Regenerate the synthetic fixture deterministically | `tests/fixtures/synthetic_tax_data/baseline/tax_units_2030.csv` untouched since `fb41110` (2026-05-26) — still the hand-patched version. The joint-constraints fix is committed, so the generator is authoritative and supersedes the patch | Build plan 0.1 — the golden fixture is frozen *on* this file |
| V1-2 | Native `renv::snapshot()` under cluster R 4.4.2 | `renv.lock` last touched at `968bbf9`, the relabel commit: 4.5.2-resolved versions carrying `"Version": "4.4.2"`. CI-validated, never natively snapshotted | Any v2 phase that adds a package |
| V1-3 | Quantify the M2 pass-through leak on real data | Logging landed (`06_build_counterfactual.R:215-227`, weighted dropped mass). Fires on the synthetic fixture at $2.6B / 1,915 units. The 2026-07-09 full run would have emitted the real number to a gitignored log — **no value is recorded anywhere in the repo** | Phase 4's conservation tests, which assume the leak is bounded |
| V1-4 | Archive `Budget-Lab-Yale/ai_fiscal` | Confirmed still open: `isArchived: false`, private, last push 2026-06-11. Checklist in `repo_consolidation.md`; that doc can go once this is done | Nothing — five minutes |
| V1-5 | Attach release assets to `v1.0.0` | `gh release view v1.0.0` returns `"assets": []`. The publishable xlsx and figure PNGs were never attached, so non-R readers can't get the deliverables | Nothing — five minutes |
| V1-6 | Upstream the three Tax-Simulator patches | Filed as issues **#128** (timeburden segfault under `--multicore scenario`), **#129** (non-unique `breaks` in `build_horizontal_table`), **#130** (`mc.cores` oversubscribes shared SLURM nodes) on 2026-06-22 — all three still **OPEN**, no PRs. Diagnosis in `tax_simulator_patches.md` | Phase 6's release candidate, which re-runs the grid through Tax-Simulator and hits all three again |

Two `todo.md` §C4 leftovers judged not worth carrying: replacing the
hand-rolled `.parse_cli_args` with `optparse`, and standardizing the
`# ====` banner style that only `15_blsmm_debt_gdp.R` uses. One that is
worth a line — there is no `here::` call anywhere in `code/`, though
`here` sits in `requirements.txt`. Bare relative paths work only because
`tax_data_vintage()` aborts outside the project root, and that abort
message names the vintage rather than the working directory, which sends
the reader to the wrong problem.

---

## Appendix A — Tax-Simulator patterns deliberately not adopted

Migrated verbatim from `todo.md` §D (written 2026-05-26 during the
Tax-Simulator comparison), so the divergence isn't relitigated. Kept
because v2 re-opens the interface with Tax-Simulator and these will come
up again.

- **Globbed `source(./src/, recursive = TRUE)`.** Tax-Simulator's
  `src/main.R` walks the tree and sources every `.R` file. We use
  explicit ordered `source(...)` calls in `00_ai_fiscal_sim.R` —
  readable, and a deterministic load order.
- **Committing `.claude/` to the repo.** Tax-Simulator does; we gitignore
  it (per-user state, not portable).
- **No LICENSE.** Tax-Simulator has none. We keep MIT.
- **Hard-coded Yale-Roberts paths in tracked config**
  (`config/interfaces/output_roots.yaml`). We keep env-var-driven paths
  (`AI_FISCAL_SCRATCH_ROOT`, `TAX_SIMULATOR_DIR`, `BLSMM_DIR`).
- **No version pinning** (Tax-Simulator's `requirements.txt` carries bare
  package names). We add `renv.lock`.
- **`config/interfaces/` for dependency-model versioning.**
  Tax-Simulator's `interface_versions.yaml` is elegant for declaring
  dependency vintages. We encode this in the Tax-Simulator runscript
  itself (the `dep.Tax-Data.vintage` column) and in env vars for sibling
  repos. The original note said "worth revisiting if we accumulate more
  sibling deps" — v2's CBO baseline module and the labor lane's exposure
  file are two more, so **revisit this in Phase 1**.
