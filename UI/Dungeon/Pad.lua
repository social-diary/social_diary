-- The Dungeon View with the pad (.claude/controller-plan.md, step 4f; the
-- scheme in .claude/ui-proposal/controller/your-diary.md §2e).
--
-- The run laid out on the table (UI/Dungeon/Spread.lua) is a frame of its
-- own on the screen, and the book under it stays shown, only see-through
-- and deaf. So while the spread is out this scope has the pad, over every
-- scope of the book, and has no parent: the book's ribbons and its "close"
-- are not the table's. The book's catcher is off while this one is on (one
-- catcher has the pad: the top scope's host's), so a shoulder never turns
-- a ribbon nobody can see.
--
-- Everything on the table the mouse can hover or click is stood on, by
-- where it lies (group `sheet`, spatial; centres measured on the screen
-- from the sheet's middle, y up, so up is up on the turned sheet too):
--   the marks on the map (the sheet's hover squares, UI/Dungeon/Sheet.lua's
--     P.Hit: bosses, deaths, level-ups, firsts found, the way in), each
--     ringed by the pen with its own tooltip. A does nothing: they have no
--     click.
--   the notes beside them (UI/Dungeon/Notes.lua's strips, a pair's two each
--     on its own), outlined as a margin card is (the user's decision 5), the
--     heading red. A is the strip's click: a person's page where it names
--     someone in the diary, nothing otherwise.
--   the items named on a loot strip, each its own: the item's own tooltip
--     and the pen's box round it. **A does nothing**, and no click is made
--     at all: no item to chat and no try-on (the user, 7 Nov 2026), and a
--     held Shift or Ctrl stand-in (LB is Forever's Ctrl) would otherwise
--     reach Style.ItemClick, as on 4e's keepsakes.
--   the floors' links on the label, boxed with their line red as a link
--     is; A shows that floor, as the click does (the one shown is plain
--     text, and A on it does nothing, as the click).
--   the bookmark (the way back), outlined as the slip of paper it is, its
--     words red; A puts the run away, as the click does.
-- The pencil's "Adjust Path" slip is never stood on and never named
-- (the route editor stays the mouse's): taken up with the mouse, the pad
-- steps aside (Pad.Aside "way", UI/Dungeon/Way.lua's Start and Lower) until
-- it is put down. Nothing on the table has a right click but the pencil's,
-- so there is no Y here: it goes on to the game, as X does.
--
-- LB / RB turn to the floor before or after (round the ends, as the book's
-- ribbons go round), as a click on its link does; with one floor they go on
-- to the game. On a floor turned to, the pad lands on the way in, else the
-- first boss. There is no zoom or pan on the sheet (the wheel stops at the
-- table), so the sticks go on to the game too.
--
-- The note on the first run ever (UI/Dungeon/Tutorial.lua) covers the
-- screen and takes every click while it is up: the pad stands only on its
-- link (group `note`), and A or B puts it away as the link does; the map
-- under it has the pad after.
--
-- B puts the run away (DungeonPage.Close, as the bookmark and Escape do),
-- and the page it was laid out from has the pad again where A was pressed
-- (Your Diary's run page: its title or the scrap). A person's page opened
-- from a note puts the run away too (the book turned): the book's scope has
-- the pad there.
--
-- The prompts lie on the same slip as in the book, on the table under the
-- sheet's foot near its right corner (the scope's `slip`, Pad.Look's
-- Legend `under`): the host is the whole screen, and its foot is off it.

local addonName, ns = ...

local L = ns.L

local Pad = ns.UI.Pad
local J = ns.UI.Journal
local DungeonPage = ns.UI.DungeonPage

local PROMPT = {
    person = { "PAD1", L["Go to their page"], main = true },
    floor = { "PAD1", L["See this floor"], main = true },
    away = { "PAD1", L["Put the map away"], main = true },
    floors = { { "PADLSHOULDER", "PADRSHOULDER" }, L["See another floor"], main = false },
    back = { "PAD2", L["Put the map away"] },
    note = { "PAD1", L["Put the note away"], main = true },
}

-- The slip of prompts on the table: its right end `right` px in from the
-- sheet's bottom-right corner, along its foot. The sheet lies turned a few
-- degrees against the clock, so its foot rises to the right: the slip is
-- hung by its left end, tucked under there, and lies a hair clear of the
-- paper toward its right end, as a slip put down beside a sheet would.
local SLIP = { right = 70 }

local function Map()
    local spread = DungeonPage.Spread()
    return spread and spread.map
end

local function Note()
    local note = DungeonPage.TutorialNote()
    return note and note:IsShown() and note or nil
end

local function Run(frame, script)
    local fn = frame and frame:GetScript(script)
    if fn then fn(frame, false) end
end

local scope = {
    layer = 40,
    -- (made with the first run laid out)
    host = function() return DungeonPage.Spread() end,
    active = function() return J.visit ~= nil end,
}

-- A point of the sheet (x right, y down from its top left) on the screen
-- from its middle, y up: where Focus measures.
local function OnScreen(view, x, y)
    return view.K.Screen(x, y)
end

-- The bookmark's slip, its four corners on its button from the top left, y
-- down, as it lies turned (its plane: UI/Dungeon/Spread.lua's Bookmark).
local function BookmarkCorners(mark)
    local W, H = mark.w or 0, DungeonPage.BOOKMARK.h
    local fw, fh = mark:GetWidth() or 0, mark:GetHeight() or 0
    local out = {}
    for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local X, Y = mark.plane.Screen(c[1] * W / 2, c[2] * H / 2)
        out[i] = { fw / 2 + X, fh / 2 - Y }
    end
    return out
end

-- Which laying out the pad stands on: this time out (J.visit, made anew
-- on each opening) and the floor shown (or `index`).
local function Laid(view, index)
    return tostring(J.visit) .. ":" .. tostring(index or view.floorIndex)
end

-- The marks on the map: every hover square shown with a tooltip.
local function AddMarks(f, view)
    local pool = view.pools and view.pools.hit
    local doors, first = nil, nil
    for i = 1, pool and pool.used or 0 do
        local hit = pool[i]
        local at = hit.padAt
        if at and hit.tip then
            local what = hit.what or "mark"
            local x, y = OnScreen(view, at[1], at[2])
            local item = f:Add("sheet", {
                key = string.format("%s:%d:%d", what, math.floor(at[1] + 0.5), math.floor(at[2] + 0.5)),
                frame = hit, ring = true, what = what,
                available = function() return hit:IsVisible() end,
                center = function() return x, y end,
                -- (no click: the tooltip is all a mark has)
                press = function() end,
            })
            if what == "door" then doors = doors or item end
            if what == "boss" then first = first or item end
        end
    end
    return doors or first
end

-- The notes beside them, and the items named on a loot strip.
local function AddNotes(f, view)
    for k, entry in ipairs(view.noteStrips or {}) do
        local slots = { { entry.slot, "" } }
        if entry.topSlot then slots[2] = { entry.topSlot, ":top" } end
        for _, s in ipairs(slots) do
            local slot, part = s[1], s[2]
            local strip = slot and slot.strip
            if strip and strip.Focus and strip:IsShown() then
                local at = strip:Focus()
                local key = "note:" .. tostring(entry.note.seed or k) .. part
                f:Add("sheet", {
                    key = key, frame = at.frame, heading = at.words,
                    person = strip.guid ~= nil and strip.onClick ~= nil,
                    available = function() return strip:IsVisible() end,
                    center = function() return at.x, -at.y end,
                    outline = function()
                        local now = strip:Focus()
                        return { anchor = strip:GetParent(), corners = now.corners, level = strip:GetFrameLevel() }
                    end,
                    -- (the strip's own click: a person's page, or nothing)
                    press = function()
                        if strip.guid and strip.onClick then strip.onClick(strip.guid) end
                    end,
                })
                -- Its items, each where it is written in the heading.
                for n = 1, slot.links and slot.links.used or 0 do
                    local hover = slot.links[n]
                    local p = hover.padAt
                    if p then
                        f:Add("sheet", {
                            key = key .. ":item:" .. n, frame = hover, item = true,
                            available = function() return hover:IsVisible() end,
                            center = function() return p[1], -p[2] end,
                            -- (never a click: no item to chat, no try-on)
                            press = function() end,
                        })
                    end
                end
            end
        end
    end
end

-- The floors' links on the label.
local function AddFloors(f, view)
    for i = 1, view.links and view.links.used or 0 do
        local link = view.links[i]
        local at = link.padAt
        if at then
            local x, y = OnScreen(view, at[1], at[2])
            local index = link.index
            f:Add("sheet", {
                key = "floor:" .. tostring(index), frame = link, floor = index,
                available = function() return link:IsVisible() end,
                center = function() return x, y end,
                press = function()
                    if link.current then return end
                    -- (laid again on that floor: the pad stays on this link,
                    -- not landing afresh on its way in)
                    scope.laidFor = Laid(view, index)
                    f:Remember("sheet", "floor:" .. tostring(index))
                    link:Click("LeftButton")
                end,
            })
        end
    end
end

local function AddBookmark(f, view)
    local spread = DungeonPage.Spread()
    local mark = spread and spread.back
    if not (mark and mark.plane and mark:IsShown()) then return end
    local x, y = (mark.x or 0) - (view.dx or 0), (mark.y or 0) - (view.dy or 0)
    f:Add("sheet", {
        key = "bookmark", frame = mark, heading = mark.words, bookmark = true,
        available = function() return mark:IsVisible() end,
        center = function() return x, y end,
        outline = function()
            return { anchor = mark, corners = BookmarkCorners(mark), level = mark:GetFrameLevel() }
        end,
        press = function() DungeonPage.Close() end,
    })
end

function scope.build(f)
    f:Group("sheet", { mode = "spatial" })
    f:Group("note", { mode = "list" })

    -- The first run's note over everything: its link alone.
    local note = Note()
    if note then
        local ok = note.ok
        f:Add("note", {
            key = "ok", frame = ok, note = true,
            -- (the box over the note, which lies far over the spread)
            level = ok:GetFrameLevel() + 5,
            -- (the note's own: its sheet and link are shown with it)
            available = function() return note:IsShown() end,
        })
        f:Within("note")
        return
    end
    if f.group == "note" then f:Within("sheet") end

    local view = Map()
    if not (view and view:IsShown()) then return end
    local land = AddMarks(f, view)
    AddNotes(f, view)
    AddFloors(f, view)
    AddBookmark(f, view)
    -- Laid out afresh (each time it comes out: J.visit is new each time)
    -- or another floor: the pad lands on the way in, else the first boss,
    -- else the first thing there.
    local laid = Laid(view)
    if scope.laidFor ~= laid then
        scope.laidFor = laid
        f:Remember("sheet", land and land.key or nil)
    end
end

-- The floor before or after (delta -1 / 1), round the ends, as its link's
-- click shows it; with one floor (or none) the press goes on to the game.
local function Floor(delta)
    return function()
        if Note() then return false end
        local view = Map()
        local n = view and view.floors and #view.floors or 0
        if not (view and view.visit and n > 1 and view.floorIndex) then return false end
        local to = (view.floorIndex - 1 + delta) % n + 1
        view.chosen[view.visit.id] = to
        view:Open(view.visit, view.guid)
        return true
    end
end

scope.keys = { PADLSHOULDER = Floor(-1), PADRSHOULDER = Floor(1) }

-- B: the note put away, as its link does; else the run (the bookmark's).
function scope.back()
    local note = Note()
    if note then
        note:Hide()
        return true
    end
    DungeonPage.Close()
    return true
end

function scope.legend()
    local f = scope.focus
    local at = f and f:Current()
    if at and at.note then return { PROMPT.note } end
    local out = {}
    if at then
        if at.person then
            out[#out + 1] = PROMPT.person
        elseif at.floor and not (at.frame and at.frame.current) then
            out[#out + 1] = PROMPT.floor
        elseif at.bookmark then
            out[#out + 1] = PROMPT.away
        end
    end
    local view = Map()
    if view and view.floors and #view.floors > 1 then out[#out + 1] = PROMPT.floors end
    out[#out + 1] = PROMPT.back
    return out
end

-- The prompts' slip on the table, hung under the sheet's foot (SLIP).
function scope.slip(_, w)
    local view = Map()
    if not (view and view:IsShown() and view.K) then return nil end
    local W, H = view.w or DungeonPage.SHEET.w, view.h or DungeonPage.SHEET.h
    local x, y = view.K.Screen(math.max(0, W - SLIP.right - w), H)
    return { frame = view.sheet, x = x, y = y, level = view.sheet:GetFrameLevel() - 1 }
end

Pad.RegisterScope("spread", scope)
