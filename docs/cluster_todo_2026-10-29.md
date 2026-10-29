# Cluster to-do: post-2030 default moved to `to_2050` (2026-10-29)

The Version 1.2 reference now sets `shock.post_2030: to_2050` (Decision 6 in
`docs/v1_2_plan.md`): after 2030, Karger's growth rate and labor share move
together in straight lines to the survey's 2050 values. Holding the 2030 gap
is the new sensitivity `v1_2_sens_post2030_hold_gap`, which replaces
`v1_2_sens_post2030_to_2050` (the reference now matches it).

Every setting that inherits `v1_2_reference` changes after 2030, so the
reference and its sensitivities need new runs. FY2026-2030 results do not
change. This list covers the runs, two reproduction checks that come free
with them, and the deck data.

## 1. Update the checkout

```bash
git fetch origin && git checkout AI-Fiscal-V1.2 && git pull --ff-only
grep -n "post_2030" config/settings/v1_2_reference.yaml   # expect: post_2030: to_2050
ls config/settings/ | grep post2030                        # hold_gap and continue_growth; no to_2050
```

## 2. Runs

All seven use `tests/server/setting_full.sbatch` (12 cores, 340 GB, about 31
minutes each for the annual window). Runs that start in the same minute
collide on the Tax-Simulator output folder (the orchestrator aborts), so
submit at least a minute apart.

```bash
export TAX_SIMULATOR_DIR=<Tax-Simulator worktree at 256f03ea9 + patches>
export BLSMM_DIR=<BLSMM checkout at adce14d>
for SETTING in v1_2_reference v1_2_sens_post2030_hold_gap \
               v1_2_sens_concentrated v1_2_sens_concentrated_m075 \
               v1_2_sens_concentrated_m050 v1_2_sens_concentrated_m025 \
               v1_2_sens_retirement_deferred; do
  SETTING=$SETTING sbatch --output=<log dir>/%x-$SETTING-%j.out tests/server/setting_full.sbatch
  sleep 90
done
```

| # | Setting | Why | Reuse instead? |
|---|---|---|---|
| 1 | `v1_2_reference` | New reference (`to_2050`) | No: release provenance needs a run under the reference's own name |
| 2 | `v1_2_sens_post2030_hold_gap` | New sensitivity (the old reference) | No, for the same reason |
| 3 | `v1_2_sens_concentrated` | Inherits the reference | No |
| 4 | `v1_2_sens_concentrated_m075` | Inherits 3 | No |
| 5 | `v1_2_sens_concentrated_m050` | Inherits 3 | No |
| 6 | `v1_2_sens_concentrated_m025` | Inherits 3 | No |
| 7 | `v1_2_sens_retirement_deferred` | Inherits the reference | No |
| – | `v1_2_sens_post2030_continue_growth` | Sets `post_2030` itself | Yes: `v1_2_sens_post2030_continue_growth-202610282303` is unchanged |

Success for each run is exit code 0 **and** `status: succeeded` in
`results/runs/<setting>-<stamp>/manifest.yaml` (the sbatch checks both). A
completed job is not enough.

## 3. Reproduction checks (free with runs 1 and 2)

The new reference has the same parameters as the old `to_2050` sensitivity,
and the new hold-gap sensitivity has the same parameters as the old
reference. Their tables should match to 1e-9:

```bash
module load R/4.4.2-gfbf-2024a
Rscript tests/server/compare_run_tables.R \
  results/runs/v1_2_reference-<stamp>/tables \
  results/runs/v1_2_sens_post2030_to_2050-202610282259/tables
Rscript tests/server/compare_run_tables.R \
  results/runs/v1_2_sens_post2030_hold_gap-<stamp>/tables \
  results/runs/v1_2_reference-202610282217/tables
```

Both should print `LAYER3 PASS`. A failure means something other than the
post-2030 rule changed between 2026-10-28 and now: stop and find it before
going on.

Spot checks on the new reference (labor share falls, proportional, from
`tables/revenue_grid_wide_by_year.csv` and `tables/revenue_window_totals.csv`):

- FY2030 Moderate total is $133.8B, unchanged.
- FY2027-2036 Moderate total is about $2,313B (Slow about $132B, Rapid about $4,329B).

## 4. Deck data

1. Check that the new reference wrote the tables the deck now reads:
   `revenue_decomp_by_year.csv`, `atr_decile_by_year.csv`,
   `national_income_reconciliation_by_year.csv`, `gini_deltas_by_year.csv`,
   `early_evidence_inputs.csv`, `early_evidence_receipts.csv`.
2. In `decks/build_deck_data.R`, replace each `NA_character_` in `.RUNS` with
   the run ids from step 2 (the script stops until all are filled).
3. Run `Rscript decks/build_deck_data.R` from the repo root. New files this
   time: `decks/v1_2/data/p1_fy2030_by_tax.csv`, `p1_fy2030_decomp.csv`,
   `p1_fy2030_atr_decile.csv`, and `decks/corrected_v1/data/a4_revenue_decomp.csv`,
   `a5_atr_decile.csv`.
4. In `decks/v1_2/data/s15_after_2030.csv`, "Interpolate to 2050" now comes
   from the reference run and "Hold the 2030 gap" from run 2. The values
   should match the current file (only the source runs change).

## 5. Record and push

1. In `docs/v1_2_plan.md`, under Decision 6, add the run ids and job numbers,
   the two `LAYER3 PASS` results, and the Moderate FY2027-2036 total.
2. Stage explicit paths only (no `git add -A`): `decks/build_deck_data.R`,
   `decks/v1_2/data/*.csv`, `decks/corrected_v1/data/*.csv`, `docs/v1_2_plan.md`.
   If the new reference run is committed as the legacy run was, include its
   `tables/`, `inputs/`, and `manifest.yaml` only (no workbooks, no log).
3. Commit and push to `AI-Fiscal-V1.2`.

## 6. Afterwards, on the laptop (not the cluster)

- Rebuild the slide charts and the Version 1.2 deck (OneDrive
  `AI-Fiscal-V1.2/slides/2026_10_release`: `make_charts.py`, `build_decks.py`).
  The third-draft deck labels its window results "holding the 2030 gap"; the
  text and titles need to follow the new reference.
- Add the FY2030 tax, decomposition, and decile slides to Part 1 from the new
  `p1_fy2030_*` files, and fill appendix A4 of the corrected Version 1 deck.
