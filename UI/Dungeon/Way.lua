-- Your own way through a run, drawn on its map (.claude/dungeon-visits-
-- prd.md §19, WAY-6 to WAY-13): a pencil lying on a slip of paper over the
-- map sheet's top edge (UI/Dungeon/Sheet.lua), and the pen on the map while
-- it is taken up. What each edit does is Core/DungeonWay.lua's (the pen);
-- this is only where the clicks go and what is drawn while drawing.
--
-- The slip (SLIP): a slip of the diary's own page lying across the sheet's
-- top edge near its right corner, most of it over the table, its foot
-- `onto` px over the paper, turned a little more than the sheet, so it
-- reads as something laid on it, not printed. It slides along the edge to
-- the first place where it covers no face, number or way in (and stays on
-- the screen). At rest a short pencil lies on it, sticking out past its
-- left end, and beside it "Adjust Path": the whole slip is the button.
-- Taken up, the pencil leaves the slip, and the slip is the drawing's:
-- a heading and what is selected, a row of plain words to press (Done
-- boxed in ink, the rest underlined on hover, Clear and Reset set apart in
-- red-brown after a rule), and two lines in pencil saying how to draw.
--
-- The pen on the map (PEN): while the pencil is up, the layout of the sheet
-- is frozen (its kept part, scale and size: a point added near the edge
-- would otherwise resize the paper under the mouse), the way is drawn
-- straight from point to point in pencil over the print, as a draft is
-- (the inked way is smoothed, which would not run through its handles),
-- with a handle on every point: a dot on a plain one, a small square on a
-- stop (its boss), a lozenge on a step (stairs, a door, a trigger); the
-- selected point ringed in red-brown, the cut marked with two strokes and
-- the part cut off in grey. The floor's stairs, doors and triggers show as
-- open lozenges to click. The strips step back (put away) and the marks'
-- tooltips with them: one frame over the paper takes every click and says
-- what is under the mouse in the tooltip. Only the way is drawn again
-- after an edit or as a point is dragged, never the whole sheet (WAY-17);
-- the sheet is laid again, its folds and size from the new way, when the
-- pen is put down: Done, another floor (taken up again on it), another
-- run, the run put away, the book shut (WAY-11).
--
-- The pen lives as long as the run is out (its undo with it, WAY-9).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local DungeonPage = ns.UI.DungeonPage
local Surface = ns.UI.Surface

-- The slip: turned `turn` degrees more than the sheet, its foot `onto` px
-- over the paper's top edge, its right end `inset` px in from the sheet's
-- top-right corner at first, slid left `step` px at a time to keep clear
-- of what is marked (at most to `inset` from the left corner), and kept
-- `edge` px inside the screen. Its stock and cut edge as the bookmark's
-- (UI/Dungeon/Spread.lua's BOOKMARK); `pad` px of paper round what is on
-- it. At rest `rest.h` tall, the pencil's room `rest.pencil` px at its
-- left. Taken up, its rows: the heading `head` px, the words to press
-- `row` px, each hint line `line` px, `gap` px between the rows; at least
-- `least` px wide, the hint wrapped to its width. It lies HEIGHT.way over
-- the paper, picked up HEIGHT.lifted more under the mouse at rest.
local SLIP = { turn = -1.2, onto = 12, inset = 40, step = 36, edge = 12, ink = 0.45, pad = 12,
    rest = { h = 30, pencil = 46 }, head = 16, row = 22, line = 14, gap = 5, least = 560,
    words = { gap = 9, rule = 14, box = { 7, 3 } } }
-- The pencil at rest: `len` px from the point to the eraser, `w` wide,
-- turned `turn` degrees on the slip, its point `out` px past the slip's
-- left end. Its painted body, the bared wood (`wood` px), the lead, the
-- brass ferrule (`ferrule` px) and the eraser (`eraser` px); its shadow
-- `shadow` px down and right.
local PENCIL = { len = 54, w = 7, turn = 7, out = 10, wood = 9, lead = 3, ferrule = 5, eraser = 6, shadow = 1.6,
    body = { 0.78, 0.55, 0.14 }, stripe = { 0.62, 0.42, 0.10 }, bare = { 0.88, 0.74, 0.54 },
    eraserInk = { 0.76, 0.40, 0.38 } }
-- The pen on the map: the way `width` px in chalk over a faint dark stroke
-- (Print.lua's CHALK), the part cut off in grey at `grey`; a jump to the far
-- end of a linked step dotted (`dash`, `space`). Handles: a dot `dot` px on
-- stock `halo` px across; a stop's square `stop`; a step's lozenge `step`;
-- the ring round the selected one `ring` px out, in `strokes` pieces. The
-- cut: two strokes `cut` px long across the first leg cut off. A marker to
-- click: an open lozenge `marker` px. The mouse finds a point within
-- `reach` px, a line within `leg`, a marker within `near`, a boss within
-- the mark's hover square (Print.lua's HOVER); a press that moves `drag`
-- px is a drag, redrawn at most every `every` seconds.
local PEN = { width = 1.6, grey = 0.45, dash = 4, space = 4, dot = 5, halo = 9, stop = 6, step = 7, ring = 8,
    strokes = 18, cut = 9, marker = 11, reach = 9, leg = 7, near = 10, drag = 3, every = 0.03 }
-- Over the sheet: the pen's ink over the marks and the strips, the frame
-- taking the clicks over that, the slip over both.
local LEVELS = { ink = 9, catcher = 20, slip = 30 }
DungeonPage.WAY = { SLIP = SLIP, PENCIL = PENCIL, PEN = PEN, LEVELS = LEVELS }

-- The words (plain and literal, as the user asked: no house voice here).
local WORDS = {
    adjust = "Adjust Path",
    adjustTip = { "Adjust Path", "Draw the way you went on this run. It starts from the usual way through." },
    adjustOwnTip = { "Adjust Path", "Change the path you drew for this run." },
    heading = "DRAWING YOUR PATH",
    hint = "Click the map to add a point. Click a boss to add a stop. Click stairs or a door to add a step. "
        .. "Ctrl-click a line to insert a point. Drag a point to move it. Right-click a point to delete it.",
    start = "Starting from the usual way through. Nothing is saved until you change something.",
    none = "No point selected. New points go at the end.",
    selected = "Point %d of %d selected. New points go after it.",
    cut = "The path is cut after point %d. Click a grey point to join it back up.",
    joined = "Joined the path back up.",
    joinedLeft = "Joined the path back up. Left out: %s.",
    full = "The path is full (at most %d points).",
    reset = "Reset the path for this run?\n\nThe path you drew is removed and the usual way through shows again."
        .. "\n\nThis cannot be undone.",
    resetButton = "Reset Path",
    buttons = {
        { key = "done", label = "Done", tip = "Stop drawing and keep the path." },
        { key = "undo", label = "Undo", tip = "Take back the last change." },
        { key = "previous", label = "Previous Point", tip = "Select the point before the selected one." },
        { key = "next", label = "Next Point", tip = "Select the point after the selected one." },
        { key = "delete", label = "Delete Point", tip = "Delete the selected point." },
        { key = "cut", label = "Cut Path Here", tip = "Cut the path after the selected point. The rest turns grey. "
            .. "Draw on from here, then click a grey point to join the path back up." },
        { key = "clear", label = "Clear", apart = true, tip = "Remove every point, to draw the path from the start." },
        { key = "reset", label = "Reset", apart = true, tip = "Remove the path you drew for this run and show the "
            .. "usual way through again." },
    },
    -- A marker by its kind, for the tooltip.
    kinds = { up = "Stairs up", down = "Stairs down", left = "Passage", right = "Passage", entrance = "Entrance",
        exit = "Exit", portal = "Portal", trigger = "Trigger" },
    step = "Click to add this step to the path.",
    stepLinked = "Click to add this step to the path, and its other end.",
    stop = "Click to add a stop at this boss.",
    point = "Point %d. Drag to move it. Right-click to delete it.",
    pointFixed = "Point %d. Right-click to delete it.",
    grey = "Click to join the path back up here.",
}
DungeonPage.WAY.WORDS = WORDS

--------------------------------------------------------------------------
-- The pieces, made the first time a run's map is laid
--------------------------------------------------------------------------

local Changed, Start, Stop, Press

-- The slip's words to press, each a button over a line of text (frames
-- cannot turn: the button's square goes where the word's middle lands).
local function Word(slip, spec)
    local b = CreateFrame("Button", nil, slip)
    b.key, b.spec = spec.key, spec
    b.label = Style.Text(b, spec.key == "done" and FONT.strong or FONT.body)
    b.label:SetText(spec.label)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.box = {}
    Style.Tooltip(b, function(self) return self.enabled and Style.TipList(spec.label, { spec.tip }) or nil end,
        "ANCHOR_TOP", function(self, on)
            self.hot = on and self.enabled
            if slip.Paint then slip:Paint() end
        end)
    b:SetScript("OnClick", function(self) if self.enabled then Press(slip.view, self.key) end end)
    return b
