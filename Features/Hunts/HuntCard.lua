-- The hunt card (Your Diary's plates, JRN-26): a quest's drops that took
-- bad luck, as option A of .claude/ui-proposal/hunt-card-proposal.md,
-- "Counted". A paper strip (UI/Paper/Strip.lua) taped in the plate's margin
-- with a pencil leader to its tally (Mark.lua's `luck`, TALLY),
-- and on it the same count written out at length: the mark on the map is
-- the shorthand, the card the long hand.
--
--   the heading  the item, as many as the quest wanted, in the diary's
--                hand ("Intact Raptor Horns", Hunts.Item)
--   the icon     the item's own picture pasted in, as the first found card
--                pastes it (its frame trimmed, a 1 px edge in its quality's
--                colour, ink for a white or grey item, a hair of shadow),
--                with the game's own stack count over its corner, white
--                and outlined as a bag slot shows it: the items wanted
--   the count    beside it, the kills as tally strokes in ink, in gates of
--                five, the plate's own TALLY at its own size
--   the lines    under them, who was killed (Hunts.KillLines): "killed 17
--                Sunscale Scytheclaws", one a kind
--
-- It is told two ways, by what is known (hunt.expected, not whether
-- Questie runs: a Questie user's Forever item with no rate is told the
-- second way). Printed type is what the drop tables said, the hand what
-- happened, graphite what the diary worked out about you:
--   - with the drop rates (EXT-2), "counted past the line": every kill a
--     stroke, a graphite stop rule standing across the tally where the
--     rates said it would end, "expected 12" printed (Friz, faded) under
--     it, so the strokes past it are the "14 more than expected" of the
--     words; at the end the total in the hand, "26 killed";
--   - without, "against yourself": two short rows, this hunt's kills an
--     item in ink ("each") and the character's usual (Hunts.UsualLuck)
--     in graphite ("usually"), from one edge, so the difference is one of
--     length; before five hunts are counted there is no usual, and the ink
--     row stands alone. The line under says the whole: "killed 37 Defias
--     Rogue Wizards for 6".
--
-- Which and where (its margin note, at the foot of this file): one card a
-- plate, for the hunt furthest past its yardstick (HuntCard.Past); in the
-- margin after the close call's card and before the people only seen, the
-- first card left off; its words leave the caption while it shows
-- (Text.PlateCaption's `said.luck`). Short of room it gives up, a step at
-- a time (card:Smaller),
-- the lines one a kind for one line ("Sunscale Scytheclaws and others"),
-- then the lines; then it is left off.
--
-- The icon comes from the hunt's itemID (kept since 12 Oct), else the
-- item's name (the client's cache), else QuestieDB's quest objectives,
-- else a plain sack (SACK): the count still says how many. Under the mouse
-- the icon shows the item's own tooltip, the rest of the card the tally's.
--
-- Laid flat ("Flat paper only") the slip lies square, the icon has no
-- shadow; the strokes are ink and stay as they are. Where text cannot
-- turn, the slip lies straight.

local addonName, ns = ...

local Style = ns.Style

local Hunts = ns.Hunts
local HuntCard = {}
Hunts.HuntCard = HuntCard

-- The slip: turned at most `turn` degrees; the heading at the hand's own
-- size, else `small`, else on two lines; `gap` under the heading.
-- `under`: between the icon's row and the lines; the lines `lineH` high,
-- each wrapped to the column (the steps down make room where it is short).
local HUNT = { turn = 1.2, small = 14, gap = 4, under = 3, lineH = 13 }
-- The icon: `size` px, `narrow` where the column is under `below` px,
-- `gap` before the count, its frame trimmed `crop` a side, edged `edge` px,
-- its shadow { dx, dy, alpha }.
local ICON = { size = 22, narrow = 18, below = 140, gap = 5, crop = 0.07, edge = 1, shadow = { 1, 1, 0.30 } }
-- The stack count: the game's own number font (Arial Narrow, outlined),
-- white, `size` (`narrow` on the smaller icon), `inset` px in from the
-- icon's bottom right.
local COUNT = { file = "Fonts\\ARIALN.TTF", size = 11, narrow = 10, inset = { 1, 0 }, colour = { 1, 1, 1 } }
-- The strokes, the plate's TALLY (Mark.lua): uprights `gap`
-- apart, `h` tall, leaning `lean`, `jitter` each; the fifth across from
-- the lower left, `over` past the outer two, rising `rise`; `width` px.
-- Gates `apart` px apart, rows `row` px; at most `most` strokes drawn: past
-- it the expected part is the rule alone, and past that the strokes end in
-- an ellipsis before the figure (the figure is always the count).
local TALLY = { gap = 2.5, h = 10, lean = 0.5, jitter = { 0, 0.6, -0.4, 0.3 }, over = 1.6, rise = 7.2, width = 1.3,
    apart = 3.5, row = 17, most = 50 }
-- The stop rule: graphite, `width` px, `reach` px above and below the
-- strokes' middle, `around` px clear of the strokes either side; its
-- label `label` px tall under it, `drop` px below the row's middle.
local RULE = { width = 1.1, reach = 8.5, around = 4.5, label = 13, drop = 15 }
-- The figure: the count in the hand at `size`, `gap` px after the strokes,
-- the word after it a `space` on at `word`.
local FIGURE = { size = 18, word = 14, gap = 5, space = 3 }
-- Without the rates: the rows' words `gap` px past the longer row, in the
-- hand at `word`; past `most` strokes a row is its figure in the hand.
local ROWS = { gap = 7, word = 14, most = 20 }
-- The stand-in where the item cannot be found, and the client's own
-- "not known" icon, which is no icon here.
local SACK = "Interface\\Icons\\INV_Misc_Bag_08"
local UNKNOWN = { [134400] = true, ["Interface\\Icons\\INV_Misc_QuestionMark"] = true }
-- The gold of the tooltip's lines under the item's own.
local TIP = { colour = { 1, 0.82, 0 } }

local HAND = Style.NEUTON_ITALIC

local countFont = CreateFont("SocialDiaryFontHuntCount")
countFont:SetFont(COUNT.file, COUNT.size, "OUTLINE")
countFont:SetTextColor(COUNT.colour[1], COUNT.colour[2], COUNT.colour[3], 1)

--------------------------------------------------------------------------
-- Which hunt, and its item
--------------------------------------------------------------------------

-- `fn`(...) if it is a function, guarded: its values, or nil.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

local function Plain(value)
    if ns.Plain then return ns.Plain(value) end
    return value
end

-- How far past its yardstick a hunt was: the kills over those expected
-- with the drop rates; without, its kills an item over the character's
-- usual (`usual`, Hunts.UsualLuck; an item counts the group's copies,
-- Hunts.Items), or over the least kills an item
-- that is ever bad luck (Hunts.T.luckRatio) before the usual is known.
function HuntCard.Past(hunt, usual)
    local kills = hunt.kills or 0
    if type(hunt.expected) == "number" and hunt.expected > 0 then return kills / hunt.expected end
    local per = kills / math.max(Hunts.Items(hunt), 1)
    if type(usual) == "number" and usual > 0 then return per / usual end
    return per / Hunts.T.luckRatio
end

-- The plate's one hunt card, from its tallies (plate.huntMarks: { list of
-- moments, at = { x, y } on the page }): the hunt furthest past its
-- yardstick, the latest of equals. { hunt, mark, usual } or nil.
function HuntCard.Choose(marks, usual)
    local best, bestMark, bestPast
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local hunt = m.hunt
            -- One the player changed or wrote has a card of its own (Customs).
            if hunt and not hunt.customOf then
                local past = HuntCard.Past(hunt, usual)
                if not best or past > bestPast or (past == bestPast and (hunt.t or 0) > (best.t or 0)) then
                    best, bestMark, bestPast = hunt, mark, past
                end
            end
        end
    end
    if not best then return nil end
    return { hunt = best, mark = bestMark.at, usual = usual or nil }
