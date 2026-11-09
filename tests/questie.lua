-- Questie and its database as sources (.claude/addon-integrations.md):
-- real creature names (EXT-1), every kind that drops a quest's item and
-- how many kills it should have taken (EXT-2), good luck (EXT-3), and the
-- chain finales the user chose (JRN-28), which need no other addon.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local J, R, Text, Q = ns.Journey, ns.JourneyRecap, ns.UI.JourneyText, ns.QuestieBridge
local SELF, STRANGER = F.SELF, F.STRANGER
local NB = "\194\160"
local OPEN, CLOSE = "\226\128\156", "\226\128\157"

local STRIDER = "Creature-0-4615-1-832-2955-00004B69A3"
local ADULT = "Creature-0-4615-1-832-2956-00004B69B1"
local WOLF = "Creature-0-4615-1-832-2958-00004B6A01"
local MEAT = "|cffffffff|Hitem:4739::::::::5:::::|h[Plainstrider Meat]|h|r"

-- QuestieDB as its contract 3 has it: entities read by field name, the
-- drop tables in its support data (wowhead and cmangos as Lua text, the
-- corrections a live table). `db.locale` is the language its names are
-- in; GetRaw gives the English.
local db = {
    npc = { [2955] = "Plainstrider", [2956] = "Adult Plainstrider", [3108] = "Encrusted Surf Crawler",
        [474] = "Defias Rogue Wizard" },
    german = { [2955] = "Ebenenschreiter" },
    items = { [4739] = { name = "Plainstrider Meat", npcDrops = { 2956, 2955 } },
        [5001] = { name = "Gnoll Paw", npcDrops = { 98 } }, [5002] = { name = "Gnoll Tooth", npcDrops = { 98 } },
        [1019] = { name = "Red Linen Bandana", npcDrops = { 474 } } },
    quests = { [781] = { objectives = { nil, nil, { { 4739, nil, 0 } } } },
        [800] = { objectives = { nil, nil, { { 5001 }, { 5002 } } } },
        [83] = { objectives = { nil, nil, { { 1019 } } } } },
}
local function Entity(get)
    return {
        Get = function(id, field) return get(id, field, false) end,
        GetRaw = function(id, field) return get(id, field, true) end,
    }
end
local function Bring()
    _G.LibQuestieDB = {
        RequireContract = function(v) return v >= 1 and v <= 3 end,
        Npc = Entity(function(id, field, raw)
            if field ~= "name" then return nil end
            if not raw and db.locale == "deDE" then return db.german[id] or db.npc[id] end
            return db.npc[id]
        end),
        Item = Entity(function(id, field) local item = db.items[id]; return item and item[field] end),
        Quest = Entity(function(id, field) local quest = db.quests[id]; return quest and quest[field] end),
        Support = { Get = function(name)
            if name == "QuestieClassicItemDrops" then
                -- The bandana as QuestieDB has it (12 Oct): 66% for every
                -- Defias in the server data, 37% on Wowhead.
                return { wowheadData = "return { [4739] = { [2955] = 30.0, [2956] = 40.0 }, [5001] = { [98] = 10.0 },"
                        .. " [1019] = { [474] = 36.9752 } }",
                    cmangosData = "return { [4739] = { [2955] = 25.0, [2956] = 50.0 }, [5002] = { [98] = 0 },"
                        .. " [1019] = { [474] = 66.0 } }" }
            end
            if name == "QuestieItemDropCorrections" then
                return { Era = { [5001] = { [98] = -1 }, [5003] = { [98] = 60.0 } } }
            end
        end },
    }
    Q.Reset()
end
local function Away()
    _G.LibQuestieDB, _G.QuestieLoader = nil, nil
    Q.Reset()
end

--------------------------------------------------------------------------
Section("QuestieDB, read through the bridge")

