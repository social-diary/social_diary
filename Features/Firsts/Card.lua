-- The first found card (Your Diary's plates, JRN-24): a first bag,
-- shoulders, green, blue or epic, shown as the thing itself. A paper strip
-- (UI/Paper/Strip.lua) taped in the plate's margin with a pencil leader to
-- its pouch (Mark.lua), the heading in the diary's hand, "Your first green item!",
-- and under it the item boxed as the game shows it, its icon and then its
-- name in its colour, set a little askew on the slip, as a thing pasted in
-- by hand never quite lines up with what was written over it.
--
-- The box is the paper's own (ns.UI.ItemBox, UI/Paper/ItemBox.lua, where
-- it moved on 15 Nov 2026 so another card can paste an item in the same
-- way): the game's item chip brought onto paper, a white item's ruled in
-- ink, a green, blue or epic one's a swatch of watercolour with its tide
-- line, the icon edged in its quality's colour, the name in its ink. Its
-- look tables (BOX, ICON, NAME) and its drawing are there; this card
-- gives it the item, its quality and its room under the heading.
-- Under the mouse the box's rule darkens (a wash's tide line goes to the
-- name's ink) and the item's own tooltip shows (GameTooltip:SetHyperlink),
-- with how and when it came under it in the tooltip's flavour gold. The
-- rest of the slip tells it in the pouch's words.
--
-- Which and where (the margin's `find`, at the foot of this file): one
-- card an item, so a green bag that was both the first bag and the first
-- green is one card ("Your first bag and first green item!"); after the
-- people's strips and before the killer card (the user's ruling: a first
-- outranks a death); left off from the bottom when the column runs out,
-- the killer first. A first with no card keeps its item's name in the
-- caption (Text.lua's caption words, `said.find`). A gift whose giver has
-- no strip beside the plate says so under the box ("a gift", "from
-- Koko": Firsts.GiftLine).
--
-- A first the player changed or wrote (Core/Custom.lua) is the same card, with a
-- card of its own whatever it shares a link with, and comes before the people
-- (`findCustom`, at the foot of this file). A typed name has no link, so it takes
-- the card's fallbacks: no icon, the box's name alone, in the ink of the first it
-- says it is (Quality's `whats`), plain for a bag or shoulders.
--
-- Laid flat ("Flat paper only") the box lies square with the slip (the
-- box's own header says how).

local addonName, ns = ...

local Style = ns.Style

local FindCard = {}
ns.Firsts.Card = FindCard

-- The heading: written at the hand's sizes in turn (FONT.noteWritten's
-- 16, then `small` from `hand`), the full words first and then the short
-- ("Your first green!"); a card whose heading fits none is left off.
-- The box turns `lean` degrees on top of the slip's turn (seeded between
-- `least` and `most`, against the slip's way, so the two read as placed
-- apart); the slip itself turns at most `turn`. `gap` under the heading,
-- `after` over a gift's line.
-- BOX and ICON are the box's own (ns.UI.ItemBox), kept on this card's
-- table as they were (the tests' names for them).
local FIND = {
    small = 14, turn = 1.2, gap = 5, after = 3,
    lean = { least = 1.4, most = 2.6 },
}
local ItemBox = ns.UI.ItemBox
local BOX, ICON = ItemBox.BOX, ItemBox.ICON
-- The tooltip's line of how and when, in the game's flavour gold.
local TIP = { colour = { 1, 0.82, 0 } }

local HAND = Style.NEUTON_ITALIC

-- A first's quality from what it was a first of, where its link says none.
local KIND_QUALITY = { uncommon = 2, rare = 3, epic = 4 }

--------------------------------------------------------------------------
-- The item
--------------------------------------------------------------------------

-- The item's quality: from its link's colour, else the client's
-- (ItemBox.Quality), else what it was a first of (`whats`), else common.
function FindCard.Quality(link, whats)
    local q = ItemBox.Quality(link)
    if q then return q end
    local best = 1
    for _, what in ipairs(whats or {}) do best = math.max(best, KIND_QUALITY[what] or 1) end
    return best
end

-- The item's icon, the ink of its name and the edge round its icon: the
-- box's (UI/Paper/ItemBox.lua), under the names they had here.
FindCard.Icon, FindCard.Ink, FindCard.Edge = ItemBox.Icon, ItemBox.Ink, ItemBox.Edge

-- The items found on `plate` (its pouches, plate.findMarks: Mark.lua's
-- `keep`), one an item:
-- { link, whats, moments, rec, mark (its pouch on the page), top }, in
-- the order of their pouches down the plate, so the leaders do not cross.
-- Not the player's own: those are Customs'.
function FindCard.Items(plate)
    local items, byLink = {}, {}
    for _, pouch in ipairs(plate.findMarks or {}) do
        for _, m in ipairs(pouch.list or {}) do
            local rec = m.find or m
            if not rec.customOf then
                local key = rec.link or m
                local item = byLink[key]
                if not item then
                    item = { link = rec.link, whats = {}, moments = {}, rec = rec, mark = pouch.at,
                        top = pouch.at and pouch.at[2] or 0 }
                    byLink[key] = item
                    items[#items + 1] = item
                end
                item.whats[#item.whats + 1] = m.what
                item.moments[#item.moments + 1] = m
            end
        end
    end
    table.sort(items, function(a, b) return a.top < b.top end)
    return items
end

-- The firsts on `plate` the player changed or wrote, as Items' items: a card
-- each, never joined to another that shares its link, as joining would leave one
-- right click for two cards. The newest first, so where the margin runs out the
-- oldest are the ones left to their pouches. One with no item named has no card
-- and keeps its pouch, as a close call with no creature keeps its cross: a box
-- with nothing in it would say less than the mark's tooltip does.
function FindCard.Customs(plate)
    local items = {}
    for _, pouch in ipairs(plate.findMarks or {}) do
        for _, m in ipairs(pouch.list or {}) do
            local rec = m.find
            if rec and rec.customOf and ns.Firsts.Name(rec) then
                items[#items + 1] = { link = rec.link, whats = { m.what }, moments = { m }, rec = rec, mark = pouch.at,
                    top = pouch.at and pouch.at[2] or 0 }
            end
        end
    end
    table.sort(items, function(a, b) return (a.rec.t or 0) > (b.rec.t or 0) end)
    return items
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- Text measured unbounded (the turned plane's kit, UI/Paper/Surface.lua).
local Width = ns.UI.Surface.Width

-- A card on `parent` (the right page): a paper strip with the box under
-- its heading. card:SetFind(item, seed, now, gift) with an item of
-- FindCard.Items (or one made up, as the tour's, UI/Windows/Intro/Tour.lua:
-- `icon`, its picture where it has no link; `short`, the short heading
-- only) and the line under the box (Firsts.GiftLine) or nil, then
-- card:Layout(x, y, width) as a strip's; card.overfull where it will not
-- fit `width` (the page leaves it off). Laid through the strip's hooks
-- (UI/Paper/Strip.lua), `hooks`, filled in below, after the box's drawing.
function FindCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)

    -- The heading's second line, where it takes two.
    card.headTail = Style.Text(card, Style.FONT.noteWritten)
    card.headTail:Hide()
    -- The box (UI/Paper/ItemBox.lua), its pieces under the names they had
    -- when they were made here (the tests read them so).
    local box = ItemBox.New(card, parent)
    card.boxWeight, card.boxRule, card.boxGround = box.weight, box.rule, box.ground
    card.boxWash, card.boxTide = box.wash, box.tide
    card.iconShadow, card.iconEdge, card.icon = box.iconShadow, box.iconEdge, box.icon
    card.itemLines = box.lines

    -- The box takes the mouse for the item's own tooltip.
    card.item = box.button
    function box.enter(button)
        card:Hot(true)
        FindCard.ShowTip(button, card.found, card.now)
    end
    function box.leave()
        card:Hot(false)
        GameTooltip:Hide()
    end

    -- Faded with the card (card:SetAlpha, as the tour's sheet fades and
    -- lays back what it shows, UI/Windows/Intro/Tour.lua): a wash is
    -- multiplied in, which a frame's alpha does not reach, so the box
    -- fades its own colours (box:Fade).
    card.fade = 1
    local setAlpha = card.SetAlpha
    function card:SetAlpha(a)
        setAlpha(self, a)
        self.fade = math.max(0, math.min(1, a or 1))
        box:Fade(a)
    end

    -- The rule (a wash's tide line) as under the mouse or not: the box's.
    function card:Hot(on)
        box:Hot(on)
        self.hot = on == true
    end
    -- Put away under the mouse: lying quiet when it comes back.
    card:HookScript("OnHide", function() card.hot = false end)

    function card:SetFind(item, seed, now, gift)
        self.found, self.now, self.gift, self.seedKey = item, now, gift, seed
        self.quality = FindCard.Quality(item.link, item.whats)
        self.iconFile = item.icon or FindCard.Icon(item.link)
        self.itemName = ns.Firsts.ItemName(item.link) or ns.Firsts.Name(item.rec) or "?"
        self:SetNote({ name = ns.Firsts.Heading(item.whats), what = gift, strong = true, seed = seed,
            turn = FIND.turn, tip = function() return FindCard.Tip(item, now) end })
    end

    -- The heading in the hand at `size` (0: FONT.noteWritten's own) on
    -- `text`.
    local function Hand(text, size)
        text:SetFontObject(Style.FONT.noteWritten)
        if size > 0 then text:SetFont(HAND, size, "") end
    end

    -- The heading at the first size and words that fit `room` on one line,
    -- the full words before the short; else the full words on two (the
    -- shoulders!"), on `note` (the strip's). Whether it fits, and the
    -- second line's words if any.
    local function Heading(room, note)
        local Firsts = ns.Firsts
        for _, short in ipairs(card.found.short and { true } or { false, true }) do
            local words = Firsts.Heading(card.found.whats, short)
            for _, size in ipairs({ 0, FIND.small }) do
                Hand(card.name, size)
                card.name:SetText(words)
                if Width(card.name) <= room then
                    note.name = words
                    return true, nil
                end
            end
        end
        local words = Firsts.Heading(card.found.whats)
        for _, size in ipairs({ 0, FIND.small }) do
            Hand(card.name, size)
            Hand(card.headTail, size)
            local first, rest = "", nil
            for word in words:gmatch("%S+") do
                if rest then
                    rest = rest .. " " .. word
                else
                    local try = first == "" and word or (first .. " " .. word)
                    card.name:SetText(try)
                    if first ~= "" and Width(card.name) > room then rest = word else first = try end
                end
            end
            card.name:SetText(first)
            card.headTail:SetText(rest or "")
            if rest and Width(card.name) <= room and Width(card.headTail) <= room then
                note.name = first
                return true, rest
            end
        end
        return false, nil
    end

    -- The box as laid now (card.chip), on the slip's room under the name.
    local function Box()
        local chip, room = card.chip, card.under
        local shown = chip ~= nil and room ~= nil
        card.headTail:SetShown(shown and chip.tail ~= nil)
        if not shown then
            box:Hide()
            return
        end

        -- The heading's second line, at the top of the room, square with
        -- the slip as the first is.
        local top = room.ly - room.h / 2
        if chip.tail then
            local tw = Width(card.headTail) + 2
            card:Lay(card.headTail, room.lx - room.w / 2 + tw / 2, top + chip.tailH / 2, tw, chip.tailH)
        end
        -- The box's middle, in its own room under that.
        local mx, my = room.lx - room.w / 2 + chip.bw / 2, top + chip.top + chip.bh / 2
        box:Draw(chip, mx, my, { quality = card.quality, icon = card.iconFile })
        card.lean = box.lean
    end

    -- Laid as a strip, with the box's room under the heading, measured for
    -- the column `width`: the heading at the size that fits, the name in
    -- the lines that hold it; then the gift's line in ink, and the box.
    function hooks.plan(self, note, width)
        self.column = width
        local l, _, r = self:Pad()
        local room = width - l - r
        local fits, tail = Heading(room, note)

        -- The box for the name in that room (the box's Measure: the icon
        -- beside the name or over it, its lean seeded by the card's seed).
        local chip = box:Measure(self.itemName, room,
            { icon = self.iconFile ~= nil, column = width, seed = self.seedKey, lean = FIND.lean })
        self.chip = nil
        note.under = nil
        if chip then
            -- Over it the heading's second line, if it has one.
            local tailH = tail and math.max(math.ceil(self.headTail:GetStringHeight() or 0), 14) or 0
            local tailW = tail and Width(self.headTail) + 2 or 0
            local top = tail and (tailH + FIND.gap) or 0
            chip.tail, chip.tailH, chip.top = tail, tailH, top
            self.chip = chip
            note.under = { w = math.max(chip.bw, tailW), h = top + chip.bh, gap = tail and 0 or FIND.gap, after = FIND.after }
            fits = fits and chip.bw <= room
        end
        self.overfull = not (fits and chip)
    end
    function hooks.draw(self)
        local INK = Style.INK
        for _, line in ipairs(self:WhatLines()) do line:SetTextColor(INK[1], INK[2], INK[3]) end
        Box()
    end

    card:Hot(false)
    return card
end

-- The slip's tooltip, as the pouch's (Firsts.Tips): every first the item
-- was, told once, and how and when it came.
function FindCard.Tip(item, now)
    local title, lines = ns.Firsts.Tips(item.moments, now)
    local list = { { title } }
    for _, line in ipairs(lines) do list[#list + 1] = { line, 1, 1, 1, true } end
    return list
end

-- The box's tooltip on `owner`: the item's own (its link), and under it
-- the firsts it was, how and when it came, once, in flavour gold. The name alone where the
-- client will not show the link.
function FindCard.ShowTip(owner, item, now)
    if not item then return end
    local Firsts = ns.Firsts
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = type(GameTooltip.SetHyperlink) == "function" and item.link
        and pcall(GameTooltip.SetHyperlink, GameTooltip, item.link)
    if not shown then GameTooltip:SetText(Firsts.ItemName(item.link) or Firsts.Name(item.rec) or "?") end
    local C = TIP.colour
    -- The firsts and how it came on one line ("Your first bag and first
    -- green, looted"), then when: Firsts.Tips, its name left to the link.
    local title, lines = Firsts.Tips(item.moments, now, true)
    local how = #lines > 1 and table.remove(lines, 1)
    GameTooltip:AddLine(how and ns.T("%1$s, %2$s", title, how:sub(1, 1):lower() .. how:sub(2)) or title,
        C[1], C[2], C[3], true)
    for _, line in ipairs(lines) do GameTooltip:AddLine(line, C[1], C[2], C[3], true) end
    GameTooltip:Show()
end

FindCard.FIND, FindCard.BOX, FindCard.ICON = FIND, BOX, ICON

--------------------------------------------------------------------------
-- The card in the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- A card an item found on the plate, right after the people who did
-- something with you (order 20: the user's ruling, a first outranks a
-- death, so before someone there when you died, 30, and the killer, 40).
-- Taken as shown on their cards until one is left off: the words name the
-- item only where its card has no room (`said.find`, Text.lua's caption
-- words).
ns.UI.JourneyMargin.Register("find", {
    order = 20, pool = "findPool", count = "findsWritten",
    new = function(parent) return FindCard.New(parent) end,
    items = function(plate)
        local list = {}
        for _, item in ipairs(FindCard.Items(plate)) do
            list[#list + 1] = { item = item, top = item.top, x = item.mark and item.mark[1] or 0 }
        end
        return list
    end,
    write = function(card, it, c)
        card:SetFind(it.item, c.Seed("find", it.item.link or ""), c.now,
            ns.Firsts.GiftLine(it.item.rec, c.named))
    end,
    mark = function(it) return it.item.mark end,
    custom = function(it) return "find", it.item.rec end,
    assume = function(said, plate, slot, plan)
        local all = {}
        for _, m in ipairs(plan.moments or {}) do
            if m.kind == "find" then all[m.find or m] = true end
        end
        said.find = all
    end,
    -- Added to what findCustom's said, which is asked first (order 6): both tell
    -- the one word.
    say = function(said, shown)
        local finds = said.find or {}
        for _, it in ipairs(shown) do
            for _, m in ipairs(it.item.moments) do finds[m.find or m] = true end
        end
        said.find = finds
    end,
})

-- The firsts the player changed or wrote, each its own card past whatever joins
-- the rest by their link: laid before the people (10), so they are the last left
-- off (.claude/features/custom-cards.md). The same card, the same pool. The words
-- before laying are `find`'s: its `assume` takes every first on the plate as
-- shown, these among them.
ns.UI.JourneyMargin.Register("findCustom", {
    order = 6, pool = "findPool", count = "customFindsWritten",
    new = function(parent) return FindCard.New(parent) end,
    items = function(plate)
        local list = {}
        for _, item in ipairs(FindCard.Customs(plate)) do
            list[#list + 1] = { item = item, top = item.top, x = item.mark and item.mark[1] or 0 }
        end
        return list
    end,
    write = function(card, it, c)
        local rec = it.item.rec
        card:SetFind(it.item, c.Seed("find", rec.t or 0, ns.Firsts.Name(rec)), c.now, ns.Firsts.GiftLine(rec, c.named))
    end,
    mark = function(it) return it.item.mark end,
    custom = function(it) return "find", it.item.rec end,
    say = function(said, shown)
        local finds = {}
        for _, it in ipairs(shown) do
            for _, m in ipairs(it.item.moments) do finds[m.find] = true end
        end
        said.find = finds
    end,
})
