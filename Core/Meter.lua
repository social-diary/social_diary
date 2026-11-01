-- The client's damage meter, for whatever reads a fight once it is over:
-- when it can be read, and its sessions and rows, secrets checked at every
-- level on the way. Features read it through here (Features/CloseCalls,
-- Features/Deaths); a new reading is one more Meter.Session with its type.
--
-- The meter is secret in combat, and out of it for as long as the server
-- keeps the session open: through an encounter, and while the group fights
-- on after the user has left the fight or died (as Details! waits for it,
-- core/parser_nocleu1.lua's WaitServerDropCombat). So leaving combat does
-- not make it readable; Meter.Busy says when it is.

local addonName, ns = ...

local Meter = {}
ns.Meter = Meter

local function Table(value)
    value = ns.Plain(value)
    return type(value) == "table" and value or nil
end
Meter.Table = Table

--------------------------------------------------------------------------
-- The sessions
--------------------------------------------------------------------------

-- The highest session id the meter has told of (the update's id is plain
-- in combat), until it is reset: ids can start over then.
local told

ns.On("DAMAGE_METER_COMBAT_SESSION_UPDATED", function(_, _, id)
    id = ns.Plain(id)
    if type(id) == "number" and id > 0 and (not told or id > told) then told = id end
end)

ns.On("DAMAGE_METER_RESET", function()
    told = nil
end)

-- Every session the meter still holds, as a set of ids, and the newest.
local function Sessions()
    local meter = C_DamageMeter
    if not (meter and meter.GetAvailableCombatSessions) then return {}, nil end
    local ok, list = pcall(meter.GetAvailableCombatSessions)
    local ids, newest = {}, nil
    for _, entry in ipairs(ok and Table(list) or {}) do
        entry = Table(entry)
        local id = entry and ns.Plain(entry.sessionID)
        if type(id) == "number" then
            ids[id] = true
            if not newest or id > newest then newest = id end
        end
    end
    return ids, newest
end

-- The newest session's id, as near as can be told: the fight just over's,
-- to read it by later, whatever has started since. Nil if there is none.
function Meter.Pin()
    local _, newest = Sessions()
    if told and (not newest or told > newest) then return told end
    return newest
end

-- The rows of meter type `kind` ("DamageTaken", "HealingDone") in session
-- `id`, or the newest if `id` is nil or gone; and the session's id and the
-- type. Nil while it does not read. A client that lists no sessions gives
-- the current one, its id "current".
function Meter.Session(kind, id)
    local meter, types = C_DamageMeter, Enum and Enum.DamageMeterType
    local which = types and types[kind]
    if not (meter and which) then return nil end
    local ok, session
    if meter.GetAvailableCombatSessions and meter.GetCombatSessionFromID then
        local ids, newest = Sessions()
        if not (id and ids[id]) then id = newest end
        if id then ok, session = pcall(meter.GetCombatSessionFromID, id, which) end
    else
        id = nil
    end
    if not id and meter.GetCombatSessionFromType and Enum.DamageMeterSessionType then
        id = "current"
        ok, session = pcall(meter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, which)
    end
    session = ok and Table(session)
    local sources = session and Table(session.combatSources)
    if not sources then return nil end
    return sources, id, which
end

-- One source's spell rows in a session as Meter.Session gave it. Nil while
-- they do not read.
function Meter.Spells(id, which, guid, creature)
    local meter = C_DamageMeter
    if not meter then return nil end
    local ok, data
    if id == "current" then
        if not meter.GetCombatSessionSourceFromType then return nil end
        ok, data = pcall(meter.GetCombatSessionSourceFromType, Enum.DamageMeterSessionType.Current, which,
            guid, creature)
    else
        if not meter.GetCombatSessionSourceFromID then return nil end
        ok, data = pcall(meter.GetCombatSessionSourceFromID, id, which, guid, creature)
    end
    return ok and Table(data) and Table(Table(data).combatSpells) or nil
end

-- The recap ID the meter keeps for `guid`'s latest death, if it lists them.
function Meter.RecapID(guid)
    local meter = C_DamageMeter
    local types = Enum and Enum.DamageMeterType
    if not (meter and meter.GetCombatSessionFromID and types and types.Deaths) then return nil end
    local best
    for id in pairs((Sessions())) do
        local ok, session = pcall(meter.GetCombatSessionFromID, id, types.Deaths)
        session = ok and Table(session)
        for _, src in ipairs(session and Table(session.combatSources) or {}) do
            src = Table(src)
            local recapID = src and ns.Plain(src.deathRecapID)
            if src and ns.Plain(src.sourceGUID) == guid and type(recapID) == "number"
                and (not best or recapID > best) then
                best = recapID
            end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- When it reads
--------------------------------------------------------------------------

local function Restricted()
    local actions, kinds = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
    if not (actions and actions.GetAddOnRestrictionState and kinds and kinds.Combat) then return false end
    local ok, state = pcall(actions.GetAddOnRestrictionState, kinds.Combat)
    state = ok and ns.Plain(state)
    return type(state) == "number" and state > 0
end

local function InEncounter()
    local encounter = C_InstanceEncounter
    if not (encounter and encounter.IsEncounterInProgress) then return false end
    local ok, on = pcall(encounter.IsEncounterInProgress)
    return ok and ns.Plain(on) == true
end

-- The user dead in a dungeon, their group still fighting.
local function GroupFightsOn()
    if ns.Plain(UnitIsDeadOrGhost("player")) ~= true or not IsInInstance then return false end
    local inside, kind = IsInInstance()
    kind = ns.Plain(kind)
    if ns.Plain(inside) ~= true or not (kind == "party" or kind == "raid") then return false end
    return ns.Units.Each(ns.Units.Group(), function(unit)
        if ns.Plain(UnitExists(unit)) and ns.Plain(UnitAffectingCombat(unit)) == true then return true end
    end) == true
end

-- The server still holds the newest session: its first row is secret.
local function Open()
    local meter, types = C_DamageMeter, Enum and Enum.DamageMeterType
    if not (meter and meter.GetCombatSessionFromID and types and types.DamageTaken) then return false end
    local _, newest = Sessions()
    if not newest then return false end
    local ok, session = pcall(meter.GetCombatSessionFromID, newest, types.DamageTaken)
    if not ok or session == nil then return false end
    if ns.IsSecret(session) or ns.IsSecret(session.combatSources) then return true end
    local first = session.combatSources and session.combatSources[1]
    if first == nil then return false end
    return ns.IsSecret(first) or ns.IsSecret(first.name) or ns.IsSecret(first.totalAmount)
end

-- What keeps the meter from reading now, or nil if nothing does: "combat",
-- "restricted", "encounter", "group", "session".
function Meter.Busy()
    if InCombatLockdown and InCombatLockdown() then return "combat" end
    if Restricted() then return "restricted" end
    if InEncounter() then return "encounter" end
    if GroupFightsOn() then return "group" end
    if Open() then return "session" end
    return nil
end

-- Calls `read` now and then every `opts.every` seconds until it returns
-- true. Only a call made while nothing keeps the meter busy counts, up to
-- `opts.tries` of them; a fight however long costs none, and `opts.deadline`
-- seconds of being busy ends the wait. `opts.gaveUp` is told if it never read.
function Meter.Wait(read, opts)
    local started, tries = ns.Now(), 0
    local function Step()
        if Meter.Busy() then
            if ns.Now() - started >= opts.deadline then
                if opts.gaveUp then opts.gaveUp() end
                return
            end
        else
            if read() then return end
            tries = tries + 1
            if tries >= opts.tries then
                if opts.gaveUp then opts.gaveUp() end
                return
            end
        end
        ns.After(opts.every, Step)
    end
    Step()
end
