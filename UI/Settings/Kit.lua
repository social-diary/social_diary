-- The settings' kit (ns.UI.Settings.Kit): what a section's builder lays
-- its pane out with. The column it is filled down (Column: Place, Heading,
-- Hint, Checkbox, Number, Slider), the pane on the right page (Pane), and the
-- settings written through ns.SetSetting and read again with the page
-- (Switch, Number, Slider, DependsOn, Saved). The page and its registry are in
-- UI/Settings/Page.lua; the sections in UI/Settings/Sections/.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local INK = Style.INK
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings

local INDENT = 20               -- a setting that depends on the one above it
local FIELD_W, UNIT_W = 34, 34  -- a number's line, and the word after it
local SCALE_W, READING_W = 170, 38  -- a slider's scale, and what it reads, on the right
local SECTION_GAP = 14

--------------------------------------------------------------------------
-- Laying out a column
--------------------------------------------------------------------------
--
-- Each page is one column, filled top down: every piece goes under the last
-- and says how tall it came out, so a label that wraps pushes the rest down.

local function Column(parent, x, y, width)
    local column = { parent = parent, x = x, y = y, width = width, first = true }

    function column:Place(widget, height, indent, gap)
        widget:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x + (indent or 0), self.y)
        self.y = self.y - height - (gap or 6)
        return widget
    end

    -- A heading in small capitals with a rule running on after it, as the
    -- People list groups its rows. The controls placed under it, up to the
    -- next, keep it as `.group` and it keeps its rule as `.rule`: the pad
    -- rubricates both while it stands on one of them (UI/Pad/Look.lua).
    function column:Heading(text)
        local heading = Style.Text(self.parent, FONT.heading)
        heading:SetText(Style.Upper(text))
        self:PlaceHeading(heading)

        local rule = self.parent:CreateTexture(nil, "ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint("LEFT", heading, "RIGHT", 8, 0)
        rule:SetWidth(math.max(0, self.width - heading:GetStringWidth() - 8))
        rule:SetColorTexture(INK[1], INK[2], INK[3], 0.25)
        heading.rule = rule
        self.group = heading
        return heading
    end

    -- A heading placed under the last piece, with the gap before it: a
    -- new one's, or one made already and laid out again (a section that
    -- changes what it shows, as Keybinds & Shortcuts does with the pad).
    function column:PlaceHeading(heading)
        if not self.first then self.y = self.y - SECTION_GAP end
        self.first = false
        self:Place(heading, 14, 0, 8)
        self.group = heading
        return heading
    end

    -- Faded small print under a setting.
    function column:Hint(text, indent)
        local hint = Style.Text(self.parent, FONT.small)
        hint:SetWidth(self.width - (indent or 0))
        hint:SetText(text)
        return self:Place(hint, hint:GetStringHeight(), indent, 8)
    end

    function column:Checkbox(text, get, set, indent, hint)
        local box = Style.Checkbox(self.parent, self.width - (indent or 0), text, get, set, hint)
        box.group = self.group
        return self:Place(box, box.height, indent, hint and 8)
    end

    -- "Forget people outside the diary after [30] days": the sentence on the
    -- left, wrapping, and the number and its unit in a column on the right,
    -- so the numbers line up. `.box` is the field.
    function column:Number(text, unit, min, max, get, set)
        local row = CreateFrame("Frame", nil, self.parent)

        row.label = Style.Text(row, FONT.body)
        row.label:SetPoint("TOPLEFT")
        row.label:SetWidth(self.width - FIELD_W - UNIT_W - 8)
        row.label:SetText(text)

        row.box = Style.NumberField(row, FIELD_W, min, max, get, set)
        row.box:SetPoint("TOPRIGHT", row, "TOPRIGHT", -UNIT_W, 1)

        row.unit = Style.Text(row, FONT.body)
        row.unit:SetText(unit)
        row.unit:SetPoint("LEFT", row.box, "RIGHT", 6, 0)

        local height = math.max(18, row.label:GetStringHeight())
        row:SetSize(self.width, height)
        row.group = self.group

        function row:Refresh() self.box:Refresh() end
        function row:SetAvailable(available)
            self.unavailable = not available
            self:SetAlpha(available and 1 or 0.45)
            if available then self.box:Enable() else self.box:Disable() end
        end

        return self:Place(row, height)
    end

    -- "Paper Texture Intensity ---+--- 100%": the sentence on the left and the
    -- scale and its reading on the right, the reading on the column's edge.
    -- `.slider` is the scale; `spec` is Style.Slider's.
    function column:Slider(text, spec, get, set)
        local row = CreateFrame("Frame", nil, self.parent)

        row.label = Style.Text(row, FONT.body)
        row.label:SetPoint("TOPLEFT")
        row.label:SetWidth(self.width - SCALE_W - READING_W - 8)
        row.label:SetText(text)

        row.slider = Style.Slider(row, SCALE_W, spec, get, set)
        row.slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -READING_W, 1)
        row.slider.reading:SetWidth(READING_W)
        row.slider.reading:SetPoint("RIGHT", row, "TOPRIGHT", 0, 1 - row.slider.height / 2)

        local height = math.max(18, row.label:GetStringHeight())
        row:SetSize(self.width, height)
        row.group = self.group

        function row:Refresh() self.slider:Refresh() end
        function row:SetAvailable(available) self.slider:SetAvailable(available) end

        return self:Place(row, height)
    end

    return column
