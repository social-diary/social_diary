-- Sighting capture (SIG-1, SIG-2, SIG-5, SIG-6, SIG-8).
--
-- The client has no "who is near me" call. What it has is every unit token
-- that can name another player, and of those nameplates are the radar: one
-- appears for each player within nameplate range, if the user shows that
-- kind of nameplate (SIG-9). Target, focus and mouseover catch people whose
-- plate is hidden, and /say, /yell and emotes catch people who are heard
-- rather than seen. T-B1b verified all of them give a plain GUID for
-- open-world strangers.
--
-- NAME_PLATE_UNIT_ADDED only fires when a plate appears, so someone who
-- stays in range never fires it again. A slow sweep over the nameplate
-- tokens keeps their last-seen time moving.
--
-- Volume is the design constraint (SIG-8): one starting zone produced ~60
-- players in minutes and the same player ~25 times in five seconds. So an
-- event only reads a GUID and checks a per-character throttle; the rest -- the
-- identity read, the position, the stored row -- happens off a queue that
-- OnUpdate drains within a per-frame budget, and the frame is hidden (no
-- OnUpdate at all) whenever the queue is empty.
--
-- SIG-5 and SIG-6: in cities and instances the source handlers are
-- unregistered, not ignored, so sighting work there is zero (NFR-1).

local addonName, ns = ...

-- A character queued this recently is dropped at the event. Also the
-- resolution of a row's last-seen time while someone stays in view.
local THROTTLE_SECONDS = 60
local SWEEP_SECONDS = 30
local QUEUE_MAX = 200

-- NFR-1: under 2 ms in any one frame. Half a millisecond leaves room for
-- everything else the addon does in the same frame.
local BUDGET_MS = 0.5
local MAX_PER_FRAME = 10

local Capture = {}
ns.SightingCapture = Capture

--------------------------------------------------------------------------
-- Counters, for /sd sightings
--------------------------------------------------------------------------

local stats

function Capture.ResetStats()
    stats = {
        since = GetServerTime(),
        events = 0, queued = 0, throttled = 0, dropped = 0,
        new = 0, updated = 0, skipped = 0,
        frames = 0, ms = 0, maxMs = 0,
    }
end
Capture.ResetStats()

function Capture.Stats()
    return stats
end

--------------------------------------------------------------------------
-- The queue (SIG-8)
--------------------------------------------------------------------------

local queue, head, tail = {}, 1, 0
local queuedAt = {}  -- [guid] = when they last went into the queue

local drainer = CreateFrame("Frame")
drainer:Hide()

function Capture.QueueLength()
    return tail - head + 1
end

-- The throttle's stamps, which must not pile up.
function ns._test.SightingThrottleSize()
    return ns.CountKeys(queuedAt)
end

local function DropQueue()
    wipe(queue)
    head, tail = 1, 0
    drainer:Hide()
end

-- Drops everything waiting, and the throttle stamps with it: a stamp says
-- "already queued", which is no longer true of anything dropped here.
local function ClearQueue()
    DropQueue()
    wipe(queuedAt)
end

-- A stamp older than the throttle no longer holds anyone back, so it only
-- takes up room: without this the table keeps every GUID seen since login.
local function PruneThrottle(now)
    for guid, at in pairs(queuedAt) do
        if now - at >= THROTTLE_SECONDS then queuedAt[guid] = nil end
    end
end

