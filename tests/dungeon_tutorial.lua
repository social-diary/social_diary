-- The note on the first run out on the table (UI/Dungeon/Tutorial.lua):
-- shown the first time only, however it went; Escape takes it and leaves
-- the map; going with the spread it leaves nothing behind; and the flag
-- is kept, defaulted on an account file saved before it existed.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local Page = ns.UI.DungeonPage

mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID

local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 then RFK = visit end
end
Check(RFK, "the test data's Razorfen Kraul")

local NAME = Page.TUTORIAL.NOTE.name
local BOOK, SPREAD = "SocialDiaryJournalFrame", Page.SPREAD.name

local function Holder()
    local held
    for _, name in ipairs(UISpecialFrames) do
        if name == BOOK or name == SPREAD or name == NAME then
            Check(not held, "two places on Escape's list: " .. tostring(held) .. ", " .. name)
            held = name
        end
    end
    return held
end
-- What Escape does in the client (CloseSpecialWindows), as in
-- tests/dungeon_spread.lua.
local function Escape()
    for _, name in pairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then frame:Hide() end
    end
end
local function Up()
    local note = Page.TutorialNote()
    return note ~= nil and note:IsShown()
end

--------------------------------------------------------------------------
Section("a run with no map leaves it for one that has")

Page.Tutorial({ map = {} })
Eq(ns.db.settings.dungeonTutorialSeen, false, "used up on a run with no map")
Check(Page.TutorialNote() == nil, "laid on a run with no map")

--------------------------------------------------------------------------
Section("the first run out brings the note, marked seen at once")

Eq(ns.db.settings.dungeonTutorialSeen, false, "seen before any run came out")
Check(Page.TutorialNote() == nil, "built before it was due")
ns.UI.OpenVisit(RFK.id, G)
Check(Up(), "no note on the first run out")
Eq(ns.db.settings.dungeonTutorialSeen, true, "not marked as it was laid")
Eq(SocialDiaryDB.settings.dungeonTutorialSeen, true, "not in the account file")
Eq(SocialDiaryCharDB.settings.dungeonTutorialSeen, nil, "in the character's file")
Eq(Holder(), NAME, "Escape not the note's")

local note = Page.TutorialNote()
local host = Page.Spread()
local view = note.view

--------------------------------------------------------------------------
Section("what it says, and how it lies")

Eq(#Page.TUTORIAL.WORDS.paragraphs, 3, "three things to say")
local said = {}
for _, line in ipairs(note.lines) do
    if line:IsShown() then said[#said + 1] = line:GetText() end
end
Eq(table.concat(said, " "), table.concat(Page.TUTORIAL.WORDS.paragraphs, " "), "not its words, in order")
Check(table.concat(said, " "):find(Page.WAY.WORDS.adjust, 1, true), "does not name the pencil's own words")
-- Over the map, its slip too, and the click stops at it.
local slip = host.map.way.slip
Check(view:GetFrameLevel() > slip:GetFrameLevel(), "under the pencil's slip")
Check(view.onPutAway == nil, "a click beside it would put it away")
local calls = view.recorded.calls
Check(calls.EnableMouse and calls.EnableMouse[1] == true, "clicks reach what is under it")
Check(calls.EnableMouseWheel and calls.EnableMouseWheel[1] == true, "the wheel reaches the map under it")
-- All of it on the paper, and it lies on the map's middle.
local NOTE = Page.TUTORIAL.NOTE
Check(#said >= 3, "not wrapped into lines")
Check(note.h >= NOTE.body + #said * NOTE.line, "the sheet shorter than its words")
Eq(view.sheet.recorded.width, NOTE.w, "its width")
Eq(view.sheet.recorded.height, note.h, "its height not its words'")
local at = view.sheet.recorded.points[1].args
Eq(at[3], host.map.lie[1], "not on the map's middle across")
Eq(at[4], host.map.lie[2], "not on the map's middle down")

--------------------------------------------------------------------------
Section("its link puts it away, the map still out")

mock.sounds = {}
note.ok:Click()
Check(not Up(), "the link left it up")
Eq(J.visit and J.visit.id, RFK.id, "the map went with it")
Check(host:IsShown(), "the spread went with it")
Eq(Holder(), SPREAD, "Escape not back with the spread")
Eq(#mock.sounds, 1, "no rustle as it was put away")

--------------------------------------------------------------------------
Section("never again")

Page.Close()
Eq(Holder(), BOOK, "Escape not back with the book")
ns.UI.OpenVisit(RFK.id, G)
Check(not Up(), "the note came back on the second run out")
Eq(Holder(), SPREAD, "Escape on the note with no note")
Page.Close()

--------------------------------------------------------------------------
Section("Escape takes the note first, one press at a time")

ns.db.settings.dungeonTutorialSeen = false
ns.UI.OpenVisit(RFK.id, G)
Check(Up(), "no note")
Escape()
Check(not Up(), "Escape left the note up")
Check(host:IsShown() and J.visit, "one press took the map too")
Eq(Holder(), SPREAD, "the map's press not given back")
Escape()
Check(not host:IsShown() and not J.visit, "the second press left the map")
Eq(Holder(), BOOK, "the book's press not given back")
Check(ns.UI.JournalShowing(), "the second press shut the book")
Escape()
Check(not ns.UI.JournalShowing(), "the third press left the book")

--------------------------------------------------------------------------
Section("going with the map or the book leaves nothing behind")

ns.UI.ShowJournal(G)
ns.db.settings.dungeonTutorialSeen = false
ns.UI.OpenVisit(RFK.id, G)
Check(Up(), "no note")
ns.UI.OpenVisit(RFK.id, G)  -- the card again: the run put away
Check(not Up(), "left shown with the run put away")
Eq(Holder(), BOOK, "Escape stuck on the note")
ns.UI.OpenVisit(RFK.id, G)
Check(host:IsShown() and not Up(), "did not open again clean")
Eq(Holder(), SPREAD, "Escape not the spread's on reopening")
Page.Close()

ns.db.settings.dungeonTutorialSeen = false
ns.UI.OpenVisit(RFK.id, G)
ns.UI.CloseJournal()
Check(not Up() and not host:IsShown(), "left behind by the book")
Eq(Holder(), BOOK, "Escape stuck with the book shut")
ns.UI.ShowJournal(G)
ns.UI.OpenVisit(RFK.id, G)
Check(host:IsShown() and not Up(), "the book's reopening brought it back")
Page.Close()

--------------------------------------------------------------------------
Section("the screen changed under it: laid again where the map lies")

ns.db.settings.dungeonTutorialSeen = false
ns.UI.OpenVisit(RFK.id, G)
Page.Refresh()
Check(Up(), "gone with the map laid again")
at = view.sheet.recorded.points[#view.sheet.recorded.points].args
Eq(at[3], host.map.lie[1], "not on the map's middle across, laid again")
note.ok:Click()
Page.Close()

--------------------------------------------------------------------------
Section("the flag is kept, and defaulted on an old account file")

Eq(ns.db.settings.dungeonTutorialSeen, true, "not seen")
ns.InitDB()
Eq(ns.db.settings.dungeonTutorialSeen, true, "lost across a load")
-- A file saved before the key existed: no step needed, the default fills it.
local schema = SocialDiaryDB.schema
SocialDiaryDB.settings.dungeonTutorialSeen = nil
SocialDiaryDB.settings.frontRead = true
ns.InitDB()
Eq(ns.db.settings.dungeonTutorialSeen, false, "not defaulted on an old file")
Eq(ns.db.settings.frontRead, true, "an old setting changed")
Eq(SocialDiaryDB.schema, schema, "the account's schema moved")
