-- The journal window (JNL-1, JNL-2, JNL-4, JNL-6).
--
-- An open book, with no window frame: a leather cover round two pages. The
-- People list on the left page (search, sort, filters), the selected
-- person's page on the right (portrait, who they are, your note, the story
-- so far, then the timeline). An index tab on the right edge lays the map
-- on the book as a loose sheet (UI/Map/HeatSheet.lua). Ribbons hanging out of
-- the bottom of the book switch between the journal's pages: green for Your
-- Diary (8.11), red for People, purple for Recently nearby (JNL-3), grey
-- for the settings. The lists are virtual
-- (ns.UI.VirtualList), so the frame count stays fixed no matter how big the
-- diary grows. The look lives in the Style files (UI/Style/Tokens.lua on).
--
-- This file keeps the book: its geometry, the state its pages share, the
-- ribbons and the entry points. The pages are files of their own: Your
-- Diary, the user's own road (UI/Journey/Page.lua, with its map plates
-- in UI/Journey/Plate.lua), the People list (UI/Journal/People.lua), the profile (UI/Journal/Profile.lua)
-- with its timeline (UI/Journal/Timeline.lua, in the words of
-- UI/Words/Timeline.lua), Recently nearby (UI/Journal/Nearby.lua) and the
-- settings (UI/Settings/Page.lua). In front of them lies the introduction: the
-- frontispiece (UI/Journal/Frontispiece.lua), pencil and ink, then the front
-- matter (UI/Journal/Front.lua), bookplate and contents. The book opens on
-- the frontispiece until the front matter has been read, and on Your Diary
-- after that (JRN-16);
-- an empty diary's People page teaches how someone gets in
-- (UI/Journal/Empty.lua).
--
-- The journal only reads. Editing goes through the entry dialog, which already
-- routes every change through ns.Diary; the journal refreshes when it closes.
--
-- JNL-5 (load the archive on demand, with a loading indicator) waits on the
-- DAT-2 archive split, which does not exist yet and whose LoD behaviour is
-- untested (T-H2). When it lands, ShowJournal loads it before the first query.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local WIDTH, HEIGHT = 840, 600
local COVER = 16  -- how far the cover reaches past the pages
local BOOK_W, BOOK_H = WIDTH - 2 * COVER, HEIGHT - 2 * COVER
local LEFT_PAGE = 286
local LEFT_X, LEFT_W = 26, LEFT_PAGE - 50
local RIGHT_X = LEFT_PAGE + 30
local PROFILE_W = BOOK_W - RIGHT_X - 26
local PROFILE_TOP, PROFILE_BOTTOM = 20, 14
local PROFILE_H = BOOK_H - PROFILE_TOP - PROFILE_BOTTOM

-- The book's geometry, for the pages that live in their own files
-- (UI/Journal/People.lua, UI/Journal/Profile.lua, UI/Journal/Nearby.lua and
-- on): ns.UI.Journal.BOOK, which each takes as a local BOOK.
local BOOK = {
    BOOK_W = BOOK_W, BOOK_H = BOOK_H,
    LEFT_X = LEFT_X, LEFT_W = LEFT_W,
    RIGHT_X = RIGHT_X, RIGHT_W = PROFILE_W,
    TOP = PROFILE_TOP, RIGHT_H = PROFILE_H,
}

-- What the journal's files share (UI/Journal/People.lua,
-- UI/Journal/Profile.lua, UI/Journal/Timeline.lua): the state below, and the
-- functions one of them calls in another. Every file reads and writes the
-- state through this table; a local copy would go stale as soon as another
-- file changed it.
local J = {}
ns.UI.Journal = J
J.BOOK = BOOK

-- The heading of one of the journal's pages, on the left page, and the
-- count to its right ("3 in the diary", "2 days"). Returns the count, for
-- the page to fill.
function J.PageHeading(book, text)
    local title = Style.Text(book, FONT.page)
    title:SetPoint("TOPLEFT", LEFT_X, -20)
    title:SetText(text)

    local count = Style.Text(book, FONT.small)
    count:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", LEFT_X + LEFT_W, -36)
    count:SetJustifyH("RIGHT")
    return count
end

-- The journal's frame, once built, and whose page is open.
J.journal = nil
J.selected = nil

-- "map" while the map sheet lies on the book, else "timeline".
J.tab = "timeline"

