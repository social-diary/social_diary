-- The small pieces drawn on the pages (Style, from UI/Style/Tokens.lua):
-- text, rules, links, grouped rows, tooltips, choice menus, index tabs,
-- tags, search fields, writing lines, boxes to tick, number fields and
-- sliders. A person's pieces (portrait, heading, medallion, boss marks,
-- rubric) are in UI/Style/Person.lua; strokes and the other drawing in
-- UI/Style/Draw.lua.

local addonName, ns = ...

local Style = ns.Style

--------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------

-- A string of text on `parent` in `font`, left-justified (OVERLAY unless
-- `layer` is given).
function Style.Text(parent, font, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFontObject(font)
    text:SetJustifyH("LEFT")
    return text
end

-- A thin ink rule that fades out at both ends.
function Style.Rule(parent, width)
    local rule = CreateFrame("Frame", nil, parent)
    rule:SetSize(width, 1)
    local INK = Style.INK
    for i, alpha in ipairs({ { 0, Style.HAIRLINE }, { Style.HAIRLINE, 0 } }) do
        local half = rule:CreateTexture(nil, "ARTWORK")
        half:SetSize(width / 2, 1)
        half:SetPoint(i == 1 and "LEFT" or "RIGHT")
        Style.Shade(half, "HORIZONTAL", INK[1], INK[2], INK[3], alpha[1], alpha[2])
    end
    return rule
end

-- Text that behaves like a link: underlined, darker on hover. For the
-- choices that used to be big red buttons (sort, filter, map, scope).
function Style.Link(parent, font, onClick)
    local link = CreateFrame("Button", nil, parent)
    link:SetHeight(18)

    link.label = Style.Text(link, font or Style.FONT.body)
    link.label:SetPoint("LEFT")

    link.line = link:CreateTexture(nil, "ARTWORK")
    link.line:SetHeight(1)
    link.line:SetPoint("TOPLEFT", link.label, "BOTTOMLEFT", 0, -1)
    link.line:SetPoint("TOPRIGHT", link.label, "BOTTOMRIGHT", 0, -1)
    link.line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)

    function link:SetText(text)
        self.label:SetText(text)
        self:SetWidth(math.max(self.label:GetStringWidth(), 8) + 2)
    end
    function link:GetText() return self.label:GetText() end

    -- Its own ink, for a link that should stand apart (Remove, in red).
    function link:SetColor(r, g, b)
        self.color = { r, g, b }
        self.label:SetTextColor(r, g, b)
        self.line:SetColorTexture(r, g, b, Style.HAIRLINE)
    end

    -- A link that is the current choice reads as plain text.
    function link:SetCurrent(current)
        self.current = current
        self.line:SetShown(not current)
        self.label:SetTextColor(unpack(current and Style.INK_STRONG or Style.INK))
    end

    link:SetScript("OnEnter", function(self)
        if self.current then return end
        self.label:SetTextColor(unpack(Style.INK_STRONG))
        self.line:SetColorTexture(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], Style.HAIRLINE_HOT)
    end)
    link:SetScript("OnLeave", function(self)
        if self.current then return end
        local color = self.color or Style.INK
        self.label:SetTextColor(color[1], color[2], color[3])
        self.line:SetColorTexture(color[1], color[2], color[3], Style.HAIRLINE)
    end)
    link:SetScript("OnClick", onClick)

    return link
end

