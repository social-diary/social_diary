-- Crafter detection: someone the user meets wears a thing the user made, or
-- the user wears a thing someone they meet gave or sold them. A feature in
-- a folder of its own (.claude/skills/new-feature/folder.md); its design,
-- decisions and probe facts are in .claude/features/crafter-detection.md.
--
--   Kind.lua     what a connection is to the diary: the craft book kept on
--                the route (j.crafter), the connections found (j.craftMeets),
--                the row on the person (`crafted`), and the readers both
--                lists' prune and forget ask
--   Text.lua     the words (CrafterDetection.WORDS), the tooltips, the
--                person's phrase, the caption's tail and the level's prose
--   Mark.lua     the needle and thread on the plates
--   Card.lua     the card in the plate's margin (the hand-off drawn)
--   Toast.lua    the toast card's kind ("crafter")
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
    -- The whole craft book: in hand, handed and waiting, found, given up.
    -- Past this the oldest handed ones go first (by when they were handed),
    -- and only then any in hand: a crafter who sells for years keeps the
    -- last few hundred hand-offs, not every one.
    book = 400,
    -- Auction wins kept by name (gear until it is put on, consumables for
    -- whom they came from): the newest this many, each for the buffer's
    -- days at most.
    bought = 200,
    -- The connections kept on the route for the plates, the newest.
    meets = 200,
    -- A sale letter's key is kept this long after it handed a craft: an
    -- auction's letter stays in the inbox up to 30 days, and is read again
    -- at every update until then.
    letters = 31 * ns.DAY,
    -- The user is a crafter (and the craft side runs: crafts booked,
    -- hand-offs, the inspect queue) once a profession that makes gear is
    -- past this rank (the user, 28 Nov 2026: skip a profession only just
    -- learned, at 1).
    rank = 3,
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

-- What an auction win is to the book, by the item's id, link or name (a
-- buyer's letter names it only): "gear" (worn: it may become a got once put
-- on), "consumable" (the user, 28 Nov 2026: who sold the user what they
-- drink and eat is worth keeping), or nil for anything else (reagents,
-- trade goods, recipes, bags: nothing the diary tells). "unknown" where the
-- client has no instant info for a name (not in its cache): kept, the cap
-- holds it, and the next prune asks again.
local CONSUMABLE = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0

function CrafterDetection.Use(item)
    if not item or not (C_Item and C_Item.GetItemInfoInstant) then return "unknown" end
    local id, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(item)
    id, equipLoc, classID = ns.Plain(id), ns.Plain(equipLoc), ns.Plain(classID)
    if not id then return "unknown" end
    if type(equipLoc) == "string" and not NOT_WORN[equipLoc] then return "gear" end
    if classID == CONSUMABLE then return "consumable" end
    return nil
end

