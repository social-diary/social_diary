-- The book's cover and the sheets like it (Style, from UI/Style/Tokens.lua):
-- the leather cover with its brass corners (Style.Cover), the loose sheet
-- the entry editor sits on outside the journal (Style.EntryPaper), the book
-- closed for the parcel at login (Style.ClosedBook), and a plate pasted onto
-- the page (Style.PastedPlate). The open book, its ribbons and the brass are
-- in UI/Style/Book.lua, which loads first.

local addonName, ns = ...

local Style = ns.Style
-- The brass (UI/Style/Book.lua), and the book's shadow on the world.
local BRASS_LIGHT, BRASS_MID, BRASS_DARK = Style.BRASS_LIGHT, Style.BRASS_MID, Style.BRASS_DARK
local BOOK_SHADOW, BOOK_SHADOW_ALPHA = Style.BOOK_SHADOW, Style.BOOK_SHADOW_ALPHA

-- The book's cover, in place of a window frame: a leather board a margin
-- larger than the pages on every side. Lit from the top left, like the
-- game's own art: the board falls from light to shadow across its face, its
-- edge is raised (light top and left, shadow bottom and right), the leather
-- is mottled twice (dark and light, at different crops), the gold tooling is
-- pressed in, and the brass corner guards are shaded metal casting a shadow
-- on the leather. The spine darkens across the middle; the pages shadow the
-- board all round; the book shadows the world. `spineX` is the fold, from
-- the frame's left.
local LEATHER = { 0.32, 0.14, 0.07 }
local HINGE = 26  -- the hinge grooves, either side of the spine
local SPINE_BULGE = 7  -- how far the spine's back stands out at the bottom
local SPINE_NOTCH = 7  -- and how deep it curves in at the top
local SPINE_HALF, SPINE_STEP = HINGE + 2, 2

-- Leather grime: { texcoords, tint, alpha }. Different crops (and so
-- different feature sizes), one of them flipped.
local LEATHER_GRIME = {
    { { 0.05, 0.85, 0.10, 0.70 }, { 0.12, 0.06, 0.03 }, 0.26 },
    { { 0.95, 0.55, 0.95, 0.35 }, { 0.10, 0.05, 0.02 }, 0.18 },
}

-- Brass wear, one entry per arm (two per corner, eight in all): where in the
-- grime texture its crop starts (u, v), then tarnish and patina strength.
local BRASS_TARNISH, BRASS_PATINA = { 0.22, 0.14, 0.05 }, { 0.30, 0.42, 0.32 }
local BRASS_WEAR = {
    { 0.10, 0.30, 0.32, 0.08 }, { 0.55, 0.20, 0.22, 0.12 },
    { 0.32, 0.68, 0.36, 0.05 }, { 0.71, 0.58, 0.27, 0.09 },
    { 0.18, 0.82, 0.20, 0.14 }, { 0.62, 0.05, 0.34, 0.06 },
    { 0.44, 0.40, 0.25, 0.11 }, { 0.05, 0.12, 0.30, 0.04 },
}

-- A frame's shadow on the world, `size` out below and to the right: a strip
-- down the right side and one along the bottom, each fading out, and in the
-- corner between them a square that fades both ways, row by row, so the
-- strips meet without overlapping into a dark block.
local function DropShadow(frame, size)
    local function Texture() return frame:CreateTexture(nil, "BACKGROUND", nil, -8) end
    local right = Texture()
    right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -size)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, 0)
    Style.Shade(right, "HORIZONTAL", 0, 0, 0, BOOK_SHADOW_ALPHA, 0)
    local below = Texture()
    below:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", size, 0)
    below:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -size)
    Style.Shade(below, "VERTICAL", 0, 0, 0, 0, BOOK_SHADOW_ALPHA)
    for row = 0, size - 1 do
        local corner = Texture()
        corner:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT", 0, -row)
        corner:SetSize(size, 1)
        Style.Shade(corner, "HORIZONTAL", 0, 0, 0, BOOK_SHADOW_ALPHA * (1 - (row + 0.5) / size), 0)
    end
end

