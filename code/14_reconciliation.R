# National-income reconciliation (docs/v1_2_plan.md, rung 2, item B1).
#
# For each (variant, share_mode), a table from GDP in the policy year to
# labor income, capital income, and the named rest of GDP, at baseline and
# under the AI shock, next to the income the model gives tax units. It
# shows where the national-accounts increment goes and how much of it the
# tax returns carry; it does not feed X, which stays sized on the tax file
# (decision 2).
#
# Baseline levels: each component's 2025 share of GDP (BEA Table 1.10,
# config/calibration/nipa_sector_gva_2025.csv) times CBO's calendar-year
# GDP in the policy year. Proprietors' income is split into labor and
# capital with the tax file's Saez-Zucman capital share
# (cell_params$proprietors_capital_share).
#
# Changes under the shock:
#   GDP                          g_y * GDP
#   depreciation, production taxes less subsidies, business transfers,
#   statistical discrepancy      held at their baseline share of GDP
#   compensation, proprietors' labor
#                                g_l * baseline (the rate the model
#                                applies to tax-file labor income)
#   rental income, net interest, government enterprise surplus
#                                0: on their baseline paths (B3)
#   corporate profits, proprietors' capital
#                                the remainder, split by baseline size

suppressPackageStartupMessages({
  library(data.table)
})

.RECON_HELD_AT_GDP_SHARE <- c("depreciation", "taxes_on_production_less_subsidies",
                              "business_transfers", "statistical_discrepancy")
.RECON_ON_BASELINE_PATH  <- c("rental", "net_interest", "gov_enterprise_surplus")
.RECON_PROFIT_TYPE       <- c("corporate_profits", "proprietors_capital")
.RECON_LABOR             <- c("compensation", "proprietors_labor")
.RECON_ROUNDING_B        <- 0.01

# Baseline components as shares of GDP, from the NIPA receipt.
.recon_gdp_shares <- function(nipa, proprietors_capital_share) {
  v <- setNames(nipa$value_B, nipa$component)
  needed <- c("gdp", "gdi_compensation", "gdi_proprietors", "gdi_corporate_profits",
              "gdi_rental", "gdi_net_interest", "gdi_gov_enterprise_surplus",
              "gdi_depreciation", "gdi_taxes_on_production", "gdi_subsidies",
              "gdi_business_transfers", "gdi_statistical_discrepancy")
  missing <- setdiff(needed, names(v))
  if (length(missing)) cli::cli_abort("NIPA receipt lacks {.val {missing}}.")
  level <- c(
    compensation          = v[["gdi_compensation"]],
    proprietors_labor     = (1 - proprietors_capital_share) * v[["gdi_proprietors"]],
    corporate_profits     = v[["gdi_corporate_profits"]],
    proprietors_capital   = proprietors_capital_share * v[["gdi_proprietors"]],
    rental                = v[["gdi_rental"]],
    net_interest          = v[["gdi_net_interest"]],
    gov_enterprise_surplus = v[["gdi_gov_enterprise_surplus"]],
    depreciation          = v[["gdi_depreciation"]],
    taxes_on_production_less_subsidies = v[["gdi_taxes_on_production"]] - v[["gdi_subsidies"]],
    business_transfers    = v[["gdi_business_transfers"]],
    statistical_discrepancy = v[["gdi_statistical_discrepancy"]]
  )
  # BEA rounds each published line to $1 million, so the identity holds to
  # a few million dollars.
  if (abs(sum(level) - v[["gdp"]]) > .RECON_ROUNDING_B) {
    cli::cli_abort("NIPA receipt components sum to {.val {sum(level)}}, not GDP {.val {v[['gdp']]}}.")
  }
  level / v[["gdp"]]
}

# One cell's reconciliation. `cell` is one row of cell_params.
.recon_cell <- function(cell, nipa, gdp_B) {
  base   <- .recon_gdp_shares(nipa, cell$proprietors_capital_share) * gdp_B
  change <- setNames(numeric(length(base)), names(base))
  d_gdp  <- cell$g_y * gdp_B

  change[.RECON_HELD_AT_GDP_SHARE] <- base[.RECON_HELD_AT_GDP_SHARE] / gdp_B * d_gdp
  change[.RECON_LABOR]             <- cell$g_l * base[.RECON_LABOR]
  change[.RECON_ON_BASELINE_PATH]  <- 0
  d_profit <- d_gdp - sum(change[c(.RECON_HELD_AT_GDP_SHARE, .RECON_LABOR)])
  change[.RECON_PROFIT_TYPE] <- d_profit * base[.RECON_PROFIT_TYPE] /
    sum(base[.RECON_PROFIT_TYPE])

  group <- ifelse(names(base) %in% .RECON_LABOR, "labor",
           ifelse(names(base) %in% c(.RECON_PROFIT_TYPE, .RECON_ON_BASELINE_PATH),
                  "capital", "rest_of_gdp"))
  rbind(
    data.table(group = "total", component = "gdp", baseline_B = gdp_B, change_B = d_gdp),
    data.table(group = group, component = names(base),
               baseline_B = unname(base), change_B = unname(change)),
    data.table(group = "tax_returns",
               component = c("labor_income", "capital_income"),
               baseline_B = c(cell$y0_l_B, cell$y0_k_B),
               change_B = c(cell$y1_l_B - cell$y0_l_B, cell$X_B))
  )
}

build_national_income_reconciliation <- function(cell_params, nipa, gdp_B, year) {
  cells <- unique(cell_params[labor_scenario == "S0"], by = c("variant", "share_mode"))
  if (is.null(cells$proprietors_capital_share)) {
    cli::cli_abort("cell_params lacks {.field proprietors_capital_share}; rebuild the run's inputs.")
  }
  out <- rbindlist(lapply(seq_len(nrow(cells)), function(i) {
    cbind(cells[i, .(variant, share_mode)], .recon_cell(cells[i], nipa, gdp_B))
  }))
  out[, `:=`(year = as.integer(year), share_of_gdp = baseline_B / gdp_B)]
  setcolorder(out, c("year", "variant", "share_mode", "group", "component",
                     "baseline_B", "change_B", "share_of_gdp"))
  out[]
}