--------------------------------------------------------------------------
-- The book (j.crafter), written and read by this feature alone
--------------------------------------------------------------------------
--
-- j.crafter = {
--   made   = { [itemGUID] = craft },  what the user made, one an item
--   got    = { [itemID] = got },      gear that came from someone
--   bought = { [key] = bought },      won at auction, until put on
--   letters = { [hash] = t },         sale letters that handed a craft
-- }
-- craft:  id, name, link, t (made); once handed: to (GUID) or toName (an
--         auction buyer's name until met), how ("trade" or "auction"),
--         handed (time); met, once found worn on them; gone,
--         once the person it went to was forgotten (PRV-3: the record
--         stays, never handed again)
-- got:    from (GUID) or fromName (an auction seller's name until met), how,
--         t, link; worn, once seen on the user; met, once the connection
--         was made (not watched for again)
-- bought: name (the item's), fromName, t, use ("gear", "consumable" or
--         "unknown": CrafterDetection.Use); a gear one becomes a got once
--         worn, a consumable one stays for whom it came from
-- letters: a sale letter read again hands nothing twice. Kept apart from
--         the crafts, which the buffer's days may prune while the letter
--         is still in the inbox, and by a hash of the letter (item, buyer,
--         bid), so no buyer's name is kept in it.

function CrafterDetection.Book(j)
    if not j then return nil end
    local book = j.crafter
    if not book then
        book = { made = {}, got = {}, bought = {}, letters = {} }
        j.crafter = book
    end
    if not book.letters then
        -- A book from before the letters had their own table (never
        -- released; the dev round's): each craft kept its letter's key.
        book.letters = {}
        for _, craft in pairs(book.made) do
            if craft.letter then
                book.letters[CrafterDetection.LetterKey(craft.letter)] = craft.handed or craft.t
                craft.letter = nil
            end
        end
    end
    return book
end

-- A sale letter's key: a hash of what tells it apart (the item's name, the
-- buyer's, the bid), never the name itself.
function CrafterDetection.LetterKey(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return h
end

-- A craft still in the user's hands: never handed, never given up.
function CrafterDetection.Unhanded(craft)
    return not craft.to and not craft.toName and not craft.gone
end

-- The crafts still in the user's hands, oldest first, as { key, craft }
-- (the saved tables are not written to sort them).
local function Older(a, b)
    if a.craft.t ~= b.craft.t then return a.craft.t < b.craft.t end
    return a.key < b.key
end

function CrafterDetection.InHand(book)
    local list = {}
    for key, craft in pairs(book and book.made or {}) do
        if CrafterDetection.Unhanded(craft) then list[#list + 1] = { key = key, craft = craft } end
    end
    table.sort(list, Older)
    return list
end

-- PRV-3 and the buffer: a stranger's GUID or name kept past the buffer's
-- days goes, as the route's other marks of strangers do (Journey.Prune);
-- someone in the diary keeps theirs.
local function Stale(guid, t, cutoff)
    return t < cutoff and not (guid and ns.Diary.IsDiary(guid))
end

-- The oldest of `tbl`'s entries past `cap` go, oldest by `When(entry)`,
-- and among those only where `May(entry)` (all where nil).
local function Trim(tbl, cap, When, May)
    local list = {}
    for key, entry in pairs(tbl) do
        if not May or May(entry) then list[#list + 1] = { key = key, t = When(entry) or 0 } end
    end
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    if n <= cap then return end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return tostring(a.key) < tostring(b.key)
    end)
    for i = 1, math.min(#list, n - cap) do tbl[list[i].key] = nil end
end
CrafterDetection.Trim = Trim

local function Handed(craft) return craft.handed or craft.t end
local function NotInHand(craft) return not CrafterDetection.Unhanded(craft) end

-- The book within bounds (the login prune, and Capture after each write
-- that may grow it). What goes, each for a reason of its own:
--   made    a stranger's hand-off past the buffer's days (PRV-3); one found
--           on them (`met`: the row and j.craftMeets tell it now) or given
--           up (`gone`: its person forgotten) past the buffer's days,
--           whoever it went to; then the oldest past T.book, handed ones
--           first. One still waited on for someone in the diary stays
--           within the cap however old.
--   got     a stranger's past the buffer's days; one never put on by then,
--           anyone's (Worn lets go of one taken off).
--   bought  past the buffer's days; anything not gear or a consumable
--           (an "unknown" asked again); the oldest past T.bought.
function CrafterDetection.Tidy(book, now)
    if not book then return end
    local cutoff = ns.Cutoff(now)
    for key, craft in pairs(book.made) do
        local t = Handed(craft)
        if (craft.to or craft.toName) and Stale(craft.to, t, cutoff) then
            book.made[key] = nil
        elseif (craft.met or craft.gone) and (craft.met or t) < cutoff then
            book.made[key] = nil
        end
    end
    Trim(book.made, T.book, Handed, NotInHand)
    Trim(book.made, T.book, Handed)
    for id, got in pairs(book.got) do
        if Stale(got.from, got.t, cutoff) or (not got.worn and got.t < cutoff) then book.got[id] = nil end
    end
    for key, bought in pairs(book.bought) do
        if bought.use == "unknown" or bought.use == nil then bought.use = CrafterDetection.Use(bought.name) end
        if bought.t < cutoff or not bought.use then book.bought[key] = nil end
    end
    Trim(book.bought, T.bought, function(b) return b.t end)
end

Journey.RegisterList("crafter", {
    prune = function(j, now)
        local book = j.crafter
        if not book then return end
        CrafterDetection.Tidy(book, now)
        for key, t in pairs(book.letters or {}) do
            if t < now - T.letters then book.letters[key] = nil end
        end
    end,
    forget = function(j, guid)
        local book = j.crafter
        if not book then return end
        for _, craft in pairs(book.made) do
            -- Everyone (nil): a name not yet met goes too.
            if (craft.to and (guid == nil or craft.to == guid)) or (guid == nil and craft.toName) then
                craft.to, craft.toName, craft.gone = nil, nil, true
            end
        end
        for id, got in pairs(book.got) do
            if (got.from and (guid == nil or got.from == guid)) or (guid == nil and got.fromName) then
                book.got[id] = nil
            end
        end
        if guid == nil then wipe(book.bought) end
    end,
})

--------------------------------------------------------------------------
-- The connections found (j.craftMeets), for the plates
--------------------------------------------------------------------------
--
-- { t, mapID, x, y, guid, dir, id, link, how }, oldest first, the newest
-- T.meets kept (Journey.Append). The moment that puts them on the plates
-- is at the foot of this file.

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
    -- The trade's own art (the signed proposal: a hand-off is an exchange,
    -- and the timeline already draws one so), no art of its own.
    icon = "trade",
})

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------
--
-- A connection where it was found, on Your Diary's plates (the signed
-- proposal, .claude/ui-proposal/crafter-detection.md; the user, 27 Nov
-- 2026: "weight 7/10", it opens a plate). Rank 3.5: under a death, a close
-- call, luck and a witness (3), over a first visit (4), a dungeon's door
-- (5), a campfire (5.5), a city trip (5.6) and a stay (6). Full, never
-- light: its card goes in the margin. In a city it is a plate of its own,
-- as anywhere, and offers the city trip's sheet no errand (the user: the
-- trip keeps its sheet). Its order (65) puts it after the profession caps
-- (60) and before the campfires (70) among the features' moments.
--
-- A connection is its person's moment too (`guid`, and `person`, Text.lua's
-- CrafterDetection.PERSON, read when the moment is made, as a first someone
-- gave is): Mark.lua's `join` keeps it with their marks where the diary
-- knows them, so their margin note says it once. A stranger's stays its
-- own. A record whose person was forgotten (PRV-3: `guid` cleared) keeps
-- its needle and names nobody.
--
-- Its key tells two connections at one time apart by who and which item
-- (a GUID and an item's id, never a name).
ns.JourneyRecap.RegisterMoment("crafted", { order = 65, list = "craftMeets", field = "meet", rank = 3.5,
    key = function(m)
        local rec = m.meet or {}
        return tostring(rec.guid or "") .. "/" .. tostring(rec.id or "")
    end,
    moment = function(j, rec, Own)
        local map, x, y = Own(j, rec.mapID, rec.x, rec.y, rec.t)
        return { kind = "crafted", t = rec.t, meet = rec, guid = rec.guid,
            person = rec.guid and CrafterDetection.PERSON or nil }, map, x, y
    end })
