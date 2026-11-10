-- When a reunion toast is due (REU-1, REU-5): the settings and the
-- per-person cooldown. UI/Windows/Reunion/ shows the toast; this file
-- decides whether there should be one, so the rule is testable without a
-- frame.
--
-- Both kinds share one per-person cooldown (settings.toastCooldownMinutes).
-- The PRD's "once per login" was replaced at the user's request: a friend
-- you keep running into over an evening is worth hearing about again, and a
-- group join right after a nearby toast would only say the same thing twice.
--
-- meta.greeted[guid] = when they last got a toast. Saved, so a /reload does
-- not reset it.

local addonName, ns = ...

local Reunions = {}
ns.Reunions = Reunions

local FOE_TAG = "foe"

-- In seconds. 0 is allowed (no cooldown); anything that is not a number of
-- minutes at all falls back to the default in DB.lua.
function Reunions.Cooldown()
    local minutes = ns.Setting("toastCooldownMinutes")
    if type(minutes) ~= "number" or minutes < 0 then
        minutes = ns.SettingDefault("toastCooldownMinutes")
    end
    return minutes * 60
end

function Reunions.CoolingDown(guid, now)
    local last = ns.db.meta.greeted[guid]
    return last ~= nil and (now or ns.Now()) - last < Reunions.Cooldown()
end

-- In the battleground match open now (Core/Matches.lua), the match and
-- which side `guid` is on there: "with", "against", or false when the
-- side went unread. Nil outside a match, or when they are not in it. By
-- GUID, else by name: enemies' GUIDs are secret while it runs.
function Reunions.InMatch(guid)
    local Matches = ns.Matches
    local m = Matches and Matches.Current()
    guid = ns.SafeGUID(guid)
    if not m or not guid then return nil end
    local name = ns.Characters.FullName(guid)
    for _, p in ipairs(Matches.Players(m)) do
        if p.guid == guid or (not p.guid and Matches.SameName(name, p.name)) then
            return m, Matches.Side(m, p) or false
        end
    end
    return nil
end

-- Whether a toast about `guid` is due now. `reason` is "group", "nearby"
-- or "match", "group" and "nearby" each with its own switch: either can be
-- on without the other. A nearby toast is never for someone already in the
-- group, who got theirs on joining, nor for someone marked quiet nearby
-- (Diary.IsQuietNearby).
-- In a battleground match (9 Nov 2026) the match's own toast tells of
-- everyone there, once a match (Capture/Matches.lua): the group and nearby
-- ones keep quiet, or a teammate would come twice, once as "joined your
-- group". The match's toast follows the group switch for someone on your
-- side (they joined your raid) and the nearby one, quiet list and all, for
-- someone against you (they came into view).
-- A foe skips the cooldown when settings.foeToastsUncooled says so: in
-- world PvP, the same foe back after two minutes is news.
-- Returns the safe GUID when it is.
function Reunions.Due(guid, reason, now)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end

    local against = false
    if reason == "match" then
        local _, side = Reunions.InMatch(guid)
        against = side == "against"
    elseif ns.Matches and ns.Matches.Current() then
        return nil
    end
    local nearby = reason == "nearby" or against
    if not ns.Setting(nearby and "nearbyToasts" or "toasts") then return nil end

    local uncooled = ns.Setting("foeToastsUncooled") and ns.Diary.HasTag(guid, FOE_TAG)
    if not uncooled and Reunions.CoolingDown(guid, now) then return nil end
    if reason == "nearby" and ns.Roster.Has(guid) then return nil end
    if nearby and ns.Diary.IsQuietNearby(guid) then return nil end
    return guid
end

-- A toast went out: the cooldown starts.
function Reunions.Greet(guid, now)
    ns.db.meta.greeted[guid] = now or ns.Now()
end

-- Expired stamps say nothing, so they are dropped at login rather than kept
-- for every diary entry ever toasted. Run from Core/Events.lua.
function Reunions.Prune(now)
    now = now or ns.Now()
    local greeted = ns.db.meta.greeted
    for guid in pairs(greeted) do
        if not Reunions.CoolingDown(guid, now) then greeted[guid] = nil end
    end
end

--------------------------------------------------------------------------
-- The foe alert
--------------------------------------------------------------------------
--
-- For world PvP: the raid warning sounds when someone tagged "foe" comes
-- into view, in combat too, since that is when it matters. Off unless
-- switched on (settings.foeAlert). Nothing to do with the toasts: quiet
-- nearby and the toast cooldown do not hold it back.
--
-- A nameplate comes and goes as a foe circles at its edge, so each foe is
-- heard at most once a minute. The stamps are kept in memory only: after a
-- /reload, hearing about a foe again is the right answer.

local FOE_SECONDS = 60
local alerted = {}

-- Whether the alert should sound for `guid` now. Stamps it when it should,
-- so the caller only has to play the sound. Never for someone in the group.
function Reunions.FoeAlert(guid, now)
    if not ns.Setting("foeAlert") then return false end

    guid = ns.SafeGUID(guid)
    if not guid or not ns.Diary.HasTag(guid, FOE_TAG) or ns.Roster.Has(guid) then
        return false
    end

    now = now or ns.Now()
    if alerted[guid] and now - alerted[guid] < FOE_SECONDS then return false end
    alerted[guid] = now
    return true
end

-- PRV-3: a forgotten person's stamp goes. The toasts still waiting are
-- UI/Windows/Reunion/Queue.lua's own store.
ns.RegisterStore("greeted", function(guid)
    local greeted = ns.db.meta.greeted
    if guid == nil then wipe(greeted) else greeted[guid] = nil end
end)

ns.RegisterStore("foeAlerts", function(guid)
    if guid == nil then wipe(alerted) else alerted[guid] = nil end
end)
