# Generate a synthetic tax_units_<year>.csv with the same column schema
# (names, R types, NA pattern, zero-sparsity, observed bounds) as the real
# PUF + SCF merged file pinned at data/tax_data, but values drawn
# independently from simple parametric distributions. The output carries
# no row-level economic information from the source: only column-level
# binary statistics (p_zero / p_na / p_true / p_neg) and observed bounds
# are used as parameters; numeric magnitudes come from a generic
# lognormal (positive support) or uniform (bounded < 1) draw, NOT from
# observed scale.
#
# Usage (requires read access to the pinned Tax-Data vintage):
#   Rscript code/make_synthetic_tax_units.R [year] [n_rows] [out_dir]
# Defaults: year = 2030, n_rows = 10000,
#   out_dir = tests/fixtures/synthetic_tax_data/baseline
#
# The generator deliberately does NOT preserve cross-column identities
# (e.g., wages != wages1 + wages2; filing_status does not constrain *2
# columns; n_dep is independent of dep_age*). The fixture is intended
# for I/O / schema / smoke-level tests in environments that lack PUF
# access — not for economic validation. See SCHEMA.md alongside the
# output for the per-column distribution choices.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

# Reproducibility: a fixed seed so the committed fixture is stable
# across regenerations from the same input vintage.
SYNTH_SEED <- 20260504L

# Profile one column → list of structural stats used by .draw_column().
.profile_column <- function(x) {
  cls <- class(x)[1]
  out <- list(class = cls, p_na = mean(is.na(x)))
  nz_x <- x[!is.na(x)]
  if (cls == "logical") {
    out$p_true <- if (length(nz_x)) mean(nz_x) else 0
  } else if (cls %in% c("integer", "numeric")) {
    out$p_zero <- if (length(nz_x)) mean(nz_x == 0) else 1
    out$p_neg  <- if (length(nz_x)) mean(nz_x <  0) else 0
    out$min    <- if (length(nz_x)) min(nz_x) else 0
    out$max    <- if (length(nz_x)) max(nz_x) else 0
    out$unique <- if (cls == "integer" && uniqueN(nz_x) <= 25L) {
      sort(unique(nz_x))
    } else NULL
  }
  out
}

# Draw n synthetic values for one column from its profile. Sign,
# zero-mass, and NA-mass are taken from the profile; magnitudes are
# generic (lognormal or uniform) so no PUF scale information leaks.
.draw_column <- function(prof, n) {
  cls <- prof$class
  out <- if (cls == "logical") {
    as.logical(rbinom(n, 1, prof$p_true %||% 0))
  } else if (cls == "integer") {
    if (!is.null(prof$unique) && length(prof$unique) == 0L) {
      # All-NA integer column: nothing observed to enumerate (and
      # sample(integer(0), ...) would error). p_na = 1 fills these
      # anyway; return typed NAs directly.
      rep(NA_integer_, n)
    } else if (!is.null(prof$unique)) {
      # Low-cardinality (filing_status, dep_age*, age*, n_dep*, etc.):
      # uniform draw from the observed enumeration. Index-based on
      # purpose: sample(x, ...) with a length-1 numeric x draws from
      # 1:x, not rep(x, n) — a constant code column k > 1 would come
      # out as uniform noise on 1..k (R's scalar-sample gotcha).
      prof$unique[sample.int(length(prof$unique), n, replace = TRUE)]
    } else if (prof$max == 0 && prof$min == 0) {
      integer(n)
    } else {
      val <- as.integer(round(runif(n, prof$min, prof$max)))
      if (prof$p_zero > 0) {
        val[rbinom(n, 1, prof$p_zero) == 1L] <- 0L
      }
      val
    }
  } else {                                          # numeric
    if (prof$max == 0 && prof$min == 0) {
      numeric(n)
    } else if (abs(prof$max) <= 1 && abs(prof$min) <= 1) {
      # Bounded values (probabilities, ratios, accrual fractions):
      # uniform on the observed [min, max] interval.
      runif(n, prof$min, prof$max)
    } else {
      # Dollar-flow magnitudes: generic lognormal centered at $1k
      # (log mean = log(1000), log sd = 2). NOT anchored to the
      # observed mean — only sign, zero mass, and clipping bounds
      # come from the profile.
      mag <- exp(rnorm(n, mean = log(1000), sd = 2))
      mag <- pmin(mag, max(abs(prof$min), abs(prof$max)))
      sgn <- ifelse(rbinom(n, 1, prof$p_neg) == 1L, -1, 1)
      val <- sgn * mag
      if (prof$p_zero > 0) {
        val[rbinom(n, 1, prof$p_zero) == 1L] <- 0
      }
      pmin(pmax(val, prof$min), prof$max)
    }
  }
  if (prof$p_na > 0) {
    out[rbinom(n, 1, prof$p_na) == 1L] <- NA
  }
  out
}

# Special-case columns where structural correctness matters more than
# distributional realism. `id` must be unique; `weight` must be positive.
# Joint constraints between columns (which the independent-column draw
# can violate) are enforced after the independent draw.
.apply_special_cases <- function(dt) {
  if ("id" %in% names(dt)) dt[, id := seq_len(.N)]
  if ("weight" %in% names(dt)) {
    dt[, weight := exp(rnorm(.N, mean = log(1000), sd = 1))]
  }
  .apply_joint_constraints(dt)
}

