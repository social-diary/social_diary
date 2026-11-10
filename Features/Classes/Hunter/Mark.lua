-- A hunter's tames' mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit: a paw print where the pet was tamed, its
-- tooltip the tame's (Text.lua's Hunter.Tip). A quiet anchor: its main
-- work is to hold the margin card's leader (Card.lua), so it must never
-- compete with a hunt's star or a death's cross (the scope, 4 Nov; the
-- signed proposal, .claude/ui-proposal/hunter-tames.md, the solid paw).

local addonName, ns = ...

local Hunter = ns.Hunter

-- A pet tamed: a paw print in solid ink, a pad and four toes. The pad an
-- oval `w` by `h`, its middle `y` below the mark's; each toe a dot of
-- `size` at `at` (x, y from the mark's middle), the outer two lower, as a
-- paw's spread. Made of five small pieces with paper between them, so it
-- weighs less than the star, the pouch or the cross, which are one mass
-- each, and nothing else on a plate is made of dots. About 9.5 px each
-- way (`height`), against the star's 12.4. In INK_STRONG, as the others.
-- (4 Nov, rasterised beside every mark, render_plate_marks.py's shapes: the
-- solid paw read as a paw at 1x and lighter than the star; an open pad
-- closed into an "8" at 1x, too near the session's ring; a smaller paw in
-- the lighter ink ran its toes into the pad.)
local MARK = {
    pad = { w = 6, h = 4.8, y = 2.2 },
    toe = { size = 2.5, at = { { -3.4, -1.0 }, { -1.25, -3.2 }, { 1.25, -3.2 }, { 3.4, -1.0 } } },
    height = 9.5, halo = 13,
}
Hunter.MARK = MARK

-- The tames' paws, after every mark but the campfire (order 67: past the
-- duel's flag, 65, before the campfire's, 70), so where they crowd the paw
-- is the one that steps aside, with a tether: it anchors a leader and
-- needs no exact spot (the user's, 4 Nov). Kept (plate.tameMarks) for the
-- plate's one card (Card.lua's Choose: the newest tame, plate.tame) and
-- the player's own cards (Card.lua's Customs). Its tooltip is Hunter.Tips's
-- account of every tame on the spot, so each name is said once.
ns.UI.JourneyPlate.RegisterMark("tame", {
    order = 67, cap = 10, count = "tames",
    radius = MARK.height / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now)
        local lines = Hunter.Tip(m.tame or m, now)
        return lines[1], { unpack(lines, 2) }
    end,
    -- Every tame on the spot in one account (Text.lua's Hunter.Tips).
    tips = function(list, now)
        local tames = {}
        for _, m in ipairs(list) do tames[#tames + 1] = m.tame or m end
        return Hunter.Tips(tames, now)
    end,
    keep = "tameMarks", chosen = "tame",
    choose = function(marks) return Hunter.Card.Choose(marks) end,
    -- The pad, a disc drawn out into its oval, then the toes.
    draw = function(kit, x, y)
        local D, T = MARK.pad, MARK.toe
        local pad = kit.Dot(kit.ink, x, y + D.y, D.h, kit.INK_STRONG, 1)
        kit.Place(pad, x - D.w / 2, y + D.y - D.h / 2, D.w, D.h)
        for _, at in ipairs(T.at) do
            kit.Dot(kit.ink, x + at[1], y + at[2], T.size, kit.INK_STRONG, 1)
        end
    end,
})
