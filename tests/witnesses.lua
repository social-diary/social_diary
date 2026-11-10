-- Witnesses (Features/Witnesses/): who watched while the user died,
-- who tried to save them, and who saved them in a fight they only just
-- survived, all off what the nameplates say; the timeline's lines and the
-- picker's reasons.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local W = ns.Witnesses
local SELF, STRANGER, FRIEND, PUG, HOSTILE = F.SELF, F.STRANGER, F.FRIEND, F.PUG, F.HOSTILE
local STRANGER2, GARRICK = F.STRANGER2, F.GARRICK

local STRIDER = "Creature-0-4615-1-832-2955-00004B69A3"
local STRIDER2 = "Creature-0-4615-1-832-2955-00004B69A4"
local WOLF = "Creature-0-4615-1-832-2958-00004B6A01"
local HOGGER = "Creature-0-4615-1-832-448-00004B69A9"

local function Mob(guid, name, extra)
    local def = { guid = guid, name = { name }, isPlayer = false, hostile = true }
    for key, value in pairs(extra or {}) do def[key] = value end
    return def
end

-- In combat, unit by unit: the user follows mock.inCombat, everyone else
-- this set.
local fighting = {}
_G.UnitAffectingCombat = function(unit)
    if unit == "player" then return mock.inCombat end
    local def = mock.units[unit]
    return def ~= nil and fighting[def.guid] == true
end

-- `def` on a nameplate, with `target` targeted.
local function Plate(i, def, target)
    mock.SetUnit("nameplate" .. i, def)
    mock.SetUnit("nameplate" .. i .. "target", target)
end

-- The user's target, on the user: a foe.
local function Target(def)
    mock.SetUnit("target", def)
    mock.SetUnit("targettarget", SELF)
    mock.fire("PLAYER_TARGET_CHANGED")
end

-- The client's clock to the fraction of a second: the server's, and a
-- fraction a test can set.
local frac = 0
_G.GetTime = function() return mock.now + frac end

-- `seconds` go by, the plates read once a second as the ticker does.
local function Pass(seconds)
    for _ = 1, seconds do
        mock.now = mock.now + 1
        ns._test.WitnessesScan()
    end
end

local function Start()
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
end

local function Fresh()
    T.BlankDiary()
    fighting = {}
    mock.ClearUnits()
    mock.SetUnit("player", SELF)
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
end

local function Line(guid, kind)
    local row = ns._test.LatestInteraction(guid, kind)
    if not row then return nil end
    local _, text = ns.UI.DescribeItem({ kind = "row", row = row }, guid)
    return (text:gsub("\194\160", " "))
end

local function Rows(guid)
    return T.Rows(guid, W.WATCHED) + T.Rows(guid, W.HELPED) + T.Rows(guid, W.SAVED)
end

mock.now = 1792000000
mock.zone = "Mulgore"
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()

--------------------------------------------------------------------------
Section("looked on: had you targeted as you died, out of combat")

Fresh()
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
-- Not witnesses: an enemy, someone in the group, a healer (in combat, you
-- targeted), someone looking elsewhere.
Plate(2, HOSTILE, SELF)
mock.fire("UNIT_TARGET", "nameplate2")
ns.Roster.Update({ [PUG.guid] = {} }, true, false)
Plate(3, PUG, SELF)
mock.fire("UNIT_TARGET", "nameplate3")
fighting[FRIEND.guid] = true
Plate(4, FRIEND, SELF)
mock.fire("UNIT_TARGET", "nameplate4")
Plate(5, GARRICK, Mob(WOLF, "Wolf"))
mock.fire("UNIT_TARGET", "nameplate5")
local f = ns._test.Witnesses()
Check(f.looked[STRANGER.guid], "the stranger looking on was not noted")
Eq(f.looked[HOSTILE.guid], nil, "an enemy was noted")
Eq(f.looked[PUG.guid], nil, "a group member was noted")
Eq(f.looked[FRIEND.guid], nil, "someone in combat with you targeted was noted as looking on")
Eq(f.looked[GARRICK.guid], nil, "someone looking elsewhere was noted")