-- A row of a list grouped under headings (the People list, the days on
-- Recently nearby): a heading in small capitals with a rule after it, or an
-- item that lights up under the mouse and is shaded while selected.
-- `body(row)` builds the item's own parts and returns them, so a heading
-- can hide them. The caller sets OnClick.
function Style.GroupedRow(list, body)
    local row = CreateFrame("Button", nil, list)
    local INK = Style.INK

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(INK[1], INK[2], INK[3], Style.HOVER_ALPHA)

    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(unpack(Style.SELECTED))

    row.parts = body(row)

    row.header = Style.Text(row, Style.FONT.heading)
    row.header:SetPoint("BOTTOMLEFT", 2, 3)

    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.rule:SetPoint("LEFT", row.header, "RIGHT", 8, 0)
    row.rule:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.rule:SetColorTexture(INK[1], INK[2], INK[3], 0.25)

    -- Shows `item` as a heading (item.header) and returns true, or shows the
    -- item's parts and returns false, for the caller to fill them and mark
    -- the selection. A heading never lights up and is never selected.
    function row:SetHeading(item)
        local isHeader = item.header ~= nil
        self.header:SetShown(isHeader)
        self.rule:SetShown(isHeader)
        for _, part in ipairs(self.parts) do part:SetShown(not isHeader) end
        self.highlight:SetAlpha(isHeader and 0 or 1)
        if isHeader then
            self.header:SetText(item.header:upper())
            self.selected:Hide()
        end
        return isHeader
    end

    return row
end

-- The GameTooltip over `frame` while the mouse is on it, at `anchor`
-- (default ANCHOR_RIGHT). `lines` is the text, a list of lines, or a
-- function(frame) returning the list when the mouse arrives, or nil for no
-- tooltip this time. A line is the arguments SetText (the first line) and
-- AddLine (the rest) take: { text, r, g, b, ... }. `hover(frame, over)`,
-- if given, is the frame's own hover look, called before the tooltip shows
-- and before it hides. Sets OnEnter and OnLeave.
function Style.Tooltip(frame, lines, anchor, hover)
    frame:SetScript("OnEnter", function(self)
        if hover then hover(self, true) end
        local list = lines
        if type(list) == "function" then list = list(self) end
        if not list then return end
        if type(list) == "string" then list = { { list } } end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(unpack(list[1]))
        for i = 2, #list do GameTooltip:AddLine(unpack(list[i])) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if hover then hover(self, false) end
        GameTooltip:Hide()
    end)
end

-- A modified click on an item (shift to paste its link into the chat box,
-- ctrl to try it on) handed to the game, as a bag slot's is: true where
-- the game took it, nil where it was a plain click or `link` is no item
-- link (a bare name from an old record), so the piece's own click goes on.
function Style.ItemClick(link)
    if type(link) ~= "string" or not link:find("item:%d+") then return nil end
    if not (IsModifiedClick and IsModifiedClick()) then return nil end
    return HandleModifiedItemClick and HandleModifiedItemClick(link) or nil
end

-- A tooltip's list as Style.Tooltip takes it, for what has a title and
-- lines under it (a card's, a mark's): the title in the tooltip's own
-- colour, each line in white and wrapped. With `into`, the title and lines
-- go on the end of that list instead (a slip telling several moments, one
-- after the other). Returns the list.
function Style.TipList(title, lines, into)
    local list = into or {}
    list[#list + 1] = { title }
    for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
    return list
end

-- The onChange a page's search (Style.PageSearch) mostly takes: the text
-- into `query.search` and `refresh()` called, only when the text is new
-- (setting the same text again still fires OnTextChanged).
function Style.SearchInto(query, refresh)
    return function(text)
        if text ~= query.search then
            query.search = text
            refresh()
        end
    end
end

-- Radio choices in a context menu (MenuUtil), one per `choices` entry,
-- each { label, key }: on where `get()` equals its key, and picking one
-- calls `set(key)`. A nil key is the "any" choice. Into `menu`, the root
-- or a submenu being built.
function Style.Choices(menu, choices, get, set)
    for _, choice in ipairs(choices) do
        menu:CreateRadio(choice.label, function() return get() == choice.key end,
            function() set(choice.key) end)
    end
end

-- A context menu of nothing but those choices, under `title` if given.
function Style.ChoiceMenu(owner, title, choices, get, set)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if title then root:CreateTitle(title) end
        Style.Choices(root, choices, get, set)
    end)
end

-- An index tab sticking out of the book's right edge: a paper tab with a
-- small picture on it. The open one is lighter and stands out further.
local TAB_OUT, TAB_IN = 40, 32

