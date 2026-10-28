-- Your Diary's capture (JRN-1, JRN-2, JRN-6 to JRN-9, JRN-17): where the
-- client's signals are read and handed to Core/Journey.lua, which never
-- touches a unit token.
--
-- One timer of its own, every few seconds, from PLAYER_ENTERING_WORLD until
-- the setting goes off: not ns.Every's shared beat, because it stops and
-- starts with the setting, and not every frame. Each tick, in this order:
--
--   the gap     a tick long after the last ends what was open (loading
--               screens, freezes, a logout or a /reload that took long)
--   AFK         a pause
--   the sitting the user is at the game: Core/Sittings.lua's heartbeat
--   instances   a party or raid instance is a dungeon segment; any other
--               (battlegrounds, arenas) a pause
--   corpse run  outside the open dungeon as a ghost: still in it
--   dead        dead or a ghost anywhere else: a pause. A ghost's walk to
--               the corpse is not the character's road, so nothing is
--               penned until they live again, and nothing joins the two
--   taxi        a flight, before anything else that moves: IsMounted is
--               true on a flight path too, so it is never asked
--   combat      no position is read; the fight's time goes where it began
--   the sample  the zone map and the yards, both readable, or a pause
--
-- Quests turned in and level-ups already have handlers (Capture/
-- Together.lua); those call in here rather than adding a second one.
-- Quests taken and turned in are passed on to the features, after the
-- route has counted them (SD_QUEST_ACCEPTED, SD_QUEST_TURNED_IN).
--
-- A few seconds after entering the world (SETTLE), when the client has
-- loaded what the character holds, this file fires SD_WORLD_SETTLED
-- (Core/Events.lua), for a feature's capture (Features/<Name>/Capture.lua)
-- that holds what the character has against its last reading to take its
-- first one then.

local addonName, ns = ...

local Journey = ns.Journey
local T = Journey.T

local Capture = {}
ns.JourneyCapture = Capture

local ticker
-- After the spirit is released the position lags a moment behind (JRN-4):
-- nothing is sampled until then, so the jump to the graveyard is no road.
local ignoreUntil
local GHOST_LAG = 3
-- Seconds after entering the world before what the character holds (its
-- bags, its skills) is read: SD_WORLD_SETTLED.
local SETTLE = 3

function Capture.On()
    return ns.Setting("keepRoute") == true
end

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

local function SubZone()
    local sub = ns.Plain(GetSubZoneText and GetSubZoneText())
    if type(sub) ~= "string" or sub == "" then return nil end
    return sub
end

-- A sample with every number readable, or nil (JRN-2: a secret or missing
-- position is a pause, never a guess).
local function Sample(now)
    local mapID, x, y, fx, fy = ns.ZoneWhere()
    if not mapID then return nil end
    local wx, wy, inst = ns.WorldWhere()
    if not wx then return nil end
    return { t = now, wx = wx, wy = wy, inst = inst, mapID = mapID, x = x, y = y, fx = fx, fy = fy, level = Level(),
        city = ns.City() ~= nil, resting = ns.Plain(IsResting and IsResting()) == true, subZone = SubZone() }
end

-- The logged-in character's route, begun now if it was not yet (D10: from
-- now on, nothing before).
local function Mine(now)
    local j = Journey.Mine()
    if j then return j end
    return Journey.Begin(ns.ownGUID, now or ns.Now(), Level(), (ns.ZoneWhere()))
end

local function Flag(fn, ...)
    if not fn then return false end
    return ns.Plain(fn(...)) == true
end

-- What the timer has been doing since login, for /sd journey stats: how
-- many ticks, the last sample, why the last tick took none, the last error.
local status = { ticks = 0, errors = 0 }
Capture.status = status

local function Skip(reason)
    status.skip = reason
end

local function Tick()
    status.ticks = status.ticks + 1
    if not Capture.On() or not ns.ownGUID then return Skip("off") end
    local now = ns.Now()
    local j = Mine(now)
    -- /sd testdata's made-up route is looked at, never added to.
    if j.test then return Skip("test data") end
    Journey.Tick(j, now)

    if Flag(UnitIsAFK, "player") then
        Journey.Settle(j)
        return Skip("AFK")
    end
    -- At the game: dead, in a battleground or in combat still counts
    -- (Core/Sittings.lua), so the sitting is noted before any of them.
    ns.Sittings.Note(j, now)

    local inside, kind = IsInInstance()
    if ns.Plain(inside) == true then
        kind = ns.Plain(kind)
        if kind == "party" or kind == "raid" then
            local name, _, _, _, _, _, _, id = GetInstanceInfo()
            Journey.InDungeon(j, { instanceID = ns.Plain(id), name = ns.Plain(name), instanceType = kind }, now)
            return Skip("in a dungeon")
        end
        Journey.Stop(j)
        return Skip("in an instance (" .. tostring(kind) .. ")")
    end
    local dead = Flag(UnitIsDeadOrGhost, "player")
    if Journey.Outside(j, dead) then return Skip("corpse run") end
    if dead then
        Journey.Settle(j)
        return Skip("dead or a ghost")
    end

    if Flag(UnitOnTaxi, "player") then
        Journey.TakeOff(j, now)
        return Skip("on a taxi")
    end
    if Flag(InCombatLockdown) or Flag(UnitAffectingCombat, "player") then return Skip("in combat") end
    if ignoreUntil and now < ignoreUntil then return Skip("spirit just released") end

    local s = Sample(now)
    if Journey.OnTaxi(j) then Journey.Land(j, s, now) end
    if not s then
        Journey.Settle(j)
        local zone = ns.ZoneWhere()
        return Skip(zone and "no world position (UnitPosition)" or "no zone position")
    end
    Journey.Raw(s)
    Journey.Feed(j, s)
    status.skip, status.sample = nil, s
