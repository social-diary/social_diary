-- Placing the reunion toast: ns.UI.PlaceToast, ns.UI.Toast.StopPlacing and
-- ns.UI.PlacingToast. The card is UI/Windows/Reunion/Toast.lua (which
-- keeps where it was dragged to, and lists the state shared on
-- ns.UI.Toast); the queue that waits meanwhile is Queue.lua's.

local addonName, ns = ...

local Toast = ns.UI.Toast

--------------------------------------------------------------------------
-- Placing the card
--------------------------------------------------------------------------
--
-- A sample card laid where toasts appear, to be dragged somewhere else:
-- from Settings (Move the toast) and whenever Blizzard's Edit Mode is open,
-- so it can be placed along with the rest of the screen. Edit Mode is only
-- listened to (EventRegistry's EditMode.Enter and EditMode.Exit), never
-- hooked, for REU-3's reason. A toast due meanwhile waits, the one showing
-- included; Done, Escape, Edit Mode closing or a fight starting ends it.

local SPECIAL = "SocialDiaryToastFrame"

local function Escapable(on)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == SPECIAL then table.remove(UISpecialFrames, i) end
    end
    -- Only while placing: a toast during play must not eat an Escape.
    if on then UISpecialFrames[#UISpecialFrames + 1] = SPECIAL end
end

-- `onDone` runs once it is placed: Settings opens the book again. A fight
-- ending it holds `onDone` until the fight is over (below).
function ns.UI.PlaceToast(onDone)
    if Toast.InCombat() then
        ns.Print("the toast can be moved once the fight is over.")
        return false
    end
    Toast.toast = Toast.toast or Toast.Build()
    local toast, placing = Toast.toast, Toast.placing
    if placing then
        placing.onDone = onDone or placing.onDone
        return true
    end

    -- Placing again: a book still waiting from the last time stays shut.
    Toast.heldDone = nil

    -- The toast showing comes back after, first in line.
    if Toast.showing then
        table.insert(Toast.queue, 1, Toast.showing)
        Toast.showing = nil
    end
    Toast.placing, Toast.overdue = { onDone = onDone }, false
    Escapable(true)
    toast:Show()
    toast:Raise()
    toast:Fill({ place = true })
    toast.view:Show()
    return true
end

function Toast.StopPlacing()
    if not Toast.placing then return end
    local onDone = Toast.placing.onDone
    Toast.placing = nil
    Escapable(false)
    Toast.toast:StopMovingOrSizing()
    Toast.toast:Hide()
    if onDone then onDone() end
    Toast.Pump()
end

function ns.UI.PlacingToast()
    return Toast.placing ~= nil
end

-- A fight ends it, but must not open the book in the middle of a pull: what
-- was to run after waits for the fight's end, once. Every other way of
-- stopping runs it at once.
ns.On("PLAYER_REGEN_DISABLED", function()
    local placing = Toast.placing
    if not placing then return end
    Toast.heldDone, placing.onDone = placing.onDone, nil
    Toast.StopPlacing()
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    local onDone = Toast.heldDone
    Toast.heldDone = nil
    if onDone then onDone() end
end)

if EventRegistry and EventRegistry.RegisterCallback then
    local owner = {}
    EventRegistry:RegisterCallback("EditMode.Enter", function() ns.UI.PlaceToast() end, owner)
    EventRegistry:RegisterCallback("EditMode.Exit", function() Toast.StopPlacing() end, owner)
end
