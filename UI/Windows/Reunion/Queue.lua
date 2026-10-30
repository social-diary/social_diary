-- The reunion toasts' queue (REU-1, REU-2, REU-5): one card shows at a
-- time, for TOAST_SECONDS, longer while the mouse is on it.
--
-- REU-2: nothing appears in combat. Toasts wait in a queue and the queue
-- moves on PLAYER_REGEN_ENABLED, and a card already up when a fight starts
-- goes back to the front of it, to come again after. One toast shows at a time; a raid full of
-- friends would otherwise bury the screen, so the queue is capped and the
-- overflow becomes one "and N more" toast at the end.
--
-- Here: showing a card and putting it away (Display, Dismiss, Hover), the
-- combat gate (InCombat, Pump), forgetting (PRV-3), and the entry point,
-- ns.UI.Reunion, with the SD_REUNION handler that calls it. The card is
-- UI/Windows/Reunion/Toast.lua, which lists the state shared on
-- ns.UI.Toast; its words Words.lua's; placing it Placing.lua's.

local addonName, ns = ...

local Toast = ns.UI.Toast

local TOAST_SECONDS = 7
-- While the mouse is on it the card stays; once it leaves a card that is
-- past its time, the card goes this much later.
local LINGER_SECONDS = 1.5
local MAX_QUEUE = 5

--------------------------------------------------------------------------
-- Showing
--------------------------------------------------------------------------

local Pump

local function Dismiss()
    Toast.showing, Toast.overdue = nil, false
    if Toast.toast then Toast.toast:Hide() end
    Pump()
end
Toast.Dismiss = Dismiss

local function Hover(over)
    Toast.hovered = over
    if over or not Toast.overdue then return end
    local shown = Toast.shown
    C_Timer.After(LINGER_SECONDS, function()
        if Toast.showing and Toast.shown == shown and not Toast.hovered then Dismiss() end
    end)
end
Toast.Hover = Hover

local function Display(snap)
    Toast.toast = Toast.toast or Toast.Build()
    local toast = Toast.toast
    Toast.showing, Toast.overdue = snap, false
    -- This showing's own number, for its timers: a card put back in the
    -- queue comes again as the same snapshot, and a timer left from its
    -- first showing must not take it for its own and put it away early.
    Toast.shown = (Toast.shown or 0) + 1
    local shown = Toast.shown

    toast:Show()
    toast:Raise()
    toast:Fill(snap)
    toast.view:Show()

    C_Timer.After(TOAST_SECONDS, function()
        if not Toast.showing or Toast.shown ~= shown then return end
        if Toast.hovered then Toast.overdue = true else Dismiss() end
    end)
end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and ns.Plain(UnitAffectingCombat("player")))
end
Toast.InCombat = InCombat

Pump = function()
    if Toast.showing or Toast.placing or InCombat() then return end

    local snap = table.remove(Toast.queue, 1)
    if not snap and Toast.more > 0 then
        snap = { more = Toast.more, reason = Toast.moreReason }
        Toast.more, Toast.moreReason = 0, nil
    end
    if snap then Display(snap) end
end
Toast.Pump = Pump

ns.On("PLAYER_REGEN_ENABLED", function() Pump() end)

-- REU-2 holds for the card already up too, mouse on it or not: it goes, and
-- comes again first in line. It may take the queue one past MAX_QUEUE, which
-- only caps who joins: nobody is lost to a fight. An "and N more" card goes
-- back into the count, to stay last.
ns.On("PLAYER_REGEN_DISABLED", function()
    local snap = Toast.showing
    if not snap then return end
    Toast.showing, Toast.overdue, Toast.hovered = nil, false, false
    Toast.toast:Hide()
    if snap.more then
        Toast.more = Toast.more + snap.more
        Toast.moreReason = (Toast.moreReason == nil or Toast.moreReason == snap.reason) and snap.reason or "mixed"
    else
        table.insert(Toast.queue, 1, snap)
    end
end)

--------------------------------------------------------------------------
-- Forgetting
--------------------------------------------------------------------------

-- PRV-3: a toast still waiting to show a forgotten person goes, and so does
-- one showing them now. Their cooldown stamp is Core/Reunions.lua's store.
ns.RegisterStore("toasts", function(guid)
    if guid == nil then Toast.more, Toast.moreReason = 0, nil end

    local queue = Toast.queue
    for i = #queue, 1, -1 do
        if guid == nil or queue[i].guid == guid then table.remove(queue, i) end
    end
    local showing = Toast.showing
    if showing and (guid == nil or showing.guid == guid) then Dismiss() end
end)

--------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------

-- REU-1 and REU-5. `reason` is "group" (the default) or "nearby".
function ns.UI.Reunion(guid, reason)
    reason = reason or "group"
    local now = ns.Now()
    guid = ns.Reunions.Due(guid, reason, now)
    if not guid then return end

    -- Without a cooldown (a foe, settings.foeToastsUncooled) a nameplate
    -- at the edge of range comes and goes: one toast per person in line.
    local showing, queue = Toast.showing, Toast.queue
    if showing and showing.guid == guid then return end
    for i = 1, #queue do
        if queue[i].guid == guid then return end
    end

    local snap = Toast.Snapshot(guid, reason)
    if not snap then return end
    ns.Reunions.Greet(guid, now)

    if #queue >= MAX_QUEUE then
        Toast.more = Toast.more + 1
        Toast.moreReason = (Toast.moreReason == nil or Toast.moreReason == reason) and reason or "mixed"
    else
        queue[#queue + 1] = snap
    end
    Pump()
end

-- The foe alert's sound, for the Sounds settings to play as a sample too.
function Toast.PlayFoeAlert()
    ns.Style.PlaySound("foeAlert", "Master")
end

-- Capture says who; this file decides whether that is worth a toast, and
-- Core/Reunions.lua whether it is a foe worth a warning.
ns.On("SD_REUNION", function(_, guid, reason)
    if reason == "nearby" and ns.Reunions.FoeAlert(guid) then Toast.PlayFoeAlert() end
    ns.UI.Reunion(guid, reason)
end)

-- For the smoke test.
function ns.UI.ReunionShowing()
    return Toast.showing
end
