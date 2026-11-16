-- Upgrades' mark on Your Diary's plates (Plate.RegisterMark,
-- UI/Journey/Plate.lua; .claude/ui-proposal/upgrades.md, the tunic, signed
-- 15 Nov 2026), drawn on every plate and the full zone page through the
-- plate's kit: a tunic where an item was first put on, the same for the
-- entry's leading upgrade (`upgrade`) and for every other piece (`piece`),
-- in the item's ink part way, as the pouch of a first found is. A gift
-- from someone in the diary is that person's moment as well (`join`): kept
-- with their marks (plate.where, plate.people), so it joins their margin
-- note ("gave you a new cloak", Text.lua's Upgrades.PERSON) and its leader
-- may come here.
--
-- At its foot the two moments are registered (Kind.lua's
-- Upgrades.Moments): a moment needs a mark of its kind (tests/kinds.lua),
-- so they wait for these.

local addonName, ns = ...

local Upgrades = ns.Upgrades

-- Something put on: a tunic, solid ink. Its `body` a box `w` wide from the
-- collar's height (`top`) to the hem (`hem`, both from the mark's middle,
-- y down); two sleeves, each a quad from the shoulder at the collar (`neck`
-- px from the middle, at `top`) out to the sleeve's upper end (`out` px
-- from the middle, at `tip`), down its cuff to (`cuff.x`, `cuff.y`) and
-- back into the armpit on the body's side at `pit`; and a `notch` of paper
-- out of the collar (`w` wide, `depth` deep), so the neck reads. Where
-- corners cannot move: the body and a bar across the shoulders (`bar`: w,
-- h, y its middle). Wide above and square below, so never the pouch (round
-- below, flared above) or the dungeon's arch (round above); a mass, never
-- the death's thin cross, whose arms are a hair wide and sit a third down
-- (the tunic's are sleeves, sloping from its very top). About 12 px each
-- way, the other marks' size. In the item's own ink (Style.QualityInk)
-- drawn `tint` of the way from the plain ink, the pouch's own rule and
-- number, so the pouch and the tunic of one item are one ink; an upgrade
-- is green or better, so a tunic is never plain. (15 Nov, the proposal's
-- mockup at 2x beside the pouch, the death, the star and the tally: the
-- tunic read as "put on"; a buckle read as the letter D, a shield as a
-- second pouch.)
local MARK = { body = { w = 6, top = -5.6, hem = 5.6 }, neck = 2, out = 6.2, tip = -3, cuff = { x = 4.8, y = -0.2 },
    pit = -1.3, notch = { w = 4, depth = 2.2 }, bar = { w = 12.4, h = 3, y = -3.4 }, tint = 0.6, height = 11.2,
    halo = 16 }
Upgrades.MARK = MARK


-- The best of them first (by quality, then the earlier), and the ink the
-- tunic is drawn in: the best one's, part way from the plain ink.
local function Ink(list)
    table.sort(list, function(a, b)
        local qa, qb = a.upgrade.quality or 0, b.upgrade.quality or 0
        if qa ~= qb then return qa > qb end
        return a.t < b.t
    end)
    local INK_STRONG = ns.Style.INK_STRONG
    local own = ns.Style.QualityInk(list[1].upgrade.quality)
    if not own then return INK_STRONG end
    local t = MARK.tint
    return { INK_STRONG[1] + (own[1] - INK_STRONG[1]) * t, INK_STRONG[2] + (own[2] - INK_STRONG[2]) * t,
        INK_STRONG[3] + (own[3] - INK_STRONG[3]) * t }
end

-- A tunic in `colour`, lit where it lies.
local function Draw(kit, x, y, colour)
    local B, C, N = MARK.body, MARK.cuff, MARK.notch
    colour = colour or kit.INK_STRONG
    kit.Box(kit.ink, x, y + (B.top + B.hem) / 2, B.w, B.hem - B.top, colour, 1)
    local light = kit.Light(x, y)
    local bent = true
    for _, side in ipairs({ -1, 1 }) do
        local sleeve = kit.ink:Next()
        kit.Fill(sleeve, colour[1] * light, colour[2] * light, colour[3] * light, 1)
        if not kit.Quad(sleeve, x + side * MARK.neck, y + B.top, x + side * MARK.out, y + MARK.tip,
            x + side * C.x, y + C.y, x + side * B.w / 2, y + MARK.pit) then
            sleeve:Hide()
            bent = false
        end
    end
    if not bent then
        kit.Box(kit.ink, x, y + MARK.bar.y, MARK.bar.w, MARK.bar.h, colour, 1)
        return
    end
    -- The collar: a nick of paper out of the top's middle.
    local notch = kit.inner:Next()
    kit.Fill(notch, kit.P[1], kit.P[2], kit.P[3], 1)
    if not kit.Quad(notch, x - N.w / 2, y + B.top - 0.2, x + N.w / 2, y + B.top - 0.2, x, y + B.top + N.depth,
        x, y + B.top + N.depth) then
        notch:Hide()
    end
end

-- A gift from someone in the diary joins their marks.
local function Join(m)
    return m.gift and m.guid and ns.Diary.IsDiary(m.guid)
end

-- The entry's leading upgrade: right after the pouch (order 7: the pouch
-- is 5, a chain's tailpiece 10), so where an item was put on where it was
-- found the pouch holds the spot and the tunic stands beside it, and
-- every later kind steps round the two. Kept (plate.upgradeMarks) for the
-- plate's one card (Card.lua, plate.upgrade: the first of them, an entry
-- has one).
ns.UI.JourneyPlate.RegisterMark("upgrade", {
    order = 7, cap = 10, count = "upgrades",
    radius = MARK.height / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now)
        local title, line = Upgrades.Tip(m, now)
        return title, { line }
    end,
    tips = function(list, now) return Upgrades.Tips(list, now) end,
    keep = "upgradeMarks", chosen = "upgrade",
    choose = function(marks)
        local mark = marks[1]
        local m = mark and mark.list and mark.list[1]
        return m and { m = m, rec = m.upgrade, mark = mark.at } or nil
    end,
    arg = Ink, join = Join, draw = Draw,
})

-- Every other piece: filler (the user: "let others fill an existing open
-- plate low prio", and "they do get a mark"), so after the paw (67) and
-- before the campfire (70): where they crowd, it is the tunic of a piece
-- that steps aside, with its tether. At most 10 a plate. Kept
-- (plate.pieceMarks) for the plate's one small note (Card.lua,
-- plate.pieces: every piece on the plate, and the first mark for its
-- leader).
ns.UI.JourneyPlate.RegisterMark("piece", {
    order = 68, cap = 10, count = "pieces",
    radius = MARK.height / 2 + 1, halo = MARK.halo, hover = MARK.halo,
    tip = function(m, now)
        local title, line = Upgrades.Tip(m, now)
        return title, { line }
    end,
    tips = function(list, now) return Upgrades.Tips(list, now) end,
    keep = "pieceMarks", chosen = "pieces",
    choose = function(marks)
        local chosen
        for _, mark in ipairs(marks) do
            for _, m in ipairs(mark.list or {}) do
                chosen = chosen or { list = {}, mark = mark.at }
                chosen.list[#chosen.list + 1] = { m = m, rec = m.upgrade, mark = mark.at }
            end
        end
        return chosen
    end,
    arg = Ink, join = Join, draw = Draw,
})

-- The two moments, now that their marks are registered (kinds.lua: a
-- moment needs a mark of its kind).
Upgrades.Moments()
