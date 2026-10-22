"""
handbake: bake handwritten text offline with a pretrained handwriting model.

    from handbake import bake
    take = bake("died twice", style=12, seed=1)
    img, meta = take.to_png()            # transparent RGBA Pillow image
    data = take.to_dict(png_name="x.png")  # stroke data in the same pixel space
"""
import os

# The model does many small vector-matrix products: one BLAS thread per process
# is fastest, and avoids oversubscription when the CLI runs parallel workers.
# Set these before importing handbake if you want different behaviour.
for _v in ('OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS', 'VECLIB_MAXIMUM_THREADS'):
    os.environ.setdefault(_v, '1')

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from .model import HandwritingModel, normalize_text, unsupported_chars, ALPHABET, SUPPORTED, STYLES
from .strokes import offsets_to_strokes, ink_widths, baseline, bounds
from .render import render_png, layout, parse_color

__all__ = ['bake', 'Take', 'HandwritingModel', 'normalize_text', 'unsupported_chars',
           'ALPHABET', 'SUPPORTED', 'STYLES', 'RenderSettings']

_MODEL = None


def get_model():
    global _MODEL
    if _MODEL is None:
        _MODEL = HandwritingModel()
    return _MODEL


@dataclass
class RenderSettings:
    scale: float = 7.0              # output px per model unit (~ x-height of 35-45 px)
    width: float = 3.2              # base ink width in output px
    color: tuple = (31, 36, 51, 255)
    pad: int = 16                   # transparent margin in px
    bg: Optional[tuple] = None      # None = transparent
    pow2: bool = False              # pad canvas to power-of-two size (texture-friendly)


@dataclass
class Take:
    text: str
    style: Optional[int]
    seed: int
    bias: float
    offsets: np.ndarray = field(repr=False)
    strokes: list = field(repr=False)

    def to_png(self, rs: RenderSettings = RenderSettings()):
        widths = ink_widths(self.strokes, rs.width)
        img, origin = render_png(self.strokes, widths, rs.scale, rs.color, rs.pad, rs.bg, rs.pow2)
        return img, dict(width=img.width, height=img.height, origin=origin)

    def to_dict(self, rs: RenderSettings = RenderSettings(), png_name=None):
        """Stroke data in the PNG's pixel space (origin top-left, y down)."""
        size, origin = layout(self.strokes, rs.scale, rs.pad, rs.pow2)
        widths = ink_widths(self.strokes, rs.width)
        r = lambda a: np.round(a, 2).tolist()
        return {
            'text': self.text,
            'style': self.style,
            'seed': self.seed,
            'bias': self.bias,
            'image': {'file': png_name, 'width': size[0], 'height': size[1]},
            'units': 'px, origin top-left, y down',
            'scale': rs.scale,
            'baseline_y': round(baseline(self.strokes) * rs.scale + float(origin[1]), 2),
            'steps': int(len(self.offsets)),
            'strokes': [
                {'t': s['t'].tolist(), 'points': r(s['pts'] * rs.scale + origin), 'width': r(w)}
                for s, w in zip(self.strokes, widths)
            ],
        }


def bake(text, style=12, seed=1, bias=0.75, fallback=False, model=None):
    """Generate one take of `text`. Raises ValueError for unsupported characters."""
    text = normalize_text(text, fallback=fallback)
    model = model or get_model()
    offsets = model.sample(text, style=style, bias=bias, seed=seed)
    return Take(text=text, style=style, seed=seed, bias=bias,
                offsets=offsets, strokes=offsets_to_strokes(offsets))
