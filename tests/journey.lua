-- Your Diary (prd.md 8.11, JRN-1 to JRN-20): the compaction on made-up
-- samples, the capture on the mock's client, the recap, meetings on the
-- route, and the storage a whole levelling run takes.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local J, R, Text = ns.Journey, ns.JourneyRecap, ns.UI.JourneyText
local TUNE = J.T
local SELF = F.SELF

-- Mulgore lies at 0,0 in the mock's world, 5000 by 3333 yards; The Barrens
-- east of it, 6000 by 4000 (tests/wowmock.lua, M.mapRects).
local MULGORE, BARRENS, CAVE = 1412, 1413, 2000
local RECT = { [MULGORE] = { 0, 0, 5000, 3333 }, [BARRENS] = { 5000, 0, 6000, 4000 } }

-- A sample at world yards wx, wy, on `map`.
local function S(t, wx, wy, extra)
    extra = extra or {}
    local map = extra.mapID or MULGORE
    local r = RECT[map]
    local s = { t = t, wx = wx, wy = wy, inst = 1, mapID = map,
        x = J.Round((wx - r[1]) / r[3]), y = J.Round((wy - r[2]) / r[4]), level = 10 }
    for k, v in pairs(extra) do s[k] = v end
    return s
end

local function Kinds(j, kind)
    local n = 0
    for _, seg in ipairs(J.Segments(j)) do
        if seg.kind == kind then n = n + 1 end
    end
    return n
end

local function Of(j, kind)
    local list = {}
    for _, seg in ipairs(J.Segments(j)) do
        if seg.kind == kind then list[#list + 1] = seg end
    end
    return list
end

-- A road's points back in yards, for distances.
local function Yards(seg)
    local pts, r, list = J.Points(seg), RECT[seg.mapID], {}
    for i = 1, #pts, 2 do list[#list + 1] = { r[1] + pts[i] * r[3], r[2] + pts[i + 1] * r[4] } end
    return list
end

local nextGuid = 0
local function Fresh(level, mapID, at)
    nextGuid = nextGuid + 1
    local guid = ("Player-0000-JRN%05d"):format(nextGuid)
    return J.Begin(guid, at or 1000000, level or 10, mapID or MULGORE), guid
end

-- A deterministic stream of numbers in 0..1, for wandering.
local function Rand(seed)
    local state = seed
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end

--------------------------------------------------------------------------
Section("grinding back and forth is one stop (JRN-3)")

local j = Fresh()
local t = 1000000
-- Walk in from the west at running speed, 35 yards a tick...
for i = 0, 14 do
    J.Feed(j, S(t, 500 + i * 35, 1000))
    t = t + 5
end
-- ...grind back and forth across 80 yards for a quarter of an hour, with a
-- pull out to 75 yards now and then...
local rand = Rand(7)
for i = 1, 180 do
    local wx = (i % 2 == 0) and 965 or 1035
    local wy = 1000 + (rand() - 0.5) * 50
    if i % 40 == 0 then wx = 1075 end
    J.Feed(j, S(t, wx, wy))
    t = t + 5
end
-- ...and walk off east.
for i = 1, 30 do
    J.Feed(j, S(t, 1000 + i * 35, 1000))
    t = t + 5
end
J.Settle(j)

Eq(Kinds(j, "stop"), 1, "the grinding became more or less than one stop")
Eq(Kinds(j, "road"), 2, "a road in, a road out")
local stop = Of(j, "stop")[1]
Check(stop.seconds >= 14 * 60 and stop.seconds <= 16 * 60, "the stop's time: " .. stop.seconds)
Check(math.abs(stop.x - 0.2) < 0.01, "the stop's centre is not the time-weighted mean: " .. stop.x)
Check(stop.r >= TUNE.rMin and stop.r <= TUNE.rMax, "the stop's spread is not clamped: " .. stop.r)
Eq(J.Segments(j)[1].kind, "road", "the road in comes first")
Eq(J.Segments(j)[2], stop, "the stop between the roads")
-- The road in ends where the stop began; no point of a road lies inside it.
for _, road in ipairs(Of(j, "road")) do
    Check(road.to <= stop.from or road.from >= stop.to, "a road overlaps the stop in time")
end

--------------------------------------------------------------------------
Section("steady travel is one thinned road (JRN-4)")

j = Fresh()
t = 2000000
local samples = 0
for i = 0, 80 do
    -- A long gentle curve, 35 yards a tick.
    local a = i / 80 * math.pi / 3
    J.Feed(j, S(t, 300 + i * 35, 1000 + math.sin(a) * 400))
    t = t + 5
    samples = samples + 1
end
J.Settle(j)
Eq(Kinds(j, "road"), 1, "steady travel made more or less than one road")
Eq(Kinds(j, "stop"), 0, "steady travel made a stop")
local road = Of(j, "road")[1]
local n = #J.Points(road) / 2
Check(n >= 3 and n < samples / 3, "the road was not thinned: " .. n .. " of " .. samples)
Check(n <= TUNE.points, "a road over its point cap")
Eq(J.Points(road)[1], J.Round(300 / 5000), "the road starts where the player did")

--------------------------------------------------------------------------
Section("a teleport ends the road, with nothing drawn across (JRN-4)")

j = Fresh()
t = 3000000
for i = 0, 20 do
    J.Feed(j, S(t, 500 + i * 30, 500))
    t = t + 5
end
-- The hearthstone: 2000 yards in one tick.
for i = 0, 20 do
    J.Feed(j, S(t, 3000 + i * 30, 2500))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "road"), 2, "the teleport did not end the road")
-- Each road keeps to its side of the jump: nothing joins the two.
for i, r in ipairs(Of(j, "road")) do
    for _, p in ipairs(Yards(r)) do
        Check((i == 1 and p[1] <= 1101) or (i == 2 and p[1] >= 2999), "a road has a line across the teleport")
    end
end

--------------------------------------------------------------------------
Section("a tick long after the last pauses (JRN-2)")

j = Fresh()
t = 4000000
for i = 0, 10 do
    J.Tick(j, t)
    J.Feed(j, S(t, 500 + i * 30, 500))
    t = t + 5
end
t = t + 90  -- a loading screen
Eq(J.Tick(j, t), true, "a 90 s gap was not a pause")
Eq(Kinds(j, "road"), 1, "the gap did not close the road")
local before = J.Segments(j)[1].to
for i = 0, 10 do
    J.Tick(j, t)
    J.Feed(j, S(t, 830 + i * 30, 500))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "road"), 2, "the road after the gap joined the one before")
Check(J.Segments(j)[2].from > before + 60, "a road spans the gap")
Eq(J.Tick(j, t + 30), false, "a tick within the gap counted as a pause")

--------------------------------------------------------------------------
Section("zone borders split segments (JRN-4)")

j = Fresh()
t = 5000000
for i = 0, 20 do
    local wx = 4700 + i * 30
    J.Feed(j, S(t, wx, 1000, { mapID = wx < 5000 and MULGORE or BARRENS }))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "road"), 2, "crossing into The Barrens did not split the road")
Eq(J.Segments(j)[1].mapID, MULGORE, "the first road's map")
Eq(J.Segments(j)[2].mapID, BARRENS, "the second road's map")
for _, seg in ipairs(J.Segments(j)) do
    for i = 1, #J.Points(seg) do
        local v = J.Points(seg)[i]
        Check(v >= 0 and v <= 1, "a point off its zone map")
    end
end

--------------------------------------------------------------------------
Section("cities are a stop, without breadcrumbs (JRN-2)")

j = Fresh()
t = 5500000
for i = 0, 10 do
    J.Feed(j, S(t, 1000 + i * 30, 1000))
    t = t + 5
end
-- Round the city at a run, 300 yards across: bank, auction house, trainer.
for i = 0, 60 do
    J.Feed(j, S(t, 1450 - math.cos(i * 0.23) * 150, 1000 + math.sin(i * 0.23) * 150,
        { city = true, resting = true }))
    t = t + 5
end
for i = 1, 10 do
    J.Feed(j, S(t, 1600 + i * 30, 1000))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "stop"), 1, "the city was not one stop")
local city = Of(j, "stop")[1]
Check(city.act and (city.act.resting or 0) >= 240, "the city's resting time not kept")
Eq(city.r, TUNE.rMax, "a city's spread not clamped to the most")
for _, r in ipairs(Of(j, "road")) do
    Check(r.to <= city.from or r.from >= city.to, "a road runs through the city")
end

--------------------------------------------------------------------------
Section("consecutive stops on one spot merge (JRN-3)")

j = Fresh()
t = 5800000
for i = 1, 50 do
    J.Feed(j, S(t, 1000 + (i % 3) * 10, 1000))
    t = t + 5
end
-- A short trip to a vendor 120 yards away and back.
for i = 1, 6 do
    J.Feed(j, S(t, 1000 + i * 20, 1000))
    t = t + 5
end
for i = 1, 6 do
    J.Feed(j, S(t, 1120 - i * 20, 1000))
    t = t + 5
end
for i = 1, 50 do
    J.Feed(j, S(t, 1000 + (i % 3) * 10, 1005))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "stop"), 1, "two stops on one spot were not merged")
Eq(Kinds(j, "road"), 0, "the short road between them was kept")
Check(Of(j, "stop")[1].seconds >= 400, "the merged stop lost time: " .. Of(j, "stop")[1].seconds)

--------------------------------------------------------------------------
Section("activity stays with its segment (JRN-6)")

j = Fresh()
t = 6000000
for i = 1, 20 do
    J.Feed(j, S(t, 1000, 1000 + (i % 2) * 5))
    t = t + 5
end
J.FightStart(j, t)
t = t + 40
J.FightEnd(j, t)
J.Act(j, "questsOut", 1)
J.Act(j, "deaths", 1)
for i = 1, 20 do
    J.Feed(j, S(t, 1000, 1000 + (i % 2) * 5))
    t = t + 5
end
J.Settle(j)
local act = Of(j, "stop")[1].act
Eq(act.combat, 40, "the fight's time not kept on the stop")
Eq(act.questsOut, 1, "a quest turned in not kept")
Eq(act.deaths, 1, "a death not kept")
Eq(R.MainActivity(Of(j, "stop")[1]), "fighting", "the stop's main activity")

--------------------------------------------------------------------------
Section("the zone map: sub-maps moved onto it, the rest skipped (JRN-5)")

