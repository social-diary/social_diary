-- Drawing on the page (Style, from UI/Style/Tokens.lua): a round spot,
-- gradients and soft shades, ink hairlines, the book's noise, and the
-- strokes, curves, arrows, lozenges, hand-drawn rings, four-point quads and
-- torn edges the pages and cards are drawn with. Loaded before
-- UI/Style/Book.lua, which takes Style.Noise as it loads. The art these
-- draw with is UI/Style/Art.lua's; the widgets built from them are in
-- UI/Style/Widgets.lua and UI/Style/Person.lua.

local addonName, ns = ...

local Style = ns.Style

-- A round spot of colour: the circle art tinted, else a flat square of the
-- same colour. Returns whether it came out round.
function Style.Disc(texture, r, g, b, a)
    local circle = Style.Art("circle")
    if circle then
        texture:SetTexture(circle)
        texture:SetVertexColor(r, g, b, a)
    else
        texture:SetColorTexture(r, g, b, a)
    end
    return circle ~= nil
end

-- A two-colour gradient, each colour { r, g, b, a }: `from` at the start of
-- `orientation` (left, or bottom for VERTICAL), `to` at the end. SetGradient
-- takes colour objects in current clients; where that fails, a flat wash at
-- the average is close enough.
function Style.Gradient(texture, orientation, from, to)
    texture:SetColorTexture(1, 1, 1, 1)
    local ok = CreateColor and pcall(texture.SetGradient, texture, orientation,
        CreateColor(from[1], from[2], from[3], from[4]), CreateColor(to[1], to[2], to[3], to[4]))
    if not ok then
        texture:SetColorTexture((from[1] + to[1]) / 2, (from[2] + to[2]) / 2, (from[3] + to[3]) / 2,
            (from[4] + to[4]) / 2)
    end
end

-- A soft edge in one colour: alpha `from` at the start, `to` at the end.
function Style.Shade(texture, orientation, r, g, b, from, to)
    Style.Gradient(texture, orientation, { r, g, b, from }, { r, g, b, to })
end

-- An ink hairline round `target` (the frame itself by default), drawn on
-- `frame` in `layer` and `sublevel`: top, bottom, left, right. `alpha` is
-- one alpha for all four, or { top, bottom, left, right }.
local SIDES = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }

function Style.Hairline(frame, layer, sublevel, alpha, target)
    local INK = Style.INK
    target = target or frame
    for i, side in ipairs(SIDES) do
        local line = frame:CreateTexture(nil, layer, nil, sublevel)
        line:SetPoint(side[1], target)
        line:SetPoint(side[2], target)
        if i <= 2 then line:SetHeight(1) else line:SetWidth(1) end
        line:SetColorTexture(INK[1], INK[2], INK[3], type(alpha) == "table" and alpha[i] or alpha)
    end
end

-- Noise in [0, 1) that is the same every time, so the book does not age
-- differently each time it opens.
local function Noise(n)
    local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)
end
Style.Noise = Noise

