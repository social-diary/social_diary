-- The journal's People list (JNL-1), on the left page: the search box, the
-- sort and filter menus, and the list itself, grouped under headings that
-- follow the sort.
--
-- The query lives in the journal's shared state (ns.UI.Journal, from
-- UI/Journal/Book.lua), so the box, the menus and the list read the one copy.

local addonName, ns = ...

local Format = ns.UI.Format

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal

local BOOK = ns.UI.Journal.BOOK
local BOOK_H, LEFT_X, LEFT_W = BOOK.BOOK_H, BOOK.LEFT_X, BOOK.LEFT_W
local PEOPLE_TOP = 114
local PEOPLE_ROW_HEIGHT = Style.ROW_HEIGHT
local PEOPLE_ROWS = math.floor((BOOK_H - PEOPLE_TOP - 14) / PEOPLE_ROW_HEIGHT)
local DAY = ns.DAY

local Count = Format.Count

--------------------------------------------------------------------------
-- The People list (JNL-1)
--------------------------------------------------------------------------

local function SortLabel()
    local sort = J.ByKey(ns.People.SORTS, J.query.sort)
    return sort and sort.label:lower() or "?"
end

-- The right-hand column follows the sort, so the list shows what it is
-- ordered by. Blank where the group heading already says it ("No Interactions yet").
local function PersonDetail(s)
    if J.query.sort == "timesMet" then
        return s.timesMet > 0 and Count(s.timesMet, "time", "times") or ""
    elseif J.query.sort == "together" then
        return s.seconds > 0 and Format.Duration(s.seconds) or ""
    elseif J.query.sort == "lastSeen" then
        local seenAt = ns.People.SeenAt(s)
        return seenAt and Format.Ago(seenAt) or ""
    end
    return s.lastMet and Format.Ago(s.lastMet) or ""
end

-- The group heading a person falls under, for the current sort. Nil means
-- no heading: by name the list is one run, and by count or time together
-- only the never-met tail gets one.
local function Group(s, now)
    local sort = J.query.sort
    if sort == "name" then return nil end

    if sort == "lastSeen" then
        local at = ns.People.SeenAt(s)
        if not at then return "Not seen yet" end
        if now - at < 7 * DAY then return "Seen this week" end
        if now - at < 30 * DAY then return "Seen this month" end
        return "Seen earlier"
    end

    if not s.lastMet then return "No Interactions yet" end
    if sort ~= "lastMet" then return nil end
    if now - s.lastMet < 7 * DAY then return "This week" end
    if now - s.lastMet < 30 * DAY then return "This month" end
    return "Earlier"
end

