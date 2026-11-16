-- A probe for fishing, for the feature to come: what WoW Forever says when a
-- line is cast, when a fish bites and when the catch is looted, so the
-- detection is written from what the client does and not from what it is
-- thought to do (as Dev/LootProbe.lua was for the dungeon's loot rolls).
--
-- Logged to SocialDiaryCharDB.fishProbe, read off the save after a /reload
-- or with /sd fishprobe show; nothing else reads it.
--
-- What it keeps, each line with its time (GetTime, to a hundredth):
--   env     once a login: which of the APIs the detection may lean on the
--           client has (IsFishingLoot, GetLootSourceInfo, UnitChannelInfo)
--   cast    the player's own cast events: UNIT_SPELLCAST_SENT, START,
--           SUCCEEDED, FAILED, INTERRUPTED, CHANNEL_START, CHANNEL_STOP and
--           CHANNEL_UPDATE, with their arguments and the spell's name. A
--           channel's start carries what UnitChannelInfo says
--   loot    LOOT_READY, LOOT_OPENED and LOOT_CLOSED. The first two carry
--           IsFishingLoot(), the channel at that moment, where the player
--           stands, and each loot slot's link, info, type and source (the
--           source's GUID says what was looted: a bobber is a GameObject)
--
-- It holds item names and a position: it stays in the local save, is never
-- committed or copied into tests, and /sd fishprobe clear empties it. Dev
-- only: the TOC's Dev/ block goes in a release.

local addonName, ns = ...

local MAX_LINES = 600
-- Tables are written this deep; deeper is "<table>".
local DEPTH = 4
local on = true

local function Store()
    if type(SocialDiaryCharDB) ~= "table" then return nil end
    local p = SocialDiaryCharDB.fishProbe
    if type(p) ~= "table" then
        p = { log = {} }
        SocialDiaryCharDB.fishProbe = p
    end
    p.log = p.log or {}
    return p
end

-- A value as it can be saved: secret values named, tables copied a few
-- levels deep, functions and userdata named.
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
    if not on then return end
    local p = Store()
    if not p or #p.log >= MAX_LINES then return end
    local at = GetTime and GetTime() or 0
    p.log[#p.log + 1] = { at = math.floor(at * 100 + 0.5) / 100, kind = kind, data = Dump(data) }
end

-- Calls `fn` on `...` and keeps what came back, or the error.
local function Call(fn, ...)
    if type(fn) ~= "function" then return "<missing>" end
    local results = { pcall(fn, ...) }
    if not results[1] then return { error = tostring(results[2]) } end
    table.remove(results, 1)
    return results
end

-- A spell's name by its id, where the client says it.
local function SpellName(id)
    id = ns.Plain(id)
    if type(id) ~= "number" or not (C_Spell and C_Spell.GetSpellName) then return nil end
    local ok, name = pcall(C_Spell.GetSpellName, id)
    return ok and ns.Plain(name) or nil
end

--------------------------------------------------------------------------
-- What the client has
--------------------------------------------------------------------------

local function Env()
    local out = {}
    for _, name in ipairs({ "IsFishingLoot", "GetLootSourceInfo", "GetLootSlotInfo", "GetLootSlotLink",
        "GetLootSlotType", "GetNumLootItems", "UnitChannelInfo", "UnitCastingInfo" }) do
        out[name] = type(_G[name])
    end
    out.GetSpellName = type(C_Spell) == "table" and type(C_Spell.GetSpellName) or "missing"
    Log("env", out)
end

--------------------------------------------------------------------------
-- Listening
--------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local function Listen(event)
    pcall(frame.RegisterEvent, frame, event)
end

local CASTS = { UNIT_SPELLCAST_SENT = true, UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true }
local LOOTS = { LOOT_READY = true, LOOT_OPENED = true, LOOT_CLOSED = true }

Listen("PLAYER_ENTERING_WORLD")
for event in pairs(CASTS) do Listen(event) end
for event in pairs(LOOTS) do Listen(event) end

-- Each loot slot as the client describes it: what is in it, and what it
-- came off.
local function Slots()
    local n = ns.Plain(GetNumLootItems and GetNumLootItems())
    local out = { n = n }
    for slot = 1, (type(n) == "number" and math.min(n, 10) or 0) do
        out[slot] = { link = Call(GetLootSlotLink, slot), info = Call(GetLootSlotInfo, slot),
            kind = Call(GetLootSlotType, slot), source = Call(GetLootSourceInfo, slot) }
    end
    return out
end

local function Where()
    local ok, where = pcall(ns.Where)
    return ok and where or "<no position>"
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        Env()
    elseif CASTS[event] then
        local unit = ...
        if ns.Plain(unit) ~= "player" then return end
        -- SENT is (unit, target, castGUID, spellID); the others (unit,
        -- castGUID, spellID).
        local spellID = event == "UNIT_SPELLCAST_SENT" and select(4, ...) or select(3, ...)
        local data = { event = event, args = { ... }, spell = SpellName(spellID) }
        if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            data.channel = Call(UnitChannelInfo, "player")
        end
        Log("cast", data)
    elseif event == "LOOT_CLOSED" then
        Log("loot", { event = event })
    elseif LOOTS[event] then
        Log("loot", { event = event, args = { ... }, fishing = Call(IsFishingLoot),
            channel = Call(UnitChannelInfo, "player"), where = Where(), slots = Slots() })
    end
end)

--------------------------------------------------------------------------
-- /sd fishprobe
--------------------------------------------------------------------------

-- A value on one line, for the chat: tables in braces, keys in order.
local function Flat(value, depth)
    depth = depth or 0
    if type(value) ~= "table" then return tostring(value) end
    if depth >= DEPTH then return "{...}" end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = Flat(value[k], depth + 1)
        parts[#parts + 1] = type(k) == "number" and v or (tostring(k) .. "=" .. v)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function Report(rest)
    local p = Store()
    if not p then return end
    rest = (rest or ""):lower()
    local word, number = rest:match("^(%a*)%s*(%d*)")
    if word == "clear" then
        SocialDiaryCharDB.fishProbe = nil
        ns.Print("fishing probe cleared.")
    elseif word == "off" or word == "on" then
        on = word == "on"
        ns.Print("fishing probe %s.", word)
    elseif word == "show" then
        local count = math.min(tonumber(number) or 10, 40)
        local first = math.max(1, #p.log - count + 1)
        for i = first, #p.log do
            local line = p.log[i]
            ns.Print("%s", string.format("%.2f %s %s", line.at or 0, tostring(line.kind), Flat(line.data)))
        end
        if #p.log == 0 then ns.Print("fishing probe: nothing logged yet.") end
    else
        local counts = {}
        for _, line in ipairs(p.log) do counts[line.kind] = (counts[line.kind] or 0) + 1 end
        ns.Print("fishing probe (%s): %d lines (cast %d, loot %d) of %d; /sd fishprobe show [n] to read them, /reload to "
            .. "save, /sd fishprobe clear to empty.", on and "on" or "off", #p.log, counts.cast or 0,
            counts.loot or 0, MAX_LINES)
    end
end

ns.Slash.Register("fishprobe", Report, "fishing probe: |cffffd100/sd fishprobe [show [n]|clear|on|off]|r",
    { dev = true })
