-- What the right page of Your Diary hands out, and the pencil from a note
-- to its mark (JRN-22): the page's three plates, given to the slots each
-- layout needs (PlateAt), its pools of font strings, textures and notes
-- (Handout), and a margin note's leader (LEADER): the one mark it goes to
-- (LeaderMark), drawn with the route's pen as a pencil (Pencil, Aim), kept
-- (page.links) and aimed again as its plate leans in (Follow).
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Style = ns.Style
local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary

local LAYOUT, LEADER = YourDiary.LAYOUT, YourDiary.LEADER

-- What follows a plate as it leans in (its leaders), below.
local Follow

local function PlateAt(i)
    local page = YourDiary.page
    local plate = page.plates[i]
    if not plate then
        plate = Plate(page.right, LAYOUT[1][1])
        plate.onZoom = function(p, scale) Follow(p, scale) end
        -- A right click on a plate of this page, a close-up's or a full
        -- page's alike: UI/Journey/CardSheet.lua, which loads later.
        plate.onRight = function(p, spot) YourDiary.CardSheet.Right(p, spot) end
        page.plates[i] = plate
    end
    return plate
end

-- Font strings, textures and notes on the right page, handed out in turn
-- and the rest hidden after a drawing, like the plates' own pools: a pool
-- (UI/Kit/Pool.lua) of what `make()` returns.
local Handout = ns.UI.Pool.New

