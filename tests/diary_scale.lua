-- "Diary Size" (Settings > Interface): the setting's default, the scale it
-- gives a window (UI/Kit/Scale.lua: the size chosen, held to what fits the
-- screen, never under 1), the windows following it and going back to their
-- place, the toast kept where it was put at any size, and the slider on
-- the page: written when the mouse lets go, at once from the pad.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Scale = ns.UI.Scale
local Pad = ns.UI.Pad

local function Near(a, b, what)
    Check(type(a) == "number" and math.abs(a - b) < 0.0001,
        ("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)))
end

UIParent.width, UIParent.height = 1920, 1080

--------------------------------------------------------------------------
Section("the setting")

Eq(ns.SettingDefault("diaryScale"), 100, "the default is not the designed size")
Eq(ns.db.settings.diaryScale, 100, "a new account has no size setting")
Check(ns.IsAccountSetting("diaryScale"), "the size is not the account's")
Near(Scale.Chosen(), 1, "the default's scale")
Near(Scale.For(840, 600), 1, "the default does not leave the book as designed")

local book = ns.UI.JournalFrame()
Near(book:GetScale(), 1, "the book's scale at the default")
Eq(book.recorded.calls.SetScale, nil, "the book was given a scale at the default")

--------------------------------------------------------------------------
Section("the size chosen, held to the screen")

ns.SetSetting("diaryScale", 150)
Near(Scale.Chosen(), 1.5, "150% is not 1.5")
Near(Scale.For(840, 600), 1.5, "150% on a large screen")
ns.SetSetting("diaryScale", 200)
Near(Scale.For(840, 600), 1.71, "200% not held to 95% of a 1080 screen's height")

UIParent.width, UIParent.height = 1024, 768
Near(Scale.For(840, 600), 1024 * 0.95 / 840, "not held to a small screen's width")
UIParent.width, UIParent.height = 800, 600
Near(Scale.For(840, 600), 1, "a screen too small for the book shrank it under 1")
ns.SetSetting("diaryScale", 100)
Near(Scale.For(840, 600), 1, "100% on a small screen")

-- Odd values are put on the scale.
ns.SetSetting("diaryScale", 999)
Near(Scale.Chosen(), 2, "not clamped from above")
ns.SetSetting("diaryScale", 40)
Near(Scale.Chosen(), 1, "not clamped from below")
ns.SetSetting("diaryScale", "oops")
Near(Scale.Chosen(), 1, "not a number is not 100%")

-- The screen's size not known yet: the size chosen, as it is.
UIParent.width, UIParent.height = 0, 0
ns.SetSetting("diaryScale", 130)
Near(Scale.For(840, 600), 1.3, "an unknown screen held the size")

--------------------------------------------------------------------------
Section("the windows follow, back to their place")

UIParent.width, UIParent.height = 1920, 1080
ns.SetSetting("diaryScale", 100)
Scale.Apply()
ns.UI.ShowJournal()
book:ClearAllPoints()
book:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -40)   -- (dragged)

ns.SetSetting("diaryScale", 150)
Scale.Apply()
Near(book:GetScale(), 1.5, "the book did not grow")
local at = book.recorded.points[1]
Eq(at and at.point, "CENTER", "the book did not go back to the middle")

-- Not changed, not moved.
book:ClearAllPoints()
book:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -40)
Scale.Apply()
Eq(book.recorded.points[1].point, "TOPLEFT", "a book of the same size was moved")

-- The screen changing holds it to the screen.
UIParent.width, UIParent.height = 1024, 768
mock.fire("DISPLAY_SIZE_CHANGED")
Near(book:GetScale(), 1024 * 0.95 / 840, "the book not fitted to a smaller screen")
UIParent.width, UIParent.height = 1920, 1080
mock.fire("UI_SCALE_CHANGED")
Near(book:GetScale(), 1.5, "the book not grown again on a larger screen")

-- Built later, a window takes the size as it is made.
ns.UI.QuickNote()
local quick = _G.SocialDiaryNoteFrame
Check(quick, "the quick note was not built")
Near(quick:GetScale(), 1.5, "the quick note not at the diary's size")
quick:Hide()

ns.SetSetting("diaryScale", 100)
Scale.Apply()
Near(book:GetScale(), 1, "the book not back to its size")
Near(quick:GetScale(), 1, "the quick note not back to its size")

--------------------------------------------------------------------------
Section("the toast stays where it was put")

