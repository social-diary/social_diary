-- Dungeon and raid runs (.claude/dungeon-visits-prd.md §4, §18): in and
-- out, the boss pulls and kills, the loot. Core/Instances.lua keeps the
-- run; who is in it comes from Core/Roster.lua's scans, who died from the
-- deaths' capture.
--
-- What the client gives, and how far it can be trusted:
--
--   in and out    IsInInstance / GetInstanceInfo on entering the world and
--                 on a zone change (not secret, feasibility report C4).
--   pulls         ENCOUNTER_START / ENCOUNTER_END (E1). Dungeon Crawler
--                 Forever found that Forever fires ENCOUNTER_END, not
--                 BOSS_KILL, for dungeon bosses, and that the id and name
--                 may be secret. A secret value is kept as nil and the
--                 pull says `secret`: the probe's answer, read off the save.
--   loot          CHAT_MSG_LOOT, read through the client's own strings
--                 (LOC-1), never English words. Under chat lockdown the
--                 text is secret and the line is let go.
--
-- After Capture/Group.lua in the TOC: on a zone change into a dungeon the
-- group is scanned straight after the run opens, so its members are in it.

local addonName, ns = ...

local Instances = ns.Instances

local function Flag(fn, ...)
    if not fn then return false end
    return ns.Plain(fn(...)) == true
end

-- In a party or raid instance now: its info, or nil.
local function Here()
    if not IsInInstance then return nil end
    local inside, kind = IsInInstance()
    if ns.Plain(inside) ~= true then return nil end
    kind = ns.Plain(kind)
    if kind ~= "party" and kind ~= "raid" then return nil end
    local name, _, difficultyID, difficulty, _, _, _, id = GetInstanceInfo()
    id = ns.Plain(id)
    if type(id) ~= "number" then return nil end
    return { instanceID = id, name = ns.Plain(name), instanceType = kind,
        difficultyID = ns.Plain(difficultyID), difficulty = ns.Plain(difficulty) }
end

local function Check()
    if not ns.ownGUID then return end
    local now = ns.Now()
    Instances.Expire(now)
    local info = Here()
    if info then
        Instances.Enter(info, now)
        if ns.Group and ns.Group.Scan then ns.Group.Scan() end
    elseif Instances.Inside() then
        Instances.Leave(now, Flag(UnitIsDeadOrGhost, "player"))
    end
end
ns._test.InstancesCheck = Check

ns.On("PLAYER_ENTERING_WORLD", function()
    -- GetInstanceInfo can still name the last map for a moment.
    ns.After(1, Check)
end)
ns.On("ZONE_CHANGED_NEW_AREA", Check)

-- A run left behind ends GAP after the last time out, even when nothing
-- else happens.
ns.Every(30, function() Instances.Expire() end)

--------------------------------------------------------------------------
-- Pulls (INS-28)
--------------------------------------------------------------------------

local function Readable(id, name)
    local secret = ns.IsSecret(id) or ns.IsSecret(name)
    id, name = ns.Plain(id), ns.Plain(name)
    if type(id) ~= "number" then id = nil end
    if type(name) ~= "string" or name == "" then name = nil end
    return id, name, secret
end

ns.On("ENCOUNTER_START", function(_, id, name)
    local secret
    id, name, secret = Readable(id, name)
    Instances.Pull(id, name, secret)
end)

ns.On("ENCOUNTER_END", function(_, id, name, _, _, success)
    local secret
    id, name, secret = Readable(id, name)
    success = ns.Plain(success)
    Instances.PullEnd(id, name, success == 1 or success == true, secret)
end)

ns.On("BOSS_KILL", function(_, id, name)
    local secret
    id, name, secret = Readable(id, name)
    Instances.PullEnd(id, name, true, secret)
end)

--------------------------------------------------------------------------
-- The client's own sentences (LOC-1)
--------------------------------------------------------------------------

-- A global string read back out of a line (Core/Events.lua).
local Read = ns.ReadString

-- The dungeon was reset: the next time in is a new run (INS-8).
ns.On("CHAT_MSG_SYSTEM", function(_, text)
    text = ns.Plain(text)
    if Read(INSTANCE_RESET_SUCCESS, text) then Instances.Reset() end
end)

--------------------------------------------------------------------------
-- Loot (INS-31)
--------------------------------------------------------------------------

-- A member by the name a loot line gives ("Feivel", "Feivel-Realm", or
-- with the surname Forever shows: "Feivel Emmenthal", as the probe's
-- "Horrible Man rolls 86" was written, 16 Oct).
local function MemberNamed(name)
    local visit = Instances.Current()
    name = type(name) == "string" and name:match("^([^%-]+)")
    if not visit or not name then return nil end
    local found
    for _, m in ipairs(visit.members or {}) do
        local full = m.first and m.surname and (m.first .. " " .. m.surname)
        if m.first == name or full == name then
            if found then return nil end -- two of a name: guess no one
            found = m.guid
        end
    end
    return found
end

-- Anything off one of this dungeon's loot tables (a quest item off a boss
-- is the run's too), or a blue or better from anywhere. Trash greens are
-- left: a night's run drops dozens and they would fill the run's loot.
local RARE = 3
local function Worth(link)
    local visit = Instances.Current()
    local itemID = tonumber(link:match("item:(%d+)"))
    if visit and ns.Dungeons.LootBoss(visit.instanceID, itemID) then return true end
    local quality = ns.Timeline.Quality(link)
    return quality ~= nil and quality >= RARE
