-- Writing mode on a person's page with the pad (.claude/controller-plan.md,
-- step 5b; the form is UI/Windows/Entry.lua's, laid on the right page by
-- UI/Journal/Profile.lua while J.editing).
--
-- A scope of its own over the People page's (`layer` above it), with the
-- book's as its parent, so the shoulders still turn the ribbons (which ends
-- writing, as a ribbon pulled with the mouse does). The edit tab opens it
-- (A on the tab, UI/Journal/PeoplePad.lua), and so does every other way in
-- (the key, a menu): the pad lands on the form's first control.
--
-- The form's controls are found, not listed (Pad.Controls): the tags (A
-- puts one on or takes it off; one of the player's own, A takes away), the
-- line to add a tag, the relationship, the note, "Remove from the diary" and
-- Done, in the order they are laid out, each its label's subheading. A line
-- to write in takes the keyboard's cursor with A; A again, B, or the pad
-- moving off takes it back, and what was written is kept (the lines save as
-- they let go, as under the mouse). Removing asks first in Blizzard's popup,
-- and the pad steps aside while it is up (Pad.Aside, UI/Kit/Confirm.lua).
-- Up off the first control, or right from any, are the index tabs; down or
-- left from them, the form. A tab is its click (its page; the edit tab ends
-- writing).
--
-- B: off a line being written on; then out of writing mode as the edit tab
-- does (J.EndEdit: whatever was typed is kept), and the People page's scope
-- has the pad where it was (the edit tab, if A was pressed there).

local addonName, ns = ...

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Controls = Pad.Controls

local function Profile() return J.journal and J.journal.profile end

local PROMPT = {
    stop = { "PAD2", "Stop writing" },
    leave = { "PAD2", "Done writing" },
    tabs = { "PADDRIGHT", "Go to the tabs" },
    story = { "PAD1", "See their story", main = true },
    seen = { "PAD1", "See where you saw them", main = true },
    note = { "PAD1", "Add a note", main = true },
    edit = { "PAD1", "Done writing", main = true },
}

-- Writing about someone on their page (asked from the moment J.Edit says
-- so, before the page is drawn: the People page's scope never sees a page
-- half turned to writing, and its pad stays where A was pressed).
local function Writing()
    return J.editing and J.selected ~= nil and Profile() ~= nil
end

local scope = {
    layer = 25,
    parent = "journal",
    host = function() return J.journal end,
    active = function() return ns.UI.JournalShowing("people") and Writing() end,
}

local TABS = { { "tabStory", "story" }, { "tabMap", "map" }, { "tabNote", "note" }, { "tabEdit", "edit" } }

function scope.build(f)
    f:Group("form", { mode = "list", up = "tabs", right = "tabs" })
    f:Group("tabs", { mode = "list", down = "form", left = "form" })
    local p = Profile()
    if not (p and Writing()) then return end
    -- (a form put away forgets where the pad was on it: the next writing
    -- lands on its first control)
    if not scope.hooked then
        scope.hooked = true
        p.form:HookScript("OnHide", function() scope.of = nil end)
    end
    -- (once the form is laid: J.Edit asks before the page is drawn)
    local landing = scope.of ~= J.selected
    if landing then
        f:Remember("form", nil)
        f:Within("form")
    end
    scope.set = Controls.Add(f, "form", Controls.Find(p.form))
    if landing and #scope.set.items > 0 then scope.of = J.selected end
    for _, t in ipairs(TABS) do
        local frame, key = p[t[1]], t[2]
        f:Add("tabs", {
            key = "tab:" .. key, kind = "tab", tab = key, frame = frame,
            available = Writing,
            outline = function()
                local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
                return { anchor = frame, corners = { { 0, 0 }, { w, 0 }, { w, h }, { 0, h } }, level = frame:GetFrameLevel() }
            end,
            enter = function()
                scope.set.LetGo()
                local fn = frame:GetScript("OnEnter")
                if fn then fn(frame, false) end
            end,
            press = function()
                -- (the People page's pad stands on the tab pressed, after)
                local people = Pad.Scope("people")
                if people and people.focus then
                    people.focus:Remember("tabs", "tab:" .. key)
                    people.focus:Within("tabs")
                end
                frame:Click("LeftButton")
            end,
        })
    end
end

-- B: off a line being written on; then out of writing mode.
function scope.back()
    if not Writing() then return false end
    local set = scope.set
    if set and set.Writing() then
        set.LetGo()
        return true
    end
    J.EndEdit()
    return true
end

function scope.legend()
    local at = scope.focus and scope.focus:Current()
    if not at then return {} end
    local out = {}
    if at.kind == "tab" then
        out[1] = PROMPT[at.tab == "map" and "seen" or at.tab]
    else
        out[1] = Controls.Prompt(at)
        if at.group == "form" then out[#out + 1] = PROMPT.tabs end
    end
    out[#out + 1] = (scope.set and scope.set.Writing()) and PROMPT.stop or PROMPT.leave
    return out
end

Pad.RegisterScope("writing", scope)
