# Publishable figure suite for the AI-fiscal deliverables.
#
# Inputs (under `agg_dir`, default results/aggregates/):
#   - revenue_grid_<year>.csv, revenue_grid_wide_<year>.csv,
#     decile_panel_<year>.csv                          (from 09)
#   - revenue_deltas_<year>.csv, share_deltas_<year>.csv,
#     gini_deltas_<year>.csv, income_deltas_<year>.csv,
#     revenue_decomp_<year>.csv                        (from 08)
#   - <runscript_basename>_macro.csv                   (from 00)
#
# Outputs (under `out_dir`, default results/figures/<year>/): one PNG + PDF
# per figure, sized for a YBL-style policy brief, plus a single
# figure_data_<year>.xlsx with one sheet per figure carrying the data
# behind the chart (use the table in place of or alongside the figure).
#
# Palette is derived from pixel-sampling YBL's public Datawrapper
# charts and the budgetlab.yale.edu site chrome. Each plot uses a
# semantic scale (variant=sequential blue, labor=qualitative,
# realization=qualitative) so colour carries meaning across the suite.

suppressPackageStartupMessages({
  library(data.table)
})

# Self-bootstrap so `Rscript code/10_figures.R` works standalone. Under the
# orchestrator (00_ai_fiscal_sim.R) these sources are redundant — 08 and 09
# have already been loaded — but they're cheap and idempotent (no top-level
# side effects fire thanks to the `sys.nframe() == 0L` entry guards in
# those files).
source("code/00_utils.R")
source("code/08_aggregate.R")
source("code/09_tables_figures.R")

# ---------------------------------------------------------------------
# Palette + theme
# ---------------------------------------------------------------------

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

# Variant on a sequential ramp (Slow=light → Rapid=dark). Keyed by the
# *_label factor levels so scale_*_manual() positions colours by name,
# not by position — reordering the factor in .attach_axis_labels won't
# silently recolour the chart.
PAL_VARIANT     <- c(Slow     = YBL_PALE,
                     Moderate = YBL_BLUE,
                     Rapid    = YBL_NAVY)

# Labor map: cool for compressive (pulls toward mean), warm for
# expansive (pulls apart), neutral for proportional, muted for the
# AI-exposure map (implemented in 03_shock_labor.R but gated on an
# optional `ai_exposure` column — present only when the input file
# carries CPS occ × Eloundou exposure scores).
PAL_LABOR       <- c(Proportional  = YBL_GRAY,
                     `AI-exposure` = YBL_MUTED,
                     Compressive   = YBL_CYAN,
                     Expansive     = YBL_ORANGE)

# Shape palette keyed by labor-map label so reordering the factor levels
# in .attach_axis_labels can't silently remap shapes.
PAL_LABOR_SHAPE <- c(Proportional  = 16,
                     `AI-exposure` = 15,
                     Compressive   = 17,
                     Expansive     = 18)


# Decomposition components.
PAL_DECOMP      <- c("labor"       = YBL_CYAN,
                     "capital"     = YBL_ORANGE,
                     "interaction" = YBL_MUTED,
                     "macro_cit"   = YBL_NAVY)

# Top-line revenue vs macro CIT for the headline split chart.
PAL_SPLIT       <- c("Microsim total" = YBL_BLUE,
                     "Macro CIT"      = YBL_ORANGE)

# Instrument breakdown (microsim instruments).
PAL_INSTRUMENT  <- c("revenues_payroll_tax"   = YBL_BLUE,
                     "revenues_income_tax"    = YBL_NAVY,
                     "outlays_tax_credits"    = YBL_RED,
                     "revenues_estate_tax"    = YBL_MUTED,
                     "revenues_vat"           = YBL_GRAY,
                     "revenues_other"         = YBL_PALE,
                     "revenues_corp_tax"      = YBL_LIGHT,
                     "macro_cit_delta"        = YBL_ORANGE)

INSTRUMENT_LABEL <- c(
  revenues_payroll_tax = "Payroll",
  revenues_income_tax  = "Income tax",
  outlays_tax_credits  = "Tax credits (outlay)",
  revenues_estate_tax  = "Estate",
  revenues_vat         = "VAT",
  revenues_other       = "Other",
  revenues_corp_tax    = "Corp tax (microsim)",
  macro_cit_delta      = "Macro CIT"
)

.fig_theme <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("ggplot2 is required for code/10_figures.R.")
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

# Heatmap / decomp variants need vertical gridlines too.
# TODO: currently unused — apply to fig_sensitivity_heatmap / fig_decomp or drop.
.fig_theme_grid <- function() {
  .fig_theme() + ggplot2::theme(
    panel.grid.major.x = ggplot2::element_line(color = YBL_GRID, linewidth = 0.3),
    panel.grid.major.y = ggplot2::element_line(color = YBL_GRID, linewidth = 0.3)
  )
}

.dollar_B <- function(x) {
  sign  <- ifelse(x < 0, "-", "")
  paste0(sign, "$", formatC(abs(x), format = "f", big.mark = ",", digits = 0), "B")
}

# When a figure facets on `realization_label` and only one realization is
# present in `d`, the strip text is redundant. Returns a theme override
# (or NULL) to be added to the ggplot. `axis = "y"` for facet_grid rows,
# `"x"` for facet_wrap(~ realization_label).
.suppress_real_strip_if_single <- function(d, axis = c("y", "x")) {
  axis <- match.arg(axis)
  if (length(unique(d$realization_label)) > 1L) return(NULL)
  if (axis == "y") {
    ggplot2::theme(
      strip.text.y       = ggplot2::element_blank(),
      strip.background.y = ggplot2::element_blank()
    )
  } else {
    ggplot2::theme(
      strip.text.x       = ggplot2::element_blank(),
      strip.background.x = ggplot2::element_blank()
    )
  }
}

# TODO: currently unused — figs build pp labels inline via sprintf. Adopt this helper or drop.
.pct_pp <- function(x, digits = 1) {
  sprintf("%+.*f pp", digits, 100 * x)
}

.fig_caption <- function(year, extra = NULL) {
  sprintf("Source: The Budget Lab at Yale AI-Fiscal microsimulation model, FY %d.",
          year)
}

# Strip title / subtitle / caption from a ggplot so it can be dropped
# into a paper where those live in the body text. Kept as a helper so
# .fig_save can emit both versions from one render input.
#
# Figures that carry equation-style axis labels in their full version
# can attach plain-prose overrides via attr(p, "clean_x") and
# attr(p, "clean_y"); .strip_for_paper applies those to the clean
# render so paper exhibits read without LaTeX-y notation. Setting the
# attribute to NA explicitly drops the axis label in the clean render
# (use when no replacement makes sense).
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

# Save a ggplot as PNG (web). PDF outputs were dropped — every consumer
# rasterises anyway, and the PDFs doubled the diff size on every run.
# Emits two PNGs per figure: the full version (title / subtitle /
# caption present, for review) and a "_clean" version with those text
# elements stripped (for embedding in a paper that supplies its own
# title and notes). Both renders share the same dimensions; the clean
# version's panel naturally expands to fill the freed space.
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

# Wrap a fig_*() return value (list(plot, data), or NULL when the function
# bailed on missing rows) into a render-list entry. Keeps assemble_figures
# tidy and gives a single place to handle the NULL case.
.fig_entry <- function(slug, result, w, h) {
  if (is.null(result)) {
    list(slug = slug, plot = NULL, data = NULL, w = w, h = h)
  } else {
    list(slug = slug, plot = result$plot, data = result$data, w = w, h = h)
  }
}

# Emit one .xlsx with one sheet per figure carrying the plotted data.
# Each sheet now leads with the figure's title / subtitle / notes
# (pulled from the ggplot object's labels) so the workbook is fully
# self-describing — no need to cross-reference the rendered PNG when
# someone is reading the numbers.
#
# Layout (per sheet):
#   Row 1: "Title:"    | <plot$labels$title>
#   Row 2: "Subtitle:" | <plot$labels$subtitle>
#   Row 3: "Notes:"    | <plot$labels$caption>   (multi-line OK)
#   Row 4: (blank)
#   Row 5: column headers (bold, light grey)
#   Row 6+: data
#
# Skips entries whose data is NULL or empty. Sheet name = figure slug,
# truncated to Excel's 31-char limit. Only one sheet per figure even
# though .fig_save emits both a full and a _clean PNG — the data is
# identical, so duplicating sheets would be noise.
.write_figure_data_excel <- function(figs, out_dir, year) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    cli::cli_warn(c(
      "{.pkg openxlsx} not installed; skipping figure-data .xlsx.",
      i = "Install with {.code install.packages('openxlsx')} to enable."
    ))
    return(invisible(NULL))
  }
  wb <- openxlsx::createWorkbook()
  hdr <- openxlsx::createStyle(textDecoration = "bold",
                               fgFill = "#f0f0f0",
                               border = "bottom")
  meta_label <- openxlsx::createStyle(textDecoration = "bold",
                                       valign = "top")
  meta_value <- openxlsx::createStyle(wrapText = TRUE, valign = "top")

  .lab <- function(p, name) {
    v <- p$labels[[name]]
    if (is.null(v) || identical(v, ggplot2::waiver())) "" else as.character(v)
  }

  n_written <- 0L
  for (f in figs) {
    if (is.null(f$data) || !nrow(f$data)) next
    sheet <- substr(f$slug, 1, 31)
    openxlsx::addWorksheet(wb, sheet)

    title    <- .lab(f$plot, "title")
    subtitle <- .lab(f$plot, "subtitle")
    notes    <- .lab(f$plot, "caption")
    meta <- data.frame(
      field = c("Title:", "Subtitle:", "Notes:"),
      value = c(title, subtitle, notes),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, sheet, meta, colNames = FALSE,
                        startRow = 1, startCol = 1)
    openxlsx::addStyle(wb, sheet, meta_label, rows = 1:3, cols = 1,
                       gridExpand = TRUE)
    openxlsx::addStyle(wb, sheet, meta_value, rows = 1:3, cols = 2,
                       gridExpand = TRUE)

    data_start <- 5L  # row 4 left blank
    openxlsx::writeData(wb, sheet, f$data, headerStyle = hdr,
                        startRow = data_start, startCol = 1)
    openxlsx::freezePane(wb, sheet, firstActiveRow = data_start + 1L)
    n_cols <- max(2L, ncol(f$data))
    openxlsx::setColWidths(wb, sheet, cols = seq_len(n_cols),
                           widths = "auto")
    n_written <- n_written + 1L
  }
  if (!n_written) {
    cli::cli_warn("No figure data to write; .xlsx skipped.")
    return(invisible(NULL))
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  fp <- file.path(out_dir, sprintf("figure_data_%d.xlsx", year))
  openxlsx::saveWorkbook(wb, fp, overwrite = TRUE)
  cli::cli_inform("Wrote {.path {fp}} ({n_written} sheet{?s})")
  invisible(fp)
}