end

local function Tools(view)
    if view.way then return view.way end
    local S, K = view.sheet, view.K
    local way = { view = view, drawing = false }
    view.way = way

    -- The pen's ink, over the marks and the strips.
    local ink = CreateFrame("Frame", nil, S)
    ink:SetAllPoints()
    ink:SetFrameLevel(S:GetFrameLevel() + LEVELS.ink)
    ink:Hide()
    way.ink = ink
    way.pools = {
        under = K.Pool("ARTWORK", 0, nil, ink),
        line = K.Pool("ARTWORK", 1, nil, ink),
        marker = K.Pool("ARTWORK", 2, nil, ink),
        halo = K.Pool("OVERLAY", 0, nil, ink),
        handle = K.Pool("OVERLAY", 1, nil, ink),
        ring = K.Pool("OVERLAY", 2, nil, ink),
    }

    -- The frame that takes every click on the paper while the pen is out.
    local catcher = CreateFrame("Frame", nil, S)
    catcher:SetAllPoints()
    catcher:SetFrameLevel(S:GetFrameLevel() + LEVELS.catcher)
    catcher:EnableMouse(true)
    catcher:Hide()
    way.catcher = catcher

    -- The slip, a button at rest.
    local slip = CreateFrame("Button", nil, view)
    slip:SetFrameLevel(S:GetFrameLevel() + LEVELS.slip)
    slip:EnableMouse(true)
    slip.view = view
    slip:Hide()
    way.slip = slip
    local plane = Surface.New(slip)
    slip.plane = plane
    local probe = slip:CreateTexture(nil, "BACKGROUND")
    slip.canBend = probe.SetVertexOffset ~= nil
    probe:Hide()
    slip.textures = ns.UI.Pool.New(function()
        local t = slip:CreateTexture(nil, "ARTWORK")
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end)
    slip.title = Style.Text(slip, FONT.strong)
    slip.title:SetText(WORDS.adjust)
    slip.heading = Style.Text(slip, FONT.heading)
    slip.heading:SetText(WORDS.heading)
    slip.status = Style.Text(slip, FONT.pencilSmall)
    slip.hints = {}
    slip.buttons = {}
    for _, spec in ipairs(WORDS.buttons) do
        local b = Word(slip, spec)
        slip.buttons[#slip.buttons + 1] = b
        slip.buttons[spec.key] = b
    end
    Style.Tooltip(slip, function()
        if way.drawing then return nil end
        local own = view.visit and type(view.visit.route) == "table"
        local tip = own and WORDS.adjustOwnTip or WORDS.adjustTip
        return Style.TipList(tip[1], { tip[2] })
    end, "ANCHOR_TOP", function(self, on)
        self.lifted = on and not way.drawing
        if self.Paint then self:Paint() end
    end)
    slip:SetScript("OnClick", function() if not way.drawing then Start(view) end end)

    -- The mouse on the paper.
    catcher:SetScript("OnMouseDown", function(_, button) DungeonPage.WayClick(view, button) end)
    catcher:SetScript("OnMouseUp", function() DungeonPage.WayRelease(view) end)
    catcher:SetScript("OnLeave", function()
        way.hover = nil
        GameTooltip:Hide()
    end)
    local since = 0
    catcher:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < PEN.every then return end
        since = 0
        DungeonPage.WayMove(view)
    end)
    return way
