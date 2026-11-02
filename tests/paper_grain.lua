-- "Paper Texture Intensity" (Settings > Interface): the setting's default,
-- the slider on the page (UI/Style/Widgets.lua, Style.Slider), and the
-- grain following it: from the saved value at load and on every paper that
-- carries the grain art.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Style = ns.Style

-- The alpha last given to `texture`, which the mock only records.
local function Alpha(texture) return texture.recorded.calls.SetAlpha[1] end

local function Near(a, b, what)
    Check(math.abs(a - b) < 0.0001, ("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)))
end

-- What the addon printed while fn ran.
local function Said(fn)
    local lines, was = {}, DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) lines[#lines + 1] = tostring(msg) end
    fn()
    DEFAULT_CHAT_FRAME.AddMessage = was
    return lines
end

--------------------------------------------------------------------------
Section("the setting")

Eq(ns.SettingDefault("paperGrain"), 100, "the default is not the designed strength")
Eq(ns.db.settings.paperGrain, 100, "a new character has no grain setting")
Eq(_G.SocialDiaryCharDB.settings.paperGrain, 100, "the setting is not the character's")
Check(not ns.IsAccountSetting("paperGrain"), "the setting is the account's")
Eq(Style.GrainStrength(), 1, "the default does not leave the grain as designed")

--------------------------------------------------------------------------
Section("on a scale")

Eq(Style.OnScale(100, 0, 200, 25), 100, "a step moved")
Eq(Style.OnScale(37, 0, 200, 25), 25, "37 is not nearest 25")
Eq(Style.OnScale(38, 0, 200, 25), 50, "38 is not nearest 50")
Eq(Style.OnScale(999, 0, 200, 25), 200, "not clamped from above")
Eq(Style.OnScale(-5, 0, 200, 25), 0, "not clamped from below")
Eq(Style.OnScale("oops", 0, 200, 25), 0, "not a number, not the scale's bottom")

--------------------------------------------------------------------------
Section("the slider on the page")

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local P = ns.UI.SettingsPage()
P.nav.interface:Click()
local row, slider = P.paperGrain, P.paperGrain.slider

Eq(row.label:GetText(), "Paper Texture Intensity", "the label")
Eq(row.hint, nil, "the slider has small print")
local function Y(widget) return widget.recorded.points[1].args[4] end
Check(Y(row) > Y(P.bookStack), "the slider is not above the first switch of Look and Feel")
Check(Y(row) < Y(P.minimapButton), "the slider is not under the Minimap section")

local lo, hi = slider:GetMinMaxValues()
Eq(lo .. "-" .. hi, "0-200", "the range")
Eq(slider.recorded.calls.SetValueStep[1], 25, "the step")
Eq(slider.recorded.calls.SetObeyStepOnDrag[1], true, "a drag does not obey the step")
Eq(slider:GetValue(), 100, "the slider does not show the saved value")
Eq(slider.reading:GetText(), "100%", "the reading")

-- A drag: the grain moves once per step, silently.
local fired = 0
ns.On("SD_PAPER_CHANGED", function() fired = fired + 1 end)
local said = Said(function()
    slider:SetValue(125)
    Eq(ns.db.settings.paperGrain, 125, "the step was not saved")
    Eq(Style.GrainStrength(), 1.25, "the grain did not follow")
    Eq(slider.reading:GetText(), "125%", "the reading did not follow")
    Eq(fired, 1, "one step did not repaint once")

    -- Between the steps it lands on the nearest, and on the same step
    -- nothing is written or repainted.
    slider:SetValue(130)
    Eq(slider:GetValue(), 125, "not snapped back to its step")
    Eq(fired, 1, "the same step repainted")

    slider:SetValue(140)
    Eq(slider:GetValue(), 150, "not snapped up to its step")
    Eq(ns.db.settings.paperGrain, 150, "the snapped value was not saved")
    Eq(fired, 2, "the next step did not repaint")

    slider:SetValue(999)
    Eq(ns.db.settings.paperGrain, 200, "not clamped to the top")
    slider:SetValue(0)
    Eq(ns.db.settings.paperGrain, 0, "not down to none")
    Eq(Style.GrainStrength(), 0, "none is not flat")
end)
Eq(#said, 0, "dragging the slider wrote in the chat: " .. tostring(said[1]))

-- A stored value off the scale shows on it, and showing it writes nothing.
ns.db.settings.paperGrain = 37
slider:Refresh()
Eq(slider:GetValue(), 25, "37 does not show as 25")
Eq(slider.reading:GetText(), "25%", "the reading of 37")
Eq(ns.db.settings.paperGrain, 37, "showing a value rewrote it")
ns.db.settings.paperGrain = 9999
slider:Refresh()
Eq(slider:GetValue(), 200, "9999 does not show as the top")
Eq(ns.db.settings.paperGrain, 9999, "showing a value rewrote it")

-- Unavailable, it fades, as the kit's other rows do.
row:SetAvailable(false)
Eq(slider.recorded.calls.SetAlpha[1], 0.45, "unavailable, it did not fade")
row:SetAvailable(true)
Eq(slider.recorded.calls.SetAlpha[1], 1, "available, it did not come back")

ns.db.settings.paperGrain = 100
slider:Refresh()
Style.SetGrain(100)
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("/sd art grain still says so")

local out = Said(function() SlashCmdList.SOCIALDIARY("art grain 150") end)
Eq(out[1] and out[1]:match("paper grain at 150%%") ~= nil, true, "the dev command did not report")
Eq(Style.GrainStrength(), 1.5, "the dev command did not set the grain")
Eq(ns.db.settings.paperGrain, 100, "the dev trial was saved")
Style.SetGrain(100)

--------------------------------------------------------------------------
Section("every paper follows it")

-- `shown()` returns the alpha on the paper: `designed` at 100, scaling with
-- the grain.
local function Follows(what, designed, shown)
    for _, percent in ipairs({ 100, 50, 200, 0 }) do
        Style.SetGrain(percent)
        Near(shown(), designed * percent / 100, what .. " at " .. percent)
    end
    Style.SetGrain(100)
end

-- A strip, at its next laying.
local host = CreateFrame("Frame")
local strip = ns.UI.PaperStrip(host)
strip:SetNote({ name = "Bram Redfen", what = "15 min together", seed = "Bram:1" })
Follows("a strip's grain", ns.UI.PAPER_STRIP.STRIP.grain, function()
    strip:Layout(20, 300, 160, 40)
    return Alpha(strip.grain)
end)

-- A loose sheet, each facet's, at its next laying.
local sheet, K = ns.UI.LooseSheet(UIParent, 600, 400)
local facets, make = {}, sheet.sheet.CreateTexture
sheet.sheet.CreateTexture = function(self, name, layer, ...)
    local texture = make(self, name, layer, ...)
    if layer == "BORDER" then facets[#facets + 1] = texture end
    return texture
end
K.Fall("grain", 0)
K.Lay()
Check(#facets > 0, "setup: the sheet has no grain")
Follows("a loose sheet's grain", 0.14, function()
    K.Lay()
    return Alpha(facets[1])
end)


--------------------------------------------------------------------------
Section("the saved grain at load")

mock.Reset()
local ns2 = T.Load()
mock.SetUnit("player", T.F.SELF)
_G.SocialDiaryCharDB = { schema = 2, settings = { paperGrain = 50 } }
local silent = Said(function() mock.fire("ADDON_LOADED", ns2.addonName) end)
Eq(#silent, 0, "loading the grain wrote in the chat")
Eq(ns2.Style.GrainStrength(), 0.5, "the saved grain was not applied at load")
ns2.db.settings.introSeen = true
mock.fire("PLAYER_LOGIN")
ns2.UI.ShowJournal()
local book = ns2.UI.JournalFrame().book
Near(Alpha(book.grain[#book.grain].texture), book.grain[#book.grain].alpha * 0.5,
    "the book was not built at the saved grain")
Eq(ns2.db.settings.paperGrain, 50, "the load rewrote the setting")
ns2.UI.CloseJournal()

-- Saved off the scale, by an older hand or a text editor: on it, and safe.
for saved, strength in pairs({ [9999] = 2, [37] = 0.25, oops = 0 }) do
    mock.Reset()
    local again = T.Load()
    mock.SetUnit("player", T.F.SELF)
    _G.SocialDiaryCharDB = { schema = 2, settings = { paperGrain = saved } }
    mock.fire("ADDON_LOADED", again.addonName)
    Eq(again.Style.GrainStrength(), strength, "saved as " .. tostring(saved))
end

-- Saved data from before the setting: as designed.
mock.Reset()
local ns3 = T.Load()
mock.SetUnit("player", T.F.SELF)
_G.SocialDiaryCharDB = { schema = 2, settings = { tooltips = false } }
mock.fire("ADDON_LOADED", ns3.addonName)
Eq(ns3.Style.GrainStrength(), 1, "an old character's grain is not as designed")
Eq(_G.SocialDiaryCharDB.settings.paperGrain, 100, "an old character got no default")
Eq(_G.SocialDiaryCharDB.settings.tooltips, false, "an old setting was overwritten")
