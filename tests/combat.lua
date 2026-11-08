-- Your Diary's fights in more depth: the close calls (JRN-25), and how
-- many kills a quest's drops took (JRN-26), told as bad luck when they
-- took far too many.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local J, R, Combat = ns.Journey, ns.JourneyRecap, ns.Hunts
local SELF, STRANGER = F.SELF, F.STRANGER

local STRIDER1 = "Creature-0-4615-1-832-2955-00004B69A3"
local STRIDER2 = "Creature-0-4615-1-832-2955-00004B69A4"
local STRIDER3 = "Creature-0-4615-1-832-2955-00004B69A5"
local WOLF = "Creature-0-4615-1-832-2958-00004B6A01"
local CHIEF = "Creature-0-4615-1-832-3035-00004B6B01"
local MEAT = "|cffffffff|Hitem:4739::::::::5:::::|h[Plainstrider Meat]|h|r"
local SHELLS = "|cff9d9d9d|Hitem:5134::::::::5:::::|h[Cracked Egg Shells]|h|r"

local function Mob(guid, name, extra)
    local def = { guid = guid, name = { name }, isPlayer = false, hostile = true }
    for key, value in pairs(extra or {}) do def[key] = value end
    return def
end

-- The client's damage meter: sessions by id, each with the user's damage
-- taken and the heals done, { from (GUID), to (unit name), amount }. A
-- value can be made secret (in combat). A heal's spell row lists its
-- target as one struct, the shape where the row's total is the number.
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
            return { combatSources = { { isLocalPlayer = false, totalAmount = 999 },
                { isLocalPlayer = true, totalAmount = s.taken } } }
        end
        local sources, seen = {}, {}
        for _, heal in ipairs(s.heals) do
            if not seen[heal.from] then
                seen[heal.from] = true
                sources[#sources + 1] = { sourceGUID = heal.from, isLocalPlayer = heal.from == SELF.guid }
            end
        end
        return { combatSources = sources }
    end,
    GetCombatSessionSourceFromID = function(id, kind, guid)
        local spells = {}
        for _, heal in ipairs(meter.sessions[id].heals) do
            if heal.from == guid then
                spells[#spells + 1] = heal.list
                    and { totalAmount = heal.amount, combatSpellDetails = heal.list }
                    or { totalAmount = heal.amount, combatSpellDetails = { unitName = heal.to, amount = 0 } }
            end
        end
        return { combatSpells = spells }
    end,
}

-- A fight, its targets, and the health it would have left from full
-- (100): the meter's damage taken. `opts.session` carries on that
-- session rather than opening the next; `opts.healed` is the user's own
-- healing on themselves in it, `opts.heals` more heals.
local nextSession = 0
local function Fight(targets, left, opts)
    opts = opts or {}
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
    for _, def in ipairs(targets) do
        mock.SetUnit("target", def)
        mock.fire("PLAYER_TARGET_CHANGED")
    end
    mock.now = mock.now + 40
    local id = opts.session
    if not id then
        nextSession = nextSession + 1
        id = nextSession
    end
    local s = meter.sessions[id] or { taken = 0, heals = {} }
    meter.sessions[id] = s
    s.taken = s.taken + (100 - left)
    if opts.healed then s.heals[#s.heals + 1] = { from = SELF.guid, to = "Ulverston Nye", amount = opts.healed } end
    for _, heal in ipairs(opts.heals or {}) do s.heals[#s.heals + 1] = heal end
    if opts.secret then s.taken = mock.secret(s.taken) end
    -- A duel's result comes before combat ends (SD_DUEL_FINISHED).
    if opts.duel then ns.Fire("SD_DUEL_FINISHED", STRANGER.guid, opts.duel) end
    mock.inCombat = false
    mock.SetUnit("target", nil)
    mock.fire("PLAYER_REGEN_ENABLED")
    mock.RunTimers()
    return id
end

mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
local j = J.Mine()
Check(j, "setup: no route")

--------------------------------------------------------------------------
Section("a close call: a fight that took all but a little of the health")

Eq(ns.CloseCalls.Is(90, 100), true, "90% taken is a close call")
Eq(ns.CloseCalls.Is(89, 100), false, "89% is not")
Eq(ns.CloseCalls.Is(130, 100), true, "more than all of it, healed through")
Eq(ns.CloseCalls.Is(95, 0), false, "no maximum")

Fight({ Mob(STRIDER1, "Plainstrider") }, 50)
Eq(#ns.CloseCalls.List(j), 0, "half the health taken was a close call")
-- Any foe's name read off a unit is kept a while (CreatureNames.Note), for
-- a death recap that gives its kind a surname.
Eq(j.names and j.names[2955] and j.names[2955][1], "Plainstrider", "a foe's name read off its target was not kept")

local before = mock.now
Fight({ Mob(STRIDER1, "Plainstrider"), Mob(WOLF, "Prairie Wolf"), Mob(STRIDER2, "Plainstrider") }, 6)
local call = ns.CloseCalls.List(j)[1]
Check(call, "94% taken was no close call")
Eq(call.pct, 6, "the health left")
Eq(call.took, 94, "the damage taken")
Eq(call.npcID, 2955, "the creature fought most")
Eq(call.name, "Plainstrider", "its name")
Eq(call.foes, 3, "how many were fought")
Eq(call.seconds, 40, "how long the fight was")
Eq(call.mapID, mock.mapID, "where it ended")
Check(call.t >= before, "when")

-- In a battleground or an arena nothing is judged; out again, it is.
do
    mock.inInstance = true
    for _, kind in ipairs({ "pvp", "arena" }) do
        mock.instanceType = kind
        Fight({ Mob(STRIDER1, "Plainstrider") }, 3)
        Eq(#ns.CloseCalls.List(j), 1, "a close call kept in a " .. kind .. " instance")
    end
    mock.inInstance, mock.instanceType = false, "party"
    Fight({ Mob(STRIDER1, "Plainstrider") }, 3)
    Eq(#ns.CloseCalls.List(j), 2, "no close call after leaving the battleground")
    -- Back to one, so the counts below stay as they were.
    table.remove(j.closeCalls)
end

-- The same creature targeted twice is one foe; one foe keeps no count.
Fight({ Mob(STRIDER3, "Plainstrider"), Mob(STRIDER3, "Plainstrider") }, 1)
Eq(ns.CloseCalls.List(j)[2].foes, nil, "one foe was counted as more")
Eq(ns.CloseCalls.List(j)[2].pct, 1, "1% left")

-- An elite keeps its rank.
Fight({ Mob(CHIEF, "Kolkar Chief", { classification = "elite", level = 14 }) }, 8)
Eq(ns.CloseCalls.List(j)[3].rank, "elite", "the elite's rank")
Eq(ns.CloseCalls.List(j)[3].foeLevel, 14, "the elite's level")
Fight({ Mob(CHIEF, "Kolkar Chief", { classification = "worldboss", level = -1 }) }, 8)
Eq(ns.CloseCalls.List(j)[4].foeLevel, -1, "the skull")
table.remove(j.closeCalls)

-- A fight nobody was targeted in keeps no creature.
Fight({}, 4)
Eq(ns.CloseCalls.List(j)[4].npcID, nil, "a creature made up")
Eq(ns.CloseCalls.List(j)[4].name, nil, "a name made up")

-- Dead is no close call, though the fight ended.
mock.dead = true
Fight({ Mob(STRIDER1, "Plainstrider") }, 0)
mock.dead = false
Eq(#ns.CloseCalls.List(j), 4, "a death was a close call")

-- More damage than there was health: healing carried the user through.
Fight({ Mob(STRIDER1, "Plainstrider") }, -30)
Eq(ns.CloseCalls.List(j)[5].pct, 1, "healed through is 1% from full")
Eq(ns.CloseCalls.List(j)[5].took, 130, "the damage taken past the maximum")
table.remove(j.closeCalls)

-- The user's own healing, alone, is taken off the damage.
Fight({ Mob(STRIDER1, "Plainstrider") }, -10, { healed = 30 })
Eq(#ns.CloseCalls.List(j), 4, "a fight healed through by oneself was a close call")
Fight({ Mob(STRIDER1, "Plainstrider") }, 5, { healed = 0 })
Eq(#ns.CloseCalls.List(j), 5, "setup: a close call with no healing")
table.remove(j.closeCalls)

-- A group's healers: what they put on the user is taken off; what they
-- put on others, and the user's heals on others, are not. The meter's
-- name for the user is told by the first name.
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
Fight({ Mob(STRIDER1, "Plainstrider") }, -20, { heals = {
    { from = STRANGER.guid, to = "Ulverston", amount = 115 },
    { from = STRANGER.guid, to = "Bram", amount = 500 },
    { from = SELF.guid, to = "Bram", amount = 300 } } })
Eq(#ns.CloseCalls.List(j), 4, "a fight a healer carried was a close call")
Fight({ Mob(STRIDER1, "Plainstrider") }, -20, { heals = {
    { from = STRANGER.guid, to = "Ulverston", amount = 25 },
    { from = SELF.guid, to = "Bram", amount = 300 } } })
Eq(#ns.CloseCalls.List(j), 5, "healing on others was taken off")
Eq(ns.CloseCalls.List(j)[5].pct, 5, "the healer's heals on the user, taken off")
table.remove(j.closeCalls)
Fight({ Mob(STRIDER1, "Plainstrider") }, -40, { heals = {
    { from = STRANGER.guid, amount = 60, list = { { unitName = "Ulverston Nye", amount = 45 },
        { unitName = "Bram Redfen", amount = 15 } } } } })
Eq(#ns.CloseCalls.List(j), 5, "a heal on a list of targets was not read by its share")
Eq(ns.CloseCalls.List(j)[5].pct, 5, "the user's share of the list")
table.remove(j.closeCalls)
mock.groupSize = 0
mock.fire("GROUP_ROSTER_UPDATE")

-- One session over several fights: each counts what it added.
local long = Fight({ Mob(STRIDER1, "Plainstrider") }, 60)
Fight({ Mob(STRIDER1, "Plainstrider") }, 55, { session = long })
Eq(#ns.CloseCalls.List(j), 4, "two fights in one session were added together")
Fight({ Mob(STRIDER1, "Plainstrider") }, 7, { session = long })
Eq(#ns.CloseCalls.List(j), 5, "the third fight in the session was not one")
Eq(ns.CloseCalls.List(j)[5].pct, 7, "the third fight's own damage")
table.remove(j.closeCalls)

-- The meter still secret as combat ends: read again a moment later.
do
    local id = Fight({ Mob(STRIDER1, "Plainstrider") }, 5, { secret = true })
    Eq(#ns.CloseCalls.List(j), 4, "a secret was read")
    meter.sessions[id].taken = 95
    mock.RunTimers()
    Eq(#ns.CloseCalls.List(j), 5, "the meter was not read again")
    table.remove(j.closeCalls)
end

-- The route not kept: nothing.
ns.db.settings.keepRoute = false
Fight({ Mob(STRIDER1, "Plainstrider") }, 3)
ns.db.settings.keepRoute = true
Eq(#ns.CloseCalls.List(j), 4, "a close call kept with the route off")
Fight({ Mob(STRIDER1, "Plainstrider") }, 4)
Eq(#ns.CloseCalls.List(j), 5, "setup: a fifth")
table.remove(j.closeCalls)

-- A duel lost ends at 1 hp by the rules: no close call, no fight
-- survived. Its damage is still read off the meter, so the next fight in
-- the session counts only its own (50 of 100: no close call either).
do
    local survived = 0
    ns.On("SD_FIGHT_SURVIVED", function() survived = survived + 1 end)
    local duel = Fight({}, 1, { duel = "lost" })
    Eq(#ns.CloseCalls.List(j), 4, "a lost duel was a close call")
    Eq(survived, 0, "a duel was told as a fight survived")
    Fight({ Mob(STRIDER1, "Plainstrider") }, 50, { session = duel })
    Eq(#ns.CloseCalls.List(j), 4, "the duel's damage was counted in the next fight")
    Eq(survived, 1, "the next fight was not told")
    -- The duel's mark goes with its fight: the next is judged again.
    Fight({ Mob(STRIDER1, "Plainstrider") }, 4)
    Eq(#ns.CloseCalls.List(j), 5, "a fight after a duel was left too")
    table.remove(j.closeCalls)
    -- Fleeing, combat can end long before the "fled" line (probe, 15 Oct:
    -- 18 s): a fight that ends while a duel is on is the duel's.
    ns.Fire("SD_DUEL_STARTED", STRANGER.guid)
    Fight({}, 2)
    Eq(#ns.CloseCalls.List(j), 4, "a fight in a duel not yet over was a close call")
    mock.now = mock.now + 18
    ns.Fire("SD_DUEL_FINISHED", STRANGER.guid, "fled")
    Fight({ Mob(STRIDER1, "Plainstrider") }, 4)
    Eq(#ns.CloseCalls.List(j), 5, "a fight after a flight was left too")
end

--------------------------------------------------------------------------
Section("what an objective wants")

local function Parsed(text)
    local item, have, need = Combat.Parse(text)
    return ("%s|%s|%s"):format(tostring(item), tostring(have), tostring(need))
end
Eq(Parsed("Plainstrider Meat: 3/7"), "Plainstrider Meat|3|7", "the usual form")
Eq(Parsed("3/7 Plainstrider Meat"), "Plainstrider Meat|3|7", "the count first")
Eq(Parsed("Plainstrider Meat"), "Plainstrider Meat|nil|nil", "no count")

--------------------------------------------------------------------------
Section("a hunt: the kills a quest's drops took")

local MEAT_QUEST = { questID = 781, title = "Break Sharptusk!", objectives = {
    { text = "Plainstrider Meat: 0/2", type = "item", numFulfilled = 0, numRequired = 2, finished = false },
    { text = "Kolkar Chief slain: 0/1", type = "monster", numFulfilled = 0, numRequired = 1, finished = false },
} }
local HALF_DONE = { questID = 782, title = "Half Done", objectives = {
    { text = "Wolf Pelt: 1/5", type = "item", numFulfilled = 1, numRequired = 5, finished = false },
} }
mock.quests = { MEAT_QUEST, HALF_DONE }
mock.fire("QUEST_ACCEPTED", 781)
mock.RunTimers()
local hunt = ns.Hunts.Hunting(j, 781, 1)
Check(hunt, "the item objective is not being counted")
Eq(hunt.item, "Plainstrider Meat", "the item")
Eq(hunt.need, 2, "how many")
Eq(hunt.title, "Break Sharptusk!", "the quest")
Eq(ns.Hunts.Hunting(j, 781, 2), nil, "a kill objective is counted")
Eq(ns.Hunts.Hunting(j, 782, 1), nil, "a want already under way is counted from the middle")

-- Kills: the user's and their group's, every kind.
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
mock.SetUnit("target", Mob(STRIDER1, "Plainstrider"))
for _ = 1, 9 do mock.fire("PARTY_KILL", SELF.guid, STRIDER1) end
for _ = 1, 3 do mock.fire("PARTY_KILL", STRANGER.guid, STRIDER2) end
mock.fire("PARTY_KILL", SELF.guid, WOLF)
mock.fire("PARTY_KILL", "Player-4615-0BBBBBBB", STRIDER3)
Eq(hunt.kills[2955], 12, "the kills of the kind")
Eq(hunt.kills[2958], 1, "another kind's")
Eq(hunt.names[2955], "Plainstrider", "the kind's name off the target")

-- The loot window: the meat came off a Plainstrider (the probe's own loot).
mock.loot = { { link = MEAT, sources = { STRIDER1, 1 } }, { link = SHELLS, sources = { STRIDER1, 1 } } }
mock.fire("LOOT_OPENED")
Eq(hunt.from[2955], true, "the meat's source")
Eq(hunt.from[2958], nil, "a kind that dropped nothing")

MEAT_QUEST.objectives[1].numFulfilled = 1
MEAT_QUEST.objectives[1].text = "Plainstrider Meat: 1/2"
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
Check(ns.Hunts.Hunting(j, 781, 1), "a hunt ended with one of two")

mock.fire("PARTY_KILL", SELF.guid, STRIDER1)
MEAT_QUEST.objectives[1].numFulfilled = 2
MEAT_QUEST.objectives[1].finished = true
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
Eq(ns.Hunts.Hunting(j, 781, 1), nil, "the hunt did not end with both")
local done = ns.Hunts.List(j)[1]
Check(done, "the hunt kept nothing")
Eq(done.kills, 13, "kills of the kind that dropped it, the group's too")
Eq(done.need, 2, "how many it wanted")
Eq(done.npcID, 2955, "the kind")
Eq(done.name, "Plainstrider", "its name")
Eq(done.item, "Plainstrider Meat", "the item")
Eq(done.itemID, 4739, "the item's id, off its loot link, for its icon")
Eq(done.title, "Break Sharptusk!", "the quest")
Eq(done.mapID, mock.mapID, "where the last came")
Eq(ns.Hunts.BadLuck(j, done), true, "13 kills for 2 was not bad luck")

-- A quest abandoned gives its hunt up, once its turn-in had the chance.
local PELTS = { questID = 790, title = "Pelts", objectives = {
    { text = "Wolf Pelt: 0/4", type = "item", numFulfilled = 0, numRequired = 4, finished = false } } }
mock.quests = { PELTS }
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
Check(ns.Hunts.Hunting(j, 790, 1), "setup: pelts not counted")
mock.quests = {}
mock.fire("QUEST_REMOVED", 790)
Check(ns.Hunts.Hunting(j, 790, 1), "given up before the turn-in could come")
mock.RunTimers()
Eq(ns.Hunts.Hunting(j, 790, 1), nil, "an abandoned quest still counted")
Eq(#ns.Hunts.List(j), 1, "an abandoned quest kept a hunt")

-- Handed in before the log said it was met: the turn-in ends it.
mock.quests = { PELTS }
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
mock.loot = { { link = "|Hitem:7073|h[Wolf Pelt]|h", sources = { WOLF, 1 } } }
mock.fire("PARTY_KILL", SELF.guid, WOLF)
mock.fire("LOOT_OPENED")
mock.quests = {}
mock.fire("QUEST_TURNED_IN", 790)
mock.fire("QUEST_REMOVED", 790)
mock.RunTimers()
Eq(#ns.Hunts.List(j), 2, "the turn-in did not end the hunt")
Eq(ns.Hunts.List(j)[2].kills, 1, "the pelts' kills")
Eq(ns.Hunts.BadLuck(j, ns.Hunts.List(j)[2]), false, "one kill for four was bad luck")

-- Items that never came off a creature keep nothing.
mock.quests = { PELTS }
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
mock.fire("PARTY_KILL", SELF.guid, WOLF)
mock.fire("QUEST_TURNED_IN", 790)
Eq(#ns.Hunts.List(j), 2, "a hunt with no source kept")

-- A crafted item whose name holds its raw material's: the hides looted
-- off the beasts are not the cured hides, so the beasts are no source,
-- and the crafting that met the want keeps nothing (6 Nov, in the client:
-- 43 Plainstriders and Zhevra for 2 Cured Light Hides).
local CURED = { questID = 791, title = "Beasts of Thunder Ridge", objectives = {
    { text = "Cured Light Hides: 0/2", type = "item", numFulfilled = 0, numRequired = 2, finished = false } } }
mock.quests = { CURED }
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
local cured = ns.Hunts.Hunting(j, 791, 1)
Check(cured, "setup: the cured hides not counted")
mock.loot = { { link = "|Hitem:783|h[Light Hide]|h", sources = { STRIDER1, 1 } } }
mock.fire("PARTY_KILL", SELF.guid, STRIDER1)
mock.fire("LOOT_OPENED")
Eq(cured.from[2955], nil, "a raw material's name inside the objective's made its creature a source")
mock.loot = { { link = "|Hitem:4231|h[Cured Light Hide]|h", sources = { WOLF, 1 } } }
mock.fire("PARTY_KILL", SELF.guid, WOLF)
mock.fire("LOOT_OPENED")
Eq(cured.from[2958], true, "the objective's plural did not match the item's name")
Eq(cured.itemID, nil, "a plural match took the item's id")
cured.from[2958] = nil
CURED.objectives[1].numFulfilled, CURED.objectives[1].finished = 2, true
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
Eq(ns.Hunts.Hunting(j, 791, 1), nil, "the met want did not end the hunt")
Eq(#ns.Hunts.List(j), 2, "a crafted want kept a hunt")
mock.quests = {}
mock.fire("QUEST_REMOVED", 791)
mock.RunTimers()

-- By id where both are known: a hunt that knows its item (QuestieDB) takes
-- no other item by name, and takes its own under any name.
do
    local hunt = ns.Hunts.Begin(j, { questID = 792, index = 1, title = "Ids", item = "Cured Light Hides",
        need = 2, t = mock.now, itemID = 4231 })
    Eq(ns.Hunts.Same(hunt, "Cured Light Hide", 783), false, "another id matched by name")
    Eq(ns.Hunts.Same(hunt, "Cured Leather", 4231), true, "the hunt's id did not match under another name")
    Eq(ns.Hunts.Same(hunt, "Cured Light Hide", nil), true, "a link with no id did not match by name")
    Eq(ns.Hunts.Same(hunt, "Hides", nil), false, "a fragment at the end matched")
    Eq(ns.Hunts.Same(hunt, "Cured Light Hides", nil), true, "the same name did not match")
    ns.Hunts.Gone(j, 792)
end

-- A hunt open too long is given up at login.
mock.quests = { PELTS }
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
ns.Hunts.Hunting(j, 790, 1).since = mock.now - ns.Hunts.T.huntAge - 1
J.Prune(mock.now)
Eq(ns.Hunts.Hunting(j, 790, 1), nil, "a month-old hunt kept")

-- A creature's name from the hunts, where none was read lately (j.names)
-- and no QuestieDB says it: their list is registered `readNames` with a
-- reading of its own (Features/Hunts/Kind.lua), as CreatureNames.Of reads
-- them before they moved: the finished hunts oldest first (a list's
-- default is newest first), then the hunts under way.
do
    local names, hunts, hunting = j.names, j.hunts, j.hunting
    j.names = nil
    j.hunts = { { t = 1, npcID = 4901, name = "Plainstrider" }, { t = 2, npcID = 4901, name = "Elder Plainstrider" } }
    j.hunting = { ["1:1"] = { names = { [4902] = "Kolkar Marauder" } } }
    Eq(ns.CreatureNames.Of(j, 4901), "Plainstrider", "two hunts of one creature not read oldest first")
    Eq(ns.CreatureNames.Of(j, 4902), "Kolkar Marauder", "a hunt under way did not name its creature")
    Eq(ns.CreatureNames.Of(j, 4903), nil, "a creature no hunt kept named")
    j.names, j.hunts, j.hunting = names, hunts, hunting
end

--------------------------------------------------------------------------
Section("bad luck, against the character's usual")

local function Hunt(kills, need)
    return { kills = kills, need = need }
end
local k = { hunts = {} }
Eq(ns.Hunts.BadLuck(k, Hunt(9, 2)), false, "fewer than eight extra kills")
Eq(ns.Hunts.BadLuck(k, Hunt(10, 2)), true, "eight extra, five an item")
Eq(ns.Hunts.BadLuck(k, Hunt(20, 8)), false, "two and a half an item")
Eq(ns.Hunts.BadLuck(k, Hunt(24, 8)), true, "three an item")
-- A character whose drops always take long: twice its usual, or no luck.
for _ = 1, 5 do k.hunts[#k.hunts + 1] = Hunt(16, 4) end
Eq(ns.Hunts.UsualLuck(k), 4, "the usual")
Eq(ns.Hunts.BadLuck(k, Hunt(28, 4)), false, "under twice the usual")
Eq(ns.Hunts.BadLuck(k, Hunt(32, 4)), true, "twice the usual")

--------------------------------------------------------------------------
Section("on the plates")

local ctx = { sessions = {}, notes = {}, visits = {} }
local e = R.Gather(j, 0, mock.now + 1, ctx)
Eq(#e.closeCalls, 5, "the close calls in the entry")
Eq(#e.hunts, 1, "only the bad luck goes in")
local kinds = {}
for _, m in ipairs(R.Moments(j, e, ctx)) do kinds[m.kind] = (kinds[m.kind] or 0) + 1 end
Eq(kinds.close, 5, "close-call moments")
Eq(kinds.luck, 1, "bad-luck moments")
Eq(R.Rank({ kind = "close" }), R.RANK.death, "a close call ranks with a death")
Eq(R.Rank({ kind = "luck" }), R.RANK.death, "bad luck ranks with a death")
