"""QORA - post-quantum explainer (~48 s, 1920x1080, 30 fps, burned-in subtitles).

Usage:
  python render.py out.mp4              # full render
  python render.py --preview 3 15 30    # write PNG stills at those seconds
Needs: Pillow, imageio-ffmpeg. Facts come from the M1/M2 vault notes and docs/video/QORA_Video_Brief.md.
"""
import math
import os
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS, DUR = 1920, 1080, 30, 48.0
SLOW = float(os.environ.get("SLOW", "1.5"))  # 1.0 = original 48 s pace; 1.5 -> 72 s
FD = "C:/Windows/Fonts/"
_fc = {}


def F(size, kind="r"):
    k = (size, kind)
    if k not in _fc:
        name = {"r": "segoeui.ttf", "b": "segoeuib.ttf", "sb": "seguisb.ttf",
                "l": "segoeuil.ttf", "m": "consola.ttf", "mb": "consolab.ttf"}[kind]
        _fc[k] = ImageFont.truetype(FD + name, size)
    return _fc[k]


BG = (248, 246, 241)
GOLD = (184, 140, 24)
GOLDL = (150, 108, 8)
WHITE = (26, 26, 32)
SUBTXT = (250, 250, 250)
GREY = (98, 98, 110)
DIM = (205, 202, 194)
RED = (204, 52, 40)
GREEN = (28, 150, 78)
BLUE = (40, 92, 214)
PANEL = (255, 255, 255)


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def P(t, a, b):
    return ease((t - a) / (b - a))


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c, a, base=BG):
    a = clamp(a)
    return tuple(int(base[i] + (c[i] - base[i]) * a) for i in range(3))


# ---------------------------------------------------------------- primitives
def text(d, xy, s, font, col, a=1.0, anchor="mm"):
    if a > 0.01:
        d.text(xy, s, font=font, fill=mix(col, a), anchor=anchor)


def box(d, cx, cy, w, h, a, outline=GOLD, fill=PANEL, r=14, wd=2):
    if a <= 0.01:
        return
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], r,
                        fill=mix(fill, a), outline=mix(outline, a), width=wd)


def line(d, p1, p2, col, a, w=3, prog=1.0):
    if a <= 0.01 or prog <= 0:
        return
    x2 = lerp(p1[0], p2[0], prog)
    y2 = lerp(p1[1], p2[1], prog)
    d.line([p1, (x2, y2)], fill=mix(col, a), width=w)


def dashed(d, p1, p2, col, a, w=2, dash=14, gap=10, offset=0.0, prog=1.0):
    if a <= 0.01:
        return
    L = math.dist(p1, p2) * prog
    ux, uy = (p2[0] - p1[0]) / max(1, math.dist(p1, p2)), (p2[1] - p1[1]) / max(1, math.dist(p1, p2))
    s = -(offset % (dash + gap))
    while s < L:
        a0, a1 = max(0, s), min(L, s + dash)
        if a1 > a0:
            d.line([(p1[0] + ux * a0, p1[1] + uy * a0), (p1[0] + ux * a1, p1[1] + uy * a1)],
                   fill=mix(col, a), width=w)
        s += dash + gap


def arrow(d, p1, p2, col, a, w=3, prog=1.0, head=14):
    if a <= 0.01 or prog <= 0:
        return
    x2, y2 = lerp(p1[0], p2[0], prog), lerp(p1[1], p2[1], prog)
    d.line([p1, (x2, y2)], fill=mix(col, a), width=w)
    ang = math.atan2(y2 - p1[1], x2 - p1[0])
    pts = [(x2, y2),
           (x2 - head * math.cos(ang - 0.45), y2 - head * math.sin(ang - 0.45)),
           (x2 - head * math.cos(ang + 0.45), y2 - head * math.sin(ang + 0.45))]
    d.polygon(pts, fill=mix(col, a))


def tick(d, cx, cy, s, col, a, w=4):
    if a > 0.01:
        d.line([(cx - s, cy), (cx - s * 0.3, cy + s * 0.7), (cx + s, cy - s * 0.8)],
               fill=mix(col, a), width=w, joint="curve")


def ring(d, cx, cy, r, col, a, w=2):
    if a > 0.01 and r > 0:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=mix(col, a), width=w)


