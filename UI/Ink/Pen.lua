-- The pen: the kit every inked line on the addon's paper is drawn with.
-- A line is resampled (and smoothed, Chaikin), mitred at its joints and
-- stroked into quads that share their edges; a fountain pen's nib sets each
-- vertex's share of the width, its flow the ink a curve draws, and a sharp
-- turn leaves a bead. Random is the seeded run of numbers the cards' paper
-- falls by. Pure arithmetic over plain tables, no client calls.
--
-- Drawn with it: the ink trail on Your Diary's plates (the road model, its
-- tuning and Build: UI/Ink/Trail.lua, loaded after this file), the page's
-- pencil leaders (UI/Journey/Leaders.lua) and the lucky card's strike
-- (Features/Hunts/LuckyCard.lua). Its table is ns.UI.Pen; the trail's
-- model is ns.UI.InkTrail. PEN is the very table /sd pen
-- (Dev/JourneyDebug.lua) changes in place, so it is made here once and
-- never replaced.

local addonName, ns = ...

local Pen = {}
ns.UI.Pen = Pen

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------

-- The pen the road is drawn with: a fountain pen with a broad nib, held one
-- way by one writer, so the line varies as a real one does with the angle
-- and speed of the hand. The player's own pace (ROAD's pressure) still
-- sets the whole line's weight; the pen only shapes it, and a map's mean
-- width stays about the same.
--   nib    the nib's edge lies at `angle` degrees on the sheet (up and to
--          the right, a right-hander's stub): moving along it the line is
--          `thin` of its width, moving across it (down and to the right)
--          `thick`, |sin| between. A curve swells and thins as it turns; a
--          straight keeps the one width its heading gives it
--   flow   the hand slows in a curve (the two-thirds power law), so more
--          ink flows: the curvature over `window` px either side sets a
--          load (1 + curvature * `radius`) ^ `power`, at most `cap`, 1 on a
--          straight. Width times load ^ `widthGain` and `straight` (a long
--          straight reads a touch leaner, so the mean stays near 1); alpha
--          times 1 + `alphaGain` * (load - 1). The load follows that over
--          `lag` px in the order the road was walked, so ink built up in a
--          curve carries into the straight after it and the line quietly
--          shows which way you went; a pen set down fresh (a road that
--          starts at no stop) starts `loaded`
--   bead   where the road turns more than `turn` degrees within `arc` px
--          (on the smoothed path), the pen paused an instant: a bead at the
--          corner `size` times the line's width across, at its alpha. A
--          pen set down fresh leaves one `start` times its width. Never on
--          a gentle curve; beads count against the dots' cap
--   width  the line's width is kept within width[1]..width[2] px: a thin
--          stroke narrows but never vanishes (only the free ends lift
--          below it). The nib changes width only, never the ink's alpha
local PEN = {
    nib = { angle = 40, thin = 0.55, thick = 1.25 },
    flow = { window = 6, radius = 10, power = 1 / 3, cap = 1.45, straight = 0.92, widthGain = 1, alphaGain = 0.35,
        lag = 10, loaded = 1.2 },
    bead = { turn = 55, arc = 5, size = 1.35, start = 1.3 },
    width = { 0.6, 3.0 },
}

Pen.PEN = PEN

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------

local floor, sqrt, abs, sin, exp, pi = math.floor, math.sqrt, math.abs, math.sin, math.exp, math.pi
local atan2 = math.atan2 or math.atan
local min, max = math.min, math.max

-- v kept within lo..hi; the trail's too (UI/Ink/Trail.lua takes it from
-- here as it loads).
local function Clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
Pen.Clamp = Clamp

-- A seeded run of numbers in 0..1 (Park-Miller): the same trail every time.
function Pen.Random(seed)
    local state = (floor(seed) % 2147483646) + 1
    return function()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
end

--------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------

