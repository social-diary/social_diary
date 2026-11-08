-- Settings: Changelog, About's second subpage (UI/Settings/Page.lua lists
-- the sections; About is UI/Settings/Sections/About.lua): what changed in
-- the newest releases, as Core/ChangelogData.lua gives them (ns.Changelog,
-- written from CHANGELOG.md by Dev/changelog.lua), newest first.
--
-- Set as a page of the book's own: each release under its version in the
-- display hand, its summary in the written hand under it, then its groups'
-- small headings (Shiny new Things, Changes, Fixes) and their entries as
-- inked lozenges, a sub-entry indented under its entry with a smaller,
-- fainter one. A feature's name, written _like this_ in the changelog, is
-- set in the strong ink the book names features in. Someone thanked for an
-- entry is credited under it, in the red-brown of a note in the margin
-- ("Thanks to Name"): one line of the entry's own, so it reads as that
-- entry's and the pad's box holds both. Releases are parted by a long
-- double rule in rubric across the column, as a ledger closes an account.
-- At the foot: where the rest of the history is.
--
-- Five releases do not fit the page, so they are a smooth list
-- (ns.UI.VirtualList, scrolled by the pixel, the book's pencil and leather
-- scrollbar down its edge): the mouse wheel scrolls it, and the pad reads
-- down it line by line (the pane hands the settings' scope its lines,
-- `pane.padItems`, UI/Settings/Pad.lua), the list scrolled to each.
--
-- Turning to it counts as reading what a major update brought
-- (ns.Hints.UpdateRead: its notice is not laid after that).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings

local FOOTER = "The full history is on CurseForge and GitHub."
local THANKS = "Thanks to %s"