def lock(d, cx, cy, s, col, a, opened=0.0, cracked=0.0):
    lift = opened * s * 0.35
    sw = max(6, int(s * 0.12))
    # shackle
    d.arc([cx - s * 0.38, cy - s * 0.78 - lift, cx + s * 0.38, cy - s * 0.02 - lift], 180, 360,
          fill=mix(col, a), width=sw)
    d.line([(cx - s * 0.38 + sw / 2, cy - s * 0.4 - lift), (cx - s * 0.38 + sw / 2, cy)], fill=mix(col, a), width=sw)
    d.line([(cx + s * 0.38 - sw / 2, cy - s * 0.4 - lift), (cx + s * 0.38 - sw / 2, cy - s * 0.4 * (1 - opened))],
           fill=mix(col, a), width=sw)
    # body
    d.rounded_rectangle([cx - s * 0.6, cy - s * 0.08, cx + s * 0.6, cy + s * 0.78], int(s * 0.1),
                        fill=mix(PANEL, a), outline=mix(col, a), width=sw)
    d.ellipse([cx - s * 0.08, cy + s * 0.2, cx + s * 0.08, cy + s * 0.36], fill=mix(col, a))
    d.rectangle([cx - s * 0.03, cy + s * 0.3, cx + s * 0.03, cy + s * 0.52], fill=mix(col, a))
    if cracked > 0:
        pts = [(cx - s * 0.55, cy + s * 0.05), (cx - s * 0.2, cy + s * 0.3), (cx - s * 0.32, cy + s * 0.45),
               (cx + s * 0.1, cy + s * 0.62), (cx + s * 0.0, cy + s * 0.7), (cx + s * 0.5, cy + s * 0.76)]
        n = 1 + int(cracked * (len(pts) - 1))
        d.line(pts[:n], fill=mix(RED, a), width=5)


def chip(d, cx, cy, s, col, a):
    box(d, cx, cy, s, s, a, outline=col, r=12, wd=3)
    box(d, cx, cy, s * 0.55, s * 0.55, a, outline=col, r=6, wd=2)
    for i in range(5):
        o = -s * 0.36 + i * s * 0.18
        for (x1, y1, x2, y2) in [(cx + o, cy - s / 2, cx + o, cy - s / 2 - 18), (cx + o, cy + s / 2, cx + o, cy + s / 2 + 18),
                                 (cx - s / 2, cy + o, cx - s / 2 - 18, cy + o), (cx + s / 2, cy + o, cx + s / 2 + 18, cy + o)]:
            d.line([(x1, y1), (x2, y2)], fill=mix(col, a), width=3)


def keyicon(d, cx, cy, s, col, a):
    ring(d, cx - s * 0.45, cy, s * 0.32, col, a, w=4)
    d.line([(cx - s * 0.13, cy), (cx + s * 0.6, cy)], fill=mix(col, a), width=4)
    d.line([(cx + s * 0.45, cy), (cx + s * 0.45, cy + s * 0.25)], fill=mix(col, a), width=4)
    d.line([(cx + s * 0.25, cy), (cx + s * 0.25, cy + s * 0.2)], fill=mix(col, a), width=4)


# ---------------------------------------------------------------- scenes
def s1_threat(d, t, a):
    la = a * P(t, 0.1, 0.7)
    broken = P(t, 3.9, 4.3)
    col = tuple(int(lerp(GOLD[i], RED[i], broken)) for i in range(3))
    lock(d, 720, 430, 190, col, la, opened=P(t, 4.1, 4.7), cracked=P(t, 3.9, 4.6))
    text(d, (720, 640), "ECDSA · secp256k1", F(40, "sb"), WHITE, la)
    text(d, (720, 688), "64-byte signature  ·  33-byte public key", F(24, "m"), GREY, la)
    text(d, (720, 730), "assumption: elliptic-curve discrete log is hard", F(24, "m"), GREY, la * (1 - broken))
    text(d, (720, 730), "ECDLP solved in polynomial time", F(26, "mb"), RED, la * broken)
    # quantum processor
    qa = a * P(t, 2.0, 2.6)
    if qa > 0:
        for k in range(3):
            ph = ((t - 2.4) * 0.8 + k / 3) % 1.0
            ring(d, 1300, 480, 110 + ph * 160, BLUE, qa * (1 - ph) * 0.6, w=2)
        chip(d, 1300, 480, 160, BLUE, qa)
        text(d, (1300, 480), "QPU", F(36, "b"), BLUE, qa)
        text(d, (1300, 640), "Shor's algorithm", F(40, "sb"), WHITE, qa)
        text(d, (1300, 688), "factoring & discrete log  ->  O((log N)^3)", F(24, "m"), GREY, qa)
    # attack beam
    ba = a * P(t, 3.2, 3.5) * (1 - P(t, 4.4, 4.9))
    if ba > 0:
        for w_, al in [(14, 0.15), (7, 0.35), (3, 1.0)]:
            dashed(d, (1200, 480), (840, 480), BLUE, ba * al, w=w_, dash=26, gap=12, offset=t * 220,
                   prog=P(t, 3.2, 3.8))


