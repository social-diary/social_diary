-- Witnesses' capture (Kind.lua): who stood by while the user died, who
-- waded in, and who pulled them through a fight they only just survived.
--
-- Three rows on the other player (Interactions.Add, Kind.lua's kinds), for
-- strangers on the user's side only:
--
--   watched_death  had the user, or one of their foes, targeted in the
--                  last moments before they died, out of combat
--                  themselves, and never fought one of the user's foes.
--                  Not whoever merely ran past: they were looking.
--                  context.watched is for how long, unbroken, up to the
--                  death (Kind.lua's WATCHING says what the line makes of
--                  it), and context.subZone where.
--   tried_to_help  fought one of the user's foes in the fight the user
--                  died in, or finished one off.
--   saved_you      fought one of the user's foes, or finished one off, in
--                  a fight the user survived with SAVED of their health or
--                  less, judged as close calls are (Features/CloseCalls/
--                  Capture.lua):
--                  the damage meter's damage taken, less the healing it
--                  lists, against the maximum health, so reckoned from full
--                  health. context.pct is what was left.
--
-- The combat log is closed to addons since 12.0, so nobody's damage or
-- heals can be read, and Recent Allies records no open-world fights in this
-- build (checked in the client, 14 Oct). What is left is what a nameplate
-- says: a nearby player's target, and whether they are in combat. "Fought
-- one of the user's foes" is: had it targeted at some point in the fight,
-- and was in combat at some point in it. The two are noted apart, as the
-- plates are read once a second and a late helper can target a weak foe,
-- hit it and see it die in between. A foe is a creature that had the user
-- targeted at some point, off its plate or the user's target's target. (A
-- foe turning on a helper would be surer, but the user holds its attention
-- nearly always.) It can also be someone fighting their own one of the
-- same pack, so the line says "tried to". In combat with the user targeted
-- is neither: a healer looks just like that.
--
-- Group members are left out: their fights with the user are the
-- session's (Core/Sessions.lua), and the group's healers would look on.
--
-- When it runs: this file is listed in the TOC after Capture/, where its
-- old file (Capture/Witnesses.lua) was, not in the features' block, so on
-- every client event it shares with Capture/ its handlers still run last,
-- as before the move. It reads the same units as Capture/Nearby.lua
-- (NAME_PLATE_UNIT_ADDED, PLAYER_TARGET_CHANGED): a look it reads in a
-- fight puts what the unit shows on the character's record
-- (Characters.ObserveUnit), and Nearby's reunion toast, run first, has
-- taken its snapshot of a diary entry (their name) before that, as it
-- always did (tests/witnesses.lua, "after the reunion toast").
-- PLAYER_DEAD after Deaths' and the route's count (Capture/Journey.lua),
-- PARTY_KILL after World PvP's, Together's and Combat's, and the fight's
-- start and end after the route's and the close-call judge's, likewise
-- (the judge in the features' block since 15 Oct, still before this).
-- The judge (Features/CloseCalls/Capture.lua) tells a fight the user survived as
-- SD_FIGHT_SURVIVED (Core/Events.lua's header) where it called
-- Witnesses.Survived before the move; dispatch is synchronous, so the
-- rescue's rows are written at the same point (inside the dispatcher's
-- pcall now, so an error here no longer unwinds the judge: its close call
-- is still kept).

local addonName, ns = ...

local Witnesses = ns.Witnesses

local WATCHED, HELPED, SAVED_ROW = Witnesses.WATCHED, Witnesses.HELPED, Witnesses.SAVED

-- Out of a fight alive with this much of the health or less, as close
-- calls reckon it (ns.CloseCalls.LEFT is the stricter 10%).
local SAVED = 0.20

-- Seconds. watch: how long before the death a look still counts. scan: how
-- often the plates are read in a fight (combat starts and stops without a
-- target changing). fight: a fight ended this long before the death is
-- still the one died in (the client can leave combat a moment before
-- PLAYER_DEAD). match: how far apart the close-call judge's start and this
-- file's may be. kill: how long PARTY_KILL may trail a foe's death.
local WAIT = { watch = 10, scan = 1, fight = 5, match = 2, kill = 0.5 }

-- How long an onlooker watched, and what breaks a look (`gap`): Kind.lua's
-- WATCHING, which the words read too.
local WATCHING = Witnesses.WATCHING

-- A clock to the fraction of a second, for how long someone looked: the
-- server's is in whole seconds.
local function Clock()
    return GetTime and GetTime() or ns.Now()
end

-- The fights, newest last, the last few kept for the close-call judge,
-- which reads a moment after the fight: { started, ended, foes = { [guid]
-- = true }, on = { [guid] = time last seen with the user targeted },
-- looked = { [guid] = the same, out of combat }, aimed = { [guid] = {
-- [creature guid] = time last seen with it targeted } }, eyed = the same
-- out of combat, fought = { [guid] = true }, rescuers = { [guid] = true },
-- streak = { [guid] = { from, last, broken } on Clock(): the latest
-- unbroken look at the user or a foe }, names = { [guid] = name } for /sd debug }.
local fights = {}
local KEEP = 3
local ticker

local function Current()
    local f = fights[#fights]
    return f and not f.ended and f or nil
end

--------------------------------------------------------------------------
-- Reading the plates
--------------------------------------------------------------------------

local LOOKERS = { "target", "focus", "mouseover" }
local LOOKER = { target = true, focus = true, mouseover = true }

local function Looker(unit)
    return type(unit) == "string" and (LOOKER[unit] or unit:match("^nameplate%d+$") ~= nil)
end

local function Flag(fn, unit)
    return ns.Plain(fn(unit)) == true
end

local function Hostile(unit)
    return ns.Plain(UnitCanAttack("player", unit)) == true
end

local function NewFight(now)
    return { started = now, foes = {}, on = {}, looked = {}, aimed = {}, eyed = {}, fought = {}, rescuers = {},
        streak = {}, names = {} }
end

--------------------------------------------------------------------------
-- /sd debug: a trace, kept in the saved diary as well (witnessTrace, the
-- newest TRACE lines) so a test in the client can be read afterwards.
--------------------------------------------------------------------------

local TRACE = 600

local function Keep(line)
    local log = ns.db.witnessTrace
    if type(log) ~= "table" then
        log = {}
        ns.db.witnessTrace = log
    end
    log[#log + 1] = date("%H:%M:%S", ns.Now()) .. " " .. line
    while #log > TRACE do table.remove(log, 1) end
end

-- To the chat and the saved trace; `quiet` the trace only.
local function Trace(quiet, msg, ...)
    if not ns.DebugOn() then return end
    if select("#", ...) > 0 then msg = msg:format(...) end
    if not quiet then ns.Debug("witnesses: %s", msg) end
    Keep(msg)
end

-- What a creature's GUID is called, as last read off `unit`, with the end
-- of the GUID: one Kobold Vermin among many is told apart by it. Players go
-- by their names.
local function Named(f, guid, unit)
    if ns.DebugOn() and type(guid) == "string" and not f.names[guid] and not ns.SafeGUID(guid) then
        local name = ns.Plain((UnitName(unit)))
        f.names[guid] = (type(name) == "string" and name or "?") .. " ~" .. guid:sub(-5)
    end
end

local function Label(f, guid)
    if not guid then return "nobody" end
    return f.names[guid] or ns.Characters.FullName(guid) or guid
end

-- A creature that can attack the user and has them targeted is a foe.
local function Creature(f, unit, target)
    local guid = ns.Plain(UnitGUID(unit))
    if target ~= ns.ownGUID or f.foes[guid] or not ns.NpcID(guid) or not Hostile(unit) then return end
    Named(f, guid, unit)
    Trace(false, "%s is on you", Label(f, guid))
    f.foes[guid] = true
end

-- What `unit` is doing in fight `f`: a foe's target, or a stranger's look
-- or fight.
local function Read(f, unit)
    if not ns.Plain(UnitExists(unit)) then return end
    local target = ns.Plain(UnitGUID(unit .. "target"))
    local guid = ns.PlayerGUIDFromUnit(unit)
    if not guid then return Creature(f, unit, target) end
    if ns.Roster.Has(guid) or Hostile(unit) then return end
    if Flag(UnitIsDeadOrGhost, unit) or Flag(UnitIsAFK, unit) then return end

    local fighting = Flag(UnitAffectingCombat, unit)
    -- How long they have been looking on, unbroken. A broken look is kept,
    -- for as long as it ran, until the next one begins.
    local streak = f.streak[guid]
    if not fighting and (target == ns.ownGUID or f.foes[target]) then
        local now = Clock()
        if not streak or streak.broken or now - streak.last > WATCHING.gap then
            streak = { from = now }
            f.streak[guid] = streak
        end
        streak.last = now
    elseif streak then
        streak.broken = true
    end
    if fighting and not f.fought[guid] then
        ns.Characters.ObserveUnit(unit)
        Trace(false, "%s is in combat", Label(f, guid))
        f.fought[guid] = true
    end
    if target == ns.ownGUID then
        f.on[guid] = ns.Now()
        if not fighting then
            if not f.looked[guid] then
                ns.Characters.ObserveUnit(unit)
                Trace(false, "%s has you targeted", Label(f, guid))
            end
            f.looked[guid] = ns.Now()
        end
    elseif ns.NpcID(target) then
        f.aimed[guid] = f.aimed[guid] or {}
        if not f.aimed[guid][target] then
            ns.Characters.ObserveUnit(unit)
            Named(f, target, unit .. "target")
            Trace(false, "%s has %s targeted", Label(f, guid), Label(f, target))
        end
        f.aimed[guid][target] = ns.Now()
        if not fighting then
            f.eyed[guid] = f.eyed[guid] or {}
            f.eyed[guid][target] = ns.Now()
        end
    end
end

-- The creature the user has targeted, if one that can attack them:
-- { npcID, name, rank }, for the line to name it. Nil otherwise.
local function Foe()
    if not ns.Plain(UnitExists("target")) or not Hostile("target") then return nil end
    local npcID = ns.NpcID(UnitGUID("target"))
    local name = ns.Plain((UnitName("target")))
    if not npcID or type(name) ~= "string" then return nil end
    local rank = UnitClassification and ns.Plain(UnitClassification("target"))
    return { npcID = npcID, name = name, rank = rank ~= "normal" and rank or nil }
end

-- The user's target, when a foe, is the one the line names: the target is
-- gone by the time PLAYER_DEAD fires (probe, 14 Oct), so it is kept as the
-- fight goes. Being the target does not make a foe: a creature clicked or
-- tabbed to is not fighting the user (seen in the client, 14 Oct).
local function Mine(f)
    Read(f, "target")
    if f.foes[ns.Plain(UnitGUID("target"))] then f.foe = Foe() or f.foe end
end

local function ReadAll(f)
    for _, unit in ipairs(LOOKERS) do Read(f, unit) end
    for _, unit in ipairs(ns.Units.Plates) do Read(f, unit) end
    Mine(f)
end

-- Who fought one of the user's foes in `f`: had it targeted, and was in
-- combat, each at some point in the fight; or finished one off.
local function Helpers(f)
    local helpers = {}
    for guid in pairs(f.rescuers) do helpers[guid] = true end
    for guid, targets in pairs(f.aimed) do
        if f.fought[guid] then
            for target in pairs(targets) do
                if f.foes[target] then
                    helpers[guid] = true
                    break
                end
            end
        end
    end
    return helpers
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- For /sd debug: how a fight was judged, "3 foe(s); helped: Bram; in
-- combat, not with your foes: Numa".
local function Judged(f, helpers, what)
    if not ns.DebugOn() then return end
    local foes, helped, other = {}, {}, {}
    for guid in pairs(f.foes) do foes[#foes + 1] = Label(f, guid) end
    for guid in pairs(helpers) do helped[#helped + 1] = Label(f, guid) end
    for guid in pairs(f.fought) do
        if not helpers[guid] then other[#other + 1] = Label(f, guid) end
    end
    Trace(false, "%s; foes: %s; helped: %s; in combat, not with your foes: %s", what,
        #foes > 0 and table.concat(foes, ", ") or "none",
        #helped > 0 and table.concat(helped, ", ") or "nobody", #other > 0 and table.concat(other, ", ") or "nobody")
end

-- `extra` adds to the shared `context`, for this row only.
local function Write(guid, kind, time, where, context, extra)
    local copy = {}
    for key, value in pairs(context) do copy[key] = value end
    for key, value in pairs(extra or {}) do copy[key] = value end
    local row = ns.Interactions.Add(guid, kind, { time = time, where = where, context = copy })
    Trace(false, "%s %s%s", kind, ns.Characters.FullName(guid) or guid,
        copy.watched and (" (%.1f s)"):format(copy.watched) or "")
    return row
end

-- For the trace: every player the client can point at, and what they are
-- doing, whether or not it counts for anything. Why someone was missed.
local function Snapshot(f, why)
    if not ns.DebugOn() then return end
    local plates, players = 0, 0
    for _, unit in ipairs(ns.Units.Plates) do
        if ns.Plain(UnitExists(unit)) then
            plates = plates + 1
            if ns.PlayerGUIDFromUnit(unit) then players = players + 1 end
        end
    end
    Trace(true, "%s: %d plate(s), %d of players", why, plates, players)
    local seen = {}
    local function One(unit)
        local guid = ns.PlayerGUIDFromUnit(unit)
        if not guid or seen[guid] then return end
        seen[guid] = true
        ns.Characters.ObserveUnit(unit)
        local target = ns.Plain(UnitGUID(unit .. "target"))
        Named(f, target, unit .. "target")
        Trace(true, "  %s [%s]: target %s%s, combat %s%s%s%s%s", Label(f, guid), unit,
            target == ns.ownGUID and "YOU" or Label(f, target), f.foes[target] and " (your foe)" or "",
            tostring(ns.Plain(UnitAffectingCombat(unit))),
            Flag(UnitIsAFK, unit) and ", AFK" or "", Flag(UnitIsDeadOrGhost, unit) and ", dead" or "",
            Hostile(unit) and ", hostile" or "", ns.Roster.Has(guid) and ", group" or "")
    end
    for _, unit in ipairs(LOOKERS) do One(unit) end
    for _, unit in ipairs(ns.Units.Plates) do One(unit) end
end

-- Who was looking, out of combat, in the last WAIT.watch seconds before
-- `now`: at the user, or at one of their foes.
local function Onlookers(f, now)
    local list = {}
    for guid, seen in pairs(f.looked) do
        if now - seen <= WAIT.watch then list[guid] = true end
    end
    for guid, creatures in pairs(f.eyed) do
        for creature, seen in pairs(creatures) do
            if f.foes[creature] and now - seen <= WAIT.watch then list[guid] = true end
        end
    end
    return list
end

local function Died()
    if ns.InBattleground() then return end
    local now = ns.Now()
    local f = fights[#fights]
    if not f or (f.ended and now - f.ended > WAIT.fight) then
        -- Not in a fight (a fall): only who looked on.
        f = NewFight(now)
    end
    -- Where everyone's eyes are as the user falls.
    ReadAll(f)
    Snapshot(f, "you died")

    local where, context = ns.Where(), f.foe or {}
    local helpers = Helpers(f)
    Judged(f, helpers, "you died")
    for guid in pairs(helpers) do Write(guid, HELPED, now, where, context) end
    for guid in pairs(Onlookers(f, now)) do
        if not helpers[guid] then
            -- One looking on through to the death was read by ReadAll just
            -- now; a look broken before it counts for as long as it ran.
            local streak = f.streak[guid]
            local watched = streak and math.floor((streak.last - streak.from) * 10 + 0.5) / 10 or 0
            Write(guid, WATCHED, now, where, context, { watched = watched, subZone = where.subZone })
        end
    end
end

-- The close-call judge's word (Features/CloseCalls/Capture.lua,
-- SD_FIGHT_SURVIVED, once the damage meter reads): a fight from `started`
-- to `ended` that did
-- `taken` damage, less the healing the meter lists, against `max` health;
-- `foe` the creature fought most ({ npcID, name, rank }, or nil).
function Witnesses.Survived(started, ended, taken, max, foe)
    if type(taken) ~= "number" or type(max) ~= "number" or max <= 0 then return end
    if taken / max < 1 - SAVED then return end
    local f
    for i = #fights, 1, -1 do
        if math.abs(fights[i].started - started) <= WAIT.match then
            f = fights[i]
            break
        end
    end
    if not f then
        Trace(false, "the close fight was not watched")
        return
    end
    local helpers = Helpers(f)
    Judged(f, helpers, ("you survived with %d%%"):format(math.max(0, 100 - math.floor(taken / max * 100 + 0.5))))
    local pct = math.max(1, math.min(math.floor(SAVED * 100), 100 - math.floor(taken / max * 100 + 0.5)))
    local context = { pct = pct, npcID = foe and foe.npcID, name = foe and foe.npcID and foe.name or nil,
        rank = foe and foe.npcID and foe.rank or nil }
    local where = ns.Where()
    for guid in pairs(helpers) do Write(guid, SAVED_ROW, ended, where, context) end
end

--------------------------------------------------------------------------
-- The fight
--------------------------------------------------------------------------

local function Scan()
    local f = Current()
    if f then ReadAll(f) end
end

-- No fight is watched in a battleground (ns.InBattleground): nobody there
-- looks on, and the user's deaths and close calls in one are kept nowhere.
ns.On("PLAYER_REGEN_DISABLED", function()
    if ns.InBattleground() then return end
    fights[#fights + 1] = NewFight(ns.Now())
    while #fights > KEEP do table.remove(fights, 1) end
    Trace(true, "fight begins")
    Scan()
    Snapshot(fights[#fights], "at the start")
    if not ticker then ticker = ns.Every(WAIT.scan, Scan) end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    local f = Current()
    if f then
        -- The last look: someone's target as the fight ends counts too.
        ReadAll(f)
        if not ns.Plain(UnitIsDeadOrGhost("player")) then Snapshot(f, "fight over") end
        f.ended = ns.Now()
    end
    if ticker then
        ticker.Cancel()
        ticker = nil
    end
end)

ns.On("PLAYER_TARGET_CHANGED", function()
    local f = Current()
    if f then Mine(f) end
end)

ns.On("UNIT_TARGET", function(_, unit)
    local f = Current()
    if f and Looker(unit) then Read(f, unit) end
end)

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
    local f = Current()
    if f then Read(f, unit) end
end)

ns.On("PLAYER_DEAD", Died)

ns.On("SD_FIGHT_SURVIVED", function(_, started, ended, taken, max, foe)
    Witnesses.Survived(started, ended, taken, max, foe)
end)

--------------------------------------------------------------------------
-- A foe finished off by someone else
--------------------------------------------------------------------------
--
-- A one-shot finisher shows neither signal above: they may cast through
-- the user (their target the user, the spell on the user's), and a foe
-- dead at once leaves them out of combat before the next reading (seen in
-- the client, 14 Oct). What shows is the foe dying with no PARTY_KILL,
-- which fires for every kill by the user, their pet or their group:
-- someone outside it killed it. The rescuer is whoever
-- had the user or that foe targeted in the moments before.

local ours = {}  -- [creature guid] = time of the PARTY_KILL

ns.On("PARTY_KILL", function(_, _, victim)
    victim = ns.Plain(victim)
    if type(victim) ~= "string" then return end
    local now = ns.Now()
    -- Only a foe's death reads it back, so the rest are let go.
    for guid, t in pairs(ours) do
        if now - t > 60 then ours[guid] = nil end
    end
    ours[victim] = now
end)

local function Finished(f, victim, at)
    local found = {}
    for guid, seen in pairs(f.on) do
        if at - seen <= WAIT.watch then found[guid] = true end
    end
    for guid, targets in pairs(f.aimed) do
        if targets[victim] and at - targets[victim] <= WAIT.watch then found[guid] = true end
    end
    local names = {}
    for guid in pairs(found) do
        f.rescuers[guid] = true
        names[#names + 1] = Label(f, guid)
    end
    Trace(false, "%s died, not by you: %s", Label(f, victim),
        #names > 0 and ("finished off by " .. table.concat(names, ", ")) or "nobody to thank")
end

ns.On("UNIT_DIED", function(_, guid)
    guid = ns.Plain(guid)
    local f = fights[#fights]
    if type(guid) ~= "string" or not f or not f.foes[guid] then return end
    if f.ended and ns.Now() - f.ended > WAIT.fight then return end
    local at = ns.Now()
    -- PARTY_KILL comes first in the client, but is not waited on blindly.
    ns.After(WAIT.kill, function()
        local kill = ours[guid]
        ours[guid] = nil
        if not (kill and math.abs(kill - at) <= WAIT.fight) then Finished(f, guid, at) end
    end)
end)

function ns._test.Witnesses()
    return fights[#fights]
end

ns._test.WitnessesScan = Scan
