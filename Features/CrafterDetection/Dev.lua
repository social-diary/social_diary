-- Crafter detection's part of /sd testdata (Dev/TestData.lua,
-- TestData.Register): two connections with Tester, one each way, as
-- records on the made-up route. Development tooling: listed in the TOC's
-- do-not-package block, and left out by .pkgmeta.
--
-- Only the route is written, so /sd testdata remove takes everything with
-- it: no "remove" of its own. The plates' moment comes
-- with its mark (UI build, phase 8), which may move these to the levels
-- its cases want.

local addonName, ns = ...

local TestData = ns.TestData
local CrafterDetection = ns.CrafterDetection

local BARRENS, STONETALON = 1413, 1442

-- Invented items, linked as the client links them.
local BOOTS = "|cffffffff|Hitem:2302::::::::14:::::::::|h[Handstitched Leather Boots]|h|r"
local BRACERS = "|cff1eff00|Hitem:6070::::::::15:::::::::|h[Wolfskin Bracers]|h|r"

-- Rows on Tester come with the UI build (phase 8): a row in one of
-- Tester's sessions changes the lines other tests expect of them
-- (tests/timeline.lua's 3-hour session), so where they land is decided
-- with the timeline row's look.

-- On the route, as capture keeps them (j.craftMeets, oldest first), timed
-- off stops: one on a level-12 plate, one on a level-15 plate.
TestData.Register("route", function(c)
    local j, Stop = c.j, c.Stop
    j.craftMeets = {
        { t = Stop(12, "Windshear Crag").to - 700, mapID = STONETALON, x = 0.69, y = 0.60, guid = TestData.GUID,
            dir = CrafterDetection.THEIRS, id = 2302, link = BOOTS, how = "trade" },
        { t = Stop(15, "Raptor Grounds").to - 1200, mapID = BARRENS, x = 0.44, y = 0.82, guid = TestData.GUID,
            dir = CrafterDetection.YOURS, id = 6070, link = BRACERS, how = "auction" },
    }
end)
