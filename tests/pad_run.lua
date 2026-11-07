-- A run's page with the pad (UI/Journey/Pad.lua's group `run`, the hits'
-- `pad` in UI/Journey/Run.lua, the spread's stand-in scope in
-- UI/Dungeon/Pad.lua; .claude/controller-plan.md, step 4e): A on a run's
-- line opens its page and the pad goes onto its title; everything on it is
-- walked by where it lies, each with its own tooltip; A on a signature
-- opens their page; a keepsake shows the item's tooltip and A on it is never
-- a click (no item to chat); A on the title lays the run out and B puts it
-- away, the pad back on the title; B goes back to the run's line, then the
-- book closes; the mouse takes over cleanly.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Look = Pad.Look
local YourDiary = ns.UI.YourDiary
local J = ns.UI.Journal
local DungeonPage = ns.UI.DungeonPage

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

local catcher = Pad.Catcher(book)
-- (true: the press went on past the catcher, to the game)
local function Press(key, on)
    local went = mock.PadPress(on or catcher, key, true)
    mock.PadPress(on or catcher, key, false)
    return went
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group) return Scope().focus.groups[group].items end
local function Legend()
    local out = {}
    for _, e in ipairs(Scope().legend(Scope())) do out[type(e[1]) == "table" and e[1][1] or e[1]] = e[2] end
    return out
end

--------------------------------------------------------------------------
Section("with the mouse nothing is told to the pad")

Check(not Pad.Input.Active(), "setup: the mouse")
local e = page.recap.entries[page.open]
-- (the run with the most keepsakes: the richest page)
local RUN, most
for _, p in ipairs(e.pieces or {}) do
    for _, visit in ipairs(p.runs or {}) do
        local n = #ns.DungeonRun.Keepsakes(visit, ns.Diary.IsDiary).shown
        if not most or n > most then RUN, most = visit, n end
    end
