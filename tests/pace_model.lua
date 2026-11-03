-- The route model (Core/Pace/Model.lua) against the answers recorded from
-- the route-model handover's preview pages (tests/pace/vectors.lua), on
-- the handover's own legs (tests/pace/*.lua, Ragefire Chasm and
-- Zul'Farrak), and the properties the addon leans on: never past the
-- boss, weights summing to one, a late death at the boss. The handover's
-- tests/run_tests.lua, in this harness. How it is laid on the addon's own
-- way: tests/pace.lua.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq

local dir = debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or "tests"
local root = dir .. "/.."
local ns = {}
local Model = assert(loadfile(root .. "/Core/Pace/Model.lua"))("SocialDiaryTest", ns)
Eq(ns.PaceModel, Model, "the model registers as ns.PaceModel")
ns.RouteData = {}
assert(loadfile(dir .. "/pace/RagefireChasm.lua"))("SocialDiaryTest", ns)
assert(loadfile(dir .. "/pace/ZulFarrak.lua"))("SocialDiaryTest", ns)
local sets = assert(loadfile(dir .. "/pace/vectors.lua"))()

local function Close(a, b, tol) return math.abs(a - b) <= tol * math.max(1, math.abs(a), math.abs(b)) end

--------------------------------------------------------------------------
Section("the recorded answers (the preview pages' JavaScript)")

local n = 0
for _, set in ipairs(sets) do
    local data = ns.RouteData[set.mapId]
    Check(data ~= nil, "no legs for map " .. tostring(set.mapId))
    for _, v in ipairs(set.vectors) do
        local leg = data.legs[v.leg]
        local r = Model.PlaceDeath(leg, v.t, set.pace, { curve = v.curve, knownKill = v.known })
        local tag = ("%s leg %d t=%d %s%s"):format(set.dungeon, v.leg, v.t, v.curve, v.known and (" known=" .. v.known) or "")
        Check(Close(r.yd, v.yd, 1e-6), tag .. (": yd %.4f, page %.4f"):format(r.yd, v.yd))
        Eq(r.kind, v.kind, tag .. ": kind")
        Eq(r.pull, v.pull, tag .. ": pull")
        Eq(r.pullsDone, v.pullsDone, tag .. ": pulls done")
        Check(Close(r.expected, v.expected, 1e-9), tag .. ": the leg's expected time")
        Check(r.top.kind == v.topKind and r.top.pull == v.topPull, tag .. ": the most likely moment")
        Check(Close(r.top.share, v.topShare, 1e-6), tag .. (": top share %.6f, page %.6f"):format(r.top.share, v.topShare))
        n = n + 1
    end
end
Check(n >= 800, "fewer recorded answers than the handover's 800: " .. n)

--------------------------------------------------------------------------
Section("never past the boss; a late death at the boss; the known kill")

-- Not a property: an open leg's estimate is the most likely spot for a
-- death at time t, so it may step back (a big pull behind outweighs
-- walking ahead). Each death is placed on its own; the handover counted 6.
local backwards = 0
for _, data in pairs(ns.RouteData) do
    for li, leg in ipairs(data.legs) do
        local tag = data.name .. " leg " .. li
        Check(leg.length > 0 and #leg.path >= 2, tag .. ": its path and length")
        local last = -1
        for _, p in ipairs(leg.pulls) do
            Check(p.at >= last and p.at <= leg.length + 1e-9, tag .. ": pulls in order along the path")
            Check(p.elites >= 1, tag .. ": a pull without an elite")
            last = p.at
        end
        local prev = -1
        for t = 0, 4 * Model.LegTime(leg), 7 do
            local r = Model.PlaceDeath(leg, t)
            Check(r.yd <= leg.length + 1e-9, tag .. ": past the boss at t=" .. t)
            Check(r.progress >= 0 and r.progress <= 1, tag .. ": progress out of 0..1 at t=" .. t)
            local s = 0
            for _, smp in ipairs(r.samples) do s = s + smp.w end
            Check(math.abs(s - 1) < 1e-9, tag .. ": the weights do not sum to 1")
            if r.yd < prev - 1e-9 then backwards = backwards + 1 end
            prev = r.yd
        end
        local late = Model.PlaceDeath(leg, 50 * Model.LegTime(leg))
        Check(late.kind == "boss" and math.abs(late.yd - leg.length) < 1e-9, tag .. ": a very late death not at the boss")
        Eq(Model.PlaceDeath(leg, 100, nil, { knownKill = 100 }).kind, "boss", tag .. ": a death at the known kill")
        -- With the kill known the leg is stretched to it: never back.
        local kprev = -1
        for t = 0, 600, 15 do
            local r = Model.PlaceDeath(leg, t, nil, { knownKill = 600 })
            Check(r.yd >= kprev - 1e-9, tag .. ": a known leg stepped back at t=" .. t)
            kprev = r.yd
        end
    end
    Eq(Model.OpenLeg(data, {}), 1, data.name .. ": the first leg open on entry")
end
Check(backwards <= 12, "the estimate steps back far more than the handover's 6: " .. backwards)
