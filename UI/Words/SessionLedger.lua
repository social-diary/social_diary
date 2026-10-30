-- What the diary has already told about a person (experimental, planner
-- stage 4): the told-ledger, kept in memory only.
--
-- A row is read under the rows before it. The planner remembers which
-- facts it told; the page writer (Core/Pages/Render.lua) remembers which
-- words it used, and neither replaces the other. Every row is the same
-- each time it is planned, so the ledger needs no saving: it is rebuilt by
-- planning the person's earlier session rows oldest first, and kept until
-- their sessions, rows or runs change.
--
-- What it holds, per earlier row:
--   kind     what led it (angle/move: "dungeon/run"), and
--   tier     the tier it led at
--   told     every `must` its lead said (a rule's `once` reads these)
--
-- SessionProse.LedgerBefore(episode, guid) gives the weighing
--   recent   the last RECENT_LEADS rows' { kind, tier }, newest first
--   told     [tag] = true, for every `must` led with before this row
--
-- Rows are planned here without being written, so a row whose lead the
-- page writer couldn't say (SessionProse.Write's fallback) counts with the
-- lead it was planned with.
--
-- The words remember too, the same way: SessionProse.PicksFor writes the
-- person's rows oldest first, once per voice, under one page-writer memory,
-- and keeps each row's picks. A row is then written from its picks, so it
-- reads the same each time however it is reached, and differs from the rows
-- before it. One memory per person, so the order profiles are opened in
-- changes nothing.

local addonName, ns = ...

local SessionProse = ns.UI.SessionProse or {}
ns.UI.SessionProse = SessionProse

-- How many earlier rows "recently" is.
local RECENT_LEADS = 3
SessionProse.RECENT_LEADS = RECENT_LEADS

-- [guid] = { sig, rows = { { id, startedAt, kind, tier, told } } oldest first,
--            episodes (the rows' own, oldest first), picks = { [voice] = { [session id] = picks } } }
local cache = {}

local function Kind(c) return c.angle .. "/" .. c.move end

-- Changes whenever something the rows are planned from changes.
local function Signature(guid)
    local sessions = ns.Sessions.For(guid)
    local newest = sessions[1]
    local p = newest and newest.participants[guid]
    local rows = ns.Interactions.For(guid) or {}
    return table.concat({ #sessions, newest and newest.id or 0, newest and (newest.endedAt or 0) or 0,
        p and p.seconds or 0, #rows, #ns.Instances.For(guid) }, ":")
end

local function LedgerFrom(rows, before)
    local ledger = { recent = {}, told = {} }
    for i = #rows, 1, -1 do
        local r = rows[i]
        if r.startedAt < before then
            if #ledger.recent < RECENT_LEADS and r.kind then
                ledger.recent[#ledger.recent + 1] = { kind = r.kind, tier = r.tier }
            end
            for key in pairs(r.told) do ledger.told[key] = true end
        end
    end
    return ledger
end

-- Plans one row with the ledger of the rows before it, and notes what it
-- would tell.
local function Planned(episode, guid, rows)
    local list, h = SessionProse.Candidates(episode, guid)
    SessionProse.Weigh(list, h, LedgerFrom(rows, episode.session.startedAt))
    local beats = SessionProse.Choose(list, {})
    local row = { id = episode.session.id, startedAt = episode.session.startedAt, told = {} }
    if beats then
        local lead = beats[1].c
        row.kind, row.tier = Kind(lead), lead.tier
        if beats[1].role == "point" then
            for _, tag in ipairs(lead.musts or {}) do row.told[tag] = true end
        end
    end
    return row
end

local function Build(guid)
    local sig = Signature(guid)
    local entry = cache[guid]
    if entry and entry.sig == sig then return entry end

    entry = { sig = sig, rows = {}, picks = {} }
    cache[guid] = entry
    local episodes = {}
    for _, item in ipairs(ns.Timeline.For(guid)) do
        if item.kind == "session" and item.session then episodes[#episodes + 1] = item end
    end
    table.sort(episodes, function(a, b) return a.session.startedAt < b.session.startedAt end)
    for _, episode in ipairs(episodes) do
        entry.rows[#entry.rows + 1] = Planned(episode, guid, entry.rows)
    end
    entry.episodes = episodes
    return entry
end

function SessionProse.LedgerBefore(episode, guid)
    return LedgerFrom(Build(guid).rows, episode.session.startedAt)
end

-- This row's picks in `voice`, or nil. A lead the writer can't say costs its
-- row a turn of the memory; that is rare, and the same every time.
function SessionProse.PicksFor(episode, guid, voice)
    local entry = Build(guid)
    local byId = entry.picks[voice]
    if not byId then
        byId = {}
        entry.picks[voice] = byId
        local memory = ns.Pages.Memory({})
        for _, row in ipairs(entry.episodes) do
            local _, report = SessionProse.Attempt(row, guid, { voice = voice, epithets = false,
                memory = memory, commit = true })
            byId[row.session.id] = report and report.picks
        end
    end
    return byId[episode.session.id]
end

-- For the tests and /sd prose: forget every ledger.
function SessionProse.ForgetLedgers()
    for guid in pairs(cache) do cache[guid] = nil end
end
