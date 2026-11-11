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
-- The story: flag lines, your fights, who fell to whom
--------------------------------------------------------------------------
--
-- What the probe showed (rounds 2-4, 10 Nov 2026, Warsong; the dossier's
-- Probe section):
--   flag lines    CHAT_MSG_BG_SYSTEM_* are plain in a match and name the
--                 carrier: "The Horde flag was picked up by First Surname!",
--                 "... dropped by ...", "The Alliance Flag was returned to
--                 its base by ...", "First Surname captured the Horde flag!",
--                 "The flags are now placed at their bases." English only:
--                 the server sends them as text (another client language
--                 simply records no flags, and the page keeps the board).
--   your fights   the damage meter (C_DamageMeter) is open in a match: each
--                 of your fights is a numbered session with its length; per
--                 source a name and class (plain on both sides), enemies
--                 marked by factionGroup / sourceDisplayType 2. Sessions say
--                 nothing of when they were, so a fight is stamped with the
--                 PLAYER_REGEN_ENABLED that ended it.
--   deaths        the meter's deaths (type 9) per session: name, the second
--                 into the session, a deathRecapID; ours all, theirs some.
--                 A recap names the killer only while it is among the newest
--                 ~28, so the fights are walked after each of yours, not
--                 once at the end.
--   near          (unproven, probe round 4) while a flag is out, whether its
--                 carrier is near you: their nameplate, your target or
--                 mouseover, and for ours UnitInRange on their raid unit.
--                 Counted in seconds, kept on the pick-up's line.

local WALK_AFTER = 1.5   -- seconds after your fight ends: its session is listed
local DMG, DEATHS = 0, 9 -- Enum.DamageMeterType's DamageDone and Deaths
local SIDE_ENEMY = 2     -- sourceDisplayType of an enemy source

local function OwnName()
    return Matches.Name(ns.NameFromUnit("player"))
end

