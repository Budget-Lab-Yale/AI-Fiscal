# Load the merged PUF + SCF tax-unit file and apply the Smith-Yagan-Zidar
# 2019 passthrough labor / capital split. Output: data.table with original
# columns plus YiL, YiK, and per-unit active-profit capital shares.
#
# SYZ 2019 rule (applied at the tax-unit level — no owner-manager
# n-bar bridging; the firm-level threshold is treated as a tax-unit
# threshold directly):
#   W* = weighted P99.99 of wages, conditional on positive wages (the
#        W-2 universe). Set
#        passthrough.wage_threshold_conditioning = "all" for the
#        unconditional sensitivity.
#   Active S-corp / partnership profit:
#     below W*:  25% capital, 75% labor
#     above W*:  75% capital, 25% labor
#   Passive S-corp / partnership profit: 75% capital, 25% labor.
#   Losses are not addressed by SZ; we apply the below-W* default (25% cap)
#   to active losses, and the standard 75% cap to passive losses.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

load_tax_units <- function(year, data_dir = "data/tax_data") {
  fp <- file.path(data_dir, "baseline", sprintf("tax_units_%d.csv", year))
  if (!file.exists(fp)) {
    cli::cli_abort(c(
      "Tax-unit file not found.",
      x = "Looked for {.path {fp}}.",
      i = "Check that {.path {data_dir}} points at a valid Tax-Data vintage."
    ))
  }
  dt <- fread(fp)

  # Vintages 2026050315+ prefix wealth/asset columns with "value." and split
  # retirement into dc + db. Normalize to the older bare-name schema so the
  # rest of the pipeline doesn't have to branch on vintage.
  value_cols <- grep("^value\\.", names(dt), value = TRUE)
  if (length(value_cols)) {
    setnames(dt, value_cols, sub("^value\\.", "", value_cols))
    if ("dc" %in% names(dt)) setnames(dt, "dc", "retirement")
    # 'db' (DB pension wealth, new in 2026050315) preserved as-is; not used
    # in current asset-base allocation but available for future enhancement.

    # Sanity-check the wealth-column universe against the registry in
    # 00_utils.R::.ASSET_KNOWN. A new value.* column in a future vintage
    # (e.g. value.crypto) would otherwise be silently excluded from the
    # asset-base allocation — surface it so the schema can be updated.
    stripped <- sub("^value\\.", "", value_cols)
    stripped[stripped == "dc"] <- "retirement"
    unknown <- setdiff(stripped, .ASSET_KNOWN)
    if (length(unknown)) {
      cli::cli_warn(c(
        "Tax-Data vintage has wealth columns not in {.code .ASSET_KNOWN}.",
        x = "Unrecognized: {.field {unknown}}.",
        i = "Loaded but excluded from the asset-base allocation. Add to {.code .ASSET_KNOWN} (and likely {.code .ASSET_BASE_ALL_ASSETS}) in {.path code/00_utils.R} to include."
      ))
    }
  }
  dt
}

# Columns the SYZ split + YiL / YiK calculations need on the input
# tax-units table. Listed centrally so a vintage mismatch fails fast
# with a clear message instead of data.table's raw "object 'X' not found".
.REQUIRED_TAX_UNIT_COLS <- c(
  "weight", "wages",
  # SYZ active / passive profit columns:
  "scorp_active", "scorp_active_loss", "scorp_passive", "scorp_passive_loss",
  "part_active",  "part_active_loss",  "part_passive",  "part_passive_loss",
  # YiL composition:
  "sole_prop", "farm",
  # YiK composition:
  "txbl_int", "exempt_int", "div_ord", "div_pref",
  "kg_st", "kg_lt", "other_gains",
  "rent", "rent_loss", "estate", "estate_loss",
  "txbl_ira_dist", "txbl_pens_dist"
)

.require_columns <- function(dt, cols, where) {
  missing <- setdiff(cols, names(dt))
  if (length(missing)) {
    cli::cli_abort(c(
      "{.fn {where}} requires columns not present on {.arg dt}.",
      "x" = "Missing: {.field {missing}}",
      "i" = "Check the Tax-Data vintage; loader normalizes {.code value.*} prefixes in {.fn load_tax_units}."
    ))
  }
}

apply_passthrough_split <- function(dt, params) {
  pt <- params$raw$passthrough
  .require_columns(dt, .REQUIRED_TAX_UNIT_COLS, "apply_passthrough_split")
  # SYZ 2019 W* applied directly at the tax-unit level; no
  # owner-manager (n_bar) bridging.
  W_star <- compute_wage_threshold(dt, pt)

  dt <- compute_active_capital_shares(dt, W_star, pt)
  dt <- compute_passive_nets(dt)
  dt <- compute_yi_labor(dt, pt$passive_capital_share)
  dt <- compute_yi_capital(dt, pt$passive_capital_share)

  # One NA in any of the ~20 component income columns propagates into
  # YiL/YiK and would only surface much later as weird aggregates.
  if (anyNA(dt$YiL) || anyNA(dt$YiK)) {
    cli::cli_abort(c(
      "NA values after the SYZ split.",
      x = "YiL: {sum(is.na(dt$YiL))} NA{?s}; YiK: {sum(is.na(dt$YiK))} NA{?s}.",
      i = "An NA in any component income column propagates; inspect the vintage."
    ))
  }

  setattr(dt, "syz_W_star", W_star)
  dt
}

