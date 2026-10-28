-- Your Diary's recap (JRN-10 to JRN-13, JRN-15): the route crossed with
-- the diary, as entries a page can print.
--
-- The route is time-indexed, so everything is joined by time: a level is
-- the stretch from reaching it to reaching the next; a together session,
-- a fight, a note lands on the segments that were open while it happened.
-- That join is what makes the page more than a map.
--
--   Build(j, ctx)        the whole recap: the prologue, one entry per level
--                        (D8, never merged), one per week after the cap
--                        (D9), and the zone index
--   Sheet(j, mapID, ctx) what one zone plate draws, meetings placed
--   Plates(e, ctx, cover) the places an entry is remembered by (JRN-21)
--   FirstSightings(j, ctx) first sightings, in hindsight (JRN-23)
--   For(guid)            Build for a character of the user's, from the
--                        diary, cached until the route or the diary moves
--
-- Pure over its inputs, no frames and no unit tokens: the words are
-- in UI/Journey/Text/, the drawing UI/Journey/Plate.lua's. Like the timeline,
-- nothing here is stored; names and colours come from the diary when a page
-- is drawn, so a rename or a new alt grouping shows everywhere at once.

local addonName, ns = ...

local Journey = ns.Journey

local Recap = {}
ns.JourneyRecap = Recap

-- The longest stops an entry names, and how long one has to be.
local STOPS = { max = 3 }

