-- Crafter detection's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua; .claude/ui-proposal/crafter-detection.md, B's
-- needle and thread, signed 27 Nov 2026 for both directions), drawn on
-- every plate and the full zone page through the plate's kit: a needle
-- with its thread where a connection was found, whichever way the thing
-- went between you, in the item's ink part way, as the pouch and the
-- tunic are. Every connection keeps its needle, the ones whose card is
-- left off too (the margin's, Card.lua): the needle and its tooltip tell
-- what the card had no room for. A connection with someone in the diary
-- is their moment as well (`join`): kept with their marks (plate.where,
-- plate.people), so it joins their margin note (Text.lua's
-- CrafterDetection.PERSON) and its leader may come here.

local addonName, ns = ...

local CrafterDetection = ns.CrafterDetection

-- The needle: a slim spike from its point (`point`, from the mark's
-- middle, y down: low left) to its eye end (`eye`: up right), `wide` px
-- across at the eye end and `sharp` at the point, a quad where corners
-- can move, else a stroke `wide` px. Its eye a slot of paper `slot` = {
-- length, width } along the needle, `inset` of the way back from the eye
-- end. The thread (`thread`, `width` px) runs out of the eye in two
-- curves (cubic, each { c1, c2, to } from where the last ended), drawn as
-- `steps` strokes each, and ends hanging by the point. About 13 px each
-- way, the other marks' size. In the item's own ink (Style.QualityInk)
-- `tint` of the way from the plain ink, the pouch's rule and number, so
-- the pouch, the tunic and the needle of one item are one ink; a white
-- item's is plain. `height` the room it claims, `halo` its paper.
-- (27 Nov 2026, the proposal's mockup at 2x beside the pouch, the tunic,
-- the star, the tally, the cross and the campfire: the needle read as
-- "made, sewn"; a thread only for one direction was declined by the user.)
local MARK = {
    point = { -6, 6.2 }, eye = { 5.6, -5.6 }, wide = 1.8, sharp = 0.25,
    slot = { 2.8, 0.9 }, inset = 0.12,
    thread = { width = 0.9, steps = 6, from = { 4.5, -4.5 },
        curves = { { { 8, -1 }, { 2, 3 }, { -1.6, 1.2 } }, { { -4.4, -0.2 }, { -6.2, 2.4 }, { -4.4, 4 } } } },
    tint = 0.6, height = 13, halo = 16,
}
CrafterDetection.MARK = MARK

-- A connection's item quality: its link's colour, else the client's.
local function Quality(m)
    local rec = m.meet or m
    return ns.UI.ItemBox.Quality(rec.link) or 1
end

-- The best item of them first (by quality, then the earliest), and the
-- ink the needle is drawn in: plain ink, or the best one's part way.
local function Ink(list)
    table.sort(list, function(a, b)
        local qa, qb = Quality(a), Quality(b)
        if qa ~= qb then return qa > qb end
        return a.t < b.t
    end)
    local INK_STRONG = ns.Style.INK_STRONG
    local own = Quality(list[1]) >= 2 and ns.Style.QualityInk(Quality(list[1]))
    if not own then return INK_STRONG end
    local t = MARK.tint
    return { INK_STRONG[1] + (own[1] - INK_STRONG[1]) * t, INK_STRONG[2] + (own[2] - INK_STRONG[2]) * t,
        INK_STRONG[3] + (own[3] - INK_STRONG[3]) * t }
end

-- A point of a cubic from p0 to p3 at u.
local function Cubic(p0, p1, p2, p3, u)
    local v = 1 - u
    local a, b, c, d = v * v * v, 3 * v * v * u, 3 * v * u * u, u * u * u
    return a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1], a * p0[2] + b * p1[2] + c * p2[2] + d * p3[2]
end

-- A needle and its thread in `colour` round x, y, lit where it lies.
local function Draw(kit, x, y, colour)
    colour = colour or kit.INK_STRONG
    local P, E = MARK.point, MARK.eye
    local px, py, ex, ey = x + P[1], y + P[2], x + E[1], y + E[2]
    local dx, dy = ex - px, ey - py
    local length = math.sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / length, dx / length
    -- The needle: tapered where corners move, a stroke where they cannot.
    local body = kit.ink:Next()
    local light = kit.Light(x, y)
    kit.Fill(body, colour[1] * light, colour[2] * light, colour[3] * light, 1)
    local w, s = MARK.wide / 2, MARK.sharp / 2
    if not kit.Quad(body, px - nx * s, py - ny * s, ex - nx * w, ey - ny * w, ex + nx * w, ey + ny * w,
        px + nx * s, py + ny * s) then
        body:Hide()
        kit.Stroke(kit.ink, px, py, ex, ey, MARK.wide, colour, 1)
    end
    -- Its eye: a slot of paper along it, near the eye end.
    local k = 1 - MARK.inset
    kit.Box(kit.inner, px + dx * k, py + dy * k, MARK.slot[1], MARK.slot[2], kit.P, 1, math.atan2(-dy, dx))
    -- The thread, out of the eye and hanging down by the point.
    local T = MARK.thread
    local from = { x + T.from[1], y + T.from[2] }
    for _, curve in ipairs(T.curves) do
        local c1 = { x + curve[1][1], y + curve[1][2] }
        local c2 = { x + curve[2][1], y + curve[2][2] }
        local to = { x + curve[3][1], y + curve[3][2] }
        local lx, ly = from[1], from[2]
        for i = 1, T.steps do
            local qx, qy = Cubic(from, c1, c2, to, i / T.steps)
            kit.Stroke(kit.ink, lx, ly, qx, qy, T.width, colour, 1)
            lx, ly = qx, qy
        end
        from = to
    end
end

-- A connection with someone in the diary joins their marks.
local function Join(m)
    return m.guid ~= nil and ns.Diary.IsDiary(m.guid)
end

-- Order 8: after the pouch (5) and the tunic (7), before a chain's
-- tailpiece (10), so where a thing was found, put on and seen worn on one
-- spot the pouch and the tunic hold it and the needle steps round them,
-- and every later kind steps round the three. At most 10 a plate. Kept
-- (plate.craftedMarks) for the cards in the margin (Card.lua: a card each
-- connection, its leader to its needle).
ns.UI.JourneyPlate.RegisterMark("crafted", {
    -- Its row in "Choose what's on this page" (UI/Journey/Choose.lua).
    label = function(rec, m) return ns.CrafterDetection.Row(rec or m.meet) end,
    order = 8, cap = 10, count = "connections",
    radius = MARK.height / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now) return CrafterDetection.Tips({ m }, now) end,
    tips = function(list, now) return CrafterDetection.Tips(list, now) end,
    keep = "craftedMarks",
    arg = Ink, join = Join, draw = Draw,
})
