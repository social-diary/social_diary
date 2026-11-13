/* Social Diary · proposal kit (the plates skill, §6). The library behind proposal-template.html:
   the drawing kit K, one board (three variants at XL 220 · L 176 · M 142 · S 122), picks, comments, the handover.
   A proposal never edits this file; it copies the template and writes its DESIGN block. */
(() => { "use strict";   // only K, proposal and variant leave this scope: a DESIGN block may name anything else
const ERRORS = [];
function oops(where, e) { ERRORS.push(`${where}: ${e && e.message ? e.message : e}`); }
addEventListener("error", e => oops("script" + (e.lineno ? ` line ${e.lineno}` : ""), e.error || e.message));

// ---------------------------------------------------------------- the page's style (injected, so the HTML stays tiny)
document.head.insertAdjacentHTML("beforeend", `<style>
  @font-face { font-family: "SDHand"; font-style: italic;
    src: url("../../../../Fonts/Neuton-Italic.ttf"), url("../../Fonts/Neuton-Italic.ttf"), url("../Fonts/Neuton-Italic.ttf"); }
  :root {
    --page: #cfb789; --ink: #3d2912; --strong: #211408; --faded: #705936; --graphite: #4f4c47; --rubric: #801a0d;
    --strip: rgb(242,232,201); --tagp: rgb(250,242,222); --stock: rgb(236,226,200);
    --friz: "Marcellus", Georgia, serif; --hand: "SDHand", "Neuton", Georgia, serif;
    /* the review tools: a cool slate, so nothing of them reads as the diary's */
    --ui: ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
    --ui-ink: #a7b3bd; --ui-dim: #74818c; --ui-hi: #d5dee5; --ui-pick: #8fb0cf; --ui-bad: #d49a8c; --ui-line: #3a3129;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; }
  html { overflow-anchor: none; }
  body { font-family: var(--friz); color: var(--ink); background: #2a1a0d; padding: 0 28px 64px; min-width: 1000px; }
  /* the bar: the review's own controls */
  #bar { position: sticky; top: 0; z-index: 50; margin: 0 -28px 18px; padding: 8px 28px 9px; background: #1c120a;
    border-bottom: 1px solid var(--ui-line); font: 12px/1.6 var(--ui); color: var(--ui-ink); display: flex; flex-wrap: wrap; gap: 4px 22px; align-items: center; }
  #bar .who { color: var(--ui-hi); font-weight: 600; letter-spacing: .01em; }
  #bar .who small { font-weight: 400; color: var(--ui-dim); margin-left: 6px; }
  .grp { display: inline-flex; gap: 3px; align-items: center; flex-wrap: wrap; }
  .grp > span { color: var(--ui-dim); margin-right: 3px; }
  .chip { font: 11px/1 var(--ui); color: var(--ui-ink); background: transparent; border: 1px solid #4a4038; border-radius: 3px; padding: 3px 6px; cursor: pointer; }
  .chip:hover { border-color: var(--ui-dim); color: var(--ui-hi); }
  .chip.on { background: #2f3a44; border-color: #5f7383; color: var(--ui-hi); }
  #bar .act { margin-left: auto; display: inline-flex; gap: 6px; }
  #bar .act .chip { padding: 4px 9px; }
  #bar .act .main { border-color: #5f7383; color: var(--ui-hi); }
  #errors { display: none; margin: 0 0 14px; padding: 8px 12px; border: 1px solid #7a3b2e; background: #2b130c; font: 12px/1.5 var(--ui); color: var(--ui-bad); white-space: pre-wrap; }
  h2 { margin: 0 0 8px; font: 13px/1.4 var(--friz); letter-spacing: .12em; text-transform: uppercase; color: #e9d48f; display: flex; gap: 14px; align-items: baseline; }
  h3 { margin: 20px 0 8px; font: 15px/1.3 var(--friz); color: #f2ead4; display: flex; gap: 12px; align-items: baseline; flex-wrap: wrap; }
  h3 small, .lab small { font: 11px var(--ui); color: var(--ui-dim); letter-spacing: 0; text-transform: none; }
  .lab { font: 11px/1.4 var(--ui); color: var(--ui-ink); margin: 0 0 4px; display: flex; gap: 8px; align-items: baseline; flex-wrap: wrap; }
  .lab b { color: var(--ui-hi); font-weight: 600; }

  /* review controls: quiet until used */
  .rv { display: inline-flex; gap: 6px; align-items: baseline; flex-wrap: wrap; font: 11px var(--ui); }
  .rv button { font: 11px var(--ui); background: none; border: 0; padding: 0; color: var(--ui-dim); cursor: pointer; }
  .rv button:hover { color: var(--ui-hi); }
  .rv .rv-pick::before { content: "○ "; }
  .rv .rv-pick.on { color: var(--ui-pick); font-weight: 600; }
  .rv .rv-pick.on::before { content: "● "; }
  .rv .rv-c.has { color: var(--ui-ink); }
  .rv textarea { display: block; flex-basis: 100%; width: 100%; min-width: 220px; margin: 3px 0 0; padding: 5px 7px; resize: vertical;
    font: 12px/1.4 var(--ui); color: var(--ui-hi); background: #20160e; border: 1px solid #4a4038; border-radius: 3px; }
  .rv textarea[hidden] { display: none; }
  .fig { display: flex; flex-direction: column; }

  /* paper */
  .sheet { position: relative; background-color: var(--page); overflow: hidden;
    box-shadow: 0 0 0 1px #1b0c04, 6px 8px 12px -4px rgba(0,0,0,.6);
    background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='500' height='500'><filter id='p'><feTurbulence type='fractalNoise' baseFrequency='.02' numOctaves='4' seed='5'/><feColorMatrix values='0 0 0 0 .45  0 0 0 0 .3  0 0 0 0 .12  0 0 0 .22 -.06'/></filter><rect width='100%' height='100%' filter='url(%23p)'/></svg>"); }
  .wr { position: relative; height: 9px; margin: 0 0 8px; border-left: 1px solid rgba(61,41,18,.4); border-right: 1px solid rgba(61,41,18,.4); }
  .wr::before { content: ""; position: absolute; left: 0; right: 0; top: 4px; border-top: 1px solid rgba(61,41,18,.22); }
  .wr span { position: absolute; left: 50%; top: -3px; transform: translateX(-50%); padding: 0 4px; background: var(--page); font: 9px/12px Georgia, serif; color: rgba(61,41,18,.7); white-space: nowrap; }
  .none { font: 11px var(--ui); color: rgba(61,41,18,.6); padding: 6px 0; }
  /* a note: a box of w x h holding its slips */
  .note { position: relative; }
  .note > .at { position: absolute; }
  .slip { position: absolute; left: 0; top: 0; background: var(--strip); outline: 1px solid rgba(61,41,18,.16);
    transform: rotate(var(--r, .8deg));
    box-shadow: 0.8px 1px 0 rgba(61,41,18,.40), 1.4px 2.2px 2.6px rgba(61,41,18,.26); }
  .slip.tag { background: var(--tagp); outline-color: rgba(61,41,18,.18);
    box-shadow: 0.6px 0.8px 0 rgba(61,41,18,.42), 1.1px 1.8px 2.2px rgba(61,41,18,.28); }
  .slip > svg { position: absolute; left: 0; top: 0; overflow: visible; }
  .tape { position: absolute; width: 28px; height: 11px; transform: rotate(var(--tr, -11deg)); z-index: 6;
    background: rgba(224,199,122,.68); border-left: 2px solid rgba(214,185,100,.55); border-right: 2px solid rgba(214,185,100,.55);
    box-shadow: inset 0 -1px 0 rgba(107,84,41,.45), inset 0 1px 0 rgba(255,247,219,.4); }
  .tape.corner { width: 22px; height: 10px; }

  /* laid flat ("Flat paper only"), as the settings switch lays it */
  body.flat .slip, body.flat .mount { transform: none !important; }
  body.flat .slip { box-shadow: none; outline-color: rgba(61,41,18,.32); }
  body.flat .tape { background: rgba(224,199,122,.62); box-shadow: none; }

  #copied { position: fixed; inset: 60px 80px auto auto; z-index: 60; width: 560px; max-height: 70vh; display: none; flex-direction: column; gap: 6px;
    padding: 10px; background: #1c120a; border: 1px solid #5f7383; font: 12px var(--ui); color: var(--ui-ink); }
  #copied textarea { width: 100%; height: 50vh; font: 12px/1.45 ui-monospace, Menlo, monospace; color: var(--ui-hi); background: #20160e; border: 1px solid #4a4038; }

  /* the board: a variant a row, its sizes side by side, its mark */
  .v { margin: 0 0 30px; }
  .cells { display: flex; gap: 18px; align-items: flex-start; flex-wrap: wrap; }
  .cell { padding: 12px 14px 14px; }
  .cells > .fig { width: min-content; }
  .mk { padding: 8px; } .mk svg { display: block; }
  #warn, #whole { font: 12px/1.5 var(--ui); color: var(--ui-dim); margin: 0 0 14px; }
  #warn:empty { display: none; }
</style>`);

// Inks (UI/Style/Tokens.lua), the strip's margins (UI/Paper/Strip.lua STRIP.pad: left, top, right, bottom).
const C = { strong: "#211408", ink: "#3d2912", faded: "#705936", graphite: "#4f4c47", rubric: "#801a0d",
  paper: "rgb(242,232,201)", tag: "rgb(250,242,222)", stock: "rgb(236,226,200)" };
const STRIP_PAD = [7, 4, 8, 5];
const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const f2 = n => (+n).toFixed(2);
const SIZES = [["XL", 220], ["L", 176], ["M", 142], ["S", 122]];   // the band's real width each size is shown at
const VIEW = { flat: location.hash === "#flat", zoom: 1 };

// ---------------------------------------------------------------- the kit a design draws with
const _cv = document.createElement("canvas").getContext("2d");
const _font = (font, px) => font === "friz" ? `${px}px Marcellus, Georgia, serif` : `italic ${px}px SDHand, Neuton, Georgia, serif`;
function _w(t, font, px) { _cv.font = _font(font, px); return _cv.measureText(String(t)).width; }
// Seeded random (Park-Miller over an FNV hash, as Ink.Random): the same seed, the same slip.
function _hash(s) { let h = 2166136261; for (const c of String(s)) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return (h >>> 0) % 2147483646; }
function _rng(seed) { let s = (typeof seed === "number" ? Math.floor(seed) : _hash(seed)) % 2147483646 + 1; return () => (s = (s * 16807) % 2147483647) / 2147483647; }

// The pen (UI/Ink/Pen.lua): a line resampled into flat pieces sharing their edges, mitred, a nib thick and thin.
function _nib(dx, dy, N) { if (!dx && !dy) return 1; return N.thin + (N.thick - N.thin) * Math.abs(Math.sin(Math.atan2(-dy, dx) - N.angle * Math.PI / 180)); }
function _mitres(P) {
  const n = P.length, m = [];
  const normal = i => { const dx = P[i + 1][0] - P[i][0], dy = P[i + 1][1] - P[i][1], l = Math.hypot(dx, dy); return l < 1e-6 ? [0, -1] : [dy / l, -dx / l]; };
  for (let i = 0; i < n; i++) {
    if (i === 0) { m.push([...normal(0), 1]); continue; }
    if (i === n - 1) { m.push([...normal(n - 2), 1]); continue; }
    const a = normal(i - 1), b = normal(i); let nx = a[0] + b[0], ny = a[1] + b[1]; const l = Math.hypot(nx, ny);
    if (l < 1e-6) { m.push([b[0], b[1], 1]); continue; }
    nx /= l; ny /= l; m.push([nx, ny, Math.min(1 / Math.max(nx * b[0] + ny * b[1], 1e-3), 2)]);
  }
  return m;
}
const _unit = (a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1; return [dx / l, dy / l]; };
const SCRIBBLE = { width: 1.0, nib: { angle: 40, thin: 0.6, thick: 1.2 }, pitch: 1.45, cap: 0.70, over: [2.2, 3.2],
  lead: [2, 4], tail: [2, 4.5], slant: [-4, 2], bend: 1.4, round: 0.35, jit: 0.15, alpha: 0.92, taper: { from: 0.7, in: 4, end: 0.45, out: 5 } };
// The lucky card's strike through its printed words (Features/Hunts/LuckyCard.lua, STRIKE): one pass of the pen.
const STRIKE = { width: 1.15, nib: SCRIBBLE.nib, alpha: 0.92, cap: 0.70, low: 0.06, lead: [2, 4], tail: [2, 4.5], slant: [-2.4, 0.4], keep: 0.5,
  sag: 0.4, jit: 0.35, step: 4, most: 28, taper: { from: 0.8, in: 3, end: 0.4, out: 7 } };
const UNDER = { width: 1.35, nib: SCRIBBLE.nib, drop: 3.4, sag: 0.5, rise: 1.3, lead: 1.5, run: 4, jit: 0.4, step: 3.5, taper: { from: 0.85, in: 3, end: 0.4, out: 7 } };
const TALLY = { gap: 2.5, h: 10, lean: 0.5, jit: [0, 0.6, -0.4, 0.3], over: 1.6, rise: 7.2, width: 1.3, apart: 3.5 };

const K = {
  C, STRIP_PAD,
  /** Width of `t` in the diary's hand (the addon's Neuton Italic) at `px`. */
  hand: (t, px = 16) => _w(t, "hand", px),
  /** Width of `t` in Friz Quadrata at `px` (Marcellus stands in; Friz runs wider, x 1.07). drawn: the stand-in's own width. */
  friz: (t, px = 11, drawn) => _w(t, "friz", px) * (drawn ? 1 : 1.07),
  /** A line's height: the hand 16 → 19, 14 → 17; Friz 13 → 15, 11 → 13. */
  lh: (font, px) => font === "friz" ? (px <= 11 ? 13 : Math.round(px * 1.17)) : (px === 16 ? 19 : px === 14 ? 17 : Math.round(px * 1.2)),
  /** Baseline of a line whose top is `top`. */
  base: (top, font, px) => top + K.lh(font, px) / 2 + px * 0.32,
  /** `t` in lines no wider than `w` (no word left alone on the last); at most `most`. */
  wrap(t, font, px, w, most = Infinity) {
    const words = String(t).split(/\s+/).filter(Boolean), lines = [];
    let cur = "";
    for (const word of words) { const next = cur ? cur + " " + word : word; if (cur && K[font === "friz" ? "friz" : "hand"](next, px) > w) { lines.push(cur); cur = word; } else cur = next; }
    if (cur) lines.push(cur);
    if (lines.length > 1 && !/\s/.test(lines[lines.length - 1])) {
      const prev = lines[lines.length - 2].split(" ");
      if (prev.length > 1) { const moved = prev.pop() + " " + lines[lines.length - 1]; if (K[font === "friz" ? "friz" : "hand"](moved, px) <= w) { lines[lines.length - 2] = prev.join(" "); lines[lines.length - 1] = moved; } }
    }
    return lines.slice(0, most);
  },
  /** SVG text, its line's top at `top`. o: font "hand"|"friz", size, colour, anchor, alpha. */
  text(x, top, t, o = {}) {
    const font = o.font || "hand", size = o.size || (font === "friz" ? 11 : 16);
    const fam = font === "hand" ? 'font-family="SDHand, Neuton, Georgia, serif" font-style="italic"' : 'font-family="Marcellus, Georgia, serif"';
    return `<text x="${f2(x)}" y="${f2(K.base(top, font, size))}" ${fam} font-size="${size}" fill="${o.colour || (font === "hand" ? C.strong : C.ink)}"${o.anchor ? ` text-anchor="${o.anchor}"` : ""}${o.alpha != null ? ` opacity="${o.alpha}"` : ""}>${esc(t)}</text>`;
  },
  /** A straight stroke. o: width, colour, alpha. */
  line: (x1, y1, x2, y2, o = {}) => `<line x1="${f2(x1)}" y1="${f2(y1)}" x2="${f2(x2)}" y2="${f2(y2)}" stroke="${o.colour || C.strong}" stroke-width="${o.width || 1.2}"${o.alpha != null ? ` opacity="${o.alpha}"` : ""} stroke-linecap="round"/>`,
  /** The route's pen along points P. o: width, nib {angle, thin, thick}, taper {from, in, end, out}, colour, alpha. */
  pen(P, o = {}) {
    const n = P.length; if (n < 2) return "";
    const width = o.width || 1, N = o.nib || SCRIBBLE.nib, T = o.taper;
    const s = [0]; for (let i = 1; i < n; i++) s[i] = s[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]);
    const total = s[n - 1], M = _mitres(P);
    const half = i => { const a = P[Math.max(i - 1, 0)], b = P[Math.min(i + 1, n - 1)]; let t = 1;
      if (T) { t = Math.min(1, T.from + (1 - T.from) * s[i] / T.in); const r = total - s[i]; if (r < T.out) t *= T.end + (1 - T.end) * r / T.out; }
      return width / 2 * _nib(b[0] - a[0], b[1] - a[1], N) * t; };
    const rail = (i, side) => { const k = M[i], q = side * half(i); return [P[i][0] + k[0] * k[2] * q, P[i][1] + k[1] * k[2] * q]; };
    let out = "";
    for (let i = 0; i < n - 1; i++) out += `<polygon points="${[rail(i, 1), rail(i + 1, 1), rail(i + 1, -1), rail(i, -1)].map(p => f2(p[0]) + "," + f2(p[1])).join(" ")}"/>`;
    const c = o.colour || C.strong;
    return `<g fill="${c}" stroke="${c}" stroke-width=".18" stroke-linejoin="round" opacity="${o.alpha ?? SCRIBBLE.alpha}">${out}</g>`;
  },
  /** The hand's underline under x0..x1, `base` the words' baseline: through the descenders, rising, thinning off. */
  underline(x0, x1, base, seed) {
    const R = _rng(seed + ":u"), u = (a, b) => a + (b - a) * R(), U = UNDER;
    const a = [x0 - U.lead, base + U.drop + u(-U.jit, U.jit) + 0.3], z = [x1 + U.run, base + U.drop - U.rise + u(-U.jit, U.jit)];
    const c = [(a[0] + z[0]) / 2, (a[1] + z[1]) / 2 + 2 * U.sag];
    const n = Math.max(3, Math.ceil(Math.hypot(z[0] - a[0], z[1] - a[1]) / U.step)), P = [];
    for (let i = 0; i <= n; i++) { const t = i / n; P.push([(1 - t) * (1 - t) * a[0] + 2 * (1 - t) * t * c[0] + t * t * z[0], (1 - t) * (1 - t) * a[1] + 2 * (1 - t) * t * c[1] + t * t * z[1]]); }
    return K.pen(P, { width: U.width, nib: U.nib, taper: U.taper });
  },
  /** The hand's strike through printed words from x0, `w` wide, their row's middle at `mid`, type `px`: one pass of the pen,
      left to right, nearly level (the lucky card's, since 13 Nov; its scribble was too strong over the words). */
  strike(x0, mid, w, px, seed) {
    const R = _rng(seed), u = (a, b) => a + (b - a) * R(), S = STRIKE, half = S.cap * px / 2;
    const ax = x0 - u(...S.lead), zx = x0 + w + u(...S.tail), y = mid + S.low * px, most = S.keep * half;
    const tilt = Math.max(-most, Math.min(most, Math.tan(u(...S.slant) * Math.PI / 180) * (zx - ax) / 2));
    const ay = y - tilt + u(-S.jit, S.jit), zy = y + tilt + u(-S.jit, S.jit), cx = (ax + zx) / 2, cy = (ay + zy) / 2 + 2 * S.sag;
    const n = Math.min(S.most, Math.max(3, Math.ceil(Math.hypot(zx - ax, zy - ay) / S.step))), P = [];
    for (let i = 0; i <= n; i++) { const t = i / n; P.push([(1 - t) * (1 - t) * ax + 2 * (1 - t) * t * cx + t * t * zx, (1 - t) * (1 - t) * ay + 2 * (1 - t) * t * cy + t * t * zy]); }
    return K.pen(P, { width: S.width, nib: S.nib, taper: S.taper, alpha: S.alpha });
  },
  /** A zigzag scribble over printed words from x0, `w` wide, their cap band's middle at `mid`, type `px` (heavy over
      words: the lucky card gave it up for K.strike; kept for the older mockups that draw it). */
  scribble(x0, mid, w, px, seed) {
    const R = _rng(seed), u = (a, b) => a + (b - a) * R(), S = SCRIBBLE, half = S.cap * px / 2, pitch = S.pitch * px;
    const xs = x0 - u(...S.lead), xe = x0 + w + u(...S.tail);
    const n = Math.max(3, Math.round((xe - xs) / (pitch / 2))), step = (xe - xs) / n;
    let up = R() < 0.6; const raw = [[xs, mid + (up ? 1 : -1) * half * 0.35]];
    for (let k = 1; k <= n; k++) { raw.push([k === n ? xe : xs + k * step + u(-S.jit, S.jit) * step, mid + (up ? -1 : 1) * (half + u(...S.over))]); up = !up; }
    const last = raw[raw.length - 1]; raw.push([last[0] + pitch * 0.2, mid + (last[1] - mid) * -0.2]);
    const P = [raw[0]];
    for (let i = 1; i < raw.length - 1; i++) { const a = raw[i - 1], b = raw[i], c = raw[i + 1], d1 = _unit(a, b), d2 = _unit(b, c);
      P.push([b[0] - d1[0] * S.bend, b[1] - d1[1] * S.bend]); P.push([b[0] + (d2[0] - d1[0]) * S.round * S.bend, b[1] + (d2[1] - d1[1]) * S.round * S.bend]); P.push([b[0] + d2[0] * S.bend, b[1] + d2[1] * S.bend]); }
    P.push(raw[raw.length - 1]);
    const sl = u(...S.slant) * Math.PI / 180, cx = x0 + w / 2, co = Math.cos(sl), si = Math.sin(sl);
    return K.pen(P.map(([px_, py]) => [cx + (px_ - cx) * co - (py - mid) * si, mid + (px_ - cx) * si + (py - mid) * co]), { width: S.width, nib: S.nib, taper: S.taper });
  },
  /** A tally (the hunt card's gates of five) of `n` from x, its middle at y. Returns svg; K.tallyW(n) its width. */
  tally(n, x, y, colour = C.strong) {
    let s = "";
    while (n > 0) { const k = Math.min(5, n);
      for (let j = 1; j <= Math.min(k, 4); j++) { const u = x + TALLY.over + (j - 1) * TALLY.gap, hh = TALLY.h + (TALLY.jit[j - 1] || 0); s += K.line(u - TALLY.lean / 2, y + hh / 2, u + TALLY.lean / 2, y - hh / 2, { width: TALLY.width, colour }); }
      if (k >= 5) s += K.line(x, y + TALLY.rise / 2, x + K.tallyW(5), y - TALLY.rise / 2, { width: TALLY.width, colour });
      x += K.tallyW(k) + TALLY.apart; n -= k; }
    return s;
  },
  tallyW: k => k >= 5 ? 2 * TALLY.over + 3 * TALLY.gap : TALLY.over + (k - 1) * TALLY.gap + TALLY.width,
  /** An item's icon, stood in (never the game's art), `px` square, with its stack count. */
  icon: (x, y, px = 22, o = {}) => `<g><rect x="${x}" y="${y}" width="${px}" height="${px}" fill="#4a3720" stroke="${C.ink}" stroke-width="1"/>
    <path d="M${x + 3} ${y + px - 4} L${x + px * .55} ${y + 4} L${x + px - 3} ${y + px * .45} Z" fill="#8a6a3a" opacity=".8"/><rect x="${x + 1}" y="${y + 1}" width="${px - 2}" height="${px * .35}" fill="#fff" opacity=".08"/>
    ${o.count ? `<text x="${x + px - 1.5}" y="${y + px - 2}" text-anchor="end" font-family="Arial Narrow, Arial, sans-serif" font-weight="bold" font-size="${px < 20 ? 10 : 11}" fill="#fff" stroke="#000" stroke-width="2.2" paint-order="stroke">${o.count}</text>` : ""}</g>`,
  /** A creature cut in ink (the killer card's silhouette), in a w x h box. */
  silhouette: (x, y, w = 70, h = 48) => `<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="0 0 70 48"><path d="M14 44 L17 30 Q 13 26 15 20 Q 18 12 27 11 Q 30 6 35 7 Q 41 4 44 9 L 50 8 L 47 13 Q 52 15 52 21 Q 57 23 58 29 L 54 30 L 52 26 Q 50 33 47 36 L 49 44 L 44 44 L 42 37 Q 33 39 26 37 L 23 44 Z" fill="#14100b"/></svg>`,
  /** A small printed tag (a creature's level), turned a little, its top left at x, y. */
  levelTag(x, y, t) { const w = K.friz(t, 11) + 8;
    return `<g transform="rotate(-3 ${x} ${y})"><rect x="${x}" y="${y}" width="${f2(w)}" height="13" fill="#f7f0d6" stroke="rgba(61,41,18,.3)"/><text x="${x + 4}" y="${y + 10}" font-family="Marcellus, Georgia, serif" font-size="11" fill="${C.ink}">${esc(t)}</text></g>`; },
  /** The close call's chart: a bar `w` wide, filled `pct` in rubric, a tick at 10 %, its middle at y. */
  bar: (x, y, w, pct) => `<rect x="${x - 1}" y="${y - 4.5}" width="${w + 2}" height="9" fill="rgba(61,41,18,.8)"/><rect x="${x}" y="${y - 3.5}" width="${w}" height="7" fill="${C.paper}"/>`
    + `<rect x="${x}" y="${y - 3.5}" width="${f2(Math.max(1.5, w * pct / 100))}" height="7" fill="${C.rubric}"/><rect x="${f2(x + w * .1 - .5)}" y="${y - 6.5}" width="1" height="13" fill="${C.graphite}" opacity=".55"/>`,
  /**
   * A paper slip taped down: { w, h, seed, svg, html, paper: "strip"|"tag", tape: "top"|"corner"|"left"|"none", turn }.
   * svg is drawn in the slip's own px (0,0 its top left); html is laid over it. Returns { w, h, html }.
   */
  slip(o) {
    const R = _rng(String(o.seed || "slip") + ":slip"), sgn = R() < 0.5 ? -1 : 1;
    const turn = VIEW.flat ? 0 : (o.turn ?? sgn * (0.4 + R() * 1.0));
    const w = Math.ceil(o.w), h = Math.ceil(o.h), tape = o.tape || "top";
    let t = "";
    if (tape === "top") t = `<i class="tape" style="left:${f2(Math.max(16, w * .16) - 14)}px;top:-6px;--tr:${f2(-(11 + (R() - .5) * 12))}deg"></i>`;
    else if (tape === "corner") t = `<i class="tape corner" style="left:-10px;top:-4px;--tr:${f2(-(39 + R() * 12))}deg"></i>`;
    else if (tape === "left") t = `<i class="tape corner" style="left:-11px;top:${f2(Math.min(h * .36, 12) - 5)}px;--tr:${f2(-(78 + R() * 8))}deg"></i>`;
    return { w, h, html: `<div class="note" style="width:${w}px;height:${h}px"><div class="slip${o.paper === "tag" ? " tag" : ""}" style="width:${w}px;height:${h}px;--r:${f2(turn)}deg">${t}<svg width="${w}" height="${h}">${o.svg || ""}</svg>${o.html || ""}</div></div>` };
  },
  /** Two slips as one note: `b` laid over `a` at dx, dy (a tag over its card). */
  pair(a, b, dx, dy) {
    const w = Math.max(a.w, dx + b.w), h = Math.max(a.h, dy + b.h);
    return { w, h, html: `<div class="note" style="width:${w}px;height:${h}px"><div class="at" style="left:0;top:0">${a.html}</div><div class="at" style="left:${dx}px;top:${dy}px;z-index:2">${b.html}</div></div>` };
  },
  /** An existing mark on the plate (UI/Journey/Plate.lua's, approximated), at x, y. Kinds: MARKS' keys. */
  mark: (kind, x, y, n) => (MARKS[kind] || MARKS.dot)(x, y, n),
  rng: _rng,
};

function _cross(x, y, k) { return [[-1.9, -5], [1.9, -5], [1.9, -3.8], [4.1, -3.8], [4.1, 0], [1.9, 0], [1.9, 6], [-1.9, 6], [-1.9, 0], [-4.1, 0], [-4.1, -3.8], [-1.9, -3.8]].map(p => f2(x + p[0] * k) + "," + f2(y + p[1] * k)).join(" "); }
const _halo = (x, y, r = 8) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${C.stock}" opacity=".85"/>`;
const MARKS = {
  person: (x, y) => `<circle cx="${x}" cy="${y}" r="5.5" fill="none" stroke="${C.strong}" stroke-width="1.6"/><circle cx="${x}" cy="${y}" r="2" fill="${C.strong}"/>`,
  death: (x, y) => _halo(x, y, 7) + `<polygon points="${_cross(x, y, .75)}" fill="${C.strong}"/>`,
  close: (x, y) => _halo(x, y, 7) + `<polygon points="${_cross(x, y, 1)}" fill="${C.stock}" stroke="${C.strong}" stroke-width="1.1"/>`,
  star: (x, y) => { const pts = []; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 - .1 + i * Math.PI / 5, r = i % 2 ? 2.8 : 6.2; pts.push(f2(x + r * Math.cos(a)) + "," + f2(y + .6 + r * Math.sin(a))); }
    return _halo(x, y) + `<polygon points="${pts.join(" ")}" fill="${C.strong}"/>`; },
  luck: (x, y) => { let o = _halo(x, y, 8.5); for (let i = 0; i < 4; i++) { const u = x - 3.75 + i * 2.5; o += K.line(u - .25, y + 5, u + .25, y - 5, { width: 1.3 }); } return o + K.line(x - 5.6, y + 3.6, x + 5.6, y - 3.6, { width: 1.3 }); },
  pouch: (x, y) => _halo(x, y) + `<path d="M${x - 4.5} ${y + 4.5} Q ${x - 5.5} ${y - 1}, ${x - 2} ${y - 2.5} L ${x - 3} ${y - 5} L ${x + 3} ${y - 5} L ${x + 2} ${y - 2.5} Q ${x + 5.5} ${y - 1}, ${x + 4.5} ${y + 4.5} Z" fill="${C.strong}"/>`,
  campfire: (x, y) => _halo(x, y) + K.line(x - 5, y + 5, x + 5, y + 2.4, { width: 1.8 }) + K.line(x - 5, y + 2.4, x + 5, y + 5, { width: 1.8 })
    + `<path d="M${x} ${y + 2.6} C ${x - 4.4} ${y + .6}, ${x - 2.6} ${y - 3.6}, ${x + .2} ${y - 7} C ${x + .8} ${y - 3.6}, ${x + 4.4} ${y - 1.4}, ${x} ${y + 2.6} Z" fill="${C.strong}"/><path d="M${x} ${y + 1.4} C ${x - 1.4} ${y}, ${x - .6} ${y - 1.8}, ${x + .2} ${y - 3}" fill="none" stroke="${C.stock}" stroke-width=".9"/>`,
  door: (x, y) => _halo(x, y) + `<path d="M${x - 4} ${y + 5} V ${y - 1} A 4 4 0 0 1 ${x + 4} ${y - 1} V ${y + 5} Z" fill="${C.strong}"/>`,
  pin: (x, y, n = 14) => `<circle cx="${x}" cy="${y}" r="8.5" fill="${C.stock}"/><circle cx="${x}" cy="${y}" r="7" fill="#7a1d12"/><text x="${x}" y="${y + 3.2}" text-anchor="middle" font-family="Marcellus, Georgia, serif" font-size="9" fill="#f3e6c6">${n}</text>`,
  dot: (x, y) => _halo(x, y, 6) + `<circle cx="${x}" cy="${y}" r="3" fill="${C.strong}"/>`,
};

