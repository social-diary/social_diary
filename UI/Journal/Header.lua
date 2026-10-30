-- The person's page's header: written straight on the book's page (the
-- person-header proposal, .claude/ui-proposal/person-header-arc-mockup.html,
-- layout B), no paper of its own: the portrait, their name in Goodmountain
-- (mixed case, never capitals), rising a little from its start and levelling
-- off, the relationship in the hand at the end of the name's line, the who
-- line and their tags under it.
--
-- It is part of what scrolls: it lies on the line of the list that holds the
-- plate and the facts (UI/Journal/Clippings.lua), and leaves with it, cut off
-- at the paper's top edge (SHEET.listTop). In writing mode the list is put
-- away and the header stays over the form, on the page itself (`Set`).
--
-- Frames cannot turn, only textures and font strings, so the arc is one font
-- string a letter, each turned to the curve where it stands. With "Flat paper
-- only", where the client cannot turn text, or for a name too long for the
-- letters' pool or its room, the name is one straight font string on the same
-- baseline at its level end.
--
-- Its pieces stay on the page as they were (p.name, p.who, p.chips,
-- p.relationship), for the page and the tests. p.name always holds the whole
-- name; under the arc it is laid but clear, so it still measures.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Width = ns.UI.Surface.Width

local Header = {}
ns.UI.PersonHeader = Header

