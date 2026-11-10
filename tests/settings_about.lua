-- Settings: About (UI/Settings/Sections/About.lua), a collapsed group with
-- no page of its own: Feedback, Changelog and Credits hung under it only
-- while one of them is open. The Changelog (UI/Settings/Sections/
-- Changelog.lua): ns.Changelog's releases newest first, a rubric divider
-- between each two, a thanks under its entry, a smooth list the wheel and
-- the pad scroll; reading it counts as the update told of. Interface's
-- switch for the update's notice (showUpdateHint). And all of it with the
-- pad.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Style = ns.Style
local Pad = ns.UI.Pad
local SettingsUI = ns.UI.Settings
local BOOK = ns.UI.Journal.BOOK

-- Releases of the test's own, before the page is built: enough to scroll,
-- a feature named in italics, and two thanks (an entry's and a sub-entry's).
local function Release(version, n)
    local entries = {}
    for i = 1, n do entries[i] = { text = ("Entry %d of %s in _Your Diary_"):format(i, version) } end
    return { version = version, summary = "A summary naming the _Dungeon View_.",
        groups = { { heading = "Shiny new Things", entries = entries },
                   { heading = "Fixes", entries = { { text = "A fix" } } } } }
end
local releases = { Release("3.0.0", 10), Release("2.9.0", 10), Release("2.8.0", 10) }
releases[1].groups[2].entries[1].thanks = "Tabi Lorang"
releases[2].groups[1].entries[1].sub = { { text = "A sub-entry", thanks = "Koko Skybluff" } }
ns.Changelog = releases

mock.RunTimers()
local P = ns.UI.SettingsPage()
local SUBS = { "feedback", "changelog", "credits" }

local function Listed(key) return P.nav[key]:IsShown() end
local function NavY(key) return -P.nav[key].recorded.points[1].args[2] end
local function Font(row) return row.label.recorded.calls.SetFontObject[1] end

--------------------------------------------------------------------------
Section("About: collapsed until it or one of its subpages is open")

P:ShowSection("recording")
for _, key in ipairs(SUBS) do
    Check(not Listed(key), key .. " is listed with About closed")
    Eq(P.nav[key].label:GetText() ~= nil, true, key .. "'s row has no name")
end
Check(Listed("about"), "About's row is not listed")
Eq(P.nav.about.about, nil, "About's row carries small print")
Eq(P.nav.about.label:GetText(), "About", "About's row's name")
Eq(P.panes.about, nil, "About has a page of its own")
Check(P.brackets.about ~= nil, "About's subpages hang off no bracket")
Check(not P.brackets.about.pieces[1]:IsShown(), "About's bracket drawn with the group collapsed")
Check(P.brackets.interface.pieces[1]:IsShown(), "Interface's bracket hidden: it never collapses")
for _, key in ipairs({ "toasts", "shortcuts", "dungeons" }) do
    Check(Listed(key), "Interface's subpage " .. key .. " collapsed")
end
local short = P.navBottom

-- Clicking About opens its first subpage, and lists the group under it.
P.nav.about:Click()
Eq(P:Section(), "feedback", "About did not open Feedback")
for i, key in ipairs(SUBS) do
    Check(Listed(key), key .. " is not listed with About open")
    Check(NavY(key) > NavY(i == 1 and "about" or SUBS[i - 1]), key .. " is not placed under the one before")
end
Check(P.brackets.about.pieces[1]:IsShown(), "About's bracket not drawn with the group open")
Eq(Font(P.nav.about), Style.FONT.strong, "About's name is not dark with a subpage open")
Check(P.navBottom > short, "the rows below did not make room for the group")
Check(P.navBottom < BOOK.BOOK_H - 22 - 18 - 8,
    ("the open group runs down to %d, into the introduction's link"):format(P.navBottom))

