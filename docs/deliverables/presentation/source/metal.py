"""Physically-flavoured metal renderer for asset tokens and a gold ingot.

A relief heightmap (rim, recessed field, embossed emblem, reeded edge) is shaded by
reflecting a procedural studio environment (soft-box strips on black) with a metal
Fresnel tint. Reflections, not gradients, are what make metal read as metal.
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

METALS = {
    "gold":   dict(f0=(1.00, 0.72, 0.27), edge=(1.0, 0.90, 0.62)),
    "silver": dict(f0=(0.93, 0.93, 0.94), edge=(1.0, 1.0, 1.0)),
}
SS = 2  # supersampling


def _box(a, k, axis):
    if k < 1:
        return a
    pad = [(0, 0), (0, 0)]
    pad[axis] = (k + 1, k)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis, dtype=np.float64)
    if axis == 0:
        return ((c[2 * k + 1:] - c[:-2 * k - 1]) / (2 * k + 1)).astype(np.float32)
    return ((c[:, 2 * k + 1:] - c[:, :-2 * k - 1]) / (2 * k + 1)).astype(np.float32)


def blur(a, r):
    """Gaussian approximated by three box passes."""
    if r <= 0.5:
        return a.astype(np.float32)
    k = max(1, int(round(r * 0.9)))
    out = a.astype(np.float32)
    for _ in range(3):
        out = _box(_box(out, k, 0), k, 1)
    return out


def mask_from_draw(n, fn):
    im = Image.new("L", (n, n), 0)
    fn(ImageDraw.Draw(im), n)
    return np.asarray(im, dtype=np.float32) / 255.0


def env(rx, ry, rz):
    """Studio: a broad front soft box with a diagonal hot streak, overhead strip, rim lights, black room."""
    front = 0.50 * np.exp(-((rx + 0.05) ** 2 + (ry - 0.10) ** 2) / 0.35)
    grad = 0.22 * np.clip(ry + 0.6, 0, 1.6)
    streak = 1.10 * np.exp(-((0.75 * rx + 0.66 * ry - 0.04) ** 2) / 0.010)
    top = 1.0 * np.exp(-((ry - 0.70) ** 2) / 0.025)
    left = 0.9 * np.exp(-((rx + 0.80) ** 2) / 0.012)
    right = 0.45 * np.exp(-((rx - 0.82) ** 2) / 0.020)
    floor = 0.10 * np.clip(-ry, 0, 1)
    return 0.04 + front + grad + streak + top + left + right + floor


def shade(height, alpha, metal, strength, n):
    m = METALS[metal]
    gy, gx = np.gradient(height)
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(height)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / l, ny / l, nz / l
    # slight perspective: camera at finite distance so flat areas sweep through the environment
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    px, py = (xs / n - 0.5) * 2, -(ys / n - 0.5) * 2
    vx, vy, vz = -px * 0.35, -py * 0.35, np.ones_like(px)
    vl = np.sqrt(vx * vx + vy * vy + vz * vz)
    vx, vy, vz = vx / vl, vy / vl, vz / vl
    d = nx * vx + ny * vy + nz * vz
    rx, ry, rz = 2 * d * nx - vx, 2 * d * ny - vy, 2 * d * nz - vz
    e = env(rx, ry, rz)
    cos = np.clip(d, 0, 1)
    fres = (1 - cos) ** 5
    ao = np.clip(1 - (blur(height, n * 0.012) - height) * 6, 0.45, 1.0)  # crevice darkening
    out = np.zeros((n, n, 3), np.float32)
    for c in range(3):
        f = m["f0"][c] + (m["edge"][c] - m["f0"][c]) * fres
        out[..., c] = e * f * ao
    # filmic tone map so highlights roll off instead of clipping flat
    out = 1 - np.exp(-out * 1.9)
    out = out ** (1 / 1.1)
    rgba = np.dstack([np.clip(out, 0, 1), alpha])
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ emblems (drawn on n x n canvas, centred)
def emb_ingot(d, n):
    c = n / 2
    d.polygon([(c - n * .20, c + n * .10), (c + n * .20, c + n * .10), (c + n * .15, c - n * .10), (c - n * .15, c - n * .10)], fill=255)


def emb_bond(d, n):
    c = n / 2
    x0, y0, x1, y1 = c - n * .15, c - n * .19, c + n * .15, c + n * .19
    d.polygon([(x0, y0), (x1 - n * .06, y0), (x1, y0 + n * .06), (x1, y1), (x0, y1)], fill=255)
    for k in range(4):
        y = y0 + n * (.07 + k * .055)
        d.rectangle([x0 + n * .04, y, x1 - n * .05 - (n * .05 if k == 3 else 0), y + n * .018], fill=120)
    d.ellipse([c + n * .01, y1 - n * .11, c + n * .10, y1 - n * .02], fill=120)


def emb_sukuk(d, n):
    c = n / 2
    w = n * .24
    x0, x1 = c - w / 2, c + w / 2
    ys, yb = c - n * .02, c + n * .19
    pts = [(x0, yb), (x0, ys)]
    for k in range(25):  # left arc, centre (x1, ys): 180 -> 120 deg
        a = math.radians(180 - 60 * k / 24)
        pts.append((x1 + w * math.cos(a), ys - w * math.sin(a)))
    for k in range(25):  # right arc, centre (x0, ys): 60 -> 0 deg
        a = math.radians(60 - 60 * k / 24)
        pts.append((x0 + w * math.cos(a), ys - w * math.sin(a)))
    pts += [(x1, ys), (x1, yb)]
    d.polygon(pts, fill=255)
    iw = w * .5
    d.rectangle([c - iw / 2, c + n * .05, c + iw / 2, yb], fill=110)


def emb_estate(d, n):
    c = n / 2
    w = n * .32
    base = c + n * .17
    d.polygon([(c - w / 2 - n * .02, c - n * .04), (c, c - n * .20), (c + w / 2 + n * .02, c - n * .04)], fill=255)
    d.rectangle([c - w / 2, c - n * .04, c + w / 2, base], fill=255)
    for k in range(4):
        x = c - w / 2 + n * .03 + k * (w - n * .06) / 3.0
        d.rectangle([x - n * .012, c - n * .01, x + n * .012, base - n * .03], fill=120)
    d.rectangle([c - w / 2 - n * .02, base - n * .02, c + w / 2 + n * .02, base + n * .01], fill=255)


def emb_lock(d, n):
    c = n / 2
    d.rounded_rectangle([c - n * .15, c - n * .03, c + n * .15, c + n * .19], radius=int(n * .03), fill=255)
    d.arc([c - n * .10, c - n * .21, c + n * .10, c + n * .04], 180, 360, fill=255, width=int(n * .045))
    d.line([(c - n * .1 + n * .022, c - n * .08), (c - n * .1 + n * .022, c - n * .02)], fill=255, width=int(n * .045))
    d.line([(c + n * .1 - n * .022, c - n * .08), (c + n * .1 - n * .022, c - n * .02)], fill=255, width=int(n * .045))
    d.ellipse([c - n * .025, c + n * .04, c + n * .025, c + n * .09], fill=90)
    d.rectangle([c - n * .01, c + n * .07, c + n * .01, c + n * .14], fill=90)


def emb_text(label):
    def f(d, n):
        try:
            font = ImageFont.truetype("C:/Windows/Fonts/BOD_B.TTF", int(n * (.20 if len(label) <= 3 else .16)))
        except OSError:
            font = ImageFont.truetype("arialbd.ttf", int(n * .16))
        d.text((n / 2, n / 2), label, font=font, fill=255, anchor="mm")
    return f


EMBLEMS = {"gold": emb_ingot, "bond": emb_bond, "sukuk": emb_sukuk, "estate": emb_estate, "lock": emb_lock,
           "pkr": emb_text("PKR"), "usdc": emb_text("USDC"), "blank": None}


def token(path, emblem, metal, D=700):
    n = D * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xs - n / 2) ** 2 + (ys - n / 2) ** 2) / (n / 2)
    alpha = np.clip((1.0 - r) * n / 2 / 1.5, 0, 1)
    # profile: rounded outer edge, raised rim, recessed field
    h = np.zeros_like(r)
    edge = np.clip((1 - r) / 0.06, 0, 1)
    h += np.sin(edge * math.pi / 2) * 0.55
    rim = np.clip((r - 0.80) / 0.03, 0, 1) * np.clip((0.985 - r) / 0.03, 0, 1)
    h += rim * 0.35
    inner_bevel = np.clip((0.80 - r) / 0.025, 0, 1)
    h -= (1 - inner_bevel) * 0  # field stays at base
    # reeded rim texture
    ang = np.arctan2(ys - n / 2, xs - n / 2)
    reed = (np.sin(ang * 180) * 0.5 + 0.5) * np.clip((r - 0.93) / 0.02, 0, 1) * np.clip((0.99 - r) / 0.01, 0, 1)
    h += reed * 0.05
    # fine concentric bead ring inside rim
    beads = (np.sin(ang * 90) > 0.6).astype(np.float32) * np.exp(-((r - 0.755) ** 2) / 0.00004)
    h += blur(beads, n * 0.002) * 0.12
    # emblem relief
    if EMBLEMS.get(emblem):
        em = mask_from_draw(n, EMBLEMS[emblem])
        em = blur(em, n * 0.004)
        h += em * 0.32 + blur(em, n * 0.012) * 0.10
    h = blur(h, n * 0.0015)
    img = shade(h * n * 0.0065, alpha, metal, 1.0, n)
    img.resize((D, D), Image.LANCZOS).save(path)


def ingot(path, metal="gold", W=900, H=520):
    w, h_ = W * SS, H * SS
    ys, xs = np.mgrid[0:h_, 0:w].astype(np.float32)
    u, v = xs / w, ys / h_
    # frustum seen from above: plateau with chamfered sides (distance-to-edge profile)
    du = np.minimum(u - 0.03, 0.97 - u) / 0.94
    dv = np.minimum(v - 0.05, 0.95 - v) / 0.90
    k = np.minimum(du * 0.94 * w, dv * 0.90 * h_) / (0.16 * h_)
    inside = (du > 0) & (dv > 0)
    hgt = np.clip(k, 0, 1)
    hgt = np.where(inside, np.sqrt(hgt) * 0.9, 0)
    # stamped recessed plate
    pm = Image.new("L", (w, h_), 0)
    ImageDraw.Draw(pm).rounded_rectangle([w * .30, h_ * .36, w * .70, h_ * .64], radius=int(h_ * .05), fill=255)
    pm = np.asarray(pm.filter(ImageFilter.GaussianBlur(h_ * 0.006)), np.float32) / 255
    hgt = hgt - pm * 0.10
    alpha = np.clip(np.minimum(du * 0.94 * w, dv * 0.90 * h_) / 2.0, 0, 1) * inside
    n = max(w, h_)
    pad = np.zeros((n, n), np.float32); pa = np.zeros((n, n), np.float32)
    oy = (n - h_) // 2
    pad[oy:oy + h_, :w] = hgt; pa[oy:oy + h_, :w] = alpha
    img = shade(blur(pad, n * 0.0015) * n * 0.05, pa, metal, 1.0, n)
    img = img.crop((0, oy, w, oy + h_)).resize((W, H), Image.LANCZOS)
    img.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "art4"
    os.makedirs(out, exist_ok=True)
    for em in ["gold", "bond", "sukuk", "estate", "lock", "pkr", "usdc", "blank"]:
        for metal in ["gold", "silver"]:
            token(f"{out}/{em}_{metal}.png", em, metal, 520)
    ingot(f"{out}/ingot_gold.png", "gold")
    ingot(f"{out}/ingot_silver.png", "silver")
    print("ok")
