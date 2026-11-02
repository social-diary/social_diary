-- The tour's example person (Core/Sample.lua): Thex Theximus written into
-- the diary and taken out again without a trace, the login that clears a
-- leftover copy, and the account migration that marks the tour seen for
-- readers of the old front matter (Core/DB.lua, account schema 2).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Sample = ns.Sample
local GUID = Sample.GUID

-- A deep copy, and the first place two tables differ (nil when equal).
local function Copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[Copy(k)] = Copy(x) end
    return c
end

local function Diff(a, b, path)
    path = path or ""
    if type(a) ~= type(b) then return path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
    if type(a) ~= "table" then
        if a ~= b then return path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
        return nil
    end
    for k, x in pairs(a) do
        local d = Diff(x, b[k], path .. "." .. tostring(k))
        if d then return d end
    end
    for k, y in pairs(b) do
        if a[k] == nil then return path .. "." .. tostring(k) .. ": nil vs " .. tostring(y) end
    end
    return nil
end

-- What the addon said in chat while `fn` ran.
local function Said(fn)
    local said, add = {}, DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = tostring(msg) end
    local ok, err = pcall(fn)
    DEFAULT_CHAT_FRAME.AddMessage = add
    assert(ok, err)
    return said
end

local function Kinds(list)
    local out = {}
    for i, item in ipairs(list) do out[i] = item.kind end
    return table.concat(out, ",")
end

--------------------------------------------------------------------------
Section("a real-looking person, already in the diary")

mock.SetUnit("target", F.STRANGER)
ns.Interactions.Add(F.STRANGER.guid, "trade", { context = { given = { { link = "[Linen Cloth]", count = 2 } } } })
ns.Diary.Add(F.STRANGER.guid, { unit = "target", source = "test", note = "met at the well" })
mock.SetUnit("target", nil)
ns.Sessions.Close(ns.Sessions.Current(), mock.now)
Check(ns.Diary.IsDiary(F.STRANGER.guid), "the real person was not added")
Eq(Sample.Present(), false, "Thex is there before the tour")

local beforeAccount, beforeChar = Copy(SocialDiaryDB), Copy(SocialDiaryCharDB)
local stranger = Copy(ns.db.characters[F.STRANGER.guid])

--------------------------------------------------------------------------
Section("Write: Thex in the diary, quietly")

Eq(Sample.GUID, "Player-0000-7E5A3E01", "Thex's GUID")
Eq(Sample.NAME, "Thex Theximus", "Thex's name")

