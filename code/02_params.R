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
# `share_mode` selects the factor-evolution counterfactual:
#   R (default): reallocate — use the Karger post-shock capital share
#                theta1_k for the chosen variant so the labor share falls.
#   F          : fixed share — override theta1_k := theta0_k so the post-shock
#                capital share equals baseline. g_k = g_l = g_y.
#
# load_params() validates that every required key is present and aborts with
# a list of any gaps.

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
           "cit_to_gdp_baseline_year")),
  "shock.baseline_labor_share",
  unlist(lapply(c("S", "M", "R"), function(v) {
    sprintf("shock.variants.%s.%s", v, c("theta1_k", "r_ai_annual"))
  })),
  "labor_inequality.k",
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
                        variant = NULL, share_mode = "R") {
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
  g_2026     <- raw$cbo_baseline$g_2026
  g_2027plus <- raw$cbo_baseline$g_2027plus
  cum_base   <- (1 + g_2026) * (1 + g_2027plus)^(horizon - 1)
  if (!is.numeric(v$r_ai_annual) || is.na(v$r_ai_annual) || v$r_ai_annual <= -1) {
    cli::cli_abort(
      "Variant {.val {active}}: {.field r_ai_annual} must be a number > -1 (got {.val {v$r_ai_annual}})."
    )
  }
  g_y        <- (1 + v$r_ai_annual)^horizon / cum_base - 1

  theta0_l <- raw$shock$baseline_labor_share
  if (!is.numeric(theta0_l) || is.na(theta0_l) || theta0_l <= 0 || theta0_l >= 1) {
    cli::cli_abort(
      "{.field shock.baseline_labor_share} must be strictly inside (0, 1); got {.val {theta0_l}}."
    )
  }
  theta0_k <- 1 - theta0_l
  # Under share_mode = "F" we pin the post-shock capital share to baseline
  # (theta1_k := theta0_k) so the labor-capital split is preserved while g_y
  # is unchanged. g_k and g_l both collapse to g_y.
  theta1_k <- if (share_mode == "F") theta0_k else v$theta1_k
  if (!is.numeric(theta1_k) || is.na(theta1_k) || theta1_k <= 0 || theta1_k >= 1) {
    cli::cli_abort(
      "Variant {.val {active}}: post-shock capital share {.field theta1_k} must be strictly inside (0, 1); got {.val {theta1_k}}. A typo like {.val 46.2} instead of {.val 0.462} would otherwise sail through."
    )
  }
  theta1_l <- 1 - theta1_k
  g_k <- (theta1_k * (1 + g_y) - theta0_k) / theta0_k
  g_l <- (theta1_l * (1 + g_y) - theta0_l) / theta0_l

  k_inequality <- raw$labor_inequality$k

  retirement_cal_path <- file.path(dirname(path), "retirement_calibration.yaml")
  retirement_cal      <- load_retirement_calibration(retirement_cal_path)

  list(
    raw            = raw,
    active_variant = active,
    share_mode     = share_mode,
    theta0_l = theta0_l, theta0_k = theta0_k,
    theta1_l = theta1_l, theta1_k = theta1_k,
    g_y = g_y,
    r_ai_annual    = v$r_ai_annual,
    horizon        = horizon,
    cum_base       = cum_base,
    g_k = g_k, g_l = g_l,
    k_inequality   = k_inequality,
    retirement_cal = retirement_cal
  )
}