-- The dungeon run laid out on the table over the book (UI/Dungeon/Spread.lua):
-- { id, guid } (the visit, and whose page it was opened from), or nil. Not
-- kept past putting it away, turning the book or closing it.
J.visit = nil

-- Writing mode: the right page shows the entry form (UI/Windows/Entry.lua) in
-- place of the note, story and timeline or map.
J.editing = false

-- The People list's query, kept across opens within a login. The sort is
-- saved too and read back when the page is built (UI/Journal/People.lua).
J.query = { search = "", sort = "lastMet" }

-- Which of the journal's pages is open: "journey", "people", "nearby" or
-- "settings", or the introduction in front of them all: "frontispiece",
-- then "front", the front matter. Each page registers itself
-- (J.RegisterPage, UI/Journal/Pages.lua): each but those two has a ribbon,
-- and everything on a page lives in that page's container. Its `leaf` is
-- where it lies in the book: Your Diary first (JRN-16), People next,
-- Recently nearby and the settings last (negative counts from the back).
J.view = "journey"

--------------------------------------------------------------------------
-- What the pages share in how they are built
--------------------------------------------------------------------------

-- Turns the book to the page `key` with the sound of a page turning: what
-- a link, a corner or a name does that leads to another page. (A ribbon
-- has its own, silent where its page is open already.)
function J.TurnTo(key)
    Style.PlaySound("pageTurn")
    ns.UI.SetJournalView(key)
end

-- A page's list (ns.UI.VirtualList) with the book's scrollbar colours
-- (Style.LIST_BAR): placed at the point `...` and `width` wide where given, in
-- that order, as each page did by hand before. A list that is placed by
-- its column (the settings) or its sheet (the link sheet) leaves them out.
function J.List(parent, rowHeight, numRows, build, update, width, ...)
    local list = ns.UI.VirtualList(parent, rowHeight, numRows, build, update)
    if select("#", ...) > 0 then list:SetPoint(...) end
    if width then list:SetWidth(width) end
    list:SetBarColors(Style.LIST_BAR[1], Style.LIST_BAR[2])
    return list
end

-- The entry of `list` ({ key, label } choices: a sort, a filter) whose key
-- is `key`, or nil.
function J.ByKey(list, key)
    for _, entry in ipairs(list) do
        if entry.key == key then return entry end
    end
end

-- How long the pencil keeps a stranger, in words: "7 days" (the
-- frontispiece, the front matter's contents, the empty People page).
function J.PencilDays()
    return ns.UI.Format.Count(ns.BufferDays(), "day", "days")
end

local RIBBON_W, RIBBON_GAP = 22, 8

-- The book grows with the diary: a page for each of its own (the ribbon
-- pages) and
-- one per entry between People and the back, up to BOOK_PAGES, with
-- FLYLEAVES blank ones at the back. Your Diary's own page is the first:
-- nothing lies under the left page there. The entries' pages are leafed
-- through in the order they are read: the first person opened lies on the
-- page after People's, the next on the one after that, and someone read
-- again turns back to their page. So the book moves forward a page at a
-- time instead of jumping between front and back. A closed book starts
-- over; once every page has been read, the rest share the last.
local BOOK_PAGES, FLYLEAVES = 25, 2

-- With the setting off (bookStack), a full even stack whatever is open.
local STILL_STACK = 6

-- Which page each entry read since the book opened lies on, the first
-- being 1, and how many have been given one.
local leaves, leafCount = {}, 0

-- The page `guid`'s entry lies on, given the next one the first time it is
-- read; nil for someone not in the diary.
-- People's `leaves` (UI/Journal/People.lua).
function J.EntryLeaf(guid)
    if not (guid and ns.Diary.Get(guid)) then return nil end
    if not leaves[guid] then
        leafCount = leafCount + 1
        leaves[guid] = leafCount
    end
    return leaves[guid]
end

-- Lays the stack beneath the open pages out for the page that is open:
-- what lies before it under the left page, what follows under the right.
-- A page with `leaves` opens on the leaf inside it it names: People on the
-- selected person's page, or on its own with nobody selected.
local function TurnStack()
    if not ns.Setting("bookStack") then
        J.journal:FitPages(J.journal.book:SetStack(STILL_STACK, STILL_STACK))
        return
    end
    local stacked, flyleaves = J.StackCounts()
    local entries = ns.Diary.Count()
    local pages = math.min(BOOK_PAGES, stacked + entries)
    local open = J.Page(J.view)
    -- The frontispiece is the first leaf and the front matter the second:
    -- the whole book lies under the right page, Your Diary's with it, and
    -- the flyleaves after the open one.
    if open.flyleaf then
        local turned = open.flyleaf
        J.journal:FitPages(J.journal.book:SetStack(turned, FLYLEAVES + pages + flyleaves - 1 - turned))
        return
    end
    local at = open.leaf > 0 and open.leaf or pages + 1 + open.leaf
    local leaf = open.leaves and open.leaves()
    if leaf then
        at = at + math.min(leaf, pages - stacked)
    end
    J.journal:FitPages(J.journal.book:SetStack(at - 1, FLYLEAVES + pages - at))
end

-- Shows one of the journal's pages, marks its ribbon and turns the stack
-- beneath to it. The pages that are not People read live data, so they are
-- brought up to date as they open.
local function ShowView()
    for _, spec in ipairs(J.PagesByKey()) do
        local key = spec.key
        J.journal.views[key]:SetShown(key == J.view)
        if J.journal.ribbons[key] then J.journal.ribbons[key]:SetActive(key == J.view) end
    end
    TurnStack()
    -- A run out on the table lies over a person's page (or Your Diary's,
    -- opened from its run page): another page puts it away.
    if J.visit and J.view ~= (J.visit.from == "journey" and "journey" or "people") then
        ns.UI.DungeonPage.Close(true)
    end
    local open = J.Page(J.view)
    if open.refresh then open.refresh() end
    -- Left before its end, the introduction asks to be gone back to
    -- (UI/Journal/IntroLabel.lua).
    J.RefreshIntroLabel()
