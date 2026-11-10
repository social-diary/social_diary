-- How far along the way a moment lies, from what stands on the way (the
-- route model, Core/Pace/Model.lua). A death, a wipe or a roll on the way
-- has only a time; Core/DungeonRun.lua says between which kills, and how
-- many seconds into that leg (`dt`) and, when the leg's boss fell, how long
-- the leg took (`known`). For a dungeon with pace data (Core/Pace/*.lua:
-- its entrance, bosses and trash packs, in game yards) this turns that
-- into yards along the way the map draws, the usual one or the player's
-- own (UI/Dungeon/Print.lua's LegPoint): walking takes time, each pack on
-- the way holds the group up, and deaths come mostly in pulls. Without
-- pace data, or where anything below does not hold, nil: the map keeps its
-- own guess (a share of the time between kills; eased on an open leg).
--
-- Laid on the addon's own way, not the data's: the handover's legs were
-- the shortest ways between bosses on its own map; Dungeon Crawler
-- Forever's usual way clears the side rooms (Ragefire Chasm: 520 yd to
-- Oggleflint where the shortest way is 265), so the packs are laid on the
-- way drawn, here, every time it is.
--
--   DungeonPace.Fit(instanceID)        the data's yards on the map's floor, or nil (FIT)
--   DungeonPace.Course(visit, route)   the way in yards with its pulls, or nil
--   DungeonPace.Place(course, i0, i1, dt, known, npc)
--                                      yards along the way (from its start) for a
--                                      moment dt seconds into the leg from point i0
--                                      to the boss at point i1, at a pull of the
--                                      killer `npc` where the leg has one (KILLER);
--                                      the model's answer, the leg, and how
--                                      ("killer" or "time")
--   DungeonPace.PlaceGroup(course, i0, i1, items, known)
--                                      the same for moments that were one pull (a
--                                      wipe's deaths): one place for all of them
--   DungeonPace.Along(course, yd)      the segment k (point k to k + 1) and how far
--                                      along it (0..1) that is
--   DungeonPace.Project(course, gx, gy) the way's point nearest game yards gx, gy:
--                                      yards along it, yards off it
--
-- Flat within a floor: the fit and the packs are in x and y only. A pack
-- on a level under or over the way (a ledge, a lower cave) that lies
-- within PULL.radius of it in x and y is a pull on it (3 Nov 2026,
-- Ragefire Chasm: a death to a Shaman below the corridor went to the
-- corridor's Shaman pack). The data has each spawn's height; the way has
-- none yet. Floors: a dungeon drawn on several floors (the Deadmines: the
-- mines, then Ironclad Cove) is fitted on every floor its bosses stand on,
-- each by its own art bounds (Fit); all of them are in one game-yard
-- frame, so the way runs on in yards where it goes down a floor. Each pack
-- carries the floor it is drawn on (`floor`, from the build), and is a
-- pull only on a stretch of that floor: the foundry's upper ledge is drawn
-- on the mines' floor and Gilnid's floor 30 yd under it on the cove's, at
-- the same x and y. A combined map of several levels (pieces at their own
-- scales) has no fit and keeps the map's own guess.
--
-- A course: { instanceID, route, floor (the first), cum (yards to each
-- point), game (each point in game yards, false off the floors fitted),
-- floors (each point's floor), broken (segment k is off the floors
-- fitted), pulls ({ at (yards from the way's start), elites, size, names,
-- npcs (its NPC IDs), boss (a guard's), pack (its index), floor }, in order
-- along the way) }.

local addonName, ns = ...

local DungeonPace = {}
ns.DungeonPace = DungeonPace

-- The data's yards on the map's floors. First each floor's art bounds
-- (Dungeon Crawler Forever's Art data, `bounds` = { x1, y1, x2, y2 }: the
-- rectangle of game yards the picture covers, Blizzard's own map rectangle):
-- the picture's x runs from game y2 down to y1, its y from game x2 down to
-- x1. Exact, and blind to the boss pins, which DCF draws where they read
-- well, not always where the bosses stand (4 Nov 2026: Zul'Farrak's pins
-- 23 to 64 yd off, Roogug's 160, Glutton's 95; fitted through them, the
-- maps came out stretched by up to a fifth and three dungeons were
-- refused). The pins' distances are kept (`worst`) as a note on how DCF
-- drew them, never a reason to refuse. A floor DCF drew as its own art,
-- without bounds, takes the pace data's (`bounds`, by uiMapID) where that
-- art lies over a Blizzard floor's rectangle (Wailing Caverns, 9 Nov 2026:
-- DCF's 800431 over floor 279, the bosses' pins within 2% of their spawns
-- there). Bosses on several floors: every one
-- of those floors needs bounds, else no fit. Where the one floor has no
-- bounds, the old fit: an affine, least squares over the entrance and the
-- bosses, at least `least` anchors on one floor, none off by more than
-- `most` yards, else no fit and the dungeon keeps the map's own guess.
-- DCF's data can be wrong too (bounds, pins, the usual way):
-- tests/pace_data.lua holds each dungeon to its packs lying near the way
-- drawn, a check that leans on none of the pins.
local FIT = { least = 4, most = 12 }
-- A pack is a pull on the way where the way passes within `radius` yards
-- of it, on the first stretch that does (the pipeline's PULL_RADIUS); a
-- guard of a boss's room (`boss`) is pulled just before that boss, on the
-- leg to it only.
local PULL = { radius = 15 }
-- What killed a death on the way (the death recap's NPC ID, Features/
-- Deaths/Capture.lua) is the strongest thing known of where it was: only
-- the leg's pulls holding that creature (or the one that summons it, the
-- data's `summons`) may be where it died, the time choosing among them.
-- The time weighs each (Weights: exactly, with a pace spread of `spread`)
-- and, going along the way, the one where the weight passes half of all of
-- theirs is it: a later time never puts it on an earlier pull (4 Nov 2026,
-- the pace explainer: taking the heaviest flickered between Trogg pulls
-- 300 yd apart from one second to the next, the model's sampling grid and
-- a near flat spread of 1.0 between them; 0.35, the model's own, follows
-- the time best). Where the time gives none of them any weight, the one
-- nearest the time's own place. No such pull on the leg (a patrol, a
-- creature not in the data, a killer from another leg): the time alone.
local KILLER = { spread = 0.35 }
DungeonPace.FIT, DungeonPace.PULL, DungeonPace.KILLER = FIT, PULL, KILLER

local function Norm(name) return ns.Dungeons.Norm(name) end

--------------------------------------------------------------------------
-- The fit
--------------------------------------------------------------------------

-- Least squares for v = a x + b y + c over `rows` ({ x, y, v }).
local function Solve(rows)
    local N, r = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { 0, 0, 0 }
    for _, row in ipairs(rows) do
        local u = { row[1], row[2], 1 }
        for i = 1, 3 do
            for j = 1, 3 do N[i][j] = N[i][j] + u[i] * u[j] end
            r[i] = r[i] + u[i] * row[3]
        end
    end
    for i = 1, 3 do
        if math.abs(N[i][i]) < 1e-12 then return nil end
        for k = i + 1, 3 do
            local f = N[k][i] / N[i][i]
            for j = i, 3 do N[k][j] = N[k][j] - f * N[i][j] end
            r[k] = r[k] - f * r[i]
        end
    end
    local s = {}
    for i = 3, 1, -1 do
        local acc = r[i]
        for j = i + 1, 3 do acc = acc - N[i][j] * s[j] end
        s[i] = acc / N[i][i]
    end
    return s
end

local fits = {}

-- A floor's transforms from its art bounds { x1, y1, x2, y2 }.
local function ByBounds(b)
    if not (b and b[1] and b[2] and b[3] and b[4] and b[3] > b[1] and b[4] > b[2]) then return nil end
    local x1, y1, x2, y2 = b[1], b[2], b[3], b[4]
    return {
        ToFloor = function(gx, gy) return (y2 - gy) / (y2 - y1), (x2 - gx) / (x2 - x1) end,
        ToGame = function(fx, fy) return x2 - fy * (x2 - x1), y2 - fx * (y2 - y1) end,
        bounds = b,
    }
end

-- A floor drawn as one picture of several pieces at their own scales (the
-- pace data's `pieces[uiMapID]`, Shadowfang Keep's overview, 9 Nov 2026):
-- each piece { name, rects (fractions of the picture, tried in order),
-- game (gx = g1 + g2 fx + g3 fy, gy = g4 + g5 fx + g6 fy) } becomes a floor
-- of its own in `floors`, keyed uiMapID * 10 + n, its `sheet` the picture's
-- uiMapID; packs carry that key. The floor itself takes a point of the
-- picture to game yards through the piece that holds it, and says which
-- (`Piece`); it has no way back without a piece named.
local function ByPieces(f, list, floors)
    if type(list) ~= "table" or #list == 0 then return nil end
    local keys = {}
    for n, pc in ipairs(list) do
        local g = pc.game
        local det = g and #g == 6 and (g[2] * g[6] - g[3] * g[5])
        if not det or math.abs(det) < 1e-12 then return nil end
        local key = f * 10 + n
        keys[#keys + 1] = key
        floors[key] = {
            ToGame = function(fx, fy) return g[1] + g[2] * fx + g[3] * fy, g[4] + g[5] * fx + g[6] * fy end,
            ToFloor = function(gx, gy)
                local dx, dy = gx - g[1], gy - g[4]
                return (g[6] * dx - g[3] * dy) / det, (g[2] * dy - g[5] * dx) / det
            end,
            rects = pc.rects, sheet = f, name = pc.name,
        }
    end
    local function Piece(fx, fy)
        for _, key in ipairs(keys) do
            for _, r in ipairs(floors[key].rects or {}) do
                if fx >= r[1] and fx <= r[3] and fy >= r[2] and fy <= r[4] then return key end
            end
        end
    end
    return {
        pieces = keys, Piece = Piece,
        ToGame = function(fx, fy)
            local key = Piece(fx, fy)
            if key then return floors[key].ToGame(fx, fy) end
        end,
        ToFloor = function() return nil end,
    }
end

-- A fit over `floors` ({ [uiMapID] = { ToFloor, ToGame, bounds } }), the
-- floors in `order` (the first the way in's): ToGame(fx, fy, floor) takes
-- a floor's point to game yards (the first floor where none is named);
-- ToFloor(gx, gy, floor) the way back, and, where no floor is named, on the
-- first floor whose bounds hold the point (else the first), returning the
-- floor third.
local function Make(order, floors, method, worst, worstName, anchors)
    local first = order[1]
    return {
        floor = first, order = order, floors = floors, method = method, worst = worst, worstName = worstName,
        anchors = anchors,
        ToGame = function(fx, fy, f)
            local t = floors[f or first]
            if t then return t.ToGame(fx, fy) end
        end,
        ToFloor = function(gx, gy, f)
            if not f then
                f = first
                for _, id in ipairs(order) do
                    local b = floors[id].bounds
                    if b and gx >= b[1] and gx <= b[3] and gy >= b[2] and gy <= b[4] then
                        f = id
                        break
                    end
                end
            end
            local t = floors[f]
            if not t then return nil end
            local fx, fy = t.ToFloor(gx, gy)
            if fx == nil then return nil end
            return fx, fy, t.sheet or f
        end,
    }
end

-- The data's yards on the map's floors for `instanceID`: { floor (the
-- first floor, the way in's), order (the floors, the first first), floors
-- ({ [uiMapID] = { ToFloor, ToGame, bounds } }), ToFloor (game x, y, and a
-- floor -> that floor's x, y, and the floor), ToGame (back), method
-- ("bounds" or "anchors"), worst (the pin or anchor furthest off, yards,
-- and `worstName`), anchors (how many pins and way in were compared) }, or
-- nil (no data, no boss on the map, a floor without bounds among several
-- or, without bounds, too few anchors or one too far off: FIT). Worked out
-- once.
function DungeonPace.Fit(instanceID)
    if fits[instanceID] ~= nil then return fits[instanceID] or nil end
    local data = ns.PaceData and ns.PaceData[instanceID]
    local fit
    if data then
        local D, pairs_, order, seen = ns.Dungeons, {}, {}, {}
        for _, b in ipairs(data.bosses or {}) do
            local m = D.Boss(instanceID, b.name)
            if m and m.floor and m.x then
                local f = tonumber(m.floor)
                if not seen[f] then
                    seen[f] = true
                    order[#order + 1] = f
                end
                pairs_[#pairs_ + 1] = { b.x, b.y, m.x, m.y, b.name, f }
            end
        end
        local first = order[1]
        local door = first and data.entrance and D.Entrance(instanceID, first)
        if door then pairs_[#pairs_ + 1] = { data.entrance.x, data.entrance.y, door.x, door.y, "the way in", first } end
        local floors, all = {}, first ~= nil
        for _, f in ipairs(order) do
            local fl = D.Floor(instanceID, f)
            floors[f] = ByBounds(fl and fl.bounds) or ByBounds(data.bounds and data.bounds[f])
                or ByPieces(f, data.pieces and data.pieces[f], floors)
            if not floors[f] then all = false end
        end
        if all then
            local worst, worstName = 0, nil
            for _, p in ipairs(pairs_) do
                local gx, gy = floors[p[6]].ToGame(p[3], p[4])
                local off = gx and math.sqrt((gx - p[1]) ^ 2 + (gy - p[2]) ^ 2) or math.huge
                if off > worst then worst, worstName = off, p[5] end
            end
            local method = "bounds"
            for _, f in ipairs(order) do
                if floors[f].pieces then method = "pieces" end
            end
            fit = Make(order, floors, method, worst, worstName, #pairs_)
        elseif #order == 1 and #pairs_ >= FIT.least then
            local rx, ry = {}, {}
            for i, p in ipairs(pairs_) do
                rx[i], ry[i] = { p[1], p[2], p[3] }, { p[1], p[2], p[4] }
            end
            local U, V = Solve(rx), Solve(ry)
            local det = U and V and (U[1] * V[2] - U[2] * V[1])
            if det and math.abs(det) > 1e-12 then
                local function ToFloor(gx, gy) return U[1] * gx + U[2] * gy + U[3], V[1] * gx + V[2] * gy + V[3] end
                local function ToGame(fx, fy)
                    local du, dv = fx - U[3], fy - V[3]
                    return (V[2] * du - U[2] * dv) / det, (-V[1] * du + U[1] * dv) / det
                end
                local worst = 0
                for _, p in ipairs(pairs_) do
                    local gx, gy = ToGame(p[3], p[4])
                    worst = math.max(worst, math.sqrt((gx - p[1]) ^ 2 + (gy - p[2]) ^ 2))
                end
                if worst <= FIT.most then
                    fit = Make(order, { [first] = { ToFloor = ToFloor, ToGame = ToGame } }, "anchors", worst, nil,
                        #pairs_)
                end
            end
        end
    end
    fits[instanceID] = fit or false
    return fit
end

-- Forgets the fits (tests that change the data).
function DungeonPace.Reset() fits = {} end

--------------------------------------------------------------------------
-- The way in yards, its pulls on it
--------------------------------------------------------------------------

-- The nearest point to (px, py) on the stretch a to b: how far along it
-- (yards) and how far off (yards).
local function Nearest(a, b, px, py)
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((px - a[1]) * dx + (py - a[2]) * dy) / l2)) or 0
    local qx, qy = a[1] + dx * t, a[2] + dy * t
    return t * math.sqrt(l2), math.sqrt((qx - px) ^ 2 + (qy - py) ^ 2)
end

-- `visit`'s way `route` (Core/DungeonWay.lua's points) in yards, with the
-- packs it passes as its pulls; nil without pace data or a fit, or a way
-- of fewer than two points. A jump to a linked step's far end (`pair`)
-- is no way at all; a stretch with an end off the fitted floors is
-- `broken` (nothing is placed on a leg across it). A stretch from one
-- fitted floor to another (the Deadmines' way down to the cove) is a walk
-- of its length in game yards, and packs of either floor lie on it.
function DungeonPace.Course(visit, route)
    local id = visit and visit.instanceID
    local data = id and ns.PaceData and ns.PaceData[id]
    local fit = data and DungeonPace.Fit(id)
    if not fit or type(route) ~= "table" or #route < 2 then return nil end
    local game, floors = {}, {}
    for i, p in ipairs(route) do
        local f, x, y = ns.DungeonWay.Where(id, p)
        local on = f and fit.floors[f]
        if on and on.Piece and x and y then
            -- An overview's piece: the floor from here on.
            f = on.Piece(x, y)
            on = f and fit.floors[f]
        end
        if on and x and y then
            game[i], floors[i] = { on.ToGame(x, y) }, f
        else
            game[i] = false
        end
    end
    local cum, broken = { 0 }, {}
    for i = 2, #route do
        local a, b, len = game[i - 1], game[i], 0
        if not (a and b) then
            broken[i - 1] = true
        elseif not route[i].pair then
            len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        end
        cum[i] = cum[i - 1] + len
    end
    -- Each pack on the first stretch of its floor that passes it; a guard
    -- where its boss's first stop is.
    local stops = {}
    for i, p in ipairs(route) do
        if p.boss and not stops[Norm(p.boss)] then stops[Norm(p.boss)] = i end
    end
    local pulls = {}
    for n, pack in ipairs(data.packs or {}) do
        local at
        if pack.boss then
            local i = stops[Norm(pack.boss)]
            at = i and game[i] and cum[i]
        else
            for k = 1, #route - 1 do
                local onFloor = not pack.floor or pack.floor == floors[k] or pack.floor == floors[k + 1]
                if onFloor and not broken[k] and cum[k + 1] > cum[k] then
                    local along, off = Nearest(game[k], game[k + 1], pack.x, pack.y)
                    if off <= PULL.radius then
                        at = cum[k] + along
                        break
                    end
                end
            end
        end
        if at then
            pulls[#pulls + 1] = { at = at, elites = math.max(1, pack.elites or 1), size = pack.size,
                names = pack.names, npcs = pack.npcs, boss = pack.boss, pack = n, floor = pack.floor }
        end
    end
    table.sort(pulls, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.pack < b.pack
    end)
    return { instanceID = id, route = route, floor = fit.floor, cum = cum, broken = broken, pulls = pulls,
        game = game, floors = floors }
end

-- The leg from point i0 to the boss at point i1, as the model takes it: {
-- length, pulls ({ at from its start, elites, size, npcs }), from (yards
-- along the way where it starts), to (its boss) }; from `start` yards along
-- the way where given (an anchor, Print.lua's Anchors: the rest of the leg,
-- the pull there still on it), else from point i0. nil where it is not one
-- (i1 not after i0, no boss at i1, a stretch broken, no length).
function DungeonPace.Leg(course, i0, i1, start)
    if not (course and i0 and i1 and i1 > i0 and course.route[i1]) then return nil end
    local target = course.route[i1].boss
    if not target then return nil end
    for k = i0, i1 - 1 do
        if course.broken[k] then return nil end
    end
    local from, to = course.cum[i0], course.cum[i1]
    if start then from = math.max(from, math.min(to, start)) end
    if to - from < 1 then return nil end
    local key, pulls = Norm(target), {}
    for _, p in ipairs(course.pulls) do
        local mine
        if p.boss then
            mine = Norm(p.boss) == key and p.at >= from and p.at <= to
        else
            mine = p.at >= from and p.at < to
        end
        if mine then pulls[#pulls + 1] = { at = p.at - from, elites = p.elites, size = p.size, npcs = p.npcs } end
    end
    return { length = to - from, pulls = pulls, from = from, to = target }
end

-- The leg's pulls (indices) holding creature `npc`, or what summons it.
local function Holding(course, leg, npc)
    if not npc then return nil end
    local data = ns.PaceData and ns.PaceData[course.instanceID]
    local by = data and data.summons and data.summons[npc]
    local out = {}
    for i, p in ipairs(leg.pulls) do
        for _, id in ipairs(p.npcs or {}) do
            if id == npc or id == by then
                out[#out + 1] = i
                break
            end
        end
    end
    return #out > 0 and out or nil
end

-- The normal distribution's cumulative function (Abramowitz and Stegun
-- 7.1.26, off by less than 1.5e-7).
local function Phi(z)
    local x = math.abs(z) / math.sqrt(2)
    local t = 1 / (1 + 0.3275911 * x)
    local y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t
        + 0.254829592) * t * math.exp(-x * x)
    return z >= 0 and 0.5 * (1 + y) or 0.5 * (1 - y)
end

-- How much the time weighs each pull of `leg` for a moment `dt` seconds
-- into it, at the pace spread KILLER.spread: { [pull index] = weight }, the
-- pulls it gives none left out. Worked out exactly, not on the model's grid
-- of pace factors (PlaceDeath's samples: a pull a few seconds long caught
-- two of them or three as dt moved, its weight jumping by a quarter): the
-- pace factors that put the group inside pull i (seconds a to b of the
-- model's profile) are one stretch of z, ln(dt / b) / spread to ln(dt / a)
-- / spread, kept within the model's -3 to 3; the weight is the pull's
-- danger (danger x elites) times the normal's mass over it. Not
-- normalised: only how the pulls weigh against each other counts.
function DungeonPace.Weights(leg, dt)
    local Model = ns.PaceModel
    local P = Model.DEFAULTS
    local spread = KILLER.spread
    local w = {}
    local function Z(z) return math.max(-3, math.min(3, z)) end
    for _, st in ipairs(Model.Profile(leg).steps) do
        if st.kind == "pull" then
            local mass
            if dt <= 0 then
                mass = st.t0 <= 0 and 1 or 0
            else
                local hi = st.t0 > 0 and math.log(dt / st.t0) / spread or 3
                mass = math.max(0, Phi(Z(hi)) - Phi(Z(math.log(dt / st.t1) / spread)))
            end
            if mass > 0 then
                w[st.pull] = P.danger * math.max(1, leg.pulls[st.pull].elites or 1) * mass
            end
        end
    end
    return w
end

-- Yards along the way (from its start) for moments on the leg from point
-- i0 to the boss at point i1 that happened together (one death, or the
-- deaths of a wipe: one pull, 3 Nov 2026), the leg `known` seconds long
-- when its boss fell (nil while it stands). `items` are { dt (seconds into
-- the leg), npc (what killed it, or nil) }, the first the earliest. Where
-- any of them has a killer the leg holds (KILLER): at the pull holding one
-- where, going along the way, the time's weight on them (Weights, summed
-- over all of them) passes half; where the time weighs none (or the leg
-- is known, and the time is one place), the one nearest where the time
-- puts them, on average.
-- Else where the time puts the first. From `start` yards along the way
-- where given (an anchor: the seconds are then from it, and so is
-- `known`). Then the model's answer for the first (Core/Pace/Model.lua's
-- PlaceDeath), the leg, and how: "killer" or "time". nil where the leg is
-- not one (Leg) or no time is known.
function DungeonPace.PlaceGroup(course, i0, i1, items, known, start)
    local Model = ns.PaceModel
    local first = items and items[1]
    local leg = Model and first and first.dt and DungeonPace.Leg(course, i0, i1, start)
    if not leg then return nil end
    known = known and known > 0 and known or nil
    local r = Model.PlaceDeath(leg, math.max(0, first.dt), nil, { knownKill = known })
    local held, score, sum, n = {}, {}, 0, 0
    for _, it in ipairs(items) do
        local candidates = it.dt and Holding(course, leg, it.npc)
        if candidates then
            local dt = math.max(0, it.dt)
            sum, n = sum + Model.PlaceDeath(leg, dt, nil, { knownKill = known }).yd, n + 1
            local by = known and {} or DungeonPace.Weights(leg, dt)
            for _, i in ipairs(candidates) do
                held[i] = true
                score[i] = (score[i] or 0) + (by[i] or 0)
            end
        end
    end
    if n == 0 then return leg.from + r.yd, r, leg, "time" end
    -- Along the way (the leg's pulls are in order), the one where the
    -- weight passes half of all of theirs.
    local order, total = {}, 0
    for i in pairs(held) do
        order[#order + 1] = i
        total = total + score[i]
    end
    table.sort(order)
    local best, bestW
    if total > 0 then
        local acc = 0
        for _, i in ipairs(order) do
            acc = acc + score[i]
            if acc >= total / 2 then
                best = i
                break
            end
        end
    end
    if not best then
        local mean = sum / n
        for i in pairs(held) do
            local d = math.abs(leg.pulls[i].at - mean)
            if not bestW or d < bestW or (d == bestW and i < best) then best, bestW = i, d end
        end
    end
    return leg.from + leg.pulls[best].at, r, leg, "killer"
end

-- One moment: PlaceGroup with it alone, `dt` seconds into the leg, killed
-- by creature `npc` (nil where not known).
function DungeonPace.Place(course, i0, i1, dt, known, npc)
    if not dt then return nil end
    return DungeonPace.PlaceGroup(course, i0, i1, { { dt = dt, npc = npc } }, known)
end

-- The stretch `yd` yards along the way lies on: k (point k to k + 1) and
-- how far along it (0..1); nil off the way. A stretch of no length (a
-- jump) is never the one.
function DungeonPace.Along(course, yd)
    local cum = course and course.cum
    if not cum or yd < 0 or yd > cum[#cum] + 1e-9 then return nil end
    for k = 1, #cum - 1 do
        local a, b = cum[k], cum[k + 1]
        if b > a and yd <= b + 1e-9 then return k, math.max(0, math.min(1, (yd - a) / (b - a))) end
    end
end

-- The point of the way nearest game yards gx, gy: how far along it (yards)
-- and how far off it (yards); nil off a way of any length. For checking
-- where a moment was placed against where it happened (Dev/PaceDebug.lua,
-- tests/pace.lua).
function DungeonPace.Project(course, gx, gy)
    if not course then return nil end
    local best, at
    for k = 1, #course.cum - 1 do
        local a, b = course.game[k], course.game[k + 1]
        if a and b and not course.broken[k] and course.cum[k + 1] > course.cum[k] then
            local along, off = Nearest(a, b, gx, gy)
            if not best or off < best then best, at = off, course.cum[k] + along end
        end
    end
    return at, best
end
