-- The one plate on a person's page (person-page proposal, variant A; the
-- user's decisions of 20 Oct): a print of the map where something with
-- them happened, as Your Diary prints the places of a level.
--
-- Which place: of the 10 newest things on their timeline that can be put
-- on a map, the one that ranks highest; the newer on a tie. A plain death
-- never counts. Something can be put on a map when it kept a spot of its
-- own on a zone map, or when the user's own route (that character's) says
-- where they were at the time: a rare kill or a session keeps only zone
-- names, the route places it. With nothing to place, the plate shows where
-- they first met, and with no spot for that either, there is no plate.
--
-- The plate names no place, and draws the route of the together session
-- the event happened in, nothing else of the road.
--
-- Ranks follow Your Diary's (Core/JourneyRecap.lua's RANK, lower first)
-- where the kinds meet: fights and notes first, a dungeon's door below a
-- rare. A row's is its kind's `plate` (Core/Rows.lua), so a feature ranks
-- its own; the timeline's own items rank here. Computed per read, cached
-- until the diary or the route moves; nothing is saved.

local addonName, ns = ...

local PersonPlate = {}
ns.PersonPlate = PersonPlate

-- How many of the newest placed things are weighed.
local LOOK = 10
-- A thing ranks this when nobody said otherwise.
local LAST = 9
PersonPlate.LOOK, PersonPlate.LAST = LOOK, LAST

