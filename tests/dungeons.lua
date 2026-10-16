-- What the diary knows about dungeons (Core/Dungeons.lua over Dungeon
-- Crawler Forever's data in Vendor/): floors, bosses, totals, wings, the
-- route, and that nothing else reads ns.DCF (SYNC-2).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Dungeons = ns.Dungeons

local RFK, WC, THANES, SM = 47, 43, 3065, 189

--------------------------------------------------------------------------
Section("the vendored data loads into ns.DCF")

Check(type(ns.DCF) == "table" and type(ns.DCF.Dungeons) == "table", "no DCF dungeons")
Check(ns.DCF.ArtData and ns.DCF.ArtForever and ns.DCF.ArtCustom, "an art table is missing")
Check(ns.Rares ~= ns.DCF.Rares, "DCF's Rares landed on the addon's namespace")
Check(Dungeons.Known(RFK) and Dungeons.Known(THANES), "a dungeon is unknown")
Eq(Dungeons.Known(999999), false, "a made-up dungeon is known")
Eq(Dungeons.Name(THANES), "The Hall of Thanes", "name")

--------------------------------------------------------------------------
Section("floors: client art, drawn art first")

local floors = Dungeons.Floors(RFK)
Eq(#floors, 1, "Razorfen Kraul floors")
Eq(floors[1].uiMapID, 301, "Razorfen Kraul is the client's map 301")
Check(type(floors[1].tiles[1][1]) == "number", "client art is not a FileDataID")

local wcFloor = Dungeons.Floors(WC)[1]
Check(wcFloor.custom, "Wailing Caverns does not use its drawn map")
Check(wcFloor.tiles[1][1]:find("social_diary\\Vendor\\DungeonCrawlerForever\\Art", 1, true),
    "a drawn tile does not point into Vendor/")

local thanes = Dungeons.Floors(THANES)[1]
Eq(thanes.uiMapID, 830651, "The Hall of Thanes' floor")
Eq(Dungeons.Floor(THANES, 930651).yards, true, "the Forever art in yards is not found by id")
Eq(Dungeons.Floors(999999), nil, "an unknown dungeon has floors")

local credits = Dungeons.Credits()
Eq(#credits, 1, "the art credits, each once")
Check(credits[1].text:find("Santiago Reyes", 1, true), "the credit's text")
Eq(#credits[1].dungeons, 4, "the dungeons the credit is for")

--------------------------------------------------------------------------
Section("bosses, and how many count")

local bosses = Dungeons.Bosses(THANES)
Eq(#bosses, 4, "The Hall of Thanes' bosses")
Eq(bosses[1].name, "Faldrim Anvilmar", "first boss")
Eq(bosses[4].name, "Durgen Dirgehammer", "last boss")
Eq(Dungeons.BossTotal(THANES), 4, "The Hall of Thanes' total")
Eq(Dungeons.Boss(THANES, 3494).name, "Plunder", "a boss by encounter id")
Eq(Dungeons.Boss(THANES, "durgen dirgehammer").id, 3496, "a boss by name, any case")

-- Razorfen Kraul: Roogug is a rare and the trash is not a boss.
Eq(Dungeons.IsRare(RFK, "Roogug"), true, "Roogug is a rare")
Eq(Dungeons.BossTotal(RFK), 5, "Razorfen Kraul counts a rare or the trash")
Eq(Dungeons.BossTotal(999999), nil, "a total for an unknown dungeon")

--------------------------------------------------------------------------
Section("wings")

Eq(Dungeons.WingOf(SM, "Arcanist Doan"), 2, "Doan's wing")
Eq(Dungeons.Name(SM, 2), "Scarlet Monastery - Library", "a wing's name")
Eq(#Dungeons.Floors(SM, 2), 1, "a wing shows its own floor")
Eq(Dungeons.Floors(SM, 2)[1].uiMapID, 303, "the Library's floor")
for _, b in ipairs(Dungeons.Bosses(SM, nil, 2)) do
    Check(Dungeons.WingOf(SM, b.name) == 2, b.name .. " is listed for the Library")
end

--------------------------------------------------------------------------
Section("a visit's floor and kills")

local visit = { instanceID = THANES, bossesKilled = { "Faldrim Anvilmar", "Plunder", "Nobody" } }
Eq(#Dungeons.Killed(visit), 2, "a name the data doesn't know is a kill")
local main, index = Dungeons.MainFloor(visit)
Eq(main, thanes, "main floor")
Eq(index, 1, "main floor's index")
Eq(Dungeons.MainFloor({ instanceID = 999999 }), nil, "an unknown dungeon has a main floor")

--------------------------------------------------------------------------
Section("points on a floor, the route, the entrance")

local faldrim = Dungeons.Boss(THANES, "Faldrim Anvilmar")
local x, y = Dungeons.Point(thanes, faldrim.floor, faldrim.x, faldrim.y)
Eq(x, faldrim.x, "a boss on the floor shown keeps its x")
Eq(y, faldrim.y, "... and its y")
Eq(Dungeons.Point(thanes, 301, 0.5, 0.5), nil, "a point on another floor is placed")

local route = Dungeons.Route(36)
Check(route and #route > 2, "the Deadmines have no route")
Eq(route[1].kind, "entrance", "a route starts at the entrance")
Check(Dungeons.Entrance(THANES, 830651) ~= nil, "The Hall of Thanes has no entrance")

-- Our own route for The Hall of Thanes (Core/DungeonRoutes.lua): DCF has
-- none. It runs on the floor shown and stops at every boss, in order.
local thanesRoute = Dungeons.Route(THANES)
Check(thanesRoute and #thanesRoute > 10, "The Hall of Thanes has no route")
local stops = {}
for _, p in ipairs(thanesRoute) do
    Eq(p.f, 830651, "a route point on another floor")
    if p.boss then
        Check(Dungeons.Boss(THANES, p.boss) ~= nil, "a route stop at a boss the data doesn't know: " .. p.boss)
        stops[#stops + 1] = p.boss
    end
end
Eq(table.concat(stops, ","), "Faldrim Anvilmar,Magmatus,Plunder,Durgen Dirgehammer", "the route's stops")

--------------------------------------------------------------------------
Section("every boss stands on a floor that has art (SYNC-2)")

for id, d in pairs(ns.DCF.Dungeons) do
    for _, b in ipairs(d.bosses) do
        if b.floor and b.x then
            Check(Dungeons.Floor(id, tonumber(b.floor)) ~= nil or Dungeons.Floors(id) == nil,
                ("%s (%d): %s stands on floor %s, which has no art"):format(d.name, id, b.name, tostring(b.floor)))
        end
    end
end

--------------------------------------------------------------------------
Section("only Core/Dungeons.lua reads ns.DCF (SYNC-2)")

local root = "."
local function Read(path)
    local f = io.open(root .. "/" .. path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local toc = assert(Read("social_diary.toc"), "no toc")
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua$") and not line:match("^#") and not line:match("^Vendor/")
        and line ~= "Core/Dungeons.lua" then
        local src = Read(line)
        Check(src == nil or not src:find("ns%.DCF"), line .. " reads ns.DCF")
    end
end
