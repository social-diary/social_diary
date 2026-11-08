-- The pad's second client round (.claude/controller-plan.md, "Client round
-- 2", 8 Nov 2026): the pen's box holds the paraph that leads Your Diary's
-- level rubric (an item's `encloses`); the buttons drawn in their real
-- colours, the client's modern atlas first; "Show marks" only where
-- a plate has a mark to stand on, and a plate whose only hover squares are
-- its trail's pools (a stay, an arrival, a road: the client's case) walks
-- those. The pad's own menu has tests/pad_menu.lua.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Look, G = Pad.Look, Pad.Glyphs

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local page = ns.UI.JourneyPage()

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Legend()
    local out = {}
    for _, e in ipairs(Pad.Legend(Pad.Top())) do
        local key = type(e[1]) == "table" and e[1][1] or e[1]
        if out[key] == nil then out[key] = e[2] end
    end
    return out
end

-- Lays a region out on the screen as the client would: left, right, top,
-- bottom (y up).
local function Lay(r, l, rt, t, b)
    r.left, r.right, r.bottom = l, rt, b
    r.at = { (l + rt) / 2, t, (t + b) / 2 }
end

-- The x offset the pen's box was put at from its anchor (Look's PenBox:
-- TOPLEFT on the words).
local function PenX()
    local pen = Look.parts[book].pen
    local point = pen.recorded.points[1]
    return point and point.args[3]
end
local function PenW() return Look.parts[book].pen:GetWidth() end

--------------------------------------------------------------------------
Section("the rubric's box holds its paraph")

Eq(At().key, "rubric", "setup: the pad on the rubric")
local item = At()
local row = item.frame
Eq(item.encloses, row.paraph, "the rubric's item does not name its paraph")
-- Laid as in the client: the words from x 100, the paraph (6 px, turned
-- 45 degrees) centred 7.5 px left of them.
Lay(row.header, 100, 160, 200, 186)
Lay(row.paraph, 89.5, 95.5, 196, 190)
local x, y, w, h = Look.Enclose(row.header, row.paraph, 0, 0, 60, 14)
local half = 3 * math.sqrt(2)
Check(math.abs(x - (92.5 - 100 - half)) < 0.01, "the box's left not the paraph's turned corner: " .. x)
Check(math.abs(w - (60 - x)) < 0.01, "the box's right moved")
Eq(y, 0, "the box's top moved")
Eq(h, 14, "the box's height changed")
-- Drawn: the pen's box starts left of the paraph, not at the words.
Look.Mark(book, item, false)
local held, heldW = PenX(), PenW()
Look.Mark(book, { key = "plain", words = row.header }, false)
local plain, plainW = PenX(), PenW()
Check(held and plain and held < plain - 10, "the box does not reach past the paraph: " .. tostring(held))
Check(heldW > plainW + 10, "the box no wider for the paraph")
-- Not laid out yet (the client before its first frame): the words alone.
row.paraph.left = nil
Look.Mark(book, item, false)
Eq(PenX(), plain, "a region not laid out moved the box")
Look.Mark(book, At(), false)
-- A list of regions, one of them hidden: only the shown one counts.
local a, b = {}, {}
for _, r in ipairs({ a, b }) do
    r.GetLeft = function(s) return s.left end
    r.GetRight = function(s) return s.right end
    r.GetTop = function(s) return s.top end
    r.GetBottom = function(s) return s.bottom end
    r.IsShown = function(s) return s.shown end
end
a.left, a.right, a.top, a.bottom, a.shown = 80, 90, 200, 186, true
b.left, b.right, b.top, b.bottom, b.shown = 40, 50, 200, 186, false
x = Look.Enclose(row.header, { a, b }, 0, 0, 60, 14)
Eq(x, -20, "a list's shown region not held, or a hidden one held")
-- The chevron before the paraph stays clear of the box.
local SOLO = ns.UI.YourDiary.SOLO
Check(SOLO.out - SOLO.w / 2 > half + 6 + 2, "the left chevron would meet the box")