# Wage threshold W* used by the SYZ active-profit split.
#
# `wage_threshold_conditioning` controls the sample over which the percentile
# is evaluated:
#   "positive_wages": only tax units with wages > 0. Matches the SYZ paper
#     methodology (W-2 universe, conditional on positive wages). Default.
#   "all": every tax unit, including zero-wage filers. Pushes W* substantially
#     higher and shrinks the share of profit above W*; provided as a
#     sensitivity option.
compute_wage_threshold <- function(dt, pt) {
  conditioning <- pt$wage_threshold_conditioning
  p <- pt$wage_threshold_percentile / 100
  if (!is.numeric(p) || is.na(p) || p <= 0 || p >= 1) {
    cli::cli_abort(c(
      "Invalid {.field passthrough.wage_threshold_percentile}: {.val {pt$wage_threshold_percentile}}.",
      i = "Must be a percentile strictly between 0 and 100 (the yaml value is divided by 100 here — a fraction like 0.99 would silently become the 0.99th percentile)."
    ))
  }

  if (conditioning == "positive_wages") {
    keep <- !is.na(dt$wages) & dt$wages > 0
    if (!any(keep)) {
      cli::cli_abort(c(
        "No tax units with positive wages; cannot compute the SYZ W* threshold.",
        i = "Check the {.field wages} column of the vintage (all zero/negative/NA)."
      ))
    }
    weighted_quantile(dt$wages[keep], dt$weight[keep], p)
  } else if (conditioning == "all") {
    weighted_quantile(dt$wages, dt$weight, p)
  } else {
    cli::cli_abort(c(
      "Unknown {.field passthrough.wage_threshold_conditioning}: {.val {conditioning}}.",
      i = "Choose {.val positive_wages} or {.val all}."
    ))
  }
}

# For S-corp and partnership active profit, derive the per-unit capital share
# under SYZ: profit at or below W* is `cap_below` capital, profit above W* is
# `cap_above` capital. Active losses inherit the below-W* default. Adds two
# columns per kind: `<kind>_active_net` and `<kind>_active_cap_share`.
compute_active_capital_shares <- function(dt, W_star, pt) {
  cap_below <- pt$active_below_capital_share
  cap_above <- pt$active_above_capital_share

  for (kind in c("scorp", "part")) {
    pos  <- dt[[paste0(kind, "_active")]]
    loss <- dt[[paste0(kind, "_active_loss")]]
    net  <- pos - loss

    below <- pmin(pmax(net, 0), W_star)
    above <- pmax(net - W_star, 0)
    cap_share <- fifelse(net > 0,
                         (below * cap_below + above * cap_above) / net,
                         cap_below)

    dt[, (paste0(kind, "_active_net"))       := net]
    dt[, (paste0(kind, "_active_cap_share")) := cap_share]
  }
  dt
}

# Net (income minus loss) columns for items that aren't split active/passive
# the way passthrough profit is. Adds rent_net, estate_net, *_passive_net.
compute_passive_nets <- function(dt) {
  dt[, rent_net          := rent          - rent_loss]
  dt[, estate_net        := estate        - estate_loss]
  dt[, scorp_passive_net := scorp_passive - scorp_passive_loss]
  dt[, part_passive_net  := part_passive  - part_passive_loss]
  dt
}

# YiL = wages + Schedule C / F + labor share of passthrough profit.
compute_yi_labor <- function(dt, cap_passive) {
  dt[, YiL := wages + sole_prop + farm +
       (1 - scorp_active_cap_share) * scorp_active_net +
       (1 - cap_passive)            * scorp_passive_net +
       (1 - part_active_cap_share)  * part_active_net  +
       (1 - cap_passive)            * part_passive_net]
  dt
}

# YiK = pure-capital PUF items + capital share of passthrough profit + realized
# retirement distributions.
compute_yi_capital <- function(dt, cap_passive) {
  dt[, YiK := txbl_int + exempt_int + div_ord + div_pref +
       kg_st + kg_lt + other_gains +
       rent_net + estate_net +
       txbl_ira_dist + txbl_pens_dist +
       scorp_active_cap_share * scorp_active_net +
       cap_passive            * scorp_passive_net +
       part_active_cap_share  * part_active_net  +
       cap_passive            * part_passive_net]
  dt
}
