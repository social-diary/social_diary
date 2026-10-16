-- The dungeon page (.claude/dungeon-visits-prd.md §8, DGN-1 to DGN-3, TLN-12,
-- MAP-1 to MAP-4, MAP-7), this first slice the run's map alone. It takes
-- over the right page only, inside the person's page it was opened from:
-- the People list stays on the left, the index tabs stay out of the edge.
-- Not a page of its own in the book (no ribbon, no leaf): the profile
-- (UI/Journal/Profile.lua) shows it in place of its own pieces while
-- J.visit is set, as Your Diary's "full" mode takes its right page.
--
-- From the top: the day in red, like the timeline's, with the way back
-- beside it; the visit's own card from the timeline as the page's head,
-- the very card clicked, so a second click on it goes back; then the
-- print of the floor the run mostly took place on (UI/Dungeon/Print.lua);
-- the run's notes on paper strips under it, each with its arrow
-- (UI/Dungeon/Notes.lua); the other floors as small prints, to choose
-- from. Whether the usual way through is drawn is a setting (Interface,
-- Dungeons and Raids). A dungeon the diary has no map of gets a line in
-- pencil saying so (MAP-7).
--
-- Opened by a click on the card (UI/Journal/Timeline.lua) through
-- ns.UI.OpenVisit, the one way in (DGN-1; Your Diary's super plate will
-- take it too). Gone back from by the link, the card, the "Their story"
-- tab, choosing someone else, or closing the book (DGN-2).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal
local DungeonPage = ns.UI.DungeonPage

-- The page, top down: the day's rubric and the way back at `day`, the
-- card at `head`, the print `gap` under it, and `between` each thing
-- after; `foot` left clear at the bottom.
local PAGE = { day = 2, head = 24, gap = 14, between = 12, foot = 4 }
-- The other floors as small prints: at most `most` px wide each, `gap`
-- apart, `ratio` as tall as wide; `border` px of stock round each; its
-- name under it, `nameGap` below, on up to `lines` lines `line` px high.
-- A floor's kills as dots of red `kill` px across.
local STRIP = { most = 84, gap = 10, ratio = 2 / 3, border = 3, nameGap = 4, line = 12, lines = 2, kill = 4,
    shadow = 0.22 }
-- No map: one line in pencil under the card, `inset` px in (no empty
-- frame: DGN-11).
local NONE = { inset = 4 }


--------------------------------------------------------------------------
-- Which visit
--------------------------------------------------------------------------

-- `guid`'s visit `id`, or nil: only a visit they were in opens on their page.
function DungeonPage.Visit(guid, id)
    for _, visit in ipairs(ns.Instances.For(guid)) do
        if visit.id == id then return visit end
    end
end

-- The visit's entry on `guid`'s timeline: on its own, or inside a session.
local function Entry(guid, visit)
    for _, item in ipairs(ns.Timeline.For(guid)) do
        if item.kind == "visit" and item.visit.id == visit.id then return item end
        for _, child in ipairs(item.all or {}) do
            if child.kind == "visit" and child.visit.id == visit.id then return child end
        end
    end
end

-- The card as the timeline draws it, laid out for the page's head: the
-- entry's own line, at the top level whatever it was in.
local function HeadLine(view, guid, entry)
    local copy = {}
    for k, v in pairs(entry) do copy[k] = v end
    copy.depth = nil
    for _, line in ipairs(J.TimelineLines({ copy }, guid)) do
        if line.visit then return J.FitTimelineLines({ line }, view)[1] end
    end
end

--------------------------------------------------------------------------
-- Opening and going back
--------------------------------------------------------------------------

