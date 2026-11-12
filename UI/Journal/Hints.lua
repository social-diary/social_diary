-- The hints on the pages (Core/Hints.lua says when one may come): which
-- there are, what each says, and the watcher that lays one on its page.
--
-- While the book is open the watcher looks twice a second at where it lies:
-- the page, the person open on it, whether the player is in a group. Five
-- seconds on the same page (HNT-4) and nothing in the way (HNT-5: combat,
-- the introduction's sheet, the dungeon map or its note, writing mode, a
-- confirm popup), it asks Core for the hint due there and lays it, one at a
-- time (HNT-6), on a slip of its own (UI/Paper/HintSlip.lua), which brings
-- its own sound as it comes. Laid is seen (HNT-7). The slip goes with its
-- page, and with the book.

local addonName, ns = ...

local Hints = ns.Hints
local J = ns.UI.Journal
local L, Fmt = ns.L, ns.Fmt

local HintsUI = {}
ns.UI.Hints = HintsUI

local REMEMBER = "SOCIALDIARY_REMEMBER"
HintsUI.TICK = 0.5

-- The Remember this key's text ("F7"), or nil where it has none.
local function RememberKey()
    return ns.UI.Keys.Bound(REMEMBER)
end

-- A custom card inserted on any route of the diary in use: what the hint
-- teaches, done before it came (an edited card retires it as it is made,
-- Core/Custom.lua).
local function AnyCustom()
    for _, j in pairs(ns.db.journey or {}) do
        if type(j) == "table" and type(j.custom) == "table" and j.custom[1] then return true end
    end
    return false
end

--------------------------------------------------------------------------
-- The hints
--------------------------------------------------------------------------

-- a) Your Diary's map takes cards of the player's own (right-click).
Hints.Register("custom-events", {
    order = 10,
    page = "journey",
    eligible = function() return Hints.Opens() >= 10 end,
    done = AnyCustom,
    words = function()
        return { title = L["Something missing?"], body = L["Right-Click the map to add events yourself."] }
    end,
})

-- b) Writing a moment down as it happens, on the key: the People page,
-- with others in the group. First a key to press...
Hints.Register("remember-bind", {
    order = 20,
    page = "people",
    eligible = function(ctx) return ctx.inGroup and RememberKey() == nil end,
    fits = function() return RememberKey() == nil end,
    done = function() return RememberKey() ~= nil end,
    words = function()
        return { title = L["Quickly Add Notes"], body = L["Assign a hotkey to add a note quickly."],
            link = L["Go to Settings"], onLink = function() ns.UI.ShowSettings("shortcuts") end }
    end,
})

-- ...then, bound three sittings and never pressed, the key itself.
HintsUI.UNUSED_SITTINGS = 3
Hints.Register("remember-use", {
    order = 21,
    page = "people",
    eligible = function(ctx)
        local key = RememberKey()
        return ctx.inGroup and key ~= nil and Hints.Remembers() == 0
            and (Hints.BoundFor(true) or 0) >= HintsUI.UNUSED_SITTINGS
    end,
    done = function() return Hints.Remembers() > 0 end,
    fits = function() return RememberKey() ~= nil end,
    words = function()
        return { title = L["Quickly Add Notes"],
            body = Fmt(L["Remember to use your hotkey for adding Notes! (%s)"], RememberKey() or "") }
    end,
})

