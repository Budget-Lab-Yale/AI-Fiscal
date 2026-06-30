# Shared helpers used across the pipeline and the smoke test / diagnostics.
# Source from each script; defines no globals beyond the named functions.

`%||%` <- function(x, y) if (is.null(x)) y else x

# Weighted unconditional quantile (upper step function — no
# interpolation). Returns the smallest x[i] whose cumulative weight
# share is >= p. Vectorized in `p`. Aborts on empty/NA/zero-weight
# input rather than returning NA silently: this feeds the SYZ W*
# threshold, and an NA here would cascade through y_l/y_k unseen.
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
fmt_pct <- function(x) sprintf("%6.2f%%", x * 100)

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
# Liability columns: loaded but excluded from the asset base (the
# allocation weights X by gross holdings, not by net worth).
.LIABILITY_COLS <- c(
  "primary_mortgage", "other_mortgage",
  "credit_lines", "credit_cards", "installment_debt", "other_debt"
)

.ASSET_KNOWN <- c(
  "cash", "equities", "bonds", "retirement", "life_ins", "annuities",
  "trusts", "other_fin", "pass_throughs",
  "primary_home", "other_home", "re_fund", "other_nonfin",
  "db",
  .LIABILITY_COLS
)

# The release pipeline uses the all-assets base exclusively: every known
# column except DB pension wealth (`db`) and the liabilities. Derived from
# .ASSET_KNOWN so a new vintage column only has to be added in one place.
.ASSET_BASE_ALL_ASSETS <- setdiff(.ASSET_KNOWN, c("db", .LIABILITY_COLS))

# Income-bearing asset classes for the within-unit allocation step.
# Names are the asset_class values in `config/asset_to_income_map.csv`;
# values are the corresponding (normalized) baseline columns.
.INCOME_BEARING_COLS <- c(
  public_equity_taxable = "equities",
  fixed_income          = "bonds",
  passthrough_equity    = "pass_throughs",
  retirement_dc_ira     = "retirement"
)

# --- Scenario-axis registry -----------------------------------------------
# Single source of truth for the release grid's axis codes and labels.
# Consumed by: release_specs() (00), .parse_scenario_axes() and
# .VARIANT_LABEL_MAP (09), .scenario_flavor()/.scenario_base() and the
# .build_scenario_guide() consistency check (08), .restore_axes() (10),
# and the BLSMM figure layer (15). Before the registry these six sites
# carried hand-synced literal vectors, and every mismatch failed by
# silent NA-coercion row drops rather than an error.
#
# Vectors are code -> label, in *code* (narrative) order. Note the
# scenario_guide presents labor rows in label order (Compressive,
# Proportional, Expansive) — that presentational ordering lives in
# .build_scenario_guide(), which is asserted against this registry.
.AXIS_VARIANTS    <- c(S  = "Slow",         M  = "Moderate",    R  = "Rapid")
.AXIS_SHARE_MODES <- c(R  = "Reallocate",   F  = "Fixed share")
.AXIS_LABOR       <- c(S0 = "Proportional", S2 = "Compressive", S3 = "Expansive")
.AXIS_REALIZATION <- c(V1 = "Mechanical")

# Decomposition flavor suffixes appended to scenario IDs (a de-facto
# fifth axis carried in the ID string; see CLAUDE.md).
.FLAVOR_SUFFIX_MAP <- c(LO = "labor_only", CO = "capital_only")

# Anchored regex matching exactly the canonical (suffix-free) scenario
# IDs this release can produce.
.scenario_id_regex <- function() {
  sprintf("^ai_(%s)_(%s)_(%s)_(%s)$",
          paste(names(.AXIS_VARIANTS),    collapse = "|"),
          paste(names(.AXIS_SHARE_MODES), collapse = "|"),
          paste(names(.AXIS_LABOR),       collapse = "|"),
          paste(names(.AXIS_REALIZATION), collapse = "|"))
}

# Anchored regex matching a registered flavor suffix at the end of an ID.
.flavor_suffix_regex <- function() {
  sprintf("_(%s)$", paste(names(.FLAVOR_SUFFIX_MAP), collapse = "|"))
}

# --- YBL brand kit (palette / theme / save) ------------------------------
# Canonical home for the shared brand assets so every output looks like a
# Budget Lab exhibit. 10_figures.R, 15_blsmm_debt_gdp.R, and
# paper_figure_data.R all consume these from here (this module is sourced
# first everywhere) instead of each carrying its own copy. The ggplot2 / cli
# references are inside function bodies, so utils stays load-light — they
# resolve only when a figure is actually rendered.
#
# Palette derived from pixel-sampling YBL's public Datawrapper charts and
# the budgetlab.yale.edu site chrome.

