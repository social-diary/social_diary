-- Recently nearby with the pad (.claude/controller-plan.md, step 6).
--
-- The left page (group `left`, a list): the days, newest first, each under
-- its week ("This week"), the week the subheading over it. Up and down walk
-- them (held, they repeat: the catcher's); the list is virtual, so a day's
-- row is found as the pad lands on it and scrolled into view (List.lua's
-- Reveal / RowOf). Landing on a day shows nothing: A (or right) shows it,
-- as its click does, and the pad crosses to its people; A on the day shown
-- crosses back to where the pad was on it.
--
-- The right page, as it lies:
--   `bar`    the search and the filter, side by side. The search: A gives
--            the box the keyboard's cursor (there is no on-screen keyboard
--            to rely on); A again, B, or the pad moving off takes it back.
--            The table narrows as it is written in (Nearby.lua's
--            RefreshTable refreshes us). The filter: A opens its menu, which
--            is Blizzard's (MenuUtil), so the pad steps aside while it is
--            open (Pad.MenuAside)
--   `heads`  the column headings, side by side: A sorts by one, as its
--            click does (again: the other way; a third time: the latest
--            seen first again)
--   `table`  everyone seen that day, a virtual list as the days are. Each
--            row shows its tooltip, all a stranger gets. A is the link at
--            its end: "+ Add" adds them and the pad stays on the row (the
--            page's own run of adds); "Open" or "Added" opens their page,
--            the book turned to People and the pad on their name there
--            (People's scope has it then: B goes to their row, B again
--            closes the book)
-- The bar and the headings are walked by where they lie (spatial, their
-- places stamped `padAt` in Nearby.lua), so left and right move along them;
-- down off the headings is the table, up off its top the headings. Left off
-- the left end of any of them is the days again.
-- B: the search's cursor → let go; the right page → the day it came from;
-- the days → the book's (it closes).
--
-- No item is ever clicked here (there are none on this page), and nothing
-- is stored.

local addonName, ns = ...

local Pad = ns.UI.Pad
local J = ns.UI.Journal

local function Journal() return Pad.Scope("journal") end
local function Page() return ns.UI.NearbyPage end

local PROMPT = {
    title = { { "PADDUP", "PADDDOWN" }, "Go to the days", main = true },
    day = { "PAD1", "See this day", main = true },
    people = { "PAD1", "Go to the people", main = true },
    write = { "PAD1", "Write", main = true },
    done = { "PAD1", "Done writing", main = true },
    stop = { "PAD2", "Stop writing" },
    choose = { "PAD1", "Choose", main = true },
    sort = { "PAD1", "Sort by this", main = true },
    reverse = { "PAD1", "Sort the other way", main = true },
    latest = { "PAD1", "Sort by last seen", main = true },
    add = { "PAD1", "Add to the diary", main = true },
    open = { "PAD1", "Open their page", main = true },
    back = { "PAD2", "Back to the days" },
}

local function Run(frame, script, ...)
    local fn = frame and frame:GetScript(script)
    if fn then fn(frame, ...) end
end

local scope = {
    layer = 20,
    parent = "journal",
    host = function() return J.journal end,
    active = function() return ns.UI.JournalShowing("nearby") and Page() ~= nil end,
}

-- The table shown (a day chosen).
local function Shown()
    local page = Page()
    return page.right:IsVisible()
end

local function Search() return Page().search end

-- The search lets go of the cursor (the pad moved off it, or B).
local function LetGo()
    local page = Page()
    local box = page and page.search
    if box and box:HasFocus() then box:ClearFocus() end
end

--------------------------------------------------------------------------
-- The days
--------------------------------------------------------------------------

local function DayKey(start) return "day:" .. tostring(start) end

-- The heading a day falls under: its index, or nil.
local function HeadingOf(data, index)
    for i = index - 1, 1, -1 do
        if data[i].header then return i end
    end
end

-- The pad lands on a day: its row in view, its words and its week's heading.
local function FindDay(item)
    local list = Page().days
    list:Reveal(item.index)
    local row = list:RowOf(item.index)
    item.frame = row
    item.words = row and row.label or nil
    local head = item.heading and list:RowOf(item.heading)
    if head then head.header.rule = head.rule end
    item.subhead = head and head.header or nil
end

local function BuildDays(f, page)
    local data = page.days.data or {}
    for index, d in ipairs(data) do
        if d.start then
            local start = d.start
            f:Add("left", {
                key = DayKey(start), kind = "day", start = start, index = index, heading = HeadingOf(data, index),
                available = function() return true end,
                -- (a day row has no tooltip)
                enter = function() end, leave = function() end,
                press = function() scope.Open(start) end,
                step = function(dir)
                    if dir ~= "RIGHT" then return false end
                    scope.Open(start)
                    return true
                end,
            })
        end
    end
end

--------------------------------------------------------------------------
-- The right page
--------------------------------------------------------------------------

-- A control's middle on the right page, y up (Nearby.lua's `padAt`).
local function At(frame)
    return function()
        local at = frame.padAt or { 0, 0 }
        return at[1], -at[2]
    end
