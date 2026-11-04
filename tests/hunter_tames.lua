-- A hunter's tames (Features/Classes/Hunter/): Tame Beast cast and the pet
-- that came of it is a tame; the quest's rod beasts, Call Pet and Revive
-- Pet are not; tames within the hour are one; a rename is read at the next
-- summon; nobody but a hunter listens.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local H = ns.Hunter
local HUNTER = F.Like(F.SELF, { class = { "Hunter", "HUNTER", 3 }, level = 10 })
local WARRIOR = F.SELF

_G.UnitCreatureFamily = function(token)
    local u = mock.units[token]
    return u and u.family
end

local BOAR, CAT = 3099, 3425
mock.creatureDisplays[BOAR], mock.creatureDisplays[CAT] = 9101, 9102
local spawn = 0
-- The pet unit as the client shows it: `name` "Unknown" on its first
-- UNIT_PET, its family's a moment later.
local function Pet(npcID, name, family, level)
    spawn = spawn + 1
    return { guid = ("Pet-0-1-1-0-%d-%010X"):format(npcID, spawn), name = { name }, family = family,
        level = level, isPlayer = false }
end
local function Beast(npcID, name)
    spawn = spawn + 1
    return { guid = ("Creature-0-1-1-0-%d-%010X"):format(npcID, spawn), name = { name }, isPlayer = false }
end

local function Cast(spellID, target)
    mock.fire("UNIT_SPELLCAST_SENT", "player", target or "", "Cast-3-1-1-1-" .. spellID .. "-0000", spellID)
end
-- The pet comes (UNIT_PET twice, as the client sends it), named a moment
-- later, and read after that.
local function Comes(pet, named)
    mock.SetUnit("pet", F.Like(pet, { name = { "Unknown" } }))
    mock.fire("UNIT_PET", "player")
    mock.fire("UNIT_PET", "player")
    mock.SetUnit("pet", F.Like(pet, { name = named and { named } or pet.name }))
    mock.RunTimers()
end
local function Gone()
    mock.units.pet = nil
    mock.fire("UNIT_PET", "player")
end
-- A whole tame of `beast`, its channel `channel` s.
local function Tame(beast, pet, channel)
    mock.SetUnit("target", beast)
    Cast(1515, beast.name[1])
    mock.now = mock.now + (channel or 20)
    Comes(pet)
end

mock.now = 1793800000
mock.position = { x = 0.48, y = 0.61 }
mock.zone, mock.subZone = "Mulgore", "Bloodhoof Village"

--------------------------------------------------------------------------
Section("nobody but a hunter listens")

mock.SetUnit("player", WARRIOR)
mock.fire("PLAYER_ENTERING_WORLD")
mock.RunTimers()
Check(not ns._test.Hunter().listening, "a warrior listens")
Check(not ns.IsRegistered("UNIT_PET"), "UNIT_PET registered for a warrior")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SENT"), "UNIT_SPELLCAST_SENT registered for a warrior")

mock.SetUnit("player", HUNTER)
ns.Fire("SD_WORLD_SETTLED")
Check(ns._test.Hunter().listening, "a hunter does not listen")
Check(ns.IsRegistered("UNIT_PET") and ns.IsRegistered("UNIT_SPELLCAST_SENT"), "a hunter's events")
local j = ns.db.journey[ns.ownGUID]
Check(j, "setup: no route")
j.tames = nil

--------------------------------------------------------------------------
Section("the quest's rod beasts are no tame")