Pass(20)
mock.fire("PLAYER_DEAD")
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "the onlooker was not written down")
Eq(Rows(PUG.guid), 0, "a group member was written down")
Eq(Rows(HOSTILE.guid), 0, "an enemy was written down")
Eq(Rows(FRIEND.guid), 0, "the healer was written down")
Eq(Rows(GARRICK.guid), 0, "someone looking elsewhere was written down")
Eq(Line(STRANGER.guid, W.WATCHED), "Bram mercilessly watched you die to a Plainstrider in Mulgore", "the line")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "written again as combat ended")
ns.Roster.Update({}, true, false)

-- A look long before the end, then elsewhere, is not looking on.
Fresh()
Start()
Plate(1, STRANGER, SELF)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Plate(1, STRANGER, Mob(WOLF, "Wolf"))
mock.now = mock.now + 30
mock.fire("PLAYER_DEAD")
Eq(Rows(STRANGER.guid), 0, "a look 30 s before the death counted")

-- The client drops the user's target as they die (probe, 14 Oct): the
-- line still names the foe, from while the fight went. With /sd debug on,
-- the trace is kept in the diary, a snapshot of everyone at the death.
Fresh()
ns.db.settings.debug = true
ns.db.witnessTrace = nil
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, SELF)
Plate(2, GARRICK, nil)
mock.fire("UNIT_TARGET", "nameplate1")
mock.SetUnit("target", nil)
mock.fire("PLAYER_DEAD")
ns.db.settings.debug = false
Eq(Line(STRANGER.guid, W.WATCHED), "Bram saw you die to a Plainstrider in Mulgore", "the foe was lost with the target")
local trace = table.concat(ns.db.witnessTrace or {}, "\n")
Check(trace:find("Plainstrider ~B69A3 is on you", 1, true), "the trace does not tell the foe by its GUID")
Check(trace:find("you died: 2 plate(s), 2 of players", 1, true), "the death's snapshot is not in the trace")
Check(trace:find("Garrick Fallow [nameplate2]: target nobody, combat false", 1, true),
    "the snapshot does not say what everyone was doing")
Check(trace:find("Bram Redfen [nameplate1]: target YOU", 1, true), "the snapshot does not say who had you targeted")

-- Looking at the creature killing you is looking on too; at another of
-- its kind, not: a Plainstrider is one GUID, not a name.
Fresh()
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, Mob(STRIDER, "Plainstrider"))
Plate(2, GARRICK, Mob(STRIDER2, "Plainstrider"))
ns._test.WitnessesScan()
mock.now = mock.now + 5
mock.fire("PLAYER_DEAD")
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "looking at your foe was not looking on")
Eq(Rows(GARRICK.guid), 0, "looking at another Plainstrider was looking on")

-- A creature tabbed to, on someone else, is no foe: fighting it is not
-- helping, looking at it is not looking on.
Fresh()
Start()
Target(Mob(STRIDER, "Plainstrider"))
mock.SetUnit("target", Mob(STRIDER2, "Plainstrider"))
mock.SetUnit("targettarget", GARRICK)
mock.fire("PLAYER_TARGET_CHANGED")
fighting[GARRICK.guid] = true
Plate(1, GARRICK, Mob(STRIDER2, "Plainstrider"))
Plate(2, STRANGER, Mob(STRIDER2, "Plainstrider"))
ns._test.WitnessesScan()
f = ns._test.Witnesses()
Eq(f.foes[STRIDER2], nil, "a creature on someone else was a foe for being your target")
mock.SetUnit("target", nil)
mock.fire("PLAYER_DEAD")
Eq(Rows(GARRICK.guid), 0, "fighting a creature you tabbed to was helping")
Eq(Rows(STRANGER.guid), 0, "looking at a creature you tabbed to was looking on")

-- Away from the keyboard is not looking on.
Fresh()
mock.afk = true
Start()
Plate(1, STRANGER, SELF)
mock.fire("PLAYER_DEAD")
mock.afk = false
Eq(Rows(STRANGER.guid), 0, "someone AFK looked on")

-- Out of a fight (a fall): who looked on, read as the user falls, and no
-- creature to name.
Fresh()
mock.SetUnit("target", STRANGER)
mock.SetUnit("targettarget", SELF)
Plate(1, STRANGER, SELF)
mock.fire("PLAYER_DEAD")
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "one row for the target and the plate")
Eq(Line(STRANGER.guid, W.WATCHED), "Bram saw you die in Mulgore", "the line without a creature")

--------------------------------------------------------------------------
Section("how long they watched: saw, watched, mercilessly watched")

