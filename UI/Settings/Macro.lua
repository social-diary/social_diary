-- The diary's two macros (ns.UI.PickupDiaryMacro) and the books that put
-- them on the cursor (ns.UI.Settings.Macro.BookButton), on the Keybinds &
-- Shortcuts subpage (UI/Settings/Sections/Shortcuts.lua).

local addonName, ns = ...

local Style = ns.Style
local SettingsUI = ns.UI.Settings

--------------------------------------------------------------------------
-- The book for an action bar
--------------------------------------------------------------------------
--
-- Two macros, one per book on the Keybinds & Shortcuts page: the journal
-- (/sd) and Remember this (/sd remember). Each is made the first time its
-- book is dragged or clicked, never before: the macro book is the user's,
-- and an addon that writes in it at login has no business there.
-- Account-wide, so every character finds them. They go onto the cursor
-- (PickupMacro) for the user to drop on a slot; the addon never places
-- them itself (PlaceAction).

-- Icons by their file name without the folder, the form the macro API
-- takes in this era of client. Unverified in this build: should a macro
-- show a question mark, its file ID is the other form CreateMacro accepts.
local MACROS = {
    journal = { name = "Social Diary", body = "/sd", icon = "INV_Misc_Book_09",
        art = "book", label = "Open Social Diary" },
    remember = { name = "Remember This", body = "/sd remember", icon = "INV_Misc_Note_01",
        art = "note", label = "Remember this" },
}
local MACRO_ORDER = { "journal", "remember" }
-- How many account macros there is room for, when the client does not say
-- (MAX_ACCOUNT_MACROS lives with Blizzard's macro window, which loads on
-- demand).
local ACCOUNT_MACROS = 120

-- Puts one of the diary's macros on the cursor ("journal", the default, or
-- "remember"), making it first if there is none. Returns true and its
-- index, or false and why not: "combat" (the client refuses macros and
-- action bars in a fight) or "full" (no room left in the account's macros,
-- or the client would not make it).
function ns.UI.PickupDiaryMacro(which)
    local macro = MACROS[which or "journal"]
    if InCombatLockdown() then return false, "combat" end
    local index = GetMacroIndexByName(macro.name)
    if not index or index == 0 then
        local account = GetNumMacros()
        if (account or 0) >= (MAX_ACCOUNT_MACROS or ACCOUNT_MACROS) then return false, "full" end
        local ok, made = pcall(CreateMacro, macro.name, macro.icon, macro.body, nil)
        if not ok or not made or made == 0 then return false, "full" end
        index = made
    end
    PickupMacro(index)
    return true, index
end

local MACRO_SAID = {
    combat = ns.UI.Keys.COMBAT,
    full = "Your macros are full, so there is no room for it. %s works anywhere, typed in chat.",
    click = "It is on your cursor: click a slot on an action bar to put it there.",
    -- (the pad in hand: a slot on the controller's bar is where it goes)
    padClick = "It is on your cursor: place it in a slot on your controller's action bar.",
}

-- The pad in hand (Forever's Gamepad UI on, the pad used last): the book
-- then speaks of the controller's action bar.
local function PadInHand()
    local Pad = ns.UI.Pad
    return Pad ~= nil and Pad.Input ~= nil and Pad.Input.Active() and true or false
end

-- A book: the macro's icon, lying on the page with a hairline
-- round it and a shadow under it, lit from the top left like the rest, to
-- be picked up. Faded and deaf in a fight; SetFight says so, as the
-- client is not in lockdown yet when PLAYER_REGEN_DISABLED arrives.
-- `.diaryMacro` names it for the pad, which stands on it and picks it up
-- with A as a click does (UI/Settings/Pad.lua, UI/Pad/Controls.lua).
local BOOK_ICON = 36

local function BookButton(parent, status, which)
    local macro = MACROS[which]
    local INK = Style.INK
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BOOK_ICON, BOOK_ICON)
    button:RegisterForDrag("LeftButton")
    button.diaryMacro = which

    local shadow = button:CreateTexture(nil, "BACKGROUND")
    shadow:SetSize(BOOK_ICON, BOOK_ICON)
    shadow:SetPoint("TOPLEFT", 2, -2)
    shadow:SetColorTexture(INK[1], INK[2], INK[3], 0.30)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    Style.SetTexture(button.icon, macro.art, 0.3, 0.22, 0.12, 1)
    button.icon:SetTexCoord(unpack(Style.ICON_CROP))
    Style.Hairline(button, "OVERLAY", 0, 0.65)

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.95, 0.8, 0.18)

    function button:SetFight(fight)
        self.unavailable = fight
        self:SetAlpha(fight and 0.45 or 1)
        self.icon:SetDesaturated(fight)
        if fight then self:Disable() else self:Enable() end
        if fight then
            status:SetText(MACRO_SAID.combat)
        elseif status:GetText() == MACRO_SAID.combat then
            status:SetText("")
        end
    end
    function button:Refresh() self:SetFight(InCombatLockdown()) end

    -- Dragged, it is in the hand already; clicked, it says where to put it.
    local function Pickup(self, clicked)
        if self.unavailable then return end
        local ok, why = ns.UI.PickupDiaryMacro(which)
        if ok then
            status:SetText(clicked and (PadInHand() and MACRO_SAID.padClick or MACRO_SAID.click) or "")
        elseif why == "combat" then
            self:SetFight(true)
        else
            status:SetText(MACRO_SAID.full:format(macro.body))
        end
    end
    button:SetScript("OnDragStart", function(self) Pickup(self, false) end)
    button:SetScript("OnClick", function(self) Pickup(self, true) end)

    local mouseTip = { { macro.label }, { "Drag onto an action bar.", 1, 1, 1 } }
    local padTip = { { macro.label }, { "Place it in a slot on your controller's action bar.", 1, 1, 1 } }
    Style.Tooltip(button, function() return PadInHand() and padTip or mouseTip end)
    ns.On("PLAYER_REGEN_DISABLED", function() button:SetFight(true) end)
    ns.On("PLAYER_REGEN_ENABLED", function() button:SetFight(false) end)
    return button
end

-- What the pad's player is told beside the books: what to do with one.
-- `glyph` is A as their pad draws it; `one`: a single book lies there.
local function PadLine(glyph, one)
    return ("Pick up %s with %s, then place it in a slot on your controller's action bar.")
        :format(one and "the book" or "a book", glyph)
end

SettingsUI.Macro = { MACROS = MACROS, MACRO_ORDER = MACRO_ORDER, BOOK_ICON = BOOK_ICON, BookButton = BookButton,
    SAID = MACRO_SAID, PadLine = PadLine, PadInHand = PadInHand }
