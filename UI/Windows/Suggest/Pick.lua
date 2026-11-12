-- Suggest a better wording: picking a line (UI/Windows/Suggest/Lookup.lua
-- says what the folder is). Like a browser's element picker: a full-screen
-- overlay of our own (never protected, never a Blizzard frame) takes the
-- mouse; the line of the diary under the cursor is ruled round in red; a
-- click picks it, and right-click or Escape stops.
--
-- Which lines: the font strings of the diary's own windows (ROOTS), found
-- by walking their visible frames (GetChildren, GetRegions) as picking
-- begins, every time afresh: nothing anywhere registers or tags its text.
-- Under the cursor (IsMouseOver, inside every clipping frame above it), the
-- topmost wins, and of those the smallest (a word in a line over the page
-- round it).
--
-- It ends on Escape, a right-click, the book closing (Strip.lua), combat
-- starting, the pad being picked up, or a reload. Its OnUpdate runs only
-- while it is out.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local L = ns.L

local Suggest = ns.UI.Suggest
local Pick = {}
Suggest.Pick = Pick

-- The diary's windows, by their global names: the book (with its pages,
-- settings and the sheets laid on it), the quick note, the dungeon spread
-- and its note.
Pick.ROOTS = { "SocialDiaryJournalFrame", "SocialDiaryNoteFrame", "SocialDiaryTableSpread",
    "SocialDiaryDungeonTutorial" }
