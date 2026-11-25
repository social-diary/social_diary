-- City trips' part of /sd testdata (Dev/TestData.lua, TestData.Register):
-- the made-up route's trips to Orgrimmar, so the sheet has all three
-- weights to draw. Development tooling: listed in the TOC's
-- do-not-package block, and left out by .pkgmeta.
--
-- The trips as capture keeps them (Kind.lua, j.trips, the record's
-- contract), at "route", each timed off the Orgrimmar stop it lies in:
--   - level 11, the Valley of Strength (the hearthstone in, a flight out):
--     a usual round, seven lines. Two lots put up, Linen Cloth bought,
--     a Linen Bag sold to Tester (a diary entry) and one come back, a
--     letter from Tester with coin in it, a bag sent to someone the diary
--     does not know, a quest handed in with Tester on it; and a green
--     vest bought at the auction house, which the made-up route's
--     upgrades have put on in town half way through (Features/Upgrades/
--     Dev.lua): offered to this sheet as an errand, "put on", its own stop;
--   - level 16, the Valley of Strength (flown in from the Crossroads): the
--     heavy round, the whole twenty minutes of it. Dozens of bolts and
--     bags made one at a time (each kind one entry with its count), lots
--     put up and sold past the lists' caps (their last entries carry the
--     rest), a stack of letters from strangers (counted, never named),
--     Tailoring climbing 22 points, recipes learnt, quests both ways;
--   - level 16 again, a few minutes after that stop (the made-up route
--     keeps nothing between it and the next day): the thin one, a quest
--     handed in and the next taken, two lines, below "a real round".
-- Nothing lands off the route (the only person in them is Tester, written
-- by the script itself), so there is no "remove" of its own.

local addonName, ns = ...

local TestData = ns.TestData
local ORGRIMMAR = 1454
local MIN = 60

-- Item ids, as the client knows them.
local LINEN, BOLT_LINEN, WOOL, BOLT_WOOL = 2589, 2996, 2592, 2997
local LINEN_BAG, WOOLEN_BAG, GLOVES, BOOTS = 4238, 4241, 4307, 2569
local THREAD, SHIRT, CLOAK, BELT, BRACERS = 2320, 2568, 2580, 4329, 4313
local TAILORING = 197
local VEST = 90411 -- (invented, as Upgrades' Dev.lua's)

TestData.Register("route", function(c)
    local j = c.j
    local tester = TestData.GUID
    j.trips = {}

    local usual = c.Stop(11, "Valley of Strength")
    j.trips[#j.trips + 1] = { t = usual.from, to = usual.to, mapID = ORGRIMMAR, x = usual.x, y = usual.y,
        level = 11, came = 4120, left = 6380,
        up = { { id = BOLT_LINEN, n = 4 }, { id = LINEN_BAG, n = 2 } },
        bought = { { id = LINEN, n = 20, paid = 160, others = 1 }, { id = VEST, n = 1, paid = 1450, others = 1 } },
        sold = { { id = LINEN_BAG, n = 1, got = 380, who = { tester } } },
        back = 1,
        letters = { { from = tester, n = 1, items = 1, coin = 2500 } },
        sent = { { n = 1, items = 1 } },
        quests = { { id = 840, title = "Conscript of the Horde", out = true, with = { tester } } },
    }

    local heavy = c.Stop(16, "Valley of Strength")
    j.trips[#j.trips + 1] = { t = heavy.from, to = heavy.to, mapID = ORGRIMMAR, x = heavy.x, y = heavy.y,
        level = 16, came = 18450, left = 31270,
        up = { { id = BOLT_WOOL, n = 10 }, { id = WOOLEN_BAG, n = 6 }, { id = GLOVES, n = 4 },
            { id = BOOTS, n = 3 }, { id = SHIRT, n = 5 }, { id = CLOAK, n = 2 }, { rest = true, n = 7 } },
        bought = { { id = WOOL, n = 60, paid = 1800, others = 3 }, { id = THREAD, n = 20, paid = 200, others = 1 } },
        sold = { { id = WOOLEN_BAG, n = 4, got = 4400, who = { tester }, others = 3 },
            { id = GLOVES, n = 3, got = 1350, others = 3 }, { id = BOLT_WOOL, n = 8, got = 1600, others = 5 },
            { id = BELT, n = 2, got = 300, others = 2 }, { id = SHIRT, n = 5, got = 450, others = 5 },
            { name = "Simple Kilt", n = 2, got = 760, others = 2 },
            { rest = true, n = 6, got = 900, others = 6 } },
        back = 4,
        letters = { { from = tester, n = 2, items = 3, coin = 5000 }, { n = 7, items = 12, coin = 1500 } },
        sent = { { to = tester, n = 1, items = 2 }, { n = 2, items = 5, coin = 1000 } },
        made = { { id = BOLT_WOOL, n = 24 }, { id = WOOLEN_BAG, n = 9 }, { id = GLOVES, n = 6 },
            { id = BELT, n = 4 }, { id = BRACERS, n = 3 }, { id = BOLT_LINEN, n = 10 } },
        skills = { { line = TAILORING, name = "Tailoring", from = 118, to = 140 } },
        recipes = { 3843, 3844, 3845, 3848 },
        quests = { { id = 5726, title = "Hidden Enemies", out = true, others = 1 },
            { id = 5727, title = "Hidden Enemies" },
            { id = 809, title = "Ak'Zeloth", out = true } },
    }

    j.trips[#j.trips + 1] = { t = heavy.to + 6 * MIN, to = heavy.to + 7 * MIN, mapID = ORGRIMMAR,
        x = heavy.x, y = heavy.y, level = 16, came = 31270, left = 32020,
        quests = { { id = 5728, title = "Hidden Enemies", out = true },
            { id = 5729, title = "Hidden Enemies" } },
    }
end)
