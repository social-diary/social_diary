-- The open person's page (JNL-2), on the right (the person-page proposal,
-- variant A, "Clippings"): a list that scrolls by the pixel: their header
-- written on the page (UI/Journal/Header.lua: portrait, name, who they are,
-- tags), the plate, the facts' strips and your note in one tall line
-- (UI/Journal/Clippings.lua), then the timeline. Its tabs lay a
-- loose sheet over the book: the map, or a note for the timeline (DIA-11);
-- the page itself only ever shows what is written. In writing mode (the
-- edit tab) the entry form (UI/Windows/Entry.lua) takes its place, under the
-- header. A dungeon run opened
-- from its card is laid out on the table over the book (J.visit,
-- UI/Dungeon/Spread.lua); the page stays as it is under it.
--
-- The selection, the tab and writing mode live in the journal's shared
-- state (ns.UI.Journal, from UI/Journal/Book.lua). The timeline's rows are
-- UI/Journal/Timeline.lua's, which loads first.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal
local TimelineLines, FitTimelineLines, BuildTimelineRow, UpdateTimelineRow =
    J.TimelineLines, J.FitTimelineLines, J.BuildTimelineRow, J.UpdateTimelineRow

local BOOK = ns.UI.Journal.BOOK
local RIGHT_X, PROFILE_W, PROFILE_TOP, PROFILE_H = BOOK.RIGHT_X, BOOK.RIGHT_W, BOOK.TOP, BOOK.RIGHT_H
local TIMELINE_ROW_HEIGHT = J.TIMELINE_ROW_HEIGHT
local SHEET = ns.UI.PersonHeader.SHEET
-- The list: from the paper's top edge (SHEET.listTop) to the page's foot,
-- scrolled by the pixel; as many rows built as the shortest lines could
-- fill, and two more for the ones cut off at its top and foot. Its
-- scrollbar starts under the header (SHEET.first), clear of its writing.
local LIST_TOP, LIST_H = SHEET.listTop, PROFILE_H - SHEET.listTop
local TIMELINE_MAX_ROWS = math.floor(LIST_H / TIMELINE_ROW_HEIGHT) + 2
-- Writing mode: the "added" line under the header, the form under it.
local WRITING = { metaX = 64, metaY = 65, formY = 87 }

--------------------------------------------------------------------------
-- The profile (JNL-2)
--------------------------------------------------------------------------

local function Who(s)
    return ns.UI.Format.WhoLine(s.record, s.entry.guildAtAdd, "always")
end

