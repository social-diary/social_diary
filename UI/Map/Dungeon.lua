-- Adapted from Dungeon Crawler Forever 0.1.11 (Per, GPL-3.0-or-later): the
-- floor art drawing (UI/View.lua's layoutArt, its four kinds of art) and
-- placing a point on the floor shown (toDisplay), changed 2026-10-16.
--
-- A dungeon's floor as map art (MAP-1), printed on a loose sheet of paper:
-- the run's map on the table spread (UI/Dungeon/Sheet.lua), and later the
-- super plate in Your Diary (JRN-20), a glued sheet. The floors come from
-- ns.Dungeons (Core/Dungeons.lua), in one of four shapes:
--   client art   tiles[row][col] FileDataIDs, `tile` px square, the
--                floor `w` by `h` px (the last row and column run past it
--                and are cut off)
--   drawn art    the same, with addon paths (custom = true)
--   yards        Forever's minimap tiles, { FileDataID, x, y, size } in
--                yards over a floor `w` by `h` yards (yards = true)
--   combined     crops of the other floors' art, each feathered at its
--                edges so they melt into one sheet (combined = true)
--
-- Printed whole and edge to edge (the user, 16 Oct): the floor's whole
-- image is the whole of the sheet, which takes its shape
-- (UI/Dungeon/Sheet.lua), nothing of it cut off (TRIM, Kept).
-- Nothing can be clipped at an angle, so nothing is: the floor is first
-- broken into pieces (Pieces), each a file showing only the part of it
-- that lies in the window (texture coordinates), and each piece is cut
-- again along the sheet's mesh as it is printed (Printer), so the art
-- turns, folds and takes the light with the paper it is printed on. A
-- combined map's pieces are each feathered by a mask laid over the piece
-- and turned with the sheet; a client whose masks cannot turn has its
-- combined maps laid straight by the caller (`masksTurn`).
-- How it is toned is the caller's (`look`): this only lays the art.
-- Nothing here touches WorldMapFrame, so there is nothing to taint.

local addonName, ns = ...

local DungeonMap = {}
ns.UI.DungeonMap = DungeonMap

-- The soft-edged mask a combined map's pieces are cut with: DCF's own.
local FEATHER = "Interface\\AddOns\\" .. addonName .. "\\Vendor\\DungeonCrawlerForever\\Art\\feather"
-- A hair of overlap, in px on the sheet, where one piece meets the next
-- inside the floor, so no seam shows between them (yards: a little more,
-- as Forever's big tiles leave hairlines).
local SEAM = { tiles = 0.5, yards = 0.6 }
-- How much of each side of the art could be cut off as its own border: a
-- share of the floor's width and height, by kind of art. None: the drawn
-- maps' title banner and caves reach their edges, and a trim of them cut
-- Wailing Caverns' banner and caves off (16 Oct, in the client); the
-- client's maps' torn edge and gilt corners are part of the picture the
-- player knows. Kept for a map that would want one: a trim never cuts
-- through what is marked (Kept).
local TRIM = { tiles = 0, custom = 0, yards = 0, combined = 0 }
-- What is marked never lies in the border cut off, nor close to the
-- paper's edge: each boss is kept `mark` px of the sheet inside it (its
-- face, its number and the crosses round it), the way in `door` px, each
-- point of the way through `way` px; the border is cut thinner on that
-- side where it must be.
local MARGIN = { mark = 36, door = 14, way = 8 }
DungeonMap.TRIM, DungeonMap.MARGIN = TRIM, MARGIN

-- The size `floor` comes out at inside `maxW` by `maxH`, its shape kept,
-- and the scale (px on the sheet per px, or yard, of its art).
function DungeonMap.Fit(floor, maxW, maxH)
    local s = math.min(maxW / floor.w, maxH / floor.h)
    return floor.w * s, floor.h * s, s
end

-- The pieces `floor` is printed from, in the floor's own units (px of its
-- art, or yards; y down): each { file, x0, y0, x1, y1, u0, u1, v0, v1,
-- piece }, a file showing u0..u1, v0..v1 of itself over that box, cut to
-- the floor's edge, and to `window` ({ x0, y0, x1, y1 } in the same
-- units) where given. `piece` is a combined map's piece it belongs to (by
-- index), feathered by that piece's mask; `masks` lists the masks' boxes,
-- in the same units. A combined map's backdrop comes first, under the
-- pieces. Pure arithmetic: the same floor gives the same pieces.
function DungeonMap.Pieces(floor, window)
    local out = { masks = {}, seam = floor and floor.yards and SEAM.yards or SEAM.tiles }
    if not floor then return out end
    local W, H = floor.w, floor.h
    local wx0, wy0 = window and window[1] or 0, window and window[2] or 0
    local wx1, wy1 = window and window[3] or W, window and window[4] or H

    -- A file over x, y, w by h, showing u0..u1, v0..v1 of it, cut to the
    -- box x0, y0, x1, y1 (the floor's, or a combined piece's).
    local function Add(file, x, y, w, h, u0, u1, v0, v1, bx0, by0, bx1, by1, piece)
        local ix0, iy0 = math.max(x, bx0, 0, wx0), math.max(y, by0, 0, wy0)
        local ix1, iy1 = math.min(x + w, bx1, W, wx1), math.min(y + h, by1, H, wy1)
        if not file or ix1 <= ix0 or iy1 <= iy0 then return end
        local function U(px) return u0 + (px - x) / w * (u1 - u0) end
        local function V(py) return v0 + (py - y) / h * (v1 - v0) end
        out[#out + 1] = { file = file, x0 = ix0, y0 = iy0, x1 = ix1, y1 = iy1,
            u0 = U(ix0), u1 = U(ix1), v0 = V(iy0), v1 = V(iy1), piece = piece }
    end

    if floor.combined then
        local c = floor.data
        local Floor = ns.Dungeons.Floor
        -- A crop of one tile stretched over the whole sheet, under the pieces.
        if c.bg then
            local sf = Floor(floor.instanceID, c.bg.floor)
            if sf and sf.tiles then
                local col, row = math.floor(c.bg.x0 / sf.tile) + 1, math.floor(c.bg.y0 / sf.tile) + 1
                local tx0, ty0 = (col - 1) * sf.tile, (row - 1) * sf.tile
                Add(sf.tiles[row] and sf.tiles[row][col], 0, 0, W, H,
                    (c.bg.x0 - tx0) / sf.tile, (c.bg.x1 - tx0) / sf.tile,
                    (c.bg.y0 - ty0) / sf.tile, (c.bg.y1 - ty0) / sf.tile, 0, 0, W, H)
            end
        end
        for pi, p in ipairs(c.pieces or {}) do
            local sf = Floor(floor.instanceID, p.floor)
            if sf and sf.tiles then
                out.masks[pi] = { x0 = p.dx, y0 = p.dy, x1 = p.dx + (p.x1 - p.x0) * p.s,
                    y1 = p.dy + (p.y1 - p.y0) * p.s }
                -- The crop, as far as the floor it is cut from reaches.
                local bx1 = p.dx + (math.min(p.x1, sf.w) - p.x0) * p.s
                local by1 = p.dy + (math.min(p.y1, sf.h) - p.y0) * p.s
                local T = sf.tile * p.s
                for r, rowTiles in ipairs(sf.tiles) do
                    for col, fid in ipairs(rowTiles) do
                        local x = p.dx + ((col - 1) * sf.tile - p.x0) * p.s
                        local y = p.dy + ((r - 1) * sf.tile - p.y0) * p.s
                        Add(fid, x, y, T, T, 0, 1, 0, 1, p.dx, p.dy, bx1, by1, pi)
                    end
                end
            end
        end
    elseif floor.yards then
        for _, tl in ipairs(floor.tiles or {}) do
            local size = tl[4] or 128
            Add(tl[1], tl[2], tl[3], size, size, 0, 1, 0, 1, 0, 0, W, H)
        end
    else
        local T = floor.tile
        for r, row in ipairs(floor.tiles or {}) do
            for c, file in ipairs(row) do
                Add(file, (c - 1) * T, (r - 1) * T, T, T, 0, 1, 0, 1, 0, 0, W, H)
            end
        end
    end
    out.window = { math.max(0, wx0), math.max(0, wy0), math.min(W, wx1), math.min(H, wy1) }
    return out
