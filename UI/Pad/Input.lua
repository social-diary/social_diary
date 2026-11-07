-- The controller (.claude/controller-plan.md): which hand is on the
-- diary, the pad's or the mouse's.
--
-- The diary takes the pad only with WoW Forever's Gamepad UI on (Settings >
-- Gamepad), a pad enabled and plugged in, and the pad the input used last.
-- Any other time nothing here does anything: no frame takes a pad button,
-- and the book looks and works exactly as it does with the mouse.
--
--   Pad.Input.Available()  the Gamepad UI on, a pad enabled and plugged in
--   Pad.Input.Active()     Available, and the pad in hand (used last)
--   Pad.Input.OnChange(fn) fn(active) each time Active changes
--   Pad.Input.Force(mode)  "on", "off" or nil (auto): for Dev's /sd pad
--
-- In hand: a pad button pressed (looked at every frame), a stick pushed or
-- a trigger pulled (the device's own state, ten times a second while the
-- mouse has it), the game saying
-- so (GAME_PAD_ACTIVE_CHANGED, IsUsingGamepad turning true). Put down: a
-- mouse click the pad did not make (its cursor control, or a pad button
-- held), or the game saying so. Never by time or the cursor's place: the
-- Gamepad UI moves the cursor itself (found in the client, 7 Nov 2026).
--
-- The first file of UI/Pad/, so it makes ns.UI.Pad.

local addonName, ns = ...

local Pad = {}
ns.UI.Pad = Pad

local Input = {}
Pad.Input = Input

-- Every pad button a press can come from, for "is one held".
Pad.KEYS = {
    "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
    "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
    "PADLSTICK", "PADRSTICK", "PADFORWARD", "PADBACK", "PADSOCIAL",
    "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
}

local LOOK_EVERY = 0.2   -- seconds between looks

local function CVar(name)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    return get and get(name) or nil
end
Pad.CVar = CVar

-- Forever's Gamepad UI. Blizzard's own helper first, then the interface
-- style, then its CVar. Off where none of them is there (another client).
function Input.GamepadUI()
    local util = _G.InputUtil
    if util and type(util.IsGamepadUIEnabled) == "function" then
        local ok, on = pcall(util.IsGamepadUIEnabled)
        if ok then return on and true or false end
    end
    local style = _G.C_InputInterfaceStyle
    local enum = Enum and Enum.InputDeviceInterfaceType
    if style and style.GetCurrentStyle and enum and enum.Gamepad then
        local ok, current = pcall(style.GetCurrentStyle)
        if ok then return current == enum.Gamepad end
    end
    return CVar("InputDeviceInterfaceStyle") == "1"
end

local function Enabled()
    if C_GamePad and C_GamePad.IsEnabled then return C_GamePad.IsEnabled() and true or false end
    return CVar("GamePadEnable") == "1"
end

local function Connected()
    if not (C_GamePad and C_GamePad.GetAllDeviceIDs) then return false end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    return ok and type(ids) == "table" and #ids > 0
end

function Input.Available()
    return Input.GamepadUI() and Enabled() and Connected()
end

-- A pad button held right now.
function Input.KeyHeld()
    if not IsKeyDown then return false end
    for _, key in ipairs(Pad.KEYS) do
        if IsKeyDown(key) then return true end
    end
    return false
end

