-- How the pad's focus and its buttons are drawn: the one file the look
-- lives in (.claude/controller-plan.md, decision 2; the chosen design,
-- .claude/ui-proposal/controller/headings/: words a+, box iii, prompts y).
--
-- No cursor. What the pad stands on shows in its own words: they turn red
-- (rubric) and bold, and the diary's pen draws a box round them. The
-- subheading of their group turns rubric too, as the timeline's day heading
-- is, its rule overlaid with a fading red of ours. The prompts are on a
-- slip of the diary's paper tucked under the cover's foot, in the book's
-- ink; the shoulder buttons sit beside the ribbons they turn.
--
--   Look.Mark(host, item, drawn)  the pad stands on item in host; `drawn`:
--                                 a press put it there, so the pen draws
--                                 the box in (Look.DRAW_ON_PRESS)
--   Look.Unmark(host, item)       every word given back as it was
--   Look.Step(host, item, dir)    a slider stepped "LEFT" / "RIGHT": its
--                                 chevron on that side flashes
--   Look.Legend(host, entries, under)  { { key, text }, ... } for host, or nil:
--                                 none. `under`, optional: function(w) →
--                                 { frame, x, y, level }, where the slip of
--                                 width w lies instead of under the cover:
--                                 its top left at x, y off frame's middle (y
--                                 up), tucked SLIP.tuck under that edge, at
--                                 frame level `level` (under the paper: the
--                                 run's map on the table, UI/Dungeon/Pad.lua)
--   Look.Hide(host)               everything of host's put away (the pad put down)
--
-- What an item may say, besides `frame` and `key` (UI/Pad/Focus.lua):
--   words     the FontString that takes the box; default frame.label, else
--             frame.title (a FontString). With none, the pen boxes the
--             frame itself and no words change
--   subhead   the subheading above it (a FontString, its rule as .rule);
--             default frame.group (UI/Settings/Kit.lua stamps it)
--   room      clear px left of the words, so the box holds back there (a
--             checkbox's tick box is 7 px away)
--   encloses  a region, or a list of regions, the box must hold too beside
--             the words: an ornament that leads them (Your Diary's level
--             rubric's paraph, cut by the box's left edge in the client, 8
--             Nov 2026). Measured on the screen (GetLeft ... GetBottom), a
--             turned texture by its turned corners; a region not laid out
--             yet is left out. Without it the box is the words' alone
--   adjust    { reading = FontString, nib = texture, scale = frame }: a
--             slider's; the reading turns rubric and bold, the nib red, a
--             chevron either side of the scale
--   clip      the frame the box is drawn on, if not host (a scroll child,
--             so the box is clipped with the words)
--   level     the least frame level the box is drawn at (default the
--             host's + 40): over a sheet laid on the book (the custom card's
--             slip, UI/Journey/CardPad.lua), which lies higher than that
--   ring      true: no words; the pen draws a ring round the frame instead
--             of a box (a mark on a plate: a pencil circle round a spot on
--             a map is what a reader draws by hand), in the same pen and red
--   outline   function() → { anchor = frame, corners = { {x, y} * 4 },
--             level = n }: a thing of paper (a plate, a margin card), its
--             corners on `anchor` (from its top left, y down; turned as it
--             lies). It is outlined in red with a slight red drop shadow
--             under it (OUTLINE), at frame level `level` (its own: the
--             shadow under it, the line over it), and no box is drawn
--   heading   with `outline`: its heading (a FontString), red while marked
--             (not bold: the outline carries it)
--   plain     true: the pen boxes the frame and its words stay as they are
--             (a tag chip filled in its own colour, where red would not read)
-- A legend entry may say `beside = { left, right }`: a pair of keys set
-- beside those two frames, with no words (LB / RB by the ribbons), and
-- `main = true`: the prompt for what the pad does to the boxed words, which
-- wears a small copy of the box (default: A, or the D-pad).
--
-- Only words of our own widgets are recoloured, and exactly what is changed
-- is saved and given back; a colour someone else set meanwhile is left as
-- it is. The font object is never swapped. Everything drawn is on frames of
-- our own: never a property of Blizzard's frames (taint, the plan's
-- override rule), and nothing on StaticPopup.

local addonName, ns = ...

local Pad = ns.UI.Pad
local Style = ns.Style

local Look = {}
Pad.Look = Look

-- The two switches the user may yet turn (7 Nov 2026).
Look.DRAW_ON_PRESS = true   -- the pen draws the box in on a press; false: it just appears
Look.DRAW_TIME = 0.2

local BOLD = 1              -- the same red as a shadow, 1 px right: the fonts have no bold cut
local THICK, PEN_ALPHA, CUT = 1.3, 0.88, 2.2  -- as Style.HandRing's line; the corners cut
local MAX_STROKES = 48
local RULE_RED = 0.40       -- the subheading's rule, red fading out
local SLIP = {
    paper = { 0.90, 0.84, 0.68 }, tuck = 10, height = 44, padL = 16, padR = 14,
    gap = 16, glyph = 16, glyphGap = 5, shadow = 6,
    right = -70,            -- in from the book's right edge
}
local KEYS = { size = 20, out = 14, down = 36 }  -- LB / RB beside the ribbons
-- A thing of paper's active state (the user, 7 Nov 2026: a red outline, a
-- slight red drop shadow, its heading red): the line `gap` px outside its
-- edges, `width` px of rubric at `alpha`; the shadow a crisp red copy of
-- its outline `drop` px down and to the right at `alpha`, and a softer one
-- `soft` px larger and further at `softAlpha`, both under the paper so
-- only their fringe shows past its bottom and right edges.
local OUTLINE = { gap = 2, width = 1.3, alpha = 0.9,
    shadow = { drop = { 1.5, 2 }, alpha = 0.22, soft = 2, softDrop = { 2.5, 3.5 }, softAlpha = 0.08 } }
