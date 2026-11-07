-- The windows outside the book with the pad (.claude/controller-plan.md,
-- step 7a; UI/Windows/Pad.lua, and the Remember key's note in
-- UI/Journal/NotePad.lua): the entry sheet opened each way takes the pad and
-- gives it back, a line takes the cursor only on A, tags, the removal popup
-- stepping aside, the picker walked, picked and put away, the book and a
-- sheet open together, a window the player did not open taking nothing,
-- and the mouse taking over.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal

local STRANGER = F.STRANGER.guid
local KNOWN = F.GARRICK.guid
mock.SetUnit("target", F.STRANGER)
ns.Characters.ObserveUnit("target")
ns.Characters.Observe(KNOWN, { first = "Garrick", surname = "Stone", level = 20, class = "WARRIOR" })
ns.Diary.Add(KNOWN, { source = "test" })

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad not in hand")

local function Press(catcher, key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Top() return Pad.Top() and Pad.Top().key end
local function At() return Pad.Top() and Pad.Top().focus:Current() end
local function Legend()
    local out = {}
    local s = Pad.Top()
    for _, e in ipairs(s and s.legend and s.legend(s) or {}) do
        local key = type(e[1]) == "table" and e[1][1] or e[1]
        if out[key] == nil then out[key] = e[2] end
    end
    return out
end
local function Find(what)
    local f = Pad.Top().focus
    for _, name in ipairs(f.order) do
        for _, it in ipairs(f.groups[name].items) do
            if it.control == what or it.key == what then return it end
        end
    end
end
local function Onto(what)
    local it = Find(what)
    return it ~= nil and Pad.Top().focus:Focus(it.key, it.group)
end
-- The mock starts every frame hidden; the client starts it shown. Every
-- frame under `root` never told either way is shown, as in the client (as
-- tests/pad_people_edit.lua does).
local function Wake(root)
    for _, child in ipairs({ root:GetChildren() }) do
        if child.recorded and child.recorded.toldShown == nil then child.shown = true end
        Wake(child)
    end
end
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

--------------------------------------------------------------------------
Section("the Remember key on a stranger: the sheet takes the pad, on the note")

Eq(Top(), nil, "a scope has the pad with nothing open")
SocialDiary_Remember()
local sheet = _G.SocialDiaryEntryFrame
local form = sheet.form
Check(sheet:IsShown(), "setup: the key did not open the sheet")
Eq(Top(), "entry", "the sheet's scope has not the pad")
Wake(sheet)
Pad.Scope("entry").opening = nil
Pad.Refresh()
local catcher = Pad.Catcher(sheet)
Check(catcher:IsGamePadButtonEnabled(), "the sheet's catcher not on")
Eq(At().control, form.note, "the pad not on the note")
Check(not form.note:HasFocus(), "the note took the cursor with the pad in hand")
local parts = Pad.Look.parts[sheet]
Check(parts and parts.pen:IsShown(), "the note not boxed")
Check(Red(form.noteLabel), "NOTE not red over it")
Eq(Legend().PAD1, "Write", "A's prompt on the note")
Eq(Legend().PAD2, "Put the page away", "B's prompt on the sheet")

Press(catcher, "PAD1")
Check(form.note:HasFocus(), "A did not give the note the cursor")
Eq(Legend().PAD1, "Done writing", "A's prompt while writing")
Eq(Legend().PAD2, "Stop writing", "B's prompt while writing")
form.note:SetText("helped with the boar")
Press(catcher, "PAD2")
Check(not form.note:HasFocus(), "B did not stop writing")
Check(sheet:IsShown(), "B while writing put the sheet away")

-- Walk up to the tags: the first tag boxed, its colours its own.
Press(catcher, "PADDUP")
Eq(At().control, form.relationship, "up from the note not the relationship")
Check(Red(form.relLabel), "RELATIONSHIP not red over it")
Check(not Red(form.noteLabel), "NOTE left red")
Check(Onto(form.chips[1]), "setup: onto the first tag")
Eq(At().kind, "chip", "the first control not a tag")
local tag = form.chips[1].tag
Eq(Legend().PAD1, "Add the tag", "A's prompt on a tag that is off")
Press(catcher, "PAD1")
Check(form.store.HasTag(form.guid, tag), "A did not put the tag on the draft")
Eq(At().key, "tag:" .. tag, "the pad left the tag")
Eq(Legend().PAD1, "Take the tag off", "A's prompt on a tag that is on")
Press(catcher, "PAD1")
Check(not form.store.HasTag(form.guid, tag), "A did not take the tag off")
Check(Find(form.done) and Find(form.remove), "Done and Cancel not found")
Eq(Find(form.remove).kind, "link", "Cancel not a link")

-- B puts it away as its close does: a draft adds nobody; the pad given back.
Press(catcher, "PAD2")
Check(not sheet:IsShown(), "B did not put the sheet away")
Eq(ns.Diary.IsDiary(STRANGER), false, "putting a draft away added them")
Eq(Top(), nil, "a scope kept the pad after the sheet went")
Check(not catcher:IsGamePadButtonEnabled(), "the sheet's catcher left on")
Check(not parts.pen:IsShown(), "the box left up")

--------------------------------------------------------------------------
Section("Done with the pad adds them")

ns.UI.Remember(STRANGER, { unit = "target", source = "test" })
Eq(Top(), "entry", "Remember again: not the sheet's scope")
Eq(At().control, form.note, "a new opening not on the note")
Check(Onto(form.done), "setup: onto Done")
Eq(Legend().PAD1, "Choose", "A's prompt on Done")
Press(catcher, "PAD1")
Check(not sheet:IsShown(), "A on Done did not close the sheet")
Eq(ns.Diary.IsDiary(STRANGER), true, "A on Done did not add them")
Eq(Top(), nil, "the pad not given back after Done")

--------------------------------------------------------------------------
Section("a menu's 'open entry', the book shut: on the first tag; Remove asks")

ns.UI.ShowEntry(KNOWN)
Eq(Top(), "entry", "the entry sheet's scope has not the pad")
Eq(At().kind, "chip", "an entry opened not on the first tag")
Check(not form.note:HasFocus(), "the note took the cursor")
Check(Onto(form.remove), "setup: onto Remove")
local popups = #mock.popups
Press(catcher, "PAD1")
Eq(#mock.popups, popups + 1, "A on Remove did not ask")
local dialog = StaticPopupDialogs.SOCIAL_DIARY_REMOVE
local popup = {}
dialog.OnShow(popup)
Check(Pad.Top() == nil, "a scope has the pad with the popup up")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher takes buttons from the popup")
dialog.OnHide(popup)
Eq(Top(), "entry", "the pad not back on the sheet after the popup")
Eq(At().control, form.remove, "the pad not back on Remove")
Check(ns.Diary.Get(KNOWN) ~= nil, "cancelled, and they went")

-- Opened for the note (the quick add of someone in the diary): on the note.
ns.UI.ShowEntry(KNOWN, true)
Eq(At().control, form.note, "ShowEntry for the note not on the note")
Check(not form.note:HasFocus(), "the note took the cursor with the pad in hand")
Press(catcher, "PAD2")
Check(not sheet:IsShown(), "B did not put the entry away")

--------------------------------------------------------------------------
Section("the picker: walked, B puts it away, A picks")

ns.Diary.Remove(STRANGER, "keep")
ns.Recent.Set("trade", KNOWN)
ns.UI.ShowPicker()
local picker = _G.SocialDiaryPickerFrame
Check(picker:IsShown(), "setup: the picker not open")
Eq(Top(), "picker", "the picker's scope has not the pad")
local pc = Pad.Catcher(picker)
Check(pc:IsGamePadButtonEnabled(), "the picker's catcher not on")
local shown = 0
for _, row in ipairs(picker.rows) do if row:IsShown() then shown = shown + 1 end end
Check(shown >= 2, "setup: fewer than two people to pick")
Eq(At().row, picker.rows[1], "the pad not on the first row")
Check(Pad.Look.parts[picker].pen:IsShown(), "the first row's name not boxed")
Eq(Pad.Look.parts[picker].pen:GetParent(), picker, "the box not on the picker")
Eq(Legend().PAD2, "Put the list away", "B's prompt on the picker")
Eq(Legend().PAD1, ns.Diary.IsDiary(At().guid) and "Open their page" or "Remember them", "A's prompt on a row")
Press(pc, "PADDDOWN")
Eq(At().row, picker.rows[2], "down did not walk to the second row")
Press(pc, "PADDUP")
Eq(At().row, picker.rows[1], "up did not walk back")
Press(pc, "PAD2")
Check(not picker:IsShown(), "B did not put the picker away")
Eq(Top(), nil, "the pad not given back after the picker")
Check(not pc:IsGamePadButtonEnabled(), "the picker's catcher left on")

ns.UI.TogglePicker()
Eq(Top(), "picker", "the picker opened again: not its scope")
Eq(At().row, picker.rows[1], "opened again, not on the first row")
local guid = At().guid
Press(pc, "PAD1")
Check(not picker:IsShown(), "A did not pick")
Check(sheet:IsShown(), "the pick opened no sheet")
Eq(form.guid, guid, "the sheet on somebody else")
Eq(Top(), "entry", "the sheet the pick opened has not the pad")
Check(catcher:IsGamePadButtonEnabled(), "the sheet's catcher not on after the pick")
Press(catcher, "PAD2")
Check(not sheet:IsShown(), "B did not put the picked sheet away")

--------------------------------------------------------------------------
Section("the book and a sheet open together")

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
local book = ns.UI.JournalFrame()
local bc = Pad.Catcher(book)
Check(Top() ~= nil and Top() ~= "entry", "setup: the book's scope not on top")
local bookTop = Top()
Check(bc:IsGamePadButtonEnabled(), "setup: the book's catcher not on")
ns.UI.Remember(STRANGER, { unit = "target", source = "test" })
Check(sheet:IsShown(), "Remember with the book open: no loose sheet")
Eq(Top(), "entry", "the sheet over the book has not the pad")
Check(catcher:IsGamePadButtonEnabled(), "the sheet's catcher not on over the book")
Check(not bc:IsGamePadButtonEnabled(), "the book's catcher still on under the sheet")
Check(not Pad.Look.parts[book].slip:IsShown(), "the book's prompts left up under the sheet")
Check(Pad.Look.parts[sheet].slip:IsShown(), "the sheet's prompts not up")
Eq(Press(catcher, "PADLSHOULDER"), true, "the sheet took LB (it turns no ribbon)")
Press(catcher, "PAD2")
Check(not sheet:IsShown(), "B did not put the sheet away over the book")
Check(book:IsShown(), "B on the sheet closed the book too")
Eq(Top(), bookTop, "the book's scope not back")
Check(bc:IsGamePadButtonEnabled(), "the book's catcher not back on")
-- The Escape stand-in (UISpecialFrames): the same.
ns.UI.Remember(STRANGER, { unit = "target", source = "test" })
Eq(Top(), "entry", "setup: the sheet again")
sheet:Hide()
Eq(Top(), bookTop, "Escape on the sheet: the book's scope not back")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a window the player did not open takes nothing")

sheet:Show()
Check(sheet:IsShown(), "setup: the sheet not shown")
Eq(Top(), nil, "a sheet shown by no player's action took the pad")
Pad.Refresh()
Check(not catcher:IsGamePadButtonEnabled(), "its catcher on")
sheet:Hide()
picker:Show()
Pad.Refresh()
Eq(Top(), nil, "a picker shown by no player's action took the pad")
picker:Hide()

--------------------------------------------------------------------------
Section("two windows: the last opened has the pad, then the one before")

ns.UI.ShowPicker()
Eq(Top(), "picker", "setup: the picker")
ns.UI.ShowEntry(KNOWN)
Eq(Top(), "entry", "the sheet opened after the picker has not the pad")
Check(not pc:IsGamePadButtonEnabled(), "the picker's catcher on under the sheet")
Press(catcher, "PAD2")
Eq(Top(), "picker", "the sheet away: the picker not back")
Press(pc, "PAD2")
Eq(Top(), nil, "both away: a scope kept the pad")

--------------------------------------------------------------------------
Section("the Remember key's note: its own scope over the game")

mock.SetUnit("target", nil)
SocialDiary_Remember()
local host = _G.SocialDiaryNoteFrame
local note = host.note
Check(host:IsShown() and note:IsShown(), "setup: the key opened no note")
Eq(Top(), "quicknote", "the key's note has not the pad")
Wake(host)
Pad.Scope("quicknote").opened = nil
Pad.Refresh()
local qc = Pad.Catcher(host)
Check(qc:IsGamePadButtonEnabled(), "the note's catcher not on")
Eq(At().kind, "field", "the pad not on the box")
Check(not note.box:HasFocus(), "the box took the cursor with the pad in hand")
Press(qc, "PAD1")
Check(note.box:HasFocus(), "A did not give the box the cursor")
note.box:SetText("a draft")
Press(qc, "PAD2")
Check(not note.box:HasFocus(), "B did not stop writing")
Press(qc, "PAD2")
Check(not host:IsShown(), "B did not put the note away")
Eq(Top(), nil, "the pad not given back after the note")
SocialDiary_Remember()
Eq(note.box:GetText(), "a draft", "B threw the draft away")
Eq(Top(), "quicknote", "opened again: not its scope")
Eq(At().kind, "field", "opened again: not on the box")
host:Hide()

--------------------------------------------------------------------------
Section("the mouse takes over; a press brings the pad back")

ns.UI.ShowEntry(KNOWN)
Check(Onto(form.relationship), "setup: onto the relationship")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Eq(Top(), "entry", "setup: the sheet still the top scope")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher still on")
Check(not parts.pen:IsShown(), "the box left up")
Check(not parts.slip:IsShown(), "the prompts left up")
Check(not Red(form.relLabel), "the label left red")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(catcher:IsGamePadButtonEnabled(), "the catcher not back on")
Eq(At().control, form.relationship, "the pad not back where it was")
Check(parts.pen:IsShown(), "the box not back")
Press(catcher, "PAD2")
Check(not sheet:IsShown(), "B did not put the sheet away")

-- With the mouse, opening a sheet for the note gives it the cursor as before.
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
ns.UI.ShowEntry(KNOWN, true)
Check(form.note:HasFocus(), "with the mouse, the note did not take the cursor")
sheet:Hide()
