# Methodology appendix: R1 retirement cascade and V1 realization

## §A. About this appendix

The main methodology document
([`ai_fiscal_methodology.md`](ai_fiscal_methodology.md)) carries short
pointers to two extended treatments that did not fit the page budget
of the published write-up. This appendix collects the full
derivations.

- **§B** documents the R1 income-flow retirement cascade — the
  procedure that distributes the aggregate retirement slice from the
  within-unit capital allocation across tax units actually drawing
  retirement income today, and splits the routed flow between taxable
  pension and IRA distributions.
- **§C** documents the V1 mechanical realization treatment for
  long-term capital gains.

Implementation cross-references:

- **R1:** `code/04_allocate_capital.R::apply_retirement_cascade_R1`;
  calibration constants in `config/retirement_calibration.yaml`.
- **V1:** `code/05_realization.R::apply_realization`.

The v1.0 release pipeline runs R1 and V1 exclusively; alternative
treatments (R2 / V2 / V3) appear in the Future work section of the
main document.

## §B. Retirement flow treatment (R1 income-flow cascade)

Retirement assets sit awkwardly in this setting because while
retirement wealth is held by many households across the age
distribution, retirement *income* is generally realized by older
households alone. Allocating the AI retirement increment in
proportion to retirement wealth alone would distribute the flow to
working-age households who are not yet drawing from their accounts —
producing distributional numbers that misrepresent how AI
retirement income would actually land. We therefore apply the
following procedure.

**First**, compute the realization pool at the population level:

$$
F \;=\; \sum_i w_i \cdot X_{i,r}^{\mathrm{alloc}},
$$

where $X_{i,r}^{\mathrm{alloc}}$ is unit $i$'s retirement slice from
the within-unit allocation.

**Second**, define the receiving set of tax units as those with
positive taxable retirement income on their baseline return:

$$
\mathcal R \;=\; \{ i : \mathrm{txbl\_pens\_dist}_i + \mathrm{txbl\_ira\_dist}_i > 0 \}.
$$

**Third**, distribute $F$ across $\mathcal R$ in proportion to SCF
retirement wealth $W_i^{\mathrm{ret}}$:

$$
F_i \;=\; \mathbf{1}_{i \in \mathcal R} \cdot
         \frac{F \cdot W_i^{\mathrm{ret}}}
              {\sum_{j \in \mathcal R} w_j \cdot W_j^{\mathrm{ret}}},
\qquad \sum_i w_i F_i \;=\; F.
$$

Conditioning the receiving set on taxable retirement income while
weighting by wealth forces the allocation of retirement income to
concentrate in older tax units — the ones actually drawing from
their accounts.

**Fourth**, $F_i$ is split at the tax-unit level between taxable
pension distributions and taxable IRA distributions. We pull from
2022 IRS statistics to construct fixed ratios for this allocation:
67.6% to pension distributions and 32.4% to IRA distributions. The
two PUF columns (`txbl_pens_dist`, `txbl_ira_dist`) are updated
accordingly; `gross_pens_dist` is incremented by the same amount as
the taxable component, since under the constant-realization
assumption no new non-taxable rollover flow is generated.

### §B.1. A diagnostic: average tax rate on baseline retirement income

Independently of the AI counterfactual, readers often want a sense
of the level of taxation on retirement income today. We compute this
by running a stacked zero-out counterfactual: a separate
Tax-Simulator scenario that zeros each unit's `txbl_ira_dist`,
`gross_pens_dist`, and `txbl_pens_dist`, then comparing tax
liability with and without retirement income. The decile-level
result on the 2030 baseline, non-dependent filers ($n = 201{,}166$):

### Table B-1. Baseline retirement ATR by decile, 2030

| decile | $Y_R$ ($B) | $\Delta$ IIT ($B) | implied ATR |
|------:|-----------:|------------------:|------------:|
| 1     |       55.8 |               5.0 |        9.0% |
| 2     |       25.6 |               0.9 |        3.4% |
| 3     |       50.6 |               2.4 |        4.8% |
| 4     |       79.9 |               6.3 |        7.8% |
| 5     |      134.6 |              13.4 |        9.9% |
| 6     |      151.1 |              15.7 |       10.4% |
| 7     |      256.5 |              31.2 |       12.2% |
| 8     |      499.1 |              67.8 |       13.6% |
| 9     |      632.5 |              90.6 |       14.3% |
| 10    |     1296.9 |             134.3 |       10.4% |

Population total ATR is 11.6%. The decile-10 dip relative to decile 9
is structural rather than a measurement artifact: at the very top,
retirement is a smaller share of total income and non-retirement
income already sits in the top bracket, so zeroing retirement
income removes ordinary-rate mass with limited bracket interaction.
Decile-9 units more often fall out of the top bracket when their
retirement income is removed, exposing more dollars to the
difference.

## §C. Realization timing (V1 mechanical)

As noted at the start of the main methodology document, the
definition of $X$ implies that we are growing realized (and generally
taxable) income that appears on tax returns. This embeds a specific
assumption about realization: all gains generated by the shock are
recognized immediately at accrual. We adopt this as the model's
default — it holds as long as $X$ already captures the appropriate
rate of realizations, which is the case by construction when $Y_0^K$ is
the on-1040 base. All gains realized in-year:

$$
X^{\mathrm{LTCG}}_{\mathrm{realized}} \;=\; X^{\mathrm{LTCG}}_{\mathrm{gross}}.
$$

Treating AI capital gains as recognized immediately at accrual is
the parallel argument to the constant-realization choice for
retirement: $Y_0^K$ is sized off the on-1040 realized base, so
re-applying a realization discount inside the model would
double-count. Loosening the assumption — defining $X$ at the
wealth level so the shock acts on unrealized accruals, or
parameterizing the realization rate as a function of unit
characteristics — is discussed in the "Parameterizing the
realization rate" subsection of Future work in the main methodology
document.
