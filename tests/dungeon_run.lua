-- Dungeon runs as the client tells them (Capture/Instances.lua into
-- Core/Instances.lua): in and out, the group, pulls, deaths, loot, when a
-- run ends and which runs are kept; and how Core/DungeonRun.lua places
-- their moments on the map (.claude/dungeon-visits-prd.md §18).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Instances, Run = ns.Instances, ns.DungeonRun

local STRANGER = F.STRANGER
local MIN = 60

_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM = "%s receives loot: %s."
_G.LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
_G.INSTANCE_RESET_SUCCESS = "%s has been reset."

local function Link(id, name, quality)
    return ("|cnIQ%d:|Hitem:%d::::::::16:1491::::::::|h[%s]|h|r"):format(quality, id, name)
end
local CHEST = Link(271098, "Golemguard Chest", 3)   -- Plunder's
local CLOTH = Link(2589, "Linen Cloth", 1)          -- nobody's, grey

local function In(name, id)
    mock.inInstance, mock.instanceName, mock.instanceID = true, name, id
    mock.fire("ZONE_CHANGED_NEW_AREA")
end
local function Out()
    mock.inInstance = false
    mock.fire("ZONE_CHANGED_NEW_AREA")
end

--------------------------------------------------------------------------
Section("in with a group: a run opens, with its members (INS-6, INS-12)")

mock.now = 1792073000
mock.timers = {}
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.RunTimers()

