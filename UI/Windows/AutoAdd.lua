-- Auto-add's one question (Core/AutoAdd.lua): switched on in Settings >
-- Recording, the people already seen near you often enough to pass its
-- seen rule are offered once, on a loose sheet of the house paper over the
-- game, as the suggestion sheet is (UI/Windows/Suggest/Sheet.lua, which
-- follows the quick note's, UI/Paper/NoteSheet.lua): how many, a few of
-- their names, and two links, "Add them" and "Not now". Nobody waiting, or
-- the switch going off, shows nothing.
--
-- The list is the one taken as it opened (AutoAdd.AddWaiting checks each
-- again). "Not now" adds nobody and leaves the setting on: they are then
-- added one at a time as they are seen again. Escape is "Not now". With the
-- pad, the sheet is a window of its own (UI/Windows/Pad.lua's `autoadd`).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local L = ns.L

local Sheet = {}
ns.UI.AutoAdd = Sheet

-- How many names it says before "and N others".
Sheet.NAMES = 3

-- The sheet in its own coordinates (x right, y down): `w` wide, `margin`
-- each side; the title's middle `title` down, the words from `first`, a
-- line `line` apart, `gap` between parts, the links `foot` up from the foot.
local SHEET = { w = 380, margin = 30, title = 34, first = 68, line = 16, gap = 10, foot = 30 }
Sheet.SHEET = SHEET
-- Folded once across and hardly crumpled, as the suggestion's; it lies
-- straight, so its words read level.
local CREASE = {
    columns = { 0, 0.08, 0.92, 1 },
    rows = { 0, 0.08, 0.5, 0.92, 1 },
    folds = { columns = {}, rows = { [3] = -1 } },
    crumple = 0.4, drift = 0.3, edge = 0.5, wander = 0, shift = 2, lean = 1,
    curl = { lift = 4, pull = 2 },
}
local HOST = { w = SHEET.w + 60, h = 360 }

local host, view, K

local function Build()
    host = CreateFrame("Frame", "SocialDiaryAutoAddFrame", UIParent)
    host:SetSize(HOST.w, HOST.h)
    host:SetPoint("CENTER")
    host:SetFrameStrata("DIALOG")
    host:SetToplevel(true)
    host:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = "SocialDiaryAutoAddFrame"
    ns.UI.Scale.Register(host, HOST.w, HOST.h)

    view, K = ns.UI.LooseSheet(host, SHEET.w, 240, { crease = CREASE, straight = true })
    local S = view.sheet
    host:SetScript("OnHide", function()
        if view:IsShown() then view:Hide(true) end
        view.list = nil
        -- (the pad's scope goes with it)
        ns.UI.Pad.Refresh()
    end)

    view.title = Style.Text(S, FONT.page)
    view.title:SetText(L["Familiar faces"])
    view.texts = {}

    view.later = K.Link(FONT.body, function() Sheet.Close() end)
    view.later:SetText(L["Not now"])
    view.add = K.Link(FONT.strong, function() Sheet.Add() end)
    view.add:SetText(L["Add them"])
end

-- The words, a part at a time: { text, font, faded }.
local function Parts(list)
    -- (the names it knows first; one it doesn't is counted, never named)
    local names, unknown = {}, 0
    for _, guid in ipairs(list) do
        local name = ns.Characters.Name(guid) or ns.Characters.FullName(guid)
        if name then names[#names + 1] = name else unknown = unknown + 1 end
    end
    local shown = math.min(Sheet.NAMES, #names)
    for _ = 1, unknown do names[#names + 1] = "" end
    local Format = ns.UI.Format
    local named = shown > 0 and (shown == #list and Format.List(names)
        or Format.List(names, { max = shown, shown = shown, more = Format.OTHERS }))
    local parts = {
        { ns.Plural(#list, L["You’ve seen %d person near you 3 times or more.|You’ve seen %d people near you 3 times or more.##plural"]), FONT.body },
    }
    if named then parts[#parts + 1] = { named, FONT.strong } end
    parts[#parts + 1] = { L["Add them to the diary now? If not, they’re added the next time you see them."], FONT.body }
    return parts
end

local function Lay()
    local M, W = SHEET.margin, SHEET.w
    local width = W - 2 * M
    local parts = Parts(view.list)
    local lines = {}
    for i, part in ipairs(parts) do
        lines[i] = K.Wrap(part[1], width, part[2])
    end
    local h = SHEET.first
    for _, l in ipairs(lines) do h = h + #l * SHEET.line + SHEET.gap end
    h = h + SHEET.foot + SHEET.line
    K.Reshape(W, h)
    K.Fall("autoadd")
    K.Lay()

    K.PlaceText(view.title, M, SHEET.title)
    local used, y = 0, SHEET.first
    for i, part in ipairs(parts) do
        local font = part[2]
        for _, line in ipairs(lines[i]) do
            used = used + 1
            local fs = view.texts[used] or Style.Text(view.sheet, font)
            view.texts[used] = fs
            fs:SetFontObject(font)
            local c = font == FONT.strong and Style.INK_STRONG or Style.INK
            fs:SetTextColor(c[1], c[2], c[3])
            fs:SetText(line)
            K.PlaceText(fs, M, y)
            fs:Show()
            y = y + SHEET.line
        end
        y = y + SHEET.gap
    end
    for i = used + 1, #view.texts do view.texts[i]:Hide() end

    view.add:PlaceAt(W - M, h - SHEET.foot, "RIGHT")
    view.later:PlaceAt(W - M - K.Width(view.add.label) - 18, h - SHEET.foot, "RIGHT")
    view.add:Show()
    view.later:Show()
end

-- Opens the sheet on `list` (GUIDs, as AutoAdd.Waiting gives them). An
-- empty list opens nothing. The player's own path (the switch), so it takes
-- the pad when it is in hand.
function Sheet.Open(list)
    if not (list and #list > 0) then return false end
    if not host then Build() end
    view.list = list
    host:Show()
    host:Raise()
    view:Show()
    Lay()
    ns.UI.Pad.Opened(host)
    return true
end

-- The switch's `after`: on, and someone is waiting, the sheet asks.
function Sheet.Offer(on)
    if not on then return false end
    return Sheet.Open(ns.AutoAdd.Waiting())
end

-- Adds the list taken as it opened, then puts the sheet away.
function Sheet.Add()
    if not (host and host:IsShown() and view.list) then return 0 end
    local list = view.list
    view.list = nil
    view:Hide(true)
    host:Hide()
    Style.PlaySound("write")
    return ns.AutoAdd.AddWaiting(list)
end

function Sheet.Close()
    if host and host:IsShown() then host:Hide() end
end

function Sheet.Shown() return host ~= nil and host:IsShown() end

-- The host, the view and the list it holds, for the pad and the tests.
function Sheet.Host() return host end
function Sheet.View() return view end
