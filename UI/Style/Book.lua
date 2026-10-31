-- The book itself (Style, from UI/Style/Tokens.lua): the open pages with
-- the stack beneath, paper grain, the gutter, the ribbons, and the brass
-- the cover's corners and the medallions share. The cover, the loose sheet
-- and the book closed are in UI/Style/Cover.lua.

local addonName, ns = ...

local Style = ns.Style
local Noise = Style.Noise

--------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------

-- The pages under the open ones, showing at the outer edges as a stack.
-- Each page shows as an edge STACK_STEP pixels wide; a side with more pages
-- than fit in STACK pixels shows finer edges instead, so a thick side reads
-- as a dense block. Lower pages sit a little further out, a little shorter
-- (STACK_DROP per full step, top and bottom) and a little darker, with a
-- fine ink line where each page ends. How many pages lie on each side is
-- the caller's (book:SetStack); where a side has few, the board shows in
-- the rest of the room.
--
-- A handled book is never that regular, so on top of that some pages sit
-- out of line or have slipped (STACK_SHIFTS), one or two have a corner
-- turned down (STACK_DOG_EARS), each page's tone and ink line drift along
-- its length, and damp has foxed it in a few spots. (Grime mottling and
-- dark thumbed bands were tried here and looked wrong in the client.)
local STACK_STEP, STACK_DROP = 2, 1.5
local STACK = 12

-- Per side (left, then right), per page from the top, repeating down the
-- stack: { how far it stands out of line (negative: tucked in), how much
-- taller it is at the top, and at the bottom }, in pixels. How far out is
-- for full-width edges, and shrinks with finer ones.
local STACK_SHIFTS = {
    { { 0, 0, 0 }, { 1, 1, 0 }, { 0, 0, -1 }, { -1, 0, 1 }, { 0, -1, 0 }, { 0, 1, 1 }, { 1, 0, 0 } },
    { { 0, 0, 1 }, { 0, -1, 0 }, { 1, 2, 0 }, { 0, 0, -1 }, { 1, 0, 2 }, { 0, 1, 0 }, { -1, 0, 0 } },
}

-- Tone and ink drift between knots KNOT_MIN to KNOT_MIN + KNOT_SPREAD apart.
local KNOT_MIN, KNOT_SPREAD = 28, 64

-- Foxing: { side, height fraction, page from the top it is on, diameter,
-- alpha }. It is there while its page is.
local STACK_FOXING = {
    { 1, 0.23, 4, 5, 0.30 },
    { 1, 0.71, 2, 4, 0.24 },
    { 2, 0.38, 5, 6, 0.28 },
    { 2, 0.41, 2, 3, 0.22 },
    { 2, 0.80, 3, 4, 0.26 },
}
local FOX = { 0.50, 0.30, 0.12 }

-- Pages in the stack with a corner turned down: { side, page from the
-- top, "top" or "bottom" corner, size in pixels }. In the page's strip the
-- corner is gone (the page beneath shows, or the board when it is the last
-- on its side), then the turned-over flap. Only ever on these pages, never
-- the open ones; on edges too fine for the flap, only the gap shows.
local STACK_DOG_EARS = {
    { 1, 2, "top", 10 },
    { 2, 3, "bottom", 13 },
}

-- Bound pages bow: their top and bottom edges dip toward the binding, by
-- GUTTER_DIP pixels at the fold, easing out over GUTTER_REACH on each side.
-- The cover shows in the dip (Style.Cover puts the headband there).
local GUTTER_DIP, GUTTER_REACH, DIP_STEP = 7, 48, 2
Style.GUTTER_DIP = GUTTER_DIP

-- Shading along the pages' top and bottom edges: { top?, depth, alpha at
-- the edge }. A tight dark band where the cover's lip overhangs the pages,
-- then a long soft falloff.
local EDGE_SHADES = {
    { true, 6, 0.30 },
    { true, 34, 0.14 },
    { false, 5, 0.26 },
    { false, 24, 0.12 },
}

local function Dip(distance)
    local t = math.max(0, 1 - distance / GUTTER_REACH)
    return GUTTER_DIP * t * t
end