// ---------------------------------------------------------------- what a proposal registers (the DESIGN block calls these)
const PROPOSAL = { name: "untitled", feature: "", date: "" };
const VARIANTS = [];
/** proposal({ name, feature, date }): name keys the saved review. */
function proposal(p) { Object.assign(PROPOSAL, p || {}); }
/** variant({ id, label, sizes: { S, M, L, XL }, mark }); anything else (order, smaller, wants, …) is ignored. */
function variant(v) {
  if (!v || !v.id || !v.sizes) { oops("variant", "needs at least { id, sizes }"); return; }
  if (VARIANTS.some(o => o.id === v.id)) { oops("variant " + v.id, "id used twice"); return; }
  VARIANTS.push({ id: String(v.id), label: v.label || String(v.id), sizes: v.sizes, mark: v.mark });
}
function render(v, size, w) {
  const fn = v.sizes[size]; if (!fn) return null;
  try { return fn({ w, band: size }, { K, seed: `variant:${v.id}:${size}`, size, flat: VIEW.flat }) || null; }
  catch (e) { oops(`variant ${v.id} ${size}`, e); return null; }
}
function markSVG(v) {
  try { return `<svg width="${40 * VIEW.zoom * 2}" height="${40 * VIEW.zoom * 2}" viewBox="-20 -20 40 40">${_halo(0, 0)}${v.mark(K)}</svg>`; }
  catch (e) { oops(`variant ${v.id} mark`, e); return ""; }
}

