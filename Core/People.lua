-- The journal's query layer (JNL-1, JNL-2).
--
-- Everything the People list sorts and filters on -- times met, last met,
-- time together, zones -- is derived, not stored: it already lives in the
-- sessions and the interaction rows, and a second copy would drift. Deriving
-- it per entry would scan every session once per person, though, which is
-- 10 million steps at JNL-6's scale (1,000 entries, 10,000 sessions). So the
-- index is built in one pass over sessions and one over each entry's rows,
-- and kept until the data moves on. Typing in the search box reuses it.
--
-- Every write that feeds it (Diary edits, Sessions.New/Together/Forget, a
-- diary entry's Interactions.Add, a diary entry's rename in
-- Characters.Observe, Characters.Forget, WipeData) moves ns.dataVersion
-- (ns.Touch). The index remembers the version it was built at and rebuilds
-- on the first read after it changed, so a session tick costs nothing unless
-- someone is looking, and opening the journal twice builds it once.
--
-- No frames here, so the smoke test can hold all of it to account.

local addonName, ns = ...

local L = ns.L

local People = {}
ns.People = People

local DAY = ns.DAY

-- Rows that mean the two of you were in one place (their kind's `meeting`,
-- Core/Rows.lua). A whisper is contact, not a meeting; /say lines come in
-- bursts and would inflate the count. Rows stamped with a session are
-- already counted by the session.
local Rows = ns.Rows

People.SORTS = {
    { key = "lastMet", label = L["Last met"] },
    { key = "timesMet", label = L["Times met"] },
    { key = "together", label = L["Time together"] },
    { key = "lastSeen", label = L["Last seen"] },
    { key = "name", label = L["Name"] },
}

People.WITHIN = {
    { days = 7, label = L["Last 7 days"] },
    { days = 30, label = L["Last 30 days"] },
    { days = 90, label = L["Last 90 days"] },
    { days = 365, label = L["Last year"] },
}

--------------------------------------------------------------------------
-- The index
--------------------------------------------------------------------------

local index

-- One person's stats, for the surfaces that only ever ask about one: the
-- tooltip (REU-4) and the reunion toast (REU-1). A session tick moves the
-- data version every 30 seconds while a session is open, and rebuilding the
-- whole index on the next mouseover would be a visible hitch at JNL-6's scale.
local single = {}