-- JRN-23: how far from the route a time may fall and still be placed on it
-- (combat pauses the capture, so a fight's first sighting can sit in a gap),
-- and how close the first sighting and what made them matter may be and
-- still be one encounter, shown already as the meeting itself.
local HINDSIGHT = { slack = 120, encounter = 30 * 60 }

-- JRN-21: at most `max` plates an entry. A window fits its moments when
-- they span no more than `inset` of it, so no mark sits on the plate's
-- edge (`window` stands in when a map's art gives none). Rank decides
-- which places win (Decision 10): people, deaths, the features' own kinds
-- where they rank themselves, a zone new to the road, a dungeon's door, the
-- longest stays (one a zone), the longest road when there was nothing
-- else, and last the level-up spot: a level is reached anyway, so a place
-- is worth a plate for what happened there, not for the ding (12 Oct).
-- Ranks are only ever compared, never counted, so a feature's kind may
-- slot in between two with a fraction, moving nothing else.
local PLATES = { max = 3, inset = 0.8, window = 0.3 }
-- The features' kinds are ranked as they register (RegisterMoment
-- below): those registered from Features/<Name>/ say theirs there.
local RANK = { session = 1, fight = 1, note = 1, first = 1, death = 3, arrive = 4,
    dungeon = 5, stay = 6, road = 7, level = 8 }
Recap.RANK = RANK
-- A plate's weight (plate-weight proposal, 13 Oct): it is light when all it
-- holds is a place, nothing for the margin and a line of words at most, and
-- the right page gives it a small print instead of a full slot
-- (UI/Journey/Look.lua's LAYOUT). A first visit, a dungeon's door, a
-- stay, the road, a level's pin. Anything else is full: a
-- kind that puts a note in the margin (people, a feature's card) or one
-- no one has weighed yet, so a
-- new kind of moment is given a full plate until someone says otherwise.
-- (The features' light kinds say so as they register: `light`.)
local LIGHT = { arrive = true, dungeon = true, stay = true, road = true, level = true }
Recap.LIGHT = LIGHT
-- What a plate may hold besides a dungeon's door and still be only the
-- door (Recap.Plates drops it where the run was recorded).
local DOOR_ONLY = { arrive = true, level = true }
Recap.DOOR_ONLY = DOOR_ONLY

--------------------------------------------------------------------------
-- A feature's moments
--------------------------------------------------------------------------
--
-- What a feature notes on the road reaches the plates as moments of its
-- own kind.
-- Recap.RegisterMoment(kind, spec) declares one:
--
--   order   its place among the features' moments (Moments' order, which
--           the plates' grouping sees)
--   entry   the entry's field its records are gathered into (e[entry])
--   list    the route's list they come from (Core/Journey.lua's
--           RegisterList): those within the entry's time are gathered
--   gather  function(j, a, b, e, ctx), instead of `list`: fills e[entry]
--           (and any other entry it shares a list with: one list may make
--           two kinds, the second's gather doing nothing, its entry filled
--           by the first's, which comes first in `order`) itself
--   field   the moment's field that holds its record (m.call)
--   rank    its RANK (see above); `light` true makes it a light kind
--   rankAs  function(m): the RANK key a moment of it ranks as, where it is
--           not its kind (one that is someone's too may rank with the
--           people: "session")
--   moment  function(j, rec, Own) → moment, mapID, x, y: instead of the
--           record placed at its own spot (Own) as { kind, t, [field] }.
--           A moment that is someone's too (its `guid`: something they
--           gave you) may carry `person` = { tier, say = function(m) →
--           words }: how it stands among that person's own moments on
--           their margin note, once its mark joins their marks (the
--           plate mark's `join`, UI/Journey/Plate.lua): `tier` the note's
--           (UI/Journey/People.lua's Tier: 1 for something done together),
--           `say` its phrase, first under their name
--           (UI/Journey/Text/Margin.lua's MarginWhat)
--
-- An entry with any feature's records is kept, as one with people or time
-- on the road is (Recap.Build's weeks).

local MOMENTS, MOMENT = {}, {}
-- Every registered kind, by name (for tests/kinds.lua; read only).
Recap.MOMENTS = MOMENT

function Recap.RegisterMoment(kind, spec)
    spec.kind = kind
    spec.entry = spec.entry or spec.list
    MOMENT[kind] = spec
    MOMENTS[#MOMENTS + 1] = spec
    table.sort(MOMENTS, function(a, b) return (a.order or 0) < (b.order or 0) end)
    RANK[kind] = spec.rank
    LIGHT[kind] = spec.light or nil
    return spec
end

-- A moment's rank: its kind's, or the one its kind says it ranks as.
local function Rank(m)
    local spec = MOMENT[m.kind]
    return RANK[spec and spec.rankAs and spec.rankAs(m) or m.kind] or 9
end
Recap.Rank = Rank

--------------------------------------------------------------------------
-- Time
--------------------------------------------------------------------------

local function Overlap(from, to, a, b)
    return math.max(0, math.min(to, b) - math.max(from, a))
end

-- Whether `seg` falls in a..b at all (a segment of no length included).
local function Touches(seg, a, b)
    return seg.from < b and seg.to >= a
end

-- The time `seg` spent inside a..b. A stop's and a dungeon's own seconds,
-- shared out over their span; a road's or a flight's span.
local function Inside(seg, a, b)
    local span = Overlap(seg.from, seg.to, a, b)
    if span <= 0 then return 0 end
    local whole = seg.to - seg.from
    if (seg.kind == "stop" or seg.kind == "dungeon") and seg.seconds and whole > 0 then
        return seg.seconds * span / whole
    end
    return span
end

-- The level at `t`, as far as the route knows.
function Recap.LevelAt(j, t)
    local best, at = j.startLevel or 1, -math.huge
    for n, rec in pairs(j.levels or {}) do
        if rec.at <= t and rec.at > at then best, at = n, rec.at end
    end
    return best
end

-- Monday 00:00 local of the week `t` falls in (JRN-12). The half day added
-- and taken off again keeps a DST change from landing it on Sunday 23:00.
local function WeekStart(t)
    local back = (tonumber(date("%w", t)) + 6) % 7
    return ns.DayStart(ns.DayStart(t) - back * ns.DAY + 12 * 3600)
end

local function NextWeek(start)
    return ns.DayStart(start + 7 * ns.DAY + 12 * 3600)
end

--------------------------------------------------------------------------
-- What a stretch of time held
--------------------------------------------------------------------------

-- A stop's main activity, if one stands out: "fighting", "questing" or
-- "resting". Nothing counted, only named (no counters-as-goals).
function Recap.MainActivity(seg)
    local act, seconds = seg.act, seg.seconds or (seg.to - seg.from)
    if not act or seconds <= 0 then return nil end
    if (act.combat or 0) >= 0.25 * seconds then return "fighting" end
    if (act.questsOut or 0) + (act.questsIn or 0) >= 2 then return "questing" end
    if (act.resting or 0) >= 0.5 * seconds then return "resting" end
    if (act.combat or 0) > 0 then return "fighting" end
    return nil
end

-- The INS-1 visit a dungeon segment was, if one was recorded (JRN-8).
local function VisitFor(seg, visits)
    for _, visit in ipairs(visits or {}) do
        if visit.instanceID == seg.instanceID
            and Overlap(visit.startedAt or 0, visit.endedAt or visit.startedAt or 0, seg.from - 60, seg.to + 60) > 0 then
            return visit
        end
    end
    return nil
end

local function ByTime(a, b)
    return a.t < b.t
end

-- Everything between a and b: the places in the order visited with the
-- time in each, the longest stops in the order made, dungeons, flights, who you were with,
-- fights and notes.
local function Gather(j, a, b, ctx)
    local e = { from = a, to = b, places = {}, stops = {}, dungeons = {}, flights = {},
        people = {}, fights = {}, notes = {}, deaths = {}, roads = {}, seconds = 0 }
    for _, spec in ipairs(MOMENTS) do e[spec.entry] = {} end
    local byMap = {}

    for _, seg in ipairs(Journey.All(j)) do
        if Touches(seg, a, b) then
            local kind = seg.kind
            if kind == "stop" or kind == "road" then
                local seconds = Inside(seg, a, b)
                e.seconds = e.seconds + seconds
                if seg.mapID then
                    local place = byMap[seg.mapID]
                    if not place then
                        place = { mapID = seg.mapID, seconds = 0, first = seg.from }
                        byMap[seg.mapID] = place
                        e.places[#e.places + 1] = place
                    end
                    place.seconds = place.seconds + seconds
                end
                if kind == "stop" and seconds > 0 then
                    e.stops[#e.stops + 1] = { seg = seg, seconds = seconds, main = Recap.MainActivity(seg) }
                elseif kind == "road" and seconds > 0 then
                    e.roads[#e.roads + 1] = { seg = seg, seconds = seconds }
                end
                if seg.act and (seg.act.deaths or 0) > 0 and seg.from >= a then
                    e.deaths[#e.deaths + 1] = seg
                end
            elseif kind == "dungeon" then
                local seconds = Inside(seg, a, b)
                e.seconds = e.seconds + seconds
                local d = { seg = seg, name = seg.name, seconds = seconds, visit = VisitFor(seg, ctx.visits) }
                e.dungeons[#e.dungeons + 1] = d
                e.places[#e.places + 1] = { dungeon = d, name = seg.name, seconds = seconds, first = seg.from }
            elseif kind == "flight" then
                e.flights[#e.flights + 1] = seg
            end
        end
    end

    -- The longest stops kept, then told in the order they came: a diary
    -- goes from then to now.
    table.sort(e.stops, function(x, y) return x.seconds > y.seconds end)
    for i = #e.stops, STOPS.max + 1, -1 do e.stops[i] = nil end
    table.sort(e.stops, function(x, y) return x.seg.from < y.seg.from end)
    table.sort(e.roads, function(x, y) return x.seconds > y.seconds end)
    e.longestRoad = e.roads[1]
    e.roads = nil

    -- Who you were with: each participant's together time, shared out over
    -- the part of the session inside the stretch.
    local people, order = {}, {}
    for _, session in ipairs(ctx.sessions or {}) do
        local s1 = session.startedAt
        local s2 = session.endedAt or ns.Sessions.LastTogether(session)
        local span = Overlap(s1, s2, a, b)
        if span > 0 or (s1 >= a and s1 < b) then
            local whole = math.max(s2 - s1, 1)
            for guid, p in pairs(session.participants or {}) do
                local person = people[guid]
                if not person then
                    person = { guid = guid, seconds = 0, sessions = 0 }
                    people[guid] = person
                    order[#order + 1] = person
                end
                person.seconds = person.seconds + (p.seconds or 0) * span / whole
                person.sessions = person.sessions + 1
            end
        end
    end
    table.sort(order, function(x, y)
        if x.seconds ~= y.seconds then return x.seconds > y.seconds end
        return x.guid < y.guid
    end)
    e.people = order

    for _, mark in ipairs(j.marks or {}) do
        if mark.kind == "fight" and mark.t >= a and mark.t < b then e.fights[#e.fights + 1] = mark end
    end
    table.sort(e.fights, ByTime)

    for _, note in ipairs(ctx.notes or {}) do
        if note.time >= a and note.time < b then e.notes[#e.notes + 1] = note end
    end
    table.sort(e.notes, function(x, y) return x.time < y.time end)

    -- The features' (RegisterMoment): within the entry's time, oldest first.
    for _, spec in ipairs(MOMENTS) do
        if spec.gather then
            spec.gather(j, a, b, e, ctx)
        elseif spec.list then
            local into = e[spec.entry]
            for _, rec in ipairs(Journey.List(j, spec.list)) do
                if rec.t >= a and rec.t < b then into[#into + 1] = rec end
            end
        end
    end

    return e
end
Recap.Gather = Gather

-- Where a level was reached, with the dungeon it was reached in, if any.
local function Reached(j, n)
    local rec = j.levels and j.levels[n]
    if not rec then return nil end
    local reached = { at = rec.at, mapID = rec.mapID, x = rec.x, y = rec.y, subZone = rec.subZone }
    if not rec.mapID then
        for _, seg in ipairs(Journey.All(j)) do
            if seg.kind == "dungeon" and seg.from <= rec.at and rec.at <= seg.to then
                reached.dungeon = seg.name
                break
            end
        end
    end
    return reached
end

--------------------------------------------------------------------------
-- The recap
--------------------------------------------------------------------------

-- `ctx`: now, level (the character's now), maxLevel, sessions (theirs),
-- notes (theirs), visits (theirs).
function Recap.Build(j, ctx)
    local now = ctx.now or ns.Now()
    local maxLevel = ctx.maxLevel or Journey.MaxLevel()
    local first = j.startLevel or 1
    local top = math.max(first, ctx.level or first)

    local recap = { entries = {}, zones = {}, maxLevel = maxLevel, startedAt = j.startedAt }

    -- JRN-13: an honest line for a character begun past level 1.
    if first > 1 then
        recap.prologue = { level = first, mapID = j.startMapID, at = j.startedAt }
    end

    -- Where each level began: the route's start, then each level reached.
    local starts = { [first] = j.startedAt }
    for n, rec in pairs(j.levels or {}) do
        if n > first then starts[n] = rec.at end
    end

    -- D8: one entry per level below the cap, from where the route began.
    -- A level whose start the route never saw (capture was off) gets an
    -- entry with no time; the one before keeps it.
    -- Each ends where the next level came: `out`, that level reached (not
    -- for a level whose road was not kept).
    for n = first, math.min(top, maxLevel - 1) do
        local to, out = now, nil
        for m = n + 1, math.min(top, maxLevel) do
            if starts[m] then
                to, out = starts[m], m
                break
            end
        end
        local from = starts[n]
        local e = Gather(j, from or to, to, ctx)
        e.kind, e.level, e.known, e.current = "level", n, from ~= nil, n == top
        e.reached = n > first and Reached(j, n) or nil
        e.out = from and out and Reached(j, out) or nil
        if e.out then e.out.level = out end
        e.first = n == first
        recap.entries[#recap.entries + 1] = e
    end

    -- D9: past the cap, a week at a time (Monday to Monday, local), from
    -- the moment it was reached. Weeks without play have no entry.
    if top >= maxLevel then
        local capAt = starts[maxLevel]
        if not capAt then
            capAt = j.startedAt
            for _, seg in ipairs(Journey.All(j)) do
                if (seg.levelTo or 0) >= maxLevel then
                    capAt = seg.from
                    break
                end
            end
        end
        recap.capAt = capAt
        local week = WeekStart(capAt)
        local guard = 0
        while week <= now and guard < 1000 do
            guard = guard + 1
            local nextWeek = NextWeek(week)
            local a = math.max(week, capAt)
            local e = Gather(j, a, math.min(nextWeek, now + 1), ctx)
            e.kind, e.week = "week", week
            local any = e.seconds > 0 or #e.people > 0 or #e.fights > 0 or #e.notes > 0 or #e.flights > 0
            for _, spec in ipairs(MOMENTS) do any = any or #e[spec.entry] > 0 end
            if any then
                if a == capAt and first < maxLevel then e.reached, e.level = Reached(j, maxLevel), maxLevel end
                recap.entries[#recap.entries + 1] = e
            end
            week = nextWeek
        end
    end

    recap.zones = Recap.Zones(j)

    -- JRN-22, JRN-23: first sightings in hindsight, on the entry they fell
    -- in, and the faces of each entry.
    local sightings = Recap.FirstSightings(j, ctx)
    for _, e in ipairs(recap.entries) do
        e.hindsight = {}
        for _, f in ipairs(sightings) do
            if f.t >= e.from and f.t < e.to then e.hindsight[#e.hindsight + 1] = f end
        end
        e.faces = Recap.Faces(e, ctx)
    end
    return recap
end

-- JRN-15: every zone map with time on it, by first visit, with its level
-- range and the time spent there.
function Recap.Zones(j)
    local list, byMap = {}, {}
    for _, seg in ipairs(Journey.All(j)) do
        if (seg.kind == "stop" or seg.kind == "road") and seg.mapID then
            local z = byMap[seg.mapID]
            if not z then
                z = { mapID = seg.mapID, first = seg.from, last = seg.to, seconds = 0,
                    levelMin = seg.levelFrom, levelMax = seg.levelTo }
                byMap[seg.mapID] = z
                list[#list + 1] = z
            end
            z.last = math.max(z.last, seg.to)
            z.seconds = z.seconds + (seg.kind == "stop" and seg.seconds or (seg.to - seg.from))
            if seg.levelFrom and (not z.levelMin or seg.levelFrom < z.levelMin) then z.levelMin = seg.levelFrom end
            if seg.levelTo and (not z.levelMax or seg.levelTo > z.levelMax) then z.levelMax = seg.levelTo end
        end
    end
    table.sort(list, function(a, b) return a.first < b.first end)
    return list
end

--------------------------------------------------------------------------
-- One zone sheet (JRN-10, JRN-14)
--------------------------------------------------------------------------

-- Where a stretch a..b happened: the segment (not a flight) it overlapped
-- most, on `mapID` when given, and that segment's point at the middle of
-- the overlap: a stop's centre, a road's point nearest in time, a
-- dungeon's door. Returns mapID, x, y and that middle's time, or nil.
function Recap.Settle(j, a, b, mapID)
    local best, most = nil, -1
    for _, seg in ipairs(Journey.All(j)) do
        if seg.kind ~= "flight" and seg.mapID and (not mapID or seg.mapID == mapID) and Touches(seg, a, b + 1) then
            local span = Overlap(seg.from, seg.to, a, b)
            if span > most then best, most = seg, span end
        end
    end
    if not best then return nil end
    local t = math.max(best.from, a) + math.max(most, 0) / 2
    local map, x, y = Journey.PointIn(best, t)
    if not x then return nil end
    return map, x, y, t
end

-- Where on `mapID` the route was at `t`, if it was on that map then.
local function OnMap(j, mapID, t)
    local seg, map, x, y = Journey.At(j, t)
    if seg and map == mapID and x then return x, y, seg end
    return nil
end

-- What the sheet of `mapID` draws: its stops, roads, flights that start or
-- end on it, dungeons entered from it, the levels reached on it, and the
-- meetings placed on it -- each { kind, t, x, y, level, ... }.
function Recap.Sheet(j, mapID, ctx)
    ctx = ctx or {}
    local sheet = { mapID = mapID, stops = {}, roads = {}, flights = {}, dungeons = {}, pins = {}, meetings = {} }
    if not j then return sheet end

    for _, seg in ipairs(Journey.All(j)) do
        local kind = seg.kind
        if kind == "stop" and seg.mapID == mapID then
            sheet.stops[#sheet.stops + 1] = seg
        elseif kind == "road" and seg.mapID == mapID then
            sheet.roads[#sheet.roads + 1] = seg
        elseif kind == "flight" and (seg.mapID1 == mapID or seg.mapID2 == mapID) then
            sheet.flights[#sheet.flights + 1] = seg
        elseif kind == "dungeon" and seg.mapID == mapID and seg.x then
            sheet.dungeons[#sheet.dungeons + 1] = seg
        end
    end

    for n, rec in pairs(j.levels or {}) do
        if rec.mapID == mapID and rec.x then
            sheet.pins[#sheet.pins + 1] = { level = n, x = rec.x, y = rec.y, at = rec.at }
        end
    end
    table.sort(sheet.pins, function(a, b) return a.level < b.level end)

    local meetings = sheet.meetings

    -- Together sessions: at the segment on this map they overlapped most,
    -- the stop's centre or the road's point nearest in time.
    for _, session in ipairs(ctx.sessions or {}) do
        local s1 = session.startedAt
        local s2 = session.endedAt or ns.Sessions.LastTogether(session)
        local _, x, y = Recap.Settle(j, s1, s2, mapID)
        if x then
            meetings[#meetings + 1] = { kind = "session", t = s1, x = x, y = y, session = session,
                level = Recap.LevelAt(j, s1) }
        end
    end

    -- Fights: where they were fought, else by time.
    for _, mark in ipairs(j.marks or {}) do
        if mark.kind == "fight" then
            local x, y
            if mark.mapID == mapID and mark.x then
                x, y = mark.x, mark.y
            elseif not (mark.mapID and mark.x) then
                x, y = OnMap(j, mapID, mark.t)
            end
            if x then
                meetings[#meetings + 1] = { kind = "fight", t = mark.t, x = x, y = y, mark = mark,
                    level = Recap.LevelAt(j, mark.t) }
            end
        end
    end

    -- Notes: by their own position when it is on this zone's map, else by
    -- the time they were written.
    for _, note in ipairs(ctx.notes or {}) do
        local x, y
        if note.mapID == mapID and note.x then
            x, y = note.x, note.y
        elseif not (note.mapID and ns.ZoneOf(note.mapID) == note.mapID and note.x) then
            x, y = OnMap(j, mapID, note.time)
        end
        if x then
            meetings[#meetings + 1] = { kind = "note", t = note.time, x = x, y = y, note = note,
                level = note.myLevel or Recap.LevelAt(j, note.time) }
        end
    end

    table.sort(meetings, ByTime)
    return sheet
end

--------------------------------------------------------------------------
-- First sightings, in hindsight (JRN-23)
--------------------------------------------------------------------------

-- Where the route was at `t`: mapID, x, y, segment. Inside a segment, its point at
-- `t` (Journey.At); in a short gap (a fight pauses the capture), the
-- nearer end of the segments either side, within HINDSIGHT.slack. A time
-- this character's route never covered (an alt was playing) is nil.
function Recap.WhereAt(j, t)
    if not (j and t) then return nil end
    local seg, map, x, y = Journey.At(j, t)
    if seg then
        if x then return map, x, y, seg end
        return nil
    end
    local best, gap, at = nil, HINDSIGHT.slack, nil
    for _, s in ipairs(Journey.All(j)) do
        local d = s.to < t and t - s.to or s.from - t
        if d >= 0 and d <= gap then best, gap, at = s, d, s.to < t and s.to or s.from end
    end
    if not best then return nil end
    map, x, y = Journey.PointIn(best, at)
    if not x then return nil end
    return map, x, y, best
end

-- When `guid` first mattered (D6 amended), or nil: the earlier of being
-- added to the diary and an interaction row of grouping, trading,
-- whispering or saying something (`matters`). Only something done with
-- them: being seen again is not (11 Oct: passers-by seen on both sides of
-- midnight, never spoken to, took a plate's margin). `ctx` carries the
-- stores, read only: diary, interactions, characters.
function Recap.Matters(guid, ctx)
    local record = ctx.characters and ctx.characters[guid]
    if not (record and record.firstSeen) then return nil end
    local best
    local function Take(t)
        if t and (not best or t < best) then best = t end
    end

    local entry = ctx.diary and ctx.diary[guid]
    if entry then Take(entry.addedAt or record.firstSeen) end

    for _, row in ipairs(ctx.interactions and ctx.interactions[guid] or {}) do
        if ns.Rows.Get(row.type).matters then
            Take(row.time)
            break
        end
    end

    return best
end

-- JRN-23: the first sightings worth showing on `j`, oldest first: each
-- { guid, t, mapID, x, y, level, metLevel, mattered }. A first sighting
-- shows only once the person mattered later, not when that was the same
-- encounter (HINDSIGHT.encounter), and only where this character's road
-- was at the time. Nothing here is stored: the record goes, and so does
-- the sighting (INT-2).
function Recap.FirstSightings(j, ctx)
    local list = {}
    if not (j and ctx and ctx.characters) then return list end
    local own = ctx.own or {}
    local from, to = j.startedAt or -math.huge, ctx.now or math.huge
    for guid, record in pairs(ctx.characters) do
        local t = record.firstSeen
        if t and t >= from and t <= to and not record.isSelf and not own[guid] then
            local mattered = Recap.Matters(guid, ctx)
            if mattered and mattered - t > HINDSIGHT.encounter then
                local map, x, y, seg = Recap.WhereAt(j, t)
                if x then
                    list[#list + 1] = { guid = guid, t = t, mapID = map, x = x, y = y,
                        subZone = seg.kind == "stop" and seg.subZone or nil,
                        level = Recap.LevelAt(j, t), metLevel = Recap.LevelAt(j, mattered), mattered = mattered }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.guid < b.guid
    end)
    return list
end

-- JRN-23 on a People page: where `guid` was first seen, on whichever of
-- the user's characters' roads it happened, once they mattered. Nil when
-- the gate is not passed or no road was there.
function Recap.FirstSightingOf(guid, now)
    local ctx = { now = now or ns.Now(), diary = ns.db.diary, interactions = ns.db.interactions,
        characters = ns.db.characters, own = ns.OwnCharacters() }
    local record = ctx.characters[guid]
    if not (record and record.firstSeen) or record.isSelf or ctx.own[guid] then return nil end
    local t = record.firstSeen
    local mattered = Recap.Matters(guid, ctx)
    if not (mattered and mattered - t > HINDSIGHT.encounter) then return nil end
    for me, j in pairs(ns.db.journey or {}) do
        if (j.startedAt or math.huge) <= t then
            local map, x, y, seg = Recap.WhereAt(j, t)
            if x then
                return { guid = guid, me = me, t = t, mapID = map, x = x, y = y,
                    subZone = seg.kind == "stop" and seg.subZone or nil, level = Recap.LevelAt(j, t),
                    metLevel = Recap.LevelAt(j, mattered), mattered = mattered }
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Faces and plates (JRN-21, JRN-22)
--------------------------------------------------------------------------

-- JRN-22: everyone from the diary crossed in an entry, once each, in the
-- order met: { guid, t, rival }. A rival is a diary entry tagged "foe".
function Recap.Faces(e, ctx)
    local diary = ctx.diary or {}
    local seen, list = {}, {}
    local function Add(guid, t)
        if not (guid and diary[guid]) then return end
        local face = seen[guid]
        if face then
            if t < face.t then face.t = t end
            return
        end
        face = { guid = guid, t = t }
        for _, tag in ipairs(diary[guid].tags or {}) do
            if tag == "foe" then face.rival = true end
        end
        seen[guid] = face
        list[#list + 1] = face
    end
    for _, session in ipairs(ctx.sessions or {}) do
        local s1 = session.startedAt
        local s2 = session.endedAt or ns.Sessions.LastTogether(session)
        if Overlap(s1, s2, e.from, e.to) > 0 or (s1 >= e.from and s1 < e.to) then
            for guid in pairs(session.participants or {}) do Add(guid, math.max(s1, e.from)) end
        end
    end
    for _, mark in ipairs(e.fights or {}) do Add(mark.guid, mark.t) end
    for _, note in ipairs(e.notes or {}) do
        for guid in pairs(note.about or {}) do Add(guid, note.time) end
    end
    for _, f in ipairs(e.hindsight or {}) do Add(f.guid, f.t) end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.guid < b.guid
    end)
    return list
end

-- A position for a note or a fight mark: its own when that is on a zone
-- map, else the route's at its time (as the plates and Sheet place them).
local function Own(j, mapID, x, y, t)
    if mapID and x and ns.ZoneOf and ns.ZoneOf(mapID) == mapID then return mapID, x, y end
    return Recap.WhereAt(j, t)
end

-- What put an entry's places on the page (JRN-21): every moment of `e`
-- with a spot on a zone map, each { kind, mapID, x, y, t, ... }.
function Recap.Moments(j, e, ctx)
    local list = {}
    local function Add(m, map, x, y)
        if not (map and x) then return end
        m.mapID, m.x, m.y = map, x, y
        list[#list + 1] = m
    end

    for _, session in ipairs(ctx.sessions or {}) do
        local s1 = session.startedAt
        local s2 = session.endedAt or ns.Sessions.LastTogether(session)
        local a, b = math.max(s1, e.from), math.min(s2, e.to)
        if b > a or (s1 >= e.from and s1 < e.to) then
            -- At the time it was where it is marked, not when the entry
            -- began: a session already under way would share that moment
            -- with the level's own pin, a plate away.
            -- Its time together is this entry's share of it, as the entry's
            -- people have it (Gather), not the whole session's: a session
            -- over three levels is not three times as long (11 Oct, in the
            -- client: "2 h 41 min together" under levels 8, 9 and 10).
            local map, x, y, t = Recap.Settle(j, a, math.max(a, b))
            local share = Overlap(s1, s2, e.from, e.to) / math.max(s2 - s1, 1)
            for guid, p in pairs(session.participants or {}) do
                Add({ kind = "session", guid = guid, t = t or a, session = session,
                    seconds = (p.seconds or 0) * share }, map, x, y)
            end
        end
    end
    for _, mark in ipairs(e.fights or {}) do
        local map, x, y = Own(j, mark.mapID, mark.x, mark.y, mark.t)
        Add({ kind = "fight", guid = mark.guid, outcome = mark.outcome, t = mark.t, mark = mark }, map, x, y)
    end
    for _, note in ipairs(e.notes or {}) do
        local map, x, y = Own(j, note.mapID, note.x, note.y, note.time)
        for guid in pairs(note.about or {}) do
            Add({ kind = "note", guid = guid, t = note.time, note = note }, map, x, y)
        end
    end
    for _, f in ipairs(e.hindsight or {}) do
        Add({ kind = "first", guid = f.guid, t = f.t, metLevel = f.metLevel, first = f }, f.mapID, f.x, f.y)
    end
    if e.reached and e.reached.mapID then
        Add({ kind = "level", level = e.level, t = e.reached.at }, e.reached.mapID, e.reached.x, e.reached.y)
    end
    -- Where the level ended, the next one reached: a plate shows both ends.
    if e.out and e.out.mapID then
        Add({ kind = "level", level = e.out.level, t = e.out.at, out = true }, e.out.mapID, e.out.x, e.out.y)
    end
    for _, seg in ipairs(e.deaths or {}) do
        local map, x, y = Journey.PointIn(seg, (seg.from + seg.to) / 2)
        Add({ kind = "death", t = seg.from, seg = seg }, map, x, y)
    end
    -- The features' (RegisterMoment), each record where it happened.
    for _, spec in ipairs(MOMENTS) do
        for _, rec in ipairs(e[spec.entry] or {}) do
            if spec.moment then
                Add(spec.moment(j, rec, Own))
            else
                local map, x, y = Own(j, rec.mapID, rec.x, rec.y, rec.t)
                Add({ kind = spec.kind, t = rec.t, [spec.field] = rec }, map, x, y)
            end
        end
    end
    -- A zone new to the road: its first spot, when this entry holds it.
    local firsts = {}
    for _, seg in ipairs(Journey.All(j)) do
        if (seg.kind == "stop" or seg.kind == "road") and seg.mapID and not firsts[seg.mapID] then
            firsts[seg.mapID] = seg
        end
    end
    for map, seg in pairs(firsts) do
        if seg.from >= e.from and seg.from < e.to then
            local _, x, y = Journey.PointIn(seg, seg.from)
            Add({ kind = "arrive", t = seg.from, seg = seg }, map, x, y)
        end
    end
    for _, d in ipairs(e.dungeons or {}) do
        Add({ kind = "dungeon", t = d.seg.from, seg = d.seg, name = d.name, visit = d.visit }, d.seg.mapID, d.seg.x,
            d.seg.y)
    end
    for _, stop in ipairs(e.stops or {}) do
        local seg = stop.seg
        Add({ kind = "stay", t = seg.from, seg = seg, seconds = stop.seconds }, seg.mapID, seg.x, seg.y)
    end
    if e.longestRoad then
        local seg = e.longestRoad.seg
        local mid = (math.max(seg.from, e.from) + math.min(seg.to, e.to)) / 2
        local map, x, y = Journey.PointIn(seg, mid)
        Add({ kind = "road", t = seg.from, seg = seg, seconds = e.longestRoad.seconds }, map, x, y)
    end
    return list
end

-- Whether `m` fits in `plate` at the window w, h: the moments' box with it
-- added spans no more than PLATES.inset of the window either way.
local function Fits(plate, m, w, h)
    if plate.mapID ~= m.mapID then return false end
    local x0, x1 = math.min(plate.x0, m.x), math.max(plate.x1, m.x)
    local y0, y1 = math.min(plate.y0, m.y), math.max(plate.y1, m.y)
    return x1 - x0 <= w * PLATES.inset and y1 - y0 <= h * PLATES.inset
end

-- Whether `plate` (Recap.Plates's) still holds at another window w, h than
-- the one it was grouped at: its moments span no more than PLATES.inset of
-- it, as Fits asks of each moment going in. The UI asks it of a slot of
-- another size (a small print, a page whose slots differ).
function Recap.Holds(plate, w, h)
    return plate.x1 - plate.x0 <= w * PLATES.inset and plate.y1 - plate.y0 <= h * PLATES.inset
end

-- JRN-21 (Decisions 2, 3, 10): the places `e` is remembered by, at most
-- PLATES.max, oldest first. A plate is a place, not an event: moments go
-- into the first plate whose window they fit, most important first, so a
-- level spent on one hillside is one plate. The places with the best
-- moments win; ties go to the busier, then the earlier. `cover(mapID)` is
-- the plate's window on that map in 0..1 units (w, h), from the art: the
-- UI's to know, a constant in the tests. Each plate: { mapID, cx, cy, t,
-- rank, moments, light }, its moments in time order, `light` when every
-- one of them is a LIGHT kind.
function Recap.Plates(j, e, ctx, cover)
    local moments = Recap.Moments(j, e, ctx or {})
    -- A level's pins rank last, so they are placed after everything else:
    -- one joins the plate of whatever happened where it was reached, and
    -- never stretches a plate's box before a moment that matters is in.
    table.sort(moments, function(a, b)
        local ra, rb = Rank(a), Rank(b)
        if ra ~= rb then return ra < rb end
        return a.t < b.t
    end)
    local plates = {}
    for _, m in ipairs(moments) do
        local w, h = cover(m.mapID)
        w, h = w or PLATES.window, h or PLATES.window
        local into
        for _, plate in ipairs(plates) do
            if Fits(plate, m, w, h) then
                into = plate
                break
            end
        end
        if into then
            into.x0, into.x1 = math.min(into.x0, m.x), math.max(into.x1, m.x)
            into.y0, into.y1 = math.min(into.y0, m.y), math.max(into.y1, m.y)
            into.moments[#into.moments + 1] = m
            into.t = math.min(into.t, m.t)
        else
            -- Only a moment that would win a plate opens one. A long stay
            -- opens one in a zone no plate shows yet (a level that went
            -- somewhere quiet still shows it went); the longest road, and
            -- then a level's pin, only when there is nothing at all. A pin alone
            -- took a plate, and the same spot is the next level's start:
            -- one level-up was two plates (11 Oct, in the client: Goldshire
            -- last under level 9 and first under level 10, empty both times).
            local rank, shown = Rank(m), false
            for _, plate in ipairs(plates) do shown = shown or plate.mapID == m.mapID end
            local opens = m.kind ~= "level" and (rank < RANK.stay or (rank == RANK.stay and not shown))
            if opens or #plates == 0 then
                plates[#plates + 1] = { mapID = m.mapID, x0 = m.x, x1 = m.x, y0 = m.y, y1 = m.y,
                    t = m.t, rank = rank, moments = { m } }
            end
        end
    end
    -- A plate that is only a dungeon's door (with an arrival or a level's
    -- pin at most) is left out where the run behind the door was recorded:
    -- the run has a page of its own (UI/Journey/Run.lua; the user, 28 Oct),
    -- and a map with one door on it beside it says nothing more.
    for i = #plates, 1, -1 do
        local doorOnly, recorded = true, false
        for _, m in ipairs(plates[i].moments) do
            if m.kind == "dungeon" then
                recorded = recorded or m.visit ~= nil
            elseif not DOOR_ONLY[m.kind] then
                doorOnly = false
            end
        end
        if doorOnly and recorded then table.remove(plates, i) end
    end
    table.sort(plates, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if #a.moments ~= #b.moments then return #a.moments > #b.moments end
        return a.t < b.t
    end)
    for i = #plates, PLATES.max + 1, -1 do plates[i] = nil end
    for _, plate in ipairs(plates) do
        plate.cx, plate.cy = (plate.x0 + plate.x1) / 2, (plate.y0 + plate.y1) / 2
        table.sort(plate.moments, ByTime)
        plate.light = true
        for _, m in ipairs(plate.moments) do plate.light = plate.light and LIGHT[m.kind] == true end
    end
    table.sort(plates, ByTime)
    return plates
end

--------------------------------------------------------------------------
-- From the diary, cached
--------------------------------------------------------------------------

-- What the diary holds of the user's character `guid`: its sessions, notes
-- and instance visits; and, read only, the stores first sightings are
-- judged from (JRN-23): the diary, the buffer, the records, and the user's
-- own characters.
function Recap.Context(guid, now)
    local ctx = { now = now or ns.Now(), maxLevel = Journey.MaxLevel(), sessions = {}, notes = {}, visits = {},
        diary = ns.db.diary, interactions = ns.db.interactions, characters = ns.db.characters,
        own = ns.OwnCharacters() }
    for _, session in pairs(ns.db.sessions) do
        if session.me == guid then ctx.sessions[#ctx.sessions + 1] = session end
    end
    table.sort(ctx.sessions, function(a, b) return a.startedAt < b.startedAt end)
    for _, note in pairs(ns.db.notes) do
        if note.me == guid then ctx.notes[#ctx.notes + 1] = note end
    end
    for _, visit in pairs(ns.db.instances) do
        if visit.me == guid then ctx.visits[#ctx.visits + 1] = visit end
    end
    if guid == ns.ownGUID then
        ctx.level = ns.Plain(UnitLevel("player"))
    end
    local own = ns.OwnCharacters()[guid]
    ctx.level = ctx.level or (own and own.level)
    -- /sd testdata's route plays at a pretend cap of its own.
    local j = Journey.For(guid)
    if j and j.test then
        ctx.maxLevel, ctx.level = j.test.maxLevel or ctx.maxLevel, j.test.level or ctx.level
    end
    return ctx
end

-- The recap is rebuilt only when the route or the diary moved (Journey's
-- version, ns.dataVersion), someone was seen or dealt with anew
-- (ns.seenVersion: a stranger can come to matter, JRN-23), the day turned
-- (a later day), or the character's level did; never per frame.
local cache = {}

function Recap.For(guid)
    local j = Journey.For(guid)
    if not j then return nil end
    local ctx = Recap.Context(guid)
    local key = ("%d:%d:%d:%d:%s"):format(Journey.version, ns.dataVersion, ns.seenVersion or 0,
        ns.DayStart(ctx.now), tostring(ctx.level))
    local hit = cache[guid]
    if hit and hit.key == key and hit.j == j then return hit.recap, hit.ctx end
    local recap = Recap.Build(j, ctx)
    cache[guid] = { key = key, j = j, recap = recap, ctx = ctx }
    return recap, ctx
end

function Recap.SheetFor(guid, mapID)
    local j = Journey.For(guid)
    local _, ctx = Recap.For(guid)
    return Recap.Sheet(j, mapID, ctx or {})
end
