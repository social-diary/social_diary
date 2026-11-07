-- The People page with the pad (UI/Journal/PeoplePad.lua; .claude/controller-plan.md,
-- step 5a): the list walked, scrolled and repeated; landing opens nothing, A
-- opens and crosses, B comes back to the same row; the search, the sort and
-- the filter; the right page's header, plate (its marks), strips, timeline
-- (folding with A), tabs and map sheet; no click on an item; the title after
-- a ribbon turn; the mouse taking over; writing mode left to the book.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal

SlashCmdList.SOCIALDIARY("testdata")
-- (invented people, enough that the list scrolls)
for i = 1, 30 do
    local guid = ("Player-0000-%08X"):format(0xA0000 + i)
    ns.Characters.Observe(guid, { first = ("Padwalker%02d"):format(i), level = 10 + i % 7, faction = "Horde" })
    ns.Diary.Add(guid, { source = "test" })
end
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
local book = ns.UI.JournalFrame()
local journal = J.journal
local p = journal.profile
local TESTER = ns.TestData and ns.TestData.TESTER or nil

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

--------------------------------------------------------------------------
Section("with the mouse nothing changes")

Check(not Pad.Input.Active(), "the pad in hand with the mouse")
local selected = J.selected

--------------------------------------------------------------------------
Section("the pad in hand: the list, landing on a row opens nothing")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Scope() return Pad.Scope("people") end
local function At() return Scope().focus:Current() end
local function Legend()
    local out = {}
    for _, s in ipairs({ Scope(), Pad.Scope("journal") }) do
        for _, e in ipairs(s.legend(s)) do
            local key = type(e[1]) == "table" and e[1][1] or e[1]
            if out[key] == nil then out[key] = e[2] end
        end
    end
    return out
end
local parts = Pad.Look.parts[book]

Eq(Pad.Top() and Pad.Top().key, "people", "the top scope")
Eq(Pad.Top().parent, "journal", "its parent")
Eq(At().kind, "person", "the pad not on someone")
local first = At().key
Check(Red(At().words), "the name not red")
Check(parts.pen:IsShown(), "the name not boxed")
Eq(Legend().PAD1, "Open their page", "A's prompt on a row")
Eq(Legend().PAD2, "Close the book", "B on the left page not the book's")

--------------------------------------------------------------------------
Section("down walks the list and scrolls it; held, it repeats")

local list = journal.people
local walked = 0
for _ = 1, 40 do
    local was = At()
    Press("PADDDOWN")
    if At() == was then break end
    walked = walked + 1
    Eq(At().kind, "person", "a heading or something else walked")
    Check(list:RowOf(At().index) ~= nil, "the row walked to not in view")
end
Check(walked >= 30, "not every person walked")
Check(list.offset > 0, "the list did not scroll")
Eq(J.selected, selected, "landing on a row opened someone")
local last = At().key
-- (held: the first wait, then every step)
for _ = 1, 50 do Press("PADDUP") end
Eq(At().key, "search", "up to the top is not the search")
Press("PADDDOWN"); Press("PADDDOWN"); Press("PADDDOWN")
Eq(At().kind, "person", "setup: on the first person")
local held = At().index
mock.keysDown.PADDDOWN = true
mock.PadPress(catcher, "PADDDOWN", true)
local afterPress = At().index
catcher.scripts.OnUpdate(catcher, 0.4)
catcher.scripts.OnUpdate(catcher, 0.2)
mock.keysDown.PADDDOWN = nil
mock.PadPress(catcher, "PADDDOWN", false)
Check(afterPress > held, "the press itself did not move")
Check(At().index > afterPress, "a held down did not repeat")
Check(catcher.scripts.OnUpdate == nil, "still repeating after the release")
-- (a heading is the subheading over its people)
local headed
for _, it in ipairs(Scope().focus.groups.left.items) do if it.heading then headed = it end end
Check(headed, "setup: a person under a heading")
Check(Scope().focus:Focus(headed.key, "left"), "setup: onto them")
if At().subhead then Check(Red(At().subhead), "the heading not red over them") end

