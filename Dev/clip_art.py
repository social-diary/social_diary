"""Bakes the binder clip that holds a person's name sheet to their page
(UI/Journal/Header.lua, the person-page proposal, variant A, round 2):
Art/Paper/clip.tga and its shadow, Art/Paper/clip_shadow.tga.

    python3 -I Dev/clip_art.py                 # writes both into Art/Paper/
    python3 -I Dev/clip_art.py --preview /tmp/clip.png
                                               # and a look at it on the page,
                                               # 4x, outside the addon

Only the side that faces us: the clip's back plate and spine lie behind
the page, past its top edge, and are not drawn. What shows is the front
jaw, from the thin roll where it turns over the page's top edge down to
its lip biting the sheet, and the wire handles folded down over it and the
sheet. (21 Oct, in the client: the back plate and wire stood up past the
page's top edge.)

Painted the way the dungeon desk's blotter is, not photographed: flat dark
bronze, an ink rim, the thin roll along its top with one brushed light
on it, one brushed light across the jaw where the lamp (top left) finds
it, and the wire handles folded down over the sheet in pale brass. No
gloss, no reflections; the value only steps a little from top left to
bottom right, and a faint brush grain runs across the metal. The shadow
is the same outline, soft, in the page's ink, a texture of its own so the
client can lay it a little down and to the right of the clip (CLIP.shadow
in Header.lua) and leave it off laid flat.

Each texture is 128 px square: the clip is drawn on a 40 px square of
the screen, 3.2 texels a pixel. 32-bit TGA, no compression, as the
client takes them (Art/Cards/ are the same). Standard library only: no
PIL. Geometry below is in screen px of the 40 px square, y down; the
numbers Header.lua places the clip by (where its jaw's top and its lip
fall, CLIP.at, DENT) are these.
"""

import math
import struct
import sys
import zlib
from pathlib import Path

SIZE = 128          # texels a side
UNIT = 40.0         # the square on the screen, px
K = SIZE / UNIT     # texels a px
SS = 4              # samples a texel a side, for the edges

# The clip, in px of the 40 px square (y down):
#   EDGE    where the page's top edge falls (Header.lua lays it so):
#           nothing is drawn above the roll, and its shadow is cut here
#   roll    the thin roll where the jaw turns over the edge: x0..x1,
#           y0..y1, round ends (about a pixel of it over the edge)
#   body    the front jaw, a trapezoid narrower at the roll: its top
#           (y, x0, x1) and its lip on the paper (y, x0, x1), corners
#           rounded by `round`
#   wire    the handles folded down: two legs at x, from y0 down to the
#           bar at y1, its corners turned on radius `r`; `width` the dark
#           wire, `core` its light middle
EDGE = 4.4
ROLL = dict(x0=7.0, x1=33.0, y0=3.2, y1=5.9)
BODY = dict(top=(4.6, 8.0, 32.0), lip=(24.5, 6.0, 34.0), round=1.4)
WIRE = dict(x=(11.6, 28.4), y0=5.2, y1=33.0, r=3.6, width=2.5, core=1.05)
# Where the sheet's top falls under the clip, for the preview only.
SHEET_TOP = 18.4
RIM = 1.0           # the ink rim round the metal, px

# Colours (0..255): the bronze lit (top left) and in shade (bottom right),
# its rim, the roll, the lights, the wire.
BRONZE_LIT = (92, 69, 40)
BRONZE_SHADE = (46, 33, 17)
RIM_INK = (29, 19, 8)
ROLL_LIT = (122, 93, 56)
ROLL_SHADE = (78, 58, 33)
LIGHT = (214, 181, 122)      # the brushed light on the roll
JAW_LIGHT = (150, 118, 74)   # the brushed light across the jaw
LIP = (34, 23, 11)           # the lip's edge, where it bites
WIRE_DARK = (40, 28, 13)
WIRE_LIT = (206, 172, 112)
WIRE_SHADE = (150, 120, 76)
# The shadow: the page's ink (Style.INK), at most `alpha`, blurred over
# `blur` px (a Gaussian's sigma), the outline grown `grow` px first.
SHADOW = dict(ink=(61, 41, 18), alpha=0.55, blur=1.15, grow=0.3)
# How far down Header.lua lays the shadow (CLIP.shadow's y).
SHADOW_DOWN = 1.7


# ---------------------------------------------------------------- shapes as distances (px; < 0 inside)

