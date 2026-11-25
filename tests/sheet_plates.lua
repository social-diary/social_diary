-- A plate that is a sheet (the city-trips proposal's core hook, 24 Nov
-- 2026): a moment kind registered with `sheet` (Core/JourneyRecap.lua's
-- RegisterMoment) opens a plate of its own, weighed H, on LAYOUT's eight
-- pages with an H; the room rule (Recap.Room) cuts a page to the sheet and
-- one full plate or two prints, what is cut going spare; a stay of the same
-- visit is the sheet's to tell; its drawer (UI/Journey/Sheet.lua's Register)
-- is called with its slot and draws on a leaf (UI/Paper/Leaf.lua) with the
-- shared pen (UI/Ink/Scribble.lua) and hand (UI/Ink/Sketch.lua); flat paper
-- lays it plain; the ticklist has one row for it and its stay, the meter a
-- fixed half, the cap line its own words; the pad walks in among its stops.
-- The kind is the test's own, registered here through the registries (no
-- production file registers one). Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local YD = ns.UI.YourDiary
local J, Chosen, Recap = ns.Journey, ns.Chosen, ns.JourneyRecap
local Sheets, Scribble, Sketch, Leaf = ns.UI.JourneySheet, ns.UI.Scribble, ns.UI.Sketch, ns.UI.Leaf
local LAYOUT, FONT = YD.LAYOUT, ns.Style.FONT
local KIND = "sheettest"

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

--------------------------------------------------------------------------
-- The test's own kind: a visit to a city, told on a sheet.

