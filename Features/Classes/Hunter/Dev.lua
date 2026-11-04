-- A hunter's tames' part of /sd testdata (Dev/TestData.lua,
-- TestData.Register): the made-up route's two pets, one named and one not.
-- Development tooling: listed in the TOC's do-not-package block, and left
-- out by .pkgmeta (Features/*/*/Dev.lua).

local addonName, ns = ...

local TestData = ns.TestData
local DUROTAR, BARRENS = 1411, 1413

-- The route's tames (ns.Hunter.Tamed's records), as capture keeps them,
-- oldest first. The made-up character need not be a hunter: the page shows
-- what the route holds.
TestData.Register("route", function(c)
    local j, Stop = c.j, c.Stop
    j.tames = {}
    local function Tame(stop, ago, map, x, y, rec)
        rec.t, rec.mapID, rec.x, rec.y, rec.level = stop.to - ago, map, x, y, stop.level
        j.tames[#j.tames + 1] = rec
    end
    -- Level 10, Sen'jin Village: the first pet, kept after two tried and let
    -- go within the hour (n = 3), and given a name.
    Tame(Stop(10, "Sen'jin Village"), 120, DUROTAR, 0.36, 0.64, { npcID = 3099, beast = "Dire Mottled Boar",
        family = "Boar", petLevel = 9, name = "Bristlemane", n = 3 })
    -- Level 14, Camp Taurajo: a second pet, its name not read yet (the
    -- client's own, its family's).
    Tame(Stop(14, "Camp Taurajo"), 900, BARRENS, 0.45, 0.60, { npcID = 3425, beast = "Savannah Prowler",
        family = "Cat", petLevel = 13, n = 1 })
end)
