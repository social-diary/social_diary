-- Group loot rolls in a run (pass B, .claude/dungeon-visits-prd.md): the
-- client's roll sentences and its loot history read into the visit
-- (Capture/Instances.lua, Core/Instances.lua), and what Core/DungeonRun.lua
-- makes of them: an item snagged from the user, a bad roll, an item that
-- finally came to them. The sentences are the client's own, as the probe
-- read them off the save (16 Oct); the names are invented.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Instances, Run = ns.Instances, ns.DungeonRun

local STRANGER = F.STRANGER
local ME = F.SELF.guid
local HISTORY = "|HlootHistory:%d|h[Loot]|h: "

_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM = "%s receives loot: %s."
_G.NEED = "Need"
_G.LOOT_ROLL_YOU_WON_NO_SPAM_NEED = HISTORY .. "You (Need - %d, Main-Spec) Won: %s"
_G.LOOT_ROLL_YOU_WON_NO_SPAM_NEED_OFF_SPEC = HISTORY .. "You (Need - %d, Off-Spec) Won: %s"
_G.LOOT_ROLL_WON_NO_SPAM_NEED = HISTORY .. "%s (Need - %d, Main-Spec) Won: %s"
_G.LOOT_ROLL_WON_NO_SPAM_NEED_OFF_SPEC = HISTORY .. "%s (Need - %d, Off-Spec) Won: %s"
_G.LOOT_ROLL_YOU_WON_NO_SPAM_GREED = HISTORY .. "You (Greed - %d) Won: %s"
_G.LOOT_ROLL_WON_NO_SPAM_GREED = HISTORY .. "%s (Greed - %d) Won: %s"
_G.LOOT_ROLL_ROLLED_NEED = HISTORY .. "Need Roll - %d for %s by %s"
_G.LOOT_ROLL_ROLLED_NEED_ROLE_BONUS = "Need Roll - %d for %s by %s + Role Bonus"
_G.LOOT_ROLL_LOST_ROLL = HISTORY .. "You have rolled %s - %d for: %s"
_G.LOOT_ROLL_NEED_SELF = HISTORY .. "You have selected Need for: %s"
_G.LOOT_ROLL_NEED_SELF_OFF_SPEC = HISTORY .. "You have selected Need for: %s"
_G.LOOT_ROLL_NEED = HISTORY .. "%s has selected Need for: %s"
_G.LOOT_ROLL_YOU_WON = HISTORY .. "You won: %s"
_G.LOOT_ROLL_WON = HISTORY .. "%s won: %s"

local function Link(id, name, quality)
    return ("|cnIQ%d:|Hitem:%d::::::::16:1491::::::::|h[%s]|h|r"):format(quality, id, name)
end
local CHEST = Link(271098, "Golemguard Chest", 3)   -- Plunder's
local BLUE = Link(990001, "Invented Blue Band", 3)  -- off no table
local GREEN = Link(990002, "Invented Green Boots", 2)
local GREY = Link(990003, "Invented Grey Rag", 0)

local function Say(text) T.Whisper("CHAT_MSG_LOOT", text, "") end
local function H(id, fmt, ...) return (fmt:gsub("%%d", tostring(id), 1)):format(...) end

local function In(name, id)
    mock.inInstance, mock.instanceName, mock.instanceID = true, name, id
    mock.fire("ZONE_CHANGED_NEW_AREA")
end

mock.now = 1792073000
mock.timers = {}
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.RunTimers()

--------------------------------------------------------------------------
Section("the client's sentences are read through its own strings")

