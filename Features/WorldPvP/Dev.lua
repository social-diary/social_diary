-- World PvP's part of /sd testdata (Dev/TestData.lua, TestData.Register):
-- the made-up route's two fight marks, so Your Diary's plates have a fight
-- on them. Development tooling: listed in the TOC's do-not-package block,
-- and left out by .pkgmeta.
--
-- Marks only, as the route keeps them (Journey.Fight, the core's: kind
-- "fight" on j.marks); no fight rows on anyone, as before the move. They
-- are the only marks the script writes, so writing them at "route", after
-- the route, leaves j.marks in the order it had.

local addonName, ns = ...

local TestData = ns.TestData
local DAY = 24 * 60 * 60
local BARRENS = 1413

TestData.Register("route", function(c)
    local j, J = c.j, ns.Journey
    -- Level 11: lost a fight at the Forgotten Pools, ten minutes before
    -- leaving them; with a stranger, so no one is named, only described as
    -- the mark keeps them (Journey.Foe: "a level 14 Dwarf Hunter / killed
    -- you" on its strip, 20 Nov 2026).
    local lost = J.Fight(j, "lost", nil, c.Stop(11, "The Forgotten Pools").to - 600,
        { mapID = BARRENS, x = 0.45, y = 0.46 })
    if lost then lost.foe = { level = 14, race = "Dwarf", raceID = 3, class = "HUNTER", classID = 3, sex = 2 } end
    -- At the cap: won one by Lushwater Oasis with Tester, on the evening
    -- Tester was first met, six days ago (TestData.Write; the oasis stop that
    -- begins 300 s in). Timed off now as that stop is: c.Stop finds the
    -- first stop at a level and place, and the oasis has an earlier one at
    -- 16.
    J.Fight(j, "won", TestData.GUID, c.now - 6 * DAY + 1500, { mapID = BARRENS, x = 0.57, y = 0.44 })
end)
