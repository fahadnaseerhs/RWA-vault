"""Block diagrams for the QORA technical proposal (IEEE style: white, greyscale, one accent)."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT = os.path.join(os.path.dirname(__file__), "fig")
os.makedirs(OUT, exist_ok=True)
INK, GREY, LIGHT, ACC, ACCL = "#000000", "#000000", "#ffffff", "#000000", "#ffffff"
plt.rcParams.update({"font.family": "Times New Roman", "font.size": 9})


def canvas(w, h):
    fig = plt.figure(figsize=(w, h), dpi=300)
    ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, w); ax.set_ylim(0, h); ax.axis("off")
    return fig, ax


def box(ax, x, y, w, h, title, lines=(), fill=LIGHT, edge=INK, bold=True, fs=8.5, lw=0.9, strong=False):
    lw = 1.9 if strong else lw
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.0,rounding_size=0.06", fc=fill, ec=edge, lw=lw))
    n = len(lines)
    ty = y + h / 2 + (0.09 * n)
    ax.text(x + w / 2, ty, title, ha="center", va="center", fontsize=fs, fontweight="bold" if bold else "normal", color=INK)
    for i, ln in enumerate(lines):
        ax.text(x + w / 2, ty - 0.17 * (i + 1), ln, ha="center", va="center", fontsize=fs - 1.6, color=GREY)


def arrow(ax, x1, y1, x2, y2, dashed=False, color=INK, label=None, lpos=0.5, loff=(0.05, 0.05)):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=7, lw=0.8, color=color,
                                 linestyle=(0, (3, 2)) if dashed else "-"))
    if label:
        ax.text(x1 + (x2 - x1) * lpos + loff[0], y1 + (y2 - y1) * lpos + loff[1], label, fontsize=6.6, color=GREY)


def save(fig, name):
    fig.savefig(os.path.join(OUT, name), dpi=300, facecolor="white"); plt.close(fig)


# ---------------- Fig. 1 layered architecture (wide)
fig, ax = canvas(7.0, 4.6)
layers = [
    (3.75, "Client layer (M10)", [("Investor PWA", ["React 18 · viem · WASM Falcon-512 signer", "device key in IndexedDB"]),
                                  ("Operations & custodian console", ["ML-DSA-65 attestations", "buffer, oracle, anchor health"])]),
    (2.75, "Service layer · NestJS on Node 22", [("pq-verifier", ["M2 · 7 checks"]), ("oracle", ["M5 · 5 feeds"]), ("settlement-rail", ["M8 · IFiatRail"]),
                                                 ("risk-engine", ["M6 · HF sweep"]), ("anchor-batcher", ["M9 · 60 s epochs"])]),
    (1.75, "Package layer", [("pq-core", ["Rust core · PQClean C · RustCrypto slh-dsa", "napi-rs addon  |  wasm32 (wasm-pack)"]),
                             ("envelope-codec", ["M2 canonical bytes", "TS ≡ Rust, shared vectors"]), ("pqctl", ["offline SLH-DSA", "root ceremony"])]),
    (0.75, "Contract layer · Solidity 0.8.26 · Foundry", [("keys", ["PQKeyRegistry"]), ("registry & tokens", ["AssetRegistry · ERC-3643", "ONCHAINID · compliance"]),
                                                         ("vault", ["ERC-4626"]), ("oracle · lending", ["PriceOracle · LendingPool", "ReserveBuffer · Liquidator"]),
                                                         ("anchoring", ["PQAnchor", "ZKNOX_falcon (dispute)"])]),
]
for y, name, items in layers:
    ax.add_patch(FancyBboxPatch((0.08, y - 0.08), 6.84, 0.86, boxstyle="round,pad=0,rounding_size=0.05", fc="white", ec=GREY, lw=0.6, ls=(0, (2, 2))))
    ax.text(0.18, y + 0.66, name, fontsize=7.6, fontweight="bold", color=ACC)
    n = len(items); gap = 0.1; w = (6.64 - gap * (n - 1)) / n
    for i, (t, ls) in enumerate(items):
        box(ax, 0.18 + i * (w + gap), y, w, 0.6, t, ls, fs=7.8)
box(ax, 0.18, 0.08, 6.64, 0.4, "Arbitrum Sepolia (Ethereum-secured optimistic rollup)  ·  local: Anvil · Redis 7 Streams · PostgreSQL 16", fill=ACCL, edge=ACC, strong=True, fs=7.8)
for y in (3.75, 2.75, 1.75):
    arrow(ax, 3.5, y - 0.08, 3.5, y - 0.22)
arrow(ax, 3.5, 0.67, 3.5, 0.48)
save(fig, "fig1_architecture.png")

# ---------------- Fig. 2 M1 build pipeline
fig, ax = canvas(3.45, 3.0)
box(ax, 0.1, 2.3, 1.55, 0.55, "PQClean (pinned)", ["falcon-padded-512, ml-dsa-44/65", "ml-kem-768/1024 · clean C"], fs=7.6)
box(ax, 1.8, 2.3, 1.55, 0.55, "RustCrypto slh-dsa", ["SLH-DSA-SHA2-128s", "pure Rust"], fs=7.6)
box(ax, 0.55, 1.45, 2.35, 0.55, "Rust core (rust 1.81)", ["build.rs + cc · byte contract (ADR 0006)", "getrandom · fail-closed RNG"], fill=ACCL, edge=ACC, strong=True, fs=7.6)
box(ax, 0.1, 0.6, 1.0, 0.55, "napi-rs addon", ["Node-API v8", "AsyncTask"], fs=7.4)
box(ax, 1.22, 0.6, 1.0, 0.55, "wasm32 (wasm-pack)", ["freestanding C", "Web Crypto RNG"], fs=7.2)
box(ax, 2.34, 0.6, 1.0, 0.55, "pqctl CLI", ["offline root", "sign/verify files"], fs=7.4)
box(ax, 0.1, 0.03, 3.24, 0.4, "TypeScript PqCoreApi · PqError classes · algorithm metadata", fs=7.2)
arrow(ax, 0.9, 2.3, 1.3, 2.0); arrow(ax, 2.55, 2.3, 2.15, 2.0)
for x in (0.6, 1.72, 2.84):
    arrow(ax, 1.72, 1.45, x, 1.15)
arrow(ax, 0.6, 0.6, 0.9, 0.43); arrow(ax, 1.72, 0.6, 1.72, 0.43)
save(fig, "fig2_pqcore.png")

# ---------------- Fig. 3 envelope -> anchor pipeline (wide)
fig, ax = canvas(7.0, 2.05)
steps = [("1 Sign", ["Falcon-512 in WASM", "device key"]), ("2 Verify", ["pq-verifier", "7 named checks"]), ("3 Execute", ["contract call", "on-chain invariants"]),
         ("4 Leaf", ["Keccak-256(envelope", "sig field zeroed)"]), ("5 Anchor", ["sorted-pair Merkle", "{root, n, epoch}"]), ("6 Prove", ["{leaf, siblings, epoch}", "verify offline"])]
w, g = 1.02, 0.14
for i, (t, ls) in enumerate(steps):
    x = 0.1 + i * (w + g)
    on = i in (2, 4)
    box(ax, x, 1.15, w, 0.7, t, ls, fill=LIGHT, edge=INK, strong=on, fs=8)
    if i < 5:
        arrow(ax, x + w, 1.5, x + w + g, 1.5)
xa = 0.1 + 4 * (w + g)
box(ax, xa - 0.55, 0.12, 2.1, 0.62, "Dispute (only if challenged)", ["leaf + proof (~22k gas) → ZKNOX_falcon", "NIST-compliant verifier, ~3.9M gas"], fill="white", edge=INK, fs=7.8, strong=True)
arrow(ax, xa + w / 2, 1.15, xa + w / 2, 0.74, dashed=True, color=ACC)
ax.text(0.1, 0.42, "Bold-bordered steps touch the chain.\nAnchor ≈ 43k gas per 60 s epoch,\nindependent of the event count n.", fontsize=7, color=GREY, va="center")
save(fig, "fig3_pipeline.png")

# ---------------- Fig. 4 asset state machine (M3)
fig, ax = canvas(3.45, 2.6)
box(ax, 0.1, 2.0, 1.45, 0.42, "UNREGISTERED", fs=7.6)
box(ax, 1.9, 2.0, 1.45, 0.42, "ATTESTATION RECEIVED", fs=7)
box(ax, 0.55, 1.05, 2.35, 0.62, "Four checks", ["ML-DSA-65 sig · sequence s > s_prev", "reserve ≥ supply · price age ≤ max"], fs=7.6)
box(ax, 0.1, 0.12, 1.45, 0.48, "LIVE", ["only state that mints"], fill=ACCL, edge=ACC, strong=True, fs=7.6)
box(ax, 1.9, 0.12, 1.45, 0.48, "FROZEN", ["mint/transfer stop", "redeem stays open"], fs=7.6)
arrow(ax, 1.55, 2.21, 1.9, 2.21); ax.text(1.72, 2.5, "signed report", ha="center", fontsize=6.6, color=GREY)
arrow(ax, 2.62, 2.0, 2.0, 1.67); arrow(ax, 1.2, 1.05, 0.85, 0.6, label="all pass", loff=(-0.42, 0.0))
arrow(ax, 2.3, 1.05, 2.62, 0.6); ax.text(2.62, 0.82, "any fail →\nREJECTED", fontsize=6.4, color=GREY)
arrow(ax, 1.55, 0.36, 1.9, 0.36); ax.text(1.72, 0.68, "overdue /\nkey revoked", ha="center", fontsize=6.2, color=GREY)
save(fig, "fig4_asset_fsm.png")

# ---------------- Fig. 5 oracle pipeline (M5)
fig, ax = canvas(3.45, 3.25)
st = [("5 sources", "parallel poll, 3 s timeout"), ("drop stale / dead", "removes a dead feed's influence"), ("quorum k ≥ 3", "else no round"),
      ("median", "one bad feed cannot move it"), ("|P − TWAP₃₀| / TWAP₃₀ ≤ 10%", "stops a correlated majority"), ("round ID ↑, t ↑", "append-only history"),
      ("sign ML-DSA-44 → commit", "PriceOracle.sol re-checks")]
for i, (t, d) in enumerate(st):
    y = 2.85 - i * 0.43
    box(ax, 0.1, y, 3.25, 0.33, "", [], fill=LIGHT, edge=INK, strong=(i == 6), fs=7.6)
    ax.text(0.2, y + 0.165, f"{i + 1}. {t}", ha="left", va="center", fontsize=7.4, fontweight="bold")
    ax.text(3.25, y + 0.165, d, ha="right", va="center", fontsize=6.4, color=GREY)
    if i < 6:
        arrow(ax, 0.5, y, 0.5, y - 0.1)
save(fig, "fig5_oracle.png")

# ---------------- Fig. 6 health-factor bands (M6/M7)
fig, ax = canvas(3.45, 2.5)
bands = [(1.15, 1.6, "HF ≥ 1.15", "healthy · borrow allowed if post-HF ≥ 1.15", "#ffffff"),
         (1.0, 1.15, "1.00–1.15", "new borrowing frozen · 6 h top-up window", LIGHT),
         (0.95, 1.0, "0.95–1.00", "reserve buffer claim D(1−HF) · 6 h grace", ACCL),
         (0.9, 0.95, "0.90–0.95", "liquidation: φ = 50%, β 5% → 3% / 20 blocks", "#ffffff"),
         (0.75, 0.9, "< 0.90", "full closure · residual socialised", "#ffffff")]
for i, (lo, hi, t, d, c) in enumerate(bands):
    y = 2.05 - i * 0.44
    box(ax, 0.1, y, 3.25, 0.36, "", [], fill=c, edge=GREY, lw=0.6)
    ax.text(0.2, y + 0.18, t, fontsize=7.8, fontweight="bold", va="center")
    ax.text(0.95, y + 0.18, d, fontsize=6.8, va="center", color=INK)
save(fig, "fig6_hf_bands.png")

# ---------------- Fig. 7 module dependencies and leaves (wide)
fig, ax = canvas(7.0, 2.35)
cols = [("Leaf 1 · Foundation (wk 1–6)", ["M0 Devnet", "M1 PQ Core", "M2 PQ-PKI & Envelope", "M3 Registry & Compliance", "M4 Vault"]),
        ("Leaf 2 · Investment (wk 7–11)", ["M5 Oracle & PoR", "M8 Settlement Rail", "M9 Anchoring & Audit"]),
        ("Leaf 3 · Lending & Risk (wk 12–19)", ["M6 Risk Engine", "M7 Lending & Liquidation", "M10 Clients"]),
        ("Leaf 4 · Evaluation (wk 20–24)", ["M11 Evaluation Harness"])]
cw = 1.58; gx = 0.16
for i, (t, mods) in enumerate(cols):
    x = 0.1 + i * (cw + gx)
    ax.add_patch(FancyBboxPatch((x, 0.1), cw, 2.1, boxstyle="round,pad=0,rounding_size=0.05", fc="white", ec=GREY, lw=0.6))
    ax.text(x + cw / 2, 2.05, t, ha="center", fontsize=6.9, fontweight="bold", color=ACC)
    for j, m in enumerate(mods):
        box(ax, x + 0.1, 1.66 - j * 0.33, cw - 0.2, 0.26, m, [], fs=7.0, bold=False)
    if i < 3:
        arrow(ax, x + cw, 1.15, x + cw + gx, 1.15)
for i, g in enumerate(["MS1: gold lot LIVE", "MS2 (FYP-I): PKR 5,000 + offline proof", "MS3: borrow → drop → buffer/liquidation", "MS4: RQ1–RQ4 measured"]):
    ax.text(0.1 + i * (cw + gx) + cw / 2, 0.18, g, ha="center", fontsize=6.0, color=GREY)
save(fig, "fig7_modules.png")

# ---------------- Fig. 8 Gantt (wide)
fig, ax2 = plt.subplots(figsize=(7.0, 2.6), dpi=300)
rows = [("M0 Devnet", 1, 2), ("M1 PQ Core", 1, 4), ("M2 PQ-PKI & Envelope", 3, 6), ("M3 Registry & Compliance", 5, 6), ("M4 Vault", 5, 6),
        ("M5 Oracle", 7, 10), ("M8 Settlement", 7, 8), ("M9 Anchoring", 7, 11), ("M6 Risk Engine", 12, 15), ("M7 Lending", 14, 19),
        ("M10 Clients", 12, 19), ("M11 Evaluation", 20, 24)]
for i, (n_, a, b) in enumerate(rows):
    ax2.barh(i, b - a + 1, left=a - 0.5, height=0.55, color="white", edgecolor="black", lw=0.8, hatch="////")
ax2.set_yticks(range(len(rows))); ax2.set_yticklabels([r[0] for r in rows], fontsize=7)
ax2.invert_yaxis(); ax2.set_xlim(0.5, 24.8)
ax2.set_xticks(range(2, 25, 2)); ax2.set_xticklabels([str(k) for k in range(2, 25, 2)], fontsize=6.6)
ax2.set_xlabel("Week", fontsize=7)
for w_, lab in [(6, "MS1"), (11, "MS2"), (19, "MS3"), (24, "MS4")]:
    ax2.axvline(w_ + 0.5, color=INK, lw=0.6, ls=(0, (3, 2))); ax2.text(w_ + 0.55, -0.75, lab, fontsize=6.6)
for s in ("top", "right"):
    ax2.spines[s].set_visible(False)
ax2.tick_params(length=2)
fig.tight_layout(); fig.savefig(os.path.join(OUT, "fig8_gantt.png"), dpi=300, facecolor="white"); plt.close(fig)
print("figures ok:", sorted(os.listdir(OUT)))
