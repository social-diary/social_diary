-- Settings: Language, Interface's last subpage (UI/Settings/Page.lua lists
-- the sections; the controls are UI/Settings/Kit.lua's): the language the
-- diary is written in (the account setting `language`: "auto", the game
-- client's, or a locale's id), what waits for a reload, and where to send
-- a correction. Which language is read, and when, is Locales/Locale.lua's
-- ("Which language"): this page only writes the setting and says how it
-- stands.
--
-- The words are taken as the files load, so a choice applies after a
-- reload: the page says so while one waits (Locale.Pending) and offers the
-- reload, asked first, as Memory's shared diary is. Where a saved choice
-- did not take (Locale.stuck: this client hands the saved settings over
-- too late) it says that instead and offers no reload.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Locale = ns.Locale

-- A language by the name its own readers call it (never translated). One
-- the diary has no words for reads English, so that is its name here.
local function NameOf(id)
    for _, offer in ipairs(Locale.offered) do
        if offer.id == id then return offer.name end
    end
    return Locale.offered[1].name
end

-- The choices as they are now: the game's language first (saying which
-- where the diary has words for it), then each language offered, English
-- first.
local function Choices()
    local auto = L["The game's language"]
    if Locale.Offers(Locale.client) then
        auto = Fmt(L["The game's language (%s)"], NameOf(Locale.client))
    end
    local choices = { { label = auto, key = "auto" } }
    for _, offer in ipairs(Locale.offered) do
        choices[#choices + 1] = { label = offer.name, key = offer.id }
    end
    return choices
end

-- The reload's question: what changes, and what does not.
local function ReloadText(name)
    return Fmt(L["Write the diary in %s?\n\nThe interface reloads, and the diary's own words are then in that language. Your notes stay as you wrote them."], name)
end

-- How far under the last small print the rest of the page begins, and
-- under the line that says how the choice stands, while there is one.
local STATE_GAP, REST_GAP = 4, 8

local function BuildLanguage(pane, c)
    local page = SettingsUI.page
    local ACCENT = Style.ACCENT

    page.language = Kit.Choice(c, L["Write the diary in"], "language", Choices, nil, L["Write the diary in"])
    page.languageHint = c:Hint(L["Switching requires a reload. Applies to every character."])
    page.languageNames = c:Hint(L["Names the game supplies, such as zones, classes and items, stay in the game's language."])
    if not Locale.Offers(Locale.client) then
        page.languageNoWords = c:Hint(L["The diary has no words for the game's language yet, so it is written in English."])
    end

    -- How the choice stands, while it is not the language read: waiting
    -- for a reload (and the reload, asked first), or not to be had here.
    local top = c.y
    page.languageState = Style.Text(pane, FONT.body)
    page.languageState:SetWidth(c.width)
    page.languageState:SetWordWrap(true)
    page.languageState:SetPoint("TOPLEFT", pane, "TOPLEFT", c.x, top - STATE_GAP)

    page.languageReload = Style.Link(pane, FONT.body, function()
        local wanted = Locale.Wanted(ns.Setting("language"))
        if not Locale.Pending(ns.Setting("language")) or Locale.stuck then return end
        ns.UI.Dialog.Confirm(ReloadText(NameOf(wanted)), function()
            if ReloadUI then ReloadUI() end
        end, L["Reload"])
    end)
    page.languageReload:SetText(L["Reload"])
    page.languageReload:SetPoint("TOPLEFT", page.languageState, "BOTTOMLEFT", 0, -6)

    -- The rest of the page, on a frame of its own, so it moves up while
    -- there is nothing to say above it.
    local rest = CreateFrame("Frame", nil, pane)
    rest:SetSize(c.width, 120)
    page.languageRest = rest
    local r = Kit.Column(rest, 0, 0, c.width)
    r:Heading(L["Translations"])
    page.languageAbout = Style.Text(rest, FONT.body)
    page.languageAbout:SetWidth(c.width)
    page.languageAbout:SetWordWrap(true)
    page.languageAbout:SetText(L["Every language but English was translated by a machine, so some lines may read oddly or wrongly. Corrections are welcome."])
    r:Place(page.languageAbout, page.languageAbout:GetStringHeight(), 0, 8)

    -- Feedback's page, and with the pad in hand the pad on its row: that
    -- page has nothing for the pad to stand on (its slips want a keyboard).
    page.languageFeedback = Style.Link(rest, FONT.body, function()
        ns.UI.ShowSettings("feedback")
        local Pad = ns.UI.Pad
        local scope = Pad.Scope("settings")
        if scope and scope.focus and Pad.Top() == scope then
            scope.focus:Remember("nav", "nav:feedback")
            scope.focus:EnterGroup("nav")
        end
        Pad.Refresh()
    end)
    page.languageFeedback:SetText(L["Go to Feedback"])
    page.languageFeedback.group = r.group
    r:Place(page.languageFeedback, 18)

    page.controls[#page.controls + 1] = {
        Refresh = function()
            local setting = ns.Setting("language")
            local pending = Locale.Pending(setting)
            local state = page.languageState
            if Locale.stuck then
                state:SetText(L["The diary can't change language on this game client, because your choice reaches it too late. It stays in the game's language."])
                state:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
            elseif pending then
                state:SetText(Fmt(L["The diary is written in %s once the interface reloads."],
                    NameOf(Locale.Wanted(setting))))
                state:SetTextColor(unpack(Style.INK))
            else
                state:SetText("")
            end
            local said = Locale.stuck or pending
            local reload = pending and not Locale.stuck
            state:SetShown(said)
            page.languageReload:SetShown(reload)

            local y = top
            if said then y = y - STATE_GAP - state:GetStringHeight() - 6 end
            if reload then y = y - 18 - 6 end
            rest:ClearAllPoints()
            rest:SetPoint("TOPLEFT", pane, "TOPLEFT", c.x, y - (said and REST_GAP or 0))
        end,
    }
end

SettingsUI.RegisterSection("language", { order = 28, label = L["Language"], parent = "interface",
    about = L["The language the diary is written in"], build = BuildLanguage })