-- Before the run: no visit, nothing kept.
Say(H(1, _G.LOOT_ROLL_LOST_ROLL, "Need", 80, CHEST))
Eq(#Instances.All(), 0, "a roll outside a run made a visit")

In("The Hall of Thanes", 3065)
local visit = Instances.Current()
Check(visit ~= nil, "no run opened")

-- Quiet loot: the user's own roll, then the winner's.
Say(H(7, _G.LOOT_ROLL_LOST_ROLL, "Need", 80, CHEST))
mock.now = mock.now + 2
Say(H(7, _G.LOOT_ROLL_WON_NO_SPAM_NEED, "Bram", 85, CHEST))
Eq(#(visit.rolls or {}), 1, "one drop, told twice")
local drop = visit.rolls[1]
Eq(drop.key, 7, "the drop's loot history id")
Eq(drop.itemID, 271098, "the item")
Eq(drop.need[ME], 80, "the user's Need roll")
Eq(drop.winner, STRANGER.guid, "Bram won")
Eq(drop.winRoll, 85, "with 85")
Eq(drop.winNeed, true, "on Need")
Eq(#visit.loot, 0, "a roll line is not loot")

-- A Greed roll of the user's keeps nothing.
Say(H(8, _G.LOOT_ROLL_LOST_ROLL, "Greed", 50, GREEN))
Eq(#visit.rolls, 1, "a Greed roll made a drop")

-- Everyone's rolls (the quiet setting off).
mock.now = mock.now + 30
Say(H(9, _G.LOOT_ROLL_NEED, "Bram", GREEN))
Say(H(9, _G.LOOT_ROLL_ROLLED_NEED, 2, GREEN, "Bram"))
Say(H(9, _G.LOOT_ROLL_ROLLED_NEED, 64, GREEN, F.SELF.name[1]))
Say(H(9, _G.LOOT_ROLL_YOU_WON, GREEN))
Eq(#visit.rolls, 2, "the second drop")
drop = visit.rolls[2]
Eq(drop.need[STRANGER.guid], 2, "Bram's roll, after his choice")
Eq(drop.need[ME], 64, "the user's roll, by their name")
Eq(drop.winner, ME, "the user won")
Eq(drop.winRoll, nil, "a win line without a roll gives no roll")

-- A stranger outside the run is not kept.
Say(H(10, _G.LOOT_ROLL_ROLLED_NEED, 1, GREEN, "Nobody"))
Eq(#visit.rolls, 2, "a roll by someone not in the run")

-- Plain loot still reads after the roll lines.
Say("You receive loot: " .. GREEN .. ".")
Eq(#visit.loot, 0, "a green off no table is not loot (as before)")

--------------------------------------------------------------------------
Section("the loot history: every roll by GUID, matched to the chat's drop")

_G.Enum = _G.Enum or {}
Enum.EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
_G.C_LootHistory = { GetSortedInfoForDrop = function(encounterID, lootListID)
    if encounterID ~= 3495 then return nil end
    return { itemHyperlink = CHEST, rollInfos = {
        { playerGUID = STRANGER.guid, roll = 85, state = 0, isWinner = true },
        { playerGUID = ME, roll = 80, state = 1 },
    } }
end }
mock.fire("LOOT_HISTORY_UPDATE_DROP", 3495, 2)
Eq(#visit.rolls, 2, "the history's drop is the chat's, not a third")
Eq(visit.rolls[1].hkey, "h3495:2", "the history's key kept beside the chat's")
Eq(visit.rolls[1].need[ME], 80, "the roll agrees")
mock.fire("LOOT_HISTORY_UPDATE_DROP", 3495, 2)
Eq(#visit.rolls, 2, "told again, the same drop")

--------------------------------------------------------------------------
Section("what the map makes of them (the user's rules)")

local rolls = Run.Rolls(visit)
Eq(#rolls.snagged, 1, "the chest was snagged from the user")
Eq(rolls.snagged[1].mine, 80, "the user's roll")
Eq(rolls.snagged[1].theirs, 85, "Bram's")
Eq(rolls.snagged[1].winner, STRANGER.guid, "by Bram")
Eq(rolls.snagged[1].boss and rolls.snagged[1].boss.name, "Plunder", "at Plunder, whose table holds it")
Eq(#rolls.bad, 1, "one bad roll")
Eq(rolls.bad[1].guid, STRANGER.guid, "Bram's 2")
Eq(rolls.bad[1].roll, 2, "his roll")
Eq(rolls.bad[1].boss, nil, "the green is off no table")

-- The edges: a gap of 16 is not snagged; 15 is. A Greed winner, a grey,
-- or a green lost close are not snagged; a grey's roll of 1 is no strip.
local function Case(mine, theirs, quality, winNeed)
    return { rolls = { { itemID = 1, item = Link(1, "X", quality), need = { [ME] = mine },
        winner = STRANGER.guid, winRoll = theirs, winNeed = winNeed } }, me = ME, instanceID = 3065 }
end
Eq(#Run.Rolls(Case(60, 75, 3, true)).snagged, 1, "lost by 15")
Eq(#Run.Rolls(Case(60, 76, 3, true)).snagged, 0, "lost by 16")
Eq(#Run.Rolls(Case(60, 75, 4, true)).snagged, 1, "an epic")
Eq(#Run.Rolls(Case(60, 70, 2, true)).snagged, 0, "a green is never snagged")
Eq(#Run.Rolls(Case(60, 70, 3, nil)).snagged, 0, "a Greed winner did not snag it")
Eq(#Run.Rolls(Case(3, 70, 2, true)).bad, 1, "the user's own 3 on a green")
Eq(#Run.Rolls(Case(4, 70, 2, true)).bad, 0, "a 4 is not bad")
Eq(#Run.Rolls(Case(1, 70, 1, true)).bad, 0, "a white's roll is no strip")
local choice = Case(60, 70, 3, true)
choice.rolls[1].need[ME] = true
Eq(#Run.Rolls(choice).snagged, 0, "a Need with no number said")

--------------------------------------------------------------------------
Section("finally: an item lost on an earlier run comes to the user")

-- Two earlier runs: the chest went to Bram on a roll the user needed, and
-- once more to Bram with no roll kept. Today it drops for the user.
local first = Instances.New({ me = ME, instanceID = 3065, startedAt = visit.startedAt - 7 * 86400,
    members = {}, loot = { { guid = STRANGER.guid, item = CHEST, itemID = 271098, time = 1 } },
    rolls = { { key = 3, item = CHEST, itemID = 271098, time = 1, need = { [ME] = 40, [STRANGER.guid] = 90 },
        winner = STRANGER.guid, winRoll = 90, winNeed = true } } })
Instances.New({ me = ME, instanceID = 3065, startedAt = visit.startedAt - 2 * 86400, members = {},
    loot = { { guid = STRANGER.guid, item = CHEST, itemID = 271098, time = 2 } } })
-- Another character's run is not the user's.
Instances.New({ me = "Player-4620-00FFFFFF", instanceID = 3065, startedAt = visit.startedAt - 86400,
    members = {}, loot = { { guid = STRANGER.guid, item = CHEST, itemID = 271098, time = 3 } } })

Eq(#Run.Rolls(visit).finally, 0, "nothing came to the user yet")
Say("You receive loot: " .. CHEST .. ".")
local finally = Run.Rolls(visit).finally
Eq(#finally, 1, "the chest finally came")
Eq(finally[1].itemID, 271098, "the chest")
Eq(finally[1].before, 2, "every earlier drop the user saw, once each")
Eq(finally[1].total, 3, "and this one")
Eq(finally[1].boss and finally[1].boss.name, "Plunder", "at Plunder")

-- Without the lost roll it is only loot.
first.rolls[1].winner = ME
Eq(#Run.Rolls(visit).finally, 0, "won before, so not 'finally'")
first.rolls[1].winner = STRANGER.guid

--------------------------------------------------------------------------
Section("forgetting someone takes their rolls (PRV-3)")

Instances.Forget(STRANGER.guid)
Eq(visit.rolls[1].need[STRANGER.guid], nil, "Bram's roll stays")
Eq(visit.rolls[1].winner, nil, "Bram stays the winner")
Eq(visit.rolls[1].winRoll, nil, "his winning roll stays")
Eq(visit.rolls[1].need[ME], 80, "the user's own roll went too")
