-- The button on the minimap's edge (UI/Blizzard/Minimap.lua): where an angle
-- puts it, dragging it, the setting that hides it, and what its clicks do.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local M = ns.UI.MinimapButton
local REACH = 75  -- the mock minimap's half width, and 5 outside its edge

local function Near(a, b, what)
    Check(math.abs(a - b) < 0.001, ("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)))
end

-- Where the button is anchored, as the client keeps it.
local function Anchor(button)
    local points = button.recorded.points
    Eq(#points, 1, "the button has more or less than one anchor")
    local a = points[1]
    Eq(a.point, "CENTER", "the button's point")
    Eq(a.args[1], _G.Minimap, "the button is not anchored to the minimap")
    Eq(a.args[2], "CENTER", "the point on the minimap")
    return a.args[3], a.args[4]
end

--------------------------------------------------------------------------
Section("the button at login")

local button = _G.SocialDiaryMinimapButton
Check(button, "no button under its global name")
Eq(button.parent, _G.Minimap, "the button is not the minimap's child")
Check(button:IsShown(), "the button is not on by default")
Eq(ns.Setting("minimapButton"), true, "the setting is not on by default")
Eq(ns.Setting("minimapAngle"), 225, "the default angle")
Check(not ns.IsAccountSetting("minimapButton") and not ns.IsAccountSetting("minimapAngle"),
    "the button's settings are not per character")
Eq(_G.SocialDiaryCharDB.settings.minimapAngle, 225, "the angle is not in the character's file")

local x, y = Anchor(button)
local d = REACH * math.sqrt(0.5)
Near(x, -d, "the default place, across")
Near(y, -d, "the default place, up")

--------------------------------------------------------------------------
Section("an angle puts it on the edge")

local function At(angle, wantX, wantY, what)
    local ox, oy = M.Offset(angle)
    Near(ox, wantX, what .. ", across")
    Near(oy, wantY, what .. ", up")
end

At(0, REACH, 0, "east")
At(90, 0, REACH, "north")
At(180, -REACH, 0, "west")
At(270, 0, -REACH, "south")

-- A square minimap: further out than the circle, 10 short of the very corner
-- so the button stays on the map's edge, and cut off at the sides.
local CORNER = (math.sqrt(2 * REACH * REACH) - 10) * math.sqrt(0.5)
Check(CORNER > d, "a square's corner is no further out than the circle")
_G.GetMinimapShape = function() return "SQUARE" end
At(45, CORNER, CORNER, "a square's corner")
At(225, -CORNER, -CORNER, "a square's far corner")
At(20, REACH, (math.sqrt(2 * REACH * REACH) - 10) * math.sin(math.rad(20)), "a square's side, near its middle")
At(0, REACH, 0, "a square's side")

-- Round only where the shape says: here the top left, not the top right.
_G.GetMinimapShape = function() return "CORNER-TOPLEFT" end
At(135, -d, d, "the round corner")
At(45, CORNER, CORNER, "a square corner beside it")

-- A shape nobody listed is round, not an error.
_G.GetMinimapShape = function() return "HEXAGON" end
At(45, d, d, "an unknown shape")
_G.GetMinimapShape = nil

--------------------------------------------------------------------------
Section("dragging it round the edge")

local function Mouse(degrees)
    local rad = math.rad(degrees)
    -- The mock minimap's middle is (700, 500); anywhere along the line will do.
    local scale = _G.Minimap:GetEffectiveScale()
    mock.pointer = { (700 + 300 * math.cos(rad)) * scale, (500 + 300 * math.sin(rad)) * scale }
end

local function Drag(degrees)
    button.scripts.OnDragStart(button)
    Check(button.scripts.OnUpdate, "the drag does not follow the mouse")
    Mouse(degrees)
    button.scripts.OnUpdate(button, 0.01)
end

_G.GameTooltip.shown = true
Drag(90)
Check(not _G.GameTooltip.shown, "the tooltip stays up while dragging")
x, y = Anchor(button)
Near(x, 0, "the button did not follow the mouse, across")
Near(y, REACH, "the button did not follow the mouse, up")
Eq(ns.Setting("minimapAngle"), 225, "the angle was saved before the drag ended")

Mouse(300)
button.scripts.OnDragStop(button)
Eq(button.scripts.OnUpdate, nil, "the drag still follows the mouse after it ended")
Near(ns.Setting("minimapAngle"), 300, "the angle saved at the drag's end")
Near(_G.SocialDiaryCharDB.settings.minimapAngle, 300, "the angle in the character's file")
x, y = Anchor(button)
Near(x, REACH * math.cos(math.rad(300)), "where the drag left it, across")
Near(y, REACH * math.sin(math.rad(300)), "where the drag left it, up")

-- West of the middle, atan2 is negative below the axis: still 0 to 360.
Drag(200)
button.scripts.OnDragStop(button)
Near(ns.Setting("minimapAngle"), 200, "an angle in the far quarter")

-- A scaled minimap: the mouse is in the client's pixels, the minimap's middle is not.
_G.Minimap.effectiveScale = 2
Drag(45)
button.scripts.OnDragStop(button)
Near(ns.Setting("minimapAngle"), 45, "the minimap's scale threw off the angle")
_G.Minimap.effectiveScale = nil

-- A new login finds it where it was left.
M.Refresh()
x, y = Anchor(button)
Near(x, d, "a refresh moved it, across")
Near(y, d, "a refresh moved it, up")

--------------------------------------------------------------------------
Section("the setting")

local P = ns.UI.SettingsPage()
Eq(P.minimapButton:GetChecked(), true, "the switch does not show the button on")
P.minimapButton:Click()
Eq(ns.Setting("minimapButton"), false, "the switch did not save")
Check(not button:IsShown(), "the switch did not hide the button at once")
P.minimapButton:Click()
Eq(ns.Setting("minimapButton"), true, "the switch did not save it back on")
Check(button:IsShown(), "the switch did not show the button at once")
Eq(_G.SocialDiaryCharDB.settings.minimapButton, true, "the switch is not in the character's file")

--------------------------------------------------------------------------
Section("what the clicks do")

ns.UI.CloseJournal()
button:Click("LeftButton")
Check(ns.UI.JournalShowing(), "a left click did not open the journal")
button:Click("LeftButton")
Check(not ns.UI.JournalShowing(), "a second left click did not close it")

button:Click("RightButton")
Check(ns.UI.JournalShowing(), "a right click did not open the journal")
Eq(ns.UI.JournalView(), "settings", "a right click did not turn to the settings")
button:Click("RightButton")
Check(ns.UI.JournalShowing(), "a second right click closed the journal")
Eq(ns.UI.JournalView(), "settings", "a second right click left the settings")
ns.UI.CloseJournal()

button.scripts.OnEnter(button)
Eq(_G.GameTooltip.text, "Social Diary", "the tooltip's title")
Eq(#_G.GameTooltip.lines, 3, "the tooltip does not say what the clicks and the drag do")
Check(_G.GameTooltip.shown, "the tooltip did not show")
button.scripts.OnLeave(button)
Check(not _G.GameTooltip.shown, "the tooltip did not go")

--------------------------------------------------------------------------
Section("turned off: no button until it is wanted, and it survives the login")

mock.Reset()
local ns2 = T.Load()
mock.SetUnit("player", T.F.SELF)
_G.SocialDiaryCharDB = { schema = 2, settings = { minimapButton = false, minimapAngle = 123 } }
mock.fire("ADDON_LOADED", ns2.addonName)
mock.fire("PLAYER_LOGIN")
Eq(_G.SocialDiaryMinimapButton, nil, "a button was made for a character who turned it off")
ns2.SetSetting("minimapButton", true)
ns2.UI.MinimapButton.Refresh()
button = _G.SocialDiaryMinimapButton
Check(button and button:IsShown(), "turning it back on made no button")
x = Anchor(button)
Near(x, REACH * math.cos(math.rad(123)), "the saved angle was not kept")

--------------------------------------------------------------------------
Section("saved data from before the button")

mock.Reset()
local ns3 = T.Load()
mock.SetUnit("player", T.F.SELF)
_G.SocialDiaryCharDB = {
    schema = 2,
    settings = { tooltips = false, bufferDays = 12, flatSheets = true },
    data = { schema = 5, characters = { ["Player-1-2"] = { first = "Bram" } } },
}
mock.fire("ADDON_LOADED", ns3.addonName)
-- Before the login, whose housekeeping prunes a stranger with no history.
Eq(_G.SocialDiaryCharDB.data.characters["Player-1-2"].first, "Bram", "the diary did not survive")
mock.fire("PLAYER_LOGIN")
Eq(_G.SocialDiaryCharDB.schema, 2, "the new settings should not need a new schema")
Eq(_G.SocialDiaryCharDB.settings.tooltips, false, "an old setting was overwritten")
Eq(_G.SocialDiaryCharDB.settings.bufferDays, 12, "an old setting was overwritten")
Eq(_G.SocialDiaryCharDB.settings.flatSheets, true, "an old setting was overwritten")
Eq(ns3.Setting("minimapButton"), true, "an old file's button is not on by default")
Eq(ns3.Setting("minimapAngle"), 225, "an old file has no angle")
Check(_G.SocialDiaryMinimapButton:IsShown(), "an old file's character has no button")
