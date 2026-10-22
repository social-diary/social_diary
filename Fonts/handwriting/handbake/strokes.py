"""
Turn raw model offsets into clean strokes in abstract "model units"
(y down, word sits roughly on y=0, slant-corrected), with per-point pen speed
and the model time step of each point.
"""
import numpy as np
from scipy.signal import savgol_filter


def offsets_to_strokes(offsets):
    """offsets [dx, dy, eos] -> list of dicts {pts Nx2, speed N, t N}."""
    off = offsets.copy()
    off[:, :2] *= 1.5
    coords = np.cumsum(off[:, :2], axis=0)
    ends = np.where(off[:, 2] == 1)[0]
    strokes, start = [], 0
    for e in list(ends) + [len(off) - 1]:
        if e < start:
            continue
        pts = coords[start:e + 1].copy()
        t = np.arange(start, e + 1)
        start = e + 1
        if len(pts) == 0:
            continue
        sp = np.r_[0.0, np.linalg.norm(np.diff(pts, axis=0), axis=1)]
        if len(sp) > 1:
            sp[0] = sp[1]
        if len(pts) >= 7:  # smooth digitiser noise (as in the original drawing.denoise)
            pts[:, 0] = savgol_filter(pts[:, 0], 7, 3, mode='nearest')
            pts[:, 1] = savgol_filter(pts[:, 1], 7, 3, mode='nearest')
        strokes.append(dict(pts=pts, speed=sp, t=t))

    # remove global baseline slope (as in the original drawing.align)
    fit = [s['pts'] for s in strokes if len(s['pts']) > 3] or [s['pts'] for s in strokes]
    allp = np.vstack(fit)
    slope = np.polyfit(allp[:, 0], allp[:, 1], 1)[0] if len(allp) > 1 else 0.0
    th = np.arctan(slope)
    R = np.array([[np.cos(th), -np.sin(th)], [np.sin(th), np.cos(th)]])
    for s in strokes:
        s['pts'] = s['pts'] @ R
        s['pts'][:, 1] *= -1  # y down
    return drop_stray_dots(strokes)


def drop_stray_dots(strokes):
    """Remove tiny pen touches that sit outside the written word (keeps i/j dots)."""
    ext = [np.ptp(s['pts'], axis=0).max() for s in strokes]
    h = np.ptp(np.vstack([s['pts'] for s in strokes])[:, 1])
    big = [s for s, e in zip(strokes, ext) if e > 0.15 * h]
    if not big:
        return strokes
    bp = np.vstack([s['pts'] for s in big])
    (x0, y0), (x1, y1) = bp.min(0), bp.max(0)
    m = 0.04 * h
    keep = []
    for s, e in zip(strokes, ext):
        if e <= 0.15 * h:
            c = s['pts'].mean(0)
            if not (x0 - m <= c[0] <= x1 + m and y0 - 4 * m <= c[1] <= y1 + m):
                continue
        keep.append(s)
    return keep


def bounds(strokes):
    allp = np.vstack([s['pts'] for s in strokes])
    return allp.min(0), allp.max(0)


def baseline(strokes):
    """Median of the strokes' bottom turning points (y down) ~ writing baseline."""
    b = []
    for s in strokes:
        y = s['pts'][:, 1]
        b += [y[i] for i in range(1, len(y) - 1) if y[i] >= y[i - 1] and y[i] >= y[i + 1]]
    if not b:
        return float(bounds(strokes)[1][1])
    return float(np.median(b))


def ink_widths(strokes, base):
    """Per-point stroke width: slow pen -> more ink, fast -> thinner, taper at pen down/up."""
    sp_all = [s['speed'] for s in strokes if len(s['speed']) > 3] or [s['speed'] for s in strokes]
    med = max(float(np.median(np.concatenate(sp_all))), 1e-6)
    out = []
    for s in strokes:
        w = base * np.clip(1.28 - 0.38 * s['speed'] / med, 0.42, 1.4)
        n = len(w)
        if n > 3:
            t = np.linspace(0, 1, n)
            w = w * np.clip(0.5 + t / 0.10, 0.5, 1.0) * np.clip(0.35 + (1 - t) / 0.14, 0.35, 1.0)
        if n >= 5:
            w = np.convolve(np.pad(w, 2, mode='edge'), np.ones(5) / 5, mode='valid')
        out.append(w)
    return out
