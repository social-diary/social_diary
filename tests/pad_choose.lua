-- "Choose what's on this page" with the pad (UI/Journey/Choose.lua, the
-- `choose` group of Your Diary's scope in UI/Journey/Pad.lua;
-- .claude/features/choose-page.md, "Later: the gamepad"): the link on the
-- left page reached and opened with A, every zone and row of the ticklist
-- reached, A doing what the click does (keep, leave out, a zone's three
-- looks, a blocked tick taken with nothing written), the pad kept on its
-- row across a tick, the hover's tooltip, ring and lit frame, B back to the
-- link and then as before, Done, right to the plates and back, Y on a plate
-- (the mouse's menu on the pad's slip, the same lines) and on a person's
-- strip, nothing passed on, combat, the mouse taking over (every colour
-- back), the Gamepad UI off, no item clicked. Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local YD = ns.UI.YourDiary
local J = ns.Journey
local Pad = ns.UI.Pad
local WORDS = YD.CHOOSE_WORDS
local CardSheet = YD.CardSheet
local L = ns.L

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

-- Five zones, a stop in each, a fight in the third (as tests/choose_ui.lua's):
-- 1412, 1413 and 1415 on the page, 1411 next in line, 1416 no room.
local FOE = "Player-1111-0000BBBB"
ns.Characters.Observe(FOE, { first = "Wrenna", surname = "Tallowbrook" })
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

-- The pad in hand, Your Diary open.
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local book = ns.UI.JournalFrame()
local catcher = Pad.Catcher(book)
local parts

local function Press(key)
    local went = mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
    return went
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group)
    local g = Scope().focus.groups[group]
    return g and g.items or {}
end
local function Legend()
    local out = {}
    for _, e in ipairs(Pad.Legend(Scope())) do out[type(e[1]) == "table" and e[1][1] or e[1]] = e[2] end
    return out
end
local function Copy(t)
    local copy = {}
    for k, v in pairs(t or {}) do copy[k] = v end
    return copy
end
local function Same(a, b)
    for k, v in pairs(a or {}) do if (b or {})[k] ~= v then return false end end
    for k, v in pairs(b or {}) do if (a or {})[k] ~= v then return false end end
    return true
end
local function IsRed(r, g, b)
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
local function Red(fs) return fs ~= nil and IsRed(fs:GetTextColor()) end
local function Colour(fs) return { fs:GetTextColor() } end
local function SameColour(a, b)
    for i = 1, 4 do
        if math.abs((a[i] or 1) - (b[i] or 1)) > 0.001 then return false end
    end
    return true
