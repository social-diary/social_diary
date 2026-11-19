-- The free card in the plate's margin (.claude/features/note-card.md, phase
-- 3; the kind is Kind.lua's). The killer card (Features/Deaths/Card.lua,
-- ns.Deaths.Card) worn with a face of its own, as the close call wears one:
-- the same slip, tape, paper, ink and hand as every automatic card beside it,
-- the same creature picture ladder (the silhouette in ink, the print, the
-- name alone), the same pool (page.killerPool). Custom cards look the same as
-- automatic ones (custom-cards.md, the user's, 1 Nov): nothing on it says the
-- player wrote it.
--
-- Down the slip:
--   the band     over the name, as the close call's heading and picture:
--                the chosen icon (ns.NoteIcons, painted at card size), and
--                beside it, where the card names a creature and someone
--                else is its heading, the creature (its picture where the
--                records know its display, as the close call's card has
--                it) and its name in small strong ink
--   the name     the heading, in the hand: who was there ("with Old Tom and
--                Wenna", the people's strip's own words), else the creature,
--                else the icon's name ("Treasure"). With someone linked it
--                opens their page as an automatic strip's name does; with
--                several linked, a click asks whose (a menu, the pad's slip
--                with the pad: one generator, so the two never drift)
--   the item     under the name, boxed as the first found card boxes its
--                item (UI/Paper/ItemBox.lua), its own tooltip under the mouse
--   the words    the player's own, quoted in their hand (the strip's
--                `quote`, as a person's strip quotes the note written about
--                them: their words, not the diary's), cut at a word with an
--                ellipsis where the card has no more lines
--   the creature's name, under it all in small ink, where the band had no
--                room for it
-- The tooltip carries everything (Text.lua's Note.Tip), whatever the card
-- had room for. A right click opens the form (the margin's `custom`).
--
-- Sizes (the plates' bands, by the column the card is laid in; FREE.bands):
--   XL (190 and up)  icon 30, the creature's picture 50 x 34, three lines
--   L  (150 to 189)  icon 26, picture 44 x 30, three lines
--   M  (under 150)   icon 22, no picture (its name only), two lines
--   S                what the margin's `smaller` leaves when the column has
--                    no more height: the heading alone, the mark carrying
--                    the icon
-- Short of height (the margin asks `smaller`), it gives up, in this order:
-- the picture (drawn small first: the killer card's `again`), its words to
-- two lines, the item's box, its words to one line, the creature's name,
-- the band with the icon, the words. Then it is left off, its mark and
-- tooltip kept, as every card's.

local addonName, ns = ...

local Style = ns.Style
local Note = ns.Note
local L = ns.L

-- The card's look:
--   bands    the column widths from which a card is XL, L (else M)
--   icon     the icon's size by band, px
--   picture  the creature's picture by band (none at M); `compact`, drawn
--            small where the card stood taller than the margin's room
--   gap      across the band: icon to picture to the creature's name
--   band     under the band, over the name (`gap`)
--   lines    the player's words by band, lines at most
--   item     the box's room under the name (`gap` under the name, `after`
--            over the words) and its lean against the slip's (degrees)
--   tapeAt   the tape's middle, a share of the slip's width: right of the
--            icon and picture, as the killer card's is right of its picture
--   under    the creature's name lies in the band, under the tape's foot,
--            where the band stands this many px over and under its letters
--   turn     the slip's turn at most, degrees (a model cannot turn with it)
-- (19 Nov, the design: an icon left of the name would indent every line
-- under it, as the strip lays them; over the name, where the killer card has
-- its picture, it is a vignette heading the note, and the creature can sit
-- beside it. Measured in the mock at 220/176/142/122: 143, 156, 134, 141 px
-- tall with everything on it; not yet seen in the client.)
local FREE = {
    bands = { xl = 190, l = 150 },
    icon = { xl = 30, l = 26, m = 22 },
    picture = { xl = { w = 50, h = 34 }, l = { w = 44, h = 30 } }, compact = { w = 36, h = 24 },
    gap = 6, band = { gap = 3 },
    lines = { xl = 3, l = 3, m = 2 },
    item = { gap = 4, after = 3, lean = { least = 1.2, most = 2.4 } },
    tapeAt = 0.84, turn = 1.2, under = 6,
}

local Card = {}
Note.Card = Card
Card.FREE = FREE

local Width = ns.UI.Surface.Width
local ItemBox = ns.UI.ItemBox

--------------------------------------------------------------------------
-- What the card says
--------------------------------------------------------------------------

local function Mob(rec)
    return type(rec.mob) == "string" and rec.mob ~= "" and rec.mob or nil
end

local function ItemName(rec)
    return type(rec.item) == "string" and rec.item ~= "" and rec.item or nil
end

-- The people on the card the diary still knows, each once: who a click
-- may open.
function Card.Linked(rec)
    local list, seen = {}, {}
    for _, p in ipairs(Note.People(rec)) do
        local guid = Note.Guid(p)
        if guid and not seen[guid] then
            seen[guid] = true
            list[#list + 1] = guid
        end
    end
    return list
end

-- The heading's words, the longest first, each { words, from }: who was
-- there, all named, then the first and a count of the rest, then the first
-- alone ("with someone" for a meeting with nobody named, Note.Names); else
-- the creature; else, or where the creature's name is too long for the
-- column ("Razormane Battleguard" in 122 px), the icon's name, "A meeting",
-- "A note" for the quill (Note.IconName). A creature not heading the card
-- is in its band, or under its words.
local function Headings(rec)
    local names = Note.Names(rec)
    if names[1] then
        local out = { { ns.Fmt(L["with %s"], ns.UI.Format.List(names)), "people" } }
        if #names > 1 then
            out[2] = { ns.Fmt(L["with %s"], ns.UI.Format.List(names, { max = 1, shown = 1, more = ns.UI.Format.OTHERS })),
                "people" }
            -- (the first alone last: the rest are in the tooltip, as a
            -- name too long for a strip's column is)
            out[3] = { ns.Fmt(L["with %s"], names[1]), "people" }
        end
        return out
    end
    local icon = { Note.IconName(rec), "icon" }
    if Mob(rec) then return { { Mob(rec), "mob" }, icon } end
    return { icon }
end
Card.Headings = Headings

-- The player's words on one line each way: the line breaks they wrote
-- are only the form's, the slip wraps them its own way.
local function Words(rec)
    local text = type(rec.text) == "string" and rec.text:gsub("%s*\n%s*", " ") or ""
    return text ~= "" and text or nil
end

-- A click on the name with several people linked: whose page. One
-- generator for the mouse's menu and the pad's (Pad.Menu), so they cannot
-- drift (the controller-support skill's rule 6).
function Card.Generator(linked, open)
    return function(_, root)
        root:CreateTitle(L["Whose page?"])
        for _, guid in ipairs(linked) do
            root:CreateButton(ns.UI.JourneyText.Short(guid) or "?", function() open(guid) end)
        end
    end
end

--------------------------------------------------------------------------
-- The face on the killer card
--------------------------------------------------------------------------

-- What the face draws on the card, made when first wanted (card.freeBits):
-- the icon's kit (its pools on the slip, laid with it), the creature's name,
-- the item's box.
local function Bits(card)
    if card.freeBits then return card.freeBits end
    local bits = {}
    bits.kit = ns.UI.JourneyPlate.MarkKit(card,
        function(region, x, y, w, h, turn) card:Lay(region, x, y, w, h, turn) end,
        function(region, ...) return card:Bend(region, ...) end, card:Paper())
    bits.mob = Style.Text(card, Style.FONT.small)
    bits.mob:Hide()
    bits.measure = Style.Text(card, Style.FONT.small)
    bits.measure:Hide()
    bits.hand = Style.Text(card, Style.FONT.noteWritten)
    bits.hand:Hide()
    bits.box = ItemBox.New(card, card:GetParent())
    function bits.box.enter(button)
        bits.box:Hot(true)
        Card.ShowItem(button, card.freeRec)
    end
    function bits.box.leave()
        bits.box:Hot(false)
        GameTooltip:Hide()
    end
    card.freeBits = bits
    return bits
end

-- The item's own tooltip, from its ID (as a link, as the first found card
-- shows its item), else its name.
function Card.ShowItem(owner, rec)
    if not rec then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local link = rec.itemID and ("item:" .. rec.itemID) or nil
    local shown = link and type(GameTooltip.SetHyperlink) == "function"
        and pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if not shown then GameTooltip:SetText(ItemName(rec) or "?") end
    GameTooltip:Show()
end

-- The heading that fits `room` in the hand, at its size or the smaller:
-- the first of Headings' that does, else the shortest (the card is then
-- overfull, and left off).
local function Heading(card, rec, room)
    local bits = Bits(card)
    local list = Headings(rec)
    local KILLER = ns.Deaths.Card.KILLER
    for _, h in ipairs(list) do
        for _, size in ipairs({ 0, KILLER.small }) do
            bits.hand:SetFontObject(Style.FONT.noteWritten)
            if size > 0 then bits.hand:SetFont(Style.NEUTON_ITALIC, size, "") end
            bits.hand:SetText(h[1])
            if Width(bits.hand) <= room then return h[1], h[2] end
        end
    end
    return list[#list][1], list[#list][2]
end

local function Band(width)
    return width >= FREE.bands.xl and "xl" or width >= FREE.bands.l and "l" or "m"
end

-- What the card will show at this width, after what it has given up
-- (card.freeGive): the plan its `top` and `under` draw.
local function Plan(card, note, width, room, Least)
    local rec, give = card.freeRec, card.freeGive
    local bits = Bits(card)
    local band = Band(width)
    card.freeSize = band
    local heading, from = Heading(card, rec, room)
    note.name = heading
    card.freeFrom = from

    -- The band: the icon, the creature's picture and name beside it.
    local plan = { band = band }
    local mob = Mob(rec)
    local mobInBand = mob and from ~= "mob" and not give.mob
    if not give.band then
        local size = FREE.icon[band]
        local pic = card.mode ~= "name" and FREE.picture[band] or nil
        if pic and card.compact then pic = FREE.compact end
        local w, h = size, size
        if pic then
            w, h = w + FREE.gap + pic.w, math.max(h, pic.h)
        end
        local mobW
        if mobInBand then
            bits.measure:SetText(mob)
            mobW = Width(bits.measure) + 2
            -- (the tape stays clear of the icon and the picture, which
            -- reach the band's top, as the killer's of its picture; the
            -- name, in the band's middle, lies under the tape's foot where
            -- the band is at least `under` px taller than its letters each
            -- side. Else, or past the column, it goes under the words.)
            if w + FREE.gap + mobW > room
                or ((h - 14) / 2 < FREE.under and Least(w + FREE.gap + mobW, FREE.tapeAt) > width) then
                mobW = nil
            else
                w = w + FREE.gap + mobW
            end
        end
        plan.icon, plan.pic, plan.mobW, plan.w, plan.h = size, pic, mobW, w, h
        note.picture = { w = w, h = h, gap = FREE.band.gap }
        note.least = Least(size + (pic and FREE.gap + pic.w or 0), FREE.tapeAt)
    else
        note.picture = nil
        note.least = nil
    end
    note.tapeAt = FREE.tapeAt

    -- The item, boxed under the name.
    note.under = nil
    local item = ItemName(rec)
    if item and not give.item then
        local icon = rec.itemID and ItemBox.Icon("item:" .. rec.itemID) or nil
        local chip = bits.box:Measure(item, room, { icon = icon ~= nil, column = width,
            seed = "free:" .. tostring(rec.t) .. item, lean = FREE.item.lean })
        if chip then
            plan.chip, plan.itemIcon = chip, icon
            plan.quality = rec.itemID and ItemBox.Quality("item:" .. rec.itemID) or 1
            note.under = { w = chip.bw, h = chip.bh, gap = FREE.item.gap, after = FREE.item.after }
        end
    end

    -- The creature's name under it all, where the band had no room for it.
    note.what = (mob and from ~= "mob" and not give.mob and not plan.mobW) and mob or ""
    return plan
end

-- The band, drawn in the room the strip kept over the name (card.picture as
-- laid): the icon at its left, then the creature's picture's room (the card
-- draws the picture in card.picture after this: the killer card's ladder),
-- then its name.
local function Top(card, plan)
    local bits = Bits(card)
    local room = card.picture
    local kit = bits.kit
    kit.P = card:Paper()
    kit:Begin()
    bits.mob:Hide()
    card.freeIcon = nil
    if not (room and plan.icon) then
        kit:Finish()
        card.picture = nil
        return
    end
    local left, mid = room.lx - room.w / 2, room.ly
    local icons = ns.NoteIcons
    local ix = left + plan.icon / 2
    if icons then icons.Draw(kit, card.freeRec.icon, ix, mid, plan.icon) end
    kit:Finish()
    -- For the tests: the icon drawn, its key and size, from the slip's middle.
    card.freeIcon = { key = icons and icons.Known(card.freeRec.icon), x = ix, y = mid, size = plan.icon }
    local x = left + plan.icon + FREE.gap
    card.picture = nil
    if plan.pic then
        local lx = x + plan.pic.w / 2
        local X, Y = card:Screen(lx, mid)
        local px, py = card:Out(lx, mid)
        card.picture = { lx = lx, ly = mid, w = plan.pic.w, h = plan.pic.h, X = X, Y = Y, x = px, y = py }
        x = x + plan.pic.w + FREE.gap
    end
    if plan.mobW then
        local S = Style.INK_STRONG
        bits.mob:SetText(Mob(card.freeRec))
        bits.mob:SetTextColor(S[1], S[2], S[3])
        card:Lay(bits.mob, x + plan.mobW / 2, mid, plan.mobW, 14)
        bits.mob:Show()
    end
end

-- The item's box, in the room under the name (card.under as laid).
local function Under(card, plan)
    local bits = Bits(card)
    local room = card.under
    if not (plan.chip and room) then
        bits.box:Hide()
        return
    end
    local chip = plan.chip
    bits.box:Draw(chip, room.lx - room.w / 2 + chip.bw / 2, room.ly, { quality = plan.quality, icon = plan.itemIcon })
end

-- The note the strip lays: its heading set in Plan, the player's words
-- quoted at `lines` lines.
local function NoteOf(card, seed, now)
    local rec = card.freeRec
    local linked = Card.Linked(rec)
    local first = linked[1]
    local stranger = first ~= nil and not ns.Diary.IsDiary(first)
    local words = Words(rec)
    local give = card.freeGive
    return {
        name = Headings(rec)[1][1], what = "", strong = true, guid = first, plain = stranger,
        rival = ns.UI.YourDiary.Rival(first), seed = seed, turn = FREE.turn, tapeAt = FREE.tapeAt,
        quote = (not give.words) and words or nil, quoteLines = give.lines or FREE.lines.xl,
        onClick = function(guid)
            if #linked < 2 then return card.freeOpen(guid) end
            local generator = Card.Generator(linked, card.freeOpen)
            if ns.UI.Pad.Input.Active() then return ns.UI.Pad.Menu.Open(card, generator) end
            MenuUtil.CreateContextMenu(card, generator)
        end,
        tip = function()
            local title, lines = Note.Tip(rec, now)
            return Style.TipList(title, lines)
        end,
    }
end

local FACE
FACE = ns.Deaths.Card.RegisterFace(Note.KIND, {
    methods = {
        -- The card for `rec` (a free card as the page reads it), `open(guid)`
        -- what a name opens (the margin's ToPerson).
        SetNoteCard = function(card, rec, mark, seed, now, open)
            card.freeRec, card.freeOpen, card.freeSeed, card.freeNow = rec, open, seed, now
            card.freeGive = { lines = nil }
            local display = ns.Plain(rec.display)
            local k = { name = Mob(rec) or "", mark = mark,
                display = Mob(rec) and type(display) == "number" and display > 0 and display or nil }
            card:Wear(FACE, k, NoteOf(card, seed, now))
        end,
    },
    plan = function(card, note, width, room, _, Least)
        -- (the words at the band's lines, or fewer where given up: the strip
        -- reads how many as its note is set, so the same note is set again)
        local give = card.freeGive
        local most = math.min(give.lines or FREE.lines[Band(width)], FREE.lines[Band(width)])
        card.freeQuoted = (not give.words and Words(card.freeRec)) and most or nil
        note.quote = card.freeQuoted and Words(card.freeRec) or nil
        note.quoteLines = most
        card:SetNote(note)
        return Plan(card, note, width, room, Least)
    end,
    top = function(card, plan) Top(card, plan) end,
    under = function(card, plan) Under(card, plan) end,
    hide = function(card)
        local bits = card.freeBits
        if bits then
            bits.kit:Begin()
            bits.kit:Finish()
            bits.mob:Hide()
            bits.box:Hide()
        end
        card.freeIcon = nil
    end,
    off = function(card)
        card.freeRec, card.freeOpen, card.freeGive, card.freeQuoted, card.freeSize, card.freeFrom = nil, nil, nil, nil, nil, nil
    end,
    -- Short of height: the picture, the words to two lines, the item, the
    -- words to one, the creature's name, the band, the words (FREE's
    -- comment, at the head of this file).
    smaller = function(card)
        local give, rec = card.freeGive, card.freeRec
        local lines = card.freeQuoted or 0
        local quoted = lines > 0
        if card.mode ~= "name" and card.picture ~= nil then
            card.mode = "name"
            return true
        end
        if quoted and lines > 2 then
            give.lines = 2
            return true
        end
        if ItemName(rec) and not give.item then
            give.item = true
            return true
        end
        if quoted and lines > 1 then
            give.lines = 1
            return true
        end
        if Mob(rec) and not give.mob and card.freeFrom ~= "mob" then
            give.mob = true
            return true
        end
        if not give.band then
            give.band = true
            return true
        end
        if quoted then
            give.words = true
            return true
        end
        return false
    end,
})

-- The card as the form has it (CardSheet's preview, Kind.lua's `preview`):
-- written by the same face as in the margin, with no mark (no leader, the
-- picture facing right) and a name that opens nothing, seeded by the card's
-- time so it lies as it will. Only to be looked at: it takes no mouse, so
-- neither its name nor its item's box can be clicked.
function Card.Preview(card, rec, now)
    card:SetNoteCard(rec, nil, "preview:" .. tostring(rec.t or 0), now, function() end)
end

--------------------------------------------------------------------------
-- In the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- Each card on the plate, newest first, so where the margin runs out it is
-- the oldest that is left to its mark and the caption.
local function Items(plate)
    local items = {}
    for _, mark in ipairs(plate.noteCardMarks or {}) do
        for _, m in ipairs(mark.list or {}) do
            items[#items + 1] = { rec = m.noteCard, mark = mark.at, top = mark.at[2], x = mark.at[1] }
        end
    end
    table.sort(items, function(a, b) return (a.rec.t or 0) > (b.rec.t or 0) end)
    return items
end
Card.Items = Items

-- What the cards tell the words: the cards shown, and who they name, so
-- the words do not name them again.
local function Tell(said, list)
    said.noteCard = {}
    for _, it in ipairs(list) do
        said.noteCard[it.rec] = true
        for _, p in ipairs(Note.People(it.rec)) do
            local guid = Note.Guid(p)
            if guid then said.named[guid] = true end
        end
    end
end

-- The killer card's pool, worn with the free card's face. Margin order 2:
-- before every automatic person (10) and every other custom card, past
-- whatever picks one card a plate, and with nothing replacing it, as the
-- custom cards' rule asks; the newest first, so the oldest is left off.
ns.UI.JourneyMargin.Register(Note.KIND, {
    order = 2, pool = "killerPool", count = "noteCardsWritten",
    new = function(parent) return ns.Deaths.Card.New(parent) end,
    items = Items,
    write = function(card, it, c)
        local rec = it.rec
        card:SetNoteCard(rec, it.mark, c.Seed(Note.FirstGuid(rec) or Note.Subject(rec) or "note", rec.t), c.now,
            c.ToPerson)
    end,
    mark = function(it) return it.mark end,
    custom = function(it) return Note.KIND, it.rec end,
    assume = function(said, plate) Tell(said, Items(plate)) end,
    say = function(said, shown) Tell(said, shown) end,
})
