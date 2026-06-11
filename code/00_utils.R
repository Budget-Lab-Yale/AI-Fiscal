# Shared helpers used across the pipeline and the smoke test / diagnostics.
# Source from each script; defines no globals beyond the named functions.

`%||%` <- function(x, y) if (is.null(x)) y else x

# Weighted unconditional quantile (upper step function — no
# interpolation). Returns the smallest x[i] whose cumulative weight
# share is >= p. Vectorized in `p`. Aborts on empty/NA/zero-weight
# input rather than returning NA silently: this feeds the SYZ W*
# threshold, and an NA here would cascade through YiL/YiK unseen.
weighted_quantile <- function(x, w, p) {
  if (!length(x) || length(x) != length(w)) {
    cli::cli_abort(
      "weighted_quantile: {.arg x} must be non-empty and the same length as {.arg w} (got {length(x)} vs {length(w)})."
    )
  }
  if (anyNA(x) || anyNA(w)) {
    cli::cli_abort(
      "weighted_quantile: NA in {.arg x} ({sum(is.na(x))}) or {.arg w} ({sum(is.na(w))}); filter before calling."
    )
  }
  total_w <- sum(w)
  if (total_w <= 0) {
    cli::cli_abort("weighted_quantile: total weight is non-positive ({total_w}).")
  }
  ord <- order(x)
  x_sorted <- x[ord]
  w_sorted <- w[ord]
  cw <- cumsum(w_sorted) / total_w
  # Float-proof the tail: accumulated rounding can leave max(cw) just
  # under 1, making p = 1 (or p > max(cw)) return NA.
  cw[length(cw)] <- 1
  vapply(p, function(pi) x_sorted[which(cw >= pi)[1]], numeric(1))
}

# Weighted top-share: the share of sum(w * x) held by the top `top_pct`
# fraction of weighted units. Used for distributional sanity checks.
weighted_top_share <- function(x, w, top_pct) {
  ord <- order(-x)
  x_sorted <- x[ord]
  w_sorted <- w[ord]
  cw <- cumsum(w_sorted) / sum(w_sorted)
  in_top <- cw <= top_pct
  if (!any(in_top)) in_top[1] <- TRUE
  sum(w_sorted[in_top] * x_sorted[in_top]) / sum(w_sorted * x_sorted)
}

# Weighted Gini coefficient. Standard convention: drops non-positive
# incomes (Gini is ill-defined when total income is non-positive and
# negative entries can push the coefficient outside [0, 1]). For a
# strictly non-negative distribution, returns a value in [0, 1].
weighted_gini <- function(x, w) {
  keep <- !is.na(x) & !is.na(w) & x > 0 & w > 0
  x <- x[keep]; w <- w[keep]
  ord <- order(x)
  x <- x[ord]; w <- w[ord]
  cw <- cumsum(w) / sum(w)
  cy <- cumsum(w * x) / sum(w * x)
  cw_lag <- c(0, head(cw, -1))
  cy_lag <- c(0, head(cy, -1))
  1 - sum((cw - cw_lag) * (cy + cy_lag))
}

# Money formatters for diagnostics output.
fmt_T <- function(x) sprintf("%9.3fT", x / 1e12)
fmt_B <- function(x) sprintf("%9.2fB", x / 1e9)
fmt_M <- function(x) sprintf("%9.2fM", x / 1e6)
fmt_pct <- function(x) sprintf("%6.2f%%", x * 100)

fmt_money <- function(x) {
  if (abs(x) >= 1e12) {
    fmt_T(x)
  } else if (abs(x) >= 1e9) {
    fmt_B(x)
  } else {
    fmt_M(x)
  }
}

# Section header for diagnostic / smoke-test output.
section <- function(title, width = 70) {
  rule <- strrep("-", width)
  cat("\n", rule, "\n", title, "\n", rule, "\n", sep = "")
}

# Short git rev of a repo (or "—" if unavailable). Used by 08_aggregate.R's
# run-metadata sheet and the orchestrator pre-flight banner. Lives here so
# both callers reach it through the always-sourced-first utils module
# instead of one reaching into the other's file.
.git_short_rev <- function(repo = getwd(), n = 12L) {
  rev <- tryCatch(
    suppressWarnings(system2(
      "git", c("-C", repo, "rev-parse", "HEAD"),
      stdout = TRUE, stderr = FALSE
    ))[1],
    error = function(e) NA_character_
  )
  if (length(rev) && !is.na(rev) && nzchar(rev)) substr(rev, 1, n) else "—"
}

# --- Asset / wealth column registry --------------------------------------
# Single source of truth for the wealth-column universe carried on the
# merged Tax-Data baseline file (post-normalization by load_tax_units():
# `value.` prefix stripped; `dc` → `retirement`). 01_load_data.R warns at
# load time if a vintage carries a `value.*` column not in .ASSET_KNOWN;
# 04_allocate_capital.R reads .ASSET_BASE_ALL_ASSETS and
# .INCOME_BEARING_COLS for the across-unit and within-unit allocation
# steps.
#
# `db` (DB pension wealth) is in .ASSET_KNOWN so the unknown-column
# warning doesn't fire on it, but is NOT in the asset base — see model
# doc §13. Liability columns are loaded but excluded from the asset
# base (the allocation weights X by gross holdings, not by net worth).
.ASSET_KNOWN <- c(
  "cash", "equities", "bonds", "retirement", "life_ins", "annuities",
  "trusts", "other_fin", "pass_throughs",
  "primary_home", "other_home", "re_fund", "other_nonfin",
  "db",
  "primary_mortgage", "other_mortgage",
  "credit_lines", "credit_cards", "installment_debt", "other_debt"
)

# The release pipeline uses the all-assets base exclusively.
.ASSET_BASE_ALL_ASSETS <- c(
  "cash", "equities", "bonds", "retirement", "life_ins", "annuities",
  "trusts", "other_fin", "pass_throughs",
  "primary_home", "other_home", "re_fund", "other_nonfin"
)

# Income-bearing asset classes for the within-unit allocation step.
# Names are the asset_class values in `config/asset_to_income_map.csv`;
# values are the corresponding (normalized) baseline columns.
.INCOME_BEARING_COLS <- c(
  public_equity_taxable = "equities",
  fixed_income          = "bonds",
  passthrough_equity    = "pass_throughs",
  retirement_dc_ira     = "retirement"
)