mock.mapID, mock.position = CAVE, { x = 0.5, y = 0.5 }
local zone, zx, zy = ns.ZoneWhere()
Eq(zone, MULGORE, "the cave's zone")
Eq(zx, J.Round(1100 / 5000), "the cave's x on Mulgore's map")
Eq(zy, J.Round(1075 / 3333), "the cave's y on Mulgore's map")
-- Without a way through world space, the point is skipped, never stored
-- as zone coordinates.
local rect = mock.mapRects[CAVE]
mock.mapRects[CAVE] = nil
Eq(ns.ZoneWhere(), nil, "an unprojectable sub-map position was kept")
mock.mapRects[CAVE] = rect
-- No zone above (the Deeprun Tram's map is no map at all), and continents.
mock.mapID = 9999
Eq(ns.ZoneWhere(), nil, "a map the client cannot describe gave a point")
mock.mapID = 1414
Eq(ns.ZoneWhere(), nil, "a continent gave a point")
-- A little past the edge reads as the edge.
mock.mapID, mock.position = MULGORE, { x = 1.004, y = -0.002 }
zone, zx, zy = ns.ZoneWhere()
Eq(zx, 1, "past the right edge not clamped")
Eq(zy, 0, "past the top edge not clamped")
mock.position = mock.secret({ x = 0.5, y = 0.5 })
Eq(ns.ZoneWhere(), nil, "a secret position gave a point")
mock.position = { x = mock.secret(0.5), y = 0.5 }
Eq(ns.ZoneWhere(), nil, "a secret coordinate gave a point")
mock.inInstance = true
mock.position = { x = 0.5, y = 0.5 }
Eq(ns.ZoneWhere(), nil, "an instance gave a zone point")
mock.inInstance = false
-- ns.Where is unchanged: it still reports the best map.
mock.mapID = CAVE
Eq(ns.Where().mapID, CAVE, "ns.Where's behaviour changed")
mock.mapID = MULGORE

--------------------------------------------------------------------------
Section("capture on the client: the tick (JRN-1, JRN-2)")

mock.SetUnit("player", F.Like(SELF, { level = 10 }))
local Tick = ns._test.JourneyTick
-- Stand at yards wx, wy in Mulgore: the map and the world agree.
local function At(wx, wy, map)
    map = map or MULGORE
    local r = RECT[map]
    mock.mapID = map
    mock.position = { x = (wx - r[1]) / r[3], y = (wy - r[2]) / r[4] }
    mock.world = { x = wx, y = wy, inst = 1 }
end
local function Step(seconds)
    mock.now = mock.now + (seconds or 5)
    Tick()
end
-- IsMounted is never asked: true on a flight path as well (JRN-2).
_G.IsMounted = function() error("IsMounted was asked") end

Eq(ns.db.journey[SELF.guid], nil, "a route before the first tick")
At(1000, 1000)
Step()
local mine = ns.db.journey[SELF.guid]
Check(mine ~= nil, "the first tick did not begin the route")
Eq(mine.startLevel, 10, "the route's start level")
Eq(mine.startMapID, MULGORE, "the route's start zone")
for i = 1, 20 do
    At(1000 + i * 35, 1000)
    Step()
end
Check(mine.open and mine.open.road, "walking built no road")

-- Inn names and an empty zone text never key anything: the map decides.
mock.zone = "Lakeshire Inn"
for i = 21, 30 do
    At(1000 + i * 35, 1000)
    Step()
end
mock.zone = ""
for i = 31, 40 do
    At(1000 + i * 35, 1000)
    Step()
end
mock.zone = "Mulgore"
J.Settle(mine)
for _, seg in ipairs(J.Segments(mine)) do Eq(seg.mapID, MULGORE, "a segment keyed by the zone text") end
Eq(Kinds(mine, "road"), 1, "the zone text split the road")

-- A secret or missing position is a pause: nothing stored, nothing joined.
local count = #mine.segments
mock.world = { x = mock.secret(5), y = 5, inst = 1 }
Step()
mock.world = nil
Step()
mock.position = nil
Step()
Eq(#mine.segments, count, "an unreadable position stored something")
Eq(mine.open.prev, nil, "an unreadable position left the road open")

-- No position is read in combat.
At(3000, 1000)
Step()
mock.inCombat = true
local reads = 0
local where = ns.ZoneWhere
ns.ZoneWhere = function(...) reads = reads + 1 return where(...) end
Step()
Step()
ns.ZoneWhere = where
mock.inCombat = false
Eq(reads, 0, "the position was read in combat")

-- A duel's fight is no fighting on the route: its result comes before
-- combat ends (SD_DUEL_FINISHED), and its time is not kept. The next
-- fight's is.
do
    local function Fought()
        local o = mine.open
        local into = o.dungeon or o.c or o.road
        return (into and into.act and into.act.combat or 0) + (o.loose and o.loose.combat or 0)
    end
    local before = Fought()
    mock.fire("PLAYER_REGEN_DISABLED")
    mock.now = mock.now + 30
    ns.Fire("SD_DUEL_FINISHED", F.STRANGER.guid, "lost")
    mock.fire("PLAYER_REGEN_ENABLED")
    Eq(Fought(), before, "a duel's fight kept as fighting")
    mock.fire("PLAYER_REGEN_DISABLED")
    mock.now = mock.now + 20
    mock.fire("PLAYER_REGEN_ENABLED")
    Eq(Fought(), before + 20, "the fight after a duel not kept")
    -- Fleeing, combat can end long before the "fled" line (probe, 15 Oct:
    -- 18 s): a fight that ends while a duel is on is the duel's.
    ns.Fire("SD_DUEL_STARTED", F.STRANGER.guid)
    mock.fire("PLAYER_REGEN_DISABLED")
    mock.now = mock.now + 10
    mock.fire("PLAYER_REGEN_ENABLED")
    mock.now = mock.now + 18
    ns.Fire("SD_DUEL_FINISHED", F.STRANGER.guid, "fled")
    Eq(Fought(), before + 20, "a fight in a duel not yet over kept as fighting")
    mock.fire("PLAYER_REGEN_DISABLED")
    mock.now = mock.now + 5
    mock.fire("PLAYER_REGEN_ENABLED")
    Eq(Fought(), before + 25, "the fight after a flight not kept")
end

-- AFK is a pause.
mock.afk = true
Step()
Eq(mine.open.prev, nil, "AFK did not pause")
mock.afk = false

--------------------------------------------------------------------------
Section("taxis are flights, never mounted travel (JRN-9)")

for i = 1, 5 do
    At(2000 + i * 30, 2000)
    Step()
end
local takeOff = mock.now
mock.onTaxi = true
for i = 1, 30 do
    At(2200 + i * 150, 2000 + i * 20)  -- flying, fast
    Step()
end
mock.onTaxi = false
At(6500, 2600, BARRENS)
Step()
local flights = Of(mine, "flight")
Eq(#flights, 1, "the taxi was not one flight")
local flight = flights[1]
Eq(flight.mapID1, MULGORE, "take-off zone")
Eq(flight.mapID2, BARRENS, "landing zone")
Eq(flight.x1, J.Round(2150 / 5000), "take-off spot: the last one before")
Eq(flight.x2, J.Round(1500 / 6000), "landing spot: the first one after")
for _, seg in ipairs(J.Segments(mine)) do
    if seg.kind == "road" or seg.kind == "stop" then
        Check(seg.to <= takeOff + 5 or seg.from >= flight.to, "the flight left a road or a stop")
    end
end

--------------------------------------------------------------------------
Section("dungeons: the entry spot, fresh or nothing; corpse runs (JRN-8)")

for i = 1, 4 do
    At(6500 + i * 30, 2600, BARRENS)
    Step()
end
mock.inInstance, mock.instanceName, mock.instanceID = true, "Wailing Caverns", 43
Step(20)
Step()
local d = mine.open.dungeon
Check(d ~= nil, "entering did not open a dungeon")
Eq(d.mapID, BARRENS, "the dungeon's zone")
Eq(d.x, J.Round(1620 / 6000), "the entry spot is not the last outdoor one")
-- Died inside, released, ran back as a ghost: still the same visit.
mock.inInstance, mock.ghost = false, true
At(6000, 2000, BARRENS)
for _ = 1, 10 do Step() end
Eq(mine.open.dungeon, d, "the corpse run ended the dungeon")
mock.inInstance, mock.ghost = true, false
Step()
Step()
Eq(mine.open.dungeon, d, "back inside did not carry on")
local inside = d.seconds
-- Out, alive: the visit is written.
mock.inInstance = false
At(6600, 2600, BARRENS)
Step()
Eq(mine.open.dungeon, nil, "leaving alive did not end the dungeon")
Eq(Kinds(mine, "dungeon"), 1, "the corpse run made two dungeons")
Eq(inside, 10, "the dungeon's time inside, the corpse run left out")
for _, seg in ipairs(J.Segments(mine)) do
    if seg.kind == "road" or seg.kind == "stop" then
        Check(seg.to < d.from or seg.from > d.from, "the ghost run left a road")
    end
end

-- Summoned in, or ported: the last outdoor spot is too old to be the door.
mock.now = mock.now + 120
Tick()
mock.inInstance, mock.instanceName, mock.instanceID = true, "Ragefire Chasm", 389
mock.now = mock.now + 90
Tick()
Eq(mine.open.dungeon and mine.open.dungeon.x, nil, "a stale spot became the entry")
mock.inInstance = false
At(6600, 2600, BARRENS)
Step()

-- Battlegrounds are no dungeon: a pause.
mock.inInstance, mock.instanceType = true, "pvp"
local dungeons = Kinds(mine, "dungeon")
Step()
Eq(mine.open.dungeon, nil, "a battleground became a dungeon")
Eq(Kinds(mine, "dungeon"), dungeons, "a battleground stored a dungeon")
mock.inInstance, mock.instanceType = false, "party"

--------------------------------------------------------------------------
Section("level-ups (JRN-7)")

At(7000, 2000, BARRENS)
Step()
mock.subZone = "The Crossroads"
mock.fire("PLAYER_LEVEL_UP", 11)
local lvl = mine.levels[11]
Check(lvl ~= nil, "the level-up was not recorded")
Eq(lvl.mapID, BARRENS, "where the level was reached")
Eq(lvl.subZone, "The Crossroads", "the subzone of the level-up")
Eq(lvl.at, mock.now, "when the level was reached")
mock.subZone = ""
for i = 1, 6 do
    At(7000 + i * 30, 2000, BARRENS)
    Step()
end
J.Settle(mine)
Eq(J.Segments(mine)[#mine.segments].levelTo, 11, "the segment's levelTo not marked")
Eq(J.MaxLevel(), 60, "the maximum level is not the client's")
mock.maxLevel = 70
Eq(J.MaxLevel(), 70, "the maximum level is hard-coded")
mock.maxLevel = 60

--------------------------------------------------------------------------
Section("/reload keeps the open segment (JRN-20)")

for i = 1, 45 do
    At(8000 + (i % 2) * 10, 2000, BARRENS)
    Step()
end
Check(mine.open.c and mine.open.c.stop, "setup: a stop is open")
local opened = mine.open.c.since
local segs = #mine.segments
-- A /reload: a fresh copy of the addon on the same saved table.
local saved, savedChar, now = _G.SocialDiaryDB, _G.SocialDiaryCharDB, mock.now
mock.Reset()
_G.SocialDiaryDB, _G.SocialDiaryCharDB = saved, savedChar
mock.now = now + 20
ns = T.Boot()
J, R, Text = ns.Journey, ns.JourneyRecap, ns.UI.JourneyText
mock.SetUnit("player", F.Like(SELF, { level = 11 }))
_G.IsMounted = nil
Tick = ns._test.JourneyTick
mine = ns.db.journey[SELF.guid]
for _ = 1, 10 do
    At(8005, 2000, BARRENS)
    Step()
end
Eq(#mine.segments, segs, "the reload closed the open stop")
Eq(mine.open.c.since, opened, "the reload began a new stop")
-- Back after the gap: it is settled at its last sample.
mock.now = mock.now + 300
At(8005, 2000, BARRENS)
Tick()
Eq(#mine.segments, segs + 1, "a long gap did not settle the open stop")
Eq(J.Segments(mine)[#mine.segments].kind, "stop", "the settled segment")

--------------------------------------------------------------------------
Section("the setting: off keeps nothing new (JRN-17)")

ns.JourneyCapture.SetEnabled(false)
Eq(ns.db.settings.keepRoute, false, "the setting did not switch off")
Eq(ns.JourneyCapture.Running(), false, "the timer still runs")
segs = #mine.segments
for i = 1, 40 do
    At(9000 + i * 30, 2000, BARRENS)
    Step()
end
Eq(#mine.segments, segs, "a route stored with the setting off")
Eq(mine.open.road, nil, "a road built with the setting off")
-- A character that has never been captured gets no record at all.
local other = ns.ownGUID
ns.ownGUID = "Player-0000-NEVER001"
Tick()
Eq(ns.db.journey[ns.ownGUID], nil, "a route begun with the setting off")
ns.ownGUID = other
ns.JourneyCapture.SetEnabled(true)
mock.fire("PLAYER_ENTERING_WORLD")
Eq(ns.JourneyCapture.Running(), true, "the timer did not start again")
Eq(mock.tickers[#mock.tickers].interval, TUNE.tick, "the timer's beat")

--------------------------------------------------------------------------
Section("the raw buffer: only with debug on, and it wraps (JRN-18)")

ns.db.settings.debug = false
At(9000, 2000, BARRENS)
Step()
Eq(J.RawCount(), 0, "raw points written with debug off")
ns.db.settings.debug = true
ns.db.journeyRaw.size = 5
for i = 1, 12 do
    At(9000 + i * 30, 2000, BARRENS)
    Step()
end
local n2, size = J.RawCount()
Eq(size, 5, "the buffer's size")
Eq(n2, 5, "the buffer grew past its size")
local stored = 0
for k in pairs(ns.db.journeyRaw) do
    if type(k) == "number" then stored = stored + 1 end
end
Eq(stored, 5, "the buffer holds more points than its size")
Eq(ns.db.journeyRaw.at, 12 % 5, "the index did not wrap")
Check(ns.db.journeyRaw[2]:find(tostring(mock.now)), "the newest point is not where the index says")
Eq(J.T.raw, 5000, "the default size")
ns.db.settings.debug = false
J.ClearRaw()

--------------------------------------------------------------------------
Section("the recap: one entry per level, several zones in one (JRN-11)")

local h = 3600
j = Fresh(10, MULGORE, 10000000)
local t0 = 10000000
local function Seg(kind, from, to, map, fields)
    local seg = { kind = kind, from = from, to = to, mapID = map, levelFrom = fields.level, levelTo = fields.level }
    for k, v in pairs(fields) do seg[k] = v end
    seg.level = nil
    j.segments[#j.segments + 1] = seg
    return seg
end
Seg("road", t0, t0 + 600, MULGORE, { level = 10, pts = { 0.2, 0.2, 0.3, 0.3 } })
Seg("stop", t0 + 600, t0 + 2400, MULGORE, { level = 10, x = 0.3, y = 0.3, r = 40, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Cloud Mesa" })
Seg("flight", t0 + 2400, t0 + 2700, MULGORE, { level = 10, mapID1 = MULGORE, x1 = 0.3, y1 = 0.3,
    mapID2 = BARRENS, x2 = 0.5, y2 = 0.5 })
Seg("stop", t0 + 2700, t0 + 4500, BARRENS, { level = 10, x = 0.5, y = 0.5, r = 30, seconds = 1800,
    act = { questsOut = 3 } })
j.levels[11] = { at = t0 + 4500, mapID = BARRENS, x = 0.5, y = 0.5, subZone = "The Crossroads" }
Seg("road", t0 + 4500, t0 + 5400, BARRENS, { level = 11, pts = { 0.5, 0.5, 0.6, 0.6 } })
Seg("dungeon", t0 + 5400, t0 + 8400, BARRENS, { level = 11, instanceID = 43, name = "Wailing Caverns",
    instanceType = "party", x = 0.6, y = 0.6, seconds = 3000 })
Seg("stop", t0 + 8400, t0 + 9000, MULGORE, { level = 11, x = 0.4, y = 0.4, r = 20, seconds = 600 })
j.levels[13] = { at = t0 + 9000, mapID = MULGORE, x = 0.4, y = 0.4 }

local recap = R.Build(j, { now = t0 + 10000, level = 13, maxLevel = 60 })
Eq(recap.prologue and recap.prologue.level, 10, "begun at level 10: the prologue")
Eq(R.Build(Fresh(1, MULGORE, t0), { now = t0 + 10, level = 1 }).prologue, nil, "a prologue at level 1")
Eq(#recap.entries, 4, "not one entry per level from 10 to 13")
local e10, e11, e12, e13 = recap.entries[1], recap.entries[2], recap.entries[3], recap.entries[4]
Eq(e10.level, 10, "the first entry's level")
Eq(#e10.places, 2, "level 10's two zones")
Eq(e10.places[1].mapID, MULGORE, "the first zone visited first")
Eq(e10.places[2].mapID, BARRENS, "the second zone second")
Eq(math.floor(e10.places[1].seconds), 2400, "the time in Mulgore")
Eq(e10.stops[1].seg.subZone, "Red Cloud Mesa", "the longest stop first")
Eq(#e10.flights, 1, "the flight in level 10")
Eq(e11.reached.subZone, "The Crossroads", "where level 11 was reached")
-- Each level ends where the next one known was reached (12 went unseen).
Eq(e10.out and e10.out.level, 11, "level 10 does not end where 11 was reached")
Eq(e11.out and e11.out.level, 13, "level 11 does not end where 13 was reached")
Eq(e12.out, nil, "an unseen level has an end")
Eq(e13.out, nil, "the level being played has an end")
local ends = {}
for _, m in ipairs(R.Moments(j, e10, {})) do
    if m.kind == "level" then ends[#ends + 1] = m end
end
Eq(#ends, 1, "level 10's end is not among its moments")
Check(ends[1].out and ends[1].level == 11 and ends[1].mapID == BARRENS, "level 10's end is not level 11 in the Barrens")
Eq(#e11.dungeons, 1, "the dungeon in level 11")
Eq(e11.places[2].name, "Wailing Caverns", "the dungeon among the places, in order")
Eq(e12.known, false, "a level the route never saw begin")
Eq(e12.seconds, 0, "an unseen level has time")
Eq(e13.current, true, "the level being played is not marked")
Eq(Text.Title(e10), "LEVEL 10", "an entry's title")
local lines = Text.Lines(e10, t0 + 10000)
Check(lines[1]:find("^Your road begins here"), "the first entry's opening: " .. lines[1])
local joined = table.concat(lines, " | ")
-- No zone list and no "Went into": the ledger rows under the entry carry
-- the zones, their times and the dungeons; the prose tells the rest.
Check(not joined:find("Mulgore for") and not joined:find("for 40 min") and not joined:find(", then "),
    "the zone-list sentence is still in the prose: " .. joined)
Check(not joined:find("Went into"), "the dungeon sentence is still in the prose: " .. joined)
Check(joined:find("Half an hour of fighting at Red Cloud Mesa%."), "the stops sentence: " .. joined)
Check(not joined:find("mostly fighting") and not joined:find("Longest"), "the stops read like a log: " .. joined)
Check(joined:find("Flew to The Barrens"), "the flight line")
-- Where the time went and the flight are one paragraph.
Check(lines[2] and lines[2]:find("Red Cloud Mesa%. Flew to The Barrens%.$"),
    "the stops and the flight are not one paragraph")
Check(not Text.Lines(e11, t0 + 10000)[2] or not Text.Lines(e11, t0 + 10000)[2]:find("Wailing Caverns"),
    "the dungeon is told in the prose")
-- The wording varies from entry to entry, the same for the same entry.
do
    local stop = { seg = { subZone = "Razormane Grounds", mapID = BARRENS }, seconds = 3600, main = "fighting" }
    local later = { seg = { subZone = "Windshear Crag", mapID = BARRENS }, seconds = 1500, main = "fighting" }
    local quest = { seg = { subZone = "The Crossroads", mapID = BARRENS }, seconds = 1200, main = "questing" }
    local function Entry(level)
        return { kind = "level", level = level, known = true, places = {}, stops = { stop, later, quest },
            flights = {}, people = {}, fights = {}, notes = {}, seconds = 6300 }
    end
    local a, b = Text.Lines(Entry(20))[1], Text.Lines(Entry(21))[1]
    Check(a ~= b, "two entries say their stops the same way: " .. a)
    Eq(Text.Lines(Entry(20))[1], a, "an entry's wording changed between drawings")
    for _, line in ipairs({ a, b }) do
        local _, n = line:gsub("fighting", "")
        Check(n == 1, "the deed is repeated: " .. line)
        Check(line:find("Windshear Crag") and line:find("quests at The Crossroads"), "the later stops: " .. line)
    end
end
-- The stops are told from then to now, not longest first: a short fight,
-- a rest, then the long stay that came last. The shortest of four goes.
do
    local d0 = 5000000
    local function Stop(from, seconds, where, act)
        return { kind = "stop", from = from, to = from + seconds, mapID = BARRENS, x = 0.5, y = 0.5,
            seconds = seconds, subZone = where, act = act }
    end
    local r = { startedAt = d0, startLevel = 7, levels = {}, marks = {}, deaths = {}, segments = {
        Stop(d0, 400, "Fargodeep Mine", { combat = 300 }),
        Stop(d0 + 500, 60, "Stonetalon Pass", {}),
        Stop(d0 + 600, 1800, "Goldshire", { resting = 1800 }),
        Stop(d0 + 2500, 2700, "Crystal Lake", {}),
    } }
    local e = R.Gather(r, d0, d0 + 6000, {})
    Eq(#e.stops, 3, "the longest stops kept")
    Eq(e.stops[1].seg.subZone, "Fargodeep Mine", "the stops are not oldest first")
    Eq(e.stops[3].seg.subZone, "Crystal Lake", "the stops are not oldest first")
    e.kind, e.level, e.known, e.places, e.flights, e.people, e.fights, e.notes =
        "level", 7, true, {}, {}, {}, {}, {}
    local line = Text.Lines(e)[1]
    local a, b, c = line:find("Fargodeep Mine"), line:find("Goldshire"), line:find("Crystal Lake")
    Check(a and b and c and a < b and b < c, "the stops are told out of order: " .. line)
end
-- Times in what wraps hold together; spoken times in the prose.
Eq(Text.Duration(55 * 60), "55\194\160min", "a time can break between its number and unit")
Eq(Text.LedgerTime(93 * 60), "1\194\160h\194\16033", "the ledger's time")
Eq(Text.Spoken(4 * 3600), "four hours", "a spoken time")
Eq(Text.Spoken(52 * 60), "fifty minutes", "a spoken time")
Eq(Text.Spoken(95 * 60), "an hour and a half", "a spoken time")
-- The player's own note: its own paragraph, quoted, not among the
-- diary's lines.
do
    local noted = { kind = "level", level = 20, known = true, places = {}, stops = {}, flights = {}, people = {},
        fights = {}, seconds = 600,
        notes = { { text = "Skum took three tries.\nTester never gave up." }, { text = "Second." } } }
    for _, line in ipairs(Text.Lines(noted)) do
        Check(not line:find("Skum") and not line:find("You wrote"), "the note is in the diary's lines: " .. line)
    end
    local quote, more = Text.Note(noted)
    Eq(quote, "\226\128\156Skum took three tries. Tester never gave up.\226\128\157", "the quoted note")
    Eq(more, "And one more note.", "the count of more notes")
    noted.notes = {}
    Eq(Text.Note(noted), nil, "a note without one")
end
Check(Text.Lines(e11, t0 + 10000)[1]:find("^Reached on .* in The Crossroads, The Barrens"), "level 11's opening")
Check(Text.Lines(e12, t0 + 10000)[1]:find("not keeping your road"), "an unseen level's line")
for _, line in ipairs(lines) do
    Check(not line:find("%d+/%d+") and not line:find("%%"), "a counter in the recap: " .. line)
end

-- The zone index: by first visit, with level range and time (JRN-15).
local zones = recap.zones
Eq(#zones, 2, "the zone index")
Eq(zones[1].mapID, MULGORE, "the first zone visited first")
Eq(zones[2].levelMax, 11, "The Barrens' level range")
Check(Text.ZoneLine(zones[1]):find("levels 10 to 11"), "the zone line: " .. Text.ZoneLine(zones[1]))

-- Cached: rebuilt only when the route or the diary moved.
mock.SetUnit("player", F.Like(SELF, { level = 11 }))
local r1 = R.For(SELF.guid)
Check(R.For(SELF.guid) == r1, "the recap was rebuilt with nothing changed")
J.Touch()
Check(R.For(SELF.guid) ~= r1, "the recap was not rebuilt after the route moved")

--------------------------------------------------------------------------
Section("the prologue (JRN-13)")

j = Fresh(30, BARRENS, t0)
recap = R.Build(j, { now = t0 + 100, level = 30, maxLevel = 60 })
Eq(recap.prologue.level, 30, "the prologue's level")
local line = Text.Prologue(recap.prologue)
Check(line:find("^This diary began at level 30, in The Barrens"), "the prologue line: " .. line)
Eq(#recap.entries, 1, "a fresh route has its level's entry")
Check(Text.Lines(recap.entries[1], t0 + 100)[#Text.Lines(recap.entries[1], t0 + 100)]:find("Nothing on the road"),
    "a quiet level says so")

--------------------------------------------------------------------------
Section("past the cap, one entry a week (JRN-12)")

mock.maxLevel = 12
-- A Wednesday noon, to start from.
local base = os.time({ year = 2026, month = 10, day = 7, hour = 12 })
j = Fresh(11, MULGORE, base)
j.levels[12] = { at = base + h, mapID = MULGORE, x = 0.5, y = 0.5, subZone = "Bloodhoof Village" }
local function Day(d, map)
    local from = base + d * DAY
    j.segments[#j.segments + 1] = { kind = "stop", from = from, to = from + h, mapID = map, x = 0.5, y = 0.5,
        r = 30, seconds = h, levelFrom = 12, levelTo = 12 }
end
Day(0.2, MULGORE)  -- the same Wednesday, after the cap
Day(3, BARRENS)    -- Saturday
Day(6, MULGORE)    -- the Tuesday after: a new week
Day(20, BARRENS)   -- two weeks without play, then one day
recap = R.Build(j, { now = base + 22 * DAY, level = 12, maxLevel = 12 })
local weeks = {}
for _, e in ipairs(recap.entries) do
    if e.kind == "week" then weeks[#weeks + 1] = e end
end
Eq(recap.entries[1].kind, "level", "level 11's entry before the weeks")
Eq(#weeks, 3, "weeks with play, and none without")
Eq(date("%w", weeks[1].week), "1", "a week does not start on Monday")
Eq(date("%H:%M", weeks[1].week), "00:00", "a week does not start at midnight")
Eq(#weeks[1].places, 2, "the first week's zones")
Eq(weeks[1].reached.subZone, "Bloodhoof Village", "where the cap was reached")
Check(Text.Lines(weeks[1], base)[1]:find("^Reached level 12 in Bloodhoof Village"), "the cap line: "
    .. Text.Lines(weeks[1], base)[1])
Check(Text.Title(weeks[2]):find("^WEEK OF "), "a week's title")
mock.maxLevel = 60

--------------------------------------------------------------------------
Section("meetings on the route, joined by time (JRN-10)")

ns.TestData.Write()
-- The made-up route has all five firsts, each with its place and level,
-- the blue Tester's gift (JRN-24).
do
    local made = ns.db.journey[SELF.guid]
    local firsts = ns.Firsts.List(made)
    Eq(#firsts, 5, "the made-up route's firsts")
    for _, f in ipairs(firsts) do
        Check(f.rec.mapID and f.rec.x and f.rec.level and f.rec.link, "a made-up first has no place: " .. f.kind)
    end
    Eq(made.firsts.rare.from .. ":" .. tostring(made.firsts.rare.guid), "trade:" .. ns.TestData.GUID,
        "the made-up blue is not Tester's gift")
end
-- Tester and his sessions, on this character's real route.
ns.TestData.RemoveJourney()
local TESTER = ns.TestData.GUID
mine = ns.db.journey[SELF.guid]
-- A stop and a road in Mulgore, an hour apart.
t = mock.now + 1000
local stopSeg = { kind = "stop", from = t, to = t + 1800, mapID = MULGORE, x = 0.31, y = 0.42, r = 40,
    seconds = 1800, levelFrom = 11, levelTo = 11 }
local roadSeg = { kind = "road", from = t + 1800, to = t + 2400, mapID = MULGORE,
    pts = { 0.31, 0.42, 0.40, 0.45, 0.50, 0.50 }, levelFrom = 11, levelTo = 11 }
mine.segments[#mine.segments + 1] = stopSeg
mine.segments[#mine.segments + 1] = roadSeg
J.Touch()

-- A session at the stop, and one on the road near its end.
local s1 = ns.Sessions.New({ startedAt = t + 300, endedAt = t + 1500,
    participants = { [TESTER] = { since = t + 300, last = t + 1500, seconds = 1200 } } })
local s2 = ns.Sessions.New({ startedAt = t + 2300, endedAt = t + 2400,
    participants = { [TESTER] = { since = t + 2300, last = t + 2400, seconds = 100 } } })
Eq(s1.me, SELF.guid, "setup: the session is this character's")
local sheet = R.SheetFor(SELF.guid, MULGORE)
local function Meeting(kind, key, value)
    for _, m in ipairs(sheet.meetings) do
        if m.kind == kind and (not key or m[key] == value) then return m end
    end
end
local m1 = Meeting("session", "session", s1)
Check(m1 ~= nil, "the session at the stop was not placed")
Eq(m1.x, 0.31, "a session at a stop goes to its centre")
local m2 = Meeting("session", "session", s2)
Eq(m2 and m2.x, 0.5, "a session on a road goes to the point nearest in time")
local title, mlines = Text.Meeting(m1, t + 5000)
Check(title:find("Tester Testerson"), "the session mark says who: " .. title)
Check(mlines[#mlines]:find("level 11"), "the session mark says at what level")

-- A note at its own position on the zone's map; one on a cave's map by time.
local n1 = ns.Notes.Add(TESTER, "By the lake.", { time = t + 100, where = { mapID = MULGORE, x = 0.7, y = 0.7 } })
local n2 = ns.Notes.Add(TESTER, "In the cave.", { time = t + 2000, where = { mapID = CAVE, x = 0.5, y = 0.5 } })
sheet = R.SheetFor(SELF.guid, MULGORE)
local mn1, mn2 = Meeting("note", "note", n1), Meeting("note", "note", n2)
Eq(mn1 and mn1.x, 0.7, "a note on the zone map is placed by its own position")
Check(mn2 ~= nil and mn2.x ~= 0.5, "a note on a sub-map is placed by time, not its own coordinates")

--------------------------------------------------------------------------
Section("fights: a stranger's name does not outlive the buffer (JRN-10)")

local STRANGER = F.STRANGER2.guid
mock.SetUnit("target", F.STRANGER2)
At(1500, 1500)
-- As Features/WorldPvP/Capture.lua does it: who they are, then the kill.
ns.Characters.ObserveUnit("target")
local row = ns.WorldPvP.Kill(STRANGER)
local mark = mine.marks[#mine.marks]
Check(mark ~= nil and mark.outcome == "won", "the kill left no mark")
Eq(mark.guid, nil, "a stranger's GUID kept on the mark")
Eq(mark.mapID, MULGORE, "the fight's zone")
Eq(mark.t, row.time, "the mark's time is the row's")
local index = J.FightIndex()
Eq(Text.Fight(mark, index), "beat Tullus Hostilius", "a stranger named while the buffer has them")
-- The buffer lets them go: only the outcome is left.
ns.Interactions.Prune(mock.now + 40 * DAY)
index = J.FightIndex()
Eq(Text.Fight(mark, index), "won a fight", "a stranger named after the buffer")

-- Someone in the diary keeps their name, from the diary.
local died = ns.WorldPvP.Died({ player = true, guid = TESTER }, mock.now, ns.Where())
Eq(died.mark.guid, TESTER, "a diary entry's GUID not kept on the mark")
Eq(died.mark.outcome, "lost", "a death's outcome")
Eq(Text.Fight(died.mark, J.FightIndex()), "lost to Tester Testerson", "a diary fight's words")
-- The recap says it was a creature after all: the mark goes.
local marks = #mine.marks
ns.WorldPvP.Resolve(died, { player = false, npcID = 3 }, mock.now, ns.Where())
Eq(#mine.marks, marks - 1, "a death taken back left its mark")
-- Out of the diary, history kept, and past the buffer: a stranger again.
local again = ns.WorldPvP.Died({ player = true, guid = TESTER }, mock.now - 40 * DAY, ns.Where())
Eq(again.mark.guid, TESTER, "setup: the mark names them")
ns.Diary.Remove(TESTER, true)
J.Prune(mock.now)
Eq(again.mark.guid, nil, "a former diary entry's GUID outlived the buffer on the mark")
-- Forgetting someone takes them off every mark (PRV-3).
local kept = J.Fight(mine, "won", nil, mock.now, {})
kept.guid = "Player-0000-FORGET01"
ns.ForgetEverywhere("Player-0000-FORGET01")
Eq(kept.guid, nil, "a forgotten person stayed on a mark")
ns.TestData.Remove()

--------------------------------------------------------------------------
Section("segments are saved as lines and read back whole (JRN-19)")

local samples = {
    { kind = "stop", from = 1789680679, to = 1789681200, mapID = 1413, levelFrom = 12, levelTo = 13,
        x = 0.512, y = 0.334, r = 45, seconds = 400, act = { combat = 300, questsOut = 2, resting = 15 },
        subZone = "Lushwater Oasis; the north bank" },
    { kind = "road", from = 1789681200, to = 1789681500, mapID = 1413, levelFrom = 13, levelTo = 13,
        pts = J.PackPoints({ 0, 0.25, 0.5, 1 }) },
    { kind = "flight", from = 1789681500, to = 1789681700, mapID = 1413, levelFrom = 13, levelTo = 13,
        mapID1 = 1413, x1 = 0.5, y1 = 1, mapID2 = 1454, x2 = 0.45, y2 = 0.62 },
    { kind = "dungeon", from = 1789681700, to = 1789684700, levelFrom = 13, levelTo = 14,
        instanceID = 43, instanceType = "party", seconds = 2900, name = "Wailing Caverns" },
}
for _, seg in ipairs(samples) do
    local line = J.Pack(seg)
    Check(type(line) == "string" and #line < 120, "a " .. seg.kind .. " saved long: " .. line)
    local back = J.Unpack(line)
    for key, value in pairs(seg) do
        if type(value) == "table" then
            for k, v in pairs(value) do Eq(back[key][k], v, seg.kind .. "." .. key .. "." .. k) end
        else
            Eq(back[key], value, seg.kind .. "." .. key)
        end
    end
end
local pts = J.Points(J.Unpack(J.Pack(samples[2])))
Eq(#pts, 4, "a road's points read back")
Eq(pts[2], 0.25, "a point's coordinate read back")
-- A stop whose time is its span, and whose level did not change, saves
-- neither again.
local plain = J.Unpack(J.Pack({ kind = "stop", from = 10, to = 70, mapID = 1, levelFrom = 5, levelTo = 5,
    x = 0.1, y = 0.2, r = 15, seconds = 60 }))
Eq(plain.seconds, 60, "a stop's seconds from its span")
Eq(plain.levelTo, 5, "levelTo from levelFrom")
Eq(plain.act, nil, "an act from nothing")
Eq(plain.subZone, nil, "a subzone from nothing")

--------------------------------------------------------------------------
Section("storage: a whole levelling run stays small (JRN-19)")

-- 1 to 60 the way people level: sessions of a few hours with a night
-- between, running between quest areas, grinding a while, quest hubs,
-- cities, flights, hearths, dungeons and fights, a new zone every level
-- and a half; then eight weeks at the cap, ten hours a week.
local sim = Fresh(1, 1412, 20000000)
local rnd = Rand(12345)
local clock = 20000000
local level = 1
local zone = 1412
local px, py = 2500, 1600
local played = 0

local function Clamp(v, hi) return math.max(50, math.min(hi - 50, v)) end

local function Feed(extra)
    J.Tick(sim, clock)
    local s = { t = clock, wx = px, wy = py, inst = 1, mapID = zone, x = J.Round(px / 5000),
        y = J.Round(py / 3333), level = level }
    for k, v in pairs(extra or {}) do s[k] = v end
    J.Feed(sim, s)
    clock = clock + 5
    played = played + 5
end

local function Travel(seconds)
    local heading = rnd() * 2 * math.pi
    for _ = 1, seconds / 5 do
        heading = heading + (rnd() - 0.5) * 0.5
        px, py = Clamp(px + math.cos(heading) * 35, 5000), Clamp(py + math.sin(heading) * 35, 3333)
        Feed()
    end
end

local function Grind(seconds)
    local cx, cy = px, py
    local i = 0
    while i < seconds / 5 do
        if rnd() < 0.45 then
            -- A fight: the timer ticks on, but no position is read; its
            -- time goes to the stop.
            J.FightStart(sim, clock)
            local fight = 5 * math.floor(3 + rnd() * 6)
            for _ = 1, fight / 5 do
                clock = clock + 5
                J.Tick(sim, clock)
            end
            played, i = played + fight, i + fight / 5
            J.FightEnd(sim, clock)
            if rnd() < 0.01 then J.Act(sim, "deaths", 1) end
        else
            px, py = Clamp(cx + (rnd() - 0.5) * 90, 5000), Clamp(cy + (rnd() - 0.5) * 90, 3333)
            Feed()
            i = i + 1
        end
    end
end

local function Hub(seconds)
    for _ = 1, seconds / 5 do
        px, py = px + (rnd() - 0.5) * 6, py + (rnd() - 0.5) * 6
        Feed()
    end
    J.Act(sim, "questsOut", 2)
    J.Act(sim, "questsIn", 2)
end

local function City(seconds)
    local heading = rnd() * 2 * math.pi
    for _ = 1, seconds / 5 do
        heading = heading + (rnd() - 0.5) * 1.5
        px, py = Clamp(px + math.cos(heading) * 20, 5000), Clamp(py + math.sin(heading) * 20, 3333)
        Feed({ city = true, resting = true })
    end
end

local function Flight()
    J.TakeOff(sim, clock)
    for _ = 1, 24 + math.floor(rnd() * 24) do
        clock = clock + 5
        J.Tick(sim, clock)
    end
    px, py = 500 + rnd() * 4000, 500 + rnd() * 2300
    J.Land(sim, { t = clock, mapID = zone, x = J.Round(px / 5000), y = J.Round(py / 3333) })
end

local function Dungeon()
    J.InDungeon(sim, { instanceID = 43, name = "Wailing Caverns", instanceType = "party" }, clock)
    for _ = 1, 540 do
        clock = clock + 5
        J.Tick(sim, clock)
        J.InDungeon(sim, { instanceID = 43, name = "Wailing Caverns", instanceType = "party" }, clock)
    end
    J.LeaveDungeon(sim)
    played = played + 2700
end

-- One evening's play: `hours` of mixed activity, then the night.
local function Evening(hours, onLevel)
    local stop = played + hours * 3600
    while played < stop do
        local roll = rnd()
        if roll < 0.40 then
            Travel(120 + math.floor(rnd() * 24) * 15)
        elseif roll < 0.62 then
            Grind(300 + math.floor(rnd() * 80) * 15)
        elseif roll < 0.85 then
            Hub(60 + math.floor(rnd() * 8) * 15)
        elseif roll < 0.90 then
            City(300 + math.floor(rnd() * 40) * 15)
        elseif roll < 0.95 then
            Flight()
        elseif roll < 0.97 then
            px, py = 500 + rnd() * 4000, 500 + rnd() * 2300  -- the hearthstone
        elseif roll < 0.985 then
            Dungeon()
        else
            J.Fight(sim, rnd() < 0.5 and "won" or "lost", nil, clock, { mapID = zone, x = 0.5, y = 0.5 })
        end
        if onLevel then onLevel() end
    end
    clock = clock + 20 * 3600
end

local target = 0
for l = 1, 59 do target = target + (0.4 + 0.06 * l) * 3600 end
local perLevel, untilNext = {}, 0
for l = 1, 59 do perLevel[l] = (0.4 + 0.06 * l) * 3600 end
untilNext = played + perLevel[1]
local zones = 0
while level < 60 do
    Evening(3, function()
        if played >= untilNext and level < 60 then
            level = level + 1
            J.Level(sim, level, clock, { mapID = zone, x = J.Round(px / 5000), y = J.Round(py / 3333) })
            if level < 60 then untilNext = played + perLevel[level] end
            if level % 3 == 0 or level % 3 == 1 and rnd() < 0.5 then
                J.Settle(sim)
                zone, zones = zone + 1, zones + 1
            end
        end
    end)
end
local levelling = played
for _ = 1, 8 do
    for _ = 1, 5 do Evening(2) end
    clock = clock + 2 * DAY
end
J.Stop(sim)

-- What it weighs: the Memory settings' rough walk, and the text the client
-- would write to SavedVariables for it (tabs, one value a line, array
-- indices as comments).
local estimate = ns.EstimateSizeOf(sim)
local function Saved(value, depth)
    if type(value) ~= "table" then
        if type(value) == "string" then return #value + 2 end
        return #tostring(value)
    end
    local total, n = 3, #value
    for k, v in pairs(value) do
        local key = type(k) == "number" and k <= n and (" -- [" .. k .. "]") or ("[\"" .. tostring(k) .. "\"] = ")
        total = total + depth + #key + Saved(v, depth + 1) + 2
    end
    return total + depth
end
local written = Saved(sim, 3)
local stops, roads = Kinds(sim, "stop"), Kinds(sim, "road")
print(("        journey storage, levels 1-60 (%d h) + 8 weeks (%d h): %d segments (%d stops, %d roads),"
    .. " %.0f KB estimated, %.0f KB as saved"):format(levelling / 3600, (played - levelling) / 3600,
    #sim.segments, stops, roads, estimate / 1024, written / 1024))
Check(levelling >= 120 * 3600, "the run is too short to measure: " .. levelling / 3600 .. " h")
Check(estimate < 200 * 1024, ("over the 200 KB budget (estimate): %.0f KB"):format(estimate / 1024))
Check(written < 200 * 1024, ("over the 200 KB budget (as saved): %.0f KB"):format(written / 1024))
local recapRun = R.Build(sim, { now = clock, level = 60, maxLevel = 60 })
Eq(#recapRun.entries >= 59 + 8, true, "the run's recap: one entry per level and per week")

--------------------------------------------------------------------------
Section("/sd testdata writes a route for this character, and takes it back")

local real = ns.db.journey[SELF.guid]
local realCount = #real.segments
SlashCmdList.SOCIALDIARY("testdata")
local fake = ns.db.journey[SELF.guid]
Check(fake ~= real and fake.test, "testdata did not put a made-up route in place")
Eq(ns.db.journeyParked[SELF.guid], real, "the real route was not put aside")
local list = J.Segments(fake)
for i = 2, #list do Check(list[i].from >= list[i - 1].from, "the made-up route is out of time order") end
local kinds = {}
for _, seg in ipairs(list) do kinds[seg.kind] = true end
Check(kinds.stop and kinds.road and kinds.flight and kinds.dungeon, "the made-up route lacks a kind")
local testRecap = R.For(SELF.guid)
local levelsIn, weeksIn = 0, 0
for _, e in ipairs(testRecap.entries) do
    if e.kind == "level" then levelsIn = levelsIn + 1 else weeksIn = weeksIn + 1 end
end
Eq(levelsIn, 6, "levels 10 to 15 have their entries")
Check(weeksIn >= 2, "the weeks after the pretend cap: " .. weeksIn)
Check(#R.SheetFor(SELF.guid, 1413).meetings >= 3, "Tester's sessions, notes and fight are not on The Barrens")
-- Capture leaves a made-up route alone.
local before2 = #fake.segments
for i = 1, 40 do
    At(1000 + i * 30, 1000)
    Step()
end
Eq(#fake.segments, before2, "capture wrote into the made-up route")
SlashCmdList.SOCIALDIARY("testdata remove")
Eq(ns.db.journey[SELF.guid], real, "the real route did not come back")
Eq(#real.segments, realCount, "the real route changed meanwhile")
Eq(ns.db.journeyParked, nil, "the parking place was left behind")

--------------------------------------------------------------------------
Section("the settings switch and the delete link (JRN-17, PRV-7)")

local P = ns.UI.SettingsPage()
Check(P.keepRoute and P.keepRoute:GetChecked(), "no route switch, or it is off by default")
P.keepRoute:Click()
Eq(ns.db.settings.keepRoute, false, "the switch did not turn the route off")
Eq(ns.JourneyCapture.Running(), false, "the switch did not stop the timer")
P.keepRoute:Click()
Eq(ns.db.settings.keepRoute, true, "the switch did not turn the route back on")
Eq(ns.JourneyCapture.Running(), true, "the switch did not start the timer")
Check(ns.db.journey[SELF.guid] and #ns.db.journey[SELF.guid].segments > 0, "setup: a route to delete")
P.wipeRoute:Click()
mock.AnswerPopup("accept")
local after = ns.db.journey[SELF.guid]
Check(after ~= nil and #after.segments == 0, "the delete link did not start the route afresh")
Eq(after.startLevel, 11, "the fresh route does not begin at today's level")

--------------------------------------------------------------------------
Section("/sd journey (dev): every report runs")

ns.db.settings.debug = true
for _, verb in ipairs({ "", "stats", "segments", "segments 3", "raw", "clear" }) do
    SlashCmdList.SOCIALDIARY("journey " .. verb)
end
At(1000, 1000)
Step()
SlashCmdList.SOCIALDIARY("journey raw")

-- /sd pen changes the fountain pen live, and puts it back.
local PEN = ns.UI.Pen.PEN
local thin, cap, size, most = PEN.nib.thin, PEN.flow.cap, PEN.bead.size, PEN.width[2]
SlashCmdList.SOCIALDIARY("pen")
Eq(PEN.nib.thin, thin, "/sd pen alone changed the pen")
SlashCmdList.SOCIALDIARY("pen bold")
Check(PEN.nib.thin < thin and PEN.flow.cap > cap and PEN.bead.size > size, "/sd pen bold is not bolder")
local mean = PEN.nib.thin + (PEN.nib.thick - PEN.nib.thin) * 2 / math.pi
Check(math.abs(mean - 1) < 0.05, "/sd pen bold made the line heavier overall: " .. mean)
SlashCmdList.SOCIALDIARY("pen wild")
Check(PEN.nib.thin < 0.3 and PEN.width[2] > most, "/sd pen wild")
SlashCmdList.SOCIALDIARY("pen nib 0.3 1.6 30")
Check(PEN.nib.thin == 0.3 and PEN.nib.thick == 1.6 and PEN.nib.angle == 30, "/sd pen nib")
SlashCmdList.SOCIALDIARY("pen flow 2 0.6")
Check(PEN.flow.cap == 2 and PEN.flow.alphaGain == 0.6, "/sd pen flow")
SlashCmdList.SOCIALDIARY("pen bead 1.8 35")
Check(PEN.bead.size == 1.8 and PEN.bead.turn == 35, "/sd pen bead")
SlashCmdList.SOCIALDIARY("pen flow.lag 25")
Eq(PEN.flow.lag, 25, "/sd pen KEY VALUE")
SlashCmdList.SOCIALDIARY("pen width.2 5")
Eq(PEN.width[2], 5, "/sd pen KEY VALUE on a list")
SlashCmdList.SOCIALDIARY("pen nonsense 3")
SlashCmdList.SOCIALDIARY("pen reset")
Check(PEN.nib.thin == thin and PEN.flow.cap == cap and PEN.bead.size == size and PEN.width[2] == most
    and PEN.flow.lag ~= 25, "/sd pen reset did not put the file's numbers back")
ns.db.settings.debug = false

--------------------------------------------------------------------------
Section("a new character's road shows before anything closes")

-- Level 1, a minute's walk, a level-up: nothing has closed yet (no stop, no
-- teleport, no border), but the page must leave its explainer for the road.
local NEWBIE = F.Like(SELF, { guid = "Player-4707-0NEWB001", name = { "Masolimtaurn Skychaser" }, level = 1 })
mock.SetUnit("player", NEWBIE)
ns.ownGUID = NEWBIE.guid
for i = 1, 12 do
    At(2000 + i * 30, 1500)
    Step()
end
mock.SetUnit("player", F.Like(NEWBIE, { level = 2 }))
mock.fire("PLAYER_LEVEL_UP", 2)
At(2400, 1500)
Step()
local newbie = ns.db.journey[NEWBIE.guid]
Eq(#newbie.segments, 0, "setup: nothing closed yet")
Check(J.Any(newbie), "an open road and a level reached count as nothing kept")

local fresh = R.For(NEWBIE.guid)
Eq(#fresh.entries, 2, "levels 1 and 2 have their entries")
Check(fresh.entries[1].seconds >= 50, "the open road's time is not in level 1: " .. fresh.entries[1].seconds)
Eq(fresh.entries[1].places[1] and fresh.entries[1].places[1].mapID, MULGORE, "the open road's zone")
Eq(#fresh.zones, 1, "the open road's zone is not in the index")
Check(#R.SheetFor(NEWBIE.guid, MULGORE).roads == 1, "the open road is not on the sheet")
Eq(#newbie.segments, 0, "reading the open road saved it")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local JP = ns.UI.JourneyPage()
Eq(JP.state, "entries", "the explainer stayed up on a road with nothing closed")
Check(not JP.empty:IsShown(), "the explainer is still shown")
ns.UI.CloseJournal()
ns.ownGUID = SELF.guid
mock.SetUnit("player", F.Like(SELF, { level = 11 }))

--------------------------------------------------------------------------
Section("busy places are stops too, however short (JRN-3, JRN-6)")

-- A fight on the way: 40 seconds in one place, most of it fighting.
j = Fresh()
t = 30000000
for i = 0, 10 do
    J.Feed(j, S(t, 500 + i * 35, 1000))
    t = t + 5
end
J.Feed(j, S(t, 885, 1000))
J.FightStart(j, t)
t = t + 30
J.FightEnd(j, t)
for _ = 1, 3 do
    J.Feed(j, S(t, 890, 1005))
    t = t + 5
end
for i = 1, 10 do
    J.Feed(j, S(t, 890 + i * 35, 1000))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "stop"), 1, "a fight on the way left no mark")
Eq(R.MainActivity(Of(j, "stop")[1]), "fighting", "the fight's place is not a fighting one")
Eq(Kinds(j, "road"), 2, "the road does not go on past the fight")

-- A quest handed in at a giver, half a minute: a questing spot.
j = Fresh()
t = 31000000
for i = 1, 8 do
    J.Feed(j, S(t, 1000 + (i % 2) * 3, 1000))
    if i == 2 then J.Act(j, "questsOut", 1) end
    t = t + 5
end
for i = 1, 10 do
    J.Feed(j, S(t, 1000 + i * 35, 1000))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "stop"), 1, "a quest handed in left no mark")

-- Standing still half a minute with nothing done is still only the road.
j = Fresh()
t = 32000000
for _ = 1, 8 do
    J.Feed(j, S(t, 1000, 1000))
    t = t + 5
end
for i = 1, 10 do
    J.Feed(j, S(t, 1000 + i * 35, 1000))
    t = t + 5
end
J.Settle(j)
Eq(Kinds(j, "stop"), 0, "an idle half minute became a stop")

--------------------------------------------------------------------------
Section("a death is marked however soon the spirit is released")

-- Running, killed on the way, released ten seconds later: the release
-- settles what is open, and the death must not go with the road.
j = Fresh()
t = 33000000
for i = 0, 10 do
    J.Feed(j, S(t, 500 + i * 35, 1000))
    t = t + 5
end
J.Act(j, "deaths", 1)
J.Feed(j, S(t, 850, 1000))
t = t + 10
J.Settle(j)
local deathStops = Of(j, "stop")
Eq(#deathStops, 1, "a death released at once left no mark")
Eq(deathStops[1].act and deathStops[1].act.deaths, 1, "the stop does not know of the death")
Check(math.abs(deathStops[1].x - 850 / 5000) < 0.02, "the death is not where it happened")
-- Saved and read back, it is still there.
Eq(J.Unpack(J.Pack(deathStops[1])).act.deaths, 1, "the death is lost when saved")

-- A short fight cut off by a hearthstone is kept too.
j = Fresh()
t = 34000000
for _ = 1, 3 do
    J.Feed(j, S(t, 1000, 1000))
    t = t + 5
end
J.FightStart(j, t)
t = t + 20
J.FightEnd(j, t)
J.Feed(j, S(t, 1002, 1000))
t = t + 5
J.Feed(j, S(t, 3500, 2500))  -- the hearthstone
Eq(Kinds(j, "stop"), 1, "a fight cut short by a teleport left no mark")

-- Died in a city half a minute after walking in, released at once.
j = Fresh()
t = 35000000
for i = 1, 6 do
    J.Feed(j, S(t, 1000 + i * 10, 1000, { city = true }))
    t = t + 5
end
J.Act(j, "deaths", 1)
J.Settle(j)
Eq(Kinds(j, "stop"), 1, "a death in a city, released at once, left no mark")

--------------------------------------------------------------------------
Section("an error in a tick does not stop the timer")

ns.JourneyCapture.SetEnabled(false)
ns.JourneyCapture.SetEnabled(true)
local timer = mock.tickers[#mock.tickers]
local feed, broken = J.Feed, true
J.Feed = function(...) if broken then error("boom") end return feed(...) end
_G.geterrorhandler = function() return function() end end
local status = ns.JourneyCapture.status
local errorsBefore = status.errors
At(1200, 1200)
mock.now = mock.now + 5
timer.fn()
Eq(status.errors, errorsBefore + 1, "the error was not caught and counted")
Check(status.lastError:find("boom"), "the error was not kept for /sd journey stats")
broken = false
local ticksBefore = status.ticks
mock.now = mock.now + 5
timer.fn()
Eq(status.ticks, ticksBefore + 1, "the next tick did not run")
Eq(status.skip, nil, "the next tick took no sample")
J.Feed = feed
_G.geterrorhandler = nil
ns.db.settings.debug = true
SlashCmdList.SOCIALDIARY("journey stats")
ns.db.settings.debug = false

--------------------------------------------------------------------------
Section("a stop keeps the shape of the time spent there")

-- Grinding along a riverbank: 100 yards east-west, 10 north-south.
j = Fresh()
t = 36000000
for i = 1, 60 do
    J.Feed(j, S(t, 2000 + ((i * 37) % 100) - 50, 1000 + (i % 3) * 5 - 5, { fx = (2000 + ((i * 37) % 100) - 50) / 5000,
        fy = (1000 + (i % 3) * 5 - 5) / 3333 }))
    t = t + 5
end
J.Settle(j)
local long = Of(j, "stop")[1]
Check(long and long.sdx and long.sdy, "the stop kept no shape")
Check(long.sdx > 3 * long.sdy, ("a riverbank stop is not long: %.5f by %.5f"):format(long.sdx or 0, long.sdy or 0))
Check(math.abs(long.rho) < 0.5, "a stop along the map's x leans: " .. tostring(long.rho))

-- Along a diagonal: the two lean together.
j = Fresh()
t = 37000000
for i = 1, 60 do
    local d = ((i * 37) % 100) - 50
    J.Feed(j, S(t, 2000 + d, 1000 + d * 0.8, { fx = (2000 + d) / 5000, fy = (1000 + d * 0.8) / 3333 }))
    t = t + 5
end
J.Settle(j)
local slant = Of(j, "stop")[1]
Check(math.abs(slant.rho) > 0.9, "a diagonal stop does not lean: " .. tostring(slant.rho))

-- Saved with its shape, and read back; a line from before shapes reads too.
local back = J.Unpack(J.Pack(long))
Eq(J.Pack(long):sub(1, 1), "S", "a shaped stop is not saved as one")
Check(math.abs(back.sdx - long.sdx) < 0.00002 and math.abs(back.sdy - long.sdy) < 0.00002, "the shape read back wrong")
Check(math.abs(back.rho - long.rho) < 0.01, "the lean read back wrong")
local old = J.Unpack("s;1789680679;300;1412;5;;420;610;30;;c120;Red Cloud Mesa")
Eq(old.kind, "stop", "an old stop line no longer reads")
Eq(old.sdx, nil, "an old stop has a made-up shape")
Eq(old.act.combat, 120, "an old stop's act")
Eq(old.subZone, "Red Cloud Mesa", "an old stop's subzone")

--------------------------------------------------------------------------
Section("a shape is never made from sums that miss samples")

-- The stop before was summed before shapes were kept (saved by an older
-- build, then /reload): the merged stop goes shapeless rather than taking
-- a variance from squares that miss half its samples.
j = Fresh()
t = 38000000
local walk = {}
for i = 1, 50 do walk[#walk + 1] = { 1000 + (i % 3) * 10, 1000 } end
-- Out long enough to leave it (past T.excursion), back within T.mergeRoad.
for i = 1, 8 do walk[#walk + 1] = { 1000 + i * 30, 1000 } end
for i = 1, 8 do walk[#walk + 1] = { 1240 - i * 30, 1000 } end
for i = 1, 50 do walk[#walk + 1] = { 1000 + (i % 3) * 10, 1005 } end
local stripped = false
for _, at in ipairs(walk) do
    J.Feed(j, S(t, at[1], at[2]))
    t = t + 5
    local held = j.open.held
    if held and not stripped then
        Check(held.zxx, "the stop before was held without its shape")
        held.zxx, held.zyy, held.zxy = nil, nil, nil
        stripped = true
    end
end
Check(stripped, "the stop before was never held to merge with")
Check(j.open.c and j.open.c.stop and j.open.c.zxx == nil, "the merged stop still sums half a shape")
J.Settle(j)
Eq(Kinds(j, "stop"), 1, "the stops across the update did not merge")
local merged = Of(j, "stop")[1]
Eq(merged.sdx, nil, "a stop merged with one without a shape was given one")
Check(merged.seconds >= 400 and merged.r, "the shapeless merge lost its time or spread")

-- The same for a stop still open across the update: what it sums from
-- then on is not its whole shape.
j = Fresh()
t = 39000000
for i = 1, 45 do
    J.Feed(j, S(t, 1000 + (i % 3) * 10, 1000))
    t = t + 5
end
local open = j.open.c
Check(open and open.zxx, "the open stop is not summing its shape")
open.zxx, open.zyy, open.zxy = nil, nil, nil
for i = 1, 30 do
    J.Feed(j, S(t, 1000 + (i % 3) * 10, 1000))
    t = t + 5
end
Check(j.open.c == open and open.zxx == nil, "a stop summed across the update began a shape halfway")
J.Settle(j)
Eq(Of(j, "stop")[1].sdx, nil, "a stop summed across the update was given a shape")

-- Sums that disagree (a negative variance) give no shape.
Eq(J.Shape({ w = 10, zx = 5, zy = 5, zxx = 0.1, zyy = 2.5, zxy = 2.5 }), nil,
    "a negative variance made a shape")
local sdx = J.Shape({ w = 4, zx = 2, zy = 2, zxx = 1.04, zyy = 1, zxy = 1 })
Check(sdx and math.abs(sdx - 0.1) < 1e-9, "a sound shape was lost")

--------------------------------------------------------------------------
Section("how many yards a zone spans: ordered by its art, guarded (JRN-14)")

-- The mock's client answers GetMapWorldSize: Mulgore 5000 by 3333.
local w, h = J.MapYards(MULGORE)
Eq(w, 5000, "Mulgore's width in yards")
Eq(h, 3333, "Mulgore's height in yards")

-- Without it, the corners: the world vector runs (north, west), so the
-- first axis is the map's height. Ordered back by the art.
local worldSize = C_Map.GetMapWorldSize
C_Map.GetMapWorldSize = nil
local _, corner = C_Map.GetWorldPosFromMapPos(MULGORE, CreateVector2D(0, 0))
local _, far = C_Map.GetWorldPosFromMapPos(MULGORE, CreateVector2D(1, 1))
local cx, cy = corner:GetXY()
local fx, fy = far:GetXY()
Eq(math.abs(fx - cx), 3333, "the mock's world vector is not (north, west)")
Eq(math.abs(fy - cy), 5000, "the mock's world vector is not (north, west)")
w, h = J.MapYards(MULGORE)
Eq(w, 5000, "the corners gave the height as the width")
Eq(h, 3333, "the corners gave the width as the height")

-- A map without art takes the client's own order.
mock.mapRects[7001] = { 0, 0, 2400, 1800 }
w, h = J.MapYards(7001)
Eq(w, 2400, "without art, the corners are not read (north, west)")
Eq(h, 1800, "without art, the corners are not read (north, west)")

-- Out of range, or the wrong shape for the art: nil, and the sheet guesses.
mock.mapRects[7001] = { 0, 0, 120, 90 }
Eq(J.MapYards(7001), nil, "a zone a hundred yards across was believed")
mock.mapRects[7001] = { 0, 0, 90000, 60000 }
Eq(J.MapYards(7001), nil, "a zone ninety thousand yards across was believed")
mock.mapArt[7001] = true
mock.mapRects[7001] = { 0, 0, 3000, 3000 }
Eq(J.MapYards(7001), nil, "a square in world space was taken for a 3:2 map")
mock.mapRects[7001], mock.mapArt[7001] = nil, nil
Eq(J.MapYards(7001), nil, "a map the client cannot place has yards")
C_Map.GetMapWorldSize = worldSize

-- The client's own figure is ordered and guarded too.
local swapped = C_Map.GetMapWorldSize
C_Map.GetMapWorldSize = function(mapID)
    local a, b = swapped(mapID)
    return b, a
end
w, h = J.MapYards(MULGORE)
Eq(w, 5000, "a world size given down-first was not put back in order")
C_Map.GetMapWorldSize = function() return 0, 0 end
w = J.MapYards(MULGORE)
Eq(w, 5000, "a world size of nothing did not fall back to the corners")
C_Map.GetMapWorldSize = swapped

--------------------------------------------------------------------------
Section("a ghost's walk is not the road")

ns.ownGUID = SELF.guid
mock.SetUnit("player", F.Like(SELF, { level = 11 }))
mock.ghost, mock.dead, mock.inInstance = false, false, false
local ghostRoute = ns.db.journey[SELF.guid]
for i = 1, 10 do
    At(3000 + i * 35, 2500)
    Step()
end
J.Act(ghostRoute, "deaths", 1)
local died = mock.now
mock.dead = true
Step()
Step()
mock.dead, mock.ghost = false, true
-- Released at the graveyard, running back across the map.
for i = 1, 20 do
    At(4000 - i * 35, 1500)
    Step()
end
mock.ghost = false
local alive = mock.now
for i = 1, 10 do
    At(3300 + i * 35, 2500)
    Step()
end
J.Settle(ghostRoute)
for _, seg in ipairs(J.Segments(ghostRoute)) do
    if seg.from > died and seg.from < alive then
        Check(seg.kind ~= "road", "the ghost's walk was penned as a road")
    end
    if seg.kind == "road" then
        Check(seg.to <= died + 10 or seg.from >= alive, "a road spans the time as a ghost")
    end
end
local deathMarked = false
for _, seg in ipairs(J.Segments(ghostRoute)) do
    if seg.kind == "stop" and seg.act and seg.act.deaths then deathMarked = true end
end
Check(deathMarked, "the death was not kept where it happened")
Eq(ns.JourneyCapture.status.skip, nil, "capture did not take up again once alive")

-- Its own function: the file's main chunk is near Lua's 200 locals.
local function Hindsight()
local h = 3600
--------------------------------------------------------------------------
Section("first sightings, in hindsight (JRN-23, D6 amended)")

-- A Wednesday at 10:00, a route of three days in Mulgore, and the stores
-- the gate reads handed in as the context, the way Recap.Context does.
local d0 = os.time({ year = 2026, month = 10, day = 7, hour = 10 })
j = Fresh(1, MULGORE, d0)
local function Stay(from, to, x, y, level)
    j.segments[#j.segments + 1] = { kind = "stop", from = from, to = to, mapID = MULGORE, x = x, y = y,
        r = 30, seconds = to - from, levelFrom = level, levelTo = level }
end
Stay(d0, d0 + 2 * h, 0.40, 0.60, 1)
j.levels[2] = { at = d0 + 2 * h, mapID = MULGORE, x = 0.40, y = 0.60 }
Stay(d0 + DAY, d0 + DAY + 2 * h, 0.50, 0.50, 2)
j.levels[3] = { at = d0 + DAY + 2 * h, mapID = MULGORE, x = 0.50, y = 0.50 }
Stay(d0 + 2 * DAY, d0 + 2 * DAY + 2 * h, 0.30, 0.30, 3)
J.Touch()

local function G(n) return ("Player-0000-HS%06d"):format(n) end
local hs = { now = d0 + 3 * DAY, level = 3, maxLevel = 60, diary = {}, interactions = {}, sightings = {},
    characters = {}, own = {} }
local function Person(n, firstSeen)
    hs.characters[G(n)] = { guid = G(n), firstSeen = firstSeen, lastSeen = firstSeen }
    return G(n)
end

-- In the diary, added the next day: they mattered.
local diaryP = Person(1, d0 + 600)
hs.diary[diaryP] = { addedAt = d0 + DAY + 600, tags = {} }
-- Grouped with on day three.
local grouped = Person(2, d0 + 1200)
hs.interactions[grouped] = { { type = "level_up", time = d0 + 1300 }, { type = "group_join", time = d0 + 2 * DAY + 60 } }
-- Seen again on a later day, never spoken to: seeing is not mattering.
local later = Person(3, d0 + 1800)
hs.sightings[later] = { { time = d0 + 1800 }, { time = d0 + DAY + 300 } }
-- Passed by twice the same evening: two zone-hour rows, one day.
local passing = Person(4, d0 + 2400)
hs.sightings[passing] = { { time = d0 + 2400 }, { time = d0 + 2400 + h } }
-- Added to the diary the moment they were first seen: one encounter.
local oneEnc = Person(5, d0 + 3000)
hs.diary[oneEnc] = { addedAt = d0 + 3000 + 600, tags = {} }
-- Whispered, then seen again a week on: the whisper was the same encounter.
local whisper = Person(6, d0 + 3600)
hs.interactions[whisper] = { { type = "whisper_in", time = d0 + 3600 + 60 } }
hs.sightings[whisper] = { { time = d0 + 3600 }, { time = d0 + 2 * DAY } }
-- Only an observation, never an exchange: a level-up seen in the roster.
local observed = Person(7, d0 + 4000)
hs.interactions[observed] = { { type = "level_up", time = d0 + DAY + 4000 } }
-- Seen first while an alt was playing: this route has nothing then.
local altSeen = Person(8, d0 + 12 * h)
hs.diary[altSeen] = { addedAt = d0 + 2 * DAY, tags = {} }
-- The rows went to the buffer's summary: two days counted, still only seen.
local folded = Person(9, d0 + 4200)
hs.characters[folded].sightingSummary = { first = d0 + 4200, last = d0 + DAY + 4200, days = 2, count = 3 }
-- An evening that ran past midnight (11 Oct, in the client): first seen at
-- 23:04, again at 00:32, never spoken to. Whichever store remembers it.
local night, past = d0 + 13 * h + 4 * 60, d0 + 14 * h + 32 * 60
local lateRow = Person(11, night)
hs.sightings[lateRow] = { { time = night }, { time = past } }
local lateSummary = Person(12, night)
hs.characters[lateSummary].sightingSummary = { first = night, last = past, days = 2, count = 2 }
local lateSeen = Person(13, night)
hs.characters[lateSeen].lastSeen = past
-- Late one night, and again at eight the next morning: still only seen.
local morning = Person(14, night)
hs.characters[morning].lastSeen = d0 + 22 * h
-- One of the user's own characters.
local alt = Person(10, d0 + 4400)
hs.own[alt] = { level = 20 }
hs.diary[alt] = { addedAt = d0 + DAY, tags = {} }

Eq(R.Matters(diaryP, hs), d0 + DAY + 600, "the diary's add is when they mattered")
Eq(R.Matters(grouped, hs), d0 + 2 * DAY + 60, "grouping is when they mattered (a level-up is not)")
Eq(R.Matters(later, hs), nil, "being seen on a later day made them matter")
Eq(R.Matters(passing, hs), nil, "two sightings the same day made them matter")
Eq(R.Matters(observed, hs), nil, "an observed row made them matter")
Eq(R.Matters(folded, hs), nil, "a later day counted in the summary made them matter")
Eq(R.Matters(lateRow, hs), nil, "a sighting past midnight the same evening made them matter")
Eq(R.Matters(lateSummary, hs), nil, "a summary's second day past midnight made them matter")
Eq(R.Matters(lateSeen, hs), nil, "a last sighting past midnight made them matter")
Eq(R.Matters(morning, hs), nil, "seen again the next morning made them matter")

local firsts = R.FirstSightings(j, hs)
local byGuid = {}
for _, f in ipairs(firsts) do byGuid[f.guid] = f end
Check(byGuid[diaryP] ~= nil, "a diary entry's first sighting is missing")
Check(byGuid[grouped] ~= nil, "a grouped stranger's first sighting is missing")
Eq(byGuid[later], nil, "a stranger only seen again a day later shows")
Eq(byGuid[folded], nil, "a later day from the summary shows")
Eq(byGuid[passing], nil, "a same-day pass-by shows")
Eq(byGuid[oneEnc], nil, "a first sighting that was the meeting itself shows")
Eq(byGuid[whisper], nil, "a whisper at first sight shows as a first sighting")
Eq(byGuid[observed], nil, "an observed level-up made a first sighting show")
Eq(byGuid[altSeen], nil, "a sighting made while an alt played shows on this route")
Eq(byGuid[alt], nil, "one of the user's own characters shows")
local f1 = byGuid[diaryP]
Eq(f1.mapID, MULGORE, "the first sighting's map")
Eq(f1.x, 0.40, "placed by time on the route: the stop's centre")
Eq(f1.level, 1, "the level at the first sighting")
Eq(byGuid[grouped].metLevel, 3, "the level they came to matter at")
for i = 2, #firsts do Check(firsts[i - 1].t <= firsts[i].t, "first sightings out of time order") end

-- In a short gap in the route (a fight pauses capture), the nearer end.
Eq(select(2, R.WhereAt(j, d0 + 2 * h + 60)), 0.40, "a time just past a stop is not placed at it")
Eq(R.WhereAt(j, d0 + 2 * h + 600), nil, "a time ten minutes off the route was placed")

-- On the recap: each first sighting on its level's entry, and the faces.
recap = R.Build(j, hs)
local L1, L2, L3 = recap.entries[1], recap.entries[2], recap.entries[3]
Eq(L1.level, 1, "setup: level 1 first")
Eq(#L1.hindsight, 2, "level 1's first sightings")
Eq(#L2.hindsight, 0, "level 2's first sightings")
local faceOf = {}
for _, face in ipairs(L1.faces) do faceOf[face.guid] = face end
Check(faceOf[diaryP] ~= nil, "a diary entry first seen at level 1 is not among its faces")
Eq(faceOf[grouped], nil, "a stranger among the faces")

--------------------------------------------------------------------------
Section("faces on a level: the diary people crossed, in order met (JRN-22)")

local ctxF = { diary = { [G(20)] = { tags = { "friend" } }, [G(21)] = { tags = { "foe" } } }, sessions = {
    { startedAt = d0 + 3000, endedAt = d0 + 3600, participants = { [G(20)] = { seconds = 600 } } } } }
local eF = { from = d0, to = d0 + 2 * h, notes = { { time = d0 + 100, about = { [G(21)] = true } } },
    fights = { { t = d0 + 200, guid = G(21), outcome = "lost" }, { t = d0 + 300, outcome = "won" } }, hindsight = {} }
local facesF = R.Faces(eF, ctxF)
Eq(#facesF, 2, "faces: once each, strangers left out")
Eq(facesF[1].guid, G(21), "faces in the order met")
Eq(facesF[1].rival, true, "a foe is a rival")
Eq(facesF[2].rival, nil, "a friend is a rival")

--------------------------------------------------------------------------
Section("plates: a place, not an event; at most three (JRN-21)")

-- A window 0.2 by 0.2 of the map, everywhere.
local function Cover() return 0.2, 0.2 end
j = Fresh(4, MULGORE, d0)
local function Seg2(kind, from, to, map, fields)
    local seg = { kind = kind, from = from, to = to, mapID = map, levelFrom = 4, levelTo = 4 }
    for k, v in pairs(fields) do seg[k] = v end
    j.segments[#j.segments + 1] = seg
    return seg
end
-- Five places in level 4: a hillside of three stops close together, one
-- far across Mulgore, one in The Barrens, a lake with a death, and a
-- quiet long stay.
Seg2("stop", d0, d0 + 600, MULGORE, { x = 0.20, y = 0.70, r = 30, seconds = 600 })
Seg2("stop", d0 + 700, d0 + 1300, MULGORE, { x = 0.24, y = 0.72, r = 30, seconds = 600 })
Seg2("stop", d0 + 1400, d0 + 2000, MULGORE, { x = 0.27, y = 0.68, r = 30, seconds = 600 })
Seg2("stop", d0 + 2100, d0 + 2700, MULGORE, { x = 0.60, y = 0.30, r = 30, seconds = 600,
    act = { deaths = 1 } })
Seg2("stop", d0 + 2800, d0 + 9000, MULGORE, { x = 0.85, y = 0.85, r = 30, seconds = 6200 })
Seg2("road", d0 + 9000, d0 + 9600, BARRENS, { pts = { 0.1, 0.5, 0.2, 0.5 } })
Seg2("stop", d0 + 9600, d0 + 10200, BARRENS, { x = 0.2, y = 0.5, r = 30, seconds = 600 })
J.Touch()
local P1, P2 = G(30), G(31)
local ctxP = { now = d0 + 11000, level = 4, maxLevel = 60, diary = { [P1] = { tags = {} }, [P2] = { tags = {} } },
    sessions = {
        { startedAt = d0 + 100, endedAt = d0 + 500, participants = { [P1] = { seconds = 400 } } },
        { startedAt = d0 + 1500, endedAt = d0 + 1900, participants = { [P2] = { seconds = 400 } } },
    } }
recap = R.Build(j, ctxP)
local e4 = recap.entries[1]
local plates = R.Plates(j, e4, ctxP, Cover)
Eq(#plates, 3, "at most three plates")
local hill = plates[1]
Eq(hill.mapID, MULGORE, "the plates in time order: the hillside first")
Eq(#hill.moments >= 2, true, "the hillside's two sessions share one plate")
local kinds = {}
for _, p in ipairs(plates) do
    for _, m in ipairs(p.moments) do kinds[m.kind] = (kinds[m.kind] or 0) + 1 end
end
Eq(kinds.session, 2, "both sessions on the plates")
Eq(kinds.death, 1, "the death won a plate")
local barrens = false
for _, p in ipairs(plates) do barrens = barrens or p.mapID == BARRENS end
Check(barrens, "the zone new to the road won no plate")
for _, p in ipairs(plates) do
    Check(p.rank < R.RANK.stay, "the long quiet stay won a plate over people, a death and a new zone")
end
for _, p in ipairs(plates) do
    Check(p.x1 - p.x0 <= 0.2 and p.y1 - p.y0 <= 0.2, "a plate's moments do not fit its window")
    Check(p.cx >= p.x0 and p.cx <= p.x1, "a plate's centre is outside its moments")
end
for i = 2, #plates do Check(plates[i - 1].t <= plates[i].t, "plates out of time order") end

-- A session already under way when the level began is marked when it was
-- where it is marked, not at the level's start: the plates' "later" counts
-- from it (10 Oct, in the client: "A moment later" two plates apart).
do
    local long = { startedAt = d0 - 3000, endedAt = d0 + 2700, participants = { [P1] = { seconds = 5700 } } }
    local ctxL = { now = d0 + 11000, level = 4, maxLevel = 60, diary = ctxP.diary, sessions = { long } }
    local found
    for _, m in ipairs(R.Moments(j, R.Build(j, ctxL).entries[1], ctxL)) do
        if m.kind == "session" then found = m end
    end
    Check(found, "the session under way has no moment")
    Check(found.t > d0 and found.t < d0 + 2700, "the session's moment is not when it was at its mark: " .. found.t - d0)
    -- Its time together is this level's share, not the whole session's
    -- (11 Oct: "2 h 41 min together" under three levels).
    Check(math.abs(found.seconds - 2700) < 1, "the session's time is not this level's share: " .. found.seconds)
end

-- A level's pin opens no plate of its own: it joins the plate of what
-- happened where the level was reached, and the next level's page shows
-- that spot (11 Oct: one level-up was an empty plate under two levels).
do
    local jp = Fresh(2, MULGORE, d0)
    local function Stop(from, to, x, y, level)
        jp.segments[#jp.segments + 1] = { kind = "stop", from = from, to = to, mapID = MULGORE, x = x, y = y, r = 30,
            seconds = to - from, levelFrom = level, levelTo = level }
    end
    Stop(d0, d0 + 600, 0.2, 0.2, 2)
    Stop(d0 + 700, d0 + 1500, 0.8, 0.8, 3)
    jp.levels[3] = { at = d0 + 700, mapID = MULGORE, x = 0.8, y = 0.8 }
    J.Touch()
    local ctxJ = { now = d0 + 2000, level = 3, maxLevel = 60, diary = ctxP.diary,
        sessions = { { startedAt = d0 + 100, endedAt = d0 + 500, participants = { [P1] = { seconds = 400 } } } } }
    local rj = R.Build(jp, ctxJ)
    local before = R.Plates(jp, rj.entries[1], ctxJ, Cover)
    Eq(#before, 1, "the level-up far from the session took a plate of its own")
    for _, m in ipairs(before[1].moments) do Check(m.kind ~= "level" or not m.out, "the level-up joined a plate it does not fit") end
    local after = R.Plates(jp, rj.entries[2], ctxJ, Cover)
    Eq(#after, 1, "the next level's plates")
    local pin = false
    for _, m in ipairs(after[1].moments) do pin = pin or m.kind == "level" end
    Check(pin, "the level's pin did not join the plate where it was reached")
end

-- A level's pin ranks below everything, the longest road too: a level
-- that only travelled has its plate where it travelled, not where the
-- level was reached (12 Oct: a plate for what happened, not the ding).
do
    local jp = Fresh(2, MULGORE, d0)
    jp.segments[#jp.segments + 1] = { kind = "stop", from = d0, to = d0 + 600, mapID = MULGORE, x = 0.5, y = 0.5,
        r = 30, seconds = 600, levelFrom = 2, levelTo = 2 }
    jp.levels[3] = { at = d0 + 700, mapID = MULGORE, x = 0.1, y = 0.1 }
    jp.segments[#jp.segments + 1] = { kind = "road", from = d0 + 700, to = d0 + 1500, mapID = MULGORE,
        levelFrom = 3, levelTo = 3, pts = { 0.6, 0.6, 0.7, 0.7 } }
    J.Touch()
    local ctxJ = { now = d0 + 2000, level = 3, maxLevel = 60, diary = ctxP.diary, sessions = {} }
    local e3
    for _, e in ipairs(R.Build(jp, ctxJ).entries) do
        if e.kind == "level" and e.level == 3 then e3 = e end
    end
    Check(e3 and e3.longestRoad and e3.reached, "setup: level 3 has no road or no pin")
    Check(R.Rank({ kind = "level" }) > R.Rank({ kind = "road" }), "a level-up outranks the longest road")
    local plates = R.Plates(jp, e3, ctxJ, Cover)
    Eq(#plates, 1, "a level that only travelled")
    Eq(plates[1].rank, R.RANK.road, "the level's pin opened the plate before its road")
    Check(plates[1].cx > 0.5, "the plate is not where the level travelled: " .. plates[1].cx)
    for _, m in ipairs(plates[1].moments) do Check(m.kind ~= "level", "a pin far from the road joined its plate") end
end

-- A death goes to the cross of the segment it was counted on
-- (Journey.CountedOn): what was open at PLAYER_DEAD, whose samples stop
-- when the fight begins, however long the fight, and wherever on the stop
-- it fell; not to a cross near it that was not where it was counted.
-- (12 Oct, in the client: a death 35 s after its stop's last sample and
-- 29 px from its cross was matched to none.)
do
    local jd = Fresh(4, MULGORE, d0)
    local function Add(seg)
        seg.levelFrom, seg.levelTo = 4, 4
        jd.segments[#jd.segments + 1] = seg
        return seg
    end
    local A = Add({ kind = "stop", from = d0, to = d0 + 600, mapID = MULGORE, x = 0.2, y = 0.2, r = 30, seconds = 600,
        act = { deaths = 1 } })
    Add({ kind = "road", from = d0 + 700, to = d0 + 800, mapID = MULGORE, pts = { 0.2, 0.2, 0.5, 0.5 } })
    local B = Add({ kind = "stop", from = d0 + 900, to = d0 + 1000, mapID = MULGORE, x = 0.5, y = 0.5, r = 30,
        seconds = 100, act = { deaths = 1 } })
    local C = Add({ kind = "stop", from = d0 + 2000, to = d0 + 2100, mapID = BARRENS, x = 0.5, y = 0.5, r = 30,
        seconds = 100, act = { deaths = 1 } })
    J.Touch()
    Eq(J.CountedOn(jd, d0 + 690), A, "a death a long fight after its stop's last sample")
    Eq(J.CountedOn(jd, d0 + 750), nil, "a death on a road that counts none")
    Eq(J.CountedOn(jd, d0 + 1500), B, "the death on the second stop")
    Eq(J.CountedOn(jd, d0 - 10), nil, "a death before the route began")

    local Card = ns.Deaths.Card
    local function Counted(t) return J.CountedOn(jd, t) end
    local function Place(d) return d.x, d.y end
    local crosses = { { x = 10, y = 10, segs = { A } }, { x = 200, y = 200, segs = { B } } }
    local far = { t = d0 + 690, name = "Murloc Forager", npcID = 46, mapID = MULGORE, x = 150, y = 150 }
    local loose = { t = d0 + 750, name = "Kobold", npcID = 6, mapID = MULGORE, x = 150, y = 150 }
    local near = { t = d0 + 1500, name = "Hogger", npcID = 448, mapID = MULGORE, x = 12, y = 12 }
    local elsewhere = { t = d0 + 2050, name = "Raptor", npcID = 3254, mapID = MULGORE, x = 11, y = 11 }
    Card.Match(crosses, { far, loose, near, elsewhere }, MULGORE, Place, { from = d0, to = d0 + 3000 }, Counted)
    Eq(#crosses[1].deaths, 1, "the stop's cross: its death, and no other near it")
    Eq(crosses[1].deaths[1], far, "a death long after its stop's last sample, far from its cross, is not its own")
    Eq(#crosses[2].deaths, 1, "the second stop's cross")
    Eq(crosses[2].deaths[1], near, "a death went to the cross nearest it, not the one it was counted on")
    Eq(Card.Choose(crosses).name, "Hogger", "setup: the plate's killer")
    -- C is not on this plate: its death, though its spot is on A's cross,
    -- is no death here.
    for _, cross in ipairs(crosses) do
        for _, d in ipairs(cross.deaths) do Check(d ~= elsewhere, "a death counted off this plate matched on it") end
    end
    Check(C, "setup")
end

-- A long stay in a zone no plate shows yet gets one: the level went there.
-- (Visited before this level, so it is not new to the road.)
table.insert(j.segments, 1, { kind = "stop", from = d0 - 5000, to = d0 - 4000, mapID = 1414, x = 0.1, y = 0.1,
    r = 30, seconds = 1000, levelFrom = 3, levelTo = 3 })
Seg2("stop", d0 + 10300, d0 + 13000, 1414, { x = 0.5, y = 0.5, r = 30, seconds = 2700 })
J.Touch()
recap = R.Build(j, ctxP)
local quiet = R.Plates(j, recap.entries[1], ctxP, function() return 2, 2 end)
Eq(#quiet, 3, "a quiet zone's long stay did not win the free slot")
Eq(quiet[3].mapID, 1414, "the third plate is not the quiet zone")
Eq(quiet[3].moments[1].kind, "stay", "the quiet zone's plate is not its stay")
table.remove(j.segments)
table.remove(j.segments, 1)
J.Touch()
recap = R.Build(j, ctxP)
e4 = recap.entries[1]

-- A whole map in one window: everything in Mulgore on one plate.
local whole = R.Plates(j, e4, ctxP, function() return 2, 2 end)
Eq(#whole, 2, "a window as big as the map: one plate a zone")

-- A quiet level: its longest stay is its one plate.
j = Fresh(2, MULGORE, d0)
Seg2("stop", d0, d0 + 600, MULGORE, { x = 0.5, y = 0.5, r = 30, seconds = 600 })
Seg2("stop", d0 + 700, d0 + 4000, MULGORE, { x = 0.1, y = 0.1, r = 30, seconds = 3300 })
J.Touch()
recap = R.Build(j, { now = d0 + 5000, level = 2, maxLevel = 60 })
plates = R.Plates(j, recap.entries[1], {}, Cover)
Eq(#plates, 1, "a quiet level's plates")
Eq(plates[1].moments[1].kind == "arrive" or plates[1].moments[1].kind == "stay", true,
    "a quiet level's plate: where it began or its longest stay")

-- Nothing kept: no plate.
j = Fresh(2, MULGORE, d0)
recap = R.Build(j, { now = d0 + 5000, level = 2, maxLevel = 60 })
Eq(#R.Plates(j, recap.entries[1], {}, Cover), 0, "a level with no road kept has a plate")

-- A level spent in a dungeon: its door.
j = Fresh(2, MULGORE, d0)
Seg2("dungeon", d0, d0 + 3000, MULGORE, { instanceID = 43, name = "Wailing Caverns", x = 0.6, y = 0.6, seconds = 3000 })
J.Touch()
recap = R.Build(j, { now = d0 + 5000, level = 2, maxLevel = 60 })
plates = R.Plates(j, recap.entries[1], {}, Cover)
Eq(#plates, 1, "a dungeon level's plate")
Eq(plates[1].moments[1].kind, "dungeon", "a dungeon level's plate is at its door")

--------------------------------------------------------------------------
Section("a plate's weight: light where it holds only a place (plate-weight proposal)")

-- The light kinds, a whitelist: a place and a line of words, nothing for
-- the margin; finales, profession caps and good luck too (the user's
-- choice, 13 Oct), and a campfire sat by (14 Oct: filler, its slip under
-- the caption at most). Whatever puts a note in the margin is full.
do
    local light = {}
    for kind in pairs(R.LIGHT) do light[#light + 1] = kind end
    table.sort(light)
    Eq(table.concat(light, ","), "arrive,campfire,duel,dungeon,finale,fortune,level,road,skill,stay", "the light kinds")
    for _, kind in ipairs({ "session", "fight", "note", "first", "gift", "find", "death", "close", "luck" }) do
        Check(R.LIGHT[kind] == nil, kind .. " counts as light")
    end
end
-- The dungeon level's plate is its door alone: light.
Eq(plates[1].light, true, "a plate at a dungeon's door is not light")
-- A plate with a session or a death is full; a quiet one beside it light.
j = Fresh(4, MULGORE, d0)
Seg2("stop", d0, d0 + 600, MULGORE, { x = 0.20, y = 0.70, r = 30, seconds = 600 })
Seg2("stop", d0 + 700, d0 + 1300, MULGORE, { x = 0.60, y = 0.30, r = 30, seconds = 600, act = { deaths = 1 } })
Seg2("road", d0 + 1300, d0 + 1900, BARRENS, { pts = { 0.1, 0.5, 0.2, 0.5 } })
Seg2("stop", d0 + 1900, d0 + 4000, BARRENS, { x = 0.2, y = 0.5, r = 30, seconds = 2100 })
J.Touch()
do
    local ctxW = { now = d0 + 5000, level = 4, maxLevel = 60, diary = ctxP.diary,
        sessions = { { startedAt = d0 + 100, endedAt = d0 + 500, participants = { [P1] = { seconds = 400 } } } } }
    local weighed = R.Plates(j, R.Build(j, ctxW).entries[1], ctxW, Cover)
    local said = {}
    for _, p in ipairs(weighed) do
        local kinds = {}
        for _, m in ipairs(p.moments) do kinds[#kinds + 1] = m.kind end
        said[#said + 1] = (p.light and "L" or "F") .. "(" .. table.concat(kinds, ",") .. ")"
    end
    Eq(#weighed, 3, "setup: the plates of a session, a death and a quiet zone: " .. table.concat(said, " "))
    Eq(weighed[1].light, false, "a plate with a session is light: " .. said[1])
    Eq(weighed[2].light, false, "a plate with a death is light: " .. said[2])
    Eq(weighed[3].light, true, "a first visit and a stay is not light: " .. said[3])

    -- A kind no one has weighed yet counts as full until someone does.
    local Moments = R.Moments
    R.Moments = function(...)
        local list = Moments(...)
        list[#list + 1] = { kind = "omen", t = d0 + 2000, mapID = BARRENS, x = 0.2, y = 0.5 }
        return list
    end
    local omen = R.Plates(j, R.Build(j, ctxW).entries[1], ctxW, Cover)
    R.Moments = Moments
    local kinds = {}
    for _, m in ipairs(omen[3].moments) do kinds[#kinds + 1] = m.kind end
    Check(table.concat(kinds, ","):find("omen"), "setup: the new kind did not join the quiet plate")
    Eq(omen[3].light, false, "a plate with a kind no one weighed is light")
end

-- Recap.Holds: whether a plate's moments still span no more than
-- PLATES.inset (0.8) of another window, either way.
do
    local box = { x0 = 0.10, x1 = 0.25, y0 = 0.50, y1 = 0.57 }
    Check(R.Holds(box, 0.2, 0.1), "0.15 by 0.07 does not hold in 0.2 by 0.1")
    Check(not R.Holds(box, 0.18, 0.1), "0.15 across holds in 0.18 (0.144)")
    Check(not R.Holds(box, 0.2, 0.08), "0.07 down holds in 0.08 (0.064)")
    Check(R.Holds({ x0 = 0.3, x1 = 0.3, y0 = 0.3, y1 = 0.3 }, 0.01, 0.01), "one spot does not hold anywhere")
end

--------------------------------------------------------------------------
Section("campfires: a plate's filler, light, last of what opens one (14 Oct)")

do
    j = Fresh(4, MULGORE, d0)
    -- Level 4: a quest stop, then a fire on the far side of Mulgore, one
    -- with no zone spot (on the route at its time), and one after the level.
    Seg2("stop", d0, d0 + 600, MULGORE, { x = 0.20, y = 0.70, r = 30, seconds = 600 })
    Seg2("road", d0 + 600, d0 + 1200, MULGORE, { pts = { 0.20, 0.70, 0.60, 0.30 } })
    Seg2("stop", d0 + 1200, d0 + 1800, MULGORE, { x = 0.60, y = 0.30, r = 30, seconds = 600 })
    j.campfires = {
        { t = d0 + 900, mapID = MULGORE, x = 0.85, y = 0.20, subZone = "Red Rocks", zone = "Mulgore" },
        { t = d0 + 1500, subZone = "Bloodhoof Village", zone = "Mulgore" },
    }
    J.Touch()
    local ctxC = { now = d0 + 2000, level = 4, maxLevel = 60 }
    local e = R.Build(j, ctxC).entries[1]
    Eq(#e.campfires, 2, "the level's campfires gathered")
    Eq(#R.Gather(j, d0 + 1000, d0 + 2000, ctxC).campfires, 1, "a campfire outside the span was gathered")
    local fires = {}
    for _, m in ipairs(R.Moments(j, e, ctxC)) do
        if m.kind == "campfire" then fires[#fires + 1] = m end
    end
    Eq(#fires, 2, "a campfire moment each")
    Eq(fires[1].x, 0.85, "a fire with a zone spot is where it was")
    Eq(fires[2].mapID, MULGORE, "a fire with no spot is on the route")
    Check(fires[2].campfire == j.campfires[2], "a fire's moment keeps its record")

    -- Its rank: it opens a plate of its own, last of what does (after a
    -- dungeon's door, before a stay); the others keep their order.
    local rank = R.Rank({ kind = "campfire" })
    Check(rank > R.RANK.dungeon and rank < R.RANK.stay, "a campfire's rank is not between a door and a stay")
    Check(R.RANK.arrive < R.RANK.dungeon and R.RANK.dungeon < R.RANK.stay and R.RANK.stay < R.RANK.road,
        "the other kinds' order changed")
    local plates = R.Plates(j, e, ctxC, Cover)
    local alone
    for _, p in ipairs(plates) do
        if p.moments[1].kind == "campfire" and math.abs(p.cx - 0.85) < 0.01 then alone = p end
    end
    Check(alone ~= nil, "the far fire opened no plate of its own")
    Eq(alone and alone.light, true, "a plate with only a campfire is full")

    -- Light with a stay; full with a session.
    local stayed = { moments = { { kind = "stay" }, { kind = "campfire" } } }
    local light = true
    for _, m in ipairs(stayed.moments) do light = light and R.LIGHT[m.kind] == true end
    Check(light, "a stay and a campfire do not make a light plate")

    -- A week past the cap with nothing but a campfire still has an entry.
    local k = Fresh(60, MULGORE, d0)
    k.levels = { [60] = { at = d0 } }
    k.campfires = { { t = d0 + 8 * 86400, mapID = MULGORE, x = 0.5, y = 0.5 } }
    J.Touch()
    local weeks = R.Build(k, { now = d0 + 9 * 86400, level = 60, maxLevel = 60 }).entries
    local found = false
    for _, w in ipairs(weeks) do found = found or (w.kind == "week" and #w.campfires == 1) end
    Check(found, "a week with only a campfire had no entry")
end

--------------------------------------------------------------------------
Section("the recap's cache sees a stranger come to matter (JRN-23)")

mock.SetUnit("player", F.Like(SELF, { level = 11 }))
local c1 = R.For(SELF.guid)
Check(R.For(SELF.guid) == c1, "setup: the recap is cached")
ns.Interactions.Add(F.STRANGER2.guid, "trade", { context = {} })
Check(R.For(SELF.guid) ~= c1, "a trade with a stranger did not rebuild the recap")
local c2 = R.For(SELF.guid)
ns.Sightings.Record(F.STRANGER.guid, { level = 5 }, { mapID = MULGORE, x = 0.5, y = 0.5 }, mock.now + 5 * DAY)
Check(R.For(SELF.guid) ~= c2, "a new sighting did not rebuild the recap")

--------------------------------------------------------------------------
Section("plates' and margin notes' words (JRN-21 to JRN-23)")

local KOKO = "Player-0000-KOKO0001"
ns.Characters.Observe(KOKO, { first = "Koko", surname = "Skybluff" })
ns.Diary.Add(KOKO, { source = "test" })
local now = d0 + 3 * DAY
local plate = { mapID = MULGORE, t = d0 + 2 * DAY + 600, moments = {
    { kind = "level", level = 5, t = d0 }, { kind = "death", t = d0 }, { kind = "death", t = d0 } } }
Eq(Text.PlateCaption(plate), "Two deaths.", "a level-up plate's caption leads with what happened")
Eq(Text.PlateHeading(plate, now), "Mulgore, yesterday", "a plate's heading")
Eq(select(3, Text.PlateHeading(plate, now)), "yesterday", "a plate heading's day")
-- A plate the same day as the one before it counts on from it.
local after = { mapID = MULGORE, t = plate.t + 45 * 60, moments = {} }
Eq(Text.PlateHeading(after, now, plate), "Forty-five minutes later", "a later plate in the same zone")
Eq(select(3, Text.PlateHeading(after, now, plate)), nil, "a later plate in the same zone moves a day")
after.mapID = BARRENS
Eq(Text.PlateHeading(after, now, plate), "Forty-five minutes later, in The Barrens", "a later plate in another zone")
local line, zone, day = Text.PlateHeading(after, now, plate)
Eq(zone, "The Barrens", "a later plate's zone, for a narrow column")
Eq(day, "forty-five minutes later", "a later plate's time, for a narrow column")
after.t = plate.t + 20 * 60
after.mapID = MULGORE
Eq(Text.PlateHeading(after, now, plate), "Twenty minutes later", "a later plate's time is not spoken")
-- Another day: the day again, as the first plate has it.
after.t = plate.t + DAY
Eq(Text.PlateHeading(after, now, plate), "Mulgore, today", "a plate on another day counts on")
plate.moments = { { kind = "session", guid = KOKO, t = d0, seconds = 1200 } }
Eq(Text.PlateCaption(plate), "With Koko.", "a plate with someone")
-- A margin note names Koko: the caption does not name her again.
Eq(Text.PlateCaption(plate, nil, { named = { [KOKO] = true } }), "In good company.", "a caption names who a strip names")
plate.moments = { { kind = "level", level = 5, t = d0 }, { kind = "session", guid = KOKO, t = d0, seconds = 1200 } }
Eq(Text.PlateCaption(plate), "With Koko.", "a level plate with someone leads with them")
Eq(Text.PlateCaption(plate, nil, { named = { [KOKO] = true } }), "In good company.", "a level caption names who a strip names")
-- The level reached is said only when nothing else on the plate is.
plate.moments = { { kind = "level", level = 5, t = d0 } }
Eq(Text.PlateCaption(plate), "Level 5.", "a plate with only the level-up")
plate.moments = { { kind = "level", level = 5, t = d0 }, { kind = "arrive", t = d0 + 50 } }
Eq(Text.PlateCaption(plate, d0), "Into Mulgore for the first time.", "a new zone leads before the level-up")
plate.moments = { { kind = "level", level = 5, t = d0 }, { kind = "road", t = d0, seg = {}, seconds = 600 } }
Eq(Text.PlateCaption(plate), "Level 5.", "the level-up leads before an empty road")
plate.moments = { { kind = "fight", outcome = "won", t = d0 } }
Eq(Text.PlateCaption(plate, nil, { named = { someone = 1 } }), "Where the fighting was.", "a caption tells a stranger's strip again")
plate.moments = { { kind = "fight", outcome = "won", t = d0 } }
Eq(Text.PlateCaption(plate), "A fight, won.", "a stranger's fight")
plate.moments = { { kind = "arrive", t = d0 + 50 } }
Eq(Text.PlateCaption(plate, d0), "Into Mulgore for the first time.", "a new zone's caption")
Eq(Text.PlateCaption(plate, d0 + 50), "Where the diary began.", "the first place's caption")
local what = Text.MarginWhat({ { kind = "session", seconds = 2100 }, { kind = "note" } }, 5)
-- The time held together by a no-break space, so the strip never wraps
-- between "35" and "min", and "a note" held the same way, so "note" is
-- never left alone on a strip's last line.
Eq(what, "35\194\160min together and a\194\160note", "a margin note")
Eq(Text.MarginWhat({ { kind = "fight", guid = KOKO, outcome = "lost" } }, 5), "killed\194\160you", "killed by them")
Eq(Text.MarginWhat({ { kind = "first", metLevel = 4 } }, 1), "first seen  \194\183  you'd meet again at level 4",
    "a first sighting's margin note")
Eq(Text.MarginWho(nil), "with someone", "a stranger's margin note")
-- Their own note on the strip (11 Oct, the user: not "a note" but what it
-- says): the latest about them on the plate, quoted under the name; the
-- words under it no longer say "a note", only count the others.
do
    local older = { kind = "note", t = 100, note = { text = "Older words." } }
    local newer = { kind = "note", t = 200, note = { text = "Saved me from the\nmurlocs." } }
    local quote, cut, whole = Text.MarginQuote({ older, { kind = "session", seconds = 2100 }, newer })
    Eq(quote, "Saved me from the murlocs.", "the quoted note is not the latest, or keeps its line break")
    Eq(cut, false, "a short note was cut")
    Eq(whole, quote, "a short note's tooltip words")
    Eq(Text.MarginQuote({ { kind = "note" } }), nil, "a note moment without its note is quoted")
    Eq(Text.MarginQuote({ { kind = "note", note = { text = " \n " } } }), nil, "a blank note is quoted")
    Eq(Text.MarginWhat({ { kind = "session", seconds = 2100 }, newer }, 5), "35\194\160min together",
        "a quoted note is still told as \"a note\"")
    Eq(Text.MarginWhat({ newer }, 5), "", "a strip with only a note says more than the quote")
    Eq(Text.MarginWhat({ { kind = "session", seconds = 2100 }, older, newer }, 5),
        "35\194\160min together and one\194\160more\194\160note", "the other notes are not counted")
    Eq(Text.MarginWhat({ older, newer, { kind = "note", t = 50, note = { text = "Third." } } }, 5),
        "two\194\160more\194\160notes", "two other notes")
    -- A long note is cut at a word, before a comma, with an ellipsis;
    -- the tooltip keeps more of it.
    local long = ("Grinding the coast, " .. ("murlocs again and again, "):rep(12)):gsub(", $", ".")
    quote, cut, whole = Text.MarginQuote({ { kind = "note", t = 1, note = { text = long } } })
    Check(cut and #quote <= Text.QUOTE.most + 3 and quote:find("%a\226\128\166$"), "a long note's cut: " .. quote)
    Check(#whole > #quote and #whole <= Text.QUOTE.tip + 3, "a long note's tooltip words: " .. #whole)
    -- One word longer than the cut: cut at a whole character.
    quote = Text.MarginQuote({ { kind = "note", t = 1, note = { text = ("\195\169"):rep(200) } } })
    Check(quote:find("^[\195\169]+\226\128\166$") and #quote % 2 == 1, "a long word cut mid-character")
end
-- What a player types is shown, not obeyed: no colour, link or texture
-- from a note (a link keeps its name), a bar shown as a bar.
Eq(Text.Written("|cffff0000Red|r and |Hitem:2589::::::::10:::::::|h[Linen Cloth]|h, |TInterface\\Icons\\X:0|t ok"),
    "Red and [Linen Cloth], ok", "a note's escape codes are obeyed")
Eq(Text.Written("a | b || c |"), "a || b || c ||", "a bar in a note is not shown as one")
Eq(Text.Written("one|ntwo\n\nthree"), "one two three", "a note's line breaks are kept")
Eq(Text.MarginQuote({ { kind = "note", t = 1, note = { text = "|cffff0000Mean|r" } } }), "Mean",
    "a quoted note keeps its colour code")
Eq(Text.Hindsight({ guid = KOKO, mapID = MULGORE, level = 1, metLevel = 4 }),
    "You first saw Koko in Mulgore. You'd meet again at level 4.", "the hindsight line")
local tip = Text.FirstSeen({ guid = KOKO, t = d0, level = 1 }, now)
Eq(tip, "First seen: Koko Skybluff", "the lozenge's tooltip")
Eq(Text.Pool({ seconds = 1500, act = { questsOut = 2 }, from = 0, to = 1500 }), "Quested here, 25 min", "a pool's tooltip")
Eq(Text.ZoneFoot({ levelMin = 1, levelMax = 5, seconds = 6 * 3600 }, { "Dos", "Koko" }, 2),
    "levels 1 to 5  \194\183  6 h  \194\183  with Dos and Koko  \194\183  2 fights", "the full page's foot line")

-- On their People page: one faded line, where they were first seen.
ns.db.characters[KOKO].firstSeen = d0 + 600
ns.db.diary[KOKO].addedAt = d0 + 2 * DAY
local firstItem
for _, item in ipairs(ns.Timeline.For(KOKO)) do
    if item.kind == "first" then firstItem = item end
end
Check(firstItem ~= nil, "no first-seen line on the People timeline")
local _, firstText = ns.UI.DescribeItem(firstItem, KOKO)
Check(firstText:find("^First seen at .*Mulgore, level %d") ~= nil, "the first-seen line: " .. firstText)
ns.db.characters[KOKO].firstSeen = ns.db.diary[KOKO].addedAt - 60
firstItem = nil
for _, item in ipairs(ns.Timeline.For(KOKO)) do
    if item.kind == "first" then firstItem = item end
end
Eq(firstItem, nil, "a first sighting at the moment they were added has a line")
ns.Characters.Forget(KOKO)
end
Hindsight()

--------------------------------------------------------------------------
Section("a plate that is only a recorded run's door is left out")

-- (.claude/ui-proposal/super-plate.md, Q2, the user, 28 Oct: the run has a
-- page of its own, UI/Journey/Run.lua.) Recap.Plates over moments given
-- straight: a door with an arrival and a level's pin on one map, a long
-- stay on another.
do
    local R2 = ns.JourneyRecap
    local moments = R2.Moments
    local function With(visit)
        R2.Moments = function()
            return {
                { kind = "dungeon", t = 10, mapID = 1, x = 0.5, y = 0.5, visit = visit, name = "Razorfen Kraul" },
                { kind = "arrive", t = 5, mapID = 1, x = 0.52, y = 0.5 },
                { kind = "level", t = 20, mapID = 1, x = 0.5, y = 0.52 },
                { kind = "stay", t = 30, mapID = 2, x = 0.3, y = 0.3, seconds = 900 },
            }
        end
        local plates = R2.Plates({}, {}, {}, function() return 0.3, 0.3 end)
        R2.Moments = moments
        local maps = {}
        for _, plate in ipairs(plates) do maps[#maps + 1] = plate.mapID end
        table.sort(maps)
        return table.concat(maps, ",")
    end
    Eq(With({ id = 7 }), "2", "the door's plate, its run recorded, is left out")
    Eq(With(nil), "1,2", "the door's plate, no run recorded behind it, stays")
    Eq(R2.DOOR_ONLY.arrive and R2.DOOR_ONLY.level and not R2.DOOR_ONLY.stay, true,
        "an arrival and a pin go with the door; a stay does not")
end

--------------------------------------------------------------------------
Section("a road's and a dungeon's act, saved")

local actRoad = { kind = "road", from = 100, to = 160, mapID = 1412, levelFrom = 5, levelTo = 5,
    pts = "100,200 300,400", act = { combat = 40, deaths = 1 } }
local line = J.Pack(actRoad)
Eq(line:sub(1, 1), "R", "a road with an act is not an R")
local actBack = J.Unpack(line)
Eq(actBack.kind, "road", "an R's kind")
Eq(actBack.pts, actRoad.pts, "an R's points")
Eq(actBack.act.combat, 40, "a road's combat lost")
Eq(actBack.act.deaths, 1, "a road's death lost")

local actDungeon = { kind = "dungeon", from = 100, to = 400, levelFrom = 13, levelTo = 13, instanceID = 43,
    instanceType = "party", seconds = 300, name = "Odd; Caverns", act = { deaths = 2 } }
line = J.Pack(actDungeon)
Eq(line:sub(1, 1), "D", "a dungeon with an act is not a D")
actBack = J.Unpack(line)
Eq(actBack.kind, "dungeon", "a D's kind")
Eq(actBack.act.deaths, 2, "a dungeon's death lost")
Eq(actBack.name, "Odd; Caverns", "a D's name, whatever it holds")
Eq(actBack.seconds, 300, "a D's seconds")
Eq(actBack.instanceID, 43, "a D's instance")

-- Nothing done: the line stays as it was, a little r or d.
Eq(J.Pack({ kind = "road", from = 1, to = 2, levelFrom = 1, levelTo = 1, pts = "" }):sub(1, 1), "r", "an idle road")
Eq(J.Pack({ kind = "road", from = 1, to = 2, levelFrom = 1, levelTo = 1, pts = "", act = { combat = 0 } }):sub(1, 1),
    "r", "a road with nothing to save in its act")

-- Lines saved before these two read as they did.
local oldRoad = J.Unpack("r;100;60;1412;5;;c40 not an act")
Eq(oldRoad.pts, "c40 not an act", "an old road's points")
Eq(oldRoad.act, nil, "an old road grew an act")
local oldDungeon = J.Unpack("d;100;300;;13;;43;party;;;300;Wailing; Caverns")
Eq(oldDungeon.name, "Wailing; Caverns", "an old dungeon's name")
Eq(oldDungeon.seconds, 300, "an old dungeon's seconds")
Eq(oldDungeon.act, nil, "an old dungeon grew an act")
