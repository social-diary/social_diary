-- Recently nearby with the pad (UI/Journal/NearbyPad.lua; .claude/controller-plan.md,
-- step 6): the days walked and scrolled, A shows a day and crosses to its
-- people, B back to the day; the search, the filter and the headings; the
-- table walked and scrolled, each row's tooltip, A adds a stranger (the pad
-- stays) or opens someone (the pad follows to People); the title after a
-- ribbon turn; the mouse taking over; B on the days closes the book.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal

-- Mid-afternoon, so nothing straddles midnight.
local today = ns.DayStart(mock.now)
mock.now = today + 15 * 3600
local MULGORE = { mapID = 1412, x = 0.4, y = 0.6 }
local BARRENS = { mapID = 1413, x = 0.5, y = 0.5, subZone = "The Crossroads" }

-- (invented people: 30 seen today, so the table scrolls; one a day for
-- twenty days before, so the days scroll too)
local guids = {}
for i = 1, 30 do guids[i] = ("Player-0000-%08X"):format(0xB0000 + i) end
-- (in time order, as they are recorded)
for d = 20, 1, -1 do
    ns.Sightings.Record(guids[d], { level = 10, source = "plate" }, MULGORE, today - d * DAY + 12 * 3600)
end
for i = 1, 30 do
    local guid = ("Player-0000-%08X"):format(0xB0000 + i)
    guids[i] = guid
    ns.Characters.Observe(guid, { first = ("Nearwalker%02d"):format(i), level = 10 + i % 7, faction = "Horde",
        class = "DRUID" })
    ns.Sightings.Record(guid, { level = 10 + i % 7, source = "plate" }, i % 2 == 0 and MULGORE or BARRENS,
        today + 9 * 3600 + i * 60)
end
ns.Diary.Add(guids[30], { source = "test" })

ns.UI.ShowJournal()
ns.UI.SetJournalView("nearby")
local book = ns.UI.JournalFrame()
local NP = ns.UI.NearbyPage

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

--------------------------------------------------------------------------
Section("with the mouse nothing changes")

Check(not Pad.Input.Active(), "the pad in hand with the mouse")
Eq(J.Nearby.Day(), today, "setup: today not shown first")

--------------------------------------------------------------------------
Section("the pad in hand: the days, landing on one shows nothing")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Scope() return Pad.Scope("nearby") end
local function At() return Scope().focus:Current() end
local function Legend()
    local out = {}
    for _, s in ipairs({ Pad.Top(), Pad.Scope("journal") }) do
        for _, e in ipairs(s.legend(s)) do
            local key = type(e[1]) == "table" and e[1][1] or e[1]
            if out[key] == nil then out[key] = e[2] end
        end
    end
    return out
end
local parts = Pad.Look.parts[book]

Eq(Pad.Top() and Pad.Top().key, "nearby", "the top scope")
Eq(Pad.Top().parent, "journal", "its parent")
Eq(At().kind, "day", "the pad not on a day")
Eq(At().start, today, "not on the day shown")
Check(Red(At().words), "the day's words not red")
Check(parts.pen:IsShown(), "the day not boxed")
Check(At().subhead and Red(At().subhead), "the week not red over it")
Eq(Legend().PAD1, "Go to the people", "A's prompt on the day shown")
Eq(Legend().PAD2, "Close the book", "B on the days not the book's")

--------------------------------------------------------------------------
Section("down walks the days and scrolls them; held, it repeats")

local days = NP.days
local walked = 0
for _ = 1, 40 do
    local was = At()
    Press("PADDDOWN")
    if At() == was then break end
    walked = walked + 1
    Eq(At().kind, "day", "a week heading or something else walked")
    Check(days:RowOf(At().index) ~= nil, "the day walked to not in view")
end
Eq(walked, 20, "not every day walked")
Check(days.offset > 0, "the days did not scroll")
Eq(J.Nearby.Day(), today, "landing on a day showed it")
Eq(Legend().PAD1, "See this day", "A's prompt on another day")
for _ = 1, 30 do Press("PADDUP") end
Eq(At().start, today, "up to the top is not today")
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

--------------------------------------------------------------------------
Section("A shows another day and crosses; B comes back to it")