end

local function RowKey(guid) return "row:" .. tostring(guid) end

-- The pad lands on someone: their row in view, their name boxed, the day's
-- title the subheading over them.
local function FindRow(item)
    local page = Page()
    page.table:Reveal(item.index)
    local row = page.table:RowOf(item.index)
    item.frame = row
    item.words = row and row.name or nil
    item.subhead = page.title
end

local function BuildBar(f, page)
    local box = page.search
    f:Add("bar", {
        key = "search", kind = "search", frame = box.holder, center = At(box.holder),
        available = Shown,
        enter = function() end, leave = function() end,
        press = function()
            if box:HasFocus() then box:ClearFocus() else box:SetFocus() end
        end,
    })
    local filter = page.filter
    f:Add("bar", {
        key = "filter", kind = "filter", frame = filter, center = At(filter),
        -- (shown with the table: its parent's)
        available = Shown,
        press = function()
            filter:Click("LeftButton")
            Pad.MenuAside()
        end,
    })
end

local function BuildHeads(f, page)
    -- (Name first: down from the search lands there the first time)
    for _, key in ipairs({ "name", "level", "zone", "subzone" }) do
        local link = page.headings[key]
        f:Add("heads", {
            key = "sort:" .. key, kind = "heading", sort = key, frame = link, center = At(link),
            available = Shown,
            -- (the sort is told by the arrow and the words: the click again)
            press = function() link:Click("LeftButton") end,
        })
    end
end

local function BuildTable(f, page)
    for index, e in ipairs(page.table.data or {}) do
        local guid = e.guid
        local item
        item = {
            key = RowKey(guid), kind = "row", guid = guid, index = index,
            available = function() return Shown() end,
            press = function() scope.Act(item) end,
        }
        f:Add("table", item)
    end
end

--------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------

function scope.build(f)
    local page = Page()
    local rows = page and #(page.table.data or {}) > 0 and Shown()
    f:Group("left", { mode = "list", reveal = FindDay })
    f:Group("bar", { mode = "spatial", down = "heads", left = "left" })
    f:Group("heads", { mode = "spatial", up = "bar", down = "table", left = "left" })
    f:Group("table", { mode = "list", reveal = FindRow, up = "heads", left = "left" })
    f:Group("title", { mode = "list" })
    if not page then return end

    -- (the day shown: the days' first landing, until the pad stood on one)
    local day = J.Nearby.Day()
    if day and not f.remembered.left then f:Remember("left", DayKey(day)) end
    if not rows and f.group == "table" then f:Within("heads") end

    -- (a ribbon just turned: the title alone, until the first D-pad press,
    -- which lands on the day shown)
    local journal = Journal()
    if journal and journal.held and journal.held() then
        local spec = J.Page("nearby")
        local title = spec and spec.title and spec.title()
        if title then
            LetGo()
            if day then f:Remember("left", DayKey(day)) end
            f:Within("left")
            f:Add("title", { key = "title", words = title, prompt = PROMPT.title,
                enter = function() end, leave = function() end })
            return
        end
    end

    BuildDays(f, page)
    if Shown() then
        BuildBar(f, page)
        BuildHeads(f, page)
        BuildTable(f, page)
    elseif f.group ~= "left" then
        f:Within("left")
    end

    -- (the search lets go as the pad stands anywhere else)
    for _, name in ipairs(f.order) do
        for _, it in ipairs(f.groups[name].items) do
            if it.kind ~= "search" then
                local own = it.enter
                it.enter = function()
                    LetGo()
                    if own then own() else Run(it.frame, "OnEnter", false) end
                end
            end
        end
    end
end

-- A (or right) on a day: shown, as its click does, and over onto its
-- people (the first, scrolled to the top; none: the search). The day
-- already shown: back where the pad was on it.
function scope.Open(start)
    local f = scope.focus
    local page = Page()
    if not (f and page) then return end
    if J.Nearby.Day() ~= start or not Shown() then
        f:Remember("table", nil)
        J.Nearby.ShowDay(start)
        f:Remember("left", DayKey(start))
    end
    if not f:EnterGroup("table") then
        f:Remember("bar", "search")
        f:EnterGroup("bar")
    end
end

-- A on a row: the link at its end. "+ Add" adds them, the pad kept on the
-- row; "Open" or "Added" opens their page, the pad on their name.
function scope.Act(item)
    local row = item.frame
    if not (row and row.item and row.item.guid == item.guid) then return end
    if row.add:IsShown() then
        row.add:Click("LeftButton")
        return
    end
    local link = row.open:IsShown() and row.open or row.added
    link:Click("LeftButton")
    -- (the book on People now: its scope has the pad, put on their name)
    local people = Pad.Scope("people")
    local pf = people and people.focus
    if pf and people.Open and Pad.Top() == people and J.selected == item.guid then
        pf:Remember("page", "header")
        people.Open(item.guid)
        -- (B there: their row. Someone just added was not in the list yet
        -- as the book turned, so the pad's first landing missed them)
        pf:Remember("left", "person:" .. tostring(item.guid))
    end
end

-- B, one step out.
function scope.back()
    local f = scope.focus
    if not f then return false end
    local page = Page()
    local box = page and page.search
    if box and box:HasFocus() then
        box:ClearFocus()
        return true
    end
    local at = f:Current()
    if at and (at.group == "bar" or at.group == "heads" or at.group == "table") then
        f:EnterGroup("left")
        return true
    end
    return false
end

-- The first D-pad press after a ribbon turn is the journal's: it lets the
-- title go. Any other time this page's focus.
local function Direction(key)
    return function()
        local journal = Journal()
        local fn = journal and journal.keys and journal.keys[key]
        if journal and journal.held and journal.held() and fn then
            fn(journal)
            return true
        end
        return false
    end
end

scope.keys = {
    PADDUP = Direction("PADDUP"), PADDDOWN = Direction("PADDDOWN"),
    PADDLEFT = Direction("PADDLEFT"), PADDRIGHT = Direction("PADDRIGHT"),
}

function scope.legend()
    local at = scope.focus and scope.focus:Current()
    if not at then return {} end
    if at.prompt then return { at.prompt } end
    local page = Page()
    local k = at.kind
    if k == "day" then
        return { (J.Nearby.Day() == at.start and Shown()) and PROMPT.people or PROMPT.day }
    end
    local out = {}
    if k == "search" then
        local writing = Search():HasFocus()
        out[1] = writing and PROMPT.done or PROMPT.write
        if writing then
            out[2] = PROMPT.stop
            return out
        end
    elseif k == "filter" then
        out[1] = PROMPT.choose
    elseif k == "heading" then
        local q = page.query
        if q.sort ~= at.sort then
            out[1] = PROMPT.sort
        elseif q.dir == page.firstDir[at.sort] then
            out[1] = PROMPT.reverse
        else
            out[1] = PROMPT.latest
        end
    elseif k == "row" then
        out[1] = ns.Diary.IsDiary(at.guid) and PROMPT.open or PROMPT.add
    end
    out[#out + 1] = PROMPT.back
    return out
end

Pad.RegisterScope("nearby", scope)