-- Each subpage keeps the group open; another section closes it again.
P.nav.credits:Click()
Eq(P:Section(), "credits", "Credits did not open")
Check(Listed("feedback") and Listed("changelog"), "the group closed on Credits")
P.nav.memory:Click()
for _, key in ipairs(SUBS) do Check(not Listed(key), key .. " still listed after leaving About") end
Eq(P.navBottom, short, "the rows did not move back up")
Eq(Font(P.nav.about), Style.FONT.body, "About's name still dark")

-- ShowSettings to a subpage opens the group too (the update's notice).
ns.UI.ShowSettings("changelog")
Eq(P:Section(), "changelog", "ShowSettings did not open the Changelog")
Check(Listed("changelog") and Listed("credits"), "the group not listed for the Changelog")
Eq(P.panes.changelog.about:GetText() or "", "", "the Changelog has small print beside its title (the pages have none)")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("the Changelog: releases newest first, dividers, thanks")

local lines = P.changelog.data
local kinds = {}
for _, line in ipairs(lines) do kinds[line.kind] = (kinds[line.kind] or 0) + 1 end
Eq(kinds.version, #ns.Changelog, "a version heading per release")
Eq(kinds.divider, #ns.Changelog - 1, "a divider between each two releases")
Eq(lines[1].text, "Version 3.0.0", "the newest release first")
Eq(lines[#lines].kind, "footer", "the footer is not last")
Eq(lines[#lines].text, "The full history is on CurseForge and GitHub.", "the footer's words")
for i, line in ipairs(lines) do
    if line.kind == "divider" then
        Eq(lines[i + 1].kind, "version", "a divider not followed by a release")
    end
    if line.text then Check(not line.text:find("_"), "underscores left in: " .. line.text) end
end
Check(lines[2].text:find("|cff" .. Style.HEX.strong .. "Dungeon View|r", 1, true) ~= nil,
    "a feature's name not set in the strong ink: " .. tostring(lines[2].text))
Eq(lines[3].kind, "group", "the group heading after the summary")
Eq(lines[3].text, "SHINY NEW THINGS", "the group heading's words")

-- The real changelog, as the data gives it: the same shape.
local real = SettingsUI.ChangelogLines(ns.Changelog)
Check(#real > 0, "no lines for the changelog")

-- A thanks under its entry, on the entry's own row; a sub-entry's too.
local thanked, sub
for i, line in ipairs(lines) do
    if line.thanks and line.kind == "entry" then thanked = i end
    if line.thanks and line.kind == "sub" then sub = i end
end
Check(thanked and sub, "no thanks among the lines")
Eq(lines[thanked].thanks, "Thanks to Tabi Lorang", "the thanks' words")
Eq(lines[sub].thanks, "Thanks to Koko Skybluff", "a sub-entry's thanks")
P.changelog:Reveal(thanked)
local row = P.changelog:RowOf(thanked)
Check(row ~= nil, "the thanked entry not in view once revealed")
Eq(row.thanks:GetText(), "Thanks to Tabi Lorang", "the thanks not on its entry's row")
Check(row.thanks:IsShown() and row.bullet:IsShown(), "the thanks or the entry's lozenge hidden")
Check(lines[thanked].height > lines[thanked - 1].height, "the thanked entry not given room for its thanks")

-- The divider: a rule in rubric across the row.
local at
for i, line in ipairs(lines) do if line.kind == "divider" then at = i break end end
P.changelog:Reveal(at)
local div = P.changelog:RowOf(at)
Check(div.divider:IsShown() and not div.text:IsShown(), "the divider's row shows words, or no rule")
local colour = div.divider.recorded.calls.SetColorTexture
Eq(colour[1], Style.RUBRIC[1], "the divider is not in rubric")
local anchors = {}
for _, p in ipairs(div.divider.recorded.points) do anchors[p.point] = true end
Check(anchors.TOPLEFT and anchors.TOPRIGHT, "the divider does not run the column's width")

-- A group's heading is rubricated: red capitals a size up, a paraph in the
-- gutter (red, then lapis on the release's second group) and a rule after.
P.changelog:Reveal(3)
local head = P.changelog:RowOf(3)
Eq(head.text.recorded.calls.SetFontObject[1], Style.FONT.headingRubricLarge, "a group's heading not in rubric")
Check(head.bullet:IsShown() and head.rule:IsShown(), "a group's heading without its paraph or rule")
Eq(head.bullet.recorded.calls.SetColorTexture[1], Style.RUBRIC[1], "the first group's paraph not red")
local second
for i = 4, #lines do if lines[i].kind == "group" then second = i break end end
Check(lines[second].lapis and not lines[3].lapis, "the paraphs not red and lapis by turns")
-- (the rule starts after the words, inside the column)
local rulePoint = head.rule.recorded.points[1].args
Eq(rulePoint[1], head, "the group's rule not placed on its row")
Check(rulePoint[3] > head.text:GetStringWidth() and rulePoint[3] < P.changelog:GetWidth(),
    "the group's rule not after its words, inside the column")
-- The hanging column: a heading's words on the entries' indent, its paraph
-- over their lozenges; the version and the summary at the margin.
local function TextX(i)
    P.changelog:Reveal(i)
    return P.changelog:RowOf(i).text.recorded.points[1].args[1]
end
Eq(TextX(3), TextX(4), "the group's words and its entries' not on one indent")
Check(TextX(1) < TextX(3) and TextX(2) < TextX(3), "the release's head not at the margin")
-- The rhythm: between releases > before a group > between entries.
local entryA, entryB
for i = 1, #lines - 1 do
    if lines[i].kind == "entry" and lines[i + 1].kind == "entry" and not lines[i].thanks then
        entryA, entryB = i, i + 1 break
    end
end
Check(entryA ~= nil, "no two entries in a row")
Check(lines[at].height > lines[3].height - 14 and lines[3].height - 14 > lines[entryA].height - 14,
    "the spacing does not step down: release, group, entry")

-- The wheel scrolls it.
P.changelog:SetPosition(0)
P.changelog.Wheel(nil, -1)
Check(P.changelog.pos > 0, "the wheel did not scroll the changelog")

--------------------------------------------------------------------------
Section("opening the Changelog counts as the update read")

local S = ns.HintState()
S.version, S.update = nil, nil
ns.Hints.Installed("2.4.0")
ns.Hints.Installed("3.0.0")
Eq(ns.Hints.Update(), "3.0.0", "the major update not kept to tell")
P:ShowSection("memory")
P.nav.about:Click()
Eq(ns.Hints.Update(), "3.0.0", "Feedback counted as reading the Changelog")
P.nav.changelog:Click()
Eq(ns.Hints.Update(), nil, "opening the Changelog did not count as read")
Eq(P.changelog.pos, 0, "the Changelog did not open at its top")

--------------------------------------------------------------------------
Section("Interface: the switch for the update's notice")

Eq(P.showUpdateHint.parent, P.panes.interface, "the switch is not on Interface")
Check(P.showUpdateHint.label:GetText():find("Show a hint after a big update", 1, true), "the switch's words")
local was = ns.Setting("showUpdateHint")
P.showUpdateHint:Click("LeftButton")
Eq(ns.Setting("showUpdateHint"), not was, "the switch did not write showUpdateHint")
-- (not under Show hints: it stays available with them off)
ns.SetSetting("showHints", false)
P:Refresh()
Check(not P.showUpdateHint.unavailable, "the update's switch faded with Show hints off")
ns.SetSetting("showHints", true)
P.showUpdateHint:Click("LeftButton")
Eq(ns.Setting("showUpdateHint"), was, "the switch did not write it back")

--------------------------------------------------------------------------
Section("with the pad: the group, the Changelog read down, the switch")

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local book = ns.UI.JournalFrame()
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(P)
P:ShowSection("memory")
P:Refresh()

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Prompt()
    local first = Pad.Top().legend(Pad.Top())[1]
    return first and first[2]
end

Pad.Refresh()
Eq(At().key, "nav:memory", "not on Memory")
for _, key in ipairs(SUBS) do Check(not Listed(key), key .. " listed for the pad with About closed") end

-- Hidden rows are passed over: up from the introduction's link is About.
Pad.Top().focus:Focus("nav:intro", "nav")
Press("PADDUP")
Eq(At().key, "nav:about", "up from the introduction's link: not About")
Eq(P:Section(), "feedback", "landing on About did not open Feedback")
Pad.Refresh()
Eq(At().key, "nav:about", "the pad moved off About once the page was built again")

-- Down walks the group's rows now listed.
Press("PADDDOWN")
Eq(At().key, "nav:feedback", "down from About: not Feedback")
Press("PADDDOWN")
Eq(At().key, "nav:changelog", "down: not the Changelog")
Eq(P:Section(), "changelog", "the Changelog not shown on landing")
-- (up to About keeps the subpage open)
Press("PADDUP")
Press("PADDUP")
Eq(At().key, "nav:about", "up: not About")
Eq(P:Section(), "feedback", "landing on About from Feedback changed the page")
Press("PADDDOWN")
Press("PADDDOWN")
Eq(P:Section(), "changelog", "back down: not the Changelog")

-- Into the Changelog: its lines, read down, the list scrolled to each.
Press("PADDRIGHT")
Eq(At().group, "pane", "right did not go into the Changelog")
Eq(At().key, "changelog:1", "not on the newest release's heading")
Eq(At().kind, "read", "its kind")
Eq(Prompt(), "Read on", "a line's prompt")
Eq(At().words, P.changelog:RowOf(1).text, "the heading's words not boxed")
local seen = {}
for _ = 1, 60 do
    Press("PADDDOWN")
    local line = P.changelog.data[At().index]
    seen[line.kind] = true
    Check(line.kind ~= "divider" and line.kind ~= "group", "the pad stood on a " .. line.kind)
    Check(P.changelog:RowOf(At().index) ~= nil, "a line read out of view")
end
Check(seen.entry and seen.summary and seen.version, "the pad did not read every kind of line")
Check(P.changelog.pos > 0, "reading down did not scroll the list")
Check(At().clip == P.changelog, "the box not clipped with the list")
-- (A does nothing on a line, and moves nowhere)
local here = At().key
Press("PAD1")
Eq(At().key, here, "A on a line moved the pad")
-- (a thanked entry's box holds its thanks)
Pad.Top().focus:Focus("changelog:" .. thanked, "pane")
local holds = At().encloses or {}
local held = false
for _, region in ipairs(holds) do if region == P.changelog:RowOf(thanked).thanks then held = true end end
Check(held, "the box round a thanked entry does not hold its thanks")

Press("PAD2")
Eq(At().key, "nav:changelog", "B did not come back to the Changelog's row")

-- Leaving About: the group's rows go, and so do their items.
Press("PADDUP")
Press("PADDUP")
Press("PADDUP")
Eq(At().key, "nav:memory", "up past About: not Memory")
for _, key in ipairs(SUBS) do Check(not Listed(key), key .. " still listed on Memory") end
Press("PADDDOWN")
Eq(At().key, "nav:about", "down from Memory: not About")

-- The update's switch, on Interface, ticked with A.
P:ShowSection("interface")
Pad.Refresh()
Press("PADDRIGHT")
for _ = 1, 30 do
    if At().frame == P.showUpdateHint then break end
    Press("PADDDOWN")
end
Eq(At().frame, P.showUpdateHint, "the update's switch never landed on")
local before = ns.Setting("showUpdateHint")
Press("PAD1")
Eq(ns.Setting("showUpdateHint"), not before, "A did not switch it")
Press("PAD1")
Eq(ns.Setting("showUpdateHint"), before, "A again did not switch it back")