-- Opens visit `visitId` on `guid`'s page (the selected person's by
-- default), or goes back when it is open there already: a second click on
-- the card. Turns the book to their page first where it is not open on
-- it. Returns whether the page is open now.
function ns.UI.OpenVisit(visitId, guid)
    guid = ns.SafeGUID(guid) or J.selected
    if J.visit and J.visit.id == visitId and J.visit.guid == guid then
        DungeonPage.Close()
        return false
    end
    if not (guid and DungeonPage.Visit(guid, visitId)) then return false end
    GameTooltip:Hide()
    Style.PlaySound("pageTurn")
    if not (ns.UI.JournalShowing("people") and J.selected == guid) then
        J.visit = { id = visitId, guid = guid, offset = 0 }
        ns.UI.ShowJournal(guid)
        return true
    end
    if J.editing then J.EndEdit() end
    local p = J.journal.profile
    J.visit = { id = visitId, guid = guid, offset = p.timeline.offset or 0 }
    J.RefreshProfile()
    return true
end

-- Back to the person's page, the timeline where it was read. Returns
-- whether there was a dungeon page to go back from.
function DungeonPage.Close()
    local open = J.visit
    if not open then return false end
    J.visit = nil
    GameTooltip:Hide()
    if not ns.UI.JournalShowing() then return true end
    Style.PlaySound("pageTurn")
    J.RefreshProfile()
    local p = J.journal.profile
    if p.timeline:IsShown() then p.timeline:SetOffset(open.offset or 0) end
    return true
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

-- A floor's small print in the strip: a card of stock with the floor on
-- it, its kills as red dots, its name under it. A click shows it.
local function NewThumb(view)
    local thumb = CreateFrame("Button", nil, view)
    local INK = Style.INK
    thumb.shadow = thumb:CreateTexture(nil, "BACKGROUND", nil, -2)
    thumb.card = thumb:CreateTexture(nil, "BACKGROUND", nil, 0)
    local P = ns.UI.JourneyPlate.PLATE.stock
    thumb.card:SetColorTexture(P[1], P[2], P[3], 1)
    thumb.canvas = ns.UI.DungeonMap.New(thumb)
    thumb.canvas:SetPoint("TOPLEFT", STRIP.border, -STRIP.border)
    thumb.marks = ns.UI.Pool.New(function()
        local dot = thumb.canvas:CreateTexture(nil, "OVERLAY")
        return dot
    end)
    -- The one shown: in a neat line of ink.
    thumb.frame = CreateFrame("Frame", nil, thumb)
    thumb.frame:SetPoint("TOPLEFT", thumb.card, "TOPLEFT", -1, 1)
    thumb.frame:SetPoint("BOTTOMRIGHT", thumb.card, "BOTTOMRIGHT", 1, -1)
    Style.Hairline(thumb.frame, "ARTWORK", 0, 0.65)
    -- Under the card, outside the button's own box.
    thumb.name = Style.Text(thumb, FONT.small)
    thumb.name:SetJustifyH("CENTER")
    thumb.name:SetWordWrap(true)
    thumb.name:SetMaxLines(STRIP.lines)
    thumb:SetScript("OnEnter", function(self)
        if not self.current then self.name:SetTextColor(INK[1], INK[2], INK[3]) end
    end)
    thumb:SetScript("OnLeave", function(self) self:SetCurrent(self.current) end)
    function thumb:SetCurrent(current)
        self.current = current
        self.frame:SetShown(current)
        local c = current and Style.INK_STRONG or Style.INK_FADED
        self.name:SetTextColor(c[1], c[2], c[3])
        self.canvas:SetAlpha(current and 1 or 0.8)
    end
    thumb:SetScript("OnClick", function(self)
        if self.current then return end
        view.chosen[view.visit.id] = self.index
        view:Open(view.visit, view.guid, view.name)
    end)
    return thumb
end

