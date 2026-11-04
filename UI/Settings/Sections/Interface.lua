-- Settings: Interface (UI/Settings/Page.lua lists the sections; the
-- controls are UI/Settings/Kit.lua's): tooltips, the minimap button, how
-- the book looks, and the hints on the pages. Its
-- subpages are Toasts.lua, Shortcuts.lua and Dungeons.lua beside it.

local addonName, ns = ...

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

    c:Heading("Tooltips")
    page.tooltips = Switch(c, "Add diary lines to player tooltips", "tooltips")
    page.tooltipSeen = Switch(c, "For everyone else, how often you have seen them", "tooltipSeen", INDENT)
    DependsOn(page.tooltipSeen, "tooltips")

    c:Heading("Minimap")
    page.minimapButton = Switch(c, "Show a button on the minimap", "minimapButton", nil,
        function() ns.UI.MinimapButton.Refresh() end)

    c:Heading("Look and Feel")
    page.paperGrain = Kit.Slider(c, "Paper Texture Intensity", "paperGrain", GRAIN, Style.SetGrain)
    page.bookStack = Switch(c, "Simulate Page Turns", "bookStack", nil,
        function() ns.UI.Journal.TurnStack() end,
        "New Diary entries add pages, and the book turns to the new page.")
    page.flatSheets = Switch(c, "Flat paper only", "flatSheets", nil, nil,
        "No folds or bends on the sheets, and a person’s name sits straight on their page.")
    page.revealMap = Switch(c, "Use fully discovered map for map sheets", "revealMap", nil, nil,
        nil)

    -- HNT-10: the hints on the pages (Core/Hints.lua). About the person at
    -- the keyboard, not the character, so an account setting, and it says so.
    c:Heading("Hints")
    page.showHints = Switch(c, "Show hints about things you may have missed", "showHints", nil,
        function(on) if not on and ns.UI.HintSlip then ns.UI.HintSlip.Hide() end end,
        "Now and then a small note on the page points something out. Applies to every character.")
    page.hintsAgain = Style.Link(pane, FONT.body, function()
        ns.Hints.Reset()
        ns.Print("the hints come again, each the next time its page is open.")
    end)
    page.hintsAgain:SetText("Show hints again")
    c:Place(page.hintsAgain, 18, 0, 8)
end

SettingsUI.RegisterSection("interface", { order = 20, label = "Interface",
    about = "Tooltips, minimap, how the book looks, hints", build = BuildInterface })

-- The saved grain, as soon as the saved settings are there (Core/Events.lua
-- loads first, so its handler has run) and before anything is built with it.
ns.On("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName then return end
    Style.SetGrain(Style.OnScale(Kit.Saved().paperGrain, GRAIN.min, GRAIN.max, GRAIN.step))
end)
