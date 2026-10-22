-- The plate on a person's page (the person-page proposal, variant A, and
-- the user's plate decisions of 20 Oct): a print of the map where
-- something with them happened, glued in with four photo corners beside
-- the facts' strips, as Your Diary's FL page turned sideways. It is Your
-- Diary's plate (UI/Journey/Plate.lua: the card, its art, the ink trail,
-- the marks) at its fixed scale, one screen px a px of the map's art, so a
-- smaller print is a smaller window and never a squeezed one.
--
-- What it shows is Core/PersonPlate.lua's choice (ns.PersonPlate.For):
-- centred on the event; the road of the together session around it, the
-- user's own route, cut to the map and to the session's times; the other
-- weighed things on that map where they fall in the print; and, where it
-- lies on that map, where they were last seen (a rubric X). It names no
-- place: no caption, nothing about other zones. Every mark says what it is
-- under the mouse in this page's words (UI/Words/Person.lua). With nothing
-- to place there is no plate, and no words for it.
--
-- A click on it opens the "Where you saw them" map sheet, as its side tab
-- does. The first-met strip's pencil leader runs to the meeting's ring
-- (the plates' leader, LEADER: graphite, bowed a little, a dot short of
-- the mark), and follows it as the print leans in under the mouse.

local addonName, ns = ...

local Style = ns.Style
local Plate = ns.UI.JourneyPlate
local PersonText = ns.UI.PersonText
local LEADER = ns.UI.YourDiary.LEADER

local PersonPlate = {}
ns.UI.PersonPlate = PersonPlate

