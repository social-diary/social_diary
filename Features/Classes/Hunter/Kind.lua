-- A hunter's moments, the first of a class's features (Features/Classes/,
-- a group folder: .claude/skills/new-feature/folder.md, "Groups"). The one
-- so far: a pet tamed (.claude/features/hunter-tames.md). A feature in a
-- folder of its own:
--
--   Kind.lua     what a tame is to the diary: the route's list of tames,
--                its writers and readers (the recap's moment and its
--                custom card come with the mark, phase 8)
--   Data.lua     the client's numbers: Tame Beast's spell, the window it
--                is armed for, the hour tames merge within
--   Capture.lua  Tame Beast cast, and the pet that comes of it; a rename
--                read at a later summon
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a hunter's tame. Its own names are on
-- ns.Hunter, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the route's gate (Journey.Kept), its spot (Journey.Spot) and list
--     keeping (Journey.RegisterList, Append, List);
--   - creature names read off units (CreatureNames.Of), for a beast whose
--     name the cast did not give;
--   - a few seconds after entering the world (SD_WORLD_SETTLED), when the
--     capture asks whether the character is a hunter at all.
--
-- This file: the tames, and their writers and readers.

local addonName, ns = ...

local Hunter = {}
ns.Hunter = Hunter

local Journey = ns.Journey
local L = ns.L

--------------------------------------------------------------------------
-- Tames: a pet the hunter tamed and kept
--------------------------------------------------------------------------
--
-- j.tames holds each tame, oldest first: { t, mapID, x, y, level, npcID,
-- beast, family, petLevel, name, n }. `t` is when the pet came (the end of
-- Tame Beast's channel), the spot where it was tamed (none inside an
-- instance), `level` the hunter's then. `npcID` is the beast's creature
-- id, from the pet's GUID (its only part that holds from one summon to
-- the next: the probe, 4 Nov). `beast` is the creature's own name ("Prairie
-- Stalker"), `family` the pet's family ("Wolf"), `petLevel` its level
-- then. `name` is the name the hunter gave it, nil until the diary has
-- read one: the client names a new pet after its family, and a rename is
-- read only at the pet's next summon (Capture.lua). `n` counts the tames
-- this one stands for (Hunter.Tamed's hour); kept, never shown (the
-- user's call, 4 Nov). `display` is the creature's display, for the card's
-- portrait, read a moment after the tame from its npcID (ns.Deaths.LookUp,
-- the diary's one creature-display reader: a model set to the pet unit
-- reads 0), nil until then or where it could not be read. No other
-- player's GUID is kept, so the list needs no `forget`. It is registered
-- neither `named` nor `readNames`: `name` is the pet's, not its
-- creature's, and must not lend that creature a name (CreatureNames).
--
-- The newest 50 are kept a character: a hunter tames a few pets in a life,
-- and a tame merges what came within the hour before it.

Journey.RegisterList("tames", { cap = 50 })

-- A tame within this long of the one before stands in for it: the pet the
-- hunter kept is the moment, and the ones tried and let go on the way are
-- not (the user's rule, 4 Nov). Counted from the last tame, so a run of
-- tries an hour apart each is one moment.
Hunter.MERGE = 60 * 60

-- The pet `rec` tamed: { t, level, npcID, beast, family, petLevel, name },
-- here unless `where` says otherwise (ns.Where's shape). Within
-- Hunter.MERGE of the last tame it takes that one's place (`n` counting
-- both), so the list keeps the pet that stayed. Returns the record kept.
function Hunter.Tamed(j, rec, where)
    if not j then return nil end
    local t = rec.t or ns.Now()
    local list = Journey.List(j, "tames")
    local last = list[#list]
    if last and t - last.t >= 0 and t - last.t <= Hunter.MERGE then
        local spot = Journey.Spot(where)
        last.t, last.mapID, last.x, last.y = t, spot.mapID, spot.x, spot.y
        last.level, last.npcID, last.beast = rec.level, rec.npcID, rec.beast
        last.family, last.petLevel, last.name = rec.family, rec.petLevel, rec.name
        -- The earlier beast's portrait goes with it; the new one is looked up.
        last.display = nil
        last.n = (last.n or 1) + 1
        Journey.Touch()
        return last
    end
    return Journey.Append(j, "tames", { t = t, level = rec.level, npcID = rec.npcID, beast = rec.beast,
        family = rec.family, petLevel = rec.petLevel, name = rec.name, n = 1 }, where)
end

-- How long after its tame a pet's name is still taken for the one the
-- hunter gave it: a rename is read only when the pet is next summoned, and
-- a later pet of the same kind, out of the stable, must not lend the tame
-- its name.
Hunter.NAMING = 7 * ns.DAY

-- A name read off the pet now (`npcID` its creature, `family` its
-- family's name): the newest tame's, where it is that creature, still
-- has no name, and was tamed within Hunter.NAMING. A name that is the
-- family's is the client's, not the hunter's. Returns the tame named, or
-- nil.
function Hunter.Named(j, npcID, name, family, now)
    local list = Journey.List(j, "tames")
    local last = list[#list]
    if not (last and npcID and last.npcID == npcID and last.name == nil) then return nil end
    if type(name) ~= "string" or name == "" or name == family or name == last.family then return nil end
    if (now or ns.Now()) - last.t > Hunter.NAMING then return nil end
    last.name = name
    Journey.Touch()
    return last
end

-- A character's tames, oldest first.
function Hunter.List(j)
    return Journey.List(j, "tames")
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- A pet tamed, where it was tamed.
--
-- Rank 1, with the people you were with and a fight (Core/JourneyRecap.lua's
-- RANK): the user's "top weight" (4 Nov). A hunter tames a handful of pets
-- in a life, each one a companion for levels after, so a plate that holds
-- one is the pet's plate before anything below the people. Full, not
-- light: it has its card in the margin (Card.lua). Its order (90) only
-- places it after the other features' kinds when they are gathered.
--
-- Its custom card (Core/Custom.lua's header): a pet tamed before the diary
-- watched, or put right. Offered to hunters only (`offer`), so no other
-- class finds it in the picker; a card already on the route stays
-- editable whoever looks. `creature` is the beast: a creature this
-- character's records know lends the card its npcID and portrait. `n` is
-- not on the form: a card written by the player stands for one tame. The
-- words are the copywriter's (phase 7, 4 Nov).
ns.JourneyRecap.RegisterMoment("tame", { order = 90, list = "tames", field = "tame", rank = 1,
    custom = {
        creature = "beast",
        label = L["Tamed Pet"],
        heading = L["A pet tamed"],
        group = "other",
        offer = function()
            local _, class = UnitClass("player")
            return ns.Plain(class) == "HUNTER"
        end,
        -- A line of a menu, where a spot merges several or one is hidden.
        describe = function(tame) return Hunter.Describe(tame) end,
        fields = {
            { key = "name", type = "text", label = L["Name"], hint = L["the name you gave it, or leave this empty"] },
            { key = "beast", type = "text", label = L["Beast"] },
            { key = "family", type = "text", label = L["Family"], hint = L["Wolf, Cat, Boar…"] },
            { key = "petLevel", type = "number", min = 1, max = 60, label = L["Level"] },
        },
    } })