-- The column: the list's own width less its scrollbar, and the measures
-- each kind of line is set at. `pad` is the room above a line's words,
-- `after` below them (the thanks' line included); `indent` where its words
-- start, `bullet` where its lozenge sits (its centre, from the left) and
-- `size` how big it is. The divider: its rule `at` px down a line `height`
-- tall, the hairline under it `gap` px lower, their alphas.
local LIST_W = BOOK.RIGHT_W
local TEXT_W = LIST_W - ns.UI.SCROLLBAR_WIDTH - 6
local ROWS = 48
local LINE = {
    version = { font = FONT.personNameLeast, pad = 2, after = 2 },
    summary = { font = FONT.noteQuoted, pad = 2, after = 4 },
    group = { font = FONT.heading, pad = 10, after = 3 },
    entry = { font = FONT.body, pad = 3, after = 1, indent = 14, bullet = 5, size = 4, alpha = 0.85 },
    sub = { font = FONT.body, pad = 2, after = 1, indent = 30, bullet = 21, size = 3, alpha = 0.55 },
    footer = { font = FONT.faded, pad = 14, after = 4 },
}
local THANKS_FONT, THANKS_GAP = FONT.margin, 1
local DIVIDER = { height = 26, at = 12, gap = 3, alpha = 0.85, hair = 0.45 }

-- "_Your Diary_" in the strong ink, the underscores gone.
local function Emphasis(text)
    return (text:gsub("_([^_]+)_", "|cff" .. Style.HEX.strong .. "%1|r"))
end

--------------------------------------------------------------------------
-- The lines
--------------------------------------------------------------------------

-- How tall `text` comes out in `font`, wrapped to `width`: measured on a
-- string of the pane's that is never shown.
local measure
local function Measure(font, width, text)
    measure:SetFontObject(font)
    measure:SetWidth(width)
    measure:SetText(text)
    return measure:GetStringHeight()
end

-- One line of the list: its kind, words, and the height it takes (its
-- words, any thanks, and the room round them).
local function Line(kind, text, thanks)
    local L = LINE[kind]
    local line = { kind = kind, text = text, thanks = thanks and THANKS:format(thanks) or nil }
    local width = TEXT_W - (L.indent or 0)
    local height = L.pad + Measure(L.font, width, text) + L.after
    if line.thanks then height = height + THANKS_GAP + Measure(THANKS_FONT, width, line.thanks) end
    line.height = math.ceil(height)
    return line
end

-- The releases as the list's lines, newest first: a divider between each
-- two, the footer under the last. Exposed for the tests
-- (SettingsUI.ChangelogLines).
local function Lines(releases)
    local lines = {}
    local function Add(line) lines[#lines + 1] = line end
    for i, release in ipairs(releases or {}) do
        if i > 1 then Add({ kind = "divider", height = DIVIDER.height }) end
        Add(Line("version", "Version " .. release.version))
        if release.summary and release.summary ~= "" then Add(Line("summary", Emphasis(release.summary))) end
        for _, group in ipairs(release.groups or {}) do
            Add(Line("group", group.heading:upper()))
            for _, entry in ipairs(group.entries or {}) do
                Add(Line("entry", Emphasis(entry.text), entry.thanks))
                for _, sub in ipairs(entry.sub or {}) do
                    Add(Line("sub", Emphasis(sub.text), sub.thanks))
                end
            end
        end
    end
    if #lines > 0 then Add(Line("footer", FOOTER)) end
    return lines
end

--------------------------------------------------------------------------
-- The rows
--------------------------------------------------------------------------

local function BuildRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.text = Style.Text(row, FONT.body)
    row.text:SetWordWrap(true)
    row.thanks = Style.Text(row, THANKS_FONT)
    row.thanks:SetWordWrap(true)
    row.thanks:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -THANKS_GAP)
    row.bullet = Style.Lozenge(row, "ARTWORK", 4, Style.INK)
    -- (the group heading's rule, running on after it, as the kit's do)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.rule:SetPoint("LEFT", row.text, "RIGHT", 8, 0)
    local INK = Style.INK
    row.rule:SetColorTexture(INK[1], INK[2], INK[3], 0.25)
    -- (the divider: a rule in rubric, a hairline under it)
    local R = Style.RUBRIC
    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetHeight(1)
    row.divider:SetPoint("TOPLEFT", 0, -DIVIDER.at)
    row.divider:SetPoint("TOPRIGHT", 0, -DIVIDER.at)
    row.divider:SetColorTexture(R[1], R[2], R[3], DIVIDER.alpha)
    row.hairline = row:CreateTexture(nil, "ARTWORK")
    row.hairline:SetHeight(1)
    row.hairline:SetPoint("TOPLEFT", 0, -(DIVIDER.at + DIVIDER.gap))
    row.hairline:SetPoint("TOPRIGHT", 0, -(DIVIDER.at + DIVIDER.gap))
    row.hairline:SetColorTexture(R[1], R[2], R[3], DIVIDER.hair)
    return row
end

local function UpdateRow(row, line)
    local divider = line.kind == "divider"
    row.divider:SetShown(divider)
    row.hairline:SetShown(divider)
    row.text:SetShown(not divider)
    if divider then
        row.bullet:Hide()
        row.rule:Hide()
        row.thanks:Hide()
        return
    end
    local L = LINE[line.kind]
    local width = TEXT_W - (L.indent or 0)
    row.text:SetFontObject(L.font)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", L.indent or 0, -L.pad)
    row.text:SetWidth(width)
    row.text:SetText(line.text)

    row.bullet:SetShown(L.bullet ~= nil)
    if L.bullet then
        local INK = Style.INK
        row.bullet:SetSize(L.size, L.size)
        row.bullet:SetColorTexture(INK[1], INK[2], INK[3], L.alpha)
        row.bullet:ClearAllPoints()
        -- (on the first line's middle: half of the body face's 13 down)
        row.bullet:SetPoint("CENTER", row, "TOPLEFT", L.bullet, -(L.pad + 7))
    end

    local group = line.kind == "group"
    row.rule:SetShown(group)
    if group then row.rule:SetWidth(math.max(0, TEXT_W - row.text:GetStringWidth() - 8)) end

    row.thanks:SetShown(line.thanks ~= nil)
    if line.thanks then
        row.thanks:SetWidth(width)
        row.thanks:SetText(line.thanks)
    end
end

--------------------------------------------------------------------------
-- The pad: a line at a time
--------------------------------------------------------------------------

-- What the pad reads: every line with words of its own but a group's
-- heading (the entries under it say what it holds).
local READ = { version = true, summary = true, entry = true, sub = true, footer = true }

local function PadItems(pane, list)
    return function(add)
        for index, line in ipairs(list.data or {}) do
            if READ[line.kind] then
                local item = { key = "changelog:" .. index, kind = "read", index = index, clip = list }
                item.available = function() return pane:IsShown() end
                -- (scrolled into view as the pad lands; its words, and its
                -- lozenge and thanks for the box to hold, found on its row)
                item.reveal = function()
                    list:Reveal(index)
                    local row = list:RowOf(index)
                    item.frame = row
                    item.words = row and row.text or nil
                    local holds = {}
                    if row and row.bullet:IsShown() then holds[#holds + 1] = row.bullet end
                    if row and row.thanks:IsShown() then holds[#holds + 1] = row.thanks end
                    item.encloses = #holds > 0 and holds or nil
                end
                item.enter = function() end
                item.leave = function() end
                item.press = function() end
                add(item)
            end
        end
    end
end

--------------------------------------------------------------------------
-- The pane
--------------------------------------------------------------------------

local function BuildChangelog(pane, c)
    local page = SettingsUI.page
    measure = measure or Style.Text(pane, FONT.body)
    measure:Hide()

    local height = math.floor(BOOK.RIGHT_H + c.y)
    local list = ns.UI.Journal.List(pane, 20, ROWS, BuildRow, UpdateRow, LIST_W)
    list:SetSmooth(height)
    c:Place(list, height, 0, 0)
    list:SetData(Lines(ns.Changelog))
    page.changelog = list
    pane.padItems = PadItems(pane, list)
end

SettingsUI.ChangelogLines = Lines

SettingsUI.RegisterSection("changelog", { order = 57, label = "Changelog", parent = "about",
    about = "What changed in the latest versions", build = BuildChangelog,
    open = function()
        if ns.Hints and ns.Hints.UpdateRead then ns.Hints.UpdateRead() end
        local list = SettingsUI.page and SettingsUI.page.changelog
        if list then list:SetPosition(0) end
    end })
