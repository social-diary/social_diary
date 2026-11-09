-- The tour's example person: Thex Theximus, a Troll Hunter, written into the
-- diary while the tour shows the People page, and taken out again when it
-- ends. He must never stay in a player's saved data, so everything written
-- here carries a `sample` mark, Remove takes all of it out, and a login finds
-- and removes him should a /reload, a crash or a logout have come mid-tour
-- (Core/Events.lua, ADDON_LOADED).
--
-- Modelled on Dev/TestData.lua, much smaller, and shipped: it writes through
-- the same core stores capture writes through (Characters, Diary, Sessions,
-- Interactions), and nothing from Dev/ or a feature's Dev.lua. The GUID is on
-- realm 0000, like the test data's, and none of theirs.
--
-- What he has, timed relative to now: the entry (added just now, no note, as
-- the tour's "+ Add" writes none), and a short history today: 35 minutes of
-- questing together in Durotar, with a trade inside it (he gave 5x [Linen
-- Cloth]) and a rare killed together, then a whisper from him after.
--
-- Nothing a player would notice: no line in chat (Diary.Add's `quiet`), no
-- reunion toast (those come only from a unit seen or grouped, Core/Roster.lua
-- and Capture/Nearby.lua, and he is never either), no sound, no heat or
-- "last seen" (no unit, no sighting rows, every row written after the fact).

local addonName, ns = ...

local L = ns.L

local Sample = {}
ns.Sample = Sample

local GUID = "Player-0000-7E5A3E01"
Sample.GUID = GUID
Sample.NAME = "Thex Theximus"

-- Where his history lies: a troll's starting zone. The entry's own place is
-- where the player stands, this only where they cannot be read.
local ZONE = "Durotar"
Sample.ZONE = ZONE

local MIN = 60

local LINEN = "|cnIQ1:|Hitem:2589::::::::::::|h[" .. L["Linen Cloth"] .. "]|h|r"

function Sample.Present()
    local db = ns.db
    return db ~= nil and (db.characters[GUID] ~= nil or db.diary[GUID] ~= nil
        or db.interactions[GUID] ~= nil or db.around[GUID] ~= nil)
end

-- Everything Write wrote, gone; whether he was there. The session counter
-- Write moved goes back too, unless another session has been opened since.
function Sample.Remove()
    local db = ns.db
    if not db or not Sample.Present() then return false end

    local record = db.characters[GUID]
    local mark = record and type(record.sample) == "table" and record.sample
    local restore = mark and mark.session and db.meta.nextSessionId == mark.session + 1

    -- Every sample session has him as its only participant, so forgetting
    -- him drops them; any left over (one somebody else joined) go by mark.
    ns.Characters.Forget(GUID)
    for id, session in pairs(db.sessions) do
        if session.sample then
            db.sessions[id] = nil
            if db.meta.openSession == id then db.meta.openSession = nil end
        end
    end
    if restore and db.sessions[mark.session] == nil then db.meta.nextSessionId = mark.session end
    ns.Touch()
    return true
end

-- When his history starts: 80 minutes ago, but kept to today where today
-- has room for it (40 minutes: the session and the whisper after).
local function Start(now)
    local day, start = ns.DayStart(now), now - 80 * MIN
    if start < day and now - day >= 40 * MIN then start = day end
    return start
end

local function Row(kind, time, data, session)
    data.time = time
    data.where = { zone = ZONE }
    data.session = session and session.id or false
    data.theirLevel = 12
    local row = ns.Interactions.Add(GUID, kind, data)
    if row then row.sample = true end
    return row
end

-- Writes him afresh (an earlier copy goes first) and returns his entry, or
-- nil when the diary is not loaded.
function Sample.Write(now)
    if not ns.db then return nil end
    Sample.Remove()
    now = now or ns.Now()
    local start = Start(now)

    local record = ns.Characters.Observe(GUID, {
        first = "Thex", surname = "Theximus", class = "HUNTER", race = "Troll",
        faction = "Horde", level = 12, sex = 2, time = start,
    })
    if not record then return nil end

    local entry = ns.Diary.Add(GUID, { source = "sample", quiet = true })
    if not entry then
        ns.Characters.Forget(GUID)
        return nil
    end
    entry.sample = true
    entry.addedAt = now
    if not entry.addedContext.zone or entry.addedContext.zone == "" then entry.addedContext.zone = ZONE end

    -- Questing together, closed, so it never becomes the open session.
    local seconds = 35 * MIN
    local nextId = ns.db.meta.nextSessionId or 1
    local session = ns.Sessions.New({
        source = "group", sample = true, startedAt = start, endedAt = start + seconds,
        zones = { ZONE },
        participants = { [GUID] = {
            since = start, last = start + seconds, seconds = seconds,
            levelStart = 12, levelEnd = 12,
            quests = { 786, 791, 794 },
            rares = { { name = "Death Flayer", npcID = 5823, kind = "rare", time = start + 22 * MIN } },
        } },
    })
    record.sample = { session = nextId }

    Row("trade", start + 12 * MIN, { context = { received = { { link = LINEN, count = 5 } } } }, session)
    Row("whisper_in", start + seconds + 3 * MIN, { excerpt = L["thanks for the help"] })

    -- The entry's fields above were written by hand, past Diary's setters.
    ns.Touch()
    return entry
end
