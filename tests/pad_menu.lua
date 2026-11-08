-- The pad's own menu (UI/Pad/Menu.lua; .claude/controller-plan.md, "Client
-- round 2", 8 Nov 2026): with the pad in hand a menu is never Blizzard's
-- (Forever's Gamepad UI does not drive one an addon opens); the same
-- generator the mouse's MenuUtil menu is built from is laid on a slip the
-- pad walks. The People page's sort and filter (a submenu), Recently
-- nearby's filter, the map sheet's "Show map"; a choice applied as the
-- mouse's is; B one level; the mouse still gets Blizzard's menu.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Menu = Pad.Menu

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
local book = ns.UI.JournalFrame()
local journal = J.journal

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

-- The labels of a recorded menu level, choices only, in order.
local function Labels(node)
    local out = {}
    for _, e in ipairs(node.children) do
        if e.kind ~= "title" and e.kind ~= "divider" and e.kind ~= "spacer" then out[#out + 1] = e.text end
    end
    return table.concat(out, "|")
end

--------------------------------------------------------------------------
Section("the mouse: Blizzard's menu, as before")

Check(not Pad.Input.Active(), "setup: the mouse in hand")
mock.contextMenu = nil
journal.sortButton:Click("LeftButton")
Check(mock.contextMenu ~= nil, "a click on the sort opened no Blizzard menu")
Check(not Menu.IsOpen(), "the mouse opened the pad's menu")
-- The recorder hears the same generator as MenuUtil does.
Eq(Labels(Menu.Record(journal.sortButton, J.SortMenu)), Labels(mock.contextMenu), "the sort's choices differ")
mock.contextMenu = nil
journal.filterButton:Click("LeftButton")
local mouseFilter = mock.contextMenu
Eq(Labels(Menu.Record(journal.filterButton, J.FilterMenu())), Labels(mouseFilter), "the filter's choices differ")
Eq(Labels(Menu.Record(nil, J.FilterMenu()).children[3]), Labels(mouseFilter.children[3]), "the Tag submenu differs")

--------------------------------------------------------------------------
Section("the pad: A on the sort lays the pad's menu, never Blizzard's")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Top() return Pad.Top() and Pad.Top().key end
local function At() return Pad.Top().focus:Current() end
local function Legend()
    local out = {}
    for _, e in ipairs(Pad.Legend(Pad.Top())) do
        local key = type(e[1]) == "table" and e[1][1] or e[1]
        if out[key] == nil then out[key] = e[2] end
    end
    return out
end
local function Walk(text)
    for _ = 1, 40 do
        if At().element.text == text then return true end
        Press("PADDDOWN")
    end
    return false
end
local people = Pad.Scope("people")

Check(people.focus:Focus("sort", "left"), "setup: onto the sort")
local sort = J.query.sort
mock.contextMenu = nil
Press("PAD1")
Eq(mock.contextMenu, nil, "A opened Blizzard's menu")
Eq(Top(), "menu", "the pad's menu does not have the pad")
Check(Menu.IsOpen(), "no menu open")
local slip = Pad.Look.parts[book] and true
Check(slip, "setup: the book's look")
-- Its first line: the sort chosen now (its radio's lozenge in the box).
local chosen
for _, s in ipairs(ns.People.SORTS) do if s.key == sort then chosen = s.label end end
Eq(At().element.text, chosen, "the pad not on the sort chosen")
Check(At().encloses ~= nil, "the chosen radio's lozenge not held in the box")
Check(Red(At().words), "the line's words not red")
Check(Pad.Look.parts[book].pen:IsShown(), "the line not boxed")
Eq(Legend().PAD1, Menu.PROMPT.choose, "A's prompt")
Eq(Legend().PAD2, Menu.PROMPT.away, "B's prompt at the top")
Eq(Legend().PADLSHOULDER, nil, "the ribbons turn under the menu")
Check(Press("PADLSHOULDER"), "a shoulder taken while the menu is up")
-- The title is not walked; up off the first choice stays.
for _, it in ipairs(Pad.Top().focus.groups.menu.items) do Check(it.element.kind ~= "title", "a title walked") end

-- A choice applied as the mouse's: "Name" picked by the pad and by the mouse.
local pick = ns.People.SORTS[#ns.People.SORTS]
Check(Walk(pick.label), "the last sort not reached")
Press("PAD1")
Eq(J.query.sort, pick.key, "the pad's pick did not sort")
Check(not Menu.IsOpen(), "a radio did not close the menu")
Eq(Top(), "people", "the page does not have the pad back")
Eq(At().key, "sort", "the pad not back on the sort")
local byPad = J.query.sort
J.SetSort(sort)
Pad.Input.Force("off")
mock.contextMenu = nil
journal.sortButton:Click("LeftButton")
mock.MenuClick(pick.label)
Eq(J.query.sort, byPad, "the mouse's pick and the pad's differ")
Eq(ns.Setting("peopleSort"), byPad, "the sort not kept")
Pad.Input.Force(nil)
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Pad.Refresh()
-- D-pad left / right still go through the sorts without the menu.
Check(people.focus:Focus("sort", "left"), "setup: onto the sort again")
Press("PADDRIGHT")
Check(J.query.sort ~= byPad, "right did not sort another way")
Check(not Menu.IsOpen(), "right opened the menu")

--------------------------------------------------------------------------
Section("the filter: a submenu goes in on right or A, comes back on left or B")

Check(people.focus:Focus("filter", "left"), "setup: onto the filter")
Press("PAD1")
Eq(Top(), "menu", "the filter's menu not the pad's")
Eq(At().element.text, "Clear filters", "not on the first choice")
Press("PADDDOWN")
Eq(At().element.text, "Tag", "the divider walked, or Tag not next")
Eq(Legend().PAD1, Menu.PROMPT.open, "A's prompt on a submenu")
Press("PADDRIGHT")
Eq(#Pad.Top().focus.groups.menu.items, #Menu.Record(nil, J.FilterMenu()).children[3].children,
    "the submenu's choices not walked")
Eq(At().element.text, "Any", "the submenu not on its chosen radio")
Eq(Legend().PAD2, Menu.PROMPT.back, "B's prompt in a submenu")
Press("PADDLEFT")
Eq(At().element.text, "Tag", "left did not come back to its line")
Press("PAD1")
Eq(At().element.text, "Any", "A did not go in")
Press("PAD2")
Eq(At().element.text, "Tag", "B did not come back to its line")
Check(Menu.IsOpen(), "B in a submenu put the whole menu away")
-- A tag chosen in the submenu, as the mouse's pick would.
Press("PADDRIGHT")
Press("PADDDOWN")
local tag = At().element.text
Check(tag ~= "Any", "setup: a tag")
Press("PAD1")
Eq(J.query.tag, tag, "the pad's tag not the filter")
Check(not Menu.IsOpen(), "a choice in a submenu left the menu open")
Eq(At().key, "filter", "not back on the filter")
J.query.tag = nil
Pad.Input.Force("off")
mock.contextMenu = nil
journal.filterButton:Click("LeftButton")
mock.MenuClick("Tag", tag)
Eq(J.query.tag, tag, "the mouse's pick and the pad's differ")
J.query.tag = nil
J.RefreshList()
Pad.Input.Force(nil)
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Pad.Refresh()
-- B at the top puts it away, the pad where it was.
Check(people.focus:Focus("filter", "left"), "setup: onto the filter again")
Press("PAD1")
Press("PAD2")
Check(not Menu.IsOpen(), "B at the top did not put the menu away")
Eq(At().key, "filter", "B not back on the filter")
-- The mouse taking over puts it away.
Press("PAD1")
Check(Menu.IsOpen(), "setup: open again")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Menu.IsOpen(), "the mouse taking over left the pad's menu up")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Pad.Input.Force(nil)
Pad.Refresh()

--------------------------------------------------------------------------
Section("what Blizzard's menu does, the recorder does: checkboxes, responses, the disabled")

_G.MenuResponse = { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 }
local ticked, pressed, kept = false, 0, 0
local function Generator(_, root)
    root:CreateTitle("Things")
    root:CreateCheckbox("Ticked", function() return ticked end, function() ticked = not ticked end)
    local off = root:CreateButton("Not now", function() pressed = pressed + 100 end)
    off:SetEnabled(false)
    root:CreateButton("Keep it open", function()
        kept = kept + 1
        return MenuResponse.Refresh
    end)
    root:CreateDivider()
    root:CreateButton("Press", function() pressed = pressed + 1 end)
    root:SetTooltip(function() end)   -- (heard, nothing done)
end
Check(Menu.Open(journal.filterButton, Generator), "a generic menu not opened")
Eq(At().element.text, "Ticked", "the title walked")
Press("PAD1")
Check(ticked, "the checkbox not ticked")
Check(Menu.IsOpen(), "a checkbox closed the menu")
Eq(At().element.text, "Ticked", "the pad moved off the checkbox")
Press("PADDDOWN")
Eq(At().element.text, "Keep it open", "the disabled line walked")
Press("PAD1")
Eq(kept, 1, "the button's callback not called")
Check(Menu.IsOpen(), "MenuResponse.Refresh closed the menu")
Press("PADDDOWN")
Press("PAD1")
Eq(pressed, 1, "the plain button not pressed (or the disabled one was)")
Check(not Menu.IsOpen(), "a plain button left the menu open")
_G.MenuResponse = nil
-- A menu with nothing to choose is not laid.
Check(not Menu.Open(journal.filterButton, function(_, root) root:CreateTitle("Nothing") end), "an empty menu laid")

--------------------------------------------------------------------------
Section("the map sheet's \"Show map\": the pad's menu")

local p = journal.profile
local tester
for _, it in ipairs(people.focus.groups.left.items) do
    if it.kind == "person" and ns.Timeline.For(it.guid)[3] then tester = it break end
end
people.focus:Focus(tester.key, "left")
Press("PAD1")
Check(people.focus:Focus("tab:map", "tabs"), "setup: onto the map tab")
Press("PAD1")
Eq(J.tab, "map", "setup: the map sheet")
local mapItem
for _, it in ipairs(people.focus.groups.sheet.items) do
    if it.frame == p.map.mapButton then mapItem = it end
end
Check(mapItem, "the map's link not walked")
people.focus:Set(mapItem)
-- (the mock's sheet has seen them on no map: two laid as the sheet keeps
-- them, so its menu has choices; the mouse's click and the pad's run the
-- same generator)
local keptMaps = p.map.maps
p.map.maps = { { mapID = 1413, total = 3 }, { mapID = 1411, total = 1 } }
mock.contextMenu = nil
Pad.Input.Force("off")
p.map.mapButton:Click("LeftButton")
Check(mock.contextMenu ~= nil, "the mouse's map menu not Blizzard's")
Eq(Labels(Menu.Record(nil, p.map.mapMenu())), Labels(mock.contextMenu), "the map menu's choices differ")
Pad.Input.Force(nil)
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Pad.Refresh()
people.focus:Set(mapItem)
mock.contextMenu = nil
Press("PAD1")
Eq(mock.contextMenu, nil, "A on the map's link opened Blizzard's menu")
Eq(Top(), "menu", "A on the map's link opened no menu of the pad's")
Eq(#Pad.Top().focus.groups.menu.items, 2, "the maps not walked")
Press("PAD2")
Check(not Menu.IsOpen(), "B did not put the map menu away")
Eq(At().frame, p.map.mapButton, "not back on the map's link")
Eq(J.tab, "map", "the sheet put away with the menu")
p.map.maps = keptMaps
Press("PAD2")

--------------------------------------------------------------------------
Section("Recently nearby's filter: the pad's menu, the mouse's choices")

ns.UI.SetJournalView("nearby")
Pad.Refresh()
local np = ns.UI.NearbyPage
mock.contextMenu = nil
Pad.Input.Force("off")
np.filter:Click("LeftButton")
Check(mock.contextMenu ~= nil, "the mouse's filter menu not Blizzard's")
Eq(Labels(Menu.Record(nil, J.Nearby.FilterMenu())), Labels(mock.contextMenu), "Nearby's choices differ")
Pad.Input.Force(nil)
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Pad.Refresh()
-- (A on it opening the pad's menu, and B back on it: tests/pad_nearby.lua)

--------------------------------------------------------------------------
Section("with the Gamepad UI off, nothing of the menu runs")

Pad.Input.Force("off")
Pad.Refresh()
Check(not Menu.IsOpen(), "a menu up with the mouse")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on with the mouse")
Pad.Input.Force(nil)