def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def poly_dist(px, py, pts):
    """Signed distance to a convex polygon (clockwise or not)."""
    d = min(seg_dist(px, py, *pts[i], *pts[(i + 1) % len(pts)]) for i in range(len(pts)))
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return -d if inside else d


def body_dist(px, py):
    (ty, tx0, tx1), (ly, lx0, lx1), r = BODY["top"], BODY["lip"], BODY["round"]
    pts = [(tx0 + r, ty + r), (tx1 - r, ty + r), (lx1 - r, ly - r), (lx0 + r, ly - r)]
    return poly_dist(px, py, pts) - r


def roll_dist(px, py):
    R = ROLL
    r = (R["y1"] - R["y0"]) / 2
    cy = R["y0"] + r
    return seg_dist(px, py, R["x0"] + r, cy, R["x1"] - r, cy) - r


def wire_path():
    """The handles' wire as points: down the left leg, round the corner,
    along the bar, round, up the right leg."""
    (xl, xr), y0, y1, r = WIRE["x"], WIRE["y0"], WIRE["y1"], WIRE["r"]
    pts = [(xl, y0), (xl, y1 - r)]
    for k in range(1, 8):
        a = math.pi - k * (math.pi / 2) / 8
        pts.append((xl + r + r * math.cos(a), y1 - r + r * math.sin(a)))
    pts.append((xl + r, y1))
    pts.append((xr - r, y1))
    for k in range(1, 8):
        a = math.pi / 2 - k * (math.pi / 2) / 8
        pts.append((xr - r + r * math.cos(a), y1 - r + r * math.sin(a)))
    pts.append((xr, y1 - r))
    pts.append((xr, y0))
    return pts


WIRE_PTS = wire_path()


def wire_dist(px, py):
    return min(seg_dist(px, py, *WIRE_PTS[i], *WIRE_PTS[i + 1]) for i in range(len(WIRE_PTS) - 1))


# ---------------------------------------------------------------- paint

def noise(x, y, seed):
    """Smooth value noise, 0..1, for the brush's grain."""
    def h(i, j):
        n = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
    i, j = math.floor(x), math.floor(y)
    fx, fy = x - i, y - j
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b, c, d = h(i, j), h(i + 1, j), h(i, j + 1), h(i + 1, j + 1)
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def over(dst, colour, alpha):
    """`colour` at `alpha` over the premultiplied-free pixel dst (r, g, b, a)."""
    r, g, b, a = dst
    out_a = alpha + a * (1 - alpha)
    if out_a <= 0:
        return (0.0, 0.0, 0.0, 0.0)
    f = alpha / out_a
    return (r + (colour[0] - r) * f, g + (colour[1] - g) * f, b + (colour[2] - b) * f, out_a)


def cover(d, soft=0.5):
    """Coverage from a signed distance, px: an edge `soft` px wide."""
    return max(0.0, min(1.0, 0.5 - d / soft))


def stroke_cover(d, width):
    return cover(d - width / 2, 0.45)


def shade_at(x, y):
    """How lit the metal is at x, y: 1 at the lamp's corner (top left), 0
    at the far one, in a couple of soft steps (painted, not airbrushed)."""
    t = ((x - 6) * 0.55 + (y - 4) * 0.85) / 26.0
    t = max(0.0, min(1.0, t))
    # Partly in three loose bands, the brush's: flatter than a gradient.
    return 1 - (0.6 * t + 0.4 * math.floor(t * 3 + 0.5) / 3)


