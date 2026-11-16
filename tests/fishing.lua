-- Fishing (Features/Fishing/Capture.lua): a loot window that is fishing loot
-- is a catch on the route, at the spot the player stands on, with the first
-- item in it; loot from a kill, a window seen again while it is open, a
-- route not kept and no position are nothing. Only a character with Fishing
-- listens.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Fi = ns.Fishing
local SELF = F.SELF

-- The client's loot calls as the probe saw them (12 Nov): IsFishingLoot,
-- and a slot's info (icon, name, quantity...) and type (1: an item).
local fishing = false
_G.IsFishingLoot = function() return fishing end
_G.GetLootSlotInfo = function(slot)
    local s = mock.loot[slot]
    return 133887, s and s.name, 1, 0, 1, false, false
end
_G.GetLootSlotType = function(slot) return mock.loot[slot] and mock.loot[slot].kind or 1 end

local function Item(name)
    return { name = name, link = "|cffffffff|Hitem:1:::::::::::::|h[" .. name .. "]|h|r",
        sources = { "GameObject-0-7089-1-87-35591-C7B6EC92DD", 1 } }
end
-- A loot window opens (fishing or not) with `slots`.
local function Open(slots, isFishing)
    fishing = isFishing ~= false
    mock.loot = slots
    mock.fire("LOOT_OPENED", false, false)
end
local function Close()
    mock.fire("LOOT_CLOSED")
    mock.loot = {}
    fishing = false
end

mock.position = { x = 0.26, y = 0.81 }
mock.zone, mock.subZone = "Mulgore", "Bloodhoof Village"
mock.fire("PLAYER_ENTERING_WORLD")
local j = ns.db.journey[SELF.guid]
Check(j, "setup: no route")

--------------------------------------------------------------------------
Section("only a fisher listens")

mock.professions = { { name = "First Aid", rank = 40, max = 75, line = 129 } }
ns.Fire("SD_WORLD_SETTLED")
Check(not ns._test.Fishing().listening, "a character with no Fishing listens")

mock.professions = { { name = "First Aid", rank = 40, max = 75, line = 129 },
    { name = "Fishing", rank = 1, max = 75, line = 356 } }
mock.fire("SKILL_LINES_CHANGED")
Check(ns._test.Fishing().listening, "learning Fishing did not start the listening")

mock.professions = { { name = "First Aid", rank = 40, max = 75, line = 129 } }
mock.fire("SKILL_LINES_CHANGED")
Check(not ns._test.Fishing().listening, "a character who lost Fishing still listens")

local askProfessions, readProfession = _G.GetProfessions, _G.GetProfessionInfo
_G.GetProfessions, _G.GetProfessionInfo = nil, nil
mock.professions = {}
ns.Fire("SD_WORLD_SETTLED")
Check(ns._test.Fishing().listening, "a client with no professions to ask left the fisher unheard")
_G.GetProfessions, _G.GetProfessionInfo = askProfessions, readProfession
mock.professions = { { name = "Fishing", rank = 1, max = 75, line = 356 } }
mock.fire("SKILL_LINES_CHANGED")
Check(ns._test.Fishing().listening, "setup: the fisher does not listen")

--------------------------------------------------------------------------
Section("a catch")

mock.now = mock.now + 10
Open({ Item("Raw Spotted Yellowtail") })
Eq(#Fi.List(j), 1, "the catch on the route")
local rec = Fi.List(j)[1]
Eq(rec.name, "Raw Spotted Yellowtail", "its item")
Eq(rec.mapID, 1412, "its map")
Eq(rec.x, 0.26, "its x")
Eq(rec.y, 0.81, "its y")
Eq(rec.t, mock.now, "its time")
Close()

--------------------------------------------------------------------------
Section("loot that is not a catch")

mock.now = mock.now + 10
Open({ Item("Long Tail Feather") }, false)
Eq(#Fi.List(j), 1, "a kill's loot was a catch")
Close()

--------------------------------------------------------------------------
Section("a window seen again while it is open is one catch")

mock.now = mock.now + 10
Open({ Item("Raw Brilliant Smallfish") })
Eq(#Fi.List(j), 2, "setup: the second catch")
mock.now = mock.now + 5
Open({ Item("Raw Brilliant Smallfish") })
Eq(#Fi.List(j), 2, "the same window, fired again, was a second catch")
Close()

--------------------------------------------------------------------------
Section("a catch within the guard of the last is the same one")

mock.now = mock.now + 10
Open({ Item("Oily Blackmouth") })
Eq(#Fi.List(j), 3, "setup: the third catch")
Close()
mock.now = mock.now + 1
Open({ Item("Oily Blackmouth") })
Eq(#Fi.List(j), 3, "a catch within the guard of the last was a second one")
Close()

mock.now = mock.now + 10
Open({ Item("Oily Blackmouth") })
Eq(#Fi.List(j), 4, "a catch some time after the last was not a catch")
Close()

-- A window that was never told to close is shut after a while.
mock.now = mock.now + 10
Open({ Item("Raw Spotted Yellowtail") })
Eq(#Fi.List(j), 5, "setup: a window left open")
mock.now = mock.now + 300
Open({ Item("Raw Spotted Yellowtail") })
Eq(#Fi.List(j), 6, "a window left open for minutes hid the next catch")
Close()

--------------------------------------------------------------------------
Section("what the loot holds")

mock.now = mock.now + 10
Open({ { name = "5 Copper", kind = 2, link = nil }, Item("Tangled Fishing Line") })
Eq(Fi.List(j)[7].name, "Tangled Fishing Line", "money first: the item named")
Close()

mock.now = mock.now + 10
Open({ { name = "", link = "|cffffffff|Hitem:2:::|h[Stringy Fish]|h|r", kind = 1 } })
Eq(Fi.List(j)[8].name, "Stringy Fish", "a name read off the link")
Close()

mock.now = mock.now + 10
Open({})
Eq(#Fi.List(j), 9, "an empty window was no catch")
Eq(Fi.List(j)[9].name, nil, "its name")
Close()

--------------------------------------------------------------------------
Section("no position, no route kept")

mock.now = mock.now + 10
mock.position = nil
Open({ Item("Raw Spotted Yellowtail") })
Eq(#Fi.List(j), 9, "a catch with no position was kept")
Close()
mock.position = { x = 0.26, y = 0.81 }

mock.now = mock.now + 10
ns.db.settings.keepRoute = false
Open({ Item("Raw Spotted Yellowtail") })
Eq(#Fi.List(j), 9, "a catch was kept with the route off")
Close()
ns.db.settings.keepRoute = true

--------------------------------------------------------------------------
Section("the record's own limits")

local long = Fi.Add(j, { t = mock.now, name = string.rep("x", 200) })
Check(long and #long.name <= 60, "a name longer than the guard")
Eq(Fi.Add(nil, { name = "x" }), nil, "a catch on no route")
