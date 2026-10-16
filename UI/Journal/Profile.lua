-- The open person's page (JNL-2), on the right: portrait, who they are and
-- tags, then a list that scrolls: your note and the story so far, then the
-- timeline. Its tabs lay a
-- loose sheet over the book: the map, or a note for the timeline (DIA-11);
-- the page itself only ever shows what is written. In writing mode the
-- entry form (UI/Windows/Entry.lua) takes its place, and with a dungeon run
-- opened from its card (J.visit) the dungeon page does (UI/Dungeon/Page.lua),
-- the tabs still out of the edge.
--
-- The selection, the tab and writing mode live in the journal's shared
-- state (ns.UI.Journal, from UI/Journal/Book.lua). The timeline's rows are
-- UI/Journal/Timeline.lua's, which loads first.

local addonName, ns = ...

local Format = ns.UI.Format

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal
local TimelineLines, FitTimelineLines, BuildTimelineRow, UpdateTimelineRow =
    J.TimelineLines, J.FitTimelineLines, J.BuildTimelineRow, J.UpdateTimelineRow

local BOOK = ns.UI.Journal.BOOK
local RIGHT_X, PROFILE_W, PROFILE_TOP, PROFILE_H = BOOK.RIGHT_X, BOOK.RIGHT_W, BOOK.TOP, BOOK.RIGHT_H
local TIMELINE_ROW_HEIGHT = J.TIMELINE_ROW_HEIGHT
local TIMELINE_MAX_ROWS = math.floor(PROFILE_H / TIMELINE_ROW_HEIGHT)
local MAX_TAG_CHIPS = 12
local HEADER_INDENT = Style.HEADING.indent  -- name, who and tags sit beside the portrait

-- The page's vertical rhythm, top down, after the heading's name line and
-- the gap under it (Style.HEADING): the who line's height (its font's, it
-- is not sized), the tag row's, the rule's, and the gaps between the pieces:
-- the list under the tags, and in it the note, the rule, the story and the
-- timeline. BuildProfile anchors with these, and TimelineRows adds them up,
-- so a change here moves both and the list's row count stays right.
local WHO_H, TAGS_H, RULE_H = 16, 18, 1
local GAP = { tags = 10, note = 14, rule = 14, story = 12, timeline = 14 }
-- At most this many lines of your note, and of the story, the rest of the
-- note in its tooltip: a line of the list must fit on the page.
local NOTE_LINES, STORY_LINES = 12, 6
local TAGS_TOP = Style.HEADING.name + Style.HEADING.gap + WHO_H + GAP.tags

--------------------------------------------------------------------------
-- The profile (JNL-2)
--------------------------------------------------------------------------

local function Em(text)
    return "|cff" .. Style.HEX.accent .. tostring(text) .. "|r"
end

-- "6 October", with the year once it is not this one (ns.UI.Format.DayMonth).
local function DayMonth(time) return Format.DayMonth(time, ns.Now()) end

