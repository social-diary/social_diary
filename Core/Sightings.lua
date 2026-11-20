-- The sighting store (prd.md section 7; SIG-3, SIG-4, SIG-7).
--
-- "I saw this character here." This file keeps the rows; Capture/Sightings.lua
-- decides what counts as a sighting and when to listen, and hands rows over
-- one at a time.
--
-- Layout: db.sightings[guid] = { row, row, ... }, oldest first, the way the
-- interaction buffer is kept. Per character rather than one flat list because
-- every question asked of it is per character: SIG-4's dedup looks at one
-- character's last hour, PRV-3's forget drops one key, and SIG-7's roll-up
-- writes into one character's summary.
--
-- A row:
--   time      when this zone-hour's first sighting happened
--   last      the latest sighting folded into it, when later than `time`
--   level     their level, last read
--   mapID, x, y   the *user's* position at `time` (Core/Location.lua says why)
--   zone      the zone name, only when there was no mapID to store
--   subZone   the subzone the user was in at `time`, when it had a name
--   hostile   true when they were attackable at some point in it
--   src       which source saw them first ("plate", "target", "say", ...)

local addonName, ns = ...

-- SIG-4: at most one row per character per zone per hour, and a meeting
-- that crosses a zone line stays on its first row (#42).
local BUCKET_SECONDS = 60 * 60
local DAY = ns.DAY
local DayStart = ns.DayStart

local Sightings = {}
ns.Sightings = Sightings

-- REU-6 needs "seen before this encounter", which the rows cannot say on
-- their own: SIG-4 folds a whole zone-hour into one row, so the moment a
-- nameplate appears, the row holding the *earlier* sighting is updated to
-- now. So the encounter is tracked as it happens instead. Pulses closer than
-- ENCOUNTER_GAP are one encounter; a longer gap starts the next one, which
-- remembers when they were last seen before it.
--
-- [guid] = { last, before, newRow }. In memory only: after a /reload an
-- encounter already under way has `before = false`, "not known".
local ENCOUNTER_GAP = 5 * 60
local encounters = {}

local function Last(row)
    return row.last or row.time
end
Sightings.Last = Last

-- Same zone, for SIG-4. The map id where there is one; the zone name is only
-- the fallback for the restricted maps that hand back no id.
local function SamePlace(row, where)
    if row.mapID or where.mapID then return row.mapID == where.mapID end
    return row.zone == where.zone
end

-- When they were last seen, over all rows. The newest row is not always the
-- latest-seen one: an older zone's row can have been updated after it. A row
-- only takes updates during its own hour, though, so nothing older than an
-- hour before the newest can beat it.
local function LatestRow(rows)
    local newest = rows[#rows]
    local row = newest
    for i = #rows - 1, 1, -1 do
        local candidate = rows[i]
        if candidate.time <= newest.time - BUCKET_SECONDS then break end
        if Last(candidate) > Last(row) then row = candidate end
    end
    return row
end

local function Encounter(guid, rows, now)
    local enc = encounters[guid]
    if enc and now - enc.last <= ENCOUNTER_GAP then
        enc.last = math.max(enc.last, now)
        return enc
    end

    local latest = #rows > 0 and Last(LatestRow(rows)) or nil
    local before = latest
    if latest and now - latest <= ENCOUNTER_GAP then
        -- Seen moments ago, but not by this session: a /reload mid-encounter.
        before = enc and enc.before or false
    end

    enc = { last = now, before = before, newRow = false }
    encounters[guid] = enc
    return enc
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- `data` is plain: { level, hostile, source }. `where` is one ns.Where()
-- snapshot. Returns "new" or "updated", and the row.
function Sightings.Record(guid, data, where, now)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end
    now = now or ns.Now()

    local rows = ns.ListFor(ns.db.sightings, guid)

    local enc = Encounter(guid, rows, now)

    local function Extend(row)
        if now > Last(row) then row.last = now end
        if data.level then row.level = data.level end
        if data.hostile then row.hostile = true end
        return "updated", row
    end

    -- Rows are appended in time order, so the last hour is a suffix.
    for i = #rows, 1, -1 do
        local row = rows[i]
        if row.time <= now - BUCKET_SECONDS then break end

        if SamePlace(row, where) and row.me == ns.ownGUID then return Extend(row) end
    end

    -- #42: a zone line crossed together -- a zeppelin or boat full of
    -- people, or someone walking beside you -- is still the one meeting,
    -- not a second occasion. Seen within ENCOUNTER_GAP, they stay on the
    -- row it began on (inside its hour, as SIG-4), filed where it began.
    -- The rows, not the in-memory encounter, so a /reload mid-ride holds.
    if #rows > 0 then
        local latest = LatestRow(rows)
        if latest.me == ns.ownGUID and latest.time > now - BUCKET_SECONDS
            and now - Last(latest) <= ENCOUNTER_GAP then
            return Extend(latest)
        end
    end

    local row = {
        time = now,
        me = ns.ownGUID,  -- DAT-1: which of the user's characters saw them
        level = data.level,
        mapID = where.mapID,
        x = where.x,
        y = where.y,
        zone = not where.mapID and where.zone or nil,
        subZone = where.subZone,
        hostile = data.hostile or nil,
        src = data.source,
    }
    rows[#rows + 1] = row
    enc.newRow = true
    ns.TouchSeen()
    return "new", row
end

-- PRV-3, through Characters.Forget. nil forgets everyone, which is also
-- the settings page's "Delete all sightings".
--
-- The rolled-up summaries are sightings too (SIG-7): left on the character
-- records, "Seen N times" would outlive the rows it was counted from.
function Sightings.Forget(guid)
    if guid == nil then
        wipe(ns.db.sightings)
        wipe(encounters)
        for _, record in pairs(ns.db.characters) do record.sightingSummary = nil end
        return
    end
    ns.db.sightings[guid] = nil
    encounters[guid] = nil
    local record = ns.db.characters[guid]
    if record then record.sightingSummary = nil end
end
ns.RegisterStore("sightings", Sightings.Forget)

-- The settings page's "Delete all sightings": the rows and summaries, where
-- anyone outside the diary was last seen, and the records of everyone known
-- from sightings alone. Diary entries, sessions and interactions stay.
-- Returns how many records went.
function Sightings.DeleteAll()
    Sightings.Forget(nil)
    for guid, record in pairs(ns.db.characters) do
        if not ns.Diary.IsDiary(guid) then record.seen = nil end
    end
    return ns.Characters.Prune(math.huge)
end

--------------------------------------------------------------------------
-- Roll-up (SIG-7)
--------------------------------------------------------------------------

-- characters[guid].sightingSummary: first, last, count, levelMin, levelMax,
-- hostile (how many rows were), zones = { [mapID or zone name] = rows },
-- days (how many calendar days had a sighting; lastDay is the bookkeeping).
-- Rows must be folded oldest first for `days` to count right.
local function Fold(summary, row)
    local day = DayStart(row.time)
    if summary.lastDay ~= day then
        summary.days = (summary.days or 0) + 1
        summary.lastDay = day
    end

    local last = Last(row)
    summary.first = math.min(summary.first or row.time, row.time)
    summary.last = math.max(summary.last or last, last)
    summary.count = (summary.count or 0) + 1

    if row.level then
        summary.levelMin = math.min(summary.levelMin or row.level, row.level)
        summary.levelMax = math.max(summary.levelMax or row.level, row.level)
    end

    if row.hostile then summary.hostile = (summary.hostile or 0) + 1 end

    local key = row.mapID or row.zone
    if key then
        summary.zones = summary.zones or {}
        summary.zones[key] = (summary.zones[key] or 0) + 1
    end
end

-- Raw rows older than `days` (bufferDays by default) fold into the
-- character's summary and go. A character with no record left -- forgotten
-- -- has nothing to fold into, so their rows are simply dropped.
--
-- Returns rows rolled up and characters touched.
function Sightings.Rollup(now, days)
    local cutoff = ns.Cutoff(now, days)

    local rolled, touched = 0, 0
    for guid, rows in pairs(ns.db.sightings) do
        local first = 1
        while rows[first] and rows[first].time < cutoff do first = first + 1 end

        if first > 1 then
            local record = ns.db.characters[guid]
            if record then
                record.sightingSummary = record.sightingSummary or {}
                for i = 1, first - 1 do Fold(record.sightingSummary, rows[i]) end
            end

            local kept = {}
            for i = first, #rows do kept[#kept + 1] = rows[i] end
            ns.db.sightings[guid] = #kept > 0 and kept or nil

            rolled = rolled + first - 1
            touched = touched + 1
        end
    end

    return rolled, touched
end

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

function Sightings.For(guid)
    guid = ns.SafeGUID(guid)
    return guid and ns.db.sightings[guid] or {}
end

-- When and where they were last sighted, in the shape of a character
-- record's `seen` (Characters.Seen), or nil. The place is where the
-- zone-hour's row began, as everywhere rows are read; rows from before the
-- subzone was kept have none.
function Sightings.Latest(guid)
    local rows = Sightings.For(guid)
    if #rows == 0 then return nil end
    local row = LatestRow(rows)
    return {
        time = Last(row),
        zone = ns.RowZone(row),
        mapID = row.mapID,
        x = row.x,
        y = row.y,
        subZone = row.subZone,
    }
end

-- Rows and characters.
function Sightings.Count()
    local rows, characters = 0, 0
    for _, list in pairs(ns.db.sightings) do
        rows = rows + #list
        characters = characters + 1
    end
    return rows, characters
end

-- Everything seen since `since`, newest first, one entry per character: the
-- shape JNL-3's "recently nearby" and DIA-3's picker both want.
function Sightings.Since(since)
    local list = {}
    for guid, rows in pairs(ns.db.sightings) do
        local row = LatestRow(rows)
        if row and Last(row) >= since then
            list[#list + 1] = { guid = guid, row = row }
        end
    end

    table.sort(list, function(a, b) return Last(a.row) > Last(b.row) end)
    return list
end

-- The rolled-up summary with the raw rows folded on top, for one character.
-- A fresh table: the stored summary is not touched.
function Sightings.Summary(guid)
    local record = ns.Characters.Get(guid)
    local summary = {}

    local stored = record and record.sightingSummary
    if stored then
        for key, value in pairs(stored) do summary[key] = value end
        if stored.zones then
            summary.zones = {}
            for key, n in pairs(stored.zones) do summary.zones[key] = n end
        end
    end

    local rows = Sightings.For(guid)
    for i = 1, #rows do Fold(summary, rows[i]) end

    if not summary.count then return nil end
    return summary
end

-- REU-6: how often, and when last, *before* the encounter under way. Returns
-- count and time, or nil and why not (for /sd sightings tooltip).
--
-- The count is in occasions, which is what rows are: one per zone-hour. The
-- current encounter's own row, if it started one, is not an earlier occasion.
function Sightings.SeenBefore(guid, now)
    now = now or ns.Now()
    local summary = Sightings.Summary(guid)
    if not summary then return nil, "never sighted" end

    local enc = encounters[ns.SafeGUID(guid) or ""]
    if not enc or now - enc.last > ENCOUNTER_GAP then
        return summary.count, summary.last
    end

    if enc.before == nil then return nil, "this is the first encounter" end
    if enc.before == false then
        -- Under way since before a /reload: the best there is.
        return summary.count, summary.last
    end

    return math.max(1, summary.count - (enc.newRow and 1 or 0)), enc.before
end

function Sightings.EncounterState(guid, now)
    local enc = encounters[ns.SafeGUID(guid) or ""]
    if not enc then return nil end
    return enc, (now or ns.Now()) - enc.last <= ENCOUNTER_GAP
end

--------------------------------------------------------------------------
-- By day (JNL-3)
--------------------------------------------------------------------------

-- Rows run in time order, so consecutive rows mostly share a day: the last
-- day's bounds are kept and date() only runs when a row leaves them.
local function DayFinder()
    local from, to
    return function(t)
        if not from or t < from or t >= to then
            from = DayStart(t)
            to = from + DAY
        end
        return from
    end
end

-- Every day with raw sightings, newest first: { start, count }, where count
-- is people, not rows. A row that runs past midnight counts on both days.
function Sightings.Days()
    local people = {}
    local DayOf = DayFinder()

    for _, rows in pairs(ns.db.sightings) do
        local on = {}
        for i = 1, #rows do
            on[DayOf(rows[i].time)] = true
            on[DayOf(Last(rows[i]))] = true
        end
        for day in pairs(on) do people[day] = (people[day] or 0) + 1 end
    end

    local list = {}
    for start, count in pairs(people) do list[#list + 1] = { start = start, count = count } end
    table.sort(list, function(a, b) return a.start > b.start end)
    return list
end

-- One entry per person seen during the day starting at `dayStart`:
-- { guid, row (their latest row that day), last (clipped to the day),
-- hostile (attackable at any point that day) }. Unsorted.
function Sightings.OnDay(dayStart)
    local dayEnd = dayStart + DAY
    local list = {}

    for guid, rows in pairs(ns.db.sightings) do
        local best, hostile
        for i = 1, #rows do
            local row = rows[i]
            if row.time >= dayEnd then break end
            if Last(row) >= dayStart then
                if not best or Last(row) > Last(best) then best = row end
                if row.hostile then hostile = true end
            end
        end
        if best then
            list[#list + 1] = {
                guid = guid,
                row = best,
                last = math.min(Last(best), dayEnd - 1),
                hostile = hostile or false,
            }
        end
    end

    return list
end

--------------------------------------------------------------------------
-- A day's people, for the Recently nearby page (JNL-3)
--------------------------------------------------------------------------

-- Interactions that mark a row (their kind's `dealt`, Core/Rows.lua), and
-- which mark wins when there are several.
local DEALT_RANK = { together = 3, trade = 2, talk = 1 }

local function ZoneName(row)
    return ns.RowZone(row) or "?"
end

-- The strongest thing done with them between `from` and `to`, and when.
local function Dealt(guid, from, to)
    local kind, at
    local rows = ns.Interactions.For(guid) or {}
    for i = 1, #rows do
        local row = rows[i]
        local k = row.time >= from and row.time < to and ns.Rows.Get(row.type).dealt
        if k and (not kind or DEALT_RANK[k] > DEALT_RANK[kind]) then kind, at = k, row.time end
    end
    return kind, at
end

-- Everyone seen on the day starting at `dayStart`, but the user's own
-- characters: { guid, record, row, name, zone, subZone (nil when it is the
-- zone's own name), level, last, hostile, days, first, firstLevel, dealt
-- ("together", "trade", "talk" or nil), dealtAt, haystack }. Unsorted;
-- QueryDay filters and sorts.
function Sightings.DayEntries(dayStart)
    local list = {}
    for _, seen in ipairs(Sightings.OnDay(dayStart)) do
        local record = ns.Characters.Get(seen.guid)
        if record and not record.isSelf then
            local summary = Sightings.Summary(seen.guid)
            local kind, at = Dealt(seen.guid, dayStart, dayStart + DAY)
            local name = ns.Characters.FullName(seen.guid) or "?"
            local zone = ZoneName(seen.row)
            -- The subzone only when it says more than the zone does.
            local subZone = seen.row.subZone ~= zone and seen.row.subZone or nil
            list[#list + 1] = {
                guid = seen.guid,
                record = record,
                row = seen.row,
                name = name,
                zone = zone,
                subZone = subZone,
                level = seen.row.level or record.level,
                last = seen.last,
                hostile = seen.hostile,
                days = summary and (summary.days or summary.count) or 1,
                first = summary and summary.first,
                firstLevel = summary and summary.levelMin,
                dealt = kind,
                dealtAt = at,
                haystack = (name .. " " .. zone .. " " .. (subZone or "")):lower(),
            }
        end
    end
    return list
end

local KEEP = {
    everyone = function() return true end,
    dealt = function(e) return e.dealt ~= nil end,
    before = function(e) return e.days > 1 end,
    hostile = function(e) return e.hostile end,
}

local SORT_KEY = {
    name = function(e) return e.name:lower() end,
    -- By zone, then subzone: a row with none comes first in its zone.
    zone = function(e) return (e.zone .. "\0" .. (e.subZone or "")):lower() end,
    -- By subzone, then zone; nil, so last, for a row with none.
    subzone = function(e) return e.subZone and (e.subZone .. "\0" .. e.zone):lower() end,
    level = function(e) return e.level or 0 end,
    last = function(e) return e.last end,
}

-- DayEntries' list, searched, filtered and sorted. `q` is { search, filter
-- ("everyone", "dealt", "before", "hostile"), sort ("name", "zone",
-- "subzone", "level", "last"), dir (1 ascending, -1 descending) }. Rows with
-- nothing to sort by go last either way round; ties go to the latest seen.
function Sightings.QueryDay(entries, q)
    local search = q.search:lower()
    local keep = KEEP[q.filter] or KEEP.everyone
    local list = {}
    for i = 1, #entries do
        local e = entries[i]
        if keep(e) and (search == "" or e.haystack:find(search, 1, true)) then list[#list + 1] = e end
    end

    local key, dir = SORT_KEY[q.sort] or SORT_KEY.last, q.dir
    table.sort(list, function(a, b)
        local x, y = key(a), key(b)
        if x ~= y then
            if x == nil or y == nil then return y == nil end
            if dir > 0 then return x < y end
            return x > y
        end
        if a.last ~= b.last then return a.last > b.last end
        return a.guid < b.guid
    end)
    return list
end
