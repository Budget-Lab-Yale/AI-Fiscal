# Read scenario_params.yaml and resolve the active variant. Derives the
# overall AI growth bump g_y from r_ai_annual (Karger Table 19) and the CBO
# baseline path, then the per-factor cumulative growth rates (g_k, g_l) from
# the baseline and post-shock factor shares (theta0_l, theta1_k, g_y):
#   horizon  = baseline_year - cbo_baseline.horizon_start_year   (= 5 for 2030)
#   cum_base = (1 + g_2026) * (1 + g_2027plus)^(horizon - 1)
#   g_y      = (1 + r_ai_annual)^horizon / cum_base - 1
#   theta0_k = 1 - theta0_l
#   theta1_l = 1 - theta1_k
#   g_k      = (theta1_k * (1 + g_y) - theta0_k) / theta0_k
#   g_l      = (theta1_l * (1 + g_y) - theta0_l) / theta0_l
# g_y, g_k, g_l are cumulative growth rates over the horizon (the methodology
# uses g for cumulative, r for annual); they apply to aggregate capital and
# labor income as Y1^K = Y0^K (1 + g_k) and Y1^L = Y0^L (1 + g_l).
#
# Version 1.2 rung 1 switches (legacy values give the formulas above):
#   cbo_baseline.growth_path = annual: cum_base is CBO's real GDP ratio,
#     baseline_year over horizon_start_year, from cbo_baseline.path_file.
#   shock.share_baseline = projected: theta0_l is the survey's 2025 share
#     plus the CBO path's change in compensation / GDP over the horizon.
#   shock.sector = nonfarm_business: theta0_l -> theta1_l and all of g_y
#     happen within nonfarm business, a share n of baseline GDP; the rest
#     of the economy keeps its income and its labor share theta_o
#     (shock.sector_file). With baseline GDP = 1:
#       L0 = theta0_l n + theta_o (1 - n)
#       L1 = theta1_l (n + g_y) + theta_o (1 - n)
#       g_l = L1 / L0 - 1,   g_k = (1 + g_y - L1) / (1 - L0) - 1
#     n is the 2025 NIPA share moved by the CBO path's ratio of real
#     nonfarm-business output to real GDP. theta0_l / theta1_l stay the
#     survey-concept (nonfarm-business) shares; theta0_l_economy /
#     theta1_l_economy are the economy-wide shares the bridge implies.
#
# `share_mode` selects the factor-evolution counterfactual:
#   R (default): reallocate — use the Karger post-shock capital share
#                theta1_k for the chosen variant so the labor share falls.
#   F          : fixed share — override theta1_k := theta0_k so the post-shock
#                capital share equals baseline. g_k = g_l = g_y.
#
# load_params() validates that every required key is present and aborts with
# a list of any gaps.
#
# `setting` selects a named parameter setting (docs/v1_2_plan.md, rung 0).
# The base yaml carries every key at its v1.0.1 value, so the legacy setting
# is the base yaml unchanged and has no overlay file. Any other setting is an
# overlay at <dir of path>/settings/<setting>.yaml that lists only the keys it
# changes; each changed leaf may carry a `<key>_rung` tag naming the rung
# that introduced it. Overlays may only override keys present in the base.

suppressPackageStartupMessages({
  library(yaml)
})

source("code/00_utils.R")

# Required parameters. Each entry is a dot-separated path into the yaml.
# Variant-specific keys are expanded for S/M/R (Slow / Moderate / Rapid).
.REQUIRED_PARAM_KEYS <- c(
  "baseline_year", "window", "window_first_year", "window_last_year",
  paste0("cbo_baseline.",
         c("horizon_start_year", "g_2026", "g_2027plus",
           "gdp_baseline_year_B", "rev_to_gdp_baseline_year",
           "cit_to_gdp_baseline_year", "growth_path", "path_file",
           "budget_path_file")),
  paste0("shock.",
         c("baseline_labor_share", "share_baseline", "sector", "sector_file",
           "post_2030")),
  unlist(lapply(c("S", "M", "R"), function(v) {
    sprintf("shock.variants.%s.%s", v,
            c("theta1_k", "r_ai_annual", "theta1_k_2050", "r_ai_annual_2050"))
  })),
  "labor_inequality.k",
  paste0("capital_flow.",
         c("allocation_base", "interest", "residual", "retirement_flow",
           "allocator", "concentration_top1",
           "concentration_top01", "payout", "ai_gains_realized")),
  paste0("passthrough.",
         c("wage_threshold_percentile", "wage_threshold_conditioning",
           "active_below_capital_share", "active_above_capital_share",
           "passive_capital_share")),
  paste0("corporate.",
         c("kappa_corp", "cit_statutory", "share_abroad", "abroad_rate",
           "share_interest"))
)

