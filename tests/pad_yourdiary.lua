-- Your Diary's left page with the pad (UI/Journey/Pad.lua; .claude/controller-plan.md,
-- step 4a): the whole contents with the mouse, one level at a time with the
-- pad, its chevrons, left and right between levels and no further than the
-- ends, up and down its rows and A on them, the hand changing with the page
-- open, B closing the book, and the title after a ribbon turn.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local YourDiary = ns.UI.YourDiary

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local page = ns.UI.JourneyPage()
local entries = page.recap.entries
local n = #entries

local function Titles()
    local out = {}
    for _, item in ipairs(page.items) do
        if item.title then out[#out + 1] = item end
    end
    return out
end
local function RowFor(test)
    for _, row in ipairs(page.entries.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
end
local function Rubric() return RowFor(function(item) return item.title ~= nil end) end
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
local function Bold(fs) return (fs:GetShadowOffset()) == 1 end

--------------------------------------------------------------------------
Section("with the mouse the left page is the whole contents, as before")

Check(n >= 3, "setup: testdata has several levels")
Eq(#Titles(), n, "a rubric per level")
Check(page.items[1].text ~= nil, "the prologue not first")
Check(not Pad.Input.Active(), "the pad in hand with the mouse")
for _, item in ipairs(page.items) do Check(not item.solo, "an item one level's with the mouse") end
for _, row in ipairs(page.entries.rows) do Check(row.chevrons == nil, "chevrons made with the mouse") end

--------------------------------------------------------------------------
Section("the pad in hand: one level, its chevrons, the pad on its rubric")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Prompt()
    local first = Pad.Top().legend(Pad.Top())[1]
    return first and first[2]
end

Eq(Pad.Top() and Pad.Top().key, "yourdiary", "the top scope")
Eq(Pad.Top().parent, "journal", "its parent")
Eq(#Titles(), 1, "more than one level shown with the pad")
Eq(Titles()[1].entry, page.open, "the level shown is not the open one")
Check(page.items[1].title ~= nil, "the level's rubric is not first")
Eq(page.entries.offset, 0, "the level not shown from its top")
for _, item in ipairs(page.items) do
    Check(item.entry == nil or item.entry == page.open, "another level's row shown")
end
local row = Rubric()
Check(row and row.chevrons, "no chevrons on the rubric")
Check(row.chevrons.LEFT:IsShown() and row.chevrons.RIGHT:IsShown(), "the chevrons not shown")
Eq(page.open, n, "setup: fallen open on the newest")
Check(row.chevrons.LEFT.live and not row.chevrons.RIGHT.live, "the newest: earlier live, later faded")
Check(row.chevrons.RIGHT:GetAlpha() < row.chevrons.LEFT:GetAlpha(), "the dead chevron not faded")
Eq(At().key, "rubric", "the pad not on the rubric")
Check(Bold(row.header) and Red(row.header), "the rubric not boxed red and bold")
Eq(Prompt(), "Open", "the rubric's prompt")
local legend = Pad.Top().legend(Pad.Top())
Eq(legend[2] and legend[2][1][1], "PADDLEFT", "left and right not in the legend")

--------------------------------------------------------------------------
Section("left and right move between levels, and stop at the ends")

Check(not Press("PADDRIGHT"), "right at the newest went on to the game")
Eq(page.open, n, "right at the newest turned past it")
Press("PADDLEFT")
Eq(page.open, n - 1, "left: not the level before")
Eq(#Titles(), 1, "the level before not alone")
Eq(Titles()[1].entry, n - 1, "the level before not shown")
Eq(At().key, "rubric", "the pad not on the new level's rubric")
row = Rubric()
Check(row.chevrons.LEFT.live and row.chevrons.RIGHT.live, "a middle level: both chevrons live")
Press("PADDRIGHT")
Eq(page.open, n, "right: not back to the newest")
for _ = 1, n + 2 do Press("PADDLEFT") end
Eq(page.open, 1, "left never reached the first level")
row = Rubric()
Check(not row.chevrons.LEFT.live and row.chevrons.RIGHT.live, "the first: earlier faded, later live")
Eq(page.mode, "plates", "a level turned to does not show its plates")

--------------------------------------------------------------------------
Section("up and down walk the level's rows; A does what a click does")

-- A level read by sitting: the newest week.
for _ = 1, n do Press("PADDRIGHT") end
Eq(page.open, n, "setup: back on the newest")
local e = entries[n]
Check(e.pieces and #e.pieces >= 2, "setup: the newest is read by sitting")
Press("PADDDOWN")
Eq(At().key, "sitting:1", "down: not the first sitting")
local srow = RowFor(function(item) return item.sitting == 1 end)
Check(srow and At().frame == srow, "the item not on its row")
Check(Red(srow.zone) and Bold(srow.zone), "the sitting's words not boxed")
Eq(At().subhead, Rubric().header, "the level's rubric not its subheading")
Press("PAD1")
Eq(page.piece, 1, "A on a sitting did not open it")
Eq(page.open, n, "A on a sitting changed the level")
-- (4b: A crosses to the sitting's plates; B comes back to the sitting)
Eq(At().group, "page", "A on a sitting did not cross to its plates")
Press("PAD2")
Eq(At().key, "sitting:1", "B did not come back to the sitting")
-- Down to the end: the ledger's zones, each opening its map or run.
local last
for _ = 1, 60 do
    Press("PADDDOWN")
    if At() == last then break end
    last = At()
end
Check(last.data.zone ~= nil, "the last row walked to is not a zone of the ledger")
Check(page.entries:RowOf(last.index) ~= nil, "the last row not scrolled into view")
local clicked
local was = YourDiary.OpenItem
YourDiary.OpenItem = function(item) clicked = item end
Press("PAD1")
YourDiary.OpenItem = was
Eq(clicked, last.data, "A on a zone row did not do its click")
for _, item in ipairs(Pad.Top().focus.groups.left.items) do
    Check(YourDiary.Opens(item.data) or item.data.later, "a row that does nothing walked: " .. item.key)
end
Press("PADDUP")
Check(At() ~= last, "up did not move")

--------------------------------------------------------------------------
Section("the hand changing with the page open")

local open = page.open
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Eq(#Titles(), n, "the whole contents not back with the mouse")
Eq(page.open, open, "the open level changed with the hand")
Eq(page.entries.offset, math.min(page.rubrics[open] - 1, page.entries.bar.max or math.huge),
    "the contents not at the open level")
for _, r in ipairs(page.entries.rows) do
    Check(not (r.chevrons and r.chevrons.LEFT:IsShown()), "chevrons left up with the mouse")
end
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")
Eq(#Titles(), 1, "one level not back with the pad")
Eq(Pad.Top().key, "yourdiary", "the scope not back")

--------------------------------------------------------------------------
Section("after a ribbon turn the name holds the box until the first D-pad press")

ns.UI.SetJournalView("settings")
local ribbons = J.Ribbons()
for _ = 1, #ribbons do
    if J.view == "journey" then break end
    Press("PADRSHOULDER")
end
Eq(J.view, "journey", "never turned to Your Diary")
Eq(At().key, "title", "the name does not hold the box")
Check(Red(page.name), "the name not red")
Press("PADDLEFT")
Eq(At().key, "rubric", "the first press not on the rubric")
Eq(page.open, n, "the first press turned a level")
Check(not Red(page.name), "the name kept the box")

--------------------------------------------------------------------------
Section("B closes the book")

Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")
