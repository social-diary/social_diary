-- The book with the pad (.claude/controller-plan.md, step 2): the
-- shoulder buttons turn the ribbons, left and right, round from the last to
-- the first; B closes the book. Every page's own scope has this one as its
-- parent, so the ribbons turn whatever page is open.
--
-- A ribbon is turned by clicking it, so the pad turns the book exactly as
-- the mouse does: the page-turn sound, the stack, and the introduction's
-- sheet put away.
--
-- A ribbon has no words of its own, so after a turn the page it opened
-- lends its title (its `title`, UI/Journal/Pages.lua): the title holds the
-- pad's box until the first D-pad press (HOLD_TITLE). A page without a
-- title gets no box. With a page's own scope on top (later steps) this
-- scope builds nothing; that scope reads `held` here to do the same.

local addonName, ns = ...

local L = ns.L

local J = ns.UI.Journal
local Pad = ns.UI.Pad

-- The user's default (7 Nov 2026): the opened page's title holds the box
-- after a ribbon turn. False: no box until the page's own focus.
local HOLD_TITLE = true

-- The page whose title holds the box, or nil.
local held

local function Title()
    local spec = J.Page(J.view)
    local fs = spec and spec.title and spec.title()
    if fs and fs:IsVisible() then return fs end
end

local hooked
local function Turn(delta)
    local ribbons = J.Ribbons()
    local at = 1
    for i, r in ipairs(ribbons) do
        if r.key == J.view then at = i end
    end
    local key = ribbons[(at - 1 + delta) % #ribbons + 1].key
    local ribbon = J.journal and J.journal.ribbons[key]
    if not ribbon then return end
    if not hooked then
        -- (a book closed lets the title go)
        hooked = true
        J.journal:HookScript("OnHide", function() held = nil end)
    end
    held = HOLD_TITLE and key or nil
    ribbon:Click("LeftButton")
end

-- The first D-pad press after a turn lets the title go, and goes no
-- further; any other time a direction is not the book's.
local function LetGo()
    local was = held
    held = nil
    if not was or was ~= J.view then return false end
    Pad.Refresh()
end

local beside = setmetatable({}, { __mode = "k" })
local function Ribbons()
    local journal = J.journal
    if not journal then return nil end
    local list = J.Ribbons()
    local first, last = journal.ribbons[list[1].key], journal.ribbons[list[#list].key]
    local b = beside[journal]
    if not b or b[1] ~= first or b[2] ~= last then
        b = { first, last }
        beside[journal] = b
    end
    return b
end

local scope = {
    layer = 10,
    host = function() return J.journal end,
    active = function() return true end,
    build = function(f)
        if not (held and held == J.view) then return end
        local fs = Title()
        if not fs then return end
        f:Group("title", { mode = "list" })
        f:Add("title", {
            key = "title:" .. J.view,
            words = fs,
            available = function() return fs:IsVisible() end,
            -- (no tooltip, and A is not the title's)
            enter = function() end,
            leave = function() end,
        })
    end,
    keys = {
        PADLSHOULDER = function() Turn(-1) end,
        PADRSHOULDER = function() Turn(1) end,
        PADDUP = LetGo, PADDDOWN = LetGo, PADDLEFT = LetGo, PADDRIGHT = LetGo,
    },
    back = function()
        ns.UI.CloseJournal()
        return true
    end,
    legend = function()
        return {
            { { "PADLSHOULDER", "PADRSHOULDER" }, L["Turn the page"], beside = Ribbons() },
            { "PAD2", L["Close the book"] },
        }
    end,
}
-- Whether the open page's title holds the box (for a page's own scope).
function scope.held() return held ~= nil and held == J.view end

Pad.RegisterScope("journal", scope)
