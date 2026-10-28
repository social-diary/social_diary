-- Drawing your own way through a run on its map (.claude/dungeon-visits-
-- prd.md §19, WAY-6 to WAY-17; UI/Dungeon/Way.lua): the pencil's slip on
-- the map sheet, the pen taken up, clicks on the paper through the mouse,
-- undo, reset with its question, Done; and the run's own way printed in
-- place of the usual one.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local D = ns.Dungeons
local DP = ns.UI.DungeonPage

mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID

local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 then RFK = visit end
end
Check(RFK and RFK.route == nil, "the test data's Razorfen Kraul run, nothing drawn on it")
local usual = D.Route(47, nil)

-- The map out, the mouse put on the sheet's point x, y.
local view, way, K
local SCALE = 0.71
local function Out()
    ns.UI.OpenVisit(RFK.id, G)
    view = DP.Spread().map
    way, K = view.way, view.K
    view.sheet.at, view.sheet.effectiveScale = { 960, 0, 540 }, SCALE
end
local function Mouse(x, y)
    local sx, sy = K.Screen(x, y)
    mock.pointer = { (960 + sx) * SCALE, (540 + sy) * SCALE }
end
local function Click(x, y, button)
    Mouse(x, y)
    way.catcher.scripts.OnMouseDown(way.catcher, button or "LeftButton")
    way.catcher.scripts.OnMouseUp(way.catcher, button or "LeftButton")
end
local function Press(key)
    local b = way.slip.buttons[key]
    b.scripts.OnClick(b)
