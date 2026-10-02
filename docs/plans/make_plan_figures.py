"""Flow figures for the AI-Fiscal v2.0 plan document.

Figure 1: the capital cascade, CBO baseline -> tax file.
Figure 2: the labor leg.

Node text tracks docs/v2_flow_network.md; regenerate both if the node
registry changes. Output: fig1_capital_cascade.png, fig2_labor_leg.png
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


def box(ax, x, y, w, h, text, new=False, small=False):
    fc = NEW if new else BOX
    ec = NEW_EDGE if new else EDGE
    ax.add_patch(FancyBboxPatch((x, y), w, h,
                                boxstyle="round,pad=0.012,rounding_size=0.02",
                                linewidth=0.9, facecolor=fc, edgecolor=ec))
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
print("wrote fig1_capital_cascade.png and fig2_labor_leg.png")
