-- A leaf glued among Your Diary's plates: a page torn from a pocket book,
-- glued in flat where a sheet's slot is (the
-- city-trips proposal's hook 5, 24 Nov 2026; UI/Journey/Sheet.lua draws one
-- for a moment kind registered with `sheet`). The paper is a glued loose
-- sheet (UI/Paper/Sheet.lua's ns.UI.LooseSheet with `glued`), so it turns
-- with its slot and "Flat paper only" lays it plain. It is one facet, lit
-- evenly across its whole width, on the margin strips' stock: it was
-- folded down its middle at first, and the two halves took the house light
-- apart, the left one greyer than the right (the user, 25 Nov 2026, in
-- the client: "the shading is different from the other paper strips").
-- Everything a feature writes or draws on it goes through its toolkit, so
-- it turns, and is lit, with the leaf:
--
--   local leaf = ns.UI.Leaf.New(parent, opts)   opts (all optional): `fold`
--                    where it was folded, a share of its width (LEAF.fold:
--                    none; a fold's two halves are lit apart, so a leaf
--                    among strips has none), `torn` false for a cut top edge,
--                    `paper` its stock ({ r, g, b }), `level` its frame level
--                    over `parent` (LEAF.level)
--   leaf:SetSlot(slot)   glued at a slot ({ x, y, w, h, t (degrees,
--                    clockwise), lift ("bl" | "br", the corner come unstuck)
--                    }) on `parent`, and laid: its paper, torn edge,
--                    shadow and lifted corner. Before every drawing
--   leaf:Begin(), leaf:Finish()   round a drawing: what is handed out
--                    between them is shown, the rest hidden
--   leaf.w, leaf.h, leaf.flat, leaf.paper   its size, whether it is laid
--                    flat, its stock; leaf.turn (radians, as laid), leaf.torn,
--                    leaf.lifted (whether its tear and lifted corner are drawn)
--   leaf.K           the sheet's toolkit (K.Place, K.PlaceText, K.Quad,
--                    K.Wrap, K.Width, K.Screen, K.Light: x right and y down
--                    from the leaf's top left)
--   leaf:Write(words, font, x, y, opts) → text, left, width   one line, its
--                    middle at height y, from x (opts.justify "RIGHT" or
--                    "CENTER" ends or centres it there), opts.colour { r, g,
--                    b[, a] }. Turned text is laid a line at a time: wrap
--                    with K.Wrap. A line in two inks is two Writes in a row
--   leaf:Text(font)  a font string of its pool, to place with K yourself
--   leaf:Ink()       a texture of its ink pool (over the paper), for K.Quad
--   leaf:Pen(paths, look)   pen marks (UI/Ink/Scribble.lua's paths and
--                    looks) stroked into its ink pool; returns how many
--   leaf:Kit()       a mark kit on the leaf (Plate.MarkKit through its
--                    toolkit, lit as the leaf: evenly), begun and finished with it:
--                    for the small drawings (UI/Ink/Sketch.lua's Draw)
--   leaf:Button(x, y, w, h, opts)   a square button over a box of the leaf
--                    (buttons cannot turn: it sits where the box's middle
--                    lands), a level over the paper: opts.tip (a function
--                    → Style.Tooltip's lines), opts.click (fn(button))
--   leaf:Name(words, font, x, y, opts) → text, left, width, button   a line
--                    that is someone (or anything with a tooltip): Write, a
--                    Button over it, and a Stop for the pad (opts.key, tip,
--                    click)
--   leaf:Stop(stop)  a stop the pad goes in among (UI/Journey/Pad.lua):
--                    { key, x, y (its middle on the leaf), frame (a Button,
--                    for its tooltip), words (a font string the pad's look
--                    reddens and boxes), tip, press (A; none: tooltip only) }
--   leaf:Heading(text)   which line is its heading: the pad's look reddens
--                    it, the ticklist's hover draws a pencil line under it
--   leaf:Stops(), leaf:HasMarks(), leaf:Marks()   for the pad, as a plate's
--   leaf:Corners(), leaf:OnPage(x, y)   on `parent`, x right and y down
--   leaf:SetRing(r)  the ticklist's hover: a pencil line under the heading
--                    (r non-nil), as the ledger marks a row; nil takes it off
--   leaf.onHover(leaf, over), leaf.onRight(leaf)   set by its owner: the
--                    mouse on it, a right click on it
--
-- No faces on it (the user's, 24 Nov 2026: "No player icons"), no window,
-- no caption, no margin.

local addonName, ns = ...

local Style = ns.Style

local Leaf = {}
ns.UI.Leaf = Leaf

-- The leaf's look:
--   paper    the margin strips' stock (ns.UI.PAPER_LOOK.paper, UI/Paper/
--            Strip.lua's STRIP.paper), so the leaf and the strips round the
--            plates read as one paper, and as paper written on, not a print
--            (a plate's photo stock is { .89, .83, .66 }). It was a stock of
--            its own ({ .93, .89, .76 }), a shade darker and yellower than
--            the strips': the user saw it (25 Nov 2026, "the shading is
--            different from the other paper strips")
--   fold     where it was folded down, a share of its width: none (false).
--            Folded at its middle (0.5, the halves a book's two pages), the
--            valley sloped each half a different way to the top-left light
--            and the left half read darker and greyer than the right (the
--            user, 25 Nov 2026: "the shading is different from the other
--            paper strips"). The two columns' gutter says two pages enough;
--            no hairline in its place
--   crease   a fold's, where a caller asks for one: a valley (`ridge` px
--            deep for the light), no crumple or drift (glued, it never
--            bends). With no fold the leaf is one flat facet, lit as 1
--   torn     its top edge, torn from the book's stitching: `teeth` points
--            along it, each standing `least`..1 of `depth` px over the
--            paper's top, the torn fibre lighter (`fibre`) than the stock, a
--            hairline of ink at `edge` along the tear. Where corners cannot
--            move, and laid flat, it is cut square
--   lift     a corner come unstuck, as a print's (UI/Journey/Plate.lua's
--            LIFT and SHADOW, the same numbers so it stands as high): its
--            shadow cast `out` + `gain` x `height` px down and right under a
--            `box` of the leaf at the corner, at `alpha`, and the paper at it
--            darkening to `shade` toward the corner as it slopes away from
--            the light. Laid flat, none
--   level    its frame level over the page (a plate's is 5: under the
--            leaders, 20, and the strips, 25); `buttons` the names' over it
--   mark     the ticklist's hover: a pencil line `width` px, `under` px
--            beneath the heading, graphite at `alpha` (the ledger's mark,
--            UI/Journey/Look.lua's LEDGER.mark)
local LEAF = {
    paper = { unpack(ns.UI.PAPER_LOOK.paper) },
    fold = false,
    crease = { ridge = 3, crumple = 0, drift = 0, edge = 0, nick = 0, shift = 0, lean = 0, press = 0, taper = 0,
        wander = 0 },
    torn = { teeth = 26, depth = 3.2, least = 0.25, fibre = { 1, 0.985, 0.94 }, edge = 0.35 },
    lift = { height = 6, out = 1.0, gain = 0.30, box = { 50, 42 }, alpha = 0.30, shade = 0.22 },
    level = 5, buttons = 3,
    mark = { width = 1, under = 1, alpha = 0.60 },
}
Leaf.LOOK = LEAF

local Seed = ns.UI.Surface.Seed

function Leaf.New(parent, opts)
    opts = opts or {}
    local fold = opts.fold == nil and LEAF.fold or opts.fold
    -- LEAF.crease copied in, not behind a metatable: the loose sheet sets
    -- its own (its CREASE behind the one it is given), which hid ours, so
    -- the leaf was crumpled as a loose map (`crumple` 2.4) and its one
    -- facet lit at about 0.975, a shade under the strips' (found 25 Nov
    -- 2026 with the fold taken out).
    local crease = { columns = fold and { 0, fold, 1 } or { 0, 1 }, rows = { 0, 1 },
        folds = { columns = fold and { [2] = -1 } or {}, rows = {} } }
    for k, v in pairs(LEAF.crease) do crease[k] = v end
    local paper = opts.paper or LEAF.paper
    local view, K = ns.UI.LooseSheet(parent, 444, 240, { glued = true, crease = crease, paper = paper,
        level = opts.level or LEAF.level })
    local leaf = view
    local S = view.sheet
    leaf.K, leaf.paper, leaf.w, leaf.h = K, paper, 444, 240
    leaf.isLeaf = true

    -- Its pools: the writing, the ink, the names' buttons; the tear and the
    -- lifted corner, laid with the paper.
    local texts = ns.UI.Pool.New(function() return Style.Text(S, Style.FONT.noteWritten, "OVERLAY") end)
    local inks = K.Pool("ARTWORK", 5)
    local teeth = K.Pool("BACKGROUND", -4)
    local tearInk = K.Pool("BACKGROUND", -3)
    local lifts = K.Pool("BACKGROUND", -8)
    local slopes = K.Pool("ARTWORK", 1)
    local buttons = ns.UI.Pool.New(function()
        local b = CreateFrame("Button", nil, S)
        b:SetFrameLevel(S:GetFrameLevel() + LEAF.buttons)
        b:EnableMouse(true)
        b:RegisterForClicks("LeftButtonUp")
        Style.Tooltip(b, function(self) return self.tip and self.tip(self) or nil end, "ANCHOR_RIGHT",
            function(self, over) if leaf.onHover then leaf.onHover(leaf, over) end end)
        b:SetScript("OnClick", function(self) if self.click then self.click(self) end end)
        return b
    end)
    local mark = S:CreateTexture(nil, "OVERLAY")
    mark:Hide()
    local kit
    leaf.stops = {}

    -- The mouse on the paper (its names have their own, which tell it too),
    -- and a right click on it.
    S:SetScript("OnEnter", function() if leaf.onHover then leaf.onHover(leaf, true) end end)
    S:SetScript("OnLeave", function() if leaf.onHover then leaf.onHover(leaf, false) end end)
    S:SetScript("OnMouseUp", function(_, which)
        if which == "RightButton" and leaf.onRight then leaf.onRight(leaf) end
    end)

    -- The top edge torn from the stitching: teeth of paper standing over the
    -- paper's top, uneven, seeded by the slot so it tears the same way each
    -- time; a hairline of ink along them. Square where corners cannot move.
    local function Tear(slot, seed)
        teeth:Begin()
        tearInk:Begin()
        local T = LEAF.torn
        leaf.torn = false
        if opts.torn ~= false and not view.flat then
            leaf.torn = true
            local n, D, W = T.teeth, T.depth, leaf.w
            local P, F = paper, T.fibre
            local function Point(j)
                local inset = D * (T.least + (1 - T.least) * Style.Noise(seed + 20 + j))
                return W * j / n, -inset
            end
            for i = 1, n do
                local ax, ay = Point(i - 1)
                local bx, by = Point(i)
                local tooth = teeth:Next()
                Style.Gradient(tooth, "VERTICAL", { P[1], P[2], P[3], 1 }, { F[1], F[2], F[3], 1 })
                if not K.Quad(tooth, ax, ay, bx, by, bx, 0.6, ax, 0.6) then
                    tooth:Hide()
                    leaf.torn = false
                    break
                end
                local line = tearInk:Next()
                local I = Style.INK
                line:SetColorTexture(I[1], I[2], I[3], T.edge)
                K.Quad(line, ax, ay - 0.5, bx, by - 0.5, bx, by, ax, ay)
            end
        end
        teeth:Finish()
        tearInk:Finish()
    end

    -- A corner come unstuck: its shadow out from under it, and the paper
    -- at it darkening as it slopes from the light. Two gradients each, one
    -- along each edge, which meet darkest at the corner.
    local function Lift(slot)
        lifts:Begin()
        slopes:Begin()
        local L = LEAF.lift
        leaf.lifted = slot.lift ~= nil and not view.flat
        if leaf.lifted then
            local bw, bh = L.box[1], L.box[2]
            local left = slot.lift == "bl"
            local x0 = left and 0 or leaf.w - bw
            local y0 = leaf.h - bh
            local off = L.out + L.gain * L.height
            local I = Style.INK
            local function Pair(pool, alpha, dx, dy)
                local across = pool:Next()
                local from = { I[1], I[2], I[3], left and alpha or 0 }
                local to = { I[1], I[2], I[3], left and 0 or alpha }
                Style.Gradient(across, "HORIZONTAL", from, to)
                K.Place(across, x0, y0, bw, bh, 0, dx, dy)
                local down = pool:Next()
                Style.Gradient(down, "VERTICAL", { I[1], I[2], I[3], alpha }, { I[1], I[2], I[3], 0 })
                K.Place(down, x0, y0, bw, bh, 0, dx, dy)
            end
            Pair(lifts, L.alpha / 2, off, -off)
            Pair(slopes, L.shade / 2, 0, 0)
        end
        lifts:Finish()
        slopes:Finish()
    end

    function leaf:SetSlot(slot)
        self.slot = slot
        self.w, self.h = slot.w, slot.h
        K.Mount(slot.x, slot.y, slot.w, slot.h, -math.rad(slot.t or 0))
        K.Lay()
        self.flat = view.flat
        local seed = Seed(("%d:%d:%d"):format(math.floor(slot.x), math.floor(slot.y), math.floor(slot.w)))
        Tear(slot, seed)
        Lift(slot)
    end

    function leaf:Begin()
        texts:Begin()
        inks:Begin()
        buttons:Begin()
        if kit then kit:Begin() end
        self.stops = {}
        self.heading = nil
        mark:Hide()
        self.ringAt = nil
    end

    function leaf:Finish()
        texts:Finish()
        inks:Finish()
        buttons:Finish()
        if kit then kit:Finish() end
    end

    function leaf:Text(font)
        local text = texts:Next()
        text:SetFontObject(font or Style.FONT.noteWritten)
        text:Show()
        return text
    end

    function leaf:Write(words, font, x, y, o)
        o = o or {}
        local text = self:Text(font)
        text:SetText(words or "")
        local c = o.colour
        if c then text:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
        local left, w = K.PlaceText(text, x, y, o.justify)
        local h = (text:GetStringHeight() or 0) + 2
        text.leafBox = { x = left, y = y - h / 2, w = w, h = h }
        return text, left, w
    end

    function leaf:Ink()
        return inks:Next()
    end

    function leaf:Pen(paths, look)
        return ns.UI.Scribble.Draw({ Next = function() return inks:Next() end, Quad = K.Quad, Place = K.Place },
            paths, look or ns.UI.Scribble.UNDER)
    end

    function leaf:Kit()
        if not kit then
            kit = ns.UI.JourneyPlate.MarkKit(S, function(region, cx, cy, w, h, turn)
                K.Place(region, cx - w / 2, cy - h / 2, w, h, turn)
            end, K.Quad, paper)
            kit.Light = function(x, y) return K.Light(x, y) end
            kit:Begin()
        end
        return kit
    end

    function leaf:Button(x, y, w, h, o)
        o = o or {}
        local b = buttons:Next()
        K.PlaceButton(b, x, y, w, h)
        b.tip, b.click = o.tip, o.click
        b:Show()
        return b
    end

    function leaf:Stop(stop)
        self.stops[#self.stops + 1] = stop
        return stop
    end

    function leaf:Name(words, font, x, y, o)
        o = o or {}
        local text, left, w = self:Write(words, font, x, y, o)
        local box = text.leafBox
        local b = self:Button(left - 2, box.y - 1, w + 4, box.h + 2, { tip = o.tip, click = o.click })
        self:Stop({ key = o.key or words, x = left + w / 2, y = y, frame = b, words = text, tip = o.tip,
            press = o.click and function() o.click(b) end or nil })
        return text, left, w, b
    end

    function leaf:Heading(text)
        self.heading = text
    end

    function leaf:OnPage(x, y)
        local s = self.slot
        local X, Y = K.Screen(x, y)
        return s.x + s.w / 2 + X, s.y + s.h / 2 - Y
    end

    function leaf:Corners()
        local out = {}
        for i, c in ipairs({ { 0, 0 }, { self.w, 0 }, { self.w, self.h }, { 0, self.h } }) do
            local px, py = self:OnPage(c[1], c[2])
            out[i] = { px, py }
        end
        return out
    end

    function leaf:Stops() return self.stops end

    -- The pad's stops as a plate's marks are given (plate:Marks): each
    -- with its middle on the page and a key that holds while it is drawn.
    function leaf:Marks()
        local out = {}
        for k, stop in ipairs(self.stops) do
            local px, py = self:OnPage(stop.x, stop.y)
            out[#out + 1] = { frame = stop.frame, words = stop.words, press = stop.press, tip = stop.tip,
                x = px, y = py, key = "stop:" .. tostring(stop.key or k) }
        end
        return out
    end

    function leaf:HasMarks() return self.stops[1] ~= nil end

    function leaf:SetRing(r)
        self.ringAt = r
        local box = self.heading and self.heading.leafBox
        if not (r and box) then
            mark:Hide()
            return
        end
        local M, G = LEAF.mark, Style.GRAPHITE
        mark:SetColorTexture(G[1], G[2], G[3], M.alpha)
        K.Place(mark, box.x, box.y + box.h + M.under, box.w, M.width)
        mark:Show()
    end

    view:Hide()
    return leaf
end
