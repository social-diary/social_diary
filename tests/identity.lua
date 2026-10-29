-- Who is who: the first load, GUIDs, names, the character store, secrets,
-- the user's position, and the one check that turns a unit token into a
-- nearby player.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local STRANGER, SELF = F.STRANGER, F.SELF

--------------------------------------------------------------------------
Section("bootstrap")

local ns = T.Load()
mock.SetUnit("player", SELF)

mock.fire("ADDON_LOADED", "some_other_addon")
Check(ns.db == nil, "DB initialised for the wrong addon")

mock.fire("ADDON_LOADED", "social_diary")
Check(ns.db and ns.db.schema == 5, "DB not initialised")
Eq(ns.dbRestored, false, "an empty first load reported as restored")

-- The whole point of the flag: a load that did get its data back says so, so
-- that this build's failure to restore on /reload is never silent again.
local account, character = _G.SocialDiaryDB, _G.SocialDiaryCharDB
_G.SocialDiaryCharDB = { data = { schema = 4, characters = { ["Player-1-2"] = {} } } }
ns.InitDB()
Eq(ns.dbRestored, true, "a load with saved data reported as empty")
Check(ns.db.characters["Player-1-2"] ~= nil, "the character's own diary was not loaded")
_G.SocialDiaryDB, _G.SocialDiaryCharDB = account, character
ns.InitDB()

--------------------------------------------------------------------------
Section("version numbers, for migrations")

-- Each file and the diary in use carry their own number.
Eq(_G.SocialDiaryDB.schema, 1, "the account file has no version")
Eq(_G.SocialDiaryCharDB.schema, 2, "the per-character file has no version")
Eq(_G.SocialDiaryCharDB.data.schema, 5, "the diary has no version")