end

local function Saved() return ns.db.settings end

--------------------------------------------------------------------------
-- Right page: one pane per section
--------------------------------------------------------------------------

-- A pane on the right page, headed with the section's name in capitals and
-- what it covers beside it, as the Recently nearby page heads a day. A
-- subpage's name is a size smaller, as its row is on the left.
-- Returns the pane and a column to fill, below the heading.
local function Pane(s)
    local page = SettingsUI.page
    local pane = CreateFrame("Frame", nil, page)
    pane:SetPoint("TOPLEFT", BOOK.RIGHT_X, -BOOK.TOP)
    pane:SetSize(BOOK.RIGHT_W, BOOK.RIGHT_H)
    page.panes[s.key] = pane

    pane.title = Style.Text(pane, s.parent and FONT.titleSmall or FONT.title)
    pane.title:SetPoint("TOPLEFT", 0, 0)
    pane.title:SetHeight(28)
    pane.title:SetText(Style.Upper(s.label))

    pane.about = Style.Text(pane, FONT.faded)
    pane.about:SetPoint("BOTTOMLEFT", pane.title, "BOTTOMRIGHT", 10, 5)
    pane.about:SetText(s.about or "")

    return pane, Column(pane, 0, -48, BOOK.RIGHT_W)
end

-- A setting from the saved table, in column `c`, refreshed with the page.
-- `after` runs once it is written. Written through ns.SetSetting, as every
-- other writer of a setting does, so a setting is written one way only. Every switch refreshes the page, so the
-- settings that depend on it fade or come back.
-- `hint` is the switch's small print, hung under its label.
local function Switch(c, text, key, indent, after, hint)
    local page = SettingsUI.page
    local box = c:Checkbox(text, function() return Saved()[key] end, function(v)
        ns.SetSetting(key, v)
        if after then after(v) end
        ns.UI.Settings.Refresh()
    end, indent, hint)
    page.controls[#page.controls + 1] = box
    return box
end

local function Number(c, text, unit, key, min, max, after)
    local page = SettingsUI.page
    local row = c:Number(text, unit, min, max, function() return Saved()[key] end, function(v)
        ns.SetSetting(key, v)
        if after then after(v) end
    end)
    page.controls[#page.controls + 1] = row
    return row
end

local function Slider(c, text, key, spec, after)
    local page = SettingsUI.page
    local row = c:Slider(text, spec, function() return Saved()[key] end, function(v)
        ns.SetSetting(key, v)
        if after then after(v) end
    end)
    page.controls[#page.controls + 1] = row
    return row
end

-- `on` is the key of the setting it depends on, or a function saying
-- whether it is available.
local function DependsOn(control, on)
    local page = SettingsUI.page
    if type(on) ~= "function" then
        local key = on
        on = function() return Saved()[key] end
    end
    page.dependents[#page.dependents + 1] = { control = control, on = on }
end

SettingsUI.Kit = {
    Column = Column, Pane = Pane, Switch = Switch, Number = Number, Slider = Slider, DependsOn = DependsOn,
    Saved = Saved, INDENT = INDENT,
}
