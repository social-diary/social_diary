-- Suggest a better wording: the sheet a picked line opens on
-- (UI/Windows/Suggest/Lookup.lua says what the folder is). A loose sheet of
-- the house paper, over the game on a window of its own, as the quick note
-- is (UI/Paper/NoteSheet.lua): the line as the diary has it, its English
-- where the lookup found it, a line to write the better wording on, and,
-- once asked, the address of a GitHub issue with all of it filled in, to
-- copy (the client cannot open one: Style.CopyField, as Feedback's page).
-- Escape puts it away.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local L = ns.L

local Suggest = ns.UI.Suggest
local Sheet = {}
Suggest.Sheet = Sheet

-- The sheet in its own coordinates (x right, y down): `w` wide, `margin`
-- each side; the title's middle `title` down; each part a heading then its
-- lines, `line` apart, `gap` between parts; at most `most` lines of a text.
local SHEET = { w = 420, margin = 30, title = 34, first = 68, heading = 18, line = 16, gap = 16,
    write = 22, foot = 30, copy = 10, most = 3 }
Sheet.SHEET = SHEET
-- Folded once across, hardly crumpled; it lies straight (it holds a box
-- to write in).
local CREASE = {
    columns = { 0, 0.08, 0.92, 1 },
    rows = { 0, 0.08, 0.5, 0.92, 1 },
    folds = { columns = {}, rows = { [3] = -1 } },
    crumple = 0.4, drift = 0.3, edge = 0.5, wander = 0, shift = 2, lean = 1,
    curl = { lift = 4, pull = 2 },
}
local HOST = { w = SHEET.w + 60, h = 520 }
local ELLIPSIS = "\226\128\166"

local host, view, K

-- `text` in at most `most` lines of `width`: the last one cut short with an
-- ellipsis where there was more.
local function Lines(text, width, font, most)
    local lines = K.Wrap(text, width, font)
    if #lines > most then
        local rest = {}
        for i = most, #lines do rest[#rest + 1] = lines[i] end
        local last = table.concat(rest, " ")
        local cut = K.Wrap(last, width - 12, font)[1] or ""
        lines = { unpack(lines, 1, most - 1) }
        lines[most] = cut .. ELLIPSIS
    end
    return lines
end

local function Build()
    host = CreateFrame("Frame", "SocialDiarySuggestFrame", UIParent)
    host:SetSize(HOST.w, HOST.h)
    host:SetPoint("CENTER")
    host:SetFrameStrata("DIALOG")
    host:SetToplevel(true)
    host:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = "SocialDiarySuggestFrame"
    ns.UI.Scale.Register(host, HOST.w, HOST.h)

    view, K = ns.UI.LooseSheet(host, SHEET.w, 400, { crease = CREASE, straight = true })
    local S = view.sheet
    host:SetScript("OnHide", function() if view:IsShown() then view:Hide(true) end end)

    view.title = Style.Text(S, FONT.page)
    view.title:SetText(L["A better wording"])
    view.headings = {}
    for _, key in ipairs({ "shown", "english", "yours" }) do
        view.headings[key] = Style.Text(S, FONT.heading)
    end
    view.headings.shown:SetText(Style.Upper(L["As the diary has it"]))
    view.headings.english:SetText(Style.Upper(L["In English"]))
    view.headings.yours:SetText(Style.Upper(L["Your wording"]))
    view.texts = {}

    view.box = Style.WritingLine(S, SHEET.w - 2 * SHEET.margin, FONT.strong, L["How should it read?"])
    view.box:SetScript("OnEnterPressed", function() Sheet.Make() end)

    view.cancel = K.Link(FONT.body, function() Sheet.Close() end)
    view.cancel:SetText(L["Cancel"])
    view.make = K.Link(FONT.strong, function() Sheet.Make() end)
    view.make:SetText(L["Make the link"])

    view.copy = Style.CopyField(S, SHEET.w - 2 * SHEET.margin, "")
    view.copyHint = Style.Text(S, FONT.small)
    view.done = K.Link(FONT.strong, function() Sheet.Close() end)
    view.done:SetText(L["Done"])
end

-- A text's lines from the pool, laid from `y`; returns the y under them.
local used
local function Write(text, font, y, faded)
    local width = SHEET.w - 2 * SHEET.margin
    for _, line in ipairs(Lines(text, width, font, SHEET.most)) do
        used = used + 1
        local fs = view.texts[used] or Style.Text(view.sheet, font)
        view.texts[used] = fs
        fs:SetFontObject(font)
        local c = faded and Style.INK_FADED or (font == FONT.strong and Style.INK_STRONG or Style.INK)
        fs:SetTextColor(c[1], c[2], c[3])
        fs:SetText(line)
        K.PlaceText(fs, SHEET.margin, y)
        fs:Show()
        y = y + SHEET.line
    end
    return y
end

-- Lays everything out for what it holds (`view.picked`), the address too
-- once it is made.
local function Lay()
    local M, W = SHEET.margin, SHEET.w
    local p = view.picked
    -- First the size: the same walk, measuring only.
    local function Count(text, font) return #Lines(text, W - 2 * M, font, SHEET.most) end
    local english = p.english or L["The diary couldn’t find the English for this line. It goes as it is shown."]
    local h = SHEET.first
        + SHEET.heading + Count(p.shown, FONT.strong) * SHEET.line + SHEET.gap
        + SHEET.heading + Count(english, FONT.body) * SHEET.line + SHEET.gap
        + SHEET.heading + SHEET.write + SHEET.gap
        + (view.url and (view.copy.height + SHEET.copy + SHEET.line + SHEET.gap) or 0)
        + SHEET.foot
    K.Reshape(W, h)
    K.Fall("suggest")
    K.Lay()

    K.PlaceText(view.title, M, SHEET.title)
    used = 0
    local y = SHEET.first
    K.PlaceText(view.headings.shown, M, y)
    y = Write(p.shown, FONT.strong, y + SHEET.heading) + SHEET.gap - SHEET.line / 2
    K.PlaceText(view.headings.english, M, y)
    y = Write(english, FONT.body, y + SHEET.heading, p.english == nil) + SHEET.gap - SHEET.line / 2
    for i = used + 1, #view.texts do view.texts[i]:Hide() end
    K.PlaceText(view.headings.yours, M, y)
    y = y + SHEET.heading
    K.PlaceButton(view.box, M, y - 4, W - 2 * M, 20)
    y = y + SHEET.write + SHEET.gap

    view.copy:SetShown(view.url ~= nil)
    view.copyHint:SetShown(view.url ~= nil)
    view.done:SetShown(view.url ~= nil)
    view.make:SetShown(view.url == nil)
    view.cancel:SetShown(view.url == nil)
    if view.url then
        view.copy:SetValue(view.url)
        K.PlaceButton(view.copy, M, y - 8, W - 2 * M, view.copy.height)
        y = y + view.copy.height + SHEET.copy
        view.copyHint:SetText(L["Copy this link into your browser. It opens a GitHub issue with everything filled in."])
        K.PlaceText(view.copyHint, M, y)
        view.done:PlaceAt(W - M, h - SHEET.foot, "RIGHT")
    else
        view.make:PlaceAt(W - M, h - SHEET.foot, "RIGHT")
        view.cancel:PlaceAt(W - M - K.Width(view.make.label) - 18, h - SHEET.foot, "RIGHT")
    end
end

-- Opens the sheet on a picked line, as the diary showed it.
function Sheet.Open(text)
    if not host then Build() end
    local shown = Suggest.Clean(text)
    local found = Suggest.Lookup(shown)
    view.picked = { shown = shown, key = found and found.key, english = found and found.english,
        kind = found and found.kind }
    view.url = nil
    view.box:SetValue("")
    host:Show()
    host:Raise()
    view:Show()
    Lay()
    view.box:SetFocus()
end

-- The address made from what is written: the issue's form, filled in.
-- Nothing written yet, the cursor goes to the line instead.
function Sheet.Make()
    if not (host and view.picked) then return end
    local wording = Suggest.Clean(view.box:GetText())
    if wording == "" then
        view.box:SetFocus()
        return
    end
    view.box:ClearFocus()
    local p = view.picked
    view.url = Suggest.URL({ locale = ns.Locale.id, version = ns.version, key = p.key,
        english = p.english, current = p.shown, suggestion = wording })
    Lay()
    view.copy.box:SetFocus()
end

function Sheet.Close()
    if host and host:IsShown() then host:Hide() end
end

function Sheet.Shown() return host ~= nil and host:IsShown() end

-- The sheet's view, for the tests: nil until it first opened.
function Sheet.View() return view end
