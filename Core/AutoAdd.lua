-- Auto-add (the Recording setting "Auto-Add Players", `autoAdd`, off by default).
--
-- DIA-1 says a character enters the diary because the user said so. This is
-- the one exception, and the user says so once, by switching it on: from
-- then on two thresholds add people without asking (decided 15 Nov 2026):
--
--   grouped   in the user's group for GROUP_SECONDS without a break, counted
--             from their latest join. Anywhere but a battleground: a
--             battleground's raid is forty strangers.
--   seen      sighted on SEEN_TIMES occasions (rows of the sighting store,
--             one per zone-hour, the count "Seen N times" says) within the
--             buffer's window, not counting hostile ones: a returning face,
--             not an enemy passing through.
--
-- Nothing is backfilled without asking: a person is weighed only when
-- something new happens with them (a group tick, a new sighting row). When
-- the setting goes on, the people who already pass the seen rule are
-- offered once, on a paper sheet (AutoAdd.Waiting, AddWaiting; the sheet is
-- UI/Windows/AutoAdd.lua's), and added only if the player says so.
--
-- Someone the user takes out of the diary is never added back
-- (meta.declined, written by Diary.Remove). Nor is anyone on the game's
-- ignore list.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local AutoAdd = {}
ns.AutoAdd = AutoAdd

AutoAdd.GROUP_SECONDS = 5 * 60
AutoAdd.SEEN_TIMES = 3

local function On()
    return ns.db and ns.db.settings.autoAdd == true
end

AutoAdd.On = On

-- PRV-3: "Delete all data" forgets the list too. Forgetting one person keeps
-- their bare GUID here, though: "delete everything about them" is not "add
-- them back the next time they pass".
ns.RegisterStore("declined", function(guid)
    if guid == nil then wipe(ns.db.meta.declined) end
end)

function AutoAdd.Decline(guid)
    guid = ns.SafeGUID(guid)
    if guid then ns.db.meta.declined[guid] = true end
end

function AutoAdd.Declined(guid)
    guid = ns.SafeGUID(guid)
    return guid ~= nil and ns.db.meta.declined[guid] == true
end

local function Ignored(guid)
    local FriendList = C_FriendList
    if not (FriendList and FriendList.IsIgnoredByGuid) then return false end
    return ns.Plain(FriendList.IsIgnoredByGuid(guid)) == true
end

local function Eligible(guid)
    guid = ns.SafeGUID(guid)
    if not guid or guid == ns.ownGUID then return nil end
    if ns.Diary.IsDiary(guid) or AutoAdd.Declined(guid) or Ignored(guid) then return nil end
    return guid
end

-- The chat line is the setting's own, not Diary.Add's: it says why.
local REASONS = {
    auto_group = L["after 5 minutes grouped with you"],
    auto_seen = L["after they were seen near you 3 times"],
}

local function Add(guid, source)
    local entry, added = ns.Diary.Add(guid, { source = source, quiet = true })
    if not added then return nil end
    ns.Print(Fmt(L["added |cffffffff%1$s|r to the diary automatically %2$s."],
        ns.Characters.FullName(entry.guid) or entry.guid, REASONS[source]))
    return entry
end

--------------------------------------------------------------------------
-- Grouped
--------------------------------------------------------------------------

-- When their latest stretch in the group began: the newest group_join row,
-- if no group_leave came after it.
local function JoinedAt(guid)
    local rows = ns.Interactions.For(guid)
    if not rows then return nil end
    for i = #rows, 1, -1 do
        local kind = rows[i].type
        if kind == "group_leave" then return nil end
        if kind == "group_join" then return rows[i].time end
    end
    return nil
end

-- Every member of the group as last scanned. Run on the together tick
-- (Capture/Together.lua); returns how many it added.
function AutoAdd.CheckGroup(now)
    if not On() or ns.InBattleground() then return 0 end
    now = now or ns.Now()

    local n = 0
    for guid in pairs(ns.Roster.Members()) do
        guid = Eligible(guid)
        local joined = guid and JoinedAt(guid)
        if joined and now - joined >= AutoAdd.GROUP_SECONDS and Add(guid, "auto_group") then
            n = n + 1
        end
    end
    return n
end

--------------------------------------------------------------------------
-- Seen
--------------------------------------------------------------------------

local function TimesSeen(guid)
    local n = 0
    for _, row in ipairs(ns.Sightings.For(guid)) do
        if not row.hostile then n = n + 1 end
    end
    return n
end

-- After the sighting store wrote a new row for them (Capture/Sightings.lua).
function AutoAdd.Sighted(guid)
    if not On() then return nil end
    guid = Eligible(guid)
    if not guid or TimesSeen(guid) < AutoAdd.SEEN_TIMES then return nil end
    return Add(guid, "auto_seen")
end

--------------------------------------------------------------------------
-- Backfill, asked when the setting goes on
--------------------------------------------------------------------------

-- Everyone already seen often enough who would be added the next time they
-- pass: the GUIDs, by name so the sheet can say a few.
function AutoAdd.Waiting()
    local list = {}
    for guid in pairs(ns.db.sightings) do
        guid = Eligible(guid)
        if guid and TimesSeen(guid) >= AutoAdd.SEEN_TIMES then list[#list + 1] = guid end
    end
    table.sort(list, function(a, b)
        local x, y = ns.Characters.FullName(a) or a, ns.Characters.FullName(b) or b
        if x ~= y then return x < y end
        return a < b
    end)
    return list
end

-- Adds them all, quietly, with one line in chat for the lot. Still checks
-- each: the sheet may have been open while one of them was added or
-- removed. Returns how many were added.
function AutoAdd.AddWaiting(list)
    local n = 0
    for _, guid in ipairs(list or AutoAdd.Waiting()) do
        guid = Eligible(guid)
        if guid and TimesSeen(guid) >= AutoAdd.SEEN_TIMES then
            local _, added = ns.Diary.Add(guid, { source = "auto_seen", quiet = true })
            if added then n = n + 1 end
        end
    end
    if n > 0 then
        ns.Print(ns.Plural(n, L["added %d person you’ve seen near you before to the diary.|added %d people you’ve seen near you before to the diary.##plural"]))
    end
    return n
end
