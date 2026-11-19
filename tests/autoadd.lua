-- Auto-add (Core/AutoAdd.lua): the opt-in exception to DIA-1.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Tick = ns._test.TogetherTick

local PUG, STRANGER = F.PUG, F.STRANGER
local MAP = { mapID = 1412, zone = "Mulgore" }
local HOUR = 3600

mock.now = 1790000000
mock.fire("PLAYER_ENTERING_WORLD", true, false)
ns._test.SettleGroup()
T.BlankDiary()

-- Today's two rules, as a character who had Auto-Add on gets them
-- (STEPS.character[3]): a new character's presets start off.
local function Rule(preset)
    for _, rule in ipairs(ns.AutoAdd.Rules()) do
        if rule.preset == preset then return rule end
    end
end
Eq(Rule("group").on, false, "a new character's Group mates is on")
Eq(Rule("seen").on, false, "a new character's Familiar faces is on")
Rule("group").on, Rule("seen").on = true, true

local function Group(...)
    local units = { ... }
    mock.groupSize = #units + 1
    for i = 1, 4 do mock.SetUnit("party" .. i, units[i]) end
    mock.fire("GROUP_ROSTER_UPDATE")
end

local function Sight(guid, n, start, hostile)
    for i = 1, n do
        ns.Sightings.Record(guid, { source = "plate", hostile = hostile }, MAP, start + (i - 1) * HOUR)
        ns.AutoAdd.Sighted(guid)
    end
end

--------------------------------------------------------------------------
Section("off by default")

Eq(ns.db.settings.autoAdd, false, "auto-add is on by default")
Group(PUG)
mock.now = mock.now + 10 * 60
Tick()
Check(not ns.Diary.IsDiary(PUG.guid), "added while the setting is off")
Sight(STRANGER.guid, 4, mock.now)
Check(not ns.Diary.IsDiary(STRANGER.guid), "added off sightings while the setting is off")

--------------------------------------------------------------------------
Section("grouped for five minutes")

T.BlankDiary()
ns.db.sightings = {}
ns.SetSetting("autoAdd", true)
Group()
Group(PUG)

mock.now = mock.now + 4 * 60
Tick()
Check(not ns.Diary.IsDiary(PUG.guid), "added before five minutes in the group")

mock.now = mock.now + 60
Tick()
local entry = ns.Diary.Get(PUG.guid)
Check(entry, "not added after five minutes in the group")
Eq(entry and entry.addedContext.source, "auto_group", "the entry's source")
Eq(entry and entry.addedContext.rule, Rule("group").id, "the entry's rule")
Eq(entry and entry.tags[1], "group", "the rule's tag")

-- Leaving and rejoining starts the count again: five minutes without a break.
T.BlankDiary()
Group(STRANGER)
mock.now = mock.now + 3 * 60
Group()
Group(STRANGER)
mock.now = mock.now + 3 * 60
Tick()
Check(not ns.Diary.IsDiary(STRANGER.guid), "two short stretches added up")

--------------------------------------------------------------------------
Section("never in a battleground")

T.BlankDiary()
mock.inInstance, mock.instanceType = true, "pvp"
Group(PUG)
mock.now = mock.now + 10 * 60
Tick()
Check(not ns.Diary.IsDiary(PUG.guid), "added from a battleground's raid")
mock.inInstance, mock.instanceType = false, "party"
Group()

--------------------------------------------------------------------------
Section("seen three times")

T.BlankDiary()
local t = mock.now
Sight(STRANGER.guid, 2, t)
Check(not ns.Diary.IsDiary(STRANGER.guid), "added after two sightings")
-- The same zone-hour again is the same occasion.
ns.Sightings.Record(STRANGER.guid, { source = "plate" }, MAP, t + HOUR + 60)
ns.AutoAdd.Sighted(STRANGER.guid)
Check(not ns.Diary.IsDiary(STRANGER.guid), "one zone-hour counted twice")

