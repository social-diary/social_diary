-- Privacy: the settings page, forgetting one person or everyone, and the
-- onboarding that says what is kept: the parcel at login and the book's
-- front matter.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local STRANGER, SELF = F.STRANGER, F.SELF
local A, B, C = STRANGER.guid, F.GARRICK.guid, F.PUG.guid

--------------------------------------------------------------------------
Section("settings, deletion and the front matter (PRV-1 to PRV-5)")

mock.RunTimers()

ns.Characters.Observe(A, { first = "Bram", surname = "Redfen" })
ns.Diary.Add(A, { source = "test", tags = { "friend" } })

-- PRV-2: the settings are the journal's grey ribbon. Blizzard's AddOns
-- settings keep a signpost to them, registered once however many logins
-- fire.
Eq(#mock.settingsCategories, 1, "signpost registered more or less than once")
Eq(mock.settingsCategories[1].name, "Social Diary", "signpost category name")

SlashCmdList.SOCIALDIARY("settings")
Check(_G.SocialDiaryJournalFrame:IsShown(), "/sd settings did not open the journal")
Eq(ns.UI.JournalView(), "settings", "/sd settings did not turn to the settings")
local book = ns.UI.JournalFrame()
Check(book.ribbons.settings.active and not book.ribbons.people.active, "the grey ribbon is not marked")
Check(book.views.settings:IsShown() and not book.views.people:IsShown(), "the settings page is not the one shown")
ns.UI.CloseJournal()

mock.settingsCategories[1].frame.open:Click()
Eq(ns.UI.JournalView(), "settings", "the signpost did not open the settings")
Check(_G.SocialDiaryJournalFrame:IsShown(), "the signpost did not open the journal")
ns.UI.SetJournalView("people")
ns.UI.CloseJournal()

local P = ns.UI.SettingsPage()

-- Two panes: the sections on the left, the open one's settings on the right.
Eq(P:Section(), "recording", "the first section is not open to begin with")
Check(P.panes.recording:IsShown() and not P.panes.interface:IsShown()
    and not P.panes.memory:IsShown(), "more or less than the open section shown")
Check(P.nav.recording.selected:IsShown() and not P.nav.memory.selected:IsShown(),
    "the open section is not marked on the left")
P.nav.memory:Click()
Eq(P:Section(), "memory", "clicking a section did not open it")
Check(P.panes.memory:IsShown() and not P.panes.recording:IsShown(), "the panes did not swap")
Check(P.nav.memory.selected:IsShown() and not P.nav.recording.selected:IsShown(),
    "the mark did not move")
ns.UI.ShowSettings()
Eq(P:Section(), "memory", "the section was not kept across opens")
ns.UI.CloseJournal()
P:ShowSection("nonsense")
Eq(P:Section(), "memory", "an unknown section was opened")
P.nav.about:Click()
Check(P.panes.about:IsShown() and not P.panes.memory:IsShown(), "the About page did not open")
Eq(#P.testers, 3, "the About page does not thank the three testers")
Eq(P.testers[3]:GetText(), "Koko Skybluff", "a tester's name")
Eq(P.nav.about.about:GetText(), "Thanks & Credits", "the About row's small print")
-- Licensing, on the same page: the licence, Dungeon Crawler Forever, each
-- drawn map's artist once (from the dungeon data), the font.
local licence = {}
for i, line in ipairs(P.licensing) do licence[i] = line:GetText() end
Check(licence[1]:find("GNU General Public License v3 or later") and licence[1]:find("1%.7%.0") and licence[1]:find("MIT"),
    "the licence line: " .. tostring(licence[1]))
Check(licence[2]:find("Dungeon Crawler Forever by Per"), "no credit for Dungeon Crawler Forever")
local credits = ns.Dungeons.Credits()
Eq(#licence, 3 + #credits, "a line per licence and per artist")
for i, credit in ipairs(credits) do
    local artist = credit.text:gsub("^Map art:%s*", "")
    Check(licence[2 + i]:find(artist, 1, true) and licence[2 + i]:find(credit.dungeons[1], 1, true),
        "an artist not credited for their maps: " .. licence[2 + i])
end
Check(licence[#licence]:find("SIL Open Font License 1%.1"), "no licence for the font")
Eq(P.questieCredit:GetText(), "Questie and QuestieDB, which Social Diary reads from while the game runs, if you have"
    .. " them installed.", "the credit for Questie")
P.nav.recording:Click()

-- Interface's subpages: always listed, under it, each with its own pane.
-- Open, a subpage is marked and its section's name goes dark with it.
local SUBPAGES = { toasts = "Toasts", shortcuts = "Keybinds & Shortcuts", dungeons = "Dungeons and Raids" }
for key, label in pairs(SUBPAGES) do
    Check(P.nav[key] and P.panes[key], "no row or pane for the subpage " .. key)
    Eq(P.nav[key].label:GetText(), label, "the subpage's name on the left")
    Eq(P.nav[key].about, nil, "a subpage's row carries a section's small print")
end
Check(P.brackets.interface, "the subpages hang off no bracket")
P.nav.toasts:Click()
Eq(P:Section(), "toasts", "clicking a subpage did not open it")
Check(P.panes.toasts:IsShown() and not P.panes.interface:IsShown() and not P.panes.recording:IsShown(),
    "more or less than the subpage's pane shown")
Check(P.nav.toasts.selected:IsShown() and not P.nav.interface.selected:IsShown(),
    "the open subpage is not the one marked")
local function Font(row) return row.label.recorded.calls.SetFontObject[1] end
Eq(Font(P.nav.interface), ns.Style.FONT.strong, "the subpage's section is not dark beside it")
Eq(Font(P.nav.shortcuts), ns.Style.FONT.body, "the other subpage is dark too")
P:ShowSection("shortcuts")
Eq(P:Section(), "shortcuts", "ShowSection did not open a subpage")
Check(P.panes.shortcuts:IsShown() and not P.panes.toasts:IsShown(), "the subpages' panes did not swap")
ns.UI.ShowSettings()
Eq(P:Section(), "shortcuts", "the subpage was not kept across opens")
ns.UI.ShowSettings("toasts")
Eq(P:Section(), "toasts", "ShowSettings did not turn to the subpage asked for")
P.nav.interface:Click()
Eq(Font(P.nav.interface), ns.Style.FONT.strong, "the open section is not dark")
Check(P.nav.interface.selected:IsShown() and not P.nav.toasts.selected:IsShown(), "the mark did not go back up")
ns.UI.CloseJournal()

-- The left page still ends above the introduction's link (its foot is
-- 22 above the page's, and it is 18 tall), clear of the ribbons.
local BOOK = ns.UI.Journal.BOOK
Check(P.navBottom < BOOK.BOOK_H - 22 - 18 - 8,
    ("the sections run down to %d, into the introduction's link"):format(P.navBottom))

-- What moved: the toasts and the blacklist are on Toasts, and Interface
-- keeps the tooltips and the look.
for _, name in ipairs({ "toasts", "nearbyToasts", "toastCooldown", "foeToastsUncooled", "moveToast", "quiet" }) do
    Eq(P[name].parent, P.panes.toasts, name .. " is not on the Toasts page")
end
Eq(P.quietSearch.holder.parent, P.panes.toasts, "the blacklist's search is not on the Toasts page")
for _, name in ipairs({ "tooltips", "tooltipSeen", "bookStack", "flatSheets", "revealMap" }) do
    Eq(P[name].parent, P.panes.interface, name .. " left the Interface page")
end
Check(not P.panes.interface.about:GetText():find("[Tt]oast"), "Interface still says it holds the toasts")

-- Move the toast comes back to Toasts, whatever was opened meanwhile.
P:ShowSection("toasts")
P.moveToast:Click()
Check(ns.UI.PlacingToast(), "Move the toast did not lay the card out")
P:ShowSection("memory")
_G.SocialDiaryToastFrame.done:Click()
Eq(P:Section(), "toasts", "placing the toast did not come back to Toasts")
ns.UI.CloseJournal()
P.nav.recording:Click()

-- Sounds: the foe alert, off until asked for, with a sample to hear.
P.nav.sounds:Click()
Check(P.panes.sounds:IsShown() and not P.panes.recording:IsShown(), "the Sounds page did not open")
Eq(P.foeAlert:GetChecked(), false, "the foe alert is ticked before anybody asked for it")
P.foeAlert:Click()
Eq(ns.db.settings.foeAlert, true, "the foe alert box did not write through")
P.foeAlert:Click()
Eq(ns.db.settings.foeAlert, false, "the foe alert box did not switch off")
mock.sounds = {}
P.foeSample:Click()
Eq(mock.sounds[1] and mock.sounds[1][1], 8959, "Hear it did not play the raid warning")
Eq(mock.sounds[1] and mock.sounds[1][2], "Master", "the sample not on the master channel")
mock.sounds = {}

-- Integrations: listed between Sounds and Memory, a section of its own.
-- Questie installed is a status, not a switch: ticked only where QuestieDB
-- answers, deaf to the mouse, and it writes nothing.
local function NavY(key) return P.nav[key].recorded.points[1].args[2] end
Check(NavY("sounds") > NavY("integrations") and NavY("integrations") > NavY("memory"),
    "Integrations is not listed between Sounds and Memory")
Eq(P.nav.integrations.label:GetText(), "Integrations", "the Integrations row's name")
Eq(P.nav.integrations.about:GetText(), "Other addons it can read", "the Integrations row's small print")
P.nav.integrations:Click()
Eq(P:Section(), "integrations", "clicking Integrations did not open it")
Check(P.panes.integrations:IsShown() and not P.panes.sounds:IsShown(), "the Integrations page did not open")
Eq(P.questie.parent, P.panes.integrations, "Questie installed is not on the Integrations page")
Eq(P.questie.label:GetText(), "Questie installed", "the Questie tick's label")
Eq(P.questie.hint:GetText(), "Mobs get their real names and quest drops are checked against real drop"
    .. " rates. Social Diary only reads from it.", "the Questie tick's small print")

Eq(ns.QuestieBridge.Status(), "off", "Questie is there before the test brings it")
Eq(P.questie:GetChecked(), false, "Questie installed is ticked without QuestieDB")
Check(not P.questieOld:IsShown(), "the unsupported line shows with no Questie at all")

_G.LibQuestieDB = { RequireContract = function(v) return v == 3 end }
ns.QuestieBridge.Reset()
P:Refresh()
Eq(P.questie:GetChecked(), true, "Questie installed is not ticked with QuestieDB")
Check(not P.questieOld:IsShown(), "the unsupported line shows for a supported QuestieDB")

-- Clicking: nothing flips, nothing is written, nothing darkens.
local function Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end
local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end
local before = { Copy(SocialDiaryDB.settings), Copy(SocialDiaryCharDB.settings) }
Check(P.questie.readOnly, "Questie installed is not read-only")
Eq(P.questie.recorded.calls.EnableMouse and P.questie.recorded.calls.EnableMouse[1], false,
    "Questie installed still takes the mouse")
Eq(P.questie:GetScript("OnEnter"), nil, "Questie installed darkens under the mouse")
P.questie:Click()
Eq(P.questie:GetChecked(), true, "clicking Questie installed changed it")
Check(Same(before[1], Copy(SocialDiaryDB.settings)) and Same(before[2], Copy(SocialDiaryCharDB.settings)),
    "clicking Questie installed wrote a setting")
Eq(P.questie.recorded.calls.SetAlpha, nil, "Questie installed is faded like an unavailable setting")

-- Questie there, its database not one the bridge can read: "old".
_G.LibQuestieDB = nil
_G.Questie = {}
ns.QuestieBridge.Reset()
P:Refresh()
Eq(ns.QuestieBridge.Status(), "old", "Questie without its database is not 'old'")
Eq(P.questie:GetChecked(), false, "Questie installed is ticked for an unsupported version")
Check(P.questieOld:IsShown(), "the unsupported line does not show for 'old'")
Eq(P.questieOld:GetText(), "Found, but this version isn't supported.", "the unsupported line")

_G.Questie = nil
ns.QuestieBridge.Reset()
P:Refresh()
Check(not P.questieOld:IsShown(), "the unsupported line stays once Questie is gone")
Eq(P.questie:GetChecked(), false, "Questie installed stays ticked once Questie is gone")

-- Deathlog and Total RP 3: placeholders under Questie, in that order. Never
-- ticked, not even with the addon there, and unavailable after any refresh:
-- the box and its label faded, the small print left at hint ink.
local function Y(widget) return widget.recorded.points[1].args[4] end
local PLACEHOLDERS = {
    { P.deathlog, "Deathlog", "Deathlog installed",
        "Adds permadeath notes in Hardcore. Not available until Hardcore is released." },
    { P.trp3, "Total RP 3", "Total RP 3 installed",
        "Adds RP profile data to diary entries. Not available until it's ported to Forever." },
}
Check(Y(P.questieOld) > Y(P.deathlog.heading) and Y(P.deathlog.heading) > Y(P.deathlog)
    and Y(P.deathlog) > Y(P.trp3.heading) and Y(P.trp3.heading) > Y(P.trp3),
    "Deathlog and Total RP 3 are not under Questie, in that order")
local function Placeholders(when)
    for _, p in ipairs(PLACEHOLDERS) do
        local box = p[1]
        Eq(box.parent, P.panes.integrations, p[3] .. " is not on the Integrations page")
        Eq(box.heading:GetText(), p[2]:upper(), p[3] .. ": its heading")
        Eq(box.label:GetText(), p[3], p[3] .. ": the tick's label")
        Eq(box.hint:GetText(), p[4], p[3] .. ": the small print")
        Eq(box:GetChecked(), false, p[3] .. " is ticked " .. when)
        Check(box.unavailable, p[3] .. " is available " .. when)
        Eq(box.tick.recorded.calls.SetAlpha[1], 0.45, p[3] .. ": the box is not faded " .. when)
        Eq(box.label.recorded.calls.SetAlpha[1], 0.45, p[3] .. ": the label is not faded " .. when)
        Eq(box.hint.recorded.calls.SetAlpha, nil, p[3] .. ": the small print is faded " .. when)
        Check(box.readOnly, p[3] .. " is not read-only")
        Eq(box:GetScript("OnEnter"), nil, p[3] .. " darkens under the mouse")
        local settings = { Copy(SocialDiaryDB.settings), Copy(SocialDiaryCharDB.settings) }
        box:Click()
        Eq(box:GetChecked(), false, "clicking " .. p[3] .. " ticked it " .. when)
        Check(Same(settings[1], Copy(SocialDiaryDB.settings))
            and Same(settings[2], Copy(SocialDiaryCharDB.settings)),
            "clicking " .. p[3] .. " wrote a setting")
    end
end
Placeholders("as built")
P:Refresh()
Placeholders("after a refresh")
_G.Deathlog, _G.TRP3_API = {}, {}
P:Refresh()
Placeholders("with the addons there")
_G.Deathlog, _G.TRP3_API = nil, nil
P.nav.recording:Click()

Eq(P.storeChat:GetChecked(), true, "chat storage checkbox")
Eq(P.toasts:GetChecked(), true, "toast checkbox")
Eq(P.bufferDays.box:GetText(), "30", "retention box")
Eq(P.sessionGap.box:GetText(), "20", "session gap box")
Eq(P.toastCooldown.box:GetText(), "10", "toast cooldown box")
Check(P.size:GetText():find("1 in the diary"), "size line: " .. P.size:GetText())
Check(P.size:GetText():find("KB"), "no size estimate (DAT-3)")

-- The switches reach the features they switch.
P.toasts:Click()
Eq(ns.db.settings.toasts, false, "toast checkbox did not write through")
ns.UI.Reunion(A)
Eq(ns.UI.ReunionShowing(), nil, "a toast with toasts switched off")
P.toasts:Click()
Eq(ns.db.settings.toasts, true, "toast checkbox did not switch back on")

P.tooltips:Click()
Eq(#mock.UnitTooltip(A), 0, "tooltip lines with tooltips switched off")
P.tooltips:Click()
Check(#mock.UnitTooltip(A) > 0, "tooltip lines did not come back")

P.storeChat:Click()
Eq(ns.db.settings.storeChat, false, "chat checkbox did not write through")
Eq(P.storeChat:GetChecked(), false, "the box did not untick")
P.storeChat:Click()
Eq(P.storeChat:GetChecked(), true, "the box did not tick again")

-- A setting that only means something while another is on fades, and
-- does nothing, while that one is off.
-- A number row has no `unavailable`: it fades (and its box stops taking
-- input).
local function Faded(row) return row.recorded.calls.SetAlpha[1] < 1 end
P.toasts:Click()
Check(not P.nearbyToasts.unavailable, "nearby toasts hang off the group ones")
Check(Faded(P.toastCooldown) == false, "the cooldown went with nearby toasts still on")
P.nearbyToasts:Click()
Eq(ns.db.settings.nearbyToasts, false, "the nearby toasts box did not write through")
Check(Faded(P.toastCooldown), "the cooldown stayed with both kinds off")
Check(P.foeToastsUncooled.unavailable, "'ignore the cooldown for foes' stayed with both kinds off")
P.nearbyToasts:Click()
P.toasts:Click()
Check(Faded(P.toastCooldown) == false, "the cooldown did not come back with toasts")
Check(not P.foeToastsUncooled.unavailable, "'ignore the cooldown for foes' did not come back")
Eq(P.foeToastsUncooled:GetChecked(), false, "foes skip the cooldown before anybody asked")
P.foeToastsUncooled:Click()
Eq(ns.db.settings.foeToastsUncooled, true, "the foes' cooldown box did not write through")
P.foeToastsUncooled:Click()
P.tooltips:Click()
Check(P.tooltipSeen.unavailable, "'seen N times' available with tooltips off")
P.tooltips:Click()
Check(not P.tooltipSeen.unavailable, "'seen N times' did not come back with tooltips")

-- The pages beneath: one entry, so five pages with the settings last; off,
-- a full even stack, at once.
local book = _G.SocialDiaryJournalFrame.book
local function Stack() return book.stackPages[1] .. "/" .. book.stackPages[2] end
Eq(ns.db.settings.bookStack, true, "the growing stack is off by default")
Eq(Stack(), "4/2", "the settings' stack")
P.bookStack:Click()
Eq(ns.db.settings.bookStack, false, "the box did not switch the growing stack off")
Eq(Stack(), "6/6", "the stack did not go still")
P.bookStack:Click()
Eq(Stack(), "4/2", "the stack did not come back")

-- Loose sheets bend by default; the box lays them flat.
Eq(ns.db.settings.flatSheets, false, "loose sheets are flat by default")
P.flatSheets:Click()
Eq(ns.db.settings.flatSheets, true, "the box did not lay loose sheets flat")
P.flatSheets:Click()
Eq(ns.db.settings.flatSheets, false, "the box did not let them bend again")
Eq(ns.db.settings.revealMap, false, "the whole map is shown by default")
P.revealMap:Click()
Eq(ns.db.settings.revealMap, true, "the box did not show the whole map")
P.revealMap:Click()
Eq(ns.db.settings.revealMap, false, "the box did not go back to what was explored")

-- Quiet nearby: no nearby toast for them, a group toast still.
local now = mock.now
local function Search(text)
    P.quietSearch:SetText(text)
    P.quietSearch.scripts.OnTextChanged(P.quietSearch)
end
Eq(#P.quiet.data, 0, "the quiet list is not empty to begin with")
Check(P.quietEmpty:GetText():find("Search your diary"), "empty quiet list: " .. P.quietEmpty:GetText())
Eq(P.quietCount:GetText(), "0 quiet", "quiet count")
Search("redfe")
Eq(#P.quiet.data, 1, "the search did not find them by name")
Search("FRIEND")
Eq(#P.quiet.data, 1, "the search did not find them by tag")
Search("nobody like this")
Eq(#P.quiet.data, 0, "the search found somebody it should not")
Check(P.quietEmpty:GetText():find("matches"), "no-match text: " .. P.quietEmpty:GetText())
Search("bram")
P.quiet.rows[1]:Click()
Eq(ns.Diary.IsQuietNearby(A), true, "ticking the row did not make them quiet")
Eq(P.quietCount:GetText(), "1 quiet", "quiet count after ticking")
Eq(ns.Reunions.Due(A, "nearby", now), nil, "a nearby toast for somebody quiet nearby")
Eq(ns.Reunions.Due(A, "group", now), A, "quiet nearby held back a group toast")

Search("")
Eq(#P.quiet.data, 1, "the quiet list does not show who is quiet")
P.quiet.rows[1]:Click()
Eq(ns.Diary.IsQuietNearby(A), false, "unticking did not end it")
Eq(#P.quiet.data, 1, "an unticked row left at once, before it could be ticked back")
Eq(ns.Reunions.Due(A, "nearby", now), A, "no nearby toast after unticking")
P:Refresh()
Eq(#P.quiet.data, 0, "the unticked row stayed after the list was built again")

-- Kept on the diary entry, so it leaves with them.
ns.Diary.SetQuietNearby(A, true)
Eq(ns.Diary.SetQuietNearby(C, true), false, "somebody outside the diary marked quiet")

-- Numbers are clamped, and a shorter retention applies at once.
local function Commit(setting, text)
    setting.box:SetText(text)
    setting.box.scripts.OnEnterPressed(setting.box)
end

ns.Interactions.Add(C, "trade", { time = mock.now - 10 * DAY })
ns.db.sightings[STRANGER.guid] = { { time = mock.now - 10 * 24 * 3600, mapID = 1412 } }
Commit(P.bufferDays, "5")
Eq(ns.db.settings.bufferDays, 5, "retention not saved")
Eq(ns.db.sightings[STRANGER.guid], nil, "a shorter window did not roll up older sightings")
Eq(ns.Interactions.For(C), nil, "a shorter retention did not prune straight away")
Commit(P.bufferDays, "9999")
Eq(ns.db.settings.bufferDays, 365, "retention not clamped to its maximum")
Eq(P.bufferDays.box:GetText(), "365", "the box does not show the clamped value")
Commit(P.bufferDays, "")
Eq(ns.db.settings.bufferDays, 365, "an empty box changed the setting")
Eq(P.bufferDays.box:GetText(), "365", "an empty box was not restored")
Commit(P.sessionGap, "1")
Eq(ns.db.settings.sessionGapMinutes, 5, "session gap not clamped to its minimum")
Commit(P.toastCooldown, "45")
Eq(ns.db.settings.toastCooldownMinutes, 45, "toast cooldown not saved")
Commit(P.toastCooldown, "0")
Eq(ns.db.settings.toastCooldownMinutes, 1, "toast cooldown not clamped to its minimum")
ns.db.settings.bufferDays, ns.db.settings.sessionGapMinutes = 30, 20
ns.db.settings.toastCooldownMinutes = 10

-- INT-3: how many lines of chat are kept, or all of them.
local function Lines(guid)
    local n = 0
    for _, r in ipairs(ns.Interactions.For(guid) or {}) do
        if r.excerpt then n = n + 1 end
    end
    return n
end
local TALKER = "Player-4620-00EEEE20"
ns.Characters.Observe(TALKER, { first = "Chatty", surname = "Cathy" })
Eq(P.chatLines.box:GetText(), "50", "chat lines box")
Eq(P.chatUnlimited:GetChecked(), false, "no limit ticked by default")
for i = 1, 60 do ns.Interactions.Add(TALKER, "whisper_in", { excerpt = "line " .. i }) end
Eq(Lines(TALKER), 50, "the default limit")

Commit(P.chatLines, "5")
Eq(ns.db.settings.chatLines, 5, "chat lines not saved")
Eq(Lines(TALKER), 5, "a lower limit did not apply at once")
local rows = ns.Interactions.For(TALKER)
Eq(rows[#rows].excerpt, "line 60", "the limit kept old lines instead of the latest")
Commit(P.chatLines, "9999")
Eq(ns.db.settings.chatLines, 5000, "chat lines not clamped to their maximum")
Commit(P.chatLines, "5")

P.chatUnlimited:Click()
Eq(ns.db.settings.chatUnlimited, true, "no limit did not write through")
Check(not P.chatUnlimited.unavailable, "no limit unavailable with chat on")
for i = 61, 80 do ns.Interactions.Add(TALKER, "whisper_in", { excerpt = "line " .. i }) end
Eq(Lines(TALKER), 25, "lines were dropped with no limit")

P.chatUnlimited:Click()
Eq(Lines(TALKER), 5, "taking the limit back did not apply at once")

P.storeChat:Click()
Check(P.chatUnlimited.unavailable, "no limit available with chat off")
P.storeChat:Click()
ns.db.settings.chatLines = 50
ns.Characters.Forget(TALKER)

-- The size warning, past ns.SIZE_WARNING only.
Eq(P.sizeWarning:GetText(), "", "a size warning for a small diary")
local limit = ns.SIZE_WARNING
ns.SIZE_WARNING = 10
P:Refresh()
Check(P.sizeWarning:GetText():find("maximum chat lines"), "no size warning: " .. P.sizeWarning:GetText())
ns.SIZE_WARNING = limit
P:Refresh()

-- PRV-3: one character, outside the diary, by name.
ns.Characters.Observe(C, { first = "Norwood", surname = "Sparks" })
ns.Interactions.Add(C, "trade", {})
ns.Recent.Set("trade", C)
SlashCmdList.SOCIALDIARY("forget Norwood Sparks")
Check(mock.AnswerPopup("accept"), "/sd forget did not ask first")
Eq(ns.Characters.Get(C), nil, "forget left the character")
Eq(ns.Interactions.For(C), nil, "forget left the interactions")
Eq(ns.Recent.Get("trade"), nil, "forget left them in the picker's recent list")

-- ... and one in the diary, with a session.
ns.db.sessions[301] = {
    id = 301, me = SELF.guid, startedAt = mock.now - 600, endedAt = mock.now,
    participants = { [A] = { since = mock.now - 600, last = mock.now, seconds = 600 } },
    others = 0, zones = {}, deaths = {},
}
SlashCmdList.SOCIALDIARY("forget Bram Redfen")
mock.AnswerPopup("accept")
Eq(ns.Diary.IsDiary(A), false, "forget left the diary entry")
Eq(ns.Diary.IsQuietNearby(A), false, "forget left them quiet nearby")
Eq(ns.Characters.Get(A), nil, "forget left the diary entry's character")
Eq(next(ns.db.sessions), nil, "forget left their session")

local before = #mock.popups
SlashCmdList.SOCIALDIARY("forget")
Eq(#mock.popups, before, "/sd forget with no name asked about somebody")

-- PRV-3: all sightings.
ns.db.sightings.test = { 1 }
P.wipeSightings:Click()
mock.AnswerPopup("accept")
Eq(next(ns.db.sightings), nil, "sightings not deleted")

-- PRV-3: everything, but not the settings.
ns.Characters.Observe(B, { first = "Garrick", surname = "Fallow" })
ns.Diary.Add(B, { source = "test" })
ns.Recent.Set("whisper", B)
ns.db.settings.storeChat = false
P.wipeAll:Click()
Eq(ns.Diary.Count(), 1, "deleted before the user confirmed")
-- With a diary of its own, that is this character's diary and road.
local asked = mock.popups[#mock.popups].args[1]
Check(asked:find("this character's diary", 1, true) and asked:find("its road", 1, true)
    and not asked:find("every character", 1, true), "'delete everything' says whose wrongly: " .. asked)
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.button1, "Delete", "'delete everything' is not answered Delete")
mock.AnswerPopup("accept")
Eq(ns.Diary.Count(), 0, "the diary survived 'delete everything'")
Eq(next(ns.db.characters), nil, "characters survived 'delete everything'")
Eq(ns.Recent.Get("whisper"), nil, "the recent list survived 'delete everything'")
Eq(ns.db.settings.storeChat, false, "'delete everything' reset the settings")
Eq(_G.SocialDiaryCharDB.data.diary, ns.db.diary, "the saved table was replaced, so the wipe would not be saved")
Eq(ns.db.schema, 4, "schema missing after the wipe")
Check(ns.OwnCharacters()[SELF.guid], "the user's own characters went with the wipe")
Check(ns.db.meta.begun[SELF.guid], "the bookplate stamp was not taken again after the wipe")
Check(type(ns.db.meta.roster.members) == "table", "roster defaults missing after the wipe")
ns.db.settings.storeChat = true

-- DAT-1: one diary shared by every character, or one each, under Your
-- data. The box shows the diary loaded; the page's one account setting
-- says so.
local OWN_FILE = "WTF\\Account\\<account>\\<realm>\\<character>\\SavedVariables\\social_diary.lua"
local SHARED_FILE = "WTF\\Account\\<account>\\SavedVariables\\social_diary.lua"
P:Refresh()
Eq(ns.diaryShared, false, "the diary is shared before the switch")
Eq(P.shareDiary:GetChecked(), false, "the switch does not show the diary loaded")
Check(P.shareDiary.hint:GetText():find("every character", 1, true), "the switch does not say it is account-wide")
Check(ns.IsAccountSetting("shareDiary"), "the switch is not an account setting")
Check(P.dataHint:GetText():find(OWN_FILE, 1, true) and P.dataHint:GetText():find("This character's", 1, true),
    "Your data does not name this character's file: " .. P.dataHint:GetText())

-- Asked first; cancelled (the dialog runs nothing), nothing changes.
local popups, reloads = #mock.popups, mock.reloads
P.shareDiary:Click()
Eq(#mock.popups, popups + 1, "the switch did not ask first")
asked = mock.popups[#mock.popups].args[1]
Check(asked:find("interface reloads", 1, true) and asked:find("Nothing is copied or deleted", 1, true)
    and asked:find("every character then uses the shared diary", 1, true),
    "the question does not say what happens: " .. asked)
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.button1, "Reload", "the switch's question is answered Delete")
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.showAlert, false, "the switch's question carries the alert")
Eq(P.shareDiary:GetChecked(), false, "the box ticked before the user answered")
Eq(ns.Setting("shareDiary"), false, "the choice was saved before the user answered")
Eq(mock.reloads, reloads, "reloaded before the user answered")
P:Refresh()
Eq(P.shareDiary:GetChecked(), false, "a cancelled switch shows the other diary")

-- Accepted: the choice is saved for the next load, and the interface
-- reloads. The diary in use stays until it has.
P.shareDiary:Click()
mock.AnswerPopup("accept")
Eq(ns.Setting("shareDiary"), true, "accepting did not save the choice")
Eq(mock.reloads, reloads + 1, "accepting did not reload the interface")
Eq(ns.diaryShared, false, "the diary changed before the reload")
P:Refresh()
Eq(P.shareDiary:GetChecked(), false, "the box shows the choice, not the diary loaded")

-- The next load: shared. The copy names the account file and the shared
-- diary, and deleting everything deletes that one.
_G.SocialDiaryCharDB.data.characters["Player-1-9"] = { guid = "Player-1-9" }
ns.InitDB()
Eq(ns.diaryShared, true, "the shared diary was not loaded")
P:Refresh()
Eq(P.shareDiary:GetChecked(), true, "the switch does not show the shared diary loaded")
Check(P.dataHint:GetText():find(SHARED_FILE, 1, true) and P.dataHint:GetText():find("The shared diary", 1, true),
    "Your data does not name the account file: " .. P.dataHint:GetText())
ns.db.characters["Player-1-8"] = { guid = "Player-1-8" }
P.wipeAll:Click()
asked = mock.popups[#mock.popups].args[1]
Check(asked:find("Delete the shared diary?", 1, true) and asked:find("every character's road", 1, true),
    "'delete everything' says whose wrongly when shared: " .. asked)
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.button1, "Delete", "Delete lost its name after the switch")
Eq(StaticPopupDialogs.SOCIAL_DIARY_CONFIRM.showAlert, true, "Delete lost its alert after the switch")
mock.AnswerPopup("accept")
Eq(_G.SocialDiaryDB.shared.characters["Player-1-8"], nil, "the shared diary survived 'delete everything'")
Check(_G.SocialDiaryCharDB.data.characters["Player-1-9"], "the character's own diary went with the shared one")

-- Back to one each: the question names this character's own diary.
reloads = mock.reloads
P.shareDiary:Click()
asked = mock.popups[#mock.popups].args[1]
Check(asked:find("its own diary, empty if it never had one", 1, true)
    and asked:find("Nothing is copied or deleted", 1, true), "the way back does not say what happens: " .. asked)
Eq(P.shareDiary:GetChecked(), true, "the box unticked before the user answered")
mock.AnswerPopup("accept")
Eq(ns.Setting("shareDiary"), false, "the way back was not saved")
Eq(mock.reloads, reloads + 1, "the way back did not reload")
ns.InitDB()
Eq(ns.diaryShared, false, "the character's own diary was not loaded again")
Check(ns.db.characters["Player-1-9"], "the character's own diary did not come back")
ns.db.characters["Player-1-9"] = nil
P:Refresh()
Eq(P.shareDiary:GetChecked(), false, "the switch does not show the own diary loaded again")

-- PRV-4: the parcel at every login until the front matter has been read.
ns.UI.CloseJournal()
ns.db.settings.frontRead = false
ns.db.settings.parcelOpened = false
mock.timers = {}
mock.fire("PLAYER_LOGIN")
mock.RunTimers()
local S = ns.UI.Slip()
Check(S and S:IsShown(), "the parcel did not show on first login")
Eq(S.state, "wrapped", "the parcel did not arrive wrapped")
Check(S.wrapped:IsShown() and not S.torn:IsShown(), "the wrapped parcel is not the one shown")

-- Its label names the diary and says nothing leaves this computer
-- (PRV-1), for someone who only ever clicks Later; the days are the book's.
Eq(S.label.title:GetText(), "ONE SOCIAL DIARY", "the label does not name the diary")
Check(S.label.keeps:GetText():find("nothing leaves this computer"), "PRV-1 not on the label")
for _, text in pairs(S.label) do Check(not text:GetText():find("day"), "the label talks of days") end

-- Its maker's: the goblins' for the Horde, the gnomes' for the Alliance,
-- postmarked today.
Eq(S.maker, "goblin", "a Horde parcel not from the goblins")
Eq(S.sender[1]:GetText(), "GRIZZIK'S DIARIES", "the goblins' name is not on it")
Check(S.seal.letter:IsShown() and not S.seal.cog[1]:IsShown(), "the goblins' seal does not show their coin")
local today = ("%d %s"):format(tonumber(date("%d")), date("%b"):upper())
Eq(S.postmark[2]:GetText(), today, "the goblins' postmark is not today's")
S:Hide()
mock.SetUnit("player", F.Like(SELF, { faction = { "Alliance", "Alliance" } }))
ns.UI.OfferSlip()
Eq(S.maker, "gnome", "an Alliance parcel not from the gnomes")
Eq(S.sender[1]:GetText(), "WIZZLEBOLT & DAUGHTER", "the gnomes' name is not on it")
Check(S.seal.cog[1]:IsShown() and not S.seal.letter:IsShown(), "the gnomes' seal does not show their cog")
Eq(S.postmark[3]:GetText(), today, "the gnomes' postmark is not today's")
mock.SetUnit("player", SELF)

-- Built once, torn edges and all, within its budget (about 400 textures,
-- the closed book's 75 and the teeth's 120 among them).
Check(S.counts.teeth > 100, "the paper is not torn all round")
Check(S.counts.textures < 450, ("the parcel takes %d textures"):format(S.counts.textures))

-- Later puts it away for this login; the next brings it back, wrapped.
S.later:Click()
Check(not S:IsShown(), "Later did not put the parcel away")
Eq(ns.db.settings.parcelOpened, false, "Later tore the parcel open")
Eq(ns.db.settings.frontRead, false, "Later counted as reading the front matter")
mock.fire("PLAYER_LOGIN")
mock.RunTimers()
Check(S:IsShown(), "the parcel did not come back at the next login")
Eq(S.state, "wrapped", "the parcel came back unwrapped")

-- Never in a fight: one starting puts it away until it is over, and one
-- under way at login holds it back.
mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Check(not S:IsShown(), "the parcel stayed up in a fight")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Check(S:IsShown(), "the parcel did not come back after the fight")
S:Hide()
mock.inCombat = true
mock.fire("PLAYER_LOGIN")
mock.RunTimers()
Check(not S:IsShown(), "the parcel showed in a fight")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Check(S:IsShown(), "the parcel did not show once the fight was over")

-- The seal tears it open, with the sound of a bag opened: the closed
-- book inside, and the diary's note beside it.
mock.sounds = {}
S.seal:Click()
Eq(S.state, "torn", "the seal did not tear the parcel open")
Eq(ns.db.settings.parcelOpened, true, "tearing it open was not kept")
Check(S.torn:IsShown() and not S.wrapped:IsShown(), "the torn parcel is not the one shown")
Eq(mock.sounds[#mock.sounds] and mock.sounds[#mock.sounds][1], 862, "no sound of the wrapping coming off")
Eq(S.book.title:GetText(), "SOCIAL\nDIARY", "the book inside is not the diary")
Check(S.note:IsShown(), "no note beside the book")
-- The greeting, its lines joined: it wraps where it is wider than the note.
local function Greeting()
    local said = {}
    for _, line in ipairs(S.note.hellos) do
        if line:IsShown() and line:GetText() ~= "" then said[#said + 1] = line:GetText() end
    end
    return table.concat(said, " ")
end
Check(Greeting():find("I'm your new diary"), "the note does not introduce the diary")
Check(S.note.keeps:GetText():find("nothing leaves this computer"), "PRV-1 not on the note")
local wrote = {}
for _, line in ipairs(S.note.lines) do
    if line:GetText() ~= "" then wrote[#wrote + 1] = line:GetText() end
end
Check(table.concat(wrote, " "):find("until you ink someone in%.$"), "the note lost words")

-- How many it has pencilled in, as it stands: nobody, then one stranger,
-- then three.
Eq(ns.People.PencilledCount(), 0, "someone is pencilled in after the wipe")
Check(S.note.count:GetText():find("Nobody yet"), "the note counts someone after the wipe")
local strangers = { "Player-1-00000A01", "Player-1-00000A02", "Player-1-00000A03" }
ns.Interactions.Add(strangers[1], "trade", {})
S:Hide()
ns.UI.OfferSlip()
Check(S.note.count:GetText():find("pencilled in one already"), "one stranger not counted")
ns.Interactions.Add(strangers[2], "trade", {})
ns.Interactions.Add(strangers[3], "trade", {})
S:Hide()
ns.UI.OfferSlip()
Check(S.note.count:GetText():find("pencilled in 3 already"), "three strangers not counted")
for _, guid in ipairs(strangers) do ns.db.interactions[guid] = nil end

-- Flat paper only: no shadows, no turn, even tears.
ns.db.settings.flatSheets = true
S:Hide()
ns.UI.OfferSlip()
Check(not S.book.shadows[1]:IsShown(), "the book casts a shadow laid flat")
Check(S.note.flat, "the note is not laid flat")
ns.db.settings.flatSheets = false
S:Hide()
ns.UI.OfferSlip()
Check(S.book.shadows[1]:IsShown(), "the book's shadow did not come back")

-- Later on the note; the next login finds it torn already, and greets you
-- again.
S.note.later:Click()
Check(not S:IsShown(), "the note's Later did not put the parcel away")
mock.fire("PLAYER_LOGIN")
mock.RunTimers()
Check(S:IsShown(), "the torn parcel did not come back at the next login")
Eq(S.state, "torn", "the parcel came back wrapped again")
Check(Greeting():find("still here whenever you're ready"), "the note does not greet you again")
Check(S.note.hellos[2]:IsShown(), "the longer greeting did not wrap")
mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Check(not S:IsShown(), "the torn parcel stayed up in a fight")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Check(S:IsShown(), "the torn parcel did not come back after the fight")

-- Open it: the book opens on the introduction's first leaf, the
-- frontispiece; that is not reading the front matter yet.
S.note.open:Click()
Check(not S:IsShown(), "opening the book left the parcel up")
Check(_G.SocialDiaryJournalFrame:IsShown(), "Open me did not open the book")
Eq(ns.UI.JournalView(), "frontispiece", "the book did not open on the frontispiece")
Eq(ns.db.settings.frontRead, false, "the frontispiece counted as reading the front matter")
local FP = ns.UI.Frontispiece()
Check(FP.key.pencil:GetText():find("after 30 days"), "the frontispiece does not use the retention setting")
Check(FP.key.ink:GetText():find("for good"), "the frontispiece does not say ink is kept")
Eq(FP.figure.faded.days[1]:GetText(), "day 1", "the fading starts on another day")
Eq(FP.figure.faded.days[4]:GetText(), "day 30", "the fading does not end at the retention")
Eq(FP.figure.inked.name:GetText(), "THEX THEXIMUS", "the inked name is missing")
Eq(FP.figure.inked.ghost:GetText(), "THEX THEXIMUS", "no pencil under the ink")
Check(FP.drawn, "the leaders and the ring were not drawn")
Check(not (ns.UI.IntroLabel() and ns.UI.IntroLabel():IsShown()), "the label shows on the introduction itself")

-- Its corner turns to the front matter, and that is reading it.
FP.corner:Click()
Eq(ns.UI.JournalView(), "front", "the frontispiece's corner did not turn to the front matter")
Eq(ns.db.settings.frontRead, true, "the front matter was not marked read")
local FM = ns.UI.FrontMatter()
Check(FM.kept.where:GetText():find("in your WTF folder"), "PRV-1 not stated")
Check(FM.kept.limits:GetText():find("nameplates on"), "what it cannot see is not stated")
Check(FM.contents.nearby.about:GetText():find("30 days"), "the contents do not use the retention setting")
Check(FM.plate.name:GetText():find("ULVERSTON"), "the bookplate does not name the character")
Check(ns.db.meta.begun[SELF.guid], "when the diary was begun was not stamped")
Check(FM.plate.begun:GetText():find("^Begun "), "the bookplate does not say when it was begun")

-- A stamp taken before the client knew the zone says no zone, not an
-- empty one, and takes the zone once it is known, the same login.
local begun = ns.db.meta.begun
local stamped = begun[SELF.guid]
begun[SELF.guid] = nil
local zone = mock.zone
mock.zone = ""
ns.TouchOwnCharacter()
Eq(begun[SELF.guid].zone, nil, "an empty zone was stamped")
ns.UI.RefreshFrontMatter()
Check(FM.plate.begun:GetText():find("^Begun on "), "the bookplate names an empty zone")
mock.zone = zone
mock.fire("PLAYER_ENTERING_WORLD")
Eq(begun[SELF.guid].zone, zone, "the zone was not filled in once known")
begun[SELF.guid] = stamped

-- The contents: a cut-out of each page beside its name.
local C = FM.contents
Check(C.journey.cut and C.journey.cut.drawn, "Your Diary's cut-out was not drawn")
Eq(C.people.cut.name:GetText(), "THEX THEXIMUS", "People's cut-out is not Thex's page")
Eq(C.people.cut.corners, 3, "People's cut-out is not held by three corners")
Eq(#C.nearby.cut.rows, 3, "Recently nearby's cut-out has no rows")
Eq(C.nearby.cut.corners, 0, "Recently nearby's cut-out has corners")

-- Chat, switched off and on from here, as the settings would.
FM.kept.chat.no:Click()
Eq(ns.db.settings.storeChat, false, "Don't did not switch chat off")
Check(FM.kept.chat.no.current, "the current chat choice is not marked")
FM.kept.chat.yes:Click()
Eq(ns.db.settings.storeChat, true, "Keep did not switch chat on")

-- PRV-7: the road, said as it is, and switched from here like the chat.
Check(FM.kept.limits:GetText():find("only your own position"), "it does not say whose position the road is")
Check(FM.kept.limits:GetText():find("kept for good"), "it does not say for how long")
Check(FM.kept.route.yes.current, "the current road choice is not marked")
FM.kept.route.no:Click()
Eq(ns.db.settings.keepRoute, false, "Don't did not switch the road off")
Check(FM.kept.limits:GetText():find("No road of yours"), "the front matter ignores the road setting")
Check(FM.kept.route.no.current, "the off choice is not marked")
FM.kept.route.yes:Click()
Eq(ns.db.settings.keepRoute, true, "Keep did not switch the road back on")

-- The ribbons turn the book from the introduction (playtesters asked),
-- and leaving it that way puts a label under the book: OK goes back.
local J = _G.SocialDiaryJournalFrame
Eq(ns.db.settings.introDone, false, "the introduction counts as done before its end")
J.ribbons.people:Click()
Eq(ns.UI.JournalView(), "people", "the People ribbon did not turn the book from the front matter")
local L = ns.UI.IntroLabel()
Check(L and L:IsShown() and L.view:IsShown(), "no label after leaving the introduction early")
L.ok:Click()
Eq(ns.UI.JournalView(), "frontispiece", "OK did not turn back to the introduction")
Check(not L:IsShown(), "the label stayed on the introduction")
J.ribbons.nearby:Click()
Eq(ns.UI.JournalView(), "nearby", "the ribbon did not turn the book from the frontispiece")
Check(L:IsShown(), "the label did not come back")

-- Closed and opened again, it is still there; Dismiss puts it away for good.
ns.UI.CloseJournal()
ns.UI.ShowJournal()
Eq(ns.UI.JournalView(), "nearby", "the book did not open where it was left once read")
Check(L:IsShown() and L.view:IsShown(), "the label did not come back with the book")
L.dismiss:Click()
Check(not L:IsShown(), "Dismiss did not put the label away")
Eq(ns.db.settings.introDone, true, "Dismiss was not kept")
ns.UI.SetJournalView("people")
Check(not L:IsShown(), "the label came back after Dismiss")

-- Turned through to its end, the introduction is done, label or not.
ns.db.settings.introDone = false
ns.UI.SetJournalView("front")
FM.corner:Click()
Eq(ns.UI.JournalView(), "journey", "the corner did not turn the page to Your Diary")
Eq(ns.db.settings.introDone, true, "the end of the introduction was not kept")
Check(not L:IsShown(), "the label showed after the introduction's end")
ns.UI.CloseJournal()
ns.UI.ShowJournal()
Eq(ns.UI.JournalView(), "journey", "the book still opens on the introduction once read")
ns.UI.CloseJournal()

mock.fire("PLAYER_LOGIN")
mock.RunTimers()
Check(not S:IsShown(), "the parcel came back once the front matter was read")

-- /sd about and the settings turn back to it.
SlashCmdList.SOCIALDIARY("about")
Eq(ns.UI.JournalView(), "frontispiece", "/sd about did not turn to the introduction")
ns.UI.SetJournalView("settings")
P.intro:Click()
Eq(ns.UI.JournalView(), "frontispiece", "the settings' link did not turn to the introduction")
ns.UI.CloseJournal()

-- Opened on someone, the book opens on them, read or not.
ns.db.settings.frontRead = false
ns.UI.ShowJournal(A)
Eq(ns.UI.JournalView(), "people", "a book opened on someone opened on the front matter")
ns.UI.CloseJournal()
ns.db.settings.frontRead = true

--------------------------------------------------------------------------
Section("forgetting, everywhere (PRV-3)")

local Capture = ns.SightingCapture
local Drain = ns._test.DrainSightings
local WHERE = { mapID = 1412, x = 0.5, y = 0.5 }

-- "Delete all sightings" takes the raw rows, the encounter under way and
-- the rolled-up summary, so "Seen N times" goes with them.
local SEEN = "Player-4620-00EEEE10"
ns.Characters.Observe(SEEN, { first = "Often", surname = "Seen" })
ns.Sightings.Record(SEEN, { source = "plate" }, WHERE, mock.now - 40 * DAY)
ns.Sightings.Rollup(mock.now)
Check(ns.db.characters[SEEN].sightingSummary, "setup: nothing rolled up")
ns.Sightings.Record(SEEN, { source = "plate" }, WHERE, mock.now)
Eq(ns.Sightings.Summary(SEEN).count, 2, "setup: summary and raw row")
-- An hour on, so the encounter under way does not decide the answer.
Eq(ns.Sightings.SeenBefore(SEEN, mock.now + 3600), 2, "setup: not seen before")
Check(ns.Sightings.EncounterState(SEEN), "setup: no encounter")

-- Someone outside the diary with an interaction, and a diary entry, both
-- last seen somewhere.
local TRADED, KEPT = "Player-4620-00EEEE13", "Player-4620-00EEEE14"
ns.Characters.Observe(TRADED, { first = "Once", surname = "Traded" })
ns.Characters.Seen(TRADED, WHERE)
ns.Interactions.Add(TRADED, "trade")
ns.Characters.Observe(KEPT, { first = "Kept", surname = "Close" })
ns.Diary.Add(KEPT, { source = "test" })
ns.Characters.Seen(KEPT, WHERE)

ns.UI.SettingsPage().wipeSightings:Click()
mock.AnswerPopup("accept")
Eq(next(ns.db.sightings), nil, "raw sightings survived 'Delete all sightings'")
Eq(ns.Sightings.Summary(SEEN), nil, "'Delete all sightings' left the rolled-up summary")
Eq(ns.Sightings.SeenBefore(SEEN, mock.now + 3600), nil, "'Seen N times' survived 'Delete all sightings'")
Eq(ns.Sightings.EncounterState(SEEN), nil, "the encounter survived 'Delete all sightings'")
Eq(ns.Characters.Get(SEEN), nil, "'Delete all sightings' kept someone known only from sightings")
Check(ns.Characters.Get(TRADED), "'Delete all sightings' deleted someone with an interaction")
Eq(ns.Characters.Get(TRADED).seen, nil, "'Delete all sightings' left where a stranger was last seen")
Check(ns.Characters.Get(KEPT) and ns.Characters.Get(KEPT).seen, "'Delete all sightings' touched a diary entry")
Check(ns.Diary.IsDiary(KEPT), "'Delete all sightings' removed a diary entry")

-- One person, from every registered store: a visit's member list, the
-- saved roster, the toast cooldown and the toast on screen, and the
-- sighting queue, which would otherwise bring them straight back.
local GONE = { guid = "Player-4620-00EEEE11", name = { "Gone", "Forever" }, level = 14 }
local STAYS = "Player-4620-00EEEE12"
ns.Characters.Observe(GONE.guid, { first = "Gone", surname = "Forever" })
ns.Diary.Add(GONE.guid, { source = "test" })
ns.db.instances[901] = {
    id = 901, name = "Wailing Caverns", startedAt = mock.now - 3600, endedAt = mock.now - 600,
    members = { { guid = GONE.guid, first = "Gone", surname = "Forever" }, { guid = STAYS, first = "Stays" } },
}
ns.db.meta.roster.members[GONE.guid] = true

for _ = 1, 10 do
    if not ns.UI.ReunionShowing() then break end
    mock.RunTimers()
end
ns.UI.Reunion(GONE.guid)
local shown = ns.UI.ReunionShowing()
Check(shown and shown.guid == GONE.guid, "setup: no toast for them")
Check(ns.db.meta.greeted[GONE.guid], "setup: no cooldown stamp")

mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
Eq((Capture.Evaluate()), "active", "setup: not listening")
while Capture.QueueLength() > 0 do Drain() end
mock.SetUnit("nameplate9", GONE)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
Eq(Capture.QueueLength(), 1, "setup: not queued")

ns.Characters.Forget(GONE.guid)
Eq(Capture.QueueLength(), 0, "forget left them in the sighting queue")
Drain()
Eq(ns.db.characters[GONE.guid], nil, "the sighting queue brought them back")
Eq(ns.db.sightings[GONE.guid], nil, "the sighting queue stored a row for them")
local members = ns.db.instances[901].members
Eq(#members, 1, "forget left them in a visit's member list")
Eq(members[1].guid, STAYS, "forget took the wrong member out of the visit")
Eq(ns.db.meta.roster.members[GONE.guid], nil, "forget left them in the saved roster")
Eq(ns.db.meta.greeted[GONE.guid], nil, "forget left their toast cooldown")
Eq(ns.UI.ReunionShowing(), nil, "their toast stayed on screen")
ns.db.instances[901] = nil

-- Everyone: what lives in memory only goes with the saved tables.
ns.Characters.Observe(SEEN, { first = "Often", surname = "Seen" })
ns.Sightings.Record(SEEN, { source = "plate" }, WHERE, mock.now)
mock.now = mock.now + 61
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
Eq(Capture.QueueLength(), 1, "setup: not queued")
ns.Recent.Set("trade", SEEN)

ns.WipeData()
Eq(Capture.QueueLength(), 0, "the sighting queue survived 'delete everything'")
Eq(ns._test.SightingThrottleSize(), 0, "throttle stamps survived 'delete everything'")
Eq(ns.Sightings.EncounterState(SEEN), nil, "an encounter survived 'delete everything'")
Eq(ns.Recent.Get("trade"), nil, "the recent list survived 'delete everything'")
Check(ns.OwnCharacters()[SELF.guid], "own character not re-recorded after the wipe")

--------------------------------------------------------------------------
Section("sightings: the switch and the cities")

local Capture = ns.SightingCapture
Check(P.detectSightings and P.detectSightings:GetChecked(), "no sightings switch, or it is off by default")
P.detectSightings:Click()
Eq(ns.db.settings.detectSightings, false, "the sightings switch did not write through")
Eq((Capture.Evaluate()), "off", "switching sightings off did not stop the capture")
local stormwind = P.cities[1453]
Check(stormwind and stormwind.unavailable, "the cities stay available with sightings off")
P.detectSightings:Click()
Eq(ns.db.settings.detectSightings, true, "the sightings switch did not switch back on")
Check(not stormwind.unavailable, "the cities did not come back with sightings")

Eq(stormwind.label:GetText(), ns.MapName(1453) or "map 1453", "a city box is not named after its map")
-- Ticked is noticing people there; the defaults pause, so they start unticked.
Eq(stormwind:GetChecked(), false, "a city it pauses in shows ticked")
stormwind:Click()
Eq(ns.db.settings.cities[1453], false, "ticking a city did not stop the pause there")
Eq(stormwind:GetChecked(), true, "the city did not tick")
stormwind:Click()
Eq(ns.db.settings.cities[1453], true, "unticking a city did not pause there again")
local n = 0
for _ in pairs(P.cities) do n = n + 1 end
Eq(n, #Capture.Cities(), "not every city on the list has a box")

--------------------------------------------------------------------------
Section("keybinds and shortcuts: both keys, the book for a bar, /sd")

local Keys = ns.UI.Keys
P:ShowSection("shortcuts")
local JOURNAL, REMEMBER = P.keys.SOCIALDIARY_JOURNAL, P.keys.SOCIALDIARY_REMEMBER
Check(JOURNAL and REMEMBER, "a binding from Bindings.xml has no key on the page")

-- Both keys, unbound to begin with, bound from here as the empty People
-- page binds Remember this (UI/Kit/Keys.lua).
mock.bindings = {}
JOURNAL:Refresh()
REMEMBER:Refresh()
Eq(JOURNAL.keycap.text:GetText(), "no key", "an unbound journal key is not shown as unbound")
Eq(JOURNAL.bind:GetText(), "Choose one", "an unbound key offers no way to bind it")
JOURNAL.bind:Click()
Check(JOURNAL.listening, "Choose one did not listen for a key")
-- Starting the other stops the first: one keyboard, one listener.
REMEMBER.bind:Click()
Check(REMEMBER.listening and not JOURNAL.listening, "two keys listened at once")
REMEMBER.catcher.scripts.OnKeyDown(REMEMBER.catcher, "ESCAPE")
JOURNAL.bind:Click()
JOURNAL.catcher.scripts.OnKeyDown(JOURNAL.catcher, "F6")
Eq(mock.bindings.F6, "SOCIALDIARY_JOURNAL", "the key was not bound to the journal")
Eq(JOURNAL.keycap.text:GetText(), "F6", "the journal's new key is not shown")
Eq(JOURNAL.bind:GetText(), "Change", "a bound key does not offer to change it")

-- The journal's key taken for Remember this: both rows read again, and
-- the line under them says what the key did before.
REMEMBER.bind:Click()
REMEMBER.catcher.scripts.OnKeyDown(REMEMBER.catcher, "F6")
Eq(mock.bindings.F6, "SOCIALDIARY_REMEMBER", "the key was not moved to Remember this")
Eq(REMEMBER.keycap.text:GetText(), "F6", "Remember this's key is not shown")
Eq(JOURNAL.keycap.text:GetText(), "no key", "the journal still shows the key it lost")
Check(P.keyStatus:GetText():find("Open the journal"), "what the key did before is not said: " .. P.keyStatus:GetText())
REMEMBER.bind:Click()
REMEMBER.catcher.scripts.OnKeyDown(REMEMBER.catcher, "Q")
Check(REMEMBER.listening and P.keyStatus:GetText() == Keys.MODIFIER_HINT, "a typing key alone was not refused")
REMEMBER.catcher.scripts.OnKeyDown(REMEMBER.catcher, "ESCAPE")
mock.inCombat = true
JOURNAL.bind:Click()
Check(not JOURNAL.listening, "it listened for a key in a fight")
Check(P.keyStatus:GetText():find("fight"), "a fight's refusal is not said")
mock.inCombat = false
mock.bindings = {}

-- The book: no macro until it is dragged or clicked, whatever logged in.
Eq(#mock.macros, 0, "a macro was made before anybody asked for one")
local B = P.macroBooks.journal
Eq(B.label:GetText(), "Open Social Diary", "the journal's book is not named")
Check(not B.unavailable, "the book is faded out of combat")
B.scripts.OnDragStart(B)
Eq(#mock.macros, 1, "dragging the book did not make the macro")
local made = mock.macros[1]
Eq(made.name, "Social Diary", "the macro's name")
Eq(made.body, "/sd", "the macro does not type /sd")
Eq(made.icon, "INV_Misc_Book_09", "the macro does not wear the addon's icon")
Eq(mock.cursor and mock.cursor[1], "macro", "dragging did not put the macro on the cursor")
Eq(mock.cursor and mock.cursor[2], 1, "the wrong macro on the cursor")
Eq(P.macroStatus:GetText(), "", "a drag answered with words")
ClearCursor()

-- Made once: clicking after finds it by name, and says where to put it.
table.insert(mock.macros, 1, { name = "Mount up", body = "/use Horn" })
B:Click()
Eq(#mock.macros, 2, "a second click made a second macro")
Eq(mock.cursor and mock.cursor[2], 2, "the click did not pick up the macro already made")
Check(P.macroStatus:GetText():find("cursor"), "a click did not say where to put it")
ClearCursor()
local ok, index = ns.UI.PickupDiaryMacro()
Check(ok and index == 2, "PickupDiaryMacro did not find the macro made before")
ClearCursor()

-- Remember this has its own book and its own macro, beside the journal's.
local R = P.macroBooks.remember
Eq(R.label:GetText(), "Remember this", "Remember this's book is not named")
R.scripts.OnDragStart(R)
Eq(#mock.macros, 3, "dragging Remember this's book did not make its macro")
made = mock.macros[3]
Eq(made.name, "Remember This", "Remember this's macro name")
Eq(made.body, "/sd remember", "Remember this's macro does not type /sd remember")
Eq(made.icon, "INV_Misc_Note_01", "Remember this's macro icon")
Eq(mock.cursor and mock.cursor[2], 3, "the wrong macro on the cursor for Remember this")
ClearCursor()
R:Click()
Eq(#mock.macros, 3, "a second Remember this made a second macro")
ClearCursor()

-- In a fight: faded, refused without a macro, and back after it.
mock.macros = {}
mock.inCombat = true
mock.fire("PLAYER_REGEN_DISABLED")
Check(B.unavailable and R.unavailable, "the books are not faded in a fight")
Eq(P.macroStatus:GetText(), Keys.COMBAT, "the fight is not said under the book")
Eq(select(2, ns.UI.PickupDiaryMacro()), "combat", "PickupDiaryMacro did not refuse in a fight")
B.scripts.OnDragStart(B)
B:Click()
Eq(#mock.macros, 0, "a macro was made in a fight")
Eq(mock.cursor, nil, "something was picked up in a fight")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Check(not B.unavailable, "the book did not come back after the fight")
Check(not R.unavailable, "Remember this's book did not come back after the fight")
Eq(P.macroStatus:GetText(), "", "the fight is still said after it")

-- The macro book full: nothing made or picked up, and /sd offered instead.
for i = 1, 120 do mock.macros[i] = { name = "Macro " .. i, body = "/wave" } end
local why
ok, why = ns.UI.PickupDiaryMacro()
Check(not ok and why == "full", "a full macro book was not refused")
B.scripts.OnDragStart(B)
Eq(#mock.macros, 120, "a macro was made past the limit")
Eq(mock.cursor, nil, "something was picked up with the macros full")
Check(P.macroStatus:GetText():find("/sd works anywhere"), "a full macro book is not explained")
R.scripts.OnDragStart(R)
Check(P.macroStatus:GetText():find("/sd remember works anywhere"), "a full macro book is not explained for Remember this")
-- The client refusing it below the limit says the same.
mock.macros, mock.maxMacros = { { name = "A" }, { name = "B" } }, 2
ok, why = ns.UI.PickupDiaryMacro()
Check(not ok and why == "full", "CreateMacro's refusal was not caught")
Eq(#mock.macros, 2, "a refused macro was kept")
mock.macros, mock.maxMacros = {}, 120
P:Refresh()

-- The slash commands listed are the ones there are.
local registered = {}
for _, command in ipairs(ns._test.SlashCommands()) do
    for _, name in ipairs(command.names) do registered[name] = true end
end
registered.help = true  -- anything unknown answers with the list
Check(#P.commands >= 5, "too few slash commands listed")
for _, line in ipairs(P.commands) do
    local word = line:GetText():match("^/sd%s*(%S*)")
    Check(word and registered[word], "a slash command listed that does not exist: " .. line:GetText())
end
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("every ribbon page in the contents and on the parcel (decision 4)")

-- The front matter's cut-outs and the parcel's ribbons are placed by hand,
-- by the page's key, and take the page's colour and name from the
-- registry (UI/Journal/Pages.lua): a ribbon page added without its
-- cut-out (unless it says contents = false) or its ribbon on the closed
-- book fails here. And neither places one for a page that has no ribbon.
local ribbonKeys = {}
for _, ribbon in ipairs(ns.UI.Journal.Ribbons()) do
    local key = ribbon.key
    ribbonKeys[key] = true
    local entry = ns.UI.FrontMatter().contents[key]
    if ribbon.page.contents == false then
        Eq(entry, nil, key .. " is in the contents, though it says it is not")
    else
        Check(entry and entry.cut, key .. " has no cut-out in the front matter's contents")
        Eq(entry and entry.link.label:GetText(), ribbon.label, key .. "'s name in the contents is not its ribbon's")
    end
    local cloth = ns.UI.Slip().book.ribbons[key]
    Check(cloth ~= nil, key .. " has no ribbon on the parcel's closed book")
    local want = ns.Style.RIBBONS[ribbon.colour].cloth
    local got = cloth and cloth.recorded.calls.SetColorTexture or {}
    Eq(table.concat({ tostring(got[1]), tostring(got[2]), tostring(got[3]) }, " "),
        table.concat({ want[1], want[2], want[3] }, " "), key .. "'s ribbon on the parcel is not its cloth")
end
for key, entry in pairs(ns.UI.FrontMatter().contents) do
    if type(entry) == "table" and entry.cut then
        Check(ribbonKeys[key], "the contents have a cut-out for " .. key .. ", which has no ribbon")
    end
end
for key in pairs(ns.UI.Slip().book.ribbons) do
    Check(ribbonKeys[key], "the parcel has a ribbon for " .. key .. ", which has no ribbon in the book")
end
-- The empty People page's arrow points at Recently nearby's ribbon, under
-- a link in the page's own name.
Eq(ns.UI.JournalFrame().welcome.nearby.label:GetText(), ns.UI.Journal.Page("nearby").ribbon.label,
    "the empty page's link is not in Recently nearby's name")