-- The steps: oldest first, each once, on the table as saved.
local Migrate, ran = ns._test.Migrate, {}
local steps = {
    [3] = function(t) ran[#ran + 1] = 3; t.renamed, t.old = t.old, nil end,
    [4] = function(t) ran[#ran + 1] = 4 end,
}
local t = { schema = 2, old = "kept" }
Migrate(t, 4, steps)
Eq(table.concat(ran, ","), "3,4", "the steps did not run oldest first")
Eq(t.schema, 4, "the version was not bumped")
Eq(t.renamed, "kept", "a step did not see the table as saved")
Migrate(t, 4, steps)
Eq(#ran, 2, "a step ran twice")
local new = {}
Migrate(new, 4, steps)
Eq(#ran, 2, "a new table was migrated")
Eq(new.schema, 4, "a new table is not current")

--------------------------------------------------------------------------
Section("one diary per character, or one shared (DAT-1)")

-- Each character's own diary, by default, in the per-character file.
Eq(ns.diaryShared, false, "the diary is shared by default")
Eq(ns.db.diary, _G.SocialDiaryCharDB.data.diary, "the diary is not the character's own file")
Eq(_G.SocialDiaryDB.shared, nil, "a shared diary was made without sharing")

-- Settings: the account's few in the account file, the rest per character.
Eq(ns.IsAccountSetting("frontRead"), true, "frontRead is per character")
Eq(ns.IsAccountSetting("toasts"), false, "toasts is account-wide")
ns.db.settings.frontRead = true
ns.db.settings.toasts = false
Eq(_G.SocialDiaryDB.settings.frontRead, true, "an account setting was not written to the account file")
Eq(_G.SocialDiaryCharDB.settings.frontRead, nil, "an account setting was written per character")
Eq(_G.SocialDiaryCharDB.settings.toasts, false, "a character setting was not written per character")
Eq(_G.SocialDiaryDB.settings.toasts, nil, "a character setting was written to the account file")
Eq(ns.Setting("toasts"), false, "a character setting does not read back")
Eq(ns.SettingDefault("toasts"), true, "a character setting's default")
Eq(ns.SettingDefault("shareDiary"), false, "the shared diary is the default")
Check(getmetatable(_G.SocialDiaryDB) == nil and getmetatable(_G.SocialDiaryCharDB) == nil
    and getmetatable(_G.SocialDiaryCharDB.settings) == nil, "a metatable reached a saved table")
ns.db.settings.toasts = true

-- Sharing: the next load reads the shared diary, and the character's own
-- is kept as it was, for when sharing goes off again. Nothing is copied.
ns.db.characters["Player-1-3"] = { guid = "Player-1-3" }
ns.ShareDiary(true)
Eq(ns.diaryShared, false, "sharing took effect before the next load")
ns.InitDB()
Eq(ns.diaryShared, true, "sharing was not loaded")
Eq(ns.db.diary, _G.SocialDiaryDB.shared.diary, "the diary is not the shared one")
Eq(ns.db.characters["Player-1-3"], nil, "the shared diary began with the character's records")
Check(_G.SocialDiaryCharDB.data.characters["Player-1-3"], "the character's own diary went when sharing")
Eq(ns.db.settings.frontRead, true, "an account setting was lost when sharing")
ns.ShareDiary(false)
ns.InitDB()
Check(ns.db.characters["Player-1-3"], "the character's own diary did not come back")
ns.db.characters["Player-1-3"] = nil

-- The account file from before schema 4 was the one diary: it is kept as
-- the shared one, the user's own characters stay account-wide.
_G.SocialDiaryDB = { schema = 3, characters = { ["Player-1-4"] = {} }, diary = {},
    settings = { toasts = false, frontRead = true },
    meta = { characters = { [SELF.guid] = { first = "Old" } } } }
_G.SocialDiaryCharDB = nil
ns.InitDB()
Eq(ns.diaryShared, false, "an old file turned sharing on")
Eq(next(ns.db.characters), nil, "the character's own diary did not start empty")
Check(_G.SocialDiaryDB.shared and _G.SocialDiaryDB.shared.characters["Player-1-4"],
    "the old diary was not kept as the shared one")
Eq(_G.SocialDiaryDB.diary, nil, "the old diary was left loose in the account file")
Eq(_G.SocialDiaryDB.schema, 1, "the old account file did not get its own version")
Eq(_G.SocialDiaryDB.shared.schema, 3, "the old diary's version was not kept for its next load")
Eq(ns.OwnCharacters()[SELF.guid].first, "Old", "the user's own characters were lost")
Eq(_G.SocialDiaryDB.shared.settings, nil, "the old settings were kept in the shared diary")
_G.SocialDiaryDB, _G.SocialDiaryCharDB = account, character
ns.InitDB()

mock.fire("PLAYER_LOGIN")
Eq(ns.ownGUID, SELF.guid, "own character not recorded")
Check(ns.OwnCharacters()[SELF.guid], "own character missing from meta")

-- Build 70009 stored the surname as the realm; the record is normalized now.
local me = ns.OwnCharacters()[SELF.guid]
Eq(me.first, "Ulverston", "own first name")
Eq(me.surname, "Nye", "own surname")
Eq(me.realm, "Classic Beta PvE", "own realm is the realm, not the surname")

--------------------------------------------------------------------------
Section("GUIDs")

Check(ns.SafeGUID("Player-4620-00B0B0B0"), "player GUID rejected")
Check(not ns.SafeGUID("Creature-0-4620-1-6-3098-00002C5F0C"), "creature GUID accepted")
Check(not ns.SafeGUID(nil), "nil GUID accepted")
Check(not ns.SafeGUID(mock.secret("Player-1-2")), "secret GUID accepted")
Eq(ns.SafeGUID(mock.secret("Player-1-2")), nil, "secret GUID survived SafeGUID")
Eq(ns.SafeGUID("Player-4620-00B0B0B0"), "Player-4620-00B0B0B0", "plain GUID lost")

--------------------------------------------------------------------------
Section("name normalization (NAM-1)")

local function Name(a, b)
    local first, surname = ns.NormalizeName(a, b)
    return tostring(first) .. "/" .. tostring(surname)
end

Eq(Name("Bram", "Redfen"), "Bram/Redfen", "UnitName for a stranger")
Eq(Name("Ulverston Nye"), "Ulverston/Nye", "UnitName for the user's own character")
Eq(Name("Bram Redfen"), "Bram/Redfen", "joined chat sender")
Eq(Name("Ulverston Nye", "ClassicBetaPvE"), "Ulverston/Nye", "UnitFullName drops the realm")
Eq(Name("Bram", "ClassicBetaPvE2"), "Bram/nil", "GetPlayerInfoByGUID realm with an index")
Eq(Name("Bram", "Classic Beta PvE"), "Bram/nil", "realm with spaces")
Eq(Name("Ulverston", ""), "Ulverston/nil", "empty surname")
Eq(Name("Bram-ClassicBetaPvE"), "Bram/nil", "Name-Realm suffix")
Eq(Name("Bram Redfen-ClassicBetaPvE"), "Bram/Redfen", "joined name with a realm suffix")
Eq(Name("Unknown"), "nil/nil", "placeholder name stored")
Eq(Name(nil), "nil/nil", "nil name")
Eq(Name(""), "nil/nil", "empty name")
Eq(Name(mock.secret("Bram"), mock.secret("Redfen")), "nil/nil", "secret name survived")
Eq(Name("Bram", mock.secret("Redfen")), "Bram/nil", "secret surname survived")

Eq(ns.JoinName("Bram", "Redfen"), "Bram Redfen", "join")
Eq(ns.JoinName("Bram", nil), "Bram", "join without a surname")
Eq(ns.JoinName(nil, "Redfen"), nil, "join without a first name")

Check(ns.IsRealmName("ClassicBetaPvE"), "realm not recognised")
Check(ns.IsRealmName("Classic Beta PvE"), "realm with spaces not recognised")
Check(not ns.IsRealmName("Redfen"), "surname mistaken for a realm")

--------------------------------------------------------------------------
Section("reading names off units")

mock.SetUnit("target", STRANGER)
Eq(ns.JoinName(ns.NameFromUnit("target")), "Bram Redfen", "stranger's name")
Eq(ns.JoinName(ns.NameFromUnit("player")), "Ulverston Nye", "own name")
Eq(ns.NameFromUnit("focus"), nil, "name from a unit that does not exist")

local info = ns.InfoFromGUID(STRANGER.guid)
Eq(info.first, "Bram", "first name from GUID")
Eq(info.surname, nil, "GetPlayerInfoByGUID must not yield a surname")
Eq(info.class, "DRUID", "class from GUID")

--------------------------------------------------------------------------
Section("character store")

local record = ns.Characters.ObserveUnit("target")
Check(record, "target not observed")
Eq(record.guid, STRANGER.guid, "wrong GUID stored")
Eq(ns.Characters.FullName(STRANGER.guid), "Bram Redfen", "stored name")
Eq(record.class, "DRUID", "class token not stored")
Eq(record.classID, 11, "class id not stored")
Eq(record.race, "Tauren", "race token not stored")
Eq(record.faction, "Horde", "faction not stored")
Eq(record.level, 1, "level not stored")
Eq(record.sex, 2, "sex not stored")
Eq(#record.names, 1, "name history should have one entry")
Eq(record.firstSeen, mock.now, "firstSeen not set")
Eq(ns.Diary.IsDiary(record.guid), false, "nobody enters the diary on their own (DIA-1)")

-- DIA-9: a rename appends rather than overwrites.
mock.now = mock.now + 3600
mock.SetUnit("target", F.Like(STRANGER, { name = { "Bram", "Redfenn" }, level = 4 }))
record = ns.Characters.ObserveUnit("target")
Eq(#record.names, 2, "rename not recorded")
Eq(ns.Characters.FullName(STRANGER.guid), "Bram Redfenn", "newest name not returned")
Eq(record.names[1].surname, "Redfen", "old name lost")
Eq(record.level, 4, "level not updated")
Eq(record.firstSeen, mock.now - 3600, "firstSeen moved")
Eq(record.lastSeen, mock.now, "lastSeen not updated")

-- Seeing them again unchanged must not grow the history.
record = ns.Characters.ObserveUnit("target")
Eq(#record.names, 2, "unchanged name appended to the history")

-- A first-name-only read is an incomplete read, not a rename: every player in
-- this build has a surname (Session 2). GetPlayerInfoByGUID is the only
-- identity source when there is no unit token, so this path is common.
ns.Characters.ObserveGUID(STRANGER.guid)
Eq(#record.names, 2, "a first-name-only read was recorded as a rename")
Eq(ns.Characters.FullName(STRANGER.guid), "Bram Redfenn", "a first-name-only read erased the surname")

-- A thin source must not blank what a richer one knew.
ns.Characters.Observe(STRANGER.guid, { first = "Bram", surname = "Redfenn" })
Eq(record.level, 4, "level blanked by a source that could not read it")
Eq(record.class, "DRUID", "class blanked by a thinner source")

-- DAT-1: the user's own alts are marked when they turn up in a roster.
local own = ns.Characters.ObserveUnit("player")
Eq(own.isSelf, true, "own character not marked")
Eq(ns.Characters.Get(STRANGER.guid).isSelf, nil, "stranger marked as self")

Eq(ns.Characters.Get("Creature-0-4620-1-6-3098-1"), nil, "creature GUID got a record")
Eq(ns.Characters.Observe(mock.secret("Player-1-2"), {}), nil, "secret GUID got a record")
Eq(ns.Characters.Count(), 2, "unexpected number of characters")

-- The no-unit-token path (DIA-2a): a GUID alone still yields a record.
mock.SetUnit("nobody", F.Player{ guid = "Player-4620-00999999", "Garrick", "Fallow",
    class = "MAGE", race = "Tauren", sex = 2 })
mock.units.nobody = nil  -- registered by GUID only, no unit token
record = ns.Characters.ObserveGUID("Player-4620-00999999")
Eq(ns.Characters.FullName("Player-4620-00999999"), "Garrick", "first name from a bare GUID")
Eq(record.class, "MAGE", "class from a bare GUID")
Eq(record.level, nil, "a bare GUID cannot know a level")

-- ... and the first full read fills in the placeholder rather than appending.
local UPGRADE = "Player-4620-00AAAAAA"
local full = F.Player{ guid = UPGRADE, "Mad", "Claw",
    class = "DRUID", race = "Tauren", sex = 2, level = 12, faction = "Horde" }
mock.SetUnit("upgrade", full)
mock.units.upgrade = nil                      -- on record by GUID only, so far

ns.Characters.ObserveGUID(UPGRADE)
Eq(ns.Characters.FullName(UPGRADE), "Mad", "a bare GUID yielded more than a first name")

mock.units.upgrade = full                     -- now there is a unit token
record = ns.Characters.ObserveUnit("upgrade")
Eq(#record.names, 1, "the placeholder was appended to instead of filled in")
Eq(ns.Characters.FullName(UPGRADE), "Mad Claw", "placeholder not upgraded")
Eq(record.level, 12, "level not picked up by the fuller read")

--------------------------------------------------------------------------
Section("secret safety (NFR-4, INT-5)")

-- Written out rather than F.Like(STRANGER): with no UnitFullName to fall
-- back on, a secret UnitName leaves nothing readable.
mock.SetUnit("target", {
    guid = mock.secret("Player-4620-00B0B0B0"),
    name = { mock.secret("Bram"), mock.secret("Redfen") },
    class = STRANGER.class, race = STRANGER.race,
    sex = 2, level = 1, faction = STRANGER.faction,
})
Eq(ns.Characters.ObserveUnit("target"), nil, "a secret GUID produced a record")

mock.SetUnit("target", {
    guid = "Player-4620-00570A8F",
    name = { mock.secret("Bram"), mock.secret("Redfen") },
    class = STRANGER.class, race = STRANGER.race,
    sex = 2, level = mock.secret(1), faction = STRANGER.faction,
})
record = ns.Characters.ObserveUnit("target")
Check(record, "a readable GUID with a secret name should still be recorded")
Eq(#record.names, 0, "a secret name was stored")
Eq(ns.Characters.FullName("Player-4620-00570A8F"), nil, "a secret name came back out")
Eq(record.level, nil, "a secret level was stored")
Eq(record.class, "DRUID", "the plain fields were dropped along with the secret ones")

--------------------------------------------------------------------------
Section("location")

local where = ns.Where()
Eq(where.zone, "Mulgore", "zone")
Eq(where.mapID, 1412, "map id")
Eq(where.x, 0.421, "x rounded")
Eq(where.y, 0.616, "y rounded")

mock.inInstance = true
where = ns.Where()
Eq(where.zone, "The Deadmines", "instance name as the zone")
Eq(where.instanceID, 36, "instance id")
Eq(where.mapID, nil, "coordinates stored inside an instance")
mock.inInstance = false

-- A loading screen: the zone texts are "", which is no name at all.
local zone = mock.zone
mock.zone = ""
Eq(ns.Where().zone, nil, "an empty zone text kept as a zone")
mock.inInstance, mock.instanceName = true, ""
mock.zone = "Westfall"
Eq(ns.Where().zone, "Westfall", "an empty instance name hid the zone text")
mock.inInstance, mock.instanceName = false, "The Deadmines"
mock.zone = zone

--------------------------------------------------------------------------
Section("unit tokens to GUIDs: one visible-player check")

local V = { visible = true }
local NEAR = F.Player{ guid = "Player-4620-00EEEE01", "Near", "By", level = 10 }
local FAR = F.Player{ guid = "Player-4620-00EEEE02", "Far", "Off", level = 10, visible = false }

mock.ClearUnits()
mock.SetUnit("player", SELF)
mock.SetUnit("target", NEAR)
mock.SetUnit("mouseover", FAR)
mock.SetUnit("focus", { guid = mock.secret("Player-4620-00EEEE03"), name = { "Hidden" } })
mock.SetUnit("nameplate3", { guid = "Creature-0-4170-1-35-3035-00002", name = { "Kodo" }, isPlayer = false })

Eq(ns.PlayerGUIDFromUnit("target", V), NEAR.guid, "a drawn player")
Eq(ns.PlayerGUIDFromUnit("mouseover"), FAR.guid, "an undrawn player, visibility not asked for")
Eq(ns.PlayerGUIDFromUnit("mouseover", V), nil, "an undrawn player counted as visible")
Eq(ns.PlayerGUIDFromUnit("focus"), nil, "a secret GUID")
Eq(ns.PlayerGUIDFromUnit("nameplate3"), nil, "an NPC")
Eq(ns.PlayerGUIDFromUnit("player"), nil, "the user")
Eq(ns.PlayerGUIDFromUnit("player", { includeSelf = true }), SELF.guid, "the user, with includeSelf")
Eq(ns.PlayerGUIDFromUnit("party3"), nil, "an empty token")
Eq(ns.PlayerGUIDFromUnit(nil), nil, "no token at all")

-- SES-2: a party frame's mouseover across the map does not keep a
-- together session going; the same person drawn nearby does.
ns.Characters.Observe(FAR.guid, { first = "Far", surname = "Off" })
ns.Diary.Add(FAR.guid, { source = "test" })
local session = ns.Sessions.Together(FAR.guid, "nearby", true)
local p = session.participants[FAR.guid]
local started = mock.now

mock.now = mock.now + 300
ns._test.TogetherTick()
Eq(p.last, started, "an undrawn mouseover counted as together")
FAR.visible = nil
ns._test.TogetherTick()
Eq(p.last, mock.now, "a drawn mouseover did not count as together")
