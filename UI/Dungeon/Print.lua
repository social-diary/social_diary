-- Adapted from Dungeon Crawler Forever 0.1.11 (Per, GPL-3.0-or-later): a
-- route's stops taken from their bosses and its runs broken where a point
-- leaves the floor shown (UI/Route.lua's followBosses and RenderRoute),
-- changed 2026-10-16: drawn with our own pen, in ink and pencil.
--
-- What happened on a run, printed over its floor on the map sheet of the
-- table spread (MAP-1 to MAP-4, MAP-7, MAP-14; UI/Dungeon/Sheet.lua), never
-- a guide:
--   the way     the usual way through (ns.Dungeons.Route, the author's, not
--               the user's: there are no coordinates inside), inked as far
--               as the furthest boss killed, the rest in pencil (ROUTE);
--               or the way the user drew on the run (visit.route, §19,
--               ns.Dungeons.WayOf), inked in full: it is where they went
--   the door    where the way in is, a doorway's arch (the plates' DOOR)
--   bosses      each its own face, round (Style.BossMedallion, MEDAL):
--               killed in brass, numbered in the order they fell (a kill
--               only its loot told of, unnumbered); a rare
--               (only when killed) in silver; still standing greyed and
--               faded in a ring of pencil; trash never. A boss with no face
--               to show: a red lozenge inked round for a kill (KILL), a
--               faint pencil ring for one standing (STANDING)
--   deaths      small crosses (MAP-14, DEATH): in ink round the boss they
--               died at; in pencil on the way between two bosses, where
--               the time says (approximate, and it says so); without a
--               way through, by the boss, else at the map's foot
-- Each mark has a tooltip; there is no key (the plates' Decision 7).
--
-- In two steps, both in the sheet's own coordinates (x right, y down from
-- its top left): Plan works out where everything goes and draws nothing,
-- so the sheet can keep its folds clear of the faces and the numbers
-- before it is laid; Ink then prints it through the sheet's placer (its
-- toolkit, UI/Paper/Sheet.lua), so every mark turns, folds and takes the
-- light with the paper. Drawn once as the sheet opens or a floor is
-- chosen, from pools; nothing per frame, nothing random: seeded by the
-- visit, so it lies the same way every time.

local addonName, ns = ...

local Style = ns.Style

local DungeonPage = {}
ns.UI.DungeonPage = DungeonPage

-- A boss killed with no face to show: on a dot of the sheet's stock
-- (`halo` across, at `haloAlpha`), a lozenge of ink `edge` px with a red
-- one `fill` px in it, the card's boss marks (Style.Pips) at map size.
-- Every kill's number in the order they fell, `size` pt, on a dot of stock
-- `halo` across (where: APART.spots).
local KILL = { halo = 15, haloAlpha = 0.75, edge = 10, fill = 6.5,
    number = { size = 10, halo = 11 } }
-- A boss still standing: a faint ring in chalk (CHALK) drawn by hand, `radius` px,
-- in `strokes` pieces `width` wide at `alpha`, a little uneven (`wobble`)
-- and over its start by `overshoot` of a turn; on a fainter dot of stock.
local STANDING = { radius = 5.5, strokes = 16, width = 1.1, alpha = 0.72, wobble = 0.07, overshoot = 0.1,
    halo = 15, haloAlpha = 0.38 }
-- The way through: resampled every `step` px after `smooth` rounds of
-- corner cutting. Inked as far as you went (`ink`: the pen's nib on a
-- line `width` wide at `alpha`), the rest in chalk (`pencil`, even, over
-- its faint dark stroke: CHALK). At most `budget` pieces in all.
local ROUTE = { step = 4, smooth = 2, budget = 700,
    ink = { width = 2.2, alpha = 0.82 }, pencil = { width = 1.2, alpha = 0.7 } }
-- A boss's face: `kill` px across for a kill (a rare's too), `standing`
-- for one still standing, smaller, as it is only pencil.
local MEDAL = { kill = 24, standing = 20 }
-- The square over each mark that takes the mouse.
local HOVER = 22
-- A death: a small cross, the plates' (UI/Journey/Plate.lua's death
-- shape: a stem `stem` = { w, h } and a bar `bar` `up` px up), on a dot of
-- stock `halo` across. At a boss in ink, `ring` px out from the edge of
-- its mark, from `start` degrees (y down: the left, clear of its number
-- at the upper right) `step` degrees apart, at most `most`; on the way in
-- pencil at `pencil`. Its tooltip takes a square `hit` px. Where nothing
-- places them, a row `gap` px apart (by default `foot` px under the art).
local DEATH = { stem = { 1.6, 7 }, bar = { 5, 1.6 }, up = 1.5, halo = 10, haloAlpha = 0.8, ring = 6,
    start = 195, step = 30, most = 6, pencil = 0.9, hit = 10, gap = 9, foot = 12 }
