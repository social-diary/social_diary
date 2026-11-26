-- World PvP (Features/WorldPvP/): kills by the user and by their group, the
-- user killed by a player, guessed and then corrected by the recap; the
-- timeline's lines, the profile's sentence and the foe's reunion card.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()

local SELF, HOSTILE, STRANGER = F.SELF, F.HOSTILE, F.STRANGER
local FOE = HOSTILE.guid

local recaps = {}
_G.C_DeathRecap = {
    GetRecapEvents = function(id) return recaps[id or "latest"] end,
}

local function Blow(source, name, at, spell)
    return { { sourceGUID = source, sourceName = name, destGUID = SELF.guid, timestamp = at,
        event = "SPELL_DAMAGE", spellName = spell, amount = 300, overkill = 12 } }
end

-- Every fight line on someone's profile, newest first.
local function Lines(guid)
    local lines = {}
    local function Walk(items)
        for _, item in ipairs(items) do
            if item.kind == "row" and item.row.type:find("^pvp_") then
                local _, text = ns.UI.DescribeItem(item, guid)
                lines[#lines + 1] = text
            end
            if item.all then Walk(item.all) end
        end
    end
    Walk(ns.Timeline.For(guid))
    return lines
end

local function Plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

T.BlankDiary()
ns._test.SettleGroup()
ns.Characters.Observe(STRANGER.guid, { first = "Bram", surname = "Redfen", level = 12 })
mock.now = 1792000000
mock.zone = "Hillsbrad Foothills"
mock.RunTimers()

--------------------------------------------------------------------------
Section("kills: yours and your group's")

-- A stranger you kill goes into the buffer, like any interaction.
mock.SetUnit("target", HOSTILE)
mock.fire("PARTY_KILL", SELF.guid, FOE)
Eq(T.Rows(FOE, "pvp_kill"), 1, "your kill was not written down")
Check(ns.Characters.Get(FOE), "the victim was not observed")
Eq(ns.Characters.Get(FOE).faction, "Alliance", "read off the target while it pointed at them")
local f = ns.Interactions.Fights(FOE)
Eq(f.kills, 1, "kills")
Eq(f.yours, 1, "your own kills")

-- A kill by someone in your group counts as well, and remembers whose blow.
ns.Diary.Add(STRANGER.guid, { source = "test" })
mock.groupSize = 2
mock.SetUnit("party1", STRANGER)
mock.fire("GROUP_ROSTER_UPDATE")
mock.now = mock.now + 600
mock.fire("PARTY_KILL", STRANGER.guid, FOE)
f = ns.Interactions.Fights(FOE)
Eq(f.kills, 2, "a group member's kill did not count")
Eq(f.yours, 1, "a group member's kill counted as yours")

-- Not a fight: a kill by someone outside the group, a kill of a group
-- member, a creature, the user.
mock.fire("PARTY_KILL", F.PUG.guid, FOE)
mock.fire("PARTY_KILL", SELF.guid, STRANGER.guid)
mock.fire("PARTY_KILL", SELF.guid, "Creature-0-4620-1-6-2955-00002C5F0D")
mock.fire("PARTY_KILL", STRANGER.guid, SELF.guid)
Eq(ns.Interactions.Fights(FOE).kills, 2, "a kill by an outsider counted")
Eq(ns.Interactions.Fights(STRANGER.guid), nil, "killing a group member is a fight")

-- Battlegrounds and arenas are not the open world.
local isInInstance = _G.IsInInstance
_G.IsInInstance = function() return true, "pvp" end
mock.fire("PARTY_KILL", SELF.guid, FOE)
_G.IsInInstance = isInInstance
Eq(ns.Interactions.Fights(FOE).kills, 2, "a battleground kill counted")

mock.groupSize = 0
mock.SetUnit("party1", nil)
mock.fire("GROUP_ROSTER_UPDATE")

--------------------------------------------------------------------------
Section("killed by a player: the guess, then the recap")

-- At the moment of death your target is the guess, written down at once.
mock.now = mock.now + 600
mock.inCombat = true
mock.SetUnit("target", HOSTILE)
mock.fire("PLAYER_DEAD")
Eq(T.Rows(FOE, "pvp_death"), 1, "the guessed killer was not written down")
local row = ns._test.LatestInteraction(FOE, "pvp_death")
Eq(row.context.probable, true, "a guess not marked probable")

-- The recap agrees: confirmed, with the spell.
recaps.latest = Blow(FOE, "Romulus", mock.now, "Ambush")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(row.context.probable, nil, "the recap did not confirm the guess")
Eq(row.context.spell, "Ambush", "the killing spell")
Eq(ns.Interactions.Fights(FOE).deaths, 1, "deaths")

-- The recap names somebody else: the death moves to them.
local OTHER = F.STRANGER2.guid
mock.now = mock.now + 600
mock.inCombat = true
mock.fire("PLAYER_DEAD")
Eq(ns.Interactions.Fights(FOE).deaths, 2, "the second guess")
recaps.latest = Blow(OTHER, "Tullus", mock.now, "Fireball")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(ns.Interactions.Fights(FOE).deaths, 1, "the wrong guess was kept")
Eq(ns.Interactions.Fights(OTHER).deaths, 1, "the death did not move to the recap's killer")

-- The recap names a creature: no player killed you, and the guess goes.
mock.now = mock.now + 600
mock.inCombat = true
mock.fire("PLAYER_DEAD")
recaps.latest = Blow("Creature-0-4620-1-6-2955-00002C5F0D", "Plainstrider", mock.now)
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(ns.Interactions.Fights(FOE).deaths, 1, "a creature's kill stayed on the guessed player")

-- No guess at the moment, but the recap names a player: written down then.
mock.SetUnit("target", nil)
mock.now = mock.now + 600
mock.fire("PLAYER_DEAD")
recaps.latest = Blow(FOE, "Romulus", mock.now, "Backstab")
mock.fire("PLAYER_REGEN_ENABLED")
Eq(ns.Interactions.Fights(FOE).deaths, 2, "a recap-only player kill was lost")

-- The ganker is offered for the diary (flow 5), in words.
local offered
for _, c in ipairs(ns.Candidates()) do
    if c.guid == FOE then offered = c end
end
Check(offered, "the foe who killed you is not offered for the diary")
Eq(offered and offered.why, "they killed you", "why the foe is offered")

--------------------------------------------------------------------------
Section("the stranger's fights come along into the diary")

Check(not ns.Diary.IsDiary(FOE), "the foe is a stranger so far")
ns.Diary.Add(FOE, { source = "test", tags = { "foe" } })
local lines = Lines(FOE)
Eq(#lines, 4, "fight lines on the profile: " .. table.concat(lines, " | "))
Eq(lines[4], "You killed Romulus in Hillsbrad Foothills", "your kill")
Eq(lines[3], "Your group killed Romulus in Hillsbrad Foothills (Bram's killing blow)", "the group's kill")
Eq(lines[2], "Romulus killed you with Ambush in Hillsbrad Foothills", "a confirmed death")
Eq(lines[1], "Romulus killed you with Backstab in Hillsbrad Foothills", "a death from the recap alone")

-- An unconfirmed guess says so.
local guessed = ns.WorldPvP.Died({ player = true, guid = FOE }, mock.now + 60, ns.Where())
Eq(Lines(FOE)[1], "Romulus probably killed you in Hillsbrad Foothills", "a guessed death")
ns.Interactions.Remove(FOE, guessed.row)

-- The profile's story says the score.
Eq(ns.UI.Format.FightsText(ns.Interactions.Fights(FOE)), "You and your group have killed them twice and they've killed you twice.",
    "the profile's sentence")
Eq(ns.UI.Format.FightsText({ kills = 1, yours = 0, deaths = 0 }), "Your group has killed them once.", "the group alone")
Eq(ns.UI.Format.FightsText({ kills = 0, yours = 0, deaths = 3 }), "They've killed you 3 times.", "deaths alone")

--------------------------------------------------------------------------
Section("the foe's reunion card")

local toast
local function Story()
    local parts = {}
    for _, fs in ipairs(toast.lines) do
        if fs:IsShown() then parts[#parts + 1] = fs:GetText() end
    end
    return Plain(table.concat(parts, " "))
end

-- Bram's card from joining the group earlier goes first.
for _ = 1, 10 do mock.RunTimers() end
Eq(ns.UI.ReunionShowing(), nil, "an earlier card is still up")

mock.now = mock.now + DAY
wipe(ns.db.meta.greeted)
ns.UI.Reunion(FOE, "nearby")
toast = _G.SocialDiaryToastFrame
Check(toast:IsShown(), "no toast for the foe")
Eq(Story(), "You've killed them twice, they've killed you twice. Last fight yesterday.",
    "the foe's card tells the score (the place dropped to fit)")
mock.RunTimers()

-- A foe never fought.
ns.Diary.Add(F.FRIEND.guid, { source = "test", tags = { "foe" } })
wipe(ns.db.meta.greeted)
ns.UI.Reunion(F.FRIEND.guid, "nearby")
Eq(Story(), "No blood between you yet.", "a foe never fought")
mock.RunTimers()

-- Avoid is not about PvP: the ordinary story.
ns.Diary.Get(FOE).tags = { "avoid" }
ns.Touch()
wipe(ns.db.meta.greeted)
ns.UI.Reunion(FOE, "nearby")
Check(not Story():find("killed"), "an avoid card told the score: " .. Story())
mock.RunTimers()

--------------------------------------------------------------------------
Section("forgetting takes the fights")

ns.Characters.Forget(FOE)
Eq(ns.Interactions.Fights(FOE), nil, "a forgotten foe's fights were kept")

--------------------------------------------------------------------------
Section("the core's hooks: Rows' `fight` flag and the death messages")

-- Core counts and indexes fights by the flag, never by the kinds' names.
Eq(ns.Rows.Get("pvp_kill").fight, "kill", "pvp_kill's flag")
Eq(ns.Rows.Get("pvp_death").fight, "death", "pvp_death's flag")
ns.Rows.Register("scrap_fight", { fight = "kill" })
local SCRAP = F.STRANGER2.guid
local scrap = ns.Interactions.Add(SCRAP, "scrap_fight", { context = { by = STRANGER.guid } })
Eq(ns.Interactions.Fights(SCRAP).kills, 1, "a kind with the flag counted as a fight")
Eq(ns.Interactions.Fights(SCRAP).yours, 0, "context.by read as the group's blow")
Eq(ns.Journey.FightIndex()[scrap.time], SCRAP, "a kind with the flag indexed by its time")
ns.Interactions.Remove(SCRAP, scrap)

-- Deaths tells the user's own death as SD_YOU_DIED, then SD_DEATH_RECAP
-- with the same table, and knows nothing of fights.
local told = {}
local function Heard(event, death, killer) told[#told + 1] = { event = event, death = death, killer = killer } end
ns.On("SD_YOU_DIED", Heard)
ns.On("SD_DEATH_RECAP", Heard)
mock.now = mock.now + 600
mock.inCombat = true
mock.SetUnit("target", HOSTILE)
mock.fire("PLAYER_DEAD")
Eq(#told, 1, "the death was not told at the moment")
Eq(told[1] and told[1].death.guess.guid, FOE, "the guess told")
Eq(told[1] and told[1].death.time, mock.now, "the death's time told")
recaps.latest = Blow(FOE, "Romulus", mock.now, "Ambush")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
Eq(#told, 2, "the recap was not told")
Check(told[2] and told[2].death == told[1].death, "the recap told another death's table")
Eq(told[2] and told[2].killer.guid, FOE, "the recap's killer told")
ns.Off("SD_YOU_DIED", Heard)
ns.Off("SD_DEATH_RECAP", Heard)

--------------------------------------------------------------------------
Section("one death, told more than once (issue #74)")

-- The client tells one death twice at the moment, again at the release
-- and once more after a resurrection: one fight, one death on the route.
-- A real death after a revive still counts, a quick one too.
local function Deaths() return ns.Interactions.Fights(FOE).deaths end
local function Crosses() return #ns.Deaths.List(ns.Journey.Kept()) end
local function Marks()
    local n = 0
    for _, m in ipairs(ns.Journey.Kept().marks or {}) do
        if m.kind == "fight" and m.outcome == "lost" then n = n + 1 end
    end
    return n
end
local function Killed(spell)
    recaps.latest = Blow(FOE, "Romulus", mock.now, spell)
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
end

ns.db.settings.keepRoute = true
ns.Journey.Begin(ns.ownGUID, mock.now, 38, 1424)
Check(ns.Journey.Kept(), "the route is not kept in this test")
local deaths, crosses, marks = Deaths(), Crosses(), Marks()
mock.now = mock.now + 600
mock.fire("PLAYER_REGEN_DISABLED")
mock.inCombat = true
mock.SetUnit("target", HOSTILE)
mock.dead = true
mock.fire("PLAYER_DEAD")
mock.fire("PLAYER_DEAD")
Killed("Shadow Word: Death")
Eq(Deaths(), deaths + 1, "the double PLAYER_DEAD wrote two fights")
Eq(Marks(), marks + 1, "the double PLAYER_DEAD drew two fight marks")
Eq(Crosses(), crosses + 1, "the double PLAYER_DEAD put two deaths on the route")

-- The spirit released: PLAYER_ALIVE as a ghost, and PLAYER_DEAD again.
mock.now = mock.now + 20
mock.dead, mock.ghost = false, true
mock.fire("PLAYER_ALIVE")
mock.fire("PLAYER_DEAD")
-- A /reload on the way back, then the corpse reached.
mock.fire("PLAYER_ENTERING_WORLD")
mock.fire("PLAYER_DEAD")
mock.now = mock.now + 60
mock.ghost = false
mock.fire("PLAYER_UNGHOST")
mock.fire("PLAYER_ALIVE")
-- And the one just after a revive, the user reading alive.
mock.now = mock.now + 2
mock.fire("PLAYER_DEAD")
mock.RunTimers()
Eq(Deaths(), deaths + 1, "a death told again was written again")
Eq(Crosses(), crosses + 1, "a death told again went on the route again")

-- Killed again a few seconds after the revive (a soulstone, a res in the
-- middle of the fight): reading dead, a death of its own.
mock.now = mock.now + 3
mock.inCombat = true
mock.dead = true
mock.fire("PLAYER_DEAD")
Killed("Shadow Word: Death")
Eq(Deaths(), deaths + 2, "a real death soon after a revive was lost")
Eq(Crosses(), crosses + 2, "a real death soon after a revive left the route")

-- PLAYER_ALIVE while still lying dead (after a loading screen) is no
-- revive: the release that follows is still the same death.
mock.fire("PLAYER_ALIVE")
mock.fire("PLAYER_DEAD")
Eq(Crosses(), crosses + 2, "PLAYER_ALIVE while dead counted as a revive")

-- Resurrected by a player, then a fight and a death much later.
mock.dead = false
mock.fire("PLAYER_ALIVE")
mock.now = mock.now + 600
mock.fire("PLAYER_REGEN_DISABLED")
mock.inCombat = true
mock.dead = true
mock.fire("PLAYER_DEAD")
Killed("Backstab")
Eq(Deaths(), deaths + 3, "a later death was taken for a repeat")
Eq(Marks(), marks + 3, "a later death drew no fight mark")
mock.dead = false
mock.fire("PLAYER_ALIVE")