function Style.SideTab(parent, artKey, tip, onClick)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(TAB_IN, 36)
    local P, INK = Style.PAPER, Style.INK_STRONG

    -- Ink edge on the three sides that stick out, paper inside.
    local edge = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(INK[1], INK[2], INK[3], 0.85)

    tab.paper = tab:CreateTexture(nil, "BACKGROUND", nil, 1)
    tab.paper:SetPoint("TOPLEFT", 0, -1)
    tab.paper:SetPoint("BOTTOMRIGHT", -1, 1)

    -- The fold where it comes out of the pages.
    local fold = tab:CreateTexture(nil, "BACKGROUND", nil, 2)
    fold:SetPoint("TOPLEFT", 0, -1)
    fold:SetPoint("BOTTOMLEFT", 0, 1)
    fold:SetWidth(8)
    Style.Shade(fold, "HORIZONTAL", INK[1], INK[2], INK[3], 0.35, 0)

    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(22, 22)
    tab.icon:SetPoint("RIGHT", -6, 0)
    Style.SetTexture(tab.icon, artKey, 0.3, 0.22, 0.12, 1)
    tab.icon:SetTexCoord(unpack(Style.ICON_CROP))

    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(tab.paper)
    hover:SetColorTexture(1, 0.95, 0.8, 0.18)

    function tab:SetSelected(selected)
        self.selected = selected
        local shade = selected and 1 or 0.80
        self.paper:SetColorTexture(P[1] * shade, P[2] * shade, P[3] * shade, 1)
        self:SetWidth(selected and TAB_OUT or TAB_IN)
        self.icon:SetDesaturated(not selected)
        self.icon:SetAlpha(selected and 1 or 0.7)
    end
    tab:SetSelected(false)

    Style.Tooltip(tab, tip)
    tab:SetScript("OnClick", onClick)
    return tab
end

-- A tag you can click: filled in its colour when on, an ink outline on
-- the paper when off. A removable (custom) tag carries a small cross, which
-- is its own button.
function Style.TagButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)

    button.edge = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    button.edge:SetAllPoints()
    button.fill = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)

    button.label = Style.Text(button, Style.FONT.tag)
    button.label:SetPoint("LEFT", 7, 0)

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.95, 0.8, 0.12)

    button.cross = CreateFrame("Button", nil, button)
    button.cross:SetSize(14, 18)
    button.cross:SetPoint("RIGHT", -2, 0)
    local cross = Style.Text(button.cross, Style.FONT.tag)
    cross:SetPoint("CENTER")
    cross:SetText("\195\151")  -- the multiplication sign, U+00D7
    cross:SetAlpha(0.75)
    button.cross:SetScript("OnEnter", function() cross:SetAlpha(1) end)
    button.cross:SetScript("OnLeave", function() cross:SetAlpha(0.75) end)

    function button:SetTag(tag, on, removable)
        self.tag, self.on = tag, on
        local color = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
        local INK, P = Style.INK, Style.PAPER
        if on then
            self.edge:SetColorTexture(0, 0, 0, 0.35)
            self.fill:SetColorTexture(color[1], color[2], color[3], 1)
            self.label:SetTextColor(unpack(Style.TAG_TEXT))
        else
            self.edge:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
            self.fill:SetColorTexture(P[1], P[2], P[3], 1)
            self.label:SetTextColor(unpack(Style.INK_FADED))
        end
        self.label:SetText(tag)
        self.cross:SetShown(removable == true)
        self:SetWidth(self.label:GetStringWidth() + 14 + (removable and 12 or 0))
    end

    return button
end

-- Faded text in an empty box, saying what goes there: `box.hint`, for the
-- caller to place. box:UpdateHint() shows it while the box is empty, and
-- with `hideOnFocus` not while it has the cursor either.
function Style.Placeholder(box, text, hideOnFocus)
    box.hint = Style.Text(box, Style.FONT.faded)
    box.hint:SetText(text or "")
    function box:UpdateHint()
        self.hint:SetShown((self:GetText() or "") == "" and not (hideOnFocus and self:HasFocus()))
    end
    return box.hint