-- c) News, not teaching: the first time the book opens after a major
-- update (2.x to 3.0, Core/Hints.lua's Installed), on whatever page it
-- opens on, past the clocks, behind its own switch. Over once laid, or
-- once the Changelog has been read.
Hints.Register("major-update", {
    order = 1,
    page = "any",
    notice = true,
    setting = "showUpdateHint",
    dwell = 1.5,
    eligible = function() return Hints.Update() ~= nil end,
    shown = function() Hints.UpdateRead() end,
    words = function()
        local version = Hints.Update() or ns.version
        return { title = L["Fresh Pages"],
            body = Fmt(L["Social Diary %s is here, with a few new things to find."], version),
            link = L["See what’s new"], onLink = function() ns.UI.ShowSettings("changelog") end }
    end,
})

-- e) News, not teaching: the first time the book opens in a translation
-- (any language but English that the diary has words for), once for each
-- language, on whatever page it opens on, past the clocks, behind its own
-- switch (showLanguageHint, Interface beside the update's). It comes after
-- the update's notice, never in the same opening as another notice, so the
-- two come over two openings. Its link begins picking a line to correct
-- (UI/Windows/Suggest/), or, with the pad in hand or without that folder,
-- turns to the Language page, where the same is said.
local function LanguageName(id)
    for _, offer in ipairs(ns.Locale.offered) do
        if offer.id == id then return offer.name end
    end
    return id
end

-- Whether a line can be picked from the notice's link: the folder is there
-- and the pad not in hand.
local function CanSuggest()
    local Suggest = ns.UI.Suggest
    return Suggest ~= nil and Suggest.Available()
end

local function ToLanguage()
    ns.UI.ShowSettings("language")
    local Pad = ns.UI.Pad
    local scope = Pad.Scope and Pad.Scope("settings")
    if scope and scope.focus and Pad.Top() == scope then
        scope.focus:Remember("nav", "nav:language")
        scope.focus:EnterGroup("nav")
    end
    Pad.Refresh()
end

Hints.Register("translation", {
    order = 1.5,
    page = "any",
    notice = true,
    setting = "showLanguageHint",
    dwell = 1.5,
    eligible = function()
        local id = ns.Locale.id
        return id ~= "enUS" and ns.Locale.Offers(id) and not Hints.LanguageSeen(id)
            and HintsUI.noticeOpen ~= Hints.Opens()
    end,
    shown = function() Hints.LanguageShown(ns.Locale.id) end,
    words = function()
        local suggest = CanSuggest()
        return { title = L["Translated Pages"],
            body = Fmt(L["The diary is now written in %s. The translation is early and machine-made, so expect odd lines and clipped text. Corrections are welcome."],
                LanguageName(ns.Locale.id)),
            link = suggest and L["Suggest Translation"] or L["Go to Language"],
            onLink = function()
                if CanSuggest() then ns.UI.Suggest.Start() else ToLanguage() end
            end }
    end,
})

-- d) News, not teaching: old battleground scoreboards are about to fade
-- (Core/Matches.lua's roll-up), at 25, 10, 5, 4, 3, 2 and 1 matches
-- before it starts, each step once (Matches.Warned). On whatever page the
-- book opens on: what it warns of happens at the next matches, wherever
-- the player is reading, and what can be done about it is in Settings,
-- not on Your Diary; a notice kept to one page could miss its step.
-- Behind its own switch (boardWarnings, Battlegrounds settings).
Hints.Register("board-rollup", {
    order = 2,
    page = "any",
    notice = true,
    setting = "boardWarnings",
    dwell = 1.5,
    eligible = function() return ns.Matches.WarningDue() ~= nil end,
    shown = function()
        local step = ns.Matches.WarningDue()
        if step then ns.Matches.Warned(step) end
    end,
    words = function()
        local _, left = ns.Matches.WarningDue()
        left = left or ns.Matches.UntilRollup()
        return { title = L["Old Scoreboards"],
            body = ns.Plural(left, L["In %d match, your oldest battleground scoreboards begin to lose their strangers. The people in your diary stay on them.|In %d matches, your oldest battleground scoreboards begin to lose their strangers. The people in your diary stay on them.##plural"]),
            link = L["Keep more"], onLink = function() ns.UI.ShowSettings("battlegrounds") end }
    end,
})

--------------------------------------------------------------------------
-- The watcher
--------------------------------------------------------------------------

local function InGroup()
    return IsInGroup and IsInGroup() and (GetNumGroupMembers and GetNumGroupMembers() or 0) > 1 or false
end

-- Whatever lies over the page or holds the player, a hint waits for it.
local function InTheWay()
    if InCombatLockdown and InCombatLockdown() then return true end
    local Tour = ns.UI.Tour
    if Tour and (Tour.step or Tour.example) then return true end
    if J.visit or J.editing then return true end
    local note = ns.UI.DungeonPage and ns.UI.DungeonPage.TutorialNote and ns.UI.DungeonPage.TutorialNote()
    if note and note:IsShown() then return true end
    if StaticPopup_Visible and StaticPopup_Visible("SOCIAL_DIARY_CONFIRM") then return true end
    return false
end

-- Where the book lies now, and since when it has lain there.
local where, since
local showing   -- the hint's spec while its slip is out
local laidOn    -- the page it lies on (a notice's "any" made one)

-- The pad told a slip came or went: it joins the page's focus, or leaves
-- it (UI/Journal/HintPad.lua). Nothing while the pad is not in hand.
local function Told()
    local Pad = ns.UI.Pad
    if Pad and Pad.Input.Active() then Pad.Refresh() end
end

local function Put()
    if showing then
        showing = nil
        ns.UI.HintSlip.Hide()
        Told()
    end
end

function HintsUI.Showing() return showing end

-- One look (the ticker's, or a test's with `now` in GetTime's seconds).
function HintsUI.Look(now)
    now = now or GetTime()
    if not ns.UI.JournalShowing() then
        where, since = nil, nil
        Put()
        return
    end
    local ctx = { view = J.view, selected = J.selected, inGroup = InGroup() }
    local here = ctx.view .. ":" .. tostring(ctx.selected)
    if here ~= where then
        where, since = here, now
        -- The slip lies on its page: turned away from, it goes.
        if showing and laidOn ~= ctx.view then Put() end
    end
    -- Kept up whether or not a hint is due: the sitting the key was first
    -- seen bound in (Core/Hints.lua's BoundFor).
    Hints.BoundFor(RememberKey() ~= nil)
    if showing or InTheWay() then return end
    local spec = Hints.Due(ctx)
    if not spec or now - since < (spec.dwell or Hints.DWELL) then return end
    -- Read before Shown: a notice's words may name what Shown clears.
    local words = spec.words()
    showing, laidOn = spec, ctx.view
    -- The opening a notice came in: the translation's waits for the next.
    if spec.notice then HintsUI.noticeOpen = Hints.Opens() end
    Hints.Shown(spec.id)
    ns.UI.HintSlip.Show(J.journal.views[ctx.view], ctx.view, words, Put)
    Told()
end

local ticker
local function Watch()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(HintsUI.TICK, function() HintsUI.Look() end)
end

-- The book is built on its first opening, after this file loads: watch from
-- the first login on, the ticker doing nothing while the book is shut.
ns.On("PLAYER_LOGIN", Watch)
