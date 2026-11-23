-- Questie and its database, when the user runs them (.claude/addon-
-- integrations.md, EXT-1 to EXT-3). The only file that knows their names,
-- globals and shapes: everything else asks the few functions below, which
-- answer plain values or nil, and nil is always the diary as it was.
--
-- QuestieDB (LibQuestieDB, contract 3) keeps every creature, item and
-- quest; Questie keeps the drop rates (its DropDB). Without Questie the
-- rates are read off QuestieDB's support tables the way Questie reads them:
-- its corrections first, then cmangos, then wowhead. Read only, never
-- written; each answer is kept for the session, since QuestieDB decodes a
-- table afresh on every read.

local addonName, ns = ...

local Bridge = {}
ns.QuestieBridge = Bridge

local CONTRACT = 3

-- Whether QuestieDB is there and speaks the contract this file was written
-- against. Asked every time (cheap), so a test can bring it and take it away.
local function DB()
    local lib = rawget(_G, "LibQuestieDB")
    if type(lib) ~= "table" or type(lib.RequireContract) ~= "function" then return nil end
    local ok, fits = pcall(lib.RequireContract, CONTRACT)
    if not ok or not fits then return nil end
    return lib
end
Bridge.On = function() return DB() ~= nil end

-- What Settings > Integrations shows: "on" where its database answers,
-- "old" where Questie or its database is there but not one this file can
-- read, "off" where neither is.
function Bridge.Status()
    if DB() then return "on" end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    local function Has(name)
        if loaded then
            local ok, yes = pcall(loaded, name)
            if ok and yes then return true end
        end
        return false
    end
    if rawget(_G, "LibQuestieDB") or rawget(_G, "Questie") or Has("QuestieDB") or Has("Questie") then return "old" end
    return "off"
end

-- A field of an entity, guarded: nil for anything that is not there or
-- errors.
local function Get(kind, id, field)
    local lib = DB()
    local entity = lib and lib[kind]
    if type(entity) ~= "table" or type(entity.Get) ~= "function" or type(id) ~= "number" then return nil end
    local ok, value = pcall(entity.Get, id, field)
    if ok then return value end
    return nil
end

local function Raw(kind, id, field)
    local lib = DB()
    local entity = lib and lib[kind]
    if type(entity) ~= "table" or type(entity.GetRaw) ~= "function" then return nil end
    local ok, value = pcall(entity.GetRaw, id, field)
    if ok then return value end
    return nil
end

local function English()
    local locale = GetLocale and GetLocale()
    return locale == "enUS" or locale == "enGB"
end

--------------------------------------------------------------------------
-- Names (EXT-1)
--------------------------------------------------------------------------

local names = {}

-- A creature's name in the client's language, by its kind's id; nil where
-- QuestieDB has none, or has it only in English on a client that is not.
-- (A name the same in both languages is lost that way: rare, and a recap
-- or a unit still names it.)
function Bridge.NpcName(npcID)
    if type(npcID) ~= "number" then return nil end
    local known = names[npcID]
    if known ~= nil then return known or nil end
    local name = Get("Npc", npcID, "name")
    if type(name) ~= "string" or name == "" then name = nil end
    if name and not English() and Raw("Npc", npcID, "name") == name then name = nil end
    -- Only kept once QuestieDB has answered: without it, nothing is learnt.
    if DB() then names[npcID] = name or false end
    return name
end

--------------------------------------------------------------------------
-- Quest drops (EXT-2)
--------------------------------------------------------------------------

