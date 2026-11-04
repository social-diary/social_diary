-- A hunter's tames: Tame Beast cast, and the pet that came of it.
--
-- What the client says (the pets probe, 4 Nov 2026,
-- .claude/features/hunter-tames.md): Tame Beast (1515) is a channel of
-- about 20 s, the new pet's UNIT_PET at its end, its GUID a "Pet-" one.
-- The quest's rod beasts come as the pet too, but as charmed creatures
-- ("Creature-" GUIDs), never pets, so they are no tame. Call Pet and
-- Revive Pet bring a "Pet-" back as well, which is why the cast is what
-- tells a tame: a cast of Tame Beast arms the watch (Hunter.ARMED), and a
-- pet of the beast's kind coming while it is armed is the tame. The pet
-- GUID changes at every summon; only its creature id holds, and the stable
-- API knows a pet only once the stable master has been visited, so neither
-- tells a new pet from an old one.
--
-- The client names a new pet "Unknown" first and its family a moment
-- later, so the pet is read Hunter.SETTLE after it came. A rename fires
-- nothing the diary hears; the new name is read at the pet's next summon
-- (Hunter.Named, Kind.lua).
--
-- Listening is kept small. A character who is not a hunter registers
-- nothing: the question is asked on SD_WORLD_SETTLED (Core/Events.lua), and
-- the events are taken on or off by the answer. A hunter hears two:
-- UNIT_SPELLCAST_SENT, which the client fires for the player's own casts
-- only (never for others in view, as the cast's SUCCEEDED does), and
-- UNIT_PET, read for "player" alone (it fires for the party's pets too).
-- No UNIT_NAME_UPDATE, which fires for every unit in view.
--
-- Event order. This file is in the TOC's features block, before Capture/:
-- UNIT_SPELLCAST_SENT and UNIT_PET have no other listener anywhere
-- (checked 4 Nov), and on SD_WORLD_SETTLED Firsts and Profession caps read
-- the bags and skills, which nothing here touches. So no order matters.
--
-- Watching is the route's: a tame is kept only while the route is
-- (ns.Journey.Kept: "Keep my own route" on, the logged-in character's own
-- route and not /sd testdata's).

local addonName, ns = ...

local Hunter = ns.Hunter

-- A pet's creature id: Pet-0-server-instance-zone-npcID-spawn. Nil for
-- anything else (a charmed "Creature-" is not a pet).
local function PetNpcID(guid)
    guid = ns.Plain(guid)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^Pet%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

local function Text(value)
    value = ns.Plain(value)
    if type(value) ~= "string" or value == "" then return nil end
    if value == (UNKNOWNOBJECT or "Unknown") or value == (UNKNOWN or "Unknown") then return nil end
    return value
end

local function Number(value)
    value = ns.Plain(value)
    return type(value) == "number" and value or nil
end

-- The tame being cast: { t, npcID (the target's, nil where unread), beast }.
local armed
-- The pet read last, by its GUID, so UNIT_PET's pair is one reading.
local lastGUID

-- The pet as it is now, Hunter.SETTLE after it came; `tame` its cast.
local function Read(guid, tame)
    if ns.Plain(UnitGUID("pet")) ~= guid then return end
    local j = ns.Journey.Kept()
    if not j then return end
    local npcID = PetNpcID(guid)
    local family = Text(UnitCreatureFamily and UnitCreatureFamily("pet"))
    local name = Text(UnitName("pet"))
    if tame then
        local given = name ~= family and name or nil
        local rec = Hunter.Tamed(j, { t = tame.t, level = Number(UnitLevel("player")), npcID = npcID,
            beast = tame.beast or ns.CreatureNames.Of(j, npcID), family = family,
            petLevel = Number(UnitLevel("pet")), name = given })
        if rec then
            ns.Debug("tame: %s (%s), %d in the hour", tostring(rec.beast), tostring(rec.family), rec.n)
            -- Its portrait, from the creature's id (Deaths' reader, at call
            -- time and guarded: folder.md's core helpers).
            if ns.Deaths and ns.Deaths.LookUp then ns.Deaths.LookUp(rec) end
        end
    else
        Hunter.Named(j, npcID, name, family)
    end
end

local function OnSent(_, unit, target, _, spellID)
    if ns.Plain(unit) ~= "player" then return end
    spellID = ns.Plain(spellID)
    if Hunter.TAME_BEAST[spellID] then
        armed = { t = ns.Now(), npcID = ns.NpcID(UnitGUID("target")), beast = Text(target) }
    else
        -- Any other cast (Call Pet among them) after a tame cut short.
        armed = nil
    end
end

local function OnPet(_, unit)
    if ns.Plain(unit) ~= "player" then return end
    local guid = ns.Plain(UnitGUID("pet"))
    local npcID = PetNpcID(guid)
    if not npcID then
        lastGUID = nil
        return
    end
    if guid == lastGUID then return end
    lastGUID = guid
    local tame
    if armed and ns.Now() - armed.t <= Hunter.ARMED and (armed.npcID == nil or armed.npcID == npcID) then
        tame, armed = armed, nil
        tame.t = ns.Now()
    end
    C_Timer.After(Hunter.SETTLE, function() Read(guid, tame) end)
end

local listening = false

local function IsHunter()
    local _, class = UnitClass("player")
    return ns.Plain(class) == "HUNTER"
end

-- On for a hunter, off for anyone else (asked again at every settle: the
-- answer holds for a character, the check costs nothing).
local function Listen()
    local want = IsHunter()
    if want == listening then return end
    listening = want
    if want then
        ns.On("UNIT_SPELLCAST_SENT", OnSent)
        ns.On("UNIT_PET", OnPet)
        -- The pet out at login came before the settle: read it now, for a
        -- name given since its last summon.
        OnPet(nil, "player")
    else
        ns.Off("UNIT_SPELLCAST_SENT", OnSent)
        ns.Off("UNIT_PET", OnPet)
        armed, lastGUID = nil, nil
    end
end

ns.On("SD_WORLD_SETTLED", Listen)

ns._test = ns._test or {}
ns._test.Hunter = function()
    return { armed = armed, listening = listening,
        reset = function() armed, lastGUID = nil, nil end }
end
