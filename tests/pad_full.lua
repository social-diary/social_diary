-- The whole zone map with the pad (UI/Journey/Pad.lua's group `full`,
-- plate:ZoomAt / Pan / PanTo / InView in UI/Journey/Plate.lua, the sticks in
-- UI/Pad/Catcher.lua; .claude/controller-plan.md, step 4d): opened by X on a
-- plate or by A on a ledger's zone row, the pad goes onto its marks, walked
-- by where they lie on the map; A closer and X further, within the map's
-- bounds; the right stick pans (and only on the whole map are sticks taken);
-- walking to a mark out of the view brings it in; Y still opens the card
-- slip; B goes back to the very plate or mark; the mouse takes over cleanly.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Look = Pad.Look
local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary
local CardSheet = YourDiary.CardSheet

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

-- The pad in hand.
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)

-- The page whose first plate's zone has the most marks on its whole map.
local best, bestScore
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    local plate = page.mode == "plates" and page.plates[1]
    if plate and plate:IsShown() then
        YourDiary.OpenFull(plate.mapID)
        local score = #page.plates[1]:Marks()
        if not bestScore or score > bestScore then best, bestScore = at, score end
    end
end
local function Open() T.OpenDiaryPage(page, best.i, best.k) end
Open()
Check(bestScore and bestScore >= 3, "setup: a whole map with three marks or more")

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
local function Full() return page.plates[1] end
-- The map eased and settled, as the client's frames would run it: the
-- pivot's OnUpdate to its end (a redraw, where the view moved).
local function Settle()
    for _ = 1, 200 do
        local plate = Full()
        local fn = plate.pivot:GetScript("OnUpdate")
        if not fn then return end
        fn(plate.pivot, 0.05)
    end
end
local function Sheet() return CardSheet.View() and CardSheet.View():IsShown() end
local parts = Look.parts[book]

--------------------------------------------------------------------------
Section("X on a plate opens the whole map, and the pad goes onto its marks")

Eq(Scope().key, "yourdiary", "setup: the top scope")
Press("PAD1")
Eq(At().group, "page", "setup: on the plates")
Check(not catcher:IsGamePadStickEnabled(), "sticks taken on the plates")
local fromKey = At().key
local mapID = page.plates[At().plate].mapID
Press("PAD3")
Eq(page.mode, "full", "X did not open the whole map")
Eq(page.fullMap, mapID, "the whole map not the plate's zone")
Eq(At().group, "full", "the pad not on the whole map")
Check(At().ring, "a mark not ringed")
parts = Look.parts[book]
Check(parts.pen:IsShown(), "the pen's ring not drawn")
Eq(parts.pen:GetParent(), Full().clip, "the ring not clipped with the map")
Check(GameTooltip.shown, "the mark's tooltip not shown")
Check(Red(page.foot.name), "the zone's name not red over its marks")
Check(catcher:IsGamePadStickEnabled(), "sticks not taken on the whole map")
Check(Full():InView(At().mx, At().my, 0), "opened on a mark out of the view")
local L = Legend()
Eq(L.PAD1, "Closer", "A's prompt on the whole map")
Check(L.PAD3 == nil, "Further offered at the fitted view")
Eq(L.PADRSTICK, "Move the map", "the stick's prompt")
Eq(L.PAD2, "Back to the plates", "B's prompt")
Eq(page.foot.hint:GetText(), YourDiary.FOOT.pad:format(Pad.Glyphs.Text("PAD2", 12)), "the foot's hint for the pad")

--------------------------------------------------------------------------
Section("every mark is found once, measured on the map, walked by where it lies")

local keys, n = {}, 0
for _, item in ipairs(Items("full")) do
    Check(not keys[item.key], "a key twice: " .. item.key)
    keys[item.key] = true
    n = n + 1
    local x, y = item.center()
    Check(type(x) == "number" and type(y) == "number", "no centre: " .. item.key)
    Check(item.what ~= "pool", "a pool walked")
