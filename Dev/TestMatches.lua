-- Battleground matches' part of /sd testdata (Dev/TestData.lua,
-- TestData.Register; Core/Matches.lua has the record): an evening of four
-- (three Warsongs and an Alterac, so the overview is drawn and the roll
-- turns over) in the route's last sitting, and a lone Arathi Basin that was
-- left before its end, a few days before. Tester is with you in three;
-- Feivel is against you in all four. Development tooling: listed in the
-- TOC's do-not-package block. Invented names only.

local addonName, ns = ...

local TestData = ns.TestData
local Matches = ns.Matches
local MIN, HOUR, DAY = 60, 60 * 60, 24 * 60 * 60

local FIRST = { "Brannoc", "Koko", "Ysolde", "Corwin", "Hesk", "Pell", "Odo", "Varla", "Tamsin", "Dagny",
    "Rook", "Thessaly", "Oswin", "Wenna", "Grimble", "Ilsabet", "Linnet", "Sorrel", "Quill", "Hollis",
    "Bryn", "Maeren", "Varek", "Tobin", "Halvard", "Sigrun", "Edda", "Ansel", "Bertil", "Aldous",
    "Briony", "Cedric", "Delphine", "Edric", "Flora", "Gisla", "Haldis", "Jorund", "Ketlin", "Linbek",
    "Magdis", "Osrold", "Permir", "Ravard", "Sigmir", "Torna", "Ulvard", "Vedis", "Wildis", "Yrlin" }
local LAST = { "Ashgrove", "Brightwater", "Coldmere", "Dunmoor", "Emberly", "Fernhollow", "Greyhill",
    "Hartwell", "Ironside", "Juniper", "Kettleby", "Larkspur", "Mossbank", "Nettlefold", "Oakhurst" }
local CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "DRUID", "HUNTER", "WARLOCK", "SHAMAN", "PALADIN" }
local RACES = { [0] = { "Orc", "Tauren", "Troll", "Undead" }, [1] = { "Human", "Dwarf", "Gnome", "Night Elf" } }

-- A made-up player, the n-th of the list: always the same for the same n.
local function Person(n, side)
    return {
        guid = ("Player-0000-%08X"):format(0x7E570000 + n),
        name = FIRST[(n - 1) % #FIRST + 1] .. " " .. LAST[(n * 7 - 1) % #LAST + 1],
        side = side,
        class = CLASSES[(n * 5 - 1) % #CLASSES + 1],
        race = RACES[side][(n - 1) % 4 + 1],
        kb = (n * 3) % 9, hk = 8 + (n * 7) % 25, deaths = (n * 5) % 8,
        damage = 4000 + (n * 3917) % 60000, healing = (n % 4 == 0) and 20000 + (n * 811) % 40000 or (n * 97) % 3000,
    }
end

local function Match(c, map, mapName, start, minutes, winner, us, them, extra)
    local me = c.me
    local players = { { guid = ns.ownGUID, name = ns.JoinName(ns.Characters.Name(ns.ownGUID)) or "You",
        side = 0, class = "WARRIOR", race = "Tauren", kb = 5, hk = 21, deaths = #extra.deaths, damage = 31000, healing = 900 } }
    for _, n in ipairs(us) do players[#players + 1] = Person(n, 0) end
    for _, n in ipairs(them) do players[#players + 1] = Person(n, 1) end
    for _, p in ipairs(extra.rows or {}) do players[#players + 1] = p end
    for _, p in ipairs(players) do
        if map == 489 then p.stats = { [42] = p.side == winner and (p.kb % 2) or 0, [44] = p.deaths % 3 } end
    end
    local m = Matches.New({ test = true, me = me, map = map, mapName = mapName, level = c.level,
        startedAt = start, endedAt = start + minutes * MIN, duration = minutes * MIN,
        faction = 0, winner = winner, state = extra.state or "complete", board = extra.state == nil or nil })
    for _, p in ipairs(players) do m.players[#m.players + 1] = Matches.Pack(p) end
    m.deaths = extra.deaths
    m.killers = extra.killers
    return m
end

local function Range(a, b) local t = {} for i = a, b do t[#t + 1] = i end return t end

TestData.Register("route", function(c)
    local now = c.now
    local tester = { guid = TestData.GUID, name = "Tester Testerson", side = 0, class = "SHAMAN", race = "Orc",
        kb = 3, hk = 19, deaths = 2, damage = 12000, healing = 26000 }
    local feivel = Person(1, 1)
    feivel.name = "Feivel Ashgrove"
    local ctx = { me = ns.ownGUID, level = c.j.test and c.j.test.level or nil }

    -- The evening: three Warsongs and an Alterac, back to back.
    local t = now - 3 * HOUR - 20 * MIN
    Match(ctx, 489, "Warsong Gulch", t, 22, 0, Range(2, 9), Range(10, 18),
        { rows = { tester, feivel }, deaths = { t + 6 * MIN, t + 15 * MIN }, killers = { "Feivel Ashgrove" } })
    t = t + 24 * MIN
    Match(ctx, 489, "Warsong Gulch", t, 31, 1, Range(19, 26), Range(27, 35),
        { rows = { feivel }, deaths = { t + 4 * MIN, t + 12 * MIN, t + 25 * MIN },
            killers = { "Feivel Ashgrove", nil, "Feivel Ashgrove" } })
    t = t + 33 * MIN
    Match(ctx, 489, "Warsong Gulch", t, 14, 0, Range(2, 9), Range(36, 44),
        { rows = { tester, feivel }, deaths = { t + 9 * MIN } })
    t = t + 16 * MIN
    local av = {}
    for i = 45, 83 do av[#av + 1] = i end
    Match(ctx, 30, "Alterac Valley", t, 48, 1, Range(84, 120), av,
        { rows = { tester, feivel }, deaths = { t + 10 * MIN, t + 22 * MIN, t + 30 * MIN, t + 41 * MIN } })

    -- A lone Arathi Basin, left early, three days before: no board.
    local a = now - 3 * DAY + 20 * HOUR
    local names = {}
    for _, n in ipairs(Range(121, 133)) do local p = Person(n, 0) names[#names + 1] = { name = p.name, side = 0, class = p.class } end
    for _, n in ipairs(Range(134, 146)) do local p = Person(n, 1) names[#names + 1] = { name = p.name, side = 1 } end
    Match(ctx, 529, "Arathi Basin", a, 9, nil, {}, {}, { state = "left", rows = names, deaths = { a + 5 * MIN } })
end)

TestData.Register("remove", function()
    for _, m in ipairs(Matches.All()) do
        if m.test then Matches.Remove(m.id) end
    end
    if ns.Touch then ns.Touch() end
end)
