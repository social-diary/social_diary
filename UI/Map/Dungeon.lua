-- Adapted from Dungeon Crawler Forever 0.1.11 (Per, GPL-3.0-or-later): the
-- floor art drawing (UI/View.lua's layoutArt, its four kinds of art) and
-- placing a point on the floor shown (toDisplay), changed 2026-10-16.
--
-- A dungeon's floor as map art (MAP-1), for whatever prints it: the dungeon
-- page's print (UI/Dungeon/Print.lua) and its small prints of the other
-- floors, and later the super plate in Your Diary (JRN-20). A canvas is a
-- frame that clips its art; Draw fills it with one floor, fitted to the
-- size it is given, and hands back how to place a point of any floor on
-- it. The floors come from ns.Dungeons (Core/Dungeons.lua), in one of
-- four shapes:
--   client art   tiles[row][col] FileDataIDs, `tile` px square, the
--                floor `w` by `h` px (the last row and column run past it
--                and are clipped)
--   drawn art    the same, with addon paths (custom = true)
--   yards        Forever's minimap tiles, { FileDataID, x, y, size } in
--                yards over a floor `w` by `h` yards (yards = true)
--   combined     crops of the other floors' art, each feathered at its
--                edges so they melt into one sheet (combined = true)
-- How it is toned is the caller's (`look`): the canvas only lays the art.
-- Nothing here touches WorldMapFrame, so there is nothing to taint.

local addonName, ns = ...

local DungeonMap = {}
ns.UI.DungeonMap = DungeonMap

-- The soft-edged mask a combined map's pieces are cut with: DCF's own.
local FEATHER = "Interface\\AddOns\\" .. addonName .. "\\Vendor\\DungeonCrawlerForever\\Art\\feather"
-- A hair of overlap between tiles, so no seam shows between them (yards:
-- a little more, as Forever's big tiles leave hairlines).
local SEAM = { tiles = 0.5, yards = 0.6 }

-- The size `floor` comes out at inside `maxW` by `maxH`, its shape kept,
-- and the scale (screen px per px, or yard, of its art).
function DungeonMap.Fit(floor, maxW, maxH)
    local s = math.min(maxW / floor.w, maxH / floor.h)
    return floor.w * s, floor.h * s, s
end

-- A new canvas on `parent`. Place it, then Draw a floor into it.
function DungeonMap.New(parent)
    local canvas = CreateFrame("Frame", nil, parent)
    canvas:SetClipsChildren(true)

    -- Under the art, and all there is where the art is missing.
    local ground = canvas:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    local G = ns.Style.MAP_BACKGROUND
    ground:SetColorTexture(G[1], G[2], G[3], 1)
    canvas.ground = ground

    -- Plain tiles, and a combined map's: those keep the mask of their piece
    -- for good (a pool a piece), so no tile ever changes mask.
    canvas.tiles = ns.UI.Pool.New(function() return canvas:CreateTexture(nil, "ARTWORK") end)
    canvas.masks, canvas.masked = {}, {}

    -- Whether the client can grey a texture part way (SetDesaturation),
    -- asked once: a print's art is toned by its caller's `look`.
    local probe = canvas.ground
    local asked, fn = pcall(function() return probe.SetDesaturation end)
    canvas.canDesaturate = asked and type(fn) == "function"

    canvas.Draw = DungeonMap.Draw
    canvas.Place = DungeonMap.Place
    return canvas
end

-- One texture from `pool`, toned by `look` ({ tint, desaturate, plain }:
-- greyed part way and tinted where the client can, else tinted `plain`).
local function Tile(canvas, pool, look)
    local t = pool:Next()
    t:ClearAllPoints()
    t:SetTexCoord(0, 1, 0, 1)
    local tint = look and (canvas.canDesaturate and look.tint or look.plain or look.tint)
    if tint then t:SetVertexColor(tint[1], tint[2], tint[3]) else t:SetVertexColor(1, 1, 1) end
    if canvas.canDesaturate then t:SetDesaturation(look and look.desaturate or 0) end
    canvas.drawn = canvas.drawn + 1
    return t
end

-- A combined map's piece `pi`: its mask, and its own pool of tiles.
local function Piece(canvas, pi)
    local mask = canvas.masks[pi]
    if not mask then
        mask = canvas:CreateMaskTexture()
        mask:SetTexture(FEATHER, "CLAMPTOWHITE", "CLAMPTOWHITE")
        canvas.masks[pi] = mask
        canvas.masked[pi] = ns.UI.Pool.New(function()
            local t = canvas:CreateTexture(nil, "ARTWORK", nil, 1)
            t:AddMaskTexture(mask)
            return t
        end)
    end
    return mask, canvas.masked[pi]
end

local function DrawCombined(canvas, floor, s, look)
    local c = floor.data
    local Floor = ns.Dungeons.Floor
    -- A crop stretched over the whole sheet, under the pieces.
    if c.bg then
        local sf = Floor(floor.instanceID, c.bg.floor)
        if sf and sf.tiles then
            local col, row = math.floor(c.bg.x0 / sf.tile) + 1, math.floor(c.bg.y0 / sf.tile) + 1
            local fid = sf.tiles[row] and sf.tiles[row][col]
            if fid then
                local t = Tile(canvas, canvas.tiles, look)
                local tx0, ty0 = (col - 1) * sf.tile, (row - 1) * sf.tile
                t:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
                t:SetSize(floor.w * s, floor.h * s)
                t:SetTexture(fid)
                t:SetTexCoord((c.bg.x0 - tx0) / sf.tile, (c.bg.x1 - tx0) / sf.tile,
                    (c.bg.y0 - ty0) / sf.tile, (c.bg.y1 - ty0) / sf.tile)
            end
        end
    end
    for _, pool in pairs(canvas.masked) do pool:Begin() end
    for pi, p in ipairs(c.pieces or {}) do
        local sf = Floor(floor.instanceID, p.floor)
        if sf and sf.tiles then
            local mask, pool = Piece(canvas, pi)
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", canvas, "TOPLEFT", p.dx * s, -p.dy * s)
            mask:SetSize((p.x1 - p.x0) * p.s * s, (p.y1 - p.y0) * p.s * s)
            for r, rowTiles in ipairs(sf.tiles) do
                for col, fid in ipairs(rowTiles) do
                    local tx0, ty0 = (col - 1) * sf.tile, (r - 1) * sf.tile
                    local ix0, ix1 = math.max(tx0, p.x0), math.min(tx0 + sf.tile, p.x1, sf.w)
                    local iy0, iy1 = math.max(ty0, p.y0), math.min(ty0 + sf.tile, p.y1, sf.h)
                    if ix1 > ix0 and iy1 > iy0 then
                        local t = Tile(canvas, pool, look)
                        t:SetTexture(fid)
                        t:SetTexCoord((ix0 - tx0) / sf.tile, (ix1 - tx0) / sf.tile,
                            (iy0 - ty0) / sf.tile, (iy1 - ty0) / sf.tile)
                        t:SetSize((ix1 - ix0) * p.s * s + SEAM.tiles, (iy1 - iy0) * p.s * s + SEAM.tiles)
                        t:SetPoint("TOPLEFT", canvas, "TOPLEFT", (p.dx + (ix0 - p.x0) * p.s) * s,
                            -(p.dy + (iy0 - p.y0) * p.s) * s)
                    end
                end
            end
        end
    end
    for _, pool in pairs(canvas.masked) do pool:Finish() end
end

-- Draws `floor` into the canvas at `w` by `h` (its own shape: DungeonMap.Fit),
-- toned by `look`. Returns the canvas's Place. With no floor, the canvas is
-- its ground alone.
function DungeonMap.Draw(canvas, floor, w, h, look)
    canvas.floor, canvas.w, canvas.h, canvas.drawn = floor, w, h, 0
    canvas:SetSize(w, h)
    canvas.tiles:Begin()
    if floor then
        local s = math.min(w / floor.w, h / floor.h)
        canvas.scale = s
        if floor.combined then
            DrawCombined(canvas, floor, s, look)
        elseif floor.yards then
            for _, tl in ipairs(floor.tiles or {}) do
                local size = (tl[4] or 128) * s
                local t = Tile(canvas, canvas.tiles, look)
                t:SetSize(size + SEAM.yards, size + SEAM.yards)
                t:SetPoint("TOPLEFT", canvas, "TOPLEFT", tl[2] * s, -tl[3] * s)
                t:SetTexture(tl[1])
            end
        else
            local tw = floor.tile * s
            for r, row in ipairs(floor.tiles or {}) do
                for c, file in ipairs(row) do
                    local t = Tile(canvas, canvas.tiles, look)
                    t:SetSize(tw + SEAM.tiles, tw + SEAM.tiles)
                    t:SetPoint("TOPLEFT", canvas, "TOPLEFT", (c - 1) * tw, -(r - 1) * tw)
                    t:SetTexture(file)
                end
            end
        end
    end
    canvas.tiles:Finish()
    return canvas.Place
end

-- Where a point of floor `srcFloorID`'s art (x, y fractions of it) lies on
-- the canvas: px right and down from its top left, or nil when that point
-- is not on the floor drawn.
function DungeonMap.Place(canvas, srcFloorID, x, y)
    if not canvas.floor then return nil end
    local fx, fy = ns.Dungeons.Point(canvas.floor, tonumber(srcFloorID), x, y)
    if not fx then return nil end
    return fx * canvas.w, fy * canvas.h
end