local function WithGroups(list)
    local now = ns.Now()
    local out, last = {}, nil
    for i = 1, #list do
        local group = Group(list[i], now)
        if group and group ~= last then out[#out + 1] = { header = group } end
        last = group
        out[#out + 1] = list[i]
    end
    return out
end

local function ActiveFilters()
    local parts = {}
    if J.query.tag then parts[#parts + 1] = "tag: " .. J.query.tag end
    if J.query.relationship then parts[#parts + 1] = "relationship: " .. J.query.relationship end
    if J.query.faction then parts[#parts + 1] = J.query.faction end
    if J.query.zone then parts[#parts + 1] = "met in " .. J.query.zone end
    if J.query.withinDays then parts[#parts + 1] = "met in the last " .. J.query.withinDays .. " days" end
    return parts
end

local function RefreshList(keepScroll)
    if not J.journal then return end

    local list = ns.People.Query(J.query)
    J.journal.people:SetData(WithGroups(list), keepScroll)

    local total = ns.Diary.Count()
    J.journal.count:SetText(total == 0 and "nobody yet" or #list == total and ("%d in the diary"):format(total)
        or ("%d of %d"):format(#list, total))

    -- An empty diary has nothing to search or sort: the page teaches how
    -- someone gets in instead (UI/Journal/Empty.lua).
    local empty = total == 0
    for _, control in ipairs(J.journal.listControls) do control:SetShown(not empty) end
    J.RefreshWelcome(empty)

    if empty then
        J.journal.emptyList:SetText("")
    elseif #list == 0 then
        J.journal.emptyList:SetText("Nobody matches.")
    else
        J.journal.emptyList:SetText("")
    end

    local filters = ActiveFilters()
    J.journal.sortButton:SetText(SortLabel())
    J.journal.filterButton:SetText(#filters == 0 and "All people" or Count(#filters, "filter", "filters"))
    J.journal.filters:SetText(#filters > 0 and table.concat(filters, "  ·  ") or "")
    -- The pad's rows were handed round (UI/Journal/PeoplePad.lua); with
    -- the pad down this does nothing.
    ns.UI.Pad.Refresh()
end

local function BuildPersonRow(list)
    local row = Style.GroupedRow(list, function(row)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 4, 0)

        row.name = Style.Text(row, FONT.body)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -72, 0)
        row.name:SetWordWrap(false)

        row.detail = Style.Text(row, FONT.small)
        row.detail:SetPoint("RIGHT", -4, 0)
        row.detail:SetJustifyH("RIGHT")

        return { row.icon, row.name, row.detail }
    end)

    row:SetScript("OnClick", function(self)
        if self.item and self.item.guid then ns.UI.SelectPerson(self.item.guid) end
    end)

    return row
end

local function UpdatePersonRow(row, item)
    if row:SetHeading(item) then return end

    local isSelected = item.guid == J.selected
    row.name:SetText(item.name)
    row.name:SetFontObject(isSelected and FONT.strong or FONT.body)
    row.detail:SetText(PersonDetail(item))
    row.selected:SetShown(isSelected)

    Style.ClassIconOrInk(row.icon, item.record and item.record.class)
end

--------------------------------------------------------------------------
-- Menus
--------------------------------------------------------------------------

-- Choices on one field of the query; picking one re-queries the list.
local function Field(menu, field, choices)
    Style.Choices(menu, choices, function() return J.query[field] end, function(key)
        J.query[field] = key
        RefreshList()
    end)
end

-- One submenu per facet, "any" first. Values come from the data, so a menu
-- never offers a tag nobody has.
local function FacetMenu(root, title, field, values)
    local choices = { { label = "Any" } }
    for _, value in ipairs(values) do choices[#choices + 1] = { label = value, key = value } end
    Field(root:CreateButton(title), field, choices)
end

-- The sort is a preference, so it is saved and outlives the login; the
-- search and filters are not.
local function SetSort(key)
    J.query.sort = key
    ns.SetSetting("peopleSort", key)
    RefreshList()
end

local function ShowSortMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Sort by")
        Style.Choices(root, ns.People.SORTS, function() return J.query.sort end, SetSort)
    end)
end

-- The saved sort, if it is still one the list knows (a hand-edited file or
-- a sort since removed falls back on the default).
local function SavedSort()
    local saved = ns.Setting("peopleSort")
    if J.ByKey(ns.People.SORTS, saved) then return saved end
    return ns.SettingDefault("peopleSort")
end

local function ShowFilterMenu(owner)
    local facets = ns.People.Facets()

    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton("Clear filters", function()
            J.query.tag, J.query.relationship, J.query.faction, J.query.zone, J.query.withinDays =
                nil, nil, nil, nil, nil
            RefreshList()
        end)
        root:CreateDivider()

        FacetMenu(root, "Tag", "tag", facets.tags)
        FacetMenu(root, "Relationship", "relationship", facets.relationships)
        FacetMenu(root, "Faction", "faction", facets.factions)
        FacetMenu(root, "Met in zone", "zone", facets.zones)

        local within = { { label = "Any time" } }
        for _, option in ipairs(ns.People.WITHIN) do
            within[#within + 1] = { label = option.label, key = option.days }
        end
        Field(root:CreateButton("Last met"), "withinDays", within)
    end)
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

local function BuildLeftPage(panel, book)
    J.query.sort = SavedSort()

    panel.count, panel.peopleTitle = J.PageHeading(book, "People")

    panel.search = Style.PageSearch(book, LEFT_X, -48, LEFT_W, "Search names, tags, notes",
        Style.SearchInto(J.query, RefreshList))

    local sortedBy = Style.Text(book, FONT.faded)
    panel.sortedBy = sortedBy
    sortedBy:SetPoint("LEFT", book, "TOPLEFT", LEFT_X, -86)
    sortedBy:SetText("Sorted by")

    panel.sortButton = Style.Link(book, FONT.body, function(self) ShowSortMenu(self) end)
    panel.sortButton:SetPoint("LEFT", sortedBy, "RIGHT", 5, 0)

    panel.filterButton = Style.Link(book, FONT.body, function(self) ShowFilterMenu(self) end)
    panel.filterButton:SetPoint("RIGHT", book, "TOPLEFT", LEFT_X + LEFT_W, -86)

    panel.filters = Style.Text(book, FONT.small)
    panel.filters:SetPoint("TOPLEFT", LEFT_X, -100)
    panel.filters:SetWidth(LEFT_W)
    panel.filters:SetWordWrap(false)

    panel.people = J.List(book, PEOPLE_ROW_HEIGHT, PEOPLE_ROWS, BuildPersonRow, UpdatePersonRow,
        LEFT_W + 20, "TOPLEFT", LEFT_X - 6, -PEOPLE_TOP)

    panel.emptyList = Style.Text(book, FONT.faded)
    panel.emptyList:SetPoint("TOPLEFT", LEFT_X, -PEOPLE_TOP - 6)
    panel.emptyList:SetWidth(LEFT_W)

    -- What an empty diary hides.
    panel.listControls = { panel.search.holder, panel.sortedBy, panel.sortButton, panel.filterButton,
        panel.filters, panel.people }
end

-- For the book, which refreshes it (UI/Journal/Book.lua); the sort as its
-- menu sets it, for the pad's left and right on it (UI/Journal/PeoplePad.lua).
J.RefreshList, J.SetSort = RefreshList, SetSort

-- The red ribbon's page, second in the book (UI/Journal/Pages.lua): the
-- list on the left page, the selected person's page on the right
-- (UI/Journal/Profile.lua), and an empty diary's welcome over both
-- (UI/Journal/Empty.lua). It opens on the selected person's own leaf, and
-- is built before every other page. The book refreshes it itself
-- (ns.UI.SetJournalView), so it has no `refresh`. A stranger's glimpse
-- (J.glimpse) takes no leaf of its own: the stack stays People's own while
-- it lies open, and adding them gives them the next leaf as any page read
-- for the first time is given (the user's decision 1 on the stranger-glimpse
-- proposal, 5 Nov 2026: whatever is simplest and breaks nothing).
J.RegisterPage("people", {
    order = 20, ribbon = { colour = "red", label = "People" }, leaf = 2, buildOrder = 10,
    leaves = function() return J.EntryLeaf(J.selected) end,
    title = function() return J.journal and J.journal.peopleTitle end,
    build = function(people, panel)
        BuildLeftPage(panel, people)
        panel.profile = J.BuildProfile(panel, people)

        panel.emptyProfile = Style.Text(people, FONT.faded)
        panel.emptyProfile:SetPoint("TOPLEFT", BOOK.RIGHT_X, -BOOK.TOP - 8)
        panel.emptyProfile:SetText("Choose someone from the list to read their page.")

        -- An empty diary's People page: how someone gets in, and what their
        -- page will be (UI/Journal/Empty.lua).
        J.BuildWelcome(panel, people)

        -- A stranger's glimpse, their page pencilled in, in place of
        -- "Choose someone" (UI/Journal/Glimpse.lua). Over the welcome's
        -- right page, whose strip gives way to it.
        J.BuildGlimpse(panel, people)
    end,
})