end

-- A search field drawn on the page rather than the dark InputBox template.
-- `onChange(text)` on every keystroke, the text never nil. Returns the
-- EditBox; its `hint` is the placeholder text.
function Style.PageSearch(parent, x, y, width, hint, onChange)
    local INK, FONT = Style.INK, Style.FONT
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 24)
    holder:SetPoint("TOPLEFT", x, y)

    local fill = holder:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(INK[1], INK[2], INK[3], 0.10)

    Style.Hairline(holder, "BORDER", nil, { Style.HAIRLINE, 0.20, 0.30, 0.30 })

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 6, 0)
    if Style.SetTexture(icon, "search") then
        icon:SetVertexColor(INK[1], INK[2], INK[3], 0.8)
    else
        icon:Hide()
    end

    local box = CreateFrame("EditBox", nil, holder)
    -- The whole field, for a caller that places it itself (a loose sheet).
    box.holder = holder
    box:SetPoint("TOPLEFT", 26, 0)
    box:SetPoint("BOTTOMRIGHT", -6, 0)
    box:SetFontObject(FONT.strong)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Unlike a writing line's, this hint stays while the box has the
    -- cursor, until the first letter.
    Style.Placeholder(box, hint):SetPoint("LEFT", 0, 0)

    box:SetScript("OnTextChanged", function(self)
        self:UpdateHint()
        if onChange then onChange(self:GetText() or "") end
    end)

    return box
end

-- A single line to write on: an EditBox in ink over an ink underline, with
-- a faded hint while empty. `onCommit(text)` on Enter and on losing focus.
function Style.WritingLine(parent, width, font, hint, onCommit)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 20)
    box:SetFontObject(font or Style.FONT.strong)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)

    box.line = box:CreateTexture(nil, "BORDER")
    box.line:SetHeight(1)
    box.line:SetPoint("BOTTOMLEFT", 0, -1)
    box.line:SetPoint("BOTTOMRIGHT", 0, -1)
    box.line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)

    Style.Placeholder(box, hint, true):SetPoint("LEFT", 0, 0)

    box:SetScript("OnTextChanged", box.UpdateHint)
    box:SetScript("OnEditFocusGained", function(self)
        self:UpdateHint()
        self.line:SetColorTexture(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], Style.HAIRLINE_HOT)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:UpdateHint()
        self.line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)
        if onCommit then onCommit(self:GetText()) end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Text set from code: refresh the hint without committing anything.
    function box:SetValue(text)
        self:SetText(text or "")
        self:UpdateHint()
    end

    return box
end

-- Text to copy out of the game (a web address: the client cannot open
-- one): a slip washed with ink and ruled round in a hairline, as the search
-- field is, `text` written on it. Read-only: typing puts the text back, so
-- nothing can be lost from it. A click or the cursor selects all of it for
-- Ctrl+C; Enter and Escape let go. Its edge darkens under the mouse and
-- while it has the cursor. `width` is the slip's; `.height` what it takes.
local COPY_H, COPY_PAD = 22, 7

