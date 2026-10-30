-- The ways into the diary: the right-click menu, the picker's candidates,
-- and the entry sheet the picker opens.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local GUID = F.STRANGER.guid

--------------------------------------------------------------------------
Section("menu resolution (DIA-2a)")

-- On record by name, for the name fallback, and still the target.
mock.SetUnit("target", F.STRANGER)
ns.Characters.ObserveUnit("target")

local function Path(contextData)
    local _, _, path = ns._test.ResolveMenuContext(contextData)
    return path
end

Eq(Path({ guid = GUID }), "guid", "an explicit GUID should win")
Eq(Path({ unit = "target" }), "unit", "the target-frame path")
Eq(Path({ unit = "nosuchunit" }), "failed", "a dead unit token resolved to something")

-- The chat-name path, which is the one Session 1 could not settle.
mock.locationGUID = GUID
Eq(Path({ playerLocation = {} }), "playerLocation", "the chat-name path")
mock.locationGUID = nil
Eq(Path({ playerLocation = {} }), "failed", "chat-name path invented a GUID")

Eq(Path({ name = "Bram", surname = "Redfen" }), "name", "the name fallback")
Eq(Path({ name = "Bram Redfen" }), "name", "the name fallback with a joined name")
Eq(Path({ name = "Nobody" }), "failed", "an unknown name resolved")
Eq(Path(nil), nil, "a nil context resolved")

-- An ambiguous first name must resolve to nobody rather than to a guess.
ns.Characters.Observe("Player-4620-00BBBBBB", { first = "Bram", surname = "Otherone" })
Eq(Path({ name = "Bram" }), "failed", "an ambiguous first name picked a winner")
Eq(Path({ name = "Bram", surname = "Redfen" }), "name", "the surname should disambiguate")
ns.db.characters["Player-4620-00BBBBBB"] = nil

