-- The parcel's host and entry points (PRV-4): the frame the scene lies on
-- (SocialDiaryIntroFrame), laying it wrapped or torn, tearing it
-- (Parcel.HideSlip), and ns.UI.OfferSlip and ns.UI.Slip (for the tests),
-- with the events that offer it at login and keep it out of a fight. What
-- "Open me" opens, ns.UI.ShowIntro, is the tour's (UI/Windows/Intro/Tour.lua). What it looks like, and the state shared on ns.UI.Parcel, is
-- UI/Windows/Intro/Scene.lua's; its pieces Wrapped.lua and Torn.lua.

local addonName, ns = ...

local Style = ns.Style
local Parcel = ns.UI.Parcel

local SHOW_DELAY = 4

local SCENE = Parcel.SCENE
local Kit = Parcel.Kit
local BuildWrapped, LayWrapped = Parcel.BuildWrapped, Parcel.LayWrapped
local BuildTorn, LayLabel, LayNote = Parcel.BuildTorn, Parcel.LayLabel, Parcel.LayNote

--------------------------------------------------------------------------
-- The host
--------------------------------------------------------------------------

local function Build()
    local host = CreateFrame("Frame", "SocialDiaryIntroFrame", UIParent)
    host:SetSize(SCENE.w, SCENE.h)
    host:SetFrameStrata("HIGH")
    host:SetClampedToScreen(true)
    host:Hide()
    -- Escape puts it away, like Later.
    UISpecialFrames[#UISpecialFrames + 1] = "SocialDiaryIntroFrame"

    local probe = host:CreateFontString(nil, "OVERLAY")
    host.turnsText = probe.SetRotation ~= nil
    probe:Hide()

    local S = Kit(host)
    BuildWrapped(host, S)
    BuildTorn(host, S)
    host.counts = { teeth = S.teeth, textures = S.made }

    function host:Lay()
        local flat = ns.Setting("flatSheets") == true
        local state = ns.Setting("parcelOpened") and "torn" or "wrapped"
        local maker = UnitFactionGroup("player") == "Horde" and "goblin" or "gnome"
        self.state, self.maker = state, maker
        self:SetScale(SCENE.scale)
        self:ClearAllPoints()
        self:SetPoint("TOP", UIParent, "TOP", SCENE.w / 2 - (SCENE.middle[state] - SCENE.left), SCENE.y)
        for _, shadow in ipairs(S.shadows) do shadow:SetShown(not flat and not shadow.never) end
        for _, edge in ipairs(self.edges) do edge:Lay(flat) end
        self.wrapped:SetShown(state == "wrapped")
        self.torn:SetShown(state == "torn")
        if state == "wrapped" then
            LayWrapped(self, S, maker)
        else
            LayLabel(self, S, flat)
            LayNote(self, flat, not Parcel.tornNow)
        end
    end

    -- Torn open: kept, with the paper's sound, and laid again.
    function host:Tear()
        if self.state ~= "wrapped" then return end
        ns.SetSetting("parcelOpened", true)
        Parcel.tornNow = true
        Style.PlaySound("tear")
        self:Lay()
    end

    -- However it goes -- Later, Escape, the book opening -- the note goes
    -- with it.
    host:SetScript("OnHide", function() host.note:Hide(true) end)

    return host
end

-- Puts it away: with the paper's rustle, unless `quiet`.
function Parcel.HideSlip(quiet)
    local slip = Parcel.slip
    if not slip or not slip:IsShown() then return end
    if quiet ~= false then quiet = true end
    slip:Hide()
    if not quiet then Style.PlaySound("sheetClose") end
end

-- Lays it over the game, if it is still due: the introduction unseen, not
-- put away this login, and no fight on.
function ns.UI.OfferSlip()
    if ns.Setting("introSeen") or Parcel.later then return end
    if InCombatLockdown() then
        Parcel.waiting = true
        return
    end
    Parcel.waiting = false
    Parcel.slip = Parcel.slip or Build()
    local slip = Parcel.slip
    if slip:IsShown() then return end
    slip:Show()
    slip:Raise()
    slip:Lay()
    Style.PlaySound("sheetOpen")
end

-- Test hook: the parcel's host.
function ns.UI.Slip()
    return Parcel.slip
end

ns.On("PLAYER_LOGIN", function()
    Parcel.later, Parcel.tornNow = false, false
    if ns.Setting("introSeen") then return end
    C_Timer.After(SHOW_DELAY, ns.UI.OfferSlip)
end)

ns.On("PLAYER_REGEN_DISABLED", function()
    local slip = Parcel.slip
    if slip and slip:IsShown() then
        Parcel.HideSlip(true)
        Parcel.waiting = true
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    if Parcel.waiting then ns.UI.OfferSlip() end
end)