YBL_NAVY    <- "#101f5b"
YBL_BLUE    <- "#286dc0"
YBL_LIGHT   <- "#63aaff"
YBL_PALE    <- "#bcd4ea"
YBL_CYAN    <- "#18a1cd"
YBL_ORANGE  <- "#fa8c00"
YBL_RED     <- "#c5371e"
YBL_GRAY    <- "#4a4a4a"
YBL_MUTED   <- "#72a4d7"
YBL_TEXT    <- "#222222"
YBL_CAPTION <- "#666666"
YBL_GRID    <- "#e8e8e8"

# Variant on a sequential ramp (Slow=light -> Rapid=dark). Keyed by the
# *_label factor levels so scale_*_manual() positions colours by name, not
# by position. Shared across the figure suite and the appendix charts.
PAL_VARIANT <- c(Slow     = YBL_PALE,
                 Moderate = YBL_BLUE,
                 Rapid    = YBL_NAVY)

.fig_theme <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("ggplot2 is required to render figures.")
  }
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title          = ggplot2::element_text(
        face = "bold", size = 14, color = YBL_TEXT,
        margin = ggplot2::margin(b = 4)
      ),
      plot.subtitle       = ggplot2::element_text(
        size = 11, color = YBL_TEXT,
        margin = ggplot2::margin(b = 10)
      ),
      plot.caption        = ggplot2::element_text(
        size = 9, color = YBL_CAPTION, face = "italic", hjust = 0,
        margin = ggplot2::margin(t = 8)
      ),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      axis.title          = ggplot2::element_text(size = 10, color = YBL_TEXT),
      axis.text           = ggplot2::element_text(size = 9,  color = "#555555"),
      axis.ticks          = ggplot2::element_blank(),
      panel.grid.minor    = ggplot2::element_blank(),
      panel.grid.major.x  = ggplot2::element_blank(),
      panel.grid.major.y  = ggplot2::element_line(color = YBL_GRID, linewidth = 0.3),
      panel.spacing       = ggplot2::unit(1.1, "lines"),
      strip.text          = ggplot2::element_text(
        face = "bold", size = 10, color = YBL_TEXT,
        margin = ggplot2::margin(b = 4)
      ),
      strip.background    = ggplot2::element_blank(),
      legend.position     = "top",
      legend.justification = "left",
      legend.title        = ggplot2::element_text(size = 10, color = YBL_TEXT),
      legend.text         = ggplot2::element_text(size = 9,  color = YBL_TEXT),
      legend.margin       = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin   = ggplot2::margin(b = 4),
      plot.margin         = ggplot2::margin(12, 16, 12, 12)
    )
}

.fig_caption <- function(year, extra = NULL) {
  sprintf("Source: The Budget Lab at Yale AI-Fiscal microsimulation model, FY %d.",
          year)
}

# Strip title / subtitle / caption from a ggplot so it can be dropped into a
# paper where those live in the body text. Figures that carry equation-style
# axis labels can attach plain-prose overrides via attr(p, "clean_x") /
# attr(p, "clean_y"); setting the attribute to NA drops the axis label in the
# clean render. Kept here so .fig_save can emit both versions from one input.
.strip_for_paper <- function(plot) {
  p <- plot +
    ggplot2::labs(title = NULL, subtitle = NULL, caption = NULL) +
    ggplot2::theme(plot.title    = ggplot2::element_blank(),
                   plot.subtitle = ggplot2::element_blank(),
                   plot.caption  = ggplot2::element_blank())
  cx <- attr(plot, "clean_x")
  cy <- attr(plot, "clean_y")
  if (!is.null(cx)) p <- p + ggplot2::xlab(if (is.na(cx)) NULL else cx)
  if (!is.null(cy)) p <- p + ggplot2::ylab(if (is.na(cy)) NULL else cy)
  p
}

# Save a ggplot as PNG (web). Emits two PNGs per figure: the full version
# (title / subtitle / caption present, for review) and a "_clean" version
# with those stripped (for embedding in a paper that supplies its own title
# and notes). Both renders share the same dimensions.
.fig_save <- function(plot, out_dir, slug, year, w = 6.5, h = 4.5) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  full_fp  <- file.path(out_dir, sprintf("%s_%d.png", slug, year))
  clean_fp <- file.path(out_dir, sprintf("%s_%d_clean.png", slug, year))
  ggplot2::ggsave(full_fp,  plot,
                  width = w, height = h, dpi = 200, bg = "white")
  ggplot2::ggsave(clean_fp, .strip_for_paper(plot),
                  width = w, height = h, dpi = 200, bg = "white")
  invisible(c(full = full_fp, clean = clean_fp))
}
