-- A probe for what the damage meter can tell beyond what the features read
-- (Core/Meter.lua), logged to SocialDiaryCharDB.meterProbe after each fight,
-- anywhere, and read off the save after a /reload; nothing else reads it.
--
-- What it answers:
--   fights   Does the client fill EnemyDamageTaken and the DamageTaken spell
--            rows, secret or plain, in the world and in a dungeon? Does a
--            foe's breakdown name strangers who hit it?
--   deaths   While the user lies dead and their group fights on, what stops
--            the meter (Meter.Busy), and does their own recap read anyway?
--
-- It holds real names: it stays in the local save, is never committed or
-- copied into tests, and /sd meterprobe clear empties it. Dev only: the
-- TOC's Dev/ block goes in a release.

local addonName, ns = ...

local Meter = ns.Meter

local MAX_LINES = 400
local DEPTH = 6
-- Seconds: how often a death's recap is tried, and for how long.
local DEATH = { every = 3, tries = 60 }

local function Dump(value, depth)
    if ns.IsSecret(value) then return "<secret>" end
    local kind = type(value)
    if kind == "table" then
        depth = depth or 0
        if depth >= DEPTH then return "<table>" end
        local out = {}
        for k, v in pairs(value) do
            out[ns.IsSecret(k) and "<secret key>" or tostring(k)] = Dump(v, depth + 1)
        end
        return out
    end
    if kind == "function" or kind == "userdata" or kind == "thread" then return "<" .. kind .. ">" end
    return value
end

local function Log(kind, data)
    if type(SocialDiaryCharDB) ~= "table" then return end
    local p = SocialDiaryCharDB.meterProbe
    if type(p) ~= "table" then
        p = { log = {} }
        SocialDiaryCharDB.meterProbe = p
    end
    if #p.log >= MAX_LINES then return end
    p.log[#p.log + 1] = { t = ns.Now(), kind = kind, data = Dump(data) }
end

local function Where()
    local inside, kind = IsInInstance()
    return { inside = inside, kind = kind }
end

-- A meter type's rows in a session, each with its spell rows.
local function Rows(kind, id)
    local sources, used, which = Meter.Session(kind, id)
    if not sources then return "<does not read>" end
    local out = {}
    for i, src in ipairs(sources) do
        src = Meter.Table(src)
        if src then
            out[i] = { source = src, spells = Meter.Spells(used, which, ns.Plain(src.sourceGUID),
                ns.Plain(src.sourceCreatureID)) or "<does not read>" }
        end
    end
    return out
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local id, atEnd, ended = Meter.Pin(), Meter.Busy(), ns.Now()
    ns.After(1, function()
        Meter.Wait(function()
            Log("fight", { where = Where(), session = id, busyAtEnd = atEnd, waited = ns.Now() - ended,
                enemies = Rows("EnemyDamageTaken", id), taken = Rows("DamageTaken", id) })
            return true
        end, { every = 1, tries = 1, deadline = 5 * 60, gaveUp = function()
            Log("fight", { where = Where(), session = id, busyAtEnd = atEnd, gaveUp = Meter.Busy() })
        end })
    end)
end)

ns.On("PLAYER_DEAD", function()
    local tries = 0
    local function Look()
        tries = tries + 1
        local recap = C_DeathRecap
        local ok, events = false, nil
        if recap and recap.GetRecapEvents then ok, events = pcall(recap.GetRecapEvents) end
        Log("death", { where = Where(), try = tries, busy = Meter.Busy() or "no", lockdown = InCombatLockdown(),
            recapOk = ok, recap = events })
        if tries < DEATH.tries and (Meter.Busy() or tries == 1) then ns.After(DEATH.every, Look) end
    end
    Look()
end)

ns.Slash.Register("meterprobe", function(rest)
    if rest == "clear" then
        SocialDiaryCharDB.meterProbe = nil
        ns.Print("meter probe cleared.")
        return
    end
    local p = SocialDiaryCharDB.meterProbe
    ns.Print("meter probe: %d lines of %d; /reload to save, /sd meterprobe clear to empty.",
        p and #p.log or 0, MAX_LINES)
end, "damage meter probe: |cffffd100/sd meterprobe [clear]|r", { dev = true })
