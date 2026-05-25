# Step A: redistribute the implied labor-income change across tax units.
#
# Aggregate target derived by applying the normalized factor-evolution rate
# to data L0$:
#   L1$ = L0$ * (1 + alpha * gk).
#
# All scenarios hold negative- and zero-baseline labor at baseline and push
# the full L1$ adjustment onto the positive-baseline subset. Total YiL1
# still aggregates to L1$ by construction.
#
# Scenarios:
#   S0 Proportional: positives scale by rho_pos = L1_pos$ / L0_pos$,
#                    where L1_pos$ = L1$ - (negative-baseline aggregate)
#                    and L0_pos$ = sum over positive baseline.
#   S2 Compressive : ln(YiL1) = mu_1 + sigma_S2 * (ln(YiL) - mu_0),
#                    sigma_S2 = 1 - k * g_y.
#   S3 Expansive   : ln(YiL1) = mu_1 + sigma_S3 * (ln(YiL) - mu_0),
#                    sigma_S3 = 1 + k * g_y.
#   sigma is the ratio of post- to pre-shock standard deviation of log(YiL)
#   on the positive subset; k (config: labor_inequality.k, default 1) is the
#   multiplier on the productivity shock g_y. mu_1 is solved by uniroot so
#   the positive subset hits L1_pos$. Aborts if sigma <= 0.

suppressPackageStartupMessages({
  library(data.table)
})

source("code/00_utils.R")

shock_labor <- function(dt, params, scenario) {
  L0d <- sum(dt$weight * dt$YiL)
  L1d <- L0d * (1 + params$alpha * params$gk)
  rho <- L1d / L0d

  k        <- params$k_inequality
  sigma_s2 <- 1 - k * params$gy
  sigma_s3 <- 1 + k * params$gy
  if (scenario %in% c("S2", "S3")) {
    sig <- if (scenario == "S2") sigma_s2 else sigma_s3
    if (sig <= 0) {
      cli::cli_abort(c(
        "Labor-inequality sigma must be positive (got {.val {sig}}).",
        x = "k * g_y = {.val {k * params$gy}} (k = {.val {k}}, g_y = {.val {params$gy}}).",
        i = "Reduce {.field labor_inequality.k} so that {.code k * g_y < 1}."
      ))
    }
  }

  YiL1 <- switch(scenario,
    S0 = .shock_proportional(dt, L1d),
    S2 = .shock_log_affine(dt, L1d, sigma = sigma_s2),
    S3 = .shock_log_affine(dt, L1d, sigma = sigma_s3),
    cli::cli_abort(c(
      "Unknown {.arg labor_scenario}: {.val {scenario}}.",
      i = "Choose one of {.val S0}, {.val S2}, {.val S3}."
    ))
  )

  # Slim return: only the columns downstream code reads. Avoids mutating
  # the caller's dt so the orchestrator can drop the per-cell copy().
  out <- data.table(id = dt$id, weight = dt$weight, YiL = dt$YiL, YiL1 = YiL1)

  sigma_used <- switch(scenario, S0 = 1, S2 = sigma_s2, S3 = sigma_s3)
  setattr(out, "step_a", list(
    scenario  = scenario,
    L0_dollar = L0d,
    L1_target = L1d,
    L1_actual = sum(out$weight * out$YiL1),
    rho       = rho,
    k         = k,
    sigma     = sigma_used
  ))
  out
}

.shock_proportional <- function(dt, L1) {
  pos <- dt$YiL > 0
  neg <- dt$YiL < 0
  L0_pos       <- sum(dt$weight[pos] * dt$YiL[pos])
  neg_baseline <- sum(dt$weight[neg] * dt$YiL[neg])
  rho_pos      <- (L1 - neg_baseline) / L0_pos
  YiL1 <- dt$YiL
  YiL1[pos] <- rho_pos * dt$YiL[pos]
  YiL1
}

.shock_log_affine <- function(dt, L1, sigma) {
  pos <- dt$YiL > 0
  if (!any(pos)) {
    cli::cli_abort("No positive labor income in sample; log-affine transform undefined.")
  }

  w   <- dt$weight[pos]
  L   <- dt$YiL[pos]
  ln  <- log(L)
  mu0 <- sum(w * ln) / sum(w)

  # Hold negative- and zero-baseline labor at baseline; the positive subset
  # absorbs the full aggregate adjustment.
  neg <- dt$YiL < 0
  neg_baseline <- sum(dt$weight[neg] * dt$YiL[neg])
  L1_pos <- L1 - neg_baseline

  agg_residual <- function(mu1) {
    sum(w * exp(mu1 + sigma * (ln - mu0))) - L1_pos
  }
  res <- uniroot(agg_residual, lower = -10, upper = 10, extendInt = "yes")
  mu1 <- res$root

  YiL1 <- dt$YiL
  YiL1[pos] <- exp(mu1 + sigma * (ln - mu0))

  # Renormalize the positive subset to absorb uniroot residual.
  scale <- L1_pos / sum(w * YiL1[pos])
  YiL1[pos] <- YiL1[pos] * scale
  YiL1
}