end
Eq(n, #Full():Marks(), "the marks found")
local moved = 0
for _, from in ipairs(Items("full")) do
    for _, dir in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
        Scope().focus:Set(from)
        local fx, fy = from.center()
        Press(dir)
        local to = At()
        Eq(to.group, "full", "a move left the whole map: " .. dir)
        if to.key ~= from.key then
            moved = moved + 1
            local x, y = to.center()
            local ok = (dir == "PADDUP" and y > fy) or (dir == "PADDDOWN" and y < fy)
                or (dir == "PADDLEFT" and x < fx) or (dir == "PADDRIGHT" and x > fx)
            Check(ok, "moved the wrong way: " .. from.key .. " " .. dir .. " " .. to.key)
        end
        Settle()
    end
end
Check(moved > 0, "the pad never moved on the whole map")
Eq(page.mode, "full", "a walk left the whole map")

--------------------------------------------------------------------------
Section("A closer, X further, a notch at a time, within the bounds")

-- Back to the fitted view.
for _ = 1, 30 do Press("PAD3") end
Settle()
local look = Full().look
Check(math.abs(look.goal.f - look.fit) < 1e-6, "setup: at the fitted view")
Eq(Press("PAD3"), false, "X at the fitted view went on to the game")
Check(math.abs(Full().look.goal.f - Full().look.fit) < 1e-6, "X went further than the fit")
local on = At()
local f0 = Full().look.goal.f
Press("PAD1")
Check(math.abs(Full().look.goal.f - math.min(Plate.FULLZOOM.native, f0 * Plate.FULLZOOM.step)) < 1e-6,
    "A not a notch closer")
Eq(At().group, "full", "a zoom left the marks")
Eq(At().what, on.what, "the pad lost its mark over the zoom")
Check(Full():InView(At().mx, At().my, 0), "zoomed away from the mark")
Eq(Legend().PAD3, "Further", "X's prompt once closer")
for _ = 1, 40 do Press("PAD1") end
Check(math.abs(Full().look.goal.f - Plate.FULLZOOM.native) < 1e-6, "A went closer than native")
Check(Legend().PAD1 == nil, "Closer offered at native")
Eq(Press("PAD1"), false, "A at native went on to the game")
Press("PAD3")
Check(Full().look.goal.f < Plate.FULLZOOM.native, "X not further")
Settle()

--------------------------------------------------------------------------
Section("the right stick pans; the left stick and a nudge go on to the game")

local cx0, cy0 = Full().look.cx, Full().look.cy
Eq(mock.PadStick(catcher, "Left", 1, 0), true, "the left stick was taken")
Eq(mock.PadStick(catcher, "Right", 0.1, 0.05), true, "a nudge inside the deadzone was taken")
Eq(mock.PadStick(catcher, "Right", 1, 0), false, "the right stick not taken")
Eq(Full().look.cx, cx0, "the map moved on the stick's first word (before a frame)")
local ticker = catcher.ticker
Check(ticker:GetScript("OnUpdate") ~= nil, "a held stick not ticking")
ticker:GetScript("OnUpdate")(ticker, 0.1)
Check(Full().look.cx > cx0, "right on the stick did not show more of the east")
local cx1 = Full().look.cx
mock.PadStick(catcher, "Right", 0, 1)
ticker:GetScript("OnUpdate")(ticker, 0.1)
Check(Full().look.cy <= cy0, "up on the stick moved the map down")
Eq(Full().look.cx, cx1, "up on the stick moved it sideways")
Eq(mock.PadStick(catcher, "Right", 0, 0), false, "the stick's centring went on after we took it")
Check(ticker:GetScript("OnUpdate") == nil, "a let-go stick still ticking")
-- Settled: drawn again, and the pad on a mark in view.
local redraws = Full().look.redraws or 0
Settle()
Check((Full().look.redraws or 0) > redraws, "not drawn again after the pan")
Eq(At().group, "full", "the pad lost the map after the pan")
Check(Full():InView(At().mx, At().my, 0), "after the pan the pad on a mark out of view")

--------------------------------------------------------------------------
Section("walking to a mark out of the view pans the map to it")

for _ = 1, 40 do Press("PAD1") end
Settle()
local panned = false
for _ = 1, 30 do
    for _, dir in ipairs({ "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PADDUP" }) do
        local out = {}
        for _, item in ipairs(Items("full")) do
            if not Full():InView(item.mx, item.my, 14) then out[item.key] = true end
        end
        local g0 = Full().look.goal
        Press(dir)
        local to = At()
        if out[to.key] then
            panned = true
            -- (brought to the middle, held on the map: nearer the middle
            -- than it was, and in view)
            local g = Full().look.goal
            local function Off(gg)
                local look = Full().look
                return math.abs(to.mx - gg.cx) * look.LW + math.abs(to.my - gg.cy) * look.LH
            end
            Check(Off(g) < Off(g0) - 1, "the view not going to the mark walked to")
            Check(Full():InView(to.mx, to.my, 0), "the mark walked to not in the view")
            local key = to.key
            Settle()
            Eq(At().key, key, "the pad lost the mark once the map was drawn there")
            Check(Full():InView(At().mx, At().my, 0), "the mark out of view once drawn")
            break
        end
        Settle()
    end
    if panned then break end
end
Check(panned, "setup: never walked to a mark out of the view")

--------------------------------------------------------------------------
Section("Y on a mark: the card slip; B back on the same mark")

local did = Legend().PAD4
Check(did == "Add a card here" or did == "Change the card", "no Y on a mark of the whole map")
local yKey = At().key
Press("PAD4")
Check(Sheet(), "Y did not open the card slip")
Check(Scope().key ~= "yourdiary", "the slip's scope not on top")
-- (B a step out at a time, as far as the slip goes: tests/pad_cards.lua)
for _ = 1, 3 do if Sheet() then Press("PAD2") end end
Check(not Sheet(), "B did not put the slip away")
Eq(Scope().key, "yourdiary", "the page's scope not back")
Eq(page.mode, "full", "the slip left the whole map")
Eq(At().key, yKey, "not back on the mark Y was pressed on")

--------------------------------------------------------------------------
Section("B goes back to the plate X was pressed on, and from a mark to the mark")

Press("PAD2")
Eq(page.mode, "plates", "B did not go back to the plates")
Eq(At().key, fromKey, "not back on the plate")
Check(not catcher:IsGamePadStickEnabled(), "sticks still taken on the plates")
Press("PAD1")
Eq(At().group, "marks", "setup: among a plate's marks")
local markKey = At().key
Press("PAD3")
Eq(At().group, "full", "X on a mark: the pad not on the whole map")
Press("PAD2")
Eq(At().group, "marks", "B not back among the marks")
Eq(At().key, markKey, "B not back on the mark")

--------------------------------------------------------------------------
Section("A on a zone row opens its whole map and the pad goes there")

Press("PAD2")
Press("PAD2")
Eq(At().group, "left", "setup: on the left page")
local zoneRow
for _, item in ipairs(Items("left")) do
    local d = item.data
    if d.zone and d.mapID and not d.zone.dungeon then zoneRow = item break end
end
if not zoneRow then
    -- (another level's ledger may have one)
    for i = 1, #page.recap.entries do
        YourDiary.OpenLevel(i)
        Pad.Refresh()
        for _, item in ipairs(Items("left")) do
            local d = item.data
            if d.zone and d.mapID and not d.zone.dungeon then zoneRow = item break end
        end
        if zoneRow then break end
    end
end
Check(zoneRow ~= nil, "setup: a zone row")
if zoneRow then
    Scope().focus:Set(zoneRow)
    Press("PAD1")
    Eq(page.mode, "full", "A on a zone row did not open the whole map")
    Eq(page.fullMap, zoneRow.data.mapID, "not the row's zone")
    Eq(At().group, "full", "the pad stayed on the left page")
    Eq(Legend().PAD2, "Back to the contents", "B's prompt from a zone row")
    Press("PAD2")
    Eq(At().group, "left", "B not back on the left page")
    Eq(At().key, zoneRow.key, "B not back on the zone row")
    Scope().focus:Set(zoneRow)
    Press("PAD1")
end

--------------------------------------------------------------------------
Section("the mouse takes over cleanly")

Eq(page.mode, "full", "setup: the whole map")
Eq(At().group, "full", "setup: on its marks")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the ring left with the mouse")
Check(not GameTooltip.shown, "the mark's tooltip left with the mouse")
Check(not Red(page.foot.name), "the zone's name left red")
Check(not catcher:IsGamePadStickEnabled(), "sticks left taken with the mouse")
Eq(page.foot.hint:GetText(), YourDiary.FOOT.words, "the mouse's hint not back")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")
Eq(At().group, "full", "the pad not back on the map")
Check(catcher:IsGamePadStickEnabled(), "sticks not taken again")