local function Sessions()
    if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions) then return {} end
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" or ns.IsSecret(list) then return {} end
    local out = {}
    for _, s in ipairs(list) do
        local okS, id, dur = pcall(function() return s.sessionID, s.durationSeconds end)
        id, dur = okS and P(id), okS and P(dur)
        if type(id) == "number" then out[#out + 1] = { id = id, dur = type(dur) == "number" and dur or 0 } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function Highest()
    local list = Sessions()
    return list[#list] and list[#list].id or 0
end

-- The sources of one session and type, plain parts only.
local function Sources(id, kind)
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, id, kind)
    if not ok or type(session) ~= "table" or ns.IsSecret(session) then return {} end
    local okL, list = pcall(function() return session.combatSources end)
    if not okL or type(list) ~= "table" then return {} end
    local out = {}
    for _, src in ipairs(list) do
        local okS, r = pcall(function()
            return { name = P(src.name), class = P(src.classFilename), me = P(src.isLocalPlayer),
                enemy = P(src.factionGroup) ~= nil or P(src.sourceDisplayType) == SIDE_ENEMY,
                at = P(src.deathTimeSeconds), recap = P(src.deathRecapID) }
        end)
        if okS and r then out[#out + 1] = r end
    end
    return out
end

-- Who dealt a death, by its recap: the overkill event's source name.
local function RecapKiller(recapID)
    if type(recapID) ~= "number" or recapID <= 0 or not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return nil end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents, recapID)
    if not ok or type(events) ~= "table" or ns.IsSecret(events) then return nil end
    local killer
    for _, e in ipairs(events) do
        local okE, overkill, name = pcall(function() return e.overkill, e.sourceName end)
        if okE and type(P(overkill)) == "number" and P(overkill) > 0 then killer = Matches.Name(P(name)) end
    end
    return killer
end

local fightEnds = {}   -- epoch seconds your fights ended, not yet walked

-- Writes every session since the last walk as a fight.
local function Walk(match)
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromID) then return end
    match.meter = match.meter or { from = Highest(), seen = nil }
    local meter = match.meter
    meter.seen = meter.seen or meter.from
    local own = OwnName()
    for _, s in ipairs(Sessions()) do
        if s.id > meter.seen then
            meter.seen = s.id
            local ended = table.remove(fightEnds, 1) or ns.Now()
            local f = { t = Matches.Rel(match, ended - s.dur), dur = s.dur, us = {}, them = {}, deaths = {} }
            for _, src in ipairs(Sources(s.id, DMG)) do
                local name = Matches.Name(src.name)
                if src.class and (name or src.me) then
                    local ref = src.me and "0" or Matches.Ref(match, name, own)
                    if ref then
                        local side = src.enemy and f.them or f.us
                        side[#side + 1] = ref
                    end
                    if name and not src.me then
                        Seen(match, { name = name, class = src.class,
                            side = src.enemy and (match.faction and 1 - match.faction) or match.faction })
                    end
                end
            end
            for _, src in ipairs(Sources(s.id, DEATHS)) do
                local name = Matches.Name(src.name)
                local who = src.me and "0" or Matches.Ref(match, name, own)
                if who then
                    local killer = RecapKiller(src.recap)
                    f.deaths[#f.deaths + 1] = { who = who,
                        at = f.t + (type(src.at) == "number" and src.at or 0),
                        killer = killer and Matches.Ref(match, killer, own) or nil }
                end
            end
            Matches.Fight(match, f)
        end
    end
    wipe(fightEnds)
end
ns._test.MatchWalk = Walk

local function InCombat()
    return P(UnitAffectingCombat and UnitAffectingCombat("player")) == true
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local match = Matches.Current()
    if not match then return end
    fightEnds[#fightEnds + 1] = ns.Now()
    ns.After(WALK_AFTER, function()
        -- In a fight again already: its session is still running, so the
        -- next end walks both.
        if match.state == "open" and not InCombat() then Walk(match) end
    end)
end)

-- Open carries: [flag] = { line, name, ref, unit, near }.
local carries = {}

local function RaidUnit(name)
    for i = 1, (Call(GetNumGroupMembers) or 0) do
        local unit = "raid" .. i
        if Matches.Name(ns.NameFromUnit(unit)) == name then return unit end
    end
end

local function CarryEnd(match, flag)
    local c = carries[flag]
    if not c then return end
    carries[flag] = nil
    if c.line and c.near then Matches.Near(match, c.line, c.near) end
end

local FLAG = { Horde = 0, Alliance = 1 }

-- One flag line, as the client printed it.
local function FlagLine(msg)
    local match = Matches.Current()
    msg = P(msg)
    if not match or type(msg) ~= "string" then return end
    if msg:find("^Let the battle for ") then Matches.Began(match) return end
    local own = OwnName()
    local word, who = msg:match("^The (%a+) [Ff]lag was picked up by (.+)!$")
    if word and FLAG[word] then
        local flag = FLAG[word]
        CarryEnd(match, flag)
        local name = Matches.Name(who)
        local ref = Matches.Ref(match, name, own)
        carries[flag] = { line = Matches.Flag(match, nil, "p", flag, ref), name = name, near = 0,
            me = ref == "0", unit = name and RaidUnit(name) }
        return
    end
    word, who = msg:match("^The (%a+) [Ff]lag was dropped by (.+)!$")
    if word and FLAG[word] then
        CarryEnd(match, FLAG[word])
        Matches.Flag(match, nil, "d", FLAG[word], Matches.Ref(match, Matches.Name(who), own))
        return
    end
    word = msg:match("^The (%a+) [Ff]lag was returned to its base")
    if word and FLAG[word] then
        who = msg:match(" by (.+)!$")
        CarryEnd(match, FLAG[word])
        Matches.Flag(match, nil, "r", FLAG[word], who and Matches.Ref(match, Matches.Name(who), own) or nil)
        return
    end
    who, word = msg:match("^(.+) captured the (%a+) [Ff]lag!$")
    if word and FLAG[word] then
        CarryEnd(match, FLAG[word])
        Matches.Flag(match, nil, "c", FLAG[word], Matches.Ref(match, Matches.Name(who), own))
        return
    end
    if msg:find("placed at their bases", 1, true) then
        for flag in pairs(carries) do CarryEnd(match, flag) end
        Matches.Flag(match, nil, "x")
    end
end
ns._test.MatchFlagLine = FlagLine

-- Is the carrier near you this second?
local function Is(unit, name)
    if not UnitExists(unit) then return false end
    return Matches.Name(ns.NameFromUnit(unit)) == name
end

local function Near(c)
    if Is("target", c.name) or Is("mouseover", c.name) then return true end
    if c.unit and UnitInRange then
        local ok, inRange = pcall(UnitInRange, c.unit)
        if ok and P(inRange) == true then return true end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate.namePlateUnitToken
                if unit and Is(unit, c.name) then return true end
            end
        end
    end
    return false
end

ns.Every(1, function()
    if not next(carries) then return end
    if not Matches.Current() then wipe(carries) return end
    for _, c in pairs(carries) do
        if not c.me and c.name and Near(c) then c.near = c.near + 1 end
    end
end)

for _, event in ipairs({ "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL" }) do
    ns.On(event, function(_, msg) FlagLine(msg) end)
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
    if new then
        ns.Debug("Match opened: %s (%s).", tostring(info.mapName), tostring(info.map))
        -- The meter's sessions so far are the world's; the match's start after.
        if C_DamageMeter then match.meter = { from = Highest() } end
    end
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
    -- The last fight may still be running: it is the match's all the same.
    local okW = pcall(Walk, match)
    if not okW then ns.Debug("The meter could not be read at the end.") end
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
ns.On("PVP_MATCH_STATE_CHANGED", function()
    Check()
    -- The gates open: the moment the state turns Engaged (a record opened
    -- later, by a /reload or a late join, keeps t0 unread; the story then
    -- counts back from the match's own duration).
    local match = Matches.Current()
    local state = Call(C_PvP and C_PvP.GetActiveMatchState)
    if match and Enum and Enum.PvPMatchState and state == Enum.PvPMatchState.Engaged then
        Matches.Began(match)
    end
end)
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
