-- The interaction buffer (INT-1 to INT-5).
--
-- Every explicit exchange with anyone -- grouped, whispered, traded -- lands
-- here first, whether or not the user has ever heard of them. That is what
-- makes flow 2 work: you trade with a stranger, move on, and an hour later
-- their profile already knows about the trade.
--
-- Retention (INT-2, decision D3): 30 days for characters outside the diary.
-- For diary entries the rows are kept permanently and become the highlights
-- inside together sessions (SES-5), so pruning skips them.
--
-- Rows are stored per GUID, oldest first. The reads this milestone needs are
-- all "what happened with this person" (DIA-5's promotion, JNL-2's profile),
-- and a per-GUID table answers those without scanning. The day log (JNL-7) is
-- M3 and will want a chronological pass over the same rows.

local addonName, ns = ...

local Interactions = {}
ns.Interactions = Interactions

-- A hard ceiling per character outside the diary, so one long evening
-- cannot grow without bound before the next prune. Well above a plausible
-- day of interaction. Diary entries have none: their history is kept for
-- good (decision of 8 Oct 2026), and the Memory settings warn when the saved
-- file grows large instead (ns.SIZE_WARNING).
local MAX_ROWS = 250

-- INT-3: how many lines of chat are kept per character is the user's
-- (settings.chatLines, 50 to begin with, or every line with
-- settings.chatUnlimited). Each line is capped in length here.
local MAX_EXCERPT_CHARS = 255

-- Which kinds carry chat text (`chat`), are about them rather than with
-- them (`observed`), or mean they were near (`proximity`) is each kind's
-- (Core/Rows.lua).
local Rows = ns.Rows

-- Rows about them rather than with them: something the user saw, not an
-- exchange. They live in the buffer like any row, so they come along when
-- the character is added (flow 2), but they do not make anyone "someone I
-- just dealt with" (Since, the picker) or count as interactions on record.
local function Observed(kind) return Rows.Get(kind).observed == true end

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

function Interactions.For(guid)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end
    return ns.db.interactions[guid]
end

function Interactions.Count(guid)
    local rows = Interactions.For(guid) or {}
    local n = 0
    for i = 1, #rows do
        if not Observed(rows[i].type) then n = n + 1 end
    end
    return n
end

-- Rows and characters, over the whole buffer: the shape Sightings.Count
-- has, for the settings page and /sd db.
function Interactions.Totals()
    local rows = 0
    for _, list in pairs(ns.db.interactions) do rows = rows + #list end
    return rows, ns.CountKeys(ns.db.interactions)
end

