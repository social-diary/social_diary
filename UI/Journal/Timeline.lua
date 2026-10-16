-- The profile's timeline (JNL-2, TLN-3 to TLN-7): ns.Timeline's items laid
-- out as page lines, and the rows that draw them -- rubricated day headings,
-- episodes with their details line, dungeon runs on a plate, and the ink
-- bracket an episode hangs off: drawn when open, dashed when folded. The
-- profile puts its own lines above them (`prose` the page's width, and a
-- `rule`), so your note and the story scroll with the timeline.
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
-- A dungeon run's entry (TLN-4): a plate tipped into the page, two lines
-- beside the run's medallion, with the party's first names (at most
-- `members`) and a mark per boss (at most `pips`). Spacing in steps of 4:
-- room inside the plate (`padY`, `padX`), medallion to text (`gutter`),
-- between its two lines (`leading`) and between things on the second
-- (`spread`); then the gap above the plate, and the wider one below it, so
-- the next entry or day starts clear.
local VISIT = { medallion = 36, members = 4, pips = 12,
    padY = 8, padX = 8, gutter = 12, leading = 6, spread = 12, above = 8, below = 12,
    line1 = 22, line2 = 14 }
VISIT.height = VISIT.padY * 2 + VISIT.line1 + VISIT.leading + VISIT.line2
-- The plate: a wash lighter than the page (the grain still shows through),
-- an ink hairline round it, and its shadow down and to the right. Under
-- the mouse it lifts (`lift`): it rises `rise` px toward the light, its
-- shadow falls `drop` px out at `shadow`, and its wash brightens to `wash`.
local PLATE = { wash = { 1, 0.97, 0.88, 0.24 }, edge = 0.24, shadow = 0.16, drop = 2,
    lift = { rise = 1, drop = 4, shadow = 0.22, wash = 0.34 } }
-- A day's heading is rubricated: a paraph (a small lozenge, lapis and red
-- by turns from day to day), the day in red capitals, and a red line ruled
-- out to the edge, fading as it goes.
local DAY = { paraph = 6, indent = 13, rule = 6, ruleAlpha = 0.40 }
local PARAPHS = { Style.LAPIS, Style.RUBRIC }

local Count = Format.Count
local IsEpisode, OtherMembers = ns.UI.TimelineText.IsEpisode, ns.UI.TimelineText.OtherMembers
local DayLabel = Format.DayLabel

-- Episodes the reader has opened (TLN-7), by their key: the session, or an
-- exchange's first stored row. Weak, so a row pruned or forgotten takes its
-- entry along; not saved, so every login starts with them folded.
local openEpisodes = setmetatable({}, { __mode = "k" })

-- A visit never folds open: a click opens its dungeon page on the right
-- page instead (TLN-12, UI/Dungeon/Page.lua).
local function Openable(item)
    return IsEpisode(item) and item.hidden > 0 and item.kind ~= "visit"
end

-- What a click on a visit's card does, for its tooltip: opens the run's
-- map, or, on the dungeon page itself, goes back.
local function VisitHint(visit)
    if J.visit and J.visit.id == visit.id then return "Click to go back to their story." end
    if ns.Dungeons.Floors(visit.instanceID) then return "Click to open its map." end
    return "Click to open its page."
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
                lines[#lines + 1] = { header = DayLabel(item.time, now), day = days }
                lastDay = day
            end
        end

        -- TLN-4: a visit stands apart, with space above and below.
        local isVisit = item.kind == "visit"
        if isVisit and #lines > 0 and not lines[#lines].height then
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
            lines[#lines + 1] = { item = item, when = when, text = (visit.name or "An instance"):upper(),
                font = FONT.rubric, depth = item.depth, full = full, height = VISIT.height,
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
                depth = item.depth, full = full, note = item.note }
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
                depth = depth + 1 + inset, full = noteFull, note = note, bracket = Bracket() }
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

-- A visit's duration, then its deaths and wipes, beside its name.
local function VisitAside(info)
    return info.losses ~= "" and (info.aside .. "  ·  " .. info.losses) or info.aside
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

-- Where a line's text starts: the page's edge for prose, else after its icon.
local function TextLeft(line)
    return line.prose and 0 or IconLeft(line.depth or 0) + ICON + TEXT_GAP
end

