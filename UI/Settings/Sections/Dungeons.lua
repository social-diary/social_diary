-- Settings: Dungeons and Raids, Interface's third subpage (UI/Settings/Page.lua
-- lists the sections; the controls are UI/Settings/Kit.lua's): how a run's
-- map is drawn on the table spread (UI/Dungeon/), and whether the diary
-- opens on it while inside (ns.UI.OpenJournal).

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch = Kit.Switch

-- A run out on the table is laid again with the setting as it is now.
local function Redraw()
    ns.UI.DungeonPage.Refresh()
end

local function BuildDungeons(pane, c)
    local page = SettingsUI.page

    c:Heading(L["Dungeon maps"])
    page.dungeonRoute = Switch(c, L["Show the usual way through on each map"], "dungeonRoute", nil, Redraw,
        L["The diary can't follow you inside, so it inks the usual way up to the furthest boss you killed and pencils the rest."])
    page.openOnRun = Switch(c, L["Open the diary on the map of the run you’re in"], "openOnRun", nil, nil,
        L["Only inside a dungeon or raid. Anywhere else, the diary opens where you left it."])
end

SettingsUI.RegisterSection("dungeons", { order = 26, label = L["Dungeons and Raids"], parent = "interface",
    about = L["How a run’s map is drawn, and when it opens"], build = BuildDungeons })