Away()
Eq(Q.On(), false, "on without QuestieDB")
Eq(Q.NpcName(2955), nil, "a name without QuestieDB")
Eq(Q.DropRate(4739, 2955), nil, "a rate without QuestieDB")
Bring()
Eq(Q.On(), true, "off with QuestieDB")
Eq(Q.Status(), "on", "the settings' status with QuestieDB")
_G.LibQuestieDB.RequireContract = function(v) return v <= 2 end
Eq(Q.On(), false, "on with a contract too old")
Eq(Q.Status(), "old", "the settings' status with a contract too old")
Away()
Eq(Q.Status(), "off", "the settings' status without either")
_G.Questie = {}
Eq(Q.Status(), "old", "Questie without its database")
_G.Questie = nil
Bring()

Eq(Q.NpcName(2955), "Plainstrider", "a creature's name")
Eq(Q.NpcName(99999), nil, "an unknown creature")
mock.locale = "deDE"
local GetLocale = _G.GetLocale
_G.GetLocale = function() return "deDE" end
db.locale = "deDE"
Q.Reset()
Eq(Q.NpcName(2955), "Ebenenschreiter", "a translated name")
Eq(Q.NpcName(2956), nil, "an English name on a German client")
_G.GetLocale, db.locale = GetLocale, nil
Q.Reset()

Eq(Q.ItemFor(781, "Plainstrider Meat"), 4739, "the item by its name")
Eq(Q.ItemFor(781, "plainstrider meat"), 4739, "by its name in another case")
Eq(Q.ItemFor(781, "Something Else"), 4739, "the only item, whatever the log calls it")
Eq(Q.ItemFor(800, "Gnoll Tooth"), 5002, "one of two items by name")
Eq(Q.ItemFor(800, "Something Else"), nil, "one of two, unmatched")
Eq(Q.ItemFor(999, "Plainstrider Meat"), nil, "an unknown quest")
Eq(table.concat(Q.Droppers(4739), ","), "2955,2956", "every kind that drops it")
Eq(Q.Droppers(9999), nil, "an item nothing drops")

Eq(Q.DropRate(4739, 2955), 25.0, "cmangos before wowhead")
Eq(Q.DropRate(5001, 98), 10.0, "a correction pointing at wowhead")
Eq(Q.DropRate(5003, 98), 60.0, "a correction of its own")
Eq(Q.DropRate(5002, 98), nil, "a rate of nothing")
Eq(Q.DropRate(4739, 3108), nil, "a creature that does not drop it")
-- Questie's own reckoning, where it runs.
_G.QuestieLoader = { ImportModule = function(_, name)
    if name == "DropDB" then
        return { tableWowhead = {}, GetItemDroprate = function(item, npc) return { 77.5, "questie" } end }
    end
    return { private = {} }
end }
Eq(Q.DropRate(4739, 2955), 77.5, "Questie's rate, where Questie runs")
_G.QuestieLoader = { ImportModule = function() return { private = {} } end }
Eq(Q.DropRate(4739, 2955), 25.0, "the tables, where Questie has no DropDB")
_G.QuestieLoader = nil

--------------------------------------------------------------------------
Section("real creature names (EXT-1)")

mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
local j = J.Mine()
Check(j, "setup: no route")
Eq(ns.CreatureNames.Of(j, 2955), "Plainstrider", "QuestieDB's name")
ns.CreatureNames.Note(2955, "Plainstrider (read)")
Eq(ns.CreatureNames.Of(j, 2955), "Plainstrider (read)", "a unit's name before QuestieDB's")
j.names = nil
Eq(ns.CreatureNames.Clean(j, 2956, "Adult Plainstrider Olwynne"), "Adult Plainstrider", "a recap's surname, never read off a unit")
Eq(ns.CreatureNames.Clean(j, 2956, "Something Else"), "Something Else", "a recap name that is not QuestieDB's plus words")
Away()
Eq(ns.CreatureNames.Clean(j, 2956, "Adult Plainstrider Olwynne"), "Adult Plainstrider Olwynne", "without QuestieDB, as before")
Bring()