function Style.Cover(frame, margin, spineX)
    local function Texture(sublevel)
        return frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    end
    local function Between(texture, a, ax, ay, b, bx, by)
        texture:SetPoint(a, frame, a, ax, ay)
        texture:SetPoint(b, frame, b, bx, by)
        return texture
    end
    -- A strip `size` thick along one side, from point `a` to point `b` on
    -- that side. Its thickness has to be set: two points on the same side
    -- leave it open, and the client then falls back to the art's own size
    -- (1024 wide for the grime) or to nothing for a plain colour.
    local function Strip(texture, a, ax, ay, b, bx, by, size)
        Between(texture, a, ax, ay, b, bx, by)
        if a:find("LEFT") and b:find("RIGHT") then texture:SetHeight(size) else texture:SetWidth(size) end
        return texture
    end
    local function Solid(sublevel, r, g, b, a)
        local texture = Texture(sublevel)
        texture:SetColorTexture(r, g, b, a)
        return texture
    end

    -- The book's shadow on the world.
    DropShadow(frame, BOOK_SHADOW)

    -- Every layer that spans the board's width leaves out the spine column
    -- [c1, c2], which is built from strips below so its top edge can curve
    -- in. `band` is "full", "top" or "bottom" (then `height` tall, `dy` in
    -- from that edge); `paint(texture, u1, u2)` styles a piece covering the
    -- fractions u1..u2 of the width, so gradients and texture crops carry on
    -- across the gap.
    local W = frame:GetWidth()
    local c1, c2 = spineX - SPINE_HALF, spineX + SPINE_HALF
    local function Split(sublevel, band, height, dy, paint)
        for _, piece in ipairs({ { 0, c1 }, { c2, W } }) do
            local x1, x2 = piece[1], piece[2]
            local texture = Texture(sublevel)
            if band == "full" then
                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, 0)
                texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x2, 0)
            elseif band == "top" then
                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, -dy)
                texture:SetPoint("TOPRIGHT", frame, "TOPLEFT", x2, -dy)
                texture:SetHeight(height)
            else
                texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, dy)
                texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x2, dy)
                texture:SetHeight(height)
            end
            paint(texture, x1 / W, x2 / W)
        end
    end
    local function Mix(a, b, t)
        local out = {}
        for i = 1, #a do out[i] = a[i] + (b[i] - a[i]) * t end
        return out
    end
    local function Flat(color)
        return function(texture) texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    end
    local function Ramp(orientation, from, to)
        return function(texture, u1, u2)
            if orientation == "HORIZONTAL" then
                Style.Gradient(texture, orientation, Mix(from, to, u1), Mix(from, to, u2))
            else
                Style.Gradient(texture, orientation, from, to)
            end
        end
    end

    -- The boards, mottled.
    Split(-7, "full", nil, 0, Flat(LEATHER))
    local path = Style.Art("grain")
    if path then
        for _, layer in ipairs({
            { { 0.9, 0.05, 0.1, 0.95 }, { 0.35, 0.14, 0.06 }, 0.55 },  -- dark blotches
            { { 0.2, 0.75, 0.6, 0.05 }, { 1.00, 0.62, 0.40 }, 0.16 },  -- worn, lighter patches
        }) do
            local l, r, t, b = unpack(layer[1])
            Split(-6, "full", nil, 0, function(mottle, u1, u2)
                mottle:SetTexture(path)
                mottle:SetTexCoord(l + (r - l) * u1, l + (r - l) * u2, t, b)
                mottle:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
                mottle:SetAlpha(layer[3])
            end)
        end
    end

    -- Grime: two dark layers at different crops and scales, so the dirt
    -- drifts unevenly instead of lying like a pattern; then lighter scuffing
    -- in a band round the edges, where hands wear a cover.
    local grime = Style.Art("grime")
    local function Grime(texture, crop, u1, u2, tint, alpha)
        local l, r, t, b = crop[1], crop[2], crop[3], crop[4]
        texture:SetTexture(grime)
        texture:SetTexCoord(l + (r - l) * u1, l + (r - l) * u2, t, b)
        texture:SetVertexColor(tint[1], tint[2], tint[3])
        texture:SetAlpha(alpha)
    end
    if grime then
        for _, layer in ipairs(LEATHER_GRIME) do
            Split(-6, "full", nil, 0, function(texture, u1, u2)
                Grime(texture, layer[1], u1, u2, layer[2], layer[3])
            end)
        end

        local band, SCUFF = 10, { 1, 0.80, 0.60 }
        Split(-6, "top", band, 0, function(texture, u1, u2)
            Grime(texture, { 0.0, 1.0, 0.20, 0.24 }, u1, u2, SCUFF, 0.08)
        end)
        Split(-6, "bottom", band, 0, function(texture, u1, u2)
            Grime(texture, { 1.0, 0.0, 0.70, 0.74 }, u1, u2, SCUFF, 0.10)
        end)
        for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT", { 0.40, 0.44, 0.0, 1.0 } },
            { "TOPRIGHT", "BOTTOMRIGHT", { 0.86, 0.90, 1.0, 0.0 } } }) do
            local texture = Strip(Texture(-6), side[1], 0, 0, side[2], 0, 0, band)
            Grime(texture, side[3], 0, 1, SCUFF, 0.09)
        end
    end

    -- Light across the face: brighter top left, darker bottom right.
    local LIGHT_FACE, DARK_FACE = { 1, 0.85, 0.65, 0.10 }, { 0, 0, 0, 0.22 }
    Split(-5, "full", nil, 0, Ramp("HORIZONTAL", LIGHT_FACE, DARK_FACE))
    Split(-5, "full", nil, 0, Ramp("VERTICAL", { 0, 0, 0, 0.30 }, { 1, 0.85, 0.65, 0.08 }))

    -- Worn edges, darker toward every side.
    local w = 16
    Style.Shade(Strip(Texture(-4), "TOPLEFT", 0, 0, "BOTTOMLEFT", 0, 0, w), "HORIZONTAL", 0, 0, 0, 0.40, 0)
    Style.Shade(Strip(Texture(-4), "TOPRIGHT", 0, 0, "BOTTOMRIGHT", 0, 0, w), "HORIZONTAL", 0, 0, 0, 0, 0.50)
    Split(-4, "top", w, 0, Ramp("VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.30 }))
    Split(-4, "bottom", w, 0, Ramp("VERTICAL", { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 }))

    -- A raised edge: dark outline, light top and left, shadow bottom and right.
    local function Edge(sublevel, a, ax, ay, b, bx, by, thickness, color)
        Strip(Solid(sublevel, color[1], color[2], color[3], color[4]), a, ax, ay, b, bx, by, thickness)
    end
    local OUTLINE, LIGHT, SHADOW = { 0, 0, 0, 0.95 }, { 1, 0.80, 0.58, 0.30 }, { 0, 0, 0, 0.45 }
    Split(-3, "top", 1, 0, Flat(OUTLINE))
    Split(-3, "bottom", 1, 0, Flat(OUTLINE))
    Edge(-3, "TOPLEFT", 0, 0, "BOTTOMLEFT", 0, 0, 1, OUTLINE)
    Edge(-3, "TOPRIGHT", 0, 0, "BOTTOMRIGHT", 0, 0, 1, OUTLINE)
    Split(-3, "top", 2, 1, Flat(LIGHT))
    Edge(-3, "TOPLEFT", 1, -1, "BOTTOMLEFT", 1, 1, 2, LIGHT)
    Split(-3, "bottom", 2, 1, Flat(SHADOW))
    Edge(-3, "TOPRIGHT", -1, -1, "BOTTOMRIGHT", -1, 1, 2, SHADOW)

    -- The spine column. Seen in perspective its top end curves away, so the
    -- edge dips in (an arc SPINE_NOTCH deep) where the bottom end bulges out
    -- (below). Strips carry the leather, the light falling down the face and
    -- the hollow darkening toward the middle, with the outline on the arc.
    local function Notch(x)
        local d = (x - spineX) / SPINE_HALF
        return SPINE_NOTCH * math.sqrt(math.max(0, 1 - d * d))
    end
    for x = c1, c2 - SPINE_STEP, SPINE_STEP do
        local middle = x + SPINE_STEP / 2
        local hollow = 0.10 + 0.55 * (1 - math.abs(middle - spineX) / SPINE_HALF)
        local inset = Notch(middle)
        local top = Mix(LEATHER, { 1, 0.85, 0.65 }, 0.08)
        local bottom = Mix(LEATHER, { 0, 0, 0 }, 0.30)

        local strip = Texture(-7)
        strip:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -inset)
        strip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x + SPINE_STEP, 0)
        Style.Gradient(strip,
            "VERTICAL", { bottom[1] * (1 - hollow), bottom[2] * (1 - hollow), bottom[3] * (1 - hollow), 1 },
            { top[1] * (1 - hollow), top[2] * (1 - hollow), top[3] * (1 - hollow), 1 })

        local rim = Solid(-3, OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
        rim:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -inset)
        rim:SetSize(SPINE_STEP, 1)
    end
    local base = Solid(-3, OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
    base:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", c1, 0)
    base:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", c2, 0)
    base:SetHeight(1)

    -- A line between two points, each { point, x, y } on the frame.
    local function Line(sublevel, from, to, color, horizontal)
        local line = Solid(sublevel, color[1], color[2], color[3], color[4])
        local function Row(point) return point:find("^TOP") and "TOP" or "BOTTOM" end
        line:SetPoint(horizontal and (Row(from[1]) .. "LEFT") or "TOP", frame, from[1], from[2], from[3])
        line:SetPoint(horizontal and (Row(to[1]) .. "RIGHT") or "BOTTOM", frame, to[1], to[2], to[3])
        if horizontal then line:SetHeight(1) else line:SetWidth(1) end
    end

    -- The hinges: a pressed groove each side of the spine, light on its
    -- far lip. They start below the arc.
    for _, x in ipairs({ spineX - HINGE, spineX + HINGE }) do
        local below = -math.ceil(Notch(x)) - 1
        Line(-3, { "TOPLEFT", x, below }, { "BOTTOMLEFT", x, 0 }, { 0, 0, 0, 0.7 })
        Line(-3, { "TOPLEFT", x + 1, below }, { "BOTTOMLEFT", x + 1, 0 }, { 1, 0.80, 0.58, 0.22 })
    end

    -- Tooled gold line, pressed in, one frame per board: its dark lip sits
    -- up and to the left.
    local t, gap = 6, HINGE + 6
    local LIP, GOLD = { 0, 0, 0, 0.55 }, { 0.86, 0.68, 0.36, 0.55 }
    for _, board in ipairs({ { t, spineX - gap, "TOPLEFT", "BOTTOMLEFT", "TOPLEFT", "BOTTOMLEFT" },
        { spineX + gap, -t, "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local x1, x2, top1, bottom1, top2, bottom2 = unpack(board)
        for _, line in ipairs({ { LIP, -1, 1 }, { GOLD, 0, 0 } }) do
            local color, dx, dy = line[1], line[2], line[3]
            Line(-2, { top1, x1 + dx, -t + dy }, { top2, x2 + dx, -t + dy }, color, true)
            Line(-2, { bottom1, x1 + dx, t + dy }, { bottom2, x2 + dx, t + dy }, color, true)
            Line(-2, { top1, x1 + dx, -t + dy }, { bottom1, x1 + dx, t + dy }, color)
            Line(-2, { top2, x2 + dx, -t + dy }, { bottom2, x2 + dx, t + dy }, color)
        end
    end

    -- At the top and bottom of the fold you see down into the hollow back
    -- of the spine, and the headband: red and gold thread round the pages.
    local circle = Style.Art("circle")
    local dip = Style.GUTTER_DIP
    for _, vertical in ipairs({ { "TOPLEFT", -1 }, { "BOTTOMLEFT", 1 } }) do
        local point, sign = vertical[1], vertical[2]
        local edgeY = sign * (margin + dip)

        local hollow = Texture(-1)
        hollow:SetSize(2 * HINGE - 6, 18)
        hollow:SetPoint("CENTER", frame, point, spineX, edgeY)
        Style.Disc(hollow, 0, 0, 0, circle and 0.7 or 0.5)

        local band = Solid(2, 0.12, 0.05, 0.02, 1)
        band:SetSize(18, 7)
        band:SetPoint("CENTER", frame, point, spineX, edgeY - sign * 2)
        for i = 1, 4 do
            local red = i % 2 == 1
            local thread = Solid(3, red and 0.58 or 0.86, red and 0.10 or 0.66, red and 0.07 or 0.30, 1)
            thread:SetSize(4, 5)
            thread:SetPoint("LEFT", band, "LEFT", 1 + (i - 1) * 4, 0)
        end
        local shine = Solid(4, 1, 0.9, 0.7, 0.35)
        shine:SetPoint("TOPLEFT", band, "TOPLEFT", 1, -1)
        shine:SetPoint("TOPRIGHT", band, "TOPRIGHT", -1, -1)
        shine:SetHeight(1)
    end

    -- At the bottom the spine's rounded back bulges past the boards' edge:
    -- half an oval of leather between the hinges, outlined, its underside in
    -- shadow. (At the top it curves away instead; see the spine column.)
    if circle then
        local width, rise = 2 * HINGE + 4, SPINE_BULGE
        -- The lower half of the circle, hung from the boards' bottom edge.
        local function Half(sublevel, w, h, color)
            local half = Texture(sublevel)
            half:SetTexture(circle)
            half:SetTexCoord(0, 1, 0.5, 1)
            half:SetVertexColor(color[1], color[2], color[3], color[4])
            half:SetSize(w, h)
            half:SetPoint("TOP", frame, "BOTTOMLEFT", spineX, 0)
            return half
        end
        Half(5, width + 2, rise + 1, { 0, 0, 0, 0.95 })
        Half(6, width, rise, { LEATHER[1] * 0.9, LEATHER[2] * 0.9, LEATHER[3] * 0.9, 1 })
        Half(7, width - 8, rise - 2, { 0, 0, 0, 0.35 })
    end

    -- The pages' shadow on the board, all round. frame:FitPages moves it in
    -- to where the stack ends on each side, `left` and `right` pixels in from
    -- the pages' full width (what the book's SetStack returns).
    local d = 7
    local shadows = { Texture(-2), Texture(-2), Texture(-2), Texture(-2) }
    Style.Shade(shadows[1], "HORIZONTAL", 0, 0, 0, 0, 0.55)
    Style.Shade(shadows[2], "HORIZONTAL", 0, 0, 0, 0.55, 0)
    Style.Shade(shadows[3], "VERTICAL", 0, 0, 0, 0.55, 0)
    Style.Shade(shadows[4], "VERTICAL", 0, 0, 0, 0, 0.55)
    function frame:FitPages(left, right)
        local l, r = margin + left, margin + right
        for _, shadow in ipairs(shadows) do shadow:ClearAllPoints() end
        Strip(shadows[1], "TOPLEFT", l - d, -margin, "BOTTOMLEFT", l - d, margin, d)
        Strip(shadows[2], "TOPRIGHT", -r + d, -margin, "BOTTOMRIGHT", -r + d, margin, d)
        Strip(shadows[3], "TOPLEFT", l, -margin + d, "TOPRIGHT", -r, -margin + d, d)
        Strip(shadows[4], "BOTTOMLEFT", l, margin - d, "BOTTOMRIGHT", -r, margin - d, d)
    end
    frame:FitPages(0, 0)

    -- Brass corner guards: an L along each edge and a domed rivet.
    local arm, thick = 30, 9
    local wear = 0
    for _, corner in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 },
        { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local point, sx, sy = corner[1], corner[2], corner[3]
        for _, horizontal in ipairs({ true, false }) do
            wear = wear + 1
            local w, h = horizontal and arm or thick, horizontal and thick or arm

            -- Its shadow on the leather, down and to the right.
            local cast = Solid(-1, 0, 0, 0, 0.45)
            cast:SetSize(w, h)
            cast:SetPoint(point, frame, point, 2, -2)

            local outline = Solid(0, BRASS_DARK[1], BRASS_DARK[2], BRASS_DARK[3], 1)
            outline:SetSize(w, h)
            outline:SetPoint(point, frame, point, 0, 0)

            -- Metal, light where it faces the light.
            local metal = Texture(1)
            metal:SetSize(w - 2, h - 2)
            metal:SetPoint(point, frame, point, sx, sy)
            local light = { BRASS_LIGHT[1], BRASS_LIGHT[2], BRASS_LIGHT[3], 1 }
            local dark = { BRASS_MID[1] * 0.75, BRASS_MID[2] * 0.75, BRASS_MID[3] * 0.75, 1 }
            if horizontal then
                Style.Gradient(metal, "VERTICAL", dark, light)
            else
                Style.Gradient(metal, "HORIZONTAL", light, dark)
            end

            -- Tarnish and a little patina, cropped differently on every arm.
            if grime then
                local spot = BRASS_WEAR[wear]
                for _, layer in ipairs({ { spot[1], spot[2], BRASS_TARNISH, spot[3] },
                    { spot[2], spot[1], BRASS_PATINA, spot[4] } }) do
                    local u, v = layer[1], layer[2]
                    local du, dv = horizontal and 0.24 or 0.07, horizontal and 0.07 or 0.24
                    local texture = Texture(2)
                    texture:SetAllPoints(metal)
                    texture:SetTexture(grime)
                    texture:SetTexCoord(u, u + du, v, v + dv)
                    texture:SetVertexColor(layer[3][1], layer[3][2], layer[3][3])
                    texture:SetAlpha(layer[4])
                end
            end

            -- A bright edge along the side the light catches.
            local shine = Solid(2, 1, 0.95, 0.75, 0.7)
            shine:SetPoint("TOPLEFT", metal, "TOPLEFT")
            if horizontal then
                shine:SetPoint("TOPRIGHT", metal, "TOPRIGHT")
                shine:SetHeight(1)
            else
                shine:SetPoint("BOTTOMLEFT", metal, "BOTTOMLEFT")
                shine:SetWidth(1)
            end
        end

        -- The rivet: a dark dome with a highlight up and to the left.
        for i, part in ipairs({ { 6, BRASS_DARK, 0, 0 }, { 4, BRASS_MID, 0, 0 }, { 2, BRASS_LIGHT, -0.7, 0.7 } }) do
            local dot = Texture(2 + i)
            dot:SetSize(part[1], part[1])
            dot:SetPoint("CENTER", frame, point, sx * 5 + part[3], sy * 5 + part[4])
            Style.Disc(dot, part[2][1], part[2][2], part[2][3], 1)
        end
    end
end

-- A loose page on its own, for the entry editor outside the journal: the
-- journal's paper, grain and edge shading on one sheet, two more sheets
-- askew underneath, and its shadow on the world.
local UNDER_SHEETS = { { -1.6, -6, -4, 0.90 }, { 1.1, 5, -6, 0.94 } }  -- degrees, dx, dy, shade

function Style.EntryPaper(frame)
    local P, INK = Style.PAPER, Style.INK

    DropShadow(frame, 12)

    for _, under in ipairs(UNDER_SHEETS) do
        local angle, dx, dy, shade = math.rad(under[1]), under[2], under[3], under[4]
        local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        edge:SetPoint("TOPLEFT", dx - 1, dy + 1)
        edge:SetPoint("BOTTOMRIGHT", dx + 1, dy - 1)
        edge:SetColorTexture(INK[1], INK[2], INK[3], 0.55)
        edge:SetRotation(angle)
        local sheet = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        sheet:SetPoint("TOPLEFT", dx, dy)
        sheet:SetPoint("BOTTOMRIGHT", dx, dy)
        sheet:SetColorTexture(P[1] * shade, P[2] * shade, P[3] * shade, 1)
        sheet:SetRotation(angle)
    end

    local leaf = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    leaf:SetAllPoints()
    leaf:SetColorTexture(P[1], P[2], P[3], 1)

    local function Edge(a, b, size, orientation, from, to)
        local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        edge:SetPoint(a)
        edge:SetPoint(b)
        if orientation == "HORIZONTAL" then edge:SetWidth(size) else edge:SetHeight(size) end
        Style.Shade(edge, orientation, INK[1], INK[2], INK[3], from, to)
    end
    Edge("TOPLEFT", "BOTTOMLEFT", 22, "HORIZONTAL", 0.24, 0)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 22, "HORIZONTAL", 0, 0.24)
    Edge("TOPLEFT", "TOPRIGHT", 5, "VERTICAL", 0, 0.22)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", 5, "VERTICAL", 0.22, 0)

    Style.Hairline(frame, "BACKGROUND", -4, Style.HAIRLINE)

    -- The grain follows `/sd art grain` as the book's does: frame.grain in
    -- book.grain's shape, and ApplyGrain to call on SD_PAPER_CHANGED.
    frame.grain = {}
    local path = Style.Art("grain")
    if path then
        for _, layer in ipairs({ { { 0.10, 0.95, 0.02, 0.98 }, 0.18 }, { { 0.90, 0.20, 0.95, 0.15 }, 0.08 } }) do
            local grain = frame:CreateTexture(nil, "BORDER", nil, 0)
            grain:SetAllPoints()
            grain:SetTexture(path)
            grain:SetTexCoord(unpack(layer[1]))
            frame.grain[#frame.grain + 1] = { texture = grain, alpha = layer[2] }
        end
    end

    function frame:ApplyGrain()
        for _, layer in ipairs(self.grain) do layer.texture:SetAlpha(layer.alpha * Style.GrainStrength()) end
    end
    frame:ApplyGrain()
end

--------------------------------------------------------------------------
-- The book closed
--------------------------------------------------------------------------

-- The journal shut, seen from the front, for the parcel at login
-- (UI/Windows/Intro/Torn.lua). It is the open book's material (Style.Cover): the
-- same leather, mottled and grimed the same way, lit from the top left, its
-- edge raised; the hinge groove beside the spine on the left; a tooled gold
-- frame pressed in, its dark lip up and to the left, and a fainter one inside
-- it; the title in gold capitals with a rule and a lozenge under it; brass
-- guards on the two outer corners; the headband peeping out at the top of
-- the spine; and the pages' edges showing past the board at the fore edge
-- and the foot. In its own coordinates, x right and y down from the board's
-- top left:
--   block   the pages: in from the spine, and how far they show past the
--           fore edge and the foot
--   hinge   the groove's x, and its dark, light and dark widths
--   tool    the gold frame's insets (left, top, right, bottom), the inner
--           one's further inset, and their alphas
--   title   the title's top; the rule's gap under it, each half's length
--           and the lozenge's size
--   guard   the corner guards' arm, thickness and how far they stand out
--   head    the headband: x, y (above the board) and size
--   shadow  its shadow on what it lies on: down, right and dark
local CLOSED = {
    block = { left = 10, top = 5, fore = 3, foot = 4 },
    hinge = { x = 16, widths = { 2, 3, 1 } },
    tool = { left = 32, top = 12, right = 12, bottom = 12, inner = 6, alpha = 0.60, innerAlpha = 0.38 },
    title = { top = 92, gap = 14, half = 24, lozenge = 5 },
    guard = { arm = 26, thick = 8, out = 2 },
    head = { x = 3, y = -4, w = 12, h = 5 },
    shadow = { 3, 4, 0.30 },
}
local PAGE_EDGES = { { 0.91, 0.85, 0.69 }, { 0.80, 0.72, 0.54 } }
local TOOL_GOLD, TOOL_LIP = { 0.86, 0.68, 0.36 }, { 0, 0, 0, 0.55 }

-- Returns the frame, `w` by `h`, with `shadows` (for "Flat paper only" to
-- take away), `title` and `count` (how many textures it took).
function Style.ClosedBook(parent, w, h, title)
    local C = CLOSED
    local book = CreateFrame("Frame", nil, parent)
    book:SetSize(w, h)
    book.shadows, book.count = {}, 0

    local function Texture(layer, sublevel)
        book.count = book.count + 1
        return book:CreateTexture(nil, layer, nil, sublevel)
    end
    local function Rect(layer, sublevel, x, y, rw, rh, colour)
        local texture = Texture(layer, sublevel)
        texture:SetPoint("TOPLEFT", book, "TOPLEFT", x, -y)
        texture:SetSize(rw, rh)
        if colour then texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1) end
        return texture
    end

    -- Its shadow, then the pages: a block of paper with a darker line
    -- between every other leaf where it shows.
    local B = C.block
    local bw, bh = w - B.left + B.fore, h - B.top + B.foot
    local S = C.shadow
    book.shadows[1] = Rect("BACKGROUND", -8, B.left + S[1], B.top + S[2], bw, bh, { 0, 0, 0, S[3] })
    Rect("BACKGROUND", -7, B.left, B.top, bw, bh, PAGE_EDGES[1])
    for x = w + 1, w + B.fore - 1, 2 do Rect("BACKGROUND", -6, x, B.top + 1, 1, bh - 1, PAGE_EDGES[2]) end
    for y = h + 1, h + B.foot - 1, 2 do Rect("BACKGROUND", -6, B.left + 1, y, bw - 1, 1, PAGE_EDGES[2]) end

    -- The board: leather, mottled and grimed as the open cover is.
    Rect("BACKGROUND", -5, 0, 0, w, h, LEATHER)
    local grain = Style.Art("grain")
    if grain then
        for _, layer in ipairs({
            { { 0.9, 0.05, 0.1, 0.95 }, { 0.35, 0.14, 0.06 }, 0.55 },  -- dark blotches
            { { 0.2, 0.75, 0.6, 0.05 }, { 1.00, 0.62, 0.40 }, 0.16 },  -- worn, lighter patches
        }) do
            local mottle = Rect("BACKGROUND", -4, 0, 0, w, h)
            mottle:SetTexture(grain)
            mottle:SetTexCoord(unpack(layer[1]))
            mottle:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
            mottle:SetAlpha(layer[3])
        end
    end
    local grime = Style.Art("grime")
    if grime then
        for _, layer in ipairs(LEATHER_GRIME) do
            local dirt = Rect("BACKGROUND", -4, 0, 0, w, h)
            dirt:SetTexture(grime)
            dirt:SetTexCoord(unpack(layer[1]))
            dirt:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
            dirt:SetAlpha(layer[3])
        end
    end

    -- Light across the face, brighter top left; darker toward the spine
    -- and the fore edge.
    Style.Gradient(Rect("BACKGROUND", -3, 0, 0, w, h), "HORIZONTAL", { 1, 0.85, 0.65, 0.08 }, { 0, 0, 0, 0.18 })
    Style.Gradient(Rect("BACKGROUND", -3, 0, 0, w, h), "VERTICAL", { 0, 0, 0, 0.25 }, { 1, 0.85, 0.65, 0.10 })
    Style.Shade(Rect("BACKGROUND", -2, 0, 0, 14, h), "HORIZONTAL", 0, 0, 0, 0.40, 0)
    Style.Shade(Rect("BACKGROUND", -2, w - 12, 0, 12, h), "HORIZONTAL", 0, 0, 0, 0, 0.45)

    -- A raised edge: a dark outline, light top and left, shadow bottom and
    -- right.
    local OUTLINE, LIGHT, SHADOW = { 0, 0, 0, 0.95 }, { 1, 0.80, 0.58, 0.30 }, { 0, 0, 0, 0.45 }
    Rect("BORDER", 0, 0, 0, w, 1, OUTLINE)
    Rect("BORDER", 0, 0, h - 1, w, 1, OUTLINE)
    Rect("BORDER", 0, 0, 0, 1, h, OUTLINE)
    Rect("BORDER", 0, w - 1, 0, 1, h, OUTLINE)
    Rect("BORDER", 1, 1, 1, w - 2, 2, LIGHT)
    Rect("BORDER", 1, 1, 1, 2, h - 2, LIGHT)
    Rect("BORDER", 1, 1, h - 3, w - 2, 2, SHADOW)
    Rect("BORDER", 1, w - 3, 1, 2, h - 2, SHADOW)

    -- The hinge: dark, light on its far lip, dark again.
    local x = C.hinge.x
    for i, colour in ipairs({ { 0, 0, 0, 0.45 }, { 1, 0.80, 0.58, 0.12 }, { 0, 0, 0, 0.20 } }) do
        local width = C.hinge.widths[i]
        Rect("BORDER", 2, x, 1, width, h - 2, colour)
        x = x + width
    end

    -- Tooled gold: a frame pressed in, its lip up and to the left, and a
    -- fainter one inside it.
    local T = C.tool
    local function Frame(x1, y1, x2, y2, colour, alpha)
        local c = { colour[1], colour[2], colour[3], alpha }
        Rect("BORDER", 3, x1, y1, x2 - x1 + 1, 1, c)
        Rect("BORDER", 3, x1, y2, x2 - x1 + 1, 1, c)
        Rect("BORDER", 3, x1, y1, 1, y2 - y1 + 1, c)
        Rect("BORDER", 3, x2, y1, 1, y2 - y1 + 1, c)
    end
    local x1, y1, x2, y2 = T.left, T.top, w - T.right, h - T.bottom
    Frame(x1 - 1, y1 - 1, x2 - 1, y2 - 1, TOOL_LIP, TOOL_LIP[4])
    Frame(x1, y1, x2, y2, TOOL_GOLD, T.alpha)
    Frame(x1 + T.inner, y1 + T.inner, x2 - T.inner, y2 - T.inner, TOOL_GOLD, T.innerAlpha)

    -- The title, centred in the frame, and a rule with a lozenge under it.
    local mid = (x1 + x2) / 2
    book.title = Style.Text(book, Style.FONT.cover)
    book.title:SetJustifyH("CENTER")
    book.title:SetSpacing(3)
    book.title:SetText(title)
    book.title:SetPoint("TOP", book, "TOPLEFT", mid, -C.title.top)
    local L = C.title
    for _, side in ipairs({ -1, 1 }) do
        local rule = Texture("ARTWORK", 0)
        rule:SetSize(L.half, 1)
        rule:SetPoint("CENTER", book.title, "BOTTOM", side * (L.lozenge + 4 + L.half / 2), -L.gap)
        rule:SetColorTexture(TOOL_GOLD[1], TOOL_GOLD[2], TOOL_GOLD[3], 0.7)
    end
    book.count = book.count + 1
    local lozenge = Style.Lozenge(book, "ARTWORK", L.lozenge, TOOL_GOLD, 1)
    lozenge:SetPoint("CENTER", book.title, "BOTTOM", 0, -L.gap)

    -- Brass guards on the outer corners: an L each, shaded metal casting a
    -- shadow on the leather, and a domed rivet.
    local G = C.guard
    for _, corner in ipairs({ { "TOPRIGHT", -1, -1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local point, sx, sy = corner[1], corner[2], corner[3]
        local ox, oy = G.out, sy < 0 and G.out or -G.out
        for _, horizontal in ipairs({ true, false }) do
            local aw, ah = horizontal and G.arm or G.thick, horizontal and G.thick or G.arm
            local function Arm(layer, sublevel, dx, dy, iw, ih)
                local texture = Texture(layer, sublevel)
                texture:SetSize(iw, ih)
                texture:SetPoint(point, book, point, ox + dx, oy + dy)
                return texture
            end
            local cast = Arm("ARTWORK", 1, 2, -2, aw, ah)
            cast:SetColorTexture(0, 0, 0, 0.45)
            book.shadows[#book.shadows + 1] = cast
            Arm("ARTWORK", 2, 0, 0, aw, ah):SetColorTexture(BRASS_DARK[1], BRASS_DARK[2], BRASS_DARK[3], 1)
            local metal = Arm("ARTWORK", 3, sx, sy, aw - 2, ah - 2)
            local light = { BRASS_LIGHT[1], BRASS_LIGHT[2], BRASS_LIGHT[3], 1 }
            local dark = { BRASS_MID[1] * 0.75, BRASS_MID[2] * 0.75, BRASS_MID[3] * 0.75, 1 }
            if horizontal then
                Style.Gradient(metal, "VERTICAL", dark, light)
            else
                Style.Gradient(metal, "HORIZONTAL", light, dark)
            end
            local shine = Texture("ARTWORK", 4)
            shine:SetColorTexture(1, 0.95, 0.75, 0.7)
            shine:SetPoint("TOPLEFT", metal, "TOPLEFT")
            if horizontal then
                shine:SetPoint("TOPRIGHT", metal, "TOPRIGHT")
                shine:SetHeight(1)
            else
                shine:SetPoint("BOTTOMLEFT", metal, "BOTTOMLEFT")
                shine:SetWidth(1)
            end
        end
        for i, part in ipairs({ { 5, BRASS_DARK, 0, 0 }, { 3, BRASS_MID, 0, 0 }, { 1.5, BRASS_LIGHT, -0.5, 0.5 } }) do
            local dot = Texture("ARTWORK", 4 + i)
            dot:SetSize(part[1], part[1])
            dot:SetPoint("CENTER", book, point, ox + sx * 4 + part[3], oy + sy * 4 + part[4])
            Style.Disc(dot, part[2][1], part[2][2], part[2][3], 1)
        end
    end

    -- The headband over the top of the spine: red and gold thread in a
    -- dark binding.
    local H = C.head
    Rect("BACKGROUND", -7, H.x, H.y, H.w, H.h, { 0.12, 0.05, 0.02, 1 })
    for i = 1, 3 do
        local red = i % 2 == 1
        Rect("BACKGROUND", -6, H.x + 1 + (i - 1) * 3.4, H.y + 1, 3.4, H.h - 2,
            red and { 0.58, 0.10, 0.07 } or { 0.86, 0.66, 0.30 })
    end

    return book
end


-- A plate pasted onto the page, `w` by `h` at x, y (y down): a sheet of
-- paper a shade lighter than the page, with its grain; its shadow, down and
-- to the right; the glue soaked through at its corners, unevenly; and an
-- engraved frame, a hairline per pixel of each rule, with a lozenge in each
-- corner over it, red and lapis by turns. The bookplate (UI/Journal/Front.lua)
-- and the frontispiece's figure (UI/Journal/Frontispiece.lua). P is its look:
-- paper, grain, rules ({ inset, width, alpha }), lozenge, lozengeInset,
-- glue ({ size, alpha }), shadows ({ drop, alpha }).
function Style.PastedPlate(parent, x, y, w, h, P)
    local INK = Style.INK
    local plate = CreateFrame("Frame", nil, parent)
    plate:SetSize(w, h)
    plate:SetPoint("TOPLEFT", x, -y)

    for i, shadow in ipairs(P.shadows) do
        local s = plate:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
        s:SetPoint("TOPLEFT", shadow.drop, -shadow.drop)
        s:SetPoint("BOTTOMRIGHT", shadow.drop, -shadow.drop)
        s:SetColorTexture(INK[1], INK[2], INK[3], shadow.alpha)
    end
    local paper = plate:CreateTexture(nil, "BACKGROUND", nil, -4)
    paper:SetAllPoints()
    paper:SetColorTexture(P.paper[1], P.paper[2], P.paper[3], 1)
    local grainPath = Style.Art("grain")
    if grainPath then
        local grain = plate:CreateTexture(nil, "BACKGROUND", nil, -3)
        grain:SetAllPoints()
        grain:SetTexture(grainPath)
        grain:SetTexCoord(0.31, 0.58, 0.12, 0.47)
        plate.grain = grain
        local function Apply() grain:SetAlpha(P.grain * Style.GrainStrength()) end
        Apply()
        ns.On("SD_PAPER_CHANGED", Apply)
    end

    local glue = { 1, 0.7, 0.85, 1.25 }
    for i, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local g = plate:CreateTexture(nil, "BACKGROUND", nil, -2)
        g:SetSize(P.glue.size, P.glue.size)
        g:SetPoint("CENTER", plate, corner)
        Style.Disc(g, INK[1], INK[2], INK[3], P.glue.alpha * glue[i])
    end

    -- The frames only give each hairline its place; the lines are drawn on
    -- the plate itself, so the lozenges lie over them.
    for _, rule in ipairs(P.rules) do
        for step = 0, rule.width - 1 do
            local inset = rule.inset + step
            local place = CreateFrame("Frame", nil, plate)
            place:SetPoint("TOPLEFT", inset, -inset)
            place:SetPoint("BOTTOMRIGHT", -inset, inset)
            Style.Hairline(plate, "BORDER", 0, rule.alpha, place)
        end
    end
    for i, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMLEFT" }) do
        local l = Style.Lozenge(plate, "ARTWORK", P.lozenge, i % 2 == 1 and Style.RUBRIC or Style.LAPIS)
        local dx = corner:find("LEFT") and P.lozengeInset or -P.lozengeInset
        local dy = corner:find("TOP") and -P.lozengeInset or P.lozengeInset
        l:SetPoint("CENTER", plate, corner, dx, dy)
    end
    return plate
end
