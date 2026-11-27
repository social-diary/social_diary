-- Crafter detection: someone the user meets wears a thing the user made, or
-- the user wears a thing someone they meet gave or sold them. A feature in
-- a folder of its own (.claude/skills/new-feature/folder.md); its design,
-- decisions and probe facts are in .claude/features/crafter-detection.md.
--
--   Kind.lua     what a connection is to the diary: the craft book kept on
--                the route (j.crafter), the connections found (j.craftMeets),
--                the row on the person (`crafted`), and the readers both
--                lists' prune and forget ask
--   Capture.lua  the crafts, the hand-offs (a trade, an auction sale), what
--                the user got and from whom (a trade, an auction bought),
--                the worn slots, meeting people, and the inspect queue
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Stage 1 of two (the user, 27 Nov 2026). The maker's mark ("<Made by
-- Name>") would say who made a thing outright, but in WoW Forever any
-- trade, sale or letter strips it (a client bug; probed 27 Nov: bought
-- crafted gear reads no mark). So this stage keeps its own book of what
-- the user made and who it went to, and of what the user got and from
-- whom, and finds a connection by an item's id:
--   "theirs"  the user made it and handed it to them (a trade, or an
--             auction sale to their name), and an inspect finds it in one of
--             their worn slots. "made them" is honest: the book saw it made.
--   "yours"   they gave it to the user (a trade) or sold it to them (an
--             auction bought from their name), and the user wears it now,
--             when they meet. Never "made": a seller may be a reseller.
-- Stage 2, once the client keeps the mark, reads it instead (the inspect
-- queue's gate opens to everyone; the row's `proof` goes "handoff" to
-- "tag" on the same row, no second toast).
--
-- What stays core, the diary's substrate this feature uses but does not
-- own:
--   - a completed trade and what went each way (SD_TRADE_COMPLETED, fired
--     by Features/Trade, Core/Events.lua);
--   - the toast card and its line (ns.UI.Toast.RegisterKind, SD_TOAST,
--     UI/Windows/Reunion/Queue.lua), the master switch over it;
--   - the route's gate (Journey.Kept), its login pruning and forgetting
--     someone (the "journey" store), which ask these tables' `prune` and
--     `forget` (Journey.RegisterList);
--   - the characters and rows (ns.Characters, ns.Interactions).
--
-- This file: the namespace, the tunables, the row kind and the lists.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local CrafterDetection = {}
ns.CrafterDetection = CrafterDetection

local Journey = ns.Journey

