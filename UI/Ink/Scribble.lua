-- The diary's hand with the pen, for marks that need no language: a strike
-- through words, an underline, a cross, a ring round a sum, an arrow, and
-- a thread joining stops down a column and over into the next. Each is a
-- seeded point-maker (the same seed, the same hand, every time it opens)
-- giving a path of points { { x, y }, ... } on whatever surface it is for,
-- x right and y down; Pen strokes a path into the route's pen's quads (UI/Ink/Pen.lua:
-- resampled by the maker, mitred, each vertex its nib's share of the
-- width, tapered where the pen lands and lifts), and Draw lays them on a
-- surface: each quad's corners where the paper takes them (a loose sheet's
-- K.Quad), or, where corners cannot move, a flat stroke turned (Flat).
--
-- The strike and the underline were the lucky card's (Features/Hunts/
-- LuckyCard.lua, 13 Nov: "a single strikethrough using our pen tech"),
-- moved here unchanged with their looks (STRIKE, UNDER) and its Pen and
-- Flat when a second surface wanted them (a sheet among the plates, the
-- city-trips proposal's hook 5, 24 Nov 2026): the lucky card calls these
-- now, and draws exactly what it drew.
--
--   Scribble.Strike(seed, x0, mid, w, size)  through words from x0, `w` wide,
--                    their row's middle at `mid`, type `size` px → path, and
--                    the figures' half cap band (the lucky card's tests)
--   Scribble.Underline(seed, x0, x1, base)   under a word, its baseline at
--                    `base` → path
--   Scribble.Cross(seed, cx, cy, r)          an X, two strokes → { path, path }
--   Scribble.Ring(seed, cx, cy, rx, ry)      round a word or a sum, a little
--                    more than once round, not closed → path
--   Scribble.Arrow(seed, x1, y1, x2, y2)     from one to the other, its head
--                    two flicks at x2, y2 → { shaft, flick, flick }
--   Scribble.Thread(seed, runs)              down each column and over into
--                    the next: `runs` = { { x, y0, y1 }, ... } in order, a
--                    line down each from y0 to y1, and between one column's
--                    foot and the next one's head a bow over the gap (the
--                    fold of a folded leaf) → { path, ... }
--   Scribble.Pen(path, look)                 the path's quads (the pen's
--                    primitives: x1..y4 and r, g, b, a), in look's ink
--   Scribble.Flat(q)                         a quad laid flat where corners
--                    cannot move: its middle, length, width and angle (y down)
--   Scribble.Draw(kit, paths, look)          paths (one, or a list of them)
--                    stroked with the pen and laid on a surface; `kit` =
--                    { Next() → a texture, Quad(texture, x1, y1, ..., y4) →
--                    false where corners cannot move, Place(texture, x, y, w,
--                    h, turn) from its top left }. Returns how many quads
--   Scribble.STRIKE, UNDER, CROSS, RING, ARROW, THREAD   the looks
--
-- Every look is a pen: `width` px before the nib's share, `nib` (Pen.Nib's
-- angle, thin, thick), `alpha`, `taper` (`from` of the width where it lands,
-- full `over` px on; to `end` over its last `off` px), `most` quads at most,
-- and `ink` (a colour; INK_STRONG where it has none). The makers' own
-- numbers are on the looks too, each commented.

local addonName, ns = ...

local Style = ns.Style

local Scribble = {}
ns.UI.Scribble = Scribble

--------------------------------------------------------------------------
-- The looks
--------------------------------------------------------------------------