# Walk a dotted path into a nested list. Returns list(missing = TRUE, value
# = NULL) if any segment is missing along the way; otherwise list(missing =
# FALSE, value = <leaf>).
.dotted_path <- function(x, path) {
  segs <- strsplit(path, ".", fixed = TRUE)[[1]]
  for (s in segs) {
    if (!is.list(x) || !s %in% names(x)) return(list(missing = TRUE, value = NULL))
    x <- x[[s]]
  }
  list(missing = FALSE, value = x)
}

.validate_required_keys <- function(raw, path) {
  missing <- character()
  for (key in .REQUIRED_PARAM_KEYS) {
    if (.dotted_path(raw, key)$missing) missing <- c(missing, key)
  }
  if (length(missing)) {
    cli::cli_abort(c(
      "{.path {path}} is missing required keys.",
      "x" = "Not found: {.field {missing}}",
      "i" = "Every parameter must be declared. See the file header for the schema."
    ))
  }
}

.LEGACY_SETTING     <- "legacy_v1_0_1"
.SETTING_RUNG_SUFFIX <- "_rung"

# Merge a setting overlay into the base yaml, recursing into named lists.
# Rung tags are bookkeeping for the bridge table and are dropped.
.apply_setting_overlay <- function(base, overlay, setting, where = "") {
  for (key in names(overlay)) {
    if (endsWith(key, .SETTING_RUNG_SUFFIX)) next
    path <- paste0(where, key)
    if (!key %in% names(base)) {
      cli::cli_abort(c(
        "Setting {.val {setting}} overrides {.field {path}}, which is not in the base yaml.",
        i = "Add the key to {.path config/scenario_params.yaml} at its v1.0.1 value first."
      ))
    }
    # Assigning NULL with [[<- would delete the key rather than override it.
    if (is.null(overlay[[key]])) {
      cli::cli_abort("Setting {.val {setting}} sets {.field {path}} to null; give it a value.")
    }
    is_branch <- is.list(overlay[[key]]) && !is.null(names(overlay[[key]]))
    base[[key]] <- if (is_branch) {
      .apply_setting_overlay(base[[key]], overlay[[key]], setting,
                             where = paste0(path, "."))
    } else {
      overlay[[key]]
    }
  }
  base
}

.read_setting_overlay <- function(setting, path) {
  if (!grepl("^[a-z0-9_]+$", setting)) {
    cli::cli_abort("Setting name {.val {setting}} must be lower-case letters, digits, and underscores.")
  }
  settings_dir <- file.path(dirname(path), "settings")
  fp <- file.path(settings_dir, paste0(setting, ".yaml"))
  if (!file.exists(fp)) {
    available <- c(.LEGACY_SETTING,
                   sub("\\.yaml$", "", list.files(settings_dir, "\\.yaml$")))
    cli::cli_abort(c(
      "Unknown setting {.val {setting}}.",
      x = "No overlay at {.path {fp}}.",
      i = "Available: {.val {available}}."
    ))
  }
  # An overlay holding only comments reads as NULL: no keys changed yet.
  yaml::read_yaml(fp) %||% list()
}

# A setting's overlays, root first. An overlay may name another setting in
# a top-level `inherits:` key (e.g. a sensitivity built on the reference),
# whose keys it then changes.
.read_setting_chain <- function(setting, path, seen = character()) {
  if (setting %in% seen) {
    cli::cli_abort("Settings inherit in a loop: {.val {c(seen, setting)}}.")
  }
  overlay <- .read_setting_overlay(setting, path)
  parent  <- overlay$inherits
  overlay$inherits <- NULL
  if (is.null(parent)) return(list(overlay))
  c(.read_setting_chain(parent, path, c(seen, setting)), list(overlay))
}

