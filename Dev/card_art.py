"""Turns a piece of card art (a business card on a black backdrop, as the
user delivers them) into a texture the client loads: Art/Cards/<name>.tga.

    ~/.cache/handbake-venv/bin/python -I Dev/card_art.py ref/cards/dwarf.png Art/Cards/dwarf.tga
    ~/.cache/handbake-venv/bin/python -I Dev/card_art.py --opaque ref/cards/nightelf.png Art/Cards/nightelf.tga
    ~/.cache/handbake-venv/bin/python -I Dev/card_art.py --key light ref/cards/gnome.png Art/Cards/gnome.tga

The card is cropped to where it is not black, the backdrop keyed out from
the edges in, the gaps that reach the backdrop (mortar between a stone
card's outer blocks) closed again, and the whole fitted into the top left
of a 1024x512 canvas: the client wants power-of-two sizes. 32-bit TGA, no
compression. A card with no backdrop (it fills its picture edge to edge,
the night elf's) is converted with --opaque: not cropped and not keyed,
so nothing dark at its edges (a vine, the wood) goes, the whole card
opaque. A card on a near-white backdrop (the gnome's badge, its rounded
corners) is converted with --key light: not cropped, the backdrop keyed
out from the edges in where it is lighter than LIGHT, no gaps closed (a
badge has no mortar), the edge shaved (SHAVE) and softened. It prints the keyed share of the art and the texcoords the
card's art fills, for its style (UI/Dungeon/Cards.lua). The sources stay
local (ref/ is ignored); needs Pillow, which the handwriting bake's venv
has.
"""

import sys
from collections import deque

from PIL import Image, ImageFilter

CANVAS = (1024, 512)
# A pixel this dark (its brightest channel under it) is backdrop, when the
# edges reach it through others like it.
DARK = 34
# Gaps narrower than this many px that the keying opened are closed again.
CLOSE = 41
# The keyed edge, softened by this blur radius.
SOFT = 1.2
# With --key light: a pixel this light (its darkest channel over it) is
# backdrop, when the edges reach it through others like it.
LIGHT = 245
# ... and the card's edge pulled in by this many px (a MinFilter's size),
# so the half-white pixels round it go too: no pale fringe.
SHAVE = 5


def card_box(im):
    px, (w, h) = im.load(), im.size
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if sum(px[x, y]) > 60:
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def keyed(im, light=False):
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    queue = deque((x, y) for x in range(w) for y in (0, h - 1))
    queue.extend((x, y) for y in range(h) for x in (0, w - 1))
    while queue:
        x, y = queue.popleft()
        i = y * w + x
        if seen[i] or (min(px[x, y]) <= LIGHT if light else max(px[x, y]) >= DARK):
            continue
        seen[i] = 1
        if x > 0: queue.append((x - 1, y))
        if x < w - 1: queue.append((x + 1, y))
        if y > 0: queue.append((x, y - 1))
        if y < h - 1: queue.append((x, y + 1))
    alpha = Image.frombytes("L", (w, h), bytes(0 if s else 255 for s in seen))
    if light:
        alpha = alpha.filter(ImageFilter.MinFilter(SHAVE))
    else:
        alpha = alpha.filter(ImageFilter.MaxFilter(CLOSE)).filter(ImageFilter.MinFilter(CLOSE))
    return alpha.filter(ImageFilter.GaussianBlur(SOFT))


def main(src, out, opaque=False, light=False):
    im = Image.open(src).convert("RGB")
    if not opaque and not light:
        im = im.crop(card_box(im))
    rgba = im.copy()
    alpha = Image.new("L", im.size, 255) if opaque else keyed(im, light)
    rgba.putalpha(alpha)
    hist = alpha.histogram()
    print("keyed: %.4f of the art clear, %.4f partly" % (hist[0] / sum(hist), sum(hist[1:255]) / sum(hist)))
    w, h = rgba.size
    s = min(CANVAS[0] / w, CANVAS[1] / h)
    aw, ah = round(w * s), round(h * s)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(rgba.resize((aw, ah), Image.Resampling.LANCZOS), (0, 0))
    canvas.save(out, compression=None)
    print("%s: art %dx%d in %dx%d, texcoords u 0-%.4f v 0-%.4f, aspect %.4f"
          % (out, aw, ah, CANVAS[0], CANVAS[1], aw / CANVAS[0], ah / CANVAS[1], aw / ah))


if __name__ == "__main__":
    args = sys.argv[1:]
    opaque = "--opaque" in args
    if opaque:
        args.remove("--opaque")
    light = False
    if "--key" in args:
        k = args.index("--key")
        light = args[k + 1] == "light"
        del args[k:k + 2]
    main(args[0], args[1], opaque, light)