# ---------------------------------------------------------------------
# 1. Headline ΔR grid
# ---------------------------------------------------------------------

fig_headline_revenue <- function(wide, year) {
  d <- wide[, .(scenario_id, variant, variant_label, labor, labor_label,
                realization, realization_label, total_with_macro_cit)]
  p <- ggplot2::ggplot(
    d,
    ggplot2::aes(x = labor_label,
                 y = total_with_macro_cit,
                 fill = variant_label)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_wrap(~ realization_label, ncol = length(unique(d$realization_label))) +
    ggplot2::scale_fill_manual(values = PAL_VARIANT, name = "Shock variant") +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "AI-fiscal revenue impact, all scenarios",
      subtitle = sprintf("Total ΔR including macro corporate-tax wedge, FY %d ($B)", year),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "x")
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 2. Microsim total vs macro CIT split, per cell
# ---------------------------------------------------------------------

fig_macro_cit_split <- function(wide, year) {
  d <- data.table::copy(wide)
  data.table::setnames(d, "total", "microsim_total")
  d <- data.table::melt(
    d,
    id.vars      = c("scenario_id",
                     "variant", "variant_label",
                     "labor",   "labor_label",
                     "realization", "realization_label"),
    measure.vars = c("microsim_total", "macro_cit_delta"),
    variable.name = "component", value.name = "delta_B"
  )
  d[, component := factor(
    ifelse(component == "microsim_total", "Microsim total", "Macro CIT"),
    levels = c("Microsim total", "Macro CIT")
  )]

  p <- ggplot2::ggplot(d, ggplot2::aes(x = labor_label, y = delta_B, fill = component)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_grid(realization_label ~ variant_label) +
    ggplot2::scale_fill_manual(values = unname(PAL_SPLIT), name = NULL) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Microsim vs macro corporate-tax contribution",
      subtitle = sprintf("Stacked ΔR per cell, FY %d ($B)", year),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "y")
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 3. Instrument breakdown (microsim instruments) per cell
# ---------------------------------------------------------------------

fig_instrument_breakdown <- function(long, year) {
  keep_instruments <- c("revenues_payroll_tax", "revenues_income_tax",
                        "outlays_tax_credits", "revenues_estate_tax",
                        "revenues_vat", "revenues_other",
                        "macro_cit_delta")
  d <- long[instrument %in% keep_instruments]
  # Drop instruments with no movement across any cell (e.g. VAT/Estate/Other
  # when the policy leaves them untouched). 1e-6 catches FP noise; anything
  # above that round-trips back into the bar.
  nonzero <- d[, .(keep = any(abs(delta) > 1e-6)), by = instrument][keep == TRUE, instrument]
  keep_instruments <- intersect(keep_instruments, as.character(nonzero))
  d <- d[instrument %in% keep_instruments]
  d[, instrument := factor(instrument, levels = keep_instruments)]
  d[, instrument_label := factor(INSTRUMENT_LABEL[as.character(instrument)],
                                  levels = INSTRUMENT_LABEL[keep_instruments])]

  p <- ggplot2::ggplot(d, ggplot2::aes(x = labor_label, y = delta, fill = instrument_label)) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_grid(realization_label ~ variant_label) +
    ggplot2::scale_fill_manual(
      values = unname(PAL_INSTRUMENT[keep_instruments]),
      name = NULL
    ) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Revenue change by instrument",
      subtitle = sprintf("Stacked ΔR, FY %d ($B). Tax credits enter as a negative bar (outlay).", year),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "y") +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 1, byrow = TRUE))
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 4. Labor / capital / interaction decomposition (+ macro CIT)
# ---------------------------------------------------------------------

fig_decomp <- function(decomp, macro_per_scn, axes, year) {
  d <- decomp[instrument == "total"]
  d <- merge(d, axes[, .(scenario_id, variant, labor, realization)],
             by = "scenario_id", all.x = TRUE)
  d <- merge(d, macro_per_scn[, .(scenario_id, delta_R_CIT)],
             by = "scenario_id", all.x = TRUE)
  d <- d[!is.na(variant)]
  .attach_axis_labels(d)
  long <- data.table::melt(
    d,
    id.vars      = c("scenario_id",
                     "variant", "variant_label",
                     "labor",   "labor_label",
                     "realization", "realization_label"),
    measure.vars = c("delta_labor", "delta_capital", "interaction",
                     "delta_R_CIT"),
    variable.name = "component", value.name = "delta_B"
  )
  long[, component := factor(
    sub("delta_", "",
        sub("delta_R_CIT", "macro_cit", as.character(component))),
    levels = c("labor", "capital", "interaction", "macro_cit")
  )]
  component_label <- c(labor = "Labor", capital = "Capital",
                      interaction = "Interaction", macro_cit = "Macro CIT")
  long[, component_label := factor(component_label[as.character(component)],
                                    levels = component_label)]

  p <- ggplot2::ggplot(long, ggplot2::aes(x = labor_label, y = delta_B,
                                      fill = component_label)) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_grid(realization_label ~ variant_label) +
    ggplot2::scale_fill_manual(values = unname(PAL_DECOMP), name = NULL) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Revenue decomposition: labor, capital, interaction, macro CIT",
      subtitle = sprintf("ΔR contribution per side, FY %d ($B). Interaction = T(both) − T(labor) − T(capital).", year),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(long, "y") +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 1))
  list(plot = p, data = long)
}

# ---------------------------------------------------------------------
# 5. Decile incidence — pretax & aftertax share deltas
# ---------------------------------------------------------------------
# Faceting the full grid (3 variants × 3 labor × 2 realization × 2 income
# × 10 deciles) yields 18+ panels that are unreadable at one page. We
# pin to a single realization (V1 mechanical — the only realization in
# feed) so the chart can fit the page; pass `realization_code` to flip.