--------------------------------------------------------------------------
Section("the search: A gives it the cursor, moving off or B takes it back")

Check(Scope().focus:Focus("search", "left"), "setup: onto the search")
local box = journal.search
Eq(Legend().PAD1, "Write", "A's prompt on the search")
Press("PAD1")
Check(box:HasFocus(), "A did not give the search the cursor")
Eq(Legend().PAD1, "Done writing", "the prompt while writing")
Eq(Legend().PAD2, "Stop writing", "B's prompt while writing")
box:SetText("Padwalker1")
box:GetScript("OnTextChanged")(box)
Eq(At().key, "search", "writing moved the pad off the search")
Check(box:HasFocus(), "the list narrowing took the cursor away")
local narrowed = 0
for _, it in ipairs(Scope().focus.groups.left.items) do if it.kind == "person" then narrowed = narrowed + 1 end end
Eq(narrowed, 10, "the walked rows not the list narrowed")
Press("PAD2")
Check(not box:HasFocus(), "B did not stop writing")
Check(book:IsShown(), "B while writing closed the book")
Press("PAD1")
Press("PADDDOWN")
Check(not box:HasFocus(), "moving off the search kept the cursor")
box:SetText("")
box:GetScript("OnTextChanged")(box)

--------------------------------------------------------------------------
Section("the sort: left and right go through the sorts; A opens its menu")