-- A straight stroke of ink or pencil on `parent`, from x1, y1 to x2, y2 (x
-- right and y down from its top left), `thickness` wide: a texture turned
-- along it. Where textures cannot turn, nothing is drawn: a stroke is
-- ornament (a margin note's leader, an arrow), never the only signal.
-- `sublevel` orders it within its layer.
function Style.Stroke(parent, layer, x1, y1, x2, y2, colour, alpha, thickness, sublevel)
    local stroke = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
    if not stroke.SetRotation then
        stroke:Hide()
        return stroke
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    stroke:SetSize(length + 0.5, thickness or 1)
    stroke:SetPoint("CENTER", parent, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    stroke:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
    -- Turned on the screen, where y runs up.
    stroke:SetRotation(math.atan2(-dy, dx))
    if stroke.SetSnapToPixelGrid then
        stroke:SetSnapToPixelGrid(false)
        stroke:SetTexelSnappingBias(0)
    end
    return stroke
end

-- A curve drawn as short strokes: the quadratic from x1, y1 to x2, y2 that
-- bends toward the control point cx, cy, in `steps` pieces.
function Style.Curve(parent, layer, x1, y1, cx, cy, x2, y2, colour, alpha, thickness, steps)
    steps = steps or 10
    local strokes = {}
    local px, py = x1, y1
    for i = 1, steps do
        local t = i / steps
        local u = 1 - t
        local x = u * u * x1 + 2 * u * t * cx + t * t * x2
        local y = u * u * y1 + 2 * u * t * cy + t * t * y2
        strokes[i] = Style.Stroke(parent, layer, px, py, x, y, colour, alpha, thickness)
        px, py = x, y
    end
    return strokes
end

-- A pencilled arrow on `parent` (x right, y down from its top left): a
-- curve from `from` bending toward `bend`, ending in a head at `to`, two
-- strokes `head` long back from the point, either side of the way it came
-- in. For the onboarding pages' pointers down to the ribbons.
function Style.Arrow(parent, layer, from, bend, to, alpha, head)
    local G = Style.GRAPHITE
    Style.Curve(parent, layer, from[1], from[2], bend[1], bend[2], to[1], to[2], G, alpha, 1.2, 9)
    local back = math.atan2(bend[2] - to[2], bend[1] - to[1])
    for _, side in ipairs({ -0.5, 0.5 }) do
        local t = back + side
        Style.Stroke(parent, layer, to[1], to[2], to[1] + head * math.cos(t), to[2] + head * math.sin(t),
            G, alpha, 1.2)
    end
end

-- A lozenge: a square of flat colour turned on its point, `size` across.
function Style.Lozenge(parent, layer, size, colour, sublevel)
    local l = parent:CreateTexture(nil, layer, nil, sublevel)
    l:SetSize(size, size)
    l:SetRotation(math.pi / 4)
    l:SetColorTexture(colour[1], colour[2], colour[3], 1)
    return l
end

-- A ring drawn by hand round a centre (x, y on `parent`, y down): an
-- ellipse in rubric red that does not quite close, a little uneven. R is
-- its measure: w, h, how far it overshoots where it began, how unevenly it
-- was drawn, its ink's alpha and its strokes, and `colour` for any ink but
-- rubric. Round "Remember this" on the empty
-- People page (UI/Journal/Empty.lua).
function Style.HandRing(parent, layer, x, y, R)
    local a0 = math.rad(200)
    local sweep = 2 * math.pi * (1 + R.overshoot)
    local px, py
    for i = 0, R.steps do
        local t = a0 + sweep * i / R.steps
        local grow = 1 + R.wobble * math.sin(3 * t) + R.wobble * i / R.steps
        local qx, qy = x + R.w / 2 * grow * math.cos(t), y + R.h / 2 * grow * math.sin(t)
        if px then Style.Stroke(parent, layer, px, py, qx, qy, R.colour or Style.RUBRIC, R.alpha, 1.3) end
        px, py = qx, qy
    end
end

-- A texture on `parent` over any four points (x right, y down from its top
-- left), in the order upper left, upper right, lower right, lower left: a
-- square with its corners moved onto them (SetVertexOffset). A triangle
-- gives one point twice. Where the client cannot move corners it covers
-- the points' box instead, and this returns false, for the caller to hide
-- it or draw something plainer.
local VERTEX = Enum and Enum.VertexIndex or {}
local UL, LL, UR, LR = VERTEX.UpperLeft or 1, VERTEX.LowerLeft or 2, VERTEX.UpperRight or 3, VERTEX.LowerRight or 4

function Style.Quad(texture, parent, x1, y1, x2, y2, x3, y3, x4, y4)
    local left, top = math.min(x1, x2, x3, x4), math.min(y1, y2, y3, y4)
    local w = math.max(math.max(x1, x2, x3, x4) - left, 1)
    local h = math.max(math.max(y1, y2, y3, y4) - top, 1)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
    texture:SetSize(w, h)
    if texture.SetRotation then texture:SetRotation(0) end
    if not texture.SetVertexOffset then return false end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
    -- Offsets from where each corner of the box would be, y up.
    texture:SetVertexOffset(UL, x1 - left, top - y1)
    texture:SetVertexOffset(UR, x2 - (left + w), top - y2)
    texture:SetVertexOffset(LR, x3 - (left + w), top + h - y3)
    texture:SetVertexOffset(LL, x4 - left, top + h - y4)
    return true
end

-- A torn edge of paper on `parent` (x right, y down from its top left): the
-- line from x1, y1 to x2, y2 as `teeth` small triangles of `colour`
-- sticking out to the left of its direction, which is outward when a sheet
-- is gone round clockwise. Each stands up to `depth` px, every other one
-- lower, uneven by `seed`, so the same edge tears the same way every time.
-- Drawn in `layer` and `sublevel`. Returns the edge, its teeth in order;
-- edge:Lay(flat) lays them, evenly when `flat` ("Flat paper only"). Where
-- the client cannot move corners there are no teeth: the paper stays a
-- plain edge.
function Style.TornEdge(parent, layer, sublevel, x1, y1, x2, y2, teeth, depth, seed, colour)
    local Noise = Style.Noise
    local edge = {}
    for i = 1, teeth do
        local tooth = parent:CreateTexture(nil, layer, nil, sublevel)
        tooth:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
        edge[i] = tooth
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.max(math.sqrt(dx * dx + dy * dy), 1)
    local nx, ny = dy / length, -dx / length
    function edge:Lay(flat)
        for i, tooth in ipairs(self) do
            local a, b = (i - 1) / teeth, i / teeth
            -- Its point leans a little along the edge, and stands as high
            -- as it tore.
            local lean = flat and 0 or (Noise(seed + i * 3.1) - 0.5) * 0.7 / teeth
            local high = depth * (i % 2 == 1 and 1 or 0.45) * (flat and 0.7 or (0.3 + 0.7 * Noise(seed + i)))
            local m = (a + b) / 2 + lean
            tooth:SetShown(Style.Quad(tooth, parent,
                x1 + dx * a, y1 + dy * a,
                x1 + dx * m + nx * high, y1 + dy * m + ny * high,
                x1 + dx * b, y1 + dy * b,
                x1 + dx * b, y1 + dy * b))
        end
    end
    return edge
end
