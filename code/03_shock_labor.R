# Step A: redistribute the implied labor-income change across tax units.
#
# Aggregate target derived by applying the labor growth rate g_l to the
# baseline aggregate labor income Y0^L$:
#   Y1^L$ = Y0^L$ * (1 + g_l).
#
# All scenarios hold negative- and zero-baseline labor at baseline and push
# the full Y1^L$ adjustment onto the positive-baseline subset. Total y_l1
# still aggregates to Y1^L$ by construction.
#
# Scenarios:
#   S0 Proportional: positives scale by rho_pos = Y1^L_pos$ / Y0^L_pos$,
#                    where Y1^L_pos$ = Y1^L$ - (negative-baseline aggregate)
#                    and Y0^L_pos$ = sum over positive baseline.
#   S2 Compressive : ln(y_l1) = mu_1 + lambda_S2 * (ln(y_l) - mu_0),
#                    lambda_S2 = 1 - k * g_y.
#   S3 Expansive   : ln(y_l1) = mu_1 + lambda_S3 * (ln(y_l) - mu_0),
#                    lambda_S3 = 1 + k * g_y.
#   lambda is the ratio of post- to pre-shock standard deviation of log(y_l)
#   on the positive subset; k (config: labor_inequality.k, default 1) is the
#   multiplier on the productivity shock g_y. mu_1 is solved by uniroot so
#   the positive subset hits Y1^L_pos$. Aborts if lambda <= 0.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

shock_labor <- function(dt, params, scenario) {
  y0_l <- sum(dt$weight * dt$y_l)
  y1_l <- y0_l * (1 + params$g_l)
  rho <- y1_l / y0_l

  k        <- params$k_inequality
  lambda_s2 <- 1 - k * params$g_y
  lambda_s3 <- 1 + k * params$g_y
  if (scenario %in% c("S2", "S3")) {
    sig <- if (scenario == "S2") lambda_s2 else lambda_s3
    if (sig <= 0) {
      cli::cli_abort(c(
        "Labor-inequality lambda must be positive (got {.val {sig}}).",
        x = "k * g_y = {.val {k * params$g_y}} (k = {.val {k}}, g_y = {.val {params$g_y}}).",
        i = "Reduce {.field labor_inequality.k} so that {.code k * g_y < 1}."
      ))
    }
  }

  y_l1 <- switch(scenario,
    S0 = .shock_proportional(dt, y1_l),
    S2 = .shock_log_affine(dt, y1_l, lambda = lambda_s2),
    S3 = .shock_log_affine(dt, y1_l, lambda = lambda_s3),
    cli::cli_abort(c(
      "Unknown {.arg labor_scenario}: {.val {scenario}}.",
      i = "Choose one of {.val S0}, {.val S2}, {.val S3}."
    ))
  )

  # Slim return: only the columns downstream code reads. Avoids mutating
  # the caller's dt so the orchestrator can drop the per-cell copy().
  out <- data.table(id = dt$id, weight = dt$weight, y_l = dt$y_l, y_l1 = y_l1)

  lambda_used <- switch(scenario, S0 = 1, S2 = lambda_s2, S3 = lambda_s3)
  setattr(out, "step_a", list(
    scenario  = scenario,
    y0_l_dollar = y0_l,
    y1_l_target = y1_l,
    y1_l_actual = sum(out$weight * out$y_l1),
    rho       = rho,
    k         = k,
    lambda     = lambda_used
  ))
  out
}

.shock_proportional <- function(dt, y1_l) {
  pos <- dt$y_l > 0
  neg <- dt$y_l < 0
  y0_l_pos     <- sum(dt$weight[pos] * dt$y_l[pos])
  neg_baseline <- sum(dt$weight[neg] * dt$y_l[neg])
  rho_pos      <- (y1_l - neg_baseline) / y0_l_pos
  y_l1 <- dt$y_l
  y_l1[pos] <- rho_pos * dt$y_l[pos]
  y_l1
}

.shock_log_affine <- function(dt, y1_l, lambda) {
  pos <- dt$y_l > 0
  if (!any(pos)) {
    cli::cli_abort("No positive labor income in sample; log-affine transform undefined.")
  }

  w   <- dt$weight[pos]
  L   <- dt$y_l[pos]
  ln  <- log(L)
  mu0 <- sum(w * ln) / sum(w)

  # Hold negative- and zero-baseline labor at baseline; the positive subset
  # absorbs the full aggregate adjustment.
  neg <- dt$y_l < 0
  neg_baseline <- sum(dt$weight[neg] * dt$y_l[neg])
  y1_l_pos <- y1_l - neg_baseline

  agg_residual <- function(mu1) {
    sum(w * exp(mu1 + lambda * (ln - mu0))) - y1_l_pos
  }
  res <- uniroot(agg_residual, lower = -10, upper = 10, extendInt = "yes")
  mu1 <- res$root

  y_l1 <- dt$y_l
  y_l1[pos] <- exp(mu1 + lambda * (ln - mu0))

  # Renormalize the positive subset to absorb uniroot residual.
  scale <- y1_l_pos / sum(w * y_l1[pos])
  y_l1[pos] <- y_l1[pos] * scale
  y_l1
}