end

--------------------------------------------------------------------------
-- Rolls (pass B, untested in the client)
--------------------------------------------------------------------------
--
-- The client's sentences for group loot (read off the probe's save, 16
-- Oct, Dev/LootProbe.lua): each begins with the drop's loot history id
-- ("|HlootHistory:%d|h[Loot]|h: ..."), which keys the drop. With the
-- quiet loot setting the client says only the user's own roll
-- (LOOT_ROLL_LOST_ROLL) and the winner's (the _NO_SPAM_ sentences); with
-- it off, everyone's (LOOT_ROLL_ROLLED_NEED). Only Need counts. Each is
-- { global string's name, what its arguments are (in order) }: `id` the
-- key, `who` a name, `item` the link, `roll` a number, `kind` the roll's
-- name (Need, Greed), `need`/`won`/`self` what the sentence says.
local ROLL_LINES = {
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", { "id", "roll", "item" }, need = true, won = true, self = true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED_OFF_SPEC", { "id", "roll", "item" }, need = true, won = true, self = true },
    { "LOOT_ROLL_WON_NO_SPAM_NEED", { "id", "who", "roll", "item" }, need = true, won = true },
    { "LOOT_ROLL_WON_NO_SPAM_NEED_OFF_SPEC", { "id", "who", "roll", "item" }, need = true, won = true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", { "id", "roll", "item" }, won = true, self = true },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", { "id", "who", "roll", "item" }, won = true },
    { "LOOT_ROLL_ROLLED_NEED", { "id", "roll", "item", "who" }, need = true },
    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", { "roll", "item", "who" }, need = true },
    { "LOOT_ROLL_LOST_ROLL", { "id", "kind", "roll", "item" }, self = true },
    { "LOOT_ROLL_NEED_SELF", { "id", "item" }, need = true, self = true },
    { "LOOT_ROLL_NEED_SELF_OFF_SPEC", { "id", "item" }, need = true, self = true },
    { "LOOT_ROLL_NEED", { "id", "who", "item" }, need = true },
    { "LOOT_ROLL_YOU_WON", { "id", "item" }, won = true, self = true },
    { "LOOT_ROLL_WON", { "id", "who", "item" }, won = true },
}
ns._test.ROLL_LINES = ROLL_LINES

-- A roll line, told to Core/Instances.lua. Returns whether it was one.
local function RollLine(text)
    for _, line in ipairs(ROLL_LINES) do
        local args = Read(_G[line[1]], text)
        if args then
            local got = {}
            for i, name in ipairs(line[2]) do got[name] = args[i] end
            local need = line.need
            -- "You have rolled Need - 80 for: ...": its kind in the
            -- client's own word for Need.
            if got.kind then need = got.kind == (NEED or "Need") end
            local who = line.self and ns.ownGUID or MemberNamed(got.who)
            if got.item and who and (need or line.won) then
                Instances.Roll(tonumber(got.id), got.item, { guid = who, need = need or nil,
                    roll = need and tonumber(got.roll) or nil, won = line.won or nil })
            end
            return true
        end
    end
    return false
end
ns._test.RollLine = RollLine

-- The client's loot history, where it says more than the chat: every
-- roll on a drop, by GUID. Its states (Enum.EncounterLootDropRollState)
-- name Need for the main spec and the off spec.
local function HistoryNeed(state)
    local S = Enum and Enum.EncounterLootDropRollState
    if not S then return false end
    return state ~= nil and (state == S.NeedMainSpec or state == S.NeedOffSpec)
end

ns.On("LOOT_HISTORY_UPDATE_DROP", function(_, encounterID, lootListID)
    local H = C_LootHistory
    if not (Instances.Inside() and H and H.GetSortedInfoForDrop) then return end
    local ok, info = pcall(H.GetSortedInfoForDrop, ns.Plain(encounterID), ns.Plain(lootListID))
    info = ok and ns.Plain(info)
    if type(info) ~= "table" then return end
    local link = ns.Plain(info.itemHyperlink)
    if type(link) ~= "string" then return end
    local key = ("h%s:%s"):format(tostring(ns.Plain(encounterID)), tostring(ns.Plain(lootListID)))
    local rolls = ns.Plain(info.rollInfos)
    for _, r in ipairs(type(rolls) == "table" and rolls or {}) do
        r = ns.Plain(r)
        local guid = type(r) == "table" and ns.SafeGUID(r.playerGUID)
        if guid then
            local need = HistoryNeed(ns.Plain(r.state))
            Instances.Roll(key, link, { guid = guid, need = need or nil,
                roll = need and tonumber(ns.Plain(r.roll)) or nil, won = ns.Plain(r.isWinner) == true or nil })
        end
    end
end)

ns.OnChat("CHAT_MSG_LOOT", function(text, sender, guid)
    if not Instances.Inside() then return end
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    if RollLine(text) then return end

    local who, link
    local mine = Read(LOOT_ITEM_SELF_MULTIPLE, text) or Read(LOOT_ITEM_SELF, text)
    if mine then
        who, link = ns.ownGUID, mine[1]
    else
        local theirs = Read(LOOT_ITEM_MULTIPLE, text) or Read(LOOT_ITEM, text)
        if not theirs then return end
        who = (guid ~= ns.ownGUID and guid) or MemberNamed(theirs[1])
        link = theirs[2]
    end
    if who and link and Worth(link) then Instances.Loot(who, link) end
end)
