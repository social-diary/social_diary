-- A note's sheet and its link card with the pad (.claude/controller-plan.md,
-- step 5b; the sheet is UI/Paper/NoteSheet.lua, the card UI/Paper/LinkSheet.lua,
-- both laid on the book from a person's page: the note tab, a note on the
-- timeline).
--
-- Each is a scope of its own, over the People page's and writing's, with no
-- parent: the book under a sheet takes no clicks while it is up, so the pad
-- turns no ribbon either (as the custom card's slip, UI/Journey/CardPad.lua).
--
-- The note's sheet (`note`): its controls found as they lie (Pad.Controls):
-- whom it is about (their faces, ringed with their tooltips; A on one with a
-- cross unlinks them), "Link others…", the ruled box, "Delete this note",
-- Cancel and Save. Opened, the pad is on the box, which waits for A before it
-- takes the keyboard's cursor (there is no on-screen keyboard to rely on); A
-- again, B, or moving off takes it back. Deleting a note is at once, as
-- under the mouse. B puts the sheet away as turning to another tab does: a
-- new note's draft is kept for the next time it opens on them. The pad is
-- back on the People page where A was pressed (the note tab, the note's line).
--
-- The link card (`links`, over the sheet): its search, then the people it
-- lists (the list is virtual: a row is found as the pad lands on it,
-- scrolled into view, its section the subheading over it), then Done.
-- Opened, the pad is on the first person: the likely ones come first, as the
-- card means them to be seen. A on someone links or unlinks them at once (the
-- row's click); the search narrows the rows as it is written in. B: off the
-- search being written in; then the card put away (Done), the pad back on
-- "Link others…".

-- The same two scopes lie over the game for the Remember key's note
-- (`quicknote`, `quicklinks`, step 7a): see the foot of this file.

local addonName, ns = ...

local L = ns.L

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local Controls = Pad.Controls

-- How far over a sheet the box is drawn (over its controls, as CardPad's).
local OVER = 30

local PROMPT = {
    away = { "PAD2", L["Put the note away"] },
    stop = { "PAD2", L["Stop writing"] },
    card = { "PAD2", L["Back to the note"] },
    link = { "PAD1", L["Link them"], main = true },
    unlink = { "PAD1", L["Unlink them"], main = true },
}

local hooked = setmetatable({}, { __mode = "k" })
-- A sheet put away: the pad's scopes follow, and the next opening lands
-- afresh (`forget`).
local function Watch(frame, forget)
    if hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnHide", function()
        forget()
        Pad.Refresh()
    end)
end

-- The heading a row falls under: its index, or nil.
local function HeadingOf(data, index)
    for i = index - 1, 1, -1 do
        if data[i].heading then return i end
    end
end

--------------------------------------------------------------------------
-- The two scopes, for a sheet wherever it lies
--------------------------------------------------------------------------

-- `names` = { note, links }; spec: `layer` (the note's; the card's 5 over),
-- `host()`, `view()` (the sheet, shown, when this scope may have it, else
-- nil), `away(view)` (B: put it away, its draft kept), optional `opening()`
-- (a window's Pad.Opening: a new one lands on the box again).
local function Register(names, spec)
    local function Sheet() return spec.view() end
    local function Card()
        local view = Sheet()
        return view and view.picker:IsShown() and view.picker or nil
    end

    local note = {
        layer = spec.layer,
        host = spec.host,
        active = function() return Sheet() ~= nil end,
    }

    function note.build(f)
        f:Group("sheet", { mode = "list" })
        local view = Sheet()
        if not view then return end
        Watch(view, function() note.opened = nil end)
        -- (a window opened again lands afresh, though its sheet never hid)
        local opening = spec.opening and spec.opening()
        if opening ~= note.opening then note.opened, note.opening = nil, opening end
        local set = Controls.Add(f, "sheet", Controls.Find(view.sheet),
            { level = view.sheet:GetFrameLevel() + OVER, clip = view.sheet })
        note.set = set
        -- (opened: on the box)
        if not note.opened then
            f:Within("sheet")
            f:Remember("sheet", nil)
            for _, it in ipairs(set.items) do
                if it.kind == "field" then
                    f:Remember("sheet", it.key)
                    note.opened = true
                    break
                end
            end
        end
    end

    -- B: off the box being written in; then the sheet put away, its draft kept.
    function note.back()
        local view = Sheet()
        if not view then return false end
        if note.set and note.set.Writing() then
            note.set.LetGo()
            return true
        end
        view.box:ClearFocus()
        spec.away(view)
        return true
    end

    function note.legend()
        local at = note.focus and note.focus:Current()
        if not at then return {} end
        local out = { Controls.Prompt(at) }
        out[#out + 1] = (note.set and note.set.Writing()) and PROMPT.stop or PROMPT.away
        return out
    end

    Pad.RegisterScope(names[1], note)

    local links = {
        layer = spec.layer + 5,
        host = spec.host,
        active = function() return Card() ~= nil end,
    }

    -- The pad lands on someone: their row scrolled into view, their name and
    -- their section's heading over it.
    local function FindRow(item)
        local card = Card()
        if not (card and item.index) then return end
        card.list:Reveal(item.index)
        local row = card.list:RowOf(item.index)
        item.frame = row
        item.words = row and row.name or nil
        local head = item.heading and card.list:RowOf(item.heading)
        item.subhead = head and head.heading or nil
    end

    function links.build(f)
        f:Group("card", { mode = "list", reveal = FindRow })
        local card = Card()
        if not card then return end
        Watch(card, function() links.ctx = nil end)
        local level = card.sheet:GetFrameLevel() + OVER
        local found = Controls.Find(card.sheet, { [card.list] = true })
        -- (the search first, then the people, then the rest: Done)
        local fields, rest = {}, {}
        for _, c in ipairs(found) do
            if c.kind == "field" then fields[#fields + 1] = c else rest[#rest + 1] = c end
        end
        local set = Controls.Add(f, "card", fields, { level = level, clip = card.sheet, refresh = false })
        links.set = set
        local first
        local data = card.list.data or {}
        for index, d in ipairs(data) do
            if d.guid then
                local guid = d.guid
                local item
                item = {
                    key = "row:" .. guid, kind = "row", guid = guid, index = index, heading = HeadingOf(data, index),
                    level = level, clip = card.sheet,
                    available = function() return true end,
                    enter = function()
                        set.LetGo()
                        local fn = item.frame and item.frame:GetScript("OnEnter")
                        if fn then fn(item.frame, false) end
                    end,
                    leave = function()
                        local fn = item.frame and item.frame:GetScript("OnLeave")
                        if fn then fn(item.frame, false) end
                    end,
                    press = function()
                        if item.frame then item.frame:Click("LeftButton") end
                    end,
                }
                f:Add("card", item)
                first = first or item.key
            end
        end
        Controls.Add(f, "card", rest, { level = level, clip = card.sheet })
        -- (opened: on the first person, the likeliest)
        if links.ctx ~= card.ctx then
            links.ctx = card.ctx
            f:Within("card")
            f:Remember("card", first)
        end
    end

    -- B: off the search being written in; then the card put away.
    function links.back()
        local card = Card()
        if not card then return false end
        if links.set and links.set.Writing() then
            links.set.LetGo()
            return true
        end
        card:Close()
        return true
    end

    function links.legend()
        local card = Card()
        local at = links.focus and links.focus:Current()
        if not (card and at) then return {} end
        local out = {}
        if at.kind == "row" then
            out[1] = card.ctx.linked(at.guid) and PROMPT.unlink or PROMPT.link
        else
            out[1] = Controls.Prompt(at)
        end
        out[#out + 1] = (links.set and links.set.Writing()) and PROMPT.stop or PROMPT.card
        return out
    end

    Pad.RegisterScope(names[2], links)
end

--------------------------------------------------------------------------
-- On the book (a person's page) and over the game (the Remember key's)
--------------------------------------------------------------------------

Register({ "note", "links" }, {
    layer = 30,
    host = function() return J.journal end,
    view = function()
        if not ns.UI.JournalShowing("people") then return nil end
        local p = J.journal and J.journal.profile
        local view = p and p.noteSheet
        return view and view:IsShown() and view or nil
    end,
    away = function()
        J.tab = "timeline"
        J.RefreshProfile()
    end,
})

-- The keybind's note (UI/Paper/NoteSheet.lua's QuickNote), a window of its
-- own over the game (step 7a, UI/Windows/Pad.lua's rule): only while the
-- player opened it (Pad.Owns), over the book's scopes when both are shown;
-- no parent, as the book's sheet has none. B puts it away as Escape does,
-- the draft kept; Cancel still throws it away.
local function Quick() return _G.SocialDiaryNoteFrame end
Register({ "quicknote", "quicklinks" }, {
    layer = 50,
    host = Quick,
    view = function()
        local host = Quick()
        if not (host and Pad.Owns(host)) then return nil end
        return host.note:IsShown() and host.note or nil
    end,
    away = function() Quick():Hide() end,
    opening = function() return Pad.Opening(Quick()) end,
})
