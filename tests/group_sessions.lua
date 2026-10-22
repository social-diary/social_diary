-- Grouping capture and the together sessions it opens.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local Whisper, Rows = T.Whisper, T.Rows
local ns = T.Boot()
local Latest, Tick = ns._test.LatestInteraction, ns._test.TogetherTick

local STRANGER, PUG, SELF = F.STRANGER, F.PUG, F.SELF
local GUID = STRANGER.guid

--------------------------------------------------------------------------
Section("grouping capture (INT-1)")

mock.now = 1790000000
mock.timers = {}  -- the login's; only the settle delay below should run

-- Until the roster has settled after login, a scan would read the whole group
-- as gone, so roster updates are ignored.
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
Eq(ns.Interactions.Count(GUID), 0, "the roster was scanned before it settled")

mock.RunTimers()
Eq(Rows(GUID, "group_join"), 1, "joining a group was not recorded")
Check(ns.Roster.Has(GUID), "the group member is not in the roster")
Eq(Latest(GUID).theirLevel, 1, "their level on the join row")
Eq(ns.Sessions.Current(), nil, "a session opened with nobody from the diary (SES-1)")

mock.fire("GROUP_ROSTER_UPDATE")
Eq(Rows(GUID, "group_join"), 1, "a roster update with no change logged a join")

-- SES-3: a reload rebuilds the unit tokens from nothing. The persisted roster
-- keeps the group from being logged as joining all over again.
mock.fire("PLAYER_ENTERING_WORLD", false, true)
mock.RunTimers()
Eq(Rows(GUID, "group_join"), 1, "a reload logged the group joining again")

-- A member whose GUID reads as secret has not left.
mock.SetUnit("party1", F.Like(STRANGER, { guid = mock.secret(GUID) }))
mock.fire("GROUP_ROSTER_UPDATE")
Check(ns.Roster.Has(GUID), "an unreadable member was taken for gone")
Eq(Rows(GUID, "group_leave"), 0, "an unreadable member was logged as leaving")

mock.SetUnit("party1", nil)
mock.groupSize = 0
mock.fire("GROUP_ROSTER_UPDATE")
Eq(Rows(GUID, "group_leave"), 1, "leaving the group was not recorded")
Check(not ns.Roster.Has(GUID), "a departed member is still in the roster")

-- A roster older than the session gap says nothing about the group now: it is
-- dropped without inventing leave rows at the wrong time.
ns.db.meta.roster.members[GUID] = true
ns.db.meta.roster.time = mock.now - 2 * 3600
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
Eq(Rows(GUID, "group_leave"), 1, "a stale roster produced leave rows")
Check(not ns.Roster.Has(GUID), "a stale roster survived the login")

--------------------------------------------------------------------------
Section("together sessions (SES-1 to SES-5)")

T.BlankDiary()
local t0 = mock.now
ns.Diary.Add(GUID, { source = "test" })

-- A whisper can come from anywhere: it never opens a session.
Whisper("CHAT_MSG_WHISPER", "up for Wailing Caverns?", "Bram Redfen", 700, GUID)
Eq(ns.Sessions.Current(), nil, "a whisper opened a session")
Eq(Latest(GUID).session, nil, "a whisper outside a session was stamped")

-- SES-2 step 1: grouping with a diary entry opens one.
mock.groupSize = 3
mock.SetUnit("party1", STRANGER)
mock.SetUnit("party2", PUG)
mock.fire("GROUP_ROSTER_UPDATE")

local s = ns.Sessions.Current()
Check(s, "grouping with a diary entry did not open a session")
Eq(s.source, "group", "session source")
Eq(s.startedAt, t0, "session start")
Eq(s.me, SELF.guid, "which of the user's characters was there (DAT-1)")
Eq(s.zones[1], "Mulgore", "the first zone")
Eq(s.myLevelStart, 70, "own level at the start")
Eq(s.others, 1, "the other group member was not counted")
Eq(s.participants[PUG.guid], nil, "somebody outside the diary became a participant")