end
ns._test.JourneyTick = Tick

local function Start()
    if not Capture.On() or not ns.ownGUID then return end
    Mine()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    -- Protected: an error must not end the timer for the rest of the
    -- session (a ticker whose callback errors may never run again). It
    -- goes to the error frame, once, and is kept for /sd journey stats.
    ticker = C_Timer.NewTicker(T.tick, function()
        local ok, err = pcall(Tick)
        if ok then return end
        status.errors, status.lastError, status.errorAt = status.errors + 1, tostring(err), ns.Now()
        if status.errors == 1 and geterrorhandler then geterrorhandler()(err) end
    end)
end

local function Halt()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    Journey.Stop(Journey.Mine())
end

-- The setting (JRN-17). Off writes what was open and stops the timer; the
-- route kept so far stays.
function Capture.SetEnabled(on)
    ns.SetSetting("keepRoute", on == true)
    if on then Start() else Halt() end
    Journey.Touch()
end

function Capture.Running()
    return ticker ~= nil
end

--------------------------------------------------------------------------
-- What happens on the way (JRN-6, JRN-7)
--------------------------------------------------------------------------

-- Capture/Together.lua's QUEST_TURNED_IN handler calls this: counted on
-- the road, then passed on to the features (SD_QUEST_TURNED_IN, Core/
-- Events.lua) with the quest's id, whether or not the route is kept: a
-- feature asks that itself (ns.Journey.Kept).
function Capture.QuestTurnedIn(questID)
    Journey.Act(Journey.Kept(), "questsOut", 1)
    questID = ns.Plain(questID)
    if type(questID) == "number" then ns.Fire("SD_QUEST_TURNED_IN", questID) end
end

-- Capture/Together.lua's PLAYER_LEVEL_UP handler calls this. Where the
-- level was reached: on the zone map outdoors, nowhere in an instance (the
-- recap finds the dungeon by time).
function Capture.LevelUp(level)
    local j = Journey.Kept()
    level = ns.Plain(level)
    if not j or type(level) ~= "number" then return end
    local mapID, x, y = ns.ZoneWhere()
    Journey.Level(j, level, ns.Now(), { mapID = mapID, x = x, y = y, subZone = mapID and SubZone() or nil })
end

-- Counted on the road, then passed on to the features (SD_QUEST_ACCEPTED,
-- Core/Events.lua) with the quest's id, the last argument (older clients
-- give the log index first), whether or not the route is kept.
ns.On("QUEST_ACCEPTED", function(_, ...)
    Journey.Act(Journey.Kept(), "questsIn", 1)
    local n = select("#", ...)
    local questID = n > 0 and ns.Plain((select(n, ...))) or nil
    if type(questID) == "number" then ns.Fire("SD_QUEST_ACCEPTED", questID) end
end)

ns.On("PLAYER_DEAD", function()
    Journey.Act(Journey.Kept(), "deaths", 1)
end)

-- The spirit released: what was open ends where the body lies, and the
-- lagging position is not read.
ns.On("PLAYER_ALIVE", function()
    local j = Journey.Kept()
    if not j or not Flag(UnitIsGhost, "player") then return end
    Journey.Settle(j)
    ignoreUntil = ns.Now() + GHOST_LAG
end)

ns.On("PLAYER_REGEN_DISABLED", function()
    local j = Journey.Kept()
    if j then Journey.FightStart(j, ns.Now()) end
end)

-- A duel's fight is no fighting on the route (SD_DUEL_FINISHED,
-- Core/Events.lua's header): one that ends while a duel is on (a flight:
-- combat can end long before the "fled" line), or is still open when the
-- result comes (a knockout). A duel with mobs joining in goes with it, as
-- it does for the close-call judge.
ns.On("PLAYER_REGEN_ENABLED", function()
    local j = Journey.Kept()
    if not j then return end
    if ns.Duelling() then Journey.FightDrop(j) else Journey.FightEnd(j, ns.Now()) end
end)

ns.On("SD_DUEL_FINISHED", function()
    local j = Journey.Kept()
    if j then Journey.FightDrop(j) end
end)

ns.On("PLAYER_LOGIN", function()
    Journey.Prune()
end)

-- The features' first reading of what the character holds
-- (SD_WORLD_SETTLED), SETTLE seconds after entering the world.
ns.On("PLAYER_ENTERING_WORLD", function()
    Start()
    ns.After(SETTLE, function() ns.Fire("SD_WORLD_SETTLED") end)
end)
