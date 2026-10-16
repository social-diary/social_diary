-- Settings: Dungeons and Raids, Interface's third subpage (UI/Settings/Page.lua
-- lists the sections; the controls are UI/Settings/Kit.lua's): how a run's
-- map is drawn on its dungeon page (UI/Dungeon/).

local addonName, ns = ...

local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch = Kit.Switch

-- An open dungeon page is drawn again with the setting as it is now, for
-- when the book turns back to it.
local function Redraw()
    local J = ns.UI.Journal
    if J.journal and J.visit then J.RefreshProfile() end
end

local function BuildDungeons(pane, c)
    local page = SettingsUI.page

    c:Heading("Dungeon maps")
    page.dungeonRoute = Switch(c, "Show the usual way through on each map", "dungeonRoute", nil, Redraw,
        "The diary can't follow you inside, so it inks the usual way up to the furthest boss you killed and pencils the rest.")
end

SettingsUI.RegisterSection("dungeons", { order = 26, label = "Dungeons and Raids", parent = "interface",
    about = "How a run's map is drawn", build = BuildDungeons })
