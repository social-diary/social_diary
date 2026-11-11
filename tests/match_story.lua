-- A Warsong told by time (Core/MatchStory.lua, Core/Matches.lua's story
-- substrate, Capture/Matches.lua's flag lines and meter walk): the record
-- keeps flag lines and fights packed; the story reads them back as carries,
-- fights tied to branches, phases, the zerg, two lines and the strips
-- chosen for them. Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Matches, Story = ns.Matches, ns.MatchStory

local SELF, BRAM, GARRICK = F.SELF, F.STRANGER, F.GARRICK

T.BlankDiary()
mock.now = 1794069000
mock.zone = "Orgrimmar"
mock.SetUnit("player", SELF)
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()
mock.SetUnit("target", BRAM)
ns.Diary.Add(BRAM.guid, { source = "test" })
mock.SetUnit("target", GARRICK)
ns.Diary.Add(GARRICK.guid, { source = "test" })
mock.SetUnit("target", nil)
-- Garrick is from the world (a trade); Bram only from the diary.
ns.Interactions.Add(GARRICK.guid, "trade", { time = mock.now - 86400 })

local OWN = "Ulverston Nye"

--------------------------------------------------------------------------
Section("the substrate, packed")

do
    local m = Matches.New({ map = 489, startedAt = 1000, faction = 0, state = "complete" })
    Eq(Matches.Ref(m, "Koko Brightwater", OWN), "1", "the first name's reference")
    Eq(Matches.Ref(m, "koko brightwater", OWN), "1", "a name was pooled twice")
    Eq(Matches.Ref(m, OWN, OWN), "0", "the user is not 0")
    Eq(Matches.RefName(m, "1"), "Koko Brightwater", "a reference read back")
    Eq(Matches.RefName(m, "0", OWN), OWN, "you read back")
    local i = Matches.Flag(m, 1030, "p", 1, "1")
    Matches.Near(m, i, 12.6)
    Matches.Flag(m, 1050, "c", 1, "1")
    local fl = Matches.Flags(m)
    Eq(#fl, 2, "flag lines kept")
    Eq(fl[1].t, 30, "a flag line's time is after startedAt")
    Eq(fl[1].near, 12, "near seconds on the pick-up")
    Eq(fl[2].kind, "c", "the capture")
    Matches.Fight(m, { t = 40, dur = 12, us = { "0", "1" }, them = { "2" },
        deaths = { { who = "2", at = 50, killer = "0" }, { who = "0", at = 51 } } })
    local fs = Matches.Fights(m)
    Eq(fs[1].dur, 12, "a fight's length")
    Eq(#fs[1].us, 2, "a fight's side")
    Eq(fs[1].deaths[1].killer, "0", "a death's killer")
    Eq(fs[1].deaths[2].killer, nil, "an unnamed killer")
    Matches.Remove(m.id)
end

--------------------------------------------------------------------------
Section("capture: flag lines and the meter")

do
    -- The meter as Capture reads it: sessions, and per session the sources.
    local sessions, sources = { { sessionID = 7, durationSeconds = 30 } }, {}
    _G.C_DamageMeter = {
        GetAvailableCombatSessions = function() return sessions end,
        GetCombatSessionFromID = function(id, kind) return { combatSources = (sources[id] or {})[kind] or {} } end,
    }
    _G.C_DeathRecap = { GetRecapEvents = function(id)
        if id == 91 then return { { overkill = 0, sourceName = "Hesk Morrow" }, { overkill = 40, sourceName = "Ilsa Venn" } } end
        return {}
    end }
    local m = Matches.Enter({ map = 489, mapName = "Warsong Gulch", faction = 0 }, mock.now)
    m.meter = { from = 7 }
    local say = ns._test.MatchFlagLine
    mock.now = m.startedAt + 90
    say("Let the battle for Warsong Gulch begin!")
    Eq(m.t0, 90, "the gates were not read")
    mock.now = m.startedAt + 100
    say("The Alliance Flag was picked up by Bram Redfen!")
    mock.now = m.startedAt + 120
    say("The Alliance Flag was dropped by Bram Redfen!")
    say("The Alliance Flag was returned to its base by Ilsa Venn!")
    mock.now = m.startedAt + 130
    say("The Horde flag was picked up by Ulverston Nye!")
    mock.now = m.startedAt + 160
    say("Ulverston Nye captured the Horde flag!")
    say("The flags are now placed at their bases.")
    say("Someone said something else entirely.")
    local fl = Matches.Flags(m)
    Eq(#fl, 6, "flag lines read")
    Eq(fl[1].kind .. fl[1].flag, "p1", "the Alliance flag's pick-up")
    Eq(Matches.RefName(m, fl[1].who), "Bram Redfen", "the carrier's name")
    Eq(fl[3].kind, "r", "the return")
    Eq(fl[4].who, "0", "you, picking it up")
    Eq(fl[5].kind .. fl[5].flag .. fl[5].who, "c00", "your capture of the Horde flag")
    Eq(fl[6].kind, "x", "the reset")

    -- A fight of yours ends; its session is walked 1.5 s later.
    sessions[#sessions + 1] = { sessionID = 8, durationSeconds = 20 }
    sources[8] = {
        [0] = { { name = OWN, classFilename = "WARRIOR", isLocalPlayer = true, sourceDisplayType = 0 },
            { name = "Bram Redfen", classFilename = "DRUID", sourceDisplayType = 1 },
            { name = "Ilsa Venn", classFilename = "MAGE", factionGroup = 1, sourceDisplayType = 2 },
            { name = "Wolf", sourceDisplayType = 2 } },
        [9] = { { name = OWN, isLocalPlayer = true, deathTimeSeconds = 15, deathRecapID = 91 } },
    }
    mock.now = m.startedAt + 200
    mock.fire("PLAYER_REGEN_ENABLED")
    mock.RunTimers()
    local fs = Matches.Fights(m)
    Eq(#fs, 1, "the fight was not walked")
    Eq(fs[1].t, 180, "a fight starts its length before its end")
    Eq(#fs[1].us, 2, "our side of the fight")
    Eq(#fs[1].them, 1, "theirs (a pet without a class left out)")
    Eq(fs[1].deaths[1].who, "0", "your death in it")
    Eq(fs[1].deaths[1].at, 195, "the death's second")
    Eq(Matches.RefName(m, fs[1].deaths[1].killer), "Ilsa Venn", "the recap's killer")
    mock.fire("PLAYER_REGEN_ENABLED")
    mock.RunTimers()
    Eq(#Matches.Fights(m), 1, "a session was walked twice")
    local hasIlsa
    for _, p in ipairs(Matches.Players(m)) do if p.name == "Ilsa Venn" then hasIlsa = p end end
    Check(hasIlsa and hasIlsa.class == "MAGE" and hasIlsa.side == 1, "the meter's enemy was not seen with class and side")
    Matches.Close(m, "left")
    Eq(m.meter, nil, "the meter's place outlived the match")
    Matches.Remove(m.id)
    _G.C_DamageMeter, _G.C_DeathRecap = nil, nil
end

--------------------------------------------------------------------------
-- A short win, 3-1 (Horde, you), times after the gates (t0 = 60):
--   20  Bram (diary) picks up their flag; home at 100          1-0
--   110 Feivel takes ours; drops at 130 (you killed him at 131); you return it at 135
--   150 you pick up theirs; home at 190                        2-0
--   200 Hesk takes ours; home at 260                           2-1
--   270 Norwood takes theirs; home at 400 (near you 15 s)      3-1
local S0 = 5000
local function Win()
    local m = Matches.New({ map = 489, mapName = "Warsong Gulch", startedAt = S0, t0 = 60, faction = 0,
        winner = 0, duration = 420, state = "complete", endedAt = S0 + 480 })
    local function R(name) return Matches.Ref(m, name, OWN) end
    local function At(t) return S0 + 60 + t end
    local bram, feivel, hesk, norwood = R("Bram Redfen"), R("Feivel Ashgrove"), R("Hesk Morrow"), R("Norwood Sparks")
    local ilsa, tam, quill, pell, garrick = R("Ilsa Venn"), R("Tam Oake"), R("Quill Darrow"), R("Pell Stour"), R("Garrick Fallow")
    Matches.Flag(m, At(20), "p", 1, bram)
    Matches.Flag(m, At(100), "c", 1, bram)
    Matches.Flag(m, At(105), "x")
    Matches.Flag(m, At(110), "p", 0, feivel)
    Matches.Flag(m, At(130), "d", 0, feivel)
    Matches.Flag(m, At(135), "r", 0, "0")
    Matches.Flag(m, At(150), "p", 1, "0")
    Matches.Flag(m, At(190), "c", 1, "0")
    Matches.Flag(m, At(200), "p", 0, hesk)
    Matches.Flag(m, At(260), "c", 0, hesk)
    local i = Matches.Flag(m, At(270), "p", 1, norwood)
    Matches.Near(m, i, 15)
    Matches.Flag(m, At(400), "c", 1, norwood)
    local function Fight(t, dur, us, them, deaths)
        for _, d in ipairs(deaths or {}) do d.at = 60 + d.at end
        Matches.Fight(m, { t = 60 + t, dur = dur, us = us, them = them, deaths = deaths })
    end
    Fight(40, 20, { "0", bram }, { feivel, hesk })                                     -- 1: Bram's carry
    Fight(125, 10, { "0" }, { feivel }, { { who = feivel, at = 131, killer = "0" } })  -- 2: you and Feivel
    Fight(205, 15, { "0", norwood }, { hesk, ilsa, tam, quill },                       -- 3: Hesk's carry
        { { who = "0", at = 215, killer = ilsa }, { who = norwood, at = 217, killer = tam } })
    Fight(240, 10, { "0", garrick }, { ilsa, tam }, { { who = "0", at = 245, killer = ilsa } })  -- 4: linked to 3
    Fight(300, 10, { "0" }, { ilsa, pell }, { { who = "0", at = 305, killer = ilsa } }) -- 5: near Norwood
    Fight(350, 8, { "0", garrick }, { ilsa }, { { who = ilsa, at = 355, killer = garrick } })  -- 6: revenge
    return m
end

--------------------------------------------------------------------------
Section("carries, the score, phases and lines")

local m = Win()
local s = Story.Build(m, { own = OWN })
Check(s, "a Warsong with flag lines has no story")
Eq(s.T, 420, "the match's length")
Eq(#s.carries, 5, "carries")
Eq(s.carries[1].side, "us", "carrying their flag is our branch")
Eq(s.carries[1].ends, "captured", "Bram's carry ended home")
Eq(s.carries[2].side, "them", "theirs carrying ours")
Eq(s.carries[2].ends, "returned", "Feivel's carry was returned")
Eq(s.carries[2].by, "0", "returned by you")
Eq(#s.carries[2].lying, 1, "the flag lay between the drop and the return")
Eq(s.carries[2].lying[1].from .. "-" .. s.carries[2].lying[1].to, "130-135", "the lying flag's dots")
Eq(s.score.us .. "-" .. s.score.them, "3-1", "the score")
Eq(#s.caps, 4, "captures")
Eq(s.caps[3].us .. "-" .. s.caps[3].them, "2-1", "the third capture's score")
Eq(s.carries[3].held["0"], 40, "your seconds with their flag")
Eq(#s.phases, 4, "a capture ends each phase")
Eq(s.phases[1].key, "opening", "the first phase")
Eq(s.phases[2].key, "broken", "a carry broken and returned in it")
Eq(s.phases[3].key, "theirs", "their capture")
Eq(s.phases[4].key, "lastflag", "the last flag")
Eq(s.lines[1].to, 190, "the line breaks at the capture nearest the middle")
Eq(s.lines[2].from, 190, "the second line starts there")
Eq(s.zerg, nil, "a short match with flags always out is no zerg")

--------------------------------------------------------------------------
Section("the sociogram: what belongs to a branch")

Eq(s.fights[1].carry, s.carries[1], "the carrier in the fight seeds the branch")
Eq(s.fights[2].carry, s.carries[2], "the carrier who fell in it")
Eq(s.fights[3].carry, s.carries[4], "Hesk, carrying, in the fight")
Eq(s.fights[4].carry, s.carries[4], "two shared people within 60 s link the next fight")
Check(s.fights[4].linked and not s.fights[4].moved, "a link forwards is not a late move")
Eq(s.fights[5].carry, s.carries[5], "near the carrier, the fight is the carry's")
Check(s.fights[5].near, "the near tie not marked")
Eq(s.fights[2].deaths[1].carry, s.carries[2], "a death follows its fight")

do
    -- A late move: a fight before the carrier was first seen joins later.
    local m2 = Win()
    local fs = m2.fights
    -- A fight at 200-210 inside Hesk's carry, sharing Ilsa and Tam with fight 3
    -- but before it, and Hesk not in it.
    local ilsa, tam = Matches.Ref(m2, "Ilsa Venn", OWN), Matches.Ref(m2, "Tam Oake", OWN)
    Matches.Fight(m2, { t = 60 + 200, dur = 4, us = { "0" }, them = { ilsa, tam } })
    local s2 = Story.Build(m2, { own = OWN })
    local early
    for _, x in ipairs(s2.fights) do if x.from == 200 then early = x end end
    Eq(early and early.carry, s2.carries[4], "an earlier fight did not move onto the branch")
    Check(early and early.moved, "the late move not marked")
    Check(#fs > 0, "setup")
    Matches.Remove(m2.id)
end

--------------------------------------------------------------------------
Section("the strips")

local byKind = {}
for _, c in ipairs(s.candidates) do byKind[c.kind] = byKind[c.kind] or {} table.insert(byKind[c.kind], c) end
Check(byKind.nemesis and byKind.nemesis[1].name == "Ilsa Venn", "Ilsa killed you three times: no nemesis")
Eq(byKind.nemesis and #byKind.nemesis[1].times, 3, "the nemesis's times")
Check(byKind.duel and byKind.duel[1].won == true, "you against Feivel, won")
Check(byKind.outnumbered and byKind.outnumbered[1].them == 4, "two against four")
Check(byKind.revenge and byKind.revenge[1].by == "Garrick Fallow", "Garrick killed Ilsa: no revenge")
Check(byKind.carry and byKind.carry[1].home, "you brought their flag home")
Check(byKind["return"] and byKind["return"][1].killed, "you killed Feivel and brought ours back")
Check(byKind.acquaintance and byKind.acquaintance[1].guid == GARRICK.guid, "Garrick, from the world, beside you")
Check(byKind.person, "a diary person not found")
local escortNorwood
for _, e in ipairs(byKind.escort or {}) do if e.name == "Norwood Sparks" then escortNorwood = e end end
Check(escortNorwood and escortNorwood.secs == 15, "near Norwood on his carry: no escort")
Eq(byKind.together, nil, "fell together with a stranger who did not carry")
Eq(byKind.friend, nil, "no diary person killed you")

local function Kinds(line)
    local out = {}
    for _, x in ipairs(line.strips) do out[#out + 1] = x.kind end
    return table.concat(out, ",")
end
Eq(Kinds(s.lines[1]), "person,duel,carry", "line 1: Bram; Feivel's return goes to his rarer duel; your carry home at the break")
Eq(Kinds(s.lines[2]), "acquaintance,nemesis,revenge", "line 2: three, the rarest, in time order")
local people = {}
for _, line in ipairs(s.lines) do
    for _, x in ipairs(line.strips) do
        if x.person then
            Check(not people[x.person], "one person, two strips: " .. tostring(x.name))
            people[x.person] = true
        end
    end
end

--------------------------------------------------------------------------
Section("a friend who killed you; fell together, limited")

do
    local m3 = Win()
    m3.deaths = { S0 + 60 + 215 }
    m3.killers = { "Bram Redfen" }
    local s3 = Story.Build(m3, { own = OWN })
    local friend
    for _, c in ipairs(s3.candidates) do if c.kind == "friend" then friend = c end end
    -- The recap at 215 named Ilsa in the meter; the record's own named Bram:
    -- the meter's is kept, so no friend strip.
    Eq(friend, nil, "the meter's killer lost to the record's")
    m3.deaths = { S0 + 60 + 380 }
    m3.killers = { "Bram Redfen" }
    s3 = Story.Build(m3, { own = OWN })
    for _, c in ipairs(s3.candidates) do if c.kind == "friend" then friend = c end end
    Check(friend and friend.guid == BRAM.guid, "a diary person killed you: no friend strip")
    Matches.Remove(m3.id)

    local m4 = Win()
    local bram = Matches.Ref(m4, "Bram Redfen", OWN)
    Matches.Fight(m4, { t = 60 + 60, dur = 6, us = { "0", bram }, them = {},
        deaths = { { who = "0", at = 60 + 62 }, { who = bram, at = 60 + 64 } } })
    Matches.Fight(m4, { t = 60 + 80, dur = 6, us = { "0", bram }, them = {},
        deaths = { { who = "0", at = 60 + 82 }, { who = bram, at = 60 + 83 } } })
    local s4 = Story.Build(m4, { own = OWN })
    local n = 0
    for _, line in ipairs(s4.lines) do for _, x in ipairs(line.strips) do if x.kind == "together" then n = n + 1 end end end
    local cands = 0
    for _, c in ipairs(s4.candidates) do if c.kind == "together" then cands = cands + 1 end end
    Eq(cands, 2, "you and Bram (diary) fell together twice")
    Check(n <= 1, "fell together more than once a page")
    local bramStrips = 0
    for _, line in ipairs(s4.lines) do for _, x in ipairs(line.strips) do if x.person == BRAM.guid then bramStrips = bramStrips + 1 end end end
    Eq(bramStrips, 1, "Bram has one strip a page")
    Matches.Remove(m4.id)
end

--------------------------------------------------------------------------
Section("The Zerg")

do
    local Z0 = 9000
    local z = Matches.New({ map = 489, startedAt = Z0, t0 = 0, faction = 0, duration = 1200, state = "complete" })
    local a, b = Matches.Ref(z, "Ilsa Venn", OWN), Matches.Ref(z, "Tam Oake", OWN)
    Matches.Flag(z, Z0 + 10, "p", 1, "0")
    Matches.Flag(z, Z0 + 100, "c", 1, "0")
    -- 100 to 900 with no flag out: eight fights of 40 s.
    for k = 0, 7 do
        Matches.Fight(z, { t = 150 + k * 90, dur = 40, us = { "0" }, them = { a, b },
            deaths = { { who = a, at = 150 + k * 90 + 30, killer = "0" } } })
    end
    Matches.Flag(z, Z0 + 900, "p", 1, "0")
    Matches.Flag(z, Z0 + 1000, "c", 1, "0")
    local sz = Story.Build(z, { own = OWN })
    Check(sz.zerg, "eight fights in thirteen minutes with no flag out: no zerg")
    Eq(sz.zerg and sz.zerg.from, 100, "the zerg starts at the capture")
    Eq(sz.zerg and sz.zerg.to, 900, "and ends at the next pick-up")
    Eq(sz.zerg and sz.zerg.fights, 8, "its fights")
    Eq(sz.zerg and sz.zerg.theirs, 8, "theirs who fell in it")
    for _, x in ipairs(sz.fights) do
        Check(x.zerg and not x.carry, "a zerg fight on a branch")
    end
    local zs
    for _, c in ipairs(sz.candidates) do if c.kind == "zerg" then zs = c end end
    Check(zs and zs.t == 500, "the zerg's strip pinned to its middle")
    -- Fewer fights: a lull, not a zerg.
    z.fights = { z.fights[1], z.fights[2] }
    Eq(Story.Build(z, { own = OWN }).zerg, nil, "two fights made a zerg")
    Matches.Remove(z.id)
end

--------------------------------------------------------------------------
Section("no story; forgetting; roll-up")

do
    local ab = Matches.New({ map = 529, startedAt = 1, state = "complete", flags = { "1;p;0;;" } })
    Eq(Story.Build(ab), nil, "Arathi has a Warsong story")
    Matches.Remove(ab.id)
    local bare = Matches.New({ map = 489, startedAt = 1, state = "complete" })
    Eq(Story.Build(bare), nil, "a Warsong with no flag lines has a story")
    Matches.Remove(bare.id)

    Matches.Forget(BRAM.guid)
    local bramGone = true
    for _, n in ipairs(m.pool) do if n == "Bram Redfen" then bramGone = false end end
    Check(bramGone, "a forgotten person stayed in the story's names")
    Eq(m.pool[1], "", "their place in the pool went")
    local s5 = Story.Build(m, { own = OWN })
    Eq(#s5.carries, 5, "forgetting a carrier lost a carry")

    m.state = "complete"
    Matches.Rollup(mock.now, 0)
    local strangers = 0
    for _, n in ipairs(m.pool) do if n ~= "" and n ~= "Garrick Fallow" then strangers = strangers + 1 end end
    Eq(strangers, 0, "a rolled-up match kept strangers' names in its story")
    Check(Story.Build(m, { own = OWN }), "a rolled-up match lost its story's shape")
end

--------------------------------------------------------------------------
Section("/sd testdata: two Warsongs told, one not")

do
    for _, mm in ipairs(Matches.All()) do Matches.Remove(mm.id) end
    SlashCmdList.SOCIALDIARY("testdata")
    local told = {}
    for _, mm in ipairs(Matches.All()) do
        if mm.test and Story.Has(mm) then told[#told + 1] = mm end
    end
    Eq(#told, 2, "testdata's told Warsongs")
    local long = Story.Build(told[1])
    Check(long.zerg, "the first Warsong's zerg")
    Eq(long.score.us .. "-" .. long.score.them, "3-1", "the first Warsong's score")
    local short = Story.Build(told[2])
    Eq(short.score.us .. "-" .. short.score.them, "3-1", "the third Warsong's score")
    local kinds = {}
    for _, line in ipairs(short.lines) do for _, x in ipairs(line.strips) do kinds[x.kind] = true end end
    Check(kinds.nemesis, "the third Warsong's nemesis strip")
    Check(kinds.evening, "Feivel, a third time tonight")
    for _, st in ipairs({ long, short }) do
        for i, line in ipairs(st.lines) do
            Check(#line.strips >= 1 and #line.strips <= 3, "a line's strips: " .. i)
        end
    end
    SlashCmdList.SOCIALDIARY("testdata remove")
end
