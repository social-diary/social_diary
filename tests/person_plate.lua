-- The plate on a person's page (Core/PersonPlate.lua): which of the newest
-- things with them it shows, where, and the road beside it.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local DAY, h = T.DAY, 3600
local MULGORE, BARRENS = 1412, 1413

local PP = ns.PersonPlate
local SELF = ns.ownGUID
local d0 = os.time({ year = 2026, month = 10, day = 7, hour = 10 })

-- A blank diary, and the user's route: a morning on one Mulgore hillside,
-- the next day a road into The Barrens.
local function Fresh()
    T.BlankDiary()
    ns.db.journey[SELF] = { startedAt = d0, startLevel = 10, levels = {}, marks = {}, segments = {
        { kind = "stop", from = d0, to = d0 + 2 * h, mapID = MULGORE, x = 0.40, y = 0.60, r = 30,
            seconds = 2 * h, levelFrom = 10, levelTo = 10 },
        { kind = "road", from = d0 + DAY, to = d0 + DAY + h, mapID = BARRENS, pts = { 0.1, 0.5, 0.3, 0.5 },
            levelFrom = 11, levelTo = 11 },
    } }
    ns.Touch()
end

local n = 0
local function Person(added)
    n = n + 1
    local guid = ("Player-0000-PP%06d"):format(n)
    ns.db.diary[guid] = { addedAt = d0 - DAY, addedBy = SELF, tags = {}, addedContext = added or {} }
    ns.db.interactions[guid] = {}
    return guid
end

local function Row(guid, kind, t, fields)
    local row = { type = kind, time = t, me = SELF }
    for k, v in pairs(fields or {}) do row[k] = v end
    local rows = ns.db.interactions[guid]
    rows[#rows + 1] = row
    table.sort(rows, function(a, b) return a.time < b.time end)
    ns.Touch()
    return row
end

--------------------------------------------------------------------------
Section("the person's plate: what it shows")

Fresh()
local P = Person()
Row(P, "trade", d0 + 3 * DAY, { mapID = BARRENS, x = 0.55, y = 0.45 })
Row(P, "whisper_in", d0 + 4 * DAY)
local plate = PP.Pick(P)
Eq(plate and plate.key, "trade", "a trade with a spot of its own is not the plate")
Eq(plate.mapID, BARRENS, "the trade's map")
Eq(plate.x, 0.55, "the trade's own spot")
Eq(plate.road, nil, "a trade in no session drew a road")
Eq(plate.fallback, nil, "a placed trade is the fallback")

-- A group session on the hillside, with a rare killed in it: the rare,
-- placed by the route, outranks the trade; the session's road comes with it.
local session = { id = "s1", me = SELF, source = "group", startedAt = d0 + 1800, endedAt = d0 + 5400,
    zones = { "Mulgore" }, participants = { [P] = { seconds = 3600, last = d0 + 5400, quests = {},
        rares = { { name = "Rocklance", time = d0 + 3600 } } } },
    deathLog = { { guid = P, time = d0 + 4000 } } }
-- (a new table: the sessions' index is rebuilt for it)
ns.db.sessions = { s1 = session }
ns.Touch()
plate = PP.Pick(P)
Eq(plate.key, "rare", "a rare in a session lost to a trade")
Eq(plate.mapID, MULGORE, "the rare's map, from the route")
Eq(plate.x, 0.40, "the rare at the route's spot at the time")
Check(plate.road and plate.road.from == session.startedAt and plate.road.to == session.endedAt,
    "the road is not the session's stretch")
Eq(plate.road.me, SELF, "the road is not the user's character's")
for _, m in ipairs(plate.marks) do
    Check(m.key ~= "death" and m.mapID == MULGORE, "a death or another map's thing among the marks")
end

-- A note outranks everything, wherever it was written.
local note = { id = 1, time = d0 + 5 * DAY, me = SELF, about = { [P] = true }, text = "owes me",
    mapID = BARRENS, x = 0.2, y = 0.3 }
ns.db.notes[1] = note
ns.Touch()
plate = PP.Pick(P)
Eq(plate.key, "note", "a note does not outrank a rare")
Eq(plate.x, 0.2, "the note's own spot")
ns.db.notes[1] = nil

-- Only the newest ten count: ten /says after the rare push it out, and the
-- newest of equals wins.
for i = 1, 10 do
    Row(P, "say", d0 + 6 * DAY + i * 3600, { mapID = BARRENS, x = 0.1 * i % 1, y = 0.5 })
end
plate = PP.Pick(P)
Eq(plate.key, "say", "something past the newest ten still counted")
Eq(plate.t, d0 + 6 * DAY + 10 * 3600, "of equals, not the newest")
Check(#plate.marks <= PP.LOOK - 1, "more marks than the things weighed")

--------------------------------------------------------------------------
Section("the person's plate: deaths, the fallback, nothing")

-- Their death is never the plate, even as the newest thing of all.
Fresh()
P = Person({ mapID = MULGORE, x = 0.7, y = 0.7 })
ns.db.sessions = {}
ns.db.sessions.s2 = { id = "s2", me = SELF, source = "nearby", startedAt = d0 + 9 * DAY, endedAt = d0 + 9 * DAY + 600,
    zones = {}, participants = { [P] = { seconds = 600, last = d0 + 9 * DAY + 600 } },
    deathLog = { { guid = P, time = d0 + 9 * DAY + 300 } } }
ns.Touch()
plate = PP.Pick(P)
Check(plate and plate.key ~= "death", "a plain death was the plate")
-- (the session is off the route, so nothing is placed: where they met)
Eq(plate.fallback, true, "nothing placed and no fallback")
Eq(plate.key, "met", "the fallback is not where they met")
Eq(plate.x, 0.7, "where they were added")
Eq(#plate.marks, 0, "the fallback has marks")

-- A first group join, placed, is the meeting before the add.
Row(P, "group_join", d0 - 2 * DAY, { mapID = BARRENS, x = 0.33, y = 0.66 })
plate = PP.Pick(P)
Eq(plate.x, 0.33, "the first group join is not where they met")

-- With nothing to place at all, no plate.
Fresh()
P = Person()
Row(P, "whisper_in", d0 + 30 * DAY)
Eq(PP.Pick(P), nil, "a plate with nothing to place")
Eq(PP.For("Player-0000-NOBODY"), nil, "a plate for someone not in the diary")

-- A feature ranks its own rows; a kind that says nothing ranks last.
Eq(ns.Rows.Get("trade").plate, 7, "a trade's rank")
Eq(ns.Rows.Get("level_up").plate, nil, "a level-up ranks")
