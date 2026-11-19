-- Custom cards with the pad (UI/Journey/CardPad.lua, Y in UI/Journey/Pad.lua,
-- CardSheet.PadRight; .claude/controller-plan.md, step 4c): Y on a card or its
-- mark opens its form; Y on a plate or another mark opens its menu on the
-- pad's slip (the page's own lines, and "Add custom event..." first where the
-- player stands, or, off this map, at the mark; on the plate itself no add),
-- its add line the picker; Y on a person's strip their menu;
-- the slip's controls are found and stepped, its lines written on with A, a
-- person's names picked from; B backs out to the very place Y was pressed; the
-- delete popup takes the pad from us; the mouse takes over.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local J = ns.Journey
local Pad = ns.UI.Pad

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

-- Level 10 on one zone (as tests/custom_cards_ui.lua's), a close call on it.
local t0 = now - 40000
local MAP = 1412
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = {}
j.open = nil
local function Seg(s)
    s.levelFrom, s.levelTo = s.levelFrom or 10, s.levelTo or 10
    j.segments[#j.segments + 1] = s
end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 1800 })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4000, mapID = MAP, x = 0.45, y = 0.55, r = 30, seconds = 1600,
    levelFrom = 11, levelTo = 11 })
j.levels[11] = { at = t0 + 2000, mapID = MAP, x = 0.45, y = 0.55 }
j.closeCalls = { { t = t0 + 900, mapID = MAP, x = 0.42, y = 0.58, level = 10, pct = 6, seconds = 42, took = 94,
    npcID = 2955, name = "Plainstrider", foeLevel = 7, foes = 3, display = 1961 } }
J.Touch()

-- The pad in hand, Your Diary open on level 10.
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YourDiary = ns.UI.YourDiary
local CardSheet = YourDiary.CardSheet
ns.UI.RefreshJourneyPage(true)
local function Level()
    for i, e in ipairs(page.recap.entries) do
        if e.level == 10 then return i, e end
    end
end
local function OpenLevel()
    local i = Level()
    YourDiary.OpenLevel(i)
end
OpenLevel()

local book = ns.UI.JournalFrame()
local catcher = Pad.Catcher(book)
local function Press(key)
    local went = mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
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
local function Sheet() return CardSheet.View() and CardSheet.View():IsShown() end
local function Plate() return page.plates[1] end
local function Card()
    for i = 1, page.killerPool.used do
        local c = page.killerPool[i]
        if c:IsShown() and c.foe then return c end
    end
end
local function Row(key)
    for _, row in ipairs(CardSheet.View().rows) do
        if row.field.key == key then return row end
    end
end
local function Stand(group, test)
    for _, item in ipairs(Items(group)) do
        if test(item) then
            Scope().focus:Set(item)
            return item
        end
    end
