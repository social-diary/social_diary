-- Settings (PRV-2, PRV-3, DAT-3): the journal's grey ribbon.
--
-- A page of the book like the others, in two panes: the left page lists the
-- sections (Recording, Interface, Sounds, Integrations, Memory, About),
-- with Interface's subpages (Toasts, Keybinds & Shortcuts, Dungeons and
-- Raids, Language) hung under it, always listed, and About's (Feedback, Changelog,
-- Credits) hung under About only while About is open, and the right page
-- shows the chosen one's settings. Written in the same ink as the
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
--   UI/Settings/Pad.lua        the page with the pad
--   UI/Kit/Confirm.lua         the questions asked before deleting
--
-- What they share is on the module (ns.UI.Settings):
--   .page                the page's frame once the book has built it (nil
--                        before): .controls (each refreshed with the page),
--                        .dependents ({ control, on }), .panes (by section
--                        key; none for a section without a build, About),
--                        .nav and .brackets (the left page's rows and the
--                        brackets subpages hang off), .navBottom (where
--                        the rows end as they lie now), and every control
--                        the tests read by name
--   .LayoutNav()         the left page's rows placed again as they stand
--                        (run with every refresh)
--   .ChangelogLines(releases)  the Changelog's lines (Sections/Changelog.lua)
--   .Kit, .Quiet, .Macro the siblings above
--   .SizeText, .SizeWarning, .DataText  Memory's lines, read again here
-- A section refreshes the page through ns.UI.Settings.Refresh.

local addonName, ns = ...

