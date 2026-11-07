-- Custom cards with the pad (UI/Journey/CardPad.lua, Y in UI/Journey/Pad.lua,
-- CardSheet.PadRight; .claude/controller-plan.md, step 4c): Y on a card or its
-- mark opens its form, Y on a plate or another mark adds a card where the
-- player stands (or, off this map, at the mark; on the plate itself, nothing);
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
Section("off this map: not offered on the plate; at the mark's spot on a mark")

Press("PAD2")
Eq(At().plate, 1, "setup: on the plate")
Eq(Legend().PAD4, nil, "Y offered on a plate with the player elsewhere")
Check(Press("PAD4"), "Y with nothing to do was taken from the game")
Check(not Sheet(), "Y opened something with the player elsewhere")
-- In an instance on the zone's map: no position given, the same.
mock.mapID, mock.position, mock.inInstance = MAP, { x = 0.5, y = 0.5 }, true
Eq(Legend().PAD4, nil, "Y offered in an instance")
mock.mapID, mock.position, mock.inInstance = nil, nil, nil

-- A mark that is not a card's (the close call's, its spot taken off) lends
-- its own spot, as a right click on it would.
Press("PAD1")
local mark = Stand("marks", function(item) return item.key == onMark.key end)
local spot = mark.frame.spot
mark.frame.spot = nil
Eq(Legend().PAD4, "Add a card here", "Y on a mark not offered with the player elsewhere")
Press("PAD4")
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
Eq(Legend().PAD4, "Add a card here", "Y's prompt on a plate")
Press("PAD4")
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
