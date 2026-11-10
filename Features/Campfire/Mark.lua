-- A campfire's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua; .claude/ui-proposal/campfire.md), drawn on every
-- plate and the full zone page through the plate's kit.

local addonName, ns = ...

local Campfire = ns.Campfire

-- A campfire sat by till its buffs came: a flame on two logs. The `logs`,
-- two strokes `w` long and `width` px, crossed at ±`angle` radians about a
-- point `y` below the middle, so their ends show either side of the
-- flame's foot as an X of logs; the `flame`, solid ink, a round `belly`
-- (`size` across, its middle `y` down) drawn up into a point at `tip`
-- (leaning `lean` px, as a flame licks), its sides meeting the belly where
-- they touch it, so it is one smooth drop; inside it a `tongue` of paper,
-- a small drop of its own (a dot of `dot` px `foot` down, drawn up to a
-- point at `tip`), so it reads as a flame in a flame, never the pouch's
-- solid mass with ears. Where corners cannot move: the belly's dot, a
-- diamond for the point, the tongue's dot alone. Ink only (the user's
-- choice, 14 Oct): rubric is the level's pin, red-brown fights and
-- flights, and a warm tint would read as a pouch's quality. About 14 px
-- tall (`h`), set on its middle, a hair more than the star and the tally,
-- on a halo of `halo` that takes in the logs' ends.
-- (14 Oct, rasterised: the proposal's flame, 6.4 px of belly under a
-- point 7.6 px up on logs at 0.2 rad, read as a "Δ" on a bar; a rounder
-- belly, a shorter point and the logs crossed steeper read as a fire.)
local MARK = { logs = { w = 12, width = 1.5, angle = 0.40, y = 3.6 },
    flame = { belly = { size = 7.6, y = 0.2 }, tip = -7.0, lean = 1.2 },
    tongue = { tip = -1.4, foot = 1.6, dot = 2.6 }, halo = 18, h = 14 }
Campfire.MARK = MARK

-- The campfires sat by, drawn last of the marks (order 70), after the
-- deaths on the road (Plate.ROAD_DEATHS, 60): filler (the user, 14 Oct),
-- so every other mark keeps its place and a fire landing on one steps
-- aside (Apart, with its tether), as one by a group's ring does. One fire
-- sat by again is one mark (the plate's own MARK.merge), its tooltip
-- telling each sitting. Kept (plate.campfireMarks) for the plate's one
-- slip in the margin (Slip.lua, plate.campfire).
ns.UI.JourneyPlate.RegisterMark("campfire", {
    order = 70, cap = 20, count = "campfires",
    radius = MARK.h / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now) return Campfire.Tip(m.campfire, now) end,
    -- Every sitting on the spot in one account (Text.lua's Campfire.Tips).
    tips = function(list, now)
        local fires = {}
        for _, m in ipairs(list) do fires[#fires + 1] = m.campfire end
        return Campfire.Tips(fires, now)
    end,
    keep = "campfireMarks", chosen = "campfire",
    choose = function(marks) return Campfire.Slip.Choose(marks) end,
    -- The logs, then the flame over their crossing, then the paper of its
    -- tongue.
    draw = function(kit, x, y)
        local L, F, T = MARK.logs, MARK.flame, MARK.tongue
        local P, INK_STRONG = kit.P, kit.INK_STRONG
        local dx, dy = L.w / 2 * math.cos(L.angle), L.w / 2 * math.sin(L.angle)
        local ly = y + L.y
        kit.Stroke(kit.ink, x - dx, ly - dy, x + dx, ly + dy, L.width, INK_STRONG, 1)
        kit.Stroke(kit.ink, x - dx, ly + dy, x + dx, ly - dy, L.width, INK_STRONG, 1)
        local B = F.belly
        kit.Dot(kit.ink, x, y + B.y, B.size, INK_STRONG, 1)
        local light = kit.Light(x, y)
        local c = INK_STRONG
        local point = kit.ink:Next()
        kit.Fill(point, c[1] * light, c[2] * light, c[3] * light, 1)
        -- The point's sides meet the belly where they touch it.
        local r, tx, ty = B.size / 2, x + F.lean, y + F.tip
        local d = math.sqrt(F.lean * F.lean + (F.tip - B.y) ^ 2)
        local up, out = r * r / d, r * math.sqrt(math.max(0, 1 - (r / d) ^ 2))
        if kit.Quad(point, tx, ty, tx, ty, x + out, y + B.y - up, x - out, y + B.y - up) then
            local tongue = kit.inner:Next()
            kit.Fill(tongue, P[1], P[2], P[3], 1)
            local hw = T.dot / 2 * 0.95
            if not kit.Quad(tongue, x + F.lean / 2, y + T.tip, x + F.lean / 2, y + T.tip, x + hw, y + T.foot - 0.3,
                x - hw, y + T.foot - 0.3) then
                tongue:Hide()
            end
        else
            local side = r * 1.1
            kit.Place(point, x + F.lean / 2 - side / 2, y + (F.tip + B.y) / 2 - 1 - side / 2, side, side, math.pi / 4)
        end
        kit.Dot(kit.inner, x, y + T.foot, T.dot, P, 1)
    end,
})
