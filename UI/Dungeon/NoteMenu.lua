-- The player's own notes on a run's map: the ways in (.claude/features/
-- dungeon-notes.md, decision 6; the approved UI proposal .claude/ui-proposal/
-- dungeon-notes.md §3–§5, whose closing "user's answers" overrule it).
--
-- With the mouse, a right press on the printed floor, on a boss's face (or
-- within SNAP.reach of it: the note is pinned to the boss), on the way in, a
-- death's cross, a level-up or a find offers "Add a note here", and the free
-- card's form opens at once (no picker: one kind), laid on the table on the
-- far side from the spot (UI/Journey/CardSheet.lua's OpenRun), a ring in
-- chalk at the spot until it is put away. A detected strip offers nothing
-- (the user, 28 Nov). A right press on the player's own note (its strip, or
-- its mark: "Which one?" first where a mark holds several) offers Edit, Move
-- and Remove. Move picks it up: its strip and leader fade, a chalk ring
-- follows the cursor (round a face it comes near), and a click puts it down
-- where it goes (another floor first, by its link, if wanted); a right
-- click or Escape leaves it where it was. Remove asks first.
--
-- There is no menu on another character's run (their notes show, read
-- only), while the pencil is out, while the sheet is being laid or the first
-- run's note is up, on a bare sheet (no map), or off the printed floor.
--
-- With the pad (UI/Dungeon/Pad.lua's Y, DungeonPage.NotePad): on a boss the
-- form opens pinned to it, on the door or a mark at its spot, on the
-- player's own note its menu on the pad's slip (Pad.Menu, the same
-- generator as the mouse's: never MenuUtil with the pad). Its Move steps the
-- note between the marks (A puts it there, B leaves it, LB / RB carry it to
-- another floor).
--
-- Nothing here is protected; combat only ends a move cleanly.

local addonName, ns = ...

local L = ns.L
local Style = ns.Style
local DungeonPage = ns.UI.DungeonPage

-- The words, all furniture (the copywriter's §1); the menu's as the
-- plates' own card's ("Delete this card", UI/Journey/CardSheet.lua).
local WORDS = {
    add = L["Add a note here"],
    edit = L["Change this note"],
    move = L["Move this note"],
    remove = L["Delete this note"],
    which = L["Which one?"],
    menu = L["Open the menu"],
    confirm = L["Delete this note you wrote?\n\nIt comes off the map. This cannot be undone."],
    drop = L["Click to put it here"],
    pin = L["Click to pin it to %s"],
    cancel = L["Right-click or Escape to leave it where it was"],
    change = L["Right-click to change it"],
    put = L["Put it here"],
    leave = L["Leave it where it was"],
}
DungeonPage.NOTE_WORDS = WORDS

-- A press within `reach` px past a face's own edge pins the note to it.
local SNAP = { reach = 8 }
-- The chalk ring (CardSheet's RING look, in the leaders' chalk over its
-- faint dark stroke: graphite was lost on dark art, 16 Oct): `r` px at a
-- spot, `face` px past a pinned face's edge.
local RING = { r = 10, face = 5 }
-- Moving with the mouse: the note's strip and leader at `alpha`, a catcher
-- named `name` (Escape's place while it is up) over the sheet `level` levels,
-- the cursor `cursor` over the paper (to check in the client: dropped where
-- the token is refused), the ring drawn again once the cursor has moved
-- `step` px.
local MOVE = { alpha = 0.45, cursor = "CAST_CURSOR", name = "SocialDiaryNoteMove", level = 40, step = 1 }
DungeonPage.NOTE_SNAP, DungeonPage.NOTE_RING, DungeonPage.NOTE_MOVE = SNAP, RING, MOVE

DungeonPage.STAND_INS[MOVE.name] = true
DungeonPage.STAND_INS[ns.UI.YourDiary.CardSheet.TABLE.name] = true

local function CardSheet() return ns.UI.YourDiary.CardSheet end

-- The kind a new note is (one today, the free card: RunNotes.KINDS), the
-- first offered by name, so nothing here names a feature.
local function Kind()
    local keys = {}
    for kind in pairs(ns.RunNotes.KINDS) do
        if ns.RunNotes.Offered(kind) and DungeonPage.NoteFace(kind) then keys[#keys + 1] = kind end
    end
    table.sort(keys)
    return keys[1]
end
local function Saved(rec) return rec and (rec.customOf or rec) end

--------------------------------------------------------------------------
-- When and where
--------------------------------------------------------------------------

local function Writing()
    local run = CardSheet().Run()
    return run ~= nil
end

-- Whether a note may be added or changed on `view` now.
local function Allowed(view)
    if not (view and view.visit and view.box and view.plan and view:IsShown()) then return false end
    if not ns.RunNotes.Writable(view.visit) then return false end
    if view.Laying and view:Laying() then return false end
    if view.way and view.way.drawing then return false end
    local note = DungeonPage.TutorialNote()
    if note and note:IsShown() then return false end
    if view.moving or Writing() then return false end
    return Kind() ~= nil
end
DungeonPage.NoteAllowed = Allowed

-- The boss whose face is within SNAP.reach of sheet point x, y: its mark.
local function Snap(view, x, y)
    local plan, best, near = view.plan, nil, nil
    for _, mark in ipairs(plan and plan.marks or {}) do
        local t = plan.targets[mark.name]
        if t then
            local d = math.sqrt((t.x - x) ^ 2 + (t.y - y) ^ 2)
            if d <= t.r + SNAP.reach and (not near or d < near) then best, near = mark, d end
        end
    end
    return best
end
DungeonPage.NoteSnap = Snap

-- A note pinned to boss mark `mark`: at the boss's own spot.
local function Pinned(mark)
    local b = mark.boss
    return { f = tonumber(b.floor), x = b.x, y = b.y, boss = mark.name }
end

-- The spot for a note at sheet point x, y: pinned where a face is that near,
-- else the floor's point there; nil off the printed floor.
local function WhereAt(view, x, y)
    local mark = Snap(view, x, y)
    if mark then return Pinned(mark) end
    if not view.From then return nil end
    local f, fx, fy = view.From(x, y)
    if not (f and fx and fy) then return nil end
    return { f = tonumber(f), x = fx, y = fy }
end
DungeonPage.NoteWhereAt = WhereAt

-- The spot for a note added on a mark's square (`hit`, P.Hit's): a boss's
-- pins it; the way in, a cross, a level-up or a find gives its spot. Nil for
-- anything else.
local function WhereOfHit(view, hit)
    local at = hit and hit.padAt
    if not at then return nil end
    if hit.what == "boss" then
        for _, mark in ipairs(view.plan and view.plan.marks or {}) do
            if math.abs(mark.x - at[1]) < 0.5 and math.abs(mark.y - at[2]) < 0.5 then return Pinned(mark) end
        end
        return nil
    end
    if hit.what == "door" or hit.what == "cross" or hit.what == "level" or hit.what == "find" or hit.what == "note" then
        if not view.From then return nil end
        local f, fx, fy = view.From(at[1], at[2])
        if f and fx then return { f = tonumber(f), x = fx, y = fy } end
    end
    return nil
end
DungeonPage.NoteWhereOfHit = WhereOfHit

-- A point of the sheet on the spread (its middle, y up, the spread's units).
local function OnSpread(view, x, y)
    local X, Y = view.K.Screen(x, y)
    local lie = view.lie or { 0, 0 }
    return lie[1] + X, lie[2] + Y
end

--------------------------------------------------------------------------
-- The chalk ring
--------------------------------------------------------------------------

-- Where the ring goes on the sheet as laid: view.ringAt is a spot ({ f, x, y,
-- boss }: a face's ring round it where it is on this sheet) or a point of the
-- sheet ({ sx, sy, r }: the cursor's while moving). x, y, r, or nil.
local function RingPoint(view)
    local r = view.ringAt
    if not (r and view.plan) then return nil end
    if r.sx then return r.sx, r.sy, r.r end
    local t = r.boss and view.plan.targets[r.boss]
    if t then return t.x, t.y, t.r + RING.face end
    if not view.At then return nil end
    local x, y = view.At(r.f, r.x, r.y)
    if x then return x, y, RING.r end
end

-- The ring drawn again as view.ringAt says (none: taken off).
local function DrawRing(view)
    local P = view.placer
    view.ringUnder:Begin()
    view.ring:Begin()
    view.ringPoint = nil
    local x, y, r = RingPoint(view)
    if x and P then
        view.ringPoint = { x, y, r }
        local CHALK = DungeonPage.CHALK
        local look = setmetatable({ r = r, colour = CHALK.colour, alpha = DungeonPage.LEADER.alpha,
            nib = ns.UI.YourDiary.LEADER.pen.nib }, { __index = CardSheet().RING })
        local prims = ns.UI.Pen.Ring({}, x, y, look, 1 + (x * 7919 + y * 104729) % 100000)
        local U = CHALK.under
        for _, q in ipairs(prims) do
            local o = U.offset
            P.Quad(view.ringUnder, Style.INK, U.alpha, q.x1 + o, q.y1 + o, q.x2 + o, q.y2 + o, q.x3 + o, q.y3 + o,
                q.x4 + o, q.y4 + o)
            P.Quad(view.ring, { q.r, q.g, q.b }, q.a, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4)
        end
    end
    view.ringUnder:Finish()
    view.ring:Finish()
end

local function SetRing(view, at)
    view.ringAt = at
    DrawRing(view)
end
DungeonPage.NoteRing = SetRing

--------------------------------------------------------------------------
-- The form
--------------------------------------------------------------------------

local function Store(visit)
    local R = ns.RunNotes
    return {
        Insert = function(kind, fields, where) return R.Insert(visit, kind, fields, where) end,
        Edit = function(rec, fields) return R.Edit(visit, rec, fields) end,
        Remove = function(rec) return R.Remove(visit, rec) end,
        -- (laid again on the floor shown: the sheet keeps its choice)
        Redraw = function() DungeonPage.Refresh() end,
    }
end

-- The form on the table for `rec` (nil: a new note at `where`), the ring at
-- its spot while it is up.
local function OpenForm(view, kind, rec, where)
    local spread = DungeonPage.Spread()
    if not spread then return end
    local visit = view.visit
    local ringAt = where or { f = rec.f, x = rec.x, y = rec.y, boss = rec.boss }
    SetRing(view, ringAt)
    CardSheet().OpenRun(kind, rec, {
        host = spread, where = where, skip = ns.RunNotes.KINDS[kind] and ns.RunNotes.KINDS[kind].skip,
        store = Store(visit), confirm = WORDS.confirm,
        spot = function()
            local x, y = RingPoint(view)
            if not x then x, y = view.w / 2, view.h / 2 end
            return OnSpread(view, x, y)
        end,
        sheet = function()
            local lie = view.lie or { 0, 0 }
            return { lie[1] - view.w / 2, lie[2] - view.h / 2, lie[1] + view.w / 2, lie[2] + view.h / 2 }
        end,
        screen = function()
            local s = view.screen
            if s then return s.w, s.h end
            local k = spread:GetScale() or 1
            return (UIParent:GetWidth() or 0) / k, (UIParent:GetHeight() or 0) / k
        end,
        hear = function(form) DungeonPage.Hear(form) end,
        onClose = function()
            if view.ringAt == ringAt then SetRing(view, nil) end
            if spread:IsShown() then DungeonPage.StandIn(DungeonPage.SPREAD.name) end
            ns.UI.Pad.Refresh()
        end,
    })
    DungeonPage.StandIn(CardSheet().TABLE.name)
    ns.UI.Pad.Refresh()
end

-- A new note at `where` ({ f, x, y, boss }).
local function Add(view, where)
    if not Allowed(view) then return end
    OpenForm(view, Kind(), nil, where)
end
DungeonPage.NoteAdd = Add

local function Edit(view, rec)
    if not Allowed(view) then return end
    OpenForm(view, rec.kind, rec, nil)
end

local function Remove(view, rec)
    local visit = view.visit
    local popup = ns.UI.Dialog.Confirm(WORDS.confirm, function()
        if not ns.RunNotes.Remove(visit, rec) then return end
        Style.PlaySound("tear")
        DungeonPage.Refresh()
    end)
    if type(popup) == "table" and popup.Raise then popup:Raise() end
end

--------------------------------------------------------------------------
-- Moving
--------------------------------------------------------------------------

local StartMove, EndMove

-- The moved note's strip and leader faded where it lies on this sheet, every
-- other at full strength (the pools are shared: given back each lay).
local function Fade(view)
    local saved = view.moving and Saved(view.moving.rec)
    for _, pool in ipairs({ view.leaders, view.leaderUnder }) do
        for i = 1, pool.used or 0 do if pool[i].SetAlpha then pool[i]:SetAlpha(1) end end
    end
    for _, entry in ipairs(view.ownStrips or {}) do
        local moved = saved ~= nil and Saved(entry.rec) == saved
        entry.strip:SetAlpha(moved and MOVE.alpha or 1)
        if moved and entry.leaders then
            local r = entry.leaders
            for i = r[1], r[2] do if view.leaders[i] then view.leaders[i]:SetAlpha(MOVE.alpha) end end
            for i = r[3], r[4] do if view.leaderUnder[i] then view.leaderUnder[i]:SetAlpha(MOVE.alpha) end end
        end
    end
end

-- The tooltip at the cursor while moving: what a click does there.
local function MoveTip(view, catcher, mark)
    GameTooltip:SetOwner(catcher, "ANCHOR_CURSOR")
    local name = mark and (view.plan.names and view.plan.names[mark.name] or mark.name)
    GameTooltip:SetText(mark and ns.Fmt(WORDS.pin, name) or WORDS.drop)
    GameTooltip:AddLine(WORDS.cancel, 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function Cursor(on)
    if on then
        if type(SetCursor) == "function" then pcall(SetCursor, MOVE.cursor) end
    elseif type(ResetCursor) == "function" then
        pcall(ResetCursor)
    end
end

-- The mouse's catcher over the sheet while a note is moved (made once).
local function Catcher(view)
    if view.moveCatcher then return view.moveCatcher end
    local S = view.sheet
    local c = CreateFrame("Frame", MOVE.name, S)
    c:SetAllPoints(S)
    c:SetFrameLevel(S:GetFrameLevel() + MOVE.level)
    c:EnableMouse(true)
    c:Hide()
    view.moveCatcher = c
    local last
    local function Follow(force)
        if not (view.moving and view.plan) then return end
        local x, y = view.K.Cursor()
        if not x then return end
        if not force and last and math.abs(last[1] - x) < MOVE.step and math.abs(last[2] - y) < MOVE.step then return end
        last = { x, y }
        local mark = Snap(view, x, y)
        if mark then
            SetRing(view, { boss = mark.name, f = 0, x = 0, y = 0 })
        else
            SetRing(view, { sx = x, sy = y, r = RING.r })
        end
        MoveTip(view, c, mark)
        Cursor(true)
    end
    c.Follow = Follow
    c:SetScript("OnUpdate", function() Follow(false) end)
    c:SetScript("OnEnter", function() Follow(true) end)
    c:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Cursor(false)
    end)
    c:SetScript("OnMouseUp", function(_, button)
        if not view.moving then return end
        if button == "RightButton" then return EndMove(view, false) end
        local x, y = view.K.Cursor()
        local where = x and WhereAt(view, x, y)
        if where then EndMove(view, where) end
    end)
    -- Escape (it holds that place while it is up), or the run going: left
    -- where it was.
    c:SetScript("OnHide", function()
        if view.moving and not view.moving.pad then EndMove(view, false) end
    end)
    c:RegisterEvent("PLAYER_REGEN_DISABLED")
    c:SetScript("OnEvent", function()
        if view.moving then EndMove(view, false) end
    end)
    return c
end

-- Picks `rec` up to move it: with the pad (`pad`), stepped between the marks
-- (UI/Dungeon/Pad.lua); with the mouse, the catcher.
function StartMove(view, rec, pad)
    if not Allowed(view) then return end
    view.moving = { rec = rec, pad = pad or nil, visit = view.visit }
    if pad then
        SetRing(view, nil)
    else
        local c = Catcher(view)
        c:Show()
        -- (the floors' links over it: a note may go to another floor)
        for i = 1, view.links.used or 0 do
            local link = view.links[i]
            if link then link:SetFrameLevel(c:GetFrameLevel() + 1) end
        end
        DungeonPage.StandIn(MOVE.name)
        c.Follow(true)
    end
    Fade(view)
    ns.UI.Pad.Refresh()
end
DungeonPage.NoteMove = function(view, rec, pad) return StartMove(view, rec, pad) end

-- The move over: the note put at `where`, or (false) left where it was.
-- Returns whether it moved.
function EndMove(view, where)
    local moving = view.moving
    if not moving then return false end
    view.moving = nil
    local moved = false
    if where and moving.visit == view.visit then moved = ns.RunNotes.Move(view.visit, moving.rec, where) end
    local c = view.moveCatcher
    if c and c:IsShown() then c:Hide() end
    GameTooltip:Hide()
    Cursor(false)
    SetRing(view, nil)
    local spread = DungeonPage.Spread()
    if spread and spread:IsShown() then DungeonPage.StandIn(DungeonPage.SPREAD.name) end
    Fade(view)
    if moved then
        Style.PlaySound("write")
        DungeonPage.Refresh()
    end
    -- (the pad onto the note it moved: UI/Dungeon/Pad.lua)
    view.moved = Saved(moving.rec)
    ns.UI.Pad.Refresh()
    return moved
end
DungeonPage.NoteMoveEnd = function(view, where) return EndMove(view, where) end

--------------------------------------------------------------------------
-- The menus
--------------------------------------------------------------------------

-- The menu as a generator (the mouse's MenuUtil and the pad's Pad.Menu
-- alike, so the two never drift: the controller-support skill's rule 6):
-- "Add a note here" at `where`, or the player's own `recs`' Edit, Move and
-- Remove ("Which one?" first, each a submenu, where there are several). Nil
-- where it would hold nothing.
function DungeonPage.NoteGenerator(view, where, recs)
    if recs and recs[1] then
        local function Lines(menu, rec)
            menu:CreateButton(WORDS.edit, function() Edit(view, rec) end)
            menu:CreateButton(WORDS.move, function() StartMove(view, rec, ns.UI.Pad.Input.Active()) end)
            menu:CreateButton(WORDS.remove, function() Remove(view, rec) end)
        end
        return function(_, root)
            if #recs == 1 then return Lines(root, recs[1]) end
            root:CreateTitle(WORDS.which)
            for _, rec in ipairs(recs) do
                local face = DungeonPage.NoteFace(rec.kind)
                local words = face and (face.describe and face.describe(rec) or face.tips({ rec }, ns.Now())) or "?"
                Lines(root:CreateButton(words), rec)
            end
        end
    end
    if where then
        return function(_, root) root:CreateButton(WORDS.add, function() Add(view, where) end) end
    end
    return nil
end

-- A right press on the sheet (`hit` nil: the paper), on a mark's square
-- (`hit`), or on the player's own strip (`entry`, LayOwn's).
function DungeonPage.NoteRight(view, hit, entry)
    if not Allowed(view) then return end
    local where, recs, owner
    if entry then
        recs, owner = { entry.rec }, entry.strip
    elseif hit then
        owner = hit
        if hit.own then recs = hit.own else where = WhereOfHit(view, hit) end
    else
        owner = view.sheet
        local x, y = view.K.Cursor()
        if x then where = WhereAt(view, x, y) end
    end
    local generator = DungeonPage.NoteGenerator(view, where, recs)
    if generator then MenuUtil.CreateContextMenu(owner, generator) end
end

-- The pad's Y on what it stands on (UI/Dungeon/Pad.lua's item; `mine`: the
-- player's own strip, LayOwn's entry): "add" (a
-- boss, pinned; the way in or a mark, at its spot: straight to the form),
-- "menu" (the player's own note: its menu on the pad's slip), or nil for
-- nothing (a detected strip, a floor's link, the bookmark, an item). `dry`
-- only says which (the prompt).
function DungeonPage.NotePad(view, item, dry)
    if not (item and Allowed(view)) then return nil end
    if item.mine then
        if not dry then
            ns.UI.Pad.Menu.Open(item.mine.strip, DungeonPage.NoteGenerator(view, nil, { item.mine.rec }))
        end
        return "menu"
    end
    local hit = item.what and item.frame
    if not hit then return nil end
    if hit.own then
        if not dry then ns.UI.Pad.Menu.Open(hit, DungeonPage.NoteGenerator(view, nil, hit.own)) end
        return "menu"
    end
    local where = WhereOfHit(view, hit)
    if not where then return nil end
    if not dry then Add(view, where) end
    return "add"
end

--------------------------------------------------------------------------
-- The sheet's hooks (UI/Dungeon/Sheet.lua, Spread.lua)
--------------------------------------------------------------------------

-- Before the sheet is laid for `visit`: another run puts away the form and a
-- move.
function DungeonPage.NotesBefore(view, visit)
    if view.visit == visit then return end
    if view.moving then EndMove(view, false) end
    local run = CardSheet().Run()
    if run then CardSheet().View():Hide(true) end
end

-- Once laid: the ring where it was, the move's fade, the floors' links over
-- the catcher, and the right click on the player's own strips.
function DungeonPage.NotesLaid(view)
    DrawRing(view)
    local writable = view.visit and ns.RunNotes.Writable(view.visit)
    for _, entry in ipairs(view.ownStrips or {}) do
        entry.strip:SetRight(writable and function() DungeonPage.NoteRight(view, nil, entry) end or nil, true)
    end
    local c = view.moveCatcher
    if view.moving and c and c:IsShown() then
        for i = 1, view.links.used or 0 do
            local link = view.links[i]
            if link then link:SetFrameLevel(c:GetFrameLevel() + 1) end
        end
    end
    Fade(view)
end

-- The run put away: the move given up and the form put away unwritten.
function DungeonPage.NotesGone(view)
    if view.moving then EndMove(view, false) end
    if CardSheet().Run() then CardSheet().View():Hide(true) end
    if view.ringAt then SetRing(view, nil) end
end
