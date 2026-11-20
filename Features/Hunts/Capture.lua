-- Hunts' capture (JRN-26, EXT-3): how many kills a quest's drops took,
-- kept on the logged-in character's route (Kind.lua's Begin, Kill, Drop,
-- Shared, Done) while it is kept (Journey.Kept).
--
-- The quest log says what a quest wants and how many are had;
-- PARTY_KILL says what the user or their group killed (plain under
-- combat lockdown, Session 1); the loot window says what each item came
-- off (GetLootSourceInfo, probe 11 Oct). A quest wanting items is counted
-- from when it is seen with none of them until it has them all. Where the
-- user runs QuestieDB, it names the item and every kind that drops it, and
-- Questie's drop rates say how many kills it should have taken (EXT-2).
--
-- Moved whole from Capture/Combat.lua (15 Oct; the close calls were judged
-- there too until they moved, the same day). It is listed in the TOC
-- where Capture/Combat.lua was, after Capture/ (Journey.lua) and before
-- the witnesses' capture, not in the features' block: it listens to
-- QUEST_LOG_UPDATE, QUEST_ACCEPTED, PLAYER_ENTERING_WORLD, QUEST_TURNED_IN,
-- QUEST_REMOVED, PARTY_KILL, LOOT_OPENED and the loot chat, several of
-- them heard by Capture/ too (Journey's quest taken, loot window and
-- login, Together's turn-in, Group's and Sightings' login; and Rares'
-- kill, run before this one as when it was Together's), so
-- every event order is the old one by construction, with nothing to
-- reason about. (The SD_QUEST_* messages the finales hear cover a quest
-- taken and turned in only; QUEST_REMOVED, QUEST_LOG_UPDATE and the rest
-- have none, so moving to them would not have kept the whole order.) The
-- route's gate is Journey.Kept, the same test as the Live() this file had
-- (the "Keep my own route" setting, the logged-in character's route, not
-- a test one).

local addonName, ns = ...

local Hunts = ns.Hunts

-- Seconds: how long the quest log's updates are gathered into one
-- reading; how long a quest gone from the log waits for its turn-in; how
-- long a want met with too few looted waits for a loot line still to come.
local WAIT = { scan = 0.2, removed = 1, looted = 1 }

local function Live() return ns.Journey.Kept() end

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

local function Name(unit)
    local name = ns.Plain((UnitName(unit)))
    return type(name) == "string" and name ~= "" and name or nil
end

-- The unit token on `guid`, if one still is: what the user points at,
-- then the nameplates.
local UNITS = { "target", "mouseover", "focus" }

local function UnitOn(guid)
    local function On(unit)
        if ns.Plain(UnitExists(unit)) and ns.Plain(UnitGUID(unit)) == guid then return unit end
    end
    return ns.Units.Each(UNITS, On) or ns.Units.Each(ns.Units.Plates, On)
end

-- The quests in the log, each { questID, title, index }: the current API
-- where the client has it, else the old one's.
local function Quests()
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetNumQuestLogEntries and Q.GetInfo then
        for i = 1, ns.Plain(Q.GetNumQuestLogEntries()) or 0 do
            local info = Q.GetInfo(i)
            if info and not info.isHeader and type(ns.Plain(info.questID)) == "number" then
                list[#list + 1] = { questID = info.questID, title = ns.Plain(info.title), index = i }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, ns.Plain(GetNumQuestLogEntries()) or 0 do
            local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
            if not isHeader and type(ns.Plain(questID)) == "number" then
                list[#list + 1] = { questID = questID, title = ns.Plain(title), index = i }
            end
        end
    end
    return list
end

-- "Plainstrider Meat: 3/7" (or "3/7 Plainstrider Meat"): the item, how
-- many are had and how many wanted.
local function Parse(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return nil end
    local have, need = text:match("(%d+)%s*/%s*(%d+)")
    local item = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", ""):gsub("^%s*%d+%s*/%s*%d+%s*", "")
    item = item:match("^%s*(.-)%s*$")
    return item, tonumber(have), tonumber(need)
end
Hunts.Parse = Parse

-- A quest's objectives that want items, each { index, item, have, need,
-- finished }.
local function Wants(quest)
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetQuestObjectives then
        for i, o in ipairs(Q.GetQuestObjectives(quest.questID) or {}) do
            if ns.Plain(o.type) == "item" then
                local item, have, need = Parse(o.text)
                have, need = ns.Plain(o.numFulfilled) or have, ns.Plain(o.numRequired) or need
                list[#list + 1] = { index = i, item = item, have = have, need = need,
                    finished = ns.Plain(o.finished) == true }
            end
        end
    elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for i = 1, ns.Plain(GetNumQuestLeaderBoards(quest.index)) or 0 do
            local text, kind, finished = GetQuestLogLeaderBoard(i, quest.index)
            if ns.Plain(kind) == "item" then
                local item, have, need = Parse(text)
                list[#list + 1] = { index = i, item = item, have = have, need = need,
                    finished = ns.Plain(finished) == true }
            end
        end
    end
    return list
end

-- The drop rates, where the user runs Questie or its database (EXT-2).
local function Rate(itemID, npcID)
    return ns.QuestieBridge and ns.QuestieBridge.DropRate(itemID, npcID)
end

-- Wowhead's, where the first cannot be believed (Hunts.Believable).
local function Wowhead(itemID, npcID)
    return ns.QuestieBridge and ns.QuestieBridge.WowheadRate(itemID, npcID)
end

local function Done(j, questID, index)
    local rec = Hunts.Done(j, questID, index, { t = ns.Now(), level = Level(), Rates = { Rate, Wowhead } })
    if rec and rec.npcID and ns.Deaths then ns.Deaths.LookUp(rec) end
    if rec then ns.Debug("hunt done: %s, %d kills for %d", tostring(rec.item), rec.kills, rec.need) end
    return rec
end

-- A met want with fewer looted than it wants (Hunts.Short) is ended a
-- moment later, in case the last loot line is still to come: then it is
-- no hunt, and keeps nothing. Each such want waits once.
local waiting = {}

local function Met(j, questID, index)
    if not Hunts.Short(Hunts.Hunting(j, questID, index)) then return Done(j, questID, index) end
    local key = Hunts.Key(questID, index)
    if waiting[key] then return end
    waiting[key] = true
    ns.After(WAIT.looted, function()
        waiting[key] = nil
        local now = Live()
        if not Hunts.Hunting(now, questID, index) then return end
        if Hunts.Short(Hunts.Hunting(now, questID, index)) then
            ns.Debug("hunt dropped: %s came otherwise than looted", tostring(Hunts.Hunting(now, questID, index).item))
        end
        Done(now, questID, index)
    end)
end

-- One reading of the log: a want with none had yet begins a hunt, a hunt
-- whose want is met ends.
function Hunts.Scan()
    local j = Live()
    if not j then return end
    for _, quest in ipairs(Quests()) do
        for _, want in ipairs(Wants(quest)) do
            local met = want.finished or (want.have and want.need and want.have >= want.need)
            if Hunts.Hunting(j, quest.questID, want.index) then
                if met then Met(j, quest.questID, want.index) end
            elseif not met and want.have == 0 then
                -- What it is, and every kind that drops it, where QuestieDB
                -- says (EXT-2).
                local Q = ns.QuestieBridge
                local itemID = Q and Q.ItemFor(quest.questID, want.item)
                Hunts.Begin(j, { questID = quest.questID, index = want.index, title = quest.title,
                    item = want.item, need = want.need, t = ns.Now(), itemID = itemID,
                    droppers = itemID and Q.Droppers(itemID) })
            end
        end
    end
end

local queued = false

local function Queue()
    if queued then return end
    queued = true
    ns.After(WAIT.scan, function()
        queued = false
        Hunts.Scan()
    end)
end

ns.On("QUEST_LOG_UPDATE", Queue)
ns.On("QUEST_ACCEPTED", Queue)
ns.On("PLAYER_ENTERING_WORLD", Queue)

-- Handed in: whatever was still being counted for it was met.
ns.On("QUEST_TURNED_IN", function(_, questID)
    local j = Live()
    questID = ns.Plain(questID)
    if not (j and j.hunting and type(questID) == "number") then return end
    local done = {}
    for _, hunt in pairs(j.hunting) do
        if hunt.questID == questID then done[#done + 1] = hunt.index end
    end
    for _, index in ipairs(done) do Done(j, questID, index) end
end)

-- Abandoned, or handed in: the turn-in has a moment to come first.
ns.On("QUEST_REMOVED", function(_, questID)
    questID = ns.Plain(questID)
    if type(questID) ~= "number" then return end
    ns.After(WAIT.removed, function() Hunts.Gone(Live(), questID) end)
end)

local function Hunting(j)
    return j and j.hunting and next(j.hunting) ~= nil
end

ns.On("PARTY_KILL", function(_, attacker, victim)
    local j = Live()
    if not Hunting(j) then return end
    attacker = ns.SafeGUID(attacker)
    if not attacker or not (attacker == ns.ownGUID or ns.Roster.Has(attacker)) then return end
    victim = ns.Plain(victim)
    local npcID = ns.NpcID(victim)
    if not npcID then return end
    local unit = UnitOn(victim)
    Hunts.Kill(j, npcID, unit and Name(unit))
end)

-- What the loot window holds, and what each item came off.
ns.On("LOOT_OPENED", function()
    local j = Live()
    if not Hunting(j) or not (GetNumLootItems and GetLootSourceInfo) then return end
    for slot = 1, ns.Plain(GetNumLootItems()) or 0 do
        local link = ns.Plain(GetLootSlotLink(slot))
        local item = type(link) == "string" and link:match("%[(.-)%]")
        if item then
            local sources = { GetLootSourceInfo(slot) }
            for i = 1, #sources, 2 do
                local guid = ns.Plain(sources[i])
                local npcID = ns.NpcID(guid)
                if npcID then
                    local unit = UnitOn(guid)
                    Hunts.Drop(j, item, npcID, unit and Name(unit), tonumber(link:match("item:(%d+)")))
                end
            end
        end
    end
end)

-- The user's own loot lines, in the client's words (as the firsts read
-- them): a hunted item looted. Mail, a trade, the bank and a vendor say
-- nothing of the kind, so what came that way is not counted.
local LOOTED = { "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }

local function Own(text)
    for _, line in ipairs(LOOTED) do
        local args = ns.ReadString(_G[line], text)
        if args then return args[1], tonumber(args[2]) or 1 end
    end
end

-- A group member's loot (the party's loot message, plain, probe 12 Oct):
-- a hunted item they took is one the group's kills gave and the user could
-- not have (Hunts.Shared). The looter by their GUID, so the message's
-- words in any language do not matter; "x3" after the link is three.
ns.OnChat("CHAT_MSG_LOOT", function(text, _, guid)
    local j = Live()
    if not Hunting(j) then return end
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local link, count = Own(text)
    if link then
        local item = link:match("|h%[(.-)%]|h")
        if item and Hunts.Looted(j, item, tonumber(link:match("|Hitem:(%d+)")), count) then
            ns.Debug("hunt looted: %d %s", count, item)
        end
        return
    end
    if not guid or guid == ns.ownGUID or not ns.Roster.Has(guid) then return end
    local item = text:match("|h%[(.-)%]|h")
    if not item then return end
    local itemID = tonumber(text:match("|Hitem:(%d+)"))
    local n = tonumber(text:match("|h|r?x(%d+)")) or 1
    if Hunts.Shared(j, item, itemID, n) then
        ns.Debug("hunt shared: %s took %d %s", tostring(guid), n, item)
    end
end)
