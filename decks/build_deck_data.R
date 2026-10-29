# Chart data for the two release decks (decks/outlines.md): one long-format
# CSV per chart slide, from finished runs, so the slides can be built where
# the runs are not (the slide-charts skill of budget-lab-charts reads a
# data.csv beside a chart.yaml). Titles and chart specs are written by hand
# on the machine that builds the deck.
#
# Usage (repo root, on the cluster where results/runs/ holds these runs):
#   Rscript decks/build_deck_data.R
# Writes decks/corrected_v1/data/*.csv and decks/v1_2/data/*.csv.
#
# 2026-10-29: the Version 1.2 reference moved to shock.post_2030 = to_2050
# (docs/v1_2_plan.md, "Post-2030 default"). The runs marked NA below are the
# reruns listed in docs/cluster_todo_2026-10-29.md; fill in their ids before
# running this script.

suppressPackageStartupMessages({
  library(data.table)
})

.RUNS <- list(
  legacy     = "legacy_v1_0_1-202610281529",
  fix1       = "v1_0_1_fix1_growth-202610290901",
  fix2       = "v1_0_1_fix2_fyblend-202610290905",
  fix3       = "v1_0_1_fix3_residual-202610290909",
  corrected  = "v1_0_1_corrected-202610290913",
  # Version 1.2 reference (to_2050). Before 2026-10-29 the reference was
  # hold_gap: v1_2_reference-202610282217, now the hold_gap sensitivity's
  # check run, and v1_2_sens_post2030_to_2050-202610282259 the reference's.
  v12        = NA_character_,  # v1_2_reference-<stamp>
  hold_gap   = NA_character_,  # v1_2_sens_post2030_hold_gap-<stamp>
  continue   = "v1_2_sens_post2030_continue_growth-202610282303",  # sets post_2030 itself; unchanged
  deferred   = NA_character_,  # v1_2_sens_retirement_deferred-<stamp>
  conc       = NA_character_,  # v1_2_sens_concentrated-<stamp>
  conc_m075  = NA_character_,  # v1_2_sens_concentrated_m075-<stamp>
  conc_m050  = NA_character_,  # v1_2_sens_concentrated_m050-<stamp>
  conc_m025  = NA_character_   # v1_2_sens_concentrated_m025-<stamp>
)
if (anyNA(unlist(.RUNS))) {
  stop("Fill in the run ids for: ", paste(names(.RUNS)[is.na(unlist(.RUNS))], collapse = ", "),
       " (docs/cluster_todo_2026-10-29.md).")
}
.POLICY_YEAR <- 2030L
.VARIANT     <- c(S = "Slow", M = "Moderate", R = "Rapid")
.SHARE_MODE  <- c(R = "Labor share falls", F = "Shares fixed")
.LABOR       <- c(S2 = "Compressive", S0 = "Proportional", S3 = "Expansive")

run_file <- function(run, ...) {
  fp <- file.path("results", "runs", .RUNS[[run]], ...)
  if (!file.exists(fp)) stop("Missing ", fp)
  fread(fp)
}

label <- function(d) {
  if ("variant" %in% names(d))    d[, scenario := factor(.VARIANT[variant], .VARIANT)]
  if ("share_mode" %in% names(d)) d[, shares := factor(.SHARE_MODE[share_mode], .SHARE_MODE)]
  if ("labor" %in% names(d))      d[, labor_rule := factor(.LABOR[labor], .LABOR)]
  d
}

write_slide <- function(d, deck, name) {
  dir.create(file.path("decks", deck, "data"), recursive = TRUE, showWarnings = FALSE)
  fwrite(d, file.path("decks", deck, "data", paste0(name, ".csv")), bom = FALSE)
}

wide_cols <- c(income_tax = "revenues_income_tax", payroll_tax = "revenues_payroll_tax",
               corporate_tax = "macro_cit_delta", total = "total_with_macro_cit")

# --- Deck 1: corrected Version 1 (FY2030) ------------------------------ #

c_wide <- label(run_file("corrected", "tables", sprintf("revenue_grid_wide_%d.csv", .POLICY_YEAR)))
write_slide(c_wide[labor == "S0", .(scenario, shares, revenue_change_B = total_with_macro_cit)],
            "corrected_v1", "s03_revenue_by_scenario")

c_params <- label(run_file("corrected", "inputs", "runscript_cell_params.csv")[
  year == .POLICY_YEAR & labor_scenario == "S0"])
write_slide(c_params[, .(scenario, shares, gdp_pct = 100 * g_y, capital_income_pct = 100 * g_k,
                         labor_income_pct = 100 * g_l)],
            "corrected_v1", "s06_income_growth")

