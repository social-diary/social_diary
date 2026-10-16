-- The group as last seen (INT-1 "grouping", SES-1, SES-3).
--
-- Capture/Group.lua reads the unit tokens and hands over who is in the group
-- now; this file diffs that against the group as last seen: new members get
-- a group_join row, departed ones a group_leave row, and every diary entry
-- in the group is handed to Sessions as present (SES-1).
--
-- The last-seen roster is persisted (meta.roster) because a /reload rebuilds
-- the unit tokens from nothing. Diffing against an empty table would log the
-- whole group as joining again after every reload, and SES-3 says a reload
-- must not duplicate anything.

local addonName, ns = ...

local Roster = {}
ns.Roster = Roster

local function Stored()
    return ns.db.meta.roster
end

-- PRV-3: the persisted roster names its members by GUID.
ns.RegisterStore("roster", function(guid)
    local members = Stored().members
    if guid == nil then wipe(members) else members[guid] = nil end
end)

-- The persisted set is the one home for "is this GUID in my group".
function Roster.Has(guid)
    guid = ns.SafeGUID(guid)
    return guid ~= nil and Stored().members[guid] == true
end

function Roster.Members()
    return Stored().members
end

-- Keeps the roster's timestamp current, so the next login can tell a reload
-- from a logout. Called on every scan and every session tick.
function Roster.Touch(now)
    local roster = Stored()
    roster.time = now or ns.Now()
    roster.me = ns.ownGUID
end

-- A stale roster -- another character, or older than the session gap -- says
-- nothing about the group now. It is dropped without leave rows: they left
-- at some point while nobody was watching, and a guessed time is worse than
-- none.
function Roster.ForgetStale(now)
    local roster = Stored()
    now = now or ns.Now()
    if roster.me ~= ns.ownGUID or not roster.time or now - roster.time > ns.Sessions.Gap() then
        roster.members = {}
        roster.me = ns.ownGUID
        roster.time = now
    end
end

-- One scan's result. `current` is { [guid] = { guild = true|nil } } for every
-- member whose GUID could be read, already observed (Characters.ObserveUnit);
-- `complete` says every member could be, so anyone missing really left;
-- `raid` marks the join rows of a raid.
--
-- An incomplete scan records joins and no leaves: a member whose GUID reads
-- as secret (instanced maps, the feasibility report's B1) is not the same as
-- a member who left.
function Roster.Update(current, complete, raid)
    local roster = Stored()

    local joined = {}
    for guid in pairs(current) do
        if not roster.members[guid] then
            joined[#joined + 1] = guid
            roster.members[guid] = true
        end
    end

    -- REU-1, before Sessions sees the join: the toast's "last met" has to be
    -- the previous meeting, not the one this join is about to start. ns.Fire
    -- is synchronous, so the toast has read it by the time Sessions runs.
    for i = 1, #joined do
        if ns.Diary.IsDiary(joined[i]) then ns.Fire("SD_REUNION", joined[i], "group") end
    end

    -- Sessions next, so the join rows below are stamped with the session
    -- they opened (SES-5).
    local set = {}
    for guid in pairs(current) do set[guid] = true end
    ns.Sessions.Roster(set)
    -- The open dungeon run's members, with when they joined and left (INS-12).
    ns.Instances.Roster(set, complete)

    for i = 1, #joined do
        local guid = joined[i]
        local record = ns.Characters.Get(guid)
        local guild = current[guid].guild
        ns.Interactions.Add(guid, "group_join", {
            theirLevel = record and record.level,
            context = (raid or guild) and { raid = raid, guild = guild } or nil,
        })
    end

    if complete then
        for guid in pairs(roster.members) do
            if not current[guid] then
                roster.members[guid] = nil
                ns.Interactions.Add(guid, "group_leave", {})
            end
        end
    end

    Roster.Touch()
    return joined
end