-- Everyone whose latest row is at or after `since`, newest first:
-- { guid, time, type } of that row. DIA-3's picker offers them as "someone
-- I just dealt with".
function Interactions.Since(since)
    local list = {}
    for guid, rows in pairs(ns.db.interactions) do
        for i = #rows, 1, -1 do
            local row = rows[i]
            if not Observed(row.type) then
                if row.time >= since then
                    list[#list + 1] = { guid = guid, time = row.time, type = row.type }
                end
                break
            end
        end
    end
    table.sort(list, function(a, b) return a.time > b.time end)
    return list
end

-- The fights with `guid` (rows whose kind sets Core/Rows.lua's `fight`):
-- { kills, yours, deaths, last, zone } -- every kill, the ones the user
-- landed themselves (no context.by), the user's deaths to them, and when
-- and where the latest fight was. nil when there has been none. The
-- profile's sentence and the foe's reunion card tell it
-- (ns.UI.Format.FightsText).
function Interactions.Fights(guid)
    local rows = Interactions.For(guid)
    if not rows then return nil end

    local t = { kills = 0, yours = 0, deaths = 0 }
    for i = 1, #rows do
        local row = rows[i]
        local fight = Rows.Get(row.type).fight
        if fight == "kill" or fight == "death" then
            if fight == "kill" then
                t.kills = t.kills + 1
                if not (row.context and row.context.by) then t.yours = t.yours + 1 end
            else
                t.deaths = t.deaths + 1
            end
            if not t.last or row.time >= t.last then t.last, t.zone = row.time, row.zone end
        end
    end
    if not t.last then return nil end
    return t
end

-- The most recent row of a given type, or of any type when kind is nil.
-- Only the smoke tests ask: the picker keeps its own ns.Recent.
function ns._test.LatestInteraction(guid, kind)
    local rows = Interactions.For(guid)
    if not rows then return nil end

    for i = #rows, 1, -1 do
        if not kind or rows[i].type == kind then return rows[i] end
    end
    return nil
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

local function Excerpt(text)
    local plain = ns.Plain(text)
    if type(plain) ~= "string" or plain == "" then return nil end
    if #plain > MAX_EXCERPT_CHARS then
        plain = ns.CutBytes(plain, MAX_EXCERPT_CHARS - 1) .. "\226\128\166"  -- ellipsis
    end
    return plain
end

-- A copy of `t` without its secret values, one level deep; nil for a secret
-- or missing table.
local function PlainFields(t)
    t = ns.Plain(t)
    if type(t) ~= "table" then return nil end
    local copy = {}
    for key, value in pairs(t) do
        copy[key] = ns.Plain(value)
    end
    return copy
end

-- How many lines of chat to keep per character, or nil for every line.
function Interactions.ChatLines()
    if ns.Setting("chatUnlimited") then return nil end
    return ns.PositiveSetting("chatLines")
end

-- INT-3's cap is on stored lines, not on rows: an older row keeps its place
-- in the history and loses only its text.
local function TrimExcerpts(rows, cap)
    if not cap then return end
    local kept = 0
    for i = #rows, 1, -1 do
        if rows[i].excerpt then
            kept = kept + 1
            if kept > cap then
                rows[i].excerpt = nil
            end
        end
    end
end

-- Everyone's chat down to the current cap, at once: for when the user
-- lowers it, as a shorter retention applies at once.
function Interactions.TrimChat()
    local cap = Interactions.ChatLines()
    for _, rows in pairs(ns.db.interactions) do TrimExcerpts(rows, cap) end
end

-- The single entry point. `data` may carry excerpt, context, theirLevel,
-- hostile and time; everything else is filled in here so that no capture path
-- has to remember to record the zone or which of the user's characters was
-- present (DAT-1).
--
-- Rows written after the fact (/sd testdata) know better than the live
-- lookups, so two more fields override them: `where`, a location in the
-- shape of ns.Where(), and `session`, the session id to stamp, or false for
-- none.
--
-- The store scrubs what came from the client: a secret would be silently
-- dropped on the next save and take its row's meaning with it (INT-5). The
-- GUID goes through SafeGUID; excerpt, theirLevel and hostile through
-- ns.Plain; `context` gets a shallow pass (PlainFields), so a secret value in
-- it is dropped and a nested table is the caller's to scrub (Trade does).
-- `time`, `where` and `session` are the addon's own values.
function Interactions.Add(guid, kind, data)
    guid = ns.SafeGUID(guid)
    if not guid or type(kind) ~= "string" then return nil end

    data = data or {}

    local storeChat = ns.db.settings.storeChat
    local isChat = Rows.Get(kind).chat == true

    local row = {
        type = kind,
        time = data.time or ns.Now(),
        me = ns.ownGUID,
        myLevel = ns.Plain(UnitLevel("player")),
        theirLevel = ns.Plain(data.theirLevel),
        hostile = ns.Plain(data.hostile) or nil,
        context = PlainFields(data.context),
    }

    if isChat and storeChat then
        row.excerpt = Excerpt(data.excerpt)
    end

    local where = data.where or ns.Where()
    row.zone = where.zone
    row.mapID = where.mapID
    row.x, row.y = where.x, where.y
    row.instanceID = where.instanceID

    -- SES-5: a row with a diary entry during a together session is a
    -- highlight of that session. A trade or a /say can also open one. Rows
    -- with an explicit time are backfill and describe the past.
    if data.session ~= nil then
        row.session = data.session or nil
    else
        row.session = ns.Sessions.Note(guid, kind, data.time == nil)
    end

    if Rows.Get(kind).proximity and data.time == nil then
        ns.Characters.Seen(guid, where)
    end

    local rows = ns.ListFor(ns.db.interactions, guid)
    rows[#rows + 1] = row

    if not ns.Diary.IsDiary(guid) then
        while #rows > MAX_ROWS do
            table.remove(rows, 1)
        end
    end

    if isChat then
        TrimExcerpts(rows, Interactions.ChatLines())
    end

    -- A trade or a group join is a meeting on the People list (JNL-1). The
    -- list only counts diary entries' rows; a stranger's row changes nothing
    -- it shows until Diary.Add, which moves the version itself.
    if ns.Diary.IsDiary(guid) then ns.Touch() end
    ns.TouchSeen()

    ns.Debug("interaction %s with %s", kind, ns.Characters.FullName(guid) or guid)

    return row
end

-- Takes back one row Add wrote, when what it said turned out wrong (a
-- killer guessed at the moment of death, then put down to someone else by
-- the death recap). Returns whether
-- it was there.
function Interactions.Remove(guid, row)
    guid = ns.SafeGUID(guid)
    local rows = guid and ns.db.interactions[guid]
    if not rows then return false end

    for i = #rows, 1, -1 do
        if rows[i] == row then
            table.remove(rows, i)
            if #rows == 0 then ns.db.interactions[guid] = nil end
            if ns.Diary.IsDiary(guid) then ns.Touch() end
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------
-- Retention
--------------------------------------------------------------------------

-- INT-2 / D3. Runs at login; cheap enough to run again whenever the setting
-- changes. Diary entries are exempt -- their history is the product.
function Interactions.Prune(now)
    local days = ns.BufferDays()
    local cutoff = ns.Cutoff(now, days)

    local droppedRows, droppedCharacters = 0, 0

    for guid, rows in pairs(ns.db.interactions) do
        if not ns.Diary.IsDiary(guid) then
            local keep = {}
            for i = 1, #rows do
                if rows[i].time >= cutoff then
                    keep[#keep + 1] = rows[i]
                else
                    droppedRows = droppedRows + 1
                end
            end

            if #keep == 0 then
                ns.db.interactions[guid] = nil
                droppedCharacters = droppedCharacters + 1
            elseif #keep < #rows then
                ns.db.interactions[guid] = keep
            end
        end
    end

    if droppedRows > 0 then
        ns.Debug("pruned %d interaction(s) and %d character(s) past %d days",
            droppedRows, droppedCharacters, days)
    end

    return droppedRows, droppedCharacters
end

-- DIA-7: removing someone from the diary can keep their history as a normal
-- character, which means the buffer rules start applying to it again.
--
-- PRV-3, through Characters.Forget. nil forgets everyone; checked before
-- SafeGUID, which turns an unreadable GUID into nil as well.
function Interactions.Forget(guid)
    if guid == nil then
        wipe(ns.db.interactions)
        return true
    end

    guid = ns.SafeGUID(guid)
    if not guid then return false end
    if ns.db.interactions[guid] == nil then return false end

    ns.db.interactions[guid] = nil
    return true
end
ns.RegisterStore("interactions", Interactions.Forget)
