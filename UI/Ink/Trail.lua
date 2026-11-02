-- Your Diary's map plates (JRN-14, JRN-21): the ink trail's arithmetic. The road
-- and its stops are one trail of ink, as a pen would leave it following
-- you across the map, built from the only two things the sheet draws them
-- with (UI/Journey/Plate.lua puts them on the paper):
--   quad  a texture with its four corners moved (K.Quad), so a stroke is a
--         chain of trapezoids that share their edges: no gaps, no overlaps,
--         no beads of doubled ink at the joints
--   disc  the circle art (Style.Disc), placed and turned (K.Place): washes,
--         dabs, sprinkles and droplets
--
-- What it says:
--   the pen moves   a road is a line, and its pressure is your pace against
--                   the sheet's own brisk pace: a brisk ride a thin, dry line
--                   fading where the ink ran short (never broken into dashes:
--                   dashes are flights on this sheet), a slow walk with fights
--                   on the way a full, wet one with ink sprinkled either side
--   the pen stays   a stop is inked inside the ground you covered, its
--                   footprint the measured spread at two standard deviations.
--                   A longer stay never makes it larger: the time goes into
--                   the ink, more passes (darker, browner), a coffee-ring rim
--                   that closes, a darker nib on a small one, and drops flicked
--                   onto the road as you leave. A stop of under two minutes
--                   without a death is a droplet, one dot of its tint
--   the join        the line swells and darkens for a few pixels where it
--                   leaves or enters a stop, and inside the stop the pool's
--                   ink takes over, so roads and stops read as one trail
--
-- Pure arithmetic over plain tables, no client calls: Build turns a sheet's
-- stops and roads into primitives in sheet pixels, in draw order, so the
-- whole of it is tested off the client (tests/ink_trail.lua). Every look is
-- a named number below.
--
-- The pen it draws the roads with, and the geometry and primitives it
-- shares with the page's leaders and the cards, are ns.UI.Pen
-- (UI/Ink/Pen.lua, loaded first).

local addonName, ns = ...

local Style = ns.Style
local Pen = ns.UI.Pen
local Ink = {}
ns.UI.InkTrail = Ink
-- The pen's tuning (UI/Ink/Pen.lua): the very table /sd pen changes.
local PEN = Pen.PEN

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------

-- What was done at a stop, by its tint (UI/Journey/Text/Tips.lua's
-- StopKind; nil is "stayed"): rust for a fight, ochre for quests, moss for
-- rest, sepia for a plain stay. The sheet's key and glyphs take theirs from
-- here.
Ink.TINT = {
    fighting = { 0.62, 0.20, 0.07 },
    questing = { 0.68, 0.49, 0.10 },
    resting = { 0.30, 0.39, 0.21 },
    stayed = { 0.38, 0.23, 0.08 },
}

-- A stay's ink, T from 0 to 1: log(1 + minutes / `knee`) against `full`
-- minutes. 2 min 0.17, 10 min 0.44, 30 min 0.67, 1 h 0.84, 2 h and more 1.
local TIME = { knee = 2, full = 120 }

