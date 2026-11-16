-- Gathering's marks on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua), drawn on every plate and the full zone page
-- through the plate's kit: one kind of mark, a sprig where herbs were picked
-- and a pickaxe where ore was mined. Ink only, like every mark: rubric is
-- the level's pin, red-brown fights and flights, and no colour says herb or
-- ore (the shape does, and the tooltip).

local addonName, ns = ...

local Gathering = ns.Gathering

-- A leaf: a kite of solid ink from its base to its tip, `w` px across a
-- third of the way along it (so it is fullest near the stem, as a leaf
-- is). Where corners cannot move: one stroke, base to tip.
local function Leaf(kit, bx, by, tx, ty, w)
    local dx, dy = tx - bx, ty - by
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return end
    local mx, my = bx + dx * 0.38, by + dy * 0.38
    local nx, ny = -dy / len * w / 2, dx / len * w / 2
    local c, light = kit.INK_STRONG, kit.Light(mx, my)
    local leaf = kit.ink:Next()
    kit.Fill(leaf, c[1] * light, c[2] * light, c[3] * light, 1)
    if not kit.Quad(leaf, bx, by, mx + nx, my + ny, tx, ty, mx - nx, my - ny) then
        leaf:Hide()
        kit.Stroke(kit.ink, bx, by, tx, ty, w * 0.75, kit.INK_STRONG, 1)
    end
end

-- Where a herb was picked: a sprig. A stem, bent a little where a hand
-- draws it (two strokes `stem` px wide, `bend` px off true at the middle),
-- a leaf at its top and one either side of it, the right a little lower.
-- Each leaf is { base, tip } as offsets from the mark's middle, `w` px
-- across. About 15 px tall (`h`) on a halo of `halo`.
-- (12 Nov, drawn from the numbers, not yet seen in the client: the sizes
-- are the campfire's and the star's, to be tuned in the client.)
local SPRIG = { stem = 1.3, foot = { 0, 7 }, mid = { 0.8, 1 }, top = { 0.3, -3.5 }, bend = 0.8, w = 3.4, h = 15,
    leaves = {
        { { 0.3, -3.2 }, { 0.5, -8 } },
        { { 0.7, 0.6 }, { -5.6, -3.8 } },
        { { 0.8, 3 }, { 6.4, -0.4 } },
    } }
Gathering.SPRIG = SPRIG

local function DrawSprig(kit, x, y)
    local S = SPRIG
    kit.Stroke(kit.ink, x + S.foot[1], y + S.foot[2], x + S.mid[1], y + S.mid[2], S.stem, kit.INK_STRONG, 1)
    kit.Stroke(kit.ink, x + S.mid[1], y + S.mid[2], x + S.top[1], y + S.top[2], S.stem, kit.INK_STRONG, 1)
    for _, leaf in ipairs(S.leaves) do
        Leaf(kit, x + leaf[1][1], y + leaf[1][2], x + leaf[2][1], y + leaf[2][2], S.w)
    end
end

-- Where ore was mined: a pickaxe, the plainest sign of mining at this size
-- (the first try, a lump of rock cut into two faces, read as a blob in the
-- client, 12 Nov). A handle and, across its top, an arched head that tapers
-- to a point at each end, the whole turned `tilt` radians as it is carried.
-- Points are offsets from the mark's middle before the turn, y down:
-- `handle` from its foot to the head, `head` the arch from its left point
-- to its right (each stroke's width in `widths`, fullest at the middle), and
-- a `socket` dot where the handle goes into the head. Ink only, in strokes
-- and a dot, so it needs no corners to move. About 15 px across (`h`) on a
-- halo of `halo`.
local PICK = { tilt = 0.5, handle = { { 0, 7.2 }, { 0, -4.6 } }, stem = 1.6,
    head = { { -7.2, -0.8 }, { -4.2, -4.4 }, { 0, -5.8 }, { 4.2, -4.4 }, { 7.2, -0.8 } },
    widths = { 1.2, 1.9, 1.9, 1.2 }, socket = { { 0, -4.8 }, 3 }, h = 15 }
Gathering.PICK = PICK

local function DrawPick(kit, x, y)
    local P = PICK
    local sin, cos = math.sin(P.tilt), math.cos(P.tilt)
    -- A point of the pickaxe, turned about the middle, on the card.
    local function At(point) return x + point[1] * cos - point[2] * sin, y + point[1] * sin + point[2] * cos end
    local x1, y1 = At(P.handle[1])
    local x2, y2 = At(P.handle[2])
    kit.Stroke(kit.ink, x1, y1, x2, y2, P.stem, kit.INK_STRONG, 1)
    for i = 1, #P.head - 1 do
        local ax, ay = At(P.head[i])
        local bx, by = At(P.head[i + 1])
        kit.Stroke(kit.ink, ax, ay, bx, by, P.widths[i], kit.INK_STRONG, 1)
    end
    local sx, sy = At(P.socket[1])
    kit.Dot(kit.ink, sx, sy, P.socket[2], kit.INK_STRONG, 1)
end

-- The nodes of the moments merged on one mark, in their order.
local function Of(list)
    local nodes = {}
    for _, m in ipairs(list) do
        if m.node then nodes[#nodes + 1] = m.node end
    end
    return nodes
end

-- Which shape a mark wears: the kind most of its nodes are, the first
-- kind where as many are herbs as ore.
local function Wears(list)
    local herbs, ore = 0, 0
    for _, node in ipairs(Of(list)) do
        if node.kind == "herb" then herbs = herbs + 1 else ore = ore + 1 end
    end
    return herbs > ore and "herb" or ore > herbs and "ore" or (Of(list)[1] or {}).kind or "ore"
end

-- The nodes gathered, drawn last of the marks but the campfires' (order
-- 72, after the fires' 70): filler, so every other mark keeps its place
-- and a node landing on one steps aside (Apart, with its tether). Nodes
-- within the plate's own MARK.merge of each other are one mark, its tooltip
-- telling each (Text.lua's Gathering.Tips); more than `cap` a plate leaves
-- the rest off. No margin note: all a node has to say is its tooltip.
ns.UI.JourneyPlate.RegisterMark("gathered", {
    order = 72, cap = 30, count = "gatherings",
    radius = SPRIG.h / 2 + 1, halo = 18, hover = 18,
    tip = function(m, now) return Gathering.Tip(m.node, now) end,
    tips = function(list, now) return Gathering.Tips(Of(list), now) end,
    arg = Wears,
    draw = function(kit, x, y, wears)
        if wears == "herb" then
            DrawSprig(kit, x, y)
        else
            DrawPick(kit, x, y)
        end
    end,
})
