-- Where the pad is on a page: the things it can stand on, and how the
-- D-pad moves between them (.claude/controller-plan.md, the focus model).
--
--   local f = Pad.Focus.New({ mark = fn(item), unmark = fn(item), step = fn(item, dir) })
--   f:Group("nav",  { mode = "list", right = "pane" })
--   f:Group("pane", { mode = "list", left = "nav", reveal = fn(item) })
--   f:Add("nav", frame)                -- a frame: clicked by A
--   f:Add("pane", { key = "sound", frame = row, press = fn, step = fn(dir) })
--   f:Done()                           -- after adding: back where it was
--
-- An item is a frame, or a table:
--   key        what it is remembered by, so a page rebuilt keeps its place
--              (default: its frame's place in its group)
--   frame      what it stands on: marked, its OnEnter / OnLeave run for the
--              tooltip, clicked by A where there is no `press`
--   press()    A on it
--   step(dir)  left or right on it ("LEFT" / "RIGHT"), a slider's step;
--              true when it took the press
--   available()  false: skipped (default: its frame is visible)
--   center()   x, y on screen, for an item without a frame (a mark on a
--              plate, later)
--
-- A group's mode is "list" (up and down in the order added) or "spatial"
-- (the nearest item that way). Left and right on a list item with no step,
-- and any way off the end of a group, go to the group named that way
-- (`left`, `right`, `up`, `down`) if any. `wrap` goes round instead.
-- `reveal(item)` is the group's scroll owner, asked to bring an item into
-- view as the pad lands on it.

local addonName, ns = ...

local Pad = ns.UI.Pad

local Focus = {}
Pad.Focus = Focus

local Model = {}
Model.__index = Model

function Focus.New(hooks)
    return setmetatable({
        hooks = hooks or {},
        groups = {}, order = {},
        remembered = {},    -- the key stood on last, by group
        group = nil,        -- the group the pad is in
        at = nil,           -- the item it stands on
        shown = false,      -- marked (the pad in hand, the page open)
    }, Model)
end

-- Empties the items, keeping where the pad was by key, to fill again.
function Model:Clear()
    self:Leave()
    for _, name in ipairs(self.order) do self.groups[name].items = {} end
    self.at = nil
end

function Model:Group(name, opts)
    local g = self.groups[name]
    if not g then
        g = { name = name, items = {} }
        self.groups[name] = g
        self.order[#self.order + 1] = name
    end
    g.opts = opts or {}
    return g
end

function Model:Add(name, item)
    local g = self.groups[name] or self:Group(name)
    -- (a frame: the mock's widgets say frameType, the client's GetObjectType)
    if item.frameType or item.GetObjectType then item = { frame = item } end
    item.group = name
    item.key = item.key or ("#" .. (#g.items + 1))
    g.items[#g.items + 1] = item
    return item
end

local function Available(item)
    if item.available then return item.available() and true or false end
    if item.frame then return item.frame:IsVisible() and true or false end
    return true
end

local function Center(item)
    if item.center then return item.center() end
    if item.frame then return item.frame:GetCenter() end
end

local function Script(frame, name)
    local fn = frame and frame:GetScript(name)
    if fn then fn(frame, false) end
end

-- The mark and the tooltip off the item stood on.
function Model:Leave()
    local item = self.at
    if not (item and self.shown) then return end
    if self.hooks.unmark then self.hooks.unmark(item) end
    if item.leave then item.leave() else Script(item.frame, "OnLeave") end
end

-- And on the item stood on now.
function Model:Enter()
    local item = self.at
    if not (item and self.shown) then return end
    local g = self.groups[item.group]
    if g and g.opts.reveal then g.opts.reveal(item) end
    -- (its own hover look first, the mark over it: a widget that changes
    -- its font on hover would wash the mark's red out)
    if item.enter then item.enter() else Script(item.frame, "OnEnter") end
    if self.hooks.mark then self.hooks.mark(item) end
end

-- Marked or not: the pad in hand on an open page, or put down.
function Model:Show(on)
    on = on and true or false
    if on == self.shown then return end
    if on then
        self.shown = true
        self:Enter()
    else
        self:Leave()
        self.shown = false
    end
end

-- Stands on `item` (an item of this model).
function Model:Set(item)
    if item == self.at then return end
    self:Leave()
    self.at = item
    if item then
        self.group = item.group
        self.remembered[item.group] = item.key
    end
    self:Enter()
end

local function FirstIn(g, key)
    local first
    for _, item in ipairs(g.items) do
        if Available(item) then
            if key and item.key == key then return item end
            first = first or item
        end
    end
    return first
end

-- Where the pad goes back to in group `name`, as if it had stood on `key`
-- last (a page that opened somewhere else meanwhile).
function Model:Remember(name, key)
    self.remembered[name] = key
end

-- The group Done looks in first, as if the pad were in `name` (a scope
-- whose group is gone after a rebuild: the marks of a plate no longer
-- drawn, back on the plates).
function Model:Within(name)
    self.group = name
end

-- Into group `name`: where it was last, else its first item.
function Model:EnterGroup(name)
    local g = self.groups[name]
    local item = g and FirstIn(g, self.remembered[name])
    if not item then return false end
    self:Set(item)
    return true
end

-- Stands on the item with `key` (in `name`, or the group the pad is in).
function Model:Focus(key, name)
    local g = self.groups[name or self.group or self.order[1]]
    if not g then return false end
    for _, item in ipairs(g.items) do
        if item.key == key and Available(item) then
            self:Set(item)
            return true
        end
    end
    return false
end

-- After the items are added: back on the item it stood on, by key, else
-- the first of its group, else the first group that has one.
function Model:Done()
    local name = self.group or self.order[1]
    if name and self:EnterGroup(name) then return end
    for _, other in ipairs(self.order) do
        if self:EnterGroup(other) then return end
    end
    self:Set(nil)
end

function Model:Current() return self.at end

-- The next available item along the list, -1 up or 1 down; nil at the end.
local function Along(g, from, delta)
    local n = #g.items
    local i
    for k, item in ipairs(g.items) do if item == from then i = k end end
    if not i then return nil end
    for step = 1, n - 1 do
        local k = i + delta * step
        if g.opts.wrap then k = (k - 1) % n + 1 elseif k < 1 or k > n then return nil end
        local item = g.items[k]
        if Available(item) then return item end
    end
end

-- The nearest available item that way: along the way counts, across it
-- counts twice, and nothing behind or level counts at all.
local AXIS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local function Nearest(g, from, dir)
    local fx, fy = Center(from)
    if not fx then return nil end
    local ax, ay = AXIS[dir][1], AXIS[dir][2]
    local best, bestScore
    for _, item in ipairs(g.items) do
        if item ~= from and Available(item) then
            local x, y = Center(item)
            if x then
                local dx, dy = x - fx, y - fy
                local along = dx * ax + dy * ay
                if along > 1 then
                    local across = math.abs(dx * ay) + math.abs(dy * ax)
                    local score = along + 2 * across
                    if not bestScore or score < bestScore then best, bestScore = item, score end
                end
            end
        end
    end
    return best
end

-- A D-pad press: "UP", "DOWN", "LEFT" or "RIGHT". True when it moved or a
-- step took it.
function Model:Move(dir)
    local item = self.at
    if not item then
        self:Done()
        return self.at ~= nil
    end
    if (dir == "LEFT" or dir == "RIGHT") and item.step and item.step(dir) then
        if self.hooks.step then self.hooks.step(item, dir) end
        return true
    end
    local g = self.groups[item.group]
    local nextItem
    if g.opts.mode == "spatial" then
        nextItem = Nearest(g, item, dir)
    elseif dir == "UP" or dir == "DOWN" then
        nextItem = Along(g, item, dir == "UP" and -1 or 1)
    end
    if nextItem then
        self:Set(nextItem)
        return true
    end
    local to = g.opts[dir:lower()]
    if to and self:EnterGroup(to) then return true end
    return false
end

-- A: the item's press, else a click on its frame.
function Model:Press()
    local item = self.at
    if not item or not Available(item) then return false end
    if item.press then
        item.press()
    elseif item.frame and item.frame.Click then
        item.frame:Click("LeftButton")
    else
        return false
    end
    return true
end
