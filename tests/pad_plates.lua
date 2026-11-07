-- Your Diary's right page with the pad (UI/Journey/Pad.lua; .claude/controller-plan.md,
-- step 4b): A on the left page crosses to the plates; the pad moves between
-- plates and margin notes by where they lie; each wears the user's active
-- state (a red outline, a slight red drop shadow, its heading red), given
-- back whole; A on a plate goes in among its marks (the pen's ring, the
-- mark's own tooltip, the plate leaning in), B backs out a level at a time;
-- X opens the zone's whole map and B comes back; the mouse takes over
-- cleanly; and a feature's card and marks are found with no pad code.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Look = Pad.Look
local Margin = ns.UI.JourneyMargin
local Plate = ns.UI.JourneyPlate

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local page = ns.UI.JourneyPage()

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
local function Colour(fs) return { fs:GetTextColor() } end
local function SameColour(a, b)
    for i = 1, 3 do if math.abs((a[i] or 0) - (b[i] or 0)) > 0.001 then return false end end
    return true
end

-- The page with the most plates and notes: the richest walk.
local best, bestScore
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    local score = 0
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        if plate:IsShown() then score = score + 10 + #(plate.margin or {}) end
    end
    if not bestScore or score > bestScore then best, bestScore = at, score end
end
local function Open() T.OpenDiaryPage(page, best.i, best.k) end
Open()
Check((page.layout or 0) >= 2, "setup: a page with two plates or more")

--------------------------------------------------------------------------
Section("with the mouse nothing is found, marked or leaned")

Check(not Pad.Input.Active(), "setup: the mouse")
Check(Look.parts[book] == nil or Look.parts[book].outline == nil, "an outline made with the mouse")
for i = 1, page.layout do Check(not page.plates[i].padLean, "a plate leaned with the mouse") end

--------------------------------------------------------------------------
Section("the pad in hand: A on the level's rubric crosses to its plates")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
-- (the pad shows one level: the page drawn again on it)
Open()
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group) return Scope().focus.groups[group].items end
local function Legend()
    local out = {}
    for _, e in ipairs(Scope().legend(Scope())) do out[type(e[1]) == "table" and e[1][1] or e[1]] = e[2] end
    return out
end

Eq(Scope().key, "yourdiary", "the top scope")
Eq(At().key, "rubric", "setup: the pad on the rubric")
local platePlain = Colour(page.plates[1].heading)
Press("PAD1")
Eq(At().group, "page", "A on the rubric did not cross")
Eq(At().plate, 1, "the pad not on the first plate")
Eq(page.mode, "plates", "crossing changed the page")

--------------------------------------------------------------------------
Section("every plate and shown note is found, keyed once, with a centre")

local plates, notes, keys = 0, 0, {}
for _, item in ipairs(Items("page")) do
    Check(not keys[item.key], "a key twice: " .. item.key)
    keys[item.key] = true
    local x, y = item.center()
    Check(type(x) == "number" and type(y) == "number", "no centre: " .. item.key)
    if item.plate then plates = plates + 1 else notes = notes + 1 end
end
local shownPlates, shownNotes = 0, 0
for i = 1, page.layout do
    local plate = page.plates[i]
    if plate:IsShown() then
        shownPlates = shownPlates + 1
        for _, it in ipairs(plate.margin or {}) do
            if it.note and it.note:IsShown() then shownNotes = shownNotes + 1 end
        end
    end
end
Eq(plates, shownPlates, "the plates found")
Eq(notes, shownNotes, "the notes found")
Check(notes > 0, "setup: notes on the page")

--------------------------------------------------------------------------
Section("the active state: a red outline, a red shadow, the heading red")

local plate1 = page.plates[1]
local parts = Look.parts[book]
Check(parts and parts.outline, "no outline made")
local o = parts.outline
Check(o.line:IsShown() and o.shadow:IsShown(), "the outline or its shadow not shown")
Check(Red(plate1.heading), "the plate's heading not red")
Check((plate1.heading:GetShadowOffset()) ~= 1, "the plate's heading made bold")
Check(not parts.pen:IsShown(), "a pen box drawn round a plate")
for _, t in ipairs(o.line.strokes) do Check(t:IsShown(), "an edge of the outline missing") end
Check(o.shadow:GetFrameLevel() < plate1:GetFrameLevel(), "the shadow not under the plate")
Check(o.line:GetFrameLevel() > plate1:GetFrameLevel(), "the outline not over the plate")
Eq(Legend().PAD1, "Look at the marks", "A's prompt on a plate")
Eq(Legend().PAD3, "See the whole map", "X's prompt on a plate")
Eq(Legend().PAD2, "Back to the contents", "B's prompt on a plate")

--------------------------------------------------------------------------
Section("the pad moves by where things lie")

