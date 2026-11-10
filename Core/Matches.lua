-- Battleground matches: one record a match, the evening's sessions they
-- make, who you met in them, and how old boards fade
-- (.claude/battleground-plan.md, .claude/features/battlegrounds.md).
--
-- db.matches[id] = {
--   id, me          the record's id; the user's character (as visits have)
--   map             the instance id: 489 Warsong Gulch, 529 Arathi Basin,
--                   30 Alterac Valley (GetInstanceInfo's 8th return)
--   mapName         the client's own name for it, as it was read
--   level           the user's level as the match began: a battleground
--                   session belongs to the level it began in (Jan, 9 Nov)
--   startedAt, endedAt   epoch seconds (endedAt nil while it runs)
--   duration        seconds, from the match's end (PVP_MATCH_COMPLETE),
--                   else endedAt - startedAt
--   faction         the user's side: 0 Horde, 1 Alliance (the scoreboard's
--                   and GetActiveMatchWinner's numbering)
--   winner          0 or 1; nil when there was none or it went unread
--   state           "open" while it runs; then "complete" (the board was
--                   read), "noboard" (it ended, the board never read) or
--                   "left" (the user left before the end)
--   deaths          { t, ... } the user's deaths, epoch seconds;
--   killers         { [i] = "First Surname" } who dealt the i-th death, when
--                   the death recap named a player (unproven in a match)
--   players         { packed, ... } everyone on both sides, one string a
--                   player (Pack); the user's own row among them
--   lost            the strangers' rows let go when the match rolled up
--   rolled          true once rolled up (Rollup)
-- }
--
-- A player is one string, not a table, to keep a forty-a-side match small
-- (an Alterac is ~9 KB this way against ~33 KB as tables; measured 9 Nov
-- with the client's own way of writing saved files):
--
--   guid;name;side;class;race;kb;hk;deaths;damage;healing;stats
--
-- name is "First" or "First Surname" (Core/Identity.lua's parts, joined);
-- side 0 or 1; class the class token ("WARRIOR"); stats "42:1,44:2", the
-- scoreboard's columns by pvpStatID (Warsong: 42 flags taken, 44 returned;
-- rbgs.io's ids, unproven on this build). A field the client kept secret,
-- or a row read only during play, leaves its place empty. ";" and "," are
-- never in a name. No honour, rank or title: not shown, not kept (Jan).
--
-- Who was there comes in two ways. During play only names, classes, races
-- and sides read (the probe, 9 Nov: enemies' GUIDs and classes are secret,
-- teammates' are not), so Seen gathers them by name. When the match ends
-- the scoreboard reads whole (Blizzard's docs: secret only "in an active
-- and incomplete PvP match"), and Board writes the rows from it, GUIDs and
-- numbers included. A match whose board never read keeps the names alone.
--
-- Capture/Matches.lua tells this file what the client says. Nothing here
-- reads the client but the clock.

local addonName, ns = ...

local Matches = {}
ns.Matches = Matches

-- The maps, by instance id. `short` is only a fallback; the words are the
-- UI's (UI/Journey/Text).
Matches.MAPS = {
    [489] = { key = "warsong" },
    [529] = { key = "arathi" },
    [30] = { key = "alterac" },
}

-- The scoreboard's stat ids this build is believed to use (rbgs.io on
-- Forever build 70338). Unproven here: the probe module logs them.
Matches.STAT = { FLAG_CAPTURED = 42, FLAG_RETURNED = 44 }

-- A match is left behind (a crash, a logout inside) when its open record is
-- this old with nobody coming back to it.
local STALE = 2 * 60 * 60
-- Caps, so one long match cannot grow a record without end.
local MAX_PLAYERS, MAX_DEATHS = 100, 40
-- Full boards kept by default; the setting is `battlegroundBoards`.
Matches.KEEP = 100
-- The roll-up warnings: this many full boards before roll-up starts.
Matches.WARN_AT = { 25, 10, 5, 4, 3, 2, 1 }

--------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------

-- The key a name is matched by: lower case, "first" or "first surname".
local function Key(name)
    if type(name) ~= "string" or name == "" then return nil end
    return name:lower()
end
Matches.Key = Key

-- A name as the client gave it ("First", "First Surname", "First-Realm",
-- or two parts) in the diary's form, or nil.
function Matches.Name(a, b)
    local first, surname = ns.NormalizeName(a, b)
    if not first then return nil end
    return ns.JoinName(first, surname)
end

--------------------------------------------------------------------------
-- Packed players
--------------------------------------------------------------------------

local FIELDS = { "guid", "name", "side", "class", "race", "kb", "hk", "deaths", "damage", "healing" }
local NUMERIC = { side = true, kb = true, hk = true, deaths = true, damage = true, healing = true }

local function Clean(v)
    if v == nil then return "" end
    return (tostring(v):gsub("[;,]", ""))
end

function Matches.Pack(p)
    local out = {}
    for i, f in ipairs(FIELDS) do out[i] = Clean(p[f]) end
    local stats = {}
    if type(p.stats) == "table" then
        local ids = {}
        for id in pairs(p.stats) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do stats[#stats + 1] = id .. ":" .. Clean(p.stats[id]) end
    end
    out[#FIELDS + 1] = table.concat(stats, ",")
    return table.concat(out, ";")
end

function Matches.Unpack(s)
    if type(s) ~= "string" then return nil end
    local p, i = {}, 0
    for part in (s .. ";"):gmatch("([^;]*);") do
        i = i + 1
        local f = FIELDS[i]
        if f then
            if part ~= "" then p[f] = NUMERIC[f] and tonumber(part) or part end
        elseif i == #FIELDS + 1 and part ~= "" then
            p.stats = {}
            for id, v in part:gmatch("(%d+):(%-?%d+)") do p.stats[tonumber(id)] = tonumber(v) end
        end
    end
    return p
end

-- Every player of a match, unpacked, in the order kept. Built again on each
-- call; the pages read a match once as they open.
function Matches.Players(match)
    local list = {}
    for i, s in ipairs(match and match.players or {}) do
        local p = Matches.Unpack(s)
        if p then p.index = i list[#list + 1] = p end
    end
    return list
end

--------------------------------------------------------------------------
-- The store
--------------------------------------------------------------------------

function Matches.New(match)
    local meta = ns.db.meta
    local id = meta.nextMatchId or 1
    meta.nextMatchId = id + 1
    match.id = id
    match.me = match.me or ns.ownGUID
    match.players = match.players or {}
    match.deaths = match.deaths or {}
    ns.db.matches[id] = match
    return match
end

function Matches.Get(id)
    return id and ns.db.matches[id] or nil
end

-- A character's matches (all of them with nil), oldest first.
function Matches.All(me)
    local list = {}
    for _, m in pairs(ns.db.matches) do
        if me == nil or m.me == me then list[#list + 1] = m end
    end
    table.sort(list, function(a, b)
        if a.startedAt ~= b.startedAt then return (a.startedAt or 0) < (b.startedAt or 0) end
        return a.id < b.id
    end)
    return list
end

function Matches.Remove(id)
    ns.db.matches[id] = nil
    if ns.db.meta.openMatch == id then ns.db.meta.openMatch = nil end
end

-- The match open now, or nil.
function Matches.Current()
    local m = Matches.Get(ns.db.meta.openMatch)
    if m and m.state == "open" then return m end
    return nil
end

-- Won, lost, or nil (no winner, or it went unread).
function Matches.Won(match)
    if not match or match.winner == nil or match.faction == nil then return nil end
    return match.winner == match.faction
end

--------------------------------------------------------------------------
-- During play
--------------------------------------------------------------------------

-- Opens a match, or carries on with the open one for this map (a /reload,
-- a disconnect). info = { map, mapName, faction, level }.
function Matches.Enter(info, now)
    now = now or ns.Now()
    local open = Matches.Current()
    if open then
        if open.map == info.map and now - (open.seenAt or open.startedAt) < STALE then
            open.seenAt = now
            return open, false
        end
        Matches.Close(open, "left", now)
    end
    local m = Matches.New({ map = info.map, mapName = info.mapName, faction = info.faction,
        level = info.level, startedAt = now, seenAt = now, state = "open" })
    ns.db.meta.openMatch = m.id
    return m, true
end

-- The row for `name` (or `guid`) in a match, and its index.
local function Find(match, guid, key)
    for i, s in ipairs(match.players) do
        local p = Matches.Unpack(s)
        if (guid and p.guid == guid) or (key and Key(p.name) == key) then return p, i end
    end
end
Matches._Find = Find

-- Someone seen during play: p = { name, guid?, side?, class?, race? }.
-- Adds a row, or fills what the row lacked. Returns the row and whether it
-- is new to this match.
function Matches.Seen(match, p)
    if not match or not p or (not p.name and not p.guid) then return nil end
    local row, i = Find(match, p.guid, Key(p.name))
    if row then
        local changed = false
        for _, f in ipairs({ "guid", "name", "side", "class", "race" }) do
            if row[f] == nil and p[f] ~= nil then row[f] = p[f] changed = true end
        end
        if changed then match.players[i] = Matches.Pack(row) end
        return row, false
    end
    if #match.players >= MAX_PLAYERS then return nil end
    match.players[#match.players + 1] = Matches.Pack(p)
    return p, true
end

-- The user died in the match.
function Matches.Death(match, now, killer)
    if not match or #match.deaths >= MAX_DEATHS then return end
    match.deaths[#match.deaths + 1] = now or ns.Now()
    if killer then
        match.killers = match.killers or {}
        match.killers[#match.deaths] = killer
    end
end

-- The match ended: winner and length as the client gave them.
function Matches.Complete(match, winner, duration, now)
    if not match then return end
    now = now or ns.Now()
    if winner == 0 or winner == 1 then match.winner = winner end
    if type(duration) == "number" and duration > 0 then match.duration = duration end
    match.endedAt = match.endedAt or now
    match.completeAt = now
end

-- The final board: rows = { { guid, name, side, class, race, kb, hk,
-- deaths, damage, healing, stats }, ... }, as Capture read them. The
-- board's rows replace those seen during play; anyone seen but not on the
-- board (left before the end) stays.
function Matches.Board(match, rows)
    if not match or type(rows) ~= "table" or #rows == 0 then return end
    local kept = {}
    local onBoard = {}
    for _, r in ipairs(rows) do
        if #kept < MAX_PLAYERS then
            kept[#kept + 1] = Matches.Pack(r)
            if r.guid then onBoard[r.guid] = true end
            if r.name then onBoard[Key(r.name)] = true end
        end
    end
    for _, s in ipairs(match.players) do
        local p = Matches.Unpack(s)
        if not (p.guid and onBoard[p.guid]) and not onBoard[Key(p.name) or ""] and #kept < MAX_PLAYERS then
            p.left = true
            kept[#kept + 1] = s
        end
    end
    match.players = kept
    match.board = true
end

-- Ends the match: "complete", "noboard" or "left".
function Matches.Close(match, state, now)
    if not match then return end
    if ns.Touch then ns.Touch() end
    now = now or ns.Now()
    match.state = state
    match.endedAt = match.endedAt or now
    match.duration = match.duration or (match.endedAt - match.startedAt)
    match.seenAt = nil
    if ns.db.meta.openMatch == match.id then ns.db.meta.openMatch = nil end
end

-- An open match nobody came back to is over.
function Matches.Expire(now)
    now = now or ns.Now()
    local open = Matches.Current()
    if open and now - (open.seenAt or open.startedAt) >= STALE then
        Matches.Close(open, open.completeAt and "noboard" or "left", open.seenAt or now)
    end
end

--------------------------------------------------------------------------
-- Diary people
--------------------------------------------------------------------------

-- Two names are the same person's when they are equal, or when one of
-- them has no surname and the first names agree: the diary may hold "Bram"
-- where the board says "Bram Redfen" (a name read before the surname was).
local function SameName(a, b)
    a, b = Key(a), Key(b)
    if not a or not b then return false end
    if a == b then return true end
    if a:find(" ", 1, true) and b:find(" ", 1, true) then return false end
    return a:match("^(%S+)") == b:match("^(%S+)")
end
Matches.SameName = SameName

-- The diary's people with their names: { { guid, name } }.
local function DiaryNames()
    local list = {}
    for guid in pairs(ns.db.diary) do
        local name = ns.Characters.FullName(guid)
        if name then list[#list + 1] = { guid = guid, name = name } end
    end
    return list
end
Matches.DiaryNames = DiaryNames

-- The diary entry a row is, or nil: by GUID, else by name when exactly one
-- diary person goes by it (a name is not a key, Characters.FindByName).
function Matches.Who(p, names)
    if not p then return nil end
    if p.guid then return ns.db.diary[p.guid] and p.guid or nil end
    if not p.name then return nil end
    local hit
    for _, d in ipairs(names or DiaryNames()) do
        if SameName(d.name, p.name) then
            if hit and hit ~= d.guid then return nil end
            hit = d.guid
        end
    end
    return hit
end

-- With you or against you: "with", "against", or nil (side unknown).
function Matches.Side(match, p)
    if not p or p.side == nil or match.faction == nil then return nil end
    return p.side == match.faction and "with" or "against"
end

-- Every match a character was in, oldest first: { { match, row, side } }.
-- By GUID, and by name for the rows that never had one (Jan: count every
-- meeting, rolled-up matches too).
function Matches.For(guid, me)
    guid = ns.SafeGUID(guid)
    if not guid then return {} end
    local name = ns.Characters.FullName(guid)
    local out = {}
    for _, m in ipairs(Matches.All(me)) do
        for _, s in ipairs(m.players) do
            local p = Matches.Unpack(s)
            if p.guid == guid or (not p.guid and SameName(name, p.name)) then
                out[#out + 1] = { match = m, row = p, side = Matches.Side(m, p) }
                break
            end
        end
    end
    return out
end

-- How many matches before `match` (and including it) a character was in on
-- the given side ("against", "with", or nil for either): "your fourth match
-- against him".
function Matches.Meetings(guid, match, side)
    local n = 0
    for _, hit in ipairs(Matches.For(guid, match and match.me)) do
        if (side == nil or hit.side == side)
            and (not match or (hit.match.startedAt or 0) <= (match.startedAt or 0)) then
            n = n + 1
        end
    end
    return n
end

--------------------------------------------------------------------------
-- Battleground sessions
--------------------------------------------------------------------------
--
-- A battleground session is a character's matches in one sitting (Jan,
-- 9 Nov: only the play-session gap ends it, maps mix). A match is placed
-- by the sitting it began in; one that no sitting holds (a route not kept)
-- joins the one before when it began within Sittings.GAP of its end.

function Matches.Sessions(me)
    me = me or ns.ownGUID
    local j = ns.Journey and ns.Journey.For and ns.Journey.For(me)
    local sessions, last = {}, nil
    for _, m in ipairs(Matches.All(me)) do
        local s = j and ns.Sittings.At(j, m.startedAt)
        local same
        if last then
            if s and last.sitting then
                same = s.from == last.sitting.from
            else
                same = m.startedAt - (last.endedAt or last.startedAt) <= ns.Sittings.GAP
            end
        end
        if same then
            last.matches[#last.matches + 1] = m
            last.endedAt = m.endedAt or m.startedAt
        else
            last = { matches = { m }, sitting = s, startedAt = m.startedAt,
                endedAt = m.endedAt or m.startedAt, level = m.level }
            sessions[#sessions + 1] = last
        end
    end
    -- Built anew on each call: a session is known by its first match's id.
    for i, s in ipairs(sessions) do s.index, s.key = i, s.matches[1].id end
    return sessions
end

-- The session a match is in.
function Matches.SessionOf(match)
    if not match then return nil end
    for _, s in ipairs(Matches.Sessions(match.me)) do
        for _, m in ipairs(s.matches) do
            if m == match then return s end
        end
    end
    return nil
end

-- The sessions that began in [a, b), oldest first: the journey's piece they
-- belong to (Core/JourneyRecap.lua's Pieces).
function Matches.Between(me, a, b)
    local out = {}
    for _, s in ipairs(Matches.Sessions(me)) do
        if s.startedAt >= a and s.startedAt < b then out[#out + 1] = s end
    end
    return out
end

-- An overview page is drawn for three matches or more (Jan, 9 Nov).
Matches.OVERVIEW_AT = 3
function Matches.HasOverview(session)
    return session and #session.matches >= Matches.OVERVIEW_AT or false
end

--------------------------------------------------------------------------
-- Roll-up
--------------------------------------------------------------------------
--
-- Full boards are kept for the newest N matches (the setting). An older
-- match rolls up: its header stays (map, result, times, your deaths), and
-- the rows of diary people; strangers' rows go, counted in `lost`, so the
-- pages can say what faded rather than show nothing (Jan, 9 Nov).

function Matches.Keep()
    local n = ns.Setting and ns.Setting("battlegroundBoards")
    return type(n) == "number" and n > 0 and n or Matches.KEEP
end

-- Matches with their full board still, newest first.
local function Full()
    local list = {}
    for _, m in pairs(ns.db.matches) do
        if not m.rolled and m.state ~= "open" then list[#list + 1] = m end
    end
    table.sort(list, function(a, b)
        if a.startedAt ~= b.startedAt then return (a.startedAt or 0) > (b.startedAt or 0) end
        return a.id > b.id
    end)
    return list
end

-- How many more matches until the oldest board rolls up: 0 when roll-up
-- has started (the next match rolls one up).
function Matches.UntilRollup()
    return math.max(0, Matches.Keep() - #Full())
end

-- The warning due now, or nil: the smallest WARN_AT step at or above the
-- matches left that has not been warned of yet (meta.matchWarned keeps the
-- last step warned; it is cleared when there is room again).
function Matches.WarningDue()
    local left = Matches.UntilRollup()
    local warned = ns.db.meta.matchWarned
    if left > Matches.WARN_AT[1] then
        ns.db.meta.matchWarned = nil
        return nil
    end
    if left == 0 then return nil end
    local step
    for _, at in ipairs(Matches.WARN_AT) do
        if left <= at then step = at end
    end
    if step and (warned == nil or step < warned) then return step, left end
    return nil
end

function Matches.Warned(step)
    ns.db.meta.matchWarned = step
end

function Matches.Rollup(now, keep)
    keep = keep or Matches.Keep()
    local full = Full()
    local names
    for i = keep + 1, #full do
        local m = full[i]
        names = names or DiaryNames()
        local kept, lost = {}, 0
        for _, s in ipairs(m.players) do
            local p = Matches.Unpack(s)
            if Matches.Who(p, names) or (p.guid and p.guid == m.me) then
                kept[#kept + 1] = s
            else
                lost = lost + 1
            end
        end
        m.players = kept
        m.lost = (m.lost or 0) + lost
        m.rolled = true
    end
end

--------------------------------------------------------------------------
-- Forgetting
--------------------------------------------------------------------------

-- PRV-3: a forgotten person's row leaves every match, by GUID and by the
-- name they went by. The match itself stays: it is the user's history.
-- nil forgets every match.
function Matches.Forget(guid)
    if guid == nil then
        wipe(ns.db.matches)
        ns.db.meta.openMatch = nil
        ns.db.meta.matchWarned = nil
        return
    end
    local name = ns.Characters.FullName(guid)
    for _, m in pairs(ns.db.matches) do
        for i = #m.players, 1, -1 do
            local p = Matches.Unpack(m.players[i])
            if p.guid == guid or (not p.guid and SameName(name, p.name)) then
                table.remove(m.players, i)
            end
        end
    end
end
ns.RegisterStore("matches", Matches.Forget)