Check(ns.UI.PlaceToast(function() end), "placing was refused")
local card = _G.SocialDiaryToastFrame
ns.db.settings.toastAt = { x = 44, y = -264 }
ns.SetSetting("diaryScale", 150)
Scale.Apply()
Near(card:GetScale(), 1.5, "the toast not at the diary's size")
local p = card.recorded.points[1].args
Eq(card.recorded.points[1].point, "TOP", "the toast's anchor")
Near(p[3], 44 / 1.5, "across, not in the card's own units")
Near(p[4], -264 / 1.5, "down, not in the card's own units")

-- Dragged: read back in the card's units, kept in the screen's.
UIParent.at = { 768, 864 }
card.at = { (768 + 100) / 1.5, (864 - 300) / 1.5 }
card.button.scripts.OnDragStart(card.button)
card.button.scripts.OnDragStop(card.button)
Eq(ns.db.settings.toastAt.x, 100, "across, kept not in the screen's units")
Eq(ns.db.settings.toastAt.y, -300, "down, kept not in the screen's units")
p = card.recorded.points[1].args
Near(p[3] * 1.5, 100, "laid again elsewhere across")
Near(p[4] * 1.5, -300, "laid again elsewhere down")

-- Another size: the same place on the screen.
ns.SetSetting("diaryScale", 120)
Scale.Apply()
p = card.recorded.points[1].args
Near(p[3] * card:GetScale(), 100, "a new size moved it across")
Near(p[4] * card:GetScale(), -300, "a new size moved it down")
Eq(ns.db.settings.toastAt.x, 100, "a new size changed where it is kept")
ns.UI.Toast.StopPlacing()
ns.db.settings.toastAt = nil
ns.SetSetting("diaryScale", 100)
Scale.Apply()

--------------------------------------------------------------------------
Section("the slider on the page")

ns.UI.SetJournalView("settings")
local P = ns.UI.SettingsPage()
P.nav.interface:Click()
local row, slider = P.diaryScale, P.diaryScale.slider

Eq(row.label:GetText(), "Diary Size", "the label")
Eq(row.hint and row.hint:GetText(),
    "On a smaller screen, the diary grows only as large as fits. Applies to every character.", "the hint")
local function Y(widget) return widget.recorded.points[1].args[4] end
Check(Y(row) < Y(P.paperGrain), "not under Paper Texture Intensity")
Check(Y(row) > Y(P.bookStack), "not above Simulate Page Turns")
local lo, hi = slider:GetMinMaxValues()
Eq(lo .. "-" .. hi, "100-200", "the range")
Eq(slider.recorded.calls.SetValueStep[1], 10, "the step")
Eq(slider.reading:GetText(), "100%", "the reading")

-- A drag: read out as it goes, written once the mouse lets go.
slider.scripts.OnMouseDown(slider, "LeftButton")
slider:SetValue(140)
slider:SetValue(170)
Eq(slider.reading:GetText(), "170%", "the reading did not follow the drag")
Eq(ns.db.settings.diaryScale, 100, "written under the drag")
Near(book:GetScale(), 1, "the book grew under the drag")
slider.scripts.OnMouseUp(slider, "LeftButton")
Eq(ns.db.settings.diaryScale, 170, "not written when the mouse let go")
Near(book:GetScale(), 1.7, "the book did not grow when the mouse let go")

-- The paper's grain still writes as it goes.
local grain = P.paperGrain.slider
Eq(grain.scripts.OnMouseDown, nil, "the grain's slider waits for the mouse")

--------------------------------------------------------------------------
Section("the pad steps it at once")

local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(P)
P:Refresh()
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end

P:ShowSection("interface")
Pad.Refresh()
Press("PAD1")
for _ = 1, 20 do
    if At().frame == P.diaryScale then break end
    Press("PADDDOWN")
end
Eq(At().frame, P.diaryScale, "the pad never landed on Diary Size")
Eq(At().kind, "slider", "its kind")
Press("PADDRIGHT")
Eq(ns.db.settings.diaryScale, 180, "right did not step it")
Near(book:GetScale(), 1080 * 0.95 / 600, "the book did not follow the pad's step, held to the screen")
Eq(At().frame, P.diaryScale, "the book's new size moved the pad off the slider")
Press("PADDLEFT")
Press("PADDLEFT")
Eq(ns.db.settings.diaryScale, 160, "left did not step it back")
Near(book:GetScale(), 1.6, "the book did not follow back")
