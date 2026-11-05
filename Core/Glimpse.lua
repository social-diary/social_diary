-- A stranger's glimpse (the stranger-glimpse proposal, 5 Nov 2026): what
-- the diary has pencilled in about someone who is not in it, read for the
-- People page's right page (UI/Journal/Glimpse.lua), where their page will
-- be written once they are added.
--
-- A first sighting in hindsight (JRN-23) puts a stranger on a Your Diary
-- plate once they mattered later, and their margin strip names them; a
-- witness card and a custom "met" strip can name one too. A click on any
-- of them used to turn to an empty People page, as SelectPerson found no
-- diary entry. The glimpse is the answer to "who was that, and why are they
-- on my plate?": where you first saw them, what made them matter (the
-- hinge, Recap.Hinge: the very row the plate's gate reads), the few things
-- that happened after, how often they were seen, and how long the pencil
-- lasts.
--
-- Nothing is stored and nothing is cached here: everything is read from the
-- stores the buffer prunes (interactions, sightings, the record), so the
-- page and the plate never disagree about whether someone qualifies or
-- what their hinge was, and a glimpse whose record went is simply nil.
-- No frames.

local addonName, ns = ...

local Glimpse = {}
ns.Glimpse = Glimpse

-- What the glimpse gathers of the rows after the hinge: at most `after`
-- of them, newest first (the page's ledger lines, UI/Journal/Glimpse.lua's
-- GLIMPSE.ledger), the rest counted as `more`.
local LOOK = { after = 3 }
Glimpse.LOOK = LOOK