Check(Scope().focus:Focus("sort", "left"), "setup: onto the sort")
Check(Red(journal.sortButton.label), "the sort's words not red")
local sort = J.query.sort
Press("PADDRIGHT")
Check(J.query.sort ~= sort, "right did not sort another way")
Eq(ns.Setting("peopleSort"), J.query.sort, "the sort not kept as the menu keeps it")
Press("PADDLEFT")
Eq(J.query.sort, sort, "left did not come back")
Eq(At().key, "sort", "sorting moved the pad")
mock.contextMenu = nil
-- (Blizzard's menu open: the pad steps aside until it closes)
local open = true
_G.Menu = { GetManager = function() return { GetOpenMenu = function() return open or nil end } end }
Press("PAD1")
Check(mock.contextMenu ~= nil, "A on the sort opened no menu")
Eq(Pad.Top(), nil, "the pad did not step aside for the menu")
open = false
Pad.menuWatch.scripts.OnUpdate(Pad.menuWatch, 0.1)
_G.Menu = nil
Eq(Pad.Top() and Pad.Top().key, "people", "the pad not back after the menu")
Check(Scope().focus:Focus("filter", "left"), "setup: onto the filter")
mock.contextMenu = nil
Press("PAD1")
Check(mock.contextMenu ~= nil, "A on the filter opened no menu")
Eq(Legend().PAD1, "Choose", "A's prompt on the filter")

--------------------------------------------------------------------------
Section("A opens their page and crosses; B comes back to the same row")

local tester
for _, it in ipairs(Scope().focus.groups.left.items) do
    if it.kind == "person" and ns.Timeline.For(it.guid)[3] then tester = it end
end
Check(tester, "setup: someone with a timeline")
Check(Scope().focus:Focus(tester.key, "left"), "setup: onto them")
Eq(J.selected, selected, "setup: landing opened them")
Press("PAD1")
Eq(J.selected, tester.guid, "A did not open their page")
Eq(At().group, "page", "A did not cross")
Eq(At().key, "header", "not on their name")
Check(parts.pen:IsShown(), "their name not boxed")
Eq(Legend().PAD2, "Back to the list", "B's prompt on the right page")
Press("PAD2")
Eq(At().key, tester.key, "B did not come back to the same row")
Press("PAD1")
Eq(At().key, "header", "A again not back on their page")

--------------------------------------------------------------------------
Section("the tabs: up from the top, right from anywhere; down or left back")

Press("PADDUP")
Eq(At().key, "tab:story", "up from their name not the tabs")
Check(parts.outline and parts.outline.line:IsShown(), "a tab not outlined")
Press("PADDDOWN")
Eq(At().key, "tab:map", "down the tabs")
Eq(Legend().PAD1, "See where you saw them", "the map tab's prompt")
Press("PAD1")
Eq(J.tab, "map", "A on the map tab did not lay the map out")
Eq(At().group, "sheet", "the pad not on the map sheet")
Eq(Legend().PAD2, "Put the map away", "B's prompt on the sheet")
for _, it in ipairs(Scope().focus.groups.left.items) do Check(false, "the left page walked under the sheet") end
Press("PAD2")
Eq(J.tab, "timeline", "B did not put the map away")
Eq(At().key, "tab:map", "B not back on the map tab")
Press("PADDLEFT")
Eq(At().group, "page", "left off the tabs not the page")
Press("PADDRIGHT")
Eq(At().group, "tabs", "right on the page not the tabs")
Press("PADDLEFT")

--------------------------------------------------------------------------
Section("the plate: outlined; A among its marks; X the map; B back")

Check(Scope().focus:Focus("plate", "page"), "setup: onto the plate")
Check(parts.outline.line:IsShown(), "the plate not outlined")
Eq(Legend().PAD1, "Look at the marks", "the plate's prompt")
Eq(Legend().PAD3, "See the map", "X on the plate")
local plate = p.clippings.plate
Press("PAD1")
Eq(At().group, "marks", "A did not go among the marks")
Check(At().ring, "a mark not ringed")
Check(plate.padLean, "the plate did not lean in")
Check(GameTooltip.shown, "a mark's tooltip not shown")
local mark = At().key
Press("PAD3")
Eq(J.tab, "map", "X on a mark did not lay the map out")
Press("PAD2")
Eq(At().key, mark, "B from the map not back on the mark")
Press("PAD2")
Eq(At().key, "plate", "B from the marks not back on the plate")
Check(not plate.padLean, "the plate still leaning")
Press("PAD3")
Eq(J.tab, "map", "X on the plate")
Press("PAD2")
Eq(At().key, "plate", "B from the map not back on the plate")

--------------------------------------------------------------------------
Section("the strips beside it: outlined, their heading red")

Press("PADDDOWN")
Eq(At().kind, "strip", "down from the plate not a strip")
Check(parts.outline.line:IsShown(), "a strip not outlined")
Check(At().heading and Red(At().heading), "a strip's heading not red")
local strips = 0
for _, it in ipairs(Scope().focus.groups.page.items) do if it.kind == "strip" then strips = strips + 1 end end
Check(strips >= 3, "the facts and the note not all walked")

--------------------------------------------------------------------------
Section("the timeline: scrolled to, folded and opened with A")

local episode
for _, it in ipairs(Scope().focus.groups.page.items) do
    local line = it.line
    if line and not line.fold and not line.visit and not line.note and line.item and line.item.hidden
        and line.item.hidden > 0 then
        episode = episode or it
    end
end
Check(episode, "setup: an episode with more inside")
Check(Scope().focus:Focus(episode.key, "page"), "setup: onto it")
Check(p.timeline:RowOf(episode.index) ~= nil, "the line not scrolled into view")
Check(Red(At().words), "the line's words not red")
Eq(Legend().PAD1, "See the rest", "a folded episode's prompt")
local lines = #p.timeline.data
Press("PAD1")
Check(#p.timeline.data > lines, "A did not open the episode")
Eq(At().key, episode.key, "the pad left the episode")
Eq(Legend().PAD1, "Fold it up", "an open episode's prompt")
Press("PAD1")
Eq(#p.timeline.data, lines, "A did not fold it again")
-- (down the whole page: the list follows)
for _ = 1, 80 do Press("PADDDOWN") end
Check(p.timeline.pos > 0, "the timeline did not scroll")
Check(p.timeline:RowOf(At().index) ~= nil, "the last line not in view")
for _ = 1, 120 do Press("PADDUP") end
Eq(At().group, "tabs", "up off the top not the tabs")

--------------------------------------------------------------------------
Section("an item in a line: its tooltip only, never a click")

local trade
for _, it in ipairs(Scope().focus.groups.page.items) do
    if it.line and it.line.text and it.line.text:find("|Hitem:") then trade = trade or it end
end
Check(trade, "setup: a line with an item")
Check(Scope().focus:Focus(trade.key, "page"), "setup: onto it")
local handed = {}
_G.IsModifiedClick = function() return true end
_G.HandleModifiedItemClick = function(link) handed[#handed + 1] = link return true end
mock.modifiers.shift = true
Check(not Press("PAD1"), "A on an item's line went on to the game")
mock.modifiers.shift = nil
_G.IsModifiedClick, _G.HandleModifiedItemClick = nil, nil
Eq(#handed, 0, "A on an item's line handed a link to the game")
Check(Legend().PAD1 == nil, "A offered on an item's line")
Eq(At().key, trade.key, "A on an item's line moved the pad")

--------------------------------------------------------------------------
Section("a note's slip: outlined; A opens its sheet (5b)")

local noteLine
for _, it in ipairs(Scope().focus.groups.page.items) do
    if it.line and it.line.note and it.line.slip then noteLine = noteLine or it end
end
Check(noteLine, "setup: a note on the timeline")
Check(Scope().focus:Focus(noteLine.key, "page"), "setup: onto it")
Check(parts.outline.line:IsShown(), "a note's slip not outlined")
Check(not parts.pen:IsShown(), "a note's slip boxed as words")
Eq(Legend().PAD1, "Change the note", "A's prompt on a note")
Press("PAD1")
Eq(J.tab, "note", "A on a note did not open its sheet")
Eq(Pad.Top() and Pad.Top().key, "note", "the note's sheet has not the pad")
Press("PAD2")
Eq(J.tab, "timeline", "B did not put the note's sheet away")
Eq(At().key, noteLine.key, "not back on the note's line")

--------------------------------------------------------------------------
Section("a run's card: A lays it out; the spread has the pad")

local run
for _, it in ipairs(Scope().focus.groups.page.items) do if it.line and it.line.visit then run = run or it end end
Check(run, "setup: a run's card")
Check(Scope().focus:Focus(run.key, "page"), "setup: onto it")
Check(Legend().PAD1 ~= nil, "no prompt on a run's card")
Press("PAD1")
Check(J.visit ~= nil, "A on a run's card did not lay it out")
Eq(Pad.Top() and Pad.Top().key, "spread", "the spread's scope has not the pad")
ns.UI.DungeonPage.Close()
Eq(Pad.Top().key, "people", "the pad not back on the page")
Eq(At().key, run.key, "not back on the run's card")

--------------------------------------------------------------------------
Section("the mouse taking over puts everything away; the pad brings it back")

Check(Scope().focus:Focus("plate", "page"), "setup: onto the plate")
Press("PAD1")
local at = At().key
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the ring left up")
Check(not parts.outline.line:IsShown(), "an outline left up")
Check(not plate.padLean, "the plate left leaning")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher still on")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(At().key, at, "the pad not back where it was")
Press("PAD2")
Press("PAD2")

--------------------------------------------------------------------------
Section("writing mode has a scope of its own (5b)")

J.Edit(J.selected)
Eq(Pad.Top() and Pad.Top().key, "writing", "writing's scope has not the pad while writing")
J.EndEdit()
Eq(Pad.Top() and Pad.Top().key, "people", "the pad not back after writing")

--------------------------------------------------------------------------
Section("after a ribbon turn the title holds the box until the first press")

ns.UI.SetJournalView("settings")
for _ = 1, #J.Ribbons() do
    if J.view == "people" then break end
    Press("PADRSHOULDER")
end
Eq(J.view, "people", "never turned to People")
Eq(At().key, "title", "the title does not hold the box")
Check(Red(journal.peopleTitle), "the title not red")
Press("PADDDOWN")
Eq(At().key, "person:" .. tostring(J.selected), "the first press not on the open person's row")
Check(not Red(journal.peopleTitle), "the title kept the box")

--------------------------------------------------------------------------
Section("B on the left page closes the book")

Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")
local _ = first or last or TESTER
