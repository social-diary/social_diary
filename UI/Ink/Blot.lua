-- The map sheet's heat as ink blots (UI/Map/HeatSheet.lua): the arithmetic
-- alone.
--
-- Where you saw someone is a handful of cells; drawn one disc a cell, a
-- cluster reads as a pile of coins. Here the cells are melted into blots
-- instead, the way drops of ink run together on paper:
--   field    every cell is a soft round bump (a Gaussian, `sigma` px), as
--            strong as its weight; the bumps add up, so neighbours flow
--            into one another and a lone cell stays round
--   levels   each level is the ground where its field rises past its
--            `edge`. A level weighs the cells by how strong they are
--            (`from`, `full`: nothing at t = from, all at t = full), so the
--            first takes every cell and the deeper ones only where you
--            lingered; printed one over another, they darken into cores
--   outline  the field is sampled on a grid finer than the heat's own
--            (`step` px), clipped to the map's box, and its outline found
--            by marching squares, each crossing placed along its edge where
--            the field's logarithm would meet the edge, so it is a smooth
--            polygon and not a staircase
--   fill     each row of the grid is filled as runs: a run of cells wholly
--            inside is one quad, its ends slanted to where the outline
--            crosses the row, and only the odd cell where the outline turns
--            within the row is filled on its own (one or two quads). Pieces
--            meet edge to edge, every shared corner worked out once the
--            same way, so a level is one layer of ink, without the doubled
--            lines of overlap or the paper lines of gaps
--   rim      the outer outline, as a thin band just inside it (mitred, so
--            its pieces meet edge to edge too), its width wandering a
--            little: ink pooled where the blot dried
--   wobble   the field is read a little off each sample, pushed by a slow,
--            smooth wander (`warp` px over about `wave` px), so a lone blot
--            is not a compass circle. It is the field that wobbles, not the
--            pieces: moving their corners would open cracks where a long
--            run's edge meets the corners of the row next to it
--
-- The sheet folds and its facets take the light differently, so the grid
-- also has a line on every fold (`cutsX`, `cutsY`) and no piece crosses
-- one: each lies on one facet, to be lit with it.
--
-- Pure arithmetic over plain tables, no client calls: Build turns points in
-- sheet pixels into quads, each { x1, y1, x2, y2, x3, y3, x4, y4 } in the
-- order K.Quad takes (upper left, upper right, lower right, lower left: the
-- same turn as a box on the screen), a triangle repeating its last corner.
-- Tested off the client (tests/ink_blot.lua).

local addonName, ns = ...

local Blot = {}
ns.UI.InkBlot = Blot

-- A bump counts out to `reach` sigmas (it is under a 450th there). While
-- the whole would pass its cap, the grid is tried again coarser, at least
-- `growth` times, at most `tries` times in all. The rim's outline is
-- straightened where it strays under `straight` px from the line, its
-- width wanders by `wander` of itself over about `wave` px, and its miters
-- reach at most `miter` times its width.
local REACH, GROWTH, TRIES = 3.5, 1.4, 4
local RIM = { straight = 0.25, wander = 0.35, wave = 14, miter = 2 }

--------------------------------------------------------------------------
-- The grid

