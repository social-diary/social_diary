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
-- is written on (an item's line, the player's own items): down goes into the
-- names, A on one picks it (and the line lets go), up off the first or B goes
-- back to the line.
--
-- The free card's controls (note-card.md, phase 3), found the same way:
--   an icon of the grid (cell.iconKey)  A chooses it; the pen's ring round
--                                      it. Left and right step along the
--                                      sixteen, up and down between their
--                                      two rows, and off the grid to the
--                                      control over or under it
--   a "+ Add" strip (strip.addKey)     outlined in red as a margin card is;
--                                      A adds its field, and the pad goes to
--                                      the field's line (the cursor stays
--                                      A's to give)
--   "Remove"                           a link, as Save is: A follows; taken
--                                      off, the pad goes to the field's strip
--   a face of who was there            the pen's ring, their name its tooltip;
--                                      A takes them off (its cross), the pad
--                                      on the next face or the line. Picking
--                                      a name from the line's search adds a
--                                      face, the pad back on the line
--   the caption's box                  a choice's box: A ticks or unticks
--   an inserted card's foot            Delete, Cancel, Save on one line:
--                                      left and right along it; down onto
--                                      it lands on Save, never on Delete;
--                                      up off it, the control over it
--                                      (scope.Foot)
-- The card beside the form (CardSheet's preview) is only looked at: it is
-- on the view, not the slip, so it is never found as a control.
-- Shift-clicking an item into its line is the mouse's alone: the pad has the
-- item search (rule 5 of the controller-support skill: never click an item
-- for the pad).
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
    add = { "PAD1", L["Add"], main = true },
    off = { "PAD1", L["Take them off the card"], main = true },
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
    if w.iconKey then return "icon" end
    if rawget(w, "SetCharacter") and type(w.cross) == "table" then return "face" end
    if w.tick and w.label then return "switch" end
    if w.line and w.label then return "link" end
    if w.line and TypeOf(w) == "EditBox" then return "field" end
end

-- The slip's controls shown, in the order they lie; the picker's list and a
-- person's names are not gone into (they are walked on their own).
local function Collect(frame, out, skip)
    for _, child in ipairs({ frame:GetChildren() }) do
        if not skip[child] and child:IsShown() then
            local kind = child.addKey and "strip" or Kind(child)
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

-- Every line of every kind's rows made so far (CardSheet.Lines: a row's
-- own, or each of a people's), with the key it is known by.
local function AllLines(view)
    local out = {}
    for _, rows in pairs(view.rowsOf or {}) do
        for _, row in ipairs(rows) do
            for _, line in ipairs(row.lines or CardSheet.Lines(row)) do
                out[#out + 1] = { line = line, key = line.key or row.field.key }
            end
        end
    end
    return out
end

-- The open form's rows, every kind's made so far: what each control is the
-- line or box of (its key), and the names hung under a line, to skip.
local function Rows(view)
    local names, found = {}, {}
    for _, at in ipairs(AllLines(view)) do
        names[at.line.box] = "field:" .. at.key
        if at.line.found then found[at.line.found] = at.line end
    end
    for _, rows in pairs(view.rowsOf or {}) do
        for _, row in ipairs(rows) do
            local key = row.field.key
            for value, box in pairs(row.toggles or {}) do names[box] = "tick:" .. key .. ":" .. tostring(value) end
            for _, cell in ipairs(row.cells or {}) do names[cell] = "icon:" .. cell.iconKey end
            if row.flag then names[row.flag] = "tick:" .. key end
            if row.off then names[row.off] = "off:" .. key end
            for i, o in ipairs(row.faces or {}) do names[o] = "face:" .. key .. ":" .. i end
            if row.add then names[row.add] = "more:" .. key end
        end
    end
    return names, found
end

-- Every line lets go of the cursor (but `keep`), and its names are put away.
local function LetGo(view, keep)
    for _, at in ipairs(AllLines(view)) do
        local line = at.line
        if line.box ~= keep then
            line.box:ClearFocus()
            if line.found then line.found:Hide() end
        end
    end
end

local function Writing(view)
    for _, at in ipairs(AllLines(view)) do
        if at.line.box:HasFocus() then return at.line end
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
        -- (a person's line, or an item's: what the search finds, hung
        -- under it)
        for _, at in ipairs(AllLines(view)) do
            if at.line.box == w and at.line.found then item.person = at.line end
        end
    elseif kind == "strip" then
        -- (outlined as a margin card is, the picker's strips too)
        item.outline = function()
            if not w:IsShown() then return nil end
            local at = w:Focus()
            return { anchor = w:GetParent(), corners = at.corners, level = w:GetFrameLevel() }
        end
        item.enter = function() LetGo(view) end
        item.leave = function() end
        item.press = function() Click(w:Focus().frame) end
    elseif kind == "face" then
        -- (who was there: the pen's ring round their face, their name its
        -- tooltip; A takes them off, as a click on its cross)
        item.ring = true
        item.enter = function()
            LetGo(view)
            local fn = w:GetScript("OnEnter")
            if fn then fn(w, false) end
        end
        item.press = function() Click(w.cross) end
    elseif kind == "icon" then
        -- (a pen's ring round it, as round a mark; its name its tooltip)
        item.ring = true
        item.icon = w.at
        item.enter = function()
            LetGo(view)
            local fn = w:GetScript("OnEnter")
            if fn then fn(w, false) end
        end
        item.press = function() Click(w) end
        item.step = function(dir) return scope.Icon(dir == "LEFT" and -1 or 1, true) end
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
    -- (a field added or taken off: the pad on its line, or on its strip)
    if view.padFocus then
        f:Remember("form", view.padFocus)
        view.padFocus = nil
    end
    for i, c in ipairs(Reading(Collect(view.sheet, {}, skip))) do
        local name = names[c.frame] or (c.kind == "link" and ("link:" .. tostring(c.frame:GetText()))) or nil
        f:Add("form", Control(view, c, name, i))
    end
    scope.Foot(f, view)
    for _, row in pairs(found) do
        if row.found:IsShown() then Names(f, view, row) end
    end
end

-- An inserted card's foot: Delete at its left, Cancel and Save at its right,
-- on one line (CardSheet's Lay). Walked as it lies: left and right along it
-- (Delete, Cancel, Save), down onto it from the form lands on Save, never on
-- Delete, and up off any of it goes back to the control over it. A foot with
-- no Delete (a new card's "Choose another", a detected card's) is walked as
-- the list it is. scope.footed: the foot's items, left to right, or nil.
function scope.Foot(f, view)
    scope.footed = nil
    local save, remove = view.save.padAt, view.remove.padAt
    if not (view.remove:IsShown() and save and remove and math.abs(remove[2] - save[2]) <= 3) then return end
    local foot = {}
    for _, item in ipairs(f.groups.form.items) do
        local at = item.frame and item.frame.padAt
        if item.kind == "link" and at and math.abs(at[2] - save[2]) <= 3 then
            foot[#foot + 1] = item
            item.foot = true
        end
    end
    table.sort(foot, function(a, b) return a.frame.padAt[1] < b.frame.padAt[1] end)
    for i, item in ipairs(foot) do
        item.step = function(dir)
            local to = foot[i + (dir == "LEFT" and -1 or 1)]
            if to then f:Set(to) end
            return true
        end
    end
    scope.footed = foot
end

-- Down or up across the line of an inserted card's foot (scope.Foot): true
-- where it was taken.
local function AcrossFoot(dir)
    local f, foot = scope.focus, scope.footed
    local at = f and f:Current()
    if not (foot and at and at.group == "form") then return false end
    local items = f.groups.form.items
    local function Index(item)
        for i, other in ipairs(items) do if other == item then return i end end
    end
    local function Open(item) return item.available == nil or item.available() end
    if dir == "DOWN" and not at.foot then
        for k = (Index(at) or #items) + 1, #items do
            local item = items[k]
            if Open(item) then
                if not item.foot then return false end
                f:Set(foot[#foot])
                return true
            end
        end
        return false
    elseif dir == "UP" and at.foot then
        for k = (Index(foot[1]) or 1) - 1, 1, -1 do
            local item = items[k]
            if not item.foot and Open(item) then
                f:Set(item)
                return true
            end
        end
        return true
    elseif dir == "DOWN" and at.foot then
        return true
    end
    return false
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

-- On the icon grid: `by` along the sixteen (`along`: left and right, kept
-- to the grid), else a row up or down, and off it to the control over or
-- under it (the list's own next, past the grid).
function scope.Icon(by, along)
    local f = scope.focus
    local at = f and f:Current()
    if not (at and at.icon) then return false end
    local items = f.groups.form.items
    local first, last
    for i, item in ipairs(items) do
        if item.icon then
            first = first or i
            last = i
        end
    end
    local to = at.icon + by
    local count = last - first + 1
    if along then
        if to < 1 or to > count then return true end
        f:Set(items[first + to - 1])
        return true
    end
    local item
    if to >= 1 and to <= count then
        item = items[first + to - 1]
    else
        local k = by < 0 and first - 1 or last + 1
        item = items[k]
    end
    if item then f:Set(item) end
    return true
end

local function Rows8(dir)
    return function()
        local f = scope.focus
        local at = f and f:Current()
        if at and at.icon then
            local across = CardSheet.ICONS.across
            return scope.Icon(dir == "UP" and -across or across)
        end
        if AcrossFoot(dir) then return true end
        return Grid(dir)()
    end
end

-- Down on a person's line with names offered: into them (built again first:
-- they change as the line is written on).
local function Down()
    local f = scope.focus
    local at = f and f:Current()
    if at and at.icon then return Rows8("DOWN")() end
    if at and at.group == "picker" then return Grid("DOWN")() end
    if AcrossFoot("DOWN") then return true end
    local row = at and at.person
    if not (row and row.found:IsShown()) then return false end
    Pad.Refresh()
    return f:EnterGroup("found") or false
end

scope.keys = {
    PADDUP = Rows8("UP"), PADDDOWN = Down, PADDLEFT = Grid("LEFT"), PADDRIGHT = Grid("RIGHT"),
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
    elseif at.kind == "strip" then
        out[1] = PROMPT.add
    elseif at.kind == "face" then
        out[1] = PROMPT.off
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
