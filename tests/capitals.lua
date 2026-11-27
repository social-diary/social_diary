local T = ...
local mock, Section, Eq = T.mock, T.Section, T.Eq

local asciiUpper = string.upper
local function Latin1Upper(s)
    return (asciiUpper(s):gsub("[\224-\246\248-\254]", function(c) return string.char(c:byte() - 32) end))
end

Section("capitals on a Chinese client")

local clientLocale = _G.GetLocale
_G.GetLocale = function() return "zhCN" end
string.upper = Latin1Upper
local ns = T.Boot()

local day = os.date("*t", mock.now)
local t = os.time({ year = day.year, month = day.month, day = day.day, hour = 14, min = 19 })
Eq(ns.UI.JourneyText.When(t, nil, t + 60), "今天14:19", "today")
Eq(ns.UI.JourneyText.When(t - T.DAY, nil, t + 60), "昨天14:19", "yesterday")

mock.missingFiles["Interface\\LFGFrame\\LFGIcon-"] = true
local medallion = ns.Style.Medallion(UIParent, 36)
medallion:SetVisit({ instanceID = 99999, name = "怒焰裂谷" })
Eq(medallion.initial:GetText(), "怒", "the drop cap")

string.upper = asciiUpper
_G.GetLocale = clientLocale