-- The tunables, in seconds unless said.
local T = {
    -- The inspect queue (probe round 3, 27 Nov 2026, in the client: an
    -- inspect answers in 250-315 ms; two asked within a second gave one
    -- late answer after 5.6 s and a burst for others):
    gap = 1.5,          -- at least this between two asks
    timeout = 3,        -- an ask unanswered this long is given up
    again = 2 * 60 * 60,  -- the same person inspected at most this often
                          -- ("at most once every few hours", the scope)
    -- The craft book: at most this many crafts not yet handed on, the
    -- oldest going first (a pair of boots made months ago and never given
    -- away needn't be kept for ever).
    made = 100,
    -- The connections kept on the route for the plates, the newest.
    meets = 200,
}
CrafterDetection.T = T

-- Stage 2's gate (the user, 27 Nov 2026: "Write the final logic, but have
-- it disabled for everyone we can't use like in the hand-off explained, so
-- we don't have to reconstruct it later"). The inspect queue is written
-- for everyone targeted or moused over, as the scope decided; while the
-- maker's mark is stripped by the client, only someone the user handed a
-- craft to can show a find, so only they are inspected. Stage 2 sets this
-- true.
CrafterDetection.INSPECT_EVERYONE = false

-- The two directions.
CrafterDetection.THEIRS, CrafterDetection.YOURS = "theirs", "yours"

--------------------------------------------------------------------------
-- Items
--------------------------------------------------------------------------

function CrafterDetection.ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- The name in a link's brackets: what an auction letter names an item by
-- (in the client's own language, as the letter's).
function CrafterDetection.ItemName(link)
    return type(link) == "string" and link:match("%[(.-)%]") or nil
end

-- Not gear: what has no slot on the character, and what sits in a bag
-- slot rather than being worn (the user, 27 Nov 2026: "anything you
-- currently wear").
local NOT_WORN = { [""] = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_NON_EQUIP_IGNORE = true }

-- Whether the item `id` is worn gear (its slot, from the client's instant
-- item info, which needs no cache).
function CrafterDetection.Wearable(id)
    if not id or not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local equipLoc = select(4, C_Item.GetItemInfoInstant(id))
    equipLoc = ns.Plain(equipLoc)
    return type(equipLoc) == "string" and not NOT_WORN[equipLoc]
end

--------------------------------------------------------------------------
-- The book (j.crafter), written and read by this feature alone
--------------------------------------------------------------------------
--
-- j.crafter = {
--   made   = { [itemGUID] = craft },  what the user made, one an item
--   got    = { [itemID] = got },      gear that came from someone
--   bought = { [key] = bought },      won at auction, until put on
-- }
-- craft:  id, name, link, t (made); once handed: to (GUID) or toName (an
--         auction buyer's name until met), how ("trade" or "auction"),
--         handed (time), letter (the sale letter's key, so a letter read
--         again hands nothing twice); met, once found worn on them; gone,
--         once the person it went to was forgotten (PRV-3: the record
--         stays, never handed again)
-- got:    from (GUID) or fromName (an auction seller's name until met), how,
--         t, link; worn, once seen on the user
-- bought: name (the item's), fromName, t

function CrafterDetection.Book(j)
    if not j then return nil end
    local book = j.crafter
    if not book then
        book = { made = {}, got = {}, bought = {} }
        j.crafter = book
    end
    return book
end

-- A craft still in the user's hands: never handed, never given up.
function CrafterDetection.Unhanded(craft)
    return not craft.to and not craft.toName and not craft.gone
end

-- The book's crafts in the order they were made (oldest first), as a list.
function CrafterDetection.Crafts(book)
    local list = {}
    for key, craft in pairs(book and book.made or {}) do
        list[#list + 1] = craft
        craft.key = key
    end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.key < b.key
    end)
    for _, craft in ipairs(list) do craft.key = nil end
    return list
end

-- PRV-3 and the buffer: a stranger's GUID or name kept past the buffer's
-- days goes, as the route's other marks of strangers do (Journey.Prune);
-- someone in the diary keeps theirs.
local function Stale(guid, t, cutoff)
    return t < cutoff and not (guid and ns.Diary.IsDiary(guid))
end

Journey.RegisterList("crafter", {
    prune = function(j, now)
        local book = j.crafter
        if not book then return end
        local cutoff = ns.Cutoff(now)
        for key, craft in pairs(book.made) do
            local t = craft.handed or craft.t
            if (craft.to or craft.toName) and Stale(craft.to, t, cutoff) then book.made[key] = nil end
        end
        for id, got in pairs(book.got) do
            if Stale(got.from, got.t, cutoff) then book.got[id] = nil end
        end
        for key, bought in pairs(book.bought) do
            if bought.t < cutoff then book.bought[key] = nil end
        end
    end,
    forget = function(j, guid)
        local book = j.crafter
        if not book then return end
        for _, craft in pairs(book.made) do
            if craft.to and (guid == nil or craft.to == guid) then
                craft.to, craft.gone = nil, true
            end
        end
        for id, got in pairs(book.got) do
            if got.from and (guid == nil or got.from == guid) then book.got[id] = nil end
        end
    end,
})

--------------------------------------------------------------------------
-- The connections found (j.craftMeets), for the plates
--------------------------------------------------------------------------
--
-- { t, mapID, x, y, guid, dir, id, link, how }, oldest first, the newest
-- T.meets kept (Journey.Append). The moment that puts them on the plates
-- is registered with its mark (UI build, phase 8).

Journey.RegisterList("craftMeets", {
    cap = T.meets,
    prune = function(j, now)
        local cutoff = ns.Cutoff(now)
        for _, rec in ipairs(j.craftMeets or {}) do
            if rec.guid and Stale(rec.guid, rec.t, cutoff) then rec.guid = nil end
        end
    end,
    forget = function(j, guid)
        for _, rec in ipairs(j.craftMeets or {}) do
            if rec.guid and (guid == nil or rec.guid == guid) then rec.guid = nil end
        end
    end,
})

--------------------------------------------------------------------------
-- The row on the person
--------------------------------------------------------------------------
--
-- context = { dir = "theirs" | "yours", id = itemID, link, how = "trade" |
-- "auction", proof = "handoff" }. One a connection, ever: a row with the
-- same dir and id already on them is the connection found (Connected).

function CrafterDetection.Connected(guid, dir, id)
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        local c = row.type == "crafted" and row.context
        if c and c.dir == dir and c.id == id then return true end
    end
    return false
end

-- The words (copywriter, 27 Nov 2026): "made them" for theirs, "gave you" /
-- "sold you" for yours, never "made" for yours (a seller may be a
-- reseller). How it went (trade, auction) and when are left to tooltips.
-- Past tense, as every row: the line is the meeting the diary saw. "You"
-- is the subject of yours, never with a present verb: Format.You names an
-- alt in a shared diary, and "Thessaly wear" would not do. An item's name
-- takes no pronoun after it (the diary cannot tell "them" from "it"); a
-- row without its link says "what" instead.
ns.Rows.Register("crafted", {
    proximity = true,
    matters = true,
    moment = function() return true end,
    -- One phrase for both directions: one of you wore what the other
    -- handed on.
    reason = L["wore what changed hands between you"],
    text = function(row)
        local c = row.context or {}
        local item = c.link
        if c.dir == CrafterDetection.YOURS then
            if c.how == "auction" then
                return ns.UI.Format.You(row.me, item and Fmt(L["{You} wore the %s they sold {you}"], item)
                    or L["{You} wore what they sold {you}"])
            end
            return ns.UI.Format.You(row.me, item and Fmt(L["{You} wore the %s they gave {you}"], item)
                or L["{You} wore what they gave {you}"])
        end
        return ns.UI.Format.You(row.me, item and Fmt(L["Wore the %s {you} made them"], item)
            or L["Wore what {you} made them"])
    end,
    icon = "crafted",
})
-- Placeholder art until the UI proposal decides it (phase 5b/8).
ns.Style.AddArt("crafted", { "Interface\\Icons\\Trade_BlackSmithing" })
