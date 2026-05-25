# Calibrating `labor_inequality.k`

*Memo — drafted 2026-05-07. For later review; numbers cited from memory
need verification before relying on them.*

## The question

Step A's S2/S3 scenarios rescale the standard deviation of log labor
income by `σ_post / σ_pre = 1 ± k · g_y`. We've pinned `k = 1.0` as a
placeholder — the literal "proportional-to-g_y" mapping the user's
intuition called for. What value of k is defensible, and what range
should we sweep as sensitivity?

## What k means in our run

Under Karger's 5-yr cumulative `g_y ∈ {5.1%, 6.7%, 10.4%}` (S/M/R), at
`k = 1`:

- S3 σ-factor:   1.051 / 1.067 / 1.104   (log-wage dispersion up 5-10%)
- S2 σ-factor:   0.949 / 0.933 / 0.896

Headline impact at k = 1 (from the 09:53 run):
R/S3/V1 aftertax Gini Δ = +0.035; R/S2/V1 = -0.026.

The transformation is approximately linear in k for small bites, so
`k = 2` roughly doubles the Gini deltas, `k = 0.5` halves them.

## Three candidate calibration anchors

**(a) Task-based theory.** Derive k from a CES task model in the
Acemoglu-Restrepo lineage (2018 AER, 2022 ECMA). In a tractable
2-skill aggregator with task displacement, the dispersion impact has
a closed form roughly proportional to the within-skill task
elasticity divided by `(1 − share_displaced)`. Pro: micro-founded,
citable. Con: highly sensitive to elasticity assumptions; we'd have
to commit to a specific parameterization and defend it. Order of
magnitude under "standard" parameterizations: **k somewhere in
[1, 3]**, but I have not derived this — to verify before citing.

**(b) Historical analogy (skill-biased technical change, ~1980-2010).**
Back-solve k from the IT/computerization episode: ~30% cumulative TFP
growth over the period coincided with sizable widening of the college
wage premium and within-group dispersion. Implied k on σ(log w) is
plausibly in **[0.5, 1.5]**, depending on horizon, dispersion measure,
and how much of the inequality rise gets attributed to
non-technological factors (institutions, trade, top-end finance).
Pro: empirical. Con: AI may displace differently than IT (cognitive vs.
routine); the literature contests the magnitude. *All numbers in this
paragraph are recalled, not freshly checked.*

**(c) Karger-consistency.** Karger et al. (NBER w35046, the source of
our `g_y` targets) presumably implies some dispersion change in their
own micro framework. If they report a Gini or variance change, we can
back-solve k so our S2/S3 are aligned with their structural story
rather than imposed independently. Pro: internal consistency with the
productivity-shock source we're already citing. Con: depends on
whether Karger reports a usable inequality number; if not, this
collapses to (a) or (b). **Strongest candidate for the central
estimate if the number exists.**

## Recommended path

1. Spend an hour with Karger §5-6 (and the appendix at
   `docs/w35046_appendix.pdf`) looking for a directly back-solvable k.
   If found, that's the central estimate.
2. If not, fall back to (a) — pick an Acemoglu-Restrepo
   parameterization, derive k analytically, document the elasticity
   assumption in `config/scenario_params.yaml` next to the `k` entry.
3. Either way, run `k ∈ {0.5, 1, 2, 3}` on the canonical grid as a
   fan and report sensitivity in 09's PDF (or a new sensitivity
   sheet on the publishable bundle). The `σ ≤ 0` abort caps `k` at
   `1/g_y` ≈ 9.6 for the R variant, well above any defensible value.

## Open issues to surface in the memo

- **Symmetric k for S2 and S3?** Task-displacement theory typically
  predicts asymmetric impacts: AI-as-substitute stretches (the S3
  "expansive" case) more than AI-as-complement equalizes (the S2
  "compressive" case), or vice versa depending on the automation
  pattern. Splitting into `k_compress` and `k_expand` doubles the
  parameter surface but is more honest. Worth a sensitivity pass even
  if we publish symmetric.
- **k constant vs. k(g_y)?** A more aggressive view: large shocks
  stretch the top of the distribution more than proportionally, so
  `k` is increasing in `g_y`. We've assumed constant k. Theoretical
  defense possible but not free; defer unless Karger or A-R make it
  central.
- **Dispersion measure choice.** Current σ is on log YiL on the
  positive subset. Alternatives (variance of log income including
  zeros, P90/P10, top 1% share) could imply different k's. We pick
  σ(log w) for tractability of the log-affine transform; flag the
  choice when reporting.

## What I'd want to know before pinning a number

- Does Karger report an aftertax inequality delta for any of S/M/R?
  (Anchor for (c).)
- What's the canonical task-elasticity in Acemoglu-Restrepo 2022 we'd
  defer to? (Anchor for (a).)
- Should the central run match a stylized fact (say, "AI doubles the
  rise in wage dispersion seen during the IT boom") or be derived
  from primitives? (Anchor for the framing in the paper.)
