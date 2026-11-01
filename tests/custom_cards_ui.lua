-- Custom cards on the page (UI/Journey/CardSheet.lua, plate:Right and
-- plate:MapAtCursor in UI/Journey/Plate.lua, strip:SetRight): the right click on
-- a mark, a card and the empty map, the form, hide and bring back, reset, insert
-- and remove, on a plate and on the full page, and the left button as it was.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Recap, J = ns.Custom, ns.JourneyRecap, ns.Journey

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

-- Level 10 in two sittings far apart, on the same zone, then level 11.
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
local LATER = t0 + 20000
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 1800 })
Seg({ kind = "stop", from = LATER, to = LATER + 1800, mapID = MAP, x = 0.70, y = 0.30, r = 30, seconds = 1800 })
Seg({ kind = "stop", from = LATER + 2400, to = LATER + 4000, mapID = MAP, x = 0.20, y = 0.20, r = 30, seconds = 1600,
    levelFrom = 11, levelTo = 11 })
j.levels[11] = { at = LATER + 2000, mapID = MAP, x = 0.70, y = 0.30 }

local function Call(t, name, x, y)
    return { t = t, mapID = MAP, x = x or 0.42, y = y or 0.58, level = 10, pct = 6, seconds = 42, took = 94,
        npcID = 2955, name = name or "Plainstrider", foeLevel = 7, foes = 3, display = 1961 }
end
j.closeCalls = { Call(t0 + 900) }
J.Touch()

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YourDiary = ns.UI.YourDiary
local CardSheet = YourDiary.CardSheet
ns.UI.RefreshJourneyPage(true)

-- The level's entry, and its first sitting's page.
local function Level()
    for i, e in ipairs(page.recap.entries) do
        if e.level == 10 then return i, e end
    end
end
local function OpenFirst()
    local i, e = Level()
    YourDiary.OpenPiece(i, 1)
    return i, e
