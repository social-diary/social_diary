-- The People page with the pad (.claude/controller-plan.md, step 5a): the
-- list, and reading a person's page.
--
-- The left page (group `left`, a list): the search box, the sort and the
-- filter, then the people, in the order the page shows them. Up and down
-- walk them (held, they repeat: the catcher's); the list is virtual, so a
-- row is found as the pad lands on it, scrolled into view (List.lua's
-- Reveal / RowOf), and its group heading ("This week") is the subheading
-- over it. Landing on someone opens nothing: A opens their page (the row's
-- click, ns.UI.SelectPerson) and the pad crosses to it, as on Your Diary.
--   the search  A gives the box the keyboard's cursor (there is no
--               on-screen keyboard to rely on, as 4c's lines); A again, B,
--               or the pad moving off takes it back. The list narrows as
--               it is written in (People.lua's RefreshList refreshes us)
--   the sort    A opens its menu, as a click; left and right go through
--               the sorts at once, without it (People.lua's SetSort)
--   the filter  A opens its menu
-- A menu is the pad's own (Pad.Menu, UI/Pad/Menu.lua), run from the same
-- generator as the mouse's Blizzard menu (People.lua's J.SortMenu,
-- J.FilterMenu): Forever's Gamepad UI does not drive a menu an addon opens
-- (the client, 8 Nov 2026), so with the pad Blizzard's is never opened.
-- B on the left page is the book's: it closes.
--
-- The right page (group `page`, a list, top to bottom as it reads): their
-- name (the header), the plate, the strips beside it and your note's slip
-- (whatever the top block holds that answers strip:Focus(): a strip added
-- there later is found with no code here), then the timeline's lines.
-- Paper (plate, strips, a note's slip) takes the red outline, words the pen's
-- box, as everywhere (Pad.Look). Each shows its own tooltip, as under the
-- mouse.
--   the plate    A goes in among its marks (group `marks`, spatial: each
--                ringed, its tooltip shown, the plate leaning in), as on Your
--                Diary's plates. X on the plate or a mark is the plate's
--                click: the "Where you saw them" sheet
--   a strip      A is its click where it has one (a strip naming someone:
--                their page); else only its tooltip
--   a line       an episode's line: A opens or folds it, as its click does
--                (any line on its bracket answers, as under the mouse); a
--                dungeon run's card: A lays its run out on the table (the
--                spread's own scope has the pad then, UI/Dungeon/Pad.lua);
--                any other line, and an item in it, only its tooltip: never
--                a click, so no item goes to chat or the dressing room (the
--                user, 7 Nov 2026)
-- The index tabs out of the book's right edge (group `tabs`, a list down
-- the edge): up off the top of the page, or right from anywhere on it. Down
-- off their foot, or left, is the page again. "Their story" and "Where you
-- saw them" are walked; A is their click.
-- The map sheet (group `sheet`), opened by the map tab or X: while it lies
-- on the book, only its links (found on it, in the order they lie); B puts it
-- away and the pad is back where it was opened from.
-- B: marks → their plate; the sheet → put away; the right page → the row it
-- was crossed from.
--
-- Step 5b: the note tab and the edit tab are walked too. A on the edit tab
-- is writing mode, a scope of its own over this one (UI/Journal/WritingPad.lua);
-- A on the note tab, or on a note's line (its click), lays the note's sheet
-- on the book, and its link card over it, each a scope of its own
-- (UI/Journal/NotePad.lua). Put away, this scope has the pad where it was.
-- Your note's slip has no click under the mouse, so A on it does nothing
-- (it is written in writing mode).
--
-- A stranger's glimpse (group `glimpse`, as it reads): their name, the loose
-- print (outlined; A among its marks, as the plate), the two pencilled notes
-- (each its heading the subheading, its tooltip where a line was cut), what
-- happened after (the ledger's heading over each line), how often they were
-- seen, and the foot strip (outlined): A is its link, "+ Add", and the page
-- inked where it lies is their page, the pad on their name. Right from the
-- list, or a glimpse opened from elsewhere (a name on Your Diary), puts the
-- pad there; B or left is the left page again.
--
-- An empty diary (UI/Journal/Empty.lua): the left page's controls, found
-- (Pad.Controls): the Remember this key (A listens for a key on the keyboard:
-- a pad button cannot be bound yet, and the prompt says so; A again or B
-- stops it) and the Recently nearby link. Its right page has nothing to walk
-- unless a glimpse lies there.

local addonName, ns = ...

local Pad = ns.UI.Pad
local J = ns.UI.Journal

local function Journal() return Pad.Scope("journal") end

local function Profile() return J.journal and J.journal.profile end

local PROMPT = {
    title = { { "PADDUP", "PADDDOWN" }, "Go to the list", main = true },
    open = { "PAD1", "Open their page", main = true },
    write = { "PAD1", "Write", main = true },
    done = { "PAD1", "Done writing", main = true },
    stop = { "PAD2", "Stop writing" },
    choose = { "PAD1", "Choose", main = true },
    sorts = { { "PADDLEFT", "PADDRIGHT" }, "Sort another way" },
    marks = { "PAD1", "Look at the marks", main = true },
    map = { "PAD3", "See the map" },
    person = { "PAD1", "Go to their page", main = true },
    unfold = { "PAD1", "See the rest", main = true },
    fold = { "PAD1", "Fold it up", main = true },
    run = { "PAD1", "Open the map", main = true },
    runSheet = { "PAD1", "Open the sheet", main = true },
    story = { "PAD1", "See their story", main = true },
    seen = { "PAD1", "See where you saw them", main = true },
    tabs = { "PADDRIGHT", "Go to the tabs" },
    back = { "PAD2", "Back to the list" },
    backPlate = { "PAD2", "Back to the plate" },
    away = { "PAD2", "Put the map away" },
    note = { "PAD1", "Change the note", main = true },
    addNote = { "PAD1", "Add a note", main = true },
    edit = { "PAD1", "Write about them", main = true },
    add = { "PAD1", "Add to the diary", main = true },
    glimpse = { "PADDRIGHT", "Go to their page" },
    backStart = { "PAD2", "Back to the left page" },
    stopKey = { "PAD2", "Stop listening" },
}

local function Run(frame, script, ...)
    local fn = frame and frame:GetScript(script)
    if fn then fn(frame, ...) end
end

-- A person's page open to read: not writing, no note's sheet (those are
-- scopes of their own over this one: WritingPad.lua, NotePad.lua).
local function Reading()
    local p = Profile()
    return J.selected ~= nil and not J.editing and p ~= nil and p:IsShown() and J.tab ~= "note"
end

-- The map sheet lying on the book.
local function OnMap()
    local p = Profile()
    return Reading() and J.tab == "map" and p.map:IsShown()
end

local scope = {
    layer = 20,
    parent = "journal",
    host = function() return J.journal end,
    -- (an empty diary's page too. Writing and a note's sheet have scopes of
    -- their own over this one; while either is coming or going, the page
    -- half drawn, this one waits, so its pad stays where A was pressed)
    active = function()
        return ns.UI.JournalShowing("people") and not (J.selected and (J.editing or J.tab == "note"))
    end,
}

--------------------------------------------------------------------------
-- The left page
--------------------------------------------------------------------------

local function Search() return J.journal.search end

-- The search lets go of the cursor (the pad moved off it, or B).
local function LetGo()
    local box = J.journal and Search()
    if box and box:HasFocus() then box:ClearFocus() end
end

-- The heading a person's row falls under: its index, or nil.
local function HeadingOf(data, index)
    for i = index - 1, 1, -1 do
        if data[i].header then return i end
    end
end

-- The pad lands on someone: their row scrolled into view, their name and
-- their group's heading over it.
local function FindPerson(item)
    if not item.index then return end
    local list = J.journal.people
    list:Reveal(item.index)
    local row = list:RowOf(item.index)
    item.frame = row
    item.words = row and row.name or nil
    local head = item.heading and list:RowOf(item.heading)
    if head then head.header.rule = head.rule end
    item.subhead = head and head.header or nil
end

local function Key(guid) return "person:" .. tostring(guid) end

local function BuildLeft(f)
    local journal = J.journal
    local box = Search()
    f:Add("left", {
        key = "search", kind = "search", frame = box.holder,
        available = function() return box.holder:IsVisible() end,
        enter = function() end, leave = function() end,
        press = function()
            if box:HasFocus() then box:ClearFocus() else box:SetFocus() end
        end,
    })
    local sort = journal.sortButton
    f:Add("left", {
        key = "sort", kind = "sort", frame = sort,
        -- (its menu the pad's own, from the mouse's generator: Forever's
        -- Gamepad UI does not drive a menu an addon opens, 8 Nov 2026)
        press = function() Pad.Menu.Open(sort, J.SortMenu) end,
        step = function(dir)
            local sorts = ns.People.SORTS
            local at = 1
            for i, s in ipairs(sorts) do if s.key == J.query.sort then at = i end end
            J.SetSort(sorts[(at - 1 + (dir == "RIGHT" and 1 or -1)) % #sorts + 1].key)
            return true
        end,
    })
    f:Add("left", {
        key = "filter", kind = "filter", frame = journal.filterButton,
        press = function() Pad.Menu.Open(journal.filterButton, J.FilterMenu()) end,
    })
    local data = journal.people.data or {}
    for index, s in ipairs(data) do
        if s.guid then
            local guid = s.guid
            f:Add("left", {
                key = Key(guid), kind = "person", guid = guid, index = index, heading = HeadingOf(data, index),
                available = function() return true end,
                press = function() scope.Open(guid) end,
            })
        end
    end
end

--------------------------------------------------------------------------
-- The right page
--------------------------------------------------------------------------

-- A timeline line's key, the same however often the list is laid again
-- (folded, opened, a row added): what it stands for, a saved table where
-- there is one (a session, a stored row, a run, a death, a note).
local function Stable(item)
    if not item then return "?" end
    local t = item.key or item.row or item.note or item.death
    if t ~= nil then return tostring(t) end
    return tostring(item.kind) .. ":" .. tostring(item.time)
end
local function LineKey(line)
    return "tl:" .. Stable(line.item) .. (line.note and (":note:" .. tostring(line.note)) or "")
end

-- The episode a line answers for (its own, or the one it hangs under), if a
-- click on it opens or folds it (Timeline.lua's Openable).
local function Folds(line)
    local ep = line.fold or line.item
    local IsEpisode = ns.UI.TimelineText.IsEpisode
    if ep and IsEpisode(ep) and (ep.hidden or 0) > 0 and ep.kind ~= "visit" then return ep end
end

-- Whether episode `ep` lies open: Timeline.lua keeps that in a table of its
-- own, so it is read off its lines (a drawn bracket, not a dashed one).
local function Open(ep)
    local p = Profile()
    for _, line in ipairs(p and p.timeline.data or {}) do
        if (line.fold == ep or line.item == ep) and line.bracket then return not line.bracket.dashed end
    end
    return false
end

-- The lines worth standing on: an entry's own (not its details' line, the
-- gaps or a day's label).
local function Walked(line)
    return line.text ~= nil and (line.icon ~= nil or line.visit ~= nil or line.slip ~= nil or line.when ~= nil)
end

local function Outline(strip)
    return function()
        local now = strip:Focus()
        return { anchor = strip:GetParent(), corners = now.corners, level = strip:GetFrameLevel() }
    end
end

-- The pad lands on a line of the right page's list: scrolled into view
-- (the top block: the list's first line), and a timeline line's frame and
-- words found on its row.
local function FindLine(item)
    local p = Profile()
    if not (p and item.index) then return end
    p.timeline:Reveal(item.index)
    if not item.line then return end
    local row = p.timeline:RowOf(item.index)
    item.frame = row
    item.words = row and row.text or nil
    -- (a note's slip is paper: outlined, not boxed)
    local slip = row and row.slip
    item.outline = slip and slip:IsShown() and Outline(slip) or nil
end

local function BuildBlock(f, p)
    local block, list = p.clippings, p.timeline
    f:Add("page", {
        key = "header", kind = "header", index = 1, words = p.header.name, clip = list,
        available = Reading, enter = function() end, leave = function() end, press = function() end,
    })
    local plate = block.plate
    if block.plated and plate:IsShown() then
        f:Add("page", {
            key = "plate", kind = "plate", index = 1, frame = plate.clip,
            available = function() return Reading() and plate:IsShown() end,
            outline = function()
                return { anchor = plate:GetParent(), corners = plate:Corners(), level = plate:GetFrameLevel() }
            end,
            -- (A goes in only where the print has a mark to stand on; its
            -- prompt likewise, scope.legend)
            press = function() if plate:HasMarks() then scope.EnterMarks() end end,
            whole = function() return plate end,
        })
    end
    -- (every strip on the block, in the order they lie: a strip added
    -- there is found as it is)
    local strips = {}
    for _, child in ipairs({ block.frame:GetChildren() }) do
        if rawget(child, "Focus") and child.box and child:IsShown() then strips[#strips + 1] = child end
    end
    table.sort(strips, function(a, b)
        if math.abs(a.box[2] - b.box[2]) > 1 then return a.box[2] < b.box[2] end
        return a.box[1] < b.box[1]
    end)
    for i, strip in ipairs(strips) do
        local at = strip:Focus()
        f:Add("page", {
            key = "strip:" .. i, kind = "strip", index = 1, frame = at.frame, heading = at.words, strip = strip,
            available = function() return Reading() and strip:IsShown() end,
            outline = Outline(strip),
            -- (its click where it names someone; else only its tooltip. Your
            -- note's slip: changing it is writing mode's, 5b)
            press = function()
                if strip.guid and strip.onClick then at.frame:Click("LeftButton") end
            end,
        })
    end
end

local function BuildTimeline(f, p)
    local list = p.timeline
    for index, line in ipairs(list.data or {}) do
        if index > 1 and Walked(line) then
            local key = LineKey(line)
            local item
            item = { key = key, kind = "line", index = index, line = line, clip = list, available = Reading }
            if line.visit then
                item.press = function() Run(item.frame, "OnMouseUp", "LeftButton") end
            elseif line.note then
                -- (its click: the note's sheet, NotePad.lua's scope)
                item.press = function() Run(item.frame, "OnMouseUp", "LeftButton") end
            elseif Folds(line) then
                local head = "tl:" .. Stable(Folds(line))
                item.press = function()
                    Run(item.frame, "OnMouseUp", "LeftButton")
                    -- (folded away under its episode: on the episode's line)
                    local fo = scope.focus
                    if fo and not fo:Focus(key, "page") then fo:Focus(head, "page") end
                end
            else
                item.press = function() end
            end
            f:Add("page", item)
        end
    end
end

local function BuildTabs(f, p)
    for _, tab in ipairs({ { p.tabStory, "story" }, { p.tabMap, "map" }, { p.tabNote, "note" }, { p.tabEdit, "edit" } }) do
        local frame, key = tab[1], tab[2]
        f:Add("tabs", {
            key = "tab:" .. key, kind = "tab", tab = key, frame = frame,
            -- (shown with the page: its parent's)
            available = Reading,
            outline = function()
                local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
                return { anchor = frame, corners = { { 0, 0 }, { w, 0 }, { w, h }, { 0, h } }, level = frame:GetFrameLevel() }
            end,
            press = function()
                if key == "map" then scope.fromMap = { group = "tabs", key = "tab:map" } end
                frame:Click("LeftButton")
            end,
        })
    end
end

local function BuildMarks(f, plate)
    local marks = plate:Marks()
    table.sort(marks, function(a, b)
        if math.abs(a.y - b.y) > 0.5 then return a.y < b.y end
        return a.x < b.x
    end)
    for _, mk in ipairs(marks) do
        local frame = mk.frame
        f:Add("marks", {
            key = mk.key, kind = "mark", frame = frame, ring = true,
            available = function() return frame:IsShown() end,
            center = function() return mk.x, -mk.y end,
            enter = function()
                plate.padLean = true
                plate:Lean()
                Run(frame, "OnEnter", false)
            end,
            leave = function()
                plate.padLean = nil
                plate:Lean()
                Run(frame, "OnLeave", false)
            end,
            press = function() end,
            whole = function() return plate end,
        })
    end
end

-- The map sheet's links, in the order they lie (a link placed on the sheet
-- keeps its middle, `padAt`): the map (its menu), "Just them" and
-- "Everyone", and the other maps they were seen on. The header's three are
-- always on the sheet (never hidden: shown as the sheet is); the other maps'
-- only as many as are laid.
local function Links(view)
    local out = { view.mapButton, view.themButton, view.everyoneButton }
    for _, link in ipairs(view.also or {}) do
        if link:IsShown() then out[#out + 1] = link end
    end
    return out
end

local function BuildSheet(f, p)
    local links = Links(p.map)
    local function At(w) return w.padAt or { math.huge, math.huge } end
    table.sort(links, function(a, b)
        local pa, pb = At(a), At(b)
        if math.abs(pa[2] - pb[2]) > 3 then return pa[2] < pb[2] end
        return pa[1] < pb[1]
    end)
    for _, link in ipairs(links) do
        f:Add("sheet", {
            key = "sheet:" .. tostring(link), kind = "link", frame = link,
            level = p.map:GetFrameLevel() + 30,
            available = function() return OnMap() end,
            -- (the map's link opens a menu: the pad's own, from the
            -- mouse's generator; the other links are their click)
            press = function()
                if link == p.map.mapButton then
                    local generator = p.map.mapMenu()
                    if generator then Pad.Menu.Open(link, generator) end
                else
                    link:Click("LeftButton")
                end
            end,
        })
    end
end

--------------------------------------------------------------------------
-- An empty diary, a stranger's glimpse (5b)
--------------------------------------------------------------------------

-- The empty page's left page: its controls, found (with the pad in hand,
-- Remember this's book in place of its key; the link to Recently nearby).
local function BuildWelcome(f, welcome)
    -- (the book is made after the link, the first time the pad is in hand,
    -- but lies where the key does, above it: read first)
    local found, books = {}, {}
    for _, c in ipairs(Pad.Controls.Find(welcome)) do
        table.insert(c.kind == "book" and books or found, c)
    end
    for i, c in ipairs(books) do table.insert(found, i, c) end
    local set = Pad.Controls.Add(f, "left", found)
    for _, it in ipairs(set.items) do
        if it.kind == "setter" then scope.setter = it.control end
    end
end

-- The glimpse open: whether it lies on the right page.
local function Glimpsed()
    local g = J.journal and J.journal.glimpse
    return J.glimpse ~= nil and g ~= nil and g:IsShown()
end

local function Hovered(hover)
    return {
        enter = function() if hover and hover:IsShown() then Run(hover, "OnEnter", false) end end,
        leave = function() if hover then Run(hover, "OnLeave", false) end end,
    }
end

local function Words(f, key, fs, extra)
    local item = Hovered(extra and extra.hover)
    item.key, item.kind, item.words = key, "glimpseWords", fs
    item.subhead = extra and extra.subhead
    item.available = function() return Glimpsed() and fs:IsShown() and (fs:GetText() or "") ~= "" end
    item.press = function() end
    f:Add("glimpse", item)
end

local function BuildGlimpse(f, page)
    Words(f, "g:name", page.name)
    local print = page.print
    if page.plated and print:IsShown() then
        f:Add("glimpse", {
            key = "g:print", kind = "glimpsePrint", frame = print.clip,
            available = function() return Glimpsed() and print:IsShown() end,
            outline = function()
                return { anchor = print:GetParent(), corners = print:Corners(), level = print:GetFrameLevel() }
            end,
            press = function() if print:HasMarks() then scope.EnterMarks("glimpse", "g:print") end end,
            whole = function() return print end,
        })
    end
    for _, which in ipairs({ "first", "hinge" }) do
        local n = page[which]
        Words(f, "g:" .. which, n.line, { hover = n.hover, subhead = n.heading })
    end
    for i, row in ipairs(page.rows) do
        Words(f, "g:after:" .. i, row.words, { hover = row.hover, subhead = page.ledgerHeading })
    end
    Words(f, "g:seen", page.seen)
    local strip = page.strip
    if strip:IsShown() then
        local at = strip:Focus()
        f:Add("glimpse", {
            key = "g:strip", kind = "glimpseStrip", frame = at.frame, heading = at.words,
            available = function() return Glimpsed() and strip:IsShown() end,
            outline = Outline(strip),
            press = function() scope.AddGlimpse() end,
        })
    end
end

--------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------

function scope.build(f)
    local glimpsed = Glimpsed()
    f:Group("left", { mode = "list", reveal = FindPerson, right = glimpsed and "glimpse" or nil })
    f:Group("glimpse", { mode = "list", left = "left" })
    f:Group("page", { mode = "list", reveal = FindLine, up = "tabs", right = "tabs" })
    f:Group("tabs", { mode = "list", down = "page", left = "page" })
    f:Group("marks", { mode = "spatial" })
    f:Group("sheet", { mode = "list" })
    f:Group("title", { mode = "list" })
    if not J.journal then return end
    scope.setter = nil

    -- (a glimpse opened from elsewhere, a name on Your Diary: the pad on it)
    if J.glimpse ~= scope.seenGlimpse then
        scope.seenGlimpse = J.glimpse
        if glimpsed then
            f:Remember("glimpse", nil)
            f:Within("glimpse")
        end
    end
    if f.group == "glimpse" and not glimpsed then f:Within("left") end

    -- (someone opened from elsewhere, Your Diary's name or the key: the
    -- pad on their row)
    if J.selected ~= scope.seen then
        scope.seen = J.selected
        if J.selected then f:Remember("left", Key(J.selected)) end
        if f.group ~= "sheet" then f:Within("left") end
    end
    if not f.remembered.left then
        local data = J.journal.people.data or {}
        for _, s in ipairs(data) do
            if s.guid then f:Remember("left", Key(s.guid)) break end
        end
    end

    -- (a ribbon just turned: the title alone, until the first D-pad press,
    -- which lands on the list)
    local journal = Journal()
    if journal and journal.held and journal.held() then
        local spec = J.Page("people")
        local title = spec and spec.title and spec.title()
        if title then
            LetGo()
            f:Within("left")
            f:Add("title", { key = "title", words = title, prompt = PROMPT.title,
                enter = function() end, leave = function() end })
            return
        end
    end

    local p = Profile()
    if OnMap() then
        f:Within("sheet")
        BuildSheet(f, p)
        return
    end
    if f.group == "sheet" then f:Within("page") end

    local welcome = J.journal.welcome
    if welcome and welcome:IsShown() then BuildWelcome(f, welcome) else BuildLeft(f) end
    if glimpsed then BuildGlimpse(f, J.journal.glimpse) end
    if Reading() then
        BuildBlock(f, p)
        BuildTimeline(f, p)
        BuildTabs(f, p)
        local plate = scope.inPlate and p.clippings.plated and p.clippings.plate
        if plate and plate:IsShown() then BuildMarks(f, plate) else scope.inPlate = nil end
    elseif glimpsed and scope.inPlate and J.journal.glimpse.plated then
        BuildMarks(f, J.journal.glimpse.print)
    else
        scope.inPlate = nil
    end
    if f.group == "marks" and not scope.inPlate then f:Within((scope.plateAt or { "page" })[1]) end

    -- (the search lets go as the pad stands anywhere else)
    for _, name in ipairs(f.order) do
        for _, it in ipairs(f.groups[name].items) do
            if it.kind ~= "search" and not it.control then
                local own = it.enter
                it.enter = function()
                    LetGo()
                    if own then own() else Run(it.frame, "OnEnter", false) end
                end
            end
        end
    end
end

-- A on someone: their page opened (the row's click), and over onto it, on
-- their name; their page already open, back where the pad was on it.
function scope.Open(guid)
    local f = scope.focus
    if J.selected ~= guid or not Reading() then
        scope.inPlate = nil
        if f then f:Remember("page", nil) end
        ns.UI.SelectPerson(guid)
    end
    scope.seen = J.selected
    if f and Reading() then f:EnterGroup("page") end
end

-- A on the plate (or a glimpse's print): among its marks, the highest
-- first; B comes back to it.
function scope.EnterMarks(group, key)
    local f = scope.focus
    scope.inPlate = true
    scope.plateAt = { group or "page", key or "plate" }
    Pad.Refresh()
    if not (f and f:EnterGroup("marks")) then scope.inPlate = nil end
end

-- A on a glimpse's foot strip: its link ("+ Add"); the page inked where it
-- lies is their page, the pad on their name, B back to their row.
function scope.AddGlimpse()
    local f = scope.focus
    local guid = J.glimpse
    local strip = J.journal.glimpse.strip
    if strip.foot then strip.foot:Click("LeftButton") end
    if not (guid and ns.Diary.Get(guid) and f) then return end
    scope.seen = J.selected
    f:Remember("left", Key(guid))
    f:Remember("page", "header")
    Pad.Refresh()
    f:EnterGroup("page")
end

-- X on the plate or a mark: the plate's click (the map sheet), where the
-- pad was kept for B.
local function Whole()
    local f = scope.focus
    local at = f and f:Current()
    local plate = at and at.whole and at.whole()
    if not (plate and plate.onClick and Reading()) or OnMap() then return false end
    scope.fromMap = { group = at.group, key = at.key, inPlate = scope.inPlate }
    plate.onClick(plate)
    return true
end

-- B, one step out.
function scope.back()
    local f = scope.focus
    if not f then return false end
    local box = J.journal and Search()
    if box and box:HasFocus() then
        box:ClearFocus()
        return true
    end
    if OnMap() then
        local from = scope.fromMap or { group = "tabs", key = "tab:map" }
        scope.fromMap = nil
        scope.inPlate = from.inPlate
        f:Remember(from.group, from.key)
        f:Within(from.group)
        J.tab = "timeline"
        J.RefreshProfile()
        return true
    end
    local at = f:Current()
    if not at then return false end
    if at.group == "marks" then
        scope.inPlate = nil
        local back = scope.plateAt or { "page", "plate" }
        f:Remember(back[1], back[2])
        f:Within(back[1])
        Pad.Refresh()
        return true
    end
    -- (the key listening for a key: it stops)
    local setter = scope.setter
    if setter and setter.listening then
        setter:Stop()
        Pad.Refresh()
        return true
    end
    if at.group == "page" or at.group == "tabs" or at.group == "glimpse" then
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
    PAD3 = Whole,
}

function scope.legend()
    local at = scope.focus and scope.focus:Current()
    if not at then return {} end
    if at.prompt then return { at.prompt } end
    local out = {}
    local k = at.kind
    if k == "search" then
        local writing = Search():HasFocus()
        out[1] = writing and PROMPT.done or PROMPT.write
        if writing then out[2] = PROMPT.stop end
        return out
    elseif k == "sort" then
        return { PROMPT.choose, PROMPT.sorts }
    elseif k == "filter" then
        return { PROMPT.choose }
    elseif k == "person" then
        if J.glimpse and J.journal.glimpse:IsShown() then return { PROMPT.open, PROMPT.glimpse } end
        return { PROMPT.open }
    elseif k == "link" and at.group == "sheet" then
        return { PROMPT.choose, PROMPT.away }
    elseif k == "mark" then
        return { PROMPT.map, PROMPT.backPlate }
    elseif k == "plate" then
        out = at.whole():HasMarks() and { PROMPT.marks, PROMPT.map } or { PROMPT.map }
    elseif k == "strip" then
        if at.strip.guid and at.strip.onClick then out[1] = PROMPT.person end
    elseif k == "line" then
        local line = at.line
        if line.visit then
            local floors = ns.Dungeons.Floors(line.visit.visit.instanceID)
            out[1] = floors and PROMPT.run or PROMPT.runSheet
        elseif line.note then
            out[1] = PROMPT.note
        elseif Folds(line) then
            out[1] = Open(Folds(line)) and PROMPT.fold or PROMPT.unfold
        end
    elseif k == "tab" then
        out[1] = ({ map = PROMPT.seen, note = PROMPT.addNote, edit = PROMPT.edit })[at.tab] or PROMPT.story
    elseif k == "setter" or k == "book" or k == "link" and at.control then
        out[1] = Pad.Controls.Prompt(at)
        if k == "setter" and at.control.listening then out[2] = PROMPT.stopKey end
        if J.glimpse and ns.UI.Glimpse and J.journal.glimpse:IsShown() then out[#out + 1] = PROMPT.glimpse end
        return out
    elseif k == "glimpsePrint" then
        if at.whole():HasMarks() then out[1] = PROMPT.marks end
    elseif k == "glimpseStrip" then
        out[1] = PROMPT.add
    end
    if at.group == "glimpse" then
        out[#out + 1] = ns.Diary.Count() > 0 and PROMPT.back or PROMPT.backStart
        return out
    end
    if at.group == "page" then out[#out + 1] = PROMPT.tabs end
    out[#out + 1] = PROMPT.back
    return out
end

Pad.RegisterScope("people", scope)
