-- A week of pages with the same people, as a diary would hold them: for
-- reading whole pages, and for seeing that the words vary from day to day.
-- Rendered in order with one memory by tests/prose/run.lua (--samples).

local DAY = 86400
local function At(month, day, hour, min)
    return os.time({ year = 2026, month = month, day = day, hour = hour, min = min or 0 })
end

local brennick = { id = "Player-1", name = "Brennick", sex = 2, race = "Dwarf", class = "Paladin",
    diary = true, relationship = "levelling buddy from Redridge", level = 32, tags = { friend = true } }
local ilyra = { id = "Player-2", name = "Ilyra", sex = 3, race = "Night Elf", class = "Druid",
    diary = true, level = 35, tags = { friend = true, helper = true } }
local hunter = { id = "Player-3", name = "Sylwen", sex = 3, race = "Night Elf", class = "Hunter",
    familiar = true, level = 30 }
local morthis = { id = "Player-4", name = "Morthis", sex = 2, race = "Undead", class = "Rogue",
    hostile = true, named = true, level = 38 }
-- Met on Tuesday and written into the diary the same evening, so named
-- from then on (the planner names anyone in the diary).
local kaelith = { id = "Player-5", name = "Kaelith", sex = 2, race = "Human", class = "Mage",
    diary = true, level = 31 }
local stranger = { id = "Player-6", race = "Gnome", class = "Warlock", level = 33 }