J.RegisterList(KIND, {})
Recap.RegisterMoment(KIND, {
    order = 9990, list = KIND, field = "visit", rank = 5.6, sheet = true,
    moment = function(_, rec)
        return { kind = KIND, t = rec.t, from = rec.t, to = rec.to, visit = rec }, rec.mapID, rec.x, rec.y
    end,
})
local drawn, clicked = {}, nil
Sheets.Register(KIND, {
    label = function() return "Errands" end,
    tip = function() return "Errands in town" end,
    draw = function(leaf, plate, slot, c)
        drawn[#drawn + 1] = { leaf = leaf, plate = plate, slot = slot, c = c }
        local head = leaf:Write("Orgrimmar, this evening", FONT.noteWritten, 14, 16)
        leaf:Heading(head)
        leaf:Name("Tester", FONT.noteWritten, 40, 60, { key = "tester",
            tip = function() return { { "Tester" } } end, click = function() clicked = "Tester" end })
        leaf:Name("and two others", FONT.pencilHandSmall, 40, 84, { key = "others",
            tip = function() return { { "Koko" }, { "Bram" } } end })
        leaf:Write("came with 4 gold", FONT.pencilHandSmall, 260, 60)
        local n = leaf:Pen(Scribble.Underline("u:" .. c.Seed("u"), 40, 80, 66))
        n = n + leaf:Pen(Scribble.Cross("x", 220, 60, 4), Scribble.CROSS)
        n = n + leaf:Pen(Scribble.Ring("r", 300, 100, 22, 9), Scribble.RING)
        n = n + leaf:Pen(Scribble.Arrow("a", 260, 140, 300, 140), Scribble.ARROW)
        n = n + leaf:Pen(Scribble.Thread("t", { { 24, 40, 220 }, { 246, 24, 120 } }), Scribble.THREAD)
        drawn[#drawn].pen = n
        drawn[#drawn].sketched = Sketch.Draw(leaf:Kit(), "scroll", 26, 60, 16)
    end,
})

--------------------------------------------------------------------------
-- The route: a quiet stop, then the city (a long stay there) and the
-- visit the sheet tells, inside the stay.

local t0 = now - 20000
J.Begin(ns.ownGUID, t0, 12, 1411)
local j = J.Mine()
local function Stop(from, seconds, mapID, act)
    return { kind = "stop", from = from, to = from + seconds, mapID = mapID, x = 0.5, y = 0.5, r = 30,
        seconds = seconds, levelFrom = 12, levelTo = 12, act = act }
end
local CITY, VISIT_T = 1454, t0 + 6100
local function Route(extra)
    j.segments = { Stop(t0, 1000, 1411), Stop(t0 + 6000, 3000, CITY) }
    for _, seg in ipairs(extra or {}) do j.segments[#j.segments + 1] = seg end
    table.sort(j.segments, function(a, b) return a.from < b.from end)
    j.open, j.marks, j.chosen = nil, nil, nil
    j[KIND] = { { t = VISIT_T, to = t0 + 8900, mapID = CITY, x = 0.4, y = 0.45 } }
    Chosen.Forget()
    J.Touch()
end
Route()

local function Cover() return 0.2, 0.2 end
local function Piece()
    local ctx = Recap.Context(ns.ownGUID, now)
    return Recap.Gather(j, t0, now + 1, ctx), ctx
end
local function Plates()
    local e, ctx = Piece()
    return Recap.Plates(j, e, ctx, Cover), e, ctx
end
local function SheetOf(plates)
    for i, p in ipairs(plates) do
        if p.sheet then return p, i end
    end
end
local function Kinds(plate)
    local out = {}
    for _, m in ipairs(plate.moments) do out[#out + 1] = m.kind end
    return table.concat(out, " ")
end

--------------------------------------------------------------------------
Section("a sheet's moment opens a plate of its own, with the stay it tells")

local plates = Plates()
local sheet, at = SheetOf(plates)
Check(sheet ~= nil, "no plate is a sheet")
Eq(sheet and sheet.sheet, KIND, "the sheet's plate carries its kind")
-- (in time order, as every plate's: the stay began first)
Eq(sheet and Kinds(sheet), "stay " .. KIND, "the sheet holds its moment and the stay of the same visit, nothing else")
Check(Recap.Holds(sheet, 0.0001, 0.0001), "a sheet is held by any window")
for _, p in ipairs(plates) do
    if not p.sheet then
        for _, m in ipairs(p.moments) do
            Check(m.kind ~= KIND, "a sheet's moment joined a map plate")
            Check(not (m.kind == "stay" and m.mapID == CITY), "the visit's stay opened a map plate beside its sheet")
        end
    end
end
-- A stay outside the visit's span is no part of it.
local visit = j[KIND][1]
Check(Recap.Tells({ kind = KIND, mapID = CITY, from = visit.t, to = visit.to },
    { kind = "stay", mapID = CITY, t = t0 + 6000, seg = { from = t0 + 6000, to = t0 + 9000 } }), "the stay overlapping is told")
Check(not Recap.Tells({ kind = KIND, mapID = CITY, from = visit.t, to = visit.to },
    { kind = "stay", mapID = CITY, t = t0, seg = { from = t0, to = t0 + 1000 } }), "a stay before the visit is told")
Check(not Recap.Tells({ kind = KIND, mapID = CITY, from = visit.t, to = visit.to },
    { kind = "stay", mapID = 1411, t = t0 + 6000, seg = { from = t0 + 6000, to = t0 + 9000 } }), "a stay on another map is told")
Check(not Recap.Tells({ kind = KIND, mapID = CITY }, { kind = "stay", mapID = CITY, t = t0 + 6500 }),
    "a sheet naming no span tells a stay")

--------------------------------------------------------------------------
Section("the room rule")

local function P(w)
    if w == "H" then return { sheet = KIND, mapID = CITY } end
    return { light = w == "L", mapID = 1411, x0 = 0.5, x1 = 0.5, y0 = 0.5, y1 = 0.5 }
end
local function Room(pattern)
    local list = {}
    for w in pattern:gmatch(".") do list[#list + 1] = P(w) end
    return Recap.Room(list)
end
for _, ok in ipairs({ "H", "HF", "FH", "HL", "LH", "HLL", "LHL", "LLH", "FFF", "FL", "LLL" }) do
    Check(Room(ok), ok .. " has no room")
end
for _, no in ipairs({ "HFF", "HFL", "FHL", "LFH", "HLLL", "HH", "HHF", "FFFF" }) do
    Check(not Room(no), no .. " has room")
end

-- Two full plates beside the sheet: the lowest-ranked, the sheet (5.6),
-- goes spare, and the visit's stay is let go to be grouped as ever.
Route({ Stop(t0 + 2000, 1500, 1412, { deaths = 1 }) })
j.marks = { { kind = "fight", outcome = "won", guid = "Player-1111-0000BBBB", t = t0 + 300, mapID = 1411, x = 0.5, y = 0.5 } }
J.Touch()
plates = Plates()
Check(SheetOf(plates) == nil, "a sheet beside two full plates stayed on the page")
local spared
for _, p in ipairs(plates.spare) do if p.sheet then spared = p end end
Check(spared ~= nil, "the sheet cut for room is not spare")
Eq(spared and Kinds(spared), KIND, "the sheet cut lets its stay go")
local cityShown = false
for _, p in ipairs(plates) do
    for _, m in ipairs(p.moments) do cityShown = cityShown or (m.kind == "stay" and m.mapID == CITY) end
end
for _, p in ipairs(plates.spare) do
    for _, m in ipairs(p.moments) do cityShown = cityShown or (m.kind == "stay" and m.mapID == CITY) end
end
for _, m in ipairs(plates.loose) do cityShown = cityShown or (m.kind == "stay" and m.mapID == CITY) end
Check(cityShown, "the stay let go is nowhere")
Check(Recap.Room(plates), "the page as cut has no room")

-- The sheet kept: the lowest-ranked plate the player did not keep goes.
local e, ctx = Piece()
for _, m in ipairs(Recap.Moments(j, e, ctx)) do
    if m.kind == KIND then Chosen.Keep(j, m) end
end
plates = Plates()
sheet = SheetOf(plates)
Check(sheet ~= nil, "a kept sheet was cut")
Check(Recap.Room(plates), "with the sheet kept the page has no room")
Eq(#plates, 2, "the kept sheet and one full plate")
local fulls = 0
for _, p in ipairs(plates.spare) do if not p.sheet then fulls = fulls + 1 end end
Check(fulls >= 1, "the full plate cut for the kept sheet is not spare")

-- A second sheet is spare, never on the page.
Route()
j[KIND][2] = { t = t0 + 300, to = t0 + 900, mapID = 1411, x = 0.6, y = 0.6 }
J.Touch()
plates = Plates()
local onPage, spareSheets = 0, 0
for _, p in ipairs(plates) do if p.sheet then onPage = onPage + 1 end end
for _, p in ipairs(plates.spare) do if p.sheet then spareSheets = spareSheets + 1 end end
Eq(onPage, 1, "two sheets on one page")
Eq(spareSheets, 1, "the second sheet is not spare")
Route()

-- No sheet: the page as ever (the existing suites hold the rest).
j[KIND] = nil
J.Touch()
plates = Plates()
Check(SheetOf(plates) == nil and #plates <= Recap.PLATES.max, "a page with no sheet")
Route()

--------------------------------------------------------------------------
Section("the eight pages with a sheet")

local PAGE_W, PAGE_H = 466, 534
-- A slot's box as turned (degrees, clockwise) about its middle.
local function Box(s)
    local a = math.rad(s.t or 0)
    local c, sn = math.abs(math.cos(a)), math.abs(math.sin(a))
    local hw, hh = (s.w * c + s.h * sn) / 2, (s.w * sn + s.h * c) / 2
    local cx, cy = s.x + s.w / 2, s.y + s.h / 2
    return cx - hw, cy - hh, cx + hw, cy + hh
end
local KEYS = { "H", "HF", "FH", "HL", "LH", "HLL", "LHL", "LLH" }
for _, key in ipairs(KEYS) do
    local layout = LAYOUT[key]
    Check(layout ~= nil, key .. " has no page")
    if layout then
        Eq(#layout, #key, key .. "'s slots")
        local lifts, boxes = 0, {}
        for i = 1, #key do
            local w, s = key:sub(i, i), layout[i]
            if w == "H" then
                Check(s.sheet == true and s.w == 444 and s.h == 240, key .. ": the sheet is not 444 by 240")
                Check(s.cap == nil and (s.pad or 0) == 0, key .. ": a sheet with a caption or a margin")
            elseif w == "F" then
                Check(s.w == 260 and s.h == 236 and s.cap and s.cap.w >= 176, key .. ": the full plate's slot")
            else
                Check(s.light == true and s.w == 176 and s.h == 124, key .. ": the print's slot")
            end
            if s.lift then lifts = lifts + 1 end
            local x0, y0, x1, y1 = Box(s)
            -- (nothing touches the page's side, as turned; a lifted corner
            -- 10 px in, its shadow reaching 9.9: the plates skill's rules)
            local left = s.lift == "bl" and 10 or 4
            local right = s.lift == "br" and 10 or 4
            Check(x0 >= left - 0.2 and x1 <= PAGE_W - right + 0.2,
                ("%s: slot %d %.1f..%.1f too near the page's side"):format(key, i, x0, x1))
            Check(y1 + (s.lift and 9.9 or 2) <= PAGE_H, ("%s: slot %d runs off the foot (%.1f)"):format(key, i, y1))
            -- (the lowest of a sheet's pages clear of the not-kept line
            -- where it lies right of it: OFF, x 246, y 512)
            if x1 > YD.OFF.x then Check(y1 + (s.lift and 9.9 or 2) < YD.OFF.y, key .. ": over the not-kept line") end
            boxes[i] = { x0, y0, x1, y1 }
        end
        Check(lifts <= 1, key .. ": more than one corner lifted")
        for a = 1, #boxes do
            for b = a + 1, #boxes do
                local A, B = boxes[a], boxes[b]
                local apart = A[3] <= B[1] or B[3] <= A[1] or A[4] <= B[2] or B[4] <= A[2]
                Check(apart, ("%s: slots %d and %d meet"):format(key, a, b))
            end
        end
        -- A sheet's slot holds any plate; LayoutFor gives this key its page.
        local fake = {}
        for i = 1, #key do
            local w = key:sub(i, i)
            fake[i] = w == "H" and { sheet = KIND, mapID = CITY } or { light = w == "L", mapID = 1411, x0 = 0.5, x1 = 0.5,
                y0 = 0.5, y1 = 0.5 }
        end
        local got, gotKey = YD.LayoutFor(fake)
        Eq(gotKey, key, key .. " keyed otherwise")
        Check(got == layout, key .. ": LayoutFor gave another page")
    end
end
-- Never a map's slot for a sheet: a pattern past the eight has no page.
Check(YD.LayoutFor({ { sheet = KIND, mapID = CITY }, { mapID = 1411, x0 = 0.5, x1 = 0.5, y0 = 0.5, y1 = 0.5 },
    { mapID = 1412, x0 = 0.5, x1 = 0.5, y0 = 0.5, y1 = 0.5 } }) == nil, "HFF fell through to a map's page")

--------------------------------------------------------------------------
-- The page.

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local function Redraw()
    drawn = {}
    ns.UI.RedrawJourneyPage()
end
local function SheetIndex()
    for i = 1, page.layout or 0 do
        if YD.SheetAt(i) then return i end
    end
end

--------------------------------------------------------------------------
Section("the page: the sheet drawn in its slot by its drawer")

Redraw()
local index = SheetIndex()
Check(index ~= nil, "no sheet on the page")
Check(type(page.pattern) == "string" and page.pattern:find("H", 1, true) ~= nil, "the page's key has no H: " .. tostring(page.pattern))
local layout = LAYOUT[page.pattern]
local d = drawn[#drawn]
Check(d ~= nil, "the drawer was not called")
if d and index then
    Check(d.slot == layout[index], "the drawer was not handed its slot")
    Eq(d.plate.sheet, KIND, "the drawer was not handed its plate")
    Eq(d.c.moment and d.c.moment.kind, KIND, "c.moment is not the sheet's own")
    Eq(#d.c.told, 1, "c.told is not the stay it tells")
    Eq(d.c.told[1] and d.c.told[1].kind, "stay", "c.told's kind")
    Eq(d.c.index, index, "c.index")
    Check(type(d.c.Heading()) == "string", "c.Heading gives no line")
    Check(type(d.c.named) == "table" and type(d.c.ToPerson) == "function", "c.named, c.ToPerson")
    local leaf = d.leaf
    Check(leaf:IsShown(), "the leaf not shown")
    Check(leaf == YD.SheetAt(index), "the leaf is not the page's sheet")
    Check(not page.plates[index]:IsShown(), "a map plate drawn in the sheet's place")
    Check(d.pen > 0, "the pen drew nothing")
    Check(d.sketched == true, "the scroll was not drawn (the free card's, through the shared hand)")
    Eq(#leaf:Stops(), 2, "the stops the drawer gave")
    Check(leaf:HasMarks(), "the leaf says it has no stops")
    Check(leaf.torn, "the leaf's top edge is not torn")
    Check(leaf.slot.lift == nil or leaf.lifted, "the lifted corner not drawn")
    -- The margin strips' paper, lit evenly across its whole width: no fold
    -- down its middle whose halves take the light apart (the user, 25 Nov
    -- 2026: "the shading is different from the other paper strips").
    local P = ns.UI.PAPER_LOOK.paper
    for k = 1, 3 do Eq(leaf.paper[k], P[k], "the leaf's stock is not the strips' (" .. k .. ")") end
    Eq(Leaf.LOOK.fold, false, "the leaf is folded")
    for x = 4, leaf.w - 4, 20 do
        for _, y in ipairs({ 30, leaf.h / 2, leaf.h - 30 }) do
            Eq(leaf.K.Light(x, y), 1, ("the leaf lit unevenly at %d, %d"):format(x, y))
        end
    end
    local e = YD.ShownPiece()
    Check(e.drawnSlots and e.drawnSlots[index] and e.drawnSlots[index].sheet == KIND, "drawnSlots does not mark the sheet")
end
-- No caption, no margin, no leader of the sheet's: every leader goes to a
-- map plate.
for _, link in ipairs(page.links or {}) do
    Check(link.plate ~= YD.SheetAt(index), "a leader to the sheet")
end

--------------------------------------------------------------------------
Section("flat paper: no turn, no shadow, no tear, no lifted corner")

ns.SetSetting("flatSheets", true)
Redraw()
local leaf = YD.SheetAt(SheetIndex())
Check(leaf and leaf.flat, "the leaf not laid flat")
Eq(leaf and leaf.turn, 0, "a flat leaf turned")
Check(leaf and not leaf.torn, "a flat leaf torn")
Check(leaf and not leaf.lifted, "a flat leaf lifted")
Check(drawn[#drawn] and drawn[#drawn].pen > 0, "the pen draws nothing on flat paper")
ns.SetSetting("flatSheets", false)
Redraw()

--------------------------------------------------------------------------
Section("the ticklist: one row for the sheet and its stay, the meter's half, the cap line")

YD.Choose()
local ch = page.chooser
local function SheetRow()
    for _, row in ipairs(ch.list.rows) do
        if row:IsShown() and row.item and row.item.card and row.item.card.sheet == KIND then return row end
    end
end
local row = SheetRow()
Check(row ~= nil, "no row for the sheet")
if row then
    local card = row.item.card
    Eq(row.item.label, "Errands", "the row's words (the drawer's label)")
    Eq(card.zone.mapID, CITY, "the row is not under its zone")
    Eq(#card.keys, 2, "the row stands for the sheet and its stay")
    Eq(card.moment.kind, KIND, "the row's moment is not the sheet's")
    Check(card.keys[1]:find("^" .. KIND .. ":") ~= nil, "the sheet's key not first")
    Check(card.on, "the row of a sheet on the page is not on")
    Eq(card.look, "diary", "the row's look")
end
-- No other row for the visit's stay.
for _, r in ipairs(ch.list.rows) do
    if r:IsShown() and r.item and r.item.card and r.item.card.kind == "stay" then
        Check(r.item.card.zone.mapID ~= CITY, "the visit's stay has a row of its own")
    end
end
Eq(ch.cap:GetText(), "Errands take half a page.", "the cap line with a sheet")
local sIndex = SheetIndex()
local sf = ch.frames[sIndex]
Eq(sf.w, 28, "the sheet's frame is not the fixed half")
Check(sf.rules[1]:IsShown() and sf.rules[2]:IsShown(), "the sheet's frame has no rules of writing")
Check(not sf.fill:IsShown(), "the sheet's frame is filled")
local total = 0
for _, f in ipairs(ch.frames) do if f:IsShown() then total = total + f.w end end
local shownFrames = 0
for _, f in ipairs(ch.frames) do if f:IsShown() then shownFrames = shownFrames + 1 end end
Eq(total + (shownFrames - 1) * YD.CHOOSE.frameGap, YD.CHOOSE.meter, "the frames fill the meter")
-- The widths: a sheet alone has an empty half; beside it, the maps share it.
local W = YD.MeterWidths
local function Same(a, b) return table.concat(a, ",") == table.concat(b, ",") end
Check(Same(W({ { w = 444, h = 240, sheet = KIND } }), { 28, 28 }), "a sheet alone: " .. table.concat(W({ { w = 444, h = 240, sheet = KIND } }), ","))
Check(Same(W({ { w = 444, h = 240, sheet = KIND }, { w = 260, h = 236 } }), { 28, 28 }), "a sheet and a full plate")
Check(Same(W({ { w = 176, h = 124 }, { w = 444, h = 240, sheet = KIND }, { w = 176, h = 124 } }), { 12, 28, 12 }),
    "a sheet between two prints: " .. table.concat(W({ { w = 176, h = 124 }, { w = 444, h = 240, sheet = KIND }, { w = 176, h = 124 } }), ","))
Check(Same(W({ { w = 260, h = 236 }, { w = 176, h = 124 } }), W({ { w = 260, h = 236 }, { w = 176, h = 124 } })), "the maps' share as ever")

-- Hover, both ways: the row marks the sheet; the sheet lights its row and frame.
if row then
    row:GetScript("OnEnter")(row)
    Check(YD.SheetAt(sIndex).ringAt ~= nil, "the row under the mouse does not mark its sheet")
    row:GetScript("OnLeave")(row)
    Check(YD.SheetAt(sIndex).ringAt == nil, "the sheet's mark stays after the row")
end
local sheetFrame = YD.SheetAt(sIndex).sheet
sheetFrame:GetScript("OnEnter")(sheetFrame)
Check(page.chooseLit and row and page.chooseLit[row.item.card.keys[1]], "the sheet under the mouse does not light its row")
Check(ch.frames[sIndex].hot, "the sheet under the mouse does not light its frame")
sheetFrame:GetScript("OnLeave")(sheetFrame)
Check(not ch.frames[sIndex].hot, "the frame stays lit")

-- Left out through its row: both keys out, the sheet off the page, its row
-- crossed; kept again: both kept, the sheet back.
if row then
    local keys = row.item.card.keys
    row:Click("LeftButton")
    Eq(j.chosen and j.chosen[keys[1]], "out", "the sheet's moment not left out")
    Eq(j.chosen and j.chosen[keys[2]], "out", "the stay not left out with it")
    Check(SheetIndex() == nil, "the sheet left out is still on the page")
    Eq(ch.cap:GetText(), "Three maps fit a page.", "the cap line with no sheet")
    row = SheetRow()
    Eq(row and row.item.card.look, "out", "the row left out is not crossed")
    row:Click("LeftButton")
    Eq(j.chosen and j.chosen[keys[1]], "keep", "the sheet's moment not kept")
    Eq(j.chosen and j.chosen[keys[2]], "keep", "the stay not kept with it")
    Check(SheetIndex() ~= nil, "the sheet kept is not on the page")
    row = SheetRow()
    Eq(row and row.item.card.look, "keep", "the row kept has not the player's tick")
end
YD.Unchoose()

--------------------------------------------------------------------------
Section("the sheet's menu")

local function Lines(generator)
    local out = {}
    local root = {}
    function root:CreateButton(text) out[#out + 1] = text end
    function root:CreateTitle() end
    generator(nil, root)
    return out
end
leaf = YD.SheetAt(SheetIndex())
local gen = YD.CardSheet.SheetGenerator(leaf)
Check(gen ~= nil, "a sheet has no menu")
local lines = gen and Lines(gen) or {}
Eq(lines[1], "Leave it out", "the menu's first line")
Eq(lines[2], "Choose what's on this page...", "the menu's second line")
Eq(#lines, 2, "the menu's lines")

--------------------------------------------------------------------------
Section("the pad: the sheet an item of the page, A among its stops, Y its menu, B back")

local Pad = ns.UI.Pad
local book = ns.UI.JournalFrame()
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Redraw()
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
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

Eq(Scope().key, "yourdiary", "the top scope")
Press("PAD1")
Eq(At().group, "page", "A on the rubric did not cross to the right page")
local sheetItem
for _, item in ipairs(Items("page")) do if item.sheet then sheetItem = item end end
Check(sheetItem ~= nil, "the sheet is no item of the page")
Scope().focus:Set(sheetItem)
leaf = YD.SheetAt(SheetIndex())
Check(Pad.Look.parts[book] and Pad.Look.parts[book].outline and Pad.Look.parts[book].outline.line:IsShown(),
    "the sheet has no outline")
Check(Red(leaf.heading), "the sheet's heading is not red")
local legend = Legend()
Eq(legend.PAD1, "Go to the names", "A's prompt on the sheet")
Check(legend.PAD3 == nil, "X offered on a sheet")
Eq(legend.PAD4, "Open the menu", "Y's prompt on the sheet")
Eq(legend.PAD2, "Back to the contents", "B's prompt on the sheet")
Check(Press("PAD3"), "X did something on the sheet")
Eq(At().group, "page", "X moved the pad off the sheet")
Press("PAD1")
Eq(At().group, "stops", "A on the sheet did not go in among its stops")
Eq(#Items("stops"), 2, "the stops found")
Check(At().words ~= nil and Red(At().words), "the stop's words are not red")
-- To the name with a click, and A is its click.
local named
for _, item in ipairs(Items("stops")) do if item.hasClick then named = item end end
Scope().focus:Set(named)
Eq(Legend().PAD1, "Go to their page", "A's prompt on a name")
Eq(Legend().PAD2, "Back to the sheet", "B's prompt among the stops")
Press("PAD1")
Eq(clicked, "Tester", "A on a name did not do its click")
-- A counted line has only its tooltip.
for _, item in ipairs(Items("stops")) do
    if not item.hasClick then
        Scope().focus:Set(item)
        Check(Legend().PAD1 == nil, "A offered on a stop with no click")
        clicked = nil
        Press("PAD1")
        Check(clicked == nil, "A on a counted line clicked something")
    end
end
Press("PAD2")
Eq(At().group, "page", "B among the stops did not come back to the page")
Check(At().sheet ~= nil, "B among the stops did not land on the sheet")
Press("PAD4")
Check(Pad.Menu.IsOpen(), "Y on the sheet did not open its menu on the pad's slip")
Pad.Menu.Close()
Pad.Refresh()
Scope().focus:Set(sheetItem)
Press("PAD2")
Check(At().group == "left" or At().group == "title", "B on the sheet did not go back to the left page")
-- In combat the pad is the game's.
mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on in combat")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
Check(not Red(leaf.heading), "the sheet's heading stays red with the pad put down")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on with the Gamepad UI off")

--------------------------------------------------------------------------
Section("an errand offered to the sheet (RegisterMoment's `errand` and `stands`)")

-- A kind of the test's own that offers its records as errands ("bought",
-- a word the sheet's drawer would read), placed where its record says,
-- ranked to open a plate of its own (as an upgrade leading its level
-- does).
local ERRAND = "errandtest"
J.RegisterList(ERRAND, {})
Recap.RegisterMoment(ERRAND, {
    order = 9991, list = ERRAND, field = "thing", rank = 2,
    moment = function(_, rec) return { kind = ERRAND, t = rec.t, thing = rec }, rec.mapID, rec.x, rec.y end,
    errand = function(rec) return { kind = "bought", name = rec.name } end,
})
local function Errands(list)
    Route()
    j[ERRAND] = list
    J.Touch()
end
local function Where(plates, rec)
    for i, p in ipairs(plates) do
        for _, m in ipairs(p.moments) do
            if m.thing == rec then return p, i, m end
        end
    end
end

-- Inside the visit's span, on its map: the sheet's to tell.
local inside = { t = VISIT_T + 600, mapID = CITY, x = 0.41, y = 0.46, name = "a Dustwalker Vest" }
Errands({ inside })
plates = Plates()
sheet = SheetOf(plates)
local p, _, em = Where(plates, inside)
Check(p ~= nil and p == sheet, "the errand inside the visit is not in the sheet's plate")
local sm
for _, m in ipairs(sheet.moments) do if m.kind == KIND then sm = m end end
Check(em and em.errandOf == sm, "the errand's moment is not marked as the sheet's")
Eq(sm and sm.errands and #sm.errands, 1, "the sheet's moment carries its errand")
Eq(sm and sm.errands[1].errand.kind, "bought", "the errand's kind, as its kind offered it")
Eq(sm and sm.errands[1].errand.t, inside.t, "the errand's time, the core's")
Check(sm and sm.errands[1].moment == em, "the errand's moment beside it")
Check(Recap.Told(sm, em), "Told: the errand")
Check(not Recap.Tells(sm, em), "Tells (the stays' alone) takes the errand")
for _, q in ipairs(plates) do
    if not q.sheet then
        for _, m in ipairs(q.moments) do Check(m.kind ~= ERRAND, "the told errand opened a map plate too") end
    end
end

-- Before the visit, or on another map: its own, as ever.
local before = { t = VISIT_T - 3000, mapID = CITY, x = 0.41, y = 0.46, name = "a Frayed Vest" }
local away = { t = VISIT_T + 600, mapID = 1411, x = 0.5, y = 0.5, name = "a Canvas Vest" }
-- (one at a time, the sheet kept: a full plate and a print beside a sheet
-- are more than the room rule gives it)
for _, rec in ipairs({ before, away }) do
    Errands({ rec })
    local e1, ctx1 = Piece()
    for _, m in ipairs(Recap.Moments(j, e1, ctx1)) do
        if m.kind == KIND then Chosen.Keep(j, m) end
    end
    plates = Plates()
    sheet = SheetOf(plates)
    Check(sheet ~= nil, rec.name .. ": setup, the sheet on the page")
    local q, _, m = Where(plates, rec)
    Check(q ~= nil and not q.sheet, rec.name .. ": not on a map plate of its own")
    Check(m and m.errandOf == nil, rec.name .. ": marked as the sheet's")
    for _, x in ipairs(sheet and sheet.moments or {}) do Check(not x.errands, rec.name .. ": given to the sheet") end
end

-- The sheet left out: the errand is back on a map plate; the errand left
-- out: off the sheet too, and the sheet has none.
Errands({ inside })
local e0, ctx0 = Piece()
for _, m in ipairs(Recap.Moments(j, e0, ctx0)) do
    if m.kind == KIND then Chosen.Leave(j, m) end
end
plates = Plates()
Check(SheetOf(plates) == nil, "setup: the sheet left out")
p = Where(plates, inside)
Check(p ~= nil and not p.sheet, "the sheet left out, its errand is on no map plate")
j.chosen = nil
e0, ctx0 = Piece()
for _, m in ipairs(Recap.Moments(j, e0, ctx0)) do
    if m.kind == ERRAND then Chosen.Leave(j, m) end
end
plates = Plates()
sheet = SheetOf(plates)
Check(sheet ~= nil, "setup: the sheet on the page")
Check(Where(plates, inside) == nil, "the errand left out is still on the page")
for _, m in ipairs(sheet.moments) do Check(not m.errands, "the errand left out is still on the sheet") end
-- The ticklist: the errand keeps its own row, not the sheet's.
j.chosen = nil
e0, ctx0 = Piece()
local own, sheetRows = 0, 0
for _, zone in ipairs(Recap.Choices(j, e0, ctx0, Cover).zones) do
    for _, row in ipairs(zone.rows) do
        if row.sheet then
            sheetRows = sheetRows + 1
            for _, m in ipairs(row.moments) do Check(m.kind ~= ERRAND, "the errand in the sheet's ticklist row") end
        elseif row.kind == ERRAND then
            own = own + 1
            Check(row.on, "the errand told on the sheet is not ticked as on the page")
        end
    end
end
Eq(sheetRows, 1, "setup: the sheet's row")
Eq(own, 1, "the errand has no row of its own")

-- `stands`: the sheet is told only where its kind says so, given the
-- errands offered to it, asked as the entry is gathered.
local spec = Recap.MOMENTS[KIND]
local asked
spec.stands = function(rec, errands)
    asked = errands
    return #errands > 0
end
Errands({ inside })
e0 = Piece()
Eq(#e0[KIND], 1, "a sheet standing on its errand left the entry")
Eq(asked and #asked, 1, "stands was not given the errand")
Eq(e0.errands[inside] and e0.errands[inside].sheet, j[KIND][1], "the entry does not keep whose errand it is")
Errands({ before })
e0 = Piece()
Eq(#e0[KIND], 0, "a sheet its stands refused is still in the entry")
Eq(e0.errands[before], nil, "an errand kept for a sheet that does not stand")
plates = Plates()
Check(SheetOf(plates) == nil, "a sheet its stands refused is on the page")
spec.stands = nil
Errands({})