-- The cursor moved by the pad (the game's cursor control), not the mouse.
local function PadCursor()
    return type(IsGamePadCursorControlEnabled) == "function" and IsGamePadCursorControlEnabled() and true or false
end

local inHand        -- the pad used last; nil until first asked
local forced        -- "on", "off" or nil
local listeners = {}

local function UsingPad()
    return type(IsUsingGamepad) == "function" and IsUsingGamepad() and true or false
end

-- The game's own word on the pad in hand, read live: our own tracking
-- (a pad button seen, the mouse moved by hand) only stands in between.
local function InHand()
    if inHand == nil then inHand = UsingPad() end
    return inHand
end

function Input.Active()
    if forced == "on" then return true end
    if forced == "off" then return false end
    return Input.Available() and InHand()
end

function Input.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local was = nil
local watch = CreateFrame("Frame")

-- After anything that may have changed Active: tell the listeners when it
-- did. Cheap, so the look below calls it every time too: Forever does not
-- always say when the Gamepad UI or the pad is turned on.
local function Changed()
    local now = Input.Active()
    if now == was then return end
    was = now
    for _, fn in ipairs(listeners) do fn(now) end
end
Input.Changed = Changed

-- Why the pad was last picked up or put down, for /sd pad.
Input.reason = "not yet"

local function SetInHand(on, why)
    on = on and true or false
    if on ~= inHand then Input.reason = (on and "picked up: " or "put down: ") .. (why or "?") end
    inHand = on
    Changed()
end

function Input.Force(mode)
    forced = (mode == "on" or mode == "off") and mode or nil
    Changed()
end

function Input.Forced() return forced end

-- Events the client may not have are asked for one by one: a client
-- without one keeps the rest.
for _, event in ipairs({ "PLAYER_LOGIN", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED",
    "GAME_PAD_CONFIGS_CHANGED", "INPUT_DEVICE_INTERFACE_TRANSITION", "CVAR_UPDATE", "GLOBAL_MOUSE_DOWN" }) do
    pcall(watch.RegisterEvent, watch, event)
end
local lastUsing   -- IsUsingGamepad as last read
watch:SetScript("OnEvent", function(_, event, arg)
    if event == "GAME_PAD_ACTIVE_CHANGED" then
        SetInHand(arg, "the game said so")
    elseif event == "GLOBAL_MOUSE_DOWN" then
        if inHand and not PadCursor() and not Input.KeyHeld() then SetInHand(false, "a mouse click") end
    elseif event == "PLAYER_LOGIN" then
        lastUsing = UsingPad()
        SetInHand(lastUsing, "logged in")
    else
        Changed()
    end
end)

-- Every frame, a pad button held picks the pad up: a tap lasts a few
-- frames, so none is missed (the book's catcher is off while the mouse is
-- in hand, so it never hears them). Five times a second, the game's own
-- IsUsingGamepad turning true picks it up too, and whatever changed without
-- an event (the Gamepad UI turned on in the options) is looked at.
--
-- Only the mouse used (a click the pad did not make) or the game saying so
-- puts the pad down: never time, never the cursor's place (the Gamepad UI
-- hides and centres the cursor itself, at rest too), never IsUsingGamepad
-- turning false.
-- The pad's own state, read straight from the device: a stick pushed or
-- a trigger pulled (a stick is no button, so KeyHeld never sees it), or
-- any button. Asked only while the mouse has the pad down: after a click
-- the game may go on thinking the pad is in use, so neither its event nor
-- IsUsingGamepad changes when a stick moves (found in the client, 7 Nov
-- 2026: the sticks woke the pad only once the game had given up on it).
local STICK_ON, TRIGGER_ON, PEEK_EVERY = 0.35, 0.5, 0.1
local function Moved()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    if not (ok and type(state) == "table") then return nil end
    for _, stick in ipairs(state.sticks or {}) do
        if (tonumber(stick.len) or 0) > STICK_ON then return "a stick" end
    end
    for _, value in ipairs(state.axes or {}) do
        if (tonumber(value) or 0) > TRIGGER_ON then return "a trigger" end
    end
    for _, down in ipairs(state.buttons or {}) do
        if down then return "a pad button" end
    end
end
Input.Moved = Moved

-- The watcher only runs while a window of ours is open (Input.Watch, from
-- UI/Pad/Catcher.lua): with none open it sleeps, hidden, and only the
-- game's events above reach it (a hidden frame still hears its events).
-- Awake, the costly answers are cached: whether a pad is available is asked
-- five times a second, not every frame. Every frame there is only the
-- buttons' check, and only while the mouse has the pad down; the device's
-- state (Moved) ten times a second, likewise. With the pad in hand, a frame
-- costs two subtractions.
local available = false
local wait, peek = 0, 0
watch:SetScript("OnUpdate", function(_, elapsed)
    if available and not inHand then
        if Input.KeyHeld() then
            SetInHand(true, "a pad button")
        else
            peek = peek - elapsed
            if peek <= 0 then
                peek = PEEK_EVERY
                local what = Moved()
                if what then SetInHand(true, what) end
            end
        end
    end
    wait = wait - elapsed
    if wait > 0 then return end
    wait = LOOK_EVERY
    available = forced == nil and Input.Available()
    if not available then return Changed() end
    local using = UsingPad()
    if using ~= lastUsing then
        lastUsing = using
        if using then return SetInHand(true, "IsUsingGamepad") end
    end
    Changed()
end)
watch:Hide()

-- Awake while a window of ours is open, asleep otherwise.
function Input.Watch(on)
    on = on and true or false
    if on == watch:IsShown() then return end
    if on then
        available = forced == nil and Input.Available()
        wait, peek = 0, 0
    end
    watch:SetShown(on)
end

function Input.Watching() return watch:IsShown() end