local function Page(spec)
    local page = {
        part = spec.part or "evening",
        seconds = spec.seconds or 9600,
        zones = spec.zones,
        zoneFirst = spec.zones[1],
        zoneLast = spec.zones[#spec.zones],
        levelStart = spec.levelStart,
        levelEnd = spec.levelEnd,
        levelsGained = spec.levelEnd - spec.levelStart,
        levelCap = 60,
        solo = spec.solo,
        diaryMet = spec.diaryMet or 0,
        newFaces = spec.newFaces or 0,
        seen = spec.seen or 0,
        myDeaths = spec.myDeaths or 0,
    }
    return page
end

return {
    -- Monday: Brennick back after a long gap, a rescue, a gift; the hunter at
    -- Astranaar again; Morthis on the road.
    {
        key = "2026-10-19", title = "Monday 19 October", now = At(10, 19, 23, 10),
        page = Page({ zones = { "Ashenvale", "Stonetalon Mountains" }, levelStart = 31, levelEnd = 33,
            diaryMet = 1, newFaces = 0, seen = 23, myDeaths = 1 }),
        paragraphs = {
            {
                { angle = "open", moves = { "scene" } },
                { angle = "reunion", facts = { who = brennick, gapDays = 19, usualGapDays = 4, longAbsence = true,
                    isRecordGap = true, prevRecordDays = 9, lastWhen = At(9, 30, 22), lastZone = "Hillsbrad Foothills",
                    lastGrouped = true, zone = "Ashenvale", subZone = "Astranaar", timesMet = 12,
                    firstZone = "Redridge Mountains", firstMetDays = 61 }, moves = { "gap" } },
                { angle = "together", facts = { who = brennick, seconds = 6600, grouped = true,
                    zones = { "Ashenvale" }, zone = "Ashenvale", quests = 9 }, moves = { "time" } },
                { angle = "rescue", facts = { who = brennick, pct = 6, foe = { name = "Thistlefur Shaman", rank = "normal" },
                    firstByThem = false, timesSaved = 2, grouped = true }, moves = { "saved" }, rel = "then" },
                { angle = "trade", facts = { who = brennick, received = { { link = "[Lesser Healing Potion]", count = 5 } },
                    first = false }, moves = { "gift" }, rel = "end" },
                { angle = "parity", facts = { who = brennick, myLevel = 33, theirLevel = 32, levelDiff = 1, absLevelDiff = 1,
                    aheadMe = true, closed = true, diffThen = 3 }, moves = { "levels" } },
            },
            {
                { angle = "stranger", facts = { who = hunter, days = 3, windowDays = 7, zone = "Ashenvale",
                    subZone = "Astranaar", sameSpot = true, sameTime = true, levelFirst = 28, levelNow = 30,
                    levelRise = 2, neverSpoke = true, neverGrouped = true } },
            },
            {
                { angle = "pvp", facts = { who = morthis, probable = true, timesKilledMe = 2, lastDeathWhen = At(10, 12, 21),
                    toldBefore = true, zone = "Stonetalon Mountains", outlevelled = true }, moves = { "death" }, rel = "turn" },
                { angle = "close" },
            },
        },
    },

    -- Tuesday: Brennick again, a dungeon with a new face, a ding.
    {
        key = "2026-10-20", title = "Tuesday 20 October", now = At(10, 20, 23, 30),
        page = Page({ zones = { "Ashenvale" }, levelStart = 33, levelEnd = 34, diaryMet = 1, newFaces = 3, seen = 11 }),
        paragraphs = {
            {
                { angle = "open" },
                { angle = "regular", facts = { who = brennick, streakDays = 2, zone = "Ashenvale" } },
                { angle = "ding", facts = { who = brennick, level = 33, from = 32, together = true, alsoMe = true, levels = 1 } },
            },
            {
                { angle = "new_face", facts = { who = kaelith, how = "group", viaGroup = true, zone = "Ashenvale",
                    seconds = 3000, quests = 2, theirLevel = 31 }, moves = { "meet" } },
                { angle = "dungeon", facts = { instance = "Blackfathom Deeps", groupSize = 5, friend = brennick, friendCount = 1,
                    strangers = 3, seconds = 5400, bossesKilled = 6, bossesTotal = 7, wipes = 2, deaths = 7, myDeaths = 2,
                    deadliest = kaelith, deadliestCount = 3, myLoot = { { link = "[Gravestone Scepter]", count = 1 } },
                    rollItem = { { link = "[Strike of the Hydra]", count = 1 } }, iWon = false, winner = brennick,
                    myRoll = 84, winRoll = 87, close = true }, rel = "then" },
                { angle = "new_face", facts = { who = kaelith, addedToday = true, tag = "friend" }, moves = { "added" } },
            },
            {
                { angle = "close" },
            },
        },
    },

    -- Wednesday afternoon: nothing much.
    {
        key = "2026-10-21", title = "Wednesday 21 October", now = At(10, 21, 16, 40),
        page = Page({ part = "afternoon", seconds = 2700, zones = { "Ashenvale" }, levelStart = 34, levelEnd = 34,
            seen = 4, solo = true }),
        paragraphs = {
            { { angle = "quiet", facts = { nobodyKnown = true, seen = 4, gained = 0 } } },
        },
    },

    -- Thursday: duels with Brennick, Ilyra at the campfire, a bad death.
    {
        key = "2026-10-22", title = "Thursday 22 October", now = At(10, 22, 23, 50),
        page = Page({ zones = { "Ashenvale", "The Barrens" }, levelStart = 34, levelEnd = 35, diaryMet = 2, seen = 18,
            myDeaths = 1 }),
        paragraphs = {
            {
                { angle = "open", moves = { "scene" } },
                { angle = "duel", facts = { who = brennick, won = 3, lost = 1, total = 4, lastWon = true, allWon = 7,
                    allLost = 6, zone = "Ashenvale", subZone = "Astranaar" } },
            },
            {
                { angle = "campfire", facts = { who = ilyra, zone = "Ashenvale", subZone = "Lake Falathim",
                    theirLevel = 35, strangers = 1, firstTime = true } },
                { angle = "chat", facts = { who = ilyra, whispersIn = 3, whispersOut = 2, firstWhisper = false },
                    moves = { "heard" }, rel = "before" },
            },
            {
                { angle = "misfortune", facts = { who = kaelith, foe = { name = "Kolkar Stormer", rank = "elite" },
                    sameKiller = true, within = 4, theyDiedFirst = true, zone = "The Barrens", grouped = true }, rel = "turn" },
                { angle = "witness", facts = { who = stranger, watched = 14, foe = { name = "Kolkar Stormer", rank = "elite" },
                    zone = "The Barrens" } },
                { angle = "close" },
            },
        },
    },

    -- Saturday night: revenge on Morthis, Ilyra in a guild, a crowd.
    {
        key = "2026-10-24", title = "Saturday 24 October", now = At(10, 25, 0, 40),
        page = Page({ part = "night", seconds = 12000, zones = { "Stonetalon Mountains", "Ashenvale" }, levelStart = 35,
            levelEnd = 36, diaryMet = 2, newFaces = 4, seen = 31 }),
        paragraphs = {
            {
                { angle = "open" },
                { angle = "crowd", facts = { newFaces = 4, seen = 31, groupedWith = 3, busiestZone = "Stonetalon Mountains",
                    busiestSeen = 19, hostileSeen = 6 } },
            },
            {
                { angle = "pvp", facts = { who = morthis, by = brennick, timesKilledThem = 1, revenge = true,
                    zone = "Stonetalon Mountains" }, moves = { "kill" } },
                { angle = "together", facts = { who = brennick, seconds = 7200, grouped = true, zones = { "Stonetalon Mountains" },
                    zone = "Stonetalon Mountains", quests = 6, others = 1, rare = "Foreman Rigger", rareCount = 1,
                    rareKilled = true }, moves = { "time", "rares" } },
            },
            {
                { angle = "changed", facts = { who = ilyra, newGuild = "Wardens of the Moon", joined = true }, moves = { "guild" } },
                { angle = "chat", facts = { who = ilyra, quote = "come find us at Astranaar sometime", fromMe = false,
                    channel = "whisper" }, moves = { "quote" } },
                { angle = "close", facts = { lateEnd = true } },
            },
        },
    },

    -- Two weeks on: no Brennick.
    {
        key = "2026-11-07", title = "Saturday 7 November", now = At(11, 7, 21, 0),
        page = Page({ zones = { "Desolace" }, levelStart = 40, levelEnd = 41, seen = 9, solo = true }),
        paragraphs = {
            {
                { angle = "open" },
            },
            {
                { angle = "lost", facts = { who = brennick, lastDays = 14, lastZone = "Stonetalon Mountains", timesMet = 16,
                    usualGapDays = 2, longest = false, heardDays = 3 }, rel = "turn" },
                { angle = "close" },
            },
        },
    },
}
