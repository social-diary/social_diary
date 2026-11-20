-- Auto-Add's rules (Core/AutoAdd.lua, .claude/features/auto-add-rules-plan.md):
-- the trigger registry and each trigger (the core's grouped and seen, the
-- features' traded, whispered, pvp, duelled), every filter (unknown data
-- failing), first-rule-wins, places, the rule id and Count, the backfill
-- over several rules, Widened, and the two migrations on old-shaped saved
-- tables (last: they log in again).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local A = ns.AutoAdd
local Tick = ns._test.TogetherTick

local MAP = { mapID = 1412, zone = "Mulgore" }
local HOUR = 3600

mock.now = 1790000000
mock.fire("PLAYER_ENTERING_WORLD", true, false)
ns._test.SettleGroup()

-- Invented people, each with what the filters read.
local function Person(guid, first, info)
    info = info or {}
    ns.Characters.Observe(guid, { first = first, faction = info.faction, level = info.level,
        class = info.class, guild = info.guild })
    return guid
end

local ALDA = "Player-1-0C000001"
local BERN = "Player-1-0C000002"
local CARA = "Player-1-0C000003"
local DOMO = "Player-1-0C000004"

local function People()
    Person(ALDA, "Alda", { faction = "Horde", level = 20, class = "MAGE" })
    Person(BERN, "Bern", { faction = "Alliance", level = 30, class = "ROGUE" })
    Person(CARA, "Cara", { faction = "Horde", level = 68, class = "PRIEST" })
    -- Nothing read but the name: every filter fails for her.
    Person(DOMO, "Domo")
end

