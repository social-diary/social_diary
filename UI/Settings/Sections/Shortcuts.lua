-- Settings: Keybinds & Shortcuts, Interface's second subpage
-- (UI/Settings/Page.lua lists the sections; the controls are
-- UI/Settings/Kit.lua's): both keys, the books to drag onto a bar
-- (UI/Settings/Macro.lua), and the slash commands. With the pad in hand,
-- the books alone, first: a controller's player puts them on a slot of
-- the controller's action bar (the keys are the keyboard's).

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings
local Macro = SettingsUI.Macro
local MACROS, MACRO_ORDER, BOOK_ICON, BookButton = Macro.MACROS, Macro.MACRO_ORDER, Macro.BOOK_ICON, Macro.BookButton

-- The keys, in Bindings.xml's terms.
local BINDINGS = {
    { action = "SOCIALDIARY_JOURNAL", label = L["Open the journal"] },
    { action = "SOCIALDIARY_REMEMBER", label = L["Remember this"] },
}
local KEY_LABEL_W = 160

-- The /sd commands worth knowing (Core/Slash.lua has them all; /sd help
-- lists them in chat). In the order they would be wanted.
local COMMANDS = {
    { "/sd", L["Opens the journal"] },
    { "/sd add <name>", L["Adds your target, or whoever you name"] },
    { "/sd remember", L["Remember this, from who you met lately"] },
    { "/sd settings", L["These pages"] },
    { "/sd about", L["What the diary keeps, and where"] },
    { "/sd forget <name>", L["Deletes everything about someone"] },
    { "/sd help", L["Every command, in chat"] },
}
local COMMAND_W = 150

-- With the pad in hand (Forever's Gamepad UI, the pad used last) the page
-- is laid out again: the keys go, and the books come first, under their
-- heading, with a line saying what to do with one. A controller's player
-- puts the diary on their controller's action bar with a book (the
-- controller plan, "As built (macros for the pad)"). The mouse's page is
-- laid out as it always was; it changes back when the mouse takes over.
local Pad = ns.UI.Pad

-- Lays the page out for the pad (`pad` true) or the mouse, in the column
-- the section was built with, from its top again.
local function Layout(pane, blocks, pad)
    local page = SettingsUI.page
    local c = SettingsUI.Kit.Column(pane, 0, -48, BOOK.RIGHT_W)
    local keys = blocks.keys
    keys.heading:SetShown(not pad)
    keys.heading.rule:SetShown(not pad)
    -- (the setters too: what the pad finds asks the setter itself)
    for _, row in ipairs(keys.rows) do
        row:SetShown(not pad)
        row.setter:SetShown(not pad)
    end
    page.keyStatus:SetShown(not pad)
    if pad and not blocks.padLine then
        blocks.padLine = Style.Text(pane, FONT.body)
        blocks.padLine:SetWidth(BOOK.RIGHT_W)
        blocks.padLine:SetSpacing(2)
        page.macroLine = blocks.padLine
    end
    if blocks.padLine then
        blocks.padLine:SetShown(pad)
        blocks.padLine:SetText(Macro.PadLine(Pad.Glyphs.Text("PAD1", 16)))
    end

    local function Place(p) c:Place(p[1], p[2], p[3], p[4]) end
    local function Books()
        c:PlaceHeading(blocks.books.heading)
        if pad then c:Place(blocks.padLine, blocks.padLine:GetStringHeight(), 0, 10) end
        for _, p in ipairs(blocks.books.placed) do Place(p) end
    end
    if pad then
        Books()
    else
        c:PlaceHeading(keys.heading)
        for _, p in ipairs(keys.placed) do Place(p) end
        Books()
    end
    c:PlaceHeading(blocks.commands.heading)
    for _, p in ipairs(blocks.commands.placed) do Place(p) end
end