end
Check(most and most >= 1, "setup: a run with keepsakes")
Check(RUN, "setup: the newest level has a run with a page")
YourDiary.OpenRun(RUN.id, page.open)
Eq(page.mode, "run", "setup: the run's page open")
Check(#YourDiary.RunParts() >= 3, "the run's page tells fewer than three parts")
Check(Look.parts[book] == nil or not Look.parts[book].pen:IsShown(), "a box drawn with the mouse")
YourDiary.OpenLevel(page.open)

-- The pad in hand.
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(Scope().key, "yourdiary", "setup: the top scope")

--------------------------------------------------------------------------
Section("A on a run's line opens its page, and the pad goes onto its title")

local lineKey = "run:" .. tostring(RUN.id)
Press("PADDDOWN")
Check(Scope().focus:Focus(lineKey, "left"), "the run's line is not on the left page")
local L = Legend()
Eq(L.PAD1, "Open", "A's prompt on the run's line")
Press("PAD1")
Eq(page.mode .. ":" .. tostring(page.runVisit), "run:" .. RUN.id, "A did not open the run's page")
Eq(At().group, "run", "the pad stayed on the left page")
Eq(At().key, "title", "the pad not on the run's title")
local parts = Look.parts[book]
Check(parts.pen:IsShown(), "the title not boxed")
Check(GameTooltip.shown, "the title's tooltip not shown")
L = Legend()
Eq(L.PAD1, "Open the map", "A's prompt on the title")
Eq(L.PAD2, "Back to the contents", "B's prompt on the run's page")
Check(L.PAD4 == nil, "Y offered on the run's page")
Check(Press("PAD4"), "Y taken on the run's page")
Check(Press("PAD3"), "X taken on the run's page")

--------------------------------------------------------------------------
Section("everything on it is found once, each kind, walked by where it lies")

local kinds, keys = {}, {}
for _, item in ipairs(Items("run")) do
    Check(not keys[item.key], "a key twice: " .. item.key)
    keys[item.key] = true
    kinds[item.kind] = (kinds[item.kind] or 0) + 1
    local x, y = item.center()
    Check(type(x) == "number" and type(y) == "number", "no centre: " .. item.key)
end
Eq(kinds.title, 1, "the title")
Eq(kinds.keepsake, #page.run.keepsakes.shown, "every keepsake")
Eq(kinds.scrap, page.run.plan.scrap and 1 or nil, "the map scrap")
Eq(kinds.slip, page.run.plan.slip and 1 or nil, "the slip of the rest")
local _, deaths = ns.DungeonRun.Fallen(RUN)
Eq(kinds.fallen, deaths > 0 and 1 or nil, "the fallen note")
Check((kinds.sig or 0) >= 1, "no signature")
-- Every hit the mouse can hover that does something is the pad's too.
local hits = page.run.used.hit
local told = 0
for i = 1, hits.n do if hits[i].pad then told = told + 1 end end
Eq(told, hits.n, "a hit on the run's page the pad cannot reach")

-- From the title the D-pad reaches every part (each part's four ways
-- followed, as a reader would walk them).
local seen, queue = { title = true }, { "title" }
while #queue > 0 do
    local from = table.remove(queue, 1)
    for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
        Scope().focus:Focus(from, "run")
        Press(dir)
        local to = At().key
        Eq(At().group, "run", "the D-pad left the run's page from " .. from)
        if not seen[to] then
            seen[to] = true
            queue[#queue + 1] = to
        end
    end
end
for key in pairs(keys) do Check(seen[key], "the D-pad never reaches " .. key) end
Eq(page.mode, "run", "left or right turned the level on the run's page")

--------------------------------------------------------------------------
Section("a keepsake: outlined, its item's tooltip, and A is never a click")

local keepsake
for _, item in ipairs(Items("run")) do if item.kind == "keepsake" then keepsake = keepsake or item end end
Check(keepsake, "setup: a keepsake")
Check(Scope().focus:Focus(keepsake.key, "run"), "setup: onto a keepsake")
Check(parts.outline and parts.outline.line:IsShown(), "a keepsake not outlined")
Check(not parts.pen:IsShown(), "a keepsake boxed as words")
Eq(GameTooltip.link, keepsake.frame.item.item, "a keepsake's item tooltip not shown")
local handed = {}
_G.IsModifiedClick = function() return true end
_G.HandleModifiedItemClick = function(link) handed[#handed + 1] = link return true end
Check(not Press("PAD1"), "A on a keepsake went on to the game")
Eq(#handed, 0, "A on a keepsake, a modifier held, handed its link to the game")
_G.IsModifiedClick, _G.HandleModifiedItemClick = nil, nil
L = Legend()
Check(L.PAD1 == nil, "A offered on a keepsake")
Check(L.PAD4 == nil, "Y (to chat) offered on a keepsake")
for _, key in ipairs({ "PADLSHOULDER", "PADRSHOULDER" }) do
    Check(L[key] ~= "Link in chat", "a chat prompt")
end

--------------------------------------------------------------------------
Section("A on a signature in the diary opens their page")

local sig
for _, item in ipairs(Items("run")) do if item.kind == "sig" and item.kept then sig = sig or item end end
if sig then
    Check(Scope().focus:Focus(sig.key, "run"), "setup: onto a signature")
    Check(parts.pen:IsShown(), "a signature not boxed")
    Check(Red(sig.words), "a signature's name not red")
    Check(GameTooltip.shown, "a signature's tooltip not shown")
    Eq(Legend().PAD1, "Go to their page", "A's prompt on a signature")
    local went
    local was = YourDiary.ToPerson
    YourDiary.ToPerson = function(guid) went = guid end
    Press("PAD1")
    YourDiary.ToPerson = was
    Eq(went, sig.frame.box.guid, "A on a signature did not open their page")
else
    Check(true, "no signature in the diary on this run")
end

-- A stranger's "+ Add": the pad goes onto their signature once kept.
local add
for _, item in ipairs(Items("run")) do if item.kind == "add" then add = add or item end end
if add then
    Check(Scope().focus:Focus(add.key, "run"), "setup: onto + Add")
    Eq(Legend().PAD1, "Add to the diary", "A's prompt on + Add")
    local guid = add.key:match("^add:(.+)$")
    local was = ns.DungeonRun.Keep
    ns.DungeonRun.Keep = function() return nil end
    Press("PAD1")
    ns.DungeonRun.Keep = was
    Eq(Scope().focus.remembered.run, "sig:" .. guid, "A on + Add does not put the pad onto their signature")
end

--------------------------------------------------------------------------
Section("A on the title lays the run out; B puts it away, back on the title")

Check(Scope().focus:Focus("title", "run"), "setup: onto the title")
Press("PAD1")
Check(J.visit and J.visit.id == RUN.id, "A on the title did not lay the run out")
local spread = DungeonPage.Spread()
Check(spread and spread:IsShown(), "the spread not shown")
Eq(Pad.Top() and Pad.Top().key, "spread", "the spread's scope has not the pad")
Check(not catcher:IsGamePadButtonEnabled(), "the book still takes the pad under the table")
local sc = Pad.Catcher(spread)
Check(sc:IsGamePadButtonEnabled(), "the table takes no pad")
Check(not parts.pen:IsShown(), "the title still boxed under the table")
-- (4f: the table's own scope; the first run out brings its note, which B
-- takes first: tests/pad_dungeon.lua walks the rest)
local note = DungeonPage.TutorialNote()
if note and note:IsShown() then
    Press("PAD2", sc)
    Check(not note:IsShown() and J.visit, "B did not take the note first")
end
Check(not Press("PADDDOWN", sc), "the D-pad not the table's")
Eq(page.mode, "run", "the page under the table changed")
Press("PAD2", sc)
Eq(J.visit, nil, "B did not put the run away")
Eq(Scope().key, "yourdiary", "the pad not back on the book")
Eq(At().group .. ":" .. At().key, "run:title", "the pad not back on the title")
Check(parts.pen:IsShown(), "the title not boxed again")
Check(catcher:IsGamePadButtonEnabled(), "the book takes no pad again")
-- Escape (UISpecialFrames) puts it away just as well.
Press("PAD1")
Eq(Pad.Top().key, "spread", "setup: out again")
DungeonPage.Close()
Eq(At().group .. ":" .. At().key, "run:title", "put away by the bookmark or Escape: not back on the title")

--------------------------------------------------------------------------
Section("B: back to the run's line, then the book closes")

Press("PAD2")
Eq(At().group, "left", "B on the run's page did not go to the left page")
Eq(At().key, lineKey, "B not back on the run's line")
Eq(page.mode, "run", "B changed the right page")
-- A on the line again: straight over, nothing opened again.
local plan = page.run.plan
Press("PAD1")
Eq(At().group, "run", "A on the line showing its run did not cross")
Check(page.run.plan == plan, "the run's page drawn again for nothing")
Press("PAD2")
Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")

--------------------------------------------------------------------------
Section("the mouse takes over cleanly")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
YourDiary.OpenRun(RUN.id, page.open)
Pad.Refresh()
Scope().focus:Focus(lineKey, "left")
Press("PAD1")
Eq(At().group, "run", "setup: on the run's page")
Check(Scope().focus:Focus(keepsake.key, "run"), "setup: onto a keepsake")
parts = Look.parts[book]
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the box left with the mouse")
Check(not parts.outline.line:IsShown() and not parts.outline.shadow:IsShown(), "the outline left with the mouse")
Check(not GameTooltip.shown, "the keepsake's tooltip left with the mouse")
Check(not catcher:IsGamePadButtonEnabled(), "the book still takes the pad")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")
Eq(At().key, keepsake.key, "the pad not back where it was")
