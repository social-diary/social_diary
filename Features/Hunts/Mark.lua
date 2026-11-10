-- Hunts' marks on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit: the tally (bad luck, `luck`) and the lucky star
-- (good luck, `fortune`), each choosing the plate's one card of its kind.

local addonName, ns = ...

local Hunts = ns.Hunts

-- The hunts of the moments merged on one mark, in their order.
local function Of(list)
    local hunts = {}
    for _, m in ipairs(list) do
        if m.hunt then hunts[#hunts + 1] = m.hunt end
    end
    return hunts
end

-- Bad luck with a quest's drops (JRN-26): a tally, the kills counted where
-- the hunt went on. Four uprights `gap` px apart, `h` tall, each leaning
-- `lean` px at its top as a hand draws them (`jitter`: each one's height
-- given or taken), and a fifth stroke across them from the lower left,
-- `over` px past the outer two. Strokes `width` px. In ink, never a letter
-- (the gate of five is no letter), never a fight's crossed strokes (two,
-- red-brown).
local TALLY = { count = 4, gap = 2.5, h = 10, lean = 0.5, jitter = { 0, 0.6, -0.4, 0.3 }, over = 1.6,
    rise = 7.2, width = 1.3, halo = 16 }
Hunts.TALLY = TALLY
-- The tallies are kept (plate.huntMarks) for the plate's one hunt card
-- (HuntCard.lua): the hunt furthest past its yardstick, against the
-- character's usual where the drop rates are not known (plate.hunt).
-- Fourth of the registered marks (order 40, after the close calls' 30,
-- before the good luck's 50).
ns.UI.JourneyPlate.RegisterMark("luck", {
    order = 40, cap = 20, count = "hunts",
    radius = TALLY.h / 2 + 2, halo = TALLY.halo, hover = TALLY.halo,
    tip = function(m, now) return Hunts.Tip(m.hunt, now) end,
    -- Every hunt on the tally told once together (Hunts.Tips, 9 Nov 2026).
    tips = function(list, now) return Hunts.Tips(Of(list), now) end,
    keep = "huntMarks", chosen = "hunt",
    choose = function(marks)
        local usual = #marks > 0 and Hunts.UsualLuck(ns.Journey.For(ns.ownGUID)) or nil
        return Hunts.HuntCard.Choose(marks, usual)
    end,
    -- Four strokes leaning a little, and one across.
    draw = function(kit, x, y)
        local T = TALLY
        local half = (T.count - 1) * T.gap / 2
        for i = 1, T.count do
            local u = x - half + (i - 1) * T.gap
            local h = T.h + (T.jitter[i] or 0)
            kit.Stroke(kit.ink, u - T.lean / 2, y + h / 2, u + T.lean / 2, y - h / 2, T.width, kit.INK_STRONG, 1)
        end
        local reach = half + T.over
        kit.Stroke(kit.ink, x - reach, y + T.rise / 2, x + reach, y - T.rise / 2, T.width, kit.INK_STRONG, 1)
    end,
})

-- Good luck with a quest's drops (EXT-3), the tally's bright counterpart:
-- a lucky star, five points `r` px out from its middle, its inner corners
-- `inner` of that, turned `turn` as a hand draws it, and set `drop` of r
-- lower so it sits on its middle (its points reach further up than down).
-- Solid ink, five kites from the middle (corners on the card); where
-- corners cannot move, five strokes `ray` px wide from the middle to its
-- points. Closed and solid, so never the tally's open strokes, the
-- crosses' square arms or the fight's two red-brown strokes; drawn solid,
-- never as the five strokes of a pentagram. About 12 px, the tally's size.
-- (12 Oct, a rasterised render: at 13 px it outweighed the death beside it.)
local FORTUNE = { r = 6.2, inner = 0.45, turn = -0.10, drop = 0.095, ray = 2.4, halo = 16 }
-- The stars are kept (plate.fortuneMarks) for the plate's one lucky card
-- (LuckyCard.lua): the luckiest hunt (plate.lucky), in the margin, or
-- on the print of a light plate (LuckyCard.lua's pass, "print"). After
-- the tally (order 50), before the deaths on the road (the plate's 60).
ns.UI.JourneyPlate.RegisterMark("fortune", {
    order = 50, cap = 20, count = "fortunes",
    radius = FORTUNE.r + 1, halo = FORTUNE.halo, hover = FORTUNE.halo,
    tip = function(m, now) return Hunts.Tip(m.hunt, now) end,
    tips = function(list, now) return Hunts.Tips(Of(list), now, true) end,
    keep = "fortuneMarks", chosen = "lucky",
    choose = function(marks) return Hunts.LuckyCard.Choose(marks) end,
    -- A solid star, one kite of ink to each point.
    draw = function(kit, x, y)
        local F = FORTUNE
        local R, r = F.r, F.r * F.inner
        y = y + R * F.drop
        local light = kit.Light(x, y)
        local c = kit.INK_STRONG
        local function Corner(i)
            local a = -math.pi / 2 + F.turn + (i + 0.5) * 2 * math.pi / 5
            return x + r * math.cos(a), y + r * math.sin(a)
        end
        for i = 0, 4 do
            local a = -math.pi / 2 + F.turn + i * 2 * math.pi / 5
            local px, py = x + R * math.cos(a), y + R * math.sin(a)
            local bx, by = Corner(i - 1)
            local ax, ay = Corner(i)
            local kite = kit.ink:Next()
            kit.Fill(kite, c[1] * light, c[2] * light, c[3] * light, 1)
            if not kit.Quad(kite, x, y, bx, by, px, py, ax, ay) then
                kite:Hide()
                kit.Stroke(kit.ink, x, y, px, py, F.ray, kit.INK_STRONG, 1)
            end
        end
    end,
})