-- Each looks on from `from` seconds before the death, through to it.
local function Watched(seconds, fraction)
    Fresh()
    Start()
    Target(Mob(STRIDER, "Plainstrider"))
    frac = fraction or 0
    Plate(1, STRANGER, SELF)
    mock.fire("UNIT_TARGET", "nameplate1")
    frac = 0
    Pass(seconds)
    mock.fire("PLAYER_DEAD")
    return ns._test.LatestInteraction(STRANGER.guid, W.WATCHED), Line(STRANGER.guid, W.WATCHED)
end

mock.subZone = "Red Cloud Mesa"
local row, line = Watched(1)
Eq(row and row.context.watched, 1, "a second's look")
Eq(line, "Bram saw you die to a Plainstrider in Red Cloud Mesa", "under 1.5 s, and in the subzone")
row, line = Watched(2, 0.6)
Eq(row and row.context.watched, 1.4, "the fraction of a second counts")
Eq(line, "Bram saw you die to a Plainstrider in Red Cloud Mesa", "1.4 s")
row, line = Watched(2)
Eq(line, "Bram watched you die to a Plainstrider in Red Cloud Mesa", "from 1.5 s")
row, line = Watched(4)
Eq(line, "Bram watched you die to a Plainstrider in Red Cloud Mesa", "4 s")
row, line = Watched(5)
Eq(line, "Bram mercilessly watched you die to a Plainstrider in Red Cloud Mesa", "from 5 s")
mock.subZone = ""

-- A look broken counts for as long as it ran; a new one starts again.
Fresh()
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
Pass(6)
Plate(1, STRANGER, Mob(WOLF, "Wolf"))
Pass(2)
mock.fire("PLAYER_DEAD")
Eq(ns._test.LatestInteraction(STRANGER.guid, W.WATCHED).context.watched, 6, "a broken look lost its length")
Fresh()
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
Pass(6)
Plate(1, STRANGER, Mob(WOLF, "Wolf"))
Pass(1)
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
Pass(2)
mock.fire("PLAYER_DEAD")
Eq(ns._test.LatestInteraction(STRANGER.guid, W.WATCHED).context.watched, 2, "a look begun again added the old one")

-- Looking at your foe is watching too.
Fresh()
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, Mob(STRIDER, "Plainstrider"))
Pass(7)
mock.fire("PLAYER_DEAD")
Eq(Line(STRANGER.guid, W.WATCHED), "Bram mercilessly watched you die to a Plainstrider in Mulgore", "watching your foe")

-- A row kept before the watching was timed.
ns.Interactions.Add(STRANGER.guid, W.WATCHED, { context = { name = "Plainstrider", npcID = 2955 } })
Eq(Line(STRANGER.guid, W.WATCHED), "Bram watched you die to a Plainstrider in Mulgore", "an old row")

--------------------------------------------------------------------------
Section("tried to save you: in combat with one of your foes")

Fresh()
Start()
-- Your target is a foe; so is a creature that has you targeted.
Target(Mob(HOGGER, "Hogger", { classification = "rare" }))
Plate(1, Mob(STRIDER, "Plainstrider"), SELF)
mock.fire("UNIT_TARGET", "nameplate1")
-- Looked on first, then waded in: in combat with Hogger.
Plate(2, FRIEND, SELF)
mock.fire("UNIT_TARGET", "nameplate2")
fighting[FRIEND.guid] = true
Plate(2, FRIEND, Mob(HOGGER, "Hogger"))
ns._test.WitnessesScan()
-- In combat with the Plainstrider on you.
fighting[STRANGER2.guid] = true
Plate(3, STRANGER2, Mob(STRIDER, "Plainstrider"))
mock.fire("UNIT_TARGET", "nameplate3")
-- Not helpers: in combat with a creature that is no foe of yours, and out
-- of combat with your foe targeted (who looked on).
fighting[GARRICK.guid] = true
Plate(4, GARRICK, Mob(WOLF, "Wolf"))
Plate(5, STRANGER, Mob(HOGGER, "Hogger"))
ns._test.WitnessesScan()
f = ns._test.Witnesses()
Check(f.foes[HOGGER], "your target was not a foe")
Check(f.foes[STRIDER], "a creature on you was not a foe")
Eq(f.foes[WOLF], nil, "a creature on someone else was a foe")