// ---------------------------------------------------------------- review: picks and comments, saved per proposal
const STORE = () => "sd-proposal:" + PROPOSAL.name;
let STATE = { picks: {}, comments: {}, labels: {}, view: null };
const LABELS = {};
function load() { try { const s = JSON.parse(localStorage.getItem(STORE()) || "null"); if (s) STATE = Object.assign(STATE, s); } catch (e) {}
  if (STATE.view) Object.assign(VIEW, STATE.view);
  if (location.hash === "#flat") VIEW.flat = true; }
function save() { STATE.view = VIEW; try { localStorage.setItem(STORE(), JSON.stringify(STATE)); } catch (e) {} }
function rv(key, what, pick) {
  LABELS[key] = what;
  const c = STATE.comments[key] || "", on = !!STATE.picks[key];
  return `<span class="rv" data-k="${esc(key)}">${pick ? `<button type="button" class="rv-pick${on ? " on" : ""}">${on ? "picked" : "pick"}</button>` : ""}`
    + `<button type="button" class="rv-c${c ? " has" : ""}">${c ? "comment" : "+ comment"}</button><textarea class="rv-t" rows="2"${c ? "" : " hidden"} placeholder="${esc(what)}">${esc(c)}</textarea></span>`;
}
document.addEventListener("click", e => {
  const b = e.target.closest(".rv button"); if (!b) return;
  const box = b.closest(".rv"), key = box.dataset.k;
  if (b.classList.contains("rv-pick")) {
    if (STATE.picks[key]) delete STATE.picks[key]; else { STATE.picks[key] = true; STATE.labels[key] = LABELS[key]; }
    b.classList.toggle("on", !!STATE.picks[key]); b.textContent = STATE.picks[key] ? "picked" : "pick"; save();
  } else { const t = box.querySelector("textarea"); t.hidden = !t.hidden; if (!t.hidden) t.focus(); }
});
document.addEventListener("input", e => {
  const t = e.target; if (!t.matches(".rv-t")) return;
  const key = t.closest(".rv").dataset.k;
  if (t.value.trim()) { STATE.comments[key] = t.value; STATE.labels[key] = LABELS[key]; } else delete STATE.comments[key];
  const c = t.closest(".rv").querySelector(".rv-c"); c.classList.toggle("has", !!STATE.comments[key]); c.textContent = STATE.comments[key] ? "comment" : "+ comment"; save();
});
function handover() {
  const P = PROPOSAL, label = k => STATE.labels[k] || LABELS[k] || k, keys = o => Object.keys(o).sort((a, b) => (a === "all") - (b === "all") || a.localeCompare(b));
  const out = [`# Handover: ${P.name}${P.feature ? ` (${P.feature})` : ""}${P.date ? `, ${P.date}` : ""}`, "", "## Picks"];
  const picks = keys(STATE.picks); out.push(...(picks.length ? picks.map(k => `- ${label(k)}`) : ["- none"]));
  out.push("", "## Comments");
  const cs = keys(STATE.comments); out.push(...(cs.length ? cs.map(k => `- **${label(k)}**: ${STATE.comments[k].trim().replace(/\n/g, "\n  ")}`) : ["- none"]));
  return out.join("\n") + "\n";
}
function copyHandover(btn) {
  const text = handover(), done = () => { btn.textContent = "Copied"; setTimeout(() => btn.textContent = "Copy handover", 1500); };
  const fallback = () => { const d = document.getElementById("copied"), t = d.querySelector("textarea"); t.value = text; d.style.display = "flex"; t.select(); try { if (document.execCommand("copy")) done(); } catch (e) {} };
  if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback); else fallback();
}

