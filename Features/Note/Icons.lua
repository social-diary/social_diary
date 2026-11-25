-- The free card's icons (.claude/features/note-card.md, decision 1): sixteen
-- small pictures drawn by hand with the diary's own pen and watercolour, no
-- game icons. The one a player chooses is the card's mark on the map plates
-- (about 13 px) and sits on its margin card and in the form's grid, larger
-- (32 to 48 px). One drawing serves every size: each icon is laid out on a
-- 16-unit square round its middle and drawn through a plate's mark kit
-- (Plate.MarkKit, or the plate's own: RegisterMark's spec says what it holds),
-- so it turns and is lit with whatever paper it lies on.
--
--   ns.NoteIcons.KEYS          the sixteen keys, the default first
--   ns.NoteIcons.NAMES[key]    a short name (the grid's tooltips, and the
--                              card's heading where nothing else names it)
--   ns.NoteIcons.Draw(kit, key, x, y, size)   on a mark kit, centred on x, y;
--                              an unknown or nil key draws KEYS[1], a nil size
--                              the mark's (MARK.size)
--   ns.NoteIcons.New(parent, size)   a frame of its own showing one icon,
--                              frame:SetIcon(key), frame:SetPaper(colour)
--   ns.NoteIcons.MARK          the mark's size and the halo it wants
--
-- How they are drawn: a wash, then the pen over it.
--   The wash is watercolour in a muted pigment (PIGMENT): a flat fill over
--   the shape (triangles from a point inside to its edge, the edge's points
--   a little uneven, as a brush's), and a bloom or two where the paint
--   pooled darker (a disc laid twice a little apart). The whole wash sits a
--   hair down and right of the lines (WASH.shift), as a quick hand tints a
--   drawing, and goes in the kit's `ink` pool, under the pen. Where corners
--   cannot move, a fill is one disc at its middle.
--   The pen is ink lines (the kit's Stroke, in its `inner` pool, over the
--   wash): every line widens and thins with the trail's own nib
--   (ns.UI.Pen.Nib), a joint that turns sharply gets a bead of ink, a free
--   end a round one, and every point is moved a little by a run of numbers
--   seeded by the icon, so the same icon is drawn by the same hand every
--   time. Solid parts (eyes, a door, a paw's pads) are dots and boxes of ink.
-- Nothing is drawn in paper over ink: the mark kit's pools are three
-- sublevels (halo, ink, inner), and the wash takes one, so every icon is
-- line and mass on its wash, never a cut-out.
--
-- Told apart from the plates' other marks at the book's size (the pouch,
-- the fortune star, the duel's flag, the campfire, the crosses, the tally,
-- the tailpiece, the stairs, the tunic, the ring of time together): so no
-- star, no flag, no fire and no plain ring here. "Meeting" (two people, side
-- by side) is the old "Someone You Met" card's, whose saved cards become free
-- cards with it (note-card.md, decision 3).

local addonName, ns = ...

local L = ns.L
local Style = ns.Style
local Pen = ns.UI.Pen

local Icons = {}
ns.NoteIcons = Icons

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------

-- The icon's sizes:
--   size     the mark's on a plate, px across its 16 units (the plates'
--            other marks are 11 to 14 px tall)
--   halo     the paper the plate should lay under it (RegisterMark's `halo`,
--            and `hover`); the campfire's and the flag's are 18
--   radius   how far other marks keep off (RegisterMark's `radius`)
--   card     New's size where none is given
--   detail   from this size up the small things are drawn too (a scroll's
--            lines of writing, the fish's gill): at the mark's size they
--            only thicken the ink into a blot
local MARK = { size = 13, halo = 18, radius = 7.5, card = 40, detail = 22 }
Icons.MARK = MARK

-- The pen, the wash and the pigments: the shared hand's (UI/Ink/Sketch.lua,
-- where each is commented), the same tables.
local Sketch = ns.UI.Sketch
local PEN, WASH, PIGMENT = Sketch.PEN, Sketch.WASH, Sketch.PIGMENT
Icons.PEN, Icons.WASH, Icons.PIGMENT = PEN, WASH, PIGMENT

--------------------------------------------------------------------------
-- The hand
--------------------------------------------------------------------------

-- The hand that draws them is the diary's (UI/Ink/Sketch.lua: lines,
-- curves, spots and washes in units, through a mark kit), moved there
-- unchanged on 24 Nov 2026 so a feature's own small drawings need not read
-- this one; the sixteen are drawn by it exactly as before.
local sqrt, cos, sin, pi = math.sqrt, math.cos, math.sin, math.pi
local Ellipse, Bend, Join, Hand = Sketch.Ellipse, Sketch.Bend, Sketch.Join, Sketch.Hand

--------------------------------------------------------------------------
-- The sixteen
--------------------------------------------------------------------------

-- Each draws on a hand in units, x right and y down, its middle at 0, 0,
-- within about 7.5 units each way. Read at the mark's size first (13 px:
-- a unit is 0.8 px), then at the card's.
local DRAW = {}

-- A quill, the diary's own: a feather lying from its nib at the lower left
-- up to the right, its vane fuller on the upper side, two barbs drawn in,
-- and a drop of ink at the nib. The default: a card about anything.
function DRAW.quill(h)
    local u0, v0, u1, v1 = -6.6, 7.0, 6.2, -7.0
    local du, dv = u1 - u0, v1 - v0
    local len = sqrt(du * du + dv * dv)
    local nu, nv = dv / len, -du / len -- the upper side's normal
    local function On(t, off) return u0 + du * t + nu * off, v0 + dv * t + nv * off end
    local function Vane(t) return sin(pi * (t - 0.24) / 0.76) ^ 0.7 end
    -- The vane: up one side and down the other, round the tip.
    local upper, lower = {}, {}
    local n = h.Pieces(len * 0.8)
    for i = 0, n do
        local t = 0.24 + 0.76 * i / n
        local u, v = On(t, 2.9 * Vane(t))
        upper[#upper + 1], upper[#upper + 2] = u, v
        u, v = On(t, -1.5 * Vane(t))
        lower[#lower + 1], lower[#lower + 2] = u, v
    end
    local edge = Join({}, upper)
    for i = #lower - 1, 1, -2 do edge[#edge + 1], edge[#edge + 2] = lower[i], lower[i + 1] end
    local cu, cv = On(0.6, 0.6)
    h.Fill("indigo", cu, cv, edge, 6)
    local bu, bv = On(0.5, 1.2)
    h.Bloom("indigo", { { bu, bv, 2.2 } })
    h.Line(upper, 0.9)
    h.Line(lower, 0.9)
    -- The shaft, past the vane to the nib.
    local a, b = On(0.0, 0)
    local c, d = On(0.97, 0)
    h.Line({ a, b, c, d }, 1.1)
    -- Two barbs, the feather's grain.
    if h.detail then
        for _, t in ipairs({ 0.5, 0.68 }) do
            local p, q = On(t, 0)
            local r, s = On(t + 0.08, 2.4 * Vane(t + 0.08))
            h.Line({ p, q, r, s }, 0.55)
        end
    end
    local e, f = On(-0.02, 0)
    h.Spot(e, f + 0.4, 2.0)
end

-- Two people side by side, each a head of solid ink over the arc of their
-- shoulders: met someone (the old "Someone You Met" card's). Two, never one,
-- so never the plate's ring of time together.
function DRAW.meeting(h)
    local L1 = Ellipse(nil, -3.8, 6.8, 3.5, 4.6, pi, 2 * pi, 10)
    local R1 = Ellipse(nil, 3.7, 6.0, 3.5, 4.6, pi + 0.55, 2 * pi, 8)
    h.Fill("rose", -3.8, 5.0, L1, 6)
    h.Fill("rose", 3.9, 4.6, Join(R1, { 0.2, 6.6 }), 6)
    h.Bloom("rose", { { -4.4, 4.6, 1.4 } })
    -- The one on the right a little taller and behind.
    h.Spot(-3.8, -2.4, 4.4)
    h.Spot(3.7, -3.4, 4.4)
    h.Ring(-3.8, 6.8, 3.5, 4.6, pi, 2 * pi, 1.05)
    h.Ring(3.7, 6.0, 3.5, 4.6, pi + 0.55, 2 * pi, 1.05)
end

-- A heart: friendship, someone dear.
function DRAW.heart(h)
    local pts = {}
    local n = h.Pieces(48)
    for i = 0, n - 1 do
        local t = 2 * pi * i / n
        local u = 16 * sin(t) ^ 3
        local v = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
        pts[#pts + 1], pts[#pts + 2] = u / 2.2, v / 2.2 - 1.6
    end
    h.Fill("rose", 0, 0, pts, 11)
    h.Bloom("rose", { { -2.8, -2.0, 2.6 } })
    h.Line(pts, 1.1, true)
end

-- A house, its door and chimney: home, a hearth, a place you stayed.
function DRAW.home(h)
    h.Fill("brick", 0, -2.4, { -7.0, -0.6, 0, -6.8, 7.0, -0.6 }, 6)
    h.Fill("ochre", 0, 3.0, { -5.2, -0.8, 5.2, -0.8, 5.2, 7.0, -5.2, 7.0 }, 8)
    h.Bloom("brick", { { -2.6, -1.6, 1.4 } })
    h.Line({ -7.2, -0.4, 0, -7.0, 7.2, -0.4 }, 1.1)
    h.Line({ -5.2, -2.0, -5.2, 7.0, 5.2, 7.0, 5.2, -2.0 }, 1.0)
    h.Line({ 3.0, -4.6, 3.0, -7.2, 4.8, -7.2, 4.8, -3.0 }, 0.85)
    h.Block(0, 4.6, 2.8, 4.8)
    if h.detail then h.Line(Bend(nil, 3.9, -8.2, 5.4, -9.2, 4.6, -10.2, 4), 0.5) end
end

-- A tankard with its head of foam: an inn, a drink, a rest.
function DRAW.tankard(h)
    h.Fill("amber", -1.2, 2.0, { -6.0, -1.0, 3.5, -1.0, 3.2, 7.0, -5.6, 7.0 }, 8)
    h.Bloom("amber", { { -3.4, 4.4, 1.6 } })
    -- The foam: three bumps over the rim.
    local foam = {}
    Ellipse(foam, -4.6, -3.6, 1.5, 1.5, pi, 2 * pi - 0.3, 4)
    Ellipse(foam, -1.6, -4.4, 1.7, 1.7, pi + 0.2, 2 * pi - 0.2, 4)
    Ellipse(foam, 1.6, -3.6, 1.5, 1.5, pi + 0.3, 2 * pi, 4)
    h.Line(foam, 0.95)
    h.Line({ -6.1, -3.4, -5.6, 7.0, 3.2, 7.0, 3.6, -3.4 }, 1.05)
    h.Ring(3.6, 1.6, 3.2, 3.4, -pi / 2 + 0.15, pi / 2 - 0.05, 1.05)
    h.Line({ -5.9, 2.0, 3.4, 2.0 }, 0.7)
end

-- A boot: the road, a journey, somewhere walked to.
function DRAW.boot(h)
    local pts = { -4.0, -7.0, -4.2, 2.0, -4.4, 6.8 }
    pts[#pts + 1], pts[#pts + 2] = 6.2, 6.8
    Bend(pts, 6.2, 6.8, 7.4, 4.0, 4.6, 3.6, 4, false)
    Bend(pts, 4.6, 3.6, 1.4, 3.2, 1.2, 0.4, 3, false)
    pts[#pts + 1], pts[#pts + 2] = 1.2, -7.0
    h.Fill("sienna", -1.2, 3.0, pts, 8)
    h.Bloom("sienna", { { -2.0, -3.0, 1.4 } })
    h.Line(pts, 1.05)
    h.Line({ -4.4, -7.0, 1.6, -7.0 }, 1.2)
    h.Block(-2.9, 7.0, 3.2, 1.8)
end

-- Two peaks, snow on the higher: a view, a landmark, the top of something.
function DRAW.mountain(h)
    local ridge = { -7.8, 6.6, -1.6, -6.4, 2.1, 0.8, 4.0, -1.8, 7.8, 6.6 }
    h.Fill("slate", -0.6, 3.6, ridge, 10)
    h.Bloom("slate", { { -3.0, 3.6, 2.6 } })
    h.Line(ridge, 1.1)
    -- The snow line, a zigzag across the higher peak.
    h.Line({ -3.7, -2.0, -2.6, -0.8, -1.5, -2.2, -0.5, -0.9, 0.6, -2.0 }, 0.7)
    h.Line({ -7.6, 7.0, 7.6, 7.0 }, 0.6)
end

-- A scroll, rolled at both ends: a quest, a letter, orders.
function DRAW.scroll(h)
    h.Fill("ochre", -0.7, 0.2, { -4.8, -4.4, 3.4, -4.4, 3.4, 4.8, -4.8, 4.8 }, 8)
    h.Bloom("ochre", { { -2.6, 2.4, 1.4 } })
    -- The rolls: across the top and the foot, each closed by its end.
    for _, v in ipairs({ -5.2, 5.6 }) do
        h.Line({ -6.0, v - 1.1, 4.8, v - 1.1 }, 0.95)
        h.Line({ -6.0, v + 1.1, 4.8, v + 1.1 }, 0.95)
        h.Ring(4.8, v, 1.2, 1.1, -pi / 2, pi / 2, 0.95)
        h.Ring(-6.0, v, 1.2, 1.1, pi / 2, 3 * pi / 2, 0.95)
    end
    h.Line({ -4.8, -4.1, -4.8, 4.5 }, 0.95)
    h.Line({ 3.4, -4.1, 3.4, 4.5 }, 0.95)
    if h.detail then
        for i, v in ipairs({ -2.0, 0.2, 2.4 }) do
            h.Line({ -3.3, v, i == 3 and 0.2 or 1.9, v }, 0.45, false, 0.7)
        end
    end
end

-- A question mark: a mystery, something not understood, still to find out.
function DRAW.question(h)
    h.Bloom("indigo", { { 0, -1.0, 5.2 } })
    local pts = Ellipse(nil, 0, -3.0, 3.6, 3.4, pi + 0.35, 2 * pi + 0.6, h.Pieces(16))
    Bend(pts, pts[#pts - 1], pts[#pts], 0.3, 0.2, 0.2, 2.8, 3, false)
    h.Line(pts, 1.35)
    h.Spot(0.2, 6.2, 2.6)
end

-- A chest, its lid domed, a band round it and its lock: treasure, loot.
function DRAW.chest(h)
    h.Fill("ochre", 0, -2.6, Ellipse(nil, 0, -0.6, 6.6, 5.0, pi, 2 * pi, 8), 8)
    h.Fill("umber", 0, 3.2, { -6.6, -0.6, 6.6, -0.6, 6.6, 7.0, -6.6, 7.0 }, 10)
    h.Bloom("umber", { { -3.6, 4.4, 1.6 } })
    h.Ring(0, -0.6, 6.6, 5.0, pi, 2 * pi, 1.05)
    h.Line({ -6.6, -0.6, -6.6, 7.0, 6.6, 7.0, 6.6, -0.6, -6.6, -0.6 }, 1.05)
    if h.detail then
        h.Line({ -3.8, -4.7, -3.8, 7.0 }, 0.6)
        h.Line({ 3.8, -4.7, 3.8, 7.0 }, 0.6)
    end
    h.Block(0, 1.4, 2.4, 3.0)
end

-- Two swords crossed, guards and pommels: a fight, a battle. On a mark the
-- pommels' knobs and the grips' length are left to the card: crossed, they
-- crowded the 13 px into a knot.
function DRAW.swords(h)
    h.Bloom("steel", { { 0, -0.6, 3.6 } })
    for _, side in ipairs({ -1, 1 }) do
        -- From the pommel low on one side to the point high on the other.
        local tu, tv = -6.2 * side, -6.2
        local gu, gv = 3.4 * side, 3.4
        local pu, pv = (h.detail and 6.2 or 5.4) * side, h.detail and 6.2 or 5.4
        local g = h.detail and 2.2 or 1.7
        h.Line({ gu, gv, tu, tv }, 1.2)
        h.Line({ gu, gv, pu, pv }, h.detail and 0.9 or 1.3)
        -- The guard, across the blade.
        h.Line({ gu - g, gv + g * side, gu + g, gv - g * side }, 1.0)
        if h.detail then h.Spot(pu + 0.5 * side, pv + 0.5, 2.0) end
    end
end

-- A skull, its eyes dark: danger, something to stay away from.
function DRAW.skull(h)
    local pts = Ellipse(nil, 0, -1.4, 6.0, 5.6, pi - 0.75, 2 * pi + 0.75, h.Pieces(32))
    Join(pts, { 3.4, 4.4, 3.4, 7.0, -3.4, 7.0, -3.4, 4.4 })
    h.Fill("ash", 0, 0, pts, 11)
    h.Bloom("ash", { { 2.4, -3.6, 2.4 } })
    h.Line(pts, 1.05, true)
    h.Spot(-2.3, -0.8, 3.0)
    h.Spot(2.3, -0.8, 3.0)
    h.Spot(0, 2.5, 1.3)
    if h.detail then
        h.Line({ -1.1, 5.0, -1.1, 7.0 }, 0.55)
        h.Line({ 1.1, 5.0, 1.1, 7.0 }, 0.55)
    end
end

-- A paw's print, a stamp of ink on a bloom: a beast, a hunt, a pet tamed.
function DRAW.paw(h)
    h.Bloom("sienna", { { 0, 0.6, 6.2 } })
    h.Spot(-5.3, -1.0, 2.8, 3.4, 0.5)
    h.Spot(-2.0, -5.0, 2.8, 3.6, 0.15)
    h.Spot(2.0, -5.0, 2.8, 3.6, -0.15)
    h.Spot(5.3, -1.0, 2.8, 3.4, -0.5)
    h.Spot(0, 3.0, 6.4, 5.0)
    h.Spot(-2.4, 4.8, 3.6)
    h.Spot(2.4, 4.8, 3.6)
end

-- A fish, nose to the left: fishing, something caught.
function DRAW.fish(h)
    local body = Bend(nil, -6.8, 0.2, -1.6, -6.4, 3.6, 0.2, h.Pieces(14))
    Bend(body, 3.6, 0.2, -1.6, 6.4, -6.8, 0.2, h.Pieces(14), false)
    body[#body], body[#body - 1] = nil, nil
    local tail = { 3.6, 0.2, 7.2, -3.4, 6.2, 0.2, 7.2, 3.8 }
    h.Fill("teal", -1.6, 0.2, body, 9)
    h.Fill("teal", 5.6, 0.2, tail, 3)
    h.Bloom("teal", { { -0.4, 1.4, 1.4 } })
    h.Line(body, 1.05, true)
    h.Line(tail, 1.0, true)
    h.Spot(-3.6, -0.7, 1.7)
    if h.detail then h.Ring(-4.0, 0.2, 2.0, 2.6, -0.9, 0.9, 0.55) end
end

-- A hammer, head up and handle down to the left: crafting, a trade learnt.
function DRAW.hammer(h)
    -- The head, across the handle's end: a block turned 45 degrees.
    local cu, cv = 2.9, -2.9
    local au, av = 0.7071, 0.7071 -- along the head
    local bu, bv = 0.7071, -0.7071 -- along the handle
    local L2, W2 = 4.8, 1.9
    local q = {}
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        q[#q + 1] = cu + au * L2 * c[1] + bu * W2 * c[2]
        q[#q + 1] = cv + av * L2 * c[1] + bv * W2 * c[2]
    end
    h.Fill("steel", cu, cv, q, 5)
    h.Bloom("ochre", { { -3.0, 3.0, 2.0 } })
    -- The handle.
    h.Line({ -6.4, 6.6, 1.6, -1.4 }, 1.25)
    h.Line(q, 1.05, true)
end

-- Two notes, beamed: music, a song, a celebration.
function DRAW.music(h)
    h.Bloom("rose", { { -3.6, 4.6, 2.8 }, { 3.6, 3.2, 2.8 } })
    h.Spot(-3.8, 5.2, 4.0, 2.8, 0.35)
    h.Spot(3.6, 3.8, 4.0, 2.8, 0.35)
    h.Line({ -2.0, 4.6, -2.0, -4.6 }, 1.0)
    h.Line({ 5.4, 3.2, 5.4, -6.2 }, 1.0)
    h.Line({ -2.0, -4.6, 5.4, -6.2 }, 2.0)
    if h.detail then h.Line({ -2.0, -2.4, 5.4, -4.0 }, 1.2) end
end

-- In the order the form's grid shows them, the general first: the quill
-- (a note about anything), then people, places, deeds, finds, the world's
-- creatures and crafts.
Icons.KEYS = { "quill", "meeting", "heart", "home", "tankard", "boot", "mountain", "scroll", "question", "chest",
    "swords", "skull", "paw", "fish", "hammer", "music" }

-- Their names, as a card's heading reads (the copywriter's, 19 Nov): "A
-- meeting", "On the road"; a bare noun where an article would not be said
-- ("Treasure", "Fishing"). The quill's is the card's own, "A note".
Icons.NAMES = {
    quill = L["A note"],
    meeting = L["A meeting"],
    heart = L["A friend"],
    home = L["Home##note icon"],
    tankard = L["At the inn"],
    boot = L["On the road"],
    mountain = L["A view"],
    scroll = L["A quest"],
    question = L["A mystery"],
    chest = L["Treasure##note icon"],
    swords = L["A fight"],
    skull = L["Danger##note icon"],
    paw = L["A beast"],
    fish = L["Fishing##note icon"],
    hammer = L["Crafting##note icon"],
    music = L["Music##note icon"],
}

-- The key drawn for `key`: itself where it is one of the sixteen, else the
-- default.
function Icons.Known(key)
    return (key and DRAW[key]) and key or Icons.KEYS[1]
end

-- Each of the sixteen is a drawing any surface may draw by its key
-- (Sketch.Register): a sheet's errand drawn as the card's scroll or hammer,
-- through the shared hand, without reading this file.
for _, key in ipairs(Icons.KEYS) do Sketch.Register(key, DRAW[key]) end

-- One icon on a mark kit, centred on x, y, `size` px across (the mark's
-- where nil). Draws into the kit's pools; the caller begins and finishes
-- them (a plate does round all its marks; New's frame round each icon).
function Icons.Draw(kit, key, x, y, size)
    key = Icons.Known(key)
    DRAW[key](Hand(kit, key, x, y, size or MARK.size))
end

-- A frame showing one icon, `size` px square (MARK.card where nil): the card's
-- and the form's grid. Its own mark kit, flat (no turn, no light); the paper
-- under it is Style.PAPER till frame:SetPaper says otherwise (only a kind of
-- mark that draws paper reads it; these never do, but the kit wants one).
--   frame:SetIcon(key)    draws it (an unknown or nil key: the default);
--                         frame.key is the key drawn
--   frame:SetPaper(rgb)   the paper it lies on
function Icons.New(parent, size)
    size = size or MARK.card
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    local function Place(region, x, y, w, h, turn)
        region:ClearAllPoints()
        region:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
        region:SetSize(w, h)
        if region.SetRotation then region:SetRotation(turn or 0) end
    end
    local function Quad(region, ...) return Style.Quad(region, frame, ...) end
    local kit = ns.UI.JourneyPlate.MarkKit(frame, Place, Quad, Style.PAPER)
    frame.kit = kit
    function frame:SetIcon(key)
        self.key = Icons.Known(key)
        kit:Begin()
        Icons.Draw(kit, self.key, size / 2, size / 2, size)
        kit:Finish()
    end
    function frame:SetPaper(paper)
        kit.P = paper or Style.PAPER
    end
    frame:SetIcon(nil)
    return frame
end
