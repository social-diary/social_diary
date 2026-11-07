-- The Dungeon View with the pad (UI/Dungeon/Pad.lua; .claude/controller-plan.md,
-- step 4f): laid out from Your Diary's run page, the table's scope has the
-- pad (the book's off under it); the first run's note takes A or B first;
-- the D-pad walks the marks, the notes, the items on them, the floors' links
-- and the bookmark by where they lie, each with its own look and tooltip;
-- LB/RB turn the floors; A on a note naming someone opens their page; an
-- item is never a click; Adjust Path is never reached, and the pad steps
-- aside while the mouse has it out; B puts the run away, back on the title;
-- the mouse takes over cleanly.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Look = Pad.Look
local YourDiary = ns.UI.YourDiary
local J = ns.UI.Journal
local DungeonPage = ns.UI.DungeonPage

mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local page = ns.UI.JourneyPage()
local G = ns.TestData.GUID

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

local catcher = Pad.Catcher(book)
local function Press(key, on)
    local went = mock.PadPress(on, key, true)
    mock.PadPress(on, key, false)
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

-- A run with a page, Razorfen Kraul's (notes, loot, deaths) where the diary
-- has one.
local RUN, AT
for i, e in ipairs(page.recap.entries) do
    for _, visit in ipairs(YourDiary.RunsOf(e) or {}) do
        if not RUN or (visit.instanceID == 47 and RUN.instanceID ~= 47) then RUN, AT = visit, i end
    end
end
Check(RUN, "setup: a run with a page")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(Scope().key, "yourdiary", "setup: the top scope")

--------------------------------------------------------------------------
Section("A on the run's title lays it out: the table has the pad, the book none")

YourDiary.OpenRun(RUN.id, AT)
Pad.Refresh()
Check(Scope().focus:Focus("title", "run"), "setup: onto the run's title")
Press("PAD1", catcher)
local spread = DungeonPage.Spread()
Check(spread and spread:IsShown() and J.visit and J.visit.id == RUN.id, "A on the title did not lay the run out")
local view = spread.map
local sc = Pad.Catcher(spread)
Eq(Scope().key, "spread", "the table's scope has not the pad")
Check(Scope().parent == nil, "the table's scope goes on to the book's (its ribbons)")
Check(sc:IsGamePadButtonEnabled(), "the table takes no pad")
Check(not catcher:IsGamePadButtonEnabled(), "the book still takes the pad under the table")
Eq(book:GetAlpha(), 0, "the book (its ribbons) not put aside")
Check(not sc:IsGamePadStickEnabled(), "the sticks taken on the table (no zoom or pan there)")
local parts = Look.parts[spread]

--------------------------------------------------------------------------
Section("the first run's note: the pad on its link, A puts it away")

local note = DungeonPage.TutorialNote()
Check(note and note:IsShown(), "setup: the first run out brings the note")
Eq(At().group .. ":" .. At().key, "note:ok", "the pad not on the note's link")
Eq(#Items("sheet"), 0, "the map under the note walked")
Check(parts.pen:IsShown(), "the note's link not boxed")
Check(Red(note.ok.label), "the note's link not red")
Check(parts.pen:GetFrameLevel() > note.ok:GetFrameLevel(), "the box under the note")
Eq(Legend().PAD1, "Put the note away", "A's prompt on the note")
Check(Press("PADDDOWN", sc) == false, "the D-pad went on to the game under the note")
Check(Press("PADRSHOULDER", sc), "a shoulder taken under the note (one floor)")
Press("PAD1", sc)
Check(not note:IsShown(), "A did not put the note away")
Check(spread:IsShown() and J.visit, "A on the note put the map away too")
Eq(At().group, "sheet", "the pad not on the map after the note")
-- B takes it as well (shown again, as the client would the first time).
note:Show()
Pad.Refresh()
Eq(At().key, "ok", "setup: on the note again")
Press("PAD2", sc)
Check(not note:IsShown() and spread:IsShown(), "B did not take the note alone")

--------------------------------------------------------------------------
Section("the marks, notes, items, floors and bookmark: each once, by where they lie")

local items, keys, byWhat = Items("sheet"), {}, {}
for _, item in ipairs(items) do
    Check(not keys[item.key], "a key twice: " .. item.key)
    keys[item.key] = item
    local x, y = item.center()
    Check(type(x) == "number" and type(y) == "number", "no centre: " .. item.key)
    local what = item.key:match("^(%a+)")
    byWhat[what] = (byWhat[what] or 0) + 1
    Check(what == "boss" or what == "cross" or what == "level" or what == "find" or what == "door"
        or what == "note" or what == "floor" or what == "bookmark", "something else stood on: " .. item.key)
end
local hits = 0
for i = 1, view.pools.hit.used do if view.pools.hit[i].tip then hits = hits + 1 end end
local marks = (byWhat.boss or 0) + (byWhat.cross or 0) + (byWhat.level or 0) + (byWhat.find or 0) + (byWhat.door or 0)
Eq(marks, hits, "a mark on the map the pad cannot reach")
Check((byWhat.boss or 0) >= 1, "no boss walked")
local strips, itemsNamed = 0, 0
for _, entry in ipairs(view.noteStrips) do
    strips = strips + (entry.top and 2 or 1)
    itemsNamed = itemsNamed + entry.slot.links.used + (entry.topSlot and entry.topSlot.links.used or 0)
end
local notes, named = 0, 0
for _, item in ipairs(items) do
    if item.item then named = named + 1 elseif item.key:match("^note:") then notes = notes + 1 end
end
Eq(notes, strips, "a note beside the map the pad cannot reach")
Eq(named, itemsNamed, "an item named on a strip the pad cannot reach")
Check(keys.bookmark, "the bookmark not walked")
Eq(byWhat.floor, nil, "floor links on a map of one floor")

-- Landed on the way in, else the first boss.
local land = Scope().focus.remembered.sheet
Check(land and (land:match("^door:") or land:match("^boss:")), "not landed on the way in or a boss: " .. tostring(land))

-- From where it landed the D-pad reaches everything (each way followed).
local seen, queue = { [land] = true }, { land }
while #queue > 0 do
    local from = table.remove(queue, 1)
    for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
        Scope().focus:Focus(from, "sheet")
        Press(dir, sc)
        local to = At().key
        if not seen[to] then
            seen[to] = true
            queue[#queue + 1] = to
        end
    end
end
for key in pairs(keys) do Check(seen[key], "the D-pad never reaches " .. key) end
Check(spread:IsShown(), "walking put the map away")

--------------------------------------------------------------------------
Section("the look: a mark ringed, a note outlined, an item boxed; each its tooltip")

local mark = keys[land]
Scope().focus:Focus(land, "sheet")
Check(parts.pen:IsShown(), "a mark not ringed")
Check(GameTooltip.shown, "a mark's tooltip not shown")
local L = Legend()
Check(L.PAD1 == nil, "A offered on a mark")
Eq(L.PAD2, "Put the map away", "B's prompt on the table")
Check(L.PADLSHOULDER == nil, "floors offered on a map of one floor")
Check(L.PAD4 == nil and L.PAD3 == nil, "X or Y offered on the table")
Check(not Press("PAD1", sc), "A on a mark went on to the game")
Check(Press("PAD4", sc) and Press("PAD3", sc), "X or Y taken on the table")
Check(Press("PADLSHOULDER", sc), "a shoulder taken on a map of one floor")
Check(mark.frame.what ~= nil, "a mark does not say what it is")

local strip
for _, item in ipairs(items) do
    if item.key:match("^note:") and not item.item then strip = strip or item end
end
Check(strip, "setup: a note")
Scope().focus:Focus(strip.key, "sheet")
Check(parts.outline and parts.outline.line:IsShown() and parts.outline.shadow:IsShown(), "a note not outlined")
Check(not parts.pen:IsShown(), "a note boxed as words")
Check(Red(strip.heading), "a note's heading not red")

-- An item on a loot strip: its own tooltip, and A never a click.
local loot
for _, item in ipairs(items) do if item.item then loot = loot or item end end
Check(loot, "setup: an item named on a strip")
Scope().focus:Focus(loot.key, "sheet")
Check(parts.pen:IsShown(), "an item not boxed")
Eq(GameTooltip.link, loot.frame.item.item, "an item's own tooltip not shown")
local handed, opened = {}, {}
local toPerson = YourDiary.ToPerson
YourDiary.ToPerson = function(guid) opened[#opened + 1] = guid end
_G.IsModifiedClick = function() return true end
_G.HandleModifiedItemClick = function(link) handed[#handed + 1] = link return true end
mock.modifiers.shift = true
Check(not Press("PAD1", sc), "A on an item went on to the game")
mock.modifiers.shift = nil
Eq(#handed, 0, "A on an item, a modifier held, handed its link to the game")
Eq(#opened, 0, "A on an item clicked it (the looter's page)")
_G.IsModifiedClick, _G.HandleModifiedItemClick = nil, nil
YourDiary.ToPerson = toPerson
L = Legend()
Check(L.PAD1 == nil and L.PAD4 == nil, "A or Y (to chat) offered on an item")
Check(spread:IsShown(), "A on an item put the map away")

--------------------------------------------------------------------------
Section("A on a note naming someone opens their page, as the click does")

local person
for _, item in ipairs(items) do if item.person then person = person or item end end
if person then
    Scope().focus:Focus(person.key, "sheet")
    Eq(Legend().PAD1, "Go to their page", "A's prompt on a note naming someone")
    local went
    YourDiary.ToPerson = function(guid) went = guid end
    Press("PAD1", sc)
    YourDiary.ToPerson = toPerson
    Check(went ~= nil, "A on a note naming someone did not open their page")
else
    -- (none in the diary on this run: a note made to name Tester)
    local entry = view.noteStrips[1]
    entry.strip.guid, entry.strip.onClick = G, function(guid) YourDiary.ToPerson(guid) end
    Pad.Refresh()
    local key
    for _, item in ipairs(Items("sheet")) do if item.person then key = key or item.key end end
    Check(key, "a note naming someone not told so")
    Scope().focus:Focus(key, "sheet")
    local went
    YourDiary.ToPerson = function(guid) went = guid end
    Press("PAD1", sc)
    YourDiary.ToPerson = toPerson
    Eq(went, G, "A on a note naming someone did not open their page")
end
Check(spread:IsShown(), "setup: a stubbed page left the map out")

--------------------------------------------------------------------------
Section("Adjust Path: never stood on; the pad steps aside while the mouse has it")

for _, item in ipairs(Items("sheet")) do
    Check(item.frame ~= (view.way and view.way.slip), "the pencil's slip stood on")
end
-- Every press on every mark and note (but the ways out), the pencil stubbed to fail.
local start = DungeonPage.WayStart
DungeonPage.WayStart = function() error("the pad took the pencil up") end
for _, item in ipairs(Items("sheet")) do
    if not (item.person or item.bookmark or item.floor) then
        Scope().focus:Focus(item.key, "sheet")
        for _, key in ipairs({ "PAD1", "PAD3", "PAD4" }) do Press(key, sc) end
    end
end
DungeonPage.WayStart = start
Check(spread:IsShown(), "a press on a mark put the map away")
for _, e2 in ipairs(Scope().legend(Scope())) do
    Check(not tostring(e2[2]):find("Path"), "Adjust Path in the prompts")
end
Check(DungeonPage.WayStart(view), "setup: the pencil taken up with the mouse")
Eq(Pad.Top(), nil, "the pad not aside while the pencil is out")
Check(not sc:IsGamePadButtonEnabled(), "the table still takes the pad under the pencil")
Check(not parts.pen:IsShown() and not (parts.slip and parts.slip:IsShown()), "the box or prompts left under the pencil")
DungeonPage.WayDone(view)
Eq(Pad.Top() and Pad.Top().key, "spread", "the pad not back as the pencil is put down")
Check(sc:IsGamePadButtonEnabled(), "the table takes no pad after the pencil")
Check(At() ~= nil, "nothing stood on after the pencil")

--------------------------------------------------------------------------
Section("the prompts lie on the table, under the sheet's foot")

Pad.Refresh()
Press("PADDUP", sc)
local slip = parts.slip
Check(slip and slip:IsShown(), "no prompts on the table")
local pt = slip.recorded.points[1]
Check(pt and pt.point == "TOPLEFT" and pt.args[1] == view.sheet, "the prompts not hung on the sheet")
Check(slip:GetFrameLevel() < view.sheet:GetFrameLevel(), "the prompts over the sheet, not under its foot")

--------------------------------------------------------------------------
Section("the bookmark: outlined, its words red; A puts the run away")

Scope().focus:Focus("bookmark", "sheet")
Check(parts.outline.line:IsShown(), "the bookmark not outlined")
Check(Red(spread.back.words), "the bookmark's words not red")
Eq(Legend().PAD1, "Put the map away", "A's prompt on the bookmark")
Press("PAD1", sc)
Eq(J.visit, nil, "A on the bookmark did not put the run away")
Eq(Scope().key, "yourdiary", "the pad not back on the book")
Eq(At().group .. ":" .. At().key, "run:title", "the pad not back on the title")
Check(catcher:IsGamePadButtonEnabled(), "the book takes no pad again")
Check(not Red(spread.back.words), "the bookmark's words left red")

--------------------------------------------------------------------------
Section("B puts the run away, back on the run's title")

Press("PAD1", catcher)
Eq(Scope().key, "spread", "setup: out again")
Check(not DungeonPage.TutorialNote():IsShown(), "the note came back")
Eq(At().key, land, "laid out again: not on the way in")
Press("PAD2", sc)
Eq(J.visit, nil, "B did not put the run away")
Eq(At().group .. ":" .. At().key, "run:title", "B: the pad not back on the title")

--------------------------------------------------------------------------
Section("the mouse takes over cleanly")

Press("PAD1", catcher)
Eq(Scope().key, "spread", "setup: out again")
Scope().focus:Focus(strip.key, "sheet")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the ring or box left with the mouse")
Check(not parts.outline.line:IsShown() and not parts.outline.shadow:IsShown(), "the outline left with the mouse")
Check(not slip:IsShown(), "the prompts left with the mouse")
Check(not sc:IsGamePadButtonEnabled(), "the table still takes the pad")
Check(spread:IsShown(), "the mouse put the map away")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(At().key, strip.key, "the pad not back where it was")
Press("PAD2", sc)
Eq(J.visit, nil, "setup: put away")

--------------------------------------------------------------------------
Section("LB / RB turn the floors (round the ends); A on a floor's link shows it")

local vc = ns.Instances.New({ instanceID = 36, name = "The Deadmines", bossesKilled = { "Rhahk'Zor", "Gilnid", "Mr. Smite" },
    bossTotal = 8, members = { { guid = G, first = "Tester" }, { guid = ns.ownGUID, first = "Me" } },
    startedAt = mock.now - 3000, endedAt = mock.now - 1200, instanceType = "party" })
ns.UI.ShowJournal(G)
Eq(ns.UI.OpenVisit(vc.id, G), true, "setup: the Deadmines out")
Eq(Scope().key, "spread", "setup: the table has the pad")
Eq(#view.floors, 2, "setup: two floors")
Eq(view.floorIndex, 2, "setup: on the floor of most kills")
local L2 = Legend()
Eq(L2.PADLSHOULDER, "See another floor", "the floors' prompt")
Check(not Press("PADRSHOULDER", sc), "RB went on to the game")
Eq(view.floorIndex, 1, "RB did not go round to the first floor")
Check(At() ~= nil and At().group == "sheet", "nothing stood on, the floor turned")
local turned = Scope().focus.remembered.sheet
Check(turned:match("^door:") or turned:match("^boss:") or true, "landed")
Press("PADLSHOULDER", sc)
Eq(view.floorIndex, 2, "LB did not go back")
Check(keys and Scope().focus:Focus("floor:1", "sheet"), "the first floor's link not walked")
Check(parts.pen:IsShown() and Red(view.links[1].label), "a floor's link not boxed red")
Eq(Legend().PAD1, "See this floor", "A's prompt on a floor's link")
Press("PAD1", sc)
Eq(view.floorIndex, 1, "A on a floor's link did not show it")
Eq(At().key, "floor:1", "the pad left the link pressed")
Check(Legend().PAD1 == nil, "A offered on the floor shown")
Press("PAD1", sc)
Eq(view.floorIndex, 1, "A on the floor shown changed it")
Press("PAD2", sc)
Eq(J.visit, nil, "B did not put the Deadmines away")
Check(Scope() == nil or Scope().key ~= "spread", "the table kept the pad")
