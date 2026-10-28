# Figure pipeline acceptance (docs/v1_2_figure_pipeline_plan.md, step F1):
# code/16_chart_data.R, run on the committed v1.0.1 reference run,
# reproduces the plotted columns of the 13 published v1.0.1 figures
# (tests/fixtures/charts_v1_0_1/, the live data.csv files with their BOMs
# stripped). The live files were reshaped by hand, so only the columns each
# spec plots are compared: text exactly, numbers to the precision the live
# file prints them with.

.REFERENCE_RUN <- here::here("results", "runs", "legacy_v1_0_1-202610281529")
.LIVE_CHARTS   <- here::here("tests", "fixtures", "charts_v1_0_1")
.FRED_FIGURES  <- c("gdp-growth-history", "labor-share-history")

withr::with_dir(here::here(), suppressMessages(source("code/16_chart_data.R")))

.built_charts <- local({
  out <- tempfile("charts_")
  withr::with_dir(here::here(), suppressMessages(suppressWarnings(
    write_chart_data(.REFERENCE_RUN, out_root = out))))
  file.path(out, "ai-fiscal")
})

# NULL when the built file matches the live one, else a message.
.chart_mismatch <- function(fig) {
  spec <- yaml::read_yaml(.spec_file(here::here("charts", "ai-fiscal", fig)))
  cols <- .spec_columns(spec)
  built <- fread(file.path(.built_charts, fig, "data.csv"), colClasses = "character")
  live  <- fread(file.path(.LIVE_CHARTS, paste0(fig, ".csv")), colClasses = "character")
  if (!all(cols %in% names(live))) return("live file lacks a plotted column")
  built <- built[, ..cols]; live <- live[, ..cols]
  if (nrow(built) != nrow(live)) return(sprintf("%d rows vs %d live", nrow(built), nrow(live)))

  is_num <- vapply(cols, function(c) !anyNA(suppressWarnings(as.numeric(live[[c]]))), logical(1))
  key <- function(d) do.call(order, lapply(cols, function(c)
    if (is_num[[c]]) as.numeric(d[[c]]) else d[[c]]))
  built <- built[key(built)]; live <- live[key(live)]
  for (c in cols) {
    if (!is_num[[c]]) {
      if (!identical(built[[c]], live[[c]])) return(sprintf("%s: text differs", c))
      next
    }
    l <- as.numeric(live[[c]]); b <- as.numeric(built[[c]])
    decimals <- nchar(sub("^[^.]*\\.?", "", live[[c]]))
    tol <- pmax(0.5 * 10^-decimals, 1e-9 * abs(l))
    if (any(abs(b - l) > tol)) {
      return(sprintf("%s: max abs diff %.3g", c, max(abs(b - l))))
    }
  }
  NULL
}

test_that("model-sourced figures reproduce the published v1.0.1 data", {
  model_figs <- setdiff(names(yaml::read_yaml(here::here("config", "charts.yaml"))$figures),
                        .FRED_FIGURES)
  expect_length(model_figs, 11L)
  for (fig in model_figs) expect_null(.chart_mismatch(fig), label = fig)
})

test_that("FRED-sourced appendix figures reproduce the published data", {
  # write_chart_data() skips these when ALFRED is unreachable.
  skip_if_not(all(dir.exists(file.path(.built_charts, .FRED_FIGURES))),
              "ALFRED unreachable; FRED figures not built")
  for (fig in .FRED_FIGURES) expect_null(.chart_mismatch(fig), label = fig)
})

test_that("every spec's plotted columns are exactly what its builder writes", {
  for (fig in list.dirs(.built_charts, full.names = FALSE, recursive = FALSE)) {
    spec  <- yaml::read_yaml(.spec_file(file.path(.built_charts, fig)))
    built <- names(fread(file.path(.built_charts, fig, "data.csv"), nrows = 1L))
    expect_setequal(built, .spec_columns(spec))
  }
})
