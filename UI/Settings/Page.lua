-- Settings (PRV-2, PRV-3, DAT-3): the journal's grey ribbon.
--
-- A page of the book like the others, in two panes: the left page lists the
-- sections (Recording, Interface, Sounds, Integrations, Memory, Feedback,
-- About), with Interface's
-- two subpages (Toasts, Keybinds & Shortcuts) hung under it, and the right
-- page shows the chosen one's settings. Written in the same ink as the
-- rest of the book: boxes to tick, numbers on a line and ruled scales
-- (Style.Checkbox, Style.NumberField, Style.Slider) rather than Blizzard's
-- controls.
--
-- Blizzard's AddOns settings keep a small page that sends you here, since
-- that is where players look first (UI/Blizzard/Signpost.lua).
--
-- What PRV-2 lists that is not here yet: the city list and the sighting
-- sources, which sightings (M2) keep in slash commands for now (/sd sightings
-- city, /sd sightings on|off), and the post-session note prompt, which
-- arrives with SES-8 (M3).
--
-- This file is the page: the sections' registry, the left page's list,
-- turning between panes, and the entry points. Its siblings:
--   UI/Settings/Kit.lua        the column and controls a section lays out
--                              with (ns.UI.Settings.Kit)
--   UI/Settings/Quiet.lua      the quiet-nearby list (ns.UI.Settings.Quiet)
--   UI/Settings/Macro.lua      the two macros and their books
--   UI/Settings/Sections/      one file per section, each registering itself
--   UI/Kit/Confirm.lua         the questions asked before deleting
--
-- What they share is on the module (ns.UI.Settings):
--   .page                the page's frame once the book has built it (nil
--                        before): .controls (each refreshed with the page),
--                        .dependents ({ control, on }), .panes (by section
--                        key), and every control the tests read by name
--   .Kit, .Quiet, .Macro the siblings above
--   .SizeText, .SizeWarning, .DataText  Memory's lines, read again here
-- A section refreshes the page through ns.UI.Settings.Refresh.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK

local page

-- The settings module (ns.UI.Settings): its sections' registry, and what
-- the settings' files share (above). Not called Settings here: that is
-- Blizzard's settings API (UI/Blizzard/Signpost.lua).
local SettingsUI = {}
ns.UI.Settings = SettingsUI

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------
--
-- Two panes, as the book's other pages: the left page lists the sections,
-- the right page shows the chosen one's settings under its name.