--------------------------------------------------------------------------
Section("a hunt with QuestieDB: every kind, and what it should have taken (EXT-2)")

local QUEST = { questID = 781, title = "Break Sharptusk!", objectives = {
    { text = "Plainstrider Meat: 0/7", type = "item", numFulfilled = 0, numRequired = 7, finished = false } } }
mock.quests = { QUEST }
mock.fire("QUEST_ACCEPTED", 781)
mock.RunTimers()
local hunt = ns.Hunts.Hunting(j, 781, 1)
Check(hunt, "the hunt did not begin")
Eq(hunt.itemID, 4739, "the item, by QuestieDB")
Check(hunt.from[2955] and hunt.from[2956], "every kind that drops it, from the start")

mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
for _ = 1, 20 do mock.fire("PARTY_KILL", SELF.guid, STRIDER) end
-- The adults are the group's, and never in the user's loot window: they
-- count all the same.
for _ = 1, 11 do mock.fire("PARTY_KILL", STRANGER.guid, ADULT) end
mock.fire("PARTY_KILL", SELF.guid, WOLF)
mock.loot = { { link = MEAT, sources = { STRIDER, 1 } } }
mock.fire("LOOT_OPENED")
QUEST.objectives[1].numFulfilled, QUEST.objectives[1].finished = 7, true
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
local done = ns.Hunts.List(j)[#ns.Hunts.List(j)]
Check(done and done.questID == 781, "the hunt kept nothing")
Eq(done.kills, 31, "both kinds' kills, not the wolf's")
Eq(done.npcID, 2955, "the kind killed most")
Eq(done.name, "Plainstrider", "its name, from QuestieDB with no unit read")
Eq(done.byKind[2955].n, 20, "the one kind's own kills")
Eq(done.byKind[2956].n, 11, "the other's")
Eq(done.byKind[2956].name, "Adult Plainstrider", "the other's name")
-- 20 at 25% and 11 at 50%: 10.5 items in 31 kills, so 7 should take 20.7.
Eq(done.expected, 20.7, "the kills it should have taken")
Eq(ns.Hunts.BadLuck(j, done), true, "31 where 20.7 were expected was not bad luck")
Eq(ns.Hunts.Line(done), "31" .. NB .. "Plainstriders and others for 7" .. NB .. "Plainstrider Meat, 10" .. NB
    .. "more than expected", "the words")

-- Without QuestieDB: the loot window alone, no expectation, as before.
Away()
QUEST.objectives[1].numFulfilled, QUEST.objectives[1].finished = 0, false
QUEST.objectives[1].text = "Plainstrider Meat: 0/7"
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
hunt = ns.Hunts.Hunting(j, 781, 1)
Check(hunt and not hunt.from[2956], "without QuestieDB, a kind before it dropped anything")
for _ = 1, 4 do mock.fire("PARTY_KILL", SELF.guid, STRIDER) end
for _ = 1, 3 do mock.fire("PARTY_KILL", STRANGER.guid, ADULT) end
mock.fire("LOOT_OPENED")
QUEST.objectives[1].numFulfilled, QUEST.objectives[1].finished = 7, true
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
done = ns.Hunts.List(j)[#ns.Hunts.List(j)]
Eq(done.kills, 4, "only the kind seen dropping it")
Eq(done.byKind, nil, "one kind has no breakdown")
Eq(done.expected, nil, "nothing expected")
Eq(ns.Hunts.Rated(done), false, "a rate without QuestieDB")
Bring()
-- Read again with QuestieDB here (12 Oct, in the client: a hunt kept
-- before the rates were read had none on its card): the item by the
-- quest, the rate of the kind it kept. 4 at 25% is one item, so 7 should
-- take 28.
Eq(ns.Hunts.Rated(done), true, "an old hunt was not given its rate")
Eq(done.itemID, 4739, "an old hunt's item, by its quest")
Eq(done.expected, 28, "an old hunt's expected kills")
Eq(ns.Hunts.Rated({ questID = 781, item = "Plainstrider Meat", need = 7, kills = 4, npcID = 3108 }), false,
    "a kind with no rate was given one")
mock.groupSize = 0

--------------------------------------------------------------------------
Section("a rate past belief, and the group's own drops")

-- 37 Defias Rogue Wizards for 6 Red Linen Bandanas (12 Oct, in the
-- client): at the server data's 66% that is a chance in billions; at
-- Wowhead's 37%, bad luck.
Eq(ns.Hunts.Believable(37, 6, 9.1), false, "37 kills for 6 at 66% believed")
Eq(ns.Hunts.Believable(37, 6, 16.2), true, "37 kills for 6 at 37% not believed")
Eq(ns.Hunts.Believable(4, 7, 58.3), true, "a quick hunt doubted (only slow ones are)")
Check(ns.Hunts.Slow(10, 1, 0.1) > 0.38 and ns.Hunts.Slow(10, 1, 0.1) < 0.39, "nine misses at 10%: " .. ns.Hunts.Slow(10, 1, 0.1))
local bandanas = { questID = 83, item = "Red Linen Bandana", need = 6, kills = 37, npcID = 474, expected = 9.1 }
Eq(ns.Hunts.Rated(bandanas), true, "the bandanas lost their rate")
Eq(bandanas.expected, 16.2, "the bandanas' rate, Wowhead's where the first is past belief")
Eq(bandanas.itemID, 1019, "the bandana, by its quest")
Eq(ns.Hunts.BadLuck(j, bandanas), true, "37 where 16.2 were expected was not bad luck")
local endless = { questID = 83, item = "Red Linen Bandana", need = 2, kills = 200, npcID = 474 }
Eq(ns.Hunts.Rated(endless), false, "a hunt past every rate kept one")
Eq(endless.expected, nil, "a hunt past every rate expects something")
Away()
local kept = { item = "Red Linen Bandana", need = 6, kills = 37, npcID = 474, expected = 9.1 }
Eq(ns.Hunts.Rated(kept), true, "without QuestieDB a kept rate is not read again")

-- A group member's loot of the item is one the user could not have: it
-- counts with the user's own, against the same kills.
Bring()
QUEST.objectives[1].numFulfilled, QUEST.objectives[1].finished = 0, false
QUEST.objectives[1].text = "Plainstrider Meat: 0/7"
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
hunt = ns.Hunts.Hunting(j, 781, 1)
Check(hunt, "setup: the meat not counted")
for _ = 1, 20 do mock.fire("PARTY_KILL", SELF.guid, STRIDER) end
local function Loot(text, guid)
    mock.fire("CHAT_MSG_LOOT", text, "x", "", "", "", "", 0, 0, "", 0, 1, guid)
end
Loot("Someone receives loot: " .. MEAT .. "x2.", STRANGER.guid)
Loot("You receive loot: " .. MEAT .. ".", SELF.guid)
Loot("Someone receives loot: " .. MEAT .. ".", "Player-4615-0CCCCCCC")
Loot("Someone receives loot: |cffffffff|Hitem:2589::::::::5:::::|h[Linen Cloth]|h|r.", STRANGER.guid)
Eq(hunt.shared, 2, "the group's copies (not the user's, a stranger's or another item)")
QUEST.objectives[1].numFulfilled, QUEST.objectives[1].finished = 7, true
mock.fire("QUEST_LOG_UPDATE")
mock.RunTimers()
done = ns.Hunts.List(j)[#ns.Hunts.List(j)]
Eq(done.shared, 2, "the group's copies kept")
Eq(ns.Hunts.Items(done), 9, "the items the kills gave")
-- 20 at 25% is five items for 20 kills, so nine should take 36.
Eq(done.expected, 36, "expected kills for the group's items too")
Eq(ns.Hunts.BadLuck(j, { kills = 30, need = 4, shared = 8 }), false, "30 for 12, the group's counted, was bad luck")
Eq(ns.Hunts.BadLuck(j, { kills = 30, need = 4 }), true, "setup: 30 for 4 alone is bad luck")
mock.groupSize = 0

-- A kind with no rate: nothing expected at all.
Eq(ns.Hunts.Expected({ [1] = { n = 5 }, [2] = { n = 5 } }, 10, 2, function(id) return id == 1 and 20 or nil end), nil,
    "an expectation with a kind unrated")
Eq(ns.Hunts.Expected({ [1] = { n = 10 } }, 10, 2, function() return 20 end), 10, "two at 20%")

--------------------------------------------------------------------------
Section("bad luck with the rate known: eight more, and a quarter more")

local function Luck(kills, expected, need)
    return { kills = kills, need = need or 5, expected = expected }
end
local k = { hunts = {} }
Eq(ns.Hunts.BadLuck(k, Luck(27, 20)), false, "seven more than expected")
Eq(ns.Hunts.BadLuck(k, Luck(28, 20)), true, "eight more, and 1.4 times")
Eq(ns.Hunts.BadLuck(k, Luck(49, 40)), false, "nine more, but 1.225 times")
Eq(ns.Hunts.BadLuck(k, Luck(50, 40)), true, "ten more, and 1.25 times")
-- Without a rate, the old rule (tests/combat.lua has it in full).
Eq(ns.Hunts.BadLuck(k, { kills = 24, need = 8 }), true, "three an item, no rate")
Eq(ns.Hunts.BadLuck(k, Luck(24, 30, 8)), false, "three an item, but fewer than expected")

--------------------------------------------------------------------------
Section("good luck: an eighth of the kills expected (EXT-3)")

Eq(ns.Hunts.GoodLuck(Luck(10, 80)), true, "eight times")
Eq(ns.Hunts.GoodLuck(Luck(10, 79)), false, "7.9 times")
Eq(ns.Hunts.GoodLuck(Luck(1, 8, 1)), true, "the first kill, at one in eight")
Eq(ns.Hunts.GoodLuck({ kills = 1, need = 1 }), false, "no rate, no good luck")
Eq(ns.Hunts.BadLuck(k, Luck(10, 80)) and ns.Hunts.GoodLuck(Luck(10, 80)), false, "both bad and good")

local lucky = { kills = 4, need = 7, expected = 58.3, name = "Plainstrider", item = "Plainstrider Meat" }
Eq(ns.Hunts.Line(lucky), "4" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat, 54" .. NB
    .. "fewer than expected", "good luck in a few words")
Eq(ns.Hunts.Fortune(lucky), "It took only 4" .. NB .. "Plainstriders to get 7" .. NB .. "Plainstrider Meat, 54" .. NB
    .. "fewer than expected.", "good luck in a sentence")
Eq(ns.Hunts.Fortune({ kills = 1, need = 1, expected = 10, name = "Sharptalon", item = "Sharptalon's Claw" }),
    "The first Sharptalon gave up its Sharptalon's Claw, where 10" .. NB .. "were expected.", "the first kill")
Eq(ns.Hunts.ExpectedWords({ kills = 20, expected = 20.3 }), "", "even")

local tip, lines = ns.Hunts.Tip({ kills = 31, need = 7, name = "Plainstrider", item = "Plainstrider Meat",
    expected = 20.7, title = "Break Sharptusk!", t = mock.now, level = 12,
    byKind = { [2956] = { n = 11, name = "Adult Plainstrider" }, [2955] = { n = 20, name = "Plainstrider" } } },
    mock.now)
Eq(tip, "31" .. NB .. "Plainstriders and others for 7" .. NB .. "Plainstrider Meat, 10" .. NB .. "more than expected",
    "the tooltip's heading")
Eq(lines[1], "20" .. NB .. "Plainstriders, 11" .. NB .. "Adult Plainstriders", "each kind's own kills, most first")
Eq(lines[2], "For Break Sharptusk!", "the quest")

--------------------------------------------------------------------------
Section("chain finales (JRN-28)")

local Finales = ns.QuestFinales

-- Samophlange Manual (3924): 894, 900, 901, 902, 3921, 3922, 3923, 3924.
Check(Finales.CHAINS[3924], "setup: Samophlange Manual is not a chosen finale")
local done = {}
local titles = { [3924] = "Samophlange Manual" }
local log = _G.C_QuestLog
log.IsQuestFlaggedCompleted = function(id) return done[id] == true end
log.GetTitleForQuestID = function(id) return titles[id] end

local began = mock.now
mock.fire("QUEST_ACCEPTED", 3, 894)
local start = j.chainStarts and j.chainStarts[894]
Check(start, "the chain's first quest taken was not kept")
Eq(start.t, began, "when")
Eq(start.mapID, mock.mapID, "where")
mock.fire("QUEST_ACCEPTED", 900)
mock.fire("QUEST_ACCEPTED")
Eq(j.chainStarts[900], nil, "a quest in the middle of a chain")
mock.now = mock.now + 1000
mock.fire("QUEST_ACCEPTED", 894)
Eq(j.chainStarts[894].t, began, "taken again: the first time kept")

for _, id in ipairs({ 894, 900, 901, 902, 3921, 3922, 3923 }) do done[id] = true end
mock.now = began + 5 * ns.DAY
mock.fire("QUEST_TURNED_IN", 3924, 1000, 0)
local finale = Finales.List(j)[1]
Check(finale, "the finale was not kept")
Eq(finale.questID, 3924, "the quest")
Eq(finale.title, "Samophlange Manual", "the client's title")
Eq(finale.n, 8, "the whole chain")
Eq(finale.started.t, began, "where it began")
mock.fire("QUEST_TURNED_IN", 3924, 1000, 0)
Eq(#Finales.List(j), 1, "the same finale twice")
mock.fire("QUEST_TURNED_IN", 783, 100, 0)
Eq(#Finales.List(j), 1, "a quest that ends no chosen chain")

local zone = ns.MapName(mock.mapID)
Eq(Finales.Sentence(finale), "The end of " .. OPEN .. "Samophlange Manual" .. CLOSE .. ", a chain of eight begun in "
    .. zone .. " five days before.", "the prose")
Eq(Finales.Words(finale), "the end of " .. OPEN .. "Samophlange Manual" .. CLOSE, "the caption's words")
tip, lines = Finales.Tip(finale, mock.now)
Eq(tip, "The end of " .. OPEN .. "Samophlange Manual" .. CLOSE, "the tooltip's heading")
Eq(lines[1], "A chain of 8 quests", "the tooltip's length")
-- The tailpiece's tooltip (Finales.Tips, the mark's `tips`): a lone
-- finale reads as its own tooltip does; several on one spot are counted
-- in the title and each told once, then one span and level range.
do
    local title, said = Finales.Tips({ finale }, mock.now)
    local lone = { Finales.Tip(finale, mock.now) }
    Eq(title, lone[1], "a lone finale's title, as its own tooltip")
    Eq(table.concat(said, "|"), table.concat(lone[2], "|"), "and its lines")
    Check(said[#said]:find(", level %d+$"), "its when and level, once: " .. said[#said])
    local seed = { title = "The Demon Seed", n = 7, t = mock.now - 600, level = 21 }
    local f = { title = finale.title, n = finale.n, t = mock.now - 60, level = 22 }
    title, said = Finales.Tips({ seed, f }, mock.now)
    Eq(title, "Two chains finished", "two on a spot: counted in the title")
    Eq(said[1], OPEN .. "The Demon Seed" .. CLOSE .. ", a chain of 7 quests", "each chain once, with its length")
    Eq(said[2], OPEN .. "Samophlange Manual" .. CLOSE .. ", a chain of 8 quests", "then the next")
    Check(said[3]:find("from") and said[3]:find(", levels 21 to 22$") and #said == 3,
        "a span and a level range: " .. tostring(said[3]))
    local four = { seed, f, { title = "A", t = mock.now }, { title = "B", t = mock.now } }
    title, said = Finales.Tips(four, mock.now)
    Eq(said[1], OPEN .. "The Demon Seed" .. CLOSE .. ", " .. OPEN .. "Samophlange Manual" .. CLOSE .. ", " .. OPEN
        .. "A" .. CLOSE .. " and " .. OPEN .. "B" .. CLOSE, "past three, every title on one line")
    Eq(#said, 2, "and when")
end

-- A chain whose first quest the diary never saw taken, one quest of it
-- not down as done (the server let it be handed in all the same).
done = { [7] = true }
for _, id in ipairs({ 6, 11, 12, 13 }) do done[id] = true end
log.IsQuestFlaggedCompleted = function(id) return done[id] == true end
local chain = Finales.CHAINS[46]
for i = 1, #chain.routes[1] - 2 do done[chain.routes[1][i]] = true end
titles[46] = nil
mock.fire("QUEST_TURNED_IN", 46, 500, 0)
finale = Finales.List(j)[2]
Eq(finale.title, "Bounty on Murlocs", "the data's title, where the client has none")
Eq(finale.n, #chain.routes[1] - 1, "the quests done")
Eq(finale.started, nil, "no start")
Eq(Finales.Sentence(finale), "The end of " .. OPEN .. "Bounty on Murlocs" .. CLOSE .. ", a chain of six.",
    "the prose without a start")

-- Two routes to one end: the one most done counts.
local two = Finales.CHAINS[93949]
Check(two and #two.routes == 2, "setup: no finale with two routes")
done = {}
for i = 1, #two.routes[2] - 1 do done[two.routes[2][i]] = true end
log.IsQuestFlaggedCompleted = function(id) return done[id] == true end
mock.fire("QUEST_TURNED_IN", 93949, 500, 0)
Eq(Finales.List(j)[3].n, #two.routes[2], "the other faction's route, done in full")

-- A client that cannot say what is done: the chain is taken whole.
log.IsQuestFlaggedCompleted = nil
local quiet = Finales.CHAINS[166]
mock.fire("QUEST_TURNED_IN", 166, 500, 0)
Eq(Finales.List(j)[4].n, #quiet.routes[1], "the whole chain, unasked")

local function Spans(seconds)
    return Finales.Sentence({ title = "X", n = 7, t = 1000 + seconds, started = { t = 1000 } })
end
Check(Spans(3 * 3600):find("three hours before", 1, true), "three hours")
Check(Spans(ns.DAY):find("a day before", 1, true), "a day")
Check(Spans(20 * ns.DAY):find("three weeks before", 1, true), "three weeks")
Check(Spans(70 * ns.DAY):find("two months before", 1, true), "two months")

--------------------------------------------------------------------------
Section("on the plates: good luck and finales are moments")

local e = R.Gather(j, 0, mock.now + 1, {})
Eq(#e.finales, 4, "the finales in the entry")
local kinds = {}
for _, m in ipairs(R.Moments(j, e, {})) do kinds[m.kind] = (kinds[m.kind] or 0) + 1 end
Eq(kinds.finale, 4, "a moment each")
Eq(R.RANK.finale, R.RANK.find, "a finale ranks with a first found")
Check(R.RANK.finale < R.RANK.level, "a finale does not outrank a level-up")
Eq(R.RANK.fortune, R.RANK.luck, "good luck ranks with bad")
j.hunts[#j.hunts + 1] = { t = mock.now, mapID = mock.mapID, x = 0.5, y = 0.5, kills = 2, need = 1, expected = 20,
    name = "Plainstrider", item = "Plainstrider Meat", questID = 1 }
e = R.Gather(j, 0, mock.now + 1, {})
Eq(#e.fortunes, 1, "the good luck in the entry")
Check(ns.Hunts.Lines(e):find("It took only 2", 1, true), "the good luck in the prose")
Check(table.concat(Text.Lines(e, mock.now), " "):find("a chain of eight", 1, true), "the finale in the prose")

Away()