-- The page lines (TimelineLines) sized to `list`: a line whose text wraps
-- gets the height it needs (`height`) and where its text starts (`top`); a
-- dungeon whose name wraps, a taller plate (`visit.extra`, `visit.nameTop`).
local function FitTimelineLines(lines, list)
    local rowW = list:GetWidth() - ns.UI.SCROLLBAR_WIDTH - 2
    for _, line in ipairs(lines) do
        local left = IconLeft(line.depth or 0)
        if line.visit then
            local info = line.visit
            local _, asideW = Measure(list, FONT.small, VisitAside(info), 0, 1)
            local textX = left + VISIT.padX + VISIT.medallion + VISIT.gutter
            local width = rowW - 2 - PLATE.drop - VISIT.padX - asideW - VISIT.spread - textX
            local extra, single = Wrapped(list, line.font, line.text, width, NAME_LINES)
            if extra > 0 then
                line.height = VISIT.height + extra
                info.extra, info.nameTop = extra, VISIT.padY + (VISIT.line1 - single) / 2
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

    row.header = Style.Text(row, FONT.headingRubric)
    row.header:SetPoint("BOTTOMLEFT", DAY.indent, 2)
    row.paraph = row:CreateTexture(nil, "ARTWORK")
    row.paraph:SetSize(DAY.paraph, DAY.paraph)
    row.paraph:SetRotation(math.pi / 4)
    row.paraph:SetPoint("CENTER", row.header, "LEFT", -DAY.indent / 2 - 1, 0)
    row.dayRule = row:CreateTexture(nil, "ARTWORK")
    row.dayRule:SetHeight(1)
    row.dayRule:SetPoint("LEFT", row.header, "RIGHT", DAY.rule, 0)
    row.dayRule:SetPoint("RIGHT", row, "RIGHT", -2, 0)
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

    -- The profile's rule, between your note and the story: a hairline
    -- fading out at both ends, in two halves that meet in the middle.
    row.rule = {}
    for i, alpha in ipairs({ { 0, Style.HAIRLINE }, { Style.HAIRLINE, 0 } }) do
        local half = row:CreateTexture(nil, "ARTWORK")
        half:SetHeight(1)
        Style.Shade(half, "HORIZONTAL", INK[1], INK[2], INK[3], alpha[1], alpha[2])
        row.rule[i] = half
    end

    -- Lines wrap up to WRAP_LINES; the tooltip has the rest. Prose is all
    -- there, but where it is cut short. A visit's card lifts under the
    -- mouse: it is there to be picked up.
    Style.Tooltip(row, function(self)
        if not self.full then return nil end
        if self.text.IsTruncated and not self.text:IsTruncated()
            and (self.prose or not self.full:find("\n")) then
            return nil
        end
        return { { self.full, 1, 1, 1, 1, true } }
    end, "ANCHOR_TOPLEFT", function(self, hot)
        HighlightBracket(self, hot)
        if self.visit and self.visit:IsShown() then self.visit:Lift(hot) end
    end)

    -- A note the user wrote opens for writing (UI/Journal/Profile.lua). A
    -- visit's card opens its dungeon page on the right page, and on that
    -- page goes back (TLN-12, UI/Dungeon/Page.lua). An episode with
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

-- A dungeon run, over two lines beside its medallion. The first line is
-- the time, the name in red capitals, and how long it took with its deaths
-- and wipes; the second a mark per boss, then the party by class and first
-- name.
-- Made the first time a visit lands on the row.
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
    v.aside:SetJustifyH("RIGHT")
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

-- Middle of the first and of the second line, down from the top.
local VISIT_LINE1 = -(VISIT.padY + VISIT.line1 / 2)
local VISIT_LINE2 = -(VISIT.padY + VISIT.line1 + VISIT.leading + VISIT.line2 / 2)

