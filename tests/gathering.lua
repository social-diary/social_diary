-- Gathering (Features/Gathering/Capture.lua): a Mining or Herb Gathering
-- cast that ends well is a node on the route, at the spot the cast began; a
-- cast cut short, another's cast, another spell and a route not kept are
-- nothing. The cast's ending events are listened to only while one is
-- watched.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local G = ns.Gathering
local SELF = F.SELF
local MINING, HERB_GATHERING = 2575, 2366

-- The client's spell names, for a rank that has an id of its own.
local names = { [MINING] = "Mining", [HERB_GATHERING] = "Herb Gathering", [99001] = "Mining",
    [99002] = "Smelting" }
_G.C_Spell = { GetSpellName = function(id) return names[id] end }

local cast = 0
-- A cast of `spell` on `target` begins; returns its id.
local function Sent(spell, target)
    cast = cast + 1
    local id = "Cast-3-1-1-1-" .. spell .. "-" .. cast
    mock.fire("UNIT_SPELLCAST_SENT", "player", target or "", id, spell)
    return id
end
local function Ended(event, id, spell, unit)
    mock.fire(event, unit or "player", id, spell)
end

mock.position = { x = 0.42, y = 0.66 }
mock.zone, mock.subZone = "Mulgore", "Bloodhoof Village"
mock.fire("PLAYER_ENTERING_WORLD")
local j = ns.db.journey[SELF.guid]
Check(j, "setup: no route")

--------------------------------------------------------------------------
Section("only a miner or a herbalist listens")

mock.professions = { { name = "First Aid", rank = 40, max = 75, line = 129 } }
ns.Fire("SD_WORLD_SETTLED")
Check(not ns._test.Gathering().listening, "a character with no gathering listens")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SENT"), "the cast's start is listened to with no gathering")

mock.professions = { { name = "First Aid", rank = 40, max = 75, line = 129 }, { name = "Herbalism", rank = 1, max = 75, line = 182 } }
mock.fire("SKILL_LINES_CHANGED")
Check(ns._test.Gathering().listening, "learning Herbalism did not start the listening")
Check(ns.IsRegistered("UNIT_SPELLCAST_SENT"), "a herbalist's cast start is not listened to")

mock.professions = { { name = "Mining", rank = 1, max = 75, line = 186 } }
mock.fire("SKILL_LINES_CHANGED")
Check(ns._test.Gathering().listening, "a miner does not listen")

local askProfessions, readProfession = _G.GetProfessions, _G.GetProfessionInfo
_G.GetProfessions, _G.GetProfessionInfo = nil, nil
mock.professions = {}
ns.Fire("SD_WORLD_SETTLED")
Check(ns._test.Gathering().listening, "a client with no professions to ask left the miner unheard")
_G.GetProfessions, _G.GetProfessionInfo = askProfessions, readProfession
mock.professions = { { name = "Mining", rank = 1, max = 75, line = 186 } }

--------------------------------------------------------------------------
Section("a node mined")

local id = Sent(MINING, "Copper Vein")
Check(ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "the cast's ending is not listened to while one is watched")
Eq(#G.List(j), 0, "a node before the cast ended")
mock.now = mock.now + 3
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING)
Eq(#G.List(j), 1, "the node on the route")
local rec = G.List(j)[1]
Eq(rec.kind, "ore", "its kind")
Eq(rec.name, "Copper Vein", "its name, as the client said it")
Eq(rec.mapID, 1412, "its map")
Eq(rec.x, 0.42, "its x")
Eq(rec.y, 0.66, "its y")
Eq(rec.t, mock.now, "its time")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "still listening after the cast ended")

--------------------------------------------------------------------------
Section("a herb picked, where the cast began")

