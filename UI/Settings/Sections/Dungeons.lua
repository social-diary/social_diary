-- Settings: Dungeons and Raids, Interface's third subpage (UI/Settings/Page.lua
-- lists the sections; the controls are UI/Settings/Kit.lua's): how a run's
-- map is drawn on the table spread (UI/Dungeon/).

local addonName, ns = ...

local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch = Kit.Switch

-- A run out on the table is laid again with the setting as it is now.
local function Redraw()
    ns.UI.DungeonPage.Refresh()
end

local function BuildDungeons(pane, c)
    local page = SettingsUI.page

    c:Heading("Dungeon maps")
    page.dungeonRoute = Switch(c, "Show the usual way through on each map", "dungeonRoute", nil, Redraw,
        "The diary can't follow you inside, so it inks the usual way up to the furthest boss you killed and pencils the rest.")
end

SettingsUI.RegisterSection("dungeons", { order = 26, label = "Dungeons and Raids", parent = "interface",
    about = "How a run's map is drawn", build = BuildDungeons })
