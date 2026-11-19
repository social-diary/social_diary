-- Auto-add's one question (Core/AutoAdd.lua): the people who already pass
-- the player's rules are offered once, on a loose sheet of the house paper
-- over the game, as the suggestion sheet is (UI/Windows/Suggest/Sheet.lua,
-- which follows the quick note's, UI/Paper/NoteSheet.lua). It is asked when
-- the master switch goes on in Settings > Recording (every rule that is on),
-- and when the rule sheet is put away (UI/Settings/Rules.lua: the rules
-- added, switched on or widened there, AutoAdd.AskAbout), one sheet for all
-- of them (.claude/features/auto-add-rules-ui.md §4.6): how many, a line per
-- rule with how many it brings ("and N more rules" past three), a few names
-- (each person once, by the first rule they pass), and two links, "Add
-- them" and "Not now". Its title is the rule's name when one rule asks (a
-- preset's, else "Your rule"). Nobody waiting, or the switch going off,
-- shows nothing.
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

-- How many names it says before "and N others", and how many rules'
-- lines before "and N more rules".
Sheet.NAMES = 3
Sheet.RULES = 3

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
    view.texts = {}

    view.later = K.Link(FONT.body, function() Sheet.Close() end)
    view.later:SetText(L["Not now"])
    view.add = K.Link(FONT.strong, function() Sheet.Add() end)
    view.add:SetText(L["Add them"])
end

local function Capital(text) return ns.Locale.grammar.Capital(text) end

-- The rules `list` came with, in the list's order (rules no longer in it
-- after), and how many people each brings.
local function Asking(list)
    local count, order, rank = {}, {}, {}
    for i, rule in ipairs(ns.AutoAdd.Rules()) do rank[rule] = i end
    for _, item in ipairs(list) do
        local rule = item.rule
        if rule then
            if not count[rule] then order[#order + 1] = rule end
            count[rule] = (count[rule] or 0) + 1
        end
    end
    table.sort(order, function(a, b) return (rank[a] or math.huge) < (rank[b] or math.huge) end)
    return order, count
end

-- The title: the rule's name when one rule asks, else the lot's.
local function Title(rules)
    if #rules == 1 then
        local rule = rules[1]
        return rule.preset and ns.AutoAdd.PresetName(rule.preset) or L["Your rule"]
    end
    return L["People who already match your rules"]
end

-- The words, a part at a time: { text, font, tight } (`tight`: no gap
-- under it, the next line its own).
local function Parts(list)
    -- (the names it knows first; one it doesn't is counted, never named)
    local names, unknown = {}, 0
    for _, item in ipairs(list) do
        local guid = item.guid
        local name = ns.Characters.Name(guid) or ns.Characters.FullName(guid)
        if name then names[#names + 1] = name else unknown = unknown + 1 end
    end
    local shown = math.min(Sheet.NAMES, #names)
    for _ = 1, unknown do names[#names + 1] = "" end
    local Format = ns.UI.Format
    local named = shown > 0 and (shown == #list and Format.List(names)
        or Format.List(names, { max = shown, shown = shown, more = Format.OTHERS }))
    local rules, count = Asking(list)
    local parts = {
        { #rules > 1 and ns.Plural(#list, L["%d person already matches your rules.|%d people already match your rules.##plural"])
            or ns.Plural(#list, L["%d person already matches this rule.|%d people already match this rule.##plural"]), FONT.body },
    }
    -- (a line per rule, the first few; tight, as one list)
    for i, rule in ipairs(rules) do
        if i > Sheet.RULES then
            parts[#parts + 1] = { ns.Plural(#rules - Sheet.RULES, L["and %d more rule|and %d more rules##plural"]), FONT.small, true }
            break
        end
        local n = count[rule]
        parts[#parts + 1] = { ns.Plural(n, L["%1$s: %2$d person|%1$s: %2$d people##plural"],
            Capital(ns.AutoAdd.Describe(rule)), n), FONT.small, true }
    end
    if parts[#parts][3] then parts[#parts][3] = nil end
    if named then parts[#parts + 1] = { named, FONT.strong } end
    parts[#parts + 1] = { L["Add them to the diary now? If not, each is added the next time you cross paths."], FONT.body }
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
    for i, l in ipairs(lines) do h = h + #l * SHEET.line + (parts[i][3] and 0 or SHEET.gap) end
    h = h + SHEET.foot + SHEET.line
    K.Reshape(W, h)
    K.Fall("autoadd")
    K.Lay()

    view.title:SetText(Title((Asking(view.list))))
    K.PlaceText(view.title, M, SHEET.title)
    local used, y = 0, SHEET.first
    for i, part in ipairs(parts) do
        local font = part[2]
        for _, line in ipairs(lines[i]) do
            used = used + 1
            local fs = view.texts[used] or Style.Text(view.sheet, font)
            view.texts[used] = fs
            fs:SetFontObject(font)
            local c = font == FONT.strong and Style.INK_STRONG or font == FONT.small and Style.INK_FADED or Style.INK
            fs:SetTextColor(c[1], c[2], c[3])
            fs:SetText(line)
            K.PlaceText(fs, M, y)
            fs:Show()
            y = y + SHEET.line
        end
        if not part[3] then y = y + SHEET.gap end
    end
    for i = used + 1, #view.texts do view.texts[i]:Hide() end

    view.add:PlaceAt(W - M, h - SHEET.foot, "RIGHT")
    view.later:PlaceAt(W - M - K.Width(view.add.label) - 18, h - SHEET.foot, "RIGHT")
    view.add:Show()
    view.later:Show()
end

-- Opens the sheet on `list` ({ guid, rule } pairs, as AutoAdd.Waiting gives them). An
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

-- The switch's `after`: on, and someone is waiting, the sheet asks (about
-- every rule that is on).
function Sheet.Offer(on)
    if not on then return false end
    return Sheet.Open(ns.AutoAdd.Waiting())
end

-- The rule sheet put away (UI/Settings/Rules.lua): asks about `rules`
-- (AutoAdd.AskAbout's), if anyone already passes one of them.
function Sheet.Ask(rules)
    if not (rules and #rules > 0) then return false end
    return Sheet.Open(ns.AutoAdd.Waiting(rules))
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
