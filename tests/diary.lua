-- The diary itself: entries, tags, notes and removal, the slash commands
-- that drive it, and the loose entry sheet keeping up with edits.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local GUID = F.STRANGER.guid

--------------------------------------------------------------------------
Section("the diary (DIA-1 to DIA-7)")

mock.SetUnit("target", F.STRANGER)
mock.guild = "The Rusted Wheel"

-- DIA-5: what was already in the buffer comes with them, and survives a prune
-- it would otherwise have been caught by.
ns.Interactions.Add(GUID, "trade", { time = mock.now - 200 * DAY })

local entry, added = ns.Diary.Add(GUID, { unit = "target", source = "test" })
Check(entry, "nobody was added")
Eq(added, true, "add did not report itself as new")
Eq(entry.guid, GUID, "wrong GUID in the entry")
Eq(ns.Diary.IsDiary(GUID), true, "entry is not in the diary")
Eq(ns.Characters.Get(GUID).isDiary, nil, "the character record keeps its own copy of membership")
Eq(entry.guildAtAdd, "The Rusted Wheel", "guild not captured at add time (DIA-5)")
Eq(entry.class, "DRUID", "class not captured at add time")
Eq(entry.addedContext.zone, "Mulgore", "where they were added")
Eq(entry.addedContext.source, "test", "which entry point added them")
Eq(entry.addedContext.myLevel, 70, "own level at add time")

ns.Interactions.Prune(mock.now)
Eq(ns.Interactions.Count(GUID), 1, "a diary entry's buffered history was pruned (DIA-5)")

-- DIA-1: adding twice is not an error, and does not duplicate.
local again, addedAgain = ns.Diary.Add(GUID, { unit = "target" })
Eq(again, entry, "adding twice made a second entry")
Eq(addedAgain, false, "adding twice reported itself as new")
Eq(ns.Diary.Count(), 1, "diary count after a duplicate add")

Eq(ns.Diary.Add("Creature-0-4620-1-6-3098-1", {}), nil, "a creature entered the diary")
Eq(ns.Diary.Add(mock.secret("Player-1-2"), {}), nil, "a secret GUID entered the diary")