In("The Hall of Thanes", 3065)
local visit = Instances.Current()
Check(visit ~= nil, "no run opened")
Eq(ns.db.meta.openVisit, visit.id, "the open run is not remembered")
Eq(visit.instanceID, 3065, "instanceID")
Eq(visit.bossTotal, 4, "boss total from the dungeon's data")
Eq(#visit.members, 2, "members: the user and Bram")
Eq(visit.members[1].guid, F.SELF.guid, "the user comes first")
Eq(visit.members[2].guid, STRANGER.guid, "Bram is a member")
Eq(visit.members[2].first, "Bram", "a member's name")
Eq(visit.members[2].joined, mock.now, "when Bram joined")
Check(visit.members[1].first ~= nil, "the user's own member has no name")
Check(Instances.Inside(), "not inside")

-- The same zone change again changes nothing.
In("The Hall of Thanes", 3065)
Eq(#visit.spans, 1, "a second zone event inside opened a span")

--------------------------------------------------------------------------
Section("pulls, a wipe and a kill (INS-28, INS-29, INS-30)")

mock.now = mock.now + 5 * MIN
mock.fire("ENCOUNTER_START", 3493, "Faldrim Anvilmar", 1, 5)
Eq(#visit.pulls, 1, "the pull")
Eq(visit.pulls[1].name, "Faldrim Anvilmar", "the pull's boss")
mock.now = mock.now + 40
mock.fire("UNIT_DIED", STRANGER.guid)
mock.now = mock.now + 10
mock.fire("PLAYER_DEAD")
Eq(#visit.deathLog, 2, "the deaths in the pull")
Eq(visit.deathLog[1].pull, 1, "Bram's death is the pull's")
Eq(visit.deathLog[2].guid, F.SELF.guid, "the user's death")
Eq(visit.deaths, 2, "the death count")
mock.fire("ENCOUNTER_END", 3493, "Faldrim Anvilmar", 1, 5, 0)
Eq(visit.pulls[1].stop, mock.now, "the pull's end")
Eq(visit.pulls[1].killed, nil, "a wipe is a kill")
Eq(#visit.bossesKilled, 0, "a wipe killed a boss")

mock.now = mock.now + 3 * MIN
mock.fire("ENCOUNTER_START", 3493, "Faldrim Anvilmar", 1, 5)
mock.now = mock.now + 90
mock.fire("ENCOUNTER_END", 3493, "Faldrim Anvilmar", 1, 5, 1)
Eq(visit.pulls[2].killed, true, "the second pull's kill")
Eq(visit.bossesKilled[1], "Faldrim Anvilmar", "the kill")
local faldrimAt = mock.now
mock.fire("BOSS_KILL", 3493, "Faldrim Anvilmar")
Eq(#visit.pulls, 2, "BOSS_KILL after ENCOUNTER_END counted another pull")
Eq(#visit.bossesKilled, 1, "the same kill twice")

-- A secret pull: kept without its id or name, and marked.
mock.now = mock.now + 4 * MIN
mock.fire("ENCOUNTER_START", mock.secret(3495), mock.secret("Magmatus"), 1, 5)
Eq(visit.pulls[3].secret, true, "a secret pull is not marked")
Eq(visit.pulls[3].name, nil, "a secret name was stored")
mock.fire("ENCOUNTER_END", mock.secret(3495), mock.secret("Magmatus"), 1, 5, 1)
Eq(visit.pulls[3].killed, true, "a secret kill")
Eq(#visit.bossesKilled, 1, "a secret kill named a boss")

-- Plunder by id alone: the name comes from the dungeon's data.
mock.now = mock.now + 4 * MIN
mock.fire("ENCOUNTER_START", 3494, nil, 1, 5)
mock.fire("ENCOUNTER_END", 3494, nil, 1, 5, 1)
Eq(visit.bossesKilled[2], "Plunder", "a kill named from its id")

-- A death with no pull open, in a boss fight the pull events missed.
_G.C_InstanceEncounter = { IsEncounterInProgress = function() return true end }
mock.now = mock.now + MIN
mock.fire("UNIT_DIED", STRANGER.guid)
Eq(visit.deathLog[3].pull, nil, "a death outside a pull has one")
Eq(visit.deathLog[3].fight, true, "a death in a boss fight without a pull")
_G.C_InstanceEncounter = nil

-- A stranger's death is not the run's.
mock.fire("UNIT_DIED", F.PUG.guid)
Eq(#visit.deathLog, 3, "someone outside the group died into the run")

--------------------------------------------------------------------------
Section("loot (INS-31)")

mock.now = mock.now + 30
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. CHEST .. ".", "")
Eq(#visit.loot, 1, "the user's loot")
Eq(visit.loot[1].guid, F.SELF.guid, "whose")
Eq(visit.loot[1].itemID, 271098, "itemID")
T.Whisper("CHAT_MSG_LOOT", "Bram receives loot: " .. CHEST .. ".", "Bram")
Eq(visit.loot[2] and visit.loot[2].guid, STRANGER.guid, "a member's loot by name")
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. CLOTH .. "x3.", "")
Eq(#visit.loot, 2, "grey cloth kept")
T.Whisper("CHAT_MSG_LOOT", mock.secret("You receive loot: " .. CHEST .. "."), "")
Eq(#visit.loot, 2, "a secret loot line kept")
-- A trash green is let go; a blue from trash is kept.
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. Link(6337, "Infantry Leggings of the Whale", 2) .. ".", "")
Eq(#visit.loot, 2, "a trash green was kept")
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. Link(6337, "Infantry Leggings of the Whale", 3) .. ".", "")
Eq(#visit.loot, 3, "a blue from trash was let go")
table.remove(visit.loot) -- the run's notes below count Plunder's chests only

--------------------------------------------------------------------------
Section("out as a ghost and back (INS-7, INS-32)")

mock.ghost = true
mock.now = mock.now + MIN
Out()
Check(not Instances.Inside(), "still inside after leaving")
Eq(visit.spans[1].ghost, true, "left as a ghost")
mock.now = mock.now + 3 * MIN
In("The Hall of Thanes", 3065)
mock.ghost = nil
Eq(Instances.Current(), visit, "back in a new run")
Eq(#visit.spans, 2, "back in is a second span")
mock.fire("UNIT_DIED", STRANGER.guid)
Eq(#visit.deathLog, 4, "a death after coming back")

--------------------------------------------------------------------------
Section("the run's notes on the map (MAP-8 to MAP-12)")

local notes = Run.Notes(visit)
local first = notes.bosses[1]
Eq(first.boss.name, "Faldrim Anvilmar", "the first kill first")
Eq(first.tries, 2, "Faldrim's tries")
Eq(first.wipes, 1, "Faldrim's wipe")
Eq(#first.deaths, 2, "the deaths in Faldrim's pulls")
Eq(first.at, faldrimAt, "Faldrim's kill time")
Eq(notes.bosses[2].boss.name, "Plunder", "the second kill")
Eq(#notes.bosses[2].loot, 2, "the chests are Plunder's, by the loot table")
Eq(notes.ranBack, 1, "the ghost run")
Eq(#notes.legs, 2, "the deaths between bosses")
Eq(notes.legs[1].after.name, "Plunder", "the death after Plunder")
Eq(notes.legs[1].before, nil, "no kill after it")

--------------------------------------------------------------------------
Section("the run ends 30 minutes after the last time out (INS-9)")

mock.now = mock.now + 10 * MIN
Out()
local out = mock.now
mock.now = mock.now + 29 * MIN
Instances.Expire()
Eq(Instances.Current(), visit, "ended before the gap")
mock.now = mock.now + 2 * MIN
Instances.Expire()
Eq(Instances.Current(), nil, "still open after the gap")
Eq(ns.db.meta.openVisit, nil, "openVisit kept")
Eq(visit.endedAt, out, "the run ends at the last time out")
Eq(ns.db.instances[visit.id], visit, "a grouped run with kills was dropped")

--------------------------------------------------------------------------
Section("a short walk-in alone is not kept (INS-10)")

mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")
In("The Hall of Thanes", 3065)
local walk = Instances.Current()
Check(walk and walk ~= visit, "a new run did not open")
mock.now = mock.now + 2 * MIN
Out()
mock.now = mock.now + 31 * MIN
Instances.Expire()
Eq(ns.db.instances[walk.id], nil, "a two-minute walk-in alone was kept")

--------------------------------------------------------------------------
Section("another dungeon, a reset, or the same one later: a new run (INS-8)")

In("Razorfen Kraul", 47)
local rfk = Instances.Current()
mock.now = mock.now + 11 * MIN
In("The Deadmines", 36)
local dm = Instances.Current()
Check(dm ~= rfk, "another dungeon carried on the run")
Eq(ns.db.instances[rfk.id], rfk, "eleven minutes inside alone was dropped")
Out()
mock.fire("CHAT_MSG_SYSTEM", "The Deadmines has been reset.")
Eq(Instances.Current(), nil, "a reset left the run open")
In("The Deadmines", 36)
Check(Instances.Current() ~= dm, "back in after a reset carried on the run")

--------------------------------------------------------------------------
Section("a kill the pull events missed, proven by its loot (MAP-16)")

-- A /reload in the fight: neither pull event came. Magmatus' grips did.
In("The Hall of Thanes", 3065)
local missed = Instances.Current()
mock.now = mock.now + 6 * MIN
local grips = Link(270231, "Flamefist Grips", 3)
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. grips .. ".", "")
Eq(missed.bossesKilled[1], "Magmatus", "the loot did not prove the kill")
Eq(missed.inferred and missed.inferred.Magmatus, "loot", "the kill is not marked as told by its loot")
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. grips .. ".", "")
Eq(#missed.bossesKilled, 1, "a second item killed the boss again")
local mn = Run.Notes(missed)
Eq(mn.bosses[1].boss.name, "Magmatus", "the proven kill comes first")
Eq(mn.bosses[1].killed, true, "the proven kill")
Eq(mn.bosses[1].inferred, true, "the proven kill is not marked")
Eq(mn.bosses[1].at, mock.now, "the proven kill's time is its loot's")
-- A run saved before the capture inferred kills: the notes prove it.
local old = { instanceID = 3065, startedAt = 1, members = {}, bossesKilled = {},
    loot = { { guid = F.SELF.guid, itemID = 270231, time = 50 } } }
local on = Run.Notes(old)
Eq(on.bosses[1].boss.name, "Magmatus", "an old run's loot proves no kill")
Eq(on.bosses[1].inferred, true, "an old run's proven kill is not marked")

--------------------------------------------------------------------------
Section("the client's name for a boss the data names otherwise (2026-10-16)")

-- Encounter 3495 is "Infurnus" in the client and "Magmatus" in the data.
-- A fresh run: out, reset, in.
Out()
mock.fire("CHAT_MSG_SYSTEM", "The Hall of Thanes has been reset.")
In("The Hall of Thanes", 3065)
local named = Instances.Current()
Check(named ~= missed, "the reset did not start a new run")
mock.fire("ENCOUNTER_START", 3495, "Infurnus", 1, 5)
mock.now = mock.now + 30
mock.fire("ENCOUNTER_END", 3495, "Infurnus", 1, 5, 1)
Eq(named.bossesKilled[1], "Infurnus", "the kill is not kept under the client's name")
Eq(ns.Dungeons.Killed(named)[1].name, "Magmatus", "the kill is not found in the data by its id")
local grips2 = Link(270231, "Flamefist Grips", 3)
T.Whisper("CHAT_MSG_LOOT", "You receive loot: " .. grips2 .. ".", "")
Eq(#named.bossesKilled, 1, "its loot proved the kill again, under the data's name")
Eq(named.inferred, nil, "a kill the pulls saw is marked as told by its loot")
local nn = Run.Notes(named)
Eq(nn.bosses[1].boss.name, "Magmatus", "the boss")
Eq(nn.bosses[1].client, "Infurnus", "the client's name for it")
Eq(nn.bosses[1].inferred, nil, "a seen kill is proven by loot")

-- A failed pull with half the group dead in it is a wipe on the record.
mock.fire("ENCOUNTER_START", 3496, "Durgen Dirgehammer", 1, 5)
mock.fire("PLAYER_DEAD")
mock.fire("ENCOUNTER_END", 3496, "Durgen Dirgehammer", 1, 5, 0)
Eq(named.wipes, 1, "a failed pull with the (lone) user dead is not a wipe")
Eq(Run.Wipes(named), 1, "Wipes")

--------------------------------------------------------------------------
Section("a wipe to trash on the way (MAP-17), kills in the order they fell")

local trash = {
    instanceID = 3065, startedAt = 0, me = "Player-1-0",
    members = { { guid = "Player-1-0" }, { guid = "Player-1-A" }, { guid = "Player-1-B" },
        { guid = "Player-1-C", left = 100 } },  -- C left early: three in the group at the time
    -- the client's name first: the order must come from the times
    bossesKilled = { "Faldrim Anvilmar", "Infurnus", "Plunder" },
    pulls = {
        { id = 3493, name = "Faldrim Anvilmar", start = 600, stop = 700, killed = true },
        { id = 3495, name = "Infurnus", start = 1200, stop = 1250, killed = true },
        { id = 3494, name = "Plunder", start = 1900, stop = 1950, killed = true },
    },
    deathLog = {
        { guid = "Player-1-A", time = 1500, killer = { name = "Dark Iron Looter" } },
        { guid = "Player-1-0", time = 1530, killer = { name = "Dark Iron Looter" } },
        { guid = "Player-1-B", time = 1700, killer = { name = "Dark Iron Looter" } },
    },
}
local tw = Run.Notes(trash)
Eq(tw.bosses[2].boss.name, "Magmatus", "the second kill by time")
Eq(#tw.wipes, 1, "two of three dead within a minute is not a wipe on the way")
Eq(#tw.wipes[1].deaths, 2, "the trash wipe's deaths")
Eq(tw.wipes[1].killer, "Dark Iron Looter", "what wiped them")
Eq(tw.wipes[1].after.name, "Magmatus", "the trash wipe's leg starts")
Eq(tw.wipes[1].before.name, "Plunder", "... and ends")
Eq(Run.Wipes(trash), 1, "Wipes counts the trash wipe")

--------------------------------------------------------------------------
Section("notes without pulls: by the killers' names and the time")

local hand = {
    instanceID = 3065, startedAt = 1000, me = F.SELF.guid,
    members = { { guid = F.SELF.guid }, { guid = "Player-1-A" }, { guid = "Player-1-B" }, { guid = "Player-1-C" } },
    bossesKilled = { "Faldrim Anvilmar", "Durgen Dirgehammer" },
    pulls = {
        { id = 3493, name = "Faldrim Anvilmar", start = 1100, stop = 1200, killed = true },
        { id = 3496, name = "Durgen Dirgehammer", start = 2100, stop = 2200, killed = true },
    },
    deathLog = {
        -- two at Plunder within 30 s: half of four, a wipe without a pull
        { guid = F.SELF.guid, time = 1500, killer = { name = "Plunder" } },
        { guid = "Player-1-A", time = 1520, killer = { name = "Plunder" } },
        -- trash between the two kills, a quarter of the way
        { guid = "Player-1-B", time = 1425, killer = { name = "Bloodhound Runt" } },
        -- trash before any kill
        { guid = "Player-1-C", time = 1050, killer = { name = "Dark Iron Looter" } },
    },
    loot = { { guid = F.SELF.guid, itemID = 999999, time = 2300 } },
    spans = { { from = 1000 } },
}
local n = Run.Notes(hand)
local plunder
for _, e in ipairs(n.bosses) do
    if e.boss.name == "Plunder" then plunder = e end
end
Check(plunder ~= nil, "Plunder is not among the bosses")
Eq(plunder.killed, nil, "Plunder was killed")
Eq(#plunder.deaths, 2, "deaths by the boss's name")
Eq(plunder.wipes, 1, "a wipe without a pull")
Eq(n.bosses[#n.bosses].boss.name, "Plunder", "a standing boss comes after the kills")
local leg
for _, l in ipairs(n.legs) do
    if l.death.guid == "Player-1-B" then leg = l end
end
Eq(leg.after.name, "Faldrim Anvilmar", "the trash death's leg starts at Faldrim")
Eq(leg.before.name, "Durgen Dirgehammer", "... and ends at Durgen")
Check(math.abs(leg.frac - 0.225) < 0.001, "how far along the leg: " .. tostring(leg.frac))
local early
for _, l in ipairs(n.legs) do
    if l.death.guid == "Player-1-C" then early = l end
end
Eq(early.after, nil, "a death before any kill starts at a boss")
Eq(early.before.name, "Faldrim Anvilmar", "... and goes towards the first kill")
-- An item no table holds is found on the way, even right after a kill:
-- only a boss's own table says it dropped there (MAP-11).
Eq(#n.bosses[2].loot, 0, "loot no table holds went to the boss killed before it")
Eq(#n.unplaced.loot, 1, "loot no table holds was placed")

--------------------------------------------------------------------------
Section("forgetting a member takes their deaths and loot (PRV-3)")

ns.Characters.Forget(STRANGER.guid)
for _, d in ipairs(visit.deathLog) do
    Check(d.guid ~= STRANGER.guid, "a forgotten member's death stayed")
end
for _, l in ipairs(visit.loot) do
    Check(l.guid ~= STRANGER.guid, "a forgotten member's loot stayed")
end

--------------------------------------------------------------------------
Section("/sd testdata's Razorfen Kraul run, as the map's notes see it")

SlashCmdList.SOCIALDIARY("testdata")
local rfkTest
for _, v in ipairs(Instances.All()) do
    if v.test and v.instanceID == 47 then rfkTest = v end
end
Check(rfkTest ~= nil, "no Razorfen Kraul test run")
local tn = Run.Notes(rfkTest)
local byBoss = {}
for _, e in ipairs(tn.bosses) do byBoss[e.boss.name] = e end
Eq(tn.bosses[1].boss.name, "Roogug", "the first kill")
Eq(byBoss["Aggem Thorncurse"].tries, 2, "Aggem's tries")
Eq(byBoss["Aggem Thorncurse"].wipes, 1, "the wipe on Aggem")
Eq(#byBoss["Aggem Thorncurse"].deaths, 3, "the wipe's deaths")
Eq(byBoss["Aggem Thorncurse"].loot[1].guid, ns.TestData.GUID, "Thornspike for Tester")
Eq(byBoss["Overlord Ramtusk"].loot[1].guid, ns.ownGUID, "the Tusken Helm for the user")
Eq(byBoss["Agathelos the Raging"].killed, nil, "Agathelos stands")
Eq(tn.ranBack, 1, "the ghost run after the wipe")
Eq(#tn.legs, 1, "the trash death")
Eq(tn.legs[1].after.name, "Aggem Thorncurse", "the trash death after Aggem")
Eq(tn.legs[1].before.name, "Death Speaker Jargba", "... on the way to Jargba")