-- The ring round the line: `pad` px out from it, `edge` px of red, a wash
-- of `fill` inside. A fresh walk every `every` seconds while picking (a
-- page that changes under it); the hover looked at only when the cursor
-- moved.
local RING = { pad = 2, edge = 1.5, fill = 0.10 }
local WALK = { every = 1.5 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
Pick.RING = RING

-- A widget's method where it has one, else nil. Asked through pcall: the
-- client's widgets answer nil for a method they lack, the test mock raises.
local function Index(object, name) return object[name] end
local function Method(object, name)
    local ok, fn = pcall(Index, object, name)
    return ok and type(fn) == "function" and fn or nil
end
local function Ask(object, name, ...)
    local fn = Method(object, name)
    if fn then return fn(object, ...) end
end

--------------------------------------------------------------------------
-- The walk
--------------------------------------------------------------------------

-- The roots that are out now, as frames.
function Pick.Roots()
    local out = {}
    for _, name in ipairs(Pick.ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" and Ask(f, "IsVisible") then out[#out + 1] = f end
    end
    return out
end

-- Whether `f` is out of bounds for us: forbidden, protected, or ours to skip.
local function Off(f, skip)
    if skip and skip[f] then return true end
    if Ask(f, "IsForbidden") then return true end
    if Ask(f, "IsProtected") then return true end
    return false
end

-- Every shown line with words under `roots`: { region, clips (the clipping
-- frames above it), strata, level }. `skip` holds frames not to enter (the
-- strip, the overlay).
function Pick.Collect(roots, skip)
    local found = {}
    local function Walk(f, clips, depth)
        if depth > 40 or Off(f, skip) or not Ask(f, "IsVisible") then return end
        if Ask(f, "DoesClipChildren") then
            local inner = {}
            for i, c in ipairs(clips) do inner[i] = c end
            inner[#inner + 1] = f
            clips = inner
        end
        local strata = STRATA[Ask(f, "GetFrameStrata") or ""] or 0
        local level = Ask(f, "GetFrameLevel") or 0
        local regions = Method(f, "GetRegions") and { f:GetRegions() } or {}
        for _, r in ipairs(regions) do
            if Ask(r, "GetObjectType") == "FontString" and Ask(r, "IsVisible") then
                local text = Ask(r, "GetText")
                local alpha = Ask(r, "GetEffectiveAlpha") or 1
                if type(text) == "string" and alpha > 0.05 and Suggest.Clean(text) ~= "" then
                    found[#found + 1] = { region = r, clips = clips, strata = strata, level = level }
                end
            end
        end
        local children = Method(f, "GetChildren") and { f:GetChildren() } or {}
        for _, child in ipairs(children) do Walk(child, clips, depth + 1) end
    end
    for _, root in ipairs(roots) do Walk(root, {}, 0) end
    return found
end

-- Whether the cursor is over `r`: its own IsMouseOver where it has one, else
-- its rectangle against the cursor.
local function Over(r)
    if Method(r, "IsMouseOver") then return r:IsMouseOver() == true end
    local left, right, top, bottom = Ask(r, "GetLeft"), Ask(r, "GetRight"), Ask(r, "GetTop"), Ask(r, "GetBottom")
    if not (left and right and top and bottom and GetCursorPosition) then return false end
    local x, y = GetCursorPosition()
    local scale = Ask(r, "GetEffectiveScale") or 1
    x, y = x / scale, y / scale
    return x >= left and x <= right and y >= bottom and y <= top
end
Pick.Over = Over

local function Area(r)
    return (Ask(r, "GetWidth") or 0) * (Ask(r, "GetHeight") or 0)
end

-- The line under the cursor of `found`: the topmost, then the smallest.
function Pick.Under(found)
    local best
    for _, c in ipairs(found) do
        if Ask(c.region, "IsVisible") and Over(c.region) then
            local inside = true
            for _, clip in ipairs(c.clips) do
                if not Over(clip) then inside = false; break end
            end
            if inside then
                c.area = Area(c.region)
                if not best or c.strata > best.strata
                    or (c.strata == best.strata and (c.level > best.level
                        or (c.level == best.level and c.area < best.area))) then
                    best = c
                end
            end
        end
    end
    return best and best.region or nil
end

--------------------------------------------------------------------------
-- The overlay
--------------------------------------------------------------------------

local overlay, found, walked, hovered, lastX, lastY

local function Ring(r)
    local ring = overlay.ring
    if not r then
        ring:Hide()
        return
    end
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", r, "TOPLEFT", -RING.pad, RING.pad)
    ring:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", RING.pad, -RING.pad)
    ring:Show()
end

local function Hover(force)
    local x, y = 0, 0
    if GetCursorPosition then x, y = GetCursorPosition() end
    if not force and x == lastX and y == lastY then return end
    lastX, lastY = x, y
    hovered = Pick.Under(found or {})
    Ring(hovered)
end
Pick.Hover = Hover

local function Skip()
    local skip = { [overlay] = true }
    local strip = Suggest.Strip and Suggest.Strip.Frame and Suggest.Strip.Frame()
    if strip then skip[strip] = true end
    return skip
end

local function Walk()
    found = Pick.Collect(Pick.Roots(), Skip())
    walked = GetTime and GetTime() or 0
end

local function Build()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:EnableKeyboard(true)
    f:Hide()

    local RUBRIC = Style.RUBRIC
    local ring = CreateFrame("Frame", nil, f)
    ring:SetFrameLevel(f:GetFrameLevel() + 2)
    ring:Hide()
    local wash = ring:CreateTexture(nil, "BACKGROUND")
    wash:SetAllPoints()
    wash:SetColorTexture(RUBRIC[1], RUBRIC[2], RUBRIC[3], RING.fill)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = ring:CreateTexture(nil, "BORDER")
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[1]:sub(1, 3) == side[2]:sub(1, 3) then edge:SetHeight(RING.edge) else edge:SetWidth(RING.edge) end
        edge:SetColorTexture(RUBRIC[1], RUBRIC[2], RUBRIC[3], 0.9)
    end
    f.ring = ring

    -- What to do, on a slip of paper at the top of the screen.
    local tag = CreateFrame("Frame", nil, f)
    tag:SetPoint("TOP", f, "TOP", 0, -48)
    tag:SetFrameLevel(f:GetFrameLevel() + 3)
    local paper = tag:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    paper:SetColorTexture(Style.PAPER[1], Style.PAPER[2], Style.PAPER[3], 0.97)
    local INK = Style.INK
    local rule = tag:CreateTexture(nil, "BORDER")
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(1)
    rule:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
    tag.text = Style.Text(tag, FONT.body)
    tag.text:SetPoint("CENTER")
    tag.text:SetText(L["Click the line you want to change. Right-click or Escape to stop."])
    tag:SetSize((tag.text:GetStringWidth() or 300) + 28, 30)
    f.tag = tag

    f:SetScript("OnUpdate", function()
        if GetTime and walked and GetTime() - walked > WALK.every then
            Walk()
            Hover(true)
        else
            Hover()
        end
    end)
    f:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            Pick.Stop()
            return
        end
        if button ~= "LeftButton" then return end
        Hover(true)
        local r = hovered
        if not r then return end
        local text = r:GetText()
        Pick.Stop()
        Suggest.Sheet.Open(text)
    end)
    -- Escape stops it here and goes no further (else the game's Escape
    -- would shut the book too); every other key goes on to the game.
    f:SetScript("OnKeyDown", function(self, key)
        local escape = key == "ESCAPE"
        if not (InCombatLockdown and InCombatLockdown()) then
            self:SetPropagateKeyboardInput(not escape)
        end
        if escape then Pick.Stop() end
    end)
    return f
end

function Pick.Picking()
    return overlay ~= nil and overlay:IsShown()
end

-- Whether picking may begin now: not in combat, the pad not in hand.
function Pick.May()
    if InCombatLockdown and InCombatLockdown() then return false end
    local Pad = ns.UI.Pad
    if Pad and Pad.Input.Active() then return false end
    return #Pick.Roots() > 0
end

function Pick.Start()
    if not Pick.May() then return false end
    overlay = overlay or Build()
    hovered, lastX, lastY = nil, nil, nil
    overlay.ring:Hide()
    overlay:Show()
    Walk()
    Hover(true)
    Style.PlaySound("hint")
    if Suggest.Strip then Suggest.Strip.Update() end
    return true
end

function Pick.Stop()
    if not overlay then return end
    hovered, found = nil, nil
    overlay.ring:Hide()
    if overlay:IsShown() then overlay:Hide() end
    if Suggest.Strip then Suggest.Strip.Update() end
end

-- The overlay, for the tests: nil until picking first began.
function Pick.Frame() return overlay end

-- Combat takes the screen back at once; so does the pad. Only where there
-- is a translation to pick from.
if ns.Locale.id ~= "enUS" then
    ns.On("PLAYER_REGEN_DISABLED", function() Pick.Stop() end)
    ns.On("PLAYER_LOGIN", function()
        ns.UI.Pad.Input.OnChange(function(active) if active then Pick.Stop() end end)
    end)
end
