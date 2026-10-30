-- Grouping capture (INT-1 "grouping", Must): who is in the group now.
--
-- This file reads the unit tokens; Core/Roster.lua diffs them against the
-- group as last seen and writes the join and leave rows, the sessions and
-- the persisted roster.
--
-- Two ways a scan can lie, both guarded:
--
--   * Right after login the roster is not populated yet, so a scan would read
--     the whole group as gone. Scans wait until a short settle delay after
--     PLAYER_ENTERING_WORLD.
--   * A member whose GUID reads as secret (instanced maps, per the
--     feasibility report's B1) is not the same as a member who left. When
--     fewer members are readable than the client says there are, the scan is
--     incomplete: joins are recorded, leaves are not.

local addonName, ns = ...

local Group = {}
ns.Group = Group

-- Seconds after entering the world before the roster is trusted.
local SETTLE_DELAY = 3

local settled = false

local function Expected()
    if not (IsInGroup and IsInGroup()) then return 0 end
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    return math.max(n - 1, 0)
end

function Group.Scan()
    if not settled or not ns.ownGUID then return end

    local current, readable = {}, 0

    -- The user is excluded by ns.PlayerGUIDFromUnit, which matters in a raid,
    -- whose raidN tokens include them.
    ns.Units.Each(ns.Units.Group(), function(unit)
        -- Not `visible`: a member across the map is still in the group.
        local guid = ns.PlayerGUIDFromUnit(unit)
        if guid then
            ns.Characters.ObserveUnit(unit)
            local guild = (UnitIsInMyGuild and ns.Plain(UnitIsInMyGuild(unit))) or nil
            current[guid] = { guild = guild }
            readable = readable + 1
        end
    end)

    local raid = (IsInRaid and IsInRaid()) or nil
    ns.Roster.Update(current, readable >= Expected(), raid)
end

ns.On("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    if not (isLogin or isReload) then return end

    settled = false
    ns.Roster.ForgetStale()

    ns.After(SETTLE_DELAY, function()
        settled = true
        Group.Scan()
    end)
end)

-- A raid's roster comes in bursts, and each scan reads up to 40 units: a
-- burst is one scan, just after it. A party's is read as it comes.
local RAID_SETTLE = 0.5
local scanWaiting = false

ns.On("GROUP_ROSTER_UPDATE", function()
    if not (IsInRaid and IsInRaid()) then return Group.Scan() end
    if scanWaiting then return end
    scanWaiting = true
    ns.After(RAID_SETTLE, function()
        scanWaiting = false
        Group.Scan()
    end)
end)

-- Levels move while grouped, and SES-4 wants their level at the end.
ns.On("UNIT_LEVEL", function(_, unit)
    unit = ns.Plain(unit)
    if type(unit) ~= "string" then return end
    if not (unit:match("^party%d") or unit:match("^raid%d")) then return end

    local record = ns.Characters.ObserveUnit(unit)
    if record and ns.Roster.Has(record.guid) then
        ns.Sessions.Together(record.guid, "group")
    end
end)

-- The smoke tests cannot wait out the settle delay.
function ns._test.SettleGroup()
    settled = true
end
