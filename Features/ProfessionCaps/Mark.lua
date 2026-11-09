-- A profession cap's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit.

local addonName, ns = ...

local ProfessionCaps = ns.ProfessionCaps

-- A profession brought to its cap (JRN-29): a flight of `steps` stairs
-- rising to the right, one for each rank a trainer teaches (Apprentice,
-- Journeyman, Expert, Artisan), each `w` px wide and `rise` px higher than
-- the one before, standing on one line. The steps climbed, up to the rank
-- reached (its cap over `per`: 75 one, 300 all four), are solid ink; the
-- ones still to climb are drawn in outline, `line` px of ink round their
-- paper, so the flight is always whole and the tooltip says what it means
-- (no key on the plates). A cap past the last rank, or none kept, is the
-- whole flight. Stepped, so never the tally's strokes, a cross, the pouch
-- or the tailpiece's rules; boxes only, so it draws the same where corners
-- cannot move. Ranked with a level's pin, so it keeps a halo as big as
-- the tailpiece's. (12 Oct, a rasterised render: as a stepped line the
-- unclimbed steps blurred into a slash at the book's size; closed, they
-- read as stairs.)
local MARK = { steps = 4, w = 3.2, rise = 2.9, line = 1.0, per = 75, halo = 17 }
ProfessionCaps.MARK = MARK

-- Ranked with the tailpiece (a chain's end, order 10), right after it
-- (order 20): its steps climbed by the best cap on the spot (`arg`).
ns.UI.JourneyPlate.RegisterMark("skill", {
    order = 20, cap = 10, count = "skills",
    radius = MARK.steps * MARK.w / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now) return ProfessionCaps.Tip(m.cap, now) end,
    -- Every cap reached on the spot told once together (ProfessionCaps.Tips).
    tips = function(list, now)
        local caps = {}
        for _, m in ipairs(list) do caps[#caps + 1] = m.cap end
        return ProfessionCaps.Tips(caps, now)
    end,
    arg = function(list)
        local rank
        for _, m in ipairs(list) do
            if type(m.cap.rank) == "number" and (not rank or m.cap.rank > rank) then rank = m.cap.rank end
        end
        return rank
    end,
    -- The whole flight in ink, a column to each step (each a hair wider,
    -- under the taller one beside it, so no seam shows between them), then
    -- the paper inside the steps above the rank reached. The paper of each
    -- such step reaches on under the next, so the outline runs round them
    -- as one, with no wall between.
    draw = function(kit, x, y, rank)
        local S = MARK
        local n, w, t = S.steps, S.w, S.line
        local climbed = type(rank) == "number" and kit.Clamp(math.floor(rank / S.per), 1, n) or n
        local x0, base = x - n * w / 2, y + n * S.rise / 2
        for i = 1, n do
            local h, wide = i * S.rise, i < n and w + 0.3 or w
            kit.Box(kit.ink, x0 + (i - 1) * w + wide / 2, base - h / 2, wide, h, kit.INK_STRONG, 1)
        end
        for i = climbed + 1, n do
            local h = i * S.rise
            local left, right = x0 + (i - 1) * w + t, x0 + i * w + (i < n and t or -t)
            kit.Box(kit.inner, (left + right) / 2, base - h / 2, right - left, h - 2 * t, kit.P, 1)
        end
    end,
})
