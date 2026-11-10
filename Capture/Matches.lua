-- Battleground matches (.claude/battleground-plan.md): in and out, who was
-- there, your deaths, the end and the final board. Core/Matches.lua keeps
-- the record; this file only says what the client said.
--
-- What the client gives, and how far it can be trusted (research note,
-- 9 Nov 2026, .claude/battleground-research.md; one probe match):
--
--   in and out    IsInInstance "pvp" and GetInstanceInfo's instance id, on
--                 entering the world, a zone change, and the match's own
--                 PVP_MATCH_ACTIVE / PVP_MATCH_STATE_CHANGED. Not secret.
--   who, playing  the scoreboard's name, faction, race and class token are
--                 never secret (Blizzard's docs); teammates' GUIDs read
--                 (probe); enemies by name only, from nameplates, target and
--                 mouseover (their GUID and class are secret, probe).
--   the end       PVP_MATCH_COMPLETE (winner, duration), and
--                 C_PvP.GetActiveMatchWinner as a second source.
--   the board     C_PvP.GetScoreInfo, read after the end: secret "in an
--                 active and incomplete PvP match" only. It takes a few
--                 seconds to fill: asked for at once, read after FIRST
--                 seconds, then every RETRY until a row's GUID reads, at
--                 most TRIES times (wow-pvp-history's sweep). Unproven on
--                 this client: a board that never reads closes the match
--                 as "noboard", with the names gathered during play.
--   deaths        PLAYER_DEAD. Who killed you: the death recap, if it names
--                 a player plainly (unproven inside a match).
--   not used      PARTY_KILL (both GUIDs secret in a match, probe), the
--                 combat log (closed), match chat (secret).
--
-- After Capture/Instances.lua in the TOC; independent of it (Instances
-- takes party and raid only). The rest of the diary stays off in a match
-- (ns.InBattleground): this file is the only one that writes there.
-- Everything uncertain says so under /sd debug, so the next match in the
-- client settles it.

local addonName, ns = ...

local Matches = ns.Matches

-- (10 Nov, in the client, one Warsong: the PvP restriction lifts the
-- moment the match is Complete, the GUIDs read 0.5 s after
-- PVP_MATCH_COMPLETE, and the board is empty again ~17 s later, at
-- PVP_MATCH_INACTIVE. So the first read comes after 1 s, not 3, in case the
-- player leaves at once.)
local FIRST, RETRY, TRIES = 1, 2, 12
local GATHER_EVERY = 5      -- seconds between two reads of the board's names
local ASK_EVERY = 15        -- RequestBattlefieldScoreData while it runs

local P = ns.Plain

-- Horde 0, Alliance 1: the scoreboard's and the winner's numbering.
local function FactionIndex(name)
    name = P(name)
    if name == "Horde" then return 0 end
    if name == "Alliance" then return 1 end
    if name == 0 or name == 1 then return name end
    return nil
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return P(a), P(b)
end

-- In a battleground now: { map, mapName }, or nil. Arenas are not matches
-- here (non-goal).
local function Here()
    if not IsInInstance then return nil end
    local inside, kind = IsInInstance()
    if P(inside) ~= true or P(kind) ~= "pvp" then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    id = P(id)
    if type(id) ~= "number" then return nil end
    return { map = id, mapName = P(name) }
end
ns._test.MatchHere = Here

-- The match is over on the client's side (Complete or PostRound), so a
-- zone change or a /reload now does not open a new one.
local function Over()
    if not (C_PvP and C_PvP.GetActiveMatchState and Enum and Enum.PvPMatchState) then return false end
    local state = Call(C_PvP.GetActiveMatchState)
    return state ~= nil and (state == Enum.PvPMatchState.Complete or state == Enum.PvPMatchState.PostRound)
end

--------------------------------------------------------------------------
-- Who was there
--------------------------------------------------------------------------

local greeted = {}   -- [matchId] = { [guid] = true }: one toast a match

local function Greet(match, row)
    local who = Matches.Who(row)
    if not who or who == ns.ownGUID then return end
    greeted[match.id] = greeted[match.id] or {}
    if greeted[match.id][who] then return end
    greeted[match.id][who] = true
    ns.Fire("SD_REUNION", who, "match")
end

local function Seen(match, p)
    local row, new = Matches.Seen(match, p)
    if row and new then Greet(match, row) end
end

-- A row of the scoreboard, plain parts only. `full` reads the numbers and
-- stats too (after the end).
local function ScoreRow(i, full)
    if not (C_PvP and C_PvP.GetScoreInfo) then return nil end
    local ok, row = pcall(C_PvP.GetScoreInfo, i)
    if not ok or type(row) ~= "table" or ns.IsSecret(row) then return nil end
    local function F(key)
        local okF, v = pcall(function() return row[key] end)
        return okF and P(v) or nil
    end
    local p = {
        name = Matches.Name(F("name")),
        guid = ns.SafeGUID(F("guid")),
        side = FactionIndex(F("faction")),
        class = F("classToken"),
        race = F("raceName"),
    }
    if not p.name and not p.guid then return nil end
    if full then
        p.kb, p.hk, p.deaths = F("killingBlows"), F("honorableKills"), F("deaths")
        p.damage, p.healing = F("damageDone"), F("healingDone")
        local stats = F("stats")
        if type(stats) == "table" then
            p.stats = {}
            for _, s in ipairs(stats) do
                local okS, id, v = pcall(function() return s.pvpStatID, s.pvpStatValue end)
                id, v = okS and P(id), okS and P(v)
                if type(id) == "number" and type(v) == "number" then p.stats[id] = v end
            end
            if not next(p.stats) then p.stats = nil end
        end
        for _, k in ipairs({ "kb", "hk", "deaths", "damage", "healing" }) do
            if type(p[k]) ~= "number" then p[k] = nil end
        end
    end
    return p
end

local function Rows()
    local n = Call(GetNumBattlefieldScores)
    if type(n) ~= "number" then return 0 end
    return n
end

local gatheredAt = 0
local function Gather(force)
    local match = Matches.Current()
    if not match then return end
    local now = GetTime and GetTime() or 0
    if not force and now - gatheredAt < GATHER_EVERY then return end
    gatheredAt = now
    match.seenAt = ns.Now()
    for i = 1, Rows() do
        local p = ScoreRow(i, false)
        if p then Seen(match, p) end
    end
    -- Teammates, GUIDs and all (probe: they read during play).
    local members = Call(GetNumGroupMembers) or 0
    for i = 1, members do
        local unit = "raid" .. i
        local guid = ns.SafeGUID(UnitGUID(unit))
        local first, surname = ns.NameFromUnit(unit)
        if guid or first then
            local _, class = UnitClass(unit)
            Seen(match, { guid = guid, name = ns.JoinName(first, surname),
                side = match.faction, class = P(class) })
        end
    end
end
ns._test.MatchGather = Gather

-- Another player met in the match: a nameplate, the target, the mouseover.
-- Enemies come by name (GUID and class are secret, probe 9 Nov).
local function Unit(unit)
    local match = Matches.Current()
    if not match or not unit or not UnitExists(unit) then return end
    if P(UnitIsPlayer(unit)) ~= true then return end
    local first, surname = ns.NameFromUnit(unit)
    if not first then return end
    local guid = ns.SafeGUID(UnitGUID(unit))
    if guid == ns.ownGUID then return end
    local _, class = UnitClass(unit)
    Seen(match, { guid = guid, name = ns.JoinName(first, surname),
        side = FactionIndex((UnitFactionGroup(unit))), class = P(class) })
end

--------------------------------------------------------------------------
-- In and out
--------------------------------------------------------------------------

local finishedHere = false   -- this match ended while we are still inside

local function Open(info)
    local level = P(UnitLevel("player"))
    local match, new = Matches.Enter({ map = info.map, mapName = info.mapName,
        faction = FactionIndex((UnitFactionGroup("player"))),
        level = type(level) == "number" and level or nil }, ns.Now())
    if new then ns.Debug("Match opened: %s (%s).", tostring(info.mapName), tostring(info.map)) end
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    Gather(true)
    return match
end

local Finish

local function Check()
    if not ns.ownGUID then return end
    Matches.Expire(ns.Now())
    local info = Here()
    if info then
        if finishedHere or Over() then return end
        Open(info)
        return
    end
    finishedHere = false
    local open = Matches.Current()
    if open then
        if open.completeAt then
            Finish(open, true)
        else
            ns.Debug("Match left before its end.")
            Matches.Close(open, "left")
            ns.Fire("SD_MATCH_CLOSED", open)
        end
    end
end
ns._test.MatchCheck = Check

--------------------------------------------------------------------------
-- The end and the board
--------------------------------------------------------------------------

local sweeping

-- Reads the whole board if its GUIDs read: true when it was written.
local function ReadBoard(match)
    local rows, readable = {}, 0
    for i = 1, Rows() do
        local p = ScoreRow(i, true)
        if p then
            rows[#rows + 1] = p
            if p.guid then readable = readable + 1 end
        end
    end
    if readable == 0 then return false end
    Matches.Board(match, rows)
    return true
end

-- Ends the match: with its board if it read (or one last try when `last`).
function Finish(match, last)
    sweeping = nil
    finishedHere = Here() ~= nil
    local read = match.board or ReadBoard(match)
    Matches.Close(match, read and "complete" or "noboard")
    ns.Debug("Match closed: %s.", read and "board read" or "the board never read")
    Matches.Rollup(ns.Now())
    ns.Fire("SD_MATCH_CLOSED", match)
end

local function Sweep(match, try)
    if sweeping ~= match.id or match.state ~= "open" then return end
    if ReadBoard(match) then
        ns.Debug("Board read %d s after the end.", FIRST + (try - 1) * RETRY)
        Finish(match)
        return
    end
    if try >= TRIES then
        Finish(match)
        return
    end
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    ns.After(RETRY, function() Sweep(match, try + 1) end)
end

local function Complete(winner, duration)
    local match = Matches.Current()
    if not match then
        local info = Here()
        if not info then return end
        match = Open(info)
    end
    Gather(true)
    winner = P(winner)
    if winner ~= 0 and winner ~= 1 then
        winner = Call(C_PvP and C_PvP.GetActiveMatchWinner)
    end
    duration = P(duration)
    if type(duration) ~= "number" then duration = Call(C_PvP and C_PvP.GetActiveMatchDuration) end
    Matches.Complete(match, winner, duration, ns.Now())
    ns.Debug("Match complete: winner %s, %s s.", tostring(winner), tostring(duration))
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    sweeping = match.id
    ns.After(FIRST, function() Sweep(match, 1) end)
end
ns._test.MatchComplete = Complete

--------------------------------------------------------------------------
-- Deaths
--------------------------------------------------------------------------

-- Who dealt the killing blow, if the recap names a player plainly. The
-- recap's id is in the "You died" chat line, which is secret in a match;
-- asked without one, as the newest. Unproven: says so under /sd debug.
local function Killer()
    if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return nil end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents)
    if not ok or type(events) ~= "table" or ns.IsSecret(events) then return nil end
    local killer
    for _, e in ipairs(events) do
        local okE, overkill, name, guid = pcall(function() return e.overkill, e.sourceName, e.sourceGUID end)
        if okE then
            overkill, name, guid = P(overkill), P(name), P(guid)
            if type(overkill) == "number" and overkill > 0 and ns.SafeGUID(guid) then
                killer = Matches.Name(name)
            end
        end
    end
    return killer
end

ns.On("PLAYER_DEAD", function()
    local match = Matches.Current()
    if not match then return end
    local now = ns.Now()
    ns.After(1, function()
        local killer = Killer()
        ns.Debug("Died in the match; the recap named %s.", killer and "a player" or "no one")
        Matches.Death(match, now, killer)
    end)
end)

--------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------

ns.On("PLAYER_ENTERING_WORLD", function() ns.After(1, Check) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() Check() end)
ns.On("PVP_MATCH_ACTIVE", function() Check() end)
ns.On("PVP_MATCH_STATE_CHANGED", function() Check() end)
ns.On("PVP_MATCH_COMPLETE", function(_, winner, duration) Complete(winner, duration) end)
ns.On("UPDATE_BATTLEFIELD_SCORE", function() Gather(false) end)
ns.On("GROUP_ROSTER_UPDATE", function() Gather(false) end)
ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) Unit(unit) end)
ns.On("PLAYER_TARGET_CHANGED", function() Unit("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() Unit("mouseover") end)

ns.Every(ASK_EVERY, function()
    if not Matches.Current() then return end
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    Gather(false)
end)
ns.Every(60, function() Matches.Expire() end)