end
OpenFirst()
do
    local i, e = Level()
    Eq(#Recap.Pieces(j, e, page.ctx), 2, "the level is two sittings")
end

local function Plate() return page.plates[1] end

-- The cursor over a point of the map: through what the plate says of it.
local function Over(plate, x, y, scale)
    local S, s = plate.sheet, plate.slot
    S.GetCenter = function() return 500, 400 end
    local px, py = plate:OnPage(x, y)
    local X, Y = px - (s.x + s.w / 2), s.y + s.h / 2 - py
    scale = scale or 1
    mock.pointer = { 500 + X * scale, 400 + Y * scale }
end

local function MarkOf(plate, kind)
    for i = 1, plate.hover.used do
        local b = plate.hover[i]
        if b.spot and b.spot.kind == (kind or "close") then return b end
    end
end
local function RightOn(frame) frame.scripts.OnMouseUp(frame, "RightButton") end
local function RightMap(plate, x, y)
    Over(plate, x, y)
    mock.contextMenu = nil
    RightOn(plate.clip)
end
local function Press(button) button.scripts.OnClick(button) end
local function Row(key)
    for _, row in ipairs(CardSheet.View().rows) do
        if row.field.key == key then return row end
    end
end
local function Card()
    for i = 1, page.killerPool.used do
        local c = page.killerPool[i]
        if c:IsShown() and c.foe then return c end
    end
end

--------------------------------------------------------------------------
Section("cursor to map, the reverse of the plate's own")

do
    local plate = Plate()
    Check(plate.slot.pad > 0, "the slot has a margin")
    Check(math.abs(plate.turn or 0) > 0, "the card lies straight here, so its turn goes untested")
    local x0, y0, x1, y1 = plate.window[1], plate.window[2], plate.window[3], plate.window[4]
    local mx, my = x0 * 0.3 + x1 * 0.7, y0 * 0.6 + y1 * 0.4
    Over(plate, mx, my)
    local x, y = plate:MapAtCursor()
    Check(x and math.abs(x - mx) < 1e-6 and math.abs(y - my) < 1e-6, "a close-up's point did not come back")

    -- Turned: the same with the card at a turn, and leaned in under the mouse.
    local saved = plate.scale
    plate.scale = 1.1
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    local ox, oy = mx, my
    Over(plate, ox, oy, 1.1)
    x, y = plate:MapAtCursor()
    Check(x and math.abs(x - ox) < 1e-6 and math.abs(y - oy) < 1e-6, "leaned in, the point moved")
    plate.scale = saved

    -- On the card's margin, off the picture.
    local s = plate.slot
    plate.sheet.GetCenter = function() return 500, 400 end
    mock.pointer = { 500, 400 + s.h / 2 - 1 }
    Eq((plate:MapAtCursor()), nil, "the card's margin is on the map")
    Check(cx and cy, "the window has a middle")
end

do
    YourDiary.OpenFull(MAP)
    local plate = Plate()
    local look = plate.look
    Check(look ~= nil, "the full page looks")
    -- Fitted, zoomed and panned: drawn at each view, the point comes back.
    local function Round(what)
        local w = plate.window
        local mx, my = plate.look.cx + 0.01, plate.look.cy - 0.02
        Check(mx > w[1] and mx < w[3], what .. ": the point is on the picture")
        Over(plate, mx, my)
        local x, y = plate:MapAtCursor()
        Check(x and math.abs(x - mx) < 1e-6 and math.abs(y - my) < 1e-6, what .. ": the point did not come back")
    end
    Round("fitted")
    look.onSettle(look.f * 1.2, 0.45, 0.55)
    Round("zoomed and panned")
    -- A drag pans before it is drawn again: the map point under the cursor
    -- stays under it, and the reading follows the view shown, not the one drawn.
    plate = Plate()
    Over(plate, plate.look.cx, plate.look.cy)
    local ax, ay = plate:MapAtCursor()
    plate:Press("LeftButton")
    mock.pointer = { mock.pointer[1] + 30, mock.pointer[2] - 20 }
    plate.Drag()
    local bx, by = plate:MapAtCursor()
    Check(math.abs(ax - bx) < 1e-3 and math.abs(ay - by) < 1e-3, "a drag lost the point under the cursor")
    plate:Release("LeftButton")
    OpenFirst()
end

--------------------------------------------------------------------------
Section("the left button as it was, the right takes nothing from it")

do
    local plate = Plate()
    plate.sheet.scripts.OnMouseUp(plate.sheet, "RightButton")
    Eq(page.mode, "plates", "a right click on the card's margin opened the map")
    local clip = plate.clip
    clip.scripts.OnMouseDown(clip, "RightButton")
    Eq(page.mode, "plates", "a right press acted as a left")
    local mark = MarkOf(plate)
    Check(mark ~= nil, "the close call's mark has a square that knows it")
    mark.scripts.OnMouseDown(mark, "LeftButton")
    mark.scripts.OnMouseUp(mark, "LeftButton")
    Eq(page.mode, "full", "a left click on a mark does not open the map")
    plate = Plate()
    -- A left drag on the full page pans and does not go back.
    Over(plate, plate.look.cx, plate.look.cy)
    plate:Press("LeftButton")
    mock.pointer = { mock.pointer[1] + 40, mock.pointer[2] }
    plate.Drag()
    plate:Release("LeftButton")
    Eq(page.mode, "full", "a drag went back")
    -- The right button in mid-drag does nothing.
    plate:Press("LeftButton")
    mock.contextMenu = nil
    RightOn(plate.clip)
    Eq(mock.contextMenu, nil, "a right click in mid-drag opened a menu")
    Check(not (CardSheet.View() and CardSheet.View():IsShown()), "a right click in mid-drag opened the form")
    plate:Release("LeftButton")
    OpenFirst()
end

--------------------------------------------------------------------------
Section("right click on a mark: the form for its record, saved")

do
    local rec = j.closeCalls[1]
    RightOn(MarkOf(Plate()))
    local view = CardSheet.View()
    Check(view and view:IsShown(), "the form did not open")
    Eq(view.rec, rec, "a detected card without changes is its raw record")
    Eq(view.title:GetText(), "A close call", "the heading comes from the spec")
    Eq(Row("name"):Get(), "Plainstrider", "the name")
    Eq(Row("pct"):Get(), "6", "the health")
    Eq(Row("rank"):Get(), "", "no rank")
    Check(view.hide:IsShown(), "a detected card can be left out")
    Check(not view.reset:IsShown(), "nothing to undo yet")
    Check(not view.remove:IsShown(), "a detected card cannot be deleted")
    Press(view.cancel)
    Check(not view:IsShown(), "cancel did not close")
    Eq(rec.custom, nil, "cancel wrote nothing")

    RightOn(MarkOf(Plate()))
    Press(view.save)
    Eq(rec.custom, nil, "saved unchanged, nothing is custom: not even the name looked up again")

    -- Only what changed is written: the name sent unchanged would be looked up
    -- again, and lend a picture this record never had.
    do
        local bare, seen = Call(t0 + 800, "Plainstrider", 0.60, 0.70), rec
        bare.display = nil
        j.closeCalls = { bare, seen }
        J.Touch()
        ns.UI.RefreshJourneyPage(false)
        OpenFirst()
        RightOn(MarkOf(Plate()))
        Eq(view.rec, bare, "the bare one's mark first")
        Row("pct"):Set("4")
        Press(view.save)
        Eq(bare.custom.pct, 4, "the change")
        Eq(bare.custom.display, nil, "the unchanged name brought a picture")
        j.closeCalls = { rec }
        J.Touch()
        ns.UI.RefreshJourneyPage(false)
        OpenFirst()
    end

    RightOn(MarkOf(Plate()))
    Row("name"):Set("Old Tom")
    Row("pct"):Set("2")
    Row("foeLevel"):Set("-1")
    Row("rank"):Set("rare")
    Row("foes"):Set("")
    local openPiece, openIndex = page.piece, page.open
    Press(view.save)
    Eq(rec.custom.name, "Old Tom", "the name saved apart")
    Eq(rec.name, "Plainstrider", "the detected name untouched")
    Eq(rec.custom.pct, 2, "the health")
    Eq(rec.custom.foeLevel, -1, "the skull")
    Eq(rec.custom.rank, "rare", "the rank")
    Eq(rec.custom.foes, false, "the emptied field cleared")
    Eq(page.open, openIndex, "the page moved")
    Eq(page.piece, openPiece, "the sitting moved")
    Eq(page.mode, "plates", "still the plates")
    local card = Card()
    Check(card and card.foe.name == "Old Tom", "the card reads the edit at once")
end

--------------------------------------------------------------------------
Section("right click on its card: the same record, merged")

do
    local rec = j.closeCalls[1]
    local card = Card()
    Check(card.foe.call.customOf == rec, "the card shows a merged copy")
    card.link.scripts.OnMouseUp(card.link, "LeftButton")
    Check(not CardSheet.View():IsShown(), "the left button on a card opened the form")
    RightOn(card.link)
    local view = CardSheet.View()
    Check(view:IsShown(), "the card did not open the form")
    Eq(view.rec, card.foe.call, "its record")
    Eq(Row("name"):Get(), "Old Tom", "the form shows the edit")
    Check(view.reset:IsShown(), "changed: it can be undone")
    -- Reset gives back exactly the detected card.
    Press(view.reset)
    Eq(rec.custom, nil, "reset")
    card = Card()
    Eq(card and card.foe.name, "Plainstrider", "the detected card is back")
    Eq(card.foe.call, rec, "as its raw record")
    RightOn(card.link)
    Eq(view.rec, rec, "the detected card (the plate's choice) opens too")
    Press(view.cancel)
end

--------------------------------------------------------------------------
Section("hide, then bring it back from the menu")

do
    local rec = j.closeCalls[1]
    RightOn(MarkOf(Plate()))
    Press(CardSheet.View().hide)
    Check(rec.custom and rec.custom.hidden, "hidden")
    local plate = Plate()
    Eq(plate.entry.hidden[1] and plate.entry.hidden[1].rec, rec, "listed on the page")
    local stayed = page.piece
    Eq(stayed, 1, "the sitting stayed open")
    RightMap(plate, 0.40, 0.60)
    Check(mock.contextMenu ~= nil, "no menu")
    Check(mock.MenuClick("Left out of this page"), "the hidden cards' heading")
    Check(mock.MenuClick("Plainstrider, 6% health"), "the hidden card's line")
    Eq(rec.custom, nil, "brought back")
    Eq(page.piece, stayed, "the sitting stayed")
    Check(Card() ~= nil, "its card is back")
end

--------------------------------------------------------------------------
Section("a spot merging several asks which")

do
    j.closeCalls = { Call(t0 + 800, "Plainstrider"), Call(t0 + 900, "Young Thunder") }
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
    local mark = MarkOf(Plate())
    Eq(#mark.spot.list, 2, "the two merged on a spot")
    mock.contextMenu = nil
    RightOn(mark)
    Check(not CardSheet.View():IsShown(), "it opened one without asking")
    Check(mock.MenuClick("Which one?"), "asks")
    Check(mock.MenuClick("Young Thunder, 6% health"), "lists it")
    Eq(CardSheet.View().rec, j.closeCalls[2], "the one picked")
    Press(CardSheet.View().cancel)
    j.closeCalls = { Call(t0 + 900) }
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
end

--------------------------------------------------------------------------
Section("insert on the empty map, and remove")

do
    local plate = Plate()
    local w = plate.window
    local mx, my = w[1] * 0.2 + w[3] * 0.8, w[2] * 0.2 + w[4] * 0.8
    RightMap(plate, mx, my)
    Check(mock.MenuClick("Add a close call here"), "offered, the words from the spec")
    local view = CardSheet.View()
    Check(view:IsShown(), "the form")
    Eq(view.rec, nil, "a new card")
    Eq(Row("pct"):Get(), "5", "the spec's default")
    Eq(Row("name").box:HasFocus(), true, "ready to write on")
    Check(not view.hide:IsShown() and not view.reset:IsShown() and not view.remove:IsShown(),
        "a new card has only Save and Cancel")
    Row("name"):Set("Old Tom")
    local entry = Plate().entry
    Press(view.save)
    Eq(#j.custom, 1, "written")
    local rec = j.custom[1]
    Check(math.abs(rec.x - mx) < 1e-6 and math.abs(rec.y - my) < 1e-6, "at the spot clicked")
    Eq(rec.mapID, MAP, "on the plate's map")
    Check(rec.t >= entry.from and rec.t < entry.to, "within the open sitting")
    Eq(page.piece, 1, "the sitting stayed")
    local card
    for i = 1, page.killerPool.used do
        local c = page.killerPool[i]
        if c:IsShown() and c.foe and c.foe.name == "Old Tom" then card = c end
    end
    Check(card ~= nil, "its card appears")
    Check(card.foe.call.inserted, "as inserted")

    RightOn(card.link)
    Check(view.remove:IsShown(), "an inserted card can be deleted")
    Check(not view.hide:IsShown(), "and not left out")
    Press(view.remove)
    Eq(#j.custom, 1, "asked first")
    Check(view:IsShown(), "the slip waits for the answer")
    local asked = mock.popups[#mock.popups]
    Check(asked.args[1]:find("This cannot be undone.", 1, true), "the confirm says so")
    mock.AnswerPopup("accept")
    Eq(#j.custom, 0, "deleted")
    Check(not view:IsShown(), "closed")
    Eq(page.piece, 1, "the sitting stayed")
end

--------------------------------------------------------------------------
Section("only a zone's map; a page with nothing to edit; other kinds' marks")

do
    local plate = Plate()
    local zone = ns.ZoneOf
    ns.ZoneOf = function(id) return id + 1 end
    RightMap(plate, 0.42, 0.58)
    Eq(mock.contextMenu, nil, "a spot on a map that is not a zone's is offered")
    ns.ZoneOf = zone
    -- Off the picture, with nothing hidden: no menu.
    plate.sheet.GetCenter = function() return 500, 400 end
    mock.pointer = { 500, 400 + plate.slot.h / 2 - 1 }
    mock.contextMenu = nil
    RightOn(plate.clip)
    Eq(mock.contextMenu, nil, "the card's margin offers a card")
    -- A plate with no close calls: the map's menu, and no error.
    local saved = j.closeCalls
    j.closeCalls = {}
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
    plate = Plate()
    Eq(MarkOf(plate), nil, "no close call's mark")
    RightMap(plate, 0.40, 0.60)
    Check(mock.contextMenu ~= nil, "the empty map still offers")
    -- A square that is not a registered mark (a pool's), and a killer's card.
    for i = 1, plate.hover.used do
        mock.contextMenu = nil
        RightOn(plate.hover[i])
    end
    j.closeCalls = saved
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
    -- Strips of a pool shared with kinds without an editor are told again.
    Check(Card().onRight ~= nil, "the close call's card has its right click")
end

--------------------------------------------------------------------------
Section("the full page: the level's time, the view kept, the sitting holding it")

do
    local i = OpenFirst()
    Eq(page.piece, 1, "first sitting open")
    YourDiary.OpenFull(MAP)
    local plate = Plate()
    plate.look.onSettle(plate.look.f * 1.2, 0.55, 0.40)
    plate = Plate()
    local f, cx, cy = plate.look.f, plate.look.cx, plate.look.cy
    -- Nearest the second sitting's stop.
    RightMap(plate, 0.70, 0.30)
    Check(mock.MenuClick("Add a close call here"), "offered on the full page")
    Row("name"):Set("Old Tom")
    Press(CardSheet.View().save)
    local rec = j.custom[1]
    Check(rec.t >= LATER and rec.t < LATER + 2000, "the level's time let it fall in the second sitting: " .. rec.t)
    Eq(page.mode, "full", "still on the full page")
    Eq(page.fullMap, MAP, "the same map")
    plate = Plate()
    Check(math.abs(plate.look.f - f) < 1e-9 and plate.look.cx == cx and plate.look.cy == cy, "the view was lost")
    Eq(page.piece, 2, "the sitting holding it is the one open")
    Eq(page.open, i, "the level stayed")
    -- Its mark opens it from here too.
    local own
    for k = 1, plate.hover.used do
        local b = plate.hover[k]
        if b.spot and b.spot.kind == "close" and b.spot.list[1].call.customOf == rec then own = b end
    end
    Check(own ~= nil, "its mark is on the full page")
    RightOn(own)
    Eq(CardSheet.View().rec.customOf, rec, "its mark, on the full page")
    Press(CardSheet.View().cancel)
    -- The way back is to its sitting, and it is there.
    plate.clip.scripts.OnMouseDown(plate.clip, "LeftButton")
    plate.clip.scripts.OnMouseUp(plate.clip, "LeftButton")
    Eq(page.mode, "plates", "back")
    Eq(page.piece, 2, "back to its sitting")
    Check(Card() ~= nil and Card().foe.name == "Old Tom", "and its card is on it")
    Custom.Remove(rec)
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
end

--------------------------------------------------------------------------
Section("with \"Keep my own route\" off")

do
    ns.JourneyCapture.SetEnabled(false)
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
    local plate = Plate()
    RightMap(plate, 0.40, 0.60)
    Check(mock.MenuClick("Add a close call here"), "still offered")
    Row("name"):Set("Old Tom")
    Press(CardSheet.View().save)
    Eq(#j.custom, 1, "written")
    RightOn(MarkOf(Plate()))
    Row("pct"):Set("1")
    Press(CardSheet.View().save)
    local found
    for _, r in ipairs(j.custom) do found = found or r.pct == 1 end
    local detected = j.closeCalls[1].custom
    Check(found or (detected and detected.pct == 1), "edited")
    j.custom, j.closeCalls[1].custom = nil, nil
    ns.JourneyCapture.SetEnabled(true)
    J.Touch()
end

--------------------------------------------------------------------------
Section("turning away puts the form away")

do
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
    RightOn(MarkOf(Plate()))
    Check(CardSheet.View():IsShown(), "open")
    page.right:Hide()
    Check(not CardSheet.View():IsShown(), "still lying there")
    page.right:Show()
end

--------------------------------------------------------------------------
Section("the road's deletion says the cards go")

do
    local Memory = assert(io.open("UI/Settings/Sections/Memory.lua", "r"))
    local code = Memory:read("*a")
    Memory:close()
    Check(code:find("every card you changed or wrote", 1, true), "the words")
    Check(ns.Custom.Spec("close").label == "a close call", "the spec names itself")
end
