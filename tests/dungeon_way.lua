-- Your own way through a run (.claude/dungeon-visits-prd.md §19): a pen on
-- the dungeon map. WAY-12 first: a click on the turned, folded sheet goes
-- back to the floor, and a point drawn from there lands under the click,
-- within a pixel, on every kind of floor and however the sheet lies.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local D = ns.Dungeons
local Map = ns.UI.DungeonMap

mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID

local function VisitOf(instanceID)
    for _, visit in ipairs(ns.Instances.For(G)) do
        if visit.instanceID == instanceID then return visit end
    end
end
local RFK, WC = VisitOf(47), VisitOf(43)
Check(RFK and WC, "the test data's visits")

local function Off(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

--------------------------------------------------------------------------
Section("the sheet: screen to paper and back")

-- Every point of a grid over the sheet (and a little past its edge), to
-- the screen and back, turned either way, bent and flat.
local function RoundTrip(K, W, H, label)
    local worst = 0
    for gx = -0.05, 1.05, 0.05 do
        for gy = -0.05, 1.05, 0.05 do
            local x, y = gx * W, gy * H
            local bx, by = K.Unscreen(K.Screen(x, y))
            worst = math.max(worst, Off(x, y, bx, by))
        end
    end
    Check(worst < 0.01, label .. ": back off by " .. worst .. " px")
end

for _, case in ipairs({ { "folded", 0.061 }, { "turned back", -0.061 }, { "straight", 0 }, { "fallen", nil } }) do
    local sheet, K = ns.UI.LooseSheet(UIParent, 900, 620,
        { crease = { columns = { 0, 0.33, 0.5, 0.67, 1 }, rows = { 0, 0.5, 1 },
            folds = { columns = { [2] = 1, [4] = -1 }, rows = { [2] = -1 } } } })
    K.Fall("way" .. case[1], case[2])
    K.Lay()
    Check(sheet.bends, "the mock's sheet does not bend")
    RoundTrip(K, 900, 620, case[1])
end

-- The drift is what makes it more than a turn: bent, a point does move.
local sheet, K = ns.UI.LooseSheet(UIParent, 900, 620)
K.Fall("drift", 0)
K.Lay()
local moved = 0
for gx = 0.1, 0.9, 0.1 do
    local sx, sy = K.Screen(gx * 900, 310)
    moved = math.max(moved, Off(sx, sy, gx * 900 - 450, 0))
end
Check(moved > 0.1, "the sheet bends, yet nothing drifts: " .. moved)
RoundTrip(K, 900, 620, "crumpled")

-- Laid flat (Flat paper only): a turn and nothing else.
ns.SetSetting("flatSheets", true)
K.Fall("drift", 0.05)
K.Lay()
Check(not sheet.bends, "laid flat, it still bends")
RoundTrip(K, 900, 620, "flat")
ns.SetSetting("flatSheets", false)

--------------------------------------------------------------------------
Section("the cursor onto the sheet")

-- The sheet's middle on the screen, the UI scaled, the mouse in the
-- client's pixels: the cursor falls on the paper where that point is.
K.Fall("cursor", 0.04)
K.Lay()
local S = sheet.sheet
S.at, S.effectiveScale = { 700, 0, 420 }, 0.8
for _, pt in ipairs({ { 10, 10 }, { 450, 310 }, { 880, 600 }, { 300, 500 } }) do
    local sx, sy = K.Screen(pt[1], pt[2])
    mock.pointer = { (700 + sx) * 0.8, (420 + sy) * 0.8 }
    local cx, cy = K.Cursor()
    Check(Off(cx, cy, pt[1], pt[2]) < 0.01, ("the cursor over %d,%d fell on %.3f,%.3f"):format(pt[1], pt[2], cx, cy))
end

--------------------------------------------------------------------------
Section("the floor: a point of the shown map back to its own floor")

local floor = D.Floor(47, D.MainFloor(RFK).uiMapID)
local f, x, y = D.Unpoint(floor, 0.3, 0.7)
Check(f == floor.uiMapID and x == 0.3 and y == 0.7, "a plain floor's point is not its own")
Eq(D.Unpoint(floor, 1.2, 0.5), nil, "a point off the art has a floor")

-- A combined map: two crops of the floor, the second over the first.
local combined = { uiMapID = 900047, combined = true, instanceID = 47, w = 400, h = 300,
    data = { pieces = {
        { floor = floor.uiMapID, x0 = 0, y0 = 0, x1 = 500, y1 = 400, dx = 0, dy = 0, s = 0.5 },
        { floor = floor.uiMapID, x0 = 500, y0 = 0, x1 = floor.w, y1 = 400, dx = 250, dy = 0, s = 0.25 },
    } } }
for _, pt in ipairs({ { 0.1, 0.2 }, { 0.55, 0.4 }, { 0.62, 0.3 }, { 0.8, 0.1 } }) do
    local sf, sx, sy = D.Unpoint(combined, pt[1], pt[2])
    Check(sf == floor.uiMapID, ("%.2f,%.2f on the combined map has no floor"):format(pt[1], pt[2]))
    if sf then
        local bx, by = D.Point(combined, sf, sx, sy)
        Check(bx and Off(bx * 400, by * 300, pt[1] * 400, pt[2] * 300) < 1e-6,
            ("%.2f,%.2f on the combined map does not come back"):format(pt[1], pt[2]))
    end
end
Eq(D.Unpoint(combined, 0.95, 0.95), nil, "a gap between the pieces has a floor")

-- At and From are each other's way back on the sheet.
local At, From = Map.At(floor, 40, 30, 600, 420), Map.From(floor, 40, 30, 600, 420)
local px, py = At(floor.uiMapID, 0.25, 0.75)
local bf, bx, by = From(px, py)
Check(bf == floor.uiMapID and math.abs(bx - 0.25) < 1e-9 and math.abs(by - 0.75) < 1e-9, "From is not At's way back")
Eq(From(10, 10), nil, "the margin outside the print has a floor")

--------------------------------------------------------------------------
Section("the run's map: the mouse on a boss is the boss")

-- On the map sheet as a run opens it: put the mouse where each boss is
-- drawn, and the point under it is where the boss stands on its floor,
-- within a pixel of the print.
local function UnderBosses(visit, label)
    ns.UI.OpenVisit(visit.id, G)
    local view = ns.UI.DungeonPage.Spread().map
    Check(view:IsShown() and view.From, label .. ": the map is not out")
    local VS, VK = view.sheet, view.K
    VS.at, VS.effectiveScale = { 960, 0, 540 }, 0.71
    local shown = view.floors[view.floorIndex]
    local At = Map.At(shown, view.box.x, view.box.y, view.box.w, view.box.h)
    local tried = 0
    for _, b in ipairs(D.Bosses(visit.instanceID) or {}) do
        local ax, ay
        if b.floor and b.x then ax, ay = At(b.floor, b.x, b.y) end
        if ax then
            tried = tried + 1
            local sx, sy = VK.Screen(ax, ay)
            mock.pointer = { (960 + sx) * 0.71, (540 + sy) * 0.71 }
            local uf, ux, uy = view:Under()
            Check(uf, label .. ": nothing under " .. b.name)
            if uf then
                local back = { At(uf, ux, uy) }
                Check(back[1] and Off(back[1], back[2], ax, ay) < 1,
                    ("%s: the mouse on %s comes back %.3f px off"):format(label, b.name,
                        back[1] and Off(back[1], back[2], ax, ay) or -1))
            end
        end
    end
    Check(tried > 0, label .. ": no boss on the floor shown")
    ns.UI.OpenVisit(visit.id, G)
end
UnderBosses(RFK, "Razorfen Kraul (client art)")
UnderBosses(WC, "Wailing Caverns (drawn art)")
ns.SetSetting("flatSheets", true)
UnderBosses(RFK, "Razorfen Kraul laid flat")
ns.SetSetting("flatSheets", false)

--------------------------------------------------------------------------
Section("the pen: a run's own way, and nothing written until it draws")

local Way = ns.DungeonWay
local usual = D.Route(47, nil)
Check(usual and #usual > 3, "Razorfen Kraul has no usual way to start from")
local function Fresh() return { id = 9001, instanceID = 47 } end

-- A run nobody drew on reads exactly as before (WAY-1, WAY-2).
local run = Fresh()
local way, own = D.WayOf(run, nil)
Check(way == usual and own == false, "a run without a drawing does not read the usual way")
local pen = Way.Pen(run, nil)
Check(not pen:Own() and #pen:Points() == #usual, "opening the pen changed the run")
Eq(run.route, nil, "opening the pen wrote a route")
Check(not pen:CanUndo(), "a fresh pen has something to undo")

-- The first point copies the usual way and goes on its end (WAY-7).
local n = #usual
Eq(pen:Add(floor.uiMapID, 0.123456, 0.654321), n + 1, "the first point is not at the end")
Check(pen:Own() and #run.route == n + 1, "the usual way was not copied in")
Check(run.route ~= usual and run.route[1] ~= usual[1], "the run's way shares the usual way's tables")
Eq(#usual, n, "drawing changed the usual way")
Eq(run.route[n + 1].x, 0.1235, "a point is not kept to four places")
way, own = D.WayOf(run, nil)
Check(way == run.route and own, "WayOf does not read the run's own way")
-- Undo goes back past the copy, to no drawing at all.
Check(pen:Undo() and run.route == nil, "undo did not go back to the usual way")
Check(not pen:CanUndo(), "something left to undo")

--------------------------------------------------------------------------
Section("the pen: points, stops, the selection")

run = Fresh()
pen = Way.Pen(run, nil)
pen:Clear()
Eq(#run.route, 0, "clearing did not leave an empty way of their own")
Check(D.WayOf(run, nil) == run.route, "an empty way of their own reads as the usual way")
local F = floor.uiMapID
for k = 1, 4 do pen:Add(F, k / 10, 0.5) end
Eq(#run.route, 4, "four points")
-- A stop: the boss's name, at the boss.
local boss
for _, b in ipairs(D.Bosses(47) or {}) do if b.floor and b.x and not boss then boss = b end end
Check(boss, "Razorfen Kraul has no boss on a floor")
Eq(pen:AddStop(boss.name), 5, "the stop is not at the end")
Eq(run.route[5].boss, boss.name, "the stop does not name its boss")
Eq(pen:AddStop("Nobody At All"), nil, "a stop at a boss the data does not know")
-- A stop follows its boss, wherever it was put.
run.route[5].x = 0.01
local _, wx = Way.Where(47, run.route[5])
Eq(wx, boss.x, "a stop does not stand where its boss does")
-- With a point selected, new points go in after it and the selection follows.
Eq(pen:Select(2), 2, "no selection")
Eq(pen:Add(F, 0.25, 0.6), 3, "the point is not after the selection")
Eq(pen.at, 3, "the selection did not move onto the new point")
Eq(pen:Add(F, 0.27, 0.6), 4, "the next point is not after that")
Eq(run.route[5].x, 0.3, "the points after it did not move up")
-- Stepping through, at the ends it stays.
pen:Select(nil)
Eq(pen:Step(-1), #run.route, "stepping back from nothing is not the last point")
Eq(pen:Step(1), #run.route, "stepping past the end")
pen:Select(nil)
Eq(pen:Step(1), 1, "stepping on from nothing is not the first point")

--------------------------------------------------------------------------
Section("the pen: on a leg, dragging, deleting")

-- Sheet coordinates: the floor printed 1000 by 1000 at 0, 0.
local place = Map.At(floor, 0, 0, 1000, 1000)
run = Fresh()
pen = Way.Pen(run, nil)
pen:Clear()
pen:Add(F, 0.1, 0.1)
pen:Add(F, 0.5, 0.1)
pen:Add(F, 0.5, 0.5)
Eq(Way.Hit(47, run.route, place, 498, 103, 10), 2, "the point under the mouse")
Eq(Way.Hit(47, run.route, place, 300, 300, 10), nil, "a point far from the mouse is hit")
Eq(Way.OnLeg(47, run.route, place, 300, 104, 10), 1, "the first leg under the mouse")
Eq(Way.OnLeg(47, run.route, place, 503, 300, 10), 2, "the second leg under the mouse")
Eq(pen:Insert(1, F, 0.3, 0.1), 2, "the point on the leg")
Eq(#run.route, 4, "insert added nothing")
Eq(pen:Insert(4, F, 0.3, 0.1), nil, "a point on a leg after the last point")
-- A drag is one undo step, and only when it moved.
local before = run.route[2].x
Check(pen:Grab(2), "a plain point cannot be grabbed")
Check(not pen:Drop(), "a drag that did not move is an undo step")
Check(pen:Grab(2) and pen:MoveTo(2, F, 0.31, 0.2) and pen:MoveTo(2, F, 0.32, 0.25), "the drag")
Check(pen:Drop(), "the drag left no undo step")
Eq(run.route[2].y, 0.25, "the point is not where it was dropped")
Check(pen:Undo() and run.route[2].x == before and run.route[2].y == 0.1, "undo did not take the drag back whole")
-- Stops stay on their boss.
pen:AddStop(boss.name)
Check(not pen:Grab(#run.route), "a stop can be dragged")
Check(not pen:MoveTo(#run.route, F, 0.9, 0.9), "a stop moved")
-- Deleting: the selection goes onto the point before.
pen:Select(3)
Check(pen:Delete(3) and #run.route == 4 and pen.at == 2, "deleting a point")
Check(not pen:Delete(99), "deleting a point that is not there")

--------------------------------------------------------------------------
Section("the pen: steps at markers, linked ones in pairs")

-- Shadowfang Keep's drawn map links its floors' stairs.
local SFK = 33
local link = ns.DCF.MarkerLinks[SFK][1]
local function MarkerAt(f, x, y)
    for _, m in ipairs(D.Markers(SFK, f)) do
        if D.Near(f, m.x, m.y, f, x, y) then return m end
    end
end
local near = MarkerAt(link.fa, link.xa, link.ya)
Check(near, "no marker at the link's end")
local to = D.LinkOf(SFK, link.fa, link.xa, link.ya)
Check(to and to.floor == link.fb and math.abs(to.x - link.xb) < 1e-9 and to.letter == "A", "the link's far end")
local back = D.LinkOf(SFK, link.fb, link.xb, link.yb)
Check(back and back.floor == link.fa and back.letter == "A", "the link from its far end")
Eq(D.LinkOf(SFK, link.fa, 0.999, 0.999), nil, "a link where there is none")

local sfk = { id = 9002, instanceID = SFK }
pen = Way.Pen(sfk, nil)
pen:Clear()
pen:Add(link.fa, 0.5, 0.2)
Eq(pen:AddStep({ floor = link.fa, x = near.x, y = near.y, kind = near.kind }), 3, "a linked step is not two points")
local a, b = sfk.route[2], sfk.route[3]
Check(a.kind == near.kind and a.tag == "A" and not a.pair, "the near end of the step")
Check(b.pair and b.tag == "A" and b.f == link.fb and math.abs(b.x - link.xb) < 1e-4, "the far end of the step")
Check(not pen:Grab(2), "a step can be dragged")
-- A linked pair is one undo step, and goes out together from either end.
Check(pen:Undo() and #sfk.route == 1, "undo did not take both ends")
pen:AddStep({ floor = link.fa, x = near.x, y = near.y, kind = near.kind })
Check(pen:Delete(3) and #sfk.route == 1, "deleting the far end left the near one")
pen:AddStep({ floor = link.fa, x = near.x, y = near.y, kind = near.kind })
Check(pen:Delete(2) and #sfk.route == 1, "deleting the near end left the far one")
-- A trigger: its label is the tag, the boss it starts kept.
Eq(pen:AddStep({ floor = link.fa, x = 0.2, y = 0.2, kind = "trigger", label = "Talk to Naralex",
    boss = "Mutanus the Devourer" }), 2, "a trigger is not one point")
Check(sfk.route[2].tag == "Talk to Naralex" and sfk.route[2].mboss == "Mutanus the Devourer", "the trigger's words")

--------------------------------------------------------------------------
Section("the pen: cut and connect")

run = Fresh()
pen = Way.Pen(run, nil)
pen:Clear()
for k = 1, 6 do pen:Add(F, k / 10, 0.3) end
run.route[5].boss = boss.name
Check(not pen:Cut(6), "a cut after the last point")
Check(pen:Cut(2), "the cut")
Eq(pen:Gap(), 3, "the grey part does not start after the cut")
Eq(pen.at, 2, "new points do not go in at the cut")
Check(not pen:Cut(1), "a second cut while one is open")
pen:Add(F, 0.25, 0.6)
Eq(run.route[3].x, 0.25, "the new point is not at the cut")
Eq(pen:Gap(), 4, "the grey part moved")
Eq(pen:Connect(2), nil, "connecting to a point before the grey part")
local dropped = pen:Connect(7)
Check(dropped and #dropped == 1 and dropped[1] == boss.name, "the stop that went is not named")
Eq(#run.route, 4, "the grey points before it did not go")
Eq(pen:Gap(), nil, "the way is still cut")
-- Left open, finishing joins it to its first grey point.
pen:Cut(1)
Check(pen:Finish() and pen:Gap() == nil and #run.route == 4, "finishing left the cut open")
-- A grey point deleted passes the cut on.
pen:Cut(1)
pen:Delete(2)
Eq(pen:Gap(), 2, "the cut went with the point it was on")

--------------------------------------------------------------------------
Section("the pen: reset, and the cap")

Check(pen:CanUndo(), "nothing to undo before the reset")
Check(pen:Reset(), "reset says there was nothing")
Eq(run.route, nil, "reset left the drawing")
Check(not pen:CanUndo() and not pen:Undo(), "the reset can be undone")
Check(D.WayOf(run, nil) == usual, "after the reset it is not the usual way")
Check(not pen:Reset(), "a second reset found a drawing")

run = Fresh()
pen = Way.Pen(run, nil)
pen:Clear()
for k = 1, Way.MAX do pen:Add(F, 0.5, k / Way.MAX) end
Eq(#run.route, Way.MAX, "the way is not full")
Eq(pen:Add(F, 0.5, 0.5), nil, "a point past the cap")
Eq(pen:Insert(1, F, 0.5, 0.5), nil, "a point past the cap, on a leg")

-- Saved with the visit: a drawn way survives as plain data.
local saved = RFK
pen = Way.Pen(saved, nil)
pen:Add(F, 0.4, 0.4)
Check(ns.db.instances[saved.id].route == saved.route, "the drawing is not on the saved visit")
for _, p in ipairs(saved.route) do
    for k, v in pairs(p) do
        Check(type(v) == "number" or type(v) == "string" or type(v) == "boolean", "a point keeps a " .. type(v) .. " in " .. k)
    end
end
pen:Reset()
