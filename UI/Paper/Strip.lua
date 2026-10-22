-- A paper strip taped into the diary (JRN-22): a person's margin note
-- beside a map plate (UI/Journey/Margin.lua). A narrow slip of lighter
-- stock than the page, written on in the diary's hand (their name,
-- FONT.noteWritten, a way to their People page) with what happened under it
-- (FONT.small), and held by one piece of old matte tape across its top near
-- the left end, put on at a slant, half on the slip and half on the page.
-- It is a slip of paper, not a label: cut by hand, never quite square
-- (STRIP.cut), or torn off at its right end (STRIP.torn), lying on the
-- page and throwing a soft shadow on it (STRIP.soft). It lies turned a
-- degree or so, all of it the same way every time for the same note (a
-- seed: the person and the plate), so a page of them looks stuck in by
-- hand and stays put after a /reload.
--
-- Frames cannot turn in the client, only textures and font strings: the
-- strip is laid out flat about its middle and every piece is turned with
-- it as it is placed (the turned plane, UI/Paper/Surface.lua), as
-- UI/Paper/Sheet.lua places what is on a sheet; where
-- the client can move a texture's corners (SetVertexOffset), its uneven
-- cut, its tear and its shadow's mitre are quads (Quad), and where it
-- cannot, the slip is a clean rectangle on rectangles of shadow. The
-- what-line is wrapped here and laid a line at a time, as turned text has
-- to be. Where the client cannot turn text the strip lies straight, and
-- laid flat ("Flat paper only") it is straight, square, unshaded: plain
-- slip, the tape a flat band with its edges. The button that takes the
-- mouse cannot turn either; it stays square under the whole strip, and
-- under it the tape's free end lifts (TAPE.hover) and the name underlines.
--
-- A stranger ("someone") is the same slip in plainer ink, opens nothing
-- and has no hover. A rival (a diary entry tagged "foe") has its foot inked in
-- rubric, a thin line, never a bar.
--
-- A slip may keep room for a picture over the name (`picture`: the killer
-- card, a feature's, draws a creature there): the slip says where it
-- lies (strip.picture) and places what goes in it turned with it
-- (strip:Lay, strip:Bend); the card can ask for its tape further along the
-- top (`tapeAt`), clear of the picture, and for a smaller turn (`turn`).
-- A slip may keep room under the name as well (`under`: a card draws a
-- boxed item there), between the name and
-- what happened (strip.under), and lay what goes in it with a turn of its
-- own on top of the slip's (strip:Lay's `more`).
-- A slip may also be blank (`size`: the lucky card's tag,
-- Features/Hunts/LuckyCard.lua, a smaller slip stuck on over the card and written on by the card), of a
-- fresher stock (`paper`), lying at an exact turn of its own (`tilt`),
-- taped where the card says (`tapeAt` as { x, y, slant, w, h }) and
-- throwing its own shadows (`shadow`, `soft`).
--
-- Where the player wrote a note about the person there, the slip quotes
-- it under the name (`quote`), in their hand a size down
-- (FONT.noteQuoted), between curly quotes, the opening one hung into the
-- margin so the words line up under the name (STRIP.quote). It is their
-- words, not the diary's: what happened stays under it in the small hand.
--
-- Textures: a slip has 18 (its body, edge, contact shadow, grain, the sheen, two
-- soft shadow bands, a rival's foot, the underline, the tape, its two
-- ends, its two edges and its lifted shadow, and a tack's three, hidden
-- under tape), and STRIP.torn.teeth more for a tear, made once and hidden
-- on a slip that was cut.

local addonName, ns = ...

local Style = ns.Style

-- The slip: its margins round the writing (left, top, right, bottom), the
-- gap between the name and what happened, at most `lines` lines of that,
-- how far it turns at most (degrees, either way), its stock (lighter than
-- the page, so the ink reads better on it, never worse), its cut edge in
-- ink at `edge`, and the hair of contact shadow it throws on the page
-- (`shadow`: right, down, alpha). Laid flat, no shadow: the edge alone, at
-- `flatEdge`. Its grain, where the art exists, at `grain`. The contact
-- shadow is the plates' (UI/Journey/Plate.lua's SHADOW.core, 1.5 px at .40)
-- scaled to a thin slip: about a pixel, as dark.
-- (9 Oct, in the client: a crisp edge at .22 round a clean cream slip read
-- as a label stuck on a screen. 10 Oct: a contact shadow of .5 by .7 px at
-- .26 was not there; the slip lay flat on the page, clean.)
local STRIP = { pad = { 7, 4, 8, 5 }, gap = 1, lines = 3, turn = 1.4, paper = { 0.95, 0.91, 0.79 },
    edge = 0.16, flatEdge = 0.32, shadow = { 0.8, 1.0, 0.40 }, grain = 0.12 }
