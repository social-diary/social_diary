-- A menu the pad drives: Blizzard's context menu's choices on a slip of the
-- diary's paper (.claude/controller-plan.md, "Client round 2", 8 Nov 2026).
--
-- Forever's Gamepad UI does not take focus of a menu an addon opens
-- (MenuUtil.CreateContextMenu): with the pad stepped aside, nothing walked
-- it and B did not close it (the client, 8 Nov 2026). Its frame manager may
-- not be called (the plan's override rule: it taints), so with the pad in
-- hand a menu is never Blizzard's. The same generator the mouse's menu is
-- built from runs here against a recorder (Record) that keeps what it
-- describes, so the pad's choices can never drift from the mouse's:
--
--   Pad.Menu.Open(owner, generator)  generator(owner, root), as given to
--                                    MenuUtil.CreateContextMenu; laid on a
--                                    slip under `owner`, over the window of
--                                    the scope that has the pad. False when
--                                    there is nothing to choose
--   Pad.Menu.Close()                 put away, the pad back on the owner
--   Pad.Menu.IsOpen()
--   Pad.Menu.Record(owner, generator) the description, for the tests: a
--                                    tree of { kind, text, children, ... }
--
-- What a generator may describe (the description's methods): CreateTitle,
-- CreateButton (a callback; or a submenu, its children made on it),
-- CreateRadio and CreateCheckbox (isSelected, setSelected, data),
-- CreateDivider, CreateSpacer, SetEnabled, SetResponse; any other method is
-- heard and does nothing (a tooltip, a scroll mode).
--
-- With the pad: up and down walk the choices (titles, dividers and the
-- disabled passed over); A on a choice does what the mouse's pick does (a
-- button's callback, a radio's or checkbox's setSelected, with its data),
-- and closes or stays open as Blizzard's does: closes, a checkbox stays,
-- and a callback's MenuResponse (Open / Refresh stay, Close / CloseAll
-- close) has the last word. Staying, the generator is run again (as
-- Blizzard's Refresh does), so a tick shows at once. A or right on a
-- submenu lays it on its own slip beside its line; left or B there comes
-- back to that line; B at the top puts the menu away. The pad's look is
-- the page's: the line stood on red and boxed (Pad.Look), its slip the
-- prompts' paper.
--
-- No parent scope: while the menu is up the book's keys wait (no ribbon
-- turns under it). The mouse taking over, or the window hiding, puts it
-- away. Nothing of Blizzard's is called or touched.

local addonName, ns = ...

local Pad = ns.UI.Pad
local Style = ns.Style

local Menu = {}
Pad.Menu = Menu

-- The slip: `paper` as the prompts' slip (Look's SLIP), a hairline edge at
-- `edge`, its shadow `shadow` px down and right. `padX` / `padY` round the
-- lines; a line `row` px, a title `title`, a divider `divider`; at least
-- `minW` wide. Lines left of the words keep `lead` px for a radio's
-- lozenge (`mark` across, its middle `markX` in from the words) or a
-- checkbox's tick; a submenu's line ends in the pen's chevron (`chevron`)
-- `gap` px past the longest words. At most `most` lines show; more scroll
-- as the pad walks (a faded rule at the cut edge says there are more). A
-- slip lies `drop` px under its owner, a submenu's over its parent's
-- right edge by `over` px, `above` frame levels over what it lies on.
local SLIP = {
    paper = { 0.93, 0.88, 0.74 }, edge = 0.45, shadow = 6,
    padX = 14, padY = 9, row = 20, title = 18, divider = 9, minW = 120,
    lead = 14, mark = 6, markX = 8, gap = 14,
    chevron = { w = 4, h = 8, thick = 1.3 },
    most = 12, drop = 4, over = 10, above = 20,
}
Menu.SLIP = SLIP

-- The prompts (copy: copywriter, 8 Nov 2026).
local PROMPT = {
    choose = "Choose",
    open = "See the choices",
    away = "Put the menu away",
    back = "Back to the menu",
}
Menu.PROMPT = PROMPT

--------------------------------------------------------------------------
-- The recorder: what a generator describes
--------------------------------------------------------------------------

local Element = {}
local function Noop() end
local ElementMeta = {
    __index = function(_, key)
        local m = Element[key]
        if m then return m end
        -- (a method this menu does not draw: heard, nothing done)
        if type(key) == "string" and key:match("^%u") then return Noop end
    end,
}