// ---------------------------------------------------------------- the board, the bar
function buildBoard() {
  let h = "";
  for (const v of VARIANTS) {
    h += `<div class="v"><h3>${esc(v.id)} · ${esc(v.label)} ${rv("v:" + v.id, `${v.id} (${v.label})`, true)}</h3><div class="cells">`;
    for (const [s, w] of SIZES) {
      if (!v.sizes[s]) continue;
      const r = render(v, s, w);
      h += `<div class="fig"><div class="lab"><b>${s}</b><small>${w} px${r ? ` · ${Math.round(r.w)} × ${Math.round(r.h)}` : ""}</small>${rv(`v:${v.id}/${s}`, `${v.id} · ${s}`, true)}</div>`
        + `<div class="sheet"><div style="zoom:${VIEW.zoom}" class="cell"><div class="wr" style="width:${w}px"></div>${r ? r.html : `<div class="none">does not go in ${w} px</div>`}</div></div></div>`;
    }
    if (v.mark) h += `<div class="fig"><div class="lab"><b>mark</b><small>2×</small></div><div class="sheet mk">${markSVG(v)}</div></div>`;
    h += `</div></div>`;
  }
  document.getElementById("board").innerHTML = h;
  document.getElementById("whole").innerHTML = `The whole proposal ${rv("all", "the whole proposal", false)}`;
  document.getElementById("warn").textContent = VARIANTS.length === 3 ? "" : `${VARIANTS.length} variant${VARIANTS.length === 1 ? "" : "s"}: a proposal shows exactly three (A, B, C).`;
}
function buildBar() {
  const chip = (on, attr, text, cls) => `<button type="button" class="chip${on ? " on" : ""}${cls ? " " + cls : ""}" ${attr}>${text}</button>`;
  document.getElementById("bar").innerHTML = `<span class="who">${esc(PROPOSAL.name)}<small>${esc([PROPOSAL.feature, PROPOSAL.date].filter(Boolean).join(" · "))}</small></span>
    <span class="grp">${chip(VIEW.flat, 'data-v="flat"', "flat paper")}</span>
    <span class="grp"><span>zoom</span>${[1, 2].map(z => chip(VIEW.zoom === z, `data-zoom="${z}"`, z + "×")).join("")}</span>
    <span class="act">${chip(false, 'data-act="copy"', "Copy handover", "main")}${chip(false, 'data-act="clear"', "Clear")}</span>`;
}
function buildAll() {
  document.body.classList.toggle("flat", VIEW.flat);
  document.title = `Social Diary · ${PROPOSAL.name}${PROPOSAL.feature ? " · " + PROPOSAL.feature : ""}`;
  for (const [name, fn] of [["bar", buildBar], ["board", buildBoard]]) { try { fn(); } catch (e) { oops(name, e); } }
  const er = document.getElementById("errors"); er.style.display = ERRORS.length ? "block" : "none"; er.textContent = [...new Set(ERRORS)].join("\n");
}