-- The strip of the dungeon's floors at x, y, `width` wide: each a small
-- print in a slot of its own, the one shown in a neat line. Returns its
-- height.
local function DrawStrip(view, floors, shown, x, y, width)
    local visit, n = view.visit, #floors
    local slotW = math.min(STRIP.most, (width - (n - 1) * STRIP.gap) / n)
    local slotH, b = slotW * STRIP.ratio, STRIP.border
    local killed = {}
    for _, boss in ipairs(ns.Dungeons.Killed(visit)) do killed[#killed + 1] = boss end
    local P = ns.UI.JourneyPlate.PLATE
    view.thumbs:Begin()
    for i, floor in ipairs(floors) do
        local thumb = view.thumbs:Next()
        thumb.index = i
        local aw, ah = ns.UI.DungeonMap.Fit(floor, slotW - 2 * b, slotH - 2 * b)
        local cw, ch = aw + 2 * b, ah + 2 * b
        local tx = x + (i - 1) * (slotW + STRIP.gap) + (slotW - cw) / 2
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", view, "TOPLEFT", tx, -(y + slotH - ch))
        thumb:SetSize(cw, ch)
        thumb.card:SetAllPoints()
        thumb.shadow:ClearAllPoints()
        thumb.shadow:SetPoint("TOPLEFT", 1.5, -1.5)
        thumb.shadow:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
        thumb.shadow:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], STRIP.shadow)
        thumb.canvas:Draw(floor, aw, ah, { tint = P.tint, desaturate = P.desaturate, plain = P.plain })
        thumb.marks:Begin()
        for _, boss in ipairs(killed) do
            local mx, my = thumb.canvas:Place(boss.floor, boss.x, boss.y)
            if mx then
                local dot = thumb.marks:Next()
                Style.Disc(dot, Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3], 1)
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", thumb.canvas, "TOPLEFT", mx, -my)
                dot:SetSize(STRIP.kill, STRIP.kill)
            end
        end
        thumb.marks:Finish()
        thumb.name:ClearAllPoints()
        thumb.name:SetPoint("TOP", view, "TOPLEFT", x + (i - 1) * (slotW + STRIP.gap) + slotW / 2,
            -(y + slotH + STRIP.nameGap))
        thumb.name:SetWidth(slotW + STRIP.gap - 2)
        thumb.name:SetText(floor.name or ("Floor %d"):format(i))
        thumb:SetCurrent(i == shown)
    end
    view.thumbs:Finish()
    return slotH + STRIP.nameGap + STRIP.line * STRIP.lines
end