# Allowed values of the rung-1 switches; the first is the v1.0.1 value.
.SWITCH_VALUES <- list(
  "cbo_baseline.growth_path" = c("flat", "annual"),
  "shock.share_baseline"     = c("survey_2025", "projected"),
  "shock.sector"             = c("whole_economy", "nonfarm_business"),
  "capital_flow.allocation_base" = c("all_assets", "ex_home_cash_nonfin"),
  "capital_flow.interest"    = c("by_holdings", "baseline_path"),
  "capital_flow.allocator"   = c("proportional", "concentrating"),
  "window"                   = c("single_year", "annual"),
  "capital_flow.residual"    = c("retirement", "spread"),
  "capital_flow.retirement_flow" = c("distributed", "deferred"),
  "shock.post_2030"          = c("hold_gap", "to_2050", "continue_growth")
)

# Rung-3 shares that must lie in [0, 1].
.UNIT_INTERVAL_KEYS <- c(
  "capital_flow.payout", "capital_flow.ai_gains_realized",
  "capital_flow.concentration_top1", "capital_flow.concentration_top01",
  "corporate.share_abroad", "corporate.abroad_rate", "corporate.share_interest"
)

.validate_shares <- function(raw) {
  for (key in .UNIT_INTERVAL_KEYS) {
    value <- .dotted_path(raw, key)$value
    if (!is.numeric(value) || length(value) != 1L || is.na(value) || value < 0 || value > 1) {
      cli::cli_abort("{.field {key}} must be a number in [0, 1]; got {.val {value}}.")
    }
  }
  cf <- raw$capital_flow
  if (cf$concentration_top01 >= cf$concentration_top1 || cf$concentration_top1 >= 1) {
    cli::cli_abort("Concentration targets need 0 <= top01 < top1 < 1; got top01 = {.val {cf$concentration_top01}}, top1 = {.val {cf$concentration_top1}}.")
  }
  if (raw$corporate$share_abroad + raw$corporate$share_interest > 1) {
    cli::cli_abort("{.field corporate.share_abroad} + {.field corporate.share_interest} exceeds 1.")
  }
}

.validate_switches <- function(raw) {
  for (key in names(.SWITCH_VALUES)) {
    value   <- .dotted_path(raw, key)$value
    allowed <- .SWITCH_VALUES[[key]]
    if (!is.character(value) || length(value) != 1L || !value %in% allowed) {
      cli::cli_abort(c(
        "{.field {key}} is {.val {value}}.",
        i = "Choose one of {.val {allowed}}."
      ))
    }
  }
}

# A calibration receipt named in the yaml, relative to the config directory.
.read_receipt <- function(config_dir, file) {
  fp <- file.path(config_dir, file)
  if (!file.exists(fp)) {
    cli::cli_abort(c(
      "Calibration receipt not found: {.path {fp}}.",
      i = "Rebuild it with {.code Rscript code/12_baseline_receipts.R}."
    ))
  }
  data.table::fread(fp)
}

# Ratio of a CBO baseline path column between two years.
.path_ratio <- function(path, column, from, to) {
  vals <- path[[column]][match(c(from, to), path$year)]
  if (anyNA(vals)) {
    cli::cli_abort("The CBO baseline path has no {.field {column}} for {.val {c(from, to)[is.na(vals)]}}.")
  }
  vals[2] / vals[1]
}

# Nonfarm business's share of GDP and the labor share of the rest of the
# economy, from the NIPA sector receipt. Outside nonfarm business, labor
# income is employee compensation (government, households, nonprofit
# institutions, farms); farm proprietors' labor is not imputed.
.nipa_sector_shares <- function(sector) {
  value <- function(component) {
    v <- sector$value_B[sector$component == component]
    if (length(v) != 1L || is.na(v)) cli::cli_abort("NIPA sector receipt lacks {.val {component}}.")
    v
  }
  gdp_other  <- value("gdp") - value("gva_nonfarm_business")
  comp_other <- value("comp_farms") + value("comp_households") +
                value("comp_npish") + value("comp_general_government")
  list(gva_share   = value("gva_nonfarm_business") / value("gdp"),
       labor_other = comp_other / gdp_other)
}

# Years of the survey's horizon and long-run forecast (Karger 2026: 2025 to
# 2030, and the five years to 2050).
.KARGER_YEAR      <- 2030L
.KARGER_LONG_YEAR <- 2050L