function Style.CopyField(parent, width, text)
    local INK, STRONG = Style.INK, Style.INK_STRONG
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, COPY_H)
    holder.height = COPY_H

    local fill = holder:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(INK[1], INK[2], INK[3], 0.07)

    -- The rule round it, top and left a shade lighter: lit from the top left.
    holder.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = holder:CreateTexture(nil, "BORDER")
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        holder.edges[i] = edge
    end

    local box = CreateFrame("EditBox", nil, holder)
    holder.box = box
    box:SetPoint("TOPLEFT", COPY_PAD, 0)
    box:SetPoint("BOTTOMRIGHT", -COPY_PAD, 0)
    box:SetFontObject(Style.FONT.strong)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)

    local function Ink(hot)
        local c = hot and STRONG or INK
        for i, edge in ipairs(holder.edges) do
            local a = hot and Style.HAIRLINE_HOT or Style.HAIRLINE
            edge:SetColorTexture(c[1], c[2], c[3], (i == 1 or i == 3) and a * 0.7 or a)
        end
    end

    -- The text as given, the cursor at its start so a long one shows its
    -- beginning.
    local function Restore(self)
        self:SetText(holder.value)
        self:SetCursorPosition(0)
    end

    local function SelectAll(self)
        self:HighlightText()
    end

    box:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= holder.value then
            Restore(self)
            if self:HasFocus() then SelectAll(self) end
        end
    end)
    box:SetScript("OnEditFocusGained", function(self)
        SelectAll(self)
        Ink(true)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        Restore(self)
        Ink(self:IsMouseOver())
    end)
    -- The click that gave it the cursor also set the cursor down, which
    -- would undo the selection: select again once the button is up.
    box:SetScript("OnMouseUp", SelectAll)
    box:SetScript("OnEnter", function() Ink(true) end)
    box:SetScript("OnLeave", function(self) Ink(self:HasFocus()) end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    function holder:SetValue(value)
        self.value = value or ""
        Restore(box)
    end
    function holder:GetValue() return self.value end

    Ink(false)
    holder:SetValue(text)
    return holder
end

-- A box to tick, drawn in ink: a hairline square, and a tick written into
-- it in two strokes. Only the picture: Style.Checkbox, and the rows that
-- toggle around one, do the clicking.
local TICK_BOX = 13
local HINT_GAP = 2   -- between a switch's label and its hint

-- Each stroke is a thin bar turned about its centre: { x, y from the box's
-- centre (y up), length, angle anticlockwise }. Short down to the corner,
-- long up to the right, a pixel longer each so they meet without a notch.
local TICK_STROKES = { { -2.9, -1.5, 5.8, -math.pi / 4 }, { 2.2, 1.1, 12, 0.90 } }

function Style.Tick(parent)
    local tick = CreateFrame("Frame", nil, parent)
    tick:SetSize(TICK_BOX, TICK_BOX)
    local INK, STRONG = Style.INK, Style.INK_STRONG

    local fill = tick:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(INK[1], INK[2], INK[3], 0.06)

    local edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = tick:CreateTexture(nil, "BORDER")
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[i] = edge
    end

    local strokes = {}
    for i, s in ipairs(TICK_STROKES) do
        local stroke = tick:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(s[3], 2)
        stroke:SetPoint("CENTER", s[1], s[2])
        stroke:SetColorTexture(STRONG[1], STRONG[2], STRONG[3], 0.92)
        stroke:SetRotation(s[4])
        strokes[i] = stroke
    end

    function tick:SetChecked(checked)
        for _, stroke in ipairs(strokes) do stroke:SetShown(checked) end
    end

    -- Darker while the mouse is on what it belongs to.
    function tick:SetHot(hot)
        local c = hot and STRONG or INK
        for _, edge in ipairs(edges) do
            edge:SetColorTexture(c[1], c[2], c[3], hot and Style.HAIRLINE_HOT or Style.HAIRLINE + 0.2)
        end
    end

    tick:SetChecked(false)
    tick:SetHot(false)
    return tick
end

-- A setting to switch: the inked box and its label beside it, wrapping
-- inside `width`, and `hint`, if any, in small print close under the label,
-- on its left edge and as wide. Reads `get()` on Refresh and writes the
-- other value through `set` when clicked anywhere. Answers GetChecked and
-- SetChecked like the client's CheckButton; `height` is what it takes on
-- the page.
--
-- Without `set` it is a status, written in by the addon, not a switch: the
-- same box and tick at full ink, but deaf to the mouse, so it never darkens
-- under it and a click goes nowhere.
function Style.Checkbox(parent, width, text, get, set, hint)
    local button = CreateFrame("Button", nil, parent)
    local FONT = Style.FONT
    local labelW = width - TICK_BOX - 7

    button.tick = Style.Tick(button)
    button.tick:SetPoint("TOPLEFT", 0, -2)

    button.label = Style.Text(button, FONT.body)
    button.label:SetPoint("TOPLEFT", TICK_BOX + 7, 0)
    button.label:SetWidth(labelW)
    button.label:SetText(text)

    button.height = math.max(TICK_BOX + 4, button.label:GetStringHeight())
    if hint then
        button.hint = Style.Text(button, FONT.small)
        button.hint:SetPoint("TOPLEFT", button.label, "BOTTOMLEFT", 0, -HINT_GAP)
        button.hint:SetWidth(labelW)
        button.hint:SetText(hint)
        button.height = math.max(TICK_BOX + 4,
            button.label:GetStringHeight() + HINT_GAP + button.hint:GetStringHeight())
    end
    button:SetSize(width, button.height)

    function button:SetChecked(checked)
        self.checked = checked and true or false
        self.tick:SetChecked(self.checked)
    end
    function button:GetChecked() return self.checked == true end
    function button:Refresh() self:SetChecked(get()) end

    -- Faded and deaf while what it depends on is off.
    function button:SetAvailable(available)
        self.unavailable = not available
        self:SetAlpha(available and 1 or 0.45)
    end

    button:SetChecked(false)
    if not set then
        button.readOnly = true
        button:EnableMouse(false)
        return button
    end

    local function Hover(self, over)
        over = over and not self.unavailable
        self.label:SetFontObject(over and FONT.strong or FONT.body)
        self.tick:SetHot(over)
    end
    button:SetScript("OnEnter", function(self) Hover(self, true) end)
    button:SetScript("OnLeave", function(self) Hover(self, false) end)
    button:SetScript("OnClick", function(self)
        if self.unavailable then return end
        self:SetChecked(not self.checked)
        set(self.checked)
    end)

    return button
end

-- A whole number written on a short line, centred, clamped to [min, max]
-- on Enter and on losing focus. A box left empty or unreadable goes back to
-- `get()`. Refresh shows the current value.
function Style.NumberField(parent, width, min, max, get, set)
    local INK, STRONG = Style.INK, Style.INK_STRONG
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 18)
    box:SetFontObject(Style.FONT.strong)
    box:SetJustifyH("CENTER")
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)

    box.line = box:CreateTexture(nil, "BORDER")
    box.line:SetHeight(1)
    box.line:SetPoint("BOTTOMLEFT", 0, -1)
    box.line:SetPoint("BOTTOMRIGHT", 0, -1)
    box.line:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)

    function box:Refresh() self:SetText(tostring(get())) end

    -- Enter commits and lets go, and letting go commits again: only a
    -- changed number reaches `set`.
    local function Commit(self)
        local n = tonumber(self:GetText())
        if n then
            n = math.max(min, math.min(max, math.floor(n)))
            if n ~= get() then set(n) end
        end
        self:Refresh()
    end

    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:Refresh()
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        self.line:SetColorTexture(STRONG[1], STRONG[2], STRONG[3], Style.HAIRLINE_HOT)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self.line:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
        Commit(self)
    end)

    return box