end
local function Shown()
    local list = {}
    for i = 1, page.layout or 0 do
        if page.plates[i] and page.plates[i]:IsShown() then list[#list + 1] = page.plates[i].mapID end
    end
    table.sort(list)
    return table.concat(list, " ")
end
local function Walk(test, group)
    group = group or "choose"
    local f = Scope().focus
    -- (from the top of the group, by the D-pad from there)
    if f.groups[group] and f.groups[group].opts.mode == "spatial" then
        -- (a spatial group: stood on directly, as tests/pad_cards.lua's Stand)
        for _, item in ipairs(f.groups[group].items) do
            if test(item) then
                f:Set(item)
                return item
            end
        end
        return nil
    end
    f:Remember(group, nil)
    if not f:EnterGroup(group) then return nil end
    for _ = 1, 60 do
        local at = At()
        if at and at.group == group and test(at) then return at end
        Press("PADDDOWN")
    end
end
local function OnKey(key) return Walk(function(at) return at.key == key end) end
-- The ticklist's item the pad stands on, as the list holds it now.
local function Choice() return page.chooser.list.data[At().index] end
local function RowFor(key)
    for _, row in ipairs(page.chooser.list.rows) do
        if row:IsShown() and row.item and row.item.zone and ("zone:" .. tostring(row.item.zone.mapID)) == key then
            return row
        end
        if row:IsShown() and row.item and row.item.card and ("row:" .. tostring(row.item.card.keys[1])) == key then
            return row
        end
    end
end
local function Mine(mapID)
    local n = 0
    for key, v in pairs(j.chosen or {}) do
        if v == "out" or v == "keep" then n = n + 1 end
    end
    return n
end
local function Reset()
    j.chosen = nil
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
end

Eq(Scope().key, "yourdiary", "setup: the page's scope")
Eq(Shown(), "1412 1413 1415", "setup: the diary's three on the page")

--------------------------------------------------------------------------
Section("the link: on the left page with the pad, A opens the ticklist")

local linkItem
for _, item in ipairs(page.items) do if item.choose then linkItem = item end end
Check(linkItem ~= nil, "the link not offered with the pad in hand")
local onLink = Walk(function(at) return at.key == "choose" end, "left")
Check(onLink ~= nil, "the pad does not reach the link on the left page")
Eq(onLink and onLink.words and onLink.words:GetText(), WORDS.title, "the box not round the link's words")
Check(Red(onLink.words), "the link's words not red under the pad")
Eq(Legend().PAD1, L["Open"], "A's prompt on the link")
Check(not Press("PAD1"), "A on the link went on to the game")
Check(page.choosing and page.chooser:IsShown(), "A on the link did not open the ticklist")
Eq(Scope().key, "yourdiary", "the ticklist took a scope of its own")
Eq(At().group, "choose", "the pad not on the ticklist")
Eq(At().key, "zone:1411", "the pad not on the first zone")
Check(not Red(onLink.words), "the link's words left red under the ticklist")
Eq(j.chosen, nil, "opening it wrote something")

--------------------------------------------------------------------------
Section("every zone and row reached, keyed by its moments, then Done")

parts = Pad.Look.parts[book]
local ch = page.chooser
local data = ch.list.data
local items = Items("choose")
Eq(#items, #data + 1, "not every row an item, and Done")
Eq(items[#items].key, "done", "Done not last")
for i, item in ipairs(data) do
    local want = item.zone and ("zone:" .. item.zone.mapID) or ("row:" .. tostring(item.card.keys[1]))
    Eq(items[i].key, want, "an item's key not its moments'")
end
Scope().focus:EnterGroup("choose")
Scope().focus:Focus("zone:1411", "choose")
local seen = {}
for i = 1, #items do
    local at = At()
    seen[#seen + 1] = at.key
    Check(parts.pen:IsShown(), "no pen box on " .. at.key)
    if not at.done then
        Check(at.words and Red(at.words), "a row's words not red under the pad: " .. at.key)
        Check(at.frame and at.frame.item == data[at.index], "the box not on the row showing its item: " .. at.key)
        if at.zoneIndex then
            Check(at.subhead ~= nil and Red(at.subhead), "a moment's zone not its subheading: " .. at.key)
        end
    else
        Check(Red(ch.done.label), "Done's words not red under the pad")
        Eq(Legend().PAD1, L["Done"], "A's prompt on Done")
    end
    if i < #items then Check(not Press("PADDDOWN"), "down went on to the game") end
end
Eq(table.concat(seen, " "), (function()
    local k = {}
    for _, item in ipairs(items) do k[#k + 1] = item.key end
    return table.concat(k, " ")
end)(), "down did not walk every row in order")
Eq(Legend().PAD2, L["Back to the contents"], "B's prompt on the ticklist")

--------------------------------------------------------------------------
Section("on a row, what the mouse's hover does: tooltip, ring, lit frame")

local fightKey
for _, item in ipairs(data) do
    if item.card and item.card.kind == "fight" then fightKey = "row:" .. item.card.keys[1] end
end
Check(fightKey ~= nil, "setup: the fight's row")
OnKey(fightKey)
local fightRow = At().frame
local plateOfFight = page.plates[Choice().card.plate]
Check(plateOfFight.ringAt ~= nil and plateOfFight.ringAt.mapID == 1413, "the pad on a row does not ring its mark")
Check(GameTooltip.shown and GameTooltip.text == Choice().label, "the row's tooltip not shown under the pad")
Check(ch.frames[Choice().card.plate].hot == true, "the row's map's frame not lit")
Eq(Legend().PAD1, L["Leave it out"], "A's prompt on a row on the page")
OnKey("zone:1411")
Eq(plateOfFight.ringAt, nil, "the ring left behind as the pad moved off")
for _, f in ipairs(ch.frames) do Check(not f.hot, "a frame left lit") end
Check(GameTooltip.lines and GameTooltip.lines[1] and GameTooltip.lines[1][1] == WORDS.reason.next,
    "an off zone's tooltip does not say why")
Eq(Legend().PAD1, L["Bring this place in"], "A's prompt on a zone off the page")

--------------------------------------------------------------------------
Section("A is the click: a zone left out and kept, the pad on its row")

OnKey("zone:1413")
Eq(Legend().PAD1, L["Leave this place out"], "A's prompt on a zone on the page")
Check(not Press("PAD1"), "A on a zone went on to the game")
local outByPad = Copy(j.chosen)
Check(next(outByPad) ~= nil, "A on a zone on the page wrote nothing")
for _, v in pairs(outByPad) do Eq(v, "out", "A on a zone on the page did not leave it out") end
Eq(At().key, "zone:1413", "the pad moved off its zone after a tick")
Eq(Choice().row.look, "out", "the zone's box not crossed")
Check(Red(At().words), "the look not back on the row after the tick")
Check(At().frame.item == Choice(), "the box on a stale row after the tick")
Check(not Shown():find("1413"), "the zone still on the page")
Eq(Legend().PAD1, L["Bring this place in"], "A's prompt on a zone left out")
-- The same with the mouse: the same choice written.
Reset()
RowFor("zone:1413"):Click()
Check(Same(outByPad, j.chosen), "A did not write what the click writes")
OnKey("zone:1413")
Press("PAD1")
local keptByPad = Copy(j.chosen)
Reset()
RowFor("zone:1413"):Click()
RowFor("zone:1413"):Click()
Check(Same(keptByPad, j.chosen), "A on a zone left out did not write what the click writes")
Eq(Shown(), "1412 1413 1415", "kept, the zone not back")

Section("a row left out and kept again; the zone's dash")
Reset()
OnKey(fightKey)
Press("PAD1")
local key = fightKey:sub(5)
Eq(j.chosen and j.chosen[key], "out", "A on a row on the page did not leave it out")
Eq(At().key, fightKey, "the pad moved off its row after a tick")
Eq(Choice().row.look, "out", "the row not crossed")
Eq(Legend().PAD1, L["Bring it in"], "A's prompt on a row left out")
local zoneItem
for _, item in ipairs(page.chooser.list.data) do
    if item.zone and item.zone.mapID == 1413 then zoneItem = item end
end
Eq(zoneItem.zone.state, "some", "the zone not a dash with one of its rows left out")
Press("PAD1")
Eq(j.chosen and j.chosen[key], "keep", "A on a row left out did not keep it")
Eq(Legend().PAD1, L["Leave it out"], "A's prompt on a kept row")

--------------------------------------------------------------------------
Section("a blocked tick: taken, shaken, the line red, nothing written")

Reset()
OnKey("zone:1412")
Press("PAD1")
Press("PAD1")
OnKey("zone:1415")
Press("PAD1")
Press("PAD1")
OnKey("zone:1413")
Press("PAD1")
Press("PAD1")
local off
for _, zone in ipairs(page.choices.zones) do if not zone.on then off = zone end end
Check(off ~= nil, "setup: a zone off the page")
OnKey("zone:" .. off.mapID)
local before = Copy(j.chosen)
local box = At().frame.placeBox
Check(not Press("PAD1"), "a blocked A went on to the game")
Check(Same(before, j.chosen), "a blocked A wrote something")
Eq(ch.note:GetText(), WORDS.blocked, "the footer does not say why")
Check(box.scripts.OnUpdate ~= nil, "the box does not shake")
Eq(At().key, "zone:" .. off.mapID, "the pad moved off after a blocked A")
Check(Red(At().words), "the look lost after a blocked A")
Reset()

--------------------------------------------------------------------------
Section("right to the plates, their frame and rows lit, and back")

OnKey(fightKey)
Check(not Press("PADDRIGHT"), "right went on to the game")
Eq(At().group, "page", "right from the list did not go to the plates")
local k = At().plate
if k then
    Check(ch.frames[k].hot == true, "the plate's map's frame not lit under the pad")
    Check(page.chooseLit ~= nil, "the plate's rows not lit under the pad")
end
Eq(Legend().PAD2, L["Back to the list"], "B's prompt on the plates with the ticklist open")
for _ = 1, 6 do
    if At().group == "choose" then break end
    Press("PADDLEFT")
end
Eq(At().group, "choose", "left from the plates did not come back to the list")
Eq(At().key, fightKey, "back on another row than the one it left")
for n, f in ipairs(ch.frames) do
    Check((f.hot == true) == (n == Choice().card.plate), "a frame lit but the row's map's after the plates")
end
Press("PADDRIGHT")
Press("PAD2")
Eq(At().group, "choose", "B on a plate not back on the list")
Eq(At().key, fightKey, "B on a plate not back on its row")

--------------------------------------------------------------------------
Section("B: back to the link, then as before")

Check(not Press("PAD2"), "B went on to the game")
Check(not page.choosing and not ch:IsShown(), "B did not leave the ticklist")
Check(page.entries:IsShown(), "B did not give the left page back")
Eq(At().group, "left", "B not back on the left page")
Eq(At().key, "choose", "B not back on the link")
Eq(page.chooser.list.rows[1].ringAt, nil, "something left ringed")
for i = 1, page.layout do Eq(page.plates[i].ringAt, nil, "a ring left on a plate") end

-- A again opens it; Done leaves it the same way.
Press("PAD1")
Check(page.choosing, "setup: open again")
OnKey("done")
Check(not Press("PAD1"), "A on Done went on to the game")
Check(not page.choosing, "A on Done did not leave the ticklist")
Eq(At().key, "choose", "Done not back on the link")
Check(not Red(ch.done.label), "Done's words left red")

-- B on the left page closes the book, as before.
Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
Eq(Scope().key, "yourdiary", "setup: the page's scope again")

--------------------------------------------------------------------------
Section("the ribbons turn the page: the ticklist closes as with the mouse")

Walk(function(at) return at.key == "choose" end, "left")
Press("PAD1")
Check(page.choosing, "setup: open")
Check(not Press("PADRSHOULDER"), "RB went on to the game")
Check(not ns.UI.JournalShowing("journey"), "RB did not turn the page")
Check(not Press("PADLSHOULDER"), "LB went on to the game")
Check(ns.UI.JournalShowing("journey"), "LB did not turn back to Your Diary")
-- (as with the mouse: the page turned to again falls open, the left page
-- given back)
Check(not page.choosing and not page.chooser:IsShown(), "the ticklist open after the ribbons")
Eq(Scope().key, "yourdiary", "setup: the page's scope again")

--------------------------------------------------------------------------
Section("Y on a plate: the mouse's menu on the pad's slip, the same lines")

local function Lines(root)
    local out = {}
    for _, e in ipairs(root.children) do if e.text then out[#out + 1] = e.text end end
    return table.concat(out, " | ")
end
Press("PADDDOWN")  -- (the title lets go after a ribbon turn)
local onPlate = Walk(function(at) return at.plate ~= nil and page.plates[at.plate].mapID == 1413 end, "page")
Check(onPlate ~= nil, "setup: the pad on 1413's plate")
local plate = page.plates[onPlate.plate]
Eq(Legend().PAD4, L["Open the menu"], "Y's prompt on a plate with the page's own lines")
mock.contextMenu = nil
Check(not Press("PAD4"), "Y on a plate went on to the game")
Eq(mock.contextMenu, nil, "Y opened Blizzard's menu")
Check(Pad.Menu.IsOpen(), "Y on a plate did not open the pad's menu")
Eq(Scope().key, "menu", "the menu's scope has not the pad")
local padLines = {}
for _, item in ipairs(Items("menu")) do padLines[#padLines + 1] = item.element.text end
local generator = CardSheet.PlaceGenerator(plate, nil)
Eq(table.concat(padLines, " | "), Lines(Pad.Menu.Record(plate.over, generator)), "the pad's lines not the generator's")
-- The mouse's menu: the same generator (it may add "Add custom event..." at the cursor).
mock.contextMenu = nil
MenuUtil.CreateContextMenu(plate.over, generator)
Eq(table.concat(padLines, " | "), Lines(mock.contextMenu), "the mouse's and the pad's lines drift")
Check(table.concat(padLines, " | "):find(L["Leave this place out"], 1, true) ~= nil, "no leave line on the pad's menu")
Check(table.concat(padLines, " | "):find(L["Choose what's on this page..."], 1, true) ~= nil,
    "no choose line on the pad's menu")
-- Its pick does it: "Choose what's on this page...".
Walk(function(at) return at.element.text == L["Choose what's on this page..."] end, "menu")
Press("PAD1")
Check(not Pad.Menu.IsOpen(), "the menu stayed open after a pick")
Check(page.choosing, "the menu's choose line did not open the ticklist")
Eq(At().group, "choose", "the pad not on the ticklist after the menu's line")
-- "Leave this place out", from the ticklist's plates.
Press("PADDRIGHT")
onPlate = Walk(function(at) return at.plate ~= nil and page.plates[at.plate].mapID == 1413 end, "page")
plate = page.plates[onPlate.plate]
Press("PAD4")
padLines = {}
for _, item in ipairs(Items("menu")) do padLines[#padLines + 1] = item.element.text end
Eq(table.concat(padLines, " | "), L["Leave this place out"], "with the ticklist open, only the leave line")
Press("PAD1")
Check(not Pad.Menu.IsOpen(), "the menu stayed open after leaving the place out")
Check(not Shown():find("1413"), "the menu's leave line did not leave the place out")
Eq(Scope().key, "yourdiary", "the page's scope not back after the menu")
local at = At()
Check(at ~= nil and at.group == "page", "the pad not back on the plates")
if at.plate then
    YD.Glide.Finish()
    Check(page.plates[at.plate]:IsShown() and page.plates[at.plate].mapID ~= 1413, "the look on a stale plate")
end
local zoneRow
for _, item in ipairs(page.chooser.list.data) do
    if item.zone and item.zone.mapID == 1413 then zoneRow = item end
end
Eq(zoneRow.row.look, "out", "the ticklist not filled after the menu's leave line")
-- Only add where the menu would hold no line of the page's: straight to the picker.
Reset()
Press("PAD2")

--------------------------------------------------------------------------
Section("Y on a person's strip: their menu on the pad's slip")

YD.Unchoose()
ns.UI.RefreshJourneyPage(false)
local function PersonStrip()
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() and strip.guid == FOE then return strip end
    end
end
local strip = PersonStrip()
Check(strip ~= nil and strip.rightMenu == true, "setup: their strip with its menu")
local onStrip = Walk(function(at) return at.note == strip end, "page")
Check(onStrip ~= nil, "setup: the pad on their strip")
Eq(Legend().PAD4, L["Open the menu"], "Y's prompt on a person's strip")
mock.contextMenu = nil
Check(not Press("PAD4"), "Y on a strip went on to the game")
Eq(mock.contextMenu, nil, "Y on a strip opened Blizzard's menu")
Check(Pad.Menu.IsOpen(), "Y on a strip did not open the pad's menu")
local leaveHer = ns.Fmt(L["Leave %1$s off this page"], "Wrenna")
padLines = {}
for _, item in ipairs(Items("menu")) do padLines[#padLines + 1] = item.element.text end
Eq(table.concat(padLines, " | "), leaveHer, "their menu's line")
mock.contextMenu = nil
strip.onRight()
Eq(Lines(mock.contextMenu), leaveHer, "the mouse's menu on their strip drifts from the pad's")
Press("PAD1")
Check(not Pad.Menu.IsOpen(), "the menu stayed open")
Eq(PersonStrip(), nil, "their strip still on the page")
local theirs = 0
for k2, v in pairs(j.chosen or {}) do
    if k2:find(FOE, 1, true) then
        Eq(v, "out", "left off: not out")
        theirs = theirs + 1
    end
end
Check(theirs > 0, "nothing written for them")
-- The way back is the ticklist's, with the pad.
YD.Choose()
OnKey(fightKey)
Eq(Legend().PAD1, L["Bring it in"], "their row not offered back")
Press("PAD1")
Eq(j.chosen[fightKey:sub(5)], "keep", "A did not bring them back")
Reset()

--------------------------------------------------------------------------
Section("combat: the catcher off, the look away; back after")

YD.Choose()
OnKey(fightKey)
mock.fire("PLAYER_REGEN_DISABLED")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on in combat")
Check(not parts.pen:IsShown(), "the look left up in combat")
Check(page.choosing, "combat closed the ticklist")
mock.fire("PLAYER_REGEN_ENABLED")
Check(catcher:IsGamePadButtonEnabled(), "the catcher not back after combat")
Eq(At().key, fightKey, "the pad not back on its row after combat")

--------------------------------------------------------------------------
Section("the mouse taking over gives every colour back")

-- A row left out (struck, faded) and a kept one (a red tick in a red box).
OnKey(fightKey)
Press("PAD1")                 -- (left out: struck)
OnKey("zone:1411")
Press("PAD1")                 -- (kept: a red tick)
local function Ink(key)
    local row = RowFor(key)
    local box = row.item.card and row.cardBox or row.placeBox
    return { name = Colour(row.name), time = Colour(row.time), strike = row.strike:IsShown(),
        strikeInk = row.strike.recorded and row.strike.recorded.calls.SetColorTexture,
        tick = box.tick[1]:IsShown(), tickRed = IsRed(unpack(box.tick[1].recorded.calls.SetColorTexture)),
        cross = box.cross[1]:IsShown() }
end
-- Their ink with the pad elsewhere (on Done), as the mouse would see them.
OnKey("done")
local struck, kept = Ink(fightKey), Ink("zone:1411")
Check(struck.strike and struck.cross, "setup: the row struck and crossed")
Check(kept.tick and kept.tickRed, "setup: the zone a red tick")
OnKey(fightKey)
Check(Red(RowFor(fightKey).name), "setup: the struck row red under the pad")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(page.choosing, "the mouse closed the ticklist")
local after = Ink(fightKey)
Check(SameColour(after.name, struck.name), "the struck row's words not given back their faded ink")
Check(SameColour(after.time, struck.time), "the struck row's time not given back")
Check(after.strike and after.cross, "the strike or the cross lost")
Check(not Red(RowFor(fightKey).name), "a row left red")
Check(not parts.pen:IsShown(), "the pen's box left with the mouse")
Check(not GameTooltip.shown, "the tooltip left with the mouse")
for i = 1, page.layout do Eq(page.plates[i].ringAt, nil, "a ring left with the mouse") end
for _, f in ipairs(ch.frames) do Check(not f.hot, "a frame left lit with the mouse") end
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad back")
Check(page.choosing, "picking the pad up closed the ticklist")
Eq(At().group, "choose", "the pad not on the ticklist")
OnKey("zone:1411")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
local keptAfter = Ink("zone:1411")
Check(SameColour(keptAfter.name, kept.name), "the kept zone's words not given back")
Check(keptAfter.tick and keptAfter.tickRed, "the red tick not back")
Check(not Red(RowFor("zone:1411").name), "the kept zone left red")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Reset()

--------------------------------------------------------------------------
Section("no item clicked: A on a row is its tick alone")

do
    local modified = 0
    local was, wasMod = _G.HandleModifiedItemClick, _G.IsModifiedClick
    _G.HandleModifiedItemClick = function() modified = modified + 1 return true end
    _G.IsModifiedClick = function() return true end
    mock.keysDown.LCTRL = true
    OnKey(fightKey)
    Press("PAD1")
    Press("PAD1")
    Eq(modified, 0, "A on a row made a modified click")
    mock.keysDown.LCTRL = nil
    _G.HandleModifiedItemClick, _G.IsModifiedClick = was, wasMod
end
Reset()

--------------------------------------------------------------------------
Section("with the Gamepad UI off, nothing enabled; the mouse's ticklist as it was")

YD.Unchoose()
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
Pad.Refresh()
Check(not Pad.Input.Active(), "the pad in hand with the Gamepad UI off")
YD.Choose()
Check(page.choosing, "the ticklist not opened with the mouse")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on with the Gamepad UI off")
Check(not parts.pen:IsShown(), "the look drawn with the Gamepad UI off")
Check(Press("PAD1"), "a press taken with the Gamepad UI off")
YD.Unchoose()
