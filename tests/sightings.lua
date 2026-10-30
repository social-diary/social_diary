-- Sightings: capture from nameplates, units and chat, the queue and its
-- throttle, cities and instances, the roll-up, seen around, and the
-- stranger tooltip.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local SELF, HOSTILE, FRIEND, STRANGER2 = F.SELF, F.HOSTILE, F.FRIEND, F.STRANGER2
local Drain = ns._test.DrainSightings

--------------------------------------------------------------------------
Section("sightings (SIG-1 to SIG-8)")

local Capture = ns.SightingCapture

mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
mock.position = { x = 0.4213, y = 0.6157 }
mock.fire("PLAYER_ENTERING_WORLD", false, false)

Eq((Capture.State()), "active", "not listening in the open world")
Check(mock.registered.CHAT_MSG_TEXT_EMOTE, "emotes are not a source")

local RHEA = "Player-4620-00AAAA01"

-- SIG-1, SIG-8: the event only queues; the work happens on the next frame.
mock.SetUnit("nameplate5", HOSTILE)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
Eq(Capture.QueueLength(), 1, "nameplate not queued")
Eq(ns.db.sightings[HOSTILE.guid], nil, "stored inside the event handler")
Drain()
Eq(Capture.QueueLength(), 0, "queue not drained")