end

--------------------------------------------------------------------------
-- What lies where on the paper
--------------------------------------------------------------------------

-- The floors whose points can show on the floor printed: its own, or a
-- combined map's pieces'.
local function Sources(floor)
    if not floor then return {} end
    if not floor.combined then return { floor.uiMapID } end
    local list, seen = {}, {}
    for _, p in ipairs(floor.data and floor.data.pieces or {}) do
        if not seen[p.floor] then
            seen[p.floor] = true
            list[#list + 1] = p.floor
        end
    end
    return list
end

-- The stairs, doors and triggers on the paper: each a marker as the pen
-- takes it ({ floor, x, y, kind, label, boss }) with where it lies on the
-- sheet (sx, sy).
local function Markers(view)
    local D, out = ns.Dungeons, {}
    local visit, floor = view.visit, view.floors and view.floors[view.floorIndex]
    if not (visit and floor and view.At) then return out end
    for _, f in ipairs(Sources(floor)) do
        for _, m in ipairs(D.Markers(visit.instanceID, f)) do
            local sx, sy = view.At(f, m.x, m.y)
            if sx then
                out[#out + 1] = { floor = f, x = m.x, y = m.y, kind = m.kind, label = m.label, boss = m.boss,
                    sx = sx, sy = sy, linked = D.LinkOf(visit.instanceID, f, m.x, m.y) ~= nil }
            end
        end
    end
    return out
end

-- The way's points on the sheet: { x, y } each, or false off the floor.
local function Placed(view, points)
    local pts, Where, id = {}, ns.DungeonWay.Where, view.visit.instanceID
    for i, p in ipairs(points) do
        local x, y = view.At(Where(id, p))
        pts[i] = x and { x, y } or false
    end
    return pts
end

-- The placer the pen's hit tests take (DungeonMap.At for the floor shown).
local function Place(view)
    return function(f, x, y) return view.At(f, x, y) end
end

-- What is under sheet point x, y while drawing, the first that answers:
-- a point of the way, a marker, a boss. { what = "point" | "marker" |
-- "boss", i, marker, mark }, or nil (bare paper).
local function Under(view, x, y)
    local way = view.way
    local pen = way.pen
    local points = pen:Points()
    local place = Place(view)
    local i = ns.DungeonWay.Hit(view.visit.instanceID, points, place, x, y, PEN.reach)
    if i then return { what = "point", i = i, p = points[i] } end
    local best, near = nil, PEN.near
    for _, m in ipairs(way.markers or {}) do
        local d = math.sqrt((m.sx - x) ^ 2 + (m.sy - y) ^ 2)
        if d <= near then best, near = m, d end
    end
    if best then return { what = "marker", marker = best } end
    local reach = DungeonPage.HOVER / 2 + 1
    for _, mark in ipairs(view.plan and view.plan.marks or {}) do
        if math.abs(mark.x - x) <= reach and math.abs(mark.y - y) <= reach then
            return { what = "boss", mark = mark }
        end
    end
end
DungeonPage.WayUnder = Under

--------------------------------------------------------------------------
-- The pen's drawing on the map
--------------------------------------------------------------------------

-- A ring of strokes round x, y, `r` px.
local function Ring(P, pool, x, y, r, width, c, a)
    local n = PEN.strokes
    for k = 0, n - 1 do
        local a1, a2 = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi
        P.Stroke(pool, x + math.cos(a1) * r, y + math.sin(a1) * r, x + math.cos(a2) * r, y + math.sin(a2) * r,
            width, c, a)
    end
end

-- A line in chalk from a to b over its faint dark stroke, `dashed` or
-- whole, at alpha a.
local function Leg(P, pools, ax, ay, bx, by, a, dashed)
    local CHALK = DungeonPage.CHALK
    local o, U = CHALK.under.offset, CHALK.under
    local function Piece(x1, y1, x2, y2)
        P.Stroke(pools.under, x1 + o, y1 + o, x2 + o, y2 + o, PEN.width, Style.INK, U.alpha * a)
        P.Stroke(pools.line, x1, y1, x2, y2, PEN.width, CHALK.colour, a)
    end
    if not dashed then return Piece(ax, ay, bx, by) end
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then return end
    local t = 0
    while t < len do
        local e = math.min(len, t + PEN.dash)
        Piece(ax + dx * t / len, ay + dy * t / len, ax + dx * e / len, ay + dy * e / len)
        t = e + PEN.space
    end
end

-- The way as it stands, its handles, the floor's markers; kept for the
-- tests as way.drawn = { points, pts, legs, handles, markers, ring, cut }.
local function Redraw(view)
    local way = view.way
    local P, pools, pen = view.placer, way.pools, way.pen
    local stock = view.paper or Style.PAPER
    for _, pool in pairs(pools) do pool:Begin() end
    local points = pen:Points()
    local pts = Placed(view, points)
    local gap = pen:Gap()
    local drawn = { points = #points, pts = pts, legs = 0, handles = 0, markers = 0 }

    -- The floor's markers, open lozenges to click.
    for _, m in ipairs(way.markers or {}) do
        local s = PEN.marker
        P.Lozenge(pools.marker, m.sx, m.sy, s + 3, stock, 0.55)
        local h = s / 2 * math.sqrt(0.5)
        local corners = { { m.sx, m.sy - s / 2 * 1.1 }, { m.sx + s / 2 * 1.1, m.sy }, { m.sx, m.sy + s / 2 * 1.1 },
            { m.sx - s / 2 * 1.1, m.sy } }
        for k = 1, 4 do
            local a, b = corners[k], corners[k % 4 + 1]
            P.Stroke(pools.marker, a[1], a[2], b[1], b[2], 1.3, Style.RUBRIC, 0.85)
        end
        P.Dot(pools.marker, m.sx, m.sy, h, Style.RUBRIC, 0.85)
        drawn.markers = drawn.markers + 1
    end

    -- The legs: straight, the part cut off grey, a jump dotted, none
    -- across the cut itself.
    for i = 1, #points - 1 do
        local a, b = pts[i], pts[i + 1]
        if a and b and not (gap and i + 1 == gap) then
            local grey = gap and i >= gap
            Leg(P, pools, a[1], a[2], b[1], b[2], grey and PEN.grey or 0.95, points[i + 1].pair)
            drawn.legs = drawn.legs + 1
        end
    end
    -- The cut: two short strokes across the first leg cut off, near its start.
    if gap and pts[gap - 1] and pts[gap] then
        local a, b = pts[gap - 1], pts[gap]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
        local ux, uy = dx / len, dy / len
        local at = math.min(len / 2, 14)
        for k = 0, 1 do
            local cx, cy = a[1] + ux * (at + k * 4), a[2] + uy * (at + k * 4)
            local h = PEN.cut / 2
            -- Slanted across the leg.
            local nx, ny = -uy + ux * 0.5, ux + uy * 0.5
            P.Stroke(pools.ring, cx - nx * h, cy - ny * h, cx + nx * h, cy + ny * h, 1.6, Style.ACCENT, 0.95)
        end
        drawn.cut = { a[1] + ux * at, a[2] + uy * at }
    end

    -- The handles.
    for i, p in ipairs(points) do
        local q = pts[i]
        if q then
            local grey = gap and i >= gap
            local c, a = grey and Style.GRAPHITE or Style.INK_STRONG, grey and 0.6 or 0.95
            P.Dot(pools.halo, q[1], q[2], PEN.halo, stock, 0.8)
            if p.boss then
                P.Rect(pools.handle, q[1] - PEN.stop / 2, q[2] - PEN.stop / 2, PEN.stop, PEN.stop, c, a)
            elseif p.kind then
                P.Lozenge(pools.handle, q[1], q[2], PEN.step * 0.72, c, a)
            else
                P.Dot(pools.handle, q[1], q[2], PEN.dot, c, a)
            end
            drawn.handles = drawn.handles + 1
        end
    end
    -- The selected point ringed.
    local at = pen.at and pts[pen.at]
    if at then
        Ring(P, pools.ring, at[1], at[2], PEN.ring, 1.4, Style.ACCENT, 0.95)
        drawn.ring = pen.at
    end
    for _, pool in pairs(pools) do pool:Finish() end
    way.drawn = drawn
end
DungeonPage.WayRedraw = Redraw

--------------------------------------------------------------------------
-- The slip
--------------------------------------------------------------------------

-- A rectangle of the slip (from its middle, y down), turned with it.
local function Rect(slip, layer, sub, lx, ly, w, h, c, a, more)
    local t = slip.textures:Next()
    Surface.Unbend(t)
    t:SetTexture(nil)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetDrawLayer(layer, sub)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    slip.plane.Place(t, lx, ly, w, h, more)
    return t
end

-- The pencil lying on the slip at rest, its point at lx, ly (from the
-- slip's middle, y down), turned PENCIL.turn more than the slip.
local function Pencil(slip, lx, ly)
    local m = math.rad(PENCIL.turn)
    -- Along the pencil, on the slip (y down: a turn the other way round to
    -- the clock on the screen lifts the far end).
    local ux, uy = math.cos(m), -math.sin(m)
    local function Piece(from, to, width, c, a, dx, dy, sub)
        local mid = (from + to) / 2
        Rect(slip, "ARTWORK", sub or 2, lx + ux * mid + (dx or 0), ly + uy * mid + (dy or 0), to - from, width, c, a, m)
    end
    local L, W = PENCIL.len, PENCIL.w
    local s = PENCIL.shadow
    -- Its shadow on the slip.
    Piece(PENCIL.wood * 0.5, L, W, Style.INK, 0.28, s, s, 0)
    -- The bared wood and the lead: a cone where corners move, else a stub.
    local function Cone(from, to, wFrom, wTo, c, sub)
        local t = slip.textures:Next()
        Surface.Unbend(t)
        t:SetTexture(nil)
        t:SetVertexColor(1, 1, 1, 1)
        t:SetDrawLayer("ARTWORK", sub)
        t:SetColorTexture(c[1], c[2], c[3], 1)
        local nx, ny = -uy, ux
        local function At(d, half) return lx + ux * d + nx * half, ly + uy * d + ny * half end
        local x1, y1 = At(from, -wFrom / 2)
        local x2, y2 = At(to, -wTo / 2)
        local x3, y3 = At(to, wTo / 2)
        local x4, y4 = At(from, wFrom / 2)
        if not slip.plane.Quad(t, x1, y1, x2, y2, x3, y3, x4, y4) then
            local mid = (from + to) / 2
            slip.plane.Place(t, lx + ux * mid, ly + uy * mid, to - from, (wFrom + wTo) / 2, m)
        end
    end
    Cone(0, PENCIL.wood, 0.6, W, PENCIL.bare, 2)
    Cone(0, PENCIL.lead, 0.4, W * PENCIL.lead / PENCIL.wood, Style.INK_STRONG, 3)
    local f0 = L - PENCIL.eraser - PENCIL.ferrule
    -- The painted body, a darker facet along its lower side.
    Piece(PENCIL.wood, f0, W, PENCIL.body, 1, 0, 0, 2)
    local nx, ny = -uy, ux
    Piece(PENCIL.wood, f0, W * 0.32, PENCIL.stripe, 1, nx * W * 0.3, ny * W * 0.3, 3)
    Piece(PENCIL.wood, f0, W * 0.18, Style.BRASS_LIGHT, 0.35, -nx * W * 0.25, -ny * W * 0.25, 3)
    -- The ferrule and the eraser.
    Piece(f0, f0 + PENCIL.ferrule, W + 0.6, Style.BRASS_MID, 1, 0, 0, 2)
    Piece(f0 + PENCIL.ferrule, L, W - 0.4, PENCIL.eraserInk, 1, 0, 0, 2)
end

-- A word on the slip, its middle at lx, ly: the button over it.
local function PlaceWord(slip, b, lx, ly, w)
    local plane = slip.plane
    local h = 14
    plane.Place(b.label, lx, ly, w + 2, h + 2)
    local X, Y = plane.Screen(lx, ly)
    b:ClearAllPoints()
    b:SetPoint("CENTER", slip, "CENTER", X, Y)
    b:SetSize(w + 8, h + 8)
    b.lx, b.ly, b.w = lx, ly, w
    b:Show()
end

-- The slip drawn as it lies now: at rest (`lifted` under the mouse) or the
-- drawing's, each word inked as it can be pressed or not.
local function Paint(slip)
    local view = slip.view
    local way = view.way
    local drawing = way.drawing
    local turn = slip.turn or 0
    slip.plane.Set(turn, 0, 0, slip.canBend and ns.Setting("flatSheets") ~= true)
    slip.textures:Begin()
    local W, H = slip.w, slip.h
    -- Its shadows: on the paper and the world under it, from its height.
    local Hh = DungeonPage.HEIGHT
    local height = Hh.way + (slip.lifted and Hh.lifted or 0)
    local layers, colour = DungeonPage.Cast(height, "world")
    for _, L in ipairs(layers) do
        local g = L[3]
        Rect(slip, "BACKGROUND", -8, L[1], L[2], W + 2 * g, H + 2 * g, colour, L[4])
    end
    -- The slip: its cut edge a hair out, the page's stock lit across.
    local I, Pp = Style.INK, Style.PAPER
    Rect(slip, "BORDER", -8, 0, 0, W + 1.2, H + 1.2, I, SLIP.ink)
    slip.paper = Rect(slip, "BORDER", -7, 0, 0, W, H, Pp, 1)
    if ns.Setting("flatSheets") ~= true then
        ns.UI.Light.Sheen(slip.paper, Rect(slip, "BORDER", -6, 0, 0, W, H, Pp, 1), Pp)
    end

    if not drawing then
        Pencil(slip, -W / 2 - PENCIL.out, 1)
        local c = slip.lifted and Style.INK_STRONG or Style.INK
        slip.title:SetTextColor(c[1], c[2], c[3])
        local tw = slip.titleW
        slip.plane.Place(slip.title, -W / 2 + SLIP.pad + SLIP.rest.pencil + tw / 2, 0.5, tw + 2, 16)
        slip.title:Show()
        if slip.lifted then
            Rect(slip, "ARTWORK", 4, -W / 2 + SLIP.pad + SLIP.rest.pencil + tw / 2, 9, tw, 1, Style.INK_STRONG,
                Style.HAIRLINE_HOT)
        end
        slip.heading:Hide()
        slip.status:Hide()
        for _, t in ipairs(slip.hints) do t:Hide() end
        for _, b in ipairs(slip.buttons) do b:Hide() end
        slip.textures:Finish()
        return
    end

    slip.title:Hide()
    local left, top = -W / 2 + SLIP.pad, -H / 2 + SLIP.pad
    -- The heading and what is selected.
    local hy = top + SLIP.head / 2
    local hw = (Surface.Width(slip.heading) or 0) + 2
    slip.plane.Place(slip.heading, left + hw / 2, hy, hw, SLIP.head)
    slip.heading:Show()
    slip.status:SetText(slip.statusText or "")
    local sw = (Surface.Width(slip.status) or 0) + 2
    slip.plane.Place(slip.status, left + hw + 14 + sw / 2, hy, sw, SLIP.head)
    slip.status:Show()

    -- The words to press.
    local ry = top + SLIP.head + SLIP.gap + SLIP.row / 2
    local x = left + SLIP.words.box[1]
    local G = SLIP.words.gap
    for k, b in ipairs(slip.buttons) do
        local w = (Surface.Width(b.label) or 0) + 2
        if b.spec.apart and not slip.buttons[k - 1].spec.apart then
            -- A rule before the two that take the drawing away.
            x = x + SLIP.words.rule / 2
            Rect(slip, "ARTWORK", 1, x, ry, 1, SLIP.row - 6, Style.INK_FADED, 0.6)
            x = x + SLIP.words.rule / 2 + G
        elseif k > 1 then
            -- A small lozenge between two words.
            Rect(slip, "ARTWORK", 1, x + G / 2, ry, 3, 3, Style.INK_FADED, 0.7, math.pi / 4)
            x = x + G
        end
        if k > 1 then x = x + G / 2 end
        PlaceWord(slip, b, x + w / 2, ry, w)
        local c
        if not b.enabled then
            c = Style.INK_FADED
            b.label:SetAlpha(0.5)
        else
            b.label:SetAlpha(1)
            c = b.spec.apart and Style.ACCENT or (b.hot or b.key == "done") and Style.INK_STRONG or Style.INK
        end
        b.label:SetTextColor(c[1], c[2], c[3])
        if b.key == "done" then
            -- Done boxed in ink, its own patch of darker stock.
            local bw, bh = w + 2 * SLIP.words.box[1], SLIP.row - 2
            local P2 = { Pp[1] * 0.9, Pp[2] * 0.86, Pp[3] * 0.78 }
            Rect(slip, "ARTWORK", 0, x + w / 2, ry, bw + 1.2, bh + 1.2, Style.INK_STRONG, b.hot and 0.95 or 0.7)
            Rect(slip, "ARTWORK", 1, x + w / 2, ry, bw, bh, b.hot and Pp or P2, 1)
            x = x + w + SLIP.words.box[1]
        else
            if b.hot then Rect(slip, "ARTWORK", 2, x + w / 2, ry + 8, w, 1, c, Style.HAIRLINE_HOT) end
            x = x + w
        end
    end

    -- How to draw, in pencil.
    local y = top + SLIP.head + SLIP.gap + SLIP.row + SLIP.gap + SLIP.line / 2
    for k, line in ipairs(slip.hintLines or {}) do
        local t = slip.hints[k]
        if not t then
            t = Style.Text(slip, FONT.pencilSmall)
            slip.hints[k] = t
        end
        t:SetText(line)
        local lw = (Surface.Width(t) or 0) + 2
        slip.plane.Place(t, left + lw / 2, y, lw, SLIP.line)
        t:Show()
        y = y + SLIP.line
    end
    for k = #(slip.hintLines or {}) + 1, #slip.hints do slip.hints[k]:Hide() end
    slip.textures:Finish()
end

-- The slip's size for how it lies now: w, h. Taken up, its hint wrapped.
local function Measure(slip, drawing)
    if not drawing then
        slip.titleW = (Surface.Width(slip.title) or 0) + 2
        return SLIP.pad + SLIP.rest.pencil + slip.titleW + SLIP.pad + 4, SLIP.rest.h
    end
    local row = SLIP.words.box[1] * 2
    for k, b in ipairs(slip.buttons) do
        row = row + (Surface.Width(b.label) or 0) + 2 + (k > 1 and SLIP.words.gap * 1.5 or 0)
        if b.spec.apart and not slip.buttons[k - 1].spec.apart then row = row + SLIP.words.rule end
    end
    local w = math.max(SLIP.least, row + 2 * SLIP.pad)
    -- The hint broken into lines as wide as the slip.
    local measure = slip.measure
    if not measure then
        measure = Style.Text(slip, FONT.pencilSmall)
        measure:Hide()
        slip.measure = measure
    end
    local lines, line = {}, ""
    for word in WORDS.hint:gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        measure:SetText(try)
        if line ~= "" and (Surface.Width(measure) or 0) > w - 2 * SLIP.pad then
            lines[#lines + 1] = line
            line = word
        else
            line = try
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    slip.hintLines = lines
    local h = 2 * SLIP.pad + SLIP.head + SLIP.gap + SLIP.row + SLIP.gap + #lines * SLIP.line
    return w, h
end

-- Where the slip lies on the sheet's top edge (SLIP), w by h: its middle
-- in the sheet's coordinates, and its box there. The first place along
-- the edge, from the right, where the part over the paper covers none of
-- `spots` ({ x, y, r }); else the one covering fewest. Kept on the screen.
local function Spot(view, w, h, spots)
    local K, W = view.K, view.w
    local cy = SLIP.onto - h / 2
    -- Down onto the paper as far as the screen's top asks.
    local lie, screen = view.lie or { 0, 0 }, view.screen
    local function Clamp(cx, y)
        if not screen then return cx, y end
        local top = screen.h / 2 - lie[2] - SLIP.edge
        local _, ya = K.Screen(cx - w / 2, y - h / 2)
        local _, yb = K.Screen(cx + w / 2, y - h / 2)
        local over = math.max(ya, yb) - top
        if over > 0 then y = y + over end
        local right = screen.w / 2 - lie[1] - SLIP.edge
        local xr = K.Screen(cx + w / 2, y + h / 2)
        if xr > right then cx = cx - (xr - right) end
        return cx, y
    end
    local best, fewest
    local x = W - SLIP.inset - w / 2
    local least = math.min(x, SLIP.inset + w / 2)
    while true do
        local cx, y = Clamp(x, cy)
        local box = { cx - w / 2, y - h / 2, cx + w / 2, y + h / 2 }
        local covered = 0
        for _, s in ipairs(spots) do
            if s.x + s.r > box[1] and s.x - s.r < box[3] and s.y + s.r > box[2] and s.y - s.r < box[4] then
                covered = covered + 1
            end
        end
        if not fewest or covered < fewest then best, fewest = { cx, y, box }, covered end
        if covered == 0 or x <= least then break end
        x = math.max(least, x - SLIP.step)
    end
    return best[1], best[2], best[3]
end

-- Lays the slip for how it lies now (Measure, Spot): its frame the turned
-- box's, its middle where the sheet puts it; view.wayKeep its box on the
-- sheet and its shadow's reach, for the strips to keep out from under.
local function Lay(view, spots)
    local way = view.way
    local slip = way.slip
    local w, h = Measure(slip, way.drawing)
    slip.w, slip.h = w, h
    local cx, cy, box = Spot(view, w, h, spots)
    slip.box = box
    local flat = ns.Setting("flatSheets") == true
    local angle = view.angle or 0
    slip.turn = angle + ((flat or not view.turnsText) and 0 or math.rad(SLIP.turn))
    local a = slip.turn
    local hw = (w * math.abs(math.cos(a)) + h * math.abs(math.sin(a))) / 2
    local hh = (w * math.abs(math.sin(a)) + h * math.abs(math.cos(a))) / 2
    slip:ClearAllPoints()
    slip:SetPoint("CENTER", view.sheet, "CENTER", view.K.Screen(cx, cy))
    slip:SetSize(2 * hw, 2 * hh)
    local reach = ns.UI.Light.Fall(DungeonPage.HEIGHT.way, true) + 4
    view.wayKeep = { box[1] - reach, box[2] - reach, box[3] + reach, box[4] + reach }
    slip.Paint = Paint
    slip:Show()
    Paint(slip)
end

-- What the slip must keep clear of: the faces, numbers and the way in,
-- and taken up, the way's points too.
local function Spots(view)
    local spots = {}
    for _, s in ipairs(view.plan and view.plan.spots or {}) do spots[#spots + 1] = s end
    local way = view.way
    if way and way.drawing and way.pen then
        for _, q in ipairs(Placed(view, way.pen:Points())) do
            if q then spots[#spots + 1] = { x = q[1], y = q[2], r = PEN.halo / 2 } end
        end
    end
    return spots
end

-- The words on the slip as the pen stands: which can be pressed, and
-- what is selected (or what just happened, `said`).
local function Status(view, said)
    local way = view.way
    local slip, pen = way.slip, way.pen
    local points = pen:Points()
    local n, at, gap = #points, pen.at, pen:Gap()
    local can = {
        done = true, undo = pen:CanUndo(), previous = n > 0, next = n > 0, delete = at ~= nil and points[at] ~= nil,
        cut = at ~= nil and points[at + 1] ~= nil and not gap, clear = n > 0 or not pen:Own(), reset = pen:Own(),
    }
    for _, b in ipairs(slip.buttons) do
        b.enabled = can[b.key] == true
        if not b.enabled then b.hot = false end
    end
    if said then
        slip.statusText = said
    elseif gap then
        slip.statusText = WORDS.cut:format(gap - 1)
    elseif at then
        slip.statusText = WORDS.selected:format(at, n)
    elseif not pen:Own() then
        slip.statusText = WORDS.start
    else
        slip.statusText = WORDS.none
    end
end

--------------------------------------------------------------------------
-- Taking the pencil up and putting it down
--------------------------------------------------------------------------

-- The pen out on what the sheet shows now: the inked way and the strips
-- put away, the clicks taken, the floor links kept over the frame that
-- takes them, the way drawn in pencil.
local function Take(view)
    local way = view.way
    for _, key in ipairs({ "route", "routeUnder" }) do
        local pool = view.pools[key]
        pool:Begin()
        pool:Finish()
    end
    DungeonPage.ClearNotes(view)
    view.wayKeep = nil
    way.markers = Markers(view)
    way.ink:Show()
    way.catcher:Show()
    for i = 1, view.links.used or 0 do
        local link = view.links[i]
        if link then link:SetFrameLevel(way.catcher:GetFrameLevel() + 1) end
    end
    Status(view)
    Lay(view, Spots(view))
    Redraw(view)
end

-- After an edit: the way drawn again, the slip's words with it (where it
-- lies stays: it does not move under the mouse while drawing).
Changed = function(view, said)
    local way = view.way
    Status(view, said)
    Redraw(view)
    way.slip:Paint()
end

-- Takes the pencil up on the run shown (WAY-7): the run's pen, made the
-- first time, kept while the run is out.
Start = function(view)
    local way = Tools(view)
    if way.drawing or not (view.visit and view.box) then return false end
    if not way.pen then way.pen = ns.DungeonWay.Pen(view.visit, DungeonPage.Wing(view.visit)) end
    way.drawing = true
    way.slip.lifted = false
    GameTooltip:Hide()
    Style.PlaySound("write")
    Take(view)
    return true
end

-- The pen's frames put away (the pen itself kept).
local function Lower(view)
    local way = view.way
    way.drawing, way.drag, way.hover = false, nil, nil
    way.catcher:Hide()
    way.ink:Hide()
    for _, pool in pairs(way.pools) do
        pool:Begin()
        pool:Finish()
    end
end

-- Done (WAY-11): a cut left open joined, the sheet laid again round the
-- new way, its strips back.
Stop = function(view)
    local way = view.way
    if not (way and way.drawing) then return false end
    if way.drag then way.pen:Drop() end
    way.pen:Finish()
    Lower(view)
    GameTooltip:Hide()
    view:Open(view.visit, view.guid)
    return true
end

-- A word on the slip pressed.
Press = function(view, key)
    local way = view.way
    local pen = way.pen
    if not (way.drawing and pen) then return end
    if key == "done" then return Stop(view) end
    if key == "undo" then
        pen:Undo()
    elseif key == "previous" then
        pen:Step(-1)
    elseif key == "next" then
        pen:Step(1)
    elseif key == "delete" then
        if pen.at then pen:Delete(pen.at) end
    elseif key == "cut" then
        if pen.at then pen:Cut(pen.at) end
    elseif key == "clear" then
        pen:Clear()
    elseif key == "reset" then
        -- It asks first (WAY-10); the popup raised over the spread's strata.
        local popup = ns.UI.Dialog.Confirm(WORDS.reset, function()
            if way.pen == pen then
                pen:Reset()
                if way.drawing then Changed(view) end
            end
        end, WORDS.resetButton)
        if type(popup) == "table" and popup.Raise then popup:Raise() end
        return
    end
    Changed(view)
end
DungeonPage.WayPress = Press

--------------------------------------------------------------------------
-- The mouse on the paper
--------------------------------------------------------------------------

-- A press on the paper (WAY-8): right on a point deletes it; Ctrl on a
-- line inserts a point there; on a grey point joins the way back; on a
-- point selects it (and a plain one is picked up to drag); on a marker
-- adds a step; on a boss a stop; anywhere else on the floor a point.
function DungeonPage.WayClick(view, button)
    local way = view.way
    if not (way and way.drawing) then return end
    local pen, K = way.pen, view.K
    local x, y = K.Cursor()
    local hit = Under(view, x, y)
    GameTooltip:Hide()
    if button == "RightButton" then
        if hit and hit.what == "point" and pen:Delete(hit.i) then Changed(view) end
        return
    end
    if IsControlKeyDown() then
        local leg = ns.DungeonWay.OnLeg(view.visit.instanceID, pen:Points(), Place(view), x, y, PEN.leg)
        local f, px, py = view.From(x, y)
        if leg and f then
            local i = pen:Insert(leg, f, px, py)
            if i then pen:Select(i) end
            Changed(view, not i and WORDS.full:format(ns.DungeonWay.MAX) or nil)
        end
        return
    end
    if hit and hit.what == "point" then
        local gap = pen:Gap()
        if gap and hit.i >= gap then
            local dropped = pen:Connect(hit.i)
            local said = dropped and (#dropped > 0 and WORDS.joinedLeft:format(table.concat(dropped, ", "))
                or WORDS.joined) or nil
            return Changed(view, said)
        end
        pen:Select(hit.i)
        if pen:Grab(hit.i) then way.drag = { i = hit.i, x = x, y = y, moved = false } end
        return Changed(view)
    end
    local done
    if hit and hit.what == "marker" then
        done = pen:AddStep(hit.marker)
    elseif hit and hit.what == "boss" then
        done = pen:AddStop(hit.mark.name)
    else
        local f, px, py = view.From(x, y)
        if not f then return end
        done = pen:Add(f, px, py)
    end
    Changed(view, not done and WORDS.full:format(ns.DungeonWay.MAX) or nil)
end

-- The press let go: a drag is one step to undo.
function DungeonPage.WayRelease(view)
    local way = view.way
    if not (way and way.drag) then return end
    way.drag = nil
    way.pen:Drop()
    Changed(view)
end

-- The mouse moving on the paper: a point dragged, else what is under it
-- said in the tooltip.
function DungeonPage.WayMove(view)
    local way = view.way
    if not (way and way.drawing) then return end
    local x, y = view.K.Cursor()
    local drag = way.drag
    if drag then
        if not drag.moved and math.abs(x - drag.x) + math.abs(y - drag.y) < PEN.drag then return end
        local f, px, py = view.From(x, y)
        if f and way.pen:MoveTo(drag.i, f, px, py) then
            drag.moved = true
            Redraw(view)
        end
        return
    end
    local hit = Under(view, x, y)
    local key = hit and (hit.what .. ":" .. (hit.i or (hit.marker and hit.marker.sx) or hit.mark.name)) or nil
    if key == way.hover then return end
    way.hover = key
    if not hit then return GameTooltip:Hide() end
    local title, line
    if hit.what == "point" then
        local gap = way.pen:Gap()
        title = hit.p.boss or (hit.p.kind and (hit.p.tag or WORDS.kinds[hit.p.kind])) or nil
        if gap and hit.i >= gap then
            line = WORDS.grey
        else
            line = ((hit.p.boss or hit.p.kind) and WORDS.pointFixed or WORDS.point):format(hit.i)
        end
        title = title or line
        if title == line then line = nil end
    elseif hit.what == "marker" then
        local m = hit.marker
        title = m.kind == "trigger" and m.label or WORDS.kinds[m.kind] or m.kind
        line = m.linked and WORDS.stepLinked or WORDS.step
    else
        local names = view.plan and view.plan.names or {}
        title, line = names[hit.mark.name] or hit.mark.name, WORDS.stop
    end
    GameTooltip:SetOwner(way.catcher, "ANCHOR_CURSOR")
    GameTooltip:SetText(title)
    if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
end

--------------------------------------------------------------------------
-- The sheet's hooks (UI/Dungeon/Sheet.lua, UI/Dungeon/Spread.lua)
--------------------------------------------------------------------------

-- Before the sheet is laid for `visit`: another run puts the pen down and
-- forgets it; the same run laid again (another floor, the screen changed)
-- joins an open cut and takes the pen up again after (WayAfter).
function DungeonPage.WayBefore(view, visit)
    local way = view.way
    if not way then return end
    if way.pen and way.pen.visit ~= visit then return DungeonPage.WayPutDown(view) end
    if way.drawing then
        if way.drag then
            way.drag = nil
            way.pen:Drop()
        end
        way.pen:Finish()
    end
end

-- As the sheet is laid, before its strips: the slip where it lies now, or
-- none where there is no map to draw on.
function DungeonPage.WayLaid(view)
    local way = Tools(view)
    view.wayKeep = nil
    if not (view.box and view.At) then
        if way.drawing then Lower(view) end
        way.slip:Hide()
        return
    end
    if not way.drawing then Lay(view, Spots(view)) end
end

-- After the sheet is laid: taken up again where the pen was out.
function DungeonPage.WayAfter(view)
    local way = view.way
    if way and way.drawing and view.box then Take(view) end
end

-- The run put away, or another laid: the pen put down, what it drew kept,
-- and forgotten (its undo with it).
function DungeonPage.WayPutDown(view)
    local way = view and view.way
    if not way then return end
    if way.pen then
        if way.drag then way.pen:Drop() end
        if way.drawing then way.pen:Finish() end
    end
    if way.drawing then Lower(view) end
    way.pen = nil
end

-- For the tests and the slip: take the pencil up, put it down (Done).
DungeonPage.WayStart, DungeonPage.WayDone = function(view) return Start(view) end,
    function(view) return Stop(view) end
