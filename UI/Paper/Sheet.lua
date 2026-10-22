-- A loose sheet of paper lying across the open book: the map
-- (UI/Map/HeatSheet.lua) and a note being written (UI/Paper/NoteSheet.lua).
-- This is the paper; what is on it is the caller's, placed, cut and lit
-- through the toolkit this hands back, so it folds with the sheet it is
-- printed on.
--
-- The sheet fell onto the book a little askew: turned a degree or two, off
-- the middle, the same way every time for the same person (Fall). Frames
-- cannot turn in the client, only textures and font strings, so the sheet
-- is laid out flat in its own coordinates (x right, y down from its top
-- left) and every piece is turned about the sheet's middle as it is placed
-- (Place). Where the client cannot turn text, the sheet lies straight.
-- Buttons cannot turn either: a link's text and underline turn, the button
-- that catches the click stays square under them.
--
-- It has been carried folded in the book: in three across and in two down,
-- a ridge and a valley across, a valley down, and crumpled a little on top
-- (CREASE). Like the ribbons, it bends by being cut into pieces: a mesh of
-- facets between the folds and wrinkles, each one lit by how it slopes to
-- the light (top left), and, where the client can move a texture's corners
-- (SetVertexOffset), bent so its corners meet its neighbours' wherever the
-- paper rises, sinks or drifts. Everything on the paper is cut along the
-- same mesh and lit with it, so the map folds with the sheet it is printed
-- on. Where the corners cannot move, the facets still take the light. Laid
-- flat (the flatSheets setting, `flat`), it is plain paper: no bending, no
-- light on the facets, and no creases or grime along the folds.
--
-- A sheet covers what it lies on and takes the clicks there, so nothing
-- under it answers. With `view.onPutAway` set (the map), a click beside it
-- puts it away; without (a note), it stays until its own buttons close it.
--
-- Glued in (`glued`, JRN-21): a plate in the diary (UI/Journey/Plate.lua).
-- It did not fall and will not be put away: it is glued where it is
-- mounted (K.Mount), turned as it was given, and the page round it stays
-- the page, answering its own clicks. It is one facet of flat card, a
-- little lighter and cooler than the page (GLUED), with no folds, grime or
-- rustle, and by default its only shadow a thin line where it meets the
-- page; laid flat, only its faint edge. Its stock and shadows can be the
-- caller's (`paper`, `shadows`): a plate passes its photo stock and casts
-- its own shadow. Its photo corners, glue and a lifted corner are the
-- plate's (JourneyPlate's MOUNT, GLUE, LIFT, SHADOW).

local addonName, ns = ...

local Style = ns.Style

-- What it shares with the paper strip (the turned plane, UI/Paper/Surface.lua:
-- a texture's corners put on points and put back, text measured
-- unbounded) and the pages' pools (UI/Kit/Pool.lua). Its own Screen and
-- Place stay here: the sheet drifts with its mesh, and places from a box's
-- top left.
local Surface = ns.UI.Surface
local Corners, Unbend, Width = Surface.Corners, Surface.Unbend, Surface.Width
local NewPool = ns.UI.Pool.New

-- How it fell: how far it turns, at least and at most, in degrees, and how
-- far its middle lies from the book's, at most.
local FALL = { least = 0.9, most = 2.2, dx = 14, dy = 8 }
-- Its shadow on the book, where the paper cannot bend: two layers, offset
-- down and right, how much larger, and how dark.
local SHADOWS = { { 3, -4, 0, 0.26 }, { 7, -10, 6, 0.10 } }
-- Where it bends, the shadow follows how high the paper stands over the
-- book (its height above its lowest point, h): the house light's fall
-- (UI/Paper/Light.lua's LIFT, which was this sheet's, tuned here), so where
-- the paper lifts the shadow moves out and pales, and where it touches the
-- book it stays close and dark, its soft edge further out and paler.
local Lamp = ns.UI.Light
-- The folds and the crumple. `columns` and `rows` are the mesh's lines, as
-- fractions of the sheet's width and height; `folds` says which of them are
-- folds, 1 a ridge and -1 a valley. Then, in pixels: how high a fold stands
-- (for the light only), how far each crossing of the mesh rises or sinks,
-- how far it drifts on the sheet, how far the outline wanders, and how far
-- in it is pulled where a fold meets it. No fold is made true, and each
-- misses its own way: `shift` how far off its line it lies, `lean` how far
-- one end runs across past the other, `press` how much harder or softer it
-- was pressed than `ridge`, and `taper` how much harder at one end than at
-- the other; `wander` how far off theirs the other lines of the mesh lie,
-- as a fraction of the sheet. `light` is how strongly a slope takes the
-- light, within `lo` and `hi`; then the creases' ink.
local CREASE = {
    columns = { 0, 0.17, 1 / 3, 0.49, 2 / 3, 0.84, 1 },
    rows = { 0, 0.26, 0.5, 0.77, 1 },
    folds = { columns = { [3] = 1, [5] = -1 }, rows = { [3] = -1 } },
    ridge = 7, crumple = 2.4, drift = 1.2, edge = 1.4, nick = 1.8,
    shift = 6, lean = 4, press = 0.4, taper = 0.4, wander = 0.025,
    light = 1.8, lo = 0.86, hi = 1.10,
    valley = 0.26, shade = 0.16, shine = 0.35,
}
-- Grime the folds took from the hands that opened them: a band along each
-- fold, `band` wide either side, darkest on it, at `alpha` give or take
-- `uneven`; where folds cross the bands overlap, so it is dirtier there.
-- `scale` is the grime art's pixels per pixel of sheet.
local GRUNGE = { band = 10, alpha = 0.16, uneven = 0.5, tint = { 0.22, 0.14, 0.06 }, scale = 2 }

