# handwriting-baker

Bakes short phrases into realistic handwriting **offline**, using the pretrained
handwriting-synthesis model from
[sjvasquez/handwriting-synthesis](https://github.com/sjvasquez/handwriting-synthesis)
(an implementation of Graves 2013, *Generating Sequences with Recurrent Neural Networks*).

The model runs here in plain NumPy, with no TensorFlow and no GPU. For every phrase,
style and seed it writes:

- a **transparent PNG** of the handwriting, inked with pressure-like stroke width
- a **JSON file with the pen strokes** in the same pixel space (points, widths, time order)
- a `manifest.json` listing everything, plus an optional `sheet.png` preview

Nothing here runs in the game. Bake offline, then ship the PNGs, or stroke data
converted to whatever format your client loads.

![example](docs/example_sheet.png)

---

## Quick start

```bash
pip install -r requirements.txt          # numpy, scipy, Pillow
python bake.py "died twice"              # -> ./baked/died-twice__style12_seed1.png/.json + manifest.json
python bake.py --file examples/phrases.txt --takes 4 --sheet --out baked/
python -m unittest discover -s tests -v  # smoke tests (~15 s)
```

Python 3.9+. Bake time is roughly 2–4 s per take for a short phrase on one CPU core,
roughly linear in phrase length. Takes run in parallel (`--jobs`, default 4).

## Agent checklist

1. Validate first: `python bake.py --file phrases.txt --check` (add `--fallback` to auto-fix characters).
2. Bake several takes per phrase: `--takes 4 --sheet`.
3. **Look at `sheet.png` before using a take.** The model is generative: a few
   takes come out with a malformed or missing letter, more often with low `--bias`
   or long phrases. Pick good seeds, then record them (style + seed + bias reproduce a take).
4. Re-bake chosen takes with `--seeds N` and the final render settings.
5. Use `manifest.json` to find the files; don't parse file names.

## CLI reference

```
python bake.py [phrases ...] [--file F] [options]
```

| Option | Default | Meaning |
|---|---|---|
| `phrases` / `--file F` | | Phrases to write. One line each. File: one per line; blank lines and `#` lines skipped. |
| `--style S [S ...]` | `12` | Handwriting style 0–12 (primed from a real writer), or `none` (unprimed). |
| `--takes N` | `1` | Takes per phrase and style, using seeds 1..N. |
| `--seeds N [N ...]` | | Explicit seeds (overrides `--takes`). |
| `--bias B` | `0.75` | Neatness. `0` = raw and messy, `0.5–1.0` typical, higher = more regular. |
| `--fallback` | off | Rewrite unsupported characters: Q/X/Z → lowercase, ä/ö/ü/ß → ae/oe/ue/ss, accents stripped, typographic quotes and dashes → ASCII. |
| `--out DIR` | `baked` | Output folder (created if missing). |
| `--scale PX` | `7` | Pixels per model unit. 7 ≈ 40 px x-height; the PNG grows proportionally. |
| `--width PX` | `3.2` | Base ink width in px. The actual width varies ~0.4–1.4× with pen speed. |
| `--ink COLOR` | `#1f2433` | Ink colour: hex (`#rrggbb[aa]`) or `r,g,b[,a]`. |
| `--bg COLOR` | transparent | Opaque background colour instead of transparency. |
| `--pad PX` | `16` | Margin around the text. |
| `--pow2` | off | Centre each image on a power-of-two canvas, for targets that need power-of-two textures. |
| `--no-png` / `--no-json` | | Skip one of the outputs. |
| `--sheet` | off | Write `sheet.png` with every take, labelled. |
| `--jobs N` | `min(4, cpus)` | Parallel worker processes. |
| `--check` | | Only validate phrases (exit 0 = ok, 2 = errors). |

Exit codes: `0` success, `2` invalid input (messages on stderr). Progress goes to stderr.

## Outputs

File stem: `<slug>__style<S>_seed<N>`, for example `died-twice__style12_seed1.png`. The slug is the
lowercased text with runs of other characters turned into `-`, cut at 40 characters, so
long phrases can share a slug. Use `manifest.json` as the source of truth.

### manifest.json

```json
{
  "generator": "handwriting-baker",
  "settings": {"bias": 0.75, "scale": 7.0, "width": 3.2, "ink": "#1f2433", "bg": null, "pad": 16, "pow2": false},
  "takes": [
    {"text": "died twice", "style": 12, "seed": 1, "bias": 0.75,
     "png": "died-twice__style12_seed1.png", "width": 781, "height": 183,
     "json": "died-twice__style12_seed1.json", "seconds": 2.91}
  ]
}
```

`text` is the text actually written, after any `--fallback` rewriting.

### Stroke JSON (one per take)

```json
{
  "text": "died twice", "style": 12, "seed": 1, "bias": 0.75,
  "image": {"file": "died-twice__style12_seed1.png", "width": 781, "height": 183},
  "units": "px, origin top-left, y down",
  "scale": 7.0,
  "baseline_y": 142.3,
  "steps": 215,
  "strokes": [
    {"t": [1, 2, 3], "points": [[71.46, 93.69], [69.44, 92.66], [65.62, 91.39]], "width": [2.32, 2.61, 2.87]}
  ]
}
```

- `strokes` are pen-down segments in writing order. Draw them in order and you get the
  same picture as the PNG.
- `points` are in the PNG's pixel space, so they overlay the image exactly.
- `width` is the rendered ink diameter in px at each point. It is thicker where the pen
  moved slowly.
- `t` is the model time step of each point. Steps are evenly spaced in time, so `t` drives
  a realistic "being written" animation: reveal points in `t` order, and pen-up gaps
  appear as jumps in `t`.
- `baseline_y` is the estimated writing line, for aligning several takes or lines.
- Points are smoothed model samples, about 25 per letter. Simplify them (for example
  Ramer–Douglas–Peucker) if you need fewer segments.

## Into the addon

Social Diary ships no PNG from here: `tools/to_lua.py` turns chosen takes' stroke JSON
into `UI/Ink/HandData.lua`, which `UI/Ink/Hand.lua` draws with the diary's own pen at any
size. Nothing in the addon writes with it at present; the only note baked so far is `snagged`.

1. Bake in the diary's hand, **style 9, bias 1.0**, a line at a time (about 15
   characters a line suits a small note): `python bake.py "snagged an item" "from me" --style 9 --bias 1.0 --takes 4 --sheet --out /tmp/notes`.