# The tax year a parameter set is for: baseline_year for a single-year
# window, any year of the window for an annual one.
.validate_year <- function(raw, year, start_year) {
  year <- as.integer(year)
  if (raw$window == "single_year") {
    if (!identical(as.integer(year), as.integer(raw$baseline_year))) {
      cli::cli_abort("A single-year window scores only baseline_year ({.val {raw$baseline_year}}); got {.val {year}}.")
    }
    if (year - start_year < 1) {
      cli::cli_abort(c(
        "Karger horizon must be at least 1 year.",
        x = "baseline_year ({.val {year}}) <= cbo_baseline.horizon_start_year ({.val {start_year}})."
      ))
    }
    return(year)
  }
  if (raw$cbo_baseline$growth_path != "annual") {
    cli::cli_abort("An annual window needs {.field cbo_baseline.growth_path} = {.val annual}.")
  }
  if (year < raw$window_first_year || year > raw$window_last_year || year < start_year) {
    cli::cli_abort("Year {.val {year}} is outside the window {.val {raw$window_first_year}}-{.val {raw$window_last_year}}.")
  }
  year
}

# AI GDP level in `year` relative to start_year (A3). Through 2030 the AI
# growth rate is r_ai_annual (Karger Table 19). After 2030 by
# shock.post_2030: continue_growth keeps r_ai_annual; to_2050 moves the
# annual rate linearly from r_ai_annual in 2030 to r_ai_annual_2050 in
# 2050. (hold_gap is handled in load_params: g_y stays at its 2030 value.)
.ai_gdp_index <- function(v, post_2030, year, start_year) {
  r <- v$r_ai_annual
  if (year <= .KARGER_YEAR || post_2030 == "continue_growth") {
    return((1 + r)^(year - start_year))
  }
  at_2030 <- (1 + r)^(.KARGER_YEAR - start_year)
  steps <- seq(.KARGER_YEAR + 1L, year)
  rates <- r + (v$r_ai_annual_2050 - r) * (steps - .KARGER_YEAR) /
    (.KARGER_LONG_YEAR - .KARGER_YEAR)
  at_2030 * prod(1 + rates)
}

# Post-shock capital share in nonfarm business in `year` (A3): linear from
# the survey's 2025 share to its 2030 value, then by shock.post_2030
# (to_2050: linear to 1 - theta1_k_2050 in 2050; otherwise held).
.ai_capital_share <- function(v, post_2030, year, start_year, theta0_k_survey) {
  if (year == .KARGER_YEAR) return(v$theta1_k)
  if (year < .KARGER_YEAR) {
    return(theta0_k_survey + (v$theta1_k - theta0_k_survey) *
             (year - start_year) / (.KARGER_YEAR - start_year))
  }
  if (post_2030 != "to_2050") return(v$theta1_k)
  v$theta1_k + (v$theta1_k_2050 - v$theta1_k) * (year - .KARGER_YEAR) /
    (.KARGER_LONG_YEAR - .KARGER_YEAR)
}

.RETIREMENT_CAL_KEYS <- c("r_R", "s_P", "s_I", "tau_P", "tau_I")

# Load the R1 retirement cascade calibration — see Table 2 of
# docs/ai_fiscal_methodology.md.
load_retirement_calibration <- function(path = "config/retirement_calibration.yaml") {
  if (!file.exists(path)) {
    cli::cli_abort(c(
      "Retirement calibration file not found.",
      x = "Looked for {.path {path}}.",
      i = "Required for the R1 cascade; restore the file from git history if missing."
    ))
  }
  cal <- yaml::read_yaml(path)
  missing <- setdiff(.RETIREMENT_CAL_KEYS, names(cal))
  if (length(missing)) {
    cli::cli_abort(c(
      "{.path {path}} is missing required calibration keys.",
      x = "Not found: {.field {missing}}",
      i = "Required keys: {.field {.RETIREMENT_CAL_KEYS}}."
    ))
  }
  cal
}

