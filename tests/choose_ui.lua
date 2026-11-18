-- "Choose what's on this page" (.claude/features/choose-page.md, Phase 3;
-- UI/Journey/Choose.lua): the link under the open level, the ticklist in
-- place of the left page, its rows and looks, a tick leaving a place out and
-- keeping one (the right page drawn again, the bumped place's "made room
-- for"), a card left out, the block (red cap line, the box shaking, nothing
-- written), Done, leaving by another level or the ribbon, and no link with
-- the pad in hand. Construction and logic only: how it looks is for the
-- client. Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local YD = ns.UI.YourDiary
local J, Chosen = ns.Journey, ns.Chosen
local WORDS = YD.CHOOSE_WORDS

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

-- Five zones, a stop in each (as tests/choices.lua's): the three longest
-- (a death, a fight, a long stay) are on the page, the first next in line,
-- the last no room.
local FOE = "Player-1111-0000BBBB"
local t0 = now - 20000
J.Begin(ns.ownGUID, t0, 12, 1411)
local j = J.Mine()
local function Stop(from, seconds, mapID, act)
    return { kind = "stop", from = from, to = from + seconds, mapID = mapID, x = 0.5, y = 0.5, r = 30,
        seconds = seconds, levelFrom = 12, levelTo = 12, act = act }
end
j.segments = { Stop(t0, 1000, 1411), Stop(t0 + 2000, 2000, 1412, { deaths = 1 }), Stop(t0 + 5000, 3000, 1413),
    Stop(t0 + 9000, 4000, 1415), Stop(t0 + 14000, 500, 1416) }
j.open = nil
j.marks = { { kind = "fight", outcome = "won", guid = FOE, t = t0 + 6000, mapID = 1413, x = 0.52, y = 0.5 } }
J.Touch()

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function LinkItem()
    for _, item in ipairs(page.items) do
        if item.choose then return item end
    end
end
local function EntryRow(test)
    for _, row in ipairs(page.entries.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
end
local function Row(test)
    for _, row in ipairs(page.chooser.list.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
end
local function PlaceRow(mapID)
    return Row(function(item) return item.place ~= nil and item.place.mapID == mapID end)
end
local function Place(mapID)
    for _, place in ipairs(page.choices.places) do
        if place.mapID == mapID then return place end
    end
end
local function Shown()
    local list = {}
    for i = 1, page.layout or 0 do
        if page.plates[i] and page.plates[i]:IsShown() then list[#list + 1] = page.plates[i].mapID end
    end
    table.sort(list)
    return table.concat(list, " ")
end
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
local function Frames()
    local out = {}
    for k, f in ipairs(page.chooser.frames) do out[k] = f.kind or "free" end
    return table.concat(out, " ")
end
local function Copy(t)
    local copy = {}
    for k, v in pairs(t or {}) do copy[k] = v end
    return copy
end
local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

--------------------------------------------------------------------------
Section("the link under the open level, with the mouse")

Eq(Shown(), "1412 1413 1415", "setup: the three busiest places on the page")
local link = LinkItem()
Check(link ~= nil, "no link to the ticklist under the open level")
Eq(link and link.label, WORDS.title, "the link's words")
Eq(page.items[page.rubrics[page.open] + 1], link, "the link straight under the rubric of a level drawn whole")
local linkRow = EntryRow(function(item) return item.choose == true end)
Check(linkRow and linkRow.zone:IsShown() and linkRow.zone:GetText() == WORDS.title, "the link's row not written")
Check(YD.Opens(link), "the link does nothing")

--------------------------------------------------------------------------
Section("the ticklist in place of the left page")

linkRow:Click()
local ch = page.chooser
Check(page.choosing and ch and ch:IsShown(), "the link did not open the ticklist")
Check(not page.entries:IsShown() and not page.name:IsShown(), "the left page still shown under it")
Eq(ch.title:GetText(), WORDS.title, "the title")
Eq(ch.rubric:GetText(), "LEVEL 12", "the level's rubric")
Eq(ch.cap:GetText(), WORDS.cap, "the cap line")
Check(not Red(ch.cap), "the cap line red before anything was blocked")
Eq(Frames(), "diary diary diary", "three frames, faded: all the diary's")
local order = {}
for _, item in ipairs(ch.list.data) do
    if item.place then order[#order + 1] = item.place.mapID end
end
Eq(table.concat(order, " "), "1411 1412 1413 1415 1416", "every place, in time order")
local cards = 0
for i, item in ipairs(ch.list.data) do
    if item.card then
        cards = cards + 1
        local before = ch.list.data[i - 1]
        Check(before.card or before.place.on, "a card under a place off the page")
    end
end
Check(cards > 0, "no card rows under the places on the page")
local next, noRoom = PlaceRow(1411), PlaceRow(1416)
Eq(next.placeBox.look, "diaryOff", "a place off the page: an empty box")
Check(not next.placeBox.tick[1]:IsShown(), "an empty box ticked")
Eq(next.why:GetText(), WORDS.reason.next, "the best place left off: next in line")
Eq(noRoom.why:GetText(), WORDS.reason.noRoom, "the rest: no room")
Check(not Red(next.why), "the diary's reason in red")
local on = PlaceRow(1413)
Eq(on.placeBox.look, "diary", "a place on the page: the diary's tick")
Check(on.placeBox.tick[1]:IsShown() and not on.placeBox.cross[1]:IsShown(), "the diary's pick not ticked")
Check(not on.why:IsShown(), "a reason under a place on the page")
Eq(on.time:GetText(), ns.UI.Format.Clock(t0 + 5000), "a place's time: its first moment's")
local fightRow = Row(function(item) return item.card ~= nil and item.card.kind == "fight" end)
Check(fightRow and fightRow.cardBox:IsShown() and not fightRow.placeBox:IsShown(), "a card row has no card box")
Eq(fightRow and fightRow.name:GetText(), ns.Characters.Name(FOE) or ns.Characters.FullName(FOE) or "Someone",
    "a person's card: their name")
Eq(j.chosen, nil, "opening the ticklist wrote something")

--------------------------------------------------------------------------
Section("a tick on a place on the page: left out, and the next comes in")

on:Click()
Check(page.choosing and ch:IsShown(), "the ticklist closed with a tick")
Eq(Shown(), "1411 1412 1415", "the right page not drawn again: the place left out, the next in")
local out = PlaceRow(1413)
Eq(out.placeBox.look, "out", "a place left out: a red cross")
Check(out.placeBox.cross[1]:IsShown() and not out.placeBox.tick[1]:IsShown(), "the cross not drawn")
Check(out.strike:IsShown(), "its name not struck through")
Eq(out.why:GetText(), WORDS.reason.byYou, "left out by you")
Check(Red(out.why), "the player's reason not in red")
Check(not Row(function(item) return item.card ~= nil and item.card.place.mapID == 1413 end),
    "a place left out still open")
local saved = 0
for _, v in pairs(j.chosen or {}) do
    Eq(v, "out", "a place left out: out on its moments")
    saved = saved + 1
end
Check(saved > 0, "nothing written for a place left out")
Eq(Frames(), "diary diary diary", "the frames: still the diary's three")

--------------------------------------------------------------------------
Section("a tick on a place off the page: kept, and the diary's weakest makes room")

PlaceRow(1416):Click()
local kept = Place(1416)
Eq(kept.look, "keep", "a place kept: the player's")
Check(kept.on, "a place kept not on the page")
Check(Shown():find("1416") ~= nil, "the right page without the place kept")
Eq(PlaceRow(1416).placeBox.look, "keep", "its box: a red tick")
Check(PlaceRow(1416).placeBox.tick[1]:IsShown(), "the red tick not drawn")
Eq(Frames(), "mine diary diary", "the frames: one the player's, two the diary's")
local bumped
for _, place in ipairs(page.choices.places) do
    if place.reason == "madeRoom" then bumped = place end
end
Check(bumped ~= nil, "no place made room")
local bumpedRow = bumped and PlaceRow(bumped.mapID)
Eq(bumpedRow and bumpedRow.why:GetText(), WORDS.madeRoom:format(PlaceRow(1416).name:GetText()),
    "made room for the place kept")

--------------------------------------------------------------------------
Section("three places the player's, and a fourth blocked")

PlaceRow(bumped.mapID):Click()
Eq(Frames(), "mine mine diary", "two of the player's")
PlaceRow(1413):Click()
Eq(Place(1413).look, "keep", "a place left out kept again")
Eq(Frames(), "mine mine mine", "three of the player's")
local off
for _, place in ipairs(page.choices.places) do
    if not place.on then off = place end
end
Check(off ~= nil, "setup: a place off the page")
local before = Copy(j.chosen)
local offRow = PlaceRow(off.mapID)
offRow:Click()
Check(Same(before, j.chosen or {}), "a blocked tick wrote something")
Eq(ch.cap:GetText(), WORDS.blocked, "the cap line does not say why")
Check(Red(ch.cap), "the cap line not red")
Check(offRow.placeBox.scripts.OnUpdate ~= nil, "the box does not shake")
for _ = 1, 30 do
    local f = offRow.placeBox.scripts.OnUpdate
    if f then f(offRow.placeBox, 0.05) end
end
Check(offRow.placeBox.scripts.OnUpdate == nil, "the box never stops shaking")
Eq(Place(off.mapID).look, off.look, "the blocked place changed")

--------------------------------------------------------------------------
Section("a card left out")

PlaceRow(1413):Click()  -- (room again: a place of the player's left out)
Check(not Red(ch.cap) and ch.cap:GetText() == WORDS.cap, "the cap line still red after a tick that went through")
local card = Row(function(item) return item.card ~= nil and item.card.look ~= "out" and item.card.on end)
Check(card ~= nil, "setup: a card on the page")
local key = card.item.card.key
card:Click()
local stillOn = false
for _, place in ipairs(page.choices.places) do
    for _, c in ipairs(place.cards) do
        if c.key == key then stillOn = c.on end
    end
end
Check(not stillOn, "a card left out still on the page")

--------------------------------------------------------------------------
Section("Done, another level, the ribbon: the left page given back")

ch.done:Click()
Check(not page.choosing and not ch:IsShown(), "Done did not close the ticklist")
Check(page.entries:IsShown() and page.name:IsShown(), "Done did not give the left page back")
YD.Choose()
Check(page.choosing, "setup: the ticklist open again")
YD.OpenLevel(page.open)
Check(not page.choosing and not ch:IsShown() and page.entries:IsShown(), "opening a level left it open")
YD.Choose()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
Check(not page.choosing and not ch:IsShown() and page.entries:IsShown(), "the ribbon left it open")

--------------------------------------------------------------------------
Section("the right-click menus: a place left out, someone left off")

-- (Phase 4: a plate's "Leave this place out" and "Choose what's on this
-- page...", a person's strip's "Leave <name> off this page"; the menu only
-- hides, so neither is ever listed under "Left out of this page")
local CARD = YD.CardSheet
local MW = {
    leavePlace = ns.L["Leave this place out"], choose = ns.L["Choose what's on this page..."],
    hidden = ns.L["Left out of this page"],
}
ns.Characters.Observe(FOE, { first = "Wrenna", surname = "Tallowbrook" })
j.chosen = nil
J.Touch()
ns.UI.RefreshJourneyPage(false)
Eq(Shown(), "1412 1413 1415", "setup: the diary's three again")
local function PlateOf(mapID)
    for i = 1, page.layout or 0 do
        if page.plates[i].mapID == mapID then return page.plates[i] end
    end
end
local function Menu(owner)
    mock.contextMenu = nil
    owner()
    local out = {}
    for _, child in ipairs(mock.contextMenu and mock.contextMenu.children or {}) do
        if child.text then out[child.text] = child.kind end
    end
    return out
end
local function PersonStrip()
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() and strip.guid == FOE then return strip end
    end
end

local lines = Menu(function() PlateOf(1413):Right() end)
Eq(lines[MW.leavePlace], "button", "no \"Leave this place out\" on a plate's menu")
Eq(lines[MW.choose], "button", "no \"Choose what's on this page...\" on a plate's menu")
Eq(lines[MW.hidden], nil, "a list of cards left out with nothing hidden")

-- Choose...: the ticklist, as the link opens it; not offered while it is open.
mock.MenuClick(MW.choose)
Check(page.choosing and page.chooser:IsShown(), "\"Choose what's on this page...\" did not open the ticklist")
lines = Menu(function() PlateOf(1413):Right() end)
Eq(lines[MW.choose], nil, "\"Choose...\" offered with the ticklist open")
Eq(lines[MW.leavePlace], "button", "\"Leave this place out\" gone with the ticklist open")
page.chooser.done:Click()

-- Someone's strip: their menu, the mouse's alone.
local strip = PersonStrip()
Check(strip ~= nil, "setup: the fight's person has a strip")
Check(strip.onRight ~= nil and strip.rightMouse == true, "a person's strip has no menu, or the pad's Y takes it")
lines = Menu(function() strip.onRight() end)
local leaveHer = ns.Fmt(ns.L["Leave %1$s off this page"], "Wrenna")
Eq(leaveHer, "Leave Wrenna off this page", "the person's line in words")
Eq(lines[leaveHer], "button", "no \"Leave <name> off this page\" on their strip")
mock.MenuClick(leaveHer)
Eq(PersonStrip(), nil, "their strip still on the page")
local theirs = 0
for key, v in pairs(j.chosen or {}) do
    if key:find(FOE, 1, true) then
        Eq(v, "out", "a person left off: out on their moments")
        theirs = theirs + 1
    end
end
Check(theirs > 0, "nothing written for a person left off")

-- A place left out: off the page, the next one in.
local before = Shown()
lines = Menu(function() PlateOf(1412):Right() end)
Eq(lines[MW.hidden], nil, "someone left off listed under \"Left out of this page\"")
mock.MenuClick(MW.leavePlace)
Eq(PlateOf(1412), nil, "the place left out still on the page")
Eq(page.layout, 3, "the next place did not come in")
Check(Shown() ~= before and Shown():find("1411") ~= nil, "not the next in line that came in: " .. Shown())
for i = 1, page.layout do
    lines = Menu(function() page.plates[i]:Right() end)
    Eq(lines[MW.hidden], nil, "a place left out listed under \"Left out of this page\"")
end

-- With the pad's Y, none of these: no menu, nothing written.
local was = Copy(j.chosen)
mock.contextMenu = nil
Eq(CARD.PadRight(page.plates[1], nil, true), nil, "the pad's Y offered on a plate (nothing to add here)")
CARD.PadRight(page.plates[1], nil, false)
Eq(mock.contextMenu, nil, "the pad's Y opened the mouse's menu")
Check(Same(was, j.chosen or {}), "the pad's Y wrote a choice")
j.chosen = nil
J.Touch()
ns.UI.RefreshJourneyPage(false)

--------------------------------------------------------------------------
Section("with the pad in hand: no link, and the ticklist given back")

YD.Choose()
Check(page.choosing, "setup: the ticklist open")
local Pad = ns.UI.Pad
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad in hand")
Check(not page.choosing and not ch:IsShown(), "the ticklist stayed open with the pad picked up")
Check(page.entries:IsShown(), "the left page not given back for the pad")
Eq(LinkItem(), nil, "the link offered with the pad in hand")
YD.Choose()
Check(not page.choosing, "the ticklist opened with the pad in hand")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(LinkItem() ~= nil, "the link not back with the mouse")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}

--------------------------------------------------------------------------
Section("a card kept that the margin had no room for comes into it")

-- (/sd testdata: a level whose first plate's margin leaves a duel off)
SlashCmdList.SOCIALDIARY("testdata")
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
do
    local function Off()
        for _, p in ipairs(T.DiaryPages(page)) do
            T.OpenDiaryPage(page, p.i, p.k)
            for i = 1, page.layout or 0 do
                for _, it in ipairs(page.plates[i].leftOff or {}) do
                    if it.kind == "duel" and it.moments and it.moments[1] then return p, i, it.moments[1] end
                end
            end
        end
    end
    local p, i, m = Off()
    Check(m ~= nil, "setup: testdata has a duel the margin left off")
    if m then
        local function InMargin()
            for _, it in ipairs(page.plates[i].margin or {}) do
                if it.kind == "duel" then return true end
            end
            return false
        end
        Check(not InMargin(), "setup: the duel not in the margin")
        local tj = J.For(ns.ownGUID)
        Chosen.Keep(tj, m)
        ns.UI.RefreshJourneyPage(false)
        T.OpenDiaryPage(page, p.i, p.k)
        Check(InMargin(), "the duel kept is still left off the margin")
        Eq(page.plates[i].margin[1].kind, "duel", "the card kept not laid first")
        tj.chosen = nil
        J.Touch()
    end
end
