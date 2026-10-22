"""
Command line baker. Run `python bake.py --help` (or `python -m handbake --help`).
"""
import argparse
import json
import multiprocessing
import os
import re
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

from . import bake, RenderSettings, normalize_text, HandwritingModel, STYLES
from .render import parse_color, contact_sheet

_WORKER_MODEL = None


def _init_worker():
    global _WORKER_MODEL
    _WORKER_MODEL = HandwritingModel()


def slugify(text, limit=40):
    s = re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')
    return (s[:limit].rstrip('-')) or 'text'


def _job(args):
    text, style, seed, bias, rs, out_dir, write_png, write_json = args
    t0 = time.time()
    take = bake(text, style=style, seed=seed, bias=bias, model=_WORKER_MODEL)
    stem = f"{slugify(text)}__style{'none' if style is None else style}_seed{seed}"
    entry = {'text': text, 'style': style, 'seed': seed, 'bias': bias}
    png_name = f'{stem}.png'
    img, meta = take.to_png(rs)
    if write_png:
        img.save(out_dir / png_name, optimize=True)
        entry['png'] = png_name
    entry.update(width=meta['width'], height=meta['height'])
    if write_json:
        with open(out_dir / f'{stem}.json', 'w') as f:
            json.dump(take.to_dict(rs, png_name if write_png else None), f, separators=(',', ':'))
        entry['json'] = f'{stem}.json'
    entry['seconds'] = round(time.time() - t0, 2)
    return entry, (img if not write_png else None)


def _style_arg(v):
    if v.lower() in ('none', 'unprimed'):
        return None
    i = int(v)
    if i not in STYLES:
        raise argparse.ArgumentTypeError(f'style must be one of {STYLES} or "none"')
    return i


def build_parser():
    p = argparse.ArgumentParser(
        prog='bake.py',
        description='Bake handwritten text to transparent PNGs + stroke JSON using a pretrained handwriting model.')
    p.add_argument('phrases', nargs='*', help='one or more phrases (each becomes one line of handwriting)')
    p.add_argument('--file', type=Path, help='text file, one phrase per line (blank lines and lines starting with # are skipped)')
    p.add_argument('--style', type=_style_arg, nargs='+', default=[12],
                   help='priming style(s) 0-12, or "none" (default: 12, the most joined-up cursive)')
    p.add_argument('--takes', type=int, default=1, help='takes per phrase and style, seeds 1..N (default: 1)')
    p.add_argument('--seeds', type=int, nargs='+', help='explicit seeds (overrides --takes)')
    p.add_argument('--bias', type=float, default=0.75, help='neatness: 0 = raw/messy, 0.75 default, >1 very regular')
    p.add_argument('--fallback', action='store_true',
                   help='rewrite unsupported characters where possible (Q/X/Z -> lowercase, ä -> ae, accents stripped)')
    p.add_argument('--out', type=Path, default=Path('baked'), help='output folder (default: ./baked)')
    p.add_argument('--scale', type=float, default=7.0, help='px per model unit; 7 gives ~40 px x-height (default: 7)')
    p.add_argument('--width', type=float, default=3.2, help='base ink width in px (default: 3.2)')
    p.add_argument('--ink', default='#1f2433', help='ink colour, hex or r,g,b[,a] (default: #1f2433)')
    p.add_argument('--bg', default=None, help='background colour; omit for transparent')
    p.add_argument('--pad', type=int, default=16, help='margin around the text in px (default: 16)')
    p.add_argument('--pow2', action='store_true', help='pad each PNG to power-of-two dimensions')
    p.add_argument('--no-png', action='store_true', help='skip PNG files')
    p.add_argument('--no-json', action='store_true', help='skip stroke JSON files')
    p.add_argument('--sheet', action='store_true', help='also write sheet.png, a preview of every take')
    p.add_argument('--jobs', type=int, default=min(4, os.cpu_count() or 1), help='parallel worker processes')
    p.add_argument('--check', action='store_true', help='only validate the phrases and exit')
    return p


def main(argv=None):
    a = build_parser().parse_args(argv)
    phrases = list(a.phrases)
    if a.file:
        phrases += [l.rstrip('\n') for l in a.file.read_text(encoding='utf-8').splitlines()
                    if l.strip() and not l.lstrip().startswith('#')]
    if not phrases:
        build_parser().error('give at least one phrase or --file')

    texts, errors = [], []
    for ph in phrases:
        try:
            t = normalize_text(ph, fallback=a.fallback)
            if t != ph:
                print(f'note: {ph!r} -> {t!r}', file=sys.stderr)
            texts.append(t)
        except ValueError as e:
            errors.append(str(e))
    if errors:
        print('\n'.join('error: ' + e for e in errors), file=sys.stderr)
        return 2
    if a.check:
        print(f'ok: {len(texts)} phrase(s) valid')
        return 0

    rs = RenderSettings(scale=a.scale, width=a.width, color=parse_color(a.ink), pad=a.pad,
                        bg=parse_color(a.bg) if a.bg else None, pow2=a.pow2)
    seeds = a.seeds or list(range(1, a.takes + 1))
    a.out.mkdir(parents=True, exist_ok=True)
    jobs = [(t, st, sd, a.bias, rs, a.out, not a.no_png, not a.no_json)
            for t in dict.fromkeys(texts) for st in a.style for sd in seeds]

    t0 = time.time()
    entries, sheet_items = [], []
    workers = max(1, min(a.jobs, len(jobs)))
    # 'spawn' gives each worker a fresh interpreter, so the one-BLAS-thread setting
    # in handbake/__init__.py applies even if the caller imported numpy first
    ctx = multiprocessing.get_context('spawn')
    with ProcessPoolExecutor(max_workers=workers, initializer=_init_worker, mp_context=ctx) as ex:
        for entry, img in ex.map(_job, jobs):
            entries.append(entry)
            print(f"baked {entry['text']!r} style={entry['style']} seed={entry['seed']} ({entry['seconds']}s)",
                  file=sys.stderr)
            if a.sheet:
                if img is None:
                    img = Image.open(a.out / entry['png']).convert('RGBA')
                label = f"{entry['text']} · style {entry['style']} · seed {entry['seed']}"
                sheet_items.append((label, img))

    manifest = {
        'generator': 'handwriting-baker',
        'settings': {'bias': a.bias, 'scale': rs.scale, 'width': rs.width, 'ink': a.ink,
                     'bg': a.bg, 'pad': rs.pad, 'pow2': rs.pow2},
        'takes': entries,
    }
    (a.out / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
    if a.sheet:
        contact_sheet(sheet_items).save(a.out / 'sheet.png', optimize=True)
    print(f'done: {len(entries)} take(s) in {time.time() - t0:.1f}s -> {a.out}', file=sys.stderr)
    return 0
