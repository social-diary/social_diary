-- /sd testdata's second diary entry (Dev/TestData.lua, TestData.Register):
-- Tessa Testerson, three months of sessions written for the session prose
-- (UI/Words/SessionProse.lua), so each of the planner's cases is on one
-- timeline with `/sd prose` on: a first meeting, firsts of every kind, runs
-- that become routine, a favour returned twice, the lead changing hands,
-- long gaps, and the level cap. Tester's own week is left as it is, and she
-- is a woman where he is a man, for the pronouns.
--
-- With debug on as well, a row's tooltip says why it reads as it does
-- (SessionProse.Trace). Development tooling: listed in the TOC's
-- do-not-package block, and left out by .pkgmeta.

local addonName, ns = ...

local TestData = ns.TestData
local Link = TestData.Link

local GUID = "Player-0000-7E57E574"
TestData.PROSE_GUID = GUID

local MIN, HOUR, DAY = 60, 60 * 60, 24 * 60 * 60

-- Strangers in her runs, seen as they grouped.
local OSKAR = { guid = "Player-0000-7E57E575", first = "Oskar", surname = "Ashmantle", class = "WARRIOR", role = "TANK" }
local MIREL = { guid = "Player-0000-7E57E576", first = "Mirel", surname = "Duskwater", class = "PRIEST", role = "HEALER" }

local LINEN = Link(1, 2589, "Linen Cloth")
local POTION = Link(1, 858, "Lesser Healing Potion")
local CLOAK = Link(2, 4663, "Journeyman's Cloak")
local BELT = Link(3, 6449, "Glowing Lizardscale Cloak")
local BLADE = Link(3, 14145, "Cursed Felblade")

local function Members()
    local me = { guid = ns.ownGUID, first = "You", role = "DAMAGER" }
    local tessa = { guid = GUID, first = "Tessa", surname = "Testerson", class = "HUNTER", role = "DAMAGER" }
    return { tessa, me, OSKAR, MIREL }
end

local function Quests(n, from)
    local list = {}
    for i = 1, n do list[i] = from + i end
    return list
end

local function Row(kind, time, zone, data, session)
    data = data or {}
    data.time = time
    data.where = { zone = zone }
    data.session = session.id
    return ns.Interactions.Add(GUID, kind, data)
end