def s2_harvest(d, t, a):
    y = 560
    x0, x1 = 240, 1680
    prog = P(t, 0.2, 2.2)
    line(d, (x0, y), (x1, y), DIM, a, w=4)
    line(d, (x0, y), (x1, y), GOLD, a, w=4, prog=prog)
    marks = [(360, "2026", "Gold lot tokenised", "signed with ECDSA", GOLD),
             (1010, "2035", "NIST deprecates ECDSA", "", WHITE),
             (1560, "2056+", "Ownership must still", "be provable", WHITE)]
    for x, yr, l1, l2, c in marks:
        ma = a * P(prog, (x - x0) / (x1 - x0) - 0.05, (x - x0) / (x1 - x0) + 0.02)
        d.ellipse([x - 11, y - 11, x + 11, y + 11], fill=mix(c, ma))
        text(d, (x, y + 50), yr, F(38, "b"), c, ma)
        text(d, (x, y + 96), l1, F(26), GREY, ma)
        if l2:
            text(d, (x, y + 128), l2, F(26), GREY, ma)
    # Q-day window
    qa = a * P(t, 1.8, 2.4)
    if qa > 0:
        d.rectangle([1120, y - 6, 1400, y + 6], fill=mix(RED, qa * 0.8))
        text(d, (1260, y - 40), "Q-day window", F(26, "sb"), RED, qa)
        text(d, (1260, y + 50), "28–49% chance", F(24, "m"), RED, qa)
        text(d, (1260, y + 80), "within 10 years", F(24, "m"), RED, qa)
    # record card + harvested copy
    ca = a * P(t, 0.6, 1.1)
    card = lambda cx, cy, al, forged=0.0: (
        box(d, cx, cy, 330, 150, al, outline=GOLD if forged < 0.5 else RED),
        text(d, (cx, cy - 42), "Gold Lot #A-001", F(28, "sb"), WHITE, al),
        text(d, (cx, cy - 4), "999.9 fine g · 1 kg bar", F(22, "m"), GREY, al),
        text(d, (cx, cy + 34), "sig: ECDSA (r, s)", F(22, "m"), GOLDL if forged < 0.5 else RED, al))
    card(360, 340, ca)
    hp = P(t, 2.8, 4.2)
    ha = a * P(t, 2.6, 2.9)
    if ha > 0:
        cx = lerp(360, 1260, hp)
        cy = 340 - math.sin(hp * math.pi) * 60
        fg = P(t, 4.2, 4.5)
        card(cx, cy, ha * 0.9, forged=fg)
        text(d, (lerp(360, 1260, 0.5), 205), "harvest now ...", F(26, "m"), GREY, ha * (1 - fg))
        if fg > 0:
            sa = ha * fg
            d.rounded_rectangle([cx - 120, cy - 30, cx + 120, cy + 30], 8, outline=mix(RED, sa), width=5,
                                fill=mix((253, 226, 222), sa))
            text(d, (cx, cy), "FORGED", F(40, "b"), RED, sa)
            text(d, (1260, 205), "... forge later", F(26, "m"), RED, sa)


SIGS = [("Falcon-512", "NTRU lattice", "FIPS 206 (draft) · L1", "sig 666 B · pk 897 B", "smallest sig · on-chain"),
        ("ML-DSA-44", "module lattice", "FIPS 204 · L2", "sig 2,420 B · pk 1,312 B", "general signing"),
        ("ML-DSA-65", "module lattice", "FIPS 204 · L3", "sig 3,309 B · pk 1,952 B", "service keys · attestations"),
        ("SLH-DSA-128s", "hash-based (SHA-256)", "FIPS 205 · L1", "sig 7,856 B · pk 32 B", "offline root ceremony")]