-- A stop's footprint: its ellipse at `sigmas` standard deviations of the
-- measured spread (sdx, sdy, rho on the map), or, for a stop saved before
-- shapes were kept, `r` yards over `rootTwo` (r is twice the RMS radius,
-- which is root 2 sigma for a round spread). At least `least` pixels across
-- (the pen's own pause, the one lie told for legibility), at most `aspect`
-- times as long as wide, at most `most` across. Time never enters it.
-- `yards` across a map whose size the client will not say.
local FOOT = { sigmas = 2, rootTwo = math.sqrt(2), least = 6, aspect = 4, most = 80, yards = 5000 }

-- A stop's ink. Under `droplet` seconds without a death: one dot `drop`
-- across, at dropAlpha by its time. Otherwise, all of it inside the
-- footprint:
--   wash    the footprint once, at wash[1] + wash[2] * T
--   passes  1 to `layers` of them by T, each a set of dabs at `layerAlpha`
--           (radius dab[1] of the short semi-axis, within dab[2]..dab[3]
--           px, `spacing` radii apart on a hex grid, jittered `jitter`,
--           their middles `inset` radii in from the edge), each pass
--           `deepen` nearer the ink: a long stay is darker and browner-
--           black, a short one pale and in its tint. A footprint too small
--           for dabs (short semi-axis under `tiny`) takes a `copy` of
--           itself per pass instead, a hair off its middle (`wander` px)
--   rim     on a footprint at least `rimAt` across: dabs `rimStep` px apart
--           on the edge, rimDab px, at rim[1] + rim[2] * T, `rimDark`
--           toward the ink, broken where the noise is under -1 + 2 *
--           `rimGap` * (1 - T): a short stay's rim is broken, a long one's
--           closed. A fight's rim throws a short streak every `splash` dabs,
--           out to `streak` of the footprint: a sign of the fight that is
--           not its colour
--   nib     on a footprint under `nibBelow` across: a dark core `nib` px in
--           radius at nibAlpha[1] + nibAlpha[2] * T
-- No dab reaches more than `edge` px past the footprint (its anti-aliasing).
-- At most `perPool` dabs a pool, and near the sheet's cap each pool still
-- to come keeps one. A stop whose middle lies within `merge` of a longer
-- stop's reach, of the same kind, is part of it: its time adds to the ink,
-- never to the ground.
local POOL = { droplet = 120, drop = 3.2, dropAlpha = { 0.55, 0.85 }, wash = { 0.22, 0.33 },
    layers = 5, layerAlpha = 0.20, dab = { 0.5, 0.9, 5 }, spacing = 1.25, inset = 0.5, jitter = 0.35,
    deepen = 0.10, tiny = 2.6, copy = 0.85, wander = 0.25, rimAt = 7.5, rimStep = 1.25, rimDab = { 0.45, 0.8 },
    rim = { 0.10, 0.70 }, rimDark = 0.55, rimGap = 0.45, splash = 3, streak = 1.12, nibBelow = 7.5, nib = 1.3,
    nibAlpha = { 0.35, 0.60 }, merge = 0.6, perPool = 160, edge = 0.4 }

-- A road: smoothed `smooth` times (Chaikin), then a point every `step` px
-- (growing by `stepGrow`, to at most `stepMost`, while the sheet's roads
-- would pass the quads' cap at `stepRoom` quads a step). Pressure p from 0
-- to 1 is its pace against the sheet's brisk pace (the pace.ref quantile of
-- its roads' speeds in sheet pixels, so no yards are needed): pace.base +
-- pace.gain * log2(brisk / speed). The usual pace is a plain line, and a
-- road under pace.least seconds or pace.short px is taken as usual.
--   line      width[1] + width[2] * p px, wobbling `wobble` over
--             `wobbleScale` px; alpha[1] + alpha[2] * p, flickering
--             `flicker` over `flickerScale` px, at most `darkest`
--   dry pen   under `dryBelow`: `dryWidth` of the width, fading to
--             `dryFade` of its ink where the noise (over `dryScale` px) is
--             under `dryGap`. Never dashes, never two hairlines (a pixel
--             apart they read as a railway)
--   wet halo  over `haloAbove`: `halo` px wider at `haloAlpha`
--   joins     over `swell` px past a stop's edge it swells by `swellWidth`
--             * (0.5 + T) px and `swellAlpha` * T; within `handOver` of the
--             stop's reach the line stops and the pool takes over. A stop
--             is joined when it ended within `gap` seconds of the road's
--             start, or began within them of its end
--   free end  lifts over `lift` px to `liftTo` of the width
-- Joints are mitred, at most `miter` times the half width.
local ROAD = { step = 4, stepGrow = 2, stepMost = 16, stepRoom = 1.6, smooth = 2, width = { 0.9, 1.3 },
    alpha = { 0.50, 0.40 }, darkest = 0.95, wobble = 0.18, wobbleScale = 10, flicker = 0.12, flickerScale = 14,
    dryBelow = 0.3, dryWidth = 0.75, dryGap = -0.45, dryScale = 3, dryFade = 0.3, handOver = 0.8, haloAbove = 0.6,
    halo = 1.4, haloAlpha = 0.10, swell = 9, swellWidth = 0.7, swellAlpha = 0.25, lift = 4, liftTo = 0.4,
    miter = 2, gap = 120,
    pace = { base = 0.45, gain = 0.35, ref = 0.75, least = 15, short = 8 } }

-- Sprinkles. Along a road, per100[1] + per100[2] * p dots every 100 px,
-- one to a stretch (so they never clump), either side, `gap` px off the
-- line's edge plus |gauss| * (spread[1] + spread[2] * p); radius size[1] +
-- size[2] * u px; alpha alpha[1] - alpha[2] * distance, at least `least`.
-- Out of a stop: exit[1] + exit[2] * T drops within `exitReach` px past its
-- edge, in its tint. A road with fighting on the way: one rust drop for
-- every `rustEvery` seconds of it, at most `rustMost`.
local SPATTER = { per100 = { 1.5, 9 }, gap = 0.5, spread = { 0.8, 2.2 }, size = { 0.35, 0.45 },
    alpha = { 0.80, 0.08 }, least = 0.25, exit = { 1, 5 }, exitReach = 10, rustEvery = 12, rustMost = 10 }

-- What a sheet draws at most: road quads, sprinkles, the pools' dabs, and
-- the stops it considers, longest first. Past a cap the rest is left off.
local CAP = { quads = 1800, dots = 700, dabs = 1400, stops = 400 }

-- Draw order, bottom up: the sublevels within ARTWORK, all under the
-- sheet's creases (4), so the trail folds with the paper.
local LAYER = { wash = -6, halo = -5, road = -4, dab = -3, rim = -2, spatter = -1, nib = 0 }

Ink.TIME, Ink.FOOT, Ink.POOL, Ink.ROAD, Ink.SPATTER, Ink.CAP, Ink.LAYER = TIME, FOOT, POOL, ROAD, SPATTER, CAP,
    LAYER

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------

local floor, sqrt, abs, cos, sin, log, pi = math.floor, math.sqrt, math.abs, math.cos, math.sin, math.log, math.pi
local atan2 = math.atan2 or math.atan
local min, max = math.min, math.max

-- The pen's (UI/Ink/Pen.lua): v kept within lo..hi.
local Clamp = Pen.Clamp
local function Toward(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

-- Style.Noise's hash, in 0..1: the same every time.
local function Hash(n)
    local x = sin(n * 12.9898 + 78.233) * 43758.5453
    return x - floor(x)
end

-- Smooth value noise in -1..1 along x. The seed is kept small: sin loses
-- its digits on epoch-sized arguments.
function Ink.Noise(seed, x)
    seed = (seed % 9973) * 0.618
    local i = floor(x)
    local f = x - i
    local a, b = Hash(seed + i), Hash(seed + i + 1)
    local t = f * f * (3 - 2 * f)
    return (a + (b - a) * t) * 2 - 1
end

local function Gauss(rand) return (rand() + rand() + rand() - 1.5) * 2 end

-- A stay's ink, 0..1, from its seconds.
function Ink.TimeScore(seconds)
    local m = (seconds or 0) / 60
    return Clamp(log(1 + m / TIME.knee) / log(1 + TIME.full / TIME.knee), 0, 1)
end

-- What was done at a stop, when the caller does not say: JourneyText's
-- word, looked up as it is needed (it loads after this file).
local function DefaultKind(seg)
    local Text = ns.UI.JourneyText
    return Text and Text.StopKind(seg) or "stayed"
end

--------------------------------------------------------------------------
-- Footprints
--------------------------------------------------------------------------

-- A stop's footprint on the sheet, { x, y, a1, a2, theta }: its semi-axes
-- in px (a1 the long one) and the long axis's angle (y down). `fullW`,
-- `fullH` are the whole map's size in px; `pxPerYard` serves a stop
-- without a shape.
function Ink.Footprint(seg, x, y, fullW, fullH, pxPerYard)
    local a1, a2, theta
    if seg.sdx and seg.sdy then
        local sx, sy = seg.sdx * fullW, seg.sdy * fullH
        local a, c, b = sx * sx, sy * sy, (seg.rho or 0) * sx * sy
        local mid, diff = (a + c) / 2, sqrt(((a - c) / 2) ^ 2 + b * b)
        a1 = FOOT.sigmas * sqrt(max(mid + diff, 0))
        a2 = FOOT.sigmas * sqrt(max(mid - diff, 0))
        theta = 0.5 * atan2(2 * b, a - c)
    else
        a1 = (seg.r or 30) / FOOT.rootTwo * pxPerYard
        a2 = a1
        theta = Hash((seg.from or 0) % 997) * pi
    end
    local least = FOOT.least / 2
    a1, a2 = Clamp(a1, least, FOOT.most / 2), Clamp(a2, least, FOOT.most / 2)
    a2 = max(a2, a1 / FOOT.aspect)
    return { x = x, y = y, a1 = a1, a2 = a2, theta = theta }
end

-- The footprint's radius toward the unit vector (dx, dy).
function Ink.Extent(e, dx, dy)
    local c, s = cos(e.theta), sin(e.theta)
    local u, v = dx * c + dy * s, -dx * s + dy * c
    return 1 / sqrt((u * u) / (e.a1 * e.a1) + (v * v) / (e.a2 * e.a2))
end

-- How far out a point lies: 1 on the footprint's edge.
function Ink.Reach(e, x, y)
    local c, s = cos(e.theta), sin(e.theta)
    local dx, dy = x - e.x, y - e.y
    local u, v = dx * c + dy * s, -dx * s + dy * c
    return sqrt((u / e.a1) ^ 2 + (v / e.a2) ^ 2)
end

-- Footprint-local (u along the long axis) to the sheet.
local function FromLocal(e, u, v)
    local c, s = cos(e.theta), sin(e.theta)
    return e.x + u * c - v * s, e.y + u * s + v * c
end

-- The pen's primitives and its walk along a road (UI/Ink/Pen.lua).
local Quad, Disc, Along = Pen.Quad, Pen.Disc, Pen.Along

--------------------------------------------------------------------------
-- Pace: the pen's pressure
--------------------------------------------------------------------------

-- Each road's pressure, by its pace against the sheet's brisk pace, in
-- sheet pixels a second: the sheet calibrates itself, no yards needed.
-- `pts` are the roads' points on the sheet. Returns the pressures and the
-- brisk pace.
function Ink.Pace(roads, pts)
    local R = ROAD.pace
    local speeds, list = {}, {}
    for i, road in ipairs(roads) do
        local p, L = pts[i], 0
        for k = 3, #p, 2 do L = L + sqrt((p[k] - p[k - 2]) ^ 2 + (p[k + 1] - p[k - 1]) ^ 2) end
        local dt = (road.to or 0) - (road.from or 0)
        if dt >= R.least and L >= R.short then
            list[i] = L / dt
            speeds[#speeds + 1] = L / dt
        end
    end
    table.sort(speeds)
    local brisk = speeds[max(1, math.ceil(#speeds * R.ref))]
    local pressure = {}
    for i = 1, #roads do
        local v = list[i]
        if brisk and v and v > 0 then
            pressure[i] = Clamp(R.base + R.gain * log(brisk / v) / log(2), 0, 1)
        else
            pressure[i] = R.base
        end
    end
    return pressure, brisk
end

--------------------------------------------------------------------------
-- A road
--------------------------------------------------------------------------

-- One road's ink: its line (`flat`, its points on the sheet) at pressure
-- `p`, and its sprinkles. `ends` = { first, last }: the pools it left and
-- reached, or nil. `room` = { quads, dots, step }. Returns the quads and
-- dots made.
function Ink.Road(out, road, flat, p, ends, seed, room)
    local R, S = ROAD, SPATTER
    local step = room.step or R.step
    local C = Pen.Chaikin(flat, R.smooth)
    local P, total = Pen.Resample(C, step)
    if #P < 2 then return 0, 0 end
    local M = Pen.Mitres(P)
    local rand = Pen.Random(seed * 31 + 7)

    -- Where it comes out of the stop it left, and goes into the next.
    local outAt, inAt
    if ends.first then
        outAt = 0
        for i = 1, #P do
            outAt = P[i].s
            if Ink.Reach(ends.first.e, P[i].x, P[i].y) > 1 then break end
        end
    end
    if ends.last then
        inAt = total
        for i = #P, 1, -1 do
            inAt = P[i].s
            if Ink.Reach(ends.last.e, P[i].x, P[i].y) > 1 then break end
        end
    end
    -- How much of a stop's ink is still on the pen at s, 0..1, and whose.
    local function Swell(s)
        local best, pool = 0, nil
        if outAt then
            local d = s - outAt
            local w = d <= 0 and 1 or max(0, 1 - d / R.swell) ^ 2
            if w > best then best, pool = w, ends.first end
        end
        if inAt then
            local d = inAt - s
            local w = d <= 0 and 1 or max(0, 1 - d / R.swell) ^ 2
            if w > best then best, pool = w, ends.last end
        end
        return best, pool
    end

    -- Each vertex's width and alpha: the pace's weight, wobbling, shaped
    -- by the pen (its nib's angle, the ink a curve draws), swelling at a
    -- stop's edge, kept within the pen's widths, and lifting at a free end.
    -- A dry pen draws `dryWidth` of it.
    local dry = p < R.dryBelow
    local base = (R.width[1] + R.width[2] * p) * (dry and R.dryWidth or 1)
    local ink = R.alpha[1] + R.alpha[2] * p
    local F = PEN.flow
    local nib, load = Pen.Pen(P, not ends.first)
    local W, A, set = {}, {}, nil
    for i, pt in ipairs(P) do
        local s = pt.s
        local w = base * (1 + R.wobble * Ink.Noise(seed, s / R.wobbleScale))
            * nib[i] * F.straight * load[i] ^ F.widthGain
        local a = ink * (1 + R.flicker * Ink.Noise(seed + 7, s / R.flickerScale)) * (1 + F.alphaGain * (load[i] - 1))
        local k, pool = Swell(s)
        if pool then
            w = w + R.swellWidth * k * (0.5 + pool.T)
            a = a + R.swellAlpha * k * pool.T
        end
        w = Clamp(w, PEN.width[1], PEN.width[2])
        if i == 1 then set = w end
        -- A free end: the pen lifts.
        if not ends.first and s < R.lift then w = w * (R.liftTo + (1 - R.liftTo) * s / R.lift) end
        if not ends.last and total - s < R.lift then
            w = w * (R.liftTo + (1 - R.liftTo) * (total - s) / R.lift)
        end
        W[i], A[i] = w, Clamp(a, 0, R.darkest)
    end

    -- Inside the stops it joins, the pool's ink takes over from the line.
    local function Within(i)
        local pt = P[i]
        if ends.first and Ink.Reach(ends.first.e, pt.x, pt.y) < R.handOver then return true end
        if ends.last and Ink.Reach(ends.last.e, pt.x, pt.y) < R.handOver then return true end
        return false
    end
    local function Inside(i) return Within(i) and Within(i + 1) end

    local INK = Style.INK_STRONG
    local quads = 0
    local function Zero() return 0 end
    if dry then
        -- A dry pen: fading where the ink ran short, never gone.
        for i, pt in ipairs(P) do
            if Swell(pt.s) < 0.3 and Ink.Noise(seed + 101, pt.s / R.dryScale) < R.dryGap then
                A[i] = A[i] * R.dryFade
            end
        end
    end
    quads = quads + Pen.Stroke(out, LAYER.road, P, M, function(i) return W[i] / 2 end, Zero,
        function(i) return A[i] end, INK, Inside, room.quads)
    if not dry and p > R.haloAbove and quads < room.quads then
        quads = quads + Pen.Stroke(out, LAYER.halo, P, M, function(i) return W[i] / 2 + R.halo / 2 end, Zero,
            function() return R.haloAlpha end, INK, Inside, room.quads - quads)
    end

    -- Beads where the pen paused: at each sharp corner, and where it was
    -- set down fresh. Outside the stops it joins, within the dots' room.
    local dots = 0
    local B = PEN.bead
    local function Bead(x, y, i, size)
        if dots >= room.dots or Within(i) then return end
        local r = size * W[i] / 2
        Disc(out, LAYER.road, x, y, r, r, 0, INK, A[i])
        dots = dots + 1
    end
    if not ends.first then
        local r = B.start * set / 2
        if dots < room.dots then
            Disc(out, LAYER.road, P[1].x, P[1].y, r, r, 0, INK, A[1])
            dots = dots + 1
        end
    end
    for _, bead in ipairs(Pen.Beads(C)) do
        Bead(bead.x, bead.y, Clamp(floor(bead.s / step + 0.5) + 1, 1, #P), B.size)
    end

    -- Sprinkles along it, more the slower it went; none inside a pool.
    local function Drop(s, colour, spread, a0)
        if dots >= room.dots then return end
        local x, y, nx, ny = Along(P, s)
        local i = Clamp(floor(s / step) + 1, 1, #P)
        local side = rand() < 0.5 and 1 or -1
        local d = W[i] / 2 + S.gap + abs(Gauss(rand)) * spread
        x, y = x + nx * side * d, y + ny * side * d
        if ends.first and Ink.Reach(ends.first.e, x, y) < 1 then return end
        if ends.last and Ink.Reach(ends.last.e, x, y) < 1 then return end
        local r = S.size[1] + S.size[2] * rand()
        Disc(out, LAYER.spatter, x, y, r, r, 0, colour, Clamp(a0 - S.alpha[2] * d, S.least, 0.9))
        dots = dots + 1
    end
    local per100 = S.per100[1] + S.per100[2] * p
    local strata = max(0, floor(total * per100 / 100 + 0.5))
    for k = 0, strata - 1 do
        Drop((k + rand()) * total / max(strata, 1), INK, S.spread[1] + S.spread[2] * p, S.alpha[1])
    end
    -- Drops flicked out of the stops it joins, more the longer the stay.
    for _, which in ipairs({ { ends.first, outAt, 1 }, { ends.last, inAt, -1 } }) do
        local pool, at, dir = which[1], which[2], which[3]
        if pool and at then
            for _ = 1, floor(S.exit[1] + S.exit[2] * pool.T + 0.5) do
                Drop(Clamp(at + dir * rand() * S.exitReach, 0, total), pool.tint, 1.5, 0.85)
            end
        end
    end
    -- Rust where it fought on the way.
    local combat = road.act and road.act.combat or 0
    for _ = 1, min(S.rustMost, floor(combat / S.rustEvery)) do
        Drop(rand() * total, Ink.TINT.fighting, 1.8, 0.9)
    end
    return quads, dots
end

--------------------------------------------------------------------------
-- A stop
--------------------------------------------------------------------------

-- One stop's ink, all inside its footprint. `pool` = { e, T, kind, seconds,
-- droplet }; `room` = { dabs }. Returns the dabs used (discs, and a fight's
-- streaks).
function Ink.Pool(out, pool, seed, room)
    local Q = POOL
    local e, T, kind = pool.e, pool.T, pool.kind
    local tint = Ink.TINT[kind] or Ink.TINT.stayed
    local INK = Style.INK_STRONG
    local rand = Pen.Random(seed * 13 + 5)
    local used = 0
    if room.dabs <= 0 then return 0 end

    if pool.droplet then
        local r = Q.drop / 2
        Disc(out, LAYER.nib, e.x, e.y, r, r, 0, tint,
            Q.dropAlpha[1] + (Q.dropAlpha[2] - Q.dropAlpha[1]) * Clamp((pool.seconds or 0) / Q.droplet, 0, 1), pool)
        return 1
    end

    -- The wash: the footprint once.
    Disc(out, LAYER.wash, e.x, e.y, e.a1, e.a2, e.theta, tint, Q.wash[1] + Q.wash[2] * T, pool)
    used = used + 1

    -- The passes: more of them the longer the stay, on the same ground.
    local passes = 1 + floor((Q.layers - 0.001) * T)
    local rho = Clamp(Q.dab[1] * e.a2, Q.dab[2], Q.dab[3])
    for l = 1, passes do
        local c = Toward(tint, INK, Q.deepen * l)
        if e.a2 < Q.tiny then
            -- Too small for dabs: the footprint again, a hair off.
            if used < room.dabs then
                local j = Q.wander
                Disc(out, LAYER.dab, e.x + (rand() - 0.5) * j * 2, e.y + (rand() - 0.5) * j * 2,
                    e.a1 * Q.copy, e.a2 * Q.copy, e.theta, c, Q.layerAlpha + 0.04, pool)
                used = used + 1
            end
        else
            local step = Q.spacing * rho
            local ox, oy = rand() * step, rand() * step
            local ia1, ia2 = max(e.a1 - Q.inset * rho, 0.5), max(e.a2 - Q.inset * rho, 0.5)
            local row = 0
            local v = -e.a2 + oy
            while v <= e.a2 do
                local u = -e.a1 + ox + ((row % 2 == 1) and step / 2 or 0)
                while u <= e.a1 do
                    local ju = u + (rand() - 0.5) * 2 * Q.jitter * step
                    local jv = v + (rand() - 0.5) * 2 * Q.jitter * step
                    local r = rho * (0.8 + 0.4 * rand())
                    -- Its middle within the inset, and all of it within the
                    -- footprint, give or take its anti-aliased edge: inside
                    -- the footprint shrunk about its middle by `fit`, every
                    -- point lies at least (1 - fit) * a2 from the edge,
                    -- however long the footprint is.
                    local fit = 1 - (r - Q.edge) / e.a2
                    local fa1, fa2 = min(ia1, e.a1 * fit), min(ia2, e.a2 * fit)
                    if fa1 > 0 and fa2 > 0 and (ju / fa1) ^ 2 + (jv / fa2) ^ 2 <= 1 and used < room.dabs then
                        local x, y = FromLocal(e, ju, jv)
                        Disc(out, LAYER.dab, x, y, r, r, 0, c, Q.layerAlpha, pool)
                        used = used + 1
                    end
                    u = u + step
                end
                v = v + step * 0.866
                row = row + 1
            end
        end
    end

    if 2 * e.a2 >= Q.rimAt then
        -- The rim: a coffee ring, broken for a short stay, closed for a long one.
        local a, b = e.a1, e.a2
        local perimeter = pi * (3 * (a + b) - sqrt((3 * a + b) * (a + 3 * b)))
        local n = max(8, math.ceil(perimeter / Q.rimStep))
        local c = Toward(tint, INK, Q.rimDark)
        local alpha = Q.rim[1] + Q.rim[2] * T
        for i = 1, n do
            if used >= room.dabs then break end
            local phi = 2 * pi * (i - 1 + 0.3 * rand()) / n
            local gap = Ink.Noise(seed + 3, i * 0.45) < -1 + 2 * Q.rimGap * (1 - T)
            if not gap then
                local r = Q.rimDab[1] + (Q.rimDab[2] - Q.rimDab[1]) * rand()
                -- On the edge, never more than `edge` px past it.
                local q = min(0.92 + 0.04 * Gauss(rand), 1 + (Q.edge - r) / b)
                if kind == "fighting" and i % Q.splash == 0 then
                    -- A streak flung out from the rim.
                    local x2, y2 = FromLocal(e, a * cos(phi) * Q.streak, b * sin(phi) * Q.streak)
                    local x1, y1 = FromLocal(e, a * cos(phi) * 0.8, b * sin(phi) * 0.8)
                    local dx, dy = x2 - x1, y2 - y1
                    local len = sqrt(dx * dx + dy * dy)
                    local nx, ny = -dy / len * 0.35, dx / len * 0.35
                    Quad(out, LAYER.rim, x1 + nx, y1 + ny, x2 + nx * 0.4, y2 + ny * 0.4,
                        x2 - nx * 0.4, y2 - ny * 0.4, x1 - nx, y1 - ny, c, alpha, pool)
                else
                    local x, y = FromLocal(e, a * cos(phi) * q, b * sin(phi) * q)
                    Disc(out, LAYER.rim, x, y, r, r, 0, c, alpha, pool)
                end
                used = used + 1
            end
        end
    elseif used < room.dabs then
        -- A small stop: the pen's nib rested here, darker the longer.
        Disc(out, LAYER.nib, e.x, e.y, Q.nib, Q.nib, 0, Toward(tint, INK, 0.55), Q.nibAlpha[1] + Q.nibAlpha[2] * T,
            pool)
        used = used + 1
    end
    return used
end

--------------------------------------------------------------------------
-- The sheet
--------------------------------------------------------------------------

-- `sheet` = { stops, roads } (Core/JourneyRecap's sheet: segments as
-- Journey.All gives them, roads in time order). `box` = { at(x, y) -> px,
-- py or nil, fullW, fullH, pxPerYard }. `opts`: points(road) -> its flat
-- map points, kind(stop) -> its kind, pressure (a road's own, for the
-- ladder in the checks), cap (a share of CAP, for a plate smaller than a
-- page: UI/Journey/Plate.lua). Returns the primitives in draw order (each
-- with `n`, its place as made, and `part`, "road" or "pool"), the counts
-- { quads, dots, dabs, pools, droplets, stops, roads, step, length, brisk },
-- and the pools, longest first: { seg, segs (every stop drawn as it, its
-- own first), kind, e, T, seconds, deaths, more, droplet, tint }.
function Ink.Build(sheet, box, opts)
    opts = opts or {}
    local out = {}
    local counts = { quads = 0, dots = 0, dabs = 0, pools = 0, droplets = 0, stops = 0, roads = 0 }
    local points = opts.points or function(seg) return seg.pts end
    local KindOf = opts.kind or DefaultKind
    local CAP = CAP
    if opts.cap and opts.cap < 1 then
        local share = max(opts.cap, 0)
        CAP = { quads = floor(CAP.quads * share), dots = floor(CAP.dots * share), dabs = floor(CAP.dabs * share),
            stops = floor(CAP.stops * share) }
    end

    -- The pools, longest first; a stop on a longer one of its kind is part
    -- of it. Whether a pool is a droplet is settled once all its time is in.
    local list = {}
    for _, seg in ipairs(sheet.stops or {}) do list[#list + 1] = seg end
    table.sort(list, function(a, b) return (a.seconds or 0) > (b.seconds or 0) end)
    local pools, of = {}, {}
    for i = 1, min(#list, CAP.stops) do
        local seg = list[i]
        local x, y = box.at(seg.x, seg.y)
        if x then
            counts.stops = counts.stops + 1
            local kind = KindOf(seg) or "stayed"
            local seconds = seg.seconds or ((seg.to or 0) - (seg.from or 0))
            local deaths = seg.act and seg.act.deaths or 0
            local into
            for _, pool in ipairs(pools) do
                if pool.kind == kind and Ink.Reach(pool.e, x, y) < POOL.merge then
                    into = pool
                    break
                end
            end
            if into then
                into.seconds, into.deaths, into.more = into.seconds + seconds, into.deaths + deaths, into.more + 1
                into.segs[#into.segs + 1] = seg
                of[seg] = into
            else
                local pool = { seg = seg, segs = { seg }, kind = kind, seconds = seconds, deaths = deaths, more = 0,
                    e = Ink.Footprint(seg, x, y, box.fullW, box.fullH, box.pxPerYard or 0),
                    tint = Ink.TINT[kind] or Ink.TINT.stayed }
                pools[#pools + 1] = pool
                of[seg] = pool
            end
        end
    end
    for _, pool in ipairs(pools) do
        pool.T = Ink.TimeScore(pool.seconds)
        pool.droplet = pool.seconds < POOL.droplet and pool.deaths == 0
    end

    -- The roads on the sheet, and each one's pressure.
    local roads, pts = sheet.roads or {}, {}
    for i, road in ipairs(roads) do
        local flat, onSheet = points(road) or {}, {}
        for k = 1, #flat - 1, 2 do
            local x, y = box.at(flat[k], flat[k + 1])
            if x then onSheet[#onSheet + 1], onSheet[#onSheet + 2] = x, y end
        end
        pts[i] = onSheet
    end
    local pressure, brisk = Ink.Pace(roads, pts)
    if opts.pressure then
        for i = 1, #roads do pressure[i] = opts.pressure[i] or pressure[i] end
    end
    counts.brisk = brisk

    -- The stops a road left (ending within `gap` seconds of its start) and
    -- reached; a droplet takes no part.
    local function Near(road, atStart)
        local best, gap = nil, ROAD.gap
        for _, seg in ipairs(sheet.stops or {}) do
            local d = atStart and abs((road.from or 0) - (seg.to or 0)) or abs((seg.from or 0) - (road.to or 0))
            if d <= gap then best, gap = seg, d end
        end
        local pool = best and of[best]
        return pool and not pool.droplet and pool or nil
    end

    -- Room for the roads: under the cap, the step grows.
    local length = 0
    for i = 1, #roads do
        local p = pts[i]
        for k = 3, #p, 2 do length = length + sqrt((p[k] - p[k - 2]) ^ 2 + (p[k + 1] - p[k - 1]) ^ 2) end
    end
    local step = ROAD.step
    while length / step * ROAD.stepRoom > CAP.quads and step < ROAD.stepMost do step = step + ROAD.stepGrow end
    counts.step, counts.length = step, length

    for i, road in ipairs(roads) do
        local room = { quads = CAP.quads - counts.quads, dots = CAP.dots - counts.dots, step = step }
        if room.quads <= 0 then break end
        local q, d = Ink.Road(out, road, pts[i], pressure[i], { first = Near(road, true), last = Near(road, false) },
            floor(road.from or i) % 9973, room)
        counts.quads, counts.dots = counts.quads + q, counts.dots + d
        if q > 0 then counts.roads = counts.roads + 1 end
    end

    -- The pools, longest first, each keeping one dab for every pool still
    -- to come: past the cap a short stay is at least its wash or its dot.
    local roadsMade = #out
    for i, pool in ipairs(pools) do
        local room = { dabs = min(POOL.perPool, CAP.dabs - counts.dabs - (#pools - i)) }
        if room.dabs <= 0 then break end
        counts.dabs = counts.dabs + Ink.Pool(out, pool, floor(pool.seg.from or 0) % 9973, room)
        pool.drawn = true
        if pool.droplet then counts.droplets = counts.droplets + 1 else counts.pools = counts.pools + 1 end
    end

    -- A steady draw order: by layer, then as made. Each says what made it
    -- (`part`: "road" or "pool"), for a drawing that shows the two apart (the
    -- tour's plate, UI/Windows/Intro/Tour.lua, lays the road back as the pool
    -- comes in).
    for i, prim in ipairs(out) do
        prim.n = i
        prim.part = i <= roadsMade and "road" or "pool"
    end
    table.sort(out, function(a, b)
        if a.layer ~= b.layer then return a.layer < b.layer end
        return a.n < b.n
    end)
    return out, counts, pools, pressure
end
