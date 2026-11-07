-- The introduction, the hints and the reunion toast with the pad
-- (.claude/controller-plan.md, step 7b; UI/Windows/Intro/Pad.lua,
-- UI/Journal/HintPad.lua, UI/Windows/Reunion/Pad.lua): the parcel at login
-- takes nothing, opened by the player it is walked and B puts it away; the
-- tour's steps walked, B puts the sheet away and Your Diary has the pad
-- again; the example's strip; a hint's slip joined at the page's edge,
-- never moving the pad, A and B; a toast never taking the pad, its frames
-- never taking a button; placing the toast from Settings with the pad; and
-- the mouse taking over.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Tour = ns.UI.Tour
local Toast = ns.UI.Toast

for i = 1, 12 do
    local guid = ("Player-0000-%08X"):format(0xB0000 + i)
    ns.Characters.Observe(guid, { first = ("Introwalker%02d"):format(i), level = 10 + i % 7, faction = "Horde" })
    ns.Diary.Add(guid, { source = "test" })
end

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad not in hand")

local function Press(catcher, key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Top() return Pad.Top() and Pad.Top().key end
local function At() return Pad.Top() and Pad.Top().focus:Current() end
local function Prompts()
    local out = {}
    for _, e in ipairs(Pad.Top() and Pad.Legend(Pad.Top()) or {}) do
        local key = type(e[1]) == "table" and e[1][1] or e[1]
        if out[key] == nil then out[key] = e[2] end
    end
    return out
end
-- The mock starts every frame hidden; the client starts it shown.
local function Wake(root)
    for _, child in ipairs({ root:GetChildren() }) do
        if child.recorded and child.recorded.toldShown == nil then child.shown = true end
        Wake(child)
    end
end
-- Any frame under root taking the pad's buttons or sticks.
local function Taking(root)
    if root:IsGamePadButtonEnabled() or root:IsGamePadStickEnabled() then return true end
    for _, child in ipairs({ root:GetChildren() }) do
        if Taking(child) then return true end
    end
    return false
end
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

--------------------------------------------------------------------------
Section("the parcel at login takes nothing")

ns.db.settings.introSeen = false
ns.db.settings.parcelOpened = false
mock.timers = {}
mock.fire("PLAYER_LOGIN")
mock.RunTimers()
-- (the look at login put the pad down: in hand again)
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad not in hand at login")
local slip = ns.UI.Slip()
Check(slip and slip:IsShown(), "setup: no parcel at login")
Pad.Refresh()
Eq(Top(), nil, "the parcel at login took the pad")
local pc = Pad.Catcher(slip)
Check(not pc:IsGamePadButtonEnabled(), "the parcel's catcher on at login")
Check(not Taking(slip), "a frame of the parcel takes the pad's buttons at login")
Eq(Press(pc, "PAD1"), true, "A did not go on to the game")

--------------------------------------------------------------------------
Section("the parcel opened by the player: walked, torn, B puts it away")

Wake(slip)
Pad.Opened(slip)
Eq(Top(), "parcel", "the parcel opened by the player has not the pad")
Check(pc:IsGamePadButtonEnabled(), "its catcher not on")
Eq(At().key, "seal", "not on the seal")
Check(At().ring, "the seal not ringed")
Eq(Prompts().PAD1, "Tear it open", "A's prompt on the seal")
Eq(Prompts().PAD2, "Put the parcel away", "B's prompt on the parcel")
Press(pc, "PADDDOWN")
Eq(At().key, "tear", "down from the seal: not Tear it open")
Check(At().plain, "the light link not boxed plain")
Press(pc, "PADDRIGHT")
Eq(At().key, "later", "right from Tear it open: not Later")
Press(pc, "PADDLEFT")
Eq(At().key, "tear", "left from Later: not Tear it open")
Press(pc, "PADDUP")
Eq(At().key, "seal", "up: not back on the seal")
Press(pc, "PAD1")
Eq(slip.state, "torn", "A on the seal did not tear it")
Eq(ns.db.settings.parcelOpened, true, "the tear not kept")
Wake(slip)
Pad.Refresh()
Eq(At().key, "open", "torn: not on Open me")
Check(Red(slip.note.open.label), "Open me not red")
Eq(Prompts().PAD1, "Open the introduction", "A's prompt on Open me")
Press(pc, "PADDDOWN")
Eq(At().key, "notelater", "down from Open me: not Later")
Check(not Red(slip.note.open.label), "Open me left red")
Press(pc, "PAD2")
Check(not slip:IsShown(), "B did not put the parcel away")
Check(ns.UI.Parcel.later, "B not as Later")
Eq(Top(), nil, "the pad not given back after the parcel")
Check(not pc:IsGamePadButtonEnabled(), "the parcel's catcher left on")
Eq(ns.db.settings.introSeen, false, "putting it away counted as seeing it")

-- Shown again by itself (after a fight): nothing again.
ns.UI.Parcel.later = false
ns.UI.OfferSlip()
Check(slip:IsShown(), "setup: the parcel offered again")
Eq(Top(), nil, "offered again by itself, the parcel took the pad")
slip:Hide()

--------------------------------------------------------------------------
Section("the tour: its steps walked, B puts it away, Your Diary has the pad")

ns.db.settings.introSeen = true
ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local bc = Pad.Catcher(book)
Pad.Refresh()
local under = Top()
Check(under ~= nil and under ~= "tour", "setup: no scope on Your Diary")
local underAt = At() and At().key
ns.UI.ShowIntro()
Tour.Finish()
Wake(Tour.host)
Pad.Refresh()
Eq(Top(), "tour", "the tour's sheet has not the pad")
Check(bc:IsGamePadButtonEnabled(), "the book's catcher not on under the tour")
Eq(At().key, "continue", "step 1 not on Continue")
Check(Red(Tour.strips.step.foot.label), "Continue not red")
Eq(Prompts().PAD1, "Continue", "A's prompt on Continue")
Eq(Prompts().PAD2, "Put the introduction away", "B's prompt on the tour")
Eq(Prompts().PADLSHOULDER, "Turn the page", "the shoulders not the book's under the tour")
Press(bc, "PAD1")
Tour.Finish()
Eq(Tour.step, 2, "A on Continue did not go on")
Wake(Tour.host)
Pad.Refresh()
Eq(At().key, "continue", "step 2 not on Continue")
Press(bc, "PADDUP")
Eq(At().key, "mark:1", "up from Continue: not the first step's mark")
Check(At().ring, "the mark not ringed")
Eq(Prompts().PAD1, "Back to this step", "A's prompt on a mark")
Press(bc, "PAD1")
Tour.Finish()
Eq(Tour.step, 1, "A on the mark did not go back")
Wake(Tour.host)
Pad.Refresh()
-- On to step 4 and 5 with A alone.
for _ = 1, 3 do
    Eq(At().key, "continue", "a step before 4 not on Continue")
    Press(bc, "PAD1")
    Tour.Finish()
    Wake(Tour.host)
    Pad.Refresh()
end
Eq(Tour.step, 4, "A did not reach step 4")
Eq(At().key, "add", "step 4 not on + Add")
Eq(Prompts().PAD1, "Add Thex", "A's prompt on + Add")
Press(bc, "PAD1")
Tour.Finish()
Wake(Tour.host)
Pad.Refresh()
Eq(Tour.step, 5, "A on + Add did not go on")
Eq(At().key, "thex", "step 5 not on Thex")
Check(Red(Tour.strips.thex.name), "Thex's name not red")

-- B: the sheet put away, seen, the book open, Your Diary's scope back.
Press(bc, "PAD2")
Eq(Tour.step, nil, "B did not put the sheet away")
Check(book:IsShown(), "B on the tour closed the book")
Eq(ns.db.settings.introSeen, true, "put away, not seen")
Eq(Top(), under, "Your Diary's scope not back after the tour")
Eq(At() and At().key, underAt, "Your Diary's pad not back where it was")
Check(not Red(Tour.strips.thex.name), "Thex's name left red")

--------------------------------------------------------------------------
Section("the example: A on Thex lands on its strip; A begins")

ns.UI.ShowIntro()
Tour.Finish()
while Tour.step < 5 do
    Wake(Tour.host)
    Pad.Refresh()
    Press(bc, "PAD1")
    Tour.Finish()
end
Wake(Tour.host)
Pad.Refresh()
Eq(At().key, "thex", "setup: not on Thex")
Press(bc, "PAD1")
Check(Tour.example ~= nil, "A on Thex did not lay the example")
Eq(J.view, "people", "the example not on People")
Wake(book)
Pad.Refresh()
Eq(Top(), "people", "the People scope has not the pad in the example")
Eq(At() and At().key, "example", "A on Thex did not land on the example's strip")
Eq(Prompts().PAD1, "Begin your own diary", "A's prompt on the example")
Eq(Prompts().PAD2, "Back to the page", "B's prompt on the example")
Eq(Press(bc, "PAD3"), true, "the page's X taken on the example's strip")
Press(bc, "PAD2")
Check(At() and At().key ~= "example", "B on the example did not go back to the page")
Check(Tour.example ~= nil, "B on the example left it")
local from = At().group
Pad.Refresh()
-- Right off the edge of the page reaches it again.
local f = Pad.Top().focus
Check(f:EnterGroup("example"), "the example not in the page's focus")
Press(bc, "PADDLEFT")
Eq(At().group, from, "left from the example not back where it came from")
Check(f:EnterGroup("example"), "setup: onto the example again")
Press(bc, "PAD1")
Eq(Tour.example, nil, "A on the example did not begin")
Eq(J.view, "journey", "beginning did not turn to Your Diary")
Pad.Refresh()
Check(not (At() and At().key == "example"), "the pad left on the example")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a hint's slip: joined at the edge, never moving the pad")

local HintSlip = ns.UI.HintSlip
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
Wake(book)
Pad.Refresh()
Eq(Top(), "people", "setup: the People scope")
Press(bc, "PADDDOWN")
Press(bc, "PADDDOWN")
local before = At().key
local gone = 0
HintSlip.Show(book.views.people, "people", { title = "Quickly Add Notes", body = "Assign a hotkey.",
    link = "Go to Settings", onLink = function() ns.UI.ShowSettings("shortcuts") end },
    function() gone = gone + 1; HintSlip.Hide() end)
local hs = HintSlip.Frame()
Wake(hs)
Pad.Refresh()
Eq(At().key, before, "the slip moved the pad")
local item
for _, it in ipairs(Pad.Top().focus.groups.hint and Pad.Top().focus.groups.hint.items or {}) do item = it end
Check(item ~= nil, "the slip not joined to the page's focus")
Check(item.outline and #item.outline().corners == 4, "the slip not outlined by its four corners")
-- Walked to: right off the page's edge.
local walked = false
for _ = 1, 6 do
    Press(bc, "PADDRIGHT")
    if At().key == "hint" then walked = true break end
end
Check(walked, "right off the page's edge did not reach the slip")
Eq(Prompts().PAD1, "Go to Settings", "A's prompt on a slip with a link")
Eq(Prompts().PAD2, "Put the hint away", "B's prompt on the slip")
Eq(Prompts().PADLSHOULDER, "Turn the page", "the shoulders not the book's on the slip")
local came = Pad.Top().focus.from
Press(bc, "PADDLEFT")
Eq(At().group, came, "left from the slip not back where the pad came from")
Pad.Top().focus:EnterGroup("hint")
Press(bc, "PAD2")
Check(not HintSlip.Shown(), "B did not put the slip away")
Eq(gone, 1, "B not as a click on it")
Eq(At().group, came, "B on the slip: the pad not back where it came from")
Pad.Refresh()
Check(Pad.Top().focus.groups.hint == nil or #Pad.Top().focus.groups.hint.items == 0, "the slip left in the focus")

-- A follows its link.
HintSlip.Show(book.views.people, "people", { title = "Quickly Add Notes", body = "Assign a hotkey.",
    link = "Go to Settings", onLink = function() ns.UI.ShowSettings("shortcuts") end },
    function() HintSlip.Hide() end)
Wake(hs)
Pad.Refresh()
Pad.Top().focus:EnterGroup("hint")
Eq(At().key, "hint", "setup: onto the slip")
Press(bc, "PAD1")
Check(not HintSlip.Shown(), "A on the link left the slip out")
Eq(J.view, "settings", "A on the slip did not follow its link")

-- No link: A puts it away.
ns.UI.SetJournalView("people")
Wake(book)
Pad.Refresh()
HintSlip.Show(book.views.people, "people", { title = "Something", body = "Words." }, function() HintSlip.Hide() end)
Wake(hs)
Pad.Refresh()
Pad.Top().focus:EnterGroup("hint")
Eq(Prompts().PAD1, "Put the hint away", "A's prompt on a slip without a link")
Press(bc, "PAD1")
Check(not HintSlip.Shown(), "A did not put the slip away")
Check(book:IsShown(), "A on the slip closed the book")

-- The watcher laying one tells the pad.
local Hints, HintsUI = ns.Hints, ns.UI.Hints
local S = ns.HintState()
wipe(S.seen)
wipe(S.retired)
S.sittingFrom, S.sittingShown = mock.now - 3600, 0
S.lastShown, S.played, S.opens = nil, 10 * 3600, 10
ns.SetSetting("showHints", true)
ns.UI.SetJournalView("journey")
Wake(book)
Pad.Refresh()
local journeyAt = At() and At().key
HintsUI.Look(1000)
HintsUI.Look(1000 + Hints.DWELL)
Check(HintSlip.Shown(), "setup: the watcher laid no slip")
Eq(At() and At().key, journeyAt, "a slip laid by the watcher moved the pad")
ns.UI.SetJournalView("people")
HintsUI.Look(1001 + Hints.DWELL)
Check(not HintSlip.Shown(), "setup: the slip stayed as the page turned")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a reunion toast never takes the pad")

local A = ("Player-0000-%08X"):format(0xB0001)
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A)
local toast = Toast.toast
Check(toast and toast:IsShown(), "setup: no toast")
Wake(toast)
Pad.Refresh()
Eq(Top(), nil, "the toast took the pad over the game")
Check(not Taking(toast), "a frame of the toast takes the pad's buttons")
Eq(Press(Pad.Catcher(toast), "PAD1"), true, "A on the toast did not go on to the game")
-- With the book open, the book keeps it.
ns.UI.ShowJournal()
Pad.Refresh()
Check(Top() ~= nil and Top() ~= "toastplace", "the toast took the pad from the book")
Check(not Taking(toast), "a frame of the toast takes buttons with the book open")
ns.UI.CloseJournal()
-- Placing from Edit Mode (not the player's through us): nothing.
Toast.Dismiss()
for _ = 1, 20 do mock.RunTimers() end
ns.UI.PlaceToast()
Pad.Refresh()
Eq(Top(), nil, "placing from Edit Mode took the pad")
Check(not Taking(toast), "placing from Edit Mode: a frame takes buttons")
Toast.StopPlacing()

--------------------------------------------------------------------------
Section("placing the toast from Settings: the pad moves it")

local settings = ns.UI.SettingsPage()
ns.UI.ShowSettings()
ns.db.settings.toastAt = nil
settings.moveToast:Click()
Check(ns.UI.PlacingToast(), "setup: not placing")
Wake(toast)
Pad.Refresh()
Eq(Top(), "toastplace", "placing from Settings has not the pad")
local tc = Pad.Catcher(toast)
Check(tc:IsGamePadButtonEnabled(), "the toast's catcher not on while placing")
Eq(At().key, "done", "not on Done")
Eq(Prompts().PAD1, "Done", "A's prompt while placing")
Eq(Prompts().PAD3, "Put it back", "X's prompt while placing")
Press(tc, "PADDRIGHT")
Press(tc, "PADDUP")
local at = ns.db.settings.toastAt
Check(at and at.x == 8 and at.y == -120 + 8, "the D-pad did not move it")
Check(tc:IsGamePadStickEnabled(), "the sticks not on while placing")
Eq(mock.PadStick(tc, "Right", 1, 0), true, "the right stick taken from the camera")
Eq(mock.PadStick(tc, "Left", -1, 0), false, "the left stick not taken")
tc.ticker.scripts.OnUpdate(tc.ticker, 0.1)
Check(ns.db.settings.toastAt.x < 8, "the left stick did not move it")
mock.PadStick(tc, "Left", 0, 0)
Press(tc, "PAD3")
Eq(ns.db.settings.toastAt, nil, "X did not put it back")
Press(tc, "PAD1")
Check(not ns.UI.PlacingToast(), "A did not end placing")
Check(book:IsShown(), "Done did not open the book on Settings again")
Check(not tc:IsGamePadButtonEnabled(), "the toast's catcher left on after placing")
-- B ends it too, as Escape.
settings.moveToast:Click()
Wake(toast)
Pad.Refresh()
Eq(Top(), "toastplace", "setup: placing again")
Press(tc, "PAD2")
Check(not ns.UI.PlacingToast(), "B did not end placing")
-- The next toast over the game takes nothing again.
ns.UI.CloseJournal()
for _ = 1, 20 do mock.RunTimers() end
wipe(ns.db.meta.greeted)
ns.UI.Reunion(A)
Check(toast:IsShown(), "setup: no toast after placing")
Pad.Refresh()
Eq(Top(), nil, "a toast after placing took the pad")
Check(not Taking(toast), "a toast after placing: a frame takes buttons")
Toast.Dismiss()

--------------------------------------------------------------------------
Section("the mouse takes over; a press brings the pad back")

ns.UI.ShowIntro()
Tour.Finish()
Wake(Tour.host)
Pad.Refresh()
Eq(Top(), "tour", "setup: the tour")
local parts = Pad.Look.parts[book]
Check(parts.pen:IsShown(), "setup: Continue not boxed")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not bc:IsGamePadButtonEnabled(), "the book's catcher still on")
Check(not parts.pen:IsShown(), "the box left up")
Check(not Red(Tour.strips.step.foot.label), "Continue left red")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(bc:IsGamePadButtonEnabled(), "the catcher not back on")
Eq(At().key, "continue", "the pad not back on Continue")
Check(parts.pen:IsShown(), "the box not back")
Press(bc, "PAD2")
Eq(Tour.step, nil, "B did not put the tour away")
ns.UI.CloseJournal()
