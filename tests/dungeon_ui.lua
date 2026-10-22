-- A dungeon run's map on the table spread (UI/Dungeon/, UI/Map/Dungeon.lua;
-- TLN-12, DGN-1, MAP-1 to MAP-4, MAP-7, MAP-13 to MAP-18): a click on a
-- visit's card lays the run's map out over the book, the floor printed on
-- a big folded sheet, cut along its folds, with what happened over it.
-- /sd testdata writes the two visits: Razorfen Kraul (client art, a rare
-- killed) and Wailing Caverns (drawn art, inside a session). The host, its
-- fit to the screen and every way back are tests/dungeon_spread.lua's.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local D = ns.Dungeons
local Page = ns.UI.DungeonPage

-- A Forever dungeon: the client has no group finder picture of it.
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-HallofThanes"] = true
mock.missingFiles["Interface\\LFGFrame\\LFGIcon-TestVault"] = true
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local panel = _G.SocialDiaryJournalFrame
local p = panel.profile
local TL = p.timeline

local function VisitOf(instanceID)
    for _, visit in ipairs(ns.Instances.For(G)) do
        if visit.instanceID == instanceID then return visit end
    end
end
local RFK, WC = VisitOf(47), VisitOf(43)
Check(RFK and WC, "the test data's visits")

-- The card on the timeline for `visit`, scrolled into view.
local function Card(visit)
    for offset = 0, #TL.data do
        TL:SetOffset(offset)
        for _, row in ipairs(TL.rows) do
            local line = row:IsShown() and row.item
            if line and line.visit and line.visit.visit == visit then return row end
        end
    end
end

local function Open() return J.visit and J.visit.id end
local function Near(a, b) return math.abs(a - b) < 1e-6 end

-- Every tooltip on the map, by its title: the lines under it joined.
local function Tips(view)
    local tips, byTitle = {}, {}
    for i = 1, view.pools.hit.used do
        local tip = view.pools.hit[i].tip
        local lines = {}
        for j = 2, #tip do lines[#lines + 1] = tip[j][1] end
        tips[tip[1][1]] = table.concat(lines, " / ")
        byTitle[tip[1][1]] = tip
    end
    return tips, byTitle
end

