-- A duel's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua; .claude/ui-proposal/duels.md, variant A as signed
-- 15 Oct), drawn on every plate and the full zone page through the plate's
-- kit.

local addonName, ns = ...

local Duels = ns.Duels

-- The flag the client plants between two players as a duel's countdown
-- starts, where the series' place was read: a swallowtailed guidon flying
-- from a pole, its foot on a stake's dot. The same, filled, for a duel won
-- or lost (the user, 15 Oct: won and lost are told by the words, not the
-- mark), so there is no `arg`. Ink only (INK_STRONG): red-brown is world
-- PvP's fights and flights, rubric the level's pin.
--   pole   `h` tall, `w` wide, its left edge `w` + `fly` / 2 left of the
--          middle, so the whole flag (pole and cloth) is centred across
--   foot   the stake's dot, `size` across, its middle `y` under the pole's
--          foot
--   cloth  from the pole's right edge (`tuck` px into it, so pole and
--          cloth are one shape): `hoist` down the pole, `fly` out from it,
--          its outer end cut `notch` deep at the hoist's middle (the
--          swallowtail), its top edge falling `droop` px to its end, as
--          cloth hangs a little; where corners cannot move, a box
--          `fly` - `notch` / 2 wide
--   h      the whole mark's height (pole and dot), set on its middle
--   halo   the paper under it (the campfire's is 18): takes in the cloth's
--          end and the dot
-- (15 Oct, rasterised for the proposal, render_duel_marks.py: about 9 px
-- wide, 14 tall, a hair more than the star and the tally, it reads beside
-- the death cross (no bar either side of its pole), the close call
-- (solid), the campfire (no logs, its mass high and to one side) and the
-- pouch (not centred). A cloth hung down the pole read as "!", a toppled
-- pole as a hat, half-mast as "Ⱶ".)
local MARK = { pole = { h = 13, w = 1.4 }, foot = { size = 3, y = 0.2 },
    cloth = { hoist = 5.6, fly = 7.6, notch = 2.4, tuck = 0.2, droop = 0.5 }, h = 14.7, halo = 17 }
Duels.MARK = MARK

-- The duels' flags, drawn after the deaths on the road (Plate.ROAD_DEATHS,
-- 60) and before the campfire (70): filler both (the user, 15 Oct), so
-- every mark that tells something keeps its place and a flag landing on
-- one steps aside (Apart, with its tether); the campfire stays last, as it
-- says less than a duel, which names a person. Two series on one spot are
-- one flag (the plate's own MARK.merge), its tooltip telling them as one. Kept
-- (plate.duelMarks) for the plate's one note (Slip.lua, plate.duel).
ns.UI.JourneyPlate.RegisterMark("duel", {
    order = 65, cap = 20, count = "duels",
    radius = MARK.h / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now) return Duels.Tip(m.duel, now) end,
    -- Every series on the spot in one account (Text.lua's Duels.Tips).
    tips = function(list, now)
        local recs = {}
        for _, m in ipairs(list) do recs[#recs + 1] = m.duel end
        return Duels.Tips(recs, now)
    end,
    keep = "duelMarks", chosen = "duel",
    choose = function(marks) return Duels.Slip.Choose(marks) end,
    -- The pole and its dot, then the cloth: two quads split at the
    -- notch, the upper from the pole's top to the notch, the lower from
    -- the notch to the hoist's foot.
    draw = function(kit, x, y)
        local P, F, C = MARK.pole, MARK.foot, MARK.cloth
        local INK = kit.INK_STRONG
        local left = x - (P.w + C.fly) / 2
        local top = y - MARK.h / 2
        kit.Box(kit.ink, left + P.w / 2, top + P.h / 2, P.w, P.h, INK, 1)
        kit.Dot(kit.ink, left + P.w / 2, top + P.h + F.y, F.size, INK, 1)
        local r = left + P.w - C.tuck
        local outer = left + P.w + C.fly
        local mid = top + C.hoist / 2 + 0.4
        local upper = kit.ink:Next()
        local light = kit.Light(r + C.fly / 2, mid)
        kit.Fill(upper, INK[1] * light, INK[2] * light, INK[3] * light, 1)
        if kit.Quad(upper, r, top + 0.2, outer, top + 0.2 + C.droop, outer - C.notch, mid, r, mid) then
            local lower = kit.ink:Next()
            kit.Fill(lower, INK[1] * light, INK[2] * light, INK[3] * light, 1)
            kit.Quad(lower, r, mid, outer - C.notch, mid, outer, top + C.hoist + 0.1, r, top + C.hoist - 0.3)
        else
            kit.Place(upper, r, top + 0.2, C.fly - C.notch / 2, C.hoist - 0.4)
        end
    end,
})