mock.now = mock.now + 25
local died = mock.now
mock.fire("PLAYER_DEAD")
Eq(T.Rows(FRIEND.guid, W.HELPED), 1, "the one who waded in was not written down")
Eq(T.Rows(FRIEND.guid, W.WATCHED), 0, "a helper also looked on")
Eq(T.Rows(STRANGER2.guid, W.HELPED), 1, "the one fighting the creature on you was not written down")
Eq(Rows(GARRICK.guid), 0, "someone fighting their own was written down")
Eq(T.Rows(STRANGER.guid, W.HELPED), 0, "someone out of combat with your foe targeted helped")
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "someone out of combat with your foe targeted did not look on")
Eq(Line(FRIEND.guid, W.HELPED), "Numa tried to save you from Hogger in Mulgore", "the line")
Eq(ns._test.LatestInteraction(FRIEND.guid, W.HELPED).time, died, "the row's time is the death's")

-- A creature that targets you only after the helper took it on is still
-- one of your foes by the end.
Fresh()
Start()
fighting[FRIEND.guid] = true
Plate(1, FRIEND, Mob(STRIDER2, "Plainstrider"))
mock.fire("UNIT_TARGET", "nameplate1")
Plate(2, Mob(STRIDER2, "Plainstrider"), SELF)
mock.fire("UNIT_TARGET", "nameplate2")
mock.fire("PLAYER_DEAD")
Eq(T.Rows(FRIEND.guid, W.HELPED), 1, "the order of the looks mattered")

-- The plates are read once a second: a late helper targets your foe out
-- of combat, hits it, and it dies before the next reading, which finds
-- them in combat with their target gone. Each at some point is enough.
-- With /sd debug on, which names it all.
Fresh()
ns.db.settings.debug = true
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, FRIEND, Mob(STRIDER, "Plainstrider"))
mock.fire("UNIT_TARGET", "nameplate1")
fighting[FRIEND.guid] = true
Plate(1, FRIEND, nil)
ns._test.WitnessesScan()
mock.fire("PLAYER_DEAD")
ns.db.settings.debug = false
Eq(T.Rows(FRIEND.guid, W.HELPED), 1, "a target and a fight a second apart did not add up")

--------------------------------------------------------------------------
Section("saved you: fought one of your foes in a fight you survived at 20% or less")

-- A fight with a helper, and the close-call judge's answer for it.
local function Rescue(taken, foe)
    Fresh()
    local from = mock.now
    Start()
    Target(Mob(STRIDER, "Plainstrider"))
    fighting[STRANGER.guid] = true
    Plate(1, STRANGER, Mob(STRIDER, "Plainstrider"))
    mock.fire("UNIT_TARGET", "nameplate1")
    mock.now = mock.now + 40
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    W.Survived(from, mock.now, taken, 100, foe)
end

Rescue(70, { npcID = 2955, name = "Plainstrider" })
Eq(Rows(STRANGER.guid), 0, "30% left was a rescue")

ns.db.settings.debug = true
Rescue(85, { npcID = 2955, name = "Plainstrider" })
ns.db.settings.debug = false
Eq(T.Rows(STRANGER.guid, W.SAVED), 1, "the rescuer was not written down")
Eq(Line(STRANGER.guid, W.SAVED), "Bram saved you from a Plainstrider at 15% health in Mulgore", "the line")

-- Healed through by someone the meter does not list: more than all of it.
Rescue(130)
Eq(Line(STRANGER.guid, W.SAVED), "Bram saved you at 1% health in Mulgore", "healed through")

-- A judge for a fight that is not kept: nothing.
Fresh()
W.Survived(mock.now - 3600, mock.now - 3500, 90, 100)
Eq(Rows(STRANGER.guid), 0, "an unknown fight was judged")

