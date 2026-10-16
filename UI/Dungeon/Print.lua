-- Adapted from Dungeon Crawler Forever 0.1.11 (Per, GPL-3.0-or-later): a
-- route's stops taken from their bosses and its runs broken where a point
-- leaves the floor shown (UI/Route.lua's followBosses and RenderRoute),
-- changed 2026-10-16: drawn with our own pen, in ink and pencil.
--
-- The dungeon page's print (MAP-1 to MAP-4, MAP-7): one floor of the
-- dungeon printed on photo stock and glued into the page, as Your Diary's
-- plates are (UI/Journey/Plate.lua's PLATE, SHADOW, THICKNESS, VIGNETTE and
-- MOUNT, read from it as it draws), but flat: no turn, no lift. On it, what
-- happened there, never a guide:
--   the art     the floor (ns.UI.DungeonMap), greyed part way and warmed
--               toward the page, in a neat line of ink (FRAME), its edges
--               darkened as an old print's (none laid flat)
--   the way     the usual way through (ns.Dungeons.Route, the author's, not
--               the user's: there are no coordinates inside), inked as far
--               as the furthest boss killed, the rest in pencil (ROUTE)
--   the door    where the way in is, a doorway's arch (the plates' DOOR)
--   bosses      each its own face, round (Style.BossMedallion, MEDAL):
--               killed in brass, numbered in the order they fell (a kill
--               only its loot told of, unnumbered); a rare
--               (only when killed) in silver; still standing greyed and
--               faded in a ring of pencil; trash never. A boss with no face
--               to show: a red lozenge inked round for a kill (KILL), a
--               faint pencil ring for one standing (STANDING)
--   deaths      small crosses (MAP-14, DEATH): in ink round the boss they
--               died at; in pencil on the way between two bosses, where
--               the time says (approximate, and it says so); without a
--               way through, by the boss, else at the print's foot
-- A drawn map's artist is credited on the About page (Licensing), not here.
-- Each mark has a tooltip; there is no key (the plates' Decision 7).
-- Drawn once as the page opens or a floor is chosen, from pools; nothing
-- per frame, nothing random: seeded by the visit, so it lies the same way
-- every time.

local addonName, ns = ...

local Style = ns.Style

local DungeonPage = {}
ns.UI.DungeonPage = DungeonPage

-- The card: `margin` px of stock round the art; photo corners as on a
-- lone plate (`corner`, the slot's pc in UI/Journey/Look.lua's terms).
-- The neat line round the art: ink at `alpha`, `inner` px hugging it, a
-- `gap`, an `outer` hairline (the plates' FRAME).
local CARD = { margin = 8, corner = 26, edge = 0.30 }
local FRAME = { inner = 1.5, gap = 1.5, outer = 1, alpha = 0.65 }

-- A boss killed with no face to show: on a dot of the card's stock
-- (`halo` across, at `haloAlpha`), a lozenge of ink `edge` px with a red
-- one `fill` px in it, the card's boss marks (Style.Pips) at map size.
-- Every kill's number in the order they fell, `size` pt, on a dot of stock
-- `halo` across (where: APART.spots).
local KILL = { halo = 15, haloAlpha = 0.75, edge = 10, fill = 6.5,
    number = { size = 10, halo = 11 } }
-- A boss still standing: a faint pencil ring drawn by hand, `radius` px,
-- in `strokes` pieces `width` wide at `alpha`, a little uneven (`wobble`)
-- and over its start by `overshoot` of a turn; on a fainter dot of stock.
local STANDING = { radius = 5.5, strokes = 16, width = 1.1, alpha = 0.72, wobble = 0.07, overshoot = 0.1,
    halo = 15, haloAlpha = 0.38 }
-- The way through: resampled every `step` px after `smooth` rounds of
-- corner cutting. Inked as far as you went (`ink`: the pen's nib on a
-- line `width` wide at `alpha`), the rest pencil (`pencil`, even). At most
-- `budget` pieces in all.
local ROUTE = { step = 4, smooth = 2, budget = 700,
    ink = { width = 2.2, alpha = 0.82 }, pencil = { width = 1.1, alpha = 0.5 } }
-- A boss's face: `kill` px across for a kill (a rare's too), `standing`
-- for one still standing, smaller, as it is only pencil.
local MEDAL = { kill = 24, standing = 20 }
-- The square over each mark that takes the mouse.
local HOVER = 22
-- A death: a small cross, the plates' (UI/Journey/Plate.lua's death
-- shape: a stem `stem` = { w, h } and a bar `bar` `up` px up), on a dot of
-- stock `halo` across. At a boss in ink, `ring` px out from the edge of
-- its mark, from `start` degrees (y down: the left, clear of its number
-- at the upper right and the leaders coming up from below) `step` degrees
-- apart, at most `most`; on the way in pencil at
-- `pencil`. Its tooltip takes a square `hit` px. At the print's foot, a
-- row `gap` px apart.
local DEATH = { stem = { 1.6, 7 }, bar = { 5, 1.6 }, up = 1.5, halo = 10, haloAlpha = 0.8, ring = 6,
    start = 195, step = 30, most = 6, pencil = 0.9, hit = 10, gap = 9 }
-- Marks never touch (the plates' rule, 9 Oct: side by side they read as
-- letters): each keeps `clear` px from those placed before it, the kills
-- first, moving out to the first free place on rings `step` px apart
-- (`tries` rings of eight headings), with a pencil tether (`tether`:
-- width, alpha) back to where the boss stands. A kill's number takes the
-- first of `spots` round its mark `gap` px clear of every mark and number.
local APART = { clear = 25, step = 9, tries = 3, tether = { 0.8, 0.5 }, gap = 12,
    spots = { { 13, -11 }, { -13, -11 }, { 13, 11 }, { -13, 11 }, { 0, -16 }, { 0, 16 }, { 16, 0 }, { -16, 0 } } }

DungeonPage.CARD, DungeonPage.KILL, DungeonPage.STANDING, DungeonPage.ROUTE = CARD, KILL, STANDING, ROUTE
DungeonPage.APART, DungeonPage.MEDAL, DungeonPage.DEATH = APART, MEDAL, DEATH

--------------------------------------------------------------------------
-- What is drawn
--------------------------------------------------------------------------

-- The wing a visit was to: its own, else its first kill's (INS-27). The
-- kills by the data's records (ns.Dungeons.Killed): the client may name a
-- boss otherwise ("Infurnus" for the data's Magmatus), its id agrees.
function DungeonPage.Wing(visit)
    if visit.wing then return visit.wing end
    local first = ns.Dungeons.Killed(visit)[1]
    return first and ns.Dungeons.WingOf(visit.instanceID, first.name) or nil
end

-- The face a dungeon's medallion wears where the client has no picture of
-- it (a Forever dungeon): its last boss's, the one the run is for, as
-- { display, portrait } for Style.Medallion; nil for a dungeon the diary
-- does not know.
function DungeonPage.Face(visit)
    local D = ns.Dungeons
    local bosses = D.Bosses(visit.instanceID, visit.difficultyID, DungeonPage.Wing(visit))
    for i = #bosses, 1, -1 do
        local b = bosses[i]
        if D.Counts(visit.instanceID, b) and (b.display or b.portrait) then
            return { display = b.display, portrait = b.portrait }
        end
    end
end

-- When each boss fell, by the data's name for it (ns.Dungeons.Norm): its
-- place among the kills, in the run's notes' order (by when they fell)
-- where given, else ns.Dungeons.Killed's. Never matched by the client's
-- names, which may differ from the data's.
local function KilledAt(visit, notes)
    local at, n = {}, 0
    local Norm = ns.Dungeons.Norm
    if notes then
        for _, e in ipairs(notes.bosses or {}) do
            if e.killed then
                n = n + 1
                at[Norm(e.boss.name)] = at[Norm(e.boss.name)] or n
            end
        end
        return at
    end
    for i, b in ipairs(ns.Dungeons.Killed(visit)) do
        at[Norm(b.name)] = at[Norm(b.name)] or i
    end
    return at
end

-- The name the game gave each boss where it is not the data's ("Infurnus"
-- for Magmatus): what the page calls it. By the data's name.
function DungeonPage.Names(notes)
    local names = {}
    for _, e in ipairs(notes and notes.bosses or {}) do
        if e.client then names[e.boss.name] = e.client end
    end
    return names
end

-- The bosses to mark (MAP-2): every boss that stands somewhere, killed or
-- not, but a rare only when killed and never the trash. { boss, killed,
-- inferred, fell, order, rare }, in the dungeon's order. A kill only its
-- loot told of (MAP-16: visit.inferred, or the run's `notes`, which also
-- prove an older run's) is `inferred`: a kill, but unnumbered, as when it
-- fell is only a guess; `order` numbers the kills the diary saw, in the
-- order they fell, and `fell` sorts them all.
function DungeonPage.Marks(visit, wing, notes)
    local D = ns.Dungeons
    local at, out = KilledAt(visit, notes), {}
    local proven = {}
    for name in pairs(visit.inferred or {}) do proven[D.Norm(name)] = true end
    for _, e in ipairs(notes and notes.bosses or {}) do
        if e.inferred then proven[D.Norm(e.boss.name)] = true end
    end
    for i, b in ipairs(D.Bosses(visit.instanceID, visit.difficultyID, wing)) do
        if not b.trash and b.floor and b.x and b.y then
            local key = D.Norm(b.name)
            local seen, inferred = at[key], proven[key] or nil
            local rare = D.IsRare(visit.instanceID, b.name)
            if seen or inferred or not rare then
                out[#out + 1] = { boss = b, killed = (seen or inferred) ~= nil, inferred = inferred,
                    fell = seen or (inferred and 1000 + i) or nil, rare = rare }
            end
        end
    end
    local kills = {}
    for _, mark in ipairs(out) do
        if mark.killed and not mark.inferred then kills[#kills + 1] = mark end
    end
    table.sort(kills, function(a, b) return a.fell < b.fell end)
    for n, mark in ipairs(kills) do mark.order = n end
    return out
end

--------------------------------------------------------------------------
-- The print
--------------------------------------------------------------------------

-- A new print on `parent`; :Lay(spec) draws it.
function DungeonPage.Print(parent)
    local print = CreateFrame("Frame", nil, parent)
    local base = print:GetFrameLevel()

    -- Above the art: its edges, the neat line, the way, the marks. Above
    -- them the photo corners, and over all the squares that take the mouse.
    local canvas = ns.UI.DungeonMap.New(print)
    canvas:SetFrameLevel(base + 1)
    local over = CreateFrame("Frame", nil, print)
    over:SetAllPoints()
    over:SetFrameLevel(base + 3)
    local mount = CreateFrame("Frame", nil, print)
    mount:SetAllPoints()
    mount:SetFrameLevel(base + 5)
    -- The faces over the marks, under the corners; the kills' numbers
    -- over the faces.
    local medals = CreateFrame("Frame", nil, print)
    medals:SetAllPoints()
    medals:SetFrameLevel(base + 4)
    local labels = CreateFrame("Frame", nil, print)
    labels:SetAllPoints()
    labels:SetFrameLevel(base + 6)
    local hits = CreateFrame("Frame", nil, print)
    hits:SetAllPoints()
    hits:SetFrameLevel(base + 7)
    print.canvas, print.over, print.mount = canvas, over, mount

    local function Textures(frame, layer, sublevel)
        return ns.UI.Pool.New(function()
            local t = frame:CreateTexture(nil, layer, nil, sublevel)
            if t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
            return t
        end)
    end
    local pools = {
        shadow = Textures(print, "BACKGROUND", -6),
        card = Textures(print, "BACKGROUND", -4),
        edge = Textures(print, "BORDER", 0),
        vignette = Textures(over, "ARTWORK", 0),
        frame = Textures(over, "ARTWORK", 1),
        route = Textures(over, "ARTWORK", 3),
        tether = Textures(over, "ARTWORK", 4),
        halo = Textures(over, "OVERLAY", 0),
        ink = Textures(over, "OVERLAY", 2),
        fill = Textures(over, "OVERLAY", 3),
        cross = Textures(over, "OVERLAY", 4),
        crossHalo = Textures(over, "OVERLAY", 1),
        -- The margin notes' leaders (UI/Dungeon/Notes.lua), over the art
        -- and its crosses, under the faces.
        leader = Textures(over, "OVERLAY", 6),
        cornerShadow = Textures(mount, "ARTWORK", 0),
        corner = Textures(mount, "ARTWORK", 1),
        fold = Textures(mount, "ARTWORK", 2),
        medal = ns.UI.Pool.New(function() return Style.BossMedallion(medals, MEDAL.kill) end),
        sketch = ns.UI.Pool.New(function() return Style.BossMedallion(medals, MEDAL.standing) end),
        numberHalo = Textures(labels, "ARTWORK", 0),
        number = ns.UI.Pool.New(function()
            local text = labels:CreateFontString(nil, "OVERLAY")
            text:SetFont(Style.FRIZ, KILL.number.size, "")
            text:SetTextColor(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], 1)
            text:SetShadowOffset(0, 0)
            return text
        end),
        hit = ns.UI.Pool.New(function()
            local hit = CreateFrame("Frame", nil, hits)
            hit:SetSize(HOVER, HOVER)
            hit:EnableMouse(true)
            Style.Tooltip(hit, function(self) return self.tip end, "ANCHOR_RIGHT")
            return hit
        end),
    }
    print.pools = pools

    print.Lay = DungeonPage.Lay
    return print
end

-- The drawing kit over one print: `print` is the frame everything is
-- placed on (x right, y down from its top left).
local function Kit(print, canBend)
    local K = {}

    function K.Place(texture, x, y, w, h)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", print, "TOPLEFT", x, -y)
        texture:SetSize(w, h)
        if texture.SetRotation then texture:SetRotation(0) end
    end

    function K.Fill(texture, c, a)
        texture:SetTexture(nil)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetColorTexture(c[1], c[2], c[3], a)
    end

    -- A round spot `size` across, its middle at x, y.
    function K.Dot(pool, x, y, size, c, a)
        local texture = pool:Next()
        texture:SetVertexColor(1, 1, 1, 1)
        Style.Disc(texture, c[1], c[2], c[3], a)
        K.Place(texture, x - size / 2, y - size / 2, size, size)
        return texture
    end

    -- A square `size` across turned on its point, its middle at x, y.
    function K.Lozenge(pool, x, y, size, c, a)
        local texture = pool:Next()
        K.Fill(texture, c, a)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", print, "TOPLEFT", x, -y)
        texture:SetSize(size, size)
        if texture.SetRotation then texture:SetRotation(math.pi / 4) end
        return texture
    end

    -- A straight stroke `width` wide from one point to the other: a
    -- texture turned to it (on the screen y runs up). None where textures
    -- cannot turn.
    function K.Stroke(pool, x1, y1, x2, y2, width, c, a)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.01 then return nil end
        local texture = pool:Next()
        if not texture.SetRotation then
            texture:Hide()
            return nil
        end
        K.Fill(texture, c, a)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", print, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
        texture:SetSize(length + 0.5, width)
        texture:SetRotation(math.atan2(-dy, dx))
        return texture
    end

    -- Any four points (Style.Quad's order), or `fx, fy, fw, fh` where the
    -- client cannot move corners.
    function K.Quad(pool, c, a, x1, y1, x2, y2, x3, y3, x4, y4, fx, fy, fw, fh)
        local texture = pool:Next()
        K.Fill(texture, c, a)
        if canBend and Style.Quad(texture, print, x1, y1, x2, y2, x3, y3, x4, y4) then return texture end
        if fx then K.Place(texture, fx, fy, fw, fh) else texture:Hide() end
        return texture
    end

    return K
end

-- Whether textures here can have their corners moved (Style.Quad).
local function CanBend(print)
    local probe = print.pools.card[1] or print:CreateTexture(nil, "BACKGROUND", nil, -8)
    local asked, fn = pcall(function() return probe.SetVertexOffset end)
    return asked and type(fn) == "function"
end

-- The card, its grain, its edges and its shadow on the page.
local function Card(print, K, W, H, flat)
    local Plate = ns.UI.JourneyPlate
    local P, S, T, INK = Plate.PLATE, Plate.SHADOW, Plate.THICKNESS, Style.INK
    local pools = print.pools
    local paper = pools.card:Next()
    K.Fill(paper, P.stock, 1)
    K.Place(paper, 0, 0, W, H)
    local grain = Style.Art("grain")
    if grain then
        local g = pools.card:Next()
        g:SetTexture(grain)
        g:SetVertexColor(1, 1, 1, 1)
        g:SetTexCoord(0.31, 0.58, 0.12, 0.47)
        g:SetAlpha(0.14)
        K.Place(g, 0, 0, W, H)
    end

    -- Its ink outline, and lit from the top left: the top and left cut
    -- edges catch the light, the bottom and right fall away.
    for _, e in ipairs({ { 0, 0, W, 1 }, { 0, H - 1, W, 1 }, { 0, 0, 1, H }, { W - 1, 0, 1, H } }) do
        local line = pools.edge:Next()
        K.Fill(line, INK, CARD.edge)
        K.Place(line, e[1], e[2], e[3], e[4])
    end
    if flat then return end
    for _, e in ipairs({ { 0, T.at, W, T.width }, { T.at, 0, T.width, H } }) do
        local light = pools.edge:Next()
        K.Fill(light, T.light, T.lightAlpha)
        K.Place(light, e[1], e[2], e[3], e[4])
    end
    for _, e in ipairs({ { 1, H - 2, W - 2, T.width }, { W - 2, 1, T.width, H - 2 } }) do
        local dark = pools.edge:Next()
        K.Fill(dark, INK, T.darkAlpha)
        K.Place(dark, e[1], e[2], e[3], e[4])
    end

    -- Glued flat: a soft band along the bottom and the right, meeting on a
    -- mitre, their far ends slanted in, and the dark line where it touches.
    local d, b, c = S.out, S.blur, S.core.out
    local soft = K.Quad(pools.shadow, INK, 1, d + b, H - 1, W - 1, H - 1, W + d + b, H + d + b, d, H + d + b,
        d, H - 1, W, d + b + 1)
    Style.Shade(soft, "VERTICAL", INK[1], INK[2], INK[3], 0, S.alpha)
    soft = K.Quad(pools.shadow, INK, 1, W - 1, d + b, W + d + b, d, W + d + b, H + d + b, W - 1, H - 1,
        W - 1, d, d + b + 1, H)
    Style.Shade(soft, "HORIZONTAL", INK[1], INK[2], INK[3], S.alpha, 0)
    K.Quad(pools.shadow, INK, S.core.alpha, 0.5 + c, H - 1, W - 1, H - 1, W + c, H + c, 0.5, H + c,
        0.5, H - 1, W, c + 1)
    K.Quad(pools.shadow, INK, S.core.alpha, W - 1, 0.5 + c, W + c, 0.5, W + c, H + c, W - 1, H - 1,
        W - 1, 0.5, c + 1, H)
end

-- The print's darkened edges (VIGNETTE): a band inside each side of the
-- art, each side's darkness a little its own.
local function Vignette(print, K, ax, ay, aw, ah, seed)
    local V = ns.UI.JourneyPlate.VIGNETTE
    local T, d = V.tint, V.depth * math.min(aw, ah)
    local function A(side, n)
        return V.alpha[side] * (1 + (Style.Noise(seed * 0.71 + n) - 0.5) * 2 * V.uneven)
    end
    local pool = print.pools.vignette
    local bands = {
        { "VERTICAL", 0, A("top", 1), ax, ay, aw, d },
        { "VERTICAL", A("bottom", 2), 0, ax, ay + ah - d, aw, d },
        { "HORIZONTAL", A("left", 3), 0, ax, ay, d, ah },
        { "HORIZONTAL", 0, A("right", 4), ax + aw - d, ay, d, ah },
    }
    for _, band in ipairs(bands) do
        local t = pool:Next()
        t:SetTexture(nil)
        -- VERTICAL runs from the bottom up.
        Style.Shade(t, band[1], T[1], T[2], T[3], band[2], band[3])
        K.Place(t, band[4], band[5], band[6], band[7])
    end
end

-- The neat line: a rule hugging the art, a gap, a hairline.
local function NeatLine(print, K, x0, y0, x1, y1)
    local ink, pool = Style.INK_STRONG, print.pools.frame
    for _, ring in ipairs({ { 0, FRAME.inner }, { FRAME.inner + FRAME.gap, FRAME.outer } }) do
        local o, w = ring[1], ring[2]
        for _, r in ipairs({
            { x0 - o - w, y0 - o - w, x1 - x0 + 2 * (o + w), w },
            { x0 - o - w, y1 + o, x1 - x0 + 2 * (o + w), w },
            { x0 - o - w, y0 - o, w, y1 - y0 + 2 * o },
            { x1 + o, y0 - o, w, y1 - y0 + 2 * o },
        }) do
            local t = pool:Next()
            K.Fill(t, ink, FRAME.alpha)
            K.Place(t, r[1], r[2], r[3], r[4])
        end
    end
end

-- A photo corner (the plates' MOUNT): its shadow, the kraft pocket a shade
-- of its own, and the light on its fold by how the fold faces the top-left
-- light. Laid flat, the pocket alone; where corners cannot move, an L of
-- two strips.
local R2 = math.sqrt(0.5)
local function Corner(print, K, which, W, H, flat, seed, canBend)
    local M = ns.UI.JourneyPlate.MOUNT
    local size, o = CARD.corner * M.scale, M.out
    local pts
    if which == "tl" then pts = { -o, -o, size - o, -o, -o, size - o, -o, size - o }
    elseif which == "tr" then pts = { W - size + o, -o, W + o, -o, W + o, size - o, W + o, size - o }
    elseif which == "bl" then pts = { -o, H - size + o, -o, H - size + o, size - o, H + o, -o, H + o }
    else pts = { W + o, H - size + o, W + o, H - size + o, W + o, H + o, W - size + o, H + o } end
    local tone = 1 + (Style.Noise(seed) - 0.5) * 2 * M.uneven
    local layers = { { print.pools.corner, 0, 0, { M.ink[1] * tone, M.ink[2] * tone, M.ink[3] * tone }, M.alpha } }
    if not flat then
        table.insert(layers, 1, { print.pools.cornerShadow, M.shadow[1], M.shadow[2], M.shade, M.shadow[3] })
    end
    for _, l in ipairs(layers) do
        local pool, dx, dy, c, a = l[1], l[2], l[3], l[4], l[5]
        if canBend then
            K.Quad(pool, c, a, pts[1] + dx, pts[2] + dy, pts[3] + dx, pts[4] + dy, pts[5] + dx, pts[6] + dy,
                pts[7] + dx, pts[8] + dy)
        else
            local left = (which == "tl" or which == "bl") and -o or W + o - size
            local top = (which == "tl" or which == "tr") and -o or H + o - size
            local hy = (which == "tl" or which == "tr") and -o or H + o - M.strip
            local vx = (which == "tl" or which == "bl") and -o or W + o - M.strip
            for _, s in ipairs({ { left, hy, size, M.strip }, { vx, top, M.strip, size } }) do
                local t = pool:Next()
                K.Fill(t, c, a)
                K.Place(t, s[1] + dx, s[2] + dy, s[3], s[4])
            end
        end
    end
    if flat or not canBend then return end
    -- The fold: the diagonal, a line just inside it toward the print's
    -- middle, its ends drawn in so it stays on the pocket.
    local ax, ay, bx, by, nx, ny
    if which == "tl" then ax, ay, bx, by, nx, ny = pts[3], pts[4], pts[5], pts[6], R2, R2
    elseif which == "tr" then ax, ay, bx, by, nx, ny = pts[1], pts[2], pts[5], pts[6], -R2, R2
    elseif which == "bl" then ax, ay, bx, by, nx, ny = pts[1], pts[2], pts[5], pts[6], R2, -R2
    else ax, ay, bx, by, nx, ny = pts[1], pts[2], pts[7], pts[8], -R2, -R2 end
    local f = M.fold
    local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local ux, uy = (bx - ax) / len, (by - ay) / len
    ax, ay, bx, by = ax + ux * f * 1.5, ay + uy * f * 1.5, bx - ux * f * 1.5, by - uy * f * 1.5
    local facing = (-nx - ny) * R2
    K.Quad(print.pools.fold, M.light, M.lo + (M.hi - M.lo) * (facing + 1) / 2,
        ax - nx * f, ay - ny * f, bx - nx * f, by - ny * f, bx, by, ax, ay)
end

-- The way through on the print: `At(floor, x, y)` places a point of any
-- floor on it, or nil. { route, pts (each { x, y }, or false off the floor
-- shown), stops (a boss's name, ns.Dungeons.Norm, to its point), reached
-- (the furthest stop whose boss fell) }, or nil without a way through.
-- A stop is its boss: where the boss stands, the way meets it.
local function Path(visit, wing, At, notes)
    local D = ns.Dungeons
    local route = D.Route(visit.instanceID, wing)
    if not route or #route < 2 then return nil end
    local at, pts, stops, reached = KilledAt(visit, notes), {}, {}, 0
    for i, p in ipairs(route) do
        local f, x, y = p.f, p.x, p.y
        local b = p.boss and D.Boss(visit.instanceID, p.boss)
        if b and b.floor and b.x then f, x, y = b.floor, b.x, b.y end
        local px, py = At(f, x, y)
        pts[i] = px and { px, py } or false
        if p.boss then
            local key = D.Norm(p.boss)
            stops[key] = stops[key] or i
            if at[key] then reached = i end
        end
    end
    return { route = route, pts = pts, stops = stops, reached = reached }
end

-- The way through (MAP-4) over the art, along `path` (Path): inked from
-- the start to the furthest stop whose boss fell, the rest in pencil;
-- broken where it leaves the floor or jumps (a linked stair, `pair`).
-- Returns how many pieces of each were drawn.
local function DrawRoute(print, K, path, canBend)
    local Pen = ns.UI.Pen
    local counts = { ink = 0, pencil = 0 }
    if not path then return counts end
    local route, pts, reached = path.route, path.pts, path.reached

    local budget = ROUTE.budget
    local pool = print.pools.route
    local function Draw(from, to, look, colour, nib)
        if to <= from or budget <= 0 then return 0 end
        local flatPts = {}
        for k = from, to do
            flatPts[#flatPts + 1] = pts[k][1]
            flatPts[#flatPts + 1] = pts[k][2]
        end
        local P = Pen.Resample(Pen.Chaikin(flatPts, ROUTE.smooth), ROUTE.step)
        if #P < 2 then return 0 end
        local M, n = Pen.Mitres(P), #P
        local function Half(k)
            if not nib then return look.width / 2 end
            local a, b = P[math.max(k - 1, 1)], P[math.min(k + 1, n)]
            return look.width / 2 * Pen.Nib(b.x - a.x, b.y - a.y)
        end
        local prims = {}
        Pen.Stroke(prims, 0, P, M, Half, function() return 0 end, function() return look.alpha end, colour, nil,
            budget)
        for _, q in ipairs(prims) do
            local texture = pool:Next()
            K.Fill(texture, { q.r, q.g, q.b }, q.a)
            if not (canBend and Style.Quad(texture, print, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4)) then
                pool.used = pool.used - 1
                texture:Hide()
                local w = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
                    + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
                K.Stroke(pool, (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2, (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2, w,
                    { q.r, q.g, q.b }, q.a)
            end
        end
        budget = budget - #prims
        return #prims
    end

    local i = 1
    while i <= #route do
        if not pts[i] then
            i = i + 1
        else
            local j = i
            while j < #route and pts[j + 1] and not route[j + 1].pair do j = j + 1 end
            local split = math.max(i, math.min(j, reached))
            counts.ink = counts.ink + Draw(i, split, ROUTE.ink, Style.INK, true)
            counts.pencil = counts.pencil + Draw(split, j, ROUTE.pencil, Style.GRAPHITE, false)
            i = j + 1
        end
    end
    return counts
end

-- A tooltip over a mark at x, y, `size` px square (HOVER by default).
local function Hit(print, x, y, tip, size)
    local hit = print.pools.hit:Next()
    hit:ClearAllPoints()
    hit:SetPoint("CENTER", print, "TOPLEFT", x, -y)
    hit:SetSize(size or HOVER, size or HOVER)
    hit.tip = tip
end

-- The first free place for a mark near x, y (APART), inside the box.
local function Apart(x, y, placed, box)
    local function Free(px, py)
        for _, q in ipairs(placed) do
            if (q.x - px) ^ 2 + (q.y - py) ^ 2 < APART.clear ^ 2 then return false end
        end
        return true
    end
    local function Inside(px, py)
        return math.max(box[1], math.min(box[3], px)), math.max(box[2], math.min(box[4], py))
    end
    if Free(x, y) then return x, y end
    for ring = 1, APART.tries do
        for k = 0, 7 do
            local a = k * math.pi / 4
            local px, py = Inside(x + math.cos(a) * APART.step * ring, y + math.sin(a) * APART.step * ring)
            if Free(px, py) then return px, py end
        end
    end
    return x, y
end

-- Where a kill's number goes round its mark at x, y: the first of
-- APART.spots clear of the marks and the numbers already placed.
local function NumberAt(x, y, marks, numbers, box)
    local function Clear(px, py)
        if px < box[1] or px > box[3] or py < box[2] or py > box[4] then return false end
        for _, list in ipairs({ marks, numbers }) do
            for _, q in ipairs(list) do
                if (q.x - px) ^ 2 + (q.y - py) ^ 2 < APART.gap ^ 2 then return false end
            end
        end
        return true
    end
    for _, spot in ipairs(APART.spots) do
        if Clear(x + spot[1], y + spot[2]) then return x + spot[1], y + spot[2] end
    end
    return x + APART.spots[1][1], y + APART.spots[1][2]
end

-- A boss's face at x, y in `pool`'s medallions, as `look` (killed, rare,
-- standing): how it came ("display" or "portrait"), or nil and none
-- shown where the boss has no face to show.
local function Face(print, pool, x, y, look, boss)
    local medal = pool:Next()
    local how = medal:SetBoss(look, boss.display, boss.portrait)
    if not how then
        medal:Hide()
        pool.used = pool.used - 1
        return nil
    end
    medal:ClearAllPoints()
    medal:SetPoint("CENTER", print, "TOPLEFT", x, -y)
    return how
end

-- A boss killed with no face to show (KILL): a red lozenge inked round.
local function Killed(print, K, x, y, stock)
    local pools = print.pools
    K.Dot(pools.halo, x, y, KILL.halo, stock, KILL.haloAlpha)
    K.Lozenge(pools.ink, x, y, KILL.edge, Style.INK_STRONG, 1)
    K.Lozenge(pools.fill, x, y, KILL.fill, Style.RUBRIC, 1)
end

-- A kill's number in the order they fell, at nx, ny on a dot of stock.
local function Number(print, K, number, nx, ny, stock)
    local pools = print.pools
    K.Dot(pools.numberHalo, nx, ny, KILL.number.halo, stock, KILL.haloAlpha)
    local text = pools.number:Next()
    text:ClearAllPoints()
    text:SetPoint("CENTER", print, "TOPLEFT", nx, -ny)
    text:SetText(tostring(number))
end

-- A boss still standing (STANDING): a ring in pencil, by hand.
local function Standing(print, K, x, y, seed, stock)
    local S = STANDING
    K.Dot(print.pools.halo, x, y, S.halo, stock, S.haloAlpha)
    local a0 = Style.Noise(seed) * 2 * math.pi
    local sweep = 2 * math.pi * (1 + S.overshoot)
    local px, py
    for i = 0, S.strokes do
        local t = a0 + sweep * i / S.strokes
        local grow = 1 + S.wobble * math.sin(3 * t + seed) + S.wobble * i / S.strokes
        local qx, qy = x + S.radius * grow * math.cos(t), y + S.radius * grow * math.sin(t)
        if px then K.Stroke(print.pools.ink, px, py, qx, qy, S.width, Style.GRAPHITE, S.alpha) end
        px, py = qx, qy
    end
end

-- The way in: a doorway's arch, as on the plates (their DOOR, MARK.door).
local function Door(print, K, x, y, stock)
    local Plate = ns.UI.JourneyPlate
    local d, B, H = Plate.MARK.door, Plate.DOOR.body, Plate.DOOR.head
    K.Dot(print.pools.halo, x, y, KILL.halo, stock, KILL.haloAlpha)
    local body = print.pools.ink:Next()
    K.Fill(body, Style.INK_STRONG, 1)
    K.Place(body, x - d * B.w / 2, y + d * B.y - d * B.h / 2, d * B.w, d * B.h)
    K.Dot(print.pools.ink, x, y + d * H.y, d * H.size, Style.INK_STRONG, 1)
end

-- A death's cross at x, y (DEATH): in ink, or in pencil where it is only
-- about there. Its tooltip says who died, to what, and where about.
local function Cross(print, K, x, y, pencil, stock, tip)
    local pools, D = print.pools, DEATH
    local c, a = pencil and Style.GRAPHITE or Style.INK_STRONG, pencil and D.pencil or 1
    K.Dot(pools.crossHalo, x, y, D.halo, stock, D.haloAlpha)
    local stem = pools.cross:Next()
    K.Fill(stem, c, a)
    K.Place(stem, x - D.stem[1] / 2, y + 0.5 - D.stem[2] / 2, D.stem[1], D.stem[2])
    local bar = pools.cross:Next()
    K.Fill(bar, c, a)
    K.Place(bar, x - D.bar[1] / 2, y - D.up - D.bar[2] / 2, D.bar[1], D.bar[2])
    Hit(print, x, y, tip, D.hit)
    print.crosses[#print.crosses + 1] = { x = x, y = y, pencil = pencil or nil, tip = tip }
end

-- Where a death on the way lies (MAP-9): `frac` of the way along the
-- route from `after`'s stop (the way in without one) to `before`'s; just
-- past `after` with no `before`. nil where the way through does not say
-- (no route, a stop off this floor).
local function LegPoint(path, leg)
    if not path then return nil end
    local Norm = ns.Dungeons.Norm
    local i0 = leg.after and path.stops[Norm(leg.after.name)] or (not leg.after and 1) or nil
    local i1 = leg.before and path.stops[Norm(leg.before.name)]
    if not i0 then return nil end
    local pts = {}
    if i1 then
        local step = i1 >= i0 and 1 or -1
        for k = i0, i1, step do
            if path.pts[k] then pts[#pts + 1] = path.pts[k] end
        end
    else
        -- Just past it: a little way along the next leg.
        for k = i0, math.min(#path.pts, i0 + 3) do
            if path.pts[k] then pts[#pts + 1] = path.pts[k] end
        end
    end
    if #pts < 2 then return nil end
    local total, lengths = 0, {}
    for k = 2, #pts do
        lengths[k] = math.sqrt((pts[k][1] - pts[k - 1][1]) ^ 2 + (pts[k][2] - pts[k - 1][2]) ^ 2)
        total = total + lengths[k]
    end
    local want = i1 and total * math.max(0.05, math.min(0.95, leg.frac or 0.5)) or math.min(total, 16)
    for k = 2, #pts do
        if want <= lengths[k] or k == #pts then
            local t = lengths[k] > 0 and math.min(1, want / lengths[k]) or 0
            return pts[k - 1][1] + (pts[k][1] - pts[k - 1][1]) * t, pts[k - 1][2] + (pts[k][2] - pts[k - 1][2]) * t
        end
        want = want - lengths[k]
    end
end

-- The run's deaths (MAP-14), from its notes (ns.DungeonRun.Notes): in ink
-- round the boss they died at; in pencil on the way, by the boss before or
-- after where the way through does not say; at the print's foot where
-- nothing does. `targets` are the marks by boss name.
local function Deaths(print, K, visit, notes, path, targets, At, foot, stock, names)
    local W = DungeonPage.Words
    local D = DEATH
    local loose = {}
    local function Near(boss)
        local t = boss and targets[boss.name]
        if t then return t end
        if not (boss and boss.floor and boss.x) then return nil end
        local x, y = At(boss.floor, boss.x, boss.y)
        if x then return { x = x, y = y, r = 4 } end
    end
    for _, e in ipairs(notes.bosses or {}) do
        local t = #e.deaths > 0 and Near(e.boss)
        if t then
            -- Round its lower left, alternating out from `start`.
            for k, death in ipairs(e.deaths) do
                if k > D.most then break end
                local turn = math.floor(k / 2) * (k % 2 == 0 and 1 or -1)
                local a = math.rad(D.start + turn * D.step)
                local r = t.r + D.ring
                Cross(print, K, t.x + math.cos(a) * r, t.y + math.sin(a) * r, false, stock,
                    Style.TipList(W.Death(visit, death)))
            end
        else
            for _, death in ipairs(e.deaths) do loose[#loose + 1] = death end
        end
    end
    for k, leg in ipairs(notes.legs or {}) do
        local tip = Style.TipList(W.Death(visit, leg.death), { W.Leg(leg, names) })
        local x, y = LegPoint(path, leg)
        if not x then
            local t = Near(leg.after) or Near(leg.before)
            if t then x, y = t.x - (t.r + D.ring) * 0.9, t.y + (t.r + D.ring) * 0.9 + k * 2 end
        end
        if x then Cross(print, K, x, y, true, stock, tip) else loose[#loose + 1] = leg.death end
    end
    for _, death in ipairs(notes.unplaced and notes.unplaced.deaths or {}) do loose[#loose + 1] = death end
    -- Nowhere to put them: a tally along the print's foot.
    for k, death in ipairs(loose) do
        Cross(print, K, foot.x + (k - 1) * D.gap, foot.y, true, stock, Style.TipList(W.Death(visit, death)))
    end
end

-- Draws the print: `spec` = { visit, floor, wing, x, y, w, h, route,
-- notes }: the floor of the visit, fitted inside the box w by h at x, y
-- on the parent (y down) and centred across it; the way through when
-- `route`. Returns the card's width and height.
-- `notes` are the run's (ns.DungeonRun.Notes): its deaths are crossed,
-- and what happened at each boss is told in its tooltip.
-- Kept for the tests and the margin notes (UI/Dungeon/Notes.lua):
-- print.marks (each with its `face`: how its portrait came, or nil),
-- print.targets (each mark by boss name: { x, y, r } on the print),
-- print.origin and print.size (its top left on its parent, and its size),
-- print.crosses,
-- print.routeCounts, print.door.
function DungeonPage.Lay(print, spec)
    local visit, floor = spec.visit, spec.floor
    local pools = print.pools
    for _, pool in pairs(pools) do pool:Begin() end
    local flat = ns.Setting("flatSheets") == true
    local canBend = CanBend(print)
    local K = Kit(print, canBend)
    local P = ns.UI.JourneyPlate.PLATE
    local stock = P.stock

    local m = CARD.margin
    local foot = m
    local aw, ah = ns.UI.DungeonMap.Fit(floor, spec.w - 2 * m, spec.h - m - foot)
    local W, H = aw + 2 * m, ah + m + foot
    print:ClearAllPoints()
    print:SetPoint("TOPLEFT", spec.x + (spec.w - W) / 2, -spec.y)
    print:SetSize(W, H)
    print.origin, print.size = { spec.x + (spec.w - W) / 2, spec.y }, { W, H }
    local seed = (visit.id or 1) * 7.31 + (floor.uiMapID or 0) * 0.013

    Card(print, K, W, H, flat)
    print.canvas:ClearAllPoints()
    print.canvas:SetPoint("TOPLEFT", print, "TOPLEFT", m, -m)
    print.canvas:Draw(floor, aw, ah, { tint = P.tint, desaturate = P.desaturate, plain = P.plain })
    if not flat then Vignette(print, K, m, m, aw, ah, seed) end
    NeatLine(print, K, m, m, m + aw, m + ah)

    local function At(f, x, y)
        local px, py = print.canvas:Place(f, x, y)
        if px then return m + px, m + py end
    end

    local notes = spec.notes or { bosses = {}, legs = {}, wipes = {} }
    local names = DungeonPage.Names(notes)
    local path = Path(visit, spec.wing, At, spec.notes)
    print.routeCounts = spec.route and DrawRoute(print, K, path, canBend) or { ink = 0, pencil = 0 }

    -- The way in, then the bosses over it.
    print.door = nil
    local door = ns.Dungeons.Entrance(visit.instanceID, floor.uiMapID)
    local dx, dy
    if door then dx, dy = At(floor.uiMapID, door.x, door.y) end
    if dx then
        Door(print, K, dx, dy, stock)
        -- And the runs back in, which a strip may have had no room for.
        local ranBack = spec.notes and spec.notes.ranBack or 0
        local W = DungeonPage.Words
        Hit(print, dx, dy, Style.TipList("The way in",
            ranBack > 0 and { W.RanBack(ranBack) .. " " .. W.GHOST } or nil))
        print.door = { x = dx, y = dy }
    end
    -- The kills first, in the order they fell, then the rest: each kept
    -- clear of those before it, tethered back where it moved.
    local list = DungeonPage.Marks(visit, spec.wing, notes)
    table.sort(list, function(a, b)
        if a.killed ~= b.killed then return a.killed end
        if a.killed then return a.fell < b.fell end
        return (a.boss.order or 0) < (b.boss.order or 0)
    end)
    local box = { m + 6, m + 6, m + aw - 6, m + ah - 6 }
    local placed = print.door and { { x = print.door.x, y = print.door.y } } or {}
    print.marks = {}
    for _, mark in ipairs(list) do
        local b = mark.boss
        local x, y = At(b.floor, b.x, b.y)
        if x then
            local px, py = Apart(x, y, placed, box)
            placed[#placed + 1] = { x = px, y = py }
            print.marks[#print.marks + 1] = { name = b.name, boss = b, killed = mark.killed, rare = mark.rare,
                inferred = mark.inferred, order = mark.order, x = px, y = py, at = { x, y } }
        end
    end
    -- What happened at each boss, for its tooltip.
    local facts = {}
    for _, e in ipairs(notes.bosses or {}) do facts[e.boss.name] = DungeonPage.Words.Facts(visit, e) end
    local numbers = {}
    print.targets, print.crosses = {}, {}
    for i, mark in ipairs(print.marks) do
        if mark.x ~= mark.at[1] or mark.y ~= mark.at[2] then
            K.Stroke(print.pools.tether, mark.at[1], mark.at[2], mark.x, mark.y, APART.tether[1], Style.GRAPHITE,
                APART.tether[2])
        end
        local lines
        if mark.killed then
            mark.face = Face(print, pools.medal, mark.x, mark.y, mark.rare and "rare" or "killed", mark.boss)
            if not mark.face then Killed(print, K, mark.x, mark.y, stock) end
            -- Numbered in the order they fell; a kill only its loot told
            -- of goes unnumbered, as when it fell is a guess.
            if mark.order then
                local nx, ny = NumberAt(mark.x, mark.y, placed, numbers, box)
                numbers[#numbers + 1] = { x = nx, y = ny }
                Number(print, K, mark.order, nx, ny, stock)
            end
            local killed = mark.inferred and "Killed on this run, going by its loot" or "Killed on this run"
            lines = mark.rare and { "Rare", killed } or { killed }
            print.targets[mark.name] = { x = mark.x, y = mark.y, r = mark.face and MEDAL.kill / 2 or KILL.edge / 2 + 1 }
        else
            mark.face = Face(print, pools.sketch, mark.x, mark.y, "standing", mark.boss)
            if not mark.face then Standing(print, K, mark.x, mark.y, seed + i * 1.7, stock) end
            lines = { "Not killed on this run" }
            print.targets[mark.name] = { x = mark.x, y = mark.y,
                r = mark.face and MEDAL.standing / 2 or STANDING.radius + 1 }
        end
        for _, fact in ipairs(facts[mark.name] or {}) do lines[#lines + 1] = fact end
        Hit(print, mark.x, mark.y, Style.TipList(names[mark.name] or mark.name, lines))
    end
    if print.door then print.targets.door = { x = print.door.x, y = print.door.y, r = 7 } end
    Deaths(print, K, visit, notes, path, print.targets, At, { x = m + 10, y = m + ah + foot / 2 }, stock, names)
    -- Where each wipe on the way lies (MAP-17), for its strip's arrow: the
    -- leg point of its first death, else by the boss before or after it.
    for i, w in ipairs(notes.wipes or {}) do
        local x, y = LegPoint(path, w)
        if not x then
            local t = (w.after and print.targets[w.after.name]) or (w.before and print.targets[w.before.name])
            if t then x, y = t.x - (t.r + DEATH.ring) * 0.9, t.y + (t.r + DEATH.ring) * 0.9 end
        end
        if x then print.targets["wipe:" .. i] = { x = x, y = y, r = DEATH.halo / 2 } end
    end

    for i, which in ipairs({ "tl", "tr", "br", "bl" }) do Corner(print, K, which, W, H, flat, seed + i, canBend) end

    for _, pool in pairs(pools) do pool:Finish() end
    print:Show()
    return W, H
end