end

-- The slow hunts on a plate the player changed or wrote (Core/Custom.lua),
-- each with its item named, a card each and the newest first, so that where
-- the margin runs out the oldest are the ones left to their marks. One with no
-- item has nothing to head a card with: the mark and the words tell it, as a
-- close call's cross does with no creature.
function HuntCard.Customs(marks)
    local list, usual = {}, nil
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local hunt = m.hunt
            if hunt and hunt.customOf and type(hunt.item) == "string" and hunt.item ~= "" then
                usual = usual or Hunts.UsualLuck(ns.Journey.For(ns.ownGUID)) or false
                list[#list + 1] = { hunt = hunt, mark = mark.at, usual = usual or nil }
            end
        end
    end
    table.sort(list, function(a, b) return (a.hunt.t or 0) > (b.hunt.t or 0) end)
    return list
end

-- The item's ID: the hunt's own, else its name in the client's cache,
-- else the quest's objectives in QuestieDB. And where it came from:
-- "record", "name", "questie"; nil where none says.
function HuntCard.ItemID(hunt)
    if type(hunt.itemID) == "number" then return hunt.itemID, "record" end
    if C_Item and type(hunt.item) == "string" then
        local id = Plain(Call(C_Item.GetItemInfoInstant, hunt.item))
        if type(id) == "number" then return id, "name" end
    end
    local Bridge = ns.QuestieBridge
    if Bridge and hunt.questID then
        local id = Plain(Call(Bridge.ItemFor, hunt.questID, hunt.item))
        if type(id) == "number" then return id, "questie" end
    end
    return nil
end

-- The item's icon, its ID and where the icon came from ("record", "name",
-- "questie", or "sack" for the stand-in).
function HuntCard.Icon(hunt)
    local id, from = HuntCard.ItemID(hunt)
    local icon
    if id and C_Item then
        icon = Plain(Call(C_Item.GetItemIconByID, id))
        if icon == nil or UNKNOWN[icon] then icon = Plain(select(5, Call(C_Item.GetItemInfoInstant, id))) end
    end
    if id and (icon == nil or UNKNOWN[icon]) then icon = Plain(Call(_G.GetItemIcon, id)) end
    if icon == nil or icon == 0 or icon == "" or UNKNOWN[icon] then return SACK, id, "sack" end
    return icon, id, from
