-- Fishing capture (Kind.lua): the loot window of a catch.
--
-- What the client says (the fishing probe, Dev/FishingProbe.lua, 12 Nov):
-- casting the line fires UNIT_SPELLCAST_SENT, CHANNEL_START and, at once,
-- SUCCEEDED, so a cast says nothing of a fish; the channel ends with
-- CHANNEL_STOP, on a bite as on a line pulled in with nothing. A bite
-- opens the loot: LOOT_READY and LOOT_OPENED, with IsFishingLoot() true and
-- the bobber (a GameObject) as the slot's source, the position readable
-- and the channel already over. Loot from a kill, in the same minute, says
-- IsFishingLoot() false and a Creature as its source. So:
--
--   opened   a loot window that is fishing loot: a catch, written down at
--            the spot the player stands on, with the first item in it
--   closed   the window is shut; LOOT_OPENED while one is still open (a full
--            bag keeps it up, and it can fire again) is the same catch
--
-- The loot is counted when it opens, whether or not the player gets to take
-- it. A second catch within GUARD of the last is the same one.
--
-- Listening is kept small, as the hunter's is. A character without Fishing
-- registers nothing: the question is asked on SD_WORLD_SETTLED and again
-- when the skills change (SKILL_LINES_CHANGED, which the profession caps and
-- Gathering read too: they only read).
--
-- Event order. This file is in the TOC's features block, before Capture/.
-- LOOT_OPENED and LOOT_CLOSED are heard by the hunts' capture (the kills'
-- loot, written to the hunts' counts) and the firsts' (the bags, read when
-- the window closes); this reads only the loot slots and writes only its own
-- list, which neither reads (checked 12 Nov). So no order matters.
--
-- Watching is the route's: a catch is kept only while the route is
-- (ns.Journey.Kept: "Keep my own route" on, the logged-in character's own
-- route and not /sd testdata's).

local addonName, ns = ...

local Fishing = ns.Fishing

-- Seconds within which a second catch is the first again.
local GUARD = 2
-- Seconds after which a loot window never said closed is taken as shut.
local STALE = 120
-- The Fishing profession's skill line, the client's id (GatherLite reads it
-- as well).
local SKILL_LINE = 356
-- A loot slot that holds an item (LOOT_SLOT_ITEM; probe, 12 Nov: a fish is
-- kind 1). Money and currency are others.
local ITEM = 1

local opened   -- when the open loot window opened, nil while none is
local last     -- when the last catch was written

-- The first item the loot holds, by its name as the client says it: from
-- the slot's info, else from its link. nil where there is none.
local function ItemName()
    if not GetNumLootItems then return nil end
    local n = ns.Plain(GetNumLootItems())
    if type(n) ~= "number" then return nil end
    for slot = 1, n do
        local kind = GetLootSlotType and ns.Plain(GetLootSlotType(slot))
        if kind == nil or kind == ITEM then
            local name = GetLootSlotInfo and ns.Plain((select(2, GetLootSlotInfo(slot))))
            if type(name) ~= "string" or name == "" then
                local link = GetLootSlotLink and ns.Plain(GetLootSlotLink(slot))
                name = type(link) == "string" and link:match("%[(.-)%]") or nil
            end
            if type(name) == "string" and name ~= "" then return name end
        end
    end
    return nil
end

local function OnOpened()
    local now = ns.Now()
    if opened and now - opened < STALE then return end
    opened = now
    if not (IsFishingLoot and ns.Plain(IsFishingLoot()) == true) then return end
    if not ns.Journey.Kept() then return end
    if last and now - last < GUARD then return end

    local where = ns.Where()
    -- No position (an instance, a restricted map) is a pause, never a guess.
    if not (where.mapID and where.x and where.y) then return end
    last = now
    local rec = Fishing.Added({ t = now, name = ItemName() }, where)
    if rec then ns.Debug("fished up: %s", tostring(rec.name)) end
end

local function OnClosed()
    opened = nil
end

-- Whether the character has Fishing: read off the professions as Profession
-- caps reads them (GetProfessionInfo's seventh value is the skill line).
-- Where the client gives no professions, true: it cannot be told, and a
-- character who fishes must not be left unheard.
local function Fishes()
    if not (GetProfessions and GetProfessionInfo) then return true end
    for _, index in pairs({ GetProfessions() }) do
        if ns.Plain((select(7, GetProfessionInfo(index)))) == SKILL_LINE then return true end
    end
    return false
end

local listening = false

-- On for a character who fishes, off for anyone else (asked again at every
-- settle and skill change: the answer holds for a while, the check costs
-- nothing).
local function Listen()
    local want = Fishes()
    if want == listening then return end
    listening = want
    if want then
        ns.On("LOOT_OPENED", OnOpened)
        ns.On("LOOT_CLOSED", OnClosed)
    else
        ns.Off("LOOT_OPENED", OnOpened)
        ns.Off("LOOT_CLOSED", OnClosed)
        opened = nil
    end
end

ns.On("SD_WORLD_SETTLED", Listen)
ns.On("SKILL_LINES_CHANGED", Listen)

-- For the tests: whether the loot events are listened to.
ns._test = ns._test or {}
ns._test.Fishing = function()
    return { listening = listening, opened = opened, reset = function() opened, last = nil, nil end }
end