-- Every direction from every item lands on an item that way, or stays.
local moved = 0
for _, from in ipairs(Items("page")) do
    for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
        Scope().focus:Set(from)
        local fx, fy = from.center()
        Press(dir)
        local to = At()
        Eq(to.group, "page", "a move left the right page: " .. dir)
        if to ~= from then
            moved = moved + 1
            local x, y = to.center()
            local ok = (dir == "PADDUP" and y > fy) or (dir == "PADDDOWN" and y < fy)
                or (dir == "PADDLEFT" and x < fx) or (dir == "PADDRIGHT" and x > fx)
            Check(ok, "moved the wrong way: " .. from.key .. " " .. dir .. " " .. to.key)
        end
    end
end
Check(moved > 0, "the pad never moved")
-- Each one is reached from the first plate, by some way.
local reached, queue = { [Items("page")[1].key] = true }, { Items("page")[1] }
while #queue > 0 do
    local from = table.remove(queue, 1)
    for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
        Scope().focus:Set(from)
        Press(dir)
        if not reached[At().key] then
            reached[At().key] = true
            queue[#queue + 1] = At()
        end
    end
end
for _, item in ipairs(Items("page")) do Check(reached[item.key], "never reached: " .. item.key) end

-- On a note: its heading red, the plate's given back.
local note
for _, item in ipairs(Items("page")) do if not item.plate then note = item break end end
Scope().focus:Set(Items("page")[1])
Scope().focus:Set(note)
Check(not Red(plate1.heading), "the plate's heading kept its red")
Check(Red(note.heading), "the note's heading not red")
Check(o.line:IsShown(), "no outline on the note")
Check(o.shadow:GetFrameLevel() < note.frame:GetFrameLevel(), "the note's shadow over it")
if note.person then Eq(Legend().PAD1, "Go to their page", "A's prompt on a person's note") end
Check(Legend().PAD3 == nil, "X on a note")

--------------------------------------------------------------------------
Section("given back whole: unmarked, hidden, the mouse")

Scope().focus:Set(Items("page")[1])
Scope().focus:Set(note)
Look.Unmark(book)
Check(not Red(note.heading), "Unmark left the note's heading red")
Check(not o.line:IsShown() and not o.shadow:IsShown(), "Unmark left the outline")
Pad.Refresh()
Check(o.line:IsShown() and Red(note.heading), "not marked again on a refresh")
Look.Hide(book)
Check(not Red(note.heading) and not o.line:IsShown(), "Hide left the outline or the red")
Pad.Refresh()

--------------------------------------------------------------------------
Section("A on a plate goes into its marks; B backs out a level at a time")

Scope().focus:Set(Items("page")[1])
Press("PAD1")
Eq(At().group, "marks", "A on a plate did not go into its marks")
local marks = Items("marks")
Check(#marks > 0, "the plate has no marks found")
local mk = At()
Check(mk.ring and parts.pen:IsShown(), "the mark not ringed")
Check(not o.line:IsShown(), "an outline round a mark")
Check(plate1.padLean, "the plate does not lean in")
-- (its lean run to the end, as the client's frames would)
local function Lean(plate)
    for _ = 1, 40 do
        local step = plate.clip:GetScript("OnUpdate")
        if not step then break end
        step(plate.clip, 0.05)
    end
    return plate.zoom
end
Eq(Lean(plate1), 1, "the plate not leaned in among its marks")
Check(GameTooltip.shown, "the mark's tooltip not shown")
Check(Red(plate1.heading), "the plate's heading not red over its marks")
Eq(Legend().PAD3, "See the whole map", "X's prompt on a mark")
Eq(Legend().PAD2, "Back to the plate", "B's prompt on a mark")
local mkeys = {}
for _, m in ipairs(marks) do
    Check(not mkeys[m.key], "a mark keyed twice: " .. m.key)
    mkeys[m.key] = true
    Check(m.frame.tip ~= nil or m.frame:GetScript("OnEnter") ~= nil, "a mark with no tooltip")
end
-- None of the trail's pools.
for _, m in ipairs(marks) do Check(m.frame.what ~= "pool", "a pool walked") end
if #marks > 1 then
    local before = At()
    for _, dir in ipairs({ "PADDDOWN", "PADDRIGHT", "PADDUP", "PADDLEFT" }) do
        Press(dir)
        if At() ~= before then break end
    end
    Check(At() ~= before, "the pad never moved among the marks")
    Eq(At().group, "marks", "a move left the marks")
end
-- A on a mark does nothing (no card editor: that is Y's, tests/pad_cards.lua;
-- no item to chat).
local CardSheet = ns.UI.YourDiary.CardSheet
Press("PAD1")
Eq(At().group, "marks", "A on a mark went somewhere")
Check(not (CardSheet.View() and CardSheet.View():IsShown()), "A on a mark opened the card editor")
Press("PAD2")
Eq(At().group, "page", "B on a mark did not go back to the plate")
Eq(At().plate, 1, "B on a mark not back on its plate")
Check(not plate1.padLean, "the plate still leans")
Eq(Lean(plate1), 0, "the plate not leaned back out")
Check(not GameTooltip.shown, "the mark's tooltip left up")
Press("PAD2")
Eq(At().key, "rubric", "B on the plates did not come back to the row")
Check(not Red(plate1.heading), "the plate's heading kept its red on the left page")
Check(SameColour(Colour(plate1.heading), platePlain), "the plate's heading not given back exactly")
Check(book:IsShown(), "B on the plates closed the book")

--------------------------------------------------------------------------
Section("X opens the whole map, from a plate or a mark; B comes back")

Press("PAD1")
local second = Items("page")[2] and Items("page")[2].plate and Items("page")[2] or Items("page")[1]
Scope().focus:Set(second)
local mapID = page.plates[second.plate].mapID
Press("PAD3")
Eq(page.mode, "full", "X on a plate did not open the whole map")
Eq(page.fullMap, mapID, "the whole map not the plate's zone")
Eq(Legend().PAD2, "Back to the plates", "B's prompt on the whole map")
Press("PAD2")
Eq(page.mode, "plates", "B on the whole map did not come back")
Eq(At().key, second.key, "B did not come back to the plate X was pressed on")

Scope().focus:Set(Items("page")[1])
Press("PAD1")
local onMark = At().key
Press("PAD3")
Eq(page.mode, "full", "X on a mark did not open the whole map")
Check(not plate1.padLean, "a plate leans under the whole map")
Press("PAD2")
Eq(page.mode, "plates", "B on the whole map did not come back (from a mark)")
Eq(At().group, "marks", "B did not come back among the marks")
Eq(At().key, onMark, "B did not come back to the mark X was pressed on")
Check(plate1.padLean, "back on the mark, the plate does not lean")
-- X with the pad on the left page goes on to the game.
Press("PAD2")
Press("PAD2")
Eq(At().group, "left", "setup: back on the left page")
Check(Press("PAD3"), "X on the left page was taken")

--------------------------------------------------------------------------
Section("the mouse takes over cleanly")

Press("PAD1")
Press("PAD1")
Eq(At().group, "marks", "setup: among the marks")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the ring left with the mouse")
Check(not o.line:IsShown() and not o.shadow:IsShown(), "the outline left with the mouse")
for i = 1, page.layout do
    local plate = page.plates[i]
    Check(not plate.padLean, "a plate left leaning with the mouse")
    if plate:IsShown() then Check(not Red(plate.heading), "a heading left red with the mouse") end
end
Check(not GameTooltip.shown, "the mark's tooltip left with the mouse")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")

--------------------------------------------------------------------------
Section("a feature's card and marks are found with no pad code")

-- Its card: a paper strip with a card's hooks, written in every margin.
Margin.Register("padscrap", {
    order = 5, pool = "padscrapPool",
    new = function(parent) return ns.UI.PaperStrip(parent, { plan = function() end }) end,
    item = function(plate)
        local s = plate.slot
        return { top = s.y, x = s.x }
    end,
    write = function(note, it, c)
        note:SetNote({ name = "Scrap", what = "made up", seed = c.Seed("padscrap"), tip = function() return { { "Scrap" } } end })
    end,
    mark = function(it) return { it.x, it.top } end,
})
Open()
Scope().focus:Set(Items("page")[1])
local found
for _, item in ipairs(Items("page")) do
    if item.key:find(":padscrap:", 1, true) then found = item end
end
Check(found ~= nil, "the feature's card not found")
if found then
    Scope().focus:Set(found)
    Check(Red(found.heading), "the feature's card's heading not red")
    Eq(found.heading:GetText(), "Scrap", "the card's heading not its name")
    Check(o.line:IsShown(), "the feature's card not outlined")
    Check(GameTooltip.shown, "the feature's card's tooltip not shown")
end
Margin.Remove("padscrap")
Open()
-- Its marks: every registered kind drawn on a testdata plate is walked.
local kinds = {}
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        if plate:IsShown() then
            for _, m in ipairs(plate:Marks()) do kinds[m.what] = true end
        end
    end
end
local registered = 0
for kind in pairs(Plate.MARKS) do if kinds[kind] then registered = registered + 1 end end
Check(registered >= 3, "the features' marks not found on the plates")
Check(kinds.person and kinds.cross, "the core's marks not found")
Check(not kinds.pool, "the trail's pools found")

--------------------------------------------------------------------------
Section("B closes the book from the left page")

Open()
Scope().focus:EnterGroup("left")
Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")