end
local function Off(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- A place on the printed floor where nothing answers the mouse.
local function Bare()
    for gx = 0.15, 0.85, 0.05 do
        for gy = 0.2, 0.8, 0.05 do
            local x, y = view.w * gx, view.h * gy
            if view.From(x, y) and not DP.WayUnder(view, x, y) then
                local near = false
                for _, q in ipairs(way.drawn and way.drawn.pts or {}) do
                    if q and Off(q[1], q[2], x, y) < 30 then near = true end
                end
                if not near then return x, y end
            end
        end
    end
end

--------------------------------------------------------------------------
Section("at rest: the slip on the sheet's top edge")

Out()
local slip = way.slip
Check(slip:IsShown() and not way.drawing, "the slip is not out at rest")
Check(slip.title:IsShown() and slip.title:GetText() == "Adjust Path", "the slip does not say Adjust Path")
Check(view.wayKeep, "the strips are not told where the slip lies")
Check(slip.box[2] < 0 and slip.box[4] > 0 and slip.box[4] <= DP.WAY.SLIP.onto + 0.01,
    "the slip does not lie across the top edge")
for _, s in ipairs(view.plan.spots) do
    local b = slip.box
    Check(not (s.x + s.r > b[1] and s.x - s.r < b[3] and s.y + s.r > b[2] and s.y - s.r < b[4]),
        "the slip covers a mark at " .. s.x .. "," .. s.y)
end
for _, entry in ipairs(view.noteStrips) do
    local b, k = entry.box, view.wayKeep
    if b then
        Check(b[3] <= k[1] or b[1] >= k[3] or b[4] <= k[2] or b[2] >= k[4], "a strip lies under the slip")
    end
end
for _, b in ipairs(slip.buttons) do Check(not b:IsShown(), "a drawing word shows at rest: " .. b.key) end

--------------------------------------------------------------------------
Section("taking the pencil up")

local kept, scale, w, h = view.kept, view.scale, view.w, view.h
slip.scripts.OnClick(slip)
Check(way.drawing and way.catcher:IsShown(), "Adjust Path did not take the pen up")
Check(not slip.title:IsShown() and slip.heading:IsShown(), "the slip is not the drawing's")
for _, b in ipairs(slip.buttons) do Check(b:IsShown(), "a word is missing: " .. b.key) end
Eq(view.pools.route.used, 0, "the inked way still shows under the pencil")
Eq(#view.noteStrips, 0, "the strips did not step back")
Eq(way.drawn.points, #usual, "the pencil does not start from the usual way")
Eq(way.drawn.handles, #usual, "not every point has a handle")
Check(way.drawn.markers > 0, "the floor's stairs and doors do not show")
Check(not slip.buttons.undo.enabled and not slip.buttons.reset.enabled, "undo or reset before any change")
Check(slip.buttons.done.enabled and slip.buttons.clear.enabled, "Done or Clear cannot be pressed")
Eq(RFK.route, nil, "taking the pen up wrote a way")
Check(slip.statusText:find("usual way"), "the slip does not say where it starts from: " .. tostring(slip.statusText))
Check(table.concat(slip.hintLines, " "):find("Ctrl%-click a line"), "the hint does not say how to insert")

--------------------------------------------------------------------------
Section("a click on the paper adds a point, the sheet stays put")

local bx, by = Bare()
Check(bx, "no bare place on the map")
Click(bx, by)
Check(type(RFK.route) == "table" and #RFK.route == #usual + 1, "the click added no point")
local last = RFK.route[#RFK.route]
local px, py = view.At(last.f, last.x, last.y)
Check(px and Off(px, py, bx, by) < 1, "the point is not under the click")
Check(view.kept == kept and view.scale == scale and view.w == w and view.h == h, "the sheet moved under the pen")
Eq(way.drawn.points, #usual + 1, "the new point is not drawn")
Check(slip.buttons.undo.enabled and slip.buttons.reset.enabled, "undo or reset cannot be pressed after a change")

-- A boss: a stop at it.
local bossMark
for _, mark in ipairs(view.plan.marks) do
    local hit = DP.WayUnder(view, mark.x, mark.y)
    if hit and hit.what == "boss" then bossMark = mark end
end
Check(bossMark, "no boss clear of the way to click")
if bossMark then
    Click(bossMark.x, bossMark.y)
    Eq(RFK.route[#RFK.route].boss, bossMark.name, "a click on a boss is no stop")
end

-- A marker: a step. Razorfen Kraul's only one is its way in, where the
-- usual way starts (a point there answers first): on a cleared way.
local marker = way.markers[1]
Check(marker and DP.WayUnder(view, marker.sx, marker.sy).what == "point", "the way does not start at the door")
local n = #RFK.route
Press("clear")
Check(DP.WayUnder(view, marker.sx, marker.sy).what == "marker", "the door does not answer the mouse")
Click(marker.sx, marker.sy)
Check(#RFK.route == 1 and RFK.route[1].kind == marker.kind, "a click on the door is no step")
Press("undo")
Press("undo")
Eq(#RFK.route, n, "two undos did not take the step and the clear back")

--------------------------------------------------------------------------
Section("selecting, dragging, undo")

-- The plain point added first: selected, then dragged as one step back.
local i = #usual + 1
local p = RFK.route[i]
px, py = view.At(p.f, p.x, p.y)
Mouse(px, py)
way.catcher.scripts.OnMouseDown(way.catcher, "LeftButton")
Eq(way.pen.at, i, "a click on a point does not select it")
Eq(way.drawn.ring, i, "the selected point is not ringed")
local tx, ty = px + 25, py + 18
Mouse(tx, ty)
DP.WayMove(view)
way.catcher.scripts.OnMouseUp(way.catcher, "LeftButton")
p = RFK.route[i]
local qx, qy = view.At(p.f, p.x, p.y)
Check(qx and Off(qx, qy, tx, ty) < 1, "the point is not where it was dropped")
Press("undo")
p = RFK.route[i]
qx, qy = view.At(p.f, p.x, p.y)
Check(Off(qx, qy, px, py) < 1, "undo did not put the dragged point back")

-- Next and previous step through the points; Delete Point takes it out.
Press("next")
Eq(way.pen.at, i + 1, "Next Point")
Press("previous")
Eq(way.pen.at, i, "Previous Point")
n = #RFK.route
Press("delete")
Eq(#RFK.route, n - 1, "Delete Point")
-- Right-click a point deletes it.
p = RFK.route[2]
px, py = view.At(ns.DungeonWay.Where(47, p))
n = #RFK.route
Click(px, py, "RightButton")
Eq(#RFK.route, n - 1, "a right-click did not delete the point")

-- Ctrl-click on a leg inserts a point there.
local a, b
local pts = way.drawn.pts
for k = 1, #pts - 1 do
    if pts[k] and pts[k + 1] and not RFK.route[k + 1].pair and not a
        and Off(pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]) > 40 then
        a, b = k, k + 1
    end
end
Check(a, "no leg long enough to click on")
local mx, my = (pts[a][1] + pts[b][1]) / 2, (pts[a][2] + pts[b][2]) / 2
n = #RFK.route
mock.modifiers.ctrl = true
Click(mx, my)
mock.modifiers.ctrl = false
Eq(#RFK.route, n + 1, "Ctrl-click on a line inserted nothing")
Eq(way.pen.at, b, "the point inserted is not selected")

--------------------------------------------------------------------------
Section("cut, and Done joins it")

way.pen:Select(3)
Press("cut")
Eq(way.pen:Gap(), 4, "Cut Path Here")
Check(way.drawn.cut, "the cut is not marked")
Check(not slip.buttons.cut.enabled, "a second cut can be pressed")
Check(slip.statusText:find("cut after point 3"), "the slip does not say the path is cut")
local count = #RFK.route
Press("done")
Check(not way.drawing and not way.catcher:IsShown(), "Done did not put the pen down")
Eq(way.pen:Gap(), nil, "Done left the cut open")
Eq(#RFK.route, count, "joining the cut lost points")
Check(slip.title:IsShown(), "the slip is not back at rest")

--------------------------------------------------------------------------
Section("the run's own way printed (WAY-14, WAY-16)")

Check(view.plan.path and view.plan.path.own, "the sheet does not print the run's own way")
Check(view.plan.routeCounts.ink > 0 and view.plan.routeCounts.pencil == 0, "the run's own way is not inked in full")
ns.SetSetting("dungeonRoute", false)
DP.Refresh()
Check(view.plan.routeCounts.ink > 0, "hiding the usual way hid the run's own")
ns.SetSetting("dungeonRoute", true)
DP.Refresh()

--------------------------------------------------------------------------
Section("reset asks first, then the usual way is back")

slip.scripts.OnClick(slip)
Check(way.drawing, "Adjust Path again")
local popups = #mock.popups
Press("reset")
Eq(#mock.popups, popups + 1, "Reset did not ask")
Check(type(RFK.route) == "table", "Reset did not wait for the answer")
Check(mock.AnswerPopup("accept"), "the question has no answer")
Eq(RFK.route, nil, "the drawing was not reset")
Check(not slip.buttons.undo.enabled, "the reset can be undone")
Eq(way.drawn.points, #usual, "the usual way is not back under the pencil")
Press("done")
Check(not view.plan.path.own, "after reset the sheet still prints a drawing")

--------------------------------------------------------------------------
Section("Clear, and the run put away puts the pen down")

slip.scripts.OnClick(slip)
Press("clear")
Check(type(RFK.route) == "table" and #RFK.route == 0, "Clear left points")
Eq(way.drawn.points, 0, "points still drawn after Clear")
Press("undo")
Eq(RFK.route, nil, "undo did not take the clear back")
bx, by = Bare()
Click(bx, by)
local pen = way.pen
way.pen:Select(1)
Press("cut")
DP.Close()
Check(not way.drawing and way.pen == nil, "putting the run away left the pen out")
Eq(pen:Gap(), nil, "putting the run away left the cut open")
Check(type(RFK.route) == "table", "putting the run away lost the drawing")

-- Opened again: at rest, the drawing printed.
Out()
Check(not way.drawing and view.plan.path.own, "the drawing is not printed when the run opens again")
DP.Close()
RFK.route = nil
