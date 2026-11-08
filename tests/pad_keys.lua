-- The Settings leftovers with the pad (.claude/controller-plan.md, step 7c
-- and "As built (macros for the pad)"): the quiet list on Toasts (its
-- search, its rows walked, scrolled and ticked); Keybinds & Shortcuts laid
-- out for the pad (the books first, with their line, the keys gone, and
-- back with the mouse); the books stood on and picked up with A (faded in
-- a fight, passed over); the key setter keyboard-only (no pad button
-- taken); Feedback's copy fields never reached.

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
Section("Feedback's copy fields are never stood on")

for _, it in ipairs(Pad.Top().focus.groups.pane.items) do
    local w = it.frame
    Check(not (w and w.box and w.edges), "a copy field is stood on: " .. it.key)
end

--------------------------------------------------------------------------
Section("Keybinds & Shortcuts with the pad: the books first, the keys gone")

local Macro = ns.UI.Settings.Macro
local JOURNAL = page.keys.SOCIALDIARY_JOURNAL
local function Y(w) return w.recorded.points[1].args[4] end
local keysHeading = JOURNAL.group
page:ShowSection("shortcuts")
Pad.Refresh()
Check(not keysHeading:IsShown() and not keysHeading.rule:IsShown(), "the Keys heading shown with the pad")
for action, setter in pairs(page.keys) do
    Check(not setter:IsVisible(), "a key setter shown with the pad: " .. action)
end
Check(not page.keyStatus:IsShown(), "the keys' status line shown with the pad")
Eq(Y(page.macroHeading), -48, "the books' heading not first on the page")
Check(page.macroLine and page.macroLine:IsShown(), "no line beside the books with the pad")
Eq(page.macroLine:GetText(), Macro.PadLine(Glyphs.Text("PAD1", 16)), "the books' line")
Check(Y(page.macroLine) < Y(page.macroHeading), "the line not under the heading")
Check(Y(page.macroBooks.journal) < Y(page.macroLine), "the books not under the line")
Check(Y(page.macroStatus) < Y(page.macroBooks.remember), "the status line not under the books")
Check(Y(page.commands[1]) < Y(page.macroStatus), "the slash commands not after the books")

--------------------------------------------------------------------------
Section("the books: stood on, A picks one up as a click does")

local BOOKS = page.macroBooks
Press("PAD1")
Eq(At().kind, "book", "the first setting on Shortcuts not a book")
Eq(At().frame, BOOKS.journal, "not the journal's book")
Eq(At().words, BOOKS.journal.label, "the book's name not boxed")
Eq(At().subhead, page.macroHeading, "the books' heading not the subheading")
Eq(Prompt(), "Pick it up", "the book's prompt")
Eq(GameTooltip.lines and GameTooltip.lines[1] and GameTooltip.lines[1][1],
    "Place it in a slot on your controller's action bar.", "the book's tooltip with the pad")
mock.macros, mock.cursor = {}, nil
Press("PAD1")
Eq(#mock.macros, 1, "A did not make the macro")
Eq(mock.macros[1].body, "/sd", "A made the wrong macro")
Eq(mock.cursor and mock.cursor[1], "macro", "A did not put the book on the cursor")
Eq(page.macroStatus:GetText(), Macro.SAID.padClick, "the pad's line after a pickup")
Eq(At().frame, BOOKS.journal, "picking it up moved the pad")
Press("PADDDOWN")
Eq(At().frame, BOOKS.remember, "down from the journal's book not Remember this's")
mock.cursor = nil
Press("PAD1")
Eq(mock.macros[2] and mock.macros[2].body, "/sd remember", "A did not make Remember this's macro")
Eq(mock.cursor and mock.cursor[1], "macro", "Remember this's book not picked up")

--------------------------------------------------------------------------
Section("in a fight a book fades, and the pad passes over it")

mock.cursor = nil
mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Pad.Refresh()
Check(BOOKS.remember.unavailable, "the book not faded in a fight")
for _, it in ipairs(Pad.Top().focus.groups.pane.items) do
    if it.kind == "book" then Check(not it.available(), "a faded book is stood on") end
end
BOOKS.remember:Click("LeftButton")
Eq(mock.cursor, nil, "a faded book was picked up")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Pad.Refresh()
Eq(page.macroStatus:GetText(), "", "the fight's line kept after it")

--------------------------------------------------------------------------
Section("with the mouse: the page as it always was")

mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse did not take over")
Check(keysHeading:IsShown() and keysHeading.rule:IsShown(), "the Keys heading not back")
Check(JOURNAL:IsVisible(), "the key setter not back with the mouse")
Check(page.keyStatus:IsShown(), "the keys' status line not back")
Check(not page.macroLine:IsShown(), "the books' line kept with the mouse")
Eq(Y(keysHeading), -48, "the Keys heading not first again")
Check(Y(page.macroHeading) < Y(page.keyStatus), "the books not after the keys again")
BOOKS.journal.scripts.OnEnter(BOOKS.journal)
Eq(GameTooltip.lines[1][1], "Drag onto an action bar.", "the mouse's tooltip")
BOOKS.journal:Click("LeftButton")
Eq(page.macroStatus:GetText(), Macro.SAID.click, "the mouse's line after a click")

--------------------------------------------------------------------------
Section("the key setter is the keyboard's: no pad button taken")

mock.bindings = {}
JOURNAL.bind:Click()
Check(JOURNAL.listening, "the click did not listen")
Eq(JOURNAL.keycap.text:GetText(), "press a key", "the keycap's words")
Eq(JOURNAL.hint:GetText(), "Escape to cancel", "the hint")
Check(not JOURNAL.catcher:IsGamePadButtonEnabled(), "the setter takes pad buttons")
mock.PadPress(JOURNAL.catcher, "PAD3", true)
Eq(mock.bindings.PAD3, nil, "a pad button was bound")
Check(JOURNAL.listening, "a pad button ended the listening")
Eq(Keys.PadCombo, nil, "the pad's combo building still there")
JOURNAL.catcher.scripts.OnKeyDown(JOURNAL.catcher, "F16")
Eq(mock.bindings.F16, "SOCIALDIARY_JOURNAL", "a keyboard key no longer binds")
Eq(JOURNAL.keycap.text:GetText(), "F16", "a keyboard key not shown in its words")
-- (a pad key bound elsewhere, before: shown in the bindings' words)
mock.bindings = { PAD3 = "SOCIALDIARY_JOURNAL" }
JOURNAL:Refresh()
Eq(JOURNAL.keycap.text:GetText(), GetBindingText("PAD3"), "a bound pad key not in the bindings' words")
mock.inCombat = true
JOURNAL.bind:Click()
Check(not JOURNAL.listening, "it listened in a fight")
Eq(page.keyStatus:GetText(), Keys.COMBAT, "the fight's refusal not said")
mock.inCombat = false
