-- The first found card (Your Diary's plates, JRN-24): a first bag,
-- shoulders, green, blue or epic, shown as the thing itself. A paper strip
-- (UI/Paper/Strip.lua) taped in the plate's margin with a pencil leader to
-- its pouch (Mark.lua), the heading in the diary's hand, "Your first green item!",
-- and under it the item boxed as the game shows it, its icon and then its
-- name in its colour, set a little askew on the slip, as a thing pasted in
-- by hand never quite lines up with what was written over it.
--
-- The box is the game's item chip brought onto paper, never a screen
-- widget laid over it:
--   - a ground a shade lighter than the slip, so the name reads better on
--     it, never worse;
--   - a white (common) item's ruled in ink, a pen's box, its bottom and
--     right a hair heavier (the light is top left);
--   - a green, blue or epic one's a swatch of watercolour instead: the
--     quality's colour multiplied (MOD) into the cream, so its warmth
--     shows through, heaviest round the icon and paling along the name
--     (Style.QualityWash), and no pen rule: a crisp hairline of darker
--     pigment where the wash dried, the tide line, is its edge, full on
--     the bottom and right, lighter on the top and left;
--   - the icon pasted in: the item's own picture, its baked-in frame
--     trimmed, edged in the game's own quality colour as the game edges
--     it, with a hair of shadow under it;
--   - the name in that quality's ink (Style.QualityNameInk: middle inks,
--     bright enough to keep their hue, dark enough for the wash), a white
--     item's in plain ink; wrapped to two lines in a narrow margin,
--     smaller only if two will not hold it.
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
-- Laid flat ("Flat paper only") the box lies square with the slip, with
-- no heavier edge and no shadow under the icon; a wash keeps its colour
-- (it is pigment, not light), its tide line even on all four sides. Where
-- text cannot turn, the slip lies straight and so does the box.
--
-- The wash turns with the box: SetGradient colours the texture's corners,
-- and SetRotation turns the corners. Were a client to keep the gradient
-- square on the screen, at the box's 3 degrees at most it would differ by
-- a pixel and a half across the box's height, which no eye can see.

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
-- BOX: its margins round the icon and name (left, top, right, bottom),
-- its ground (`ground`, lighter than the slip's STRIP.paper), its rule in
-- ink at `rule` (`hot` under the mouse), the heavier bottom and right a
-- second rule moved `weight` = { dx, dy, alpha } (a white item's: a wash
-- has its tide line instead, in the rule's px, its colours in
-- Style.QualityWash).
-- ICON: `size` px, `narrow`
-- where the column is under `below` px, `gap` before the name, its frame
-- trimmed by `crop` of each side, edged `edge` px in its quality's colour,
-- its shadow `shadow` = { dx, dy, alpha }; where the name will not go
-- beside it, it stands over the name, `stack` px above it. NAME: at most
-- `lines` lines,
-- in `fonts` in turn (Friz 13, then Friz 11; FONT's names, each with its
-- line's height).
local FIND = {
    small = 14, turn = 1.2, gap = 5, after = 3,
    lean = { least = 1.4, most = 2.6 },
}
local BOX = { pad = { 5, 4, 7, 4 }, ground = { 0.975, 0.95, 0.865 }, rule = 0.62, hot = 0.92,
    weight = { 0.8, 0.8, 0.30 } }
local ICON = { size = 22, narrow = 18, below = 140, gap = 5, stack = 4, crop = 0.07, edge = 1,
    shadow = { 1, 1, 0.30 } }
local NAME = { lines = 3, fonts = { { "strong", 15 }, { "small", 13 } } }
-- The tooltip's line of how and when, in the game's flavour gold.
local TIP = { colour = { 1, 0.82, 0 } }

local HAND = Style.NEUTON_ITALIC

-- A first's quality from what it was a first of, where its link says none.
local KIND_QUALITY = { uncommon = 2, rare = 3, epic = 4 }

--------------------------------------------------------------------------
-- The item
--------------------------------------------------------------------------

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- `fn`(...) if it is a function, guarded: its first value, or nil.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

-- The item's quality: from its link's colour, else the client's, else what
-- it was a first of (`whats`), else common.
function FindCard.Quality(link, whats)
    local q = ns.Timeline.Quality(link)
    if not q and C_Item then q = Call(C_Item.GetItemQualityByID, ItemID(link) or link) end
    q = ns.Plain and ns.Plain(q) or q
    if type(q) == "number" then return q end
    local best = 1
    for _, what in ipairs(whats or {}) do best = math.max(best, KIND_QUALITY[what] or 1) end
    return best
end

-- The item's icon (a file ID or path), from its ID, cache-free; nil where
-- the client cannot say.
function FindCard.Icon(link)
    local id = ItemID(link)
    if not id then return nil end
    local icon = C_Item and Call(C_Item.GetItemIconByID, id)
    if not icon and C_Item then icon = select(5, Call(C_Item.GetItemInfoInstant, id)) end
    if not icon then icon = Call(_G.GetItemIcon, id) end
    icon = ns.Plain and ns.Plain(icon) or icon
    if icon == nil or icon == 0 or icon == "" then return nil end
    return icon
end

-- The ink a name of quality `q` is written in on the box: plain ink for
-- a white (common) item, else the quality's own (the card's middle inks,
-- Style.QualityNameInk, where it has one; else the page's).
function FindCard.Ink(q)
    if q == 1 or q == nil then return Style.INK_STRONG end
    return Style.QualityNameInk(q) or Style.QualityInk(q) or Style.INK_STRONG
end

-- The 1 px edge round an icon of quality `q`: the game's own colour, as
-- the game draws it, else the name's ink.
function FindCard.Edge(q)
    return (q ~= 1 and Style.QualityGameColour(q)) or FindCard.Ink(q)
end

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

-- A number from a string, the same every time; text measured unbounded;
-- a point of the box turned about its middle (the turned plane's kit,
-- UI/Paper/Surface.lua).
local Seed, Width, Turned = ns.UI.Surface.Seed, ns.UI.Surface.Width, ns.UI.Surface.Turned

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

    local function Texture(sublevel)
        local texture = card:CreateTexture(nil, "ARTWORK", nil, sublevel)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        return texture
    end
    -- From the slip up: the box's heavier edge, its rule, its ground; a
    -- wash's two lengths (round the icon, along the name) and its tide
    -- line (top, bottom, left, right), both multiplied into the ground,
    -- so their order does not matter; the icon's shadow, its quality
    -- edge, the icon. The name over them.
    card.boxWeight = Texture(1)
    card.boxRule = Texture(2)
    card.boxGround = Texture(3)
    card.boxWash, card.boxTide = {}, {}
    for i = 1, 2 do card.boxWash[i] = Texture(4) end
    for i = 1, 4 do card.boxTide[i] = Texture(4) end
    for _, part in ipairs({ card.boxWash[1], card.boxWash[2], unpack(card.boxTide) }) do
        part:SetBlendMode("MOD")
    end
    card.iconShadow = Texture(5)
    card.iconEdge = Texture(6)
    card.icon = Texture(7)
    card.itemLines = {}
    -- The heading's second line, where it takes two.
    card.headTail = Style.Text(card, Style.FONT.noteWritten)
    card.headTail:Hide()
    card.itemMeasure = Style.Text(card, Style.FONT.strong)
    card.itemMeasure:Hide()

    -- The box takes the mouse for the item's own tooltip: a square button
    -- over it as drawn, a level over the slip's.
    card.item = CreateFrame("Button", nil, card)
    card.item:SetScript("OnEnter", function(self)
        card:Hot(true)
        FindCard.ShowTip(self, card.found, card.now)
    end)
    card.item:SetScript("OnLeave", function()
        card:Hot(false)
        GameTooltip:Hide()
    end)

    -- A wash is multiplied into what lies under it (MOD), which a frame's
    -- alpha does not reach: faded with the card (card:SetAlpha, as the
    -- tour's sheet fades and lays back what it shows, UI/Windows/Intro/
    -- Tour.lua), its colours go that far toward white, which multiplies to
    -- nothing, so the box fades with the slip it is pasted on.
    card.fade = 1
    local function Faded(c)
        local k = 1 - card.fade
        return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k }
    end
    local function Paint()
        local wash = card.wash
        if not wash then return end
        local D, L, R = Faded(wash.deep), Faded(wash.left), Faded(wash.right)
        Style.Gradient(card.boxWash[1], "HORIZONTAL", { D[1], D[2], D[3], 1 }, { L[1], L[2], L[3], 1 })
        Style.Gradient(card.boxWash[2], "HORIZONTAL", { L[1], L[2], L[3], 1 }, { R[1], R[2], R[3], 1 })
        card:Hot(card.hot)
    end
    local setAlpha = card.SetAlpha
    function card:SetAlpha(a)
        setAlpha(self, a)
        self.fade = math.max(0, math.min(1, a or 1))
        Paint()
    end

    -- The rule (a wash's tide line) as under the mouse or not. The tide's
    -- full sides, the bottom and right (all four laid flat), go to the
    -- name's ink.
    function card:Hot(on)
        local INK = Style.INK
        self.boxRule:SetColorTexture(INK[1], INK[2], INK[3], on and BOX.hot or BOX.rule)
        local wash = self.wash
        if wash then
            local ink = FindCard.Ink(self.quality)
            for i, tide in ipairs(self.boxTide) do
                local full = self.flat or i == 2 or i == 4
                local c = Faded(not full and wash.tideIn or (on and ink or wash.tide))
                tide:SetColorTexture(c[1], c[2], c[3], 1)
            end
        end
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

    -- `text` broken into lines no wider than `room` in `font`.
    local function Wrap(text, room, font)
        local probe = card.itemMeasure
        probe:SetFontObject(font)
        local lines, line = {}, ""
        for word in (text or ""):gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            probe:SetText(try)
            if line ~= "" and Width(probe) > room then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        return lines
    end

    -- The name in at most NAME.lines lines within `room`, at the first of
    -- the fonts that holds it: the lines, the font, its line height and the
    -- widest line; nil where none does.
    local function Name(room)
        for _, each in ipairs(NAME.fonts) do
            local font = Style.FONT[each[1]]
            local lines = Wrap(card.itemName, room, font)
            local probe, widest, fits = card.itemMeasure, 0, #lines <= NAME.lines
            for _, line in ipairs(lines) do
                probe:SetText(line)
                widest = math.max(widest, Width(probe))
                if Width(probe) > room then fits = false end
            end
            if fits then
                probe:SetText(lines[1] or "")
                local lineH = math.max(math.ceil(probe:GetStringHeight() or 0), each[2])
                return lines, font, lineH, widest
            end
        end
        return nil
    end

    -- The box as laid now (card.chip), on the slip's room under the name.
    local function Box()
        local chip, room = card.chip, card.under
        local shown = chip ~= nil and room ~= nil
        for _, part in ipairs({ card.boxWeight, card.boxRule, card.boxGround, card.iconShadow, card.iconEdge, card.icon }) do
            part:SetShown(shown)
        end
        local wash = shown and Style.QualityWash(card.quality) or nil
        card.wash = wash
        for _, part in ipairs(card.boxWash) do part:SetShown(wash ~= nil) end
        for _, part in ipairs(card.boxTide) do part:SetShown(wash ~= nil) end
        for _, line in ipairs(card.itemLines) do line:Hide() end
        card.item:SetShown(shown)
        card.headTail:SetShown(shown and chip.tail ~= nil)
        if not shown then return end

        -- The heading's second line, at the top of the room, square with
        -- the slip as the first is.
        local top = room.ly - room.h / 2
        if chip.tail then
            local tw = Width(card.headTail) + 2
            card:Lay(card.headTail, room.lx - room.w / 2 + tw / 2, top + chip.tailH / 2, tw, chip.tailH)
        end
        -- The box's middle, in its own room under that.
        local mx, my = room.lx - room.w / 2 + chip.bw / 2, top + chip.top + chip.bh / 2

        local flat = card.flat
        -- Against the slip's way, so the two read as placed apart.
        local lean = 0
        if not flat and card.turnsText then
            lean = chip.lean * ((card.turn or 0) > 0 and -1 or 1)
        end
        card.lean = lean
        local c, s = math.cos(lean), math.sin(lean)
        local function At(u, v) return Turned(mx, my, u, v, c, s) end
        local function Lay(region, u, v, w, h)
            local lx, ly = At(u, v)
            card:Lay(region, lx, ly, w, h, lean)
        end
        local w, h = chip.w, chip.h
        local INK = Style.INK

        local G = BOX.ground
        card.boxGround:SetColorTexture(G[1], G[2], G[3], 1)
        local left, top = -w / 2 + BOX.pad[1], -h / 2 + BOX.pad[2]
        if wash then
            -- A wash: the ground out to where the rule was, the colour
            -- multiplied into it, deep at the left edge, `left` where the
            -- name starts (only the margin, where the icon stands over the
            -- name), paling to `right`; the tide line in the rule's place.
            card.boxWeight:Hide()
            card.boxRule:Hide()
            Lay(card.boxGround, 0, 0, w + 2, h + 2)
            local u0, u1, us = -w / 2 - 1, w / 2 + 1, left + chip.textAt[1]
            Lay(card.boxWash[1], (u0 + us) / 2, 0, us - u0, h + 2)
            Lay(card.boxWash[2], (us + u1) / 2, 0, u1 - us, h + 2)
            -- Top and bottom across the corners, left and right between
            -- them, so no corner is multiplied twice.
            local tide = card.boxTide
            Lay(tide[1], 0, -h / 2 - 0.5, w + 2, 1)
            Lay(tide[2], 0, h / 2 + 0.5, w + 2, 1)
            Lay(tide[3], -w / 2 - 0.5, 0, 1, h)
            Lay(tide[4], w / 2 + 0.5, 0, 1, h)
            Paint()
        else
            -- A white item's: its heavier bottom and right, its rule, its
            -- ground.
            local Wt = BOX.weight
            card.boxWeight:SetColorTexture(INK[1], INK[2], INK[3], Wt[3])
            Lay(card.boxWeight, Wt[1], Wt[2], w + 2, h + 2)
            card.boxWeight:SetShown(not flat)
            card:Hot(card.hot)
            Lay(card.boxRule, 0, 0, w + 2, h + 2)
            Lay(card.boxGround, 0, 0, w, h)
        end

        -- The icon, pasted in at the left, the name's block beside it (or
        -- under it, stacked): as Layout measured them, from the box's top
        -- left inside its margins.
        local size = chip.icon
        local ink, edge = FindCard.Ink(card.quality), FindCard.Edge(card.quality)
        if size > 0 then
            local iu, iv = left + chip.iconAt[1], top + chip.iconAt[2]
            local S = ICON.shadow
            card.iconShadow:SetColorTexture(INK[1], INK[2], INK[3], S[3])
            Lay(card.iconShadow, iu + S[1], iv + S[2], size + 2 * ICON.edge, size + 2 * ICON.edge)
            card.iconShadow:SetShown(not flat)
            card.iconEdge:SetColorTexture(edge[1], edge[2], edge[3], 1)
            Lay(card.iconEdge, iu, iv, size + 2 * ICON.edge, size + 2 * ICON.edge)
            card.icon:SetTexture(card.iconFile)
            local k = ICON.crop
            card.icon:SetTexCoord(k, 1 - k, k, 1 - k)
            Lay(card.icon, iu, iv, size, size)
        else
            card.iconShadow:Hide()
            card.iconEdge:Hide()
            card.icon:Hide()
        end
        local tx, ty = left + chip.textAt[1], top + chip.textAt[2]
        for i, words in ipairs(chip.lines) do
            local line = card.itemLines[i]
            if not line then
                line = Style.Text(card, Style.FONT.strong)
                card.itemLines[i] = line
            end
            line:SetFontObject(chip.font)
            line:SetText(words)
            line:SetTextColor(ink[1], ink[2], ink[3])
            line:SetSize(0, 0)
            local lw = Width(line) + 2
            Lay(line, tx + lw / 2, ty + (i - 0.5) * chip.lineH, lw, chip.lineH)
            line:Show()
        end

        -- The mouse over the box as drawn, its corners turned: one square
        -- button round them.
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local px, py = card:Out(At(corner[1] * (w / 2 + 1), corner[2] * (h / 2 + 1)))
            x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
        end
        card.item:SetFrameLevel(card:GetFrameLevel() + 2)
        card.item:ClearAllPoints()
        card.item:SetPoint("TOPLEFT", parent, "TOPLEFT", x0, -y0)
        card.item:SetSize(x1 - x0, y1 - y0)
    end

    -- Laid as a strip, with the box's room under the heading, measured for
    -- the column `width`: the heading at the size that fits, the name in
    -- the lines that hold it; then the gift's line in ink, and the box.
    function hooks.plan(self, note, width)
        self.column = width
        local l, _, r = self:Pad()
        local room = width - l - r
        local fits, tail = Heading(room, note)

        local size = self.iconFile and (width < ICON.below and ICON.narrow or ICON.size) or 0
        local L = FIND.lean
        local lean = math.rad(L.least + (L.most - L.least) * Style.Noise(Seed(self.seedKey) + 7))
        local c, s = math.abs(math.cos(lean)), math.abs(math.sin(lean))
        -- The name's room: the column's, less the box's margins, the icon,
        -- the rule round it (3) and what its lean takes (at its tallest,
        -- two lines at the larger font).
        -- The icon beside the name where the name fits beside it, else over
        -- it (a word too long for a narrow column beside the icon).
        local most = NAME.lines * NAME.fonts[1][2]
        local lines, font, lineH, widest, fixed, stacked
        for _, stack in ipairs(size > 0 and { false, true } or { false }) do
            fixed = BOX.pad[1] + BOX.pad[3] + 2 + ((size > 0 and not stack) and size + ICON.gap or 0)
            local tallest = BOX.pad[2] + BOX.pad[4] + (stack and (size + ICON.stack + most) or math.max(size, most))
            local nameRoom = room - fixed - 3 - math.ceil(tallest * s) - 1
            lines, font, lineH, widest = Name(nameRoom)
            stacked = stack
            if lines then break end
        end
        self.chip = nil
        note.under = nil
        if lines then
            local textH = #lines * lineH
            local w, h, iconAt, textAt
            if stacked then
                w = math.ceil(fixed + math.max(size, widest))
                h = math.ceil(BOX.pad[2] + size + ICON.stack + textH + BOX.pad[4])
                iconAt, textAt = { size / 2, size / 2 }, { 0, size + ICON.stack }
            else
                local inner = math.max(size, textH)
                w = math.ceil(fixed + widest)
                h = math.ceil(BOX.pad[2] + inner + BOX.pad[4])
                iconAt = { size / 2, inner / 2 }
                textAt = { size > 0 and size + ICON.gap or 0, (inner - textH) / 2 }
            end
            -- Room for it at its lean, and the rule round it; over it the
            -- heading's second line, if it has one.
            local bw, bh = math.ceil(w * c + h * s) + 3, math.ceil(w * s + h * c) + 3
            local tailH = tail and math.max(math.ceil(self.headTail:GetStringHeight() or 0), 14) or 0
            local tailW = tail and Width(self.headTail) + 2 or 0
            local top = tail and (tailH + FIND.gap) or 0
            self.chip = { w = w, h = h, icon = size, lines = lines, font = font, lineH = lineH, textH = textH,
                lean = lean, bw = bw, bh = bh, tail = tail, tailH = tailH, top = top, iconAt = iconAt,
                textAt = textAt, stacked = stacked }
            note.under = { w = math.max(bw, tailW), h = top + bh, gap = tail and 0 or FIND.gap, after = FIND.after }
            fits = fits and bw <= room
        end
        self.overfull = not (fits and lines)
    end
    function hooks.draw(self)
        local INK = Style.INK
        for _, line in ipairs(self:WhatLines()) do line:SetTextColor(INK[1], INK[2], INK[3]) end
        Box()
    end

    card:Hot(false)
    return card
end

-- The slip's tooltip, as the pouch's: each first the item was, and how
-- and when it came.
function FindCard.Tip(item, now)
    local list = {}
    for _, m in ipairs(item.moments) do
        local title, line = ns.Firsts.Tip(m, now)
        list[#list + 1] = { title }
        if line and line ~= "" then list[#list + 1] = { line, 1, 1, 1, true } end
    end
    return list
end

-- The box's tooltip on `owner`: the item's own (its link), and under it
-- how and when each first came, in flavour gold. The name alone where the
-- client will not show the link.
function FindCard.ShowTip(owner, item, now)
    if not item then return end
    local Firsts = ns.Firsts
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = type(GameTooltip.SetHyperlink) == "function" and item.link
        and pcall(GameTooltip.SetHyperlink, GameTooltip, item.link)
    if not shown then GameTooltip:SetText(Firsts.ItemName(item.link) or Firsts.Name(item.rec) or "?") end
    local C = TIP.colour
    for _, m in ipairs(item.moments) do
        local title, line = Firsts.Tip(m, now, true)
        GameTooltip:AddLine(line ~= "" and (title .. ", " .. line) or title, C[1], C[2], C[3], true)
    end
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
