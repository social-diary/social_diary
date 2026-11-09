-- Settings: Interface (UI/Settings/Page.lua lists the sections; the
-- controls are UI/Settings/Kit.lua's): tooltips, the minimap button, how
-- the book looks, the hints on the pages and the one after a major update.
-- Its subpages are Toasts.lua, Shortcuts.lua and Dungeons.lua beside it,
-- always listed under it.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch, DependsOn = Kit.Switch, Kit.DependsOn
local INDENT = Kit.INDENT

-- The paper's grain, in percent of its designed strength.
local GRAIN = { min = 0, max = 200, step = 25, unit = "%", mark = 100 }

local function BuildInterface(pane, c)
    local page = SettingsUI.page

    c:Heading(L["Tooltips"])
    page.tooltips = Switch(c, L["Add diary lines to player tooltips"], "tooltips")
    page.tooltipSeen = Switch(c, L["For everyone else, how often you have seen them"], "tooltipSeen", INDENT)
    DependsOn(page.tooltipSeen, "tooltips")

    c:Heading(L["Minimap"])
    page.minimapButton = Switch(c, L["Show a button on the minimap"], "minimapButton", nil,
        function() ns.UI.MinimapButton.Refresh() end)

    c:Heading(L["Look and Feel"])
    page.paperGrain = Kit.Slider(c, L["Paper Texture Intensity"], "paperGrain", GRAIN, Style.SetGrain)
    page.bookStack = Switch(c, L["Simulate Page Turns"], "bookStack", nil,
        function() ns.UI.Journal.TurnStack() end,
        L["New Diary entries add pages, and the book turns to the new page."])
    page.flatSheets = Switch(c, L["Flat paper only"], "flatSheets", nil, nil,
        L["No folds or bends on the sheets, and a person’s name sits straight on their page."])
    page.revealMap = Switch(c, L["Use fully discovered map for map sheets"], "revealMap", nil, nil,
        nil)

    -- HNT-10: the hints on the pages (Core/Hints.lua). About the person at
    -- the keyboard, not the character, so an account setting, and it says so.
    c:Heading(L["Hints"])
    page.showHints = Switch(c, L["Show hints about things you may have missed"], "showHints", nil,
        function(on) if not on and ns.UI.HintSlip then ns.UI.HintSlip.Hide() end end,
        L["Now and then a small note on the page points something out. Applies to every character."])
    page.hintsAgain = Style.Link(pane, FONT.body, function()
        ns.Hints.Reset()
        ns.Print(L["the hints come again, each the next time its page is open."])
    end)
    page.hintsAgain:SetText(L["Show hints again"])
    c:Place(page.hintsAgain, 18, 0, 8)
    -- The notice after a major update (Core/Hints.lua, the major-update
    -- hint): its own switch, not under showHints, as it tells of the
    -- update rather than of something on a page. The account's too.
    page.showUpdateHint = Switch(c, L["Show a hint after a big update"], "showUpdateHint", nil, nil,
        L["When a new major version such as 3.0 is installed, the book points you to what changed. Applies to every character."])
end

SettingsUI.RegisterSection("interface", { order = 20, label = L["Interface"],
    about = L["Tooltips, minimap, how the book looks, hints"], build = BuildInterface })

-- The saved grain, as soon as the saved settings are there (Core/Events.lua
-- loads first, so its handler has run) and before anything is built with it.
ns.On("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName then return end
    Style.SetGrain(Style.OnScale(Kit.Saved().paperGrain, GRAIN.min, GRAIN.max, GRAIN.step))
end)