def pixel(x, y):
    """The clip's colour at x, y (px), as (r, g, b, a)."""
    px = (0.0, 0.0, 0.0, 0.0)
    grain = (noise(x * 0.9, y * 5.0, 3) - 0.5) * 10 + (noise(x * 2.4, y * 9.0, 7) - 0.5) * 5

    # The jaw: its rim, then the bronze inside it.
    db = body_dist(x, y)
    a_rim = cover(db, 0.5)
    if a_rim > 0:
        px = over(px, RIM_INK, a_rim)
        a_in = cover(db + RIM, 0.5)
        if a_in > 0:
            lit = shade_at(x, y)
            c = mix(BRONZE_SHADE, BRONZE_LIT, lit)
            c = tuple(v + grain for v in c)
            # The lip's edge, where it bites the paper: a darker band.
            ly = BODY["lip"][0]
            c = mix(c, LIP, max(0.0, 1 - (ly - RIM - y) / 2.2) * 0.85)
            px = over(px, c, a_in)
            # One brushed light across the jaw, under the roll, toward the
            # lamp: a short soft stroke, fading to its right end.
            d = seg_dist(x, y, 9.4, 9.0, 19.5, 8.3)
            a = cover(d - 1.1, 0.8) * 0.75 * max(0.0, min(1.0, (21 - x) / 8))
            if a > 0:
                px = over(px, mix(JAW_LIGHT, BRONZE_LIT, (noise(x * 3, y, 11) - 0.5) * 0.6), a)

    # The rolled hinge over its top.
    dr = roll_dist(x, y)
    a_rim = cover(dr, 0.5)
    if a_rim > 0:
        px = over(px, RIM_INK, a_rim)
        a_in = cover(dr + RIM * 0.9, 0.5)
        if a_in > 0:
            R = ROLL
            v = (y - R["y0"]) / (R["y1"] - R["y0"])
            c = mix(ROLL_LIT, ROLL_SHADE, v * 0.9 + (x - R["x0"]) / (R["x1"] - R["x0"]) * 0.35)
            c = tuple(k + grain * 0.6 for k in c)
            px = over(px, c, a_in)
            # Its one light: brushed along its upper side, from the left.
            d = seg_dist(x, y, 9.5, 4.2, 22.5, 4.0)
            a = cover(d - 0.4, 0.5) * 0.85 * max(0.0, min(1.0, (25 - x) / 7))
            if a > 0:
                px = over(px, LIGHT, a)

    # The wire handles folded down over it all and onto the sheet.
    dw = wire_dist(x, y)
    a = stroke_cover(dw, WIRE["width"])
    if a > 0:
        px = over(px, WIRE_DARK, a)
        a = stroke_cover(dw, WIRE["core"] + 0.25)
        if a > 0:
            # The left leg and the bar's left half face the lamp.
            lit = max(0.0, min(1.0, 1.15 - (x - WIRE["x"][0]) / 20 - (y - 6) / 60))
            px = over(px, mix(WIRE_SHADE, WIRE_LIT, lit), a * 0.95)
    return px


def shadow_alpha(x, y):
    # Laid SHADOW_DOWN px lower than the clip, it is cut where the page's
    # edge falls on it: nothing of it on the cover above the page.
    if y < EDGE - SHADOW_DOWN:
        return 0.0
    g = SHADOW["grow"]
    d = min(body_dist(x, y), roll_dist(x, y), wire_dist(x, y) - WIRE["width"] / 2)
    return 1.0 if d < g else 0.0


# ---------------------------------------------------------------- bake

def bake():
    clip = [[(0.0, 0.0, 0.0, 0.0)] * SIZE for _ in range(SIZE)]
    hard = [[0.0] * SIZE for _ in range(SIZE)]
    n = SS * SS
    for ty in range(SIZE):
        for tx in range(SIZE):
            r = g = b = a = 0.0
            s = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = (tx + (sx + 0.5) / SS) / K
                    y = (ty + (sy + 0.5) / SS) / K
                    pr, pg, pb, pa = pixel(x, y)
                    r, g, b, a = r + pr * pa, g + pg * pa, b + pb * pa, a + pa
                    s += shadow_alpha(x, y)
            if a > 0:
                clip[ty][tx] = (r / a, g / a, b / a, a / n)
            hard[ty][tx] = s / n
    soft = blur(hard, SHADOW["blur"] * K)
    # The blur spreads it back up past the edge: cut again, sharp, as the
    # page's edge cuts it.
    cut = int(math.ceil((EDGE - SHADOW_DOWN) * K))
    for ty in range(min(cut, SIZE)):
        soft[ty] = [0.0] * SIZE
    return clip, soft


def blur(img, sigma):
    radius = int(math.ceil(sigma * 3))
    kernel = [math.exp(-(i * i) / (2 * sigma * sigma)) for i in range(-radius, radius + 1)]
    total = sum(kernel)
    kernel = [k / total for k in kernel]
    h, w = len(img), len(img[0])
    tmp = [[sum(kernel[k + radius] * img[y][min(w - 1, max(0, x + k))] for k in range(-radius, radius + 1))
            for x in range(w)] for y in range(h)]
    return [[sum(kernel[k + radius] * tmp[min(h - 1, max(0, y + k))][x] for k in range(-radius, radius + 1))
             for x in range(w)] for y in range(h)]


