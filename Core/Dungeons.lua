-- What the diary knows about a dungeon: its floors (map art), its bosses
-- and where they stand, its wings, and the usual way through it. From
-- Dungeon Crawler Forever's data (Vendor/DungeonCrawlerForever, ns.DCF;
-- .claude/dungeon-visits-prd.md §17), read only here, so the rest of the
-- addon never learns its shapes. Keyed by instanceID, the id
-- GetInstanceInfo gives and visits keep.
--
-- Only the canvas is read: art, floors, boss positions, the route, the
-- entrance, and which boss drops what (to place loot). Tactics (the
-- bosses' `how`, abilities, quests) and drop rates are not.
--
-- A floor is { uiMapID, name, w, h, ... } in one of four shapes: client art
-- (tile, tiles[row][col] = FileDataID), Forever art in yards (yards = true,
-- tiles = { {FileDataID, x, y, size} }), drawn art (custom = true, tiles of
-- addon paths) and a combined map (combined = true). UI/Map/Dungeon.lua
-- draws all four. A boss is { id (DungeonEncounterID), name, order, floor,
-- x, y, display | portrait, trash, summoned, sub }.

local addonName, ns = ...

local Dungeons = {}
ns.Dungeons = Dungeons

local function DCF() return ns.DCF or {} end

local function Norm(name)
    return (tostring(name or ""):lower():gsub("[^%w]", ""))
end
Dungeons.Norm = Norm

local function Record(instanceID)
    local list = DCF().Dungeons
    return list and list[instanceID]
end

-- Whether the diary has anything on this dungeon.
function Dungeons.Known(instanceID)
    return Record(instanceID) ~= nil
end

function Dungeons.Wings(instanceID)
    local wings = DCF().Wings
    return wings and wings[instanceID]
end

local function Wing(instanceID, wing)
    for _, w in ipairs(Dungeons.Wings(instanceID) or {}) do
        if w.wing == wing then return w end
    end
end

-- The dungeon's name, or its wing's ("Scarlet Monastery - Library").
function Dungeons.Name(instanceID, wing)
    local w = wing and Wing(instanceID, wing)
    if w then return w.name end
    local d = Record(instanceID)
    return d and d.name
end

-- The wing a boss belongs to (INS-27: a visit to a shared instance is
-- named after the wing of its first kill), or nil.
function Dungeons.WingOf(instanceID, bossName)
    local key = Norm(bossName)
    for _, w in ipairs(Dungeons.Wings(instanceID) or {}) do
        for name in pairs(w.bosses or {}) do
            if Norm(name) == key then return w.wing end
        end
    end
end

-- The art sources, drawn art first: a boss's floor is a drawn map's when
-- the dungeon has one, so the order is the data's, not a taste.
local function Sources(instanceID)
    local d = DCF()
    return {
        d.ArtCustom and d.ArtCustom[instanceID] or {},
        d.ArtData and d.ArtData[instanceID] or {},
        d.ArtForever and d.ArtForever[instanceID] or {},
    }
end

local function Combined(instanceID, floors)
    local c = DCF().Combined and DCF().Combined[instanceID]
    if not c or not floors then return floors end
    Dungeons.combined = Dungeons.combined or {}
    local cf = Dungeons.combined[instanceID]
    if not cf then
        cf = { uiMapID = 900000 + instanceID, combined = true, w = c.w, h = c.h,
            data = c, instanceID = instanceID }
        Dungeons.combined[instanceID] = cf
    end
    local out = {}
    for i, fl in ipairs(floors) do out[i] = fl end
    out[#out + 1] = cf
    return out
end

-- The floors to show, in order, or nil when there is no art. A wing with a
-- floor list of its own shows only those.
function Dungeons.Floors(instanceID, wing)
    local src = Sources(instanceID)
    local all = (#src[1] > 0 and src[1]) or (#src[2] > 0 and src[2])
        or (#src[3] > 0 and src[3]) or nil
    local w = wing and Wing(instanceID, wing)
    if w and w.floors then
        if #w.floors == 0 then return nil end
        local out = {}
        for _, id in ipairs(w.floors) do
            local fl = Dungeons.Floor(instanceID, id)
            if fl then out[#out + 1] = fl end
        end
        if #out > 0 then return Combined(instanceID, out) end
    end
    return Combined(instanceID, all)
end

-- One floor by its uiMapID, from any source (a combined map's pieces are
-- cut from these).
function Dungeons.Floor(instanceID, floorID)
    for _, list in ipairs(Sources(instanceID)) do
        for _, fl in ipairs(list) do
            if fl.uiMapID == floorID then return fl end
        end
    end
    local c = Dungeons.combined and Dungeons.combined[instanceID]
    if c and c.uiMapID == floorID then return c end
end

-- The art credit to print beside a drawn map, or nil.
function Dungeons.Credit(instanceID)
    local credits = DCF().ArtCredits
    local c = credits and credits[instanceID]
    return c and c.text
end

-- Every art credit the data carries, each once, in the order of the
-- dungeons they are for: { { text, dungeons = { name, ... } } }. For the
-- About page's Licensing part.
function Dungeons.Credits()
    local credits = DCF().ArtCredits or {}
    local ids = {}
    for id in pairs(credits) do ids[#ids + 1] = id end
    table.sort(ids)
    local out, byText = {}, {}
    for _, id in ipairs(ids) do
        local text = credits[id].text
        if text then
            local c = byText[text]
            if not c then
                c = { text = text, dungeons = {} }
                byText[text] = c
                out[#out + 1] = c
            end
            c.dungeons[#c.dungeons + 1] = Dungeons.Name(id) or tostring(id)
        end
    end
    return out
end

-- Forever keeps the normal list under difficulties 0 and 1 together; other
-- ids are modes of their own. Exact match, else normal, else the lowest.
local NORMAL = { [0] = true, [1] = true }

-- The bosses for a difficulty (and wing), in the dungeon's order. The
-- records are DCF's: read them, never write them.
function Dungeons.Bosses(instanceID, difficultyID, wing)
    local d = Record(instanceID)
    if not d then return {} end
    local present = {}
    for _, b in ipairs(d.bosses) do present[b.diff] = true end
    local want = {}
    if difficultyID and present[difficultyID] and not NORMAL[difficultyID] then
        want[difficultyID] = true
    elseif present[0] or present[1] then
        want[0], want[1] = true, true
    else
        local lowest
        for diff in pairs(present) do
            if not lowest or diff < lowest then lowest = diff end
        end
        want[lowest] = true
    end

    local w = wing and Wing(instanceID, wing)
    local out, seen = {}, {}
    for _, b in ipairs(d.bosses) do
        if want[b.diff] and not seen[b.name] and (not w or w.bosses[b.name]) then
            seen[b.name] = true
            out[#out + 1] = b
        end
    end
    table.sort(out, function(a, b)
        if a.num or b.num then
            if a.num and b.num then return a.num < b.num end
            return a.num ~= nil
        end
        return a.order < b.order
    end)
    return out
end

function Dungeons.IsRare(instanceID, bossName)
    local rares = DCF().Rares and DCF().Rares[instanceID]
    if not rares then return false end
    if rares[bossName] then return true end
    local key = Norm(bossName)
    for name in pairs(rares) do
        if Norm(name) == key then return true end
    end
    return false
end

-- A boss that counts towards "4 of 6": not trash, not summoned, not part
-- of another fight, not a rare.
function Dungeons.Counts(instanceID, boss)
    return not (boss.trash or boss.summoned or boss.sub)
        and not Dungeons.IsRare(instanceID, boss.name)
end

-- DCF's catch-all for what trash drops: not a boss, and its table proves
-- no kill.
function Dungeons.IsTrash(boss)
    return boss ~= nil and (boss.trash == true or Norm(boss.name) == "trash"
        or Norm(boss.name):find("^trash") ~= nil)
end

-- How many bosses a full run has (INS-14), or nil for a dungeon we don't
-- know.
function Dungeons.BossTotal(instanceID, difficultyID, wing)
    if not Record(instanceID) then return nil end
    local n = 0
    for _, b in ipairs(Dungeons.Bosses(instanceID, difficultyID, wing)) do
        if Dungeons.Counts(instanceID, b) then n = n + 1 end
    end
    return n
end

-- A boss by encounter id or by name (any case, any punctuation).
function Dungeons.Boss(instanceID, idOrName)
    local d = Record(instanceID)
    if not d or idOrName == nil then return nil end
    local key = type(idOrName) == "string" and Norm(idOrName)
    for _, b in ipairs(d.bosses) do
        if b.id == idOrName or (key and Norm(b.name) == key) then return b end
    end
end

-- The boss whose loot table holds an item (MAP-11), or nil. An item on two
-- tables gives the first in the dungeon's order. Drop rates are not read.
function Dungeons.LootBoss(instanceID, itemID)
    local loot = DCF().Loot and DCF().Loot[instanceID]
    itemID = tonumber(itemID)
    if not loot or not itemID then return nil end
    for _, b in ipairs(Record(instanceID) and Record(instanceID).bosses or {}) do
        for _, entry in ipairs(loot[b.name] or {}) do
            if entry[1] == itemID then return b end
        end
    end
end

-- The usual way through the dungeon, ours (Core/DungeonRoutes.lua) before
-- DCF's: { {f = floor, x, y, boss,
-- kind}, ... }, or nil. It is the usual way, not the user's (MAP-4).
function Dungeons.Route(instanceID, wing)
    local ours = ns.DungeonRoutes and ns.DungeonRoutes[instanceID]
    if ours and ours[wing or 0] then return ours[wing or 0] end
    local routes = DCF().RouteData and DCF().RouteData[instanceID]
    return routes and routes[wing or 0]
end

-- The entrance on a floor, { x, y }, or nil. The other markers are
-- wayfinding and are not read (D12).
function Dungeons.Entrance(instanceID, floorID)
    local markers = DCF().Markers and DCF().Markers[instanceID]
    for _, m in ipairs(markers and markers[floorID] or {}) do
        if m.kind == "entrance" then return { x = m.x, y = m.y } end
    end
end

-- Where a point of one floor's art (srcFloorID, x, y) falls on the floor
-- shown: fractions of its art, or nil when it is not on it. A combined
-- map looks the point up in its pieces.
function Dungeons.Point(floor, srcFloorID, x, y)
    if not floor or not x or not y then return nil end
    if floor.combined then
        for _, p in ipairs(floor.data.pieces or {}) do
            if p.floor == srcFloorID then
                local sf = Dungeons.Floor(floor.instanceID, p.floor)
                if sf then
                    local px, py = x * sf.w, y * sf.h
                    if px >= p.x0 and px <= p.x1 and py >= p.y0 and py <= p.y1 then
                        return (p.dx + (px - p.x0) * p.s) / floor.w,
                            (p.dy + (py - p.y0) * p.s) / floor.h
                    end
                end
            end
        end
        return nil
    end
    if tonumber(srcFloorID) == floor.uiMapID then return x, y end
end

-- A visit's killed bosses as DCF records, in the order they fell. A name
-- the data doesn't know is left out here (the visit still names it).
-- A name the data doesn't know is looked up through the run's pulls: the
-- client's name for an encounter the data names otherwise, by its id
-- (runs saved before kills were kept under the data's name).
function Dungeons.Killed(visit)
    local out, seen = {}, {}
    for _, name in ipairs(visit and visit.bossesKilled or {}) do
        local b = Dungeons.Boss(visit.instanceID, name)
        if not b then
            for _, p in ipairs(visit.pulls or {}) do
                if p.killed and p.name == name and p.id then b = Dungeons.Boss(visit.instanceID, p.id) end
            end
        end
        if b and not seen[b] then
            seen[b] = true
            out[#out + 1] = b
        end
    end
    return out
end

-- The floor a visit mostly took place on: the one most of its kills stand
-- on, else the first. Ties go to the earlier floor.
function Dungeons.MainFloor(visit, wing)
    local floors = visit and Dungeons.Floors(visit.instanceID, wing)
    if not floors or #floors == 0 then return nil, nil end
    local count = {}
    for _, b in ipairs(Dungeons.Killed(visit)) do
        local f = tonumber(b.floor)
        if f then count[f] = (count[f] or 0) + 1 end
    end
    local best, bestN = 1, 0
    for i, fl in ipairs(floors) do
        local n = count[fl.uiMapID] or 0
        if n > bestN then best, bestN = i, n end
    end
    return floors[best], best
end
