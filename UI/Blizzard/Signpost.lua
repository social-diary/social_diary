-- Blizzard's AddOns settings: a signpost. A small page there that sends
-- you to the journal's settings (UI/Settings/Page.lua), since that is
-- where players look first. It only needs RegisterCanvasLayoutCategory
-- and RegisterAddOnCategory; the declarative Settings API has changed
-- signature between client versions and is unverified in this build.

local addonName, ns = ...

local L = ns.L

local category

local function CloseBlizzardSettings()
    if SettingsPanel and SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
    end
end

local function Register()
    if category then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    local sign = CreateFrame("Frame")
    local title = ns.UI.Chrome.Label(sign, "Social Diary", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local text = ns.UI.Chrome.Label(sign,
        L["The settings live in your journal now, behind the grey ribbon at the bottom of the book."], "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    text:SetPoint("RIGHT", sign, "RIGHT", -16, 0)

    sign.open = ns.UI.Chrome.Button(sign, L["Open the settings"], 170, function()
        CloseBlizzardSettings()
        ns.UI.ShowSettings()
    end)
    sign.open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)

    category = Settings.RegisterCanvasLayoutCategory(sign, "Social Diary")
    Settings.RegisterAddOnCategory(category)
end

ns.On("PLAYER_LOGIN", Register)