-- Marks never touch (the plates' rule, 9 Oct: side by side they read as
-- letters): each keeps `clear` px from those placed before it, the kills
-- first, moving out to the first free place on rings `step` px apart
-- (`tries` rings of eight headings), with a pencil tether (`tether`:
-- width, alpha) back to where the boss stands. A kill's number takes the
-- first of `spots` round its mark `gap` px clear of every mark and number.
-- Marks keep `inset` px inside the art.
-- Chalk: what is drawn lightly on the map, where pencil grey would be lost
-- on the dark art (16 Oct, in the client: the leaders could not be seen at
-- all): a pale cream, about the strips' own paper (UI/Paper/Strip.lua's
-- STRIP.paper), so a leader reads as its strip's; under it, where it must
-- read on the lighter art too, a faint dark stroke `under.offset` px down
-- and to the right at `under.alpha`. The way still to go (ROUTE.pencil),
-- a mark's tether, a standing boss's ring without a face, and the margin
-- notes' leaders (UI/Dungeon/Notes.lua) are chalk; the way gone (ink) and
-- the crosses, each on its dot of paper, stay as they were.
local CHALK = { colour = { 0.93, 0.89, 0.76 }, under = { offset = 0.9, alpha = 0.32 } }
-- The run's moments in the hand (flavour pass A): the bigger the moment,
-- the more the hand shows. In order of what gives way to what, when two
-- would clash (the lesser drawn smaller or moved off): a good drop for you
-- (LOOT), a wipe's scribble (SCRIBBLE), the pen at rest where the group
-- stayed long (REST), the blood where people died (SPLAT), a level-up's
-- star (LEVEL).
--   LOOT      round a boss's face, for the best drop there for you: a rare
--             (blue) one ink loop by hand, `pad` px out from the face,
--             over its start by `overshoot` of a turn, uneven by `wobble`;
--             an epic two heavier loops `apart` px apart and a small inked
--             star `star.out` px out. In `steps` pieces a turn
--   SCRIBBLE  beside a face (or a wipe's place on the way), `out` px from
--             its edge: an angry scribble, `size` px, of `strokes`
--             scratches and `more` for each wipe past the first (at most
--             `most` counted), pressed (`width`, `alpha`) and struck through;
--             a near wipe's lighter and nervous, a wavering line `wave` px
--             high, `near`. In chalk, over its faint dark stroke (CHALK)
--   REST      the share of the run's time inside spent at one boss (first
--             pull to kill, Core/DungeonRun.lua's `share`): from `circle`
--             the pen went round it once, wrinkled (`wiggles` a turn,
--             `wobble`), `pad` px out from the face; from `knot` it went
--             round and round, `loops` overlapping loops `swing` px across.
--             The route's own ink, under the face
--   SPLAT     dried blood under each death spot's crosses (the witness
--             card's, Features/Witnesses/Card.lua: InkBlot in a brown red):
--             crosses within `cluster` px one spot; its pool `drops` drops
--             and `per` more for each death, `spread` px and `grow` more
--             each; InkBlot's `levels`, `ink`, `rim`, `step`, `warp`, `cap`
--   LEVEL     a level-up on the way it happened: a five-point star in ink,
--             `size` px, on a dot of paper `halo` across, the new level
--             scrawled `text.dx`, `text.dy` px off it, `text.size` pt in the
--             hand, in chalk
local LOOT = { pad = 4, overshoot = 0.14, wobble = 0.05, steps = 30,
    rare = { width = 1.5, alpha = 0.9, loops = 1 }, epic = { width = 2.1, alpha = 0.95, loops = 2, apart = 3.5 },
    star = { size = 9, out = 8, width = 1.3 } }
local SCRIBBLE = { out = 12, size = { 16, 10 }, strokes = 6, more = 4, most = 3, width = 1.2, alpha = 0.8, press = 0.3,
    near = { width = 0.9, alpha = 0.55, wave = 2.2, passes = 2 } }
local REST = { circle = 0.15, knot = 0.30, pad = 5, wiggles = 9, wobble = 0.09, loops = 3, swing = 3.5, width = 1.7,
    alpha = 0.82 }
local SPLAT = { cluster = 18, drops = 5, per = 3, spread = 2.5, grow = 1.4,
    levels = { { sigma = 2.0, edge = 0.22, from = 0, full = 1 }, { sigma = 1.8, edge = 0.55, from = 0.8, full = 1 } },
    ink = { { 0.42, 0.11, 0.06, 0.62 }, { 0.30, 0.065, 0.04, 0.55 } }, rim = 0.8, rimInk = { 0.25, 0.05, 0.03, 0.5 },
    step = 0.8, warp = { 0.6, 8 }, cap = 360 }
local LEVEL = { size = 9, halo = 13, haloAlpha = 0.8, width = 1.2, text = { size = 14, dx = 10, dy = -6 } }
local APART = { clear = 25, step = 9, tries = 3, tether = { 1, 0.7 }, gap = 12, inset = 6,
    spots = { { 13, -11 }, { -13, -11 }, { 13, 11 }, { -13, 11 }, { 0, -16 }, { 0, 16 }, { 16, 0 }, { -16, 0 } } }

DungeonPage.KILL, DungeonPage.STANDING, DungeonPage.ROUTE = KILL, STANDING, ROUTE
DungeonPage.APART, DungeonPage.MEDAL, DungeonPage.DEATH, DungeonPage.HOVER = APART, MEDAL, DEATH, HOVER
DungeonPage.CHALK = CHALK
DungeonPage.LOOT, DungeonPage.SCRIBBLE, DungeonPage.REST, DungeonPage.SPLAT, DungeonPage.LEVEL =
    LOOT, SCRIBBLE, REST, SPLAT, LEVEL

-- What the pen at rest draws for a boss the group spent `share` of the
-- run's time inside at (REST): "knot", "circle" or nil.
function DungeonPage.Rest(share)
    if not share then return nil end
    if share >= REST.knot then return "knot" end
    if share >= REST.circle then return "circle" end
    return nil
end

--------------------------------------------------------------------------
-- What is drawn
--------------------------------------------------------------------------

-- The wing a visit was to: its own, else its first kill's (INS-27). The
-- kills by the data's records (ns.Dungeons.Killed): the client may name a
-- boss otherwise ("Infurnus" for the data's Magmatus), its id agrees.
function DungeonPage.Wing(visit)
    if visit.wing then return visit.wing end
    local first = ns.Dungeons.Killed(visit)[1]
    return first and ns.Dungeons.WingOf(visit.instanceID, first.name) or nil
end

-- The face a dungeon's medallion wears where the client has no picture of
-- it (a Forever dungeon): its last boss's, the one the run is for, as
-- { display, portrait } for Style.Medallion; nil for a dungeon the diary
-- does not know.
function DungeonPage.Face(visit)
    local D = ns.Dungeons
    local bosses = D.Bosses(visit.instanceID, visit.difficultyID, DungeonPage.Wing(visit))
    for i = #bosses, 1, -1 do
        local b = bosses[i]
        if D.Counts(visit.instanceID, b) and (b.display or b.portrait) then
            return { display = b.display, portrait = b.portrait }
        end
    end
end

-- When each boss fell, by the data's name for it (ns.Dungeons.Norm): its
-- place among the kills, in the run's notes' order (by when they fell)
-- where given, else ns.Dungeons.Killed's. Never matched by the client's
-- names, which may differ from the data's.
local function KilledAt(visit, notes)
    local at, n = {}, 0
    local Norm = ns.Dungeons.Norm
    if notes then
        for _, e in ipairs(notes.bosses or {}) do
            if e.killed then
                n = n + 1
                at[Norm(e.boss.name)] = at[Norm(e.boss.name)] or n
            end
        end
        return at
    end
    for i, b in ipairs(ns.Dungeons.Killed(visit)) do
        at[Norm(b.name)] = at[Norm(b.name)] or i
    end
    return at
end

-- The name the game gave each boss where it is not the data's ("Infurnus"
-- for Magmatus): what the map calls it. By the data's name.
function DungeonPage.Names(notes)
    local names = {}
    for _, e in ipairs(notes and notes.bosses or {}) do
        if e.client then names[e.boss.name] = e.client end
    end
    return names
end

-- The bosses to mark (MAP-2): every boss that stands somewhere, killed or
-- not, but a rare only when killed and never the trash. { boss, killed,
-- inferred, fell, order, rare }, in the dungeon's order. A kill only its
-- loot told of (MAP-16: visit.inferred, or the run's `notes`, which also
-- prove an older run's) is `inferred`: a kill, but unnumbered, as when it
-- fell is only a guess; `order` numbers the kills the diary saw, in the
-- order they fell, and `fell` sorts them all.
function DungeonPage.Marks(visit, wing, notes)
    local D = ns.Dungeons
    local at, out = KilledAt(visit, notes), {}
    local proven = {}
    for name in pairs(visit.inferred or {}) do proven[D.Norm(name)] = true end
    for _, e in ipairs(notes and notes.bosses or {}) do
        if e.inferred then proven[D.Norm(e.boss.name)] = true end
    end
    for i, b in ipairs(D.Bosses(visit.instanceID, visit.difficultyID, wing)) do
        if not b.trash and b.floor and b.x and b.y then
            local key = D.Norm(b.name)
            local seen, inferred = at[key], proven[key] or nil
            local rare = D.IsRare(visit.instanceID, b.name)
            if seen or inferred or not rare then
                out[#out + 1] = { boss = b, killed = (seen or inferred) ~= nil, inferred = inferred,
                    fell = seen or (inferred and 1000 + i) or nil, rare = rare }
            end
        end
    end
    local kills = {}
    for _, mark in ipairs(out) do
        if mark.killed and not mark.inferred then kills[#kills + 1] = mark end
    end
    table.sort(kills, function(a, b) return a.fell < b.fell end)
    for n, mark in ipairs(kills) do mark.order = n end
    return out
end

--------------------------------------------------------------------------
-- Where it goes (Plan)
--------------------------------------------------------------------------

-- The way through over the art: `At(floor, x, y)` places a point of any
-- floor on it, or nil. { route, own (the user drew it), pts (each { x, y },
-- or false off the floor shown), stops (a boss's name, ns.Dungeons.Norm,
-- to its point), reached (the furthest stop whose boss fell; the user's
-- own way all of it, WAY-14) }, or nil without a way through. A stop is
-- its boss: where the boss stands, the way meets it.
local function Path(visit, wing, At, notes)
    local D = ns.Dungeons
    local route, own = D.WayOf(visit, wing)
    if not route or #route < 2 then return nil end
    local at, pts, stops, reached = KilledAt(visit, notes), {}, {}, 0
    for i, p in ipairs(route) do
        local f, x, y = p.f, p.x, p.y
        local b = p.boss and D.Boss(visit.instanceID, p.boss)
        if b and b.floor and b.x then f, x, y = b.floor, b.x, b.y end
        local px, py = At(f, x, y)
        pts[i] = px and { px, py } or false
        if p.boss then
            local key = D.Norm(p.boss)
            stops[key] = stops[key] or i
            if at[key] then reached = i end
        end
    end
    if own then reached = #route end
    return { route = route, own = own, pts = pts, stops = stops, reached = reached }
end

-- The first free place for a mark near x, y (APART), inside the box.
local function Apart(x, y, placed, box)
    local function Free(px, py)
        for _, q in ipairs(placed) do
            if (q.x - px) ^ 2 + (q.y - py) ^ 2 < APART.clear ^ 2 then return false end
        end
        return true
    end
    local function Inside(px, py)
        return math.max(box[1], math.min(box[3], px)), math.max(box[2], math.min(box[4], py))
    end
    if Free(x, y) then return x, y end
    for ring = 1, APART.tries do
        for k = 0, 7 do
            local a = k * math.pi / 4
            local px, py = Inside(x + math.cos(a) * APART.step * ring, y + math.sin(a) * APART.step * ring)
            if Free(px, py) then return px, py end
        end
    end
    return x, y
end

-- Where a kill's number goes round its mark at x, y: the first of
-- APART.spots clear of the marks and the numbers already placed.
local function NumberAt(x, y, marks, numbers, box)
    local function Clear(px, py)
        if px < box[1] or px > box[3] or py < box[2] or py > box[4] then return false end
        for _, list in ipairs({ marks, numbers }) do
            for _, q in ipairs(list) do
                if (q.x - px) ^ 2 + (q.y - py) ^ 2 < APART.gap ^ 2 then return false end
            end
        end
        return true
    end
    for _, spot in ipairs(APART.spots) do
        if Clear(x + spot[1], y + spot[2]) then return x + spot[1], y + spot[2] end
    end
    return x + APART.spots[1][1], y + APART.spots[1][2]
end

-- Where everything on the run's map goes, nothing drawn: `spec` = { visit,
-- floor, wing, notes, route, box = { x, y, w, h } (the whole floor on the
-- sheet), At (DungeonMap.At for it), inside = { x0, y0, x1, y1 } (where
-- marks moved apart are kept; the box less APART.inset by default), foot
-- = { x, y } (where deaths that lie nowhere are tallied; under the box by
-- default) }. The plan: the spec's fields and path,
-- door ({ x, y }), marks (the kills first, in the order they fell, then
-- the rest, each { name, boss, killed, rare, inferred, order, x, y, at (where
-- the boss stands), number ({ x, y }, a kill the diary saw) }), names,
-- facts (by boss, for its tooltip), seed, and `spots`: the faces, the
-- numbers and the door as { x, y, r }, which the folds keep clear of.
function DungeonPage.Plan(spec)
    local visit, box, At = spec.visit, spec.box, spec.At
    local notes = spec.notes or { bosses = {}, legs = {}, wipes = {} }
    local plan = { visit = visit, floor = spec.floor, wing = spec.wing, box = box, At = At, notes = notes,
        hasNotes = spec.notes ~= nil, route = spec.route, names = DungeonPage.Names(notes) }
    plan.seed = (visit.id or 1) * 7.31 + (spec.floor and spec.floor.uiMapID or 0) * 0.013
    plan.path = Path(visit, spec.wing, At, spec.notes)

    -- The way in, then the bosses round it.
    local door = spec.floor and ns.Dungeons.Entrance(visit.instanceID, spec.floor.uiMapID)
    local dx, dy
    if door then dx, dy = At(spec.floor.uiMapID, door.x, door.y) end
    plan.door = dx and { x = dx, y = dy } or nil

    -- The kills first, in the order they fell, then the rest: each kept
    -- clear of those before it, tethered back where it moved.
    local list = DungeonPage.Marks(visit, spec.wing, notes)
    table.sort(list, function(a, b)
        if a.killed ~= b.killed then return a.killed end
        if a.killed then return a.fell < b.fell end
        return (a.boss.order or 0) < (b.boss.order or 0)
    end)
    local inset = APART.inset
    local inside = spec.inside or { box.x + inset, box.y + inset, box.x + box.w - inset, box.y + box.h - inset }
    plan.inside = inside
    plan.foot = spec.foot or { x = box.x + 10, y = box.y + box.h + DEATH.foot }
    local placed = plan.door and { { x = plan.door.x, y = plan.door.y } } or {}
    plan.marks = {}
    for _, mark in ipairs(list) do
        local b = mark.boss
        local x, y = At(b.floor, b.x, b.y)
        if x then
            local px, py = Apart(x, y, placed, inside)
            placed[#placed + 1] = { x = px, y = py }
            plan.marks[#plan.marks + 1] = { name = b.name, boss = b, killed = mark.killed, rare = mark.rare,
                inferred = mark.inferred, order = mark.order, x = px, y = py, at = { x, y } }
        end
    end
    -- Each number where it is clear of the marks and the numbers before it.
    local numbers = {}
    for _, mark in ipairs(plan.marks) do
        if mark.killed and mark.order then
            local nx, ny = NumberAt(mark.x, mark.y, placed, numbers, inside)
            numbers[#numbers + 1] = { x = nx, y = ny }
            mark.number = { x = nx, y = ny }
        end
    end

    -- What happened at each boss, for its tooltip.
    plan.facts = {}
    for _, e in ipairs(notes.bosses or {}) do plan.facts[e.boss.name] = DungeonPage.Words.Facts(visit, e) end

    -- What a fold must not run through: every face as big as a kill's, every
    -- number and the way in.
    plan.spots = {}
    for _, mark in ipairs(plan.marks) do
        plan.spots[#plan.spots + 1] = { x = mark.x, y = mark.y, r = MEDAL.kill / 2 }
        if mark.number then
            plan.spots[#plan.spots + 1] = { x = mark.number.x, y = mark.number.y, r = KILL.number.halo / 2 }
        end
    end
    if plan.door then plan.spots[#plan.spots + 1] = { x = plan.door.x, y = plan.door.y, r = KILL.halo / 2 } end
    return plan
end

--------------------------------------------------------------------------
-- Printing it (Ink)
--------------------------------------------------------------------------
--
-- The placer P is the sheet's (UI/Dungeon/Sheet.lua), in its coordinates:
--   P.Rect(pool, x, y, w, h, c, a, turn)     a rectangle of ink from its
--                                            top left, turned `turn` more
--   P.Dot(pool, x, y, size, c, a)            a round spot on its middle
--   P.Lozenge(pool, x, y, size, c, a)        a square on its point
--   P.Stroke(pool, x1, y1, x2, y2, w, c, a)  a straight stroke, or nil
--   P.Quad(pool, c, a, x1, y1, ... y4)       any four points, or nil where
--                                            corners cannot move
--   P.Face(pool, x, y, look, boss)           a boss's face (its medallion),
--                                            how it came, or nil
--   P.Text(pool, text, x, y)                 a line of text on its middle
--   P.Hit(pool, x, y, size, tip)             a square that takes the mouse
-- each lit by the facet it lies on; and P.pools, the pools by name: route,
-- tether, halo, ink, fill, crossHalo, cross, medal, sketch, numberHalo,
-- number, hit. `stock` is the paper's colour, for the dots under marks.

-- The way through (MAP-4) over the art, along `path` (Path): inked from
-- the start to the furthest stop whose boss fell, the rest in pencil;
-- broken where it leaves the floor or jumps (a linked stair, `pair`).
-- Returns how many pieces of each were drawn.
local function DrawRoute(P, path)
    local Pen = ns.UI.Pen
    local counts = { ink = 0, pencil = 0 }
    if not path then return counts end
    local route, pts, reached = path.route, path.pts, path.reached

    local budget = ROUTE.budget
    local pool = P.pools.route
    local function Draw(from, to, look, colour, nib, chalk)
        if to <= from or budget <= 0 then return 0 end
        local flatPts = {}
        for k = from, to do
            flatPts[#flatPts + 1] = pts[k][1]
            flatPts[#flatPts + 1] = pts[k][2]
        end
        local L = Pen.Resample(Pen.Chaikin(flatPts, ROUTE.smooth), ROUTE.step)
        if #L < 2 then return 0 end
        local M, n = Pen.Mitres(L), #L
        local function Half(k)
            if not nib then return look.width / 2 end
            local a, b = L[math.max(k - 1, 1)], L[math.min(k + 1, n)]
            return look.width / 2 * Pen.Nib(b.x - a.x, b.y - a.y)
        end
        local prims = {}
        Pen.Stroke(prims, 0, L, M, Half, function() return 0 end, function() return look.alpha end, colour, nil,
            budget)
        for _, q in ipairs(prims) do
            local c = { q.r, q.g, q.b }
            local w = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2) + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
            if chalk then
                local o, U = CHALK.under.offset, CHALK.under
                if not P.Quad(P.pools.routeUnder, Style.INK, U.alpha, q.x1 + o, q.y1 + o, q.x2 + o, q.y2 + o,
                    q.x3 + o, q.y3 + o, q.x4 + o, q.y4 + o) then
                    P.Stroke(P.pools.routeUnder, (q.x1 + q.x4) / 2 + o, (q.y1 + q.y4) / 2 + o, (q.x2 + q.x3) / 2 + o,
                        (q.y2 + q.y3) / 2 + o, w, Style.INK, U.alpha)
                end
            end
            if not P.Quad(pool, c, q.a, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                P.Stroke(pool, (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2, (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2, w, c, q.a)
            end
        end
        budget = budget - #prims
        return #prims
    end

    local i = 1
    while i <= #route do
        if not pts[i] then
            i = i + 1
        else
            local j = i
            while j < #route and pts[j + 1] and not route[j + 1].pair do j = j + 1 end
            local split = math.max(i, math.min(j, reached))
            counts.ink = counts.ink + Draw(i, split, ROUTE.ink, Style.INK, true)
            counts.pencil = counts.pencil + Draw(split, j, ROUTE.pencil, CHALK.colour, false, true)
            i = j + 1
        end
    end
    return counts
end

-- A boss killed with no face to show (KILL): a red lozenge inked round.
local function Killed(P, x, y, stock)
    local pools = P.pools
    P.Dot(pools.halo, x, y, KILL.halo, stock, KILL.haloAlpha)
    P.Lozenge(pools.ink, x, y, KILL.edge, Style.INK_STRONG, 1)
    P.Lozenge(pools.fill, x, y, KILL.fill, Style.RUBRIC, 1)
end

-- A kill's number in the order they fell, at nx, ny on a dot of stock.
local function Number(P, number, nx, ny, stock)
    P.Dot(P.pools.numberHalo, nx, ny, KILL.number.halo, stock, KILL.haloAlpha)
    P.Text(P.pools.number, tostring(number), nx, ny)
end

-- A boss still standing (STANDING): a ring in pencil, by hand.
local function Standing(P, x, y, seed, stock)
    local S = STANDING
    P.Dot(P.pools.halo, x, y, S.halo, stock, S.haloAlpha)
    local a0 = Style.Noise(seed) * 2 * math.pi
    local sweep = 2 * math.pi * (1 + S.overshoot)
    local px, py
    for i = 0, S.strokes do
        local t = a0 + sweep * i / S.strokes
        local grow = 1 + S.wobble * math.sin(3 * t + seed) + S.wobble * i / S.strokes
        local qx, qy = x + S.radius * grow * math.cos(t), y + S.radius * grow * math.sin(t)
        if px then P.Stroke(P.pools.ink, px, py, qx, qy, S.width, CHALK.colour, S.alpha) end
        px, py = qx, qy
    end
end

-- The way in: a doorway's arch, as on the plates (their DOOR, MARK.door).
local function Door(P, x, y, stock)
    local Plate = ns.UI.JourneyPlate
    local d, B, H = Plate.MARK.door, Plate.DOOR.body, Plate.DOOR.head
    P.Dot(P.pools.halo, x, y, KILL.halo, stock, KILL.haloAlpha)
    P.Rect(P.pools.ink, x - d * B.w / 2, y + d * B.y - d * B.h / 2, d * B.w, d * B.h, Style.INK_STRONG, 1)
    P.Dot(P.pools.ink, x, y + d * H.y, d * H.size, Style.INK_STRONG, 1)
end

-- A death's cross at x, y (DEATH): in ink, or in pencil where it is only
-- about there. Its tooltip says who died, to what, and where about.
local function Cross(plan, P, x, y, pencil, stock, tip)
    local pools, D = P.pools, DEATH
    local c, a = pencil and Style.GRAPHITE or Style.INK_STRONG, pencil and D.pencil or 1
    P.Dot(pools.crossHalo, x, y, D.halo, stock, D.haloAlpha)
    P.Rect(pools.cross, x - D.stem[1] / 2, y + 0.5 - D.stem[2] / 2, D.stem[1], D.stem[2], c, a)
    P.Rect(pools.cross, x - D.bar[1] / 2, y - D.up - D.bar[2] / 2, D.bar[1], D.bar[2], c, a)
    P.Hit(pools.hit, x, y, D.hit, tip)
    plan.crosses[#plan.crosses + 1] = { x = x, y = y, pencil = pencil or nil, tip = tip }
end

-- Where a death on the way lies (MAP-9): `frac` of the way along the
-- route from `after`'s stop (the way in without one) to `before`'s; just
-- past `after` with no `before`. nil where the way through does not say
-- (no route, a stop off this floor).
local function LegPoint(path, leg)
    if not path then return nil end
    local Norm = ns.Dungeons.Norm
    local i0 = leg.after and path.stops[Norm(leg.after.name)] or (not leg.after and 1) or nil
    local i1 = leg.before and path.stops[Norm(leg.before.name)]
    if not i0 then return nil end
    local pts = {}
    if i1 then
        local step = i1 >= i0 and 1 or -1
        for k = i0, i1, step do
            if path.pts[k] then pts[#pts + 1] = path.pts[k] end
        end
    else
        -- Just past it: a little way along the next leg.
        for k = i0, math.min(#path.pts, i0 + 3) do
            if path.pts[k] then pts[#pts + 1] = path.pts[k] end
        end
    end
    if #pts < 2 then return nil end
    local total, lengths = 0, {}
    for k = 2, #pts do
        lengths[k] = math.sqrt((pts[k][1] - pts[k - 1][1]) ^ 2 + (pts[k][2] - pts[k - 1][2]) ^ 2)
        total = total + lengths[k]
    end
    local want = i1 and total * math.max(0.05, math.min(0.95, leg.frac or 0.5)) or math.min(total, 16)
    for k = 2, #pts do
        if want <= lengths[k] or k == #pts then
            local t = lengths[k] > 0 and math.min(1, want / lengths[k]) or 0
            return pts[k - 1][1] + (pts[k][1] - pts[k - 1][1]) * t, pts[k - 1][2] + (pts[k][2] - pts[k - 1][2]) * t
        end
        want = want - lengths[k]
    end
end

DungeonPage.LegPoint = LegPoint

-- Where a moment at time `t` on the way lies on the map (a drop rolled for
-- that no boss's table holds: the rolls' strips, pass B): on the route
-- between the kills before and after it (Core/DungeonRun.lua's When), as a
-- death on the way is; without a route, by the boss before or after it;
-- else by the way in. { x, y, r }, or nil off this floor.
function DungeonPage.Anchor(plan, t)
    local leg = ns.DungeonRun.When(plan.visit, plan.notes, t)
    local x, y = LegPoint(plan.path, leg)
    if x then return { x = x, y = y, r = DEATH.halo / 2 } end
    local near = (leg.after and plan.targets[leg.after.name]) or (leg.before and plan.targets[leg.before.name])
    if near then
        return { x = near.x - (near.r + DEATH.ring) * 0.9, y = near.y + (near.r + DEATH.ring) * 0.9, r = DEATH.halo / 2 }
    end
    return plan.targets.door
end

-- The run's deaths (MAP-14), from its notes (ns.DungeonRun.Notes): in ink
-- round the boss they died at; in pencil on the way, by the boss before or
-- after where the way through does not say; at the map's foot where
-- nothing does.
local function Deaths(plan, P, stock)
    local W, D = DungeonPage.Words, DEATH
    local visit, notes, targets, At = plan.visit, plan.notes, plan.targets, plan.At
    local loose = {}
    local function Near(boss)
        local t = boss and targets[boss.name]
        if t then return t end
        if not (boss and boss.floor and boss.x) then return nil end
        local x, y = At(boss.floor, boss.x, boss.y)
        if x then return { x = x, y = y, r = 4 } end
    end
    for _, e in ipairs(notes.bosses or {}) do
        local t = #e.deaths > 0 and Near(e.boss)
        if t then
            -- Round its lower left, alternating out from `start`.
            for k, death in ipairs(e.deaths) do
                if k > D.most then break end
                local turn = math.floor(k / 2) * (k % 2 == 0 and 1 or -1)
                local a = math.rad(D.start + turn * D.step)
                local r = t.r + D.ring
                Cross(plan, P, t.x + math.cos(a) * r, t.y + math.sin(a) * r, false, stock,
                    Style.TipList(W.Death(visit, death)))
            end
        else
            for _, death in ipairs(e.deaths) do loose[#loose + 1] = death end
        end
    end
    for k, leg in ipairs(notes.legs or {}) do
        local tip = Style.TipList(W.Death(visit, leg.death), { W.Leg(leg, plan.names) })
        local x, y = LegPoint(plan.path, leg)
        if not x then
            local t = Near(leg.after) or Near(leg.before)
            if t then x, y = t.x - (t.r + D.ring) * 0.9, t.y + (t.r + D.ring) * 0.9 + k * 2 end
        end
        if x then Cross(plan, P, x, y, true, stock, tip) else loose[#loose + 1] = leg.death end
    end
    for _, death in ipairs(notes.unplaced and notes.unplaced.deaths or {}) do loose[#loose + 1] = death end
    -- Nowhere to put them: a tally along the map's foot.
    local fx, fy = plan.foot.x, plan.foot.y
    for k, death in ipairs(loose) do
        Cross(plan, P, fx + (k - 1) * D.gap, fy, true, stock, Style.TipList(W.Death(visit, death)))
    end
end

--------------------------------------------------------------------------
-- The moments in the hand (flavour pass A)
--------------------------------------------------------------------------

-- A line by hand through `pts` ({ x1, y1, x2, y2, ... } on the sheet),
-- `width` wide (with the pen's nib where `nib`), in colour c at alpha a,
-- from `pool`; with a faint dark stroke under it from `under` (chalk).
-- Rounded off `smooth` times. Returns how many pieces it took.
local function Hand(P, pool, pts, width, c, a, nib, under, smooth)
    local Pen = ns.UI.Pen
    local L = Pen.Resample(Pen.Chaikin(pts, smooth or 1), 2.5)
    if #L < 2 then return 0 end
    local M, n = Pen.Mitres(L), #L
    local function Half(k)
        if not nib then return width / 2 end
        local p, q = L[math.max(k - 1, 1)], L[math.min(k + 1, n)]
        return width / 2 * Pen.Nib(q.x - p.x, q.y - p.y)
    end
    local prims = {}
    Pen.Stroke(prims, 0, L, M, Half, function() return 0 end, function() return a end, c, nil, 600)
    local U = CHALK.under
    for _, q in ipairs(prims) do
        local layers = under and { { under, Style.INK, U.alpha, U.offset }, { pool, c, a, 0 } } or { { pool, c, a, 0 } }
        for _, l in ipairs(layers) do
            local o = l[4]
            if not P.Quad(l[1], l[2], l[3], q.x1 + o, q.y1 + o, q.x2 + o, q.y2 + o, q.x3 + o, q.y3 + o, q.x4 + o, q.y4 + o) then
                P.Stroke(l[1], (q.x1 + q.x4) / 2 + o, (q.y1 + q.y4) / 2 + o, (q.x2 + q.x3) / 2 + o, (q.y2 + q.y3) / 2 + o,
                    width, l[2], l[3])
            end
        end
    end
    return #prims
end
DungeonPage.Hand = Hand

-- A stream of numbers seeded by `key` (the same every time): U(a, b).
local function Stream(key)
    local rand = ns.UI.Pen.Random(ns.UI.Surface.Seed(key))
    return function(a, b) return a + (b - a) * rand() end
end

-- What is already drawn where, { x, y, r }: a new mark keeps clear of it.
local function Free(busy, x, y, r)
    for _, q in ipairs(busy) do
        if (q.x - x) ^ 2 + (q.y - y) ^ 2 < (q.r + r + 2) ^ 2 then return false end
    end
    return true
end

-- The first free place `d` px out from x, y at one of `angles` (degrees,
-- y down), or the first of them.
local function Beside(busy, x, y, d, r, angles)
    for _, deg in ipairs(angles) do
        local a = math.rad(deg)
        local px, py = x + math.cos(a) * d, y + math.sin(a) * d
        if Free(busy, px, py, r) then return px, py, true end
    end
    local a = math.rad(angles[1])
    return x + math.cos(a) * d, y + math.sin(a) * d, false
end

-- A loop by hand round x, y: `loops` turns from radius r, `apart` px out
-- each turn, uneven and over its start (LOOT).
local function Loop(x, y, r, loops, apart, U, wobble, wiggles)
    local pts = {}
    local a0, phase = U(0, 2 * math.pi), U(0, 6)
    local sweep = 2 * math.pi * (loops + LOOT.overshoot)
    local n = math.ceil(LOOT.steps * (loops + LOOT.overshoot))
    for i = 0, n do
        local t = sweep * i / n
        local grow = 1 + wobble * math.sin((wiggles or 3) * t + phase)
        local rr = (r + (apart or 0) * t / (2 * math.pi)) * grow
        pts[#pts + 1] = x + rr * math.cos(a0 + t)
        pts[#pts + 1] = y + rr * math.sin(a0 + t)
    end
    return pts
end

-- A small star in ink at x, y, `size` px: five points, drawn as a hand
-- draws one, round in one stroke.
local function Star(P, pool, x, y, size, width, U)
    local pts, a0 = {}, U(-0.3, 0.3) - math.pi / 2
    for k = 0, 5 do
        local a = a0 + k * 4 * math.pi / 5
        pts[#pts + 1] = x + size / 2 * math.cos(a)
        pts[#pts + 1] = y + size / 2 * math.sin(a)
    end
    Hand(P, pool, pts, width, Style.INK_STRONG, 1, false, nil, 0)
end

-- The best drop for you at each boss (LOOT): a loop round its face, an
-- epic's two and a star. `plan.lootTier` by boss name.
local function Circles(plan, P, busy)
    local pools = P.pools
    for _, mark in ipairs(plan.marks) do
        local tier = plan.lootTier and plan.lootTier[mark.name]
        local t = plan.targets[mark.name]
        if tier and t then
            local U = Stream(plan.visit.id .. ":loot:" .. mark.name)
            local L = LOOT[tier]
            local r = t.r + LOOT.pad
            Hand(P, pools.loot, Loop(t.x, t.y, r, L.loops, L.apart, U, LOOT.wobble), L.width, Style.INK_STRONG, L.alpha,
                true, nil, 1)
            local reach = r + (L.apart or 0) * L.loops + L.width
            plan.flavour[#plan.flavour + 1] = { kind = tier, x = t.x, y = t.y, r = reach }
            busy[#busy + 1] = { x = t.x, y = t.y, r = reach }
            if tier == "epic" then
                local S = LOOT.star
                local sx, sy = Beside(busy, t.x, t.y, reach + S.out, S.size / 2, { -135, -45, 135, 45, 180, 0 })
                Star(P, pools.loot, sx, sy, S.size, S.width, U)
                plan.flavour[#plan.flavour + 1] = { kind = "lootStar", x = sx, y = sy, r = S.size / 2 + 1 }
                busy[#busy + 1] = { x = sx, y = sy, r = S.size / 2 }
            end
        end
    end
end

-- A scribble at x, y (SCRIBBLE): angry for `wipes` wipes, or nervous for
-- a near wipe (`near`).
local function Scribble(P, x, y, wipes, near, U)
    local pools, S = P.pools, SCRIBBLE
    local w, h = S.size[1], S.size[2]
    if near then
        local N = S.near
        for pass = 1, N.passes do
            local pts = {}
            local y0 = y - h / 4 + (pass - 1) * h / 2
            for i = 0, 10 do
                local f = i / 10
                pts[#pts + 1] = x - w / 2 + w * f + U(-0.6, 0.6)
                pts[#pts + 1] = y0 + math.sin(f * 4 * math.pi + U(0, 1)) * N.wave + U(-0.5, 0.5)
            end
            Hand(P, pools.scribble, pts, N.width, CHALK.colour, N.alpha, false, pools.scribbleUnder, 0)
        end
        return
    end
    local n = math.min(wipes, S.most)
    local strokes = S.strokes + S.more * (n - 1)
    local pts = {}
    for i = 0, strokes do
        local f = i / strokes
        local side = (i % 2 == 0) and -1 or 1
        pts[#pts + 1] = x + side * w / 2 + U(-2, 2)
        pts[#pts + 1] = y - h / 2 + h * f + U(-1, 1)
    end
    local width, alpha = S.width + S.press * (n - 1), math.min(1, S.alpha + 0.08 * (n - 1))
    Hand(P, pools.scribble, pts, width, CHALK.colour, alpha, false, pools.scribbleUnder, 0)
    -- Struck through, hard.
    Hand(P, pools.scribble, { x - w / 2 - 2, y + h / 2 + U(-1, 1), x + w / 2 + 2, y - h / 2 + U(-1, 1) }, width + 0.4,
        CHALK.colour, alpha, false, pools.scribbleUnder, 0)
end

-- The wipes and near wipes (SCRIBBLE): beside each boss's face, never on
-- it; beside a wipe's place on the way.
local function Scribbles(plan, P, busy)
    local S = SCRIBBLE
    local r = math.max(S.size[1], S.size[2]) / 2
    local around = { 180, 160, 200, 140, 220, 90, -90, 0, 30, -30 }
    local function At(x, y, d, wipes, near, key)
        local px, py = Beside(busy, x, y, d, r, around)
        Scribble(P, px, py, wipes, near, Stream(plan.visit.id .. ":scribble:" .. key))
        plan.flavour[#plan.flavour + 1] = { kind = near and "near" or "wipe", x = px, y = py, r = r + 1, wipes = wipes }
        busy[#busy + 1] = { x = px, y = py, r = r }
    end
    for _, e in ipairs(plan.notes.bosses or {}) do
        local t = plan.targets[e.boss.name]
        if t and (e.wipes or 0) > 0 then At(t.x, t.y, t.r + S.out + r, e.wipes, false, e.boss.name) end
        if t and (e.near or 0) > 0 then At(t.x, t.y, t.r + S.out + r, 1, true, e.boss.name .. ":near") end
    end
    for i in ipairs(plan.notes.wipes or {}) do
        local t = plan.targets["wipe:" .. i]
        if t then At(t.x, t.y, t.r + r + 6, 1, false, "way" .. i) end
    end
    for i in ipairs(plan.notes.near or {}) do
        local t = plan.targets["near:" .. i]
        if t then At(t.x, t.y, t.r + r + 6, 1, true, "near" .. i) end
    end
end

-- The pen at rest (REST): where the group stayed long, the route's ink
-- goes round the spot the boss stands at, under its face; outside a
-- drop's loop where there is one.
local function Rests(plan, P, busy)
    local byName = {}
    for _, e in ipairs(plan.notes.bosses or {}) do byName[e.boss.name] = e end
    for _, mark in ipairs(plan.marks) do
        local e = byName[mark.name]
        local how = e and DungeonPage.Rest(e.share)
        local t = plan.targets[mark.name]
        if how and t and plan.route then
            local U = Stream(plan.visit.id .. ":rest:" .. mark.name)
            local x, y = mark.at[1], mark.at[2]
            local r = t.r + REST.pad
            local looped = plan.lootTier and plan.lootTier[mark.name]
            if looped then r = r + LOOT.pad + (LOOT[looped].apart or 0) * LOOT[looped].loops + 3 end
            local pts
            if how == "knot" then
                pts = {}
                local a0, turns = U(0, 2 * math.pi), REST.loops
                local n = LOOT.steps * turns
                for i = 0, n do
                    local tt = 2 * math.pi * turns * i / n
                    local rr = r + REST.swing * math.sin(tt * (turns + 0.5) / turns * 2.3 + U(0, 0.3))
                    pts[#pts + 1] = x + rr * math.cos(a0 + tt) + REST.swing * 0.6 * math.cos(tt * 2.7)
                    pts[#pts + 1] = y + rr * math.sin(a0 + tt) + REST.swing * 0.6 * math.sin(tt * 2.7)
                end
            else
                pts = Loop(x, y, r, 1, 0, U, REST.wobble, REST.wiggles)
            end
            Hand(P, P.pools.route, pts, REST.width, Style.INK, REST.alpha, true, nil, 1)
            local reach = r + REST.swing + REST.width
            plan.flavour[#plan.flavour + 1] = { kind = how, x = x, y = y, r = reach, name = mark.name }
            busy[#busy + 1] = { x = x, y = y, r = reach }
        end
    end
end

-- The blood (SPLAT): under each death spot's crosses, a stain the more
-- that died there the bigger, seeded by the run and the spot.
local function Splats(plan, P)
    local spots = {}
    for _, c in ipairs(plan.crosses) do
        local near
        for _, sp in ipairs(spots) do
            if (sp.x - c.x) ^ 2 + (sp.y - c.y) ^ 2 <= SPLAT.cluster ^ 2 then near = sp end
        end
        if near then
            near.n = near.n + 1
            near.x, near.y = near.x + (c.x - near.x) / near.n, near.y + (c.y - near.y) / near.n
        else
            spots[#spots + 1] = { x = c.x, y = c.y, n = 1 }
        end
    end
    local pools = P.pools
    for i, sp in ipairs(spots) do
        local U = Stream(plan.visit.id .. ":blood:" .. i)
        local points = {}
        local spread = SPLAT.spread + SPLAT.grow * sp.n
        for k = 1, SPLAT.drops + SPLAT.per * sp.n do
            local a, d = U(0, 2 * math.pi), (k == 1 and 0 or math.sqrt(U(0, 1))) * spread
            points[#points + 1] = { x = sp.x + d * math.cos(a), y = sp.y + d * math.sin(a), t = k == 1 and 1 or U(0.5, 1) }
        end
        -- And a few flung drops.
        for _ = 1, 2 + sp.n do
            local a, d = U(0, 2 * math.pi), spread + U(3, 8)
            points[#points + 1] = { x = sp.x + d * math.cos(a), y = sp.y + d * math.sin(a), t = U(0.26, 0.6) }
        end
        local reach = spread + 12
        local stain = ns.UI.InkBlot.Build(points, SPLAT.levels, { step = SPLAT.step,
            clip = { sp.x - reach, sp.y - reach, sp.x + reach, sp.y + reach }, rim = SPLAT.rim, warp = SPLAT.warp,
            cap = SPLAT.cap })
        for n, quads in ipairs(stain.levels) do
            local ink = SPLAT.ink[n]
            for _, q in ipairs(quads) do
                P.Quad(n == 1 and pools.blood or pools.bloodCore, ink, ink[4], q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8])
            end
        end
        for _, q in ipairs(stain.rim) do
            P.Quad(pools.bloodCore, SPLAT.rimInk, SPLAT.rimInk[4], q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8])
        end
        plan.flavour[#plan.flavour + 1] = { kind = "blood", x = sp.x, y = sp.y, r = spread + 4, n = sp.n }
    end
end

-- The level-ups (LEVEL): a star on the way where each happened, the new
-- level scrawled by it; moved off what is there, and drawn smaller where
-- nothing near is free.
local function Levels(plan, P, busy, stock)
    local pools, L = P.pools, LEVEL
    for i, up in ipairs(plan.notes.levels or {}) do
        local x, y = DungeonPage.LegPoint(plan.path, up)
        if not x then
            local t = (up.before and plan.targets[up.before.name]) or (up.after and plan.targets[up.after.name])
            if t then x, y = t.x + t.r + L.halo, t.y - t.r end
        end
        if x then
            local size = L.size
            if not Free(busy, x, y, L.halo / 2) then
                local px, py, free = Beside(busy, x, y, L.halo, L.halo / 2, { -90, 0, 180, 90, -45, -135, 45, 135 })
                x, y = px, py
                if not free then size = size * 0.7 end
            end
            local U = Stream(plan.visit.id .. ":level:" .. i)
            P.Dot(pools.halo, x, y, L.halo * size / L.size, stock, L.haloAlpha)
            Star(P, pools.loot, x, y, size, L.width, U)
            local tx, ty = x + L.text.dx, y + L.text.dy
            if not Free(busy, tx + 6, ty, 8) then tx = x - L.text.dx - 12 end
            local label = P.Text(pools.scrawl, DungeonPage.Words.LevelScrawl(up.level), tx + 6, ty)
            P.Hit(pools.hit, x, y, DungeonPage.HOVER, DungeonPage.Words.LevelTip(plan.visit, up))
            plan.flavour[#plan.flavour + 1] = { kind = "level", x = x, y = y, r = L.halo / 2 + 1, level = up.level,
                label = label, size = size }
            plan.flavour[#plan.flavour + 1] = { kind = "levelText", x = tx + 6, y = ty, r = 9 }
            busy[#busy + 1] = { x = x, y = y, r = L.halo / 2 }
        end
    end
end

-- The moments, in order of what gives way to what (the less important
-- drawn after, round what is there): the drops' loops, the wipes'
-- scribbles, the pen at rest, the blood (under the crosses, where they
-- are), the level-ups. Kept on the plan: plan.flavour ({ kind, x, y, r,
-- ... } each), which the margin notes keep clear of too.
local function Flavour(plan, P, stock)
    plan.flavour = {}
    local busy = {}
    for _, mark in ipairs(plan.marks) do
        local t = plan.targets[mark.name]
        if t then busy[#busy + 1] = { x = t.x, y = t.y, r = t.r } end
        if mark.number then busy[#busy + 1] = { x = mark.number.x, y = mark.number.y, r = KILL.number.halo / 2 } end
    end
    for _, c in ipairs(plan.crosses) do busy[#busy + 1] = { x = c.x, y = c.y, r = DEATH.halo / 2 } end
    if plan.door then busy[#busy + 1] = { x = plan.door.x, y = plan.door.y, r = KILL.halo / 2 } end
    Circles(plan, P, busy)
    Scribbles(plan, P, busy)
    Rests(plan, P, busy)
    Splats(plan, P)
    Levels(plan, P, busy, stock)
end

-- Prints `plan` (DungeonPage.Plan) through the placer P on paper of colour
-- `stock`. Begins and finishes P's pools. Kept on the plan for the tests
-- and the margin notes still to come (step 2): routeCounts, each mark's
-- `face` (how its portrait came, or nil), targets (each mark by boss name,
-- the door and each wipe on the way ("wipe:<n>"): { x, y, r } on the
-- sheet), crosses.
function DungeonPage.Ink(plan, P, stock)
    local pools = P.pools
    for _, pool in pairs(pools) do pool:Begin() end
    local W = DungeonPage.Words

    plan.routeCounts = plan.route and DrawRoute(P, plan.path) or { ink = 0, pencil = 0 }

    if plan.door then
        local d = plan.door
        Door(P, d.x, d.y, stock)
        -- And the runs back in, which a strip may have had no room for.
        local ranBack = plan.hasNotes and plan.notes.ranBack or 0
        P.Hit(pools.hit, d.x, d.y, HOVER, Style.TipList("The way in",
            ranBack > 0 and { W.RanBack(ranBack) .. " " .. W.GHOST } or nil))
    end

    plan.targets, plan.crosses = {}, {}
    for i, mark in ipairs(plan.marks) do
        if mark.x ~= mark.at[1] or mark.y ~= mark.at[2] then
            P.Stroke(pools.tether, mark.at[1], mark.at[2], mark.x, mark.y, APART.tether[1], CHALK.colour,
                APART.tether[2])
        end
        local lines
        if mark.killed then
            mark.face = P.Face(pools.medal, mark.x, mark.y, mark.rare and "rare" or "killed", mark.boss)
            if not mark.face then Killed(P, mark.x, mark.y, stock) end
            -- Numbered in the order they fell; a kill only its loot told
            -- of goes unnumbered, as when it fell is a guess.
            if mark.number then Number(P, mark.order, mark.number.x, mark.number.y, stock) end
            local killed = mark.inferred and "Killed on this run, going by its loot" or "Killed on this run"
            lines = mark.rare and { "Rare", killed } or { killed }
            plan.targets[mark.name] = { x = mark.x, y = mark.y, r = mark.face and MEDAL.kill / 2 or KILL.edge / 2 + 1 }
        else
            mark.face = P.Face(pools.sketch, mark.x, mark.y, "standing", mark.boss)
            if not mark.face then Standing(P, mark.x, mark.y, plan.seed + i * 1.7, stock) end
            lines = { "Not killed on this run" }
            plan.targets[mark.name] = { x = mark.x, y = mark.y,
                r = mark.face and MEDAL.standing / 2 or STANDING.radius + 1 }
        end
        for _, fact in ipairs(plan.facts[mark.name] or {}) do lines[#lines + 1] = fact end
        P.Hit(pools.hit, mark.x, mark.y, HOVER, Style.TipList(plan.names[mark.name] or mark.name, lines))
    end
    if plan.door then plan.targets.door = { x = plan.door.x, y = plan.door.y, r = 7 } end
    Deaths(plan, P, stock)
    -- Where each wipe on the way lies (MAP-17), for its strip's arrow (step
    -- 2): the leg point of its first death, else by the boss before or
    -- after it.
    for i, w in ipairs(plan.notes.wipes or {}) do
        local x, y = LegPoint(plan.path, w)
        if not x then
            local t = (w.after and plan.targets[w.after.name]) or (w.before and plan.targets[w.before.name])
            if t then x, y = t.x - (t.r + DEATH.ring) * 0.9, t.y + (t.r + DEATH.ring) * 0.9 end
        end
        if x then plan.targets["wipe:" .. i] = { x = x, y = y, r = DEATH.halo / 2 } end
    end
    -- And each near wipe on the way, the same way.
    for i, w in ipairs(plan.notes.near or {}) do
        local x, y = LegPoint(plan.path, w)
        if not x then
            local t = (w.after and plan.targets[w.after.name]) or (w.before and plan.targets[w.before.name])
            if t then x, y = t.x - (t.r + DEATH.ring) * 0.9, t.y + (t.r + DEATH.ring) * 0.9 end
        end
        if x then plan.targets["near:" .. i] = { x = x, y = y, r = DEATH.halo / 2 } end
    end

    -- The best drop for you at each boss, for its loop (LOOT).
    plan.lootTier = {}
    local me = plan.visit.me or ns.ownGUID
    for _, e in ipairs(plan.notes.bosses or {}) do
        local best = 0
        for _, entry in ipairs(e.loot or {}) do
            if entry.guid == me or entry.guid == ns.ownGUID then
                best = math.max(best, ns.Timeline.Quality(entry.item) or 0)
            end
        end
        plan.lootTier[e.boss.name] = best >= 4 and "epic" or best == 3 and "rare" or nil
    end
    -- An item that finally came to you keeps its boss's loop, or adds one
    -- (a big moment, whatever its colour).
    for _, g in ipairs(plan.notes.rolls and plan.notes.rolls.finally or {}) do
        if g.boss then
            local q = ns.Timeline.Quality(g.item) or 0
            local tier = plan.lootTier[g.boss.name]
            if q >= 4 then tier = "epic" elseif not tier then tier = "rare" end
            plan.lootTier[g.boss.name] = tier
        end
    end
    Flavour(plan, P, stock)

    for _, pool in pairs(pools) do pool:Finish() end
    return plan
end
