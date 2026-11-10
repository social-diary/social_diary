-- The zone sheet's ink trail (JRN-14), its arithmetic alone
-- (UI/Ink/Trail.lua, and its pen, UI/Ink/Pen.lua): the user's rule that a
-- longer stay never makes the ground larger, no ink outside a footprint,
-- seamless strokes that are never dashed, droplets, pace, merging and the
-- caps. Pure functions over
-- plain tables, so nothing here needs a sheet; tests/journey_ui.lua checks
-- the same promises as drawn on one.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Ink = ns.UI.InkTrail
local Pen = ns.UI.Pen
local POOL, FOOT, CAP, LAYER = Ink.POOL, Ink.FOOT, Ink.CAP, Ink.LAYER

-- A 500 x 340 map, as if the whole of it were on the sheet.
local box = { at = function(x, y) return x * 500, y * 340 end, fullW = 500, fullH = 340, pxPerYard = 0.1 }

-- How far a disc reaches past footprint `e`, in px: the most any point of
-- its edge lies outside the ellipse, measured to the nearest point of the
-- ellipse's outline (sampled every half degree).
local function Past(e, prim)
    local outline = {}
    local c, s = math.cos(e.theta), math.sin(e.theta)
    for k = 0, 719 do
        local a = 2 * math.pi * k / 720
        local u, v = e.a1 * math.cos(a), e.a2 * math.sin(a)
        outline[#outline + 1] = { e.x + u * c - v * s, e.y + u * s + v * c }
    end
    local most = -math.huge
    local pc, ps = math.cos(prim.th), math.sin(prim.th)
    for k = 0, 35 do
        local a = 2 * math.pi * k / 36
        local u, v = prim.rx * math.cos(a), prim.ry * math.sin(a)
        local x, y = prim.x + u * pc - v * ps, prim.y + u * ps + v * pc
        if Ink.Reach(e, x, y) > 1 then
            local near = math.huge
            for _, o in ipairs(outline) do near = math.min(near, (o[1] - x) ^ 2 + (o[2] - y) ^ 2) end
            most = math.max(most, math.sqrt(near))
        end
    end
    return most
end

--------------------------------------------------------------------------
Section("time never touches the ground")

local shaped = { kind = "stop", from = 100, to = 160, x = 0.5, y = 0.5, sdx = 0.008, sdy = 0.004, rho = 0.3,
    seconds = 60 }
local e1 = Ink.Footprint(shaped, 250, 170, 500, 340, 0.1)
shaped.seconds, shaped.to = 7200, 7300
local e2 = Ink.Footprint(shaped, 250, 170, 500, 340, 0.1)
Check(e1.a1 == e2.a1 and e1.a2 == e2.a2 and e1.theta == e2.theta, "a footprint changed with time")

-- The stay's score at its anchors.
for _, anchor in ipairs({ { 120, 0.17 }, { 600, 0.44 }, { 3600, 0.84 }, { 7200, 1 }, { 36000, 1 } }) do
    Check(math.abs(Ink.TimeScore(anchor[1]) - anchor[2]) < 0.01,
        ("T at %d s is %.3f, not %.2f"):format(anchor[1], Ink.TimeScore(anchor[1]), anchor[2]))
end
Eq(Ink.TimeScore(0), 0, "no time is no ink")

--------------------------------------------------------------------------
Section("the footprint: 2 sigma of the spread, r over root 2 for an old stop")

-- A round spread on a square map: 2 sigma either way.
local round = Ink.Footprint({ sdx = 0.02, sdy = 0.02, rho = 0 }, 0, 0, 500, 500, 0.1)
Check(math.abs(round.a1 - 20) < 1e-9 and math.abs(round.a2 - 20) < 1e-9, "a round spread is not 2 sigma: " .. round.a1)
-- An old stop: r yards over root 2.
local old = Ink.Footprint({ r = 200, from = 5 }, 0, 0, 500, 340, 0.1)
Check(math.abs(old.a1 - 200 / math.sqrt(2) * 0.1) < 1e-9 and old.a1 == old.a2, "an old stop is not r / root 2: " .. old.a1)
-- The least, the most and the aspect.
local tiny = Ink.Footprint({ sdx = 0.0001, sdy = 0.0001 }, 0, 0, 500, 340, 0.1)
Eq(tiny.a1, FOOT.least / 2, "a tiny spread is not the least size")
local huge = Ink.Footprint({ sdx = 0.5, sdy = 0.5 }, 0, 0, 500, 340, 0.1)
Eq(huge.a1, FOOT.most / 2, "a huge spread passed the most")
local thin = Ink.Footprint({ sdx = 0.05, sdy = 0.001, rho = 0 }, 0, 0, 500, 340, 0.1)
Check(thin.a1 <= FOOT.aspect * thin.a2 + 1e-9, "a thin spread passed the aspect")
-- Leaning with its spread, its long axis along the correlation.
local lean = Ink.Footprint({ sdx = 0.01, sdy = 0.01, rho = 0.8 }, 0, 0, 500, 500, 0.1)
Check(math.abs(lean.theta - math.pi / 4) < 1e-6 and lean.a1 > lean.a2, "a leaning spread is not turned to it")
-- Reach and Extent agree: a point at the extent is on the edge.
for _, dir in ipairs({ { 1, 0 }, { 0, 1 }, { 0.6, -0.8 } }) do
    local d = Ink.Extent(lean, dir[1], dir[2])
    Check(math.abs(Ink.Reach(lean, lean.x + dir[1] * d, lean.y + dir[2] * d) - 1) < 1e-9, "Reach and Extent disagree")
end

--------------------------------------------------------------------------
Section("a pool's ink stays on its ground, darker the longer")

local function PoolOf(e, seconds, kind)
    local out = {}
    Ink.Pool(out, { e = e, T = Ink.TimeScore(seconds), kind = kind or "stayed", seconds = seconds }, 1, { dabs = 999 })
    return out
end
local big = Ink.Footprint({ sdx = 0.02, sdy = 0.012, rho = 0.3 }, 250, 170, 500, 340, 0.1)
for _, case in ipairs({ { e1, 180 }, { e1, 7200 }, { big, 180 }, { big, 7200 },
    { Ink.Footprint({ r = 10 }, 50, 50, 500, 340, 0.1), 3600 } }) do
    local e = case[1]
    local worst, stray = -math.huge, 0
    for _, prim in ipairs(PoolOf(e, case[2], case[3])) do
        if prim.k == "d" then
            worst = math.max(worst, Past(e, prim))
        else
            stray = stray + 1
        end
    end
    -- Give or take the outline's sampling (0.01 px).
    Check(worst <= POOL.edge + 0.01, ("a dab reached %.3f px past its footprint"):format(worst))
    -- A pool is discs only (a fight's streaks went with its stain, 9 Nov).
    Eq(stray, 0, "quads in a pool")
end

local short, long = PoolOf(e1, 180), PoolOf(e1, 7200)
Check(#long > #short, "a long stay has no more passes than a short one")
local function Coverage(prims, e)
    local keep = 1
    for _, p in ipairs(prims) do
        if p.k == "d" and (p.x - e.x) ^ 2 + (p.y - e.y) ^ 2 < 1 then keep = keep * (1 - p.a) end
    end
    return 1 - keep
end
Check(Coverage(long, e1) > Coverage(short, e1) + 0.2, "a long stay is not darker at its middle")
local function Wash(prims)
    for _, p in ipairs(prims) do if p.layer == LAYER.wash then return p.a end end
end
Check(Wash(long) > Wash(short), "a long stay's wash is not darker")
-- A big pool's rim closes with time: more rim dabs for a long stay.
local function Rim(prims)
    local n = 0
    for _, p in ipairs(prims) do if p.layer == LAYER.rim then n = n + 1 end end
    return n
end
Check(Rim(PoolOf(big, 7200)) > Rim(PoolOf(big, 180)), "a long stay's rim is not more closed")
-- A small one has a nib, darker the longer; a big one none.
local function Nib(prims)
    for _, p in ipairs(prims) do if p.layer == LAYER.nib then return p.a end end
end
Check(Nib(long) and Nib(long) > Nib(short), "a small pool's nib is not darker for a long stay")
Eq(Nib(PoolOf(big, 600)), nil, "a big pool has a nib")
-- The room is kept.
local capped = {}
Check(Ink.Pool(capped, { e = big, T = 1, kind = "stayed", seconds = 7200 }, 1, { dabs = 10 }) <= 10 and #capped <= 10,
    "a pool passed its room")
-- The same pool is the same ink every time.
local again = PoolOf(big, 600)
local once = PoolOf(big, 600)
local moved = #once ~= #again
for i = 1, #once do
    moved = moved or once[i].x ~= again[i].x or once[i].y ~= again[i].y or once[i].a ~= again[i].a
end
Check(not moved, "a pool's ink moved between drawings")

--------------------------------------------------------------------------
Section("a stroke is seamless and never dashed")

local P = Pen.Resample({ 0, 0, 20, 5, 40, 0, 60, 12 }, 4)
local out = {}
Pen.Stroke(out, LAYER.road, P, Pen.Mitres(P), function() return 1 end, function() return 0 end,
    function() return 0.8 end, ns.Style.INK_STRONG)
Eq(#out, #P - 1, "a stroke is not one quad a piece")
local apart = 0
for i = 2, #out do
    local a, b = out[i - 1], out[i]
    if math.abs(a.x2 - b.x1) > 1e-9 or math.abs(a.y2 - b.y1) > 1e-9 or math.abs(a.x3 - b.x4) > 1e-9
        or math.abs(a.y3 - b.y4) > 1e-9 then
        apart = apart + 1
    end
end
Eq(apart, 0, "pieces that do not meet the one before")
-- Resampled every step, its ends kept.
Check(P[1].x == 0 and P[1].y == 0 and P[#P].x == 60 and P[#P].y == 12, "the resampled line lost its ends")
local off = 0
for i = 2, #P - 1 do
    if math.abs(P[i].s - 4 * (i - 1)) > 1e-9 then off = off + 1 end
end
Eq(off, 0, "resampled points off their step")
-- Chaikin keeps the ends and cuts the corners.
local smooth = Pen.Chaikin({ 0, 0, 10, 0, 10, 10 }, 1)
Eq(#smooth, 12, "Chaikin's points: two cuts a corner, the ends kept")
Check(smooth[1] == 0 and smooth[2] == 0 and smooth[11] == 10 and smooth[12] == 10, "Chaikin lost the ends")

-- A brisk road (a dry pen) is one unbroken chain of pieces, fading but
-- never gone: dashes mean flights.
local fast = { stops = {}, roads = {
    { from = 0, to = 20, pts = { 0.1, 0.5, 0.9, 0.5 } },     -- 400 px in 20 s
    { from = 100, to = 400, pts = { 0.1, 0.2, 0.3, 0.2 } },  -- 100 px in 300 s
    { from = 500, to = 800, pts = { 0.1, 0.8, 0.3, 0.8 } },
    { from = 900, to = 1200, pts = { 0.4, 0.8, 0.6, 0.8 } },
} }
local prims, counts, _, pressure = Ink.Build(fast, box)
Check(pressure[1] < Ink.ROAD.dryBelow, "the brisk road is not a dry pen: " .. pressure[1])
local chain, least = {}, math.huge
for _, prim in ipairs(prims) do
    if prim.k == "q" and prim.layer == LAYER.road and prim.y1 > 150 and prim.y1 < 190 then
        chain[#chain + 1] = prim
        least = math.min(least, prim.a)
    end
end
Check(#chain > 50, "the brisk road has too few pieces: " .. #chain)
local breaks = 0
for i = 2, #chain do
    local a, b = chain[i - 1], chain[i]
    if math.abs(a.x2 - b.x1) > 1e-9 or math.abs(a.y2 - b.y1) > 1e-9 then breaks = breaks + 1 end
end
Eq(breaks, 0, "breaks in the dry pen's line (dashes)")
Check(least >= 0.1, "the dry pen faded out entirely: " .. least)
Eq(counts.roads, 4, "every road was drawn")

--------------------------------------------------------------------------
Section("pace: slower is heavier, and needs no yards")

local roads = { { from = 0, to = 100 }, { from = 200, to = 250 }, { from = 300, to = 600 } }
local pts = { { 0, 0, 100, 0 }, { 0, 0, 100, 0 }, { 0, 0, 100, 0 } }
local p = Ink.Pace(roads, pts)
Check(p[3] > p[1] and p[1] > p[2], "pressure does not follow pace")
-- Too short to judge: the usual pressure.
local q = Ink.Pace({ { from = 0, to = 5 } }, { { 0, 0, 100, 0 } })
Eq(q[1], Ink.ROAD.pace.base, "a road too short to judge is not the usual pressure")
-- A slow road is a wetter line with more sprinkles than a brisk one.
local function Weight(seconds)
    local o = {}
    local _, dots = Ink.Road(o, { from = 0, to = seconds }, { 0, 0, 200, 0 }, Ink.Pace({ { from = 0, to = seconds } ,
        { from = 0, to = 20 } }, { { 0, 0, 200, 0 }, { 0, 0, 200, 0 } })[1], {}, 7, { quads = 999, dots = 999 })
    local width = 0
    for _, prim in ipairs(o) do
        if prim.k == "q" and prim.layer == LAYER.road then
            width = math.max(width, math.abs(prim.y1 - prim.y4))
        end
    end
    return width, dots
end
local slowW, slowDots = Weight(300)
local briskW, briskDots = Weight(20)
Check(slowW > briskW and slowDots > briskDots, "a slow road is not heavier than a brisk one")

--------------------------------------------------------------------------
Section("droplets, merging, joins")

local sheet = { stops = {
    { kind = "stop", from = 0, to = 60, seconds = 60, x = 0.2, y = 0.2, r = 15 },
    { kind = "stop", from = 200, to = 230, seconds = 30, x = 0.6, y = 0.6, r = 15, act = { deaths = 1, combat = 20 } },
}, roads = {} }
local _, c, pools = Ink.Build(sheet, box, { kind = function() return "stayed" end })
Check(c.droplets == 1 and c.pools == 1, "droplets and pools miscounted")
for _, pool in ipairs(pools) do
    Eq(pool.droplet, pool.deaths == 0, "a stop with a death became a droplet")
end
for _, prim in ipairs(Ink.Build(sheet, box, { kind = function() return "stayed" end })) do
    if prim.of and prim.of.droplet then
        Check(prim.k == "d" and math.abs(2 * prim.rx - POOL.drop) < 1e-9, "a droplet is not one small dot")
    end
end

-- Two short stays on one spot are one pool: their time adds to the ink, and
-- together they are no droplet; another kind on the spot stays apart.
local twice = { stops = {
    { kind = "stop", from = 0, to = 90, seconds = 90, x = 0.5, y = 0.5, r = 30 },
    { kind = "stop", from = 500, to = 590, seconds = 90, x = 0.501, y = 0.5, r = 30 },
    { kind = "stop", from = 900, to = 1500, seconds = 600, x = 0.5, y = 0.5, r = 30, fought = true },
}, roads = {} }
local _, tc, tpools = Ink.Build(twice, box, { kind = function(seg) return seg.fought and "fighting" or "stayed" end })
Eq(tc.stops, 3, "the stops considered")
Eq(#tpools, 2, "the same spot twice is not one pool")
local merged = tpools[2]
Check(merged.more == 1 and merged.seconds == 180 and not merged.droplet, "the merged pool's time: " .. merged.seconds)
Check(merged.T == Ink.TimeScore(180), "the merged pool's ink is not its whole time")

-- Without a kind given, JourneyText says (it loads after InkTrail).
local _, _, kinds = Ink.Build({ stops = { { kind = "stop", from = 0, to = 900, seconds = 900, x = 0.5, y = 0.5,
    r = 30, act = { combat = 600 } } }, roads = {} }, box)
Eq(kinds[1].kind, "fighting", "the kind is not JourneyText's")

-- A road between two stops hands over to them and swells at their edges:
-- no line deep inside either, and drops flicked out of the long one.
local joined = { stops = {
    { kind = "stop", from = 0, to = 3600, seconds = 3600, x = 0.2, y = 0.5, sdx = 0.02, sdy = 0.02, rho = 0 },
    { kind = "stop", from = 3700, to = 4300, seconds = 600, x = 0.8, y = 0.5, sdx = 0.02, sdy = 0.02, rho = 0 },
}, roads = { { from = 3600, to = 3700, pts = { 0.2, 0.5, 0.5, 0.52, 0.8, 0.5 } } } }
local jprims, _, jpools = Ink.Build(joined, box, { kind = function() return "stayed" end })
local widest, drops, deepest = 0, 0, math.huge
for _, prim in ipairs(jprims) do
    if prim.k == "q" and prim.layer == LAYER.road then
        for _, pool in ipairs(jpools) do
            deepest = math.min(deepest, Ink.Reach(pool.e, (prim.x1 + prim.x3) / 2, (prim.y1 + prim.y3) / 2))
        end
        widest = math.max(widest, math.abs(prim.y1 - prim.y4))
    elseif prim.layer == LAYER.spatter and prim.r == Ink.TINT.stayed[1] then
        drops = drops + 1
    end
end
Check(deepest > Ink.ROAD.handOver - 0.3, "the line runs on inside a pool: " .. deepest)
Check(widest > Ink.ROAD.width[1] + Ink.ROAD.width[2] * 0.45 + 0.3, "the line does not swell into its stops")
Check(drops >= 2, "no drops flicked out of the stops: " .. drops)

-- Seeds stay small: an epoch-sized seed still gives honest noise.
for _, seed in ipairs({ 1791000000, 2 ^ 40 }) do
    local n = Ink.Noise(seed, 3.5)
    Check(n >= -1 and n <= 1 and n == n, "noise on a big seed")
end

--------------------------------------------------------------------------
Section("a fight is a stain: one blot, never a droplet, growing and darker the longer")
do

    local STAIN = Ink.STAIN
    local function Fought(seg) return seg.act and (seg.act.combat or 0) > 0 and "fighting" or "stayed" end
    -- A fight of `combat` seconds at sheet px x, y (on the 500 x 340 box).
    local function Fight(from, x, y, seconds, combat, extra)
        local seg = { kind = "stop", from = from, to = from + seconds, seconds = seconds, x = x / 500, y = y / 340,
            sdx = 0.004, sdy = 0.004, rho = 0, act = { combat = combat } }
        for k, v in pairs(extra or {}) do seg.act[k] = v end
        return seg
    end
    local function Road(from, to, xy, combat)
        local pts = {}
        for k = 1, #xy, 2 do pts[#pts + 1], pts[#pts + 2] = xy[k] / 500, xy[k + 1] / 340 end
        return { from = from, to = to, pts = pts, act = combat and { combat = combat } or nil }
    end
    -- Each pool's pieces by layer, and how far its ink reaches past its ground.
    local function Pieces(prims, pool)
        local by, past = {}, 0
        for _, prim in ipairs(prims) do
            if prim.of == pool then
                by[prim.layer] = (by[prim.layer] or 0) + 1
                for k = 1, prim.k == "q" and 4 or 0 do
                    local x, y = prim["x" .. k], prim["y" .. k]
                    local dx, dy = x - pool.e.x, y - pool.e.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d > 1e-6 then past = math.max(past, d - Ink.Extent(pool.e, dx / d, dy / d)) end
                end
            end
        end
        return by, past
    end

    -- The anchors of a fight's score.
    for _, anchor in ipairs({ { 60, 0.20 }, { 120, 0.32 }, { 300, 0.52 }, { 900, 0.81 }, { 1800, 1 }, { 7200, 1 } }) do
        Check(math.abs(Ink.FightScore(anchor[1]) - anchor[2]) < 0.01,
            ("F at %d s is %.3f, not %.2f"):format(anchor[1], Ink.FightScore(anchor[1]), anchor[2]))
    end

    -- A minute's fight on the way: no droplet, but a stain several times a
    -- droplet across, of blot pieces, that the road goes into and comes out
    -- of (no free ends: the line is not broken at the fight, 9 Nov).
    local onTheWay = { stops = { Fight(100, 250, 170, 60, 45) }, roads = {
        Road(0, 100, { 150, 170, 200, 170, 250, 170 }), Road(160, 260, { 250, 170, 300, 170, 350, 170 }) } }
    local wprims, wc, wpools = Ink.Build(onTheWay, box, { kind = Fought })
    local stain = wpools[1]
    Check(stain.stains and not stain.droplet and wc.droplets == 0, "a minute's fight is a droplet")
    Check(2 * math.min(stain.e.a1, stain.e.a2) >= 2 * STAIN.least[1] and 2 * stain.e.a2 > 2.5 * POOL.drop,
        ("a minute's fight is not a stain: %.1f px across"):format(2 * stain.e.a2))
    local wby, wpast = Pieces(wprims, stain)
    Check((wby[LAYER.wash] or 0) > 4 and not wby[LAYER.nib], "a minute's fight is not a blot")
    Check(not wby[LAYER.dab], "a minute's fight has a dark heart already")
    Check(wpast <= STAIN.sigma + STAIN.warp[1], ("a stain's ink reached %.2f px past its ground"):format(wpast))
    local inside, roadBeads = math.huge, 0
    for _, prim in ipairs(wprims) do
        if prim.layer == LAYER.road then
            if prim.k == "q" then
                inside = math.min(inside, Ink.Reach(stain.e, (prim.x1 + prim.x3) / 2, (prim.y1 + prim.y3) / 2))
            else
                roadBeads = roadBeads + 1
            end
        end
    end
    Check(inside > Ink.ROAD.stainHandOver - 0.3, "the line runs on inside a fight's stain: " .. inside)

    -- A quarter of an hour round one spot: six fights close together, the roads
    -- between fought on, a quest handed in between pulls (some fighting in it),
    -- a death. One stain, all its time and all its fighting in it, roads
    -- included, and none of their rust sprinkled on the roads.
    local function Grind(roadCombat)
        local sheet = { stops = {}, roads = {} }
        local spots = { { 240, 160, 140, 100 }, { 248, 172, 110, 80 }, { 260, 176, 180, 130 }, { 254, 186, 70, 50 },
            { 252, 165, 160, 120 }, { 266, 188, 90, 70 } }
        local t = 1000
        for i, sp in ipairs(spots) do
            sheet.stops[#sheet.stops + 1] = Fight(t, sp[1], sp[2], sp[3], sp[4], i == 3 and { deaths = 1 } or nil)
            t = t + sp[3]
            local nx = spots[i + 1] or { 300, 230 }
            sheet.roads[#sheet.roads + 1] = Road(t, t + 25, { sp[1], sp[2], nx[1], nx[2] }, roadCombat)
            t = t + 25
        end
        sheet.stops[#sheet.stops + 1] = { kind = "stop", from = t, to = t + 120, seconds = 120, x = 244 / 500,
            y = 178 / 340, sdx = 0.004, sdy = 0.004, rho = 0, act = { questsOut = 2, combat = 20 } }
        return sheet
    end
    local function Kinds(seg)
        if seg.act and (seg.act.questsOut or 0) > 0 then return "questing" end
        return Fought(seg)
    end
    local gprims, gc, gpools = Ink.Build(Grind(20), box, { kind = Kinds })
    Eq(#gpools, 1, "a quarter of an hour's fighting round one spot is not one stain")
    local grind = gpools[1]
    Eq(grind.more, 6, "the stain does not hold every stop on it")
    Eq(grind.deaths, 1, "the stain lost its death")
    Eq(grind.combat, 550 + 20 + 6 * 20, "the stain's fighting is not its stops' and its roads'")
    local function Rust(prims)
        local n = 0
        for _, prim in ipairs(prims) do
            if prim.layer == LAYER.spatter and prim.r == Ink.TINT.fighting[1] then n = n + 1 end
        end
        return n
    end
    Eq(Rust(gprims), Rust((Ink.Build(Grind(nil), box, { kind = Kinds }))), "the roads into the stain sprinkled rust")
    local gby, gpast = Pieces(gprims, grind)
    Check((gby[LAYER.dab] or 0) > 0 and (gby[LAYER.rim] or 0) > (wby[LAYER.rim] or 0),
        "a long fight's stain has no darker heart")
    Check(gpast <= STAIN.sigma + STAIN.warp[1], ("a stain's ink reached %.2f px past its ground"):format(gpast))
    Check(grind.e.a1 > stain.e.a1 + 5 and 2 * grind.e.a1 <= FOOT.most
        and grind.e.a1 <= STAIN.aspect * grind.e.a2 + 1e-9,
        ("a long fight's stain is not larger, within its most and aspect: %.1f by %.1f"):format(grind.e.a1, grind.e.a2))
    for _, prim in ipairs(gprims) do
        if prim.of == grind and prim.layer == LAYER.wash then
            Check(prim.a > STAIN.ink[1][2] + STAIN.ink[1][3] * 0.6, "a long fight's stain is not deeper")
            break
        end
    end

    -- The stain's account, for its tooltip (9 Nov, in the client: it told
    -- only its longest stop): every stop and fought road in it, its deaths
    -- and quests summed, the levels across them, from the first start to
    -- the last end.
    local sheet = Grind(20)
    for i, seg in ipairs(sheet.stops) do
        seg.subZone, seg.mapID = "Raptor Grounds", 1413
        seg.levelFrom, seg.levelTo = i < 4 and 19 or 20, i < 3 and 19 or 20
    end
    local _, _, apools = Ink.Build(sheet, box, { kind = Kinds })
    local a = Ink.Account(apools[1])
    Eq(a.combat, 550 + 20 + 6 * 20, "the account's fighting is not the stain's")
    Eq(a.deaths, 1, "the account lost the stain's death")
    Eq(a.questsOut, 2, "the account lost the quests handed in on the stain")
    Eq(a.parts, 7 + 6, "the account does not hold every stop and road")
    Eq(a.from, 1000, "the account does not start at the first stop")
    Eq(a.to, 1900 + 120, "the account does not end at the last stop")
    Eq(a.levelFrom, 19, "the account's first level")
    Eq(a.levelTo, 20, "the account's last level")
    Eq(a.place, "Raptor Grounds", "the account's place")
    -- In words: one account, the fighting once, no bookkeeping.
    local Text = ns.UI.JourneyText
    local title, lines = Text.Fought(a, a.from + 3000)
    local clock = function(t) return os.date("%H:%M", t) end
    Eq(title, "Raptor Grounds", "a stain's tooltip title")
    Eq(lines[1], "Fought here on and off, 11 min in all", "a stain's fighting")
    Eq(lines[2], "Died here", "a stain's death")
    Eq(lines[3], "Handed in 2 quests", "a stain's quests")
    Eq(lines[4], "Today from " .. clock(1000) .. " to " .. clock(2020) .. ", levels 19 to 20",
        "a stain's span and levels")
    Eq(#lines, 4, "a stain's tooltip is longer than four lines")
    -- Two deaths, quests both ways, a level up, on one stop.
    title, lines = Text.Fought({ place = "Lushwater Oasis", from = 1000, to = 1600, combat = 400, deaths = 2,
        questsIn = 1, questsOut = 3, levelFrom = 15, levelTo = 16, parts = 1 }, 4000)
    Eq(table.concat(lines, "|"), "Fought here for 6 min|Died here twice|Took a quest, handed in 3|Today from "
        .. clock(1000) .. " to " .. clock(1600) .. ", levels 15 to 16", "a fight with deaths and a level up")
    -- A single short fight on its own: "Fought here" once.
    title, lines = Text.Stop({ kind = "stop", subZone = "Razor Hill", from = 1000, to = 1120, seconds = 120,
        act = { combat = 40 }, levelFrom = 12, levelTo = 12 }, 4000, 0)
    Eq(table.concat(lines, "|"), "Fought here briefly|Today from " .. clock(1000) .. " to " .. clock(1120)
        .. ", level 12", "a short fight's tooltip")
    -- Within a minute, only its start.
    _, lines = Text.Fought({ from = 1020, to = 1030, combat = 10, parts = 1, mapID = 1413 }, 4000)
    Eq(lines[#lines], "Today at " .. clock(1020), "a fight within a minute is a span")
    -- Over days, both ends told with their day, never "From on 1 Oct" nor
    -- a padded "01 Oct" (9 Nov: Format.At's "on 01 Oct at 06:00" was let
    -- through).
    local day = os.time({ year = 2026, month = 10, day = 1, hour = 6, min = 0 })
    local today = os.time({ year = 2026, month = 10, day = 9, hour = 12, min = 0 })
    Eq(Text.Span(day, today - 3600, today), "From 1 Oct at 06:00 to today at 11:00", "a span over days")
    Eq(Text.Span(today - 13 * 3600, today - 3600, today), "From yesterday at 23:00 to today at 11:00",
        "a span over midnight")
    Eq(Text.Span(day, day + 1800, today), "On 1 Oct from 06:00 to 06:30", "a span on an old day")
    Eq(Text.Foot({ from = day, to = day + 1800, levelFrom = 20, levelTo = 19 }, today),
        "On 1 Oct from 06:00 to 06:30, levels 19 to 20", "a foot's levels in order")

    -- A pool that is not a fight's: how long in all, fighting and deaths on
    -- one line, its quests, the foot; four lines at most.
    title, lines = Text.Stayed({ place = "The Crossroads", kind = "questing", seconds = 1500, parts = 3, combat = 200,
        deaths = 2, questsIn = 2, questsOut = 3, from = day, to = day + 1500, levelFrom = 13, levelTo = 13 }, today)
    Eq(title .. "|" .. table.concat(lines, "|"), "The Crossroads|Quested here on and off, 25 min in all|Fought for 3 min"
        .. " and died twice|Took 2 quests, handed in 3|On 1 Oct from 06:00 to 06:25, level 13", "a pool's account")

    -- A door's visits: the second visit counted, the time in all.
    title, lines = Text.Dungeon({ name = "Wailing Caverns", visits = 2, seconds = 5220, from = day, to = day + 7200,
        levelFrom = 16, levelTo = 17 }, today)
    Eq(title .. "|" .. table.concat(lines, "|"), "Wailing Caverns|Went in twice, 1 h 27 min in all|On 1 Oct from"
        .. " 06:00 to 08:00, levels 16 to 17", "a door's visits")
    -- A person's page's door (no level, no end): its time inside and when.
    _, lines = Text.Dungeon({ name = "Ragefire Chasm", seconds = 1800, from = day }, today)
    Eq(table.concat(lines, "|"), "Inside for 30 min|On 1 Oct from 06:00 to 06:30", "a lone door")

    -- A people's spot: the fight titles it (its mark is on top), the rest a
    -- line each, two notes and a first sighting cut to four lines, the
    -- second note going before the sighting.
    local session = { startedAt = day, participants = { ["Player-1-A"] = {} } }
    title, lines = Text.Company({ sessions = { { session = session, seconds = 2700 } },
        fights = { { outcome = "won" }, { outcome = "won" } },
        notes = { { text = "First note.", about = { ["Player-1-A"] = true } }, { text = "Second note." } },
        firsts = { { guid = "Player-1-B" } }, from = day, to = day + 2700, levelFrom = 20, levelTo = 20 }, today)
    Eq(title, "Won 2 fights", "a spot's fights are its title, counted")
    Eq(#lines, 4, "a spot's tooltip is longer than four lines: " .. table.concat(lines, "|"))
    Eq(lines[1], "With someone for 45 min", "a spot's company under its fight")
    Eq(lines[2], "First note.", "a spot's note")
    Eq(lines[3], "First saw someone", "a spot's first sighting kept over a second note")
    Eq(lines[4], "On 1 Oct from 06:00 to 06:45, level 20", "a spot's foot")

    -- The same ground fought on a minute and an hour: the hour's larger. And a
    -- fight with no room for its blot is its ground once, in rust.
    local function Lone(seconds)
        local _, _, pools = Ink.Build({ stops = { Fight(0, 250, 170, seconds, seconds) }, roads = {} }, box,
            { kind = Fought })
        return pools[1]
    end
    Check(Lone(3600).e.a1 > Lone(60).e.a1 and Lone(3600).e.a1 >= Lone(600).e.a1, "a fight does not grow with its time")
    local tight = {}
    Eq(Ink.Stain(tight, Lone(3600), 1, { dabs = 5 }), 1, "a stain with no room is not one wash")
    Check(#tight == 1 and tight[1].k == "d" and tight[1].layer == LAYER.wash, "a stain with no room is not its ground")

    -- Apart: fights far from one another stay their own; a fight's stain
    -- never spans more than STAIN.span, however long the grind along a road;
    -- a stop without fighting on a stain stays its own pool.
    local road = { stops = {}, roads = {} }
    for i = 0, 14 do road.stops[#road.stops + 1] = Fight(i * 300, 40 + i * 8, 170, 200, 150) end
    road.stops[#road.stops + 1] = { kind = "stop", from = 9000, to = 9600, seconds = 600, x = 40 / 500, y = 170 / 340,
        sdx = 0.004, sdy = 0.004, rho = 0 }
    local _, _, rpools = Ink.Build(road, box, { kind = Fought })
    local stains, rest = 0, 0
    for _, pool in ipairs(rpools) do
        if pool.stains then
            stains = stains + 1
            Check(2 * pool.e.a1 <= STAIN.span + 2 * STAIN.bleed + 1e-6, "a stain passed its span: " .. 2 * pool.e.a1)
        else
            rest = rest + 1
        end
    end
    Check(stains >= 2, "a long grind along a road is one stain")
    Eq(rest, 1, "a stop without fighting joined a stain")
    local far = { stops = { Fight(0, 100, 100, 300, 200), Fight(400, 160, 100, 300, 200) }, roads = {} }
    Eq(#select(3, Ink.Build(far, box, { kind = Fought })), 2, "two fights far apart ran together")
end

--------------------------------------------------------------------------
Section("the caps hold, the step grows, the order is the layers'")

local busy = { stops = {}, roads = {} }
local flat = {}
for i = 0, 400 do
    flat[#flat + 1] = (i % 20) / 20 + 0.02 * math.sin(i)
    flat[#flat + 1] = i / 400
end
for i = 1, 30 do
    busy.roads[i] = { from = i * 1000, to = i * 1000 + 300, pts = flat, act = { combat = 200 } }
    busy.stops[i] = { kind = "stop", from = i * 1000 + 300, to = i * 1000 + 900, seconds = 600 + i * 300,
        x = (i % 6) / 6 + 0.05, y = math.floor(i / 6) / 6 + 0.05, sdx = 0.03, sdy = 0.02, rho = 0 }
end
for i = 1, 500 do
    busy.stops[#busy.stops + 1] = { kind = "stop", from = 100000 + i * 200, to = 100000 + i * 200 + 150 + i,
        seconds = 150 + i, x = (i % 25) / 25, y = math.floor(i / 25) / 20, r = 15 }
end
local bprims, bc = Ink.Build(busy, box, { kind = function() return "stayed" end })
Check(bc.quads <= CAP.quads and bc.dots <= CAP.dots and bc.dabs <= CAP.dabs,
    ("a cap was passed: %d quads, %d dots, %d dabs"):format(bc.quads, bc.dots, bc.dabs))
Eq(bc.stops, CAP.stops, "the stops considered passed their cap")
Check(bc.step > Ink.ROAD.step, "the step did not grow under the cap")
Check(bc.dabs > CAP.dabs - POOL.perPool, "the busy sheet did not reach its dabs")
local quads, discs = 0, 0
local unordered = 0
for i, prim in ipairs(bprims) do
    if i > 1 and bprims[i - 1].layer > prim.layer then unordered = unordered + 1 end
    if prim.k == "q" then quads = quads + 1 else discs = discs + 1 end
end
Eq(unordered, 0, "primitives out of layer order")
Check(quads + discs == #bprims and discs > 0 and quads > 0, "the primitives' kinds")

--------------------------------------------------------------------------
Section("the pen: a broad nib, flow in the curves, lag, beads")

local PEN, ROAD = Pen.PEN, Ink.ROAD
-- The pen's own effects alone: no wobble or flicker while measuring.
local wobble, flicker = ROAD.wobble, ROAD.flicker
ROAD.wobble, ROAD.flicker = 0, 0

-- A road drawn at pressure p, measured at each vertex: its width (with the
-- mitre taken out), the nib's share of it, and its piece's alpha; and its
-- road-layer discs (beads). `fresh` leaves its start free (a pen set down).
local function Profile(flat, p, fresh, room)
    local out = {}
    local ends = fresh and {} or { first = { e = { x = -1e4, y = -1e4, a1 = 3, a2 = 3, theta = 0 }, T = 0,
        tint = Ink.TINT.stayed } }
    local _, dots = Ink.Road(out, { from = 0, to = 300 }, flat, p, ends, 5, room or { quads = 9999, dots = 9999 })
    local P, total = Pen.Resample(Pen.Chaikin(flat, ROAD.smooth), ROAD.step)
    local M = Pen.Mitres(P)
    local quads, beads, at = {}, {}, {}
    for _, prim in ipairs(out) do
        if prim.layer == LAYER.road then
            if prim.k == "q" then quads[#quads + 1] = prim else beads[#beads + 1] = prim end
        end
    end
    for i = 1, #quads do
        local q, a, b = quads[i], P[math.max(i - 1, 1)], P[math.min(i + 1, #P)]
        local w = math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2) / M[i].k
        at[i] = { x = P[i].x, y = P[i].y, s = P[i].s, w = w, nib = Pen.Nib(b.x - a.x, b.y - a.y), a = q.a }
        at[i].ink = w / at[i].nib * q.a
    end
    return at, quads, beads, total, dots
end
local function Mean(at, key, from, to)
    local sum, n = 0, 0
    for i = from or 1, to or #at do sum, n = sum + at[i][key], n + 1 end
    return sum / n
end
-- The vertex nearest a point of the sheet.
local function Near(at, x, y)
    local best, d = nil, math.huge
    for _, v in ipairs(at) do
        local dd = (v.x - x) ^ 2 + (v.y - y) ^ 2
        if dd < d then best, d = v, dd end
    end
    return best
end
local function Line(x1, y1, x2, y2, n)
    local pts = {}
    for k = 0, n do
        pts[#pts + 1], pts[#pts + 2] = x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n
    end
    return pts
end

-- The nib: up and to the right (along it) thinner than down and to the right.
local upRight = Profile(Line(100, 300, 300, 100, 10), 0.45)
local downRight = Profile(Line(100, 100, 300, 300, 10), 0.45)
Check(Mean(upRight, "w", 5, #upRight - 5) < 0.6 * Mean(downRight, "w", 5, #downRight - 5),
    ("up-right is not thinner than down-right: %.2f against %.2f"):format(Mean(upRight, "w", 5, #upRight - 5),
        Mean(downRight, "w", 5, #downRight - 5)))
local function Alphas(at, from, to)
    local lo, hi = math.huge, 0
    for i = from, to do lo, hi = math.min(lo, at[i].a), math.max(hi, at[i].a) end
    return lo, hi
end
local lo1, hi1 = Alphas(upRight, 5, #upRight - 5)
local lo2, hi2 = Alphas(downRight, 5, #downRight - 5)
Check(math.abs(lo1 - lo2) < 1e-9 and math.abs(hi1 - hi2) < 1e-9, "the nib changed the ink's alpha, not only its width")

-- A full circle: thick and thin by direction, its mean about the plain width.
local circle = {}
for k = 0, 72 do
    local a = 2 * math.pi * k / 72
    circle[#circle + 1], circle[#circle + 2] = 200 + 40 * math.cos(a), 200 + 40 * math.sin(a)
end
local round = Profile(circle, 0.45)
local thinnest, thickest = math.huge, 0
for i = 3, #round - 3 do
    thinnest, thickest = math.min(thinnest, round[i].w), math.max(thickest, round[i].w)
end
Check(thickest > 1.8 * thinnest, ("the circle's width does not follow the nib: %.2f to %.2f"):format(thinnest, thickest))
local held = {}
for k, v in pairs(PEN) do held[k] = v end
PEN.nib = { angle = 40, thin = 1, thick = 1 }
PEN.flow = { window = 6, radius = 0, power = 1, cap = 1, straight = 1, widthGain = 1, alphaGain = 0, lag = 10, loaded = 1 }
local plain = Profile(circle, 0.45)
for k, v in pairs(held) do PEN[k] = v end
local ratio = Mean(round, "w", 3, #round - 3) / Mean(plain, "w", 3, #plain - 3)
Check(ratio > 0.9 and ratio < 1.1, ("the circle's mean width drifted from the plain line's: %.2f"):format(ratio))

-- Flow: a tight curve carries more ink than a straight at the same pace,
-- the nib taken out. A long lead-in first, so a fresh pen's load is gone.
local function Bend(radius, turn, lead, after, reverse)
    local pts = Line(0, 100, lead, 100, math.ceil(lead / 10))
    local steps = math.max(4, math.ceil(radius * turn / 2))
    for k = 1, steps do
        local a = turn * k / steps
        pts[#pts + 1], pts[#pts + 2] = lead + radius * math.sin(a), 100 + radius * (1 - math.cos(a))
    end
    local ex, ey = pts[#pts - 1], pts[#pts]
    local dx, dy = math.cos(turn), math.sin(turn)
    for k = 1, math.ceil(after / 10) do
        pts[#pts + 1], pts[#pts + 2] = ex + dx * k * 10, ey + dy * k * 10
    end
    if reverse then
        local r = {}
        for k = #pts - 1, 1, -2 do r[#r + 1], r[#r + 2] = pts[k], pts[k + 1] end
        pts = r
    end
    return pts, ex, ey, dx, dy
end
local curvy = Profile(Bend(8, math.pi / 2, 80, 90), 0.45)
local straight = Profile(Line(0, 100, 300, 100, 30), 0.45)
local most = 0
for _, v in ipairs(curvy) do
    if v.x > 76 then most = math.max(most, v.ink) end
end
local plainInk = Near(straight, 150, 100).ink
Check(most > 1.15 * plainInk, ("a tight curve carries no more ink: %.3f against %.3f"):format(most, plainInk))
Check(math.abs(Near(curvy, 40, 100).ink - plainInk) < 0.02 * plainInk, "the lead-in is not a plain straight")

-- Lag: the ink built in the curve carries on past it the way it was walked.
local pts, ex, ey, dx, dy = Bend(8, math.pi / 2, 80, 90)
local forward = Profile(pts, 0.45)
local backward = Profile(Bend(8, math.pi / 2, 80, 90, true), 0.45)
local A, A30 = { ex + dx * 10, ey + dy * 10 }, { ex + dx * 40, ey + dy * 40 }
local B, B30 = { 70, 100 }, { 40, 100 }
local function InkAt(at, pt) return Near(at, pt[1], pt[2]).ink end
Check(InkAt(forward, A) > 1.03 * InkAt(forward, A30), ("no ink carried past the curve: %.3f against %.3f"):format(
    InkAt(forward, A), InkAt(forward, A30)))
Check(InkAt(forward, B) < 1.01 * InkAt(forward, B30), "the ink came before the curve, walked forward")
Check(InkAt(backward, B) > 1.03 * InkAt(backward, B30), "walked back, no ink carried past the curve")
Check(InkAt(backward, A) < 1.01 * InkAt(backward, A30), "walked back, the ink stayed on the old side")

-- Beads: at sharp corners, none on a gentle arc, a fresh pen's at its start.
local zigzag = { 0, 100, 30, 100 }
for k = 1, 6 do zigzag[#zigzag + 1], zigzag[#zigzag + 2] = 30 + 9 * k, k % 2 == 1 and 78 or 100 end
zigzag[#zigzag + 1], zigzag[#zigzag + 2] = 120, 100
local corners = Pen.Beads(Pen.Chaikin(zigzag, ROAD.smooth))
Check(#corners >= 4, "the zig-zag's corners have no beads: " .. #corners)
local arc = {}
for k = 0, 20 do
    local a = math.pi / 2 * k / 20
    arc[#arc + 1], arc[#arc + 2] = 100 + 60 * math.cos(a), 100 + 60 * math.sin(a)
end
Eq(#Pen.Beads(Pen.Chaikin(arc, ROAD.smooth)), 0, "beads on a gentle arc")
local _, _, zbeads = Profile(zigzag, 0.45, true)
Eq(#zbeads, #corners + 1, "the zig-zag's beads drawn, and the fresh pen's")
local _, _, held2 = Profile(arc, 0.45, false)
Eq(#held2, 0, "beads drawn on a gentle arc carried out of a stop")
local _, _, few, _, fewDots = Profile(zigzag, 0.45, true, { quads = 9999, dots = 2 })
Check(#few <= 2 and fewDots <= 2, "the beads passed the dots' room")

-- Never dashes: edges shared, widths within the pen's, alpha never gone,
-- at every pace, the dry pen too.
for _, p in ipairs({ 0, 0.2, 0.45, 0.8, 1 }) do
    for _, flat in ipairs({ circle, zigzag, (Bend(8, math.pi / 2, 80, 90)) }) do
        local at, quads, _, total = Profile(flat, p, true)
        local apart, narrow, wide, faint = 0, math.huge, 0, math.huge
        for i, v in ipairs(at) do
            if i > 1 then
                local a, b = quads[i - 1], quads[i]
                if math.abs(a.x2 - b.x1) > 1e-9 or math.abs(a.y2 - b.y1) > 1e-9 or math.abs(a.x3 - b.x4) > 1e-9
                    or math.abs(a.y3 - b.y4) > 1e-9 then
                    apart = apart + 1
                end
            end
            if v.s >= ROAD.lift and total - v.s >= ROAD.lift then
                narrow, wide = math.min(narrow, v.w), math.max(wide, v.w)
            end
            faint = math.min(faint, v.a)
        end
        Eq(apart, 0, ("pieces apart at pace %.2f"):format(p))
        Check(narrow >= PEN.width[1] - 1e-6 and wide <= PEN.width[2] + 1e-6,
            ("a width past the pen's at pace %.2f: %.2f to %.2f"):format(p, narrow, wide))
        Check(faint > 0.1, ("the line faded out at pace %.2f: %.3f"):format(p, faint))
        Eq(#quads, #at, "a piece left out")
    end
end

ROAD.wobble, ROAD.flicker = wobble, flicker

--------------------------------------------------------------------------
Section("a plate stands on the page, a strip lies on it (JRN-21, JRN-22)")

-- Construction and logic only: whether it looks like a print glued in is
-- for the client. A plate with all four corners and its lower right lifted.
do
    local mock = T.mock
    local Plate = ns.UI.JourneyPlate
    local host = CreateFrame("Frame")
    local slot = { x = 8, y = 14, w = 300, h = 204, t = -1.4, pad = 8, pc = 24, corners = { "tl", "tr", "bl", "br" },
        lift = "br" }
    local plate = Plate(host, slot)
    local sheet = { mapID = 1412, stops = {}, roads = {}, flights = {}, pins = {}, dungeons = {}, meetings = {} }
    local window = Plate.Window(1412, 0.5, 0.5, slot.w - 2 * slot.pad, slot.h - 2 * slot.pad)
    local function Draw()
        plate:Draw(sheet, { from = 0, to = 1e12 }, window, { moments = {}, fights = {}, now = 1000 })
    end
    -- The shown textures on `frame` in `layer` (and `sublevel`).
    local function On(frame, layer, sublevel)
        local list = {}
        for _, w in ipairs(mock.frames) do
            if w.frameType == "Texture" and w.parent == frame and w:IsShown() and w.recorded.layer == layer
                and (sublevel == nil or w.recorded.sublevel == sublevel) then
                list[#list + 1] = w
            end
        end
        return list
    end
    local function Alpha(t) return t.recorded.calls.SetColorTexture[4] end

    ns.SetSetting("flatSheets", false)
    Draw()
    local c = plate.counts
    -- The shadow: soft bands along the bottom and the right, in pieces
    -- where the lifted corner's height changes, a core over each; each a
    -- gradient on its four corners, turned with the card.
    Eq(c.shadow, 4, "the plate's soft shadow is not two bands, cut at the lifted corner")
    Eq(c.core, 4, "the plate's contact shadow")
    local soft = On(plate.sheet, "BACKGROUND", -8)
    Eq(#soft, c.shadow, "the soft shadow's bands")
    -- The glue lies over the soft shadow (10 Oct: under it, it could not be
    -- seen), the contact line over both; the glue's gloss over the card's
    -- frame, so over the contact line too.
    Check(#On(plate.sheet, "BACKGROUND", -7) >= 3 * 2, "the glue's beads are not over the soft shadow")
    Check(#On(plate.sheet, "BACKGROUND", -6) >= c.core, "the contact line is not over the glue")
    -- Strong enough to be seen at the book's size (10 Oct, in the client):
    -- a dark contact line and a soft band, the lifted corner's wider.
    Check(Plate.SHADOW.core.alpha >= 0.35 and Plate.SHADOW.core.out >= 1.4, "the plate's contact line is too faint")
    Check(Plate.SHADOW.alpha >= 0.25 and plate.reach.glued >= 4, "the plate's soft shadow is too faint")
    Check(plate.reach.lifted >= 1.8 * plate.reach.glued, "the lifted corner's shadow is not much wider")
    -- The light on the top and left edges is a catch-light on the cut, not
    -- a bevel inside the card (10 Oct, in the client).
    Check(Plate.THICKNESS.lightAlpha <= 0.25 and Plate.THICKNESS.at < 0, "the card's light edge reads as a bevel")
    local S, P = Plate.PLATE.stock, ns.Style.PAPER
    Check(S[1] + S[2] + S[3] > P[1] + P[2] + P[3] + 0.2 and S[1] < 0.93 and S[3] < S[1] - 0.15,
        "the card is not an aged stock, lighter than the page and warm")
    for _, band in ipairs(soft) do
        Check(band.bent and band.recorded.calls.SetGradient, "a shadow band is not a gradient on its corners")
    end
    Check(plate.reach and plate.reach.lifted > plate.reach.glued + 3,
        "the lifted corner's shadow does not reach further than the glued card's")
    Check(plate.reach.lifted <= 10, "the lifted corner's shadow reaches past the page's margin: " .. plate.reach.lifted)
    Eq(c.edges, 4, "the card has no thickness")
    Check(c.lift > 2, "the lifted corner throws no shadow of its own")
    -- Glue: beads and their gloss, the same every time it is drawn.
    Check(c.glue >= 3 * 3 and c.gloss >= 3, "the glue is not beads with a gloss: " .. c.glue)
    local glue, gloss = c.glue, On(plate.over, "BACKGROUND", -8)
    Eq(#gloss, c.gloss, "the glue's gloss")
    local function Places(list)
        local out = {}
        for _, t in ipairs(list) do
            local p = t.recorded.points[1]
            out[#out + 1] = p and (p.args[3] .. "," .. p.args[4]) or "-"
        end
        table.sort(out)
        return table.concat(out, " ")
    end
    local before = Places(gloss)
    Draw()
    Eq(plate.counts.glue, glue, "the glue moved when drawn again")
    Eq(Places(On(plate.over, "BACKGROUND", -8)), before, "the gloss moved when drawn again")
    -- The corners: kraft, not black; each with the light on its fold, the
    -- lower right's fold facing the light, the upper left's away.
    Eq(plate.counts.corners, 4, "the photo corners")
    Eq(plate.counts.folds, 4, "the photo corners carry no fold")
    local pocket = On(plate.over, "OVERLAY", 7)[1]
    local r, g, b = unpack(pocket.recorded.calls.SetColorTexture, 1, 3)
    Check(r > 0.2 and r > b * 2, "a photo corner is black, not kraft")
    local folds = On(plate.folds, "OVERLAY")
    Eq(#folds, 4, "the folds")
    Check(Alpha(folds[4]) > Alpha(folds[2]) and Alpha(folds[2]) > Alpha(folds[1]),
        "the folds do not take the light by how they face it")
    -- The print: its edges darkened under the ink, toned (tinted in the
    -- mock: it cannot desaturate).
    Eq(#On(plate.content, "BORDER", 4), 4, "the print has no darkened edges")
    Eq(plate.toned, "tinted", "the art is not toned where it cannot be desaturated")

    -- Laid flat: no shadow, edges, glue, vignette or folds; the corners
    -- lie flat.
    ns.SetSetting("flatSheets", true)
    Draw()
    c = plate.counts
    Eq(c.shadow + c.core + c.edges + c.glue + c.folds + c.lift, 0, "laid flat, the plate keeps its depth")
    Eq(c.corners, 4, "laid flat, the photo corners are gone")
    Eq(#On(plate.content, "BORDER", 4), 0, "laid flat, the print keeps its darkened edges")
    Eq(#On(plate.sheet, "BACKGROUND", -7), 0, "laid flat, a shadow band is still shown")
    ns.SetSetting("flatSheets", false)

    -- Where corners cannot move: the shadow in boxes, the corners in L
    -- strips, no folds.
    plate.canBend = false
    Draw()
    c = plate.counts
    Check(c.shadow > 0 and c.core > 0, "without corners, the plate casts no shadow")
    for _, band in ipairs(On(plate.sheet, "BACKGROUND", -7)) do
        Check(not band.bent, "without corners, a shadow band kept its corners")
    end
    Eq(c.corners, 4 * 2, "without corners, the photo corners are not L strips")
    Eq(c.folds, 0, "without corners, a fold was drawn")
    plate.canBend = true

    -- A strip: its soft shadow, its contact shadow, tape that shows.
    local STRIP, TAPE = ns.UI.PAPER_STRIP.STRIP, ns.UI.PAPER_STRIP.TAPE
    local strip = ns.UI.PaperStrip(host)
    local function Lay(seed)
        strip:SetNote({ name = "Bram Redfen", what = "15 min together", guid = "Player-1-0001", seed = seed })
        strip:Layout(20, 300, 160)
    end
    Lay("Bram:1412")
    Check(strip.shadow:IsShown() and strip.soft[1]:IsShown() and strip.soft[2]:IsShown(),
        "a strip throws no shadow")
    for _, band in ipairs(strip.soft) do
        Check(band.bent and band.recorded.calls.SetGradient, "a strip's shadow band is not a gradient on its corners")
    end
    Check(strip.paper.bent, "a strip is cut square")
    Check(strip.tape:IsShown() and strip.tapeEdges[1]:IsShown() and strip.tapeEdges[2]:IsShown(),
        "the tape's edges do not show")
    Check(Alpha(strip.tape) >= 0.45 and Alpha(strip.tapeEdges[1]) >= 0.25, "the tape is too faint to see")
    local tr, box = strip.tapeRect, strip.box
    Check(tr[2] < box[2] - 2 and tr[4] > box[2] + 2, "the tape does not lie on both the slip and the page")
    -- Stable: laid again, the same cut.
    local cut = table.concat({ unpack(strip.paper.recorded.calls.SetVertexOffset, 1, 3) }, ",")
    Lay("Bram:1412")
    Eq(table.concat({ unpack(strip.paper.recorded.calls.SetVertexOffset, 1, 3) }, ","), cut,
        "a strip was cut another way when laid again")
    -- Some slips are torn at their right end, some cut: seeded.
    local torn, cutClean
    for n = 1, 40 do
        Lay("someone:" .. n)
        local shown = 0
        for _, tooth in ipairs(strip.teeth) do
            if tooth:IsShown() then shown = shown + 1 end
        end
        if strip.torn then
            torn = shown
        else
            cutClean = shown
        end
        if torn and cutClean then break end
    end
    Eq(torn, STRIP.torn.teeth, "no slip is torn off")
    Eq(cutClean, 0, "a cut slip shows a tear")
    -- Lifted under the mouse, its shadow falls further out; laid down, back.
    Lay("Bram:1412")
    local function SoftAt() return table.concat({ unpack(strip.soft[1].recorded.calls.SetVertexOffset, 1, 3) }, ",") end
    local lying = SoftAt()
    strip:Hover(true)
    strip.scripts.OnUpdate(strip, TAPE.hover.time)
    Check(SoftAt() ~= lying, "the lifted strip's shadow did not move")
    strip:Hover(false)
    strip.scripts.OnUpdate(strip, TAPE.hover.time)
    Eq(SoftAt(), lying, "laid down, the strip's shadow is not where it was")
    -- Laid flat: no shadow, no tear, no shine, square; the tape and its
    -- lower edge still there.
    ns.SetSetting("flatSheets", true)
    for n = 1, 40 do
        Lay("someone:" .. n)
        for _, tooth in ipairs(strip.teeth) do Check(not tooth:IsShown(), "laid flat, a slip is torn") end
    end
    Check(not strip.shadow:IsShown() and not strip.soft[1]:IsShown() and not strip.soft[2]:IsShown(),
        "laid flat, a strip throws a shadow")
    Check(not strip.paper.bent and not strip.tapeEdges[2]:IsShown(), "laid flat, a strip is uneven or its tape shines")
    Check(strip.tape:IsShown() and strip.tapeEdges[1]:IsShown(), "laid flat, the tape is gone")
    ns.SetSetting("flatSheets", false)
    -- Where corners cannot move: square, on boxes of shadow.
    strip.canBend = false
    Lay("Bram:1412")
    Check(strip.soft[1]:IsShown() and not strip.soft[1].bent and not strip.paper.bent,
        "without corners, a strip is not square on boxes of shadow")
    strip.canBend = true
end