-- Whether `kind` (an interaction row's type) is one that makes a person
-- matter (Core/Rows.lua's `matters`): grouping, trading, a whisper, a /say.
local function Matters(row)
    return ns.Rows.Get(row.type).matters == true
end

-- Where they were first seen: the hindsight gate's own sighting where it
-- passes (Recap.FirstSightingOf), else, ungated, the record's firstSeen
-- placed on whichever road was there (Recap.OnRoads), else the time alone.
-- { t, me, mapID, x, y, subZone, level (yours), theirLevel } or nil.
-- Their level then only where the oldest raw sighting row is that first
-- sighting: the summary's levelMin is not "then".
local function First(guid, record, now)
    local first = ns.JourneyRecap.FirstSightingOf(guid, now)
    if not first and record.firstSeen then
        local t = record.firstSeen
        local me, j, map, x, y, seg = ns.JourneyRecap.OnRoads(t)
        if me then
            first = { guid = guid, me = me, t = t, mapID = map, x = x, y = y,
                subZone = seg.kind == "stop" and seg.subZone or nil, level = ns.JourneyRecap.LevelAt(j, t) }
        else
            first = { guid = guid, t = t }
        end
    end
    if not first then return nil end
    local rows = ns.Sightings.For(guid)
    if rows[1] and rows[1].time == first.t then first.theirLevel = rows[1].level end
    return first
end

-- The latest thing the buffer still holds of them: their last interaction
-- row, their last raw sighting (its zone-hour's end), and the record's
-- lastSeen.
local function Latest(guid, record)
    local latest = record.lastSeen or record.firstSeen or 0
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row.time and row.time > latest then latest = row.time end
    end
    for _, row in ipairs(ns.Sightings.For(guid)) do
        local t = math.max(row.time or 0, row.last or 0)
        if t > latest then latest = t end
    end
    return latest
end

-- When the pencil runs out for `guid`: the latest thing the buffer holds
-- of them plus bufferDays. The record goes at the next login after it at
-- the latest (pruning runs at login), so it is a day to say "until", not a
-- time. Nil without a record.
function Glimpse.Until(guid)
    local record = ns.db.characters[guid]
    if not record then return nil end
    return Latest(guid, record) + ns.BufferDays() * ns.DAY
end

-- The glimpse of `guid`, read now; nil for a diary entry (they have a
-- page), one of the user's own characters, or someone with no record:
--   guid, name    their full name as the record has it last
--   record        the character record (level, race, class, faction, seen)
--   first         where they were first seen (First, above), or nil
--   hinge         the first interaction row that `matters`, or nil (a thin
--                 glimpse: opened from a witness card or a "met" strip)
--   after         the rows that matter after the hinge, newest first, at
--                 most LOOK.after; `more` how many past those
--   seen          { days, since, count } from the sightings' summary, or
--                 nil where they were never sighted
--   ["until"]     Glimpse.Until's time
function Glimpse.Of(guid, now)
    guid = ns.SafeGUID(guid)
    if not guid or ns.Diary.Get(guid) then return nil end
    local record = ns.db.characters[guid]
    if not record or record.isSelf or ns.OwnCharacters()[guid] then return nil end
    now = now or ns.Now()

    local g = { guid = guid, record = record, now = now,
        name = ns.Characters.FullName(guid) or ns.Characters.Name(guid) or "" }
    g.first = First(guid, record, now)

    -- The hinge, through the plate's own reader (they are not in the
    -- diary, so it is a row or nothing); then what came after it.
    local ctx = { diary = ns.db.diary, interactions = ns.db.interactions, characters = ns.db.characters }
    local hinge, _, how = ns.JourneyRecap.Hinge(guid, ctx)
    if how == "row" then g.hinge = hinge end
    if not g.hinge then
        -- No firstSeen to gate on: the first row that matters all the same.
        for _, row in ipairs(ns.Interactions.For(guid) or {}) do
            if Matters(row) then
                g.hinge = row
                break
            end
        end
    end
    local later = {}
    local past = false
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row == g.hinge then
            past = true
        elseif past and Matters(row) then
            later[#later + 1] = row
        end
    end
    g.after, g.more = {}, 0
    for i = #later, 1, -1 do
        if #g.after < LOOK.after then g.after[#g.after + 1] = later[i] else g.more = g.more + 1 end
    end

    local summary = ns.Sightings.Summary(guid)
    if summary then g.seen = { days = summary.days or 1, since = summary.first, count = summary.count } end
    g["until"] = Glimpse.Until(guid)
    return g
end

-- Where adding them from the glimpse says they were met (the user's
-- decision 2, and the proposal's data check, 5 Nov 2026): the hinge row's
-- own place, the user's own position when it was written (zone, mapID, x,
-- y, instanceID; rows keep no subzone). Its coordinates are optional: none
-- inside an instance (zone only, by design), none outdoors where the
-- position was secret, and no zone through a loading screen. So, in order:
-- the row's place, its spot filled from the user's route at the row's time
-- (Recap.WhereAt, as the person plate's Spot does) where the row has none
-- and was not inside; the route alone where the row has no place at all;
-- and nil, so Diary.Add takes ns.Where() as adding always has.
function Glimpse.Where(g)
    local row = g and g.hinge
    if not row then return nil end
    local j = row.me and ns.Journey.For(row.me)
    local map, x, y
    if j and row.time and not row.instanceID and not row.x then
        map, x, y = ns.JourneyRecap.WhereAt(j, row.time)
    end
    if row.zone or row.mapID then
        local where = { zone = row.zone, mapID = row.mapID, x = row.x, y = row.y, instanceID = row.instanceID }
        if x and not where.x and (not where.mapID or where.mapID == map) then
            where.mapID, where.x, where.y = map, x, y
        end
        return where
    end
    if x then return { zone = ns.MapName(map), mapID = map, x = x, y = y } end
    return nil
end

-- Adds them from the glimpse (its foot strip's link): one click, as
-- Recently nearby's "+ Add" is, at the place they were met (Glimpse.Where).
-- `source` "journey" is a new value of the existing free addedContext.source
-- (no schema step: nothing is reinterpreted). Returns Diary.Add's entry and
-- whether it was new.
function Glimpse.Add(guid)
    local g = Glimpse.Of(guid)
    if not g then return ns.Diary.Get(guid), false end
    return ns.Diary.Add(g.guid, { source = "journey", where = Glimpse.Where(g) })
end