-- DIA-6: tags.
Check(ns.Diary.AddTag(GUID, "helper"), "tag not added")
Check(not ns.Diary.AddTag(GUID, "HELPER"), "the same tag was added twice in another case")
Check(ns.Diary.HasTag(GUID, "Helper"), "tag lookup is case sensitive")
Eq(#entry.tags, 1, "tag count")
Eq(ns.Diary.ToggleTag(GUID, "helper"), false, "toggle did not remove an existing tag")
Eq(#entry.tags, 0, "toggle left the tag behind")
Eq(ns.Diary.ToggleTag(GUID, "foe"), true, "toggle did not add a missing tag")
Check(not ns.Diary.AddTag(GUID, "   "), "a blank tag was added")
ns.Diary.AddTag(GUID, ("z"):rep(80))
Eq(#entry.tags[2], 24, "tag not capped in length")

for i = 1, 30 do ns.Diary.AddTag(GUID, "tag" .. i) end
Eq(#entry.tags, 12, "tag count not capped")

-- DIA-6: note and relationship.
ns.Diary.SetNote(GUID, "   helped me with Nagas   ")
Eq(entry.note, "helped me with Nagas", "note not trimmed")
ns.Diary.SetNote(GUID, "")
Eq(entry.note, nil, "an emptied note should clear, not store a blank")
ns.Diary.SetRelationship(GUID, "questing buddy")
Eq(entry.relationship, "questing buddy", "relationship not stored")

Eq(ns.Diary.SetNote("Player-4620-00DEADBE", "x"), false, "note set on a non-entry")

-- DIA-7: "keep" gives up the entry but not the character.
local OTHER = F.GARRICK.guid
ns.Diary.Add(OTHER, { source = "test" })
Eq(ns.Diary.Count(), 2, "second entry not added")

Check(ns.Diary.Remove(GUID, "keep"), "remove reported failure")
Eq(ns.Diary.IsDiary(GUID), false, "still in the diary after removal")
Check(ns.Characters.Get(GUID), "the character was deleted by a 'keep' removal")
Eq(ns.Interactions.Count(GUID), 1, "history deleted by a 'keep' removal")

-- ... and now that they are an ordinary character again, retention applies.
ns.Interactions.Prune(mock.now)
Eq(ns.Interactions.Count(GUID), 0, "retention did not resume after a 'keep' removal")

-- DIA-7: "purge" takes everything.
ns.Interactions.Add(OTHER, "trade", {})
Check(ns.Diary.Remove(OTHER, "purge"), "purge reported failure")
Eq(ns.Characters.Get(OTHER), nil, "purge left the character behind")
Eq(ns.Interactions.For(OTHER), nil, "purge left interactions behind")
Eq(ns.Diary.Count(), 0, "diary not empty after removing both entries")
Eq(ns.Diary.Remove(GUID), false, "removing a non-entry reported success")

--------------------------------------------------------------------------
Section("slash commands")

mock.SetUnit("target", F.STRANGER)
ns.db.diary = {}

-- DIA-2's slash entry point: no argument means "my target".
SlashCmdList.SOCIALDIARY("add")
Eq(ns.Diary.IsDiary(GUID), false, "/sd add added the target before Done")
_G.SocialDiaryEntryFrame.form.done:Click()
Eq(ns.Diary.IsDiary(GUID), true, "/sd add did not add the target")

SlashCmdList.SOCIALDIARY("list")

-- Arguments are a name, and an unknown one is refused rather than guessed.
SlashCmdList.SOCIALDIARY("add Nobody Here")
Eq(ns.Diary.Count(), 1, "/sd add invented a character")

SlashCmdList.SOCIALDIARY("remove Bram Redfen")
Check(mock.AnswerPopup("accept"), "/sd remove did not offer DIA-7's choice")
Eq(ns.Diary.IsDiary(GUID), false, "/sd remove did not remove")
Check(ns.Characters.Get(GUID), "'keep history' deleted the character")

SlashCmdList.SOCIALDIARY("remember")
Check(_G.SocialDiaryPickerFrame:IsShown(), "/sd remember did not open the picker")
SlashCmdList.SOCIALDIARY("remember")
Check(not _G.SocialDiaryPickerFrame:IsShown(), "/sd remember did not toggle shut")

-- JNL-4: the bare command is the journal; help is where the usage went.
SlashCmdList.SOCIALDIARY("")
Check(_G.SocialDiaryJournalFrame:IsShown(), "/sd did not open the journal")
SlashCmdList.SOCIALDIARY("")
Check(not _G.SocialDiaryJournalFrame:IsShown(), "/sd did not toggle the journal shut")
SlashCmdList.SOCIALDIARY("help")
SlashCmdList.SOCIALDIARY("who")
SlashCmdList.SOCIALDIARY("observe")
SlashCmdList.SOCIALDIARY("chars")
SlashCmdList.SOCIALDIARY("db")
SlashCmdList.SOCIALDIARY("debug")
ns.Debug("debug line is visible")
SlashCmdList.SOCIALDIARY("debug")
SlashCmdList.SOCIALDIARY("env")

--------------------------------------------------------------------------
Section("the loose entry sheet follows edits")

local LOOSE = "Player-4620-00EEEE05"
ns.Characters.Observe(LOOSE, { first = "Loose", surname = "Leaf" })
ns.Diary.Add(LOOSE, { source = "test" })
Check(ns.UI.ShowEntry(LOOSE), "setup: the sheet did not open")
local sheet = _G.SocialDiaryEntryFrame
Check(sheet:IsShown(), "setup: the sheet is not showing")

-- An edit made somewhere else (the journal's page, a command) reaches
-- the sheet through the journal's refresh.
ns.Diary.SetRelationship(LOOSE, "old friend")
ns.UI.RefreshJournal()
Eq(sheet.form.relationship:GetText(), "old friend", "the sheet did not follow an edit made elsewhere")

-- /sd testdata remove, with the sheet open on Tester Testerson.
ns.TestData.Write()
ns.UI.ShowEntry(ns.TestData.GUID)
Eq(sheet.form.guid, ns.TestData.GUID, "setup: the sheet is not on the test character")
SlashCmdList.SOCIALDIARY("testdata remove")
Check(not sheet:IsShown(), "the sheet stayed open on a deleted entry")

-- Every entry, once each, for the derived views.
local each = 0
for guid, e in ns.Diary.Each() do
    Eq(e, ns.Diary.Get(guid), "Diary.Each handed out another entry")
    each = each + 1
end
Eq(each, ns.Diary.Count(), "Diary.Each missed an entry")

--------------------------------------------------------------------------
Section("added off a sighting, last seen comes along")

-- Characters.Seen only keeps `seen` for diary entries, so someone added off
-- the Recently nearby page has sighting rows and no `seen`. Insert takes it
-- from the rows; nothing is on screen to read it from.
local SIGHTED = "Player-4620-00EEEE06"
ns.Characters.Observe(SIGHTED, { first = "Wren", surname = "Hollow", level = 18 })
local MULGORE = { mapID = 1412, x = 0.3, y = 0.4 }
ns.Sightings.Record(SIGHTED, { source = "plate" }, MULGORE, mock.now - 3 * 3600)
ns.Sightings.Record(SIGHTED, { source = "plate" }, { mapID = 1413, x = 0.5, y = 0.6 }, mock.now - 3600)
ns.Sightings.Record(SIGHTED, { source = "plate" }, { mapID = 1413, x = 0.7, y = 0.8 }, mock.now - 3000)
Eq(ns.Characters.Get(SIGHTED).seen, nil, "setup: a stranger already has `seen`")

ns.Diary.Add(SIGHTED, { source = "nearby", where = { zone = "The Barrens", mapID = 1413, x = 0.5, y = 0.6 } })
local seen = ns.Characters.Get(SIGHTED).seen
Check(seen, "added off a sighting, still not seen nearby")
Eq(seen.time, mock.now - 3000, "last seen is not the latest sighting")
Eq(seen.mapID, 1413, "last seen is not the latest sighting's map")
Eq(seen.x, 0.5, "the place is not where the zone-hour's row began")
Eq(ns.UI.Format.SeenText(seen):match(" in (.+)$"), "The Barrens", "the profile line names no zone")

-- A later `seen` (a trade, a nameplate once in the diary) is not overwritten.
local LATER = "Player-4620-00EEEE07"
ns.Characters.Observe(LATER, { first = "Ash", surname = "Vale" })
ns.Sightings.Record(LATER, { source = "plate" }, MULGORE, mock.now - 7200)
ns.Interactions.Add(LATER, "trade", {})
local traded = ns.Characters.Get(LATER).seen
Check(traded and traded.time == mock.now, "setup: the trade did not set `seen`")
ns.Diary.Add(LATER, { source = "nearby" })
Eq(ns.Characters.Get(LATER).seen.time, mock.now, "an older sighting replaced a newer `seen`")

-- Entries added before the fix: filled at login, once, and not into the map.
local BEFORE = "Player-4620-00EEEE08"
ns.Characters.Observe(BEFORE, { first = "Moss", surname = "Brook" })
ns.Sightings.Record(BEFORE, { source = "plate" }, MULGORE, mock.now - 7200)
ns.Diary.Add(BEFORE, { source = "nearby" })
local record = ns.Characters.Get(BEFORE)
record.seen = nil
local function HeatTotal(r)
    local n = 0
    for _, map in pairs(r.heat or {}) do
        for _, count in pairs(map) do n = n + count end
    end
    return n
end
local heat = HeatTotal(record)
local NEVER = "Player-4620-00EEEE09"
ns.Characters.Observe(NEVER, { first = "Fern", surname = "Glade" })
ns.Diary.Add(NEVER, { source = "chat" })

ns.Diary.FillSeen()
Check(record.seen, "login did not fill an older entry's `seen`")
Eq(record.seen.time, mock.now - 7200, "login filled the wrong time")
Eq(ns.Characters.Get(NEVER).seen, nil, "someone never sighted got a `seen`")
Eq(HeatTotal(record), heat, "filling `seen` counted on the map")
local filled = record.seen
ns.Diary.FillSeen()
Eq(record.seen, filled, "a second login changed `seen`")

--------------------------------------------------------------------------
Section("preset tags in the reader's language, saved in English")

Eq(ns.Diary.TagLabel("foe"), "foe", "an English preset does not read as itself")
Eq(ns.Diary.TagLabel("questing buddy"), "questing buddy", "a custom tag does not read as written")

mock.Reset()
local clientLocale = _G.GetLocale
_G.GetLocale = function() return "deDE" end
ns = T.Boot()
Eq(ns.Locale.id, "deDE", "the diary does not read German")
mock.SetUnit("target", F.STRANGER)
local german = ns.Diary.Add(GUID, { unit = "target" })
Eq(ns.Diary.TagLabel("foe"), "Feind", "a preset not in the reader's language")
Eq(ns.Diary.TagLabel("gilde"), "gilde", "a custom tag was translated")
Check(ns.Diary.AddTag(GUID, "Feind"), "a preset typed in German was not added")
Eq(german.tags[1], "foe", "a preset typed in German was not saved as the preset")
Check(not ns.Diary.AddTag(GUID, "foe"), "the preset was added twice, once per language")
Eq(ns.Diary.TagList({ "foe", "helper", "gilde" }), "Feind, Helfer, gilde", "a tag list not as read")
Eq(#ns.People.Query({ search = "feind" }), 1, "search does not find a preset by its German word")
Eq(#ns.People.Query({ search = "foe" }), 1, "search no longer finds a preset by its English word")
_G.GetLocale = clientLocale
