-- Someone you met, on the map: see Kind.lua.

local addonName, ns = ...

local Met = ns.Met
local Plate = ns.UI.JourneyPlate
local MARK = Plate.MARK

-- The core's ring for time together, at its own size and on the halo the core
-- lays under it (MARK.together + 4: DrawMoments), so nothing on the plate tells
-- this card from a person's. Order 36: after the close call (30) and before the
-- luck (40), so where they crowd, a death's near thing and the people hold their
-- places first. Its marks are kept for the strips' leaders, not joined to
-- plate.people: that would make a second, automatic strip with no moments to tell.
Plate.RegisterMark("met", {
    order = 36, cap = 20, count = "acquaintances",
    radius = MARK.together / 2 + 1, halo = MARK.together + 4,
    tip = function(m, now) return Met.Tip(m.met, now) end,
    -- Every card on the spot in one account (Text.lua's Met.Tips).
    tips = function(list, now)
        local recs = {}
        for _, m in ipairs(list) do recs[#recs + 1] = m.met end
        return Met.Tips(recs, now)
    end,
    keep = "metMarks",
    draw = function(kit, x, y) Plate.SHAPE.session(kit, x, y) end,
})