-- One straight stroke from x1, y1 to x2, y2, `width` wide, turned: a
-- leader's piece where corners cannot move.
local function Stroke(stroke, x1, y1, x2, y2, width)
    local page = YourDiary.page
    if not stroke.SetRotation then
        stroke:Hide()
        return
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    stroke:ClearAllPoints()
    stroke:SetSize(length + 0.5, width)
    stroke:SetPoint("CENTER", page.right, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    stroke:SetRotation(math.atan2(-dy, dx))
    stroke:Show()
end

-- A leader along `points` (x, y, x, y, ...: its curve on the right page,
-- from the strip to the mark), with the route's pen as a pencil
-- (LEADER.pen): resampled, mitred, each vertex's width its nib's share of
-- `width`, tapered off the strip, and stroked into flat quads, one texture
-- each from the link's; the rest hidden. Returns how many were drawn.
local function Pencil(link, points)
    local page = YourDiary.page
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
            if Style.Quad(stroke, page.right, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                stroke:Show()
            else
                -- From the middle of its start to the middle of its end.
                local w = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
                    + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
                Stroke(stroke, (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2, (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2, w)
            end
        else
            stroke:Hide()
        end
    end
    link.prims, link.drawn = prims, math.min(#prims, #link.strokes)
    return link.drawn
end

local function HideLeader(link)
    for _, stroke in ipairs(link.strokes) do stroke:Hide() end
    link.drawn = 0
    link.dot:Hide()
end

-- Not the pen's Clamp (UI/Ink/Pen.lua): where `lo` passes `hi` (a plate
-- narrower than twice LEADER.inset) this one gives `lo`, the pen's `hi` or
-- `lo` by `v`. Kept as it is, so no leader moves.
local function Clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- A leader aimed at its mark as the plate shows it now: leaning in
-- (ZOOM, UI/Journey/Plate.lua), the picture grows about the card's middle,
-- and the mark with it. From the edge of its strip nearest the mark, onto
-- the plate over its edge nearest the strip, bowing a little, to a pencil
-- dot a little short of the mark (LEADER); none while the mark is out of
-- the plate's window. Worked in the card's own frame, through its turn
-- (none laid flat), so "the nearest edge" is the card's.
local function Aim(link, scale)
    local page = YourDiary.page
    local s, mark = link.plate.slot, link.mark
    local cx, cy = s.x + s.w / 2, s.y + s.h / 2
    local mx, my = cx + (mark[1] - cx) * scale, cy + (mark[2] - cy) * scale
    if math.abs(mx - cx) > s.w / 2 - s.pad or math.abs(my - cy) > s.h / 2 - s.pad then
        HideLeader(link)
        return
    end
    local sx, sy = link.strip:Nearest(mx, my)
    local a = ns.Setting("flatSheets") == true and 0 or math.rad(s.t or 0)
    local cos, sin = math.cos(a), math.sin(a)
    local function Card(x, y)
        local dx, dy = x - cx, y - cy
        return dx * cos + dy * sin, -dx * sin + dy * cos
    end
    local function OnPage(u, v)
        return cx + u * cos - v * sin, cy + u * sin + v * cos
    end

    -- Where it comes onto the plate.
    local su, sv = Card(sx, sy)
    local mu, mv = Card(mx, my)
    local hw, hh, inset = s.w / 2, s.h / 2, LEADER.inset
    local outU, outV = math.abs(su) - hw, math.abs(sv) - hh
    local eu, ev
    if outU <= 0 and outV <= 0 then
        eu, ev = (su + mu) / 2, (sv + mv) / 2
    elseif outU >= outV then
        eu = su < 0 and -hw or hw
        ev = Clamp(mv + (sv - mv) * LEADER.lean, -hh + inset, hh - inset)
    else
        ev = sv < 0 and -hh or hh
        eu = Clamp(mu + (su - mu) * LEADER.lean, -hw + inset, hw - inset)
    end
    local ex, ey = OnPage(eu, ev)

    -- Where it ends: short of the mark, along the way it comes in.
    local dx, dy = mx - ex, my - ey
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= LEADER.stop then
        ex, ey = (sx + mx) / 2, (sy + my) / 2
        dx, dy = mx - sx, my - sy
        d = math.sqrt(dx * dx + dy * dy)
    end
    if d <= LEADER.stop then
        HideLeader(link)
        return
    end
    local tx, ty = mx - dx / d * LEADER.stop, my - dy / d * LEADER.stop
    local lx, ly = tx - sx, ty - sy
    local length = math.sqrt(lx * lx + ly * ly)
    if length < 1 then
        HideLeader(link)
        return
    end

    -- The bow: the curve bends toward the way in, pushed a little toward
    -- the page's foot, across the line from the strip to the end.
    local nx, ny = -ly / length, lx / length
    if ny < 0 then nx, ny = -nx, -ny end
    local kx, ky = ex + nx * LEADER.bow * length, ey + ny * LEADER.bow * length
    -- The curve, finely enough for the pen to resample (LEADER.pen.curve
    -- points).
    local steps = LEADER.pen.curve
    local points = { sx, sy }
    for i = 1, steps do
        local t = i / steps
        local u = 1 - t
        points[#points + 1] = u * u * sx + 2 * u * t * kx + t * t * tx
        points[#points + 1] = u * u * sy + 2 * u * t * ky + t * t * ty
    end
    link.points = points
    Pencil(link, points)
    local dot, C = link.dot, LEADER.colour
    Style.Disc(dot, C[1], C[2], C[3], LEADER.dotAlpha)
    dot:ClearAllPoints()
    dot:SetSize(LEADER.dot, LEADER.dot)
    dot:SetPoint("CENTER", page.right, "TOPLEFT", tx, -ty)
    dot:Show()
end

function Follow(plate, scale)
    local page = YourDiary.page
    for _, link in ipairs(page.links or {}) do
        if link.plate == plate then Aim(link, scale) end
    end
end

-- The one mark a strip's leader goes to (10 Oct, in the client: a leader
-- to each of a person's marks drew long pencil lines across the plate):
-- the mark of their likeliest to matter (the plate's PRIORITY: a fight,
-- then time together, a note, a first sighting, then a feature's moment
-- joined to theirs), and of
-- those the nearest the strip, so the line crosses as little of the map
-- as it can. A strip that quotes a note leads to where it was written,
-- whatever else they did there: the words under the name say what the
-- mark is (12 Oct, in the client: the quote was written in the south, the
-- leader went north to the time together).
local function LeaderMark(g, strip, plate)
    local quoted = Text.MarginQuoted(g.moments)
    if quoted and plate.where[quoted] then return plate.where[quoted] end
    local P = Plate.PRIORITY
    local best, rank, gap
    for _, m in ipairs(g.moments) do
        local at = plate.where[m]
        if at then
            local r = P[m.kind] or math.huge
            local sx, sy = strip:Nearest(at[1], at[2])
            local d = (sx - at[1]) ^ 2 + (sy - at[2]) ^ 2
            if not best or r < rank or (r == rank and d < gap) then best, rank, gap = at, r, d end
        end
    end
    return best
end

-- A strip's leader, to its one mark on `plate` (LeaderMark), kept
-- (page.links) so it follows the plate as it leans in.
local function Leader(strip, mark, plate)
    local page = YourDiary.page
    if not mark then return end
    local strokes = {}
    for i = 1, LEADER.pen.most do strokes[i] = page.leaderPool:Next() end
    local link = { strokes = strokes, dot = page.dotPool:Next(), strip = strip, mark = mark, plate = plate }
    page.links[#page.links + 1] = link
    Aim(link, plate.scale or 1)
end

YourDiary.PlateAt, YourDiary.Handout, YourDiary.LeaderMark, YourDiary.Leader = PlateAt, Handout, LeaderMark, Leader
