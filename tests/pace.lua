-- The route model laid on the addon's own way (Core/DungeonPace.lua):
-- Ragefire Chasm's pace data (Core/Pace/RagefireChasm.lua) fitted to
-- Dungeon Crawler Forever's map, its packs laid on the way drawn as pulls,
-- a moment's time turned into yards along it, and the map putting it there
-- (UI/Dungeon/Print.lua's LegPoint) or keeping its own guess where the
-- model does not hold. The model itself: tests/pace_model.lua.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Pace, D, Run, Page = ns.DungeonPace, ns.Dungeons, ns.DungeonRun, ns.UI.DungeonPage
local Model = ns.PaceModel
local RFC = 389

local function Near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end

--------------------------------------------------------------------------
Section("the data fitted to the map")

Check(ns.PaceData and ns.PaceData[RFC], "no pace data for Ragefire Chasm")
local fit = Pace.Fit(RFC)
Check(fit, "Ragefire Chasm's data does not fit the map")
Eq(fit.floor, 213, "the floor fitted")
Eq(fit.method, "bounds", "not fitted by the floor's art bounds")
Eq(fit.anchors, 5, "the pins compared: the way in and four bosses")
-- The art bounds: the picture's corners are the rectangle's.
local floor213 = D.Floor(RFC, 213)
local bb = floor213.bounds
local cx, cy = fit.ToFloor(bb[3], bb[4])
Check(Near(cx, 0) and Near(cy, 0), "the picture's top left not the rectangle's far corner")
cx, cy = fit.ToFloor(bb[1], bb[2])
Check(Near(cx, 1) and Near(cy, 1), "the picture's bottom right not the rectangle's near corner")
-- Ragefire's pins are drawn where the bosses stand (within 6 yd); the way
-- in's marker is some 15 yd from the handover's entrance.
for _, b in ipairs(ns.PaceData[RFC].bosses) do
    local m = D.Boss(RFC, b.name)
    Check(m, "a boss of the data not in the map's: " .. b.name)
    local gx, gy = fit.ToGame(m.x, m.y)
    Check(math.sqrt((gx - b.x) ^ 2 + (gy - b.y) ^ 2) < 6, b.name .. " off its spawn")
    local fx, fy = fit.ToFloor(gx, gy)
    Check(Near(fx, m.x, 1e-9) and Near(fy, m.y, 1e-9), "there and back again")
end
Check(fit.worst < 20 and fit.worstName == "the way in", ("the worst pin: %s %.1f yd"):format(tostring(fit.worstName), fit.worst))

-- A pin drawn 40 yd off (or a spawn): the bounds do not care; the
-- distance is only reported.
local boss1 = ns.PaceData[RFC].bosses[1]
local x0 = boss1.x
boss1.x = x0 + 40
Pace.Reset()
local moved = Pace.Fit(RFC)
Check(moved and moved.method == "bounds", "the bounds refused for a pin drawn off")
Check(moved.worst > 35 and moved.worstName == boss1.name, "a pin 40 yd off not reported")
cx, cy = moved.ToFloor(bb[3], bb[4])
Check(Near(cx, 0) and Near(cy, 0), "the bounds moved by a pin")

-- A floor without bounds: the old fit through the pins, refused when one
-- is off by more than FIT.most.
floor213.bounds = nil
Pace.Reset()
Eq(Pace.Fit(RFC), nil, "a fit through a pin 40 yd off")
Eq(Pace.Course({ instanceID = RFC }, D.Route(RFC)), nil, "a course without a fit")
boss1.x = x0
Pace.Reset()
local pinned = Pace.Fit(RFC)
Check(pinned and pinned.method == "anchors", "no fit through the pins without bounds")
Check(pinned.worst < 6, "the fit through the pins: " .. pinned.worst)
-- Too few anchors on one floor.
local bosses = ns.PaceData[RFC].bosses
ns.PaceData[RFC].bosses = { bosses[1], bosses[2] }
Pace.Reset()
Eq(Pace.Fit(RFC), nil, "a fit on three anchors")
ns.PaceData[RFC].bosses = bosses
floor213.bounds = bb
Pace.Reset()
Eq(Pace.Fit(RFC).method, "bounds", "the bounds back")
-- No data: nothing.
Eq(Pace.Fit(43), nil, "a fit without data")
Eq(Pace.Course({ instanceID = 43 }, D.Route(43)), nil, "a course without data")

--------------------------------------------------------------------------
Section("the packs laid on the usual way")

local route = D.Route(RFC)
local course = Pace.Course({ instanceID = RFC }, route)
Check(course, "no course on the usual way")
local stops, at = {}, {}
for i, p in ipairs(route) do
    if p.boss then stops[#stops + 1] = i; at[p.boss] = i end
end
Eq(#stops, 4, "the usual way's stops")
-- The legs in yards (the usual way clears the side rooms; 4 Nov 2026, by
-- the art bounds: through the pins the map was squeezed a tenth).
local want = { 535, 705, 200, 440 }
local prev = 1
for n, i in ipairs(stops) do
    local len = course.cum[i] - course.cum[prev]
    Check(math.abs(len - want[n]) < 15, ("leg %d in yards: %.0f, about %d"):format(n, len, want[n]))
    prev = i
end
for k = 1, #route - 1 do Check(not course.broken[k], "a stretch of the usual way off the floor") end
-- Each pack once at most, in order along the way, a guard at its boss.
local seen, last = {}, -1
for _, p in ipairs(course.pulls) do
    Check(not seen[p.pack], "a pack laid twice")
    seen[p.pack] = true
    Check(p.at >= last, "pulls out of order along the way")
    last = p.at
    Check(p.at >= 0 and p.at <= course.cum[#course.cum] + 1e-9, "a pull off the way")
    Check(p.elites >= 1, "a pull without an elite")
    if p.boss then Check(Near(p.at, course.cum[at[p.boss]]), "a guard away from its boss: " .. p.boss) end
end
Check(#course.pulls >= 35 and #course.pulls <= #ns.PaceData[RFC].packs,
    "the pulls on the usual way: " .. #course.pulls)
-- Every pull lies within PULL.radius of the way where it is laid.
for _, p in ipairs(course.pulls) do
    if not p.boss then
        local k, t = Pace.Along(course, p.at)
        local a, b = course.game[k], course.game[k + 1]
        local qx, qy = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        local pack = ns.PaceData[RFC].packs[p.pack]
        Check(math.sqrt((qx - pack.x) ^ 2 + (qy - pack.y) ^ 2) <= Pace.PULL.radius + 1e-6, "a pull laid off its pack")
    end
end

--------------------------------------------------------------------------
Section("the legs the model takes")

local i1, i2, i3, i4 = stops[1], stops[2], stops[3], stops[4]
local leg1 = Pace.Leg(course, 1, i1)
Check(leg1 and #leg1.pulls > 0, "the leg to Oggleflint")
Eq(leg1.to, "Oggleflint", "the leg's boss")
local guarded = false
for _, p in ipairs(leg1.pulls) do
    Check(p.at >= 0 and p.at <= leg1.length + 1e-9, "a pull off its leg")
    if Near(p.at, leg1.length) then guarded = true end
end
Check(guarded, "Oggleflint's guards not pulled on the leg to him")
local leg2 = Pace.Leg(course, i1, i2)
for _, p in ipairs(leg2.pulls) do
    Check(not Near(p.at, 0), "Oggleflint's guards pulled again on the way on")
end
-- The legs take all the pulls between them, once.
local count = 0
prev = 1
for _, i in ipairs(stops) do
    count = count + #Pace.Leg(course, prev, i).pulls
    prev = i
end
Eq(count, #course.pulls, "the legs' pulls")
-- Legs the model does not take.
Eq(Pace.Leg(course, i2, i1), nil, "a leg backwards")
Eq(Pace.Leg(course, i1, i1), nil, "a leg of nothing")
Eq(Pace.Leg(course, 1, i1 - 1), nil, "a leg to a point that is no boss")
Eq(Pace.Leg(nil, 1, i1), nil, "a leg without a course")
-- A skipped boss: from the way in straight to Taragaman, Oggleflint's
-- guards not on it (he stands; they are his).
local skip = Pace.Leg(course, 1, i2)
Check(skip and skip.length > leg1.length, "the leg past a boss still standing")
for _, p in ipairs(skip.pulls) do Check(not Near(p.at, leg1.length), "Oggleflint's guards on Taragaman's leg") end

--------------------------------------------------------------------------
Section("a moment's time into yards along the way")

-- An open leg: up to the boss, never past.
local from, to = course.cum[1], course.cum[i1]
for dt = 0, 4000, 37 do
    local yd, r = Pace.Place(course, 1, i1, dt)
    Check(yd and yd >= from - 1e-9 and yd <= to + 1e-9, "past Oggleflint at " .. dt .. " s")
    Check(r.progress >= 0 and r.progress <= 1, "the model's progress")
end
Eq(Pace.Place(course, 1, i1, 0), from, "a death at the way in, at once")
Check(Near(Pace.Place(course, 1, i1, 50 * Model.LegTime(leg1)), to), "a very late death not at the boss")
-- With the kill known: stretched to it, never back.
local kprev = -1
for dt = 0, 900, 30 do
    local yd = Pace.Place(course, i1, i2, dt, 900)
    Check(yd >= kprev - 1e-9, "a known leg stepped back at " .. dt .. " s")
    kprev = yd
end
Check(Near(Pace.Place(course, i1, i2, 900, 900), course.cum[i2]), "a death at the kill not at the boss")
Eq(Pace.Place(course, 1, i1, nil), nil, "a moment without a time")
Eq(Pace.Place(course, i2, i1, 60), nil, "a moment on a leg backwards")
-- Along: the stretch and how far.
local k, t = Pace.Along(course, (course.cum[5] + course.cum[6]) / 2)
Eq(k, 5, "the stretch half way along it")
Check(Near(t, 0.5), "half way along it")
Eq(Pace.Along(course, course.cum[#course.cum] + 1), nil, "past the way's end")
Eq(Pace.Along(course, -1), nil, "before the way's start")

--------------------------------------------------------------------------
Section("a way of the player's own")

-- A jump (a linked step's far end) is no way at all, and never where a
-- moment lies.
local own = {}
for i, p in ipairs(route) do own[i] = p end
local jumpAt = 10
local copy = {}
for key, v in pairs(own[jumpAt]) do copy[key] = v end
copy.pair = true
own[jumpAt] = copy
local oc = Pace.Course({ instanceID = RFC }, own)
Eq(oc.cum[jumpAt], oc.cum[jumpAt - 1], "a jump has length")
for yd = 0, oc.cum[#oc.cum], 5 do
    local kk = Pace.Along(oc, yd)
    Check(kk ~= jumpAt - 1, "a moment on a jump")
end
-- A point off the floor fitted: the legs across it are not the model's.
own = {}
for i, p in ipairs(route) do own[i] = p end
own[5] = { f = 999, x = 0.5, y = 0.5 }
oc = Pace.Course({ instanceID = RFC }, own)
Check(oc.broken[4] and oc.broken[5], "a stretch off the floor not broken")
Eq(Pace.Leg(oc, 1, i1), nil, "a leg across a broken stretch")
Check(Pace.Leg(oc, i1, i2), "a leg clear of it")
-- The bosses the other way round: the legs follow the way drawn.
own = { { f = 213, x = 0.6120, y = 0.0724 }, { boss = "Bazzalan" }, { boss = "Jergosh the Invoker" },
    { boss = "Oggleflint" } }
oc = Pace.Course({ instanceID = RFC }, own)
Check(Pace.Leg(oc, 1, 2), "the leg to Bazzalan first")
Eq(Pace.Leg(oc, 1, 2).to, "Bazzalan", "... its boss")
Eq(Pace.Course({ instanceID = RFC }, { { boss = "Oggleflint" } }), nil, "a way of one point")

--------------------------------------------------------------------------
Section("time inside: the way out and back not counted")

local away = { instanceID = RFC, startedAt = 1000, spans = { { from = 1000, to = 1300, ghost = true }, { from = 1500 } } }
Eq(Run.InsideBetween(away, 1000, 1600), 400, "the time inside across a run back")
Eq(Run.InsideBetween(away, 1350, 1450), 0, "the time outside")
Eq(Run.InsideBetween({ startedAt = 0 }, 100, 250), 150, "a run without spans")
Eq(Run.InsideBetween(away, 1600, 1500), 0, "backwards")
local aw = Run.When(away, { bosses = {} }, 1600)
Eq(aw.dt, 400, "a moment's seconds into its leg, inside")
Check(Near(aw.frac, Run.Eased(400)), "eased by the time inside")

--------------------------------------------------------------------------
Section("on the map: a run in Ragefire Chasm")

-- Oggleflint killed ten minutes in; Taragaman not yet.
local G = ns.ownGUID
local run = {
    id = 9389, instanceID = RFC, name = "Ragefire Chasm", startedAt = 1000, me = G,
    members = { { guid = G }, { guid = "Player-1-A" }, { guid = "Player-1-B" }, { guid = "Player-1-C" },
        { guid = "Player-1-D" } },
    spans = { { from = 1000 } },
    bossesKilled = { "Oggleflint" },
    pulls = { { id = 2732, name = "Oggleflint", start = 1560, stop = 1600, killed = true } },
    deathLog = {
        -- trash on the way to Oggleflint, half way through the leg's time
        { guid = "Player-1-A", time = 1300, killer = { name = "Ragefire Trogg" } },
        -- and right at the start
        { guid = "Player-1-B", time = 1010, killer = { name = "Earthborer" } },
        -- after him, toward Taragaman, late
        { guid = "Player-1-C", time = 1600 + 3000, killer = { name = "Searing Blade Cultist" } },
    },
}
local notes = Run.Notes(run)
local W, H = 800, 520
local floor = D.Floor(RFC, 213)
Check(floor, "Ragefire Chasm's floor")
local function At(f, x, y)
    if tonumber(f) == 213 and x and y then return x * W, y * H end
end
local plan = Page.Plan({ visit = run, floor = floor, box = { x = 0, y = 0, w = W, h = H }, At = At, notes = notes,
    route = true })
local path = plan.path
Check(path and path.course, "the plan's way has no course")

-- The sheet's point back to the floor and into yards along the way.
local function Yards(x, y)
    local gx, gy = fit.ToGame(x / W, y / H)
    local best, bestAt = math.huge, nil
    for kk = 1, #route - 1 do
        local a, b = path.course.game[kk], path.course.game[kk + 1]
        if b and a and path.course.cum[kk + 1] > path.course.cum[kk] then
            local dx, dy = b[1] - a[1], b[2] - a[2]
            local l2 = dx * dx + dy * dy
            local tt = math.max(0, math.min(1, ((gx - a[1]) * dx + (gy - a[2]) * dy) / l2))
            local d = (a[1] + dx * tt - gx) ^ 2 + (a[2] + dy * tt - gy) ^ 2
            if d < best then best, bestAt = d, path.course.cum[kk] + tt * math.sqrt(l2) end
        end
    end
    return bestAt, math.sqrt(best)
end

local legs = {}
for _, l in ipairs(notes.legs) do legs[l.death.guid] = l end
local clear = Page.PACE_CLEAR

-- A: on the leg to Oggleflint, its kill known.
local a = legs["Player-1-A"]
Eq(a.after, nil, "A's leg from the way in")
Eq(a.before.name, "Oggleflint", "A's leg to Oggleflint")
Eq(a.dt, 300, "A's seconds into the leg")
Eq(a.known, 600, "the leg's length in seconds")
local ax, ay, how = Page.LegPoint(path, a)
Eq(how, "pace", "A not placed by the model")
local ayd, off = Yards(ax, ay)
Check(off < 0.5, "A off the way drawn: " .. off)
local want = Pace.Place(path.course, 1, i1, 300, 600)
Check(Near(ayd, want, 0.5), ("A where the model says: %.1f yd, the model %.1f"):format(ayd, want))
Check(ayd > clear and ayd < course.cum[i1] - clear, "A not between the way in and Oggleflint")

-- B: ten seconds in, kept off the way in.
local bx, by, bhow = Page.LegPoint(path, legs["Player-1-B"])
Eq(bhow, "pace", "B not placed by the model")
local bWant = math.max(clear, (Pace.Place(path.course, 1, i1, 10, 600)))
Check(Near(Yards(bx, by), bWant, 0.5), ("B not where the model says, kept off the way in: %.1f, want %.1f")
    :format(Yards(bx, by), bWant))
-- A death at the very start of an open leg: kept PACE_CLEAR yards off it.
local zx, zy = Page.LegPoint(path, { open = true, frac = 0, dt = 0 })
Check(Near(Yards(zx, zy), clear, 0.5), "a death at the way in not kept PACE_CLEAR yards off it")

-- C: past Oggleflint, Taragaman standing, very late: short of him.
local c = legs["Player-1-C"]
Eq(c.open, true, "C's leg open")
Eq(c.after.name, "Oggleflint", "C's leg from Oggleflint")
local cx, cy, chow = Page.LegPoint(path, c)
Eq(chow, "pace", "C not placed by the model")
local cyd = Yards(cx, cy)
Check(cyd > course.cum[i1] and cyd <= course.cum[i2] - clear + 0.5,
    ("C not short of Taragaman: %.0f yd, Taragaman at %.0f"):format(cyd, course.cum[i2]))

-- A wipe on the way and a roll found there go the same way (their
-- targets: Print.lua's LegPoint for both).
local roll = Run.When(run, notes, 1300)
local rx, ry = Page.LegPoint(path, roll)
Check(Near(rx, ax) and Near(ry, ay), "a roll at A's time not where A died")

-- A dungeon without pace data keeps the map's own guess.
local wc = { instanceID = 43, startedAt = 1000, spans = { { from = 1000 } }, deathLog = {} }
local wpath = { route = { { f = 1, x = 0, y = 0 }, { boss = "Alpha" } }, pts = { { 0, 0 }, { 100, 0 } },
    stops = { [D.Norm("Alpha")] = 2 }, killed = {}, course = Pace.Course(wc, D.Route(43)) }
Eq(wpath.course, nil, "a course without pace data")
local _, _, whow = Page.LegPoint(wpath, { open = true, frac = 0.5, dt = 240 })
Eq(whow, "eased", "without pace data, not eased")
-- And so does a leg the model does not take (to the way's end, no boss).
path.killed[D.Norm("Taragaman the Hungerer")] = 9
path.killed[D.Norm("Jergosh the Invoker")] = 9
path.killed[D.Norm("Bazzalan")] = 9
local _, _, ehow = Page.LegPoint(path, c)
Check(ehow == "pace", "the last boss's stop is the way's end: still a boss: " .. tostring(ehow))
local short = {}
for i = 1, i4 - 1 do short[i] = route[i] end
short[#short + 1] = { f = 213, x = 0.45, y = 0.9 }
local spath = { route = short, pts = {}, stops = {}, killed = { [D.Norm("Oggleflint")] = 1,
    [D.Norm("Taragaman the Hungerer")] = 2, [D.Norm("Jergosh the Invoker")] = 3 },
    course = Pace.Course(run, short) }
for i, p in ipairs(short) do
    local f, x, y = ns.DungeonWay.Where(RFC, p)
    spath.pts[i] = { At(f, x, y) }
    if p.boss then spath.stops[D.Norm(p.boss)] = spath.stops[D.Norm(p.boss)] or i end
end
local _, _, shhow = Page.LegPoint(spath, { after = { name = "Jergosh the Invoker" }, open = true, frac = 0.5, dt = 60 })
Eq(shhow, "eased", "a leg to the way's end (no boss there) not eased")

--------------------------------------------------------------------------
Section("on the real sheet: the crosses and the strips where the model says")

-- Two more deaths a breath apart at A's time: a near wipe on the way, its
-- strip's arrow and its crosses where the model puts A.
run.deathLog[#run.deathLog + 1] = { guid = "Player-1-D", time = 1302, killer = { name = "Ragefire Trogg" } }
run.deathLog[#run.deathLog + 1] = { guid = G, time = 1304, killer = { name = "Ragefire Trogg" } }
run.endedAt = 1600 + 3600
ns.db.instances[run.id] = run
ns.UI.ShowJournal()
Check(ns.UI.OpenVisit(run.id, "journey"), "the run did not open")
local view = Page.Spread().map
Check(view:IsShown() and view.plan, "the sheet is not out")
local vp = view.plan
Check(vp.path and vp.path.course, "the sheet's way has no course")
local vnotes = vp.notes
Eq(#vnotes.wipes, 1, "half the group dead on the way")
-- Every pencil cross on the way sits where LegPoint puts its death, or
-- its wipe's (a wipe is one pull), fanned round it, placed by the model.
local pencil = 0
for _, cr in ipairs(vp.crosses) do if cr.pencil then pencil = pencil + 1 end end
Eq(pencil, 5, "the deaths on the way drawn")
local together = {}
for _, list in ipairs({ vnotes.wipes, vnotes.near or {} }) do
    for _, w in ipairs(list) do for _, d in ipairs(w.deaths) do together[d] = w end end
end
for _, l in ipairs(vnotes.legs) do
    local x, y, lhow = Page.LegPoint(vp.path, together[l.death] or l)
    Eq(lhow, "pace", "a death on the way not placed by the model")
    local hit = false
    for _, cr in ipairs(vp.crosses) do
        if cr.pencil and (cr.x - x) ^ 2 + (cr.y - y) ^ 2 <= (Page.DEATH.ring + 1e-6) ^ 2 then hit = true end
    end
    Check(hit, "no cross where the model puts a death")
end
-- The wipe's strip points where the model puts its first death.
local wt = vp.targets["wipe:1"]
local wx, wy = Page.LegPoint(vp.path, vnotes.wipes[1])
Check(wt and Near(wt.x, wx) and Near(wt.y, wy), "the wipe's target not where the model says")
local strip
for _, e in ipairs(view.noteStrips) do
    if e.target == wt then strip = e end
end
Check(strip, "no strip for the wipe on the way")

--------------------------------------------------------------------------
Section("/sd pace: the report and the packs on the map (Dev/PaceDebug.lua)")

local said = {}
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = tostring(msg) end
SlashCmdList.SOCIALDIARY("pace")
local text = table.concat(said, "\n")
if os.getenv("PACE_SHOW") then print(text) end  -- PACE_SHOW=1: the report as written
Check(text:find("fit: floor 213 by its art bounds; DCF's pins against the spawns: worst the way in", 1, true),
    "the report's fit: " .. text)
Check(text:find("leg to Oggleflint: 535 yd", 1, true), "the report's legs")
Check(select(2, text:gsub(": pace[^\n]- at ", "")) >= 5, "the report's moments placed by the model")
Check(text:find(": pace, with its wipe at ", 1, true), "the report's deaths with their wipe")
Check(text:find("your pauses kept: 0; inside ", 1, true), "the report's pauses and time getting on")
Check(text:find("Oggleflint killed 10:00", 1, true), "the report's kills")
-- Each moment in yards along the way.
Check(text:find("yd along", 1, true), "the report's yards along the way")
-- /sd pace at: Oggleflint's spawn is where his stop is.
said = {}
SlashCmdList.SOCIALDIARY("pace at -147.55 38.71")
Check(said[1] and said[1]:find("53%d yd along the way, %d off it"), "pace at Oggleflint: " .. tostring(said[1]))
said = {}
SlashCmdList.SOCIALDIARY("pace at 3.81, -14.82")
-- The handover's entrance lies some 15 yd along the way from DCF's way in
-- marker (where the way starts): two sources, a little apart.
local inYd = said[1] and tonumber(said[1]:match("(%d+) yd along the way"))
Check(inYd and inYd <= 20, "pace at the way in: " .. tostring(said[1]))
-- /sd pace here: wherever the client says you are (or why it cannot).
said = {}
SlashCmdList.SOCIALDIARY("pace here")
Check(said[1] and said[1]:find("^.-pace: "), "pace here says nothing")
-- Each death says what killed it, as the run recorded it.
Check(text:find("killed by Ragefire Trogg #? (guess)", 1, true), "the report's killers: " .. text)

-- The kill probe: kills inside a run counted, readable or hidden.
local mock = T.mock
local current = ns.Instances.Current
ns.Instances.Current = function() return run end
SocialDiaryCharDB.paceProbe = nil
local trogg = "Creature-0-1-389-0-11318-0000000001"
mock.fire("PARTY_KILL", G, trogg)
mock.fire("PARTY_KILL", G, "Creature-0-1-389-0-11320-0000000002")
mock.fire("PARTY_KILL", G, trogg)
mock.fire("PARTY_KILL", mock.secret(G), mock.secret(trogg))
mock.fire("PARTY_KILL", G, "Player-1-00000001")
ns.Instances.Current = current
local probe = SocialDiaryCharDB.paceProbe and SocialDiaryCharDB.paceProbe[run.id]
Check(probe, "the probe kept nothing")
Eq(probe.events, 5, "the kills seen")
Eq(probe.readable, 3, "the kills read")
Eq(probe.hidden, 1, "the kills hidden")
Eq(probe.other, 1, "a kill of something not a creature")
Eq(probe.attackerHidden, 1, "a killer hidden")
Eq(#probe.kills, 4, "the kills kept, a hidden one with its time only")
Eq(probe.kills[1].npc, 11318, "the first kill's NPC ID")
for _, k in ipairs(probe.kills) do
    for key in pairs(k) do Check(key == "t" or key == "npc", "the probe kept more than a time and an NPC ID") end
    Check(type(k.t) == "number", "a kill without its time")
end
-- Outside a run: nothing.
mock.fire("PARTY_KILL", G, trogg)
Eq(probe.events, 5, "a kill outside a run counted")
said = {}
SlashCmdList.SOCIALDIARY("pace")
text = table.concat(said, "\n")
Check(text:find("kill probe: 5 kills seen: 3 readable, 1 hidden, 1 not creatures; the killer hidden on 1", 1, true),
    "the report's probe: " .. text)
Check(text:find("#11318 x2, #11320 x1", 1, true), "the report's kills by NPC ID")
said = {}
SlashCmdList.SOCIALDIARY("pace clear")
Eq(SocialDiaryCharDB.paceProbe, nil, "the probe not cleared")

local hitsBefore = view.pools.hit.used
SlashCmdList.SOCIALDIARY("pace map")
Eq(Page.DevOverlay ~= nil, true, "the overlay not on")
Eq(view.pools.hit.used, hitsBefore + #ns.PaceData[RFC].packs, "a tooltip for every pack")
SlashCmdList.SOCIALDIARY("pace map")
Eq(Page.DevOverlay, nil, "the overlay not off")
Eq(view.pools.hit.used, hitsBefore, "the packs left on the map")
DEFAULT_CHAT_FRAME.AddMessage = add

ns.UI.OpenVisit(run.id, "journey")
ns.db.instances[run.id] = nil

--------------------------------------------------------------------------
Section("the killer: at a pull of what killed them (KILLER)")

-- The pattern of a real run (3 Nov 2026, Ragefire Chasm, two level 60s in
-- a level 15 group): its times, kills and killers, the names and GUIDs
-- made up. Oggleflint fell 12:19 in, Taragaman 25:02; a ghost's run out
-- and back of 18 s between.
local S = 100000
local function Killed(name, npc) return { name = name, npcID = npc, source = "recap" } end
local replay = {
    id = 9390, instanceID = RFC, name = "Ragefire Chasm", startedAt = S, me = G,
    members = { { guid = G }, { guid = "Player-1-A" }, { guid = "Player-1-B" }, { guid = "Player-1-C" },
        { guid = "Player-1-D" } },
    spans = { { from = S, to = S + 1258, ghost = true }, { from = S + 1276 } },
    bossesKilled = { "Oggleflint", "Taragaman the Hungerer" },
    pulls = { { id = 2732, name = "Oggleflint", start = S + 739, stop = S + 739, killed = true },
        { id = 2733, name = "Taragaman the Hungerer", start = S + 1502, stop = S + 1502, killed = true } },
    deathLog = {
        { guid = "Player-1-A", time = S + 170, killer = Killed("Ragefire Trogg", 11318) },
        { guid = "Player-1-B", time = S + 369, killer = Killed("Oggleflint", 11517) },
        { guid = "Player-1-C", time = S + 844, killer = Killed("Molten Elemental", 11321) },
        { guid = "Player-1-D", time = S + 855, killer = Killed("Molten Elemental", 11321) },
        { guid = G, time = S + 880, killer = Killed("Molten Elemental", 11321) },
        { guid = "Player-1-A", time = S + 1562, killer = Killed("Searing Blade Enforcer", 11323) },
        { guid = "Player-1-B", time = S + 1770, killer = Killed("Voidwalker Minion", 8996) },
    },
}
Eq(ns.PaceData[RFC].summons[8996], 11324, "the Voidwalker Minion is no Searing Blade Warlock's")
local rn = Run.Notes(replay)
local rplan = Page.Plan({ visit = replay, floor = floor, box = { x = 0, y = 0, w = W, h = H }, At = At, notes = rn,
    route = true })
local rpath = rplan.path
-- The pull a point lies at, and the NPC IDs in it.
local function PullAt(x, y)
    local gx, gy = fit.ToGame(x / W, y / H)
    local yd = Pace.Project(rpath.course, gx, gy)
    local best, bd
    for _, p in ipairs(rpath.course.pulls) do
        local d = math.abs(p.at - yd)
        if not bd or d < bd then best, bd = p, d end
    end
    return best, bd, yd
end
local function Holds(p, npc)
    for _, id in ipairs(p.npcs or {}) do if id == npc then return true end end
end
local placed = {}
for _, l in ipairs(rn.legs) do
    local x, y, lhow = Page.LegPoint(rpath, l)
    local npc = l.death.killer.npcID
    Eq(lhow, "killer", l.death.killer.name .. "'s death not placed by its killer")
    local p, off, yd = PullAt(x, y)
    Check(off <= clear + 0.5, l.death.killer.name .. "'s death off a pull: " .. off)
    Check(Holds(p, npc) or Holds(p, ns.PaceData[RFC].summons[npc]),
        l.death.killer.name .. "'s death at a pull without it: " .. table.concat(p.names, "/"))
    placed[#placed + 1] = { name = l.death.killer.name, yd = yd, l = l }
end
Eq(#placed, 6, "the deaths on the way (Oggleflint's is his)")
if os.getenv("PACE_SHOW") then  -- PACE_SHOW=1: the replay as placed, against the time alone
    for _, e in ipairs(placed) do
        local l = e.l
        local i0 = l.after and rpath.stops[D.Norm(l.after.name)] or 1
        local i9 = l.before and rpath.stops[D.Norm(l.before.name)] or (i0 == i1 and i2 or i0 == i2 and i3 or i1)
        local t = Pace.Place(rpath.course, i0, i9, l.dt, not l.open and l.known or nil)
        local p = PullAt(Page.LegPoint(rpath, l))
        print(("%-24s time alone %5.0f yd   killer %5.0f yd  (%s)"):format(e.name, t, e.yd, table.concat(p.names, "/")))
    end
end
-- Each where the time alone could not: the Trogg past the Earthborers,
-- the three Elementals together at their pulls on the way to Taragaman.
-- The pull the time alone would choose, and what stands there.
local function NearestPull(yd)
    local best
    for _, p in ipairs(rpath.course.pulls) do
        if not best or math.abs(p.at - yd) < math.abs(best.at - yd) then best = p end
    end
    return best
end
Check(placed[1].yd < course.cum[i1], "the Trogg past Oggleflint: " .. placed[1].yd)
local tyd = Pace.Place(rpath.course, 1, i1, placed[1].l.dt, placed[1].l.known)
Check(not Holds(NearestPull(tyd), 11318), "the time alone already at a Trogg pull")
Check(Near(placed[2].yd, placed[3].yd, 0.5) and Near(placed[3].yd, placed[4].yd, 0.5), "the wipe's deaths apart")
Check(placed[2].yd > course.cum[i1] and placed[2].yd < course.cum[i2], "the Elementals off the leg to Taragaman: " .. placed[2].yd)
local myd = Pace.Place(rpath.course, i1, i2, placed[2].l.dt, placed[2].l.known)
Check(not Holds(NearestPull(myd), 11321), "the time alone already at an Elemental pull")
-- The wipe's strip points at the Elementals too.
Eq(#rn.wipes, 1, "the Elementals' wipe")
local _, _, whow2 = Page.LegPoint(rpath, rn.wipes[1])
Eq(whow2, "killer", "the wipe not placed by its killer")
-- Past Taragaman: the Enforcer, and the Warlock's Voidwalker at a Warlock.
Check(placed[5].yd > course.cum[i2] and placed[5].yd < course.cum[i3], "the Enforcer off the leg to Jergosh")
Check(placed[6].yd > course.cum[i2] and placed[6].yd < course.cum[i3], "the Voidwalker off the leg to Jergosh")

-- What the killer cannot say, the time does.
local dt0 = placed[2].l.dt
local function How(leg) return select(3, Page.LegPoint(rpath, leg)) end
local base = { after = placed[5].l.after, before = placed[5].l.before, open = placed[5].l.open,
    frac = placed[5].l.frac, dt = placed[5].l.dt, known = placed[5].l.known }
local function With(killer)
    local l = {}
    for k, v in pairs(base) do l[k] = v end
    l.death = { guid = "Player-1-A", time = S + 1562, killer = killer }
    return l
end
Eq(How(With(Killed("Molten Elemental", 11321))), "pace", "a killer from another leg placed by it")
Eq(How(With(Killed("Kobold Vermin", 6))), "pace", "a killer in no pull placed by it")
Eq(How(With({ player = true, npcID = 11323 })), "pace", "a player killer placed by it")
Eq(How(With(nil)), "pace", "no killer")
Eq(How(With({ name = "Searing Blade Enforcer" })), "pace", "a killer without its NPC ID")
-- Directly: no NPC ID, the time's answer; the same with one in no pull.
local a1, _, _, h1 = Pace.Place(rpath.course, i1, i2, dt0, nil)
local a2, _, _, h2 = Pace.Place(rpath.course, i1, i2, dt0, nil, 99999)
Eq(h1, "time", "no killer: not the time")
Eq(h2, "time", "a killer in no pull: not the time")
Check(Near(a1, a2), "a killer in no pull moved it")
-- Always at a pull holding it, whatever the time.
for dt = 0, 3000, 150 do
    local yd, _, leg, h = Pace.Place(rpath.course, i1, i2, dt, nil, 11321)
    Eq(h, "killer", "the Elementals' killer at " .. dt .. " s")
    local ok = false
    for _, p in ipairs(leg.pulls) do
        if Near(leg.from + p.at, yd) and Holds(p, 11321) then ok = true end
    end
    Check(ok, "a death to an Elemental not at an Elemental at " .. dt .. " s")
end
do
-- An open leg, a Trogg's: the later the death, never an earlier pull, and
-- never past the next Trogg pull at once (4 Nov 2026: taking the heaviest
-- on the model's sampled grid went 173 times between Trogg pulls in 1100
-- s, 75 of them back, once 300 yd).
local trogg = {}
for i, p in ipairs(leg1.pulls) do if Holds(p, 11318) then trogg[#trogg + 1] = i end end
local rank = {}
for r, i in ipairs(trogg) do rank[leg1.from + leg1.pulls[i].at] = r end
local tprev, moves = nil, 0
for dt = 0, 1100 do
    local yd, _, _, h = Pace.Place(course, 1, i1, dt, nil, 11318)
    Eq(h, "killer", "a Trogg's death not placed by it at " .. dt .. " s")
    local r = rank[yd]
    Check(r, ("a Trogg's death at %.1f yd, no Trogg pull, at %d s"):format(yd, dt))
    if tprev and r ~= tprev then
        moves = moves + 1
        Check(r == tprev + 1, ("a Trogg's death went from Trogg pull %d to %d at %d s"):format(tprev, r, dt))
    end
    tprev = r
end
Check(moves >= 4 and moves < #trogg, "a Trogg's death moved " .. moves .. " times along the leg")
-- The weights: exact, so a second more moves each pull's by little (at
-- most 4% where it counts; on the sampled grid, a quarter).
for dt = 200, 700 do
    local a, b = Pace.Weights(leg1, dt), Pace.Weights(leg1, dt + 1)
    local top = 0
    for _, w in pairs(a) do top = math.max(top, w) end
    for _, i in ipairs(trogg) do
        local wa, wb = a[i] or 0, b[i] or 0
        Check(wa < 0.05 * top or math.abs(wb - wa) <= 0.08 * wa,
            ("pull %d's weight jumped from %.4f to %.4f at %d s"):format(i, wa, wb, dt))
    end
end
end
-- A known leg: the pull holding it nearest where the time says.
local kyd, kr, kleg = Pace.Place(rpath.course, 1, i1, 170, 739, 11318)
local nearest
for _, p in ipairs(kleg.pulls) do
    if Holds(p, 11318) and (not nearest or math.abs(p.at - kr.yd) < math.abs(nearest.at - kr.yd)) then nearest = p end
end
Check(Near(kyd, kleg.from + nearest.at), "a known leg's killer not at the nearest Trogg")

--------------------------------------------------------------------------
Section("a wipe is one pull: its strip and all its crosses there")

-- The pattern of a second real run (3 Nov 2026): no kill yet, two wipes on
-- the way to Oggleflint, some deaths without a killer; names made up.
local S2 = 200000
local twice = {
    id = 9391, instanceID = RFC, name = "Ragefire Chasm", startedAt = S2, me = G,
    members = { { guid = G }, { guid = "Player-1-A" }, { guid = "Player-1-B" }, { guid = "Player-1-C" },
        { guid = "Player-1-D" } },
    spans = { { from = S2 } }, bossesKilled = {}, pulls = {},
    deathLog = {
        { guid = "Player-1-A", time = S2 + 22 },
        { guid = "Player-1-B", time = S2 + 26, killer = Killed("Earthborer", 11320) },
        { guid = "Player-1-C", time = S2 + 36 },
        { guid = "Player-1-D", time = S2 + 125, killer = Killed("Earthborer", 11320) },
        { guid = "Player-1-A", time = S2 + 282 },
        { guid = "Player-1-D", time = S2 + 288 },
        { guid = "Player-1-B", time = S2 + 296, killer = Killed("Ragefire Trogg", 11318) },
        { guid = "Player-1-C", time = S2 + 333, killer = Killed("Ragefire Trogg", 11318) },
    },
}
local tn = Run.Notes(twice)
Eq(#tn.wipes, 2, "the two wipes")
Eq(#tn.wipes[1].deaths, 3, "the first wipe's deaths")
Eq(#tn.wipes[2].deaths, 4, "the second wipe's deaths")
local tplan = Page.Plan({ visit = twice, floor = floor, box = { x = 0, y = 0, w = W, h = H }, At = At, notes = tn,
    route = true })
local tpath = tplan.path
local function YdAt(x, y) return (Pace.Project(tpath.course, fit.ToGame(x / W, y / H))) end
-- The second wipe: placed from the last sure place before it (the lone
-- Earthborer death at 2:05, an anchor), at the Trogg pull where, along the
-- way, its two Trogg deaths' weight together (their seconds since that
-- anchor, Pace.Weights) passes half.
local w2x, w2y, w2how, w2info = Page.LegPoint(tpath, tn.wipes[2])
Check(w2info and w2info.anchor, "the second wipe not placed from an anchor")
Eq(w2info.anchor.dt, 125, "the second wipe's anchor not the last sure death before it")
local anchorPull = NearestPull(w2info.anchor.yd)
Check(Near(anchorPull.at, w2info.anchor.yd, 0.5) and Holds(anchorPull, 11320),
    "the anchor not at an Earthborer pull: " .. w2info.anchor.yd)
local leg1t = Pace.Leg(tpath.course, 1, i1, w2info.anchor.yd)
local want2
do
local sum, total = {}, 0
for _, dt in ipairs({ 296 - 125, 333 - 125 }) do
    for i, w in pairs(Pace.Weights(leg1t, dt)) do
        if Holds(leg1t.pulls[i], 11318) then
            sum[i] = (sum[i] or 0) + w
            total = total + w
        end
    end
end
local acc = 0
for i = 1, #leg1t.pulls do
    acc = acc + (sum[i] or 0)
    if not want2 and total > 0 and acc >= total / 2 then want2 = i end
end
end
Check(want2, "no Trogg pull weighed for the second wipe")
Eq(w2how, "killer", "the second wipe not placed by its killers")
Check(Near(YdAt(w2x, w2y), leg1t.from + leg1t.pulls[want2].at, 0.5),
    ("the second wipe not at the middle of its deaths' weight: %.0f, want %.0f"):format(YdAt(w2x, w2y),
        leg1t.from + leg1t.pulls[want2].at))
-- Its first death, alone, has no killer; the wipe is not where that alone
-- puts it, nor where its first Trogg death alone does, necessarily: one
-- place for all.
local w1x, w1y = Page.LegPoint(tpath, tn.wipes[1])
local firstEarthborer
for _, p in ipairs(tpath.course.pulls) do
    if Holds(p, 11320) and (not firstEarthborer or p.at < firstEarthborer.at) then firstEarthborer = p end
end
Check(math.abs(YdAt(w1x, w1y) - math.max(Page.PACE_CLEAR, firstEarthborer.at)) < 1,
    "the first wipe not at the first Earthborers: " .. YdAt(w1x, w1y))

-- On the sheet: every cross of a wipe within a ring of where its strip
-- points, whatever killed it or did not.
ns.db.instances[twice.id] = twice
Check(ns.UI.OpenVisit(twice.id, "journey"), "the second run did not open")
local tv = Page.Spread().map
local tvp = tv.plan
for wi, w in ipairs(tvp.notes.wipes) do
    local t = tvp.targets["wipe:" .. wi]
    Check(t, "no target for wipe " .. wi)
    local crosses = 0
    for _, d in ipairs(w.deaths) do
        for _, cr in ipairs(tvp.crosses) do
            if cr.pencil and (cr.x - t.x) ^ 2 + (cr.y - t.y) ^ 2 <= (Page.DEATH.ring + 1e-6) ^ 2 then
                crosses = crosses + 1
                break
            end
        end
    end
    Eq(crosses, #w.deaths, "a cross of wipe " .. wi .. " away from its strip's target")
end
-- Pencil crosses round wipe 2's target: its four deaths, fanned.
local round = 0
local t2 = tvp.targets["wipe:2"]
for _, cr in ipairs(tvp.crosses) do
    if cr.pencil and (cr.x - t2.x) ^ 2 + (cr.y - t2.y) ^ 2 <= (Page.DEATH.ring + 1e-6) ^ 2 then round = round + 1 end
end
Eq(round, 4, "the second wipe's crosses round its target")
ns.UI.OpenVisit(twice.id, "journey")
ns.db.instances[twice.id] = nil

-- PlaceGroup directly: no killer among them, the first's time; a known
-- leg, the pull holding one nearest where the time puts them on average.
local g1, _, _, gh1 = Pace.PlaceGroup(tpath.course, 1, i1, { { dt = 282 }, { dt = 288 } })
Eq(gh1, "time", "a group without killers not by time")
Check(Near(g1, (Pace.Place(tpath.course, 1, i1, 282))), "a group without killers not at its first's time")
local kg, _, kleg2, kh = Pace.PlaceGroup(tpath.course, 1, i1, { { dt = 100, npc = 11318 }, { dt = 140, npc = 11318 } }, 600)
Eq(kh, "killer", "a known group not by its killers")
local mean = ((Model.PlaceDeath(kleg2, 100, nil, { knownKill = 600 }).yd) + (Model.PlaceDeath(kleg2, 140, nil, { knownKill = 600 }).yd)) / 2
local nearestT
for _, p in ipairs(kleg2.pulls) do
    if Holds(p, 11318) and (not nearestT or math.abs(p.at - mean) < math.abs(nearestT.at - mean)) then nearestT = p end
end
Check(Near(kg, kleg2.from + nearestT.at), "a known group not at the Trogg nearest its mean")
Eq(Pace.PlaceGroup(tpath.course, 1, i1, {}), nil, "a group of nothing")

--------------------------------------------------------------------------
Section("the user's pauses kept on the run (Instances.Combat)")

do
    local I = ns.Instances
    local least = I.PAUSE.least
    local t0 = mock.now
    local v = I.Enter({ instanceID = RFC, name = "Ragefire Chasm", instanceType = "party", difficultyID = 1 }, t0)
    local function At(dt) mock.now = t0 + dt end
    At(10) mock.fire("PLAYER_REGEN_DISABLED")      -- the first fight: no pause before it
    At(40) mock.fire("PLAYER_REGEN_ENABLED")
    At(40 + least - 5) mock.fire("PLAYER_REGEN_DISABLED")   -- a short break: no pause
    At(80) mock.fire("PLAYER_REGEN_ENABLED")
    At(80) mock.fire("PLAYER_REGEN_ENABLED")       -- twice: nothing more
    At(200) mock.fire("PLAYER_REGEN_DISABLED")     -- a pause of 120 s
    At(200) mock.fire("PLAYER_REGEN_DISABLED")     -- twice: nothing more
    I.Leave(t0 + 250, true)                         -- out as a ghost mid-fight: the pause starts
    At(255) mock.fire("PLAYER_REGEN_ENABLED")       -- outside: nothing
    At(270) mock.fire("PLAYER_REGEN_DISABLED")      -- outside: nothing
    I.Enter({ instanceID = RFC, name = "Ragefire Chasm", instanceType = "party", difficultyID = 1 }, t0 + 300)
    At(340) mock.fire("PLAYER_REGEN_DISABLED")      -- the pause across the time outside ends
    Check(type(v.pauses) == "table", "no pauses kept")
    Eq(#v.pauses, 2, "the pauses kept")
    Eq(v.pauses[1].from, t0 + 80, "the first pause's start")
    Eq(v.pauses[1].to, t0 + 200, "the first pause's end")
    Eq(v.pauses[2].from, t0 + 250, "a pause not started at going out")
    Eq(v.pauses[2].to, t0 + 340, "a pause across the time outside not ended at the next fight")
    Eq(v.fighting, true, "in a fight")
    At(360) mock.fire("PLAYER_REGEN_ENABLED")
    I.Close(t0 + 380)
    Eq(v.calm, nil, "a pause left open at the run's end")
    Eq(v.fighting, nil, "a fight left open at the run's end")
    Eq(#v.pauses, 2, "a pause kept at the run's end")
    -- At most PAUSE.most a run.
    local full = I.Enter({ instanceID = 43, name = "Wailing Caverns", instanceType = "party", difficultyID = 1 }, t0 + 400)
    for k = 1, I.PAUSE.most + 5 do
        At(400 + k * 100) mock.fire("PLAYER_REGEN_DISABLED")
        At(400 + k * 100 + 10) mock.fire("PLAYER_REGEN_ENABLED")
    end
    Eq(#full.pauses, I.PAUSE.most, "the pauses past the cap")
    I.Close(mock.now)
    ns.db.instances[v.id], ns.db.instances[full.id] = nil, nil
    mock.now = t0
end

--------------------------------------------------------------------------
Section("the time spent getting on: long waits left out (IDLE)")

do
    local most = Run.IDLE.most
    -- A pause of 260 s (40 to 300) counts `most`.
    local v = { startedAt = 0, spans = { { from = 0 } }, pauses = { { from = 40, to = 300 } } }
    Eq(Run.Active(v, 0, 400), 400 - (260 - most), "a long wait not left out")
    Eq(Run.Active(v, 0, 250), 250 - (210 - most), "the part of a wait before the moment not left out")
    Eq(Run.Active(v, 0, 100), 100, "a short part of a wait left out")
    Eq(Run.Active(v, 320, 400), 80, "after the wait")
    Eq(Run.Active(v, 200, 400), 200, "from part way into a wait: the rest of it short")
    -- Time outside is not left out twice.
    local away2 = { startedAt = 0, spans = { { from = 0, to = 200 }, { from = 260 } }, pauses = { { from = 40, to = 300 } } }
    Eq(Run.Active(away2, 0, 400), 340 - (200 - most), "time outside left out twice")
    -- Without pauses kept: the time inside.
    Eq(Run.Active({ startedAt = 0, spans = { { from = 0 } } }, 0, 900), 900, "a run without pauses kept")
    -- The notes go by it.
    local w = Run.When(v, { bosses = {} }, 400)
    Eq(w.dt, 400 - (260 - most), "a moment's seconds into its leg not by the time getting on")
end

--------------------------------------------------------------------------
Section("sure places: a leg placed on from the last one (Anchors)")

-- A wipe to Troggs, then ten minutes of nothing (a rez, drinking), then a
-- second wipe to Troggs: the same pull.
local S3 = 300000
local function Wipe(at, who)
    local list = {}
    for k, guid in ipairs(who) do
        list[#list + 1] = { guid = guid, time = S3 + at + k * 3, killer = Killed("Ragefire Trogg", 11318) }
    end
    return list
end
local again = {
    id = 9392, instanceID = RFC, name = "Ragefire Chasm", startedAt = S3, me = G,
    members = { { guid = G }, { guid = "Player-1-A" }, { guid = "Player-1-B" }, { guid = "Player-1-C" },
        { guid = "Player-1-D" } },
    spans = { { from = S3 } }, bossesKilled = {}, pulls = {}, deathLog = {},
    -- The user's pauses between fights (20-60, 100-140, 200-290, 950-1000).
    pauses = { { from = S3 + 60, to = S3 + 100 }, { from = S3 + 140, to = S3 + 200 }, { from = S3 + 290, to = S3 + 950 } },
}
for _, d in ipairs(Wipe(280, { "Player-1-A", "Player-1-B", "Player-1-C" })) do again.deathLog[#again.deathLog + 1] = d end
for _, d in ipairs(Wipe(990, { "Player-1-A", "Player-1-B", "Player-1-D" })) do again.deathLog[#again.deathLog + 1] = d end
local function Placed(visit)
    local n = Run.Notes(visit)
    local plan = Page.Plan({ visit = visit, floor = floor, box = { x = 0, y = 0, w = W, h = H }, At = At, notes = n,
        route = true })
    local out = {}
    for i, w in ipairs(n.wipes) do
        local x, y, how, info = Page.LegPoint(plan.path, w)
        out[i] = { yd = Pace.Project(plan.path.course, fit.ToGame(x / W, y / H)), how = how, info = info }
    end
    return out, n, plan
end
local p, an = Placed(again)
Eq(#an.wipes, 2, "the two wipes")
Eq(p[1].how, "killer", "the first wipe not by its killers")
Eq(p[2].how, "killer", "the second wipe not by its killers")
Check(p[2].info.anchor, "the second wipe not placed from the first")
Check(Near(p[1].yd, p[2].yd, 0.5), ("the second wipe not at the first's pull: %.0f, then %.0f"):format(p[1].yd, p[2].yd))
-- The wait taken out by the pauses: without them, the second goes on.
local bare = {}
for k, v in pairs(again) do bare[k] = v end
bare.id, bare.pauses = 9393, nil
local q = Placed(bare)
Check(q[2].yd > q[1].yd + 30, ("without the pauses kept the second wipe stays: %.0f, then %.0f"):format(q[1].yd, q[2].yd))
-- Nothing placed from an anchor lies behind it: moments after the first
-- wipe, at any time (a roll found on the way, as Anchor asks).
local _, _, aplan = Placed(again)
local first = an.wipes[1]
local behind = 0
for later = 10, 1500, 50 do
    local leg = Run.When(again, an, first.deaths[1].time + later)
    local x, y, _, info = Page.LegPoint(aplan.path, leg)
    if info and info.anchor then
        behind = behind + 1
        local yd = Pace.Project(aplan.path.course, fit.ToGame(x / W, y / H))
        Check(yd >= info.anchor.yd - 0.5, ("a moment %d s after the wipe placed behind it: %.0f < %.0f")
            :format(later, yd, info.anchor.yd))
    end
end
Check(behind > 20, "moments after the wipe not placed from it: " .. behind)

-- After a wipe, with the pauses kept: the clock starts again where the
-- pause after it ends (the next fight).
local ra = p[2].info.anchor
Eq(ra.wipe, true, "the first wipe's anchor not a wipe's")
Check(Near(p[2].info.shift, ra.dt + Run.Active(again, ra.time, S3 + 950), 1e-6),
    "the clock not started again at the first fight after the wipe")

-- Out and back in between (a release, a run back), no pauses kept: the
-- walk back from the way in to the anchor is not time getting on.
local out = {}
for k, v in pairs(again) do out[k] = v end
out.id = 9394
out.pauses = nil
out.spans = { { from = S3, to = S3 + 400, ghost = true }, { from = S3 + 700 } }
local r, rn2 = Placed(out)
local a = r[2].info.anchor
Check(a, "after a run back, no anchor")
Check(Near(r[2].info.shift, a.dt + a.yd / Model.DEFAULTS.speed, 1e-6),
    ("the walk back not taken off: shift %.1f, anchor %.1f s at %.0f yd"):format(r[2].info.shift, a.dt, a.yd))
Check(Near(q[2].info.shift, q[2].info.anchor.dt, 1e-6), "a walk back taken off without going out")
Eq(#rn2.wipes, 2, "the wipes after a run back")

-- A leg whose boss fell: from the anchor, the rest of the leg's time.
local closed = {}
for k, v in pairs(again) do closed[k] = v end
closed.id = 9395
closed.bossesKilled = { "Oggleflint" }
closed.pulls = { { id = 2732, name = "Oggleflint", start = S3 + 1400, stop = S3 + 1400, killed = true } }
local c3 = Placed(closed)
Check(c3[2].info.anchor, "a known leg not placed from the anchor")
Check(c3[2].yd >= c3[2].info.anchor.yd - 0.5 and c3[2].yd <= course.cum[i1], "a known leg's wipe off the rest of it")

-- /sd pace on the repeated wipe: the second placed on from the first.
ns.db.instances[again.id] = again
local add2 = DEFAULT_CHAT_FRAME.AddMessage
local said2 = {}
DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said2[#said2 + 1] = tostring(msg) end
SlashCmdList.SOCIALDIARY("pace")
DEFAULT_CHAT_FRAME.AddMessage = add2
local text2 = table.concat(said2, "\n")
Check(text2:find("your pauses kept: 3", 1, true), "the report's pauses: " .. text2)
Check(text2:find("placed on from the sure place at %d+ yd %(a wipe"), "the report's anchor: " .. text2)
ns.db.instances[again.id] = nil
