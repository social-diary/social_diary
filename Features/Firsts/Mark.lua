-- Firsts found's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit: a drawstring pouch where each first was found,
-- firsts on one spot (a green bag is a first bag and a first green) one
-- pouch, in the ink of the best of them, its tooltip telling them together. A gift
-- from someone in the diary is that person's moment as well (`join`):
-- kept with their marks (plate.where, plate.people), so it joins their
-- margin note ("gave you your first blue", Text.lua's Firsts.PERSON) and
-- its leader may come here.

local addonName, ns = ...

local Firsts = ns.Firsts

-- A first found (JRN-24): a drawstring pouch, the loot bag of a treasure
-- map. Solid ink: a round `body` (`size` across, its middle `y` below the
-- mark's), pinched at a `neck` (`w` wide, from `y0` to `y1`) and flaring
-- above it into a `mouth` `w` wide at `top`, with a `notch` of paper in its
-- middle (`w` wide, `depth` deep) so the cloth stands up in two ears where
-- corners can move (a plain box down to the neck where they cannot). Round below
-- and flared above, so never the dungeon's arch (round above, square
-- below); solid, so never the ring of time together or the hollow lozenge
-- of a first sighting; a mass, never the death's thin cross. 12 px tall,
-- about the other marks' size. In the item's own ink (Style.QualityInk, as
-- its name is written on the page) drawn `tint` of the way from the plain
-- ink, so a green or a blue only hints at its colour; a white or grey
-- item's pouch is plain ink.
local POUCH = { body = { size = 8, y = 1.6 }, neck = { w = 2.2, y0 = -3.4, y1 = -1.6 },
    mouth = { w = 6.4, top = -6.0 }, notch = { w = 2.2, depth = 1.5 }, tint = 0.6, height = 11.6 }
Firsts.POUCH = POUCH
-- The quality a first of each kind is, at least; a bag or shoulders say
-- theirs in their link.
local FIND_QUALITY = { uncommon = 2, rare = 3, epic = 4 }

local function Quality(m)
    local rec = m.find or m
    return math.max(FIND_QUALITY[m.what] or 0, ns.Timeline.Quality(rec.link) or 0)
end

-- The pouches are the first of the registered marks (order 5, before a
-- chain's tailpiece at 10), where they were drawn before they were
-- registered: right after the people's marks, so the other kinds step
-- round them. At most 10 a plate (CAP.finds), kept (plate.findMarks) for
-- the cards in the margin (Card.lua's Items: a card each item, its leader
-- to the pouch), each with the ink it was drawn in (its `arg`).
ns.UI.JourneyPlate.RegisterMark("find", {
    order = 5, cap = 10, count = "finds",
    radius = POUCH.height / 2 + 1, halo = POUCH.height + 4,
    tip = function(m, now)
        local title, line = Firsts.Tip(m, now)
        return title, (line and line ~= "") and { line } or nil
    end,
    -- Every first in the pouch told once together, the best first (`arg`
    -- has sorted the list so before the mouse comes): Firsts.Tips.
    tips = function(list, now) return Firsts.Tips(list, now) end,
    keep = "findMarks",
    -- The best of them first (by quality, then the oldest), and the ink
    -- the pouch is drawn in: plain ink, or the best one's part way.
    arg = function(list)
        table.sort(list, function(a, b)
            local qa, qb = Quality(a), Quality(b)
            if qa ~= qb then return qa > qb end
            return a.t < b.t
        end)
        local INK_STRONG = ns.Style.INK_STRONG
        local colour = INK_STRONG
        local own = Quality(list[1]) >= 2 and ns.Style.QualityInk(Quality(list[1]))
        if own then
            local t = POUCH.tint
            colour = { INK_STRONG[1] + (own[1] - INK_STRONG[1]) * t, INK_STRONG[2] + (own[2] - INK_STRONG[2]) * t,
                INK_STRONG[3] + (own[3] - INK_STRONG[3]) * t }
        end
        return colour
    end,
    -- A gift from someone in the diary joins their marks.
    join = function(m)
        return m.gift and m.guid and ns.Diary.IsDiary(m.guid)
    end,
    -- A drawstring pouch in `colour` (ink, or the item's ink part way),
    -- lit where it lies.
    draw = function(kit, x, y, colour)
        local B, N, M, V = POUCH.body, POUCH.neck, POUCH.mouth, POUCH.notch
        local ink, inner, P = kit.ink, kit.inner, kit.P
        colour = colour or kit.INK_STRONG
        kit.Dot(ink, x, y + B.y, B.size, colour, 1)
        kit.Box(ink, x, y + (N.y0 + N.y1) / 2, N.w, N.y1 - N.y0, colour, 1)
        local light = kit.Light(x, y)
        local mouth = ink:Next()
        kit.Fill(mouth, colour[1] * light, colour[2] * light, colour[3] * light, 1)
        local hw, nw = M.w / 2, N.w / 2
        if kit.Quad(mouth, x - hw, y + M.top, x + hw, y + M.top, x + nw, y + N.y0 + 0.3, x - nw, y + N.y0 + 0.3) then
            -- The ears: a nick of paper out of the mouth's middle.
            local notch = inner:Next()
            kit.Fill(notch, P[1], P[2], P[3], 1)
            local vw = V.w / 2
            if not kit.Quad(notch, x - vw, y + M.top - 0.2, x + vw, y + M.top - 0.2, x, y + M.top + V.depth,
                x, y + M.top + V.depth) then
                notch:Hide()
            end
        else
            kit.Place(mouth, x - hw * 0.8, y + M.top, M.w * 0.8, N.y0 + 0.3 - M.top)
        end
    end,
})
