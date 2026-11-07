-- Settings: Keybinds & Shortcuts, Interface's second subpage
-- (UI/Settings/Page.lua lists the sections; the controls are
-- UI/Settings/Kit.lua's): both keys, the books to drag onto a bar
-- (UI/Settings/Macro.lua), and the slash commands.

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

-- Interface's second subpage: both keys, the book to drag onto a bar, and
-- the slash commands.
local function BuildShortcuts(pane, c)
    local page = SettingsUI.page

    -- One status line for both keys, under them: what the key did before,
    -- or why it was refused. Room kept, so nothing below moves.
    c:Heading(L["Keys"])
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
        -- A key bound may have been the other's: both read again.
        setter.onBound = function() ns.UI.Settings.Refresh() end
        page.keys[b.action] = setter
        page.controls[#page.controls + 1] = setter
        c:Place(row, ns.UI.Keys.KEYCAP.h, 0, 8)
    end
    c:Place(page.keyStatus, 28, 0, 0)

    -- One status line for both books, under them, as for the keys.
    c:Heading(L["On your action bar"])
    page.macroStatus = Style.Text(pane, FONT.small)
    page.macroStatus:SetWidth(BOOK.RIGHT_W)
    page.macroBooks = {}
    for _, which in ipairs(MACRO_ORDER) do
        local book = BookButton(pane, page.macroStatus, which)
        book.label = Style.Text(pane, FONT.body)
        book.label:SetPoint("LEFT", book, "RIGHT", 14, 0)
        book.label:SetText(MACROS[which].label)
        page.macroBooks[which] = book
        page.controls[#page.controls + 1] = book
        c:Place(book, BOOK_ICON + 2, 0, 6)
    end
    c:Place(page.macroStatus, 28, 0, 0)

    c:Heading(L["Slash commands"])
    page.commands = {}
    for i, command in ipairs(COMMANDS) do
        local line = Style.Text(pane, FONT.strong)
        line:SetText(command[1])
        local said = Style.Text(pane, FONT.body)
        said:SetPoint("TOPLEFT", line, "TOPLEFT", COMMAND_W, 0)
        said:SetWidth(BOOK.RIGHT_W - COMMAND_W)
        said:SetText(command[2])
        page.commands[i] = c:Place(line, math.max(16, said:GetStringHeight()), 0, 5)
    end
end

SettingsUI.RegisterSection("shortcuts", { order = 24, label = L["Keybinds & Shortcuts"], parent = "interface",
    about = L["Keys, macros, and /sd"], build = BuildShortcuts })
