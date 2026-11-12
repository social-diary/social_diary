-- Suggest a better wording: the strip that starts it (UI/Windows/Suggest/
-- Lookup.lua says what the folder is). A small slip of paper tucked behind
-- the book, standing up from behind the cover's top edge near its right
-- corner, left of the close button: out of the way of everything on the
-- pages, and of the hints' slip, which lies on the fore-edge lower down
-- (UI/Paper/HintSlip.lua). A click on it begins picking (Pick.lua).
--
-- Behind the book: the cover is drawn on the book's own frame (Style.Cover,
-- its BACKGROUND layer, edge to edge of the frame and opaque there), so
-- the strip is a child of the book one frame level under it. The client
-- draws by level, not by parentage: the cover's rim lies over the strip's
-- foot. A child keeps its distance when the book is raised (it is toplevel)
-- and follows its scale, place and shown state as any child does; Update
-- puts the level right again should anything have moved it.
--
-- Made only where the diary reads a translation (Locale.id other than
-- enUS), as the book is built (SD_JOURNAL_BUILT): an English diary has no
-- strip at all. Out only while nothing else holds the book: not during the
-- introduction's tour, writing, a run laid on the table, combat or picking,
-- and never with the pad in hand: typing a wording and copying its link
-- want a keyboard and a mouse (the CHANGELOG 3.0.0 precedent). Nor while
-- its switch is off (the account setting showSuggestStrip, Settings >
-- Language): that puts the strip away, not the translation's notice or
-- its link. Looked at on a slow ticker while the book is open, and at once
-- when the pad is picked up or put down or the switch is written
-- (SD_SETTING_CHANGED): nothing at all while the book is shut.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local L = ns.L

local Suggest = ns.UI.Suggest
local Strip = {}
Suggest.Strip = Strip

-- Where it stands: its right edge `right` px in from the book's top right
-- (clear of the close button and the brass corner), `sink` px of it behind
-- the cover's top edge, so `tall - sink` px show; its words `pad` px in
-- each side, centred in what shows; looked at every `tick` seconds while
-- the book is open.
local PLACE = { right = 54, sink = 8, pad = 9, tall = 26, lozenge = 4, tick = 0.5 }
local STOCK = { 0.91, 0.84, 0.66 }
Strip.PLACE = PLACE

local holder, tab, ticker, book

-- Under the book, by one frame level. A book at level 0 has nothing under
-- it: there the strip stands on the cover's edge instead, over it.
local function Tuck()
    local level = book:GetFrameLevel()
    local behind = level > 0
    local want = behind and level - 1 or level + 1
    if tab:GetFrameLevel() ~= want then tab:SetFrameLevel(want) end
    if tab.behind ~= behind then
        tab.behind = behind
        tab:ClearAllPoints()
        tab:SetPoint("BOTTOMRIGHT", book, "TOPRIGHT", -PLACE.right, behind and -PLACE.sink or 0)
    end
end

-- Whether the strip should be out now.
function Strip.Wanted()
    if ns.Locale.id == "enUS" then return false end
    if ns.Setting("showSuggestStrip") == false then return false end
    local J = ns.UI.Journal
    if not (J and J.journal and J.journal:IsShown()) then return false end
    if J.visit or J.editing then return false end
    local Tour = ns.UI.Tour
    if Tour and (Tour.step or Tour.example) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local Pad = ns.UI.Pad
    if Pad and Pad.Input.Active() then return false end
    if Suggest.Pick.Picking() then return false end
    return true
end

function Strip.Update()
    if not tab then return end
    Tuck()
    tab:SetShown(Strip.Wanted())
end

local function Ink(hot)
    local c = hot and Style.INK_STRONG or Style.INK
    tab.label:SetTextColor(c[1], c[2], c[3])
    for _, edge in ipairs(tab.edges) do
        edge:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], hot and Style.HAIRLINE_HOT or Style.HAIRLINE)
    end
end

local function Build(panel)
    book = panel
    holder = CreateFrame("Frame", nil, panel)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPRIGHT")
    holder:Show()
    -- Shown and hidden with the book: the ticker runs only while it is open,
    -- and picking ends with it.
    holder:SetScript("OnShow", function()
        Strip.Update()
        if not ticker and C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(PLACE.tick, Strip.Update)
        end
    end)
    holder:SetScript("OnHide", function()
        if ticker then ticker:Cancel(); ticker = nil end
        Suggest.Pick.Stop()
    end)

    tab = CreateFrame("Button", nil, holder)
    local paper = tab:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    paper:SetColorTexture(STOCK[1], STOCK[2], STOCK[3], 1)
    tab.edges = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = tab:CreateTexture(nil, "BORDER")
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[2] == "TOPRIGHT" then edge:SetHeight(1) else edge:SetWidth(1) end
        tab.edges[#tab.edges + 1] = edge
    end
    tab.lozenge = Style.Lozenge(tab, "ARTWORK", PLACE.lozenge, Style.RUBRIC)
    -- The words sit in the middle of what shows above the cover.
    local lift = PLACE.sink / 2
    tab.lozenge:SetPoint("LEFT", PLACE.pad, lift)
    tab.label = Style.Text(tab, FONT.small)
    tab.label:SetPoint("LEFT", PLACE.pad + PLACE.lozenge + 6, lift)
    tab.label:SetText(L["Suggest Translation"])
    tab:SetSize((tab.label:GetStringWidth() or 120) + 2 * PLACE.pad + PLACE.lozenge + 6, PLACE.tall)
    Tuck()
    -- What is behind the cover takes no click: that is the book's.
    tab:SetHitRectInsets(0, 0, 0, PLACE.sink)
    tab:RegisterForClicks("LeftButtonUp")
    tab:SetScript("OnClick", function() Suggest.Start() end)
    Style.Tooltip(tab, L["Pick a line in the diary and suggest how it should read."], "ANCHOR_TOP",
        function(_, over) Ink(over) end)
    Ink(false)
    tab:Hide()
    Strip.Update()
end

-- Picking begins (the strip, or the translation's notice).
function Suggest.Start()
    return Suggest.Pick.Start()
end

-- Whether picking can begin from here: a translation read, the pad not in hand.
function Suggest.Available()
    if ns.Locale.id == "enUS" then return false end
    local Pad = ns.UI.Pad
    return not (Pad and Pad.Input.Active())
end

-- The strip's button, for the tests and the walk to skip: nil on English.
function Strip.Frame() return tab end

if ns.Locale.id ~= "enUS" then
    ns.On("SD_JOURNAL_BUILT", function(_, panel)
        if not holder then Build(panel) end
    end)
    ns.On("PLAYER_LOGIN", function()
        ns.UI.Pad.Input.OnChange(function() Strip.Update() end)
    end)
    ns.On("SD_SETTING_CHANGED", function(_, key)
        if key == "showSuggestStrip" then Strip.Update() end
    end)
end
