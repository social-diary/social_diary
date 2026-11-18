-- Upgrades: the items the character put on and kept wearing. Not what fell
-- into the bags (a first found may be something never worn: that is
-- Features/Firsts/, which this leaves as it is), but what the diary saw
-- arrive and then saw worn for two minutes of play: the player's own
-- verdict that it was worth wearing. A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md; the dossier is
-- .claude/features/upgrades.md):
--
--   Kind.lua     what an upgrade is to the diary: the upgrades kept on the
--                route (j.upgrades), the candidates beside them
--                (j.fitting: seen arriving, not yet worn long enough),
--                their writers and readers, the giver's row, and the
--                recap's two moments (`upgrade`, the one an entry leads
--                with; `piece`, every other one, filler)
--   Capture.lua  the bags, the worn slots and the bank read as they
--                change; how each item came; the two minutes counted
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names an upgrade. Its own names are on
-- ns.Upgrades, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the people's rows, margin notes and marks (a gift that was worn is a
--     row on its giver, and joins their marks);
--   - the item qualities' inks, washes and game colours (ns.Style);
--   - the route's gate (Journey.Kept), its login pruning (Journey.Prune)
--     and forgetting someone (the "journey" store), which ask this list's
--     `prune` and `forget` (Journey.RegisterList);
--   - a few seconds after entering the world (SD_WORLD_SETTLED) and a
--     trade completed (SD_TRADE_COMPLETED), the messages the capture
--     listens to (Core/Events.lua).
--
-- What is Firsts' and not shared: how an item came (the windows, the loot
-- lines, the letter's hooks). The capture here reads them again for
-- itself: a feature never reads another's capture.
--
-- This file: the upgrades and the candidates, their writers and readers,
-- and the moments that put them on the plates.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Upgrades = {}
ns.Upgrades = Upgrades

local Journey = ns.Journey

-- What the user decided (15 Nov), and what follows from it.
Upgrades.T = {
    worn = 120,        -- seconds of play an item is worn before it is an upgrade ("2 min is enough")
    greenOpens = 20,   -- the last level at which a green may still open a plate
    cap = 400,         -- the newest this many upgrades kept a character
}
local T = Upgrades.T

--------------------------------------------------------------------------
-- What an item is
--------------------------------------------------------------------------

-- The client's numbers: Enum.ItemClass.Weapon and its fishing pole; the
-- item qualities from green up.
local WEAPON, FISHING_POLE = 2, 20
local UNCOMMON, RARE = 2, 3

-- What is put in a slot without being gear anyone chose for what it does:
-- a shirt, a tabard, a bag, a quiver, ammunition; and what is not put on
-- at all.
local NOT_GEAR = { [""] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_BODY = true,
    INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true }

-- The worn slots read: head to ranged (1 to 18), without the shirt (4).
-- The tabard (19) and the bag slots after it are not gear.
Upgrades.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

