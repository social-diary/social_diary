-- The journal: its query layer, the window with the People pages, and the
-- Recently nearby page.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF

--------------------------------------------------------------------------
Section("the journal's query layer (JNL-1, JNL-2)")

mock.now = 1791000000
local now = mock.now
local A, B, C = F.STRANGER.guid, F.GARRICK.guid, F.PUG.guid

-- Observed in full first, so the diary adds have names to show.
ns.Characters.Observe(A, { first = "Bram", surname = "Redfen", level = 12, faction = "Horde" })
ns.Characters.Observe(B, { first = "Garrick", surname = "Fallow", level = 20, faction = "Alliance" })
ns.Characters.Observe(C, { first = "Norwood", surname = "Sparks", level = 10, faction = "Horde" })
ns.Diary.Add(A, { source = "test", tags = { "friend" }, relationship = "questing buddy",
    note = "helped me with Nagas" })
ns.Diary.Add(B, { source = "test", tags = { "foe" } })
ns.Diary.Add(C, { source = "test" })

ns.db.sessions[101] = {
    id = 101, me = SELF.guid, source = "group",
    startedAt = now - 10 * DAY, endedAt = now - 10 * DAY + 3600,
    participants = { [A] = { since = now - 10 * DAY, last = now - 10 * DAY + 3600,
        seconds = 3600, levelStart = 8, levelEnd = 10, quests = { 1, 2 } } },
    others = 0, zones = { "Mulgore", "The Barrens" }, deaths = {},
}
ns.db.sessions[102] = {
    id = 102, me = SELF.guid, source = "group",
    startedAt = now - 2 * DAY, endedAt = now - 2 * DAY + 600,
    participants = {
        [A] = { since = now - 2 * DAY, last = now - 2 * DAY + 600, seconds = 600, levelStart = 11 },
        [B] = { since = now - 2 * DAY, last = now - 2 * DAY + 300, seconds = 300, levelStart = 20 },
    },
    others = 2, zones = { "Thunder Bluff" }, deaths = { [SELF.guid] = 1 },
}

-- A meeting before they were in the diary, a highlight inside session 102,
-- and a leave row that the timeline hides.
ns.Interactions.Add(A, "trade", { time = now - 40 * DAY, theirLevel = 5,
    context = { given = { { link = "[Linen Cloth]", count = 5 } }, moneyReceived = 12345 } })
