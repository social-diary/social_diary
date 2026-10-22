-- The profile's timeline (JNL-2, TLN-3 to TLN-7): ns.Timeline's items laid
-- out as page lines, and the rows that draw them -- a day's label on a
-- taped strip, episodes with their details line, dungeon runs on a taped
-- card, your notes on small slips, and the ink bracket an episode hangs
-- off: drawn when open, dashed when folded. Every other row stays a quiet
-- line of ink straight on the page (the person-page proposal, variant A:
-- in a long list only the days and the moments are paper). The profile
-- puts its own line above them (`clippings`: the plate, the facts and
-- your note, UI/Journal/Clippings.lua), which scrolls with the timeline.
--
-- The words are UI/Words/Timeline.lua's. The profile (UI/Journal/Profile.lua)
-- owns the list and fills it, through the three functions at the end.

local addonName, ns = ...

local Format = ns.UI.Format

local Style = ns.Style
local FONT = Style.FONT
local INK = Style.INK
local J = ns.UI.Journal

-- The ink bracket an episode's rows hang off, down the margin under the
-- episode's own icon: how dark the stroke is, how much that varies from line
-- to line (a pen, not a ruler), how much darker it gets under the mouse,
-- how long its foot is, and the gap left under it before the next entry.
-- Folded, with more inside, the stroke is dashed: `dash` long, `gap` apart,
-- so it runs on unbroken from one row to the next (rows are 20 high, and
-- grow in steps of `dash + gap` when their text wraps).
local BRACKET = { ink = 0.35, wobble = 0.08, hot = 1.6, foot = 5, below = 6, dash = 2, gap = 2 }
-- A dungeon run's entry (TLN-4): a card taped into the page beside the
-- run's medallion, in three lines as the person-page mockup (variant A)
-- has it: its title in Goodmountain with a mark per boss (at most `pips`)
-- at the card's right; how long it took, with its deaths and wipes; the
-- party's first names (at most `members`). Room inside the card (`padY`,
-- `padX`), medallion to text (`gutter`), under the title (`leading`),
-- between things on a line (`spread`), the lines' heights (`line1` to
-- `line3`); then the gap above the card, and the wider one below it, so
-- the next entry or day starts clear. The card is as wide as its longest
-- line measures, `overhang` px more past the title (Goodmountain's last
-- stroke), up to the row; only a title that will not fit the row's card
-- wraps, onto a second line, and the card grows taller.
-- (20 Oct, in the client: with the time and losses beside it on the first
-- line, "The Hall of Thanes" wrapped onto two lines.)
local VISIT = { medallion = 36, members = 4, pips = 12,
    padY = 6, padX = 8, gutter = 12, leading = 2, spread = 12, above = 8, below = 12,
    line1 = 22, line2 = 14, line3 = 14, overhang = 3 }
VISIT.height = VISIT.padY * 2 + VISIT.line1 + VISIT.leading + VISIT.line2 + VISIT.line3
-- The plate: a wash lighter than the page (the grain still shows through),
-- an ink hairline round it, and its shadow down and to the right. Under
-- the mouse it lifts (`lift`): it rises `rise` px toward the light, its
-- shadow falls `drop` px out at `shadow`, and its wash brightens to `wash`.
local PLATE = { wash = { 1, 0.97, 0.88, 0.24 }, edge = 0.24, shadow = 0.16, drop = 2,
    lift = { rise = 1, drop = 4, shadow = 0.22, wash = 0.34 } }