-- An item's key: what it is matched by, in the bags, on the character and
-- in the bank. The item's ID and its random suffix (the link's 7th field
-- after the ID), and its bonus IDs where the client gives any (from the
-- 13th field, their count): never the whole link, which also carries the
-- character's level and an enchant, and so changes while the item does
-- not. Returns the key and the item ID; nil for anything not an item.
function Upgrades.Key(link)
    if type(link) ~= "string" then return nil end
    local fields = link:match("item:([%-%d:]*)")
    if not fields then return nil end
    local f = {}
    for field in (fields .. ":"):gmatch("([^:]*):") do f[#f + 1] = field end
    local id = tonumber(f[1])
    if not id then return nil end
    local key = id .. ":" .. (tonumber(f[7]) or 0)
    for i = 1, tonumber(f[13]) or 0 do key = key .. ":" .. (tonumber(f[13 + i]) or 0) end
    return key, id
end

-- Whether an item could be an upgrade at all: { quality, equipLoc,
-- classID, subclassID }. Green or better (whites do not count: the user,
-- 15 Nov), gear, and no fishing pole.
function Upgrades.Counts(item)
    if type(item.quality) ~= "number" or item.quality < UNCOMMON then return false end
    if type(item.equipLoc) ~= "string" or NOT_GEAR[item.equipLoc] then return false end
    if item.classID == WEAPON and item.subclassID == FISHING_POLE then return false end
    return true
end

-- What kind of thing an item is in its slot: an upgrade is measured only
-- against the last thing of its own kind worn there (the user, 16 Nov: a
-- warrior's tanking shield never "replaces" the off-hand sword, and a
-- first two-hander replaces nothing: "we wait for comparable item types").
-- The hands and the ranged slot hold things of different kinds; every
-- other slot holds one kind (a robe is a chest piece).
local WAND = 19
local HANDS = { INVTYPE_WEAPON = "one-hand", INVTYPE_WEAPONMAINHAND = "one-hand", INVTYPE_WEAPONOFFHAND = "one-hand",
    INVTYPE_2HWEAPON = "two-hand", INVTYPE_SHIELD = "shield", INVTYPE_HOLDABLE = "held" }
local RANGED = { INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "thrown",
    INVTYPE_RELIC = "relic" }
function Upgrades.Kind(item, slot)
    if slot == 16 or slot == 17 then return HANDS[item.equipLoc] or "other" end
    if slot == 18 then
        if item.classID == WEAPON and item.subclassID == WAND then return "wand" end
        return RANGED[item.equipLoc] or "other"
    end
    return "piece"
end

--------------------------------------------------------------------------
-- Upgrades: what was put on and kept on
--------------------------------------------------------------------------
--
-- j.upgrades holds each, oldest first by when it was first put on: { t,
-- mapID, x, y, level, link, key, quality, slot, ilvl, from, guid, found,
-- was }. `t`, the place and `level` are the first put-on's; `link` the
-- item as worn when the two minutes were up; `from` how it came, when that
-- could be told ("loot", "quest", "vendor", "craft", "mail", "trade", and
-- then `guid`, who gave it); `found` when it arrived in the bags; `ilvl`
-- its item level where the client gave one; `was` what it took the place
-- of, { link, ilvl }: the last thing of its kind worn in that slot
-- (Upgrades.Kind; never nil since 16 Nov, an item with nothing of its kind
-- before it is no upgrade). The newest T.cap are kept.
--
-- j.fitting holds the candidates, in the order they arrived: what the
-- diary saw arrive and has not yet seen worn for T.worn seconds. Each
-- { key, link, quality, t, level, from, guid, banked, worn, on }: `t` and
-- `level` when it arrived, `banked` true while it lies in the bank, `worn`
-- the seconds of play it has been on so far, and `on` the first time it
-- was put on, { t, level, slot, kind, mapID, x, y, zone, was, ilvl,
-- wasIlvl }, `was` the link of what it took the place of, the item levels
-- read then (both items have just been in the slot, so the client has
-- them). There is no cap: a candidate goes when the item does
-- (Capture.lua), and a cap would lose the green found at level 10 and
-- worn at 15.
--
-- j.lastWorn holds what an upgrade is measured against: by slot, then by
-- kind (Upgrades.Kind), the link of the last thing of that kind seen worn
-- there that was no candidate (what was had, and every upgrade once it is
-- one). A candidate tried on and taken off again is never the measure, so
-- the next piece is measured against what was worn before the both of
-- them. Kept across sessions: a warrior's sword is still their sword after
-- a week with a two-hander.
--
-- All three are new fields on the route; nothing older is moved or
-- reread, so there is no migration (AGENTS.md).

-- A gift's giver goes as a first's does (Features/Firsts/Kind.lua). At
-- login (Journey.Prune): a giver kept with an upgrade, or with a
-- candidate, whose person has left the diary is a stranger's again once
-- the buffer has let them go. PRV-3 (`forget`): a forgotten giver leaves
-- every record and every candidate, and a gift stays a gift (`from` is
-- kept).
Journey.RegisterList("upgrades", {
    cap = T.cap,
    prune = function(j, now)
        local cutoff = ns.Cutoff(now)
        for _, list in ipairs({ j.upgrades or {}, j.fitting or {} }) do
            for _, rec in ipairs(list) do
                if rec.guid and rec.t < cutoff and not ns.Diary.IsDiary(rec.guid) then rec.guid = nil end
            end
        end
    end,
    forget = function(j, guid)
        for _, list in ipairs({ j.upgrades or {}, j.fitting or {} }) do
            for _, rec in ipairs(list) do
                if guid == nil or rec.guid == guid then rec.guid = nil end
            end
        end
    end,
})

-- A character's upgrades, oldest first.
function Upgrades.List(j)
    return Journey.List(j, "upgrades")
end

-- Whether an item of `key` is an upgrade already: nothing counts twice (a
-- piece sold and bought back, or sent away and back by letter).
function Upgrades.Known(j, key)
    for _, rec in ipairs(j and j.upgrades or {}) do
        if rec.key == key then return true end
    end
    return false
end

-- The candidate of `key`, and its place in j.fitting.
function Upgrades.Candidate(j, key)
    for i, cand in ipairs(j and j.fitting or {}) do
        if cand.key == key then return cand, i end
    end
    return nil
end

-- An item seen arriving: a candidate from now, unless it is one or was an
-- upgrade before. `item` is { key, link, quality }, `rec` { t, level,
-- from, guid }. Returns the candidate made, or nil.
function Upgrades.Arrived(j, item, rec)
    if not (j and item and item.key) then return nil end
    if Upgrades.Known(j, item.key) or Upgrades.Candidate(j, item.key) then return nil end
    rec = rec or {}
    local cand = { key = item.key, link = item.link, quality = item.quality, t = rec.t or ns.Now(),
        level = rec.level, from = rec.from, guid = rec.from == "trade" and ns.SafeGUID(rec.guid) or nil, worn = 0 }
    j.fitting = j.fitting or {}
    j.fitting[#j.fitting + 1] = cand
    return cand
end

-- The candidate of `key` given up: the item is gone, or was put on out of
-- sight.
function Upgrades.Gone(j, key)
    local _, i = Upgrades.Candidate(j, key)
    if i then table.remove(j.fitting, i) end
end

-- The measure in `slot` for something of `kind`: the link of the last
-- thing of that kind worn there (j.lastWorn), or nil.
function Upgrades.Before(j, slot, kind)
    local bySlot = j and j.lastWorn and j.lastWorn[slot]
    return bySlot and bySlot[kind] or nil
end

-- `link`, of `kind`, worn in `slot`, is the measure there from now.
function Upgrades.Saw(j, slot, kind, link)
    if not (j and slot and kind and link) then return end
    j.lastWorn = j.lastWorn or {}
    j.lastWorn[slot] = j.lastWorn[slot] or {}
    j.lastWorn[slot][kind] = link
end

-- The candidate of `key` put on. Only the first time is kept: the moment
-- is when and where it was first put on, whatever is swapped after. `on`
-- is { t, level, slot, kind, was, ilvl, wasIlvl }, `where` in ns.Where's
-- shape (here and now without it is the caller's to give: the candidate
-- is confirmed minutes later, somewhere else).
function Upgrades.PutOn(j, key, on, where)
    local cand = Upgrades.Candidate(j, key)
    if not cand or cand.on then return cand end
    where = where or {}
    cand.on = { t = on.t or ns.Now(), level = on.level, slot = on.slot, kind = on.kind, was = on.was,
        ilvl = on.ilvl, wasIlvl = on.wasIlvl, mapID = where.mapID, x = where.x, y = where.y, zone = where.zone }
    return cand
end

-- `seconds` more of play the candidate of `key` was worn. Returns whether
-- that makes it an upgrade.
function Upgrades.Wore(j, key, seconds)
    local cand = Upgrades.Candidate(j, key)
    if not cand then return false end
    cand.worn = (cand.worn or 0) + math.max(0, seconds or 0)
    return cand.on ~= nil and cand.worn >= T.worn
end

-- The candidate of `key` is an upgrade: kept on the route as of its first
-- put-on, the measure of its kind in its slot from now, and a row on its
-- giver where it was a gift. `read` is what is read only now, { link,
-- ilvl, wasIlvl }: the item as it is worn, and the item levels where they
-- did not read at the put-on. Returns the record.
function Upgrades.Confirm(j, key, read)
    local cand, i = Upgrades.Candidate(j, key)
    if not (cand and cand.on) then return nil end
    table.remove(j.fitting, i)
    read = read or {}
    local on = cand.on
    local where = { mapID = on.mapID, x = on.x, y = on.y, zone = on.zone }
    local rec = Journey.Append(j, "upgrades", { t = on.t, level = on.level, link = read.link or cand.link,
        key = cand.key, quality = cand.quality, slot = on.slot, ilvl = on.ilvl or read.ilvl, from = cand.from,
        guid = cand.guid, found = cand.t,
        was = { link = on.was, ilvl = on.wasIlvl or read.wasIlvl } }, where)
    Upgrades.Saw(j, on.slot, on.kind, rec.link)
    -- Append adds at the end; the list is kept by the first put-on, and a
    -- piece put on earlier may be confirmed later (it was taken off for a
    -- while).
    table.sort(j.upgrades, function(a, b) return a.t < b.t end)
    if rec.guid then
        ns.Interactions.Add(rec.guid, "gift_worn", { time = rec.t, where = where, session = false,
            context = { link = rec.link } })
    end
    return rec
end

--------------------------------------------------------------------------
-- Which one an entry leads with
--------------------------------------------------------------------------

-- How much better than what it replaced, by the one number the client
-- has: its item level over the old one's; nil where either did not read
-- (never "the whole of it": an old item's level the client had lost would
-- make the smallest change the largest). Never shown (the user, 15 Nov:
-- "no ilvl"); it only picks the best.
function Upgrades.Gain(rec)
    local was = rec.was and rec.was.ilvl
    if type(rec.ilvl) ~= "number" or type(was) ~= "number" then return nil end
    return rec.ilvl - was
end

-- Whether an upgrade may open a plate of its own: a blue or better
-- always, a green while the character was level T.greenOpens or below
-- ("green can open plates too but only until level 20").
function Upgrades.Opens(rec)
    if (rec.quality or 0) >= RARE then return true end
    return (rec.level or 0) <= T.greenOpens
end

-- The best of `list`: the largest gain, then the better quality, then the
-- earlier ("prefer the best one (highest diff ilvl)"). A gain that did not
-- read comes after every one that did.
function Upgrades.Best(list)
    local best
    for _, rec in ipairs(list) do
        if not best then
            best = rec
        else
            local a, b = Upgrades.Gain(rec) or -math.huge, Upgrades.Gain(best) or -math.huge
            if a > b or (a == b and ((rec.quality or 0) > (best.quality or 0)
                or ((rec.quality or 0) == (best.quality or 0) and rec.t < best.t))) then
                best = rec
            end
        end
    end
    return best
end

-- An entry's upgrades (those first put on from `a` up to `b`), split as
-- the plates take them: the one it leads with, if it may open a plate,
-- and the rest.
function Upgrades.Split(j, a, b)
    local within = {}
    for _, rec in ipairs(Upgrades.List(j)) do
        if rec.t >= a and rec.t < b then within[#within + 1] = rec end
    end
    local best = Upgrades.Best(within)
    local lead = best and Upgrades.Opens(best) and best or nil
    local pieces = {}
    for _, rec in ipairs(within) do
        if rec ~= lead then pieces[#pieces + 1] = rec end
    end
    return lead, pieces
end

--------------------------------------------------------------------------
-- The giver's row
--------------------------------------------------------------------------

-- A gift that was worn, on its giver's timeline: at the time and place it
-- was first put on. Something the user did with what they gave, not an
-- exchange with them (`observed`: it makes no one "just dealt with"), and
-- a line of its own: "You wore their gift: Wolfskin Bracers". It has no
-- `reason`: an observed row never reaches the picker (Interactions.Since
-- leaves it out), so there is nothing for it to say there.
ns.Rows.Register("gift_worn", { observed = true, moment = function() return true end, icon = "trade",
    text = function(row)
        local link = row.context and row.context.link
        local name = type(link) == "string" and link:match("%[(.-)%]") or nil
        -- "{You}": the character that wore it, where the diary is shared
        -- (UI/Words/Format.lua). Said once: "their gift", not "what they
        -- gave {you}", which would name an alt twice in one line.
        if name then return ns.UI.Format.You(row.me, Fmt(L["{You} wore their gift: %s"], name)) end
        return ns.UI.Format.You(row.me, L["{You} wore their gift"])
    end })

--------------------------------------------------------------------------
-- The recap's moments
--------------------------------------------------------------------------
--
-- Two kinds from the one list, as the hunts' luck and fortune are
-- (Features/Hunts/Kind.lua): the first's `gather` fills both entries, the
-- second's does nothing.
--
-- `upgrade`: the one an entry leads with (Split's). Rank 2, a first
-- found's and a chain's finale's: after the people, before a death. Full:
-- its card goes in the margin. A gift is its giver's moment too and ranks
-- with the people ("session"), as a first someone gave does. Its order
-- (12) puts it straight after the finds (10).
--
-- `piece`: every other one, and the best too where it may not open a
-- plate. Filler ("let others fill an existing open plate low prio"): rank
-- 6.5, a duel's, below a stay (6), so it opens no plate while anything
-- else has one (Recap.Plates' `opens`), and goes onto the plate it fits.
-- Light: one line in the hand is all it has. Its order (75) puts it
-- between the campfires (70) and the duels (80).
--
-- A moment is { kind, t, upgrade = rec, gift, guid, person }, the record
-- under `upgrade` for both kinds.
--
-- The pieces' entry field is e.wornPieces (Upgrades.PIECES), not
-- e.pieces: that name is the recap's own, a level's sittings
-- (Core/JourneyRecap.lua's Recap.Pieces), and a moment gathered into it
-- left no level cut into sittings (16 Nov, found by the UI build).
Upgrades.PIECES = "wornPieces"
local function Moment(kind)
    return function(j, rec, Own)
        local map, x, y = Own(j, rec.mapID, rec.x, rec.y, rec.t)
        local gift = rec.from == "trade" or nil
        return { kind = kind, t = rec.t, upgrade = rec, gift = gift, guid = rec.guid,
            -- Text.lua's, read when the moment is made.
            person = gift and Upgrades.PERSON or nil }, map, x, y
    end
end

-- The moments are registered once their marks are (kinds.lua: a moment
-- needs a mark of its kind): Upgrades.Moments(), called at the foot of
-- Mark.lua.
function Upgrades.Moments()
    ns.JourneyRecap.RegisterMoment("upgrade", { order = 12, entry = "upgrades", field = "upgrade", rank = 2,
        gather = function(j, a, b, e)
            local lead, pieces = Upgrades.Split(j, a, b)
            if lead then e.upgrades[#e.upgrades + 1] = lead end
            local into = e[Upgrades.PIECES]
            for _, rec in ipairs(pieces) do into[#into + 1] = rec end
        end,
        rankAs = function(m) return m.gift and "session" or "upgrade" end,
        moment = Moment("upgrade") })
    -- (keyed as an upgrade, Recap.Key's `keyKind`: the lead turns into a
    -- piece when a better one is put on later in the piece, and a choice on
    -- it holds)
    ns.JourneyRecap.RegisterMoment("piece", { order = 75, entry = Upgrades.PIECES, field = "upgrade", rank = 6.5,
        light = true, keyKind = "upgrade",
        gather = function() end,
        moment = Moment("piece") })
end