-- The sections, in the order the left page lists them (.claude/
-- ui-refactor-plan.md, decision 5 and 2c):
--
--   Settings.RegisterSection(key, {
--       order = 10,         where its row stands on the left page; gaps
--       label = "Recording", its name, on its row and over its pane
--       about = "...",      what it covers, in small print under the name
--       parent = "interface",  optional: a subpage of that section, its row
--                           smaller and hung off a bracket under it. Its
--                           order puts it after its section's, before the
--                           next section's.
--       build = function(pane, c),  fills its pane on the right page: the
--                           frame, and the column under its heading
--   })
--
-- A subpage is a section like the others, with its own pane, and only its
-- row on the left is smaller. Sections register as their files load
-- (UI/Settings/Sections/, each registration under its builder, the files
-- in the TOC in the sections' order), before the book is made; the page is built once, so one registered or removed after
-- that is refused.
local sections = ns.Registry.New({
    what = "Settings.RegisterSection(key, { order, label, about, parent, build })",
    order = "order",
    default = 100,
    check = function(key, spec)
        return type(spec.label) == "string" and type(spec.about) == "string" and type(spec.build) == "function"
            and (spec.parent == nil or type(spec.parent) == "string")
    end,
})

function SettingsUI.RegisterSection(key, spec)
    assert(not page, "Settings.RegisterSection: the settings page is already built")
    return sections:Add(key, spec)
end

-- Takes a section out again (the tests' own sections).
function SettingsUI.RemoveSection(key)
    assert(not page, "Settings.RemoveSection: the settings page is already built")
    return sections:Remove(key)
end

-- The sections in the order the left page lists them.
function SettingsUI.Sections()
    return sections:Ordered()
end

-- The left page: where the rows start, a section's row (its name and what
-- it covers), a subpage's (its name alone), how far in a subpage hangs, and
-- the ink bracket it hangs off: how far in from the section's row, the
-- foot's length, and its ink, darker while one of its subpages is open.
-- SUB_AFTER is the room left under the last subpage, so the next section
-- stands clear of the group.
local NAV_TOP, NAV_ROW, SUB_ROW, SUB_INDENT, SUB_AFTER = 58, 42, 24, 18, 6
local BRACKET = { x = 10, foot = 6, ink = 0.30, open = 0.65 }

-- The open section, kept across opens within a login: the first listed to
-- begin with, once the page is built.
local section

-- The section a key names, or nil.
local function Find(key)
    return key and sections:Get(key)
end

-- Everything the page shows, read again: which section is open, the
-- switches, the numbers, which of them are available, the quiet list and
-- the size. The closed sections too, so none is stale when it opens.
-- A subpage open is shaded on the left like a section; its section's name
-- goes dark with it, unshaded, and so does the bracket it hangs off.
local function RefreshPage(keepScroll)
    if not page then return end
    page.version:SetText("v" .. ns.version)
    local open = Find(section)
    local parent = open and open.parent
    for _, s in ipairs(sections:Ordered()) do
        local row = page.nav[s.key]
        local isOpen = s.key == section
        page.panes[s.key]:SetShown(isOpen)
        row.selected:SetShown(isOpen)
        row.label:SetFontObject((isOpen or s.key == parent) and FONT.strong or FONT.body)
    end
    for key, bracket in pairs(page.brackets) do
        bracket:SetInk(key == parent)
    end
    for _, control in ipairs(page.controls) do control:Refresh() end
    for _, dependent in ipairs(page.dependents) do
        dependent.control:SetAvailable(dependent.on())
    end
    local bytes = ns.EstimateSize()
    page.size:SetText(SettingsUI.SizeText(bytes))
    page.sizeWarning:SetText(SettingsUI.SizeWarning(bytes))
    page.dataHint:SetText(SettingsUI.DataText())
    SettingsUI.Quiet.Refresh(keepScroll)
end

function SettingsUI.Refresh()
    RefreshPage(true)
end

-- Turns to one of the sections by key, a subpage's included.
local function ShowSection(key)
    if not Find(key) then return end
    section = key
    RefreshPage(true)
end

-- Removing or forgetting someone changes the quiet list and the size.
ns.On("SD_DIARY_CHANGED", function()
    if ns.UI.JournalShowing("settings") then RefreshPage(true) end
end)

--------------------------------------------------------------------------
-- Left page: the sections
--------------------------------------------------------------------------

-- A section's subpages hang off an ink bracket, as an episode's rows do on
-- the timeline: down the margin from the foot of the section's row, under
-- its name, with a short foot out to each subpage. Drawn on the page, left
-- of the rows, so a subpage's shading never covers it. SetInk(open)
-- darkens it while one of its subpages is open.
local function Bracket(parent, x, top, feet)
    local INK = Style.INK
    local bracket = { pieces = {} }
    local function Piece(px, py, w, h)
        local piece = parent:CreateTexture(nil, "ARTWORK")
        piece:SetSize(w, h)
        piece:SetPoint("TOPLEFT", px, -py)
        bracket.pieces[#bracket.pieces + 1] = piece
    end
    Piece(x, top, 1, feet[#feet] - top + 1)
    for _, y in ipairs(feet) do Piece(x + 1, y, BRACKET.foot, 1) end

    function bracket:SetInk(open)
        for _, piece in ipairs(self.pieces) do
            piece:SetColorTexture(INK[1], INK[2], INK[3], open and BRACKET.open or BRACKET.ink)
        end
    end
    bracket:SetInk(false)
    return bracket
end

-- Sections in full (the name, and what it covers in small print under it);
-- subpages smaller, the name alone, indented under their section.
local function BuildNav(parent)
    page.version = ns.UI.Journal.PageHeading(parent, "Settings")
    page.nav, page.brackets = {}, {}

    local x, y = BOOK.LEFT_X - 6, NAV_TOP
    local feet, bottoms = {}, {}
    local list = sections:Ordered()
    for i, s in ipairs(list) do
        local sub = s.parent ~= nil
        if not sub and i > 1 and list[i - 1].parent then y = y + SUB_AFTER end
        local row = Style.GroupedRow(parent, function(row)
            row.label = Style.Text(row, FONT.body)
            if sub then
                row.label:SetPoint("LEFT", 8, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.label:SetWordWrap(false)
                return { row.label }
            end
            row.label:SetPoint("TOPLEFT", 8, -6)
            row.about = Style.Text(row, FONT.small)
            row.about:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
            row.about:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.about:SetWordWrap(false)
            return { row.label, row.about }
        end)
        local height = sub and SUB_ROW or NAV_ROW
        local indent = sub and SUB_INDENT or 0
        row:SetSize(BOOK.LEFT_W + 12 - indent, height)
        row:SetPoint("TOPLEFT", x + indent, -y)
        row:SetHeading(s)
        row.label:SetText(s.label)
        if row.about then row.about:SetText(s.about) end
        row:SetScript("OnClick", function() ShowSection(s.key) end)
        page.nav[s.key] = row

        if sub then
            feet[s.parent] = feet[s.parent] or {}
            table.insert(feet[s.parent], y + height / 2)
        end
        bottoms[s.key] = y + height
        y = y + height + 2
    end
    page.navBottom = y

    -- From the foot of the section's row down to its last subpage.
    for key, ys in pairs(feet) do
        page.brackets[key] = Bracket(parent, x + BRACKET.x, bottoms[key], ys)
    end

    -- The way back to the introduction (its tour on a loose sheet over Your
    -- Diary, UI/Windows/Intro/Tour.lua), at the foot of the page, clear of
    -- the ribbons.
    page.intro = Style.Link(parent, FONT.body, function()
        Style.PlaySound("pageTurn")
        ns.UI.ShowIntro()
    end)
    page.intro:SetText("Show the introduction again")
    page.intro:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", BOOK.LEFT_X + BOOK.LEFT_W, -BOOK.BOOK_H + 22)
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

-- Built by the book as it is made (UI/Journal/Book.lua), into the grey
-- ribbon's container: the sections on the left, a pane for each on the
-- right, in the order they are listed.
local function BuildPage(parent)
    page = parent
    SettingsUI.page = parent
    page.controls, page.dependents, page.panes = {}, {}, {}
    local list = sections:Ordered()
    section = section or (list[1] and list[1].key)
    BuildNav(parent)
    for _, s in ipairs(list) do
        local pane, c = SettingsUI.Kit.Pane(s)
        s.build(pane, c)
    end
    function page:Refresh() RefreshPage(true) end
    function page:ShowSection(key) ShowSection(key) end
    function page:Section() return section end
    return page
end

-- The grey ribbon's page, the book's last (UI/Journal/Pages.lua).
ns.UI.Journal.RegisterPage("settings", {
    order = 40, ribbon = { colour = "gray", label = "Settings" }, leaf = -1, buildOrder = 60,
    build = function(container) BuildPage(container) end,
    refresh = function() SettingsUI.Refresh() end,
})

--------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------

-- `key`, if given, is the section or subpage to open on; else the one
-- open last this login.
function ns.UI.ShowSettings(key)
    ns.UI.ShowJournal()
    ns.UI.SetJournalView("settings")
    if key and page then ShowSection(key) end
end

-- Test hook: the page, built with the book if it was not yet and brought
-- up to date, open or not.
function ns.UI.SettingsPage()
    ns.UI.JournalFrame()
    RefreshPage(true)
    return page
end
