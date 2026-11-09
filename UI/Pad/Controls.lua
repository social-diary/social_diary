-- The controls on a form or a sheet, found rather than listed
-- (.claude/controller-plan.md, step 5b): a later field on the entry form,
-- the note's sheet or the link card needs no pad code, as the settings'
-- panes (UI/Settings/Pad.lua) and the custom card's slip
-- (UI/Journey/CardPad.lua) need none.
--
--   local found = Controls.Find(root, skip)   every control shown under
--                       root, in reading order: by the middle a loose
--                       sheet's PlaceButton kept (`padAt`, its own or an
--                       ancestor's under root) when every control has one,
--                       else in the order they were made (a form laid out
--                       top down, as the entry form is). `skip`: frames not
--                       gone into (a virtual list walked on its own)
--   local set = Controls.Add(f, group, found, opts)   each made a focus
--                       item (UI/Pad/Focus.lua) in `group`; opts: `level`,
--                       `clip` (Pad.Look's, for a sheet over the book),
--                       `refresh` (false: a press does not refresh the pad)
--   set.Writing()       the line with the keyboard's cursor, or nil
--   set.LetGo(keep)     every line lets go of the cursor but `keep`
--   Controls.Prompt(item)   A's prompt on it, or nil
--
-- What a control is, by what it is made of (lowercase fields, the widgets'
-- own, safe to read on any frame; a method looked up only with rawget):
--   a tag (Style.TagButton: tag, cross)  A puts it on or takes it off; a
--                       tag of the player's own (its cross shown) A takes
--                       away. Boxed whole, its words left in their colours
--   a face with a cross (Style.Portrait + cross, the note's sheet)  A is the
--                       cross: unlinks them. Ringed, its tooltip shown
--   a face (Style.Portrait)  ringed, its tooltip shown; A does nothing
--   a key (UI/Kit/Keys.lua's setter: keycap, bind)  A listens for a key on
--                       the keyboard (a pad button is never bound: it would
--                       not fire under the Gamepad UI), A again stops
--   a book (UI/Settings/Macro.lua's BookButton: diaryMacro)  A picks it up,
--                       as a click does, for a slot on the controller's
--                       action bar. Its name beside it boxed, its tooltip
--                       shown; faded in a fight, it is passed over
--   a box (Style.Checkbox: tick, label)  A ticks or unticks it
--   a link (Style.Link: line, label)  A follows it, as a click
--   a line or a box to write in (an EditBox)  A gives it the keyboard's
--                       cursor (there is no on-screen keyboard to rely on);
--                       A again, or the pad moving off, takes it back. Its
--                       holder (a search's) or its scroll frame (a ruled
--                       note's) is what is boxed
-- Its subheading is the widget's `group` (a form's label over it, red).

local addonName, ns = ...

local L = ns.L

local Pad = ns.UI.Pad

local Controls = {}
Pad.Controls = Controls

local PROMPT = {
    write = { "PAD1", L["Write"], main = true },
    done = { "PAD1", L["Done writing"], main = true },
    choose = { "PAD1", L["Choose"], main = true },
    tagOn = { "PAD1", L["Add the tag"], main = true },
    tagOff = { "PAD1", L["Take the tag off"], main = true },
    tagAway = { "PAD1", L["Take the tag off"], main = true },
    unlink = { "PAD1", L["Unlink them"], main = true },
    key = { "PAD1", L["Choose a keyboard key"], main = true },
    book = { "PAD1", L["Pick it up"], main = true },
    listening = { "PAD1", L["Stop listening"], main = true },
}
Controls.PROMPT = PROMPT

local function TypeOf(w)
    -- (the mock's widgets say frameType, the client's GetObjectType)
    return w.frameType or w:GetObjectType()
end

function Controls.Kind(w)
    if w.tag ~= nil and type(w.cross) == "table" then return "chip" end
    if rawget(w, "SetCharacter") then
        if type(w.cross) == "table" and w.cross:IsShown() then return "crossed" end
        return "face"
    end
    if w.keycap and w.bind and rawget(w, "Listen") then return "setter" end
    if w.diaryMacro then return "book" end
    if w.tick and w.label then return "switch" end
    if w.line and w.label then return "link" end
    if TypeOf(w) == "EditBox" then return "field" end
end

local function Collect(frame, out, skip)
    for _, child in ipairs({ frame:GetChildren() }) do
        if not skip[child] and child:IsShown() then
            local kind = Controls.Kind(child)
            if kind then
                out[#out + 1] = { frame = child, kind = kind, made = #out + 1 }
            else
                Collect(child, out, skip)
            end
        end
    end
    return out
end

-- The middle a sheet kept for it, or for what it lies in, under root.
local function At(w, root)
    while w and w ~= root do
        if type(w.padAt) == "table" then return w.padAt end
        w = w:GetParent()
    end
end

function Controls.Find(root, skip)
    local out = Collect(root, {}, skip or {})
    for _, c in ipairs(out) do
        c.at = At(c.frame, root)
        if not c.at then return out end
    end
    table.sort(out, function(a, b)
        local pa, pb = a.at, b.at
        if math.abs(pa[2] - pb[2]) > 3 then return pa[2] < pb[2] end
        if math.abs(pa[1] - pb[1]) > 0.5 then return pa[1] < pb[1] end
        return a.made < b.made
    end)
    return out
end

local function Run(frame, script, ...)
    local fn = frame and frame:GetScript(script)
    if fn then fn(frame, ...) end
end

-- What is boxed for a line to write in: its holder, its scroll frame, or it.
local function Shown(w)
    if type(w.holder) == "table" then return w.holder end
    local parent = w:GetParent()
    if parent and TypeOf(parent) == "ScrollFrame" then return parent end
    return w
end

-- Its key, the same each time the form is built: a tag by its words, a face
-- by whom, the rest by the frame (made once, never handed round).
local function KeyOf(c)
    local w = c.frame
    if c.kind == "chip" then return "tag:" .. tostring(w.tag) end
    if c.kind == "face" or c.kind == "crossed" then return "face:" .. tostring(w.guid) end
    return c.kind .. ":" .. tostring(w)
end

function Controls.Add(f, group, found, opts)
    opts = opts or {}
    local set = { items = {}, fields = {} }
    function set.LetGo(keep)
        for _, box in ipairs(set.fields) do
            if box ~= keep and box:HasFocus() then box:ClearFocus() end
        end
    end
    function set.Writing()
        for _, box in ipairs(set.fields) do
            if box:HasFocus() then return box end
        end
    end
    local function After()
        if opts.refresh ~= false then Pad.Refresh() end
    end
    for _, c in ipairs(found) do
        local w, kind = c.frame, c.kind
        local item = { key = KeyOf(c), kind = kind, control = w, frame = w, level = opts.level, clip = opts.clip }
        if kind == "field" then
            set.fields[#set.fields + 1] = w
            local shown = Shown(w)
            item.frame = shown
            item.subhead = w.group or shown.group
            item.available = function() return w:IsVisible() and true or false end
            item.enter = function() set.LetGo(w) end
            item.leave = function() end
            item.press = function()
                if w:HasFocus() then w:ClearFocus() else
                    set.LetGo(w)
                    w:SetFocus()
                end
            end
        else
            item.subhead = w.group
            item.enter = function()
                set.LetGo()
                Run(w, "OnEnter", false)
            end
            item.leave = function() Run(w, "OnLeave", false) end
            if kind == "chip" then
                item.plain = true
                item.press = function()
                    if w.cross:IsShown() then w.cross:Click("LeftButton") else w:Click("LeftButton") end
                    After()
                end
            elseif kind == "crossed" then
                item.ring = true
                item.press = function()
                    w.cross:Click("LeftButton")
                    After()
                end
            elseif kind == "face" then
                item.ring = true
                item.press = function() end
            elseif kind == "book" then
                item.words = w.label
                item.available = function() return w:IsVisible() and not w.unavailable end
                item.press = function()
                    w:Click("LeftButton")
                    After()
                end
            elseif kind == "setter" then
                -- (its link while it waits; the keycap's words while it
                -- listens, the link hidden then)
                item.frame = w.bind
                item.enter = function()
                    set.LetGo()
                    item.words = w.listening and w.keycap.text or w.bind.label
                    item.frame = w.listening and w.keycap or w.bind
                end
                item.leave = function() end
                item.press = function()
                    if w.listening then w:Stop() else w.bind:Click("LeftButton") end
                    After()
                end
                item.available = function() return w:IsVisible() and true or false end
            else
                item.press = function()
                    w:Click("LeftButton")
                    After()
                end
            end
        end
        set.items[#set.items + 1] = f:Add(group, item)
    end
    return set
end

-- A's prompt on an item Controls made.
function Controls.Prompt(item)
    local w, kind = item.control, item.kind
    if not w then return nil end
    if kind == "field" then return w:HasFocus() and PROMPT.done or PROMPT.write end
    if kind == "switch" then return { "PAD1", w:GetChecked() and L["Untick"] or L["Tick"], main = true } end
    if kind == "chip" then
        if w.cross:IsShown() then return PROMPT.tagAway end
        return w.on and PROMPT.tagOff or PROMPT.tagOn
    end
    if kind == "crossed" then return PROMPT.unlink end
    if kind == "setter" then return w.listening and PROMPT.listening or PROMPT.key end
    if kind == "link" then return PROMPT.choose end
    if kind == "book" then return PROMPT.book end
end
