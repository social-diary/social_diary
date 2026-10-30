-- Your Diary: the logged-in character's own road through the world (prd.md
-- 8.11, JRN-1 to JRN-20).
--
-- Only ever the user's own position, like everything else the addon stores
-- (Core/Location.lua): where you went, so that the diary can say who you
-- were with on the way. Never anyone else's whereabouts.
--
-- Capture (Capture/Journey.lua) hands this file a sample every few seconds
-- -- the time, the position in yards and on the zone map -- and this file
-- compacts them as they come, into segments:
--
--   stop     staying in one place a while: a grinding spot, an inn, a city
--   road     the way between stops, a breadcrumb every few yards, thinned
--   flight   a taxi, from take-off to landing
--   dungeon  an instance, pinned at the spot it was entered from
--
-- Distances are yards in world space (UnitPosition), never map units, which
-- are a different distance in every zone. The zone map's 0..1 coordinates
-- are kept for drawing only. Nothing raw is kept, except in the debug ring
-- buffer (JRN-18).
--
-- db.journey[charGUID] = { startedAt, startLevel, startMapID, levels,
-- segments, marks, open }
-- (prd.md section 7), and a list of its own for each feature that
-- registered one (Journey.RegisterList), or what else a feature keeps on
-- the route (its Features/<Name>/Kind.lua says). `open` is
-- the working state: the stop or road being built, saved so that a /reload
-- carries on where it was (JRN-20), and never read by the UI.
--
-- The compaction is plain functions over that record, so the tests drive it
-- with made-up samples and no client at all.

local addonName, ns = ...

local Journey = {}
ns.Journey = Journey

-- D14: the numbers, to tune with real routes. Seconds and yards.
local T = {
    tick = 5,           -- capture's timer
    gap = 60,           -- a tick this long after the last is a pause (JRN-2)
    radius = 60,        -- a stop: staying within this...
    dwell = 180,        -- ...for this long (JRN-3)
    busyDwell = 30,     -- ...or this long, where something happened there:
    busyCombat = 15,    -- this much fighting, a quest, or a death (JRN-6)
    excursion = 45,     -- out of a stop's radius and back within this stays in it
    rMin = 15, rMax = 150,  -- a stop's spread, clamped
    step = 25,          -- a breadcrumb once this far from the last kept one (JRN-4)
    tolerance = 15,     -- Douglas-Peucker, when a road closes
    teleport = 200,     -- a jump this long ends the road, with no line across it
    points = 64,        -- at most this many points a road
    crumbs = 200,       -- a road this long in breadcrumbs is cut, and carries on
    mergeGap = 600,     -- two stops on one spot this close in time are one
    mergeRoad = 180,    -- ...when the road between them is no longer than this
    entryAge = 60,      -- a dungeon's entry spot, a flight's take-off: this fresh
    city = 60,          -- less time in a city than this is no stop
    raw = 5000,         -- the debug ring buffer's points (JRN-18)
    marks = 1000,       -- fights kept a character, the oldest strangers' first
    -- (a feature's list adds its own cap here as it registers:
    -- Journey.RegisterList)
}
Journey.T = T