-- Its slot on the page's top block (UI/Journal/Clippings.lua: x, y from
-- its top left, y down; the plates' slot, UI/Journey/Look.lua's LAYOUT):
-- 262 x 178, its art 248 x 164 inside a 7 px margin, turned 1.4 degrees
-- against the clock, four photo corners, none lifted (one wear is the
-- name sheet's corner).
local SLOT = { x = 4, y = 8, w = 262, h = 178, t = -1.4, pad = 7, pc = 18, corners = { "tl", "tr", "bl", "br" } }
-- A dungeon's door is the route's own dungeon segment's entrance where the
-- run began within `door` seconds of it.
local LOOK = { door = 10 * 60, leaders = 18 }
PersonPlate.SLOT, PersonPlate.LOOK = SLOT, LOOK

--------------------------------------------------------------------------
-- What is drawn
--------------------------------------------------------------------------

-- The road of `road` ({ me, mapID, from, to }): that character's stops on
-- the map that overlap the times, and its roads cut to them (a road's
-- time shared out by its length, as the plates share a road cut at a
-- window's edge). A sheet as Your Diary's plates take one
-- (Recap.Sheet's), with nothing else: no flights, doors, pins.
local function Cut(road, a, b)
    local from, to = road.from or 0, road.to or road.from or 0
    if a <= from and b >= to then return road end
    local pts = ns.Journey.Points(road)
    local total, lens = 0, {}
    for k = 1, #pts - 3, 2 do
        local len = math.sqrt((pts[k + 2] - pts[k]) ^ 2 + (pts[k + 3] - pts[k + 1]) ^ 2)
        lens[#lens + 1] = len
        total = total + len
    end
    if total <= 0 or to <= from then return nil end
    local s0 = (math.max(a, from) - from) / (to - from) * total
    local s1 = (math.min(b, to) - from) / (to - from) * total
    local out, s = {}, 0
    local function Add(x, y) out[#out + 1], out[#out + 2] = x, y end
    for i, len in ipairs(lens) do
        local k = 2 * i - 1
        local x1, y1, x2, y2 = pts[k], pts[k + 1], pts[k + 2], pts[k + 3]
        local e = s + len
        if e >= s0 and s <= s1 and len > 0 then
            local u0, u1 = math.max(0, (s0 - s) / len), math.min(1, (s1 - s) / len)
            if #out == 0 then Add(x1 + (x2 - x1) * u0, y1 + (y2 - y1) * u0) end
            Add(x1 + (x2 - x1) * u1, y1 + (y2 - y1) * u1)
        end
        s = e
    end
    if #out < 4 then return nil end
    return { kind = "road", mapID = road.mapID, from = math.max(a, from), to = math.min(b, to), act = road.act,
        levelFrom = road.levelFrom, levelTo = road.levelTo, pts = out, of = road }
end
PersonPlate.Cut = Cut

local function Road(road, mapID)
    local sheet = { mapID = mapID, stops = {}, roads = {}, flights = {}, dungeons = {}, pins = {}, meetings = {} }
    local j = road and ns.Journey.For(road.me)
    if not j then return sheet end
    for _, seg in ipairs(ns.Journey.All(j)) do
        if seg.mapID == mapID and seg.from < road.to and (seg.to or seg.from) > road.from then
            if seg.kind == "stop" then
                sheet.stops[#sheet.stops + 1] = seg
            elseif seg.kind == "road" then
                sheet.roads[#sheet.roads + 1] = Cut(seg, road.from, road.to)
            end
        end
    end
    return sheet
end
PersonPlate.Road = Road

-- The door of a dungeon run on `mapID`: the route's dungeon segment it
-- began from, or nil.
local function Door(visit, me, mapID)
    local j = me and ns.Journey.For(me)
    if not (j and visit.startedAt) then return nil end
    for _, seg in ipairs(ns.Journey.All(j)) do
        if seg.kind == "dungeon" and seg.mapID == mapID and seg.x
            and math.abs((seg.from or 0) - visit.startedAt) <= LOOK.door then
            return seg
        end
    end
    return nil
end

-- Whether a thing at `t` is the first meeting (People.Stats' firstMet).
local function First(s, t)
    return s.firstMet ~= nil and t == s.firstMet
end

-- A candidate of Core/PersonPlate.lua's ({ key, t, me, mapID, x, y, item })
-- as a moment for the plate ({ kind, mapID, x, y, t, tip, ... }): the
-- plates' person ring for time together and the meeting, the folded note,
-- the crossed strokes of a fight, the hollow lozenge of a first sighting,
-- a doorway, and a dot for the rest (a trade, a word said, a rare killed).
-- `met` is set on the first meeting's.
local function Moment(c, s, guid)
    local m = { mapID = c.mapID, x = c.x, y = c.y, t = c.t, guid = guid, from = c }
    local key, item = c.key, c.item or {}
    if key == "note" then
        local note = item.note
        m.kind, m.note = "note", note
        m.tip = function(_, now) return PersonText.NoteTip(note, guid, now) end
    elseif key == "group" or key == "session" then
        local session = item.session
        local p = session.participants and session.participants[guid]
        local seconds = p and p.seconds or ns.Sessions.Duration(session)
        m.kind, m.session = "session", session
        m.met = First(s, session.startedAt)
        m.tip = function(_, now)
            if m.met then
                local words = session.source == "group" and (session.raid and "Raided together" or "Grouped")
                    or PersonText.TogetherTip(seconds, session.startedAt, now)
                return PersonText.MetTip(words, session.startedAt, now)
            end
            return PersonText.TogetherTip(seconds, session.startedAt, now)
        end
    elseif key == "first" then
        m.kind, m.first = "first", item.first
        m.tip = function(_, now) return PersonText.FirstSeenTip(c.t, now) end
    elseif key == "visit" then
        local visit = item.visit
        local door = Door(visit, c.me, c.mapID)
        if door then m.x, m.y = door.x, door.y end
        local seconds = (visit.endedAt or ns.Now()) - visit.startedAt
        -- Its own words, no level (Text.Dungeon reads none here).
        m.kind, m.seg = "dungeon", { name = visit.name, seconds = seconds, from = visit.startedAt }
    elseif item.kind == "row" then
        local row = item.row
        local spec = ns.Rows.Get(row.type)
        m.kind = spec.fight and "fight" or row.type == "group_join" and "session" or "dot"
        m.met = First(s, row.time)
        m.tip = function(_, now)
            if m.met then
                local text = spec.text and spec.text(row, guid) or nil
                if text and row.zone then text = text:gsub(" in " .. row.zone:gsub("%p", "%%%0") .. "$", "") end
                return PersonText.MetTip(text, row.time, now)
            end
            return PersonText.RowTip(row, guid, now)
        end
    else
        -- A rare killed, a while seen around: its timeline words.
        local _, words = ns.UI.DescribeItem(item, guid)
        if words and item.kind == "around" then words = "Seen around" end
        m.kind = "dot"
        m.tip = function(_, now) return PersonText.ItemTip(words, c.t, now) end
    end
    return m
end
PersonPlate.Moment = Moment

-- The fallback, where they first met with nothing else to place: the
-- spot they were added at, their first group, or their first sighting.
local function Met(pick, s, guid)
    local entry = s.entry
    local m = { mapID = pick.mapID, x = pick.x, y = pick.y, t = pick.t, guid = guid, met = true, from = pick }
    if entry.addedAt == pick.t then
        m.kind = "session"
        m.tip = function(_, now) return PersonText.AddedTip(pick.t, now) end
        return m
    end
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row.type == "group_join" and row.time == pick.t then
            local spec = ns.Rows.Get(row.type)
            m.kind = "session"
            m.tip = function(_, now) return PersonText.MetTip(spec.text and spec.text(row, guid), row.time, now) end
            return m
        end
    end
    m.kind = "first"
    m.tip = function(_, now) return PersonText.FirstSeenTip(pick.t, now) end
    return m
end

-- Everything the plate of `pick` marks: the event, the others on its map,
-- and where they were last seen when that is on it.
function PersonPlate.Moments(pick, s)
    local guid = s.guid
    local list = {}
    if pick.fallback then
        list[1] = Met(pick, s, guid)
    else
        list[1] = Moment(pick, s, guid)
        for _, c in ipairs(pick.marks or {}) do list[#list + 1] = Moment(c, s, guid) end
    end
    local seen = s.record and s.record.seen
    if seen and seen.mapID == pick.mapID and seen.x and ns.ZoneOf(seen.mapID) == seen.mapID then
        list[#list + 1] = { kind = "seen", mapID = seen.mapID, x = seen.x, y = seen.y, t = seen.time, guid = guid,
            tip = function(_, now) return PersonText.SeenTip(seen, now) end }
    end
    return list
end

--------------------------------------------------------------------------
-- The leader
--------------------------------------------------------------------------

-- The pen's stroke along `points` (x, y, ...: on `frame`, y down) into the
-- link's textures, as Your Diary's leaders are drawn (UI/Journey/
-- Leaders.lua's Pencil, on the frame they are laid on).
local function Pencil(link, points, frame)
    local Pen, look = ns.UI.Pen, LEADER.pen
    local length = 0
    for k = 1, #points - 3, 2 do
        length = length + math.sqrt((points[k + 2] - points[k]) ^ 2 + (points[k + 3] - points[k + 1]) ^ 2)
    end
    local P = Pen.Resample(points, math.max(look.step, length / (#link.strokes - 1)))
    local prims = {}
    if #P >= 2 then
        local M = Pen.Mitres(P)
        local n, T = #P, look.taper
        local function Half(i)
            local a, b = P[math.max(i - 1, 1)], P[math.min(i + 1, n)]
            local taper = T.from + (1 - T.from) * math.min(1, P[i].s / T.over)
            return look.width / 2 * Pen.Nib(b.x - a.x, b.y - a.y, look.nib) * taper
        end
        Pen.Stroke(prims, 0, P, M, Half, function() return 0 end, function() return LEADER.alpha end,
            LEADER.colour, nil, #link.strokes)
    end
    for k, stroke in ipairs(link.strokes) do
        local q = prims[k]
        if q then
            stroke:SetColorTexture(q.r, q.g, q.b, q.a)
            if Style.Quad(stroke, frame, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                stroke:Show()
            elseif stroke.SetRotation then
                -- From the middle of its start to the middle of its end.
                local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
                local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
                local dx, dy = ex - sx, ey - sy
                stroke:ClearAllPoints()
                stroke:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, look.width)
                stroke:SetPoint("CENTER", frame, "TOPLEFT", (sx + ex) / 2, -(sy + ey) / 2)
                stroke:SetRotation(math.atan2(-dy, dx))
                stroke:Show()
            else
                stroke:Hide()
            end
        else
            stroke:Hide()
        end
    end
    link.drawn = math.min(#prims, #link.strokes)
end

-- The leader from the strip's edge nearest the mark (x, y on the block as
-- the print shows it unleaned) to a dot LEADER.stop short of it, bowed a
-- little toward the page's foot; `scale` the print's lean (its picture
-- grows about the card's middle). None where the mark is off the print.
local function Aim(link, scale)
    local s, mark = SLOT, link.mark
    local cx, cy = s.x + s.w / 2, s.y + s.h / 2
    local mx, my = cx + (mark[1] - cx) * scale, cy + (mark[2] - cy) * scale
    local function Hide()
        for _, stroke in ipairs(link.strokes) do stroke:Hide() end
        link.dot:Hide()
        link.drawn = 0
    end
    if math.abs(mx - cx) > s.w / 2 - s.pad or math.abs(my - cy) > s.h / 2 - s.pad then return Hide() end
    local sx, sy = link.strip:Nearest(mx, my)
    local dx, dy = mx - sx, my - sy
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= LEADER.stop + 1 then return Hide() end
    local tx, ty = mx - dx / d * LEADER.stop, my - dy / d * LEADER.stop
    local lx, ly = tx - sx, ty - sy
    local length = math.sqrt(lx * lx + ly * ly)
    local nx, ny = -ly / length, lx / length
    if ny < 0 then nx, ny = -nx, -ny end
    local kx, ky = (sx + tx) / 2 + nx * LEADER.bow * length * 2, (sy + ty) / 2 + ny * LEADER.bow * length * 2
    local steps, points = LEADER.pen.curve, { sx, sy }
    for i = 1, steps do
        local t = i / steps
        local u = 1 - t
        points[#points + 1] = u * u * sx + 2 * u * t * kx + t * t * tx
        points[#points + 1] = u * u * sy + 2 * u * t * ky + t * t * ty
    end
    link.points = points
    Pencil(link, points, link.frame)
    local dot, C = link.dot, LEADER.colour
    Style.Disc(dot, C[1], C[2], C[3], LEADER.dotAlpha)
    dot:ClearAllPoints()
    dot:SetSize(LEADER.dot, LEADER.dot)
    dot:SetPoint("CENTER", link.frame, "TOPLEFT", tx, -ty)
    dot:Show()
end
PersonPlate.Aim = Aim

--------------------------------------------------------------------------
-- The plate
--------------------------------------------------------------------------

-- The plate on `parent` (the top block: its slot is measured there);
-- `open()` is what a click on it does (the map sheet).
function PersonPlate.New(parent, open)
    local view = Plate(parent, SLOT)
    view:SetClick(function()
        Style.PlaySound("pageTurn")
        if open then open() end
    end)
    -- Over the print outside a mark: what it is, and that it opens. Its
    -- lean still follows the mouse (the plate's own hover).
    Style.Tooltip(view.clip, function() return Style.TipList(PersonText.PLATE[1], PersonText.PLATE[2]) end,
        "ANCHOR_RIGHT", function() view:Lean() end)

    -- The leader's ink: over the print, under the strips.
    local ink = CreateFrame("Frame", nil, parent)
    ink:SetAllPoints(parent)
    ink:SetFrameLevel(parent:GetFrameLevel() + LOOK.leaders)
    local link = { frame = parent, strokes = {}, dot = ink:CreateTexture(nil, "ARTWORK", nil, 2) }
    for i = 1, LEADER.pen.most do
        local stroke = ink:CreateTexture(nil, "ARTWORK", nil, 1)
        if stroke.SetSnapToPixelGrid then
            stroke:SetSnapToPixelGrid(false)
            stroke:SetTexelSnappingBias(0)
        end
        stroke:Hide()
        link.strokes[i] = stroke
    end
    link.dot:Hide()
    view.link = link
    view.onZoom = function(_, scale)
        if link.mark then Aim(link, scale) end
    end

    -- Draws the plate for `pick` (ns.PersonPlate.For's) and the person's
    -- stats `s`; returns whether it is drawn (no pick, no plate).
    function view:DrawFor(pick, s, now)
        self.pick, link.mark, link.strip = pick, nil, nil
        for _, stroke in ipairs(link.strokes) do stroke:Hide() end
        link.dot:Hide()
        if not pick then
            self:Hide()
            return false
        end
        self:SetSlot(SLOT)
        local aw, ah = SLOT.w - 2 * SLOT.pad, SLOT.h - 2 * SLOT.pad
        local moments = PersonPlate.Moments(pick, s)
        self.moments = moments
        self:Draw(Road(pick.road, pick.mapID), nil, Plate.Window(pick.mapID, pick.x, pick.y, aw, ah),
            { moments = moments, cap = Plate.Share(SLOT), fights = {}, witnesses = {}, now = now })
        self:Show()
        return true
    end

    -- The meeting's mark on the block, where the print shows it, or nil.
    function view:MetMark()
        for _, m in ipairs(self.moments or {}) do
            if m.met and self.where and self.where[m] then return self.where[m] end
        end
        return nil
    end

    -- The leader from `strip` to the meeting's mark; none without one.
    function view:Lead(strip)
        local mark = strip and self:MetMark()
        link.mark, link.strip = mark, strip
        if mark then Aim(link, self.scale or 1) end
        return mark ~= nil
    end

    return view
end