load_params <- function(path = "config/scenario_params.yaml",
                        variant = NULL, share_mode = "R",
                        setting = .LEGACY_SETTING, year = NULL) {
  if (!file.exists(path)) {
    cli::cli_abort(c(
      "Parameter config not found.",
      "x" = "Looked for {.path {path}}.",
      "i" = "The pipeline requires {.path config/scenario_params.yaml}."
    ))
  }
  if (!share_mode %in% c("R", "F")) {
    cli::cli_abort(c(
      "Unknown {.arg share_mode}: {.val {share_mode}}.",
      i = "Choose {.val R} (reallocate) or {.val F} (fixed share)."
    ))
  }
  raw <- yaml::read_yaml(path)
  .validate_required_keys(raw, path)
  if (!identical(setting, .LEGACY_SETTING)) {
    for (overlay in .read_setting_chain(setting, path)) {
      raw <- .apply_setting_overlay(raw, overlay, setting)
    }
  }

  active <- variant %||% "M"
  if (!active %in% names(raw$shock$variants)) {
    cli::cli_abort(c(
      "Variant {.val {active}} is not a defined shock variant.",
      i = "Choose one of {.val {names(raw$shock$variants)}} in {.path {path}}."
    ))
  }
  v <- raw$shock$variants[[active]]

  .validate_switches(raw)
  .validate_shares(raw)
  start_year <- raw$cbo_baseline$horizon_start_year
  # Default year: baseline_year, or the window's first year when an annual
  # window does not contain it.
  in_window  <- raw$window == "single_year" ||
    (raw$baseline_year >= raw$window_first_year && raw$baseline_year <= raw$window_last_year)
  year       <- .validate_year(raw, year %||% if (in_window) raw$baseline_year else raw$window_first_year,
                               start_year)
  horizon    <- year - start_year
  config_dir   <- dirname(path)
  cbo          <- raw$cbo_baseline
  uses_path    <- cbo$growth_path == "annual" ||
                  raw$shock$share_baseline == "projected" ||
                  raw$shock$sector == "nonfarm_business"
  cbo_path     <- if (uses_path) .read_receipt(config_dir, cbo$path_file)

  if (cbo$growth_path == "flat") {
    # The CBO growth keys are named by calendar year but consumed
    # positionally: g_2026 applies to the first horizon year, g_2027plus
    # to the rest. That is only correct while the horizon starts at 2025.
    # Rolling the CBO baseline forward without renaming the keys would
    # silently shift the compounding — assert until the v2 year-indexed
    # baseline object replaces this (docs/v2_architecture.md §2).
    if (!identical(as.integer(start_year), 2025L)) {
      cli::cli_abort(c(
        "cbo_baseline.horizon_start_year is {.val {start_year}} but the growth keys assume 2025.",
        x = "{.field g_2026} / {.field g_2027plus} are applied positionally to horizon years 1 / 2+.",
        i = "Rename the keys and update the compounding in {.fn load_params} before rolling the baseline forward."
      ))
    }
    g_2026     <- cbo$g_2026
    g_2027plus <- cbo$g_2027plus
    cum_base   <- (1 + g_2026) * (1 + g_2027plus)^(horizon - 1)
  } else {
    cum_base <- .path_ratio(cbo_path, "real_gdp_B2017", start_year, year)
  }
  if (!is.numeric(v$r_ai_annual) || is.na(v$r_ai_annual) || v$r_ai_annual <= -1) {
    cli::cli_abort(
      "Variant {.val {active}}: {.field r_ai_annual} must be a number > -1 (got {.val {v$r_ai_annual}})."
    )
  }
  g_y <- if (year > .KARGER_YEAR && raw$shock$post_2030 == "hold_gap") {
    .ai_gdp_index(v, "hold_gap", .KARGER_YEAR, start_year) /
      .path_ratio(cbo_path, "real_gdp_B2017", start_year, .KARGER_YEAR) - 1
  } else {
    .ai_gdp_index(v, raw$shock$post_2030, year, start_year) / cum_base - 1
  }

  theta0_l <- raw$shock$baseline_labor_share
  if (raw$shock$share_baseline == "projected") {
    comp_share <- cbo_path$comp_paid_B / cbo_path$gdp_B
    theta0_l   <- theta0_l + comp_share[match(year, cbo_path$year)] -
                             comp_share[match(start_year, cbo_path$year)]
  }
  if (!is.numeric(theta0_l) || is.na(theta0_l) || theta0_l <= 0 || theta0_l >= 1) {
    cli::cli_abort(
      "{.field shock.baseline_labor_share} must be strictly inside (0, 1); got {.val {theta0_l}}."
    )
  }
  theta0_k <- 1 - theta0_l
  # Under share_mode = "F" we pin the post-shock capital share to baseline
  # (theta1_k := theta0_k) so the labor-capital split is preserved while g_y
  # is unchanged. g_k and g_l both collapse to g_y (whole-economy shock).
  theta1_k <- if (share_mode == "F") theta0_k else
    .ai_capital_share(v, raw$shock$post_2030, year, start_year,
                      1 - raw$shock$baseline_labor_share)
  if (!is.numeric(theta1_k) || is.na(theta1_k) || theta1_k <= 0 || theta1_k >= 1) {
    cli::cli_abort(
      "Variant {.val {active}}: post-shock capital share {.field theta1_k} must be strictly inside (0, 1); got {.val {theta1_k}}. A typo like {.val 46.2} instead of {.val 0.462} would otherwise sail through."
    )
  }
  theta1_l <- 1 - theta1_k
  if (raw$shock$sector == "whole_economy") {
    nfb_gva_share <- 1
    labor_other   <- NA_real_
    theta0_l_economy <- theta0_l
    theta1_l_economy <- theta1_l
    g_k <- (theta1_k * (1 + g_y) - theta0_k) / theta0_k
    g_l <- (theta1_l * (1 + g_y) - theta0_l) / theta0_l
  } else {
    shares        <- .nipa_sector_shares(.read_receipt(config_dir, raw$shock$sector_file))
    labor_other   <- shares$labor_other
    nfb_gva_share <- shares$gva_share *
      .path_ratio(cbo_path, "real_gva_nfb_B2017", start_year, year) /
      .path_ratio(cbo_path, "real_gdp_B2017", start_year, year)
    labor0 <- theta0_l * nfb_gva_share + labor_other * (1 - nfb_gva_share)
    labor1 <- theta1_l * (nfb_gva_share + g_y) + labor_other * (1 - nfb_gva_share)
    theta0_l_economy <- labor0
    theta1_l_economy <- labor1 / (1 + g_y)
    g_l <- labor1 / labor0 - 1
    g_k <- (1 + g_y - labor1) / (1 - labor0) - 1
  }

  # CBO anchors for the year (GDP, revenue / GDP, corporate receipts /
  # GDP): the yaml's baseline-year scalars for a single-year window, the
  # fiscal year of the CBO budget path for an annual one.
  cbo_anchor <- if (raw$window == "single_year") {
    list(gdp_fy_B   = cbo$gdp_baseline_year_B,
         rev_to_gdp = cbo$rev_to_gdp_baseline_year,
         cit_to_gdp = cbo$cit_to_gdp_baseline_year)
  } else {
    budget <- .read_receipt(config_dir, cbo$budget_path_file)
    fy_row <- budget[budget$fy == year]
    if (nrow(fy_row) != 1L) cli::cli_abort("CBO budget path has no fiscal year {.val {year}}.")
    list(gdp_fy_B   = fy_row$gdp_fy_B,
         rev_to_gdp = fy_row$revenues_B / fy_row$gdp_fy_B,
         cit_to_gdp = fy_row$corporate_B / fy_row$gdp_fy_B)
  }

  k_inequality <- raw$labor_inequality$k

  retirement_cal_path <- file.path(dirname(path), "retirement_calibration.yaml")
  retirement_cal      <- load_retirement_calibration(retirement_cal_path)

  list(
    raw            = raw,
    setting        = setting,
    active_variant = active,
    share_mode     = share_mode,
    year           = year,
    theta0_l = theta0_l, theta0_k = theta0_k,
    theta1_l = theta1_l, theta1_k = theta1_k,
    g_y = g_y,
    r_ai_annual    = v$r_ai_annual,
    horizon        = horizon,
    cum_base       = cum_base,
    g_k = g_k, g_l = g_l,
    nfb_gva_share    = nfb_gva_share,
    labor_other      = labor_other,
    theta0_l_economy = theta0_l_economy,
    theta1_l_economy = theta1_l_economy,
    cbo_anchor       = cbo_anchor,
    k_inequality   = k_inequality,
    retirement_cal = retirement_cal
  )
}