local function Write(now)
    ns.Characters.Observe(GUID, { first = "Tessa", surname = "Testerson", class = "HUNTER", race = "Tauren",
        faction = "Horde", level = 52, sex = 3, time = now - 90 * DAY })
    for _, m in ipairs({ { OSKAR, "Orc" }, { MIREL, "Undead" } }) do
        ns.Characters.Observe(m[1].guid, { first = m[1].first, surname = m[1].surname, class = m[1].class,
            race = m[2], faction = "Horde", level = 14, sex = 2, time = now - 45 * DAY })
    end

    -- `days` ago at `hour` o'clock, the two levels at each end ({ from, to }),
    -- closed so it never becomes the open session.
    local function Session(days, hour, minutes, zones, mine, hers, p, extra)
        local start = ns.DayStart(now - days * DAY) + hour * HOUR
        local seconds = minutes * MIN
        p = p or {}
        p.since, p.last, p.seconds = start, start + seconds, seconds
        p.levelStart, p.levelEnd = hers[1], hers[2]
        local opts = { source = "group", test = true, startedAt = start, endedAt = start + seconds,
            participants = { [GUID] = p }, zones = zones, myLevelStart = mine[1], myLevelEnd = mine[2] }
        for k, v in pairs(extra or {}) do opts[k] = v end
        return ns.Sessions.New(opts)
    end
    local NEARBY = { source = "nearby" }

    -- A first meeting: grouped, and written into the diary there and then.
    local s = Session(90, 18, 50, { "Durotar" }, { 8, 9 }, { 8, 9 }, { quests = Quests(3, 1000) })
    local entry = ns.Diary.Add(GUID, { source = "test" })
    if not entry then return end
    entry.addedAt = s.startedAt + 40 * MIN
    entry.addedContext.zone = "Durotar"
    entry.note = "Test data for the session prose, from /sd testdata. Remove it with /sd testdata remove."
    entry.tags = { "test" }

    -- Only nearby, for a quarter of an hour: a quiet row.
    Session(88, 9, 15, { "Durotar" }, { 9, 9 }, { 9, 9 }, nil, NEARBY)

    -- Both to a round level, side by side.
    Session(87, 20, 60, { "The Barrens" }, { 9, 10 }, { 9, 10 }, { quests = Quests(4, 1010) })

    -- The first rescue, and one that came too late.
    s = Session(85, 21, 40, { "The Barrens" }, { 10, 10 }, { 10, 11 }, { quests = Quests(2, 1020) })
    Row("saved_you", s.startedAt + 15 * MIN, "The Barrens",
        { context = { pct = 6, name = "Razormane Hunter", rank = "normal" } }, s)
    s = Session(84, 19, 25, { "The Barrens" }, { 10, 11 }, { 11, 11 }, nil, NEARBY)
    Row("tried_to_help", s.startedAt + 10 * MIN, "The Barrens",
        { context = { name = "Sunscale Lashtail", rank = "normal" } }, s)
    -- The first whispers, on a row of their own: as support to a bigger
    -- point they would not be told (SessionProse.Choose).
    s = Session(83, 16, 20, { "The Barrens" }, { 11, 11 }, { 11, 11 }, nil, NEARBY)
    Row("whisper_in", s.startedAt + 5 * MIN, "The Barrens", { excerpt = "sorry, got there too late" }, s)
    Row("whisper_out", s.startedAt + 6 * MIN, "The Barrens", { excerpt = "no harm done" }, s)

    -- The first trade: I gave.
    s = Session(82, 18, 35, { "The Barrens" }, { 11, 11 }, { 11, 12 })
    Row("trade", s.startedAt + 5 * MIN, "The Barrens", { context = { given = { { link = LINEN, count = 10 } } } }, s)

    -- The first time at my fire; our first rare.
    s = Session(80, 22, 30, { "The Barrens" }, { 11, 12 }, { 12, 12 }, nil, NEARBY)
    Row("campfire", s.startedAt + 12 * MIN, "The Barrens", { context = { subZone = "The Crossroads" } }, s)
    s = Session(78, 19, 45, { "The Barrens" }, { 12, 13 }, { 12, 13 }, { quests = Quests(3, 1030),
        rares = { { name = "Sister Hatelash", npcID = 5927, kind = "rare", time = now - 78 * DAY } } })

    -- Our first run, a full clear, my first; a roll between us, won by a point.
    -- (Every run here has questing round it: a session that is only a run
    -- gives way to the visit's own row, which is not written in prose.)
    s = Session(75, 20, 170, { "The Barrens", "Ragefire Chasm" }, { 13, 14 }, { 13, 14 }, { quests = Quests(3, 1035) }, { others = 2 })
    TestData.Visit({ instanceID = 389, name = "Ragefire Chasm", instanceType = "party", difficulty = "Normal",
        startedAt = s.startedAt + 5 * MIN, endedAt = s.startedAt + 85 * MIN, sessionIds = { s.id }, members = Members(),
        bossesKilled = { "Oggleflint", "Taragaman the Hungerer", "Jergosh the Invoker", "Bazzalan" }, bossTotal = 4,
        deaths = 1, wipes = 0, deathLog = { { guid = OSKAR.guid, time = s.startedAt + 30 * MIN } },
        loot = { { guid = GUID, item = CLOAK, itemID = 4663, time = s.startedAt + 40 * MIN } },
        rolls = { { key = "tessa:rfc:1", item = BLADE, itemID = 14145, time = s.startedAt + 80 * MIN,
            need = { [ns.ownGUID] = 87, [GUID] = 86 }, winner = ns.ownGUID, winRoll = 87, winNeed = true } } })

    -- A favour returned, a rough night between, and a gift that is only a gift.
    s = Session(70, 18, 40, { "The Barrens" }, { 14, 14 }, { 14, 15 })
    Row("trade", s.startedAt + 10 * MIN, "The Barrens", { context = { received = { { link = POTION, count = 5 } } } }, s)
    Session(68, 23, 60, { "Stonetalon Mountains" }, { 14, 15 }, { 15, 15 }, { quests = Quests(1, 1039) },
        { deaths = { [ns.ownGUID] = 5, [GUID] = 1 } })
    s = Session(62, 19, 40, { "The Barrens" }, { 15, 16 }, { 15, 16 })
    Row("trade", s.startedAt + 10 * MIN, "The Barrens", { context = { received = { { link = BELT, count = 1 } } } }, s)

    -- The same run, day after day, until it is routine; the first, three
    -- wipes and most of the deaths hers. The rows must not all lead alike.
    for i = 1, 7 do
        local level = 15 + i
        s = Session(59 - i, 20, 100, { "The Barrens", "Ragefire Chasm" }, { level, level }, { level, level + 1 },
            { quests = Quests(2, 1040 + i) }, { others = 2 })
        local wipes = i == 1 and 3 or 0
        local log = {}
        if i == 1 then
            for k = 1, 4 do log[k] = { guid = GUID, time = s.startedAt + k * 8 * MIN } end
        end
        TestData.Visit({ instanceID = 389, name = "Ragefire Chasm", instanceType = "party", difficulty = "Normal",
            startedAt = s.startedAt + 2 * MIN, endedAt = s.startedAt + 43 * MIN, sessionIds = { s.id }, members = Members(),
            bossesKilled = { "Oggleflint", "Taragaman the Hungerer" }, bossTotal = 4,
            deaths = #log, wipes = wipes, deathLog = log, loot = {}, rolls = {} })
    end

    -- She has overtaken me, then a month apart: our longest gap.
    Session(50, 18, 70, { "Thousand Needles" }, { 22, 22 }, { 23, 24 }, { quests = Quests(4, 1050) })
    Session(20, 20, 80, { "Desolace" }, { 37, 38 }, { 36, 37 }, { quests = Quests(5, 1060) })
    -- The next day, as if nothing happened; a week later, a shorter gap.
    Session(19, 20, 60, { "Desolace" }, { 38, 38 }, { 37, 38 }, { quests = Quests(3, 1070) })
    Session(12, 13, 55, { "Dustwallow Marsh" }, { 40, 41 }, { 40, 40 }, { quests = Quests(2, 1080) })

    -- She watched me die: on the trace, but it may not lead and nothing else
    -- on this row is a point for it to support, so the row doesn't tell it.
    s = Session(10, 7, 20, { "Tanaris" }, { 44, 44 }, { 42, 42 }, nil, NEARBY)
    Row("watched_death", s.startedAt + 8 * MIN, "Tanaris",
        { context = { watched = 14, name = "Wastewander Rogue", rank = "normal", subZone = "Gadgetzan" } }, s)

    -- Our longest session yet, over three zones; her round level, nearby.
    Session(8, 14, 300, { "Tanaris", "Feralas", "Thousand Needles" }, { 46, 48 }, { 44, 46 }, { quests = Quests(12, 1090) })
    Session(6, 22, 30, { "Felwood" }, { 50, 50 }, { 49, 50 }, nil, NEARBY)

    -- My level cap, with her there.
    local cap = ns.Journey.MaxLevel()
    Session(3, 21, 90, { "Winterspring" }, { cap - 1, cap }, { 51, 52 }, { quests = Quests(6, 1110) })
end

TestData.Register("beat", function(c)
    if c.at == "now" then Write(c.now) end
end)

-- She and her runs' strangers. Her sessions go with her; the runs go by
-- their mark (TestData.Remove).
TestData.Register("remove", function()
    ns.Characters.Forget(GUID)
    for _, m in ipairs({ OSKAR, MIREL }) do
        if ns.db.characters[m.guid] and not ns.Diary.IsDiary(m.guid) then ns.Characters.Forget(m.guid) end
    end
end)
