-- Every dungeon's pace data (Core/Pace/*.lua, ns.PaceData) as the addon
-- needs it, whichever is added next (.claude/skills/pace-data): it loads,
-- its bosses are the map's, it has a fit (the floor's art bounds, else
-- through the pins), its packs are whole, and the usual way through lays
-- legs the route model takes, with pulls on them. And, leaning on none of
-- DCF's pins (drawn where they read well: 4 Nov 2026), the packs lie by
-- the way drawn: at least ON_WAY of them within PULL.radius of it. That
-- checks the bounds, the spawns and the usual way against each other; any
-- of them can be wrong (DCF's data too). A file that fails here never
-- reaches a player's map.

-- At least this share of a dungeon's packs within PULL.radius of the usual
-- way, on their own floor (4 Nov 2026: Ragefire 74%, Stockade 54%,
-- Razorfen Kraul 54%, Razorfen Downs 86%; Zul'Farrak 27%, its way through
-- the spread pins).
local ON_WAY = 0.4

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Pace, D, Model = ns.DungeonPace, ns.Dungeons, ns.PaceModel

-- PACE_EXTRA=Core/Pace/A.lua,Core/Pace/B.lua: files not yet in the TOC,
-- loaded as it would (a new dungeon checked before it is listed).
for file in (os.getenv("PACE_EXTRA") or ""):gmatch("[^,]+") do
    assert(loadfile(file))(ns.addonName, ns)
    Pace.Reset()
end

local only = os.getenv("PACE_ONLY") and tonumber(os.getenv("PACE_ONLY"))
local ids = {}
for id in pairs(ns.PaceData or {}) do
    if not only or id == only then ids[#ids + 1] = id end
end
table.sort(ids)
Check(#ids >= 1, "no pace data at all")

for _, id in ipairs(ids) do
    local data = ns.PaceData[id]
    local name = tostring(data.name or id)
    Section("pace data: " .. name)

    Eq(data.instanceID, id, name .. ": registered under another instance")
    Check(D.Known(id), name .. ": a dungeon the map does not know")
    Check(type(data.source) == "string" and data.source:find("GPL", 1, true), name .. ": no source and licence")

    -- The bosses: each one the map's, by its name.
    Check(#(data.bosses or {}) >= 1, name .. ": no bosses")
    for _, b in ipairs(data.bosses) do
        Check(D.Boss(id, b.name), name .. ": a boss the map does not know: " .. tostring(b.name))
        Check(type(b.x) == "number" and type(b.y) == "number", name .. ": a boss without its place")
    end

    -- The packs: whole, and only creatures that are no boss.
    Check(#(data.packs or {}) >= 1, name .. ": no packs")
    local npcs = {}
    for k, p in ipairs(data.packs) do
        local tag = name .. " pack " .. k
        Check(type(p.x) == "number" and type(p.y) == "number", tag .. ": no place")
        Check((p.size or 0) >= 1 and (p.elites or -1) >= 0 and p.elites <= p.size, tag .. ": its size and elites")
        Check(#(p.names or {}) >= 1 and #(p.npcs or {}) >= 1, tag .. ": who is in it")
        for _, npc in ipairs(p.npcs) do npcs[npc] = true end
        if p.boss then Check(D.Boss(id, p.boss), tag .. ": guards a boss the map does not know") end
        if p.floor then Check(D.Floor(id, p.floor), tag .. ": drawn on a floor the map does not know") end
    end
    for npc, by in pairs(data.summons or {}) do
        Check(npcs[by], ("%s: summon %d's summoner %d in no pack"):format(name, npc, by))
        Check(not npcs[npc], ("%s: summon %d is in a pack itself"):format(name, npc))
    end

    -- The fit, and the usual way laid on it.
    local fit = Pace.Fit(id)
    Check(fit, name .. ": no fit (no art bounds, and the pins refused: FIT.most " .. Pace.FIT.most .. " yd)")
    for k, p in ipairs(data.packs) do
        if p.floor then Check(fit.floors[p.floor], name .. " pack " .. k .. ": on a floor not fitted") end
    end
    -- On several floors, every pack says which; on one, none does.
    local several = fit.order and #fit.order > 1
    for k, p in ipairs(data.packs) do
        Check((p.floor ~= nil) == (several == true), name .. " pack " .. k .. (several and ": no floor" or ": a floor on a one-floor map"))
    end
    local route = D.Route(id)
    Check(route, name .. ": no usual way through")
    local course = Pace.Course({ instanceID = id }, route)
    Check(course, name .. ": no course on the usual way")
    Check(#course.pulls >= 1, name .. ": no pull on the usual way")
    -- How near the way drawn (on the pack's own floor) each pack lies, in yards.
    local near, dists = 0, {}
    for _, p in ipairs(data.packs) do
        local best = math.huge
        for k = 1, #course.cum - 1 do
            local a, b = course.game[k], course.game[k + 1]
            local mine = not p.floor or p.floor == course.floors[k] or p.floor == course.floors[k + 1]
            if mine and a and b and not course.broken[k] then
                local dx, dy = b[1] - a[1], b[2] - a[2]
                local l2 = dx * dx + dy * dy
                local t = l2 > 0 and math.max(0, math.min(1, ((p.x - a[1]) * dx + (p.y - a[2]) * dy) / l2)) or 0
                best = math.min(best, math.sqrt((a[1] + dx * t - p.x) ^ 2 + (a[2] + dy * t - p.y) ^ 2))
            end
        end
        dists[#dists + 1] = best
        if best <= Pace.PULL.radius then near = near + 1 end
    end
    table.sort(dists)
    local median = dists[math.floor(#dists / 2) + 1]
    Check(near >= ON_WAY * #data.packs, ("%s: only %d of %d packs near the way drawn (median %.1f yd): the bounds, the spawns or the way are off")
        :format(name, near, #data.packs, median))
    local prev, legs = 1, 0
    for i, p in ipairs(route) do
        if p.boss and D.Boss(id, p.boss) then
            local leg = Pace.Leg(course, prev, i)
            if leg then
                legs = legs + 1
                Check(leg.length > 0 and Model.LegTime(leg) > 0, name .. ": a leg of nothing to " .. p.boss)
            end
            prev = i
        end
    end
    Check(legs >= 1, name .. ": no leg the model takes")
    if os.getenv("PACE_SHOW") then  -- PACE_SHOW=1: the numbers to report
        local floors = {}
        for _, f in ipairs(fit.order or { fit.floor }) do floors[#floors + 1] = tostring(f) end
        print(("%s: fit floor %s by %s; DCF's pins: worst %s %.1f yd (%d compared); usual way %.0f yd, %d of %d packs as pulls, %d near it (median %.1f yd), %d legs")
            :format(name, table.concat(floors, ", "), fit.method, tostring(fit.worstName or "-"), fit.worst, fit.anchors,
                course.cum[#course.cum], #course.pulls, #data.packs, near, median, legs))
        prev = 1
        for i, p in ipairs(route) do
            if p.boss and D.Boss(id, p.boss) then
                local leg = Pace.Leg(course, prev, i)
                print(leg and ("  leg to %s: %.0f yd, %d pulls, the model's time %.0f s")
                    :format(p.boss, leg.length, #leg.pulls, Model.LegTime(leg)) or ("  leg to %s: none"):format(p.boss))
                prev = i
            end
        end
    end
end
