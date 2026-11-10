-- The introduction with the pad (.claude/controller-plan.md, step 7b): the
-- parcel at login (UI/Windows/Intro/Parcel.lua), the tour's sheet over Your
-- Diary and its example on the People page (UI/Windows/Intro/Tour.lua).
--
-- The parcel (`parcel`, layer 50, no parent) comes by itself a few seconds
-- after login, while the player may already be running or fighting
-- through a loading screen's worth of buttons: **it does not take the pad
-- by itself**, and nothing at login says Pad.Opened for it. Taking it on
-- the first pad press instead would still eat that press (A is jump) and
-- needs the catcher on to hear it at all. A player with the pad in hand
-- reaches it without it: the book's key opens the book on the tour (the
-- parcel's "Open me"; Tour.Lay puts the parcel away), and the Escape
-- stand-in (GamePadEmulateEsc) puts it away as Escape does. Should a path
-- of the player's own ever lay it (Pad.Opened(slip)), it takes the pad:
-- wrapped, the seal (ringed: A tears it, as its click), "Tear it open",
-- "Later"; torn, the note's "Open me" and "Later"; up/down and left/right
-- walk them. The ribbons out of the closed book are drawn, not clickable,
-- so they are not walked. B is Later. Lands on the seal, then on "Open me"
-- once torn.
--
-- The tour (`tour`, layer 28, parent `journal`: the shoulders turn the
-- page, which puts the sheet away as a ribbon does) has the pad while its
-- sheet lies on the book, over Your Diary's own scope, which keeps its
-- place under it. Walked top down: the progress marks of the steps passed
-- (ringed, A goes back to that step), then the step's one action:
-- "Continue" (steps 1 to 3), "+ Add" on Thex's strip (4), his name (5:
-- the example). It lands on the action at each step. B puts the sheet away
-- as Escape does (seen, Thex not written); Your Diary's scope has the pad
-- again where it was.
--
-- The example (`example`, a join on the People page: Pad.JoinAside): its
-- strip ("Begin your own diary") lies at the page's foot, reached by going
-- right off the page's edge; reached by the pad from the tour (A on Thex),
-- the pad lands on it, as that A asked for it. A begins; B or left goes
-- back to the page.

local addonName, ns = ...

local L = ns.L

local Pad = ns.UI.Pad
local Parcel = ns.UI.Parcel
local Tour = ns.UI.Tour
local J = ns.UI.Journal

-- How far over a window the box is drawn (over its controls).
local OVER = 30

local PROMPT = {
    tear = { "PAD1", L["Tear it open"], main = true },
    open = { "PAD1", L["Open the introduction"], main = true },
    later = { "PAD1", L["Later"], main = true },
    away = { "PAD2", L["Put the parcel away"] },
    continue = { "PAD1", L["Continue"], main = true },
    add = { "PAD1", L["Add Thex"], main = true },
    thex = { "PAD1", L["Open his page"], main = true },
    step = { "PAD1", L["Back to this step"], main = true },
    sheet = { "PAD2", L["Put the introduction away"] },
    begin = { "PAD1", L["Begin your own diary"], main = true },
    page = { "PAD2", L["Back to the page"] },
}

local function Run(frame, name)
    local fn = frame and frame:GetScript(name)
    if fn then fn(frame, false) end
end

-- Items of a row of links walked up/down, and left/right as well: a step
-- to the one before or after (nothing is drawn for it).
local function Row(f, group, items)
    for i, item in ipairs(items) do
        -- (a click, then what is walked found again: the paper torn is
        -- laid again)
        item.press = function()
            item.frame:Click("LeftButton")
            Pad.Refresh()
        end
        item.step = function(dir)
            local other = items[i + (dir == "LEFT" and -1 or 1)]
            return other ~= nil and f:Focus(other.key, group)
        end
        f:Add(group, item)
    end
end

--------------------------------------------------------------------------
-- The parcel
--------------------------------------------------------------------------

local function Slip()
    local slip = Parcel.slip
    return slip and Pad.Owns(slip) and slip or nil
end

local parcel = {
    layer = 50,
    host = function() return Parcel.slip end,
    active = function() return Slip() ~= nil end,
}

