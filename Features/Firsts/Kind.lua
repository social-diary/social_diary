-- Firsts found (JRN-24): the first bag, shoulders, green, blue and epic the
-- character found, where and how each came. A feature in a folder of its
-- own (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a first is to the diary: the firsts kept on the
--                route (j.firsts, keyed by kind), their readers, and the
--                recap's moment (`find`; a first someone gave is a gift,
--                which ranks with the people)
--   Text.lua     its words: a first in a sentence, the level's prose, the
--                plates' captions, the tooltips, the card's heading and
--                the line under its item, and a giver's words on their
--                margin note
--   Mark.lua     its mark on the plates (a drawstring pouch, in the
--                item's ink), a gift joining its giver's marks
--   Card.lua     the first found card in the plate's margin, and its note
--   Capture.lua  the bags read as they change, and how each first came
--                (a window open or just closed, a trade just completed)
--   Dev.lua      its part of /sd testdata: the made-up route's five
--                firsts (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a first found. Its own names are on
-- ns.Firsts, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the first sightings (JRN-23: a person first seen, in hindsight) and
--     the first visits (a zone new to the road), the recap's own `first`
--     and `arrive`; they share only the word;
--   - the people's margin notes and marks (a gift from someone in the
--     diary joins them: the mark's `join`, UI/Journey/Plate.lua; and the
--     moment's `person`, which says how it stands among their own
--     moments: UI/Journey/People.lua's Tier, UI/Journey/Text/Margin.lua's
--     MarginWhat);
--   - the item qualities' inks, washes and game colours (ns.Style:
--     QualityInk, QualityNameInk, QualityWash, QualityGameColour), the
--     design system's, which the card and the pouch read;
--   - the route's gate (Journey.Kept), its login pruning (Journey.Prune)
--     and forgetting someone (the "journey" store), which ask this
--     table's `prune` and `forget` (Journey.RegisterList);
--   - a few seconds after entering the world (SD_WORLD_SETTLED) and a
--     trade completed (SD_TRADE_COMPLETED), the messages the capture
--     listens to (Core/Events.lua).
--
-- The route keeps the firsts as a keyed table, not a list (j.firsts,
-- below): written and read by this feature alone, registered with
-- Journey.RegisterList for its `prune` and `forget` only.
--
-- This file: the firsts, their writers and readers, and the moment that
-- puts them on the plates.

local addonName, ns = ...

local Firsts = {}
ns.Firsts = Firsts

local Journey = ns.Journey

--------------------------------------------------------------------------
-- Firsts: the first bag, shoulders, green, blue and epic found
--------------------------------------------------------------------------
--
-- j.firsts[kind] is the record of the first one found, as Capture.lua saw
-- it come into the bags: { t, mapID, x, y, level, link, from, guid }.
-- `from` is how it came, when that could be told: "trade" (and `guid`,
-- who gave it), "mail", "vendor", "quest", "craft" (made, since 20 Oct)
-- or "loot". `false` is a kind the character already had when the diary
-- first looked (D10: nothing before is made up), nil one still to be
-- found. No table at all: the diary has not looked yet.

Firsts.KINDS = { "bag", "shoulder", "uncommon", "rare", "epic" }

-- The client's numbers: Enum.ItemClass.Container, its plain bag, and the
-- item qualities.
local CONTAINER, BAG = 1, 0
local QUALITY = { [2] = "uncommon", [3] = "rare", [4] = "epic" }

