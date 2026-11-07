-- The windows that open outside the book with the pad (.claude/controller-plan.md,
-- step 7a): the loose entry sheet (UI/Windows/Entry.lua) and the Remember
-- this picker (UI/Windows/Picker.lua). The Remember key's note, the third
-- such window, is UI/Journal/NotePad.lua's (`quicknote`), as the book's
-- note sheet is.
--
-- The rule: a window the player opened (or that opened from their action:
-- the Remember key, a menu's line, /sd, a pick in the picker) takes the pad
-- while it is shown and the pad is in hand, and gives it back the moment it
-- hides. A window shown any other way never takes it (Pad.Owns: each opening
-- path says Pad.Opened). Each is a scope of its own on its own window, at
-- layer 50, over every scope of the book: open over the book, it has the
-- pad, and the book's catcher is off (only the top scope's window catches);
-- put away, the book's scope has it again where it was. **No parent**: the
-- book under it is another window, so the shoulders turn no ribbon from it
-- and its prompts are its own. Of two such windows shown, the one opened
-- last has the pad.
--
-- The entry sheet (`entry`): the form's controls found as they are laid
-- (Pad.Controls, as writing mode on the book): the tags (A puts one on or
-- takes it off), the line to add a tag, the relationship, the note, then
-- "Remove from the diary" (on a draft "Cancel") and Done, each under its
-- label in red. Opened for the note (the Remember key, a quick add), the pad
-- lands on the note, which waits for A before it takes the keyboard's
-- cursor; opened otherwise, on the first tag. Remove asks in Blizzard's
-- popup, and the pad steps aside while it is up (Pad.Aside). B: off a line
-- being written on; then the sheet put away as its close does (a draft adds
-- nobody), the Escape stand-in doing the same through UISpecialFrames.
--
-- The picker (`picker`): its people, top down; A is the row's click (their
-- page, or the page to remember them on, which then has the pad). B puts it
-- away. Nobody to remember: nothing walked, B puts it away.

local addonName, ns = ...

local Pad = ns.UI.Pad
local Controls = Pad.Controls

local LAYER = 50
-- How far over the window the box is drawn (over its controls).
local OVER = 30

local PROMPT = {
    away = { "PAD2", "Put the page away" },
    stop = { "PAD2", "Stop writing" },
    open = { "PAD1", "Open their page", main = true },
    remember = { "PAD1", "Remember them", main = true },
    list = { "PAD2", "Put the list away" },
}

--------------------------------------------------------------------------
-- The entry sheet
--------------------------------------------------------------------------

local function Sheet()
    local sheet = ns.UI.Entry.Sheet()
    return sheet and Pad.Owns(sheet) and sheet or nil
end

local entry = {
    layer = LAYER,
    host = function() return ns.UI.Entry.Sheet() end,
    active = function() return Sheet() ~= nil end,
}

function entry.build(f)
    f:Group("form", { mode = "list" })
    local sheet = Sheet()
    if not sheet then return end
    local form = sheet.form
    local set = Controls.Add(f, "form", Controls.Find(form), { level = sheet:GetFrameLevel() + OVER })
    entry.set = set
    -- (each opening lands afresh: on the note if that is what it was
    -- opened for, else the first control)
    local opening = Pad.Opening(sheet)
    if opening ~= entry.opening and #set.items > 0 then
        entry.opening = opening
        f:Within("form")
        local land = set.items[1].key
        if sheet.padNote then
            for _, it in ipairs(set.items) do
                if it.control == form.note then land = it.key end
            end
        end
        f:Remember("form", land)
    end
end

-- B: off a line being written on; then the sheet put away, as its close.
function entry.back()
    local sheet = Sheet()
    if not sheet then return false end
    if entry.set and entry.set.Writing() then
        entry.set.LetGo()
        return true
    end
    sheet:Hide()
    return true
end

function entry.legend()
    local at = entry.focus and entry.focus:Current()
    if not at then return { PROMPT.away } end
    local out = { Controls.Prompt(at) }
    out[#out + 1] = (entry.set and entry.set.Writing()) and PROMPT.stop or PROMPT.away
    return out
end

Pad.RegisterScope("entry", entry)

--------------------------------------------------------------------------
-- The picker
--------------------------------------------------------------------------

local function Picker()
    local picker = _G.SocialDiaryPickerFrame
    return picker and Pad.Owns(picker) and picker or nil
end

-- What the pen boxes on a row: its name alone (a frame of ours the size of
-- the name's ink, made the first time the pad stands there). The name is
-- inked in its class colour, which red would not replace, so it is boxed
-- and left in its colours, as a tag is.
local function NameBox(row)
    local box = row.padName
    if not box then
        box = CreateFrame("Frame", nil, row)
        row.padName = box
    end
    local fs = row.name
    box:ClearAllPoints()
    box:SetPoint("LEFT", fs, "LEFT", 0, 0)
    box:SetSize(math.max(1, fs:GetStringWidth() or 0), math.max(1, fs:GetStringHeight() or 0))
    return box
end

local picker = {
    layer = LAYER,
    host = function() return _G.SocialDiaryPickerFrame end,
    active = function() return Picker() ~= nil end,
}

function picker.build(f)
    f:Group("rows", { mode = "list" })
    local panel = Picker()
    if not panel then return end
    local first
    for _, row in ipairs(panel.rows or {}) do
        if row.guid and row:IsShown() then
            local item
            item = {
                key = "row:" .. row.guid, kind = "row", guid = row.guid, row = row,
                frame = NameBox(row), plain = true, level = panel:GetFrameLevel() + OVER,
                available = function() return row:IsVisible() and row.guid ~= nil end,
                enter = function()
                    local fn = row:GetScript("OnEnter")
                    if fn then fn(row, false) end
                end,
                leave = function()
                    local fn = row:GetScript("OnLeave")
                    if fn then fn(row, false) end
                end,
                press = function() row:Click("LeftButton") end,
            }
            f:Add("rows", item)
            first = first or item.key
        end
    end
    local opening = Pad.Opening(panel)
    if opening ~= picker.opening then
        picker.opening = opening
        f:Within("rows")
        f:Remember("rows", first)
    end
end

function picker.back()
    if not Picker() then return false end
    ns.UI.ClosePicker()
    return true
end

function picker.legend()
    local at = picker.focus and picker.focus:Current()
    local out = {}
    if at then out[1] = ns.Diary.IsDiary(at.guid) and PROMPT.open or PROMPT.remember end
    out[#out + 1] = PROMPT.list
    return out
end

Pad.RegisterScope("picker", picker)
