-- Adapted from Dungeon Crawler Forever 0.1.11 (Per, GPL-3.0-or-later): the
-- route tool's edits (UI/Route.lua's RouteAdd, RouteInsert,
-- RouteDeletePoint, RouteCut, RouteConnect, RouteCloseGap,
-- RouteSelectStep, its snapshots and batches; UI/Edit.lua's
-- EditRouteMarker), changed 2026-10-28: kept on a run, not a dungeon, and
-- out of the UI, so they can be tested offline.
--
-- The way the user went on a run, drawn by them on its map
-- (.claude/dungeon-visits-prd.md §19). Saved on the visit as
--   visit.route = { { f = floor, x, y, boss, kind, tag, mboss, pair, gap }, ... }
-- in the shape of DCF's routes (ns.Dungeons.Route): a stop is `boss`
-- (where that boss stands, whatever f, x, y say), a step is `kind` (a
-- marker: stairs, a door, a trigger) with `tag` its letter or label and
-- `mboss` the boss a trigger starts, `pair` the far end of a linked step
-- (the jump to it drawn dotted), `gap` the first point of the part cut off
-- while drawing. No route on a visit is the usual way (WAY-2); an empty
-- one is a way the user cleared.
--
-- A pen is the drawing on one run while the map is out (UI/Dungeon/):
--   local pen = DungeonWay.Pen(visit, wing)
--   pen:Points()                   the way as it stands (theirs or the usual)
--   pen:Own()                      whether the run has its own way
--   pen.at                         the point selected, or nil (new points go after it)
--   pen:Add(f, x, y)               a point after the selected one, or at the end
--   pen:AddStop(name)              a stop at that boss
--   pen:AddStep(marker)            a step at a marker ({ floor, x, y, kind, label, boss }),
--                                  and its far end when it is linked
--   pen:Insert(after, f, x, y)     a point on the leg after point `after`
--   pen:Grab(i), pen:MoveTo(i, f, x, y), pen:Drop()
--                                  dragging a plain point: one undo step
--   pen:Delete(i)                  a point out (a linked pair goes together)
--   pen:Cut(k), pen:Gap(), pen:Connect(m), pen:Finish()
--                                  cut after k (the rest goes grey), join a grey point
--                                  back, the first grey point; Finish joins an open cut
--   pen:Select(i), pen:Step(delta) the selection
--   pen:Undo(), pen:CanUndo()      a step back, for as long as the pen lives (WAY-9)
--   pen:Clear()                    an empty way of their own
--   pen:Reset()                    back to the usual way, the drawing gone (WAY-10)
-- Each edit returns true (or what it says) when it did something. Nothing
-- is written until the first edit (WAY-7): it then copies the usual way.

local addonName, ns = ...

local DungeonWay = {}
ns.DungeonWay = DungeonWay

-- At most this many points on a run (WAY-5), and the places kept.
local MAX = 300
local PLACES = 1e4
DungeonWay.MAX = MAX

local function Round(v) return math.floor(v * PLACES + 0.5) / PLACES end

local function Copy(list)
    if not list then return false end
    local out = {}
    for i, p in ipairs(list) do
        local c = {}
        for k, v in pairs(p) do c[k] = v end
        out[i] = c
    end
    return out
end