-- The item that objective's `itemName` is, for quest `questID`: one of the
-- quest's item objectives, by its name in the client's language; the only
-- one, where there is only one.
function Bridge.ItemFor(questID, itemName)
    local objectives = Get("Quest", questID, "objectives")
    local items = type(objectives) == "table" and objectives[3]
    if type(items) ~= "table" then return nil end
    local ids = {}
    for _, entry in pairs(items) do
        local id = type(entry) == "table" and entry[1]
        if type(id) == "number" then ids[#ids + 1] = id end
    end
    if type(itemName) == "string" then
        local lower = itemName:lower()
        for _, id in ipairs(ids) do
            local name = Get("Item", id, "name")
            if type(name) == "string" and (name == itemName or name:lower() == lower) then return id end
        end
    end
    if #ids == 1 then return ids[1] end
    return nil
end

local droppers = {}

-- Every kind of creature that drops item `itemID`, as a list of npcIDs.
function Bridge.Droppers(itemID)
    if type(itemID) ~= "number" then return nil end
    if droppers[itemID] ~= nil then return droppers[itemID] or nil end
    local list = Get("Item", itemID, "npcDrops")
    local out = {}
    for _, id in pairs(type(list) == "table" and list or {}) do
        if type(id) == "number" then out[#out + 1] = id end
    end
    table.sort(out)
    if #out == 0 then out = nil end
    if DB() then droppers[itemID] = out or false end
    return out
end

-- The server's item flag for a drop a corpse gives everyone who may loot
-- it (its "party loot", in QuestieDB's `flags` as the server has them).
local PARTY_LOOT = 2048

local partyLoot = {}

-- Whether item `itemID` is looted by each of a group off the same corpse,
-- a copy of their own for everyone on its quest: so the heads and other
-- trophies of the named, where what a quest gathers by the dozen goes to
-- one of them only. nil where QuestieDB is away.
function Bridge.PartyLoot(itemID)
    if type(itemID) ~= "number" then return nil end
    if partyLoot[itemID] ~= nil then return partyLoot[itemID] end
    if not DB() then return nil end
    local flags = Get("Item", itemID, "flags")
    local each = type(flags) == "number" and flags % (PARTY_LOOT * 2) >= PARTY_LOOT
    partyLoot[itemID] = each
    return each
end

-- The drop tables, read off QuestieDB's support data once: [itemID] =
-- { [npcID] = percent }. A table that does not read is empty.
local tables

local function Decode(text)
    if type(text) == "table" then return text end
    if type(text) ~= "string" or not loadstring then return {} end
    local chunk = loadstring(text)
    if not chunk then return {} end
    setfenv(chunk, {})
    local ok, value = pcall(chunk)
    return ok and type(value) == "table" and value or {}
end

local function Tables()
    if tables then return tables end
    local lib = DB()
    local support = lib and lib.Support
    if type(support) ~= "table" or type(support.Get) ~= "function" then return nil end
    local drops = support.Get("QuestieClassicItemDrops") or {}
    local fixes = support.Get("QuestieItemDropCorrections") or {}
    tables = { wowhead = Decode(drops.wowheadData), cmangos = Decode(drops.cmangosData),
        fixes = type(fixes.Era) == "table" and fixes.Era or {} }
    return tables
end

-- Questie's own reckoning, where Questie runs and has its tables loaded.
local function Questies(itemID, npcID)
    local loader = rawget(_G, "QuestieLoader")
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return nil end
    local ok, drop = pcall(loader.ImportModule, loader, "DropDB")
    if not ok or type(drop) ~= "table" or type(drop.GetItemDroprate) ~= "function" or not drop.tableWowhead then
        return nil
    end
    local okRate, rate = pcall(drop.GetItemDroprate, itemID, npcID)
    if okRate and type(rate) == "table" then return rate[1] end
    return nil
end

local WOWHEAD, CMANGOS = -1, -2

-- How often a creature of kind `npcID` drops item `itemID`, in percent;
-- nil where nobody knows.
function Bridge.DropRate(itemID, npcID)
    if type(itemID) ~= "number" or type(npcID) ~= "number" or not DB() then return nil end
    local rate = Questies(itemID, npcID)
    if rate == nil then
        local t = Tables()
        if not t then return nil end
        local fix = t.fixes[itemID] and t.fixes[itemID][npcID]
        local cm = t.cmangos[itemID] and t.cmangos[itemID][npcID]
        local wh = t.wowhead[itemID] and t.wowhead[itemID][npcID]
        if type(fix) == "number" and fix >= 0 then
            rate = fix
        elseif fix == WOWHEAD and wh then
            rate = wh
        elseif fix == CMANGOS and cm then
            rate = cm
        else
            rate = cm or wh
        end
    end
    if type(rate) ~= "number" or rate <= 0 then return nil end
    return rate
end

-- Wowhead's rate alone, in percent, nil where it has none: the second
-- opinion where the first source's makes a hunt past belief
-- (the caller says what it cannot believe; QuestieDB's server data gives some items one rate
-- for every creature, 66% for a Red Linen Bandana where Wowhead has 37%).
function Bridge.WowheadRate(itemID, npcID)
    if type(itemID) ~= "number" or type(npcID) ~= "number" or not DB() then return nil end
    local t = Tables()
    local rate = t and t.wowhead[itemID] and t.wowhead[itemID][npcID]
    if type(rate) ~= "number" or rate <= 0 then return nil end
    return rate
end

-- For the tests: forget what was kept.
function Bridge.Reset()
    names, droppers, partyLoot, tables = {}, {}, {}, nil
end