def clamp8(v):
    return max(0, min(255, int(round(v))))


def write_tga(path, rows):
    """rows: rows of (r, g, b, a 0..1), top first."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, len(rows[0]), len(rows), 32, 8)
    body = bytearray()
    for row in reversed(rows):   # bottom-left origin, as Art/Cards/ are
        for r, g, b, a in row:
            body += bytes((clamp8(b), clamp8(g), clamp8(r), clamp8(a * 255)))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(header + bytes(body))


def write_preview(path, clip, shade):
    """The clip on a piece of the page and the sheet, 4x, for a look: never
    in the addon (*.png is ignored, and stays out)."""
    page, sheet, ink = (226, 211, 175), (242, 233, 205), SHADOW["ink"]
    scale = 4
    W = H = SIZE
    off = (round(1.3 * K), round(SHADOW_DOWN * K))
    edge_y = round(EDGE * K)               # the page's top edge, as Header.lua lays the clip
    sheet_y = round(SHEET_TOP * K)         # the sheet's top there, under the lip
    out = []
    for y in range(H):
        line = []
        for x in range(W):
            if y < edge_y:
                base = (58, 38, 22)        # the leather above the page
            elif y < sheet_y or x < round(2 * K):
                base = page
            else:
                base = sheet
            sx, sy = x - off[0], y - off[1]
            sa = shade[sy][sx] * SHADOW["alpha"] if 0 <= sx < W and 0 <= sy < H else 0
            c = mix(base, ink, sa)
            r, g, b, a = clip[y][x]
            c = mix(c, (r, g, b), a)
            line.append(c)
        out.append(line)
    raw = bytearray()
    for y in range(H * scale):
        raw.append(0)
        for x in range(W * scale):
            raw += bytes(clamp8(v) for v in out[y // scale][x // scale])

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * scale, H * scale, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


# ---------------------------------------------------------------- the dent the jaw leaves

# The clip's mark on the sheet (Art/Paper/clip_dent.tga), laid on the
# sheet's plane over DENT's box in Header.lua, under the portrait and the
# clip. A 128 x 64 texture over 48 x 24 px of the sheet (its x 0 to 48, y 2
# to 26), drawn in its own px here (y down; the sheet's y less 2). One
# layer, blended as usual: ink where the paper goes darker, a warm white
# where it catches the light, transparent where it is untouched. Lit from
# the top left, as the house light (UI/Paper/Light.lua) lights everything:
#   lip      the jaw's lip in it: y, from x0 to x1 (the clip's art laid by
#            Header.lua's CLIP: its lip at y 24.5 of the square, 6 to 34)
#   crease   pressed flat and a little sunk right under the lip: ink at
#            `alpha` over `width` px, its ends fading over `fade`
#   bow      the paper springing back up under it: its upper slope faces
#            the lamp (`light`, warm white at `alpha`, `top` to `peak` to
#            `foot` px under the lip), its lower slope away (`shade`, ink)
#   pucker   at each end of the lip, short wrinkles fanning out and down
#            (degrees from the right, y down; px long), each a dark fold
#            with its lit side up and to the left of it, `dark`/`light`
#            alpha, fading to nothing along its length
DENT_W, DENT_H, DENT_SPAN = 128, 64, (48.0, 24.0)
DENT = dict(
    lip=dict(y=4.1, x0=2.4, x1=29.6),
    crease=dict(alpha=0.42, width=1.3, fade=2.5),
    bow=dict(top=1.6, peak=3.2, foot=8.5, light=0.55, shade=0.13, shadeTo=12.5),
    pucker=dict(left=((222, 4.5), (243, 7.5), (263, 5.0)), right=((-12, 6.0), (-33, 8.0), (-57, 5.0)),
                dark=0.40, light=0.50, width=0.8),
)
LIT = (255, 250, 232)
INK = SHADOW["ink"]


def dent_pixel(x, y):
    """The mark at x, y (its own px): (colour, alpha)."""
    L, C, B, P = DENT["lip"], DENT["crease"], DENT["bow"], DENT["pucker"]
    dark = light = 0.0
    if x < 0.5:
        return INK, 0.0          # off the sheet's left edge
    # How far along the lip, its ends soft.
    along = min(x - L["x0"], L["x1"] - x)
    span = max(0.0, min(1.0, 0.5 + along / C["fade"]))
    under = y - L["y"]           # px under the lip
    if span > 0 and under > -0.5:
        # The crease: darkest right under the lip.
        dark = max(dark, C["alpha"] * span * max(0.0, 1 - abs(under - 0.5) / C["width"]))
        # The bow: up its lit slope to the peak, down to its foot.
        if B["top"] < under < B["foot"]:
            t = (under - B["top"]) / (B["peak"] - B["top"]) if under < B["peak"] \
                else 1 - (under - B["peak"]) / (B["foot"] - B["peak"])
            light = max(light, B["light"] * span * t * t * (3 - 2 * t))
        # ... and its far slope, turned from the lamp, a breath darker.
        if B["peak"] + 2 < under < B["shadeTo"]:
            mid = (B["peak"] + 2 + B["shadeTo"]) / 2
            t = 1 - abs(under - mid) / ((B["shadeTo"] - B["peak"] - 2) / 2)
            dark = max(dark, B["shade"] * span * t)
    # The puckers: from each end of the lip, fanning out and down.
    for end_x, folds in ((L["x0"], P["left"]), (L["x1"], P["right"])):
        for angle, length in folds:
            a = math.radians(angle)
            dx, dy = math.cos(a), -math.sin(a)
            # y down: an angle below the horizontal points down.
            dy = abs(dy)
            ox, oy = end_x + dx * 0.6, L["y"] + 0.9
            ex, ey = ox + dx * length, oy + dy * length
            # Along it, and off it.
            vx, vy = ex - ox, ey - oy
            t = ((x - ox) * vx + (y - oy) * vy) / (vx * vx + vy * vy)
            if 0 <= t <= 1:
                fade = (1 - t) ** 1.4
                d = seg_dist(x, y, ox, oy, ex, ey)
                dark = max(dark, P["dark"] * fade * cover(d - P["width"] / 2, 0.45))
                # Its lit side, up and to the left (toward the lamp).
                d = seg_dist(x, y, ox - 0.7, oy - 0.6, ex - 0.7, ey - 0.6)
                light = max(light, P["light"] * fade * cover(d - P["width"] / 2, 0.45))
    # Ink over light where both: the fold's dark line wins.
    if dark >= light:
        return INK, dark
    return LIT, light


def bake_dent():
    sx, sy = DENT_SPAN[0] / DENT_W, DENT_SPAN[1] / DENT_H
    rows = []
    for ty in range(DENT_H):
        row = []
        for tx in range(DENT_W):
            r = g = b = a = 0.0
            for jy in range(SS):
                for jx in range(SS):
                    c, al = dent_pixel((tx + (jx + 0.5) / SS) * sx, (ty + (jy + 0.5) / SS) * sy)
                    r, g, b, a = r + c[0] * al, g + c[1] * al, b + c[2] * al, a + al
            n = SS * SS
            row.append((r / a, g / a, b / a, a / n) if a > 0 else (0.0, 0.0, 0.0, 0.0))
        rows.append(row)
    return rows


def write_dent_preview(path, rows):
    """The mark on the sheet's stock, 6x, beside nothing else."""
    paper, scale = (242, 233, 205), 6
    W, H = len(rows[0]), len(rows)
    raw = bytearray()
    for y in range(H * 3):
        raw.append(0)
        for x in range(W * 3):
            r, g, b, a = rows[y // 3][x // 3]
            raw += bytes(clamp8(paper[k] + ((r, g, b)[k] - paper[k]) * a) for k in range(3))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * 3, H * 3, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def main(argv):
    root = Path(__file__).resolve().parent.parent
    clip, shade = bake()
    write_tga(root / "Art" / "Paper" / "clip.tga", clip)
    ink = SHADOW["ink"]
    write_tga(root / "Art" / "Paper" / "clip_shadow.tga",
              [[(ink[0], ink[1], ink[2], v * SHADOW["alpha"]) for v in row] for row in shade])
    dent = bake_dent()
    write_tga(root / "Art" / "Paper" / "clip_dent.tga", dent)
    if "--preview" in argv:
        out = argv[argv.index("--preview") + 1]
        write_preview(out, clip, shade)
        write_dent_preview(out.replace(".png", "_dent.png"), dent)
    print("wrote Art/Paper/clip.tga, clip_shadow.tga (%dx%d) and clip_dent.tga (%dx%d)"
          % (SIZE, SIZE, DENT_W, DENT_H))


if __name__ == "__main__":
    main(sys.argv[1:])