local function New(kind, text)
    return setmetatable({ kind = kind, text = text, children = {}, enabled = true }, ElementMeta)
end

local function Append(parent, child)
    parent.children[#parent.children + 1] = child
    child.parent = parent
    return child
end

function Element:CreateTitle(text) return Append(self, New("title", text)) end
function Element:CreateDivider() return Append(self, New("divider")) end
function Element:CreateSpacer() return Append(self, New("spacer")) end
function Element:CreateButton(text, callback, data)
    local e = New("button", text)
    e.callback, e.data = callback, data
    return Append(self, e)
end
function Element:CreateRadio(text, isSelected, setSelected, data)
    local e = New("radio", text)
    e.isSelected, e.setSelected, e.data = isSelected, setSelected, data
    return Append(self, e)
end
function Element:CreateCheckbox(text, isSelected, setSelected, data)
    local e = New("checkbox", text)
    e.isSelected, e.setSelected, e.data = isSelected, setSelected, data
    return Append(self, e)
end
function Element:SetEnabled(on) self.enabled = on end
function Element:SetResponse(response) self.response = response end

local function Enabled(e)
    if type(e.enabled) == "function" then return e.enabled(e.data) and true or false end
    return e.enabled ~= false
end

local function Choosable(e)
    return e.kind == "button" or e.kind == "radio" or e.kind == "checkbox"
end

local function HasSub(e) return e.kind == "button" and #e.children > 0 end

local function Selected(e)
    return e.isSelected ~= nil and e.isSelected(e.data) and true or false
end

function Menu.Record(owner, generator)
    local root = New("root")
    generator(owner, root)
    return root
end

--------------------------------------------------------------------------
-- The slips
--------------------------------------------------------------------------

local state        -- { owner, generator, host, root, path = { index ... } } while open
local slips = {}   -- by depth, made the first time

local function Slip(depth, host)
    local slip = slips[depth]
    if slip and slip:GetParent() == host then return slip end
    slip = CreateFrame("Frame", nil, host)
    slip:Hide()
    local c = SLIP.paper
    local paper = slip:CreateTexture(nil, "BACKGROUND", nil, 0)
    paper:SetAllPoints()
    paper:SetColorTexture(c[1], c[2], c[3], 1)
    Style.Hairline(slip, "BORDER", 0, SLIP.edge)
    -- Its shadow on the page, down and to the right (as the prompts' slip).
    local below = slip:CreateTexture(nil, "BACKGROUND", nil, -1)
    below:SetPoint("TOPLEFT", slip, "BOTTOMLEFT", SLIP.shadow / 2, 0)
    below:SetPoint("BOTTOMRIGHT", slip, "BOTTOMRIGHT", SLIP.shadow, -SLIP.shadow)
    Style.Shade(below, "VERTICAL", 0, 0, 0, 0, 0.35)
    local side = slip:CreateTexture(nil, "BACKGROUND", nil, -1)
    side:SetPoint("TOPLEFT", slip, "TOPRIGHT", 0, -SLIP.shadow)
    side:SetPoint("BOTTOMRIGHT", slip, "BOTTOMRIGHT", SLIP.shadow, 0)
    Style.Shade(side, "HORIZONTAL", 0, 0, 0, 0.35, 0)
    -- The cut edges' rules, where more lines lie past them.
    local INK = Style.INK
    slip.more = {}
    for _, edge in ipairs({ "TOP", "BOTTOM" }) do
        local rule = slip:CreateTexture(nil, "ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint(edge .. "LEFT", slip, edge .. "LEFT", SLIP.padX, edge == "TOP" and -3 or 3)
        rule:SetPoint(edge .. "RIGHT", slip, edge .. "RIGHT", -SLIP.padX, edge == "TOP" and -3 or 3)
        Style.Shade(rule, "HORIZONTAL", INK[1], INK[2], INK[3], 0.5, 0)
        rule:Hide()
        slip.more[edge] = rule
    end
    slip.lines = {}
    slip.depth = depth
    slips[depth] = slip
    return slip
end

-- A line of a slip: its words, a radio's lozenge, a checkbox's tick, a
-- submenu's chevron; a title's capitals, a divider's rule. Made once a
-- place, set again each time it is laid.
local function Line(slip, i)
    local line = slip.lines[i]
    if line then return line end
    line = CreateFrame("Frame", nil, slip)
    line.label = Style.Text(line, Style.FONT.body)
    line.label:SetPoint("LEFT", line, "LEFT", SLIP.lead, 0)
    line.heading = Style.Text(line, Style.FONT.heading)
    line.heading:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.mark = Style.Lozenge(line, "ARTWORK", SLIP.mark, Style.RUBRIC)
    line.mark:SetPoint("CENTER", line.label, "LEFT", -SLIP.markX, 0)
    line.tick = Style.Tick(line)
    line.tick:SetPoint("CENTER", line.label, "LEFT", -SLIP.markX - 1, 0)
    line.rule = line:CreateTexture(nil, "ARTWORK")
    line.rule:SetHeight(1)
    line.rule:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.rule:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    local INK = Style.INK
    line.rule:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE or 0.25)
    -- The pen's chevron, its point outward, as Your Diary's level chevrons.
    local ch = SLIP.chevron
    line.chevron = CreateFrame("Frame", nil, line)
    line.chevron:SetSize(ch.w, ch.h)
    line.chevron:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    local S = Style.INK_STRONG
    line.chevron.strokes = {
        Style.Stroke(line.chevron, "ARTWORK", 0, 0, ch.w, ch.h / 2 + 0.3, S, 0.85, ch.thick),
        Style.Stroke(line.chevron, "ARTWORK", ch.w, ch.h / 2 - 0.3, 0, ch.h, S, 0.85, ch.thick),
    }
    slip.lines[i] = line
    return line
end

local function Height(e)
    if e.kind == "title" then return SLIP.title end
    if e.kind == "divider" or e.kind == "spacer" then return SLIP.divider end
    return SLIP.row
end

-- The words' colour as a line stands: faded where it cannot be chosen,
-- strong where it is chosen, red where its submenu lies open beside it.
local function Ink(line, e, open)
    local c = (not Enabled(e)) and Style.INK_FADED or (open and Style.RUBRIC)
        or (Selected(e) and Style.INK_STRONG) or Style.INK
    line.label:SetTextColor(c[1], c[2], c[3], 1)
    for _, s in ipairs(line.chevron.strokes) do
        local k = open and Style.RUBRIC or Style.INK_STRONG
        if s.SetColorTexture then s:SetColorTexture(k[1], k[2], k[3], 0.85) end
    end
end

local function Measure(slip, text)
    local fs = slip.measure
    if not fs then
        fs = Style.Text(slip, Style.FONT.body)
        fs:Hide()
        slip.measure = fs
    end
    fs:SetText(text or "")
    return fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
end

-- The slip of `node` at `depth` laid: its lines from `slip.first`, as many
-- as `most` allow, its size from its widest words.
local function Lay(slip, node, depth, openIndex)
    local children = node.children
    local widest, sub = 0, false
    for _, e in ipairs(children) do
        if e.kind == "title" then
            widest = math.max(widest, Measure(slip, (e.text or ""):upper()) - SLIP.lead)
        elseif Choosable(e) then
            widest = math.max(widest, Measure(slip, e.text))
            sub = sub or HasSub(e)
        end
    end
    local inner = SLIP.lead + widest + (sub and (SLIP.gap + SLIP.chevron.w) or 0)
    local w = math.max(SLIP.minW, math.floor(inner + 2 * SLIP.padX + 0.5))
    slip:SetWidth(w)

    local first = slip.first or 1
    local last = math.min(#children, first + SLIP.most - 1)
    local y, n = SLIP.padY, 0
    slip.at = {}
    for i = first, last do
        local e = children[i]
        n = n + 1
        local line = Line(slip, n)
        local h = Height(e)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", slip, "TOPLEFT", SLIP.padX, -y)
        line:SetPoint("TOPRIGHT", slip, "TOPRIGHT", -SLIP.padX, -y)
        line:SetHeight(h)
        local choosable = Choosable(e)
        line.label:SetShown(choosable)
        line.heading:SetShown(e.kind == "title")
        line.rule:SetShown(e.kind == "divider")
        line.mark:SetShown(e.kind == "radio" and Selected(e))
        line.tick:SetShown(e.kind == "checkbox")
        if e.kind == "checkbox" then line.tick:SetChecked(Selected(e)) end
        line.chevron:SetShown(HasSub(e))
        if choosable then
            line.label:SetText(e.text or "")
            Ink(line, e, openIndex == i)
        elseif e.kind == "title" then
            line.heading:SetText((e.text or ""):upper())
        end
        line.element, line.index = e, i
        slip.at[i] = line
        line:Show()
        y = y + h
    end
    for k = n + 1, #slip.lines do slip.lines[k]:Hide() end
    slip:SetHeight(y + SLIP.padY)
    slip.more.TOP:SetShown(first > 1)
    slip.more.BOTTOM:SetShown(last < #children)
    slip.node, slip.first = node, first
end

-- Where the slip at `depth` lies: the first under its owner, its lines'
-- words under the owner's; a submenu's over its parent's right edge, its
-- first line level with the line that opened it.
local function Place(slip, depth, host)
    slip:ClearAllPoints()
    local base = (state.owner.GetFrameLevel and state.owner:GetFrameLevel() or host:GetFrameLevel())
    local level = math.max(host:GetFrameLevel() + 50, base + SLIP.above) + (depth - 1) * 10
    slip:SetFrameLevel(level)
    if depth == 1 then
        slip:SetPoint("TOPLEFT", state.owner, "BOTTOMLEFT", -(SLIP.padX + SLIP.lead), -SLIP.drop)
    else
        local parent = slips[depth - 1]
        local from = parent.at and parent.at[state.path[depth - 1]]
        if from then
            slip:SetPoint("TOPLEFT", from, "TOPRIGHT", SLIP.padX - SLIP.over, SLIP.padY)
        else
            slip:SetPoint("TOPLEFT", parent, "TOPRIGHT", -SLIP.over, 0)
        end
    end
end

-- The node open at `depth` (1 the root), following the path.
local function NodeAt(depth)
    local node = state.root
    for d = 1, depth - 1 do
        node = node and node.children[state.path[d]]
    end
    return node
end

local function Depth() return #state.path + 1 end

-- Every slip of the path laid and placed; those past it put away.
local function Draw()
    local host = state.host
    for depth = 1, Depth() do
        local slip = Slip(depth, host)
        Lay(slip, NodeAt(depth), depth, state.path[depth])
        Place(slip, depth, host)
        slip:Show()
    end
    for depth = Depth() + 1, #slips do
        slips[depth]:Hide()
        slips[depth].first = nil
    end
end

-- The line at `index` brought into view on the top slip (the pad landing
-- on it): the slip scrolled by as little as will show it.
local function Reveal(index)
    local slip = slips[Depth()]
    if not slip then return end
    local first = slip.first or 1
    if index < first then
        first = index
    elseif index > first + SLIP.most - 1 then
        first = index - SLIP.most + 1
    end
    -- (a title or a divider just above comes with it)
    if first == index and first > 1 and not Choosable(slip.node.children[first - 1]) then first = first - 1 end
    if first ~= slip.first then
        slip.first = first
        Lay(slip, slip.node, Depth(), nil)
    end
end

--------------------------------------------------------------------------
-- Opening, choosing, closing
--------------------------------------------------------------------------

local function HideAll()
    for _, slip in ipairs(slips) do
        slip:Hide()
        slip.first = nil
    end
end

function Menu.IsOpen() return state ~= nil end

function Menu.Close()
    if not state then return end
    state = nil
    HideAll()
    Pad.Refresh()
end

local function AnyChoice(node)
    for _, e in ipairs(node.children) do
        if Choosable(e) then return true end
    end
    return false
end

local hooked = setmetatable({}, { __mode = "k" })

function Menu.Open(owner, generator)
    if not (owner and type(generator) == "function") then return false end
    local top = Pad.Top()
    local host = top and top.host()
    if not host then return false end
    local root = Menu.Record(owner, generator)
    if not AnyChoice(root) then return false end
    if state then HideAll() end
    state = { owner = owner, generator = generator, host = host, root = root, path = {},
        from = top.key }
    if not hooked[host] then
        hooked[host] = true
        host:HookScript("OnHide", function(self)
            if state and state.host == self then Menu.Close() end
        end)
    end
    Draw()
    Pad.Refresh()
    return true
end

-- Into the submenu at `index` of the top slip.
local function In(index)
    local node = NodeAt(Depth())
    local e = node and node.children[index]
    if not (e and HasSub(e) and Enabled(e) and AnyChoice(e)) then return false end
    state.path[#state.path + 1] = index
    state.fresh = nil
    Draw()
    Pad.Refresh()
    return true
end

-- Back out of the top submenu, the pad on the line that opened it.
local function Out()
    if #state.path == 0 then return false end
    local index = table.remove(state.path)
    state.back = index
    Draw()
    Pad.Refresh()
    return true
end

-- Whether a pick's answer keeps the menu open (Blizzard's MenuResponse:
-- Open and Refresh stay, Close and CloseAll close; a checkbox stays by
-- default, anything else closes).
local function Stays(e, answer)
    local R = _G.MenuResponse
    local response = answer
    if response == nil then response = e.response end
    if response == nil then return e.kind == "checkbox" end
    if R then return response == R.Open or response == R.Refresh end
    return false
end

-- The generator run again with the menu kept open where it was (as
-- Blizzard's Refresh): the path followed as far as it still goes.
local function Again()
    state.root = Menu.Record(state.owner, state.generator)
    local node, path = state.root, {}
    for _, index in ipairs(state.path) do
        local e = node.children[index]
        if not (e and HasSub(e)) then break end
        path[#path + 1] = index
        node = e
    end
    state.path = path
    Draw()
end

local INPUT = { context = "pad", buttonName = "LeftButton" }

local function Pick(index)
    local node = NodeAt(Depth())
    local e = node and node.children[index]
    if not (e and Choosable(e) and Enabled(e)) then return false end
    if HasSub(e) then return In(index) end
    local answer
    if e.kind == "button" then
        if e.callback then answer = e.callback(e.data, INPUT) end
    elseif e.setSelected then
        answer = e.setSelected(e.data, INPUT)
    end
    if not state then return true end  -- (the pick put it away itself)
    if Stays(e, answer) then
        Again()
        Pad.Refresh()
    else
        Menu.Close()
    end
    return true
end
Menu.Pick = Pick  -- (for the tests: a pick by index on the top slip)

--------------------------------------------------------------------------
-- The scope
--------------------------------------------------------------------------

local function Key(depth, index, e) return ("menu:%d:%d:%s"):format(depth, index, tostring(e.text)) end

local scope = {
    layer = 60,
    host = function() return state and state.host end,
    active = function() return state ~= nil and state.host:IsVisible() end,
}

-- The pad lands on a line: brought into view, its frame and words found
-- as laid (a chosen radio's lozenge held in the box with its words).
local function Find(item)
    Reveal(item.index)
    local slip = slips[Depth()]
    local line = slip and slip.at and slip.at[item.index]
    item.frame = line
    item.words = line and line.label or nil
    item.encloses = line and line.mark:IsShown() and line.mark or nil
end

function scope.build(f)
    local depth = Depth()
    f:Group("menu", { mode = "list", reveal = Find })
    local node = NodeAt(depth)
    local slip = slips[depth]
    if not (node and slip) then return end
    local land, chosen
    for index, e in ipairs(node.children) do
        if Choosable(e) then
            local key = Key(depth, index, e)
            f:Add("menu", {
                key = key, index = index, element = e,
                level = slip:GetFrameLevel() + 3,
                available = function() return Enabled(e) end,
                enter = function() end, leave = function() end,
                press = function() Pick(index) end,
                step = function(dir)
                    if dir == "RIGHT" and HasSub(e) then return In(index) end
                    if dir == "LEFT" and depth > 1 then return Out() end
                    return false
                end,
            })
            if state.back == index then land = key end
            if not chosen and e.kind == "radio" and Selected(e) then chosen = key end
        end
    end
    -- Where the pad lands: back on the line a submenu was opened from; on a
    -- slip just laid, its chosen radio, else its first choice (never a place
    -- remembered from another menu).
    if land then
        state.back = nil
    elseif state.fresh ~= depth then
        land = chosen or false
    end
    if land ~= nil then
        state.fresh = depth
        f:Remember("menu", land or nil)
    end
    f:Within("menu")
end

function scope.back()
    if not state then return false end
    if not Out() then Menu.Close() end
    return true
end

function scope.legend()
    local item = scope.focus and scope.focus:Current()
    local e = item and item.element
    local sub = e and HasSub(e)
    return {
        { "PAD1", sub and PROMPT.open or PROMPT.choose, main = true },
        { "PAD2", (state and #state.path > 0) and PROMPT.back or PROMPT.away },
    }
end

Pad.RegisterScope("menu", scope)

-- The mouse taking over puts the menu away (its slip is the pad's alone).
Pad.Input.OnChange(function()
    if state and not Pad.Input.Active() then
        state = nil
        HideAll()
    end
end)
