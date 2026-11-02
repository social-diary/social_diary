-- Opening the diary inside a dungeon or raid (ns.UI.OpenJournal): the
-- key, the minimap button and the Social tab open on the run going on, its
-- map out on the table over Your Diary; a second press shuts it all; with
-- the setting off, or outside, the book opens as it always did.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local mock = T.mock
local ns = T.Boot()
local J = ns.UI.Journal
local Page = ns.UI.DungeonPage

mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
ns.db.settings.dungeonTutorialSeen = true
local G = ns.TestData.GUID

local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 then RFK = visit end
end
Check(RFK, "the test data's Razorfen Kraul")

local panel = _G.SocialDiaryJournalFrame or ns.UI.JournalFrame()
local function Out() return J.visit and J.visit.id end
local function Shut()
    ns.UI.CloseJournal()
    Check(not panel:IsShown() and Out() == nil, "the book and the run did not shut")
end

--------------------------------------------------------------------------
Section("outside: the book as it was")

Eq(ns.SettingDefault("openOnRun"), true, "opening on the run is not on by default")
-- /sd testdata leaves the book open on its person.
Shut()
SocialDiary_ToggleJournal()
Check(panel:IsShown(), "the key did not open the book")
Eq(Out(), nil, "a run came out with nobody inside")
Shut()

--------------------------------------------------------------------------
Section("inside: the run's map, over Your Diary")

-- The user is in it now: the open visit, its last span not ended.
RFK.me = ns.ownGUID
RFK.spans = RFK.spans or {}
RFK.spans[#RFK.spans + 1] = { from = mock.now - 60 }
ns.db.meta.openVisit = RFK.id
Check((ns.Instances.Inside()), "not inside")

ns.UI.SetJournalView("people")
SocialDiary_ToggleJournal()
Check(panel:IsShown(), "the book is not open under the run")
Eq(Out(), RFK.id, "the key did not open on the run")
Eq(J.visit and J.visit.from, "journey", "the run is not read as the user's own")
Eq(ns.UI.JournalView(), "journey", "the book under it is not Your Diary")
Check(Page.Spread():IsShown(), "the table is not out")
-- A second press shuts the book, and the run with it.
SocialDiary_ToggleJournal()
Check(not panel:IsShown() and Out() == nil, "a second press did not shut it")

-- The minimap button and the compartment go the same way.
SocialDiary_OnCompartmentClick()
Eq(Out(), RFK.id, "the compartment did not open on the run")
Shut()
SlashCmdList.SOCIALDIARY("")
Eq(Out(), RFK.id, "/sd did not open on the run")
Shut()

-- Opened on someone (a toast, a link), it opens on them.
ns.UI.ShowJournal(G)
Eq(Out(), nil, "opening on a person brought the run out")
Eq(ns.UI.JournalView(), "people", "opening on a person did not open on them")
Shut()

--------------------------------------------------------------------------
Section("before the introduction: that comes first")

ns.db.settings.introSeen = false
ns.UI.OpenJournal()
Eq(Out(), nil, "the run came out before the introduction")
Shut()
ns.db.settings.introSeen = true

--------------------------------------------------------------------------
Section("the setting off: the book as it was")

local SP = ns.UI.SettingsPage()
ns.UI.ShowSettings("dungeons")
Check(SP.openOnRun, "no switch in Dungeons and Raids")
Check(SP.openOnRun:GetChecked(), "the switch is not on")
SP.openOnRun.scripts.OnClick(SP.openOnRun)
Eq(ns.Setting("openOnRun"), false, "the switch did not turn it off")
Shut()

SocialDiary_ToggleJournal()
Check(panel:IsShown(), "the key did not open the book")
Eq(Out(), nil, "the run came out with the setting off")
Shut()