-- Bumped on every write the recap reads (JourneyRecap's cache). In memory
-- only, like ns.dataVersion, and kept apart from it: the route moves every
-- few minutes, and the People index has no reason to rebuild for it.
Journey.version = 0

local function Touch()
    Journey.version = Journey.version + 1
end
Journey.Touch = Touch

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------

-- Three decimals like every stored position (ns.Where), clamped to the map.
local function Round(v)
    v = math.max(0, math.min(1, v))
    return math.floor(v * 1000 + 0.5) / 1000
end
Journey.Round = Round

local function Dist(a, b)
    local dx, dy = a.wx - b.wx, a.wy - b.wy
    return math.sqrt(dx * dx + dy * dy)
end

-- Whether `b` can be measured from `a`: same zone map, same world.
local function Comparable(a, b)
    return a.mapID == b.mapID and a.inst == b.inst
end

local function AddAct(into, act)
    if not act then return into end
    into = into or {}
    for key, n in pairs(act) do into[key] = (into[key] or 0) + n end
    return into
end

-- The record a segment is written as. `levelTo` is the level at its end.
local function Segment(o, kind, from, to, mapID, levelFrom)
    return { kind = kind, from = from, to = to, mapID = mapID,
        levelFrom = levelFrom or o.level, levelTo = o.level }
end

--------------------------------------------------------------------------
-- How segments are saved (JRN-19)
--------------------------------------------------------------------------
--
-- In memory a segment is the table prd.md section 7 describes, and every
-- reader gets it that way (Journey.Segments). Saved, each is one line of
-- text: SavedVariables writes a table one field a line, about twenty bytes
-- a value, and a levelling run's thirteen hundred segments came to well
-- over the budget that way. As a line, a stop is about sixty characters:
--
--   s;from;duration;mapID;levelFrom;levelTo;x;y;r;seconds;act;subZone
--   S;from;duration;mapID;levelFrom;levelTo;x;y;r;seconds;sdx;sdy;rho;act;subZone
--   r;from;duration;mapID;levelFrom;levelTo;pts
--   f;from;duration;mapID;levelFrom;levelTo;mapID1;x1;y1;mapID2;x2;y2
--   d;from;duration;mapID;levelFrom;levelTo;instanceID;instanceType;x;y;seconds;name
--
-- `S` is a stop with its shape (since 9 Oct 2026): sdx and sdy, how far
-- the time spent there spread across and down the zone map (one standard
-- deviation, in hundred-thousandths of the map), and rho, how the two lean
-- together (hundredths, -100 to 100). The sheet draws it as an ellipse.
-- Times are epoch seconds, positions thousandths of the map, `act` a
-- letter and a number for each thing done ("c300o2": 300 s fighting, two
-- quests turned in). An empty field is nil; levelTo is empty when it is
-- levelFrom, and a stop's seconds when they are its duration. Text comes
-- last, so a name can hold anything. A road or a dungeon with something done
-- on it is an R or a D: its act comes before its last field, and an r or a d
-- has none (nothing was saved of it before these two). A segment saved as a
-- table (an older build, a test) is read as it is.

local KIND = { stop = "s", road = "r", flight = "f", dungeon = "d" }
local KIND_OF = { s = "stop", S = "stop", r = "road", R = "road", f = "flight", d = "dungeon", D = "dungeon" }
local ACT = { { "combat", "c" }, { "questsIn", "i" }, { "questsOut", "o" }, { "deaths", "d" }, { "resting", "r" } }
local ACT_OF = {}
for _, a in ipairs(ACT) do ACT_OF[a[2]] = a[1] end

local function Int(v)
    return type(v) == "number" and tostring(math.floor(v + 0.5)) or ""
end

local function Milli(v)
    return type(v) == "number" and tostring(math.floor(v * 1000 + 0.5)) or ""
end

local function PackAct(act)
    if not act then return "" end
    local parts = {}
    for _, a in ipairs(ACT) do
        local n = act[a[1]]
        if n and n >= 0.5 then parts[#parts + 1] = a[2] .. Int(n) end
    end
    return table.concat(parts)
end

local function Pack(seg)
    local duration = seg.to - seg.from
    local shaped = seg.kind == "stop" and seg.sdx ~= nil
    local kind = seg.kind
    local act = (kind == "road" or kind == "dungeon") and PackAct(seg.act) or ""
    local letter = shaped and "S" or KIND[kind]
    if act ~= "" then letter = letter:upper() end
    local fields = { letter, Int(seg.from), Int(duration), Int(seg.mapID),
        Int(seg.levelFrom), seg.levelTo ~= seg.levelFrom and Int(seg.levelTo) or "" }
    if kind == "stop" then
        fields[#fields + 1] = Milli(seg.x)
        fields[#fields + 1] = Milli(seg.y)
        fields[#fields + 1] = Int(seg.r)
        fields[#fields + 1] = seg.seconds ~= duration and Int(seg.seconds) or ""
        if shaped then
            fields[#fields + 1] = Int(seg.sdx * 100000)
            fields[#fields + 1] = Int(seg.sdy * 100000)
            fields[#fields + 1] = Int((seg.rho or 0) * 100)
        end
        fields[#fields + 1] = PackAct(seg.act)
        fields[#fields + 1] = seg.subZone or ""
    elseif kind == "road" then
        if act ~= "" then fields[#fields + 1] = act end
        fields[#fields + 1] = seg.pts or ""
    elseif kind == "flight" then
        fields[#fields + 1] = Int(seg.mapID1)
        fields[#fields + 1] = Milli(seg.x1)
        fields[#fields + 1] = Milli(seg.y1)
        fields[#fields + 1] = Int(seg.mapID2)
        fields[#fields + 1] = Milli(seg.x2)
        fields[#fields + 1] = Milli(seg.y2)
    else
        fields[#fields + 1] = Int(seg.instanceID)
        fields[#fields + 1] = seg.instanceType or ""
        fields[#fields + 1] = Milli(seg.x)
        fields[#fields + 1] = Milli(seg.y)
        fields[#fields + 1] = Int(seg.seconds)
        if act ~= "" then fields[#fields + 1] = act end
        fields[#fields + 1] = seg.name or ""
    end
    return table.concat(fields, ";")
end
Journey.Pack = Pack

-- How many fields each kind has: the last takes the rest of the line.
local FIELDS = { s = 12, S = 15, r = 7, R = 8, f = 12, d = 12, D = 13 }

local function UnpackAct(text)
    if not text or text == "" then return nil end
    local act = {}
    for letter, n in text:gmatch("(%a)(%d+)") do
        local key = ACT_OF[letter]
        if key then act[key] = tonumber(n) end
    end
    return act
end

local function Unpack(line)
    local letter = line:sub(1, 1)
    local kind = KIND_OF[letter]
    if not kind then return nil end
    local count = FIELDS[letter]
    local f, at = {}, 1
    for i = 1, count - 1 do
        local stop = line:find(";", at, true)
        if not stop then
            f[i] = line:sub(at)
            at = #line + 1
            break
        end
        f[i] = line:sub(at, stop - 1)
        at = stop + 1
    end
    if #f == count - 1 then f[count] = line:sub(at) end
    local function N(i) return tonumber(f[i] or "") end
    local function M(i) local n = N(i) return n and n / 1000 end
    local function S(i) return f[i] ~= "" and f[i] or nil end

    local from = N(2) or 0
    local seg = { kind = kind, from = from, to = from + (N(3) or 0), mapID = N(4), levelFrom = N(5) }
    seg.levelTo = N(6) or seg.levelFrom
    if kind == "stop" then
        seg.x, seg.y, seg.r = M(7), M(8), N(9)
        seg.seconds = N(10) or (seg.to - seg.from)
        local at = 11
        if letter == "S" then
            local sdx, sdy, rho = N(11), N(12), N(13)
            if sdx and sdy then seg.sdx, seg.sdy, seg.rho = sdx / 100000, sdy / 100000, (rho or 0) / 100 end
            at = 14
        end
        seg.act = UnpackAct(f[at])
        seg.subZone = S(at + 1)
    elseif kind == "road" then
        if letter == "R" then
            seg.act = UnpackAct(f[7])
            seg.pts = f[8] or ""
        else
            seg.pts = f[7] or ""
        end
    elseif kind == "flight" then
        seg.mapID1, seg.x1, seg.y1 = N(7), M(8), M(9)
        seg.mapID2, seg.x2, seg.y2 = N(10), M(11), M(12)
    else
        seg.instanceID, seg.instanceType = N(7), S(8)
        seg.x, seg.y, seg.seconds = M(9), M(10), N(11) or 0
        if letter == "D" then
            seg.act = UnpackAct(f[12])
            seg.name = S(13)
        else
            seg.name = S(12)
        end
    end
    return seg
end
Journey.Unpack = Unpack

-- The segments as tables, oldest first, decoded once and kept in memory
-- (weakly, by record) while nothing else changes the saved list.
local decoded = setmetatable({}, { __mode = "k" })

function Journey.Segments(j)
    if not j or not j.segments then return {} end
    local raw = j.segments
    local hit = decoded[j]
    if hit and hit.raw == raw and hit.n == #raw and hit.last == raw[#raw] then return hit.list end
    local list = {}
    for i = 1, #raw do
        local item = raw[i]
        list[#list + 1] = type(item) == "table" and item or Unpack(item)
    end
    decoded[j] = { raw = raw, n = #raw, last = raw[#raw], list = list }
    return list
end
local Segments = Journey.Segments

local function Push(j, seg)
    local list = Segments(j)
    local raw = j.segments
    raw[#raw + 1] = Pack(seg)
    list[#list + 1] = seg
    local hit = decoded[j]
    hit.n, hit.last = #raw, raw[#raw]
    Touch()
    return seg
end

-- Takes the newest segment back (Merge).
local function Pop(j)
    local list = Segments(j)
    local raw = j.segments
    raw[#raw] = nil
    list[#list] = nil
    local hit = decoded[j]
    hit.n, hit.last = #raw, raw[#raw]
end

--------------------------------------------------------------------------
-- The record
--------------------------------------------------------------------------

-- The logged-in character's, or nil before it began (Begin).
function Journey.Mine()
    local guid = ns.ownGUID
    return guid and ns.db.journey[guid] or nil
end

function Journey.For(guid)
    return guid and ns.db.journey[guid] or nil
end

-- JRN-13 and D10: a character's route starts the first time it is captured,
-- at the level and in the zone it is in then. Nothing before is made up.
function Journey.Begin(guid, now, level, mapID)
    if not guid then return nil end
    local j = ns.db.journey[guid]
    if not j then
        j = { startedAt = now, startLevel = level or 1, startMapID = mapID,
            levels = {}, segments = {}, marks = {} }
        ns.db.journey[guid] = j
        Touch()
    end
    j.levels, j.segments, j.marks = j.levels or {}, j.segments or {}, j.marks or {}
    -- Begun inside a dungeon, the zone comes with the first outdoor sample.
    if not j.startMapID and mapID then j.startMapID = mapID end
    return j
end

local function Open(j)
    local o = j.open
    if not o then
        o = {}
        j.open = o
    end
    return o
end

--------------------------------------------------------------------------
-- Roads (JRN-4)
--------------------------------------------------------------------------

-- Douglas-Peucker on the breadcrumbs, in yards: the indices kept.
local function Thin(crumbs, tolerance)
    local n = #crumbs
    local keep = { [1] = true, [n] = true }
    local stack = { 1, n }
    while #stack > 0 do
        local last = table.remove(stack)
        local first = table.remove(stack)
        local a, b = crumbs[first], crumbs[last]
        local dx, dy = b.wx - a.wx, b.wy - a.wy
        local len = math.sqrt(dx * dx + dy * dy)
        local far, at = 0, nil
        for i = first + 1, last - 1 do
            local c = crumbs[i]
            local d
            if len == 0 then
                d = Dist(a, c)
            else
                d = math.abs(dy * (c.wx - a.wx) - dx * (c.wy - a.wy)) / len
            end
            if d > far then far, at = d, i end
        end
        if at and far > tolerance then
            keep[at] = true
            stack[#stack + 1] = first
            stack[#stack + 1] = at
            stack[#stack + 1] = at
            stack[#stack + 1] = last
        end
    end
    local list = {}
    for i = 1, n do
        if keep[i] then list[#list + 1] = crumbs[i] end
    end
    return list
end

-- A road's points as the record keeps them: one short string, two
-- characters a coordinate (its thousandths, 0 to 1000, in a 64-letter
-- alphabet that SavedVariables writes as it is). A table of numbers is
-- written one value a line, which over a levelling run came to five times
-- the storage budget (JRN-19); the string keeps the same three decimals.
local DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VALUE = {}
for i = 1, #DIGITS do VALUE[DIGITS:byte(i)] = i - 1 end

local function Encode(v)
    local n = math.floor(math.max(0, math.min(1, v)) * 1000 + 0.5)
    local hi, lo = math.floor(n / 64), n % 64
    return DIGITS:sub(hi + 1, hi + 1) .. DIGITS:sub(lo + 1, lo + 1)
end

local function PackPoints(kept)
    local parts = {}
    for i = 1, #kept do
        parts[#parts + 1] = Encode(kept[i].x) .. Encode(kept[i].y)
    end
    return table.concat(parts)
end
Journey.PackPoints = function(flat)
    local kept = {}
    for i = 1, #flat, 2 do kept[#kept + 1] = { x = flat[i], y = flat[i + 1] } end
    return PackPoints(kept)
end

-- A road's points, flat: { x1, y1, x2, y2, ... } on its zone map. The one
-- way the sheet and the recap read them, so how a road is stored stays this
-- file's business. Unpacked once per road and remembered (weakly).
local unpacked = setmetatable({}, { __mode = "k" })

function Journey.Points(seg)
    local pts = seg.pts
    if type(pts) ~= "string" then return pts or {} end
    local hit = unpacked[seg]
    if hit and hit.pts == pts then return hit.list end
    local list = {}
    for i = 1, #pts - 1, 2 do
        local hi, lo = VALUE[pts:byte(i)], VALUE[pts:byte(i + 1)]
        if hi and lo then list[#list + 1] = (hi * 64 + lo) / 1000 end
    end
    unpacked[seg] = { pts = pts, list = list }
    return list
end

local function NewRoad(o, s)
    o.road = { mapID = s.mapID, inst = s.inst, levelFrom = s.level or o.level, crumbs = { s } }
    return o.road
end

-- Closes the road being built, if it has somewhere to go: thinned, capped,
-- and written. The last sample seen on it closes it even when the step
-- filter skipped it, so the road reaches where the player was.
local function CloseRoad(j, o)
    local road = o.road
    o.road = nil
    if not road then return nil end
    local crumbs = road.crumbs
    if road.tail and road.tail.t > crumbs[#crumbs].t then crumbs[#crumbs + 1] = road.tail end
    if #crumbs < 2 then
        if road.act then o.loose = AddAct(o.loose, road.act) end
        return nil
    end

    local tolerance = T.tolerance
    local kept = Thin(crumbs, tolerance)
    while #kept > T.points do
        tolerance = tolerance * 1.5
        kept = Thin(crumbs, tolerance)
    end
    if #kept < 2 then return nil end

    local seg = Segment(o, "road", crumbs[1].t, crumbs[#crumbs].t, road.mapID, road.levelFrom)
    seg.pts = PackPoints(kept)
    seg.act = road.act
    return Push(j, seg)
end

-- A breadcrumb, once the player is `step` yards from the last one kept. A
-- road too long to hold is closed there and carries on from its last point,
-- so the line is unbroken.
local function Crumb(j, o, s)
    local road = o.road or NewRoad(o, s)
    local crumbs = road.crumbs
    local last = crumbs[#crumbs]
    if last == s then return end
    if Dist(last, s) < T.step then
        road.tail = s
        return
    end
    crumbs[#crumbs + 1] = s
    road.tail = nil
    if #crumbs >= T.crumbs then
        CloseRoad(j, o)
        NewRoad(o, s)
    end
end

--------------------------------------------------------------------------
-- Stops (JRN-3)
--------------------------------------------------------------------------
--
-- A cluster is where the player might be staying. Until it is a stop it is
-- a window of the latest samples, all within the radius of their
-- time-weighted mean. A sample outside it is held as an excursion; only one
-- that stays out (or goes far) moves the window on, its oldest samples
-- dropped until the rest fit again. So grinding back and forth stays in one
-- window however the pulls swing, and steady travel slides through it.
-- Once the window spans the dwell time it is a stop: summed from then on,
-- relative to its first sample (exact arithmetic in a world whose yards
-- run to five digits), the road that led to it closed at its first sample,
-- and an excursion has to stay out to end it.

local function NewCluster(o, s)
    local c = { since = s.t, start = s.t, last = s.t, ox = s.wx, oy = s.wy,
        w = 0, sx = 0, sy = 0, sq = 0, zx = 0, zy = 0, zxx = 0, zyy = 0, zxy = 0,
        mapID = s.mapID, inst = s.inst, levelFrom = s.level or o.level,
        first = s, lastSample = s, extra = 0 }
    o.c = c
    return c
end

local function NewWindow(o, s)
    local c = { samples = { { s = s, w = 1 } }, since = s.t, last = s.t, mapID = s.mapID, inst = s.inst,
        levelFrom = o.level, act = o.loose }
    o.loose = nil
    o.c = c
    return c
end

-- The time-weighted mean of a window's samples from `from` on.
local function Mean(list, from)
    local w, x, y = 0, 0, 0
    for i = from, #list do
        local e = list[i]
        w, x, y = w + e.w, x + e.w * e.s.wx, y + e.w * e.s.wy
    end
    return x / w, y / w
end

local function Fits(list, from)
    local mx, my = Mean(list, from)
    local r2 = T.radius * T.radius
    for i = from, #list do
        local s = list[i].s
        if (s.wx - mx) ^ 2 + (s.wy - my) ^ 2 > r2 then return false end
    end
    return true
end

local function Weigh(c, s, w)
    w = math.max(w or 1, 1)
    local dx, dy = s.wx - c.ox, s.wy - c.oy
    c.w = c.w + w
    c.sx, c.sy = c.sx + w * dx, c.sy + w * dy
    c.sq = c.sq + w * (dx * dx + dy * dy)
    c.zx, c.zy = c.zx + w * s.x, c.zy + w * s.y
    -- Its shape, on the zone map itself, so it lies the way the map does.
    -- Only on a cluster that has summed it from its start: one summed
    -- before shapes were kept (a /reload across the update) or merged with
    -- one that was stays without a shape, as its squares would be missing
    -- the samples its means hold, and its variance come out wrong, even
    -- negative.
    if c.zxx then
        c.zxx = c.zxx + w * s.x * s.x
        c.zyy = c.zyy + w * s.y * s.y
        c.zxy = c.zxy + w * s.x * s.y
    end
    c.last, c.lastSample = math.max(c.last, s.t), s
end

local function Centre(c)
    if c.w <= 0 then return c.ox, c.oy end
    return c.ox + c.sx / c.w, c.oy + c.sy / c.w
end

local function DistToCentre(c, s)
    local cx, cy = Centre(c)
    local dx, dy = s.wx - cx, s.wy - cy
    return math.sqrt(dx * dx + dy * dy)
end

local function Spread(c)
    if c.w <= 0 then return T.rMin end
    local mx, my = c.sx / c.w, c.sy / c.w
    local var = c.sq / c.w - (mx * mx + my * my)
    local r = 2 * math.sqrt(math.max(var, 0))
    return math.floor(math.max(T.rMin, math.min(T.rMax, r)) + 0.5)
end

-- How the time spent in a cluster spread over the zone map: standard
-- deviations across and down (0..1 map units) and their correlation, or
-- nil for a cluster summed before shapes were kept (a /reload across the
-- update) or with too little in it to have a shape.
function Journey.Shape(c)
    local w = c.w or 0
    if w <= 0 or not (c.zxx and c.zyy and c.zxy) then return nil end
    local mx, my = c.zx / w, c.zy / w
    local vx, vy = c.zxx / w - mx * mx, c.zyy / w - my * my
    -- Sums that disagree with each other (a variance well below nothing)
    -- have no shape to give; a hair below is rounding.
    if vx < -1e-9 or vy < -1e-9 then return nil end
    vx, vy = math.max(vx, 0), math.max(vy, 0)
    local sdx, sdy = math.sqrt(vx), math.sqrt(vy)
    if sdx + sdy <= 0 then return nil end
    local rho = 0
    if sdx > 0 and sdy > 0 then rho = math.max(-1, math.min(1, (c.zxy / w - mx * my) / (sdx * sdy))) end
    return sdx, sdy, rho
end

local function StopSeconds(c)
    return c.extra + (c.last - c.start)
end

-- Writes the cluster as a stop. What it did stays with it.
local function CloseStop(j, o)
    local c = o.c
    o.c = nil
    local seg = Segment(o, "stop", c.since, c.last, c.mapID, c.levelFrom)
    seg.x = Round(c.w > 0 and c.zx / c.w or c.first.x)
    seg.y = Round(c.w > 0 and c.zy / c.w or c.first.y)
    seg.r = Spread(c)
    seg.sdx, seg.sdy, seg.rho = Journey.Shape(c)
    seg.seconds = StopSeconds(c)
    seg.act = c.act
    seg.subZone = c.subZone
    Push(j, seg)
    -- Kept to merge with, should the next stop be on this spot (JRN-3): by
    -- its place in the list, as the table itself is not what is saved.
    o.held = { index = #j.segments, ox = c.ox, oy = c.oy, w = c.w, sx = c.sx, sy = c.sy, sq = c.sq,
        zx = c.zx, zy = c.zy, zxx = c.zxx, zyy = c.zyy, zxy = c.zxy, mapID = c.mapID, inst = c.inst }
    return seg
end

-- A stop just made, on the spot of the one before it and soon after: the
-- two are one, and a short road between them goes. Returns whether it merged.
local function Merge(j, o, c)
    local held = o.held
    if not held or held.mapID ~= c.mapID or held.inst ~= c.inst then return false end
    local list = Segments(j)
    local n = #list
    local seg = list[held.index]
    if not seg or seg.kind ~= "stop" or held.index < n - 1 then return false end
    local between = held.index == n - 1 and list[n] or nil
    if between and (between.kind ~= "road" or between.to - between.from > T.mergeRoad) then return false end
    if c.since - seg.to > T.mergeGap then return false end

    local hx, hy = held.ox + held.sx / math.max(held.w, 1), held.oy + held.sy / math.max(held.w, 1)
    local cx, cy = Centre(c)
    if math.sqrt((hx - cx) ^ 2 + (hy - cy) ^ 2) > T.radius then return false end

    -- Back into one cluster, measured from the held one's origin.
    local dx, dy = c.ox - held.ox, c.oy - held.oy
    local w = c.w
    c.sq = held.sq + c.sq + 2 * (dx * c.sx + dy * c.sy) + w * (dx * dx + dy * dy)
    c.sx, c.sy = held.sx + c.sx + w * dx, held.sy + c.sy + w * dy
    c.ox, c.oy = held.ox, held.oy
    c.w = held.w + w
    c.zx, c.zy = held.zx + c.zx, held.zy + c.zy
    -- The shape only where both halves kept one: else the squares would
    -- miss half the samples the means hold, and the stop goes shapeless.
    if held.zxx and c.zxx then
        c.zxx, c.zyy, c.zxy = held.zxx + c.zxx, held.zyy + c.zyy, held.zxy + c.zxy
    else
        c.zxx, c.zyy, c.zxy = nil, nil, nil
    end
    c.extra = c.extra + seg.seconds
    c.since, c.levelFrom = seg.from, seg.levelFrom
    c.act = AddAct(AddAct(nil, seg.act), c.act)
    c.subZone = seg.subZone or c.subZone
    if between then c.act = AddAct(c.act, between.act) end

    Pop(j)
    if between then Pop(j) end
    o.held = nil
    Touch()
    return true
end

-- The cluster has stayed long enough: a stop. The road that led here ends
-- at the cluster's first sample.
local function Establish(j, o, c)
    -- From a window to sums.
    local list = c.samples
    local first = list[1].s
    c.samples = nil
    c.ox, c.oy, c.w, c.sx, c.sy, c.sq, c.zx, c.zy = first.wx, first.wy, 0, 0, 0, 0, 0, 0
    c.zxx, c.zyy, c.zxy = 0, 0, 0
    c.since, c.start, c.extra, c.first, c.lastSample = first.t, first.t, 0, first, first
    for i = 1, #list do Weigh(c, list[i].s, list[i].w) end

    local road = o.road
    -- A road cut and begun again inside the cluster led nowhere new.
    if road and road.crumbs[1].t > c.since then
        o.road = nil
        road = nil
    end
    if road then
        local crumbs = road.crumbs
        while #crumbs > 1 and crumbs[#crumbs].t > c.since do crumbs[#crumbs] = nil end
        if crumbs[#crumbs] ~= c.first then crumbs[#crumbs + 1] = c.first end
        road.tail = nil
        CloseRoad(j, o)
    end
    c.stop = true
    Merge(j, o, c)
end

-- Whether something happened in a place, enough to mark it on the road
-- even if the player did not stay long: a fight, a quest, a death. Level-
-- ups are rare; these are what a road is made of (JRN-3, JRN-6).
function Journey.Busy(act)
    if not act then return false end
    return (act.combat or 0) >= T.busyCombat or (act.questsIn or 0) > 0 or (act.questsOut or 0) > 0
        or (act.deaths or 0) > 0
end

-- What was done in a window that moved on was done on the way.
local function Passing(o, c)
    if not c.act then return end
    if o.road then o.road.act = AddAct(o.road.act, c.act) else o.loose = AddAct(o.loose, c.act) end
    c.act = nil
end

-- Following a moving player, who might be about to stay (above).
local function Candidate(j, o, s, w)
    local c = o.c
    if not c or not c.samples or not Comparable(c, s) then
        if c then Passing(o, c) end
        NewWindow(o, s)
        return
    end
    local list = c.samples
    local mx, my = Mean(list, 1)
    local d = math.sqrt((s.wx - mx) ^ 2 + (s.wy - my) ^ 2)
    if d <= T.radius then
        for _, e in ipairs(c.ex or {}) do list[#list + 1] = e end
        c.ex = nil
        list[#list + 1] = { s = s, w = w }
    else
        c.ex = c.ex or {}
        c.ex[#c.ex + 1] = { s = s, w = w }
        if s.t - c.ex[1].s.t < T.excursion and d <= 2 * T.radius then return end
        for _, e in ipairs(c.ex) do list[#list + 1] = e end
        c.ex = nil
        local from = 1
        while from < #list and not Fits(list, from) do from = from + 1 end
        if from > 1 then
            local kept = {}
            for i = from, #list do kept[#kept + 1] = list[i] end
            c.samples, list = kept, kept
            -- Done before what is kept, it was done on the way; done within
            -- it, it is this place's (a fight, then a few steps on).
            if not (c.actAt and c.actAt >= kept[1].s.t) then Passing(o, c) end
            c.levelFrom = o.level
        end
    end
    c.since, c.last = list[1].s.t, s.t
    local span = c.last - c.since
    if span >= T.dwell or (span >= T.busyDwell and Journey.Busy(c.act)) then Establish(j, o, c) end
end

-- Leaving a stop: it closes at the last sample inside, and the road starts
-- there and runs through the excursion so far.
local function Leave(j, o)
    local c = o.c
    local ex = c.ex or {}
    c.ex = nil
    local exit = c.lastSample
    CloseStop(j, o)
    NewRoad(o, exit)
    for i = 1, #ex do
        Crumb(j, o, ex[i].s)
        Candidate(j, o, ex[i].s, ex[i].w)
    end
end

--------------------------------------------------------------------------
-- Settling (JRN-2)
--------------------------------------------------------------------------

-- Ends whatever was being built, cleanly: a pause, a teleport, a zone
-- border. The next sample starts afresh, so no line is ever drawn across.
local function Settle(j)
    local o = j.open
    if not o then return end
    local c = o.c
    if c then
        if c.stop then
            CloseStop(j, o)
        elseif c.city and (c.last - c.since >= T.city or Journey.Busy(c.act)) then
            c.stop = true
            CloseStop(j, o)
        elseif c.samples and Journey.Busy(c.act) then
            -- Cut short (a spirit released, a hearthstone, a pause) with
            -- something done there: still a place on the road.
            Establish(j, o, c)
            CloseStop(j, o)
        else
            if c.act then
                if o.road then o.road.act = AddAct(o.road.act, c.act) else o.loose = AddAct(o.loose, c.act) end
            end
            o.c = nil
        end
    end
    CloseRoad(j, o)
    o.prev = nil
end
Journey.Settle = Settle

--------------------------------------------------------------------------
-- Feeding (JRN-1)
--------------------------------------------------------------------------

-- One sample: { t, wx, wy (yards), inst, mapID (the zone map), x, y (on
-- it, 0..1), level, city, resting, subZone }. Capture only sends one with
-- every number readable and out of combat.
function Journey.Feed(j, sample)
    local o = Open(j)
    -- Levels only go up, and UnitLevel can still read the old one just
    -- after PLAYER_LEVEL_UP: a sample never takes a level back.
    if sample.level and sample.level > (o.level or 0) then o.level = sample.level end
    if not j.startMapID then j.startMapID = sample.mapID end
    -- What is kept of it in the working state, which is saved: the place
    -- and the time, a tenth of a yard being plenty.
    -- The map position to a ten-thousandth (half a yard on most zones), so a
    -- small spot still has a shape; it is stored to thousandths.
    local s = { t = sample.t, mapID = sample.mapID, inst = sample.inst,
        x = math.floor((sample.fx or sample.x) * 10000 + 0.5) / 10000,
        y = math.floor((sample.fy or sample.y) * 10000 + 0.5) / 10000,
        wx = math.floor(sample.wx * 10 + 0.5) / 10, wy = math.floor(sample.wy * 10 + 0.5) / 10 }
    Journey.Step(j, o, s, sample)
    -- A stop is named after the subzone it was found in.
    local c = o.c
    if c and not c.subZone and not c.city then c.subZone = sample.subZone end
    -- The open stop or road moved on, and the recap reads it (Journey.All).
    Touch()
end

-- The rest of Feed, on the kept sample `s`; `sample` has the flags.
function Journey.Step(j, o, s, sample)

    -- A zone border, another world, or a jump no one walks: what was being
    -- built ends where the player was, and nothing joins the two.
    local prev = o.prev
    if prev and (not Comparable(prev, s) or Dist(prev, s) > T.teleport) then
        Settle(j)
        prev = nil
    end
    local w = prev and math.min(math.max(s.t - prev.t, 0), T.gap) or 1
    o.prev = s
    o.seen = { t = s.t, mapID = s.mapID, x = s.x, y = s.y }

    if sample.resting and prev then
        local into = o.c or o.road
        if into then
            into.act = into.act or {}
            into.act.resting = (into.act.resting or 0) + w
        end
    end

    local c = o.c

    -- Cities take no breadcrumbs: the time there is one stop.
    if sample.city then
        if not (c and c.city) then
            if c and c.stop then CloseStop(j, o) end
            if o.road then
                o.road.tail = s
                CloseRoad(j, o)
            end
            if o.c and o.c.act then o.loose = AddAct(o.loose, o.c.act) end
            c = NewCluster(o, s)
            c.city, c.act, o.loose = true, o.loose, nil
            Weigh(c, s, 1)
        else
            Weigh(c, s, w)
        end
        return
    end
    if c and c.city then
        local exit = c.lastSample
        Settle(j)
        o.prev = s
        NewRoad(o, exit)
        if Comparable(exit, s) then
            Crumb(j, o, s)
        else
            NewRoad(o, s)
        end
        Candidate(j, o, s, w)
        return
    end

    if c and c.stop then
        if DistToCentre(c, s) <= T.radius then
            -- Back from an excursion, or never away: all of it is the stop.
            for _, e in ipairs(c.ex or {}) do Weigh(c, e.s, e.w) end
            c.ex = nil
            Weigh(c, s, w)
            return
        end
        c.ex = c.ex or {}
        c.ex[#c.ex + 1] = { s = s, w = w }
        if s.t - c.ex[1].s.t >= T.excursion or DistToCentre(c, s) > 2 * T.radius then
            Leave(j, o)
        end
        return
    end

    Crumb(j, o, s)
    Candidate(j, o, s, w)
end

--------------------------------------------------------------------------
-- Activity (JRN-6)
--------------------------------------------------------------------------

-- `key` is combat, questsIn, questsOut, deaths or resting. It goes to the
-- dungeon the player is in, else to where they are staying or passing,
-- else to whatever comes next.
function Journey.Act(j, key, n)
    if not j or not n or n <= 0 then return end
    local o = Open(j)
    local into = o.dungeon or o.c or o.road
    if into then
        into.act = into.act or {}
        into.act[key] = (into.act[key] or 0) + n
        -- Where in a window it happened: at its newest sample.
        if into.samples and o.prev then into.actAt = o.prev.t end
        -- A death marks its spot at once, however soon the spirit is
        -- released (which ends what is open).
        if key == "deaths" and into == o.c and into.samples then Establish(j, o, into) end
    else
        o.loose = o.loose or {}
        o.loose[key] = (o.loose[key] or 0) + n
    end
end

-- A fight's time goes where it started (JRN-2): nothing is fed in combat,
-- so whatever was open at its start is still open at its end.
function Journey.FightStart(j, now)
    Open(j).fight = now
end

function Journey.FightEnd(j, now)
    local o = Open(j)
    local start = o.fight
    o.fight = nil
    if start and now > start then Journey.Act(j, "combat", now - start) end
end

-- A fight that was none on the road: a duel's (SD_DUEL_FINISHED, told
-- before combat ends). Its time is not kept, so the stop is not drawn or
-- told as fighting for it (probe, 15 Oct: a lost duel left a red splat).
function Journey.FightDrop(j)
    Open(j).fight = nil
end

--------------------------------------------------------------------------
-- Levels (JRN-7)
--------------------------------------------------------------------------

-- Where level `level` was reached. `where` is { mapID, x, y, subZone },
-- empty inside an instance.
function Journey.Level(j, level, now, where)
    if not j or type(level) ~= "number" then return end
    where = where or {}
    j.levels[level] = { at = now, mapID = where.mapID, x = where.x, y = where.y, subZone = where.subZone }
    local o = Open(j)
    o.level = level
    Touch()
end

--------------------------------------------------------------------------
-- Dungeons (JRN-8)
--------------------------------------------------------------------------

-- Each tick inside a party or raid instance. The first one ends what was
-- open outside and pins the dungeon at the last outdoor spot, if that is
-- fresh: older, and they were summoned or ported in. Back in the same one
-- after a corpse run carries on.
function Journey.InDungeon(j, info, now)
    local o = Open(j)
    local d = o.dungeon
    if d and d.instanceID == info.instanceID then
        d.seconds = d.seconds + math.max(0, math.min(now - (d.tick or now), T.gap))
        d.to, d.tick = now, now
        Touch()
        return d
    end
    if d then Journey.LeaveDungeon(j) end
    Settle(j)

    local seen = o.seen
    local entry = seen and now - seen.t < T.entryAge and seen or nil
    d = Segment(o, "dungeon", now, now, entry and entry.mapID)
    d.instanceID, d.name, d.instanceType = info.instanceID, info.name, info.instanceType
    d.x, d.y = entry and entry.x, entry and entry.y
    d.seconds, d.tick = 0, now
    d.act, o.loose = o.loose, nil
    o.dungeon = d
    Touch()
    return d
end

-- Outside the open dungeon: still in it while running back as a ghost
-- (`ghost`), out of it otherwise.
function Journey.Outside(j, ghost)
    local o = Open(j)
    if not o.dungeon then return false end
    if ghost then
        o.dungeon.tick = nil
        return true
    end
    Journey.LeaveDungeon(j)
    return false
end

function Journey.LeaveDungeon(j)
    local o = Open(j)
    local d = o.dungeon
    if not d then return nil end
    o.dungeon = nil
    d.tick = nil
    d.levelTo = o.level
    return Push(j, d)
end

--------------------------------------------------------------------------
-- Flights (JRN-9)
--------------------------------------------------------------------------

-- On the taxi: what was open ends, and the take-off is the last spot seen.
function Journey.TakeOff(j, now)
    local o = Open(j)
    if o.taxi then return o.taxi end
    Settle(j)
    local seen = o.seen
    local fresh = seen and now - seen.t < T.entryAge
    o.taxi = { t = now, mapID = fresh and seen.mapID or nil, x = fresh and seen.x or nil,
        y = fresh and seen.y or nil, level = o.level }
    return o.taxi
end

function Journey.OnTaxi(j)
    return j and j.open and j.open.taxi ~= nil or false
end

-- Off it: `s` is the first sample after landing, or nil when the landing
-- cannot be placed. Without both ends there is no flight to draw.
function Journey.Land(j, s, now)
    local o = Open(j)
    local taxi = o.taxi
    o.taxi = nil
    if not taxi or not taxi.mapID or not s then return nil end
    local seg = Segment(o, "flight", taxi.t, s.t or now, taxi.mapID, taxi.level)
    seg.mapID1, seg.x1, seg.y1 = taxi.mapID, taxi.x, taxi.y
    seg.mapID2, seg.x2, seg.y2 = s.mapID, s.x, s.y
    return Push(j, seg)
end

--------------------------------------------------------------------------
-- Pauses (JRN-2, JRN-20)
--------------------------------------------------------------------------

-- Every tick, before anything else: a tick more than `gap` after the last
-- (a loading screen, a freeze, a logout) ends what was open. Saved, so the
-- same rule settles a /reload: back within the gap, it carries on.
function Journey.Tick(j, now)
    local o = Open(j)
    local last = o.tick
    o.tick = now
    if last and now - last > T.gap then
        Settle(j)
        if o.dungeon then Journey.LeaveDungeon(j) end
        if o.taxi then o.taxi = nil end
        return true
    end
    return false
end

-- Everything open, written: capture switched off, a pause it cannot
-- carry across.
function Journey.Stop(j)
    if not j then return end
    Settle(j)
    if j.open and j.open.dungeon then Journey.LeaveDungeon(j) end
    if j.open then j.open.taxi = nil end
end

--------------------------------------------------------------------------
-- Fights on the route (JRN-10)
--------------------------------------------------------------------------
--
-- The only meetings Your Diary keeps itself: the fight's rows live in the
-- buffer, and a stranger's go after bufferDays (INT-2). The mark keeps when,
-- where and how it ended; whom only while they are in the diary, so a
-- stranger's identity never outlives the buffer. Their name is read from
-- the buffer at view time (Journey.FightWho) for as long as it has them.

local function Compact(marks)
    local keep = {}
    local over = #marks - T.marks
    for i = 1, #marks do
        local m = marks[i]
        if over > 0 and not m.guid then
            over = over - 1
        else
            keep[#keep + 1] = m
        end
    end
    for i = 1, #keep do marks[i] = keep[i] end
    for i = #keep + 1, #marks do marks[i] = nil end
end

-- `outcome` is "won" or "lost". `where` is { mapID, x, y } on the zone map,
-- or nil to place it by time.
function Journey.Fight(j, outcome, guid, now, where)
    if not j then return nil end
    guid = ns.SafeGUID(guid)
    where = where or {}
    local mark = { t = now, kind = "fight", outcome = outcome, mapID = where.mapID, x = where.x, y = where.y,
        guid = guid and ns.Diary.IsDiary(guid) and guid or nil }
    local marks = j.marks
    marks[#marks + 1] = mark
    -- Over the cap by a tenth, the oldest strangers' fights go at once.
    if #marks > T.marks * 1.1 then Compact(marks) end
    Touch()
    return mark
end

-- Where a moment on the route is marked (Journey.Fought's fights,
-- Journey.Append's records). `where` is the row's (ns.Where's shape,
-- whose map may be a cave's or a district's): its position counts only on
-- a zone map, else the mark is placed by time. Without it, here and now.
local function Spot(where)
    local spot = {}
    if where then
        if where.mapID and ns.ZoneOf(where.mapID) == where.mapID then
            spot.mapID, spot.x, spot.y = where.mapID, where.x, where.y
        end
    else
        spot.mapID, spot.x, spot.y = ns.ZoneWhere()
    end
    return spot
end
Journey.Spot = Spot

-- The logged-in character's route, while it is being kept: "Keep my own
-- route" on (the setting Capture/Journey.lua's timer runs by), and not
-- /sd testdata's made-up one; else nil. A feature's capture
-- (Features/<Name>/Capture.lua) writes only while this gives a route, and
-- forgets what it was holding while it does not, as the route's own
-- capture does.
local function Kept()
    if ns.Setting("keepRoute") ~= true then return nil end
    local j = Journey.Mine()
    if not j or j.test then return nil end
    return j
end
Journey.Kept = Kept

--------------------------------------------------------------------------
-- A feature's list of moments on the route
--------------------------------------------------------------------------
--
-- Most of what a feature notes on the road is a list of records, oldest
-- first, each where and when it happened: j[name] = { { t, mapID, x, y,
-- ... }, ... }, kept to the newest T[name]. Journey.RegisterList(name,
-- { cap }) declares one (its cap goes into T); Append adds to it, List
-- reads it. The recap gathers it through its moment (Core/JourneyRecap.lua,
-- Recap.RegisterMoment).
--
-- `spec`:
--   cap      the newest this many kept (T[name])
--   named    true: its records carry a creature's `npcID` and `name` as
--            the death recap gave them, which may come with a made-up
--            surname; the creature names read off units put it right,
--            as soon as one is read and at login (Core/CreatureNames.lua)
--   readNames  true: its records carry a creature's `npcID` and `name` as
--            read off a unit when the record was made, so a creature's
--            name may be taken from them (CreatureNames.Of: the newest
--            first), where no name read lately and no QuestieDB says it.
--            Or a function(j, npcID) → name or nil: the feature reads its
--            names itself, where they are not the newest record's first
--            (say, its list oldest first, then records still under way
--            that it keeps beside the list)
--   prune    optional function(j, now): at login (Journey.Prune), for
--            each character's route, before the creature names are put
--            right and dropped (CreatureNames.Prune, which asks Of): what the
--            feature keeps on the route beside its list given up when it
--            is stale (say, a record under way left open too long, or a
--            person's GUID kept on a record while the buffer still held
--            them, given up once it no longer does and they are not in
--            the diary)
--   forget   optional function(j, guid): PRV-3, someone forgotten (the
--            "journey" store, below), for each character's route: the
--            feature lets go of `guid` wherever it kept it, `nil` being
--            everyone. The record stays; only the name goes
--
-- A feature that keeps a table of its own on the route that is not a
-- list (keyed, say by kind: j[name][key] = record, written by the
-- feature itself) registers it too, with no `cap`, for its `prune` and
-- `forget` alone: Append and List are never asked of it.

local LISTS = {}
-- Every registered list, by name (for tests/kinds.lua; read only).
Journey.LISTS = LISTS
-- The lists registered `readNames`, in the order they registered
-- (CreatureNames.Of asks them in turn; read only), and those registered
-- with a `prune` or a `forget`, likewise.
local READ_NAMES, PRUNES, FORGETS = {}, {}, {}
Journey.READ_NAMES = READ_NAMES

function Journey.RegisterList(name, spec)
    spec = spec or {}
    for _, list in ipairs({ READ_NAMES, PRUNES, FORGETS }) do
        for i = #list, 1, -1 do
            if list[i] == name then table.remove(list, i) end
        end
    end
    LISTS[name] = spec
    if spec.cap then T[name] = spec.cap end
    if spec.readNames then READ_NAMES[#READ_NAMES + 1] = name end
    if spec.prune then PRUNES[#PRUNES + 1] = name end
    if spec.forget then FORGETS[#FORGETS + 1] = name end
    return spec
end

-- `rec` on j's list `name`, stamped now unless it says when, and placed
-- where `where` says (ns.Where's shape; here and now without it; only on a
-- zone map, else the recap places it by time). Returns `rec`.
function Journey.Append(j, name, rec, where)
    if not j then return nil end
    local spot = Spot(where)
    rec.t = rec.t or ns.Now()
    rec.mapID, rec.x, rec.y = spot.mapID, spot.x, spot.y
    local list = j[name] or {}
    j[name] = list
    list[#list + 1] = rec
    local cap = T[name]
    while cap and #list > cap do table.remove(list, 1) end
    Touch()
    return rec
end

-- j's list `name`, oldest first (empty without one).
function Journey.List(j, name)
    return j and j[name] or {}
end

-- A fight of the user's, kept as a mark on the logged-in character's route
-- while it is kept (Kept): "won" or "lost", with `guid`, at `t` (the time of
-- the fight's row, Core/Rows.lua's `fight`, so FightIndex finds a stranger
-- by it), where `where` says (ns.Where's shape) or here. Returns the mark,
-- or nil. The feature that writes fight rows calls it with each.
function Journey.Fought(outcome, guid, t, where)
    local j = Kept()
    if not j then return nil end
    return Journey.Fight(j, outcome, guid, t or ns.Now(), Spot(where))
end

-- A fight that was not what it seemed (a death the recap put down to
-- someone else): moved to the player the death recap names, or taken back
-- (`guid` false).
function Journey.Refight(j, mark, guid)
    if not (j and mark) then return end
    if guid == false then
        for i = #j.marks, 1, -1 do
            if j.marks[i] == mark then table.remove(j.marks, i) break end
        end
    else
        guid = ns.SafeGUID(guid)
        mark.guid = guid and ns.Diary.IsDiary(guid) and guid or nil
    end
    Touch()
end

-- Who a fight was with, as far as the diary still knows: the diary entry
-- the mark names, else the buffer's row of that fight, while it is there.
-- `index` is FightIndex's, built once per drawing.
function Journey.FightWho(mark, index)
    if mark.guid and ns.db.characters[mark.guid] then return mark.guid end
    local hit = index and index[mark.t]
    return hit
end

-- Every fight row in the buffer (a kind that sets Core/Rows.lua's
-- `fight`), by its time: the strangers' names for as long as the buffer
-- keeps them.
function Journey.FightIndex()
    local index = {}
    local Get = ns.Rows.Get
    for guid, rows in pairs(ns.db.interactions) do
        for i = 1, #rows do
            if Get(rows[i].type).fight then index[rows[i].time] = guid end
        end
    end
    return index
end

--------------------------------------------------------------------------
-- Witnesses to the user's deaths and close calls
--------------------------------------------------------------------------
--
-- A stranger who was there at one of the user's deaths or close calls is
-- a row on that player, of a kind that sets Core/Rows.lua's `witness`,
-- written at the moment's own time. So a death or a close call on the
-- route finds its witnesses by time, as fights find their strangers
-- (FightIndex), and the route keeps no names (forgetting someone takes
-- their rows, and with them their part on the plates). Which witnesses a
-- moment had, and which the plate shows, is the feature's that writes
-- the rows.

-- Every witness row in the buffer (a kind that sets `witness`), oldest
-- first: { t, guid, row }. Built once per drawing.
function Journey.WitnessIndex()
    local list = {}
    local Get = ns.Rows.Get
    for guid, rows in pairs(ns.db.interactions) do
        for i = 1, #rows do
            local row = rows[i]
            if Get(row.type).witness and type(row.time) == "number" then
                list[#list + 1] = { t = row.time, guid = guid, row = row }
            end
        end
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    return list
end

--------------------------------------------------------------------------
-- The user's deaths on the route
--------------------------------------------------------------------------
--
-- A death on the route is a count where it happened (act.deaths, at
-- PLAYER_DEAD: Capture/Journey.lua), drawn as a cross on the plates. What
-- killed you there is a feature's, kept on a list of its own
-- (RegisterList), which finds its cross by the death's time through this.

-- The segment a death at `t` was counted on (Act's "deaths", at
-- PLAYER_DEAD): what was open then, the last one but a flight begun by
-- `t`. Nil where that one counts no death (the death went to `loose`, or
-- the route was not kept then). Nothing is fed in combat, so that segment
-- may have ended its samples well before the death: a long fight's death
-- is still its own. (12 Oct, in the client: a death 35 s after its stop's
-- last sample, and 29 px from its cross, was matched to none.)
function Journey.CountedOn(j, t)
    if not (j and type(t) == "number") then return nil end
    local list = Journey.All(j)
    local lo, hi, at = 1, #list, 0
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if list[mid].from <= t then
            at, lo = mid, mid + 1
        else
            hi = mid - 1
        end
    end
    for i = at, 1, -1 do
        local seg = list[i]
        if seg.kind ~= "flight" then
            return seg.act and (seg.act.deaths or 0) > 0 and seg or nil
        end
    end
    return nil
end

-- At login: a mark kept with a GUID whose person has left the diary is a
-- stranger's again once the buffer has let them go. A feature's tables
-- registered with a `prune` give up what is stale (RegisterList), before
-- the creature names are put right (Core/CreatureNames.lua).
function Journey.Prune(now)
    local cutoff = ns.Cutoff(now)
    local function Stale(guid, t)
        return guid and t < cutoff and not ns.Diary.IsDiary(guid)
    end
    for _, j in pairs(ns.db.journey) do
        for _, mark in ipairs(j.marks or {}) do
            if Stale(mark.guid, mark.t) then mark.guid = nil end
        end
        for _, name in ipairs(PRUNES) do LISTS[name].prune(j, now or ns.Now()) end
        ns.CreatureNames.Prune(j, now or ns.Now())
    end
end

-- PRV-3: a forgotten person leaves every mark; the fight stays, nameless.
-- A feature's tables registered with a `forget` let them go too
-- (RegisterList). nil is everyone: the route is the user's own, so it
-- stays, only names go.
ns.RegisterStore("journey", function(guid)
    for _, j in pairs(ns.db.journey or {}) do
        for _, mark in ipairs(j.marks or {}) do
            if guid == nil or mark.guid == guid then mark.guid = nil end
        end
        for _, name in ipairs(FORGETS) do LISTS[name].forget(j, guid) end
    end
    Touch()
end)

-- One character's route, gone (Settings > Memory).
function Journey.Delete(guid)
    if not guid or not ns.db.journey[guid] then return false end
    ns.db.journey[guid] = nil
    Touch()
    return true
end

--------------------------------------------------------------------------
-- Debug ring buffer (JRN-18)
--------------------------------------------------------------------------
--
-- Raw breadcrumbs, only while debug is on, for checking the compaction
-- against what was actually walked. Fixed size, with a wrapping index:
-- nothing shifts. One short string a point, so it stays cheap to save.

function Journey.Raw(s)
    if not ns.DebugOn() then return end
    local raw = ns.db.journeyRaw
    local size = raw.size or T.raw
    raw.size = size
    local at = (raw.at or 0) % size + 1
    raw[at] = ("%d %d %.3f %.3f %.1f %.1f"):format(s.t, s.mapID or 0, s.x or 0, s.y or 0, s.wx or 0, s.wy or 0)
    raw.at = at
    raw.n = math.min((raw.n or 0) + 1, size)
end

function Journey.RawCount()
    local raw = ns.db.journeyRaw
    return raw.n or 0, raw.size or T.raw
end

function Journey.ClearRaw()
    wipe(ns.db.journeyRaw)
end

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

-- The client's maximum level (JRN-7), never assumed: guarded, since none of
-- these is verified in this build.
function Journey.MaxLevel()
    local level = GetMaxPlayerLevel and ns.Plain(GetMaxPlayerLevel())
    if type(level) ~= "number" or level <= 1 then level = ns.Plain(MAX_PLAYER_LEVEL) end
    if type(level) ~= "number" or level <= 1 then level = 60 end
    return level
end

-- What is being built right now, as segments: the open road, stop or
-- dungeon, read as if they closed this moment. Never saved; they become
-- real segments when they close. A new character walking about has no
-- closed segment for a while (a road closes at a stop, a teleport, a
-- border or a pause), and the page has to show their road all the same.
local function Provisional(j)
    local o = j.open
    local list = {}
    if not o then return list end

    local road = o.road
    if road then
        local crumbs = {}
        for i, crumb in ipairs(road.crumbs) do crumbs[i] = crumb end
        if road.tail and road.tail.t > crumbs[#crumbs].t then crumbs[#crumbs + 1] = road.tail end
        if #crumbs >= 2 then
            local seg = Segment(o, "road", crumbs[1].t, crumbs[#crumbs].t, road.mapID, road.levelFrom)
            local tolerance, kept = T.tolerance, nil
            repeat
                kept = Thin(crumbs, tolerance)
                tolerance = tolerance * 1.5
            until #kept <= T.points
            local flat = {}
            for _, crumb in ipairs(kept) do
                flat[#flat + 1] = crumb.x
                flat[#flat + 1] = crumb.y
            end
            seg.pts, seg.open = Journey.PackPoints(flat), true
            list[#list + 1] = seg
        end
    end

    local c = o.c
    if c and (c.stop or (c.city and c.w and c.last - c.since >= T.city)) then
        local seg = Segment(o, "stop", c.since, c.last, c.mapID, c.levelFrom)
        seg.x = Round(c.w > 0 and c.zx / c.w or c.first.x)
        seg.y = Round(c.w > 0 and c.zy / c.w or c.first.y)
        seg.r, seg.seconds, seg.act, seg.subZone, seg.open = Spread(c), StopSeconds(c), c.act, c.subZone, true
        seg.sdx, seg.sdy, seg.rho = Journey.Shape(c)
        list[#list + 1] = seg
    end

    local d = o.dungeon
    if d then
        local seg = {}
        for key, value in pairs(d) do seg[key] = value end
        seg.tick, seg.levelTo, seg.open = nil, o.level, true
        list[#list + 1] = seg
    end

    table.sort(list, function(a, b) return a.from < b.from end)
    return list
end

-- The closed segments and the open ones after them, in time order: what
-- the recap and the sheets read. Built once per version of the route.
local all = setmetatable({}, { __mode = "k" })

function Journey.All(j)
    if not j then return {} end
    local hit = all[j]
    if hit and hit.version == Journey.version and hit.n == #(j.segments or {}) then return hit.list end
    local list = {}
    for i, seg in ipairs(Segments(j)) do list[i] = seg end
    for _, seg in ipairs(Provisional(j)) do
        if not list[#list] or seg.from >= list[#list].from then list[#list + 1] = seg end
    end
    all[j] = { version = Journey.version, n = #(j.segments or {}), list = list }
    return list
end

-- Whether anything has been kept for `j` yet: a segment, open or closed, a
-- level reached, a fight.
function Journey.Any(j)
    if not j then return false end
    return #Journey.All(j) > 0 or next(j.levels or {}) ~= nil or #(j.marks or {}) > 0
end

-- Where the route was at `t`: the segment, its zone map and a position on
-- it -- a stop's centre, a road's point nearest in time, a dungeon's or a
-- flight's spot. Segments are in time order, so it is a binary search.
function Journey.At(j, t)
    local list = Journey.All(j)
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local seg = list[mid]
        if t < seg.from then
            hi = mid - 1
        elseif t > seg.to then
            lo = mid + 1
        else
            return seg, Journey.PointIn(seg, t)
        end
    end
    return nil
end

-- A position on `seg` at `t`: mapID, x, y.
function Journey.PointIn(seg, t)
    local kind = seg.kind
    if kind == "stop" or kind == "dungeon" then return seg.mapID, seg.x, seg.y end
    if kind == "flight" then
        if t - seg.from < seg.to - t then return seg.mapID1, seg.x1, seg.y1 end
        return seg.mapID2, seg.x2, seg.y2
    end
    local pts = Journey.Points(seg)
    local n = #pts / 2
    if n == 0 then return seg.mapID, nil, nil end
    local f = seg.to > seg.from and (t - seg.from) / (seg.to - seg.from) or 0
    local i = math.max(1, math.min(n, math.floor(f * (n - 1) + 0.5) + 1))
    return seg.mapID, pts[2 * i - 1], pts[2 * i]
end

-- How many yards a zone map spans, across and down, for drawing a stop's
-- radius to scale (JRN-14): the client's own figure, else the distance
-- between the map's corners in world space, else nil (the sheet then
-- guesses). Both are guarded:
--   the order  the world's axes are not the map's: the client's world
--              vector runs (north, west), so the corners' first axis is the
--              map's height (as HereBeDragons reads it). Mulgore's corners
--              measure 4102 by 6154 (probed in the client, 9 Oct 2026;
--              GetMapWorldSize answers 6154 across); taken in their own
--              order, every old stop came out half as big again. The pair is put in the
--              order that matches the art's own shape (within `aspect`),
--              else, without art, in the client's (north, west) order.
--   the range  a zone is `least` to `most` yards across; outside it, or in
--              neither order the art's shape, the answer is nil.
local YARDS = { least = 300, most = 20000, aspect = 0.2 }

-- The pair a, b as (across, down), or nil.
local function Across(mapID, a, b, worldOrder)
    if not (a and b) or a <= 0 or b <= 0 then return nil end
    local w, h = a, b
    if worldOrder then w, h = b, a end
    local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    local LW, LH = layer and ns.Plain(layer.layerWidth), layer and ns.Plain(layer.layerHeight)
    if type(LW) == "number" and type(LH) == "number" and LW > 0 and LH > 0 then
        local want = LW / LH
        local function Off(x, y) return math.abs(x / y / want - 1) end
        if Off(h, w) < Off(w, h) then w, h = h, w end
        if Off(w, h) > YARDS.aspect then return nil end
    end
    if w < YARDS.least or w > YARDS.most or h < YARDS.least or h > YARDS.most then return nil end
    return w, h
end

function Journey.MapYards(mapID)
    if not mapID then return nil end
    if C_Map.GetMapWorldSize then
        local ok, w, h = pcall(C_Map.GetMapWorldSize, mapID)
        w, h = ns.Plain(w), ns.Plain(h)
        if ok and type(w) == "number" and type(h) == "number" then
            local across, down = Across(mapID, w, h, false)
            if across then return across, down end
        end
    end
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
        local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
        if ok1 and ok2 and a and b and not ns.IsSecret(a) and not ns.IsSecret(b) and a.GetXY then
            local ax, ay = a:GetXY()
            local bx, by = b:GetXY()
            ax, ay, bx, by = ns.Plain(ax), ns.Plain(ay), ns.Plain(bx), ns.Plain(by)
            if type(ax) == "number" and type(bx) == "number" and type(ay) == "number" and type(by) == "number" then
                return Across(mapID, math.abs(bx - ax), math.abs(by - ay), true)
            end
        end
    end
    return nil
end

-- Roughly what one character's route weighs saved, in bytes: the same
-- rough walk the Memory settings use (ns.EstimateSize).
function Journey.Size(j)
    return ns.EstimateSizeOf and ns.EstimateSizeOf(j) or 0
end
