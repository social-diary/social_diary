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
-- In hand: the game says so (GAME_PAD_ACTIVE_CHANGED, IsUsingGamepad read
-- live), and so does a pad button held or the mouse moved by hand, looked
-- at five times a second. A click made by the pad (its cursor control, or
-- a pad button held) does not count as the mouse's.
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
local MOVED = 24         -- the mouse moved this far (UI units) between looks: it is in hand

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

local function SetInHand(on)
    inHand = on and true or false
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
        SetInHand(arg)
    elseif event == "GLOBAL_MOUSE_DOWN" then
        if inHand and not PadCursor() and not Input.KeyHeld() then SetInHand(false) end
    elseif event == "PLAYER_LOGIN" then
        lastUsing = UsingPad()
        SetInHand(lastUsing)
    else
        Changed()
    end
end)

-- A look five times a second (it does next to nothing): the game's own
-- IsUsingGamepad changed since the last look, a pad button held, or the
-- mouse moved by hand; and whatever changed without an event (the Gamepad
-- UI turned on in the options).
local wait, lastX, lastY = 0, nil, nil
watch:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = LOOK_EVERY
    if forced ~= nil or not Input.Available() then return Changed() end
    local using = UsingPad()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    if using ~= lastUsing then
        lastUsing = using
        SetInHand(using)
    elseif Input.KeyHeld() then
        if not inHand then SetInHand(true) end
    elseif inHand and lastX and not PadCursor()
        and math.abs(x - lastX) + math.abs(y - lastY) > MOVED * scale then
        SetInHand(false)
    else
        Changed()
    end
    lastX, lastY = x, y
end)