Sight(STRANGER.guid, 1, t + 2 * HOUR)
entry = ns.Diary.Get(STRANGER.guid)
Check(entry, "not added after three sightings")
Eq(entry and entry.addedContext.source, "auto_seen", "the entry's source")
Eq(entry and entry.tags[1], "seen", "the rule's tag")

-- Hostile sightings do not count.
T.BlankDiary()
ns.db.sightings = {}
Sight(F.HOSTILE.guid, 4, t, true)
Check(not ns.Diary.IsDiary(F.HOSTILE.guid), "added off hostile sightings")

--------------------------------------------------------------------------
Section("never added back, never the ignored")

T.BlankDiary()
ns.db.sightings = {}
Sight(STRANGER.guid, 3, t)
Check(ns.Diary.IsDiary(STRANGER.guid), "set-up: not added")
ns.Diary.Remove(STRANGER.guid, "keep")
Sight(STRANGER.guid, 1, t + 5 * HOUR)
Check(not ns.Diary.IsDiary(STRANGER.guid), "added back after being removed")

-- Deleting everything about them still keeps them out...
ns.Diary.Add(STRANGER.guid, { source = "test" })
ns.Diary.Remove(STRANGER.guid, "purge")
Check(ns.AutoAdd.Declined(STRANGER.guid), "a purge forgot that they were declined")
-- ...and only "Delete all data" lets them in again.
ns.ForgetEverywhere(nil)
Check(not ns.AutoAdd.Declined(STRANGER.guid), "deleting all data kept the declined list")

C_FriendList = { IsIgnoredByGuid = function(guid) return guid == PUG.guid end }
T.BlankDiary()
Group(PUG)
mock.now = mock.now + 10 * 60
Tick()
Check(not ns.Diary.IsDiary(PUG.guid), "added someone on the ignore list")
C_FriendList = nil

--------------------------------------------------------------------------
Section("backfill: who is waiting, added only when asked")

T.BlankDiary()
ns.db.sightings = {}
ns.db.meta.declined = {}
ns.SetSetting("autoAdd", false)
local base = mock.now
for i = 1, 3 do
    ns.Sightings.Record(STRANGER.guid, { source = "plate" }, MAP, base + (i - 1) * HOUR)
    ns.Sightings.Record(F.GARRICK.guid, { source = "plate" }, MAP, base + (i - 1) * HOUR)
    ns.Sightings.Record(F.HOSTILE.guid, { source = "plate", hostile = true }, MAP, base + (i - 1) * HOUR)
end
ns.Sightings.Record(PUG.guid, { source = "plate" }, MAP, base)
ns.Sightings.Record(PUG.guid, { source = "plate" }, MAP, base + HOUR)
ns.AutoAdd.Decline(F.GARRICK.guid)

local waiting = ns.AutoAdd.Waiting()
Eq(#waiting, 1, "who is waiting (not the declined, the hostile, or twice seen)")
Eq(waiting[1].guid, STRANGER.guid, "the one waiting")
Eq(waiting[1].rule, Rule("seen"), "the rule they wait under")
Eq(ns.Diary.Count(), 0, "asking who is waiting added someone")

Eq(ns.AutoAdd.AddWaiting(waiting), 1, "how many the backfill added")
Eq(ns.Diary.Get(STRANGER.guid).addedContext.source, "auto_seen", "the backfilled entry's source")
Eq(ns.AutoAdd.AddWaiting(waiting), 0, "a second backfill added them again")
Eq(#ns.AutoAdd.Waiting(), 0, "someone still waiting after the backfill")

--------------------------------------------------------------------------
Section("an older diary gets the list empty")

local old = { schema = 5, meta = { greeted = {} } }
ns._test.Migrate(old, 5, ns._test.DiarySteps)
Eq(old.meta.declined, nil, "a migration step wrote the list")
-- The defaults fill it at load (Core/DB.lua's DIARY).
Check(type(ns.db.meta.declined) == "table", "the loaded diary has no declined list")
