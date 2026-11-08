-- Settings: Changelog, About's second subpage (UI/Settings/Page.lua lists
-- the sections; About is UI/Settings/Sections/About.lua): what changed in
-- the newest releases, as Core/ChangelogData.lua gives them (ns.Changelog,
-- written from CHANGELOG.md by Dev/changelog.lua), newest first.
--
-- Set as a page of the book's own: each release under its version in the
-- display hand, its summary in the written hand under it as the lead, then
-- its groups (Shiny new Things, Changes, Fixes), rubricated as the
-- timeline's days are (a paraph, red capitals a size up, a red rule fading
-- out): the anchors the eye scans the page by. Their entries hang under
-- them as inked lozenges, the heading's words and the entries' on one
-- indent with the ornaments in the gutter; a sub-entry indented under its
-- entry with a smaller, fainter one. One spacing scale (SPACE) sets the
-- rhythm: tight inside a release, generous between releases. A feature's name, written _like this_ in the changelog, is
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

-- The column: the list's own width less its scrollbar.
local LIST_W = BOOK.RIGHT_W
local TEXT_W = LIST_W - ns.UI.SCROLLBAR_WIDTH - 6
local ROWS = 48

-- The page's rhythm, one scale for all of it, each step clearly wider than
-- the one under it: a wrapped line's leading, then between entries, between
-- a group and the release's head or the group before it, and between
-- releases (the divider's air, above its rule and below its hairline).
-- Tight inside a release, generous between them, so each reads as a whole.
local SPACE = { leading = 2, sub = 4, lead = 5, entry = 6, group = 14, release = 18 }

-- The hanging column: every line's words in a release (a group's heading
-- and its entries) start at one indent, `HANG`, and their ornaments hang
-- in the gutter left of it, a group's paraph over its entries' lozenges.
-- The version and its summary stand out at the margin, the head of what
-- hangs under them.
local HANG = 14

-- Each kind of line: its font, `pad` the room above its words and `after`
-- below them (a thanks included), so two lines' `after` + `pad` is a step
-- of SPACE; `indent` where its words start, `bullet` where its ornament
-- sits (its centre, from the left), `size` how big it is, `mid` how far
-- down its first line's middle is from its words' top, `leading` between
-- its wrapped lines.
local LINE = {
    version = { font = FONT.personNameLeast, pad = 0, after = 2 },
    summary = { font = FONT.noteQuoted, pad = SPACE.lead - 2, after = 3, leading = SPACE.leading },
    group = { font = FONT.headingRubricLarge, pad = SPACE.group - 3, after = 3, indent = HANG,
        bullet = 5, size = 6, mid = 6, paraph = true },
    entry = { font = FONT.body, pad = SPACE.entry - 3, after = 3, indent = HANG, bullet = 5, size = 4,
        mid = 7, alpha = 0.85, leading = SPACE.leading },
    sub = { font = FONT.body, pad = SPACE.sub - 3, after = 3, indent = HANG + 16, bullet = HANG + 7,
        size = 3, mid = 7, alpha = 0.55, leading = SPACE.leading },
    footer = { font = FONT.faded, pad = SPACE.release + 2, after = 4 },
}
local THANKS_FONT, THANKS_GAP = FONT.margin, SPACE.leading
-- A group's rule runs on after its words, rubric fading out to the edge,
-- as the timeline's day headings do.
local GROUP_RULE = { gap = 7, alpha = 0.45 }
-- The divider: SPACE.release of air above its rule (the last entry's
-- `after` and `at`), the hairline `gap` px under it, and SPACE.release
-- under the hairline before the next version; their alphas.
local DIVIDER = { at = SPACE.release - 3, gap = 3, alpha = 0.85, hair = 0.45 }
DIVIDER.height = DIVIDER.at + DIVIDER.gap + 1 + SPACE.release

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
local function Measure(font, width, text, leading)
    measure:SetFontObject(font)
    measure:SetSpacing(leading or 0)
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
    local height = L.pad + Measure(L.font, width, text, L.leading) + L.after
    if line.thanks then
        height = height + THANKS_GAP + Measure(THANKS_FONT, width, line.thanks, SPACE.leading)
    end
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
        for g, group in ipairs(release.groups or {}) do
            -- (its paraph red, then lapis, by turns, as the timeline's days)
            local heading = Line("group", group.heading:upper())
            heading.lapis = g % 2 == 0
            Add(heading)
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
    row.thanks:SetSpacing(SPACE.leading)
    row.thanks:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -THANKS_GAP)
    row.bullet = Style.Lozenge(row, "ARTWORK", 4, Style.INK)
    -- (the group heading's rule, running on after it in rubric, fading)
    local R = Style.RUBRIC
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    Style.Shade(row.rule, "HORIZONTAL", R[1], R[2], R[3], GROUP_RULE.alpha, 0)
    -- (the divider: a rule in rubric, a hairline under it)
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
    row.text:SetSpacing(L.leading or 0)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", L.indent or 0, -L.pad)
    row.text:SetWidth(width)
    row.text:SetText(line.text)

    row.bullet:SetShown(L.bullet ~= nil)
    if L.bullet then
        -- (an entry's lozenge in ink; a group's paraph in rubric or lapis)
        local colour = L.paraph and (line.lapis and Style.LAPIS or Style.RUBRIC) or Style.INK
        row.bullet:SetSize(L.size, L.size)
        row.bullet:SetColorTexture(colour[1], colour[2], colour[3], L.alpha or 1)
        row.bullet:ClearAllPoints()
        -- (on the first line's middle)
        row.bullet:SetPoint("CENTER", row, "TOPLEFT", L.bullet, -(L.pad + L.mid))
    end

    local group = line.kind == "group"
    row.rule:SetShown(group)
    if group then
        -- (from just after its words, not the string's end: the string is
        -- the column's width, so its RIGHT is the column's edge)
        local from = L.indent + row.text:GetStringWidth() + GROUP_RULE.gap
        row.rule:ClearAllPoints()
        row.rule:SetPoint("LEFT", row, "TOPLEFT", from, -(L.pad + L.mid))
        row.rule:SetWidth(math.max(0, TEXT_W - from))
    end

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
