-- Reading a fight once it can be read (Core/Meter.lua), and those who do:
-- the close-call judge's baseline, a death's recap waiting out the group's
-- fight, and a pull's end told twice.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Meter = ns.Meter
local SELF, STRANGER = F.SELF, F.STRANGER
local WOLF = "Creature-0-4615-1-832-2958-00004B6A01"

-- Sessions by id: { taken, deaths = { [guid] = recapID } }.
local meter = { sessions = {} }
_G.Enum.DamageMeterType = { HealingDone = 2, DamageTaken = 7, Deaths = 9 }
_G.Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
_G.C_DamageMeter = {
    GetAvailableCombatSessions = function()
        local list = {}
        for id in pairs(meter.sessions) do list[#list + 1] = { sessionID = id } end
        return list
    end,
    GetCombatSessionFromID = function(id, kind)
        local s = meter.sessions[id]
        if not s then return { combatSources = {} } end
        if kind == Enum.DamageMeterType.DamageTaken then
            return { combatSources = { { name = s.name, isLocalPlayer = true, totalAmount = s.taken } } }
        end
        if kind == Enum.DamageMeterType.Deaths then
            local rows = {}
            for guid, recapID in pairs(s.deaths or {}) do
                rows[#rows + 1] = { sourceGUID = guid, deathRecapID = recapID }
            end
            return { combatSources = rows }
        end
        return { combatSources = {} }
    end,
    GetCombatSessionSourceFromID = function() return { combatSpells = {} } end,
}

local function Settle()
    for _ = 1, 8 do mock.RunTimers() end
end

-- A fight in session `id`, `taken` more damage in it, the meter read after.
local function Fight(id, taken, opts)
    opts = opts or {}
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
    mock.now = mock.now + 40
    local s = meter.sessions[id] or { taken = 0 }
    meter.sessions[id] = s
    s.taken = s.taken + taken
    mock.inCombat = false
    if opts.dead then mock.dead = true end
    mock.fire("PLAYER_REGEN_ENABLED")
    if not opts.hold then Settle() end
end

mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
local j = ns.Journey.Mine()

--------------------------------------------------------------------------
Section("what keeps the meter from reading")

Eq(Meter.Busy(), nil, "nothing going on")
mock.inCombat = true
Eq(Meter.Busy(), "combat", "in combat")
mock.inCombat = false

_G.C_InstanceEncounter = { IsEncounterInProgress = function() return true end }
Eq(Meter.Busy(), "encounter", "in an encounter")
_G.C_InstanceEncounter = { IsEncounterInProgress = function() return mock.secret(true) end }
Eq(Meter.Busy(), nil, "a secret answer is no encounter")
_G.C_InstanceEncounter = nil

_G.Enum.AddOnRestrictionType = { Combat = 0 }
_G.C_RestrictedActions = { GetAddOnRestrictionState = function() return 2 end }
Eq(Meter.Busy(), "restricted", "the combat restriction")
_G.C_RestrictedActions = nil

meter.sessions[1] = { taken = 0, name = mock.secret("Someone") }
Eq(Meter.Busy(), "session", "the server holds the session")
meter.sessions[1] = nil

--------------------------------------------------------------------------
Section("waiting costs no tries while it is busy")

do
    local reads, gaveUp = 0, 0
    local function Read() reads = reads + 1 end
    mock.inCombat = true
    Meter.Wait(Read, { every = 1, tries = 2, deadline = 100, gaveUp = function() gaveUp = gaveUp + 1 end })
    Settle()
    Eq(reads, 0, "read while busy")
    Eq(gaveUp, 0, "gave up while busy, before the deadline")
    mock.inCombat = false
    Settle()
    Eq(reads, 2, "its tries, once it could read")
    Eq(gaveUp, 1, "told it never read")

    mock.inCombat = true
    Meter.Wait(Read, { every = 1, tries = 2, deadline = 100, gaveUp = function() gaveUp = gaveUp + 1 end })
    mock.now = mock.now + 101
    Settle()
    Eq(gaveUp, 2, "busy past the deadline")
    mock.inCombat = false
    Settle()
end

--------------------------------------------------------------------------
Section("close calls: every reading moves the baseline")

-- The user dies in a session that carries on: its damage is not the next
-- fight's.
Fight(10, 95, { dead = true })
mock.dead = false
Eq(#ns.CloseCalls.List(j), 0, "a death was a close call")
Eq(j.meter.taken.amount, 95, "the death's damage was not counted from")
Fight(10, 10)
Eq(#ns.CloseCalls.List(j), 0, "the fight after a death counted the death's damage")

-- A fight that never read, in a session that carries on: the next reading
-- holds both, so it judges nothing, and the one after is its own again.
meter.sessions[11] = { taken = 0 }
Fight(11, 60, { hold = true })
meter.sessions[11].name = mock.secret("Someone")
mock.RunTimers()
mock.now = mock.now + 400
Settle()
meter.sessions[11].name = nil
Fight(11, 50)
Eq(#ns.CloseCalls.List(j), 0, "two fights added together were a close call")
Eq(j.meter.taken.amount, 110, "the reading set no baseline")
Fight(11, 95)
Eq(#ns.CloseCalls.List(j), 1, "the fight after was not judged on its own")
Eq(ns.CloseCalls.List(j)[1].took, 95, "its own damage")
table.remove(j.closeCalls)

-- The meter busy past another fight's start: the session read is the
-- fight's own, not the newest.
Fight(12, 95, { hold = true })
mock.inCombat = true
mock.RunTimers()
meter.sessions[13] = { taken = 5 }
mock.inCombat = false
Settle()
Eq(#ns.CloseCalls.List(j), 1, "the fight was not read by its own session")
Eq(ns.CloseCalls.List(j)[1].took, 95, "another session's damage")
table.remove(j.closeCalls)

-- The meter reset, its ids starting over: nothing to count from.
Check(j.meter ~= nil, "setup: a baseline")
mock.fire("DAMAGE_METER_RESET")
Eq(j.meter, nil, "a reset kept the baseline")
meter.sessions = { [1] = { taken = 0 } }
Fight(1, 95)
Eq(#ns.CloseCalls.List(j), 1, "a fight after a reset lost to the old baseline")
table.remove(j.closeCalls)

--------------------------------------------------------------------------
Section("a death's recap waits out the group's fight")

local function Hit(guid, name, dest, at)
    return { sourceGUID = guid, sourceName = name, destGUID = dest, timestamp = at, spellName = "Bite" }
end

local recaps = {}
_G.C_DeathRecap = {
    HasRecapEvents = function(id) return recaps[id] ~= nil end,
    GetRecapEvents = function(id) return recaps[id or "latest"] end,
}

mock.inInstance, mock.instanceName, mock.instanceID = true, "The Hall of Thanes", 3065
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
local affecting = _G.UnitAffectingCombat
local fighting = true
_G.UnitAffectingCombat = function(unit) return unit == "party1" and fighting end

mock.dead = true
Eq(Meter.Busy(), "group", "dead, the group fighting on")
mock.fire("PLAYER_DEAD")
Eq(ns._test.DeathsPending(), 1, "setup: waiting for the recap")
for _ = 1, 15 do mock.RunTimers() end
Eq(ns._test.DeathsPending(), 1, "a long fight used up the death's tries")

fighting = false
local at = mock.now
meter.sessions[1].deaths = { [SELF.guid] = 7 }
recaps[7] = { Hit(WOLF, "Prairie Wolf", SELF.guid, at) }
mock.RunTimers()
Eq(ns._test.DeathsPending(), 0, "the recap was not read once the fight ended")
local slain = ns.Deaths.List(j)
Eq(slain[#slain].name, "Prairie Wolf", "the killer off the recap the meter lists")

-- A recap the meter lists that is not this death's: the latest is tried.
at = mock.now + 100
mock.now = at
recaps.latest = { Hit(WOLF, "Prairie Wolf", SELF.guid, at) }
recaps[7] = { Hit(WOLF, "Stale Wolf", SELF.guid, at - 1000) }
mock.fire("PLAYER_DEAD")
mock.RunTimers()
slain = ns.Deaths.List(j)
Eq(slain[#slain].name, "Prairie Wolf", "the latest recap was not tried")

-- The fight never ending: the death gives up at its deadline.
fighting = true
mock.fire("PLAYER_DEAD")
mock.now = mock.now + 11 * 60
mock.RunTimers()
Eq(ns._test.DeathsPending(), 0, "waited past the deadline")
fighting = false

_G.UnitAffectingCombat = affecting
mock.dead = false
mock.inInstance = false
mock.fire("ZONE_CHANGED_NEW_AREA")
_G.C_DeathRecap = nil

--------------------------------------------------------------------------
Section("a pull's start and end told twice")

mock.now = mock.now + 3600
mock.inInstance, mock.instanceName, mock.instanceID = true, "The Hall of Thanes", 3065
mock.fire("ZONE_CHANGED_NEW_AREA")
local visit = ns.Instances.Current()
Check(visit, "setup: a run")
local pulls = #visit.pulls
local function Half()
    local d = ns.Instances.Death(STRANGER.guid)
    Check(d, "setup: a death")
end

mock.fire("ENCOUNTER_START", 3493, "Faldrim Anvilmar", 1, 5)
Half()
ns.Instances.Death(SELF.guid)
mock.now = mock.now + 30
mock.fire("ENCOUNTER_END", 3493, "Faldrim Anvilmar", 1, 5, 0)
local wipes = visit.wipes
Check(wipes and wipes >= 1, "setup: a wipe")
mock.now = mock.now + 2
mock.fire("ENCOUNTER_END", 3493, "Faldrim Anvilmar", 1, 5, 0)
Eq(visit.wipes, wipes, "a wipe told twice was counted twice")
mock.fire("ENCOUNTER_START", 3493, "Faldrim Anvilmar", 1, 5)
Eq(#visit.pulls, pulls + 1, "a start told again was another try")

-- A real next try, and a kill right after a wipe, still count.
mock.now = mock.now + 20
mock.fire("ENCOUNTER_START", 3493, "Faldrim Anvilmar", 1, 5)
Eq(#visit.pulls, pulls + 2, "the next try was lost")
mock.now = mock.now + 30
mock.fire("ENCOUNTER_END", 3493, "Faldrim Anvilmar", 1, 5, 0)
mock.now = mock.now + 1
mock.fire("ENCOUNTER_END", 3493, "Faldrim Anvilmar", 1, 5, 1)
Eq(visit.pulls[#visit.pulls].killed, true, "a kill after a wipe was taken for a repeat")

-- Secret ends told twice leave one pull.
mock.now = mock.now + 60
mock.fire("ENCOUNTER_START", mock.secret(3495), mock.secret("Infurnus"), 1, 5)
local count = #visit.pulls
mock.now = mock.now + 30
mock.fire("ENCOUNTER_END", mock.secret(3495), mock.secret("Infurnus"), 1, 5, 0)
mock.fire("ENCOUNTER_END", mock.secret(3495), mock.secret("Infurnus"), 1, 5, 0)
Eq(#visit.pulls, count, "a secret end told twice made a pull")
