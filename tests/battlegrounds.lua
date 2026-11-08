-- Battlegrounds and arenas, until the diary has a shape for a match: the
-- open world's detections stand down inside one (ns.InBattleground). A
-- Warsong Gulch match was ten "You died to ..." lines in the session, each
-- death a lost fight with a stranger, and all of it on the Orgrimmar plate
-- (8 Nov). Out again, everything is written as before.
--
-- Close calls are tests/combat.lua's ("a close call"), where the meter is
-- mocked.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Pending = ns._test.DeathsPending

local SELF, HOSTILE, STRANGER = F.SELF, F.HOSTILE, F.STRANGER
local FOE = HOSTILE.guid

local recaps = {}
_G.C_DeathRecap = {
    GetRecapEvents = function(id) return recaps[id or "latest"] end,
}

-- The recap after combat names the killer by a plain GUID, as it did in the
-- match.
local function Blow(source, name, dest, at, spell)
    return { { sourceGUID = source, sourceName = name, destGUID = dest, timestamp = at,
        event = "SPELL_DAMAGE", spellName = spell, amount = 300, overkill = 12 } }
end

-- Deaths counted on the route's open stop, wherever Journey.Act put them.
local function RouteDeaths(j)
    local o = j.open or {}
    local into = o.dungeon or o.c or o.road
    return (into and into.act and into.act.deaths or 0) + (o.loose and o.loose.deaths or 0)
end

local function Enter(kind)
    mock.inInstance, mock.instanceType, mock.instanceName = true, kind, "Warsong Gulch"
    mock.zone = "Warsong Gulch"
end

local function Leave()
    mock.inInstance, mock.instanceType, mock.instanceName = false, "party", "The Deadmines"
    mock.zone = "Orgrimmar"
end

-- Killed by a player, the guess at the moment and the recap after.
local function Die(dest)
    mock.inCombat = true
    mock.SetUnit("target", HOSTILE)
    if dest == SELF.guid then mock.fire("PLAYER_DEAD") else mock.fire("UNIT_DIED", dest) end
    recaps.latest = Blow(FOE, "Romulus Lupa", dest, mock.now, "Shadow Bolt")
    mock.inCombat = false
    mock.SetUnit("target", nil)
    mock.fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 12 do mock.RunTimers() end
end

T.BlankDiary()
mock.now = 1794069000
mock.zone = "Orgrimmar"
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
local j = ns.Journey.Mine()
Check(j, "setup: no route")

-- Queued with a friend: a session open before the match.
ns.Diary.Add(STRANGER.guid, { source = "test" })
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
local s = ns.Sessions.Current()
Check(s, "setup: grouping with a diary entry did not open a session")

--------------------------------------------------------------------------
Section("the check itself")

Eq(ns.InBattleground(), false, "the open world read as a battleground")
for kind, want in pairs({ pvp = true, arena = true, party = false, raid = false, scenario = false }) do
    mock.inInstance, mock.instanceType = true, kind
    Eq(ns.InBattleground(), want, "a " .. kind .. " instance")
end
Leave()

--------------------------------------------------------------------------
Section("in a battleground: no deaths, fights or places written")

local deathsBefore = #ns.Deaths.List(j)
local actBefore = RouteDeaths(j)
local zonesBefore = #s.zones

for _, kind in ipairs({ "pvp", "arena" }) do
    Enter(kind)
    mock.fire("ZONE_CHANGED_NEW_AREA")
    mock.now = mock.now + 120
    Die(SELF.guid)
    mock.now = mock.now + 60
    Die(STRANGER.guid)

    Eq(Pending(), 0, "a death in a " .. kind .. " instance is waiting for its recap")
    Eq(s.deaths[SELF.guid], nil, "your death in a " .. kind .. " instance was the session's")
    Eq(s.deaths[STRANGER.guid], nil, "a friend's death in a " .. kind .. " instance was the session's")
    Eq(s.deathLog, nil, "the session logged a death in a " .. kind .. " instance")
    Eq(T.Rows(FOE, "pvp_death"), 0, "a death in a " .. kind .. " instance was a fight")
    Eq(ns.Interactions.Fights(FOE), nil, "the killer has a score from a " .. kind .. " instance")
    Eq(#ns.Deaths.List(j), deathsBefore, "a death in a " .. kind .. " instance went on the route")
    Eq(RouteDeaths(j), actBefore, "the route's stop counted a death in a " .. kind .. " instance")
    Eq(#s.zones, zonesBefore, "a " .. kind .. " instance was one of the session's places")
end

-- The fighting there is no fighting on the road either.
mock.fire("PLAYER_REGEN_DISABLED")
Eq(j.open and j.open.fight, nil, "a fight in a battleground opened on the route")
mock.fire("PLAYER_REGEN_ENABLED")

-- The session itself goes on: it is still the friend's.
Check(ns.Sessions.Current() == s, "the session ended in the battleground")

--------------------------------------------------------------------------
Section("out again: written as before")

Leave()
mock.fire("ZONE_CHANGED_NEW_AREA")
mock.now = mock.now + 600
Die(SELF.guid)
Eq(s.deaths[SELF.guid], 1, "your death after the match was not the session's")
Eq(T.Rows(FOE, "pvp_death"), 1, "a player killing you after the match was no fight")
Eq(#ns.Deaths.List(j), deathsBefore + 1, "your death after the match is not on the route")
Eq(RouteDeaths(j), actBefore + 1, "the route's stop did not count the death after the match")

mock.now = mock.now + 60
Die(STRANGER.guid)
Eq(s.deaths[STRANGER.guid], 1, "a friend's death after the match was not the session's")
