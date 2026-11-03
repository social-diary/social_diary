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
Eq(fit.anchors, 5, "the anchors: the way in and four bosses")
Check(fit.worst < 6, "an anchor off by more than 6 yd: " .. fit.worst)
for _, b in ipairs(ns.PaceData[RFC].bosses) do
    local m = D.Boss(RFC, b.name)
    Check(m, "a boss of the data not in the map's: " .. b.name)
    local gx, gy = fit.ToGame(m.x, m.y)
    Check(math.sqrt((gx - b.x) ^ 2 + (gy - b.y) ^ 2) < 6, b.name .. " off its spawn")
    local fx, fy = fit.ToFloor(gx, gy)
    Check(Near(fx, m.x, 1e-9) and Near(fy, m.y, 1e-9), "there and back again")
end

-- A boss moved 40 yd: no fit, and nothing laid.
local boss1 = ns.PaceData[RFC].bosses[1]
local x0 = boss1.x
boss1.x = x0 + 40
Pace.Reset()
Eq(Pace.Fit(RFC), nil, "a fit with a boss 40 yd off")
Eq(Pace.Course({ instanceID = RFC }, D.Route(RFC)), nil, "a course without a fit")
boss1.x = x0
Pace.Reset()
Check(Pace.Fit(RFC), "the fit back")
-- Too few anchors on one floor.
local bosses = ns.PaceData[RFC].bosses
ns.PaceData[RFC].bosses = { bosses[1], bosses[2] }
Pace.Reset()
Eq(Pace.Fit(RFC), nil, "a fit on three anchors")
ns.PaceData[RFC].bosses = bosses
Pace.Reset()
-- No data: nothing.
Eq(Pace.Fit(47), nil, "a fit without data")
Eq(Pace.Course({ instanceID = 47 }, D.Route(47)), nil, "a course without data")

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
-- The legs in yards (3 Nov 2026: the usual way clears the side rooms).
local want = { 520, 681, 195, 429 }
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
-- Every pencil cross on the way sits where LegPoint puts its death (or
-- fanned round it), and LegPoint placed them by the model.
local pencil = 0
for _, cr in ipairs(vp.crosses) do if cr.pencil then pencil = pencil + 1 end end
Eq(pencil, 5, "the deaths on the way drawn")
for _, l in ipairs(vnotes.legs) do
    local x, y, lhow = Page.LegPoint(vp.path, l)
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
Check(text:find("fit: floor 213, 5 anchors", 1, true), "the report's fit: " .. text)
Check(text:find("leg to Oggleflint: 520 yd", 1, true), "the report's legs")
Check(select(2, text:gsub(": pace at ", "")) >= 5, "the report's moments placed by the model")
Check(text:find("Oggleflint killed 10:00", 1, true), "the report's kills")
-- Each moment in yards along the way.
Check(text:find("yd along", 1, true), "the report's yards along the way")
-- /sd pace at: Oggleflint's spawn is where his stop is.
said = {}
SlashCmdList.SOCIALDIARY("pace at -147.55 38.71")
Check(said[1] and said[1]:find("52%d yd along the way, %d off it"), "pace at Oggleflint: " .. tostring(said[1]))
said = {}
SlashCmdList.SOCIALDIARY("pace at 3.81, -14.82")
Check(said[1] and said[1]:find(" [0-5] yd along the way"), "pace at the way in: " .. tostring(said[1]))
-- /sd pace here: wherever the client says you are (or why it cannot).
said = {}
SlashCmdList.SOCIALDIARY("pace here")
Check(said[1] and said[1]:find("^.-pace: "), "pace here says nothing")
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
