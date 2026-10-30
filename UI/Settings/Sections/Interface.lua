-- Settings: Interface (UI/Settings/Page.lua lists the sections; the
-- controls are UI/Settings/Kit.lua's): tooltips, the minimap button, and how
-- the book looks. Its
-- subpages are Toasts.lua, Shortcuts.lua and Dungeons.lua beside it.

local addonName, ns = ...

local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch, DependsOn = Kit.Switch, Kit.DependsOn
local INDENT = Kit.INDENT

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
    page.bookStack = Switch(c, "Simulate Page Turns", "bookStack", nil,
        function() ns.UI.Journal.TurnStack() end,
        "New Diary entries add pages, and the book turns to the new page.")
    page.flatSheets = Switch(c, "Flat paper only", "flatSheets", nil, nil,
        "Disable folded & bent look of Heatmap & other sheets")
    page.revealMap = Switch(c, "Use fully discovered map for map sheets", "revealMap", nil, nil,
        nil)
end

SettingsUI.RegisterSection("interface", { order = 20, label = "Interface",
    about = "Tooltips, minimap, how the book looks", build = BuildInterface })