--------------------------------------------------------------------------
Section("the buttons in their real colours: the modern atlas first")

local known = {}
_G.C_Texture = { GetAtlasInfo = function(name)
    local k = known[name]
    return k and { width = k[1], height = k[2] } or nil
end }
mock.pad.style = "Letters"
G.Changed()
Eq(G.Atlas("PAD1"), nil, "an atlas the client has not")
_G.KEY_PAD1_LTR = "|A:Gamepad_Ltr_A_64:24:24|a"
Eq(G.Atlas("PAD1"), "Gamepad_Ltr_A_64", "the KEY markup's atlas not next")
known["gamepad-xbox1-buttona-normal"] = { 64, 64 }
Eq(G.Atlas("PAD1"), "gamepad-xbox1-buttona-normal", "the modern Xbox atlas not first")
_G.KEY_PAD1_LTR = nil
known["Gamepad_Shp_Circle_64"] = { 64, 64 }
mock.pad.style = "Shapes"
G.Changed()
Eq(G.Atlas("PAD2"), "Gamepad_Shp_Circle_64", "the older set not last")
known["gamepad-ps-buttoncircle-normal"] = { 64, 64 }
Eq(G.Atlas("PAD2"), "gamepad-ps-buttoncircle-normal", "the modern PlayStation atlas not first")
known["gamepad-switch-128x-face-b-normal"] = { 128, 128 }
mock.pad.style = "Reverse"
G.Changed()
Eq(G.Atlas("PAD1"), "gamepad-switch-128x-face-b-normal", "Switch's bottom button not its B")
-- A shoulder is wider than tall: drawn by its own shape, inline too.
known["gamepad-xbox1-trigger-lb-normal"] = { 128, 64 }
known["gamepad-xbox1-trigger-rb-normal"] = { 128, 64 }
known["gamepad-xbox1-buttonb-normal"] = { 64, 64 }
mock.pad.style = "Letters"
G.Changed()
Eq(G.Text("PADLSHOULDER", 16), "|A:gamepad-xbox1-trigger-lb-normal:16:32|a", "inline: not the same atlas, by its shape")
Eq(G.Text("PAD1", 16), "|A:gamepad-xbox1-buttona-normal:16:16|a", "inline A not the modern atlas")
-- "Generic" (a pad SDL does not name) shows Xbox's, as the game does.
mock.pad.devices = {}
G.Changed()
Eq(G.Style(), "Generic", "setup: generic")
Eq(G.Atlas("PAD1"), "gamepad-xbox1-buttona-normal", "generic not Xbox's modern atlas")
mock.pad.devices = { 1 }
G.Changed()

-- The slip's glyphs: the atlas as it is, never greyed or inked.
local before = #mock.frames
-- (made anew: what the slip and the ribbons' keys showed before was drawn
-- with another set of atlases)
Look.parts[book].keys.id = nil
Look.parts[book].slip.entriesShown = nil
Look.Legend(book, { { "PAD1", "Open", main = true }, { "PAD2", "Close the book" },
    { { "PADLSHOULDER", "PADRSHOULDER" }, "Turn the page", beside = { book, book } } })
local glyphs, wide = 0, false
for i = before + 1, #mock.frames do
    local calls = mock.frames[i].recorded.calls
    if calls.SetAtlas then
        glyphs = glyphs + 1
        Check(not calls.SetDesaturated, "a glyph desaturated: " .. tostring(calls.SetAtlas[1]))
        Check(not calls.SetVertexColor, "a glyph tinted: " .. tostring(calls.SetAtlas[1]))
        local f = mock.frames[i]
        if calls.SetAtlas[1] == "gamepad-xbox1-trigger-lb-normal" then
            wide = f.recorded.width == 2 * f.recorded.height
        end
    end
end
Eq(glyphs, 4, "not A, B and the two shoulders drawn")
Check(wide, "the shoulder beside the ribbon squeezed square")
_G.C_Texture = nil
G.Changed()
Pad.Refresh()

