# SZ pass-through split (01_load_data.R::apply_passthrough_split).
#
# The fixture-level invariant tests elsewhere only check that y_l and y_k
# come out positive, so a sign error that swapped the labor and capital
# shares of pass-through profit (or routed wages into y_k) would pass
# them. These tests pin the *direction* of the split on a tiny
# hand-built unit set with known answers, recomputing the documented SZ
# formula independently and asserting the loader matches it exactly.

# Minimal params: apply_passthrough_split() only reads $raw$passthrough.
.sz_params <- list(raw = list(passthrough = list(
  wage_threshold_percentile   = 99.99,
  wage_threshold_conditioning = "positive_wages",
  active_below_capital_share  = 0.25,
  active_above_capital_share  = 0.75,
  passive_capital_share       = 0.75
)))

# All required columns default to zero; override per unit below. Exactly
# one unit carries positive wages (100), so the weighted P99.99 wage
# threshold W* is a known 100 and active profit can be made to straddle it.
.sz_fixture <- function() {
  zero <- function(...) rep(0, 6)
  data.table::data.table(
    id                 = 1:6,
    weight             = rep(1, 6),
    #                     A    B    C    D    E      F
    wages              = c(100,  0,   0,   0,   0,    0),
    sole_prop          = zero(),
    farm               = zero(),
    # Active S-corp: unit C below W* (net 80), unit D above W* (net 300).
    scorp_active       = c(  0,  0,  80, 300,   0,    0),
    scorp_active_loss  = zero(),
    # Passive S-corp: unit E (net 400).
    scorp_passive      = c(  0,  0,   0,   0, 400,    0),
    scorp_passive_loss = zero(),
    # Active partnership: unit F with a loss (net 200 - 50 = 150, > W*).
    part_active        = c(  0,  0,   0,   0,   0,  200),
    part_active_loss   = c(  0,  0,   0,   0,   0,   50),
    part_passive       = zero(),
    part_passive_loss  = zero(),
    # Pure-capital PUF items (unit B).
    txbl_int           = c(  0,200,   0,   0,   0,    0),
    exempt_int         = zero(),
    div_ord            = c(  0, 10,   0,   0,   0,    0),
    div_pref           = c(  0, 20,   0,   0,   0,    0),
    kg_st              = zero(),
    kg_lt              = c(  0, 30,   0,   0,   0,    0),
    other_gains        = zero(),
    rent               = zero(),
    rent_loss          = zero(),
    estate             = zero(),
    estate_loss        = zero(),
    txbl_ira_dist      = zero(),
    txbl_pens_dist     = zero()
  )
}

# Independent reimplementation of the documented SZ rule. Deliberately
# NOT copied from 01_load_data.R — if the loader flips a share, this and
# the loader disagree.
.sz_expected <- function(dt, pt, W_star) {
  cap_b <- pt$active_below_capital_share
  cap_a <- pt$active_above_capital_share
  psh   <- pt$passive_capital_share
  active_cap_share <- function(pos, loss) {
    net   <- pos - loss
    below <- pmin(pmax(net, 0), W_star)
    above <- pmax(net - W_star, 0)
    ifelse(net > 0, (below * cap_b + above * cap_a) / net, cap_b)
  }
  sa_cs  <- active_cap_share(dt$scorp_active, dt$scorp_active_loss)
  pa_cs  <- active_cap_share(dt$part_active,  dt$part_active_loss)
  sa_net <- dt$scorp_active  - dt$scorp_active_loss
  pa_net <- dt$part_active   - dt$part_active_loss
  sp_net <- dt$scorp_passive - dt$scorp_passive_loss
  pp_net <- dt$part_passive  - dt$part_passive_loss

  y_l <- dt$wages + dt$sole_prop + dt$farm +
    (1 - sa_cs) * sa_net + (1 - psh) * sp_net +
    (1 - pa_cs) * pa_net + (1 - psh) * pp_net
  y_k <- dt$txbl_int + dt$exempt_int + dt$div_ord + dt$div_pref +
    dt$kg_st + dt$kg_lt + dt$other_gains +
    (dt$rent - dt$rent_loss) + (dt$estate - dt$estate_loss) +
    dt$txbl_ira_dist + dt$txbl_pens_dist +
    sa_cs * sa_net + psh * sp_net + pa_cs * pa_net + psh * pp_net
  list(y_l = y_l, y_k = y_k)
}

test_that("W* is the weighted P99.99 of positive wages (here, 100)", {
  dt  <- .sz_fixture()
  out <- apply_passthrough_split(data.table::copy(dt), .sz_params)
  expect_equal(attr(out, "sz_W_star"), 100, tolerance = 1e-9)
})

test_that("y_l / y_k match an independent SZ recomputation (sign-locked)", {
  dt  <- .sz_fixture()
  out <- apply_passthrough_split(data.table::copy(dt), .sz_params)
  exp <- .sz_expected(dt, .sz_params$raw$passthrough, W_star = 100)
  expect_equal(out$y_l, exp$y_l, tolerance = 1e-9)
  expect_equal(out$y_k, exp$y_k, tolerance = 1e-9)
})

test_that("wages flow only to y_l; pure capital flows only to y_k", {
  dt  <- .sz_fixture()
  out <- apply_passthrough_split(data.table::copy(dt), .sz_params)
  # Unit A: wages = 100, nothing else.
  expect_equal(out$y_l[1], 100, tolerance = 1e-9)
  expect_equal(out$y_k[1], 0,   tolerance = 1e-9)
  # Unit B: txbl_int 200 + div_ord 10 + div_pref 20 + kg_lt 30 = 260.
  expect_equal(out$y_l[2], 0,   tolerance = 1e-9)
  expect_equal(out$y_k[2], 260, tolerance = 1e-9)
})

test_that("below-W* active profit splits 25% capital / 75% labor (not flipped)", {
  dt  <- .sz_fixture()
  out <- apply_passthrough_split(data.table::copy(dt), .sz_params)
  # Unit C: scorp_active net 80, entirely below W* = 100. Capital share
  # is active_below_capital_share = 0.25, so y_k gets 20 and y_l gets 60.
  # A labor<->capital flip would give y_k = 60, y_l = 20.
  expect_equal(out$y_k[3], 0.25 * 80, tolerance = 1e-9)
  expect_equal(out$y_l[3], 0.75 * 80, tolerance = 1e-9)
})

test_that("the split conserves mass: y_l + y_k == sum of source components", {
  dt  <- .sz_fixture()
  out <- apply_passthrough_split(data.table::copy(dt), .sz_params)
  components <- with(dt,
    wages + sole_prop + farm +
      (scorp_active - scorp_active_loss) + (scorp_passive - scorp_passive_loss) +
      (part_active  - part_active_loss)  + (part_passive  - part_passive_loss) +
      txbl_int + exempt_int + div_ord + div_pref + kg_st + kg_lt + other_gains +
      (rent - rent_loss) + (estate - estate_loss) +
      txbl_ira_dist + txbl_pens_dist)
  expect_equal(out$y_l + out$y_k, components, tolerance = 1e-9)
})