c_macro <- label(run_file("corrected", "inputs", "runscript_macro.csv")[year == .POLICY_YEAR])
x_types <- c(Dividends = "X_qualified_div_B", `Capital gains` = "X_ltcg_gross_B",
             `Business income` = "X_passthrough_ordinary_B",
             `Retirement distributions` = "X_retirement_slice_B",
             Interest = "X_taxable_int_B", `Tax-exempt interest` = "X_tax_exempt_int_B")
c_macro[, (unname(x_types)) := lapply(.SD, as.numeric), .SDcols = unname(x_types)]
c_x <- melt(c_macro[, c("scenario", "shares", x_types), with = FALSE],
            id.vars = c("scenario", "shares"), variable.name = "column", value.name = "amount_B")
c_x[, income_type := names(x_types)[match(column, x_types)]][, column := NULL]
write_slide(c_x, "corrected_v1", "s09_capital_income_by_type")

c_tax <- melt(c_wide[labor == "S0" & share_mode == "R",
                     c("scenario", unname(wide_cols[1:3])), with = FALSE],
              id.vars = "scenario", variable.name = "column", value.name = "revenue_change_B")
c_tax[, tax := names(wide_cols)[match(column, wide_cols)]][, column := NULL]
write_slide(c_tax, "corrected_v1", "s13_revenue_by_tax")

write_slide(c_wide[share_mode == "R", .(scenario, labor_rule, revenue_change_B = total_with_macro_cit)],
            "corrected_v1", "s15_labor_rules")

c_gdp <- label(run_file("corrected", "tables", sprintf("revenue_to_gdp_%d.csv", .POLICY_YEAR)))
c_debt <- label(run_file("corrected", "tables", sprintf("blsmm_debt_to_gdp_%d.csv", .POLICY_YEAR)))
write_slide(merge(c_gdp[labor == "S0", .(scenario, shares, revenue_to_gdp_pp = 100 * delta_rev_to_gdp)],
                  c_debt[labor == "S0", .(scenario, shares, debt_to_gdp_pp = delta_debt_to_gdp_vs_baseline_pp)],
                  by = c("scenario", "shares")),
            "corrected_v1", "s16_gdp_and_debt")

gini_cut <- function(g) {
  g[, `:=`(variant    = sub("^ai_([SMR])_.*", "\\1", scenario_id),
           share_mode = sub("^ai_[SMR]_([RF])_.*", "\\1", scenario_id),
           labor      = sub("^ai_[SMR]_[RF]_(S[0-9])_.*", "\\1", scenario_id))]
  label(g[!grepl("_(LO|CO)$", scenario_id)])
}
c_gini <- gini_cut(run_file("corrected", "tables", sprintf("gini_deltas_%d.csv", .POLICY_YEAR)))
write_slide(c_gini[labor == "S0", .(scenario, shares, income_concept, gini_change = delta)],
            "corrected_v1", "s17_gini")

steps <- c(legacy = "v1.0.1", fix1 = "CBO calendar-year growth", fix2 = "Fiscal-year blend",
           fix3 = "Households with no financial assets", corrected = "Allocation base and interest")
bridge <- rbindlist(lapply(names(steps), function(r) {
  label(run_file(r, "tables", sprintf("revenue_grid_wide_%d.csv", .POLICY_YEAR)))[
    , .(step = steps[[r]], step_order = match(r, names(steps)), scenario, shares, labor_rule,
        revenue_change_B = total_with_macro_cit)]
}))
write_slide(bridge, "corrected_v1", "a1_corrections_bridge")
tax_table <- function(d, keys) {
  out <- d[, c(keys, unname(wide_cols)), with = FALSE]
  setnames(out, unname(wide_cols), paste0(names(wide_cols), "_B"))
  out
}
write_slide(tax_table(c_wide, c("scenario", "shares", "labor_rule")), "corrected_v1", "a2_revenue_grid")

# --- Deck 2: Version 1.2 (FY2026-2036) --------------------------------- #

v_year <- label(run_file("v12", "tables", "revenue_grid_wide_by_year.csv"))
write_slide(v_year[labor == "S0", .(year, scenario, shares, revenue_change_B = total_with_macro_cit,
                                    nowcast = year == 2026L)],
            "v1_2", "s03_annual_path")

totals <- function(run) label(run_file(run, "tables", "revenue_window_totals.csv"))
v_tot <- totals("v12")
write_slide(v_tot[labor == "S0", .(window, scenario, shares, revenue_change_B = total_with_macro_cit)],
            "v1_2", "s04_window_totals")

v_params <- label(run_file("v12", "inputs", "runscript_cell_params.csv")[labor_scenario == "S0"])
write_slide(v_params[, .(year, scenario, shares, gdp_pct = 100 * g_y,
                         nonfarm_labor_share_pct = 100 * theta_1_L,
                         capital_income_pct = 100 * g_k, labor_income_pct = 100 * g_l,
                         economy_labor_share_pct = 100 * theta_1_L_economy)],
            "v1_2", "s06_s07_paths_and_split")