local entry
local said = Said(function() entry = Sample.Write(mock.now) end)
Check(entry, "Write wrote no entry")
Eq(#said, 0, "Write said something in chat: " .. tostring(said[1]))
Eq(Sample.Present(), true, "Present after Write")
Eq(ns.Diary.IsDiary(GUID), true, "Thex is not in the diary")
Eq(ns.Characters.FullName(GUID), "Thex Theximus", "Thex's name on his record")

local record = ns.Characters.Get(GUID)
Eq(record.class, "HUNTER", "class")
Eq(record.race, "Troll", "race")
Eq(record.level, 12, "level")
Eq(record.faction, "Horde", "faction")
Eq(record.sex, 2, "sex")
Eq(record.seen, nil, "a 'last seen' was written for him")
Eq(record.heat, nil, "heat was written for him")

Eq(entry.sample, true, "the entry is not marked")
Eq(entry.addedAt, mock.now, "not added just now")
Eq(entry.addedContext.source, "sample", "the entry's source")
Eq(entry.addedContext.zone, "Mulgore", "added where the player stands")
Eq(entry.note, nil, "the entry has a note")
Eq(#entry.tags, 0, "the entry has tags")

-- On the People list, found by his name.
local found = ns.People.Query({ search = "theximus" })
Eq(#found, 1, "the People search for his name")
Eq(found[1].guid, GUID, "the People search found someone else")
Check(ns.People.Index()[GUID], "Thex is not in the People index")
Check(ns.People.Index()[F.STRANGER.guid], "the real person left the People index")

-- His rows: one questing session today, a trade and a rare inside it, a
-- whisper after.
local sessions = ns.Sessions.For(GUID)
Eq(#sessions, 1, "sessions together")
local s = sessions[1]
Eq(s.sample, true, "the session is not marked")
Eq(s.endedAt - s.startedAt, 35 * 60, "the session's length")
Eq(s.zones[1], Sample.ZONE, "the session's zone")
Check(s.endedAt <= mock.now, "the session ends in the future")
Eq(ns.DayStart(s.startedAt), ns.DayStart(mock.now), "the session is not today")
Check(ns.db.meta.openSession ~= s.id, "the sample session is the open one")
local p = s.participants[GUID]
Eq(#p.rares, 1, "the rare killed together")
Check(#p.quests > 0, "no quests: not a questing session")

local rows = ns.Interactions.For(GUID)
Eq(#rows, 2, "Thex's rows")
Eq(rows[1].type, "trade", "the first row")
Eq(rows[1].session, s.id, "the trade is not inside the session")
Eq(rows[1].context.received[1].count, 5, "the linen's count")
Check(rows[1].context.received[1].link:find("Linen Cloth", 1, true), "the linen's link")
Eq(rows[2].type, "whisper_in", "the second row")
Eq(rows[2].excerpt, "thanks for the help", "the whisper's words")
Eq(rows[2].session, nil, "the whisper is inside the session")
Eq(rows[1].sample and rows[2].sample, true, "the rows are not marked")

local tl = ns.Timeline.For(GUID)
Eq(Kinds(tl), "added,row,session", "his timeline")
Eq(tl[2].row.type, "whisper_in", "the timeline's whisper")
local episode = tl[3]
local acts = Copy(episode.activities)
table.sort(acts)
Eq(table.concat(acts, ","), "quest,rare,trade", "the session's activities")
local inside = {}
for _, child in ipairs(episode.all) do inside[#inside + 1] = child.kind end
table.sort(inside)
Eq(table.concat(inside, ","), "rare,row", "inside the session")

--------------------------------------------------------------------------
Section("Write twice is the same as once")

local first = Copy(SocialDiaryCharDB)
local nextId = ns.db.meta.nextSessionId
said = Said(function() Sample.Write(mock.now) end)
Eq(#said, 0, "the second Write said something")
Eq(#ns.Sessions.For(GUID), 1, "a second Write left two sessions")
Eq(#ns.Interactions.For(GUID), 2, "a second Write left more rows")
Eq(ns.db.meta.nextSessionId, nextId, "a second Write moved the session counter")
Eq(Diff(first, Copy(SocialDiaryCharDB)), nil, "a second Write changed the saved data")

--------------------------------------------------------------------------
Section("Remove: everything back as it was")

said = Said(function() Eq(Sample.Remove(), true, "Remove did not find him") end)
Eq(#said, 0, "Remove said something in chat")
Eq(Sample.Present(), false, "Present after Remove")
Eq(ns.Diary.IsDiary(GUID), false, "still in the diary")
Eq(ns.db.characters[GUID], nil, "his record stayed")
Eq(ns.db.interactions[GUID], nil, "his rows stayed")
for _, session in pairs(ns.db.sessions) do Check(not session.sample, "a sample session stayed") end
Eq(#ns.People.Query({ search = "theximus" }), 0, "still on the People list")
Eq(Diff(beforeChar, Copy(SocialDiaryCharDB)), nil, "the character file changed")
Eq(Diff(beforeAccount, Copy(SocialDiaryDB)), nil, "the account file changed")
Eq(Diff(stranger, ns.db.characters[F.STRANGER.guid]), nil, "the real person's record changed")
Eq(Sample.Remove(), false, "a second Remove found him")

-- Another session opened meanwhile: his are gone, the counter stays put.
Sample.Write(mock.now)
local other = ns.Sessions.New({ startedAt = mock.now - 60, endedAt = mock.now,
    participants = { [F.STRANGER.guid] = { since = mock.now - 60, last = mock.now, seconds = 60 } } })
local counter = ns.db.meta.nextSessionId
Sample.Remove()
Eq(ns.db.meta.nextSessionId, counter, "the counter went back under another session")
Check(ns.db.sessions[other.id], "the other session went with him")
ns.db.sessions[other.id] = nil

--------------------------------------------------------------------------
Section("a login clears a leftover Thex")

Sample.Write(mock.now)
Check(Sample.Present(), "the leftover was not written")
-- As saved at a /reload mid-tour, then loaded again.
local savedAccount, savedChar = Copy(SocialDiaryDB), Copy(SocialDiaryCharDB)
mock.Reset()
_G.SocialDiaryDB, _G.SocialDiaryCharDB = savedAccount, savedChar
ns = T.Load()
mock.SetUnit("player", F.SELF)
said = Said(function() mock.fire("ADDON_LOADED", ns.addonName) end)
Eq(ns.Sample.Present(), false, "the leftover survived the load")
Eq(SocialDiaryCharDB.data.diary[GUID], nil, "the leftover entry stayed saved")
Eq(#said, 0, "the cleanup said something")
mock.fire("PLAYER_LOGIN")
Check(ns.Diary.IsDiary(F.STRANGER.guid), "the real person went with him")
Eq(#ns.People.Query({ search = "theximus" }), 0, "on the People list after login")

--------------------------------------------------------------------------
Section("account schema 2: introSeen from frontRead")

local Migrate, Steps = ns._test.Migrate, ns._test.AccountSteps
Eq(SocialDiaryDB.schema, 2, "the account file's version")
Eq(ns.IsAccountSetting("introSeen"), true, "introSeen is per character")
Eq(ns.SettingDefault("introSeen"), false, "introSeen's default")

local read = { schema = 1, settings = { frontRead = true, introDone = true } }
Migrate(read, 2, Steps)
Eq(read.schema, 2, "the version was not bumped")
Eq(read.settings.introSeen, true, "a reader of the front matter is offered the tour again")
Eq(read.settings.frontRead, true, "frontRead was not kept")
Eq(read.settings.introDone, true, "introDone was not kept")

local unread = { schema = 1, settings = { frontRead = false, introDone = false } }
Migrate(unread, 2, Steps)
Eq(unread.settings.introSeen, nil, "introSeen set for someone who never read the front matter")
Eq(unread.settings.frontRead, false, "frontRead was not kept")
Eq(unread.settings.introDone, false, "introDone was not kept")

local bare = { schema = 1 }
Migrate(bare, 2, Steps)
Eq(bare.schema, 2, "a file without settings was not bumped")
Eq(bare.settings, nil, "a file without settings got some")

-- Through a whole load: an old account file comes back with the tour seen,
-- or not, and its old keys as they were.
for _, case in ipairs({ { true, true }, { false, false }, { nil, false } }) do
    mock.Reset()
    _G.SocialDiaryDB = { schema = 1, settings = { frontRead = case[1], introDone = true }, own = {} }
    _G.SocialDiaryCharDB = nil
    ns = T.Load()
    mock.SetUnit("player", F.SELF)
    mock.fire("ADDON_LOADED", ns.addonName)
    local what = " (frontRead " .. tostring(case[1]) .. ")"
    Eq(SocialDiaryDB.schema, 2, "the account file was not migrated" .. what)
    Eq(ns.Setting("introSeen"), case[2], "introSeen after the load" .. what)
    Eq(SocialDiaryDB.settings.frontRead, case[1] == true, "frontRead after the load" .. what)
    Eq(SocialDiaryDB.settings.introDone, true, "introDone after the load" .. what)
end

-- A new account file is current already: the tour not yet seen.
mock.Reset()
_G.SocialDiaryDB, _G.SocialDiaryCharDB = nil, nil
ns = T.Load()
mock.SetUnit("player", F.SELF)
mock.fire("ADDON_LOADED", ns.addonName)
Eq(SocialDiaryDB.schema, 2, "a new account file's version")
Eq(ns.Setting("introSeen"), false, "a new player has seen the tour")
