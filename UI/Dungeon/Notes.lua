-- The dungeon page's margin notes (MAP-13, MAP-15): paper strips taped
-- under the print, each with a pencil leader ending in an arrowhead at
-- what it is about: a boss's face ("Wiped once", "Killed on the third
-- try", an item that dropped there for you or for someone in the diary) or
-- the way in ("Ran back once", "as a ghost"). The strips are ns.UI.PaperStrip's, as the plates' margin
-- notes are (UI/Journey/Margin.lua); the leaders are drawn with the pen,
-- as the plates' are (UI/Journey/Leaders.lua), on the print's own layer
-- over the art and under the faces.
--
-- Chosen, not dumped (MAP-15): wipes first, then loot for you and the
-- diary's people, then tries, then the runs back; at most NOTES.most, the
-- rest counted ("and 2 more", and told in the bosses' tooltips). A
-- stranger's loot is never a note. The strips lie in two columns under the
-- print, the notes about the left of the map on the left, each column top
-- to bottom as their marks lie, so the leaders seldom cross; they never
-- lie on the print, so they never cover a face, each other or the head.

local addonName, ns = ...

local Style = ns.Style
local DungeonPage = ns.UI.DungeonPage

-- At most `most` notes; two columns `gap` px apart, the strips `row` px
-- apart down them; the count of the rest `more` px high under them; at
-- most `items` items named on one boss's loot strip.
local NOTES = { most = 5, gap = 12, row = 6, more = 14, items = 3 }
-- A leader: pencil (`colour`) `width` px at `alpha`, thinning toward the
-- strip to `taper` of itself over `over` px, bowed by `bow` of its length;
-- it stops `gap` px short of its mark's edge, in an arrowhead `head`
-- (length, width) px. Resampled every `step` px, at most `budget` pieces.
local LEADER = { colour = Style.GRAPHITE, width = 1.3, alpha = 0.85, taper = 0.55, over = 14, bow = 0.08,
    gap = 3, head = { 7, 5.5 }, step = 3, budget = 240 }
DungeonPage.NOTES, DungeonPage.LEADER = NOTES, LEADER

--------------------------------------------------------------------------
-- What to say
--------------------------------------------------------------------------

-- The notes worth a strip, in the order they are chosen: { rank, kind
-- ("wipe", "wayWipe", "loot", "tries", "ranBack"), boss (or door = true,
-- or wipe = its index in notes.wipes), name, what, guid (a diary entry to
-- open, not the page's own person), items, seed }. A boss's loot for you
-- and the diary's people is one note, its items in its heading (MAP-13:
-- one leader a boss): `items` = { { item, guid (theirs to open, or nil),
-- line (for whom, for its tooltip), from, text (its piece of the
-- heading) } }, at most NOTES.items of them. The wipes, at a boss and on
-- the way (MAP-17), come first, in the order they happened.
-- `notes` are ns.DungeonRun.Notes(visit); `guid` the page's person.
function DungeonPage.Choose(visit, notes, guid)
    local Words = DungeonPage.Words
    local list = {}
    local function Add(note)
        note.seed = table.concat({ visit.id or 0, note.kind, note.boss and note.boss.name or "door", #list }, ":")
        list[#list + 1] = note
    end
    local function FirstDeath(deaths)
        local first
        for _, d in ipairs(deaths or {}) do first = math.min(first or d.time, d.time) end
        return first
    end
    for i, e in ipairs(notes.bosses or {}) do
        if (e.wipes or 0) > 0 then
            Add({ rank = 1, order = FirstDeath(e.deaths) or e.at or math.huge, kind = "wipe", boss = e.boss,
                name = Words.Wipes(e.wipes),
                what = e.killed and Words.KilledOn(e.tries) or (not e.killed and Words.STANDING) or nil })
        end
        local items, links, guids, seen, owner, first = {}, {}, {}, {}, nil, nil
        for _, entry in ipairs(e.loot or {}) do
            if Words.Noted(visit, entry.guid) and #items < NOTES.items then
                local diary = entry.guid ~= guid and ns.Diary.IsDiary(entry.guid)
                items[#items + 1] = { item = entry.item, guid = diary and entry.guid or nil,
                    line = Words.Capital(Words.Dropped(visit, entry.guid)) }
                links[#links + 1] = Style.Inkify(entry.item or "?")
                if not seen[entry.guid] then
                    seen[entry.guid] = true
                    guids[#guids + 1] = entry.guid
                end
                owner = owner or (diary and entry.guid) or nil
                first = math.min(first or entry.time or 0, entry.time or 0)
            end
        end
        if #items > 0 then
            local heading, parts = Words.Items(links)
            for k, part in ipairs(parts) do items[k].from, items[k].text = part.from, part.text end
            Add({ rank = 2, order = first or i, kind = "loot", boss = e.boss, items = items, name = heading,
                what = Words.DroppedFor(visit, guids), guid = owner })
        end
        if (e.wipes or 0) == 0 and (e.tries or 0) > 1 then
            local name = Words.Tries(e.tries, e.killed)
            if name then
                Add({ rank = 3, order = i, kind = "tries", boss = e.boss, name = name,
                    what = not e.killed and Words.STANDING or nil })
            end
        end
    end
    for i, w in ipairs(notes.wipes or {}) do
        Add({ rank = 1, order = FirstDeath(w.deaths) or 0, kind = "wayWipe", wipe = i, name = Words.WAY_WIPE,
            what = Words.WipedTo(visit, w) })
    end
    if (notes.ranBack or 0) > 0 then
        Add({ rank = 4, order = 0, kind = "ranBack", door = true, name = Words.RanBack(notes.ranBack),
            what = Words.GHOST })
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)
    return list
end

--------------------------------------------------------------------------
-- The strips
--------------------------------------------------------------------------

local function ToPerson(guid)
    if guid then ns.UI.YourDiary.ToPerson(guid) end
end

-- A strip of the page's, and over each item named on a loot strip a
-- square of our own: the item's own tooltip, for whom it dropped under
-- it, and a click opens their page where they are in the diary.
function DungeonPage.NewNote(view)
    local strip = ns.UI.PaperStrip(view)
    local note = { strip = strip }
    note.links = ns.UI.Pool.New(function()
        local hover = CreateFrame("Button", nil, view)
        hover:SetFrameLevel(strip:GetFrameLevel() + 5)
        hover:SetScript("OnEnter", function(self)
            strip:Hover(true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local it = self.item
            local shown = it and it.item and type(GameTooltip.SetHyperlink) == "function"
                and pcall(GameTooltip.SetHyperlink, GameTooltip, it.item)
            if not shown then GameTooltip:SetText(it and it.text or "") end
            if it and it.line then GameTooltip:AddLine(it.line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", function()
            strip:Hover(false)
            GameTooltip:Hide()
        end)
        hover:SetScript("OnClick", function(self) ToPerson(self.item and self.item.guid) end)
        return hover
    end)
    function note:Show() self.strip:Show() end
    function note:Hide()
        self.strip:Hide()
        self.links:Begin()
        self.links:Finish()
    end
    return note
end

-- Over each item a loot strip names, its own square (NewNote's), as wide
-- as its link in the heading's hand, the strip laid at x, y.
local function PlaceLinks(view, slot, x, y)
    slot.links:Begin()
    local items = slot.note.items
    if items then
        local m = view.nameMeasure
        local l, t = slot.strip:Pad()
        local h = math.max(slot.strip.name:GetStringHeight() or 0, 16)
        for _, it in ipairs(items) do
            m:SetText(it.from)
            local before = it.from ~= "" and m:GetStringWidth() or 0
            m:SetText(it.text)
            local hover = slot.links:Next()
            hover.item = it
            hover:ClearAllPoints()
            hover:SetPoint("TOPLEFT", view, "TOPLEFT", x + l + before, -(y + t))
            hover:SetSize(math.max(m:GetStringWidth(), 8), h)
        end
    end
    slot.links:Finish()
end

-- The column a strip is laid in, `width` wide.
local function ColumnWidth(view)
    return (view.right - view.left - NOTES.gap) / 2
end

-- Sets `slot` (a note of the pool) to say `note`.
local function Say(slot, note)
    slot.note = note
    slot.strip:SetNote({ name = note.name, what = note.what, guid = note.guid, onClick = ToPerson,
        strong = true, seed = note.seed })
end

-- How much of the page the notes take under the print, before it is laid:
-- the first NOTES.most of `list`, two to a row (0 for none).
function DungeonPage.NotesHeight(view, list)
    local n = math.min(#list, NOTES.most)
    if n == 0 then return 0 end
    local tallest = 0
    view.notes:Begin()
    for i = 1, n do
        local slot = view.notes:Next()
        Say(slot, list[i])
        local _, h = slot.strip:Layout(view.left, 0, ColumnWidth(view))
        tallest = math.max(tallest, h)
    end
    view.notes:Finish()
    local rows = math.ceil(n / 2)
    return rows * tallest + (rows - 1) * NOTES.row + (#list > n and NOTES.more or 0)
end

-- The leader along `ctrl` (points { x, y } on the print: from the strip,
-- by any bends on the way) to the mark t ({ x, y, r }): a pencil line,
-- its corners rounded, bowed a little on its last stretch, ending in an
-- arrowhead `gap` short of the mark's edge. Returns its tip, or nil when
-- the strip lies too close to the mark for one.
local function Leader(print, pool, ctrl, t, bend)
    local Pen = ns.UI.Pen
    local last = ctrl[#ctrl]
    local dx, dy = t.x - last[1], t.y - last[2]
    local len = math.sqrt(dx * dx + dy * dy)
    local H = LEADER.head
    if len < t.r + LEADER.gap + H[1] + 4 then return nil end
    local ux, uy = dx / len, dy / len
    local tx, ty = t.x - ux * (t.r + LEADER.gap), t.y - uy * (t.r + LEADER.gap)
    local bx, by = tx - ux * H[1], ty - uy * H[1]
    -- The last stretch bowed a little, the same way every time for the
    -- same note; the corners on the way rounded off.
    local reach = len - t.r - LEADER.gap - H[1]
    local points = {}
    for _, c in ipairs(ctrl) do
        points[#points + 1] = c[1]
        points[#points + 1] = c[2]
    end
    points[#points + 1] = last[1] + ux * reach / 2 - uy * reach * LEADER.bow * bend
    points[#points + 1] = last[2] + uy * reach / 2 + ux * reach * LEADER.bow * bend
    points[#points + 1], points[#points + 2] = bx, by
    local P = Pen.Resample(Pen.Chaikin(points, 3), LEADER.step)
    if #P >= 2 then
        local prims = {}
        local M = Pen.Mitres(P)
        local function Half(i)
            local taper = LEADER.taper + (1 - LEADER.taper) * math.min(1, P[i].s / LEADER.over)
            return LEADER.width / 2 * taper
        end
        Pen.Stroke(prims, 0, P, M, Half, function() return 0 end, function() return LEADER.alpha end,
            LEADER.colour, nil, LEADER.budget)
        for _, q in ipairs(prims) do
            local texture = pool:Next()
            texture:SetTexture(nil)
            texture:SetVertexColor(1, 1, 1, 1)
            texture:SetColorTexture(q.r, q.g, q.b, q.a)
            if not Style.Quad(texture, print, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                texture:Hide()
            end
        end
    end
    -- The head: a filled triangle; two strokes where corners cannot move.
    local px, py = -uy * H[2] / 2, ux * H[2] / 2
    local C = LEADER.colour
    local head = pool:Next()
    head:SetTexture(nil)
    head:SetVertexColor(1, 1, 1, 1)
    head:SetColorTexture(C[1], C[2], C[3], LEADER.alpha)
    if not Style.Quad(head, print, tx, ty, tx, ty, bx + px, by + py, bx - px, by - py) then
        head:Hide()
        for _, side in ipairs({ 1, -1 }) do
            local stroke = pool:Next()
            local sx, sy = bx + side * px, by + side * py
            local sdx, sdy = tx - sx, ty - sy
            local sl = math.sqrt(sdx * sdx + sdy * sdy)
            stroke:SetColorTexture(C[1], C[2], C[3], LEADER.alpha)
            stroke:ClearAllPoints()
            stroke:SetPoint("CENTER", print, "TOPLEFT", (sx + tx) / 2, -(sy + ty) / 2)
            stroke:SetSize(sl + 0.5, LEADER.width)
            if stroke.SetRotation then stroke:SetRotation(math.atan2(-sdy, sdx)) else stroke:Hide() end
        end
    end
    return tx, ty
end

-- Whether the straight line from a to b passes over any of `boxes` ({ x, y,
-- w, h }, `pad` px larger) but `own`.
local function Crosses(a, b, boxes, own, pad)
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 3))
    for k = 1, n do
        local x, y = a[1] + dx * k / n, a[2] + dy * k / n
        for _, box in ipairs(boxes) do
            if box ~= own and x > box[1] - pad and x < box[1] + box[3] + pad
                and y > box[2] - pad and y < box[2] + box[4] + pad then
                return true
            end
        end
    end
    return false
end

-- Lays the notes of `list` (DungeonPage.Choose) under the print from `top`
-- down, each leader to its mark on the print as drawn (print.targets),
-- those whose mark is on another floor left for that floor. A leader that
-- would pass over another strip goes round it instead: out of its side
-- into the gap between the columns (LEADER's channel), up the gap and over
-- to its mark. Returns the height they took. Kept for the tests:
-- view.noteStrips ({ note, strip, box, from, target and tip on the page })
-- and view.notesMore.
function DungeonPage.LayNotes(view, list, top)
    local print = view.print
    local ox, oy = print.origin[1], print.origin[2]
    local shown = {}
    local here = 0
    for _, note in ipairs(list) do
        local t = (note.door and print.targets.door) or (note.wipe and print.targets["wipe:" .. note.wipe])
            or (note.boss and print.targets[note.boss.name])
        if t then
            here = here + 1
            if #shown < NOTES.most then shown[#shown + 1] = { note = note, t = t } end
        end
    end
    view.notesMore = here - #shown
    view.noteStrips = {}

    -- The left of the map to the left column, each column as the marks lie
    -- from the top.
    table.sort(shown, function(a, b) return a.t.x < b.t.x end)
    local split = math.ceil(#shown / 2)
    local columns = { {}, {} }
    for i, s in ipairs(shown) do table.insert(columns[i <= split and 1 or 2], s) end
    for _, column in ipairs(columns) do
        table.sort(column, function(a, b) return a.t.y < b.t.y end)
    end

    view.notes:Begin()
    print.pools.leader:Begin()
    local width = ColumnWidth(view)
    local bottom = top
    local laid, boxes = {}, {}
    for c, column in ipairs(columns) do
        local x = view.left + (c - 1) * (width + NOTES.gap)
        local y = top
        for k, s in ipairs(column) do
            local slot = view.notes:Next()
            Say(slot, s.note)
            -- A lone note lies under its mark, where the column allows.
            local nx = x
            if #shown == 1 then
                nx = math.max(view.left, math.min(view.right - width, ox + s.t.x - width / 2))
            end
            local w, h = slot.strip:Layout(nx, y, width)
            PlaceLinks(view, slot, nx, y)
            local box = { nx, y, w, h }
            boxes[#boxes + 1] = box
            laid[#laid + 1] = { s = s, slot = slot, box = box }
            y = y + h + (k < #column and NOTES.row or 0)
        end
        bottom = math.max(bottom, y)
    end

    -- The leaders, once every strip lies where it does.
    local channel = view.left + width + NOTES.gap / 2
    local inChannel = 0
    for i, l in ipairs(laid) do
        local t, box = l.s.t, l.box
        local target = { ox + t.x, oy + t.y }
        local sx, sy = l.slot.strip:Nearest(target[1], target[2])
        local ctrl = { { sx, sy } }
        if Crosses({ sx, sy }, target, boxes, box, 2) then
            -- Round the strips in its way: out of its side nearest the gap,
            -- up the gap, a lane each, and over to its mark.
            inChannel = inChannel + 1
            local cx = channel + (inChannel % 2 == 0 and 3 or -3) * math.floor((inChannel + 1) / 2)
            sx, sy = l.slot.strip:Nearest(cx, box[2] + box[4] / 2)
            ctrl = { { sx, sy }, { cx, sy }, { cx, top - 6 } }
        end
        for _, c in ipairs(ctrl) do c[1], c[2] = c[1] - ox, c[2] - oy end
        local bend = (i % 2 == 0) and 1 or -1
        local tx, ty = Leader(print, print.pools.leader, ctrl, t, bend)
        view.noteStrips[#view.noteStrips + 1] = { note = l.s.note, strip = l.slot.strip, box = box,
            target = target, tip = tx and { ox + tx, oy + ty } or nil, from = { sx, sy },
            channel = #ctrl > 1 or nil }
    end
    print.pools.leader:Finish()
    view.notes:Finish()

    view.more:SetShown(view.notesMore > 0)
    if view.notesMore > 0 then
        view.more:ClearAllPoints()
        view.more:SetPoint("TOPRIGHT", view, "TOPLEFT", view.right, -(bottom + 2))
        view.more:SetText(DungeonPage.Words.More(view.notesMore))
        bottom = bottom + NOTES.more
    end
    return bottom - top
end

-- No notes on the page: the strips, their leaders and the count put away.
function DungeonPage.ClearNotes(view)
    view.notes:Begin()
    view.notes:Finish()
    view.print.pools.leader:Begin()
    view.print.pools.leader:Finish()
    view.more:Hide()
    view.noteStrips, view.notesMore = {}, 0
end
