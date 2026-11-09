-- Settings: Toasts, Interface's first subpage (UI/Settings/Page.lua lists
-- the sections; the controls are UI/Settings/Kit.lua's): when a toast
-- shows, where it lies, and the quiet-nearby list (UI/Settings/Quiet.lua).

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch, Number, DependsOn, Saved = Kit.Switch, Kit.Number, Kit.DependsOn, Kit.Saved
local INDENT = Kit.INDENT

-- Interface's first subpage: the toasts, moved out of Interface when it
-- grew too busy, the blacklist with them.
local function BuildToasts(pane, c)
    local page = SettingsUI.page

    -- Two switches, neither under the other: nearby toasts without the
    -- group ones is a fair thing to want. The cooldown is both kinds'.
    c:Heading(L["When they show"])
    page.toasts = Switch(c, L["Show a toast when someone from your diary joins your group"], "toasts")
    page.nearbyToasts = Switch(c, L["Show a toast when someone from your diary comes into view"],
        "nearbyToasts")
    page.toastCooldown = Number(c, L["At most one toast per person every"], L["min"],
        "toastCooldownMinutes", 1, 720)
    DependsOn(page.toastCooldown, function() return Saved().toasts or Saved().nearbyToasts end)
    page.foeToastsUncooled = Switch(c, L["Ignore toast cooldown for foes"], "foeToastsUncooled", INDENT,
        nil, L["For World PVP e.g."])
    DependsOn(page.foeToastsUncooled, function() return Saved().toasts or Saved().nearbyToasts end)

    -- The book closes so the card can be seen where it lies, and opens
    -- on this page again once it is placed (UI/Windows/Reunion/Placing.lua).
    local function Back() ns.UI.ShowSettings("toasts") end
    -- The player asked for it: with the pad in hand, the pad moves it
    -- (UI/Windows/Reunion/Pad.lua). Edit Mode's placing never says so.
    page.moveToast = Style.Link(pane, FONT.body, function()
        ns.UI.CloseJournal()
        if ns.UI.PlaceToast(Back) then ns.UI.Pad.Opened(ns.UI.Toast.toast) else Back() end
    end)
    page.moveToast:SetText(L["Move the toast"])
    c:Place(page.moveToast, 18)

    -- Last, so its list can take whatever room is left.
    c:Heading(L["Nearby Toast Blacklist"])
    c:Hint(L["Toasts can get annoying for people you play with all the time."])

    SettingsUI.Quiet.Build(pane, c)
end

SettingsUI.RegisterSection("toasts", { order = 22, label = L["Toasts"], parent = "interface",
    about = L["Who gets one, how often, and where"], build = BuildToasts })
