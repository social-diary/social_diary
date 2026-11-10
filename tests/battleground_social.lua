-- Battleground matches among the diary's people (Core/Matches.lua has the
-- record): a match's line on a diary person's timeline (Core/Timeline.lua,
-- UI/Words/Timeline.lua, UI/Journal/Timeline.lua) and what a click on it
-- opens; the reunion toast in a match (Core/Reunions.lua, UI/Windows/
-- Reunion/Words.lua); the Battlegrounds settings section and its roll-up;
-- the roll-up warning (UI/Journal/Hints.lua's "board-rollup"); the pad on
-- the section. Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Matches = ns.Matches
local Pad = ns.UI.Pad
local SELF, BRAM, ROMULUS = F.SELF, F.STRANGER, F.HOSTILE
local t0 = 1795000000
local MIN = 60

T.BlankDiary()
mock.now = t0
mock.zone = "Orgrimmar"
mock.SetUnit("player", SELF)
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
mock.SetUnit("target", BRAM)
ns.Diary.Add(BRAM.guid, { source = "test" })
mock.SetUnit("target", ROMULUS)
ns.Diary.Add(ROMULUS.guid, { source = "test" })
mock.SetUnit("target", nil)
local BRAM_NAME = ns.Characters.FullName(BRAM.guid)
local ROMULUS_NAME = ns.Characters.FullName(ROMULUS.guid) or "Romulus Lupa"

-- A finished match: the user on the Horde (0), Bram with them, Romulus
-- against them, and `strangers` more on each side.
local n = 0
local function Match(start, minutes, winner, opts)
    opts = opts or {}
    local m = Matches.New({ map = opts.map or 489, mapName = opts.mapName, faction = 0, winner = winner,
        startedAt = start, endedAt = start + minutes * MIN, duration = minutes * MIN,
        state = opts.state or "complete", board = true, me = SELF.guid })
    local rows = { { guid = SELF.guid, name = "Ulverston Nye", side = 0, kb = 2 } }
    if not opts.noBram then rows[#rows + 1] = { guid = BRAM.guid, name = BRAM_NAME, side = 0, kb = opts.kb or 3 } end
    if not opts.noRomulus then rows[#rows + 1] = { guid = ROMULUS.guid, name = ROMULUS_NAME, side = 1, kb = 1 } end
    for i = 1, opts.strangers or 0 do
        n = n + 1
        rows[#rows + 1] = { guid = ("Player-0000-%08X"):format(0x5E000000 + n), name = "Linnet Oakhurst" .. n,
            side = i % 2 }
    end
    for _, r in ipairs(rows) do m.players[#m.players + 1] = Matches.Pack(r) end
    return m
end

local function OfKind(list, kind)
    local out = {}
    for _, item in ipairs(list) do if item.kind == kind then out[#out + 1] = item end end
    return out
end

--------------------------------------------------------------------------
Section("a match is a line on a diary person's timeline")

local wsg = Match(t0 - 5 * 3600, 22, 0, { mapName = "Warsong Gulch" })
local ab = Match(t0 - 3 * 3600, 31, 1, { map = 529, mapName = nil })

local tl = ns.Timeline.For(BRAM.guid)
local lines = OfKind(tl, "match")
Eq(#lines, 2, "Bram's two matches are not both on his timeline")
Eq(lines[1].match, ab, "the newest first")
Eq(lines[1].side, "with", "Bram's side")
local _, text, sub, icon, full = ns.UI.DescribeItem(lines[2], BRAM.guid)
Eq(text, "Warsong Gulch, on your side", "the line: map and side")
Check(sub and sub:find("you won", 1, true), "the result on its details: " .. tostring(sub))
Check(sub:find("22 min", 1, true), "how long: " .. sub)
Eq(icon, "match", "the match's icon")
Check(ns.Style.ART.match, "the match's art not registered")
_, text, sub = ns.UI.DescribeItem(lines[1], BRAM.guid)
Eq(text, "Arathi Basin, on your side", "a map with no name read: the map's own name")
Check(sub:find("you lost", 1, true), "a lost match: " .. sub)
Check(sub:find("your second match together", 1, true), "the meetings counted: " .. sub)

local foe = OfKind(ns.Timeline.For(ROMULUS.guid), "match")
Eq(#foe, 2, "Romulus's matches")
_, text = ns.UI.DescribeItem(foe[1], ROMULUS.guid)
Eq(text, "Arathi Basin, against you", "against you")

--------------------------------------------------------------------------
Section("a rolled-up match keeps its line")

ab.rolled, ab.lost = true, 12
Eq(#OfKind(ns.Timeline.For(BRAM.guid), "match"), 2, "a rolled-up match left the timeline")
ab.rolled, ab.lost = nil, nil

--------------------------------------------------------------------------
Section("a together session that was the match gives way to it; a longer one holds it")

-- The battleground raid: Bram's session from the gates to the way out.
local function Session(id, from, to)
    ns.db.sessions[id] = { id = id, me = SELF.guid, source = "group", raid = true, startedAt = from, endedAt = to,
        participants = { [BRAM.guid] = { since = from, last = to, seconds = to - from } },
        others = 0, zones = {}, deaths = {} }
end
T.BlankDiary()
ns.Diary.Add(BRAM.guid, { source = "test" })
ns.Diary.Add(ROMULUS.guid, { source = "test" })
wipe(ns.db.matches)
local raid = Match(t0 - 5 * 3600, 22, 0, { mapName = "Warsong Gulch" })
Session(901, raid.startedAt + 30, raid.endedAt + 20)
-- An evening queued together as a party: one session round two matches.
local first = Match(t0 - 3 * 3600, 20, 0, { mapName = "Warsong Gulch" })
local second = Match(t0 - 3 * 3600 + 25 * MIN, 20, 1, { mapName = "Warsong Gulch" })
Session(902, first.startedAt - 20 * MIN, second.endedAt + 30 * MIN)
tl = ns.Timeline.For(BRAM.guid)
local top = {}
for _, item in ipairs(tl) do top[#top + 1] = item.kind end
Eq(table.concat(top, ","), "added,session,match", "the raid's session did not give way, or the party's did")
Eq(tl[3].match, raid, "the match that was its session")
Eq(tl[3].replacing and tl[3].replacing.id, 901, "it took the session's place")
local held = OfKind(tl[2].all, "match")
Eq(#held, 2, "the party's session does not hold its two matches")
Eq(held[1].depth, 1, "a held match is one level in")
Eq(#OfKind(tl[2].lines, "match"), 2, "folded, the session does not show its matches")

-- Against you: never in the group, never a session's.
local foeTl = ns.Timeline.For(ROMULUS.guid)
Eq(#OfKind(foeTl, "match"), 3, "an enemy's matches are not each a line of their own")

--------------------------------------------------------------------------
Section("a click on the line opens the match's page, where it is offered")

local opened, turnedTo = {}, nil
local YD = ns.UI.YourDiary
local realOpen = YD.OpenMatch
YD.OpenMatch = function(id) opened[#opened + 1] = id end
local realView = ns.UI.SetJournalView
ns.UI.SetJournalView = function(key) turnedTo = key end

ns.UI.ShowJournal(ROMULUS.guid)
local TL = _G.SocialDiaryJournalFrame.profile.timeline
local mrow
for _, row in ipairs(TL.rows) do
    if row:IsShown() and row.item and row.item.item and row.item.item.kind == "match" and row.item.when then
        mrow = mrow or row
    end
end
Check(mrow, "no match line on the page")
Eq(mrow.item.icon, "match", "the line's icon")
mrow.scripts.OnEnter(mrow)
Check(GameTooltip.text and GameTooltip.text:find("Click to open the match.", 1, true),
    "the tooltip does not say what a click does: " .. tostring(GameTooltip.text))
mrow.scripts.OnLeave(mrow)
mrow.scripts.OnMouseUp(mrow)
Eq(opened[1], mrow.item.item.match.id, "the click did not open its match")
Eq(turnedTo, "journey", "the book did not turn to Your Diary")
ns.UI.SetJournalView = realView

-- Without the page there (or another character's match), it says and does nothing.
YD.OpenMatch = nil
Eq(ns.UI.Journal.CanOpenMatch(raid), false, "offered without the page")
mrow.scripts.OnMouseUp(mrow)
Eq(#opened, 1, "a click opened something without the page")
YD.OpenMatch = function(id) opened[#opened + 1] = id end
local other = { id = 999, me = "Player-4620-0ACC0001" }
Eq(ns.UI.Journal.CanOpenMatch(other), false, "another character's match offered")

-- The pad: A on the line does what the click does.
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(_G.SocialDiaryJournalFrame)
local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local scope = Pad.Scope("people")
Pad.Refresh()
local padItem
for _, it in ipairs(scope.focus.groups.page and scope.focus.groups.page.items or {}) do
    if it.line and it.line.match then padItem = padItem or it end
end
Check(padItem, "the pad does not walk the match's line")
Check(scope.focus:Focus(padItem.key, "page"), "the pad cannot land on the match's line")
local legend = scope.legend(scope)
Eq(legend[1] and legend[1][2], "Open the match", "the line's prompt")
local before = #opened
Press("PAD1")
Eq(#opened, before + 1, "A did not open the match")
YD.OpenMatch = nil
legend = scope.legend(scope)
Check(not (legend[1] and legend[1][2] == "Open the match"), "a prompt where nothing opens")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
YD.OpenMatch = realOpen
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("the reunion toast in a match: its words")

local function RT(snap)
    local w = ns.UI.ReunionText(snap)
    for i, story in ipairs(w.stories or {}) do
        w.stories[i] = story:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    return w
end
local snap = { reason = "match", side = "with", map = "Warsong Gulch", meetings = 3, name = "Bram Redfen",
    tags = {}, timesMet = 4, lastMet = t0 - 86400, lastZone = "The Barrens" }
local words = RT(snap)
Eq(words.heading, "On your side", "with you: the heading")
Check(words.stories[1]:find("third", 1, true) and words.stories[1]:find("Warsong Gulch", 1, true)
    and words.stories[1]:find("crossed paths", 1, true), "the longest story: " .. words.stories[1])
Check(words.stories[#words.stories] == "Your third match with them.", "the shortest: "
    .. words.stories[#words.stories])
snap.side = "against"
Eq(RT(snap).heading, "Against you", "against you: the heading")
Check(RT(snap).stories[1]:find("match against them", 1, true), "against: the story")
snap.tags = { "foe" }
words = RT(snap)
Eq(words.heading, "A foe, against you", "a foe against you is a warning")
Eq(words.warning, "foe", "its warning")
snap.tags, snap.side, snap.meetings = {}, nil, nil
Eq(RT(snap).heading, "In this battleground", "side unread")
Eq(RT({ more = 2, reason = "match" }).stories[1], "from your diary are in this battleground too.", "a flood's last")

--------------------------------------------------------------------------
Section("the reunion toast in a match: due, once, by the toast settings")

T.BlankDiary()
wipe(ns.db.matches)
wipe(ns.db.meta.greeted)
ns.Diary.Add(BRAM.guid, { source = "test" })
ns.Diary.Add(ROMULUS.guid, { source = "test" })
ns.SetSetting("toasts", true)
ns.SetSetting("nearbyToasts", true)
local live = Matches.Enter({ map = 489, mapName = "Warsong Gulch", faction = 0, level = 30 }, mock.now)
Matches.Seen(live, { guid = BRAM.guid, name = BRAM_NAME, side = 0 })
Matches.Seen(live, { name = ROMULUS_NAME, side = 1 })   -- an enemy: by name only
local m, side = ns.Reunions.InMatch(BRAM.guid)
Eq(m, live, "Bram's match")
Eq(side, "with", "Bram's side")
Eq(select(2, ns.Reunions.InMatch(ROMULUS.guid)), "against", "Romulus found by name")

-- The group and nearby toasts keep quiet in a match: the match's says it.
Eq(ns.Reunions.Due(BRAM.guid, "group"), nil, "a group toast in a match")
Eq(ns.Reunions.Due(ROMULUS.guid, "nearby"), nil, "a nearby toast in a match")

ns.Fire("SD_REUNION", BRAM.guid, "match")
local up = ns.UI.ReunionShowing()
Check(up and up.guid == BRAM.guid, "no toast for Bram in the match")
Eq(up.reason, "match", "its reason")
Eq(up.side, "with", "its side")
Eq(up.map, "Warsong Gulch", "its map")
Eq(up.meetings, 1, "this match counted")
Eq(ns.UI.ReunionText(up).heading, "On your side", "the card's heading")
ns.UI.Toast.Dismiss()
ns.Fire("SD_REUNION", BRAM.guid, "match")
Eq(ns.UI.ReunionShowing(), nil, "the cooldown not honoured")

-- Against you follows the nearby switch; with you the group one.
ns.SetSetting("nearbyToasts", false)
Eq(ns.Reunions.Due(ROMULUS.guid, "match"), nil, "against you with nearby toasts off")
ns.SetSetting("nearbyToasts", true)
ns.SetSetting("toasts", false)
Check(ns.Reunions.Due(ROMULUS.guid, "match"), "against you, nearby on and group off")
wipe(ns.db.meta.greeted)
Eq(ns.Reunions.Due(BRAM.guid, "match"), nil, "with you with group toasts off")
ns.SetSetting("toasts", true)
ns.Diary.SetQuietNearby(ROMULUS.guid, true)
Eq(ns.Reunions.Due(ROMULUS.guid, "match"), nil, "the quiet list against you")
ns.Diary.SetQuietNearby(ROMULUS.guid, false)
Matches.Close(live, "left", mock.now)
Check(ns.Reunions.Due(BRAM.guid, "group"), "the group toast after the match")

--------------------------------------------------------------------------
Section("the Battlegrounds section: keep full boards for the last N")

T.BlankDiary()
wipe(ns.db.matches)
ns.Diary.Add(BRAM.guid, { source = "test" })
ns.db.meta.matchWarned = nil
for i = 1, 12 do Match(t0 - (20 - i) * 3600, 20, 0, { strangers = 4, noRomulus = true }) end

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local book = ns.UI.JournalFrame()
local page = ns.UI.SettingsPage()
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(page)
page:ShowSection("battlegrounds")
page:Refresh()
Check(page.battlegroundBoards, "no number for the boards")
Check(page.boardWarnings, "no switch for the warnings")
Eq(ns.Setting("battlegroundBoards"), 100, "the default")
Eq(ns.IsAccountSetting("boardWarnings"), true, "the warnings are the account's")
Eq(ns.IsAccountSetting("battlegroundBoards"), false, "the boards are the character's")
Eq(page.battlegroundState:GetText(), "12 of 100 kept whole so far. In 88 matches, the oldest begin to lose their strangers.",
    "the state line")

local box = page.battlegroundBoards.box
box:SetText("10")
box.scripts.OnEnterPressed(box)
Eq(ns.Setting("battlegroundBoards"), 10, "the number not saved")
local rolled, kept = 0, 0
for _, mm in ipairs(Matches.All()) do
    if mm.rolled then
        rolled = rolled + 1
        Eq(mm.lost, 4, "a rolled match's strangers not counted")
        Eq(#mm.players, 2, "a rolled match lost the user or Bram")
    else
        kept = kept + 1
        Eq(#mm.players, 6, "a kept match lost a row")
    end
end
Eq(rolled, 2, "the two oldest did not roll up")
Eq(kept, 10, "ten full boards not kept")
Eq(page.battlegroundState:GetText(), "The newest 10 are kept whole. Older ones keep only the people from your diary.",
    "the state line after")
box:SetText("5")
box.scripts.OnEnterPressed(box)
Eq(ns.Setting("battlegroundBoards"), 10, "below the least it takes")

--------------------------------------------------------------------------
Section("the pad reaches both")

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
catcher = Pad.Catcher(book)
local function At() return Pad.Top().focus:Current() end
page:ShowSection("battlegrounds")
Pad.Refresh()
Eq(Pad.Top().key, "settings", "the top scope")
Pad.Top().focus:Focus("nav:battlegrounds", "nav")
Eq(At().key, "nav:battlegrounds", "the section's row not reachable")
Press("PADDRIGHT")
Eq(At().frame, page.battlegroundBoards, "right: not on the boards")
Eq(At().kind, "number", "its kind")
Press("PADDRIGHT")
Eq(ns.Setting("battlegroundBoards"), 11, "right did not count up")
Press("PADDLEFT")
Eq(ns.Setting("battlegroundBoards"), 10, "left did not count down")
for _ = 1, 5 do
    if At().frame == page.boardWarnings then break end
    Press("PADDDOWN")
end
Eq(At().frame, page.boardWarnings, "the warnings' switch never landed on")
Press("PAD1")
Eq(ns.Setting("boardWarnings"), false, "A did not switch the warnings off")
Press("PAD1")
Eq(ns.Setting("boardWarnings"), true, "A did not switch them on again")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("the roll-up warning: due at each step, once")

local Hints = ns.Hints
local S = ns.HintState()
local function Due(view)
    local spec = Hints.Due({ view = view, inGroup = false })
    return spec and spec.id or nil
end
S.update = nil
wipe(ns.db.matches)
ns.db.meta.matchWarned = nil
ns.SetSetting("battlegroundBoards", 30)
local start = t0 - 400 * 3600
local made = 0
local function Play(k)
    for _ = 1, k do
        made = made + 1
        Match(start + made * 3600, 20, 0, { noRomulus = true })
    end
end
local seen = {}
for _ = 1, 30 do
    local id = Due("people")
    if id == "board-rollup" then
        Eq(Due("journey"), "board-rollup", "the warning not on any page")
        local step = Matches.WarningDue()
        local hint = Hints.Get("board-rollup").words()
        Check(hint.body:find(("In %d match"):format(Matches.UntilRollup()), 1, true), "its words: " .. hint.body)
        Hints.Shown("board-rollup")
        seen[#seen + 1] = step
        Eq(Due("people"), nil, "the same step warned twice")
    end
    Play(1)
end
Eq(table.concat(seen, ","), "25,10,5,4,3,2,1", "the steps warned")
Eq(Matches.UntilRollup(), 0, "setup: roll-up under way")
Eq(Due("people"), nil, "a warning once roll-up began")

-- Its link opens the section.
local shownKey
local realShow = ns.UI.ShowSettings
ns.UI.ShowSettings = function(key) shownKey = key end
Hints.Get("board-rollup").words().onLink()
Eq(shownKey, "battlegrounds", "the link does not open the Battlegrounds section")
ns.UI.ShowSettings = realShow

-- Room again (more kept) clears the steps; the switch silences them.
ns.SetSetting("battlegroundBoards", 60)
Eq(Due("people"), nil, "a warning with room again")
ns.SetSetting("battlegroundBoards", 40)
Eq(Due("people"), "board-rollup", "the warning did not come again after room was made")
ns.SetSetting("boardWarnings", false)
Eq(Due("people"), nil, "the warning with its switch off")
ns.SetSetting("boardWarnings", true)
