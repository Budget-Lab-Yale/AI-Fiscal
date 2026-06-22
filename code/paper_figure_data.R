# Build a paper-only figure/table workbook: exactly the exhibits that
# appear in the policy draft ("How potential AI futures would play out in
# the current tax system"), in the draft's order, drawn from the
# already-produced model outputs.
#
# This is a thin post-processor over the full figure/table outputs — it
# selects, re-orders, and re-labels; it does not recompute the model.
# Run it after the pipeline (08 -> 09 -> 10 [-> 15]) has produced:
#   results/figures/<year>/figure_data_<year>.xlsx            (per-figure data, from 10)
#   results/aggregates/ai_fiscal_publishable_<year>_latest.xlsx
#       (key_parameters sheet -> Table 1; blsmm_debt_to_gdp sheet -> Fig A4; from 09/15)
#
# The two appendix context charts (Fig A1 GDP growth, Fig A2 labor share)
# are NOT produced by the model pipeline — in the draft they are
# Datawrapper charts built from historical macro series. This script
# regenerates their underlying data directly from FRED (no API key — the
# public fredgraph.csv endpoint), so the workbook is self-contained.
#
# Output:
#   results/figures/<year>/paper_figure_data_<year>.xlsx
#   results/figures/<year>/A1_gdp_growth_<year>.png  (+ _clean)   } the two
#   results/figures/<year>/A2_labor_share_<year>.png (+ _clean)   } FRED charts
# (Figs 1-7, A3 PNGs come from 10_figures.R; A4 from 15_blsmm_debt_gdp.R.)
#
# Draft-exhibit -> source mapping. The model-figure mapping was verified
# 2026-06-22 by hashing the draft's embedded images against the rendered
# figure PNGs (7/8 byte-identical; the rest confirmed visually). If the
# figure suite in 10_figures.R changes slugs, update .PAPER_MANIFEST.
#
#   Table 1   -> key_parameters            (publishable bundle)
#   Figure 1  -> 01_headline_revenue
#   Figure 2  -> 04_decomposition
#   Figure 3  -> 03_instrument_breakdown
#   Figure 4  -> 11_revenue_vs_gross_factor
#   Figure 5  -> 12_share_mode_comparison
#   Figure 6  -> 07_gini_delta
#   Figure 7  -> 14_atr_decile_ai_M_R_S0_V1
#   Figure A1 -> FRED GDPC1     (5-yr annualized log GDP growth + CBO projection)
#   Figure A2 -> FRED PRS85006173 (nonfarm-business labor share, percent)
#   Figure A3 -> 10_revenue_vs_income
#   Figure A4 -> blsmm_debt_to_gdp         (publishable bundle)

suppressPackageStartupMessages({
  library(openxlsx)
})

# The YBL brand kit (colours, PAL_VARIANT, .fig_theme/.fig_save) lives in
# 00_utils.R so the appendix charts here match the figure suite from
# 10_figures.R. Sourcing utils alone keeps this post-processor light — it
# does not pull in the whole figure pipeline. Idempotent (no top-level
# side effects); harmless under the orchestrator, which sources it earlier.
source("code/00_utils.R")

# --------------------------------------------------------------------------
# Config for the FRED-sourced appendix series (A1 / A2)
# --------------------------------------------------------------------------

.FRED_GDP_ID    <- "GDPC1"        # Real GDP, quarterly, Bil. Chn. 2017$ (annual avg = GDPCA)
.FRED_LABOR_ID  <- "PRS85006173"  # Nonfarm Business Sector: Labor Share (Index 2017=100)

# The BLS index is 2017=100; the figure plots the labor share in percent.
# Anchor the index to the nonfarm-business labor-share level in the index
# base year (2017 ~ 56.5%, matching the BLS/Haver LXNFBL level the draft
# used). fraction_y = index_y / index_2017 * .LS_ANCHOR_2017. Validated to
# reproduce the draft's historical series at 1947 / 2017 / 2025 to <0.1pp.
.LS_ANCHOR_YEAR <- 2017L
.LS_ANCHOR_2017 <- 0.565

.GDP_GROWTH_MA_YEARS  <- 5L       # window for the annualized log-growth measure
.GDP_PROJECTION_END   <- 2036L    # how far to carry the CBO projection line

# --------------------------------------------------------------------------
# FRED download (public fredgraph.csv endpoint — no API key required)
# --------------------------------------------------------------------------