-- Every strip laid on the map, as it must lie (Notes.lua's PLACE): a
-- third of it and its tape on the paper (it may stick out past its edge),
-- on the screen where the spread says where that is, off every mark's halo, off each other, the floors' label and the
-- count; never across a valley of the fold (across a ridge only where it
-- lies over the crest); turned the sheet's way and a little its own; its
-- leader a tick where it lies near its mark, else an arrow, never across
-- another face.
local function StripsSound(view, label)
    local PL, L = Page.PLACE, Page.LEADER
    local W_, H_ = view.w, view.h
    local plan = view.plan
    local spots, faces = {}, {}
    for _, mark in ipairs(plan.marks) do
        local t = plan.targets[mark.name]
        spots[#spots + 1] = { t.x, t.y, math.max(t.r, Page.KILL.halo / 2) }
        faces[#faces + 1] = t
        if mark.number then spots[#spots + 1] = { mark.number.x, mark.number.y, Page.KILL.number.halo / 2 } end
    end
    for _, c in ipairs(plan.crosses) do spots[#spots + 1] = { c.x, c.y, Page.DEATH.halo / 2 } end
    if plan.door then spots[#spots + 1] = { plan.door.x, plan.door.y, Page.KILL.halo / 2 } end
    for _, f in ipairs(plan.flavour or {}) do spots[#spots + 1] = { f.x, f.y, f.r } end
    local X, Y, folds = view.K.Lines()
    local valleys, ridges = {}, {}
    for k, f in pairs(folds.columns) do table.insert(f.sign < 0 and valleys or ridges, { 1, X[k] }) end
    for k, f in pairs(folds.rows) do table.insert(f.sign < 0 and valleys or ridges, { 2, Y[k] }) end
    for i, e in ipairs(view.noteStrips) do
        local b = e.box
        local what = label .. ", " .. e.note.kind .. " strip: "
        Check(e.strip:IsShown(), what .. "not shown")
        local ix = math.max(0, math.min(b[3], W_) - math.max(b[1], 0))
        local iy = math.max(0, math.min(b[4], H_) - math.max(b[2], 0))
        Check(ix * iy >= (b[3] - b[1]) * (b[4] - b[2]) / 3 - 1e-6, what .. "less than a third on the paper")
        Check(#e.tape == 4, what .. "no tape")
        for _, p in ipairs(e.tape) do
            Check(p[1] >= PL.tape - 1e-6 and p[2] >= PL.tape - 1e-6 and p[1] <= W_ - PL.tape + 1e-6
                and p[2] <= H_ - PL.tape + 1e-6, what .. "its tape off the paper")
        end
        if view.screen then
            for _, p in ipairs({ { b[1], b[2] }, { b[3], b[2] }, { b[3], b[4] }, { b[1], b[4] } }) do
                local X, Y = view.K.Screen(p[1], p[2])
                X, Y = X + view.lie[1], Y + view.lie[2]
                Check(math.abs(X) <= view.screen.w / 2 - PL.screen + 1e-6 and math.abs(Y) <= view.screen.h / 2 - PL.screen + 1e-6,
                    what .. "off the screen")
            end
        end
        for _, sp in ipairs(spots) do
            local cx, cy = math.max(b[1], math.min(b[3], sp[1])), math.max(b[2], math.min(b[4], sp[2]))
            Check((cx - sp[1]) ^ 2 + (cy - sp[2]) ^ 2 >= (sp[3] + PL.clear) ^ 2 - 1e-6, what .. "over a mark")
        end
        local others = { view.labelBox }
        for j = i + 1, #view.noteStrips do others[#others + 1] = view.noteStrips[j].box end
        for _, o in pairs(others) do
            Check(not (b[1] < o[3] + PL.apart - 1e-6 and o[1] < b[3] + PL.apart - 1e-6
                and b[2] < o[4] + PL.apart - 1e-6 and o[2] < b[4] + PL.apart - 1e-6), what .. "over another strip or the label")
        end
        for _, v in ipairs(valleys) do
            local lo, hi = b[v[1]], b[v[1] + 2]
            Check(v[2] <= lo - PL.fold + 1e-6 or v[2] >= hi + PL.fold - 1e-6, what .. "across a valley")
        end
        for _, r in ipairs(ridges) do
            local lo, hi = b[r[1]], b[r[1] + 2]
            Check(r[2] <= lo - PL.fold + 1e-6 or r[2] >= hi + PL.fold - 1e-6
                or (r[2] >= lo + PL.fold - 1e-6 and r[2] <= hi - PL.fold + 1e-6), what .. "on a ridge's edge")
        end
        if not ns.Setting("flatSheets") then
            Check(math.abs(e.strip.turn - view.angle) <= math.rad(PL.jitter) + 1e-9, what .. "not turned with the sheet")
        end
        -- The leader: a tick near, an arrow further; never across a face.
        local gap = math.sqrt((e.target.x - e.from[1]) ^ 2 + (e.target.y - e.from[2]) ^ 2) - e.target.r
        Check(Near(gap, e.gap), what .. "its gap")
        Eq(e.leader, gap < L.tick.near and "tick" or "arrow", what .. "the wrong leader")
        if e.leader == "arrow" then
            Check(e.tip, what .. "no arrow")
            local d = math.sqrt((e.tip[1] - e.target.x) ^ 2 + (e.tip[2] - e.target.y) ^ 2)
            Check(Near(d, e.target.r + L.gap), what .. "an arrow not at its mark's edge")
        end
        for _, f in ipairs(faces) do
            if f ~= e.target then
                local ax, ay, bx, by = e.from[1], e.from[2], e.target.x, e.target.y
                local dx, dy = bx - ax, by - ay
                local t = math.max(0, math.min(1, ((f.x - ax) * dx + (f.y - ay) * dy) / (dx * dx + dy * dy)))
                Check((ax + dx * t - f.x) ^ 2 + (ay + dy * t - f.y) ^ 2 >= (f.r + 2) ^ 2 - 1e-6, what .. "its leader over a face")
            end
        end
    end
    Check(view.leaders.used > 0 or #view.noteStrips == 0, label .. ": no leaders drawn")
    -- The leaders in chalk, the strips' cream, over a faint dark stroke.
    local C = Page.CHALK.colour
    for i = 1, view.leaders.used do
        local c = view.leaders[i].recorded.calls.SetColorTexture
        local lit = c[1] / C[1]
        Check(lit > 0.8 and lit < 1.15 and math.abs(c[2] / C[2] - lit) < 1e-6, label .. ": a leader not in chalk")
    end
    Eq(view.leaderUnder.used, view.leaders.used, label .. ": a leader without its dark stroke")
    if view.leaderUnder.used > 0 then
        local u = view.leaderUnder[1].recorded.calls.SetColorTexture
        Check(u[4] == Page.CHALK.under.alpha and u[1] < 0.3, label .. ": the dark stroke not faint and dark")
    end
end

local function Marks(view)
    local marks = {}
    for _, mark in ipairs(view.plan.marks) do marks[mark.name] = mark end
    return marks
end

--------------------------------------------------------------------------
Section("the card lays the run out on the table (TLN-12)")

local card = Card(RFK)
Check(card, "no Razorfen Kraul card on the timeline")
card.scripts.OnEnter(card)
Check(GameTooltip.text and GameTooltip.text:find("Click to open its map%."), "the card's tooltip: "
    .. tostring(GameTooltip.text))
Eq(card.visit.hot, true, "the card does not lift under the mouse")
card.scripts.OnLeave(card)
Eq(card.visit.hot, nil, "the card stays lifted after the mouse left")

-- No more folding: the click does not change the timeline's lines.
local before = #TL.data
TL:SetOffset(2)
card = Card(RFK)
local offset = TL.offset
card.scripts.OnMouseUp(card)
Eq(Open(), RFK.id, "the click did not open the visit")
local spread = Page.Spread()
local view = spread.map
Check(spread:IsShown() and view:IsShown(), "the map is not out on the table")
Eq(#TL.data, before, "the visit folded open in place")
-- The person's page stays as it was under it: their story, where it was
-- read, the People list and the tabs.
Check(TL:IsShown(), "the timeline went from the page")
Eq(TL.offset, offset, "the timeline lost its place")
Check(panel.people:IsShown(), "the People list went with it")
Check(p.tabStory.selected, "their story's tab is not lit under the spread")
Eq(ns.UI.JournalView(), "people", "the book turned")
Eq(p.dungeon, nil, "the right page still hosts a dungeon page")
-- With the run out, the card's click puts it away.
card.scripts.OnEnter(card)
Check(GameTooltip.text:find("Click to go back to their story%."), "the open run's card: " .. GameTooltip.text)
card.scripts.OnLeave(card)

-- The sheet: the map's own shape, turned 3.5 degrees the other way round
-- to the clock, a little under the book's middle (where it slides on a
-- screen too small: tests/dungeon_spread.lua).
local SW, SH = view.w, view.h
Check(SW <= Page.SIZE.w + 1e-6, "the sheet wider than its room: " .. SW)
Eq(view.dy, -Page.SHEET.down, "the sheet does not lie under the book's middle")
Eq(view.dx, 0, "the sheet lies off the book's middle")

--------------------------------------------------------------------------
Section("the art: the main floor, cut along the sheet's mesh")

local floor, index = D.MainFloor(RFK)
Eq(view.floorIndex, index, "not on the main floor")
local printer = view.printer
Eq(printer.pieces, 12, "Razorfen Kraul's twelve tiles")
Check(printer.cuts > printer.pieces, "the folds cut no tile: " .. printer.cuts)
Eq(printer.tiles.used, printer.cuts, "a texture per cut")
local files = {}
for _, row in ipairs(floor.tiles) do
    for _, file in ipairs(row) do files[file] = true end
end
for i = 1, printer.tiles.used do
    local t = printer.tiles[i]
    Check(files[t.recorded.calls.SetTexture[1]], "a cut from another floor's art")
    local tc = t.recorded.calls.SetTexCoord
    Check(tc[1] >= -1e-9 and tc[2] <= 1 + 1e-9 and tc[3] >= -1e-9 and tc[4] <= 1 + 1e-9 and tc[2] > tc[1]
        and tc[4] > tc[3], "a cut's texture coordinates run off its file")
end
-- Printed on the paper: toned (here, where nothing greys, `plain`), and
-- each cut lit by its facet.
local tint = printer.tiles[1].recorded.calls.SetVertexColor
local light = tint[1] / ns.UI.JourneyPlate.PLATE.plain[1]
Check(light > 0.8 and light < 1.15, "the art is not toned toward the paper: " .. tint[1])
-- Edge to edge and whole: the floor's whole image is the whole sheet,
-- and the sheet is its shape, as big as its room allows.
local Map = ns.UI.DungeonMap

-- The whole image on the paper, nothing cut (16 Oct: a trim of the drawn
-- maps' border cut Wailing Caverns' banner and caves off): the floor's w
-- by h is the sheet's W by H; every piece of it printed; each file's
-- coordinates from 0 at the image's left and top to its right and bottom
-- edge (1 for a tile that ends there); and the marks where the art puts
-- their points, by the same scale.
local function Whole(view, floor, label)
    local W_, H_ = view.w, view.h
    local b = view.box
    Check(Near(b.x, 0) and Near(b.y, 0) and Near(b.w, W_) and Near(b.h, H_),
        ("%s: the image is not the sheet: %.1f,%.1f %.1fx%.1f on %.1fx%.1f"):format(label, b.x, b.y, b.w, b.h, W_, H_))
    local pieces = Map.Pieces(floor)
    Eq(view.printer.pieces, #pieces, label .. ": a piece of the image left off")
    -- Each file's coordinates as printed, all its cuts together.
    local span = {}
    for i = 1, view.printer.tiles.used do
        local t = view.printer.tiles[i]
        local file, tc = t.recorded.calls.SetTexture[1], t.recorded.calls.SetTexCoord
        local f = span[file] or { 1, 0, 1, 0 }
        span[file] = { math.min(f[1], tc[1]), math.max(f[2], tc[2]), math.min(f[3], tc[3]), math.max(f[4], tc[4]) }
    end
    for _, p in ipairs(pieces) do
        local f = span[p.file]
        Check(f, label .. ": a file not printed")
        Check(Near(f[1], p.u0) and Near(f[2], p.u1) and Near(f[3], p.v0) and Near(f[4], p.v1),
            label .. ": a file printed short of its piece")
        if floor.tiles and not floor.yards and floor.tile then
            -- A tile starts at 0 and runs to 1, or to the image's edge.
            Check(Near(p.u0, 0) and Near(p.v0, 0), label .. ": a tile cut at its left or top")
            Check(Near(p.u1, math.min(1, (floor.w - (p.x0 - p.x0 % floor.tile)) / floor.tile))
                and Near(p.v1, math.min(1, (floor.h - (p.y0 - p.y0 % floor.tile)) / floor.tile)),
                label .. ": a tile cut short of the image's edge")
        end
    end
    for _, mark in ipairs(view.plan.marks) do
        local bo = mark.boss
        if tonumber(bo.floor) == floor.uiMapID then
            Check(Near(mark.at[1], bo.x * W_) and Near(mark.at[2], bo.y * H_), label .. ": a mark off the art's point: " .. mark.name)
        end
    end
end
Whole(view, floor, "Razorfen Kraul")
local box, kept, sc = view.box, view.kept, view.scale
local kw, kh = kept[3] - kept[1], kept[4] - kept[2]
Check(math.abs(box.w / box.h - floor.w / floor.h) < 1e-9, "the art out of shape")
Check(Near(SW / SH, kw / kh), "the sheet is not the art's shape")
Check(Near(sc * kw, SW) and Near(sc * kh, SH), "the art does not fill the sheet")
Check(Near(box.x + kept[1] * sc, 0) and Near(box.y + kept[2] * sc, 0), "the art not from the paper's corner")
local fitW, fitH = Page.SheetSize(SW / SH)
Check(Near(fitW, SW) and Near(fitH, SH), "the sheet not as big as its room")
local trim = Map.Kept(floor)
Check(trim[1] == 0 and trim[2] == 0 and trim[3] == floor.w and trim[4] == floor.h, "the client art's edge is cut off")
-- Every boss, the door and the way through on the paper, clear of its edge.
local M_ = Map.MARGIN
local function OnPaper(x, y, m) return x >= m - 1e-6 and y >= m - 1e-6 and x <= SW - m + 1e-6 and y <= SH - m + 1e-6 end
for _, mark in ipairs(view.plan.marks) do
    Check(OnPaper(mark.at[1], mark.at[2], M_.mark), "a boss too near the paper's edge: " .. mark.name)
    Check(OnPaper(mark.x, mark.y, Page.LABEL.inside), "a mark moved off the paper: " .. mark.name)
end
Check(OnPaper(view.plan.door.x, view.plan.door.y, M_.door), "the way in too near the paper's edge")
for _, pt in ipairs(view.plan.path.pts) do
    if pt then Check(OnPaper(pt[1], pt[2], M_.way - 1e-6), "the way through runs off the paper") end
end
for _, c in ipairs(view.plan.crosses) do
    Check(OnPaper(c.x, c.y, 4), "a cross off the paper")
end

-- Each cut lies in one facet of the mesh: the art is cut along it.
local K = view.K
local cuts, bend = {}, K.Bend
K.Bend = function(texture, x0, y0, x1, y1, seal)
    cuts[texture] = { x0, y0, x1, y1 }
    return bend(texture, x0, y0, x1, y1, seal)
end
view:Open(RFK, G)
K.Bend = bend
local X, Y, folds = K.Lines()
local function Facet(r)
    local inX, inY = false, false
    for i = 1, #X - 1 do
        if r[1] >= X[i] - 1e-6 and r[3] <= X[i + 1] + 1e-6 then inX = true end
    end
    for j = 1, #Y - 1 do
        if r[2] >= Y[j] - 1e-6 and r[4] <= Y[j + 1] + 1e-6 then inY = true end
    end
    return inX and inY
end
local laid = 0
for i = 1, printer.tiles.used do
    local r = cuts[printer.tiles[i]]
    Check(r, "a cut not laid through the mesh")
    Check(Facet(r), ("a cut across a facet's edge: %.1f,%.1f to %.1f,%.1f"):format(r[1], r[2], r[3], r[4]))
    laid = laid + (r[3] - r[1]) * (r[4] - r[2])
end
-- Together the cuts cover the paper (a hair over, where tiles meet).
Check(laid >= SW * SH - 1e-6 and laid < SW * SH * 1.02, "the cuts do not cover the paper: " .. laid)
-- Three panels across and two down, for a map as wide as this.
Eq(view.grid[1] .. "x" .. view.grid[2], "3x2", "Razorfen Kraul's folds")
local across, down = 0, 0
for _ in pairs(folds.columns) do across = across + 1 end
for _ in pairs(folds.rows) do down = down + 1 end
Eq(across, 2, "two folds across")
Eq(down, 1, "one fold down")

--------------------------------------------------------------------------
Section("the folds keep clear of the faces, the numbers and the way in")

local pad = Page.FOLDS.pad
local function Clear(view)
    local X, Y, folds = view.K.Lines()
    for k in pairs(folds.columns) do
        for _, spot in ipairs(view.plan.spots) do
            if math.abs(X[k] - spot.x) < spot.r + pad then return false, "across at " .. X[k] end
        end
    end
    for k in pairs(folds.rows) do
        for _, spot in ipairs(view.plan.spots) do
            if math.abs(Y[k] - spot.y) < spot.r + pad then return false, "down at " .. Y[k] end
        end
    end
    return true
end
Check(#view.plan.spots >= 10, "the faces, numbers and door are not kept clear of: " .. #view.plan.spots)
Check(Clear(view))
-- A fold on a face moves the least it can, within its reach.
local probe, PK = ns.UI.LooseSheet(UIParent, 1010, 580)
PK.Fall("folds", 0)
local PX, PY, pf = PK.Lines()
local col
for k in pairs(pf.columns) do col = col or k end
local natural = PX[col]
PK.Clear({ { x = natural, y = 100, r = 12 } }, 30, 4)
Check(math.abs(PX[col] - natural) >= 16 - 1e-9 and math.abs(PX[col] - natural) <= 16 + 1e-9,
    "the fold did not step just clear of the face: " .. (PX[col] - natural))
-- Clearing again starts from where it fell, not where it was moved to.
PK.Clear({}, 30, 4)
Check(Near(PX[col], natural), "a fold stays moved with nothing in its way")
-- Nowhere clear in reach: where it cuts the fewest.
PK.Clear({ { x = natural, y = 0, r = 60 }, { x = natural + 40, y = 0, r = 10 } }, 30, 4)
Check(math.abs(PX[col] - natural) <= 30, "a fold moved past its reach")
-- A new fall puts the folds back.
PK.Clear({ { x = natural, y = 100, r = 12 } }, 30, 4)
PK.Fall("folds", 0)
Check(Near(PX[col], natural), "a new fall kept the folds moved")
probe:Hide()

--------------------------------------------------------------------------
Section("bosses: inked when killed, pencil when not, rares when killed, trash never")

local marks = Marks(view)
Eq(#view.plan.marks, 6, "Razorfen Kraul's marks")
Check(marks.Roogug and marks.Roogug.killed and marks.Roogug.rare, "the rare killed is not marked")
Eq(marks.Roogug.order, 1, "the first to fall")
Eq(marks["Overlord Ramtusk"].order, 4, "the fourth to fall")
Check(marks["Aggem Thorncurse"].killed and marks["Death Speaker Jargba"].killed, "a kill not inked")
Check(not marks["Agathelos the Raging"].killed and not marks["Charlga Razorflank"].killed,
    "a boss left standing is inked")
Eq(marks.Trash, nil, "the trash is marked")
-- Each boss is its own face: the kills in brass (the rare in silver), with
-- their numbers; the standing ones greyed in pencil. A face from the
-- creature's display where it has one, else its portrait texture.
local pools = view.pools
Eq(pools.medal.used, 4, "a face per kill")
Eq(pools.sketch.used, 2, "a face per boss standing")
Eq(pools.fill.used, 0, "a lozenge where there is a face")
Eq(pools.number.used, 4, "a number per kill")
Eq(pools.number[4]:GetText(), "4", "the last number")
local looks, byDisplay = {}, {}
for i = 1, pools.medal.used do
    local medal = pools.medal[i]
    looks[medal.look] = (looks[medal.look] or 0) + 1
    if medal.icon.portrait then byDisplay[medal.icon.portrait] = medal end
end
Eq(looks.rare, 1, "the rare killed is not in silver")
Eq(looks.killed, 3, "the kills are not in brass")
Eq(marks.Roogug.face, "portrait", "Roogug's face is not his portrait")
Eq(marks["Aggem Thorncurse"].face, "display", "Aggem's face is not from his display")
Check(byDisplay[6097] and byDisplay[6097].look == "killed", "Aggem's display is not on a brass face")
local standing = pools.sketch[1]
Eq(standing.look, "standing", "a boss standing is not in pencil")
Eq(standing.icon.recorded.calls.SetDesaturated[1], true, "a boss standing is not greyed")
Eq(standing.icon.recorded.calls.SetAlpha[1], 0.55, "a boss standing is not faded")
Eq(byDisplay[6097].icon.recorded.calls.SetDesaturated[1], false, "a kill is greyed")
-- On the paper: a face's middle where the sheet takes its point, a number
-- turned with the sheet, the medals over the paper and the numbers over
-- the medals.
local aggem = marks["Aggem Thorncurse"]
local at = byDisplay[6097].recorded.points[1].args
local sx, sy = K.Screen(aggem.x, aggem.y)
Check(at[1] == view.sheet and Near(at[3], sx) and Near(at[4], sy), "a face not where the sheet takes its point")
Check(Near(pools.number[1].recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn)),
    "a number not turned with the sheet")
Check(pools.medal[1].parent:GetFrameLevel() > view.sheet:GetFrameLevel()
    and pools.number[1].parent:GetFrameLevel() > pools.medal[1].parent:GetFrameLevel(),
    "the faces and numbers are not over the paper in order")
-- A rare not killed is left off.
local unkilled = { id = 9001, instanceID = 47, bossesKilled = { "Aggem Thorncurse" } }
local names = {}
for _, mark in ipairs(Page.Marks(unkilled)) do names[mark.boss.name] = mark.killed end
Eq(names.Roogug, nil, "a rare left standing is marked")
Eq(names["Aggem Thorncurse"], true, "a kill")
Eq(names["Charlga Razorflank"], false, "a boss standing")

-- Tooltips say what each mark is; there is no key.
local tips, byTitle = Tips(view)
Eq(tips.Roogug, "Rare / Killed on this run", "the rare's tooltip")
Eq(tips["Charlga Razorflank"], "Not killed on this run", "a standing boss's tooltip")
Eq(tips["Death Speaker Jargba"], "Killed on this run / Nearly wiped / " .. ns.Style.Inkify(RFK.loot[2].item)
    .. ", dropped for you", "a kill's tooltip, nearly lost, an epic for you")
-- What happened at a boss, under its name (MAP-13's words, all of them).
Eq(tips["Aggem Thorncurse"], "Killed on this run / Wiped once / Killed on the second try / "
    .. ns.Style.Inkify(RFK.loot[1].item) .. ", dropped for Tester", "what happened at Aggem")
Check(view.plan.door, "no way in on the map")
Eq(byTitle["The way in"] and byTitle["The way in"][2] and byTitle["The way in"][2][1], "Ran back once as a ghost",
    "the runs back are not on the way in's tooltip")
-- A tooltip's square over its mark, over everything else on the sheet.
local hit = pools.hit[1]
Check(hit.parent:GetFrameLevel() > pools.number[1].parent:GetFrameLevel(), "the tooltips' squares lie under the numbers")
Eq(hit.recorded.points[1].args[1], view.sheet, "a tooltip's square not placed on the sheet")

-- No face to show (no client call for a display's portrait): a portrait
-- texture still comes; the rest fall back to the lozenge and the ring,
-- never an empty circle.
local Portrait = _G.SetPortraitTextureFromCreatureDisplayID
_G.SetPortraitTextureFromCreatureDisplayID = nil
view:Open(RFK, G)
marks = Marks(view)
Eq(marks.Roogug.face, "portrait", "a portrait texture needs the display call")
Eq(marks["Aggem Thorncurse"].face, nil, "a face without the call")
Eq(pools.medal.used, 1, "faces without the call")
Eq(pools.fill.used, 3, "no lozenge for a kill without a face")
Eq(pools.sketch.used, 1, "Charlga's portrait is not shown")
Check(pools.ink.used > 3 * 2, "no pencil ring for Agathelos without a face")
Eq(pools.number.used, 4, "a kill without a face lost its number")
-- The lozenge stands on its point, turned with the sheet.
Check(Near(pools.fill[1].recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn) + math.pi / 4),
    "a lozenge not turned with the sheet")
_G.SetPortraitTextureFromCreatureDisplayID = Portrait
local faceless = ns.Style.BossMedallion(UIParent, 24)
Eq(faceless:SetBoss("killed", nil, nil), nil, "a face from nothing")
Eq(faceless:SetBoss("killed", 6097, nil), "display", "a face from a display")
Eq(faceless.icon.portrait, 6097, "the display's portrait is not on the face")
view:Open(RFK, G)

--------------------------------------------------------------------------
Section("the usual way through (MAP-4)")

local counts = view.plan.routeCounts
Check(counts.ink > 0, "no ink to the last boss killed")
Check(counts.pencil > 0, "no pencil past the last boss killed")
Check(pools.route.used >= counts.ink + counts.pencil, "a piece of the way not drawn")
-- The way still to go in chalk over a faint dark stroke; the way gone in ink.
Eq(pools.routeUnder.used, counts.pencil, "the chalk way without its dark stroke")
local chalked = 0
for i = 1, pools.route.used do
    local c = pools.route[i].recorded.calls.SetColorTexture
    if c[1] > 0.6 and c[1] / Page.CHALK.colour[1] > 0.8 then chalked = chalked + 1 end
end
Eq(chalked, counts.pencil, "the way still to go not in chalk")
Check(pools.route[1].recorded.calls.SetColorTexture[1] < 0.4, "the way gone not in ink")
-- Whether it is drawn is a setting, on Interface's Dungeons and Raids page.
Eq(ns.SettingDefault("dungeonRoute"), true, "the usual way is not drawn by default")
Eq(ns.IsAccountSetting("dungeonRoute"), false, "the usual way is not the character's setting")
local SP = ns.UI.SettingsPage()
Eq(ns.UI.Settings.Sections()[5].key, "dungeons", "Dungeons and Raids is not after Keybinds & Shortcuts")
Eq(ns.UI.Settings.Sections()[5].parent, "interface", "Dungeons and Raids is not Interface's subpage")
Eq(SP.nav.dungeons.label:GetText(), "Dungeons and Raids", "the subpage's name")
-- The book turned to the settings puts the run away.
ns.UI.ShowSettings("dungeons")
Eq(Open(), nil, "the run stayed out over the settings")
Check(not spread:IsShown(), "the spread lies over the settings")
Check(SP.dungeonRoute:GetChecked(), "the switch is not on by default")
SP.dungeonRoute.scripts.OnClick(SP.dungeonRoute)
Eq(ns.Setting("dungeonRoute"), false, "the switch did not turn the setting off")
ns.UI.OpenVisit(RFK.id, G)
Eq(view.plan.routeCounts.ink + view.plan.routeCounts.pencil, 0, "the way drawn with the setting off")
Eq(pools.route.used, 0, "pieces of the way left on the map")
-- Laid again as the settings change, while it is out.
ns.SetSetting("dungeonRoute", true)
Page.Refresh()
Check(view.plan.routeCounts.ink > 0, "the way not drawn again")
ns.UI.OpenVisit(RFK.id, G)
Eq(Open(), nil, "a second click did not put the run away")

--------------------------------------------------------------------------
Section("a run inside a session, on drawn art")

card = Card(WC)
Check(card and card.item.depth == 1, "the Wailing Caverns card is not inside its session")
card.scripts.OnMouseUp(card)
Eq(Open(), WC.id, "the Wailing Caverns card did not open")
local wcFloor = view.floors[view.floorIndex]
Check(wcFloor.custom, "Wailing Caverns is not on its drawn map")
Eq(printer.pieces, 24, "Wailing Caverns' tiles")
Check(printer.tiles[1].recorded.calls.SetTexture[1]:find("social_diary\\Vendor\\DungeonCrawlerForever\\Art\\43_", 1, true),
    "a drawn tile is not ours")
Check(Clear(view))
Whole(view, wcFloor, "Wailing Caverns")
-- The drawn map runs to its edges: its last tiles to their files' edges.
Eq(wcFloor.w, 6 * wcFloor.tile, "Wailing Caverns is not six tiles wide")
Eq(wcFloor.h, 4 * wcFloor.tile, "Wailing Caverns is not four tiles tall")
-- A run with nothing to say (no pulls, deaths or loot kept): no crosses.
Eq(#view.plan.crosses, 0, "crosses for a run without deaths")
Eq(#view.noteStrips, 0, "strips for a run with nothing to say")
Eq(view.notesMore, 0, "a count for a run with nothing to say")
ns.UI.OpenVisit(WC.id, G)

--------------------------------------------------------------------------
Section("floors to choose")

local function Visit(fields)
    fields.members = { { guid = G, first = "Tester" }, { guid = ns.ownGUID, first = "Me" } }
    fields.startedAt, fields.endedAt = mock.now - 3000, mock.now - 1200
    fields.instanceType = "party"
    return ns.Instances.New(fields)
end

-- The Deadmines: two floors, the kills on the second.
local vc = Visit({ instanceID = 36, name = "The Deadmines", bossesKilled = { "Rhahk'Zor", "Gilnid", "Mr. Smite" },
    bossTotal = 8 })
Eq(ns.UI.OpenVisit(vc.id, G), true, "the Deadmines did not open")
Eq(view.floorIndex, 2, "not on the floor of most kills")
Eq(view.links.used, 2, "a link per floor")
Check(view.links[2].current and not view.links[1].current, "the floor shown is not marked")
Eq(view.links[1]:GetText(), "The Deadmines", "a floor's name")
-- On a label of paper pasted in the map's bottom-right corner.
local linkAt = view.links[1].label.recorded.points[1].args
Check(linkAt[1] == view.sheet, "a floor's link not on the sheet")
local lb = view.labelBox
Check(lb and Near(lb[3], view.w - Page.LABEL.inset) and Near(lb[4], view.h - Page.LABEL.inset), "the floors' label not in the corner")
Check(view.label.used > 0 and view.label[1].recorded.calls.SetColorTexture[1] > 0.6, "the label is not paper")
for _, mark in ipairs(view.plan.marks) do
    Check(not (mark.x > lb[1] and mark.x < lb[3] and mark.y > lb[2] and mark.y < lb[4]), "a mark under the floors' label")
end
Check(Near(view.links[1].label.recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn)), "a link not turned with the sheet")
Whole(view, view.floors[2], "Ironclad Cove")
view.links[1].scripts.OnClick(view.links[1])
Eq(view.floorIndex, 1, "a link does not show its floor")
Whole(view, view.floors[1], "The Deadmines")
Check(Clear(view))
Eq(view.floors[1].uiMapID, 291, "the first floor")
-- Rhahk'Zor and Sneed; Miner Johnson is a rare nobody killed.
Eq(D.IsRare(36, "Miner Johnson"), true, "Miner Johnson is no rare now: count him")
Eq(#view.plan.marks, 2, "the first floor's bosses")
Eq(Open(), vc.id, "choosing a floor put the run away")
-- Notes only about what is on the floor shown; another floor lays its own.
local onFloor = {}
for _, b in ipairs(D.Bosses(36)) do
    if not b.trash and b.floor and not D.IsRare(36, b.name) then onFloor[tonumber(b.floor)] = onFloor[tonumber(b.floor)] or b end
end
local up, down = onFloor[291], onFloor[292]
Check(up and down, "no boss on each of the Deadmines' floors")
local tries = Visit({ instanceID = 36, name = "The Deadmines", bossesKilled = { up.name, down.name, "Mr. Smite" },
    pulls = { { name = up.name, start = mock.now - 2900, stop = mock.now - 2880 },
        { name = up.name, start = mock.now - 2800, stop = mock.now - 2780, killed = true },
        { name = down.name, start = mock.now - 2000, stop = mock.now - 1980 },
        { name = down.name, start = mock.now - 1900, stop = mock.now - 1880, killed = true } } })
ns.UI.OpenVisit(tries.id, G)
local function About() local out = {} for _, e in ipairs(view.noteStrips) do out[#out + 1] = e.note.boss.name end return table.concat(out, ",") end
local shownFloor = view.floors[view.floorIndex].uiMapID
Eq(About(), shownFloor == 291 and up.name or down.name, "the strips on the floor shown")
Eq(view.notesAbout, 1, "a note about another floor counted here")
Eq(view.notesMore, 0, "a note about another floor counted as left over")
local other = view.floorIndex == 1 and 2 or 1
view.links[other].scripts.OnClick(view.links[other])
Eq(About(), shownFloor == 291 and down.name or up.name, "the other floor's strips not laid again")
StripsSound(view, "The Deadmines")
ns.UI.OpenVisit(tries.id, G)
-- A dungeon of one floor has nothing to choose.
ns.UI.OpenVisit(RFK.id, G)
Eq(view.links.used, 0, "a link for a dungeon of one floor")
Eq(view.label.used, 0, "a label for a dungeon of one floor")
ns.UI.OpenVisit(RFK.id, G)

-- The Hall of Thanes: drawn art, its artist credited on the About page.
local thanes = Visit({ instanceID = 3065, name = "The Hall of Thanes", bossesKilled = { "Faldrim Anvilmar" } })
ns.UI.OpenVisit(thanes.id, G)
Check(view.floors[view.floorIndex].custom, "The Hall of Thanes is not on its drawn map")
Whole(view, view.floors[view.floorIndex], "The Hall of Thanes")
Eq(view.credit, nil, "a credit on a drawn map")
-- No picture of it in the client: the card's medallion wears its last
-- boss's face, as the map does, and no drop cap over it.
ns.UI.OpenVisit(thanes.id, G)
local thanesCard = Card(thanes)
Check(thanesCard, "no Hall of Thanes card")
local medal = thanesCard.visit.medallion
Eq(ns.Style.InstanceArt(thanes), nil, "a picture of The Hall of Thanes")
Eq(medal.how, "face", "no face on a dungeon the client has no picture of")
Eq(medal.initial:IsShown(), false, "a drop cap over the face")
local durgen = D.Boss(3065, "Durgen Dirgehammer")
Eq(D.Bosses(3065)[#D.Bosses(3065)].name, "Durgen Dirgehammer", "the last boss")
Eq(Page.Face(thanes).display, durgen.display, "the face is not the last boss's")
-- Neither picture nor face: the drop cap, on its own layer over the ring.
local bare = ns.Style.Medallion(UIParent, 36)
bare:SetVisit({ instanceID = 999999, name = "The Test Vault" }, nil)
Eq(bare.how, "initial", "no drop cap without a picture or a face")
Check(bare.initial:IsShown(), "the drop cap is hidden")
Check(bare.initial.parent:GetFrameLevel() > bare:GetFrameLevel() + 1, "the drop cap lies under the face")
bare:SetVisit({ instanceID = 47, name = "Razorfen Kraul" }, nil)
Eq(bare.how, "art", "the group finder's picture")

-- A kill the pull events missed, proven by its loot (MAP-16): a kill,
-- with no number, and the tooltip says how the diary knows.
local proven = Visit({ instanceID = 3065, name = "The Hall of Thanes", bossesKilled = { "Faldrim Anvilmar", "Magmatus" },
    inferred = { Magmatus = "loot" } })
ns.UI.OpenVisit(proven.id, G)
local byName = Marks(view)
Check(byName.Magmatus.killed and byName.Magmatus.inferred, "the proven kill is not a kill")
Eq(byName.Magmatus.order, nil, "the proven kill is numbered")
Eq(byName["Faldrim Anvilmar"].order, 1, "the kill the diary saw")
Eq(byName.Magmatus.face, "display", "the proven kill has no face")
Eq(pools.number.used, 1, "numbers for the kills")
local _, titled = Tips(view)
Eq(titled.Magmatus[2][1], "Killed on this run, going by its loot", "the proven kill's tooltip")
ns.UI.OpenVisit(proven.id, G)
-- An older run: only its notes prove it (the grips off Magmatus' table).
local older = Visit({ instanceID = 3065, name = "The Hall of Thanes", bossesKilled = {},
    loot = { { guid = ns.ownGUID, itemID = 270231, time = mock.now - 2000,
        item = "|cnIQ3:|Hitem:270231::::::::22:1491::::::::|h[Flamefist Grips]|h|r" } } })
ns.UI.OpenVisit(older.id, G)
byName = Marks(view)
Check(byName.Magmatus.killed and byName.Magmatus.inferred, "an older run's proven kill is not a kill")
ns.UI.OpenVisit(older.id, G)

--------------------------------------------------------------------------
Section("the run's notes chosen (MAP-13 to MAP-15), and its deaths crossed (MAP-14)")

local runNotes = ns.DungeonRun.Notes(RFK)
-- Chosen in order: the wipe, the near wipe, then the loot (for Tester, a
-- diary entry, then an epic and a blue for the user), then the run back.
-- Aggem's two tries are told by the wipe.
local chosen = Page.Choose(RFK, runNotes, G)
local kinds = {}
for i, note in ipairs(chosen) do kinds[i] = note.kind end
Eq(table.concat(kinds, ","), "wipe,near,loot,loot,loot,ranBack", "the notes chosen, in order")
Eq(chosen[1].name, "Wiped once", "the wipe's words")
Eq(chosen[1].what, "killed on the second try", "under the wipe")
Eq(chosen[2].name, "Nearly wiped", "the near wipe's words")
Eq(chosen[2].what, "two went down", "under the near wipe")
Eq(chosen[2].boss.name, "Death Speaker Jargba", "the near wipe not Jargba's")
Eq(#chosen[3].items, 1, "Aggem's loot")
Eq(chosen[3].items[1].item, RFK.loot[1].item, "the first loot is not Thornspike")
Eq(chosen[3].name, ns.Style.Inkify(RFK.loot[1].item), "the item not in its quality's ink")
Eq(chosen[3].what, "dropped for Tester", "Tester's loot")
Eq(chosen[3].guid, nil, "on Tester's own page, Tester's loot opens their page")
Eq(chosen[3].tier, nil, "Tester's blue is the user's")
Eq(chosen[4].what, "dropped for you", "the user's loot")
Eq(chosen[4].tier, "epic", "the user's epic")
Eq(chosen[5].tier, "rare", "the user's blue")
Eq(chosen[6].name, "Ran back once", "the run back")
Eq(chosen[6].what, "as a ghost", "under the run back")
-- On anyone else's page, Tester's name opens their page.
Eq(Page.Choose(RFK, runNotes, ns.ownGUID)[3].guid, G, "Tester's loot does not open their page")

ns.UI.OpenVisit(RFK.id, G)
-- The notes on the map (step 2): in the order chosen, each where it is
-- free, near what it is about.
local strips = view.noteStrips
Eq(#strips, 7, "the strips on Razorfen Kraul's map")
Eq(view.notesAbout, 8, "the notes about Razorfen Kraul's floor")
Eq(view.notesMore, 1, "the note past the cap not counted")
Check(view.more:IsShown() and view.more:GetText() == "and 1 more", "no count of the one left over")
local laidKinds = {}
for i, e in ipairs(strips) do laidKinds[i] = e.note.kind end
Eq(table.concat(laidKinds, ","), "wipe,near,finally,snagged,loot,loot,bad", "the strips not in the order chosen")
StripsSound(view, "Razorfen Kraul")
local kindsOfLeader = {}
for _, e in ipairs(strips) do kindsOfLeader[e.leader] = true end
Check(kindsOfLeader.tick and kindsOfLeader.arrow, "Razorfen Kraul has no tick or no arrow")

-- A loot strip gives the item's own tooltip.
local lootSlot
for i = 1, view.notes.used do
    if view.notes[i].note.kind == "loot" then lootSlot = lootSlot or view.notes[i] end
end
local hover = lootSlot.links[1]
hover.scripts.OnEnter(hover)
Eq(GameTooltip.link, lootSlot.note.items[1].item, "no item tooltip on a loot strip")
Check(GameTooltip.lines[1][1]:find("^Dropped for "), "the item's tooltip does not say for whom")
hover.scripts.OnLeave(hover)

-- The cap: the rest counted in pencil by the label.
local most = Page.NOTES.most
Page.NOTES.most = 2
view:Open(RFK, G)
Eq(#view.noteStrips, 2, "more strips than the cap")
Eq(view.notesMore, 6, "the notes past the cap not counted")
Check(view.more:IsShown() and view.more:GetText() == "and 6 more", "no count: " .. tostring(view.more:GetText()))
Check(Near(view.more.recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn)), "the count not turned with the sheet")
Eq(view.noteStrips[1].note.kind, "wipe", "the cap kept the wrong notes")
Page.NOTES.most = most
-- Nowhere free at all: counted with the rest, never laid off the paper.
-- Along the paper's edge, sticking out past it: a place as good as any.
local gaps = Page.PLACE.gap
Page.PLACE.gap = { 2000 }
view:Open(RFK, G)
Eq(#view.noteStrips, 7, "no place along the paper's edge")
local out = 0
for _, e in ipairs(view.noteStrips) do
    local b = e.box
    if b[1] < 0 or b[2] < 0 or b[3] > view.w or b[4] > view.h then out = out + 1 end
    Check(e.edge, "a strip not along the paper's edge")
end
Check(out > 0, "no strip sticks out past the paper")
StripsSound(view, "Razorfen Kraul, along the edge")
Page.PLACE.gap = gaps
local clear = Page.PLACE.clear
Page.PLACE.clear = 2000
view:Open(RFK, G)
Eq(#view.noteStrips, 0, "a strip laid where nothing is free")
Eq(view.notesMore, 8, "the notes with nowhere to go not counted")
Page.PLACE.clear = clear
-- Laid flat: the strips lie straight on the turned sheet, still clear.
ns.SetSetting("flatSheets", true)
view:Open(RFK, G)
Eq(#view.noteStrips, 7, "the strips laid flat")
for _, e in ipairs(view.noteStrips) do Eq(e.strip.turn, 0, "a strip turned, laid flat") end
StripsSound(view, "Razorfen Kraul, flat")
ns.SetSetting("flatSheets", false)
view:Open(RFK, G)

-- Deaths: the wipe's three in ink round Aggem, the user's on the way to
-- Jargba in pencil, with who died to what and where about.
local targets = view.plan.targets
aggem = targets["Aggem Thorncurse"]
local atAggem, onTheWay = 0, nil
for _, c in ipairs(view.plan.crosses) do
    local d = math.sqrt((c.x - aggem.x) ^ 2 + (c.y - aggem.y) ^ 2)
    if not c.pencil and math.abs(d - (aggem.r + Page.DEATH.ring)) < 0.01 then atAggem = atAggem + 1 end
    if c.pencil then onTheWay = c end
end
Eq(atAggem, 3, "the wipe's deaths are not crossed round Aggem")
Check(onTheWay, "no cross on the way to Jargba")
Eq(onTheWay.tip[1][1], "You died, probably to a Razorfen Defender", "the death on the way's tooltip")
Eq(onTheWay.tip[2][1], "On the way to Death Speaker Jargba", "where about it was")
local jargba = targets["Death Speaker Jargba"]
Check(math.sqrt((onTheWay.x - jargba.x) ^ 2 + (onTheWay.y - jargba.y) ^ 2) > jargba.r
    and math.sqrt((onTheWay.x - aggem.x) ^ 2 + (onTheWay.y - aggem.y) ^ 2) > aggem.r, "the death on the way is at a boss")
local brom
for _, c in ipairs(view.plan.crosses) do
    if c.tip[1][1]:find("^Brom") then brom = brom or c end
end
Eq(brom and brom.tip[1][1], "Brom died, probably to Aggem Thorncurse", "a wipe death's tooltip")
-- A cross is printed on the paper, turned with it.
Check(Near(pools.cross[1].recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn)), "a cross not turned with the sheet")
ns.UI.OpenVisit(RFK.id, G)

-- At most five strips; a stranger's loot never a strip, only counted in
-- its boss's tooltip.
local STRANGER = "Player-4620-00EEEEEE"
local pulls = {}
for i, name in ipairs({ "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk",
    "Agathelos the Raging", "Charlga Razorflank" }) do
    local start = mock.now - 3000 + i * 200
    pulls[#pulls + 1] = { name = name, start = start, stop = start + 30 }
    if i <= 4 then pulls[#pulls + 1] = { name = name, start = start + 60, stop = start + 90, killed = true } end
    if i > 4 then pulls[#pulls + 1] = { name = name, start = start + 60, stop = start + 90 } end
end
local busy = Visit({ instanceID = 47, name = "Razorfen Kraul",
    bossesKilled = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk" }, pulls = pulls,
    spans = { { from = mock.now - 3000, to = mock.now - 2500, ghost = true }, { from = mock.now - 2400, to = mock.now - 1200 } },
    loot = { { guid = STRANGER, item = "|cnIQ2:|Hitem:6686::::::::22:1491::::::::|h[Tusken Helm]|h|r", itemID = 6686,
        time = mock.now - 3000 + 4 * 200 + 100 } } })
local busyNotes = Page.Choose(busy, ns.DungeonRun.Notes(busy), G)
Eq(#busyNotes, 7, "six tries and the run back")
Eq(busyNotes[1].name, "Killed on the second try", "a kill's tries without a wipe")
Eq(busyNotes[1].what, nil, "under a kill's tries")
Eq(busyNotes[5].name, "Tried twice", "a boss still standing")
Eq(busyNotes[5].what, "left standing", "under a boss still standing")
for _, note in ipairs(busyNotes) do Check(note.kind ~= "loot", "a stranger's loot is a strip") end
Eq(Page.NOTES.most, 7, "the strips' most")
local Words = Page.Words
Eq(Words.Wipes(3), "Wiped three times", "wipes in words")
Eq(Words.Wipes(11), "Wiped 11 times", "wipes past ten")
Eq(Words.More(2), "and 2 more", "the count of the rest")
Eq(Words.Facts(busy, { wipes = 2, tries = 2 })[2], nil, "a standing boss's tries told twice")
Eq(Words.Death(busy, { guid = ns.ownGUID, killer = { environment = "FALLING" } }), "You died (falling)",
    "a fall's words")
ns.UI.OpenVisit(busy.id, G)
_, titled = Tips(view)
local ramtuskTip = titled["Overlord Ramtusk"]
Eq(ramtuskTip[#ramtuskTip][1], "One item for someone else", "a stranger's loot is not counted")
ns.UI.OpenVisit(busy.id, G)

--------------------------------------------------------------------------
Section("the moments in the hand: loot loops, scribbles, the pen at rest, blood, level-ups, age")

ns.UI.OpenVisit(RFK.id, G)
local flavour = {}
for _, f in ipairs(view.plan.flavour) do
    flavour[f.kind] = flavour[f.kind] or {}
    table.insert(flavour[f.kind], f)
end
local T_ = view.plan.targets
local function At(f, name) return f and Near(f.x, T_[name].x) and Near(f.y, T_[name].y) end
-- The epic for you at Jargba: two loops and a star; the blue at Ramtusk:
-- one loop. Tester's blue at Aggem: none (loot for you only).
Eq(#(flavour.epic or {}), 1, "the epic's loops")
Check(At(flavour.epic[1], "Death Speaker Jargba"), "the epic's loops not round Jargba")
Eq(#(flavour.rare or {}), 1, "the blue's loop")
Check(At(flavour.rare[1], "Overlord Ramtusk"), "the blue's loop not round Ramtusk")
Eq(#(flavour.lootStar or {}), 1, "the epic's star")
Check(flavour.epic[1].r > T_["Death Speaker Jargba"].r + Page.LOOT.pad, "the loops inside the face")
Check(pools.loot.used > 0, "no ink for the loops")
Eq(view.plan.lootTier["Aggem Thorncurse"], nil, "a loop for Tester's loot")
Eq(Page.Tier({ { mine = true, quality = 3 } }), "rare", "a blue for you")
Eq(Page.Tier({ { mine = true, quality = 4 }, { mine = true, quality = 3 } }), "epic", "an epic for you")
Eq(Page.Tier({ { mine = false, quality = 5 } }), nil, "someone else's legendary")
Eq(Page.Tier({ { mine = true, quality = 2 } }), nil, "a green")
-- The loot strips: the epic's underlined twice and tacked, the blue's once
-- and taped, Tester's not at all.
local byTier = {}
for i = 1, view.notes.used do
    local slot = view.notes[i]
    if slot.note.kind == "loot" or slot.note.kind == "finally" then byTier[slot.note.tier or "none"] = slot end
end
Eq(byTier.epic.underlines, 2, "the epic's heading not underlined twice")
Check(byTier.epic.rules[2]:IsShown() and byTier.epic.strip.tacked, "the epic's strip not tacked")
Check(byTier.epic.strip.tack[2]:IsShown() and not byTier.epic.strip.tape:IsShown(), "the epic's tack, or its tape")
Eq(byTier.rare.underlines, 1, "the blue's heading not underlined once")
Check(not byTier.rare.rules[2]:IsShown() and not byTier.rare.strip.tacked, "the blue's strip tacked")
Eq(byTier.none.underlines, 0, "Tester's loot underlined")
-- The wipe at Aggem: an angry scribble beside the face, never on it; the
-- near wipe at Jargba: a nervous one.
Eq(#(flavour.wipe or {}), 1, "the wipe's scribble")
Eq(#(flavour.near or {}), 1, "the near wipe's scribble")
for _, f in ipairs({ flavour.wipe[1], flavour.near[1] }) do
    for _, mark in ipairs(view.plan.marks) do
        local t = T_[mark.name]
        Check(math.sqrt((f.x - t.x) ^ 2 + (f.y - t.y) ^ 2) >= t.r + f.r - 1e-6, "a scribble over a face: " .. mark.name)
    end
end
Check(pools.scribble.used > 0 and pools.scribbleUnder.used == pools.scribble.used, "the scribbles not chalk on dark")
-- Two wipes are darker and denser than one.
local function Wiped(n)
    local pulls, deathLog = {}, {}
    local m = { RFK.members[1].guid, RFK.members[3].guid, RFK.members[4].guid }
    for k = 1, n do
        local at = mock.now - 3000 + k * 300
        pulls[#pulls + 1] = { id = 2774, name = "Aggem Thorncurse", start = at, stop = at + 60 }
        for i = 1, 3 do deathLog[#deathLog + 1] = { guid = m[i], time = at + 10 * i, pull = #pulls } end
    end
    pulls[#pulls + 1] = { id = 2774, name = "Aggem Thorncurse", start = mock.now - 1500, stop = mock.now - 1400, killed = true }
    local v = ns.Instances.New({ instanceID = 47, name = "Razorfen Kraul", instanceType = "party", members = RFK.members,
        startedAt = mock.now - 3200, endedAt = mock.now - 1300, bossesKilled = { "Aggem Thorncurse" }, pulls = pulls,
        deathLog = deathLog })
    ns.UI.OpenVisit(v.id, G)
    local width = 0
    for i = 1, pools.scribble.used do
        local p = pools.scribble[i]
        width = math.max(width, p.recorded.height or 0)
    end
    local n2, alpha = pools.scribble.used, pools.scribble[1].recorded.calls.SetColorTexture[4]
    ns.UI.OpenVisit(v.id, G)
    return n2, alpha
end
local once, onceAlpha = Wiped(1)
local twice, twiceAlpha = Wiped(2)
Check(twice > once and twiceAlpha > onceAlpha, ("two wipes not denser or darker: %d/%d, %.2f/%.2f"):format(once, twice,
    onceAlpha, twiceAlpha))
ns.UI.OpenVisit(RFK.id, G)
-- The pen at rest: Aggem's eight minutes of 33 a circle, Ramtusk's ten a knot.
Eq(Page.Rest(0.14), nil, "a short fight marked")
Eq(Page.Rest(Page.REST.circle), "circle", "a fight at the circle's share")
Eq(Page.Rest(Page.REST.knot - 0.001), "circle", "just short of a knot")
Eq(Page.Rest(Page.REST.knot), "knot", "a fight at the knot's share")
Eq(flavour.circle and flavour.circle[1].name, "Aggem Thorncurse", "Aggem's circle")
Eq(flavour.knot and flavour.knot[1].name, "Overlord Ramtusk", "Ramtusk's knot")
-- Outside the blue's loop where there is one.
Check(flavour.knot[1].r > flavour.rare[1].r, "the knot inside the blue's loop")
-- The blood: under every death spot, bigger where more died.
local blood = flavour.blood or {}
Check(#blood >= 3, "blood at the death spots: " .. #blood)
table.sort(blood, function(a, b) return a.n > b.n end)
Check(blood[1].n >= 3 and blood[1].r > blood[#blood].r, "more dead, no more blood")
for _, c in ipairs(view.plan.crosses) do
    local under = false
    for _, b in ipairs(blood) do
        if (b.x - c.x) ^ 2 + (b.y - c.y) ^ 2 <= (Page.SPLAT.cluster + 1) ^ 2 then under = true end
    end
    Check(under, "a cross without its blood")
end
Check(pools.blood.used > 0 and pools.bloodCore.used > 0, "no blood drawn")
-- Seeded: the same every time.
local first = pools.blood[1].recorded.calls.SetColorTexture[4]
view:Open(RFK, G)
Eq(pools.blood[1].recorded.calls.SetColorTexture[4], first, "the blood lies otherwise each time")
-- Tester's level 22: a star on the way between Aggem and Jargba, "22".
Eq(#(flavour.level or {}), 1, "the level-up's star")
Eq(flavour.level[1].level, 22, "the level")
Eq(flavour.level[1].label:GetText(), "22", "the level scrawled")
local levelTip
for i = 1, pools.hit.used do
    local tip = pools.hit[i].tip
    if tip[1][1] == "Level 22" then levelTip = tip end
end
Check(levelTip and levelTip[2][1] == "Reached by Tester", "the level-up's tooltip")
-- Age: last night's map as it was; a few months on, yellowed and grimier;
-- never older past that.
Eq(Page.Age(0), 0, "a fresh map aged")
Eq(Page.Age(Page.AGE.full * 86400), 1, "a map a few months old not worn")
Eq(Page.Age(Page.AGE.full * 2 * 86400), 1, "a map aged past its most")
Check(Page.Age(7 * 86400) > 0 and Page.Age(7 * 86400) < Page.Age(30 * 86400), "wear not by age")
local fresh, g0 = Page.Worn(0)
local old, g1 = Page.Worn(1)
Check(fresh[1] == ns.Style.PAPER[1] and g0 == 1, "a fresh map's paper")
Check(old[3] < fresh[3] and g1 == Page.AGE.grime, "an old map's paper not yellowed or grimier")
-- Readable still: the old paper stays light.
Check(0.3 * old[1] + 0.59 * old[2] + 0.11 * old[3] > 0.6, "the old paper too dark")
local wasNow = mock.now
mock.now = RFK.startedAt + Page.AGE.full * 86400
view:Open(RFK, G)
Eq(view.age, 1, "an old run's map not worn")
Check(view.paper[3] < ns.Style.PAPER[3], "an old run's paper not yellowed")
mock.now = wasNow
view:Open(RFK, G)
Check(view.age < 0.2, "today's run worn: " .. view.age)
StripsSound(view, "Razorfen Kraul, with its moments")
ns.UI.OpenVisit(RFK.id, G)

--------------------------------------------------------------------------
Section("rolls on the map: snagged and finally as pairs, bad rolls (pass B)")
do

local rn = ns.DungeonRun.Notes(RFK)
rn.rolls = ns.DungeonRun.Rolls(RFK)
local rc = Page.Choose(RFK, rn, G)
local rk = {}
for i, note in ipairs(rc) do rk[i] = note.kind end
-- Wipes, near wipes, the pairs, the plain loot, the bad roll, the run back.
Eq(table.concat(rk, ","), "wipe,near,finally,snagged,loot,loot,bad,ranBack", "the rolls' notes not in order")
local fin, snag, bad = rc[3], rc[4], rc[7]
-- The charm finally came: its own strip, and on it the second.
Eq(fin.name, ns.Style.Inkify(RFK.loot[2].item), "the finally's first strip not the item")
Eq(fin.what, "dropped for you", "the finally's first strip not yours")
Eq(fin.top.name, "Finally! After two drops, it's yours", "the finally's words")
Eq(fin.struck, false, "the finally struck out")
Eq(fin.boss.name, "Death Speaker Jargba", "the finally not at Jargba")
Eq(fin.tier, "epic", "the finally's epic")
-- No plain strip for the charm: the pair took it (Jargba had nothing else).
for _, note in ipairs(rc) do
    if note.kind == "loot" then Check(note.boss.name ~= "Death Speaker Jargba", "the charm on a plain strip too") end
end
-- The band Zuri snagged: your strip for it, struck out, and hers on it.
Eq(snag.what, "dropped for you", "the snagged item's first strip not yours")
Eq(snag.top.name, "Zuri snagged it from you", "the snagged words")
Eq(snag.top.what, "80 against 85", "the rolls under it")
Eq(snag.top.guid, nil, "a stranger's name opens a page")
Eq(snag.struck, true, "the snagged strip not struck out")
Eq(snag.boss.name, "Overlord Ramtusk", "the snagged band not at Ramtusk")
-- Brom's 2 on boots off no boss's table: placed by its time, on the way.
Eq(bad.name, "Brom rolled a 2", "the bad roll's words")
Eq(bad.what, "on " .. ns.Style.Inkify(RFK.rolls[2].item), "the bad roll's item")
Eq(bad.boss, nil, "the boots given a boss")
Eq(bad.when, RFK.rolls[2].time, "the bad roll not placed by its time")
-- A diary person's name is a link: on the user's page, Tester's.
local fake = { bosses = {}, rolls = {
    snagged = { { drop = { item = RFK.rolls[1].item, itemID = 1, time = 1 }, winner = G, mine = 10, theirs = 20 } },
    bad = { { drop = { item = RFK.rolls[2].item, time = 2 }, guid = G, roll = 1 } },
    finally = {} } }
local fc = Page.Choose(RFK, fake, ns.ownGUID)
Eq(fc[1].top.guid, G, "Tester's name on the snagged strip opens nothing")
Eq(fc[2].guid, G, "Tester's bad roll opens nothing")
Eq(fc[2].name, "Tester rolled a 1", "Tester's bad roll's words")
local own = Page.Choose(RFK, { bosses = {}, rolls = { snagged = {}, finally = {},
    bad = { { drop = { item = RFK.rolls[2].item, time = 2 }, guid = ns.ownGUID, roll = 3 } } } }, G)
Eq(own[1].name, "You rolled a 3", "your bad roll's words")
Eq(own[1].guid, nil, "your bad roll opens a page")

-- On the map: the pair placed as one, the second strip on the first.
ns.UI.OpenVisit(RFK.id, G)
local pairs_ = {}
for _, e in ipairs(view.noteStrips) do
    if e.note.kind == "snagged" or e.note.kind == "finally" then pairs_[e.note.kind] = e end
    if e.note.kind == "bad" then bad = e end
end
-- Inside a turned rect: a point of the sheet in its own frame.
local function OnStrip(p, mid, size, turn)
    local dx, dy = p[1] - mid[1], p[2] - mid[2]
    local c, sn = math.cos(turn), math.sin(turn)
    local u, v = dx * c - dy * sn, dx * sn + dy * c
    return math.abs(u) <= size[1] / 2 + 1e-6 and math.abs(v) <= size[2] / 2 + 1e-6
end
for kind, e in pairs(pairs_) do
    local a, b = e.boxA, e.boxB
    Check(e.top and e.top:IsShown(), kind .. ": no second strip")
    Check(a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4], kind .. ": the second strip not on the first")
    -- Both read: the second leaves the first's heading clear.
    Check(b[2] > e.firstMiddle[2] - e.sizeA[2] / 2 + 10, kind .. ": the second strip over the first's heading")
    -- Its tape: half on itself, the half off it on the first or the map.
    local off = 0
    for _, p in ipairs(e.tapeB) do
        if not OnStrip(p, e.topMiddle, e.sizeB, e.turnB) then
            off = off + 1
            local onPaper = p[1] >= 0 and p[2] >= 0 and p[1] <= view.w and p[2] <= view.h
            Check(OnStrip(p, e.firstMiddle, e.sizeA, e.turnA) or onPaper, kind .. ": the second strip's tape on neither")
        end
    end
    Check(off > 0, kind .. ": the second strip's tape all on itself")
    -- Nothing the first says lies under the second: every corner of the
    -- second, in the first's own frame, under the first's writing.
    local _, _, _, padB = e.strip:Pad()
    local textBottom = e.sizeA[2] / 2 - padB
    local ca, sa = math.cos(e.turnB), math.sin(e.turnB)
    for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local px, py = ns.UI.Surface.Turned(e.topMiddle[1], e.topMiddle[2], k[1] * e.sizeB[1] / 2, k[2] * e.sizeB[2] / 2, ca, sa)
        local dx, dy = px - e.firstMiddle[1], py - e.firstMiddle[2]
        local cA, sA = math.cos(e.turnA), math.sin(e.turnA)
        local v = dx * sA + dy * cA
        Check(v >= textBottom - 1e-6, kind .. ": the second strip over the first's writing: " .. v .. " < " .. textBottom)
    end
    -- The first's writing all on the first, the second's on the second.
    for _, st in ipairs({ e.strip, e.top }) do
        local nb, W_, H_ = st.nameBox, st.box[3], st.box[4]
        Check(nb[1] >= -W_ / 2 and nb[3] <= W_ / 2 and nb[2] >= -H_ / 2 and nb[4] <= H_ / 2, kind .. ": writing off its strip")
    end
    -- Turned, the second's line has the room its turn takes (TURNED).
    local nb = e.top.nameBox
    local nameH = e.top.name.recorded.height
    Check(nameH >= (nb[4] - nb[2]) + (nb[3] - nb[1]) * math.abs(math.sin(e.top.turn)) - 1e-6,
        kind .. ": the second strip's line has no room for its turn")
    Check(math.abs(e.top.turn) > math.abs(e.strip.turn) or e.top.turn ~= e.strip.turn, kind .. ": the second strip not turned")
    -- Underlined: just "Finally!" or "Zuri snagged it", in the name's hand.
    local mark = e.note.top.mark
    local m = view.notesHost.nameMeasure
    m:SetText(mark)
    Eq(e.topSlot.underlineWidth, ns.UI.Surface.Width(m), kind .. ": the underline not under its words")
    Check(e.topSlot.underlineWidth < ns.UI.Surface.Width(e.top.name), kind .. ": the underline under the whole line")
    Check(e.topSlot.rules[1]:IsShown() and not e.topSlot.rules[2]:IsShown(), kind .. ": not underlined once")
    Eq(e.topSlot.rules[1].recorded.width, e.topSlot.underlineWidth, kind .. ": the underline's length")
    Check(math.abs(math.abs(e.turnB - e.turnA) - math.rad(Page.PAIR.turn)) < 1e-9, kind .. ": the second strip not turned its own way")
    Check(e.top:GetFrameLevel() > e.strip:GetFrameLevel() + 5, kind .. ": the second strip under the first's item hover")
    Eq(e.topSlot.strikes.used, 0, kind .. ": the second strip struck out")
    -- The pair's box holds both.
    Check(e.box[1] <= math.min(a[1], b[1]) + 1e-6 and e.box[3] >= math.max(a[3], b[3]) - Page.PAIR.pad - 6,
        kind .. ": the pair not laid as one")
end
Eq(pairs_.finally.note.top.mark, "Finally!", "the finally's underlined words")
Eq(pairs_.snagged.note.top.mark, "Zuri snagged it", "the snagged underlined words")
-- The epic's tack, pinned at the corner, clear of its heading.
local fs = pairs_.finally.strip
Check(fs.tacked and fs.tackBox, "the finally's epic not tacked")
local tb, nb = fs.tackBox, fs.nameBox
Check(tb[1] >= nb[3] or tb[3] <= nb[1] or tb[2] >= nb[4] or tb[4] <= nb[2], "the tack on the heading")
Check(tb[3] <= fs.box[3] / 2 + 1e-6 and tb[2] >= -fs.box[4] / 2 - 1e-6, "the tack off its strip")
local sa = pairs_.snagged
Check(sa, "no snagged pair on the map")
-- Struck out: a stroke across the heading and each line under it, over
-- the first strip.
Eq(sa.slot.strikes.used, Page.STRIKE.pieces * (1 + #sa.strip:WhatLines()), "the strike-through's strokes")
Eq(pairs_.finally.slot.strikes.used, 0, "the finally struck out")
Eq(sa.top.note.name, "Zuri snagged it from you", "the second strip's words")
-- The snagged first strip's item still has its tooltip.
local sh = sa.slot.links[1]
sh.scripts.OnEnter(sh)
Eq(GameTooltip.link, RFK.rolls[1].item, "the snagged item's tooltip")
sh.scripts.OnLeave(sh)
-- The finally keeps its boss's loop.
Eq(view.plan.lootTier["Death Speaker Jargba"], "epic", "the finally's loop")
-- The bad roll: where it dropped on the way, between Aggem and Jargba.
local anchor = Page.Anchor(view.plan, RFK.rolls[2].time)
Check(bad and Near(bad.target.x, anchor.x) and Near(bad.target.y, anchor.y), "the bad roll not where it dropped")
local leg = ns.DungeonRun.When(RFK, view.plan.notes, RFK.rolls[2].time)
Eq(leg.after.name, "Aggem Thorncurse", "the boots after Aggem")
Eq(leg.before.name, "Death Speaker Jargba", "... on the way to Jargba")
local lx, ly = Page.LegPoint(view.plan.path, leg)
Check(Near(anchor.x, lx) and Near(anchor.y, ly), "the anchor not on the route")
-- Without a route: by the boss before or after; with neither, the way in.
local bare = { visit = RFK, notes = view.plan.notes, path = nil, targets = view.plan.targets }
local byBoss = Page.Anchor(bare, RFK.rolls[2].time)
local ag = view.plan.targets["Aggem Thorncurse"]
Check(Near(byBoss.x, ag.x - (ag.r + Page.DEATH.ring) * 0.9), "without a route, not by the boss before")
local lone = Page.Anchor({ visit = RFK, notes = { bosses = {} }, targets = view.plan.targets }, RFK.rolls[2].time)
Eq(lone, view.plan.targets.door, "with nothing else, not by the way in")
StripsSound(view, "Razorfen Kraul, with its rolls")
ns.UI.OpenVisit(RFK.id, G)
end

--------------------------------------------------------------------------
Section("kills by id under the game's own names, merged loot, a wipe on the way")

-- The game says "Infurnus" for the boss the data calls Magmatus (id 3495).
-- Garrick is in the diary; Pell, Odo and the stranger are not.
local F = T.F
mock.SetUnit("target", F.GARRICK)
ns.Diary.Add(F.GARRICK.guid, { unit = "target" })
local PELL, ODO, STRANGER2 = "Player-4620-00F1F1F1", "Player-4620-00F2F2F2", "Player-4620-00F3F3F3"
local t0 = mock.now - 4000
local function At(m) return t0 + m * 60 end
local function Link(id, name, q) return ("|cnIQ%d:|Hitem:%d::::::::22:1491::::::::|h[%s]|h|r"):format(q, id, name) end
local hall = ns.Instances.New({
    instanceID = 3065, name = "The Hall of Thanes", instanceType = "party", startedAt = At(0), endedAt = At(50),
    members = { { guid = G, first = "Tester" }, { guid = ns.ownGUID, first = "Me" },
        { guid = F.GARRICK.guid, first = "Garrick" }, { guid = PELL, first = "Pell" }, { guid = ODO, first = "Odo" } },
    bossesKilled = { "Faldrim Anvilmar", "Infurnus", "Plunder", "Durgen Dirgehammer" },
    pulls = {
        { id = 3493, name = "Faldrim Anvilmar", start = At(5), stop = At(7), killed = true },
        { id = 3495, name = "Infurnus", start = At(12), stop = At(14), killed = true },
        { id = 3494, name = "Plunder", start = At(25), stop = At(27), killed = true },
        { id = 3496, name = "Durgen Dirgehammer", start = At(33), stop = At(35) },
        { id = 3496, name = "Durgen Dirgehammer", start = At(40), stop = At(42), killed = true },
    },
    deathLog = {
        -- Three of five to trash on the way to Plunder: a wipe on the way.
        { guid = PELL, time = At(18), killer = { name = "Dark Iron Looter" } },
        { guid = ODO, time = At(18) + 10, killer = { name = "Dark Iron Looter" } },
        { guid = ns.ownGUID, time = At(18) + 20, killer = { name = "Dark Iron Looter" } },
        -- And three in Durgen's first pull.
        { guid = PELL, time = At(34), pull = 4, killer = { name = "Durgen Dirgehammer" } },
        { guid = ODO, time = At(34) + 5, pull = 4, killer = { name = "Durgen Dirgehammer" } },
        { guid = G, time = At(34) + 9, pull = 4, killer = { name = "Durgen Dirgehammer" } },
    },
    loot = {
        { guid = STRANGER2, item = Link(270227, "Drape of the Test", 3), itemID = 270227, time = At(7) + 10 },
        { guid = F.GARRICK.guid, item = Link(270231, "Grips of the Test", 3), itemID = 270231, time = At(14) + 10 },
        { guid = ns.ownGUID, item = Link(270230, "Girdle of the Test", 3), itemID = 270230, time = At(14) + 20 },
        { guid = G, item = Link(271098, "Chest of the Test", 3), itemID = 271098, time = At(27) + 10 },
        { guid = ns.ownGUID, item = Link(270256, "Axe of the Test", 4), itemID = 270256, time = At(42) + 10 },
    },
    spans = { { from = At(0), to = At(19), ghost = true }, { from = At(21), to = At(35), ghost = true },
        { from = At(37), to = At(50) } },
})
local hallNotes = ns.DungeonRun.Notes(hall)
local hallChosen = Page.Choose(hall, hallNotes, G)
kinds = {}
for i, note in ipairs(hallChosen) do kinds[i] = note.kind end
Eq(table.concat(kinds, ","), "wayWipe,wipe,loot,loot,loot,ranBack", "the Hall's notes, in order")
Eq(hallChosen[1].name, "Wiped on the way", "the wipe on the way's words")
Eq(hallChosen[1].what, "to a Dark Iron Looter", "what the wipe on the way was to")
-- Each kind of killer once, in the order they killed; no plural guessed.
local function WayWipe(...)
    local deaths = {}
    for i, name in ipairs({ ... }) do deaths[i] = { killer = name ~= "" and { name = name } or nil } end
    return Page.Words.WipedTo(hall, { deaths = deaths })
end
Eq(WayWipe("Dark Iron Looter", "Anvilrage Guardsman", "Dark Iron Looter"),
    "to a Dark Iron Looter and an Anvilrage Guardsman", "a wipe to two kinds")
Eq(WayWipe("Dark Iron Looter", "Anvilrage Guardsman", "Ironforge Thug"),
    "to a Dark Iron Looter and others", "a wipe to three kinds")
Eq(WayWipe(""), nil, "a wipe no death names a killer for")
-- Magmatus' two items on one strip, each its own piece of the heading.
local merged = hallChosen[3]
Eq(merged.boss.name, "Magmatus", "the first loot is not Magmatus'")
Eq(#merged.items, 2, "Magmatus' loot is not on one strip")
Eq(merged.name, ns.Style.Inkify(hall.loot[2].item) .. " and " .. ns.Style.Inkify(hall.loot[3].item),
    "the merged heading")
Eq(merged.items[2].from, ns.Style.Inkify(hall.loot[2].item) .. " and ", "where the second item starts")
Eq(merged.what, "dropped for Garrick and you", "for whom")
Eq(merged.guid, F.GARRICK.guid, "Garrick's name does not open his page")
Eq(merged.items[1].guid, F.GARRICK.guid, "Garrick's item does not open his page")
Eq(merged.items[2].guid, nil, "the user's item opens a page")
Eq(hallChosen[4].what, "dropped for Tester", "Plunder's chest for the page's person")
Eq(hallChosen[4].guid, nil, "on Tester's own page, Tester's name opens it")
for _, note in ipairs(hallChosen) do
    if note.kind == "loot" then
        for _, it in ipairs(note.items) do Check(it.item ~= hall.loot[1].item, "a stranger's loot is a strip") end
    end
end

ns.UI.OpenVisit(hall.id, G)
-- Kills by id: "Infurnus" marks Magmatus killed, numbered in the order the
-- notes give, and the map calls it what the game did.
byName = Marks(view)
Check(byName.Magmatus.killed and not byName.Magmatus.inferred, "Infurnus did not kill Magmatus")
Eq(byName.Magmatus.order, 2, "Magmatus is not the second to fall")
Eq(byName["Durgen Dirgehammer"].order, 4, "Durgen is not the fourth")
_, titled = Tips(view)
Check(titled.Infurnus and not titled.Magmatus, "the tooltip does not use the game's name")
Eq(Page.Wing(hall), D.WingOf(3065, "Faldrim Anvilmar"), "the wing from the first kill by id")
Check(Clear(view))
-- The wipe on the way has its place on the map, and its strip points
-- there.
Check(view.plan.targets["wipe:1"], "the wipe on the way has no place on the map")
-- The real run's shape: every note on the map, under the cap.
Eq(view.notesAbout, 6, "the Hall's notes about this floor")
Eq(#view.noteStrips + view.notesMore, 6, "a note neither laid nor counted")
Eq(view.notesMore, 0, "the Hall's notes do not all fit the sheet")
StripsSound(view, "The Hall of Thanes")
local way, merged
for _, e in ipairs(view.noteStrips) do
    if e.note.kind == "wayWipe" then way = e end
    if e.note.kind == "loot" and e.note.boss.name == "Magmatus" then merged = e end
end
Check(way and way.target == view.plan.targets["wipe:1"], "the wipe on the way's strip not at its place")
-- Two items on one strip: wider than the rest, and each item its own
-- tooltip, where the turned strip has it.
Check(merged and merged.strip.box[3] > Page.NOTES.width, "the merged loot strip not as wide as its heading")
local mergedSlot
for i = 1, view.notes.used do
    if view.notes[i].note == merged.note then mergedSlot = view.notes[i] end
end
Eq(mergedSlot.links.used, 2, "a hover per item on the merged strip")
local h1 = mergedSlot.links[1]
Eq(h1.recorded.points[1].args[1], view.notesHost, "an item's hover not on the strips' frame")
h1.scripts.OnEnter(h1)
Eq(GameTooltip.link, hall.loot[2].item, "the first item's tooltip")
Eq(GameTooltip.lines[1][1], "Dropped for Garrick", "for whom the first item dropped")
h1.scripts.OnLeave(h1)
-- Garrick's name opens his page, and the run is put away for it.
merged.strip.link.scripts.OnClick(merged.strip.link)
Eq(J.selected, F.GARRICK.guid, "Garrick's name did not open his page")
Eq(Open(), nil, "the run stayed out over Garrick's page")
ns.UI.SelectPerson(G)

--------------------------------------------------------------------------
Section("a dungeon the diary has no map of (MAP-7)")

local vault = Visit({ instanceID = 999999, name = "The Test Vault", bossesKilled = { "Nobody" } })
Eq(ns.UI.OpenVisit(vault.id, G), true, "an unknown dungeon did not open")
Check(view:IsShown(), "no sheet for a dungeon without a map")
Check(view.none:IsShown(), "no word for a dungeon without a map")
Eq(view.none:GetText(), "The diary has no map of The Test Vault yet.", "the words without a map")
Check(Near(view.none.recorded.calls.SetRotation[1], math.rad(Page.SHEET.turn)), "the pencil line not turned with the sheet")
Eq(printer.pieces, 0, "art for a dungeon without a map")
Eq(printer.tiles.used, 0, "tiles left on a bare sheet")
Eq(pools.medal.used + pools.hit.used + view.links.used, 0, "marks left on a bare sheet")
ns.UI.OpenVisit(vault.id, G)
Eq(Open(), nil, "no way back from a dungeon without a map")
-- And a mapped one after it: the pencil line goes.
ns.UI.OpenVisit(RFK.id, G)
Check(not view.none:IsShown(), "the pencil line stayed on a map")
ns.UI.OpenVisit(RFK.id, G)

--------------------------------------------------------------------------
Section("every kind of art, cut to the floor and along the mesh")

local Map = ns.UI.DungeonMap
local sheet, SK = ns.UI.LooseSheet(UIParent, 600, 400)
SK.Fall("art", 0)
SK.Lay()
local art = Map.Printer(SK, sheet.sheet)
-- Forever's tiles in yards.
local yards = D.Floor(3065, 930651)
local list = Map.Pieces(yards)
Eq(#list, #yards.tiles, "Forever's tiles in yards")
for _, piece in ipairs(list) do
    Check(piece.x0 >= 0 and piece.y0 >= 0 and piece.x1 <= yards.w and piece.y1 <= yards.h, "a piece off the floor")
end
local w, h = Map.Fit(yards, 300, 300)
Check(math.abs(w / h - yards.w / yards.h) < 1e-9 and h <= 300 and w <= 300, "a floor fitted out of shape")
local place = art:Print(yards, 50, 20, 200, 200 * yards.h / yards.w)
Eq(art.pieces, #yards.tiles, "a yards tile not printed")
Check(art.cuts >= art.pieces, "fewer cuts than pieces")
Eq(place(930651, 0.5, 0.25), 150, "a point on the floor printed")
Eq(place(301, 0.5, 0.5), nil, "a point on another floor is placed")
-- Client tiles running past the floor are cut off by their coordinates.
local rfk = D.Floor(47, floor.uiMapID)
list = Map.Pieces(rfk)
local last = list[#list]
Check(last.x1 <= rfk.w and last.y1 <= rfk.h, "the last tile runs past the floor")
Check(last.u1 <= 1 and last.v1 <= 1, "the last tile's coordinates run off its file")
if rfk.w < #rfk.tiles[1] * rfk.tile then
    Check(last.u1 < 1, "the last column is not cut to the floor")
end
-- A combined map: crops of the floors, each feathered by its mask, turned
-- with the sheet.
local combined = { uiMapID = 900047, combined = true, instanceID = 47, w = 400, h = 300,
    data = { pieces = { { floor = floor.uiMapID, x0 = 0, y0 = 0, x1 = 500, y1 = 400, dx = 0, dy = 0, s = 0.5 } } } }
list = Map.Pieces(combined)
Check(#list > 0 and list[1].piece == 1, "a combined map's piece is not cut")
Check(list.masks[1] and list.masks[1].x1 == 250 and list.masks[1].y1 == 200, "a combined piece's mask")
SK.Fall("art", math.rad(4))
SK.Lay()
art:Print(combined, 0, 0, 400, 300)
Check(art.masked[1] and art.masked[1].used > 0, "a combined map's piece is not printed")
Eq(art.masked[1][1].recorded.calls.AddMaskTexture[1], art.masks[1], "a piece's tile is not feathered")
Check(art.masksTurn, "the mock's masks cannot turn")
Check(Near(art.masks[1].recorded.calls.SetRotation[1], math.rad(4)), "the mask not turned with the sheet")
art:Print(nil, 0, 0, 10, 10)
Eq(art.tiles.used + art.masked[1].used, 0, "tiles left after a print of nothing")
sheet:Hide()

-- The border cut thinner where something marked lies in it, just enough;
-- not at all where it lies right at the art's edge.
local plain = { uiMapID = 1, w = 1000, h = 1000, tiles = {}, tile = 256 }
Eq(Map.Kept(plain)[1], 0, "a map's edge cut off by default")
-- A trim, were one set, is cut thinner where something marked lies in it.
local trimmed = Map.TRIM.tiles
Map.TRIM.tiles = 0.035
local t0 = Map.Kept(plain)
Check(Near(t0[1], 1000 * Map.TRIM.tiles) and Near(t0[4], 1000 * (1 - Map.TRIM.tiles)), "the border's trim")
local t1 = Map.Kept(plain, { { x = 40, y = 500 } }, 1)
Check(Near(t1[1], 40 - Map.MARGIN.mark) and Near(t1[3], t0[3]) and Near(t1[2], t0[2]), "a boss in the border: " .. t1[1])
local t2 = Map.Kept(plain, { { x = 500, y = 995, kind = "door" } }, 1)
Eq(t2[4], 1000, "the way in at the art's edge still cut off")
local t3 = Map.Kept(plain, { { x = 500, y = 980, kind = "way" } }, 2)
Check(Near(t3[4], 980 + Map.MARGIN.way / 2), "the margin not in the sheet's px")
Map.TRIM.tiles = trimmed
-- The sheet's size: a fifth bigger each way than the size the user kept
-- on 16 Oct (the book lay under it then), the shape kept. The sizes it
-- had then, by shape: a wide map as wide as 1010, a 3:2 or square one
-- about 571 tall, a tall one taller.
local KEPT = { [2.5] = { 1010, 404 }, [2] = { 1010, 505 }, [1.7] = { 975, 573 }, [1.5] = { 857, 571 },
    [1.3] = { 742, 571 }, [1] = { 570, 570 }, [0.8] = { 495, 619 }, [0.6] = { 422, 704 } }
for aspect, was in pairs(KEPT) do
    local sw_, sh_ = Page.SheetSize(aspect)
    Check(Near(sw_ / sh_, aspect), "a sheet not its map's shape: " .. aspect)
    Check(math.abs(sw_ / was[1] - 1.2) < 0.03 and math.abs(sh_ / was[2] - 1.2) < 0.03,
        ("a sheet not a fifth bigger: %s, %.0fx%.0f"):format(aspect, sw_, sh_))
    Check(sw_ <= Page.SIZE.w + 1e-6, "a sheet wider than its room: " .. aspect)
end
local ww = Page.SheetSize(2.5)
Check(Near(ww, Page.SIZE.w), "a wide map's sheet not as wide as its room")
Check(Page.CornerClear == nil and Page.CORNER == nil, "the old corner's limit still there")

-- The folds: panels nearest the first map's shape.
local function GridOf(w, h) local g = Page.Grid(w, h) return g[1] .. "x" .. g[2] end
Eq(GridOf(1010, 580), "3x2", "a wide sheet's folds")
Eq(GridOf(1002, 668), "3x2", "a 3:2 sheet's folds")
Eq(GridOf(700, 700), "2x2", "a square sheet's folds")
Eq(GridOf(540, 720), "2x3", "a tall sheet's folds")
local _, crease = Page.Grid(540, 720)
Eq(#crease.columns, 5, "a tall sheet's lines across")
Eq(#crease.rows, 7, "a tall sheet's lines down")
Check(crease.folds.rows[3] and crease.folds.rows[5] and crease.folds.columns[3], "a tall sheet's folds")

-- On the run's sheet: where the client cannot turn a mask, a combined
-- map's sheet lies straight; any other map is turned all the same.
ns.DCF.Combined[47] = { w = 400, h = 300, pieces = combined.data.pieces }
D.combined = nil
local all = D.Floors(47)
Eq(all[#all].combined, true, "no combined floor for Razorfen Kraul")
ns.UI.OpenVisit(RFK.id, G)
view.chosen[RFK.id] = #all
view:Open(RFK, G)
Check(not view.straight, "a combined map's sheet lies straight where masks turn")
Check(printer.masked[1] and printer.masked[1].used > 0, "the combined map is not printed")
printer.masksTurn = false
view:Open(RFK, G)
Eq(view.straight, true, "a combined map's sheet turned, its masks cannot")
Eq(view.links.used, 2, "the combined map is not a floor to choose")
Eq(view.links[1].label.recorded.calls.SetRotation[1], 0, "a straight sheet's words turned")
view.chosen[RFK.id] = 1
view:Open(RFK, G)
Eq(view.straight, false, "a map without masks lies straight")
printer.masksTurn = true
ns.DCF.Combined[47] = nil
D.combined = nil
view.chosen[RFK.id] = nil
ns.UI.OpenVisit(RFK.id, G)

SlashCmdList.SOCIALDIARY("testdata remove")
ns.UI.CloseJournal()