-- Where a point stands: a stop where its boss does (DCF's followBosses),
-- anything else where it was put. floor, x, y.
function DungeonWay.Where(instanceID, p)
    local b = p.boss and ns.Dungeons.Boss(instanceID, p.boss)
    if b and b.floor and b.x then return tonumber(b.floor), b.x, b.y end
    return tonumber(p.f), p.x, p.y
end

-- The point nearest sheet point x, y within `reach`, by `place`
-- (floor, px, py -> sheet x, y or nil, as DungeonMap.At). Its index, or nil.
function DungeonWay.Hit(instanceID, points, place, x, y, reach)
    local best, near = nil, reach
    for i, p in ipairs(points or {}) do
        local px, py = place(DungeonWay.Where(instanceID, p))
        if px then
            local d = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
            if d <= near then best, near = i, d end
        end
    end
    return best
end

-- The leg nearest sheet point x, y within `reach`: the index of the point
-- it starts at, or nil. A jump to a linked step is no leg to put a point on.
function DungeonWay.OnLeg(instanceID, points, place, x, y, reach)
    local best, near = nil, reach
    for i = 1, #(points or {}) - 1 do
        local a, b = points[i], points[i + 1]
        local ax, ay = place(DungeonWay.Where(instanceID, a))
        local bx, by = place(DungeonWay.Where(instanceID, b))
        if ax and bx and not b.pair then
            local sx, sy, px, py = bx - ax, by - ay, x - ax, y - ay
            local len2 = sx * sx + sy * sy
            local t = len2 > 0 and math.max(0, math.min(1, (px * sx + py * sy) / len2)) or 0
            local d = math.sqrt((px - t * sx) ^ 2 + (py - t * sy) ^ 2)
            if d < near then best, near = i, d end
        end
    end
    return best
end

-- The span a point goes out with: a linked pair goes together.
local function Span(r, i)
    if r[i].pair and i > 1 then return i - 1, i end
    if r[i + 1] and r[i + 1].pair then return i, i + 1 end
    return i, i
end

function DungeonWay.Pen(visit, wing)
    local pen = { visit = visit, wing = wing, at = nil }
    local history = {}
    local batching = false

    local function Usual() return ns.Dungeons.Route(visit.instanceID, wing) end

    function pen:Points()
        return (ns.Dungeons.WayOf(visit, wing)) or {}
    end

    function pen:Own() return type(visit.route) == "table" end

    -- The way to write in: the run's own, made from the usual way the
    -- first time.
    local function Mine()
        if type(visit.route) ~= "table" then visit.route = Copy(Usual()) or {} end
        return visit.route
    end

    local function Push()
        if batching then return end
        history[#history + 1] = { route = Copy(type(visit.route) == "table" and visit.route or nil), at = pen.at }
    end

    -- Several edits as one undo step.
    local function Batch(fn)
        Push()
        batching = true
        local ok, result = pcall(fn)
        batching = false
        if not ok then error(result, 0) end
        return result
    end

    local function Room(n) return #pen:Points() + n <= MAX end

    -- In after the selection, or at the end; the selection moves onto it.
    local function Put(point)
        local r = Mine()
        local at = pen.at
        if at and at >= 1 and at <= #r then
            table.insert(r, at + 1, point)
            pen.at = at + 1
            return at + 1
        end
        r[#r + 1] = point
        pen.at = nil
        return #r
    end

    function pen:Add(f, x, y)
        if not (f and x and y) or not Room(1) then return nil end
        Push()
        return Put({ f = tonumber(f), x = Round(x), y = Round(y) })
    end

    function pen:AddStop(name)
        local b = ns.Dungeons.Boss(visit.instanceID, name)
        if not (b and b.floor and b.x) or not Room(1) then return nil end
        Push()
        return Put({ f = tonumber(b.floor), x = Round(b.x), y = Round(b.y), boss = b.name })
    end

    function pen:AddStep(marker)
        if not (marker and marker.floor and marker.x and marker.y) then return nil end
        local D = ns.Dungeons
        local link = D.LinkOf(visit.instanceID, marker.floor, marker.x, marker.y)
        if not Room(link and 2 or 1) then return nil end
        return Batch(function()
            local tag = marker.kind == "trigger" and marker.label or (link and link.letter)
            local i = Put({ f = tonumber(marker.floor), x = Round(marker.x), y = Round(marker.y), kind = marker.kind,
                tag = tag, mboss = marker.boss })
            if link then
                local far
                for _, m in ipairs(D.Markers(visit.instanceID, link.floor)) do
                    if D.Near(link.floor, m.x, m.y, link.floor, link.x, link.y) then far = m end
                end
                i = Put({ f = tonumber(link.floor), x = Round(link.x), y = Round(link.y),
                    kind = far and far.kind or marker.kind, tag = link.letter, pair = true })
            end
            return i
        end)
    end

    function pen:Insert(after, f, x, y)
        local r = pen:Points()
        if not (after and r[after] and r[after + 1]) or not (f and x and y) or not Room(1) then return nil end
        Push()
        r = Mine()
        table.insert(r, after + 1, { f = tonumber(f), x = Round(x), y = Round(y) })
        if pen.at and pen.at > after then pen.at = pen.at + 1 end
        return after + 1
    end

    -- Dragging: the state before it is kept on Grab and becomes one undo
    -- step on Drop, if it moved at all. Stops and steps stay on their boss
    -- or marker.
    local grabbed
    function pen:Grab(i)
        local p = pen:Points()[i]
        if not p or p.boss or p.kind then return false end
        grabbed = { route = Copy(type(visit.route) == "table" and visit.route or nil), at = pen.at, moved = false }
        return true
    end

    function pen:MoveTo(i, f, x, y)
        local p = pen:Points()[i]
        if not grabbed or not p or p.boss or p.kind or not (f and x and y) then return false end
        p = Mine()[i]
        p.f, p.x, p.y = tonumber(f), Round(x), Round(y)
        grabbed.moved = true
        return true
    end

    function pen:Drop()
        local g = grabbed
        grabbed = nil
        if not (g and g.moved) then return false end
        history[#history + 1] = { route = g.route, at = g.at }
        return true
    end

    function pen:Delete(i)
        local r = pen:Points()
        if not r[i] then return false end
        Push()
        r = Mine()
        local from, to = Span(r, i)
        local gap = false
        for k = from, to do if r[k].gap then gap = true end end
        for k = to, from, -1 do table.remove(r, k) end
        if gap and r[from] then r[from].gap = true end
        pen.at = from > 1 and from - 1 or nil
        return true
    end

    -- The first point of the grey part, or nil when the way is whole.
    function pen:Gap()
        for i, p in ipairs(pen:Points()) do if p.gap then return i end end
    end

    function pen:Cut(k)
        local r = pen:Points()
        if not (k and r[k] and r[k + 1]) or pen:Gap() then return false end
        Push()
        Mine()[k + 1].gap = true
        pen.at = k
        return true
    end

    -- Join the new part to the grey part at point m: the grey points
    -- before m go. The names of the stops that went with them, or nil.
    function pen:Connect(m)
        local g = pen:Gap()
        local r = pen:Points()
        if not (g and m and m >= g and r[m]) then return nil end
        Push()
        r = Mine()
        local dropped = {}
        for k = m - 1, g, -1 do
            if r[k].boss then table.insert(dropped, 1, r[k].boss) end
            table.remove(r, k)
        end
        r[g].gap = nil
        pen.at = nil
        return dropped
    end

    -- The pen is put down: a cut left open joins its first grey point.
    function pen:Finish()
        local g = pen:Gap()
        pen.at, grabbed = nil, nil
        if not g then return false end
        visit.route[g].gap = nil
        return true
    end

    function pen:Select(i)
        local r = pen:Points()
        pen.at = (i and r[i]) and i or nil
        return pen.at
    end

    function pen:Step(delta)
        local r = pen:Points()
        if #r == 0 then return nil end
        local at = pen.at or (delta < 0 and #r + 1 or 0)
        pen.at = math.max(1, math.min(#r, at + delta))
        return pen.at
    end

    function pen:CanUndo() return #history > 0 end

    function pen:Undo()
        local snap = table.remove(history)
        if not snap then return false end
        visit.route = snap.route or nil
        pen.at = snap.at
        if pen.at and not pen:Points()[pen.at] then pen.at = nil end
        return true
    end

    function pen:Clear()
        if pen:Own() and #visit.route == 0 then return false end
        Push()
        visit.route = {}
        pen.at = nil
        return true
    end

    -- Their drawing gone, the usual way back; and no undo past it (it
    -- asked first, WAY-10).
    function pen:Reset()
        local had = pen:Own()
        visit.route = nil
        pen.at, grabbed = nil, nil
        for k in pairs(history) do history[k] = nil end
        return had
    end

    return pen
end