KEMS = [("ML-KEM-768", "module lattice", "FIPS 203 · L3", "ct 1,088 B · ss 32 B", "envelope encryption"),
        ("ML-KEM-1024", "module lattice", "FIPS 203 · L5", "ct 1,568 B · ss 32 B", "long-term key wrapping")]


def card6(d, cx, cy, data, a, hl=0.0):
    name, fam, std, size, role = data
    oc = tuple(int(lerp(DIM[i], GOLD[i], 0.55 + 0.45 * hl)) for i in range(3))
    box(d, cx, cy, 390, 210, a, outline=oc, wd=2 + int(2 * hl))
    text(d, (cx, cy - 66), name, F(36, "b"), GOLDL, a)
    text(d, (cx, cy - 24), fam + "  ·  " + std, F(20), GREY, a)
    text(d, (cx, cy + 20), size, F(23, "m"), WHITE, a)
    d.line([(cx - 150, cy + 50), (cx + 150, cy + 50)], fill=mix(DIM, a), width=1)
    text(d, (cx, cy + 76), role, F(22, "sb"), GOLD, a)


def lattice_bg(d, t, a):
    b1, b2 = (96, 22), (38, 84)
    ox, oy = 960 + math.sin(t * 0.3) * 20, 540 + t * 6
    pts = []
    for i in range(-14, 15):
        for j in range(-9, 10):
            x = ox + i * b1[0] + j * b2[0]
            y = oy + i * b1[1] + j * b2[1]
            if -20 < x < W + 20 and 60 < y < H - 120:
                d.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=mix((214, 204, 176), a))
                pts.append((x, y))


def s3_primitives(d, t, a):
    lattice_bg(d, t, a * 0.9)
    text(d, (960, 150), "PQ Core · six NIST post-quantum primitives", F(46, "b"), WHITE, a * P(t, 0.0, 0.5))
    text(d, (960, 205), "one Rust crate  ->  native Node addon (servers)  +  WASM (browser & phone)", F(24, "m"),
         GREY, a * P(t, 0.3, 0.8))
    text(d, (960, 282), "DIGITAL SIGNATURES  —  authenticity", F(22, "sb"), GOLD, a * P(t, 0.5, 0.9))
    text(d, (960, 572), "KEY ENCAPSULATION  —  confidentiality", F(22, "sb"), GOLD, a * P(t, 2.0, 2.4))
    sweep = (t - 4.6) / 2.6 * 6
    for i, dat in enumerate(SIGS):
        st = 0.7 + i * 0.32
        ca = a * P(t, st, st + 0.45)
        card6(d, 960 + (i - 1.5) * 420, 420 + 30 * (1 - P(t, st, st + 0.45)), dat, ca,
              hl=clamp(1 - abs(sweep - i)))
    for i, dat in enumerate(KEMS):
        st = 2.1 + i * 0.32
        ca = a * P(t, st, st + 0.45)
        card6(d, 960 + (i - 0.5) * 420, 712 + 30 * (1 - P(t, st, st + 0.45)), dat, ca,
              hl=clamp(1 - abs(sweep - 4 - i)))
    text(d, (960, 862), "vendored PQClean C  ·  pinned sources  ·  CAVP / ACVP conformance vectors", F(22, "m"),
         GREY, a * P(t, 3.2, 3.8))