local function PageStack(book, height)
    local P, INK = Style.PAPER, Style.INK
    local circle = Style.Art("circle")
    -- Wear that `/sd art grain` scales, with the paper grain.
    book.grain = {}

    -- Per side, a function that lays it out with `count` pages and returns
    -- how far in from the outer edge the stack ends.
    local layouts = {}

    for s, side in ipairs({ -1, 1 }) do
        -- Textures per sublevel, made as the stack first needs them and
        -- handed out again each time it is laid out; the rest are hidden.
        local pools = {}

        -- A rectangle `near`..`far` in from this side's outer edge and
        -- `top`..`bottom` down from the top.
        local function Place(sublevel, near, far, top, bottom)
            local pool = pools[sublevel]
            if not pool then
                pool = { used = 0 }
                pools[sublevel] = pool
            end
            pool.used = pool.used + 1
            local texture = pool[pool.used]
            if not texture then
                texture = book:CreateTexture(nil, "BACKGROUND", nil, sublevel)
                -- Edges finer than a pixel blend in instead of snapping away.
                if texture.SetSnapToPixelGrid then
                    texture:SetSnapToPixelGrid(false)
                    texture:SetTexelSnappingBias(0)
                end
                pool[pool.used] = texture
            end
            texture:ClearAllPoints()
            if side < 0 then
                texture:SetPoint("TOPLEFT", book, "TOPLEFT", near, -top)
                texture:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", far, -bottom)
            else
                texture:SetPoint("TOPLEFT", book, "TOPRIGHT", -far, -top)
                texture:SetPoint("BOTTOMRIGHT", book, "TOPRIGHT", -near, -bottom)
            end
            texture:Show()
            return texture
        end
        -- Flat colour as a gradient, so a texture handed out again does not
        -- keep the gradient it had before.
        local function Flat(texture, colour)
            Style.Gradient(texture, "VERTICAL", colour, colour)
        end

        -- A strip whose colour drifts along its length: `Tone(n)` is the
        -- { r, g, b, a } at knot n, and each piece blends between two knots.
        local function Drift(sublevel, near, far, top, bottom, seed, Tone)
            local y, j, upper = top, 0, Tone(seed)
            while y < bottom do
                j = j + 1
                local y2 = math.min(bottom, y + KNOT_MIN + KNOT_SPREAD * Noise(seed + j + 0.5))
                local lower = Tone(seed + j)
                Style.Gradient(Place(sublevel, near, far, y, y2), "VERTICAL", lower, upper)
                y, upper = y2, lower
            end
        end
        local function Ink(alpha)
            return function(n) return { INK[1], INK[2], INK[3], alpha * (0.25 + Noise(n + 0.25)) } end
        end

        local function Tone(shade, n)
            local tone = shade * (0.97 + 0.06 * Noise(n))
            -- Some stretches have yellowed more than others.
            return { P[1] * tone, P[2] * tone, P[3] * tone * (0.95 + 0.05 * Noise(n + 0.5)), 1 }
        end
        -- Darker the further out from the open page.
        local function Shade(depth) return 0.97 - 0.0175 * depth end

        -- The open page's own edge, over the first page beneath it. Laid
        -- once: the stack's layouts leave this sublevel alone.
        Drift(-6, STACK, STACK + 1, 0, height, s * 1000, Ink(0.35))

        -- A dark core in a fainter halo, per spot on this side.
        local foxing = {}
        if circle then
            for _, spot in ipairs(STACK_FOXING) do
                if spot[1] == s then
                    for _, disc in ipairs({ { 1, 1 }, { 1.8, 0.35 } }) do
                        local texture = book:CreateTexture(nil, "BACKGROUND", nil, -5)
                        texture:SetSize(spot[4] * disc[1], spot[4] * disc[1])
                        texture:SetTexture(circle)
                        texture:SetVertexColor(FOX[1], FOX[2], FOX[3])
                        book.grain[#book.grain + 1] = { texture = texture, alpha = spot[5] * disc[2] }
                        foxing[#foxing + 1] = { texture = texture, spot = spot }
                    end
                end
            end
        end

        layouts[s] = function(count)
            pools[-8] = pools[-8] or { used = 0 }
            pools[-7] = pools[-7] or { used = 0 }
            pools[-8].used, pools[-7].used = 0, 0
            local step = math.min(STACK_STEP, STACK / math.max(count, 1))
            local scale = step / STACK_STEP
            local inkWidth = math.min(1, step / 2)

            -- Where each page lies. Each shows from its own outer side to
            -- the outer side of the page above; one tucked in behind its
            -- neighbours does not show.
            local pages, above, bottomPage = {}, STACK, nil
            for k = 1, count do
                local shift = STACK_SHIFTS[s][(k - 1) % #STACK_SHIFTS[s] + 1]
                local outer = STACK - k * step - shift[1] * scale
                local drop = k * STACK_DROP * scale
                pages[k] = {
                    outer = outer, above = above,
                    top = math.max(0, drop - shift[2]),
                    bottom = height - math.max(0, drop - shift[3]),
                }
                if outer < above then bottomPage = k end
                above = math.min(above, outer)
            end

            for k, page in ipairs(pages) do
                local outer, above, top, bottom = page.outer, page.above, page.top, page.bottom
                local seed = s * 1000 + k * 100
                if outer < above then
                    local width = above - outer
                    -- A turned-down corner, row by row from the corner:
                    -- where `x + row < size` (x in from the page's outer
                    -- side) the corner is gone, then comes the flap and
                    -- its fold.
                    local ear = {}
                    for _, dog in ipairs(STACK_DOG_EARS) do
                        if dog[1] == s and dog[2] == k then ear[dog[3]] = dog[4] end
                    end
                    for corner, size in pairs(ear) do
                        for row = 0, size - 1 do
                            local y = corner == "top" and top + row or bottom - row - 1
                            local fold = size - row
                            if k < count then
                                -- The page beneath, in the flap's shadow.
                                Flat(Place(-8, outer, outer + math.min(fold, width), y, y + 1),
                                    Tone(Shade(STACK - outer + step) * 0.90, seed + row))
                            end
                            if fold < width then
                                Flat(Place(-8, outer + fold, above, y, y + 1),
                                    Tone(Shade(STACK - outer) * 1.04, seed + row))
                                Flat(Place(-7, outer + fold, outer + fold + inkWidth, y, y + 1),
                                    { INK[1], INK[2], INK[3], 0.45 })
                            end
                        end
                    end
                    local from, to = top + (ear.top or 0), bottom - (ear.bottom or 0)
                    Drift(-8, outer, above, from, to, seed, function(n) return Tone(Shade(STACK - outer), n) end)
                    Drift(-7, outer, outer + inkWidth, from, to, seed + 50, Ink(k == bottomPage and 0.55 or 0.30))
                end
            end

            for _, sublevel in ipairs({ -8, -7 }) do
                local pool = pools[sublevel]
                for i = pool.used + 1, #pool do pool[i]:Hide() end
            end

            for _, fox in ipairs(foxing) do
                local page = pages[fox.spot[3]]
                local shown = page ~= nil and page.outer < page.above
                fox.texture:SetShown(shown)
                if shown then
                    fox.texture:ClearAllPoints()
                    fox.texture:SetPoint("CENTER", book, side < 0 and "TOPLEFT" or "TOPRIGHT",
                        -side * (page.outer + page.above) / 2, -fox.spot[2] * height)
                end
            end

            return bottomPage and pages[bottomPage].outer or STACK
        end
    end

    -- Lays the stack out with `left` and `right` pages beneath the open
    -- ones. Returns how far in from the book's left and right edges the
    -- stack now ends, for the board's shadow (Style.Cover's FitPages).
    function book:SetStack(left, right)
        self.stackPages = { left, right }
        return layouts[1](left), layouts[2](right)
    end
    book:SetStack(2, 2)
end

-- The open book: two parchment pages, a gutter between them, darker edges,
-- and the stack of pages beneath showing at the outer edges. Positions on
-- the pages stay measured from the book's own edges; the open pages start
-- STACK in from the outer ones.
function Style.Book(parent, leftWidth, width, height)
    local book = CreateFrame("Frame", nil, parent)
    local BOOK_RIGHT = width - STACK

    -- The page colour: two flat bodies, and narrow strips near the fold that
    -- step down into the dip. Each piece carries its own shading along the
    -- top and bottom edge, so the shadow bends into the dip with the paper.
    local P, INK = Style.PAPER, Style.INK
    local function Paper(x1, x2, inset)
        local strip = book:CreateTexture(nil, "BACKGROUND", nil, -8)
        strip:SetPoint("TOPLEFT", x1, -inset)
        strip:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", x2, inset)
        strip:SetColorTexture(P[1], P[2], P[3], 1)

        for _, shade in ipairs(EDGE_SHADES) do
            local top, depth, alpha = shade[1], shade[2], shade[3]
            local band = book:CreateTexture(nil, "BACKGROUND", nil, -6)
            if top then
                band:SetPoint("TOPLEFT", x1, -inset)
                band:SetPoint("TOPRIGHT", book, "TOPLEFT", x2, -inset)
                band:SetHeight(depth)
                Style.Shade(band, "VERTICAL", INK[1], INK[2], INK[3], 0, alpha)
            else
                band:SetPoint("BOTTOMLEFT", x1, inset)
                band:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", x2, inset)
                band:SetHeight(depth)
                Style.Shade(band, "VERTICAL", INK[1], INK[2], INK[3], alpha, 0)
            end
        end
    end
    Paper(STACK, leftWidth - GUTTER_REACH, 0)
    for d = 0, GUTTER_REACH - DIP_STEP, DIP_STEP do
        local inset = Dip(d + DIP_STEP / 2)
        Paper(leftWidth - d - DIP_STEP, leftWidth - d, inset)
        Paper(leftWidth + d, leftWidth + d + DIP_STEP, inset)
    end
    Paper(leftWidth + GUTTER_REACH, BOOK_RIGHT, 0)
    PageStack(book, height)

    book.paperLeft = book:CreateTexture(nil, "BACKGROUND", nil, -7)
    book.paperLeft:SetPoint("TOPLEFT", STACK, 0)
    book.paperLeft:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", leftWidth, 0)

    book.paperRight = book:CreateTexture(nil, "BACKGROUND", nil, -7)
    book.paperRight:SetPoint("TOPLEFT", leftWidth, 0)
    book.paperRight:SetPoint("BOTTOMRIGHT", -STACK, 0)

    function book:ApplyPaper()
        for _, side in ipairs({ "Left", "Right" }) do
            local texture = self["paper" .. side]
            local path = Style.Art("paper" .. side)
            texture:SetTexture(path)
            texture:SetShown(path ~= nil)
        end
    end
    book:ApplyPaper()
    Style.Grain(book, leftWidth)

    local function Edge(a, ax, b, bx, w, h, orientation, from, to)
        local edge = book:CreateTexture(nil, "BACKGROUND", nil, -6)
        edge:SetPoint(a, ax, 0)
        edge:SetPoint(b, bx, 0)
        if w then edge:SetWidth(w) else edge:SetHeight(h) end
        Style.Shade(edge, orientation, INK[1], INK[2], INK[3], from, to)
    end
    Edge("TOPLEFT", STACK, "BOTTOMLEFT", STACK, 26, nil, "HORIZONTAL", 0.32, 0)
    Edge("TOPRIGHT", -STACK, "BOTTOMRIGHT", -STACK, 26, nil, "HORIZONTAL", 0, 0.32)

    Style.Gutter(book, leftWidth, height)

    return book
end

-- Uneven age over the flat page: the stationery texture twice per page, at
-- different crops, flips and strengths so the layers drift against each
-- other and neither page mirrors the other, plus a few faint stains. Each
-- entry is { page, texcoords (l, r, t, b), alpha }; `page` 1 is the left.
-- Drawn in the BORDER layer, above the page colour and the ribbon, so the
-- ribbon takes the same grain and the cloth and paper read as one surface.
local GRAIN_LAYERS = {
    { 1, { 0.10, 0.95, 0.02, 0.98 }, 0.25 },
    { 1, { 0.90, 0.20, 0.95, 0.15 }, 0.11 },
    { 2, { 0.95, 0.12, 0.04, 0.96 }, 0.21 },
    { 2, { 0.35, 0.92, 0.45, 0.98 }, 0.125 },
}

-- { x, y as fractions of the book, diameter in pixels, alpha }. Each stain is
-- three stacked discs, so its edge steps off instead of ending sharp.
local STAINS = {
    { 0.06, 0.88, 120, 0.044 },
    { 0.27, 0.18, 70, 0.031 },
    { 0.52, 0.80, 170, 0.038 },
    { 0.83, 0.62, 90, 0.031 },
    { 0.95, 0.10, 140, 0.038 },
    { 0.70, 0.95, 60, 0.038 },
}

local grainStrength = 1

-- Adds to book.grain, which PageStack started with the stack's wear.
function Style.Grain(book, leftWidth)
    local path = Style.Art("grain")
    if path then
        for _, layer in ipairs(GRAIN_LAYERS) do
            local texture = book:CreateTexture(nil, "BORDER", nil, 0)
            -- Clear of the dip at the fold, where it would lighten the leather.
            if layer[1] == 1 then
                texture:SetPoint("TOPLEFT", STACK, -GUTTER_DIP)
                texture:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", leftWidth, GUTTER_DIP)
            else
                texture:SetPoint("TOPLEFT", leftWidth, -GUTTER_DIP)
                texture:SetPoint("BOTTOMRIGHT", -STACK, GUTTER_DIP)
            end
            texture:SetTexture(path)
            texture:SetTexCoord(unpack(layer[2]))
            book.grain[#book.grain + 1] = { texture = texture, alpha = layer[3] }
        end
    end

    local circle = Style.Art("circle")
    if circle then
        local INK = Style.INK
        book.stains = {}
        for _, stain in ipairs(STAINS) do
            for step = 1, 3 do
                local size = stain[3] * (1.1 - step * 0.2)
                local disc = book:CreateTexture(nil, "BORDER", nil, 1)
                disc:SetSize(size, size)
                disc:SetTexture(circle)
                disc:SetVertexColor(INK[1], INK[2], INK[3], 1)
                book.stains[#book.stains + 1] = { texture = disc, alpha = stain[4] / 2, x = stain[1], y = stain[2] }
            end
        end
        book:SetScript("OnSizeChanged", function(self, width, height)
            for _, stain in ipairs(self.stains) do
                stain.texture:ClearAllPoints()
                stain.texture:SetPoint("CENTER", self, "TOPLEFT", stain.x * width, -stain.y * height)
            end
        end)
    end

    function book:ApplyGrain()
        for _, layer in ipairs(self.grain) do layer.texture:SetAlpha(layer.alpha * grainStrength) end
        for _, stain in ipairs(self.stains or {}) do stain.texture:SetAlpha(stain.alpha * grainStrength) end
    end
    book:ApplyGrain()
end

-- "Paper Texture Intensity" in the settings, passed in from there, and
-- `/sd art grain <percent>`: 100 is the designed strength, 0 is flat colour.
function Style.SetGrain(percent)
    grainStrength = math.max(0, math.min(percent, 300)) / 100
    ns.Fire("SD_PAPER_CHANGED")
end

-- How strong the grain is now (Style.SetGrain), for the paper that is not
-- the book's: whatever carries the grain art multiplies its alpha by this.
function Style.GrainStrength() return grainStrength end

-- A red cloth bookmark hanging from the top edge of a page, its tail cut in
-- a swallowtail: a paper-coloured diamond over the end makes the notch. The
-- cloth is the journal's red ribbon's (Style.RIBBONS, below).
function Style.Ribbon(book, x, width, length)
    local RED, EDGE = Style.RIBBONS.red.cloth, Style.RIBBONS.red.edge

    local function Piece(sublevel, left, right, r, g, b, a)
        local piece = book:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        piece:SetPoint("TOPLEFT", x + left, 4)
        piece:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", x + width - right, -length)
        piece:SetColorTexture(r, g, b, a)
        return piece
    end

    -- Cloth, darker selvedges, a soft sheen off-centre.
    Piece(-4, 0, 0, RED[1], RED[2], RED[3], 1)
    Piece(-3, 0, width - 2, EDGE[1], EDGE[2], EDGE[3], 1)
    Piece(-3, width - 2, 0, EDGE[1], EDGE[2], EDGE[3], 1)
    Piece(-3, 5, width - 9, 1, 0.55, 0.45, 0.16)

    local notch = book:CreateTexture(nil, "BACKGROUND", nil, -2)
    local size = width * 0.72
    notch:SetSize(size, size)
    notch:SetPoint("CENTER", book, "TOPLEFT", x + width / 2, -length)
    notch:SetColorTexture(Style.PAPER[1], Style.PAPER[2], Style.PAPER[3], 1)
    notch:SetRotation(math.pi / 4)

    -- Its shadow on the page, to the right, where the light falls from.
    local shadow = book:CreateTexture(nil, "BACKGROUND", nil, -5)
    shadow:SetPoint("TOPLEFT", x + width, 0)
    shadow:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", x + width + 4, -length + 6)
    Style.Shade(shadow, "HORIZONTAL", Style.INK[1], Style.INK[2], Style.INK[3], 0.22, 0)
end

-- The journal's page markers: cloth bookmarks that come out from between the
-- pages at the bottom of the book, cross the cover and fall over its edge.
-- Each one is a page of the journal, so they are the navigation: the open
-- page's ribbon hangs longer and in full colour, the others shorter and
-- dimmer.
--
-- Cloth does not fall straight. Past the cover's edge each ribbon lies on
-- the world along its own drape, and the purple one has a half twist in it.
-- To bend, a ribbon is built from RIBBON_STEP-pixel slices down its length,
-- each shifted sideways.
--
-- The light is the book's, from the top left. The ribbon's shadow falls
-- close, down and to the right: in ink on the page, darker on the leather
-- and on the world. Right below the cover the world is already in the
-- book's shadow (DropShadow), which falls across the ribbon too; the ribbon
-- adds no second shadow there, since shade does not darken shade.
--
-- Below the book there is no paper to cut a swallowtail into, so the tail
-- ends in a point instead: a square of the same cloth turned 45 degrees,
-- centred on the end and turned with it. Parented to the book, so the ribbon
-- draws over the cover; it starts a few pixels up the page, where no text
-- sits.
--
-- `drape` is the sideways offset in pixels every RIBBON_KNOT pixels past the
-- cover's edge, with a smooth curve through them; `twist` is { distance past
-- the edge, half its length, how much narrower the cloth looks at its
-- middle }. `sheen` is the light on the cloth, warm by default; grey cloth
-- would turn pink under it.
Style.RIBBONS = {
    red = { cloth = { 0.52, 0.07, 0.05 }, edge = { 0.28, 0.03, 0.02 },
        drape = { 0, -1.2, -3.4, -5.2, -5.8 } },
    purple = { cloth = { 0.34, 0.12, 0.42 }, edge = { 0.17, 0.05, 0.22 },
        drape = { 0, 1.2, 2.6, 5.0, 6.2 }, twist = { 18, 11, 0.22 } },
    gray = { cloth = { 0.40, 0.39, 0.37 }, edge = { 0.21, 0.20, 0.19 },
        drape = { 0, -0.6, -1.4, -1.6, -0.8 }, sheen = { 1, 1, 0.95 } },
    -- Your Diary's (8.11): bottle green, the first ribbon.
    green = { cloth = { 0.15, 0.30, 0.17 }, edge = { 0.06, 0.14, 0.07 },
        drape = { 0, 0.8, 1.6, 3.0, 3.8 }, twist = { 14, 8, 0.18 } },
}
local SHEEN = { 1, 0.6, 0.55 }

-- The book's shadow on the world: how far it reaches, and its alpha at the
-- book's edge, fading to nothing.
local BOOK_SHADOW, BOOK_SHADOW_ALPHA = 14, 0.5
-- The cover and the loose sheet (UI/Style/Cover.lua) cast the same shadow.
Style.BOOK_SHADOW, Style.BOOK_SHADOW_ALPHA = BOOK_SHADOW, BOOK_SHADOW_ALPHA

local RIBBON_TUCK = 8                         -- how far up the page it starts
local RIBBON_HANG = { open = 58, shut = 40 }  -- how far below the book it ends
local RIBBON_DIM = 0.72
local RIBBON_STEP, RIBBON_KNOT = 1, 12
local RIBBON_PARTS = { "shadow", "softLeft", "softRight", "body", "leftEdge", "rightEdge", "sheen", "shade" }
local BLACK = { 0, 0, 0 }

-- The ribbon's shadow, by what it falls on: { offset down and right, colour,
-- alpha, width of its soft edge }.
local RIBBON_CAST = {
    page = { 1.5, Style.INK, 0.42, 2 },
    cover = { 2, BLACK, 0.55, 2.5 },
    world = { 2, BLACK, 0.45, 2.5 },
}

-- The drape's sideways offset `d` pixels past the cover's edge: a
-- Catmull-Rom curve through the knots, level past the last one.
local function Drape(knots, d)
    local f = math.max(0, d) / RIBBON_KNOT
    local i = math.floor(f)
    local t = f - i
    local function K(n) return knots[math.max(1, math.min(#knots, n + 1))] end
    local p0, p1, p2, p3 = K(i - 1), K(i), K(i + 1), K(i + 2)
    return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
        + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
end

-- How much narrower the cloth looks `d` past the edge as it turns through
-- a twist: 0 where it lies flat.
local function Twist(twist, d)
    if not twist then return 0 end
    local t = (d - twist[1]) / twist[2]
    if math.abs(t) >= 1 then return 0 end
    local c = math.cos(t * math.pi / 2)
    return twist[3] * c * c
end

-- The book's shadow `d` pixels below the cover's edge.
local function BookShade(d)
    if d < 0 or d >= BOOK_SHADOW then return 0 end
    return BOOK_SHADOW_ALPHA * (1 - d / BOOK_SHADOW)
end

-- `cover` is how far the cover reaches past the pages.
function Style.BookRibbon(book, x, width, cover, colour, label, onClick)
    local cloth = Style.RIBBONS[colour] or Style.RIBBONS.red
    local edge = RIBBON_TUCK + cover  -- where it goes over the cover's edge

    local ribbon = CreateFrame("Button", nil, book)
    ribbon:SetWidth(width)
    ribbon:SetPoint("TOPLEFT", book, "BOTTOMLEFT", x, RIBBON_TUCK)
    ribbon.label = label

    -- Clicks reach as far as the drape swings, and no further: the
    -- neighbouring ribbon is close.
    local lo, hi = 0, 0
    for _, knot in ipairs(cloth.drape) do lo, hi = math.min(lo, knot), math.max(hi, knot) end
    ribbon:SetHitRectInsets(math.floor(lo), -math.ceil(hi), 0, 0)

    local function Texture(layer, sublevel)
        return ribbon:CreateTexture(nil, layer, nil, sublevel)
    end
    -- `left` and `top` in from the ribbon's top left.
    local function Place(texture, left, top, w, h)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", ribbon, "TOPLEFT", left, -top)
        texture:SetSize(w, h)
        texture:Show()
    end
    local function Cast(texture, colour, from, to)
        if from == to then
            texture:SetColorTexture(colour[1], colour[2], colour[3], from)
        else
            Style.Shade(texture, "HORIZONTAL", colour[1], colour[2], colour[3], from, to)
        end
    end

    -- The slices, made as the ribbon first needs them.
    local slices = {}
    local function Slice(i)
        if not slices[i] then
            slices[i] = {
                shadow = Texture("BACKGROUND", 0),
                softLeft = Texture("BACKGROUND", 0),
                softRight = Texture("BACKGROUND", 0),
                body = Texture("ARTWORK", 0),
                leftEdge = Texture("ARTWORK", 1),
                rightEdge = Texture("ARTWORK", 1),
                sheen = Texture("ARTWORK", 2),
                shade = Texture("ARTWORK", 3),  -- the book's shadow across it
            }
        end
        return slices[i]
    end

    ribbon.tipShadow = Texture("BACKGROUND", 0)
    ribbon.tip = Texture("ARTWORK", 0)

    local count, tipLight = 0, 1

    local function Layout()
        local length = RIBBON_TUCK + (ribbon.active and RIBBON_HANG.open or RIBBON_HANG.shut)
        ribbon:SetHeight(length)

        count = math.ceil(length / RIBBON_STEP)
        for i = count + 1, #slices do
            for _, part in ipairs(RIBBON_PARTS) do slices[i][part]:Hide() end
        end

        for i = 1, count do
            local slice = Slice(i)
            local top = (i - 1) * RIBBON_STEP
            local bottom = math.min(length, top + RIBBON_STEP)
            local mid, h = (top + bottom) / 2, bottom - top
            local narrow = Twist(cloth.twist, mid - edge)
            local w = width * (1 - narrow)
            local left = Drape(cloth.drape, mid - edge) + (width - w) / 2

            Place(slice.body, left, top, w, h)
            Place(slice.leftEdge, left, top, 2, h)
            Place(slice.rightEdge, left + w - 2, top, 2, h)
            -- The sheen keeps its place across the cloth as it turns.
            Place(slice.sheen, left + 5 * w / width, top, 4 * w / width, h)
            slice.light = 1 - 0.7 * narrow
            slice.shine = math.max(0, 1 - 3 * narrow)

            local nearTop, nearBottom = BookShade(top - edge), BookShade(bottom - edge)
            if nearTop > 0 or nearBottom > 0 then
                Place(slice.shade, left, top, w, h)
                Style.Shade(slice.shade, "VERTICAL", 0, 0, 0, nearBottom, nearTop)
            else
                slice.shade:Hide()
            end

            -- Its shadow, cut off where the surface under it ends.
            local surface, ends = "world", length + RIBBON_STEP + 4
            if mid < RIBBON_TUCK then
                surface, ends = "page", RIBBON_TUCK
            elseif mid < edge then
                surface, ends = "cover", edge
            end
            local o, colour, alpha, soft = unpack(RIBBON_CAST[surface])
            if surface == "world" then
                local shade = BookShade(mid + o - edge)
                alpha = math.max(0, (alpha - shade) / (1 - shade))
            end
            local shadowTop = top + o
            local shadowH = math.min(bottom + o, ends) - shadowTop
            if shadowH > 0 and alpha > 0 then
                Place(slice.shadow, left + o, shadowTop, w, shadowH)
                Cast(slice.shadow, colour, alpha, alpha)
                Place(slice.softLeft, left + o - soft, shadowTop, soft, shadowH)
                Cast(slice.softLeft, colour, 0, alpha)
                Place(slice.softRight, left + o + w, shadowTop, soft, shadowH)
                Cast(slice.softRight, colour, alpha, 0)
            else
                slice.shadow:Hide()
                slice.softLeft:Hide()
                slice.softRight:Hide()
            end
        end

        -- The point, turned to the way the cloth runs at the end.
        local d = length - edge
        local narrow = Twist(cloth.twist, d)
        local w = width * (1 - narrow)
        local sway = Drape(cloth.drape, d)
        local angle = math.atan((sway - Drape(cloth.drape, d - 2)) / 2)
        local size = w / math.sqrt(2)
        local o, colour, alpha = unpack(RIBBON_CAST.world)
        for _, part in ipairs({ { ribbon.tip, 0 }, { ribbon.tipShadow, o } }) do
            local texture, shift = part[1], part[2]
            texture:ClearAllPoints()
            texture:SetSize(size, size)
            texture:SetPoint("CENTER", ribbon, "TOPLEFT", sway + width / 2 + shift, -length - shift)
            texture:SetRotation(math.pi / 4 + angle)
        end
        Cast(ribbon.tipShadow, colour, alpha, alpha)
        tipLight = (1 - 0.7 * narrow) * (1 - BookShade(d))
    end

    local hovered = false

    local function Paint()
        local dim = ribbon.active and 1 or RIBBON_DIM
        local c, e, sheen = cloth.cloth, cloth.edge, cloth.sheen or SHEEN
        local function Dye(texture, color, k)
            texture:SetColorTexture(color[1] * k, color[2] * k, color[3] * k, 1)
        end
        for i = 1, count do
            local slice = slices[i]
            local k = dim * slice.light
            Dye(slice.body, c, k)
            Dye(slice.leftEdge, e, k)
            Dye(slice.rightEdge, e, k)
            slice.sheen:SetColorTexture(sheen[1], sheen[2], sheen[3], (hovered and 0.30 or 0.16) * slice.shine)
        end
        Dye(ribbon.tip, c, dim * tipLight)
    end

    function ribbon:SetActive(active)
        self.active = active and true or false
        Layout()
        Paint()
    end

    Style.Tooltip(ribbon, function(self) return { { self.label, 1, 1, 1 } } end, "ANCHOR_BOTTOM",
        function(_, over)
            hovered = over
            Paint()
        end)
    ribbon:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
    end)

    ribbon:SetActive(false)
    return ribbon
end

-- Where the pages meet. Each page curves down into the binding, so the
-- shadow deepens faster the closer it gets: three gradients of falling width
-- stack into that curve. Just before the dip the paper bulges toward the
-- light, so a faint highlight band sits there. A crease line marks the fold
-- itself, and the binding thread shows through it, in the ribbon's red.
--
-- { distance from the fold, width, alpha at the fold side }, mirrored on
-- both pages.
local GUTTER_SHADOWS = {
    { 0, 46, 0.10 },
    { 0, 20, 0.16 },
    { 0, 7, 0.28 },
}
local GUTTER_LIGHT = { 20, 9, 0.10 }  -- distance, half width, peak alpha
local STITCH_SPACING, STITCH_LENGTH = 46, 9

function Style.Gutter(book, x, height)
    local INK = Style.INK

    -- `side` is -1 for the left page, 1 for the right. `from` and `to` are
    -- distances from the fold; alphas follow the same direction.
    local function Band(sublevel, side, from, to, r, g, b, nearAlpha, farAlpha)
        local band = book:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        local left, right = x + side * from, x + side * to
        if side < 0 then left, right = right, left end
        band:SetPoint("TOPLEFT", left, 0)
        band:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", right, 0)
        -- HORIZONTAL runs left to right, so the near end flips with the side.
        if side < 0 then
            Style.Shade(band, "HORIZONTAL", r, g, b, farAlpha, nearAlpha)
        else
            Style.Shade(band, "HORIZONTAL", r, g, b, nearAlpha, farAlpha)
        end
    end

    for _, side in ipairs({ -1, 1 }) do
        for _, shadow in ipairs(GUTTER_SHADOWS) do
            Band(-5, side, shadow[1], shadow[1] + shadow[2], INK[1], INK[2], INK[3], shadow[3], 0)
        end
        local d, half, peak = GUTTER_LIGHT[1], GUTTER_LIGHT[2], GUTTER_LIGHT[3]
        Band(-4, side, d, d + half, 1, 0.97, 0.88, 0, peak)
        Band(-4, side, d + half, d + 2 * half, 1, 0.97, 0.88, peak, 0)
    end

    local crease = book:CreateTexture(nil, "BACKGROUND", nil, -3)
    crease:SetPoint("TOPLEFT", x - 1, -GUTTER_DIP)
    crease:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", x + 1, GUTTER_DIP)
    crease:SetColorTexture(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], 0.45)

    local count = math.floor((height - STITCH_SPACING / 2) / STITCH_SPACING)
    local top = (height - (count - 1) * STITCH_SPACING) / 2
    for i = 1, count do
        local stitch = book:CreateTexture(nil, "BACKGROUND", nil, -2)
        stitch:SetSize(2, STITCH_LENGTH)
        stitch:SetPoint("CENTER", book, "TOPLEFT", x, -(top + (i - 1) * STITCH_SPACING))
        stitch:SetColorTexture(0.40, 0.07, 0.05, 0.8)
    end
end

-- The cover's brass (UI/Style/Cover.lua): its corner guards. The medallions
-- (UI/Style/Person.lua) are ringed in the same brass.
Style.BRASS_LIGHT, Style.BRASS_MID, Style.BRASS_DARK = { 0.96, 0.82, 0.50 }, { 0.70, 0.53, 0.24 },
    { 0.30, 0.20, 0.08 }