-- What both caches were built from: the data version, and the stores
-- themselves, so a replaced table (a test's blank diary, a future import)
-- is never read through a stale cache either.
local builtFrom = {}

local STORES = { "diary", "sessions", "interactions", "characters" }

local function Fresh()
    if builtFrom.version ~= ns.dataVersion then return false end
    for i = 1, #STORES do
        if builtFrom[STORES[i]] ~= ns.db[STORES[i]] then return false end
    end
    return true
end

-- Drops both caches when the data moved on since they were built.
local function Current()
    if Fresh() then return end
    index, single = nil, {}
    builtFrom.version = ns.dataVersion
    for i = 1, #STORES do builtFrom[STORES[i]] = ns.db[STORES[i]] end
end

-- How many times the full index was built, for the smoke tests: opening
-- the journal again after no write must not rebuild it.
local builds = 0
function ns._test.PeopleBuilds()
    return builds
end

-- `zone` is where the meeting ended, for "where you last met" (REU-1);
-- `firstZone` where it began, for "where you first met" (the profile).
local function Meet(s, from, to, level, zone, firstZone)
    s.timesMet = s.timesMet + 1
    if not s.firstMet or from < s.firstMet then s.firstMet, s.firstZone = from, firstZone or zone end
    if not s.lastMet or to > s.lastMet then s.lastMet, s.lastZone = to, zone end

    -- "Level then" is their level at the earliest meeting that knew it.
    if level and (not s.levelAt or from < s.levelAt) then
        s.levelThen, s.levelAt = level, from
    end
end

local function AddZone(s, zone)
    if zone and not s.zones[zone] then
        s.zones[zone] = true
        s.zoneList[#s.zoneList + 1] = zone
    end
end

-- Everything search matches against, lowercased once: every name on record
-- (DIA-9 keeps the old ones findable), tags, relationship, note.
local function Haystack(record, entry)
    local parts = {}
    if record then
        for i = 1, #record.names do
            parts[#parts + 1] = ns.JoinName(record.names[i].first, record.names[i].surname)
        end
    end
    for i = 1, #entry.tags do parts[#parts + 1] = entry.tags[i] end
    parts[#parts + 1] = entry.relationship
    parts[#parts + 1] = entry.note
    return table.concat(parts, "\n"):lower()
end

local function NewStats(guid, entry)
    local record = ns.Characters.Get(guid)
    local name = ns.Characters.FullName(guid) or guid
    return {
        guid = guid,
        entry = entry,
        -- Read live, not copied: "last seen" moves on every mouseover, and
        -- invalidating the index that often would rebuild it on every keystroke.
        record = record,
        name = name,
        sortName = name:lower(),
        faction = record and record.faction,
        levelNow = record and record.level,
        timesMet = 0,
        seconds = 0,
        zones = {},
        zoneList = {},
        haystack = Haystack(record, entry),
    }
end

-- Their own zones, the user's while they were near (Sessions' `near`);
-- the session's for a participant from before those were kept.
local function AddSession(s, session, p)
    local zones = p.zones or session.zones
    Meet(s, p.since, p.last, p.levelStart, zones[#zones], zones[1])
    s.seconds = s.seconds + p.seconds
    for i = 1, #zones do AddZone(s, zones[i]) end
end

-- The rows not already counted by a session, and the fallback level.
local function Finish(s)
    local rows = ns.Interactions.For(s.guid)
    if rows then
        for i = 1, #rows do
            local row = rows[i]
            if not row.session and Rows.Get(row.type).meeting then
                Meet(s, row.time, row.time, row.theirLevel, row.zone)
                AddZone(s, row.zone)
            end
        end
    end

    if not s.levelThen then
        s.levelThen = s.entry.addedContext and s.entry.addedContext.theirLevel
    end
    return s
end

local function Build()
    builds = builds + 1
    local stats = {}

    for guid, entry in ns.Diary.Each() do
        stats[guid] = NewStats(guid, entry)
    end

    for _, session in pairs(ns.db.sessions) do
        for guid, p in pairs(session.participants) do
            local s = stats[guid]
            if s then AddSession(s, session, p) end
        end
    end

    for _, s in pairs(stats) do Finish(s) end
    return stats
end

local function BuildOne(guid)
    local entry = ns.Diary.Get(guid)
    if not entry then return false end

    local s = NewStats(guid, entry)
    local sessions = ns.Sessions.For(guid)
    for i = 1, #sessions do
        AddSession(s, sessions[i], sessions[i].participants[guid])
    end
    return Finish(s)
end

function People.Index()
    Current()
    index = index or Build()
    return index
end

-- Reads the full index when the journal already built it, and otherwise
-- works out just this one person.
function People.Stats(guid)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end
    Current()
    if index then return index[guid] end

    if single[guid] == nil then single[guid] = BuildOne(guid) end
    return single[guid] or nil
end

--------------------------------------------------------------------------
-- Querying (JNL-1)
--------------------------------------------------------------------------

-- What the filter menus can offer, from the data rather than from a list
-- that could name a tag nobody has.
function People.Facets()
    local seen = { tags = {}, relationships = {}, factions = {}, zones = {} }
    local facets = { tags = {}, relationships = {}, factions = {}, zones = {} }

    local function Add(kind, value)
        if value and not seen[kind][value] then
            seen[kind][value] = true
            facets[kind][#facets[kind] + 1] = value
        end
    end

    for _, s in pairs(People.Index()) do
        for i = 1, #s.entry.tags do Add("tags", s.entry.tags[i]) end
        Add("relationships", s.entry.relationship)
        Add("factions", s.faction)
        for i = 1, #s.zoneList do Add("zones", s.zoneList[i]) end
    end

    for _, list in pairs(facets) do table.sort(list) end
    return facets
end

local function HasTag(entry, tag)
    for i = 1, #entry.tags do
        if entry.tags[i] == tag then return true end
    end
    return false
end

local function Matches(s, q, now)
    if q.search and q.search ~= "" and not s.haystack:find(q.search:lower(), 1, true) then
        return false
    end
    if q.tag and not HasTag(s.entry, q.tag) then return false end
    if q.relationship and s.entry.relationship ~= q.relationship then return false end
    if q.faction and s.faction ~= q.faction then return false end
    if q.zone and not s.zones[q.zone] then return false end
    if q.withinDays and not (s.lastMet and s.lastMet >= now - q.withinDays * DAY) then
        return false
    end
    return true
end

-- Never-met entries sort after everyone who has a value, whichever the key.
local COMPARE = {
    lastMet = function(a, b) return (a.lastMet or -1), (b.lastMet or -1) end,
    timesMet = function(a, b) return a.timesMet, b.timesMet end,
    together = function(a, b) return a.seconds, b.seconds end,
    lastSeen = function(a, b) return People.SeenAt(a) or -1, People.SeenAt(b) or -1 end,
}

function People.SeenAt(s)
    local seen = s.record and s.record.seen
    return seen and seen.time
end

-- `q` may carry search, tag, relationship, faction, zone, withinDays, sort.
function People.Query(q)
    q = q or {}
    local now = ns.Now()
    local list = {}

    for _, s in pairs(People.Index()) do
        if Matches(s, q, now) then list[#list + 1] = s end
    end

    local key = COMPARE[q.sort or "lastMet"]
    table.sort(list, function(a, b)
        if key then
            local x, y = key(a, b)
            if x ~= y then return x > y end
        end
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        return a.guid < b.guid
    end)

    return list
end

-- How many are pencilled in: everyone in the buffer or seen recently,
-- outside the diary. The empty People page (UI/Journal/Empty.lua) and the
-- parcel's note (UI/Windows/Intro/Torn.lua) say it.
function People.PencilledCount()
    local seen, n = {}, 0
    for _, store in ipairs({ ns.db.interactions, ns.db.sightings }) do
        for guid in pairs(store) do
            if not seen[guid] and guid ~= ns.ownGUID and not ns.Diary.IsDiary(guid) then
                seen[guid] = true
                n = n + 1
            end
        end
    end
    return n
end