end

-- The edge round the icon: the game's colour for green and up, else ink.
function HuntCard.Edge(id)
    local q = id and C_Item and Plain(Call(C_Item.GetItemQualityByID, id))
    if type(q) == "number" and q >= 2 then return Style.QualityGameColour(q) or Style.INK end
    return Style.INK
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- Text measured unbounded (UI/Paper/Surface.lua's).
local Width = ns.UI.Surface.Width

-- A gate of `k` strokes (1 to 5) is this wide.
local function GateW(k)
    if k >= 5 then return 2 * TALLY.over + 3 * TALLY.gap end
    return TALLY.over + (k - 1) * TALLY.gap + TALLY.width
end

-- `n` strokes in gates of five, as atoms to lay.
local function Gates(n, colour, list)
    list = list or {}
    while n > 0 do
        local k = math.min(5, n)
        list[#list + 1] = { kind = "gate", k = k, colour = colour, w = GateW(k) }
        n = n - k
    end
    return list
end

-- The length of `n` strokes in a row.
local function RowW(n)
    local w = 0
    for i, g in ipairs(Gates(n)) do w = w + (i > 1 and TALLY.apart or 0) + g.w end
    return w
end

-- A card on `parent` (the right page): card:SetHunt(chosen, seed, now)
-- with HuntCard.Choose's choice, then card:Layout(x, y, width) as a
-- strip's; card.overfull where it will not fit `width` (the page leaves it
-- off); card:Smaller() gives up a step. Laid through the strip's hooks
-- (UI/Paper/Strip.lua), `hooks`, filled in below, after its drawing.
function HuntCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    -- The strip's margins round the writing (l, t, r, b).
    local pad = { card:Pad() }

    local function Texture(layer, sublevel)
        local texture = card:CreateTexture(nil, layer, nil, sublevel)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        return texture
    end
    card.iconShadow = Texture("ARTWORK", 4)
    card.iconEdge = Texture("ARTWORK", 5)
    card.icon = Texture("ARTWORK", 6)
    card.count = card:CreateFontString(nil, "OVERLAY")
    card.count:SetFontObject(countFont)
    card.strokes = {}
    card.rule = Texture("ARTWORK", 3)
    card.label = Style.Text(card, Style.FONT.small)
    card.figure = Style.Text(card, Style.FONT.noteWritten)
    card.figureWord = Style.Text(card, Style.FONT.noteWritten)
    card.ellipsis = Style.Text(card, Style.FONT.noteWritten)
    card.rowWords = { Style.Text(card, Style.FONT.noteWritten), Style.Text(card, Style.FONT.noteWritten) }
    card.rowFigures = { Style.Text(card, Style.FONT.noteWritten), Style.Text(card, Style.FONT.noteWritten) }
    card.kills = {}
    card.headTail = Style.Text(card, Style.FONT.noteWritten)
    -- A hidden measure in small print (the card's own, not a field:
    -- `measure` is the strip's name).
    local measure = Style.Text(card, Style.FONT.small)
    measure:Hide()

    -- The icon takes the mouse for the item's own tooltip, a level over
    -- the slip's.
    card.item = CreateFrame("Button", nil, card)
    card.item:SetScript("OnEnter", function(self) HuntCard.ShowTip(self, card) end)
    card.item:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function Hand(text, size)
        text:SetFontObject(Style.FONT.noteWritten)
        if size and size > 0 then text:SetFont(HAND, size, "") end
    end

    function card:SetHunt(chosen, seed, now)
        local hunt = chosen.hunt
        self.chosen, self.hunt, self.now, self.usual = chosen, hunt, now, chosen.usual
        self.rates = hunt.expected ~= nil
        self.iconFile, self.itemID, self.iconFrom = HuntCard.Icon(hunt)
        self.step = 0
        -- The heading's words as set on the note: its own copy, for Heading.
        self.nameWords = Hunts.Item(hunt)
        self:SetNote({ name = self.nameWords, strong = true, seed = seed, turn = HUNT.turn,
            tip = function()
                local title, lines = Hunts.CardTip(hunt, now, self.usual)
                return Style.TipList(title, lines)
            end })
    end

    -- A step less, where the margin is short (UI/Journey/Margin.lua's
    -- LayNotes): the lines one a kind become one line, then go. Whether
    -- there was a step to give up.
    function hooks.smaller(self)
        if (self.step or 0) >= 2 then return false end
        self.step = (self.step or 0) + 1
        return true
    end

    -- The heading at the first size that fits `room` on one line, else on
    -- two (the second, card.headTail, in the room under it). Whether it
    -- fits, and the second line's words if any.
    local function Heading(room)
        local words = card.nameWords or ""
        for _, size in ipairs({ 0, HUNT.small }) do
            Hand(card.name, size)
            card.name:SetText(words)
            if Width(card.name) <= room then return true, nil end
        end
        for _, size in ipairs({ 0, HUNT.small }) do
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
            if rest and Width(card.name) <= room and Width(card.headTail) <= room then return true, rest end
        end
        card.name:SetText(words)
        return false, nil
    end

    -- `text` in lines no wider than `room` (FONT.small).
    local function Wrap(text, room)
        local probe, lines, line = measure, {}, ""
        for word in text:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            probe:SetText(try)
            if line ~= "" and Width(probe) > room then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        return lines
    end

    -- The figure "26 killed" measured: its width and the word's.
    local function Figure()
        Hand(card.figure, FIGURE.size)
        card.figure:SetText(tostring(card.hunt.kills or 0))
        Hand(card.figureWord, FIGURE.word)
        card.figureWord:SetText(Hunts.KILLED)
        local a, b = Width(card.figure) + 1, Width(card.figureWord) + 1
        return a + FIGURE.space + b, a
    end

    -- With the rates: the strokes, the stop rule and its label, the figure,
    -- flowed into rows no wider than `room`. Returns { w, h, ops }: the
    -- ops in the block's own room, from its top left (y down).
    local function Counted(room)
        local hunt = card.hunt
        local kills = math.max(hunt.kills or 0, 0)
        local a = math.max(0, math.min(kills, math.floor((hunt.expected or 0) + 0.5)))
        local b = kills - a
        local cut = false
        if kills > TALLY.most then a = 0 end
        if b > TALLY.most then b, cut = TALLY.most, true end
        local atoms = Gates(a, Style.INK_STRONG)
        atoms[#atoms + 1] = { kind = "rule", w = RULE.width }
        Gates(b, Style.INK_STRONG, atoms)
        if cut then
            Hand(card.ellipsis, FIGURE.word)
            card.ellipsis:SetText("\226\128\166")
            atoms[#atoms + 1] = { kind = "ellipsis", w = Width(card.ellipsis) + 1 }
        end
        local figW = Figure()
        atoms[#atoms + 1] = { kind = "figure", w = figW }
        -- Into rows: each atom after the one before, `apart` (round the
        -- rule, `around`; before the figure, its gap), a new row where it
        -- would pass the room.
        local rows, x, prev = { {} }, 0, nil
        for _, at in ipairs(atoms) do
            local before = 0
            if x > 0 then
                before = (at.kind == "rule" or (prev and prev.kind == "rule")) and RULE.around
                    or (at.kind == "figure" and FIGURE.gap) or TALLY.apart
            end
            if x > 0 and x + before + at.w > room then
                rows[#rows + 1] = {}
                x, before = 0, 0
            end
            at.x = x + before
            local row = rows[#rows]
            row[#row + 1] = at
            x = at.x + at.w
            prev = at
        end
        local ops, y, w = {}, 0, 0
        for _, row in ipairs(rows) do
            local mid, ruled = y + TALLY.row / 2, false
            for _, at in ipairs(row) do
                w = math.max(w, at.x + at.w)
                if at.kind == "gate" then
                    ops[#ops + 1] = { kind = "gate", x = at.x, y = mid, k = at.k, colour = at.colour }
                elseif at.kind == "rule" then
                    ruled = true
                    ops[#ops + 1] = { kind = "rule", x = at.x + RULE.width / 2, y = mid }
                    card.label:SetText(Hunts.ExpectedLabel(hunt))
                    local lw = Width(card.label) + 1
                    -- Hung under the rule, as a ruler's figure is, kept in
                    -- the room.
                    local lx = math.max(0, math.min(at.x - lw / 2, room - lw))
                    ops[#ops + 1] = { kind = "label", x = lx, y = mid + RULE.drop, w = lw }
                    w = math.max(w, lx + lw)
                elseif at.kind == "ellipsis" then
                    ops[#ops + 1] = { kind = "ellipsis", x = at.x, y = mid, w = at.w }
                else
                    ops[#ops + 1] = { kind = "figure", x = at.x, y = mid, w = at.w }
                end
            end
            y = y + TALLY.row + (ruled and (RULE.drop + RULE.label / 2 - TALLY.row / 2) or 0)
        end
        return { w = w, h = y, ops = ops, rows = #rows }
    end

    -- Without the rates: this hunt's strokes an item and, once known, the
    -- usual's in graphite, their words lined up past the longer.
    local function Rows()
        local hunt = card.hunt
        -- An item the group's kills gave, the group's copies too.
        local per = math.max(1, math.floor((hunt.kills or 0) / math.max(Hunts.Items(hunt), 1) + 0.5))
        local usual = card.usual and math.max(1, math.floor(card.usual + 0.5)) or nil
        local rows = { { n = per, colour = Style.INK_STRONG, word = Hunts.EACH } }
        if usual then rows[2] = { n = usual, colour = Style.GRAPHITE, word = Hunts.USUALLY } end
        local longest = 0
        for i, row in ipairs(rows) do
            if row.n > ROWS.most then
                local fig = card.rowFigures[i]
                Hand(fig, ROWS.word)
                fig:SetText(tostring(row.n))
                row.figure = Width(fig) + 1
                longest = math.max(longest, row.figure)
            else
                longest = math.max(longest, RowW(row.n))
            end
        end
        local ops, w = {}, 0
        local at = longest + ROWS.gap
        for i, row in ipairs(rows) do
            local mid = (i - 0.5) * TALLY.row
            if row.figure then
                ops[#ops + 1] = { kind = "rowFigure", i = i, x = 0, y = mid, w = row.figure, colour = row.colour }
            else
                local x = 0
                for k, g in ipairs(Gates(row.n, row.colour)) do
                    if k > 1 then x = x + TALLY.apart end
                    ops[#ops + 1] = { kind = "gate", x = x, y = mid, k = g.k, colour = row.colour }
                    x = x + g.w
                end
            end
            local word = card.rowWords[i]
            Hand(word, ROWS.word)
            word:SetText(row.word)
            local ww = Width(word) + 1
            ops[#ops + 1] = { kind = "rowWord", i = i, x = at, y = mid, w = ww, colour = row.colour }
            w = math.max(w, at + ww)
        end
        return { w = w, h = #rows * TALLY.row, ops = ops, rows = 1 }
    end

    -- A stroke from one point of the strip to another (from its middle, y
    -- down): a texture as long as the gap, turned to it (screen y up, so
    -- the strip's y negated), a hair longer, so strokes meet.
    local used = 0
    local function Stroke(x1, y1, x2, y2, width, colour)
        used = used + 1
        local t = card.strokes[used]
        if not t then
            t = Texture("ARTWORK", 3)
            card.strokes[used] = t
        end
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy) + 0.6
        t:SetColorTexture(colour[1], colour[2], colour[3], 1)
        card:Lay(t, (x1 + x2) / 2, (y1 + y2) / 2, length, width, math.atan2(-dy, dx))
        t:Show()
    end
    -- A gate of `k` at x (its left), y (its middle).
    local function Gate(x, y, k, colour)
        local T = TALLY
        for i = 1, math.min(k, 4) do
            local u, h = x + T.over + (i - 1) * T.gap, T.h + (T.jitter[i] or 0)
            Stroke(u - T.lean / 2, y + h / 2, u + T.lean / 2, y - h / 2, T.width, colour)
        end
        if k >= 5 then Stroke(x, y + T.rise / 2, x + GateW(5), y - T.rise / 2, T.width, colour) end
    end
    -- `text` laid with its left at x, its middle at y.
    local function Put(text, x, y, w, h)
        card:Lay(text, x + w / 2, y, w, h)
        text:Show()
    end

    -- Everything under the heading, in the room the strip kept for it.
    local function Draw()
        used = 0
        local plan, room = card.plan, card.under
        local parts = { card.iconShadow, card.iconEdge, card.icon, card.count, card.rule, card.label, card.figure,
            card.figureWord, card.ellipsis, card.headTail, card.item }
        for _, part in ipairs(parts) do part:Hide() end
        for _, part in ipairs(card.rowWords) do part:Hide() end
        for _, part in ipairs(card.rowFigures) do part:Hide() end
        for _, line in ipairs(card.kills) do line:Hide() end
        if not (plan and room) then
            for _, s in ipairs(card.strokes) do s:Hide() end
            return
        end
        local left, top = room.lx - room.w / 2, room.ly - room.h / 2
        local INK = Style.INK
        -- The heading's second line, square with the slip.
        if plan.tail then
            local tw = Width(card.headTail) + 2
            Put(card.headTail, left, top + plan.tailH / 2, tw, plan.tailH)
            top = top + plan.tailH + HUNT.gap
        end
        -- The icon, pasted in, its count over its corner.
        local size, flat = plan.icon, card.flat
        local ix, iy = left + size / 2, top + size / 2 + ICON.edge
        local S, E = ICON.shadow, HuntCard.Edge(card.iconFrom ~= "sack" and card.itemID or nil)
        card.iconShadow:SetColorTexture(INK[1], INK[2], INK[3], S[3])
        card:Lay(card.iconShadow, ix + S[1], iy + S[2], size + 2 * ICON.edge, size + 2 * ICON.edge)
        card.iconShadow:SetShown(not flat)
        card.iconEdge:SetColorTexture(E[1], E[2], E[3], 1)
        card:Lay(card.iconEdge, ix, iy, size + 2 * ICON.edge, size + 2 * ICON.edge)
        card.iconEdge:Show()
        card.icon:SetTexture(card.iconFile)
        local k = ICON.crop
        card.icon:SetTexCoord(k, 1 - k, k, 1 - k)
        card:Lay(card.icon, ix, iy, size, size)
        card.icon:Show()
        if (card.hunt.need or 0) > 1 then
            card.count:SetFont(COUNT.file, size < ICON.size and COUNT.narrow or COUNT.size, "OUTLINE")
            card.count:SetText(tostring(card.hunt.need))
            local cw, ch = Width(card.count) + 2, size < ICON.size and COUNT.narrow + 2 or COUNT.size + 2
            Put(card.count, ix + size / 2 - COUNT.inset[1] - cw, iy + size / 2 - COUNT.inset[2] - ch / 2, cw, ch)
        end
        -- The count beside it, its first row's middle level with the icon's.
        local bx, by = left + size + ICON.gap, top + plan.blockTop
        for _, op in ipairs(plan.block.ops) do
            local x, y = bx + op.x, by + op.y
            if op.kind == "gate" then
                Gate(x, y, op.k, op.colour)
            elseif op.kind == "rule" then
                local G = Style.GRAPHITE
                card.rule:SetColorTexture(G[1], G[2], G[3], 1)
                card:Lay(card.rule, x, y, RULE.width, 2 * RULE.reach)
                card.rule:Show()
            elseif op.kind == "label" then
                Put(card.label, x, y, op.w, RULE.label)
            elseif op.kind == "ellipsis" then
                Put(card.ellipsis, x, y, op.w, FIGURE.word + 2)
            elseif op.kind == "figure" then
                local fw = Width(card.figure) + 1
                Put(card.figure, x, y, fw, FIGURE.size + 2)
                Put(card.figureWord, x + fw + FIGURE.space, y + 1.5, Width(card.figureWord) + 1, FIGURE.word + 2)
            elseif op.kind == "rowFigure" or op.kind == "rowWord" then
                local text = op.kind == "rowFigure" and card.rowFigures[op.i] or card.rowWords[op.i]
                text:SetTextColor(op.colour[1], op.colour[2], op.colour[3])
                Put(text, x, y, op.w, ROWS.word + 2)
            end
        end
        for i = used + 1, #card.strokes do card.strokes[i]:Hide() end
        -- Who was killed, under them.
        local ly = top + plan.rowH + (#plan.lines > 0 and HUNT.under or 0)
        for i, words in ipairs(plan.lines) do
            local line = card.kills[i]
            if not line then
                line = Style.Text(card, Style.FONT.small)
                card.kills[i] = line
            end
            line:SetText(words)
            line:SetTextColor(INK[1], INK[2], INK[3])
            line:SetSize(0, 0)
            Put(line, left, ly + (i - 0.5) * HUNT.lineH, Width(line) + 2, HUNT.lineH)
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
        card.item:Show()
    end

    -- Laid as a strip, with its room under the heading, measured for the
    -- column `width`: the heading at the size that fits, the icon and the
    -- count beside it, the lines the step allows.
    function hooks.plan(self, note, width)
        local room = width - pad[1] - pad[3]
        local fits, tail = Heading(room)
        local size = width < ICON.below and ICON.narrow or ICON.size
        -- The count's room: the column's, less the icon, and a little for
        -- the slip's turn.
        local blockRoom = room - size - ICON.gap - 3
        local block = self.rates and Counted(blockRoom) or Rows()
        local step = self.step or 0
        local words = step < 2 and Hunts.KillLines(self.hunt, step >= 1) or {}
        local lines = {}
        for _, text in ipairs(words) do
            for _, line in ipairs(Wrap(text, room)) do lines[#lines + 1] = line end
        end
        local linesW = 0
        for _, line in ipairs(lines) do
            measure:SetText(line)
            linesW = math.max(linesW, Width(measure) + 2)
        end
        local blockTop = (size + 2 * ICON.edge - TALLY.row) / 2
        local rowH = math.max(size + 2 * ICON.edge, blockTop + block.h)
        local tailH = tail and math.max(math.ceil(self.headTail:GetStringHeight() or 0), 14) or 0
        local tailW = tail and Width(self.headTail) + 2 or 0
        local h = (tail and tailH + HUNT.gap or 0) + rowH + (#lines > 0 and (HUNT.under + #lines * HUNT.lineH) or 0)
        local w = math.max(size + ICON.gap + block.w, linesW, tailW)
        self.plan = { icon = size, block = block, blockTop = blockTop, lines = lines, words = words, rowH = rowH,
            tail = tail, tailH = tailH }
        note.under = { w = math.ceil(w), h = math.ceil(h), gap = tail and 0 or HUNT.gap, after = 0 }
        note.what = nil
        self.overfull = not fits or block.w > blockRoom or w > room
    end
    function hooks.draw() Draw() end

    -- The width the card would like (px, the column's): the wide
    -- arrangement, the full icon with the whole count on one row beside it,
    -- strokes, rule and "26 killed" (12 Oct, the user: "if there is enough
    -- wide space, draw that"). The page gives a row's box this much where it
    -- has it (UI/Journey/Margin.lua's ROW).
    function card:Preferred()
        local block = self.rates and Counted(math.huge) or Rows()
        return math.ceil(pad[1] + pad[3] + ICON.size + ICON.gap + 3 + block.w + 1)
    end

    -- For the tests: the lines under the tally as said (Hunts.KillLines),
    -- before they were wrapped to the column.
    function card:Lines()
        local list = {}
        for _, line in ipairs(self.plan and self.plan.words or {}) do list[#list + 1] = line end
        return list
    end

    card:HookScript("OnHide", function() card.item:Hide() end)
    return card
end

-- The width a card for `chosen` (HuntCard.Choose's) would like
-- (card:Preferred), measured on a card of its own that is never shown.
local measurer
function HuntCard.Preferred(chosen)
    measurer = measurer or HuntCard.New(UIParent)
    measurer:SetHunt({ hunt = chosen.hunt, mark = { 0, 0 }, usual = chosen.usual }, "measure", 0)
    return measurer:Preferred()
end

-- The icon's tooltip on `owner`: the item's own (by its ID), and under
-- it, in flavour gold, the card's lines (Hunts.CardTip). The item's
-- name alone where there is no ID.
function HuntCard.ShowTip(owner, card)
    local hunt = card and card.hunt
    if not hunt then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local id = card.itemID
    local shown = false
    if id then
        if type(GameTooltip.SetItemByID) == "function" then
            shown = pcall(GameTooltip.SetItemByID, GameTooltip, id)
        elseif type(GameTooltip.SetHyperlink) == "function" then
            shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id)
        end
    end
    if not shown then GameTooltip:SetText(hunt.item or "?") end
    local C = TIP.colour
    local title, lines = Hunts.CardTip(hunt, card.now, card.usual)
    GameTooltip:AddLine(title, C[1], C[2], C[3], true)
    for _, line in ipairs(lines) do GameTooltip:AddLine(line, C[1], C[2], C[3], true) end
    GameTooltip:Show()
end

HuntCard.ICON, HuntCard.COUNT, HuntCard.TALLY = ICON, COUNT, TALLY
HuntCard.SACK = SACK

--------------------------------------------------------------------------
-- In the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- A quest's drops that took bad luck (JRN-26, this card): the
-- mildest of the cards, the first of them left off (the user's choice, 12
-- Oct). Its words are on the card, so the caption leaves them off while it
-- shows (`said.luck`).
ns.UI.JourneyMargin.Register("hunt", {
    order = 70, pool = "huntPool", count = "huntsWritten",
    new = function(parent) return HuntCard.New(parent) end,
    wants = function(it) return HuntCard.Preferred(it.hunt) end,
    item = function(plate)
        local h = plate.hunt
        return h and { hunt = h, top = h.mark[2], x = h.mark[1] } or nil
    end,
    write = function(card, it, c)
        local hunt = it.hunt.hunt
        card:SetHunt(it.hunt, c.Seed("hunt", hunt.questID or hunt.item or ""), c.now)
    end,
    mark = function(it) return it.hunt.mark end,
    custom = function(it) return "luck", it.hunt.hunt end,
    assume = function(said, plate)
        said.luck = plate.hunt and plate.hunt.hunt
    end,
    say = function(said, shown)
        said.luck = shown[1] and shown[1].hunt.hunt or nil
    end,
})

-- The slow hunts the player changed or wrote, each its own card, past the
-- plate's one (HuntCard.Choose): 7 in the margin, among the custom cards and
-- before the people's (10), so they are nearly the last left off, where the
-- detected hunt, the mildest card, is the first (.claude/features/
-- custom-cards.md). The same card, the same pool. Read off the kept marks when
-- asked, with no pass of their own: `chosen` is the plate's one, and a list
-- has nothing to be chosen.
ns.UI.JourneyMargin.Register("huntCustom", {
    order = 7, pool = "huntPool", count = "customHuntsWritten",
    new = function(parent) return HuntCard.New(parent) end,
    wants = function(it) return HuntCard.Preferred(it.hunt) end,
    items = function(plate)
        local items = {}
        for _, h in ipairs(HuntCard.Customs(plate.huntMarks)) do
            items[#items + 1] = { hunt = h, top = h.mark[2], x = h.mark[1] }
        end
        return items
    end,
    write = function(card, it, c)
        local hunt = it.hunt.hunt
        card:SetHunt(it.hunt, c.Seed("hunt", hunt.t or hunt.item), c.now)
    end,
    mark = function(it) return it.hunt.mark end,
    custom = function(it) return "luck", it.hunt.hunt end,
    assume = function(said, plate)
        local set = {}
        for _, h in ipairs(HuntCard.Customs(plate.huntMarks)) do set[h.hunt] = true end
        said.lucks = set
    end,
    say = function(said, shown)
        local set = {}
        for _, it in ipairs(shown) do set[it.hunt.hunt] = true end
        said.lucks = set
    end,
})
