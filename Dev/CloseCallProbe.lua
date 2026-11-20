-- A probe for issue #25 (close calls kept at 1% health that never
-- happened): everything the close-call judge (Features/CloseCalls/
-- Capture.lua) reads for a fight, next to what it decided, so a fight the
-- player watched can be held against the sum the judge did.
--
-- Off until /sd ccprobe on (saved per character). While on, each fight:
--   start   the maximum health, the shapeshift form, the meter's readings
--           and the judge's last saved reading (j.meter)
--   during  every change of maximum health and of form
--   end     j.meter as the judge found it, the meter's sessions, the
--           damage taken by the user spell by spell, the healing every
--           source did spell by spell and to whom, and the judge's verdict
--           (SD_FIGHT_SURVIVED), or that it never gave one
-- A line per fight goes to chat; the whole of it to
-- SocialDiaryCharDB.ccprobe, read off the save after a /reload. It holds
-- real names: it stays in the local save, is never committed or copied
-- into tests. /sd ccprobe clear empties it. Dev only: the TOC's Dev/ block.

local addonName, ns = ...

local MAX_FIGHTS = 200
local DEPTH = 6

local function Store()
    if type(SocialDiaryCharDB) ~= "table" then return nil end
    local p = SocialDiaryCharDB.ccprobe
    if type(p) ~= "table" then
        p = { on = false, fights = {} }
        SocialDiaryCharDB.ccprobe = p
    end
    p.fights = p.fights or {}
    return p
end

-- Read without making the store, so a character who never turned it on
-- has no ccprobe in their save.
local function On()
    local p = type(SocialDiaryCharDB) == "table" and SocialDiaryCharDB.ccprobe
    return type(p) == "table" and p.on == true
end

local function Dump(value, depth)
    if ns.IsSecret(value) then return "<secret>" end
    local kind = type(value)
    if kind == "table" then
        depth = depth or 0
        if depth >= DEPTH then return "<table>" end
        local out = {}
        for k, v in pairs(value) do
            local key = ns.IsSecret(k) and "<secret key>" or (type(k) == "number" and k or tostring(k))
            out[key] = Dump(v, depth + 1)
        end
        return out
    end
    if kind == "function" or kind == "userdata" or kind == "thread" then return "<" .. kind .. ">" end
    return value
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return "<missing>" end
    local results = { pcall(fn, ...) }
    if not results[1] then return { error = tostring(results[2]) } end
    table.remove(results, 1)
    return #results == 1 and results[1] or results
end

local function Max()
    return Dump(ns.Plain(UnitHealthMax("player"), "<secret>"))
end

local function Form()
    local id = GetShapeshiftFormID and ns.Plain(GetShapeshiftFormID())
    local index = GetShapeshiftForm and ns.Plain(GetShapeshiftForm())
    return (id and tostring(id) or "none") .. "/" .. tostring(index)
end

local function MeterState()
    local j = ns.Journey.Kept()
    return j and Dump(j.meter) or "<route not kept>"
end

--------------------------------------------------------------------------
-- The meter, read whole
--------------------------------------------------------------------------

-- The latest session's id, as the judge picks it (the highest listed).
local function LatestID(sessions)
    local id
    for _, entry in ipairs(type(sessions) == "table" and sessions or {}) do
        local sid = type(entry) == "table" and ns.Plain(entry.sessionID)
        if type(sid) == "number" and (not id or sid > id) then id = sid end
    end
    return id
end

-- One meter type of one session: its sources, and each source's spells.
local function Read(meter, id, which)
    local session
    if id then
        session = Call(meter.GetCombatSessionFromID, id, which)
    else
        session = Call(meter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, which)
    end
    local out = { session = Dump(session), sources = {} }
    local sources = type(session) == "table" and not ns.IsSecret(session) and session.combatSources
    for i, src in ipairs(type(sources) == "table" and sources or {}) do
        if type(src) == "table" then
            local guid, creature = src.sourceGUID, src.sourceCreatureID
            if id then
                out.sources[i] = Dump(Call(meter.GetCombatSessionSourceFromID, id, which, guid, creature))
            else
                out.sources[i] = Dump(Call(meter.GetCombatSessionSourceFromType,
                    Enum.DamageMeterSessionType.Current, which, guid, creature))
            end
        end
    end
    return out
