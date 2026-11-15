-- Auto-add's question (UI/Windows/AutoAdd.lua): switched on in Settings >
-- Recording with people waiting, a paper sheet offers them; "Add them" adds
-- the list it opened on, "Not now" and Escape add nobody; switched off, or
-- on with nobody waiting, nothing shows. Then the same with the pad
-- (UI/Windows/Pad.lua's `autoadd`).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Sheet = ns.UI.AutoAdd
local Pad = ns.UI.Pad
local MAP = { mapID = 1412, zone = "Mulgore" }
local HOUR = 3600

mock.now = 1790000000
T.BlankDiary()

-- Four people seen three times each, one twice (not waiting).
local PEOPLE = {
    { guid = "Player-1-0A000001", first = "Aldwin" },
    { guid = "Player-1-0A000002", first = "Brenna" },
    { guid = "Player-1-0A000003", first = "Corwen" },
    { guid = "Player-1-0A000004", first = "Dalla" },
}
local TWICE = "Player-1-0A000005"

local function Seed()
    T.BlankDiary()
    ns.db.sightings = {}
    ns.db.meta.declined = {}
    for _, p in ipairs(PEOPLE) do
        ns.Characters.Observe(p.guid, { first = p.first, level = 20, class = "MAGE" })
        for i = 1, 3 do
            ns.Sightings.Record(p.guid, { source = "plate" }, MAP, mock.now + (i - 1) * HOUR)
        end
    end
    ns.Characters.Observe(TWICE, { first = "Edda", level = 20, class = "MAGE" })
    ns.Sightings.Record(TWICE, { source = "plate" }, MAP, mock.now)
    ns.Sightings.Record(TWICE, { source = "plate" }, MAP, mock.now + HOUR)
end

local P = ns.UI.SettingsPage()
local function Switch(on)
    if (ns.Setting("autoAdd") == true) ~= on then P.autoAdd:Click() end
    Eq(ns.Setting("autoAdd") == true, on, "setup: the switch did not turn " .. (on and "on" or "off"))
end

-- Every line of words on the sheet, joined.
local function Words()
    local out = {}
    for _, fs in ipairs(Sheet.View().texts) do
        if fs:IsShown() then out[#out + 1] = fs:GetText() end
    end
    return table.concat(out, " ")
end

--------------------------------------------------------------------------
Section("switched on with people waiting: the sheet asks")

Seed()
ns.SetSetting("autoAdd", false)
Check(not Sheet.Shown(), "the sheet is up before the switch")
Switch(true)
Check(Sheet.Shown(), "switched on with four waiting: no sheet")
Check(Sheet.View():IsShown(), "the paper is not laid")
Eq(#Sheet.View().list, 4, "the list it opened on")
local words = Words()
Check(words:find("You’ve seen 4 people near you 3 times or more.", 1, true), "the count: " .. words)
Check(words:find("Aldwin, Brenna, Corwen and 1 other", 1, true), "the names: " .. words)
Check(not words:find("Edda", 1, true), "someone seen twice is offered")
Check(words:find("Add them to the diary now?", 1, true), "the question: " .. words)
Eq(Sheet.View().add.label:GetText(), "Add them", "the add link's words")
Eq(Sheet.View().later.label:GetText(), "Not now", "the not-now link's words")
Eq(Sheet.View().title:GetText(), "Familiar faces", "the title")
Eq(ns.Diary.Count(), 0, "opening the sheet added someone")

--------------------------------------------------------------------------
Section("\"Add them\" adds the list and puts the sheet away")

Sheet.View().add:Click()
Check(not Sheet.Shown(), "the sheet stayed up after adding")
Eq(ns.Diary.Count(), 4, "not all four were added")
for _, p in ipairs(PEOPLE) do
    Check(ns.Diary.IsDiary(p.guid), p.first .. " was not added")
end
Check(not ns.Diary.IsDiary(TWICE), "someone seen twice was added")
Eq(ns.Setting("autoAdd"), true, "the setting went off")

--------------------------------------------------------------------------
Section("one waiting: singular, named alone")

Switch(false)
Seed()
for i = 2, 4 do ns.AutoAdd.Decline(PEOPLE[i].guid) end
Switch(true)
Check(Sheet.Shown(), "one waiting: no sheet")
words = Words()
Check(words:find("You’ve seen 1 person near you 3 times or more.", 1, true), "the singular: " .. words)
Check(words:find("Aldwin", 1, true) and not words:find("other", 1, true), "the one name: " .. words)
Sheet.Close()

--------------------------------------------------------------------------
Section("\"Not now\" and Escape add nobody; the setting stays on")

Switch(false)
Seed()
Switch(true)
Check(Sheet.Shown(), "setup: no sheet")
Sheet.View().later:Click()
Check(not Sheet.Shown(), "Not now left the sheet up")
Eq(ns.Diary.Count(), 0, "Not now added someone")
Eq(ns.Setting("autoAdd"), true, "Not now turned the setting off")

Switch(false)
Switch(true)
Check(Sheet.Shown(), "setup: no sheet the second time")
Sheet.Host():Hide()   -- (Escape: UISpecialFrames hides the window)
Eq(ns.Diary.Count(), 0, "Escape added someone")
Eq(Sheet.Add(), 0, "Add after it was put away added someone")

--------------------------------------------------------------------------
Section("switched off, or on with nobody waiting: nothing")

Switch(false)
Check(not Sheet.Shown(), "switching off showed the sheet")
ns.db.sightings = {}
Switch(true)
Check(not Sheet.Shown(), "switched on with nobody waiting: a sheet")
Eq(Sheet.Open({}), false, "an empty list opened")
Eq(Sheet.Offer(false), false, "switching off offered")

-- The flatSheets setting: the sheet lies flat as the others do.
Switch(false)
Seed()
ns.SetSetting("flatSheets", true)
Switch(true)
Check(Sheet.View().flat, "flatSheets on: the sheet was not laid flat")
Sheet.Close()
ns.SetSetting("flatSheets", false)

--------------------------------------------------------------------------
Section("the pad: the sheet has it, on \"Add them\"")

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
        out[e[1]] = e[2]
    end
    return out
end

Switch(false)
Seed()
Switch(true)
local host = Sheet.Host()
Eq(Top(), "autoadd", "the sheet's scope has not the pad")
local catcher = Pad.Catcher(host)
Check(catcher:IsGamePadButtonEnabled(), "the sheet's catcher is off")
Eq(At() and At().control, Sheet.View().add, "the pad did not land on Add them")
Eq(At().kind, "link", "Add them's kind")
local legend = Legend()
Eq(legend.PAD1, "Choose", "A's prompt")
Eq(legend.PAD2, "Not now", "B's prompt")

-- Both links reachable: left to Not now, right back.
Press(catcher, "PADDLEFT")
if At().control ~= Sheet.View().later then Press(catcher, "PADDUP") end
Eq(At().control, Sheet.View().later, "Not now not reachable")
Press(catcher, "PADDRIGHT")
if At().control ~= Sheet.View().add then Press(catcher, "PADDDOWN") end
Eq(At().control, Sheet.View().add, "back to Add them")

-- A on Add them adds them all, and gives the pad back.
Press(catcher, "PAD1")
Check(not Sheet.Shown(), "A on Add them left the sheet up")
Eq(ns.Diary.Count(), 4, "A on Add them did not add the four")
Check(Top() ~= "autoadd", "the scope kept the pad after the sheet went")

--------------------------------------------------------------------------
Section("the pad: A on Not now, and B, add nobody")

Switch(false)
Seed()
Switch(true)
Eq(Top(), "autoadd", "setup: the scope")
Press(catcher, "PADDLEFT")
if At().control ~= Sheet.View().later then Press(catcher, "PADDUP") end
Eq(At().control, Sheet.View().later, "setup: on Not now")
Press(catcher, "PAD1")
Check(not Sheet.Shown(), "A on Not now left the sheet up")
Eq(ns.Diary.Count(), 0, "A on Not now added someone")

Switch(false)
Switch(true)
Eq(Top(), "autoadd", "opened again: not its scope")
Eq(At().control, Sheet.View().add, "opened again: not on Add them")
Press(catcher, "PAD2")
Check(not Sheet.Shown(), "B left the sheet up")
Eq(ns.Diary.Count(), 0, "B added someone")
Eq(ns.Setting("autoAdd"), true, "B turned the setting off")

--------------------------------------------------------------------------
Section("the pad: in combat it is the game's; opened another way, it takes nothing")

Switch(false)
Switch(true)
mock.fire("PLAYER_REGEN_DISABLED")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher stayed on in a fight")
mock.fire("PLAYER_REGEN_ENABLED")
Check(catcher:IsGamePadButtonEnabled(), "the catcher not back after the fight")
Sheet.Close()

-- Shown without the player's path (no Pad.Opened): no pad.
host:Show()
Sheet.View():Show()
Pad.Refresh()
Check(Top() ~= "autoadd", "a sheet the player did not open took the pad")
host:Hide()

-- The mouse taking over: the catcher goes off.
Switch(false)
Switch(true)
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher stayed on under the mouse")
Sheet.Close()