-- The paper as it lies loose, and as it is glued in: its stock, the ink of
-- its edge, and its shadows (as SHADOWS: down, right, larger, dark) in
-- `shade`. A glued plate is card a little lighter and cooler than the
-- page; it has one facet (`crease`: no inner lines, no folds, nothing
-- crumpled or drifting) and a contact line for a shadow, in ink.
local LOOSE = { paper = Style.PAPER, edge = 0.55, shadows = SHADOWS, shade = { 0, 0, 0 } }
local GLUED = {
    paper = { 0.89, 0.83, 0.66 }, edge = 0.30, shadows = { { 0.6, -0.8, 0, 0.45 }, { 1, -1.5, 0.5, 0.22 } },
    shade = Style.INK,
    crease = { columns = { 0, 1 }, rows = { 0, 1 }, folds = { columns = {}, rows = {} }, crumple = 0, drift = 0,
        edge = 0, nick = 0, shift = 0, lean = 0, press = 0, taper = 0, wander = 0 },
}

-- How the sheet lies for `guid`: its turn in radians, its middle's offset
-- from the book's, and the seed its crumple grows from. The same every time
-- for the same person.
local function Fall(guid)
    local seed = 0
    for i = 1, #(guid or "") do seed = seed + guid:byte(i) * i end
    local noise = Style.Noise
    local degrees = FALL.least + noise(seed) * (FALL.most - FALL.least)
    if noise(seed + 1) < 0.5 then degrees = -degrees end
    return math.rad(degrees), (noise(seed + 2) - 0.5) * 2 * FALL.dx, (noise(seed + 3) - 0.5) * 2 * FALL.dy, seed
end

