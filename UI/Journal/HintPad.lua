-- A hint's slip with the pad (.claude/controller-plan.md, step 7b; the slip
-- is UI/Paper/HintSlip.lua's, laid by UI/Journal/Hints.lua).
--
-- A slip comes by itself, after five seconds on a page, often while the
-- player is walking it: it **never moves the pad**. It joins the open
-- page's focus (Pad.JoinAside) as a thing of its own at the book's
-- fore-edge, where it lies: going right off the edge of anything on the
-- page reaches it, and left (or B, see below) goes back where the pad was.
-- On it, it is outlined as a thing of paper is (red, a slight red shadow,
-- its rubric title red), and the × in its corner darkens, as under the
-- mouse. A does what a click does: its link where it has one ("Go to
-- Settings"), else puts it away; B puts it away as a click on it does.
-- Either way the pad goes back where it came from. Only over a page's own
-- scope (or the bare book's): a sheet over the page (writing, a note, a
-- card, the run's map, the introduction) leaves it alone.

local addonName, ns = ...

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local HintSlip = ns.UI.HintSlip

-- The layer of a page's own scope: anything higher is a sheet over it.
local PAGE_LAYER = 20

local PROMPT = {
    away = { "PAD1", "Put the hint away", main = true },
    back = { "PAD2", "Put the hint away" },
}

local function Out(top)
    local slip = HintSlip.Frame()
    if not (slip and HintSlip.Shown() and slip:IsVisible()) then return nil end
    if not (J.journal and top.host() == J.journal and slip.page == J.view) then return nil end
    if (top.layer or 0) > PAGE_LAYER then return nil end
    return slip
end

-- Anything on the page to walk from: an empty page keeps its D-pad for
-- the game, and a slip alone would take it.
local function Walked(f)
    for _, name in ipairs(f.order) do
        if #f.groups[name].items > 0 then return true end
    end
    return false
end

Pad.RegisterJoin("hint", {
    join = function(f, top)
        local slip = Out(top)
        if not (slip and Walked(f)) then return end
        local S = slip.view.sheet
        local function Back()
            Pad.Refresh()
            return true
        end
        Pad.JoinAside(f, "hint", {
            key = "hint",
            frame = S,
            available = function() return HintSlip.Shown() and slip:IsVisible() end,
            outline = function()
                return { anchor = slip, corners = HintSlip.Corners(), level = S:GetFrameLevel() }
            end,
            heading = slip.title,
            enter = function()
                local fn = S:GetScript("OnEnter")
                if fn then fn(S) end
            end,
            leave = function()
                local fn = S:GetScript("OnLeave")
                if fn then fn(S) end
            end,
            press = function()
                if slip.link:IsShown() then slip.link:Click() else HintSlip.PutAway() end
                Back()
            end,
            back = function()
                HintSlip.PutAway()
                return Back()
            end,
            legend = function()
                local a = slip.link:IsShown() and { "PAD1", slip.link.label:GetText() or "", main = true } or PROMPT.away
                return { a, PROMPT.back }
            end,
        })
    end,
})