2. Look at `sheet.png`; copy the good takes into `notes/<key>/` as `1.json`, `2.json`, ...
   (one per line, top to bottom; `<key>` is the note's name in Lua, e.g. `snagged`).
3. From this folder, convert every note at once (the file is rewritten whole):

   ```bash
   ~/.cache/handbake-venv/bin/python tools/to_lua.py notes --out ../../UI/Ink/HandData.lua
   ```

   It prints each note's measured x-height and the points kept. Units are x-heights
   from the left end of each line's baseline; points are simplified with
   Ramer–Douglas–Peucker at `--tolerance` x-heights (default 0.035; every segment is a
   texture in game, so keep notes short). Text, style, seed and bias go into the file.
4. Draw the note with `ns.UI.Hand.Draw` where it belongs and run `luajit tests/run.lua`.

## Python API

```python
from handbake import bake, RenderSettings

take = bake("died twice", style=12, seed=1, bias=0.75)       # ValueError on unsupported text
img, meta = take.to_png(RenderSettings(scale=7, width=3.2))  # Pillow RGBA image
img.save("died_twice.png")
data = take.to_dict(RenderSettings(), png_name="died_twice.png")  # same dict as the JSON file
```

`bake(..., fallback=True)` applies the same rewriting as `--fallback`. `take.offsets`
holds the raw model output (`[dx, dy, end_of_stroke]` per step) and `take.strokes` the
cleaned strokes in model units.

## Choosing style, bias and seeds

- **Style 12** (default) is the most joined-up cursive. **5** and **8** are the neatest
  and most legible. **9** is narrow and condensed. **2** and **11** are loopier and less
  legible. These impressions come from short test phrases; preview with
  `--style 0 1 2 3 4 5 6 7 8 9 10 11 12 --sheet`.
- **Bias** trades character for legibility. Keep 0.6–1.0 for text people must read.
- **Seeds** give a different take every time with the same hand. For variety in game,
  bake 3–5 takes per phrase and rotate between them.
- **Reproducibility**: the same text, style, seed and bias give an identical take on the
  same machine and library versions. Across machines, tiny floating-point differences can
  change a take, so store the outputs rather than relying on re-baking.

## Limits

- **Character set**: lowercase a–z, capital letters except **Q, X, Z**, digits, space and
  `! " # ' ( ) , - . : ; ?`. No accents or umlauts (use `--fallback`) and no other symbols.
- **One line per phrase, at most 75 characters.** Quality drops on long lines; keep
  phrases short and split longer text into lines yourself.
- English handwriting only (that's what the model was trained on).

## How it works

| File | Role |
|---|---|
| `handbake/model.py` | NumPy port of the sampling path: 3 LSTM layers (400 units), soft attention window over the text, 20-component Gaussian mixture output. Optional priming with a real writer's sample sets the style. |
| `handbake/strokes.py` | Offsets → strokes: smoothing, slant correction, removal of stray pen dots, baseline estimate, ink width from pen speed. |
| `handbake/render.py` | Variable-width ink rasteriser (Pillow, 4× supersampled) and the preview sheet. |
| `handbake/cli.py`, `bake.py` | Command line baker. |
| `handbake/assets/weights.npz` | Pretrained weights (float32, ~13.5 MB). |
| `handbake/assets/styles/` | The 13 priming samples (strokes + text) from the original repo. |
| `tools/to_lua.py` | Chosen takes' strokes → the addon's `UI/Ink/HandData.lua` ("Into the addon"). |
| `tools/convert_checkpoint.py` | Rebuilds `assets/` from the original TensorFlow checkpoint (needs `tensorflow-cpu`, one-off). |
| `tests/test_smoke.py` | Validation, determinism, PNG/JSON agreement, CLI end-to-end. |

The port reproduces the original's sampling logic, including its stop condition and
neatness bias. Environment overrides: `HANDBAKE_WEIGHTS` and `HANDBAKE_STYLES` point to
alternative asset locations.

## Provenance and licensing

- The model code, weights and style samples come from
  [sjvasquez/handwriting-synthesis](https://github.com/sjvasquez/handwriting-synthesis).
  Its repository page lists no license.
