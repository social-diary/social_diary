-- A probe for pass B of the dungeon sheet (.claude/dungeon-visits-prd.md):
-- what the client says about group loot rolls, and whether the damage
-- meter and the party's health can tell a group-wide close call. Logged to
-- SocialDiaryCharDB.probe while inside a party or raid instance, read off
-- the save after a /reload; nothing else reads it.
--
-- What it keeps, each line with its time:
--   globals   every LOOT_ROLL* string the client has, once a login: the
--             sentences the roll lines are written in, in this client
--   chat      CHAT_MSG_LOOT and CHAT_MSG_SYSTEM as they came (or <secret>)
--   rolls     START_LOOT_ROLL with the item, CANCEL_LOOT_ROLL, and the
--             loot history's events with what C_LootHistory gives for them
--   fights    after ENCOUNTER_END and at combat's end: the meter's damage
--             taken and healing done by source, and each party unit's
--             health and maximum, or <secret>
--
-- It holds real names: it stays in the local save, is never committed or
-- copied into tests, and /sd probe clear empties it. Dev only: the TOC's
-- Dev/ block goes in a release.

local addonName, ns = ...

local MAX_LINES = 1500
-- Tables are written this deep; deeper is "<table>".
local DEPTH = 4

local function Store()
    if type(SocialDiaryCharDB) ~= "table" then return nil end
    local p = SocialDiaryCharDB.probe
    if type(p) ~= "table" then
        p = { log = {}, globals = {} }
        SocialDiaryCharDB.probe = p
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

local function Inside()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    kind = ns.Plain(kind)
    return ns.Plain(inside) == true and (kind == "party" or kind == "raid")
end

local function Log(kind, data)
    local p = Store()
    if not p or #p.log >= MAX_LINES then return end
    p.log[#p.log + 1] = { t = GetServerTime and GetServerTime() or 0, kind = kind, data = Dump(data) }
end

-- Calls `fn` on `...` and keeps what came back, or the error.
local function Call(fn, ...)
    if type(fn) ~= "function" then return "<missing>" end
    local results = { pcall(fn, ...) }
    if not results[1] then return { error = tostring(results[2]) } end
    table.remove(results, 1)
    return results
end

--------------------------------------------------------------------------
-- The client's sentences
--------------------------------------------------------------------------

local function Globals()
    local p = Store()
    if not p then return end
    p.globals = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string"
            and (key:find("^LOOT_ROLL") or key:find("^LOOT_ITEM") or key:find("^RANDOM_ROLL")) then
            p.globals[key] = value
        end
    end
end

--------------------------------------------------------------------------
-- The fights: the meter and the party's health
--------------------------------------------------------------------------

local function Meter(kindName)
    local meter, types = C_DamageMeter, Enum and Enum.DamageMeterType
    local which = types and types[kindName]
    if not (meter and which) then return "<no meter>" end
    local out = {}
    if meter.GetAvailableCombatSessions then
        out.sessions = Call(meter.GetAvailableCombatSessions)
    end
    if meter.GetCombatSessionFromType and Enum.DamageMeterSessionType then
        out.current = Call(meter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, which)
    end
    return out
end

local function Party()
    local out = {}
    for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        if UnitExists and ns.Plain(UnitExists(unit)) then
            out[unit] = {
                name = Call(UnitName, unit),
                guid = Call(UnitGUID, unit),
                health = Call(UnitHealth, unit),
                healthMax = Call(UnitHealthMax, unit),
                dead = Call(UnitIsDeadOrGhost, unit),
            }
        end
    end
    return out
end

local function Fight(why, ...)
    local args = { ... }
    ns.After(1, function()
        if not Inside() then return end
        Log("fight", { why = why, args = args, taken = Meter("DamageTaken"),
            healing = Meter("HealingDone"), party = Party() })
    end)
end

--------------------------------------------------------------------------
-- Listening
--------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local function Listen(event)
    pcall(frame.RegisterEvent, frame, event)
end

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM",
    "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CONFIRM_LOOT_ROLL", "LOOT_ROLLS_COMPLETE",
    "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_CLEAR_HISTORY",
    "LOOT_HISTORY_ROLL_CHANGED", "LOOT_HISTORY_ROLL_COMPLETE", "LOOT_HISTORY_FULL_UPDATE",
    "ENCOUNTER_END", "PLAYER_REGEN_ENABLED",
}) do
    Listen(event)
end

local history = {
    LOOT_HISTORY_UPDATE_DROP = function(encounterID, lootListID)
        local H = C_LootHistory
        return H and Call(H.GetSortedInfoForDrop, encounterID, lootListID) or "<no C_LootHistory>"
    end,
    LOOT_HISTORY_UPDATE_ENCOUNTER = function(encounterID)
        local H = C_LootHistory
        return H and Call(H.GetSortedDropsForEncounter, encounterID) or "<no C_LootHistory>"
    end,
    LOOT_HISTORY_ROLL_CHANGED = function(itemIdx, playerIdx)
        local H = C_LootHistory
        if not H then return "<no C_LootHistory>" end
        return { item = Call(H.GetItem, itemIdx), player = Call(H.GetPlayerInfo, itemIdx, playerIdx) }
    end,
    LOOT_HISTORY_ROLL_COMPLETE = function()
        local H = C_LootHistory
        if not (H and H.GetNumItems) then return "<no C_LootHistory>" end
        local out = { n = Call(H.GetNumItems) }
        local n = ns.Plain(out.n[1])
        for i = 1, (type(n) == "number" and math.min(n, 20) or 0) do
            out[i] = Call(H.GetItem, i)
        end
        return out
    end,
}

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        Globals()
        return
    end
    if not Inside() then return end
    if event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM" then
        local text, sender = ...
        Log("chat", { event = event, text = text, sender = sender, guid = select(12, ...) })
    elseif event == "START_LOOT_ROLL" then
        local rollID = ...
        Log("roll", { event = event, args = { ... }, link = Call(GetLootRollItemLink, rollID),
            info = Call(GetLootRollItemInfo, rollID) })
    elseif history[event] then
        Log("roll", { event = event, args = { ... }, history = history[event](...) })
    elseif event == "ENCOUNTER_END" or event == "PLAYER_REGEN_ENABLED" then
        Fight(event, ...)
    else
        Log("roll", { event = event, args = { ... } })
    end
end)

--------------------------------------------------------------------------
-- /sd probe
--------------------------------------------------------------------------

local function Report(rest)
    local p = Store()
    if not p then return end
    if rest == "clear" then
        SocialDiaryCharDB.probe = nil
        ns.Print("probe cleared.")
        return
    end
    local counts = {}
    for _, line in ipairs(p.log) do counts[line.kind] = (counts[line.kind] or 0) + 1 end
    ns.Print("probe: %d lines (chat %d, roll %d, fight %d) of %d; /reload to save, /sd probe clear to empty.",
        #p.log, counts.chat or 0, counts.roll or 0, counts.fight or 0, MAX_LINES)
end

ns.Slash.Register("probe", Report, "loot roll and close-call probe: |cffffd100/sd probe [clear]|r", { dev = true })