end

local function Meter()
    local meter, types = C_DamageMeter, Enum and Enum.DamageMeterType
    if not (meter and types) then return { error = "<no meter>" } end
    local sessions = meter.GetAvailableCombatSessions and Call(meter.GetAvailableCombatSessions)
    local id = LatestID(sessions)
    return { sessions = Dump(sessions), id = id,
        taken = Read(meter, id, types.DamageTaken), healing = Read(meter, id, types.HealingDone) }
end

-- The local player's damage-taken total in a reading, for the chat line.
local function TakenTotal(m)
    local s = type(m.taken) == "table" and m.taken.session
    for _, src in ipairs(type(s) == "table" and type(s.combatSources) == "table" and s.combatSources or {}) do
        if type(src) == "table" and src.isLocalPlayer == true then return src.totalAmount end
    end
    return 0
end

--------------------------------------------------------------------------
-- The fight
--------------------------------------------------------------------------

local fight

ns.On("PLAYER_REGEN_DISABLED", function()
    if not On() then return end
    fight = { started = ns.Now(), maxStart = Max(), formStart = Form(), meterStart = MeterState(),
        changes = {} }
end)

local function Change(what)
    if fight then fight.changes[#fight.changes + 1] = { t = ns.Now() - fight.started, what = what } end
end

ns.On("UNIT_MAXHEALTH", function(_, unit)
    if unit == "player" and fight then Change("max " .. tostring(Max())) end
end)

ns.On("UPDATE_SHAPESHIFT_FORM", function()
    if fight then Change("form " .. Form()) end
end)

local pending

ns.On("SD_FIGHT_SURVIVED", function(_, started, now, taken, max, foe)
    if not pending then return end
    pending.verdict = { taken = taken, max = max, took = max and max > 0 and math.floor(taken / max * 100 + 0.5),
        close = max and max > 0 and taken / max >= 0.9 or false, foe = Dump(foe) }
end)

local function Finish(f)
    local p = Store()
    if not p then return end
    f.meterEnd = MeterState()
    if #p.fights >= MAX_FIGHTS then table.remove(p.fights, 1) end
    p.fights[#p.fights + 1] = f
    local v = f.verdict
    local n = #p.fights
    local changes = #f.changes > 0 and (" changes: " .. #f.changes) or ""
    if v then
        ns.Print("ccprobe #%d: %ss, meter taken %s; judge: %s of %s = %s%%%s%s", n, tostring(f.seconds),
            tostring(TakenTotal(f.meter)), tostring(v.taken), tostring(v.max), tostring(v.took),
            v.close and " |cffff4040CLOSE CALL|r" or "", changes)
    else
        ns.Print("ccprobe #%d: %ss, meter taken %s; judge gave no verdict (left, duel or meter unread)%s", n,
            tostring(f.seconds), tostring(TakenTotal(f.meter)), changes)
    end
    ns.Print("ccprobe #%d: form %s -> %s, max %s -> %s. Note your real lowest health for #%d.", n,
        f.formStart, Form(), tostring(f.maxStart), tostring(Max()), n)
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local f = fight
    fight = nil
    if not f then return end
    f.seconds = ns.Now() - f.started
    f.meterAtEnd = MeterState()
    pending = f
    -- The judge reads at 1s and retries for up to 5s; the meter is read
    -- here just after its first try, the verdict waited for past its last.
    ns.After(1.2, function() f.meter = Meter() end)
    ns.After(7, function()
        if pending == f then pending = nil end
        Finish(f)
    end)
end)

--------------------------------------------------------------------------
-- /sd ccprobe
--------------------------------------------------------------------------

local function Command(rest)
    local p = Store()
    if not p then return end
    if rest == "on" or rest == "off" then
        p.on = rest == "on"
        ns.Print("ccprobe %s.", rest)
    elseif rest == "clear" then
        p.fights = {}
        ns.Print("ccprobe cleared.")
    else
        ns.Print("ccprobe: %s, %d fights kept; /sd ccprobe on | off | clear, /reload to save.",
            p.on and "on" or "off", #p.fights)
    end
end

ns.Slash.Register("ccprobe", Command, "close-call probe (#25): |cffffd100/sd ccprobe [on | off | clear]|r",
    { dev = true })