-- Chaikin's corner cutting, `times` over: each corner cut a quarter of the
-- way along both its sides, the ends kept. Points are flat { x, y, ... }.
function Pen.Chaikin(pts, times)
    for _ = 1, times do
        local n = #pts / 2
        if n < 3 then return pts end
        local out = { pts[1], pts[2] }
        for i = 1, n - 1 do
            local x1, y1, x2, y2 = pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], pts[2 * i + 2]
            out[#out + 1] = 0.75 * x1 + 0.25 * x2
            out[#out + 1] = 0.75 * y1 + 0.25 * y2
            out[#out + 1] = 0.25 * x1 + 0.75 * x2
            out[#out + 1] = 0.25 * y1 + 0.75 * y2
        end
        out[#out + 1], out[#out + 2] = pts[2 * n - 1], pts[2 * n]
        pts = out
    end
    return pts
end

-- The polyline at a point every `step` px of its length, { { x, y, s }, ... }
-- (s the length so far), its ends kept exactly; and its whole length.
function Pen.Resample(pts, step)
    local n = #pts / 2
    if n < 2 then return {}, 0 end
    local out = { { x = pts[1], y = pts[2], s = 0 } }
    local total, nextAt = 0, step
    for i = 1, n - 1 do
        local x1, y1, x2, y2 = pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], pts[2 * i + 2]
        local len = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        while len > 0 and nextAt <= total + len do
            local t = (nextAt - total) / len
            out[#out + 1] = { x = x1 + (x2 - x1) * t, y = y1 + (y2 - y1) * t, s = nextAt }
            nextAt = nextAt + step
        end
        total = total + len
    end
    local last = out[#out]
    if total - last.s > step * 0.35 then
        out[#out + 1] = { x = pts[2 * n - 1], y = pts[2 * n], s = total }
    elseif #out > 1 then
        last.x, last.y, last.s = pts[2 * n - 1], pts[2 * n], total
    end
    return out, total
end

--------------------------------------------------------------------------
-- Primitives
--------------------------------------------------------------------------
--
-- quad  { k = "q", layer, x1, y1 .. x4, y4, r, g, b, a }: four points in
--       polygon order, upper left, upper right, lower right, lower left (a
--       stroke's left rail is the texture's top edge), as K.Quad takes them
-- disc  { k = "d", layer, x, y, rx, ry, th, r, g, b, a }: the circle art 2rx
--       by 2ry about x, y, turned th (y down: placed turned -th)
-- A pool's own carry `of`, the pool, for the checks.

local function Quad(out, layer, x1, y1, x2, y2, x3, y3, x4, y4, c, a, of)
    out[#out + 1] = { k = "q", layer = layer, x1 = x1, y1 = y1, x2 = x2, y2 = y2, x3 = x3, y3 = y3,
        x4 = x4, y4 = y4, r = c[1], g = c[2], b = c[3], a = a, of = of }
end

local function Disc(out, layer, x, y, rx, ry, th, c, a, of)
    out[#out + 1] = { k = "d", layer = layer, x = x, y = y, rx = rx, ry = ry, th = th or 0,
        r = c[1], g = c[2], b = c[3], a = a, of = of }
end

-- The trail draws its own primitives with these (UI/Ink/Trail.lua).
Pen.Quad, Pen.Disc = Quad, Disc

-- Each vertex's mitre: the unit normal between its two pieces (left of the
-- way it runs, y down) and how far to stretch it.
function Pen.Mitres(P)
    -- At most ROAD's `miter` (UI/Ink/Trail.lua), read when drawn: the
    -- trail's tuning loads after this file.
    local miter = ns.UI.InkTrail.ROAD.miter
    local n, m = #P, {}
    local function Normal(i)
        local dx, dy = P[i + 1].x - P[i].x, P[i + 1].y - P[i].y
        local len = sqrt(dx * dx + dy * dy)
        if len < 1e-6 then return 0, -1 end
        return dy / len, -dx / len
    end
    for i = 1, n do
        local nx, ny, k
        if i == 1 then
            nx, ny = Normal(1)
            k = 1
        elseif i == n then
            nx, ny = Normal(n - 1)
            k = 1
        else
            local ax, ay = Normal(i - 1)
            local bx, by = Normal(i)
            nx, ny = ax + bx, ay + by
            local len = sqrt(nx * nx + ny * ny)
            if len < 1e-6 then
                nx, ny, k = bx, by, 1
            else
                nx, ny = nx / len, ny / len
                k = min(1 / max(nx * bx + ny * by, 1e-3), miter)
            end
        end
        m[i] = { nx = nx, ny = ny, k = k }
    end
    return m
end

-- A stroke along P: piece i joins vertex i to i + 1, its rails at offset
-- off(i) +- half(i) along the mitres, so neighbours share their edge
-- exactly; its alpha the mean of its ends'. `skip(i)` leaves a piece out
-- (inside a pool); at most `budget` pieces. Returns the pieces made.
function Pen.Stroke(out, layer, P, M, half, off, alpha, colour, skip, budget)
    local made = 0
    local function Rail(i, side)
        local m, o = M[i], off(i) + side * half(i)
        return P[i].x + m.nx * m.k * o, P[i].y + m.ny * m.k * o
    end
    for i = 1, #P - 1 do
        if budget and made >= budget then break end
        if not (skip and skip(i)) then
            local a = (alpha(i) + alpha(i + 1)) / 2
            if a > 0.01 then
                local lx1, ly1 = Rail(i, 1)
                local lx2, ly2 = Rail(i + 1, 1)
                local rx2, ry2 = Rail(i + 1, -1)
                local rx1, ry1 = Rail(i, -1)
                Quad(out, layer, lx1, ly1, lx2, ly2, rx2, ry2, rx1, ry1, colour, a)
                made = made + 1
            end
        end
    end
    return made
end

-- The point and unit normal at length s along P.
local function Along(P, s)
    local lo, hi = 1, #P
    while hi - lo > 1 do
        local mid = floor((lo + hi) / 2)
        if P[mid].s <= s then lo = mid else hi = mid end
    end
    local a, b = P[lo], P[hi]
    local span = b.s - a.s
    local t = span > 0 and Clamp((s - a.s) / span, 0, 1) or 0
    local dx, dy = b.x - a.x, b.y - a.y
    local len = sqrt(dx * dx + dy * dy)
    local nx, ny = 0, -1
    if len > 1e-6 then nx, ny = dy / len, -dx / len end
    return a.x + dx * t, a.y + dy * t, nx, ny
end

-- The trail's sprinkles walk the road with it too (UI/Ink/Trail.lua).
Pen.Along = Along

--------------------------------------------------------------------------
-- The pen: nib, flow and beads
--------------------------------------------------------------------------

-- The signed turn from heading h1 to h2, in -pi..pi.
local function Turn(h1, h2) return (h2 - h1 + pi) % (2 * pi) - pi end

-- The nib's share of the width moving along (dx, dy) on the sheet (y
-- down): thin along its edge, thick across it. `nib` another pen's
-- { angle, thin, thick } (the page's pencil leaders), PEN's by default.
function Pen.Nib(dx, dy, nib)
    local N = nib or PEN.nib
    if dx == 0 and dy == 0 then return 1 end
    return N.thin + (N.thick - N.thin) * abs(sin(atan2(-dy, dx) - math.rad(N.angle)))
end

-- The pen along a resampled road P, in the order it was walked: each
-- vertex's nib share of the width, and its ink load (1 on a straight,
-- more in a curve, lagging behind it). `fresh` for a pen set down at the
-- road's start rather than carried out of a stop.
function Pen.Pen(P, fresh)
    local F = PEN.flow
    local n = #P
    local total = P[n].s
    local nib, load = {}, {}
    local L
    for i = 1, n do
        local a, b = P[max(i - 1, 1)], P[min(i + 1, n)]
        nib[i] = Pen.Nib(b.x - a.x, b.y - a.y)
        -- The curvature: the turn between the chords either side, over
        -- `window` px each way, against the arc between their middles.
        local s = P[i].s
        local s0, s1 = max(0, s - F.window), min(total, s + F.window)
        local curve = 0
        if s - s0 > 1 and s1 - s > 1 then
            local x0, y0 = Along(P, s0)
            local x1, y1 = Along(P, s1)
            local x, y = P[i].x, P[i].y
            curve = abs(Turn(atan2(y - y0, x - x0), atan2(y1 - y, x1 - x))) / ((s1 - s0) / 2)
        end
        local target = min(F.cap, (1 + curve * F.radius) ^ F.power)
        if i == 1 then
            L = fresh and max(F.loaded, target) or target
        else
            L = L + (target - L) * (1 - exp(-(P[i].s - P[i - 1].s) / F.lag))
        end
        load[i] = L
    end
    return nib, load
end

-- Where the smoothed road `C` (flat points) turns sharply: { { x, y, s } }
-- at each corner's apex, one a corner, the turn summed over `arc` px.
function Pen.Beads(C)
    local B = PEN.bead
    local n = #C / 2
    local beads = {}
    if n < 3 then return beads end
    local S, turn = { 0 }, { 0 }
    for k = 2, n do
        S[k] = S[k - 1] + sqrt((C[2 * k - 1] - C[2 * k - 3]) ^ 2 + (C[2 * k] - C[2 * k - 2]) ^ 2)
    end
    for k = 2, n - 1 do
        local dx1, dy1 = C[2 * k - 1] - C[2 * k - 3], C[2 * k] - C[2 * k - 2]
        local dx2, dy2 = C[2 * k + 1] - C[2 * k - 1], C[2 * k + 2] - C[2 * k]
        local ok = (dx1 ~= 0 or dy1 ~= 0) and (dx2 ~= 0 or dy2 ~= 0)
        turn[k] = ok and Turn(atan2(dy1, dx1), atan2(dy2, dx2)) or 0
    end
    turn[n] = 0
    -- Each vertex's turn summed over the arc round it.
    local half, sharp = B.arc / 2, math.rad(B.turn)
    local sum = {}
    for k = 1, n do
        local t = turn[k]
        local j = k - 1
        while j >= 1 and S[k] - S[j] <= half do t, j = t + turn[j], j - 1 end
        j = k + 1
        while j <= n and S[j] - S[k] <= half do t, j = t + turn[j], j + 1 end
        sum[k] = abs(t)
    end
    -- One bead a corner: the sharpest vertex of each run past the turn.
    local k = 1
    while k <= n do
        if sum[k] >= sharp then
            local best = k
            while k + 1 <= n and sum[k + 1] >= sharp do
                k = k + 1
                if sum[k] > sum[best] then best = k end
            end
            local last = beads[#beads]
            if not last or S[best] - last.s > B.arc then
                beads[#beads + 1] = { x = C[2 * best - 1], y = C[2 * best], s = S[best] }
            end
        end
        k = k + 1
    end
    return beads
end
