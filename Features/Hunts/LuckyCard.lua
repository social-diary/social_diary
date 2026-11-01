-- The lucky card (Your Diary's plates, JRN-27): a quest's drops that came
-- with good luck, as .claude/ui-proposal/lucky-card-proposal.md, "Struck
-- down" (decided 13 Oct). The bad-luck hunt card's slip (HuntCard.lua)
-- taped in the plate's margin, with a pencil leader to its star
-- (Mark.lua's `fortune`, FORTUNE):
--
--   the heading  the item, as many as the quest wanted, in the diary's hand
--                (Hunts.Item), as on the bad-luck card
--   the icon     the item's own picture pasted in, the game's stack count
--                over its corner (HuntCard's ICON, COUNT, Icon and Edge)
--   the struck   beside it, the drop tables' word, printed (Friz, faded):
--                "expected 58" (Hunts.ExpectedLabel); and over it, the
--                diary's hand has scribbled it out, one pen line of tall
--                zigzag strokes (SCRIBBLE) whose turns all fall outside the
--                figures, so the number still reads underneath
--   the tag      a second, smaller slip of fresher paper taped on over the
--                card's right side, turned against it, hanging past its
--                edge; on it the hand says what happened instead: "dropped
--                after just four", "dropped" underlined by the same pen
--                (UNDER)
--
-- The family's rule holds: printed type is what the drop tables said, the
-- hand is what happened, graphite (here only the leader) what the diary
-- worked out.
--
-- Its size is not picked by name: card:Layout(x, y, width) tries each of
-- FORMS in turn (ORDER) and keeps the first that fits the width, the tag
-- beside the struck words (XL), or under them (L, M). Short of room it
-- gives up a step at a time (card:Smaller): the creature's line (XL's
-- alone), then the icon (and with it the tag beside the struck words is
-- tried after XL, M2s); then the page leaves it off and the caption keeps
-- its words.
--
-- On a light plate's print there is no margin: S, a small slip glued
-- across the print's foot (PRINT), drawn on the plate by this file's
-- pass ("print", at the foot) through its own toolkit (LuckyCard.Print),
-- with the struck words, the tag beside them
-- ("after four", or the count alone, the count underlined), and the item's
-- icon stuck on the slip's right edge, most of it on the slip and the rest
-- past it (the user's choice, 13 Oct: S keeps the item's picture without
-- growing onto the map).
--
-- Laid flat ("Flat paper only") both slips lie square, no shadows; the
-- tag still overlaps and hangs past (the layering is geometry, not an
-- effect); the scribble and the underline are ink and stay.

local addonName, ns = ...

local Style = ns.Style

local Hunts = ns.Hunts
local LuckyCard = {}
Hunts.LuckyCard = LuckyCard

-- The card: turned at most `turn` degrees (the bad-luck card's); the
-- heading at the hand's own size, else `small`, else on two lines; `gap`
-- under the heading. The creature's line (XL) `after` px under the struck
-- row, `creature` px tall. Beside the struck words (XL, M2s) the tag starts
-- `clear` px past the scribble's end, `rise` px above the row's top (or
-- under the heading, where the heading runs that far right). Under them
-- (L, M) it is flush with the card's right, `drop` px under the row, and
-- lies `land` px on the card, the rest hanging past its foot; at least
-- `show` px of the card's lower left must show beside it.
local LUCKY = { turn = 1.2, small = 14, gap = 4, after = 3, creature = 13, clear = 6, rise = 6, drop = 2, land = 12,
    show = 30 }
-- The arrangements, tried in turn: beside (`side`) or under the struck
-- row, the tag's lines, the hand's size on it, the struck words' size
-- (13: FONT.faded, 11: FONT.small), and how far the tag hangs past the
-- card's right edge (`over`). With the icon given up, the tag beside the
-- struck words is tried after XL (BARE).
local FORMS = {
    XL = { side = true, lines = 2, hand = 16, struck = 13, over = 14 },
    L = { side = false, lines = 1, hand = 16, struck = 13, over = 14 },
    M1 = { side = false, lines = 1, hand = 14, struck = 11, over = 10 },
    M2 = { side = false, lines = 2, hand = 14, struck = 11, over = 10 },
    M2s = { side = true, lines = 2, hand = 14, struck = 11, over = 10 },
}
local ORDER = { "XL", "L", "M1", "M2" }
local BARE = { "XL", "M2s", "L", "M1", "M2" }
-- The struck row's height without the icon, by the words' size.
local ROW = { [13] = 17, [11] = 15 }
-- The tag: its margins (left, top, right, bottom; the left a little wider,
-- for its tape), a line of the hand at 16 or 14 px, its stock (fresher than
-- the card's { .95, .91, .79 }, only slightly: stuck on later, its ink
-- reading at least as well), its turn against the card's (`turn`, degrees,
-- the other way), its contact shadow { right, down, alpha } and soft one,
-- and its tape, the family's made smaller, slanted `slant` degrees over a
-- corner.
local TAG = { pad = { 9, 5, 8, 5 }, line = { [16] = 19, [14] = 17 }, paper = { 0.97, 0.935, 0.84 },
    turn = { 1.8, 3.0 }, shadow = { 0.6, 0.8, 0.40 }, soft = { out = 0.6, blur = 2.0, alpha = 0.26 },
    tape = { w = 22, h = 10, slant = { 39, 51 } } }
-- The scribble over the printed expectation: one pen line of tall zigzag
-- strokes with the route's pen (UI/Ink/Pen.lua: mitred, the nib's share,
-- stroked into quads that share their edges), in ink at `alpha` (a hair of
-- paper shows through, as ink does; the readability comes from the shape,
-- not the alpha). Its turns lie `over` px past the figures' cap band (`cap`
-- of the type's size), so only straight thin diagonals cross the letters;
-- a zig and zag `pitch` of the size apart, each turn off by `jitter` of a
-- stroke; from `lead` px before the words to `tail` past them; slanted
-- `slant` degrees about its middle; each turn rounded `bend` px along its
-- sides, its corner pulled `round` of that into the turn; tapered from
-- `from` of its width over its first `over` px and to `end` over its last
-- `off` px. At most `most` pieces: the pitch widens past that. (An earlier
-- try at .62 of the size a tooth and 1.3 px wide blacked the words out.)
local SCRIBBLE = { width = 1.0, nib = { angle = 40, thin = 0.6, thick = 1.2 }, alpha = 0.92, pitch = 1.45,
    cap = 0.70, over = { 2.2, 3.2 }, lead = { 2, 4 }, tail = { 2, 4.5 }, slant = { -4, 2 }, jitter = 0.15,
    bend = 1.4, round = 0.35, taper = { from = 0.7, over = 4, ["end"] = 0.45, off = 5 }, most = 48 }
-- The underline under "dropped" (at S, the count): the same pen, a
-- quadratic from `lead` px before the word to `run` past it, `drop` px under
-- the baseline (through the p's tails, as a hand's underline runs), sagging
-- `sag` in its middle and rising `rise` toward its end as the hand flicks
-- off; each end given or taken `jitter`; a piece every `step` px, at most
-- `most`; tapered from `from` over `over` px and to `end` over its last
-- `off`.
local UNDER = { width = 1.35, nib = SCRIBBLE.nib, drop = 3.4, sag = 0.5, rise = 1.3, lead = 1.5, run = 4,
    jitter = 0.4, step = 3.5, taper = { from = 0.85, over = 3, ["end"] = 0.4, off = 7 }, most = 16 }
-- S, on a light plate's print: the slip's margins, its height (`height`:
-- its foot `bottom` px inside the print's, so it covers the print's border
-- and the lowest of the map), its own turn on the print (`turn`, degrees),
-- the struck words' size and the hand's on the tag (`line` px a line); the
-- tag's margins, `clear` px past the scribble's end, `drop` px under the
-- slip's top, so it hangs past the print's foot onto the page. The item's
-- icon, `icon` px (and HuntCard's 1 px edge), `gap` px past the tag, stuck
-- on the slip's right edge with `share` of it on the slip and the rest past
-- it (the user's choice, 13 Oct). Along the foot it starts `pc` + 2 px past
-- a photo corner, or `edge` px from the print's edge where a corner has
-- none; it moves to the foot's right end only where its star lies under
-- it (`star` px round); a leader goes up to the star only where the star
-- is `near` px off or more.
local PRINT = { pad = { 4, 3, 4, 3 }, height = 21, bottom = 2, turn = { 0.2, 0.7 }, struck = 11, hand = 14, line = 17,
    tagPad = { 7, 4, 5, 4 }, clear = 2, drop = 2, icon = 18, gap = 3, share = 0.6, edge = 6, star = 9, near = 22 }

local HAND = Style.NEUTON_ITALIC

--------------------------------------------------------------------------
-- Which hunt
--------------------------------------------------------------------------

-- How lucky a hunt was: its kills over those expected (smaller is luckier).
function LuckyCard.Ratio(hunt)
    local expected = hunt and hunt.expected
    if type(expected) ~= "number" or expected <= 0 then return math.huge end
    return (hunt.kills or 0) / expected
end

-- The plate's one lucky card, from its stars (plate.fortuneMarks: { x, y
-- on the card, list of moments, at = { x, y } on the page }): the luckiest
-- hunt, the latest of equals. { hunt, mark (on the page), x, y (on the
-- card) } or nil.
function LuckyCard.Choose(marks)
    local best, bestMark, bestRatio
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local hunt = m.hunt
            -- One the player changed or wrote has a card of its own (Customs).
            if hunt and not hunt.customOf then
                local ratio = LuckyCard.Ratio(hunt)
                if not best or ratio < bestRatio or (ratio == bestRatio and (hunt.t or 0) > (best.t or 0)) then
                    best, bestMark, bestRatio = hunt, mark, ratio
                end
            end
        end
    end
    if not best then return nil end
    return { hunt = best, mark = bestMark.at, x = bestMark.x, y = bestMark.y }
end

-- The good luck on a plate the player changed or wrote (Core/Custom.lua), each
-- with its item named, in the shape Choose gives, the newest first: where the
-- margin runs out the oldest are left to their marks, and a light plate's print
-- tells the first. One with no item has nothing to head a card with: the mark
-- and the words tell it.
function LuckyCard.Customs(marks)
    local list = {}
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local hunt = m.hunt
            if hunt and hunt.customOf and type(hunt.item) == "string" and hunt.item ~= "" then
                list[#list + 1] = { hunt = hunt, mark = mark.at, x = mark.x, y = mark.y }
            end
        end
    end
    table.sort(list, function(a, b) return (a.hunt.t or 0) > (b.hunt.t or 0) end)
    return list
end

--------------------------------------------------------------------------
-- The pen
--------------------------------------------------------------------------

-- A number from a string, the same every time (the strip's,
-- UI/Paper/Surface.lua), and a stream of them; a point of a slip turned
-- about its middle (Surface.Turned).
local Seed, Turned = ns.UI.Surface.Seed, ns.UI.Surface.Turned

local function Random(key)
    local rand = ns.UI.Pen.Random(Seed(key))
    return function(a, b) return a + (b - a) * rand() end, rand
end

local function Unit(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return 0, 0 end
    return dx / len, dy / len
end

-- The scribble over printed words from x0, `w` wide, the middle of their
-- cap band at `mid`, type `size` px, seeded by `seed` (a string): its
-- points { { x, y }, ... }; and, for the tests, its turns before they were
-- rounded and slanted, and the band's half height.
function LuckyCard.Scribble(seed, x0, mid, w, size)
    local U, rand = Random(seed)
    local S = SCRIBBLE
    local half, pitch = S.cap * size / 2, S.pitch * size
    local xs, xe = x0 - U(S.lead[1], S.lead[2]), x0 + w + U(S.tail[1], S.tail[2])
    -- Strokes: as many as fit at about half a pitch each, spread evenly;
    -- each turn makes three points, so past `most` pieces fewer, wider.
    local n = math.max(3, math.floor((xe - xs) / (pitch / 2) + 0.5))
    while 3 * n + 1 > S.most and n > 3 do n = n - 1 end
    local step = (xe - xs) / n
    local up = rand() < 0.6
    local raw = { { xs, mid + (up and 1 or -1) * half * 0.35 } }
    for k = 1, n do
        local x = k == n and xe or (xs + k * step + U(-S.jitter, S.jitter) * step)
        raw[#raw + 1] = { x, mid + (up and -1 or 1) * (half + U(S.over[1], S.over[2])) }
        up = not up
    end
    -- The pen lifts on its way back: a last short stroke toward the middle.
    local last = raw[#raw]
    raw[#raw + 1] = { last[1] + pitch * 0.2, mid + (last[2] - mid) * -0.2 }
    -- Each turn rounded: a point `bend` back along each side, the corner
    -- pulled `round` of that into the turn.
    local P = { { x = raw[1][1], y = raw[1][2] } }
    for i = 2, #raw - 1 do
        local a, b, c = raw[i - 1], raw[i], raw[i + 1]
        local d1x, d1y = Unit(a[1], a[2], b[1], b[2])
        local d2x, d2y = Unit(b[1], b[2], c[1], c[2])
        P[#P + 1] = { x = b[1] - d1x * S.bend, y = b[2] - d1y * S.bend }
        P[#P + 1] = { x = b[1] + (d2x - d1x) * S.round * S.bend, y = b[2] + (d2y - d1y) * S.round * S.bend }
        P[#P + 1] = { x = b[1] + d2x * S.bend, y = b[2] + d2y * S.bend }
    end
    P[#P + 1] = { x = raw[#raw][1], y = raw[#raw][2] }
    -- A hand is never level: the whole of it slanted about its middle.
    local slant = math.rad(U(S.slant[1], S.slant[2]))
    local cx, co, si = x0 + w / 2, math.cos(slant), math.sin(slant)
    for _, p in ipairs(P) do
        local dx, dy = p.x - cx, p.y - mid
        p.x, p.y = cx + dx * co - dy * si, mid + dx * si + dy * co
    end
    return P, raw, half
end

-- The underline under a word from x0 to x1, its baseline at `base`: its
-- points (UNDER), seeded by `seed`.
function LuckyCard.Underline(seed, x0, x1, base)
    local U = Random(seed)
    local D = UNDER
    local ax, ay = x0 - D.lead, base + D.drop + U(-D.jitter, D.jitter) + 0.3
    local zx, zy = x1 + D.run, base + D.drop - D.rise + U(-D.jitter, D.jitter)
    local cx, cy = (ax + zx) / 2, (ay + zy) / 2 + 2 * D.sag
    local len = math.sqrt((zx - ax) ^ 2 + (zy - ay) ^ 2)
    local n = math.min(D.most, math.max(3, math.ceil(len / D.step)))
    local P = {}
    for i = 0, n do
        local t = i / n
        local u = 1 - t
        P[#P + 1] = { x = u * u * ax + 2 * u * t * cx + t * t * zx, y = u * u * ay + 2 * u * t * cy + t * t * zy }
    end
    return P
end

-- `P` drawn with the pen (SCRIBBLE's or UNDER's look): the quads, as
-- the pen's primitives (ns.UI.Pen), each vertex's half-width its nib's
-- share of the width, tapered where the pen lands and where it lifts.
function LuckyCard.Pen(P, look)
    local Pen = ns.UI.Pen
    local n = #P
    if n < 2 then return {} end
    P[1].s = 0
    for i = 2, n do P[i].s = P[i - 1].s + math.sqrt((P[i].x - P[i - 1].x) ^ 2 + (P[i].y - P[i - 1].y) ^ 2) end
    local total, T = P[n].s, look.taper
    local M = Pen.Mitres(P)
    local function Half(i)
        local a, b = P[math.max(i - 1, 1)], P[math.min(i + 1, n)]
        local t = math.min(1, T.from + (1 - T.from) * P[i].s / T.over)
        local left = total - P[i].s
        if left < T.off then t = t * (T["end"] + (1 - T["end"]) * left / T.off) end
        return look.width / 2 * Pen.Nib(b.x - a.x, b.y - a.y, look.nib) * t
    end
    local prims = {}
    Pen.Stroke(prims, 0, P, M, Half, function() return 0 end, function() return SCRIBBLE.alpha end,
        Style.INK_STRONG, nil, look.most)
    return prims
end

-- A piece of the pen laid flat where corners cannot move: from the middle
-- of its start to the middle of its end, as wide as it is on average.
-- Returns its middle, length, width and angle (y down).
local function Flat(q)
    local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
    local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
    local dx, dy = ex - sx, ey - sy
    local width = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2) + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
    return (sx + ex) / 2, (sy + ey) / 2, math.sqrt(dx * dx + dy * dy) + 0.3, math.max(width, 0.4), math.atan2(-dy, dx)
end

--------------------------------------------------------------------------
-- Measures
--------------------------------------------------------------------------

-- Text measured unbounded (UI/Paper/Surface.lua's).
local Width = ns.UI.Surface.Width

-- `text` in the diary's hand at `size` (its own, 16, without one).
local function Hand(text, size)
    text:SetFontObject(Style.FONT.noteWritten)
    if size and size ~= 16 then text:SetFont(HAND, size, "") end
end

-- The printed words at `size`: FONT.faded (13) or FONT.small (11), both
-- Friz in faded ink.
local function Printed(text, size)
    text:SetFontObject(size == 13 and Style.FONT.faded or Style.FONT.small)
end

-- Hidden font strings for measuring S before it is drawn (the page asks
-- whether it will go on a print, LuckyCard.PrintFits).
local probe
local function Probe()
    if not probe then
        probe = { struck = Style.Text(UIParent, Style.FONT.small), hand = Style.Text(UIParent, Style.FONT.noteWritten) }
        probe.struck:Hide()
        probe.hand:Hide()
    end
    return probe
end

--------------------------------------------------------------------------
-- The card (XL, L, M)
--------------------------------------------------------------------------

-- A card on `parent` (the right page): card:SetHunt(chosen, seed, now)
-- with LuckyCard.Choose's choice, then card:Layout(x, y, width) as a
-- strip's; card.overfull where no arrangement fits `width` (the page
-- leaves it off); card:Smaller() gives up a step. The tag is a slip of its
-- own on the card (card.tag), laid with it. Laid through the strip's hooks
-- (UI/Paper/Strip.lua), `hooks`, filled in below, after its drawing.
function LuckyCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    -- The strip's margins round the writing (l, t, r, b).
    local pad = { card:Pad() }
    local Hunt = Hunts.HuntCard
    local ICON, COUNT = Hunt.ICON, Hunt.COUNT

    local function Texture(frame, layer, sublevel)
        local texture = frame:CreateTexture(nil, layer, nil, sublevel)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        return texture
    end
    card.iconShadow = Texture(card, "ARTWORK", 4)
    card.iconEdge = Texture(card, "ARTWORK", 5)
    card.icon = Texture(card, "ARTWORK", 6)
    card.count = card:CreateFontString(nil, "OVERLAY")
    card.count:SetFont(COUNT.file, COUNT.size, "OUTLINE")
    -- The printed words under the scribble (ARTWORK 3), as print lies
    -- under ink.
    card.struck = Style.Text(card, Style.FONT.faded, "ARTWORK")
    card.struck:SetDrawLayer("ARTWORK", 2)
    card.kind = Style.Text(card, Style.FONT.small)
    card.headTail = Style.Text(card, Style.FONT.noteWritten)
    card.ink = {}
    -- A hidden measure in the hand (the card's own, not a field:
    -- `measure` is the strip's name).
    local measure = Style.Text(card, Style.FONT.noteWritten)
    measure:Hide()

    -- The icon takes the mouse for the item's own tooltip (the bad-luck
    -- card's), a level over the slip's.
    card.item = CreateFrame("Button", nil, card)
    card.item:SetScript("OnEnter", function(self) Hunt.ShowTip(self, card) end)
    card.item:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The tag: a blank slip of its own, on the card, written on here.
    local tag = ns.UI.PaperStrip(card)
    card.tag = tag
    tag.words = { Style.Text(tag, Style.FONT.noteWritten), Style.Text(tag, Style.FONT.noteWritten) }
    tag.ink = {}

    function card:SetHunt(chosen, seed, now)
        local hunt = chosen.hunt
        self.chosen, self.hunt, self.now, self.seedKey = chosen, hunt, now, seed
        self.usual = nil
        self.iconFile, self.itemID, self.iconFrom = Hunt.Icon(hunt)
        self.step, self.plan = 0, nil
        local function Tip()
            local title, lines = Hunts.CardTip(hunt, now)
            return Style.TipList(title, lines)
        end
        self.tipLines = Tip
        -- The heading's words as set on the note: its own copy, for Heading
        -- (Preferred measures a card that is never laid).
        self.nameWords = Hunts.Item(hunt)
        self:SetNote({ name = self.nameWords, strong = true, seed = seed, turn = LUCKY.turn, tip = Tip })
    end

    -- A step less, where the margin is short (UI/Journey/Margin.lua's
    -- LayNotes): the creature's line, then the icon. A step that gives
    -- nothing up (no creature's line but at XL) is passed over. Whether
    -- there was a step to give up.
    function hooks.smaller(self)
        local step = self.step or 0
        if step >= 2 then return false end
        if step == 0 and not (self.plan and self.plan.creature) then step = 1 end
        self.step = step + 1
        return true
    end

    -- The heading at the first size that fits `room` on one line, else on
    -- two (the second, card.headTail): { fits, tail (its words), nameH,
    -- tailH, w (the wider line) }.
    local function Heading(room)
        local words = card.nameWords or ""
        local function Head(fits, tail)
            card.name:SetSize(0, 0)
            local nameH = math.max(math.ceil(card.name:GetStringHeight() or 0), 14)
            local tailH = tail and math.max(math.ceil(card.headTail:GetStringHeight() or 0), 14) or 0
            return { fits = fits, tail = tail, nameH = nameH, tailH = tailH,
                w = math.max(Width(card.name), tail and Width(card.headTail) or 0) + 1 }
        end
        for _, size in ipairs({ 16, LUCKY.small }) do
            Hand(card.name, size)
            card.name:SetText(words)
            if Width(card.name) + 1 <= room then return Head(true, nil) end
        end
        for _, size in ipairs({ 16, LUCKY.small }) do
            Hand(card.name, size)
            Hand(card.headTail, size)
            local first, rest = "", nil
            for word in words:gmatch("%S+") do
                if rest then
                    rest = rest .. " " .. word
                else
                    local try = first == "" and word or (first .. " " .. word)
                    card.name:SetText(try)
                    if first ~= "" and Width(card.name) > room then rest = word else first = try end
                end
            end
            card.name:SetText(first)
            card.headTail:SetText(rest or "")
            if rest and Width(card.name) <= room and Width(card.headTail) <= room then return Head(true, rest) end
        end
        card.name:SetText(words)
        return Head(false, nil)
    end

    local function HandWidth(words, size)
        Hand(measure, size)
        measure:SetText(words)
        return Width(measure)
    end

    -- One arrangement (FORMS[form]) in `width` px: its plan, or nil where it
    -- does not fit (`force`: laid all the same, for the page to measure
    -- and leave off). All of it from the card's top left, y down; `W` by
    -- `H` the card and its tag together, `Wb` by `Hb` the card.
    local function Try(form, width, force)
        local F = FORMS[form]
        local hunt = card.hunt
        local lines = Hunts.LuckyTag(hunt, form)
        local lw = 0
        for _, line in ipairs(lines) do lw = math.max(lw, HandWidth(line.text, F.hand)) end
        local lh = TAG.line[F.hand]
        local tag = { w = math.ceil(TAG.pad[1] + lw + 1 + TAG.pad[3]), h = TAG.pad[2] + #lines * lh + TAG.pad[4],
            lines = lines, hand = F.hand, lh = lh, tape = F.side and "corner" or "left" }
        local step = card.step or 0
        local icon = step >= 2 and 0 or (width < ICON.below and ICON.narrow or ICON.size)
        local iconH = icon > 0 and icon + 2 * ICON.edge or 0
        local label = Hunts.ExpectedLabel(hunt)
        Printed(card.struck, F.struck)
        card.struck:SetText(label)
        -- (Measured as the proposal's mockup measured it, bare: the scribble's
        -- tail runs past the words' end anyway.)
        local sw = Width(card.struck)
        local sx = icon > 0 and pad[1] + iconH + ICON.gap or pad[1] + SCRIBBLE.lead[2]
        local send = sx + sw + SCRIBBLE.tail[2]
        local rowH = icon > 0 and iconH or ROW[F.struck]
        local W
        if F.side then
            tag.x = math.ceil(send + LUCKY.clear)
            W = tag.x + tag.w
            if W > width and not force then return nil end
        else
            W = width
            tag.x = W - tag.w
            if tag.x < LUCKY.show and not force then return nil end
        end
        local Wb = W - F.over
        if send > Wb - 2 and not force then return nil end
        local head = Heading(Wb - pad[1] - pad[3])
        if not head.fits and not force then return nil end
        local headBottom = pad[2] + head.nameH + (head.tail and head.tailH or 0)
        local rowTop = headBottom + LUCKY.gap
        local rowBottom = rowTop + rowH
        local Hb, H, creature
        if F.side then
            -- Beside: its top a little over the row's, or under the heading
            -- where the heading runs that far right.
            tag.y = (pad[1] + head.w > tag.x - 4) and headBottom + 1 or rowTop - LUCKY.rise
            local words = form == "XL" and step < 1 and Hunts.LuckyKind(hunt)
            if words then
                card.kind:SetText(words)
                if pad[1] + Width(card.kind) + 1 <= tag.x - 6 then
                    creature = { text = words, y = rowBottom + LUCKY.after }
                end
            end
            Hb = (creature and creature.y + LUCKY.creature or rowBottom) + pad[4]
            H = math.max(Hb, tag.y + tag.h)
        else
            -- Under: on the card's lower right, hanging past its foot.
            tag.y = rowBottom + LUCKY.drop
            Hb = tag.y + LUCKY.land
            H = tag.y + tag.h
        end
        return { form = form, W = W, H = H, Wb = Wb, Hb = Hb, head = head, icon = icon, iconH = iconH,
            rowTop = rowTop, rowH = rowH, struck = { text = label, size = F.struck, x = sx, w = sw },
            tag = tag, creature = creature, over = F.over }
    end

    -- `text` laid with its left at x, its middle at y (from the card's
    -- middle, y down).
    local function Put(slip, text, x, y, w, h)
        slip:Lay(text, x + w / 2, y, w, h)
        text:Show()
    end

    -- The pen's quads on `slip` (from its middle), from its pool `list`;
    -- where corners cannot move, each a turned flat stroke.
    local function Ink(slip, list, prims, layer, sublevel)
        for k, q in ipairs(prims) do
            local t = list[k]
            if not t then
                t = Texture(slip, layer, sublevel)
                list[k] = t
            end
            t:SetColorTexture(q.r, q.g, q.b, q.a)
            if not slip:Bend(t, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local mx, my, length, w, angle = Flat(q)
                slip:Lay(t, mx, my, length, w, angle)
            end
            t:Show()
        end
        for k = #prims + 1, #list do list[k]:Hide() end
        return #prims
    end

    -- Points from a slip's top left (w by h) to its middle.
    local function Centred(P, w, h)
        for _, p in ipairs(P) do p.x, p.y = p.x - w / 2, p.y - h / 2 end
        return P
    end

    -- The card's writing and the tag, as planned, the card laid `Wb` by `Hb`.
    local function Draw(plan, Wb, Hb)
        local INK = Style.INK
        local seed = card.seedKey or "lucky"
        local function C(x, y) return x - Wb / 2, y - Hb / 2 end
        -- The heading's second line.
        card.headTail:SetShown(plan.head.tail ~= nil)
        if plan.head.tail then
            local x, y = C(pad[1], pad[2] + plan.head.nameH + plan.head.tailH / 2)
            Put(card, card.headTail, x, y, Width(card.headTail) + 2, plan.head.tailH)
        end
        -- The icon, pasted in, its count over its corner.
        local size, flat = plan.icon, card.flat
        local shown = size > 0
        for _, part in ipairs({ card.iconShadow, card.iconEdge, card.icon, card.count, card.item }) do
            part:SetShown(shown)
        end
        local mid = plan.rowTop + plan.rowH / 2
        if shown then
            local ix, iy = C(pad[1] + plan.iconH / 2, mid)
            local S, E = ICON.shadow, Hunt.Edge(card.iconFrom ~= "sack" and card.itemID or nil)
            card.iconShadow:SetColorTexture(INK[1], INK[2], INK[3], S[3])
            card:Lay(card.iconShadow, ix + S[1], iy + S[2], plan.iconH, plan.iconH)
            card.iconShadow:SetShown(not flat)
            card.iconEdge:SetColorTexture(E[1], E[2], E[3], 1)
            card:Lay(card.iconEdge, ix, iy, plan.iconH, plan.iconH)
            card.icon:SetTexture(card.iconFile)
            local k = ICON.crop
            card.icon:SetTexCoord(k, 1 - k, k, 1 - k)
            card:Lay(card.icon, ix, iy, size, size)
            if (card.hunt.need or 0) > 1 then
                local small = size < ICON.size
                card.count:SetFont(COUNT.file, small and COUNT.narrow or COUNT.size, "OUTLINE")
                card.count:SetTextColor(COUNT.colour[1], COUNT.colour[2], COUNT.colour[3], 1)
                card.count:SetText(tostring(card.hunt.need))
                local cw, ch = Width(card.count) + 2, (small and COUNT.narrow or COUNT.size) + 2
                Put(card, card.count, ix + size / 2 - COUNT.inset[1] - cw, iy + size / 2 - COUNT.inset[2] - ch / 2, cw, ch)
            else
                card.count:Hide()
            end
            -- The mouse over the icon as drawn: one square button round it.
            local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
            local half = size / 2 + 1
            for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
                local px, py = card:Out(ix + corner[1] * half, iy + corner[2] * half)
                x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
            end
            card.item:SetFrameLevel(card:GetFrameLevel() + 2)
            card.item:ClearAllPoints()
            card.item:SetPoint("TOPLEFT", parent, "TOPLEFT", x0, -y0)
            card.item:SetSize(x1 - x0, y1 - y0)
        end
        -- The drop tables' word, printed, and the hand's scribble over it.
        local st = plan.struck
        Printed(card.struck, st.size)
        card.struck:SetText(st.text)
        local sx, sy = C(st.x, mid)
        Put(card, card.struck, sx, sy, st.w + 1, st.size + 4)
        local P = Centred(LuckyCard.Scribble(seed .. ":s", st.x, mid, st.w, st.size), Wb, Hb)
        card.scribble = P
        card.pieces = Ink(card, card.ink, LuckyCard.Pen(P, SCRIBBLE), "ARTWORK", 3)
        -- Who dropped it (XL).
        card.kind:SetShown(plan.creature ~= nil)
        if plan.creature then
            card.kind:SetText(plan.creature.text)
            card.kind:SetTextColor(INK[1], INK[2], INK[3])
            local kx, ky = C(pad[1], plan.creature.y + LUCKY.creature / 2)
            Put(card, card.kind, kx, ky, Width(card.kind) + 2, LUCKY.creature)
        end

        -- The tag: turned the other way from the card, its tape where it
        -- holds it and never on the struck words (over its top-left corner
        -- beside them; across its left edge a third down under them, where
        -- over the corner it would reach up into the row).
        local t = plan.tag
        local U = Random(seed .. ":tag")
        local sign = (card.turn or 0) < 0 and 1 or ((card.turn or 0) > 0 and -1 or (U(0, 1) < 0.5 and -1 or 1))
        local tilt = sign * U(TAG.turn[1], TAG.turn[2])
        local slant = U(TAG.tape.slant[1], TAG.tape.slant[2])
        local tape = { x = 1, y = 1, slant = slant, w = TAG.tape.w, h = TAG.tape.h }
        if t.tape == "left" then
            tape.x, tape.y, tape.slant = 0, math.min(t.h * 0.36, 12), 90 - (slant - 45) * 0.8 - 8
        end
        tag:SetNote({ name = "", strong = true, seed = seed .. ":tag", size = { t.w, t.h }, paper = TAG.paper,
            tilt = tilt, tapeAt = tape, shadow = TAG.shadow, soft = TAG.soft, tip = card.tipLines })
        tag:SetFrameLevel(card:GetFrameLevel() + 2)
        tag:Layout(t.x, t.y, t.w)
        local ink = {}
        for i, word in ipairs(tag.words) do
            local line = t.lines[i]
            word:SetShown(line ~= nil)
            if line then
                Hand(word, t.hand)
                word:SetText(line.text)
                word:SetTextColor(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3])
                local lx, ly = TAG.pad[1], TAG.pad[2] + (i - 0.5) * t.lh
                Put(tag, word, lx - t.w / 2, ly - t.h / 2, Width(word) + 2, t.lh)
                if line.under then
                    local at = line.text:find(line.under, 1, true) or 1
                    local x0 = lx + (at > 1 and HandWidth(line.text:sub(1, at - 1), t.hand) or 0)
                    local x1 = x0 + HandWidth(line.under, t.hand)
                    local U2 = Centred(LuckyCard.Underline(seed .. ":u", x0, x1, ly + 0.3 * t.hand), t.w, t.h)
                    for _, q in ipairs(LuckyCard.Pen(U2, UNDER)) do ink[#ink + 1] = q end
                end
            end
        end
        Ink(tag, tag.ink, ink, "ARTWORK", 6)
    end

    -- Laid as a strip, the first arrangement that fits `width` (FORMS, in
    -- ORDER, or BARE with the icon given up), the tag laid over it: the
    -- slip laid at the card's own width (plan.Wb), the card and its tag
    -- together the note's size (plan.W by plan.H, the strip's box).
    function hooks.plan(self, note, width)
        local order = (self.step or 0) >= 2 and BARE or ORDER
        local plan
        for _, form in ipairs(order) do
            plan = Try(form, width)
            if plan then break end
        end
        self.overfull = plan == nil
        plan = plan or Try(order[#order], width, true)
        -- The heading again for the arrangement kept.
        plan.head = Heading(plan.Wb - pad[1] - pad[3])
        local gap = plan.head.tail and 0 or LUCKY.gap
        note.under = { w = plan.Wb - pad[1] - pad[3], gap = gap, after = 0,
            h = plan.Hb - pad[2] - plan.head.nameH - gap - pad[4] }
        note.least, note.what = plan.Wb, nil
        self.plan = plan
        return plan, plan.Wb
    end
    function hooks.draw(self, plan, Wb, Hb)
        Draw(plan, Wb, Hb)
        -- For the tests and the page: where it lies, the tag with it.
        return plan.W, plan.H
    end

    -- The width the card would like: the wide arrangement (XL), the tag
    -- beside the struck words. The page gives a row's box this much where
    -- it has it (UI/Journey/Margin.lua's ROW).
    function card:Preferred()
        return Try("XL", 10000, true).W
    end

    -- The point of either slip's edge nearest x, y of the page: a leader
    -- leaves the card there, so it never crosses the tag.
    function hooks.nearest(self, x, y, bx, by)
        local box = self.box
        if not (box and tag.box) then return bx, by end
        local tx, ty = tag:Nearest(x - box[1], y - box[2])
        tx, ty = tx + box[1], ty + box[2]
        if (tx - x) ^ 2 + (ty - y) ^ 2 < (bx - x) ^ 2 + (by - y) ^ 2 then return tx, ty end
        return bx, by
    end

    -- For the tests: the tag's words as written, its lines joined by "/".
    function card:Tag()
        local parts = {}
        for i, word in ipairs(tag.words) do
            if word:IsShown() and self.plan and self.plan.tag.lines[i] then parts[#parts + 1] = word:GetText() end
        end
        return table.concat(parts, "/")
    end

    card:HookScript("OnHide", function() card.item:Hide() end)
    return card
end

-- The width a card for `chosen` (LuckyCard.Choose's) would like
-- (card:Preferred), measured on a card of its own that is never shown.
local measurer
function LuckyCard.Preferred(chosen)
    measurer = measurer or LuckyCard.New(UIParent)
    measurer:SetHunt({ hunt = chosen.hunt, mark = { 0, 0 } }, "measure", 0)
    return measurer:Preferred()
end

--------------------------------------------------------------------------
-- S, on a light plate's print
--------------------------------------------------------------------------

-- Where S may lie along a print's foot (`slot`, the page's LAYOUT): from
-- past its lower-left photo corner to short of the lower-right one, or
-- PRINT.edge px from the print's edge where a corner has none (the corner
-- come unstuck). Its left and right, from the card's left.
function LuckyCard.PrintRoom(slot)
    local has = {}
    for _, corner in ipairs(slot.corners or {}) do has[corner] = true end
    local left = has.bl and (slot.pc or 0) + 2 or PRINT.edge
    local right = has.br and slot.w - (slot.pc or 0) - 2 or slot.w - PRINT.edge
    return left, right
end

-- S for `hunt` in `room` px along the foot: the first of its wordings
-- ("after four", then the count alone) that fits with the icon, or nil.
-- All of it from S's top left, y down: the slip `Wb` by `Hb`, S as a whole
-- `W` by `H` (the tag hangs below the slip, the icon past its right end).
function LuckyCard.PrintPlan(hunt, room)
    local ICON = Hunts.HuntCard.ICON
    local p, P = Probe(), PRINT
    local label = Hunts.ExpectedLabel(hunt)
    Printed(p.struck, P.struck)
    p.struck:SetText(label)
    local sw = Width(p.struck)
    local sx = P.pad[1] + 1
    local send = sx + sw + SCRIBBLE.tail[2]
    local box = P.icon + 2 * ICON.edge
    local tagH = P.tagPad[2] + P.line + P.tagPad[4]
    for _, form in ipairs({ "S", "S-" }) do
        local lines = Hunts.LuckyTag(hunt, form)
        Hand(p.hand, P.hand)
        p.hand:SetText(lines[1].text)
        local tagX = math.ceil(send + P.clear)
        local tagW = math.ceil(P.tagPad[1] + Width(p.hand) + 1 + P.tagPad[3])
        -- The icon past the tag, `gap` clear of it, `share` on the slip.
        local iconX = tagX + tagW + P.gap
        local W = iconX + box
        if W <= room then
            return { form = form, W = W, H = math.max(P.height, P.drop + tagH), Wb = math.ceil(iconX + P.share * box),
                Hb = P.height, struck = { text = label, size = P.struck, x = sx, w = sw },
                tag = { x = tagX, y = P.drop, w = tagW, h = tagH, lines = lines },
                icon = { x = iconX, y = (P.height - box) / 2, box = box, size = P.icon } }
        end
    end
    return nil
end

-- The luckiest of a plate's good luck from its plan's moments (Recap's),
-- before it is drawn.
local function PlannedLuck(p)
    local list = {}
    for _, m in ipairs(p and p.moments or {}) do
        if m.kind == "fortune" and m.hunt then list[#list + 1] = m end
    end
    if #list == 0 then return nil end
    local marks = { { list = list } }
    return LuckyCard.Customs(marks)[1] or LuckyCard.Choose(marks)
end

-- Whether a light plate (`p`, its plan) can have its luck told on the
-- print in `slot`: true without any; false where S will not fit, so the
-- page does not tuck the print in (F+L), where nothing may be lost.
function LuckyCard.PrintFits(p, slot)
    local chosen = PlannedLuck(p)
    if not chosen then return true end
    local left, right = LuckyCard.PrintRoom(slot)
    return LuckyCard.PrintPlan(chosen.hunt, right - left) ~= nil
end

-- S drawn on a print through its own toolkit, `kit`: { Place (K.Place),
-- Quad (K.Quad), Texture(part), Text(part) } with the parts' textures and
-- font strings from the plate's pools (its pass's, below: PRINT_LAYERS and
-- PRINT_TEXTS, made through the plate's over-kit). `chosen` is
-- LuckyCard.Choose's (x, y: its star on the card), `slot` the print's,
-- `seed` a string, `flat` laid flat. Nil where it will not fit (the caption
-- keeps the hunt's words); else where it went, all on the card, from its
-- top left: { plan, left, top, label, tag, icon (each four corners),
-- edge (S's top edge, two points, for its leader), hit, iconHit ({ x, y,
-- w, h }: the mouse's squares), star }.
function LuckyCard.Print(kit, chosen, slot, seed, flat)
    local Hunt = Hunts.HuntCard
    local ICON, COUNT = Hunt.ICON, Hunt.COUNT
    -- The strip's look (UI/Paper/Strip.lua's PAPER_LOOK): S is drawn in it.
    local LOOK, TAPE = ns.UI.PAPER_LOOK, ns.UI.PAPER_LOOK.tape
    local hunt = chosen.hunt
    local left0, right0 = LuckyCard.PrintRoom(slot)
    local plan = LuckyCard.PrintPlan(hunt, right0 - left0)
    if not plan then return nil end
    local P = PRINT
    local top = slot.h - P.bottom - plan.Hb
    local left = left0
    -- At the foot's right end only where its star lies under it.
    local star = chosen.x and { chosen.x, chosen.y } or nil
    if star and star[1] > left - P.star and star[1] < left + plan.W + P.star and star[2] > top - P.star then
        left = right0 - plan.W
    end

    local U, rand = Random(seed)
    local sign = rand() < 0.5 and -1 or 1
    local a = flat and 0 or sign * math.rad(U(P.turn[1], P.turn[2]))
    local b = flat and 0 or -sign * math.rad(U(TAG.turn[1], TAG.turn[2]))
    local INK, INK_STRONG = Style.INK, Style.INK_STRONG
    -- A point of a slip turned `t` about its middle cx, cy (u, v from its
    -- middle, y down) on the card.
    local function To(cx, cy, t, u, v)
        local c, s = math.cos(t), math.sin(t)
        return Turned(cx, cy, u, v, c, s)
    end
    local function Corners(cx, cy, t, w, h)
        local list = {}
        for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local x, y = To(cx, cy, t, k[1] * w / 2, k[2] * h / 2)
            list[#list + 1] = { x, y }
        end
        return list
    end
    -- `region` with its middle at x, y of the card, w by h, turned `t` more
    -- than the print, moved dx, dy on the screen (y up).
    local function Put(region, x, y, w, h, t, dx, dy)
        kit.Place(region, x - w / 2, y - h / 2, w, h, t, dx, dy)
        region:Show()
        return region
    end
    local function Colour(part, c, alpha)
        local texture = kit.Texture(part)
        texture:SetColorTexture(c[1], c[2], c[3], alpha)
        if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
        return texture
    end
    -- The pen's quads (on the card) from `part`'s pool; flat strokes
    -- where corners cannot move.
    local function Ink(part, prims)
        for _, q in ipairs(prims) do
            local texture = Colour(part, { q.r, q.g, q.b }, q.a)
            if not kit.Quad(texture, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local mx, my, length, w, angle = Flat(q)
                Put(texture, mx, my, length, w, angle)
            end
        end
        return #prims
    end
    local function OnCard(points, cx, cy, t, w, h)
        for _, p in ipairs(points) do p.x, p.y = To(cx, cy, t, p.x - w / 2, p.y - h / 2) end
        return points
    end

    -- The slip, glued on the print: its contact shadow, its cut edge, the
    -- card's stock.
    local Lx, Ly = left + plan.Wb / 2, top + plan.Hb / 2
    if not flat then
        local sh = LOOK.shadow
        Put(Colour("shadow", INK, sh[3]), Lx, Ly, plan.Wb, plan.Hb, a, sh[1], -sh[2])
    end
    Put(Colour("edge", INK, flat and LOOK.flatEdge or LOOK.edge), Lx, Ly, plan.Wb + 2, plan.Hb + 2, a)
    Put(Colour("paper", LOOK.paper, 1), Lx, Ly, plan.Wb, plan.Hb, a)
    -- The drop tables' word, and the scribble over it.
    local st = plan.struck
    local mid = P.pad[2] + (plan.Hb - P.pad[2] - P.pad[4]) / 2
    local text = kit.Text("struck")
    Printed(text, st.size)
    text:SetText(st.text)
    local tx, ty = To(Lx, Ly, a, st.x + st.w / 2 - plan.Wb / 2, mid - plan.Hb / 2)
    Put(text, tx, ty, st.w + 1, st.size + 4, a)
    local pieces = Ink("ink", LuckyCard.Pen(OnCard(LuckyCard.Scribble(seed .. ":s", st.x, mid, st.w, st.size),
        Lx, Ly, a, plan.Wb, plan.Hb), SCRIBBLE))
    -- The icon, stuck on the slip's right edge, its count over its corner.
    local ic = plan.icon
    local iconFile, itemID, from = Hunt.Icon(hunt)
    local ix, iy = To(Lx, Ly, a, ic.x + ic.box / 2 - plan.Wb / 2, ic.y + ic.box / 2 - plan.Hb / 2)
    if not flat then
        local S = ICON.shadow
        local sx, sy = To(Lx, Ly, a, ic.x + ic.box / 2 - plan.Wb / 2 + S[1], ic.y + ic.box / 2 - plan.Hb / 2 + S[2])
        Put(Colour("iconShadow", INK, S[3]), sx, sy, ic.box, ic.box, a)
    end
    local E = Hunt.Edge(from ~= "sack" and itemID or nil)
    Put(Colour("iconEdge", E, 1), ix, iy, ic.box, ic.box, a)
    local icon = kit.Texture("icon")
    icon:SetTexture(iconFile)
    if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
    local k = ICON.crop
    icon:SetTexCoord(k, 1 - k, k, 1 - k)
    Put(icon, ix, iy, ic.size, ic.size, a)
    local count
    if (hunt.need or 0) > 1 then
        count = kit.Text("count")
        count:SetFont(COUNT.file, COUNT.narrow, "OUTLINE")
        count:SetTextColor(COUNT.colour[1], COUNT.colour[2], COUNT.colour[3], 1)
        count:SetText(tostring(hunt.need))
        local cw, ch = Width(count) + 2, COUNT.narrow + 2
        local u = ic.x + ic.box / 2 + ic.size / 2 - COUNT.inset[1] - cw / 2 - plan.Wb / 2
        local v = ic.y + ic.box / 2 + ic.size / 2 - COUNT.inset[2] - ch / 2 - plan.Hb / 2
        local cx, cy = To(Lx, Ly, a, u, v)
        Put(count, cx, cy, cw, ch, a)
    end

    -- The tag, turned against the slip: its shadows on the slip and past
    -- the print's foot, its cut edge, its stock, the hand on it, the
    -- underline under the count, and its tape across its top edge.
    local t = plan.tag
    local Tx, Ty = left + t.x + t.w / 2, top + t.y + t.h / 2
    if not flat then
        local sh, so = TAG.shadow, TAG.soft
        Put(Colour("tagShadow", INK, sh[3]), Tx, Ty, t.w, t.h, b, sh[1], -sh[2])
        local d, r = so.out, so.out + so.blur
        local bottom = kit.Texture("tagShadow")
        Style.Shade(bottom, "VERTICAL", INK[1], INK[2], INK[3], 0, so.alpha)
        local bx, by = To(Tx, Ty, b, d / 2 + r / 2, t.h / 2 - 1 + (r + 1) / 2)
        Put(bottom, bx, by, t.w - d + r, r + 1, b)
        local right = kit.Texture("tagShadow")
        Style.Shade(right, "HORIZONTAL", INK[1], INK[2], INK[3], so.alpha, 0)
        local rx, ry = To(Tx, Ty, b, t.w / 2 - 1 + (r + 1) / 2, d / 2 - 0.5)
        Put(right, rx, ry, r + 1, t.h - d - 1, b)
    end
    Put(Colour("tagEdge", INK, flat and LOOK.flatEdge or LOOK.edge), Tx, Ty, t.w + 2, t.h + 2, b)
    Put(Colour("tagPaper", TAG.paper, 1), Tx, Ty, t.w, t.h, b)
    local line = t.lines[1]
    local words = kit.Text("tagText")
    Hand(words, P.hand)
    words:SetText(line.text)
    words:SetTextColor(INK_STRONG[1], INK_STRONG[2], INK_STRONG[3])
    local ww = Width(words) + 2
    local lx, ly = P.tagPad[1], P.tagPad[2] + P.line / 2
    local wx, wy = To(Tx, Ty, b, lx + ww / 2 - t.w / 2, ly - t.h / 2)
    Put(words, wx, wy, ww, P.line, b)
    local p = Probe()
    Hand(p.hand, P.hand)
    local at = line.text:find(line.under, 1, true) or 1
    p.hand:SetText(line.text:sub(1, at - 1))
    local x0 = lx + (at > 1 and Width(p.hand) or 0)
    p.hand:SetText(line.under)
    local x1 = x0 + Width(p.hand)
    local under = OnCard(LuckyCard.Underline(seed .. ":u", x0, x1, ly + 0.3 * P.hand), Tx, Ty, b, t.w, t.h)
    pieces = pieces + Ink("underline", LuckyCard.Pen(under, UNDER))
    -- The tape across its top edge, a third along, at the family's slant.
    local TW, TH = TAG.tape.w, TAG.tape.h
    local slant = flat and 0 or math.rad(TAPE.slant + (U(TAG.tape.slant[1], TAG.tape.slant[2]) - 45))
    local mx, my = To(Tx, Ty, b, math.max(TW / 2 + 1, t.w * 0.36) - t.w / 2, -t.h / 2)
    local turn = b + slant
    Put(Colour("tape", TAPE.tint, flat and TAPE.flatAlpha or TAPE.alpha), mx, my, TW, TH, turn)
    if not flat then
        for _, side in ipairs({ -1, 1 }) do
            local ex, ey = To(mx, my, turn, side * (TW - TAPE.ends) / 2, 0)
            Put(Colour("tape", TAPE.tint, TAPE.endAlpha), ex, ey, TAPE.ends, TH, turn)
        end
        local hx, hy = To(mx, my, turn, 0, -TH / 2 + TAPE.line / 2)
        Put(Colour("tape", TAPE.shine, TAPE.shineAlpha), hx, hy, TW, TAPE.line, turn)
    end
    local ex, ey = To(mx, my, turn, 0, TH / 2 - TAPE.line / 2)
    Put(Colour("tape", TAPE.edge, flat and TAPE.flatEdge or TAPE.edgeAlpha), ex, ey, TW, TAPE.line, turn)

    -- Where it all went, for the page (its leader, the mouse) and the tests.
    local function Bounds(...)
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, list in ipairs({ ... }) do
            for _, pt in ipairs(list) do
                x0, y0, x1, y1 = math.min(x0, pt[1]), math.min(y0, pt[2]), math.max(x1, pt[1]), math.max(y1, pt[2])
            end
        end
        return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
    end
    local labelCorners = Corners(Lx, Ly, a, plan.Wb, plan.Hb)
    local tagCorners = Corners(Tx, Ty, b, t.w, t.h)
    local iconCorners = Corners(ix, iy, a, ic.box, ic.box)
    local e1x, e1y = To(Lx, Ly, a, -plan.Wb / 2 + 10, -plan.Hb / 2)
    local e2x, e2y = To(Lx, Ly, a, plan.Wb / 2 - 10, -plan.Hb / 2)
    return { plan = plan, form = plan.form, left = left, top = top, label = labelCorners, tag = tagCorners,
        icon = iconCorners, edge = { { e1x, e1y }, { e2x, e2y } }, hit = Bounds(labelCorners, tagCorners, iconCorners),
        iconHit = Bounds(iconCorners), star = star, itemID = itemID, pieces = pieces, count = count ~= nil }
end

LuckyCard.LUCKY, LuckyCard.FORMS, LuckyCard.TAG, LuckyCard.SCRIBBLE, LuckyCard.UNDER, LuckyCard.PRINT =
    LUCKY, FORMS, TAG, SCRIBBLE, UNDER, PRINT

--------------------------------------------------------------------------
-- In the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- Good luck with a quest's drops (JRN-27, this card): after the
-- close call and before the slow hunt (the user's choice, 13 Oct), rarer,
-- and a happy moment, but never in place of a person, a find, a death or
-- a close call. On a light plate's print it is told on the print instead
-- (S, drawn by its pass below), so not in the margin: it stays told
-- there whatever the margin does (`said.fortune`'s `print`), counts as
-- written, and has a short leader up to its star where the star is not
-- right by it (plate.print.far); F+L is not kept where S
-- will not go on the tucked print (LuckyCard.PrintFits). On a card it is
-- taken as shown, as the hunt's is, until the card is left off.
do
    local function Printed(plate)
        return plate.print and { hunt = plate.print.hunt, print = true } or nil
    end
    ns.UI.JourneyMargin.Register("lucky", {
        order = 60, pool = "luckyPool", count = "luckyWritten",
        counted = function(shown, plate) return (shown[1] or plate.print) and 1 or 0 end,
        new = function(parent) return LuckyCard.New(parent) end,
        wants = function(it) return LuckyCard.Preferred(it.lucky) end,
        item = function(plate)
            local l = plate.lucky
            if not l or (plate.slot and plate.slot.light) then return nil end
            return { lucky = l, top = l.mark[2], x = l.mark[1] }
        end,
        write = function(card, it, c)
            local hunt = it.lucky.hunt
            card:SetHunt(it.lucky, c.Seed("lucky", hunt.questID or hunt.item or ""), c.now)
        end,
        mark = function(it) return it.lucky.mark end,
        custom = function(it) return "fortune", it.lucky.hunt end,
        assume = function(said, plate, slot)
            said.fortune = Printed(plate) or (plate.lucky and not slot.light and { hunt = plate.lucky.hunt })
        end,
        say = function(said, shown, plate)
            said.fortune = Printed(plate) or (shown[1] and { hunt = shown[1].lucky.hunt })
        end,
        fits = function(plan, slot) return LuckyCard.PrintFits(plan, slot) end,
        after = function(plate, c)
            if plate.print and plate.print.far then c.Leader(plate.print, plate.print.mark) end
        end,
    })

    -- The good luck the player changed or wrote, each its own card, past the
    -- plate's one (LuckyCard.Choose): 8 in the margin, among the custom cards
    -- and before the people's (10) (.claude/features/custom-cards.md). The same
    -- card, the same pool. The one on a light plate's print is told there, its
    -- card (`lucky` counts it, and `said.fortune` says so), and any other a
    -- light plate has, or that one where S would not fit, comes here, under the
    -- caption, as a campfire's slip does: the player's card is not to go missing
    -- for want of a print, where a detected one's words would do.
    local function Carded(plate)
        local list = {}
        for _, l in ipairs(LuckyCard.Customs(plate.fortuneMarks)) do
            if not (plate.print and plate.print.hunt == l.hunt) then list[#list + 1] = l end
        end
        return list
    end
    ns.UI.JourneyMargin.Register("luckyCustom", {
        order = 8, pool = "luckyPool", count = "customLuckyWritten",
        new = function(parent) return LuckyCard.New(parent) end,
        wants = function(it) return LuckyCard.Preferred(it.lucky) end,
        items = function(plate)
            local items = {}
            for _, l in ipairs(Carded(plate)) do
                items[#items + 1] = { lucky = l, top = l.mark[2], x = l.mark[1] }
            end
            return items
        end,
        write = function(card, it, c)
            local hunt = it.lucky.hunt
            card:SetHunt(it.lucky, c.Seed("lucky", hunt.t or hunt.item), c.now)
        end,
        mark = function(it) return it.lucky.mark end,
        custom = function(it) return "fortune", it.lucky.hunt end,
        assume = function(said, plate)
            local set = {}
            for _, l in ipairs(Carded(plate)) do set[l.hunt] = true end
            said.fortunes = set
        end,
        say = function(said, shown)
            local set = {}
            for _, it in ipairs(shown) do set[it.lucky.hunt] = true end
            said.fortunes = set
        end,
    })
end

--------------------------------------------------------------------------
-- S, drawn on the plate (Plate.RegisterPass)
--------------------------------------------------------------------------

-- Good luck told on a light plate's print (S): a slip glued over the
-- print's foot, over the mat and the neat line and under the lifted
-- corner's shade and the photo corners, its parts from the slip up: its
-- shadow and edge, its stock, the printed words, the scribble, the icon,
-- the tag (its shadows, edge, stock, words, the underline) and the tag's
-- tape. Each part a pool of its own, on the frame over the picture (the
-- plate's over-kit: its pools are begun, finished and counted with the
-- plate's).
local PRINT_LAYERS = { shadow = { "ARTWORK", 4 }, edge = { "ARTWORK", 4 }, paper = { "ARTWORK", 5 },
    ink = { "ARTWORK", 7 }, iconShadow = { "OVERLAY", -8 }, iconEdge = { "OVERLAY", -7 }, icon = { "OVERLAY", -6 },
    tagShadow = { "OVERLAY", -4 }, tagEdge = { "OVERLAY", -3 }, tagPaper = { "OVERLAY", -2 },
    underline = { "OVERLAY", 0 }, tape = { "OVERLAY", 1 } }
local PRINT_TEXTS = { struck = { "ARTWORK", 6 }, count = { "OVERLAY", -5 }, tagText = { "OVERLAY", -1 } }

-- Each plate's toolkit for S (made by the pass's `new`), by plate.
local kits = setmetatable({}, { __mode = "k" })

-- The pass, after every card is chosen (the killer's 10, the close call's
-- 20, the witness's 30), where the plate drew S itself until 15 Oct
-- (after its passes): on a light plate's slot (a snapshot or the tucked
-- print), which has no margin, the plate's lucky hunt (plate.lucky, the
-- star's `chosen`) on a slip across the print's foot, drawn through the
-- card's toolkit so it turns and lies with the print. plate.print says
-- where it went (for the page: the caption's words, a leader to the star
-- where the star is not beside it) or is nil where it did not fit, and
-- the caption keeps the hunt's words. The mouse over it (plate.printHit,
-- plate.printItem): the star's tooltip over the slip and its tag, the
-- item's own over its icon (the lucky card's, HuntCard.ShowTip). Square
-- buttons round each as drawn (they cannot turn), on the frame over the
-- picture, so they do not lean in; a press on them is a press on the
-- plate.
ns.UI.JourneyPlate.RegisterPass("print", {
    order = 90,
    new = function(plate, kit)
        local pools, texts = {}, {}
        for part, at in pairs(PRINT_LAYERS) do pools[part] = kit.Pool(at[1], at[2]) end
        for part, at in pairs(PRINT_TEXTS) do texts[part] = kit.TextPool(Style.FONT.small, at[1], at[2]) end
        plate.printHit, plate.printItem = kit.Button(), kit.Button()
        Style.Tooltip(plate.printHit, function()
            local s = plate.print
            return s and kit.Tip(Hunts.Tip(s.hunt, s.now))
        end)
        plate.printItem:SetScript("OnEnter", function(self)
            if plate.print then Hunts.HuntCard.ShowTip(self, plate.print) end
        end)
        plate.printItem:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- S is the hunt's card, so a right click opens its form as a card's does,
        -- not the menu for the empty map under it. (The left stays a press on
        -- the plate, as the kit's buttons have it.)
        local function Up(_, which)
            plate:Release(which)
            if which == "RightButton" then
                local s = plate.print
                plate:Right(s and { kind = "fortune", list = { { hunt = s.hunt } } } or nil)
            end
        end
        plate.printHit:SetScript("OnMouseUp", Up)
        plate.printItem:SetScript("OnMouseUp", Up)
        kits[plate] = { over = kit.over, PlaceButton = kit.PlaceButton,
            print = { Place = kit.Place, Quad = kit.Quad,
                Texture = function(part) return pools[part]:Next() end,
                Text = function(part) return texts[part]:Next() end } }
    end,
    draw = function(plate, c)
        local k = kits[plate]
        if not k then return end
        plate.print = nil
        plate.printHit:Hide()
        plate.printItem:Hide()
        -- The player's, where there is one: S is its card, and a detected
        -- one on the same print goes to the words as any other lucky hunt.
        local chosen, slot = LuckyCard.Customs(plate.fortuneMarks)[1] or plate.lucky, plate.slot
        if not (chosen and slot and slot.light) then return end
        local entry, now, OnPage, PlaceButton = c.entry, c.now, c.OnPage, k.PlaceButton
        local hunt = chosen.hunt
        local seed = table.concat({ "lucky", hunt.questID or hunt.item or "", plate.mapID or 0,
            entry and (entry.level or entry.week) or 0 }, ":") .. ":print"
        local s = LuckyCard.Print(k.print, chosen, slot, seed, plate.flat)
        if not s then return end
        local hit, item = s.hit, s.iconHit
        PlaceButton(plate.printHit, hit.x, hit.y, hit.w, hit.h)
        plate.printHit:SetFrameLevel(k.over:GetFrameLevel() + 1)
        plate.printHit:Show()
        PlaceButton(plate.printItem, item.x, item.y, item.w, item.h)
        plate.printItem:SetFrameLevel(k.over:GetFrameLevel() + 2)
        plate.printItem:Show()
        -- On the page: its corners, its top edge, and a leader's way from
        -- that edge to the star, where the star is far enough off to need
        -- one (PRINT.near).
        local function Page(list)
            local out = {}
            for i, p in ipairs(list) do out[i] = { OnPage(p[1], p[2]) } end
            return out
        end
        local edge = Page(s.edge)
        local mark, far = chosen.mark, false
        if s.star then
            local ex = math.max(s.edge[1][1], math.min(s.edge[2][1], s.star[1]))
            local d = math.sqrt((s.star[1] - ex) ^ 2 + (s.star[2] - s.top) ^ 2)
            far = d >= PRINT.near
        end
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        local polys = { label = Page(s.label), tag = Page(s.tag), icon = Page(s.icon) }
        for _, poly in pairs(polys) do
            for _, p in ipairs(poly) do
                x0, y0, x1, y1 = math.min(x0, p[1]), math.min(y0, p[2]), math.max(x1, p[1]), math.max(y1, p[2])
            end
        end
        plate.print = { hunt = hunt, now = now, itemID = s.itemID, form = s.form, s = s, mark = mark, far = far,
            polys = polys, box = { x0, y0, x1 - x0, y1 - y0 }, plate = plate }
        -- A leader's way off it (UI/Journey/Leaders.lua's Aim): the point of
        -- its top edge nearest the mark, on the page.
        function plate.print:Nearest(x, y)
            local ax, ay, bx, by = edge[1][1], edge[1][2], edge[2][1], edge[2][2]
            local dx, dy = bx - ax, by - ay
            local t = ((x - ax) * dx + (y - ay) * dy) / math.max(dx * dx + dy * dy, 1e-6)
            t = math.max(0, math.min(1, t))
            return ax + dx * t, ay + dy * t
        end
        function plate.print:IsShown() return plate:IsShown() end
    end,
})