-- The kinds an item is a first of: { classID, subclassID, equipLoc,
-- quality }. A green bag is a bag and a green.
function Firsts.Kinds(item)
    local kinds = {}
    if item.classID == CONTAINER and item.subclassID == BAG then kinds[#kinds + 1] = "bag" end
    if item.equipLoc == "INVTYPE_SHOULDER" then kinds[#kinds + 1] = "shoulder" end
    if QUALITY[item.quality] then kinds[#kinds + 1] = QUALITY[item.quality] end
    return kinds
end

-- What the character holds when the diary first looks, or looks again
-- after not watching (a login, capture back on): `held` is a set of
-- kinds. A kind held and not yet found was had out of sight, never a
-- first the diary saw.
function Firsts.Held(j, held)
    if not j then return end
    j.firsts = j.firsts or {}
    for _, kind in ipairs(Firsts.KINDS) do
        if j.firsts[kind] == nil and held[kind] then j.firsts[kind] = false end
    end
end

-- Whether any kind is still to be found.
function Firsts.Looking(j)
    if not (j and j.firsts) then return true end
    for _, kind in ipairs(Firsts.KINDS) do
        if j.firsts[kind] == nil then return true end
    end
    return false
end

-- The first `kind` found, here and now unless `where` says otherwise (in
-- ns.Where's shape; nowhere inside an instance, where the recap places it
-- by time). `rec` is { t, level, link, from, guid }. Only once a kind, and
-- only once the diary has looked (Held).
function Firsts.Found(j, kind, rec, where)
    if not (j and j.firsts) or j.firsts[kind] ~= nil then return nil end
    local spot = Journey.Spot(where)
    local first = { t = rec.t or ns.Now(), mapID = spot.mapID, x = spot.x, y = spot.y, level = rec.level,
        link = rec.link, from = rec.from, guid = rec.from == "trade" and ns.SafeGUID(rec.guid) or nil }
    j.firsts[kind] = first
    Journey.Touch()
    return first
end

-- A character's firsts, each { kind, rec }, oldest first.
function Firsts.List(j)
    local list = {}
    for _, kind in ipairs(Firsts.KINDS) do
        local rec = j and j.firsts and j.firsts[kind]
        if rec then list[#list + 1] = { kind = kind, rec = rec } end
    end
    table.sort(list, function(a, b)
        if a.rec.t ~= b.rec.t then return a.rec.t < b.rec.t end
        return a.kind < b.kind
    end)
    return list
end

-- A gift's giver goes as a fight's does. At login (Journey.Prune, this
-- table's `prune`): a giver kept with a first whose person has left the
-- diary is a stranger's again once the buffer has let them go. PRV-3 (the
-- "journey" store, its `forget`): a forgotten giver leaves every first,
-- and a gift stays a gift (`from` is kept). Not a list: registered for
-- these two alone (no cap; Journey.Append and List are never asked of it).
Journey.RegisterList("firsts", {
    prune = function(j, now)
        local cutoff = ns.Cutoff(now)
        for _, rec in pairs(j.firsts or {}) do
            if rec and rec.guid and rec.t < cutoff and not ns.Diary.IsDiary(rec.guid) then rec.guid = nil end
        end
    end,
    forget = function(j, guid)
        for _, rec in pairs(j.firsts or {}) do
            if rec and (guid == nil or rec.guid == guid) then rec.guid = nil end
        end
    end,
})

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- JRN-24: a first found, where it was found, each { kind, rec } gathered.
-- A gift names the giver while the diary still knows them (the `prune`
-- above), and ranks with the people: as time together with them does
-- (RANK.session, 1, Decision 10), ahead of a death (3). A first found
-- otherwise ranks 2, with a chain's finale: after the people, before a
-- death, a close call and luck. Full: its card goes in the margin. Its
-- order (10) puts it first of the features' moments.
--
-- A gift is its giver's moment too: `guid`, and `person` (Text.lua's
-- Firsts.PERSON, read when the moment is made), how it stands among a
-- person's own moments on their margin note (UI/Journey/People.lua's
-- Tier, UI/Journey/Text/Margin.lua's MarginWhat). Mark.lua's `join` keeps
-- it with the giver's marks where the diary knows them.
ns.JourneyRecap.RegisterMoment("find", { order = 10, entry = "finds", rank = 2,
    gather = function(j, a, b, e)
        for _, f in ipairs(Firsts.List(j)) do
            if f.rec.t >= a and f.rec.t < b then e.finds[#e.finds + 1] = f end
        end
    end,
    rankAs = function(m) return m.gift and "session" or "find" end,
    moment = function(j, f, Own)
        local rec = f.rec
        local map, x, y = Own(j, rec.mapID, rec.x, rec.y, rec.t)
        local gift = rec.from == "trade" or nil
        return { kind = "find", what = f.kind, t = rec.t, find = rec, gift = gift,
            guid = rec.guid, person = gift and Firsts.PERSON or nil }, map, x, y
    end })
