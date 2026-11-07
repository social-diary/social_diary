-- /sd pad: the controller's state, and the pad forced in hand or out of
-- it for this session (UI/Pad/Input.lua), to try the book's pad support
-- without the game's own say.
--
--   /sd pad              where it stands: Gamepad UI, pad, in hand, the top scope
--   /sd pad on | off     the pad in hand, or not, whatever is used
--   /sd pad auto         back to the input used last

local addonName, ns = ...

local Pad = ns.UI.Pad

local function YesNo(v) return v and "yes" or "no" end

ns.Slash.Register("pad", function(arg)
    arg = (arg or ""):lower()
    if arg == "on" or arg == "off" or arg == "auto" then
        Pad.Input.Force(arg ~= "auto" and arg or nil)
    end
    local top = Pad.Top()
    ns.Print("pad: Gamepad UI %s, a pad available %s, in hand %s%s; style %s; scope %s.",
        YesNo(Pad.Input.GamepadUI()), YesNo(Pad.Input.Available()), YesNo(Pad.Input.Active()),
        Pad.Input.Forced() and (" (forced " .. Pad.Input.Forced() .. ")") or "",
        Pad.Glyphs.Style(), top and top.key or "none")
end, "the controller's state: |cffffd100/sd pad [on | off | auto]|r", { dev = true })
