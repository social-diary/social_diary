-- Settings: Integrations (UI/Settings/Page.lua lists the sections; the
-- controls are UI/Settings/Kit.lua's): the addons it reads from
-- (Core/Bridges), and those it will one day.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local DependsOn = Kit.DependsOn

-- An addon it will read from one day, not yet: never ticked, never looked
-- for, and always unavailable. Only the box and its label fade, as an
-- unavailable setting does; the small print stays at full hint ink, since
-- it is the part that says why.
local function Placeholder(c, heading, text, hint)
    local page = SettingsUI.page
    local title = c:Heading(heading)
    local box = c:Checkbox(text, function() return false end, nil, nil, hint)
    box.heading = title
    function box:SetAvailable(available)
        self.unavailable = not available
        local alpha = available and 1 or 0.45
        self.tick:SetAlpha(alpha)
        self.label:SetAlpha(alpha)
    end
    page.controls[#page.controls + 1] = box
    DependsOn(box, function() return false end)
    box:SetAvailable(false)
    return box
end

-- Addons it reads from (Core/Bridges), each a status the user cannot
-- change: ticked where it is there and answers.
local function BuildIntegrations(pane, c)
    local page = SettingsUI.page

    c:Heading("Questie")
    page.questie = c:Checkbox(L["Questie installed"],
        function() return ns.QuestieBridge.Status() == "on" end, nil, nil,
        L["Mobs get their real names and quest drops are checked against real drop rates. Social Diary only reads from it."])
    page.controls[#page.controls + 1] = page.questie

    page.questieOld = c:Hint(L["Found, but this version isn't supported."])
    function page.questieOld:Refresh()
        self:SetShown(ns.QuestieBridge.Status() == "old")
    end
    page.controls[#page.controls + 1] = page.questieOld

    page.deathlog = Placeholder(c, "Deathlog", L["Deathlog installed"],
        L["Adds permadeath notes in Hardcore. Not available until Hardcore is released."])
    page.trp3 = Placeholder(c, "Total RP 3", L["Total RP 3 installed"],
        L["Adds RP profile data to diary entries. Not available until it's ported to Forever."])
end

SettingsUI.RegisterSection("integrations", { order = 40, label = L["Integrations"],
    about = L["Other addons it can read"], build = BuildIntegrations })
