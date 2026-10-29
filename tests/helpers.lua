-- The small shared helpers the modules lean on: unit token lists, map
-- names, the clock's day arithmetic, retention, counting, per-GUID lists,
-- chat payloads, timers and the journal's wording. Each is checked on its
-- own here; the module files check them again through their callers.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

--------------------------------------------------------------------------
Section("unit tokens")

local Units = ns.Units
Eq(#Units.Plates, 40, "nameplate tokens")
Eq(Units.Plates[1] .. "," .. Units.Plates[40], "nameplate1,nameplate40", "nameplate token names")

local party = Units.Group()
Eq(#party, 4, "party tokens")
Eq(party[1] .. "," .. party[4], "party1,party4", "party token names")
mock.inRaid = true
local raid = Units.Group()
Eq(#raid, 40, "raid tokens")
Eq(raid[1] .. "," .. raid[40], "raid1,raid40", "raid token names")
mock.inRaid = false
Eq(Units.Group(), party, "the party list is not the shared one")

local walked = {}
Eq(Units.Each({ "a", "b", "c" }, function(unit) walked[#walked + 1] = unit end), nil,
    "a walk that finds nothing returns something")
Eq(table.concat(walked, ","), "a,b,c", "walk order")
walked = {}
Eq(Units.Each({ "a", "b", "c" }, function(unit)
    walked[#walked + 1] = unit
    if unit == "b" then return "found " .. unit end
end), "found b", "the first non-nil return")
Eq(table.concat(walked, ","), "a,b", "the walk did not stop at the find")
Eq(Units.Each({ "a", "b" }, function(unit) if unit == "a" then return false end end), false,
    "false is a find, not a miss")

-- Through a caller: the sweep reads every plate token.
mock.SetUnit("nameplate40", F.STRANGER)
local players = ns.SightingCapture.Sweep(true)
Eq(#players, 1, "the sweep missed the last plate")
Eq(players[1] and players[1].unit, "nameplate40", "the sweep's unit token")
mock.SetUnit("nameplate40", nil)

--------------------------------------------------------------------------
Section("map names")

Eq(ns.MapName(1412), "Mulgore", "a known map")
Eq(ns.MapName(9999), nil, "a map the client cannot describe")
Eq(ns.MapName(nil), nil, "no map id")
Eq(ns.RowZone({ mapID = 1413, zone = "ignored" }), "The Barrens", "the map's name wins")
Eq(ns.RowZone({ zone = "Restricted Place" }), "Restricted Place", "the zone name without a map id")
Eq(ns.RowZone({ mapID = 9999, zone = "Somewhere" }), "Somewhere", "the zone name for a nameless map")
Eq(ns.RowZone({ mapID = 9999 }), nil, "nothing to call it")
Eq(ns.MapParent(1412), nil, "a map without a parent")

-- The parent walk behind SIG-5's city check: a city district is the city.
local GetMapInfo = C_Map.GetMapInfo
C_Map.GetMapInfo = function(mapID)
    if mapID == 2001 then return { mapID = 2001, name = "Valley of Strength", parentMapID = 1454 } end
    return GetMapInfo(mapID)
end
Eq(ns.MapParent(2001), 1454, "the parent map id")
Eq(ns.MapName(2001), "Valley of Strength", "a district's name")
mock.mapID = 2001
Eq(ns.City(), 1454, "a district of a listed city is not the city")
mock.mapID = 1412
Eq(ns.City(), nil, "Mulgore read as a city")
C_Map.GetMapInfo = GetMapInfo

--------------------------------------------------------------------------
Section("days")

Eq(ns.DAY, 86400, "a day in seconds")
local noon = os.time({ year = 2026, month = 10, day = 7, hour = 12, min = 34, sec = 56 })
local midnight = os.time({ year = 2026, month = 10, day = 7, hour = 0, min = 0, sec = 0 })
Eq(ns.DayStart(noon), midnight, "local midnight")
Eq(ns.DayStart(midnight), midnight, "midnight is its own day")
Eq(ns.DayStart(midnight - 1), ns.DayStart(midnight - ns.DAY / 2), "a second before midnight is the day before")

--------------------------------------------------------------------------
Section("retention")

local settings = ns.db.settings
Eq(ns.BufferDays(), 30, "the default window")
Eq(ns.Cutoff(noon), noon - 30 * ns.DAY, "the default cutoff")
Eq(ns.Cutoff(noon, 2), noon - 2 * ns.DAY, "a cutoff for an explicit window")
Eq(ns.Cutoff(), mock.now - 30 * ns.DAY, "the cutoff defaults to now")
settings.bufferDays = 5
Eq(ns.BufferDays(), 5, "a set window")
for _, bad in ipairs({ 0, -3, "7" }) do
    settings.bufferDays = bad
    Eq(ns.BufferDays(), 30, "an unusable window (" .. tostring(bad) .. ") not defaulted")
end
Eq(ns.Sessions.Gap(), 20 * 60, "the session gap")

-- Character schema 2: the session gap's old setting goes.
local old = { schema = 1, settings = { sessionGapMinutes = 45, storeChat = false } }
ns._test.Migrate(old, 2, ns._test.CharacterSteps)
Eq(old.settings.sessionGapMinutes, nil, "the old session gap kept")
Eq(old.settings.storeChat, false, "another setting lost with the session gap")
Eq(old.schema, 2, "character schema not bumped")

-- The inconsistency this fixed: Prune fell back to 30 days, Rollup did not.
settings.bufferDays = nil
ns.Characters.Observe(F.STRANGER.guid, { first = "Bram", surname = "Redfen" })
ns.db.sightings[F.STRANGER.guid] = { { time = mock.now - 40 * ns.DAY }, { time = mock.now - ns.DAY } }
Eq(ns.Sightings.Rollup(), 1, "the roll-up without a usable window")
Eq(#ns.db.sightings[F.STRANGER.guid], 1, "the recent row was rolled up too")
ns.Sightings.Forget(nil)
settings.bufferDays = 30

--------------------------------------------------------------------------
Section("counting")

Eq(ns.CountKeys({}), 0, "an empty table")
Eq(ns.CountKeys({ a = 1, b = false, [3] = "x" }), 3, "keys of every kind, false values included")

ns.db.interactions = {}
local rows, characters = ns.Interactions.Totals()
Eq(rows .. "/" .. characters, "0/0", "an empty buffer")
ns.Interactions.Add(F.STRANGER.guid, "trade", {})
ns.Interactions.Add(F.STRANGER.guid, "trade", {})
ns.Interactions.Add(F.GARRICK.guid, "whisper_in", { excerpt = "hi" })
rows, characters = ns.Interactions.Totals()
Eq(rows .. "/" .. characters, "3/2", "rows and characters")
Eq(ns.Characters.Count(), ns.CountKeys(ns.db.characters), "Characters.Count")

--------------------------------------------------------------------------
Section("per-GUID lists")

local store = {}
local list = ns.ListFor(store, "Player-1-1")
Eq(type(list), "table", "no list created")
Eq(store["Player-1-1"], list, "the list was not stored")
list[1] = "row"
Eq(ns.ListFor(store, "Player-1-1"), list, "a second call made a new list")
Eq(ns.CountKeys(store), 1, "keys in the store")

--------------------------------------------------------------------------
Section("a unit's level, read once")

mock.mapID, mock.zone, mock.inInstance = 1412, "Mulgore", false
mock.fire("PLAYER_ENTERING_WORLD", false, false)
Eq((ns.SightingCapture.State()), "active", "capture not listening")

-- -1 is "too high to tell", not a level, on the record and on the row.
local SKULL = F.Player{ guid = "Player-4620-00DDDD01", "Grim", "Skull", level = -1 }
mock.SetUnit("target", SKULL)
mock.fire("PLAYER_TARGET_CHANGED")
ns._test.DrainSightings()
Eq(ns.db.characters[SKULL.guid].level, nil, "-1 stored on the character")
Eq(ns.db.sightings[SKULL.guid][1].level, nil, "-1 stored on the row")

-- The row takes the level the record ends up with: an unreadable level
-- leaves the last one read, so a new row carries that rather than nothing.
local VET = F.Player{ guid = "Player-4620-00DDDD02", "Old", "Hand", level = 30 }
mock.SetUnit("target", VET)
mock.fire("PLAYER_TARGET_CHANGED")
ns._test.DrainSightings()
Eq(ns.db.sightings[VET.guid][1].level, 30, "the level on the first row")
mock.now, mock.mapID, VET.level = mock.now + 61, 1413, -1
mock.fire("PLAYER_TARGET_CHANGED")
ns._test.DrainSightings()
Eq(#ns.db.sightings[VET.guid], 2, "a new zone did not start a row")
Eq(ns.db.sightings[VET.guid][2].level, 30, "the new row lost the level on record")
Eq(ns.db.characters[VET.guid].level, 30, "-1 overwrote the level on record")
mock.mapID = 1412
mock.SetUnit("target", nil)

--------------------------------------------------------------------------
Section("chat payloads")

local heard = {}
local handler = ns.OnChat("CHAT_MSG_HELPER_TEST", function(text, sender, guid, lineID, event)
    heard[#heard + 1] = { text = text, sender = sender, guid = guid, lineID = lineID, event = event }
end)
Check(mock.registered.CHAT_MSG_HELPER_TEST, "OnChat did not register the event")

T.Whisper("CHAT_MSG_HELPER_TEST", "hello", "Bram Redfen", 41, F.STRANGER.guid)
local got = heard[1]
Eq(got.text, "hello", "text (1)")
Eq(got.sender, "Bram Redfen", "sender (2)")
Eq(got.lineID, 41, "lineID (11)")
Eq(got.guid, F.STRANGER.guid, "guid (12)")
Eq(got.event, "CHAT_MSG_HELPER_TEST", "the event")

-- INT-4: a secret GUID, or one that is not a player's, arrives as nil.
T.Whisper("CHAT_MSG_HELPER_TEST", "x", "y", 42, mock.secret(F.STRANGER.guid))
Eq(heard[2].guid, nil, "a secret GUID got through")
Eq(heard[2].lineID, 42, "lineID under lockdown")
T.Whisper("CHAT_MSG_HELPER_TEST", "x", "y", 43, "Creature-0-4170-1-35-3035-00001")
Eq(heard[3].guid, nil, "an NPC's GUID got through")

ns.Off("CHAT_MSG_HELPER_TEST", handler)
Check(not mock.registered.CHAT_MSG_HELPER_TEST, "OnChat's handler could not be taken off")

--------------------------------------------------------------------------
Section("timers")

local function TickersEvery(seconds)
    local found = {}
    for _, ticker in ipairs(mock.tickers) do
        if ticker.interval == seconds then found[#found + 1] = ticker end
    end
    return found
end

-- The together tick, the group scan and the sighting sweep share one.
Eq(#TickersEvery(30), 1, "30-second tickers after login, with capture active")

local ran = {}
local a = ns.Every(77, function() ran[#ran + 1] = "a" end)
local b = ns.Every(77, function() ran[#ran + 1] = "b" end)
local shared = TickersEvery(77)
Eq(#shared, 1, "two jobs on one interval made two tickers")
shared[1].fn()
Eq(table.concat(ran, ","), "a,b", "a beat did not run both jobs in order")

a:Cancel()
shared[1].fn()
Eq(table.concat(ran, ","), "a,b,b", "a cancelled job still ran")
local c = ns.Every(77, function() ran[#ran + 1] = "c" end)
a:Cancel()  -- a stale handle must not cancel the job that took its slot
shared[1].fn()
Eq(table.concat(ran, ","), "a,b,b,c,b", "the freed slot was not reused, or a stale cancel hit it")
b:Cancel()
c:Cancel()

local NewTicker = C_Timer.NewTicker
C_Timer.NewTicker = nil
Eq(ns.Every(5, function() end), nil, "a handle without tickers")
C_Timer.NewTicker = NewTicker

-- Once: on the client's timer, else straight away.
local fired = 0
local pending = #mock.timers
ns.After(3, function() fired = fired + 1 end)
Eq(#mock.timers, pending + 1, "After did not use the timer")
Eq(mock.timers[#mock.timers].delay, 3, "After's delay")
Eq(fired, 0, "After ran before its time")
mock.RunTimers()
Eq(fired, 1, "After never ran")

local After = C_Timer.After
C_Timer.After = nil
ns.After(3, function() fired = fired + 1 end)
Eq(fired, 2, "without a timer, After did not run at once")
C_Timer.After = After

--------------------------------------------------------------------------
Section("wording")

local UI = ns.UI
Eq(UI.Format.Count(0, "day", "days"), "0 days", "none")
Eq(UI.Format.Count(1, "person", "people"), "1 person", "one")
Eq(UI.Format.Count(3, "time", "times"), "3 times", "many")

local function L(n) local t = {} for i = 1, n do t[i] = string.char(64 + i) end return t end
Eq(UI.Format.List({}), nil, "an empty list")
Eq(UI.Format.List(L(1)), "A", "one name")
Eq(UI.Format.List(L(2)), "A and B", "two names")
Eq(UI.Format.List(L(4)), "A, B, C and D", "every name, without a limit")
Eq(UI.Format.List(L(3), { oxford = true }), "A, B, and C", "clauses")
Eq(UI.Format.List(L(2), { oxford = true }), "A and B", "two clauses take no comma")

-- The journal's three shapes: places, rares, the others in a visit.
local PLACES = { max = 3, shown = 2 }
Eq(UI.Format.List(L(3), PLACES), "A, B and C", "three places, all named")
Eq(UI.Format.List(L(4), PLACES), "A, B and 2 more", "four places")
Eq(UI.Format.List(L(1), { max = 1 }), "A", "one rare under a limit of one")
Eq(UI.Format.List(L(3), { max = 1 }), "A and 2 more", "rares past a limit of one")
Eq(UI.Format.List(L(5), { max = 3, shown = 2, more = "others" }), "A, B and 3 others", "people past the limit")

-- Days, at a fixed noon so the calendar does not move under the checks.
local day = os.time({ year = 2026, month = 10, day = 7, hour = 12, min = 0, sec = 0 })
local lastYear = os.time({ year = 2025, month = 10, day = 6, hour = 12, min = 0, sec = 0 })
local monday = os.time({ year = 2026, month = 10, day = 5, hour = 9, min = 0, sec = 0 })
Eq(UI.Format.DayMonth(day), "7 October", "a day and month, unpadded")
Eq(UI.Format.DayMonth(lastYear), "6 October", "no year without `now`")
Eq(UI.Format.DayMonth(day, day), "7 October", "this year's date took a year")
Eq(UI.Format.DayMonth(lastYear, day), "6 October 2025", "last year's date without its year")
Eq(UI.Format.DayLabel(day - 3600, day), "Today", "today")
Eq(UI.Format.DayLabel(ns.DayStart(day) - 60, day), "Yesterday", "a minute before midnight")
Eq(UI.Format.DayLabel(monday, day), date("%A", monday) .. ", 5 October", "an earlier day")
Eq(UI.Format.DayLabel(lastYear, day), date("%A", lastYear) .. ", 6 October 2025", "a day last year")
Eq(UI.Format.At(ns.DayStart(day) - 60, day), "yesterday at " .. date("%H:%M", ns.DayStart(day) - 60),
    "At and DayLabel disagree about yesterday")
-- Moved out of Style (UI/Words/Format.lua), still inked in Style's colours.
Eq(UI.Format.WhoLine({ level = 6, race = "Tauren", class = "DRUID", faction = "Horde" }, "Kin"),
    "Level 6 Tauren Druid  ·  |cff8c1a12Horde|r  |cff705936<Kin>|r", "UI.Format.WhoLine")
-- The toast drops the faction when it is the player's own (SELF is Horde).
Eq(UnitFactionGroup("player"), "Horde", "the player is not Horde")
Eq(UI.Format.WhoLine({ level = 6, race = "Tauren", class = "DRUID", faction = "Horde" }, nil, true),
    "Level 6 Tauren Druid", "own faction kept on the toast")
Eq(UI.Format.WhoLine({ level = 5, race = "Human", class = "ROGUE", faction = "Alliance" }, nil, true),
    "Level 5 Human Rogue  ·  |cff" .. ns.Style.HEX.alliance .. "Alliance|r", "other faction dropped from the toast")

-- The colour codes are written out from the RGB palette (UI/Style/Tokens.lua).
-- These are the strings they were typed as by hand: the inks must not move.
local HEX = ns.Style.HEX
Eq(HEX.strong, "211408", "HEX.strong from INK_STRONG")
Eq(HEX.faded, "705936", "HEX.faded from INK_FADED")
Eq(HEX.accent, "6b240a", "HEX.accent from ACCENT")
Eq(HEX.horde, "8c1a12", "HEX.horde from HORDE")
Eq(HEX.alliance, "143c86", "HEX.alliance from ALLIANCE")
