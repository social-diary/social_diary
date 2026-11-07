-- The settings with the pad (UI/Settings/Pad.lua; .claude/controller-plan.md,
-- step 3): the sections down the left, the open one's settings found on its
-- pane, switches, scales and numbers, faded settings passed over, back and
-- out with B, the title after a ribbon turn, and the book stepping aside
-- for Blizzard's popup.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Pad = ns.UI.Pad
local J = ns.UI.Journal

ns.UI.ShowJournal()
ns.UI.SetJournalView("settings")
local book = ns.UI.JournalFrame()
local page = ns.UI.SettingsPage()

-- In the client a frame starts shown; here every widget starts hidden.
local function ShowAll(frame)
    frame:Show()
    for _, child in ipairs({ frame:GetChildren() }) do ShowAll(child) end
end
ShowAll(page)
page:Refresh()   -- (one pane shown again, the open section's)

mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(book)

local function Press(key)
    mock.PadPress(catcher, key, true)
    mock.PadPress(catcher, key, false)
end
local function At() return Pad.Top().focus:Current() end
local function Prompt()
    local first = Pad.Top().legend(Pad.Top())[1]
    return first and first[2]
end

local sections = {}
for _, s in ipairs(ns.UI.Settings.Sections()) do sections[#sections + 1] = s.key end

--------------------------------------------------------------------------
Section("the settings page has its own scope, on the sections")

page:ShowSection(sections[1])
Pad.Refresh()
Eq(Pad.Top().key, "settings", "the top scope")
Eq(At().key, "nav:" .. sections[1], "not on the open section's row")
Eq(Prompt(), "Go to the page", "a section row's prompt")

--------------------------------------------------------------------------
Section("landing on a section shows it")

Press("PADDDOWN")
Eq(At().key, "nav:" .. sections[2], "down: not the next section")
Eq(page:Section(), sections[2], "the section landed on not shown")
Press("PADDUP")
Eq(page:Section(), sections[1], "up: not shown")

--------------------------------------------------------------------------
Section("right goes into the settings, on the open section's first")

Press("PADDRIGHT")
Eq(At().group, "pane", "not in the settings")
Eq(At().key, sections[1] .. ":1", "not the open section's first setting")
Eq(At().frame, page.keepRoute, "the first setting of Recording")
Eq(At().kind, "switch", "its kind")

--------------------------------------------------------------------------
Section("A ticks a switch, and the prompt follows it")

local before = ns.Setting("keepRoute")
Eq(Prompt(), before and "Untick" or "Tick", "the prompt before")
Press("PAD1")
Eq(ns.Setting("keepRoute"), not before, "A did not switch it")
Eq(Prompt(), (not before) and "Untick" or "Tick", "the prompt after")
Press("PAD1")
Eq(ns.Setting("keepRoute"), before, "A again did not switch it back")

--------------------------------------------------------------------------
Section("a number counts with left and right; faded settings are passed over")

ns.SetSetting("storeChat", true)
ns.SetSetting("chatUnlimited", false)
page:Refresh()
Press("PADDDOWN")
Eq(At().frame, page.storeChat, "down: not the next switch")
Press("PADDDOWN")
Eq(At().frame, page.chatLines, "down: not the number")
Eq(At().kind, "number", "its kind")
local lines = ns.Setting("chatLines")
Press("PADDRIGHT")
Eq(ns.Setting("chatLines"), lines + 1, "right did not count up")
Eq(At().frame, page.chatLines, "right moved off the number")
Press("PADDLEFT")
Eq(ns.Setting("chatLines"), lines, "left did not count down")
Eq(Prompt(), "Less · more", "a number's prompt")

-- Chat off: the number and Unlimited fade, and down passes over them.
Press("PADDUP")
Press("PAD1")
Eq(ns.Setting("storeChat"), false, "chat not switched off")
Press("PADDDOWN")
Check(At().frame ~= page.chatLines and At().frame ~= page.chatUnlimited, "a faded setting landed on")
ns.SetSetting("storeChat", true)
page:Refresh()

--------------------------------------------------------------------------
Section("B comes back to the sections, then closes the book")

Press("PAD2")
Eq(At().group, "nav", "B did not come back to the sections")
Eq(At().key, "nav:" .. sections[1], "not back on the section it left")
Check(book:IsShown(), "B in the settings closed the book")
Press("PADDRIGHT")
Press("PADDLEFT")
Eq(At().group, "nav", "left did not come back to the sections")

--------------------------------------------------------------------------
Section("a scale steps with left and right")

page:ShowSection("interface")
Pad.Refresh()
Eq(At().key, "nav:interface", "not on Interface")
Press("PAD1")
Eq(At().group, "pane", "A did not go into the settings")
for _ = 1, 20 do
    if At().frame == page.paperGrain then break end
    Press("PADDDOWN")
end
Eq(At().frame, page.paperGrain, "the scale never landed on")
Eq(At().kind, "slider", "its kind")
local grain = ns.Setting("paperGrain")
local up = grain < 200 and 1 or -1
Press(up == 1 and "PADDRIGHT" or "PADDLEFT")
Eq(ns.Setting("paperGrain"), grain + 25 * up, "a step did not move the scale by its step")
Eq(At().frame, page.paperGrain, "a step moved off the scale")
Press(up == 1 and "PADDLEFT" or "PADDRIGHT")
Eq(ns.Setting("paperGrain"), grain, "the step back")

--------------------------------------------------------------------------
Section("links are found and followed with A")

local found = false
for _ = 1, 20 do
    Press("PADDDOWN")
    if At().kind == "link" then found = true break end
end
Check(found, "no link found on Interface")
Eq(Prompt(), "Choose", "a link's prompt")
local clicked = 0
local link = At().frame
local was = link:GetScript("OnClick")
link:SetScript("OnClick", function() clicked = clicked + 1 end)
Press("PAD1")
Eq(clicked, 1, "A did not follow the link")
link:SetScript("OnClick", was)

--------------------------------------------------------------------------
Section("every section's settings are reachable, none are read-only")

Press("PAD2")
for _, key in ipairs(sections) do
    page:ShowSection(key)
    Pad.Refresh()
    Eq(At().key, "nav:" .. key, "not on " .. key)
end
for _, item in ipairs(Pad.Top().focus.groups.pane.items) do
    Check(not item.frame.readOnly, "a read-only box among the settings: " .. item.key)
end

--------------------------------------------------------------------------
Section("after a ribbon turn the title holds the box until the first D-pad press")

page:ShowSection("memory")
ns.UI.SetJournalView("people")
Press("PADRSHOULDER")
Press("PADRSHOULDER")
local ribbons = J.Ribbons()
if J.view ~= "settings" then
    -- (wherever the settings are among the ribbons: round to them)
    for _ = 1, #ribbons do
        if J.view == "settings" then break end
        Press("PADRSHOULDER")
    end
end
Eq(J.view, "settings", "never turned to the settings")
Eq(At().key, "title", "the title does not hold the box")
Eq(Prompt(), "Go to the sections", "the title's prompt")
Press("PADDDOWN")
Eq(At().key, "nav:memory", "the first press not on the open section")

--------------------------------------------------------------------------
Section("Blizzard's popup: the book's pad steps aside while it is up")

local dialog = StaticPopupDialogs["SOCIAL_DIARY_CONFIRM"]
Check(type(dialog.OnShow) == "function" and type(dialog.OnHide) == "function", "the popup does not tell the pad")
local popup = {}
dialog.OnShow(popup)
Check(Pad.Top() == nil, "a scope has the pad with the popup up")
Check(not catcher:IsGamePadButtonEnabled(), "the catcher takes buttons from the popup")
dialog.OnHide(popup)
Eq(Pad.Top() and Pad.Top().key, "settings", "the pad not back after the popup")
Check(catcher:IsGamePadButtonEnabled(), "the catcher not back after the popup")
Check(type(StaticPopupDialogs["SOCIAL_DIARY_REMOVE"].OnShow) == "function", "Remove's popup does not tell the pad")

--------------------------------------------------------------------------
Section("B on the sections closes the book")

Press("PAD2")
Check(not book:IsShown(), "B on the sections did not close the book")
