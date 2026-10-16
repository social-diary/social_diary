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

-- A global string as a pattern: "%s receives loot: %s." with its
-- arguments' order ("%2$s" comes second).
local function Pattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local out, order = {}, {}
    local i = 1
    while i <= #fmt do
        local s, e, pos, conv = fmt:find("^%%(%d?)%$?([sd])", i)
        if fmt:sub(i, i + 1) == "%%" then
            out[#out + 1] = "%%"
            i = i + 2
        elseif s then
            order[#order + 1] = tonumber(pos) or (#order + 1)
            out[#out + 1] = conv == "d" and "(%d+)" or "(.+)"
            i = e + 1
        else
            local c = fmt:sub(i, i)
            out[#out + 1] = c:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") and ("%" .. c) or c
            i = i + 1
        end
    end
    return "^" .. table.concat(out) .. "$", order
end

local function Read(fmt, text)
    local pattern, order = Pattern(fmt)
    if not pattern or type(text) ~= "string" then return nil end
    local found = { text:match(pattern) }
    if #found == 0 then return nil end
    local args = {}
    for k, at in ipairs(order) do args[at] = found[k] end
    return args
end

-- The dungeon was reset: the next time in is a new run (INS-8).
ns.On("CHAT_MSG_SYSTEM", function(_, text)
    text = ns.Plain(text)
    if Read(INSTANCE_RESET_SUCCESS, text) then Instances.Reset() end
end)

--------------------------------------------------------------------------
-- Loot (INS-31)
--------------------------------------------------------------------------

-- A member by the name a loot line gives ("Feivel", or "Feivel-Realm").
local function MemberNamed(name)
    local visit = Instances.Current()
    name = type(name) == "string" and name:match("^([^%-]+)")
    if not visit or not name then return nil end
    local found
    for _, m in ipairs(visit.members or {}) do
        if m.first == name then
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

ns.OnChat("CHAT_MSG_LOOT", function(text, sender, guid)
    if not Instances.Inside() then return end
    text = ns.Plain(text)
    if type(text) ~= "string" then return end

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
