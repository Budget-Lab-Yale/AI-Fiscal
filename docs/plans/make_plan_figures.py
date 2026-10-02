"""Flow figures for the AI-Fiscal v2.0 plan document.

Figure 1: the capital cascade, CBO baseline -> tax file.
Figure 2: the labor leg.
Figure 3: the proposed v2.0 transmission, AI shock -> tax outputs
          (post-review; tracks docs/v2_methodology_proposal.md and the
          D-numbers in docs/v2_decisions.md).

Figures 1-2 track docs/v2_flow_network.md as of 2026-09-19 and inherit
its gaps; regenerate if the node registry changes. Output:
fig1_capital_cascade.png, fig2_labor_leg.png, fig3_v2_transmission.png
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

INK = "#1A1A1A"
BOX = "#F2F2F2"
EDGE = "#8C8C8C"
NEW = "#DCE9F2"
NEW_EDGE = "#3E6C8E"
RULE = "#B0B0B0"

FONT = {"family": "DejaVu Sans", "size": 8.2, "color": INK}


def box(ax, x, y, w, h, text, new=False, small=False, fc=None, dashed=False):
    fc = fc or (NEW if new else BOX)
    ec = NEW_EDGE if new else EDGE
    ax.add_patch(FancyBboxPatch((x, y), w, h,
                                boxstyle="round,pad=0.012,rounding_size=0.02",
                                linewidth=0.9, facecolor=fc, edgecolor=ec,
                                linestyle="--" if dashed else "-"))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center",
            fontsize=7.2 if small else FONT["size"], color=INK,
            family=FONT["family"], linespacing=1.35)


def arrow(ax, x1, y1, x2, y2, style="-|>", dashed=False, rad=0.0):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style,
                                 mutation_scale=9, linewidth=0.9,
                                 color=EDGE,
                                 linestyle="--" if dashed else "-",
                                 connectionstyle="arc3,rad=%s" % rad,
                                 shrinkA=1, shrinkB=1))


def label(ax, x, y, text, size=7.0, style="italic", ha="left", color="#5A5A5A",
          mask=False):
    bbox = dict(facecolor="white", edgecolor="none", pad=1.5) if mask else None
    ax.text(x, y, text, fontsize=size, style=style, ha=ha, va="center",
            color=color, family=FONT["family"], bbox=bbox)


# ---------------------------------------------------------------- figure 1
fig, ax = plt.subplots(figsize=(6.5, 8.0))
ax.set_xlim(0, 10)
ax.set_ylim(0, 13.2)
ax.axis("off")

box(ax, 2.6, 12.3, 4.8, 0.72,
    "CBO baseline\nGDP path, factor shares, revenue by source")
arrow(ax, 5.0, 12.3, 5.0, 11.95)

box(ax, 2.6, 11.2, 4.8, 0.72,
    "Macro sizing (Karger-calibrated)\n$g_y$, $g_K$, $g_L$")
arrow(ax, 5.0, 11.2, 5.0, 10.85)

box(ax, 2.35, 10.1, 5.3, 0.72,
    "Upstream increment   $\\Delta\\Pi = g_K \\cdot K_0^{NIPA}$", new=True)
label(ax, 7.85, 10.46, "national\naccounts", ha="left")
arrow(ax, 5.0, 10.1, 5.0, 9.72)

box(ax, 2.35, 9.0, 5.3, 0.68, "Entity split of $\\Delta\\Pi$", new=True)

# five channels
chans = [
    (0.15, "C-corp\n49.7%", True),
    (2.12, "S-corp\n12.4%", False),
    (4.09, "Prop. and\npartnership\n16.8%", False),
    (6.06, "Rental\n17.7%", False),
    (8.03, "Interest\n3.3%", False),
]
for x, t, hi in chans:
    box(ax, x, 7.85, 1.82, 0.78, t, small=True)
    arrow(ax, 5.0, 9.0, x + 0.91, 8.63, rad=0.0)

# C-corp leg
arrow(ax, 1.06, 7.85, 1.06, 7.5)
box(ax, 0.15, 6.78, 1.82, 0.72, "Entity CIT\n$\\tau^{*}\\Delta\\Pi_C$", new=True, small=True)
arrow(ax, 1.06, 6.78, 1.06, 6.43)
box(ax, 0.15, 5.7, 1.82, 0.72, "After-tax\nprofit", small=True)
arrow(ax, 1.06, 5.7, 1.06, 5.35)
box(ax, 0.15, 4.62, 1.82, 0.72, "Payout $p$ /\nretention $1-p$", new=True, small=True)
arrow(ax, 0.8, 4.62, 0.68, 4.27)
arrow(ax, 1.45, 4.62, 2.0, 4.27)
box(ax, 0.15, 3.5, 1.05, 0.76, "dividends", small=True)
box(ax, 1.35, 3.5, 1.4, 0.76, "accrual →\nrealization", new=True, small=True)

# other channels flow straight down
for x, _, _ in chans[1:]:
    arrow(ax, x + 0.91, 7.85, x + 0.91, 4.3)
label(ax, 5.0, 6.0, "no entity tax; realized as they arise", size=6.8,
      ha="center", mask=True)

# reconciliation rule
ax.plot([0.0, 10.0], [3.22, 3.22], color=RULE, linewidth=0.8, linestyle=(0, (4, 3)))
label(ax, 9.98, 3.38, "national accounts", size=6.8, color="#7A7A7A", ha="right")
label(ax, 9.98, 3.06, "microdata", size=6.8, color="#7A7A7A", ha="right")

box(ax, 2.35, 2.25, 5.3, 0.72,
    "Reconciliation to the tax file\nbenchmark or inherit, per channel", new=True)
for x, _, _ in chans:
    arrow(ax, x + 0.91 if x > 0.2 else 1.35, 4.3 if x > 0.2 else 3.5, 5.0, 2.97, rad=0.06)

arrow(ax, 5.0, 2.25, 5.0, 1.9)
box(ax, 2.35, 1.18, 5.3, 0.72,
    "Household allocation\nacross units by holdings, then within unit by class")
arrow(ax, 5.0, 1.18, 5.0, 0.83)
box(ax, 2.35, 0.1, 5.3, 0.72,
    "Counterfactual tax lines → Tax-Simulator → $\\Delta R$")

fig.tight_layout(pad=0.3)
fig.savefig("fig1_capital_cascade.png", dpi=220, facecolor="white")
plt.close(fig)

# ---------------------------------------------------------------- figure 2
fig, ax = plt.subplots(figsize=(6.5, 4.6))
ax.set_xlim(0, 10)
ax.set_ylim(-0.4, 7.4)
ax.axis("off")

box(ax, 2.6, 6.55, 4.8, 0.7,
    "CBO baseline labor income   $L_0$")
arrow(ax, 5.0, 6.55, 5.0, 6.2)

box(ax, 2.35, 5.45, 5.3, 0.7,
    "Aggregate target   $Y_1^{L} = Y_0^{L}(1 + g_L)$", new=True)
arrow(ax, 5.0, 5.45, 5.0, 5.1)

box(ax, 1.2, 4.3, 3.2, 0.72, "Metric\nproportional · inequality ·\nAI exposure", small=True)
box(ax, 5.6, 4.3, 3.2, 0.72, "Margin\nintensive · extensive ·\nmixed", new=True, small=True)
arrow(ax, 4.4, 4.66, 5.6, 4.66, style="<|-|>")
label(ax, 5.0, 3.98, "crossed", size=6.8, ha="center")

arrow(ax, 2.8, 4.3, 2.4, 3.6)
arrow(ax, 7.2, 4.3, 7.6, 3.6)

box(ax, 0.5, 2.85, 3.8, 0.72,
    "Intensive\nper-unit labor income scaled", small=True)
box(ax, 5.7, 2.85, 3.8, 0.72,
    "Extensive\nweights split; displaced units\nlose labor lines and FICA", new=True, small=True)

arrow(ax, 7.6, 2.85, 7.6, 2.5)
box(ax, 6.1, 1.85, 3.0, 0.6, "UI, outside the\nfactor identity", small=True)

arrow(ax, 2.4, 2.85, 5.0, 1.62, rad=-0.08)
arrow(ax, 7.6, 1.85, 5.6, 1.62, rad=0.08)

box(ax, 2.35, 0.9, 5.3, 0.7,
    "Factor-channel sidecar; $\\sum_i w_i\\, y_{l,i}^{1} = Y_1^{L}$")
arrow(ax, 5.0, 0.9, 5.0, 0.55)
box(ax, 2.35, -0.2, 5.3, 0.7,
    "Wage lines → Tax-Simulator → $\\Delta R$ (income and payroll)")

fig.tight_layout(pad=0.3)
fig.savefig("fig2_labor_leg.png", dpi=220, facecolor="white")
plt.close(fig)

# ---------------------------------------------------------------- figure 3
OUT = "#FFF4DE"   # output boxes

fig, ax = plt.subplots(figsize=(8.5, 11.0))
ax.set_xlim(0, 12)
ax.set_ylim(-0.6, 17.2)
ax.axis("off")

# inputs
box(ax, 0.2, 16.0, 3.7, 1.0,
    "CBO baseline (dated vintage)\nGDP, factor income, revenue,\nprice paths, 2025-2036  [D6]")
box(ax, 4.15, 16.0, 3.7, 1.0,
    "AI scenario path\nGDP level (Karger growth) +\nnonfarm-business labor share  [D1]")
box(ax, 8.1, 16.0, 3.7, 1.0,
    "Macro adapter (optional)\nTFP -> GDP, hours, factor\nincome, own closure",
    dashed=True)
arrow(ax, 8.1, 16.5, 7.85, 16.5, dashed=True)
arrow(ax, 2.05, 16.0, 4.5, 15.55)
arrow(ax, 6.0, 16.0, 6.0, 15.55)

# 1 production accounts
box(ax, 1.5, 14.35, 9.0, 1.2,
    "1  Production accounts   $Y = L + K + Q$   (annual levels and changes)\n"
    "sector bridge [D1] · one mixed-income split $\\varphi$ [D3] · "
    "shock coverage [D2]\n$Q$ = named non-factor items, each with a scenario rule")

# labor and capital-by-entity
box(ax, 0.2, 12.2, 3.3, 1.1,
    "2  Labor   $\\Delta L$\ncompensation -> wages bridge\nS0 / S2 / S3 across workers")
box(ax, 3.9, 12.2, 2.5, 1.1, "C-corporations\n$\\Delta\\Pi_C$")
box(ax, 6.6, 12.2, 2.5, 1.1, "Pass-throughs\n$\\Delta\\Pi_S$, $\\Delta\\Pi_P$\n(K-1, Sch. C)")
box(ax, 9.3, 12.2, 2.5, 1.1,
    "Rental, interest\nmarket rent shocked;\nowner-occ. + interest\nfixed (reference)",
    small=True)
arrow(ax, 3.0, 14.35, 1.85, 13.3)
for x in (5.15, 7.85, 10.55):
    arrow(ax, 6.0, 14.35, x, 13.3)
label(ax, 7.45, 13.75, "capital by legal form (κ)", size=6.8, ha="left", mask=True)

# 3 entity tax and payout
arrow(ax, 5.15, 12.2, 5.15, 11.75)
box(ax, 3.9, 10.65, 2.5, 1.1,
    "3  Entity tax\n$\\Delta R_{CIT}$ on a compatible\nprofit base [D4]")
arrow(ax, 5.15, 10.65, 5.15, 10.2)
box(ax, 3.9, 9.1, 2.5, 1.1, "Payout $p$ [D7]\ndividends | retained\nproduction income")

# 4 ownership
box(ax, 3.9, 7.3, 7.9, 1.15,
    "4  Ownership and wrappers [D9]   entity × owner × wrapper\n"
    "US taxable · traditional DC/IRA · Roth · DB · tax-exempt · foreign",
    new=True)
arrow(ax, 5.15, 9.1, 5.15, 8.45)
arrow(ax, 7.85, 12.2, 7.85, 8.45)
arrow(ax, 10.55, 12.2, 10.55, 8.45)

# 5 household income and asset state
box(ax, 3.9, 5.2, 2.5, 1.35,
    "5a  Cash income\ndividends, K-1 income,\nrent, interest")
box(ax, 6.6, 5.2, 2.5, 1.35,
    "5b  Asset ledger [D10]\nvaluation -> gains stock $U$\n-> realized $G$;\nbasis at death $E$",
    new=True, small=True)
box(ax, 9.3, 5.2, 2.5, 1.35,
    "5c  Retirement [D11]\nDC/IRA balances ->\nage-based withdrawals;\nDB formulas fixed",
    new=True, small=True)
for x in (5.15, 7.85, 10.55):
    arrow(ax, x, 7.3, x, 6.55)

# 6 reconciliation + untaxed destinations
box(ax, 3.9, 3.45, 5.2, 1.1,
    "6  Reconciliation to the tax file [D5]\n"
    "concept -> ownership -> timing -> residual only")
for x in (5.15, 7.85):
    arrow(ax, x, 5.2, x if x < 7 else 7.2, 4.55)
arrow(ax, 10.55, 5.2, 8.6, 4.55)
box(ax, 9.3, 3.45, 2.5, 1.1,
    "Untaxed / deferred\nforeign · exempt · Roth ·\ndeferred balances",
    fc=OUT, small=True)
arrow(ax, 11.6, 7.3, 11.6, 4.55, dashed=True)

ax.plot([0.0, 12.0], [3.1, 3.1], color=RULE, linewidth=0.8, linestyle=(0, (4, 3)))
label(ax, 11.95, 3.24, "aggregate ledgers", size=6.6, color="#7A7A7A", ha="right")
label(ax, 11.95, 2.96, "microdata", size=6.6, color="#7A7A7A", ha="right")

# 7 microsimulation
box(ax, 0.9, 1.75, 8.2, 1.0,
    "7  Household allocation -> counterfactual tax units -> Tax-Simulator\n"
    "individual income tax · payroll (per worker) · refundable credits")
arrow(ax, 1.85, 12.2, 1.85, 2.75)
arrow(ax, 6.5, 3.45, 6.5, 2.75)

# CIT bypasses the microsim: counted once, at the entity
ax.plot([3.9, 0.45, 0.45], [11.2, 11.2, 1.3], color=NEW_EDGE, linewidth=0.9,
        linestyle="--")
arrow(ax, 0.45, 1.3, 0.75, 1.15)
label(ax, 0.55, 9.6, "CIT counted once", size=6.6, color=NEW_EDGE, mask=True)

# outputs
box(ax, 0.2, -0.05, 2.75, 1.15,
    "Federal receipts\nCIT + IIT + payroll;\ncredits as outlays [D13]", fc=OUT, small=True)
box(ax, 3.15, -0.05, 2.75, 1.15,
    "Distribution [D12]\ncash panel · economic-\nincome panel · CIT overlay", fc=OUT, small=True)
box(ax, 6.1, -0.05, 2.75, 1.15,
    "Flow reconciliation\nevery dollar of $\\Delta Y$ by\ndestination; v1.0 bridge", fc=OUT, small=True)
box(ax, 9.05, -0.05, 2.75, 1.15,
    "Fiscal feedback (optional)\nreceipts -> BLSMM\ndebt/GDP", fc=OUT, small=True, dashed=True)
for x in (1.6, 4.5, 7.5):
    arrow(ax, x if x > 2 else 2.2, 1.75, x, 1.1)
arrow(ax, 10.55, 3.45, 7.9, 1.1, dashed=True)
ax.plot([1.6, 1.6, 10.4], [-0.05, -0.45, -0.45], color=EDGE, linewidth=0.9,
        linestyle="--")
arrow(ax, 10.4, -0.45, 10.4, -0.05, dashed=True)

fig.tight_layout(pad=0.3)
fig.savefig("fig3_v2_transmission.png", dpi=220, facecolor="white")
plt.close(fig)
print("wrote fig1_capital_cascade.png, fig2_labor_leg.png, "
      "fig3_v2_transmission.png")
