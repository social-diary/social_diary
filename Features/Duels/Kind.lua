-- Duels: a duel with another player, won or lost, and back-to-back duels
-- with the same one told together ("lost 3 duels and won 2"; the user, 15
-- Oct). A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a duel is to the diary: its row kind, its words and
--                icon on the timeline, the route's list of duels, and the
--                series both are kept as
--   Text.lua     its words on Your Diary's plates: the note's, the
--                tooltip's, the caption's (registered there)
--   Mark.lua     the flag on the plates' map where a series began
--   Slip.lua     the margin's one-line note, and the same words glued
--                across a light plate's print (a pass)
--   Capture.lua  the challenge, the countdown and the result line read off
--                the client, and the duel's start and end told to core
--                (SD_DUEL_STARTED, SD_DUEL_FINISHED)
--   Dev.lua      its part of /sd testdata: a series with Tester, and the
--                made-up route's duels (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a duel row or the duels list. Its own
-- names are on ns.Duels, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - whether a duel is on (ns.Duelling, Core/Events.lua, kept from the
--     two messages this feature fires), which the close-call judge, the
--     route's fighting and the sightings' hostility read, so a duel is no
--     close call, no fighting on the road and no foe (the probes, 15 Oct);
--   - the score with someone (Interactions.Fights) and the route's fight
--     marks, which are world PvP's: a duel is neither (no `fight` flag).
--
-- This file: the kind, whole (Core/Rows.lua's spec in one call, words and
-- icon included), the route's list, the recap's moment, and the writing
-- of a series.

local addonName, ns = ...

local Duels = {}
ns.Duels = Duels

-- Not "duel": the tests use that for a kind nobody declared
-- (tests/timeline.lua).
local KIND = "duel_series"
Duels.KIND = KIND

-- A duel starting this long after the last one with the same player ended
-- is still the same series: the user's "one after another" (15 Oct). Long
-- enough for a drink and a rematch, short enough that a duel later in the
-- evening is a new line.
local SERIES_GAP = 15 * 60
Duels.SERIES_GAP = SERIES_GAP

-- The outcomes, as SD_DUEL_FINISHED tells them (Core/Events.lua's header),
-- and the count each adds to: a flight is a loss for the one who ran.
local COUNT = { won = "won", lost = "lost", fled = "fled", they_fled = "theyFled" }
Duels.COUNT = COUNT

-- A series' balance, "won" or "lost": the user's wins (theirs fled)
-- against their losses (the user fled), a tie going by its latest. The
-- words lead with it; nothing drawn shows it (the user, 15 Oct: one icon,
-- one mark, won or lost alike).
function Duels.Balance(c)
    local up = (c.won or 0) + (c.theyFled or 0)
    local down = (c.lost or 0) + (c.fled or 0)
    if up ~= down then return up > down and "won" or "lost" end
    return (c.last == "won" or c.last == "they_fled") and "won" or "lost"
end

--------------------------------------------------------------------------
-- The People rows
--------------------------------------------------------------------------
--
-- Always a line, never an activity: a moment, as PRD TLN-2 has a duel. One
-- row a series (below), updated in place as its duels come; within arm's
-- reach, so a live row is also "last seen". One icon, won or lost: the
-- line's words tell which (the user, 15 Oct). Not a `fight`: the score
-- with someone is world PvP's, and a duel counts in it no more than the
-- close-call judge or the route's fighting count one (ns.Duelling).

local Place = ns.UI.TimelineText.Place

-- Where a series started, as the campfire's line says it: " in Sentinel
-- Hill, Westfall", the zone alone where the client gave no subzone or one
-- with the zone's own name (Place), or "".
local function Where(row)
    local sub = row.context and row.context.subZone
    if type(sub) ~= "string" or sub == "" or sub == row.zone then return Place(row) end
    return " in " .. (row.zone and (sub .. ", " .. row.zone) or sub)
end

-- Its line, the outcome first, as the icon is the same for both: one duel
-- "Won a duel against Bram", "Lost a duel to Bram", "Won a duel when Bram
-- fled", "Fled a duel with Bram"; a series by its balance, flights counted
-- with their side, "Lost 3 duels to Bram and won 2" (the user's own, 15
-- Oct), "Won 3 duels against Bram"; each " in Sentinel Hill, Westfall".
-- A series with a flight in it says so after the place: "  ·  they fled
-- once", "  ·  you fled twice". Figures, as the timeline counts.
local function Line(row, guid)
    local c = row.context or {}
    local them = guid and ns.Characters.Name(guid) or nil
    local balance, up, down = Duels.Balance(c), (c.won or 0) + (c.theyFled or 0), (c.lost or 0) + (c.fled or 0)
    local where = Where(row)
    if up + down <= 1 then
        local last = c.last
        if not COUNT[last] then last = (c.theyFled or 0) > 0 and "they_fled" or (c.fled or 0) > 0 and "fled" or balance end
        if last == "won" then return "Won a duel against " .. (them or "them") .. where end
        if last == "they_fled" then return "Won a duel when " .. (them or "they") .. " fled" .. where end
        if last == "fled" then return "Fled a duel with " .. (them or "them") .. where end
        return "Lost a duel to " .. (them or "them") .. where
    end
    local lead, rest = up, down
    if balance == "lost" then lead, rest = down, up end
    local text = balance == "won" and ("Won " .. lead .. " duels against " .. (them or "them"))
        or ("Lost " .. lead .. " duels to " .. (them or "them"))
    if rest > 0 then text = text .. (balance == "won" and " and lost " or " and won ") .. rest end
    local Times = ns.UI.Format.Times
    local flights = {}
    if (c.fled or 0) > 0 then flights[#flights + 1] = ns.UI.Format.You(row.me, "{you} fled ") .. Times(c.fled) end
    if (c.theyFled or 0) > 0 then flights[#flights + 1] = "they fled " .. Times(c.theyFled) end
    if #flights > 0 then where = where .. "  \194\183  " .. table.concat(flights, ", ") end
    return text .. where
end

local function Always() return true end

-- The picker's reason, the same whoever challenged (it isn't kept).
ns.Rows.Register(KIND, { proximity = true, plate = 6, moment = Always, reason = "you duelled them",
    text = Line, icon = KIND })

-- Its icon: Challenging Shout's, a raised war cry (15 Oct, not yet seen in
-- the client: /sd art shows which file won).
ns.Style.AddArt(KIND, { "Interface\\Icons\\Ability_Warrior_Challange", "Interface\\Icons\\INV_Sword_04" })

--------------------------------------------------------------------------
-- The route's list: a series, where it started
--------------------------------------------------------------------------
--
-- j.duels holds each series on the character's route, oldest first: { t,
-- ended, guid, won, lost, fled, theyFled, last, mapID, x, y, subZone, zone
-- }. `t` is its first duel's start, `ended` its latest's end; the place is
-- where it started (a flight ends far from the flag). The route keeps no
-- names: the opponent is read from the diary by `guid` when a page is
-- drawn. The newest 300 are kept a character.
--
-- `guid` goes as a gift's giver's does (Features/Firsts/Kind.lua): at login
-- (`prune`), once a stranger is gone from the buffer and not in the diary;
-- on PRV-3 (`forget`), at once. The duel stays a duel.
local Journey = ns.Journey
local LIST = "duels"

