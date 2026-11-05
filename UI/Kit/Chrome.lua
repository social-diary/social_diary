-- The dark Blizzard-style chrome: Panel, Label, Button.
--
-- Hand-rolled rather than templated, for the reason REU-3 gives about toasts:
-- the less of Blizzard's own machinery the addon reaches into, the less it can
-- taint. These are plain frames with plain textures; only the widely-used
-- widget templates (buttons, edit boxes, the close button) are borrowed.
--
-- The first UI file loaded, so it makes ns.UI; the chrome is ns.UI.Chrome.
-- Its siblings: the virtual list (UI/Kit/List.lua) and the text helpers
-- (ns.UI.Format, UI/Words/Format.lua).

local addonName, ns = ...

ns.UI = ns.UI or {}

local Chrome = {}
ns.UI.Chrome = Chrome

-- The dialog border, over an opaque background. The stock dialog background
-- draws nearly see-through in this client, and text over the game world is
-- hard to read.
local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- A movable, escape-closable dialog with a heading and a close button.
--
-- `opts.bare`: no border, background or heading, for a window that draws
-- its own (the journal's cover, the loose sheet). Its close button sits
-- `opts.closeOutset` out past the top right corner, where there is no
-- border to sit inside.
function Chrome.Panel(globalName, width, height, title, opts)
    local bare = opts and opts.bare
    local panel = CreateFrame("Frame", globalName, UIParent, not bare and "BackdropTemplate" or nil)
    panel:SetSize(width, height)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    if not bare then
        panel:SetBackdrop(BACKDROP)
        panel:SetBackdropColor(0.07, 0.06, 0.05, 0.97)
    end
    panel:Hide()

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    if bare then
        close:SetPoint("TOPRIGHT", opts.closeOutset or 0, opts.closeOutset or 0)
    else
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    -- The template's own click goes through HideUIPanel, which Blizzard
    -- refuses to addons in combat (it returns before the plain Hide it
    -- would otherwise do for a window that is no UI panel). Hiding the
    -- window directly is allowed in combat, as the minimap button does.
    close:SetScript("OnClick", function(self) self:GetParent():Hide() end)
    panel.close = close

    if not bare then
        panel.heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        panel.heading:SetPoint("TOPLEFT", 18, -20)
        panel.heading:SetPoint("RIGHT", -34, 0)
        panel.heading:SetJustifyH("LEFT")
        panel.heading:SetText(title or "")
    end

    -- Escape closes it, the way every other WoW window behaves.
    if globalName then
        UISpecialFrames[#UISpecialFrames + 1] = globalName
    end

    return panel
end

function Chrome.Label(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

function Chrome.Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end
