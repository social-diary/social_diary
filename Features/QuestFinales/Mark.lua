-- A chain's finale's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit.

local addonName, ns = ...

local QuestFinales = ns.QuestFinales

-- The end of a long quest chain (JRN-28): a tailpiece, as an old book
-- ends a chapter. A swelled `rules` (`w` wide, `t` thick at its middle,
-- tapering to points, its middle `y` off the mark's), a shorter one under
-- it, and a full stop (`dot`: size, y). Where corners cannot move, each
-- rule a flat bar `bar` of its size. Rules lie across, so never the tally
-- or a cross; narrowing to a point, so never a pin or the ring of time
-- together. Ranked with a level's pin on the plate, so it keeps a halo as
-- big as the pin's.
local MARK = { rules = { { w = 14, t = 2.5, y = -3.2 }, { w = 7.5, t = 2.1, y = 0.5 } }, dot = { 2.8, 4.0 },
    bar = 0.75, halo = 17, h = 10 }
QuestFinales.MARK = MARK

-- Drawn first of the registered marks (order 10): it ranks with the
-- level's pin, so it keeps its place and the crosses and tallies step
-- round it.
ns.UI.JourneyPlate.RegisterMark("finale", {
    order = 10, cap = 10, count = "finales",
    radius = MARK.rules[1].w / 2, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now) return QuestFinales.Tip(m.finale, now) end,
    -- Every chain ended on the spot told once together (QuestFinales.Tips).
    tips = function(list, now)
        local finales = {}
        for _, m in ipairs(list) do finales[#finales + 1] = m.finale end
        return QuestFinales.Tips(finales, now)
    end,
    -- Two swelled rules and a full stop.
    draw = function(kit, x, y)
        local F = MARK
        local light = kit.Light(x, y)
        local c = kit.INK_STRONG
        for _, rule in ipairs(F.rules) do
            local ry, hw, ht = y + rule.y, rule.w / 2, rule.t / 2
            local texture = kit.ink:Next()
            kit.Fill(texture, c[1] * light, c[2] * light, c[3] * light, 1)
            if not kit.Quad(texture, x - hw, ry, x, ry - ht, x + hw, ry, x, ry + ht) then
                kit.Place(texture, x - hw * F.bar, ry - ht * F.bar, rule.w * F.bar, rule.t * F.bar)
            end
        end
        kit.Dot(kit.ink, x, y + F.dot[2], F.dot[1], kit.INK_STRONG, 1)
    end,
})
