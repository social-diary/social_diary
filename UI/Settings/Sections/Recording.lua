-- Settings: Recording, the first section (UI/Settings/Page.lua lists them;
-- its controls are UI/Settings/Kit.lua's): your own route, chat and
-- sightings.

local addonName, ns = ...

local Style = ns.Style
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch, Number, DependsOn, Saved = Kit.Switch, Kit.Number, Kit.DependsOn, Kit.Saved
local INDENT = Kit.INDENT

local MAX_CHAT_LINES = 5000  -- above it, "No maximum" says it better

local function BuildRecording(pane, c)
    local page = SettingsUI.page

    -- JRN-17, through the same call as the front matter's links, so the
    -- timer starts and stops at once.
    c:Heading("Your Diary")
    page.keepRoute = Switch(c, "Keep my own route", "keepRoute", nil,
        function(on) ns.JourneyCapture.SetEnabled(on) end,
        "Data needed for the 'Your Diary' Page: Where you go and what you do.")

    c:Heading("Chat")
    -- INT-4 asks for the hint to be said in the settings.
    page.storeChat = Switch(c, "Keep whisper, /say and party text", "storeChat", nil, nil,
        "some text in dungeons cannot be accessed, fyi.")

    -- A lower limit applies now, to everyone's chat.
    page.chatLines = Number(c, "Maximum chat lines kept per person", "lines", "chatLines",
        1, MAX_CHAT_LINES, function() ns.Interactions.TrimChat() end)
    DependsOn(page.chatLines, function() return Saved().storeChat and not Saved().chatUnlimited end)
    page.chatUnlimited = Switch(c, "Unlimited", "chatUnlimited", INDENT,
        function(on) if not on then ns.Interactions.TrimChat() end end)
    DependsOn(page.chatUnlimited, "storeChat")
    c:Hint("Lines can still be lost if they exceed file size limits.")

    -- SIG-1 and SIG-5, through the same calls as /sd sightings on|off and
    -- /sd sightings city, so they take effect at once.
    c:Heading("Sightings")
    local Capture = ns.SightingCapture
    page.detectSightings = Switch(c, "Notice who passes you in the open world", "detectSightings", nil,
        function(on) Capture.SetEnabled(on) end,
        "Only works if nameplates are on. Doesn't work in dungeons, raids or battlegrounds.")

    -- The cities on SIG-5's list, two to a line. Saved, a city on means it
    -- pauses there; ticked here means it notices people there, so that a
    -- tick never stands for something that is not being recorded. The list
    -- is the one saved when the page was built; a city added by command
    -- shows after a reload.
    c:Hint("Enable sightings in cities - performance warning:", INDENT)
    local cities = Capture.Cities()
    for _, city in ipairs(cities) do
        city.name = type(city.key) == "number" and (ns.MapName(city.key) or ("map " .. city.key)) or city.key
    end
    table.sort(cities, function(a, b) return a.name < b.name end)

    local half = (c.width - INDENT) / 2
    local left
    page.cities = {}
    for i, city in ipairs(cities) do
        local box = Style.Checkbox(c.parent, half - 8, city.name,
            function() return Saved().cities[city.key] ~= true end,
            function(on) Capture.SetCity(city.key, not on) end)
        if i % 2 == 1 then
            left = c:Place(box, box.height, INDENT, 4)
        else
            box:SetPoint("TOPLEFT", left, "TOPLEFT", half, 0)
        end
        DependsOn(box, "detectSightings")
        page.controls[#page.controls + 1] = box
        page.cities[city.key] = box
    end
end

SettingsUI.RegisterSection("recording", { order = 10, label = "Recording",
    about = "Your route, chat, sightings", build = BuildRecording })
