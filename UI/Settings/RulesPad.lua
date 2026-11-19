-- Auto-Add's rule sheet with the pad (UI/Settings/Rules.lua;
-- .claude/features/auto-add-rules-ui.md §5).
--
-- The sheet lies over the Settings page, so this scope is over the page's
-- (layer 30, as the custom card's slip and the note sheet), with no parent:
-- the book under the sheet takes no clicks while it is up, so the pad turns
-- no ribbon either. It was opened from the book by the player (the "Auto-Add
-- Players" switch's words with X, or the switch), so it needs no Pad.Opened
-- of its own.
--
-- Three groups, from what the sheet recorded as it was laid (view.items:
-- each control with a stable key, in reading order):
--   list  the index's lines ("rule:<id>"), the "Undo" lines, "+ New rule",
--         then "Done". A on a line opens its form, the pad on its trigger;
--         Y lays its menu out on the pad's own slip (Rules.RowMenu, the
--         mouse's right click's generator). Right goes to the form.
--   form  the open rule's controls in reading order: up and down walk them
--         one at a time (as the custom card's slip); left and right belong
--         to the control: a choice steps to the
--         next trigger (Rules.Cycle), a number climbs its ladder, the class
--         icons and the boxes on one line step along it. A does what a click
--         does; on the trigger it lays the choices out on the pad's menu
--         (Rules.TriggerMenu, the mouse's generator). Leaving it is B.
--   pick  the four starting strips, then Cancel, in place of the form.
-- B, one step at a time, on its release: off a line being written in (what
-- it holds is kept), then out of the picker (back to the list, on the rule
-- that was open), then out of the form (back to its index line), then the
-- sheet put away, and the pad is back on "Auto-Add Players" in Settings
-- (the settings scope kept its place). Putting it away may ask the backfill
-- question, whose sheet takes the pad (UI/Windows/Pad.lua's `autoadd`).

local addonName, ns = ...

local L = ns.L

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Rules = ns.UI.AutoAddRules

-- How far over the sheet the box is drawn (over its controls, as CardPad's).
local OVER = 30

-- copy TBD (copywriter)
local PROMPT = {
    open = { "PAD1", L["Open the rule"], main = true },
    menu = { "PAD4", L["Open the menu"] },
    choose = { "PAD1", L["Choose"], main = true },
    start = { "PAD1", L["Start from it"], main = true },
    change = { { "PADDLEFT", "PADDRIGHT" }, L["Change it"], main = true },
    choices = { "PAD1", L["See the choices"] },
    step = { { "PADDLEFT", "PADDRIGHT" }, L["Less or more"], main = true },
    add = { "PAD1", L["Add it"], main = true },
    remove = { "PAD1", L["Remove it"], main = true },
    tag = { "PAD1", L["Add the tag"], main = true },
    write = { "PAD1", L["Write"], main = true },
    done = { "PAD1", L["Done writing"], main = true },
    stop = { "PAD2", L["Stop writing"] },
    list = { "PAD2", L["Back to the rules"] },
    away = { "PAD2", L["Put the rules away"] },
}

local function View()
    local view = Rules.View()
    return view and view:IsShown() and view or nil
end

local scope = {
    layer = 30,
    host = function() return J.journal end,
    active = function() return View() ~= nil end,
}

local function Click(frame) frame:Click("LeftButton") end

local function Run(frame, script)
    local fn = frame and frame:GetScript(script)
    if fn then fn(frame, false) end
end

-- Another item of `group` on the line of `item` (the same y), `by` along.
local function Along(group, item, by)
    local line = {}
    for _, it in ipairs(scope.focus.groups[group].items) do
        if it.y == item.y and (it.available == nil or it.available()) then line[#line + 1] = it end
    end
    table.sort(line, function(a, b) return (a.x or 0) < (b.x or 0) end)
    for i, it in ipairs(line) do
        if it == item then return line[i + by] end
    end
end

-- A focus item from what the sheet recorded.
local function Make(view, group, rec)
    local w = rec.frame
    local item = { key = rec.key, kind = rec.kind, frame = w, words = rec.words, subhead = rec.subhead,
        y = rec.y, x = rec.x, rule = rec.rule, radio = rec.radio, level = view.sheet:GetFrameLevel() + OVER, clip = view.sheet }
    item.available = function() return w == nil or w:IsShown() end
    item.enter = function()
        Rules.LetGo(rec.kind == "field" and w or nil)
        Run(w, "OnEnter")
    end
    item.leave = function() Run(w, "OnLeave") end
    local kind = rec.kind
    if kind == "rule" then
        item.press = function() Click(w) end
    elseif kind == "choice" then
        item.press = function() Pad.Menu.Open(w, Rules.TriggerMenu()) end
        item.step = function(dir)
            Rules.Cycle(dir)
            return true
        end
    elseif kind == "number" then
        item.enter = function() Rules.LetGo(w) end
        item.leave = function() end
        item.press = function()
            if w:HasFocus() then w:ClearFocus() else w:SetFocus() end
        end
        item.step = function(dir)
            w:Nudge(dir == "RIGHT" and 1 or -1)
            Pad.Look.Step(J.journal, item, dir)
            return true
        end
    elseif kind == "field" then
        item.leave = function() end
        item.press = function()
            if w:HasFocus() then w:ClearFocus() else w:SetFocus() end
        end
    elseif kind == "strip" or kind == "start" then
        local strip = rec.strip
        item.frame = nil
        item.heading = rec.heading
        item.available = function() return strip:IsShown() end
        item.outline = function()
            if not strip:IsShown() then return nil end
            local at = strip:Focus()
            return { anchor = strip:GetParent(), corners = at.corners, level = strip:GetFrameLevel() }
        end
        item.enter = function() Rules.LetGo() end
        item.leave = function() end
        item.press = function() Click(strip:Focus().frame) end
    elseif kind == "icon" then
        item.ring = true
        item.class = rec.class
        item.press = function() Click(w) end
    elseif kind == "chip" then
        item.plain = true
        item.press = function() Click(w) end
    else
        item.press = function() Click(w) end
    end
    -- (left and right along a line of boxes, chips or icons)
    if not item.step and group == "form" then
        item.step = function(dir)
            local to = Along(group, item, dir == "LEFT" and -1 or 1)
            if to then scope.focus:Set(to) end
            return true
        end
    end
    return item
end

function scope.build(f)
    f:Group("list", { mode = "list", right = function() return Rules.State().picking and "pick" or "form" end })
    f:Group("form", { mode = "list" })
    f:Group("pick", { mode = "list" })
    local view = View()
    if not view then return end
    local items = view.items or {}
    for _, group in ipairs({ "list", "form", "pick" }) do
        local list = {}
        for i, rec in ipairs(items[group] or {}) do list[i] = { rec = rec, i = i } end
        -- (the form in reading order: by line, then along it)
        if group == "form" then
            table.sort(list, function(a, b)
                local ya, yb = a.rec.y or 0, b.rec.y or 0
                if math.abs(ya - yb) > 3 then return ya < yb end
                if (a.rec.x or 0) ~= (b.rec.x or 0) then return (a.rec.x or 0) < (b.rec.x or 0) end
                return a.i < b.i
            end)
        end
        for _, at in ipairs(list) do f:Add(group, Make(view, group, at.rec)) end
    end
    -- (where the sheet said the pad goes: a form opened on its trigger, a
    -- filter added on its first control, a delete on its Undo line)
    local to = view.padTo
    if to then
        view.padTo = nil
        f:Within(to.group)
        f:Remember(to.group, to.key)
    end
    -- (the picker gone, or a form with nothing: back on the list)
    local g = f.group
    if g and not (items[g] and items[g][1]) then f:Within("list") end
end

-- Y on an index line: its menu, on the pad's slip.
local function Menu()
    local at = scope.focus and scope.focus:Current()
    if not (at and at.kind == "rule" and at.rule) then return false end
    Pad.Menu.Open(at.frame, Rules.RowMenu(at.rule))
    return true
end

scope.keys = { PAD4 = Menu }

-- B: off a line being written in; out of the picker; out of the form to its
-- line; else the sheet put away.
function scope.back()
    local view = View()
    local f = scope.focus
    if not (view and f) then return false end
    if Rules.Writing() then
        Rules.LetGo()
        return true
    end
    local at = f:Current()
    if Rules.State().picking and #ns.AutoAdd.Rules() > 0 then
        Rules.CancelPick()
        return true
    end
    if at and at.group ~= "list" then
        local open = Rules.State().open
        f:Remember("list", open and ("rule:" .. open) or nil)
        f:EnterGroup("list")
        return true
    end
    Rules.Close()
    return true
end

function scope.legend()
    local at = scope.focus and scope.focus:Current()
    if not at then return {} end
    local out = {}
    local kind = at.kind
    if kind == "rule" then
        out[1], out[2] = PROMPT.open, PROMPT.menu
    elseif kind == "choice" then
        out[1], out[2] = PROMPT.change, PROMPT.choices
    elseif kind == "number" then
        out[1] = at.frame:HasFocus() and PROMPT.done or PROMPT.step
    elseif kind == "field" then
        out[1] = at.frame:HasFocus() and PROMPT.done or PROMPT.write
    elseif kind == "start" then
        out[1] = PROMPT.start
    elseif kind == "strip" then
        out[1] = PROMPT.add
    elseif kind == "switch" then
        if at.radio then out[1] = PROMPT.choose
        else out[1] = { "PAD1", at.frame:GetChecked() and L["Untick"] or L["Tick"], main = true } end
    elseif kind == "icon" then
        local set = Rules.Rule() and Rules.Rule().filters and Rules.Rule().filters.class
        out[1] = { "PAD1", (set and set[at.class]) and L["Untick"] or L["Tick"], main = true }
    elseif kind == "chip" then
        out[1] = PROMPT.tag
    elseif kind == "link" and at.key:find("^off:") then
        out[1] = PROMPT.remove
    else
        out[1] = PROMPT.choose
    end
    if Rules.Writing() then
        out[#out + 1] = PROMPT.stop
    elseif at.group == "list" then
        out[#out + 1] = PROMPT.away
    else
        out[#out + 1] = PROMPT.list
    end
    return out
end

Pad.RegisterScope("autoaddrules", scope)
