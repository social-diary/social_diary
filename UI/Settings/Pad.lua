-- The settings with the pad (.claude/controller-plan.md, step 3).
--
-- Two groups, as the page's two pages: the sections down the left (and
-- "Show the introduction again" at their foot), the open section's settings
-- down the right. Up and down move along a page. The pad landing on a
-- section shows it at once; right or A goes into its settings, left or B
-- comes back to the sections, and B there closes the book (the journal's
-- scope, this one's parent). The shoulders turn the ribbons whatever the
-- page.
--
-- A section's settings are found on its pane, not listed by hand: every
-- switch, number, scale and link built with the kit and the Style widgets,
-- in the order they were made (which is the order they are laid out, top
-- down and left to right). So a new section is controllable with no code
-- here. What each does:
--   a switch (Style.Checkbox)  A ticks or unticks it
--   a scale (the kit's Slider) left and right step it
--   a number (the kit's Number) left and right count it up or down
--   a link (Style.Link)        A follows it
--   a key (UI/Kit/Keys.lua)    A listens; the next key or pad button binds
--                              (the setter takes it itself, the pad aside)
-- Faded settings (DependsOn) and read-only boxes are passed over. So are
-- Feedback's copy fields (copying needs a keyboard) and the books to drag
-- onto an action bar (a drag): neither is a control found here.
--
-- The quiet list (the Toasts section, UI/Settings/Quiet.lua) ends the
-- Toasts settings: its search (A gives the box the keyboard's cursor; A
-- again, B, or the pad moving off takes it back; the list narrows as it is
-- written in), then its rows, a virtual list: down walks them, the list
-- scrolled to the row the pad lands on (List.lua's Reveal / RowOf); A
-- ticks or unticks one, as its click does. Rows are known by who they are,
-- so a search or a tick keeps the pad's place.
--
-- After a ribbon turn the page's title holds the box until the first
-- D-pad press (the journal's HOLD_TITLE), which lands on the sections.

local addonName, ns = ...

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local SettingsUI = ns.UI.Settings

local function Page() return SettingsUI.page end

local function Journal() return Pad.Scope("journal") end

-- What a widget on a pane is, by what it is made of (lowercase fields:
-- the widgets' own, and safe to read on any frame).
local function Kind(w)
    if w.keycap and w.bind and rawget(w, "Listen") then return "setter" end
    if w.slider then return "slider" end
    if w.box and w.label then return "number" end
    if w.tick and w.label then
        if w.readOnly then return "status" end   -- (a status the addon writes: not a switch)
        return "switch"
    end
    if w.line and w.label then return "link" end
end

-- The pane's settings, in the order they were made; a list (the quiet
-- list) is not gone into.
local function Collect(frame, out, skip)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= skip then
            local kind = Kind(child)
            if kind == "status" then
                -- (passed over, and not gone into)
            elseif kind then
                out[#out + 1] = { frame = child, kind = kind }
            else
                Collect(child, out, skip)
            end
        end
    end
    return out
end

local function Shown(frame)
    return frame:IsVisible() and true or false
end

-- copy: the copywriter's pass (.claude/ui-proposal/controller/headings/proposal.md)
local PROMPT = {
    nav = { "PAD1", "Go to the page", main = true },
    intro = { "PAD1", "Choose", main = true },
    link = { "PAD1", "Choose", main = true },
    step = { { "PADDLEFT", "PADDRIGHT" }, "Less · more", main = true },
    back = { "PAD2", "Back to the sections" },
    key = { "PAD1", "Choose a button", main = true },
    write = { "PAD1", "Write", main = true },
    done = { "PAD1", "Done writing", main = true },
    stop = { "PAD2", "Stop writing" },
    title = { { "PADDUP", "PADDDOWN" }, "Go to the sections", main = true },
}

local scope

local function Item(pane, sectionKey, i, found)
    local w, kind = found.frame, found.kind
    local item = { key = sectionKey .. ":" .. i, frame = w, kind = kind }
    item.available = function()
        return pane:IsShown() and Shown(w) and not w.unavailable
    end
    if kind == "slider" then
        item.adjust = { reading = w.slider.reading, nib = w.slider.nib, scale = w.slider }
        item.step = function(dir)
            w.slider:Nudge(dir == "RIGHT" and 1 or -1)
            Pad.Look.Step(J.journal, item, dir)
            return true
        end
        item.press = function() end
    elseif kind == "number" then
        item.step = function(dir)
            w.box:Nudge(dir == "RIGHT" and 1 or -1)
            Pad.Look.Step(J.journal, item, dir)
            return true
        end
        item.press = function() end
    elseif kind == "switch" then
        -- (its tooltip and hover look are the mouse's; A clicks it)
        item.press = function() w:Click("LeftButton") end
    elseif kind == "setter" then
        -- (its link boxed; A listens, and the setter has the pad until a
        -- button, B or Escape)
        item.frame, item.words, item.subhead = w.bind, w.bind.label, w.group
        item.available = function()
            return pane:IsShown() and Shown(w) and not w.listening
        end
        item.press = function() w.bind:Click("LeftButton") end
    end
    return item
end

--------------------------------------------------------------------------
-- The quiet list
--------------------------------------------------------------------------

local function Quiet() local page = Page() return page and page.quiet end

-- The search lets go of the cursor (the pad moved off it, or B).
local function LetGo()
    local page = Page()
    local box = page and page.quietSearch
    if box and box:HasFocus() then box:ClearFocus() end
end

-- Where someone is in the list as it stands, or nil.
local function IndexOf(guid)
    for i, e in ipairs(Quiet().data or {}) do
        if e.guid == guid then return i end
    end
end

-- The pad lands on a row: in view, its name boxed, the heading over it.
local function FindRow(item)
    if not item.guid then return end
    local list = Quiet()
    local index = IndexOf(item.guid)
    if index then list:Reveal(index) end
    local row = index and list:RowOf(index)
    item.frame = row
    item.words = row and row.name or nil
end

local function QuietItems(f, pane)
    local page = Page()
    local box = page.quietSearch
    f:Add("pane", {
        key = "quiet:search", kind = "search", frame = box.holder, subhead = page.quietHeading,
        available = function() return pane:IsShown() and Shown(box) end,
        enter = function() end, leave = function() end,
        press = function()
            if box:HasFocus() then box:ClearFocus() else box:SetFocus() end
        end,
    })
    for _, e in ipairs(Quiet().data or {}) do
        local guid = e.guid
        local item
        item = {
            key = "quiet:" .. tostring(guid), kind = "quiet", guid = guid, subhead = page.quietHeading,
            available = function() return pane:IsShown() and IndexOf(guid) ~= nil end,
            press = function()
                local row = item.frame
                if not (row and row.item and row.item.guid == guid) then return end
                row:Click("LeftButton")
                -- (the row's font changes with its tick: boxed again over it)
                local focus = scope.focus
                if focus and focus:Current() == item then
                    focus:Leave()
                    focus:Enter()
                end
            end,
        }
        f:Add("pane", item)
    end
end
scope = {
    layer = 20,
    parent = "journal",
    host = function() return J.journal end,
    active = function() return ns.UI.JournalShowing("settings") and Page() ~= nil end,
}

function scope.build(f)
    local page = Page()
    f:Group("nav", { mode = "list", right = "pane" })
    -- (the quiet list's rows are found as the pad lands on them)
    f:Group("pane", { mode = "list", left = "nav", reveal = FindRow })
    f:Group("title", { mode = "list" })

    -- (a ribbon just turned: the title alone, until the first D-pad press)
    local journal = Journal()
    if journal and journal.held and journal.held() then
        local spec = J.Page("settings")
        local title = spec and spec.title and spec.title()
        if title then
            f:Add("title", { key = "title", words = title, prompt = PROMPT.title,
                enter = function() end, leave = function() end })
            return
        end
    end

    for _, s in ipairs(SettingsUI.Sections()) do
        local row = page.nav[s.key]
        local key = s.key
        f:Add("nav", {
            key = "nav:" .. key, frame = row, prompt = PROMPT.nav,
            -- (landing on a section shows it, after the row's own hover look)
            enter = function()
                local fn = row:GetScript("OnEnter")
                if fn then fn(row, false) end
                if page:Section() ~= key then page:ShowSection(key) end
            end,
            press = function()
                page:ShowSection(key)
                scope.focus:EnterGroup("pane")
            end,
        })
    end
    if page.intro then
        f:Add("nav", { key = "nav:intro", frame = page.intro, prompt = PROMPT.intro })
    end
    -- (on the sections, the pad stands on the one open: it may have been
    -- opened otherwise meanwhile, by a link or /sd settings)
    if f.group ~= "pane" and f.remembered.nav ~= "nav:intro" then f:Remember("nav", "nav:" .. page:Section()) end

    for _, s in ipairs(SettingsUI.Sections()) do
        local pane = page.panes[s.key]
        for i, found in ipairs(Collect(pane, {}, page.quiet)) do
            f:Add("pane", Item(pane, s.key, i, found))
        end
        if page.quiet and page.quiet:GetParent() == pane then QuietItems(f, pane) end
    end

    -- (the quiet list's search lets go as the pad stands anywhere else)
    for _, name in ipairs(f.order) do
        for _, it in ipairs(f.groups[name].items) do
            if it.kind ~= "search" then
                local own = it.enter
                it.enter = function()
                    LetGo()
                    if own then own() else
                        local fn = it.frame and it.frame:GetScript("OnEnter")
                        if fn then fn(it.frame, false) end
                    end
                end
            end
        end
    end
end

-- B on the settings comes back to the sections; on the sections it is the
-- book's (closing it).
function scope.back()
    local box = Page() and Page().quietSearch
    if box and box:HasFocus() then
        box:ClearFocus()
        return true
    end
    local focus = scope.focus
    local at = focus and focus:Current()
    if at and at.group == "pane" then
        focus:EnterGroup("nav")
        return true
    end
    return false
end

-- The first D-pad press after a ribbon turn is the journal's: it lets the
-- title go (and the page is built again, on the sections). Any other time
-- it is this page's focus.
local function Direction(key)
    return function()
        local journal = Journal()
        local fn = journal and journal.keys and journal.keys[key]
        if journal and journal.held and journal.held() and fn then
            fn(journal)
            return true
        end
        return false
    end
end
scope.keys = {
    PADDUP = Direction("PADDUP"), PADDDOWN = Direction("PADDDOWN"),
    PADDLEFT = Direction("PADDLEFT"), PADDRIGHT = Direction("PADDRIGHT"),
}

function scope.legend()
    local at = scope.focus and scope.focus:Current()
    if not at then return {} end
    if at.prompt then return { at.prompt } end
    local out = {}
    if at.kind == "switch" then
        out[1] = { "PAD1", at.frame:GetChecked() and "Untick" or "Tick", main = true }
    elseif at.kind == "quiet" then
        out[1] = { "PAD1", ns.Diary.IsQuietNearby(at.guid) and "Untick" or "Tick", main = true }
    elseif at.kind == "search" then
        local box = Page().quietSearch
        if box:HasFocus() then
            out[1], out[2] = PROMPT.done, PROMPT.stop
            return out
        end
        out[1] = PROMPT.write
    elseif at.kind == "setter" then
        out[1] = PROMPT.key
    elseif at.kind == "slider" or at.kind == "number" then
        out[1] = PROMPT.step
    elseif at.kind == "link" then
        out[1] = PROMPT.link
    end
    out[#out + 1] = PROMPT.back
    return out
end

Pad.RegisterScope("settings", scope)