mock.position = { x = 0.30, y = 0.20 }
id = Sent(HERB_GATHERING, "Peacebloom")
mock.position = { x = 0.31, y = 0.21 }   -- a step before it ends
Ended("UNIT_SPELLCAST_SUCCEEDED", id, HERB_GATHERING)
Eq(#G.List(j), 2, "the herb on the route")
rec = G.List(j)[2]
Eq(rec.kind, "herb", "its kind")
Eq(rec.name, "Peacebloom", "its name")
Eq(rec.x, 0.3, "the spot the cast began at")
Eq(rec.y, 0.2, "the spot the cast began at, y")

--------------------------------------------------------------------------
Section("a cast cut short, or another's, is nothing")

id = Sent(MINING, "Tin Vein")
Ended("UNIT_SPELLCAST_INTERRUPTED", id, MINING)
Eq(#G.List(j), 2, "an interrupted cast was a node")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "still listening after an interrupted cast")

id = Sent(MINING, "Tin Vein")
Ended("UNIT_SPELLCAST_FAILED", id, MINING)
Eq(#G.List(j), 2, "a failed cast was a node")

id = Sent(MINING, "Tin Vein")
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING, "party1")
Eq(#G.List(j), 2, "another unit's cast was a node")
Ended("UNIT_SPELLCAST_SUCCEEDED", "Cast-3-1-1-1-" .. MINING .. "-other", MINING)
Eq(#G.List(j), 2, "another cast of the player's was this node")
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING)
Eq(#G.List(j), 3, "the cast itself, ended after the others, was not a node")

id = Sent(5000, "Copper Vein")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "another spell is watched")
Ended("UNIT_SPELLCAST_SUCCEEDED", id, 5000)
Eq(#G.List(j), 3, "another spell was a node")

mock.fire("UNIT_SPELLCAST_SENT", "party1", "Copper Vein", "Cast-3-1-1-1-" .. MINING .. "-9", MINING)
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "another unit's cast is watched")

-- A second cast begun before the first ended takes its place.
local first = Sent(MINING, "Silver Vein")
local second = Sent(HERB_GATHERING, "Silverleaf")
Ended("UNIT_SPELLCAST_SUCCEEDED", first, MINING)
Eq(#G.List(j), 3, "a replaced cast was a node")
Ended("UNIT_SPELLCAST_SUCCEEDED", second, HERB_GATHERING)
Eq(#G.List(j), 4, "the cast that replaced it was not a node")
Eq(G.List(j)[4].name, "Silverleaf", "the node of the second cast")

--------------------------------------------------------------------------
Section("a rank with an id of its own, by the name it shares")

id = Sent(99001, "Iron Deposit")
Ended("UNIT_SPELLCAST_SUCCEEDED", id, 99001)
Eq(#G.List(j), 5, "a higher rank of Mining was no node")
Eq(G.List(j)[5].kind, "ore", "its kind")
id = Sent(99002, "Iron Deposit")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "Smelting is watched")

--------------------------------------------------------------------------
Section("no name, no position, no route kept")

id = Sent(MINING, nil)
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING)
Eq(#G.List(j), 6, "a node with no name was no node")
Eq(G.List(j)[6].name, nil, "its name")

mock.position = nil
id = Sent(MINING, "Copper Vein")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "a cast with no position is watched")
mock.position = { x = 0.42, y = 0.66 }

ns.db.settings.keepRoute = false
id = Sent(MINING, "Copper Vein")
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "a cast is watched with the route not kept")
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING)
Eq(#G.List(j), 6, "a node was kept with the route off")
ns.db.settings.keepRoute = true

-- A route not kept while the cast went on.
id = Sent(MINING, "Copper Vein")
ns.db.settings.keepRoute = false
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING)
Eq(#G.List(j), 6, "a node was kept when the route went off during the cast")
ns.db.settings.keepRoute = true

--------------------------------------------------------------------------
Section("a cast that never ends is given up on")

id = Sent(MINING, "Copper Vein")
Check(ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "setup: the cast is not watched")
mock.RunTimers()
Check(not ns.IsRegistered("UNIT_SPELLCAST_SUCCEEDED"), "still watching a cast long past")
Ended("UNIT_SPELLCAST_SUCCEEDED", id, MINING)
Eq(#G.List(j), 6, "a given-up cast was a node")

--------------------------------------------------------------------------
Section("the record's own limits")

Eq(G.Add(j, { kind = "fish", name = "Oily Blackmouth" }), nil, "a kind the feature does not know")
local long = G.Add(j, { t = mock.now, kind = "ore", name = string.rep("x", 200) })
Check(long and #long.name <= 60, "a name longer than the guard")
