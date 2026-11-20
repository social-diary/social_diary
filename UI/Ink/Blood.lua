-- Blood on a slip of paper: dried blood splashed across one of a slip's
-- right corners and off its edge onto the page, a pool, a run or two over
-- the edge and droplets flung past it, built as the heat map's ink blots
-- are (UI/Ink/Blot.lua: drops that run together, a darker rim where it
-- dried), in the slip's own turn. It may run under the ends of the lines
-- nearest its corner, never under the name or the rest of a line, and under
-- a word it is the wash alone, lighter: the words keep their contrast.
--
-- First the witness's card (Features/Witnesses/Card.lua, 14 Oct: a page you
-- bled on, more the longer they watched); then a fight's strip on Your
-- Diary's plates (UI/Journey/Margin.lua, 20 Nov 2026, the user: "blood
-- splats on that card, like the witness card"). One look, one set of
-- sums, here; each caller says how much (an `amount` of BLOOD.amount) and
-- where its writing is.
--
-- ns.UI.Blood: BLOOD (the look, below), Keep, Spill, Stain, Under (the
-- sums, pure), Draw (a slip's textures laid from them).

local addonName, ns = ...

local Blood = {}
ns.UI.Blood = Blood

-- The blood, all in px of the slip (from its middle, y down), seeded by
-- the slip's key: a stain across one of the slip's right corners and off
-- its edges onto the page.
--   amount   by how long they watched (Text.lua's Look): the pool's drops
--            (`pool`, run together within `spread` px of its middle), the
--            lobes it splashed into (`lobes`, each a quarter of the pool,
--            in toward the slip), the runs over the right edge (`runs`)
--            and the drips over the lower or upper one (`drips`), the
--            droplets on the page round the corner (`drops`) and back on
--            the slip (`back`). A glance a small stain and a few drops;
--            watched a stain the size of a thumb's print, a run and a drip;
--            mercilessly a palm's splash, two of each and a spray
--            (14 Oct, in the client: the first, a few drops 2 or 3 px
--            across past "Wolf", read as crumbs, not a stain)
--   low      the share of cards whose blood is at the lower corner (else
--            the upper; the left has the tape)
--   out      the most anything reaches past the slip's right edge (`side`:
--            a row's boxes are 8 px apart, a right-hand column has the
--            page's edge 8 px on) and past its lower or upper one (`foot`:
--            notes down a column are 12 px apart), each leaving 3 px or
--            more to the next note. (14 Oct, the testdata pages: at 7 and
--            10 px it came within 1 px of the note beside or under it.)
--   along    how far along the edges from the corner the droplets fall
--            (px), the nearer the likelier (`near`, a power); `tail` of them
--            trail a smaller drop back toward the pool, as a flung drop does
--   size     weights (InkBlot's: a drop's size): the pool's, a droplet's,
--            a run's or a drip's first and last
--   soft     what of the writing it may run under (the user, 14 Oct: under
--            the text's edge is fine): the right end of the `lines` deed or
--            foe lines nearest its corner, `share` of each line and at most
--            `most` px of it (its last word or two). Never the name line,
--            the underlines, the chart or the rest of a line: no drop comes
--            nearer those than `clear` px
--   under    what lies under a word is the wash alone, at this alpha (the
--            words keep at least 5:1 against it, small print in INK too);
--            the core and the rim never lie under a word
--   levels   InkBlot's: the wash (the whole stain) and the core (where it
--            pooled, darker)
--   ink      dried blood on paper, never a game decal's red: the wash a
--            brown red that lets the paper through a little, the core and
--            the rim (`rim` px, where it dried) darker and browner
--   step, warp, cap   InkBlot's grid, its wobble, the most pieces a card
local BLOOD = {
    amount = {
        saw = { pool = 7, spread = 3.6, lobes = 0, runs = 0, drips = 0, drops = 6, back = 1 },
        watched = { pool = 20, spread = 7.5, lobes = 2, runs = 1, drips = 1, drops = 11, back = 2 },
        merciless = { pool = 34, spread = 10.5, lobes = 3, runs = 2, drips = 2, drops = 18, back = 3 },
    },
    low = 0.7, out = { side = 5, foot = 8 }, along = { 44, near = 1.5, tail = 0.5 },
    size = { pool = { 0.7, 1 }, drop = { 0.26, 0.85 }, run = { 0.9, 0.35 } },
    soft = { lines = 2, share = 0.45, most = 36 }, clear = 1.5, under = 0.40,
    levels = { { sigma = 2.0, edge = 0.22, from = 0, full = 1 }, { sigma = 1.8, edge = 0.55, from = 0.8, full = 1 } },
    ink = { { 0.42, 0.11, 0.06, 0.66 }, { 0.30, 0.065, 0.04, 0.6 } }, rim = 0.8, rimInk = { 0.25, 0.05, 0.03, 0.55 },
    step = 0.8, warp = { 0.6, 8 }, cap = 560,
}

-- A number from a string, the same every time (the strip's,
-- UI/Paper/Surface.lua), and a stream of them.
local Seed = ns.UI.Surface.Seed
local function Random(key)
    local rand = ns.UI.Pen.Random(Seed(key))
    return function(a, b) return a + (b - a) * rand() end, rand
end

-- Where the blood may and may not go on a card whose writing is
-- `writing` ({ name, lines, marks }: boxes { x0, y0, x1, y1 } from the
-- slip's middle, y down; `lines` the deed's and the foe's, `marks` the
-- underlines and the chart), its corner `sy` (1 the lower, -1 the upper):
-- `hard`, the boxes no drop may come near (BLOOD.soft), and `words`, every
-- box of writing (what lies under them is the wash alone, BLOOD.under).
function Blood.Keep(writing, H, sy)
    local S = BLOOD.soft
    local hard, words = { writing.name }, { writing.name }
    for _, b in ipairs(writing.marks or {}) do
        hard[#hard + 1] = b
        words[#words + 1] = b
    end
    -- The lines nearest the corner, by how far their box is from it.
    local cy = sy * H / 2
    local order = {}
    for i, b in ipairs(writing.lines or {}) do
        words[#words + 1] = b
        order[#order + 1] = { i = i, d = math.min(math.abs(b[2] - cy), math.abs(b[4] - cy)) }
    end
    table.sort(order, function(a, b) return a.d < b.d or (a.d == b.d and a.i < b.i) end)
    local soft = {}
    for k = 1, math.min(S.lines, #order) do soft[order[k].i] = true end
    for i, b in ipairs(writing.lines or {}) do
        local x1 = b[3]
        if soft[i] then x1 = b[3] - math.min(S.most, S.share * (b[3] - b[1])) end
        if x1 > b[1] then hard[#hard + 1] = { b[1], b[2], x1, b[4] } end
    end
    return hard, words
end

-- The blood's drops for a card `W` by `H` (from its middle, y down) whose
-- writing is `writing` (Keep's), by `amount`, seeded by `key`: { { x, y, t
-- } } for InkBlot.Build, every one clear of the hard writing (Keep) and
-- within BLOOD.out of the slip; the corner it lies across (`corner`, "br"
-- or "tr", where the caller chooses it; else the seed's, BLOOD.low); and
-- Keep's `hard` and `words`.
function Blood.Spill(amount, W, H, writing, key, corner)
    local B = BLOOD
    local U, rand = Random(key .. ":blood")
    local low = rand() < B.low
    -- A corner asked for (a fight's strip: the one away from its leader)
    -- over the seed's; the seed's stream goes on the same either way.
    if corner == "br" then low = true elseif corner == "tr" then low = false end
    local sy = low and 1 or -1
    local hw, hh = W / 2, H / 2
    local hard, words = Blood.Keep(writing, H, sy)
    -- A drop's radius at weight t (a lone bump of InkBlot's wash, a little
    -- more where drops run together).
    local L = B.levels[1]
    local function Radius(t)
        if t <= L.edge then return 0 end
        return L.sigma * math.sqrt(2 * math.log(t / L.edge)) + 0.9
    end
    local function Clear(x, y, t)
        local r = Radius(t)
        if x + r > hw + B.out.side or math.abs(y) + r > hh + B.out.foot then return false end
        for _, b in ipairs(hard) do
            local dx = math.max(b[1] - x, 0, x - b[3])
            local dy = math.max(b[2] - y, 0, y - b[4])
            if dx * dx + dy * dy < (r + B.clear) ^ 2 then return false end
        end
        return true
    end
    local points = {}
    local function Spill(x, y, t)
        if Clear(x, y, t) then points[#points + 1] = { x = x, y = y, t = t } end
    end
    local function Near(most) return most * rand() ^ B.along.near end
    local function Line(x0, y0, x1, y1, n)
        local S = B.size.run
        for i = 0, n - 1 do
            local f = i / (n - 1)
            Spill(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, S[1] + (S[2] - S[1]) * f)
        end
    end
    -- The pool, across the corner, its far side at the reach's limit: most
    -- of it on the slip's corner, the rest on the page.
    local r1 = Radius(1)
    local px = hw + B.out.side - r1 - amount.spread * 0.55
    local py = sy * (hh + B.out.foot - r1 - amount.spread * 0.55)
    local function Cluster(cx, cy, n, spread)
        for k = 1, n do
            local a, d = U(0, 2 * math.pi), (k == 1 and 0 or math.sqrt(rand())) * spread
            Spill(cx + d * math.cos(a), cy + d * math.sin(a), k == 1 and 1 or U(B.size.pool[1], B.size.pool[2]))
        end
    end
    Cluster(px, py, amount.pool, amount.spread)
    -- Its lobes, splashed in toward the slip (up and left of a lower
    -- corner), so the stain is never a disc.
    local inward = math.atan2(-sy, -1)
    for _ = 1, amount.lobes do
        local a = inward + math.rad(U(-65, 65))
        local d = amount.spread * U(0.8, 1.25)
        Cluster(px + d * math.cos(a), py + d * math.sin(a), math.ceil(amount.pool / 4), amount.spread * 0.45)
    end
    -- Runs over the right edge, from the slip onto the page; drips over
    -- the lower (upper) edge.
    for k = 1, amount.runs do
        local y = py - sy * (amount.spread * U(0.7, 1.3) + (k - 1) * U(6, 10))
        Line(hw - U(8, 14), y, hw + B.out.side - 1.5, y + U(-1.2, 1.2), 9)
    end
    for k = 1, amount.drips do
        local x = px - amount.spread * U(0.8, 1.6) - (k - 1) * U(7, 12)
        Line(x, sy * (hh - U(6, 10)), x + U(-1.2, 1.2), sy * (hh + B.out.foot - 1.5), 9)
    end
    -- Droplets on the page round the corner: along the right edge, or the
    -- lower (upper) one, the nearer the corner the likelier.
    for _ = 1, amount.drops do
        local t = U(B.size.drop[1], B.size.drop[2])
        local x, y
        if rand() < 0.4 then
            x, y = hw + U(1.5, B.out.side - 1), py - sy * (amount.spread + Near(math.min(B.along[1], H)))
        else
            x, y = px - amount.spread - Near(math.min(B.along[1] * 1.5, W)), sy * (hh + U(1.5, B.out.foot - 1.5))
        end
        Spill(x, y, t)
        if rand() < B.along.tail then
            local dx, dy = px - x, py - y
            local d = math.max(math.sqrt(dx * dx + dy * dy), 1)
            local back = U(2, 3.5)
            Spill(x + dx / d * back, y + dy / d * back, t * 0.55)
        end
    end
    -- And a few back on the slip, beyond the stain.
    for _ = 1, amount.back do
        local a = inward + math.rad(U(-50, 50))
        local d = amount.spread * 1.4 + U(3, 12)
        Spill(px + d * math.cos(a), py + d * math.sin(a), U(B.size.drop[1], 0.6))
    end
    return points, low and "br" or "tr", hard, words
end

-- InkBlot's pieces for `points` in the slip's px: the wash and the core,
-- and the rim, each { x1, y1, ..., x4, y4 }; no piece crosses an edge of
-- `words` (so each lies wholly under a word or wholly clear of it).
function Blood.Stain(points, W, H, words)
    local B = BLOOD
    local hw, hh = W / 2, H / 2
    local reach = math.max(B.out.side, B.out.foot) + 4
    local cutsX, cutsY = {}, {}
    for _, b in ipairs(words or {}) do
        cutsX[#cutsX + 1], cutsX[#cutsX + 2] = b[1], b[3]
        cutsY[#cutsY + 1], cutsY[#cutsY + 2] = b[2], b[4]
    end
    return ns.UI.InkBlot.Build(points, B.levels, { step = B.step, clip = { -hw - reach, -hh - reach, hw + reach,
        hh + reach }, rim = B.rim, warp = B.warp, cap = B.cap, cutsX = cutsX, cutsY = cutsY })
end

-- Whether a piece's middle lies in one of `boxes`.
function Blood.Under(q, boxes)
    local x, y = (q[1] + q[3] + q[5] + q[7]) / 4, (q[2] + q[4] + q[6] + q[8]) / 4
    for _, b in ipairs(boxes) do
        if x > b[1] and x < b[3] and y > b[2] and y < b[4] then return true end
    end
    return false
end

-- A quad of the slip (upper left, upper right, lower right, lower left,
-- from its middle, y down) on a texture of `strip`, turned with it, laid
-- flat or not; false where the client cannot move a texture's corners.
local VERTEX = Enum and Enum.VertexIndex or {}
local UL, LL, UR, LR = VERTEX.UpperLeft or 1, VERTEX.LowerLeft or 2, VERTEX.UpperRight or 3, VERTEX.LowerRight or 4
local function Quad(strip, region, x1, y1, x2, y2, x3, y3, x4, y4)
    if not region.SetVertexOffset then return false end
    local ulx, uly = strip:Screen(x1, y1)
    local urx, ury = strip:Screen(x2, y2)
    local lrx, lry = strip:Screen(x3, y3)
    local llx, lly = strip:Screen(x4, y4)
    local w = math.max(0.1, math.sqrt(((x2 + x3) - (x1 + x4)) ^ 2 + ((y2 + y3) - (y1 + y4)) ^ 2) / 2)
    local h = math.max(0.1, math.sqrt(((x4 + x3) - (x1 + x2)) ^ 2 + ((y4 + y3) - (y1 + y2)) ^ 2) / 2)
    local mx, my = (ulx + llx + urx + lrx) / 4, (uly + lly + ury + lry) / 4
    region:ClearAllPoints()
    region:SetPoint("CENTER", strip, "CENTER", mx, my)
    region:SetSize(w, h)
    if region.SetRotation then region:SetRotation(0) end
    region:SetVertexOffset(UL, ulx - (mx - w / 2), uly - (my + h / 2))
    region:SetVertexOffset(LL, llx - (mx - w / 2), lly - (my - h / 2))
    region:SetVertexOffset(UR, urx - (mx + w / 2), ury - (my + h / 2))
    region:SetVertexOffset(LR, lrx - (mx + w / 2), lry - (my - h / 2))
    return true
end

-- The blood on `strip` (laid `W` by `H`, its writing `writing`, Keep's
-- shape), `amount` of it (nil: none), seeded by `key`, at `corner` (Spill's)
-- : under the writing and the tape (its own layer, BORDER, over the slip's
-- paper and grain), each level's pieces in its ink, then the rim. `stain`
-- is the strip's list of textures, grown from `make()` as needed; the rest
-- are hidden. Where corners cannot move, none. Returns, for the tests, the
-- drops, the pieces, the corner, where it may not go and what is writing
-- ({ points, stain, corner, drawn, under, hard, words, pieces }), or nil.
function Blood.Draw(strip, stain, make, amount, W, H, writing, key, corner)
    local used, record = 0, nil
    if amount then
        local points, at, hard, words = Blood.Spill(amount, W, H, writing, key, corner)
        local built = Blood.Stain(points, W, H, words)
        local B = BLOOD
        local layers = {}
        for n, quads in ipairs(built.levels) do layers[#layers + 1] = { quads, B.ink[n], n, n == 1 } end
        layers[#layers + 1] = { built.rim, B.rimInk, 3, false }
        local drawn, under, pieces = 0, 0, {}
        for _, layer in ipairs(layers) do
            local quads, ink, sublevel, wash = layer[1], layer[2], layer[3], layer[4]
            for _, q in ipairs(quads) do
                -- Under a word: the wash alone, lighter (BLOOD.under).
                local beneath = Blood.Under(q, words)
                if wash or not beneath then
                    used = used + 1
                    local t = stain[used]
                    if not t then
                        t = make()
                        stain[used] = t
                    end
                    t:SetDrawLayer("BORDER", sublevel)
                    t:SetColorTexture(ink[1], ink[2], ink[3], beneath and B.under or ink[4])
                    if Quad(strip, t, q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8]) then
                        t:Show()
                        drawn = drawn + 1
                        pieces[drawn] = { q = q, level = sublevel, under = beneath }
                        if beneath then under = under + 1 end
                    else
                        t:Hide()
                    end
                end
            end
        end
        record = { points = points, stain = built, corner = at, drawn = drawn, under = under, hard = hard,
            words = words, pieces = pieces }
    end
    for i = used + 1, #stain do stain[i]:Hide() end
    return record
end

Blood.BLOOD = BLOOD