local p = s.participants[GUID]
Check(p, "the diary entry is not a participant")
Eq(p.levelStart, 1, "their level at the start")
Eq(Latest(GUID, "group_join").session, s.id, "the join row was not stamped")
Eq(#ns.Sessions.Highlights(s), 0, "the session's own join row shown as a highlight")

-- Grouped time is credited on the tick.
mock.now = t0 + 600
Tick()
Eq(p.seconds, 600, "grouped time not credited")

-- SES-5: what happens during the session lives inside it.
ns.Interactions.Add(GUID, "trade", { context = {} })
local highlights = ns.Sessions.Highlights(s)
Eq(#highlights, 1, "the trade is not a highlight of the session")
Eq(highlights[1].type, "trade", "wrong highlight")
Eq(Latest(PUG.guid, "group_join").session, nil,
    "a row with somebody outside the diary was stamped")

-- SES-4: quests, zones, deaths, levels.
mock.fire("QUEST_TURNED_IN", 783, 0, 0)
Eq(p.quests and p.quests[1], 783, "quest turned in together not counted")

mock.zone = "Thunder Bluff"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(s.zones[2], "Thunder Bluff", "zone change not recorded")
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(#s.zones, 2, "the same zone recorded twice in a row")
mock.zone = "Mulgore"
-- Walking to and fro across a border is not another place (21 Oct, in the
-- client: Stormwind City, Deeprun Tram, Stormwind City, ... up to forty).
mock.fire("ZONE_CHANGED_NEW_AREA")
mock.zone = "Thunder Bluff"
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(table.concat(s.zones, ","), "Mulgore,Thunder Bluff", "a zone come back to was written down again")
mock.zone = "Mulgore"

mock.fire("PLAYER_DEAD")
Eq(s.deaths[SELF.guid], 1, "own death not counted")
mock.fire("UNIT_DIED", GUID)
Eq(s.deaths[GUID], 1, "the participant's death not counted")
mock.fire("UNIT_DIED", PUG.guid)
Eq(s.deaths[PUG.guid], nil, "a non-participant's death counted")
mock.fire("UNIT_DIED", mock.secret(GUID))
Eq(s.deaths[GUID], 1, "a secret GUID's death counted")

mock.SetUnit("party1", F.Like(STRANGER, { level = 5 }))
mock.fire("UNIT_LEVEL", "party1")
Eq(p.levelEnd, 5, "their level at the end did not follow a level-up")

mock.fire("PLAYER_LEVEL_UP", 71)
Eq(s.myLevelEnd, 71, "own level at the end did not follow a level-up")

-- Rares and world bosses: PARTY_KILL plus a unit token still on the corpse.
local RARE = "Creature-0-4620-1-6-3068-00002C5F0C"
mock.SetUnit("target", {
    guid = RARE, name = { "Mazzranache" }, isPlayer = false, classification = "rare",
})
mock.fire("PARTY_KILL", SELF.guid, RARE)
Eq(p.rares and #p.rares, 1, "rare killed together not counted")
Eq(p.rares[1].name, "Mazzranache", "rare's name")
Eq(p.rares[1].npcID, 3068, "rare's npc id")

mock.SetUnit("target", {
    guid = "Creature-0-4620-1-6-2955-00002C5F0D", name = { "Plainstrider" },
    isPlayer = false,
})
mock.fire("PARTY_KILL", SELF.guid, "Creature-0-4620-1-6-2955-00002C5F0D")
Eq(#p.rares, 1, "an ordinary mob counted as a rare")

mock.SetUnit("target", {
    guid = RARE, name = { "Mazzranache" }, isPlayer = false, classification = "rare",
})
mock.fire("PARTY_KILL", "Player-4620-00EEEEEE", RARE)
Eq(#p.rares, 1, "a stranger's kill counted as ours")
mock.SetUnit("target", nil)

-- SES-3: a reload in the middle of a session changes nothing.
mock.now = t0 + 900
mock.fire("PLAYER_LOGOUT")
Eq(p.seconds, 900, "time up to the logout not credited")

mock.now = t0 + 930
mock.fire("PLAYER_LOGIN")
Eq(ns.Sessions.Current(), s, "a reload closed the session")
mock.fire("PLAYER_ENTERING_WORLD", false, true)
mock.RunTimers()
Eq(Rows(GUID, "group_join"), 1, "a reload logged a second join")

local count = 0
for _ in pairs(ns.db.sessions) do count = count + 1 end
Eq(count, 1, "a reload opened a second session")

mock.now = t0 + 960
Tick()
Eq(p.seconds, 930, "the time offline during the reload was credited")

-- SES-2 step 2 and 3: out of the group, seen nearby keeps it going; the gap
-- running out closes it, at the last moment together.
mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.SetUnit("party2", nil)
mock.fire("GROUP_ROSTER_UPDATE")
Eq(Rows(GUID, "group_leave"), 1, "leaving the group mid-session not recorded")

mock.now = t0 + 960 + 600
Tick()
Check(ns.Sessions.Current(), "the session closed before the gap ran out")

mock.now = t0 + 960 + 900
mock.SetUnit("mouseover", STRANGER)
Tick()
Eq(p.last, t0 + 1860, "being seen nearby did not count as together")
mock.SetUnit("mouseover", nil)

mock.now = t0 + 1860 + 1300
Tick()
Eq(ns.Sessions.Current(), nil, "the session outlived the gap")
Eq(s.endedAt, t0 + 1860, "the session should end at the last moment together")
Eq(ns.Sessions.Duration(s), 1860, "duration")
Eq(ns.db.meta.openSession, nil, "the open-session pointer outlived the session")
Eq(p.done, nil, "a closed session kept its working flags")

-- An interaction that needs both players in one place opens a session too.
ns.Interactions.Add(GUID, "trade", {})
local s2 = ns.Sessions.Current()
Check(s2 and s2 ~= s, "a trade with a diary entry did not open a new session")
Eq(s2.source, "nearby", "a session opened by a trade is a nearby session")

-- A real logout closes it at the next login, at the last moment together.
mock.fire("PLAYER_LOGOUT")
mock.now = mock.now + 3600
mock.fire("PLAYER_LOGIN")
Eq(ns.Sessions.Current(), nil, "a session survived a long logout")
Eq(s2.endedAt, s2.startedAt, "a session closed at logout got the wrong end time")

-- Backfilled rows describe the past and open nothing now.
ns.Interactions.Add(GUID, "trade", { time = mock.now - 60 })
Eq(ns.Sessions.Current(), nil, "a backfilled row opened a session")

Eq(#ns.Sessions.For(GUID), 2, "sessions for the diary entry")
Eq(ns.Sessions.For(GUID)[1], s2, "sessions should be newest first")

SlashCmdList.SOCIALDIARY("sessions")
SlashCmdList.SOCIALDIARY("sessions Bram Redfen")

-- DIA-7's "delete everything" takes their sessions with them.
ns.Diary.Remove(GUID, "purge")
Eq(next(ns.db.sessions), nil, "purging the only participant left their sessions behind")

--------------------------------------------------------------------------
Section("Sessions.New, All, DeathCount and AroundAll")

T.BlankDiary()
local FRIEND = F.GARRICK.guid
ns.Characters.Observe(FRIEND, { first = "Garrick", surname = "Fallow" })
ns.Diary.Add(FRIEND, { source = "test" })
Eq(#ns.Sessions.For(FRIEND), 0, "setup: sessions with a new entry")  -- builds the index

-- Open: the next id, the pointer, the user's level now.
local nextId = ns.db.meta.nextSessionId
local open = ns.Sessions.New({ source = "nearby", id = 999 })
Eq(open.id, nextId, "New did not take the next id")
Eq(ns.db.sessions[nextId], open, "New did not store the session")
Eq(ns.db.meta.nextSessionId, nextId + 1, "the counter did not move on")
Eq(ns.Sessions.Current(), open, "a session without endedAt is not the open one")
Eq(open.myLevelStart, 70, "an open session does not start at the user's level")
Eq(open.me, F.SELF.guid, "which of the user's characters")
ns.Sessions.Close(open, open.startedAt)

-- Written after the fact (/sd testdata): closed, no level, and its
-- participants indexed at once.
local past = ns.Sessions.New({
    source = "group", test = true, startedAt = mock.now - 7200, endedAt = mock.now - 3600,
    participants = { [FRIEND] = { since = mock.now - 7200, last = mock.now - 3600, seconds = 3600 } },
    deaths = { [FRIEND] = 2, [F.SELF.guid] = 1 },
})
Eq(ns.Sessions.Current(), nil, "a closed session became the open one")
Eq(past.myLevelStart, nil, "a past session got today's level")
Eq(past.test, true, "the test mark was not kept")
Eq(past.others, 0, "the skeleton's defaults")
Eq(ns.Sessions.For(FRIEND)[1], past, "a written session is missing from the index")

local all = ns.Sessions.All()
Eq(#all, 2, "All")
Eq(all[1], open, "All is not newest first")

Eq(ns.Sessions.DeathCount(past), 3, "DeathCount")
Eq(ns.Sessions.DeathCount(open), 0, "DeathCount without deaths")

-- SES-9: two pulses are a glimpse; AroundFor leaves it out, AroundAll not.
ns.Sessions.Around(FRIEND, mock.now, "Mulgore")
ns.Sessions.Around(FRIEND, mock.now + 60, "Mulgore")
Eq(#ns.Sessions.AroundFor(FRIEND), 0, "a glimpse counted")
local stretches = ns.Sessions.AroundAll(FRIEND)
Eq(#stretches, 1, "AroundAll lost the glimpse")
Eq(stretches[1].count, 2, "the glimpse's pulses")
stretches[1] = nil
Eq(#ns.Sessions.AroundAll(FRIEND), 1, "AroundAll handed out the stored list")
Eq(#ns.Sessions.AroundAll(F.PUG.guid), 0, "AroundAll for someone never around")

--------------------------------------------------------------------------
Section("Core/Roster.lua without unit tokens, Sessions.MyLevel")

-- The diff alone, as Capture hands it over: who is readable, and whether
-- that is everyone.
T.BlankDiary()
local R1, R2 = "Player-4620-00RRRR01", "Player-4620-00RRRR02"
ns.Characters.Observe(R1, { first = "Roster", surname = "One", level = 30 })
ns.Characters.Observe(R2, { first = "Roster", surname = "Two" })
ns.Diary.Add(R1, { source = "test" })

local toasts = {}
local function Toast(_, guid, reason) toasts[#toasts + 1] = guid .. ":" .. reason end
ns.On("SD_REUNION", Toast)

local joined = ns.Roster.Update({ [R1] = { guild = true }, [R2] = {} }, true, true)
Eq(#joined, 2, "joins")
Check(ns.Roster.Has(R1) and ns.Roster.Has(R2), "joins not persisted")
Eq(table.concat(toasts, ","), R1 .. ":group", "SD_REUNION for the diary entry only")
Eq(Latest(R1).type, "group_join", "join row")
Eq(Latest(R1).theirLevel, 30, "join row level")
Eq(Latest(R1).context.raid, true, "raid on the join row")
Eq(Latest(R1).context.guild, true, "guild on the join row")
Check(Latest(R1).session and ns.Sessions.Current() and Latest(R1).session == ns.Sessions.Current().id,
    "the join row is not stamped with the session it opened")
Eq(ns.Roster.Members(), ns.db.meta.roster.members, "Members is the persisted set")
Eq(ns.db.meta.roster.time, mock.now, "Update did not touch the roster")

-- Incomplete: R2 unreadable, not gone. Complete: gone.
toasts = {}
ns.Roster.Update({ [R1] = {} }, false)
Check(ns.Roster.Has(R2), "an incomplete scan dropped a member")
Eq(Rows(R2, "group_leave"), 0, "an incomplete scan wrote a leave row")
ns.Roster.Update({ [R1] = {} }, true)
Check(not ns.Roster.Has(R2), "a complete scan kept a departed member")
Eq(Rows(R2, "group_leave"), 1, "no leave row")
Eq(#toasts, 0, "a member already in the roster was toasted again")
ns.Off("SD_REUNION", Toast)

-- A stale roster (another character) is dropped on ForgetStale.
ns.db.meta.roster.me = "Player-0000-OTHER"
ns.Roster.ForgetStale()
Check(not ns.Roster.Has(R1), "a roster of another character survived")
Eq(ns.db.meta.roster.me, ns.ownGUID, "ForgetStale did not claim the roster")

-- The user's level at the session's end, outside Together.
Check(ns.Sessions.MyLevel(72), "MyLevel with a session open")
Eq(ns.Sessions.Current().myLevelEnd, 72, "MyLevel")
Check(not ns.Sessions.MyLevel("72"), "MyLevel took a non-number")
Eq(ns.Sessions.Current().myLevelEnd, 72, "a non-number level was stored")
ns.Sessions.Close(ns.Sessions.Current())
Check(not ns.Sessions.MyLevel(73), "MyLevel without a session")