local other = At().start
Check(other ~= today, "setup: on another day")
Press("PAD1")
Eq(J.Nearby.Day(), other, "A did not show the day")
Eq(At().group, "table", "A did not cross to its people")
Eq(At().index, 1, "not on its first person")
Check(Red(At().words), "the name not red")
Check(Red(NP.title), "the day's title not red over them")
Eq(Legend().PAD2, "Back to the days", "B's prompt on the right page")
Press("PAD2")
Eq(At().key, "day:" .. tostring(other), "B did not come back to the day")
for _ = 1, 30 do Press("PADDUP") end
Press("PADDRIGHT")
Eq(J.Nearby.Day(), today, "right did not show the day")
Eq(At().group, "table", "right did not cross")

--------------------------------------------------------------------------
Section("the table: walked, scrolled, a tooltip on each row")

local list = NP.table
walked = 0
for _ = 1, 40 do
    local was = At()
    Press("PADDDOWN")
    if At() == was then break end
    walked = walked + 1
    Eq(At().kind, "row", "something else walked in the table")
    Check(list:RowOf(At().index) ~= nil, "the row walked to not in view")
end
Eq(walked, 29, "not everyone walked")
Check(list.offset > 0, "the table did not scroll")
Eq(GameTooltip.text, At().frame.item.name, "the row's tooltip not shown")
local deep = At().key
-- (B and A again: back where the pad was)
Press("PAD2")
Press("PAD1")
Eq(At().key, deep, "A on the day shown not back where the pad was")
for _ = 1, 40 do
    if At().group ~= "table" then break end
    Press("PADDUP")
end
Eq(At().group, "heads", "up off the table's top not the headings")
Eq(At().key, "sort:name", "not on the Name heading first")

--------------------------------------------------------------------------
Section("the headings: left and right along them, A sorts")

Check(Red(NP.headings.name.label), "the heading not red")
Eq(Legend().PAD1, "Sort by this", "A's prompt on a heading")
Press("PAD1")
Eq(NP.query.sort, "name", "A did not sort by name")
Eq(At().key, "sort:name", "sorting moved the pad")
Eq(Legend().PAD1, "Sort the other way", "the prompt after a sort")
Press("PAD1")
Eq(Legend().PAD1, "Sort by last seen", "the prompt on the third click")
Press("PAD1")
Eq(NP.query.sort, "last", "the third press not latest first again")
Press("PADDRIGHT")
Eq(At().key, "sort:zone", "right from Name not Zone")
Press("PADDRIGHT")
Eq(At().key, "sort:subzone", "right from Zone not Subzone")
Press("PADDLEFT"); Press("PADDLEFT"); Press("PADDLEFT")
Eq(At().key, "sort:level", "left along the headings not Lvl")
Press("PADDDOWN")
Eq(At().group, "table", "down off the headings not the table")
Press("PADDUP")
Press("PADDLEFT")
Eq(At().group, "left", "left off the headings not the days")
Press("PAD1")

--------------------------------------------------------------------------
Section("the search: A gives it the cursor, moving off or B takes it back")

for _ = 1, 40 do Press("PADDUP") end
Eq(At().key, "search", "up off the headings not the search")
local box = NP.search
Eq(Legend().PAD1, "Write", "A's prompt on the search")
Press("PAD1")
Check(box:HasFocus(), "A did not give the search the cursor")
Eq(Legend().PAD1, "Done writing", "the prompt while writing")
Eq(Legend().PAD2, "Stop writing", "B's prompt while writing")
box:SetText("Nearwalker1")
box:GetScript("OnTextChanged")(box)
Eq(At().key, "search", "writing moved the pad off the search")
Check(box:HasFocus(), "the table narrowing took the cursor away")
local narrowed = #Scope().focus.groups.table.items
Eq(narrowed, 10, "the walked rows not the table narrowed")
Press("PAD2")
Check(not box:HasFocus(), "B did not stop writing")
Check(book:IsShown(), "B while writing closed the book")
Eq(At().key, "search", "B while writing left the search")
Press("PAD1")
Press("PADDDOWN")
Check(not box:HasFocus(), "moving off the search kept the cursor")
box:SetText("")
box:GetScript("OnTextChanged")(box)

