-- Gathering capture (Kind.lua): the player's own casts of Mining and Herb
-- Gathering, and the node each one took.
--
-- What the client says (and what GatherLite, which draws gathered nodes
-- on the world map, listens for as well): UNIT_SPELLCAST_SENT fires for the
-- player's own casts only, with the target's name (the node's), the cast's
-- id (castGUID) and the spell. The spell says herb or ore: Herb Gathering
-- (2366) and Mining (2575). The same cast then ends in
-- UNIT_SPELLCAST_SUCCEEDED, FAILED or INTERRUPTED, which carry its castGUID
-- (and fire for every unit in view). So:
--
--   sent       a gathering cast: where the player stands is read now (the
--              node is within arm's reach, and the cast is when they are
--              nearest), and the cast's id kept
--   succeeded  that same cast ended well: the node is written down, at the
--              spot read when it began
--   failed     that same cast was cut short (a step, a hit): nothing
--
-- Only SENT is listened to all the time. The three that end a cast fire
-- for every unit in view, so they are taken on when a gathering cast
-- begins and off when it ends (or after GIVE_UP, should none ever come).
--
-- Not in an instance (no map position there), and not when the position
-- is unreadable (a restricted map: a secret is a pause, never a guess).
--
-- Watching is the route's: a node is kept only while the route is
-- (ns.Journey.Kept: "Keep my own route" on, the logged-in character's own
-- route and not /sd testdata's).
--
-- Event order. This file is in the TOC's features block, before Capture/:
-- UNIT_SPELLCAST_SENT has no other listener but the hunter's, which reads
-- the cast and keeps nothing this reads, the three that end a cast have
-- none at all, and SKILL_LINES_CHANGED's other listener (the profession
-- caps) shares nothing with this (checked 12 Nov). So no order matters.

local addonName, ns = ...

local Gathering = ns.Gathering

-- Herb Gathering and Mining, the client's ids.
local SPELLS = { [2366] = "herb", [2575] = "ore" }
Gathering.SPELLS = SPELLS

-- Seconds after which a cast that never ended is given up on. A gather is
-- a few seconds of channel.
local GIVE_UP = 20

-- The cast being watched: { kind, name, where, cast }.
local pending
local watching = false

-- The kind of gathering a spell is, by its id or, for a rank that has its
-- own, by the name it shares with the base spell (the client's own words).
local function KindOf(spellID)
    if SPELLS[spellID] then return SPELLS[spellID] end
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    local name = ns.Plain(C_Spell.GetSpellName(spellID))
    if type(name) ~= "string" or name == "" then return nil end
    for id, kind in pairs(SPELLS) do
        if ns.Plain(C_Spell.GetSpellName(id)) == name then return kind end
    end
    return nil
end

local OnDone, OnLost

-- The cast-ending events, on while a gathering cast is watched.
local function Watch(on)
    if on == watching then return end
    watching = on
    if on then
        ns.On("UNIT_SPELLCAST_SUCCEEDED", OnDone)
        ns.On("UNIT_SPELLCAST_FAILED", OnLost)
        ns.On("UNIT_SPELLCAST_INTERRUPTED", OnLost)
    else
        ns.Off("UNIT_SPELLCAST_SUCCEEDED", OnDone)
        ns.Off("UNIT_SPELLCAST_FAILED", OnLost)
        ns.Off("UNIT_SPELLCAST_INTERRUPTED", OnLost)
    end
end

local function Clear()
    pending = nil
    Watch(false)
end

-- Whether the event is the watched cast ending: the player's, with its id.
local function Mine(unit, castGUID)
    if not pending or ns.Plain(unit) ~= "player" then return false end
    castGUID = ns.Plain(castGUID)
    return type(castGUID) == "string" and castGUID == pending.cast
end

function OnDone(_, unit, castGUID)
    if not Mine(unit, castGUID) then return end
    local p = pending
    Clear()
    local rec = Gathering.Added({ t = ns.Now(), kind = p.kind, name = p.name }, p.where)
    if rec then ns.Debug("gathered %s: %s", p.kind, tostring(p.name)) end
end

function OnLost(_, unit, castGUID)
    if not Mine(unit, castGUID) then return end
    Clear()
end

local function OnSent(_, unit, target, castGUID, spellID)
    if ns.Plain(unit) ~= "player" then return end
    -- A new cast of any kind ends one that never said how it ended.
    Clear()
    spellID, castGUID = ns.Plain(spellID), ns.Plain(castGUID)
    if type(spellID) ~= "number" or type(castGUID) ~= "string" then return end
    local kind = KindOf(spellID)
    if not kind or not ns.Journey.Kept() then return end

    local where = ns.Where()
    if not (where.mapID and where.x and where.y) then return end
    target = ns.Plain(target)
    local name = type(target) == "string" and target ~= "" and target or nil

    local cast = { kind = kind, name = name, where = where, cast = castGUID }
    pending = cast
    Watch(true)
    ns.After(GIVE_UP, function()
        if pending == cast then Clear() end
    end)
end

-- Mining's and Herbalism's skill lines, the client's ids (the same in
-- every language; GatherLite reads them as well).
local SKILL_LINES = { [186] = true, [182] = true }

-- Whether the character has either profession: read off the professions as
-- Profession caps reads them (GetProfessionInfo's seventh value is the
-- skill line). Where the client gives no professions, true: it cannot be
-- told, and a character who gathers must not be left unheard.
local function Gathers()
    if not (GetProfessions and GetProfessionInfo) then return true end
    for _, index in pairs({ GetProfessions() }) do
        if SKILL_LINES[ns.Plain((select(7, GetProfessionInfo(index))))] then return true end
    end
    return false
end

local listening = false

-- On for a character who mines or picks herbs, off for anyone else (asked
-- again at every settle and skill change: the answer holds for a while,
-- the check costs nothing).
local function Listen()
    local want = Gathers()
    if want == listening then return end
    listening = want
    if want then
        ns.On("UNIT_SPELLCAST_SENT", OnSent)
    else
        ns.Off("UNIT_SPELLCAST_SENT", OnSent)
        Clear()
    end
end

ns.On("SD_WORLD_SETTLED", Listen)
ns.On("SKILL_LINES_CHANGED", Listen)

-- For the tests: the cast being watched, and whether the ending events are
-- listened to.
ns._test = ns._test or {}
ns._test.Gathering = function()
    return { pending = pending, watching = watching, listening = listening, reset = Clear }
end