end

-- The part of `floor` the art is kept to, { x0, y0, x1, y1 } in its units:
-- all of it less its own border (TRIM), but on each side no more than
-- leaves every one of `points` (what is marked: { x, y, kind } in the
-- floor's units, `kind` "door" or "way" for the way in and a point of the
-- way through, else a boss) its MARGIN inside, at `scale` px of the sheet
-- per unit of the floor (the border is not cut at all where a point lies
-- closer to the art's edge than that).
function DungeonMap.Kept(floor, points, scale)
    local t = TRIM[floor.combined and "combined" or floor.yards and "yards" or floor.custom and "custom" or "tiles"]
    local x0, y0, x1, y1 = t * floor.w, t * floor.h, (1 - t) * floor.w, (1 - t) * floor.h
    for _, p in ipairs(points or {}) do
        local m = (MARGIN[p.kind or "mark"] or MARGIN.mark) / (scale or 1)
        x0, x1 = math.max(0, math.min(x0, p.x - m)), math.min(floor.w, math.max(x1, p.x + m))
        y0, y1 = math.max(0, math.min(y0, p.y - m)), math.min(floor.h, math.max(y1, p.y + m))
    end
    return { x0, y0, x1, y1 }
end

-- Where a point of floor `srcFloorID`'s art (x, y fractions of it) lies
-- when `floor` is printed in the box x, y, w by h on the sheet, or nil
-- when that point is not on the floor printed.
function DungeonMap.At(floor, x, y, w, h)
    return function(srcFloorID, px, py)
        if not floor then return nil end
        local fx, fy = ns.Dungeons.Point(floor, tonumber(srcFloorID), px, py)
        if not fx then return nil end
        return x + fx * w, y + fy * h
    end
end

-- A printer of floors on a loose sheet: `K` is its toolkit and `sheet` the
-- frame its masks are made on (UI/Paper/Sheet.lua). The art goes on
-- `layer` (BORDER 2, over the ground and under the grime along the folds),
-- a combined map's pieces a sublevel over its backdrop. Kept for the
-- tests: printer.pieces (pieces printed), printer.cuts (textures, after
-- the mesh cut them), printer.masked (by piece, its pool), printer.masks.
-- printer.masksTurn: whether a mask can turn with the sheet here.
function DungeonMap.Printer(K, sheet, layer, sublevel)
    local printer = { masks = {}, masked = {}, pieces = 0, cuts = 0 }
    layer, sublevel = layer or "BORDER", sublevel or 2
    printer.tiles = K.Pool(layer, sublevel)

    -- Whether the client can grey a texture part way (SetDesaturation) and
    -- turn a mask (SetRotation), asked once, under pcall: a build without
    -- a method may raise on it.
    local probe = K.Texture(layer, sublevel)
    local asked, fn = pcall(function() return probe.SetDesaturation end)
    printer.canDesaturate = asked and type(fn) == "function"
    probe:Hide()
    local mask = sheet:CreateMaskTexture()
    asked, fn = pcall(function() return mask.SetRotation end)
    printer.masksTurn = asked and type(fn) == "function"
    printer.masks[1] = mask

    -- A combined map's piece `pi`: its mask, and its own pool of tiles,
    -- which keep that mask for good, so no tile ever changes mask.
    local function Piece(pi)
        local m = printer.masks[pi]
        if not m then
            m = sheet:CreateMaskTexture()
            printer.masks[pi] = m
        end
        if not m.feathered then
            m:SetTexture(FEATHER, "CLAMPTOWHITE", "CLAMPTOWHITE")
            m.feathered = true
        end
        if not printer.masked[pi] then
            printer.masked[pi] = K.Pool(layer, sublevel + 1, function(t) t:AddMaskTexture(m) end)
        end
        return m, printer.masked[pi]
    end

    -- Prints `floor` into the box x, y, w by h of the sheet (its own shape:
    -- DungeonMap.Fit; the whole floor, though only `window` of it, in its
    -- units, is printed where given), toned by `look` ({ tint, desaturate,
    -- plain }: greyed part way and tinted where the client can, else tinted
    -- `plain`), each cut taking its facet's light. Returns DungeonMap.At
    -- for it. With no floor, nothing.
    function printer:Print(floor, x, y, w, h, look, window)
        self.pieces, self.cuts = 0, 0
        self.tiles:Begin()
        for _, pool in pairs(self.masked) do pool:Begin() end
        local list = DungeonMap.Pieces(floor, window)
        local s = floor and w / floor.w or 1
        for pi, box in pairs(list.masks) do
            local m = Piece(pi)
            m:Show()
            K.Place(m, x + box.x0 * s, y + box.y0 * s, (box.x1 - box.x0) * s, (box.y1 - box.y0) * s)
        end
        for pi, m in pairs(self.masks) do
            if not list.masks[pi] then m:Hide() end
        end
        local tint = look and (self.canDesaturate and look.tint or look.plain or look.tint) or { 1, 1, 1 }
        local grey = look and look.desaturate or 0
        for _, p in ipairs(list) do
            local pool = p.piece and select(2, Piece(p.piece)) or self.tiles
            local sx0, sy0 = x + p.x0 * s, y + p.y0 * s
            -- Over the next piece by a hair, but never past what is printed.
            local sx1 = x + p.x1 * s + (p.x1 < list.window[3] and list.seam or 0)
            local sy1 = y + p.y1 * s + (p.y1 < list.window[4] and list.seam or 0)
            local du, dv = (p.u1 - p.u0) / (sx1 - sx0), (p.v1 - p.v0) / (sy1 - sy0)
            self.pieces = self.pieces + 1
            K.Split(sx0, sy0, sx1, sy1, function(a, b, c, d, light)
                local t = pool:Next()
                t:SetTexture(p.file)
                t:SetTexCoord(p.u0 + (a - sx0) * du, p.u0 + (c - sx0) * du, p.v0 + (b - sy0) * dv, p.v0 + (d - sy0) * dv)
                t:SetVertexColor(tint[1] * light, tint[2] * light, tint[3] * light)
                if self.canDesaturate then t:SetDesaturation(grey) end
                K.Bend(t, a, b, c, d, true)
                self.cuts = self.cuts + 1
            end)
        end
        self.tiles:Finish()
        for _, pool in pairs(self.masked) do pool:Finish() end
        return DungeonMap.At(floor, x, y, w, h)
    end

    return printer
end