--------------------------------------------------------------------------
Section("the filter: right of the search; A opens its menu, the pad steps aside")

Check(Scope().focus:Focus("search", "bar"), "setup: onto the search")
Press("PADDRIGHT")
Eq(At().key, "filter", "right from the search not the filter")
Eq(Legend().PAD1, "Choose", "A's prompt on the filter")
mock.contextMenu = nil
local open = true
_G.Menu = { GetManager = function() return { GetOpenMenu = function() return open or nil end } end }
Press("PAD1")
Check(mock.contextMenu ~= nil, "A on the filter opened no menu")
Eq(Pad.Top(), nil, "the pad did not step aside for the menu")
open = false
Pad.menuWatch.scripts.OnUpdate(Pad.menuWatch, 0.1)
_G.Menu = nil
Eq(Pad.Top() and Pad.Top().key, "nearby", "the pad not back after the menu")
Eq(At().key, "filter", "not back on the filter")
Press("PADDDOWN")
Eq(At().group, "heads", "down from the filter not the headings")

--------------------------------------------------------------------------
Section("A on a stranger adds them; the pad stays on the row")

local stranger
for _, it in ipairs(Scope().focus.groups.table.items) do
    if not ns.Diary.IsDiary(it.guid) then stranger = stranger or it end
end
Check(Scope().focus:Focus(stranger.key, "table"), "setup: onto a stranger")
Eq(Legend().PAD1, "Add to the diary", "A's prompt on a stranger")
Press("PAD1")
Check(ns.Diary.IsDiary(stranger.guid), "A did not add them")
Eq(ns.Diary.Get(stranger.guid).addedContext.source, "nearby", "not added as the page adds")
Eq(J.view, "nearby", "A on a stranger left the page")
Eq(At().key, stranger.key, "the pad left the row")
Check(At().frame.added:IsShown(), "the row not marked Added")
Eq(Legend().PAD1, "Open their page", "the prompt after adding")

--------------------------------------------------------------------------
Section("A on someone in the diary opens their page; the pad follows")

Press("PAD1")
Eq(J.view, "people", "A did not turn to People")
Eq(J.selected, stranger.guid, "not their page")
Eq(Pad.Top() and Pad.Top().key, "people", "People's scope has not the pad")
Eq(Pad.Scope("people").focus:Current().key, "header", "the pad not on their name")
Press("PAD2")
Eq(Pad.Scope("people").focus:Current().key, "person:" .. stranger.guid, "B not on their row")

--------------------------------------------------------------------------
Section("after a ribbon turn the title holds the box until the first press")

for _ = 1, #J.Ribbons() do
    if J.view == "nearby" then break end
    Press("PADRSHOULDER")
end
Eq(J.view, "nearby", "never turned to Recently nearby")
Eq(At().key, "title", "the title does not hold the box")
Check(Red(NP.heading), "the title not red")
Eq(Legend().PAD1, nil, "A offered on the title")
Press("PADDDOWN")
Eq(At().key, "day:" .. tostring(J.Nearby.Day()), "the first press not on the day shown")
Check(not Red(NP.heading), "the title kept the box")

--------------------------------------------------------------------------
Section("the mouse taking over puts everything away; the pad brings it back")

Press("PAD1")
Press("PADDDOWN")
local at = At().key
Eq(At().group, "table", "setup: in the table")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the box left up")
Check(not Red(At().words), "the name left red")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher still on")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(At().key, at, "the pad not back where it was")
Check(parts.pen:IsShown(), "the box not back")

--------------------------------------------------------------------------
Section("no days: nothing walked, the D-pad goes on to the game")

wipe(ns.db.sightings)
ns.UI.RefreshNearbyPage()
Eq(At(), nil, "something walked with no days")
Check(mock.PadPress(catcher, "PADDDOWN", true) == true, "the D-pad did not go on to the game")
mock.PadPress(catcher, "PADDDOWN", false)

--------------------------------------------------------------------------
Section("B on the days closes the book")

Press("PAD2")
Check(not book:IsShown(), "B on the days did not close the book")
