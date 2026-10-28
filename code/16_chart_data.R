# Website figure data (docs/v1_2_figure_pipeline_plan.md, step F1).
#
# For every figure in config/charts.yaml, build the data its chart.yaml /
# table.yaml plots from a run directory, and write a complete spec folder
# that the chart engine can validate, render, and publish:
#
#   <run dir>/charts/<collection>/article.yaml
#   <run dir>/charts/<collection>/<figure>/{chart,table}.yaml + data.csv
#
# Specs are copied unchanged from charts/<collection>/ (the tracked copy
# never holds data); only data.csv is generated, with exactly the columns
# the spec plots. Builders reuse the figure suite's data functions
# (10_figures.R) and paper_figure_data.R's FRED series, so a published
# number and its diagnostic PNG share one definition.
#
# Usage: Rscript code/16_chart_data.R <run dir>

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")
source("code/08_aggregate.R")
source("code/09_tables_figures.R")
source("code/10_figures.R")
source("code/paper_figure_data.R")

.CHART_MANIFEST <- "config/charts.yaml"
.CHART_SPECS    <- "charts"

# Site vocabulary where it differs from the axis registry's labels.
.SITE_SHARE_MODE <- c(R = "Reallocated", F = "Fixed")
# Figure 7 shows one cell: Moderate, reallocated shares, proportional labor.
.ATR_FIGURE_SCENARIO <- "ai_M_R_S0_V1"

# Everything the builders read from one run directory.
.chart_context <- function(run_dir) {
  inputs    <- file.path(run_dir, "inputs")
  runscript <- file.path(inputs, "runscript.csv")
  year      <- .runscript_policy_year(runscript)
  ctx <- .load_figure_inputs(runscript, file.path(run_dir, "tables"), year)
  c(ctx, list(
    year        = year,
    tables      = file.path(run_dir, "tables"),
    params_yaml = file.path(inputs, "params.yaml"),
    cell_params = fread(file.path(inputs, "runscript_cell_params.csv"))
  ))
}

# ai_speed / labor_dist: the site's names for the variant and labor axes.
.site_axes <- function(d) {
  d <- as.data.table(d)
  d[, `:=`(ai_speed   = as.character(variant_label),
           labor_dist = as.character(labor_label))]
}

chart_revenue_headline <- function(ctx) {
  d <- .site_axes(fig_headline_revenue(ctx$wide_R, ctx$year)$data)
  d[, .(ai_speed, labor_dist, total_with_macro_cit)]
}

chart_revenue_by_income_type <- function(ctx) {
  d <- .site_axes(fig_decomp(ctx$decomp, ctx$macro_per_scn[share_mode == "R"],
                             ctx$axes_per_scn_R, ctx$year)$data)
  d[, .(ai_speed, labor_dist, component_label = as.character(component_label),
        delta_B)]
}

chart_revenue_by_instrument <- function(ctx) {
  d <- .site_axes(fig_instrument_breakdown(ctx$long_R, ctx$year)$data)
  d[, .(ai_speed, labor_dist, instrument_label = as.character(instrument_label),
        delta)]
}

chart_revenue_vs_factor_income <- function(ctx) {
  d <- .site_axes(fig_revenue_vs_gross_factor(ctx$wide_R, ctx$macro_per_scn,
                                              ctx$year)$data)
  d[, .(ai_speed, labor_dist,
        `Gross Factor Income Expansion` = delta_factor_gross,
        `Change in Total Revenue`       = total_with_macro_cit)]
}

chart_revenue_fixed_vs_reallocated <- function(ctx) {
  d <- .site_axes(ctx$wide)
  d[, .(ai_speed, labor_dist,
        share_mode = unname(.SITE_SHARE_MODE[as.character(share_mode)]),
        total_with_macro_cit)]
}

chart_inequality_gini <- function(ctx) {
  d <- .site_axes(fig_gini_delta(ctx$gini, ctx$axes_per_scn_R, ctx$year)$data)
  d[, .(ai_speed, labor_dist, income_concept, delta)]
}

chart_atr_by_decile <- function(ctx) {
  axes <- .attach_axis_labels(ctx$axes_per_scn[scenario_id == .ATR_FIGURE_SCENARIO])
  d <- fig_atr_decile_one(ctx$atr_dec[scenario_id == .ATR_FIGURE_SCENARIO],
                          axes, ctx$year)$data
  as.data.table(d)[, .(decile = as.integer(as.character(decile)), dATR)]
}

chart_revenue_vs_pretax_income <- function(ctx) {
  d <- .site_axes(fig_revenue_vs_income(ctx$wide_R, ctx$income, ctx$year)$data)
  d[, .(ai_speed, labor_dist, delta_Y, total_with_macro_cit)]
}

chart_debt_to_gdp <- function(ctx) {
  fp <- file.path(ctx$tables, sprintf("blsmm_debt_to_gdp_%d.csv", ctx$year))
  if (!file.exists(fp)) return(NULL)  # BLSMM step skipped for this run
  d <- .site_axes(fread(fp)[share_mode == "R"])
  d[, .(ai_speed, labor_dist, blsmm_debt_to_gdp_year_pct)]
}

