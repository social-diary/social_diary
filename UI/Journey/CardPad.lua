-- The custom card's slip with the pad (.claude/controller-plan.md, step 4c;
-- the slip is UI/Journey/CardSheet.lua, the data Core/Custom.lua).
--
-- Y on Your Diary's right page opens it (UI/Journey/Pad.lua: what a right
-- click does). While it lies on the book this scope has the pad, over the
-- page's (`layer` above it), and with no parent: the book under the slip takes
-- no clicks while it is up, so the pad turns no ribbon either.
--
-- Its controls are found on the slip, not listed, as the settings' are
-- (UI/Settings/Pad.lua): every one shown, in the order they lie, top down and
-- left to right (a button's middle on the sheet, `padAt`, kept by the sheet's
-- PlaceButton), so a later kind's form needs nothing here. What each is, by
-- what it is made of:
--   a choice's box (Style.Checkbox)    A ticks or unticks it
--   a line to write on (WritingLine)   A gives it the keyboard's cursor (there
--                                      is no on-screen keyboard to rely on); A
--                                      again, B, or the pad moving off takes it
--                                      back
--   a link (Save, Cancel, Delete, ...) A follows it, as a click
-- Each wears the pen's box (UI/Pad/Look.lua), its row's label the
-- subheading over it, red. A person's line offers who the search finds as it
-- is written on: down goes into the names, A on one picks it (and the line
-- lets go), up off the first or B goes back to the line.
--
-- The picker (a new card: which kind) is a grid of paper strips, two to a row:
-- the D-pad walks it as it lies, each strip outlined in red as a margin card
-- is, A on one opens its form. Its Cancel is under the grid.
--
-- B is one step back: off the names to the line, off a line being written on,
-- then the slip put away unwritten (its Cancel), and the pad is back on the
-- plate, mark or card Y was pressed on. Deleting a card asks first, through
-- Blizzard's popup, and the pad steps aside while it is up (Pad.Aside,
-- UI/Kit/Confirm.lua).

local addonName, ns = ...

local L = ns.L

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local CardSheet = ns.UI.YourDiary.CardSheet

local function View()
    local view = CardSheet.View()
    return view and view:IsShown() and view or nil
end

local PROMPT = {
    choose = { "PAD1", L["Choose"], main = true },
    write = { "PAD1", L["Write"], main = true },
    done = { "PAD1", L["Done writing"], main = true },
    names = { "PADDDOWN", L["Go to the names"] },
    away = { "PAD2", L["Put the card away"] },
    stop = { "PAD2", L["Stop writing"] },
    line = { "PAD2", L["Back to the line"] },
}

-- How far over the slip the box is drawn: over its controls and the names a
-- person's line offers (CardSheet's PERSON.level, 20, over the sheet).
local OVER = 30

local function TypeOf(w)
    -- (the mock's widgets say frameType, the client's GetObjectType)
    return w.frameType or w:GetObjectType()
end

-- What a control is, by what it is made of (lowercase fields: the widgets'
-- own, safe to read on any frame).
local function Kind(w)
    if w.tick and w.label then return "switch" end
    if w.line and w.label then return "link" end
    if w.line and TypeOf(w) == "EditBox" then return "field" end
end