end
-- A close-up plate's Y opens its menu on the pad's slip (Pad.Menu: "Leave
-- this place out" and "Choose what's on this page...", with "Add custom
-- event..." first where a card can be added; choose-page.md, "Later: the
-- gamepad"). Its lines, and a line picked with the D-pad and A.
local ADD = ns.L["Add custom event..."]
local function MenuLines()
    local out = {}
    for _, item in ipairs(Items("menu")) do out[#out + 1] = item.element.text end
    return table.concat(out, " | ")
end
local function PickLine(text)
    for _ = 1, 10 do
        if At().element and At().element.text == text then break end
        Press("PADDDOWN")
    end
    Eq(At().element and At().element.text, text, "setup: the menu's line")
    Press("PAD1")
end
-- Not on the plate's map unless a test says so.
mock.mapID, mock.position = nil, nil

Eq(Scope().key, "yourdiary", "setup: the page's scope")
Eq(page.mode, "plates", "setup: plates")
Scope().focus:EnterGroup("page")

--------------------------------------------------------------------------
Section("Y on a card: its form, controls found in the order they lie")

local rec = j.closeCalls[1]
local onCard = Stand("page", function(item) return item.note == Card() end)
Check(onCard ~= nil, "setup: the close call's card among the page's things")
Eq(Legend().PAD4, "Change the card", "Y's prompt on a card")
Check(not Press("PAD4"), "Y on a card went on to the game")
Check(Sheet(), "Y on a card did not open its form")
Eq(CardSheet.View().rec, rec, "the form is not the card's record")
Eq(Scope().key, "cards", "the slip's scope has not the pad")
Eq(At().group, "form", "the pad not on the form")
Eq(At().key, "field:name", "the pad not on the first line")
Check(not Row("name").box:HasFocus(), "a line took the cursor by itself")

local keys = {}
for _, item in ipairs(Items("form")) do keys[#keys + 1] = item.key end
local order = table.concat(keys, " ")
-- (the spec's fields in its order: name, level, type's two boxes on one line,
-- then the rest; the links under them, Cancel left of Save)
Check(order:find("^field:name field:foeLevel tick:rank:rare tick:rank:elite field:foes field:pct") ~= nil,
    "the lines and boxes not in order: " .. order)
Check(order:find("field:pct link:Leave it out link:Cancel link:Save$") ~= nil, "the links not last: " .. order)
-- Down walks them all; each is boxed by the pen over the slip.
local parts = Pad.Look.parts[book]
local seen = 1
for _ = 2, #keys do
    Press("PADDDOWN")
    seen = seen + 1
    Eq(At().key, keys[seen], "down did not walk the form in order")
    Check(parts.pen:IsShown(), "no pen box on " .. At().key)
    Check(parts.pen:GetFrameLevel() > CardSheet.View().sheet:GetFrameLevel(), "the box under the slip")
end

--------------------------------------------------------------------------
Section("a line: A gives it the cursor, B or moving off takes it back")

Scope().focus:Focus("field:pct", "form")
local pct = Row("pct").box
Eq(Legend().PAD1, "Write", "A's prompt on a line")
Press("PAD1")
Check(pct:HasFocus(), "A did not give the line the cursor")
Eq(Legend().PAD1, "Done writing", "A's prompt while writing")
Eq(Legend().PAD2, "Stop writing", "B's prompt while writing")
Press("PAD2")
Check(not pct:HasFocus(), "B did not take the cursor back")
Check(Sheet(), "B while writing put the slip away")
Press("PAD1")
Check(pct:HasFocus(), "setup: writing again")
Press("PADDDOWN")
Check(not pct:HasFocus(), "moving off did not take the cursor back")

--------------------------------------------------------------------------
Section("a choice's box: A ticks and unticks")

Scope().focus:Focus("tick:rank:rare", "form")
Eq(Legend().PAD1, "Tick", "A's prompt on a box")
Press("PAD1")
Eq(Row("rank"):Get(), "rare", "A did not tick")
Eq(Legend().PAD1, "Untick", "A's prompt on a ticked box")
Press("PAD1")
Eq(Row("rank"):Get(), "", "A did not untick")

--------------------------------------------------------------------------
Section("B puts the slip away, back on the card Y was pressed on")

Eq(Legend().PAD2, "Put the card away", "B's prompt on the form")
Press("PAD2")
Check(not Sheet(), "B did not put the slip away")
Eq(rec.custom, nil, "putting it away wrote something")
Eq(Scope().key, "yourdiary", "the page has not the pad back")
Eq(At().key, onCard.key, "not back on the card")

--------------------------------------------------------------------------
Section("Save with A: written, back on the card")

Press("PAD4")
Row("pct"):Set("4")
Scope().focus:Focus("link:Save", "form")
Press("PAD1")
Check(not Sheet(), "Save did not put the slip away")
Eq(rec.custom and rec.custom.pct, 4, "Save did not write")
Eq(Scope().key, "yourdiary", "the page has not the pad back after Save")
Eq(At().key, onCard.key, "not back on the card after Save")

--------------------------------------------------------------------------
Section("Y on a mark of a card: its form; B back on the mark")

Stand("page", function(item) return item.plate == 1 end)
Press("PAD1")
Eq(At().group, "marks", "setup: among the marks")
local onMark = Stand("marks", function(item) return item.frame.spot and item.frame.spot.kind == "close" end)
Check(onMark ~= nil, "setup: the close call's mark")
Eq(Legend().PAD4, "Change the card", "Y's prompt on a card's mark")
Press("PAD4")
-- (changed now: its record merged with the change, CardSheet's `customOf`)
local opened = Sheet() and CardSheet.View().rec
Check(opened and (opened == rec or opened.customOf == rec), "Y on the mark did not open its card")
Press("PAD2")
Check(not Sheet(), "B did not put it away")
Eq(At().key, onMark.key, "not back on the mark")

--------------------------------------------------------------------------
Section("off this map: no add on the plate's menu; at the mark's spot on a mark")

Press("PAD2")
Eq(At().plate, 1, "setup: on the plate")
-- (the plate's menu still holds the page's own lines: Y opens it, no add)
Eq(Legend().PAD4, "Open the menu", "Y's prompt on a close-up plate with the player elsewhere")
Check(not Press("PAD4"), "Y on the plate went on to the game")
Check(not Sheet(), "Y opened the picker with the player elsewhere")
Check(ns.UI.Pad.Menu.IsOpen(), "Y on the plate did not open its menu")
Check(not MenuLines():find(ADD, 1, true), "an add line with the player elsewhere: " .. MenuLines())
Press("PAD2")
Check(not ns.UI.Pad.Menu.IsOpen(), "B did not put the menu away")
Eq(At().plate, 1, "not back on the plate from the menu")
-- In an instance on the zone's map: no position given, the same.
mock.mapID, mock.position, mock.inInstance = MAP, { x = 0.5, y = 0.5 }, true
Press("PAD4")
Check(not MenuLines():find(ADD, 1, true), "an add line in an instance")
Press("PAD2")
mock.mapID, mock.position, mock.inInstance = nil, nil, nil

-- A mark that is not a card's (the close call's, its spot taken off) lends
-- its own spot, as a right click on it would.
Press("PAD1")
local mark = Stand("marks", function(item) return item.key == onMark.key end)
local spot = mark.frame.spot
mark.frame.spot = nil
Eq(Legend().PAD4, "Open the menu", "Y on a mark not offered with the player elsewhere")
Press("PAD4")
Eq(MenuLines():match("^[^|]+"), ADD .. " ", "the add line not first on a mark's menu")
PickLine(ADD)
mark.frame.spot = spot
Check(Sheet(), "Y on the mark did not open the picker")
local where = CardSheet.View().where
Check(where and where.mapID == MAP, "not on the plate's map")
Check(where and math.abs(where.x - 0.42) < 0.03 and math.abs(where.y - 0.58) < 0.03,
    "not at the mark: " .. tostring(where and where.x) .. ", " .. tostring(where and where.y))
Press("PAD2")
Check(not Sheet(), "B on the picker did not put it away")
Eq(At().key, onMark.key, "not back on the mark from the picker")
Press("PAD2")

--------------------------------------------------------------------------
Section("on this map: Y on the plate adds a card where the player stands")

mock.mapID, mock.position = MAP, { x = 0.47, y = 0.53 }
Eq(At().plate, 1, "setup: on the plate")
Eq(Legend().PAD4, "Open the menu", "Y's prompt on a plate")
Press("PAD4")
PickLine(ADD)
Check(Sheet(), "the picker not open")
Check(CardSheet.View().list:IsShown(), "not the picker")
Eq(At().group, "picker", "the pad not on the picker")
Eq(At().kind, "cell", "the pad not on a strip")
Check(At().cell ~= nil and At().frame ~= nil, "the strip not found as the pad landed")
Check(parts.outline and parts.outline.line:IsShown(), "the strip not outlined")
local first = At().key
-- The grid as it lies: right along the row, down a row, down off the last
-- to Cancel and up again.
local grid = {}
for _, item in ipairs(Items("picker")) do
    if item.index then grid[item.index] = grid[item.index] or {}; grid[item.index][item.col] = item.key end
end
if grid[1][2] then
    Press("PADDRIGHT")
    Eq(At().key, grid[1][2], "right did not go along the row")
    Press("PADDLEFT")
    Eq(At().key, first, "left did not come back")
end
for _ = 1, #grid do Press("PADDDOWN") end
Eq(At().key, "link:Cancel", "down off the last row is not Cancel")
Press("PADDUP")
Eq(At().index, #grid, "up from Cancel not on the last row")
Eq(Legend().PAD1, "Choose", "A's prompt on a strip")
-- A on the close call's strip: its form, on its first line.
Scope().focus:Focus("kind:close", "picker")
Press("PAD1")
Check(not CardSheet.View().list:IsShown(), "A on a strip did not open its form")
Eq(At().group, "form", "the pad not on the form")
Eq(At().key, "field:name", "not on the form's first line")
Check(not Row("name").box:HasFocus(), "the new card's line took the cursor with the pad in hand")
-- "Choose another" goes back to the picker, on the kind chosen.
Scope().focus:Focus("link:Choose another", "form")
Press("PAD1")
Eq(At().key, "kind:close", "back on the picker not on the kind chosen")
Press("PAD1")
Row("name"):Set("Old Tom")
Scope().focus:Focus("link:Save", "form")
Press("PAD1")
Eq(#(j.custom or {}), 1, "the card not written")
local mine = j.custom[1]
Eq(mine.mapID, MAP, "not on the plate's map")
Check(math.abs(mine.x - 0.47) < 1e-6 and math.abs(mine.y - 0.53) < 1e-6, "not where the player stands")
Eq(Scope().key, "yourdiary", "the page has not the pad back")
mock.mapID, mock.position = nil, nil

--------------------------------------------------------------------------
Section("delete: the popup takes the pad, and gives it back")

local inserted
for i = 1, page.killerPool.used do
    local c = page.killerPool[i]
    if c:IsShown() and c.foe and c.foe.name == "Old Tom" then inserted = c end
end
Check(inserted ~= nil, "setup: the card written")
Scope().focus:EnterGroup("page")
local onMine = Stand("page", function(item) return item.note == inserted end)
Press("PAD4")
Check(Sheet() and CardSheet.View().rec and CardSheet.View().rec.inserted, "Y did not open the card written")
Check(Scope().focus:Focus("link:Delete this card", "form"), "no Delete among the controls")
Press("PAD1")
Eq(#j.custom, 1, "deleted without asking")
local dialog = StaticPopupDialogs.SOCIAL_DIARY_CONFIRM
local popup = {}
dialog.OnShow(popup)
Check(Pad.Top() == nil, "a scope has the pad with the popup up")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher takes buttons from the popup")
mock.AnswerPopup("accept")
dialog.OnHide(popup)
Eq(#j.custom, 0, "not deleted")
Check(not Sheet(), "the slip not put away")
Eq(Pad.Top() and Pad.Top().key, "yourdiary", "the pad not back after the popup")
Check(catcher:IsGamePadButtonEnabled(), "the catcher not back after the popup")
Check(onMine ~= nil, "setup: stood on it")

--------------------------------------------------------------------------
Section("a person's line: the names the search finds, picked with the D-pad")

do
    local guid = "Player-1-0AAAAAAA"
    ns.db.characters[guid] = { guid = guid, names = { { first = "Brannoc", surname = "" } } }
    ns.db.diary[guid] = { tags = {}, addedAt = now, relationship = "", note = "" }
    ns.Touch()
    ns.JourneyRecap.MOMENTS.zz_pad = { kind = "zz_pad", custom = { label = "Form", group = "other",
        fields = { { key = "who", type = "person", label = "Who" }, { key = "after", type = "text", label = "After" } } } }
    ns.UI.JourneyPlate.MARKS.zz_pad = { draw = function() end }
    CardSheet.Edit("zz_pad", { kind = "zz_pad", t = now, who = "" })
    Eq(Scope().key, "cards", "setup: the slip has the pad")
    Eq(At().key, "field:who", "setup: on the person's line")
    Press("PAD1")
    local line = Row("who").box
    Check(line:HasFocus(), "A did not give the line the cursor")
    line:SetText("bran")
    line:GetScript("OnTextChanged")(line, true)
    Check(Row("who").found:IsShown(), "setup: names offered")
    Eq(Legend().PADDDOWN, "Go to the names", "down's prompt with names offered")
    Press("PADDDOWN")
    Eq(At().group, "found", "down did not go into the names")
    Check(line:HasFocus(), "going into the names took the cursor")
    Press("PAD2")
    Eq(At().key, "field:who", "B on a name not back on the line")
    Press("PADDDOWN")
    Eq(At().group, "found", "setup: in the names again")
    Press("PAD1")
    Eq(Row("who").guid, guid, "A on a name did not pick it")
    Eq(Row("who"):Get(), "Brannoc", "the name not written")
    Check(not Row("who").found:IsShown(), "the names left up")
    Check(not line:HasFocus(), "the line kept the cursor after a pick")
    Eq(At().key, "field:who", "not back on the line after a pick")
    Press("PAD2")
    Check(not Sheet(), "B did not put it away")
    ns.JourneyRecap.MOMENTS.zz_pad = nil
    ns.UI.JourneyPlate.MARKS.zz_pad = nil
end

--------------------------------------------------------------------------
Section("the free card's form: icons, the + Add strips, people, the item, the caption")

do
    local guid = "Player-1-0AAAAAAA"
    ns.db.characters[guid] = ns.db.characters[guid] or { guid = guid, names = { { first = "Brannoc", surname = "" } } }
    ns.db.diary[guid] = ns.db.diary[guid] or { tags = {}, addedAt = now, relationship = "", note = "" }
    mock.bags[0] = { size = 16, [1] = { link = "|cff1eff00|Hitem:100:0:0:0:0:0:0:0:11|h[Thistle Sash]|h|r", quality = 2 } }
    local note = ns.Custom.Insert("noteCard", { text = "at the pier", people = { { name = "Old Tom" } } },
        { mapID = MAP, x = 0.41, y = 0.59, from = t0, to = t0 + 1800 })
    CardSheet.Edit("noteCard", note)
    Eq(Scope().key, "cards", "setup: the slip has the pad")
    Eq(At().key, "icon:quill", "the pad on the first icon, the first control")
    Check(At().ring == true, "the icon ringed by the pen")
    Eq(Legend().PAD1, "Choose", "A's prompt on an icon")
    -- Along the sixteen, then their rows, then off the grid.
    Press("PADDRIGHT")
    Eq(At().key, "icon:meeting", "right: the next icon")
    Press("PADDLEFT")
    Press("PADDLEFT")
    Eq(At().key, "icon:quill", "left stops at the first")
    Press("PADDDOWN")
    Eq(At().key, "icon:" .. ns.NoteIcons.KEYS[9], "down: the row under it")
    Press("PADDUP")
    Eq(At().key, "icon:quill", "up: back to the first row")
    Press("PADDDOWN")
    Press("PADDDOWN")
    Eq(At().key, "field:text", "down off the grid: the text")
    Press("PADDUP")
    Eq(At().group, "form", "up from the text: back on the grid")
    Check(At().icon ~= nil, "on an icon")
    Press("PAD1")
    Eq(Row("icon"):Get(), ns.NoteIcons.KEYS[At().icon], "A chose it")
    -- Who was there: faces, and the line under them.
    local face = Stand("form", function(item) return item.key == "face:people:1" end)
    Check(face ~= nil and face.ring == true, "Old Tom's face reachable, ringed by the pen")
    Eq(Legend().PAD1, "Take them off the card", "A's prompt on a face")
    Press("PADDDOWN")
    Eq(At().key, "field:people", "down from the faces: the line")
    Check(not Row("people").box:HasFocus(), "which has no cursor till A")
    Press("PAD1")
    local line = Row("people").box
    Check(line:HasFocus(), "A: the cursor")
    line:SetText("bran")
    line:GetScript("OnTextChanged")(line, true)
    Eq(Legend().PADDDOWN, "Go to the names", "names offered on the people's line")
    Press("PADDDOWN")
    Eq(At().group, "found", "into the names")
    Press("PAD1")
    Eq(#Row("people").people, 2, "A picked them: a second face")
    Eq(Row("people").people[2].guid, guid, "linked")
    Eq(At().key, "field:people", "back on the line")
    Check(Stand("form", function(item) return item.key == "face:people:2" end) ~= nil, "their face reachable")
    -- One taken off, and back.
    Stand("form", function(item) return item.key == "face:people:1" end)
    Press("PAD1")
    Eq(#Row("people").people, 1, "A on a face took them off")
    Eq(At().key, "face:people:1", "the pad on the next face")
    Eq(Row("people").people[1].guid, guid, "which is who was second")
    Stand("form", function(item) return item.key == "field:people" end)
    Press("PAD1")
    line:SetText("Old Tom")
    line:GetScript("OnEnterPressed")(line)
    Eq(#Row("people").people, 2, "Enter on the line added the name typed")
    Press("PAD2")
    -- The strips.
    local strip = Stand("form", function(item) return item.key == "more:mob" end)
    Check(strip ~= nil and strip.kind == "strip", "the mob's strip reachable")
    Eq(Legend().PAD1, "Add", "A's prompt on a strip")
    Check(strip.outline() ~= nil, "outlined as a card")
    Press("PAD1")
    Check(Row("mob").on, "A added the mob")
    Eq(At().key, "field:mob", "the pad on its line")
    Check(not Row("mob").box:HasFocus(), "with no cursor till A")
    Press("PAD1")
    Row("mob").box:SetText("Plainstrider")
    Press("PAD2")
    local off = Stand("form", function(item) return item.key == "off:mob" end)
    Check(off ~= nil, "its Remove reachable")
    Press("PAD1")
    Check(not Row("mob").on, "A took it off")
    Eq(Row("mob"):Get(), "", "cleared")
    Eq(At().key, "more:mob", "the pad back on its strip")
    -- The item, from the search (the pad's way: no shift-click).
    Stand("form", function(item) return item.key == "more:item" end)
    Press("PAD1")
    Eq(At().key, "field:item", "on the item's line")
    Press("PAD1")
    local box = Row("item").box
    box:SetText("sash")
    box:GetScript("OnTextChanged")(box, true)
    Press("PADDDOWN")
    Eq(At().group, "found", "into the items offered")
    Press("PAD1")
    Eq(Row("item").id, 100, "A picked it")
    -- The caption's box.
    Stand("form", function(item) return item.key == "tick:caption" end)
    Eq(Legend().PAD1, "Tick", "A's prompt on the caption's box")
    Press("PAD1")
    Eq(Row("caption"):Get(), true, "A ticked it")
    -- Saved with A on Save.
    Stand("form", function(item) return item.key == "link:" .. ns.L["Save"] end)
    Press("PAD1")
    Check(not Sheet(), "saved and put away")
    Eq(note.icon ~= nil and note.people and #note.people, 2, "both people")
    Eq(note.people[1].guid, guid, "the one picked linked")
    Eq(note.itemID, 100, "the item")
    Eq(note.caption, true, "the caption")
    Eq(note.mob, nil, "no mob")
    -- Combat: the catcher off with the slip up.
    CardSheet.Edit("noteCard", note)
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
    Check(not catcher:IsGamePadButtonEnabled(), "in combat the pad is the game's")
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    Press("PAD2")
    Check(not Sheet(), "B put it away")
    ns.Custom.Remove(note)
    mock.bags[0] = { size = 16 }
end

--------------------------------------------------------------------------
Section("a free card naming two: A asks whose page, on the pad's slip")

do
    local a, b = "Player-1-0AAAAAAA", "Player-1-0BBBBBBB"
    ns.db.characters[b] = { guid = b, names = { { first = "Wenna", surname = "" } } }
    ns.db.diary[b] = { tags = {}, addedAt = now, relationship = "", note = "" }
    local note = ns.Custom.Insert("noteCard", { people = { { name = "Brannoc", guid = a }, { name = "Wenna", guid = b } } },
        { mapID = MAP, x = 0.41, y = 0.59, from = t0, to = t0 + 1800 })
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    OpenLevel()
    Press("PADDDOWN")
    Scope().focus:EnterGroup("page")
    local onNote = Stand("page", function(item) return item.note and item.note.freeRec ~= nil end)
    Check(onNote ~= nil, "the free card among the page's things")
    mock.contextMenu = nil
    Press("PAD1")
    Eq(mock.contextMenu, nil, "A opened Blizzard's menu")
    Check(Pad.Menu.IsOpen(), "A did not open the pad's slip")
    Check(MenuLines():find("Wenna") ~= nil, "the people to choose from: " .. MenuLines())
    Press("PAD2")
    Check(not Pad.Menu.IsOpen(), "B put it away")
    ns.Custom.Remove(note)
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    OpenLevel()
end

--------------------------------------------------------------------------
Section("the mouse takes over the slip cleanly")

Scope().focus:Set(onCard)
Press("PAD4")
Check(Sheet(), "setup: the slip up")
Eq(Scope().key, "cards", "setup: the slip's scope")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(Sheet(), "the mouse put the slip away")
Check(not parts.pen:IsShown(), "the pen's box left with the mouse")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on with the mouse")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")
Eq(Pad.Top().key, "cards", "the slip's scope not back with the pad")
Press("PAD2")
Check(not Sheet(), "B did not put it away")
Eq(Pad.Top().key, "yourdiary", "the page's scope not back")

--------------------------------------------------------------------------
Section("with the mouse the right click is as it was")

mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mock.mapID, mock.position = MAP, { x = 0.47, y = 0.53 }
mock.contextMenu = nil
Plate().clip.scripts.OnMouseUp(Plate().clip, "RightButton")
Check(not Sheet(), "a right click on the map opened the picker with no menu")

--------------------------------------------------------------------------
Section("Y on a person's strip: their menu on the pad's slip")

-- (.claude/features/choose-page.md, "Later: the gamepad": "Leave <name> off
-- this page" on the pad too, now the ticklist is the pad's way back; the
-- same generator as the mouse's, CardSheet.PersonGenerator, never MenuUtil)
do
    local WHO = "Player-2222-0000CCCC"
    ns.Characters.Observe(WHO, { first = "Thessaly", surname = "Brookmere" })
    j.marks = { { kind = "fight", outcome = "won", guid = WHO, t = t0 + 1000, mapID = MAP, x = 0.41, y = 0.59 } }
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    OpenLevel()
    local function Strip()
        for i = 1, page.notePool.used do
            local s = page.notePool[i]
            if s:IsShown() and s.guid == WHO then return s end
        end
    end
    local strip = Strip()
    Check(strip ~= nil and strip.onRight ~= nil and strip.rightMenu == true, "setup: their strip with its menu")
    mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
    Check(Pad.Input.Active(), "setup: the pad in hand")
    Press("PADDDOWN")  -- (the title lets go after the page fell open)
    Scope().focus:EnterGroup("page")
    local onStrip = Stand("page", function(item) return item.note == strip end)
    Check(onStrip ~= nil, "setup: the pad on their strip")
    Eq(Legend().PAD4, "Open the menu", "Y's prompt on a person's strip")
    mock.contextMenu = nil
    Check(not Press("PAD4"), "Y on a person's strip went on to the game")
    Eq(mock.contextMenu, nil, "Y on a person's strip opened Blizzard's menu")
    Check(Pad.Menu.IsOpen(), "Y on a person's strip did not open the pad's menu")
    local leave = ns.Fmt(ns.L["Leave %1$s off this page"], "Thessaly")
    Eq(MenuLines(), leave, "their menu's line")
    Press("PAD2")
    Check(not Pad.Menu.IsOpen(), "B did not put their menu away")
    Eq(At().key, onStrip.key, "not back on their strip from the menu")
    Eq(j.chosen, nil, "putting the menu away left them off")
    Press("PAD4")
    PickLine(leave)
    Check(not Pad.Menu.IsOpen(), "the menu left up after the pick")
    Check(Strip() == nil, "their strip still on the page after the pick")
    local theirs = 0
    for key, v in pairs(j.chosen or {}) do
        if key:find(WHO, 1, true) then
            Eq(v, "out", "left off: not out")
            theirs = theirs + 1
        end
    end
    Check(theirs > 0, "the pick wrote nothing")
    j.chosen = nil
    j.marks = {}
    J.Touch()
end
