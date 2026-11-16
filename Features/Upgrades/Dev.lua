-- Upgrades' part of /sd testdata (Dev/TestData.lua, TestData.Register):
-- the made-up route's upgrades, so Your Diary's plates have them, and the
-- line on Tester for the gift that was worn. Development tooling: listed
-- in the TOC's do-not-package block, and left out by .pkgmeta.
--
-- The upgrades as capture keeps them (Kind.lua, j.upgrades: a list by the
-- first put-on), at "route", after the route: each at the stop it was put
-- on at, timed off that stop's end. They follow the firsts' story
-- (Features/Firsts/Dev.lua), so the same item is seen found and then
-- worn:
--   - level 10, Razor Hill: green gloves bought, over white ones: an
--     upgrade that is no first found, so its card shows what it replaced;
--   - level 11, the Sludge Fen: the quest's green bracers, put on a
--     minute after they were found, over white ones (a green at 20 or
--     below: it leads its entry), and a looted green belt after them, a
--     smaller gain (a filler piece);
--   - level 13, the Crossroads: a green ring over a white one, with
--     nothing said of how it came (the card's plainest heading, "Newly
--     worn"). It was on an empty finger until 16 Nov, when an upgrade
--     came to be measured only against the last item of its own kind in
--     its slot: with nothing there before, it is no upgrade at all;
--   - level 15, the Raptor Grounds: the epic axe, over a white one;
--   - at the cap, the Crossroads: Tester's blue cloak (ns.Trade.GIFT),
--     put on four minutes after the trade, over a green one: a gift.
-- The gift's row on Tester is written at "tester", in today's last
-- session, after that session's trade and its whispers (this file loads
-- after Trade's and Chat's Dev.lua).

local addonName, ns = ...

local TestData = ns.TestData
local Upgrades = ns.Upgrades
local Link = TestData.Link
local DUROTAR, BARRENS = 1411, 1413
local MIN = 60

local GLOVES = Link(2, 4767, "Hardened Leather Gloves")
local OLD_GLOVES = Link(1, 1422, "Worn Leather Gloves")
local BRACERS = Link(2, 6070, "Wolfskin Bracers")
local OLD_BRACERS = Link(1, 1423, "Worn Leather Bracers")
local BELT = Link(2, 4697, "Burnished Girdle")
local OLD_BELT = Link(1, 1419, "Worn Leather Belt")
local RING = Link(2, 4998, "Blood Ring")
local OLD_RING = Link(1, 5000, "Tarnished Copper Band")
local GUTWRENCHER = Link(4, 5616, "Gutwrencher")
local OLD_AXE = Link(1, 853, "Hatchet")
local OLD_CLOAK = Link(2, 4771, "Harvest Cloak")

-- How long after the trade the gift was put on.
local GIFT_WORN = 4 * MIN

TestData.Register("route", function(c)
    local j = c.j
    j.upgrades = {}
    local function Wore(stop, at, x, y, slot, link, quality, ilvl, from, was, wasIlvl, found, giver, map)
        j.upgrades[#j.upgrades + 1] = { t = at, mapID = map or BARRENS, x = x, y = y, level = stop.level, link = link,
            key = Upgrades.Key(link), quality = quality, slot = slot, ilvl = ilvl, from = from, guid = giver,
            found = found, was = was and { link = was, ilvl = wasIlvl } or nil }
    end

    local stop = c.Stop(10, "Razor Hill")
    Wore(stop, stop.to - 300, 0.475, 0.545, 10, GLOVES, 2, 15, "vendor", OLD_GLOVES, 5, stop.to - 330, nil, DUROTAR)
    stop = c.Stop(11, "The Sludge Fen")
    Wore(stop, stop.to - 140, 0.61, 0.14, 9, BRACERS, 2, 17, "quest", OLD_BRACERS, 5, stop.to - 200)
    Wore(stop, stop.to - 60, 0.612, 0.15, 6, BELT, 2, 16, "loot", OLD_BELT, 10, stop.to - 80)
    stop = c.Stop(13, "The Crossroads")
    Wore(stop, stop.to - 300, 0.525, 0.305, 11, RING, 2, 15, nil, OLD_RING, 8, stop.to - 900)
    stop = c.Stop(15, "Raptor Grounds")
    Wore(stop, stop.to - 640, 0.45, 0.80, 16, GUTWRENCHER, 4, 24, "loot", OLD_AXE, 9, stop.to - 700)
    local gift = ns.Trade.GIFT
    stop = c.Stop(16, "The Crossroads")
    Wore(stop, c.now - gift.ago + GIFT_WORN, 0.535, 0.31, 15, gift.link, 3, 23, "trade", OLD_CLOAK, 18,
        c.now - gift.ago, TestData.GUID)
end)

TestData.Register("tester", function(c)
    if c.n ~= 4 then return end
    local gift = ns.Trade.GIFT
    c.Row("gift_worn", c.now - gift.ago + GIFT_WORN, "The Barrens", { context = { link = gift.link } }, c.session)
end)