def s4_tiers(d, t, a):
    tiers = [(250, "TIER 0", "root"), (500, "TIER 1", "services"), (750, "TIER 2", "devices")]
    for k, (y, lab, sub) in enumerate(tiers):
        ta = a * P(t, 0.3 + k * 1.3, 0.8 + k * 1.3)
        text(d, (190, y - 16), lab, F(30, "b"), GOLD, ta)
        text(d, (190, y + 20), sub, F(22), GREY, ta)
    # tier 0
    ra = a * P(t, 0.3, 0.8)
    box(d, 1000, 250, 600, 140, ra, outline=GOLD, wd=3)
    text(d, (1000, 205), "ROOT KEY", F(24, "sb"), GREY, ra)
    text(d, (1000, 248), "SLH-DSA-SHA2-128s", F(40, "b"), GOLDL, ra)
    text(d, (1000, 292), "offline ceremony · pqctl · never on a server", F(22, "m"), GREY, ra)
    t1 = [(680, "Custodian service"), (1320, "Oracle service")]
    t2 = [(560, "User device"), (1000, "User device"), (1440, "User device")]
    for x, _ in t1:
        arrow(d, (1000, 322), (x, 432), GOLD, a, w=3, prog=P(t, 1.1, 1.7))
    text(d, (1000, 380), "certifies", F(20, "m"), GREY, a * P(t, 1.4, 1.8))
    for x, name in t1:
        ba = a * P(t, 1.6, 2.1)
        box(d, x, 500, 440, 130, ba, outline=GOLD)
        text(d, (x, 466), name, F(24, "sb"), GREY, ba)
        text(d, (x, 508), "ML-DSA-65", F(38, "b"), GOLDL, ba)
        text(d, (x, 546), "NIST level 3 · attestations", F(20, "m"), GREY, ba)
    for i, (x, _) in enumerate(t2):
        src = t1[0][0] if i < 2 else t1[1][0]
        arrow(d, (src, 567), (x, 690), GOLD, a, w=3, prog=P(t, 2.4, 3.0))
    for x, name in t2:
        ba = a * P(t, 2.9, 3.4)
        box(d, x, 750, 340, 120, ba, outline=GOLD)
        text(d, (x, 718), name, F(24, "sb"), GREY, ba)
        text(d, (x, 758), "Falcon-512", F(36, "b"), GOLDL, ba)
        text(d, (x, 792), "key never leaves device", F(18, "m"), GREY, ba)
    text(d, (1000, 895), "rotate with overlap  ·  revoke = set validTo, never delete  ·  old signatures stay verifiable",
         F(23, "m"), WHITE, a * P(t, 4.2, 4.8))


CHECKS = ["algorithm allow-listed for action", "signer key active & unrevoked", "domain separator matches",
          "clock inside validity window", "nonce = stored + 1", "signature verifies (zeroed envelope)",
          "payload hash = executed payload"]


def s5_flow(d, t, a):
    # phone
    pa = a * P(t, 0.1, 0.6)
    px, py = 330, 520
    box(d, px, py, 250, 460, pa, outline=GREY, r=34, wd=3)
    d.rounded_rectangle([px - 40, py - 214, px + 40, py - 204], 5, fill=mix(DIM, pa))
    text(d, (px, py - 150), "Invest", F(26), GREY, pa)
    text(d, (px, py - 108), "PKR 1,000", F(40, "b"), WHITE, pa)
    text(d, (px, py - 66), "-> gold, fine grams", F(20, "m"), GREY, pa)
    sg = P(t, 0.9, 1.5)
    box(d, px, py + 10, 180, 60, pa, outline=GOLD, fill=mix(GOLD, 0.15 + 0.6 * sg, PANEL), r=30)
    text(d, (px, py + 10), "Sign" if sg < 1 else "Signed", F(28, "b"), GOLDL if sg < 1 else BG, pa)
    keyicon(d, px - 10, py + 110, 70, GOLD, pa)
    text(d, (px, py + 160), "Falcon-512", F(26, "b"), GOLDL, pa)
    text(d, (px, py + 194), "WASM · on device", F(19, "m"), GREY, pa)
    # verifier
    va = a * P(t, 0.4, 0.9)
    vx, vy = 960, 520
    box(d, vx, vy, 660, 540, va, outline=GOLD, wd=3)
    text(d, (vx, vy - 230), "pq-verifier", F(34, "b"), WHITE, va)
    text(d, (vx, vy - 194), "stateless · holds no signing keys", F(20, "m"), GREY, va)
    for i, c in enumerate(CHECKS):
        y = vy - 140 + i * 56
        ct = 3.0 + i * 0.45
        done = P(t, ct, ct + 0.2)
        active = clamp(1 - abs(t - ct) * 3)
        d.rounded_rectangle([vx - 292, y - 18, vx - 256, y + 18], 6,
                            outline=mix(tuple(int(lerp(DIM[k], GREEN[k], done)) for k in range(3)), va), width=2,
                            fill=mix(tuple(int(lerp(PANEL[k], (214, 240, 222)[k], done)) for k in range(3)), va))
        tick(d, vx - 274, y - 2, 10, GREEN, va * done, w=4)
        text(d, (vx - 235, y), f"{i + 1}. {c}", F(23, "m"),
             tuple(int(lerp(GREY[k], WHITE[k], max(done, active))) for k in range(3)), va, anchor="lm")
    # contract
    ka = a * P(t, 0.7, 1.2)
    kx, ky = 1620, 520
    ex = P(t, 7.0, 7.4)
    box(d, kx, ky, 380, 320, ka, outline=tuple(int(lerp(GOLD[k], GREEN[k], ex)) for k in range(3)), wd=3)
    text(d, (kx, ky - 110), "Smart contract", F(32, "b"), WHITE, ka)
    text(d, (kx, ky - 72), "ERC-3643 gold token", F(22, "m"), GREY, ka)
    text(d, (kx, ky - 40), "re-checks its own rules", F(20, "m"), GREY, ka)
    tick(d, kx, ky + 30, 26, GREEN, ka * ex, w=7)
    text(d, (kx, ky + 100), "EXECUTED", F(34, "b"), GREEN, ka * ex)
    # links
    dashed(d, (465, 520), (620, 520), DIM, va, w=3, offset=t * 40)
    dashed(d, (1300, 520), (1420, 520), DIM, ka, w=3, offset=t * 40)
    # envelope packet
    def packet(x, y, al):
        box(d, x, y, 150, 86, al, outline=GOLDL, fill=(252, 241, 208), r=10, wd=2)
        text(d, (x, y - 16), "PQEnvelope", F(20, "mb"), GOLDL, al)
        text(d, (x, y + 16), "sig 666 B", F(18, "m"), WHITE, al)

    m1 = P(t, 1.5, 2.6)
    if 1.4 < t < 3.0:
        packet(lerp(px, 600, m1), 520 - math.sin(m1 * math.pi) * 90, a * P(t, 1.4, 1.6) * (1 - P(t, 2.7, 3.0)))
    m2 = P(t, 6.3, 7.0)
    if 6.2 < t < 7.4:
        packet(lerp(1280, 1500, m2), 520 - math.sin(m2 * math.pi) * 90, a * P(t, 6.2, 6.4) * (1 - P(t, 7.1, 7.4)))
    text(d, (960, 862), "cheap checks first, signature late  ·  first failure is reported by name",
         F(22, "m"), GREY, a * P(t, 3.4, 4.0))


