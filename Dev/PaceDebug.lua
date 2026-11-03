-- /sd pace: how the route model (Core/DungeonPace.lua) laid a run's
-- moments on the way, for checking it against a real run in the client.
--
--   /sd pace          the run inside now, else the last run with pace data:
--                     the fit, the way's legs (yards, pulls, the model's
--                     time for them), and each death, wipe, near wipe and
--                     roll on the way: its time, its leg, the seconds into
--                     it (and the leg's, once its boss fell), how it was
--                     placed ("pace", "eased", "share", "past") and where:
--                     yards along the way, and the floor's x, y
--   /sd pace here     where you stand: the floor's x, y, and yards along the
--                     way (and off it), to set against where a death you
--                     just had was placed
--   /sd pace at X Y   the same for game yards (a GM's .gps: X, then Y)
--   /sd pace map      on the map sheet, over the marks: every pack of the
--                     pace data (red where a pull on the way, grey where the
--                     way does not pass it, larger for more elites), each
--                     with a tooltip, and the data's way in and bosses
--                     (blue rings: how far the fit puts them off the map's
--                     own); again to take it off
--
-- Prints names from the run; nothing is saved. Dev only: the TOC's Dev/
-- block never goes in a release.

local addonName, ns = ...

local Page = ns.UI.DungeonPage

local RED, GREY = { 0.70, 0.13, 0.10 }, { 0.35, 0.35, 0.35 }

local function Say(fmt, ...) ns.Print(fmt:format(...)) end

local function Clock(seconds)
    if not seconds then return "-" end
    seconds = math.floor(seconds + 0.5)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- The run inside now, else the last one with pace data.
local function TheRun()
    local now = ns.Instances and ns.Instances.Current and ns.Instances.Current()
    if now and ns.PaceData and ns.PaceData[now.instanceID] then return now end
    local best
    for _, visit in pairs(ns.db and ns.db.instances or {}) do
        if ns.PaceData and ns.PaceData[visit.instanceID]
            and (not best or (visit.startedAt or 0) > (best.startedAt or 0)) then
            best = visit
        end
    end
    return best
end

local function Who(visit, guid)
    if guid == (visit.me or ns.ownGUID) then return "you" end
    for _, m in ipairs(visit.members or {}) do
        if m.guid == guid and m.first then return m.first end
    end
    return tostring(guid):sub(-6)
end

-- The way as the map has it: the user's own, else the usual one; the
-- stops along it.
local function Way(visit)
    local route, own = ns.Dungeons.WayOf(visit, visit.wing)
    return route, own
end

local function Report()
    local visit = TheRun()
    if not visit then
        Say("pace: no run in a dungeon with pace data (%s).", "Ragefire Chasm")
        return
    end
    local Pace, D = ns.DungeonPace, ns.Dungeons
    local fit = Pace.Fit(visit.instanceID)
    local inside = visit.endedAt and "lasted" or "inside for"
    Say("pace: %s, run %s, %s %s", visit.name or "?", tostring(visit.id), inside,
        Clock((visit.endedAt or ns.Now()) - (visit.startedAt or ns.Now())))
    if not fit then
        Say("  no fit: the data's bosses and way in do not match the map (FIT.most %d yd)", Pace.FIT.most)
        return
    end
    Say("  fit: floor %d, %d anchors, worst %.1f yd off", fit.floor, fit.anchors, fit.worst)
    local route, own = Way(visit)
    local course = Pace.Course(visit, route)
    if not course then
        Say("  no course on the %s way", own and "player's own" or "usual")
        return
    end
    Say("  the %s way: %d points, %.0f yd, %d of %d packs on it", own and "player's own" or "usual", #route,
        course.cum[#course.cum], #course.pulls, #ns.PaceData[visit.instanceID].packs)
    local prev = 1
    for i, p in ipairs(route) do
        if p.boss then
            local leg = Pace.Leg(course, prev, i)
            if leg then
                local elites = 0
                for _, pull in ipairs(leg.pulls) do elites = elites + pull.elites end
                Say("  leg to %s: %.0f yd, %d pulls (%d elites), the model's time %s", p.boss, leg.length,
                    #leg.pulls, elites, Clock(ns.PaceModel.LegTime(leg)))
            else
                Say("  leg to %s: not the model's (broken, or no length)", p.boss)
            end
            prev = i
        end
    end

    -- Each moment on the way, as the map places it.
    local notes = ns.DungeonRun.Notes(visit)
    local At = function(f, x, y) if tonumber(f) == fit.floor then return x, y end end
    local floor = D.Floor(visit.instanceID, fit.floor)
    local plan = floor and Page.Plan({ visit = visit, floor = floor, box = { x = 0, y = 0, w = 1, h = 1 },
        At = At, notes = notes, route = true })
    local path = plan and plan.path
    local function Line(kind, time, leg, who)
        local x, y, how = nil, nil, nil
        if path then x, y, how = Page.LegPoint(path, leg) end
        local to = leg.before and leg.before.name or (leg.open and "the next boss standing") or "?"
        local where = "nowhere"
        if x then
            local yd, off = ns.DungeonPace.Project(course, fit.ToGame(x, y))
            where = ("%.0f yd along (%.0f off), floor %.3f, %.3f"):format(yd or -1, off or -1, x, y)
        end
        Say("  %s %s%s: %s -> %s, %s into the leg (of %s): %s at %s", Clock((time or 0) - (visit.startedAt or 0)),
            kind, who and (" " .. who) or "", leg.after and leg.after.name or "the way in", to, Clock(leg.dt),
            leg.known and Clock(leg.known) or "-", tostring(how), where)
    end
    for _, l in ipairs(notes.legs or {}) do Line("death", l.death.time, l, Who(visit, l.death.guid)) end
    for _, w in ipairs(notes.wipes or {}) do Line("wipe", w.deaths[1] and w.deaths[1].time, w) end
    for _, w in ipairs(notes.near or {}) do Line("near wipe", w.deaths[1] and w.deaths[1].time, w) end
    for _, b in ipairs(notes.bosses or {}) do
        if b.killed then Say("  %s killed %s", b.boss.name, Clock((b.at or 0) - (visit.startedAt or 0))) end
    end
    if #(notes.legs or {}) == 0 then Say("  no deaths on the way") end
end

-- The packs over the marks (Print.lua's DevOverlay hook).
local function Overlay(plan, P)
    local visit = plan.visit
    local data = ns.PaceData and visit and ns.PaceData[visit.instanceID]
    local fit = data and ns.DungeonPace.Fit(visit.instanceID)
    if not fit or not plan.floor then return end
    local onWay = {}
    for _, pull in ipairs(plan.path and plan.path.course and plan.path.course.pulls or {}) do
        onWay[pull.pack] = pull
    end
    for n, pack in ipairs(data.packs) do
        local fx, fy = fit.ToFloor(pack.x, pack.y)
        local x, y = plan.At(fit.floor, fx, fy)
        if x then
            local pull = onWay[n]
            local size = 4 + 2 * math.min(pack.elites or 1, 5)
            P.Dot(P.pools.crossHalo, x, y, size, pull and RED or GREY, 0.85)
            local lines = { (pack.size or 1) .. " (" .. (pack.elites or 0) .. " elite)" }
            lines[#lines + 1] = pull and ("a pull %.0f yd along the way"):format(pull.at) or "not on the way"
            if pack.boss then lines[#lines + 1] = "guards " .. pack.boss end
            P.Hit(P.pools.hit, x, y, size + 4, ns.Style.TipList(table.concat(pack.names or {}, ", "), lines))
        end
    end
    -- The way in and the bosses where the data has them (a ring): how far
    -- the fit puts them off the map's own.
    local anchors = { data.entrance }
    for _, b in ipairs(data.bosses) do anchors[#anchors + 1] = b end
    for _, a in ipairs(anchors) do
        local fx, fy = fit.ToFloor(a.x, a.y)
        local x, y = plan.At(fit.floor, fx, fy)
        if x then P.Dot(P.pools.crossHalo, x, y, 14, { 0.1, 0.3, 0.7 }, 0.5) end
    end
end

-- Where game yards gx, gy lie on the run's way.
local function Where(visit, gx, gy, label)
    local Pace = ns.DungeonPace
    local fit = Pace.Fit(visit.instanceID)
    if not fit then return Say("pace: no fit for %s", visit.name or "?") end
    local route = Way(visit)
    local course = Pace.Course(visit, route)
    local yd, off = Pace.Project(course, gx, gy)
    local fx, fy = fit.ToFloor(gx, gy)
    Say("pace: %s: game %.1f, %.1f; floor %.3f, %.3f; %s", label, gx, gy, fx, fy,
        yd and ("%.0f yd along the way, %.0f off it"):format(yd, off) or "not near the way")
    Say("  %s into the run", Clock(ns.Now() - (visit.startedAt or ns.Now())))
end

-- Where you stand, from the map the client says you are on.
local function Here()
    local visit = TheRun()
    if not visit then return Say("pace: no run in a dungeon with pace data") end
    local fit = ns.DungeonPace.Fit(visit.instanceID)
    if not fit then return Say("pace: no fit for %s", visit.name or "?") end
    local ok, pos = pcall(function()
        return C_Map.GetPlayerMapPosition(fit.floor, "player")
    end)
    if not ok or not pos or not pos.GetXY then
        return Say("pace: the client gives no position on floor %d here (%s): try /sd pace at X Y", fit.floor,
            ok and "none" or tostring(pos))
    end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then
        return Say("pace: your position is secret here: try /sd pace at X Y")
    end
    local gx, gy = fit.ToGame(x, y)
    Where(visit, gx, gy, "you")
end

local function Map()
    if Page.DevOverlay then
        Page.DevOverlay = nil
        Say("pace: the packs taken off the map")
    else
        Page.DevOverlay = Overlay
        Say("pace: the packs on the map (red: pulls on the way; grey: off it; blue: the data's way in and bosses)")
    end
    local spread = Page.Spread and Page.Spread()
    local view = spread and spread.map
    if view and view:IsShown() and view.visit then view:Open(view.visit, view.guid) end
end

ns.Slash.Register("pace", function(rest)
    rest = rest or ""
    local gx, gy = rest:match("^at%s+(%-?[%d.]+)[%s,]+(%-?[%d.]+)")
    if rest == "map" then
        Map()
    elseif rest == "here" then
        Here()
    elseif gx then
        local visit = TheRun()
        if not visit then return Say("pace: no run in a dungeon with pace data") end
        Where(visit, tonumber(gx), tonumber(gy), "there")
    else
        Report()
    end
end, "how the route model placed a run's moments: |cffffd100/sd pace [here | at X Y | map]|r", { dev = true })
