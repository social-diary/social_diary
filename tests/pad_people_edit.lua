-- Writing on the People page with the pad (.claude/controller-plan.md, step
-- 5b): an empty diary's page (its key and link), a stranger's glimpse (walked,
-- "+ Add" with A), writing mode (UI/Journal/WritingPad.lua: in from the edit
-- tab, its controls found, A gives a line the cursor, tags, B out keeping
-- what was typed, the removal popup stepping aside), the note's sheet and its
-- link card (UI/Journal/NotePad.lua: write, put away with the draft kept,
-- save; search and pick with the D-pad, unlink), and the mouse taking over.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF

local Pad = ns.UI.Pad
local J = ns.UI.Journal

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

-- A stranger pencilled in (tests/glimpse.lua's Numa, thinner): seen, then
-- grouped with, never added.
local t0 = now - 3 * DAY
local N = F.FRIEND.guid
ns.Characters.Observe(N, { first = "Numa", surname = "Pompilius", level = 12, class = "DRUID", race = "Tauren",
    faction = "Horde" })
ns.db.characters[N].firstSeen = t0 + 300
ns.db.characters[N].lastSeen = t0 + 9000
ns.db.sightings[N] = { { time = t0 + 300, last = t0 + 600, level = 10, mapID = 1412, x = 0.40, y = 0.60,
    subZone = "Red Rocks", me = SELF.guid } }
ns.db.interactions[N] = {
    { type = "group_join", time = t0 + 5000, me = SELF.guid, myLevel = 11, theirLevel = 11,
        zone = "Mulgore", mapID = 1412, x = 0.45, y = 0.55 },
    { type = "whisper_in", time = t0 + 6500, me = SELF.guid, excerpt = "ty! inviting", zone = "The Barrens" },
}
ns.TouchSeen()
Check(ns.Glimpse.Of(N) ~= nil, "setup: Numa has no glimpse")
Eq(ns.Diary.Count(), 0, "setup: the diary not empty")

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
local book = ns.UI.JournalFrame()
local journal = J.journal
local p = journal.profile

local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Top() return Pad.Top() and Pad.Top().key end
local function At() return Pad.Top().focus:Current() end
local function Legend()
    local out = {}
    local s = Pad.Top()
    while s do
        for _, e in ipairs(s.legend and s.legend(s) or {}) do
            local key = type(e[1]) == "table" and e[1][1] or e[1]
            if out[key] == nil then out[key] = e[2] end
        end
        s = s.parent and Pad.Scope(s.parent)
    end
    return out
end
-- The item of the top scope whose control (or key) is `what`.
local function Find(what, group)
    local f = Pad.Top().focus
    for _, name in ipairs(f.order) do
        if not group or name == group then
            for _, it in ipairs(f.groups[name].items) do
                if it.control == what or it.key == what then return it end
            end
        end
    end
end
local function Onto(what, group)
    local it = Find(what, group)
    return it ~= nil and Pad.Top().focus:Focus(it.key, it.group)
end
local parts = Pad.Look.parts[book]

-- The mock starts every frame hidden; the client starts it shown. Every
-- frame under `root` never told either way is shown, as in the client (as
-- tests/tour.lua reads them), and the pad looks again.
local function Wake(root)
    for _, child in ipairs({ root:GetChildren() }) do
        if child.recorded and child.recorded.toldShown == nil then child.shown = true end
        Wake(child)
    end
    Pad.Refresh()
end

--------------------------------------------------------------------------
Section("an empty diary: the key and the link walked")

local welcome = journal.welcome
Check(welcome:IsShown(), "setup: the empty page not shown")
Wake(welcome)
Eq(Top(), "people", "the People page's scope has not the pad on an empty diary")
local setter = welcome.key
Eq(At().kind, "setter", "the pad not on the key")
Check(parts.pen:IsShown(), "the key's link not boxed")
Eq(Legend().PAD1, "Choose a keyboard key", "A's prompt does not say the keyboard")
Press("PAD1")
Check(setter.listening, "A did not listen for a key")
Eq(Legend().PAD2, "Stop listening", "B's prompt while listening")
Eq(At().kind, "setter", "listening moved the pad off the key")
Press("PAD2")
Check(not setter.listening, "B did not stop the listening")
Check(book:IsShown(), "B while listening closed the book")
Press("PADDDOWN")
Eq(At().kind, "link", "down from the key not the Recently nearby link")
Eq(At().control, welcome.nearby, "not the Recently nearby link")
Eq(Legend().PAD1, "Choose", "A's prompt on the link")

--------------------------------------------------------------------------
Section("a glimpse: opened from elsewhere, the pad on it; walked")

ns.UI.SelectPerson(N)
Eq(J.glimpse, N, "setup: the glimpse not open")
local glimpse = journal.glimpse
Check(glimpse:IsShown(), "setup: the glimpse not shown")
-- (its name and seen line are never told: shown, as in the client)
for _, fs in ipairs({ glimpse.name, glimpse.seen }) do
    if fs.recorded and fs.recorded.toldShown == nil then fs.shown = true end
end
Wake(glimpse.frame)
Pad.Scope("people").focus:Remember("glimpse", "g:name")
Pad.Refresh()
Eq(At().group, "glimpse", "the pad not on the glimpse")
Eq(At().key, "g:name", "the pad not on their name")
Check(Red(glimpse.name), "their name not red")
local walked = {}
for _ = 1, 20 do
    walked[#walked + 1] = At().key
    local was = At()
    Press("PADDDOWN")
    if At() == was then break end
end
local seq = table.concat(walked, " ")
Check(seq:find("g:first", 1, true) or seq:find("g:hinge", 1, true), "no pencilled note walked: " .. seq)
Check(seq:find("g:seen", 1, true), "the seen line not walked: " .. seq)
Eq(At().key, "g:strip", "the foot strip not last: " .. seq)
Check(parts.outline.line:IsShown(), "the foot strip not outlined")
Check(Red(glimpse.strip.name), "the strip's heading not red")
Eq(Legend().PAD1, "Add to the diary", "A's prompt on the strip")
Eq(Legend().PAD2, "Back to the left page", "B's prompt on an empty diary's glimpse")
local note = Find("g:hinge") or Find("g:first")
Check(Pad.Top().focus:Focus(note.key, "glimpse"), "setup: onto a note")
Check(note.subhead ~= nil and Red(note.subhead), "the note's heading not red over it")
Press("PAD2")
Eq(At().group, "left", "B on the glimpse not back on the left page")
Press("PADDRIGHT")
Eq(At().group, "glimpse", "right from the left page not the glimpse")
if Find("g:print") then
    Check(Pad.Top().focus:Focus("g:print", "glimpse"), "setup: onto the print")
    Press("PAD1")
    if At().group == "marks" then
        Check(parts.pen:IsShown(), "a mark not ringed")
        Press("PAD2")
        Eq(At().key, "g:print", "B among the marks not back on the print")
    end
end

--------------------------------------------------------------------------
Section("a glimpse: A on the strip adds them; their page, the pad on their name")

Check(Pad.Top().focus:Focus("g:strip", "glimpse"), "setup: onto the strip")
Press("PAD1")
Check(ns.Diary.Get(N) ~= nil, "A on the strip did not add them")
Eq(J.selected, N, "their page not open")
Eq(J.glimpse, nil, "the glimpse still open")
Check(not welcome:IsShown(), "the empty page still shown")
Eq(Top(), "people", "the People page's scope has not the pad")
Eq(At().key, "header", "the pad not on their name")
Press("PAD2")
Eq(At().key, "person:" .. N, "B not back on their row")

--------------------------------------------------------------------------
Section("writing mode: in from the edit tab, its controls found")

SlashCmdList.SOCIALDIARY("testdata")
-- (invented people, for the link card to list)
for i = 1, 4 do
    local guid = ("Player-0000-%08X"):format(0xB0000 + i)
    ns.Characters.Observe(guid, { first = ("Penfriend%02d"):format(i), level = 12, faction = "Horde" })
    ns.Diary.Add(guid, { source = "test" })
end
ns.UI.SelectPerson(N)
Pad.Scope("people").Open(N)
Eq(At().group, "page", "setup: on their page")
Check(Pad.Top().focus:Focus("tab:edit", "tabs"), "the edit tab not walked")
Eq(Legend().PAD1, "Write about them", "A's prompt on the edit tab")
Check(Find("tab:note", "tabs") ~= nil, "the note tab not walked")
Press("PAD1")
Check(J.editing, "A on the edit tab did not open writing")
Wake(p.form)
Eq(Top(), "writing", "writing's scope has not the pad")
Eq(At().kind, "chip", "the pad not on the first tag")
Check(parts.pen:IsShown(), "the tag not boxed")
Check(Red(p.form.tagsLabel), "the tags' label not red over a tag")
local kinds, form = {}, p.form
for _, it in ipairs(Pad.Top().focus.groups.form.items) do kinds[#kinds + 1] = it.kind end
Check(#kinds >= 6, "too few controls found")
local fields = 0
for _, k in ipairs(kinds) do if k == "field" then fields = fields + 1 end end
Eq(fields, 3, "the three lines (a tag, relationship, note) not found")
Check(Find(form.done) and Find(form.remove), "Done and Remove not found")
Eq(Legend().PAD2, "Done writing", "B's prompt in writing mode")
Eq(Legend().PADLSHOULDER, "Turn the page", "the ribbons not still the book's")

--------------------------------------------------------------------------
Section("tags: A puts one on and takes it off; a tag of your own, added and removed")

local chip = At().control
local tag = chip.tag
local had = ns.Diary.HasTag(N, tag)
Eq(Legend().PAD1, had and "Take the tag off" or "Add the tag", "A's prompt on a tag")
Press("PAD1")
Eq(ns.Diary.HasTag(N, tag), not had, "A did not toggle the tag")
Eq(At().key, "tag:" .. tag, "the pad left the tag")
Press("PAD1")
Eq(ns.Diary.HasTag(N, tag), had, "A again did not toggle it back")
Check(Onto(form.addTag), "setup: onto the line to add a tag")
Press("PAD1")
Check(form.addTag:HasFocus(), "A did not give the tag line the cursor")
form.addTag:SetText("padfriend")
form.addTag:GetScript("OnEnterPressed")(form.addTag)
Check(ns.Diary.HasTag(N, "padfriend"), "the tag not added")
local own = Find("tag:padfriend")
Check(own ~= nil, "the new tag not walked")
Check(Pad.Top().focus:Focus(own.key, "form"), "setup: onto it")
Eq(Legend().PAD1, "Take the tag off", "A's prompt on a tag of your own")
Press("PAD1")
Check(not ns.Diary.HasTag(N, "padfriend"), "A did not remove the tag")

--------------------------------------------------------------------------
Section("a line: A gives it the cursor, B takes it back; B again leaves, keeping it")

Check(Onto(form.relationship), "setup: onto the relationship")
Check(Red(form.relLabel), "its label not red over it")
Eq(Legend().PAD1, "Write", "A's prompt on a line")
Press("PAD1")
Check(form.relationship:HasFocus(), "A did not give the line the cursor")
Eq(Legend().PAD1, "Done writing", "A's prompt while writing")
Eq(Legend().PAD2, "Stop writing", "B's prompt while writing")
form.relationship:SetText("pad pal")
Press("PAD2")
Check(not form.relationship:HasFocus(), "B did not stop writing")
Check(J.editing, "B while writing left writing mode")
-- (the client's ClearFocus runs OnEditFocusLost, which saves the line; the
-- mock's does not)
form.relationship:GetScript("OnEditFocusLost")(form.relationship)
Eq(ns.Diary.Get(N).relationship, "pad pal", "the line not kept")
Check(Onto(form.note), "setup: onto the note")
Check(Red(form.noteLabel), "the note's label not red over it")
Press("PAD1")
Check(form.note:HasFocus(), "A did not give the note the cursor")
Press("PADDUP")
Check(not form.note:HasFocus(), "moving off the note kept the cursor")
Press("PAD2")
Check(not J.editing, "B did not leave writing mode")
Eq(Top(), "people", "the People page's scope not back")
Eq(At().key, "tab:edit", "the pad not back on the edit tab")
Eq(ns.Diary.Get(N).relationship, "pad pal", "leaving lost what was written")

--------------------------------------------------------------------------
Section("writing opened elsewhere lands on the form; Remove asks, the pad steps aside")

J.Edit(N)
Eq(Top(), "writing", "writing from elsewhere: not its scope")
Eq(At().kind, "chip", "writing afresh not on the first control")
Check(Onto(form.remove), "setup: onto Remove")
local popups = #mock.popups
Press("PAD1")
Eq(#mock.popups, popups + 1, "A on Remove did not ask")
Eq(mock.popups[#mock.popups].which, "SOCIAL_DIARY_REMOVE", "not the removal's popup")
local dialog = StaticPopupDialogs.SOCIAL_DIARY_REMOVE
local popup = {}
dialog.OnShow(popup)
Check(Pad.Top() == nil, "a scope has the pad with the popup up")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher takes buttons from the popup")
dialog.OnHide(popup)
Eq(Top(), "writing", "the pad not back in writing after the popup")
Eq(At().control, form.remove, "the pad not back on Remove")
Check(ns.Diary.Get(N) ~= nil, "cancelled, and they went")

--------------------------------------------------------------------------
Section("the mouse taking over in writing mode; the pad brings it back")

Check(Onto(form.relationship), "setup: onto the relationship")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not parts.pen:IsShown(), "the box left up")
Check(not Red(form.relLabel), "the label left red")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher still on")
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Eq(At().control, form.relationship, "the pad not back where it was")
Check(parts.pen:IsShown(), "the box not back")
Press("PAD2")
Check(not J.editing, "B did not leave writing")

--------------------------------------------------------------------------
Section("the note's sheet: opened from the note tab, the pad on the box, waiting for A")

local sheet = p.noteSheet
Check(Pad.Top().focus:Focus("tab:note", "tabs"), "setup: onto the note tab")
Eq(Legend().PAD1, "Add a note", "A's prompt on the note tab")
Press("PAD1")
Check(sheet:IsShown(), "A on the note tab did not lay the sheet")
Wake(sheet.sheet)
Eq(Top(), "note", "the note's scope has not the pad")
Eq(At().kind, "field", "the pad not on the box")
Check(not sheet.box:HasFocus(), "the box took the cursor with the pad in hand")
Check(parts.pen:IsShown(), "the box not boxed")
Eq(Legend().PADLSHOULDER, nil, "the ribbons turn under the sheet")
Check(Find(sheet.save) and Find(sheet.cancel) and Find(sheet.link), "Save, Cancel and the link not found")
Press("PAD1")
Check(sheet.box:HasFocus(), "A did not give the box the cursor")
sheet.box:SetText("We fought the pad together.")
Press("PAD2")
Check(not sheet.box:HasFocus(), "B did not stop writing")
Check(sheet:IsShown(), "B while writing put the sheet away")
Eq(Legend().PAD2, "Put the note away", "B's prompt on the sheet")
Press("PAD2")
Check(not sheet:IsShown(), "B did not put the sheet away")
Eq(J.tab, "timeline", "the page not back on their story")
Eq(Top(), "people", "the People page's scope not back")
Eq(At().key, "tab:note", "the pad not back on the note tab")
Press("PAD1")
Eq(sheet.box:GetText(), "We fought the pad together.", "the draft not kept")

--------------------------------------------------------------------------
Section("the link card: the pad on the first person, A links; search and pick")

Check(Onto(sheet.link), "setup: onto the link")
Press("PAD1")
local card = sheet.picker
Check(card:IsShown(), "A on the link did not lay the card")
Wake(card.sheet)
Eq(Top(), "links", "the card's scope has not the pad")
Eq(At().kind, "row", "the pad not on the first person")
local first = At().guid
Eq(Legend().PAD1, "Link them", "A's prompt on a person")
Press("PAD1")
Check(card.ctx.linked(first), "A did not link them")
Eq(At().guid, first, "the pad left them")
Eq(Legend().PAD1, "Unlink them", "A's prompt on someone linked")
for _ = 1, 10 do Press("PADDUP") end
Eq(At().kind, "field", "up off the people not the search")
Press("PAD1")
Check(card.search:HasFocus(), "A did not give the search the cursor")
card.search:SetText("Padfr")
card.search:GetScript("OnTextChanged")(card.search)
local rows = 0
for _, it in ipairs(Pad.Top().focus.groups.card.items) do if it.kind == "row" then rows = rows + 1 end end
Eq(rows, 0, "the rows not narrowed to nobody")
card.search:SetText("")
card.search:GetScript("OnTextChanged")(card.search)
Press("PAD2")
Check(not card.search:HasFocus(), "B did not stop writing in the search")
Press("PADDDOWN")
Eq(At().kind, "row", "down from the search not into the people")
Press("PADDDOWN")
local second = At().guid
Check(second ~= nil and second ~= first, "down did not walk the people")
Press("PAD1")
Check(card.ctx.linked(second), "A did not pick the second")
Eq(Legend().PAD2, "Back to the note", "B's prompt on the card")
Press("PAD2")
Check(not card:IsShown(), "B did not put the card away")
Eq(Top(), "note", "the note's scope not back")
Eq(At().control, sheet.link, "the pad not back on the link")

--------------------------------------------------------------------------
Section("faces: A on one with a cross unlinks them")

local face = Find("face:" .. second)
Check(face ~= nil and face.kind == "crossed", "the linked face not walked")
Check(Pad.Top().focus:Focus(face.key, "sheet"), "setup: onto the face")
Eq(Legend().PAD1, "Unlink them", "A's prompt on a face")
Check(parts.pen:IsShown(), "the face not ringed")
Press("PAD1")
Check(Find("face:" .. second) == nil, "A did not unlink them")
local mine = Find("face:" .. N)
Check(mine ~= nil and mine.kind == "face", "their own face not walked")

--------------------------------------------------------------------------
Section("Save: the note written, the sheet gone, the pad back on the page")

local before = #ns.Notes.For(N)
Check(Onto(sheet.save), "setup: onto Save")
Press("PAD1")
Check(not sheet:IsShown(), "Save did not put the sheet away")
Eq(#ns.Notes.For(N), before + 1, "the note not written")
Eq(Top(), "people", "the People page's scope not back after Save")
Eq(At().key, "tab:note", "the pad not back on the note tab after Save")

--------------------------------------------------------------------------
Section("B on the left page still closes the book")

Press("PAD2")
Eq(At().group, "left", "B not on the left page")
Press("PAD2")
Check(not book:IsShown(), "B on the left page did not close the book")