-- Interface's second subpage: both keys, the book to drag onto a bar, and
-- the slash commands.
local function BuildShortcuts(pane, c)
    local page = SettingsUI.page
    -- What was placed, block by block, to be laid out again with the pad.
    local blocks = { keys = { rows = {}, placed = {} }, books = { placed = {} }, commands = { placed = {} } }
    local function Place(block, widget, height, indent, gap)
        block.placed[#block.placed + 1] = { widget, height, indent, gap }
        return c:Place(widget, height, indent, gap)
    end

    -- One status line for both keys, under them: what the key did before,
    -- or why it was refused. Room kept, so nothing below moves.
    blocks.keys.heading = c:Heading(L["Keys"])
    page.keyStatus = Style.Text(pane, FONT.small)
    page.keyStatus:SetWidth(BOOK.RIGHT_W)
    page.keys = {}
    for _, b in ipairs(BINDINGS) do
        local row = CreateFrame("Frame", nil, pane)
        row:SetSize(BOOK.RIGHT_W, ns.UI.Keys.KEYCAP.h)
        row.label = Style.Text(row, FONT.body)
        row.label:SetPoint("LEFT")
        row.label:SetWidth(KEY_LABEL_W - 8)
        row.label:SetText(b.label)
        local setter = ns.UI.Keys.Setter(row, b.action, page.keyStatus)
        setter:SetPoint("LEFT", KEY_LABEL_W, 0)
        setter:SetWidth(BOOK.RIGHT_W - KEY_LABEL_W)
        setter.group = c.group   -- (the pad's subheading: Keys)
        -- A key bound may have been the other's: both read again.
        setter.onBound = function() ns.UI.Settings.Refresh() end
        page.keys[b.action] = setter
        page.controls[#page.controls + 1] = setter
        row.setter = setter
        blocks.keys.rows[#blocks.keys.rows + 1] = row
        Place(blocks.keys, row, ns.UI.Keys.KEYCAP.h, 0, 8)
    end
    Place(blocks.keys, page.keyStatus, 28, 0, 0)

    -- One status line for both books, under them, as for the keys.
    blocks.books.heading = c:Heading(L["On your action bar"])
    page.macroHeading = blocks.books.heading
    page.macroStatus = Style.Text(pane, FONT.small)
    page.macroStatus:SetWidth(BOOK.RIGHT_W)
    page.macroBooks = {}
    for _, which in ipairs(MACRO_ORDER) do
        local book = BookButton(pane, page.macroStatus, which)
        book.label = Style.Text(pane, FONT.body)
        book.label:SetPoint("LEFT", book, "RIGHT", 14, 0)
        book.label:SetText(MACROS[which].label)
        book.group = c.group   -- (the pad's subheading)
        page.macroBooks[which] = book
        page.controls[#page.controls + 1] = book
        Place(blocks.books, book, BOOK_ICON + 2, 0, 6)
    end
    Place(blocks.books, page.macroStatus, 28, 0, 0)

    blocks.commands.heading = c:Heading(L["Slash commands"])
    page.commands = {}
    for i, command in ipairs(COMMANDS) do
        local line = Style.Text(pane, FONT.strong)
        line:SetText(command[1])
        local said = Style.Text(pane, FONT.body)
        said:SetPoint("TOPLEFT", line, "TOPLEFT", COMMAND_W, 0)
        said:SetWidth(BOOK.RIGHT_W - COMMAND_W)
        said:SetText(command[2])
        page.commands[i] = Place(blocks.commands, line, math.max(16, said:GetStringHeight()), 0, 5)
    end

    -- (the mouse's page as built; the pad's laid out when it is in hand,
    -- and the pad's focus found again on the page as it now stands)
    local pad = false
    local function Update(active, building)
        active = active and true or false
        if active == pad then return end
        pad = active
        Layout(pane, blocks, pad)
        if not building then Pad.Refresh() end
    end
    Update(Pad.Input.Active(), true)
    Pad.Input.OnChange(function(active) Update(active) end)
end

SettingsUI.RegisterSection("shortcuts", { order = 24, label = L["Keybinds & Shortcuts"], parent = "interface",
    about = L["Keys, macros, and /sd"], build = BuildShortcuts })
