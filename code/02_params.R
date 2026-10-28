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
  "baseline_year",
  paste0("cbo_baseline.",
         c("horizon_start_year", "g_2026", "g_2027plus",
           "gdp_baseline_year_B", "rev_to_gdp_baseline_year",
           "cit_to_gdp_baseline_year", "growth_path", "path_file")),
  paste0("shock.",
         c("baseline_labor_share", "share_baseline", "sector", "sector_file")),
  unlist(lapply(c("S", "M", "R"), function(v) {
    sprintf("shock.variants.%s.%s", v, c("theta1_k", "r_ai_annual"))
  })),
  "labor_inequality.k",
  "capital_flow.allocation_base",
  "capital_flow.interest",
  paste0("passthrough.",
         c("wage_threshold_percentile", "wage_threshold_conditioning",
           "active_below_capital_share", "active_above_capital_share",
           "passive_capital_share")),
  paste0("corporate.",
         c("kappa_corp", "cit_statutory"))
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

# Allowed values of the rung-1 switches; the first is the v1.0.1 value.
.SWITCH_VALUES <- list(
  "cbo_baseline.growth_path" = c("flat", "annual"),
  "shock.share_baseline"     = c("survey_2025", "projected"),
  "shock.sector"             = c("whole_economy", "nonfarm_business"),
  "capital_flow.allocation_base" = c("all_assets", "ex_home_cash_nonfin"),
  "capital_flow.interest"    = c("by_holdings", "baseline_path")
)

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
                        setting = .LEGACY_SETTING) {
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
    raw <- .apply_setting_overlay(raw, .read_setting_overlay(setting, path),
                                  setting)
  }

  active <- variant %||% "M"
  if (!active %in% names(raw$shock$variants)) {
    cli::cli_abort(c(
      "Variant {.val {active}} is not a defined shock variant.",
      i = "Choose one of {.val {names(raw$shock$variants)}} in {.path {path}}."
    ))
  }
  v <- raw$shock$variants[[active]]

  baseline_year <- raw$baseline_year
  start_year    <- raw$cbo_baseline$horizon_start_year
  horizon       <- baseline_year - start_year
  if (horizon < 1) {
    cli::cli_abort(c(
      "Karger horizon must be at least 1 year.",
      x = "baseline_year ({.val {baseline_year}}) <= cbo_baseline.horizon_start_year ({.val {start_year}}).",
      i = "Set baseline_year > horizon_start_year in {.path {path}}."
    ))
  }
  .validate_switches(raw)
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
    cum_base <- .path_ratio(cbo_path, "real_gdp_B2017", start_year, baseline_year)
  }
  if (!is.numeric(v$r_ai_annual) || is.na(v$r_ai_annual) || v$r_ai_annual <= -1) {
    cli::cli_abort(
      "Variant {.val {active}}: {.field r_ai_annual} must be a number > -1 (got {.val {v$r_ai_annual}})."
    )
  }
  g_y        <- (1 + v$r_ai_annual)^horizon / cum_base - 1

  theta0_l <- raw$shock$baseline_labor_share
  if (raw$shock$share_baseline == "projected") {
    comp_share <- cbo_path$comp_paid_B / cbo_path$gdp_B
    theta0_l   <- theta0_l + comp_share[match(baseline_year, cbo_path$year)] -
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
  theta1_k <- if (share_mode == "F") theta0_k else v$theta1_k
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
      .path_ratio(cbo_path, "real_gva_nfb_B2017", start_year, baseline_year) /
      .path_ratio(cbo_path, "real_gdp_B2017", start_year, baseline_year)
    labor0 <- theta0_l * nfb_gva_share + labor_other * (1 - nfb_gva_share)
    labor1 <- theta1_l * (nfb_gva_share + g_y) + labor_other * (1 - nfb_gva_share)
    theta0_l_economy <- labor0
    theta1_l_economy <- labor1 / (1 + g_y)
    g_l <- labor1 / labor0 - 1
    g_k <- (1 + g_y - labor1) / (1 - labor0) - 1
  }

  k_inequality <- raw$labor_inequality$k

  retirement_cal_path <- file.path(dirname(path), "retirement_calibration.yaml")
  retirement_cal      <- load_retirement_calibration(retirement_cal_path)

  list(
    raw            = raw,
    setting        = setting,
    active_variant = active,
    share_mode     = share_mode,
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
    k_inequality   = k_inequality,
    retirement_cal = retirement_cal
  )
}
