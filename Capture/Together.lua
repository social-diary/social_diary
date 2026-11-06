-- The events that drive together sessions (SES-2 to SES-4).
--
-- Core/Sessions.lua holds the model and never touches a unit token; this file
-- is where the client's signals are read and handed to it: the lifecycle
-- (login, the tick, logout) and what happens during a session -- zones,
-- quests, levels. Rares and deaths are features' (Features/Rares/,
-- Features/Deaths/), which write them into the session (Sessions.Rare,
-- Sessions.Death).

local addonName, ns = ...

local TICK_SECONDS = 30

--------------------------------------------------------------------------
-- Presence
--------------------------------------------------------------------------

local function Grouped(guid)
    return ns.Roster.Has(guid)
end

-- "Seen nearby": the unit tokens that can name a player, read live rather
-- than from the sightings store (M2). Built once per tick, on first use.
-- Drawn by the client, too: a party frame's mouseover across the map is not
-- "nearby" (Capture/Nearby.lua). The group's own tokens are in it as well,
-- which is how a grouped member counts as near (Sessions' `near`): grouped
-- is together wherever they are, but only a member the client is drawing
-- shares the user's place.
local POINTED = { "target", "focus", "mouseover" }

local VISIBLE = { visible = true }

local function VisibleSet()
    local set = {}
    local function Add(unit)
        local guid = ns.PlayerGUIDFromUnit(unit, VISIBLE)
        if guid then set[guid] = true end
    end
    ns.Units.Each(ns.Units.Group(), Add)
    ns.Units.Each(POINTED, Add)
    ns.Units.Each(ns.Units.Plates, Add)
    return set
end

local function NearbyTest()
    local visible
    return function(guid)
        visible = visible or VisibleSet()
        return visible[guid] == true
    end
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

local function Tick()
    if not ns.ownGUID then return end

    -- A diary entry can be in the group without a roster change announcing
    -- it: added to the diary mid-group, or resumed after a reload.
    local nearby = NearbyTest()
    ns.Sessions.Roster(ns.Roster.Members(), nearby)
    ns.Sessions.Tick(Grouped, nearby)
    ns.Roster.Touch()
end

ns._test.TogetherTick = Tick

ns.On("PLAYER_LOGIN", function()
    ns.Sessions.Resume()
    ns.Every(TICK_SECONDS, Tick)
end)

ns.On("PLAYER_LOGOUT", function()
    ns.Sessions.Flush(Grouped, NearbyTest())
    ns.Roster.Touch()
end)

--------------------------------------------------------------------------
-- During a session (SES-4)
--------------------------------------------------------------------------

ns.On("ZONE_CHANGED_NEW_AREA", function()
    ns.Sessions.Zone()
end)

-- Your Diary counts them too, on the route (JRN-6, JRN-7): one handler
-- for each event, calling both.
ns.On("QUEST_TURNED_IN", function(_, questID)
    local n = ns.Sessions.Quest(questID, Grouped)
    if n > 0 then ns.Debug("quest %s counted for %d participant(s)", tostring(questID), n) end
    ns.JourneyCapture.QuestTurnedIn(questID)
end)

ns.On("PLAYER_LEVEL_UP", function(_, level)
    ns.Sessions.MyLevel(level)
    ns.JourneyCapture.LevelUp(level)
end)
