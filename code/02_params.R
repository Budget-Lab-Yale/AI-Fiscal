# Read scenario_params.yaml and resolve the active variant. Derives the
# overall AI growth bump gy from r_ai_annual (Karger Table 19) and the CBO
# baseline path, then the factor-evolution scalars (gk, alpha) from (s1, gy, L0):
#   horizon  = baseline_year - cbo_baseline.horizon_start_year   (= 5 for 2030)
#   cum_base = (1 + g_2026) * (1 + g_2027plus)^(horizon - 1)
#   gy       = (1 + r_ai_annual)^horizon / cum_base - 1
#   K0    = 1 - L0
#   K1    = s1 * (1 + gy)
#   L1    = (1 - s1) * (1 + gy)
#   gk    = (K1 - K0) / K0
#   alpha = (1 / gk) * (L1 - L0) / L0
#
# `share_mode` selects the factor-evolution counterfactual:
#   R (default): reallocate — use the Karger s1 for the chosen variant
#                so the labor share falls toward s1.
#   F          : fixed share — override s1 := 1 - L0 so the post-shock
#                capital share equals baseline. gk = gy, alpha = 1.
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
    sprintf("shock.variants.%s.%s", v, c("s1", "r_ai_annual"))
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
  gy         <- (1 + v$r_ai_annual)^horizon / cum_base - 1

  L0 <- raw$shock$baseline_labor_share
  if (!is.numeric(L0) || is.na(L0) || L0 <= 0 || L0 >= 1) {
    cli::cli_abort(
      "{.field shock.baseline_labor_share} must be strictly inside (0, 1); got {.val {L0}}."
    )
  }
  K0 <- 1 - L0
  # Under share_mode = "F" we pin the post-shock capital share to baseline
  # (s1 := 1 - L0 = K0) so the labor-capital split is preserved while gy
  # is unchanged. gk collapses to gy and alpha to 1.
  s1 <- if (share_mode == "F") K0 else v$s1
  if (!is.numeric(s1) || is.na(s1) || s1 <= 0 || s1 >= 1) {
    cli::cli_abort(
      "Variant {.val {active}}: post-shock capital share {.field s1} must be strictly inside (0, 1); got {.val {s1}}. A typo like {.val 46.2} instead of {.val 0.462} would otherwise sail through."
    )
  }
  K1 <- s1 * (1 + gy)
  L1 <- (1 - s1) * (1 + gy)
  gk <- (K1 - K0) / K0
  alpha <- if (gk == 0) NA_real_ else (1 / gk) * (L1 - L0) / L0

  k_inequality <- raw$labor_inequality$k

  retirement_cal_path <- file.path(dirname(path), "retirement_calibration.yaml")
  retirement_cal      <- load_retirement_calibration(retirement_cal_path)

  list(
    raw            = raw,
    active_variant = active,
    share_mode     = share_mode,
    L0 = L0, K0 = K0,
    s1 = s1, gy = gy,
    r_ai_annual    = v$r_ai_annual,
    horizon        = horizon,
    cum_base       = cum_base,
    K1 = K1, L1 = L1,
    gk = gk, alpha = alpha,
    k_inequality   = k_inequality,
    retirement_cal = retirement_cal
  )
}