-- What it says is set in balanced lines, never one word left alone on
-- the last (10 Oct, in the client: "3 h 20 min together and a / note"):
-- where the last line would be a single word, the lines are wrapped again
-- narrower, `step` px at a time down to `least` of the width, and the
-- first width that keeps as many lines with two words or more on the last
-- is taken. The slip narrows with them.
STRIP.balance = { step = 3, least = 0.55 }
-- A note quoted under the name: at most `lines` lines, balanced as what
-- happened is; past that, the last line kept is cut at a word and ends in
-- an ellipsis inside the closing quote. Where the margin has too little
-- room, the quote gives up a line at a time down to `least` before the
-- strip is left off (strip:Smaller). `gap` px under the name, `after` px
-- over what happened (a little more: the diary's words are not theirs).
-- The opening quote hangs into the margin, at most `hang` px.
STRIP.quote = { lines = 3, least = 1, gap = 1, after = 3, hang = 6,
    open = "\226\128\156", close = "\226\128\157", cut = "\226\128\166" }
-- Its cut: scissors never cut square, so each corner lies off true by up
-- to `skew` px each way (seeded). Laid flat, or where corners cannot move,
-- square.
STRIP.cut = { skew = 1.1 }
-- Some slips were torn off, not cut: `chance` of them (seeded) have a
-- tear for a right end, `teeth` pieces of it, each point of the tear
-- `depth` px in from the end at most and `least` of that at least. A tear
-- shows the paper's fibres, so each piece pales toward it, to `fibre`.
-- Laid flat, or where corners cannot move, cut square.
STRIP.torn = { chance = 0.5, teeth = 5, depth = 3.5, least = 0.2, fibre = { 1, 0.985, 0.94 } }
-- Its shadow on the page, as a plate's is (UI/Journey/Plate.lua's SHADOW):
-- gradient bands along its bottom and right edges, turned with it, meeting
-- on a mitre, falling `out` px down and to the right and fading out over
-- `blur` px more, from `alpha` under its edge. Lifted under the mouse
-- (TAPE.hover), it falls `lift` = { out, blur } px more and pales to
-- `pale` of itself. The plates' soft band (about 4.5 px at .28) scaled to
-- a slip. None laid flat.
STRIP.soft = { out = 0.8, blur = 2.6, alpha = 0.28, lift = { 1.5, 2 }, pale = 0.8 }
-- The tape: `w` by `h`, its middle `at` across the top edge (a share of
-- the strip's width from the left, never nearer an end than `inset` px),
-- `over` of its height on the slip and the rest on the page; put on at
-- `slant` degrees, give or take `jitter`, its left end the lower, in the
-- slip's margin, its right end rising off the slip over the name. It never
-- lies on the name's letters: where its lower edge would come within
-- `clear` px of the top of the name's box over the name, it is moved up
-- off it (the name's capitals start about that far into its box). Old
-- matte tape, gone yellow: `tint` at `alpha`, its cut ends a little denser
-- (`ends`, px wide, at `endAlpha` more). Its long edges show, each `line`
-- px: the lower in `edge` at `edgeAlpha` (dust in its glue and its own
-- hair of shadow), the upper catching the light in `shine` at
-- `shineAlpha`. Laid flat, the band at `flatAlpha` and its edges at
-- `flatEdge`: no ends, no shine.
-- (9 Oct, in the client: warm white at .55 on the pale slip, it was not
-- there at all. 10 Oct: { .92, .84, .60 } at .50, its edges at .34, was
-- still too faint.)
local TAPE = { w = 28, h = 11, at = 0.16, inset = 16, over = 0.42, slant = 11, jitter = 6, clear = 3,
    tint = { 0.88, 0.78, 0.48 }, alpha = 0.68, ends = 2, endAlpha = 0.22, line = 1,
    edge = { 0.42, 0.33, 0.16 }, edgeAlpha = 0.50, shine = { 1, 0.97, 0.86 }, shineAlpha = 0.36,
    flatAlpha = 0.62, flatEdge = 0.40 }
-- Under the mouse (the strip's name opens their page): the tape's free
-- end, its right, comes up a little off the paper, the way tape does
-- when a fingernail finds it. It catches the light (the tape toward
-- `tint`, at `alpha`; its right end at `endAlpha`), throws a hair of
-- shadow under itself (`shadow`: alpha, `drop` px down), and the slip
-- under it lifts with it: its contact shadow to `strip`, its soft shadow
-- further out (STRIP.soft.lift). Nothing else moves: the writing and the
-- leaders stay put. Over `time` seconds, eased out, back the same way on
-- leaving. Laid flat, only the tape's tone, to `flatAlpha`. A stranger's
-- strip opens nothing, so it has no hover.
TAPE.hover = { time = 0.15, tint = { 0.97, 0.90, 0.68 }, alpha = 0.80, endAlpha = 0.36, shadow = 0.22, drop = 1.2,
    strip = 0.46, flatAlpha = 0.74 }
-- A slip fastened with a brass tack instead of tape (`tack`: an epic's
-- strip on a dungeon's map, UI/Dungeon/Notes.lua): a round head `size` px
-- across, pinned through its top right corner, its middle `inset` px in
-- from the slip's right and `down` from its top, clear of the name (which
-- starts at the left and ends `pad[3]` short of the right at the most),
-- in brass (Style's) with a lit spot up and to the left and a hair of
-- shadow down and to the right. Drawn, until the art comes. (16 Oct, in
-- the client: 12 px in from the left it sat on the name's first letter.)
local TACK = { size = 7, inset = 4, down = 4, shine = 0.4, shadow = { 1.2, 0.35 } }
-- Turned writing is drawn inside its own box, and the client cuts what
-- the turn takes out of it: a line w px long turned t lifts its ends w *
-- sin t, so each line's box is that much taller (centred on it, so the
-- words stay where they were) and `room` px more. (16 Oct, in the client:
-- the long "Finally!" line on a strip turned some 8 degrees lost the tops
-- of its letters.)
local TURNED = { room = 4 }
-- How far round the strip and its tape, as drawn, the mouse finds it (px).
local HIT = 2
-- A rival's foot: a rubric line `inset` px in from the bottom edge, inset
-- as far from the sides, `width` px at `alpha`.
local RIVAL = { inset = 3, width = 1, alpha = 0.7 }

local function Noise(n) return Style.Noise(n) end

-- The turned plane's kit (UI/Paper/Surface.lua): a number from a string,
-- the same every time (what a slip turns and tears by); text measured
-- unbounded; a point of something turned about another.
local Surface = ns.UI.Surface
local Seed, Width, Turned = Surface.Seed, Surface.Width, Surface.Turned

-- A strip on `parent`. strip:SetNote(note) with { name, what, quote, guid
-- (a link to their page when given), rival, seed, onClick(guid) }, then
-- strip:Layout(x, y, width) lays it with its top left at x, y of `parent`
-- (right and down), at most `width` wide, and returns its width and
-- height (as laid flat; the turn moves its corners a pixel or two).
-- strip:Nearest(x, y) is the point of its edge nearest a point of
-- `parent`, for a leader to leave from.
--
-- The margin's note (UI/Journey/Margin.lua: what a kind's `new` returns, a
-- person's strip and every feature's card; said here once, for all):
--   :Layout(x, y, width, room) → w, h
--            laid with its top left at x, y of its parent, at most `width`
--            wide, its size as laid flat; `room` is the height the margin
--            has left there (nil where the page does not say), for a note
--            that can fit itself to it
--   :Nearest(x, y) → x, y
--            the point of its edge nearest x, y of its parent: where its
--            leader leaves it
--   :Smaller() → bool
--            a field of its own (the margin asks rawget): it gives
--            something up to be laid smaller (a quote a line, a card what
--            its `smaller` says), false where it has nothing left; the page
--            lays it again
--   .overfull
--            true where, as last laid, it will not fit `width`: the page
--            leaves it off (:Hide)
-- How wide a card would like a row's box is not asked of the note: its
-- kind's `wants` measures that on a card of its own (a hunt card's
-- card:Preferred).
--
-- A card on the strip (a feature's: the find card, a campfire's slip, the
-- killer card, ...) is the strip laid out its own way. It passes `card`, a
-- table of hooks, all optional, read as the strip is laid (so a card may
-- fill its table in after the strip is made, once its own drawing is):
--   plan(strip, note, width, room, again) → plan, at
--            before the slip is laid: `note` is the note as set (SetNote's
--            table, what the strip lays), and the card sets there its rooms
--            and look for this `width` (note.picture, note.under,
--            note.least, note.tapeAt, note.what, note.name), the name's
--            font and words on strip.name, and strip.overfull. `room` is
--            Layout's; `again` is true while it is laid a second time
--            (`again`, below). `plan` is handed to draw; `at`, where given,
--            is the width the slip is laid at instead of `width` (a card
--            narrower than its column with something of its own beside it:
--            the lucky card and its tag)
--   draw(strip, plan, w, h) → w, h
--            after the slip is laid, w by h, and shown: what goes in its
--            rooms. A size it returns is the note's instead (Layout's, and
--            strip.box's): a card that is more than its slip (the lucky
--            card's tag)
--   again(strip, w, h, room) → bool
--            asked once, after the first laying: true lays it once more,
--            plan and draw with it (the killer card's picture drawn small
--            where the card stood taller than `room`)
--   smaller(strip) → bool
--            strip:Smaller's, instead of the quote giving up a line
--   nearest(strip, x, y, sx, sy) → x, y
--            strip:Nearest's, given the slip's own nearest point sx, sy
--            (the lucky card's tag is nearer, some ways)
-- What a card may use of the strip, and nothing else (the rest is the
-- strip's own, and may change; nor may a card's own fields take its
-- names):
--   fields   name (the font string in the hand: a card sets its font and
--            words in `plan`); picture and under (the rooms as laid:
--            { lx, ly, w, h } on the strip from its middle, y down; X, Y on
--            the screen from its middle, y up; x, y on the parent; nil where
--            none was asked: a card's draw may narrow `picture` to the part
--            its picture takes, the close call's under its heading, and the
--            tests read it so); box ({ x, y, w, h } as laid); turn, flat
--            and turnsText (how it lies as laid: its turn in radians, laid
--            flat, whether text can turn in this client); overfull
--   methods  :Pad() → l, t, r, b, its margins round the writing
--            :Least(over, tapeAt, clear) → the least width for its tape,
--            `tapeAt` of the way along, to start `clear` px past what is
--            at its top, `over` px wide
--            :Paper() → its stock as laid ({ r, g, b })
--            :WhatLines() → what happened's lines as shown (font strings)
--            :Lay, :Bend, :Out, :Screen (at the foot), :Nearest, :SetNote,
--            :Hover, :What, :Quote
-- Something drawn in the strip's look that is not a strip (good luck's S
-- on a print, Features/Hunts/LuckyCard.lua) reads ns.UI.PAPER_LOOK (at the
-- foot of this file).
function ns.UI.PaperStrip(parent, card)
    -- A strip without a card is a person's: no hooks.
    card = card or {}
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(1, 1)

    local function Texture(layer, sublevel)
        local texture = strip:CreateTexture(nil, layer, nil, sublevel)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        return texture
    end

    -- From the page up: its soft shadow and contact shadow, its cut edge,
    -- the slip and its tear, its grain, the writing, the tape.
    strip.soft = { Texture("BACKGROUND", -2), Texture("BACKGROUND", -2) }
    strip.shadow = Texture("BACKGROUND", 0)
    strip.edge = Texture("BACKGROUND", 1)
    strip.paper = Texture("BACKGROUND", 2)
    -- Lit (`light`): the house light's shade across the slip, over it.
    strip.sheen = Texture("BACKGROUND", 3)
    strip.sheen:Hide()
    -- Its shadow on what lies under what it lies on (`ground`), made on
    -- that frame as first asked for.
    strip.grounds = {}
    strip.teeth = {}
    for i = 1, STRIP.torn.teeth do strip.teeth[i] = Texture("BACKGROUND", 2) end
    local grainPath = Style.Art("grain")
    if grainPath then
        strip.grain = Texture("BORDER", 0)
        strip.grain:SetTexture(grainPath)
        strip.grain:SetAlpha(STRIP.grain)
    end
    strip.rival = Texture("ARTWORK", 0)
    strip.tapeShadow = Texture("OVERLAY", 1)
    strip.tape = Texture("OVERLAY", 2)
    strip.tapeEnds = { Texture("OVERLAY", 3), Texture("OVERLAY", 3) }
    -- Its long edges: the lower in dust and shade, the upper in light.
    strip.tapeEdges = { Texture("OVERLAY", 4), Texture("OVERLAY", 4) }
    -- Or a brass tack (TACK): its shadow, its head, the light on it.
    strip.tack = { Texture("OVERLAY", 1), Texture("OVERLAY", 2), Texture("OVERLAY", 3) }

    -- Whether a texture's corners can be moved (the uneven cut, the tear,
    -- the shadow's mitre). A field, so the tests can say.
    strip.canBend = strip.paper.SetVertexOffset ~= nil

    -- The name: written in the diary's hand, a square button under it.
    strip.name = Style.Text(strip, Style.FONT.noteWritten)
    strip.underline = Texture("ARTWORK", 1)
    strip.underline:Hide()
    strip.link = CreateFrame("Button", nil, strip)
    -- A note with a tooltip (`tip`) shows it under the mouse; one that
    -- opens a page lifts its tape (Hover).
    Style.Tooltip(strip.link, function() return strip.tip and strip.tip() end, nil,
        function(_, on) strip:Hover(on) end)
    strip.link:SetScript("OnClick", function()
        if strip.guid and strip.onClick then strip.onClick(strip.guid) end
    end)

    -- What happened, a line at a time; and a measure for wrapping it.
    strip.lines = {}
    strip.measure = Style.Text(strip, Style.FONT.small)
    strip.measure:Hide()
    local probe = strip.measure
    strip.turnsText = probe.SetRotation ~= nil
    -- Their note, quoted a line at a time; and a measure in their hand.
    strip.said = {}
    local voice = Style.Text(strip, Style.FONT.noteQuoted)
    voice:Hide()

    local turn, W, H = 0, 1, 1
    -- How it is laid now: whether its corners move (`bends`), and the
    -- outline of its body, TL, TR, BR, BL, from its middle, y down.
    local bends, body = false, nil

    -- The strip is a turned plane (UI/Paper/Surface.lua), its middle the
    -- strip's, laid with it (plane.Set, in Lay):
    --   Out(lx, ly)      a point of the strip (from its middle, y down) on
    --                    `parent` (y down)
    --   Screen(lx, ly)   a point of the strip on the screen, from its
    --                    middle, y up
    --   Place(region, lx, ly, w, h, more)
    --                    `region` w by h with its middle at lx, ly of the
    --                    strip, turned with it and `more`; one bent before
    --                    has its corners put back
    --   Quad(region, x1, y1, ..., x4, y4)
    --                    `region` over four points of the strip, upper
    --                    left, upper right, lower right, lower left (from
    --                    its middle, y down), turned with it: a square
    --                    about as big, its corners moved onto them. False
    --                    where corners cannot move (as laid now), for the
    --                    caller to place a box
    local plane = Surface.New(strip)
    local Out, Screen, Place, Quad = plane.Out, plane.Screen, plane.Place, plane.Quad

    -- The body's outline, `grow` px out (its edge) and moved dx, dy (its
    -- contact shadow), on `region`; a box of the same where corners cannot
    -- move. A torn end has no cut edge: there it is drawn in under the
    -- tear instead of grown.
    local function Body(region, grow, dx, dy)
        local b, g = body, grow or 0
        local gr = (strip.torn and g > 0) and -0.5 or g
        dx, dy = dx or 0, dy or 0
        if not Quad(region, b[1] - g + dx, b[2] - g + dy, b[3] + gr + dx, b[4] - g + dy, b[5] + gr + dx,
            b[6] + g + dy, b[7] - g + dx, b[8] + g + dy) then
            local x0, x1 = math.min(b[1], b[7]), math.max(b[3], b[5])
            local y0, y1 = math.min(b[2], b[4]), math.max(b[6], b[8])
            Place(region, (x0 + x1) / 2 + dx, (y0 + y1) / 2 + dy, x1 - x0 + 2 * g, y1 - y0 + 2 * g)
        end
    end

    -- How wide `text` is in `font` (a hidden measure: `probe`, `voice`).
    local function Measure(font, text)
        font:SetText(text)
        return Width(font)
    end

    -- `text` broken into lines no wider than `width` in `font` (FONT.small,
    -- the probe, unless said), its own spacing kept within a line (the wide
    -- space round a "·").
    local function Wrap(text, width, font)
        font = font or probe
        local lines, line, space = {}, "", ""
        for word, after in (text or ""):gmatch("(%S+)(%s*)") do
            local try = line == "" and word or (line .. space .. word)
            if line ~= "" and Measure(font, try) > width then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
            space = after ~= "" and after or " "
        end
        if line ~= "" then lines[#lines + 1] = line end
        return lines
    end

    -- Whether a line is one word alone (a time held by no-break spaces,
    -- "3 h 20 min", is one word).
    local function Alone(line) return line ~= nil and not line:find("%s") end

    -- `text` wrapped to `width` in balanced lines (STRIP.balance): where the
    -- last line would be one word alone, wrapped again narrower until it is
    -- not, keeping as many lines; as wrapped where no width does. In `font`
    -- (Wrap's), and at most `most` lines (STRIP.lines) kept.
    local function Balanced(text, width, font, most)
        local lines = Wrap(text, width, font)
        local n = #lines
        -- (Past `most` the rest is left off: no last line to balance.)
        if n < 2 or n > (most or STRIP.lines) or not Alone(lines[n]) then return lines end
        local B = STRIP.balance
        local w = width - B.step
        while w >= width * B.least do
            local try = Wrap(text, w, font)
            if #try ~= n then break end
            if not Alone(try[n]) then return try end
            w = w - B.step
        end
        return lines
    end

    -- Their note quoted (STRIP.quote) in at most `most` lines no wider than
    -- `width`: balanced where it fits; else cut on the last line kept, at a
    -- word (at a character where one word will not fit), and ended with an
    -- ellipsis inside the closing quote. A word too wide for a line ends
    -- the quote there. Returns the lines, and whether it was cut.
    local function Said(text, width, most)
        local Q = STRIP.quote
        local lines = Balanced(Q.open .. text .. Q.close, width, voice, most)
        local keep = math.min(#lines, most)
        for i = 1, keep do
            if Measure(voice, lines[i]) > width then
                keep = i
                break
            end
        end
        if keep == #lines and Measure(voice, lines[keep]) <= width then return lines, false end
        for i = keep + 1, #lines do lines[i] = nil end
        -- The last line kept, without its closing quote or an ellipsis it
        -- came with (JourneyText cuts a long note first), shortened until
        -- it fits with its own.
        local line = lines[keep]:gsub(Q.close .. "$", ""):gsub(Q.cut .. "$", "")
        local function Ended(s) return (s:gsub("[%s,;:]+$", "")) .. Q.cut .. Q.close end
        while Measure(voice, Ended(line)) > width and #line > #Q.open do
            line = line:match("^(.*%S)%s+%S+$") or line:gsub("[\1-\127\192-\255][\128-\191]*$", "")
        end
        -- Never half of a shown bar ("||").
        line = line:gsub("|+$", function(bars) return bars:sub(1, #bars - #bars % 2) end)
        lines[keep] = Ended(line)
        return lines, true
    end

    -- Its soft shadow (STRIP.soft), `t` of the way lifted: a band along
    -- the bottom and one down the right, meeting on a mitre, their far
    -- ends starting in a slant; boxes where corners cannot move.
    local function Soft(t)
        local S, I = strip.softLook or STRIP.soft, Style.INK
        local d, b = S.out + S.lift[1] * t, S.blur + S.lift[2] * t
        local a = S.alpha * (1 - (1 - S.pale) * t)
        local hw, hh, r = W / 2, H / 2, d + b
        local bottom, right = strip.soft[1], strip.soft[2]
        -- VERTICAL runs from the bottom up: clear outside, dark inside.
        Style.Shade(bottom, "VERTICAL", I[1], I[2], I[3], 0, a)
        if not Quad(bottom, -hw + r, hh - 2, hw - 2, hh - 2, hw + r, hh + r, -hw + d, hh + r) then
            Place(bottom, d / 2 + r / 2, hh - 1 + (r + 1) / 2, W - d + r, r + 1)
        end
        Style.Shade(right, "HORIZONTAL", I[1], I[2], I[3], a, 0)
        if not Quad(right, hw - 2, -hh + r, hw + r, -hh + d, hw + r, hh + r, hw - 2, hh - 2) then
            Place(right, hw - 1 + (r + 1) / 2, d / 2 - 0.5, r + 1, H - d - 1)
        end
    end

    -- The hover (TAPE.hover): `lift` from 0 (lying) to 1 (lifted), eased
    -- out, run by a short OnUpdate that stops itself once it gets there.
    local HOVER = TAPE.hover
    strip.lift = 0
    local target = 0

    local function Mix(a, b, t) return a + (b - a) * t end

    local function Apply()
        local t = 1 - (1 - strip.lift) ^ 4
        local T, flat = TAPE, strip.flat
        strip.tape:SetColorTexture(Mix(T.tint[1], HOVER.tint[1], t), Mix(T.tint[2], HOVER.tint[2], t),
            Mix(T.tint[3], HOVER.tint[3], t), flat and Mix(T.flatAlpha, HOVER.flatAlpha, t) or Mix(T.alpha, HOVER.alpha, t))
        local INK = Style.INK
        strip.tapeShadow:SetColorTexture(INK[1], INK[2], INK[3], flat and 0 or HOVER.shadow * t)
        strip.tapeShadow:SetShown(not flat and t > 0 and not strip.tacked)
        local tip = strip.tapeEnds[2]
        tip:SetColorTexture(T.tint[1], T.tint[2], T.tint[3], Mix(T.endAlpha, HOVER.endAlpha, t))
        strip.shadow:SetColorTexture(INK[1], INK[2], INK[3], Mix((strip.contact or STRIP.shadow)[3], HOVER.strip, t))
        if not flat then Soft(t) end
    end

    local function Step(self, elapsed)
        local step = (elapsed or 0) / HOVER.time
        if target > self.lift then
            self.lift = math.min(target, self.lift + step)
        else
            self.lift = math.max(target, self.lift - step)
        end
        Apply()
        if self.lift == target then self:SetScript("OnUpdate", nil) end
    end

    -- Picked up under the mouse, or laid down again; the name underlined
    -- with it. Only a strip that opens someone's page.
    function strip:Hover(on)
        on = on and self.guid ~= nil
        self.underline:SetShown(on)
        target = on and 1 or 0
        if self.lift ~= target then self:SetScript("OnUpdate", Step) end
    end

    -- Lying, at once: as it is laid again, or put away mid-hover.
    local function Settle()
        target, strip.lift = 0, 0
        strip:SetScript("OnUpdate", nil)
        strip.underline:Hide()
        if body then Apply() end
    end
    strip:HookScript("OnHide", Settle)
    -- Its shadow on the ground goes with it.
    strip:HookScript("OnHide", function()
        for _, t in ipairs(strip.grounds) do t:Hide() end
    end)

    -- `note`: { name, what, quote (their note's words, as JourneyText's
    -- Written gives them: no escape codes), quoteLines (the most lines the
    -- quote may take, STRIP.quote.lines at most), guid (a link to their page when
    -- given), rival, seed, onClick(guid), and for a slip that is not a
    -- person's: tack (fastened with a brass tack, TACK, instead of tape), strong
    -- (the name in INK_STRONG without a page to open), tip (a tooltip's
    -- lines, as Style.Tooltip takes them), picture ({ w, h, gap }: room over
    -- the name), under ({ w, h, gap, after }: room under the name, `gap`
    -- under the name and `after` over what happened), least (its least
    -- width), tapeAt (the tape's middle, a share of the width; or { x, y,
    -- slant, w, h }: its middle at x, y px of the slip from its top left,
    -- `slant` degrees, its own size, put on exactly there, names or not),
    -- turn (the most it turns, degrees), tilt (the turn it lies at, exactly,
    -- degrees: a slip stuck on another, turned against it), size ({ w, h }:
    -- a blank slip that size, written on by its caller), paper (its stock),
    -- shadow ({ right, down, alpha }: its contact shadow), soft ({ out,
    -- blur, alpha }: its soft one), light (lit across by the house light,
    -- UI/Paper/Light.lua's SHEEN: as cut at its top left, a little darker
    -- toward its bottom right), ground ({ frame, layers, colour }: its
    -- outline's shadow, as UI/Paper/Light.lua's Cast gives it, drawn on
    -- `frame`, a layer under what the strip lies on: the dungeon map's
    -- strips on the world under it, where they stick out past the sheet) }.
    function strip:SetNote(note)
        self.note = note
        self.guid = note.guid
        self.onClick = note.onClick
        self.tip = note.tip
        self.name:SetText(note.name or "")
        local S = (note.guid or note.strong) and Style.INK_STRONG or Style.INK
        self.name:SetTextColor(S[1], S[2], S[3])
        self.link:EnableMouse(note.guid ~= nil or note.tip ~= nil)
        self.rival:SetShown(note.rival == true)
        -- Its quote in full again, or in as many lines as the page allows
        -- it (`quoteLines`), for the margin it is laid in next.
        self.quoteMost = math.min(note.quoteLines or STRIP.quote.lines, STRIP.quote.lines)
    end

    -- What happened, as written (for the tests).
    function strip:What()
        local parts = {}
        for i = 1, self.shownLines or 0 do parts[#parts + 1] = self.lines[i]:GetText() end
        return table.concat(parts, " ")
    end

    -- Their note as quoted, its lines joined (for the tests and its tooltip:
    -- strip.quoteCut where it was cut).
    function strip:Quote()
        local parts = {}
        for i = 1, self.quoteLines or 0 do parts[#parts + 1] = self.said[i]:GetText() end
        return table.concat(parts, " ")
    end

    -- Where the margin has too little room for it, a quote gives up a line
    -- (to STRIP.quote.least) before the page leaves the strip off. Whether
    -- there was a line to give up (the page lays it again). A card on a
    -- strip gives up what its own says (`smaller`).
    function strip:Smaller()
        if card.smaller then return card.smaller(self) end
        if (self.quoteLines or 0) <= STRIP.quote.least then return false end
        self.quoteMost = self.quoteLines - 1
        return true
    end

    -- The slip as cut (STRIP.cut, STRIP.torn): its body's outline, and the
    -- tear along its right end where it was torn off. Square laid flat or
    -- where corners cannot move.
    local function Cut(seed, flat)
        local hw, hh = W / 2, H / 2
        local k = (flat or not bends) and 0 or STRIP.cut.skew
        local function J(n) return (Noise(seed + n) - 0.5) * 2 * k end
        local torn = not flat and bends and Noise(seed + 5) < STRIP.torn.chance
        local right = torn and hw - STRIP.torn.depth or hw
        body = { -hw + J(10), -hh + J(11), right + (torn and 0 or J(12)), -hh + J(13),
            right + (torn and 0 or J(14)), hh + J(15), -hw + J(16), hh + J(17) }
        local P, F, D = strip.stock or STRIP.paper, STRIP.torn.fibre, STRIP.torn.depth
        local n = torn and #strip.teeth or 0
        for i, tooth in ipairs(strip.teeth) do
            tooth:SetShown(i <= n)
            if i <= n then
                -- The tear's points, from the body's top right corner down
                -- to its bottom right, each its own depth in.
                local function Point(j)
                    local y = body[4] + (body[6] - body[4]) * j / n
                    local inset = D * (STRIP.torn.least + (1 - STRIP.torn.least) * Noise(seed + 20 + j))
                    return hw - inset, y
                end
                local ax, ay = Point(i - 1)
                local bx, by = Point(i)
                Style.Gradient(tooth, "HORIZONTAL", { P[1], P[2], P[3], 1 }, { F[1], F[2], F[3], 1 })
                Quad(tooth, right - 0.5, ay, ax, ay, bx, by, right - 0.5, by)
            end
        end
        return torn
    end

    -- The slip laid (strip:Layout, below, with its card's hooks round it).
    local function Lay(self, x, y, width)
        local note = self.note or {}
        local pad = STRIP.pad
        local flat = ns.Setting("flatSheets") == true
        local inner = width - pad[1] - pad[3]

        -- The writing: the name, their note quoted, then what happened in
        -- lines.
        self.name:SetSize(0, 0)
        local nameW, nameH = Width(self.name) + 2, math.max(math.ceil(self.name:GetStringHeight() or 0), 14)
        local Q = STRIP.quote
        local said, cut = {}, false
        if note.quote and note.quote ~= "" then
            said, cut = Said(note.quote, inner, self.quoteMost or Q.lines)
        end
        self.quoteCut = cut
        -- The opening quote hangs into the margin, so the words line up.
        local hang = #said > 0 and math.min(Q.hang, pad[1] - 1, Measure(voice, Q.open)) or 0
        local quoteH, textW = 0, nameW
        for i, words in ipairs(said) do
            local line = self.said[i]
            if not line then
                line = Style.Text(self, Style.FONT.noteQuoted)
                self.said[i] = line
            end
            line:SetText(words)
            line:SetSize(0, 0)
            quoteH = math.max(quoteH, math.ceil(line:GetStringHeight() or 0), 13)
            textW = math.max(textW, Width(line) + 2 - (i == 1 and hang or 0))
            line:Show()
        end
        for i = #said + 1, #self.said do self.said[i]:Hide() end
        self.quoteLines = #said
        local wrapped = Balanced(note.what, inner)
        for i = STRIP.lines + 1, #wrapped do wrapped[i] = nil end
        local lineH = 0
        -- The picture's room over the name, and the gap under it.
        local pic = note.picture
        local picW, picH = pic and pic.w or 0, pic and (pic.h + (pic.gap or 0)) or 0
        -- The room under the name, and the gaps round it.
        local under = note.under
        local underW, underH = under and under.w or 0, under and (under.h + (under.gap or 0)) or 0
        for i, words in ipairs(wrapped) do
            local line = self.lines[i]
            if not line then
                line = Style.Text(self, Style.FONT.small)
                self.lines[i] = line
            end
            line:SetText(words)
            line:SetSize(0, 0)
            lineH = math.max(lineH, math.ceil(line:GetStringHeight() or 0), 11)
            textW = math.max(textW, Width(line) + 2)
            line:Show()
        end
        for i = #wrapped + 1, #self.lines do self.lines[i]:Hide() end
        self.shownLines = #wrapped
        -- Under their words, a little further down than under the name.
        local quoteGap = #said > 0 and (Q.gap + quoteH * #said) or 0
        local whatGap = #said > 0 and Q.after or (under and under.after or STRIP.gap)
        W = math.min(width, math.max(note.least or 0, math.ceil(math.max(textW, picW, underW)) + pad[1] + pad[3]))
        H = pad[2] + picH + nameH + underH + quoteGap
            + (#wrapped > 0 and (whatGap + lineH * #wrapped) or 0) + pad[4]
        -- A blank slip is the size its caller wrote on.
        if note.size then W, H = note.size[1], note.size[2] end
        -- Its own stock and shadows, where it has them.
        self.stock, self.contact = note.paper or STRIP.paper, note.shadow or STRIP.shadow
        self.softLook = nil
        if note.soft then
            local S = STRIP.soft
            self.softLook = { out = note.soft.out, blur = note.soft.blur, alpha = note.soft.alpha, lift = S.lift,
                pale = S.pale }
        end

        -- How it lies: turned by its seed (or exactly, `tilt`), straight
        -- laid flat or where text cannot turn.
        local seed = Seed(note.seed or note.name)
        turn = 0
        if not flat and self.turnsText then
            turn = note.tilt and math.rad(note.tilt) or math.rad((Noise(seed) - 0.5) * 2 * (note.turn or STRIP.turn))
        end
        self.turn, self.flat = turn, flat
        bends = self.canBend and not flat
        local cx, cy = x + W / 2, y + H / 2
        plane.Set(turn, cx, cy, bends)
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "TOPLEFT", cx, -cy)
        self:SetSize(W, H)

        -- The slip: as it was cut or torn, its shadows, its cut edge, the
        -- stock, its grain.
        self.torn = Cut(seed, flat)
        local INK = Style.INK
        local sh = self.contact
        self.shadow:SetColorTexture(INK[1], INK[2], INK[3], sh[3])
        Body(self.shadow, 0, sh[1], sh[2])
        self.shadow:SetShown(not flat)
        for _, soft in ipairs(self.soft) do soft:SetShown(not flat) end
        self.edge:SetColorTexture(INK[1], INK[2], INK[3], flat and STRIP.flatEdge or STRIP.edge)
        Body(self.edge, 1)
        local P = self.stock
        self.paper:SetColorTexture(P[1], P[2], P[3], 1)
        Body(self.paper, 0)
        -- Lit across, where asked (not laid flat).
        local lit = note.light and not flat
        if lit then
            ns.UI.Light.Sheen(self.paper, self.sheen, P)
            Body(self.sheen, 0)
        end
        self.sheen:SetShown(lit == true)
        -- Its shadow on the ground under what it lies on, an outline a
        -- layer at a time, grown and moved as each says.
        local G = not flat and note.ground or nil
        for i, layer in ipairs(G and G.layers or {}) do
            local t = self.grounds[i]
            if not t or t.frame ~= G.frame then
                t = G.frame:CreateTexture(nil, "BACKGROUND", nil, -8)
                if t.SetSnapToPixelGrid then
                    t:SetSnapToPixelGrid(false)
                    t:SetTexelSnappingBias(0)
                end
                t.frame = G.frame
                self.grounds[i] = t
            end
            local c = G.colour or INK
            t:SetColorTexture(c[1], c[2], c[3], layer[4])
            Body(t, layer[3], layer[1], layer[2])
            t:Show()
        end
        for i = #(G and G.layers or {}) + 1, #self.grounds do self.grounds[i]:Hide() end
        if self.grain then
            local u, v = Noise(seed + 1) * 0.6, Noise(seed + 2) * 0.6
            self.grain:SetTexCoord(u, u + W / 512, v, v + H / 512)
            Body(self.grain, 0)
        end

        -- The picture's room, from the top left inside the margins: where it
        -- lies on the strip (from its middle, y down), on the screen from the
        -- strip's middle (y up), and on `parent`.
        local left = -W / 2 + pad[1]
        self.picture = nil
        if pic then
            local lx, ly = left + pic.w / 2, -H / 2 + pad[2] + pic.h / 2
            local X, Y = Screen(lx, ly)
            local px, py = Out(lx, ly)
            self.picture = { lx = lx, ly = ly, w = pic.w, h = pic.h, X = X, Y = Y, x = px, y = py }
        end

        -- A line of writing w by h with its middle at lx, ly, in a box tall
        -- enough for its turn (TURNED).
        local lift = math.abs(math.sin(turn))
        local function Write(region, lx, ly, w, h)
            Place(region, lx, ly, w, h + w * lift + TURNED.room)
        end

        -- The writing, under it.
        local top = -H / 2 + pad[2] + picH
        Write(self.name, left + nameW / 2, top + nameH / 2, nameW, nameH)
        -- For the tests and a card: the name's writing, from the middle.
        self.nameBox = { left, top, left + nameW, top + nameH }
        local U = Style.INK_STRONG
        self.underline:SetColorTexture(U[1], U[2], U[3], Style.HAIRLINE)
        Place(self.underline, left + nameW / 2, top + nameH, nameW, 1)
        -- The room under the name: where it lies, as the picture's.
        self.under = nil
        if under then
            local lx, ly = left + under.w / 2, top + nameH + (under.gap or 0) + under.h / 2
            local X, Y = Screen(lx, ly)
            local px, py = Out(lx, ly)
            self.under = { lx = lx, ly = ly, w = under.w, h = under.h, X = X, Y = Y, x = px, y = py }
        end
        -- Their words, the first line's opening quote in the margin.
        local quoteTop = top + nameH + underH + Q.gap
        for i = 1, #said do
            local line = self.said[i]
            local w = Width(line) + 2
            local lx = left - (i == 1 and hang or 0)
            Write(line, lx + w / 2, quoteTop + (i - 0.5) * quoteH, w, quoteH)
        end
        local lineTop = top + nameH + underH + quoteGap + whatGap
        for i = 1, #wrapped do
            local line = self.lines[i]
            local w = Width(line) + 2
            Write(line, left + w / 2, lineTop + (i - 0.5) * lineH, w, lineH)
        end

        -- A rival's foot, in rubric.
        local R = Style.RUBRIC
        self.rival:SetColorTexture(R[1], R[2], R[3], RIVAL.alpha)
        Place(self.rival, 0, H / 2 - RIVAL.inset, W - 2 * RIVAL.inset, RIVAL.width)

        -- The tape across the top near the left end, at its slant, `over`
        -- of it on the slip; laid flat, a plain band, square.
        local T = TAPE
        local at = math.max(T.inset, math.min(W - T.inset, W * (type(note.tapeAt) == "number" and note.tapeAt or T.at)))
            - W / 2
        local slant = flat and 0 or math.rad(T.slant + (Noise(seed + 3) - 0.5) * 2 * T.jitter)
        local tw, th = T.w, T.h
        local ty = -H / 2 + th * (T.over - 0.5)
        -- Or exactly where the caller puts it (a tag's tape, Features/Hunts/LuckyCard.lua),
        -- its own size, at its own slant, names or not.
        local exact = type(note.tapeAt) == "table" and note.tapeAt or nil
        if exact then
            at, ty = exact.x - W / 2, exact.y - H / 2
            tw, th = exact.w or tw, exact.h or th
            slant = flat and 0 or math.rad(exact.slant or 0)
        end
        local c, s = math.cos(slant), math.sin(slant)
        -- Off the name's letters (TAPE.clear): the lowest point of its lower
        -- edge over the name, where the name begins or the tape does, at
        -- most `clear` px into the name's box; moved up as far as it is
        -- past that.
        local nameTop = top + T.clear
        local u0 = math.max(-tw / 2, (left - at - th / 2 * s) / c)
        local u1 = math.min(tw / 2, (left + nameW - at - th / 2 * s) / c)
        self.tapeClear = nil
        if u0 <= u1 and not exact then
            local low = math.max(ty - u0 * s, ty - u1 * s) + th / 2 * c
            if low > nameTop then
                ty = ty - (low - nameTop)
                low = nameTop
            end
            -- For the tests: how far over the name's capitals its lower
            -- edge stays (0 or more: clear of them).
            self.tapeClear = nameTop - low
        end
        self.tape:SetColorTexture(T.tint[1], T.tint[2], T.tint[3], flat and T.flatAlpha or T.alpha)
        Place(self.tape, at, ty, tw, th, slant)
        self.tape:Show()
        -- A point of the tape (u along it, v across it, y down) on the
        -- strip: turned by its slant.
        local function Along(u, v) return Turned(at, ty, u, v, c, s) end
        -- Its cut ends, a little denser: along the tape, either side.
        for k, side in ipairs({ -1, 1 }) do
            local tip = self.tapeEnds[k]
            tip:SetColorTexture(T.tint[1], T.tint[2], T.tint[3], T.endAlpha)
            local ex, ey = Along(side * (tw - T.ends) / 2, 0)
            Place(tip, ex, ey, T.ends, th, slant)
            tip:SetShown(not flat)
        end
        -- Its long edges: the lower dark, the upper lit (none laid flat).
        local E = T.edge
        local lower, upper = self.tapeEdges[1], self.tapeEdges[2]
        lower:SetColorTexture(E[1], E[2], E[3], flat and T.flatEdge or T.edgeAlpha)
        local lx, ly = Along(0, th / 2 - T.line / 2)
        Place(lower, lx, ly, tw, T.line, slant)
        lower:Show()
        upper:SetColorTexture(T.shine[1], T.shine[2], T.shine[3], T.shineAlpha)
        local hx, hy = Along(0, -th / 2 + T.line / 2)
        Place(upper, hx, hy, tw, T.line, slant)
        upper:SetShown(not flat)
        -- The hair of shadow its free end throws when it lifts: under the
        -- tape's right half, a little down.
        local qx, qy = Along(tw / 4, T.hover.drop)
        Place(self.tapeShadow, qx, qy, tw / 2, th, slant)
        -- Or a brass tack in the tape's place (TACK).
        self.tacked = note.tack == true
        for _, part in ipairs({ self.tape, self.tapeEnds[1], self.tapeEnds[2], lower, upper }) do
            if self.tacked then part:Hide() end
        end
        local K = TACK
        local kx, ky = W / 2 - K.inset, -H / 2 + K.down
        self.tackBox = self.tacked and { kx - K.size / 2, ky - K.size / 2, kx + K.size / 2, ky + K.size / 2 } or nil
        for k, part in ipairs(self.tack) do
            if self.tacked then
                local B = k == 1 and Style.INK or k == 2 and Style.BRASS_MID or Style.BRASS_LIGHT
                local a = k == 1 and K.shadow[2] or k == 2 and 1 or K.shine
                Style.Disc(part, B[1], B[2], B[3], a)
                local d = k == 1 and K.shadow[1] or 0
                local size = k == 3 and K.size * 0.45 or K.size
                local ox = k == 3 and -K.size * 0.15 or 0
                Place(part, kx + d + ox, ky + d + ox, size, size)
                part:Show()
            else
                part:Hide()
            end
        end

        -- The mouse is taken over all of it as drawn, the slip and its tape
        -- turned, and `HIT` px round: one square button (buttons cannot
        -- turn), a level over the strip.
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        local function Take(lx, ly, w, h, angle)
            local cc, ss = math.cos(angle), math.sin(angle)
            local mx, my = Out(lx, ly)
            for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
                local u, v = corner[1] * w / 2, corner[2] * h / 2
                local px, py = Turned(mx, my, u, v, cc, ss)
                x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
            end
            return x0, y0, x1, y1
        end
        Take(at, ty, tw, th, turn + slant)
        self.tapeRect = { x0, y0, x1, y1 }
        x0, y0, x1, y1 = Take(0, 0, W, H, turn)
        x0, y0, x1, y1 = x0 - HIT, y0 - HIT, x1 + HIT, y1 + HIT
        self.hitRect = { x0, y0, x1, y1 }
        self.link:SetFrameLevel(self:GetFrameLevel() + 1)
        self.link:ClearAllPoints()
        self.link:SetPoint("TOPLEFT", parent, "TOPLEFT", x0, -y0)
        self.link:SetSize(x1 - x0, y1 - y0)
        Settle()

        -- For the tests and the page: where it lies, as laid flat.
        self.box = { x, y, W, H }
        self:Show()
        return W, H
    end

    -- Laid as its card says (the hooks, above): planned, the slip laid,
    -- drawn on; and once more where the card asks it.
    function strip:Layout(x, y, width, room)
        local function Once(again)
            local plan, at
            if card.plan then plan, at = card.plan(self, self.note or {}, width, room, again) end
            local w, h = Lay(self, x, y, at or width)
            if card.draw then
                local dw, dh = card.draw(self, plan, w, h)
                if dw then
                    w, h = dw, dh
                    self.box = { x, y, w, h }
                end
            end
            return w, h
        end
        local w, h = Once(false)
        if card.again and card.again(self, w, h, room) then w, h = Once(true) end
        return w, h
    end

    -- What a card may ask of the strip (the hooks' comment, above): its
    -- margins round the writing; the least width for its tape to start
    -- `clear` px past `over` px at its top, `tapeAt` of the way along (its
    -- middle at most TAPE.inset from the end); its stock as laid; what
    -- happened's lines as shown.
    function strip:Pad() return STRIP.pad[1], STRIP.pad[2], STRIP.pad[3], STRIP.pad[4] end
    function strip:Least(over, tapeAt, clear)
        local reach = STRIP.pad[1] + over + (clear or 0) + TAPE.w / 2
        return math.ceil(math.max(reach / tapeAt, reach + TAPE.inset))
    end
    function strip:Paper() return self.stock or STRIP.paper end
    function strip:WhatLines()
        local shown = {}
        for i = 1, self.shownLines or 0 do shown[i] = self.lines[i] end
        return shown
    end

    -- `region` placed w by h with its middle at lx, ly of the strip (from
    -- its middle, y down), turned with it; and over four points of it,
    -- false where corners cannot move (as laid now). For what a note
    -- draws in its picture's room.
    -- `more` turns it further than the slip (radians, as SetRotation).
    function strip:Lay(region, lx, ly, w, h, more) Place(region, lx, ly, w, h, more) end
    function strip:Bend(region, ...) return Quad(region, ...) end

    -- A point of the strip (from its middle, y down) on `parent` (y down),
    -- and on the screen from its middle (y up), where a frame is set that
    -- cannot turn with it.
    function strip:Out(lx, ly) return Out(lx, ly) end
    function strip:Screen(lx, ly) return Screen(lx, ly) end

    -- The point of the strip's edge nearest x, y of `parent`, both y down
    -- (or its card's, `nearest`, given that).
    local function Nearest(x, y)
        local lx, ly = plane.In(x, y)
        local hw, hh = W / 2, H / 2
        lx, ly = math.max(-hw, math.min(hw, lx)), math.max(-hh, math.min(hh, ly))
        if math.abs(lx) < hw and math.abs(ly) < hh then
            -- Inside: out to the nearest side.
            if hw - math.abs(lx) < hh - math.abs(ly) then lx = lx < 0 and -hw or hw
            else ly = ly < 0 and -hh or hh end
        end
        return Out(lx, ly)
    end
    function strip:Nearest(x, y)
        local sx, sy = Nearest(x, y)
        if card.nearest then return card.nearest(self, x, y, sx, sy) end
        return sx, sy
    end

    strip:Hide()
    return strip
end

-- The strip's look, for what is drawn in it without being a strip (good
-- luck's S on a print, Features/Hunts/LuckyCard.lua) or wraps words as it
-- does (a witness's card): its stock, its cut edge (laid flat:
-- `flatEdge`), its contact shadow ({ right, down, alpha }), how it
-- balances its lines (STRIP.balance), and its tape's look (TAPE, less
-- where the strip puts it). Read only.
ns.UI.PAPER_LOOK = { paper = STRIP.paper, edge = STRIP.edge, flatEdge = STRIP.flatEdge, shadow = STRIP.shadow,
    balance = STRIP.balance,
    tape = { slant = TAPE.slant, tint = TAPE.tint, alpha = TAPE.alpha, flatAlpha = TAPE.flatAlpha, ends = TAPE.ends,
        endAlpha = TAPE.endAlpha, line = TAPE.line, shine = TAPE.shine, shineAlpha = TAPE.shineAlpha,
        edge = TAPE.edge, edgeAlpha = TAPE.edgeAlpha, flatEdge = TAPE.flatEdge } }

-- Its tables whole, for the tests alone: those that pin the strip's own
-- look and behaviour (its turn, lines, quote, soft shadow, tear and the
-- tape's hover: tests/journey_ui.lua, tests/ink_trail.lua) and the
-- contract's own answers against them (Pad, Least, Paper and PAPER_LOOK:
-- tests/paper_strip.lua). A card never reads them: it has the hooks and
-- what they may use (above), and PAPER_LOOK (tests/kinds.lua checks every
-- file under Features/).
ns.UI.PAPER_STRIP = { STRIP = STRIP, TAPE = TAPE, RIVAL = RIVAL }
