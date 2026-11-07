-- The Settings leftovers with the pad (.claude/controller-plan.md, step 7c):
-- the quiet list on Toasts (its search, its rows walked, scrolled and
-- ticked), the key setter taking a pad button (PAD3, SHIFT-PAD3 with the
-- Shift stand-in held, the stand-ins refused, B cancelling, never in a
-- fight, the keycap drawn with the pad's glyph, the mouse's click too), and
-- Feedback's copy fields and the action-bar books never reached.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Keys = ns.UI.Keys
local Glyphs = Pad.Glyphs

-- Thirty from the diary, all quiet: more than the list shows at once.
local people = {}
for i = 1, 30 do
    local guid = ("Player-4620-%08X"):format(0x00C0C000 + i)
    ns.Characters.Observe(guid, { first = ("Quietling%02d"):format(i), level = 10, faction = "Horde" })
    ns.Diary.Add(guid, { source = "test" })
    ns.Diary.SetQuietNearby(guid, true)
    people[i] = guid
end

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local book = ns.UI.JournalFrame()
local page = ns.UI.SettingsPage()

local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(page)
page:Refresh()

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)

local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Prompt(n)
    local e = Pad.Top().legend(Pad.Top())[n or 1]
    return e and e[2]
end
local function Walk(test, most)
    for _ = 1, most or 60 do
        if test(At()) then return true end
        Press("PADDDOWN")
    end
    return test(At())
end
local function Search(text)
    page.quietSearch:SetText(text)
    page.quietSearch.scripts.OnTextChanged(page.quietSearch)
end

--------------------------------------------------------------------------
Section("the quiet list joins Toasts' settings, after them")

page:ShowSection("toasts")
Pad.Refresh()
Eq(At().key, "nav:toasts", "not on Toasts")
Press("PAD1")
Eq(At().group, "pane", "A did not go into the settings")
Check(Walk(function(at) return at.kind == "search" end), "the quiet list's search never landed on")
Eq(At().frame, page.quietSearch.holder, "the search's field not what is boxed")
Eq(At().subhead, page.quietHeading, "the list's heading not the subheading")
Check(page.quietHeading ~= nil, "the list's heading not kept")
Eq(Prompt(), "Write", "the search's prompt")
Check(not page.quietSearch:HasFocus(), "landing on the search gave it the cursor")

--------------------------------------------------------------------------
Section("the search: A gives the cursor, the list narrows, B and moving off take it back")