# Returns a data.frame(date = Date, value = numeric) or NULL on any failure
# (offline, timeout, bad series). Callers degrade gracefully to a placeholder.
.fred_series <- function(series_id, timeout = 30L) {
  url <- sprintf("https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s", series_id)
  tmp <- tempfile(fileext = ".csv")
  ok <- tryCatch({
    old <- options(timeout = timeout); on.exit(options(old), add = TRUE)
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) {
    cli_or_message(sprintf("FRED download failed for %s: %s", series_id, conditionMessage(e)))
    FALSE
  })
  if (!ok || !file.exists(tmp) || file.info(tmp)$size == 0) return(NULL)
  df <- tryCatch(utils::read.csv(tmp, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df) || ncol(df) < 2L || !nrow(df)) return(NULL)
  # fredgraph.csv: col1 = observation_date, col2 = <series_id>. Coerce; FRED
  # marks missing as ".".
  out <- data.frame(
    date  = as.Date(df[[1]]),
    value = suppressWarnings(as.numeric(df[[2]])),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$date), , drop = FALSE]
  if (!nrow(out)) return(NULL)
  out
}

# Light wrapper so the script works whether or not cli is attached.
cli_or_message <- function(msg) {
  if (requireNamespace("cli", quietly = TRUE)) cli::cli_warn(msg) else message(msg)
}

# Aggregate a (date, value) series to annual means. Returns data.frame(
# year, value, n_obs). `n_obs` lets callers keep only complete years
# (4 quarters for a quarterly series) when extending a projection.
.fred_annual <- function(df) {
  if (is.null(df)) return(NULL)
  yr <- as.integer(format(df$date, "%Y"))
  ok <- !is.na(df$value)
  agg <- aggregate(df$value[ok], by = list(year = yr[ok]), FUN = mean)
  cnt <- aggregate(df$value[ok], by = list(year = yr[ok]), FUN = length)
  out <- merge(agg, cnt, by = "year")
  names(out) <- c("year", "value", "n_obs")
  out[order(out$year), ]
}

# --------------------------------------------------------------------------
# Scenario parameters (reference lines come from the model's single source
# of truth, not hard-coded round numbers).
# --------------------------------------------------------------------------

.read_scenario_params <- function(
  yaml_path = file.path("config", "scenario_params.yaml")
) {
  if (!requireNamespace("yaml", quietly = TRUE) || !file.exists(yaml_path)) return(NULL)
  y <- tryCatch(yaml::read_yaml(yaml_path), error = function(e) NULL)
  if (is.null(y)) return(NULL)
  v <- y$shock$variants
  list(
    g_2026     = y$cbo_baseline$g_2026,
    g_2027plus = y$cbo_baseline$g_2027plus,
    # AI GDP CAGR per variant (Slow / Moderate / Rapid).
    gdp_cagr   = c(Slow = v$S$r_ai_annual, Moderate = v$M$r_ai_annual, Rapid = v$R$r_ai_annual),
    # 2030 labor share per variant = 1 - s1.
    labor_2030 = c(Slow = 1 - v$S$s1, Moderate = 1 - v$M$s1, Rapid = 1 - v$R$s1)
  )
}

# --------------------------------------------------------------------------
# A1 — GDP growth: 5-yr annualized log growth of real GDP, historical
# (solid) plus a CBO-baseline projection (dashed), with the three AI
# scenario CAGR reference lines.
# --------------------------------------------------------------------------

