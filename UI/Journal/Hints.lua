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
        return { title = "Something missing?", body = "Right-Click the map to add events yourself." }
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
        return { title = "Quickly Add Notes", body = "Assign a hotkey to add a note quickly.",
            link = "Go to Settings", onLink = function() ns.UI.ShowSettings("shortcuts") end }
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
        return { title = "Quickly Add Notes",
            body = ("Remember to use your hotkey for adding Notes! (%s)"):format(RememberKey() or "") }
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

local function Put()
    if showing then
        showing = nil
        ns.UI.HintSlip.Hide()
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
        if showing and showing.page ~= ctx.view then Put() end
    end
    -- Kept up whether or not a hint is due: the sitting the key was first
    -- seen bound in (Core/Hints.lua's BoundFor).
    Hints.BoundFor(RememberKey() ~= nil)
    if showing or now - since < Hints.DWELL or InTheWay() then return end
    local spec = Hints.Due(ctx)
    if not spec then return end
    showing = spec
    Hints.Shown(spec.id)
    ns.UI.HintSlip.Show(J.journal.views[spec.page], spec.page, spec.words(), Put)
end

local ticker
local function Watch()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(HintsUI.TICK, function() HintsUI.Look() end)
end

-- The book is built on its first opening, after this file loads: watch from
-- the first login on, the ticker doing nothing while the book is shut.
ns.On("PLAYER_LOGIN", Watch)