-- The timeline's own items (Core/Timeline.lua). A session in a group is
-- questing together; one nearby is being around each other. Not here: a
-- death (never counts), "added to the diary" (the meeting's fallback).
local RANK = { note = 1, rare = 4, visit = 5, group = 8, session = LAST, around = LAST, first = LAST }
PersonPlate.RANK = RANK

-- A session may end this long before something of it still counts as in it
-- (a row written as the session closes).
local SLACK = 2 * 60

-- A spot on a zone map for something at `t`: its own when it has one, else
-- the user's character `me`'s route at that time. mapID, x, y or nil.
local function Spot(me, mapID, x, y, t)
    if mapID and x and ns.ZoneOf(mapID) == mapID then return mapID, x, y end
    local j = me and ns.Journey.For(me)
    if not (j and t) then return nil end
    local map, rx, ry = ns.JourneyRecap.WhereAt(j, t)
    if rx then return map, rx, ry end
    return nil
end

-- A stretch a..b on `me`'s route: where it spent most of it.
local function Stretch(me, a, b)
    local j = me and ns.Journey.For(me)
    if not (j and a) then return nil end
    local map, x, y = ns.JourneyRecap.Settle(j, a, math.max(a, b or a))
    if x then return map, x, y end
    return nil
end

local function SessionEnd(session)
    return session.endedAt or ns.Sessions.LastTogether(session)
end

-- Everything on the timeline that can count, each { key, rank, t, me,
-- mapID, x, y, item } where it can be placed; nested lines included.
local function Gather(items, me, into)
    for _, item in ipairs(items or {}) do
        local kind = item.kind
        local key, rank, t, map, x, y, who
        if kind == "row" then
            local row = item.row
            local spec = ns.Rows.Get(row.type)
            if spec.plate ~= false then
                key, rank, t, who = row.type, spec.plate or LAST, row.time, row.me or me
                map, x, y = Spot(who, row.mapID, row.x, row.y, row.time)
            end
        elseif kind == "note" then
            local note = item.note
            key, rank, t, who = "note", RANK.note, note.time, note.me
            map, x, y = Spot(who, note.mapID, note.x, note.y, note.time)
        elseif kind == "session" then
            local session = item.session
            key = session.source == "group" and "group" or "session"
            rank, t, who = RANK[key], session.startedAt, session.me
            map, x, y = Stretch(who, session.startedAt, SessionEnd(session))
        elseif kind == "visit" then
            local visit = item.visit
            key, rank, t, who = "visit", RANK.visit, visit.startedAt, visit.me
            map, x, y = Stretch(who, visit.startedAt, visit.endedAt or ns.Now())
        elseif kind == "rare" then
            key, rank, t, who = "rare", RANK.rare, item.time, me
            map, x, y = Spot(who, nil, nil, nil, item.time)
        elseif kind == "around" then
            local stretch = item.around
            key, rank, t, who = "around", RANK.around, stretch.start, stretch.me
            map, x, y = Stretch(who, stretch.start, stretch.last)
        elseif kind == "first" then
            local first = item.first
            key, rank, t, who = "first", RANK.first, first.t, first.me
            map, x, y = first.mapID, first.x, first.y
        end
        if key and map and x then
            into[#into + 1] = { key = key, rank = rank, t = t, me = who, mapID = map, x = x, y = y, item = item }
        end

        -- What happened inside: a session's or a visit's lines and notes, a
        -- climb's level-ups, an exchange's rows.
        local inner = kind == "session" and item.session.me or kind == "visit" and item.visit.me or me
        Gather(item.all, inner, into)
        Gather(item.ups, inner, into)
        Gather(item.deaths, inner, into)
        for _, note in ipairs(item.notes or {}) do
            Gather({ { kind = "note", time = note.time, note = note } }, inner, into)
        end
    end
    return into
end

-- The together session (of theirs) `t` falls in, or nil.
local function SessionAt(guid, t, visit)
    for _, session in ipairs(ns.Sessions.For(guid)) do
        if visit then
            for _, id in ipairs(visit.sessionIds or {}) do
                if session.id == id then return session end
            end
        elseif t >= session.startedAt and t <= SessionEnd(session) + SLACK then
            return session
        end
    end
    return nil
end

-- Where they first met: the earliest placed of their first group join, the
-- spot they were added at, and their first sighting in hindsight.
local function Met(guid, entry)
    local best
    local function Take(key, t, me, mapID, x, y)
        if not t then return end
        local map, sx, sy = Spot(me, mapID, x, y, t)
        if sx and (not best or t < best.t) then
            best = { key = key, rank = LAST, t = t, me = me, mapID = map, x = sx, y = sy }
        end
    end
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row.type == "group_join" then
            Take("met", row.time, row.me, row.mapID, row.x, row.y)
            break
        end
    end
    local added = entry.addedContext
    if added then Take("met", entry.addedAt, entry.addedBy, added.mapID, added.x, added.y) end
    local first = ns.JourneyRecap.FirstSightingOf(guid)
    if first then Take("met", first.t, first.me, first.mapID, first.x, first.y) end
    return best
end

-- The plate for `guid`, or nil when nothing of them can be placed:
--   mapID, x, y  where it is centred: the event's spot
--   key, rank, t the event: its key (a row's type, or "note", "rare",
--                "visit", "group", "session", "around", "first"; "met" for
--                the fallback), rank and time; `item` its timeline item
--   fallback     true when it is where they first met, nothing else placed
--   road         { me, mapID, from, to }: the together session's stretch of
--                `me`'s route to draw (the ink trail, clipped to the map
--                and the times), or nil when it was in no session
--   marks        the other weighed things on the same map, newest first
--                (each as the event), for the UI to keep those that fall
--                inside the print
function PersonPlate.Pick(guid)
    guid = ns.SafeGUID(guid)
    local entry = guid and ns.Diary.Get(guid)
    if not entry then return nil end

    local placed = Gather(ns.Timeline.For(guid), nil, {})
    table.sort(placed, function(a, b) return a.t > b.t end)
    for i = #placed, LOOK + 1, -1 do placed[i] = nil end

    local pick
    for _, c in ipairs(placed) do
        if not pick or c.rank < pick.rank then pick = c end
    end

    if not pick then
        local met = Met(guid, entry)
        if not met then return nil end
        met.fallback, met.marks = true, {}
        return met
    end

    local marks = {}
    for _, c in ipairs(placed) do
        if c ~= pick and c.mapID == pick.mapID then marks[#marks + 1] = c end
    end
    pick.marks = marks

    local session
    if pick.key == "group" or pick.key == "session" then
        session = pick.item.session
    else
        session = SessionAt(guid, pick.t, pick.key == "visit" and pick.item.visit or nil)
    end
    if session then
        pick.road = { me = session.me, mapID = pick.mapID, from = session.startedAt, to = SessionEnd(session) }
    end
    return pick
end

-- Cached until the diary, the route or what was seen moves.
local cache = {}

function PersonPlate.For(guid)
    local key = ("%d:%d:%d"):format(ns.Journey.version or 0, ns.dataVersion or 0, ns.seenVersion or 0)
    local hit = cache[guid]
    if hit and hit.key == key then return hit.plate end
    local plate = PersonPlate.Pick(guid)
    cache[guid] = { key = key, plate = plate }
    return plate
end
