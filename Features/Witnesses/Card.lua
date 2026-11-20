-- The witness card (Your Diary's plates): someone who was there when you
-- died or nearly did (Capture.lua), as
-- .claude/ui-proposal/witness-card-proposal.md. It takes the killer card's
-- place in the margin (or the close call's, for a rescue: the user's call,
-- 14 Oct, a person in the moment is the better story than the creature):
-- a paper strip (UI/Paper/Strip.lua) taped in the margin with a pencil
-- leader to the death cross or the close call's mark, and on it, down the
-- slip:
--
--   the name     the person, the card's subject, in the diary's hand
--                (their first name, Text.lua's Name), a way to their page
--                as a person's strip is; "Ilsabet & two others" on the one
--                line where more were there and it fits, else the name
--                alone (the tooltip still says who else was there). It never
--                takes a line of its own (14 Oct, the user, after level 14's
--                M card read on four lines)
--   the deed     what they did, in the hand, the timeline's own verbs
--                (Text.lua's Deed): "saw you die", "watched you die",
--                "mercilessly watched you die" (the hand underlines
--                "mercilessly" twice, DOUBLE, as one does when one cannot
--                believe it); "tried to save you", "saved you"
--   the foe      what it was against, in small print (Text.lua's Foe):
--                "to a Ragged Young Wolf", "from Hogger". Secondary: the
--                first thing given up where the margin is short, and then
--                the caption names the creature, as it does a killer whose
--                card is left off
--   the chart    a rescue's health left only, charted as the close call's
--                card charts it (ns.CloseCalls.Card's VITALS: an ink box
--                filled in rubric, a graphite tick at the tenth where a
--                close call begins), the figure large in rubric, "6%": how
--                near it was, which is what they saved you from
--
-- A watcher's card was laid on a page you bled on (BLOOD): dried blood,
-- splashed across the slip's corner and off its edge onto the page, a pool,
-- a run or two over the edge and droplets flung past it, built as the heat
-- map's ink blots are (UI/Ink/Blot.lua: drops that run together, a darker
-- rim where it dried), in the card's own turn. It may run under the ends of
-- the lines nearest its corner, never under the name or the rest of a line,
-- and under a word it is the wash alone, lighter (BLOOD.soft, .under): the
-- words keep their contrast. The longer they watched, the more of it (a
-- glance a small stain, mercilessly a palm's splash, runs and a spray): the
-- longer you lay there. How long is in the tooltip, never on the card
-- (14 Oct, the user: no seconds count; the strokes went with it).
--
-- The family's rule holds: the hand is what happened, small print what it
-- was against. The name is in ink like everyone else's on the plates (no
-- class colour: a coloured name would read as another kind of thing, and
-- the blues read as Alliance); the tooltip says who they are.
--
-- Its size is not picked by name: card:Layout(x, y, width) tries FORMS in
-- turn (ORDER) and keeps the first that fits the width: XL the deed in the
-- name's own hand on one line; L the deed a size down, on two lines at
-- most; M the name a size down too, the bar narrower. Short of height it
-- gives up its foe's line (card:Smaller; the caption names the creature);
-- then the page leaves it off and the caption tells the witness in a
-- sentence of its own (Text.PlateCaption's `witness`, Text.lua).
--
-- Laid flat ("Flat paper only") the slip lies square and so does its blood;
-- the underlines, the chart and the blood are ink and stay.
--
-- A witness the player wrote in (Kind.lua's Written) is this same card, given
-- the same shape of witness with no row behind it; it has a mark of its own and
-- a margin kind of its own at this file's foot.
--
-- The card is ns.Witnesses.Card. The rescue's chart is the close call's
-- (its card's VITALS, Features/CloseCalls/Card.lua, read at call time as
-- ns.CloseCalls.Card.VITALS, so this folder loads after Close calls'). At the
-- foot: the plate's one witness chosen (Choose), the pass that chooses it
-- over the plate (after Deaths' and the close call's) and the card's note
-- in the margin.

local addonName, ns = ...

local Style = ns.Style
local Witnesses = ns.Witnesses
local L = ns.L

local WitnessCard = {}
Witnesses.Card = WitnessCard

-- The slip: turned at most `turn` degrees (the other cards'). Under the
-- name, `deed` px to the deed (none: the two read as one sentence), the
-- deed's lines `line` px at the hand's 16 and 14; `foe` px to the foe's
-- small print, its lines `foeLine` px; `row` px to the chart.
local WITNESS = { turn = 1.2, deed = 0, line = { [16] = 19, [14] = 17 }, foe = 1, foeLine = 13, row = 4 }
-- The arrangements, tried in turn: the least width of the box it takes
-- (`least`: XL only where a row or a caption column is wide, 190 px and
-- more; L the 150 to 176 px columns; M the 122 px column and the 142 px
-- boxes of a row), the name's size in the hand, the deed's, the most lines
-- the deed and the foe may take, and the rescue's bar's width (the close
-- call's, ns.CloseCalls.Card.VITALS: 70, or 56 in a narrow column).
local FORMS = {
    XL = { least = 190, name = 16, deed = 16, deedLines = 1, foeLines = 1, bar = 70 },
    L = { least = 150, name = 16, deed = 14, deedLines = 2, foeLines = 2, bar = 70 },
    M = { least = 0, name = 14, deed = 14, deedLines = 3, foeLines = 2, bar = 56 },
}
local ORDER = { "XL", "L", "M" }
-- "Mercilessly" underlined twice by the hand: the lucky card's underline
-- (Features/Hunts/LuckyCard.lua's UNDER, the route's pen), and a second `second` px
-- under the first, `inset` px shorter at its start and its end, as a second
-- stroke is drawn quicker.
local DOUBLE = { second = 2.6, inset = { 2, 5 } }
-- The blood on a watcher's card: the shared look (UI/Ink/Blood.lua's BLOOD,
-- its comment the spec), its `amount` by how long they watched.
local Blood = ns.UI.Blood
local BLOOD = Blood.BLOOD

local HAND = Style.NEUTON_ITALIC

-- Text measured unbounded (UI/Paper/Surface.lua's).
local Width = ns.UI.Surface.Width

-- `text` in the diary's hand at `size` (its own, 16, without one).
local function Hand(text, size)
    text:SetFontObject(Style.FONT.noteWritten)
    if size and size ~= 16 then text:SetFont(HAND, size, "") end
end


-- What a witness's card has to show under its words: "chart" (a rescue's
-- health left), else nil.
function WitnessCard.Evidence(w)
    if w.type == Witnesses.SAVED and type(w.pct) == "number" then return "chart" end
    return nil
end

-- How much blood a witness's card has (BLOOD.amount), nil for a helper.
function WitnessCard.Blood(w)
    local look = Witnesses.Look(w)
    return look and BLOOD.amount[look] or nil
end

-- The blood's sums are the shared ones (UI/Ink/Blood.lua, ns.UI.Blood: a
-- fight's strip on the plates bleeds the same way), kept here by their
-- old names for this file's readers: Keep, Spill, Stain, Under.
WitnessCard.Keep, WitnessCard.Spill = Blood.Keep, Blood.Spill
WitnessCard.Stain, WitnessCard.Under = Blood.Stain, Blood.Under

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- A card on `parent` (the right page): card:SetWitness(w, seed, now, guid,
-- onClick) with the plate's witness (Choose, below; `guid`
-- where their page can be opened), then card:Layout(x, y, width) as a
-- strip's; card.overfull where no arrangement fits `width` (the page
-- leaves it off); card:Smaller() gives up a step. card.form says which
-- arrangement it took, card.plan.foe whether the foe's line is written,
-- card.blood what of the blood was spilt. Laid through the strip's hooks
-- (UI/Paper/Strip.lua), `hooks`, filled in below, after its drawing.
function WitnessCard.New(parent)
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
    card.deeds = {}
    card.foes = {}
    card.figure = Style.Text(card, Style.FONT.noteWritten)
    card.ink = {}
    card.stain = {}
    card.barEdge = Texture("ARTWORK", 1)
    card.barPaper = Texture("ARTWORK", 2)
    card.barFill = Texture("ARTWORK", 3)
    card.barTick = Texture("ARTWORK", 4)
    -- Hidden measures, in the hand and in small print. (The hand's is the
    -- card's own, not a field: `measure` is the strip's name.)
    local measure = Style.Text(card, Style.FONT.noteWritten)
    measure:Hide()
    card.small = Style.Text(card, Style.FONT.small)
    card.small:Hide()

    function card:SetWitness(w, seed, now, guid, onClick)
        self.witness, self.now, self.seedKey = w, now, seed
        self.step, self.plan, self.form = 0, nil, nil
        -- The name as set on the note: its own copy, for Try (Preferred
        -- measures a card that is never laid).
        self.nameWords = Witnesses.Name(w)
        self:SetNote({ name = self.nameWords, strong = true, seed = seed, turn = WITNESS.turn, guid = guid,
            onClick = onClick, tip = function()
                local title, lines = Witnesses.Tip(w, now)
                local list = Style.TipList(title, lines)
                -- A stranger's opens their page pencilled in, the glimpse (the
                -- stranger-glimpse proposal, 5 Nov 2026), and says so.
                if guid then
                    local click = ns.Diary.IsDiary(guid) and L["Click to open their page in the diary"]
                        or ns.UI.PersonText.GLIMPSE.click
                    list[#list + 1] = { click, 0.6, 0.6, 0.6, true }
                end
                return list
            end })
    end

    -- A step less, where the margin is short (UI/Journey/Margin.lua's
    -- LayNotes): the foe's line. Whether there was one to give up.
    function hooks.smaller(self)
        if (self.step or 0) >= 1 or not Witnesses.Foe(self.witness) then return false end
        self.step = 1
        return true
    end

    -- `text` in lines no wider than `room`, measured on `probe`; nil where
    -- it takes more than `most` or a word alone is too wide.
    local function Wrap(probe, text, room, most)
        local lines, line = {}, ""
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
        if #lines > most then return nil end
        for _, l in ipairs(lines) do
            probe:SetText(l)
            if Width(probe) > room then return nil end
        end
        return lines
    end

    -- The same, never one word alone on the last line where there are
    -- more ("mercilessly watched you / die"): wrapped again narrower,
    -- `step` px at a time down to `least` of the room, keeping as many
    -- lines (the strip's balance, PAPER_LOOK.balance).
    local function Balanced(probe, text, room, most)
        local lines = Wrap(probe, text, room, most)
        if not lines or #lines < 2 or lines[#lines]:find("%s") then return lines end
        local B = ns.UI.PAPER_LOOK.balance
        local w = room - B.step
        while w >= room * B.least do
            local try = Wrap(probe, text, w, most)
            if not try or #try ~= #lines then break end
            if try[#try]:find("%s") then return try end
            w = w - B.step
        end
        return lines
    end

    local function Widest(probe, lines)
        local w = 0
        for _, l in ipairs(lines) do
            probe:SetText(l)
            w = math.max(w, Width(probe) + 2)
        end
        return w
    end

    -- The chart's width and height, for a rescue.
    local function Row(form)
        local w = card.witness
        if WitnessCard.Evidence(w) ~= "chart" then return nil end
        local V = ns.CloseCalls.Card.VITALS
        Hand(measure, V.figure.size)
        measure:SetText((w.pct or 0) .. "%")
        local fw = Width(measure) + 2
        return { kind = "chart", bar = FORMS[form].bar, fw = fw, w = math.ceil(FORMS[form].bar + V.figure.gap + fw),
            h = math.max(V.figure.size, V.bar.h + 2) }
    end

    -- One arrangement (FORMS[form]) in `width` px: its plan, or nil where it
    -- does not fit (`force`: planned all the same, for the page to measure
    -- and leave off). Heights and widths of what goes under the name.
    local function Try(form, width, force)
        local F = FORMS[form]
        local room = width - pad[1] - pad[3]
        local w = card.witness
        local step = card.step or 0
        local fail = width < F.least
        -- The name, and who else was there on its line where that fits.
        local name = card.nameWords or ""
        Hand(card.name, F.name)
        local others = Witnesses.Others(w.others)
        local line = others and ns.Fmt(L["%1$s %2$s##name and others"], name, others) or name
        card.name:SetText(line)
        if others and Width(card.name) + 2 > room then
            line, others = name, nil
            card.name:SetText(line)
        end
        card.name:SetSize(0, 0)
        local nameW = Width(card.name) + 2
        local nameH = math.max(math.ceil(card.name:GetStringHeight() or 0), 14)
        if nameW > room then fail = true end
        -- The deed, in the hand.
        local deedText, under = Witnesses.Deed(w)
        Hand(measure, F.deed)
        local deed = Balanced(measure, deedText, room, F.deedLines)
        if not deed then
            fail = true
            deed = { deedText }
        end
        local deedW = Widest(measure, deed)
        -- The foe, in small print.
        local foeText = step < 1 and Witnesses.Foe(w) or nil
        local foe
        if foeText then
            foe = Balanced(card.small, foeText, room, F.foeLines)
            if not foe then
                fail = true
                foe = { foeText }
            end
        end
        local foeW = foe and Widest(card.small, foe) or 0
        -- A rescue's chart.
        local row = Row(form)
        if row and row.w > room then fail = true end
        if fail and not force then return nil end

        local lineH = WITNESS.line[F.deed] or WITNESS.line[14]
        local deedTop = WITNESS.deed
        local h = deedTop + #deed * lineH
        local foeTop
        if foe then
            foeTop = h + WITNESS.foe
            h = foeTop + #foe * WITNESS.foeLine
        end
        local rowTop
        if row then
            rowTop = h + WITNESS.row
            h = rowTop + row.h
        end
        local underW = math.max(deedW, foeW, row and row.w or 0)
        return { form = form, F = F, line = line, others = others, nameW = nameW, nameH = nameH, deed = deed,
            deedSize = F.deed, lineH = lineH, deedTop = deedTop, under = under, foe = foe, foeTop = foeTop, row = row,
            rowTop = rowTop, h = math.ceil(h), w = math.ceil(underW),
            W = math.max(math.ceil(underW) + pad[1] + pad[3], nameW + pad[1] + pad[3]) }
    end

    -- `text` laid with its left at x, its middle at y (from the slip's
    -- middle, y down).
    local function Put(text, x, y, w, h)
        card:Lay(text, x + w / 2, y, w, h)
        text:Show()
    end

    -- A piece of the pen laid flat where corners cannot move: from the
    -- middle of its start to the middle of its end (LuckyCard's).
    local function Flat(q)
        local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
        local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
        local dx, dy = ex - sx, ey - sy
        local width = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
            + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
        return (sx + ex) / 2, (sy + ey) / 2, math.sqrt(dx * dx + dy * dy) + 0.3, math.max(width, 0.4),
            math.atan2(-dy, dx)
    end

    -- The pen's quads on the slip, from card.ink.
    local function Ink(prims)
        for k, q in ipairs(prims) do
            local t = card.ink[k]
            if not t then
                t = Texture("ARTWORK", 5)
                card.ink[k] = t
            end
            t:SetColorTexture(q.r, q.g, q.b, q.a)
            if not card:Bend(t, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local mx, my, length, w, angle = Flat(q)
                card:Lay(t, mx, my, length, w, angle)
            end
            t:Show()
        end
        for k = #prims + 1, #card.ink do card.ink[k]:Hide() end
        return #prims
    end

    -- The blood, for a watcher (BLOOD, UI/Ink/Blood.lua's Draw): under the
    -- writing and the tape, in the card's turn. card.blood says what was
    -- spilt, for the tests.
    local function Bleed(W, H, writing)
        card.blood = Blood.Draw(card, card.stain, function() return Texture("BORDER", 1) end,
            WitnessCard.Blood(card.witness), W, H, writing, card.seedKey or "witness")
    end

    -- Everything but the name, as planned, the slip laid `W` by `H`.
    local function Draw(plan, W, H)
        local INK, STRONG = Style.INK, Style.INK_STRONG
        local left = -W / 2 + pad[1]
        local nameTop = -H / 2 + pad[2]
        local top = nameTop + plan.nameH
        local Lucky = ns.Hunts.LuckyCard
        for _, part in ipairs({ card.figure, card.barEdge, card.barPaper, card.barFill, card.barTick }) do
            part:Hide()
        end
        -- Where the writing is, for the blood (WitnessCard.Keep).
        local writing = { name = { left, nameTop + 2, left + plan.nameW, nameTop + plan.nameH }, lines = {}, marks = {} }

        -- The deed, in the hand, a line at a time.
        local pieces = {}
        for i, words in ipairs(plan.deed) do
            local line = card.deeds[i]
            if not line then
                line = Style.Text(card, Style.FONT.noteWritten)
                card.deeds[i] = line
            end
            Hand(line, plan.deedSize)
            line:SetText(words)
            line:SetTextColor(STRONG[1], STRONG[2], STRONG[3])
            local ly = top + plan.deedTop + (i - 0.5) * plan.lineH
            local lw = Width(line) + 2
            Put(line, left, ly, lw, plan.lineH)
            writing.lines[#writing.lines + 1] = { left, ly - plan.lineH / 2 + 2, left + lw, ly + plan.lineH / 2 }
            -- "Mercilessly", underlined twice.
            local at = plan.under and words:find(plan.under, 1, true)
            if at then
                Hand(measure, plan.deedSize)
                measure:SetText(words:sub(1, at - 1))
                local x0 = left + (at > 1 and Width(measure) or 0)
                measure:SetText(plan.under)
                local x1 = x0 + Width(measure)
                local base = ly + 0.3 * plan.deedSize
                local seed = card.seedKey or "witness"
                local first = Lucky.Underline(seed .. ":u1", x0, x1, base)
                local second = Lucky.Underline(seed .. ":u2", x0 + DOUBLE.inset[1], x1 - DOUBLE.inset[2],
                    base + DOUBLE.second)
                for _, q in ipairs(Lucky.Pen(first, Lucky.UNDER)) do pieces[#pieces + 1] = q end
                for _, q in ipairs(Lucky.Pen(second, Lucky.UNDER)) do pieces[#pieces + 1] = q end
                card.underlined = { x0 = x0, x1 = x1, base = base }
                writing.marks[#writing.marks + 1] = { x0 - 2, ly, x1 + 5, base + DOUBLE.second + 5 }
            end
        end
        for i = #plan.deed + 1, #card.deeds do card.deeds[i]:Hide() end
        card.pieces = Ink(pieces)

        -- The foe, in small print.
        for i, words in ipairs(plan.foe or {}) do
            local line = card.foes[i]
            if not line then
                line = Style.Text(card, Style.FONT.small)
                card.foes[i] = line
            end
            line:SetText(words)
            line:SetTextColor(INK[1], INK[2], INK[3])
            line:SetSize(0, 0)
            local ly, lw = top + plan.foeTop + (i - 0.5) * WITNESS.foeLine, Width(line) + 2
            Put(line, left, ly, lw, WITNESS.foeLine)
            writing.lines[#writing.lines + 1] = { left, ly - WITNESS.foeLine / 2, left + lw, ly + WITNESS.foeLine / 2 }
        end
        for i = #(plan.foe or {}) + 1, #card.foes do card.foes[i]:Hide() end

        -- A rescue's chart (ns.CloseCalls.Card.VITALS): the bar at the left, the
        -- figure beside it.
        local row = plan.row
        if row then
            local V, R, P = ns.CloseCalls.Card.VITALS, Style.RUBRIC, card:Paper()
            local B = V.bar
            local pct = math.max(0, math.min(100, card.witness.pct or 0))
            local foot = top + plan.rowTop + row.h
            local by = foot - B.h / 2 - 1
            card.barEdge:SetColorTexture(INK[1], INK[2], INK[3], B.edge)
            card:Lay(card.barEdge, left + row.bar / 2, by, row.bar + 2, B.h + 2)
            card.barPaper:SetColorTexture(P[1], P[2], P[3], 1)
            card:Lay(card.barPaper, left + row.bar / 2, by, row.bar, B.h)
            local fw = math.max(B.least, row.bar * pct / 100)
            card.barFill:SetColorTexture(R[1], R[2], R[3], 0.95)
            card:Lay(card.barFill, left + fw / 2, by, fw, B.h)
            local G, T = Style.GRAPHITE, B.tick
            card.barTick:SetColorTexture(G[1], G[2], G[3], T.alpha)
            card:Lay(card.barTick, left + row.bar * T.at, by, T.width, B.h + 2 + 2 * T.over)
            for _, part in ipairs({ card.barEdge, card.barPaper, card.barFill, card.barTick }) do part:Show() end
            Hand(card.figure, V.figure.size)
            card.figure:SetText((card.witness.pct or 0) .. "%")
            card.figure:SetTextColor(R[1], R[2], R[3])
            Put(card.figure, left + row.bar + V.figure.gap, foot - V.figure.size / 2 + 1, row.fw, V.figure.size)
            writing.marks[#writing.marks + 1] = { left - 1, foot - row.h, left + row.w, foot }
        end
        card.writing = writing
        Bleed(W, H, writing)
    end

    -- Laid as a strip, the first arrangement that fits `width` (FORMS, in
    -- ORDER), everything under the name in the room the strip keeps there.
    function hooks.plan(self, note, width)
        local plan
        for _, form in ipairs(ORDER) do
            plan = Try(form, width)
            if plan then break end
        end
        self.overfull = plan == nil
        plan = plan or Try(ORDER[#ORDER], width, true)
        -- The name line again at the arrangement's size (Try measured the
        -- others).
        Hand(self.name, plan.F.name)
        self.name:SetText(plan.line)
        note.under = { w = plan.w, h = plan.h, gap = 0, after = 0 }
        note.least, note.what = nil, nil
        self.plan, self.form, self.underlined = plan, plan.form, nil
        return plan
    end
    function hooks.draw(self, plan, W, H)
        -- (The strip writes its note's name; the line with the others is
        -- the card's.)
        self.name:SetText(plan.line)
        Draw(plan, W, H)
    end

    -- The width the card would like: XL, all of it on its lines, and never
    -- less than XL's least. The page gives a row's box this much where it
    -- has it (UI/Journey/Margin.lua's ROW).
    function card:Preferred()
        return math.max(FORMS.XL.least, Try("XL", 10000, true).W)
    end

    -- For the tests: the deed as written, its lines joined.
    function card:Deed()
        local parts = {}
        for i = 1, #(self.plan and self.plan.deed or {}) do parts[#parts + 1] = self.deeds[i]:GetText() end
        return table.concat(parts, " ")
    end

    -- For the tests: the foe's line as written ("" without one).
    function card:Foe()
        local parts = {}
        for i = 1, #(self.plan and self.plan.foe or {}) do parts[#parts + 1] = self.foes[i]:GetText() end
        return table.concat(parts, " ")
    end

    return card
end

-- The width a card for `w` would like (card:Preferred), measured on a card
-- of its own that is never shown.
local measurer
function WitnessCard.Preferred(w)
    measurer = measurer or WitnessCard.New(UIParent)
    measurer:SetWitness(w, "measure", 0)
    return measurer:Preferred()
end

WitnessCard.WITNESS, WitnessCard.FORMS, WitnessCard.BLOOD = WITNESS, FORMS, BLOOD

--------------------------------------------------------------------------
-- On the plates: the plate's one witness, its pass, its note in the margin
--------------------------------------------------------------------------

-- The plate's one witness (Kind.lua's At), or nil: someone who tried to
-- save the user from a death on this plate, saved them in a close call on
-- it, or watched them die on it. A witness goes before the killer card
-- (or the close call's, for one who saved the user): a person in the
-- moment is the better story than the creature (14 Oct, the user's call).
-- Who acted before who watched, then the longer watcher, then the latest.
-- `crosses` as Deaths' pass left them (cross.deaths), `marks`
-- plate.closeMarks, `index` Journey.WitnessIndex's, `onPage(x, y)` a card
-- spot to the page.
--
-- { kind ("helped" | "watched": the row kind's `witness`), type (the
-- row's: "tried_to_help", "saved_you", "watched_death"), guid, row, t,
-- watched (seconds, a watcher's), pct (health left, a rescue's), creature
-- ({ npcID, name, rank }, nil when not known), death (Deaths' record) or
-- call (the close call's), others (how many more witnessed the same
-- moment), mark (where its cross is on the page) }.
local DEATH_WITNESS = { [Witnesses.HELPED] = true, [Witnesses.WATCHED] = true }
local CLOSE_WITNESS = { [Witnesses.SAVED] = true }

function WitnessCard.Choose(crosses, marks, index, onPage)
    local Get = ns.Rows.Get
    local best
    local function Consider(found, extra)
        local w = found[1]
        if not w then return end
        local helped = Get(w.row.type).witness == "helped"
        local c = w.row.context or {}
        local better = not best
        if best then
            local bh = best.kind == "helped"
            if helped ~= bh then
                better = helped
            elseif (c.watched or 0) ~= (best.watched or 0) then
                better = (c.watched or 0) > (best.watched or 0)
            else
                better = w.t > best.t
            end
        end
        if not better then return end
        best = { kind = Get(w.row.type).witness, type = w.row.type, guid = w.guid, row = w.row, t = w.t,
            watched = c.watched, pct = c.pct, others = #found - 1,
            creature = type(c.name) == "string" and { npcID = c.npcID, name = c.name, rank = c.rank } or nil }
        for key, value in pairs(extra) do best[key] = value end
    end
    for _, cross in ipairs(crosses or {}) do
        for _, d in ipairs(cross.deaths or {}) do
            local px, py = onPage(cross.x, cross.y)
            Consider(Witnesses.At(index, d.t, DEATH_WITNESS), { death = d, mark = { px, py } })
        end
    end
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            -- Not one the player changed or wrote: nobody replaces their card,
            -- and an inserted one's time says nothing about who was there.
            if m.call and not m.call.customOf then
                Consider(Witnesses.At(index, m.call.t, CLOSE_WITNESS), { call = m.call, mark = mark.at })
            end
        end
    end
    return best
end

-- Someone who was there goes before the creature (ns.UI.JourneyPlate's
-- RegisterPass, after the marks): a witness to a death takes the killer
-- card's place, one who saved the user in a close call the close call's
-- card's (14 Oct, the user's call). plate.witness is Choose's, from the
-- crosses as Deaths' pass (`killer`, order 10) left them (their deaths)
-- and the close calls' marks, so it comes after it and after the close
-- call's (`foe`, 20), whose plate.foe it may clear: order 30, last of the
-- passes. The index of witnesses is the page's, built once
-- (opts.witnesses), else built here.
ns.UI.JourneyPlate.RegisterPass("witness", {
    order = 30,
    draw = function(plate, c)
        local witnesses = c.opts.witnesses or ns.Journey.WitnessIndex()
        plate.witness = WitnessCard.Choose(c.crosses, plate.closeMarks, witnesses, c.OnPage)
        if plate.witness and plate.witness.death then plate.killer = nil end
        if plate.witness and plate.witness.call then plate.foe = nil end
    end,
})

-- Someone who was there, in the margin (ns.UI.JourneyMargin.Register):
-- who watched you die, tried to save you or saved you. Their card goes
-- where the card they took the place of would have (the user's call, 14
-- Oct: a witness before the killer): order 30, before the killer's (40)
-- and the close call's (50); the pass above clears the one they replace,
-- plate.killer for a death's witness, plate.foe for a rescue. Their name
-- opens their page, as a person's strip does. Taken as shown, its creature
-- named on it (a rescue's as the close call's card would); left off, they
-- are told in a sentence of their own (`said.witness`, Text.lua's
-- caption) and the creature their card did not name goes to the words: a
-- death's as its killer's card would have (`said.death`, which the
-- killer's own card, left off, overrules), a rescue's as the close call's
-- (`said.close`).
do
    -- The creature a witness's death was to, as Text.KillerName takes it
    -- (the row's, else the death's own); nil for a death to the world or
    -- to nobody known.
    local function WitnessKiller(w)
        if w.creature and w.creature.name then return w.creature end
        local d = w.death
        if d and type(d.name) == "string" and d.name ~= "" and not d.environment then
            return { name = d.name, rank = d.rank }
        end
        return nil
    end
    ns.UI.JourneyMargin.Register("witness", {
        order = 30, pool = "witnessPool", count = "witnessesWritten",
        new = function(parent) return WitnessCard.New(parent) end,
        wants = function(it) return WitnessCard.Preferred(it.witness) end,
        item = function(plate)
            local w = plate.witness
            return w and { witness = w, top = w.mark[2], x = w.mark[1] } or nil
        end,
        write = function(card, it, c)
            local w = it.witness
            local guid = w.guid and ns.db.characters[w.guid] ~= nil and w.guid or nil
            card:SetWitness(w, c.Seed("witness", w.guid or ""), c.now, guid, c.ToPerson)
        end,
        mark = function(it) return it.witness.mark end,
        assume = function(said, plate)
            if plate.witness and plate.witness.call ~= nil then said.close = true end
        end,
        say = function(said, shown, plate)
            local seen = plate.witness
            if not seen then return end
            local it = shown[1]
            -- Whether the card as laid kept its creature's line.
            local named = it ~= nil and it.note ~= nil and it.note.plan ~= nil and it.note.plan.foe ~= nil
            if seen.death and not named then said.death = ns.UI.JourneyText.KillerName(WitnessKiller(seen)) end
            if named and seen.call ~= nil then said.close = true end
            if not it then said.witness = seen end
        end,
    })
end

--------------------------------------------------------------------------
-- A witness the player wrote in (.claude/features/custom-cards.md)
--------------------------------------------------------------------------

-- Every written witness on a plate's marks, as the card reads one, the newest
-- first so that where the margin runs out the oldest are left to their marks.
function WitnessCard.Customs(marks)
    local list = {}
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            if m.witnessed then list[#list + 1] = Witnesses.Written(m.witnessed, mark.at) end
        end
    end
    -- By name within a second: cards written at one stop can share its time, and
    -- the drawing has to come out the same each time.
    table.sort(list, function(a, b)
        if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) > (b.t or 0) end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- Its mark: what a real witness's leader comes to, so the card looks the same on
-- the page. A rescue goes to the close call's outlined cross, and a death watched
-- or fought to the death's solid one. They are only drawn alike: this mark counts
-- in plate.counts.witnesses, never as a death or a close call, and the witness
-- pass (Choose) reads plate.crosses and plate.closeMarks, so it cannot take this
-- for a real death. Solid where a spot holds both, as a death is the darker fact,
-- and with no `arg` (the picker), as "saw" is what a new card starts as. Order 34
-- after the close call's 30, whose size it shares and so its room.
ns.UI.JourneyPlate.RegisterMark("witnessed", {
    order = 34, cap = 20, count = "witnesses",
    radius = ns.CloseCalls.MARK.stem.h / 2 + 1, halo = false, hover = ns.CloseCalls.MARK.dot,
    tip = function(m, now) return Witnesses.Tip(Witnesses.Written(m.witnessed), now) end,
    -- Those on one spot told together (Text.lua's Tips).
    tips = function(list, now)
        local ws = {}
        for i, m in ipairs(list) do ws[i] = Witnesses.Written(m.witnessed) end
        return Witnesses.Tips(ws, now)
    end,
    keep = "witnessedMarks",
    -- Chosen with the marks rather than in a pass: nothing here depends on what
    -- another pass leaves, and nothing else clears it.
    chosen = "customWitnesses", choose = WitnessCard.Customs,
    arg = function(list)
        for _, m in ipairs(list) do
            if m.witnessed.deed ~= "saved" then return nil end
        end
        return "saved"
    end,
    draw = function(kit, x, y, arg)
        if arg == "saved" then
            ns.UI.JourneyPlate.MARKS.close.draw(kit, x, y)
        else
            ns.UI.JourneyPlate.SHAPE.death(kit, x, y)
        end
    end,
})

-- Each written witness its own card, in the detected ones' pool, past the plate's
-- one (Choose) and taking nobody's place: it clears no killer's or close call's
-- card, as a real witness's does, since the player said nothing about those.
-- Order 3, among the custom cards laid first. Left off, it is told in the
-- caption's words (`said.witnessed`, Text.lua), beside its mark. A card that gives
-- up its creature's line tells the words nothing, unlike a real witness's: its
-- creature need be no killer's or close call's the words would otherwise name, and
-- the tooltip still has it.
ns.UI.JourneyMargin.Register("witnessCustom", {
    order = 3, pool = "witnessPool", count = "customWitnessesWritten",
    new = function(parent) return WitnessCard.New(parent) end,
    wants = function(it) return WitnessCard.Preferred(it.witness) end,
    items = function(plate)
        local items = {}
        for _, w in ipairs(plate.customWitnesses or {}) do
            items[#items + 1] = { witness = w, top = w.mark[2], x = w.mark[1] }
        end
        return items
    end,
    write = function(card, it, c)
        local w = it.witness
        -- A typed name has no page: no guid, no link and no "click" on its tooltip.
        local guid = w.guid and ns.db.characters[w.guid] ~= nil and w.guid or nil
        card:SetWitness(w, c.Seed("witnessed", w.t or 0, w.name or ""), c.now, guid, c.ToPerson)
    end,
    mark = function(it) return it.witness.mark end,
    custom = function(it) return "witnessed", it.witness.written end,
    say = function(said, shown, plate)
        local seen = {}
        for _, it in ipairs(shown) do seen[it.witness] = true end
        local left = {}
        for _, w in ipairs(plate.customWitnesses or {}) do
            if not seen[w] then left[#left + 1] = w end
        end
        said.witnessed = left[1] and left or nil
    end,
})
