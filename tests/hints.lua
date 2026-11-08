-- The hints' gates and record (Core/Hints.lua) and the hints themselves
-- (UI/Journal/Hints.lua): when one may come, which, and what retires it.
-- The slip's look and the watcher on a drawn book are tests/hints_ui.lua's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Hints = ns.Hints
local S = ns.HintState()
local H, M = 3600, 60

-- A sitting already well under way, the cooldown long passed: every gate
-- open, nothing seen. Hints.Beat at mock.now from here on.
local function Settled()
    wipe(S.seen)
    wipe(S.retired)
    wipe(S.again)
    S.sittingFrom, S.sittingShown = mock.now - H, 0
    S.lastBeat, S.lastShown, S.played = mock.now, nil, 10 * H
    S.opens, S.remembers, S.boundAt = 0, 0, nil
    ns.SetSetting("showHints", true)
end

local function Due(view, inGroup)
    local spec = Hints.Due({ view = view, inGroup = inGroup or false })
    return spec and spec.id or nil
end

--------------------------------------------------------------------------
Section("the record: account-wide, with its defaults")

Check(SocialDiaryDB.hints == S, "the record is not SocialDiaryDB.hints")
Eq(type(S.seen) .. type(S.retired), "tabletable", "seen and retired lists")
Eq(S.opens, 0, "the opens begin at 0")
Eq(ns.IsAccountSetting("showHints"), true, "Show hints is the account's")
Eq(ns.Setting("showHints"), true, "Show hints is on to begin with")
Eq(S.sitting, 1, "the login's beat began the first sitting")

--------------------------------------------------------------------------
Section("the registry refuses what it cannot lay")

Check(not pcall(Hints.Register, "x", { eligible = function() end }), "a hint with no page")
Check(not pcall(Hints.Register, "x", { page = "people" }), "a hint with no eligible")
Check(not pcall(Hints.Register, "x", { page = "people", eligible = function() end, done = 1 }),
    "a done that is not a function")
