-- /sd testdata: a made-up diary entry (and a second for the session prose,
-- Dev/TestDataProse.lua), Tester Testerson, with a week of
-- history -- questing sessions, two dungeon visits, rares, trades, chat, a
-- seen-around stretch, notes the user wrote -- so the profile timeline
-- (TLN-1 to TLN-10) can be looked at in the client without playing it all
-- first; and a made-up route under it for Your Diary (8.11).
--
-- Everything is written through the modules capture writes through, timed
-- relative to now. The GUID is not a real character's (realm 0000), and every
-- session and visit is marked `test`, so /sd testdata remove takes it all
-- out again. Writing again replaces the last copy.
--
-- Development tooling, but the in-client test runbooks use it: it stays in
-- the TOC's Dev/ block until a release drops that.

local addonName, ns = ...

local TestData = {}
ns.TestData = TestData

local GUID = "Player-0000-7E57E570"
TestData.GUID = GUID

local MIN, HOUR, DAY = 60, 60 * 60, 24 * 60 * 60

-- An item link as the client writes one; a feature's Dev.lua makes its
-- items' with it too.
local function Link(quality, id, name)
    return ("|cnIQ%d:|Hitem:%d::::::::::::|h[%s]|h|r"):format(quality, id, name)
end
TestData.Link = Link

-- Other group members of the visits: only names, they are not diary entries.
local KAELITH = { guid = "Player-0000-7E57E571", first = "Kaelith", surname = "Dawnsong", class = "DRUID", role = "HEALER" }
local BROM = { guid = "Player-0000-7E57E572", first = "Brom", surname = "Ironhide", class = "WARRIOR", role = "TANK" }
local ZURI = { guid = "Player-0000-7E57E573", first = "Zuri", surname = "Nightfang", class = "PRIEST", role = "DAMAGER" }

local function Me()
    return { guid = ns.ownGUID, first = "You", role = "DAMAGER" }
end

local function Tester()
    return { guid = GUID, first = "Tester", surname = "Testerson", class = "SHAMAN", role = "DAMAGER" }
end

