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
-- The cards the picker shows, row by row; a click on the kind's.
local function Cells()
    local list = {}
    for _, row in ipairs(CardSheet.View().list.rows) do
        if row.item then
            for _, cell in ipairs(row.cells) do
                if cell.kind then list[#list + 1] = cell end
            end
        end
    end
    return list
end
local function PickKind(kind)
    for _, cell in ipairs(Cells()) do
        if cell.kind == kind then
            cell.strip.link.scripts.OnClick(cell.strip.link)
            return true
        end
    end
    error("no card for " .. kind)
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
    Eq(Row("rank"):Get(), "", "no type")
    Eq(Row("rank").label:GetText(), "TYPE", "the field is called Type")
    Check(Row("rank").toggles.rare:IsShown() and Row("rank").toggles.elite:IsShown(), "both toggles in sight")
    Eq(Row("rank").link, nil, "no link and menu")
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
Section("Type: two toggles, at most one on")

do
    local rec = j.closeCalls[1]
    Custom.Reset(rec)
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
    RightOn(MarkOf(Plate()))
    local view = CardSheet.View()
    local row = Row("rank")
    local rare, elite = row.toggles.rare, row.toggles.elite
    Check(not rare:GetChecked() and not elite:GetChecked(), "neither on: a common creature")
    rare.scripts.OnClick(rare)
    Check(rare:GetChecked() and not elite:GetChecked(), "rare on")
    Eq(row:Get(), "rare", "reads rare")
    elite.scripts.OnClick(elite)
    Check(elite:GetChecked() and not rare:GetChecked(), "turning one on turns the other off")
    Eq(row:Get(), "elite", "reads elite")
    elite.scripts.OnClick(elite)
    Check(not rare:GetChecked() and not elite:GetChecked(), "the lit one clicked turns off")
    Eq(row:Get(), "", "reads nothing")
    rare.scripts.OnClick(rare)
    Press(view.save)
    Eq(rec.custom.rank, "rare", "saved as rank")
    Custom.Reset(rec)
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()

    -- A rank the form cannot choose, as detected: neither lit, untouched by a
    -- save, replaced by a toggle, and given back by Undo.
    for _, detected in ipairs({ "worldboss", "rareelite" }) do
        rec.rank = detected
        J.Touch()
        ns.UI.RefreshJourneyPage(false)
        OpenFirst()
        RightOn(MarkOf(Plate()))
        row = Row("rank")
        rare, elite = row.toggles.rare, row.toggles.elite
        Check(not rare:GetChecked() and not elite:GetChecked(), detected .. ": neither lit")
        Row("pct"):Set("3")
        Press(view.save)
        Eq(rec.rank, detected, detected .. ": as detected")
        Eq(rec.custom.rank, nil, detected .. ": no change saved over it")
        Eq(Card().foe.call.rank, detected, detected .. ": the card keeps it")

        RightOn(MarkOf(Plate()))
        rare.scripts.OnClick(rare)
        Press(view.save)
        Eq(rec.custom.rank, "rare", detected .. ": a toggle replaces it")
        Eq(rec.rank, detected, detected .. ": underneath, kept")
        Eq(Card().foe.call.rank, "rare", detected .. ": the card reads the toggle")

        RightOn(MarkOf(Plate()))
        Press(view.reset)
        Eq(rec.custom, nil, detected .. ": undone")
        Eq(Card().foe.call.rank, detected, detected .. ": restored")
    end
    rec.rank = nil
    -- As the next section expects it: edited.
    Custom.Edit("close", rec, { name = "Old Tom", pct = 2 })
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()
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
    Check(mock.MenuClick("Add custom event..."), "offered")
    PickKind("close")
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
Section("the picker: its cards, the way back, the ring, and on the book")

do
    local view
    -- Laid wholly on the pages, however wide: from what it was told.
    local function OnBook(what)
        local S = view.sheet
        local BOOK = ns.UI.Journal.BOOK
        -- (The mock keeps a frame's height only on its record.)
        local W, H = S:GetWidth(), S.recorded.height
        Check(H and H > 0, what .. " has a height")
        local left, top = BOOK.BOOK_W / 2 + view.dx - W / 2, BOOK.BOOK_H / 2 - view.dy - H / 2
        Check(left >= 0 and left + W <= BOOK.BOOK_W, what .. " runs off the book across: " .. left .. " + " .. W)
        Check(top >= 0 and top + H <= BOOK.BOOK_H, what .. " runs off the book down: " .. top .. " + " .. H)
    end
    -- The cover's the same each side, so the view's middle is the pages'.
    Eq(ns.UI.Journal.BOOK.BOOK_W, 808, "the pages' width this reads against")

    OpenFirst()
    local plate = Plate()
    local w = plate.window
    local mx, my = w[1] * 0.3 + w[3] * 0.7, w[2] * 0.3 + w[4] * 0.7
    RightMap(plate, mx, my)
    Eq(#mock.contextMenu.children, 1, "the menu has the one entry")
    Eq(mock.contextMenu.children[1].text, "Add custom event...", "in the user's words")
    Eq(plate.ringPoint, nil, "no ring before it is asked for")
    Check(mock.MenuClick("Add custom event..."), "offered")
    view = CardSheet.View()
    Check(view:IsShown() and view.heading:IsShown(), "the picker opens")
    Eq(view.heading:GetText(), "What happened here?", "its title")
    Check(not view.title:IsShown() and not view.save:IsShown(), "no form under it")
    OnBook("the picker with one kind")

    local cells = Cells()
    Eq(#cells, #CardSheet.Kinds(), "a card a kind")
    Eq(#CardSheet.Kinds(), 9, "every margin card")
    Eq(cells[1].kind, "close", "the close call's")
    Eq(cells[1].eyebrow:GetText(), "COMBAT", "its type")
    Eq(cells[1].title:GetText(), "Close Call", "its name")
    Check(cells[1].kit.ink.used > 0 and cells[1].kit.inner.used > 0, "its map mark, from its own draw")

    -- The ring: the leaders' pencil, at the spot, on the picture.
    local ring = plate.ringPool
    Check(ring.used > 0, "the ring is drawn")
    Check(ring.used >= 9, "dashes of the pen's pieces: " .. ring.used)
    Eq(ring[1].anchorTo, plate.pivot, "on the picture, so it pans")
    local rx, ry = plate.At(mx, my, true)
    Check(math.abs(plate.ringPoint[1] - rx) < 1e-6 and math.abs(plate.ringPoint[2] - ry) < 1e-6, "at the spot")
    Eq(plate.ringAt.look.colour, ns.UI.YourDiary.LEADER.colour, "the leaders' graphite")

    -- The form, on the book, and the way back drops what was typed.
    PickKind("close")
    Check(not view.heading:IsShown() and view.title:IsShown(), "the form takes its place")
    Eq(view.title:GetText(), "A close call", "its own heading")
    Check(view.another:IsShown(), "the way back")
    Eq(view.another:GetText(), "Choose another", "in the user's words")
    OnBook("the new card's form")
    Check(ring.used > 0, "the ring stays on the form")
    Row("name"):Set("Old Tom")
    Row("foes"):Set("4")
    Row("rank").toggles.rare.scripts.OnClick(Row("rank").toggles.rare)
    Press(view.another)
    Check(view:IsShown() and view.heading:IsShown(), "back at the picker")
    Check(ring.used > 0, "the ring stays")
    PickKind("close")
    Eq(Row("name"):Get(), "", "what was typed went")
    Eq(Row("foes"):Get(), "", "all of it")
    Eq(Row("rank"):Get(), "", "the toggle too")
    Eq(Row("pct"):Get(), "5", "the kind's default stands")
    local calls = j.custom and #j.custom or 0

    -- Cancel, from the form and from the picker: nothing, and no ring.
    Press(view.cancel)
    Check(not view:IsShown(), "cancel closes")
    Eq(ring.used, 0, "the ring goes")
    Eq(plate.ringAt, nil, "for good")
    Eq(j.custom and #j.custom or 0, calls, "nothing saved")
    RightMap(plate, mx, my)
    mock.MenuClick("Add custom event...")
    Press(view.cancel)
    Eq(ring.used, 0, "the ring goes with the picker")

    -- Leaving the page: the same.
    RightMap(plate, mx, my)
    mock.MenuClick("Add custom event...")
    PickKind("close")
    Row("name"):Set("Old Tom")
    page.right:Hide()
    page.right:Show()
    Check(not view:IsShown(), "gone with the page")
    Eq(ring.used, 0, "and the ring")
    Eq(j.custom and #j.custom or 0, calls, "nothing saved")

    -- Saved: the ring goes, the card stays.
    OpenFirst()
    plate = Plate()
    RightMap(plate, mx, my)
    mock.MenuClick("Add custom event...")
    PickKind("close")
    Row("name"):Set("Old Tom")
    Press(view.save)
    Eq(plate.ringPool.used, 0, "saved, the ring goes")
    Eq(#j.custom, calls + 1, "written")
    Custom.Remove(j.custom[#j.custom])
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()

    -- An edit has no way back and no ring.
    RightOn(MarkOf(Plate()))
    Check(not view.another:IsShown(), "editing is not adding")
    Eq(Plate().ringPool.used, 0, "and has no ring")
    OnBook("the edit's form")
    Press(view.cancel)

    -- On the full page: through a zoom and a pan, at the same spot of the map.
    YourDiary.OpenFull(MAP)
    plate = Plate()
    RightMap(plate, 0.40, 0.55)
    local sx, sy = plate:MapAtCursor()
    mock.MenuClick("Add custom event...")
    Check(plate.ringPool.used > 0, "the ring on the full page")
    Check(plate.ringPool[1].anchorTo == plate.pivot, "on its picture")
    plate.look.onSettle(plate.look.f * 1.2, 0.45, 0.5)
    plate = Plate()
    Check(plate.ringPool.used > 0, "it survives the zoom's drawing")
    local nx, ny = plate.At(sx, sy, true)
    Check(math.abs(plate.ringPoint[1] - nx) < 1e-6 and math.abs(plate.ringPoint[2] - ny) < 1e-6,
        "at the same spot, drawn at the new view")
    Press(view.cancel)
    Eq(plate.ringPool.used, 0, "gone from the full page")
    OpenFirst()
end

--------------------------------------------------------------------------
Section("the picker's cards: where they really lie, and that they go")

do
    -- The mock computes no layout, so this does, from the anchors it records,
    -- as the client would: an anchor with no frame named is to the frame's
    -- parent (1 Nov, in the client: the rows were made on the sheet, so their bare
    -- anchors meant its corner, and only the anchors said so). A box is left,
    -- right, top, bottom, from the sheet's middle, y up. Its height is on its
    -- record: the mock's GetHeight is always 0.
    local function Size(frame)
        local r = frame.recorded
        return r.width or frame.width, r.height
    end
    local function Read(anchor, frame)
        local a = anchor.args
        if type(a[1]) == "table" then return a[1], a[2], a[3] or 0, a[4] or 0 end
        if type(a[1]) == "string" then return frame.parent, a[1], a[2] or 0, a[3] or 0 end
        return frame.parent, anchor.point, a[1] or 0, a[2] or 0
    end
    local Box
    local function At(frame, point, sheet)
        local l, r, t, b = Box(frame, sheet)
        local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
        local y = point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2
        return x, y
    end
    function Box(frame, sheet)
        if frame == sheet then
            local w, h = Size(frame)
            return -w / 2, w / 2, h / 2, -h / 2
        end
        local points = {}
        for _, anchor in ipairs(frame.recorded.points) do points[anchor.point] = anchor end
        local w, h = Size(frame)
        if points.CENTER then
            local rel, rp, x, y = Read(points.CENTER, frame)
            local cx, cy = At(rel, rp, sheet)
            cx, cy = cx + x, cy + y
            return cx - w / 2, cx + w / 2, cy + h / 2, cy - h / 2
        end
        local rel, rp, x, y = Read(points.TOPLEFT, frame)
        local l, t = At(rel, rp, sheet)
        l, t = l + x, t + y
        if points.RIGHT then
            local rr, rrp, rx = Read(points.RIGHT, frame)
            w = At(rr, rrp, sheet) + rx - l
        end
        return l, l + w, t, t - h
    end
    -- Shown all the way up: only what was told to hide counts as hidden, as the
    -- client's regions start shown.
    local function Showing(frame)
        while frame do
            if frame.recorded and frame.recorded.toldShown == false then return false end
            frame = frame.parent
        end
        return true
    end
    local function ShownCards(view)
        local list = {}
        for _, row in ipairs(view.list.rows) do
            for _, cell in ipairs(row.cells) do
                if cell.kind and Showing(cell.strip) and Showing(row) then list[#list + 1] = cell end
            end
        end
        return list
    end

    OpenFirst()
    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    local view = CardSheet.View()
    local S = view.sheet
    local list = view.list

    for i, row in ipairs(list.rows) do Eq(row.parent, list, "row " .. i .. " is the list's") end

    local function Lying()
        Check(Showing(view.heading), "the title is showing")
        local _, _, _, titleFoot = Box(view.heading, S)
        local sl, sr, st, sb = Box(S, S)
        local ll, lr, lt, lb = Box(list, S)
        Check(lt <= titleFoot, "the list's area lies over the title: " .. lt .. " over " .. titleFoot)
        Check(ll >= sl and lr <= sr and lb >= sb, "the list runs off the sheet")
        local _, _, cancelTop = Box(view.cancel.label, S)
        Check(lb >= cancelTop, "the list runs over Cancel: " .. lb .. " under " .. cancelTop)
        local cards = ShownCards(view)
        Check(cards[1] ~= nil, "a card is showing")
        for _, cell in ipairs(cards) do
            local l, r, t, b = Box(cell.strip, S)
            Check(l >= sl and r <= sr, "the card runs off the sheet across: " .. l .. ".." .. r)
            Check(t <= titleFoot, "the card lies over the title: " .. t .. " over " .. titleFoot)
            Check(b >= cancelTop, "the card lies over Cancel: " .. b .. " under " .. cancelTop)
            Check(r - l < sr - sl, "the card is narrower than its sheet")
        end
    end
    Lying()
    local ALL = #CardSheet.Kinds()
    Eq(#ShownCards(view), ALL, "a card a kind")

    local function Gone(what)
        Eq(#ShownCards(view), 0, what .. ": a card is still showing")
        for i, row in ipairs(list.rows) do
            Check(not Showing(row), what .. ": row " .. i .. " is still showing")
        end
    end

    PickKind("close")
    Check(Showing(view.title), "the form's heading shows")
    Gone("on the form")
    Check(not Showing(view.heading), "the picker's title goes")

    Press(view.another)
    Check(not Showing(view.title), "back: the form's heading goes")
    Check(not Showing(view.save), "back: Save goes")
    Lying()
    Eq(#ShownCards(view), ALL, "back: the same cards, none twice")

    Press(view.cancel)
    Gone("cancelled from the picker")

    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    Lying()
    Eq(#ShownCards(view), ALL, "reopened: the same cards")
    PickKind("close")
    Press(view.cancel)
    Gone("cancelled from the form")

    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    PickKind("close")
    Row("name"):Set("Old Tom")
    Press(view.save)
    Gone("saved")
    Custom.Remove(j.custom[#j.custom])
    ns.UI.RefreshJourneyPage(false)
    OpenFirst()

    -- An edit never shows them either, right after a picker.
    RightOn(MarkOf(Plate()))
    Gone("on an edit's form")
    Press(view.cancel)

    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    Lying()
    Eq(#ShownCards(view), ALL, "reopened after all that: the same cards")
    Press(view.cancel)
end

--------------------------------------------------------------------------
Section("the picker with more kinds than it holds")

do
    local Plates = ns.UI.JourneyPlate
    local added = {}
    local drew = 0
    -- A throwaway kind for each place: type, then `at`, then its name, and one
    -- whose group nobody knows, which counts as Other.
    local function Kind(kind, group, at)
        ns.JourneyRecap.MOMENTS[kind] = { kind = kind, custom = { label = "Kind " .. kind, group = group, at = at, fields = {} } }
        Plates.MARKS[kind] = { draw = function(kit, x, y)
            drew = drew + 1
            kit.Dot(kit.halo, x, y, 8, kit.P, 1)
            kit.Stroke(kit.ink, x - 3, y, x + 3, y, 1, kit.INK_STRONG, 1)
        end }
        added[#added + 1] = kind
    end
    Kind("zz_other", "other", 1)
    Kind("zz_nobody", "nonsense", 0)
    Kind("zz_social", "social")
    Kind("zz_lore2", "lore", 2)
    Kind("zz_lore1", "lore", 1)
    Kind("zz_combat", "combat", -1)
    for i = 1, 8 do Kind("zy_fill" .. i, "other", 5) end

    local order = {}
    local mine = {}
    for _, k in ipairs(CardSheet.Kinds()) do
        order[#order + 1] = k.kind
        if k.kind == "close" or k.kind:find("^zz_") then mine[#mine + 1] = k.kind end
    end
    local want = { "zz_combat", "close", "zz_lore1", "zz_lore2", "zz_social", "zz_nobody", "zz_other" }
    for i, kind in ipairs(want) do Eq(mine[i], kind, "the order at " .. i) end
    Eq(#order, 23, "every kind, and only those with a spec")

    OpenFirst()
    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    local view = CardSheet.View()
    local list = view.list
    Eq(list.numRows, 5, "the rows it holds")
    Check(#list.data > list.numRows, "more rows than it holds: " .. #list.data)
    Check(list.bar:IsShown(), "so its bar shows")
    local firstBefore = Cells()[1].kind
    Eq(firstBefore, "zz_combat", "from the top")
    do
        local lore = false
        for _, cell in ipairs(Cells()) do
            lore = lore or (cell.kind == "luck" and cell.eyebrow:GetText() == "QUESTS AND LORE")
        end
        Check(lore, "a type's words")
    end
    list.Wheel(list, -1)
    Check(list.offset > 0, "the wheel scrolls it")
    Check(Cells()[1].kind ~= firstBefore, "to other cards")
    list:SetOffset(#list.data)
    local cells = Cells()
    Eq(cells[#cells].kind, order[#order], "to the last")
    Check(drew > 0, "each by its own mark")
    -- Laid wholly on the book, at its widest and tallest.
    local S, BOOK = view.sheet, ns.UI.Journal.BOOK
    local left = BOOK.BOOK_W / 2 + view.dx - S:GetWidth() / 2
    Check(left >= 0 and left + S:GetWidth() <= BOOK.BOOK_W, "the two-column picker runs off the book")
    Check(S.recorded.height > 400 and S.recorded.height <= BOOK.BOOK_H,
        "the tall picker runs off the book: " .. S.recorded.height)
    -- A row's card opens its kind's form; here a kind with no fields still does.
    local chosen = cells[#cells].kind
    PickKind(chosen)
    Eq(view.title:GetText(), "Kind " .. chosen, "the label stands in for a heading")
    Press(view.cancel)

    for _, kind in ipairs(added) do
        ns.JourneyRecap.MOMENTS[kind] = nil
        Plates.MARKS[kind] = nil
    end
    Eq(#CardSheet.Kinds(), 9, "the throwaway kinds are gone")
    OpenFirst()
    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    Eq(#Cells(), 9, "and the sheet is back to every kind")
    Press(view.cancel)
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
    Check(mock.MenuClick("Add custom event..."), "offered on the full page")
    PickKind("close")
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
    Check(mock.MenuClick("Add custom event..."), "still offered")
    PickKind("close")
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
    Check(ns.Custom.Spec("close").label == "Close Call", "the spec names itself")
end

--------------------------------------------------------------------------
Section("the form: a person's line, toggles that wrap, what a detected card shows")

do
    local Plates = ns.UI.JourneyPlate
    local guid = "Player-1-0AAAAAAA"
    ns.db.characters[guid] = { guid = guid, names = { { first = "Brannoc", surname = "" } } }
    ns.db.diary[guid] = { tags = {}, addedAt = now, relationship = "", note = "" }
    ns.Touch()
    ns.JourneyRecap.MOMENTS.zz_form = { kind = "zz_form", custom = { label = "Form", group = "other",
        fields = {
            { key = "who", type = "person", label = "Who" },
            { key = "pick", type = "choice", label = "Pick", values = { "a", "b", "c", "d", "e" },
                names = { a = "A", b = "B", c = "C", d = "D", e = "E" } },
            { key = "after", type = "text", label = "After" },
        } } }
    Plates.MARKS.zz_form = { draw = function() end }
    OpenFirst()
    local plate = Plate()
    RightMap(plate, 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    local view = CardSheet.View()
    CardSheet.Edit("zz_form", { kind = "zz_form", t = now, who = "Written" })
    local rows = view.rows

    -- The boxes stay inside the sheet's width, on lines of their own, and the row
    -- after them clears the last line.
    local function X(frame)
        local anchor = frame.recorded.points[1]
        return anchor.args[3], anchor.args[4]
    end
    local across, down = {}, {}
    for value, box in pairs(rows[2].toggles) do
        local x, y = X(box)
        across[value], down[value] = x, y
        Check(x + box:GetWidth() / 2 <= view.sheet:GetWidth() / 2, "a toggle runs off the sheet: " .. value)
    end
    Check(math.abs(down.a - down.b) < 1, "two to a line: " .. down.a .. " and " .. down.b)
    Check(down.c < down.a - 10 and down.e < down.c - 10, "the rest wrap")
    Check(math.abs(across.a - across.c) < 1, "each line starts under the first")
    local _, afterY = X(rows[3].box)
    Check(afterY <= down.e - 20, "the row after them clears them: " .. afterY .. " after " .. down.e)

    -- A typed name is not picked; a line shows who the search finds, and picking one
    -- links them. Typing over it lets the link go.
    local line = rows[1].box
    Eq(line:GetText(), "Written", "the name as written shows")
    line:SetFocus()
    line:SetText("bran")
    line:GetScript("OnTextChanged")(line, true)
    Check(rows[1].found:IsShown(), "the search offers someone")
    -- Hung from the line by its top, whatever its height, so one name is as close
    -- to the line as four.
    do
        local top = rows[1].found.recorded.points[1]
        Eq(top.point, "TOPLEFT", "hung by its top")
        Eq(top.args[1], line, "from the line")
        Eq(top.args[2], "BOTTOMLEFT", "under it")
        Eq(#rows[1].found.recorded.points, 2, "and as wide as it, and no other anchor")
    end
    line:GetScript("OnTabPressed")(line)
    Check(not rows[1].found:IsShown(), "Tab leaves the offer behind")
    line:SetFocus()
    line:GetScript("OnTextChanged")(line, true)
    Eq(rows[1].rows[1].person.guid, guid, "the entry it found")
    rows[1].rows[1]:GetScript("OnClick")(rows[1].rows[1])
    Eq(rows[1].guid, guid, "picked")
    Eq(line:GetText(), rows[1].rows[1].person.name, "their name on the line")
    Check(not rows[1].found:IsShown(), "and the offer goes")
    line:SetText("Brannoc two")
    line:GetScript("OnTextChanged")(line, true)
    Eq(rows[1].guid, nil, "typing over it lets go")
    view.cancel:GetScript("OnClick")(view.cancel)

    ns.JourneyRecap.MOMENTS.zz_form, Plates.MARKS.zz_form = nil, nil

    -- A detected card's form shows what it keeps elsewhere, and writes none of it.
    local kept = { t = now - 60, link = "|cff1eff00|Hitem:1:|h[Thistle Sash]|h|r" }
    j.firsts = j.firsts or {}
    j.firsts.uncommon = kept
    CardSheet.Edit("find", kept)
    local name
    for _, row in ipairs(view.rows) do
        if row.field.key == "name" then name = row:Get() end
        if row.field.key == "what" then Eq(row:Get(), "uncommon", "which first, from its key") end
    end
    Eq(name, "Thistle Sash", "the item, from its link")
    view.save:GetScript("OnClick")(view.save)
    Eq(kept.custom, nil, "saved untouched: nothing written")
    j.firsts.uncommon = nil
end

--------------------------------------------------------------------------
Section("Enter saves the card")

do
    OpenFirst()
    RightMap(Plate(), 0.40, 0.60)
    mock.MenuClick("Add custom event...")
    local view = CardSheet.View()
    local before = #(j.custom or {})
    PickKind("met")
    local line = Row("who").box
    line:SetText("Old Friend")
    line:GetScript("OnEnterPressed")(line)
    Eq(#j.custom, before + 1, "the card is written")
    Eq(j.custom[#j.custom].who or j.custom[1].who, "Old Friend", "with what was typed")
    Check(not view:IsShown(), "and the form closes")
    Custom.Remove(j.custom[1])
end
