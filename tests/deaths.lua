-- Deaths in a together session and what killed them: the guess at the
-- moment, the death recap once combat is over, and what is kept when the
-- recap cannot be had.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Pending = ns._test.DeathsPending

local STRANGER, SELF = F.STRANGER, F.SELF
local GUID = STRANGER.guid

-- Three Plainstriders, as the probe saw them on 8 Oct: one GUID under two
-- names, and the killing blow first.
local THUNDERHOOF = "Creature-0-4615-1-72-2955-000046CD8A"
local LONGHOOF = "Creature-0-4615-1-72-2955-000046CDA6"
local THIRD = "Creature-0-4615-1-72-2955-0002C6CCD9"

local function Hit(source, name, dest, time, extra)
    local event = { sourceGUID = source, sourceName = name, destGUID = dest, timestamp = time,
        event = "SWING_DAMAGE", amount = 1 }
    for key, value in pairs(extra or {}) do event[key] = value end
    return event
end

local function Pack(dest, at)
    return {
        Hit(THUNDERHOOF, "Plainstrider Thunderhoof", dest, at + 0.4, { overkill = 1 }),
        Hit(LONGHOOF, "Plainstrider Longhoof", dest, at - 1.3),
        Hit(THIRD, "Plainstrider Thunderhoof", dest, at - 1.3),
        Hit(THUNDERHOOF, "Plainstrider Wrathlete", dest, at - 1.6),
    }
end

-- recaps: id (or "latest") -> events.
local recaps = {}
_G.C_DeathRecap = {
    GetRecapEvents = function(id) return recaps[id or "latest"] end,
}

local function Mob(guid, name)
    return { guid = guid, name = { name }, isPlayer = false, hostile = true }
end

local function Describe(item, guid)
    local _, text = ns.UI.DescribeItem(item, guid)
    return text
end