-- Through the close-call judge (Features/CloseCalls/Capture.lua): the meter's damage
-- taken once combat is over, told as SD_FIGHT_SURVIVED (Core/Events.lua),
-- which Capture.lua hands to Survived. The earlier deaths' judges, still trying a
-- meter that was never there, are let run out first.
Fresh()
for _ = 1, 6 do mock.RunTimers() end
local taken = 0
_G.Enum.DamageMeterType = { HealingDone = 2, DamageTaken = 7 }
_G.C_DamageMeter = {
    GetAvailableCombatSessions = function() return { { sessionID = 1 } } end,
    GetCombatSessionFromID = function(_, kind)
        if kind == 7 then return { combatSources = { { isLocalPlayer = true, totalAmount = taken } } } end
        return { combatSources = {} }
    end,
    GetCombatSessionSourceFromID = function() return { combatSpells = {} } end,
}
mock.healthMax = 100
Start()
Target(Mob(STRIDER, "Plainstrider"))
fighting[STRANGER2.guid] = true
Plate(1, STRANGER2, Mob(STRIDER, "Plainstrider"))
mock.fire("UNIT_TARGET", "nameplate1")
mock.now = mock.now + 30
taken = 82
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
mock.RunTimers()
Eq(T.Rows(STRANGER2.guid, W.SAVED), 1, "the close-call judge did not ask who saved you")
Eq(Line(STRANGER2.guid, W.SAVED), "Tullus saved you from a Plainstrider at 18% health in Mulgore", "the line")

--------------------------------------------------------------------------
Section("finished off: your foe died, not by you or your group")

-- As in the client (14 Oct): the finisher had you targeted, cast through
-- you, and was never seen in combat. Your foe died with no PARTY_KILL.
Fresh()
local from = mock.now
Start()
Target(Mob(WOLF, "Timber Wolf"))
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
-- Looking at another creature that dies is nothing to do with you.
Plate(2, GARRICK, Mob(STRIDER2, "Plainstrider"))
mock.fire("UNIT_TARGET", "nameplate2")
mock.now = mock.now + 30
ns._test.WitnessesScan()
mock.fire("UNIT_DIED", WOLF)
mock.fire("UNIT_DIED", STRIDER2)
mock.RunTimers()
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
W.Survived(from, mock.now, 96, 100, { npcID = 2958, name = "Timber Wolf" })
Eq(T.Rows(STRANGER.guid, W.SAVED), 1, "the one who finished your foe off was not written down")
Eq(Line(STRANGER.guid, W.SAVED), "Bram saved you from a Timber Wolf at 4% health in Mulgore", "the line")
Eq(Rows(GARRICK.guid), 0, "someone looking at another creature was written down")

-- Your own kill (or your pet's, or your group's) is no rescue, whoever
-- was looking.
Fresh()
from = mock.now
Start()
Target(Mob(WOLF, "Timber Wolf"))
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
mock.now = mock.now + 30
ns._test.WitnessesScan()
mock.fire("PARTY_KILL", "Pet-0-4615-1-832-165189-0000AAAAAA", WOLF)
mock.fire("UNIT_DIED", WOLF)
mock.RunTimers()
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
W.Survived(from, mock.now, 96, 100)
Eq(Rows(STRANGER.guid), 0, "your pet's kill made a rescuer")

-- A look long before the foe died does not count.
Fresh()
from = mock.now
Start()
Target(Mob(WOLF, "Timber Wolf"))
Plate(1, STRANGER, SELF)
mock.fire("UNIT_TARGET", "nameplate1")
Plate(1, STRANGER, nil)
mock.now = mock.now + 30
mock.fire("UNIT_DIED", WOLF)
mock.RunTimers()
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
W.Survived(from, mock.now, 96, 100)
Eq(Rows(STRANGER.guid), 0, "a look 30 s before the foe died made a rescuer")

--------------------------------------------------------------------------
Section("after the reunion toast: what a look in a fight reads")

-- Nearby's reunion toast (Capture/Nearby.lua) and this capture read the
-- same nameplate and the same target. A look read in a fight puts what the
-- unit shows on the character's record (Characters.ObserveUnit), so it
-- comes after the toast has taken its snapshot, as it always has:
-- Features/Witnesses/Capture.lua is listed after Capture/ in the TOC. A diary entry the diary knows by their
-- first name only (off a chat name, say) comes into view in a fight,
-- looking on: the toast names them as the diary knew them, and the look
-- reads their surname after.
Fresh()
ns.Characters.Forget(STRANGER.guid)
wipe(ns.db.meta.greeted)
ns.Characters.Observe(STRANGER.guid, { first = "Bram" })
ns.Diary.Add(STRANGER.guid, { source = "test" })
Eq(ns.Characters.FullName(STRANGER.guid), "Bram", "setup: the diary knew their surname")
Eq(ns.UI.ReunionShowing(), nil, "setup: a toast is up")
Start()
Target(Mob(STRIDER, "Plainstrider"))
Plate(1, STRANGER, SELF)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Eq(ns.Characters.FullName(STRANGER.guid), "Bram Redfen", "the look did not read them")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
local toast = ns.UI.ReunionShowing()
Eq(toast and toast.name, "Bram", "the toast's name: the look was read before the toast took it")
mock.RunTimers()

