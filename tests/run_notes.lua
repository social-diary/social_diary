-- The player's notes on a run's map (Core/RunNotes.lua,
-- .claude/features/dungeon-notes.md): the free card kept on the visit,
-- cleaned as on the plates, its time from the run, moved and removed, never
-- on another character's run; Forget; the schema step; the slip on the
-- people's timelines.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local RunNotes, D, Note = ns.RunNotes, ns.Dungeons, ns.Note
local KIND = "noteCard"

mock.now = 1791000000
local now = mock.now
SELF.level = 19
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()
ns.Journey.Begin(ns.ownGUID, now - 7200, 18, 1436)

local TAGGED = "Player-1-0EEEEEEE"
ns.db.characters[TAGGED] = { guid = TAGGED, names = { { first = "Ysolde", surname = "" } } }
ns.db.diary[TAGGED] = { tags = {}, addedAt = now }
local OTHER = "Player-1-0FFFFFFF"
ns.db.characters[OTHER] = { guid = OTHER, names = { { first = "Corwen", surname = "" } } }
ns.db.diary[OTHER] = { tags = {}, addedAt = now }

-- The Deadmines, two bosses fought: the first and the second of the data's.
local bosses = D.Bosses(36)
local B1, B2 = bosses[1], bosses[2]
Check(B1 and B2 and B1.floor and B1.x, "the Deadmines' bosses have places")
local START = now - 3600
local visit = ns.Instances.New({ instanceID = 36, name = "The Deadmines", instanceType = "party",
    startedAt = START, endedAt = now - 600, bossesKilled = { B1.name, B2.name },
    members = { { guid = ns.ownGUID, first = "Me", level = 19 }, { guid = TAGGED, first = "Ysolde", level = 20 } },
    pulls = { { name = B1.name, start = START + 600, stop = START + 700, killed = true },
        { name = B2.name, start = START + 1500, stop = START + 1620, killed = true } } })

--------------------------------------------------------------------------
Section("a note on the run: kept on the visit, cleaned as a card is")

Check(RunNotes.Offered(KIND), "the free card is offered on a run")
Check(not RunNotes.Offered("death"), "another kind is not (the user, 28 Nov)")
Eq(RunNotes.List(visit)[1], nil, "no notes on a new run")

local pinned = RunNotes.Insert(visit, KIND, { icon = "heart", text = "Divine Intervention saved the run.|cff00ff00",
    people = { { name = "Ysolde", guid = TAGGED } }, caption = true },
    { f = tonumber(B2.floor), x = B2.x, y = B2.y, boss = B2.name })
Check(pinned ~= nil, "the note was not saved")
Eq(visit.custom[1], pinned, "on the visit's own list")
Eq(pinned.kind, KIND, "its kind")
Eq(pinned.boss, B2.name, "pinned to the boss")
Eq(pinned.f, tonumber(B2.floor), "on the boss's floor")
Eq(pinned.text, "Divine Intervention saved the run.cff00ff00", "its words cleaned of escape codes")
Eq(pinned.people[1].guid, TAGGED, "its person linked")
Eq(pinned.caption, nil, "no caption on a run: that box is the left page's")
Eq(pinned.mapID, nil, "no mapID: no zone card reader can take it")
Eq(pinned.t, START + 1620, "its time: the pinned boss's kill")
Eq(pinned.level, 19, "the character's level on the run")
Eq(ns.Journey.Mine().custom, nil, "nothing written on the route")

local loose = RunNotes.Insert(visit, KIND, { text = "Pulled two packs here." },
    { f = tonumber(B1.floor), x = B1.x + 0.01, y = B1.y })
Check(loose ~= nil, "a free spot")
Eq(loose.boss, nil, "not pinned")
Eq(loose.icon, ns.Custom.DefaultIcon(), "an icon it must have")
Eq(loose.t, START + 700, "its time: the nearest boss fought on its floor")
Eq(visit.custom[1], loose, "the list is oldest first")
Eq(visit.custom[2], pinned, "the later after it")