-- Nobody in the diary, nothing buffered, no sightings, nobody declined,
-- and the rules `list` (NewRule's fields, each with a `trigger`).
local function Fresh(list)
    T.BlankDiary()
    ns.db.sightings = {}
    ns.db.meta.declined = {}
    ns.db.settings.autoAddRules = {}
    People()
    local made = {}
    for i, fields in ipairs(list or {}) do
        local f = {}
        for k, v in pairs(fields) do if k ~= "trigger" then f[k] = v end end
        if f.on == nil then f.on = true end
        made[i] = A.NewRule(fields.trigger, f)
    end
    return made
end

local function In(guid) return ns.Diary.IsDiary(guid) end

local function Trade(guid) ns.Interactions.Add(guid, "trade", {}) end
local function Whisper(guid, kind) ns.Interactions.Add(guid, kind or "whisper_in", { excerpt = "hi" }) end
local function Sight(guid, n, start, hostile)
    for i = 1, n do
        ns.Sightings.Record(guid, { source = "plate", hostile = hostile }, MAP, start + (i - 1) * HOUR)
        A.Sighted(guid)
    end
end

ns.SetSetting("autoAdd", true)

-- What the addon said in chat.
local said = {}
local chained = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(frame, msg)
    said[#said + 1] = tostring(msg)
    return chained(frame, msg)
end

--------------------------------------------------------------------------
Section("the registry: core and features")

for _, key in ipairs({ "grouped", "seen", "traded", "whispered", "pvp", "duelled" }) do
    local spec = A.Trigger(key)
    Check(spec, "no trigger " .. key)
    Check(spec and spec.amount and spec.amount.min and spec.amount.max and spec.amount.default
        and #spec.amount.steps > 0, key .. ": no amount bounds")
    Check(spec and type(spec.describe) == "function" and type(spec.count) == "function", key .. ": no describe or count")
    Check(spec and type(spec.source) == "string" and spec.source:find("^auto_"), key .. ": no source")
    Check(spec and type(spec.label) == "string", key .. ": no label")
end
local keys = {}
for _, spec in ipairs(A.Triggers()) do keys[#keys + 1] = spec.key end
Eq(table.concat(keys, ","), "grouped,seen,traded,whispered,pvp,duelled", "the form's order")
Eq(A.Trigger("grouped").backfill, false, "grouped can be backfilled")
Eq(A.Trigger("seen").backfill, true, "seen can't be backfilled")
Eq(A.Trigger("whispered").option.default, "either", "whispered's default")
Eq(A.Trigger("pvp").option.default, "either", "pvp's default")
Check(A.Trigger("grouped").option.multi, "grouped's places are not a set")

-- A rule of a trigger nobody registered never matches.
Fresh({ { trigger = "traded", amount = 1 } })
ns.db.settings.autoAddRules[1].trigger = "nonesuch"
Trade(ALDA)
Check(not In(ALDA), "an unknown trigger added someone")

--------------------------------------------------------------------------
Section("rule ids, MAX_RULES, NewRule")

local rules = Fresh()
local first = A.NewRule("traded", { on = true })
local second = A.NewRule("seen")
Check(first and second and second.id > first.id, "ids do not grow")
Eq(second.on, false, "a new rule starts on")
Eq(second.amount, 3, "a new seen rule's amount")
Eq(A.NewRule("nonesuch"), nil, "a rule for an unknown trigger")
table.remove(ns.db.settings.autoAddRules, 2)
local third = A.NewRule("seen")
Check(third.id > second.id, "a deleted rule's id was used again")
for _ = 1, 20 do A.NewRule("seen") end
Eq(#A.Rules(), A.MAX_RULES, "more rules than MAX_RULES")
Eq(A.NewRule("seen"), nil, "a rule past MAX_RULES")

--------------------------------------------------------------------------
Section("traded")

rules = Fresh({ { trigger = "traded", amount = 2, tag = "trader" } })
Trade(ALDA)
Check(not In(ALDA), "added after one trade of two")
Trade(ALDA)
local entry = ns.Diary.Get(ALDA)
Check(entry, "not added after two trades")
Eq(entry and entry.addedContext.source, "auto_trade", "the source")
Eq(entry and entry.addedContext.rule, rules[1].id, "the rule id")
Eq(entry and entry.tags[1], "trader", "the tag")
Eq(A.Count(rules[1].id), 1, "Count")
-- Count reads only this character's entries.
entry.addedBy = "Player-1-0FFFFFFF"
Eq(A.Count(rules[1].id), 0, "Count took another character's entry")

--------------------------------------------------------------------------
Section("whispered: in, out, either")

rules = Fresh({ { trigger = "whispered", amount = 2, option = "in" } })
Whisper(ALDA, "whisper_out")
Whisper(ALDA, "whisper_out")
Check(not In(ALDA), "whispers to them counted as from them")
Whisper(ALDA, "whisper_in")
Check(not In(ALDA), "added after one whisper from them")
Whisper(ALDA, "whisper_in")
Check(In(ALDA), "not added after two whispers from them")
Eq(ns.Diary.Get(ALDA).addedContext.source, "auto_whisper", "the source")

rules = Fresh({ { trigger = "whispered", amount = 2, option = "out" } })
Whisper(ALDA, "whisper_in")
Whisper(ALDA, "whisper_in")
Check(not In(ALDA), "whispers from them counted as to them")
Whisper(ALDA, "whisper_out")
Whisper(ALDA, "whisper_out")
Check(In(ALDA), "not added after two whispers to them")

rules = Fresh({ { trigger = "whispered", amount = 2, option = "either" } })
Whisper(ALDA, "whisper_in")
Whisper(ALDA, "whisper_out")
Check(In(ALDA), "either way did not add both ways")

-- A /say is not a whisper.
rules = Fresh({ { trigger = "whispered", amount = 1 } })
ns.Interactions.Add(ALDA, "say", { excerpt = "hi" })
Check(not In(ALDA), "a /say counted as a whisper")

--------------------------------------------------------------------------
Section("pvp: a guess counts only once the recap confirms it")

rules = Fresh({ { trigger = "pvp", amount = 1, option = "killedMe", tag = "foe" } })
local fight = ns.WorldPvP.Died({ player = true, guid = BERN }, mock.now, ns.Where())
Check(fight, "setup: no fight")
Check(not In(BERN), "a probable killer was added")
Eq(A.Passes(BERN, rules[1]), false, "a probable death passes")
ns.WorldPvP.Resolve(fight, { player = true, guid = BERN }, mock.now, ns.Where())
entry = ns.Diary.Get(BERN)
Check(entry, "the confirmed killer was not added")
Eq(entry and entry.addedContext.source, "auto_pvp", "the source")
Eq(entry and entry.tags[1], "foe", "the tag")

-- Moved by the recap to someone else: only the real killer counts.
rules = Fresh({ { trigger = "pvp", amount = 1, option = "killedMe" } })
fight = ns.WorldPvP.Died({ player = true, guid = BERN }, mock.now, ns.Where())
ns.WorldPvP.Resolve(fight, { player = true, guid = ALDA }, mock.now, ns.Where())
Check(In(ALDA), "the player the recap names was not added")
Check(not In(BERN), "the guess was added")

-- Taken back (a creature killed you): nobody.
rules = Fresh({ { trigger = "pvp", amount = 1, option = "either" } })
fight = ns.WorldPvP.Died({ player = true, guid = BERN }, mock.now, ns.Where())
ns.WorldPvP.Resolve(fight, nil, mock.now, ns.Where())
Check(not In(BERN), "added off a death the recap took back")

-- Killed them.
rules = Fresh({ { trigger = "pvp", amount = 2, option = "killedThem" } })
ns.WorldPvP.Kill(BERN)
Check(not In(BERN), "added after one kill of two")
fight = ns.WorldPvP.Died({ player = true, guid = BERN }, mock.now, ns.Where())
ns.WorldPvP.Resolve(fight, { player = true, guid = BERN }, mock.now, ns.Where())
Check(not In(BERN), "a death counted as a kill")
ns.WorldPvP.Kill(BERN, ALDA)
Check(In(BERN), "a group's kill did not count")

rules = Fresh({ { trigger = "pvp", amount = 2, option = "either" } })
ns.WorldPvP.Kill(BERN)
fight = ns.WorldPvP.Died({ player = true, guid = BERN }, mock.now, ns.Where())
Check(not In(BERN), "either: a guess counted")
ns.WorldPvP.Resolve(fight, { player = true, guid = BERN }, mock.now, ns.Where())
Check(In(BERN), "either: a kill and a confirmed death did not add")

--------------------------------------------------------------------------
Section("duelled: a series counts every duel won or lost")

rules = Fresh({ { trigger = "duelled", amount = 3 } })
local t0 = mock.now
ns.Duels.Added(ALDA, "won", t0, t0 + 30)
Check(not In(ALDA), "added after one duel of three")
ns.Duels.Added(ALDA, "lost", t0 + 60, t0 + 90)
Eq(T.Rows(ALDA, ns.Duels.KIND), 1, "setup: the rematch made a new series")
Check(not In(ALDA), "added after two duels of three")
ns.Duels.Added(ALDA, "won", t0 + 120, t0 + 150)
entry = ns.Diary.Get(ALDA)
Check(entry, "not added after three duels in one series")
Eq(entry and entry.addedContext.source, "auto_duel", "the source")

--------------------------------------------------------------------------
Section("seen")

rules = Fresh({ { trigger = "seen", amount = 2 } })
Sight(ALDA, 1, mock.now)
Check(not In(ALDA), "added after one sighting of two")
Sight(ALDA, 1, mock.now + 2 * HOUR)
Check(In(ALDA), "not added after two sightings")
Sight(BERN, 4, mock.now, true)
Check(not In(BERN), "hostile sightings counted")

--------------------------------------------------------------------------
Section("filters, unknown data failing")

local function Passes(guid, filters)
    rules = Fresh({ { trigger = "traded", amount = 1, filters = filters } })
    ns.db.interactions[guid] = { { type = "trade", time = mock.now } }
    return A.Passes(guid, rules[1])
end

-- (the player: Horde, level 70)
Check(Passes(ALDA, { faction = "mine" }), "faction mine: same side failed")
Check(not Passes(BERN, { faction = "mine" }), "faction mine: the other side passed")
Check(Passes(BERN, { faction = "other" }), "faction other: the other side failed")
Check(not Passes(ALDA, { faction = "other" }), "faction other: same side passed")
Check(not Passes(DOMO, { faction = "mine" }), "faction: unknown passed mine")
Check(not Passes(DOMO, { faction = "other" }), "faction: unknown passed other")

Check(Passes(ALDA, { level = { min = 10, max = 25 } }), "level between failed")
Check(not Passes(BERN, { level = { min = 10, max = 25 } }), "level between: 30 passed 10-25")
Check(Passes(CARA, { level = { within = 2 } }), "within 2: 68 failed for a 70")
Check(not Passes(ALDA, { level = { within = 5 } }), "within 5: 20 passed for a 70")
Check(not Passes(DOMO, { level = { min = 1, max = 60 } }), "level: unknown passed")
Check(not Passes(DOMO, { level = { within = 59 } }), "level within: unknown passed")
rules = Fresh({ { trigger = "traded", amount = 1, filters = { level = { min = 1, max = 99 } } } })
ns.db.interactions[CARA] = { { type = "trade", time = mock.now } }
ns.Characters.Get(CARA).level = nil   -- (a "??" skull reads as no level)
Check(not A.Passes(CARA, rules[1]), "level: a skull passed")
ns.Characters.Get(CARA).level = -1
Check(not A.Passes(CARA, rules[1]), "level: -1 passed")

Check(Passes(ALDA, { class = { MAGE = true, PRIEST = true } }), "class failed")
Check(not Passes(BERN, { class = { MAGE = true } }), "class: a rogue passed mages")
Check(not Passes(DOMO, { class = { MAGE = true } }), "class: unknown passed")

mock.guild = nil
Person(ALDA, "Alda", { guild = "Lantern Keepers" })
Check(not Passes(ALDA, { guild = true }), "guild: passed while I'm in none")
mock.guild = "Lantern Keepers"
Check(Passes(ALDA, { guild = true }), "guild: same guild failed")
Check(not Passes(BERN, { guild = true }), "guild: unknown passed")
Person(BERN, "Bern", { guild = "Other Lot" })
Check(not Passes(BERN, { guild = true }), "guild: another guild passed")
-- A group scan's "in my guild" is enough.
rules = Fresh({ { trigger = "traded", amount = 1, filters = { guild = true } } })
ns.db.interactions[CARA] = { { type = "group_join", time = mock.now, context = { guild = true } },
    { type = "trade", time = mock.now } }
Check(A.Passes(CARA, rules[1]), "guild: a group scan's in-my-guild failed")
mock.guild = nil

-- Every filter at once is ANDed.
Check(Passes(ALDA, { faction = "mine", class = { MAGE = true }, level = { min = 15, max = 25 } }), "all three failed")
Check(not Passes(ALDA, { faction = "mine", class = { ROGUE = true } }), "one failing filter let through")

-- The filters hold for a live add too.
rules = Fresh({ { trigger = "traded", amount = 1, filters = { faction = "other" } } })
Trade(ALDA)
Check(not In(ALDA), "a live add ignored the filter")
Trade(BERN)
Check(In(BERN), "a live add that passes did not add")

--------------------------------------------------------------------------
Section("first rule wins, in list order")

rules = Fresh({
    { trigger = "traded", amount = 1, tag = "first", filters = { faction = "other" } },
    { trigger = "traded", amount = 1, tag = "second" },
    { trigger = "traded", amount = 1, tag = "third" },
})
Trade(ALDA)
Trade(BERN)
Eq(ns.Diary.Get(ALDA).tags[1], "second", "Alda (Horde) under the wrong rule")
Eq(#ns.Diary.Get(ALDA).tags, 1, "a second tag was given")
Eq(ns.Diary.Get(BERN).tags[1], "first", "Bern (Alliance) under the wrong rule")
Eq(A.Count(rules[1].id), 1, "Count of the first")
Eq(A.Count(rules[2].id), 1, "Count of the second")
Eq(A.Count(rules[3].id), 0, "Count of the third")

-- A rule switched off is passed over.
rules = Fresh({
    { trigger = "traded", amount = 1, tag = "off", on = false },
    { trigger = "traded", amount = 1, tag = "on" },
})
Trade(ALDA)
Eq(ns.Diary.Get(ALDA).tags[1], "on", "a rule switched off added")

-- A rule with no tag gives none.
rules = Fresh({ { trigger = "traded", amount = 1 } })
Trade(ALDA)
Eq(#ns.Diary.Get(ALDA).tags, 0, "a rule with no tag gave one")

-- Match: only the triggers the kind wakes.
rules = Fresh({ { trigger = "seen", amount = 1 }, { trigger = "traded", amount = 1 } })
ns.db.interactions[ALDA] = { { type = "trade", time = mock.now } }
Eq(A.Match(ALDA, "trade"), rules[2], "Match(trade)")
Eq(A.Match(ALDA, "sighting"), nil, "Match(sighting) matched a trade")
Eq(A.Match(ALDA), rules[2], "Match(any)")

--------------------------------------------------------------------------
Section("declined, ignored, and the master switch")

rules = Fresh({ { trigger = "traded", amount = 1 } })
A.Decline(ALDA)
Trade(ALDA)
Check(not In(ALDA), "a declined person was added")
C_FriendList = { IsIgnoredByGuid = function(guid) return guid == BERN end }
Trade(BERN)
Check(not In(BERN), "an ignored person was added")
C_FriendList = nil

rules = Fresh({ { trigger = "traded", amount = 1 }, { trigger = "seen", amount = 2 } })
ns.SetSetting("autoAdd", false)
Trade(ALDA)
Sight(BERN, 3, mock.now)
Check(not In(ALDA) and not In(BERN), "the master switch off still added")
ns.SetSetting("autoAdd", true)

-- Someone already in the diary is never touched: no second tag.
rules = Fresh({ { trigger = "traded", amount = 1, tag = "trader" } })
ns.Diary.Add(ALDA, { source = "test", tags = { "friend" } })
Trade(ALDA)
Eq(table.concat(ns.Diary.Get(ALDA).tags, ","), "friend", "a rule touched someone already in the diary")
Eq(ns.Diary.Get(ALDA).addedContext.rule, nil, "a hand-added entry has a rule id")

--------------------------------------------------------------------------
Section("grouped: places")

local function Group(...)
    local units = { ... }
    mock.groupSize = #units + 1
    for i = 1, 4 do mock.SetUnit("party" .. i, units[i]) end
    mock.fire("GROUP_ROSTER_UPDATE")
end

local PUG = F.PUG
-- Grouped 6 minutes where `place` says ("none", "party", "raid", "pvp"),
-- against `option`; whether they were added.
local function GroupedIn(instanceType, option)
    Fresh({ { trigger = "grouped", amount = 5, option = option, tag = "grp" } })
    mock.inInstance = instanceType ~= "none"
    mock.instanceType = instanceType ~= "none" and instanceType or "party"
    Group()
    Group(PUG)
    mock.now = mock.now + 6 * 60
    Tick()
    local added = In(PUG.guid)
    Group()
    mock.inInstance, mock.instanceType = false, "party"
    return added
end

local ALL = { world = true, dungeon = true, raid = true }
local DR = { dungeon = true, raid = true }
Check(GroupedIn("none", ALL), "anywhere: not added in the world")
Check(GroupedIn("party", ALL), "anywhere: not added in a dungeon")
Check(GroupedIn("raid", ALL), "anywhere: not added in a raid")
Check(not GroupedIn("pvp", ALL), "anywhere: added in a battleground")
Check(not GroupedIn("arena", ALL), "anywhere: added in an arena")
Check(not GroupedIn("none", DR), "dungeons and raids: added in the world")
Check(GroupedIn("party", DR), "dungeons and raids: not added in a dungeon")
Check(GroupedIn("raid", DR), "dungeons and raids: not added in a raid")
Check(GroupedIn("none", { world = true }), "world: not added in the world")
Check(not GroupedIn("party", { world = true }), "world: added in a dungeon")
Check(not GroupedIn("raid", { dungeon = true }), "dungeon: added in a raid")
Check(not GroupedIn("none", {}), "no places: added")

-- Grouped rules wake only on the tick, never on a row.
Fresh({ { trigger = "grouped", amount = 1, option = ALL } })
ns.db.interactions[ALDA] = { { type = "group_join", time = mock.now - 600 } }
ns.Interactions.Add(ALDA, "trade", {})
Check(not In(ALDA), "a trade woke a grouped rule")

-- The amount: four minutes is not five.
Fresh({ { trigger = "grouped", amount = 5, option = ALL } })
Group(PUG)
mock.now = mock.now + 4 * 60
Tick()
Check(not In(PUG.guid), "added after four minutes of five")
mock.now = mock.now + 60
Tick()
Check(In(PUG.guid), "not added after five minutes")
Group()

-- First rule wins among the grouped too: the dungeon rule before the
-- world one.
rules = Fresh({
    { trigger = "grouped", amount = 5, option = DR, tag = "dungeon" },
    { trigger = "grouped", amount = 5, option = ALL, tag = "group" },
})
mock.inInstance, mock.instanceType = true, "party"
Group(PUG)
mock.now = mock.now + 6 * 60
Tick()
Eq(ns.Diary.Get(PUG.guid) and ns.Diary.Get(PUG.guid).tags[1], "dungeon", "in a dungeon, the wrong rule")
Group()
mock.inInstance, mock.instanceType = false, "party"

--------------------------------------------------------------------------
Section("backfill over several rules, overlapping people")

local function Buffered()
    -- Alda: traded twice, seen 3 times. Bern: seen 3 times (hostile, so
    -- never counted). Cara: whispered 3 times. Domo: traded once.
    ns.db.interactions[ALDA] = { { type = "trade", time = mock.now }, { type = "trade", time = mock.now } }
    ns.db.interactions[CARA] = { { type = "whisper_in", time = mock.now }, { type = "whisper_out", time = mock.now },
        { type = "whisper_in", time = mock.now } }
    ns.db.interactions[DOMO] = { { type = "trade", time = mock.now } }
    for i = 1, 3 do
        ns.Sightings.Record(ALDA, { source = "plate" }, MAP, mock.now + i * HOUR)
        ns.Sightings.Record(BERN, { source = "plate", hostile = true }, MAP, mock.now + i * HOUR)
    end
end

rules = Fresh({
    { trigger = "seen", amount = 3, tag = "seen" },
    { trigger = "traded", amount = 1, tag = "trader" },
    { trigger = "whispered", amount = 3, option = "either", tag = "chat" },
    { trigger = "grouped", amount = 1, option = ALL, tag = "group" },
})
Buffered()
local waiting = A.Waiting()
Eq(#waiting, 3, "how many wait under every rule")
local by = {}
for _, item in ipairs(waiting) do by[item.guid] = item.rule end
Eq(by[ALDA], rules[1], "Alda (seen and traded) under the first rule")
Eq(by[CARA], rules[3], "Cara under the whisper rule")
Eq(by[DOMO], rules[2], "Domo under the trade rule")
Eq(by[BERN], nil, "Bern (seen hostile) waits")
Eq(waiting[1].guid, ALDA, "not by name")
Eq(ns.Diary.Count(), 0, "asking who waits added someone")

-- Asked for some rules only: Alda comes under the trade rule.
waiting = A.Waiting({ rules[2], rules[3] })
by = {}
for _, item in ipairs(waiting) do by[item.guid] = item.rule end
Eq(by[ALDA], rules[2], "Alda asked for trade and whispers")
Eq(#waiting, 3, "how many wait under trade and whispers")
-- Grouped is never asked about.
Eq(#A.Waiting({ rules[4] }), 0, "grouped was backfilled")
-- A rule that is off asks nothing.
rules[3].on = false
Eq(#A.Waiting({ rules[3] }), 0, "a rule switched off was backfilled")
rules[3].on = true

-- Added, each with their rule's tag and id; one line in chat.
waiting = A.Waiting()
A.Decline(DOMO)  -- (declined while the sheet was up)
local before = #said
Eq(A.AddWaiting(waiting), 2, "how many the backfill added")
Eq(#said - before, 1, "the backfill's lines in chat")
Eq(ns.Diary.Get(ALDA).tags[1], "seen", "Alda's tag")
Eq(ns.Diary.Get(ALDA).addedContext.rule, rules[1].id, "Alda's rule")
Eq(ns.Diary.Get(ALDA).addedContext.source, "auto_seen", "Alda's source")
Eq(ns.Diary.Get(CARA).tags[1], "chat", "Cara's tag")
Check(not In(DOMO), "the backfill added someone declined meanwhile")
Eq(A.Count(rules[1].id), 1, "Count after the backfill")
Eq(A.AddWaiting(waiting), 0, "a second backfill added again")
Eq(#A.Waiting(), 0, "someone still waits after the backfill")

-- Every candidate already in the diary: nobody.
rules = Fresh({ { trigger = "traded", amount = 1 } })
ns.db.interactions[ALDA] = { { type = "trade", time = mock.now } }
ns.Diary.Add(ALDA, { source = "test" })
Eq(#A.Waiting(), 0, "someone in the diary waits")

--------------------------------------------------------------------------
Section("Widened, Snapshot, AskAbout")

local base = { id = 1, on = true, trigger = "whispered", amount = 3, option = "in",
    filters = { guild = true, faction = "mine", level = { min = 10, max = 20 }, class = { MAGE = true } } }
local function With(change)
    local r = A.Snapshot(base)
    change(r)
    return r
end
Check(base.filters ~= A.Snapshot(base).filters, "Snapshot is not a deep copy")
Eq(A.Widened(base, A.Snapshot(base)), false, "unchanged is widened")
Eq(A.Widened(nil, base), true, "a new rule is not widened")
Eq(A.Widened(base, With(function(r) r.amount = 2 end)), true, "a lower amount")
Eq(A.Widened(base, With(function(r) r.amount = 4 end)), false, "a higher amount")
Eq(A.Widened(base, With(function(r) r.option = "either" end)), true, "a broader direction")
Eq(A.Widened(With(function(r) r.option = "either" end), base), false, "a narrower direction")
Eq(A.Widened(base, With(function(r) r.option = "out" end)), true, "another direction")
Eq(A.Widened(base, With(function(r) r.trigger = "traded" end)), true, "another trigger")
Eq(A.Widened(base, With(function(r) r.filters.guild = nil end)), true, "guild removed")
Eq(A.Widened(base, With(function(r) r.filters.faction = "other" end)), true, "faction changed")
Eq(A.Widened(base, With(function(r) r.filters.faction = nil end)), true, "faction removed")
Eq(A.Widened(base, With(function(r) r.filters.level.min = 5 end)), true, "level min lowered")
Eq(A.Widened(base, With(function(r) r.filters.level.max = 30 end)), true, "level max raised")
Eq(A.Widened(base, With(function(r) r.filters.level.min = 12 end)), false, "level narrowed")
Eq(A.Widened(base, With(function(r) r.filters.level = { within = 5 } end)), true, "level kind changed")
Eq(A.Widened(base, With(function(r) r.filters.class.ROGUE = true end)), true, "a class added")
Eq(A.Widened(base, With(function(r) r.filters.class = nil end)), true, "class removed")
Eq(A.Widened(With(function(r) r.filters.class.ROGUE = true end), base), false, "a class taken away")
Eq(A.Widened(With(function(r) r.filters = {} end), base), false, "filters added")
Eq(A.Widened(base, With(function(r) r.tag = "x" end)), false, "a tag change")
local within = With(function(r) r.filters.level = { within = 5 } end)
Eq(A.Widened(within, With(function(r) r.filters.level = { within = 8 } end)), true, "within raised")
Eq(A.Widened(within, With(function(r) r.filters.level = { within = 2 } end)), false, "within lowered")
local g = { id = 2, on = true, trigger = "grouped", amount = 5, option = { dungeon = true } }
Eq(A.Widened(g, { id = 2, on = true, trigger = "grouped", amount = 5, option = { dungeon = true, world = true } }),
    true, "a place added")
Eq(A.Widened(g, { id = 2, on = true, trigger = "grouped", amount = 5, option = { dungeon = true, world = false } }),
    false, "a place unticked counted")
Eq(A.Widened({ id = 3, trigger = "pvp", amount = 1, option = "killedMe" },
    { id = 3, trigger = "pvp", amount = 1, option = "either" }), true, "pvp either")

-- AskAbout: new, switched on, widened; not on-then-off, not unchanged, not
-- grouped, not a narrowed one.
rules = Fresh({
    { trigger = "seen", amount = 3 },                 -- unchanged
    { trigger = "traded", amount = 2 },               -- will be widened
    { trigger = "whispered", amount = 3, on = false }, -- will be switched on
    { trigger = "duelled", amount = 1, on = false },  -- on then off again
    { trigger = "traded", amount = 1 },               -- will be narrowed
})
local snap = A.Snapshot()
rules[2].amount = 1
rules[3].on = true
rules[5].amount = 3
local new = A.NewRule("pvp", { on = true })
A.NewRule("grouped", { on = true })
local asking = A.AskAbout(snap)
local ids = {}
for _, r in ipairs(asking) do ids[#ids + 1] = r.id end
Eq(table.concat(ids, ","), table.concat({ rules[2].id, rules[3].id, new.id }, ","), "the rules asked about")

-- Two new rules with overlapping people: each person once, under the first.
rules = Fresh({ { trigger = "seen", amount = 3, on = false } })
snap = A.Snapshot()
local r1 = A.NewRule("traded", { on = true, amount = 1, tag = "a" })
local r2 = A.NewRule("whispered", { on = true, amount = 3, tag = "b" })
Buffered()
ns.db.interactions[CARA][#ns.db.interactions[CARA] + 1] = { type = "trade", time = mock.now }
waiting = A.Waiting(A.AskAbout(snap))
by = {}
for _, item in ipairs(waiting) do by[item.guid] = item.rule end
Eq(#waiting, 3, "two new rules: how many")
Eq(by[CARA], r1, "Cara (traded and whispered) under the first new rule")
Eq(by[ALDA], r1, "Alda under the trade rule")
Eq(by[DOMO], r1, "Domo under the trade rule")
-- One widened and one new.
rules = Fresh({ { trigger = "whispered", amount = 5 } })
snap = A.Snapshot()
rules[1].amount = 3
local r3 = A.NewRule("traded", { on = true, amount = 2 })
Buffered()
waiting = A.Waiting(A.AskAbout(snap))
by = {}
for _, item in ipairs(waiting) do by[item.guid] = item.rule end
Eq(by[CARA], rules[1], "the widened rule's person")
Eq(by[ALDA], r3, "the new rule's person")
Eq(by[DOMO], nil, "Domo traded once of two")
-- The master off: the sheet's caller asks nothing (UI); Waiting itself
-- does not look at the switch, AddWaiting neither: the player said yes.

--------------------------------------------------------------------------
Section("describe and the chat line")

rules = Fresh({ { trigger = "traded", amount = 1 } })
before = #said
Trade(ALDA)
local line = said[#said] or ""
Eq(#said - before, 1, "lines in chat for one auto-add")
Check(line:find("Alda", 1, true) and line:find("traded with you once", 1, true), "the chat line: " .. line)
for _, spec in ipairs(A.Triggers()) do
    local rule = { trigger = spec.key, amount = 2, option = spec.option and A.Snapshot(spec.option.default) }
    local text = A.Describe(rule)
    Check(type(text) == "string" and text:find("2", 1, true), spec.key .. " describes: " .. tostring(text))
end
Check(A.Describe({ trigger = "grouped", amount = 5, option = DR }):find("dungeons and raids", 1, true),
    "grouped's places in its words")

--------------------------------------------------------------------------
-- The saved tables, logging in: last, as each login loads afresh.
--------------------------------------------------------------------------

local function Login(account, character)
    mock.Reset()
    local n = T.Load()
    mock.SetUnit("player", F.SELF)
    _G.SocialDiaryDB, _G.SocialDiaryCharDB = account, character
    mock.fire("ADDON_LOADED", n.addonName)
    return n, _G.SocialDiaryDB, _G.SocialDiaryCharDB
end

local function Presets(list)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = (r.preset or "?") .. "=" .. tostring(r.on) end
    return table.concat(out, ",")
end

--------------------------------------------------------------------------
Section("character schema 3: Auto-Add on")

local OLD_ON = {
    schema = 2,
    settings = { autoAdd = true, storeChat = false },
    data = { schema = 6, diary = {
        [ALDA] = { guid = ALDA, addedAt = 1, tags = { "friend" }, addedContext = { source = "auto_group" } },
        [BERN] = { guid = BERN, addedAt = 1, tags = {}, addedContext = { source = "auto_seen" } },
        [CARA] = { guid = CARA, addedAt = 1, tags = { "helper" }, addedContext = { source = "menu" } },
        -- Full up: no thirteenth tag.
        [DOMO] = { guid = DOMO, addedAt = 1, addedContext = { source = "auto_seen" },
            tags = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" } },
    } },
}
local _, _, char = Login({}, OLD_ON)
local list = char.settings.autoAddRules
Eq(char.schema, 3, "the character's schema")
Eq(Presets(list), "group=true,dungeon=false,seen=true", "the presets from Auto-Add on")
Eq(list[1].trigger, "grouped", "Group mates' trigger")
Eq(list[1].amount, 5, "Group mates' minutes")
Check(list[1].option.world and list[1].option.dungeon and list[1].option.raid, "Group mates' places")
Check(not list[2].option.world and list[2].option.dungeon and list[2].option.raid, "Dungeon & raid's places")
Eq(list[3].trigger, "seen", "Familiar faces' trigger")
Eq(list[3].amount, 3, "Familiar faces' count")
Eq(list[1].tag, "group", "Group mates' tag")
Eq(list[2].tag, "dungeon", "Dungeon & raid's tag")
Eq(list[3].tag, "seen", "Familiar faces' tag")
Eq(list[1].id .. "," .. list[2].id .. "," .. list[3].id, "1,2,3", "the ids")
Eq(char.settings.autoAddNextId, 4, "the next id")
Eq(char.settings.storeChat, false, "another setting lost")
Eq(char.settings.autoAdd, true, "the master switch moved")

--------------------------------------------------------------------------
Section("diary schema 7: the auto-added get their tags")

local d = char.data
Eq(d.schema, 7, "the diary's schema")
Eq(table.concat(d.diary[ALDA].tags, ","), "friend,group", "auto_group's tag")
Eq(table.concat(d.diary[BERN].tags, ","), "seen", "auto_seen's tag")
Eq(table.concat(d.diary[CARA].tags, ","), "helper", "an untouched entry got a tag")
Eq(#d.diary[DOMO].tags, 12, "a full entry got a thirteenth tag")
Eq(d.diary[ALDA].addedContext.rule, nil, "an old entry got a rule id")

--------------------------------------------------------------------------
Section("a second login: nothing twice, deleted presets stay deleted")

table.remove(char.settings.autoAddRules, 2)
local n2
n2, _, char = Login({}, char)
Eq(Presets(char.settings.autoAddRules), "group=true,seen=true", "a deleted preset came back")
Eq(table.concat(char.data.diary[ALDA].tags, ","), "friend,group", "tagged twice")
Eq(char.settings.autoAddNextId, 4, "the next id moved")
char.settings.autoAddRules = {}
n2, _, char = Login({}, char)
Eq(#char.settings.autoAddRules, 0, "every preset deleted, and they came back")
Eq(n2.AutoAdd.Seed(), false, "Seed seeded an empty list")

--------------------------------------------------------------------------
Section("character schema 3: Auto-Add off, and a file with no settings")

local nOff, _, off = Login({}, { schema = 2, settings = { autoAdd = false }, data = { schema = 6 } })
Eq(Presets(off.settings.autoAddRules), "group=false,dungeon=false,seen=false", "the presets from Auto-Add off")
Eq(off.settings.autoAdd, false, "the master switch moved")
local raw = { schema = 2 }
nOff._test.Migrate(raw, 3, nOff._test.CharacterSteps)
Eq(Presets(raw.settings.autoAddRules), "group=false,dungeon=false,seen=false", "a file with no settings")

--------------------------------------------------------------------------
Section("a new character: the presets, off, once")

local n3, _, fresh = Login({}, {})
Eq(fresh.schema, 3, "a new character's schema")
Eq(Presets(fresh.settings.autoAddRules), "group=false,dungeon=false,seen=false", "a new character's presets")
Eq(fresh.settings.autoAdd, false, "a new character has Auto-Add on")
Eq(fresh.settings.autoAddNextId, 4, "a new character's next id")
Eq(n3.AutoAdd.Rules(), fresh.settings.autoAddRules, "Rules is not the saved list")
local _, _, again = Login({}, fresh)
Eq(#again.settings.autoAddRules, 3, "a second login seeded again")
Eq(again.settings.autoAddNextId, 4, "a second login moved the next id")

-- A shared diary: the rules stay the character's.
local _, acct2, char2 = Login({ settings = { shareDiary = true } }, {})
Check(char2.settings.autoAddRules and not acct2.settings.autoAddRules, "the rules are not per character")