--------------------------------------------------------------------------
Section("Your Diary: \"Show marks\" only where a plate has one")

-- (onto the right page's first plate)
Press("PAD1")
local plateItem
for _, it in ipairs(Pad.Top().focus.groups.page.items) do
    if it.plate then plateItem = it break end
end
Check(plateItem, "setup: a plate on the right page")
Pad.Top().focus:Set(plateItem)
local plate = plateItem.whole()
Check(plate:HasMarks(), "setup: testdata's plate has marks")
Eq(Legend().PAD1, "Show marks", "the prompt with marks")
-- Drawn again with the road alone, as a stay's plate is in the client: its
-- pools are what there is to look at.
local data, window = plate.data, plate.window
plate:Draw(data, plate.entry, window, { moments = {}, fights = {}, witnesses = {} })
local marks = plate:Marks()
Check(marks[1] ~= nil, "a plate of pools alone has nothing for the pad")
for _, mk in ipairs(marks) do Eq(mk.what, "pool", "a stay's plate walked something but its pools") end
Press("PAD1")
Eq(At().group, "marks", "A on a stay's plate did not go among its pools")
Check(At().ring, "a pool not ringed")
Press("PAD2")
Eq(At().key, plateItem.key, "B not back on the plate")
-- With nothing at all: no prompt, and A stays.
local empty = { mapID = data.mapID, stops = {}, roads = {}, flights = {}, dungeons = {}, pins = {}, meetings = {} }
plate:Draw(empty, plate.entry, window, { moments = {}, fights = {}, witnesses = {} })
Check(not plate:HasMarks(), "an empty plate has marks")
Pad.Refresh()
Eq(At().key, plateItem.key, "setup: still on the plate")
Check(Legend().PAD1 ~= "Show marks", "the prompt on a plate with nothing to look at")
Press("PAD1")
Eq(At().key, plateItem.key, "A on an empty plate moved the pad")
ns.UI.RedrawJourneyPage()

--------------------------------------------------------------------------
Section("a person's plate: A among its marks; none, no prompt")

ns.UI.SetJournalView("people")
local scope = Pad.Scope("people")
local p = J.journal.profile
local tester
for _, it in ipairs(scope.focus.groups.left.items) do
    if it.kind == "person" and ns.Timeline.For(it.guid)[3] then tester = it break end
end
Check(tester, "setup: someone with a timeline")
scope.focus:Focus(tester.key, "left")
Press("PAD1")
Check(scope.focus:Focus("plate", "page"), "setup: onto their plate")
local pp = p.clippings.plate
Check(pp:HasMarks(), "setup: their plate has marks")
Eq(Legend().PAD1, "Show marks", "the plate's prompt with marks")
Press("PAD1")
Eq(At().group, "marks", "A did not step among the marks")
Check(At().ring, "the mark not ringed")
Check(GameTooltip.shown, "the mark's tooltip not shown")
Press("PAD2")
Eq(At().key, "plate", "B not back on the plate")
-- Only the road (the client's case: a stay, nothing marked): its pools.
data, window = pp.data, pp.window
pp:Draw(data, nil, window, { moments = {}, fights = {}, witnesses = {} })
Check(pp:HasMarks(), "the road's pools not walked")
Press("PAD1")
Eq(At().group, "marks", "A on a road's print did not step among its pools")
Press("PAD2")
-- Nothing at all on it: no prompt, A does nothing, X still the map.
empty = { mapID = data.mapID, stops = {}, roads = {}, flights = {}, dungeons = {}, pins = {}, meetings = {} }
pp:Draw(empty, nil, window, { moments = {}, fights = {}, witnesses = {} })
Pad.Refresh()
Eq(At().key, "plate", "setup: on the plate")
Check(Legend().PAD1 ~= "Show marks", "the prompt on a print with nothing to look at")
Eq(Legend().PAD3, "See the map", "X's prompt gone too")
Press("PAD1")
Eq(At().key, "plate", "A on an empty print moved the pad")
Check(not scope.inPlate, "A on an empty print went in")