-- DIA-2: the entry actually reaches the menu, and opens the page to add
-- them on; Done adds them.
local buttons = mock.OpenMenu("MENU_UNIT_PLAYER", { unit = "target" })
Eq(#buttons, 1, "no menu entry was added")
Check(buttons[1].text:find("remember"), "wrong menu entry: " .. buttons[1].text)
buttons[1].Click()
Eq(ns.Diary.IsDiary(GUID), false, "the menu entry added them before Done")
_G.SocialDiaryEntryFrame.form.done:Click()
Eq(ns.Diary.IsDiary(GUID), true, "Done after the menu entry did not add anybody")

-- Already in the diary, the entry opens them instead of adding again.
buttons = mock.OpenMenu("MENU_UNIT_PLAYER", { unit = "target" })
Check(buttons[1].text:find("open entry"), "wrong menu entry for an existing entry")

-- The target changed while the menu was open: the token is not passed on,
-- or the page would be filled in from someone else.
do
    local opts
    local realRemember = ns.UI.Remember
    ns.UI.Remember = function(_, o) opts = o end
    mock.SetUnit("party1", F.PUG)
    ns.Characters.ObserveUnit("party1")
    local menu = mock.OpenMenu("MENU_UNIT_PLAYER", { unit = "party1" })
    menu[1].Click()
    Eq(opts.unit, "party1", "the token was dropped while it still pointed at them")
    menu = mock.OpenMenu("MENU_UNIT_PLAYER", { unit = "party1" })
    mock.SetUnit("party1", F.GARRICK)
    menu[1].Click()
    Eq(opts.unit, nil, "the token was passed on after it moved to someone else")
    mock.SetUnit("party1", nil)
    ns.UI.Remember = realRemember
end

-- Never offer to remember yourself.
mock.SetUnit("self", F.SELF)
Eq(#mock.OpenMenu("MENU_UNIT_PLAYER", { unit = "self" }), 0, "offered to remember the user")
Eq(#mock.OpenMenu("MENU_UNIT_PLAYER", { isSelf = true }), 0, "isSelf context not honoured")

-- Anything added to a menu on a secret unit taints its layout, and Blizzard's
-- arithmetic on the (secret) menu size then errors. So the menu is left
-- alone on a secret unit, and on anybody the addon cannot identify.
mock.SetUnit("target", { guid = mock.secret(GUID), name = { mock.secret("Bram") } })
Eq(#mock.OpenMenu("MENU_UNIT_PLAYER", { unit = "target", name = "Bram", surname = "Redfen" }), 0,
    "the menu on a secret unit was touched (the name fallback must not rescue it)")
Eq(#mock.OpenMenu("MENU_UNIT_PLAYER", { name = mock.secret("Bram") }), 0,
    "the menu on a secret name was touched")
mock.SetUnit("target", { guid = "Creature-0-4620-1-6-3098-1", name = { "Kobold Vermin" }, isPlayer = false })
Eq(#mock.OpenMenu("MENU_UNIT_TARGET", { unit = "target" }), 0, "an NPC was offered an entry")
Eq(#mock.OpenMenu("MENU_UNIT_PLAYER", { name = "Nobody" }), 0, "an unidentified character was offered an entry")
mock.SetUnit("target", F.STRANGER)

--------------------------------------------------------------------------
Section("candidates and the picker (DIA-3)")

ns.db.diary, ns.db.interactions = {}, {}
mock.SetUnit("mouseover", nil)
mock.SetUnit("focus", nil)

local candidates = ns.Candidates()
Eq(#candidates, 1, "only the target should be a candidate here")
Eq(candidates[1].guid, GUID, "the target should come first")
Eq(candidates[1].why, "your target", "the reason shown next to the name")
Eq(candidates[1].unit, "target", "the unit token should travel with the candidate")
Eq(candidates[1].inDiary, false, "candidate wrongly marked as in the diary")

-- The user is never a candidate for their own diary.
mock.SetUnit("mouseover", F.SELF)
Eq(#ns.Candidates(), 1, "the user offered themselves as a candidate")
mock.SetUnit("mouseover", nil)

-- DIA-3 names the last trade partner explicitly.
ns.Recent.Set("trade", F.GARRICK.guid)
ns.Characters.Observe(F.GARRICK.guid, { first = "Garrick", surname = "Fallow" })
candidates = ns.Candidates()
Eq(#candidates, 2, "the last trade partner is missing")
Eq(candidates[2].why, "you traded with them", "wrong reason for the trade partner")

-- Anyone else the buffer saw in the last hour.
ns.Characters.Observe("Player-4620-00CCCCCC", { first = "Mad", surname = "Claw" })
ns.Interactions.Add("Player-4620-00CCCCCC", "whisper_in", {})
candidates = ns.Candidates()
Eq(#candidates, 3, "a recent whisper is not a candidate")
Eq(candidates[3].why, "recent whisper_in", "wrong reason for a buffered interaction")

-- ... but not what it saw last week.
ns.db.interactions["Player-4620-00CCCCCC"][1].time = mock.now - 10 * DAY
Eq(#ns.Candidates(), 2, "a week-old interaction is still being offered")

--------------------------------------------------------------------------
Section("the picker and the entry dialog")

ns.UI.ShowPicker()
local pickerFrame = _G.SocialDiaryPickerFrame
Check(pickerFrame:IsShown(), "picker did not open")
Eq(pickerFrame.rows[1].name:GetText():find("Bram Redfen") ~= nil, true,
    "the target is not the first row")
Check(not pickerFrame.rows[5]:IsShown(), "an empty row is showing")

-- DIA-4: one click opens the page to add them on, Done adds them. Two
-- actions in total.
pickerFrame.rows[1]:Click()
Eq(ns.Diary.IsDiary(GUID), false, "clicking a row added them before Done")
Check(not pickerFrame:IsShown(), "the picker stayed open after a pick")

-- The page opens as a loose sheet, the note ready to write in (the quick
-- add), and says they are not in the diary yet.
local dialogFrame = _G.SocialDiaryEntryFrame
local form = dialogFrame.form
Check(dialogFrame:IsShown(), "the entry sheet did not open")
Eq(dialogFrame.name:GetText(), "BRAM REDFEN", "wrong name on the sheet")
Check(form.note:HasFocus(), "the quick add did not put the cursor in the note")
Check(dialogFrame.meta:GetText():find("no interactions yet"), "no 'not yet' line: " .. dialogFrame.meta:GetText())
Eq(form.remove:GetText(), "Cancel", "the way out of a draft offers removal")

-- Written on, then closed without Done: nobody was added.
form.presets.friend:Click()
Eq(form.presets.friend.on, true, "a chip on the draft did not turn on")
form.note:SetText("lost")
form.note.scripts.OnEditFocusLost(form.note)
dialogFrame:Hide()  -- the close button, or Escape
Eq(ns.Diary.IsDiary(GUID), false, "closing the page without Done added them")

-- Cancel closes it the same way.
ns.UI.ShowPicker()
pickerFrame.rows[1]:Click()
Eq(form.note:GetText(), "", "a new draft kept the closed one's note")
Eq(form.presets.friend.on, false, "a new draft kept the closed one's tag")
form.remove:Click()
Check(not dialogFrame:IsShown(), "Cancel did not close the sheet")
Eq(ns.Diary.IsDiary(GUID), false, "Cancel added them")

-- Done adds them with what was written, typed-but-uncommitted included.
-- Asked again while the page is open, it keeps what was written on it.
ns.UI.ShowPicker()
pickerFrame.rows[1]:Click()
form.presets.helper:Click()
form.relationship:SetText("levelling buddy")
form.relationship.scripts.OnEditFocusLost(form.relationship)
ns.UI.Remember(GUID, { unit = "target", source = "test" })
Eq(form.presets.helper.on, true, "asking again started the draft over")
form.note:SetFocus()
form.note:SetText("helped with Nagas")
form.done:Click()
Check(not dialogFrame:IsShown(), "Done did not close the sheet")
Eq(ns.Diary.IsDiary(GUID), true, "Done did not add them")
local added = ns.Diary.Get(GUID)
Eq(added.note, "helped with Nagas", "Done lost the note being written")
Eq(added.relationship, "levelling buddy", "Done lost the relationship")
Check(ns.Diary.HasTag(GUID, "helper"), "Done lost the tag")
Eq(added.addedContext.source, "picker", "the add forgot where it came from")
ns.Diary.SetNote(GUID, nil)
ns.Diary.SetRelationship(GUID, nil)
ns.Diary.RemoveTag(GUID, "helper")

-- The target changed while the page was open: Done still adds whoever it
-- was opened on.
mock.SetUnit("target", F.GARRICK)
ns.UI.Remember(F.GARRICK.guid, { unit = "target", source = "test" })
mock.SetUnit("target", F.STRANGER)
form.done:Click()
Check(ns.Diary.IsDiary(F.GARRICK.guid), "Done added somebody else than the page was on")
ns.Diary.Remove(F.GARRICK.guid, "keep")

ns.UI.ShowEntry(GUID, true)
Check(dialogFrame.meta:GetText():find("^Added "), "no 'added' line: " .. dialogFrame.meta:GetText())
Eq(form.remove:GetText(), "Remove from the diary", "an entry's page has no remove link")

-- DIA-6 through the chips rather than the API. Presets show on and off.
Eq(form.presets.foe.on, false, "a preset that is off shows as on")
form.presets.foe:Click()
Check(ns.Diary.HasTag(GUID, "foe"), "the tag chip did not tag anybody")
Eq(form.presets.foe.on, true, "the chip did not turn on")
form.presets.foe:Click()
Check(not ns.Diary.HasTag(GUID, "foe"), "the tag chip did not toggle off")

-- A custom tag: written on the line, Enter adds it; its cross removes it.
form.addTag:SetText("helped with Nagas")
form.addTag.scripts.OnEnterPressed(form.addTag)
Check(ns.Diary.HasTag(GUID, "helped with Nagas"), "a custom tag was not added")
Eq(form.addTag:GetText(), "", "the tag line was not cleared for the next tag")
local custom
for _, chip in ipairs(form.chips) do
    if chip:IsShown() and chip.tag == "helped with nagas" then custom = chip end  -- tags are stored lowercase
end
Check(custom and custom.removable, "the custom tag has no removable chip")
custom.cross:Click()
Check(not ns.Diary.HasTag(GUID, "helped with Nagas"), "the cross did not remove the tag")

-- Text typed but not committed survives a chip click.
form.note:SetText("ganked me twice")
form.presets.avoid:Click()
Eq(ns.Diary.Get(GUID).note, "ganked me twice", "a chip click lost the note being written")
Eq(form.note:GetText(), "ganked me twice", "a chip click overwrote the note being written")
form.presets.avoid:Click()

form.note:SetText("ganked me twice in Stranglethorn")
form.note.scripts.OnEditFocusLost(form.note)
Eq(ns.Diary.Get(GUID).note, "ganked me twice in Stranglethorn", "the note did not save")

form.relationship:SetText("foe")
form.relationship.scripts.OnEditFocusLost(form.relationship)
Eq(ns.Diary.Get(GUID).relationship, "foe", "the relationship did not save")

-- Done closes the sheet; everything is already saved.
form.done:Click()
Check(not dialogFrame:IsShown(), "Done did not close the sheet")
ns.UI.ShowEntry(GUID)
Check(not form.note:HasFocus(), "opening to edit (not a quick add) grabbed the keyboard")

-- DIA-7 through the Remove link: the popup offers both outcomes.
form.remove:Click()
Check(mock.AnswerPopup("alt"), "the popup had no 'delete everything' button")
Eq(ns.Diary.IsDiary(GUID), false, "still in the diary after deleting everything")
Eq(ns.Characters.Get(GUID), nil, "'delete everything' left the character behind")
Check(not dialogFrame:IsShown(), "the sheet stayed open after the removal")

-- The dialog refuses to open on somebody who is not in the diary (DIA-1).
Eq(ns.UI.ShowEntry(F.GARRICK.guid), false, "the dialog opened on a non-entry")

--------------------------------------------------------------------------
Section("the keybind: a new note, or somebody linked on it")

ns.Diary.Add(F.GARRICK.guid, { source = "test" })
ns.Diary.Add(F.FRIEND.guid, { source = "test" })
local notesBefore = ns.Notes.Count()

-- Nobody targeted: a new note about nobody yet, the cursor in it.
mock.SetUnit("target", nil)
SocialDiary_Remember()
local host = _G.SocialDiaryNoteFrame
local N = host and host.note
Check(host and host:IsShown() and N:IsShown(), "the keybind with no target did not open a note")
Check(not (_G.SocialDiaryPickerFrame and _G.SocialDiaryPickerFrame:IsShown()), "the keybind still opened the picker")
Eq(N.title:GetText(), "A new note", "wrong title on the keybind's note")
Eq(N.guid, nil, "the note was opened on somebody")
Check(N.box:HasFocus(), "the note did not take the cursor")
Check(N.link.label:GetText():find("^Link who"), "the link does not ask whom: " .. N.link.label:GetText())

-- Written on but about nobody: Save asks whom rather than losing it.
N.box:SetText("Ran the Deadmines, wiped twice on Cookie.")
N.save:Click()
Eq(ns.Notes.Count(), notesBefore, "a note about nobody was saved")
Check(N:IsShown() and N.picker:IsShown(), "Save about nobody did not ask whom")
N.picker:Close()

-- A target already in the diary is linked on it, with a cross; twice is once.
N.box:ClearFocus()
mock.SetUnit("target", F.GARRICK)
SocialDiary_Remember()
mock.SetUnit("target", F.FRIEND)
SocialDiary_Remember()
SocialDiary_Remember()
Eq(#N.others, 2, "the keybind did not link each target once")
Eq(N.others[1], F.GARRICK.guid, "the first target is not linked first")
Check(N.portraits[1]:IsShown() and N.portraits[1].cross:IsShown(), "a linked target has no cross to unlink them")
Eq(N.box:GetText(), "Ran the Deadmines, wiped twice on Cookie.", "linking lost the text")

-- Escape puts it away with the draft kept; the keybind brings it back.
host:Hide()
mock.SetUnit("target", nil)
SocialDiary_Remember()
Check(host:IsShown(), "the keybind did not bring the note back")
Eq(#N.others, 2, "putting it away lost who was linked")
Eq(N.box:GetText(), "Ran the Deadmines, wiped twice on Cookie.", "putting it away lost the text")

-- With nobody targeted and the note open, the keybind puts it away.
SocialDiary_Remember()
Check(not host:IsShown(), "the keybind did not put the open note away")

-- Saved: one note about both.
SocialDiary_Remember()
N.save:Click()
Check(not host:IsShown(), "Save did not put the note away")
Eq(ns.Notes.Count(), notesBefore + 1, "the note was not saved")
Eq(#ns.Notes.For(F.GARRICK.guid), 1, "the note is not about the first target")
Eq(#ns.Notes.For(F.FRIEND.guid), 1, "the note is not about the second target")

-- The next one starts blank; Cancel throws a draft away.
SocialDiary_Remember()
Eq(N.box:GetText(), "", "a saved note's text came back")
Eq(#N.others, 0, "a saved note's people came back")
N.box:SetText("never mind")
N.cancel:Click()
SocialDiary_Remember()
Eq(N.box:GetText(), "", "a cancelled draft came back")
N.cancel:Click()

-- A target not in the diary yet still gets the page to add them on.
mock.SetUnit("target", F.PUG)
SocialDiary_Remember()
Check(not host:IsShown(), "a new target opened the note")
Check(_G.SocialDiaryEntryFrame:IsShown(), "a new target did not open the page to add them")
Eq(_G.SocialDiaryEntryFrame.form.guid, F.PUG.guid, "the add page is on somebody else")