-- The slip's controls shown, in the order they lie; the picker's list and a
-- person's names are not gone into (they are walked on their own).
local function Collect(frame, out, skip)
    for _, child in ipairs({ frame:GetChildren() }) do
        if not skip[child] and child:IsShown() then
            local kind = Kind(child)
            if kind then
                out[#out + 1] = { frame = child, kind = kind }
            else
                Collect(child, out, skip)
            end
        end
    end
    return out
end

local function Reading(list)
    local function At(c) return c.frame.padAt or { math.huge, math.huge } end
    table.sort(list, function(a, b)
        local pa, pb = At(a), At(b)
        if math.abs(pa[2] - pb[2]) > 3 then return pa[2] < pb[2] end
        return pa[1] < pb[1]
    end)
    return list
end

-- The open form's rows, every kind's made so far: what each control is the
-- line or box of (its key), and a person's names to skip.
local function Rows(view)
    local names, found = {}, {}
    for _, rows in pairs(view.rowsOf or {}) do
        for _, row in ipairs(rows) do
            local key = row.field.key
            if row.box then names[row.box] = "field:" .. key end
            for value, box in pairs(row.toggles or {}) do names[box] = "tick:" .. key .. ":" .. tostring(value) end
            if row.found then found[row.found] = row end
        end
    end
    return names, found
end

-- Every line lets go of the cursor (but `keep`), and its names are put away.
local function LetGo(view, keep)
    for _, rows in pairs(view.rowsOf or {}) do
        for _, row in ipairs(rows) do
            if row.box and row.box ~= keep then
                row.box:ClearFocus()
                if row.found then row.found:Hide() end
            end
        end
    end
end

local function Writing(view)
    for _, rows in pairs(view.rowsOf or {}) do
        for _, row in ipairs(rows) do
            if row.box and row.box:HasFocus() then return row end
        end
    end
end

local scope = {
    layer = 30,
    host = function() return J.journal end,
    active = function() return View() ~= nil end,
}

local function Click(frame) frame:Click("LeftButton") end

local function Control(view, found, name, i)
    local w, kind = found.frame, found.kind
    local item = { key = name or (kind .. ":" .. i), frame = w, kind = kind, clip = view.sheet,
        level = view.sheet:GetFrameLevel() + OVER }
    item.available = function() return w:IsShown() end
    if kind == "field" then
        -- (the line itself boxed, its label red over it; the cursor A's)
        item.enter = function() LetGo(view, w) end
        item.leave = function() end
        item.press = function()
            if w:HasFocus() then
                LetGo(view)
            else
                w:SetFocus()
            end
        end
        -- (a person's line: who the search finds, hung under it)
        local row
        for _, r in ipairs(view.rows or {}) do
            if r.box == w and r.found then row = r end
        end
        item.person = row
    else
        item.enter = function()
            LetGo(view)
            local fn = w:GetScript("OnEnter")
            if fn then fn(w, false) end
        end
        item.press = function() Click(w) end
    end
    return item
end

-- A person's names, while they are offered.
local function Names(f, view, row)
    for i, line in ipairs(row.rows) do
        f:Add("found", {
            key = "name:" .. i, frame = line, words = line.text, clip = view.sheet,
            level = view.sheet:GetFrameLevel() + OVER,
            available = function() return row.found:IsShown() and line:IsShown() end,
            enter = function() end, leave = function() end,
            press = function()
                Click(line)
                LetGo(view)
                Pad.Refresh()
                scope.focus:EnterGroup("form")
            end,
        })
    end
end

-- The picker's strips, a row at a time (the list is virtual: a strip is found
-- as the pad lands on it, scrolled into view).
local function FindCell(item)
    local view = View()
    if not view then return end
    view.list:Reveal(item.index)
    local row = view.list:RowOf(item.index)
    local cell = row and row.cells[item.col]
    item.cell = cell
    item.frame = cell and cell.strip.link or nil
    item.heading = cell and cell.title or nil
end

local grid = {}

local function Picker(f, view, skip)
    wipe(grid)
    for index, kinds in ipairs(view.list.data or {}) do
        grid[index] = {}
        for col, k in ipairs(kinds) do
            local key = "kind:" .. k.kind
            grid[index][col] = key
            local item
            item = {
                key = key, index = index, col = col, kind = "cell",
                available = function() return true end,
                outline = function()
                    local cell = item.cell
                    if not (cell and cell.strip:IsShown()) then return nil end
                    local at = cell.strip:Focus()
                    return { anchor = cell.strip:GetParent(), corners = at.corners, level = cell.strip:GetFrameLevel() }
                end,
                press = function()
                    if item.frame then Click(item.frame) end
                end,
            }
            f:Add("picker", item)
        end
    end
    -- (and under it, Cancel)
    scope.foot = nil
    for i, found in ipairs(Reading(Collect(view.sheet, {}, skip))) do
        local item = f:Add("picker", Control(view, found, found.kind == "link" and ("link:" .. tostring(found.frame:GetText())) or nil, i))
        scope.foot = scope.foot or item.key
    end
end

function scope.build(f)
    f:Group("form", { mode = "list" })
    f:Group("found", { mode = "list", up = "form" })
    f:Group("picker", { mode = "list", reveal = FindCell })
    local view = View()
    if not view then return end
    local names, found = Rows(view)
    local skip = { [view.list] = true }
    for frame in pairs(found) do skip[frame] = true end

    -- (a form opened afresh: on its first control; the picker for a new spot
    -- on its first strip, but back from a form ("Choose another") on the kind
    -- that was chosen)
    local opened = tostring(view.kind) .. ":" .. tostring(view.rec) .. ":" .. tostring(view.where)
    local picking = view.list:IsShown()
    if opened ~= scope.opened then
        scope.opened = opened
        f:Remember("form", nil)
        f:Remember("found", nil)
    end
    if view.where ~= scope.where then
        scope.where = view.where
        f:Remember("picker", nil)
    end
    f:Within(picking and "picker" or "form")

    if picking then return Picker(f, view, skip) end
    for i, c in ipairs(Reading(Collect(view.sheet, {}, skip))) do
        local name = names[c.frame] or (c.kind == "link" and ("link:" .. tostring(c.frame:GetText()))) or nil
        f:Add("form", Control(view, c, name, i))
    end
    for _, row in pairs(found) do
        if row.found:IsShown() then Names(f, view, row) end
    end
end

-- The picker walked as it lies: up and down a row, left and right along it;
-- down off the last row is Cancel, up from Cancel the last row.
local function Grid(dir)
    return function()
        local f = scope.focus
        local at = f and f:Current()
        if not (at and at.group == "picker") then return false end
        local key
        if at.index then
            local row = grid[at.index]
            if dir == "LEFT" or dir == "RIGHT" then
                key = row[at.col + (dir == "LEFT" and -1 or 1)]
            else
                local to = grid[at.index + (dir == "UP" and -1 or 1)]
                key = to and (to[at.col] or to[#to])
                if not to and dir == "DOWN" then key = scope.foot end
            end
        elseif dir == "UP" and grid[#grid] then
            key = grid[#grid][1]
        end
        if key then f:Focus(key, "picker") end
        return true
    end
end

-- Down on a person's line with names offered: into them (built again first:
-- they change as the line is written on).
local function Down()
    local f = scope.focus
    local at = f and f:Current()
    if at and at.group == "picker" then return Grid("DOWN")() end
    local row = at and at.person
    if not (row and row.found:IsShown()) then return false end
    Pad.Refresh()
    return f:EnterGroup("found") or false
end

scope.keys = {
    PADDUP = Grid("UP"), PADDDOWN = Down, PADDLEFT = Grid("LEFT"), PADDRIGHT = Grid("RIGHT"),
}

-- B: off the names to the line; off a line being written on; else the slip
-- put away unwritten.
function scope.back()
    local view = View()
    local f = scope.focus
    if not (view and f) then return false end
    local at = f:Current()
    if at and at.group == "found" then
        f:EnterGroup("form")
        return true
    end
    if Writing(view) then
        LetGo(view)
        return true
    end
    Click(view.cancel)
    return true
end

function scope.legend()
    local view = View()
    local at = scope.focus and scope.focus:Current()
    if not (view and at) then return {} end
    local out = {}
    if at.kind == "switch" then
        out[1] = { "PAD1", at.frame:GetChecked() and L["Untick"] or L["Tick"], main = true }
    elseif at.kind == "field" then
        out[1] = at.frame:HasFocus() and PROMPT.done or PROMPT.write
        if at.person and at.person.found:IsShown() then out[#out + 1] = PROMPT.names end
    else
        out[1] = PROMPT.choose
    end
    if at.group == "found" then
        out[#out + 1] = PROMPT.line
    elseif Writing(view) then
        out[#out + 1] = PROMPT.stop
    else
        out[#out + 1] = PROMPT.away
    end
    return out
end

Pad.RegisterScope("cards", scope)