fig_decile_incidence <- function(decile, year, realization_code = "V1") {
  d <- decile[realization == realization_code]
  if (!nrow(d)) {
    cli::cli_warn("No decile rows for realization = {.val {realization_code}}; skipping.")
    return(invisible(NULL))
  }
  real_name <- as.character(unique(d$realization_label))

  p <- ggplot2::ggplot(d, ggplot2::aes(x = decile, y = delta,
                                   fill = variant_label)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.85),
                      width = 0.78) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_grid(income_concept ~ labor_label) +
    ggplot2::scale_fill_manual(values = PAL_VARIANT, name = "Shock variant") +
    ggplot2::scale_x_continuous(breaks = c(1, 5, 10)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%+.1f pp", 100 * x)) +
    ggplot2::labs(
      title    = "Distributional incidence by decile",
      subtitle = sprintf(
        "Change in within-scenario income share by decile, FY %d (pp). Realization: %s.",
        year, real_name
      ),
      x        = "Decile (1 = lowest)", y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme()
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 6. Top-share concentration shift
# ---------------------------------------------------------------------
# Pinned to a single realization (V1) for the same readability
# reason as fig_decile_incidence.

fig_top_share <- function(shares_long, axes, year, realization_code = "V1") {
  d <- shares_long[group_type == "top"]
  d <- merge(d, axes[, .(scenario_id, variant, labor, realization)],
             by = "scenario_id", all.x = TRUE)
  d <- d[!is.na(variant) & realization == realization_code]
  if (!nrow(d)) {
    cli::cli_warn("No top-share rows for realization = {.val {realization_code}}; skipping.")
    return(invisible(NULL))
  }
  .attach_axis_labels(d)
  real_name <- as.character(unique(d$realization_label))

  group_label <- c(top_10_pct  = "Top 10%",
                   top_5_pct   = "Top 5%",
                   top_1_pct   = "Top 1%",
                   top_0.1_pct = "Top 0.1%")
  d[, group_label := factor(group_label[as.character(group)],
                             levels = unname(group_label))]

  p <- ggplot2::ggplot(d, ggplot2::aes(x = group_label, y = delta,
                                   fill = variant_label)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.7) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_grid(income_concept ~ labor_label) +
    ggplot2::scale_fill_manual(values = PAL_VARIANT, name = "Shock variant") +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%+.1f pp", 100 * x)) +
    ggplot2::labs(
      title    = "Concentration shift at the top",
      subtitle = sprintf(
        "Change in income share held by top groups, FY %d (pp). Realization: %s.",
        year, real_name
      ),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme()
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 7. Gini Δ — pretax vs aftertax dumbbell per cell
# ---------------------------------------------------------------------

fig_gini_delta <- function(gini_long, axes, year) {
  d <- merge(gini_long, axes[, .(scenario_id, variant, labor, realization)],
             by = "scenario_id", all.x = TRUE)
  d <- d[!is.na(variant)]
  .attach_axis_labels(d)

  p <- ggplot2::ggplot(d, ggplot2::aes(x = labor_label, y = delta,
                                   color = income_concept,
                                   shape = income_concept)) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::geom_point(size = 3,
                        position = ggplot2::position_dodge(width = 0.5)) +
    ggplot2::facet_grid(realization_label ~ variant_label) +
    ggplot2::scale_color_manual(values = c(pretax = YBL_NAVY, aftertax = YBL_ORANGE),
                                 name = NULL,
                                 labels = c(aftertax = "Aftertax", pretax = "Pretax")) +
    ggplot2::scale_shape_manual(values = c(pretax = 16, aftertax = 17),
                                 name = NULL,
                                 labels = c(aftertax = "Aftertax", pretax = "Pretax")) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%+.3f", x)) +
    ggplot2::labs(
      title    = "Inequality response (Gini)",
      subtitle = sprintf("Change in within-scenario Gini, FY %d. Positive = inequality up.", year),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "y")
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 8. Sensitivity heatmap — ΔR(total_with_macro_cit) across the grid
# ---------------------------------------------------------------------

fig_sensitivity_heatmap <- function(wide, year) {
  d <- wide[, .(scenario_id, variant, variant_label, labor, labor_label,
                realization, realization_label, total_with_macro_cit)]
  p <- ggplot2::ggplot(
    d,
    ggplot2::aes(x = labor_label, y = realization_label,
                 fill = total_with_macro_cit)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 1) +
    ggplot2::geom_text(
      ggplot2::aes(label = .dollar_B(total_with_macro_cit)),
      color = YBL_TEXT, size = 3.4
    ) +
    ggplot2::facet_wrap(~ variant_label, ncol = length(unique(d$variant_label))) +
    ggplot2::scale_fill_gradient2(
      low = YBL_ORANGE, mid = "white", high = YBL_NAVY,
      midpoint = 0, name = expression(Delta * R~"($B)"),
      labels = .dollar_B
    ) +
    ggplot2::labs(
      title    = "Revenue sensitivity at a glance",
      subtitle = sprintf("Total ΔR (incl. macro CIT) across the labor × realization grid, by variant, FY %d", year),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    ggplot2::theme(
      panel.grid       = ggplot2::element_blank(),
      legend.position  = "right",
      legend.key.height = ggplot2::unit(1.2, "cm")
    )
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 9. Variant scaling — ΔR vs AI growth-shock magnitude g_y
# ---------------------------------------------------------------------

fig_variant_scaling <- function(wide, gy_by_variant, year) {
  d <- merge(wide, gy_by_variant, by = "variant")

  p <- ggplot2::ggplot(d, ggplot2::aes(x = gy, y = total_with_macro_cit,
                                    color = labor_label,
                                    shape = labor_label,
                                    group = interaction(labor_label, realization_label))) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_point(size = 2.4) +
    ggplot2::facet_wrap(~ realization_label, ncol = length(unique(d$realization_label))) +
    ggplot2::scale_color_manual(values = PAL_LABOR, name = "Labor map") +
    ggplot2::scale_shape_manual(values = PAL_LABOR_SHAPE, name = "Labor map") +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 0.1)) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Revenue scaling with the AI growth shock",
      subtitle = sprintf("Total ΔR vs AI growth bump g_y over CBO baseline, FY %d", year),
      x        = "g_y (AI growth bump over CBO baseline)", y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "x")
  attr(p, "clean_x") <- "AI growth bump above the CBO baseline"
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 10. Revenue delta vs pretax income delta, by scenario
# ---------------------------------------------------------------------
# One point per (variant, labor, realization) cell. ΔY is the pretax
# total-income delta computed by build_income_total_table (08).

fig_revenue_vs_income <- function(wide, income_long, year) {
  inc <- income_long[income_type == "pretax",
                     .(scenario_id, delta_Y = delta)]
  d <- merge(wide, inc, by = "scenario_id")

  p <- ggplot2::ggplot(d, ggplot2::aes(x = delta_Y, y = total_with_macro_cit,
                                    color = variant_label,
                                    shape = labor_label)) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::geom_vline(xintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::geom_point(size = 3) +
    ggplot2::facet_wrap(~ realization_label,
                        ncol = length(unique(d$realization_label))) +
    ggplot2::scale_color_manual(values = PAL_VARIANT, name = "Shock variant") +
    ggplot2::scale_shape_manual(values = PAL_LABOR_SHAPE, name = "Labor map") +
    ggplot2::scale_x_continuous(labels = .dollar_B) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Revenue response vs pretax income response, by scenario",
      subtitle = sprintf("Total ΔR (incl. macro CIT) vs ΔY (pretax), FY %d ($B)", year),
      x        = "ΔY pretax (within-scenario, $B)",
      y        = "ΔR total with macro CIT ($B)",
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "x")
  attr(p, "clean_x") <- "Change in pretax income ($B)"
  attr(p, "clean_y") <- "Change in total revenue ($B)"
  list(plot = p, data = d)
}

# Companion to fig_revenue_vs_income with the x-axis swapped for the
# gross factor-income expansion implied by the variant — labor growth
# (L0$ * alpha * gk) plus the gross capital expansion X (K1$ - K0$),
# both before any leakage from the macro CIT wedge or retirement
# deferral. This is the pre-leakage analog of ΔY pretax and isolates
# how revenue scales with the underlying factor shock rather than the
# tax-base impact.
fig_revenue_vs_gross_factor <- function(wide, macro_per_scn, year) {
  gross <- macro_per_scn[, .(scenario_id,
                             delta_factor_gross = delta_L_dollar + X)]
  d <- merge(wide, gross, by = "scenario_id")

  p <- ggplot2::ggplot(d, ggplot2::aes(x = delta_factor_gross,
                                       y = total_with_macro_cit,
                                       color = variant_label,
                                       shape = labor_label)) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::geom_vline(xintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::geom_point(size = 3) +
    ggplot2::facet_wrap(~ realization_label,
                        ncol = length(unique(d$realization_label))) +
    ggplot2::scale_color_manual(values = PAL_VARIANT, name = "Shock variant") +
    ggplot2::scale_shape_manual(values = PAL_LABOR_SHAPE, name = "Labor map") +
    ggplot2::scale_x_continuous(labels = .dollar_B) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Revenue response vs gross factor-income expansion, by scenario",
      subtitle = sprintf(
        "Total ΔR (incl. macro CIT) vs ΔL + X (pre-leakage), FY %d ($B)", year),
      x        = "ΔL + X gross (labor growth + gross capital expansion, $B)",
      y        = "ΔR total with macro CIT ($B)",
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "x")
  attr(p, "clean_x") <- "Gross factor-income expansion ($B)"
  attr(p, "clean_y") <- "Change in total revenue ($B)"
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 12. Share-mode paired comparison — total ΔR under R vs F
# ---------------------------------------------------------------------
# For each (variant, labor, realization) cell, plot the bottom-line
# total_with_macro_cit twice: once for share_mode = R (Karger
# reallocation) and once for share_mode = F (labor-capital share held
# fixed). Returns NULL when only one share_mode is present.

fig_share_mode_comparison <- function(wide, year) {
  if (uniqueN(wide$share_mode) < 2L) return(NULL)
  d <- wide[, .(scenario_id, variant, variant_label,
                share_mode, share_mode_label,
                labor, labor_label,
                realization, realization_label,
                total_with_macro_cit)]
  p <- ggplot2::ggplot(
    d,
    ggplot2::aes(x = labor_label, y = total_with_macro_cit,
                 fill = share_mode_label)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_grid(realization_label ~ variant_label) +
    ggplot2::scale_fill_manual(
      values = c(Reallocate = YBL_NAVY, `Fixed share` = YBL_ORANGE),
      name   = "Factor-share mode"
    ) +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Reallocate vs fixed-share, paired by shock",
      subtitle = sprintf(
        "Total ΔR including macro CIT, FY %d ($B). Same gy per variant; only the labor-capital reallocation differs.",
        year
      ),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(d, "y")
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 13. Reallocation revenue delta — R minus F per cell
# ---------------------------------------------------------------------
# The difference between the bottom-line ΔR under R and F isolates the
# revenue change attributable to the labor-capital reallocation itself
# (the productivity channel is the same on both sides). Returns NULL if
# any cell is missing its F twin.

fig_share_mode_reallocation_delta <- function(wide, year) {
  if (uniqueN(wide$share_mode) < 2L) return(NULL)
  pair_keys <- c("variant", "variant_label",
                 "labor", "labor_label",
                 "realization", "realization_label")
  paired <- dcast(
    wide[, c(pair_keys, "share_mode", "total_with_macro_cit"), with = FALSE],
    ... ~ share_mode, value.var = "total_with_macro_cit"
  )
  paired <- paired[!is.na(R) & !is.na(`F`)]
  if (!nrow(paired)) return(NULL)
  paired[, reallocation_delta := R - `F`]

  p <- ggplot2::ggplot(
    paired,
    ggplot2::aes(x = labor_label, y = reallocation_delta,
                 fill = variant_label)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::facet_wrap(~ realization_label,
                        ncol = length(unique(paired$realization_label))) +
    ggplot2::scale_fill_manual(values = PAL_VARIANT, name = "Shock variant") +
    ggplot2::scale_y_continuous(labels = .dollar_B) +
    ggplot2::labs(
      title    = "Revenue change attributable to labor-capital reallocation",
      subtitle = sprintf(
        "Reallocate minus Fixed share, FY %d ($B). Same gy on both sides.",
        year
      ),
      x        = NULL, y = NULL,
      caption  = .fig_caption(year)
    ) +
    .fig_theme() +
    .suppress_real_strip_if_single(paired, "x")
  list(plot = p, data = paired)
}

# Two-color fill for the paired ATR-definition bars. Keyed by label so
# scale_fill_manual positions by name. Standard = level-shift in
# Tax/Pretax; Extended = the same numerator over a denominator that
# includes the full gross factor-income expansion (CIT not subtracted —
# footnote in the figure).
PAL_ATR_DEFN <- c("Standard"             = YBL_BLUE,
                  "Extended denominator" = YBL_ORANGE)

# ---------------------------------------------------------------------
# 14. ΔATR by decile, one figure per (variant × labor × realization)
# ---------------------------------------------------------------------
# Two grouped bars per decile per scenario. Standard ΔATR uses the cf
# pretax-income denominator; the extended-denominator variant replaces
# the cf denominator with (baseline pretax + gross factor-income
# expansion), giving a "share of new factor income not taxed" reading.
# Caller passes one scenario's slice of `atr_decile` plus the (single)
# row of `axes_per_scn` that names the variant / labor / realization,
# so the title can carry the descriptive labels rather than the
# internal codes. assemble_figures emits one of these per (variant ×
# labor × realization) cell present in atr_decile.csv at share_mode=R.
fig_atr_decile_one <- function(atr_d, axes_row, year) {
  if (!nrow(atr_d)) return(NULL)
  d <- copy(atr_d)
  d[, atr_base     := tax_base_d_B / pretax_base_d_B]
  d[, atr_cf_std   := tax_cf_d_B   / pretax_cf_d_B]
  d[, atr_cf_ext   := tax_cf_d_B   / (pretax_base_d_B + dY_factor_d_B)]
  d[!is.finite(atr_base),   atr_base   := NA_real_]
  d[!is.finite(atr_cf_std), atr_cf_std := NA_real_]
  d[!is.finite(atr_cf_ext), atr_cf_ext := NA_real_]
  d[, dATR_std := atr_cf_std - atr_base]
  d[, dATR_ext := atr_cf_ext - atr_base]

  plot_d <- melt(
    d[, .(decile, dATR_std, dATR_ext)],
    id.vars = "decile", variable.name = "definition", value.name = "dATR"
  )
  plot_d[, definition := factor(
    fifelse(definition == "dATR_std", "Standard", "Extended denominator"),
    levels = c("Standard", "Extended denominator")
  )]
  plot_d[, decile := factor(decile, levels = seq_len(10))]

  subtitle <- sprintf("%s shock, %s labor scenario (R, %s), FY %d",
                      axes_row$variant_label,
                      axes_row$labor_label,
                      axes_row$realization_label, year)
  caption  <- paste0(
    .fig_caption(year),
    "\nStandard denominator = cf pretax income; Extended denominator = ",
    "baseline pretax + gross factor expansion.\n",
    "CIT omitted from denominator (consistent handling would require ",
    "allocating CIT in baseline as well)."
  )

  p <- ggplot2::ggplot(plot_d,
                       ggplot2::aes(x = decile, y = dATR, fill = definition)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = PAL_ATR_DEFN, name = NULL) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 0.1)
    ) +
    ggplot2::labs(
      title    = "Change in average tax rate by decile",
      subtitle = subtitle,
      x        = "Baseline pretax-income decile",
      y        = NULL,
      caption  = caption
    ) +
    .fig_theme()

  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 14b / 14c. Cross-scenario ΔATR by decile (Standard denominator only)
# ---------------------------------------------------------------------
# Two companion figures to 14 that pin the denominator to the standard
# cf-pretax-income form and instead vary the bar-grouping over one of
# the scenario axes — so we can read off how ΔATR moves with growth
# (variant) and inequality (labor) holding the other axis fixed.
#
# 14b: fix (variant, realization); bars per decile = labor scenario
#       (S0 / S2 / S3), coloured by PAL_LABOR.
# 14c: fix (labor, realization);   bars per decile = shock variant
#       (S / M / R),               coloured by PAL_VARIANT.
#
# Both callers pass a per-scenario slice of `atr_decile` plus the rows
# of `axes_per_scn` covering those scenarios. ΔATR is computed exactly
# as in fig_atr_decile_one's "Standard" line: (cf tax / cf pretax) −
# (baseline tax / baseline pretax).
.compute_dATR_std <- function(atr_d) {
  d <- copy(atr_d)
  d[, atr_base   := tax_base_d_B / pretax_base_d_B]
  d[, atr_cf_std := tax_cf_d_B   / pretax_cf_d_B]
  d[!is.finite(atr_base),   atr_base   := NA_real_]
  d[!is.finite(atr_cf_std), atr_cf_std := NA_real_]
  d[, dATR := atr_cf_std - atr_base]
  d
}

fig_atr_decile_by_inequality <- function(atr_d, axes_sub, year) {
  if (!nrow(atr_d) || !nrow(axes_sub)) return(NULL)
  d  <- .compute_dATR_std(atr_d)
  ax <- axes_sub[, .(scenario_id, labor, labor_label,
                     variant_label, realization_label)]
  d  <- merge(d, ax, by = "scenario_id")
  d[, labor_label := droplevels(labor_label)]
  d[, decile := factor(decile, levels = seq_len(10))]

  caption <- paste0(
    .fig_caption(year),
    "\nΔATR = (cf tax / cf pretax income) − (baseline tax / baseline ",
    "pretax income).\nThree bars per decile compare labor (inequality) ",
    "scenarios at a fixed shock variant."
  )

  p <- ggplot2::ggplot(d,
                       ggplot2::aes(x = decile, y = dATR, fill = labor_label)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = PAL_LABOR, name = "Labor scenario",
                               drop = TRUE) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 0.1)
    ) +
    ggplot2::labs(
      title    = "Change in average tax rate by decile, across labor scenarios",
      subtitle = sprintf("%s shock (R, %s), FY %d",
                         as.character(axes_sub$variant_label[1]),
                         as.character(axes_sub$realization_label[1]), year),
      x        = "Baseline pretax-income decile",
      y        = NULL,
      caption  = caption
    ) +
    .fig_theme()

  list(plot = p, data = d)
}

fig_atr_decile_by_growth <- function(atr_d, axes_sub, year) {
  if (!nrow(atr_d) || !nrow(axes_sub)) return(NULL)
  d  <- .compute_dATR_std(atr_d)
  ax <- axes_sub[, .(scenario_id, variant, variant_label,
                     labor_label, realization_label)]
  d  <- merge(d, ax, by = "scenario_id")
  d[, variant_label := droplevels(variant_label)]
  d[, decile := factor(decile, levels = seq_len(10))]

  caption <- paste0(
    .fig_caption(year),
    "\nΔATR = (cf tax / cf pretax income) − (baseline tax / baseline ",
    "pretax income).\nThree bars per decile compare shock variants ",
    "(growth) at a fixed labor scenario."
  )

  p <- ggplot2::ggplot(d,
                       ggplot2::aes(x = decile, y = dATR, fill = variant_label)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78),
                      width = 0.72) +
    ggplot2::geom_hline(yintercept = 0, color = YBL_TEXT, linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = PAL_VARIANT, name = "Shock variant",
                               drop = TRUE) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 0.1)
    ) +
    ggplot2::labs(
      title    = "Change in average tax rate by decile, across shock variants",
      subtitle = sprintf("%s labor scenario (R, %s), FY %d",
                         as.character(axes_sub$labor_label[1]),
                         as.character(axes_sub$realization_label[1]), year),
      x        = "Baseline pretax-income decile",
      y        = NULL,
      caption  = caption
    ) +
    .fig_theme()

  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# 15-16. X-flow tax composition: helper + waterfall + ETR scatter
# ---------------------------------------------------------------------
# Both figures read off a single per-scenario table built here so the
# accounting identity (X = CIT wedge + household-side flows) stays in
# one place. Inputs:
#   macro_raw      — per (variant, share_mode), raw from the macro CSV
#                    (has the per-instrument X_*_B aggregates).
#   axes_per_scn   — per scenario_id, the (variant, share_mode, labor,
#                    realization) axes.
#   decomp         — revenue_decomp_<year>.csv, optional. When present,
#                    instrument=='total' delta_capital gives the clean
#                    microsim capital-side ΔR. Otherwise we fall back to
#                    revenue_grid_wide's `total` (mixed labor + capital).
#   wide           — revenue_grid_wide_<year>.csv (fallback source for
#                    microsim ΔR and the bottom-line total_with_macro_cit).
#
# Returns one row per scenario with:
#   X_B, X_to_units_B, kappa_corp, eta_corp, delta_R_CIT_B,
#   per-instrument X_*_B (qual_div / taxable_int / tax_exempt_int /
#     passthrough_ord / ltcg_gross / ltcg_realized_chosen / retirement_slice /
#     retirement_realized / retirement_unrealized),
#   X_ltcg_unrealized_B (= ltcg_gross − ltcg_realized at the run's realization),
#   X_realized_B (the IIT base that hits expanded_inc this year,
#     excluding tax-exempt int and the unrealized/deferred pieces; includes
#     the retirement_realized aggregate emitted by the cascade),
#   CIT_base_B (= κ·X), taxed_base_B (= CIT_base + X_realized),
#   delta_R_micro_cap_B, delta_R_micro_total_B,
#   delta_R_total_B (= ΔR_CIT + ΔR_micro_cap),
#   taxed_fraction (= taxed_base / X), etr_on_taxed (= ΔR_total / taxed_base),
#   delta_R_over_X (= ΔR_total / X), micro_cap_source ("decomp" | "fallback").
.build_x_taxed_table <- function(macro_raw, axes_per_scn,
                                 decomp = NULL, wide = NULL) {
  m <- copy(macro_raw)
  # Raw $ → $B for the columns we use.
  m[, X_B           := X / 1e9]
  m[, X_to_units_B  := X_to_units / 1e9]
  m[, delta_R_CIT_B := delta_R_CIT / 1e9]
  # κ now comes directly from the macro summary (yaml input), not from
  # an identity. CIT_base_B = κ·X.
  m[, CIT_base_B := kappa_corp * X_B]

  keep_cols <- c("variant", "share_mode",
                 "X_B", "X_to_units_B", "eta_corp", "cit_statutory",
                 "delta_R_CIT_B", "kappa_corp", "CIT_base_B",
                 "X_qualified_div_B", "X_taxable_int_B",
                 "X_tax_exempt_int_B", "X_passthrough_ordinary_B",
                 "X_ltcg_gross_B",
                 "X_ltcg_V1_realized_B",
                 "X_retirement_slice_B", "X_retirement_realized_B",
                 "X_retirement_unrealized_B")
  m <- m[, keep_cols, with = FALSE]
  m[, `:=`(variant_chr    = as.character(variant),
           share_mode_chr = as.character(share_mode))]
  m[, c("variant", "share_mode") := NULL]

  ax <- copy(axes_per_scn)
  ax[, `:=`(variant_chr    = as.character(variant),
            share_mode_chr = as.character(share_mode))]
  out <- merge(ax, m, by = c("variant_chr", "share_mode_chr"), all.x = TRUE)
  out[, c("variant_chr", "share_mode_chr") := NULL]

  # Under V1 (mechanical) the realized LTCG aggregate equals the gross.
  out[, X_ltcg_realized_chosen_B := X_ltcg_V1_realized_B]
  out[, X_ltcg_unrealized_B := X_ltcg_gross_B - X_ltcg_realized_chosen_B]
  # Realized this year = ordinary-income + dividends + LTCG-realized
  # + retirement-realized. Excludes tax-exempt int (lawfully untaxed) and
  # any unrealized residual (under V1/R1 the residual is zero).
  out[, X_realized_B := X_qualified_div_B + X_taxable_int_B +
        X_passthrough_ordinary_B + X_ltcg_realized_chosen_B +
        X_retirement_realized_B]
  # `taxed_base_B` (= κ·X + X_realized) is the union over the CIT and
  # IIT bases. Reported on the per-scenario table because it's useful
  # for the waterfall caption, but the fig 16 scatter avoids it: the
  # C-corp post-tax flow (κ·X·(1−τ)) lands inside X_realized as
  # qualified dividends + LTCG, so the two bases overlap and the union
  # can exceed X. The scatter uses X_realized / X as the cleaner
  # "household-side realized share" lever.
  out[, taxed_base_B := CIT_base_B + X_realized_B]

  # Microsim capital ΔR: prefer --decomp, fall back to wide$total.
  micro_cap_src <- "fallback"
  if (!is.null(decomp) && nrow(decomp)) {
    dc <- decomp[instrument == "total",
                 .(scenario_id, delta_R_micro_cap_B = delta_capital)]
    if (nrow(dc)) {
      out <- merge(out, dc, by = "scenario_id", all.x = TRUE)
      micro_cap_src <- "decomp"
    }
  }
  if (!"delta_R_micro_cap_B" %in% names(out)) {
    out[, delta_R_micro_cap_B := NA_real_]
  }
  if (!is.null(wide) && "total" %in% names(wide)) {
    wt <- wide[, .(scenario_id, delta_R_micro_total_B = total)]
    out <- merge(out, wt, by = "scenario_id", all.x = TRUE)
  } else {
    out[, delta_R_micro_total_B := NA_real_]
  }
  # If decomp is missing, attribute the full microsim total to the
  # capital channel — for S0 (no labor delta) that's exact; for S2/S3 it
  # carries the redistributive labor effect. Caption flags the fallback.
  out[is.na(delta_R_micro_cap_B), delta_R_micro_cap_B := delta_R_micro_total_B]
  out[, micro_cap_source := micro_cap_src]

  out[, delta_R_total_B := delta_R_CIT_B + delta_R_micro_cap_B]
  # Scatter axes — two flavours, one per fig 16 variant, designed so
  # each scatter's x and y share the same denominator:
  #
  # Fig 16a "with CIT" — denominator is gross X:
  #   realized_share_with_corp = (X_realized + κ·X) / X   (additive
  #     HH + C-Corp base; can exceed 1 because the C-corp post-tax flow
  #     appears in both X_realized as dividends + LTCG and in κ·X)
  #   etr_on_X                 = ΔR_total / X
  #
  # Fig 16b "IIT only" — denominator is X_to_units = X − ΔR_CIT (the
  # after-corp-tax pot that reaches households):
  #   realized_share_post_cit  = X_realized / X_to_units
  #   etr_on_X_to_units        = ΔR_micro_cap / X_to_units
  #
  # `realized_share_of_X` (X_realized / X) is kept for legacy callers
  # and the cell-level data table.
  out[, realized_share_of_X      := ifelse(X_B > 0,
                                           X_realized_B / X_B, NA_real_)]
  out[, realized_share_with_corp := ifelse(X_B > 0,
                                           (X_realized_B + CIT_base_B) / X_B,
                                           NA_real_)]
  out[, realized_share_post_cit  := ifelse(X_to_units_B > 0,
                                           X_realized_B / X_to_units_B,
                                           NA_real_)]
  out[, etr_on_X            := ifelse(X_B > 0,
                                       delta_R_total_B / X_B, NA_real_)]
  out[, etr_on_X_to_units   := ifelse(X_to_units_B > 0,
                                       delta_R_micro_cap_B / X_to_units_B,
                                       NA_real_)]
  # Effective per-X CIT rate. Under the new (post-2026-05-22) calibration
  # this equals delta_R_CIT / X = CBO_CIT_baseline / K0$, by construction.
  out[, cit_floor_etr       := ifelse(X_B > 0,
                                       delta_R_CIT_B / X_B, NA_real_)]
  # Old union-base diagnostic — kept for the per-scenario table but no
  # longer the scatter axes. taxed_base_B can exceed X because the
  # C-corp post-tax flow appears in both κ·X and X_realized.
  out[, taxed_fraction_union := ifelse(X_B > 0, taxed_base_B / X_B, NA_real_)]
  out[, etr_on_taxed_union   := ifelse(taxed_base_B > 0,
                                       delta_R_total_B / taxed_base_B,
                                       NA_real_)]
  out
}

# ---------------------------------------------------------------------
# 15. X waterfall (per realization, share_mode=R, labor=S0)
# ---------------------------------------------------------------------
# One figure per realization (V1 only in the release pipeline). Three
# horizontal stacked bars in each figure — one per variant
# (Slow/Moderate/Rapid) at share_mode=R, labor=S0 — so the reader can
# compare the X composition across shock magnitudes inside a single
# realization regime.
#
# Labor scenario fixed to S0 because the per-instrument X aggregates
# and ΔR_CIT are invariant across labor scenarios; only the implied
# IIT ETR varies slightly with labor (progressive bracket creep), and
# that's the story the scatter (fig 16) tells. Filtering here keeps
# the waterfall to the canonical no-redistribution case.
#
# Segments that are zero across all 3 variants are dropped from the
# legend (e.g., unrealized capital gains under V1 — the realization
# variant capitalizes the full gain).
PAL_X_TREATMENT <- c(
  "Corporate tax (CIT wedge)"      = YBL_NAVY,
  "Realized this year (IIT)"       = YBL_BLUE,
  "Tax-exempt interest"            = YBL_PALE,
  "Unrealized capital gains"       = YBL_MUTED,
  "Retirement (unrealized)"        = YBL_GRAY
)

fig_x_waterfall_per_realization <- function(tbl, realization_code, year) {
  d <- tbl[share_mode == "R" & labor == "S0" &
             realization == realization_code &
             is.finite(X_B) & X_B > 0]
  if (!nrow(d)) return(NULL)
  d <- d[order(variant)]

  # Build segments in long form: one row per (variant, treatment).
  segs <- rbindlist(lapply(seq_len(nrow(d)), function(i) {
    r <- d[i]
    data.table(
      variant       = r$variant,
      variant_label = r$variant_label,
      X_B           = r$X_B,
      treatment = factor(c("Corporate tax (CIT wedge)",
                           "Realized this year (IIT)",
                           "Tax-exempt interest",
                           "Unrealized capital gains",
                           "Retirement (unrealized)"),
                         levels = names(PAL_X_TREATMENT)),
      amount_B  = c(r$delta_R_CIT_B,
                    r$X_realized_B,
                    r$X_tax_exempt_int_B,
                    r$X_ltcg_unrealized_B,
                    r$X_retirement_unrealized_B)
    )
  }))
  segs[, share := amount_B / X_B]

  # Drop treatments that are zero across all variants in this
  # realization (rounding tolerance 1e-6 $B = $1 thousand).
  nonzero_treatments <- segs[, .(keep = any(abs(amount_B) > 1e-6)),
                              by = treatment][keep == TRUE, treatment]
  nonzero_treatments <- factor(
    as.character(nonzero_treatments),
    levels = intersect(names(PAL_X_TREATMENT),
                       as.character(nonzero_treatments))
  )
  segs[, treatment := factor(as.character(treatment),
                              levels = levels(nonzero_treatments))]
  segs <- segs[!is.na(treatment)]
  treatment_palette <- PAL_X_TREATMENT[levels(nonzero_treatments)]

  realization_label <- d$realization_label[1]
  subtitle <- sprintf(
    "%s realization, share_mode = R, proportional labor, FY %d",
    realization_label, year
  )
  # Compact per-variant ETR summary in the caption. Implied IIT ETR =
  # ΔR_micro_cap / X_realized; CIT wedge ETR is τ_C_eff·κ (invariant).
  per_variant <- d[, .(
    variant_label,
    X_B,
    iit_etr = ifelse(X_realized_B > 0,
                     delta_R_micro_cap_B / X_realized_B, NA_real_),
    etr_on_X
  )]
  per_variant_lines <- vapply(seq_len(nrow(per_variant)), function(i) {
    sprintf("  %s: X = $%.0fB, ΔR/X = %.1f%%, implied IIT ETR on realized = %.1f%%",
            per_variant$variant_label[i],
            per_variant$X_B[i],
            100 * per_variant$etr_on_X[i],
            100 * per_variant$iit_etr[i])
  }, character(1))
  cit_line <- sprintf(
    "CIT wedge: τ_stat = %.1f%% on κ·X / η (κ = %.2f, η = %.2f). Per variant:",
    100 * d$cit_statutory[1], d$kappa_corp[1], d$eta_corp[1]
  )
  micro_src <- unique(d$micro_cap_source)
  src_line <- sprintf(
    "Microsim capital-side ΔR source: %s. Untaxed segments do not contribute to current-year ΔR.",
    paste(micro_src, collapse = " / ")
  )
  caption <- paste(c(.fig_caption(year), cit_line, per_variant_lines,
                     src_line), collapse = "\n")

  # Inside/above decision is by panel-fraction (segment width relative
  # to the widest bar), not share-of-bar. Threshold ~2.5% of panel
  # width is enough to fit "X%" at size 3.4. This routes the Slow
  # variant's tiny CIT segment and the tax-exempt-interest sliver on
  # every variant to above-bar callouts in the treatment colour,
  # connected to the bar top by a geom_segment leader. Replaces the
  # previous ggrepel approach, which silently dropped labels under
  # coord_flip when segment midpoints clustered near zero.
  max_bar_amount <- segs[, .(total = sum(amount_B)),
                          by = variant_label][, max(total)]
  segs[, panel_fraction := amount_B / max_bar_amount]
  INSIDE_THRESHOLD <- 0.025
  segs[, label_inside := panel_fraction >= INSIDE_THRESHOLD]
  segs[, cum_end := cumsum(amount_B), by = variant_label]
  segs[, segment_mid := cum_end - amount_B / 2]

  inside_segs <- segs[label_inside == TRUE]
  above_segs  <- segs[label_inside == FALSE]
  # Stagger multiple callouts on the same variant in the categorical
  # direction so their text doesn't collide when segment midpoints are
  # close together. With at most 2 callouts per variant under the
  # current data this is effectively flat (0.45), but the formula
  # leaves headroom if a future realization adds a non-zero unrealized
  # cap-gains segment.
  above_segs[, order_in_variant := seq_len(.N), by = variant_label]
  above_segs[, x_above   := as.numeric(variant_label) + 0.45 +
                             0.15 * (order_in_variant - 1)]
  above_segs[, x_bar_top := as.numeric(variant_label) + 0.325]

  p <- ggplot2::ggplot(segs,
                       ggplot2::aes(x = variant_label, y = amount_B,
                                    fill = treatment)) +
    ggplot2::geom_col(position = ggplot2::position_stack(reverse = TRUE),
                      width = 0.65, color = "white", linewidth = 0.4)
  if (nrow(inside_segs)) {
    p <- p + ggplot2::geom_text(
      data = inside_segs,
      ggplot2::aes(label = sprintf("%.0f%%", 100 * share)),
      position = ggplot2::position_stack(vjust = 0.5, reverse = TRUE),
      color = "white", size = 3.4, fontface = "bold"
    )
  }
  if (nrow(above_segs)) {
    p <- p +
      ggplot2::geom_segment(
        data = above_segs,
        ggplot2::aes(x = x_bar_top, xend = x_above,
                     y = segment_mid, yend = segment_mid,
                     color = treatment),
        inherit.aes = FALSE, linewidth = 0.35, show.legend = FALSE
      ) +
      ggplot2::geom_text(
        data = above_segs,
        ggplot2::aes(x = x_above, y = segment_mid, color = treatment,
                     label = sprintf("%.0f%%", 100 * share)),
        inherit.aes = FALSE, size = 3.4, fontface = "bold",
        vjust = -0.4, show.legend = FALSE
      )
  }
  p <- p +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(values = treatment_palette, name = NULL) +
    ggplot2::scale_color_manual(values = treatment_palette, guide = "none") +
    ggplot2::scale_x_discrete(
      expand = ggplot2::expansion(add = c(0.4, 1.0))
    ) +
    ggplot2::scale_y_continuous(
      labels = .dollar_B,
      expand = ggplot2::expansion(mult = c(0.025, 0.02))
    ) +
    ggplot2::labs(
      title    = "Where the AI capital flow lands in the tax base",
      subtitle = subtitle,
      x = NULL, y = NULL, caption = caption
    ) +
    .fig_theme() +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      legend.position    = "top"
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 1, byrow = TRUE))

  list(plot = p, data = segs)
}

# ---------------------------------------------------------------------
# 16. Effective rate on X vs realized share (per realization, S0, R)
# ---------------------------------------------------------------------
# Two scatter variants per realization. Each one's x and y share the
# same denominator so the axes read consistently.
#
# 16a "with_cit"  — denominator is gross X
#   x = (X_realized + κ·X) / X     additive HH + C-Corp base. Can
#                                  exceed 1 because the C-corp post-tax
#                                  flow appears in BOTH X_realized
#                                  (as dividends + LTCG) and in κ·X.
#   y = ΔR_total / X               composite ETR including CIT.
#
# 16b "iit_only" — denominator is X_to_units = X − ΔR_CIT
#   x = X_realized / X_to_units    HH-only realized share of the
#                                  after-corp-tax pot.
#   y = ΔR_micro_cap / X_to_units  IIT-only rate on the after-corp pot.
#
# The 14.7% effective CIT rate applies to the C-corp slice κ·X only —
# not to gross X — which is why the CIT contribution to ΔR/X is
# τ_C_eff·κ ≈ 7.4% in 16a.
#
# Filtered to share_mode = R and labor = S0 (proportional). The H/M/L
# spread comes entirely from progressive IIT bracket creep (≤ 0.2 pp).
fig_x_etr_scatter_per_realization <- function(tbl, realization_code, year,
                                              include_cit = TRUE) {
  d <- tbl[share_mode == "R" & labor == "S0" &
             realization == realization_code &
             is.finite(realized_share_of_X)]
  if (!nrow(d)) return(NULL)

  if (isTRUE(include_cit)) {
    d[, x_val := realized_share_with_corp]
    d[, y_val := etr_on_X]
    floor_val   <- median(d$cit_floor_etr, na.rm = TRUE)
    panel_tag   <- "composite"
    title_tail  <- "including CIT"
    x_label     <- "HH + C-Corp realized share of X  =  (X_realized + κ·X) / X"
    y_label     <- "Composite effective rate on X  =  (ΔR_CIT + ΔR_micro_cap) / X"
    clean_x_label <- "Realized share of the AI capital flow"
    clean_y_label <- "Effective tax rate on the AI capital flow"
    floor_line  <- sprintf("CIT-only floor κ·τ_C_eff = %.1f%% lies below the visible range.",
                           100 * floor_val)
    caption_lines <- c(
      "X can exceed 100%: the C-corp post-tax flow appears in both κ·X (CIT",
      "base) and X_realized (as qualified dividends and realized LTCG), so",
      "those dollars are counted twice in the additive HH + C-Corp base.",
      "Both axes use X as the denominator. Y-axis zoomed to ~0.5 pp around the",
      "data so the H/M/L bracket-creep spread is visible; the CIT-only",
      "contribution κ·τ_C_eff ≈ 7.4% is a constant baseline beneath the data."
    )
  } else {
    d[, x_val := realized_share_post_cit]
    d[, y_val := etr_on_X_to_units]
    floor_val   <- 0
    panel_tag   <- "iit_only"
    title_tail  <- "IIT only"
    x_label     <- "HH realized share of after-CIT flow  =  X_realized / (X − ΔR_CIT)"
    y_label     <- "IIT-only effective rate  =  ΔR_micro_cap / (X − ΔR_CIT)"
    clean_x_label <- "Realized share of the after-corporate-tax flow"
    clean_y_label <- "Individual income tax rate on the after-corporate-tax flow"
    floor_line  <- ""
    caption_lines <- c(
      "Both axes use X_to_units = X − ΔR_CIT (the after-corp-tax pot reaching",
      "households) as the denominator, so the rate read is 'IIT bite per",
      "dollar that survives the corporate level.' For the composite total see",
      "the with-CIT scatter. The H/M/L spread is progressive IIT bracket creep:",
      "Rapid pushes more realized capital income into higher brackets, lifting",
      "the implied IIT rate by ≈ 0.2 pp vs Slow."
    )
  }
  d <- d[is.finite(x_val) & is.finite(y_val)]
  if (!nrow(d)) return(NULL)

  realization_label <- d$realization_label[1]

  # Tight y-zoom so the S/M/R bracket-creep spread is legible. Pad
  # ±0.25 pp around the data.
  y_lo <- min(d$y_val, na.rm = TRUE) - 0.0025
  y_hi <- max(d$y_val, na.rm = TRUE) + 0.0025
  # X is variant-invariant within a realization, so all three points
  # stack at the same x. Stagger labels in y only.
  nudge_y <- setNames(c(S = -0.0008, M = 0, R = 0.0008),
                      c("S", "M", "R"))
  d[, label_nudge := nudge_y[as.character(variant)]]

  # x-axis range: 0–110% so the 16a additive base can exceed 100%
  # without being clipped. 16b values are well under 100% so the wider
  # range is harmless there.
  x_hi <- max(1.0, max(d$x_val, na.rm = TRUE) * 1.05)

  subtitle <- if (nzchar(floor_line)) {
    sprintf("share_mode = R, proportional labor, FY %d. %s",
            year, floor_line)
  } else {
    sprintf("share_mode = R, proportional labor, FY %d", year)
  }

  p <- ggplot2::ggplot(d,
                       ggplot2::aes(x = x_val, y = y_val)) +
    ggplot2::geom_point(
      ggplot2::aes(color = variant_label),
      size = 4, stroke = 0.6, alpha = 0.9
    ) +
    ggplot2::geom_text(
      ggplot2::aes(color = variant_label, label = variant_label,
                   y = y_val + label_nudge),
      hjust = -0.25, size = 3.4, fontface = "bold",
      show.legend = FALSE
    ) +
    ggplot2::scale_color_manual(values = PAL_VARIANT,
                                name = "Shock variant", drop = FALSE) +
    ggplot2::scale_x_continuous(
      labels = scales::label_percent(accuracy = 1),
      limits = c(0, x_hi),
      expand = ggplot2::expansion(mult = c(0.02, 0.10))
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 0.1),
      limits = c(y_lo, y_hi)
    ) +
    ggplot2::labs(
      title    = sprintf("Effective tax rate on the AI capital flow — %s (%s)",
                         realization_label, title_tail),
      subtitle = subtitle,
      x = x_label,
      y = y_label,
      caption = paste(c(
        .fig_caption(year),
        caption_lines,
        "Labor scenarios omitted: capital flow is invariant across labor",
        "variants; the IIT-rate shift from bracket creep is ≤ 0.2 pp."
      ), collapse = "\n")
    ) +
    .fig_theme()

  attr(p, "panel_tag") <- panel_tag
  attr(p, "clean_x")   <- clean_x_label
  attr(p, "clean_y")   <- clean_y_label
  list(plot = p, data = d)
}

# ---------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------

assemble_figures <- function(
  year           = NULL,
  runscript_path = file.path(
    Sys.getenv("TAX_SIMULATOR_DIR", unset = NA_character_),
    "config", "runscripts", "private", "ai_fiscal.csv"
  ),
  agg_dir        = "results/aggregates",
  out_dir        = NULL,
  # TODO: argv is accepted for parity with assemble_deliverables but currently
  # unused inside this function. Wire up CLI parsing (--year, --out-dir, ...) or drop.
  argv           = NULL
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_warn(c(
      "{.pkg ggplot2} not installed; skipping figure suite.",
      i = "Install with {.code install.packages('ggplot2')} to enable."
    ))
    return(invisible(NULL))
  }
  if (!requireNamespace("scales", quietly = TRUE)) {
    cli::cli_warn(c(
      "{.pkg scales} not installed; skipping figure suite.",
      i = "Install with {.code install.packages('scales')} to enable."
    ))
    return(invisible(NULL))
  }

  if (is.null(year))    year    <- .runscript_policy_year(runscript_path)
  if (is.null(out_dir)) out_dir <- file.path("results", "figures", as.character(year))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # Load deliverable + supporting tables.
  wide_fp     <- file.path(agg_dir, sprintf("revenue_grid_wide_%d.csv", year))
  long_fp     <- file.path(agg_dir, sprintf("revenue_grid_%d.csv",      year))
  decile_fp   <- file.path(agg_dir, sprintf("decile_panel_%d.csv",      year))
  shares_fp   <- file.path(agg_dir, sprintf("share_deltas_%d.csv",      year))
  gini_fp     <- file.path(agg_dir, sprintf("gini_deltas_%d.csv",       year))
  decomp_fp   <- file.path(agg_dir, sprintf("revenue_decomp_%d.csv",    year))
  income_fp   <- file.path(agg_dir, sprintf("income_deltas_%d.csv",     year))
  atr_dec_fp  <- file.path(agg_dir, sprintf("atr_decile_%d.csv",        year))
  macro_csv   <- sub("\\.csv$", "_macro.csv", runscript_path)
  required    <- c(wide_fp, long_fp, decile_fp, shares_fp, gini_fp,
                   income_fp, runscript_path, macro_csv)
  missing     <- Filter(function(fp) !file.exists(fp), required)
  if (length(missing)) {
    cli::cli_abort(c(
      "Figure inputs missing.",
      "x" = "Looked for: {.path {missing}}",
      "i" = "Run {.run Rscript code/09_tables_figures.R} first (or the full orchestrator)."
    ))
  }

  wide      <- fread(wide_fp)
  long      <- fread(long_fp)
  decile    <- fread(decile_fp)
  shares    <- fread(shares_fp)
  gini      <- fread(gini_fp)
  income    <- fread(income_fp)
  decomp    <- if (file.exists(decomp_fp)) fread(decomp_fp) else NULL
  atr_dec   <- if (file.exists(atr_dec_fp)) fread(atr_dec_fp) else NULL

  # Restore factor levels on the axis columns (fread loses them).
  .restore_axes <- function(dt) {
    if ("variant" %in% names(dt))
      dt[, variant := factor(variant, levels = c("S", "M", "R"))]
    if ("share_mode" %in% names(dt))
      dt[, share_mode := factor(share_mode, levels = c("R", "F"))]
    if ("labor" %in% names(dt))
      dt[, labor := factor(labor, levels = c("S0", "S2", "S3"))]
    if ("realization" %in% names(dt))
      dt[, realization := factor(realization, levels = c("V1"))]
    if ("variant_label" %in% names(dt))
      dt[, variant_label := factor(variant_label,
                                    levels = c("Slow", "Moderate", "Rapid"))]
    if ("share_mode_label" %in% names(dt))
      dt[, share_mode_label := factor(share_mode_label,
                                       levels = c("Reallocate", "Fixed share"))]
    if ("labor_label" %in% names(dt))
      dt[, labor_label := factor(labor_label,
                                  levels = c("Compressive", "Proportional",
                                             "Expansive"))]
    if ("realization_label" %in% names(dt))
      dt[, realization_label := factor(realization_label,
                                        levels = c("Mechanical"))]
    dt
  }
  .restore_axes(wide); .restore_axes(long); .restore_axes(decile)

  # Macro per scenario (for the decomp plot) plus per-scenario axes
  # (for shares / gini which only have scenario_id) plus a per-variant
  # gy lookup (for the variant-scaling plot — .load_macro_per_scenario
  # drops gy, so read it from the raw macro CSV).
  macro_per_scn <- .load_macro_per_scenario(runscript_path)
  axes_per_scn  <- macro_per_scn[, .(scenario_id, variant, share_mode,
                                     labor, realization)]

  macro_raw     <- fread(macro_csv)
  # gy is invariant across share_mode for a given variant; drop the
  # share_mode column before deduplicating so the unique() call returns
  # one row per variant.
  gy_by_variant <- unique(macro_raw[, .(variant, gy)])
  stopifnot(
    uniqueN(gy_by_variant$variant) == nrow(gy_by_variant)
  )

  # Existing figures: pin to share_mode = R (the canonical Karger
  # reallocation case) so the visuals are unchanged from the pre-share-
  # mode pipeline. Fixed-share twins surface in the new paired-comparison
  # figures (15+) and in the comparison sheet written below.
  wide_R         <- wide[share_mode == "R"]
  long_R         <- long[share_mode == "R"]
  decile_R       <- decile[share_mode == "R"]
  axes_per_scn_R <- axes_per_scn[share_mode == "R"]

  # Render each figure. Decile / top-share are pinned to one realization
  # at a time. Each fig_* function returns list(plot, data); .fig_entry
  # wraps that into a render-list entry, tolerating NULL returns.
  realization_codes <- intersect(
    c("V1"),
    as.character(unique(axes_per_scn_R$realization))
  )
  decile_figs <- lapply(realization_codes, function(rc) {
    .fig_entry(sprintf("05_decile_incidence_%s", rc),
               fig_decile_incidence(decile_R, year, realization_code = rc),
               w = 9.5, h = 5.5)
  })
  top_share_figs <- lapply(realization_codes, function(rc) {
    .fig_entry(sprintf("06_top_share_concentration_%s", rc),
               fig_top_share(shares, axes_per_scn_R, year,
                             realization_code = rc),
               w = 9.0, h = 5.5)
  })

  # X-flow tax-composition table — one row per scenario, joined from
  # macro_raw + axes_per_scn + (revenue_decomp when present, else wide).
  # Feeds the waterfall (one per realization at share_mode=R, labor=S0,
  # three variants stacked) and the ETR scatter (one per realization,
  # same R / S0 filter).
  x_taxed_tbl <- .build_x_taxed_table(macro_raw, axes_per_scn,
                                      decomp = decomp, wide = wide)
  x_taxed_tbl <- .attach_axis_labels(x_taxed_tbl)

  x_realizations <- intersect(
    c("V1"),
    as.character(unique(
      x_taxed_tbl[share_mode == "R" & labor == "S0" & X_B > 0]$realization
    ))
  )
  x_waterfall_figs <- lapply(x_realizations, function(rc) {
    .fig_entry(sprintf("15_x_waterfall_%s", rc),
               fig_x_waterfall_per_realization(x_taxed_tbl, rc, year),
               w = 9.5, h = 5.0)
  })
  # Two scatter variants per realization: composite (CIT + IIT) and
  # IIT-only. The composite version answers "what's the total tax bite
  # per dollar of X" — the IIT-only version isolates the household-side
  # contribution by removing the τ_C_eff·κ CIT floor from y.
  x_scatter_figs <- unlist(lapply(x_realizations, function(rc) {
    list(
      .fig_entry(sprintf("16a_x_etr_scatter_with_cit_%s", rc),
                 fig_x_etr_scatter_per_realization(x_taxed_tbl, rc, year,
                                                   include_cit = TRUE),
                 w = 8.5, h = 5.0),
      .fig_entry(sprintf("16b_x_etr_scatter_iit_only_%s", rc),
                 fig_x_etr_scatter_per_realization(x_taxed_tbl, rc, year,
                                                   include_cit = FALSE),
                 w = 8.5, h = 5.0)
    )
  }), recursive = FALSE)

  # ΔATR-by-decile figures: one per (variant × labor × realization)
  # cell. Filtered to share_mode = R (matches the rest of the figure
  # suite). Release pipeline produces 9 figures (3 variants × 3 labor
  # × V1). Same loop pattern as decile_figs / top_share_figs above.
  atr_figs <- if (!is.null(atr_dec) && nrow(atr_dec)) {
    present_sids <- unique(atr_dec$scenario_id)
    target_axes  <- axes_per_scn[share_mode == "R" &
                                   labor %in% c("S0", "S2", "S3") &
                                   scenario_id %in% present_sids]
    target_axes  <- .attach_axis_labels(target_axes)
    target_axes  <- target_axes[order(realization, variant, labor)]
    lapply(seq_len(nrow(target_axes)), function(i) {
      ax  <- target_axes[i]
      sid <- ax$scenario_id
      .fig_entry(sprintf("14_atr_decile_%s", sid),
                 fig_atr_decile_one(atr_dec[scenario_id == sid], ax, year),
                 w = 8.5, h = 5.0)
    })
  } else {
    list()
  }

  # 14b / 14c: cross-scenario ΔATR variants (Standard denominator only).
  # 14b fixes (variant × realization) and varies labor across deciles;
  # 14c fixes (labor × realization) and varies variant across deciles.
  # Both restricted to share_mode = R and labor ∈ {S0, S2, S3} to match
  # the 14_* coverage above.
  atr_cross_figs <- if (!is.null(atr_dec) && nrow(atr_dec)) {
    present_sids <- unique(atr_dec$scenario_id)
    cross_axes   <- axes_per_scn[share_mode == "R" &
                                   labor %in% c("S0", "S2", "S3") &
                                   scenario_id %in% present_sids]
    cross_axes   <- .attach_axis_labels(cross_axes)

    by_ineq_groups <- unique(cross_axes[, .(variant, realization)])
    by_ineq_groups <- by_ineq_groups[order(realization, variant)]
    figs_b <- lapply(seq_len(nrow(by_ineq_groups)), function(i) {
      g <- by_ineq_groups[i]
      sub_ax <- cross_axes[variant == g$variant & realization == g$realization]
      sids   <- sub_ax$scenario_id
      .fig_entry(sprintf("14b_atr_decile_by_inequality_%s_%s",
                         g$variant, g$realization),
                 fig_atr_decile_by_inequality(
                   atr_dec[scenario_id %in% sids], sub_ax, year),
                 w = 9.0, h = 5.0)
    })

    by_grow_groups <- unique(cross_axes[, .(labor, realization)])
    by_grow_groups <- by_grow_groups[order(realization, labor)]
    figs_c <- lapply(seq_len(nrow(by_grow_groups)), function(i) {
      g <- by_grow_groups[i]
      sub_ax <- cross_axes[labor == g$labor & realization == g$realization]
      sids   <- sub_ax$scenario_id
      .fig_entry(sprintf("14c_atr_decile_by_growth_%s_%s",
                         g$labor, g$realization),
                 fig_atr_decile_by_growth(
                   atr_dec[scenario_id %in% sids], sub_ax, year),
                 w = 9.0, h = 5.0)
    })

    c(figs_b, figs_c)
  } else {
    list()
  }

  figs <- c(
    list(
      .fig_entry("01_headline_revenue",
                 fig_headline_revenue(wide_R, year), w = 9.0, h = 5.0),
      .fig_entry("02_macro_cit_split",
                 fig_macro_cit_split(wide_R, year), w = 10.0, h = 6.5),
      .fig_entry("03_instrument_breakdown",
                 fig_instrument_breakdown(long_R, year), w = 10.0, h = 6.5)
    ),
    decile_figs,
    top_share_figs,
    list(
      .fig_entry("07_gini_delta",
                 fig_gini_delta(gini, axes_per_scn_R, year), w = 10.0, h = 5.5),
      .fig_entry("08_sensitivity_heatmap",
                 fig_sensitivity_heatmap(wide_R, year), w = 12.0, h = 4.5),
      .fig_entry("09_variant_scaling",
                 fig_variant_scaling(wide_R, gy_by_variant, year),
                 w = 9.0, h = 5.0),
      .fig_entry("10_revenue_vs_income",
                 fig_revenue_vs_income(wide_R, income, year), w = 9.0, h = 5.0),
      .fig_entry("11_revenue_vs_gross_factor",
                 fig_revenue_vs_gross_factor(wide_R,
                                             macro_per_scn[share_mode == "R"],
                                             year),
                 w = 9.0, h = 5.0),
      # Paired share-mode comparison (R vs F). Only added when both modes
      # are present; otherwise the fig_* functions short-circuit and
      # `.fig_entry()` emits a NULL entry.
      .fig_entry("12_share_mode_comparison",
                 fig_share_mode_comparison(wide, year),
                 w = 10.0, h = 5.5),
      .fig_entry("13_share_mode_reallocation_delta",
                 fig_share_mode_reallocation_delta(wide, year),
                 w = 10.0, h = 5.5)
    ),
    x_waterfall_figs,
    x_scatter_figs,
    atr_figs,
    atr_cross_figs
  )
  if (!is.null(decomp)) {
    figs <- append(figs, list(
      .fig_entry("04_decomposition",
                 fig_decomp(decomp, macro_per_scn[share_mode == "R"],
                            axes_per_scn_R, year),
                 w = 10.0, h = 6.5)
    ), after = 3L)
  }

  written <- list()
  failed  <- character()
  for (f in figs) {
    if (is.null(f$plot)) next   # skipped realization, already warned
    out <- tryCatch(
      .fig_save(f$plot, out_dir, f$slug, year, w = f$w, h = f$h),
      error = function(e) {
        cli::cli_warn(c("Figure {.val {f$slug}} failed.", "x" = conditionMessage(e)))
        failed <<- c(failed, f$slug)
        NULL
      }
    )
    if (!is.null(out)) written[[f$slug]] <- out
  }

  # Emit one .xlsx with a sheet per figure (data behind the chart). Sheets
  # come up in the same order as the rendered figures.
  xlsx_fp <- .write_figure_data_excel(figs, out_dir, year)

  cli::cli_inform(c(
    "Wrote {length(written)} figure{?s} to {.path {out_dir}}.",
    "i" = "Each figure is saved as <slug>_<year>.png plus a paper-ready <slug>_<year>_clean.png (no title/subtitle/notes)."
  ))
  if (length(failed)) {
    cli::cli_warn(c(
      "!" = "{length(failed)} figure{?s} failed: {.val {failed}}",
      i = "Re-run with --log to capture full errors, or inspect inline warnings above."
    ))
  }
  invisible(list(figures = written, data_xlsx = xlsx_fp))
}

if (!interactive() && sys.nframe() == 0L) {
  assemble_figures(argv = commandArgs(trailingOnly = TRUE))
}
