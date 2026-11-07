-- "Remember this" candidates (DIA-3).
--
-- The picker's job is to answer "who did I just mean?" without the user having
-- to still be targeting them. It gathers everyone the client can still name
-- right now, in the order they are likely to be the answer.
--
-- DIA-3 says this has to work in combat. It does: Session 1 verified that
-- every identity read here stayed plain under both [Combat=2,InCombatLockdown]
-- and [Chat=2,ChatLockdown]. Nothing in this file compares or keys on a value
-- that could be secret without going through ns.SafeGUID first.
--
-- Sightings (M2) are the one source not gathered yet. The seam is the source
-- list below: SIG-* adds a gatherer there and nothing else changes.

local addonName, ns = ...

local L = ns.L

-- How far back the buffer is worth offering as "someone I just dealt with".
local RECENT_WINDOW = 60 * 60
local MAX_CANDIDATES = 20

-- Why each entry is on the list, shown next to the name so the user can tell
-- two strangers apart.
local function Gatherer(list, seen)
    return function(guid, why, unit)
        guid = ns.SafeGUID(guid)
        if not guid or seen[guid] then return end
        if guid == ns.ownGUID then return end

        -- A unit token is worth observing on the way past: it is the richest
        -- identity source, and the picker is often the last moment the client
        -- can still see them.
        local record
        if unit then
            record = ns.Characters.ObserveUnit(unit)
        end
        record = record or ns.Characters.Get(guid) or ns.Characters.ObserveGUID(guid)
        if not record then return end

        seen[guid] = true
        list[#list + 1] = {
            guid = guid,
            unit = unit,
            why = why,
            name = ns.Characters.FullName(guid) or guid,
            level = record.level,
            class = record.class,
            inDiary = ns.Diary.IsDiary(guid),
        }
    end
end

local function GatherUnits(add)
    add(UnitGUID("target"), L["your target"], "target")
    add(UnitGUID("mouseover"), L["under your cursor"], "mouseover")
    add(UnitGUID("focus"), L["your focus"], "focus")
end

local function GatherGroup(add)
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            local unit = "raid" .. i
            add(UnitGUID(unit), L["in your raid"], unit)
        end
        return
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            add(UnitGUID(unit), L["in your group"], unit)
        end
    end
end

-- Who the user most recently did something with, by kind. DIA-3's "Remember
-- this" picker is built out of this: "last whisperer", "last trade partner",
-- "last resurrector". Deliberately volatile -- it is a shortcut for the
-- current play session, and the buffer already holds the durable answer.
-- Capture sets it (ns.Recent.Set), under one of RECENT_KINDS below.
local recentByKind = {}
ns.Recent = {}

function ns.Recent.Set(kind, guid)
    guid = ns.SafeGUID(guid)
    if not guid then return end
    recentByKind[kind] = { guid = guid, time = ns.Now() }
end

function ns.Recent.Get(kind)
    local entry = recentByKind[kind]
    if not entry then return nil end
    return entry.guid, entry.time
end

-- PRV-3: deleting a character must not leave them one keybind away.
function ns.Recent.Forget(guid)
    for kind, entry in pairs(recentByKind) do
        if guid == nil or entry.guid == guid then recentByKind[kind] = nil end
    end
end
ns.RegisterStore("recent", ns.Recent.Forget)

-- DIA-3 names these explicitly: last whisperer, last trade partner, last
-- resurrector or summoner. ns.Recent holds them for the session.
local RECENT_KINDS = {
    { "trade", L["you traded with them"] },
    { "whisper", L["they whispered you"] },
    { "resurrect", L["they resurrected you"] },
    { "summon", L["they summoned you"] },
}

local function GatherRecent(add)
    for i = 1, #RECENT_KINDS do
        local guid = ns.Recent.Get(RECENT_KINDS[i][1])
        if guid then add(guid, RECENT_KINDS[i][2]) end
    end
end

-- Anyone else the buffer saw in the last hour, most recent first. This is what
-- makes "trade first, decide later" reach past the current session's Recent
-- entries.
-- Said in words where the row type would not be (its kind's `reason`,
-- Core/Rows.lua): a fight, for flow 5's ganker; a witness
-- to one of the user's; whatever a feature's own kind says
-- (Features/<Name>/).

local function GatherBuffer(add, now)
    local recent = ns.Interactions.Since(now - RECENT_WINDOW)
    for i = 1, #recent do
        add(recent[i].guid, ns.Rows.Get(recent[i].type).reason or ns.Fmt(L["recent %s"], recent[i].type))
    end
end

-- Ordered, deduplicated, capped.
function ns.Candidates()
    local list, seen = {}, {}
    local add = Gatherer(list, seen)
    local now = ns.Now()

    GatherUnits(add)
    GatherGroup(add)
    GatherRecent(add)
    GatherBuffer(add, now)

    while #list > MAX_CANDIDATES do
        table.remove(list)
    end

    return list
end
