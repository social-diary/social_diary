-- The run's map on the table spread (.claude/dungeon-visits-prd.md §8,
-- MAP-1 to MAP-4, MAP-7): a big sheet of paper lying over the open book
-- (UI/Dungeon/Spread.lua), a loose sheet (UI/Paper/Sheet.lua) like the
-- heat map, with the floor the run mostly took place on printed on it
-- (UI/Map/Dungeon.lua) and over the floor what happened there
-- (UI/Dungeon/Print.lua).
--
-- The map is printed whole and edge to edge on it, and the sheet is the
-- map's own shape (the user, 16 Oct: "the dungeon map defines our aspect
-- ratio"): the floor's whole image (UI/Map/Dungeon.lua's Kept: nothing is
-- trimmed) is the whole sheet, as big as SIZE allows: about one and a half
-- times the book's width for a wide map, and taller for a tall one.
-- A thin band of ink at the paper's edge (FRAME). It lies turned a few
-- degrees the other way round to the clock (SHEET), on the book; which of
-- the book's corners show beside it depends on the map's shape (and on
-- where the spread had to slide it to stay on the screen:
-- UI/Dungeon/Spread.lua).
-- It has been carried folded, in panels about the shape of the first
-- map's (GRIDS: three across and two down for a wide map, two by two for
-- a squarer one, two across and three down for a tall one), each panel
-- much bigger than the heat map's, so the folds stand higher (CREASE);
-- each fold is moved off its line, as far as it can go (FOLDS), so it
-- never runs through a boss's face, a number or the way in (K.Clear). Everything on it is placed, cut and lit through
-- the sheet's toolkit, so it turns, folds and takes the light with the
-- paper: the art cut along the mesh by its texture coordinates, the marks
-- through the placer below. Laid flat ("Flat paper only"), it is plain
-- paper, turned all the same.
--
-- A combined map's pieces are feathered by masks; where the client cannot
-- turn a mask, that map's sheet lies straight, so mask and art agree.
--
-- The other floors to choose from, as links on a paper label pasted in
-- the map's bottom-right corner (LABEL), the one shown read as plain
-- text. The run's notes lie on it as paper strips near what they are
-- about, with pencil leaders (UI/Dungeon/Notes.lua's LayNotes). A dungeon
-- the diary has no map of gets a line in pencil on the bare sheet instead
-- (MAP-7). The ticket, the cartouche and the tallies (step 3) are still
-- to come.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local DungeonPage = ns.UI.DungeonPage

-- The sheet: turned `turn` degrees the other way round to the clock about
-- its middle, which lies `down` px under the book's (where the book lay:
-- it is put aside while the run is out, UI/Dungeon/Spread.lua). Bare (no
-- map), `w` by `h`.
local SHEET = { w = 1212, h = 696, turn = 3.5, down = 6 }
-- Its size, the map's shape kept: at most `w` px wide and `h` px tall, a
-- tall map (narrower than square) taller by its narrowness to the power
-- `tall`, as it stood before. A fifth bigger each way than the size the
-- user kept on 16 Oct (1010 wide, about 571 tall: the book lay under it
-- then), as the book is put aside now (the user, 17 Oct). The screen is
-- not asked: where the sheet will not fit, the spread slides and, only as
-- a last resort, shrinks (UI/Dungeon/Spread.lua's DungeonPage.Lie).
local SIZE = { w = 1212, h = 686, tall = 0.4 }
-- The folds, by how many panels across and down; the one whose panels
-- come nearest to `panel` (width over height: the first map's, 337 by
-- 290) is taken. Each grid's lines: its folds at the panels' edges, a
-- ridge and a valley by turns, and a wrinkle near the middle of each
-- panel (`wrinkle`, as a share of the panel, a little off).
local GRIDS = { panel = 337 / 290, sizes = { { 3, 2 }, { 2, 2 }, { 2, 3 } }, wrinkle = { 0.51, 0.47, 0.53 } }
-- The printed art: greyed part way and warmed toward the paper, as the
-- plates' (UI/Journey/Plate.lua's PLATE: `plain` where nothing greys).
local PRINT = { tint = { 0.98, 0.92, 0.80 }, desaturate = 0.35, plain = { 0.94, 0.86, 0.71 } }
-- The band of ink round the printed map, at the paper's edge: `width` px
-- in, at `alpha` (the heat map's FRAME), so the paper shows through it.
local FRAME = { width = 2.5, alpha = 0.55 }
-- The folds (the loose sheet's CREASE, its lines and folds kept): the
-- panels are about 337 by 290, so a fold stands `ridge` px, the paper
-- crumples and drifts a little more, and a fold misses its line by up to
-- `shift`.
local CREASE = { ridge = 10, crumple = 3.2, drift = 1.5, shift = 8 }
-- Its age (flavour pass A): a run long ago lies on older paper, its
-- stock yellowed toward `paper` and the grime along its folds up to
-- `grime` times the usual, by how long ago the run began: fresh after a
-- night, clearly worn after a few months (`full` days), no older past
-- that, the wear coming on fast and then slower (`curve`, a power). Only
-- the paper and its folds age: the print, the ink and the strips keep
-- their contrast.
local AGE = { full = 120, curve = 0.6, paper = { 0.80, 0.68, 0.46 }, yellow = 0.45, grime = 2.6 }
-- Each fold keeps `pad` px clear of a face, a number and the way in,
-- moved at most `reach` px off its line to do it (a seventh of a panel:
-- a run's bosses can stand close together across a fold, Wailing
-- Caverns' four by the first).
local FOLDS = { reach = 48, pad = 4 }
-- The floors' label: a slip of the sheet's own stock pasted `inset` px in
-- from the bottom-right corner, `h` px tall, `pad` px of it either side of
-- the links, which lie `gap` px apart; edged in ink at `edge`. A run's
-- deaths that lie nowhere are tallied at the bottom-left, `foot` px in;
-- every mark is kept `inside` px within the paper.
local LABEL = { inset = 16, h = 24, pad = 10, gap = 16, edge = 0.45, foot = 26, inside = 20 }
-- The frames on the paper, over it in this order: the faces, the
-- numbers, the squares that take the mouse, the strips lying on it
-- (UI/Dungeon/Notes.lua).
local LEVELS = { medals = 1, labels = 3, hits = 5, notes = 7 }

DungeonPage.SHEET, DungeonPage.FOLDS, DungeonPage.LABEL, DungeonPage.SIZE = SHEET, FOLDS, LABEL, SIZE
DungeonPage.AGE = AGE

-- How worn a run's map is, from 0 (last night) to 1 (AGE.full days ago or
-- more), `seconds` after it began.
function DungeonPage.Age(seconds)
    local days = math.max(0, (seconds or 0) / 86400)
    return math.min(1, days / AGE.full) ^ AGE.curve
end

-- The paper and the grime for that wear: the stock yellowed, the grime
-- times the usual.
function DungeonPage.Worn(age)
    local P, A = Style.PAPER, AGE.paper
    local k = AGE.yellow * age
    return { P[1] + (A[1] - P[1]) * k, P[2] + (A[2] - P[2]) * k, P[3] + (A[3] - P[3]) * k },
        1 + (AGE.grime - 1) * age
end

-- The sheet's size for art of shape `aspect` (width over height), as big
-- as SIZE lets that shape be: w, h.
function DungeonPage.SheetSize(aspect)
    local h = math.min(SIZE.w / aspect, SIZE.h / math.min(1, aspect) ^ SIZE.tall)
    return aspect * h, h
end

-- The fold grid for a sheet w by h (GRIDS): { across, down } and its
-- CREASE (the folds' lines, as UI/Paper/Sheet.lua takes them).
function DungeonPage.Grid(w, h)
    local best, nearest
    for _, g in ipairs(GRIDS.sizes) do
        local off = math.abs(math.log((w / g[1]) / (h / g[2]) / GRIDS.panel))
        if not nearest or off < nearest then best, nearest = g, off end
    end
    local function Lines(n, firstSign)
        local lines, folds, sign = { 0 }, {}, firstSign
        for k = 1, n do
            local wrinkle = GRIDS.wrinkle[(k - 1) % #GRIDS.wrinkle + 1]
            lines[#lines + 1] = (k - 1 + wrinkle) / n
            lines[#lines + 1] = k / n
            if k < n then
                folds[#lines] = sign
                sign = -sign
            end
        end
        return lines, folds
    end
    local columns, foldsX = Lines(best[1], 1)
    local rows, foldsY = Lines(best[2], -1)
    local crease = { columns = columns, rows = rows, folds = { columns = foldsX, rows = foldsY } }
    for k, v in pairs(CREASE) do crease[k] = v end
    return best, crease
end

-- The sheet's placer (UI/Dungeon/Print.lua's P) over its toolkit K: every
-- mark placed in the sheet's coordinates, turned and moved with the mesh,
-- and lit by the facet it lies on.
local function Placer(view, K)
    local S = view.sheet
    local P = {}

    local function Frame(level)
        local f = CreateFrame("Frame", nil, S)
        f:SetAllPoints()
        f:SetFrameLevel(S:GetFrameLevel() + level)
        return f
    end
    local medals, labels, hits = Frame(LEVELS.medals), Frame(LEVELS.labels), Frame(LEVELS.hits)

    local function Inks(layer, sublevel, frame) return K.Pool(layer, sublevel, nil, frame) end
    -- Under the creases (ARTWORK 4) the way, which is printed on the paper;
    -- over them the marks, which the folds keep clear of.
    P.pools = {
        routeUnder = Inks("ARTWORK", 0),
        route = Inks("ARTWORK", 1),
        tether = Inks("ARTWORK", 2),
        halo = Inks("OVERLAY", 0),
        crossHalo = Inks("OVERLAY", 1),
        ink = Inks("OVERLAY", 2),
        fill = Inks("OVERLAY", 3),
        cross = Inks("OVERLAY", 4),
        medal = ns.UI.Pool.New(function() return Style.BossMedallion(medals, DungeonPage.MEDAL.kill) end),
        sketch = ns.UI.Pool.New(function() return Style.BossMedallion(medals, DungeonPage.MEDAL.standing) end),
        numberHalo = Inks("ARTWORK", 0, labels),
        number = ns.UI.Pool.New(function()
            local text = labels:CreateFontString(nil, "OVERLAY")
            text:SetFont(Style.FRIZ, DungeonPage.KILL.number.size, "")
            local I = Style.INK_STRONG
            text:SetTextColor(I[1], I[2], I[3], 1)
            text:SetShadowOffset(0, 0)
            return text
        end),
        -- The moments in the hand (Print.lua's Flavour): the blood under
        -- the crosses' paper, the drops' loops and the stars in ink with
        -- the marks, the scribbles in chalk over their dark strokes, the
        -- level scrawled in the hand.
        blood = Inks("ARTWORK", 2),
        bloodCore = Inks("ARTWORK", 3),
        loot = Inks("OVERLAY", 2),
        scribbleUnder = Inks("OVERLAY", 3),
        scribble = Inks("OVERLAY", 4),
        scrawl = ns.UI.Pool.New(function()
            local text = labels:CreateFontString(nil, "OVERLAY")
            text:SetFont(Style.NEUTON_ITALIC, DungeonPage.LEVEL.text.size, "")
            local C = DungeonPage.CHALK.colour
            text:SetTextColor(C[1], C[2], C[3], 1)
            text:SetShadowColor(Style.INK[1], Style.INK[2], Style.INK[3], 0.8)
            text:SetShadowOffset(1, -1)
            return text
        end),
        hit = ns.UI.Pool.New(function()
            local hit = CreateFrame("Frame", nil, hits)
            hit:EnableMouse(true)
            Style.Tooltip(hit, function(self) return self.tip end, "ANCHOR_RIGHT")
            return hit
        end),
    }

    -- Ink of colour c at alpha a, lit where it lies (x, y).
    local function Fill(texture, c, a, x, y)
        local light = K.Light(x, y)
        texture:SetTexture(nil)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetColorTexture(c[1] * light, c[2] * light, c[3] * light, a)
    end

    function P.Rect(pool, x, y, w, h, c, a, turn)
        local texture = pool:Next()
        Fill(texture, c, a, x + w / 2, y + h / 2)
        K.Place(texture, x, y, w, h, turn)
        return texture
    end

    function P.Dot(pool, x, y, size, c, a)
        local texture = pool:Next()
        local light = K.Light(x, y)
        texture:SetVertexColor(1, 1, 1, 1)
        Style.Disc(texture, c[1] * light, c[2] * light, c[3] * light, a)
        K.Place(texture, x - size / 2, y - size / 2, size, size)
        return texture
    end

    function P.Lozenge(pool, x, y, size, c, a)
        return P.Rect(pool, x - size / 2, y - size / 2, size, size, c, a, math.pi / 4)
    end

    -- A texture turned to the stroke (on the screen y runs up). None where
    -- textures cannot turn.
    function P.Stroke(pool, x1, y1, x2, y2, width, c, a)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.01 then return nil end
        local texture = pool:Next()
        if not texture.SetRotation then
            texture:Hide()
            pool.used = pool.used - 1
            return nil
        end
        local L = length + 0.5
        Fill(texture, c, a, (x1 + x2) / 2, (y1 + y2) / 2)
        K.Place(texture, (x1 + x2) / 2 - L / 2, (y1 + y2) / 2 - width / 2, L, width, math.atan2(-dy, dx))
        return texture
    end

    function P.Quad(pool, c, a, x1, y1, x2, y2, x3, y3, x4, y4)
        local texture = pool:Next()
        Fill(texture, c, a, (x1 + x2 + x3 + x4) / 4, (y1 + y2 + y3 + y4) / 4)
        if K.Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4) then return texture end
        texture:Hide()
        pool.used = pool.used - 1
        return nil
    end

    -- A medallion is a frame: it cannot turn, its middle goes where the
    -- point lands (a round face turned a few degrees looks the same).
    function P.Face(pool, x, y, look, boss)
        local medal = pool:Next()
        local how = medal:SetBoss(look, boss.display, boss.portrait)
        if not how then
            medal:Hide()
            pool.used = pool.used - 1
            return nil
        end
        medal:ClearAllPoints()
        medal:SetPoint("CENTER", S, "CENTER", K.Screen(x, y))
        return how
    end

    function P.Text(pool, text, x, y)
        local label = pool:Next()
        label:SetText(text)
        K.PlaceText(label, x, y, "CENTER")
        return label
    end

    function P.Hit(pool, x, y, size, tip)
        local hit = pool:Next()
        K.PlaceButton(hit, x - size / 2, y - size / 2, size, size)
        hit.tip = tip
        return hit
    end

    return P
end

-- The map sheet on `parent` (the spread's host, which it covers: a click
-- on it beside the sheet calls view.onPutAway). view:Open(visit, guid)
-- lays it for a run. Kept for the tests: view.plan (UI/Dungeon/Print.lua's,
-- inked), view.printer (the art's, UI/Map/Dungeon.lua), view.floors,
-- view.floorIndex, view.box (the whole floor on the sheet), view.links
-- (the floors') and view.labelBox, view.none (the pencil line), view.straight (laid straight, as
-- its masks cannot turn), and the toolkit, view.K.
function DungeonPage.Sheet(parent)
    -- Its size now: the shown map's (Shape).
    local W, H = SHEET.w, SHEET.h
    -- It lies over the game world (the book is put aside): its shadow the
    -- world's, darker and wider than on a page (UI/Paper/Light.lua's
    -- GROUND), cast by the same light from the same heights.
    local view, K = ns.UI.LooseSheet(parent, W, H, { crease = select(2, DungeonPage.Grid(W, H)),
        ground = ns.UI.Light.GROUND.world })
    local S = view.sheet
    view.K = K
    -- Two levels left between the sheet and what it lies on: the ground
    -- (`view.ground`), where what lies over the sheet's edge casts its
    -- shadow on the world, under the sheet, so the sheet covers the part
    -- of it that falls on the paper (UI/Dungeon/Heights.lua); and over it
    -- what lies beside the sheet and under its edge (the way back's
    -- bookmark, UI/Dungeon/Spread.lua). Raised before anything is made on
    -- it.
    view.ground = CreateFrame("Frame", nil, view)
    view.ground:SetAllPoints(view)
    view.ground:SetFrameLevel(view:GetFrameLevel() + 1)
    S:SetFrameLevel(view:GetFrameLevel() + 3)
    view.chosen = {}

    -- Under the art, and all there is where the art is missing; the art
    -- (BORDER 2, its feathered pieces 3), under the grime along the folds;
    -- the band of ink round it and the floors' label over it.
    local groundPool = K.Pool("BORDER", 1)
    local framePool = K.Pool("ARTWORK", 3)
    local labelPool = K.Pool("ARTWORK", 3)
    view.printer = ns.UI.DungeonMap.Printer(K, S, "BORDER", 2)
    local P = Placer(view, K)
    view.pools = P.pools
    view.label = labelPool

    view.none = Style.Text(S, FONT.pencil)
    view.none:SetJustifyH("CENTER")

    -- The run's notes (UI/Dungeon/Notes.lua): strips on a frame whose top
    -- left is the sheet's middle, over everything on it; their leaders in
    -- chalk on the paper, over the marks' halos, a faint dark stroke under
    -- them; the count of the rest.
    local host = CreateFrame("Frame", nil, S)
    host:SetFrameLevel(S:GetFrameLevel() + LEVELS.notes)
    host:SetPoint("TOPLEFT", S, "CENTER")
    host:SetSize(1, 1)
    host.nameMeasure = Style.Text(host, FONT.noteWritten)
    host.nameMeasure:Hide()
    view.notesHost = host
    view.notes = ns.UI.Pool.New(function() return DungeonPage.NewNote(host) end)
    view.leaderUnder = K.Pool("OVERLAY", 5)
    view.leaders = K.Pool("OVERLAY", 6)
    -- The count in chalk (Print.lua's CHALK), a hair of dark under it.
    view.more = Style.Text(S, FONT.pencilSmall)
    local C = DungeonPage.CHALK.colour
    view.more:SetTextColor(C[1], C[2], C[3])
    view.more:SetShadowColor(Style.INK[1], Style.INK[2], Style.INK[3], 0.7)
    view.more:SetShadowOffset(1, -1)
    view.more:Hide()
    view.noteStrips, view.notesMore, view.notesAbout = {}, 0, 0
    view.links = ns.UI.Pool.New(function()
        return K.Link(FONT.body, function(self)
            if self.current then return end
            view.chosen[view.visit.id] = self.index
            view:Open(view.visit, view.guid)
        end)
    end)

    -- Colour over the rectangle x0, y0 to x1, y1 from `pool`, cut along
    -- the mesh and lit with it (the heat map's frame, UI/Map/HeatSheet.lua);
    -- `seal`ed where it must meet itself without a seam (the ground).
    local function Lay(pool, c, a, x0, y0, x1, y1, seal)
        K.Split(x0, y0, x1, y1, function(l, t, r, b, light)
            local texture = pool:Next()
            texture:SetColorTexture(c[1] * light, c[2] * light, c[3] * light, a)
            K.Bend(texture, l, t, r, b, seal)
        end)
    end

    -- A band `d` px wide just inside the rectangle, all round.
    local function Band(pool, c, a, x0, y0, x1, y1, d)
        Lay(pool, c, a, x0, y0, x1, y0 + d)
        Lay(pool, c, a, x0, y1 - d, x1, y1)
        Lay(pool, c, a, x0, y0 + d, x0 + d, y1 - d)
        Lay(pool, c, a, x1 - d, y0 + d, x1, y1 - d)
    end

    -- What the map marks, in the floor's units, which the art's border is
    -- never cut through (UI/Map/Dungeon.lua's Kept): the bosses it shows,
    -- the way in, the way through where it is drawn, and the deaths placed
    -- by a boss or on the way (round its bosses and the way, so within
    -- their margins).
    local function Marked(visit, floor, wing, notes, drawRoute)
        local D, points = ns.Dungeons, {}
        local function Add(f, x, y, kind)
            local fx, fy = D.Point(floor, tonumber(f), x, y)
            if fx then points[#points + 1] = { x = fx * floor.w, y = fy * floor.h, kind = kind } end
        end
        for _, mark in ipairs(DungeonPage.Marks(visit, wing, notes)) do
            Add(mark.boss.floor, mark.boss.x, mark.boss.y)
        end
        local door = D.Entrance(visit.instanceID, floor.uiMapID)
        if door then Add(floor.uiMapID, door.x, door.y, "door") end
        for _, pt in ipairs(drawRoute and D.Route(visit.instanceID, wing) or {}) do
            local b = pt.boss and D.Boss(visit.instanceID, pt.boss)
            if b and b.floor and b.x then Add(b.floor, b.x, b.y, "way") else Add(pt.f, pt.x, pt.y, "way") end
        end
        return points
    end

    -- The other floors, on a label in the bottom-right corner: a slip of
    -- the sheet's stock edged in ink, the links on it from its left.
    local function Links(floors, shown)
        view.links:Begin()
        labelPool:Begin()
        if #floors > 1 then
            local widths, total = {}, 0
            for i, floor in ipairs(floors) do
                local link = view.links:Next()
                link.index = i
                link:SetText(floor.name or ("Floor %d"):format(i))
                link:SetCurrent(i == shown)
                widths[i] = K.Width(link.label)
                total = total + widths[i] + (i > 1 and LABEL.gap or 0)
            end
            local x1, y1 = W - LABEL.inset, H - LABEL.inset
            local x0, y0 = x1 - total - 2 * LABEL.pad, y1 - LABEL.h
            Lay(labelPool, view.paper, 1, x0, y0, x1, y1, true)
            Band(labelPool, Style.INK, LABEL.edge, x0, y0, x1, y1, 1)
            view.labelBox = { x0, y0, x1, y1 }
            local x = x0 + LABEL.pad
            for i = 1, #floors do
                view.links[i]:PlaceAt(x, (y0 + y1) / 2)
                x = x + widths[i] + LABEL.gap
            end
        else
            view.labelBox = nil
        end
        labelPool:Finish()
        view.links:Finish()
    end

    -- The sheet made w by h and folded to suit (DungeonPage.Grid); the
    -- spread told, so it can say where it lies (view.onMeasure, which sets
    -- view.lie: UI/Dungeon/Spread.lua).
    local function Shape(w, h)
        W, H = w, h
        local grid, crease = DungeonPage.Grid(w, h)
        K.Reshape(w, h, crease)
        view.w, view.h, view.grid = w, h, grid
        if view.onMeasure then view.onMeasure(w, h) end
    end

    -- Where the sheet comes down: on the book, or as the spread slid it
    -- (UI/Dungeon/Spread.lua's Fit, view.lie).
    local function Fall(visit, turn)
        -- Worn by its age.
        view.age = DungeonPage.Age(ns.Now() - (visit.startedAt or ns.Now()))
        K.Wear(DungeonPage.Worn(view.age))
        local lie = view.lie or { 0, -SHEET.down }
        K.Fall(tostring(visit.id or 0), turn, { lie[1], lie[2] })
    end

    -- Laid for a dungeon the diary has no map of: the bare sheet, one line
    -- in pencil on it (no empty frame: DGN-11).
    local function Bare(visit)
        Shape(SHEET.w, SHEET.h)
        Fall(visit, math.rad(SHEET.turn))
        K.Lay()
        for _, pool in ipairs({ groundPool, framePool }) do
            pool:Begin()
            pool:Finish()
        end
        view.printer:Print(nil, 0, 0, 0, 0)
        for _, pool in pairs(P.pools) do
            pool:Begin()
            pool:Finish()
        end
        Links({})
        DungeonPage.ClearNotes(view)
        view.plan, view.box, view.kept, view.scale = nil, nil, nil, nil
        view.none:SetText(("The diary has no map of %s yet."):format(visit.name or "this place"))
        K.PlaceText(view.none, W / 2, H / 2, "CENTER")
        view.none:Show()
        -- The party's cards in their stack all the same.
        view.stack = DungeonPage.StackPlace(view)
        if view.onLaid then view.onLaid() end
    end

    -- Lays the sheet for `visit`, opened from `guid`'s page: the floor
    -- chosen for it, else the one the run mostly took place on. Kept for
    -- the tests: view.w, view.h (its size), view.grid (its folds, {
    -- across, down }), view.kept (the part of the floor printed, in its
    -- units), view.scale (px of the sheet per unit).
    function view:Open(visit, guid)
        self.visit, self.guid = visit, guid
        local D, Map = ns.Dungeons, ns.UI.DungeonMap
        local wing = DungeonPage.Wing(visit)
        local floors = D.Floors(visit.instanceID, wing)
        self.floors = floors
        if not floors or #floors == 0 then
            self.floorIndex, self.straight = nil, false
            Bare(visit)
            return
        end
        self.none:Hide()
        self.none:SetText("")

        local _, main = D.MainFloor(visit, wing)
        local index = self.chosen[visit.id] or main or 1
        if not floors[index] then index = 1 end
        local floor = floors[index]
        self.floorIndex = index

        -- The art kept (all of it, as TRIM is none; a border trimmed would
        -- be cut thinner where something marked lies in it), and the sheet
        -- its shape. The margins are the sheet's px,
        -- so the scale is found as the sheet is (twice: the second cut at
        -- the first's scale). The usual way through as the settings say
        -- (Interface, Dungeons and Raids).
        local notes = ns.DungeonRun.Notes(visit)
        -- The rolls (pass B), for the strips.
        notes.rolls = ns.DungeonRun.Rolls(visit)
        local route = D.Route(visit.instanceID, wing)
        local drawRoute = route ~= nil and #route > 1 and ns.Setting("dungeonRoute") == true
        local points = Marked(visit, floor, wing, notes, drawRoute)
        local kept, w, h = Map.Kept(floor), nil, nil
        for _ = 1, 2 do
            w, h = DungeonPage.SheetSize((kept[3] - kept[1]) / (kept[4] - kept[2]))
            kept = Map.Kept(floor, points, w / (kept[3] - kept[1]))
        end
        w, h = DungeonPage.SheetSize((kept[3] - kept[1]) / (kept[4] - kept[2]))
        local s = w / (kept[3] - kept[1])
        self.kept, self.scale = kept, s
        Shape(w, h)
        -- The whole floor on the sheet: with nothing trimmed, the sheet
        -- itself (a trimmed border would lie past the paper's edge).
        local box = { x = -kept[1] * s, y = -kept[2] * s, w = floor.w * s, h = floor.h * s }
        self.box = box

        -- Where everything goes, before the paper is laid, so its folds
        -- keep clear of it.
        local At = Map.At(floor, box.x, box.y, box.w, box.h)
        local inset = LABEL.inside
        local plan = DungeonPage.Plan({ visit = visit, floor = floor, wing = wing, box = box, At = At,
            notes = notes, route = drawRoute, inside = { inset, inset, W - inset, H - inset },
            foot = { x = LABEL.foot, y = H - LABEL.foot } })

        -- A combined map's masks that cannot turn: that sheet lies straight.
        self.straight = floor.combined == true and not self.printer.masksTurn
        Fall(visit, self.straight and 0 or math.rad(SHEET.turn))
        K.Clear(plan.spots, FOLDS.reach, FOLDS.pad)
        K.Lay()

        groundPool:Begin()
        Lay(groundPool, Style.MAP_BACKGROUND, 1, 0, 0, W, H, true)
        groundPool:Finish()
        self.printer:Print(floor, box.x, box.y, box.w, box.h, PRINT, kept)
        framePool:Begin()
        Band(framePool, Style.INK_STRONG, FRAME.alpha, 0, 0, W, H, FRAME.width)
        framePool:Finish()

        self.plan = DungeonPage.Ink(plan, P, self.paper)
        Links(floors, index)
        -- Where the party's cards lie in their stack by it (UI/Dungeon/
        -- Cards.lua), before the strips, which keep out from under it.
        self.stack = DungeonPage.StackPlace(self)
        DungeonPage.LayNotes(self, self.plan, P, K)
        if self.onLaid then self.onLaid() end
    end

    view:Hide()
    return view
end