-- JNL-2's key facts, written the way a diary would put them.
local function Story(s)
    local first = s.name:match("^(%S+)") or s.name
    local parts = {}

    if s.timesMet == 0 then
        parts[1] = ("You haven't spent time with %s yet."):format(first)
    else
        local where = s.firstZone and (" in " .. Em(s.firstZone)) or ""
        local level = s.levelThen and (", when they were level " .. s.levelThen) or ""
        local together = s.seconds >= 60 and (" and spent " .. Em(Format.Duration(s.seconds)) .. " together")
            or ""

        if s.timesMet == 1 then
            parts[1] = ("You met %s once%s on %s%s%s."):format(first, where, Em(DayMonth(s.firstMet)),
                level, together)
        else
            parts[1] = ("You first met %s%s on %s%s."):format(first, where, Em(DayMonth(s.firstMet)), level)
            parts[2] = ("You've crossed paths %s%s."):format(Em(s.timesMet .. " times"), together)
        end

        if s.levelNow and s.levelThen and s.levelNow ~= s.levelThen then
            parts[#parts + 1] = ("They're level %s now."):format(Em(s.levelNow))
        end
    end

    local fights = Format.FightsText(ns.Interactions.Fights(s.guid), Em)
    if fights then parts[#parts + 1] = fights end

    local seen = s.record and s.record.seen
    parts[#parts + 1] = Format.SeenText(seen):gsub("%.$", "") .. "."

    return table.concat(parts, " ")
end

local function Who(s)
    return Format.WhoLine(s.record, s.entry.guildAtAdd)
end

-- Tags as chips, then the relationship. Returns the row's height.
local function FillTags(p, entry)
    local x = 0
    for i = 1, MAX_TAG_CHIPS do
        local chip, tag = p.chips[i], entry.tags[i]
        if tag then
            chip:SetTag(tag)
            chip:ClearAllPoints()
            chip:SetPoint("LEFT", p.tagRow, "LEFT", x, 0)
            chip:Show()
            x = x + chip:GetWidth() + 6
        else
            chip:Hide()
        end
    end

    p.relationship:ClearAllPoints()
    p.relationship:SetPoint("LEFT", p.tagRow, "LEFT", x + (x > 0 and 4 or 0), 0)
    p.relationship:SetText(entry.relationship or "")

    local any = #entry.tags > 0 or entry.relationship ~= nil
    p.tagRow:SetHeight(any and TAGS_H or 1)
    return any and TAGS_H or 1
end

-- The list gets what the tags above it leave.
local function TimelineRows(tagHeight)
    local used = TAGS_TOP + tagHeight + GAP.note
    return math.floor((PROFILE_H - used) / TIMELINE_ROW_HEIGHT)
end

-- The list's own first lines, scrolled with the timeline under them: your
-- note (`prose`, drawn the page's full width, centred), a rule, and the
-- story so far.
local function PageLines(s)
    local entry = s.entry
    local note = entry.note
        and { prose = "note", text = entry.note, full = entry.note, font = FONT.noteWritten }
        or { prose = "note", text = "No note yet. Click Edit to write one.", font = FONT.faded }
    note.maxLines, note.justify = NOTE_LINES, "CENTER"
    return {
        note,
        { rule = GAP.rule, height = GAP.rule + RULE_H + GAP.story },
        { prose = "story", text = Story(s), font = FONT.body, maxLines = STORY_LINES },
        { height = GAP.timeline },
    }
end

-- The list: the page's lines, then the timeline, each sized to fit. `keep`
-- holds where it scrolled to (an episode opened or folded).
local function FillTimeline(p, s, keep)
    local lines = PageLines(s)
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

-- The page's own pieces, which the dungeon page lies in place of.
local function ShowPage(p, shown)
    for _, piece in ipairs({ p.portrait, p.name, p.who }) do piece:SetShown(shown) end
    p.dungeon:SetShown(not shown)
end

function RefreshProfile()
    if not J.journal then return end
    local p = J.journal.profile

    local s = J.selected and ns.People.Stats(J.selected)
    if not s then
        J.selected = nil
        J.visit = nil
        p:Hide()
        p.map:Hide()
        -- An empty diary's right page is the page drawn in pencil
        -- (UI/Journal/Empty.lua).
        J.journal.emptyProfile:SetShown(ns.Diary.Count() > 0)
        return
    end
    J.journal.emptyProfile:Hide()
    p:Show()

    local entry = s.entry
    Style.SetPersonHeading(p, s.record, s.name, Who(s))
    p.edit:SetShown(not J.editing)
    p.meta:SetShown(J.editing)
    p.form:SetShown(J.editing)
    p.tagRow:SetShown(not J.editing)

    if J.editing then
        J.visit = nil
        ShowPage(p, true)
        for _, piece in ipairs({ p.timeline, p.map, p.noteSheet }) do piece:Hide() end
        p.meta:SetText(ns.UI.Entry.Meta(s.guid))
        p.form:SetPerson(s.guid)
        p.tabStory:SetSelected(false)
        p.tabMap:SetSelected(false)
        p.tabNote:SetSelected(false)
        return
    end

    local tagHeight = FillTags(p, entry)

    -- The map lies on the book as a loose sheet: the page stays under it.
    local onMap = J.tab == "map"
    -- A note's sheet is for the person it was opened on; anyone else's page
    -- opens on their story, and the sheet keeps its draft.
    if J.tab == "note" and p.noteSheet.guid ~= s.guid then J.tab = "timeline" end
    local onNote = J.tab == "note"
    -- A dungeon run opened from their card, if it is theirs: the dungeon
    -- page lies in place of the page's own pieces, the sheets over it as
    -- over the page. Anyone else's page opens on their story.
    local visit = J.visit and J.visit.guid == s.guid and ns.UI.DungeonPage.Visit(s.guid, J.visit.id)
    if not visit then J.visit = nil end
    ShowPage(p, not visit)
    p.edit:SetShown(not visit)
    p.tagRow:SetShown(not visit)
    p.timeline:SetShown(not visit)
    if not onNote then p.noteSheet:Hide() end
    p.map:SetShown(onMap)
    -- On the dungeon page no tab is lit: their story is the way back.
    p.tabStory:SetSelected(not onMap and not onNote and not visit)
    p.tabMap:SetSelected(onMap)
    p.tabNote:SetSelected(onNote)

    p.timeline:SetNumRows(TimelineRows(tagHeight))
    FillTimeline(p, s)
    if visit then p.dungeon:Open(visit, s.guid, s.name:match("^(%S+)") or s.name) end
    if onMap then p.map:SetPerson(s.guid) end
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

local function BuildProfile(panel, book)
    local p = CreateFrame("Frame", nil, book)
    p:SetPoint("TOPLEFT", RIGHT_X, -PROFILE_TOP)
    p:SetSize(PROFILE_W, PROFILE_H)

    Style.PersonHeading(p, p, PROFILE_W, 100)

    -- A link like the list's sort and filter, not an icon: the client's icons
    -- with their own alpha are faint white glyphs on parchment, and the
    -- inventory ones carry a dark square.
    p.edit = Style.Link(p, FONT.body, function()
        if J.selected then ns.UI.ShowEntry(J.selected) end
    end)
    p.edit:SetText("Edit")
    p.edit:SetPoint("TOPRIGHT", 0, -8)

    p.tagRow = CreateFrame("Frame", nil, p)
    p.tagRow:SetPoint("TOPLEFT", p.who, "BOTTOMLEFT", 0, -GAP.tags)
    p.tagRow:SetSize(PROFILE_W, TAGS_H)
    p.chips = {}
    for i = 1, MAX_TAG_CHIPS do
        p.chips[i] = Style.TagChip(p.tagRow)
        p.chips[i]:Hide()
    end
    p.relationship = Style.Text(p.tagRow, FONT.faded)

    -- Your note, the story and the timeline, scrolled together.
    p.timeline = J.List(p, TIMELINE_ROW_HEIGHT, TIMELINE_MAX_ROWS, BuildTimelineRow, UpdateTimelineRow,
        PROFILE_W, "TOPLEFT", p.tagRow, "BOTTOMLEFT", -HEADER_INDENT, -GAP.note)

    -- Writing mode: the form below the header, the "added" line beside it.
    p.meta = Style.Text(p, FONT.small)
    p.meta:SetPoint("TOPLEFT", HEADER_INDENT, -56)
    p.meta:Hide()

    p.form = ns.UI.Entry.Form(p, PROFILE_W, PROFILE_H - 90)
    p.form:SetPoint("TOPLEFT", 0, -90)
    p.form:Hide()
    p.form.onDone = function() J.EndEdit() end

    -- A dungeon run's page (UI/Dungeon/Page.lua), in place of the rest
    -- while one is open. A book closed and opened again opens on the
    -- person's page.
    p.dungeon = ns.UI.DungeonPage.New(p, PROFILE_W, PROFILE_H)
    panel:HookScript("OnHide", function() J.visit = nil end)

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
        if not ns.UI.DungeonPage.Close() then RefreshProfile() end
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

    return p
end

-- For the book, which builds the page and refreshes it (UI/Journal/Book.lua).
J.RefreshProfile, J.BuildProfile = RefreshProfile, BuildProfile
