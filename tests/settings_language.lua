-- Settings: Language, Interface's last subpage (UI/Settings/Sections/
-- Language.lua): the choice of the diary's language (the kit's Choice: a
-- link and a menu of radios, the game's language first, then each language
-- offered), written to the account setting `language`; the line that says
-- a choice waits for a reload, and the reload, asked first; the line that
-- says a saved choice could not take (Locale.stuck), with no reload; the
-- way to Feedback. And all of it with the pad.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local Menu = Pad.Menu
local Locale = ns.Locale
-- Only English here, whatever locales the TOC loads: the test offers its
-- own made-up languages.
Locale.offered = { Locale.offered[1] }
local SettingsUI = ns.UI.Settings

mock.RunTimers()
ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local book = ns.UI.JournalFrame()
local P = ns.UI.SettingsPage()

-- In the client a frame starts shown; here every widget starts hidden.
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(P)
P:Refresh()

local function Labels(root)
    local out = {}
    for _, child in ipairs(root.children) do
        if child.kind == "radio" then out[#out + 1] = child.text end
    end
    return table.concat(out, " | ")
end

--------------------------------------------------------------------------
Section("Language is Interface's last subpage")

local spec, at, lastSub
for i, s in ipairs(SettingsUI.Sections()) do
    if s.key == "language" then spec, at = s, i end
    if s.parent == "interface" then lastSub = s.key end
end
Check(spec, "no section called language")
Eq(spec.parent, "interface", "not under Interface")
Eq(spec.label, "Language", "its name")
Eq(spec.about, nil, "it has a subtitle (the pages have none)")
Eq(lastSub, "language", "not the last of Interface's subpages")
Eq(SettingsUI.Sections()[at - 1].key, "dungeons", "not after Dungeons and Raids")
Check(P.nav.language:IsShown(), "its row is not listed (Interface's subpages always are)")
P.nav.language:Click()
Eq(P:Section(), "language", "its row did not open it")
Check(P.panes.language:IsShown(), "its pane is not shown")
Check(ns.IsAccountSetting("language"), "the language is not an account setting")
Check(P.languageHint:GetText():find("every character", 1, true), "the page does not say it is account-wide")

--------------------------------------------------------------------------
Section("the choice: the game's language, then every language offered")

Eq(ns.Setting("language"), "auto", "setup: the default")
Eq(P.language.choice:GetText(), "The game's language (English)", "what is chosen, with one language offered")
mock.contextMenu = nil
P.language.choice:Click()
Check(mock.contextMenu ~= nil, "the choice's click opened no menu")
Eq(Labels(mock.contextMenu), "The game's language (English) | English", "the choices with one language offered")
Check(mock.MenuSelected("The game's language (English)"), "the game's language is not marked as chosen")
Check(not mock.MenuSelected("English"), "English marked while the game's language is chosen")

-- Another language offers itself (as a locale's Grammar.lua does).
Locale.Offer("xxXX", "Xxish")
Locale.Offer("yyYY", "Yyish")
mock.contextMenu = nil
P.language.choice:Click()
Eq(Labels(mock.contextMenu), "The game's language (English) | English | Xxish | Yyish",
    "the choices with several offered")

-- A client the diary has no words for: the first choice names no language.
local client = Locale.client
Locale.client = "zzZZ"
P.language.choice:Click()
Eq(Labels(mock.contextMenu), "The game's language | English | Xxish | Yyish",
    "the first choice on a client without words")
Locale.client = client

--------------------------------------------------------------------------
Section("choosing writes the setting, and says it waits for a reload")

P:Refresh()
Check(not Locale.Pending(ns.Setting("language")), "setup: nothing waits")
Check(not P.languageState:IsShown(), "a line about a reload with nothing waiting")
Check(not P.languageReload:IsShown(), "a reload offered with nothing waiting")
local restY = P.languageRest.recorded.points[1].args[4]

local reloads, popups = mock.reloads, #mock.popups
P.language.choice:Click()
Check(mock.MenuClick("Xxish"), "Xxish is not among the choices")
Eq(ns.Setting("language"), "xxXX", "choosing did not write the setting")
Eq(SocialDiaryDB.settings.language, "xxXX", "the choice is not in the account's saved settings")
Eq(P.language.choice:GetText(), "Xxish", "the choice does not read what was chosen")
Eq(mock.reloads, reloads, "choosing reloaded the interface")
Eq(#mock.popups, popups, "choosing asked something")
Check(Locale.Pending("xxXX"), "setup: the choice waits")
Check(P.languageState:IsShown(), "no line says the choice waits")
Eq(P.languageState:GetText(), "The diary is written in Xxish once the interface reloads.", "the waiting line")
Check(P.languageReload:IsShown(), "no reload offered")
Eq(P.languageReload:GetText(), "Reload", "the reload's link")
local moved = P.languageRest.recorded.points[1].args[4]
Check(moved < restY, "the rest of the page did not make room for the line")

-- The reload is asked first; left unanswered, nothing happens.
P.languageReload:Click()
Eq(#mock.popups, popups + 1, "the reload did not ask first")
local asked = mock.popups[#mock.popups].args[1]
Check(asked:find("Write the diary in Xxish?", 1, true) and asked:find("interface reloads", 1, true),
    "the question does not say what happens: " .. asked)
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.button1, "Reload", "the question's answer")
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.showAlert, false, "the question carries the alert")
Eq(mock.reloads, reloads, "reloaded before the user answered")
P.languageReload:Click()
mock.AnswerPopup("accept")
Eq(mock.reloads, reloads + 1, "accepting did not reload the interface")
Eq(ns.Setting("language"), "xxXX", "the reload changed the choice")

-- Back to the language read: nothing waits, nothing is offered.
P.language.choice:Click()
Check(mock.MenuClick("English"), "English is not among the choices")
Eq(ns.Setting("language"), "enUS", "English not written")
Check(not P.languageState:IsShown() and not P.languageReload:IsShown(), "a reload offered for the language read")
P.language.choice:Click()
Check(mock.MenuClick("The game's language (English)"), "the game's language is not among the choices")
Eq(ns.Setting("language"), "auto", "the game's language not written")
Check(not P.languageState:IsShown() and not P.languageReload:IsShown(), "a reload offered for the game's language")
Eq(P.languageRest.recorded.points[1].args[4], restY,
    "the rest of the page did not move back up")

--------------------------------------------------------------------------
Section("a saved choice that could not take: said plainly, no reload")

ns.SetSetting("language", "xxXX")
Locale.stuck = true
P:Refresh()
Check(P.languageState:IsShown(), "nothing says the choice could not take")
Check(P.languageState:GetText():find("can't change language on this game client", 1, true),
    "the line does not say so: " .. tostring(P.languageState:GetText()))
Check(not P.languageReload:IsShown(), "another reload offered where it cannot help")
popups = #mock.popups
P.languageReload:Click()
Eq(#mock.popups, popups, "the hidden reload still asks")
-- (the game's language stays to be chosen)
P.language.choice:Click()
Check(mock.MenuClick("The game's language (English)"), "the game's language cannot be chosen")
Eq(ns.Setting("language"), "auto", "the game's language not written")
Check(P.languageState:IsShown() and not P.languageReload:IsShown(), "the line went, or a reload came")
Locale.stuck = false
P:Refresh()
Check(not P.languageState:IsShown(), "the line stays without cause")

--------------------------------------------------------------------------
Section("the translations are a machine's, and Feedback is a link away")

local about = P.languageAbout:GetText()
Check(about:find("machine", 1, true) and about:find("welcome", 1, true), "the page does not say so: " .. about)
Check(P.languageNames:GetText():find("stay in the game's language", 1, true),
    "the page does not say the game's names stay")
Eq(P.languageFeedback:GetText(), "Go to Feedback", "the link")
P.languageFeedback:Click()
Eq(P:Section(), "feedback", "the link did not open Feedback")
Check(P.panes.feedback:IsShown() and not P.panes.language:IsShown(), "the panes did not swap")
Check(P.nav.feedback:IsShown(), "Feedback's row is not listed")

--------------------------------------------------------------------------
Section("with the pad: the choice and both links are reached")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Prompt()
    local first = Pad.Top().legend(Pad.Top())[1]
    return first and first[2]
end

ns.SetSetting("language", "auto")
P:ShowSection("language")
Pad.Refresh()
Eq(Pad.Top().key, "settings", "the top scope")
Eq(At().key, "nav:language", "not on Language's row")
Press("PADDRIGHT")
Eq(At().kind, "choice", "the first thing on the page is not the choice")
Eq(At().frame, P.language.choice, "the pad is not on what is chosen")
Eq(Prompt(), "See the choices", "the choice's prompt")
Press("PADDDOWN")
Eq(At().frame, P.languageFeedback, "down: not the way to Feedback (nothing waits: no reload to stand on)")
Eq(Prompt(), "Choose", "a link's prompt")
Press("PADDUP")
Eq(At().frame, P.language.choice, "up: not back on the choice")

--------------------------------------------------------------------------
Section("with the pad: A lays the choices on the pad's menu, never Blizzard's")

mock.contextMenu = nil
Press("PAD1")
Eq(mock.contextMenu, nil, "A opened Blizzard's menu")
Check(Menu.IsOpen(), "A opened no menu of the pad's")
Eq(Pad.Top().key, "menu", "the menu does not have the pad")
Eq(Labels(Menu.Record(nil, P.language.menu())), "The game's language (English) | English | Xxish | Yyish",
    "the pad's choices are not the mouse's")
Eq(#Pad.Top().focus.groups.menu.items, 4, "not every choice is walked")
Press("PAD2")
Check(not Menu.IsOpen(), "B did not put the menu away")
Eq(At().frame, P.language.choice, "B: not back on the choice")
Eq(ns.Setting("language"), "auto", "B chose something")

-- Down to Xxish (the game's language, English, Xxish) and A.
Press("PAD1")
local onto
for _ = 1, 4 do
    local words = At().words or (At().frame and At().frame.label)
    if At().text == "Xxish" or (words and words.GetText and words:GetText() == "Xxish") then onto = true break end
    Press("PADDDOWN")
end
Check(onto, "the pad could not reach Xxish in the menu")
reloads = mock.reloads
Press("PAD1")
Eq(ns.Setting("language"), "xxXX", "A in the menu did not choose")
Check(not Menu.IsOpen(), "the menu stayed after the choice")
Eq(mock.reloads, reloads, "choosing with the pad reloaded")
Eq(At().frame, P.language.choice, "after choosing: not back on the choice")
Eq(P.language.choice:GetText(), "Xxish", "the choice does not read what was chosen")

-- The reload is now there to stand on, between the choice and Feedback.
Check(P.languageReload:IsShown(), "no reload offered")
Press("PADDDOWN")
Eq(At().frame, P.languageReload, "down: not the reload")
popups = #mock.popups
Press("PAD1")
Eq(#mock.popups, popups + 1, "A on the reload did not ask")
Eq(mock.reloads, reloads, "A on the reload reloaded without asking")
Press("PADDDOWN")
Eq(At().frame, P.languageFeedback, "down: not the way to Feedback")

--------------------------------------------------------------------------
Section("with the pad: the link opens Feedback, the pad on its row")

Press("PAD1")
Eq(P:Section(), "feedback", "A on the link did not open Feedback")
Eq(At().key, "nav:feedback", "the pad is not on Feedback's row")
Press("PAD2")
Check(not _G.SocialDiaryJournalFrame:IsShown(), "B on the sections did not close the book")

--------------------------------------------------------------------------
Section("with the mouse again, and with the Gamepad UI off")

ns.UI.ShowSettings("language")
Pad.Input.Force("off")
mock.contextMenu = nil
P.language.choice:Click()
Check(mock.contextMenu ~= nil, "the mouse's menu is not Blizzard's")
Check(not Menu.IsOpen(), "the pad's menu opened for the mouse")
Check(mock.MenuSelected("Xxish"), "the menu does not mark what is chosen")
Pad.Input.Force(nil)
ns.SetSetting("language", "auto")