function parcel.build(f)
    f:Group("parcel", { mode = "list" })
    local slip = Slip()
    if not slip then return end
    local level = slip:GetFrameLevel() + OVER
    local land
    if slip.state == "wrapped" then
        Row(f, "parcel", {
            { key = "seal", frame = slip.seal, ring = true, level = level, prompt = PROMPT.tear },
            -- (light words on the game world: boxed, left in their colours)
            { key = "tear", frame = slip.tear, plain = true, level = level, prompt = PROMPT.tear },
            { key = "later", frame = slip.later, plain = true, level = level, prompt = PROMPT.later },
        })
        land = "seal"
    else
        local note = slip.note
        Row(f, "parcel", {
            { key = "open", frame = note.open, level = level, prompt = PROMPT.open },
            { key = "notelater", frame = note.later, level = level, prompt = PROMPT.later },
        })
        land = "open"
    end
    -- (each opening, and the paper torn, lands afresh)
    local at = tostring(Pad.Opening(slip)) .. slip.state
    if at ~= parcel.landed then
        parcel.landed = at
        f:Within("parcel")
        f:Remember("parcel", land)
    end
end

function parcel.back()
    if not Slip() then return false end
    Parcel.later = true
    Parcel.HideSlip(false)
    return true
end

function parcel.legend()
    local at = parcel.focus and parcel.focus:Current()
    return { at and at.prompt or nil, PROMPT.away }
end

Pad.RegisterScope("parcel", parcel)

--------------------------------------------------------------------------
-- The tour
--------------------------------------------------------------------------

-- Reached by the pad's A on Thex: the example lands the pad on its strip.
local landExample = false

local function Showing()
    return Tour.step ~= nil and Tour.host ~= nil and Tour.host:IsVisible()
end

local tour = {
    layer = 28,
    parent = "journal",
    host = function() return J.journal end,
    active = function() return Showing() end,
}

-- An item on a strip's line of the tour (its foot, its aside): the line's
-- words boxed, A its click.
local function Line(key, button, prompt, press)
    return {
        key = key, frame = button, words = button.label, prompt = prompt,
        level = button:GetFrameLevel() + 2,
        press = press or function() button:Click() end,
    }
end

function tour.build(f)
    f:Group("sheet", { mode = "list" })
    if not Showing() then return end
    local n, s = Tour.step, Tour.strips
    for k, m in ipairs(Tour.progress.marks) do
        if m.passed then
            f:Add("sheet", {
                key = "mark:" .. k, frame = m.button, ring = true, prompt = PROMPT.step,
                level = m.button:GetFrameLevel() + 2,
                enter = function() end, leave = function() end,
            })
        end
    end
    local action
    if n <= 3 and s.step.foot then
        action = f:Add("sheet", Line("continue", s.step.foot, PROMPT.continue))
    elseif n == 4 and s.thex.aside then
        action = f:Add("sheet", Line("add", s.thex.aside, PROMPT.add))
    elseif n == 5 then
        action = f:Add("sheet", {
            key = "thex", frame = s.thex.link, words = s.thex.name, prompt = PROMPT.thex,
            level = s.thex:GetFrameLevel() + 4,
            press = function()
                landExample = true
                s.thex.link:Click()
            end,
        })
    end
    -- (each step lands on its action)
    if action and n ~= tour.landed then
        tour.landed = n
        f:Within("sheet")
        f:Remember("sheet", action.key)
    end
end

-- B: the sheet put away, as Escape does.
function tour.back()
    if not Showing() then return false end
    Tour.host:Hide()
    tour.landed = nil
    Pad.Refresh()
    return true
end

function tour.legend()
    local at = tour.focus and tour.focus:Current()
    return { at and at.prompt or nil, PROMPT.sheet }
end

Pad.RegisterScope("tour", tour)

--------------------------------------------------------------------------
-- The example
--------------------------------------------------------------------------

Pad.RegisterJoin("example", {
    join = function(f, top)
        local strip = Tour.endStrip
        if not (Tour.example and strip and strip:IsVisible() and J.view == "people" and top.parent == "journal"
            and (top.layer or 0) <= 20 and strip.foot) then
            -- (kept while the example is still being laid)
            if not Tour.example then landExample = false end
            return
        end
        Pad.JoinAside(f, "example", {
            key = "example", frame = strip.foot,
            outline = function()
                local now = strip:Focus()
                return { anchor = strip:GetParent(), corners = now.corners, level = strip:GetFrameLevel() }
            end,
            heading = strip.name,
            enter = function() Run(strip.foot, "OnEnter") end,
            leave = function() Run(strip.foot, "OnLeave") end,
            press = function() strip.foot:Click() end,
            legend = function() return { PROMPT.begin, PROMPT.page } end,
        })
        if landExample then
            landExample = false
            Pad.LandAside(f, "example")
        end
    end,
})
