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
--   DungeonPace.Place(course, i0, i1, dt, known)
--                                      yards along the way (from its start) for a
--                                      moment dt seconds into the leg from point i0
--                                      to the boss at point i1; and the model's answer
--   DungeonPace.Along(course, yd)      the segment k (point k to k + 1) and how far
--                                      along it (0..1) that is
--   DungeonPace.Project(course, gx, gy) the way's point nearest game yards gx, gy:
--                                      yards along it, yards off it
--
-- A course: { instanceID, route, floor, cum (yards to each point), game
-- (each point in game yards, false off the floor fitted), broken (segment
-- k is off the floor fitted), pulls ({ at (yards from the way's
-- start), elites, size, names, boss (a guard's), pack (its index) }, in
-- order along the way) }.

local addonName, ns = ...

local DungeonPace = {}
ns.DungeonPace = DungeonPace

-- The fit of the data's yards onto the map's floor (an affine, least
-- squares over the entrance and the bosses): at least `least` anchors, all
-- on one floor, none off by more than `most` yards, else no fit, and the
-- dungeon keeps the map's own guess. (3 Nov 2026: Ragefire Chasm's five
-- anchors fit to within 5.3 yd.)
local FIT = { least = 4, most = 12 }
-- A pack is a pull on the way where the way passes within `radius` yards
-- of it, on the first stretch that does (the pipeline's PULL_RADIUS); a
-- guard of a boss's room (`boss`) is pulled just before that boss, on the
-- leg to it only.
local PULL = { radius = 15 }
DungeonPace.FIT, DungeonPace.PULL = FIT, PULL

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

-- The data's yards on the map's floor for `instanceID`: { floor, ToFloor
-- (game x, y -> the floor's x, y), ToGame (back), worst (the anchor
-- furthest off, yards), anchors (how many) }, or nil (no data, too few
-- anchors on one floor, or one too far off: FIT). Worked out once.
function DungeonPace.Fit(instanceID)
    if fits[instanceID] ~= nil then return fits[instanceID] or nil end
    local data = ns.PaceData and ns.PaceData[instanceID]
    local fit
    if data then
        local D, pairs_, floor = ns.Dungeons, {}, nil
        for _, b in ipairs(data.bosses or {}) do
            local m = D.Boss(instanceID, b.name)
            if m and m.floor and m.x then
                floor = floor or tonumber(m.floor)
                if tonumber(m.floor) ~= floor then floor = false end
                pairs_[#pairs_ + 1] = { b.x, b.y, m.x, m.y }
            end
        end
        local door = floor and data.entrance and D.Entrance(instanceID, floor)
        if door then pairs_[#pairs_ + 1] = { data.entrance.x, data.entrance.y, door.x, door.y } end
        if floor and #pairs_ >= FIT.least then
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
                    fit = { floor = floor, ToFloor = ToFloor, ToGame = ToGame, worst = worst, anchors = #pairs_ }
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
-- is no way at all; a stretch with an end off the fitted floor is
-- `broken` (nothing is placed on a leg across it).
function DungeonPace.Course(visit, route)
    local id = visit and visit.instanceID
    local data = id and ns.PaceData and ns.PaceData[id]
    local fit = data and DungeonPace.Fit(id)
    if not fit or type(route) ~= "table" or #route < 2 then return nil end
    local game = {}
    for i, p in ipairs(route) do
        local f, x, y = ns.DungeonWay.Where(id, p)
        if f == fit.floor and x and y then game[i] = { fit.ToGame(x, y) } else game[i] = false end
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
    -- Each pack on the first stretch that passes it; a guard where its
    -- boss's first stop is.
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
                if not broken[k] and cum[k + 1] > cum[k] then
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
                names = pack.names, boss = pack.boss, pack = n }
        end
    end
    table.sort(pulls, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.pack < b.pack
    end)
    return { instanceID = id, route = route, floor = fit.floor, cum = cum, broken = broken, pulls = pulls,
        game = game }
end

-- The leg from point i0 to the boss at point i1, as the model takes it: {
-- length, pulls ({ at from i0, elites, size }) }; nil where it is not one
-- (i1 not after i0, no boss at i1, a stretch broken, no length).
function DungeonPace.Leg(course, i0, i1)
    if not (course and i0 and i1 and i1 > i0 and course.route[i1]) then return nil end
    local target = course.route[i1].boss
    if not target then return nil end
    for k = i0, i1 - 1 do
        if course.broken[k] then return nil end
    end
    local from, to = course.cum[i0], course.cum[i1]
    if to - from < 1 then return nil end
    local key, pulls = Norm(target), {}
    for _, p in ipairs(course.pulls) do
        local mine
        if p.boss then
            mine = Norm(p.boss) == key and p.at >= from and p.at <= to
        else
            mine = p.at >= from and p.at < to
        end
        if mine then pulls[#pulls + 1] = { at = p.at - from, elites = p.elites, size = p.size } end
    end
    return { length = to - from, pulls = pulls, from = from, to = target }
end

-- Yards along the way (from its start) for a moment `dt` seconds into the
-- leg from point i0 to the boss at point i1, the leg `known` seconds long
-- when its boss fell (nil while it stands); and the model's answer
-- (Core/Pace/Model.lua's PlaceDeath). nil where the leg is not one (Leg)
-- or no time is known.
function DungeonPace.Place(course, i0, i1, dt, known)
    local Model = ns.PaceModel
    local leg = Model and dt and DungeonPace.Leg(course, i0, i1)
    if not leg then return nil end
    local r = Model.PlaceDeath(leg, math.max(0, dt), nil, { knownKill = known and known > 0 and known or nil })
    return leg.from + r.yd, r, leg
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