-- The samples from lo to hi: every `step` from `origin` (so blots made
-- separately still share their lines), both ends, and every cut between.
-- A sample nearer than a third of a step to a cut or an end gives way to
-- it. Returns the samples and which of them are cuts.
function Blot.Axis(lo, hi, origin, step, cuts)
    local fixed = { lo, hi }
    for _, c in ipairs(cuts or {}) do
        if c > lo and c < hi then fixed[#fixed + 1] = c end
    end
    local xs, isFixed = {}, {}
    for _, f in ipairs(fixed) do
        xs[#xs + 1] = f
        isFixed[f] = true
    end
    for k = math.ceil((lo - origin) / step), math.floor((hi - origin) / step) do
        local x, near = origin + k * step, false
        for _, f in ipairs(fixed) do
            if math.abs(x - f) < step / 3 then near = true; break end
        end
        if not near then xs[#xs + 1] = x end
    end
    table.sort(xs)
    local unique, isCut = {}, {}
    for _, x in ipairs(xs) do
        if #unique == 0 or x > unique[#unique] + 1e-6 then
            unique[#unique + 1] = x
            if isFixed[x] and x > lo and x < hi then isCut[#unique] = true end
        end
    end
    return unique, isCut
end

-- The first sample at or past v.
local function From(xs, v)
    local lo, hi = 1, #xs + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if xs[mid] < v then lo = mid + 1 else hi = mid end
    end
    return lo
end

-- How far the wobble pushes the point x, y: two slow waves across the
-- sheet for each way it pushes, in different directions and lengths, the
-- same at the same point every time.
function Blot.Push(x, y, amount, wave)
    local k = 2 * math.pi / wave
    local a = math.sin(k * (0.83 * x + 0.56 * y) + 1.3)
    local b = math.sin(k * (-0.41 * x + 0.91 * y) * 1.37 + 4.1)
    local c = math.sin(k * (0.97 * x - 0.24 * y) * 0.71 + 2.2)
    local d = math.sin(k * (0.19 * x + 0.98 * y) * 1.13 + 5.7)
    return amount * (0.55 * a + 0.45 * b), amount * (0.55 * c + 0.45 * d)
end

-- The field over the samples, F[j][i] at xs[i], ys[j]: each point's bump,
-- weighed. A bump is a product of one curve across and one down, so each
-- is worked out once per sample line. With a `warp` { px, wave }, each
-- sample reads the field where the wobble pushes it, one by one.
function Blot.Field(points, sigma, xs, ys, warp)
    local F = {}
    for j = 1, #ys do
        local row = {}
        for i = 1, #xs do row[i] = 0 end
        F[j] = row
    end
    local reach, k = REACH * sigma, -1 / (2 * sigma * sigma)
    local exp = math.exp
    local WX, WY
    if warp then
        local Push, amount, wave = Blot.Push, warp[1], warp[2]
        WX, WY = {}, {}
        for j = 1, #ys do
            local rx, ry, y = {}, {}, ys[j]
            for i = 1, #xs do
                local x = xs[i]
                local dx, dy = Push(x, y, amount, wave)
                rx[i], ry[i] = x + dx, y + dy
            end
            WX[j], WY[j] = rx, ry
        end
        reach = reach + warp[1]
    end
    for _, p in ipairs(points) do
        local w = p.w
        if w and w > 0 then
            local px, py = p.x, p.y
            local i0, i1 = From(xs, px - reach), From(xs, px + reach) - 1
            local j0, j1 = From(ys, py - reach), From(ys, py + reach) - 1
            if i0 <= i1 and j0 <= j1 then
                if WX then
                    for j = j0, j1 do
                        local row, rx, ry = F[j], WX[j], WY[j]
                        for i = i0, i1 do
                            local dx, dy = rx[i] - px, ry[i] - py
                            row[i] = row[i] + w * exp((dx * dx + dy * dy) * k)
                        end
                    end
                else
                    local across = {}
                    for i = i0, i1 do
                        local dx = xs[i] - px
                        across[i] = exp(dx * dx * k)
                    end
                    for j = j0, j1 do
                        local dy = ys[j] - py
                        local down, row = w * exp(dy * dy * k), F[j]
                        for i = i0, i1 do row[i] = row[i] + down * across[i] end
                    end
                end
            end
        end
    end
    return F
end

--------------------------------------------------------------------------
-- Pieces

-- Adds the quad to `out` in the screen's turn (upper left, upper right,
-- lower right, lower left, as a box would be: clockwise with y down),
-- unless it has no area.
local function Emit(out, x1, y1, x2, y2, x3, y3, x4, y4)
    local area = (x1 * y2 - x2 * y1) + (x2 * y3 - x3 * y2) + (x3 * y4 - x4 * y3) + (x4 * y1 - x1 * y4)
    if area > 1e-4 then
        out[#out + 1] = { x1, y1, x2, y2, x3, y3, x4, y4 }
    elseif area < -1e-4 then
        out[#out + 1] = { x1, y1, x4, y4, x3, y3, x2, y2 }
    end
end
Blot.Emit = Emit

-- A convex polygon { x, y, x, y, ... } as quads fanned from its first corner.
local function EmitPolygon(out, v)
    local n = #v / 2
    if n < 3 then return end
    local k = 2
    while k < n do
        local a, b = k, math.min(k + 1, n)
        local c = math.min(k + 2, n)
        Emit(out, v[1], v[2], v[2 * a - 1], v[2 * a], v[2 * b - 1], v[2 * b], v[2 * c - 1], v[2 * c])
        k = k + 2
    end
end

-- A cell's corners and edges, in the screen's turn from the upper left:
-- corner k runs along edge k to corner k + 1.
local CORNER = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }

-- The marching squares over one level: calls cell(i, j, polygons) for each
-- cell the outline passes through, where each polygon is a list of
-- vertices { x, y, key } (key set on a crossing: which edge of the grid it
-- lies on, the same from both cells that share the edge).
local function Crossings(F, xs, ys, edge)
    local NX = #xs

    -- Where the outline crosses the edge along row j from i to i + 1, and
    -- down column i from j to j + 1: always worked out in that direction, so
    -- the two cells sharing an edge agree to the last bit. The field is a
    -- sum of Gaussians, so its logarithm is nearly a parabola and far
    -- nearer straight between two samples than the field itself: the
    -- crossing is put where the logarithm's line meets the edge's, and a
    -- round blot stays round instead of turning into a polygon.
    local low, logEdge = 1e-9, math.log(edge)
    local function Part(a, b)
        local la, lb = math.log(math.max(a, low)), math.log(math.max(b, low))
        return (logEdge - la) / (lb - la)
    end
    local function Across(j, i)
        return xs[i] + (xs[i + 1] - xs[i]) * Part(F[j][i], F[j][i + 1]), ys[j], (j * NX + i) * 2
    end
    local function Down(j, i)
        return xs[i], ys[j] + (ys[j + 1] - ys[j]) * Part(F[j][i], F[j + 1][i]), (j * NX + i) * 2 + 1
    end

    -- The polygon of cell i, j inside the outline, in the screen's turn
    -- (and a second: a saddle's two triangles); a, b, c, d say which of its
    -- corners are inside (in CORNER's order). Each is a list of vertices { x, y, key } for the outline (Blot.Outline
    -- joins them by their keys), or, `flat`, the plain { x, y, x, y, ... }
    -- the fill fans into quads: the same corners and crossings either way,
    -- without a table a vertex where nobody reads the keys.
    -- (The helpers and `inside` are made once a level, not once a cell: a
    -- zone's stains ask this for thousands of cells a drawing.)
    local inside = {}
    local function Corner(list, i, j, k)
        local c = CORNER[k]
        list[#list + 1] = { xs[i + c[1]], ys[j + c[2]] }
    end
    local function Edge(list, i, j, k)
        local x, y, key
        if k == 1 then x, y, key = Across(j, i)
        elseif k == 2 then x, y, key = Down(j, i + 1)
        elseif k == 3 then x, y, key = Across(j + 1, i)
        else x, y, key = Down(j, i) end
        list[#list + 1] = { x, y, key }
    end
    local function FlatCorner(list, i, j, k)
        local c, n = CORNER[k], #list
        list[n + 1], list[n + 2] = xs[i + c[1]], ys[j + c[2]]
    end
    local function FlatEdge(list, i, j, k)
        local x, y
        if k == 1 then x, y = Across(j, i)
        elseif k == 2 then x, y = Down(j, i + 1)
        elseif k == 3 then x, y = Across(j + 1, i)
        else x, y = Down(j, i) end
        local n = #list
        list[n + 1], list[n + 2] = x, y
    end
    local function Polygons(i, j, a, b, c, d, flat)
        inside[1], inside[2], inside[3], inside[4] = a, b, c, d
        local CornerAt, EdgeAt = Corner, Edge
        if flat then CornerAt, EdgeAt = FlatCorner, FlatEdge end
        local saddle = (a and c and not b and not d) or (b and d and not a and not c)
        if saddle then
            local mid = (F[j][i] + F[j][i + 1] + F[j + 1][i] + F[j + 1][i + 1]) / 4
            if mid < edge then
                -- Two corners apart: one triangle each, edge k - 1 in, edge
                -- k out.
                local first, second
                for k = 1, 4 do
                    if inside[k] then
                        local triangle = {}
                        EdgeAt(triangle, i, j, (k + 2) % 4 + 1)
                        CornerAt(triangle, i, j, k)
                        EdgeAt(triangle, i, j, k)
                        if first then second = triangle else first = triangle end
                    end
                end
                return first, second
            end
        end
        local polygon = {}
        for k = 1, 4 do
            local nextK = k % 4 + 1
            if inside[k] then CornerAt(polygon, i, j, k) end
            if inside[k] ~= inside[nextK] then EdgeAt(polygon, i, j, k) end
        end
        return polygon
    end

    return Across, Down, Polygons
end

-- Which of a cell's corners are inside (a, b, c, d: in CORNER's order) is
-- read into locals by Fill and Outline, a row's two lines at a time, and
-- handed to Polygons only for the cells the outline passes through: most
-- cells are wholly in or wholly out, and a table for each was a quarter
-- of a full zone page's drawing.

-- The ground inside `edge` as quads: a row at a time, runs of whole cells
-- as one quad slanted at its ends, the cells the outline turns in on their
-- own. A run is broken at every cut (isCut), so no piece crosses a fold.
function Blot.Fill(F, xs, ys, edge, isCut, out)
    out = out or {}
    local Across, _, Polygons = Crossings(F, xs, ys, edge)
    local NX = #xs
    for j = 1, #ys - 1 do
        local y0, y1 = ys[j], ys[j + 1]
        local upper, lower = F[j], F[j + 1]
        local top, bottom -- where the open run starts, on the row's two lines
        -- (a cell's right corners are the next one's left)
        local b, c = upper[1] >= edge, lower[1] >= edge
        for i = 1, NX - 1 do
            local x0 = xs[i]
            if top and isCut and isCut[i] then
                Emit(out, top, y0, x0, y0, x0, y1, bottom, y1)
                top, bottom = x0, x0
            end
            local a, d = b, c
            b, c = upper[i + 1] >= edge, lower[i + 1] >= edge
            if a and b and c and d then
                if not top then top, bottom = x0, x0 end
            elseif b and c and not a and not d then
                -- The outline comes in across the row: a run starts.
                top, bottom = (Across(j, i)), (Across(j + 1, i))
            elseif a and d and not b and not c then
                -- It goes out across the row: the run ends.
                local x2, x3 = (Across(j, i)), (Across(j + 1, i))
                Emit(out, top or x0, y0, x2, y0, x3, y1, bottom or x0, y1)
                top, bottom = nil, nil
            else
                if top then
                    Emit(out, top, y0, x0, y0, x0, y1, bottom, y1)
                    top, bottom = nil, nil
                end
                if a or b or c or d then
                    local v, second = Polygons(i, j, a, b, c, d, true)
                    EmitPolygon(out, v)
                    if second then EmitPolygon(out, second) end
                end
            end
        end
        if top then Emit(out, top, y0, xs[NX], y0, xs[NX], y1, bottom, y1) end
    end
    return out
end

-- The outline at `edge` as lines of points { x, y, x, y, ... }, the inside
-- on their right as they run (with y down), and whether each closes on
-- itself. Where the ground meets the grid's border there is no outline:
-- a line ends there.
function Blot.Outline(F, xs, ys, edge)
    local _, _, Polygons = Crossings(F, xs, ys, edge)
    local starts, ends, all = {}, {}, {}
    local NX = #xs
    for j = 1, #ys - 1 do
        local upper, lower = F[j], F[j + 1]
        local b, c = upper[1] >= edge, lower[1] >= edge
        for i = 1, NX - 1 do
            local a, d = b, c
            b, c = upper[i + 1] >= edge, lower[i + 1] >= edge
            if (a or b or c or d) and not (a and b and c and d) then
                local polygon, second = Polygons(i, j, a, b, c, d)
                while polygon do
                    local n = #polygon
                    for k = 1, n do
                        local p, q = polygon[k], polygon[k % n + 1]
                        if p[3] and q[3] then
                            local segment = { p, q }
                            starts[p[3]] = segment
                            ends[q[3]] = segment
                            all[#all + 1] = segment
                        end
                    end
                    polygon, second = second, nil
                end
            end
        end
    end

    local lines, used = {}, {}
    local function Follow(segment)
        local line = { segment[1][1], segment[1][2] }
        local first = segment[1][3]
        while segment and not used[segment] do
            used[segment] = true
            line[#line + 1], line[#line + 2] = segment[2][1], segment[2][2]
            if segment[2][3] == first then
                line.closed = true
                line[#line], line[#line - 1] = nil, nil
                break
            end
            segment = starts[segment[2][3]]
        end
        lines[#lines + 1] = line
    end
    -- Open lines from their starts first, then the loops.
    for _, segment in ipairs(all) do
        if not used[segment] and not ends[segment[1][3]] then Follow(segment) end
    end
    for _, segment in ipairs(all) do
        if not used[segment] then Follow(segment) end
    end
    return lines
end

-- A line with the points dropped that stray under `tolerance` from the
-- straight line between the points kept either side.
local function Straighten(line, tolerance)
    local n = #line / 2
    if n <= 2 then return line end
    local kept = { line[1], line[2] }
    local ax, ay = line[1], line[2]
    local i = 2
    while i <= n do
        -- Reach as far as the line stays within tolerance of a-to-there.
        local far = i
        for k = i + 1, n do
            local bx, by = line[2 * k - 1], line[2 * k]
            local dx, dy = bx - ax, by - ay
            local length = math.sqrt(dx * dx + dy * dy)
            local ok = length > 0
            if ok then
                for m = i, k - 1 do
                    local px, py = line[2 * m - 1], line[2 * m]
                    if math.abs((px - ax) * dy - (py - ay) * dx) / length > tolerance then ok = false; break end
                end
            end
            if not ok then break end
            far = k
        end
        kept[#kept + 1], kept[#kept + 2] = line[2 * far - 1], line[2 * far]
        ax, ay = line[2 * far - 1], line[2 * far]
        i = far + 1
    end
    kept.closed = line.closed
    return kept
end

-- The rim: a band `width` wide just inside each line (the inside is on
-- its right), mitred at its corners so its pieces meet edge to edge, its
-- width wandering along it, and kept inside `clip`.
function Blot.Rim(lines, width, clip, out)
    out = out or {}
    for _, raw in ipairs(lines) do
        local line = Straighten(raw, RIM.straight)
        local n = #line / 2
        if n >= 2 then
            local closed = line.closed and n >= 3
            local function P(k)
                if closed then k = (k - 1) % n + 1 end
                return line[2 * k - 1], line[2 * k]
            end
            -- Each piece's inward normal: right of the way it runs.
            local normals, along = {}, { 0 }
            local pieces = closed and n or n - 1
            for k = 1, pieces do
                local x1, y1 = P(k)
                local x2, y2 = P(k + 1)
                local dx, dy = x2 - x1, y2 - y1
                local length = math.sqrt(dx * dx + dy * dy)
                if length < 1e-9 then length = 1e-9 end
                normals[k] = { -dy / length, dx / length }
                along[k + 1] = along[k] + length
            end
            -- At each point, the miter between the pieces either side,
            -- the width wandering with the distance along the line.
            local inner = {}
            for k = 1, n do
                local before = normals[k - 1] or (closed and normals[pieces])
                local after = normals[k] or before
                before = before or after
                local mx, my = before[1] + after[1], before[2] + after[2]
                local m = math.sqrt(mx * mx + my * my)
                if m < 1e-6 then mx, my, m = after[1], after[2], 1 end
                mx, my = mx / m, my / m
                local s = along[k] / RIM.wave
                local w = width * (1 + RIM.wander * (0.6 * math.sin(s * 2.1 + raw[1] * 0.37) + 0.4 * math.sin(s * 5.3 + raw[2] * 0.53)))
                local reach = w / math.max(mx * after[1] + my * after[2], 1 / RIM.miter)
                local x, y = P(k)
                local ix, iy = x + mx * reach, y + my * reach
                if clip then
                    ix = math.max(clip[1], math.min(clip[3], ix))
                    iy = math.max(clip[2], math.min(clip[4], iy))
                end
                inner[k] = { ix, iy }
            end
            for k = 1, pieces do
                local x1, y1 = P(k)
                local x2, y2 = P(k + 1)
                local a, b = inner[k], inner[closed and (k % n + 1) or (k + 1)]
                Emit(out, x1, y1, x2, y2, b[1], b[2], a[1], a[2])
            end
        end
    end
    return out
end

--------------------------------------------------------------------------
-- The whole

-- How much a point weighs on a level: nothing at t = from, all at t = full.
function Blot.Weight(level, t)
    if level.full <= level.from then return t >= level.full and 1 or 0 end
    return math.max(0, math.min(1, (t - level.from) / (level.full - level.from)))
end

-- points: { { x, y, t }, ... } in sheet px, t the cell's strength (0..1).
-- levels: { { sigma, edge, from, full }, ... }, sigma in px. opts: `step`
-- (px), `clip` { x0, y0, x1, y1 }, `cutsX`, `cutsY` (the folds), `rim` (its
-- width in px, or nil for none) and `cap` (the most quads in all).
-- `warp` { px, wave } wobbles the lot. Returns { levels = { quads, ... },
-- rim = quads, count, step }.
function Blot.Build(points, levels, opts)
    local clip = opts.clip
    local step = opts.step
    local result
    for _ = 1, TRIES do
        result = { levels = {}, rim = {}, count = 0, step = step }
        for n, level in ipairs(levels) do
            local quads = {}
            result.levels[n] = quads
            local weighed, x0, y0, x1, y1 = {}, math.huge, math.huge, -math.huge, -math.huge
            for _, p in ipairs(points) do
                local w = Blot.Weight(level, p.t or 1)
                if w > 0 then
                    weighed[#weighed + 1] = { x = p.x, y = p.y, w = w }
                    x0, y0 = math.min(x0, p.x), math.min(y0, p.y)
                    x1, y1 = math.max(x1, p.x), math.max(y1, p.y)
                end
            end
            local pad = REACH * level.sigma + (opts.warp and opts.warp[1] or 0)
            x0, y0, x1, y1 = math.max(clip[1], x0 - pad), math.max(clip[2], y0 - pad),
                math.min(clip[3], x1 + pad), math.min(clip[4], y1 + pad)
            if #weighed > 0 and x1 > x0 and y1 > y0 then
                local xs, cutX = Blot.Axis(x0, x1, clip[1], step, opts.cutsX)
                local ys = Blot.Axis(y0, y1, clip[2], step, opts.cutsY)
                local F = Blot.Field(weighed, level.sigma, xs, ys, opts.warp)
                Blot.Fill(F, xs, ys, level.edge, cutX, quads)
                if n == 1 and opts.rim then
                    Blot.Rim(Blot.Outline(F, xs, ys, level.edge), opts.rim, clip, result.rim)
                end
            end
            result.count = result.count + #quads
        end
        result.count = result.count + #result.rim
        if not opts.cap or result.count <= opts.cap then break end
        -- The pieces go about as the step to the power -0.8 (the rows and
        -- the outline's length, less the runs that stay one piece). Coarser
        -- by as much, and a little more.
        step = step * math.max(GROWTH, (result.count / opts.cap) ^ 1.25 * 1.05)
    end
    return result
end
