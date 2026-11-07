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

local L, Fmt = ns.L, ns.Fmt

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
--
-- The player may change or insert one (Core/Custom.lua), by the item's name
-- and which first it is. `field` is how the core finds the record on a moment,
-- for the custom rank and the right click. An inserted card lives on j.custom
-- and never enters j.firsts, so capture still keeps one first a kind, and a
-- second "first" is the player's to write. Not a gift's giver, this round: a
-- changed gift stays the gift it was, and an inserted card is no gift.
--
-- A detected record does not say which first it is: that is its key in
-- j.firsts, and only a changed one has a `what`. The list keeps its entries
-- { kind, rec }, so an inserted card and a changed one are wrapped to match,
-- and with no box ticked one is simply "find" ("Your first find!"), which every
-- word and mark of this feature already falls back on.

-- A record read with the player's changes, as an entry. A typed name is another
-- item as far as anyone can tell, so the copy lets go of the link: otherwise its
-- tooltip and picture would go on showing the thing the player renamed away from.
-- The saved record keeps it, so Reset gives back the real item.
local function Changed(f, read)
    if read.name and read.name ~= Firsts.ItemName(read.link) then read.link = nil end
    return { kind = read.what or f.kind, rec = read }
end

ns.JourneyRecap.RegisterMoment("find", { order = 10, entry = "finds", field = "find", rank = 2,
    custom = {
        label = L["First Found"],
        heading = L["A first found"],
        group = "other",
        -- A new card has to be a first of something, and most are a green.
        defaults = { what = "uncommon" },
        -- A detected first keeps its item in its link and which first it is as its
        -- key in j.firsts: for the form, nothing written.
        values = function(values, rec)
            values.name = Firsts.Name(rec) or values.name
            local j = Journey.Mine()
            for kind, kept in pairs(j and j.firsts or {}) do
                if kept == rec then values.what = kind end
            end
        end,
        wrap = function(rec) return { kind = rec.what or "find", rec = rec } end,
        timeOf = function(f) return f.rec.t end,
        -- A line of a menu: the item, and which first where the card says.
        describe = function(rec)
            local name = Firsts.Name(rec)
            local _, yours = Firsts.Words(rec.what)
            if name then return rec.what and Fmt(L["%1$s, %2$s"], name, yours) or name end
            return rec.what and ns.UI.JourneyText.Capital(yours) or L["A first found"]
        end,
        fields = {
            -- Saved as `name`, beside a detected record's `link`. The hint tells
            -- what an empty line does: the form cannot show a detected item's
            -- name, which is in its link and not in a field of its own.
            { key = "name", type = "text", label = L["Item"] },
            -- j.firsts' own keys, so a card reads as a detected first does. The
            -- quality's word is the player's colour here, whatever the card's
            -- heading calls it.
            { key = "what", type = "choice", values = { "uncommon", "rare", "epic", "bag", "shoulder" }, label = L["First"],
                names = { uncommon = L["Green"], rare = L["Blue"], epic = L["Purple"], bag = L["Bag"],
                    shoulder = L["Shoulders"] } },
        },
    },
    gather = function(j, a, b, e)
        for _, f in ipairs(Firsts.List(j)) do
            if f.rec.t >= a and f.rec.t < b then
                -- As the player left it. One hidden is off the page, and listed so
                -- it can be brought back, as the core's list branch does in Gather
                -- for a kind it reads itself. One unchanged stays the entry it was.
                local read = ns.Custom.Read(f.rec)
                if not read then
                    e.hidden[#e.hidden + 1] = { kind = "find", rec = f.rec }
                else
                    e.finds[#e.finds + 1] = read == f.rec and f or Changed(f, read)
                end
            end
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