# Table 1 / Appendix Table 1: one row per (parameter, scenario).
chart_key_parameters <- function(ctx) {
  shock <- yaml::read_yaml(ctx$params_yaml)$shock
  kp    <- build_key_parameters_table(ctx$cell_params, shock_params = shock)$tbl
  rows  <- list(
    ai_adoption = c(gdp_growth = "r_ai_annual", capital_share = "theta_1_K",
                    labor_share = "theta_1_L"),
    growth      = c(gdp = "g_y", capital = "g_k", labor = "labor_growth"),
    inequality  = c(Compressive = "S2", Proportional = "S0", Expansive = "S3")
  )
  rbindlist(lapply(names(rows), function(group) {
    rbindlist(lapply(names(rows[[group]]), function(param) {
      data.table(group = group, param = param, bank = "ai_scenarios",
                 scenario = unname(.AXIS_VARIANTS[as.character(kp$variant)]),
                 value = kp[[rows[[group]][[param]]]])
    }))
  }))
}

chart_gdp_growth_history <- function(ctx) {
  d <- .build_fred_gdp_growth(.read_scenario_params(ctx$params_yaml))
  if (is.null(d)) return(NULL)  # FRED unreachable
  d <- melt(as.data.table(d, check.names = FALSE), id.vars = "Year",
            measure.vars = c("GDP Growth", "CBO Projection"),
            variable.name = "series", value.name = "gdp_growth",
            na.rm = TRUE, variable.factor = FALSE)
  d[series == "GDP Growth", series := "Actual"]
  d[, .(Year, series, gdp_growth)]
}

chart_labor_share_history <- function(ctx) {
  d <- .build_fred_labor_share(.read_scenario_params(ctx$params_yaml))
  if (is.null(d)) return(NULL)  # FRED unreachable
  d <- as.data.table(d, check.names = FALSE)
  d[, .(Year, `Labor Share`)]
}

# The data columns a spec plots: a chart's `columns:` mapping, or a table's
# stub, header, and value columns.
.spec_columns <- function(spec) {
  if (!is.null(spec$columns)) return(unique(unlist(spec$columns, use.names = FALSE)))
  stub <- vapply(spec$stub, function(s) if (is.list(s)) s$label else s, character(1))
  unique(c(stub, unlist(spec$header), spec$value))
}

.spec_file <- function(dir) {
  fp <- file.path(dir, c("chart.yaml", "table.yaml"))
  fp <- fp[file.exists(fp)]
  if (length(fp) != 1L) cli::cli_abort("Expected one chart.yaml or table.yaml in {.path {dir}}.")
  fp
}

# Build every figure's data for one run and write the spec folders.
# Returns the figure names written; figures whose builder returns NULL
# (an optional source absent) are skipped with a warning.
write_chart_data <- function(run_dir,
                             manifest_path = .CHART_MANIFEST,
                             specs_root    = .CHART_SPECS,
                             out_root      = file.path(run_dir, "charts")) {
  manifest   <- yaml::read_yaml(manifest_path)
  collection <- manifest$collection
  spec_dir   <- file.path(specs_root, collection)
  out_dir    <- file.path(out_root, collection)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(spec_dir, "article.yaml"), out_dir, overwrite = TRUE)

  ctx     <- .chart_context(run_dir)
  written <- character()
  for (fig in names(manifest$figures)) {
    entry <- manifest$figures[[fig]]
    spec_fp <- .spec_file(file.path(spec_dir, fig))
    data <- match.fun(entry$builder)(ctx)
    if (is.null(data)) {
      cli::cli_warn("Skipped {.val {fig}}: a source ({.val {entry$sources}}) is unavailable for this run.")
      next
    }
    cols <- .spec_columns(yaml::read_yaml(spec_fp))
    if (!setequal(names(data), cols)) {
      cli::cli_abort(c(
        "Builder {.fn {entry$builder}} does not match the columns {.val {fig}} plots.",
        x = "Built: {.val {names(data)}}; spec: {.val {cols}}."
      ))
    }
    fig_out <- file.path(out_dir, fig)
    dir.create(fig_out, showWarnings = FALSE)
    file.copy(spec_fp, fig_out, overwrite = TRUE)
    # Engine CSV rules: UTF-8 without a BOM, no thousands separators.
    fwrite(data, file.path(fig_out, "data.csv"), bom = FALSE)
    written <- c(written, fig)
  }
  cli::cli_inform("Wrote {length(written)} of {length(manifest$figures)} figure{?s} to {.path {out_dir}}.")
  invisible(written)
}

# Validate the run's figures and render preview pages through the pinned
# chart engine (tools/charts.mjs). Skipped, not failed, where Node or the
# engine is absent (e.g. a batch job without the nodejs module); a figure
# that fails validation aborts.
render_chart_previews <- function(run_dir, manifest_path = .CHART_MANIFEST) {
  collection_dir <- file.path(run_dir, "charts", yaml::read_yaml(manifest_path)$collection)
  if (!nzchar(Sys.which("node")) ||
      !dir.exists(file.path("node_modules", "budget-lab-chart-engine"))) {
    cli::cli_inform(c(
      "Node or the chart engine is unavailable; skipping figure validation and previews.",
      i = "Later: {.code npm run charts:validate -- {collection_dir}} (after {.code npm install})."
    ))
    return(invisible(FALSE))
  }
  quote_arg <- function(x) shQuote(x, type = if (.Platform$OS.type == "windows") "cmd" else "sh")
  for (cmd in c("validate", "render")) {
    status <- system2("node", c("tools/charts.mjs", cmd, quote_arg(collection_dir)))
    if (!identical(as.integer(status), 0L)) {
      cli::cli_abort("Figure {cmd} failed for {.path {collection_dir}}; see the output above.")
    }
  }
  invisible(TRUE)
}

if (!interactive() && sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript code/16_chart_data.R <run dir>")
  write_chart_data(args[[1]])
  render_chart_previews(args[[1]])
}