-- Shows `visit` on the page, opened from `guid`'s, whose first name is
-- `name`.
local function Open(view, visit, guid, name)
    view.visit, view.guid, view.name = visit, guid, name
    local now = ns.Now()
    local left, right = view.left, view.right

    -- The day, and the way back beside it.
    local entry = Entry(guid, visit)
    view.day:SetText(ns.UI.Format.DayLabel(entry and entry.time or visit.startedAt or now, now))
    view.back:SetText(name and ("Back to %s's story"):format(name) or "Back to their story")
    view.day:SetWidth(math.max(40, right - view.back:GetWidth() - 12))

    -- The card, as it is on the timeline.
    local y = PAGE.head
    local line = entry and HeadLine(view, guid, entry)
    view.head:SetShown(line ~= nil)
    if line then
        local head = view.head
        -- The card without its time: the day says when.
        line.when = nil
        head.item = line
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
        head:SetSize(view.rowW, line.height)
        J.UpdateTimelineRow(head, line)
        y = y + line.height
    end
    y = y + PAGE.gap

    local D = ns.Dungeons
    local wing = DungeonPage.Wing(visit)
    local floors = D.Floors(visit.instanceID, wing)
    view.floors = floors
    if not floors or #floors == 0 then
        view.print:Hide()
        view.thumbs:Begin()
        view.thumbs:Finish()
        DungeonPage.ClearNotes(view)
        view.none:ClearAllPoints()
        view.none:SetPoint("TOPLEFT", view, "TOPLEFT", left, -y)
        view.none.text:SetText(("The diary has no map of %s yet."):format(visit.name or "this place"))
        view.none:Show()
        return
    end
    view.none:Hide()

    local _, main = D.MainFloor(visit, wing)
    local index = view.chosen[visit.id] or main or 1
    if not floors[index] then index = 1 end
    local floor = floors[index]
    view.floorIndex = index

    -- What goes under the print, so the print takes the rest.
    local stripH = #floors > 1 and (STRIP.line * STRIP.lines + STRIP.nameGap
        + math.min(STRIP.most, ((right - left) - (#floors - 1) * STRIP.gap) / #floors) * STRIP.ratio) or 0
    local route = D.Route(visit.instanceID, wing)
    -- The usual way through (MAP-4), as the settings say
    -- (UI/Settings/Sections/Dungeons.lua).
    local hasRoute = route ~= nil and #route > 1 and ns.Setting("dungeonRoute") == true
    -- The run's notes (UI/Dungeon/Notes.lua): strips under the print.
    local notes = ns.DungeonRun.Notes(visit)
    local chosen = DungeonPage.Choose(visit, notes, guid)
    local notesH = DungeonPage.NotesHeight(view, chosen)
    local room = view.h - y - PAGE.foot - (notesH > 0 and notesH + PAGE.between or 0)
        - (stripH > 0 and stripH + PAGE.between or 0)

    local _, h = view.print:Lay({ visit = visit, floor = floor, wing = wing, x = left, y = y,
        w = right - left, h = room, route = hasRoute, notes = notes })
    y = y + h + PAGE.between

    if notesH > 0 then
        local used = DungeonPage.LayNotes(view, chosen, y)
        if used > 0 then y = y + used + PAGE.between end
    else
        DungeonPage.ClearNotes(view)
    end

    if stripH > 0 then
        DrawStrip(view, floors, index, left, y, right - left)
        y = y + stripH + PAGE.between
    else
        view.thumbs:Begin()
        view.thumbs:Finish()
    end
end

-- The page on `parent` (the person's page), `w` by `h`, hidden until
-- opened (view:Open).
function DungeonPage.New(parent, w, h)
    local view = CreateFrame("Frame", nil, parent)
    view:SetPoint("TOPLEFT")
    view:SetSize(w, h)
    view.w, view.h = w, h
    -- As wide as the timeline's rows, and the print as wide as the card's
    -- plate on them.
    view.rowW = w - ns.UI.SCROLLBAR_WIDTH - 2
    view.left, view.right = J.VISIT_PLATE.left, view.rowW - J.VISIT_PLATE.right
    view.chosen = {}

    view.day = Style.Rubric(view, view.right)
    view.day:SetPoint("TOPLEFT", 0, -PAGE.day)
    view.back = Style.Link(view, FONT.body, function() DungeonPage.Close() end)
    view.back:SetPoint("RIGHT", view, "TOPLEFT", view.right, -(PAGE.day + 8))

    view.head = J.BuildTimelineRow(view)
    view.print = DungeonPage.Print(view)
    view.notes = ns.UI.Pool.New(function() return DungeonPage.NewNote(view) end)
    -- Measures the hand a strip's heading is written in (its links).
    view.nameMeasure = Style.Text(view, FONT.noteWritten)
    view.nameMeasure:Hide()
    view.more = Style.Text(view, FONT.small)
    view.more:SetJustifyH("RIGHT")
    view.more:Hide()
    view.noteStrips, view.notesMore = {}, 0
    view.thumbs = ns.UI.Pool.New(function() return NewThumb(view) end)


    -- No map: a line in pencil where the print would be.
    local none = CreateFrame("Frame", nil, view)
    none:SetSize(view.right - view.left, 40)
    none.text = Style.Text(none, FONT.pencil)
    none.text:SetPoint("TOPLEFT", NONE.inset, 0)
    none.text:SetPoint("TOPRIGHT", -NONE.inset, 0)
    none.text:SetWordWrap(true)
    none:Hide()
    view.none = none

    view.Open = Open
    view:Hide()
    return view
end
