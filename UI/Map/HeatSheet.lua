-- The journal's map: where you saw someone, as heat over the map art, on a
-- loose sheet of paper lying across both pages of the open book.
--
-- The map is drawn from the client's own art tiles, the same ones Blizzard's
-- world map canvas uses: C_Map.GetMapArtLayers gives the layer's size and
-- tile size, C_Map.GetMapArtLayerTextures the tile file IDs, row by row,
-- and over them the areas the character has explored, as their own world
-- map has them (UI/Map/Art.lua).
-- Nothing here touches WorldMapFrame, so there is nothing to taint. Both
-- calls are unverified in this build; without them the heat still draws, on
-- a plain background.
--
-- It lies on the book as a loose sheet (UI/Paper/Sheet.lua), fallen a
-- little askew and carried folded, and everything on it is placed, cut
-- and lit with the paper.
--
-- The map is printed on the sheet: the art's own torn edge cropped off (by
-- texture coordinates, as nothing can be clipped at an angle), warmed
-- toward the page, in a border of ink (FRAME).
-- Heat is ink blotted onto the paper: the cells run together into blots
-- (UI/Ink/Blot.lua), a pale wash over all of them, edged with a thin line
-- of ink pooled where it dried, and deeper inks printed over it only where
-- you lingered, so a cluster is one blot with a dark heart, not a pile of
-- coins. A cell's strength is its count blended with its neighbours',
-- against the map's strongest (ns.Heat.Shade): on a busy map a sighting in
-- passing is a pale trace and only where you lingered goes dark, while a
-- map with a few sightings keeps each one strong. Where you
-- last saw them is an inked X. Under the map, a key, and links to the other
-- maps they were seen on. A click on the book beside the sheet puts it
-- away (`onPutAway`).

local addonName, ns = ...

local Format = ns.UI.Format
local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style

-- The sheet and what is on it, in its own coordinates. The map gets the
-- room under the header and is fitted into it by its art's shape.
local SHEET = { w = 600, h = 492, margin = 30, header = 34, mapTop = 58, mapW = 540, mapH = 360,
    key = 20, also = 44 }
local MAX_CELLS = 600
local DEFAULT_ASPECT = 1002 / 668  -- a classic zone map

-- The printed map: how much of the art's edge is cropped (its torn border),
-- the warm tint the art takes, and how far its colour is drawn toward grey
-- (`desaturate`, where the client can: SetDesaturation), so the heat's
-- ink stands out against the green.
local PLATE = { crop = 0.022, tint = { 1, 0.94, 0.82 }, desaturate = 0.3 }
-- Its border: a band of ink `width` wide all round, at `alpha`, so the
-- paper shows through it brown, and lit with the folds.
local FRAME = { width = 4, alpha = 0.65 }
-- The heat's ink runs from `floor` (a trace) to `floor + span` (the
-- strongest).
local HEAT = { floor = 0.22, span = 0.62 }
-- The heat as blots (UI/Ink/Blot.lua), sizes in grid cells. Three inks,
-- one over another, as the key's three swatches. Each is the ground where
-- the cells' bumps (`sigma` cells) add up past its `edge`, a cell weighing
-- from nothing at strength `from` to all of it at `full`:
--   the first takes every cell, the faintest at 0.4 of full (`from` is
--   below 0), so a lone sighting is a round blot about 2.5 cells across,
--   a passing one on a busy map about 1.5, and a trail walked once a pale
--   path about two cells wide, unbroken even where you rode (a cell every
--   other one)
--   the second and third take only the cells you lingered in: the heart of
--   a lone sighting, the hotspots of a busy map
-- Each is printed so that, over the ones under it, it comes to
-- HeatColor(t), as its swatch does. The first is edged with a rim `rim` px
-- wide in the darkest ink at `rimAlpha`, ink pooled where it dried. The
-- outline is traced on a grid `step` cells fine, coarser past `cap` pieces
-- in all, and wobbles `warp[1]` cells over about `warp[2]`.
local BLOT = {
    levels = {
        { t = 0.15, sigma = 0.70, edge = 0.20, from = -2 / 3, full = 1 },
        { t = 0.55, sigma = 0.60, edge = 0.29, from = 0.25, full = 0.55 },
        { t = 1, sigma = 0.55, edge = 0.52, from = 0.6, full = 0.9 },
    },
    rim = 1.3, rimAlpha = 0.35, step = 0.3, cap = 1400, warp = { 0.08, 1.7 },
}
-- The key's swatches, and how many other maps get a link.
local KEY = { swatch = 8, step = 10, also = 6 }

