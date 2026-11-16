-- Fishing's part of /sd testdata (Dev/TestData.lua, TestData.Register): the
-- made-up route's catches, placed for cases on Your Diary's plates.
-- Development tooling: listed in the TOC's do-not-package block, and left
-- out by .pkgmeta.

local addonName, ns = ...

local TestData = ns.TestData
local BARRENS = 1413

-- The route's catches (ns.Fishing.Add's records), as capture keeps them:
-- one a fish fished up, oldest first.
TestData.Register("route", function(c)
    local j, Stop = c.j, c.Stop
    j.catches = {}
    local function Catch(at, map, x, y, name)
        j.catches[#j.catches + 1] = { t = at, mapID = map, x = x, y = y, name = name }
    end
    -- Level 15, the raptor grounds: a shore fished for a quarter of an hour,
    -- four catches on one spot (one mark, told in its tooltip), and one
    -- more from another bank.
    local raptors = Stop(15, "Raptor Grounds").to
    Catch(raptors - 3000, BARRENS, 0.34, 0.84, "Raw Spotted Yellowtail")
    Catch(raptors - 2800, BARRENS, 0.34, 0.84, "Raw Spotted Yellowtail")
    Catch(raptors - 2600, BARRENS, 0.34, 0.84, "Tangled Fishing Line")
    Catch(raptors - 2400, BARRENS, 0.34, 0.84, "Raw Brilliant Smallfish")
    Catch(raptors - 1000, BARRENS, 0.55, 0.74, "Oily Blackmouth")
end)
