-- The hand that draws small things with the diary's pen and watercolour:
-- the free card's sixteen icons (Features/Note/Icons.lua), and whatever a
-- feature draws small on its own paper (a sheet among the plates draws a
-- letter, a lot's tag, a coin beside a stop: the city-trips proposal's hook
-- 5, 24 Nov 2026). It was the free card's (`Hand` in Features/Note/Icons.lua,
-- 19 Nov) and moved here unchanged, so a feature draws without reading
-- another feature; the free card draws through it as before.
--
-- A drawing is a function(h) laid out on a 16-unit square round its middle
-- (x right, y down, within about 7.5 units each way), drawn on `h`, a hand
-- for one drawing at one size, through a mark kit (Plate.MarkKit, a plate's
-- own, or a leaf's: UI/Paper/Leaf.lua's leaf:Kit()), so it turns and is lit
-- with whatever paper it lies on:
--
--   h.Line(pts, weight, closed, alpha)  a pen line through flat u, v, ...
--   h.Ring(cx, cy, rx, ry, a0, a1, weight)  an ellipse or part of one
--   h.Spot(u, v, d, e, turn, alpha)     a solid spot of ink
--   h.Block(u, v, w, h, turn, alpha)    a solid block of ink
--   h.Fill(pigment, cu, cv, pts, r)     a flat wash over a shape
--   h.Bloom(pigment, { { u, v, r } })   paint pooled darker
--   h.Pieces(length)                    how many pieces a curve is cut into
--   h.detail                            drawn large enough for small things
--
--   Sketch.Hand(kit, key, x, y, size)   a hand, centred on x, y, `size` px
--                                       across its 16 units, its stray seeded
--                                       by `key` (a string)
--   Sketch.Register(key, draw)          a drawing any surface may draw by key
--                                       (the free card registers its sixteen:
--                                       "scroll", "hammer", ...; a feature's
--                                       own go under keys of its own)
--   Sketch.Draw(kit, key, x, y, size)   a registered drawing on a mark kit,
--                                       into its pools (the caller begins and
--                                       finishes them); false where `key` is
--                                       not registered
--   Sketch.Known(key)                   whether it is
--   Sketch.Ellipse, Sketch.Bend, Sketch.Join   the drawings' point-makers
--   Sketch.PEN, WASH, PIGMENT, SIZE     the looks
--
-- How it draws: a wash, then the pen over it.
--   The wash is watercolour in a muted pigment (PIGMENT): a flat fill over
--   the shape (triangles from a point inside to its edge, the edge's points
--   a little uneven, as a brush's), and a bloom or two where the paint
--   pooled darker (a disc laid twice a little apart). The whole wash sits a
--   hair down and right of the lines (WASH.shift), as a quick hand tints a
--   drawing, and goes in the kit's `ink` pool, under the pen. Where corners
--   cannot move, a fill is one disc at its middle.
--   The pen is ink lines (the kit's Stroke, in its `inner` pool, over the
--   wash): every line widens and thins with the trail's own nib
--   (ns.UI.Pen.Nib), a joint that turns sharply gets a bead of ink, a free
--   end a round one, and every point is moved a little by a run of numbers
--   seeded by the drawing's key, so the same drawing is drawn by the same
--   hand every time. Solid parts are dots and boxes of ink.
-- Nothing is drawn in paper over ink: the mark kit's pools are three
-- sublevels (halo, ink, inner), and the wash takes one, so every drawing is
-- line and mass on its wash, never a cut-out.

local addonName, ns = ...

local Pen = ns.UI.Pen

local Sketch = {}
ns.UI.Sketch = Sketch

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------

-- The size the pen is weighed at: the free card's mark on a plate
-- (Features/Note/Icons.lua's MARK.size, 13 px across its 16 units), and the
-- size from which the small things are drawn too (MARK.detail: a scroll's
-- lines of writing, the fish's gill); at a mark's size they only thicken
-- the ink into a blot.
local SIZE = { mark = 13, detail = 22 }
Sketch.SIZE = SIZE

-- The pen:
--   weight   a line's width in units at the mark's size (1.55 units = 1.26
--            px, the stroke weight of the plates' marks)
--   grow     how a line widens with the icon: as size ^ grow, not size, so
--            a card's icon is drawn with a finer pen than a blown-up mark
--            (40 px: 2.3 px of ink, not 3.9)
--   least    the thinnest line, px
--   nib      the share of the trail's nib (Pen.Nib, 0.55 along its edge to
--            1.25 across) a line takes: width * (1 - nib + nib * Nib)
--   wobble   how far a point strays, in units (0.13 px on a mark, 0.4 on a
--            card: the hand, never a tremble)
--   bead     a joint turning more than this (radians) gets a dot of ink
--   alpha    the ink's
--   step     a curve is cut into pieces about this many px long, between
--            `pieces` of them
local PEN = { weight = 1.55, grow = 0.55, least = 1.0, nib = 0.35, wobble = 0.16, bead = 0.55, alpha = 0.95,
    step = 2.6, pieces = { 4, 26 } }
Sketch.PEN = PEN

-- The wash:
--   fill     a flat fill's share of its pigment's alpha
--   edge     how far a fill's edge strays in and out, units
--   points   a fill's edge is cut to at most this many points (textures)
--   bloom    a bloom: discs at `alpha` of the pigment's, one a size in
--            `sizes` (of the bloom's), each moved up to `stray` of its
--            radius, so they pool unevenly and the bloom is never a coin
--   shift    the whole wash's offset from the lines, units
-- (19 Nov, rasterised: washes of discs alone read as polka dots at the
-- card's size; a flat fill with a bloom reads as paint.)
local WASH = { fill = 0.9, edge = 0.35, points = 14, bloom = { alpha = 0.3, sizes = { 1, 0.8, 0.62 }, stray = 0.3 },
    shift = { 0.45, 0.35 } }
Sketch.WASH = WASH

-- The pigments: muted, earthy, as a travelling painter's box. None is an
-- item quality's (green, blue, purple, orange washes are the pouch's and the
-- tunic's), so the teal is greyed and the green a sap green. Each { r, g, b,
-- alpha } over the paper.
local PIGMENT = {
    rose = { 0.72, 0.32, 0.26, 0.42 },
    brick = { 0.64, 0.25, 0.15, 0.42 },
    ochre = { 0.80, 0.58, 0.22, 0.45 },
    amber = { 0.84, 0.56, 0.16, 0.45 },
    sienna = { 0.62, 0.34, 0.16, 0.40 },
    umber = { 0.45, 0.32, 0.18, 0.36 },
    slate = { 0.36, 0.42, 0.52, 0.40 },
    indigo = { 0.30, 0.34, 0.50, 0.38 },
    teal = { 0.30, 0.48, 0.50, 0.40 },
    sap = { 0.42, 0.50, 0.24, 0.40 },
    ash = { 0.46, 0.45, 0.40, 0.34 },
    steel = { 0.42, 0.46, 0.50, 0.38 },
}
Sketch.PIGMENT = PIGMENT

--------------------------------------------------------------------------
-- The hand: lines, curves, spots and washes in units
--------------------------------------------------------------------------

local sqrt, cos, sin, abs, pi = math.sqrt, math.cos, math.sin, math.abs, math.pi
local atan2 = math.atan2 or math.atan
local min, max, floor = math.min, math.max, math.floor

-- A string to a seed: the same drawing strays the same way every time.
local function Seed(key)
    local n = 7
    for i = 1, #key do n = (n * 31 + key:byte(i)) % 2147483629 end
    return n
end

-- The points of an ellipse round cx, cy from angle a0 to a1 (radians, y
-- down: -pi/2 is the top), cut into `n` pieces; appended to `out` (flat u,
-- v, ...), which it returns.
local function Ellipse(out, cx, cy, rx, ry, a0, a1, n)
    out = out or {}
    for i = 0, n do
        local a = a0 + (a1 - a0) * i / n
        out[#out + 1] = cx + rx * cos(a)
        out[#out + 1] = cy + ry * sin(a)
    end
    return out
end

-- The points of a quadratic curve from (u0, v0) bent towards (u1, v1) to
-- (u2, v2), `n` pieces, appended to `out` (its first point left out where
-- `from` is false: it continues a line).
local function Bend(out, u0, v0, u1, v1, u2, v2, n, from)
    out = out or {}
    for i = from == false and 1 or 0, n do
        local t = i / n
        local a, b, c = (1 - t) * (1 - t), 2 * t * (1 - t), t * t
        out[#out + 1] = a * u0 + b * u1 + c * u2
        out[#out + 1] = a * v0 + b * v1 + c * v2
    end
    return out
end

-- Appends the flat points of `more` to `pts`; returns `pts`.
local function Join(pts, more)
    for _, p in ipairs(more) do pts[#pts + 1] = p end
    return pts
end

Sketch.Ellipse, Sketch.Bend, Sketch.Join = Ellipse, Bend, Join

-- A hand for one drawing: `kit` a mark kit, the drawing's middle at x, y,
-- `size` px across its 16 units, seeded by `key`.
local function Hand(kit, key, x, y, size)
    local s = size / 16
    local h = { kit = kit, s = s, size = size, detail = size >= SIZE.detail }
    local random = Pen.Random(Seed(key))
    local stray = PEN.wobble * s
    local thick = max(PEN.least, PEN.weight * (SIZE.mark / 16) * (size / SIZE.mark) ^ PEN.grow)
    h.thick = thick
    local ink = kit.INK_STRONG

    local function At(u, v) return x + u * s, y + v * s end
    local function Stray() return (random() * 2 - 1) * stray end

    -- How many pieces a curve `length` units long is cut into, at this size.
    function h.Pieces(length)
        return max(PEN.pieces[1], min(PEN.pieces[2], floor(length * s / PEN.step + 0.5)))
    end

    -- A line through the flat points `pts` (u, v, ...), `weight` times the
    -- pen's width; `closed` joins the last to the first. `alpha` the ink's.
    function h.Line(pts, weight, closed, alpha)
        local n = #pts / 2
        if n < 2 then return end
        local P = {}
        for i = 1, n do
            local px, py = At(pts[2 * i - 1], pts[2 * i])
            P[i] = { px + Stray(), py + Stray() }
        end
        if closed then P[n + 1] = P[1] end
        local w0 = thick * (weight or 1)
        alpha = alpha or PEN.alpha
        local last = #P
        local widths = {}
        for i = 1, last - 1 do
            local a, b = P[i], P[i + 1]
            local w = w0 * (1 - PEN.nib + PEN.nib * Pen.Nib(b[1] - a[1], b[2] - a[2]))
            widths[i] = w
            kit.Stroke(kit.inner, a[1], a[2], b[1], b[2], w, ink, alpha)
        end
        -- A bead where the line turns sharply, and at each free end.
        for i = 2, last - 1 do
            local a, b, c = P[i - 1], P[i], P[i + 1]
            local turn = atan2(c[2] - b[2], c[1] - b[1]) - atan2(b[2] - a[2], b[1] - a[1])
            turn = abs((turn + pi) % (2 * pi) - pi)
            if turn > PEN.bead then
                kit.Dot(kit.inner, b[1], b[2], (widths[i - 1] + widths[i]) / 2, ink, alpha)
            end
        end
        if closed then
            local a, b, c = P[last - 1], P[1], P[2]
            local turn = atan2(c[2] - b[2], c[1] - b[1]) - atan2(b[2] - a[2], b[1] - a[1])
            if abs((turn + pi) % (2 * pi) - pi) > PEN.bead then
                kit.Dot(kit.inner, b[1], b[2], (widths[last - 1] + widths[1]) / 2, ink, alpha)
            end
        else
            kit.Dot(kit.inner, P[1][1], P[1][2], widths[1] * 1.05, ink, alpha)
            kit.Dot(kit.inner, P[last][1], P[last][2], widths[last - 1] * 1.05, ink, alpha)
        end
    end

    -- An ellipse (or part of one) in ink: Ellipse's angles.
    function h.Ring(cx, cy, rx, ry, a0, a1, weight)
        a0, a1 = a0 or 0, a1 or 2 * pi
        local whole = abs(a1 - a0) >= 2 * pi - 1e-6
        local n = h.Pieces(abs(a1 - a0) * (rx + ry) / 2)
        local pts = Ellipse(nil, cx, cy, rx, ry, a0, whole and a1 - (a1 - a0) / n or a1, whole and n - 1 or n)
        h.Line(pts, weight, whole)
    end

    -- A solid spot of ink `d` units across (an ellipse `d` by `e`, turned
    -- `turn` radians, where `e` is given).
    function h.Spot(u, v, d, e, turn, alpha)
        local px, py = At(u, v)
        local texture = kit.Dot(kit.inner, px, py, d * s, ink, alpha or PEN.alpha)
        if e and texture then
            local w, hh = d * s, e * s
            kit.Place(texture, px - w / 2, py - hh / 2, w, hh, turn or 0)
        end
        return texture
    end

    -- A solid block of ink, its middle at u, v.
    function h.Block(u, v, w, hh, turn, alpha)
        local px, py = At(u, v)
        return kit.Box(kit.inner, px, py, w * s, hh * s, ink, alpha or PEN.alpha, turn)
    end

    local shiftU, shiftV = WASH.shift[1], WASH.shift[2]

    -- Blooms of `pigment` (a PIGMENT key), each { u, v, r }: paint pooled.
    function h.Bloom(pigment, blobs)
        local c = PIGMENT[pigment]
        local B = WASH.bloom
        for _, b in ipairs(blobs) do
            local px, py = At(b[1] + shiftU, b[2] + shiftV)
            local d, r = 2 * b[3] * s, b[3] * s * B.stray
            for _, k in ipairs(B.sizes) do
                kit.Dot(kit.ink, px + (random() * 2 - 1) * r, py + (random() * 2 - 1) * r, d * k, c, c[4] * B.alpha)
            end
        end
    end

    -- A flat wash of `pigment` over the shape round (cu, cv) whose edge is
    -- `pts` (flat u, v, ..., in order round it; every edge point seen from
    -- cu, cv). Where corners cannot move: one disc at cu, cv, `r` across.
    function h.Fill(pigment, cu, cv, pts, r)
        local c = PIGMENT[pigment]
        local n = #pts / 2
        local every = math.ceil(n / WASH.points)
        local E = {}
        for i = 1, n, every do
            local d = (random() * 2 - 1) * WASH.edge
            local du, dv = pts[2 * i - 1] - cu, pts[2 * i] - cv
            local len = sqrt(du * du + dv * dv)
            if len > 1e-6 then du, dv = du / len * d, dv / len * d else du, dv = 0, 0 end
            local px, py = At(pts[2 * i - 1] + du + shiftU, pts[2 * i] + dv + shiftV)
            E[#E + 1] = { px, py }
        end
        local mx, my = At(cu + shiftU, cv + shiftV)
        local light = kit.Light(mx, my)
        local alpha = c[4] * WASH.fill
        for i = 1, #E do
            local a, b = E[i], E[i % #E + 1]
            local texture = kit.ink:Next()
            kit.Fill(texture, c[1] * light, c[2] * light, c[3] * light, alpha)
            if not kit.Quad(texture, mx, my, a[1], a[2], b[1], b[2], b[1], b[2]) then
                texture:Hide()
                if i == 1 then kit.Dot(kit.ink, mx, my, (r or 8) * s, c, alpha) end
                break
            end
        end
    end

    return h
end
Sketch.Hand = Hand

--------------------------------------------------------------------------
-- The drawings any surface may draw
--------------------------------------------------------------------------

local DRAWINGS = {}

function Sketch.Register(key, draw)
    assert(type(key) == "string" and type(draw) == "function", "Sketch.Register(key, function(h) ... end)")
    DRAWINGS[key] = draw
end

function Sketch.Known(key)
    return key ~= nil and DRAWINGS[key] ~= nil
end

function Sketch.Draw(kit, key, x, y, size)
    local draw = key and DRAWINGS[key]
    if not draw then return false end
    draw(Hand(kit, key, x, y, size or SIZE.mark))
    return true
end