// ---------------------------------------------------------------- boot: the page's frame, then the DESIGN block, then the board
function boot() {
  document.body.insertAdjacentHTML("afterbegin", `<div id="bar"></div><div id="errors"></div><div id="warn"></div><div id="whole"></div><div id="board"></div>
    <div id="copied"><div>Copy this (the clipboard was not reachable):</div><textarea readonly></textarea><div><button class="chip" type="button" id="copiedClose">Close</button></div></div>`);
  document.getElementById("copiedClose").addEventListener("click", () => document.getElementById("copied").style.display = "none");
  document.getElementById("bar").addEventListener("click", e => {
    const b = e.target.closest("button"); if (!b) return; const d = b.dataset;
    if (d.act === "copy") return copyHandover(b);
    if (d.act === "clear") { if (confirm("Clear every pick and comment of this proposal?")) { STATE.picks = {}; STATE.comments = {}; STATE.labels = {}; save(); buildAll(); } return; }
    if (d.v) VIEW[d.v] = !VIEW[d.v];
    if (d.zoom) VIEW.zoom = +d.zoom;
    save(); buildAll();
  });
  const design = document.getElementById("design");
  if (!design) oops("design", "no <script type=\"text/x-design\" id=\"design\"> in the page");
  else { const s = document.createElement("script"); s.textContent = design.textContent; document.body.appendChild(s); }
  load();
  const fonts = document.fonts ? Promise.all([document.fonts.load("italic 16px SDHand"), document.fonts.load("13px Marcellus"), document.fonts.load("italic 16px Neuton")]).catch(() => {}).then(() => document.fonts.ready) : Promise.resolve();
  fonts.then(buildAll, buildAll);
}
Object.assign(window, { K, proposal, variant });
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();
})();