local Style = ns.Style
local L = ns.L
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
--                           and beside its pane's title. Optional: a row
--                           without it is its name alone, a section row
--                           as tall as one line needs (About's)
--       parent = "interface",  optional: a subpage of that section, its row
--                           smaller and hung off a bracket under it. Its
--                           order puts it after its section's, before the
--                           next section's.
--       collapsed = true,   optional, on a section with subpages: their rows
--                           are listed only while it or one of them is open
--                           (About's), and the rows under them move up
--                           while they are not. Without it they are always
--                           listed (Interface's)
--       build = function(pane, c),  fills its pane on the right page: the
--                           frame, and the column under its heading.
--                           Optional on a section with subpages: without
--                           it the section has no pane, and turning to it
--                           opens its first subpage (About opens Feedback)
--       open = function(),  optional: run each time it is turned to (the
--                           Changelog counts as read)
--   })
--
-- A subpage is a section like the others, with its own pane, and only its
-- row on the left is smaller. Sections register as their files load
-- (UI/Settings/Sections/, each registration under its builder, the files
-- in the TOC in the sections' order), before the book is made; the page is built once, so one registered or removed after
-- that is refused.
local sections = ns.Registry.New({
    what = "Settings.RegisterSection(key, { order, label, about?, parent?, collapsed?, build?, open? })",
    order = "order",
    default = 100,
    check = function(key, spec)
        return type(spec.label) == "string" and (spec.about == nil or type(spec.about) == "string")
            and (spec.build == nil or type(spec.build) == "function")
            and (spec.open == nil or type(spec.open) == "function")
            and (spec.parent == nil or type(spec.parent) == "string")
            -- (a section without a pane opens a subpage: never a subpage itself)
            and (spec.build ~= nil or spec.parent == nil)
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
-- it covers), a section's row with its name alone (NAV_PLAIN: one line of
-- the body face and the room round it a section's row has), a subpage's
-- (its name alone), how far in a subpage hangs, and
-- the ink bracket it hangs off: how far in from the section's row, the
-- foot's length, and its ink, darker while one of its subpages is open.
-- SUB_AFTER is the room left under the last subpage, so the next section
-- stands clear of the group.
-- (NAV_ROW 40 and SUB_ROW 22, from 42 and 24, since Language joined
-- Interface's subpages: with About's group open the rows have to end above
-- the introduction's link, tests/settings_about.lua.)
local NAV_TOP, NAV_ROW, NAV_PLAIN, SUB_ROW, SUB_INDENT, SUB_AFTER = 58, 40, 28, 22, 18, 6
local BRACKET = { x = 10, foot = 6, ink = 0.30, open = 0.65 }

-- The open section, kept across opens within a login: the first listed to
-- begin with, once the page is built.
local section

-- The section a key names, or nil.
local function Find(key)
    return key and sections:Get(key)
end

-- The section turning to `key` shows: itself, or, for a section without a
-- pane of its own, its first subpage. Nil where there is none.
local function Target(key)
    local s = Find(key)
    if not s then return nil end
    if s.build then return key end
    for _, sub in ipairs(sections:Ordered()) do
        if sub.parent == key and sub.build then return sub.key end
    end
end

-- Whether a section's row is listed: a section's always, a subpage's
-- unless its section is collapsed and neither it nor one of its subpages
-- is open.
local function Listed(s)
    if not s.parent then return true end
    local group = Find(s.parent)
    if not (group and group.collapsed) then return true end
    local open = Find(section)
    return section == s.parent or (open and open.parent) == s.parent
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
        local pane = page.panes[s.key]
        if pane then pane:SetShown(isOpen) end
        row.selected:SetShown(isOpen)
        row.label:SetFontObject((isOpen or s.key == parent) and FONT.strong or FONT.body)
    end
    SettingsUI.LayoutNav()
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

-- Turns to one of the sections by key, a subpage's included (a section
-- without a pane: its first subpage), and tells it it was turned to.
local function ShowSection(key)
    key = Target(key)
    if not key then return end
    section = key
    RefreshPage(true)
    local s = Find(key)
    if s.open then s.open() end
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
-- darkens it while one of its subpages is open. Made with a foot for each
-- of its `n` subpages; Place(x, top, feet) lays it from `top` down to the
-- last of `feet`, as the rows stand now, and SetShown hides it with a
-- collapsed group's rows.
local function Bracket(parent, n)
    local INK = Style.INK
    local bracket = { pieces = {} }
    for i = 1, n + 1 do
        bracket.pieces[i] = parent:CreateTexture(nil, "ARTWORK")
    end

    function bracket:Place(x, top, feet)
        local spine = self.pieces[1]
        spine:ClearAllPoints()
        spine:SetSize(1, feet[#feet] - top + 1)
        spine:SetPoint("TOPLEFT", x, -top)
        for i, y in ipairs(feet) do
            local foot = self.pieces[i + 1]
            foot:ClearAllPoints()
            foot:SetSize(BRACKET.foot, 1)
            foot:SetPoint("TOPLEFT", x + 1, -y)
        end
    end

    function bracket:SetShown(shown)
        for _, piece in ipairs(self.pieces) do piece:SetShown(shown) end
    end

    function bracket:SetInk(open)
        for _, piece in ipairs(self.pieces) do
            piece:SetColorTexture(INK[1], INK[2], INK[3], open and BRACKET.open or BRACKET.ink)
        end
    end
    bracket:SetInk(false)
    return bracket
end

-- The rows placed down the left page as they stand: a collapsed group's
-- subpages hidden and the rows under them moved up, each bracket from the
-- foot of its section's row down to its last subpage listed.
function SettingsUI.LayoutNav()
    if not (page and page.nav) then return end
    local x, y = BOOK.LEFT_X - 6, NAV_TOP
    local feet, bottoms, afterSub = {}, {}, false
    for _, s in ipairs(sections:Ordered()) do
        local row = page.nav[s.key]
        local listed = Listed(s)
        row:SetShown(listed)
        if listed then
            local sub = s.parent ~= nil
            if not sub and afterSub then y = y + SUB_AFTER end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", x + row.indent, -y)
            if sub then
                feet[s.parent] = feet[s.parent] or {}
                table.insert(feet[s.parent], y + row.height / 2)
            end
            bottoms[s.key] = y + row.height
            y = y + row.height + 2
            afterSub = sub
        end
    end
    page.navBottom = y
    for key, bracket in pairs(page.brackets) do
        local ys = feet[key]
        bracket:SetShown(ys ~= nil and bottoms[key] ~= nil)
        if ys and bottoms[key] then bracket:Place(x + BRACKET.x, bottoms[key], ys) end
    end
end

-- Sections in full (the name, and what it covers in small print under it);
-- subpages smaller, the name alone, indented under their section. Made
-- once; placed by LayoutNav, again on every refresh, since a collapsed
-- group's rows come and go.
local function BuildNav(parent)
    page.version, page.heading = ns.UI.Journal.PageHeading(parent, L["Settings"])
    page.nav, page.brackets = {}, {}

    local subs = {}
    for _, s in ipairs(sections:Ordered()) do
        local sub = s.parent ~= nil
        local plain = not sub and s.about == nil
        local row = Style.GroupedRow(parent, function(row)
            row.label = Style.Text(row, FONT.body)
            if sub or plain then
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
        row.height = sub and SUB_ROW or plain and NAV_PLAIN or NAV_ROW
        row.indent = sub and SUB_INDENT or 0
        row:SetSize(BOOK.LEFT_W + 12 - row.indent, row.height)
        row:SetHeading(s)
        row.label:SetText(s.label)
        if row.about then row.about:SetText(s.about) end
        row:SetScript("OnClick", function() ShowSection(s.key) end)
        page.nav[s.key] = row
        if sub then subs[s.parent] = (subs[s.parent] or 0) + 1 end
    end
    for key, n in pairs(subs) do page.brackets[key] = Bracket(parent, n) end
    SettingsUI.LayoutNav()

    -- The way back to the introduction (its tour on a loose sheet over Your
    -- Diary, UI/Windows/Intro/Tour.lua), at the foot of the page, clear of
    -- the ribbons.
    page.intro = Style.Link(parent, FONT.body, function()
        Style.PlaySound("pageTurn")
        ns.UI.ShowIntro()
    end)
    page.intro:SetText(L["Show the introduction again"])
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
    section = Target(section) or Target(list[1] and list[1].key)
    BuildNav(parent)
    for _, s in ipairs(list) do
        if s.build then
            local pane, c = SettingsUI.Kit.Pane(s)
            s.build(pane, c)
        end
    end
    function page:Refresh() RefreshPage(true) end
    function page:ShowSection(key) ShowSection(key) end
    function page:Section() return section end
    return page
end

-- The grey ribbon's page, the book's last (UI/Journal/Pages.lua).
ns.UI.Journal.RegisterPage("settings", {
    order = 40, ribbon = { colour = "gray", label = L["Settings"] }, leaf = -1, buildOrder = 60,
    build = function(container) BuildPage(container) end,
    refresh = function() SettingsUI.Refresh() end,
    title = function() return page and page.heading end,
})

--------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------

-- `key`, if given, is the section or subpage to open on (a section without
-- a pane: its first subpage); else the one open last this login.
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
