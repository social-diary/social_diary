-- The person's page's header: their name sheet, clipped to the page (the
-- person-page proposal, variant A "Clippings", round 2). A short sheet of
-- a lighter stock than the page holds what stays while the list scrolls:
-- the portrait, their name in Goodmountain (mixed case, never capitals),
-- the who line and their tags. A painted bronze binder clip at its top
-- left holds it to the page's top edge: its hinge and the top of its jaw
-- stand out over the edge, its lip bites sheet and page together over the
-- portrait's corner, and the sheet hangs from it, turned 1.6 degrees
-- against the clock about the clip, its right end risen about 12 px, its
-- top right corner just inside the page.
--
-- The list passes under it: it starts behind the sheet at every x
-- (SHEET.listTop), so rows and the plate slide in under its foot and are
-- cut off behind the paper, never at a frame line; the sheet throws its
-- soft shadow from its foot onto them, from its height (the house light,
-- UI/Paper/Light.lua). Worn a little (none laid flat): a faint dent where
-- the clip's jaw bites, and its bottom right corner lifted, shaded.
--
-- Frames cannot turn, only textures and font strings: the sheet is laid
-- out flat about its middle and every piece placed turned with it (the
-- turned plane, UI/Paper/Surface.lua), as a strip is. The tag chips are
-- textures, so they turn too; the portrait's discs are round and its mask
-- a circle, so only their middles move. Where the client cannot turn text
-- (the strip's probe), or with "Flat paper only", it lies straight. Edit
-- is pencilled on it in graphite with a dashed underline, and stays
-- straight: it is a control, not paper. The clip is art baked by
-- Dev/clip_art.py (Art/Paper/clip.tga, and its shadow).
--
-- Its pieces stay on the page as they were (p.name, p.who, p.chips,
-- p.relationship, p.edit), for the page and the tests.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Surface = ns.UI.Surface
local Width = Surface.Width

local Header = {}
ns.UI.PersonHeader = Header

-- The clip and its shadow (Dev/clip_art.py): each 128 px square, the clip
-- painted at 3.2 texels a px of the screen.
local ART = "Interface\\AddOns\\" .. addonName .. "\\Art\\Paper\\"
Style.AddArt("clip", { ART .. "clip" })
Style.AddArt("clipShadow", { ART .. "clip_shadow" })
Style.AddArt("clipDent", { ART .. "clip_dent" })

-- The sheet, on the right page (466 x 534, y down from its top left):
--   x, y, w, h   where it lies before it turns, and its size
--   pivot        the clip's bite on it, from its top left: what it turns about
--   turn         degrees against the clock (its right end rises)
--   height       how high it stands off the page, for its shadow (px):
--                held up at the clip, a little off the paper under it
--   paper        its stock: lighter than a strip's, a sheet of its own
--   edge         its cut edge in ink (`flatEdge` laid flat); its grain
--   listTop      the list's top: behind the sheet at every x (turned, at
--                the left it spans about -6 to 58, at the right -18 to 46;
--                laid straight, -6 to 58 all along)
--   first        where the list's first line starts: the sheet's foot at
--                its lowest (its bottom left corner, 58.4) and a little
--                room
--   flat         laid flat: a hair of shadow under it, `flat` px at its
--                alpha, so the list still goes under paper
-- The page's paper runs 20 px above the page's frame (UI/Journal/Book.lua's
-- TOP), so its top edge is at y -20 here. The clip bites at the top edge
-- over `pivot` (x 22 of the page), and turned about it the sheet's top
-- right corner rises 432 * sin 1.6 = 12.1 px: with its top at y -6 under
-- the clip, that corner is at -18.1, just inside the page's edge, its
-- inked edge a pixel inside. (20 Oct, in the client: at y 15 the sheet
-- hung some 30 px under the page's top, parchment above it, and a clip
-- holds paper only at the page's edge.)
-- Its height is what the name needs (GOOD and NAME, below): 64, from 50,
-- and the list's top and first line moved down with its foot, 14 px.
-- (21 Oct, in the client: at 50 the tops of "Feivel Emmenthal" rose out
-- of the paper.)
local SHEET = { x = 6, y = -6, w = 448, h = 64, pivot = { 16, 0 }, turn = 1.6, height = 3,
    paper = { 0.95, 0.915, 0.805 }, edge = 0.18, flatEdge = 0.30, grain = 0.12, listTop = 26, first = 61,
    flat = { 2, 0.12 } }
-- Goodmountain's metrics, in ems, from the font's own tables
-- (Fonts/Goodmountain.otf: 1000 units an em, hhea ascender 1000 and
-- descender 210, the glyphs' bounds 1210 up and 257 down): the client lays
-- a line `line` ems tall, `ascent` of it over the baseline, but its tall
-- ascenders and swashes reach `high` over the baseline and `low` under it,
-- out of the line's box. Taken as one em to the font's size (the larger of
-- the ways a client may scale it), so the ink is never under-reckoned.
local GOOD = { line = 1.21, ascent = 1.0, high = 1.21, low = 0.257 }
-- On the sheet (from its top left): the portrait disc, `size` across with
-- its rings (inset, colour: the round portrait's, Style.Portrait, scaled),
-- the race or class icon `zoom` times the inner disc under a round mask;
-- the name's line (`room` px for it before Edit; a long name a size down,
-- `sizes` in turn ({ font, its size }, Style/Tokens.lua's), and past the
-- last cut at the room, never past it): its ink starts `top` px under the
-- sheet's top at the largest size, every size on the same baseline (the
-- largest's ink, GOOD.high ems over it); the who line under the
-- name's lowest ink; the tags on the who line, centred on it in the
-- sheet's turned plane, right-aligned `right` px in from the sheet's edge,
-- chips `gap` apart. The who line gives way to them: it ends at least
-- `clear` px short of them, cut there (the client ends it in an
-- ellipsis); only past the who line's `least` px do the tags give way, a
-- chip at a time, the last first. (21 Oct, the user: the tags belong on
-- the same line as the who line.) Edit on the page, straight, its dashes
-- `dash` long `gap` apart,
-- about 5 px under the sheet's top edge where it lies (moved up with the
-- sheet, 20 Oct).
local PORTRAIT = { x = 8, y = 12, size = 40, zoom = 1.4, pad = 4.5,
    rings = { { 0, { 0, 0, 0 } }, { 1.5, { 0.72, 0.58, 0.33 } }, { 3, { 0, 0, 0 } }, { 3.5, { 0.22, 0.15, 0.08 } } } }
local NAME = { x = 58, top = 4, room = 330,
    sizes = { { "personName", 27 }, { "personNameSmall", 22 }, { "personNameLeast", 17 } } }
NAME.baseline = NAME.top + GOOD.high * NAME.sizes[1][2]
local WHO = { x = 58, y = 44, h = 16, least = 150 }
local TAGS = { right = 14, h = 16, pad = 6, gap = 6, clear = 12, most = 12, edge = 0.35 }
TAGS.y = WHO.y + (WHO.h - TAGS.h) / 2
local EDIT = { x = 408, y = -12, dash = 2, gap = 1.5, alpha = 0.55, hot = 0.9 }
-- The clip: a `size` px square of art (Dev/clip_art.py) with its middle
-- `at` on the sheet; its shadow the same outline's, `shadow` px down and to
-- the right (the lamp at the top left), at `shadowAlpha`, none laid flat.
-- Only its front is drawn (its back lies behind the page): in the art the
-- thin roll where the jaw turns over the page's edge spans y 3.2 to 5.9 of
-- the square, the page's edge falling at 4.4, the jaw runs from 4.6 to its
-- lip at 24.5, 6 to 34 across, and the wire handles down to 34. So here
-- nothing but a pixel of the roll stands over the page's top edge (y -20
-- of the page), the lip bites 6 px into the sheet, from x 2 to 30, and the
-- handles lie folded down over the portrait's corner. (21 Oct, in the
-- client: its back plate and wire stood up past the page's edge.)
local CLIP = { size = 40, at = { 16, 1.6 }, shadow = { 1.3, 1.7 }, shadowAlpha = 1, edge = 4.4, roll = 3.2,
    lip = 24.5 }
-- Wear: the mark the jaw leaves on the sheet, baked by Dev/clip_art.py
-- (Art/Paper/clip_dent.tga) and laid over `w` by `h` at x, y of the sheet,
-- turning with it, under the portrait and the clip: the paper pressed
-- flat and a little sunk in a darker crease right under the lip, a light
-- bow under it where it springs back up toward the lamp (top left, the
-- house light's), and short puckers fanning out from the lip's two ends.
-- Ink and a warm white in one texture, blended as usual, so it darkens and
-- lightens alike. Kept to the clip's corner: it ends at x 48, short of the
-- name (x 58), and over the who line's row. (21 Oct, in the client: two
-- hairlines were too faint to read as a dent.) And the lifted corner, a
-- shade over `w` by `h` at the bottom right, darkest (`alpha`) at the
-- corner. Neither laid flat.
local DENT = { x = 0, y = 2, w = 48, h = 24 }
local CORNER = { w = 38, h = 24, alpha = 0.18 }
Header.SHEET, Header.PORTRAIT, Header.NAME, Header.TAGS, Header.EDIT, Header.CLIP, Header.DENT, Header.CORNER =
    SHEET, PORTRAIT, NAME, TAGS, EDIT, CLIP, DENT, CORNER
Header.GOOD, Header.WHO = GOOD, WHO

-- The name's line at font size `size`, the client measuring its line
-- `measured` px tall: the top of its line's box and its height, and where
-- its ink starts and ends (on the sheet, y down). The line is taken no
-- shorter than GOOD.line ems; its ems from it.
function Header.NameLine(size, measured)
    local lineH = math.max(measured or 0, size * GOOD.line)
    local em = lineH / GOOD.line
    local B = NAME.baseline
    return B - em * GOOD.ascent, lineH, B - em * GOOD.high, B + em * GOOD.low
end

-- The clip's art: the file Style.Art finds, else its own path, as the
-- client may not say it has an addon's own file before it is drawn.
local function ClipArt(key)
    return Style.Art(key) or (Style.ART[key] or {})[1]
end

-- The header on the person's page `p`, over its list `list` (frame levels:
-- the sheet over the list and everything laid in it).
function Header.New(p, list)
    local W, H = SHEET.w, SHEET.h
    local sheet = CreateFrame("Frame", nil, p)
    sheet:SetSize(W, H)
    sheet:SetFrameLevel(list:GetFrameLevel() + 40)
    -- It takes the mouse over itself (rows under it give no tooltip
    -- through the paper) and passes the wheel on to the list.
    sheet:EnableMouse(true)
    sheet:EnableMouseWheel(true)
    sheet:SetScript("OnMouseWheel", function(_, delta) if list.Wheel then list.Wheel(list, delta) end end)

    local function Texture(layer, sublevel)
        local t = sheet:CreateTexture(nil, layer, nil, sublevel)
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end

    local h = { sheet = sheet, p = p }
    h.shadows = { soft = Texture("BACKGROUND", -8), core = Texture("BACKGROUND", -7), right = Texture("BACKGROUND", -7) }
    h.edge = Texture("BACKGROUND", -2)
    h.paper = Texture("BACKGROUND", -1)
    h.sheen = Texture("BACKGROUND", 0)
    local grain = Style.Art("grain")
    if grain then
        h.grain = Texture("BORDER", 0)
        h.grain:SetTexture(grain)
        h.grain:SetAlpha(SHEET.grain)
    end
    h.dent = Texture("BORDER", 1)
    h.corner = Texture("BORDER", 3)
    h.rings = {}
    for i = 1, #PORTRAIT.rings do h.rings[i] = Texture("ARTWORK", i - 1) end
    h.icon = Texture("ARTWORK", 4)
    local circle = Style.Art("circle")
    if circle and sheet.CreateMaskTexture then
        h.mask = sheet:CreateMaskTexture()
        h.mask:SetTexture(circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        h.icon:AddMaskTexture(h.mask)
    end
    h.clipShadow = Texture("OVERLAY", 6)
    h.clip = Texture("OVERLAY", 7)

    -- The writing.
    h.name = Style.Text(sheet, FONT.personName)
    h.name:SetWordWrap(false)
    h.who = Style.Text(sheet, FONT.body)
    h.who:SetWordWrap(false)
    -- The relationship is the user's word: in the hand.
    h.relationship = Style.Text(sheet, FONT.noteQuoted)
    h.relationship:SetWordWrap(false)

    -- The chips: a frame each, to show and hide it whole, its pieces laid
    -- on the sheet's plane.
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

    -- Edit, pencilled on the sheet, straight.
    local edit = CreateFrame("Button", nil, p)
    edit:SetFrameLevel(sheet:GetFrameLevel() + 2)
    edit:SetHeight(18)
    edit:SetPoint("TOPLEFT", p, "TOPLEFT", EDIT.x, -EDIT.y)
    edit.label = Style.Text(edit, FONT.pencil)
    edit.label:SetPoint("LEFT")
    edit.dashes = {}
    function edit:SetText(text)
        self.label:SetText(text)
        local w = math.max(Width(self.label), 8) + 2
        self:SetWidth(w)
        local G, step = Style.GRAPHITE, EDIT.dash + EDIT.gap
        for i = 1, math.ceil(w / step) do
            local dash = self.dashes[i]
            if not dash then
                dash = self:CreateTexture(nil, "ARTWORK")
                self.dashes[i] = dash
            end
            dash:ClearAllPoints()
            dash:SetPoint("TOPLEFT", self.label, "BOTTOMLEFT", (i - 1) * step, -1)
            dash:SetSize(math.min(EDIT.dash, w - (i - 1) * step), 1)
            dash:SetColorTexture(G[1], G[2], G[3], EDIT.alpha)
            dash:Show()
        end
        for i = math.ceil(w / step) + 1, #self.dashes do self.dashes[i]:Hide() end
    end
    function edit:GetText() return self.label:GetText() end
    -- Under the mouse the pencil darkens, as a link does.
    local function Hot(on)
        local C = on and Style.INK or Style.GRAPHITE
        edit.label:SetTextColor(C[1], C[2], C[3])
        for _, dash in ipairs(edit.dashes) do dash:SetColorTexture(C[1], C[2], C[3], on and EDIT.hot or EDIT.alpha) end
    end
    edit:SetScript("OnEnter", function() Hot(true) end)
    edit:SetScript("OnLeave", function() Hot(false) end)
    edit:SetScript("OnClick", function()
        if ns.UI.Journal.selected then ns.UI.ShowEntry(ns.UI.Journal.selected) end
    end)
    edit:SetText("Edit")
    h.edit = edit

    -- The turned plane: the sheet's middle, turned about the clip.
    local plane = Surface.New(sheet)
    local Place, Quad = plane.Place, plane.Quad
    h.turnsText = h.name.SetRotation ~= nil
    h.canBend = h.paper.SetVertexOffset ~= nil

    -- A piece w by h with its top left at x, y of the sheet.
    local function Box(region, x, y, w, ht, more)
        Place(region, x + w / 2 - W / 2, y + ht / 2 - H / 2, w, ht, more)
    end
    -- A line of writing w by ht at x, y, in a box tall enough for its turn
    -- (the strip's TURNED: the client cuts what a turn lifts out of it).
    -- Anchored by its left end, at where its left middle lies turned: the
    -- client turns a font string about its left end, not its middle (a
    -- texture it turns about its middle), so a line laid by its middle was
    -- drawn (w/2) sin t higher than planned, the turn's way. (21 Oct, in
    -- the client: the who line, some 300 px long, drawn about 4 px over
    -- its plan, its tag chips, textures, under it.)
    local function Write(region, x, y, w, ht)
        local turn = h.turn or 0
        local X, Y = plane.Screen(x - W / 2, y + ht / 2 - H / 2)
        region:ClearAllPoints()
        region:SetPoint("LEFT", sheet, "CENTER", X, Y)
        region:SetSize(w, ht + w * math.abs(math.sin(turn)) + 4)
        if region.SetRotation then region:SetRotation(turn) end
    end

    -- Lays the sheet as it lies now: turned, or straight laid flat or
    -- where text cannot turn; its shadow, wear and clip.
    function h:Lay()
        local flat = ns.Setting("flatSheets") == true
        local turn = (flat or not self.turnsText) and 0 or math.rad(SHEET.turn)
        self.turn, self.flat = turn, flat
        local bends = self.canBend and not flat
        -- The middle, turned about the pivot.
        local px, py = SHEET.x + SHEET.pivot[1], SHEET.y + SHEET.pivot[2]
        local mx, my = Surface.Turned(px, py, W / 2 - SHEET.pivot[1], H / 2 - SHEET.pivot[2], math.cos(turn),
            math.sin(turn))
        plane.Set(turn, mx, my, bends)
        self.middle = { mx, my }
        -- Where its corners lie on the page (TL, TR, BR, BL, y down), for
        -- the tests: the page's top edge, the list's top under it.
        local c, s = math.cos(turn), math.sin(turn)
        self.corners = {}
        for i, corner in ipairs({ { 0, 0 }, { W, 0 }, { W, H }, { 0, H } }) do
            local x, y = Surface.Turned(px, py, corner[1] - SHEET.pivot[1], corner[2] - SHEET.pivot[2], c, s)
            self.corners[i] = { x, y }
        end
        sheet:ClearAllPoints()
        sheet:SetPoint("CENTER", p, "TOPLEFT", mx, -my)

        -- The paper, its cut edge, lit across, its grain.
        local P, I = SHEET.paper, Style.INK
        self.paper:SetColorTexture(P[1], P[2], P[3], 1)
        Box(self.paper, 0, 0, W, H)
        self.edge:SetColorTexture(I[1], I[2], I[3], flat and SHEET.flatEdge or SHEET.edge)
        Box(self.edge, -1, -1, W + 2, H + 2)
        if flat then
            self.sheen:Hide()
        else
            ns.UI.Light.Sheen(self.paper, self.sheen, P)
            Box(self.sheen, 0, 0, W, H)
            self.sheen:Show()
        end
        if self.grain then
            self.grain:SetTexCoord(0.13, 0.13 + W / 512, 0.41, 0.41 + H / 512)
            Box(self.grain, 0, 0, W, H)
        end

        -- Its shadow from its foot onto what passes under it: a core and a
        -- soft band, down and to the right, from its height; laid flat, a
        -- hair of shadow only.
        local S = self.shadows
        if flat then
            local d, a = SHEET.flat[1], SHEET.flat[2]
            Style.Shade(S.core, "VERTICAL", I[1], I[2], I[3], 0, a)
            Box(S.core, 0, H, W, d)
            S.core:Show()
            S.soft:Hide()
            S.right:Hide()
        else
            local near, dark = ns.UI.Light.Fall(SHEET.height)
            local far, pale = ns.UI.Light.Fall(SHEET.height, true)
            Style.Shade(S.core, "VERTICAL", I[1], I[2], I[3], pale, dark)
            Box(S.core, near, H, W, near)
            Style.Shade(S.soft, "VERTICAL", I[1], I[2], I[3], 0, pale)
            Box(S.soft, near, H + near, W, far - near)
            Style.Shade(S.right, "HORIZONTAL", I[1], I[2], I[3], dark, 0)
            Box(S.right, W, near, near, H)
            for _, t in pairs(S) do t:Show() end
        end

        -- Wear: the dent under the clip's jaw, the lifted corner.
        local dent = ClipArt("clipDent")
        self.dent:SetShown(dent ~= nil and not flat)
        if dent then
            self.dent:SetTexture(dent)
            Box(self.dent, DENT.x, DENT.y, DENT.w, DENT.h)
        end
        local corner = self.corner
        Style.Shade(corner, "HORIZONTAL", I[1], I[2], I[3], 0, CORNER.alpha)
        local shaded = not flat and Quad(corner, W / 2, H / 2 - CORNER.h, W / 2, H / 2, W / 2, H / 2,
            W / 2 - CORNER.w, H / 2)
        corner:SetShown(shaded == true)

        -- The portrait: its rings, its icon under the round mask.
        local cx, cy = PORTRAIT.x + PORTRAIT.size / 2, PORTRAIT.y + PORTRAIT.size / 2
        for i, ring in ipairs(PORTRAIT.rings) do
            local t, c = self.rings[i], ring[2]
            Style.Disc(t, c[1], c[2], c[3], 1)
            local d = PORTRAIT.size - 2 * ring[1]
            Box(t, cx - d / 2, cy - d / 2, d, d)
        end
        local inner = PORTRAIT.size - 2 * PORTRAIT.pad
        local icon = self.mask and inner * PORTRAIT.zoom or inner
        Box(self.icon, cx - icon / 2, cy - icon / 2, icon, icon)
        if self.mask then Box(self.mask, cx - inner / 2, cy - inner / 2, inner, inner) end

        -- The clip, over the page's edge and the portrait's corner, and its
        -- shadow (none laid flat).
        local file, shade = ClipArt("clip"), ClipArt("clipShadow")
        self.clip:SetShown(file ~= nil)
        if flat then shade = nil end
        self.clipShadow:SetShown(shade ~= nil)
        -- Where its middle lies on the page, for the tests.
        local cx, cy = plane.Out(CLIP.at[1] - W / 2, CLIP.at[2] - H / 2)
        self.clipAt = { cx, cy }
        if file then
            self.clip:SetTexture(file)
            Box(self.clip, CLIP.at[1] - CLIP.size / 2, CLIP.at[2] - CLIP.size / 2, CLIP.size, CLIP.size)
        end
        if shade then
            self.clipShadow:SetTexture(shade)
            self.clipShadow:SetAlpha(CLIP.shadowAlpha)
            Box(self.clipShadow, CLIP.at[1] - CLIP.size / 2 + CLIP.shadow[1],
                CLIP.at[2] - CLIP.size / 2 + CLIP.shadow[2], CLIP.size, CLIP.size)
        end
    end

    -- Fills it for `record` ({ race, class, ... }), their `name` (as
    -- written: mixed case), the `who` line and the diary `entry`'s tags;
    -- `editing`, the tags and Edit put away for the form.
    function h:Set(record, name, who, entry, editing)
        -- The icon first: its art and part set, then turned as it is laid.
        if not (Style.SetRaceIcon(self.icon, record) or Style.SetClassIcon(self.icon, record and record.class)) then
            Style.SetTexture(self.icon, "book", 0.3, 0.22, 0.12, 1)
            self.icon:SetTexCoord(unpack(Style.ICON_CROP))
        end
        self:Lay()

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
        Write(text, NAME.x, top, nw, lineH)
        self.edit:SetShown(not editing)
        -- The tags first, at the who line's right; the who line up to
        -- them, cut short where it would come nearer than TAGS.clear.
        local left = self:SetTags(not editing and entry or nil)
        self.who:SetText(who or "")
        local ww = math.min(Width(self.who) + 2, left - TAGS.clear - WHO.x)
        Write(self.who, WHO.x, WHO.y, ww, WHO.h)
        -- Where it lies on the sheet (x, width, middle), for the tests.
        self.whoBox = { WHO.x, ww, WHO.y + WHO.h / 2 }
    end

    -- The tags on the who line, right-aligned, the relationship last: all
    -- of them, unless they would leave the who line less than WHO.least.
    -- Returns where the leftmost begins (the sheet's right end, less
    -- TAGS.right, where none show).
    function h:SetTags(entry)
        local tags = entry and entry.tags or {}
        local relationship = entry and entry.relationship or nil
        self.relationship:SetText(relationship or "")
        local relW = relationship and (Width(self.relationship) + 2) or 0
        local shown = math.min(#tags, TAGS.most)
        for i = 1, shown do self.chips[i]:SetTag(tags[i]) end
        local function Total(n, rel)
            local w = rel and relW or 0
            for i = 1, n do w = w + self.chips[i].w + ((i > 1 or rel) and TAGS.gap or 0) end
            return w
        end
        local right = W - TAGS.right
        local room = right - (WHO.x + WHO.least + TAGS.clear)
        local rel = relationship ~= nil
        while shown > 0 and Total(shown, rel) > room do shown = shown - 1 end
        if rel and Total(shown, rel) > room then rel = false end
        local x = right - Total(shown, rel)
        local left = x
        for i, chip in ipairs(self.chips) do
            if i <= shown then
                Box(chip.edge, x, TAGS.y, chip.w, TAGS.h)
                Box(chip.fill, x + 1, TAGS.y + 1, chip.w - 2, TAGS.h - 2)
                Write(chip.label, x + TAGS.pad, TAGS.y, chip.w - 2 * TAGS.pad, TAGS.h)
                chip:Show()
                x = x + chip.w + TAGS.gap
            else
                chip:Hide()
            end
        end
        self.relationship:SetShown(rel)
        if rel then Write(self.relationship, x, TAGS.y - 1, relW, TAGS.h + 2) end
        self.shownTags = shown
        -- Where they lie on the sheet (left, right, middle), for the tests.
        self.tagsBox = { left, right, TAGS.y + TAGS.h / 2 }
        return (shown > 0 or rel) and left or right
    end

    sheet:Show()
    return h
end