local function MapName(mapID)
    return ns.MapName(mapID) or Fmt(L["Map %d"], mapID)
end

local function HeatColor(t)
    -- Rust for a little, deep red-brown for a lot. The floor is low, as a
    -- map with a few sightings keeps them high by itself (a lone sighting
    -- is t = 1), so only passing sightings on a busy map come out faint.
    return 0.62 - 0.22 * t, 0.16 - 0.08 * t, 0.06, HEAT.floor + HEAT.span * t
end

-- Blot level k's ink: HeatColor at its t, at the alpha that, printed over
-- the levels under it, comes to HeatColor's.
local function LevelInk(k)
    local r, g, b, a = HeatColor(BLOT.levels[k].t)
    local under = k > 1 and select(4, HeatColor(BLOT.levels[k - 1].t)) or 0
    return r, g, b, 1 - (1 - a) / (1 - under)
end

-- The heat on a map as blots: `cells` and `total` as ns.Heat.Cells gives
-- them, onto the map's box mx, my, mw, mh on the sheet (the art cropped
-- `crop` all round), cut along the folds `cutsX`, `cutsY`. Cells off the
-- part shown still bleed in from beyond the edge, cut there. Returns
-- InkBlot's quads and how many cells lie on the part shown.
local function HeatBlots(cells, total, mx, my, mw, mh, crop, cutsX, cutsY)
    local list = ns.Heat.Shade(cells, total)
    local span = 1 - 2 * crop
    local cell = mw / span / ns.Heat.GRID
    local points, shown = {}, 0
    for i = 1, math.min(#list, MAX_CELLS) do
        local x, y = ns.Heat.CellXY(list[i].cell)
        local u, v = (x - crop) / span, (y - crop) / span
        if u >= 0 and u <= 1 and v >= 0 and v <= 1 then shown = shown + 1 end
        points[#points + 1] = { x = mx + u * mw, y = my + v * mh, t = list[i].t }
    end
    local levels = {}
    for k, level in ipairs(BLOT.levels) do
        levels[k] = { sigma = level.sigma * cell, edge = level.edge, from = level.from, full = level.full }
    end
    local blot = ns.UI.InkBlot.Build(points, levels, { step = BLOT.step * cell, cap = BLOT.cap,
        rim = BLOT.rim, warp = { BLOT.warp[1] * cell, BLOT.warp[2] * cell },
        clip = { mx, my, mx + mw, my + mh }, cutsX = cutsX, cutsY = cutsY })
    return blot, shown
end

ns.UI.MapSheet = {}

-- `parent` is what the sheet lies on: it covers it, and a click on it
-- outside the sheet puts the sheet away.
function ns.UI.MapSheet.New(parent)
    local W, H = SHEET.w, SHEET.h
    local P = Style.PAPER

    local view, K = ns.UI.LooseSheet(parent, W, H)
    local S = view.sheet
    local Place, PlaceButton, PlaceText, Width = K.Place, K.PlaceButton, K.PlaceText, K.Width
    local Texture, Pool, Split, Bend, Quad, Light, Link = K.Texture, K.Pool, K.Split, K.Bend, K.Quad, K.Light, K.Link

    ----------------------------------------------------------------------
    -- The map

    -- Under the art, and in its place where there is none; the border;
    -- the art's tiles, and over them the areas explored. All cut along the
    -- mesh.
    local backgroundPool = Pool("BORDER", 1)
    local framePool = Pool("ARTWORK", 3)
    local tilePool = Pool("BORDER", 2)
    local exploredPool = Pool("BORDER", 3)
    -- The heat's inks, one pool a level, palest lowest, and the rim over
    -- the palest.
    local blotPools = { Pool("ARTWORK", -1), Pool("ARTWORK", 1), Pool("ARTWORK", 2) }
    local rimPool = Pool("ARTWORK", 0)

    -- Whether the client can draw a texture part way to grey (PLATE):
    -- asked under pcall, as a build without the method may raise on it.
    local probe = Texture("BORDER", 0)
    local asked, desaturate = pcall(function() return probe.SetDesaturation end)
    view.canDesaturate = asked and type(desaturate) == "function"
    probe:Hide()

    -- Prints ink over the rectangle x0, y0 to x1, y1, cut along the mesh
    -- and lit with it.
    local function Ink(x0, y0, x1, y1)
        local I = Style.INK_STRONG
        Split(x0, y0, x1, y1, function(a, b, c, d, light)
            local texture = framePool:Next()
            texture:SetColorTexture(I[1] * light, I[2] * light, I[3] * light, FRAME.alpha)
            Bend(texture, a, b, c, d)
        end)
    end

    -- The border round the map's box: a band of ink all round.
    local function PrintFrame(mx, my, mw, mh)
        local d = FRAME.width
        local x0, y0, x1, y1 = mx, my, mx + mw, my + mh
        Ink(x0 - d, y0 - d, x1 + d, y0)
        Ink(x0 - d, y1, x1 + d, y1 + d)
        Ink(x0 - d, y0, x0, y1)
        Ink(x1, y0, x1 + d, y1)
    end

    -- The last-seen mark: an inked X, two strokes of red over a paper halo
    -- so it reads on the busiest part of the art.
    local function Cross(size, layer)
        local strokes = {}
        local length = size * 0.8
        for _, part in ipairs({ { length + 3, 4.5, P, 0.85, 1 }, { length, 2, Style.RUBRIC, 1, 2 } }) do
            for _, turn in ipairs({ math.pi / 4, -math.pi / 4 }) do
                local stroke = Texture(layer, part[5])
                stroke:SetColorTexture(part[3][1], part[3][2], part[3][3], part[4])
                strokes[#strokes + 1] = { texture = stroke, w = part[1], h = part[2], turn = turn }
            end
        end
        local cross = { strokes = strokes }
        function cross:Place(x, y)
            for _, s in ipairs(self.strokes) do Place(s.texture, x - s.w / 2, y - s.h / 2, s.w, s.h, s.turn) end
        end
        function cross:SetShown(on)
            self.shown = on
            for _, s in ipairs(self.strokes) do s.texture:SetShown(on) end
        end
        function cross:IsShown() return self.shown == true end
        function cross:Show() self:SetShown(true) end
        function cross:Hide() self:SetShown(false) end
        return cross
    end
    view.marker = Cross(16, "OVERLAY")
    view.marker:Hide()

    view.empty = Style.Text(S, Style.FONT.faded)
    view.empty:SetJustifyH("CENTER")

    ----------------------------------------------------------------------
    -- Header and key

    -- The map's menu's generator (the maps as they are now), or nil where
    -- there is none: the mouse's menu and the pad's (UI/Journal/PeoplePad.lua).
    function view.mapMenu()
        if not view.maps or #view.maps == 0 then return nil end
        local choices = {}
        for _, entry in ipairs(view.maps) do
            choices[#choices + 1] = { label = Fmt(L["%1$s (%2$d)"], MapName(entry.mapID), entry.total), key = entry.mapID }
        end
        return Style.ChoiceGenerator(L["Show map"], choices, function() return view.mapID end, function(mapID)
            view.mapID = mapID
            view:Refresh()
        end)
    end
    view.mapButton = Link(Style.FONT.page, function(self)
        local generator = view.mapMenu()
        if generator then MenuUtil.CreateContextMenu(self, generator) end
    end)

    local function SetScope(everyone)
        return function()
            if view.everyone == everyone then return end
            view.everyone = everyone
            view.mapID = nil
            view:Refresh()
        end
    end
    view.everyoneButton = Link(Style.FONT.body, SetScope(true))
    view.everyoneButton:SetText(L["Everyone"])
    view.bar = Style.Text(S, Style.FONT.small)
    view.bar:SetText("|")
    view.themButton = Link(Style.FONT.body, SetScope(false))

    -- A swatch is its level's ink over the ones under it, as on the map;
    -- `swatches` holds the top disc of each, `swatchUnder` the others.
    view.swatches, view.swatchUnder = {}, {}
    for i = 1, #BLOT.levels do
        for k = 1, i do
            local disc = Texture("ARTWORK", k - 1)
            Style.Disc(disc, LevelInk(k))
            if k == i then view.swatches[i] = disc else view.swatchUnder[#view.swatchUnder + 1] = { disc, i } end
        end
    end
    view.legend = Style.Text(S, Style.FONT.small)
    view.seen = Style.Text(S, Style.FONT.small)
    view.seenCross = Cross(12, "ARTWORK")

    view.alsoLabel = Style.Text(S, Style.FONT.heading)
    view.alsoLabel:SetText(L["ALSO SEEN IN"])
    view.also = {}
    for i = 1, KEY.also do
        view.also[i] = Link(Style.FONT.body, function(self)
            view.mapID = self.mapID
            view:Refresh()
        end)
    end

    ----------------------------------------------------------------------
    -- Drawing

    -- The map's box on the sheet, fitted to the art's shape.
    local function MapBox(aspect)
        local mw, mh = SHEET.mapW, SHEET.mapW / aspect
        if mh > SHEET.mapH then mw, mh = SHEET.mapH * aspect, SHEET.mapH end
        return (W - mw) / 2, SHEET.mapTop, mw, mh
    end

    -- Draws the art into its box, cropped, and returns how a point of the
    -- map (0..1 across the whole art) lands on the sheet, and the box.
    local function DrawArt(mapID)
        local layer, pieces = ns.UI.MapArt.For(mapID)
        local mx, my, mw, mh = MapBox(layer and layer.layerWidth / layer.layerHeight or DEFAULT_ASPECT)
        local crop = layer and PLATE.crop or 0

        backgroundPool:Begin()
        local B = Style.MAP_BACKGROUND
        Split(mx, my, mx + mw, my + mh, function(x0, y0, x1, y1, light)
            local texture = backgroundPool:Next()
            texture:SetColorTexture(B[1] * light, B[2] * light, B[3] * light, 1)
            Bend(texture, x0, y0, x1, y1, true)
        end)
        backgroundPool:Finish()

        framePool:Begin()
        PrintFrame(mx, my, mw, mh)
        framePool:Finish()

        tilePool:Begin()
        exploredPool:Begin()
        local tiles, explored = 0, 0
        if layer then
            tiles, explored = ns.UI.MapArt.Print(layer, pieces, crop, mx, my, mw, PLATE.tint, K, tilePool, exploredPool)
            if view.canDesaturate then
                for _, pool in ipairs({ tilePool, exploredPool }) do
                    for i = 1, pool.used do pool[i]:SetDesaturation(PLATE.desaturate) end
                end
            end
        end
        tilePool:Finish()
        exploredPool:Finish()
        view.tileCount, view.exploredCount = tiles, explored

        -- A map point onto the sheet; nil off the part shown.
        local function At(x, y)
            local u, v = (x - crop) / (1 - 2 * crop), (y - crop) / (1 - 2 * crop)
            if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
            return mx + u * mw, my + v * mh
        end
        return At, mx, my, mw, mh, crop
    end

    -- One piece of ink over four points of the sheet, lit with the facet
    -- it lies on. Where the client cannot move corners, the box round it
    -- instead.
    local function Piece(texture, q, r, g, b, a)
        local light = Light((q[1] + q[3] + q[5] + q[7]) / 4, (q[2] + q[4] + q[6] + q[8]) / 4)
        texture:SetColorTexture(r * light, g * light, b * light, a)
        if Quad(texture, q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8]) then return end
        local x0, y0 = math.min(q[1], q[3], q[5], q[7]), math.min(q[2], q[4], q[6], q[8])
        local x1, y1 = math.max(q[1], q[3], q[5], q[7]), math.max(q[2], q[4], q[6], q[8])
        Place(texture, x0, y0, x1 - x0, y1 - y0)
    end

    -- The heat as blots over the map's box, cut along the folds so each
    -- piece takes its facet's light. The rim needs corners that move: a
    -- box round each of its slivers would be a smudge.
    local function DrawHeat(cells, total, mx, my, mw, mh, crop)
        local cutsX, cutsY = {}, {}
        Split(mx, my, mx + mw, my + mh, function(x0, y0, x1, y1)
            cutsX[#cutsX + 1], cutsX[#cutsX + 2] = x0, x1
            cutsY[#cutsY + 1], cutsY[#cutsY + 2] = y0, y1
        end)
        local blot, shown = HeatBlots(cells, total, mx, my, mw, mh, crop, cutsX, cutsY)
        view.blot, view.cellCount = blot, shown
        view.box = { x = mx, y = my, w = mw, h = mh, crop = crop }

        for k, pool in ipairs(blotPools) do
            pool:Begin()
            local r, g, b, a = LevelInk(k)
            for _, q in ipairs(blot.levels[k] or {}) do Piece(pool:Next(), q, r, g, b, a) end
            pool:Finish()
        end
        rimPool:Begin()
        if view.canBend then
            local r, g, b = HeatColor(1)
            for _, q in ipairs(blot.rim) do Piece(rimPool:Next(), q, r, g, b, BLOT.rimAlpha) end
        end
        rimPool:Finish()
    end

    -- The person's last-seen spot, when it is on this map.
    local function DrawMarker(mapID, At)
        local record = view.guid and not view.everyone and ns.Characters.Get(view.guid)
        local seen = record and record.seen
        local x, y
        if seen and seen.mapID == mapID and seen.x and seen.y then x, y = At(seen.x, seen.y) end
        if x then view.marker:Place(x, y) end
        view.marker:SetShown(x ~= nil)
    end

    ----------------------------------------------------------------------
    -- Choosing what to show

    local function Scope()
        return (not view.everyone) and view.guid or nil
    end

    -- The header: the map, which opens the list of maps, and whose heat.
    local function FillHeader()
        local y = SHEET.header
        view.mapButton:PlaceAt(SHEET.margin, y - 2)
        local right = W - SHEET.margin
        view.everyoneButton:PlaceAt(right, y, "RIGHT")
        local left = PlaceText(view.bar, right - Width(view.everyoneButton.label) - 10, y, "RIGHT")
        view.themButton:PlaceAt(left - 4, y, "RIGHT")
    end

    -- The key under the map: the heat, the X when it is on the map, and
    -- links to the other maps. All of it hidden while there are no maps.
    local function FillKey(maps, total, my, mh)
        local any = #maps > 0
        local y, left = my + mh + SHEET.key, (W - SHEET.mapW) / 2
        for i, swatch in ipairs(view.swatches) do
            swatch:SetShown(any)
            Place(swatch, left + (i - 1) * KEY.step, y - KEY.swatch / 2, KEY.swatch, KEY.swatch)
        end
        for _, under in ipairs(view.swatchUnder) do
            under[1]:SetShown(any)
            Place(under[1], left + (under[2] - 1) * KEY.step, y - KEY.swatch / 2, KEY.swatch, KEY.swatch)
        end
        local n = total or 0
        local legend = view.everyone and L["Your diary was seen here %d time|Your diary was seen here %d times##plural"]
            or L["Seen here %d time|Seen here %d times##plural"]
        view.legend:SetText(any and ns.Plural(n, legend) or "")
        PlaceText(view.legend, left + 2 * KEY.step + KEY.swatch + 6, y)

        local record = view.marker:IsShown() and ns.Characters.Get(view.guid) or nil
        local when = record and record.seen and record.seen.time or nil
        view.seen:SetText(when and Fmt(L["Last seen %s"], Format.At(when)) or "")
        local seenLeft = PlaceText(view.seen, W - left, y, "RIGHT")
        view.seenCross:Place(seenLeft - 9, y)
        view.seenCross:SetShown(when ~= nil)

        local alsoY = my + mh + SHEET.also
        local _, labelW = PlaceText(view.alsoLabel, left, alsoY)
        local x, shown = left + labelW + 8, 0
        for _, entry in ipairs(maps) do
            local link = view.also[shown + 1]
            if not link then break end
            if entry.mapID ~= view.mapID then
                link:SetText(Fmt(L["%1$s (%2$d)"], MapName(entry.mapID), entry.total))
                local w = Width(link.label)
                if x + w > W - left then break end
                link.mapID = entry.mapID
                link:PlaceAt(x, alsoY)
                link:Show()
                x, shown = x + w + 14, shown + 1
            end
        end
        for i = shown + 1, #view.also do view.also[i]:Hide() end
        view.alsoLabel:SetShown(shown > 0)
    end

    function view:Refresh()
        local maps = ns.Heat.Maps(Scope())
        self.maps = maps

        K.Lay()

        local record = self.guid and ns.Characters.Get(self.guid)
        local first = record and ns.Characters.Name(self.guid)
        self.themButton:SetText(first and Fmt(L["Just %s"], first:match("^(%S+)")) or L["Just them"])
        self.themButton:SetCurrent(not self.everyone)
        self.everyoneButton:SetCurrent(self.everyone == true)

        if #maps == 0 then
            local _, mx, my, mw, mh, crop = DrawArt(0)
            DrawHeat({}, 0, mx, my, mw, mh, crop)
            self.marker:Hide()
            self.mapID = nil
            self.mapButton:SetText(L["No maps yet"])
            self.empty:SetText(self.everyone and L["Nobody from your diary seen on a map yet."]
                or L["Not seen on a map yet.\nThis fills in as you see them nearby."])
            PlaceText(self.empty, mx + mw / 2, my + mh / 2, "CENTER")
            FillHeader()
            FillKey(maps, 0, my, mh)
            return
        end
        self.empty:SetText("")

        local known = false
        for i = 1, #maps do
            if maps[i].mapID == self.mapID then known = true end
        end
        if not known then
            -- Where the user is now, if they have history here; else the busiest.
            local here = ns.Plain(C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
            self.mapID = maps[1].mapID
            for i = 1, #maps do
                if maps[i].mapID == here then self.mapID = here end
            end
        end

        local cells, _, total = ns.Heat.Cells(Scope(), self.mapID)
        local At, mx, my, mw, mh, crop = DrawArt(self.mapID)
        DrawHeat(cells, total, mx, my, mw, mh, crop)
        DrawMarker(self.mapID, At)

        self.mapButton:SetText(MapName(self.mapID))
        FillHeader()
        FillKey(maps, total, my, mh)
    end

    -- A new person's sheet falls their way; the scope and map are kept for
    -- the same person.
    function view:SetPerson(guid)
        if guid ~= self.guid then self.mapID = nil end
        self.guid = guid
        K.Fall(guid)
        self:Refresh()
    end

    view:Hide()
    return view
end