# Joint-constraint repairs. Independent per-column draws can produce
# rows that violate constraints the pipeline (and Tax-Simulator) rely
# on; this pass fixes them.
#
# Constraints enforced:
#
# - kg_lt != 0  =>  kg_lt_years_held non-NA AND kg_lt_basis non-NA.
#   Tax-Simulator's calc_kg_cpi_ratio() rejects NA on either side for
#   any non-zero kg_lt (gain or loss).
#   build_counterfactual()::.augment_kg_lt only fills these for units
#   receiving NEW LTCG flow, so a corrupted baseline persists into
#   the counterfactual and trips test-counterfactual.R.
.apply_joint_constraints <- function(dt) {
  if (all(c("kg_lt", "kg_lt_years_held", "kg_lt_basis") %in% names(dt))) {
    bad_yh <- !is.na(dt$kg_lt) & dt$kg_lt != 0 & is.na(dt$kg_lt_years_held)
    bad_b  <- !is.na(dt$kg_lt) & dt$kg_lt != 0 & is.na(dt$kg_lt_basis)
    # 5-year holding period and zero basis are arbitrary but well-formed
    # defaults; the fixture has no economic content so the specific
    # values don't matter, only that downstream code finds them non-NA.
    if (any(bad_yh)) dt[bad_yh, kg_lt_years_held := 5L]
    if (any(bad_b))  dt[bad_b,  kg_lt_basis := 0]
  }
  dt
}

make_synthetic_tax_units <- function(year     = 2030L,
                                     n_rows   = 10000L,
                                     source_dir = "data/tax_data",
                                     out_dir  = "tests/fixtures/synthetic_tax_data/baseline",
                                     seed     = SYNTH_SEED) {
  src_fp <- file.path(source_dir, "baseline", sprintf("tax_units_%d.csv", year))
  if (!file.exists(src_fp)) {
    cli::cli_abort(c(
      "Source tax-units file not found.",
      x = "Looked for {.path {src_fp}}.",
      i = paste0("This generator requires read access to the pinned ",
                 "PUF + SCF vintage. Point {.arg source_dir} at a ",
                 "Tax-Data folder, or run from a host with the symlink.")
    ))
  }

  cli::cli_inform("Profiling {.path {src_fp}}")
  src <- fread(src_fp)
  profiles <- lapply(src, .profile_column)
  rm(src); gc(verbose = FALSE)

  set.seed(seed)
  cli::cli_inform("Drawing {n_rows} synthetic rows × {length(profiles)} columns")
  syn <- as.data.table(lapply(profiles, .draw_column, n = n_rows))
  syn <- .apply_special_cases(syn)

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_fp <- file.path(out_dir, sprintf("tax_units_%d.csv", year))
  fwrite(syn, out_fp)
  cli::cli_inform("Wrote {.path {out_fp}} ({.val {format(file.size(out_fp), big.mark = ',')}} bytes)")

  schema_fp <- file.path(dirname(out_dir), "SCHEMA.md")
  .write_schema_audit(profiles, schema_fp, year, n_rows, seed)
  cli::cli_inform("Wrote audit {.path {schema_fp}}")

  invisible(out_fp)
}

# Per-column audit of what the generator did. Lets reviewers verify
# that no row-level info was preserved and that each column's draw
# strategy is documented.
.write_schema_audit <- function(profiles, fp, year, n, seed) {
  rows <- vapply(names(profiles), function(nm) {
    p <- profiles[[nm]]
    strat <- if (p$class == "logical") {
      sprintf("bernoulli(p_true=%.4f)", p$p_true %||% 0)
    } else if (p$class == "integer") {
      if (!is.null(p$unique)) {
        sprintf("sample({%s})", paste(p$unique, collapse = ","))
      } else if (p$max == 0 && p$min == 0) {
        "all-zero"
      } else {
        sprintf("uniform_int(%g, %g) | p_zero=%.4f",
                p$min, p$max, p$p_zero %||% 0)
      }
    } else {
      if (p$max == 0 && p$min == 0) {
        "all-zero"
      } else if (abs(p$max) <= 1 && abs(p$min) <= 1) {
        sprintf("uniform(%.4f, %.4f)", p$min, p$max)
      } else {
        sprintf("lognormal(log=log(1000),sd=2) clipped to [%g,%g] | p_zero=%.4f, p_neg=%.4f",
                p$min, p$max, p$p_zero %||% 0, p$p_neg %||% 0)
      }
    }
    sprintf("| `%s` | %s | %.4f | %s |", nm, p$class, p$p_na, strat)
  }, character(1))

  writeLines(c(
    sprintf("# Synthetic tax-units fixture (year = %d, n = %d)", year, n),
    "",
    "Generated by `code/make_synthetic_tax_units.R` from a real PUF + SCF",
    sprintf("vintage. Seed = `%d`. **No row-level economic information from", seed),
    "the source is preserved**: per-column the only inputs to the draw are",
    "type, NA rate, zero/negative/true rates, and observed bounds. Numeric",
    "magnitudes come from a generic lognormal (log mean = log(1000), log sd =",
    "2) clipped to the observed support, or a uniform draw for bounded",
    "[-1, 1]-style columns. Cross-column identities (per-spouse splits,",
    "filing-status-conditional zeros, n_dep vs. dep_*, etc.) are NOT",
    "preserved.",
    "",
    "## Column draw strategies",
    "",
    "| column | type | p_na | strategy |",
    "|---|---|---|---|",
    rows
  ), fp)
}

if (!interactive() && sys.nframe() == 0L) {
  argv  <- commandArgs(trailingOnly = TRUE)
  year  <- if (length(argv) >= 1) as.integer(argv[1]) else 2030L
  n     <- if (length(argv) >= 2) as.integer(argv[2]) else 10000L
  outd  <- if (length(argv) >= 3) argv[3] else
           "tests/fixtures/synthetic_tax_data/baseline"
  make_synthetic_tax_units(year = year, n_rows = n, out_dir = outd)
}
