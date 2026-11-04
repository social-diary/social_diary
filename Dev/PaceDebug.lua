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
--   /sd pace clear    forget the kill probe's counts (below)
--   /sd pace map      on the map sheet, over the marks: every pack of the
--                     pace data (red where a pull on the way, grey where the
--                     way does not pass it, larger for more elites), each
--                     with a tooltip, and the data's way in and bosses
--                     (blue rings: how far the fit puts them off the map's
--                     own); again to take it off
--
-- The report gives the run's time inside and the part of it spent getting
-- on (Core/DungeonRun.lua's Active: a wait out of combat past IDLE.most is
-- left out), and for a moment placed on from a sure place before it (a
-- death placed by its killer: Print.lua's Anchors), where that was and
-- how much time was taken off.
--
-- Each death also says what killed it as the run recorded it (name, NPC
-- ID, from the recap or the guess at the moment), "hidden" where the
-- client kept it back, or "no killer".
--
-- The kill probe: while inside a run, every PARTY_KILL is counted, and
-- whether its victim's GUID could be read (an NPC ID) or was secret; each
-- is kept in order (seconds into the run, and its NPC ID where readable),
-- at most PROBE.most a run. (3 Nov 2026, Ragefire Chasm: all 30 creature
-- kills came secret, the killer too; the count and the time are what is
-- left.) It is to learn whether trash kills can be counted
-- inside an instance on Forever (a count along the way: 3 Nov 2026), so
-- it holds creatures only, never a player's name or GUID. Kept in
-- SocialDiaryCharDB.paceProbe by run until /sd pace clear; /sd pace
-- reports it with the run.
--
-- Prints names from the run. Dev only: the TOC's Dev/ block never goes in a
-- release.

local addonName, ns = ...

local Page = ns.UI.DungeonPage

local RED, GREY = { 0.70, 0.13, 0.10 }, { 0.35, 0.35, 0.35 }
-- The kill probe keeps at most `most` readable kills a run.
local PROBE = { most = 400 }

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
    local first = ns.Characters and ns.Characters.Name and ns.Characters.Name(guid)
    return first or tostring(guid):sub(-6)
end

-- What killed a death, as the run recorded it.
local function Killer(death)
    local k = death and death.killer
    if type(k) ~= "table" then return "no killer" end
    if k.environment then return "the world (" .. tostring(k.environment) .. ")" end
    if k.player then return "a player" end
    if not (k.name or k.npcID) then return "hidden (" .. tostring(k.source or "guess") .. ")" end
    return ("%s #%s (%s)"):format(tostring(k.name or "?"), tostring(k.npcID or "?"), tostring(k.source or "guess"))
end

--------------------------------------------------------------------------
-- The kill probe
--------------------------------------------------------------------------

local function ProbeStore(create)
    if type(SocialDiaryCharDB) ~= "table" then return nil end
    if type(SocialDiaryCharDB.paceProbe) ~= "table" then
        if not create then return nil end
        SocialDiaryCharDB.paceProbe = {}
    end
    return SocialDiaryCharDB.paceProbe
end

-- A kill by the group, while a run is open: counted, its victim's NPC ID
-- kept where it can be read.
local function Probe(attacker, victim)
    local visit = ns.Instances and ns.Instances.Current and ns.Instances.Current()
    if not visit or not visit.id then return end
    local store = ProbeStore(true)
    if not store then return end
    local run = store[visit.id]
    if type(run) ~= "table" then
        run = { instanceID = visit.instanceID, events = 0, readable = 0, hidden = 0, other = 0, attackerHidden = 0,
            kills = {} }
        store[visit.id] = run
    end
    run.events = run.events + 1
    if ns.IsSecret(attacker) then run.attackerHidden = run.attackerHidden + 1 end
    local t = math.floor(ns.Now() - (visit.startedAt or ns.Now()))
    if ns.IsSecret(victim) then
        run.hidden = run.hidden + 1
        if #run.kills < PROBE.most then run.kills[#run.kills + 1] = { t = t } end
        return
    end
    local npc = ns.NpcID(victim)
    if not npc then
        -- A player, a pet, or a GUID of another shape: not a creature.
        run.other = run.other + 1
        return
    end
    run.readable = run.readable + 1
    if #run.kills < PROBE.most then run.kills[#run.kills + 1] = { t = t, npc = npc } end
end

ns.On("PARTY_KILL", function(_, attacker, victim) Probe(attacker, victim) end)

-- The probe's line for `visit`, said.
local function ReportProbe(visit)
    local store = ProbeStore(false)
    local run = store and store[visit.id]
    if type(run) ~= "table" then
        Say("  kill probe: nothing seen on this run (it counts from when it was loaded, inside a run)")
        return
    end
    Say("  kill probe: %d kills seen: %d readable, %d hidden, %d not creatures; the killer hidden on %d",
        run.events, run.readable, run.hidden, run.other, run.attackerHidden)
    local byNpc, order = {}, {}
    for _, k in ipairs(run.kills) do
        if k.npc then
            if not byNpc[k.npc] then order[#order + 1] = k.npc end
            byNpc[k.npc] = (byNpc[k.npc] or 0) + 1
        end
    end
    local parts = {}
    for _, npc in ipairs(order) do parts[#parts + 1] = ("#%d x%d"):format(npc, byNpc[npc]) end
    if #parts > 0 then Say("  by NPC ID: %s", table.concat(parts, ", ")) end
    local first = run.kills[1]
    local last = run.kills[#run.kills]
    if first then Say("  the kills from %s to %s into the run", Clock(first.t), Clock(last.t)) end
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
    if fit.method == "bounds" then
        Say("  fit: floor %d by its art bounds; DCF's pins against the spawns: worst %s, %.1f yd (%d compared; a note on the map's icons, not the fit)",
            fit.floor, tostring(fit.worstName or "-"), fit.worst, fit.anchors)
    else
        Say("  fit: floor %d through %d pins (no art bounds), worst %.1f yd off", fit.floor, fit.anchors, fit.worst)
    end
    local fights = type(visit.pauses) == "table" and #visit.pauses or 0
    local inside = ns.DungeonRun.InsideBetween(visit, visit.startedAt or 0, visit.endedAt or ns.Now())
    local active = ns.DungeonRun.Active(visit, visit.startedAt or 0, visit.endedAt or ns.Now())
    Say("  your pauses kept: %d; inside %s, of it getting on %s (waits past %s left out)", fights, Clock(inside),
        Clock(active), Clock(ns.DungeonRun.IDLE.most))
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
    -- A wipe's deaths lie where the wipe does, as on the map (Print.lua's
    -- Deaths); the line still says the death's own leg and time.
    local together = {}
    for _, list in ipairs({ notes.wipes or {}, notes.near or {} }) do
        for _, w in ipairs(list) do
            for _, d in ipairs(w.deaths or {}) do together[d] = w end
        end
    end
    local function Line(kind, time, leg, who)
        local x, y, how, info = nil, nil, nil, nil
        if path then x, y, how, info = Page.LegPoint(path, leg.death and together[leg.death] or leg) end
        if leg.death and together[leg.death] then how = tostring(how) .. ", with its wipe" end
        local to = leg.before and leg.before.name or (leg.open and "the next boss standing") or "?"
        local where = "nowhere"
        if x then
            local yd, off = ns.DungeonPace.Project(course, fit.ToGame(x, y))
            where = ("%.0f yd along (%.0f off), floor %.3f, %.3f"):format(yd or -1, off or -1, x, y)
        end
        Say("  %s %s%s: %s -> %s, %s into the leg (of %s): %s at %s", Clock((time or 0) - (visit.startedAt or 0)),
            kind, who and (" " .. who) or "", leg.after and leg.after.name or "the way in", to, Clock(leg.dt),
            leg.known and Clock(leg.known) or "-", tostring(how), where)
        if info and info.anchor then
            Say("      placed on from the sure place at %.0f yd (%s %s into the leg), %s taken off",
                info.anchor.yd, info.anchor.wipe and "a wipe" or "a death", Clock(info.anchor.dt), Clock(info.shift))
        end
    end
    for _, l in ipairs(notes.legs or {}) do
        Line("death", l.death.time, l, Who(visit, l.death.guid))
        Say("      killed by %s", Killer(l.death))
    end
    for _, w in ipairs(notes.wipes or {}) do Line("wipe", w.deaths[1] and w.deaths[1].time, w) end
    for _, w in ipairs(notes.near or {}) do Line("near wipe", w.deaths[1] and w.deaths[1].time, w) end
    for _, b in ipairs(notes.bosses or {}) do
        if b.killed then Say("  %s killed %s", b.boss.name, Clock((b.at or 0) - (visit.startedAt or 0))) end
    end
    if #(notes.legs or {}) == 0 then Say("  no deaths on the way") end
    -- The deaths at bosses too: what the run says killed them.
    for _, b in ipairs(notes.bosses or {}) do
        for _, d in ipairs(b.deaths or {}) do
            Say("  %s death %s at %s: killed by %s", Clock((d.time or 0) - (visit.startedAt or 0)), Who(visit, d.guid),
                b.boss.name, Killer(d))
        end
    end
    ReportProbe(visit)
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
    elseif rest == "clear" then
        if type(SocialDiaryCharDB) == "table" then SocialDiaryCharDB.paceProbe = nil end
        Say("pace: the kill probe's counts forgotten")
    elseif rest == "here" then
        Here()
    elseif gx then
        local visit = TheRun()
        if not visit then return Say("pace: no run in a dungeon with pace data") end
        Where(visit, tonumber(gx), tonumber(gy), "there")
    else
        Report()
    end
end, "how the route model placed a run's moments: |cffffd100/sd pace [here | at X Y | map | clear]|r", { dev = true })