local rows = ns.db.sightings[HOSTILE.guid]
Check(rows and #rows == 1, "no sighting row for a stranger's nameplate")
local row = rows[1]
Eq(row.level, 5, "level")
Eq(row.hostile, true, "SIG-2: hostility at the moment")
Eq(row.mapID, 1412, "the user's map")
Eq(row.x, 0.421, "the user's position, rounded")
Eq(row.src, "plate", "source")
Eq(row.time, mock.now, "time")
Eq(ns.Characters.FullName(HOSTILE.guid), "Romulus Lupa", "a stranger's character record")
Eq(ns.db.characters[HOSTILE.guid].faction, "Alliance", "faction on the character")

-- SIG-8: the same player 25 times in five seconds is one queue entry, not 25.
for _ = 1, 25 do mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5") end
Eq(Capture.QueueLength(), 0, "a burst got past the throttle")
Eq(Capture.Stats().throttled, 25, "throttled bursts not counted")

-- SIG-4: later in the same zone and hour updates the row.
mock.now = mock.now + 120
HOSTILE.level = 6
mock.SetUnit("target", HOSTILE)
mock.fire("PLAYER_TARGET_CHANGED")
Drain()
Eq(#rows, 1, "a second row inside the same zone-hour")
Eq(row.last, mock.now, "last-seen not updated")
Eq(row.level, 6, "level not updated")
Eq(row.x, 0.421, "the position moved; it is the first sighting's")

-- Another zone is another row; so is the same zone an hour later.
mock.now, mock.mapID = mock.now + 61, 1413
mock.fire("PLAYER_TARGET_CHANGED")
Drain()
Eq(#ns.db.sightings[HOSTILE.guid], 2, "a new zone did not start a row")
mock.now, HOSTILE.level = mock.now + 3601, 7
mock.fire("PLAYER_TARGET_CHANGED")
Drain()
Eq(#ns.db.sightings[HOSTILE.guid], 3, "a new hour did not start a row")
mock.mapID = 1412

-- Not proof of proximity: a unit the client is not drawing.
local FAR = F.Player{ guid = "Player-4620-00AAAA03", "Far", "Away", visible = false }
mock.SetUnit("mouseover", FAR)
mock.fire("UPDATE_MOUSEOVER_UNIT")
Eq(Capture.QueueLength(), 0, "an undrawn mouseover was queued")

-- The user's own character, and NPC plates, are not sightings.
mock.SetUnit("nameplate6", SELF)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
mock.SetUnit("nameplate7", { guid = "Creature-0-4170-1-35-3035-00001", name = { "Plainstrider" }, isPlayer = false })
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
Eq(Capture.QueueLength(), 0, "own character or an NPC queued")

-- /say, /yell and emotes: a joined name, a plain GUID, no unit.
mock.fire("CHAT_MSG_TEXT_EMOTE", "Rhea Silvia waves at you.", "Rhea Silvia",
    "", "", "", "", 0, 0, "", 0, 81, RHEA)
Drain()
Eq(ns.Characters.FullName(RHEA), "Rhea Silvia", "an emote's sender not observed")
Eq(ns.db.sightings[RHEA][1].src, "emote", "an emote is not a sighting")
Eq(ns.db.sightings[RHEA][1].level, nil, "chat invented a level")

mock.fire("CHAT_MSG_SAY", "hi", mock.secret("Remus"), "", "", "", "", 0, 0, "", 0, 82,
    mock.secret("Player-4620-00AAAA04"))
Eq(Capture.QueueLength(), 0, "a chat-lockdown line was queued")

-- SIG-8's frame budget: at most 10 per frame, fewer when each is expensive.
local function Crowd(n, from)
    for i = 1, n do
        mock.SetUnit("nameplate" .. (i % 40 + 1), {
            guid = ("Player-4620-01%06d"):format(from + i), name = { "Crowd" .. i, "Member" },
            level = 10,
        })
        mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. (i % 40 + 1))
    end
end
Crowd(30, 0)
Eq(Capture.QueueLength(), 30, "a crowd not queued")
Drain()
Eq(Capture.QueueLength(), 20, "more than 10 in one frame")
mock.clockStep = 0.3
Drain()
Eq(Capture.QueueLength(), 18, "the time budget did not cut the frame short")
mock.clockStep = 0
while Capture.QueueLength() > 0 do Drain() end
Check(Capture.Stats().maxMs > 0, "frame cost not measured")

Crowd(250, 1000)
Eq(Capture.QueueLength(), 200, "the queue is not capped")
Eq(Capture.Stats().dropped, 50, "drops not counted")
while Capture.QueueLength() > 0 do Drain() end
for i = 1, 40 do mock.SetUnit("nameplate" .. i, nil) end

-- The sweep catches people who stayed in range (no new ADDED event).
mock.now = mock.now + 61
mock.SetUnit("nameplate5", HOSTILE)
local players, queued = Capture.Sweep()
Eq(#players, 1, "the sweep missed a nameplate")
Eq(queued, 1, "the sweep did not queue")
Drain()

-- SIG-5: a capital unregisters the handlers and drops the queue.
mock.now = mock.now + 61
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
Eq(Capture.QueueLength(), 1, "setup: nothing queued before the city")
mock.mapID, mock.zone = 1454, "Orgrimmar"
mock.fire("ZONE_CHANGED_NEW_AREA")
local state, why = Capture.State()
Eq(state, "city", "Orgrimmar is not a city")
Eq(why, 1454, "the matched city")
Eq(Capture.QueueLength(), 0, "the queue survived entering a city")
Check(not mock.registered.CHAT_MSG_TEXT_EMOTE, "SIG-5: a source still registered in a city")
Check(not mock.registered.CHAT_MSG_EMOTE, "SIG-5: a source still registered in a city")
mock.now = mock.now + 61
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
mock.fire("PLAYER_TARGET_CHANGED")
Eq(Capture.QueueLength(), 0, "queued in a city")

-- A removed city stays removed, through the defaults.
ns.db.settings.cities[1454] = false
ns.InitDB()
Eq(ns.db.settings.cities[1454], false, "the defaults brought a removed city back")
Eq((Capture.Evaluate()), "active", "a removed city still pauses")
ns.db.settings.cities[1454] = true
Eq((Capture.Evaluate()), "city", "a re-added city does not pause")

-- An inn in a small town is resting, not a city; a sanctuary is.
mock.mapID, mock.zone, mock.subZone = 1412, "Mulgore", "Bloodhoof Village"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq((Capture.State()), "active", "a small town paused detection")
Check(mock.registered.CHAT_MSG_TEXT_EMOTE, "sources not re-registered after the city")
mock.pvpType = "sanctuary"
mock.fire("ZONE_CHANGED")
Eq((Capture.State()), "city", "a sanctuary is not a city")
mock.pvpType, mock.subZone = nil, ""
mock.fire("ZONE_CHANGED")

-- Leaving and entering cities does not grow the handler lists.
for _ = 1, 5 do
    mock.mapID = 1454; mock.fire("ZONE_CHANGED_NEW_AREA")
    mock.mapID = 1412; mock.fire("ZONE_CHANGED_NEW_AREA")
end
local fired = 0
local probe = function() fired = fired + 1 end
ns.On("CHAT_MSG_TEXT_EMOTE", probe)
mock.fire("CHAT_MSG_TEXT_EMOTE", "x", "Nobody", "", "", "", "", 0, 0, "", 0, 83, nil)
Eq(fired, 1, "a handler ran twice or not at all after the city round trips")
ns.Off("CHAT_MSG_TEXT_EMOTE", probe)

-- SIG-6: instances, and the switch.
mock.inInstance = true
mock.fire("PLAYER_ENTERING_WORLD", false, false)
Eq((Capture.State()), "instance", "listening in an instance")
Check(not mock.registered.CHAT_MSG_TEXT_EMOTE, "SIG-6: a source still registered in an instance")
mock.inInstance = false
mock.fire("PLAYER_ENTERING_WORLD", false, false)
Eq((Capture.State()), "active", "not listening again after the instance")

SlashCmdList.SOCIALDIARY("sightings off")
Eq((Capture.State()), "off", "/sd sightings off")
Eq(ns.db.settings.detectSightings, false, "the switch is not saved")
SlashCmdList.SOCIALDIARY("sightings on")
Eq((Capture.State()), "active", "/sd sightings on")

-- JNL-3's read: one entry per character, newest first.
local recent = ns.Sightings.Since(mock.now - DAY)
Check(#recent >= 2, "recent sightings missing")
Eq(recent[1].guid, HOSTILE.guid, "not newest first")
local found
for i = 1, #recent do if recent[i].guid == RHEA then found = true end end
Check(found, "the emote's sighting is not recent")

-- Anything the city round trips left waiting is drained here, or it would
-- land after the roll-up below with a month-old time.
while Capture.QueueLength() > 0 do Drain() end

-- SIG-7: older than 30 days rolls into the character's summary.
local hostileRows = #ns.db.sightings[HOSTILE.guid]
local summaryBefore = ns.Sightings.Summary(HOSTILE.guid)
Eq(summaryBefore.count, hostileRows, "the live summary does not count the raw rows")
mock.now = mock.now + 31 * DAY
-- Heard from since, from across the world, so the record outlives its rows
-- (a stranger with nothing recent at all is forgotten: see the end).
ns.Characters.Observe(HOSTILE.guid, {})
mock.fire("PLAYER_LOGIN")
Eq(ns.db.sightings[HOSTILE.guid], nil, "raw rows older than 30 days kept")
local summary = ns.db.characters[HOSTILE.guid].sightingSummary
Check(summary, "no summary after the roll-up")
Eq(summary.count, hostileRows, "summary count")
Eq(summary.zones[1413], 2, "summary zones")
-- 5 never reaches the summary: the first row took the 6 seen later that hour.
Eq(summary.levelMin, 6, "summary lowest level")
Eq(summary.levelMax, 7, "summary highest level")
Eq(summary.hostile, hostileRows, "summary hostility")
Eq(ns.Sightings.Summary(HOSTILE.guid).count, hostileRows, "the summary read lost the rolled rows")

-- A fresh sighting after the roll-up starts the raw list again.
Capture.ResetStats()
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
Drain()
Eq(#ns.db.sightings[HOSTILE.guid], 1, "no raw row after the roll-up")
Eq(ns.Sightings.Summary(HOSTILE.guid).count, hostileRows + 1, "summary and raw rows not combined")

-- PRV-3: forgetting a character forgets their sightings.
ns.Characters.Forget(HOSTILE.guid)
Eq(ns.db.sightings[HOSTILE.guid], nil, "sightings survived forgetting the character")

-- The test commands run, in and out of a city.
for _, command in ipairs({
    "sightings", "sightings help", "sightings recent", "sightings recent 1",
    "sightings of Rhea", "sightings of Nobody", "sightings scan",
    "sightings city", "sightings city add", "sightings city remove 1412",
    "sightings rollup", "sightings reset", "db",
}) do
    SlashCmdList.SOCIALDIARY(command)
end
Eq(ns.db.settings.cities[1412], false, "/sd sightings city remove <id>")
mock.mapID = 1454
mock.fire("ZONE_CHANGED_NEW_AREA")
SlashCmdList.SOCIALDIARY("sightings")
SlashCmdList.SOCIALDIARY("sightings scan")
Eq(Capture.QueueLength(), 0, "/sd sightings scan queued in a city")
SlashCmdList.SOCIALDIARY("sightings city remove")
Eq(ns.db.settings.cities[1454], false, "/sd sightings city remove, standing in it")
Eq((Capture.State()), "active", "removing the current city did not resume")
SlashCmdList.SOCIALDIARY("sightings city add")
Eq((Capture.State()), "city", "adding the current city did not pause")
ns.db.settings.cities[1412] = nil
mock.mapID = 1412
mock.fire("ZONE_CHANGED_NEW_AREA")
-- Rolled rows do not come back, so a day under one is refused, and sooner
-- than the retention setting has to be meant.
mock.now = mock.now + 61
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
Drain()
Check(next(ns.db.sightings), "no rows to roll up")

-- The way through a city's gate and back keeps the throttle: nobody is read
-- again for it.
local stamps = ns._test.SightingThrottleSize()
Check(stamps > 0, "no throttle stamp to keep")
mock.mapID = 1454
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq((Capture.State()), "city", "the gate did not pause capture")
Eq(ns._test.SightingThrottleSize(), stamps, "the gate wiped the throttle")
mock.mapID = 1412
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(Capture.QueueLength(), 0, "the way back through the gate read them again")

SlashCmdList.SOCIALDIARY("sightings rollup 0")
Check(next(ns.db.sightings), "/sd sightings rollup 0 rolled rows up")
SlashCmdList.SOCIALDIARY("sightings rollup -5")
Check(next(ns.db.sightings), "/sd sightings rollup -5 rolled rows up")
mock.now = mock.now + 2 * DAY
SlashCmdList.SOCIALDIARY("sightings rollup 1")
Check(next(ns.db.sightings), "a rollup sooner than the retention went ahead unconfirmed")
SlashCmdList.SOCIALDIARY("sightings rollup 1 confirm")
Eq(next(ns.db.sightings), nil, "a confirmed rollup kept rows")

--------------------------------------------------------------------------
Section("seen around and the stranger tooltip (SES-9, REU-6)")

mock.mapID, mock.zone = 1412, "Mulgore"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq((Capture.State()), "active", "setup: not listening")
while Capture.QueueLength() > 0 do Drain() end
local open = ns.Sessions.Current()
if open then ns.Sessions.Close(open) end

for i = 1, 40 do mock.SetUnit("nameplate" .. i, nil) end
mock.SetUnit("nameplate8", FRIEND)

-- Outside the diary, a sighting is only a sighting.
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
Drain()
Eq(ns.db.around[FRIEND.guid], nil, "seen around kept for somebody outside the diary")

-- SES-9: three pulses within the gap make a stretch worth showing.
ns.Diary.Add(FRIEND.guid, { source = "test" })
local aroundStart = mock.now + 61
for _ = 1, 3 do
    mock.now = mock.now + 61
    Capture.Sweep()
    Drain()
end
local stretches = ns.Sessions.AroundFor(FRIEND.guid)
Eq(#stretches, 1, "no seen-around stretch after three pulses")
Eq(stretches[1].start, aroundStart, "stretch start")
Eq(stretches[1].count, 3, "stretch pulses")
Eq(stretches[1].zones[1], "Mulgore", "stretch zone")
Eq(ns.Sessions.Current(), nil, "seen around opened a together session")
Eq(ns.People.Stats(FRIEND.guid).timesMet, 0, "seen around counted as meeting them")

local timeline = ns.Timeline.For(FRIEND.guid)
local aroundItem
for i = 1, #timeline do
    if timeline[i].kind == "around" then aroundItem = timeline[i] end
end
Check(aroundItem, "seen around missing from the timeline")
local _, aroundText, _, aroundIcon = ns.UI.DescribeItem(aroundItem, FRIEND.guid)
Eq(aroundText, "Seen around Mulgore for 2 min", "seen-around line")
Eq(aroundIcon, "around", "seen-around icon")

-- A single glimpse later is not kept once the next stretch starts.
mock.now = mock.now + 30 * 60
Capture.Sweep()
Drain()
Eq(#ns.Sessions.AroundFor(FRIEND.guid), 1, "a glimpse shown as seen around")
mock.now = mock.now + 30 * 60
Capture.Sweep()
Drain()
Eq(#ns.db.around[FRIEND.guid], 2, "glimpses pile up instead of being replaced")

SlashCmdList.SOCIALDIARY("sightings around Numa")

-- Together already: the session is the record, not seen around.
local before = ns.db.around[FRIEND.guid][2].count
local together = ns.Sessions.Together(FRIEND.guid, "group", true)
mock.now = mock.now + 61
Capture.Sweep()
Drain()
Eq(ns.db.around[FRIEND.guid][2].count, before, "a pulse during a together session")
SlashCmdList.SOCIALDIARY("sightings around Numa")
SlashCmdList.SOCIALDIARY("sightings around Tullus")
ns.Sessions.Close(together)

-- REU-6: off by default.
local P = ns.UI.SettingsPage()
mock.SetUnit("nameplate9", STRANGER2)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
Drain()
local firstSeen = mock.now
Eq(ns.db.settings.tooltipSeen, false, "REU-6 is on by default")
Eq(#mock.UnitTooltip(STRANGER2.guid), 0, "a stranger line with REU-6 off")

P.tooltipSeen:Click()
Eq(ns.db.settings.tooltipSeen, true, "the settings checkbox did not switch REU-6 on")

-- The encounter happening now is not "seen before".
Eq(#mock.UnitTooltip(STRANGER2.guid), 0, "the current encounter counted")

-- Seen once before is not worth a line.
mock.now = mock.now + 10 * 60
Eq(#mock.UnitTooltip(STRANGER2.guid), 0, "a line for a single earlier sighting")

-- What hid the line in game: met again inside the same zone-hour, so the
-- nameplate has updated the earlier sighting's row to now before the tooltip
-- is built. The earlier sighting is still "seen before".
mock.now = mock.now + 20 * 60
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
Drain()
Eq(#ns.db.sightings[STRANGER2.guid], 1, "setup: not the same zone-hour")
local count, last = ns.Sightings.SeenBefore(STRANGER2.guid, mock.now)
Eq(count, 1, "an earlier sighting in the same zone-hour hidden by the current one")
Eq(last, firstSeen, "the earlier sighting's time replaced by the current one")
Eq(#mock.UnitTooltip(STRANGER2.guid), 0, "a line for a single earlier sighting")
local secondSeen = mock.now

-- An encounter that starts a row of its own does not count itself; rolled-up
-- history counts like raw rows.
mock.now = mock.now + 2 * 3600
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
Drain()
ns.Sightings.Rollup(mock.now + 1, 0)
Eq(ns.db.sightings[STRANGER2.guid], nil, "setup: not rolled up")
Eq(#mock.UnitTooltip(STRANGER2.guid), 0, "the current encounter counted as an earlier one")
mock.now = mock.now + 10 * 60
local lines = mock.UnitTooltip(STRANGER2.guid)
Eq(lines[1], "Seen twice  ·  last " .. ns.UI.Format.At(secondSeen + 2 * 3600, mock.now),
    "rolled-up sightings not counted")

-- Three and up are numbers.
mock.now = mock.now + 2 * 3600
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
Drain()
mock.now = mock.now + 10 * 60
Check(mock.UnitTooltip(STRANGER2.guid)[1]:find("^Seen 3 times  ·  "), "three sightings not worded as a number")

SlashCmdList.SOCIALDIARY("sightings tooltip")
mock.SetUnit("target", STRANGER2)
SlashCmdList.SOCIALDIARY("sightings tooltip")

-- Independent of the diary lines; never for diary entries or the user's alts.
ns.db.settings.tooltips = false
Eq(#mock.UnitTooltip(STRANGER2.guid), 1, "the stranger line follows the diary-lines switch")
ns.db.settings.tooltips = true
for _, line in ipairs(mock.UnitTooltip(FRIEND.guid)) do
    Check(not line:find("^Seen"), "a stranger line on a diary entry")
end
ns.db.characters[STRANGER2.guid].isSelf = true
Eq(#mock.UnitTooltip(STRANGER2.guid), 0, "a stranger line for the user's own alt")
Eq(#mock.UnitTooltip(mock.secret(STRANGER2.guid)), 0, "a stranger line for a secret GUID")
P.tooltipSeen:Click()

-- PRV-3: forgetting them forgets the stretches.
ns.Characters.Forget(FRIEND.guid)
Eq(ns.db.around[FRIEND.guid], nil, "seen around survived forgetting the character")
for i = 1, 40 do mock.SetUnit("nameplate" .. i, nil) end

--------------------------------------------------------------------------
Section("sighting throttle bookkeeping (SIG-8)")

local ROAMER = F.Player{ guid = "Player-4620-00EEEE04", "Roam", "Er", level = 12 }

mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
ns.db.settings.cities[1454] = true
Eq((Capture.Evaluate()), "active", "setup: not listening")
while Capture.QueueLength() > 0 do Drain() end

mock.SetUnit("nameplate4", ROAMER)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
Drain()
Check(ns._test.SightingThrottleSize() > 0, "setup: no throttle stamp")
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
Eq(Capture.QueueLength(), 0, "draining the queue reset the throttle")

-- Someone already recorded keeps their stamp through a city's gate: walking
-- back and forth reads nobody again.
mock.mapID, mock.zone = 1454, "Orgrimmar"
mock.fire("ZONE_CHANGED_NEW_AREA")
Check(ns._test.SightingThrottleSize() > 0, "entering a city dropped a recorded player's stamp")
mock.mapID, mock.zone = 1412, "Mulgore"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(Capture.QueueLength(), 0, "the way back through the gate read a recorded player again")

-- Dropping the queue drops the stamps of those in it: whoever was waiting
-- was never recorded, so the sweep on the way out of the city queues them.
mock.now = mock.now + 61
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
Eq(Capture.QueueLength(), 1, "setup: not queued")
mock.mapID, mock.zone = 1454, "Orgrimmar"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(Capture.QueueLength(), 0, "entering a city kept the queue")
mock.mapID, mock.zone = 1412, "Mulgore"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(Capture.QueueLength(), 1, "the sweep after the city was throttled by a dropped stamp")
Drain()

-- The sweep prunes stamps that no longer hold anyone back.
mock.SetUnit("nameplate4", nil)
mock.now = mock.now + 61
Capture.Sweep()
Eq(ns._test.SightingThrottleSize(), 0, "expired throttle stamps were kept")

--------------------------------------------------------------------------
Section("a day's people without the page (JNL-3)")

-- ns.Sightings.DayEntries and QueryDay, the Recently nearby page's data.
wipe(ns.db.sightings)
local day = ns.DayStart(mock.now) - 2 * DAY
local P1, P2, P3 = "Player-4620-00D00001", "Player-4620-00D00002", "Player-4620-00D00003"
ns.Characters.Observe(P1, { first = "Anna", surname = "Zed", level = 10 })
ns.Characters.Observe(P2, { first = "Bert", surname = "Yew" })
ns.Characters.Observe(P3, { first = "Carl", surname = "Xu", level = 30 })
ns.Characters.Get(P3).isSelf = true  -- one of the user's alts
local MAP = { mapID = 1412, x = 0.1, y = 0.2 }
ns.Sightings.Record(P1, { level = 11, hostile = true, source = "plate" }, MAP, day - DAY + 3600)
ns.Sightings.Record(P1, { level = 12, source = "plate" }, MAP, day + 3600)
ns.Sightings.Record(P2, { source = "say" }, { zone = "Restricted Place" }, day + 7200)
ns.Sightings.Record(P3, { source = "plate" }, MAP, day + 7200)
-- P1: talked, then traded (the stronger mark wins); a group join the day
-- after does not count for this day.
ns.Interactions.Add(P1, "whisper_in", { time = day + 3700 })
ns.Interactions.Add(P1, "trade", { time = day + 3800 })
ns.Interactions.Add(P1, "group_join", { time = day + DAY + 60 })

local entries = ns.Sightings.DayEntries(day)
local by = {}
for _, e in ipairs(entries) do by[e.guid] = e end
Eq(#entries, 2, "the user's own alt is listed, or someone is missing")
Check(not by[P3], "an alt on the day's list")
Eq(by[P1].name, "Anna Zed", "name")
Eq(by[P1].level, 12, "the day's level")
Eq(by[P1].days, 2, "seen on two days")
Eq(by[P1].firstLevel, 11, "level when first seen")
Eq(by[P1].dealt, "trade", "the strongest mark of the day")
Eq(by[P1].dealtAt, day + 3800, "when")
Eq(by[P1].hostile, false, "hostile the day before is not hostile today")
Eq(by[P2].zone, "Restricted Place", "the zone name without a map")
Eq(by[P2].dealt, nil, "nothing dealt")
Eq(by[P2].days, 1, "seen on one day")

local function Q(q)
    local names = {}
    for i, e in ipairs(ns.Sightings.QueryDay(entries, q)) do names[i] = e.name end
    return table.concat(names, ",")
end
Eq(Q({ search = "", filter = "everyone", sort = "last", dir = -1 }), "Bert Yew,Anna Zed", "latest first")
Eq(Q({ search = "", filter = "everyone", sort = "name", dir = 1 }), "Anna Zed,Bert Yew", "by name")
Eq(Q({ search = "", filter = "dealt", sort = "last", dir = -1 }), "Anna Zed", "dealt with")
Eq(Q({ search = "", filter = "before", sort = "last", dir = -1 }), "Anna Zed", "seen before")
Eq(Q({ search = "RESTRICTED", filter = "everyone", sort = "last", dir = -1 }), "Bert Yew", "search the zone")
Eq(Q({ search = "(", filter = "everyone", sort = "last", dir = -1 }), "", "a pattern character in the search")

--------------------------------------------------------------------------
Section("the subzone on a sighting row")

-- A row keeps the subzone the user was in when its zone-hour began, like
-- its x and y; later sightings in the same hour do not move it.
mock.mapID, mock.zone, mock.subZone = 1412, "Mulgore", "Bloodhoof Village"
local where = ns.Where()
Eq(where.subZone, "Bloodhoof Village", "setup: Where() has no subzone")
local S1, S2 = "Player-4620-00D00011", "Player-4620-00D00012"
ns.Characters.Observe(S1, { first = "Dora", surname = "Wick" })
ns.Characters.Observe(S2, { first = "Emil", surname = "Vane" })
local _, srow = ns.Sightings.Record(S1, { source = "plate" }, where, day + 3600)
Eq(srow.subZone, "Bloodhoof Village", "a new row did not keep the subzone")
ns.Sightings.Record(S1, { source = "plate" },
    { mapID = 1412, x = 0.5, y = 0.5, subZone = "Red Cloud Mesa" }, day + 3700)
Eq(srow.subZone, "Bloodhoof Village", "a later sighting in the same hour moved the subzone")
Eq(ns.Sightings.Latest(S1).subZone, "Bloodhoof Village", "Latest drops the subzone")

mock.subZone = ""
Eq(ns.Where().subZone, nil, "an unnamed subzone is stored as an empty string")
local _, bare = ns.Sightings.Record(S2, { source = "plate" }, ns.Where(), day + 3600)
Eq(bare.subZone, nil, "a row with no subzone got one")

local sentries = ns.Sightings.DayEntries(day)
local sby = {}
for _, e in ipairs(sentries) do sby[e.guid] = e end
Eq(sby[S1].subZone, "Bloodhoof Village", "the day's entry has no subzone")
Eq(sby[S1].zone, "Mulgore", "the subzone replaced the zone")
Eq(sby[S2].subZone, nil, "an entry without a subzone got one")

local function SQ(q)
    local names = {}
    for i, e in ipairs(ns.Sightings.QueryDay(sentries, q)) do names[i] = e.name end
    return table.concat(names, ",")
end
Eq(SQ({ search = "bloodhoof", filter = "everyone", sort = "last", dir = -1 }), "Dora Wick", "search the subzone")
-- By zone, a row with no subzone comes first in its zone; by subzone, a row
-- with none comes last, whichever way round.
local function Sorted(sort, dir)
    local names = {}
    for i, e in ipairs(ns.Sightings.QueryDay({ sby[S1], sby[S2] }, { search = "", filter = "everyone", sort = sort, dir = dir })) do
        names[i] = e.name
    end
    return table.concat(names, ",")
end
Eq(Sorted("zone", 1), "Emil Vane,Dora Wick", "by zone, then subzone")
Eq(Sorted("subzone", 1), "Dora Wick,Emil Vane", "by subzone, none last")
Eq(Sorted("subzone", -1), "Dora Wick,Emil Vane", "by subzone reversed, none still last")

-- Added off the page: the profile's "last seen" names the subzone too.
ns.Diary.Add(S1, { source = "nearby",
    where = { zone = "Mulgore", subZone = sby[S1].subZone, mapID = 1412, x = 0.1, y = 0.2 } })
Eq(ns.Characters.Get(S1).seen.subZone, "Bloodhoof Village", "last seen lost the subzone on add")
Eq(ns.UI.Format.SeenText(ns.Characters.Get(S1).seen):match(" in (.+)$"), "Bloodhoof Village, Mulgore",
    "the profile line does not name the subzone")
ns.Characters.Forget(S1)
ns.Characters.Forget(S2)

-- A subzone named like its zone says nothing more, so the entry has none.
local S3 = "Player-4620-00D00013"
ns.Characters.Observe(S3, { first = "Fern", surname = "Ashby" })
ns.Sightings.Record(S3, { source = "plate" }, { mapID = 1412, x = 0.3, y = 0.3, subZone = "Mulgore" }, day + 3600)
local fern
for _, e in ipairs(ns.Sightings.DayEntries(day)) do
    if e.guid == S3 then fern = e end
end
Check(fern, "setup: Fern Ashby not seen that day")
Eq(fern and fern.subZone, nil, "a subzone named like its zone was kept")
ns.Characters.Forget(S3)

--------------------------------------------------------------------------
Section("a diary entry's level-up, seen on a nameplate")

-- The sighting path reads the level off the unit (ObserveUnit), so a diary
-- entry seen higher than last time gets a level-up row, timed when seen.
mock.mapID, mock.zone, mock.inInstance, mock.pvpType = 1412, "Mulgore", false, nil
mock.fire("PLAYER_ENTERING_WORLD", false, false)
Eq((Capture.State()), "active", "not listening for the level-up test")

local LEVELER = F.Player{ guid = "Player-4620-00BBBB09", "Ancus", "Marcius",
    class = "HUNTER", race = "Orc", sex = 2, level = 15, faction = "Horde" }
mock.SetUnit("nameplate11", LEVELER)
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
Drain()
ns.Diary.Add(LEVELER.guid, { source = "test" })

local function Ups()
    local list = {}
    for _, row in ipairs(ns.Interactions.For(LEVELER.guid) or {}) do
        if row.type == "level_up" then list[#list + 1] = row.context.from .. ">" .. row.context.level end
    end
    return table.concat(list, ",")
end

LEVELER.level = 16
mock.SetUnit("nameplate11", LEVELER)
mock.now = mock.now + 61
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
Drain()
Eq(Ups(), "15>16", "a level-up seen on a nameplate was not logged")

-- Within the sighting throttle the new level is not read at all.
LEVELER.level = 17
mock.SetUnit("nameplate11", LEVELER)
mock.now = mock.now + 10
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
Drain()
Eq(Ups(), "15>16", "a sighting inside the throttle read the level")

--------------------------------------------------------------------------
Section("forgetting people outside the diary (INT-2 for the records)")

-- Past the window with nothing left to hold them, strangers go at login,
-- sighting summary and all. Diary entries, the user's own characters and
-- anyone with a row still in the window stay.
local OLD, RECENT, TALKED, ENTRY = "Player-4620-00FFFF01", "Player-4620-00FFFF02",
    "Player-4620-00FFFF03", "Player-4620-00FFFF04"
local WHERE = { mapID = 1412, x = 0.5, y = 0.5 }
local long = mock.now - 40 * DAY
ns.Characters.Observe(OLD, { first = "Long", surname = "Gone", time = long })
ns.Sightings.Record(OLD, { source = "plate" }, WHERE, long)
ns.Characters.Observe(RECENT, { first = "Just", surname = "Seen" })
ns.Characters.Observe(TALKED, { first = "Old", surname = "Talk", time = long })
ns.Interactions.Add(TALKED, "whisper_in", { excerpt = "hi" })
ns.Characters.Observe(ENTRY, { first = "Old", surname = "Friend", time = long })
ns.Diary.Add(ENTRY, { source = "test" })
ns.db.characters[ENTRY].lastSeen = long
ns.db.characters[SELF.guid] = ns.db.characters[SELF.guid] or { guid = SELF.guid, names = {}, isSelf = true }
ns.db.characters[SELF.guid].lastSeen = long

mock.fire("PLAYER_LOGIN")
Eq(ns.Characters.Get(OLD), nil, "a stranger past the window was kept")
Check(ns.Characters.Get(RECENT), "a stranger seen today was forgotten")
Check(ns.Characters.Get(TALKED), "a stranger with an interaction in the window was forgotten")
Check(ns.Characters.Get(ENTRY), "a diary entry was forgotten")
Check(ns.Characters.Get(SELF.guid), "the user's own character was forgotten")

-- A shorter window applies at once, from the settings.
mock.now = mock.now + 2 * DAY
ns.db.settings.bufferDays = 1
ns.Interactions.Prune()
ns.Sightings.Rollup()
ns.Characters.Prune()
Eq(ns.Characters.Get(RECENT), nil, "a shorter window did not forget at once")
Eq(ns.Characters.Get(TALKED), nil, "a pruned interaction still held on to the record")
Check(ns.Characters.Get(ENTRY), "a shorter window forgot a diary entry")
ns.db.settings.bufferDays = 30


--------------------------------------------------------------------------
Section("which of the user's characters (DAT-1)")

-- A shared diary tells the user's characters apart: each row, stretch and
-- entry notes who was there, and one character's never takes another's.
local SEEN, ALT = "Player-4620-00AAAA77", "Player-4620-00ABCDEF"
local HERE = { mapID = 1412, x = 0.5, y = 0.5 }
ns.Characters.Observe(SEEN, { first = "Shared", surname = "Sight" })
local _, row = ns.Sightings.Record(SEEN, { source = "plate" }, HERE, mock.now)
Eq(row.me, SELF.guid, "a sighting row does not say who saw it")
ns.ownGUID = ALT
local how, other = ns.Sightings.Record(SEEN, { source = "plate" }, HERE, mock.now + 60)
Eq(how, "new", "an alt's sighting was folded into another character's row")
Eq(other.me, ALT, "an alt's row is not the alt's")

ns.Diary.Add(SEEN, { source = "test" })
Eq(ns.Diary.Get(SEEN).addedBy, ALT, "a diary entry does not say who added it")
local stretch = ns.Sessions.Around(SEEN, mock.now + 120, "Mulgore")
Eq(stretch.me, ALT, "a seen-around stretch does not say whose it is")
ns.ownGUID = SELF.guid
local mine = ns.Sessions.Around(SEEN, mock.now + 180, "Mulgore")
Check(mine ~= stretch and mine.me == SELF.guid, "a character took over an alt's stretch")
ns.Characters.Forget(SEEN)


--------------------------------------------------------------------------
Section("a duel's opponent is no foe (SD_DUEL_STARTED, SD_DUEL_FINISHED)")

mock.mapID, mock.zone, mock.inInstance = 1412, "Mulgore", false
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq((Capture.Evaluate()), "active", "setup: not listening in the open world")

-- A duel's opponent reads as an enemy while it lasts, and is none: not
-- marked hostile from its start (SD_DUEL_STARTED) until a moment after its
-- end (SD_DUEL_FINISHED). After that, an enemy reading counts again.
do
    local SPARRER = F.Player{ guid = "Player-4620-00AAAA0D", "Dara", "Quill", level = 9, hostile = true }
    -- Each reading 61 s after the last, past the sightings' throttle, into
    -- the same row: it turns hostile once any reading is.
    local function Read()
        mock.now = mock.now + 61
        mock.SetUnit("target", SPARRER)
        mock.fire("PLAYER_TARGET_CHANGED")
        Drain()
        local list = ns.db.sightings[SPARRER.guid]
        return list and list[#list].hostile
    end
    ns.Fire("SD_DUEL_STARTED", SPARRER.guid)
    Eq(Read(), nil, "a duel's opponent marked hostile")
    -- The duel ends 3 s before the next reading: their reaction may not
    -- have turned back yet.
    mock.now = mock.now + 58
    ns.Fire("SD_DUEL_FINISHED", SPARRER.guid, "won")
    mock.now = mock.now - 58
    local throttled = Capture.Stats().throttled
    Eq(Read(), nil, "the opponent marked hostile as the duel ended")
    Eq(Capture.Stats().throttled, throttled, "setup: the reading at the duel's end was throttled")
    Eq(Read(), true, "an enemy after the duel not marked hostile")
    -- A duel whose end never came frees them in the end.
    local LOST = F.Player{ guid = "Player-4620-00AAAA0E", "Ivo", "Thatch", level = 9, hostile = true }
    ns.Fire("SD_DUEL_STARTED", LOST.guid)
    mock.now = mock.now + 11 * 60
    mock.SetUnit("target", LOST)
    mock.fire("PLAYER_TARGET_CHANGED")
    Drain()
    Eq(ns.db.sightings[LOST.guid][1].hostile, true, "a duel never ended kept them friendly for good")
    mock.SetUnit("target", nil)
end
