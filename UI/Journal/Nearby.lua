-- The Recently nearby page (JNL-3): the journal's purple ribbon.
--
-- For scanning who was around and picking people to add, not for reading
-- about them. The left page lists the days with sightings; the right page is
-- a table of everyone seen on the chosen day. A stranger gets one row and a
-- tooltip, nothing more: their story starts on the People page once they are
-- added. So + Add stays on this page and marks the row, and you can go down
-- the list adding several.
--
-- Built from the raw sightings (the last bufferDays days) and the
-- interaction buffer, for the "dealt with" marks, by ns.Sightings.DayEntries
-- and QueryDay (Core/Sightings.lua). Nothing is stored here.
-- Sightings never run inside instances (SIG-6); dungeon groups join this
-- page once instance visits (INS-1, INS-2) record their members.

local addonName, ns = ...

local Format = ns.UI.Format
local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local INK, INK_STRONG = Style.INK, Style.INK_STRONG
local DAY = ns.DAY

local BOOK = ns.UI.Journal.BOOK
local J = ns.UI.Journal

local ROW_HEIGHT = Style.ROW_HEIGHT
local DAYS_TOP = 84
local DAY_ROWS = math.floor((BOOK.BOOK_H - DAYS_TOP - 14) / ROW_HEIGHT)
local TABLE_TOP = 100
local TABLE_ROWS = math.floor((BOOK.RIGHT_H - TABLE_TOP) / ROW_HEIGHT)
local QUIET = 5     -- a day with fewer people than this reads as quiet
local BAR_MAX = 60  -- the busiest day's bar, in pixels

-- Table columns, in row coordinates. A row stops short of the scrollbar, and
-- the headings use the same numbers so they line up. Left to right: class,
-- level, the name and its marks, zone, subzone, and + Add / Open / Added.
local ROW_W = BOOK.RIGHT_W - ns.UI.SCROLLBAR_WIDTH - 2
local GAP = 8
local LEVEL_RIGHT = 40  -- two figures, after the 16 px class icon
local NAME_X = 48
local NAME_W = 128      -- a name and surname with a mark and ×N beside it
local NAME_RIGHT = NAME_X + NAME_W
local ACTION_W = 54     -- "Added" and its feather
-- Zone and subzone share the rest evenly, about 14 letters each: enough for
-- "Elwynn Forest" or "The Crossroads"; "Hillsbrad Foothills" trails off.
local ZONE_X = NAME_RIGHT + GAP
local PLACE_W = math.floor((ROW_W - 4 - ACTION_W - GAP - ZONE_X - GAP) / 2)
local SUBZONE_X = ZONE_X + PLACE_W + GAP
local MARK = 12

local page
local selectedDay
local query = { search = "", filter = "everyone", sort = "last", dir = -1 }

-- The chosen day's people, built once per refresh of the page: search,
-- filter and sort only re-query them. { day, list }.
local cache

-- Added from this page this login: their row says "Added" instead of
-- offering Open, so a run of adds reads as done.
local addedHere = {}

local FILTERS = {
    { key = "everyone", label = L["Everyone"] },
    { key = "dealt", label = L["Dealt with"] },
    { key = "before", label = L["Seen before"] },
    { key = "hostile", label = L["Hostile"] },
}