-- The strike through printed words: a single pass of the route's
-- pen (UI/Ink/Pen.lua: mitred, the nib's share, stroked into quads that
-- share their edges), left to right, in ink at `alpha` (a hair of paper
-- shows through, as ink does; the readability comes from the shape, not
-- the alpha), `width` px wide before the nib's share (about 1.1 px on the
-- page: a little lighter than the underline, as it lies on type). A
-- quadratic, as the underline is: from `lead` px before the words to `tail`
-- past them, `low` of the type's size under the row's middle (toward the
-- small letters' middle, so it crosses the figures near theirs), sagging
-- `sag` px in its middle, tilted `slant` degrees (mostly rising, as a hand
-- strikes) but never more than `keep` of the figures' half cap band (`cap`
-- of the size) at either end, so it stays inside the words; each end given
-- or taken `jitter`; a piece every `step` px, at most `most`; tapered from
-- `from` of its width over its first `over` px and to `end` over its last
-- `off` px. (Until 13 Nov a scribble: one pen line of tall zigzag strokes
-- over the words. In the client, the user: too strong over the words,
-- "let's replace it with a single strikethrough using our pen tech".
-- `lead` and `tail` are the scribble's, so nothing on the card moved.)
local STRIKE = { width = 1.15, nib = { angle = 40, thin = 0.6, thick = 1.2 }, alpha = 0.92, cap = 0.70, low = 0.06,
    lead = { 2, 4 }, tail = { 2, 4.5 }, slant = { -2.4, 0.4 }, keep = 0.5, sag = 0.4, jitter = 0.35, step = 4,
    taper = { from = 0.8, over = 3, ["end"] = 0.4, off = 7 }, most = 28 }
-- The underline under "dropped" (at S, the count): the same pen, a
-- quadratic from `lead` px before the word to `run` past it, `drop` px under
-- the baseline (through the p's tails, as a hand's underline runs), sagging
-- `sag` in its middle and rising `rise` toward its end as the hand flicks
-- off; each end given or taken `jitter`; a piece every `step` px, at most
-- `most`; tapered from `from` over `over` px and to `end` over its last
-- `off`.
local UNDER = { width = 1.35, nib = STRIKE.nib, drop = 3.4, sag = 0.5, rise = 1.3, lead = 1.5, run = 4,
    jitter = 0.4, step = 3.5, taper = { from = 0.85, over = 3, ["end"] = 0.4, off = 7 }, most = 16 }
-- A cross (what came back, a thing undone): two strokes, the first from the
-- upper left down, the second from the upper right, each `reach` of the
-- radius past the middle either way, its ends given or taken `jitter` px
-- (a quick hand's X is never square), bowed `bow` px; the strike's pen a
-- little heavier, as a mark rather than a line through type.
local CROSS = { width = 1.3, nib = STRIKE.nib, alpha = 0.92, reach = 1, jitter = 0.6, bow = 0.4, step = 2.5,
    taper = { from = 0.7, over = 2, ["end"] = 0.5, off = 3 }, most = 10 }
-- A ring round a word or a sum, as a hand rings a figure to keep it: an
-- ellipse started at `start` (radians from the right, y down: the upper
-- right, where a pen comes in), going round `turns` times (a little more
-- than once, so its ends cross and part), its radii given or taken `uneven`
-- of themselves and wandering `wander` px as it goes; a piece every `step`
-- px, at most `most`.
local RING = { width = 1.2, nib = STRIKE.nib, alpha = 0.9, start = -0.9, turns = 1.12, uneven = 0.06, wander = 0.7,
    step = 3, taper = { from = 0.6, over = 4, ["end"] = 0.35, off = 6 }, most = 40 }
-- An arrow, between a craft's old rank and its new: the shaft a quadratic
-- bowed `bow` of its length to its left, its head two flicks `head` px
-- long, `spread` radians either side of the shaft's end, each a straight
-- stroke a little uneven (`jitter`).
local ARROW = { width = 1.2, nib = STRIKE.nib, alpha = 0.92, bow = 0.08, head = 4.5, spread = 0.5, jitter = 0.4,
    step = 3, taper = { from = 0.7, over = 2, ["end"] = 0.6, off = 3 }, most = 16 }
-- A thread joining stops: a fine line down each column, wavering `waver` px
-- side to side about every `every` px (a hand drawing down a page, never a
-- ruler), and between one column's foot and the next one's head a bow over
-- the gap, rising `arc` px over the higher end (a line taken over a fold);
-- lighter than writing (`alpha`), as it is the page's furniture.
local THREAD = { width = 0.9, nib = { angle = 40, thin = 0.8, thick = 1.1 }, alpha = 0.6, waver = 0.8, every = 22,
    arc = 10, step = 4, taper = { from = 0.5, over = 6, ["end"] = 0.5, off = 6 }, most = 60 }

Scribble.STRIKE, Scribble.UNDER, Scribble.CROSS, Scribble.RING, Scribble.ARROW, Scribble.THREAD =
    STRIKE, UNDER, CROSS, RING, ARROW, THREAD

--------------------------------------------------------------------------
-- The makers
--------------------------------------------------------------------------

-- A number from a string, the same every time (the strip's,
-- UI/Paper/Surface.lua), and a stream of them.
local Seed = ns.UI.Surface.Seed

local function Random(key)
    local rand = ns.UI.Pen.Random(Seed(key))
    return function(a, b) return a + (b - a) * rand() end, rand
end

-- The strike through printed words from x0, `w` wide, their row's middle
-- at `mid`, type `size` px, seeded by `seed` (a string): its points
-- { { x, y }, ... }, left to right (STRIKE); and, for the tests, the
-- figures' half cap band.
function Scribble.Strike(seed, x0, mid, w, size)
    local U = Random(seed)
    local S = STRIKE
    local half = S.cap * size / 2
    local ax, zx = x0 - U(S.lead[1], S.lead[2]), x0 + w + U(S.tail[1], S.tail[2])
    local y = mid + S.low * size
    -- A hand is never level: tilted about its middle, kept inside the words.
    local most = S.keep * half
    local tilt = math.max(-most, math.min(most, math.tan(math.rad(U(S.slant[1], S.slant[2]))) * (zx - ax) / 2))
    local ay, zy = y - tilt + U(-S.jitter, S.jitter), y + tilt + U(-S.jitter, S.jitter)
    local cx, cy = (ax + zx) / 2, (ay + zy) / 2 + 2 * S.sag
    local len = math.sqrt((zx - ax) ^ 2 + (zy - ay) ^ 2)
    local n = math.min(S.most, math.max(3, math.ceil(len / S.step)))
    local P = {}
    for i = 0, n do
        local t = i / n
        local u = 1 - t
        P[#P + 1] = { x = u * u * ax + 2 * u * t * cx + t * t * zx, y = u * u * ay + 2 * u * t * cy + t * t * zy }
    end
    return P, half
end

-- The underline under a word from x0 to x1, its baseline at `base`: its
-- points (UNDER), seeded by `seed`.
function Scribble.Underline(seed, x0, x1, base)
    local U = Random(seed)
    local D = UNDER
    local ax, ay = x0 - D.lead, base + D.drop + U(-D.jitter, D.jitter) + 0.3
    local zx, zy = x1 + D.run, base + D.drop - D.rise + U(-D.jitter, D.jitter)
    local cx, cy = (ax + zx) / 2, (ay + zy) / 2 + 2 * D.sag
    local len = math.sqrt((zx - ax) ^ 2 + (zy - ay) ^ 2)
    local n = math.min(D.most, math.max(3, math.ceil(len / D.step)))
    local P = {}
    for i = 0, n do
        local t = i / n
        local u = 1 - t
        P[#P + 1] = { x = u * u * ax + 2 * u * t * cx + t * t * zx, y = u * u * ay + 2 * u * t * cy + t * t * zy }
    end
    return P
end

-- A quadratic from (ax, ay) bent toward (cx, cy) to (zx, zy), a piece
-- every `step` px, between 2 and `most` pieces.
local function Curve(ax, ay, cx, cy, zx, zy, step, most)
    local len = math.sqrt((zx - ax) ^ 2 + (zy - ay) ^ 2)
    local n = math.min(most, math.max(2, math.ceil(len / step)))
    local P = {}
    for i = 0, n do
        local t = i / n
        local u = 1 - t
        P[#P + 1] = { x = u * u * ax + 2 * u * t * cx + t * t * zx, y = u * u * ay + 2 * u * t * cy + t * t * zy }
    end
    return P
end

-- A stroke from a to z, bowed `bow` px to its left (y down).
local function Bowed(ax, ay, zx, zy, bow, look)
    local dx, dy = zx - ax, zy - ay
    local len = math.max(math.sqrt(dx * dx + dy * dy), 0.001)
    local cx, cy = (ax + zx) / 2 + dy / len * bow, (ay + zy) / 2 - dx / len * bow
    return Curve(ax, ay, cx, cy, zx, zy, look.step, look.most)
end

function Scribble.Cross(seed, cx, cy, r)
    local U = Random(seed)
    local C = CROSS
    local d = r * C.reach
    local function J() return U(-C.jitter, C.jitter) end
    return { Bowed(cx - d + J(), cy - d + J(), cx + d + J(), cy + d + J(), C.bow, C),
        Bowed(cx + d + J(), cy - d + J(), cx - d + J(), cy + d + J(), -C.bow, C) }
end

function Scribble.Ring(seed, cx, cy, rx, ry)
    local U = Random(seed)
    local R = RING
    rx, ry = rx * (1 + U(-R.uneven, R.uneven)), ry * (1 + U(-R.uneven, R.uneven))
    local sweep = 2 * math.pi * R.turns
    local around = sweep * (rx + ry) / 2
    local n = math.min(R.most, math.max(8, math.ceil(around / R.step)))
    local P = {}
    local w1, w2 = U(0, 2 * math.pi), U(0, 2 * math.pi)
    for i = 0, n do
        local t = i / n
        local a = R.start + sweep * t
        -- (it wanders as it goes, and comes round a little wide or tight)
        local grow = R.wander * math.sin(w1 + 3 * a) + R.wander * t
        P[#P + 1] = { x = cx + (rx + grow) * math.cos(a), y = cy + (ry + grow * ry / math.max(rx, 0.001)) * math.sin(a)
            + R.wander * 0.5 * math.sin(w2 + 2 * a) }
    end
    return P
end

function Scribble.Arrow(seed, x1, y1, x2, y2)
    local U = Random(seed)
    local A = ARROW
    local dx, dy = x2 - x1, y2 - y1
    local len = math.max(math.sqrt(dx * dx + dy * dy), 0.001)
    local shaft = Bowed(x1, y1, x2, y2, A.bow * len, A)
    -- The head: from the tip back along the shaft's last heading, either side.
    local last, before = shaft[#shaft], shaft[#shaft - 1]
    local back = math.atan2(before.y - last.y, before.x - last.x)
    local out = { shaft }
    for _, side in ipairs({ -1, 1 }) do
        local a = back + side * (A.spread + U(-0.08, 0.08))
        local h = A.head + U(-A.jitter, A.jitter)
        out[#out + 1] = Curve(last.x, last.y, last.x + math.cos(a) * h / 2, last.y + math.sin(a) * h / 2,
            last.x + math.cos(a) * h, last.y + math.sin(a) * h, A.step, 3)
    end
    return out
end

function Scribble.Thread(seed, runs)
    local U = Random(seed)
    local H = THREAD
    local out = {}
    for k, run in ipairs(runs) do
        local x, y0, y1 = run[1], run[2], run[3]
        if y1 > y0 then
            local n = math.min(H.most, math.max(2, math.ceil((y1 - y0) / H.step)))
            local phase, P = U(0, 2 * math.pi), {}
            for i = 0, n do
                local y = y0 + (y1 - y0) * i / n
                local edge = math.min(1, math.min(i, n - i) / 2)
                P[#P + 1] = { x = x + H.waver * edge * math.sin(phase + 2 * math.pi * (y - y0) / H.every), y = y }
            end
            out[#out + 1] = P
        end
        -- Over into the next column: from this foot to the next head,
        -- bowed up over the higher of the two.
        local nxt = runs[k + 1]
        if nxt then
            local ax, ay, zx, zy = x, y1, nxt[1], nxt[2]
            local cy = math.min(ay, zy) - H.arc
            out[#out + 1] = Curve(ax, ay, (ax + zx) / 2, cy, zx, zy, H.step, H.most)
        end
    end
    return out
end

--------------------------------------------------------------------------
-- The pen and the surface
--------------------------------------------------------------------------

-- `P` drawn with the pen (STRIKE's or UNDER's look): the quads, as
-- the pen's primitives (ns.UI.Pen), each vertex's half-width its nib's
-- share of the width, tapered where the pen lands and where it lifts.
function Scribble.Pen(P, look)
    local Pen = ns.UI.Pen
    local n = #P
    if n < 2 then return {} end
    P[1].s = 0
    for i = 2, n do P[i].s = P[i - 1].s + math.sqrt((P[i].x - P[i - 1].x) ^ 2 + (P[i].y - P[i - 1].y) ^ 2) end
    local total, T = P[n].s, look.taper
    local M = Pen.Mitres(P)
    local function Half(i)
        local a, b = P[math.max(i - 1, 1)], P[math.min(i + 1, n)]
        local t = math.min(1, T.from + (1 - T.from) * P[i].s / T.over)
        local left = total - P[i].s
        if left < T.off then t = t * (T["end"] + (1 - T["end"]) * left / T.off) end
        return look.width / 2 * Pen.Nib(b.x - a.x, b.y - a.y, look.nib) * t
    end
    local prims = {}
    Pen.Stroke(prims, 0, P, M, Half, function() return 0 end, function() return look.alpha or STRIKE.alpha end,
        look.ink or Style.INK_STRONG, nil, look.most)
    return prims
end

-- A piece of the pen laid flat where corners cannot move: from the middle
-- of its start to the middle of its end, as wide as it is on average.
-- Returns its middle, length, width and angle (y down).
function Scribble.Flat(q)
    local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
    local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
    local dx, dy = ex - sx, ey - sy
    local width = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2) + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
    return (sx + ex) / 2, (sy + ey) / 2, math.sqrt(dx * dx + dy * dy) + 0.3, math.max(width, 0.4), math.atan2(-dy, dx)
end

function Scribble.Draw(kit, paths, look)
    -- (one path, or a list of them)
    if paths[1] and paths[1].x then paths = { paths } end
    local n = 0
    for _, P in ipairs(paths) do
        for _, q in ipairs(Scribble.Pen(P, look)) do
            local texture = kit.Next()
            texture:SetColorTexture(q.r, q.g, q.b, q.a)
            if not kit.Quad(texture, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local mx, my, length, w, angle = Scribble.Flat(q)
                kit.Place(texture, mx - length / 2, my - w / 2, length, w, angle)
            end
            texture:Show()
            n = n + 1
        end
    end
    return n
end
