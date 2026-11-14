-- Gathering's part of /sd testdata (Dev/TestData.lua, TestData.Register):
-- the made-up route's nodes, placed for cases on Your Diary's plates.
-- Development tooling: listed in the TOC's do-not-package block, and left
-- out by .pkgmeta.

local addonName, ns = ...

local TestData = ns.TestData
local BARRENS, STONETALON = 1413, 1442

-- The route's nodes (ns.Gathering.Add's records), as capture keeps them:
-- one a node gathered, oldest first.
TestData.Register("route", function(c)
    local j, Stop = c.j, c.Stop
    j.nodes = {}
    local function Node(at, map, x, y, kind, name)
        j.nodes[#j.nodes + 1] = { t = at, mapID = map, x = x, y = y, kind = kind, name = name }
    end
    -- Level 15, the raptor grounds: a vein worked three times over (one
    -- mark, told in its tooltip), another vein not far off, and a herb
    -- picked on the spot of a vein, then another herb there too (one mark,
    -- the sprig, for the kind there is more of; its tooltip tells both).
    local raptors = Stop(15, "Raptor Grounds").to
    Node(raptors - 2400, BARRENS, 0.40, 0.80, "ore", "Copper Vein")
    Node(raptors - 2300, BARRENS, 0.40, 0.80, "ore", "Copper Vein")
    Node(raptors - 2200, BARRENS, 0.40, 0.80, "ore", "Copper Vein")
    Node(raptors - 1800, BARRENS, 0.45, 0.77, "ore", "Tin Vein")
    Node(raptors - 1500, BARRENS, 0.50, 0.83, "herb", "Peacebloom")
    Node(raptors - 1400, BARRENS, 0.50, 0.83, "ore", "Tin Vein")
    Node(raptors - 1300, BARRENS, 0.50, 0.83, "herb", "Silverleaf")
    -- Level 12, the crag: three herbs along the way, each on a spot of its
    -- own.
    local crag = Stop(12, "Windshear Crag").to
    Node(crag - 900, STONETALON, 0.69, 0.64, "herb", "Silverleaf")
    Node(crag - 800, STONETALON, 0.75, 0.57, "herb", "Earthroot")
    Node(crag - 500, STONETALON, 0.67, 0.55, "herb", "Peacebloom")
end)