end

-- A slider's measure: its height, the nib's (the lozenge you drag) size and
-- the room it travels in, and the ticks' lengths: every step, and the longer
-- one at `spec.mark`.
local SCALE = { height = 16, nib = 8, thumb = 10, tick = 5, markTick = 9 }

-- `value` as a number on a scale: inside [min, max], on a step, the nearest.
-- What is not a number is `min`.
function Style.OnScale(value, min, max, step)
    value = math.max(min, math.min(max, tonumber(value) or min))
    return min + math.floor((value - min) / step + 0.5) * step
end

-- A number chosen on a ruled scale: an ink line with a tick at each step,
-- and a lozenge on it to drag or to click along the line. `width` is the
-- scale's; `height` what it takes on the page. `.reading`, for the caller to
-- place, says the value with `spec.unit` after it. `spec` is min, max, step,
-- unit, and `mark`, the value whose tick is longer, if any. Refresh shows
-- `get()`, put on the scale; only a move to another step reaches `set`, so
-- a drag writes once per step.
function Style.Slider(parent, width, spec, get, set)
    local INK, STRONG = Style.INK, Style.INK_STRONG
    local min, max, step = spec.min, spec.max, spec.step
    local slider = CreateFrame("Slider", nil, parent)
    slider.height = SCALE.height
    slider:SetSize(width, SCALE.height)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    -- The nib's centre stops half the thumb short of each end, so the line
    -- and the ticks do too. The thumb is clear, with the nib on it.
    local inset, travel = SCALE.thumb / 2, width - SCALE.thumb
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0, 0, 0, 0)
    thumb:SetSize(SCALE.thumb, SCALE.height)
    slider:SetThumbTexture(thumb)
    local nib = Style.Lozenge(slider, "OVERLAY", SCALE.nib, STRONG, 1)
    nib:SetPoint("CENTER", thumb, "CENTER")

    local line = slider:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", inset, 0)
    line:SetPoint("RIGHT", -inset, 0)

    local ticks = {}
    local steps = math.floor((max - min) / step + 0.5)
    for i = 0, steps do
        local tick = slider:CreateTexture(nil, "ARTWORK")
        tick:SetSize(1, min + i * step == spec.mark and SCALE.markTick or SCALE.tick)
        tick:SetPoint("CENTER", slider, "LEFT", math.floor(inset + travel * i / steps + 0.5), 0)
        ticks[#ticks + 1] = tick
    end

    -- Darker while the mouse is on it, as a box to tick is.
    local function Ink(hot)
        local c = hot and STRONG or INK
        local alpha = hot and Style.HAIRLINE_HOT or Style.HAIRLINE + 0.2
        line:SetColorTexture(c[1], c[2], c[3], alpha)
        for _, tick in ipairs(ticks) do tick:SetColorTexture(c[1], c[2], c[3], alpha) end
    end
    Ink(false)

    slider.reading = Style.Text(slider, Style.FONT.strong)
    slider.reading:SetJustifyH("RIGHT")

    local function Show(value) slider.reading:SetText(value .. (spec.unit or "")) end

    function slider:Refresh()
        local value = Style.OnScale(get(), min, max, step)
        self:SetValue(value)
        Show(value)
    end

    -- Faded and deaf while what it depends on is off.
    function slider:SetAvailable(available)
        self.unavailable = not available
        self:SetAlpha(available and 1 or 0.45)
        if available then self:Enable() else self:Disable() end
    end

    slider:SetScript("OnEnter", function(self) Ink(not self.unavailable) end)
    slider:SetScript("OnLeave", function() Ink(false) end)
    slider:SetScript("OnValueChanged", function(self, value)
        local stepped = Style.OnScale(value, min, max, step)
        -- Between the steps (a value set from outside): on to the nearest,
        -- which comes back here.
        if stepped ~= value then
            self:SetValue(stepped)
            return
        end
        Show(stepped)
        if stepped ~= Style.OnScale(get(), min, max, step) then set(stepped) end
    end)

    return slider
end

-- A tag as a small inked label: colour plus its text.
function Style.TagChip(parent)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(18)

    local edge = chip:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 0.35)

    chip.fill = chip:CreateTexture(nil, "BACKGROUND", nil, 1)
    chip.fill:SetPoint("TOPLEFT", 1, -1)
    chip.fill:SetPoint("BOTTOMRIGHT", -1, 1)

    chip.label = Style.Text(chip, Style.FONT.tag)
    chip.label:SetPoint("LEFT", 7, 0)

    function chip:SetTag(tag)
        local color = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
        self.fill:SetColorTexture(color[1], color[2], color[3], 1)
        self.label:SetText(tag)
        self:SetWidth(self.label:GetStringWidth() + 14)
    end

    return chip
end