-- The death lines on a profile, oldest first.
local function DeathLines(guid)
    local lines = {}
    for _, top in ipairs(ns.Timeline.For(guid)) do
        for _, child in ipairs(top.all or {}) do
            if child.kind == "death" then lines[#lines + 1] = Describe(child, guid) end
        end
    end
    return lines
end

--------------------------------------------------------------------------
Section("a death outside a session")

-- The user's own death waits for its recap even alone: a player may have
-- killed them (tests/pvp.lua). With no recap, it gives up and keeps nothing.
mock.now = 1791413816
mock.fire("PLAYER_DEAD")
Eq(Pending(), 1, "the user's death outside a session is not waiting for a recap")
for _ = 1, 12 do mock.RunTimers() end
Eq(Pending(), 0, "a death without a recap waited past its tries")
Eq(next(ns.db.interactions), nil, "a death to nobody was written down")

--------------------------------------------------------------------------
Section("the user's death: guess, then the recap")

ns.Diary.Add(GUID, { source = "test" })
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
local s = ns.Sessions.Current()
Check(s, "grouping with a diary entry did not open a session")

mock.subZone = "Red Cloud Mesa"
mock.SetUnit("target", Mob(THUNDERHOOF, "Plainstrider"))
mock.inCombat = true
mock.fire("PLAYER_DEAD")

Eq(s.deaths[SELF.guid], 1, "the death was not counted")
local death = s.deathLog and s.deathLog[1]
Check(death, "the death has no record")
Eq(death.guid, SELF.guid, "whose death")
Eq(death.subZone, "Red Cloud Mesa", "where")
Eq(death.killer and death.killer.source, "target", "the guess at the moment of death")
Eq(death.killer.name, "Plainstrider", "the guessed killer's name")
Eq(death.killer.npcID, 2955, "the guessed killer's NPC id")
Eq(Pending(), 1, "the death is not waiting for its recap")

-- Still in combat: nothing is read, however often the timer comes round.
recaps.latest = Pack(SELF.guid, mock.now)
mock.RunTimers()
Eq(death.killer.source, "target", "the recap was read in combat")
Eq(Pending(), 1, "a death stopped waiting during combat")

mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(death.killer.source, "recap", "the recap was not read after combat")
Eq(death.killer.name, "Plainstrider", "the nameplate's name lost to the recap's")
Eq(death.killer.npcID, 2955, "the recap's NPC id")
Eq(death.killer.attackers, 3, "everyone who hit")
Eq(Pending(), 0, "a resolved death is still waiting")

Eq(DeathLines(GUID)[1], "You died to Plainstrider (3 attackers) near Red Cloud Mesa",
    "the user's death on their profile")

--------------------------------------------------------------------------
Section("the recap's own name, with no target")

mock.SetUnit("target", nil)
mock.now = mock.now + 60
recaps.latest = Pack(SELF.guid, mock.now)
mock.fire("PLAYER_DEAD")
death = s.deathLog[2]
Eq(death.killer, nil, "a guess with nothing targeted")
mock.RunTimers()
Eq(death.killer and death.killer.name, "Plainstrider",
    "the words the killer's recap names share are not its name")

--------------------------------------------------------------------------
Section("fallbacks: a stale, secret or missing recap")

-- A recap from an earlier death is not this one's.
mock.SetUnit("target", Mob(LONGHOOF, "Plainstrider"))
mock.now = mock.now + 300
mock.fire("PLAYER_DEAD")
death = s.deathLog[3]
for _ = 1, 12 do mock.RunTimers() end
Eq(death.killer.source, "target", "a stale recap replaced the guess")
Eq(Pending(), 0, "a death kept waiting past its tries")
Eq(DeathLines(GUID)[3], "You died, probably to Plainstrider near Red Cloud Mesa", "a guessed death's line")

-- A secret recap is skipped without touching it.
mock.now = mock.now + 300
recaps.latest = mock.secret(Pack(SELF.guid, mock.now))
mock.fire("PLAYER_DEAD")
death = s.deathLog[4]
for _ = 1, 12 do mock.RunTimers() end
Eq(death.killer.source, "target", "a secret recap replaced the guess")

-- No recap API at all, and nothing targeted: a death with no killer.
local api = _G.C_DeathRecap
_G.C_DeathRecap = nil
mock.SetUnit("target", nil)
mock.subZone = ""
mock.now = mock.now + 300
mock.fire("PLAYER_DEAD")
death = s.deathLog[5]
for _ = 1, 12 do mock.RunTimers() end
Eq(death.killer, nil, "a killer out of nowhere")
Eq(DeathLines(GUID)[5], "You died near Mulgore", "a death with no killer")
_G.C_DeathRecap = api

-- A target that cannot attack is not a suspect.
mock.SetUnit("target", { guid = "Creature-0-4615-1-72-3078-000046C000", name = { "Kodo Calf" },
    isPlayer = false, hostile = false })
mock.now = mock.now + 300
mock.fire("PLAYER_DEAD")
Eq(s.deathLog[6].killer, nil, "a friendly target taken for the killer")
for _ = 1, 12 do mock.RunTimers() end
mock.SetUnit("target", nil)

--------------------------------------------------------------------------
Section("a group member's death")

mock.SetUnit("party1target", Mob(LONGHOOF, "Plainstrider"))
mock.now = mock.now + 300
mock.inCombat = true
mock.fire("UNIT_DIED", GUID)
death = s.deathLog[7]
Eq(death.guid, GUID, "whose death")
Eq(death.killer and death.killer.source, "target", "their target as the guess")

-- The meter lists their death with a recap ID; that recap is theirs.
_G.Enum.DamageMeterType = { Deaths = 9 }
_G.C_DamageMeter = {
    GetAvailableCombatSessions = function() return { { sessionID = 4 } } end,
    GetCombatSessionFromID = function(id, kind)
        if id ~= 4 or kind ~= 9 then return nil end
        return { combatSources = { { sourceGUID = GUID, deathRecapID = 7 },
            { sourceGUID = SELF.guid, deathRecapID = 2 } } }
    end,
}
recaps[7] = { Hit("Player-4618-00000BAD", "Romulus Lupa", GUID, mock.now, { spellName = "Wrath" }) }
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(death.killer.source, "recap", "their recap was not read")
Check(death.killer.player, "a player killer not marked as one")
Eq(death.killer.guid, "Player-4618-00000BAD", "the player killer's GUID")
Eq(death.killer.spell, "Wrath", "the killing spell")
Eq(DeathLines(GUID)[7], "Bram died to Romulus Lupa's Wrath near Mulgore", "their death on their profile")

-- Not a participant: no death, nothing waiting.
mock.fire("UNIT_DIED", F.PUG.guid)
Eq(#s.deathLog, 7, "a non-participant's death recorded")
Eq(Pending(), 0, "a non-participant's death is waiting")

--------------------------------------------------------------------------
Section("the details line and forgetting")

-- Seven deaths, all with lines: the details line does not count them again.
local session
for _, top in ipairs(ns.Timeline.For(GUID)) do
    if top.kind == "session" then session = top end
end
local _, _, sub = ns.UI.DescribeItem(session, GUID)
Check(not (sub or ""):find("death"), "deaths with lines counted again on the details line: " .. tostring(sub))

-- An older session only has the count, and keeps it.
local old = ns.Sessions.New({ startedAt = mock.now - 3 * T.DAY, endedAt = mock.now - 3 * T.DAY + 600,
    source = "group", participants = { [GUID] = { since = mock.now - 3 * T.DAY, last = mock.now - 3 * T.DAY + 600,
        seconds = 600 } }, deaths = { [GUID] = 2 } })
for _, top in ipairs(ns.Timeline.For(GUID)) do
    if top.session == old then
        _, _, sub = ns.UI.DescribeItem(top, GUID)
        Check((sub or ""):find("2 deaths"), "an older session lost its death count: " .. tostring(sub))
    end
end

-- PRV-3: forgetting the player who killed them keeps the death, nameless;
-- forgetting them drops their deaths.
ns.Sessions.Forget("Player-4618-00000BAD")
Eq(s.deathLog[7].killer, nil, "a forgotten killer kept")
ns.Sessions.Forget(GUID)
for _, d in ipairs(s.deathLog) do Check(d.guid ~= GUID, "a forgotten character's death kept") end

--------------------------------------------------------------------------
Section("the user's deaths on their route, with what killed them")

local route = ns.Deaths.List(ns.Journey.Mine())
Check(#route > 0, "the user's deaths above left nothing on their route")
local function Latest() return route[#route] end
local KOBOLD = "Creature-0-4615-1-72-6-0000AAAA01"
mock.inCombat = false

-- The guessed killer, and the recap agrees: its display is looked up once.
mock.creatureDisplays[2955] = 1961
mock.SetUnit("target", { guid = THUNDERHOOF, name = { "Plainstrider" }, isPlayer = false, hostile = true })
mock.now = mock.now + 300
local before = #route
mock.fire("PLAYER_DEAD")
Eq(#route, before + 1, "the death did not go on the route")
local d = Latest()
Eq(d.t, mock.now, "when")
Eq(d.mapID, mock.mapID, "where: the zone map")
Eq(d.npcID, 2955, "the guessed creature")
Check(d.probable, "a guess not marked as one")
recaps.latest = Pack(SELF.guid, mock.now)
for _ = 1, 4 do mock.RunTimers() end
Eq(d.probable, nil, "the recap did not confirm the guess")
Eq(d.name, "Plainstrider", "the killer's name")
Eq(d.display, 1961, "the recap lost the display of the same creature")

-- Nothing targeted: the recap names a creature, and its display is looked
-- up by NPC id once the model frame has loaded it.
mock.SetUnit("target", nil)
mock.creatureDisplays[6] = 127670
mock.now = mock.now + 300
recaps.latest = { Hit(KOBOLD, "Kobold Vermin", SELF.guid, mock.now, { spellName = "Rend" }) }
mock.fire("PLAYER_DEAD")
d = Latest()
Eq(d.npcID, nil, "a killer with nothing targeted")
mock.RunTimers()
Eq(d.npcID, 6, "the recap's creature")
Eq(d.name, "Kobold Vermin", "the recap's name")
Eq(d.spell, "Rend", "the killing spell")
Eq(d.display, nil, "a display before the model frame loaded it")
for _ = 1, 3 do mock.RunTimers() end
Eq(d.display, 127670, "the creature's display was not looked up")

-- A creature the cache does not know: tried a while, then left without.
mock.now = mock.now + 300
recaps.latest = { Hit("Creature-0-4615-1-72-99-0000AAAA02", "Mystery", SELF.guid, mock.now) }
local looked = mock.models or 0
mock.fire("PLAYER_DEAD")
for _ = 1, 10 do mock.RunTimers() end
d = Latest()
Eq(d.npcID, 99, "the uncached creature")
Eq(d.display, nil, "a display out of nowhere")
Eq(mock.models - looked, 1, "the creature was set on the model more than once")

-- The world killed them: no creature, the kind of death kept.
mock.now = mock.now + 300
recaps.latest = { Hit(nil, nil, SELF.guid, mock.now, { environmentalType = "Falling" }) }
mock.fire("PLAYER_DEAD")
mock.RunTimers()
d = Latest()
Eq(d.environment, "Falling", "a fall")
Eq(d.npcID, nil, "a creature for a fall")

-- A player killed them: a fight (tests/pvp.lua), and the death keeps no
-- killer here.
mock.SetUnit("target", { guid = KOBOLD, name = { "Kobold Vermin" }, isPlayer = false, hostile = true })
mock.now = mock.now + 300
recaps.latest = { Hit("Player-4618-00000BAD", "Romulus Lupa", SELF.guid, mock.now, { spellName = "Wrath" }) }
mock.fire("PLAYER_DEAD")
Eq(Latest().npcID, 6, "the guess")
mock.RunTimers()
d = Latest()
Eq(d.npcID, nil, "a creature kept for a player's kill")
Eq(d.name, nil, "a player named on the route's death")
Eq(d.probable, nil, "a player's kill still a guess")
mock.SetUnit("target", nil)

-- Route off: nothing goes on it.
ns.db.settings.keepRoute = false
before = #route
mock.now = mock.now + 300
mock.fire("PLAYER_DEAD")
for _ = 1, 12 do mock.RunTimers() end
Eq(#route, before, "a death kept with the route off")
ns.db.settings.keepRoute = true

--------------------------------------------------------------------------
Section("the killer's rank")

-- An elite on a nameplate, the recap naming it after combat: its rank,
-- read at the moment of death, goes with it. A common one has none.
local HOGGER = "Creature-0-4615-1-72-448-0000AAAA03"
mock.SetUnit("nameplate3", { guid = HOGGER, name = { "Hogger" }, isPlayer = false, hostile = true,
    classification = "elite" })
mock.SetUnit("nameplate4", { guid = KOBOLD, name = { "Kobold Vermin" }, isPlayer = false, hostile = true,
    classification = "normal" })
mock.now = mock.now + 300
recaps.latest = { Hit(HOGGER, "Hogger", SELF.guid, mock.now) }
mock.fire("PLAYER_DEAD")
mock.SetUnit("nameplate3", nil)
mock.RunTimers()
d = Latest()
Eq(d.npcID, 448, "the recap's elite")
Eq(d.rank, "elite", "the elite's rank was not kept")

mock.now = mock.now + 300
recaps.latest = { Hit(KOBOLD, "Kobold Vermin", SELF.guid, mock.now) }
mock.fire("PLAYER_DEAD")
mock.RunTimers()
Eq(Latest().npcID, 6, "the common creature")
Eq(Latest().rank, nil, "a common creature given a rank")
mock.SetUnit("nameplate4", nil)

--------------------------------------------------------------------------
Section("a recap's surname, put right by the name read off a unit")

-- The recap may name a mob once, with a made-up surname ("Murloc Forager
-- Olwynne", 11 Oct): with one name there is no surname to find in common.
-- The name a fight read off a unit puts it right, for this death and for
-- one kept before it was read.
local J = ns.Journey
local j = J.Mine()
local MURLOC = "Creature-0-4615-1-72-46-0000AAAA04"
local SPIDER = "Creature-0-4615-1-72-30-0000AAAA05"
local BEAR = "Creature-0-4615-1-72-822-0000AAAA06"
mock.SetUnit("target", nil)
ns.CreatureNames.Note(46, "Murloc Forager", mock.now)
mock.now = mock.now + 300
recaps.latest = { Hit(MURLOC, "Murloc Forager Olwynne", SELF.guid, mock.now) }
mock.fire("PLAYER_DEAD")
mock.RunTimers()
Eq(Latest().npcID, 46, "setup: the recap's creature")
Eq(Latest().name, "Murloc Forager", "the recap's surname kept, the creature's name known")

-- Kept before its name was known, then read off a nameplate: put right.
mock.now = mock.now + 300
recaps.latest = { Hit(SPIDER, "Forest Spider Grimm", SELF.guid, mock.now) }
mock.fire("PLAYER_DEAD")
mock.RunTimers()
local spider = Latest()
Eq(spider.name, "Forest Spider Grimm", "setup: a surname with no name known")
ns.CreatureNames.Note(30, "Forest Spider", mock.now)
Eq(spider.name, "Forest Spider", "a death kept with a surname was not put right when the name was read")

-- A name of three words with none known is left as it is: nothing is
-- guessed off it.
mock.now = mock.now + 300
recaps.latest = { Hit(BEAR, "Young Forest Bear", SELF.guid, mock.now) }
mock.fire("PLAYER_DEAD")
mock.RunTimers()
Eq(Latest().name, "Young Forest Bear", "a name cut with none known")
ns.CreatureNames.Note(822, "Young Forest Bear", mock.now)
Eq(Latest().name, "Young Forest Bear", "a name its own name changed")

-- An old death mended from a close call's name, at login; the names read
-- are forgotten after a few days, and what they put right stays.
local old = { t = mock.now - 100, npcID = 2955, name = "Plainstrider Wrathlete" }
table.insert(j.deaths, 1, old)
j.closeCalls = j.closeCalls or {}
j.closeCalls[#j.closeCalls + 1] = { t = mock.now - 50, npcID = 2955, name = "Plainstrider", pct = 5 }
j.names[2955] = nil
J.Prune(mock.now)
Eq(old.name, "Plainstrider", "an old death not put right from a close call's name")
Check(j.names and j.names[30], "a name read today forgotten")
J.Prune(mock.now + 4 * 24 * 60 * 60)
Eq(j.names and j.names[30], nil, "a name read four days ago still kept")
Eq(spider.name, "Forest Spider", "a death put right lost its name with the name read")

-- Through the list's `named` (Journey.RegisterList): any list registered
-- so is put right the same way; one that is not, never.
J.RegisterList("scrapsNamed", { named = true })
J.RegisterList("scrapsPlain", {})
j.scrapsNamed = { { t = mock.now, npcID = 3100, name = "Mottled Boar Grunwald" } }
j.scrapsPlain = { { t = mock.now, npcID = 3100, name = "Mottled Boar Grunwald" } }
ns.CreatureNames.Note(3100, "Mottled Boar", mock.now)
Eq(j.scrapsNamed[1].name, "Mottled Boar", "a list registered `named` was not put right")
Eq(j.scrapsPlain[1].name, "Mottled Boar Grunwald", "a list not registered `named` was put right")
j.scrapsNamed, j.scrapsPlain = nil, nil

-- A list's `readNames` may be a function (Journey.RegisterList): the list
-- reads its names itself (the hunts: oldest first, then the ones under
-- way, kept beside the list), asked in its turn. And its `prune` runs at
-- login, for each route, before the names are put right: what it gives
-- up there names no creature any more, so an old death is not mended
-- from it. Registered again without them, the list is asked for neither.
do
    local asked = 0
    J.RegisterList("scrapsRead", {
        readNames = function(route, npcID)
            asked = asked + 1
            return route.scrapsOpen and route.scrapsOpen[npcID] or nil
        end,
        prune = function(route, now)
            if route.scrapsOpen and now > route.scrapsOpen.stale then route.scrapsOpen = nil end
        end })
    j.scrapsOpen = { [3101] = "Bristleback Quilboar", stale = mock.now - 1 }
    Eq(ns.CreatureNames.Of(j, 3101), "Bristleback Quilboar", "a list's own reading of its names not asked")
    local older = { t = mock.now - 100, npcID = 3101, name = "Bristleback Quilboar Hamm" }
    table.insert(j.deaths, 1, older)
    J.Prune(mock.now)
    Eq(j.scrapsOpen, nil, "a list's prune not run at login")
    Eq(older.name, "Bristleback Quilboar Hamm", "an old death put right from what a prune gave up first")
    j.scrapsOpen = { [3101] = "Bristleback Quilboar", stale = mock.now - 1 }
    J.RegisterList("scrapsRead", {})
    asked = 0
    Eq(ns.CreatureNames.Of(j, 3101), nil, "a list registered again without its reading still read")
    Eq(asked, 0, "a list registered again without its reading still asked")
    J.Prune(mock.now)
    Check(j.scrapsOpen ~= nil, "a list registered again without its prune still pruned")
    table.remove(j.deaths, 1)
    j.scrapsOpen = nil
end

-- A table a feature keeps on the route that is not a list (keyed) is
-- registered for its `forget` (and `prune`) alone: forgetting someone
-- (PRV-3, the "journey" store) asks it for each route, with their GUID or
-- nil for everyone; registered again without it, it is not asked.
do
    local SOMEONE = "Player-0000-SCRAP001"
    local forgot = {}
    J.RegisterList("scrapsKeyed", { forget = function(route, guid)
        forgot[#forgot + 1] = guid or "everyone"
        for _, rec in pairs(route.scrapsKeyed or {}) do
            if guid == nil or rec.guid == guid then rec.guid = nil end
        end
    end })
    j.scrapsKeyed = { a = { t = mock.now, guid = SOMEONE }, b = { t = mock.now, guid = "Player-0000-SCRAP002" } }
    ns.ForgetEverywhere(SOMEONE)
    Eq(j.scrapsKeyed.a.guid, nil, "a keyed table's forget not asked when someone is forgotten")
    Eq(j.scrapsKeyed.b.guid, "Player-0000-SCRAP002", "a keyed table's forget let go of someone else")
    Check(#forgot >= 1 and forgot[1] == SOMEONE, "the forget not told who: " .. tostring(forgot[1]))
    Eq(J.T.scrapsKeyed, nil, "a table registered with no cap has a cap")
    J.RegisterList("scrapsKeyed", {})
    j.scrapsKeyed.a.guid = SOMEONE
    ns.ForgetEverywhere(SOMEONE)
    Eq(j.scrapsKeyed.a.guid, SOMEONE, "a table registered again without its forget still forgot")
    j.scrapsKeyed = nil
end

-- At most sixty, the least recent dropped.
for id = 1001, 1061 do ns.CreatureNames.Note(id, "Mob " .. id, mock.now + id) end
local n = 0
for _ in pairs(j.names) do n = n + 1 end
Eq(n, 60, "the names read kept")
Eq(j.names[1001], nil, "the least recent name kept over the limit")

-- Route off: nothing read is kept.
ns.db.settings.keepRoute = false
ns.CreatureNames.Note(2000, "Gnoll Brute", mock.now)
Eq(j.names[2000], nil, "a name kept with the route off")
ns.db.settings.keepRoute = true


--------------------------------------------------------------------------
Section("the guess: the target is gone by PLAYER_DEAD")

local guessed
ns.On("SD_YOU_DIED", function(_, told) guessed = told end)
local function DieWith()
    guessed = nil
    mock.fire("PLAYER_DEAD")
    return guessed and guessed.guess
end

mock.now = mock.now + 600
mock.SetUnit("target", Mob(THUNDERHOOF, "Plainstrider"))
mock.fire("PLAYER_REGEN_DISABLED")
mock.SetUnit("target", nil)
local kept = DieWith()
Eq(kept and kept.name, "Plainstrider", "the foe held during the fight was not kept")
Eq(kept and kept.source, "target", "a kept foe's source")
Eq(kept and kept.npcID, 2955, "a kept foe's NPC id")
Eq(DieWith(), nil, "one fight's foe guessed at a second death")

-- Combat over just before the death is told: still that fight's.
mock.SetUnit("target", Mob(THUNDERHOOF, "Plainstrider"))
mock.fire("PLAYER_REGEN_DISABLED")
mock.SetUnit("target", nil)
mock.fire("PLAYER_REGEN_ENABLED")
mock.now = mock.now + 3
kept = DieWith()
Eq(kept and kept.name, "Plainstrider", "the foe was lost as combat ended")

-- Long after: a fall is nobody's doing.
mock.SetUnit("target", Mob(THUNDERHOOF, "Plainstrider"))
mock.fire("PLAYER_REGEN_DISABLED")
mock.SetUnit("target", nil)
mock.fire("PLAYER_REGEN_ENABLED")
mock.now = mock.now + 60
Eq(DieWith(), nil, "an old fight's foe guessed at a later death")

-- A foe targeted out of combat is not kept; one changed to in a fight is.
mock.SetUnit("target", Mob(THUNDERHOOF, "Plainstrider"))
mock.fire("PLAYER_TARGET_CHANGED")
mock.SetUnit("target", nil)
Eq(DieWith(), nil, "a target outside any fight was kept")
mock.fire("PLAYER_REGEN_DISABLED")
mock.SetUnit("target", Mob(LONGHOOF, "Longhoof"))
mock.fire("PLAYER_TARGET_CHANGED")
mock.SetUnit("target", nil)
kept = DieWith()
Eq(kept and kept.name, "Longhoof", "a foe targeted during the fight")
mock.fire("PLAYER_REGEN_ENABLED")
