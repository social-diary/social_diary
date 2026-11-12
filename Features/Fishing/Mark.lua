-- Fishing's mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit: a fish, in ink like every mark.

local addonName, ns = ...

local Fishing = ns.Fishing

-- A fish, swimming left, the whole turned `tilt` radians so it does not sit
-- stiff on the card: a body of two panels (each a quad from the nose, over
-- its back or under its belly, to the tail joint, so it is a rounded lens),
-- a forked tail (two triangles from the joint) and an eye of paper. Points
-- are offsets from the mark's middle before the turn, y down. Where corners
-- cannot move: a solid dot for the body and two strokes for the tail. About
-- 15 px long (`h`) on a halo of `halo`.
-- (12 Nov, drawn from the numbers and previewed at real size, not yet seen
-- in the client: the sizes are the sprig's and the pickaxe's, to be tuned
-- there. The first try, a single diamond for the body, read stiff.)
local FISH = { tilt = -0.25, nose = { -7, 0.3 }, joint = { 3.4, -0.1 },
    top = { { -3.8, -3.4 }, { 0.4, -2.9 } }, bottom = { { -3.8, 3.6 }, { 0.4, 3.1 } },
    fork = { { 7.8, -3.8 }, { 5.8, 0 }, { 7.8, 3.8 } }, eye = { { -4.6, -0.5 }, 1.5 }, dot = 8, stroke = 1.8,
    h = 15 }
Fishing.FISH = FISH

-- A flat triangle of ink: a quad with a corner given twice. False where
-- corners cannot move.
local function Triangle(kit, a, b, c, At)
    local ax, ay = At(a)
    local bx, by = At(b)
    local cx, cy = At(c)
    local ink, light = kit.INK_STRONG, kit.Light(ax, ay)
    local tri = kit.ink:Next()
    kit.Fill(tri, ink[1] * light, ink[2] * light, ink[3] * light, 1)
    if kit.Quad(tri, ax, ay, ax, ay, bx, by, cx, cy) then return true end
    tri:Hide()
    return false
end

-- One panel of the body: the nose, two corners along the back or the
-- belly, and the joint.
local function Panel(kit, edge, At)
    local F = FISH
    local nx, ny = At(F.nose)
    local ux, uy = At(edge[1])
    local vx, vy = At(edge[2])
    local jx, jy = At(F.joint)
    local ink, light = kit.INK_STRONG, kit.Light(nx, ny)
    local panel = kit.ink:Next()
    kit.Fill(panel, ink[1] * light, ink[2] * light, ink[3] * light, 1)
    if kit.Quad(panel, nx, ny, ux, uy, vx, vy, jx, jy) then return true end
    panel:Hide()
    return false
end

local function DrawFish(kit, x, y)
    local F = FISH
    local sin, cos = math.sin(F.tilt), math.cos(F.tilt)
    local function At(p) return x + p[1] * cos - p[2] * sin, y + p[1] * sin + p[2] * cos end

    if Panel(kit, F.top, At) and Panel(kit, F.bottom, At) then
        -- The forked tail: the joint, an upper tip and the notch, then the
        -- notch and a lower tip.
        Triangle(kit, F.joint, F.fork[1], F.fork[2], At)
        Triangle(kit, F.joint, F.fork[2], F.fork[3], At)
    else
        local cx, cy = At({ -1.8, 0 })
        kit.Dot(kit.ink, cx, cy, F.dot, kit.INK_STRONG, 1)
        local tx, ty = At(F.joint)
        local ux, uy = At(F.fork[1])
        local lx, ly = At(F.fork[3])
        kit.Stroke(kit.ink, tx, ty, ux, uy, F.stroke, kit.INK_STRONG, 1)
        kit.Stroke(kit.ink, tx, ty, lx, ly, F.stroke, kit.INK_STRONG, 1)
    end
    local ex, ey = At(F.eye[1])
    kit.Dot(kit.inner, ex, ey, F.eye[2], kit.P, 0.95)
end

-- The catches of the moments merged on one mark, in their order.
local function Of(list)
    local catches = {}
    for _, m in ipairs(list) do
        if m.catch then catches[#catches + 1] = m.catch end
    end
    return catches
end

-- The catches, drawn after the gathered nodes' marks (order 74, after
-- their 72): filler, so every other mark keeps its place and a fish
-- landing on one steps aside (Apart, with its tether). Catches within the
-- plate's own MARK.merge of each other are one mark, its tooltip telling
-- each (Text.lua's Fishing.Tips): a shore fished all afternoon is one fish.
-- More than `cap` a plate leaves the rest off. No margin note.
ns.UI.JourneyPlate.RegisterMark("fished", {
    order = 74, cap = 30, count = "catches",
    radius = FISH.h / 2 + 1, halo = 18, hover = 18,
    tip = function(m, now) return Fishing.Tip(m.catch, now) end,
    tips = function(list, now) return Fishing.Tips(Of(list), now) end,
    draw = function(kit, x, y) DrawFish(kit, x, y) end,
})
