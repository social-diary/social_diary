-- Where the user is (prd.md section 7; SIG-3, INT-1, SES-4).
--
-- The diary stores the *user's own* position, never the other player's. Two
-- reasons, and both matter: the API does not expose a stranger's coordinates
-- at all, and storing someone else's whereabouts is exactly the "tool for
-- tracking people" reading the PRD sets out to avoid.
--
-- Session 1 confirmed this build uses the retail map system: GetBestMapForUnit
-- returned 1412 in Mulgore and all four zone-text calls worked.

local addonName, ns = ...

-- Map coordinates are 0..1 floats. Three decimals is roughly a step's
-- precision at zone scale and keeps stored rows short (DAT-3).
local function Round(value)
    if type(value) ~= "number" then return nil end
    return math.floor(value * 1000 + 0.5) / 1000
end

-- A name the client gave, or nil: during a loading screen the zone texts
-- are "", which would be saved as a zone with no name (", Stormwind City"
-- in a session's headline, 20 Oct).
local function Named(value)
    value = ns.Plain(value)
    if value == "" then return nil end
    return value
end

-- Instances get a name and an id but no coordinates: prd.md section 7 says
-- "zone only inside instances", and a dungeon's map position is noise.
local function InstanceContext(where)
    if not IsInInstance then return false end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end

    where.instanceType = ns.Plain(instanceType)

    if GetInstanceInfo then
        local name, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
        where.zone = Named(name) or where.zone
        where.instanceID = ns.Plain(instanceID)
        where.difficultyID = ns.Plain(difficultyID)
    end

    return true
end

-- One call, one snapshot. Everything that stores a row asks for this rather
-- than reading the map itself, so the secret-gating lives in one place.
function ns.Where()
    local where = {}

    where.zone = Named(GetRealZoneText and GetRealZoneText())
        or Named(GetZoneText and GetZoneText())

    if InstanceContext(where) then
        return where
    end

    local mapID = ns.Plain(C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    if not mapID then return where end

    where.mapID = mapID

    -- 12.0.5 added restricted-map rules, so the position can come back secret
    -- even though the map id did not.
    local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if position and not ns.IsSecret(position) and position.GetXY then
        local x, y = position:GetXY()
        where.x, where.y = Round(ns.Plain(x)), Round(ns.Plain(y))
    end

    where.subZone = ns.Plain(GetSubZoneText and GetSubZoneText())
    if where.subZone == "" then where.subZone = nil end

    return where
end

--------------------------------------------------------------------------
-- Map names
--------------------------------------------------------------------------
--
-- Rows keep the map id rather than its name (DAT-3), so every surface that
-- shows a place asks here. A map the client cannot describe gives nil, and
-- each caller says that in its own words.

local function MapInfo(mapID)
    if not mapID or not (C_Map and C_Map.GetMapInfo) then return nil end
    return C_Map.GetMapInfo(mapID)
end

function ns.MapName(mapID)
    local info = MapInfo(mapID)
    return info and ns.Plain(info.name) or nil
end

-- One step up the map tree: a city's districts and a zone's sub-maps have
-- the city or zone as their parent.
function ns.MapParent(mapID)
    local info = MapInfo(mapID)
    return info and ns.Plain(info.parentMapID) or nil
end

-- A stored row's place: the map's name, else the zone name kept for maps
-- without an id (Core/Sightings.lua), else nil.
function ns.RowZone(row)
    return ns.MapName(row.mapID) or row.zone
end

--------------------------------------------------------------------------
-- Cities (SIG-5)
--------------------------------------------------------------------------

-- Whether the user is in a city, by the settings' city list: the matched map
-- id or zone name, "sanctuary", or nil. Capture/Sightings.lua pauses on it.
--
-- The city list holds map ids and, as a fallback, zone names. A city's own
-- sub-maps count, so the map's parents are checked too. IsResting is not the
-- signal: it is just as true in a small town's inn, which SIG-5 says is not a
-- city. A sanctuary is, wherever it is.
function ns.City()
    if GetZonePVPInfo and ns.Plain(GetZonePVPInfo()) == "sanctuary" then
        return "sanctuary"
    end

    local cities = ns.db.settings.cities
    local mapID = C_Map and C_Map.GetBestMapForUnit and ns.Plain(C_Map.GetBestMapForUnit("player"))
    for _ = 1, 4 do
        if type(mapID) ~= "number" then break end
        if cities[mapID] then return mapID end
        mapID = ns.MapParent(mapID)
    end

    local zone = ns.Plain(GetRealZoneText and GetRealZoneText())
    if type(zone) == "string" and cities[zone] then return zone end

    return nil
end

--------------------------------------------------------------------------
-- The zone map (JRN-5)
--------------------------------------------------------------------------
--
-- Your Diary draws the route on zone sheets, so its positions have to be on
-- the zone's own map. GetBestMapForUnit is often something smaller: a cave,
-- a building, a city district, each with its own 0..1 square that does not
-- line up with the zone's. Their parents lead up to the zone (map type 3),
-- and a position on one is moved onto the zone through world space. ns.Where
-- above is left as it is: the rows other modules store keep the best map.

local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3

-- The zone map `mapID` lies in: itself for a zone, the first zone among its
-- parents for anything smaller, nil for a continent or the world above one
-- (or a map the client cannot describe, like the Deeprun Tram's lack of one).
function ns.ZoneOf(mapID)
    for _ = 1, 6 do
        if type(mapID) ~= "number" or mapID <= 0 then return nil end
        local info = MapInfo(mapID)
        local kind = info and ns.Plain(info.mapType)
        if type(kind) ~= "number" then return nil end
        if kind == ZONE then return mapID end
        if kind < ZONE then return nil end
        mapID = ns.Plain(info.parentMapID)
    end
    return nil
end

-- Positions a little past the map's edge happen; they read as the edge.
local function Clamped(value)
    return Round(math.max(0, math.min(1, value)))
end

-- A position on `fromMap` moved onto `toMap` through world space, or nil
-- when the client cannot say. Every call is guarded: none of the three is
-- verified in this build.
local function Project(fromMap, toMap, x, y)
    if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, continent, world = pcall(C_Map.GetWorldPosFromMapPos, fromMap, CreateVector2D(x, y))
    if not ok or not world or ns.IsSecret(world) or ns.IsSecret(continent) then return nil end
    local done, _, pos = pcall(C_Map.GetMapPosFromWorldPos, continent, world, toMap)
    if not done or not pos or ns.IsSecret(pos) or not pos.GetXY then return nil end
    local px, py = pos:GetXY()
    px, py = ns.Plain(px), ns.Plain(py)
    if type(px) ~= "number" or type(py) ~= "number" then return nil end
    return px, py
end
ns.ProjectMapPos = Project

-- Where the user is on the zone map: zone map id, x, y (0..1, rounded and
-- clamped), or nil -- in an instance, off any zone, with the position
-- secret, or on a sub-map that cannot be moved onto its zone. A point that
-- cannot be placed is skipped, never stored as zone coordinates.
function ns.ZoneWhere()
    if IsInInstance and ns.Plain((IsInInstance())) == true then return nil end

    local best = ns.Plain(C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    if type(best) ~= "number" then return nil end
    local zone = ns.ZoneOf(best)
    if not zone then return nil end

    local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(best, "player")
    if not position or ns.IsSecret(position) or not position.GetXY then return nil end
    local x, y = position:GetXY()
    x, y = ns.Plain(x), ns.Plain(y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end

    if best ~= zone then
        x, y = Project(best, zone, x, y)
        if not x then return nil end
    end
    -- Also unrounded (clamped), for Your Diary's stop shapes.
    return zone, Clamped(x), Clamped(y), math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

-- Where the user stands in the world, in yards, and the instance id that
-- says which world: x, y, instance (UnitPosition hands y first), or nil. Outdoors only; thresholds are measured in these, never in map
-- units, which are a different distance in every zone (JRN-1).
function ns.WorldWhere()
    if not UnitPosition then return nil end
    local y, x, _, instance = UnitPosition("player")
    x, y, instance = ns.Plain(x), ns.Plain(y), ns.Plain(instance)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, instance
end