-- The card's tape, down its left end (the strips' tape, ns.UI.PAPER_LOOK's
-- look): `w` by `h`, its middle on the card's left edge `y` px from its
-- top, nearly upright (`slant` degrees against the clock, give or take
-- `jitter`, seeded by the run); laid flat, upright and plain. The card
-- itself lies straight: its medallion is a frame, which cannot turn.
local CARD_TAPE = { w = 22, h = 10, y = 12, slant = 82, jitter = 4 }
-- A day's label (the person-page proposal, variant A): a paraph (a small
-- lozenge, lapis and red by turns from day to day), the day in
-- Goodmountain, rubric and mixed case (Format.DayLabel's words, never in
-- capitals), on a taped strip (UI/Journal/Strips.lua's Day) `indent` px
-- in and `top` px down a line `height` tall, turned `tilt` degrees one
-- way and the other by turns, and a red line ruled from `rule` px past the
-- strip out to the edge, fading as it goes.
local DAY = { paraph = 6, indent = 16, top = 4, height = 34, tilt = { 0.6, -0.7 }, rule = 8, ruleAlpha = 0.40 }
local PARAPHS = { Style.LAPIS, Style.RUBRIC }
-- A note you wrote, on the timeline: a small slip of your hand (the
-- strips' Written) `top` px under its line's top, `below` px over the next,
-- at most `most` lines (the rest in its tooltip), from just past its icon
-- (`inset`) to `right` px short of the row's end.
local NOTE_SLIP = { top = 3, below = 6, most = 2, inset = 2, right = 4 }

local Count = Format.Count
local IsEpisode, OtherMembers = ns.UI.TimelineText.IsEpisode, ns.UI.TimelineText.OtherMembers
local DayLabel = Format.DayLabel

-- Episodes the reader has opened (TLN-7), by their key: the session, or an
-- exchange's first stored row. Weak, so a row pruned or forgotten takes its
-- entry along; not saved, so every login starts with them folded.
local openEpisodes = setmetatable({}, { __mode = "k" })

-- A visit never folds open: a click lays its run out on the table over
-- the book instead (TLN-12, UI/Dungeon/Spread.lua).
local function Openable(item)
    return IsEpisode(item) and item.hidden > 0 and item.kind ~= "visit"
end

-- What a click on a visit's card does, for its tooltip: lays the run's map
-- out, or, with that run out already, puts it away.
local function VisitHint(visit)
    if J.visit and J.visit.id == visit.id then return "Click to go back to their story." end
    if ns.Dungeons.Floors(visit.instanceID) then return "Click to open its map." end
    return "Click to open its sheet."
end

-- Where a line's icon starts, `depth` levels in: the icon column, clear of
-- the time, a step further in per level. A visit's plate starts there too,
-- an episode's bracket runs down the middle of the icon, and the text
-- starts TEXT_GAP after it.
local ICON, TEXT_GAP = 14, 6

local function IconLeft(depth)
    return 40 + depth * 18
end

-- A line is a row ROW_H high. Text that runs longer wraps onto more lines,
-- LEADING apart, up to WRAP_LINES (a dungeon's name up to NAME_LINES), the
-- rest in the tooltip; the row grows to fit. The time, the icon and the
-- bracket's foot stay beside the first line.
local ROW_H, LEADING, WRAP_LINES, NAME_LINES = 20, 3, 4, 2
local GROW = BRACKET.dash + BRACKET.gap

-- ns.Timeline's items, laid out as page lines: a heading per day, and an
-- episode's details on a line of their own, with the notes written during
-- it (TLN-10). An episode with more inside is followed by its notes, then
-- what it shows, then its details, hung off an ink bracket (`bracket`) that
-- ends at them: open, everything in it, on a drawn bracket; folded, its
-- moments, on a dashed one. Either way the details stay last, so nothing
-- jumps as it opens and folds. One with nothing more has its details right
-- under it, then its moments. Children stay under their episode whatever
-- day they fell on. Inside an open bracket a row's time is left blank where
-- the line above already shows that minute.
-- Deaths in one run at the same place as the death before them are worded
-- "there" (`there` on the item, set for the lines about to be laid out:
-- folded and opened, a different death may be the one before).
local function There(list)
    local place
    for _, child in ipairs(list) do
        if child.kind == "death" then
            local at = child.death.subZone or child.death.zone
            child.there = at ~= nil and at == place or nil
            place = at
        end
    end
end

local function TimelineLines(items, guid)
    local lines, lastDay, days = {}, nil, 0
    local now = ns.Now()

    local function Add(item)
        if not item.depth then
            local day = date("%Y-%m-%d", item.time)
            if day ~= lastDay then
                days = days + 1
                lines[#lines + 1] = { header = DayLabel(item.time, now), day = days, height = DAY.height }
                lastDay = day
            end
        end

        -- TLN-4: a visit stands apart, with space above and below.
        local isVisit = item.kind == "visit"
        -- (A day's label is a tall line, not a gap: a visit under it still
        -- stands apart.)
        local last = lines[#lines]
        if isVisit and last and not (last.height and not last.header) then
            lines[#lines + 1] = { height = VISIT.above }
        end

        local when, text, sub, icon, story = ns.UI.DescribeItem(item, guid)
        local font = FONT.body
        if IsEpisode(item) then font = FONT.strong end
        if item.kind == "added" or item.kind == "around" or item.kind == "first" then font = FONT.faded end
        if item.kind == "note" then font = FONT.noteWritten end

        local full = story or (sub and (text .. "\n" .. sub) or text)
        local isOpen = Openable(item) and openEpisodes[item.key]
        local isFolded = Openable(item) and not isOpen
        if Openable(item) then
            full = full .. "\n" .. (isOpen and "Click to fold it up again."
                or ("Click to show all %d."):format(#item.all))
        elseif isVisit then
            full = full .. "\n" .. VisitHint(item.visit)
        end

        -- Each line draws its own piece of the bracket, inked a little
        -- differently, but the same every time the episode opens.
        local depth, inked = item.depth or 0, 0
        -- A visit's bracket runs down from its medallion, a level further in
        -- than an icon's, so what hangs under it goes a level further too.
        local inset = isVisit and 1 or 0
        local function Bracket()
            if not (isOpen or isFolded) then return nil end
            inked = inked + 1
            return { depth = depth, dashed = isFolded or nil,
                x = isVisit and (IconLeft(depth) + VISIT.padX + VISIT.medallion / 2) or nil,
                alpha = BRACKET.ink + (Style.Noise(item.time + inked) - 0.5) * BRACKET.wobble }
        end

        -- Where the episode's own line is; anything hung under it follows.
        local head
        if isVisit then
            -- One tall entry; the details it leaves out are in the tooltip.
            local visit = item.visit
            local aside = Format.Duration(item.seconds)
            if visit.difficulty and visit.difficulty ~= "Normal" then aside = aside .. "  ·  " .. visit.difficulty end
            local losses = {}
            if (visit.deaths or 0) > 0 then losses[#losses + 1] = Count(visit.deaths, "death", "deaths") end
            local wipes = ns.DungeonRun.Wipes(visit)
            if wipes > 0 then losses[#losses + 1] = Count(wipes, "wipe", "wipes") end
            lines[#lines + 1] = { item = item, when = when, text = visit.name or "An instance",
                font = FONT.runTitle, depth = item.depth, full = full, height = VISIT.height,
                visit = { visit = visit, aside = aside, losses = table.concat(losses, "  ·  "),
                    members = OtherMembers(visit, guid) } }
            sub = nil
            head = #lines
            -- Its own lines start as far under the plate as the line above
            -- ends over it. A visit never folds, so they hang on no bracket.
            local under = isOpen and item.all or item.lines
            if #under > 0 or (item.notes and #item.notes > 0) then
                lines[#lines + 1] = { item = item, height = VISIT.above, bracket = Bracket() }
            end
        else
            lines[#lines + 1] = { item = item, when = when, text = text, icon = icon, font = font,
                depth = item.depth, full = full, note = item.note, slip = item.kind == "note" or nil }
            head = #lines
        end
        local function Details()
            lines[#lines + 1] = { item = item, text = sub, font = FONT.small, depth = item.depth,
                full = full, bracket = Bracket() }
        end
        if sub and not (isOpen or isFolded) then Details() end
        -- TLN-10: what the user wrote during the run, part of its own
        -- description, so it shows folded or open. With its icon, like a note
        -- of its own, one level in, clear of the bracket under the run's.
        for _, note in ipairs(item.notes or {}) do
            local noteText, noteFull = ns.UI.TimelineText.DescribeNote(note, guid)
            lines[#lines + 1] = { item = item, text = noteText, icon = "note", font = FONT.noteWritten,
                depth = depth + 1 + inset, full = noteFull, note = note, bracket = Bracket(), slip = true }
        end

        if isOpen or isFolded then
            local inside, shown = isOpen and item.all or item.lines, when
            There(inside)
            for i = 1, #inside do
                local first = #lines + 1
                Add(inside[i])
                if isOpen then
                    if lines[first].when == shown then
                        lines[first].when = nil
                    else
                        shown = lines[first].when
                    end
                end
                for k = first, #lines do
                    lines[k].bracket = Bracket()
                    lines[k].fold = item
                    lines[k].depth = (lines[k].depth or 0) + inset
                end
            end
            if sub then Details() end
            -- A short line under the bracket, so the next entry stands clear.
            -- A folded visit may have nothing under it to hang one off.
            if #lines > head then
                lines[#lines].bracket.last = true
                lines[#lines + 1] = { fold = item, height = BRACKET.below }
            end
        elseif IsEpisode(item) then
            There(item.lines)
            for i = 1, #item.lines do
                local first = #lines + 1
                Add(item.lines[i])
                for k = first, #lines do lines[k].depth = (lines[k].depth or 0) + inset end
            end
        end
        if isVisit and not lines[#lines].height then
            lines[#lines + 1] = { height = VISIT.below }
        end
    end

    for i = 1, #items do Add(items[i]) end

    return lines
end

-- A visit's duration, then its deaths and wipes, under its name.
local function VisitAside(info)
    return info.losses ~= "" and (info.aside .. "  ·  " .. info.losses) or info.aside
end

-- The `i`th of a visit's party as its card writes it: their first name,
-- the last shown with how many more.
local function PartyName(info, i)
    local members = info.members or {}
    local member = members[i]
    if not member then return nil end
    local name = member.first or "someone"
    if i == VISIT.members and #members > i then name = ("%s +%d"):format(name, #members - i) end
    return name
end

-- How wide a visit's marks per boss come out (0 for none), and the room
-- they take at the end of the title's line.
local function VisitPips(info)
    local visit = info.visit or {}
    local w = Style.PipsWidth(#(visit.bossesKilled or {}), visit.bossTotal, VISIT.pips)
    return w, w > 0 and (w + VISIT.spread) or 0
end

-- Measured on a font string of the list's own that is never shown: how
-- tall `text` is in `font` at `width` (0: on one line), and how wide.
local function Measure(list, font, text, width, maxLines)
    local m = list.measure
    if not m then
        m = Style.Text(list, FONT.body)
        m:SetSpacing(LEADING)
        m:SetWordWrap(true)
        m:Hide()
        list.measure = m
    end
    m:SetFontObject(font)
    m:SetWidth(width)
    m:SetMaxLines(maxLines)
    m:SetText(text)
    return m:GetStringHeight() or 0, m:GetStringWidth() or 0
end

-- How much taller than one line `text` wraps to, in whole GROW steps, and
-- how far below the top of its line one line of `font` starts.
local function Wrapped(list, font, text, width, maxLines)
    local single = Measure(list, font, "M", 0, 1)
    local extra = Measure(list, font, Style.Inkify(text), width, maxLines) - single
    if extra < 1 then return 0, single end
    return math.ceil(extra / GROW) * GROW, single
end

-- Where a line's text starts: after its icon.
local function TextLeft(line)
    return IconLeft(line.depth or 0) + ICON + TEXT_GAP
end

-- A note's slip on a row `rowW` wide: where it starts, and how wide it may
-- be.
local function SlipBox(line, rowW)
    local x = TextLeft(line) + NOTE_SLIP.inset
    return x, rowW - x - NOTE_SLIP.right
end

-- How tall a note's slip is, its words wrapped as the slip wraps them
-- (UI/Journal/Strips.lua's Written), measured on a font string of the
-- list's own in the hand.
local function SlipHeight(list, line, rowW)
    local Strips = ns.UI.PersonStrips
    local W = Strips.LOOK.written
    local m = list.slipMeasure
    if not m then
        m = Style.Text(list, FONT.noteWritten)
        m:Hide()
        list.slipMeasure = m
    end
    local _, width = SlipBox(line, rowW)
    local wrapped = Strips.Wrap(m, ns.UI.JourneyText.Written(line.text), Strips.WrittenRoom(width), NOTE_SLIP.most)
    return W.pad[2] + math.max(1, #wrapped) * W.line + W.pad[4]
end

-- The page lines (TimelineLines) sized to `list`: a line whose text wraps
-- gets the height it needs (`height`) and where its text starts (`top`); a
-- dungeon whose name wraps, a taller plate (`visit.extra`, `visit.nameTop`);
-- a note, its slip's height. The profile's own line (`clippings`) brings
-- its height.
local function FitTimelineLines(lines, list)
    local rowW = list:GetWidth() - ns.UI.SCROLLBAR_WIDTH - 2
    for _, line in ipairs(lines) do
        local left = IconLeft(line.depth or 0)
        if line.clippings then
            -- Laid by the profile.
        elseif line.slip then
            line.height = NOTE_SLIP.top + SlipHeight(list, line, rowW) + NOTE_SLIP.below
        elseif line.visit then
            -- The card as wide as its longest line, at most the row's.
            local info = line.visit
            local _, pipsRoom = VisitPips(info)
            local textX = left + VISIT.padX + VISIT.medallion + VISIT.gutter
            local most = rowW - 2 - PLATE.drop - left
            local width = left + most - VISIT.padX - pipsRoom - textX
            local extra, single = Wrapped(list, line.font, line.text, width, NAME_LINES)
            local _, titleW = Measure(list, line.font, Style.Inkify(line.text), 0, 1)
            local _, asideW = Measure(list, FONT.small, VisitAside(info), 0, 1)
            local partyW = 0
            for i = 1, VISIT.members do
                local name = PartyName(info, i)
                if name then
                    local _, nw = Measure(list, FONT.small, name, 0, 1)
                    partyW = partyW + (i > 1 and VISIT.spread or 0) + 12 + 4 + nw
                end
            end
            local inner = math.max(titleW + VISIT.overhang + pipsRoom, asideW, partyW)
            info.cardW = math.min(most, math.ceil(textX - left + inner + VISIT.padX))
            if extra > 0 then
                line.height = VISIT.height + extra
                info.extra, info.nameTop = extra, VISIT.padY + (VISIT.line1 - single) / 2
                info.cardW = most
            end
        elseif line.text and not line.height then
            local width = rowW - 2 - TextLeft(line)
            local extra, single = Wrapped(list, line.font, line.text, width, line.maxLines or WRAP_LINES)
            if extra > 0 then
                line.height, line.top = ROW_H + extra, (ROW_H - single) / 2
            end
        end
    end
    return lines
end

--------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------

local function InkBracket(row, hot)
    local a = math.min(1, row.item.bracket.alpha * (hot and BRACKET.hot or 1))
    row.stroke:SetColorTexture(INK[1], INK[2], INK[3], a)
    row.foot:SetColorTexture(INK[1], INK[2], INK[3], a)
    for _, dash in ipairs(row.dashes) do dash:SetColorTexture(INK[1], INK[2], INK[3], a) end
end

-- A folded bracket's stroke, a dash at a time, from the top of the row down
-- `length`; dashes are made as a row first needs them.
local function DashBracket(row, x, length)
    local step = BRACKET.dash + BRACKET.gap
    for i = 1, math.ceil(length / step) do
        local dash = row.dashes[i]
        if not dash then
            dash = row:CreateTexture(nil, "ARTWORK")
            dash:SetWidth(1)
            row.dashes[i] = dash
        end
        local top = (i - 1) * step
        dash:ClearAllPoints()
        dash:SetPoint("TOPLEFT", row, "TOPLEFT", x, -top)
        dash:SetHeight(math.min(BRACKET.dash, length - top))
        dash:Show()
    end
end

-- Any line of an episode on its bracket darkens the whole bracket, like a
-- link: a click on any of them opens or folds it.
local function HighlightBracket(row, hot)
    local line = row.item
    local episode = line and (line.fold or line.item)
    if not Openable(episode) then return end
    for _, other in ipairs(row.list.rows) do
        local l = other:IsShown() and other.item
        if l and l.bracket and (l.fold or l.item) == episode then InkBracket(other, hot) end
    end
end

local function BuildTimelineRow(list)
    local row = CreateFrame("Frame", nil, list)
    row:EnableMouse(true)

    row.when = Style.Text(row, FONT.small)
    row.when:SetPoint("LEFT", row, "TOPLEFT", 0, -ROW_H / 2)
    row.when:SetWidth(38)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)

    row.text = Style.Text(row, FONT.body)
    row.text:SetWordWrap(true)
    row.text:SetSpacing(LEADING)

    -- A day's paraph and its rule; its label's strip is made the first time
    -- a day lands on the row (DayStrip), a note's slip the first time a
    -- note does (NoteSlip).
    row.paraph = row:CreateTexture(nil, "ARTWORK")
    row.paraph:SetSize(DAY.paraph, DAY.paraph)
    row.paraph:SetRotation(math.pi / 4)
    row.dayRule = row:CreateTexture(nil, "ARTWORK")
    row.dayRule:SetHeight(1)
    local RUBRIC = Style.RUBRIC
    Style.Shade(row.dayRule, "HORIZONTAL", RUBRIC[1], RUBRIC[2], RUBRIC[3], DAY.ruleAlpha, 0)

    -- An episode's bracket: each line inks its own stretch of the stroke,
    -- dashed when folded, and the last one its foot, turning toward the rows.
    row.stroke = row:CreateTexture(nil, "ARTWORK")
    row.stroke:SetWidth(1)
    row.dashes = {}
    row.foot = row:CreateTexture(nil, "ARTWORK")
    row.foot:SetSize(BRACKET.foot, 1)
    row.list = list

    -- Lines wrap up to WRAP_LINES; the tooltip has the rest. A visit's
    -- card lifts under the mouse: it is there to be picked up.
    Style.Tooltip(row, function(self)
        if not self.full then return nil end
        if self.text.IsTruncated and not self.text:IsTruncated() and not self.full:find("\n") then
            return nil
        end
        return { { self.full, 1, 1, 1, 1, true } }
    end, "ANCHOR_TOPLEFT", function(self, hot)
        HighlightBracket(self, hot)
        if self.visit and self.visit:IsShown() then self.visit:Lift(hot) end
    end)

    -- A note the user wrote opens for writing (UI/Journal/Profile.lua). A
    -- visit's card lays its run out on the table over the book, and with
    -- it out puts it away (TLN-12, UI/Dungeon/Spread.lua). An episode with
    -- something folded away opens and folds; all its other lines answer,
    -- open or folded, the rows on its bracket too.
    row:SetScript("OnMouseUp", function(self)
        if self.item and self.item.note and J.EditNote then
            GameTooltip:Hide()
            J.EditNote(self.item.note)
            return
        end
        if self.item and self.item.visit then
            GameTooltip:Hide()
            ns.UI.OpenVisit(self.item.visit.visit.id, J.selected)
            return
        end
        local item = self.item and (self.item.fold or self.item.item)
        if not Openable(item) then return end
        openEpisodes[item.key] = not openEpisodes[item.key] or nil
        GameTooltip:Hide()
        ns.UI.RefreshTimeline()
    end)

    return row
end

-- A dungeon run, in three lines beside its medallion, on a card taped
-- down its left end (VISIT). The first line is the time, the name in
-- Goodmountain (rubric, mixed case) and a mark per boss at the card's
-- right; the second how long it took with its deaths and wipes; the third
-- the party by class and first name. Made the first time a visit lands on
-- the row.
local UpdateVisit

local function BuildVisit(row)
    local v = CreateFrame("Frame", nil, row)
    v:SetAllPoints()

    -- The plate, sized in UpdateVisit; its edges and shadow hang off it.
    local function Plate(sublevel, r, g, b, a)
        local texture = v:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        texture:SetColorTexture(r, g, b, a)
        return texture
    end
    local W = PLATE.wash
    v.plate = Plate(1, W[1], W[2], W[3], W[4])
    Style.Hairline(v, "BACKGROUND", 2, PLATE.edge, v.plate)
    v.right = Plate(0, INK[1], INK[2], INK[3], PLATE.shadow)
    v.below = Plate(0, INK[1], INK[2], INK[3], PLATE.shadow)
    -- Its tape, over the card's edge (CARD_TAPE), in the strips' tape.
    v.tape = v:CreateTexture(nil, "ARTWORK", nil, 7)

    -- Lying on the page, or lifted under the mouse (PLATE.lift): where its
    -- shadow falls and how dark, and how bright its wash.
    function v:Lift(hot)
        self.hot = hot or nil
        local L = PLATE.lift
        local d, a = hot and L.drop or PLATE.drop, hot and L.shadow or PLATE.shadow
        self.plate:SetColorTexture(W[1], W[2], W[3], hot and L.wash or W[4])
        self.right:ClearAllPoints()
        self.right:SetPoint("TOPLEFT", self.plate, "TOPRIGHT", 0, -d)
        self.right:SetPoint("BOTTOMRIGHT", self.plate, "BOTTOMRIGHT", d, -d)
        self.right:SetColorTexture(INK[1], INK[2], INK[3], a)
        self.below:ClearAllPoints()
        self.below:SetPoint("TOPLEFT", self.plate, "BOTTOMLEFT", d, 0)
        self.below:SetPoint("BOTTOMRIGHT", self.plate, "BOTTOMRIGHT", 0, -d)
        self.below:SetColorTexture(INK[1], INK[2], INK[3], a)
        if self.place then self.place(hot and L.rise or 0) end
    end
    v.medallion = Style.Medallion(v, VISIT.medallion)
    v.aside = Style.Text(v, FONT.small)
    v.pips = Style.Pips(v, VISIT.pips)
    v.members = {}
    for i = 1, VISIT.members do
        local icon = v:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        local name = Style.Text(v, FONT.small)
        name:SetWordWrap(false)
        v.members[i] = { icon = icon, name = name }
    end
    row.visit = v
    return v
end

-- Middle of the first, second and third line, down from the top.
local VISIT_LINE1 = -(VISIT.padY + VISIT.line1 / 2)
local VISIT_LINE2 = -(VISIT.padY + VISIT.line1 + VISIT.leading + VISIT.line2 / 2)
local VISIT_LINE3 = -(VISIT.padY + VISIT.line1 + VISIT.leading + VISIT.line2 + VISIT.line3 / 2)

function UpdateVisit(row, line)
    local v = row.visit or BuildVisit(row)
    local info = line.visit
    v:Show()

    local left = IconLeft(line.depth or 0)
    local textX = left + VISIT.padX + VISIT.medallion + VISIT.gutter
    -- The card's width (FitTimelineLines measured it; the row's otherwise)
    -- and its right edge.
    local cardW = info.cardW
        or (row.list:GetWidth() - ns.UI.SCROLLBAR_WIDTH - 2) - 2 - PLATE.drop - left
    local right = left + cardW
    local pipsW, pipsRoom = VisitPips(info)
    -- The plate where it lies, `rise` px up and to the left when lifted.
    -- Its tape: down its left end, at a slant seeded by the run; laid
    -- flat, upright and plain.
    local T, look = CARD_TAPE, ns.UI.PAPER_LOOK.tape
    local flat = ns.Setting("flatSheets") == true
    local slant = flat and 90 or T.slant + (Style.Noise(ns.UI.Surface.Seed(info.visit.id or "")) - 0.5) * 2 * T.jitter
    v.tape:SetColorTexture(look.tint[1], look.tint[2], look.tint[3], flat and look.flatAlpha or look.alpha)
    v.tape:SetSize(T.w, T.h)
    if v.tape.SetRotation then v.tape:SetRotation(math.rad(slant)) end
    function v.place(rise)
        v.plate:ClearAllPoints()
        v.plate:SetPoint("TOPLEFT", row, "TOPLEFT", left - rise, rise)
        v.plate:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", right - rise, rise)
        v.tape:ClearAllPoints()
        v.tape:SetPoint("CENTER", row, "TOPLEFT", left - rise, -T.y + rise)
    end
    -- A row handed a new line lies down again (the mouse left with the old).
    v:Lift(false)
    row.icon:Hide()
    row.when:ClearAllPoints()
    row.when:SetPoint("LEFT", row, "TOPLEFT", 0, VISIT_LINE1)

    v.medallion:ClearAllPoints()
    v.medallion:SetPoint("LEFT", row, "LEFT", left + VISIT.padX, 0)
    -- Without the client's picture of it, its last boss's face
    -- (UI/Dungeon/Print.lua).
    v.medallion:SetVisit(info.visit, ns.UI.DungeonPage.Face(info.visit))

    -- The title, up to the marks at the card's right; over two lines only
    -- where it would not fit the row's card (the card grew to fit).
    local titleRight = right - VISIT.padX - pipsRoom
    row.text:ClearAllPoints()
    row.text:SetMaxLines(NAME_LINES)
    if info.nameTop then
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -info.nameTop)
        row.text:SetPoint("TOPRIGHT", row, "TOPLEFT", titleRight, -info.nameTop)
    else
        row.text:SetPoint("LEFT", row, "TOPLEFT", textX, VISIT_LINE1)
        row.text:SetPoint("RIGHT", row, "TOPLEFT", titleRight, VISIT_LINE1)
    end
    local bosses = info.visit.bossesKilled or {}
    v.pips:Set(#bosses, info.visit.bossTotal)
    v.pips:ClearAllPoints()
    v.pips:SetPoint("LEFT", row, "TOPLEFT", right - VISIT.padX - pipsW, VISIT_LINE1)
    v.pips:SetShown(pipsW > 0)

    -- How long, its deaths and wipes; then the party.
    local extra = info.extra or 0
    v.aside:ClearAllPoints()
    v.aside:SetPoint("LEFT", row, "TOPLEFT", textX, VISIT_LINE2 - extra)
    v.aside:SetText(VisitAside(info))
    local line3, x = VISIT_LINE3 - extra, textX

    for i, slot in ipairs(v.members) do
        local member = (info.members or {})[i]
        slot.icon:SetShown(member ~= nil)
        slot.name:SetShown(member ~= nil)
        if member then
            slot.icon:ClearAllPoints()
            slot.icon:SetPoint("LEFT", row, "TOPLEFT", x, line3)
            Style.ClassIconOrInk(slot.icon, member.class)
            slot.name:SetText(PartyName(info, i))
            slot.name:ClearAllPoints()
            slot.name:SetPoint("LEFT", slot.icon, "RIGHT", 4, 0)
            x = x + 12 + 4 + slot.name:GetStringWidth() + VISIT.spread
        end
    end

end

-- A day's label, on its strip (UI/Journal/Strips.lua's Day), the paraph
-- before it and the rule after it on the strip's middle. The strip is made
-- the first time a day lands on the row.
local function LayDay(row, line)
    local strip = row.day
    if not strip then
        strip = ns.UI.PersonStrips.Day(row)
        row.day = strip
    end
    local turn = DAY.tilt[(line.day or 1) % 2 == 1 and 1 or 2]
    strip:SetNote({ name = line.header, seed = "day:" .. line.header, tilt = turn })
    local w, h = strip:Layout(DAY.indent, DAY.top, row.list:GetWidth())
    local mid = DAY.top + h / 2
    local paraph = PARAPHS[(line.day or 1) % 2 == 1 and 1 or 2]
    row.paraph:SetColorTexture(paraph[1], paraph[2], paraph[3], 1)
    row.paraph:ClearAllPoints()
    row.paraph:SetPoint("CENTER", row, "TOPLEFT", DAY.indent / 2 - 2, -mid)
    row.dayRule:ClearAllPoints()
    row.dayRule:SetPoint("LEFT", row, "TOPLEFT", DAY.indent + w + DAY.rule, -mid)
    row.dayRule:SetPoint("RIGHT", row, "RIGHT", -2, 0)
end

-- A note's slip (UI/Journal/Strips.lua's Written), from just past its
-- icon; made the first time a note lands on the row. The row keeps the
-- mouse: a click opens the note for writing, its tooltip the whole note.
local function NoteSlip(row, line)
    local strip = row.slip
    if not strip then
        strip = ns.UI.PersonStrips.Written(row)
        row.slip = strip
    end
    local rowW = row.list:GetWidth() - ns.UI.SCROLLBAR_WIDTH - 2
    local x, width = SlipBox(line, rowW)
    local note = line.note or {}
    strip:SetNote({ text = ns.UI.JourneyText.Written(line.text), most = NOTE_SLIP.most, tape = "corner",
        seed = "note:" .. tostring(note.id or note.time or line.text) })
    strip:Layout(x, NOTE_SLIP.top, width)
end

local function UpdateTimelineRow(row, line)
    -- The profile's own line: its block of plate, strips and note lies on
    -- this row while it shows (UI/Journal/Clippings.lua).
    if row.clippings and row.clippings ~= line.clippings then
        row.clippings:Let(row)
        row.clippings = nil
    end
    local isBlock = line.clippings ~= nil
    local isHeader = line.header ~= nil
    -- The short line under a bracket carries nothing.
    local isGap = not isHeader and not isBlock and line.text == nil
    local isSlip = line.slip == true and not isHeader and not isGap
    row.paraph:SetShown(isHeader)
    row.dayRule:SetShown(isHeader)
    if row.day then row.day:SetShown(isHeader) end
    if row.slip then row.slip:SetShown(isSlip) end
    row.when:SetShown(not isHeader and not isGap and not isBlock)
    row.text:SetShown(not isHeader and not isGap and not isBlock and not isSlip)

    -- The stroke runs down the middle of the episode's icon, through the
    -- whole line; on the last line it stops beside the first line of text
    -- (a plate's middle) and turns toward the row with its foot.
    local bracket = line.bracket
    local dashed = bracket ~= nil and bracket.dashed == true
    row.stroke:SetShown(bracket ~= nil and not dashed)
    row.foot:SetShown(bracket ~= nil and bracket.last == true)
    for _, dash in ipairs(row.dashes) do dash:Hide() end
    if bracket then
        local x = bracket.x or (IconLeft(bracket.depth) + ICON / 2)
        local height = row:GetHeight()
        local stop = bracket.last and (line.visit and height / 2 or ROW_H / 2) or height
        if dashed then
            DashBracket(row, x, stop)
        else
            row.stroke:ClearAllPoints()
            row.stroke:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
            row.stroke:SetPoint("BOTTOMLEFT", row, "TOPLEFT", x, -stop)
        end
        row.foot:ClearAllPoints()
        row.foot:SetPoint("LEFT", row, "TOPLEFT", x, -stop)
        InkBracket(row, false)
    end

    if row.visit then row.visit:SetShown(line.visit ~= nil) end
    row.when:ClearAllPoints()
    row.when:SetPoint("LEFT", row, "TOPLEFT", 0, -ROW_H / 2)

    if isBlock then
        row.icon:Hide()
        row.full = nil
        line.clippings:Hold(row)
        row.clippings = line.clippings
        return
    end
    if isHeader or isGap then
        if isHeader then LayDay(row, line) end
        row.icon:Hide()
        row.full = nil
        return
    end

    row.when:SetText(line.when or "")
    row.text:SetFontObject(line.font)
    row.text:SetText(Style.Inkify(line.text))
    row.full = line.full

    if line.visit then
        UpdateVisit(row, line)
        return
    end

    local left = IconLeft(line.depth or 0)
    -- A slip's time and icon sit by its first line of writing.
    local first = -ROW_H / 2
    if isSlip then
        local W = ns.UI.PersonStrips.LOOK.written
        first = -(NOTE_SLIP.top + W.pad[2] + W.line / 2)
        row.when:ClearAllPoints()
        row.when:SetPoint("LEFT", row, "TOPLEFT", 0, first)
        NoteSlip(row, line)
    end

    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "TOPLEFT", left, first)
    row.icon:SetShown(line.icon ~= nil and Style.SetTexture(row.icon, line.icon))
    row.icon:SetVertexColor(Style.ArtTint(line.icon))
    -- Gossip icons are drawn to the edge; Interface\Icons ones have a frame.
    if line.icon and Style.IsInventoryIcon(line.icon) then
        row.icon:SetTexCoord(unpack(Style.ICON_CROP))
    else
        row.icon:SetTexCoord(0, 1, 0, 1)
    end

    row.text:ClearAllPoints()
    row.text:SetMaxLines(line.maxLines or WRAP_LINES)
    if line.top then
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", TextLeft(line), -line.top)
        row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -line.top)
    else
        row.text:SetPoint("LEFT", TextLeft(line), 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    end
end

-- For the profile, which holds the timeline (UI/Journal/Profile.lua).
J.TimelineLines, J.FitTimelineLines, J.BuildTimelineRow, J.UpdateTimelineRow =
    TimelineLines, FitTimelineLines, BuildTimelineRow, UpdateTimelineRow
J.TIMELINE_ROW_HEIGHT = ROW_H
-- The run card's look, for the tests (its card fits its words).
J.VISIT = VISIT