end

local function Build()
    -- The cover is the frame: no dialog border, no title bar.
    local panel = ns.UI.Chrome.Panel("SocialDiaryJournalFrame", WIDTH, HEIGHT, nil, { bare = true, closeOutset = 8 })
    -- Below the entry dialog, which opens on top of it from the Edit button.
    panel:SetFrameStrata("HIGH")
    Style.Cover(panel, COVER, COVER + LEFT_PAGE)

    panel.book = Style.Book(panel, LEFT_PAGE, BOOK_W, BOOK_H)
    panel.book:SetPoint("TOPLEFT", COVER, -COVER)
    panel.book:SetPoint("BOTTOMRIGHT", -COVER, COVER)
    -- Closing the book ends writing mode; what was typed is kept.
    panel:HookScript("OnHide", function() J.EndEdit() end)

    ns.On("SD_PAPER_CHANGED", function()
        panel.book:ApplyPaper()
        panel.book:ApplyGrain()
    end)

    -- One container per page of the journal, each covering the whole book,
    -- made by key (UI/Journal/Pages.lua says why).
    panel.views = {}
    for _, spec in ipairs(J.PagesByKey()) do
        local container = CreateFrame("Frame", nil, panel.book)
        container:SetAllPoints(panel.book)
        panel.views[spec.key] = container
    end

    -- Each page builds itself into its container, in the book's build
    -- order (People's pieces first), which is not the ribbons'.
    for _, spec in ipairs(J.BuildOrder()) do
        spec.build(panel.views[spec.key], panel)
    end

    -- The ribbons, left to right in the pages' order, on the left page: they
    -- turn the journal's main pages, while the right page's index tabs
    -- belong to whatever page is open. Mirrors where the ornamental one
    -- hung on the right.
    panel.ribbons = {}
    local x = 112 - RIBBON_W
    for _, r in ipairs(J.Ribbons()) do
        -- A ribbon pulled turns the book to its page, with the sound of it:
        -- from the introduction too, which playtesters asked for.
        panel.ribbons[r.key] = Style.BookRibbon(panel.book, x, RIBBON_W, COVER, r.colour, r.label, function()
            if J.view ~= r.key then Style.PlaySound("pageTurn") end
            ns.UI.SetJournalView(r.key)
        end)
        x = x + RIBBON_W + RIBBON_GAP
    end

    return panel
end

--------------------------------------------------------------------------
-- Entry points (JNL-4)
--------------------------------------------------------------------------

-- Turns the right page to writing mode on `guid`. False when the journal is
-- closed, so the caller opens the loose sheet instead.
function J.Edit(guid, focusNote)
    if not J.journal or not J.journal:IsShown() then return false end
    J.selected = ns.SafeGUID(guid)
    J.editing = true
    J.view = "people"
    ShowView()
    J.journal.people:Refresh()
    J.RefreshProfile()
    if focusNote then J.journal.profile.form.note:SetFocus() end
    return true
end

-- Back from writing mode to the page.
function J.EndEdit()
    if not J.editing then return end
    J.journal.profile.form:Commit()
    J.editing = false
    J.RefreshProfile()
end

function ns.UI.SelectPerson(guid)
    if J.editing then J.EndEdit() end
    J.selected = ns.SafeGUID(guid)
    if not J.journal then return end
    TurnStack()
    J.journal.people:Refresh()
    J.RefreshProfile()
end

-- Turns to one of the journal's pages: "frontispiece", "front", "journey",
-- "people", "nearby" or "settings".
function ns.UI.SetJournalView(key)
    if not J.Page(key) then return end
    if key ~= "people" and J.editing then J.EndEdit() end
    J.view = key
    if not J.journal then return end
    ShowView()

    -- The Recently nearby page adds people; the list has to know. Diary.Add
    -- moved the data version, so the list's query sees them.
    if key == "people" then
        J.RefreshList(true)
        J.RefreshProfile()
    end
end

-- After the bookStack setting changed.
function J.TurnStack()
    if J.journal then TurnStack() end
end

function ns.UI.JournalView()
    return J.view
end

-- Whether the journal is open, and with `key`, on that page. Every refresh
-- below asks this first: a closed book is brought up to date when it opens
-- (ShowJournal), so repainting it in the meantime is wasted work.
function ns.UI.JournalShowing(key)
    if not J.journal or not J.journal:IsShown() then return false end
    return key == nil or J.view == key
end

-- After anything that may have changed what the journal shows: on
-- SD_DIARY_CHANGED, or called directly. It re-queries the People index, which
-- has already noticed the write (ns.Touch), so it is for edits, not for
-- keystrokes.
--
-- The loose entry sheet follows the same edits, journal open or not: an
-- entry edited on the journal's page, or deleted by /sd testdata remove,
-- would otherwise stay on the sheet as it was.
function ns.UI.RefreshJournal()
    ns.UI.Entry.Refresh()
    if not ns.UI.JournalShowing() then return end
    TurnStack()
    J.RefreshList(true)
    J.RefreshProfile()
end
ns.On("SD_DIARY_CHANGED", function() ns.UI.RefreshJournal() end)

-- The timeline alone, where it scrolled to: an episode opened or folded.
function ns.UI.RefreshTimeline()
    if not ns.UI.JournalShowing() or not J.selected or J.editing or J.tab ~= "timeline" then return end
    J.RefreshTimelineList()
end

-- Opened on nobody in particular before the front matter has been read
-- (PRV-4), it opens on the introduction, at the frontispiece; after, on whichever page was open last, Your
-- Diary to begin with (JRN-16). Opened on someone, it opens on them: the
-- slip keeps asking for the front matter until it has been read.
function ns.UI.ShowJournal(guid)
    J.journal = J.journal or Build()
    -- A book opened afresh is leafed through from the start again.
    if not J.journal:IsShown() then leaves, leafCount = {}, 0 end
    if guid then
        J.selected = ns.SafeGUID(guid)
        J.view = "people"
    elseif not ns.Setting("frontRead") then
        J.view = "frontispiece"
    end

    -- Shown before the page is chosen: the Recently nearby page only
    -- refreshes into an open book.
    J.journal:Show()
    J.journal:Raise()
    ShowView()

    -- People.Index rebuilds by itself when the data moved on (ns.Touch), so
    -- opening an unchanged diary twice builds it once.
    J.RefreshList()
    J.RefreshProfile()
end

-- The book, built if it was not yet, without opening it: for the settings
-- page's accessor (UI/Settings/Page.lua), which tests reach for closed.
function ns.UI.JournalFrame()
    J.journal = J.journal or Build()
    return J.journal
end

function ns.UI.CloseJournal()
    if J.journal then J.journal:Hide() end
end

function ns.UI.ToggleJournal()
    if J.journal and J.journal:IsShown() then
        ns.UI.CloseJournal()
    else
        ns.UI.ShowJournal()
    end
end
