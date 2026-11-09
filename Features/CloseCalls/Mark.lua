-- A close call's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit.

local addonName, ns = ...

local CloseCalls = ns.CloseCalls

-- A close call (JRN-25): the death's cross drawn in outline and never
-- filled in, the cross you nearly got. Ink round paper, as the hollow
-- lozenge of a first sighting is: a `stem` `w` wide and `h` tall, its middle
-- `y` below the mark's, and a `bar` `w` wide, its middle `y` off it, each
-- `line` px of ink round its paper. A little bigger than the death's solid
-- cross (8 px), so its paper reads at the book's size, but no heavier: the
-- death stays the darker mark. On a `dot` of paper, as the death's is.
-- (11 Oct, a rasterised render: at 12.4 px with 1.25 px of ink it
-- outweighed the death beside it.)
local CLOSE = { stem = { w = 3.8, h = 11, y = 0.5 }, bar = { w = 8.2, y = -1.9 }, line = 1.1, dot = 14 }
CloseCalls.MARK = CLOSE

-- Third of the registered marks (order 30, after the finales' 10 and the
-- caps' 20, before the luck's 40). No halo of the plate's: it lies on its
-- own dot of paper, as the death's cross does (kit.halo). Its marks are
-- kept (plate.closeMarks) for the creature that nearly got you, its card
-- in the margin: chosen with the killer's, after the marks (its pass,
-- Card.lua: plate.foe, or a witness's), so not here.
ns.UI.JourneyPlate.RegisterMark("close", {
    order = 30, cap = 20, count = "closeCalls",
    radius = CLOSE.stem.h / 2 + 1, halo = false, hover = CLOSE.dot,
    tip = function(m, now) return CloseCalls.Tip(m.call, now) end,
    -- Those on one spot told together (Text.lua's Tips).
    tips = function(list, now)
        local calls = {}
        for i, m in ipairs(list) do calls[i] = m.call end
        return CloseCalls.Tips(calls, now)
    end,
    keep = "closeMarks",
    -- The cross in ink, then its paper inside, so the outline runs round
    -- the crossing unbroken.
    draw = function(kit, x, y)
        local S, B, t = CLOSE.stem, CLOSE.bar, CLOSE.line
        local P, INK_STRONG = kit.P, kit.INK_STRONG
        kit.Dot(kit.halo, x, y, CLOSE.dot, P, 0.85)
        kit.Box(kit.ink, x, y + S.y, S.w, S.h, INK_STRONG, 1)
        kit.Box(kit.ink, x, y + B.y, B.w, S.w, INK_STRONG, 1)
        kit.Box(kit.inner, x, y + S.y, S.w - 2 * t, S.h - 2 * t, P, 1)
        kit.Box(kit.inner, x, y + B.y, B.w - 2 * t, S.w - 2 * t, P, 1)
    end,
})
