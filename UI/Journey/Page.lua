-- Your Diary's start page (JRN-11, JRN-13, JRN-15, JRN-16, JRN-21 to
-- JRN-23): the logged-in character's own road, the journal's first
-- section, in front of People.
--
-- The left page is the character's: their name in capitals like the
-- bookplate's (UI/Journal/Front.lua), who they are and their level, then
-- the recap, oldest first, one entry per level (one per week after the
-- cap). Each entry is rubricated like a day on the timeline ("LEVEL 12",
-- "so far" beside the one being played), with the faces of the people from
-- the diary crossed at it at the rubric's end: class circles, a rival's
-- ringed in rubric (JRN-22). One level is open at a time, the newest as
-- the diary falls open; the others are their rubric alone, a contents
-- line to open them by. The open one reads in three levels: the rubric,
-- then its prose in the diary's own words (UI/Journey/Text/Prose.lua),
-- each name a way to their page, the player's own note quoted in their
-- hand, any first sighting written in later, in hindsight, in the diary's
-- hand (JRN-23); then a ledger of the zones it was spent in, small, with dot
-- leaders out to their times and a dungeon's doorway in the margin
-- (JRN-15: the zone index's rows, now where they happened). An honest
-- line about where the diary began goes before them all (JRN-13).
--
-- The right page shows where the open level happened (JRN-21): up to three
-- close-up plates of map glued in (UI/Journey/Plate.lua), from any zone,
-- each captioned in a few words and with the people met there written in
-- the margin, a pencil leader from each name to their mark (JRN-22).
-- Clicking a plate or a zone row shows that zone's whole map as one plate
-- across the page (JRN-14), the open level only (other levels' roads and
-- marks are left off), with a line under it and the way back. A rubric goes
-- back to its level's plates.
--
-- The left page's list is virtual (ns.UI.VirtualList): an item per rubric,
-- paragraph and zone, each paragraph measured once to its own height, so
-- the frame count stays fixed however long the road grows. The right page
-- keeps three plates and hands them out to the slots each layout needs.
--
-- With nothing on the road yet, the page teaches what will be there, in
-- the style of the empty People page (UI/Journal/Empty.lua): a word on why
-- it is empty (the setting off, or nothing walked yet), a pencilled sample
-- entry, and a pencilled plate with notes in the margin. It is a recap,
-- never a tracker: nothing here counts quests, shows a bar or keeps a score.
--
-- A level with recorded dungeon runs opens on its first run's page
-- instead (UI/Journey/Run.lua, the keepsake page; interim, the user, 28
-- Oct, until the pages go by play session): its rubric steps on through
-- its runs to its plates and round again, and a run's ledger row opens
-- that run (OpenRun).
--
-- The page is one module, ns.UI.YourDiary, in a file per question; this
-- file, the last of them, builds it, refreshes it and turns it to. The
-- others, their order and what they share: UI/Journey/Look.lua.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local YourDiary = ns.UI.YourDiary

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, RIGHT_X, RIGHT_W = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X, BOOK.RIGHT_W
local BOOK_H, TOP = BOOK.BOOK_H, BOOK.TOP
local SCROLLBAR_WIDTH = ns.UI.SCROLLBAR_WIDTH

local HEAD, ENTRY, LEDGER, RIGHT_H = YourDiary.HEAD, YourDiary.ENTRY, YourDiary.LEDGER, YourDiary.RIGHT_H
local LAYOUT, SNAPSHOT, CAPTION, LEADER = YourDiary.LAYOUT, YourDiary.SNAPSHOT, YourDiary.CAPTION, YourDiary.LEADER
local LEADERS, FOOT, NOTHING, OFF = YourDiary.LEADERS, YourDiary.FOOT, YourDiary.NOTHING, YourDiary.OFF
local FillHeader, EntryItems = YourDiary.FillHeader, YourDiary.EntryItems
local BuildEntryRow, UpdateEntryRow = YourDiary.BuildEntryRow, YourDiary.UpdateEntryRow
local LayoutFor, Handout = YourDiary.LayoutFor, YourDiary.Handout
local NewNote, EnsurePools, ROW, Shared = YourDiary.NewNote, YourDiary.EnsurePools, YourDiary.ROW, YourDiary.Shared
local DrawPlates, DrawFull = YourDiary.DrawPlates, YourDiary.DrawFull
local DrawRun, HideRun, RunsOf = YourDiary.DrawRun, YourDiary.HideRun, YourDiary.RunsOf
local BuildEmpty, FillEmpty = YourDiary.BuildEmpty, YourDiary.FillEmpty

-- Set below, and on the module for the files before this one.
local OpenLevel, OpenFull, OpenRun

--------------------------------------------------------------------------
-- The right page
--------------------------------------------------------------------------

-- The setting off with a road kept: said under the plates, with the way
-- back.
local function PlaceOff(full)
    local page = YourDiary.page
    page.off:ClearAllPoints()
    page.keep:ClearAllPoints()
    if full then
        page.off:SetPoint("TOPLEFT", page.right, "TOPLEFT", OFF.fullX, -OFF.fullY)
        page.keep:SetPoint("LEFT", page.off, "RIGHT", 8, 0)
    else
        page.off:SetPoint("TOPLEFT", page.right, "TOPLEFT", OFF.x, -OFF.y)
        page.keep:SetPoint("TOPLEFT", page.off, "BOTTOMLEFT", 0, -2)
    end
end

-- The open entry's run `id`, or nil where it is not one of its runs.
local function RunOf(e, id)
    for _, visit in ipairs(RunsOf(e)) do
        if visit.id == id then return visit end
    end
end

-- The right page for the open entry: its plates, one zone's full page, or
-- one of its runs (UI/Journey/Run.lua).
-- Drawn as it opens or turns, from pools; never per frame.
local function DrawRight()
    local page = YourDiary.page
    local recap = page.recap
    local e = recap and recap.entries[page.open]
    for _, pool in ipairs(page.rightPools) do pool:Begin() end
    page.links = {}
    page.nothing:Hide()
    for _, part in pairs({ page.foot.name, page.foot.meta, page.foot.hint }) do part:Hide() end
    local shown = 0
    local visit = e and page.mode == "run" and RunOf(e, page.runVisit)
    if not visit then HideRun() end
    if e then
        if visit then
            shown = DrawRun(e, visit)
        elseif page.mode == "full" and page.fullMap then
            shown = DrawFull(e)
        else
            page.mode = "plates"
            shown = DrawPlates(e)
        end
    end
    for i = shown + 1, #page.plates do page.plates[i]:Hide() end
    for _, pool in ipairs(page.rightPools) do pool:Finish() end
    PlaceOff(page.mode == "full")
end

--------------------------------------------------------------------------
-- Construction and refresh
--------------------------------------------------------------------------

local function BuildPage(parent)
    local page = { parent = parent, plates = {}, sheets = {}, moments = {}, mode = "plates", links = {} }
    YourDiary.page = page
    local INK = Style.INK

    -- The character.
    page.name = Style.Text(parent, FONT.title)
    page.name:SetPoint("TOPLEFT", LEFT_X, -HEAD.name)
    page.who = Style.Text(parent, FONT.faded)
    page.who:SetPoint("TOPLEFT", LEFT_X, -HEAD.who)
    page.rule = parent:CreateTexture(nil, "ARTWORK")
    page.rule:SetSize(HEAD.ruleW, 1)
    page.rule:SetPoint("TOPLEFT", LEFT_X, -HEAD.rule)
    Style.Shade(page.rule, "HORIZONTAL", INK[1], INK[2], INK[3], Style.HAIRLINE, 0)

    page.measure = Style.Text(parent, FONT.body)
    page.measure:SetWidth(LEFT_W - SCROLLBAR_WIDTH - 2 - ENTRY.indent)
    page.measure:SetWordWrap(true)
    page.measure:SetSpacing(ENTRY.leading)
    page.measure:Hide()

    -- The entries.
    local listH = BOOK_H - HEAD.list - HEAD.bottom
    page.entries = ns.UI.Journal.List(parent, ENTRY.unit, ENTRY.rows, BuildEntryRow, UpdateEntryRow,
        LEFT_W, "TOPLEFT", LEFT_X, -HEAD.list)
    page.entries:SetNumRows(math.floor(listH / ENTRY.unit))

    -- The right page: the plates, their captions and notes, the leaders
    -- over the plates, and the full page's line.
    page.right = CreateFrame("Frame", nil, parent)
    page.right:SetPoint("TOPLEFT", RIGHT_X, -TOP)
    page.right:SetSize(RIGHT_W, RIGHT_H)
    page.leaders = CreateFrame("Frame", nil, page.right)
    page.leaders:SetAllPoints(page.right)
    page.leaders:SetFrameLevel(page.right:GetFrameLevel() + LEADERS.level)
    page.leaderPool = Handout(function()
        local stroke = page.leaders:CreateTexture(nil, "OVERLAY")
        if stroke.SetSnapToPixelGrid then
            stroke:SetSnapToPixelGrid(false)
            stroke:SetTexelSnappingBias(0)
        end
        return stroke
    end)
    page.dotPool = Handout(function()
        local dot = page.leaders:CreateTexture(nil, "OVERLAY")
        if dot.SetSnapToPixelGrid then
            dot:SetSnapToPixelGrid(false)
            dot:SetTexelSnappingBias(0)
        end
        return dot
    end)
    page.headingPool = Handout(function()
        local text = Style.Text(page.right, FONT.noteWritten)
        text:SetWordWrap(true)
        return text
    end)
    page.captionPool = Handout(function()
        local text = Style.Text(page.right, FONT.body)
        text:SetWordWrap(true)
        text:SetSpacing(2)
        return text
    end)
    page.notePool = Handout(NewNote)
    -- Every registered kind's notes (JourneyMargin.Register): the cards
    -- and slips, each kind's pool made here (page[spec.pool]), and the
    -- lists of pools the page draws and the margin rolls back.
    EnsurePools()

    page.nothing = Style.Text(page.right, FONT.faded)
    page.nothing:SetPoint("TOPLEFT", NOTHING.x, -NOTHING.y)
    page.nothing:SetWidth(NOTHING.w)
    page.nothing:Hide()

    local foot = {}
    page.foot = foot
    foot.name = Style.Text(page.right, FONT.page)
    foot.name:SetPoint("TOPLEFT", 12, -FOOT.y)
    foot.meta = Style.Text(page.right, FONT.small)
    -- No way back but the map itself: a click on it (FULLZOOM's DRAG), so
    -- the hint says so.
    foot.hint = Style.Text(page.right, FONT.small)
    foot.hint:SetText(FOOT.words)
    for _, part in pairs(foot) do part:Hide() end

    -- The setting off with a road already kept: said under the plates.
    page.off = Style.Text(page.right, FONT.small)
    page.off:SetText("Your road is not being kept just now.")
    page.keep = Style.Link(page.right, FONT.body, function()
        ns.JourneyCapture.SetEnabled(true)
        ns.UI.RefreshJourneyPage()
    end)
    page.keep:SetText("Keep it again")
    PlaceOff(false)

    page.empty = BuildEmpty(parent)
    return page
end

-- What the page shows: "entries" (a road to recap: anything kept, the
-- stop or road still open included, or a level reached), or "on" or "off"
-- for the empty page, by the setting.
local function State()
    local j = ns.Journey.Mine()
    if ns.Journey.Any(j) then return "entries" end
    return ns.JourneyCapture.On() and "on" or "off"
end

local function ShowRoad(shown)
    local page = YourDiary.page
    page.entries:SetShown(shown)
    page.right:SetShown(shown)
    page.empty:SetShown(not shown)
end

-- The left page's items for the recap as it is open now. `keep` holds the
-- reader's place; `steady` (an entry's index) keeps that entry's rubric
-- where it was on the page as others open and close round it.
local function Rebuild(keep, steady)
    local page = YourDiary.page
    local before = steady and page.rubrics and page.rubrics[steady]
    local offset = page.entries.offset or 0
    local items, rubrics = EntryItems(page.recap, page.now, page.fights)
    page.items, page.rubrics = items, rubrics
    page.newest = rubrics[#page.recap.entries]
    page.entries:SetData(items, keep)
    if before and rubrics[steady] then
        page.entries:SetOffset(math.max(0, rubrics[steady] - (before - offset)))
    end
end

-- What entry `i` opens on: its first run where it has recorded runs,
-- else its plates. Asked again of the level open (its rubric clicked
-- again), the next: the run after the one shown, the plates after the
-- last, the first run after the plates (interim, the user, 28 Oct).
local function NextView(i)
    local page = YourDiary.page
    local runs = RunsOf(page.recap.entries[i])
    if #runs == 0 then return "plates", nil end
    if page.open ~= i then return "run", runs[1].id end
    if page.mode == "run" then
        for k, visit in ipairs(runs) do
            if visit.id == page.runVisit then
                if runs[k + 1] then return "run", runs[k + 1].id end
                return "plates", nil
            end
        end
    end
    return "run", runs[1].id
end
YourDiary.NextView = NextView

-- Opens entry `i`: its prose on the left, its first run or its plates on
-- the right (NextView).
function OpenLevel(i)
    local page = YourDiary.page
    if not (page and page.recap and page.recap.entries[i]) then return end
    GameTooltip:Hide()
    local mode, id = NextView(i)
    page.open, page.mode, page.fullMap, page.runVisit = i, mode, nil, id
    Rebuild(true, i)
    DrawRight()
end

-- Shows run `id` of entry `i` (the open one when not given) across the
-- right page: its ledger row clicked.
function OpenRun(id, i)
    local page = YourDiary.page
    if not (page and page.recap and id) then return end
    i = i or page.open
    if not RunOf(page.recap.entries[i], id) then return end
    GameTooltip:Hide()
    page.open, page.mode, page.fullMap, page.runVisit = i, "run", nil, id
    Rebuild(true, i)
    DrawRight()
end

-- Shows `mapID`'s whole map across the right page, the entry `i` in ink
-- (the open one when not given).
function OpenFull(mapID, i)
    local page = YourDiary.page
    if not (page and page.recap and mapID) then return end
    GameTooltip:Hide()
    i = i or page.open
    page.open, page.mode, page.fullMap, page.runVisit = i, "full", mapID, nil
    Rebuild(true, i)
    DrawRight()
end
YourDiary.OpenLevel, YourDiary.OpenFull, YourDiary.OpenRun = OpenLevel, OpenFull, OpenRun

-- `opening`: the page is being turned to, so it falls open at the newest
-- entry and its plates. Otherwise (the diary changed while it lies open)
-- it stays where it was read. Cheap when nothing changed: the recap is
-- cached by version (JourneyRecap.For), and the page is only rebuilt when
-- it, or the day (relative dates), moved on, or as it opens.
function ns.UI.RefreshJourneyPage(opening)
    local page = YourDiary.page
    if not page then return end
    -- Called by the book as it turns here: that is an opening.
    if opening == nil then opening = true end
    FillHeader()

    local state = State()
    page.state = state
    local route = state == "entries"
    ShowRoad(route)
    local on = ns.JourneyCapture.On()
    page.off:SetShown(route and not on)
    page.keep:SetShown(route and not on)
    if not route then
        FillEmpty(page.empty, state == "on")
        page.recap = nil
        return
    end

    local recap, ctx = ns.JourneyRecap.For(ns.ownGUID)
    if not recap then return end
    local now = ns.Now()
    local day = ns.DayStart(now)
    local changed = recap ~= page.recap or day ~= page.day
    if changed then
        page.recap, page.ctx, page.day, page.now = recap, ctx, day, now
        page.fights = ns.Journey.FightIndex()
        page.witnesses = ns.Journey.WitnessIndex()
        page.sheets, page.moments = {}, {}
    end
    local count = #recap.entries
    if opening or not page.open or page.open > count then
        -- Fallen open on the newest entry's first view (NextView asked as
        -- of another entry open).
        page.open = nil
        page.mode, page.runVisit = NextView(count)
        page.open, page.fullMap = count, nil
    end
    if changed or opening then
        Rebuild(not opening)
        DrawRight()
    end
    if opening and page.rubrics[page.open] then page.entries:SetOffset(page.rubrics[page.open] - 1) end
end

-- Draws the right page again as it is (/sd pen, after the pen changed).
function ns.UI.RedrawJourneyPage()
    local page = YourDiary.page
    if page and page.recap and page.state == "entries" then DrawRight() end
end

-- Kept up to date while it lies open: a session, a note or a fight written
-- elsewhere changes what the entries say.
ns.On("SD_DIARY_CHANGED", function()
    if ns.UI.JournalShowing("journey") then ns.UI.RefreshJourneyPage(false) end
end)

-- Test hook (tests, plate_dump.lua, /sd journey debug): the page's state.
function ns.UI.JourneyPage()
    return YourDiary.page
end
ns.UI.JourneyLook = { ENTRY = ENTRY, LEDGER = LEDGER, CAPTION = CAPTION, LEADER = LEADER, LAYOUT = LAYOUT, FOOT = FOOT,
    ROW = ROW, Shared = Shared, SNAPSHOT = SNAPSHOT, LayoutFor = LayoutFor }

-- A zone's whole map on the right page (JRN-14): at the open level when
-- it was there, else the latest level that was.
function ns.UI.OpenZoneSheet(mapID)
    local page = YourDiary.page
    if not (page and mapID) then return end
    ns.UI.RefreshJourneyPage(false)
    local recap = page.recap
    if not recap then return end
    local function Visited(e)
        for _, place in ipairs(e and e.places or {}) do
            if place.mapID == mapID then return true end
        end
        return false
    end
    local i = page.open
    if not Visited(recap.entries[i]) then
        for k = #recap.entries, 1, -1 do
            if Visited(recap.entries[k]) then
                i = k
                break
            end
        end
    end
    OpenFull(mapID, i)
end

-- The green ribbon's page, the book's first (JRN-16; UI/Journal/Pages.lua).
-- Turned to, it falls open at the newest entry.
ns.UI.Journal.RegisterPage("journey", {
    order = 10, ribbon = { colour = "green", label = "Your Diary" }, leaf = 1, buildOrder = 40,
    build = function(container) BuildPage(container) end,
    refresh = function() ns.UI.RefreshJourneyPage() end,
})