local strider = Beast(2956, "Adult Plainstrider")
mock.SetUnit("target", strider)
Cast(19688, "Adult Plainstrider")
mock.now = mock.now + 20
mock.SetUnit("pet", strider)                      -- a charmed creature, not a pet
mock.fire("UNIT_PET", "player")
mock.RunTimers()
Eq(#H.List(j), 0, "a rod's charmed beast was a tame")
-- Armed or not, a "Creature-" pet is never one.
Cast(1515, "Adult Plainstrider")
mock.SetUnit("pet", Beast(2956, "Adult Plainstrider"))
mock.fire("UNIT_PET", "player")
mock.RunTimers()
Eq(#H.List(j), 0, "a charmed creature after Tame Beast was a tame")
Gone()
ns._test.Hunter().reset()

--------------------------------------------------------------------------
Section("Tame Beast, and the pet that came of it")

mock.now = mock.now + 600
local boar = Beast(BOAR, "Dire Mottled Boar")
local bristle = Pet(BOAR, "Boar", "Boar", 9)
Tame(boar, bristle)
local tames = H.List(j)
Eq(#tames, 1, "one tame")
local rec = tames[1]
Eq(rec.npcID, BOAR, "its creature")
Eq(rec.beast, "Dire Mottled Boar", "the beast, as the cast named it")
Eq(rec.family, "Boar", "its family")
Eq(rec.petLevel, 9, "its level")
Eq(rec.level, 10, "the hunter's level")
Eq(rec.name, nil, "the client's own name is no name given")
Eq(rec.n, 1, "one tame in it")
Eq(rec.t, mock.now, "when the pet came")
Eq(rec.mapID, 1412, "where: the map")
Eq(rec.x, 0.48, "where: x")
-- Its portrait, looked up from the creature's id a moment later.
for _ = 1, 3 do mock.RunTimers() end
Eq(rec.display, 9101, "the beast's display")

--------------------------------------------------------------------------
Section("Call Pet and Revive Pet are no tame")

Gone()
mock.now = mock.now + 30
Cast(883)                                         -- Call Pet
Comes(Pet(BOAR, "Boar", "Boar", 9))
Gone()
Cast(982)                                         -- Revive Pet
Comes(Pet(BOAR, "Boar", "Boar", 9))
Eq(#H.List(j), 1, "a summon was a tame")
Eq(H.List(j)[1].n, 1, "a summon merged in")

--------------------------------------------------------------------------
Section("a rename, read at the next summon")

Gone()
mock.now = mock.now + 120
Cast(883)
Comes(Pet(BOAR, "Bristlemane", "Boar", 9))
Eq(rec.name, "Bristlemane", "the name given")
Gone()
Cast(883)
Comes(Pet(BOAR, "Someone Else", "Boar", 9))
Eq(rec.name, "Bristlemane", "a name, once read, is kept")

--------------------------------------------------------------------------
Section("a tame cut short is nothing")

Gone()
mock.SetUnit("target", Beast(CAT, "Savannah Prowler"))
Cast(1515, "Savannah Prowler")
mock.now = mock.now + H.ARMED + 1
Comes(Pet(CAT, "Cat", "Cat", 13))
Eq(#H.List(j), 1, "a pet long after the cast was a tame")
Eq(rec.n, 1, "a pet long after the cast merged in as a tame")
Gone()
-- Cut short, then the old pet called within the window.
mock.SetUnit("target", Beast(CAT, "Savannah Prowler"))
Cast(1515, "Savannah Prowler")
mock.now = mock.now + 3
Cast(883)
Comes(Pet(BOAR, "Bristlemane", "Boar", 9))
Eq(#H.List(j), 1, "Call Pet after a tame cut short was a tame")
Eq(rec.n, 1, "Call Pet after a tame cut short merged in as a tame")
Gone()
-- Cut short with no other cast: the old pet, another creature, still no tame.
mock.SetUnit("target", Beast(CAT, "Savannah Prowler"))
Cast(1515, "Savannah Prowler")
mock.now = mock.now + 5
Comes(Pet(BOAR, "Bristlemane", "Boar", 9))
Eq(#H.List(j), 1, "another creature's pet after Tame Beast was a tame")
Eq(rec.n, 1, "another creature's pet merged in as a tame")
Gone()
ns._test.Hunter().reset()

--------------------------------------------------------------------------
Section("tames within the hour are one, the one kept")

mock.now = rec.t + 30 * 60
mock.position = { x = 0.40, y = 0.70 }
Tame(Beast(CAT, "Savannah Prowler"), Pet(CAT, "Cat", "Cat", 13))
Eq(#H.List(j), 1, "a tame within the hour was another")
Eq(rec.n, 2, "the two counted")
Eq(rec.beast, "Savannah Prowler", "the one kept")
Eq(rec.family, "Cat", "its family")
Eq(rec.name, nil, "the first pet's name went with it")
Eq(rec.x, 0.40, "where the one kept was tamed")
Eq(rec.display, nil, "the first beast's portrait went with it")
for _ = 1, 3 do mock.RunTimers() end
Eq(rec.display, 9102, "the one kept's portrait")
Gone()
mock.now = rec.t + H.MERGE + 60
Tame(Beast(BOAR, "Dire Mottled Boar"), Pet(BOAR, "Boar", "Boar", 9))
Eq(#H.List(j), 2, "a tame more than an hour on was merged")
Eq(H.List(j)[2].n, 1, "the new one on its own")
Gone()

--------------------------------------------------------------------------
Section("a name only for the newest tame, and not for long")

local newest = H.List(j)[2]
mock.now = newest.t + H.NAMING + 60
Cast(883)
Comes(Pet(BOAR, "Tusk", "Boar", 9))
Eq(newest.name, nil, "a name read a week on was taken")
Eq(H.Named(j, CAT, "Whisker", "Cat", newest.t + 60), nil, "another creature's name was taken")
Eq(H.Named(j, BOAR, "Boar", "Boar", newest.t + 60), nil, "the family's name was taken")
Eq(H.Named(j, BOAR, "Tusk", "Boar", newest.t + 60), newest, "a name in time")
Gone()

--------------------------------------------------------------------------
Section("the pet out at login is read for its name")

H.List(j)[2].name = nil
mock.now = newest.t + 3600
mock.SetUnit("pet", Pet(BOAR, "Tusk", "Boar", 9))
ns._test.Hunter().reset()
-- The settle finds a hunter already listening: it reads nothing new. A
-- fresh login (off, then on) does.
mock.SetUnit("player", WARRIOR)
ns.Fire("SD_WORLD_SETTLED")
mock.SetUnit("player", HUNTER)
ns.Fire("SD_WORLD_SETTLED")
mock.RunTimers()
Eq(newest.name, "Tusk", "the pet out at the settle was not read")
Gone()

--------------------------------------------------------------------------
Section("only while the route is kept")

ns.SetSetting("keepRoute", false)
mock.now = mock.now + 2 * H.MERGE
Tame(Beast(CAT, "Savannah Prowler"), Pet(CAT, "Cat", "Cat", 13))
Eq(#H.List(j), 2, "a tame kept with the route off")
ns.SetSetting("keepRoute", true)
Gone()

--------------------------------------------------------------------------
Section("a warrior again hears nothing")

mock.SetUnit("player", WARRIOR)
ns.Fire("SD_WORLD_SETTLED")
Check(not ns.IsRegistered("UNIT_PET"), "UNIT_PET still registered")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SENT"), "UNIT_SPELLCAST_SENT still registered")

--------------------------------------------------------------------------
Section("/sd testdata: two tames on the made-up route, and never written to")

mock.SetUnit("player", HUNTER)
ns.Fire("SD_WORLD_SETTLED")
local own = #H.List(j)
ns.TestData.Write()
local test = ns.db.journey[ns.ownGUID]
Check(test ~= j and test.test, "setup: the made-up route is not shown")
local made = H.List(test)
Eq(#made, 2, "the made-up route's tames")
Eq(made[1].level, 10, "the first at level 10")
Eq(made[1].name, "Bristlemane", "named")
Eq(made[1].n, 3, "after two let go")
Eq(made[2].level, 14, "the second at level 14")
Eq(made[2].name, nil, "not named yet")
Check(made[1].t < made[2].t, "oldest first")
mock.now = mock.now + 2 * H.MERGE
Tame(Beast(CAT, "Savannah Prowler"), Pet(CAT, "Cat", "Cat", 13))
Eq(#H.List(test), 2, "capture wrote onto the made-up route")
Gone()
ns.TestData.Remove()
Eq(ns.db.journey[ns.ownGUID], j, "the own route is back")
Eq(#H.List(j), own, "with its own tames")