Press("PAD1")
Check(page.quietSearch:HasFocus(), "A did not give the search the cursor")
Eq(Prompt(), "Done writing", "A's prompt while writing")
Eq(Prompt(2), "Stop writing", "B's prompt while writing")
Search("quietling0")
Eq(#page.quiet.data, 9, "the search did not narrow the list")
Eq(At().kind, "search", "writing moved the pad off the search")
Check(page.quietSearch:HasFocus(), "the pad's refresh took the cursor while writing")
Eq(#Pad.Top().focus.groups.pane.items > 0 and (function()
    local n = 0
    for _, it in ipairs(Pad.Top().focus.groups.pane.items) do if it.kind == "quiet" then n = n + 1 end end
    return n
end)(), 9, "the pad's rows not the list's as it narrowed")
Press("PAD2")
Check(not page.quietSearch:HasFocus(), "B did not take the cursor back")
Eq(At().kind, "search", "B while writing moved the pad")
Eq(At().group, "pane", "B while writing went back to the sections")
Press("PAD1")
Press("PADDDOWN")
Check(not page.quietSearch:HasFocus(), "moving off the search kept the cursor")
Eq(At().kind, "quiet", "down from the search not a row")
Press("PADDUP")
Press("PAD1")
Search("")
Press("PAD1")
Check(not page.quietSearch:HasFocus(), "A again did not take the cursor back")
Eq(#page.quiet.data, 30, "the whole list not back")

--------------------------------------------------------------------------
Section("the rows: walked, the list scrolled, the name boxed")

Press("PADDDOWN")
Eq(At().kind, "quiet", "down from the search not a row")
Eq(At().guid, people[1], "not the first row")
local row = page.quiet:RowOf(1)
Eq(At().frame, row, "the row's frame not stood on")
Eq(At().words, row.name, "the name not the words boxed")
Eq(page.quiet.offset, 0, "the list scrolled before it had to")
local shown = page.quiet.numRows
for _ = 1, shown + 3 do Press("PADDDOWN") end
local index = shown + 4
Eq(At().guid, people[index], "walking down not on the next rows")
Check(page.quiet.offset > 0, "the list did not scroll with the pad")
Check(page.quiet:RowOf(index) ~= nil, "the row walked to not in view")
Eq(At().frame, page.quiet:RowOf(index), "the pad's frame not the row in view")
for _ = 1, 40 do Press("PADDDOWN") end
Eq(At().guid, people[30], "the last row not reached")
Check(page.quiet:RowOf(30) ~= nil, "the last row not in view")
for _ = 1, 29 do Press("PADDUP") end
Eq(At().guid, people[1], "walking back up not on the first row")
Eq(page.quiet.offset, 0, "the list not scrolled back to the top")

--------------------------------------------------------------------------
Section("A ticks and unticks a row, as its click does")

Eq(Prompt(), "Untick", "a quiet row's prompt")
Press("PAD1")
Eq(ns.Diary.IsQuietNearby(people[1]), false, "A did not untick the row")
Check(not page.quiet:RowOf(1).tick:GetChecked(), "the row's tick not taken off")
Eq(page.quietCount:GetText(), "29 quiet", "the count not told")
Eq(Prompt(), "Tick", "the prompt after unticking")
Eq(At().guid, people[1], "ticking moved the pad")
Eq(At().words, page.quiet:RowOf(1).name, "the name not boxed again after the tick")
Press("PAD1")
Eq(ns.Diary.IsQuietNearby(people[1]), true, "A again did not tick it back")
Eq(page.quietCount:GetText(), "30 quiet", "the count after ticking back")

--------------------------------------------------------------------------
Section("B from the list goes back to the sections; other sections never reach it")

Press("PAD2")
Eq(At().key, "nav:toasts", "B from a row not back on Toasts")
page:ShowSection("recording")
Pad.Refresh()
for _, it in ipairs(Pad.Top().focus.groups.pane.items) do
    if it.kind == "quiet" or it.kind == "search" then
        Check(not it.available(), "the quiet list reachable with Recording shown")
        break
    end
end

--------------------------------------------------------------------------
Section("Feedback's copy fields and the action-bar books are never stood on")

local books = {}
for _, b in pairs(page.macroBooks) do books[b] = true end
for _, it in ipairs(Pad.Top().focus.groups.pane.items) do
    local w = it.frame
    Check(not books[w], "an action-bar book is stood on: " .. it.key)
    Check(not (w and w.box and w.edges), "a copy field is stood on: " .. it.key)
end

--------------------------------------------------------------------------
Section("the key setter: A listens, the pad aside")

mock.bindings = {}
mock.cvars.GamePadEmulateShift = "PADLTRIGGER"
mock.cvars.GamePadEmulateCtrl = "PADLSHOULDER"
mock.cvars.GamePadEmulateAlt = "none"
mock.cvars.GamePadEmulateEsc = "PADBACK"
local JOURNAL = page.keys.SOCIALDIARY_JOURNAL
JOURNAL:Refresh()
page:ShowSection("shortcuts")
Pad.Refresh()
Press("PAD1")
Eq(At().kind, "setter", "the first setting on Shortcuts not the journal's key")
Eq(At().frame, JOURNAL.bind, "its link not stood on")
Eq(At().words, JOURNAL.bind.label, "its link's words not boxed")
Eq(At().subhead, JOURNAL.group, "the Keys heading not its subheading")
Eq(Prompt(), "Choose a button", "the key's prompt")
Press("PAD1")
Check(JOURNAL.listening, "A did not listen")
Check(Pad.Top() == nil, "a scope kept the pad while the key listens")
Check(not catcher:IsGamePadButtonEnabled(), "the book's catcher still takes buttons")
Check(JOURNAL.catcher:IsGamePadButtonEnabled(), "the setter does not take pad buttons")
Eq(JOURNAL.keycap.text:GetText(), "press a button", "the keycap does not ask for a button")
Eq(JOURNAL.hint:GetText(), Glyphs.Text("PAD2", 16) .. " to cancel", "the hint does not say B cancels")
Eq(page.keyStatus:GetText(), Keys.PAD_CANCEL:format(Glyphs.Text("PAD2", 16)), "B's not being bindable not said")

--------------------------------------------------------------------------
Section("a pad button binds, saved, the keycap its glyph")

local saves = mock.bindingSaves
Eq(mock.PadPress(JOURNAL.catcher, "PAD3", true), false, "the button went on past the setter")
Eq(mock.bindings.PAD3, "SOCIALDIARY_JOURNAL", "PAD3 not bound")
Eq(mock.bindingSaves, saves + 1, "the bindings not saved")
Check(not JOURNAL.listening, "still listening after the bind")
Eq(JOURNAL.keycap.text:GetText(), Glyphs.Text("PAD3", 18), "the keycap does not show the pad's glyph")
Eq(Keys.Bound("SOCIALDIARY_JOURNAL"), Glyphs.Text("PAD3", 18), "Bound not the glyph")
Eq(Keys.Text("F5"), "F5", "a keyboard key not in the bindings' words")
Eq(Pad.Top() and Pad.Top().key, "settings", "the pad not back after the bind")
Check(catcher:IsGamePadButtonEnabled(), "the book's catcher not back")
Check(not JOURNAL.catcher:IsGamePadButtonEnabled(), "the setter still takes pad buttons")
Eq(At().frame, JOURNAL.bind, "the pad not back on the key")

--------------------------------------------------------------------------
Section("with the Shift stand-in held: SHIFT-PAD3, drawn as both buttons")

Press("PAD1")
Check(JOURNAL.listening, "A did not listen again")
Eq(mock.PadPress(JOURNAL.catcher, "PADLTRIGGER", true), true, "the Shift stand-in did not go on to the game")
Check(JOURNAL.listening, "the Shift stand-in ended the listening")
Eq(page.keyStatus:GetText(), Keys.PAD_MODIFIER:format("Shift"), "the Shift stand-in not explained")
mock.keysDown.PADLTRIGGER = true
mock.PadPress(JOURNAL.catcher, "PAD3", true)
mock.keysDown.PADLTRIGGER = nil
Eq(mock.bindings["SHIFT-PAD3"], "SOCIALDIARY_JOURNAL", "SHIFT-PAD3 not bound")
Eq(mock.bindings.PAD3, nil, "the old key not let go")
Eq(JOURNAL.keycap.text:GetText(), Glyphs.Text("PADLTRIGGER", 18) .. " + " .. Glyphs.Text("PAD3", 18),
    "the keycap does not draw Shift's button and the button")
Eq(Keys.PadCombo("PAD4"), "PAD4", "a modifier held with nothing held")
mock.modifiers.ctrl = true
Eq(Keys.PadCombo("PAD4"), "CTRL-PAD4", "the keyboard's Ctrl not taken")
mock.modifiers.ctrl = false
mock.cvars.GamePadEmulateShift = "PADPADDLE1"
mock.keysDown.PADPADDLE1 = true
Eq(Keys.PadCombo("PAD4"), "SHIFT-PAD4", "the Shift stand-in not read from its CVar")
mock.keysDown.PADPADDLE1 = nil
mock.cvars.GamePadEmulateShift = "PADLTRIGGER"

--------------------------------------------------------------------------
Section("the stand-ins are refused, B cancels")

Press("PAD1")
Check(JOURNAL.listening, "A did not listen")
Eq(mock.PadPress(JOURNAL.catcher, "PADBACK", true), false, "the Escape stand-in went on")
Check(JOURNAL.listening, "the Escape stand-in ended the listening")
Eq(page.keyStatus:GetText(), Keys.PAD_ESCAPE, "the Escape stand-in not refused")
mock.PadPress(JOURNAL.catcher, "PADLSHOULDER", true)
Eq(page.keyStatus:GetText(), Keys.PAD_MODIFIER:format("Ctrl"), "the Ctrl stand-in not refused")
mock.cvars.GamePadEmulateEsc = "PAD4"
mock.PadPress(JOURNAL.catcher, "PAD4", true)
Eq(page.keyStatus:GetText(), Keys.PAD_ESCAPE, "the Escape stand-in not read from its CVar")
mock.cvars.GamePadEmulateEsc = "PADBACK"
Eq(mock.bindings.PADBACK, nil, "the Escape stand-in bound")
Eq(mock.bindings.PADLSHOULDER, nil, "the Ctrl stand-in bound")
Eq(mock.bindings.PAD4, nil, "a stand-in bound")
Eq(mock.PadPress(JOURNAL.catcher, "PAD2", true), false, "B went on past the setter")
Check(not JOURNAL.listening, "B did not cancel")
Eq(mock.bindings.PAD2, nil, "B was bound")
Eq(mock.bindings["SHIFT-PAD3"], "SOCIALDIARY_JOURNAL", "cancelling changed the key")
Eq(Pad.Top() and Pad.Top().key, "settings", "the pad not back after B")
Eq(Keys.Text("CTRL-ALT-PAD1"):find(Glyphs.Text("PADLSHOULDER", 18), 1, true) ~= nil, true, "Ctrl not drawn as its button")
Check(Keys.Text("ALT-PAD1"):find("Alt", 1, true), "Alt without a stand-in not named")

--------------------------------------------------------------------------
Section("what the button did before, asked and said")

mock.bindings.PAD4 = "TOGGLEBAG"
BINDING_NAME_TOGGLEBAG = "Open a Bag"
Press("PAD1")
mock.PadPress(JOURNAL.catcher, "PAD4", true)
Eq(mock.bindings.PAD4, "TOGGLEBAG", "a taken button bound before the answer")
Check(mock.popups[#mock.popups].args[1]:find(Glyphs.Text("PAD4", 18), 1, true) == 1,
    "the question does not show the button's glyph")
mock.AnswerPopup("accept")
Eq(mock.bindings.PAD4, "SOCIALDIARY_JOURNAL", "yes did not bind the button")
Check(page.keyStatus:GetText():find("Open a Bag", 1, true), "what it did before not said")

--------------------------------------------------------------------------
Section("never in a fight")

mock.inCombat = true
Press("PAD1")
Check(not JOURNAL.listening, "it listened in a fight")
Eq(page.keyStatus:GetText(), Keys.COMBAT, "the fight's refusal not said")
mock.inCombat = false
Press("PAD1")
Check(JOURNAL.listening, "it did not listen after the fight")
mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Check(not JOURNAL.listening, "a fight did not stop the listening")
Check(not JOURNAL.catcher:IsGamePadButtonEnabled(), "the setter kept the pad's buttons in a fight")
Eq(mock.PadPress(JOURNAL.catcher, "PAD1", true), true, "a stopped setter took a button")
mock.inCombat = false
Press("PAD1")
Check(JOURNAL.listening, "it did not listen")
mock.inCombat = true   -- (a fight begun, its event not yet come)
saves = mock.bindingSaves
mock.PadPress(JOURNAL.catcher, "PAD1", true)
Eq(mock.bindings.PAD1, nil, "a button bound in a fight")
Eq(mock.bindingSaves, saves, "the bindings saved in a fight")
Eq(page.keyStatus:GetText(), Keys.COMBAT, "the fight's refusal not said after the press")
mock.inCombat = false

--------------------------------------------------------------------------
Section("with the mouse: a click, then a pad button")

mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
mock.pad.using = false
Pad.Input.Force("off")
Check(not Pad.Input.Active(), "setup: the pad still in hand")
JOURNAL.bind:Click()
Check(JOURNAL.listening, "the click did not listen")
Eq(JOURNAL.keycap.text:GetText(), "press a key", "the mouse's keycap words")
Eq(JOURNAL.hint:GetText(), "Escape to cancel", "the mouse's hint")
Eq(page.keyStatus:GetText(), "", "B's line said with the mouse")
mock.PadPress(JOURNAL.catcher, "PAD3", true)
Eq(mock.bindings.PAD3, "SOCIALDIARY_JOURNAL", "a pad button after a click not bound")
JOURNAL.bind:Click()
JOURNAL.catcher.scripts.OnKeyDown(JOURNAL.catcher, "F16")
Eq(mock.bindings.F16, "SOCIALDIARY_JOURNAL", "a keyboard key no longer binds")
Eq(JOURNAL.keycap.text:GetText(), "F16", "a keyboard key not shown in its words")
JOURNAL.bind:Click()
JOURNAL.catcher.scripts.OnKeyDown(JOURNAL.catcher, "ESCAPE")
Check(not JOURNAL.listening, "Escape did not cancel")
Check(not JOURNAL.catcher:IsGamePadButtonEnabled(), "Escape left the setter taking pad buttons")
Pad.Input.Force(nil)