Look.OUTLINE = OUTLINE
-- A mark's ring: `pad` px clear of its hover square's half side, going
-- round once and `over` more (a share of a turn), in `steps` strokes.
local RING = { pad = 2, over = 0.12, steps = 20, wobble = 0.05 }
local CHEVRON = { w = 5, h = 8, gap = 3, flash = 0.2, travel = 3 }

local parts = setmetatable({}, { __mode = "k" })
Look.parts = parts  -- (each host's pieces, read by tests/pad.lua)

local function R() return Style.RUBRIC end

local function IsWords(x)
    return type(x) == "table" and x.SetTextColor ~= nil and x.GetTextColor ~= nil
end

local function Same(a, b)
    for i = 1, #b do
        if math.abs((a[i] or 0) - b[i]) > 0.01 then return false end
    end
    return true
end

local function Seed(key)
    local n = 0
    for i = 1, #key do n = (n * 31 + key:byte(i)) % 100003 end
    return n
end

--------------------------------------------------------------------------
-- Red ink on words of ours, given back exactly
--------------------------------------------------------------------------

-- Rubric on `fs`, and bold where `bold`; returns what was there.
local function Rubricate(fs, bold)
    local r = R()
    local saved = { fs = fs, colour = { fs:GetTextColor() } }
    fs:SetTextColor(r[1], r[2], r[3], 1)
    if bold then
        saved.shadow = { fs:GetShadowColor() }
        saved.offset = { fs:GetShadowOffset() }
        fs:SetShadowColor(r[1], r[2], r[3], 1)
        fs:SetShadowOffset(BOLD, 0)
    end
    return saved
end

-- Given back: each part only if it still is ours (a widget that inked its
-- words meanwhile keeps its own).
local function GiveBack(saved)
    if not saved then return end
    local fs, r = saved.fs, R()
    if Same({ fs:GetTextColor() }, { r[1], r[2], r[3] }) then fs:SetTextColor(unpack(saved.colour)) end
    if saved.shadow then
        if Same({ fs:GetShadowColor() }, { r[1], r[2], r[3] }) then fs:SetShadowColor(unpack(saved.shadow)) end
        if Same({ fs:GetShadowOffset() }, { BOLD, 0 }) then fs:SetShadowOffset(unpack(saved.offset)) end
    end
end

--------------------------------------------------------------------------
-- The pen: straight strokes round a box, a little uneven, as Style.HandRing
--------------------------------------------------------------------------

-- The points the pen passes through round a box w x h (x right, y down from
-- its top left): it starts near the top left, goes round clockwise, its
-- corners cut, drifting outward as it goes, and runs on past where it began
-- without meeting it. The same `seed`, the same box.
local function PenPoints(w, h, seed)
    local Noise = Style.Noise
    local sx = math.min(10, w * 0.18)
    local ex = sx + math.min(16, w * 0.3)
    local legs = { { sx, 0, w, 0 }, { w, 0, w, h }, { w, h, 0, h }, { 0, h, 0, 0 }, { 0, 0, ex, 0 } }
    local per = 2 * (w + h) + (ex - sx)
    local pts, k, run = {}, 0, 0
    for li, leg in ipairs(legs) do
        local dx, dy = leg[3] - leg[1], leg[4] - leg[2]
        local len = math.max(math.sqrt(dx * dx + dy * dy), 0.01)
        local ux, uy = dx / len, dy / len
        local nx, ny = uy, -ux  -- outward, going round clockwise with y down
        local cut = li > 1 and CUT or 0
        local cutEnd = li < #legs and CUT or 0
        local ax, ay = leg[1] + ux * cut, leg[2] + uy * cut
        local bx, by = leg[3] - ux * cutEnd, leg[4] - uy * cutEnd
        local n = math.max(2, math.floor(len / 30 + 0.5))
        for i = 0, n do
            local t = i / n
            local drift = -0.5 + 1.9 * (run + len * t) / per
            local jig = 0
            if not (li == 1 and i == 0) then
                k = k + 1
                jig = (Noise(seed + k * 1.7) - 0.5) * 1.3
            end
            local off = drift + jig + ((li == #legs and i == n) and -1.2 or 0)
            pts[#pts + 1] = { ax + (bx - ax) * t + nx * off, ay + (by - ay) * t + ny * off }
        end
        run = run + len
    end
    return pts
end

-- A frame of ours that the pen draws on: a pool of strokes, reshaped each
-- time (Style.Stroke's method: SetSize, SetPoint, SetRotation).
local function NewPen(parent)
    local pen = CreateFrame("Frame", nil, parent)
    pen.strokes = {}
    pen:Hide()
    return pen
end

local function Stroke(pen, i)
    local s = pen.strokes[i]
    if s then return s end
    local r = R()
    s = pen:CreateTexture(nil, "OVERLAY")
    s:SetColorTexture(r[1], r[2], r[3], PEN_ALPHA)
    if s.SetSnapToPixelGrid then
        s:SetSnapToPixelGrid(false)
        s:SetTexelSnappingBias(0)
    end
    pen.strokes[i] = s
    return s
end

-- Where textures cannot turn: four flat edges, the box plain.
local function FlatEdges(pen)
    if pen.flat then return pen.flat end
    local r = R()
    pen.flat = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = pen:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(r[1], r[2], r[3], PEN_ALPHA)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        pen.flat[i] = edge
    end
    return pen.flat
end

local function DrawIn(pen, elapsed)
    pen.t = pen.t + elapsed
    local p = math.min(pen.t / Look.DRAW_TIME, 1)
    p = 1 - (1 - p) ^ 3  -- the nib slows as it comes round
    local upTo = math.ceil(p * pen.count)
    for i = 1, pen.count do pen.strokes[i]:SetShown(i <= upTo) end
    if p >= 1 then pen:SetScript("OnUpdate", nil) end
end

-- The pen's box, w x h, its top left at the pen's: drawn in over
-- Look.DRAW_TIME where `drawIn`, else there at once.
local function PenBox(pen, w, h, seed, drawIn)
    pen:SetSize(w, h)
    pen:SetScript("OnUpdate", nil)
    local probe = Stroke(pen, 1)
    if not probe.SetRotation then
        for _, s in ipairs(pen.strokes) do s:Hide() end
        for _, edge in ipairs(FlatEdges(pen)) do edge:Show() end
        pen.count = 0
        pen:Show()
        return
    end
    if pen.flat then for _, edge in ipairs(pen.flat) do edge:Hide() end end
    local pts = PenPoints(w, h, seed)
    local n = math.min(#pts - 1, MAX_STROKES)
    for i = 1, n do
        local a, b = pts[i], pts[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local s = Stroke(pen, i)
        s:ClearAllPoints()
        s:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, THICK)
        s:SetPoint("CENTER", pen, "TOPLEFT", (a[1] + b[1]) / 2, -(a[2] + b[2]) / 2)
        s:SetRotation(math.atan2(-dy, dx))
        s:SetShown(not drawIn)
    end
    for i = n + 1, #pen.strokes do pen.strokes[i]:Hide() end
    pen.count = n
    if drawIn then
        pen.t = 0
        pen:SetScript("OnUpdate", DrawIn)
    end
    pen:Show()
end

-- The pen's ring round a box `d` px square (its middle at d / 2, d / 2 from
-- the pen's top left): as Style.HandRing, uneven and not quite closing.
local function RingPoints(d, seed)
    local Noise = Style.Noise
    local pts, r = {}, d / 2
    local a0 = math.rad(200) + (Noise(seed) - 0.5) * 0.6
    local sweep = 2 * math.pi * (1 + RING.over)
    for i = 0, RING.steps do
        local t = a0 + sweep * i / RING.steps
        local grow = 1 + RING.wobble * math.sin(3 * t) + RING.wobble * i / RING.steps
        pts[#pts + 1] = { r + r * grow * math.cos(t), r + r * grow * math.sin(t) }
    end
    return pts
end

local function PenRing(pen, d, seed, drawIn)
    pen:SetSize(d, d)
    pen:SetScript("OnUpdate", nil)
    if pen.flat then for _, edge in ipairs(pen.flat) do edge:Hide() end end
    local probe = Stroke(pen, 1)
    if not probe.SetRotation then
        for _, s in ipairs(pen.strokes) do s:Hide() end
        for _, edge in ipairs(FlatEdges(pen)) do edge:Show() end
        pen.count = 0
        pen:Show()
        return
    end
    local pts = RingPoints(d, seed)
    local n = math.min(#pts - 1, MAX_STROKES)
    for i = 1, n do
        local a, b = pts[i], pts[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local s = Stroke(pen, i)
        s:ClearAllPoints()
        s:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, THICK)
        s:SetPoint("CENTER", pen, "TOPLEFT", (a[1] + b[1]) / 2, -(a[2] + b[2]) / 2)
        s:SetRotation(math.atan2(-dy, dx))
        s:SetShown(not drawIn)
    end
    for i = n + 1, #pen.strokes do pen.strokes[i]:Hide() end
    pen.count = n
    if drawIn then
        pen.t = 0
        pen:SetScript("OnUpdate", DrawIn)
    end
    pen:Show()
end

-- How much room round words of `size` px: more for a title than a label.
local function Pads(size)
    return math.floor(size * 0.34 + 0.5) + 2, math.floor(size * 0.12 + 0.5) + 1
end

-- Where the words' ink lies inside their FontString: x, y from its top
-- left (y down), and the ink's width and height.
local function Ink(fs, bold)
    local w = fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
    local box = fs:GetWidth() or 0
    if box > 0 then w = math.min(w, box) end
    local h = fs:GetStringHeight() or 0
    local x, y = 0, 0
    local justify = fs.GetJustifyH and fs:GetJustifyH()
    if box > w and justify == "RIGHT" then x = box - w elseif box > w and justify == "CENTER" then x = (box - w) / 2 end
    local tall = fs.GetHeight and fs:GetHeight() or 0
    local vertical = fs.GetJustifyV and fs:GetJustifyV()
    if tall > h and vertical ~= "TOP" then y = vertical == "BOTTOM" and tall - h or (tall - h) / 2 end
    return x, y, w + (bold and BOLD or 0), h
end

-- The box x, y, w, h (from fs's top left, y down) grown to hold each region
-- of `encloses` as it lies on the screen; as it was where none is laid out.
local function Enclose(fs, encloses, x, y, w, h)
    if type(encloses) ~= "table" then return x, y, w, h end
    -- (a list has a first; a region, a table of its own, has none)
    local list = rawget(encloses, 1) ~= nil and encloses or { encloses }
    local fl, ft = fs:GetLeft(), fs:GetTop()
    if not (fl and ft) then return x, y, w, h end
    local x0, y0, x1, y1 = x, y, x + w, y + h
    for _, r in ipairs(list) do
        local l, rt, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
        if l and rt and t and b and r:IsShown() then
            local cx, cy = (l + rt) / 2 - fl, ft - (t + b) / 2
            local hw, hh = (rt - l) / 2, (t - b) / 2
            -- (a turned texture: its rect is its unturned one; its corners
            -- turned reach further, a paraph's 45° by its half diagonal)
            local a = r.GetRotation and r:GetRotation() or 0
            if a ~= 0 then
                local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
                hw, hh = hw * c + hh * s, hw * s + hh * c
            end
            x0, x1 = math.min(x0, cx - hw), math.max(x1, cx + hw)
            y0, y1 = math.min(y0, cy - hh), math.max(y1, cy + hh)
        end
    end
    return x0, y0, x1 - x0, y1 - y0
end
Look.Enclose = Enclose

local function FontSize(fs, fallback)
    local size = fs.GetFont and select(2, fs:GetFont())
    return (type(size) == "number" and size > 0) and size or fallback
end

--------------------------------------------------------------------------
-- A host's parts
--------------------------------------------------------------------------

local function Over(host, parent, above)
    local f = CreateFrame("Frame", nil, parent or host)
    f:SetFrameLevel(host:GetFrameLevel() + (above or 40))
    f:Hide()
    return f
end

local function Parts(host)
    local p = parts[host]
    if p then return p end
    p = {}
    parts[host] = p
    p.pen = NewPen(host)
    p.pen:SetFrameLevel(host:GetFrameLevel() + 40)

    -- What lies over a widget's own pieces: the subheading's rule, a link's
    -- line, a slider's nib and its chevrons.
    p.over = Over(host)
    p.rule = p.over:CreateTexture(nil, "OVERLAY")
    p.line = p.over:CreateTexture(nil, "OVERLAY")
    p.line:SetHeight(1)
    p.nib = Style.Lozenge(p.over, "OVERLAY", 8, R(), 2)
    p.chevrons = {}
    for _, dir in ipairs({ "LEFT", "RIGHT" }) do
        local c = CreateFrame("Frame", nil, p.over)
        c:SetSize(CHEVRON.w, CHEVRON.h)
        c.dir = dir
        local t = c:CreateTexture(nil, "OVERLAY")
        local r = R()
        t:SetColorTexture(r[1], r[2], r[3], 0.9)
        local tip, back = dir == "LEFT" and 0 or CHEVRON.w, dir == "LEFT" and CHEVRON.w or 0
        local quad = Style.Quad(t, c, tip, CHEVRON.h / 2, back, 0, back, CHEVRON.h, tip, CHEVRON.h / 2)
        if not quad then t:SetSize(3, 3) end
        c.tex = t
        p.chevrons[dir] = c
    end
    return p
end

--------------------------------------------------------------------------
-- A thing of paper outlined: its line over it, its red shadow under it
--------------------------------------------------------------------------

local function Flat(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
    return texture
end

-- Two frames of ours a host keeps for it (made the first time a thing of
-- paper is marked): `line` (four strokes) and `shadow` (two quads).
local function Outline(host)
    local p = Parts(host)
    if p.outline then return p.outline end
    local o = {}
    o.line = CreateFrame("Frame", nil, host)
    o.line:SetSize(1, 1)
    o.line.strokes = {}
    local r = R()
    for i = 1, 4 do
        local t = Flat(o.line:CreateTexture(nil, "OVERLAY"))
        t:SetColorTexture(r[1], r[2], r[3], OUTLINE.alpha)
        o.line.strokes[i] = t
    end
    o.shadow = CreateFrame("Frame", nil, host)
    o.shadow:SetSize(1, 1)
    local sh = OUTLINE.shadow
    o.soft = Flat(o.shadow:CreateTexture(nil, "BACKGROUND", nil, 0))
    o.soft:SetColorTexture(r[1], r[2], r[3], sh.softAlpha)
    o.crisp = Flat(o.shadow:CreateTexture(nil, "BACKGROUND", nil, 1))
    o.crisp:SetColorTexture(r[1], r[2], r[3], sh.alpha)
    o.line:Hide()
    o.shadow:Hide()
    p.outline = o
    return o
end

-- `corners` pushed `by` px out from their middle, along each corner's
-- diagonal (a rectangle, turned a little: near enough an even margin).
local function Grown(corners, by, dx, dy)
    local mx, my = 0, 0
    for _, c in ipairs(corners) do mx, my = mx + c[1] / 4, my + c[2] / 4 end
    local out = {}
    for i, c in ipairs(corners) do
        local vx, vy = c[1] - mx, c[2] - my
        local len = math.max(math.sqrt(vx * vx + vy * vy), 0.01)
        local k = by * math.sqrt(2) / len
        out[i] = { c[1] + vx * k + (dx or 0), c[2] + vy * k + (dy or 0) }
    end
    return out
end

local function QuadOn(texture, frame, pts)
    local ok = Style.Quad(texture, frame, pts[1][1], pts[1][2], pts[2][1], pts[2][2], pts[3][1], pts[3][2],
        pts[4][1], pts[4][2])
    texture:Show()
    return ok
end

local function DrawOutline(host, o, spec)
    local anchor, corners = spec.anchor, spec.corners
    local level = spec.level or (anchor:GetFrameLevel() + 1)
    local sh = OUTLINE.shadow
    for _, f in ipairs({ o.line, o.shadow }) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    end
    o.shadow:SetFrameLevel(math.max(0, level - 1))
    o.line:SetFrameLevel(level + 4)
    QuadOn(o.crisp, o.shadow, Grown(corners, 0, sh.drop[1], sh.drop[2]))
    QuadOn(o.soft, o.shadow, Grown(corners, sh.soft, sh.softDrop[1], sh.softDrop[2]))
    local pts = Grown(corners, OUTLINE.gap)
    for i = 1, 4 do
        local a, b = pts[i], pts[i % 4 + 1]
        local t = o.line.strokes[i]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        t:ClearAllPoints()
        if t.SetRotation then
            t:SetSize(math.sqrt(dx * dx + dy * dy) + OUTLINE.width, OUTLINE.width)
            t:SetPoint("CENTER", o.line, "TOPLEFT", (a[1] + b[1]) / 2, -(a[2] + b[2]) / 2)
            t:SetRotation(math.atan2(-dy, dx))
        else
            -- (no turning: the box's flat edges)
            local horizontal = math.abs(dx) >= math.abs(dy)
            t:SetSize(horizontal and math.abs(dx) or OUTLINE.width, horizontal and OUTLINE.width or math.abs(dy))
            t:SetPoint("CENTER", o.line, "TOPLEFT", (a[1] + b[1]) / 2, -(a[2] + b[2]) / 2)
        end
        t:Show()
    end
    o.shadow:Show()
    o.line:Show()
end

--------------------------------------------------------------------------
-- The mark
--------------------------------------------------------------------------

local function WordsOf(item)
    if IsWords(item.words) then return item.words end
    local f = item.frame
    if f and IsWords(f.label) then return f.label end
    if f and IsWords(f.title) then return f.title end
end

function Look.Unmark(host)
    local p = parts[host]
    if not (p and p.marked) then return end
    local m = p.marked
    p.marked = nil
    -- (the pen still drawing in: where it was, for Mark to go on from)
    if p.pen:GetScript("OnUpdate") then
        p.resume, p.resumeKey = p.pen.t, p.drawnKey
    else
        p.resume, p.resumeKey = nil, nil
    end
    GiveBack(m.words)
    GiveBack(m.subhead)
    GiveBack(m.reading)
    GiveBack(m.heading)
    if p.outline then
        p.outline.line:Hide()
        p.outline.shadow:Hide()
    end
    p.pen:SetScript("OnUpdate", nil)
    p.pen:Hide()
    p.over:Hide()
    for _, c in pairs(p.chevrons) do c:SetScript("OnUpdate", nil) end
end

function Look.Mark(host, item, drawn)
    if not (host and item) then return end
    local p = Parts(host)
    -- (marked again while the pen is still drawing the same one in: a page
    -- refreshed more than once by one press, the People page's list and
    -- profile, goes on drawing, not at once and not from the start)
    Look.Unmark(host)
    local resume = drawn and p.resumeKey == tostring(item.key or "") and p.resume or nil
    p.resume, p.resumeKey = nil, nil
    local frame = item.frame
    local fs = not (item.ring or item.outline or item.plain) and WordsOf(item) or nil
    local anchor = fs or frame
    local spec = item.outline and item.outline()
    if not (anchor or spec) then return end

    local m = {}
    p.marked = m
    local r = R()
    local key = tostring(item.key or "")

    if spec and spec.anchor and spec.corners then
        -- A thing of paper: outlined, its shadow red, its heading red.
        DrawOutline(host, Outline(host), spec)
        if IsWords(item.heading) then m.heading = Rubricate(item.heading, false) end
        p.pen:SetScript("OnUpdate", nil)
        p.pen:Hide()
        p.drawnKey = key
    elseif item.ring and frame then
        -- A mark: the pen's ring round it.
        local d = math.max(frame:GetWidth() or 0, frame:GetHeight() or 0) + 2 * RING.pad
        local pen = p.pen
        pen:SetParent(item.clip or host)
        pen:SetFrameLevel(math.max(host:GetFrameLevel() + 40, (frame:GetFrameLevel() or 0) + 3))
        pen:ClearAllPoints()
        pen:SetPoint("TOPLEFT", frame, "CENTER", -d / 2, d / 2)
        local drawIn = drawn and Look.DRAW_ON_PRESS and key ~= p.drawnKey or resume ~= nil
        PenRing(pen, d, Seed(key), drawIn)
        if resume then pen.t = resume end
        p.drawnKey = key
    end

    -- The words: rubric and bold, boxed.
    local x, y, w, h, size
    if spec or item.ring then
        -- (outlined or ringed above: no box)
    elseif fs then
        m.words = Rubricate(fs, true)
        x, y, w, h = Ink(fs, true)
        size = FontSize(fs, h)
        if item.encloses then x, y, w, h = Enclose(fs, item.encloses, x, y, w, h) end
    else
        -- (no words of its own: the pen round the frame, nothing recoloured)
        x, y, w, h = 0, 0, frame:GetWidth() or 0, frame:GetHeight() or 0
        size = 13
    end
    if not (spec or item.ring) then
        local padX, padY = Pads(size)
        local padL = item.room and math.min(padX, item.room) or padX

        local pen = p.pen
        pen:SetParent(item.clip or host)
        pen:SetFrameLevel(math.max(host:GetFrameLevel() + 40, item.level or 0))
        pen:ClearAllPoints()
        pen:SetPoint("TOPLEFT", anchor, "TOPLEFT", x - padL, -y + padY)
        local drawIn = drawn and Look.DRAW_ON_PRESS and key ~= p.drawnKey or resume ~= nil
        PenBox(pen, w + padL + padX, h + 2 * padY, Seed(key), drawIn)
        if resume then pen.t = resume end
        p.drawnKey = key
    end

    -- Where it is: its subheading a rubric, the rule after it fading red.
    local any = false
    local subhead = item.subhead or (frame and frame.group)
    if IsWords(subhead) then
        m.subhead = Rubricate(subhead, false)
        local rule = subhead.rule
        if rule then
            p.rule:ClearAllPoints()
            p.rule:SetPoint("TOPLEFT", rule, "TOPLEFT")
            p.rule:SetPoint("BOTTOMRIGHT", rule, "BOTTOMRIGHT")
            Style.Shade(p.rule, "HORIZONTAL", r[1], r[2], r[3], RULE_RED, 0)
            p.rule:Show()
            any = true
        else
            p.rule:Hide()
        end
    else
        p.rule:Hide()
    end

    -- A link's line under its words: red laid over it.
    local line = frame and fs and fs == frame.label and frame.line
    if type(line) == "table" then
        p.line:ClearAllPoints()
        p.line:SetPoint("TOPLEFT", line, "TOPLEFT")
        p.line:SetPoint("TOPRIGHT", line, "TOPRIGHT")
        p.line:SetColorTexture(r[1], r[2], r[3], Style.HAIRLINE_HOT or 0.6)
        p.line:Show()
        any = true
    else
        p.line:Hide()
    end

    -- A slider: its reading rubric and bold, its nib red, a chevron either side.
    local adjust = item.adjust
    if adjust then
        if IsWords(adjust.reading) then m.reading = Rubricate(adjust.reading, true) end
        if adjust.nib then
            p.nib:ClearAllPoints()
            p.nib:SetPoint("CENTER", adjust.nib, "CENTER")
            p.nib:Show()
        else
            p.nib:Hide()
        end
        local left, right = p.chevrons.LEFT, p.chevrons.RIGHT
        local scale = adjust.scale or (adjust.nib and adjust.nib:GetParent())
        left.anchor = { "RIGHT", scale, "LEFT", -CHEVRON.gap }
        right.anchor = { "LEFT", adjust.reading or scale, "RIGHT", CHEVRON.gap }
        for _, c in pairs(p.chevrons) do
            c:SetScript("OnUpdate", nil)
            c:ClearAllPoints()
            if c.anchor[2] then c:SetPoint(c.anchor[1], c.anchor[2], c.anchor[3], c.anchor[4], 0) end
            c:SetAlpha(1)
            c:SetShown(c.anchor[2] ~= nil)
        end
        any = true
    else
        p.nib:Hide()
        for _, c in pairs(p.chevrons) do c:Hide() end
    end
    p.over:SetShown(any)
end

-- The chevron on the side stepped comes in from outside, faint to full.
local function Flash(c, elapsed)
    c.t = c.t + elapsed
    local p = math.min(c.t / CHEVRON.flash, 1)
    local ease = 1 - (1 - p) ^ 3
    local from = (c.dir == "LEFT" and -1 or 1) * CHEVRON.travel
    c:ClearAllPoints()
    c:SetPoint(c.anchor[1], c.anchor[2], c.anchor[3], c.anchor[4] + from * (1 - ease), 0)
    c:SetAlpha(0.3 + 0.7 * ease)
    if p >= 1 then c:SetScript("OnUpdate", nil) end
end

function Look.Step(host, item, dir)
    local p = parts[host]
    local c = p and p.marked and p.chevrons[dir]
    if not (c and c:IsShown() and c.anchor) then return end
    c.t = 0
    c:SetScript("OnUpdate", Flash)
end

--------------------------------------------------------------------------
-- The prompts: a slip under the cover, LB / RB by the ribbons
--------------------------------------------------------------------------

local function Slip(host)
    local p = Parts(host)
    if p.slip then return p.slip end
    -- (a level under the book's: the cover's foot lies over its top edge)
    local slip = CreateFrame("Frame", nil, host)
    slip:SetFrameLevel(math.max(0, host:GetFrameLevel() - 1))
    slip:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", SLIP.right, SLIP.tuck)
    slip:SetHeight(SLIP.height)

    local paper = slip:CreateTexture(nil, "BACKGROUND", nil, 0)
    paper:SetAllPoints()
    local c = SLIP.paper
    paper:SetColorTexture(c[1], c[2], c[3], 1)
    Style.Hairline(slip, "BORDER", 0, 0.45)
    -- Its shadow on the world, down and to the right.
    local below = slip:CreateTexture(nil, "BACKGROUND", nil, -1)
    below:SetPoint("TOPLEFT", slip, "BOTTOMLEFT", SLIP.shadow / 2, 0)
    below:SetPoint("BOTTOMRIGHT", slip, "BOTTOMRIGHT", SLIP.shadow, -SLIP.shadow)
    Style.Shade(below, "VERTICAL", 0, 0, 0, 0, 0.35)
    local side = slip:CreateTexture(nil, "BACKGROUND", nil, -1)
    side:SetPoint("TOPLEFT", slip, "TOPRIGHT", 0, -SLIP.tuck)
    side:SetPoint("BOTTOMRIGHT", slip, "BOTTOMRIGHT", SLIP.shadow, 0)
    Style.Shade(side, "HORIZONTAL", 0, 0, 0, 0.35, 0)

    slip.entries = {}
    slip.pen = NewPen(slip)
    slip.pen:SetFrameLevel(slip:GetFrameLevel() + 2)
    slip:Hide()
    p.slip = slip
    return slip
end

-- A button as the pad's own prompts draw it, in its real colours, on the
-- slip as on the world (the client, 8 Nov 2026: desaturated and inked, its
-- letters were nearly as dark as the button): the atlas `size` px tall,
-- never tinted. Where the client has no atlas, its printed name, in the
-- book's ink on the slip.
local function Glyph(parent, key, size, inked)
    local atlas = Pad.Glyphs.Atlas(key)
    if atlas then
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetAtlas(atlas)
        local w, h = Pad.Glyphs.Size(atlas, size)
        t:SetSize(w, h)
        return t, w
    end
    local fs = inked and Style.Text(parent, Style.FONT.strong) or parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetText(Pad.Glyphs.Name(key))
    return fs, fs:GetStringWidth()
end

local function Main(e)
    if e.main ~= nil then return e.main end
    local key = type(e[1]) == "table" and e[1][1] or e[1]
    return key == "PAD1" or Pad.DIRS[key] ~= nil
end

-- One entry of the slip, made anew (the slip is small and rarely changes).
local function Entry(slip, e)
    local entry = CreateFrame("Frame", nil, slip)
    local keys = type(e[1]) == "table" and e[1] or { e[1] }
    local x = 0
    for _, key in ipairs(keys) do
        local g, w = Glyph(entry, key, SLIP.glyph, true)
        g:SetPoint("LEFT", entry, "LEFT", x, 0)
        x = x + w + 2
    end
    x = x - 2 + SLIP.glyphGap
    local main = Main(e)
    local words = Style.Text(entry, main and Style.FONT.headingRubric or Style.FONT.heading)
    words:SetText((e[2] or ""):upper())
    words:SetPoint("LEFT", entry, "LEFT", x, 0)
    entry.span = x + words:GetStringWidth()
    entry:SetSize(entry.span, SLIP.glyph)
    entry.main = main
    return entry
end

local function SameEntries(a, b)
    if not a or #a ~= #b then return false end
    for i = 1, #b do
        local x, y = a[i], b[i]
        local kx = type(x[1]) == "table" and table.concat(x[1], "/") or x[1]
        local ky = type(y[1]) == "table" and table.concat(y[1], "/") or y[1]
        if kx ~= ky or x[2] ~= y[2] or x.beside ~= y.beside or x.main ~= y.main then return false end
    end
    return true
end

local function RibbonKeys(host, e)
    local p = Parts(host)
    if not p.keys then
        p.keys = CreateFrame("Frame", nil, host)
        p.keys:SetAllPoints(host)
    end
    if not e then
        p.keys:Hide()
        return
    end
    local keys = e[1]
    local id = table.concat(keys, "/") .. Pad.Glyphs.Style()
    if p.keys.id ~= id or p.keys.beside ~= e.beside then
        for _, g in ipairs(p.keys.made or {}) do g:Hide() end
        local a = Glyph(p.keys, keys[1], KEYS.size, false)
        a:SetPoint("CENTER", e.beside[1], "TOPLEFT", -KEYS.out, -KEYS.down)
        local b = Glyph(p.keys, keys[2] or keys[1], KEYS.size, false)
        b:SetPoint("CENTER", e.beside[2], "TOPRIGHT", KEYS.out, -KEYS.down)
        p.keys.made, p.keys.id, p.keys.beside = { a, b }, id, e.beside
    end
    p.keys:Show()
end

-- Where the slip lies: under the cover's foot (Slip), or under `under`'s
-- edge where it says.
local function Lie(slip, host, under)
    local at = under and under(slip:GetWidth() or 0)
    slip:ClearAllPoints()
    if at and at.frame then
        slip:SetPoint("TOPLEFT", at.frame, "CENTER", at.x or 0, (at.y or 0) + SLIP.tuck)
        slip:SetFrameLevel(math.max(0, at.level or at.frame:GetFrameLevel() - 1))
    else
        slip:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", SLIP.right, SLIP.tuck)
        slip:SetFrameLevel(math.max(0, host:GetFrameLevel() - 1))
    end
end

function Look.Legend(host, entries, under)
    if not host then return end
    local slip = Slip(host)
    local onSlip, beside = {}, nil
    for _, e in ipairs(entries or {}) do
        if e.beside and type(e[1]) == "table" then beside = e else onSlip[#onSlip + 1] = e end
    end
    RibbonKeys(host, beside)
    if #onSlip == 0 then
        slip.entriesShown = nil
        slip:Hide()
        return
    end
    local style = Pad.Glyphs.Style()
    if slip.style ~= style or not SameEntries(slip.entriesShown, onSlip) then
        for _, old in ipairs(slip.entries) do old:Hide() end
        slip.entries = {}
        slip.pen:Hide()
        local x = SLIP.padL
        local midY = -(SLIP.tuck + (SLIP.height - SLIP.tuck) / 2)
        for i, e in ipairs(onSlip) do
            local entry = Entry(slip, e)
            entry:SetPoint("LEFT", slip, "TOPLEFT", x, midY)
            slip.entries[i] = entry
            x = x + entry.span + SLIP.gap
            if entry.main and not slip.pen:IsShown() then
                -- (the small box: this button acts on the boxed words)
                local padX, padY = Pads(10)
                padX, padY = padX * 0.8, padY * 0.8
                slip.pen:ClearAllPoints()
                slip.pen:SetPoint("TOPLEFT", entry, "TOPLEFT", -padX, padY)
                PenBox(slip.pen, entry.span + 2 * padX, SLIP.glyph + 2 * padY - 2, 77, false)
            end
        end
        slip:SetWidth(x - SLIP.gap + SLIP.padR)
        slip.entriesShown, slip.style = onSlip, style
    end
    Lie(slip, host, under)
    slip:Show()
end

function Look.Hide(host)
    local p = parts[host]
    if not p then return end
    Look.Unmark(host)
    p.drawnKey = nil
    if p.slip then
        p.slip:Hide()
        p.slip.entriesShown = nil
    end
    if p.keys then p.keys:Hide() end
end