local ids = {}
for _, spec in ipairs(Hints.All()) do ids[#ids + 1] = spec.id end
Eq(table.concat(ids, ","), "major-update,custom-events,remember-bind,remember-use", "the hints, in order")

--------------------------------------------------------------------------
Section("the heartbeat: played time and sittings")

S.lastBeat, S.played, S.sitting = 1000, 0, 4
Hints.Beat(1060)
Eq(S.played, 60, "a beat counts the minute since the last")
Hints.Beat(1060 + 40 * M)
Eq(S.played, 180, "a long silence inside the hour counts two beats at most")
Eq(S.sitting, 4, "inside the hour: the same sitting")
mock.afk = true
Hints.Beat(1060 + 41 * M)
mock.afk = false
Eq(S.played, 180, "AFK is not played")
Hints.Beat(1060 + 41 * M + H + 1)
Eq(S.sitting, 5, "more than an hour away begins a sitting")
Eq(S.sittingFrom, 1060 + 41 * M + H + 1, "...from that beat")
Eq(S.sittingShown, 0, "...with nothing shown in it yet")
Eq(S.played, 180, "the time away is not played")

--------------------------------------------------------------------------
Section("the gates: settle, cooldown, cap, the switch")

Settled()
Check(Hints.Open(), "every gate open")
S.sittingFrom = mock.now - 14 * M
Check(not Hints.Open(), "HNT-3: a quarter hour into the sitting first")
S.sittingFrom = mock.now - 15 * M
Check(Hints.Open(), "...and from then on")

Settled()
Hints.Shown("custom-events")
Check(not Hints.Open(), "HNT-1: not right after one")
S.played = S.played + 59 * M
Check(not Hints.Open(), "...nor 59 minutes of play later")
S.played = S.played + M
Check(Hints.Open(), "...an hour of play later, yes")
Eq(S.sittingShown, 1, "a shown hint counts in the sitting")

Settled()
S.sittingShown = Hints.CAP
Check(not Hints.Open(), "HNT-2: the sitting's cap")

Settled()
ns.SetSetting("showHints", false)
Check(not Hints.Open(), "HNT-10: Show hints off")
ns.SetSetting("showHints", true)

--------------------------------------------------------------------------
Section("a) Something missing?: Your Diary, from the tenth opening")

Settled()
S.opens = 9
Eq(Due("journey"), nil, "nine openings: not yet")
ns.UI.ShowJournal()
Eq(S.opens, 10, "opening the book counts")
ns.UI.ShowJournal()
Eq(S.opens, 10, "...but not again while it is open")
ns.UI.CloseJournal()
Eq(Due("journey"), "custom-events", "ten openings, on Your Diary")
Eq(Due("people"), nil, "...only there")

Hints.Shown("custom-events")
S.played = S.played + 2 * H
Eq(Due("journey"), nil, "HNT-7: shown is gone for good")

Settled()
S.opens = 10
ns.db.journey["Player-0000-HINT0001"] = { custom = { { kind = "x", t = mock.now } } }
Eq(Due("journey"), nil, "HNT-8: a card of their own already, on any route: done")
Eq(Hints.Retired("custom-events"), true, "...and retired as it was found")
ns.db.journey["Player-0000-HINT0001"] = nil

Settled()
S.opens = 10
local spec = Hints.Get("custom-events")
local words = spec.words()
Eq(words.title, "Something missing?", "a's title")
Eq(words.body, "Right-Click the map to add events yourself.", "a's words")

--------------------------------------------------------------------------
Section("b1) Quickly Add Notes: People, in a group, no key")

Settled()
Eq(Due("people", false), nil, "not out of a group")
Eq(Due("people", true), "remember-bind", "on People in a group, no key bound")
Eq(Due("journey", true), nil, "...only on People")
words = Hints.Get("remember-bind").words()
Eq(words.title .. "|" .. words.body .. "|" .. words.link, "Quickly Add Notes|Assign a hotkey to add a note quickly.|Go to Settings",
    "b1's words")
Eq(type(words.onLink), "function", "b1's link does something")

SetBinding("F7", "SOCIALDIARY_REMEMBER")
Eq(Due("people", true), nil, "a key bound: b1 is done")
Eq(Hints.Retired("remember-bind"), true, "...and retired")

--------------------------------------------------------------------------
Section("b2) the key bound three sittings and never pressed")

Settled()
S.sitting = 7
Eq(Hints.BoundFor(true), 0, "the sitting it was first seen bound in")
Eq(Due("people", true), nil, "bound just now: not yet")
S.sitting = 9
Eq(Due("people", true), nil, "two sittings on: not yet")
S.sitting = 10
Eq(Due("people", true), "remember-use", "three sittings on, never pressed")
Eq(Hints.Get("remember-use").words().body, "Remember to use your hotkey for adding Notes! (F7)", "b2 names the key")
Eq(Hints.BoundFor(false), nil, "unbound: forgotten...")
Eq(Hints.BoundFor(true), 0, "...and counted afresh when bound again")

S.sitting, S.boundAt = 10, 7
SocialDiary_Remember()
Eq(S.remembers, 1, "the key pressed is counted")
Eq(Hints.Retired("remember-use"), true, "...and b2 retired")
Eq(Due("people", true), nil, "nothing more on People")
SetBinding("F7")

--------------------------------------------------------------------------
Section("/sd hint: forced past every gate but its context")

Settled()
Hints.Shown("custom-events")
ns.SetSetting("showHints", false)
Hints.Force("custom-events")
Eq(Due("people"), nil, "forced, but its page still has to be open")
Eq(Due("journey"), "custom-events", "forced: seen, its openings, cooldown and the switch passed over")
Hints.Shown("custom-events")
Eq(Hints.Forced("custom-events"), false, "shown: no longer forced")
ns.SetSetting("showHints", true)

--------------------------------------------------------------------------
Section("Show hints again")

Settled()
Hints.Shown("custom-events")
Hints.Retire("remember-bind")
Hints.Reset()
Eq(Hints.Seen("custom-events"), false, "seen hints can come again")
Eq(Hints.Retired("remember-bind"), true, "a retired one stays retired: its feature is in use")
Eq(Hints.Again("custom-events") and not Hints.Again("remember-bind"), true, "asked again: those not retired")

S.sittingFrom, S.sittingShown, S.opens = mock.now, Hints.CAP, 0
S.lastShown = S.played
Check(not Hints.Open(), "every clock shut")
Eq(Due("journey"), "custom-events", "asked again: past the clocks and its openings, on its page")
ns.SetSetting("showHints", false)
Eq(Due("journey"), nil, "...but not with Show hints off")
ns.SetSetting("showHints", true)
Hints.Shown("custom-events")
Eq(Hints.Again("custom-events"), false, "shown: asked no more")
Eq(Due("journey"), nil, "...and gone for good again")

Settled()
S.sittingFrom = mock.now
Hints.Reset()
Eq(Due("people", false), "remember-bind", "b1 asked again: out of a group too, no key bound")
SetBinding("F7", "SOCIALDIARY_REMEMBER")
Eq(Due("people", false), "remember-use", "a key bound since: b1 done, b2 fits")
Eq(Hints.Again("remember-bind"), false, "...b1 dropped from the asking")
Eq(Hints.Get("remember-use").words().body, "Remember to use your hotkey for adding Notes! (F7)", "...naming the key")
SetBinding("F7")
Eq(Due("people", false), nil, "unbound again, never pressed: b2 does not fit")
S.remembers = 1
SetBinding("F7", "SOCIALDIARY_REMEMBER")
Eq(Due("people", false), nil, "pressed once: b2 is done")
SetBinding("F7")

--------------------------------------------------------------------------
Section("a major update: the version record and its notice")

Eq(ns.IsAccountSetting("showUpdateHint"), true, "the update switch is the account's")
Eq(ns.Setting("showUpdateHint"), true, "...and on to begin with")
Eq(Hints.Major("2.4.0"), 2, "a version's major number")
Eq(Hints.Major("v10.1.3"), 10, "...with a v, two digits")
Eq(Hints.Major("@project-version@"), nil, "...nothing for what is not a version")

Settled()
S.version, S.update = nil, nil
Hints.Installed("2.4.0")
Eq(S.version, "2.4.0", "the login records the version")
Eq(Hints.Update(), nil, "no version known before: nothing to tell (a new install)")
Hints.Installed("2.5.0")
Eq(Hints.Update(), nil, "a minor update tells nothing")
Hints.Installed("3.0.0")
Eq(Hints.Update(), "3.0.0", "a major update is told of")
Eq(S.version, "3.0.0", "...and recorded")

-- Every clock shut and Show hints off: a notice comes all the same, on any page.
S.sittingFrom, S.sittingShown = mock.now, Hints.CAP
S.lastShown = S.played
ns.SetSetting("showHints", false)
Eq(Due("people"), "major-update", "the notice: past the clocks and Show hints")
Eq(Due("journey"), "major-update", "...on whatever page is open")
local words = Hints.Get("major-update").words()
Check(words.body:find("3.0.0", 1, true) ~= nil, "the notice names the version")
Check(type(words.onLink) == "function" and words.link ~= nil, "...with a link to the Changelog")
ns.SetSetting("showUpdateHint", false)
Eq(Due("people"), nil, "its own switch off: no notice")
ns.SetSetting("showUpdateHint", true)

local played, shownInSitting = S.lastShown, S.sittingShown
Hints.Shown("major-update")
Eq(Hints.Update(), nil, "laid: the update is told of")
Eq(S.lastShown, played, "a notice leaves the cooldown as it was")
Eq(S.sittingShown, shownInSitting, "...and the sitting's count")
Eq(Due("people"), nil, "told once only")

Hints.Installed("4.0.0")
Eq(Hints.Update(), "4.0.0", "the next major update")
Hints.UpdateRead()
Eq(Hints.Update(), nil, "reading the Changelog is as good as the notice")

ns.SetSetting("showUpdateHint", false)
Hints.Installed("5.0.0")
Eq(Hints.Update(), nil, "with the switch off, a major update is not kept to tell later")
ns.SetSetting("showUpdateHint", true)
ns.SetSetting("showHints", true)

Settled()
Hints.Reset()
Eq(Hints.Again("major-update"), false, "Show hints again does not ask the notice again")
