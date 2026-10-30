-- The character store (prd.md section 7, DIA-5, DIA-9).
--
-- One record per player the addon has ever observed, keyed by GUID. The
-- diary, the interaction buffer and together sessions all point at these
-- records by GUID instead of copying identity around, so a rename is recorded
-- in one place and every surface that shows the name follows.
--
-- Nothing here promotes anyone into the diary: DIA-1 says that only ever
-- happens because the user asked.

local addonName, ns = ...

local Characters = {}
ns.Characters = Characters

-- Fields that a capture may fill in but must never blank. A source that could
-- not read a field (a chat line has no level, a tooltip has no guild) must not
-- erase what a better source already knew.
local FILLABLE = {
    "faction", "level", "class", "classID", "race", "raceID", "sex", "guild",
}

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

function Characters.Get(guid)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end
    return ns.db.characters[guid]
end

-- D12: names are stored as parts and joined here.
function Characters.Name(guid)
    local record = Characters.Get(guid)
    if not record then return nil end

    local latest = record.names[#record.names]
    if not latest then return nil end

    return latest.first, latest.surname
end

function Characters.FullName(guid)
    return ns.JoinName(Characters.Name(guid))
end

-- Name lookup, for the surfaces that have nothing better: a chat-name menu
-- whose GUID could not be resolved (DIA-2a), and `/sd add <name>`.
--
-- A name is not a key -- two characters can share a first name -- so an
-- ambiguous match returns nil and the number of hits, and the caller says so
-- rather than guessing. Putting the wrong stranger in the diary under
-- somebody else's name is worse than failing to add anyone.
function Characters.FindByName(name, surname)
    local first, last = ns.NormalizeName(name, surname)
    if not first then return nil, 0 end

    first = first:lower()
    if last then last = last:lower() end

    local match, hits = nil, 0
    for guid in pairs(ns.db.characters) do
        local f, s = Characters.Name(guid)
        if f and f:lower() == first and (last == nil or (s and s:lower() == last)) then
            hits = hits + 1
            match = guid
        end
    end

    if hits ~= 1 then return nil, hits end
    return match, 1
end

function Characters.Count()
    return ns.CountKeys(ns.db.characters)
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- DIA-9: renames, including surname changes, are history rather than an
-- overwrite. The newest name is the last element.
--
-- Session 2 confirmed that every player in this build has a surname, so a
-- name arriving without one is always an incomplete read rather than a real
-- name -- GetPlayerInfoByGUID yields the first name only, and it is the only
-- identity source available when there is no unit token (DIA-2a). Those reads
-- must not be mistaken for renames in either direction: a first-name-only
-- read neither appends an entry nor erases the surname already on record, and
-- the first full read fills in the placeholder it left behind.
--
-- Returns true when the names changed (a rename, or a surname filled in),
-- which the People index has to hear about: it searches every name.
local function RecordName(record, first, surname, now)
    if not first then return false end

    local names = record.names
    local latest = names[#names]

    -- Safe to compare: both sides came through ns.Plain in Observe.
    if latest and latest.first == first then
        if surname == nil or latest.surname == surname then
            latest.lastSeen = now
            return false
        end

        if latest.surname == nil then
            latest.surname = surname
            latest.lastSeen = now
            return true
        end
    end

    names[#names + 1] = {
        first = first,
        surname = surname,
        firstSeen = now,
        lastSeen = now,
    }
    return true
end

-- What the People index copies out of a record (Core/People.lua's NewStats),
-- besides the names. Anything else on the record it reads live.
local INDEXED = { faction = true, level = true }

-- Every capture path funnels in here, and this is where values become table
-- keys and stored fields, both of which kill a secret (NFR-4, INT-5). So the
-- store scrubs: the GUID through SafeGUID, the name and every other field
-- through ns.Plain. A secret field is dropped and the rest is kept.
function Characters.Observe(guid, info)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end

    info = info or {}
    local now = info.time or ns.Now()

    local record = ns.db.characters[guid]
    local changed = record == nil
    if not record then
        record = { guid = guid, names = {}, firstSeen = now }
        ns.db.characters[guid] = record
    end
    record.lastSeen = now

    -- The user's own alts can land in this table too when they show up in a
    -- roster (DAT-1 keeps the list of them account-wide). Marking them once keeps every later
    -- surface from having to know the difference.
    if ns.OwnCharacters()[guid] then
        record.isSelf = true
    end

    if RecordName(record, ns.Plain(info.first), ns.Plain(info.surname), now) then changed = true end

    local levelBefore = record.level

    for i = 1, #FILLABLE do
        local key = FILLABLE[i]
        local value = ns.Plain(info[key])
        if value ~= nil then
            if INDEXED[key] and record[key] ~= value then changed = true end
            record[key] = value
        end
    end

    -- Every mouseover lands here, so the data version moves only when a
    -- diary entry's indexed fields did: anything more would throw the
    -- journal's index away on every nameplate.
    if changed and ns.Diary.IsDiary(guid) then ns.Touch() end

    -- Seen at a higher level than last time: told as SD_LEVEL_ROSE (Core/
    -- Events.lua's header), with the record already updated, for whatever
    -- keeps a row of it. Noticed now, which while grouped is the moment it
    -- happens (UNIT_LEVEL); otherwise the next time they are seen. Only
    -- live readings: a backfilled one describes the past, so it is no news
    -- now. A first reading has nothing to rise from.
    local level = record.level
    if info.time == nil and type(levelBefore) == "number" and type(level) == "number"
        and level > levelBefore then
        ns.Fire("SD_LEVEL_ROSE", guid, levelBefore, level)
    end

    return record
end

-- "Last seen at ... in ...": the last time they were physically near the user.
--
-- Not the same as record.lastSeen, which moves on any observation at all (a
-- whisper from across the world included). This one only moves on proximity:
-- a visible unit token, a trade, /say or /yell. The place is the *user's*
-- position at that moment, as with every other location the addon stores --
-- the API does not give anyone else's, and the diary would not keep it.
--
-- Mouseover and nameplates fire in bursts, so within SEEN_THROTTLE of the
-- last read (`read`; an older `seen` has only its time) only the time moves;
-- the location is read again once the throttle has passed, however steady
-- the burst. A place handed in (`where`) is kept at once, but counts on the
-- map only past the throttle too.
local SEEN_THROTTLE = 15

function Characters.Seen(guid, where)
    local record = Characters.Get(guid)
    if not record then return nil end

    local now = ns.Now()
    local seen = record.seen
    local read = seen and (seen.read or seen.time)
    local throttled = read and now - read < SEEN_THROTTLE
    if throttled and not where then
        seen.time = now
        return seen
    end

    where = where or ns.Where()
    record.seen = {
        time = now,
        read = throttled and read or now,
        zone = where.zone,
        subZone = where.subZone,
        mapID = where.mapID,
        x = where.x,
        y = where.y,
    }

    -- The journal's map (ns.Heat) keeps where, for diary entries only.
    if not throttled and ns.Diary.IsDiary(guid) then ns.Heat.Add(record, where) end

    return record.seen
end

-- `seen` from the sighting rows, when they are newer. Seen above only keeps
-- it for diary entries, so someone sighted before they were added -- off the
-- Recently nearby page, say -- has rows but no `seen`. Not into the map:
-- Heat.Backfill counts those rows.
function Characters.SeenFromSightings(guid)
    local record = Characters.Get(guid)
    local latest = record and ns.Sightings.Latest(guid)
    if not latest then return record and record.seen end
    if record.seen and record.seen.time >= latest.time then return record.seen end

    record.seen = latest
    return latest
end

--------------------------------------------------------------------------
-- Retention
--------------------------------------------------------------------------

-- INT-2 / D3 for the records themselves: "forget people outside the diary
-- after N days". A record goes once nothing else holds on to it -- no
-- interaction or raw sighting left (their own prunes run first) and not
-- observed since `cutoff` -- taking its sighting summary and last-seen place
-- with it. Diary entries and the user's own characters are never pruned.
--
-- Only the record goes. What other stores copied out of it stays: an
-- instance visit keeps its members' names, a death its killer's.
--
-- `cutoff` defaults to the buffer window; math.huge drops everyone outside
-- the diary with nothing left. Returns how many records went.
function Characters.Prune(cutoff)
    cutoff = cutoff or ns.Cutoff()
    local own = ns.OwnCharacters()
    local dropped = 0

    for guid, record in pairs(ns.db.characters) do
        if not record.isSelf and not own[guid] and guid ~= ns.ownGUID
            and not ns.Diary.IsDiary(guid)
            and ns.db.interactions[guid] == nil and ns.db.sightings[guid] == nil
            and (record.lastSeen or record.firstSeen or 0) < cutoff then
            ns.db.characters[guid] = nil
            dropped = dropped + 1
        end
    end
    ns.Sessions.PruneLeftovers()

    if dropped > 0 then ns.Debug("forgot %d character(s) outside the diary", dropped) end
    return dropped
end

-- The records themselves, as one of the stores Forget walks.
ns.RegisterStore("characters", function(guid)
    if guid == nil then wipe(ns.db.characters) else ns.db.characters[guid] = nil end
end)

-- PRV-3: delete one character outright, from every store registered with
-- ns.RegisterStore -- record, diary entry, buffer, sightings, sessions, and
-- what capture and the toasts still hold in memory. The diary's own "delete
-- everything" (DIA-7) lands here too, so both paths forget the same things.
function Characters.Forget(guid)
    guid = ns.SafeGUID(guid)
    if not guid then return false end

    local known = ns.db.characters[guid] ~= nil or ns.db.diary[guid] ~= nil
        or ns.db.interactions[guid] ~= nil or ns.db.sightings[guid] ~= nil

    ns.ForgetEverywhere(guid)
    ns.Touch()

    return known
end

-- Reads everything readable off a unit token in one pass.
--
-- T-B1b verified that GUID, name, class, race, level, faction and sex are all
-- plain for open-world strangers, and stayed plain under combat and chat
-- lockdown -- but every read still goes through ns.Plain. An API that is
-- plain today can be guarded by a patch, and the failure mode of skipping the
-- check is a hard error on the first comparison (NFR-4).
function Characters.ObserveUnit(unit, extra)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end

    local guid = ns.SafeGUID(UnitGUID(unit))
    if not guid then return nil end

    local first, surname = ns.NameFromUnit(unit)

    local _, class, classID = UnitClass(unit)
    local _, race, raceID = UnitRace(unit)
    local faction = UnitFactionGroup(unit)
    local level = ns.Plain(UnitLevel(unit))

    -- -1 is "level too high to read", not a level.
    if type(level) ~= "number" or level <= 0 then level = nil end

    local info = {
        first = first,
        surname = surname,
        class = class,
        classID = classID,
        race = race,
        raceID = raceID,
        sex = UnitSex(unit),
        faction = faction,
        level = level,
    }

    if extra then
        for key, value in pairs(extra) do info[key] = value end
    end

    return Characters.Observe(guid, info)
end

-- The no-unit-token path: a chat name, a menu entry, a stored GUID (DIA-2a).
-- Identity from the GUID is thinner -- first name, class, race, sex, no level
-- -- so it only ever fills blanks.
function Characters.ObserveGUID(guid, extra)
    local info = ns.InfoFromGUID(guid)
    if not info then return nil end

    if extra then
        for key, value in pairs(extra) do info[key] = value end
    end

    return Characters.Observe(info.guid, info)
end