ns.db.interactions[A][#ns.db.interactions[A]].zone = "Durotar"
ns.Interactions.Add(A, "whisper_in", { time = now - 2 * DAY + 60, excerpt = "ty!" })
ns.db.interactions[A][#ns.db.interactions[A]].session = 102
ns.Interactions.Add(A, "group_leave", { time = now - 3 * DAY })

local sa = ns.People.Stats(A)
Eq(sa.timesMet, 3, "times met: two sessions and a trade")
Eq(sa.firstMet, now - 40 * DAY, "first met")
Eq(sa.lastMet, now - 2 * DAY + 600, "last met")
Eq(sa.seconds, 4200, "time together")
Eq(sa.levelThen, 5, "level at the first meeting")
Eq(sa.levelNow, 12, "level now")
Check(sa.zones.Durotar and sa.zones["The Barrens"], "zones met in")
Eq(ns.People.Stats(C).timesMet, 0, "never met")
Eq(ns.People.Stats(C).levelThen, 10, "level then falls back to the level when added")

local function Names(list)
    local out = {}
    for i = 1, #list do out[i] = list[i].name end
    return table.concat(out, ",")
end

Eq(Names(ns.People.Query({})), "Bram Redfen,Garrick Fallow,Norwood Sparks", "sorted by last met")
Eq(Names(ns.People.Query({ sort = "name" })), "Bram Redfen,Garrick Fallow,Norwood Sparks", "by name")
Eq(Names(ns.People.Query({ sort = "together" })), "Bram Redfen,Garrick Fallow,Norwood Sparks", "by time")
Eq(Names(ns.People.Query({ search = "NAGAS" })), "Bram Redfen", "search the note")
Eq(Names(ns.People.Query({ search = "foe" })), "Garrick Fallow", "search the tags")
Eq(Names(ns.People.Query({ search = "sparks" })), "Norwood Sparks", "search the surname")
Eq(Names(ns.People.Query({ search = "nobody" })), "", "search with no match")
Eq(Names(ns.People.Query({ tag = "friend" })), "Bram Redfen", "tag filter")
Eq(Names(ns.People.Query({ relationship = "questing buddy" })), "Bram Redfen", "relationship filter")
Eq(Names(ns.People.Query({ faction = "Alliance" })), "Garrick Fallow", "faction filter")
Eq(Names(ns.People.Query({ zone = "Durotar" })), "Bram Redfen", "zone filter")
Eq(Names(ns.People.Query({ withinDays = 7 })), "Bram Redfen,Garrick Fallow", "last met filter")

-- Search is plain text, not a Lua pattern.
Eq(Names(ns.People.Query({ search = "(" })), "", "a pattern character in the search broke it")

local facets = ns.People.Facets()
Eq(table.concat(facets.tags, ","), "foe,friend", "tag facets")
Eq(table.concat(facets.factions, ","), "Alliance,Horde", "faction facets")

-- The profile timeline: newest first, episodes carrying what happened in
-- them (TLN-1). A whisper in a session is chatter: counted, not a line.
local timeline = ns.Timeline.For(A)
local kinds = {}
for i = 1, #timeline do kinds[i] = timeline[i].kind end
Eq(table.concat(kinds, ","), "added,session,session,row", "timeline order")
Eq(timeline[2].all[1].row.type, "whisper_in", "the highlight inside its session")
Eq(#timeline[2].lines, 0, "chatter shown as a line of a folded session")
Eq(timeline[2].hidden, 1, "folded-away count")
Eq(timeline[2].all[1].depth, 1, "a session's rows not one level in")

local _, text, sub = ns.UI.DescribeItem(timeline[3], A)
Eq(text, "Quested together in Mulgore and The Barrens for 1 h; Bram reached lv 10", "questing session line")
Eq(sub, "2 quests", "session details: the level is the headline's")
_, text = ns.UI.DescribeItem(timeline[4], A)
Check(text:find("gave 5x %[Linen Cloth%]") and text:find("got 1g 23s 45c"), "trade line: " .. text)
_, text = ns.UI.DescribeItem(timeline[2].all[1], A)
Check(text:find('"ty!"'), "whisper line: " .. text)
_, text, sub = ns.UI.DescribeItem(timeline[2], A)
Eq(text, "Kept company in Thunder Bluff", "a session in a capital, under 15 min")
Eq(sub, "1 death", "a single message is not counted on the session's details")

-- Item and chat colours are for dark backgrounds; on parchment they get ink.
Eq(ns.Style.Inkify("|cffffffff|Hitem:2589|h[Linen Cloth]|h|r"), "|cff211408|Hitem:2589|h[Linen Cloth]|h|r",
    "a white item link inked")
Eq(ns.Style.Inkify("|cnIQ2:|Hitem:1|h[x]|h|r"), "|cff1d5d12|Hitem:1|h[x]|h|r", "a quality code inked")
Eq(ns.Style.Inkify("|cff3d2912dark|r"), "|cff3d2912dark|r", "dark colours are left alone")

--------------------------------------------------------------------------
Section("the journal window (JNL-1, JNL-2, JNL-4, JNL-6)")

-- The People sort is a saved preference: a sort picked before a reload
-- is the one the page is built with.
ns.SetSetting("peopleSort", "together")

ns.UI.ShowJournal()
local J = _G.SocialDiaryJournalFrame
Check(J:IsShown(), "the journal did not open")
Eq(J.count:GetText(), "3 in the diary", "people count")
Eq(J.sortButton:GetText(), "time together", "the saved sort was not restored")
J.sortButton:Click()
mock.MenuClick("Last met")
Eq(ns.Setting("peopleSort"), "lastMet", "picking a sort did not save it")

-- The ribbons are the journal's pages: Your Diary (green) open by default
-- once the front matter has been read (JRN-16), People (red) next.
Check(J.views.journey:IsShown() and not J.views.people:IsShown(), "Your Diary is not the first page")
Check(J.ribbons.journey.active and not J.ribbons.people.active, "the open page's ribbon is not marked")
J.ribbons.people:Click()
Check(J.views.people:IsShown() and not J.views.nearby:IsShown(), "the red ribbon did not turn to People")
Check(J.ribbons.people.active and not J.ribbons.nearby.active, "People's ribbon is not marked")
J.ribbons.nearby.scripts.OnEnter(J.ribbons.nearby)
Eq(GameTooltip.text, "Recently nearby", "ribbon tooltip")
J.ribbons.nearby.scripts.OnLeave(J.ribbons.nearby)
J.ribbons.nearby:Click()
Check(J.views.nearby:IsShown() and not J.views.people:IsShown(), "the purple ribbon did not turn the page")
Check(J.ribbons.nearby.active and not J.ribbons.people.active, "ribbons not swapped")
Check(ns.UI.NearbyPage.dayCount:GetText():find("days?$"), "Recently nearby day count: "
    .. tostring(ns.UI.NearbyPage.dayCount:GetText()))
Eq(ns.UI.JournalView(), "nearby", "view not kept")

-- The page stays open across a close; opening on a person goes to People.
ns.UI.CloseJournal()
ns.UI.ShowJournal()
Check(J.views.nearby:IsShown(), "closing the journal forgot the open page")
ns.UI.ShowJournal(A)
Check(J.views.people:IsShown(), "opening on a person did not turn to People")
J.ribbons.nearby:Click()
J.ribbons.people:Click()
Check(J.views.people:IsShown() and J.ribbons.people.active, "the red ribbon did not turn back")
ns.UI.SelectPerson(nil)

-- The stack beneath follows the page and the diary: four pages of its
-- own and one per entry (three here), two flyleaves at the back. Your
-- Diary is the first page, People the second, Recently nearby and the
-- settings at the back.
local function Stack() return J.book.stackPages[1] .. "/" .. J.book.stackPages[2] end
Eq(Stack(), "1/7", "People's stack")
J.ribbons.journey:Click()
Eq(Stack(), "0/8", "Your Diary's stack")
J.ribbons.nearby:Click()
Eq(Stack(), "5/3", "Recently nearby's stack")
J.ribbons.settings:Click()
Eq(Stack(), "6/2", "the settings' stack")
J.ribbons.people:Click()
Eq(Stack(), "1/7", "the stack did not move back for People")

-- The entries' pages are leafed through in the order they are read: the
-- first person opened lies on the page after People's, the next after
-- that, and someone read again turns back to theirs. Nobody selected opens
-- the book on People's own. A book opened afresh starts over.
ns.UI.CloseJournal()
ns.UI.ShowJournal()
ns.UI.SelectPerson(B)
Eq(Stack(), "2/6", "the first entry read")
ns.UI.SelectPerson(A)
Eq(Stack(), "3/5", "the second entry read: one page on")
ns.UI.SelectPerson(B)
Eq(Stack(), "2/6", "the first entry again: back to its page")
ns.UI.SelectPerson(C)
Eq(Stack(), "4/4", "the third entry read: the next page, not the back")
J.ribbons.settings:Click()
Eq(Stack(), "6/2", "the settings' stack with someone selected")
J.ribbons.people:Click()
Eq(Stack(), "4/4", "back on People: the selected entry's page again")
ns.UI.SelectPerson(nil)
Eq(Stack(), "1/7", "nobody selected: People's own page")

-- Read past the pages there are, the rest share the last.
local Count = ns.Diary.Count
ns.Diary.Count = function() return 1 end
ns.UI.SelectPerson(C)
Eq(Stack(), "2/4", "more read than pages: the last entry page")
ns.Diary.Count = Count
ns.UI.SelectPerson(nil)

ns.UI.CloseJournal()
ns.UI.ShowJournal()
ns.UI.SelectPerson(C)
Eq(Stack(), "2/6", "reopened, the book starts over")
ns.UI.SelectPerson(nil)

-- It grows up to 25 pages; past six on a side the edges get finer, so the
-- stack keeps to its room and the board's shadow to its edge.
ns.Diary.Count = function() return 40 end
ns.UI.RefreshJournal()
Eq(Stack(), "1/25", "a full diary's stack")
local leftIn, rightIn = J.book:SetStack(24, 2)
Check(leftIn > -1 and leftIn < 1, "a full side overran its room: " .. leftIn)
Check(rightIn > 6 and rightIn < 10, "two pages on a side: " .. rightIn)
ns.Diary.Count = Count
ns.UI.RefreshJournal()
Eq(Stack(), "1/7", "the stack did not shrink back with the diary")

-- The list is grouped: a heading row, then people under it.
local function PersonRows()
    local rows = {}
    for i = 1, #J.people.rows do
        local row = J.people.rows[i]
        if row:IsShown() and row.item and row.item.guid then rows[#rows + 1] = row end
    end
    return rows
end
local function Headings()
    local list = {}
    for i = 1, #J.people.data do
        if J.people.data[i].header then list[#list + 1] = J.people.data[i].header end
    end
    return table.concat(list, ",")
end
-- The profile's own line at the top of its list: the plate, the facts'
-- strips and your note (UI/Journal/Clippings.lua).
local function Block(P) return P.clippings end

Eq(J.people.data[1].header, "This week", "first group heading")
Eq(J.people.rows[1].header:GetText(), "THIS WEEK", "headings are set in capitals")
Eq(Headings(), "This week,No Interactions yet", "group headings")
local people = PersonRows()
Eq(#people, 3, "people rows")
Check(people[1].name:GetText():find("Bram Redfen"), "first person")
Eq(people[1].detail:GetText(), "yesterday", "last met on the row (1 day 23 h ago)")
Eq(people[3].detail:GetText(), "", "the never-met row leaves the date to its heading")
Check(not J.people.rows[6]:IsShown(), "an empty people row is showing")
J.people.rows[1]:Click()
Check(J.profile:IsShown() == false or J.profile.name:GetText() == "", "clicking a heading selected someone")

people[1]:Click()
local P = J.profile
-- The name sheet: their name as written (Goodmountain, mixed case).
Eq(P.name:GetText(), "Bram Redfen", "profile heading, as written")
Eq(P.name.recorded.calls.SetFontObject[1], ns.Style.FONT.personName, "the name is not in Goodmountain")
Check(P.chips[1]:IsShown() and P.chips[1].label:GetText() == "friend", "tag chip")
Eq(P.relationship:GetText(), "questing buddy", "relationship")
-- No summary paragraph: the facts are strips (the old story's "You first
-- met Bram in Durotar ... when they were level 5", "crossed paths 3
-- times", "level 12 now").
local CL = Block(P)
Check(CL.first:IsShown() and CL.first.name:GetText():find("^First met "), "no first-met strip: "
    .. tostring(CL.first.name:GetText()))
Eq(CL.first:What(), "at level 5", "the first-met strip's level then")
Eq(CL.tally.name:GetText(), "Met 3 times", "the tally strip")
Check(CL.level:IsShown() and CL.level.struck == "5" and CL.level.written == "12", "the level tag: 5 struck, 12 written")
Check(CL.note:Written():find("Nagas"), "note")

-- The list starts with that one tall line, from behind the name sheet,
-- and scrolls by the pixel.
local lines = P.timeline.data
Eq(lines[1].clippings, CL, "the list does not start with the plate and the facts")
Check(lines[1].height and lines[1].height > 100, "the top block is not one tall line")
for _, line in ipairs(lines) do
    Check(line.prose == nil and line.rule == nil, "a summary line is still in the list")
end
local PAGE = 1
Eq(P.timeline.recorded.points[1].args[1], P, "the list is not on the page")
Eq(P.timeline.recorded.points[1].args[4], -ns.UI.PersonHeader.SHEET.listTop, "the list does not start behind the sheet")
Eq(P.timeline.smooth, 534 - ns.UI.PersonHeader.SHEET.listTop, "the list does not scroll by the pixel to the foot")

-- Timeline: a day heading per day, a details line under a session.
local headers, added, session = 0, nil, nil
for i = 1, #lines do
    if lines[i].header then headers = headers + 1 end
    if lines[i].text and lines[i].text:find("^Added") then added = i end
    if lines[i].item and lines[i].item.kind == "session" and not session then session = i end
end
Check(headers >= 1, "no day headings")
Eq(lines[PAGE + 1].header ~= nil, true, "the timeline starts with a day heading")
Check(added, "no 'Added to the diary' line")
Check(lines[session + 1].font == ns.Style.FONT.small, "no details line under the session")
Eq(#lines, PAGE + 4 + headers + 2 + 1,
    "timeline lines (4 items, headings, 2 details lines, the gap under a folded bracket)")
Eq(lines[PAGE + 1].day, 1, "the first day heading is not counted, for its paraph")

local sessionRow
for i = 1, #P.timeline.rows do
    local row = P.timeline.rows[i]
    if row:IsShown() and row.item and row.item.item and row.item.item.kind == "session" then sessionRow = row; break end
end
Check(sessionRow, "no session row on screen")
sessionRow.scripts.OnEnter(sessionRow)
Check(GameTooltip.text and GameTooltip.text:find("Kept company in Thunder Bluff"), "the tooltip does not show the full line")
Check(GameTooltip.text:find("Click to show all 1"), "the tooltip does not say the session opens")
Check(people[1].selected:IsShown(), "the selected row is not marked")

-- Live search.
J.search:SetText("nagas")
J.search.scripts.OnTextChanged(J.search)
Eq(J.count:GetText(), "1 of 3", "search did not filter")
J.search:SetText("")
J.search.scripts.OnTextChanged(J.search)
Eq(J.count:GetText(), "3 in the diary", "clearing the search")

-- Sort and filter through their menus.
Eq(J.sortButton:GetText(), "last met", "sort link")
J.sortButton:Click()
Check(mock.MenuClick("Times met"), "no 'Times met' sort")
Eq(J.sortButton:GetText(), "times met", "sort link label")
Eq(ns.Setting("peopleSort"), "timesMet", "the sort was not saved")
Eq(PersonRows()[1].detail:GetText(), "3 times", "the row detail follows the sort")
Eq(J.people.data[1].header, nil, "by times met, the met need no heading")
J.sortButton:Click()
Eq(mock.MenuSelected("Times met"), true, "the current sort is not marked")
mock.MenuClick("Last met")

Eq(J.filterButton:GetText(), "All people", "filter link")
J.filterButton:Click()
Check(mock.MenuClick("Tag", "foe"), "no 'foe' under Tag")
Eq(J.count:GetText(), "1 of 3", "tag filter from the menu")
Eq(J.filterButton:GetText(), "1 filter", "active filter count")
Check(J.filters:GetText():find("tag: foe"), "active filters not listed")
J.filterButton:Click()
Check(mock.MenuClick("Clear filters"), "no clear")
Eq(J.count:GetText(), "3 in the diary", "clearing filters")

-- JNL-6: a large diary costs no extra frames, and scrolling stays in bounds.
local framesBefore = #mock.frames
for i = 1, 1200 do
    local guid = ("Player-9999-%08X"):format(i)
    ns.db.characters[guid] = { guid = guid, names = { { first = "Filler" .. i, surname = "Test" } } }
    ns.db.diary[guid] = { guid = guid, addedAt = now - i, tags = {}, addedContext = {} }
end
for i = 1, 10000 do
    local guid = ("Player-9999-%08X"):format(i % 1200 + 1)
    ns.db.sessions[1000 + i] = {
        id = 1000 + i, me = SELF.guid, startedAt = now - i * 60, endedAt = now - i * 60 + 30,
        participants = { [guid] = { since = now - i * 60, last = now - i * 60 + 30, seconds = 30 } },
        others = 0, zones = { "Mulgore" }, deaths = {},
    }
end
-- Written past the modules, so the data version is moved by hand.
ns.Touch()

local started = os.clock()
ns.UI.RefreshJournal()
local elapsed = os.clock() - started
Eq(#mock.frames, framesBefore, "the lists created frames per entry")
Eq(J.count:GetText(), "1203 in the diary", "large diary count")
Check(elapsed < 0.5, ("refresh over 1,203 entries and 10,000 sessions took %.3fs"):format(elapsed))

J.people.scripts.OnMouseWheel(J.people, -1)
Eq(J.people.offset, 3, "mouse wheel scroll")
J.people.bar:SetValue(1000)
Eq(J.people.offset, 1000, "scrollbar drag")
Eq(J.people.rows[1].item, J.people.data[1001], "rows follow the offset")
local rowsShown, lineCount = J.people.numRows, #J.people.data
J.people.bar:SetValue(50000)
Eq(J.people.offset, lineCount - rowsShown, "scrolled past the end")
Eq(J.people.rows[rowsShown].item, J.people.data[lineCount], "the last row is the last item")

for i = 1, 1200 do
    local guid = ("Player-9999-%08X"):format(i)
    ns.db.characters[guid], ns.db.diary[guid] = nil, nil
end
for i = 1, 10000 do ns.db.sessions[1000 + i] = nil end
ns.Touch()
ns.UI.RefreshJournal()
Eq(J.count:GetText(), "3 in the diary", "filler not cleaned up")

-- Edit turns the right page to writing mode, in the journal, not a dialog.
ns.UI.SelectPerson(A)
J.profile.edit:Click()
local form = J.profile.form
Check(form:IsShown() and not J.profile.timeline:IsShown(), "Edit did not turn the page to writing mode")
local sheet = _G.SocialDiaryEntryFrame  -- built only once something opens it
Check(not (sheet and sheet:IsShown()), "Edit opened the loose sheet over the journal")
Check(not J.profile.edit:IsShown(), "the Edit link still shows while writing")
Check(not form.note:HasFocus(), "Edit grabbed the keyboard")
form.presets.helper:Click()
form.done:Click()
Check(not form:IsShown() and J.profile.timeline:IsShown(), "Done did not turn the page back")
local chipFound = false
for i = 1, #J.profile.chips do
    if J.profile.chips[i]:IsShown() and J.profile.chips[i].label:GetText() == "helper" then chipFound = true end
end
Check(chipFound, "an edit on the page did not reach the profile")

-- Choosing someone else leaves writing mode.
J.profile.edit:Click()
ns.UI.SelectPerson(A)
Check(not form:IsShown(), "selecting a person stayed in writing mode")

-- DIA-11: the "Add a note" tab lays a loose sheet over the book, like the
-- map; the page stays read-only under it. A note clicked on the timeline
-- opens on the same sheet to change or delete.
do
    local P = J.profile
    local N = P.noteSheet
    local function NoteRow()
        for _, row in ipairs(P.timeline.rows) do
            if row:IsShown() and row.item and row.item.note then return row end
        end
    end
    local function Portraits()
        local list = {}
        for _, o in ipairs(N.portraits) do
            if o:IsShown() then list[#list + 1] = { guid = o.guid, cross = o.cross:IsShown() } end
        end
        return list
    end

    Check(not N:IsShown(), "the note sheet lies on the book unasked")
    P.tabNote:Click()
    Check(N:IsShown(), "the tab did not lay the note sheet on the book")
    Check(P.timeline:IsShown(), "the page under the note sheet is gone")
    Check(P.tabNote.selected and not P.tabStory.selected, "the tabs do not say the note sheet is open")
    Check(N.box:HasFocus(), "the note sheet has no cursor")
    Eq(N.title:GetText(), "A new note", "a new note's title")
    Check(not N.delete:IsShown(), "a new note offers Delete")
    Check(N.link:IsShown(), "Link others is not always offered")
    local shown = Portraits()
    Eq(#shown, 1, "portraits on a new note")
    Eq(shown[1].guid, A, "the first portrait is not the page's person")
    Check(not shown[1].cross, "the page's person can be unlinked")

    N.box:SetText("Showed me the way to Thunder Bluff.")
    N.save:Click()
    local notes = ns.Notes.For(A)
    Eq(#notes, 1, "Save did not write the note")
    Eq(notes[1].text, "Showed me the way to Thunder Bluff.", "the note's text")
    Check(not N:IsShown(), "Save did not put the sheet away")
    Check(P.tabStory.selected, "the story's tab is not open after Save")
    local row = NoteRow()
    Check(row, "the note is not on the timeline")
    Eq(row.text:GetText(), "Showed me the way to Thunder Bluff.", "the note's line on the page")

    row:GetScript("OnMouseUp")(row)
    Check(N:IsShown(), "a click on the note did not open it")
    Eq(N.box:GetText(), "Showed me the way to Thunder Bluff.", "the note did not open with its text")
    Eq(N.title:GetText(), "Your note", "a note being changed is titled as a new one")
    Check(N.delete:IsShown(), "a note being changed offers no Delete")
    N.box:SetText("Showed me the way to Thunder Bluff, twice.")
    N.save:Click()
    Eq(#ns.Notes.For(A), 1, "changing a note wrote a second one")
    Eq(notes[1].text, "Showed me the way to Thunder Bluff, twice.", "the change did not reach the note")

    -- A click beside the sheet leaves it be (the map's would put it away).
    -- Turned away from by its tab, the draft waits; Cancel throws it away.
    P.tabNote:Click()
    N.box:SetText("Half a thought")
    N:GetScript("OnMouseDown")(N)
    Check(N:IsShown() and P.tabNote.selected, "a click beside the note sheet put it away")
    P.tabStory:Click()
    Check(not N:IsShown(), "the story's tab did not turn away from the note sheet")
    Eq(#ns.Notes.For(A), 1, "turning away from the sheet wrote the note")
    P.tabNote:Click()
    Eq(N.box:GetText(), "Half a thought", "the draft was lost when the sheet was turned away from")
    N.cancel:Click()
    Eq(#ns.Notes.For(A), 1, "Cancel wrote the note")
    P.tabNote:Click()
    Eq(N.box:GetText(), "", "a cancelled draft came back")

    -- Another person's page opens on their story.
    ns.UI.SelectPerson(B)
    Check(not N:IsShown() and P.timeline:IsShown(), "the note sheet stayed open on someone else")
    ns.UI.SelectPerson(A)

    -- Link others: a card over the note listing the diary, the likely ones
    -- first, with a search. Garrick was in a session with Bram two days
    -- ago; Norwood never was.
    local L = N.picker
    local function Lines()
        local out = {}
        for _, item in ipairs(L.list.data) do
            out[#out + 1] = item.heading or ns.Characters.FullName(item.guid)
        end
        return table.concat(out, ",")
    end
    local function Pick(guid)
        for _, r in ipairs(L.list.rows) do
            if r:IsShown() and r.guid == guid then
                r:Click()
                return r
            end
        end
    end
    local function Search(text)
        L.search:SetText(text)
        L.search:GetScript("OnTextChanged")(L.search)
    end

    P.tabNote:Click()
    N.link:Click()
    Check(L:IsShown() and N:IsShown(), "Link others did not lay its card over the note")
    Check(not L.search:HasFocus(), "the card's search took the cursor, hiding its hint")
    Check(L.search.hint:IsShown(), "the card's search shows no hint")
    Check(#L.list.rows * 30 <= L.list.recorded.height, "the card's rows run past its list")
    Eq(Lines(), "WITH THEM BEFORE,Garrick Fallow,EVERYONE ELSE,Norwood Sparks", "the card's sections")
    local picked = Pick(C)
    Check(picked, "someone in the diary is not offered to link")
    Check(picked.tick.recorded and true, "a row has no tick box")
    Eq(L.count:GetText(), "1 linked", "the card's count")
    Search("norw")
    Eq(Lines(), "EVERYONE ELSE,Norwood Sparks", "the search did not narrow the card")
    Search("FOE")
    Eq(Lines(), "WITH THEM BEFORE,Garrick Fallow", "the search does not reach tags")
    Search("zzz")
    Eq(Lines(), "", "a search for nobody listed someone")
    Check(L.empty:IsShown(), "a search for nobody does not say so")
    L.done:Click()
    Check(not L:IsShown() and N:IsShown(), "Done did not put the card away, or took the note with it")
    shown = Portraits()
    Eq(#shown, 2, "portraits after linking Norwood")
    Eq(shown[2].guid, C, "the linked portrait")
    Check(shown[2].cross, "a linked portrait has no cross to unlink")
    N.portraits[2].cross:Click()
    Eq(#Portraits(), 1, "the cross did not unlink Norwood")
    N.cancel:Click()

    local sessions = {}
    for id, session in pairs(ns.db.sessions) do sessions[id] = session end
    local saved = ns.db.sessions
    sessions[103] = { id = 103, me = SELF.guid, source = "group", startedAt = mock.now - 600,
        participants = { [A] = { since = mock.now - 600, last = mock.now, seconds = 600 },
            [B] = { since = mock.now - 600, last = mock.now, seconds = 600 } },
        others = 0, zones = { "Mulgore" }, deaths = {} }
    ns.db.sessions = sessions
    P.tabNote:Click()
    N.link:Click()
    Eq(Lines(), "WITH THEM THEN,Garrick Fallow,EVERYONE ELSE,Norwood Sparks",
        "the group they are in now is not offered first")
    Check(Pick(B), "Garrick is not on the card")
    L:GetScript("OnMouseDown")(L)
    Check(not L:IsShown() and N:IsShown(), "a click beside the card did not put it away")
    N.box:SetText("Ragefire Chasm with Garrick.")
    N.save:Click()
    local group = ns.Notes.For(B)[1]
    Check(group and group.about[A] and group.about[B], "the note is not about both of them")
    P.tabNote:Click()
    Eq(#Portraits(), 1, "the next note still links Garrick")
    N.cancel:Click()

    -- Unlinked while changing it, Garrick comes off the note.
    ns.UI.Journal.EditNote(group)
    Eq(#Portraits(), 2, "a note opened to change lost whom it is about")
    N.portraits[2].cross:Click()
    N.save:Click()
    Eq(#ns.Notes.For(B), 0, "unlinking Garrick left him on the note")
    Check(group.about[A], "unlinking Garrick took Bram off the note")

    -- The card goes with the note's sheet.
    P.tabNote:Click()
    N.link:Click()
    P.tabStory:Click()
    Check(not L:IsShown(), "the card stayed on the book without its note")
    P.tabNote:Click()
    N.cancel:Click()

    -- Delete takes it out.
    ns.UI.Journal.EditNote(group)
    N.delete:Click()
    Eq(ns.Notes.Get(group.id), nil, "a deleted note is still there")
    Check(not N:IsShown(), "Delete did not put the sheet away")

    -- Edit turns the page to writing mode, and the sheet goes.
    P.tabNote:Click()
    P.edit:Click()
    Check(not N:IsShown() and not P.tabNote.selected, "the note sheet lay over writing mode")
    P.form.done:Click()

    ns.Notes.Delete(notes[1].id)
    ns.db.sessions = saved
    ns.UI.Journal.tab = "timeline"
    ns.UI.RefreshJournal()
end

-- Removing them from the page empties the profile.
J.profile.edit:Click()
form.remove:Click()
mock.AnswerPopup("accept")
Eq(J.count:GetText(), "2 in the diary", "a removed entry is still listed")
Check(not J.profile:IsShown(), "the profile of a removed entry is still showing")

-- JNL-4: the compartment and the keybind toggle it.
SocialDiary_OnCompartmentClick()
Check(not J:IsShown(), "the compartment did not close the journal")
SocialDiary_ToggleJournal()
Check(J:IsShown(), "the keybind did not open the journal")

--------------------------------------------------------------------------
Section("an empty diary's People page: three ways in")

-- An empty diary hides what there is nothing to search or sort, and
-- teaches how someone gets in instead, with a page drawn in pencil.
local savedDiary, savedRows, savedSeen = ns.db.diary, ns.db.interactions, ns.db.sightings
ns.db.diary, ns.db.sightings = {}, {}
ns.db.interactions = { [F.PUG.guid] = { { type = "trade", time = mock.now } } }
ns.UI.RefreshJournal()
local W = J.welcome
Check(W:IsShown(), "the empty diary did not show the three ways in")
Eq(J.count:GetText(), "nobody yet", "an empty diary still counts its entries")
for i, control in ipairs(J.listControls) do
    Check(not control:IsShown(), "the empty diary still shows list control " .. i)
end
Check(not J.emptyProfile:IsShown(), "the empty diary still says to choose someone")
Eq(J.emptyList:GetText(), "", "the empty diary still prints the old empty text")
Check(W.laterText:GetText():find("30 days"), "the pencil's days are not the setting's")
Check(W.laterText:GetText():find("One is there already"), "who is pencilled in already is not counted")

-- The key: unbound, it says so; bound here, out of combat, in place of
-- whatever had it.
Eq(W.key.keycap.text:GetText(), "no key", "an unbound key is not shown as unbound")
Eq(W.key.bind:GetText(), "Choose one", "an unbound key offers no way to bind it")
BINDING_NAME_OPENALLBAGS = "Open All Bags"
mock.bindings = { ["ALT-B"] = "OPENALLBAGS" }
W.key.bind:Click()
Check(W.key.listening, "Choose one did not listen for a key")
Eq(W.key.keycap.text:GetText(), "press a key", "listening is not shown on the key")
W.key.catcher.scripts.OnKeyDown(W.key.catcher, "LALT")
Check(W.key.listening, "a modifier alone ended the listening")
mock.modifiers.alt = true
W.key.catcher.scripts.OnKeyDown(W.key.catcher, "B")
mock.modifiers.alt = false
Check(not W.key.listening, "a key did not end the listening")
Eq(mock.bindings["ALT-B"], "SOCIALDIARY_REMEMBER", "the key was not bound to Remember this")
Eq(mock.bindingSaves, 1, "the binding was not saved")
Eq(W.key.keycap.text:GetText(), "ALT-B", "the bound key is not shown")
Eq(W.key.bind:GetText(), "Change", "a bound key does not offer to change it")
Check(W.keyStatus:GetText():find("Open All Bags"), "what the key did before is not said")

-- Changing it frees the old key; Escape cancels; a fight refuses.
W.key.bind:Click()
W.key.catcher.scripts.OnKeyDown(W.key.catcher, "ESCAPE")
Check(not W.key.listening, "Escape did not cancel")
Eq(mock.bindings["ALT-B"], "SOCIALDIARY_REMEMBER", "Escape changed the binding")
W.key.bind:Click()
-- Keys for typing and moving need a modifier: refused alone, still listening.
for _, key in ipairs({ "F", "W", "7", "SPACE", "ENTER", "BACKSLASH" }) do
    W.key.catcher.scripts.OnKeyDown(W.key.catcher, key)
    Check(W.key.listening, key .. " alone ended the listening")
    Eq(mock.bindings[key], nil, key .. " alone was bound")
    Check(W.keyStatus:GetText():find("Shift, Ctrl or Alt"), key .. " alone was refused without a word")
end
mock.modifiers.shift = true
W.key.catcher.scripts.OnKeyDown(W.key.catcher, "W")
mock.modifiers.shift = false
Eq(mock.bindings["SHIFT-W"], "SOCIALDIARY_REMEMBER", "a letter with a modifier was not bound")
W.key.bind:Click()
W.key.catcher.scripts.OnKeyDown(W.key.catcher, "F5")
Eq(mock.bindings["F5"], "SOCIALDIARY_REMEMBER", "the new key was not bound")
Eq(mock.bindings["SHIFT-W"], nil, "the old key still runs Remember this")
Eq(mock.bindings["ALT-B"], nil, "the old key still runs Remember this")
mock.inCombat = true
W.key.bind:Click()
Check(not W.key.listening, "it listened for a key in a fight")
Check(W.keyStatus:GetText():find("fight"), "a fight's refusal is not said")
mock.inCombat = false
W.key.bind:Click()
ns.UI.CloseJournal()
Check(not W.key.listening, "closing the book left the keyboard taken")
mock.bindings, BINDING_NAME_OPENALLBAGS = {}, nil
ns.UI.ShowJournal()

-- Recently nearby, from its link.
W.nearby:Click()
Eq(ns.UI.JournalView(), "nearby", "the Recently nearby link did not turn there")
ns.UI.SetJournalView("people")

-- The first entry takes it all away.
ns.db.diary, ns.db.interactions, ns.db.sightings = savedDiary, savedRows, savedSeen
ns.UI.RefreshJournal()
Check(not W:IsShown(), "the three ways in stayed with someone in the diary")
for i, control in ipairs(J.listControls) do
    Check(control:IsShown(), "list control " .. i .. " did not come back")
end
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("the Recently nearby page (JNL-3)")

local NP = ns.UI.NearbyPage

-- Mid-afternoon, so nothing below straddles midnight by accident.
local today = ns.DayStart(mock.now)
mock.now = today + 15 * 3600
local yesterday = ns.DayStart(today - 1)

local function Person(guid, first, surname, class, level, faction)
    ns.Characters.Observe(guid, { first = first, surname = surname, class = class, level = level, faction = faction })
    return guid
end
local BRAM = Person("Player-4620-00CCCC01", "Bram", "Redfen", "DRUID", 9, "Horde")
local FENWICK = Person("Player-4620-00CCCC02", "Fenwick", "Hale", "ROGUE", 15, "Alliance")
local KOKO = Person("Player-4620-00CCCC03", "Koko", "Skybluff", "DRUID", 7, "Horde")
local OLD = Person("Player-4620-00CCCC04", "Yesterday", "Only", "WARRIOR", 12, "Horde")
local HIDDEN = Person("Player-4620-00CCCC05", "Restricted", "Map", "MAGE", 20, "Horde")

local BARRENS = { mapID = 1413, x = 0.5, y = 0.5, subZone = "The Crossroads" }
local MULGORE = { mapID = 1412, x = 0.4, y = 0.6 }
ns.Sightings.Record(BRAM, { level = 8, source = "plate" }, MULGORE, yesterday + 20 * 3600)
ns.Sightings.Record(OLD, { level = 12, source = "plate" }, MULGORE, yesterday + 21 * 3600)
ns.Sightings.Record(BRAM, { level = 9, source = "plate" }, BARRENS, today + 14 * 3600 + 600)
ns.Sightings.Record(FENWICK, { level = 15, hostile = true, source = "target" }, MULGORE, today + 13 * 3600 + 44 * 60)
ns.Sightings.Record(KOKO, { level = 7, source = "plate" },
    { mapID = 1412, x = 0.4, y = 0.6, subZone = "Bloodhoof Village" }, today + 13 * 3600)
ns.Sightings.Record(HIDDEN, { level = 20, source = "say" }, { zone = "Restricted Place" }, today + 9 * 3600)
ns.Interactions.Add(BRAM, "trade", { time = today + 14 * 3600 })
ns.Diary.Add(KOKO, { source = "test" })

ns.UI.ShowJournal()
ns.UI.SetJournalView("nearby")

-- Left page: one line per day with sightings, people counted once a day.
local dayItems = {}
for _, item in ipairs(NP.days.data) do
    if item.start then dayItems[item.start] = item end
end
Check(dayItems[today] and dayItems[yesterday], "today or yesterday missing from the days")
Eq(dayItems[today].count, 4, "people today")
Eq(dayItems[yesterday].count, 2, "people yesterday")
Eq(dayItems[today].label, "Today", "today's label")
Eq(dayItems[yesterday].label, "Yesterday", "yesterday's label")
Eq(NP.dayCount:GetText(), "2 days", "day count")
Check(NP.hint:GetText():find("Kept for 30 days"), "hint: " .. tostring(NP.hint:GetText()))
ns.db.settings.bufferDays = 20
ns.UI.RefreshNearbyPage()
Check(NP.hint:GetText():find("Kept for 20 days"), "the hint ignores the retention setting")
ns.db.settings.bufferDays = 30
Check(NP.days.data[1].header, "the days are not under a week heading")

-- Right page: today first, latest seen first.
Eq(NP.title:GetText(), "TODAY", "today is not chosen first")
Eq(NP.count:GetText(), "4 people", "table count")
local function Names()
    local names = {}
    for _, e in ipairs(NP.table.data) do names[#names + 1] = e.name end
    return table.concat(names, ", ")
end
Eq(Names(), "Bram Redfen, Fenwick Hale, Koko Skybluff, Restricted Map", "default order")

local function RowFor(guid)
    for _, row in ipairs(NP.table.rows) do
        if row:IsShown() and row.item and row.item.guid == guid then return row end
    end
end
local bram = RowFor(BRAM)
Eq(bram.zone:GetText(), "The Barrens", "zone from the map id")
Eq(bram.subZone:GetText(), "The Crossroads", "the subzone column")
Eq(bram.level:GetText(), 9, "level that day")
Eq(bram.times:GetText(), "×2", "seen on two days")
Check(bram.dealt:IsShown(), "no trade mark")
Check(not bram.hostile:IsShown(), "a friendly marked hostile")
Check(bram.add:IsShown() and not bram.open:IsShown(), "a stranger without + Add")
Check(RowFor(FENWICK).hostile:IsShown(), "no hostile mark")
Eq(RowFor(FENWICK).zone:GetText(), "Mulgore", "the zone without a subzone")
Eq(RowFor(FENWICK).subZone:GetText(), "", "the subzone column is not blank without one")
Eq(RowFor(HIDDEN).zone:GetText(), "Restricted Place", "the zone name when there is no map id")
local koko = RowFor(KOKO)
Check(koko.open:IsShown() and not koko.add:IsShown() and koko.feather:IsShown(), "a diary entry without Open")

-- The tooltip is all a stranger gets.
bram.scripts.OnEnter(bram)
Eq(GameTooltip.text, "Bram Redfen", "row tooltip")
-- The place in full there, subzone first; the zone alone without one.
local function SeenLine()
    for _, line in ipairs(GameTooltip.lines) do
        if line[1]:find("^Last seen") then return line[1] end
    end
end
Eq(SeenLine(), "Last seen today at 14:10 in The Crossroads, The Barrens", "the tooltip's place")
bram.scripts.OnLeave(bram)
local hidden = RowFor(HIDDEN)
hidden.scripts.OnEnter(hidden)
Eq(SeenLine(), "Last seen today at 09:00 in Restricted Place", "the tooltip's place without a subzone")
hidden.scripts.OnLeave(hidden)
Eq(NP.headings.zone:GetText(), "ZONE", "the zone column's heading")
Eq(NP.headings.subzone:GetText(), "SUBZONE", "the subzone column's heading")

-- Filters, search and sorting only re-query the day.
NP.filter:Click()
mock.MenuClick("Hostile")
Eq(Names(), "Fenwick Hale", "hostile filter")
Eq(NP.count:GetText(), "1 of 4", "filtered count")
NP.filter:Click()
mock.MenuClick("Dealt with")
Eq(Names(), "Bram Redfen", "dealt-with filter")
NP.filter:Click()
mock.MenuClick("Seen before")
Eq(Names(), "Bram Redfen", "seen-before filter")
NP.filter:Click()
mock.MenuClick("Everyone")
Eq(NP.filter:GetText(), "Everyone", "filter label")

NP.search:SetText("barrens")
NP.search.scripts.OnTextChanged(NP.search)
Eq(Names(), "Bram Redfen", "search by zone")
NP.search:SetText("crossroads")
NP.search.scripts.OnTextChanged(NP.search)
Eq(Names(), "Bram Redfen", "search by subzone")
NP.search:SetText("zzz")
NP.search.scripts.OnTextChanged(NP.search)
Eq(NP.empty:GetText(), "Nobody matches.", "empty search")
NP.search:SetText("")
NP.search.scripts.OnTextChanged(NP.search)

NP.headings.name:Click()
Eq(Names(), "Bram Redfen, Fenwick Hale, Koko Skybluff, Restricted Map", "name A-Z")
NP.headings.name:Click()
Eq(Names(), "Restricted Map, Koko Skybluff, Fenwick Hale, Bram Redfen", "name Z-A")
NP.headings.name:Click()
Eq(Names(), "Bram Redfen, Fenwick Hale, Koko Skybluff, Restricted Map", "third click is latest first again")
NP.headings.level:Click()
Eq(NP.table.data[1].name, "Restricted Map", "level, highest first")
NP.headings.zone:Click()
Eq(Names(), "Fenwick Hale, Koko Skybluff, Restricted Map, Bram Redfen", "zone A-Z, then subzone")
NP.headings.subzone:Click()
Eq(Names(), "Koko Skybluff, Bram Redfen, Fenwick Hale, Restricted Map", "subzone A-Z, none last")
NP.headings.subzone:Click()
Eq(Names(), "Bram Redfen, Koko Skybluff, Fenwick Hale, Restricted Map", "subzone Z-A, none still last")
NP.headings.subzone:Click()
Eq(Names(), "Bram Redfen, Fenwick Hale, Koko Skybluff, Restricted Map", "subzone's third click")

-- + Add stays on the page and files them where they were seen.
local fenwick = RowFor(FENWICK)
fenwick.add:Click()
Check(ns.Diary.IsDiary(FENWICK), "+ Add did not add")
Eq(ns.UI.JournalView(), "nearby", "+ Add left the page")
fenwick = RowFor(FENWICK)
Check(fenwick.added:IsShown() and not fenwick.add:IsShown() and not fenwick.open:IsShown(), "row not marked Added")
local context = ns.Diary.Get(FENWICK).addedContext
Eq(context.source, "nearby", "add source")
Eq(context.mapID, 1412, "added where they were seen, not where you are")

-- Added opens the new profile too.
fenwick.added:Click()
Eq(ns.UI.JournalView(), "people", "Added did not turn to People")
Eq(J.profile.name:GetText():upper(), "FENWICK HALE", "Added opened the wrong profile")
ns.UI.SetJournalView("nearby")
koko = RowFor(KOKO)

-- Open turns to their profile.
koko.open:Click()
Eq(ns.UI.JournalView(), "people", "Open did not turn to People")
Check(J.views.people:IsShown(), "People page not shown after Open")
ns.UI.SetJournalView("nearby")

-- Another day.
for _, row in ipairs(NP.days.rows) do
    if row:IsShown() and row.item and row.item.start == yesterday then row:Click() end
end
Eq(NP.title:GetText(), "YESTERDAY", "yesterday not chosen")
Eq(#NP.table.data, 2, "yesterday's people")

-- Nothing at all.
wipe(ns.db.sightings)
ns.UI.RefreshNearbyPage()
Check(NP.noDays:GetText():find("^Nobody yet"), "no empty text: " .. tostring(NP.noDays:GetText()))
Check(not NP.right:IsShown(), "the table shows with no days")
ns.UI.SetJournalView("people")
ns.UI.CloseJournal()

-- A closed book is not repainted; it catches up when it opens. The same
-- test for all three refreshes (RefreshJournal, RefreshTimeline, this one).
ns.UI.SetJournalView("nearby")
ns.Sightings.Record(KOKO, { level = 7, source = "plate" }, MULGORE, mock.now)
ns.UI.RefreshNearbyPage()
Check(NP.noDays:GetText():find("^Nobody yet"), "the page was repainted with the journal closed")
ns.UI.ShowJournal()
Eq(NP.noDays:GetText(), "", "the page did not catch up on opening")
Check(NP.right:IsShown(), "the page did not catch up on opening")
ns.UI.ShowJournal(KOKO)
local timelineData = J.profile.timeline.data
ns.UI.RefreshTimeline()
Check(J.profile.timeline.data ~= timelineData, "RefreshTimeline did nothing with the journal open")
ns.UI.CloseJournal()
timelineData = J.profile.timeline.data
ns.UI.RefreshTimeline()
Eq(J.profile.timeline.data, timelineData, "the timeline was rebuilt with the journal closed")
ns.UI.SelectPerson(nil)