-- Closed, so it never becomes the open session.
local function Session(start, seconds, zones, p, extra)
    p.since, p.last, p.seconds = start, start + seconds, seconds
    local opts = {
        source = "group", test = true, startedAt = start, endedAt = start + seconds,
        participants = { [GUID] = p }, zones = zones,
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return ns.Sessions.New(opts)
end

local function Visit(visit)
    visit.test = true
    return ns.Instances.New(visit)
end
TestData.Visit = Visit

-- The zone alone, as written: where the user stands now would be wrong. The
-- session is the one given or none, never whatever happens to be open.
local function Row(kind, time, zone, data, session)
    data = data or {}
    data.time = time
    data.where = { zone = zone }
    data.session = session and session.id or false
    return ns.Interactions.Add(GUID, kind, data)
end

local function Quests(n, from)
    local list = {}
    for i = 1, n do list[i] = from + i end
    return list
end

--------------------------------------------------------------------------
-- A feature's own test data (Features/<Name>/Dev.lua)
--------------------------------------------------------------------------
--
-- A feature adds its part of /sd testdata from its own folder:
-- TestData.Register(point, fn) has fn(c) called at `point` of the script
-- below, after what is written there already, in the order the features
-- registered. Each point is where capture would have written a feature's
-- records, so they land in the same order among the rest:
--
--   "tester"  TestData.Write, after each of Tester's four sessions' rows:
--             c.n (1 to 4, oldest first), c.session (its record:
--             startedAt, endedAt, id, ...), c.now, and c.Row(kind, time,
--             zone, data, session): a row on Tester (TestData.GUID), the
--             zone alone as written, in the session given (or none)
--   "route"   TestData.WriteJourney, the route written: c.j (the route,
--             to write a feature's list on as capture keeps it), c.now,
--             and c.Stop(level, subZone) → the first stop made at that
--             level there, { from, to, level, subZone, mapID, x, y }, to
--             time a record by (an error where there is none, so a changed
--             route is noticed rather than silently missed)
--   "beat"    TestData.Write, at Tester's other moments, for rows that
--             fall between the script's own rather than after a
--             session's: c.at says which, c.t when it is
--               "met"     six days ago, Tester still a stranger, before
--                         the first trade (c.t: the evening's first
--                         moment)
--               "traded"  that trade's moment, before the add (c.t: the
--                         trade's time): the trade itself, then what
--                         came after it, in TOC order
--               "began"   session c.n (1 to 4) just made, before its
--                         rows (c.session, c.t its start)
--               "now"     the end, after the notes and the pulses seen
--                         around (c.t: c.now)
--             with c.now and c.Row as at "tester"
--
--   "remove"  TestData.Remove (/sd testdata remove, and the start of
--             every /sd testdata), after the route is taken out and
--             before Tester is forgotten: for what a feature wrote that is
--             neither on the route nor on Tester (strangers it pencilled
--             in: Characters.Forget). c is empty.
--
-- What is written on the route or on Tester goes again with /sd testdata
-- remove, so a feature that writes only there needs no "remove" of its
-- own.

local points = { tester = {}, route = {}, beat = {}, remove = {} }

function TestData.Register(point, fn)
    assert(points[point] and type(fn) == "function",
        "TestData.Register(\"tester\", \"beat\", \"route\" or \"remove\", fn)")
    local list = points[point]
    list[#list + 1] = fn
end

local function Point(point, c)
    for _, fn in ipairs(points[point]) do fn(c) end
end

--------------------------------------------------------------------------
-- Your Diary (8.11): a made-up route for the logged-in character
--------------------------------------------------------------------------
--
-- Levels 10 to 16 over six evenings, several zones a level: a grinding
-- stop, roads, the hearthstone (no line drawn across), a city, a flight, a
-- dungeon pinned at its door, then two weeks at a pretend cap of 16 (the
-- client's own is far above), timed to lie under Tester's sessions, notes
-- and a fight, so the map plates have meetings on them. The real route is
-- parked while it is here and comes back with /sd testdata remove; capture
-- leaves a test route alone.

local DUROTAR, BARRENS, ORGRIMMAR, STONETALON = 1411, 1413, 1454, 1442
local JOURNEY_CAP = 16

function TestData.RemoveJourney()
    local guid = ns.ownGUID
    local j = guid and ns.db.journey[guid]
    if not (j and j.test) then return false end
    local parked = ns.db.journeyParked
    ns.db.journey[guid] = parked and parked[guid] or nil
    if parked then
        parked[guid] = nil
        if next(parked) == nil then ns.db.journeyParked = nil end
    end
    ns.Journey.Touch()
    return true
end

function TestData.WriteJourney(now)
    TestData.RemoveJourney()
    local guid = ns.ownGUID
    if not guid then return nil end
    local J = ns.Journey
    if ns.db.journey[guid] then
        ns.db.journeyParked = ns.db.journeyParked or {}
        ns.db.journeyParked[guid] = ns.db.journey[guid]
    end

    local start = ns.DayStart(now - 20 * DAY) + 18 * HOUR
    local j = { startedAt = start, startLevel = 10, startMapID = DUROTAR, levels = {}, segments = {}, marks = {},
        test = { maxLevel = JOURNEY_CAP, level = JOURNEY_CAP } }
    ns.db.journey[guid] = j

    local level, t = 10, start
    local stops = {}
    local function Push(seg)
        seg.levelFrom, seg.levelTo = level, level
        j.segments[#j.segments + 1] = J.Pack(seg)
    end
    local function Road(seconds, map, pts)
        Push({ kind = "road", from = t, to = t + seconds, mapID = map, pts = J.PackPoints(pts) })
        t = t + seconds
    end
    local function Stop(seconds, map, x, y, r, act, sub)
        Push({ kind = "stop", from = t, to = t + seconds, mapID = map, x = x, y = y, r = r, seconds = seconds,
            act = act, subZone = sub })
        stops[#stops + 1] = { from = t, to = t + seconds, level = level, subZone = sub, mapID = map, x = x, y = y }
        t = t + seconds
    end
    local function Flight(seconds, map1, x1, y1, map2, x2, y2)
        Push({ kind = "flight", from = t, to = t + seconds, mapID = map1, mapID1 = map1, x1 = x1, y1 = y1,
            mapID2 = map2, x2 = x2, y2 = y2 })
        t = t + seconds
    end
    local function Dungeon(seconds, map, x, y, id, name)
        Push({ kind = "dungeon", from = t, to = t + seconds, mapID = map, x = x, y = y, instanceID = id,
            instanceType = "party", name = name, seconds = seconds })
        t = t + seconds
    end
    local function Ding(map, x, y, sub)
        level = level + 1
        j.levels[level] = { at = t, mapID = map, x = x, y = y, subZone = sub }
    end
    -- (What the features note on the route is their own, at "route":
    -- TestData.Register, at the foot.)

    -- Level 10: Durotar, grinding by Razor Hill, Sen'jin, then west into
    -- The Barrens (the border splits the road).
    Road(600, DUROTAR, { 0.52, 0.44, 0.50, 0.48, 0.47, 0.52, 0.45, 0.55 })
    Stop(1500, DUROTAR, 0.45, 0.56, 55, { combat = 900, deaths = 1 }, "Razor Hill")
    Road(480, DUROTAR, { 0.45, 0.56, 0.40, 0.60, 0.36, 0.62, 0.34, 0.66 })
    Stop(420, DUROTAR, 0.34, 0.66, 25, { questsOut = 3, questsIn = 2 }, "Sen'jin Village")
    Road(540, DUROTAR, { 0.34, 0.66, 0.25, 0.60, 0.12, 0.55, 0.03, 0.52 })
    Road(720, BARRENS, { 0.97, 0.32, 0.85, 0.30, 0.70, 0.31, 0.58, 0.30, 0.53, 0.29 })
    Stop(1200, BARRENS, 0.52, 0.30, 40, { questsOut = 4, resting = 600 }, "The Crossroads")
    Ding(BARRENS, 0.52, 0.30, "The Crossroads")

    -- Level 11: the Forgotten Pools, the hearthstone to Orgrimmar, and a
    -- flight back down.
    t = start + DAY
    Road(600, BARRENS, { 0.52, 0.30, 0.48, 0.36, 0.46, 0.40, 0.45, 0.44 })
    Stop(1800, BARRENS, 0.45, 0.45, 70, { combat = 1200 }, "The Forgotten Pools")
    Road(420, BARRENS, { 0.45, 0.45, 0.50, 0.48, 0.56, 0.50, 0.60, 0.52 })
    t = t + 30
    Stop(900, ORGRIMMAR, 0.54, 0.68, 150, { resting = 900 }, "Valley of Strength")
    Flight(240, ORGRIMMAR, 0.45, 0.64, BARRENS, 0.51, 0.30)
    Road(500, BARRENS, { 0.51, 0.30, 0.55, 0.25, 0.58, 0.20, 0.60, 0.16 })
    Stop(1500, BARRENS, 0.60, 0.15, 50, { combat = 800, questsOut = 2 }, "The Sludge Fen")
    Ding(BARRENS, 0.60, 0.15, "The Sludge Fen")

    -- Level 12: west across The Barrens into Stonetalon.
    t = start + 2 * DAY
    Road(700, BARRENS, { 0.60, 0.15, 0.52, 0.20, 0.42, 0.24, 0.35, 0.27, 0.30, 0.28 })
    Stop(1200, BARRENS, 0.30, 0.28, 45, { combat = 600 })
    Road(600, BARRENS, { 0.30, 0.28, 0.22, 0.25, 0.14, 0.22, 0.05, 0.20 })
    Road(900, STONETALON, { 0.90, 0.80, 0.82, 0.74, 0.76, 0.66, 0.73, 0.60 })
    Stop(1500, STONETALON, 0.72, 0.60, 55, { combat = 900, questsOut = 1 }, "Windshear Crag")
    Ding(STONETALON, 0.72, 0.60, "Windshear Crag")

    -- Level 13: back to The Barrens and into the Wailing Caverns.
    t = start + 3 * DAY
    Road(800, STONETALON, { 0.72, 0.60, 0.78, 0.70, 0.85, 0.78, 0.95, 0.86 })
    Road(700, BARRENS, { 0.06, 0.22, 0.20, 0.28, 0.32, 0.33, 0.42, 0.36, 0.46, 0.36 })
    Dungeon(3000, BARRENS, 0.46, 0.36, 43, "Wailing Caverns")
    Road(400, BARRENS, { 0.46, 0.36, 0.49, 0.33, 0.52, 0.30 })
    Stop(600, BARRENS, 0.52, 0.30, 30, { questsOut = 3, resting = 500, deaths = 1 }, "The Crossroads")
    -- An hour the route did not keep, before the level ends.
    t = t + 3600
    Ding(BARRENS, 0.52, 0.30, "The Crossroads")

    -- Level 14: one long evening at Camp Taurajo.
    t = start + 4 * DAY
    Road(900, BARRENS, { 0.52, 0.30, 0.50, 0.40, 0.48, 0.50, 0.47, 0.58 })
    Stop(2400, BARRENS, 0.47, 0.58, 60, { combat = 1600, deaths = 2 }, "Camp Taurajo")
    Ding(BARRENS, 0.47, 0.58, "Camp Taurajo")

    -- Level 15: the Raptor Grounds; level 16 is the pretend cap.
    t = start + 5 * DAY
    Road(800, BARRENS, { 0.47, 0.58, 0.44, 0.66, 0.42, 0.74, 0.44, 0.82 })
    Stop(2100, BARRENS, 0.44, 0.82, 50, { combat = 1400 }, "Raptor Grounds")
    Road(600, BARRENS, { 0.44, 0.82, 0.48, 0.74, 0.50, 0.64 })
    Stop(900, BARRENS, 0.50, 0.63, 35, { questsOut = 2 })
    Ding(BARRENS, 0.50, 0.63)

    -- Two weeks at the cap, under Tester's sessions (TestData.Write).
    t = now - 12 * DAY
    Road(600, BARRENS, { 0.50, 0.63, 0.53, 0.52, 0.56, 0.44 })
    Stop(1800, BARRENS, 0.56, 0.42, 45, { combat = 1000, deaths = 1 }, "Lushwater Oasis")
    t = now - 9 * DAY
    Flight(260, BARRENS, 0.51, 0.30, ORGRIMMAR, 0.45, 0.64)
    Stop(1200, ORGRIMMAR, 0.50, 0.70, 150, { resting = 1200 }, "Valley of Strength")
    t = now - 6 * DAY + 200
    Road(100, BARRENS, { 0.52, 0.36, 0.55, 0.41 })
    Stop(2700, BARRENS, 0.55, 0.42, 50, { combat = 1500, questsOut = 5 }, "Lushwater Oasis")
    t = now - DAY - 5 * HOUR
    Stop(3600, BARRENS, 0.50, 0.35, 60, { combat = 2000 }, "Razormane Grounds")
    Dungeon(52 * MIN, BARRENS, 0.46, 0.36, 43, "Wailing Caverns")
    Road(600, BARRENS, { 0.46, 0.36, 0.35, 0.30, 0.22, 0.25, 0.05, 0.20 })
    Road(600, STONETALON, { 0.90, 0.80, 0.80, 0.72, 0.72, 0.62 })
    Stop(2700, STONETALON, 0.71, 0.61, 55, { combat = 1200, questsOut = 4, deaths = 1 }, "Windshear Crag")
    t = now - 4 * HOUR
    Road(180, BARRENS, { 0.44, 0.82, 0.43, 0.88, 0.43, 0.90 })
    Dungeon(35 * MIN, BARRENS, 0.43, 0.90, 47, "Razorfen Kraul")
    t = now - 90 * MIN
    Stop(1200, BARRENS, 0.52, 0.30, 40, { questsOut = 2, resting = 300 }, "The Crossroads")

    -- The features' own (TestData.Register).
    Point("route", { j = j, now = now, Stop = function(lv, sub)
        for _, stop in ipairs(stops) do
            if stop.level == lv and stop.subZone == sub then return stop end
        end
        error(("TestData: no stop at level %s in %s"):format(tostring(lv), tostring(sub)), 2)
    end })

    J.Touch()
    return j
end

function TestData.Remove()
    TestData.RemoveJourney()
    Point("remove", {})
    local had = ns.db.characters[GUID] ~= nil
    -- Every test session has Tester as its only participant, so forgetting
    -- them drops those sessions. A visit outlives one member, though, so the
    -- made-up ones go by their mark.
    ns.Characters.Forget(GUID)
    -- And the runs' other members, seen for their cards.
    for _, m in ipairs({ BROM, KAELITH, ZURI }) do
        if ns.db.characters[m.guid] and not ns.Diary.IsDiary(m.guid) then ns.Characters.Forget(m.guid) end
    end
    for _, visit in ipairs(ns.Instances.All()) do
        if visit.test then ns.Instances.Remove(visit.id) end
    end
    return had
end

function TestData.Write(now)
    TestData.Remove()
    now = now or ns.Now()

    ns.Characters.Observe(GUID, {
        first = "Tester", surname = "Testerson", class = "SHAMAN", race = "Orc",
        faction = "Horde", level = 22, sex = 2, time = now - 6 * DAY - HOUR,
    })
    -- The dungeon runs' other members, seen as they grouped: strangers, not
    -- in the diary, of the races their business cards are told by on the
    -- map (UI/Dungeon/Cards.lua): a dwarf's, a gnome's and a night elf's.
    for _, m in ipairs({ { BROM, "Dwarf", 22 }, { ZURI, "Gnome", 21 }, { KAELITH, "NightElf", 22 } }) do
        ns.Characters.Observe(m[1].guid, { first = m[1].first, surname = m[1].surname, class = m[1].class,
            race = m[2], faction = "Horde", level = m[3], sex = 2, time = now - 4 * HOUR })
    end

    -- Six days ago: chat and a trade with a stranger (the features', at
    -- "met" and "traded"), then the add, then a first questing session
    -- (TLN-8: the add sits above the exchange).
    local function Beat(at, t, n, session)
        Point("beat", { at = at, t = t, n = n, session = session, now = now, Row = Row })
    end

    local t1 = now - 6 * DAY
    Beat("met", t1)
    Beat("traded", t1 + 90)

    local entry = ns.Diary.Add(GUID, { source = "test" })
    if not entry then
        ns.Print("could not write the test character.")
        return nil
    end
    entry.addedAt = t1 + 100
    entry.addedContext.zone = "The Barrens"
    entry.note = "Test data from /sd testdata. Remove it with /sd testdata remove."
    entry.tags = { "test" }
    entry.relationship = "questing buddy"

    local s1 = Session(t1 + 300, 45 * MIN, { "The Barrens" },
        { quests = Quests(5, 800), levelStart = 17, levelEnd = 18 },
        { deaths = { [ns.ownGUID] = 1 }, deathLog = {
            { guid = ns.ownGUID, time = t1 + 300 + 20 * MIN, zone = "The Barrens", subZone = "Lushwater Oasis",
                killer = { source = "recap", name = "Kolkar Pack Runner", npcID = 3274, attackers = 2 } },
        } })
    Beat("began", s1.startedAt, 1, s1)
    Point("tester", { n = 1, session = s1, now = now, Row = Row })

    -- Yesterday: three hours of questing with a dungeon in the middle, a rare
    -- and (at "tester") a green trade (TLN-3: three activities named; TLN-4:
    -- the dungeon in a block of its own).
    local t2 = now - DAY - 5 * HOUR
    local s2 = Session(t2, 3 * HOUR + 5 * MIN, { "The Barrens", "Stonetalon Mountains" },
        { quests = Quests(14, 900), levelStart = 18, levelEnd = 21,
            rares = { { name = "Humar the Pridelord", npcID = 5828, kind = "rare", time = t2 + 40 * MIN } } },
        -- One of the user's deaths has no record: older sessions only counted.
        -- Tester's death in Wailing Caverns is the run's (TLN-11): neither a
        -- line beside its card nor counted on the session.
        { deaths = { [ns.ownGUID] = 2, [GUID] = 2 }, others = 3, deathLog = {
            { guid = GUID, time = t2 + 80 * MIN, zone = "Wailing Caverns",
                killer = { source = "recap", name = "Lord Cobrahn", npcID = 3669 } },
            { guid = ns.ownGUID, time = t2 + 25 * MIN, zone = "The Barrens", subZone = "Razormane Grounds",
                killer = { source = "recap", name = "Razormane Geomancer", npcID = 3269, spell = "Fireball",
                    attackers = 3 } },
            { guid = GUID, time = t2 + 2 * HOUR + 50 * MIN, zone = "Stonetalon Mountains",
                killer = { source = "target", name = "Venture Co. Logger", npcID = 3989 } },
        } })
    Beat("began", s2.startedAt, 2, s2)
    Visit({
        instanceID = 43, name = "Wailing Caverns", instanceType = "party", difficulty = "Normal",
        startedAt = t2 + 60 * MIN, endedAt = t2 + 112 * MIN,
        members = { Tester(), Me(), KAELITH, BROM, ZURI },
        bossesKilled = { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum" },
        bossTotal = 8, deaths = 4, wipes = 1, sessionIds = { s2.id },
    })
    Point("tester", { n = 2, session = s2, now = now, Row = Row })

    -- Today: a session that was only a dungeon run (it gives way to the
    -- visit), then a short questing session with a rare and (at "tester") a
    -- trade: jerky, and a blue.
    local t3 = now - 4 * HOUR
    local s3 = Session(t3, 40 * MIN, { "Razorfen Kraul" },
        { levelStart = 21, levelEnd = 22 }, { others = 3 })
    Beat("began", s3.startedAt, 3, s3)
    -- As the capture writes a run (Core/Instances.lua): the pulls, a wipe
    -- on Aggem and a ghost run after it, a death to trash on the way to
    -- Jargba, Jargba nearly lost (two down in the kill), a long last fight
    -- with Ramtusk, and three bosses' loot, one for Tester (a diary entry),
    -- an epic and a blue for the user, for the map's notes and its marks
    -- (Core/DungeonRun.lua; UI/Dungeon/Print.lua's flavour). Tester's level
    -- 22 falls in it too (Features/LevelUps/Dev.lua). Its rolls (pass B): a
    -- blue Zuri snagged from the user at Ramtusk, 80 against her 85; Brom's
    -- Need of 2 on green boots found on the way to Jargba; and the charm
    -- off Jargba, which the user needed and lost to Zuri on an earlier run
    -- (nine days ago, below: without Tester, so on no timeline of his),
    -- finally theirs.
    local at = function(m) return t3 + m * MIN end
    local CHARM = "|cnIQ4:|Hitem:6685::::::::22:1491::::::::|h[Spiteful Death Charm]|h|r"
    local early = now - 9 * DAY
    Visit({
        instanceID = 47, name = "Razorfen Kraul", instanceType = "party", difficulty = "Normal",
        startedAt = early, endedAt = early + 40 * MIN,
        members = { Me(), BROM, KAELITH, ZURI },
        bossesKilled = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba" },
        bossTotal = 6, spans = { { from = early, to = early + 40 * MIN } },
        rolls = {
            { key = "test:early:1", item = CHARM, itemID = 6685, time = early + 25 * MIN,
                need = { [ns.ownGUID] = 41, [ZURI.guid] = 77 }, winner = ZURI.guid, winRoll = 77, winNeed = true },
        },
    })
    Visit({
        instanceID = 47, name = "Razorfen Kraul", instanceType = "party", difficulty = "Normal",
        startedAt = at(3), endedAt = at(38),
        members = { Tester(), Me(), BROM, KAELITH, ZURI },
        bossesKilled = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk" },
        bossTotal = 6, deaths = 6, wipes = 1, sessionIds = { s3.id },
        spans = { { from = at(3), to = at(14), ghost = true }, { from = at(16), to = at(38) } },
        pulls = {
            { id = 2773, name = "Roogug", start = at(7), stop = at(8), killed = true },
            { id = 2774, name = "Aggem Thorncurse", start = at(12), stop = at(13) },
            { id = 2774, name = "Aggem Thorncurse", start = at(18), stop = at(20), killed = true },
            { id = 2775, name = "Death Speaker Jargba", start = at(26), stop = at(27), killed = true },
            { id = 2776, name = "Overlord Ramtusk", start = at(28), stop = at(38), killed = true },
        },
        deathLog = {
            { guid = BROM.guid, time = at(12) + 30, pull = 2, killer = { name = "Aggem Thorncurse", npcID = 4424 } },
            { guid = ZURI.guid, time = at(12) + 45, pull = 2, killer = { name = "Aggem Thorncurse", npcID = 4424 } },
            { guid = KAELITH.guid, time = at(12) + 50, pull = 2, killer = { name = "Aggem Thorncurse", npcID = 4424 } },
            { guid = ns.ownGUID, time = at(23), killer = { name = "Razorfen Defender", npcID = 4442 } },
            { guid = BROM.guid, time = at(26) + 20, pull = 4, killer = { name = "Death Speaker Jargba", npcID = 4428 } },
            { guid = KAELITH.guid, time = at(26) + 40, pull = 4, killer = { name = "Death Speaker Jargba", npcID = 4428 } },
        },
        loot = {
            { guid = GUID, item = "|cnIQ3:|Hitem:6681::::::::22:1491::::::::|h[Thornspike]|h|r",
                itemID = 6681, time = at(20) + 20 },
            { guid = ns.ownGUID, item = "|cnIQ4:|Hitem:6685::::::::22:1491::::::::|h[Spiteful Death Charm]|h|r",
                itemID = 6685, time = at(27) + 15 },
            { guid = ns.ownGUID, item = "|cnIQ3:|Hitem:6686::::::::22:1491::::::::|h[Tusken Helm]|h|r",
                itemID = 6686, time = at(38) },
        },
        rolls = {
            { key = "test:rfk:1", item = "|cnIQ3:|Hitem:6687::::::::22:1491::::::::|h[Gnarled Tusk Band]|h|r",
                itemID = 6687, time = at(38) + 30, need = { [ns.ownGUID] = 80, [ZURI.guid] = 85 },
                winner = ZURI.guid, winRoll = 85, winNeed = true },
            { key = "test:rfk:2", item = "|cnIQ2:|Hitem:990101::::::::22:1491::::::::|h[Moss-Stitched Boots]|h|r",
                itemID = 990101, time = at(24), need = { [BROM.guid] = 2, [KAELITH.guid] = 57 },
                winner = KAELITH.guid, winRoll = 57, winNeed = true },
            { key = "test:rfk:3", item = CHARM, itemID = 6685, time = at(27) + 10,
                need = { [ns.ownGUID] = 64, [ZURI.guid] = 12 }, winner = ns.ownGUID, winRoll = 64, winNeed = true },
        },
    })
    Point("tester", { n = 3, session = s3, now = now, Row = Row })

    local t4 = now - 90 * MIN
    local s4 = Session(t4, 15 * MIN, { "The Barrens" },
        { quests = Quests(2, 950), levelStart = 22, levelEnd = 22,
            rares = { { name = "Rocklance", npcID = 3270, kind = "rare", time = t4 + 5 * MIN } } })
    Beat("began", s4.startedAt, 4, s4)
    Point("tester", { n = 4, session = s4, now = now, Row = Row })

    -- Notes (DIA-11, TLN-10): one in a session, one in the dungeon inside
    -- yesterday's session, and one written when nothing was going on.
    local function Note(time, zone, text)
        ns.Notes.Add(GUID, text, { time = time, where = { zone = zone } })
    end
    Note(t1 + 300 + 40 * MIN, "The Barrens", "Tester knows every Kolkar camp by heart.")
    Note(t2 + 100 * MIN, "Wailing Caverns", "Skum took three tries. Tester never gave up.")
    Note(now - 60 * MIN, "Orgrimmar", "Promised to help with Sludge Fen tomorrow.")

    -- Seen around since, six pulses five minutes apart, and a word just
    -- now. Every row above is written oldest first, the order capture keeps.
    for i = 0, 5 do
        ns.Sessions.Around(GUID, now - 40 * MIN + i * 5 * MIN, "Durotar")
    end
    Beat("now", now)

    -- Your Diary's made-up route, under all of the above.
    TestData.WriteJourney(now)

    -- The entry's fields above were written by hand, past Diary's setters.
    ns.Touch()
    return entry
end

ns.Slash.Register("testdata", function(rest)
    if rest == "remove" then
        if TestData.Remove() then
            ns.Print("removed the test data.")
        else
            ns.Print("there was no test data.")
        end
        ns.Fire("SD_DIARY_CHANGED")
    elseif TestData.Write() then
        ns.Print("wrote |cffffffffTester Testerson|r: a week of sessions, two dungeon runs, rares,"
            .. " trades and chat; |cffffffffTessa Testerson|r: three months of sessions for |cffffd100/sd prose|r;"
            .. " and a made-up route for this character in Your Diary (yours is put"
            .. " aside meanwhile). |cffffd100/sd testdata remove|r takes it out again.")
        ns.UI.ShowJournal(GUID)
        ns.Fire("SD_DIARY_CHANGED")
    end
end, "write two made-up diary entries, Tester Testerson with a week of history and Tessa Testerson"
    .. " with three months for /sd prose, and a made-up route in Your Diary; |cffffd100/sd testdata remove|r removes both", { dev = true })