local list = RunNotes.List(visit)
Eq(#list, 2, "both read")
Eq(list[2].customOf, pinned, "a copy knowing its record")
Eq(list[2].visit, visit, "and its run")
Eq(#RunNotes.On(visit, tonumber(B2.floor)), B1.floor == B2.floor and 2 or 1, "the notes on a floor")
Eq(#RunNotes.On(visit, 999999), 0, "none on a floor of nowhere")

Eq(RunNotes.Insert(visit, KIND, {}, { x = 0.5, y = 0.5 }), nil, "no floor, no note")
Eq(RunNotes.Insert(visit, "death", {}, { f = 1, x = 0.5, y = 0.5 }), nil, "no other kind")
local far = RunNotes.Insert(visit, KIND, {}, { f = tonumber(B1.floor), x = 4, y = -1 })
Eq(far.x, 1, "a spot kept on the art")
Eq(far.y, 0, "both ways")
Check(RunNotes.Remove(visit, far), "removed")

local theirs = ns.Instances.New({ instanceID = 36, me = "Player-1-0ABCDEF0", startedAt = START, members = {} })
Eq(RunNotes.Insert(theirs, KIND, { text = "x" }, { f = 1, x = 0.5, y = 0.5 }), nil,
    "never on another character's run")
Eq(theirs.custom, nil, "and nothing written on it")

--------------------------------------------------------------------------
Section("edited, moved, removed")

Check(RunNotes.Edit(visit, list[2], { text = "Saved by a bubble.", caption = true, people = {} }), "edited")
Eq(pinned.text, "Saved by a bubble.", "its words changed")
Eq(pinned.people, nil, "nobody left on it")
Eq(pinned.caption, nil, "still no caption")

Check(RunNotes.Move(visit, pinned, { f = tonumber(B1.floor), x = B1.x, y = B1.y, boss = B1.name }), "moved")
Eq(pinned.boss, B1.name, "onto the other boss")
Eq(pinned.t, START + 700, "its time follows the spot")
Check(RunNotes.Move(visit, pinned, { f = tonumber(B2.floor), x = 0.5, y = 0.5 }), "moved off the boss")
Eq(pinned.boss, nil, "pinned to none")
Check(not RunNotes.Move(visit, pinned, { x = 0.5 }), "no spot, no move")
Check(not RunNotes.Edit(theirs, pinned, { text = "x" }), "not through another's run")

Check(RunNotes.Remove(visit, loose), "removed")
Eq(#visit.custom, 1, "one left")
Check(not RunNotes.Remove(visit, loose), "not twice")

--------------------------------------------------------------------------
Section("the slip on a person's timeline")

RunNotes.Edit(visit, pinned, { people = { { name = "Ysolde", guid = TAGGED }, { name = "Corwen", guid = OTHER } } })
local lines = Note.RunCardsOf(TAGGED)
Eq(#lines, 1, "a slip on their page")
Eq(lines[1].visit, visit, "about the run")
Eq(lines[1].guid, TAGGED, "opening over their page")
local text, sub = Note.Aside(lines[1], TAGGED)
Eq(text, "Saved by a bubble.", "the words on the slip")
Check(sub:find("The Deadmines", 1, true) ~= nil, "the line under it names the dungeon: " .. tostring(sub))
Check(sub:find("19", 1, true) ~= nil, "and the level")
Check(sub:find("Corwen", 1, true) ~= nil, "and who else was there")
Eq(#Note.CardsOf(TAGGED), 0, "not one of the route's cards")
local spec = ns.Timeline.Aside("noteCardRun")
Check(spec and spec.opens(lines[1]), "a click opens the run")
local opened
local was = ns.UI.OpenVisit
ns.UI.OpenVisit = function(id, guid) opened = { id, guid } end
spec.press(lines[1])
ns.UI.OpenVisit = was
Eq(opened and opened[1], visit.id, "the run's map")
Eq(opened and opened[2], TAGGED, "over their page")

--------------------------------------------------------------------------
Section("forgetting someone: the name stays, the link goes (PRV-3)")

ns.Instances.Forget(TAGGED)
Eq(pinned.people[1].name, "Ysolde", "the name as written stays")
Eq(pinned.people[1].guid, nil, "the link is gone")
Eq(pinned.people[2].guid, OTHER, "the other link stays")
Eq(#Note.RunCardsOf(TAGGED), 0, "no slip left on their page")

--------------------------------------------------------------------------
Section("diary schema 9: a visit's custom is a list or absent")

local step = ns._test.DiarySteps[9]
Check(type(step) == "function", "the step is there")
Eq(ns._test.SchemaVersion, 9, "the diary's number")
local old = { schema = 8, instances = {
    [1] = { id = 1, instanceID = 36, members = {} },
    [2] = { id = 2, instanceID = 36, custom = "junk" },
    [3] = { id = 3, instanceID = 36, custom = {} },
    [4] = { id = 4, instanceID = 36, custom = { { kind = KIND, t = 1, f = 1, x = 0.5, y = 0.5, icon = "heart" } } },
    [5] = "not a visit",
} }
ns._test.Migrate(old, 9, ns._test.DiarySteps)
Eq(old.schema, 9, "brought to 9")
Eq(old.instances[1].custom, nil, "an old visit stays without")
Eq(old.instances[1].instanceID, 36, "and as it was")
Eq(old.instances[2].custom, nil, "a value not a list dropped")
Eq(old.instances[3].custom, nil, "an empty list gone")
Eq(old.instances[4].custom[1].icon, "heart", "a list kept")
Eq(old.instances[5], "not a visit", "anything else untouched")
local bare = { schema = 8 }
ns._test.Migrate(bare, 9, ns._test.DiarySteps)
Eq(bare.schema, 9, "a diary with no runs")

--------------------------------------------------------------------------
Section("a deleted run takes its notes with it")

ns.Instances.Remove(visit.id)
Eq(#Note.RunCardsOf(OTHER), 0, "no slip for a run gone")