-- The "dealt with" marks (ns.Sightings.DayEntries works out which one;
-- Core/Rows.lua's Rows.DEALT lists them).
local DEALT_TEXT = { together = L["Grouped with you"], trade = L["Traded with you"], talk = L["Talked with you"] }

-- The first click on a heading sorts the way people expect for that column;
-- the second reverses it; the third goes back to the latest seen first.
local FIRST_DIR = { name = 1, zone = 1, subzone = 1, level = -1 }

--------------------------------------------------------------------------
-- Days
--------------------------------------------------------------------------

local DayStart = ns.DayStart

local function DaysAgo(start, now)
    return math.floor((DayStart(now) - start) / DAY + 0.5)
end

-- Counted from day starts rather than ns.UI.Format.DayLabel's calendar dates, so
-- the same rounding decides "Yesterday" here and the week below.
local RECENT = { [0] = L["Today"], [1] = L["Yesterday"] }

-- "Monday 6 October": no comma and no year, as this page has always shown
-- them. The journal's headings (ns.UI.Format.DayLabel) have both.
local function Dated(start)
    return Fmt(L["%1$s %2$s##weekday"], Format.Weekday(start), Format.DayMonth(start))
end

local function DayLabel(start, now)
    return RECENT[DaysAgo(start, now)] or Dated(start)
end

-- The right page's heading and the line beside it.
local function DayTitle(start, now)
    local recent = RECENT[DaysAgo(start, now)]
    if recent then return recent, Dated(start) end
    return Format.Weekday(start), Format.DayMonth(start)
end

-- Weeks start on Monday.
local function Week(start, now)
    local weekday = (date("*t", now).wday + 5) % 7
    local ago = DaysAgo(start, now)
    if ago <= weekday then return L["This week"] end
    if ago <= weekday + 7 then return L["Last week"] end
    return L["Earlier"]
end

--------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------

local function BuildDayRow(list)
    local row = Style.GroupedRow(list, function(row)
        row.label = Style.Text(row, FONT.body)
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetWordWrap(false)

        row.count = Style.Text(row, FONT.small)
        row.count:SetPoint("RIGHT", -6, 0)
        row.count:SetJustifyH("RIGHT")

        -- How busy the day was, against the busiest one.
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetHeight(4)
        row.bar:SetPoint("RIGHT", row, "RIGHT", -36, 0)
        row.bar:SetColorTexture(INK[1], INK[2], INK[3], 0.16)

        return { row.label, row.count, row.bar }
    end)

    row:SetScript("OnClick", function(self)
        if self.item and self.item.start then
            selectedDay = self.item.start
            ns.UI.RefreshNearbyPage()
        end
    end)

    return row
end

local function UpdateDayRow(row, item)
    if row:SetHeading(item) then return end

    local isSelected = item.start == selectedDay
    row.label:SetText(item.label)
    row.label:SetFontObject(isSelected and FONT.strong or (item.count < QUIET and FONT.faded or FONT.body))
    row.count:SetText(item.count)
    row.bar:SetWidth(math.max(1, math.floor(BAR_MAX * item.count / math.max(item.max, 1) + 0.5)))
    row.selected:SetShown(isSelected)
end

-- Where they were seen, in full for the tooltip: "Goldshire, Elwynn Forest",
-- as Your Diary and the profile write a place. DayEntries has already
-- dropped a subzone named like its zone; "?" is a zone it could not name.
local function Place(e)
    if not e.subZone then return e.zone end
    if e.zone == "?" then return e.subZone end
    return Fmt(L["%1$s, %2$s"], e.subZone, e.zone)
end

-- The tooltip's lines: all the detail a stranger gets.
local function TooltipLines(row)
    local e = row.item
    if not e then return nil end
    local record = e.record

    local lines = {}
    if e.hostile then
        lines[1] = { e.name, 1, 0.13, 0.13 }
    else
        lines[1] = { e.name, 1, 1, 1 }
    end

    local who = {}
    if e.level then who[#who + 1] = Fmt(L["Level %d"], e.level) end
    who[#who + 1] = Format.RaceName(record)
    who[#who + 1] = Format.ClassName(record)
    local line = table.concat(who, " ")
    if record.faction then
        local faction = record.faction == "Horde" and L["Horde"] or record.faction == "Alliance" and L["Alliance"]
            or record.faction
        line = line .. "  ·  " .. faction
    end
    lines[#lines + 1] = { line, 1, 1, 1 }

    local now = ns.Now()
    if e.days > 1 then
        lines[#lines + 1] = { Fmt(L["Seen on %1$d days since %2$s"], e.days, Format.DayMonth(e.first, ns.Now())), 1, 0.82, 0 }
    end
    if e.firstLevel and e.level and e.firstLevel < e.level then
        lines[#lines + 1] = { Fmt(L["Level %d when you first saw them"], e.firstLevel), 0.66, 0.66, 0.66 }
    end
    if e.dealt and DEALT_TEXT[e.dealt] then
        lines[#lines + 1] = { Fmt(L["%1$s at %2$s##time"], DEALT_TEXT[e.dealt], date("%H:%M", e.dealtAt)), 1, 0.82, 0 }
    end
    -- Worded as the profile's line will be once they are added.
    local place = Place(e)
    local seen = place ~= "?" and Fmt(L["Last seen %1$s in %2$s"], Format.At(e.last, now), place)
        or Fmt(L["Last seen %s"], Format.At(e.last, now))
    lines[#lines + 1] = { seen, 0.66, 0.66, 0.66 }
    if ns.Diary.IsDiary(e.guid) then lines[#lines + 1] = { L["In your diary"], 1, 0.82, 0 } end
    return lines
end

local function AddFromRow(row)
    local e = row.item
    if not e then return end

    -- Where they were seen, not where the user is now.
    local entry, added = ns.Diary.Add(e.guid, {
        source = "nearby",
        where = { zone = e.zone, subZone = e.subZone, mapID = e.row.mapID, x = e.row.x, y = e.row.y },
    })
    if not entry then
        ns.Print(L["could not identify that character."])
        return
    end
    if added then Style.PlaySound("write") end
    addedHere[e.guid] = true
    page.table:Refresh()
end

local function BuildEntryRow(list)
    local row = CreateFrame("Button", nil, list)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(INK[1], INK[2], INK[3], 0.045)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(INK[1], INK[2], INK[3], Style.HOVER_ALPHA)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)

    row.name = Style.Text(row, FONT.body)
    row.name:SetPoint("LEFT", NAME_X, 0)
    row.name:SetWordWrap(false)

    -- After the name: the strongest thing you did together, hostile, ×N.
    row.dealt = row:CreateTexture(nil, "ARTWORK")
    row.dealt:SetSize(MARK, MARK)
    row.hostile = row:CreateTexture(nil, "ARTWORK")
    row.hostile:SetSize(MARK, MARK)
    row.times = Style.Text(row, FONT.small)

    row.level = Style.Text(row, FONT.body)
    row.level:SetPoint("RIGHT", row, "LEFT", LEVEL_RIGHT, 0)
    row.level:SetJustifyH("RIGHT")

    -- A fixed width without wrapping: a long name ends in an ellipsis.
    row.zone = Style.Text(row, FONT.body)
    row.zone:SetPoint("LEFT", ZONE_X, 0)
    row.zone:SetWidth(PLACE_W)
    row.zone:SetWordWrap(false)

    row.subZone = Style.Text(row, FONT.body)
    row.subZone:SetPoint("LEFT", SUBZONE_X, 0)
    row.subZone:SetWidth(PLACE_W)
    row.subZone:SetWordWrap(false)

    row.add = Style.Link(row, FONT.small, function() AddFromRow(row) end)
    row.add:SetText(L["+ Add"])
    row.add:SetPoint("RIGHT", -4, 0)

    local function OpenProfile()
        if row.item then ns.UI.ShowJournal(row.item.guid) end
    end

    row.open = Style.Link(row, FONT.small, OpenProfile)
    row.open:SetText(L["Open"])
    row.open:SetPoint("RIGHT", -4, 0)

    -- Just added: says so in faded ink, and still opens their new profile.
    row.added = Style.Link(row, FONT.small, OpenProfile)
    row.added:SetText(L["Added"])
    row.added:SetColor(Style.INK_FADED[1], Style.INK_FADED[2], Style.INK_FADED[3])
    row.added:SetPoint("RIGHT", -4, 0)

    row.feather = row:CreateTexture(nil, "ARTWORK")
    row.feather:SetSize(14, 14)

    Style.Tooltip(row, TooltipLines)

    return row
end

local function UpdateEntryRow(row, e)
    -- Rows are a fixed pool, so the stripe follows the data, not the frame.
    row.stripe:SetShown(e.index % 2 == 0)

    Style.ClassIconOrInk(row.icon, e.record.class)

    -- Marks first, so the name knows how much room is left.
    local marks = {}
    row.dealt:SetShown(e.dealt ~= nil and Style.SetTexture(row.dealt, e.dealt))
    if row.dealt:IsShown() then marks[#marks + 1] = row.dealt end
    row.hostile:SetShown(e.hostile and Style.SetTexture(row.hostile, "hostile"))
    if row.hostile:IsShown() then
        row.hostile:SetTexCoord(unpack(Style.ICON_CROP))
        marks[#marks + 1] = row.hostile
    end
    row.times:SetText(e.days > 1 and ("×" .. e.days) or "")
    row.times:SetShown(e.days > 1)

    local marksWidth = 0
    for _ = 1, #marks do marksWidth = marksWidth + MARK + 4 end
    if e.days > 1 then marksWidth = marksWidth + row.times:GetStringWidth() + 4 end

    row.name:SetText(e.name)
    local room = NAME_RIGHT - NAME_X - marksWidth
    row.name:SetWidth(math.max(20, math.min(row.name:GetUnboundedStringWidth() + 2, room)))

    local anchor = row.name
    for i = 1, #marks do
        marks[i]:ClearAllPoints()
        marks[i]:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
        anchor = marks[i]
    end
    row.times:ClearAllPoints()
    row.times:SetPoint("LEFT", anchor, "RIGHT", 4, 0)

    row.level:SetText(e.level or "")
    row.zone:SetText(e.zone)
    -- Blank without one: the zone beside it already says where.
    row.subZone:SetText(e.subZone or "")

    local inDiary = ns.Diary.IsDiary(e.guid)
    local justAdded = inDiary and addedHere[e.guid]
    row.add:SetShown(not inDiary)
    row.open:SetShown(inDiary and not justAdded)
    row.added:SetShown(justAdded == true)

    row.feather:ClearAllPoints()
    if inDiary and Style.SetTexture(row.feather, "added") then
        row.feather:SetTexCoord(unpack(Style.ICON_CROP))
        row.feather:SetPoint("RIGHT", justAdded and row.added or row.open, "LEFT", -4, 0)
        row.feather:Show()
    else
        row.feather:Hide()
    end
end

--------------------------------------------------------------------------
-- Refreshing
--------------------------------------------------------------------------

local RefreshTable

local function FilterLabel()
    local f = J.ByKey(FILTERS, query.filter)
    return f and f.label or L["Everyone"]
end

-- The filter's menu's generator, the mouse's and the pad's
-- (UI/Journal/NearbyPad.lua) alike.
local function FilterMenu()
    return Style.ChoiceGenerator(nil, FILTERS, function() return query.filter end, function(key)
        query.filter = key
        RefreshTable()
    end)
end

local function ShowFilterMenu(owner)
    MenuUtil.CreateContextMenu(owner, FilterMenu())
end

local function PaintHeadings()
    for key, heading in pairs(page.headings) do
        heading:SetCurrent(query.sort == key)
    end

    local arrow = page.arrow
    local current = page.headings[query.sort]
    if not current or not Style.SetTexture(arrow, "sortArrow") then
        arrow:Hide()
        return
    end
    arrow:ClearAllPoints()
    -- Outside a right-aligned heading would be over the next column.
    if current.alignRight then
        arrow:SetPoint("RIGHT", current, "LEFT", -2, 0)
    else
        arrow:SetPoint("LEFT", current, "RIGHT", 2, 0)
    end
    -- The texture points down; flipped for ascending.
    if query.dir > 0 then arrow:SetTexCoord(0, 0.5625, 1, 0) else arrow:SetTexCoord(0, 0.5625, 0, 1) end
    arrow:SetVertexColor(INK_STRONG[1], INK_STRONG[2], INK_STRONG[3], 1)
    arrow:Show()
end

local function SortBy(key)
    local first = FIRST_DIR[key]
    if query.sort ~= key then
        query.sort, query.dir = key, first
    elseif query.dir == first then
        query.dir = -first
    else
        query.sort, query.dir = "last", -1
    end
    RefreshTable()
end

local function EmptyText()
    local text = L["Nobody yet."]
    if not ns.Setting("detectSightings") then
        return text .. "\n\n" .. Fmt(L["Sightings are switched off. Turn them back on in the settings, under %1$s: %2$s."],
            L["Recording"], "|cffffd100" .. L["Notice who passes you in the open world"] .. "|r")
    end
    text = text .. "\n\n" .. L["Sightings pause in cities and dungeons."]
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if get and ns.Plain(get("nameplateShowFriends")) == "0" then
        text = text .. "\n\n" .. L["Friendly nameplates are off, so only people you target, mouse over or hear in /say are listed."]
    end
    return text
end

-- The table only, from the cached day: for search, filter and sort.
function RefreshTable(keepScroll)
    if not cache then return end
    local entries = cache.list
    local list = ns.Sightings.QueryDay(entries, query)
    for i = 1, #list do list[i].index = i end
    page.table:SetData(list, keepScroll)

    page.count:SetText(#list == #entries and Format.Count(#entries, L["person"], L["people"])
        or Fmt(L["%1$d of %2$d"], #list, #entries))
    page.empty:SetText(#list == 0 and L["Nobody matches."] or "")
    page.filter:SetText(FilterLabel())
    PaintHeadings()
    -- (the pad's rows were handed round: UI/Journal/NearbyPad.lua)
    ns.UI.Pad.Refresh()
end

-- Everything: the days, and the chosen day's people rebuilt from the data.
function ns.UI.RefreshNearbyPage()
    if not page or not ns.UI.JournalShowing("nearby") then return end
    local now = ns.Now()

    local days = ns.Sightings.Days()
    local max, found = 0, false
    for _, d in ipairs(days) do
        if d.count > max then max = d.count end
        if d.start == selectedDay then found = true end
    end
    if not found then selectedDay = days[1] and days[1].start or nil end

    local items, heading = {}, nil
    for _, d in ipairs(days) do
        local week = Week(d.start, now)
        if week ~= heading then
            items[#items + 1] = { header = week }
            heading = week
        end
        items[#items + 1] = { start = d.start, count = d.count, max = max, label = DayLabel(d.start, now) }
    end
    page.days:SetData(items, true)

    page.hint:SetText(Fmt(L["Everyone you passed in the open world. Kept for %d days."], ns.BufferDays()))
    page.dayCount:SetText(Format.Count(#days, L["day##count"], L["days##count"]))
    page.noDays:SetText(#days == 0 and EmptyText() or "")
    page.right:SetShown(selectedDay ~= nil)
    if not selectedDay then
        cache = nil
        ns.UI.Pad.Refresh()
        return
    end

    local sameDay = cache and cache.day == selectedDay
    cache = { day = selectedDay, list = ns.Sightings.DayEntries(selectedDay) }

    local title, sub = DayTitle(selectedDay, now)
    page.title:SetText(Style.Upper(title))
    page.date:SetText(sub)
    RefreshTable(sameDay)
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

local function BuildPage(parent)
    page = {}

    -- Left page: the days.
    page.dayCount, page.heading = J.PageHeading(parent, L["Recently nearby"])

    page.hint = Style.Text(parent, FONT.small)
    page.hint:SetPoint("TOPLEFT", BOOK.LEFT_X, -50)
    page.hint:SetWidth(BOOK.LEFT_W)

    page.days = J.List(parent, ROW_HEIGHT, DAY_ROWS, BuildDayRow, UpdateDayRow,
        BOOK.LEFT_W + 20, "TOPLEFT", BOOK.LEFT_X - 6, -DAYS_TOP)

    page.noDays = Style.Text(parent, FONT.faded)
    page.noDays:SetPoint("TOPLEFT", BOOK.LEFT_X, -DAYS_TOP - 6)
    page.noDays:SetWidth(BOOK.LEFT_W)

    -- Right page: the table.
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", BOOK.RIGHT_X, -BOOK.TOP)
    r:SetSize(BOOK.RIGHT_W, BOOK.RIGHT_H)
    page.right = r

    page.title = Style.Text(r, FONT.title)
    page.title:SetPoint("TOPLEFT", 0, 0)
    page.title:SetHeight(28)

    page.date = Style.Text(r, FONT.faded)
    page.date:SetPoint("BOTTOMLEFT", page.title, "BOTTOMRIGHT", 10, 5)

    page.count = Style.Text(r, FONT.small)
    page.count:SetPoint("TOPRIGHT", 0, -10)
    page.count:SetJustifyH("RIGHT")

    page.search = Style.PageSearch(r, 0, -40, 260, L["Search names, zones, subzones"],
        Style.SearchInto(query, RefreshTable))
    -- (`padAt`: where each control lies on the right page, y down, for the
    -- pad's left and right between them: UI/Journal/NearbyPad.lua)
    page.search.holder.padAt = { 130, 52 }

    page.filter = Style.Link(r, FONT.body, function(self) ShowFilterMenu(self) end)
    page.filter:SetPoint("RIGHT", r, "TOPRIGHT", 0, -52)
    page.filter.padAt = { BOOK.RIGHT_W - 30, 52 }

    -- Column headings, on the rows' own coordinates.
    page.headings = {}
    local function Heading(key, text, x)
        local link = Style.Link(r, FONT.heading, function() SortBy(key) end)
        link:SetText(Style.Upper(text))
        link.padAt = { x, 86 }
        page.headings[key] = link
        return link
    end
    Heading("level", L["Lvl"], LEVEL_RIGHT - 10):SetPoint("RIGHT", r, "TOPLEFT", LEVEL_RIGHT, -86)
    page.headings.level.alignRight = true
    Heading("name", L["Name"], NAME_X + 20):SetPoint("LEFT", r, "TOPLEFT", NAME_X, -86)
    Heading("zone", L["Zone"], ZONE_X + 20):SetPoint("LEFT", r, "TOPLEFT", ZONE_X, -86)
    Heading("subzone", L["Subzone"], SUBZONE_X + 20):SetPoint("LEFT", r, "TOPLEFT", SUBZONE_X, -86)

    page.arrow = r:CreateTexture(nil, "ARTWORK")
    page.arrow:SetSize(9, 8)

    local rule = r:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -TABLE_TOP + 4)
    rule:SetPoint("TOPRIGHT", r, "TOPLEFT", ROW_W, -TABLE_TOP + 4)
    rule:SetColorTexture(INK[1], INK[2], INK[3], 0.30)

    page.table = J.List(r, ROW_HEIGHT, TABLE_ROWS, BuildEntryRow, UpdateEntryRow,
        BOOK.RIGHT_W, "TOPLEFT", 0, -TABLE_TOP)

    page.empty = Style.Text(r, FONT.faded)
    page.empty:SetPoint("TOPLEFT", 4, -TABLE_TOP - 8)

    -- For the pad (UI/Journal/NearbyPad.lua): the query, and how a heading
    -- sorts at its first click.
    page.query, page.firstDir = query, FIRST_DIR

    ns.UI.NearbyPage = page  -- test hook: the page, once built
    return page
end

-- For the pad (UI/Journal/NearbyPad.lua): the day shown, and showing
-- another, as a day's click does; the filter's menu.
J.Nearby = {
    Day = function() return selectedDay end,
    -- (the filter menu's generator, the mouse's own, for the pad's menu)
    FilterMenu = FilterMenu,
    ShowDay = function(start)
        selectedDay = start
        ns.UI.RefreshNearbyPage()
    end,
}

-- The purple ribbon's page, second from the back (JNL-3;
-- UI/Journal/Pages.lua). It reads live data, so it is brought up to date
-- as it opens.
ns.UI.Journal.RegisterPage("nearby", {
    order = 30, ribbon = { colour = "purple", label = L["Recently nearby"] }, leaf = -2, buildOrder = 50,
    build = function(container) BuildPage(container) end,
    refresh = function() ns.UI.RefreshNearbyPage() end,
    title = function() return page and page.heading end,
})
