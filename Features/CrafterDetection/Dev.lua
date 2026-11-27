-- Crafter detection's part of /sd testdata (Dev/TestData.lua,
-- TestData.Register): connections on the made-up route, one of each case
-- the plates show on a plate of its own (the UI build, phase 8).
-- Development tooling: listed in the TOC's do-not-package block, and left
-- out by .pkgmeta.
--
-- On the route, as capture keeps them (j.craftMeets, oldest first), timed
-- off stops:
--   - level 12 (its first sitting): Kaelin Ashby wore the boots you made
--     them (theirs, a trade): the card at L in the one plate's column;
--   - level 13, the Crossroads: Garrow Vey gave you the Blood Ring you
--     wear (yours, a trade), the same ring Upgrades' card shows on that
--     plate (Features/Upgrades/Dev.lua: the ring put on there): the
--     upgrade card wins, and the connection keeps only its needle;
--   - the cap's second week, on the road down to Razorfen Kraul (its
--     second sitting): Thessalindra Moonwhisper in the cloak you made her
--     (theirs, an auction), a plate opened for her alone, in the two
--     plates' narrow lower column, where her hand-off will not go on one
--     line even by her first name: no card, and the caption's tail names
--     her;
--   - the cap's last sitting, the Crossroads: two at one plate, Tester in
--     the tunic you made them (theirs, a trade; Tester is in the diary, so
--     the needle joins their marks and their note says it too) and the
--     gloves Bramwell Pike sold you (yours, an auction), in time order:
--     Tester's card at M, Bramwell's, the later, left to its needle as the
--     room goes.
-- (27 Nov, the main session: this list re-read against the records below
-- and the UI build's renders; it had the cases' first placing.)
-- The strangers are pencilled in at "route" and forgotten at "remove"
-- (and again before they are written, as a second /sd testdata replaces
-- the first). No rows on Tester: one in a Tester session changes the lines
-- tests/timeline.lua pins.

local addonName, ns = ...

local TestData = ns.TestData
local CrafterDetection = ns.CrafterDetection
local Link = TestData.Link

local BARRENS, STONETALON = 1413, 1442
local THEIRS, YOURS = CrafterDetection.THEIRS, CrafterDetection.YOURS

-- Invented items (ids no other feature's test data uses), but the boots
-- and Upgrades' ring.
local BOOTS = Link(1, 2302, "Handstitched Leather Boots")
local RING = Link(2, 4998, "Blood Ring")
local TUNIC = Link(2, 90431, "Stitched Wolfhide Tunic")
local GLOVES = Link(2, 90432, "Dustwalker Gloves")
local CLOAK = Link(2, 90433, "Embroidered Moonweave Cloak")

-- Who they are (Characters.Observe's fields); CrafterDetection.STRANGERS,
-- for the tests.
local STRANGERS = {
    garrow = { guid = "Player-0000-7E57E5C0", first = "Garrow", surname = "Vey", class = "WARRIOR", race = "Orc",
        level = 14, sex = 2 },
    kaelin = { guid = "Player-0000-7E57E5C1", first = "Kaelin", surname = "Ashby", class = "DRUID", race = "Tauren",
        level = 18, sex = 3 },
    bramwell = { guid = "Player-0000-7E57E5C2", first = "Bramwell", surname = "Pike", class = "ROGUE",
        race = "Scourge", level = 20, sex = 2 },
    thessalindra = { guid = "Player-0000-7E57E5C3", first = "Thessalindra", surname = "Moonwhisper",
        class = "PRIEST", race = "BloodElf", level = 19, sex = 3 },
}
CrafterDetection.STRANGERS = STRANGERS

local function Forget()
    for _, who in pairs(STRANGERS) do ns.Characters.Forget(who.guid) end
end

TestData.Register("route", function(c)
    local j, Stop = c.j, c.Stop
    local S = STRANGERS
    -- (the road down to Razorfen Kraul, the cap's last sitting but one:
    -- the route's own, Dev/TestData.lua, `now - 4 * HOUR`)
    local kraul = c.now - 4 * 60 * 60
    local crossroads = Stop(16, "The Crossroads")
    -- (forgotten before the records are written: forgetting someone clears
    -- their GUID off the records, Kind.lua's `forget`)
    Forget()
    j.craftMeets = {
        { t = Stop(12, nil).to - 400, mapID = BARRENS, x = 0.305, y = 0.285, guid = S.kaelin.guid,
            dir = THEIRS, id = 2302, link = BOOTS, how = "trade" },
        { t = Stop(13, "The Crossroads").to - 250, mapID = BARRENS, x = 0.522, y = 0.302, guid = S.garrow.guid,
            dir = YOURS, id = 4998, link = RING, how = "trade" },
        { t = kraul + 150, mapID = BARRENS, x = 0.60, y = 0.16, guid = S.thessalindra.guid,
            dir = THEIRS, id = 90433, link = CLOAK, how = "auction" },
        { t = crossroads.from + 300, mapID = BARRENS, x = 0.518, y = 0.296, guid = TestData.GUID,
            dir = THEIRS, id = 90431, link = TUNIC, how = "trade" },
        { t = crossroads.from + 600, mapID = BARRENS, x = 0.526, y = 0.306, guid = S.bramwell.guid,
            dir = YOURS, id = 90432, link = GLOVES, how = "auction" },
    }
    for _, rec in ipairs(j.craftMeets) do
        for _, who in pairs(S) do
            if who.guid == rec.guid then
                ns.Characters.Observe(who.guid, { first = who.first, surname = who.surname, class = who.class,
                    race = who.race, level = who.level, sex = who.sex, faction = "Horde", time = rec.t })
            end
        end
    end
end)

TestData.Register("remove", Forget)