--------------------------------------------------------------------------
Section("on the plates: a witness before the killer")

-- The rows find their death or close call by time (ns.Witnesses.At, over
-- the core's Journey.WitnessIndex, which goes by Rows' `witness` flag),
-- and the plate picks one (ns.Witnesses.Card.Choose): who acted before
-- who watched, then the longer watcher.
Fresh()
local t0 = mock.now
ns.Interactions.Add(STRANGER.guid, W.WATCHED, { time = t0, context = { watched = 6.2, name = "Kobold Vermin", npcID = 6 } })
ns.Interactions.Add(GARRICK.guid, W.WATCHED, { time = t0 + 1, context = { watched = 2 } })
ns.Interactions.Add(FRIEND.guid, W.HELPED, { time = t0 + 600, context = { name = "Kobold Vermin", npcID = 6 } })
ns.Interactions.Add(STRANGER2.guid, W.SAVED, { time = t0 + 1200, context = { pct = 11, name = "Burly Rockjaw Trogg" } })
local index = ns.Journey.WitnessIndex()
Eq(#index, 4, "the index")
local at = W.At(index, t0, { watched_death = true, tried_to_help = true })
Eq(#at, 2, "both watchers of the first death")
Eq(at[1].guid, STRANGER.guid, "the longer watcher first")
Eq(#W.At(index, t0 + 10, { watched_death = true }), 0, "a death ten seconds on had watchers")
Eq(#W.At(index, t0 + 1200, { watched_death = true, tried_to_help = true }), 0,
    "a rescue was a death's witness")

local Card = W.Card
local function OnPage(x, y) return x + 100, y + 200 end
local first = { t = t0 }
local second = { t = t0 + 600 }
local crosses = { { x = 10, y = 20, deaths = { first } }, { x = 30, y = 40, deaths = { second } } }
local w = Card.Choose(crosses, {}, index, OnPage)
Eq(w and w.guid, FRIEND.guid, "who tried to save you goes before who watched")
Eq(w.kind, "helped", "kind")
Eq(w.death, second, "the death")
Eq(w.mark[1] .. "," .. w.mark[2], "130,240", "where its cross is on the page")
Eq(w.creature and w.creature.name, "Kobold Vermin", "the creature")
w = Card.Choose({ crosses[1] }, {}, index, OnPage)
Eq(w.guid, STRANGER.guid, "the longer watcher")
Eq(w.watched, 6.2, "how long")
Eq(w.others, 1, "one more watched")
local call = { t = t0 + 1200, pct = 11 }
w = Card.Choose({}, { { at = { 5, 6 }, list = { { call = call } } } }, index, OnPage)
Eq(w and w.type, W.SAVED, "a rescue on a close call")
Eq(w.call, call, "its close call")
Eq(w.pct, 11, "health left")
Eq(Card.Choose({ { x = 0, y = 0, deaths = { { t = t0 + 3000 } } } }, {}, index, OnPage), nil, "nobody was there")

--------------------------------------------------------------------------
Section("the picker's reasons")

Fresh()
ns.Interactions.Add(STRANGER.guid, W.WATCHED, {})
ns.Interactions.Add(FRIEND.guid, W.HELPED, {})
ns.Interactions.Add(STRANGER2.guid, W.SAVED, {})
local reasons = {}
for _, c in ipairs(ns.Candidates()) do reasons[c.guid] = c.why end
Eq(reasons[STRANGER.guid], "they watched you die", "watched")
Eq(reasons[FRIEND.guid], "they tried to save you", "tried to save")
Eq(reasons[STRANGER2.guid], "they saved you", "saved")

-- What each witness did, as Core/Rows.lua's `witness` says it: the core's
-- index of witnesses goes by it (Journey.WitnessIndex), the plate's choice
-- by "helped" before "watched".
Eq(ns.Rows.Get(W.WATCHED).witness, "watched", "a watcher's flag")
Eq(ns.Rows.Get(W.HELPED).witness, "helped", "a helper's flag")
Eq(ns.Rows.Get(W.SAVED).witness, "helped", "a rescuer's flag")
