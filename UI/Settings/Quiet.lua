-- The quiet-nearby list (ns.UI.Settings.Quiet): the people from the diary
-- who get no toast when they come into view, searched and ticked on the
-- Toasts subpage (UI/Settings/Sections/Toasts.lua builds it there with
-- Quiet.Build). UI/Settings/Page.lua reads it again with the page
-- (Quiet.Refresh).

local addonName, ns = ...

local Style = ns.Style
local L, Fmt = ns.L, ns.Fmt
local FONT = Style.FONT
local INK = Style.INK
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings

local ROW_HEIGHT = Style.ROW_HEIGHT
local MIN_QUIET_ROWS = 4

-- What the search holds (Style.SearchInto writes it).
local quiet = { search = "" }

--------------------------------------------------------------------------
-- Quiet nearby
--------------------------------------------------------------------------
--
-- The people from the diary who get no toast when they come into view
-- (ns.Diary.IsQuietNearby). With the search empty the list is everyone
-- marked; typing searches the whole diary by name and tag, to mark more.
-- A row unticked stays where it is until the list is next built, so a slip
-- can be ticked back.

local function Lower(text)
    return (text or ""):lower()
end

local function QuietQuery(search)
    search = Lower(search):gsub("^%s+", ""):gsub("%s+$", "")
    local list = {}

    for guid, entry in ns.Diary.Each() do
        local name = ns.Characters.FullName(guid) or guid
        local match
        if search == "" then
            match = entry.quietNearby == true
        else
            match = Lower(name):find(search, 1, true) ~= nil
            for i = 1, #entry.tags do
                if match then break end
                match = entry.tags[i]:find(search, 1, true) ~= nil
            end
        end
        if match then
            list[#list + 1] = {
                guid = guid,
                name = name,
                record = ns.Characters.Get(guid),
                tags = table.concat(entry.tags, ", "),
            }
        end
    end

    table.sort(list, function(a, b)
        if a.name ~= b.name then return Lower(a.name) < Lower(b.name) end
        return a.guid < b.guid
    end)
    return list
end

local function QuietCount()
    local n = 0
    for guid in ns.Diary.Each() do
        if ns.Diary.IsQuietNearby(guid) then n = n + 1 end
    end
    return n
end

local function RefreshQuietCount()
    local page = SettingsUI.page
    page.quietCount:SetText(Fmt(L["%d quiet"], QuietCount()))
end

local function UpdateQuietRow(row, item)
    local quiet = ns.Diary.IsQuietNearby(item.guid)
    row.tick:SetChecked(quiet)
    row.name:SetText(item.name)
    row.name:SetFontObject(quiet and FONT.strong or FONT.body)
    row.tags:SetText(item.tags)
    Style.ClassIconOrInk(row.icon, item.record and item.record.class)
end

local function BuildQuietRow(list)
    local row = CreateFrame("Button", nil, list)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(INK[1], INK[2], INK[3], Style.HOVER_ALPHA)

    row.tick = Style.Tick(row)
    row.tick:SetPoint("LEFT", 6, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row.tick, "RIGHT", 9, 0)

    row.name = Style.Text(row, FONT.body)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -150, 0)
    row.name:SetWordWrap(false)

    row.tags = Style.Text(row, FONT.small)
    row.tags:SetPoint("RIGHT", -6, 0)
    row.tags:SetWidth(140)
    row.tags:SetJustifyH("RIGHT")
    row.tags:SetWordWrap(false)

    row:SetScript("OnEnter", function(self) self.tick:SetHot(true) end)
    row:SetScript("OnLeave", function(self) self.tick:SetHot(false) end)
    row:SetScript("OnClick", function(self)
        if not self.item then return end
        ns.Diary.SetQuietNearby(self.item.guid, not ns.Diary.IsQuietNearby(self.item.guid))
        UpdateQuietRow(self, self.item)
        RefreshQuietCount()
    end)

    return row
end

local function RefreshQuiet(keepScroll)
    local page = SettingsUI.page
    local list = QuietQuery(quiet.search)
    page.quiet:SetData(list, keepScroll)
    RefreshQuietCount()

    local empty = ""
    if #list == 0 then
        if ns.Diary.Count() == 0 then
            empty = L["Nobody in the diary yet."]
        elseif quiet.search:find("%S") then
            empty = L["Nobody in the diary matches."]
        else
            empty = L["Nobody yet. Search your diary above to choose who."]
        end
    end
    page.quietEmpty:SetText(empty)
end

-- The list, under Toasts' heading and hint in column `c`: the search, the
-- count, the list taking what room is left, and what it says when empty.
local function Build(pane, c)
    local page = SettingsUI.page
    page.quietSearch = Style.PageSearch(pane, 0, c.y, 236, L["Search your diary"],
        Style.SearchInto(quiet, RefreshQuiet))
    page.quietCount = Style.Text(pane, FONT.small)
    page.quietCount:SetPoint("RIGHT", pane, "TOPRIGHT", 0, c.y - 12)
    page.quietCount:SetJustifyH("RIGHT")
    c.y = c.y - 24 - 8

    local rows = math.max(MIN_QUIET_ROWS, math.floor((BOOK.RIGHT_H + c.y) / ROW_HEIGHT))
    page.quiet = ns.UI.Journal.List(pane, ROW_HEIGHT, rows, BuildQuietRow, UpdateQuietRow, BOOK.RIGHT_W)
    c:Place(page.quiet, ROW_HEIGHT * rows)

    page.quietEmpty = Style.Text(pane, FONT.faded)
    page.quietEmpty:SetPoint("TOPLEFT", page.quiet, "TOPLEFT", 4, -6)
    page.quietEmpty:SetWidth(BOOK.RIGHT_W - 8)
end

SettingsUI.Quiet = { Build = Build, Refresh = RefreshQuiet }
