-- The button on the minimap's edge: the logo in the ring every minimap button
-- wears, so it sits among the others. Left click is the journal, right click
-- the settings, a drag moves it round the edge. Its one setting is
-- `minimapButton` (UI/Settings/Sections/Interface.lua); where it lies is
-- `minimapAngle`, both per character. Hand-rolled, with no library, under a
-- global name so the minimap collectors can find it.

local addonName, ns = ...

local Style = ns.Style

ns.UI.MinimapButton = {}
local MinimapButton = ns.UI.MinimapButton

Style.AddArt("minimapLogo", { "Interface\\AddOns\\" .. addonName .. "\\Art\\Minimap\\logo",
    "Interface\\Icons\\INV_Misc_Book_09" })
Style.AddArt("minimapRing", { "Interface\\Minimap\\MiniMap-TrackingBorder" })
Style.AddArt("minimapGround", { "Interface\\Minimap\\UI-Minimap-Background" })
Style.AddArt("minimapHover", { "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" })

-- The ring's art is drawn off-centre in its file: it lies from the button's
-- top left at RING, and its hole is about GROUND wide round the button's middle.
local LOOK = {
    SIZE = 31,       -- the button, as other minimap buttons
    RING = 50,
    GROUND = 24,
    LOGO = 20,       -- the logo's circle is in its art; it needs no mask
    PRESS = 1,       -- how far the logo sinks when pressed, down and right
    PRESSED = 0.8,   -- and how much it dims
}

-- How far outside the minimap's edge its middle lies.
local OUTSIDE = 5

-- For each minimap shape, whether each quarter of it is round: bottom right,
-- bottom left, top right, top left. A shape not listed is treated as round.
local SHAPES = {
    ROUND = { true, true, true, true },
    SQUARE = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

-- Where the button's middle lies from the minimap's, for an angle in degrees
-- (0 is east, 90 north): on the circle in a round quarter; in a square one,
-- on a wider circle cut off at the square's sides.
function MinimapButton.Offset(angle)
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local quarter = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local shape = SHAPES[GetMinimapShape and GetMinimapShape() or "ROUND"] or SHAPES.ROUND
    local reach = Minimap:GetWidth() / 2 + OUTSIDE
    if shape[quarter] then return x * reach, y * reach end
    local corner = math.sqrt(2 * reach * reach) - 10
    return math.max(-reach, math.min(x * corner, reach)), math.max(-reach, math.min(y * corner, reach))
end

local button

local function Place(angle)
    local x, y = MinimapButton.Offset(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- The angle from the minimap's middle to the mouse, in degrees from 0 to 360.
local function CursorAngle()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local midX, midY = Minimap:GetCenter()
    return math.deg(math.atan2(y / scale - midY, x / scale - midX)) % 360
end

local function Press(down)
    local sink = down and LOOK.PRESS or 0
    button.logo:ClearAllPoints()
    button.logo:SetPoint("CENTER", button, "CENTER", sink, -sink)
    local shade = down and LOOK.PRESSED or 1
    button.logo:SetVertexColor(shade, shade, shade)
end

local function Dragging()
    Place(CursorAngle())
end

local function Build()
    button = CreateFrame("Button", "SocialDiaryMinimapButton", Minimap)
    button:SetSize(LOOK.SIZE, LOOK.SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(LOOK.GROUND, LOOK.GROUND)
    ground:SetPoint("CENTER", button, "CENTER")
    ground:SetTexture(Style.Art("minimapGround"))

    button.logo = button:CreateTexture(nil, "ARTWORK")
    button.logo:SetSize(LOOK.LOGO, LOOK.LOGO)
    button.logo:SetTexture(Style.Art("minimapLogo"))
    Press(false)

    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(LOOK.RING, LOOK.RING)
    ring:SetPoint("TOPLEFT", button, "TOPLEFT")
    ring:SetTexture(Style.Art("minimapRing"))

    button:SetHighlightTexture(Style.Art("minimapHover"))

    Style.Tooltip(button, function()
        return Style.TipList("Social Diary", {
            "Click to open or close the journal.",
            "Right-click to open the settings.",
            "Drag to move this button.",
        })
    end, "ANCHOR_LEFT")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            ns.UI.ShowSettings()
        else
            ns.UI.ToggleJournal()
        end
    end)
    button:SetScript("OnMouseDown", function() Press(true) end)
    button:SetScript("OnMouseUp", function() Press(false) end)

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        Press(true)
        self:SetScript("OnUpdate", Dragging)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        Press(false)
        ns.SetSetting("minimapAngle", CursorAngle())
        Place(ns.Setting("minimapAngle"))
    end)
end

-- The button as the settings say: made the first time it is wanted, so a
-- character who turned it off never has one until they turn it back on.
function MinimapButton.Refresh()
    local on = ns.Setting("minimapButton")
    if not button then
        if not on then return end
        Build()
    end
    Place(ns.Setting("minimapAngle"))
    button:SetShown(on)
end

ns.On("PLAYER_LOGIN", MinimapButton.Refresh)