def s6_merkle(d, t, a):
    lx = [210 + i * 150 for i in range(8)]
    ly, l1y, l2y, ry = 800, 650, 500, 330
    levels = [lx]
    for _ in range(3):
        prev = levels[-1]
        levels.append([(prev[2 * i] + prev[2 * i + 1]) / 2 for i in range(len(prev) // 2)])
    ys = [ly, l1y, l2y, ry]
    starts = [0.2, 1.3, 1.9, 2.5]
    path = {0: {2}, 1: {1}, 2: {0}, 3: {0}}
    sib = {0: {3}, 1: {0}, 2: {1}}
    pr = P(t, 5.0, 5.4)
    for L in range(1, 4):
        for j, x in enumerate(levels[L]):
            for c in (2 * j, 2 * j + 1):
                cx = levels[L - 1][c]
                lc = GREEN if (pr > 0 and c in path[L - 1] and j in path[L]) else GOLD
                line(d, (cx, ys[L - 1] - 30), (x, ys[L] + 30), lc, a * 0.8, w=3,
                     prog=P(t, starts[L] - 0.3, starts[L] + 0.1))
    for L in range(4):
        for j, x in enumerate(levels[L]):
            st = starts[L] + (j * 0.1 if L == 0 else 0)
            na = a * P(t, st, st + 0.35)
            y = ys[L] + (20 * (1 - P(t, st, st + 0.35)) if L == 0 else 0)
            onp = j in path[L]
            iss = L < 3 and j in sib[L]
            oc = GOLD
            if pr > 0 and onp:
                oc = tuple(int(lerp(GOLD[k], GREEN[k], pr)) for k in range(3))
            if pr > 0 and iss:
                oc = tuple(int(lerp(GOLD[k], BLUE[k], pr)) for k in range(3))
            if L == 3:
                if t < 3.6:
                    box(d, x, y, 270, 80, na, outline=oc, fill=(252, 241, 208), wd=3)
                    text(d, (x, y - 14), "MERKLE ROOT", F(22, "b"), GOLDL, na)
                    text(d, (x, y + 16), "0x9f3a…c41e · 32 B", F(18, "m"), WHITE, na)
                else:
                    box(d, x, y, 270, 80, na * 0.6, outline=oc, wd=2)
                    text(d, (x, y), "root", F(22, "m"), GREY, na * 0.6)
            else:
                w = 120 if L == 0 else 130
                box(d, x, y, w, 60, na, outline=oc, wd=2 + (2 if pr > 0 and (onp or iss) else 0))
                lab = f"env {j + 1}" if L == 0 else "H(·‖·)"
                text(d, (x, y), lab, F(20, "m"), WHITE if L == 0 else GREY, na)
    text(d, (735, 875), "every 60 s · leaf = hash of a signed PQEnvelope", F(22, "m"), GREY, a * P(t, 0.6, 1.1))
    # chain
    cxs = 1640
    blocks = [(250, "block n"), (430, "block n+1"), (610, "block n+2")]
    ca = a * P(t, 2.8, 3.3)
    for k, (y, lab) in enumerate(blocks):
        lit = P(t, 4.6, 4.9) if k == 1 else 0
        box(d, cxs, y, 240, 110, ca * (0.55 if k == 2 else 1),
            outline=tuple(int(lerp(DIM[i], GOLD[i], 0.6 + 0.4 * lit)) for i in range(3)),
            fill=tuple(int(lerp(PANEL[i], (252, 241, 208)[i], lit)) for i in range(3)), wd=2 + int(2 * lit))
        text(d, (cxs, y - 22), lab, F(22, "sb"), GREY, ca)
        text(d, (cxs, y + 16), "anchor(root)" if (k == 1 and lit > 0.5) else "· · ·", F(20, "m"),
             GOLDL if k == 1 else DIM, ca)
        if k < 2:
            line(d, (cxs, y + 55), (cxs, y + 125), DIM, ca, w=4)
    text(d, (cxs, 140), "BLOCKCHAIN", F(24, "b"), GOLD, ca)
    mv = P(t, 3.6, 4.6)
    if 3.6 <= t < 4.75:
        x = lerp(levels[3][0], cxs, mv)
        y = lerp(ry, 430, mv) - math.sin(mv * math.pi) * 80
        box(d, x, y, 200, 64, a, outline=GOLDL, fill=(252, 241, 208), wd=3)
        text(d, (x, y), "32-byte root", F(20, "mb"), GOLDL, a)
    text(d, (cxs, 720), "1 tx per batch", F(24, "sb"), WHITE, a * P(t, 4.7, 5.1))
    text(d, (cxs, 754), "fixed cost, any number", F(20, "m"), GREY, a * P(t, 4.7, 5.1))
    text(d, (cxs, 782), "of actions", F(20, "m"), GREY, a * P(t, 4.7, 5.1))
    text(d, (cxs, 860), "proof = leaf + 3 sibling hashes", F(22, "m"), GREEN, a * P(t, 5.2, 5.6))
    text(d, (cxs, 890), "verify offline · no trust in QORA", F(22, "m"), GREEN, a * P(t, 5.2, 5.6))


def s7_outro(d, t, a):
    la = a * P(t, 0.2, 0.9)
    text(d, (960, 430), "QORA", F(170, "b"), GOLD, la)
    gw = 380 * P(t, 0.6, 1.4)
    d.line([(960 - gw, 540), (960 + gw, 540)], fill=mix(GOLD, la), width=3)
    text(d, (960, 600), "Own the real. Secure it for the quantum era.", F(44, "sb"), WHITE, a * P(t, 0.9, 1.5))
    text(d, (960, 680), "Falcon-512  ·  ML-DSA-44 / 65  ·  SLH-DSA-128s  ·  ML-KEM-768 / 1024", F(26, "m"), GREY,
         a * P(t, 1.4, 2.0))
    text(d, (960, 722), "sign off-chain  ·  verify 7 checks  ·  anchor on-chain  ·  prove offline", F(24, "m"),
         GREY, a * P(t, 1.7, 2.3))


SCENES = [(0, 6, s1_threat, "01 · THE THREAT"),
          (6, 12, s2_harvest, "02 · HARVEST NOW, FORGE LATER"),
          (12, 20, s3_primitives, "03 · THE SIX PRIMITIVES"),
          (20, 27, s4_tiers, "04 · KEY HIERARCHY"),
          (27, 36, s5_flow, "05 · SIGN -> VERIFY -> EXECUTE"),
          (36, 43, s6_merkle, "06 · BATCH & ANCHOR"),
          (43, 48, s7_outro, "")]

SUBS = [(0.4, 3.2, "Today, blockchains sign every action with ECDSA."),
        (3.3, 5.8, "A quantum computer running Shor's algorithm can break it."),
        (6.3, 8.9, "Gold ownership records must stay valid for 30+ years."),
        (9.0, 11.8, "Signatures harvested today could be forged once quantum arrives."),
        (12.3, 15.9, "QORA's PQ Core ships six NIST-standard post-quantum algorithms."),
        (16.0, 19.8, "Built on lattices and hashes, hard even for a quantum computer."),
        (20.3, 23.2, "Keys live in a three-tier hierarchy."),
        (23.3, 26.8, "An offline SLH-DSA root certifies ML-DSA-65 service keys and Falcon-512 device keys."),
        (27.3, 31.0, "Your phone signs each action with Falcon-512. The key never leaves the device."),
        (31.1, 35.8, "The verifier runs seven named checks before the smart contract executes."),
        (36.3, 39.4, "Every 60 seconds, signed envelopes are batched into a Merkle tree."),
        (39.5, 42.8, "Only one 32-byte root goes on-chain, and anyone can verify their action offline."),
        (43.4, 47.4, "Quantum-safe today. Provable for decades.")]


def make_bg():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    for x in range(0, W, 60):
        d.line([(x, 0), (x, H)], fill=(236, 233, 226))
    for y in range(0, H, 60):
        d.line([(0, y), (W, y)], fill=(236, 233, 226))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W / 2 - 700, H / 2 - 420, W / 2 + 700, H / 2 + 420], fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    return Image.composite(Image.new("RGB", (W, H), (255, 248, 228)), img, glow)


BGIMG = None


def frame(T):
    global BGIMG
    if BGIMG is None:
        BGIMG = make_bg()
    img = BGIMG.copy()
    d = ImageDraw.Draw(img)
    label = ""
    for s0, s1, fn, lab in SCENES:
        if s0 <= T < s1 or (T >= DUR and s1 == DUR):
            lt = T - s0
            a = P(lt, 0, 0.45) * (1 - P(T, s1 - 0.45, s1)) if s1 != DUR else P(lt, 0, 0.45) * (1 - P(T, DUR - 0.8, DUR))
            fn(d, lt, a)
            label = lab
            la = a
    # header
    ha = 1 - P(T, DUR - 0.8, DUR)
    text(d, (60, 52), "QORA", F(30, "b"), GOLD, ha, anchor="lm")
    text(d, (160, 53), "POST-QUANTUM CORE", F(20, "sb"), GREY, ha, anchor="lm")
    if label:
        text(d, (W - 60, 53), label, F(20, "sb"), GOLD, la, anchor="rm")
    d.rectangle([0, 0, int(W * T / DUR), 4], fill=mix(GOLD, 0.8 * ha))
    # subtitles
    for s0, s1, s in SUBS:
        if s0 <= T <= s1:
            sa = P(T, s0, s0 + 0.2) * (1 - P(T, s1 - 0.2, s1))
            f = F(36, "sb")
            tw = d.textlength(s, font=f)
            y = H - 82
            d.rounded_rectangle([W / 2 - tw / 2 - 26, y - 32, W / 2 + tw / 2 + 26, y + 30], 10,
                                fill=mix((24, 24, 30), sa * 0.92, BGIMG.getpixel((960, y))))
            text(d, (W / 2, y - 2), s, f, SUBTXT, sa, )
    return img


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--preview":
        outdir = os.environ.get("PREVIEW_DIR", ".")
        for s in sys.argv[2:]:
            frame(float(s)).save(os.path.join(outdir, f"preview_{float(s):05.1f}.png"))
        return
    out = sys.argv[1] if len(sys.argv) > 1 else "QORA_PQ_Explainer.mp4"
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
           "-movflags", "+faststart", out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    n = int(DUR * SLOW * FPS)
    for i in range(n):
        p.stdin.write(frame(i / FPS / SLOW).tobytes())
        if i % 150 == 0:
            print(f"frame {i}/{n}", flush=True)
    p.stdin.close()
    p.wait()
    print("done", out, p.returncode)


if __name__ == "__main__":
    main()
