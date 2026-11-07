-- The introduction (PRV-4): a short tour on one loose sheet laid across the
-- open book, then an example in the book itself. It replaces the
-- frontispiece and the front matter; the spec is
-- .claude/ui-proposal/HANDOFF-intro-tour.md, its look
-- .claude/ui-proposal/intro-rethink-mockup.html (#one-1 to #one-5, #one-end).
--
-- The sheet is a real loose sheet (UI/Paper/Sheet.lua), laid the way the map
-- sheet is (UI/Map/HeatSheet.lua), and on it a reduced Your Diary plate,
-- built up one layer a step: a short road in ink, two level pins, a
-- pool where you fought, a first green's pouch and its card, a rescue's
-- mark and the card of the stranger who saved you, a ring and a strip for
-- Thex, each a real piece of the page (UI/Journey/Plate.lua's card and its
-- layers, UI/Ink/Trail.lua's ink, UI/Paper/Strip.lua's strips, the find card
-- and the witness card of the margin's registered kinds, their marks of
-- the plate's). The road is made up in memory (ROUTE):
-- nothing of the player's own is read or written while the sheet is out.
-- One step strip lies in a fixed place and says what the step shows; its
-- foot is the step's one action: "Continue →" (steps 1 to 3), then an
-- instruction in red-brown with one arrow to what to click (4: "+ Add" on
-- Thex's strip, 5: his name).
--
-- Clicking Thex's name ends the sheet: it is put away, Thex is written into
-- the real diary (Core/Sample.lua: ns.Sample.Write), and the book turns to
-- People with its real search set to his name, so only he shows, his own
-- page on the right and a strip over its foot, "An example", whose "Begin
-- your own diary →" takes him out again and turns to Your Diary. Every other
-- way out, from the sheet (a click beside it, Escape, the book closed, a
-- ribbon, a fight starting) or from the example (the book closed, a ribbon,
-- Escape, a fight), marks the introduction seen (introSeen) and takes Thex
-- out if he was written. A /reload in the middle of the example leaves him
-- for the next login to remove (Core/Events.lua, ADDON_LOADED), and the
-- introduction is marked seen as the example begins, so the same holds.
--
-- What offers it: the parcel's "Open me" (UI/Windows/Intro/Torn.lua), the
-- book opened on nobody while it is unseen (UI/Journal/Book.lua), /sd about
-- (Core/Slash.lua) and the settings' "Show the introduction again"
-- (UI/Settings/Page.lua), all through ns.UI.ShowIntro. A book opened on
-- someone never lays it.
--
-- Motion (MOTION) is one short OnUpdate on the host that runs the step's
-- tracks and stops itself, as the strip's hover and the plate's lean do: an
-- entrance a step at most 1.5 s, eased out (quart), never bouncing. Any click
-- during one finishes it, and the step's action works from its first frame.
-- A step gone back to (the progress marks) shows complete. "Flat paper only"
-- moves nothing: every step is shown complete, the sheet arrives at once,
-- and the sheet and everything on it lie straight.
--
-- Escape takes the sheet off the book and leaves the book open: while the
-- sheet is out, its host stands in the book's place in UISpecialFrames (as
-- the dungeon spread does, UI/Dungeon/Spread.lua's StandIn), swapped in
-- place, never added or removed.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local Tour = {}
ns.UI.Tour = Tour

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------

-- The sheet: its size on the book's 808 by 568 (about 40 px of book show
-- either side, 12 above and 16 below, so it reads as a sheet lying on the
-- book, and covers Your Diary's heading; the map sheet is 600 by 492), the
-- key it falls by, and how it lies: turned `turn` degrees (as SetRotation,
-- counter-clockwise: the mockup's -1.0) with its middle `at` px off the
-- book's (x right, y up). Its host's global name, for Escape. Its folds are
-- the map sheet's (CREASE) with the facets' light at half its slope
-- (`crease.light`, the map's 1.8): the map's print hides how the facets
-- differ, this sheet's bare paper does not. (2 Nov 2026, in the client: at
-- 520 px and 4 px down, the character's name showed over its top edge,
-- and at the map's light its middle third read as darker panels.)
local SHEET = { w = 720, h = 540, key = "intro", turn = 1.0, at = { 6, 2 }, name = "SocialDiaryIntroTour",
    book = "SocialDiaryJournalFrame", crease = { light = 0.9 } }
-- Where Your Diary's right page lies on the sheet (its top left): the plate,
-- its slot and the row of strips under it are the page's own
-- (UI/Journey/Look.lua's LAYOUT[1][1].top), from there.
local PAGE = { x = 20, y = 4 }
-- No fold through a strip (K.Clear): each fold moved at most `reach` px to
-- keep `pad` px clear of every strip in every state it takes.
local CLEAR = { reach = 120, pad = 6 }
-- Laid back: what earlier steps showed, at `alpha`, its leaders hidden.
local BACK = 0.32
-- Frame levels over the sheet: the leaders and arrows over the plate
-- (PLATE.level 5, its card's own frames to about 13 over that), the strips
-- over them, the progress marks' buttons with the strips.
local LEVEL = { lines = 20, strips = 25 }

-- The made-up road, fed to the real ink (UI/Ink/Trail.lua's Ink.Build) in
-- 0..1 of the plate's art box (424 by 323 px). A: the road alone (step 1).
-- B: the road, a 30-minute stop spent fighting and the road on (steps 2 to
-- 5); B's road lies on A's within a pixel. The stop says what was done there
-- as a recorded one does (its `act`: 15 of its 30 minutes in combat), and
-- its kind and tint come of that through the plate's own reading
-- (UI/Journey/Text/Tips.lua's StopKind: "fighting", Ink.TINT's rust).
-- `yards` how far a pixel of the box is (the trail's pxPerYard).
-- (2 Nov 2026, the user: the pool a fight, not a quest.)
local ROUTE = {
    A = { stops = {}, roads = {
        { from = 0, to = 700, pts = { 0.05, 0.88, 0.12, 0.84, 0.20, 0.78, 0.27, 0.72, 0.34, 0.66, 0.44, 0.60,
            0.53, 0.57, 0.62, 0.52, 0.71, 0.44, 0.80, 0.36, 0.90, 0.26, 0.96, 0.20 } } } },
    B = { stops = { { kind = "stop", from = 300, to = 2100, seconds = 1800, x = 0.34, y = 0.66,
        sdx = 0.016, sdy = 0.02, rho = 0.2, act = { combat = 900 } } },
        roads = {
            { from = 0, to = 300, pts = { 0.05, 0.88, 0.12, 0.84, 0.20, 0.78, 0.27, 0.72, 0.32, 0.68 } },
            { from = 2100, to = 2600, pts = { 0.36, 0.64, 0.44, 0.60, 0.53, 0.57, 0.62, 0.52, 0.71, 0.44,
                0.80, 0.36, 0.90, 0.26, 0.96, 0.20 } } } },
    yards = 0.1,
}
-- The marks, in px of the art box (y down): where the level began (6) and
-- the next was reached (7), the first green's pouch, where Bram saved you
-- (a rescue's mark) and the ring of the time spent with Thex.
local MARKS = { pin6 = { 24, 281, level = 6 }, pin7 = { 301, 142, level = 7 }, pouch = { 164, 232 },
    bram = { 226, 183 }, thex = { 372, 96 } }
-- A pin where a level began: ink round paper, `ring` px of ink (the plate's
-- PIN.ring).
local PIN = { ring = 1.5 }

-- The strips in the row under the plate (the slot's `row` boxes), their
-- turns as the mockup lays them (degrees, clockwise as there: SetRotation
-- takes them negated), and Thex's a little wider so "+ Add" has room.
local ROW = { find = { box = 1, turn = -1.0 }, bram = { box = 2, turn = 0.9 }, thex = { box = 3, turn = -1.3, w = 150 } }
-- The step strip: its top left on the sheet, its width and turn (clockwise),
-- and the most lines its words take (its fourth for the longer steps).
local STEP = { x = 498, y = 250, w = 200, turn = 0.8, lines = 5 }
-- The ending's strip: on the open book (x, y from its top left), its width
-- and turn (clockwise), a level over the person's page.
local ENDING = { x = 470, y = 400, w = 230, turn = -1.2, level = 30 }
-- The progress marks: five lozenges `size` px, `gap` apart, then "n of 5"
-- `text` px after them, the whole ending `right` px from the sheet's right
-- edge, its middle `top` px down. Passed ones in ink at `done`; the one to
-- come hollow, its edge `edge` px of ink at `done`. A passed one is a
-- button, `hit` px square: the way back to its step.
local PROGRESS = { size = 6, gap = 9, text = 4, right = 30, top = 17, done = 0.5, edge = 1, hit = 14 }
-- The red-brown of the instructions and their arrow: a pen stroke `width`
-- px at `alpha`, bowing `bow` of its length, its head two strokes `head` px
-- back from the point at `spread` radians either side; it leaves `from`
-- px along under the instruction's words and stops `short` px off its mark.
local RED = { 0.478, 0.165, 0.047 }
local ARROW = { width = 1.9, alpha = 0.9, bow = 0.12, head = 8, spread = 0.45, from = 24, short = 2, step = 4 }
-- Thex added: a drop of ink left before his name (5 px at .6), and the
-- blot it was before it dried (`peak`, reached `at` of the way in).
local BLOT = { size = 5, alpha = 0.6, peak = 0.92, at = 0.35, from = 0.2 }

-- The words. The step's heading in the hand, its words (at most 25), and its
-- foot: "Continue →" or the instruction. "30 days" is the live retention.
-- Each link that leads on ends in an arrow the strip draws (the fonts have
-- no "→": UI/Paper/Strip.lua's EXTRA.arrow), so its words end without one.
local CONTINUE = "Continue"
local STEPS = {
    { heading = "Social Diary",
        words = function() return "Wherever you go, the diary marks your path. Each level you reach gets a page like this." end },
    { heading = "What you did",
        words = function() return "Red splats show where you've fought. Memorable moments, such as finding your first green item, are shown in cards." end },
    { heading = "Who you met",
        words = function()
            return "Any player you interact with, is written down automatically, like Bram and Thex. After "
                .. ns.UI.Journal.PencilDays() .. " their data is deleted."
        end },
    { heading = "Keep one",
        words = function() return "To keep someone for good, add them to your diary." end,
        todo = "Add Thex now." },
    { heading = "Kept for good",
        words = function() return "Thex is in your diary now. When you meet again, the diary will tell you." end,
        todo = "Click him to see his page." },
}
local WORDS = {
    find = { heading = "Your first green!", item = "Wolfskin Bracers" },
    -- Bram: a stranger who saved you from Hogger with 8% of your health
    -- left. As a witness the player writes in (Core/Custom.lua's moment
    -- "witnessed"), the record the card reads: the deed, who, the creature
    -- (bare: "from Hogger", no article) and its rank, the health left, and
    -- the level you were. That record has no npcID (Hogger's is 448, level
    -- 11, elite, in Elwynn Forest): nothing on the card or its tooltip reads one.
    bram = { deed = "saved", name = "Bram Redfen", creature = "Hogger", rank = "elite", bare = "yes", pct = 8,
        level = 6 },
    thex = { minutes = 35 },
    add = "+ Add",
    progress = "%d of 5",
    ending = { heading = "An Example",
        words = "This is how the people you add will look.",
        begin = "Begin your own diary" },
}
-- The find card's item: a green leather bracer's picture from the client's
-- icons (a typed name has no link, so it takes the card's fallbacks, the
-- icon given here and the quality of a first green).
local ITEM = { icon = "Interface\\Icons\\INV_Bracer_07", whats = { "uncommon" } }

-- The steps' entrances (ms; step 1's from the sheet laid, its first
-- `arrive` its arrival, UI/Paper/Sheet.lua's ARRIVE): when each piece starts
-- and ends. The road shown in its build order at an even pace, pin 7
-- stamped (alpha 0 to 1, scale `stamp` to 1) as the line reaches it; a
-- pool's wash, dabs (in their build order), rim (round the pool) and drops
-- as it is left; leaders drawn as the pen goes; strips laid on (alpha, and a
-- slide from `slide` px). The step strip says its piece last (`say`), once
-- what it tells of has landed (the user's round of 2 Nov 2026, in the
-- client): the old words fade off at once (`out`), the new come in after
-- the step's own pieces, and its leader or arrow is drawn from it last.
-- On step 1 the whole strip comes in so.
local MOTION = {
    arrive = 240, stamp = 0.7, stampTime = 140, slide = { -3, -8 }, out = 200, back = 300,
    [1] = { road = { 240, 1000 }, pin = 760, say = { 1000, 1220 }, leader = { 1220, 1460 } },
    [2] = { wash = { 0, 200 }, dab = { 120, 480 }, rim = { 420, 640 }, drops = { 640, 720 }, pouch = 720,
        findLeader = { 800, 1000 }, card = { 900, 1120 }, say = { 1120, 1300 }, leader = { 1300, 1500 } },
    [3] = { bram = 0, thex = 150, bramLeader = { 300, 540 }, bramStrip = { 500, 760 }, thexLeader = { 620, 860 },
        thexStrip = { 820, 1080 }, say = { 1080, 1300 } },
    [4] = { add = { 100, 320 }, say = { 320, 540 }, arrow = { 540, 860 } },
    [5] = { blot = { 0, 520 }, name = { 60, 380 }, say = { 520, 740 }, arrow = { 740, 1060 } },
}

--------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------

-- The step shown (1 to 5) while the sheet is out, else nil.
Tour.step = nil
-- While the example is up (the People page with Thex): { filters } (the
-- People list's filters as they were, given back after), else nil.
Tour.example = nil

local function Flat() return ns.Setting("flatSheets") == true end

--------------------------------------------------------------------------
-- Motion: one OnUpdate, its tracks, finished at once on a click
--------------------------------------------------------------------------

local tracks, clock = {}, 0

local function Ease(t) return 1 - (1 - t) ^ 4 end

local function Stop()
    tracks, clock = {}, 0
    if Tour.host then Tour.host:SetScript("OnUpdate", nil) end
end

-- Every track at its end, at once (a click during an entrance).
local function Finish()
    local list = tracks
    Stop()
    for _, t in ipairs(list) do
        if not t.done then t.fn(1) end
    end
    if Tour.view then Tour.view:Land() end
end
Tour.Finish = Finish

local function Run(_, elapsed)
    clock = clock + (elapsed or 0)
    local live = false
    for _, t in ipairs(tracks) do
        if not t.done then
            local p = (clock - t.from) / math.max(t.to - t.from, 0.001)
            if p >= 1 then
                t.fn(1)
                t.done = true
            else
                live = true
                if p > 0 then t.fn(t.linear and p or Ease(p)) end
            end
        end
    end
    if not live then Stop() end
end

-- `fn(t)` from `from` to `to` ms into the step, t eased (or even, `linear`),
-- set at its start now.
local function Track(from, to, fn, linear)
    tracks[#tracks + 1] = { from = from / 1000, to = to / 1000, fn = fn, linear = linear }
    fn(0)
    Tour.host:SetScript("OnUpdate", Run)
end

--------------------------------------------------------------------------
-- Escape: the host in the book's place while the sheet is out
--------------------------------------------------------------------------

-- The pad told the sheet changed (a step, laid, put away, the example):
-- what it walks is found again (UI/Windows/Intro/Pad.lua).
local function Told()
    local Pad = ns.UI.Pad
    if Pad and Pad.Input.Active() then Pad.Refresh() end
end

local function StandIn(from, to)
    for i, name in ipairs(UISpecialFrames) do
        if name == from then
            UISpecialFrames[i] = to
            return
        end
    end
end

--------------------------------------------------------------------------
-- The sheet
--------------------------------------------------------------------------

local Go, Exit, Ending

-- A layer of the plate, shown a piece at a time: its textures in the order
-- they reveal, alpha on its frame.
local function Reveal(list, upto)
    local n = math.floor(#list * upto + 0.5)
    for i, texture in ipairs(list) do texture:SetShown(i <= n) end
end

local function Build(parent)
    local Ink, Pen, Plate = ns.UI.InkTrail, ns.UI.Pen, ns.UI.JourneyPlate
    local Look = ns.UI.JourneyLook
    local host = CreateFrame("Frame", SHEET.name, parent)
    host:SetAllPoints(parent)
    host:Hide()
    Tour.host = host

    local view, K = ns.UI.LooseSheet(host, SHEET.w, SHEET.h, { arrive = true, crease = SHEET.crease })
    local S = view.sheet
    -- Away until it is laid, so laying it rustles and arrives.
    view:Hide(true)
    Tour.container = parent
    Tour.view, Tour.K = view, K
    -- A click beside it puts it away; on it, finishes an entrance.
    view.onPutAway = function() host:Hide() end
    S:SetScript("OnMouseDown", function() Finish() end)

    -- A point of the flat sheet (x right, y down from its top left) where it
    -- lies on the sheet's frame (its top left, y down), turned and drifted
    -- with it, and back: what lies on the sheet without being cut along it
    -- (the plate, the strips) is placed through these, and the leaders
    -- between them are drawn back on the paper.
    local function Onto(x, y)
        local sx, sy = K.Screen(x, y)
        return SHEET.w / 2 + sx, SHEET.h / 2 - sy
    end
    local function Flatten(x, y)
        return K.Unscreen(x - SHEET.w / 2, SHEET.h / 2 - y)
    end

    -- Over the plate, the leaders and arrows; over them, the strips.
    local lines = CreateFrame("Frame", nil, S)
    lines:SetAllPoints(S)
    lines:SetFrameLevel(S:GetFrameLevel() + LEVEL.lines)
    local strips = CreateFrame("Frame", nil, S)
    strips:SetAllPoints(S)
    strips:SetFrameLevel(S:GetFrameLevel() + LEVEL.strips)

    ----------------------------------------------------------------------
    -- The plate: Your Diary's one-plate slot with its caption on top, the
    -- card blank stock (no map), glued onto the sheet and turned with it

    local slot = Look.LAYOUT[1][1].top
    local plate = Plate(S, slot)
    Tour.plate = plate
    local art = { w = slot.w - 2 * slot.pad, h = slot.h - 2 * slot.pad }
    local layers = {}
    local function Layer(key, level)
        local frame, kit = plate:Layer(level)
        layers[key] = { frame = frame, kit = kit, list = {} }
        return layers[key]
    end
    for _, key in ipairs({ "roadA", "roadB" }) do Layer(key, 1) end
    Layer("pool", 2)
    for _, key in ipairs({ "pin6", "pin7", "pouch", "bram", "thex" }) do Layer(key, 3) end
    Tour.layers = layers

    -- The trail's primitives onto a layer, each on a texture of its own
    -- from a pool of its sublevel (Ink.LAYER); `list` in the order they
    -- were made, the order they show.
    local function Ink2(layer, prims)
        local pools = {}
        for _, prim in ipairs(prims) do
            local pool = pools[prim.layer]
            if not pool then
                pool = layer.kit.Pool("ARTWORK", prim.layer)
                pool:Begin()
                pools[prim.layer] = pool
            end
            local texture = pool:Next()
            layer.kit.Prim(prim, texture)
            layer.list[#layer.list + 1] = { texture = texture, prim = prim }
        end
        table.sort(layer.list, function(a, b) return a.prim.n < b.prim.n end)
        local textures = {}
        for i, each in ipairs(layer.list) do textures[i] = each.texture end
        layer.textures = textures
    end

    -- A mark on its layer: drawn through the marks' kit (Plate.MarkKit) at
    -- `scale` of its size about where it lies (a stamp grows into place).
    local function Mark(layer, at, draw)
        local mx, my = slot.pad + at[1], slot.pad + at[2]
        local scale = 1
        local K2 = layer.kit
        local function place(region, x, y, w, h, turn)
            local cx, cy = mx + (x - mx) * scale, my + (y - my) * scale
            K2.Place(region, cx - w * scale / 2, cy - h * scale / 2, w * scale, h * scale, turn)
        end
        local function quad(region, ...)
            local p = { ... }
            for k = 1, #p, 2 do
                p[k], p[k + 1] = mx + (p[k] - mx) * scale, my + (p[k + 1] - my) * scale
            end
            return K2.Quad(region, unpack(p))
        end
        local kit = Plate.MarkKit(layer.frame, place, quad, plate.paper)
        layer.at, layer.marks = { mx, my }, kit
        function layer:Draw(s)
            scale = s or 1
            kit:Begin()
            draw(kit, mx, my)
            kit:Finish()
        end
        return layer
    end

    -- The pins: the level begun in ink round paper, its number in ink; the
    -- next reached a rubric disc, its number light (the plate's own Pin).
    local MARK = Plate.MARK
    local function Pin(layer, spec, begun)
        local number = layer.kit.Text(FONT.tag)
        number:SetText(tostring(spec.level))
        layer.number = number
        Mark(layer, spec, function(kit, x, y)
            local size = math.max(MARK.pin, layer.kit.Width(number) + MARK.pinPad)
            kit.Dot(kit.halo, x, y, size + 4, plate.paper, MARK.halo)
            local text = Style.TAG_TEXT
            if begun then
                kit.Dot(kit.ink, x, y, size, Style.INK_STRONG, 0.92)
                kit.Dot(kit.inner, x, y, size - 2 * PIN.ring, plate.paper, 1)
                text = Style.INK_STRONG
            else
                kit.Dot(kit.ink, x, y, size, Style.RUBRIC, 0.92)
            end
            number:SetTextColor(text[1], text[2], text[3])
            layer.kit.PlaceText(number, x, y, "CENTER")
        end)
    end
    Pin(layers.pin6, MARKS.pin6, true)
    Pin(layers.pin7, MARKS.pin7, false)

    -- The first green's pouch: the registered find mark's own drawing, in
    -- the ink its `arg` gives a first green (part way to a green's), through
    -- the registry, as the plate draws it (Plate.RegisterMark; the core
    -- names no feature). None where no kind "find" is registered.
    Mark(layers.pouch, MARKS.pouch, function(kit, x, y)
        local find = Plate.MARKS.find
        if not find then return end
        local colour = find.arg and find.arg({ { what = "uncommon", t = 0, kind = "find" } })
        if find.halo then kit.Dot(kit.halo, x, y, find.halo, plate.paper, MARK.halo) end
        find.draw(kit, x, y, colour)
    end)
    -- Time spent together with Thex: the ring of a session
    -- (Plate.SHAPE.session).
    Mark(layers.thex, MARKS.thex, function(kit, x, y)
        kit.Dot(kit.halo, x, y, MARK.together + 4, plate.paper, MARK.halo)
        Plate.SHAPE.session(kit, x, y)
    end)
    -- Where Bram saved you: a witness's own registered mark ("witnessed"),
    -- which for a rescue is the close call's, through the registry as the
    -- plate draws it (the core names no feature). Its witness, made of the
    -- record by the mark's own `choose`, is what Bram's card is written of.
    local bramMark = { at = { slot.pad + MARKS.bram[1], slot.pad + MARKS.bram[2] },
        list = { { kind = "witnessed", witnessed = WORDS.bram } } }
    WORDS.bram.t = ns.Now()
    Mark(layers.bram, MARKS.bram, function(kit, x, y)
        local spec = Plate.MARKS.witnessed
        if not spec then return end
        local arg = spec.arg and spec.arg(bramMark.list)
        if spec.halo then kit.Dot(kit.halo, x, y, spec.halo, plate.paper, MARK.halo) end
        spec.draw(kit, x, y, arg)
    end)

    ----------------------------------------------------------------------
    -- The strips

    local row = slot.row
    local function Box(which) return row[ROW[which].box] end

    -- The find card is the margin's own "find" kind (ns.UI.JourneyMargin),
    -- made and written through its registration as the page does: an item
    -- with no link, so it takes the card's fallbacks, the icon given.
    local findKind = ns.UI.JourneyMargin.KINDS.find
    local find = findKind.new(strips)
    findKind.write(find, { item = { link = nil, whats = ITEM.whats, moments = {}, rec = { name = WORDS.find.item },
        icon = ITEM.icon, short = true } }, { Seed = function() return "intro-find" end, now = ns.Now(), named = {} })
    -- Bram's card: the margin's own written-witness kind, a stranger's (no
    -- page to open), written of the witness the mark chose. Nothing of it is
    -- saved: the record lives in WORDS.bram.
    local witnessKind = ns.UI.JourneyMargin.KINDS.witnessCustom
    local bram = witnessKind.new(strips)
    local saved = Plate.MARKS.witnessed.choose({ bramMark })[1]
    witnessKind.write(bram, { witness = saved }, { Seed = function() return "intro-bram" end, now = ns.Now() })
    Tour.saved = saved
    local thex = ns.UI.PaperStrip(strips)
    local step = ns.UI.PaperStrip(strips)
    -- The step strip's words as they were, over the new ones while they
    -- cross-fade: the same slip, so only the words change.
    local ghost = ns.UI.PaperStrip(strips)
    ghost:SetFrameLevel(step:GetFrameLevel() + 3)
    Tour.strips = { find = find, bram = bram, thex = thex, step = step, ghost = ghost }

    -- Thex's strip in step `n`: a stranger's (3), with "+ Add" on his
    -- name's line (4), added (5: in strong ink, written as a link, a blot
    -- left before his name).
    local function ThexNote(n)
        local note = { name = ns.Sample.NAME, seed = "intro-thex",
            what = ns.UI.Format.Duration(WORDS.thex.minutes * 60) .. " together" }
        if n == 4 then
            note.aside = { text = WORDS.add, font = FONT.body, onClick = function() Tour.Add() end }
        elseif n >= 5 then
            note.guid, note.underlined = ns.Sample.GUID, true
            note.onClick = function() Ending() end
            note.blot = { size = BLOT.size, alpha = BLOT.alpha }
        end
        return note
    end
    -- The step strip's note in step `n`.
    local function StepNote(n, tall)
        local s = STEPS[n]
        local foot = s.todo and { text = s.todo, font = FONT.body, colour = RED }
            or { text = CONTINUE, font = FONT.strong, arrow = true, onClick = function() Tour.Continue() end }
        return { name = s.heading, strong = true, what = s.words(), ink = Style.INK, lines = STEP.lines,
            seed = "intro-step", tall = tall, foot = foot }
    end

    -- A strip laid with its top left at x, y of the flat sheet, at most
    -- `width` wide, turned `turn` degrees (clockwise) on the sheet: placed
    -- where the sheet takes that point, and turned with the sheet.
    local function LayStrip(strip, x, y, width, turn)
        strip.note.tilt = math.deg(view.angle or 0) - turn
        local w, h = strip:Layout(x, y, width)
        local cx, cy = Onto(x + w / 2, y + h / 2)
        w, h = strip:Layout(cx - w / 2, cy - h / 2, width)
        strip.at = { cx, cy }
        return w, h
    end

    ----------------------------------------------------------------------
    -- Leaders and arrows: the page's pencil (LEADER) and the instructions'
    -- red-brown pen, on the sheet, each its own textures

    local Texture = K.Texture
    local function Line()
        local line = { strokes = {}, dot = Texture("OVERLAY", 2, lines) }
        line.dot:Hide()
        return line
    end
    local function Stroke(line, k)
        local t = line.strokes[k]
        if not t then
            t = Texture("OVERLAY", 1, lines)
            line.strokes[k] = t
        end
        return t
    end

    -- A pen along `points` (frame px, x, y, ...) in `colour` at `alpha`,
    -- `width` wide (its nib `nib`, tapered `taper` off its start): onto the
    -- sheet as quads, each a texture of the line's; the rest hidden.
    local function Ink3(line, points, colour, alpha, width, nib, taper, step)
        local flat = {}
        for k = 1, #points, 2 do flat[k], flat[k + 1] = Flatten(points[k], points[k + 1]) end
        local P = Pen.Resample(flat, step)
        local prims = {}
        if #P >= 2 then
            local M, n = Pen.Mitres(P), #P
            Pen.Stroke(prims, 0, P, M, function(i)
                local a, b = P[math.max(i - 1, 1)], P[math.min(i + 1, n)]
                local t = taper and (taper.from + (1 - taper.from) * math.min(1, P[i].s / taper.over)) or 1
                return width / 2 * Pen.Nib(b.x - a.x, b.y - a.y, nib) * t
            end, function() return 0 end, function() return alpha end, colour)
        end
        line.shown = {}
        for k, q in ipairs(prims) do
            local t = Stroke(line, k)
            t:SetColorTexture(q.r, q.g, q.b, q.a)
            if not K.Quad(t, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
                local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
                local len = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)
                K.Place(t, (sx + ex) / 2 - len / 2, (sy + ey) / 2 - width / 2, len + 0.5, width,
                    math.atan2(-(ey - sy), ex - sx))
            end
            line.shown[k] = t
        end
        for k = #prims + 1, #line.strokes do line.strokes[k]:Hide() end
    end

    -- A curve from a to b (frame px) bowing `bow` of its length toward the
    -- sheet's foot: `steps` points along it.
    local function Curve(ax, ay, bx, by, bow, steps)
        local dx, dy = bx - ax, by - ay
        local length = math.sqrt(dx * dx + dy * dy)
        local nx, ny = -dy / math.max(length, 0.01), dx / math.max(length, 0.01)
        if ny < 0 then nx, ny = -nx, -ny end
        local kx, ky = (ax + bx) / 2 + nx * bow * length, (ay + by) / 2 + ny * bow * length
        local points = {}
        for i = 0, steps do
            local t, u = i / steps, 1 - i / steps
            points[#points + 1] = u * u * ax + 2 * u * t * kx + t * t * bx
            points[#points + 1] = u * u * ay + 2 * u * t * ky + t * t * by
        end
        return points
    end

    -- A strip's leader to a mark (frame px): from the strip's edge nearest
    -- it to `stop` px short of it, in a pencil dot (the page's LEADER).
    local function Leader(line, strip, mx, my)
        local L = Look.LEADER
        local sx, sy = strip:Nearest(mx, my)
        local dx, dy = mx - sx, my - sy
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= L.stop + 1 then return end
        local tx, ty = mx - dx / d * L.stop, my - dy / d * L.stop
        Ink3(line, Curve(sx, sy, tx, ty, L.bow, L.pen.curve), L.colour, L.alpha, L.pen.width, L.pen.nib, L.pen.taper,
            L.pen.step)
        line.live = true
        local C = L.colour
        Style.Disc(line.dot, C[1], C[2], C[3], L.dotAlpha)
        local fx, fy = Flatten(tx, ty)
        K.Place(line.dot, fx - L.dot / 2, fy - L.dot / 2, L.dot, L.dot)
    end

    -- The arrow from under the instruction to the point x, y (frame px):
    -- the red-brown pen, bowed, and its head.
    local function Arrow(line, foot, x, y)
        local at = foot.at
        local ax, ay = at.x - at.w / 2 + ARROW.from, at.y + at.h / 2 + 2
        local dx, dy = x - ax, y - ay
        local d = math.sqrt(dx * dx + dy * dy)
        local tx, ty = x - dx / d * ARROW.short, y - dy / d * ARROW.short
        local points = Curve(ax, ay, tx, ty, ARROW.bow, 16)
        -- The head: back from the point along the way the shaft came in.
        local n = #points
        local back = math.atan2(points[n - 2] - ty, points[n - 3] - tx)
        Ink3(line, points, RED, ARROW.alpha, ARROW.width, { angle = 40, thin = 0.9, thick = 1.1 }, nil, ARROW.step)
        line.live = true
        line.head = line.head or { Texture("OVERLAY", 1, lines), Texture("OVERLAY", 1, lines) }
        for k, side in ipairs({ -ARROW.spread, ARROW.spread }) do
            local a = back + side
            local hx, hy = tx + ARROW.head * math.cos(a), ty + ARROW.head * math.sin(a)
            local fx1, fy1 = Flatten(tx, ty)
            local fx2, fy2 = Flatten(hx, hy)
            local len = math.sqrt((fx2 - fx1) ^ 2 + (fy2 - fy1) ^ 2)
            local t = line.head[k]
            t:SetColorTexture(RED[1], RED[2], RED[3], ARROW.alpha)
            K.Place(t, (fx1 + fx2) / 2 - len / 2, (fy1 + fy2) / 2 - ARROW.width / 2, len + 0.5, ARROW.width,
                math.atan2(-(fy2 - fy1), fx2 - fx1))
            line.shown[#line.shown + 1] = t
        end
    end

    -- A line shown `upto` of the way along (all of it at 1, its dot with it).
    local function Draw(line, upto)
        if not line.live then
            line.dot:Hide()
            return
        end
        local n = math.floor(#(line.shown or {}) * upto + 0.5)
        for k, t in ipairs(line.shown or {}) do t:SetShown(k <= n) end
        line.dot:SetShown(line.hasDot == true and upto >= 1)
    end
    local function Hidden(line)
        line.live, line.shown = false, {}
        for _, t in ipairs(line.strokes) do t:Hide() end
        for _, t in ipairs(line.head or {}) do t:Hide() end
        line.dot:Hide()
    end

    local LINES = { stepPin = Line(), stepPool = Line(), find = Line(), bram = Line(), thex = Line(),
        add = Line(), name = Line() }
    for _, key in ipairs({ "stepPin", "stepPool", "find", "bram", "thex" }) do LINES[key].hasDot = true end
    Tour.lines = LINES

    ----------------------------------------------------------------------
    -- The progress marks

    local marks = {}
    for k = 1, 5 do
        local m = { edge = Texture("OVERLAY", 3), hole = Texture("OVERLAY", 4) }
        m.button = CreateFrame("Button", nil, S)
        m.button:SetFrameLevel(S:GetFrameLevel() + LEVEL.strips)
        m.button:SetScript("OnClick", function()
            if Tour.step and k < Tour.step then Go(k, false) end
        end)
        marks[k] = m
    end
    local count = Style.Text(S, FONT.small)
    Tour.progress = { marks = marks, count = count }

    local function Lozenge(t, x, y, size, c, a)
        t:SetColorTexture(c[1], c[2], c[3], a)
        K.Place(t, x - size / 2, y - size / 2, size, size, math.pi / 4)
        t:Show()
    end
    local function Progress(n)
        local P = PROGRESS
        count:SetText(WORDS.progress:format(n))
        local left = K.PlaceText(count, SHEET.w - P.right, P.top, "RIGHT")
        for k, m in ipairs(marks) do
            local x = left - P.text - P.size / 2 - (5 - k) * (P.size + P.gap)
            if k == n then
                Lozenge(m.edge, x, P.top, P.size, Style.RUBRIC, 1)
                m.hole:Hide()
            elseif k < n then
                Lozenge(m.edge, x, P.top, P.size, Style.INK, P.done)
                m.hole:Hide()
            else
                Lozenge(m.edge, x, P.top, P.size, Style.INK, P.done)
                local inner = P.size - 2 * P.edge
                Lozenge(m.hole, x, P.top, inner, view.paper, 1)
            end
            m.passed = k < n
            K.PlaceButton(m.button, x - P.hit / 2, P.top - P.hit / 2, P.hit, P.hit)
            m.button:EnableMouse(k < n)
            m.button:SetShown(k < n)
        end
    end

    ----------------------------------------------------------------------
    -- Laying it: the sheet, the plate and its ink, the strips

    -- The flat boxes of the strips in every state they take (measured),
    -- for the folds to keep clear of.
    local function Measure(strip, width)
        local w, h = strip:Layout(0, 0, width)
        return w, h
    end

    function host:Lay()
        local flat = Flat()
        -- Each strip's size, in its widest state, before the sheet is laid.
        local boxes = {}
        local function Note(key, x, y, w, h) boxes[key] = { x = x, y = y, w = w, h = h } end
        local fb, bb, tb = Box("find"), Box("bram"), Box("thex")
        find.note.tilt = 0
        Note("find", PAGE.x + fb.x, PAGE.y + fb.y, Measure(find, fb.w))
        bram.note.tilt = 0
        Note("bram", PAGE.x + bb.x, PAGE.y + bb.y, Measure(bram, bb.w))
        local tw, th = 0, 0
        for n = 3, 5 do
            thex:SetNote(ThexNote(n))
            local w, h = Measure(thex, ROW.thex.w)
            tw, th = math.max(tw, w), math.max(th, h)
        end
        Note("thex", PAGE.x + tb.x, PAGE.y + tb.y, tw, th)
        local tall = 0
        for n = 1, 5 do
            step:SetNote(StepNote(n))
            local _, h = Measure(step, STEP.w)
            tall = math.max(tall, h)
        end
        Tour.tall = tall
        Note("step", STEP.x, STEP.y, STEP.w, tall)
        Tour.boxes = boxes

        -- The sheet, its folds kept off the strips: a spot for each
        -- strip's width (for the folds across) and one for its height (for
        -- the fold down), each far off the other way.
        K.Fall(SHEET.key, flat and 0 or math.rad(SHEET.turn), SHEET.at)
        local spots = {}
        for _, b in pairs(boxes) do
            spots[#spots + 1] = { x = b.x + b.w / 2, y = -1e6, r = b.w / 2 }
            spots[#spots + 1] = { x = -1e6, y = b.y + b.h / 2, r = b.h / 2 }
        end
        K.Clear(spots, CLEAR.reach, CLEAR.pad)
        K.Lay()

        -- The plate, glued where the sheet takes its slot, turned with it.
        local px, py = PAGE.x + slot.x, PAGE.y + slot.y
        local cx, cy = Onto(px + slot.w / 2, py + slot.h / 2)
        plate:SetSlot(setmetatable({ x = cx - slot.w / 2, y = cy - slot.h / 2,
            t = (slot.t or 0) - math.deg(view.angle or 0) }, { __index = slot }))
        plate:Draw({ mapID = nil, stops = {}, roads = {}, flights = {}, pins = {} }, { from = 0, to = 0 }, { 0, 0, 1, 1 },
            { moments = {}, fights = {}, now = ns.Now() })
        -- A plate is made hidden and shown by whoever draws it (the page's
        -- Plated, UI/Journey/Caption.lua). (2 Nov 2026, in the client: left
        -- hidden, the sheet showed its strips and leaders on bare paper.)
        plate:Show()
        -- Its ink, made up: the two roads and the pool, each on its layer.
        local box = { at = function(x, y) return plate.At(x, y) end, fullW = art.w, fullH = art.h,
            pxPerYard = ROUTE.yards }
        local opts = { kind = ns.UI.JourneyText.StopKind }
        local primsA = Ink.Build(ROUTE.A, box, opts)
        local primsB, _, pools = Ink.Build(ROUTE.B, box, opts)
        local road, pool = {}, {}
        for _, prim in ipairs(primsB) do
            if prim.part == "pool" then pool[#pool + 1] = prim else road[#road + 1] = prim end
        end
        for _, key in ipairs({ "roadA", "roadB", "pool" }) do layers[key].list = {} end
        Ink2(layers.roadA, primsA)
        Ink2(layers.roadB, road)
        Ink2(layers.pool, pool)
        -- The pool's pieces by what they are, for its entrance: wash, dabs
        -- (as made), rim (round the pool), and the drops as it is left.
        local L, e = Ink.LAYER, pools[1] and pools[1].e or { x = 0, y = 0 }
        local parts = { wash = {}, dab = {}, rim = {}, drops = {} }
        for _, each in ipairs(layers.pool.list) do
            local l = each.prim.layer
            local into = (l == L.wash or l == L.halo) and parts.wash or l == L.dab and parts.dab
                or (l == L.rim or l == L.nib) and parts.rim or parts.drops
            into[#into + 1] = each
        end
        local function Angle(p)
            local x = p.k == "q" and (p.x1 + p.x2 + p.x3 + p.x4) / 4 or p.x
            local y = p.k == "q" and (p.y1 + p.y2 + p.y3 + p.y4) / 4 or p.y
            return math.atan2(y - e.y, x - e.x)
        end
        table.sort(parts.rim, function(a, b) return Angle(a.prim) < Angle(b.prim) end)
        for key, list in pairs(parts) do
            local textures = {}
            for i, each in ipairs(list) do textures[i] = each.texture end
            parts[key] = textures
        end
        layers.pool.parts = parts
        Tour.pool = e
        -- For the tests: what the pool was read as (its kind, its tint).
        Tour.poolKind, Tour.poolTint = pools[1] and pools[1].kind, pools[1] and pools[1].tint
        for _, key in ipairs({ "pin6", "pin7", "pouch", "bram", "thex" }) do layers[key]:Draw(1) end

        -- The strips, where the sheet takes their boxes.
        LayStrip(find, boxes.find.x, boxes.find.y, fb.w, ROW.find.turn)
        LayStrip(bram, boxes.bram.x, boxes.bram.y, bb.w, ROW.bram.turn)
    end

    -- Where a mark lies on the sheet's frame (its art-box px).
    local function MarkAt(key)
        return plate:SheetToPage(slot.pad + MARKS[key][1], slot.pad + MARKS[key][2])
    end

    -- Step `n` as it ends: every layer shown, laid back or hidden, the
    -- strips written, the lines drawn.
    function host:Compose(n)
        local function Alpha(key, a)
            local frame = layers[key].frame
            frame:SetShown(a ~= nil)
            if a then frame:SetAlpha(a) end
        end
        Alpha("roadA", n == 1 and 1 or nil)
        Alpha("roadB", n >= 2 and BACK or nil)
        Alpha("pin6", n == 1 and 1 or BACK)
        Alpha("pin7", n == 1 and 1 or BACK)
        local poolA = n == 2 and 1 or (n > 2 and BACK or nil)
        Alpha("pool", poolA)
        Alpha("pouch", poolA)
        local bramA = n == 3 and 1 or (n > 3 and BACK or nil)
        Alpha("bram", bramA)
        Alpha("thex", n >= 3 and 1 or nil)
        for _, key in ipairs({ "roadA", "roadB", "pool" }) do Reveal(layers[key].textures or {}, 1) end
        for _, key in ipairs({ "pin6", "pin7", "pouch", "bram", "thex" }) do layers[key]:Draw(1) end

        local function StripAt(strip, a)
            strip:SetShown(a ~= nil)
            if a then strip:SetAlpha(a) end
        end
        StripAt(find, poolA)
        StripAt(bram, bramA)
        if n >= 3 then
            thex:SetNote(ThexNote(n))
            local tb = Tour.boxes.thex
            LayStrip(thex, tb.x, tb.y, ROW.thex.w, ROW.thex.turn)
            thex:SetAlpha(1)
        else
            thex:Hide()
        end
        step:SetNote(StepNote(n, Tour.tall))
        LayStrip(step, STEP.x, STEP.y, STEP.w, STEP.turn)
        step:SetAlpha(1)
        ghost:Hide()

        for _, line in pairs(LINES) do Hidden(line) end
        if n == 1 then
            Leader(LINES.stepPin, step, MarkAt("pin7"))
        elseif n == 2 then
            Leader(LINES.stepPool, step, plate:SheetToPage(Tour.pool.x, Tour.pool.y))
            Leader(LINES.find, find, MarkAt("pouch"))
        end
        if n == 3 then Leader(LINES.bram, bram, MarkAt("bram")) end
        if n >= 3 then Leader(LINES.thex, thex, MarkAt("thex")) end
        if n == 4 then
            local a = thex.aside.at
            Arrow(LINES.add, step.foot, a.x, a.y - a.h / 2)
        elseif n == 5 then
            local b = thex.nameBox
            Arrow(LINES.name, step.foot, thex:Out((b[1] + b[3]) / 2, b[2] + 2))
        end
        for _, line in pairs(LINES) do Draw(line, 1) end
        Progress(n)
    end

    -- Its entrance from step `from` (nil: the sheet just laid).
    function host:Enter(n, from)
        local M = MOTION[n]
        -- Step 1's times count from the sheet's arrival (its first 240 ms).
        local off = 0
        local function Back(key, frame)
            frame = frame or layers[key].frame
            Track(off, off + MOTION.back, function(t) frame:SetAlpha(BACK + (1 - BACK) * (1 - t)) end)
        end
        local function Stamp(key, at)
            local layer = layers[key]
            Track(off + at, off + at + MOTION.stampTime, function(t)
                layer.frame:SetAlpha(t)
                layer:Draw(MOTION.stamp + (1 - MOTION.stamp) * t)
            end)
        end
        local function Pen(line, span)
            Track(off + span[1], off + span[2], function(t) Draw(line, t) end, true)
        end
        local function Lay(strip, span)
            local cx, cy = strip.at and strip.at[1], strip.at and strip.at[2]
            local box = strip.box
            if not box then return end
            local mx, my = box[1] + box[3] / 2, box[2] + box[4] / 2
            Track(off + span[1], off + span[2], function(t)
                strip:SetAlpha(t)
                strip:ClearAllPoints()
                strip:SetPoint("CENTER", strips, "TOPLEFT", mx + MOTION.slide[1] * (1 - t),
                    -(my + MOTION.slide[2] * (1 - t)))
            end)
        end
        -- The step strip's words (its paper stays): each piece of writing
        -- on it at `a`.
        local function Say(a)
            step.name:SetAlpha(a)
            for _, line in ipairs(step:WhatLines()) do line:SetAlpha(a) end
            local foot = step.foot
            foot.label:SetAlpha(a)
            foot.line:SetAlpha(a)
            for _, t in ipairs(foot.arrow or {}) do t:SetAlpha(a) end
        end
        -- The old words lie over the new on a slip just like it, fading off
        -- at once; the new come in last (M.say). Step 1's whole strip.
        if from ~= nil then
            ghost:SetNote(StepNote(from, Tour.tall))
            ghost.note.foot.onClick = nil
            LayStrip(ghost, STEP.x, STEP.y, STEP.w, STEP.turn)
            Track(0, MOTION.out, function(t) ghost:SetAlpha(1 - t) end)
            Track(MOTION.out, MOTION.out, function(t) if t >= 1 then ghost:Hide() end end)
            Track(M.say[1], M.say[2], Say)
        else
            Track(M.say[1], M.say[2], function(t) step:SetAlpha(t) end)
        end

        if n == 1 then
            local road = layers.roadA.textures
            Track(off + M.road[1], off + M.road[2], function(t) Reveal(road, t) end, true)
            Stamp("pin7", M.pin)
            Pen(LINES.stepPin, M.leader)
        elseif n == 2 then
            layers.roadB.frame:SetAlpha(1)
            Back("roadB")
            Back("pin6")
            Back("pin7")
            local parts = layers.pool.parts
            for _, key in ipairs({ "wash", "dab", "rim", "drops" }) do
                local list = parts[key]
                Track(M[key][1], M[key][2], function(t) Reveal(list, t) end, true)
            end
            Pen(LINES.stepPool, M.leader)
            Stamp("pouch", M.pouch)
            Pen(LINES.find, M.findLeader)
            Lay(find, M.card)
        elseif n == 3 then
            for _, key in ipairs({ "pool", "pouch" }) do Back(key) end
            Back(nil, find)
            Stamp("bram", M.bram)
            Stamp("thex", M.thex)
            Pen(LINES.bram, M.bramLeader)
            Lay(bram, M.bramStrip)
            Pen(LINES.thex, M.thexLeader)
            Lay(thex, M.thexStrip)
        elseif n == 4 then
            Back("bram")
            Back(nil, bram)
            local aside = thex.aside
            Track(M.add[1], M.add[2], function(t)
                aside.label:SetAlpha(t)
                aside.line:SetAlpha(t)
            end)
            Pen(LINES.add, M.arrow)
        elseif n == 5 then
            local blot, at = thex.blot, thex.blotAt
            local I = Style.INK_STRONG
            Track(M.blot[1], M.blot[2], function(t)
                local grow = math.min(1, t / BLOT.at)
                local size = at.size * (BLOT.from + (1 - BLOT.from) * grow)
                local a = t < BLOT.at and BLOT.peak * grow or BLOT.peak + (BLOT.alpha - BLOT.peak) * (t - BLOT.at) / (1 - BLOT.at)
                Style.Disc(blot, I[1], I[2], I[3], a)
                thex:Lay(blot, at.lx, at.ly, size, size)
            end, true)
            local C = Style.INK
            Track(M.name[1], M.name[2], function(t)
                thex.name:SetTextColor(C[1] + (I[1] - C[1]) * t, C[2] + (I[2] - C[2]) * t, C[3] + (I[3] - C[3]) * t)
            end)
            Pen(LINES.name, M.arrow)
        end
    end

    -- Put away however it goes (beside it, Escape, the book closed or
    -- turned, a fight): an early way out, unless the ending did it.
    host:SetScript("OnHide", function() if Tour.step then Exit() end end)

    return host
end

--------------------------------------------------------------------------
-- The steps
--------------------------------------------------------------------------

-- To step `n`: with its entrance (`enter`, not laid flat), or complete.
function Go(n, enter)
    local host = Tour.host
    local from = Tour.step
    Finish()
    Tour.step = n
    host:Compose(n)
    if enter and not Flat() then host:Enter(n, from) end
    Told()
end
Tour.Go = Go

-- "Continue →" (steps 1 to 3).
function Tour.Continue()
    if not Tour.step or Tour.step > 3 then return end
    Go(Tour.step + 1, true)
end

-- "+ Add" on Thex's strip (step 4): written in ink, as Recently nearby's
-- Add sounds, though nothing is written yet.
function Tour.Add()
    if Tour.step ~= 4 then return end
    Style.PlaySound("write")
    Go(5, true)
end

-- Lays the sheet on the open book at step 1, if it is not out already.
-- Never in a fight, which would put it away again: the book opens without
-- it, and an unseen introduction is offered the next time it opens.
function Tour.Lay()
    local J = ns.UI.Journal
    if Tour.step or not J.journal or InCombatLockdown() then return end
    -- A run out on the table goes first: Escape is the book's again.
    if J.visit and ns.UI.DungeonPage and ns.UI.DungeonPage.Close then ns.UI.DungeonPage.Close(true) end
    if ns.UI.Parcel and ns.UI.Parcel.HideSlip then ns.UI.Parcel.HideSlip() end
    local host = Tour.host or Build(J.journal.views.journey)
    Finish()
    host:Show()
    host:Lay()
    StandIn(SHEET.book, SHEET.name)
    Tour.step = 1
    host:Compose(1)
    Tour.view:Show()
    if not Flat() then host:Enter(1, nil) end
    Told()
end

-- The sheet's way out, any but the ending: seen, and Thex gone if he was
-- written. The book stays on the page it was on.
function Exit()
    if not Tour.step then return end
    Tour.step = nil
    Stop()
    ns.SetSetting("introSeen", true)
    if ns.Sample.Present() then ns.Sample.Remove() end
    StandIn(SHEET.name, SHEET.book)
    local host = Tour.host
    if host:IsShown() then host:Hide() end
    Tour.view:Hide(true)
    -- Put away while the book lies open (a click beside it, Escape, a
    -- fight), it rustles; gone with its page or the book, it is silent.
    if Tour.container:IsVisible() then Style.PlaySound("sheetClose") end
    Told()
end
Tour.Exit = Exit

--------------------------------------------------------------------------
-- The ending: Thex in the book
--------------------------------------------------------------------------

-- The People list's filters, kept aside while only Thex shows.
local FILTERS = { "tag", "relationship", "faction", "zone", "withinDays" }

local endStrip

local function LayEnding()
    local J = ns.UI.Journal
    local container = J.journal.views.people
    if not endStrip then
        local frame = CreateFrame("Frame", nil, container)
        frame:SetAllPoints(container)
        frame:SetFrameLevel(container:GetFrameLevel() + ENDING.level)
        endStrip = ns.UI.PaperStrip(frame)
        Tour.endStrip = endStrip
    end
    endStrip:SetNote({ name = WORDS.ending.heading, strong = true, what = WORDS.ending.words, ink = Style.INK,
        lines = STEP.lines, seed = "intro-ending", tilt = -ENDING.turn, light = true,
        foot = { text = WORDS.ending.begin, font = FONT.strong, arrow = true, onClick = function() Tour.Begin() end } })
    endStrip:Layout(ENDING.x, ENDING.y, ENDING.w)
end

-- Thex's name clicked (step 5): the sheet put away, Thex written, the book
-- turned to People with only him in it.
function Ending()
    if Tour.step ~= 5 then return end
    Finish()
    Tour.step = nil
    StandIn(SHEET.name, SHEET.book)
    Tour.host:Hide()
    Tour.view:Hide(true)
    Style.PlaySound("sheetClose")
    local Sample, J = ns.Sample, ns.UI.Journal
    if not Sample.Present() then Sample.Write() end
    -- Seen from here on: a /reload now leaves Thex for the next login to
    -- take out (Core/Events.lua), and the tour is not offered again.
    ns.SetSetting("introSeen", true)
    local kept = {}
    for _, key in ipairs(FILTERS) do
        kept[key] = J.query[key]
        J.query[key] = nil
    end
    Tour.example = { filters = kept }
    -- The real search, as typed: the box's own callback finds the query
    -- already set.
    J.query.search = Sample.NAME
    if J.journal and J.journal.search then J.journal.search:SetText(Sample.NAME) end
    Style.PlaySound("pageTurn")
    ns.UI.ShowJournal(Sample.GUID)
    LayEnding()
    Told()
end
Tour.Ending = function() Ending() end

-- The example left, however: Thex gone, the search cleared and the filters
-- back, seen. `begin`: by its own link, which turns to Your Diary.
local function Leave(begin)
    local example = Tour.example
    if not example then return end
    Tour.example = nil
    local J = ns.UI.Journal
    if endStrip then endStrip:Hide() end
    if ns.Sample.Present() then ns.Sample.Remove() end
    J.query.search = ""
    for _, key in ipairs(FILTERS) do J.query[key] = example.filters[key] end
    if J.journal and J.journal.search then J.journal.search:SetText("") end
    if J.selected == ns.Sample.GUID then J.selected = nil end
    ns.SetSetting("introSeen", true)
    if begin then
        J.TurnTo("journey")
    elseif ns.UI.JournalShowing("people") then
        J.RefreshList(true)
        J.RefreshProfile()
    end
    Told()
end

-- "Begin your own diary →".
function Tour.Begin() Leave(true) end
Tour.Leave = Leave

--------------------------------------------------------------------------
-- What the book tells it
--------------------------------------------------------------------------

-- The book turned (UI/Journal/Book.lua's ShowView): the sheet goes with
-- Your Diary's page, the example with Thex's.
function Tour.Turned()
    local J = ns.UI.Journal
    if Tour.step and J.view ~= "journey" then Exit() end
    if Tour.example and (J.view ~= "people" or J.selected ~= ns.Sample.GUID) then Leave(false) end
end

-- The book closed.
function Tour.Closed()
    if Tour.step then Exit() end
    if Tour.example then Leave(false) end
end

-- The book opened on nobody while the introduction is unseen.
function Tour.Offer()
    if not ns.Setting("introSeen") and not Tour.example then Tour.Lay() end
end

-- The introduction, from the parcel, /sd about or the settings: the book
-- open on Your Diary and the sheet laid on it (again, for one who has seen
-- it: Thex is written again at its end).
function ns.UI.ShowIntro()
    if Tour.example then Leave(false) end
    ns.UI.SetJournalView("journey")
    ns.UI.ShowJournal()
    Tour.Lay()
end

-- A fight starting puts it all away.
ns.On("PLAYER_REGEN_DISABLED", function()
    if Tour.step then Exit() end
    if Tour.example then Leave(false) end
end)

Tour.SHEET, Tour.STEPS, Tour.WORDS, Tour.MOTION, Tour.ROUTE, Tour.MARKS, Tour.BACK = SHEET, STEPS, WORDS, MOTION,
    ROUTE, MARKS, BACK
