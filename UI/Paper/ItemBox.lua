-- An item boxed on a paper strip as the game shows it: its icon and then
-- its name in its colour, set a little askew on the slip, as a thing
-- pasted in by hand never quite lines up with what was written over it.
-- The first found card's box (JRN-24), moved here on 15 Nov 2026 so a
-- second card can paste an item in without reading the first's feature
-- (the user: "so we don't repeat ourselves"); that card draws through it
-- and its tests are this file's guard.
--
-- Why here: it is paper laid and turned, not design system. Everything of
-- it is placed through the strip it lies on (strip:Lay, strip:Out, the
-- turned plane's kit, UI/Paper/Surface.lua) and it reads an item's quality
-- from the diary's own reader (ns.Timeline.Quality), neither of which
-- UI/Style/ may know (.claude/rules/ui.md); its colours stay Style's
-- (QualityWash, QualityNameInk, QualityGameColour). It loads after the
-- strip, whose cards are its only users.
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
--     item's in plain ink; wrapped to three lines at most in a narrow
--     margin, smaller only if they will not hold it.
-- Under the mouse the box's rule darkens (a wash's tide line goes to the
-- name's ink); what the mouse shows is its owner's (`enter`, `leave`).
--
-- The quality is the caller's to give (`look.quality`), so an item may be
-- shown without its colour: 1 is the white item's box whatever the item
-- is (plain ink, the pen's rule, the icon edged in ink).
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
--
-- Use, from a card's hooks (UI/Paper/Strip.lua):
--   local box = ns.UI.ItemBox.New(strip, parent)   once, as the card is made
--   plan:  chip = box:Measure(name, room, { icon, column, seed, lean, lead })
--          nil where the name will not go in `room`; else the box as it
--          would be laid: ask a room of chip.bw by chip.bh for it
--   draw:  box:Draw(chip, mx, my, { quality, icon, was })   its middle on
--          the strip (from the strip's middle, y down); or box:Hide()
--   box:Hot(on), box:Fade(alpha), box.enter / box.leave (the button's)
--
-- What the item took the place of may stand in the same box, before its
-- icon (`lead` true in Measure, `was` in Draw; for a card that tells of
-- one item worn in place of another, signed 15 Nov 2026): the old item's
-- icon, smaller, plain (ruled in ink whatever its quality, dimmed) and
-- struck with one stroke of the pen, then a pen's arrow to the new one.
-- Its own button
-- (box.wasButton, box.wasEnter / box.wasLeave). Its pieces are made the
-- first time one is drawn, so a box that never has one makes none.

local addonName, ns = ...

local Style = ns.Style

local ItemBox = {}
ns.UI.ItemBox = ItemBox

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
local BOX = { pad = { 5, 4, 7, 4 }, ground = { 0.975, 0.95, 0.865 }, rule = 0.62, hot = 0.92,
    weight = { 0.8, 0.8, 0.30 } }
local ICON = { size = 22, narrow = 18, below = 140, gap = 5, stack = 4, crop = 0.07, edge = 1,
    shadow = { 1, 1, 0.30 } }
local NAME = { lines = 3, fonts = { { "strong", 15 }, { "small", 13 } } }
-- LEAD, what the item took the place of, before its icon: the old icon
-- `icon` px (edged ICON.edge px in ink, at `alpha`: dimmed, the paper
-- through it), `gap` px to the arrow, the arrow `arrow` px long, `after`
-- px to the new icon. The strike through the old icon, corner to corner
-- less `inset`, `strike` px wide; the arrow's shaft and its head (two
-- strokes back `head[1]` px, out `head[2]`), `pen` px wide, both in strong
-- ink.
local LEAD = { icon = 18, gap = 3, arrow = 12, after = 4, alpha = 0.55, inset = 1, strike = 1.6, pen = 1.3,
    head = { 3.5, 3 } }
ItemBox.BOX, ItemBox.ICON, ItemBox.NAME, ItemBox.LEAD = BOX, ICON, NAME, LEAD

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

-- The item's quality: from its link's colour, else the client's; nil
-- where neither says (the caller's to settle).
function ItemBox.Quality(link)
    local q = ns.Timeline.Quality(link)
    if not q and C_Item then q = Call(C_Item.GetItemQualityByID, ItemID(link) or link) end
    q = ns.Plain and ns.Plain(q) or q
    if type(q) == "number" then return q end
    return nil
end

-- The item's icon (a file ID or path), from its ID, cache-free; nil where
-- the client cannot say.
function ItemBox.Icon(link)
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
function ItemBox.Ink(q)
    if q == 1 or q == nil then return Style.INK_STRONG end
    return Style.QualityNameInk(q) or Style.QualityInk(q) or Style.INK_STRONG
end

-- The 1 px edge round an icon of quality `q`: the game's own colour, as
-- the game draws it, else the name's ink.
function ItemBox.Edge(q)
    return (q ~= 1 and Style.QualityGameColour(q)) or ItemBox.Ink(q)
end

--------------------------------------------------------------------------
-- The box
--------------------------------------------------------------------------

-- A number from a string, the same every time; text measured unbounded;
-- a point of the box turned about its middle (the turned plane's kit,
-- UI/Paper/Surface.lua).
local Seed, Width, Turned = ns.UI.Surface.Seed, ns.UI.Surface.Width, ns.UI.Surface.Turned

-- A box on `card` (a paper strip, on `parent`): its textures, its
-- measuring text and its button, made once. Fields a card may read:
-- weight, rule, ground, wash (2), tide (4), iconShadow, iconEdge, icon,
-- lines (the name's font strings), button, and as drawn: quality, lean
-- (radians, 0 laid flat), hot.
function ItemBox.New(card, parent)
    local box = { card = card, lines = {}, fade = 1, hot = false }

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
    box.weight = Texture(1)
    box.rule = Texture(2)
    box.ground = Texture(3)
    box.wash, box.tide = {}, {}
    for i = 1, 2 do box.wash[i] = Texture(4) end
    for i = 1, 4 do box.tide[i] = Texture(4) end
    for _, part in ipairs({ box.wash[1], box.wash[2], unpack(box.tide) }) do
        part:SetBlendMode("MOD")
    end
    box.iconShadow = Texture(5)
    box.iconEdge = Texture(6)
    box.icon = Texture(7)
    box.measure = Style.Text(card, Style.FONT.strong)
    box.measure:Hide()

    -- The box takes the mouse: a square button over it as drawn, a level
    -- over the slip's. What it does there is its owner's (box.enter,
    -- box.leave, each given the button).
    box.button = CreateFrame("Button", nil, card)
    box.button:SetScript("OnEnter", function(self)
        if box.enter then box.enter(self) end
    end)
    box.button:SetScript("OnLeave", function(self)
        if box.leave then box.leave(self) end
    end)

    -- A wash is multiplied into what lies under it (MOD), which a frame's
    -- alpha does not reach: faded with the card (box:Fade, from the
    -- card's SetAlpha, as the tour's sheet fades and lays back what it
    -- shows, UI/Windows/Intro/Tour.lua), its colours go that far toward
    -- white, which multiplies to nothing, so the box fades with the slip
    -- it is pasted on.
    local function Faded(c)
        local k = 1 - box.fade
        return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k }
    end
    local function Paint()
        local wash = box.washed
        if not wash then return end
        local D, L, R = Faded(wash.deep), Faded(wash.left), Faded(wash.right)
        Style.Gradient(box.wash[1], "HORIZONTAL", { D[1], D[2], D[3], 1 }, { L[1], L[2], L[3], 1 })
        Style.Gradient(box.wash[2], "HORIZONTAL", { L[1], L[2], L[3], 1 }, { R[1], R[2], R[3], 1 })
        box:Hot(box.hot)
    end
    function box:Fade(a)
        self.fade = math.max(0, math.min(1, a or 1))
        Paint()
    end

    -- The rule (a wash's tide line) as under the mouse or not. The tide's
    -- full sides, the bottom and right (all four laid flat), go to the
    -- name's ink.
    function box:Hot(on)
        local INK = Style.INK
        self.rule:SetColorTexture(INK[1], INK[2], INK[3], on and BOX.hot or BOX.rule)
        local wash = self.washed
        if wash then
            local ink = ItemBox.Ink(self.quality)
            for i, tide in ipairs(self.tide) do
                local full = card.flat or i == 2 or i == 4
                local c = Faded(not full and wash.tideIn or (on and ink or wash.tide))
                tide:SetColorTexture(c[1], c[2], c[3], 1)
            end
        end
        self.hot = on == true
    end
    -- Put away under the mouse: lying quiet when it comes back.
    card:HookScript("OnHide", function() box.hot = false end)

    -- `text` broken into lines no wider than `room` in `font`.
    local function Wrap(text, room, font)
        local probe = box.measure
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

    -- `name` in at most NAME.lines lines within `room`, at the first of
    -- the fonts that holds it: the lines, the font, its line height and the
    -- widest line; nil where none does.
    local function Name(name, room)
        for _, each in ipairs(NAME.fonts) do
            local font = Style.FONT[each[1]]
            local lines = Wrap(name, room, font)
            local probe, widest, fits = box.measure, 0, #lines <= NAME.lines
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

    -- The box as it would be laid for `name` in a room `room` px wide, or
    -- nil where the name will not go in it. `o`: `icon` (whether it has a
    -- picture), `column` (the column's width: the icon is narrow under
    -- ICON.below), `seed` (what its lean is seeded by), `lean` = { least,
    -- most } in degrees. The chip: w, h (the box itself), bw, bh (the room
    -- it takes at its lean, the rule round it), icon (its size, 0 without),
    -- lines, font, lineH, textH, lean (radians), iconAt, textAt (from the
    -- box's top left inside its margins), stacked (the icon over the name).
    -- `o.lead` true keeps room before the icon for what the item took the
    -- place of (LEAD): chip.lead its width (0 without), and the icon and a
    -- name beside it stand that much further right.
    function box:Measure(name, room, o)
        local size = o.icon and (o.column < ICON.below and ICON.narrow or ICON.size) or 0
        local lead = o.lead and (LEAD.icon + 2 * ICON.edge + LEAD.gap + LEAD.arrow + LEAD.after) or 0
        local L = o.lean
        local lean = math.rad(L.least + (L.most - L.least) * Style.Noise(Seed(o.seed) + 7))
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
                + (stack and 0 or lead)
            local tallest = BOX.pad[2] + BOX.pad[4] + (stack and (size + ICON.stack + most) or math.max(size, most))
            local nameRoom = room - fixed - 3 - math.ceil(tallest * s) - 1
            lines, font, lineH, widest = Name(name, nameRoom)
            stacked = stack
            if lines then break end
        end
        if not lines then return nil end
        local textH = #lines * lineH
        local w, h, iconAt, textAt
        if stacked then
            w = math.ceil(fixed + math.max(lead + size, widest))
            h = math.ceil(BOX.pad[2] + size + ICON.stack + textH + BOX.pad[4])
            iconAt, textAt = { lead + size / 2, size / 2 }, { 0, size + ICON.stack }
        else
            local inner = math.max(size, textH)
            w = math.ceil(fixed + widest)
            h = math.ceil(BOX.pad[2] + inner + BOX.pad[4])
            iconAt = { lead + size / 2, inner / 2 }
            textAt = { lead + (size > 0 and size + ICON.gap or 0), (inner - textH) / 2 }
        end
        -- Room for it at its lean, and the rule round it.
        local bw, bh = math.ceil(w * c + h * s) + 3, math.ceil(w * s + h * c) + 3
        return { w = w, h = h, icon = size, lines = lines, font = font, lineH = lineH, textH = textH,
            lean = lean, bw = bw, bh = bh, iconAt = iconAt, textAt = textAt, stacked = stacked, lead = lead }
    end

    -- What the item took the place of: its pieces, made when first drawn
    -- (box.was: edge, icon, strokes (the pen's, a pool), button).
    local function Was()
        if box.was then return box.was end
        local was = { edge = Texture(6), icon = Texture(7), strokes = {} }
        box.was = was
        box.wasButton = CreateFrame("Button", nil, card)
        box.wasButton:SetScript("OnEnter", function(self)
            if box.wasEnter then box.wasEnter(self) end
        end)
        box.wasButton:SetScript("OnLeave", function(self)
            if box.wasLeave then box.wasLeave(self) end
        end)
        return was
    end
    local function HideWas()
        local was = box.was
        if not was then return end
        was.edge:Hide()
        was.icon:Hide()
        for _, stroke in ipairs(was.strokes) do stroke:Hide() end
        box.wasButton:Hide()
        box.wasShown = nil
    end

    -- Nothing of it shown.
    function box:Hide()
        for _, part in ipairs({ self.weight, self.rule, self.ground, self.iconShadow, self.iconEdge, self.icon }) do
            part:Hide()
        end
        self.washed = nil
        for _, part in ipairs(self.wash) do part:Hide() end
        for _, part in ipairs(self.tide) do part:Hide() end
        for _, line in ipairs(self.lines) do line:Hide() end
        self.button:Hide()
        HideWas()
    end

    -- The box drawn: `chip` (Measure's) with its middle at mx, my on the
    -- strip. `look`: `quality` (its colours: 1 the white item's box
    -- whatever the item is), `icon` (its picture) and, for a chip measured
    -- with `lead`, `was`: { icon = the old item's picture } (box.wasShown
    -- is "item" where it was drawn, else nil).
    function box:Draw(chip, mx, my, look)
        self.quality = look.quality
        for _, part in ipairs({ self.weight, self.rule, self.ground, self.iconShadow, self.iconEdge, self.icon }) do
            part:Show()
        end
        local wash = Style.QualityWash(look.quality) or nil
        self.washed = wash
        for _, part in ipairs(self.wash) do part:SetShown(wash ~= nil) end
        for _, part in ipairs(self.tide) do part:SetShown(wash ~= nil) end
        for _, line in ipairs(self.lines) do line:Hide() end
        self.button:Show()

        local flat = card.flat
        -- Against the slip's way, so the two read as placed apart.
        local lean = 0
        if not flat and card.turnsText then
            lean = chip.lean * ((card.turn or 0) > 0 and -1 or 1)
        end
        self.lean = lean
        local c, s = math.cos(lean), math.sin(lean)
        local function At(u, v) return Turned(mx, my, u, v, c, s) end
        local function Lay(region, u, v, w, h)
            local lx, ly = At(u, v)
            card:Lay(region, lx, ly, w, h, lean)
        end
        local w, h = chip.w, chip.h
        local INK = Style.INK

        local G = BOX.ground
        self.ground:SetColorTexture(G[1], G[2], G[3], 1)
        local left, top = -w / 2 + BOX.pad[1], -h / 2 + BOX.pad[2]
        if wash then
            -- A wash: the ground out to where the rule was, the colour
            -- multiplied into it, deep at the left edge, `left` where the
            -- name starts (only the margin, where the icon stands over the
            -- name), paling to `right`; the tide line in the rule's place.
            self.weight:Hide()
            self.rule:Hide()
            Lay(self.ground, 0, 0, w + 2, h + 2)
            local u0, u1, us = -w / 2 - 1, w / 2 + 1, left + chip.textAt[1]
            Lay(self.wash[1], (u0 + us) / 2, 0, us - u0, h + 2)
            Lay(self.wash[2], (us + u1) / 2, 0, u1 - us, h + 2)
            -- Top and bottom across the corners, left and right between
            -- them, so no corner is multiplied twice.
            local tide = self.tide
            Lay(tide[1], 0, -h / 2 - 0.5, w + 2, 1)
            Lay(tide[2], 0, h / 2 + 0.5, w + 2, 1)
            Lay(tide[3], -w / 2 - 0.5, 0, 1, h)
            Lay(tide[4], w / 2 + 0.5, 0, 1, h)
            Paint()
        else
            -- A white item's: its heavier bottom and right, its rule, its
            -- ground.
            local Wt = BOX.weight
            self.weight:SetColorTexture(INK[1], INK[2], INK[3], Wt[3])
            Lay(self.weight, Wt[1], Wt[2], w + 2, h + 2)
            self.weight:SetShown(not flat)
            self:Hot(self.hot)
            Lay(self.rule, 0, 0, w + 2, h + 2)
            Lay(self.ground, 0, 0, w, h)
        end

        -- The icon, pasted in at the left, the name's block beside it (or
        -- under it, stacked): as Measure placed them, from the box's top
        -- left inside its margins.
        local size = chip.icon
        local ink, edge = ItemBox.Ink(look.quality), ItemBox.Edge(look.quality)
        if size > 0 then
            local iu, iv = left + chip.iconAt[1], top + chip.iconAt[2]
            local S = ICON.shadow
            self.iconShadow:SetColorTexture(INK[1], INK[2], INK[3], S[3])
            Lay(self.iconShadow, iu + S[1], iv + S[2], size + 2 * ICON.edge, size + 2 * ICON.edge)
            self.iconShadow:SetShown(not flat)
            self.iconEdge:SetColorTexture(edge[1], edge[2], edge[3], 1)
            Lay(self.iconEdge, iu, iv, size + 2 * ICON.edge, size + 2 * ICON.edge)
            self.icon:SetTexture(look.icon)
            local k = ICON.crop
            self.icon:SetTexCoord(k, 1 - k, k, 1 - k)
            Lay(self.icon, iu, iv, size, size)
        else
            self.iconShadow:Hide()
            self.iconEdge:Hide()
            self.icon:Hide()
        end
        -- What it took the place of, before the icon: on the icon's row.
        HideWas()
        if (chip.lead or 0) > 0 and look.was then
            local was, D = Was(), LEAD
            local used = 0
            -- One stroke of the pen from u1, v1 to u2, v2 of the box.
            local function Stroke(u1, v1, u2, v2, width, colour, alpha)
                used = used + 1
                local stroke = was.strokes[used]
                if not stroke then
                    stroke = Texture(7)
                    was.strokes[used] = stroke
                end
                stroke:SetColorTexture(colour[1], colour[2], colour[3], alpha)
                local dx, dy = u2 - u1, v2 - v1
                local lx, ly = At((u1 + u2) / 2, (v1 + v2) / 2)
                card:Lay(stroke, lx, ly, math.sqrt(dx * dx + dy * dy), width, lean + math.atan2(-dy, dx))
                stroke:Show()
            end
            local half = D.icon / 2 + ICON.edge
            local ou, ov = left + half, top + (chip.stacked and size / 2 or chip.iconAt[2])
            local STRONG = Style.INK_STRONG
            was.edge:SetColorTexture(INK[1], INK[2], INK[3], D.alpha)
            Lay(was.edge, ou, ov, D.icon + 2 * ICON.edge, D.icon + 2 * ICON.edge)
            was.edge:Show()
            was.icon:SetTexture(look.was.icon)
            local k = ICON.crop
            was.icon:SetTexCoord(k, 1 - k, k, 1 - k)
            was.icon:SetAlpha(D.alpha)
            Lay(was.icon, ou, ov, D.icon, D.icon)
            was.icon:SetShown(look.was.icon ~= nil)
            local r = D.icon / 2 - D.inset
            Stroke(ou - r, ov + r, ou + r, ov - r, D.strike, STRONG, 1)
            self.wasShown = "item"
            -- The arrow to the new one.
            local a0, a1 = ou + half + D.gap, ou + half + D.gap + D.arrow
            Stroke(a0, ov, a1, ov, D.pen, STRONG, 1)
            Stroke(a1 - D.head[1], ov - D.head[2], a1, ov, D.pen, STRONG, 1)
            Stroke(a1 - D.head[1], ov + D.head[2], a1, ov, D.pen, STRONG, 1)
            for i = used + 1, #was.strokes do was.strokes[i]:Hide() end
            -- The mouse over the old icon as drawn.
            local bx0, by0, bx1, by1 = math.huge, math.huge, -math.huge, -math.huge
            for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
                local px, py = card:Out(At(ou + corner[1] * half, ov + corner[2] * half))
                bx0, by0, bx1, by1 = math.min(bx0, px), math.min(by0, py), math.max(bx1, px), math.max(by1, py)
            end
            self.wasButton:SetFrameLevel(card:GetFrameLevel() + 3)
            self.wasButton:ClearAllPoints()
            self.wasButton:SetPoint("TOPLEFT", parent, "TOPLEFT", bx0, -by0)
            self.wasButton:SetSize(bx1 - bx0, by1 - by0)
            self.wasButton:Show()
        end
        local tx, ty = left + chip.textAt[1], top + chip.textAt[2]
        for i, words in ipairs(chip.lines) do
            local line = self.lines[i]
            if not line then
                line = Style.Text(card, Style.FONT.strong)
                self.lines[i] = line
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
        self.button:SetFrameLevel(card:GetFrameLevel() + 2)
        self.button:ClearAllPoints()
        self.button:SetPoint("TOPLEFT", parent, "TOPLEFT", x0, -y0)
        self.button:SetSize(x1 - x0, y1 - y0)
    end

    return box
end
