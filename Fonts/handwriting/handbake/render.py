"""
Rasterise strokes as variable-width ink with Pillow (4x supersampled).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.interpolate import CubicSpline

from .strokes import bounds

SS = 4  # supersampling factor


def parse_color(value):
    """'#1f2433', '1f2433', '#1f2433ff' or 'r,g,b[,a]' -> RGBA tuple."""
    if isinstance(value, (tuple, list)):
        return tuple(value) + ((255,) if len(value) == 3 else ())
    v = value.strip()
    if ',' in v:
        parts = [int(p) for p in v.split(',')]
        return tuple(parts) + ((255,) if len(parts) == 3 else ())
    v = v.lstrip('#')
    rgb = tuple(int(v[i:i + 2], 16) for i in range(0, len(v), 2))
    return rgb + ((255,) if len(rgb) == 3 else ())


def _densify(pts, w, factor=4):
    if len(pts) < 4:
        return pts, w
    t = np.arange(len(pts))
    tt = np.linspace(0, len(pts) - 1, (len(pts) - 1) * factor + 1)
    return (np.c_[CubicSpline(t, pts[:, 0])(tt), CubicSpline(t, pts[:, 1])(tt)],
            np.interp(tt, t, w))


def draw_strokes(draw, strokes, widths, scale, origin, color, ss=SS):
    """Draw onto a supersampled ImageDraw. origin = output-pixel offset of model (0,0)."""
    for s, w in zip(strokes, widths):
        p, w = _densify((s['pts'] * scale + origin) * ss, w * ss)
        if len(p) == 1:
            r = w[0] * 0.6
            draw.ellipse([p[0, 0] - r, p[0, 1] - r, p[0, 0] + r, p[0, 1] + r], fill=color)
            continue
        for i in range(len(p)):
            r = w[i] / 2
            draw.ellipse([p[i, 0] - r, p[i, 1] - r, p[i, 0] + r, p[i, 1] + r], fill=color)
            if i + 1 < len(p):
                d = p[i + 1] - p[i]
                L = np.hypot(*d)
                if L < 1e-6:
                    continue
                n = np.array([-d[1], d[0]]) / L
                a, b = w[i] / 2, w[i + 1] / 2
                draw.polygon([tuple(p[i] + n * a), tuple(p[i + 1] + n * b),
                              tuple(p[i + 1] - n * b), tuple(p[i] - n * a)], fill=color)


def _next_pow2(v):
    return 1 << (int(v) - 1).bit_length()


def layout(strokes, scale, pad, pow2=False):
    """Image size and the pixel origin of model (0,0) for one take."""
    lo, hi = bounds(strokes)
    size = np.ceil((hi - lo) * scale + 2 * pad).astype(int)
    origin = -lo * scale + pad
    if pow2:
        new = np.array([_next_pow2(size[0]), _next_pow2(size[1])])
        origin = origin + (new - size) / 2
        size = new
    return (int(size[0]), int(size[1])), origin


def render_png(strokes, widths, scale=7.0, color=(31, 36, 51, 255), pad=16, bg=None, pow2=False):
    """One take as an RGBA image. bg=None -> transparent background."""
    size, origin = layout(strokes, scale, pad, pow2)
    img = Image.new('RGBA', (size[0] * SS, size[1] * SS), bg or (0, 0, 0, 0))
    draw_strokes(ImageDraw.Draw(img), strokes, widths, scale, origin, color)
    return img.resize(size, Image.LANCZOS), origin


def _font(size):
    for path in ('/usr/share/fonts/opentype/inter/Inter-Regular.otf',
                 '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
                 '/Library/Fonts/Arial.ttf', 'C:/Windows/Fonts/arial.ttf'):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def contact_sheet(items, cols=3, cell=(560, 150), paper=(247, 244, 236), label_color=(138, 133, 119)):
    """items: list of (label, RGBA image). Returns an RGB preview sheet."""
    gap, top = 48, 30
    rows = (len(items) + cols - 1) // cols
    W = cols * cell[0] + (cols + 1) * gap
    H = rows * (cell[1] + top) + (rows + 1) * gap
    sheet = Image.new('RGBA', (W, H), paper + (255,))
    d = ImageDraw.Draw(sheet)
    font = _font(18)
    for i, (label, im) in enumerate(items):
        x = gap + (i % cols) * (cell[0] + gap)
        y = gap + (i // cols) * (cell[1] + top + gap)
        d.text((x, y), label, fill=label_color, font=font)
        im = im.copy()
        im.thumbnail(cell, Image.LANCZOS)
        sheet.alpha_composite(im, (x + (cell[0] - im.width) // 2, y + top + (cell[1] - im.height) // 2))
    return sheet.convert('RGB')