function UpdateVisit(row, line)
    local v = row.visit or BuildVisit(row)
    local info = line.visit
    v:Show()

    local left = IconLeft(line.depth or 0)
    local textX = left + VISIT.padX + VISIT.medallion + VISIT.gutter
    -- The plate where it lies, `rise` px up and to the left when lifted.
    function v.place(rise)
        v.plate:ClearAllPoints()
        v.plate:SetPoint("TOPLEFT", row, "TOPLEFT", left - rise, rise)
        v.plate:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2 - PLATE.drop - rise, rise)
    end
    -- A row handed a new line lies down again (the mouse left with the old).
    v:Lift(false)
    row.icon:Hide()
    row.when:ClearAllPoints()
    row.when:SetPoint("LEFT", row, "TOPLEFT", 0, VISIT_LINE1)

    v.medallion:ClearAllPoints()
    v.medallion:SetPoint("LEFT", row, "LEFT", left + VISIT.padX, 0)
    -- Without the client's picture of it, its last boss's face
    -- (UI/Dungeon/Print.lua), as on the dungeon page's head.
    v.medallion:SetVisit(info.visit, ns.UI.DungeonPage.Face(info.visit))

    v.aside:ClearAllPoints()
    v.aside:SetPoint("RIGHT", row, "TOPRIGHT", -2 - PLATE.drop - VISIT.padX, VISIT_LINE1)
    v.aside:SetText(VisitAside(info))
    row.text:ClearAllPoints()
    row.text:SetMaxLines(NAME_LINES)
    if info.nameTop then
        -- Over two lines, from the top of the first; the plate grew to fit.
        local right = 2 + PLATE.drop + VISIT.padX + v.aside:GetStringWidth() + VISIT.spread
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -info.nameTop)
        row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -right, -info.nameTop)
    else
        row.text:SetPoint("LEFT", row, "TOPLEFT", textX, VISIT_LINE1)
        row.text:SetPoint("RIGHT", v.aside, "LEFT", -VISIT.spread, 0)
    end
    local line2 = VISIT_LINE2 - (info.extra or 0)

    local bosses = info.visit.bossesKilled or {}
    local x = textX + v.pips:Set(#bosses, info.visit.bossTotal)
    v.pips:ClearAllPoints()
    v.pips:SetPoint("LEFT", row, "TOPLEFT", textX, line2)
    if x > textX then x = x + VISIT.spread end

    for i, slot in ipairs(v.members) do
        local member = info.members[i]
        slot.icon:SetShown(member ~= nil)
        slot.name:SetShown(member ~= nil)
        if member then
            slot.icon:ClearAllPoints()
            slot.icon:SetPoint("LEFT", row, "TOPLEFT", x, line2)
            Style.ClassIconOrInk(slot.icon, member.class)
            local name = member.first or "someone"
            if i == VISIT.members and #info.members > i then
                name = ("%s +%d"):format(name, #info.members - i)
            end
            slot.name:SetText(name)
            slot.name:ClearAllPoints()
            slot.name:SetPoint("LEFT", slot.icon, "RIGHT", 4, 0)
            x = x + 12 + 4 + slot.name:GetStringWidth() + VISIT.spread
        end
    end

end

local function UpdateTimelineRow(row, line)
    local isHeader = line.header ~= nil
    -- The short line under a bracket carries nothing.
    local isGap = not isHeader and line.text == nil
    row.header:SetShown(isHeader)
    row.paraph:SetShown(isHeader)
    row.dayRule:SetShown(isHeader)
    row.when:SetShown(not isHeader and not isGap)
    row.text:SetShown(not isHeader and not isGap)
    row.prose = line.prose ~= nil

    for _, half in ipairs(row.rule) do half:SetShown(line.rule ~= nil) end
    if line.rule then
        local left, right = row.rule[1], row.rule[2]
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -line.rule)
        left:SetPoint("TOPRIGHT", row, "TOP", 0, -line.rule)
        right:ClearAllPoints()
        right:SetPoint("TOPLEFT", row, "TOP", 0, -line.rule)
        right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -line.rule)
    end

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

    if isHeader or isGap then
        if isHeader then
            row.header:SetText(line.header:upper())
            local paraph = PARAPHS[(line.day or 1) % 2 == 1 and 1 or 2]
            row.paraph:SetColorTexture(paraph[1], paraph[2], paraph[3], 1)
        end
        row.icon:Hide()
        row.full = nil
        return
    end

    row.when:SetText(line.when or "")
    row.text:SetFontObject(line.font)
    -- Prose is the page's own, already in ink.
    row.text:SetText(line.prose and line.text or Style.Inkify(line.text))
    row.text:SetJustifyH(line.justify or "LEFT")
    row.full = line.full

    if line.visit then
        UpdateVisit(row, line)
        return
    end

    local left = IconLeft(line.depth or 0)

    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "TOPLEFT", left, -ROW_H / 2)
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

-- For the profile, which holds the timeline (UI/Journal/Profile.lua), and
-- the dungeon page, which wears a visit's card as its head
-- (UI/Dungeon/Page.lua): where the card's plate starts, and how far short
-- of the row's right edge it stops.
J.TimelineLines, J.FitTimelineLines, J.BuildTimelineRow, J.UpdateTimelineRow =
    TimelineLines, FitTimelineLines, BuildTimelineRow, UpdateTimelineRow
J.TIMELINE_ROW_HEIGHT = ROW_H
J.VISIT_PLATE = { left = IconLeft(0), right = 2 + PLATE.drop }