Journey.RegisterList(LIST, {
    cap = 300,
    prune = function(j, now)
        local cutoff = ns.Cutoff(now)
        for _, rec in ipairs(j[LIST] or {}) do
            if rec.guid and (rec.ended or rec.t) < cutoff and not ns.Diary.IsDiary(rec.guid) then rec.guid = nil end
        end
    end,
    forget = function(j, guid)
        for _, rec in ipairs(j[LIST] or {}) do
            if guid == nil or rec.guid == guid then rec.guid = nil end
        end
    end,
})

-- A character's duels, oldest first.
function Duels.List(j)
    return Journey.List(j, LIST)
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- A series, where its first duel started (where the client planted its
-- flag), its record in the moment's `duel`.
--
-- Rank 6.5: between a long stay (6) and the road (7), so a duel never
-- opens a plate of its own while anything else is on the level: a moment
-- opens one only below a stay's rank (Core/JourneyRecap.lua, Plates'
-- `opens`), and 5.5 would have opened prints as a campfire does. It is
-- filler (the user, 15 Oct: "filler", one line, never a plate of its own),
-- so it joins a plate whose window it fits and is lost from Your Diary
-- where it fits none (its line on the opponent's timeline keeps it). As
-- the road, it still opens one where the level has nothing else at all.
-- Ranks are only ever compared, so the fraction is fine.
--
-- Light: its note is one line in the hand (under a light plate's caption,
-- or across its print's foot), so a plate of duels and places alone is a
-- print, not a full slot.
ns.JourneyRecap.RegisterMoment("duel", { order = 80, list = LIST, field = "duel", rank = 6.5, light = true })

--------------------------------------------------------------------------
-- Writing a duel
--------------------------------------------------------------------------

-- Adds `outcome` to `rec`'s counts (a row's context or a route record).
local function Count(rec, outcome, ended)
    local key = COUNT[outcome]
    rec[key] = (rec[key] or 0) + 1
    rec.last = outcome
    rec.ended = ended
end

-- The series with `guid` a duel started at `since` belongs to: the newest
-- duel row on them, if its latest duel ended at most SERIES_GAP before.
local function SeriesRow(guid, since)
    local rows = ns.db.interactions[guid]
    for i = #(rows or {}), 1, -1 do
        local row = rows[i]
        if row.type == KIND then
            local ended = row.context and row.context.ended
            if ended and since - ended <= SERIES_GAP then return row end
            return nil
        end
    end
    return nil
end

local function SeriesRecord(j, guid, since)
    local list = j[LIST]
    for i = #(list or {}), 1, -1 do
        local rec = list[i]
        if rec.guid == guid then
            if rec.ended and since - rec.ended <= SERIES_GAP then return rec end
            return nil
        end
    end
    return nil
end

-- A duel with `guid` (nil when they could not be read) that started at
-- `since` where `where` says (ns.Where's shape) ended with `outcome` (one
-- of COUNT's keys) at `ended`: on their row, and on the route while it is
-- kept, each a new series or the one it carries on. Returns the row and
-- the route's record (either may be nil).
function Duels.Added(guid, outcome, since, ended, where)
    if not COUNT[outcome] then return nil end
    since, ended = since or ended, ended or ns.Now()
    local row
    if guid then
        row = SeriesRow(guid, since)
        if row then
            Count(row.context, outcome, ended)
        else
            local c = { subZone = where and where.subZone or nil }
            Count(c, outcome, ended)
            -- Written live, at the first duel's end: a row with a time of
            -- its own would be backfill (no session, no "last seen").
            row = ns.Interactions.Add(guid, KIND, { where = where, context = c })
        end
    end
    local j = Journey.Kept()
    local rec
    if j then
        rec = guid and SeriesRecord(j, guid, since)
        if rec then
            Count(rec, outcome, ended)
        else
            rec = { t = since, guid = guid, subZone = where and where.subZone or nil,
                zone = where and where.zone or nil }
            Count(rec, outcome, ended)
            rec = Journey.Append(j, LIST, rec, where)
        end
    end
    return row, rec
end
