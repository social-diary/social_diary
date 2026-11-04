-- The hints' slip (UI/Paper/HintSlip.lua) and the watcher that lays it on
-- a drawn book (UI/Journal/Hints.lua), and HNT-10's two settings. The
-- gates themselves are tests/hints.lua's.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Slip = ns.UI.HintSlip
local SLIP, PLACE, ARRIVE = Slip.SLIP, Slip.PLACE, Slip.ARRIVE
local HINT = tostring(SOUNDKIT.IG_QUEST_LIST_OPEN)

local function Heard()
    local ids = {}
    for _, sound in ipairs(mock.sounds) do ids[#ids + 1] = tostring(sound[1]) end
    mock.sounds = {}
    return table.concat(ids, ",")
end

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local BOOK = ns.UI.Journal.BOOK
local journey = book.views.journey

--------------------------------------------------------------------------
Section("the sound is its own")

local hint = ns.Style.SOUNDS.hint
Check(hint and hint[1], "no hint sound")
for _, other in ipairs({ "pageTurn", "sheetOpen" }) do
    Check(ns.Style.SOUNDS[other][1] ~= hint[1], "the hint sounds as " .. other)
end

--------------------------------------------------------------------------
Section("Show lays a slip on the page's container, with its sound")

Check(not Slip.Shown(), "a slip out before any hint")
Heard()
local gone, linked = 0, 0
local function Gone() gone = gone + 1; Slip.Hide() end
Slip.Show(journey, "journey", { title = "Something missing?", body = "Right-Click the map to add events yourself." },
    Gone)
local slip = Slip.Frame()
Check(Slip.Shown(), "no slip shown")
Eq(slip.container, journey, "not on the page's container")
Eq(Heard(), HINT, "not laid with the hint's sound, alone")
Eq(slip.title:GetText(), "SOMETHING MISSING?", "its title, as a rubric")
local said = {}
for _, line in ipairs(slip.lines) do
    if line:IsShown() then said[#said + 1] = line:GetText() end
end
Eq(table.concat(said, " "), "Right-Click the map to add events yourself.", "its words, in order")
Check(#said >= 2, "the words not wrapped to the slip's width")
Check(not slip.link:IsShown(), "a link where it has none")
Eq(slip.view.sheet.recorded.width, SLIP.w, "its width")
Eq(slip.view.sheet.recorded.height, slip.h, "its height not its words'")
Check(slip:GetFrameLevel() > journey:GetFrameLevel(), "under the page")

--------------------------------------------------------------------------
Section("it does not cover the page or take what is beside it")

-- Its frame is the slip's size, anchored once, not the book's.
local points = slip.recorded.points
Eq(#points, 1, "anchored more than once (stretched over the book?)")
Eq(points[1].point, "TOPLEFT", "its anchor")
Eq(slip.recorded.width, SLIP.w, "its frame wider than the slip")
Eq(slip.recorded.height, slip.h, "its frame taller than the slip")
-- Settled, it lies past the right page's working area (the plates, the
-- profile: RIGHT_X to RIGHT_X + RIGHT_W), below the index tabs, on the book.
mock.sounds = {}
slip.scripts.OnUpdate(slip, ARRIVE.time)
Check(slip.scripts.OnUpdate == nil, "the arrival did not stop itself")
local args = slip.recorded.points[1].args
local x, y = args[3], -args[4]
Eq(args[1], journey, "not placed on the container")
Check(x >= BOOK.RIGHT_X + BOOK.RIGHT_W, "over the right page's working area: x " .. x)
Check(x < BOOK.BOOK_W, "not on the book's edge at all: x " .. x)
Check(y >= 200, "up among the index tabs: y " .. y)
Check(y + slip.h <= BOOK.BOOK_H, "past the book's foot")
Eq(x, BOOK.BOOK_W - PLACE.journey.tuck, "not where Your Diary's slip lies")
Eq(slip:GetAlpha(), 1, "not fully there once settled")
-- Clicks only: the wheel goes through to the page.
for _, frame in ipairs({ slip, slip.view, slip.view.sheet }) do
    local wheel = frame.recorded.calls.EnableMouseWheel
    Check(not (wheel and wheel[1]), "it takes the wheel")
end
Eq(slip.view.recorded.points[1].args[1], slip, "the click-catcher covers more than the slip")

-- A book near the screen's right edge: it comes in over the page, never off it.
journey.right, UIParent.right = 900, 1000
Slip.Show(journey, "journey", { title = "T", body = "Words." }, Gone)
slip.scripts.OnUpdate(slip, ARRIVE.time)
local inside = slip.recorded.points[1].args[3]
Eq(inside, x - (900 - PLACE.journey.tuck + SLIP.w + 8 - 1000), "not kept on the screen")
journey.right, UIParent.right = nil, nil

--------------------------------------------------------------------------
Section("it comes in, not in place")

Slip.Show(journey, "journey", { title = "T", body = "Words." }, Gone)
local first = slip.recorded.points[1].args
Check(first[3] > x, "it starts where it lies, not out to the right")
Check(slip:GetAlpha() < 0.1, "it starts fully there")
slip.scripts.OnUpdate(slip, ARRIVE.time / 2)
local mid = slip.recorded.points[1].args
Check(mid[3] > x and mid[3] < first[3], "it does not move in")
slip.scripts.OnUpdate(slip, ARRIVE.time)
Eq(slip.recorded.points[1].args[3], x, "it does not come to rest")
-- Laid flat: straight, and only fading in.
ns.SetSetting("flatSheets", true)
Slip.Show(journey, "journey", { title = "T", body = "Words." }, Gone)
Eq(slip.recorded.points[1].args[3], x, "laid flat, it still slides")
Eq(slip.view.angle, 0, "laid flat, it is turned")
ns.SetSetting("flatSheets", false)
slip.scripts.OnUpdate(slip, ARRIVE.time)

--------------------------------------------------------------------------
Section("Hide takes it away, and again does nothing")

gone = 0
Heard()
Slip.Hide()
Check(not Slip.Shown(), "still out")
Slip.Hide()
Check(not Slip.Shown(), "out again")
Eq(gone, 0, "Hide counts as the player putting it away")
Eq(Heard(), "", "it made a sound going")

--------------------------------------------------------------------------
Section("a click on it puts it away")

Slip.Show(journey, "journey", { title = "T", body = "Words." }, Gone)
slip.view.sheet.scripts.OnMouseUp(slip.view.sheet, "LeftButton")
Eq(gone, 1, "the click did not call onGone")
Check(not Slip.Shown(), "the click left it out")
-- An onGone that does not hide it: it goes all the same, called once.
Slip.Show(journey, "journey", { title = "T", body = "Words." }, function() gone = gone + 1 end)
slip.view.scripts.OnMouseDown(slip.view, "LeftButton")
Eq(gone, 2, "a click on its corner did not call onGone")
Check(not Slip.Shown(), "the corner's click left it out")

--------------------------------------------------------------------------
Section("its link does what it says and puts it away")

ns.UI.SetJournalView("people")
Slip.Show(book.views.people, "people", { title = "Quickly Add Notes", body = "Assign a hotkey to add a note quickly.",
    link = "Go to Settings", onLink = function() linked = linked + 1 end }, Gone)
Eq(slip.container, book.views.people, "not moved to the People page")
Check(slip.link:IsShown(), "no link")
Eq(slip.link:GetText(), "Go to Settings", "its link's words")
slip.link:Click()
Eq(linked, 1, "the link did not run")
Eq(gone, 3, "the link did not put it away")
Check(not Slip.Shown(), "the link left it out")

--------------------------------------------------------------------------
Section("the watcher lays the due hint after five seconds on the page")

local Hints, HintsUI = ns.Hints, ns.UI.Hints
local S = ns.HintState()
local function Open()
    wipe(S.seen)
    wipe(S.retired)
    S.sittingFrom, S.sittingShown = mock.now - 3600, 0
    S.lastShown, S.played, S.opens = nil, 10 * 3600, 10
    ns.SetSetting("showHints", true)
end
Open()
ns.UI.SetJournalView("journey")
Heard()
HintsUI.Look(100)
Check(not Slip.Shown(), "laid as the page came")
HintsUI.Look(100 + Hints.DWELL - 1)
Check(not Slip.Shown(), "laid before five seconds")
HintsUI.Look(100 + Hints.DWELL)
Check(Slip.Shown(), "not laid after five seconds")
Eq(slip.container, journey, "not on Your Diary")
Check(S.seen["custom-events"] ~= nil, "not marked seen as it was laid")
Eq(HintsUI.Showing() and HintsUI.Showing().id, "custom-events", "the watcher does not know it is out")
Eq(slip.title:GetText(), "SOMETHING MISSING?", "not the custom-events hint")
Eq(Heard(), HINT, "not laid with its sound")
-- Put away by the player: the watcher lets it go, and it does not come back.
slip.view.sheet.scripts.OnMouseUp(slip.view.sheet, "LeftButton")
Check(not Slip.Shown(), "the click left it out")
Eq(HintsUI.Showing(), nil, "the watcher still holds it")
HintsUI.Look(200)
HintsUI.Look(300)
Check(not Slip.Shown(), "it came back")
-- Turning the page takes it with it.
Open()
HintsUI.Look(400)
HintsUI.Look(400 + Hints.DWELL)
Check(Slip.Shown(), "not laid again after Show hints again")
ns.UI.SetJournalView("people")
HintsUI.Look(401 + Hints.DWELL)
Check(not Slip.Shown(), "it stayed as the page turned")
ns.UI.SetJournalView("journey")

--------------------------------------------------------------------------
Section("HNT-10: Show hints, and Show hints again")

ns.UI.ShowSettings("interface")
local P = ns.UI.SettingsPage()
Eq(P.showHints.parent, P.panes.interface, "Show hints is not on the Interface page")
Check(P.showHints.hint and P.showHints.hint:GetText():find("Applies to every character.", 1, true),
    "the account setting does not say so")
Check(P.showHints:GetChecked(), "Show hints not ticked to begin with")
P.showHints:Click()
Eq(ns.Setting("showHints"), false, "the switch did not turn it off")
Eq(SocialDiaryDB.settings.showHints, false, "not in the account file")
Eq(SocialDiaryCharDB.settings.showHints, nil, "in the character's file")
Check(not Hints.Open(), "a hint may still come with them off")
P.showHints:Click()
Eq(ns.Setting("showHints"), true, "the switch did not turn it on again")

S.seen["custom-events"], S.seen["remember-bind"], S.lastShown = 1, 2, S.played
Eq(P.hintsAgain.parent, P.panes.interface, "Show hints again is not on the Interface page")
P.hintsAgain:Click()
Check(next(S.seen) == nil, "the hints seen were kept")
Eq(S.lastShown, nil, "the cooldown was kept")