v_recon <- label(run_file("v12", "tables", "national_income_reconciliation_by_year.csv"))
write_slide(v_recon[year == .POLICY_YEAR], "v1_2", "s12_reconciliation_2030")

v_tax <- melt(v_tot[labor == "S0" & share_mode == "R", c("scenario", unname(wide_cols[1:3])), with = FALSE],
              id.vars = "scenario", variable.name = "column", value.name = "revenue_change_B")
v_tax[, tax := names(wide_cols)[match(column, wide_cols)]][, column := NULL]
write_slide(v_tax, "v1_2", "s14_window_by_tax")

rules <- c(v12 = "Interpolate to 2050", hold_gap = "Hold the 2030 gap", continue = "Continue 2025-2030 growth")
post <- rbindlist(lapply(names(rules), function(r) {
  label(run_file(r, "tables", "revenue_grid_wide_by_year.csv"))[
    labor == "S0", .(post_2030 = rules[[r]], year, scenario, shares, revenue_change_B = total_with_macro_cit)]
}))
write_slide(post, "v1_2", "s15_after_2030")

sens <- c(v12 = "Reference", conc = "Concentrated ownership",
          conc_m075 = "Concentrated, 75% of AI gains realized",
          conc_m050 = "Concentrated, 50% realized", conc_m025 = "Concentrated, 25% realized",
          deferred = "Retirement income deferred")
write_slide(rbindlist(lapply(names(sens), function(r) totals(r)[
  labor == "S0", .(sensitivity = sens[[r]], order = match(r, names(sens)), scenario, shares,
                   revenue_change_B = total_with_macro_cit)])),
  "v1_2", "s16_sensitivities")

write_slide(v_tot[share_mode == "R", .(scenario, labor_rule, revenue_change_B = total_with_macro_cit)],
            "v1_2", "s17_labor_rules")

early <- file.path("results", "runs", .RUNS$v12, "tables")
write_slide(fread(file.path(early, "early_evidence_inputs.csv")), "v1_2", "s18_early_evidence_inputs")
write_slide(fread(file.path(early, "early_evidence_receipts.csv")), "v1_2", "s19_early_evidence_receipts")

v_gini <- gini_cut(run_file("v12", "tables", "gini_deltas_by_year.csv"))
write_slide(v_gini[labor == "S0", .(year, scenario, shares, income_concept, gini_change = delta)],
            "v1_2", "s20_gini_by_year")

b1 <- rbindlist(list(
  label(run_file("corrected", "tables", sprintf("revenue_grid_wide_%d.csv", .POLICY_YEAR)))[
    , .(version = "Corrected Version 1", scenario, shares, labor_rule, revenue_change_B = total_with_macro_cit)],
  v_year[year == .POLICY_YEAR, .(version = "Version 1.2", scenario, shares, labor_rule,
                                 revenue_change_B = total_with_macro_cit)]))
write_slide(b1, "v1_2", "b1_bridge_fy2030")
write_slide(tax_table(v_tot, c("window", "scenario", "shares", "labor_rule")), "v1_2", "b4_window_totals")

# --- Added 2026-10-29: FY2030 detail for Version 1.2, and the published ---- #
# report's decomposition (Figure 2) and tax rates by decile (Figure 7).

# Revenue by labor-only, capital-only, and both shocks, per instrument.
decomp_table <- function(d) {
  gini_cut(d)[instrument %in% c("revenues_income_tax", "revenues_payroll_tax", "outlays_tax_credits", "total"),
              .(scenario, shares, labor_rule, instrument, delta_labor, delta_capital, delta_both, interaction)]
}
# Tax and pre-tax income by decile, baseline and counterfactual ($B).
atr_table <- function(d) {
  gini_cut(d)[, .(scenario, shares, labor_rule, decile, pretax_base_d_B, pretax_cf_d_B, tax_base_d_B, tax_cf_d_B)]
}

write_slide(tax_table(v_year[year == .POLICY_YEAR], c("scenario", "shares", "labor_rule")),
            "v1_2", "p1_fy2030_by_tax")
write_slide(decomp_table(run_file("v12", "tables", "revenue_decomp_by_year.csv")[year == .POLICY_YEAR]),
            "v1_2", "p1_fy2030_decomp")
write_slide(atr_table(run_file("v12", "tables", "atr_decile_by_year.csv")[year == .POLICY_YEAR]),
            "v1_2", "p1_fy2030_atr_decile")
write_slide(decomp_table(run_file("corrected", "tables", sprintf("revenue_decomp_%d.csv", .POLICY_YEAR))),
            "corrected_v1", "a4_revenue_decomp")
write_slide(atr_table(run_file("corrected", "tables", sprintf("atr_decile_%d.csv", .POLICY_YEAR))),
            "corrected_v1", "a5_atr_decile")

cat("Wrote", length(list.files("decks", pattern = "\\.csv$", recursive = TRUE)), "chart data files.\n")
