-- The diary's own handwriting: notes baked offline by a handwriting model
-- (Fonts/handwriting/, its README's "Into the addon") and kept as pen
-- strokes in UI/Ink/HandData.lua, which the converter writes and which
-- loads after this file. Here a note is drawn with the pen (UI/Ink/Pen.lua)
-- as quads a surface lays: no texture, no font, any size.
--
-- A note is one or more lines, each a few strokes in x-heights from the
-- left end of its baseline, y down, each point with the pen's pressure
-- there (1 = its usual width). Drawn at an x-height of `size` px, the
-- strokes scale with it but the pen does not: a nib is as wide on a small
-- note as on a big one, and only its pressure and the nib's angle vary it.
-- A stroke is split where it turns back on itself (the top of an n, the
-- foot of a d), so no joint is mitred into a spike. Pure arithmetic, like
-- the pen. Its table is ns.UI.Hand; the notes are Hand.NOTES.
--
-- Written with it: nothing at present. Dev/HandTest.lua and tests/hand.lua
-- are all that still read it.

local addonName, ns = ...

local Hand = {}
ns.UI.Hand = Hand

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------

-- The pen the diary's notes are written with: a fine fountain pen.
--   width   the nib's usual width, px, whatever the note's size; each
--           point's pressure ^ `gain` times it, kept within min..max px
--           (thinner than about 0.7 px and a line breaks up on the screen)
--   nib     the nib's edge at `angle` degrees: along it `thin`, across it
--           `thick` of the width (Pen.Nib), a gentler nib than the road's
--   lead    from one line's baseline to the next's, in x-heights
--   corner  a stroke turning more than this (degrees) at a point is split
--           there, each piece running on `over` of its half-width past it
--           so the corner stays closed
--   alpha   the ink's
local HAND = {
    width = 1.15, gain = 0.6, min = 0.75, max = 2.1,
    nib = { angle = 40, thin = 0.8, thick = 1.15 },
    lead = 2.35, corner = 110, over = 0.8, alpha = 0.92,
}
Hand.HAND = HAND

local sqrt, cos, sin, abs, min, max = math.sqrt, math.cos, math.sin, math.abs, math.min, math.max
local atan2 = math.atan2 or math.atan

--------------------------------------------------------------------------
-- The notes
--------------------------------------------------------------------------

-- The baked note `key`, or nil where none was baked.
function Hand.Note(key)
    return key and Hand.NOTES and Hand.NOTES[key] or nil
end

-- How big note `n` is drawn at x-height `size`, its lines `lead` apart
-- (HAND's by default) and each moved right by `indent[i]` px: its width
-- and its height from the first line's tallest letter to the last's
-- lowest, and how far its first baseline lies under that top.
function Hand.Measure(n, size, lead, indent)
    lead = lead or HAND.lead
    local w, lines = 0, n.lines
    for i, line in ipairs(lines) do w = max(w, line.w * size + (indent and indent[i] or 0)) end
    local top = lines[1].up * size
    local h = top + (#lines - 1) * lead * size + lines[#lines].down * size
    return w, h, top
end

--------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------

-- One piece of a stroke (points { x, y, p } in px) stroked with the pen
-- into `out`, each end run on past its point by `over` of its half-width.
local function Piece(out, layer, P, colour, alpha, nibbed)
    local Pen = ns.UI.Pen
    local n = #P
    if n < 2 then return 0 end
    local function Half(i)
        local a, b = P[max(i - 1, 1)], P[min(i + 1, n)]
        local w = HAND.width * P[i].p ^ HAND.gain
        if nibbed then w = w * Pen.Nib(b.x - a.x, b.y - a.y, HAND.nib) end
        return max(HAND.min, min(HAND.max, w)) / 2
    end
    -- The ends run on along the piece, so two pieces meeting at a corner
    -- overlap rather than leave a notch.
    for _, e in ipairs({ { 1, 2 }, { n, n - 1 } }) do
        local p, q = P[e[1]], P[e[2]]
        local dx, dy = p.x - q.x, p.y - q.y
        local len = sqrt(dx * dx + dy * dy)
        if len > 1e-6 then
            local run = Half(e[1]) * HAND.over
            P[e[1]] = { x = p.x + dx / len * run, y = p.y + dy / len * run, p = p.p }
        end
    end
    local M = Pen.Mitres(P)
    return Pen.Stroke(out, layer, P, M, Half, function() return 0 end, function() return alpha end, colour)
end

-- A stroke's points split where it turns back on itself (HAND.corner).
local function Split(P)
    local pieces, cur = {}, { P[1] }
    local sharp = math.rad(HAND.corner)
    for i = 2, #P do
        cur[#cur + 1] = P[i]
        if i < #P then
            local a, b, c = P[i - 1], P[i], P[i + 1]
            local h1, h2 = atan2(b.y - a.y, b.x - a.x), atan2(c.y - b.y, c.x - b.x)
            local turn = abs((h2 - h1 + math.pi) % (2 * math.pi) - math.pi)
            if turn > sharp then
                pieces[#pieces + 1] = cur
                cur = { { x = b.x, y = b.y, p = b.p } }
            end
        end
    end
    pieces[#pieces + 1] = cur
    return pieces
end

-- Note `n` drawn into `out` as the pen's primitives (ns.UI.Pen's quads),
-- with `o`:
--   x, y     the left end of its first baseline, px on the surface (y down)
--   size     its x-height, px
--   turn     radians about x, y, anticlockwise on the screen (a line that
--            rises to the right is turned > 0)
--   lead     from baseline to baseline, x-heights (HAND.lead)
--   indent   { px, ... } each line moved right, along the line
--   colour   { r, g, b }; alpha (HAND.alpha); layer (0)
--   flatNib  true for an even width, no nib
-- Returns the pieces made and the box round all its ink { x0, y0, x1, y1 }.
function Hand.Draw(out, n, o)
    local size, lead = o.size, o.lead or HAND.lead
    local c, s = cos(o.turn or 0), sin(o.turn or 0)
    local alpha, layer = o.alpha or HAND.alpha, o.layer or 0
    local made = 0
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for i, line in ipairs(n.lines) do
        local dx, dy = (o.indent and o.indent[i] or 0), (i - 1) * lead * size
        for _, st in ipairs(line.strokes) do
            local P = {}
            for k = 1, #st, 3 do
                local u, v = st[k] * size + dx, st[k + 1] * size + dy
                -- Turned anticlockwise on the screen with y down.
                local x, y = o.x + u * c + v * s, o.y - u * s + v * c
                local last = P[#P]
                if not last or abs(last.x - x) + abs(last.y - y) > 0.05 then
                    P[#P + 1] = { x = x, y = y, p = st[k + 2] }
                end
            end
            -- A dot: one point, drawn as a fleck the pen's width long.
            if #P == 1 then
                local d = max(HAND.min, HAND.width * P[1].p ^ HAND.gain) / 2
                P = { { x = P[1].x - d / 2, y = P[1].y, p = P[1].p }, { x = P[1].x + d / 2, y = P[1].y, p = P[1].p } }
            end
            for _, piece in ipairs(Split(P)) do
                made = made + Piece(out, layer, piece, o.colour, alpha, not o.flatNib)
            end
        end
    end
    for k = #out - made + 1, #out do
        local q = out[k]
        for _, xy in ipairs({ { q.x1, q.y1 }, { q.x2, q.y2 }, { q.x3, q.y3 }, { q.x4, q.y4 } }) do
            x0, y0, x1, y1 = min(x0, xy[1]), min(y0, xy[2]), max(x1, xy[1]), max(y1, xy[2])
        end
    end
    if made == 0 then return 0, nil end
    return made, { x0, y0, x1, y1 }
end