-- PRV-3: someone forgotten must not come back out of the queue a frame
-- later, with a fresh character record and a fresh row.
ns.RegisterStore("sighting queue", function(guid)
    if guid == nil then
        ClearQueue()
        return
    end

    queuedAt[guid] = nil
    local kept = {}
    for i = head, tail do
        if queue[i].guid ~= guid then kept[#kept + 1] = queue[i] end
    end
    queue, head, tail = kept, 1, #kept
    if tail == 0 then drainer:Hide() end
end)

local function Enqueue(guid, unit, source, sender)
    local now = ns.Now()
    local last = queuedAt[guid]
    if last and now - last < THROTTLE_SECONDS then
        stats.throttled = stats.throttled + 1
        return false
    end

    if tail - head + 1 >= QUEUE_MAX then
        stats.dropped = stats.dropped + 1
        return false
    end

    queuedAt[guid] = now
    tail = tail + 1
    queue[tail] = { guid = guid, unit = unit, source = source, sender = sender, time = now }
    stats.queued = stats.queued + 1
    drainer:Show()
    return true
end

-- SIG-2's "attackable at that moment". A duel's opponent reads as an enemy
-- in every way the client has while it lasts (probe, 15 Oct:
-- UnitCanAttack, UnitIsEnemy, reaction 2), yet is no foe: not hostile
-- while ns.Duelling says a duel with them is on, or just ended
-- (Core/Events.lua).
local function Hostile(unit, guid)
    if not UnitCanAttack then return nil end
    if ns.Duelling(guid, true) then return false end
    return ns.Plain(UnitCanAttack("player", unit)) == true
end

-- A unit token is only worth reading if it still names the same player: a
-- mouseover in particular has usually moved on by the next frame. When it
-- has, the GUID still gives a thinner identity (DIA-2a) and no level.
local function Process(item, where)
    local data = { source = item.source }
    local record

    local unit = item.unit
    if unit and ns.Plain(UnitGUID(unit)) == item.guid then
        record = ns.Characters.ObserveUnit(unit)
        -- What ObserveUnit just read. A level it could not read (-1, "too
        -- high to tell") leaves the one on record, which is the last read.
        data.level = record and record.level
        data.hostile = Hostile(unit, item.guid)
    elseif item.sender then
        local first, surname = ns.NormalizeName(item.sender)
        record = ns.Characters.Observe(item.guid, { first = first, surname = surname })
    end

    record = record or ns.Characters.Get(item.guid) or ns.Characters.ObserveGUID(item.guid)
    if not record then
        stats.skipped = stats.skipped + 1
        return
    end

    local result = ns.Sightings.Record(item.guid, data, where, item.time)
    ns.Sessions.Around(item.guid, item.time, where.zone)
    if result == "new" then
        stats.new = stats.new + 1
    elseif result == "updated" then
        stats.updated = stats.updated + 1
    end
end

local function Drain()
    local clock = debugprofilestop
    local started = clock and clock()

    -- One position per frame: everything in this batch was seen within a
    -- frame or two of it.
    local where = ns.Where()

    local done = 0
    while head <= tail and done < MAX_PER_FRAME do
        local item = queue[head]
        queue[head] = nil
        head = head + 1

        Process(item, where)
        done = done + 1

        if started and clock() - started >= BUDGET_MS then break end
    end

    -- Empty: start over. Not ClearQueue, whose throttle reset would let the
    -- next burst straight back in (SIG-8).
    if head > tail then
        wipe(queue)
        head, tail = 1, 0
        drainer:Hide()
    end

    if started then
        local spent = clock() - started
        stats.frames = stats.frames + 1
        stats.ms = stats.ms + spent
        if spent > stats.maxMs then stats.maxMs = spent end
    end
end

drainer:SetScript("OnUpdate", Drain)
ns._test.DrainSightings = Drain  -- one frame's worth; the mock runs no OnUpdate

--------------------------------------------------------------------------
-- Sources (SIG-1)
--------------------------------------------------------------------------

local VISIBLE = { visible = true }

-- Target, focus and mouseover can point at someone across the map through a
-- party frame. UnitIsVisible is the client's own "close enough to be drawn",
-- and the stored position is the user's, so a far-away unit would be filed
-- in the wrong place. Nameplates are drawn by definition.
local function FromUnit(unit, source)
    local drawn = source == "plate" or source == "sweep"
    local guid = ns.PlayerGUIDFromUnit(unit, not drawn and VISIBLE or nil)
    if not guid then return false end

    return Enqueue(guid, unit, source)
end

-- Under chat lockdown sender and guid are both secret, and ns.ChatHandler
-- hands over no guid: the line is dropped.
local function FromChat(source)
    return ns.ChatHandler(function(_, sender, guid)
        stats.events = stats.events + 1
        if not guid or guid == ns.ownGUID then return end
        Enqueue(guid, nil, source, ns.Plain(sender))
    end)
end

local function FromToken(token, source)
    return function()
        stats.events = stats.events + 1
        FromUnit(token, source)
    end
end

local SOURCES = {
    NAME_PLATE_UNIT_ADDED = function(_, unit)
        stats.events = stats.events + 1
        unit = ns.Plain(unit)
        if type(unit) == "string" then FromUnit(unit, "plate") end
    end,
    PLAYER_TARGET_CHANGED = FromToken("target", "target"),
    PLAYER_FOCUS_CHANGED = FromToken("focus", "focus"),
    UPDATE_MOUSEOVER_UNIT = FromToken("mouseover", "mouse"),
    CHAT_MSG_SAY = FromChat("say"),
    CHAT_MSG_YELL = FromChat("yell"),
    CHAT_MSG_EMOTE = FromChat("emote"),
    CHAT_MSG_TEXT_EMOTE = FromChat("emote"),
}

Capture.SOURCE_COUNT = ns.CountKeys(SOURCES)

-- Every nameplate token in use. With `dry`, nothing is queued: /sd sightings
-- scan uses that to report what is around while capture is paused.
--
-- Returns the players found and how many of them went into the queue.
function Capture.Sweep(dry)
    if not dry then PruneThrottle(ns.Now()) end

    local players, queued = {}, 0
    ns.Units.Each(ns.Units.Plates, function(unit)
        local guid = ns.PlayerGUIDFromUnit(unit)
        if guid then
            players[#players + 1] = { guid = guid, unit = unit }
            if not dry and Enqueue(guid, unit, "sweep") then queued = queued + 1 end
        end
    end)
    return players, queued
end

--------------------------------------------------------------------------
-- When to listen (SIG-5, SIG-6)
--------------------------------------------------------------------------

local active = false
local ticker
local state, detail = "login", nil

local function Activate()
    if active then return end
    active = true

    for event, handler in pairs(SOURCES) do ns.On(event, handler) end
    ticker = ns.Every(SWEEP_SECONDS, function() Capture.Sweep() end)

    -- Plates that appeared while paused fired their event into nothing.
    Capture.Sweep()
end

local function Deactivate()
    if not active then return end
    active = false

    for event, handler in pairs(SOURCES) do ns.Off(event, handler) end
    if ticker then
        ticker:Cancel()
        ticker = nil
    end

    -- Whatever was queued was seen where the user no longer is, and never
    -- recorded, so its stamps go with it. The rest stay: walking back through
    -- a city's gate must not read everyone again.
    for i = head, tail do queuedAt[queue[i].guid] = nil end
    DropQueue()
end

-- "active", or why not: "login", "off", "instance", "city" (with the
-- matched map id, zone name or "sanctuary" as the second return, from
-- ns.City in Core/Location.lua).
function Capture.Evaluate()
    local want, why
    if not ns.ownGUID or not ns.db then
        want = "login"
    elseif not ns.db.settings.detectSightings then
        want = "off"
    elseif IsInInstance and IsInInstance() then
        want = "instance"
    else
        why = ns.City()
        want = why and "city" or "active"
    end

    if want == "active" then Activate() else Deactivate() end
    state, detail = want, why
    return state, detail
end

function Capture.State()
    return state, detail, active
end

-- SIG-1's switch (/sd sightings on|off). Takes effect at once.
function Capture.SetEnabled(on)
    ns.db.settings.detectSightings = on and true or false
    return Capture.Evaluate()
end

-- SIG-5's list, by map id or zone name. false, not nil, for a removed city:
-- the defaults would bring it back.
function Capture.SetCity(key, on)
    ns.db.settings.cities[key] = on and true or false
    return Capture.Evaluate()
end

-- The city list, sorted, as { key, on } pairs, removed defaults included.
function Capture.Cities()
    local list = {}
    for key, on in pairs(ns.db.settings.cities) do
        list[#list + 1] = { key = key, on = on }
    end
    table.sort(list, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return list
end

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
}) do
    ns.On(event, function() Capture.Evaluate() end)
end