.build_fred_gdp_growth <- function(params) {
  ann <- .fred_annual(.fred_series(.FRED_GDP_ID))
  if (is.null(ann) || is.null(params)) return(NULL)
  # Real GDP by complete year (4 quarters); GDPC1 annual mean == GDPCA.
  ann <- ann[ann$n_obs >= 4L, ]
  if (nrow(ann) < .GDP_GROWTH_MA_YEARS + 1L) return(NULL)
  gdp <- setNames(ann$value, ann$year)
  last_hist <- max(ann$year)

  # Extend the GDP level with the CBO baseline path: g_2026 in 2026, then
  # g_2027plus for every later year, through the projection horizon.
  proj_years <- (last_hist + 1L):.GDP_PROJECTION_END
  for (yy in proj_years) {
    rate <- if (yy == 2026L) params$g_2026 else params$g_2027plus
    gdp[as.character(yy)] <- gdp[as.character(yy - 1L)] * (1 + rate)
  }

  n <- .GDP_GROWTH_MA_YEARS
  log_growth5 <- function(y) {
    a <- gdp[as.character(y)]; b <- gdp[as.character(y - n)]
    if (is.na(a) || is.na(b)) return(NA_real_)
    (log(a) - log(b)) / n
  }

  all_years <- (min(ann$year) + n):.GDP_PROJECTION_END
  hist_g <- vapply(all_years, function(y) if (y <= last_hist) log_growth5(y) else NA_real_, numeric(1))
  # Projection line includes the seam (last_hist) so the dashed line joins
  # the solid one.
  cbo_g  <- vapply(all_years, function(y) if (y >= last_hist) log_growth5(y) else NA_real_, numeric(1))

  data.frame(
    Year             = all_years,
    `GDP Growth`     = hist_g,
    `CBO Projection` = cbo_g,
    `Slow (2030)`    = params$gdp_cagr[["Slow"]],
    `Moderate (2030)`= params$gdp_cagr[["Moderate"]],
    `Rapid (2030)`   = params$gdp_cagr[["Rapid"]],
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# A2 — labor share: BLS nonfarm-business labor share in percent, with the
# three AI scenario 2030 labor-share reference lines.
# --------------------------------------------------------------------------

.build_fred_labor_share <- function(params) {
  ann <- .fred_annual(.fred_series(.FRED_LABOR_ID))
  if (is.null(ann) || is.null(params)) return(NULL)
  idx <- setNames(ann$value, ann$year)
  anchor_idx <- idx[as.character(.LS_ANCHOR_YEAR)]
  if (is.na(anchor_idx) || anchor_idx == 0) return(NULL)
  scale <- .LS_ANCHOR_2017 / anchor_idx
  data.frame(
    Year             = ann$year,
    `Labor Share`    = ann$value * scale,
    `Slow (2030)`    = params$labor_2030[["Slow"]],
    `Moderate (2030)`= params$labor_2030[["Moderate"]],
    `Rapid (2030)`   = params$labor_2030[["Rapid"]],
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# PNG renders for A1 / A2
# --------------------------------------------------------------------------
# Figures 1-7, A3 already have rendered PNGs from 10_figures.R, and A4 from
# 15_blsmm_debt_gdp.R. A1/A2 are regenerated here, so render them too — a
# YBL-style line chart of the historical series with the AI scenario
# reference lines (and NBER recession shading), matching the draft's
# Datawrapper exhibits. Emits a full (titled) and a _clean (paper-ready)
# PNG, mirroring the 10_figures.R convention.

# Palette / theme / PNG-save come from the shared brand kit in 00_utils.R
# (YBL_* colours, PAL_VARIANT, .fig_theme(), .fig_save()).

# NBER recession bands as decimal-year intervals, from FRED USREC (monthly
# 0/1). Returns data.frame(start, end) or NULL (offline / unavailable).
.fred_recession_bands <- function() {
  df <- .fred_series("USREC")
  if (is.null(df)) return(NULL)
  df <- df[order(df$date), ]
  rec <- !is.na(df$value) & df$value == 1
  if (!any(rec)) return(NULL)
  dy <- as.integer(format(df$date, "%Y")) + (as.integer(format(df$date, "%m")) - 1L) / 12
  bands <- list(); in_rec <- FALSE; st <- NA_real_
  for (i in seq_along(rec)) {
    if (rec[i] && !in_rec) { in_rec <- TRUE; st <- dy[i] }
    else if (!rec[i] && in_rec) { in_rec <- FALSE; bands[[length(bands) + 1L]] <- c(st, dy[i]) }
  }
  if (in_rec) bands[[length(bands) + 1L]] <- c(st, dy[length(dy)] + 1/12)
  if (!length(bands)) return(NULL)
  do.call(rbind, lapply(bands, function(b) data.frame(start = b[1], end = b[2])))
}

# Keep only recession bands overlapping [xmin, Inf) and clamp their start to
# xmin, so USREC's pre-1950 history doesn't stretch the plot past the data.
.clamp_bands <- function(rec, xmin) {
  if (is.null(rec)) return(NULL)
  rec <- rec[rec$end >= xmin, , drop = FALSE]
  if (!nrow(rec)) return(NULL)
  rec$start <- pmax(rec$start, xmin)
  rec
}

# Shared scaffold: recession bands + dashed scenario reference lines with
# right-edge labels. `series` is the line layer(s) added by the caller.
.scenario_ref_layers <- function(df, value_cols, xmax) {
  refs <- data.frame(
    label = c("Slow", "Moderate", "Rapid"),
    value = c(df[[value_cols[1]]][1], df[[value_cols[2]]][1], df[[value_cols[3]]][1]),
    stringsAsFactors = FALSE
  )
  refs$label <- factor(refs$label, levels = c("Slow", "Moderate", "Rapid"))
  pal <- PAL_VARIANT   # shared sequential variant scale (Slow -> Rapid)
  list(
    hline = ggplot2::geom_hline(data = refs,
                                ggplot2::aes(yintercept = value, color = label),
                                linetype = "dashed", linewidth = 0.5),
    text  = ggplot2::geom_text(data = refs,
                               ggplot2::aes(x = xmax, y = value, color = label,
                                            label = sprintf("%s: %.1f%%", label, 100 * value)),
                               hjust = 1, vjust = -0.5, size = 3.2,
                               fontface = "bold", show.legend = FALSE),
    scale = ggplot2::scale_color_manual(values = pal, guide = "none")
  )
}

.render_gdp_growth <- function(df, year, out_dir, rec_bands = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("scales", quietly = TRUE)) return(NULL)
  hist <- df[!is.na(df[["GDP Growth"]]),     c("Year", "GDP Growth")];     names(hist) <- c("year", "value")
  proj <- df[!is.na(df[["CBO Projection"]]), c("Year", "CBO Projection")]; names(proj) <- c("year", "value")
  xmin <- min(hist$year); xmax <- max(df$Year)
  rec  <- .clamp_bands(rec_bands, xmin)
  refl <- .scenario_ref_layers(df, c("Slow (2030)", "Moderate (2030)", "Rapid (2030)"), xmax)

  p <- ggplot2::ggplot()
  if (!is.null(rec)) {
    p <- p + ggplot2::geom_rect(data = rec,
                                ggplot2::aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
                                fill = YBL_GRAY, alpha = 0.10, inherit.aes = FALSE)
  }
  p <- p + refl$hline +
    ggplot2::geom_line(data = hist, ggplot2::aes(year, value),
                       color = YBL_NAVY, linewidth = 0.9) +
    ggplot2::geom_line(data = proj, ggplot2::aes(year, value),
                       color = YBL_NAVY, linetype = "dashed", linewidth = 0.8) +
    refl$text + refl$scale +
    ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
    ggplot2::labs(
      title    = "AI scenario GDP growth vs. historical GDP growth",
      subtitle = "Real GDP growth, 5-yr annualized (log); CBO baseline projection 2026 onward.",
      x = NULL, y = NULL,
      caption  = sprintf("Source: BEA/BLS via FRED (GDPC1), CBO 2025 baseline, NBER recessions; The Budget Lab at Yale. FY %d.", year)
    ) +
    ggplot2::coord_cartesian(xlim = c(xmin, xmax)) +
    .fig_theme()
  .fig_save(p, out_dir, "A1_gdp_growth", year, w = 7.6, h = 4.8)
}

.render_labor_share <- function(df, year, out_dir, rec_bands = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("scales", quietly = TRUE)) return(NULL)
  hist <- df[!is.na(df[["Labor Share"]]), c("Year", "Labor Share")]; names(hist) <- c("year", "value")
  xmin <- min(hist$year); xmax <- max(df$Year)
  rec  <- .clamp_bands(rec_bands, xmin)
  refl <- .scenario_ref_layers(df, c("Slow (2030)", "Moderate (2030)", "Rapid (2030)"), xmax)

  p <- ggplot2::ggplot()
  if (!is.null(rec)) {
    p <- p + ggplot2::geom_rect(data = rec,
                                ggplot2::aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
                                fill = YBL_GRAY, alpha = 0.10, inherit.aes = FALSE)
  }
  p <- p + refl$hline +
    ggplot2::geom_line(data = hist, ggplot2::aes(year, value),
                       color = YBL_NAVY, linewidth = 0.9) +
    refl$text + refl$scale +
    ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
    ggplot2::labs(
      title    = "AI scenario labor share vs. historical labor share",
      subtitle = "Nonfarm-business labor share of income (percent). Reference lines: AI scenario 2030 labor shares.",
      x = NULL, y = NULL,
      caption  = sprintf("Source: BLS via FRED (PRS85006173), NBER recessions; The Budget Lab at Yale. FY %d.", year)
    ) +
    ggplot2::coord_cartesian(xlim = c(xmin, xmax)) +
    .fig_theme()
  .fig_save(p, out_dir, "A2_labor_share", year, w = 7.6, h = 4.8)
}

# --------------------------------------------------------------------------
# Manifest — one row per draft exhibit, in draft order.
#   tab     : worksheet name in the output (<= 31 chars, Excel limit)
#   caption : the draft's caption line, verbatim (the sheet Title)
#   desc    : short, human one-liner for the Contents index
#   units   : the draft's units / subtitle line (NA if none)
#   kind    : "tbl"  -> a sheet in the publishable bundle (copied with header)
#             "fig"  -> a sheet in figure_data_<year>.xlsx (data grid copied)
#             "fred" -> regenerated from FRED via `builder`
#   source  : INTERNAL sheet name in the relevant workbook (NA for "fred").
#             Provenance only — never written to the public workbook.
#   cite    : public "Source:" citation line (NA -> the model default)
#   builder : function(params) -> data.frame, for kind == "fred"
#   note    : extra methodology text shown in the "Notes:" line
# --------------------------------------------------------------------------

.PAPER_MANIFEST <- list(
  list(tab = "T1",  caption = "Table 1. Key Parameters",
       desc = "Key model parameters by AI-adoption scenario",
       units = NA_character_, kind = "tbl", source = "key_parameters", builder = NULL,
       cite = NA_character_,
       note = "Slow / Moderate / Rapid AI-adoption variants; Karger et al. 2026, CBO 2025, TBL calculations."),
  list(tab = "F1", caption = "Figure 1. Tax revenue is higher when AI adoption is faster and when inequality rises",
       desc = "Headline federal revenue change by scenario",
       units = "Change in federal revenue, including corporate tax wedge, FY 2030, Billions USD",
       kind = "fig", source = "01_headline_revenue", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "F2", caption = "Figure 2. Capital and corporate revenue increases offset labor revenue losses in most scenarios",
       desc = "Revenue change decomposed by type of income",
       units = "Change in federal revenue by type of income, FY 2030, Billions USD",
       kind = "fig", source = "04_decomposition", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "F3", caption = "Figure 3. Revenue gains are driven by corporate and individual income tax revenue increases",
       desc = "Revenue change by tax instrument",
       units = "Change in federal revenue by tax instrument, FY 2030, Billions USD",
       kind = "fig", source = "03_instrument_breakdown", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "F4", caption = "Figure 4. Federal revenue grows non-linearly with the size of the GDP shock",
       desc = "Revenue vs. total factor income growth",
       units = "Change in federal revenue (y-axis) plotted against total factor income growth (x-axis), FY 2030, Billions USD",
       kind = "fig", source = "11_revenue_vs_gross_factor", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "F5", caption = "Figure 5. Federal revenue is higher in all scenarios when capital-labor shares are held fixed.",
       desc = "Revenue under fixed vs. reallocated factor shares",
       units = "Change in federal revenue, including corporate tax wedge, FY 2030, Billions USD",
       kind = "fig", source = "12_share_mode_comparison", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "F6", caption = "Figure 6. Overall inequality changes are driven by assumptions about labor income inequality",
       desc = "Change in income inequality (Gini)",
       units = "Change in within-scenario Gini coefficient, FY 2030. Positive = inequality rises.",
       kind = "fig", source = "07_gini_delta", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "F7", caption = "Figure 7. Despite a falling labor share, average tax rates tend to rise slightly in the Moderate AI scenario",
       desc = "Average tax rate change by income decile",
       units = "Percentage point change in average tax rate by decile, excluding corporate income tax, FY 2030",
       kind = "fig", source = "14_atr_decile_ai_M_R_S0_V1", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "FA1", caption = "Figure A1. How AI Scenario GDP Growth Assumptions Compare to Historical GDP Growth",
       desc = "AI scenario vs. historical GDP growth",
       units = "GDP growth (5-yr annualized, log). CBO projection 2026 onward.",
       kind = "fred", source = NA_character_, builder = .build_fred_gdp_growth,
       render = .render_gdp_growth,
       cite = "BEA/BLS via FRED (GDPC1), CBO 2025 baseline, NBER recessions; The Budget Lab at Yale.",
       note = "Real GDP from FRED GDPC1 (Bil. Chn. 2017$). 5-yr annualized log growth; projection extends GDP with the CBO baseline path. Reference lines = AI scenario GDP CAGRs."),
  list(tab = "FA2", caption = "Figure A2. How AI Scenario Labor Share Assumptions Compare to the Historical Labor Share",
       desc = "AI scenario vs. historical labor share",
       units = "Labor share of income (nonfarm business, percent)",
       kind = "fred", source = NA_character_, builder = .build_fred_labor_share,
       render = .render_labor_share,
       cite = "BLS via FRED (PRS85006173), NBER recessions; The Budget Lab at Yale.",
       note = "Labor share from FRED PRS85006173 (BLS NFB labor share, index 2017=100), rescaled to percent at the 2017 level. Reference lines = AI scenario 2030 labor shares."),
  list(tab = "FA3", caption = "Figure A3. Federal revenue gains versus change in pre-tax income",
       desc = "Revenue gains vs. pre-tax income change",
       units = "Change in federal revenue (y-axis) plotted against pre-tax income growth (x-axis), FY 2030, Billions USD",
       kind = "fig", source = "10_revenue_vs_income", builder = NULL, cite = NA_character_, note = NA_character_),
  list(tab = "FA4", caption = "Figure A4. The debt-to-GDP ratio falls more when AI adoption is faster",
       desc = "Debt-to-GDP by scenario (BLSMM)",
       units = NA_character_, kind = "tbl", source = "blsmm_debt_to_gdp", builder = NULL,
       cite = NA_character_,
       note = "Per-scenario 2030 debt/GDP from the Budget Lab Small Macro Model (BLSMM).")
)

# Public-facing "Source:" citation for a manifest entry. Model exhibits get
# the AI-Fiscal model citation; FRED/other exhibits carry an explicit `cite`.
# Internal sheet slugs (e$source) are never surfaced.
.source_citation <- function(e, year) {
  if (!is.null(e$cite) && !is.na(e$cite)) return(e$cite)
  sprintf("The Budget Lab at Yale AI-Fiscal microsimulation model, FY %d.", year)
}

# Per-column display widths from the body grid ONLY — the header block's long
# caption / Subtitle / Notes lines live in column A but overflow into the
# empty cells beside them, so they must not drive column A's width. `m` is a
# character matrix that includes the data's column-header row. Widths are
# padded for legibility and capped so a long text column can't dominate.
.body_col_widths <- function(m, min_w = 9, max_w = 46) {
  if (is.null(m) || !length(m)) return(NULL)
  m <- as.matrix(m)
  m[is.na(m)] <- ""
  w <- apply(m, 2L, function(col) max(nchar(col), 0L))
  pmin(pmax(w + 2L, min_w), max_w)
}

build_paper_figure_data <- function(
  year      = 2030L,
  fig_xlsx  = file.path("results", "figures", as.character(year),
                        sprintf("figure_data_%d.xlsx", year)),
  pub_xlsx  = file.path("results", "aggregates",
                        sprintf("ai_fiscal_publishable_%d_latest.xlsx", year)),
  out_xlsx  = file.path("results", "figures", as.character(year),
                        sprintf("paper_figure_data_%d.xlsx", year)),
  pull_fred = TRUE
) {
  if (!file.exists(fig_xlsx)) {
    stop(sprintf("figure_data workbook not found: %s\n  Run code/10_figures.R (or the orchestrator) first.", fig_xlsx))
  }
  if (!file.exists(pub_xlsx)) {
    stop(sprintf("publishable bundle not found: %s\n  Run code/09_tables_figures.R (or the orchestrator) first.", pub_xlsx))
  }

  fig_sheets <- openxlsx::getSheetNames(fig_xlsx)
  pub_sheets <- openxlsx::getSheetNames(pub_xlsx)
  params     <- if (pull_fred && any(vapply(.PAPER_MANIFEST, function(e) e$kind == "fred", logical(1)))) {
    .read_scenario_params()
  } else NULL
  # NBER recession bands are shared by every FRED render (A1, A2); fetch the
  # USREC series once here rather than re-downloading it inside each render.
  rec_bands  <- if (pull_fred && any(vapply(.PAPER_MANIFEST,
                    function(e) !is.null(e$render), logical(1)))) {
    .fred_recession_bands()
  } else NULL

  wb <- openxlsx::createWorkbook()
  title_st <- openxlsx::createStyle(textDecoration = "bold", fontSize = 12)
  meta_st  <- openxlsx::createStyle(textDecoration = "italic", fontColour = "#555555")
  hdr_st   <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#f0f0f0",
                                    border = "bottom")

  # ---- Contents (index) sheet -------------------------------------------
  # Public-facing index: a short human description per exhibit, no internal
  # sheet slugs. Identity block (rows 1-4) mirrors the Budget Lab template.
  contents <- data.frame(
    Sheet       = vapply(.PAPER_MANIFEST, function(e) e$tab, character(1)),
    Caption     = vapply(.PAPER_MANIFEST, function(e) e$caption, character(1)),
    Description = vapply(.PAPER_MANIFEST, function(e) e$desc, character(1)),
    stringsAsFactors = FALSE
  )
  openxlsx::addWorksheet(wb, "Data TOC")
  ident <- c(
    sprintf("AI-Fiscal — paper exhibits (FY %d)", year),
    format(Sys.Date(), "%B %Y"),
    "The Budget Lab at Yale",
    "Tables and Figures"
  )
  for (i in seq_along(ident)) {
    openxlsx::writeData(wb, "Data TOC", ident[i], startRow = i, startCol = 1)
  }
  openxlsx::addStyle(wb, "Data TOC", title_st, rows = 1, cols = 1)
  openxlsx::addStyle(wb, "Data TOC", meta_st, rows = 2:4, cols = 1, gridExpand = TRUE)
  toc_start <- length(ident) + 2L   # blank row after the identity block
  openxlsx::writeData(wb, "Data TOC", contents, startRow = toc_start, startCol = 1,
                      headerStyle = hdr_st)
  openxlsx::setColWidths(wb, "Data TOC", cols = 1:3, widths = c(12, 90, 48))
  openxlsx::freezePane(wb, "Data TOC", firstActiveRow = toc_start + 1L)

  out_dir <- dirname(out_xlsx)
  n_ok <- 0L; missing_src <- character(); fred_failed <- character()
  rendered_png <- character()
  for (e in .PAPER_MANIFEST) {
    openxlsx::addWorksheet(wb, e$tab)
    col_widths <- NULL   # set by a branch that writes a body grid

    # Single header block (rows 1-4), then a blank row, then the body from
    # row 6 — one consistent template across every exhibit, matching the
    # Budget Lab figure-workbook layout (Title / Subtitle / Notes / Source).
    openxlsx::writeData(wb, e$tab, e$caption, startRow = 1, startCol = 1)
    openxlsx::addStyle(wb, e$tab, title_st, rows = 1, cols = 1)
    if (!is.na(e$units)) {
      openxlsx::writeData(wb, e$tab, sprintf("Subtitle: %s", e$units),
                          startRow = 2, startCol = 1)
      openxlsx::addStyle(wb, e$tab, meta_st, rows = 2, cols = 1)
    }
    if (!is.na(e$note)) {
      openxlsx::writeData(wb, e$tab, sprintf("Notes: %s", e$note),
                          startRow = 3, startCol = 1)
      openxlsx::addStyle(wb, e$tab, meta_st, rows = 3, cols = 1)
    }
    openxlsx::writeData(wb, e$tab, sprintf("Source: %s", .source_citation(e, year)),
                        startRow = 4, startCol = 1)
    openxlsx::addStyle(wb, e$tab, meta_st, rows = 4, cols = 1)

    body_row <- 6L
    if (e$kind == "fig") {
      if (!e$source %in% fig_sheets) {
        missing_src <- c(missing_src, sprintf("%s (figure_data sheet '%s')", e$tab, e$source))
        openxlsx::writeData(wb, e$tab,
                            sprintf("[missing] sheet '%s' not found in %s", e$source, basename(fig_xlsx)),
                            startRow = body_row, startCol = 1)
        next
      }
      # Copy ONLY the data grid from the figure-data sheet. Those sheets
      # carry their own 3-row Title/Subtitle/Notes meta block + a blank row
      # before the data header (10_figures.R writes data_start = 5L). Drop
      # that block so we don't stack a second header under ours — this sheet
      # already owns the single header above.
      block <- openxlsx::read.xlsx(fig_xlsx, sheet = e$source,
                                   colNames = FALSE, skipEmptyRows = FALSE)
      .FIG_META_ROWS <- 4L
      if (nrow(block) > .FIG_META_ROWS) {
        block <- block[-seq_len(.FIG_META_ROWS), , drop = FALSE]
      }
      openxlsx::writeData(wb, e$tab, block, startRow = body_row, startCol = 1,
                          colNames = FALSE)
      # Style the (now first) row of the grid as a header, matching the
      # tbl/fred sheets.
      openxlsx::addStyle(wb, e$tab, hdr_st, rows = body_row,
                         cols = seq_len(ncol(block)), gridExpand = TRUE)
      col_widths <- .body_col_widths(block)   # block already includes the header row
      n_ok <- n_ok + 1L
    } else if (e$kind == "tbl") {
      if (!e$source %in% pub_sheets) {
        missing_src <- c(missing_src, sprintf("%s (publishable sheet '%s')", e$tab, e$source))
        openxlsx::writeData(wb, e$tab,
                            sprintf("[missing] sheet '%s' not found in %s", e$source, basename(pub_xlsx)),
                            startRow = body_row, startCol = 1)
        next
      }
      df <- openxlsx::read.xlsx(pub_xlsx, sheet = e$source)
      openxlsx::writeData(wb, e$tab, df, startRow = body_row, startCol = 1,
                          headerStyle = hdr_st)
      col_widths <- .body_col_widths(rbind(names(df), as.matrix(df)))
      n_ok <- n_ok + 1L
    } else if (e$kind == "fred") {
      df <- if (pull_fred && !is.null(e$builder)) {
        tryCatch(e$builder(params), error = function(err) {
          cli_or_message(sprintf("%s: FRED build error: %s", e$tab, conditionMessage(err)))
          NULL
        })
      } else NULL
      if (is.null(df) || !nrow(df)) {
        fred_failed <- c(fred_failed, e$tab)
        openxlsx::writeData(wb, e$tab,
                            "FRED series unavailable (offline or fetch failed). Re-run with network access to populate.",
                            startRow = body_row, startCol = 1)
      } else {
        openxlsx::writeData(wb, e$tab, df, startRow = body_row, startCol = 1,
                            headerStyle = hdr_st)
        col_widths <- .body_col_widths(rbind(names(df), as.matrix(df)))
        n_ok <- n_ok + 1L
        # Render the matching PNG (full + _clean), mirroring 10_figures.R.
        if (!is.null(e$render)) {
          pngs <- tryCatch(e$render(df, year, out_dir, rec_bands), error = function(err) {
            cli_or_message(sprintf("%s: PNG render failed: %s", e$tab, conditionMessage(err)))
            NULL
          })
          if (!is.null(pngs)) rendered_png <- c(rendered_png, pngs)
        }
      }
    }
    # Size columns from the body grid and freeze the header block + column
    # headers (rows 1-6) so they stay visible on scroll. Sheets that hit a
    # missing/failed source above leave col_widths NULL and keep defaults.
    if (!is.null(col_widths)) {
      openxlsx::setColWidths(wb, e$tab, cols = seq_along(col_widths),
                             widths = col_widths)
      openxlsx::freezePane(wb, e$tab, firstActiveRow = body_row + 1L)
    }
  }

  dir.create(dirname(out_xlsx), recursive = TRUE, showWarnings = FALSE)
  openxlsx::saveWorkbook(wb, out_xlsx, overwrite = TRUE)
  message(sprintf("Wrote %s (%d exhibit sheets + Contents).", out_xlsx, n_ok))
  if (length(rendered_png)) {
    message(sprintf("Rendered %d PNG(s): %s",
                    length(rendered_png), paste(basename(rendered_png), collapse = ", ")))
  }
  if (length(fred_failed)) {
    cli_or_message(sprintf("FRED series not populated (placeholder written): %s",
                           paste(fred_failed, collapse = ", ")))
  }
  if (length(missing_src)) {
    warning("Missing source sheets:\n  ", paste(missing_src, collapse = "\n  "))
  }
  invisible(out_xlsx)
}

if (!interactive() && sys.nframe() == 0L) {
  argv <- commandArgs(trailingOnly = TRUE)
  yr <- if (length(argv) >= 1L) as.integer(argv[[1]]) else 2030L
  build_paper_figure_data(year = yr)
}