-- The list: the page's own line (the plate, the facts, your note), then
-- the timeline, each sized to fit. `keep` holds where it scrolled to (an
-- episode opened or folded).
local function FillTimeline(p, s, keep)
    local lines = { { clippings = p.clippings, height = p.clippings:Fill(s) } }
    for _, line in ipairs(TimelineLines(ns.Timeline.For(s.guid), s.guid)) do lines[#lines + 1] = line end
    p.timeline:SetData(FitTimelineLines(lines, p.timeline), keep)
end

-- The list alone (ns.UI.RefreshTimeline, UI/Journal/Book.lua).
function J.RefreshTimelineList()
    local s = J.journal and J.selected and ns.People.Stats(J.selected)
    if s then FillTimeline(J.journal.profile, s, true) end
end

--------------------------------------------------------------------------
-- Writing a note (DIA-11)
--------------------------------------------------------------------------
--
-- On a loose sheet over the book (UI/Paper/NoteSheet.lua), like the map: from
-- the "Add a note" tab for a new one, or a note clicked on the timeline to
-- change it. The page stays as it is under it.

local RefreshProfile

local function OpenNote(note)
    local p = J.journal and J.journal.profile
    if not p or not J.selected then return end
    J.EndEdit()
    J.tab = "note"
    p.noteSheet:Open(J.selected, note)
    RefreshProfile()
end

-- A note clicked on the timeline (UI/Journal/Timeline.lua).
function J.EditNote(note)
    if note then OpenNote(note) end
end

function RefreshProfile()
    if not J.journal then return end
    local p = J.journal.profile

    local s = J.selected and ns.People.Stats(J.selected)
    -- A run out on the table is someone's: nobody's page, anyone else's or
    -- writing puts it away.
    -- (One opened from Your Diary is the diary's, not a person's.)
    if J.visit and J.visit.from ~= "journey" and (not s or J.visit.guid ~= s.guid or J.editing) then
        ns.UI.DungeonPage.Close(true)
    end
    if not s then
        J.selected = nil
        p:Hide()
        p.map:Hide()
        -- An empty diary's right page is the page drawn in pencil
        -- (UI/Journal/Empty.lua).
        J.journal.emptyProfile:SetShown(ns.Diary.Count() > 0)
        return
    end
    J.journal.emptyProfile:Hide()
    p:Show()

    p.header:Set(s.record, s.name, Who(s), s.entry, J.editing)
    p.meta:SetShown(J.editing)
    p.form:SetShown(J.editing)

    if J.editing then
        for _, piece in ipairs({ p.timeline, p.map, p.noteSheet }) do piece:Hide() end
        p.meta:SetText(ns.UI.Entry.Meta(s.guid))
        p.form:SetPerson(s.guid)
        p.tabStory:SetSelected(false)
        p.tabMap:SetSelected(false)
        p.tabNote:SetSelected(false)
        p.tabEdit:SetSelected(true)
        return
    end

    -- The map lies on the book as a loose sheet: the page stays under it.
    local onMap = J.tab == "map"
    -- A note's sheet is for the person it was opened on; anyone else's page
    -- opens on their story, and the sheet keeps its draft.
    if J.tab == "note" and p.noteSheet.guid ~= s.guid then J.tab = "timeline" end
    local onNote = J.tab == "note"
    p.timeline:Show()
    if not onNote then p.noteSheet:Hide() end
    p.map:SetShown(onMap)
    p.tabStory:SetSelected(not onMap and not onNote)
    p.tabMap:SetSelected(onMap)
    p.tabNote:SetSelected(onNote)
    p.tabEdit:SetSelected(false)

    FillTimeline(p, s)
    if onMap then p.map:SetPerson(s.guid) end
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

local function BuildProfile(panel, book)
    local p = CreateFrame("Frame", nil, book)
    p:SetPoint("TOPLEFT", RIGHT_X, -PROFILE_TOP)
    p:SetSize(PROFILE_W, PROFILE_H)

    -- The header, the plate, the facts, your note and the timeline, scrolled
    -- together by the pixel, from the paper's top edge.
    p.timeline = J.List(p, TIMELINE_ROW_HEIGHT, TIMELINE_MAX_ROWS, BuildTimelineRow, UpdateTimelineRow,
        PROFILE_W, "TOPLEFT", p, "TOPLEFT", 0, -LIST_TOP)
    p.timeline:SetSmooth(LIST_H)
    p.timeline.bar:ClearAllPoints()
    p.timeline.bar:SetPoint("TOPRIGHT", p.timeline, "TOPRIGHT", 0, -(SHEET.first - LIST_TOP))
    p.timeline.bar:SetPoint("BOTTOMRIGHT", p.timeline, "BOTTOMRIGHT", 0, 0)

    -- The list's first line: the plate (a click opens the map sheet, as
    -- its tab does), the facts and your note.
    p.clippings = ns.UI.Clippings.New(p.timeline, function()
        J.tab = "map"
        J.EndEdit()
        RefreshProfile()
    end)

    -- The header, on that same line (or on the page, in writing mode); its
    -- pieces where the page has always kept them.
    p.header = ns.UI.PersonHeader.New(p, p.timeline)
    p.clippings.header = p.header
    p.name, p.who, p.chips, p.relationship = p.header.name, p.header.who, p.header.chips, p.header.relationship

    -- Writing mode: the form below the header, the "added" line over it.
    p.meta = Style.Text(p, FONT.small)
    p.meta:SetPoint("TOPLEFT", WRITING.metaX, -WRITING.metaY)
    p.meta:Hide()

    p.form = ns.UI.Entry.Form(p, PROFILE_W, PROFILE_H - WRITING.formY)
    p.form:SetPoint("TOPLEFT", 0, -WRITING.formY)
    p.form:Hide()
    p.form.onDone = function() J.EndEdit() end

    -- The map: a loose sheet across both pages (UI/Map/HeatSheet.lua). A click
    -- on the book beside it puts it away.
    p.map = ns.UI.MapSheet.New(book)
    p.map.onPutAway = function()
        J.tab = "timeline"
        RefreshProfile()
    end

    -- Index tabs out of the book's right edge.
    p.tabStory = Style.SideTab(p, "book", "Their story", function()
        J.tab = "timeline"
        J.EndEdit()
        RefreshProfile()
    end)
    p.tabStory:SetPoint("TOPLEFT", panel, "TOPRIGHT", -3, -72)

    -- Open, its tab puts the sheet away again.
    p.tabMap = Style.SideTab(p, "map", "Where you saw them", function()
        J.tab = J.tab == "map" and "timeline" or "map"
        J.EndEdit()
        RefreshProfile()
    end)
    p.tabMap:SetPoint("TOPLEFT", p.tabStory, "BOTTOMLEFT", 0, -6)

    -- DIA-11: a note for the timeline, on a loose sheet like the map's.
    p.noteSheet = ns.UI.NoteSheet.New(book)
    p.noteSheet.onDone = function()
        J.tab = "timeline"
        RefreshProfile()
    end
    p.tabNote = Style.SideTab(p, "note", "Add a note", function() OpenNote(nil) end)
    p.tabNote:SetPoint("TOPLEFT", p.tabMap, "BOTTOMLEFT", 0, -6)

    -- Writing mode is a page of its own, so this tab is lit while it shows,
    -- and puts it away again as the map's does. Going there leaves any loose
    -- sheet, so the tabs still say what is open when it is done.
    p.tabEdit = Style.SideTab(p, "added", "edit", function()
        if J.editing then
            J.EndEdit()
        elseif J.selected then
            J.tab = "timeline"
            ns.UI.ShowEntry(J.selected)
        end
    end)
    p.tabEdit:SetPoint("TOPLEFT", p.tabNote, "BOTTOMLEFT", 0, -6)

    return p
end

-- For the book, which builds the page and refreshes it (UI/Journal/Book.lua).
J.RefreshProfile, J.BuildProfile = RefreshProfile, BuildProfile