-- A W by H sheet on `parent`. `opts` (all optional):
--   crease    its own mesh, folds and crumple, in CREASE's shape: whatever
--             it gives replaces the map's. `curl` = { lift, pull } curls
--             the corners up: each lifted up to `lift` and drawn in up to
--             `pull` pixels, by its own amount
--   straight  never turned: for a sheet with a box to write in, as text
--             being written cannot turn with it
--   level     how far above what it lies on (40, the map's): a sheet laid
--             over another sheet lies higher
--   quiet     never rustles: for a card that comes and goes by itself
--             (the reunion toast), which would otherwise rustle all evening
--   glued     a plate glued into the page (see the top): placed by K.Mount,
--             turned `turn` (radians), never fallen, put away or rustled
--   paper     its own stock ({ r, g, b }) in place of its look's: a plate's
--             photo stock (JourneyPlate's PLATE.stock)
--   shadows   its own unbent shadows, in SHADOWS' shape, in place of its
--             look's; {} for none, where the caller casts its own (a plate's
--             contact shadow, JourneyPlate's SHADOW)
--   ground    what it lies on, as the house light has it (UI/Paper/Light.lua's
--             GROUND): its shadow darker and wider on the game world (the
--             dungeon's map, the book put aside); the book's page by default
--
-- Returns the view, with `sheet` (the frame everything is drawn on),
-- `bends` (whether it bends as it is laid now), `flat` (laid flat by the
-- setting) and `turnsText`, and the toolkit K:
--   K.Fall(key, turn, at)  how it lies (view.angle, its turn) and was
--                 crumpled, the same for the
--                 same key; given a `turn` (radians), it lies turned that
--                 much on its own middle instead of as it fell (the
--                 parcel's note), or `at` = { dx, dy } off it (x right, y up,
--                 as SetPoint: the dungeon's map, UI/Dungeon/Sheet.lua)
--   K.Clear(spots, reach, pad)  its folds moved off their lines, at most
--                 `reach` px, to keep `pad` px clear of each spot ({ x, y,
--                 r } on the flat sheet: a boss's face, a number), and
--                 crumpled again round them; until the next K.Fall
--   K.Lines()     the mesh's lines across and down, and its folds ({
--                 columns, rows }, by line), for the tests
--   K.Wear(paper, grime)  worn with age: its stock and how much grime
--                 lies along its folds
--   K.Reshape(w, h, crease)  a sheet of another size, and folded otherwise
--                 (`crease` as opts.crease, or the one it has): a map
--                 sheet the shape of the map on it (UI/Dungeon/Sheet.lua).
--                 Laid by the next K.Fall and K.Lay
--   K.Lay()       lays it on the book: the paper, its shadow and folds
--   K.Place(region, x, y, w, h, turn, dx, dy), K.PlaceButton(button, x, y,
--   w, h), K.PlaceText(text, x, y, justify), K.Width(text): placing on
--   the sheet, x right and y down from its top left; K.Wrap(text, width,
--   font): words into lines, to place one at a time
--   K.Texture(layer, sublevel, frame), K.Pool(layer, sublevel, setup,
--   frame): textures for it, made on `frame` (a frame laid over the sheet,
--   to clip or scale what it holds) or on the sheet. A region placed is
--   anchored to its `anchorTo` (a frame on the sheet's middle that can be
--   moved, for a picture that pans) or to the sheet; K.Split, K.Bend, K.Light: cutting along the mesh and lighting
--   K.Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4): a texture over any four
--   points of the sheet, in order upper left, upper right, lower right,
--   lower left, its corners where the paper takes them (the ink trail's
--   strokes, UI/Ink/Trail.lua); false where the client cannot move corners,
--   for the caller to place a turned rectangle instead
--   K.Link(font, onClick): a link whose text and underline turn with it
--   K.Screen(x, y): a point of the sheet on the screen, relative to its
--   middle, y up (for what is drawn beside it: a margin note's leader)
--   K.Mount(x, y, w, h, turn): glued, where it is (its top left, right and
--   down from `parent`'s), its size and its turn; laid by the next K.Lay
function ns.UI.LooseSheet(parent, W, H, opts)
    opts = opts or {}
    local LOOK = opts.glued and GLUED or LOOSE
    local CREASE = setmetatable(opts.crease or LOOK.crease or {}, { __index = CREASE })
    local INK, P = Style.INK, opts.paper or LOOK.paper
    -- How worn it is (K.Wear): its grime this many times the usual.
    local worn = 1
    local SHADOW_LIST = opts.shadows or LOOK.shadows

    -- The view covers the book and catches the clicks beside the sheet;
    -- glued, nothing beside it: the page round a plate is still the page.
    local view = CreateFrame("Frame", nil, parent)
    view:SetFrameLevel(parent:GetFrameLevel() + (opts.level or 40))
    view:SetAllPoints(parent)
    -- Glued, no mouse script at all: a frame with one may take the mouse
    -- in the client, and a plate's view covers the whole page (round 5,
    -- 9 Oct: it swallowed the margin notes' hover).
    view:EnableMouse(not opts.glued)
    if not opts.glued then
        view:SetScript("OnMouseDown", function() if view.onPutAway then view.onPutAway() end end)
    end

    -- The square the sheet turns in: its middle is the turning point, and
    -- it takes the clicks on the sheet itself.
    local S = CreateFrame("Frame", nil, view)
    S:SetSize(W, H)
    S:EnableMouse(true)
    view.sheet = S
    -- Its stock, for what is laid over it in its colour.
    view.paper = P

    local probe = S:CreateFontString(nil, "OVERLAY")
    view.turnsText = probe.SetRotation ~= nil
    probe:Hide()

    local angle, cos, sin = 0, 1, 0

    ----------------------------------------------------------------------
    -- The mesh

    -- Its lines on the flat sheet, and at each crossing how high the paper
    -- stands (z) and how far it has drifted (dx, dy, y down). Built for each
    -- person from their seed (Crumple), like how their folds were made:
    -- { sign, lean, pressed at its start, at its end }, by line.
    local NX, NY = #CREASE.columns, #CREASE.rows
    local X, Y, mesh = {}, {}, {}
    local folds = { columns = {}, rows = {} }
    -- How far each fold was moved off its line to keep clear of what must
    -- not be folded through (K.Clear), by line; none until asked.
    local nudge = { columns = {}, rows = {} }

    -- The height the folds give the paper on line k of `lines`, `t` (0..1)
    -- along it: 0 at the sheet's edges, a fold's own height on it, in a
    -- straight line between.
    local function FoldHeight(lines, made, k, t)
        local function Known(n)
            if n == 1 or n == #lines then return 0 end
            local fold = made[n]
            return fold and fold.sign * CREASE.ridge * (fold.from + (fold.to - fold.from) * t)
        end
        local here = Known(k)
        if here then return here end
        local a, b = k - 1, k + 1
        while Known(a) == nil do a = a - 1 end
        while Known(b) == nil do b = b + 1 end
        local f = (lines[k] - lines[a]) / (lines[b] - lines[a])
        return Known(a) + (Known(b) - Known(a)) * f
    end

    local function Crumple(seed)
        local noise = Style.Noise
        local function Spread(n, size) return (noise(seed * 0.37 + n) - 0.5) * 2 * size end

        -- The lines: the folds a little off theirs, the rest of the mesh more.
        for i, f in ipairs(CREASE.columns) do
            local off = (i == 1 or i == NX) and 0
                or Spread(100 + i, CREASE.folds.columns[i] and CREASE.shift or CREASE.wander * W)
            X[i] = f * W + off + (nudge.columns[i] or 0)
        end
        for j, f in ipairs(CREASE.rows) do
            local off = (j == 1 or j == NY) and 0
                or Spread(200 + j, CREASE.folds.rows[j] and CREASE.shift or CREASE.wander * H)
            Y[j] = f * H + off + (nudge.rows[j] or 0)
        end
        for kind, base in pairs({ columns = 300, rows = 400 }) do
            folds[kind] = {}
            for k, sign in pairs(CREASE.folds[kind]) do
                local press = 1 + Spread(base + k, CREASE.press)
                local taper = Spread(base + 10 + k, CREASE.taper)
                folds[kind][k] = { sign = sign, lean = Spread(base + 20 + k, CREASE.lean),
                    from = press * (1 + taper), to = press * (1 - taper) }
            end
        end

        for i = 1, NX do
            mesh[i] = mesh[i] or {}
            for j = 1, NY do
                local n = seed * 0.37 + i * 13.1 + j * 7.7
                -- How far along a column, and along a row, this crossing is.
                local t, u = Y[j] / H, X[i] / W
                local z = FoldHeight(X, folds.columns, i, t) + FoldHeight(Y, folds.rows, j, u)
                local v = { z = z + (noise(n) - 0.5) * 2 * CREASE.crumple, dx = 0, dy = 0 }
                local edgeX, edgeY = i == 1 or i == NX, j == 1 or j == NY
                if edgeX and edgeY then
                    -- The corners stay put, unless they curl: up off the
                    -- book, and drawn in, so the outline bends round them.
                    local curl = CREASE.curl
                    if curl then
                        local amount = 0.5 + 0.5 * noise(n + 3)
                        v.z = v.z + curl.lift * amount
                        v.dx = (i == 1 and 1 or -1) * curl.pull * amount
                        v.dy = (j == 1 and 1 or -1) * curl.pull * amount
                    end
                elseif edgeX then
                    -- The outline wanders across itself, and is drawn in
                    -- where a fold meets it.
                    v.dx = (noise(n + 1) - 0.5) * 2 * CREASE.edge
                    if folds.rows[j] then v.dx = v.dx + (i == 1 and 1 or -1) * CREASE.nick end
                elseif edgeY then
                    v.dy = (noise(n + 2) - 0.5) * 2 * CREASE.edge
                    if folds.columns[i] then v.dy = v.dy + (j == 1 and 1 or -1) * CREASE.nick end
                else
                    v.dx = (noise(n + 1) - 0.5) * 2 * CREASE.drift
                    v.dy = (noise(n + 2) - 0.5) * 2 * CREASE.drift
                end
                -- A fold leans: its line runs across itself, one way at one
                -- end and the other way at the other.
                if folds.columns[i] then v.dx = v.dx + folds.columns[i].lean * (t - 0.5) * 2 end
                if folds.rows[j] then v.dy = v.dy + folds.rows[j].lean * (u - 0.5) * 2 end
                mesh[i][j] = v
            end
        end
        -- Its lowest point, where it rests on the book.
        mesh.low = math.huge
        for i = 1, NX do
            for j = 1, NY do mesh.low = math.min(mesh.low, mesh[i][j].z) end
        end

        -- Each facet's light, from how it slopes: rising to the right or
        -- down, it faces the light at the top left.
        for i = 1, NX - 1 do
            for j = 1, NY - 1 do
                local a, b, c, d = mesh[i][j], mesh[i + 1][j], mesh[i][j + 1], mesh[i + 1][j + 1]
                local slopeX = ((b.z + d.z) - (a.z + c.z)) / (2 * (X[i + 1] - X[i]))
                local slopeY = ((c.z + d.z) - (a.z + b.z)) / (2 * (Y[j + 1] - Y[j]))
                a.light = math.max(CREASE.lo, math.min(CREASE.hi, 1 + CREASE.light * (slopeX + slopeY)))
            end
        end
    end

    -- The facet a point of the flat sheet is on, and where in it (0..1).
    local function Facet(x, y)
        local i, j = 1, 1
        while i < NX - 1 and x > X[i + 1] do i = i + 1 end
        while j < NY - 1 and y > Y[j + 1] do j = j + 1 end
        return i, j, (x - X[i]) / (X[i + 1] - X[i]), (y - Y[j]) / (Y[j + 1] - Y[j])
    end

    -- How facet i, j is lit: evenly, laid flat.
    local function FacetLight(i, j)
        if view.flat or not mesh[i] then return 1 end
        return mesh[i][j].light or 1
    end

    -- How the facet at a point is lit.
    local function Light(x, y)
        return FacetLight(Facet(x, y))
    end

    -- A point of the flat sheet onto the screen: drifted with the mesh while
    -- it bends, turned with the sheet; relative to the sheet's middle, y up.
    -- Off the sheet (a plate's picture drawn past it, Split's `open`), it
    -- drifts as the edge it is beyond does, not on and on.
    local function Screen(x, y)
        if mesh[1] and view.bends then
            local i, j, t, u = Facet(x, y)
            t, u = math.max(0, math.min(1, t)), math.max(0, math.min(1, u))
            local a, b, c, d = mesh[i][j], mesh[i + 1][j], mesh[i][j + 1], mesh[i + 1][j + 1]
            x = x + (a.dx * (1 - t) + b.dx * t) * (1 - u) + (c.dx * (1 - t) + d.dx * t) * u
            y = y + (a.dy * (1 - t) + b.dy * t) * (1 - u) + (c.dy * (1 - t) + d.dy * t) * u
        end
        local cx, cy = x - W / 2, H / 2 - y
        return cx * cos - cy * sin, cx * sin + cy * cos
    end

    -- Places `region` on the sheet at x, y (its top left, the sheet's top
    -- left being 0, 0), w by h, turned with the sheet and `turn` more, then
    -- moved dx, dy on the screen (for shadows). Its middle follows the mesh;
    -- it does not bend (Bend does). A texture bent before (Corners marks it)
    -- has its corners put back first, or it would keep its old shape: one
    -- placed flat after "Flat paper only" was switched on, say (Unbend,
    -- UI/Paper/Surface.lua).
    local function Place(region, x, y, w, h, turn, dx, dy)
        Unbend(region)
        local sx, sy = Screen(x + w / 2, y + h / 2)
        region:ClearAllPoints()
        region:SetPoint("CENTER", region.anchorTo or S, "CENTER", sx + (dx or 0), sy + (dy or 0))
        region:SetSize(w, h)
        if region.SetRotation then region:SetRotation(angle + (turn or 0)) end
    end

    -- A button, which cannot turn: its square goes where the box's middle
    -- lands.
    local function PlaceButton(button, x, y, w, h)
        local sx, sy = Screen(x + w / 2, y + h / 2)
        button:ClearAllPoints()
        button:SetPoint("CENTER", button.anchorTo or S, "CENTER", sx, sy)
        button:SetSize(w, h)
    end

    -- A line of text with its middle at height y, starting at x ("LEFT"),
    -- ending there ("RIGHT") or centred on it. Returns its left and width.
    -- Measured unbounded (Width, UI/Paper/Surface.lua): a font string still
    -- sized for its last text reports only what fits that size, and would
    -- be cut short.
    local function PlaceText(text, x, y, justify)
        text:SetSize(0, 0)
        local w = Width(text) + 2
        local h = (text:GetStringHeight() or 0) + 2
        if justify == "RIGHT" then x = x - w elseif justify == "CENTER" then x = x - w / 2 end
        Place(text, x, y - h / 2, w, h)
        return x, w
    end

    local function Texture(layer, sublevel, frame)
        local texture = (frame or S):CreateTexture(nil, layer, nil, sublevel)
        -- Placed about the frame's own middle where it has one (`anchorTo`:
        -- a plate's picture, which pans), else the sheet's.
        texture.anchorTo = frame and frame.anchorTo
        -- Turned edges blend in instead of snapping to the pixel grid.
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        return texture
    end

    -- Whether a texture's corners can be moved. Whether the sheet bends is
    -- settled as it is laid (K.Lay).
    local probeTexture = Texture("ARTWORK", 0)
    view.canBend = probeTexture.SetVertexOffset ~= nil
    view.bends = view.canBend
    probeTexture:Hide()

    -- A texture is placed with its corners at points on the screen
    -- (relative to the sheet's middle, or its `anchorTo`'s, y up), as a w
    -- by h square bent to them, by Corners (UI/Paper/Surface.lua).

    -- Places `texture` over the flat rectangle x0, y0 to x1, y1 (inside one
    -- facet, or a pixel past it) with each corner where the mesh takes it,
    -- so it meets its neighbours. Without bending, it is placed whole and
    -- turned; `seal`ed, half a pixel over each edge, so no seam opens
    -- between opaque pieces turned side by side.
    local function Bend(texture, x0, y0, x1, y1, seal)
        if not view.bends then
            local o = seal and 0.5 or 0
            Place(texture, x0 - o, y0 - o, x1 - x0 + 2 * o, y1 - y0 + 2 * o)
            return
        end
        local ulx, uly = Screen(x0, y0)
        local llx, lly = Screen(x0, y1)
        local urx, ury = Screen(x1, y0)
        local lrx, lry = Screen(x1, y1)
        Corners(texture, texture.anchorTo or S, x1 - x0, y1 - y0, ulx, uly, llx, lly, urx, ury, lrx, lry)
    end

    -- Places `texture` over four points of the sheet, in polygon order:
    -- upper left, upper right, lower right, lower left (a stroke's left rail
    -- is the texture's top edge). Each corner goes where the sheet takes it
    -- (Screen: drifted with the mesh while it bends, turned with it always),
    -- so a chain of them shares its edges and folds with the paper, flat or
    -- not. The square bent to them is about as long and wide as the quad
    -- itself. False where the client cannot move corners.
    local function Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4)
        if not (view.canBend and texture.SetVertexOffset) then return false end
        local ulx, uly = Screen(x1, y1)
        local urx, ury = Screen(x2, y2)
        local lrx, lry = Screen(x3, y3)
        local llx, lly = Screen(x4, y4)
        local w = math.sqrt(((x2 + x3) - (x1 + x4)) ^ 2 + ((y2 + y3) - (y1 + y4)) ^ 2) / 2
        local h = math.sqrt(((x4 + x3) - (x1 + x2)) ^ 2 + ((y4 + y3) - (y1 + y2)) ^ 2) / 2
        Corners(texture, texture.anchorTo or S, math.max(w, 0.1), math.max(h, 0.1), ulx, uly, llx, lly, urx, ury,
            lrx, lry)
        return true
    end

    -- Calls fn(x0, y0, x1, y1, light) for each piece of the rectangle
    -- inside one facet. What is off the sheet is left out, unless `open`:
    -- then the edge facets reach on past it (a plate's picture drawn round
    -- its window, to pan into).
    local function Split(x0, y0, x1, y1, fn, open)
        local HUGE = math.huge
        for i = 1, NX - 1 do
            local lo, hi = (open and i == 1) and -HUGE or X[i], (open and i == NX - 1) and HUGE or X[i + 1]
            local a, b = math.max(x0, lo), math.min(x1, hi)
            if b > a then
                for j = 1, NY - 1 do
                    local top, bottom = (open and j == 1) and -HUGE or Y[j], (open and j == NY - 1) and HUGE or Y[j + 1]
                    local c, d = math.max(y0, top), math.min(y1, bottom)
                    if d > c then fn(a, c, b, d, FacetLight(i, j)) end
                end
            end
        end
    end

    -- Textures made as they are first needed (and set up by `setup`) and
    -- handed out in turn; after a drawing, the ones not handed out are
    -- hidden (a pool, UI/Kit/Pool.lua).
    local function Pool(layer, sublevel, setup, frame)
        return NewPool(function()
            local texture = Texture(layer, sublevel, frame)
            if setup then setup(texture) end
            return texture
        end)
    end

    ----------------------------------------------------------------------
    -- The paper

    -- On a ground of its own (opts.ground), its shadow takes that ground's
    -- colour and darkness.
    local GROUND = opts.ground
    local shadows, SHADE = {}, GROUND and GROUND.colour or LOOK.shade
    for i, shadow in ipairs(SHADOW_LIST) do
        shadows[i] = Texture("BACKGROUND", -8 + i - 1)
        shadows[i]:SetColorTexture(SHADE[1], SHADE[2], SHADE[3],
            math.min(0.9, shadow[4] * (GROUND and GROUND.strength or 1)))
    end
    -- The bent shadow, soft edge and core, from the facets along the right
    -- and bottom: the only ones whose shadow comes out from under the
    -- paper, as the light falls from the top left.
    local softPool, corePool = Pool("BACKGROUND", -8), Pool("BACKGROUND", -7)
    local BLACK = { 0, 0, 0 }

    -- Where the shadow of a crossing of the mesh falls on the screen, and
    -- how dark it is there: the core's, or with `soft` the soft edge's.
    local function Fallen(i, j, soft)
        local x, y = Screen(X[i], Y[j])
        local h = mesh[i][j].z - mesh.low
        local off, alpha = Lamp.Fall(h, soft, GROUND)
        return x + off, y - off, alpha
    end

    local function CastShadow()
        softPool:Begin()
        corePool:Begin()
        for i = 1, NX - 1 do
            for j = 1, NY - 1 do
                if i == NX - 1 or j == NY - 1 then
                    for _, part in ipairs({ { softPool, true }, { corePool, false } }) do
                        local ulx, uly = Fallen(i, j, part[2])
                        local llx, lly, ll = Fallen(i, j + 1, part[2])
                        local urx, ury, ur = Fallen(i + 1, j, part[2])
                        local lrx, lry, lr = Fallen(i + 1, j + 1, part[2])
                        local texture = part[1]:Next()
                        -- Along the bottom it shades left to right, down the
                        -- right side top to bottom.
                        local c = GROUND and GROUND.colour or BLACK
                        if j == NY - 1 then
                            Style.Gradient(texture, "HORIZONTAL", { c[1], c[2], c[3], ll }, { c[1], c[2], c[3], lr })
                        else
                            Style.Gradient(texture, "VERTICAL", { c[1], c[2], c[3], lr }, { c[1], c[2], c[3], ur })
                        end
                        Corners(texture, texture.anchorTo or S, X[i + 1] - X[i], Y[j + 1] - Y[j], ulx, uly, llx,
                            lly, urx, ury, lrx, lry)
                    end
                end
            end
        end
        softPool:Finish()
        corePool:Finish()
    end
    local inkPool = Pool("BACKGROUND", -6, function(t) t:SetColorTexture(INK[1], INK[2], INK[3], LOOK.edge) end)
    local paperPool = Pool("BACKGROUND", -5)
    local grainPath = Style.Art("grain")
    local grainPool = Pool("BORDER", 0, function(t)
        t:SetTexture(grainPath)
        t:SetAlpha(0.14)
    end)
    -- The creases: a valley's dark line, a ridge's lit side and shaded side.
    local creasePool = Pool("ARTWORK", 4)

    -- The grime: bands along the folds, cut from the grime art (else plain),
    -- over a map printed on the sheet (BORDER 1 to 3, UI/Map/Art.lua).
    local grimePath = Style.Art("grime")
    local T = GRUNGE.tint
    local grimePool = Pool("BORDER", 4, function(t)
        if grimePath then t:SetTexture(grimePath) else t:SetColorTexture(1, 1, 1, 1) end
    end)

    -- A crop of the grime art as big as w by h on the sheet, somewhere
    -- (`n`) in it.
    local function GrimeCrop(texture, w, h, n)
        if not grimePath then return end
        local cw, ch = w * GRUNGE.scale / 1024, h * GRUNGE.scale / 1024
        local u, v = Style.Noise(n) * (1 - cw), Style.Noise(n + 0.5) * (1 - ch)
        texture:SetTexCoord(u, u + cw, v, v + ch)
    end

    -- One side of a fold's band, fading out from it: `orientation` as
    -- SetGradient takes it, darkest at its end when `atEnd`.
    local function Grime(x0, y0, x1, y1, orientation, atEnd, n)
        local texture = grimePool:Next()
        GrimeCrop(texture, x1 - x0, y1 - y0, n)
        local a = math.min(0.6, GRUNGE.alpha * worn * (1 - GRUNGE.uneven * Style.Noise(n + 0.25)))
        local clear, dark = CreateColor(T[1], T[2], T[3], 0), CreateColor(T[1], T[2], T[3], a)
        local ok = pcall(texture.SetGradient, texture, orientation, atEnd and clear or dark, atEnd and dark or clear)
        if not ok then
            texture:SetVertexColor(T[1], T[2], T[3])
            texture:SetAlpha(a / 2)
        end
        Bend(texture, x0, y0, x1, y1)
    end

    local function Crease(x0, y0, x1, y1, r, g, b, a)
        local texture = creasePool:Next()
        texture:SetColorTexture(r, g, b, a)
        Bend(texture, x0, y0, x1, y1)
    end

    local function LayPaper()
        for i, shadow in ipairs(SHADOW_LIST) do
            local grow = shadow[3]
            Place(shadows[i], -grow, -grow, W + 2 * grow, H + 2 * grow, 0, shadow[1], shadow[2])
            -- Glued (it never bends), the contact line goes only laid flat.
            shadows[i]:SetShown(not view.bends and not (opts.glued and view.flat))
        end
        if view.bends then CastShadow() end

        inkPool:Begin()
        paperPool:Begin()
        grainPool:Begin()
        for i = 1, NX - 1 do
            for j = 1, NY - 1 do
                local x0, x1, y0, y1 = X[i], X[i + 1], Y[j], Y[j + 1]
                local light = FacetLight(i, j)
                local paper = paperPool:Next()
                paper:SetColorTexture(P[1] * light, P[2] * light, P[3] * light, 1)
                Bend(paper, x0, y0, x1, y1, true)
                -- The ink edge, a pixel out on the outline's sides only.
                if i == 1 or j == 1 or i == NX - 1 or j == NY - 1 then
                    Bend(inkPool:Next(), x0 - (i == 1 and 1 or 0), y0 - (j == 1 and 1 or 0),
                        x1 + (i == NX - 1 and 1 or 0), y1 + (j == NY - 1 and 1 or 0))
                end
                if grainPath then
                    local grain = grainPool:Next()
                    grain:SetTexCoord(x0 / W, x1 / W, y0 / H, y1 / H)
                    Bend(grain, x0, y0, x1, y1)
                end
            end
        end
        inkPool:Finish()
        paperPool:Finish()
        grainPool:Finish()

        -- The creases along the folds, in pieces along the mesh. A ridge is
        -- lit on its left or upper side and shaded on the other; a valley
        -- is a dark line. None, laid flat.
        creasePool:Begin()
        local I, V = INK, CREASE
        for k, fold in pairs(view.flat and {} or folds.columns) do
            local sign = fold.sign
            for j = 1, NY - 1 do
                local x = X[k]
                if sign > 0 then
                    Crease(x - 1, Y[j], x, Y[j + 1], 1, 0.97, 0.88, V.shine)
                    Crease(x, Y[j], x + 1, Y[j + 1], I[1], I[2], I[3], V.shade)
                else
                    Crease(x - 0.5, Y[j], x + 0.5, Y[j + 1], I[1], I[2], I[3], V.valley)
                end
            end
        end
        for k, fold in pairs(view.flat and {} or folds.rows) do
            local sign = fold.sign
            for i = 1, NX - 1 do
                local y = Y[k]
                if sign > 0 then
                    Crease(X[i], y - 1, X[i + 1], y, 1, 0.97, 0.88, V.shine)
                    Crease(X[i], y, X[i + 1], y + 1, I[1], I[2], I[3], V.shade)
                else
                    Crease(X[i], y - 0.5, X[i + 1], y + 0.5, I[1], I[2], I[3], V.valley)
                end
            end
        end
        creasePool:Finish()

        -- Grime along the folds, uneven from piece to piece, the bands
        -- overlapping where folds cross. None, laid flat.
        grimePool:Begin()
        local b, seed = GRUNGE.band * (1 + (worn - 1) * 0.5), view.seed or 0
        for k in pairs(view.flat and {} or folds.columns) do
            local x = X[k]
            for j = 1, NY - 1 do
                Grime(x - b, Y[j], x, Y[j + 1], "HORIZONTAL", true, seed + k * 3.1 + j * 1.7)
                Grime(x, Y[j], x + b, Y[j + 1], "HORIZONTAL", false, seed + k * 3.1 + j * 1.7 + 0.9)
            end
        end
        for k in pairs(view.flat and {} or folds.rows) do
            local y = Y[k]
            for i = 1, NX - 1 do
                Grime(X[i], y - b, X[i + 1], y, "VERTICAL", false, seed + k * 5.3 + i * 2.3)
                Grime(X[i], y, X[i + 1], y + b, "VERTICAL", true, seed + k * 5.3 + i * 2.3 + 0.9)
            end
        end
        grimePool:Finish()
    end

    -- A link whose text and underline turn with the sheet.
    local function Link(font, onClick)
        local link = Style.Link(S, font, onClick)
        function link:PlaceAt(x, y, justify)
            local left, w = PlaceText(self.label, x, y, justify)
            local h = self.label:GetStringHeight() or 0
            Place(self.line, left, y + h / 2 + 1, w, 1)
            PlaceButton(self, left - 2, y - h / 2 - 3, w + 4, h + 6)
        end
        return link
    end

    -- `text` broken into lines no wider than `width` in `font`: text that
    -- turns with the sheet is laid a line at a time.
    local measures = {}
    local function Wrap(text, width, font)
        local measure = measures[font]
        if not measure then
            measure = Style.Text(S, font)
            measure:Hide()
            measures[font] = measure
        end
        local lines, line = {}, ""
        for word in text:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            measure:SetText(try)
            if line ~= "" and Width(measure) > width then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        return lines
    end

    ----------------------------------------------------------------------
    -- Lying on the book

    local K = { Place = Place, PlaceButton = PlaceButton, PlaceText = PlaceText, Width = Width,
        Wrap = Wrap, Texture = Texture, Pool = Pool, Split = Split, Bend = Bend, Quad = Quad, Light = Light,
        Link = Link, Screen = Screen }

    -- Glued: where it is mounted on `parent`, and its turn as given.
    local glue = { x = 0, y = 0, turn = opts.turn or 0 }
    function K.Mount(x, y, w, h, turn)
        glue.x, glue.y, glue.turn = x, y, turn or 0
        W, H = w, h
        S:SetSize(w, h)
    end

    function K.Fall(key, given, at)
        local turn, seed
        turn, view.dx, view.dy, seed = Fall(key)
        if given then turn, view.dx, view.dy = given, 0, 0 end
        if at then view.dx, view.dy = at[1], at[2] end
        if opts.straight or not view.turnsText then turn = 0 end
        angle, cos, sin = turn, math.cos(turn), math.sin(turn)
        -- Its turn as it lies (radians, as SetRotation), for what is laid
        -- on it that turns by itself (the dungeon map's strips).
        view.angle = turn
        view.seed = seed
        nudge = { columns = {}, rows = {} }
        Crumple(seed)
    end

    -- A fold kept clear of the spots: of the places within `reach` of its
    -- line, nearest first (and the left or upper one first of two as
    -- near), the first `pad` px clear of every spot, never nearer than
    -- ROOM px to the mesh's lines either side of it; where none is clear,
    -- the one through the fewest. `axis` is the spots' "x" for a fold
    -- across, "y" for one down. Returns how far it moved.
    local ROOM = 12
    local function Clearing(lines, k, spots, axis, reach, pad)
        local at, lo, hi = lines[k], lines[k - 1] + ROOM, lines[k + 1] - ROOM
        local best, fewest = 0, math.huge
        for step = 0, reach do
            for _, off in ipairs(step == 0 and { 0 } or { -step, step }) do
                local p = at + off
                if p >= lo and p <= hi then
                    local cut = 0
                    for _, spot in ipairs(spots) do
                        if math.abs(p - spot[axis]) < spot.r + pad then cut = cut + 1 end
                    end
                    if cut == 0 then return off end
                    if cut < fewest then best, fewest = off, cut end
                end
            end
        end
        return best
    end

    function K.Clear(spots, reach, pad)
        -- From the lines as they fell, not as a last clearing left them.
        nudge = { columns = {}, rows = {} }
        Crumple(view.seed or 0)
        local moved = { columns = {}, rows = {} }
        for k in pairs(folds.columns) do moved.columns[k] = Clearing(X, k, spots, "x", reach, pad) end
        for k in pairs(folds.rows) do moved.rows[k] = Clearing(Y, k, spots, "y", reach, pad) end
        nudge = moved
        Crumple(view.seed or 0)
    end

    function K.Lines() return X, Y, folds end

    -- Worn with age (the dungeon map, UI/Dungeon/Sheet.lua's AGE): its
    -- stock `paper` ({ r, g, b }, nil for its own) and its grime `grime`
    -- times the usual, darker and wider along the folds. Laid by the next
    -- K.Lay.
    function K.Wear(paper, grime)
        P = paper or opts.paper or LOOK.paper
        view.paper = P
        worn = grime or 1
    end

    function K.Reshape(w, h, crease)
        W, H = w, h
        S:SetSize(w, h)
        if crease then
            CREASE = setmetatable(crease, getmetatable(CREASE))
            NX, NY = #CREASE.columns, #CREASE.rows
            -- The old mesh's lines and crossings past the new one's go.
            for k in pairs(X) do X[k] = nil end
            for k in pairs(Y) do Y[k] = nil end
            for k in pairs(mesh) do mesh[k] = nil end
        end
    end

    function K.Lay()
        view.flat = ns.Setting("flatSheets") == true
        view.bends = view.canBend and not view.flat and not opts.glued
        S:ClearAllPoints()
        if opts.glued then
            -- Turned as given, not as it fell; straight laid flat, or where
            -- text cannot turn (the pins' numbers). One facet, for its size.
            local turn = (view.flat or opts.straight or not view.turnsText) and 0 or glue.turn
            angle, cos, sin = turn, math.cos(turn), math.sin(turn)
            view.turn = turn
            Crumple(0)
            S:SetPoint("CENTER", parent, "TOPLEFT", glue.x + W / 2, -(glue.y + H / 2))
        else
            S:SetPoint("CENTER", view, "CENTER", view.dx or 0, view.dy or 0)
        end
        LayPaper()
    end

    ----------------------------------------------------------------------
    -- Its sound

    -- Paper rustles as the sheet is laid on the book and as it is taken off
    -- (Style.SOUNDS): on its own showing and hiding only, and only while the
    -- book is open. A sheet that comes and goes with its page or with the
    -- book, or is shown again where it already lies, stays silent, and so
    -- does one hidden `quiet`ly, when another sound says what happened.
    local show, hide = view.Show, view.Hide
    local function Rustle(key)
        if parent:IsVisible() and not opts.quiet and not opts.glued then Style.PlaySound(key) end
    end
    function view:Show()
        local was = self:IsShown()
        show(self)
        if not was then Rustle("sheetOpen") end
    end
    function view:Hide(quiet)
        local was = self:IsShown()
        hide(self)
        if was and not quiet then Rustle("sheetClose") end
    end
    function view:SetShown(on)
        if on then self:Show() else self:Hide() end
    end

    return view, K
end
