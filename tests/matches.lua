-- Battleground matches (Core/Matches.lua, Capture/Matches.lua): a match is
-- opened on entering, gathers who was there by name while the board is
-- secret, reads the final board once its GUIDs read, and closes; a diary
-- person in the match is greeted once; three matches in a sitting make an
-- overview; old boards roll up to the diary's people, with warnings first.
-- Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Matches = ns.Matches

local SELF, STRANGER, HOSTILE, GARRICK = F.SELF, F.STRANGER, F.HOSTILE, F.GARRICK

-- The scoreboard, as C_PvP.GetScoreInfo hands it out. `secret` makes the
-- GUIDs and numbers secret, as during play.
local board, secret = {}, true
local function S(v) if secret and v ~= nil then return mock.secret(v) end return v end
_G.Enum = _G.Enum or {}
Enum.PvPMatchState = { Inactive = 0, Waiting = 1, StartUp = 2, Engaged = 3, PostRound = 4, Complete = 5 }
local matchState = 3
local winnerNow
_G.C_PvP = {
    GetScoreInfo = function(i)
        local r = board[i]
        if not r then return nil end
        local stats = {}
        for id, v in pairs(r.stats or {}) do stats[#stats + 1] = { pvpStatID = id, pvpStatValue = S(v) } end
        return { name = r.name, faction = r.faction, raceName = r.race, classToken = r.class,
            guid = S(r.guid), killingBlows = S(r.kb), honorableKills = S(r.hk), deaths = S(r.deaths),
            damageDone = S(r.damage), healingDone = S(r.healing), honorGained = S(99), stats = stats }
    end,
    GetActiveMatchState = function() return matchState end,
    GetActiveMatchWinner = function() return winnerNow end,
    GetActiveMatchDuration = function() return 0 end,
}
_G.GetNumBattlefieldScores = function() return #board end
local asked = 0
_G.RequestBattlefieldScoreData = function() asked = asked + 1 end

local reunions = {}
ns.On("SD_REUNION", function(_, guid, reason) reunions[#reunions + 1] = { guid = guid, reason = reason } end)
local closed = {}
ns.On("SD_MATCH_CLOSED", function(_, m) closed[#closed + 1] = m end)

local function Enter(id, name)
    mock.inInstance, mock.instanceType, mock.instanceName, mock.instanceID = true, "pvp", name, id
    mock.zone = name
    matchState = 3
    mock.fire("ZONE_CHANGED_NEW_AREA")
end

local function Out()
    mock.inInstance, mock.instanceType, mock.instanceName, mock.instanceID = false, "party", "The Deadmines", 36
    mock.zone = "Orgrimmar"
    matchState = 0
    mock.fire("ZONE_CHANGED_NEW_AREA")
end

-- A Warsong board: the user, a diary teammate (Bram), a stranger teammate,
-- and two Alliance players, one of them in the diary by name only.
local function WarsongBoard()
    return {
        { name = "Ulverston Nye", guid = SELF.guid, faction = 0, class = "WARRIOR", race = "Tauren",
            kb = 4, hk = 20, deaths = 2, damage = 30000, healing = 1000, stats = { [42] = 1, [44] = 2 } },
        { name = "Bram Redfen-ClassicBetaPvE", guid = STRANGER.guid, faction = 0, class = "DRUID", race = "Tauren",
            kb = 1, hk = 18, deaths = 3, damage = 9000, healing = 40000, stats = { [42] = 2, [44] = 0 } },
        { name = "Norwood Sparks", guid = "Player-4620-00DDDDDD", faction = 0, class = "WARRIOR", race = "Orc",
            kb = 2, hk = 15, deaths = 5, damage = 20000, healing = 0 },
        { name = "Romulus Lupa", guid = HOSTILE.guid, faction = 1, class = "ROGUE", race = "Human",
            kb = 6, hk = 22, deaths = 1, damage = 41000, healing = 0, stats = { [42] = 1 } },
        { name = "Feivel Ashgrove", guid = "Player-4620-00F0F0F0", faction = 1, class = "PRIEST", race = "Dwarf",
            kb = 0, hk = 10, deaths = 6, damage = 3000, healing = 52000 },
    }
end

T.BlankDiary()
mock.now = 1794069000
mock.zone = "Orgrimmar"
mock.SetUnit("player", SELF)
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
mock.SetUnit("target", STRANGER)
ns.Diary.Add(STRANGER.guid, { source = "test" })
mock.SetUnit("target", HOSTILE)
ns.Diary.Add(HOSTILE.guid, { source = "test" })
mock.SetUnit("target", nil)
Check(ns.Characters.FullName(HOSTILE.guid), "setup: the diary enemy has no name")

--------------------------------------------------------------------------
Section("a player, packed")

do
    local p = { guid = "Player-1-2", name = "Koko Brightwater", side = 1, class = "MAGE", race = "Gnome",
        kb = 3, hk = 0, deaths = 7, damage = 1200, stats = { [44] = 1, [42] = 2 } }
    local s = Matches.Pack(p)
    Eq(s, "Player-1-2;Koko Brightwater;1;MAGE;Gnome;3;0;7;1200;;42:2,44:1", "the packed form changed")
    local back = Matches.Unpack(s)
    Eq(back.name, "Koko Brightwater", "name lost")
    Eq(back.side, 1, "side not a number")
    Eq(back.deaths, 7, "deaths lost")
    Eq(back.healing, nil, "an empty field came back")
    Eq(back.stats[42], 2, "a stat lost")
    local bare = Matches.Unpack(Matches.Pack({ name = "Feivel Ashgrove" }))
    Eq(bare.name, "Feivel Ashgrove", "a name-only row lost its name")
    Eq(bare.guid, nil, "a name-only row gained a GUID")
    Eq(Matches.Pack({ name = "A;B,C" }):find("A;B", 1, true), nil, "a separator got into a field")
end

--------------------------------------------------------------------------
Section("during play: names, not numbers")

board, secret = WarsongBoard(), true
Enter(489, "Warsong Gulch")
local m = Matches.Current()
Check(m, "entering Warsong Gulch opened no match")
Eq(m.map, 489, "the map id")
Eq(m.faction, 0, "the user's side (Horde)")
Eq(m.state, "open", "state while it runs")
Eq(#m.players, 5, "the board's names were not gathered")
for _, p in ipairs(Matches.Players(m)) do
    Eq(p.guid, nil, "a secret GUID was kept: " .. tostring(p.name))
    Eq(p.kb, nil, "a number was kept during play")
end
Check(asked > 0, "the board was never asked for")

-- Greeted: Bram by name; Romulus (in the diary) by name, though his GUID
-- is secret. Once each.
local greetedBram, greetedRomulus = 0, 0
for _, r in ipairs(reunions) do
    Eq(r.reason, "match", "a reunion's reason")
    if r.guid == STRANGER.guid then greetedBram = greetedBram + 1 end
    if r.guid == HOSTILE.guid then greetedRomulus = greetedRomulus + 1 end
end
Eq(greetedBram, 1, "the diary teammate was not greeted once")
Eq(greetedRomulus, 1, "the diary enemy was not greeted once by name")
mock.fire("UPDATE_BATTLEFIELD_SCORE")
ns._test.MatchGather(true)
Eq(#reunions, 2, "a person was greeted twice in one match")

-- An enemy by nameplate: name and level read, GUID and class secret.
mock.SetUnit("nameplate3", F.Like(F.Player{ "Tullus", "Hostilius", faction = "Alliance" },
    { guid = mock.secret("Player-4620-00123456"), class = mock.secret("x") }))
mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
local tullus
for _, p in ipairs(Matches.Players(m)) do if p.name == "Tullus Hostilius" then tullus = p end end
Check(tullus, "an enemy by nameplate was not kept")
Eq(tullus and tullus.side, 1, "the nameplate enemy's side")
Eq(tullus and tullus.guid, nil, "a secret GUID was kept from a nameplate")

-- The user dies.
mock.fire("PLAYER_DEAD")
mock.RunTimers()
Eq(#m.deaths, 1, "the death in the match was not kept")

-- A reload mid-match carries on with the same record.
mock.fire("PLAYER_ENTERING_WORLD", false, true)
mock.RunTimers()
Eq(Matches.Current(), m, "a reload opened a second match")

--------------------------------------------------------------------------
Section("the end: the board read once its GUIDs read")

winnerNow = 0
mock.now = mock.now + 1320
matchState = 5
mock.fire("PVP_MATCH_COMPLETE", mock.secret(0), 1320)   -- the payload's winner secret: read again
Eq(m.winner, 0, "the winner from GetActiveMatchWinner")
Eq(m.duration, 1320, "the duration")
Eq(m.state, "open", "closed before the board was tried")
mock.RunTimers()                 -- first try: still secret
Eq(m.state, "open", "closed on a secret board")
secret = false
for _ = 1, 3 do mock.RunTimers() end
Eq(m.state, "complete", "the readable board did not close the match")
Eq(Matches.Won(m), true, "a Horde win read as lost")
Eq(closed[#closed], m, "SD_MATCH_CLOSED not fired")
local rows = Matches.Players(m)
local byName = {}
for _, p in ipairs(rows) do byName[p.name] = p end
Eq(byName["Bram Redfen"] and byName["Bram Redfen"].guid, STRANGER.guid, "the board's GUID missing")
Eq(byName["Romulus Lupa"] and byName["Romulus Lupa"].kb, 6, "the board's numbers missing")
Eq(byName["Ulverston Nye"] and byName["Ulverston Nye"].stats[44], 2, "stats by id missing")
Check(byName["Tullus Hostilius"], "someone seen but off the board was dropped")
Eq(#rows, 6, "rows after the board")
for _, s in ipairs(m.players) do Check(not s:find("99", 1, true) or s:find("Player", 1, true), "honour kept") end

-- Still inside after the end: a zone change does not open another match.
mock.fire("ZONE_CHANGED_NEW_AREA")
Eq(Matches.Current(), nil, "a match opened after the end")
Out()
Eq(#Matches.All(SELF.guid), 1, "leaving made a record")

--------------------------------------------------------------------------
Section("a board that never reads, and leaving early")

board, secret = WarsongBoard(), true
mock.now = mock.now + 300
Enter(529, "Arathi Basin")
local m2 = Matches.Current()
Check(m2 and m2 ~= m, "the second match did not open")
winnerNow = 1
mock.now = mock.now + 900
mock.fire("PVP_MATCH_COMPLETE", 1, 900)
for _ = 1, 20 do mock.RunTimers() end
Eq(m2.state, "noboard", "a board that never read")
Eq(Matches.Won(m2), false, "an Alliance win read as won")
Eq(#m2.players, 5, "the names from play were lost")
Out()

mock.now = mock.now + 300
Enter(30, "Alterac Valley")
local m3 = Matches.Current()
mock.now = mock.now + 600
Out()
Eq(m3.state, "left", "leaving before the end")
Eq(m3.endedAt, mock.now, "the time it was left")

--------------------------------------------------------------------------
Section("meetings, sessions, the overview")

Eq(Matches.Meetings(HOSTILE.guid, m3, "against"), 3, "Romulus: three matches against")
Eq(Matches.Meetings(STRANGER.guid, m3, "with"), 3, "Bram: three matches with")
Eq(#Matches.For(GARRICK.guid), 0, "someone never met was found")
local sessions = Matches.Sessions(SELF.guid)
Eq(#sessions, 1, "three matches close together made more than one session")
Eq(#sessions[1].matches, 3, "the session's matches")
Eq(Matches.HasOverview(sessions[1]), true, "three matches have no overview")
Eq(Matches.SessionOf(m2).key, m.id, "SessionOf: known by its first match")
Eq(#Matches.Between(SELF.guid, 0, m.startedAt), 0, "Between: before")
Eq(#Matches.Between(SELF.guid, m.startedAt, m.startedAt + 1), 1, "Between: the piece it began in")

-- After a play-session gap, a new session.
mock.now = mock.now + ns.Sittings.GAP + 60
Enter(489, "Warsong Gulch")
Out()
sessions = Matches.Sessions(SELF.guid)
Eq(#sessions, 2, "a gap did not start a new session")
Eq(Matches.HasOverview(sessions[2]), false, "one match has an overview")

--------------------------------------------------------------------------
Section("roll-up and its warnings")

ns.db.settings.battlegroundBoards = 30
Eq(Matches.UntilRollup(), 26, "matches until roll-up")
Eq(Matches.WarningDue(), nil, "a warning above 25")
ns.db.settings.battlegroundBoards = 29
local step, left = Matches.WarningDue()
Eq(step, 25, "the 25 warning")
Eq(left, 25, "matches left")
Matches.Warned(step)
Eq(Matches.WarningDue(), nil, "the 25 warning came twice")
ns.db.settings.battlegroundBoards = 10
Eq((Matches.WarningDue()), 10, "the 10 warning")
Matches.Warned(10)
ns.db.settings.battlegroundBoards = 9
Eq((Matches.WarningDue()), 5, "the 5 warning")
Matches.Warned(5)
ns.db.settings.battlegroundBoards = 7
Eq((Matches.WarningDue()), 3, "the 3 warning")

ns.db.settings.battlegroundBoards = 2
Matches.Rollup()
Eq(m.rolled, true, "the oldest board did not roll up")
Eq(m2.rolled, true, "the second oldest did not roll up")
Eq(m3.rolled, nil, "a board in the newest two rolled up")
local kept = {}
for _, p in ipairs(Matches.Players(m)) do kept[p.name] = true end
Check(kept["Bram Redfen"] and kept["Romulus Lupa"], "a diary person's row rolled away")
Check(kept["Ulverston Nye"], "the user's own row rolled away")
Eq(kept["Norwood Sparks"], nil, "a stranger's row stayed")
Eq(m.lost, 3, "the strangers counted as lost")
Eq(Matches.Meetings(HOSTILE.guid, m3, "against"), 3, "meetings lost to the roll-up")
Eq(Matches.UntilRollup(), 0, "room left after roll-up")
ns.db.settings.battlegroundBoards = 100
Eq(Matches.WarningDue(), nil, "a warning with room again")
Eq(ns.db.meta.matchWarned, nil, "the warnings were not reset with room again")

--------------------------------------------------------------------------
Section("forgetting")

ns.ForgetEverywhere(HOSTILE.guid)
Eq(#Matches.For(HOSTILE.guid), 0, "a forgotten person stayed in a match")
Eq(#Matches.All(SELF.guid), 4, "forgetting someone removed a match")
ns.ForgetEverywhere(nil)
Eq(#Matches.All(), 0, "forgetting everything kept a match")

--------------------------------------------------------------------------
Section("/sd testdata: an evening of four and a lone match left early")

mock.SetUnit("player", SELF)
ns.TestData.Write()
local test = {}
for _, tm in ipairs(Matches.All(SELF.guid)) do if tm.test then test[#test + 1] = tm end end
Eq(#test, 5, "the test matches")
local four
for _, s in ipairs(Matches.Sessions(SELF.guid)) do if #s.matches == 4 then four = s end end
Check(four and Matches.HasOverview(four), "no evening of four with an overview")
local av = four and four.matches[4]
Eq(av and #av.players, 1 + 37 + 39 + 2, "the Alterac's players")
Eq(av and av.map, 30, "the evening's fourth is Alterac")
-- Every test session sits on one piece of the journey.
local recap, rctx = ns.JourneyRecap.For(SELF.guid)
local placed = 0
for _, e in ipairs(recap.entries) do
    for _, p in ipairs(ns.JourneyRecap.Pieces(ns.Journey.For(SELF.guid), e, rctx)) do
        placed = placed + #(p.battlegrounds or {})
    end
end
Eq(placed, #Matches.Sessions(SELF.guid), "a battleground session found no piece of the journey")
ns.TestData.Remove()
for _, tm in ipairs(Matches.All()) do Check(not tm.test, "a test match stayed after remove") end