-- The header's place on the right page (466 x 534, y down from its top left):
--   w, h     its frame, from the page's top left; its pieces stand out of it
--   right    where the writing ends (clear of the page's edge)
--   listTop  the list's top: the paper's top edge, 20 px above the page's
--            frame (UI/Journal/Book.lua's TOP), so what scrolls away leaves
--            with the paper, not at a line across it
--   first    where the list's first writing starts, under the who line
local SHEET = { w = 466, h = 61, right = 460, listTop = -20, first = 61 }
-- Goodmountain's metrics, in ems, from the font's own tables
-- (Fonts/Goodmountain.otf: 1000 units an em, hhea ascender 1000 and
-- descender 210, the glyphs' bounds 1210 up and 257 down): the client lays
-- a line `line` ems tall, `ascent` of it over the baseline, but its tall
-- ascenders and swashes reach `high` over the baseline and `low` under it,
-- out of the line's box. Taken as one em to the font's size (the larger of
-- the ways a client may scale it), so the ink is never under-reckoned.
local GOOD = { line = 1.21, ascent = 1.0, high = 1.21, low = 0.257 }
-- The portrait disc, `size` across with its rings (inset, colour: the round
-- portrait's, Style.Portrait, scaled), the race or class icon `zoom` times
-- the inner disc under a round mask; its `y` (below, once the name and the
-- who line are known) centres it on their ink.
local PORTRAIT = { x = 6, size = 44, zoom = 1.4, pad = 4.95,
    rings = { { 0, { 0, 0, 0 } }, { 1.65, { 0.72, 0.58, 0.33 } }, { 3.3, { 0, 0, 0 } }, { 3.85, { 0.22, 0.15, 0.08 } } } }
-- The name: from `x`, its level end on `baseline` at every size (the arc
-- starts lower); `room` px for it; a long name a size down, `sizes` in turn
-- ({ font, its size }, Style/Tokens.lua's), and past the last cut at the
-- room, never past it.
local NAME = { x = 58, baseline = 26, room = 330,
    sizes = { { "personName", 27 }, { "personNameSmall", 22 }, { "personNameLeast", 17 } } }
-- The arc: { fraction of the name's width, degrees }, straight lines between
-- the stops; less than nothing climbs (against the clock). `pool` letters at
-- most; each letter's box `swash` ems wider than its advance and tall enough
-- for its turn (`Letter`), or the client cuts the swashes or adds an ellipsis.
local ARC = { { 0, -5 }, { 0.30, -1 }, { 1, 0 } }
local LETTERS = { pool = 24, swash = 0.6 }
-- The relationship, on the name's line at its right: its middle `y` down,
-- `gap` px clear of the name; cut there, and gone if cut under `least` px.
local RELATION = { y = 22, gap = 12, least = 60 }
-- `ink`: how far under its middle the who line's writing ends.
local WHO = { x = 58, y = 39, h = 16, least = 150, ink = 3 }
-- The portrait on the name's and the who line's ink, from the top of the
-- name's letters at its largest size (its ascender over the baseline) to the
-- foot of the who line. Fixed: a name a size down keeps its baseline, so its
-- ink starts lower and the portrait stays. (30 Oct, in the client: at y -6 it
-- stood well over the name, its foot at the who line's top.)
local NAME_TOP = NAME.baseline - GOOD.ascent * NAME.sizes[1][2]
PORTRAIT.y = (NAME_TOP + WHO.y + WHO.h / 2 + WHO.ink - PORTRAIT.size) / 2
-- The tags after the who line, `clear` px on from it, chips `gap` apart. The
-- who line gives way to them, cut there (the client ends it in an ellipsis);
-- only past the who line's WHO.least do the tags give way, a chip at a time,
-- the last first.
local TAGS = { y = 39, h = 16, pad = 6, gap = 6, clear = 9, most = 12, edge = 0.35 }
Header.SHEET, Header.PORTRAIT, Header.NAME, Header.TAGS, Header.ARC, Header.LETTERS, Header.RELATION =
    SHEET, PORTRAIT, NAME, TAGS, ARC, LETTERS, RELATION
Header.GOOD, Header.WHO = GOOD, WHO

-- The name's line at font size `size`, the client measuring its line
-- `measured` px tall: the top of its line's box and its height, and where
-- its ink starts and ends at the level end (y down). The line is taken no
-- shorter than GOOD.line ems; its ems from it.
function Header.NameLine(size, measured)
    local lineH = math.max(measured or 0, size * GOOD.line)
    local em = lineH / GOOD.line
    local B = NAME.baseline
    return B - em * GOOD.ascent, lineH, B - em * GOOD.high, B + em * GOOD.low
end

-- The arc's angle in degrees at `t`, a fraction of the name's width.
function Header.ArcAngle(t)
    for i = 2, #ARC do
        local a, b = ARC[i - 1], ARC[i]
        if t <= b[1] then return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1]) end
    end
    return ARC[#ARC][2]
end

-- The letters of `text`, whole UTF-8 sequences, not bytes.
function Header.Letters(text)
    local letters = {}
    for letter in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do letters[#letters + 1] = letter end
    return letters
end

-- Where each letter of `letters` stands on the arc, its level end on
-- NAME.baseline, measured by `widthOf(text)` (whole strings, so whatever
-- kerning the client applies is kept: a letter starts at the width of
-- everything up to and including it, less its own). The baseline is the
-- integral of its tangent; each letter's baseline's middle lies on it, turned
-- to the tangent there. Returns one { letter, x, y, deg, adv } a letter: x, y
-- its baseline's left end (y down), and the name's length.
function Header.ArcPlace(letters, widthOf)
    local L = widthOf(table.concat(letters))
    local n = math.max(64, math.ceil(L * 4))
    local xs, ys = { [0] = 0 }, { [0] = 0 }
    local last = math.rad(Header.ArcAngle(0))
    for i = 1, n do
        local a = math.rad(Header.ArcAngle(i / n))
        xs[i] = xs[i - 1] + L / n * (math.cos(last) + math.cos(a)) / 2
        ys[i] = ys[i - 1] + L / n * (math.sin(last) + math.sin(a)) / 2
        last = a
    end
    local y0 = NAME.baseline - ys[n]
    local function At(s)
        local f = math.max(0, math.min(n, L > 0 and s / L * n or 0))
        local i = math.min(n - 1, math.floor(f))
        local u = f - i
        return NAME.x + xs[i] + (xs[i + 1] - xs[i]) * u, y0 + ys[i] + (ys[i + 1] - ys[i]) * u
    end
    local placed, prefix = {}, ""
    for i, letter in ipairs(letters) do
        prefix = prefix .. letter
        local adv = widthOf(letter)
        local mid = widthOf(prefix) - adv / 2
        local deg = Header.ArcAngle(L > 0 and mid / L or 0)
        local r = math.rad(deg)
        local x, y = At(mid)
        placed[i] = { letter = letter, x = x - adv / 2 * math.cos(r), y = y - adv / 2 * math.sin(r), deg = deg, adv = adv }
    end
    return placed, L
end

-- The header on the person's page `p`, over its list `list`.
function Header.New(p, list)
    local W = SHEET.w
    local sheet = CreateFrame("Frame", nil, p)
    sheet:SetSize(W, SHEET.h)
    local level = list:GetFrameLevel() + 40
    sheet:SetFrameLevel(level)

    local function Texture(layer, sublevel)
        return sheet:CreateTexture(nil, layer, nil, sublevel)
    end

    local h = { sheet = sheet, p = p, list = list }
    h.rings = {}
    for i = 1, #PORTRAIT.rings do h.rings[i] = Texture("ARTWORK", i - 1) end
    h.icon = Texture("ARTWORK", 4)
    local circle = Style.Art("circle")
    if circle and sheet.CreateMaskTexture then
        h.mask = sheet:CreateMaskTexture()
        h.mask:SetTexture(circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        h.icon:AddMaskTexture(h.mask)
    end

    -- The writing: the name whole, what the arc measures with, its letters.
    h.name = Style.Text(sheet, FONT.personName)
    h.name:SetWordWrap(false)
    h.measure = Style.Text(sheet, FONT.personName)
    h.measure:SetWordWrap(false)
    h.measure:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, 0)
    h.measure:SetAlpha(0)
    h.letters = {}
    for i = 1, LETTERS.pool do
        local letter = Style.Text(sheet, FONT.personName)
        letter:SetWordWrap(false)
        letter:Hide()
        h.letters[i] = letter
    end
    h.turnsText = h.name.SetRotation ~= nil
    h.who = Style.Text(sheet, FONT.body)
    h.who:SetWordWrap(false)
    -- The relationship is the user's word: in the hand.
    h.relationship = Style.Text(sheet, FONT.personRelation)
    h.relationship:SetWordWrap(false)
    h.relationship:SetJustifyH("RIGHT")

    -- A piece w by ht with its top left at x, y.
    local function Box(region, x, y, w, ht)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", sheet, "TOPLEFT", x, -y)
        region:SetSize(w, ht)
    end

    -- The chips: a frame each, to show and hide it whole.
    h.chips = {}
    for i = 1, TAGS.most do
        local chip = CreateFrame("Frame", nil, sheet)
        chip:SetAllPoints(sheet)
        chip.edge = chip:CreateTexture(nil, "ARTWORK", nil, 5)
        chip.fill = chip:CreateTexture(nil, "ARTWORK", nil, 6)
        chip.label = Style.Text(chip, FONT.tag)
        function chip:SetTag(tag)
            local colour = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
            self.fill:SetColorTexture(colour[1], colour[2], colour[3], 1)
            self.edge:SetColorTexture(0, 0, 0, TAGS.edge)
            self.label:SetText(tag)
            self.w = math.ceil(Width(self.label) + 2 * TAGS.pad)
        end
        chip:Hide()
        h.chips[i] = chip
    end

    -- The portrait: its rings, its icon under the round mask.
    local cx, cy = PORTRAIT.x + PORTRAIT.size / 2, PORTRAIT.y + PORTRAIT.size / 2
    for i, ring in ipairs(PORTRAIT.rings) do
        local c, d = ring[2], PORTRAIT.size - 2 * ring[1]
        Style.Disc(h.rings[i], c[1], c[2], c[3], 1)
        Box(h.rings[i], cx - d / 2, cy - d / 2, d, d)
    end
    local inner = PORTRAIT.size - 2 * PORTRAIT.pad
    local icon = h.mask and inner * PORTRAIT.zoom or inner
    Box(h.icon, cx - icon / 2, cy - icon / 2, icon, icon)
    if h.mask then Box(h.mask, cx - inner / 2, cy - inner / 2, inner, inner) end

    -- On the page itself while writing (the list is put away), else on the
    -- list, so its top edge cuts it: the frame level set again, as a new
    -- parent may move it.
    local function Mount(self, parent)
        if self.mount == parent then return end
        self.mount = parent
        sheet:SetParent(parent)
        sheet:SetFrameLevel(level)
        for _, chip in ipairs(self.chips) do chip:SetFrameLevel(level + 1) end
    end
    local function OnRow(self)
        sheet:ClearAllPoints()
        if self.row then sheet:SetPoint("TOPLEFT", self.row, "TOPLEFT", 0, SHEET.listTop) end
        sheet:SetShown(self.row ~= nil)
    end

    -- Shown on `row`, the list's line that holds it (Clippings).
    function h:Hold(row)
        self.row = row
        if not self.editing then OnRow(self) end
    end
    -- `row` was handed another line: scrolled away, if it held it.
    function h:Let(row)
        if self.row ~= row then return end
        self.row = nil
        if not self.editing then OnRow(self) end
    end

    -- A letter's font string: its baseline's left end at x, y, turned `deg`
    -- (as the arc's: less than nothing against the clock). The client turns a
    -- font string about its left end, not its baseline (21 Oct, in the client:
    -- the who line drawn about 4 px over its plan when laid by its middle), and
    -- a line's middle lies (ascent - line / 2) ems over its baseline, so it is
    -- anchored by its left there, along the normal.
    local function Letter(text, place, em, lineH)
        local r = math.rad(place.deg)
        local d = (GOOD.ascent - GOOD.line / 2) * em
        local x, y = place.x + math.sin(r) * d, place.y - math.cos(r) * d
        local w = place.adv + LETTERS.swash * em
        text:ClearAllPoints()
        text:SetPoint("LEFT", sheet, "TOPLEFT", x, -y)
        text:SetSize(w, lineH + w * math.abs(math.sin(r)) + 4)
        if text.SetRotation then text:SetRotation(math.rad(-place.deg)) end
    end

    -- The name on the arc, if it may be: true when it was.
    local function LayArc(self, name, font, em, lineH)
        local letters = Header.Letters(name)
        local ink = 0
        for _, letter in ipairs(letters) do
            if letter ~= " " then ink = ink + 1 end
        end
        if ink == 0 or ink > LETTERS.pool then return false end
        local measure = self.measure
        measure:SetFontObject(font)
        local placed, L = Header.ArcPlace(letters, function(text)
            measure:SetText(text)
            return Width(measure)
        end)
        if L + 2 > NAME.room then return false end
        local used = 0
        self.placed = {}
        for _, place in ipairs(placed) do
            if place.letter ~= " " then
                used = used + 1
                local text = self.letters[used]
                text:SetFontObject(font)
                text:SetText(place.letter)
                Letter(text, place, em, lineH)
                text:Show()
                self.placed[used] = place
            end
        end
        return true
    end

    -- Fills it for `record` ({ race, class, ... }), their `name` (as
    -- written: mixed case), the `who` line and the diary `entry`'s tags;
    -- `editing`, the tags put away for the form.
    function h:Set(record, name, who, entry, editing)
        if not (Style.SetRaceIcon(self.icon, record) or Style.SetClassIcon(self.icon, record and record.class)) then
            Style.SetTexture(self.icon, "book", 0.3, 0.22, 0.12, 1)
            self.icon:SetTexCoord(unpack(Style.ICON_CROP))
        end

        self.editing = editing
        Mount(self, editing and p or list)
        if editing then
            sheet:ClearAllPoints()
            sheet:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
            sheet:Show()
        else
            OnRow(self)
        end

        -- The name, a size down rather than lose its end; past the
        -- smallest, cut at its room (the client ends it in an ellipsis).
        local text = self.name
        text:SetText(name or "")
        local size
        for _, step in ipairs(NAME.sizes) do
            text:SetFontObject(FONT[step[1]])
            self.nameSize, size = step[1], step[2]
            if Width(text) + 2 <= NAME.room then break end
        end
        local nw = math.min(NAME.room, Width(text) + 2)
        -- On the baseline, its line measured as the client lays it; where
        -- its ink lies, for the tests.
        local top, lineH, inkTop, inkFoot = Header.NameLine(size, math.ceil(text:GetStringHeight() or 0))
        self.nameInk = { inkTop, inkFoot }
        text:ClearAllPoints()
        text:SetPoint("LEFT", sheet, "TOPLEFT", NAME.x, -(top + lineH / 2))
        text:SetSize(nw, lineH)
        -- The arc, or the whole string straight where it may not be.
        self.flat = ns.Setting("flatSheets") == true
        for _, letter in ipairs(self.letters) do letter:Hide() end
        self.placed = nil
        self.arced = not self.flat and self.turnsText
            and LayArc(self, name or "", FONT[self.nameSize], lineH / GOOD.line, lineH) or false
        text:SetAlpha(self.arced and 0 or 1)

        self:SetRelation(entry and not editing and entry.relationship or nil, nw)
        self.who:SetText(who or "")
        local whoW = Width(self.who) + 2
        local right = self:SetTags(not editing and entry or nil, whoW)
        local ww = math.min(whoW, right - WHO.x)
        Box(self.who, WHO.x, WHO.y, ww, WHO.h)
        -- Where it lies (x, width, middle), for the tests.
        self.whoBox = { WHO.x, ww, WHO.y + WHO.h / 2 }
    end

    -- The relationship at the end of the name's line, after a name `nw` wide.
    function h:SetRelation(relationship, nw)
        local rel = self.relationship
        rel:SetText(relationship or "")
        local room = SHEET.right - (NAME.x + nw + RELATION.gap)
        local full = Width(rel) + 2
        local w = math.min(full, room)
        rel:SetShown(relationship ~= nil and (w == full or w >= RELATION.least))
        rel:ClearAllPoints()
        rel:SetPoint("RIGHT", sheet, "TOPLEFT", SHEET.right, -RELATION.y)
        rel:SetSize(math.max(w, 0), TAGS.h)
    end

    -- The tags after a who line `whoW` wide: all of them, unless they would
    -- leave it less than WHO.least. Returns where the who line must end.
    function h:SetTags(entry, whoW)
        local tags = entry and entry.tags or {}
        local shown = math.min(#tags, TAGS.most)
        for i = 1, shown do self.chips[i]:SetTag(tags[i]) end
        local function Total(n)
            local w = n > 0 and TAGS.clear or 0
            for i = 1, n do w = w + self.chips[i].w + (i > 1 and TAGS.gap or 0) end
            return w
        end
        local least = math.min(whoW, WHO.least)
        while shown > 0 and WHO.x + least + Total(shown) > SHEET.right do shown = shown - 1 end
        local whoEnd = SHEET.right - Total(shown)
        local x = math.min(WHO.x + whoW, whoEnd) + TAGS.clear
        local left = x
        for i, chip in ipairs(self.chips) do
            if i <= shown then
                Box(chip.edge, x, TAGS.y, chip.w, TAGS.h)
                Box(chip.fill, x + 1, TAGS.y + 1, chip.w - 2, TAGS.h - 2)
                Box(chip.label, x + TAGS.pad, TAGS.y, chip.w - 2 * TAGS.pad, TAGS.h)
                chip:Show()
                x = x + chip.w + TAGS.gap
            else
                chip:Hide()
            end
        end
        self.shownTags = shown
        -- Where they lie (left, right, middle), for the tests.
        self.tagsBox = { left, x - TAGS.gap, TAGS.y + TAGS.h / 2 }
        return whoEnd
    end

    return h
end
