-- A city trip's sheet: the round in town written on a leaf glued among
-- Your Diary's plates (the signed design, variant B at full width:
-- .claude/ui-proposal/city-trips.md, "Round 2", and the dossier's
-- sign-off, .claude/features/city-trips.md). The leaf is the core's (UI/
-- Paper/Leaf.lua, 444 by 240, written in two columns, its toolkit the
-- only way onto it); the pen marks UI/Ink/Scribble.lua's; the small
-- drawings UI/Ink/Sketch.lua's hand. The words are Text.lua's.
--
-- What is on it:
--   - the heading: the city and the day, the city underlined by the pen,
--     how long the stay was in graphite at the row's end (left off where
--     the two would meet);
--   - the round, stop by stop (Text.lua's STOPS: the post, the auction
--     house, the workbench, what was put on, the quest-givers, the people
--     round the trip, the purse), down the left column and on into the right, a small
--     drawing opening each stop, a pen thread joining them down each
--     column (never across from one to the other: Thread); a stop may
--     break across the columns (the user, 24 Nov), a line never does;
--   - the purse last, right after the last errand (the user's "purse sits
--     last"): the sum you came with struck, the sum you left with ringed;
--   - people the diary knows are names: strong ink, underlined, a button
--     to their page (c.ToPerson) with their name's tooltip, and a stop for
--     the pad (leaf:Name). Your own characters are plain ink. Strangers
--     are counted, never named. No faces (the user: "No player icons").
--   - folded only where needed (the user: "fold many interactions into
--     one, but only if needed"): every line is laid as it is first; only
--     while the leaf would overflow is the next step of the copy's §14
--     taken (FOLDS), and the lines laid again. A counted line keeps its
--     tooltip, every line it merged in full (Style.TipList), and is a
--     stop for the pad (tooltip only, no A).
-- Flat paper lays it plain (the leaf's own: no turn, tear or lifted
-- corner); the pen draws flat strokes there (Scribble.Draw's Flat).

local addonName, ns = ...

local CityTrips = ns.CityTrips
local Style = ns.Style
local Scribble, Sketch = ns.UI.Scribble, ns.UI.Sketch
local FONT = Style.FONT

--------------------------------------------------------------------------
-- The look
--------------------------------------------------------------------------

-- Where things go on the leaf, x right and y down from its top left (the
-- mockup's variant B, round 2, at A's 444 by 240):
--   heading  the heading's middle at x, y, in the hand at 16 (noteWritten);
--            `under` px from its middle to the city's baseline; the stay at
--            `right` px from the leaf's right edge, kept `apart` px from the
--            heading (else left off: §1, the ticklist row still says it)
--   top      the first row's top, both halves
--   lead     a row's height (the 14 px hand)
--   gap      between two stops
--   width    a line's width in each half: 168 px, about 28 characters at
--            the 14 px hand (the copy's §0)
--   cols     each half: X its thread and drawings, tx its lines
--   foot     the lowest a row may reach, both halves
--   drawing  a stop's drawing, `size` px across, its middle `down` px
--            under its stop's top; it holds `room` px of the thread
--   cross    the pen's cross on the thread at a line of lots come back,
--            radius `r`, its middle `down` px under the line's top
--   base     from a row's middle to its baseline (the underline's)
--   space    a word's gap, when it cannot be measured
--   ring     round the sum you left with: `x` px past its ends, `y` px
--            radius up and down
local SHEET = {
    heading = { x = 14, y = 18, under = 5, right = 16, apart = 14 },
    top = 40, lead = 17, gap = 7, width = 168,
    cols = { { X = 21, tx = 40 }, { X = 243, tx = 262 } },
    foot = 228,
    drawing = { size = 16, down = 9, room = { -1, 19 } },
    cross = { r = 4, down = 8.5, room = { 3, 14 } },
    base = 4, space = 4,
    ring = { x = 7, y = 9.5 },
}
CityTrips.SHEET = SHEET

-- The inks (the proposal's decision 6): the hand in ink for what happened,
-- names in strong ink, graphite for what the diary worked out (how long,
-- "and five other things"), printed Friz 11 for a craft's ranks only.
local INK = {
    line = FONT.noteQuoted,
    tail = FONT.pencilHandSmall,
    rank = FONT.small,
    heading = FONT.noteWritten,
    stay = FONT.pencilHandSmall,
}

-- The steps the copy's §14 gives way in, first to go first. Each is taken
-- only while the leaf would still overflow (Plan), and each is one key of
-- Text.lua's `folds`:
--   recipesFold, recipesDrop   C3 to C4, then gone
--   takenFold, takenDrop       Q3 into the handed-in line as Q6, then gone
--   emptyLetters, emptyStrangers   M1 and M8, then M4 and M10
--   sentOwn                    letters sent fold to F4 (+ F5)
--   whispers, strangers, peopleFold   the people's line: whispers, then
--                              the strangers' counts, then "With …"
--   boughtFold, upFold, madeFold, soldFold   kinds of item, each to one line
--   prices                     A9 to A10
--   wornFold                   things put on: the first (a gift's, where
--                              one names its giver) and a tail, the
--                              other gifts named kept (25 Nov 2026)
--   lettersFold                letters taken to F2 (+ F3)
--   wornJoin                   what was put on joins the stop before it
--                              (the auction house's, or the workbench's),
--                              no drawing and no gap of its own: on the
--                              heavy round at every cap, a thing put on
--                              cost a line otherwise (25 Nov 2026)
--   soldStrangers              the stranger count on a sale (A6)
--   questsFold                 Q4 (+ Q5, Q6)
local FOLDS = { "recipesFold", "recipesDrop", "takenFold", "takenDrop", "emptyLetters", "emptyStrangers",
    "sentOwn", "whispers", "strangers", "peopleFold", "boughtFold", "upFold", "madeFold", "soldFold", "prices",
    "wornFold", "lettersFold", "wornJoin", "soldStrangers", "questsFold" }
CityTrips.FOLDS = FOLDS

--------------------------------------------------------------------------
-- The drawings (Sketch, on the 16-unit square, as the free card's)
--------------------------------------------------------------------------

local pi = math.pi
local Ellipse = Sketch.Ellipse

-- A letter, its flap down and a spot of wax: the post.
Sketch.Register("cityTrips.letter", function(h)
    local box = { -7.0, -4.6, 7.0, -4.6, 7.0, 4.8, -7.0, 4.8 }
    h.Fill("ash", 0, 0.4, box, 10)
    h.Line(box, 1.0, true)
    h.Line({ -6.8, -4.3, 0, 1.0, 6.8, -4.3 }, 0.85)
    h.Bloom("brick", { { 0, 1.4, 1.2 } })
end)

-- A lot's tag, its eye and its string: the auction house.
Sketch.Register("cityTrips.tag", function(h)
    local tag = { -7.0, 0, -3.4, -4.4, 7.0, -4.4, 7.0, 4.4, -3.4, 4.4 }
    h.Fill("ochre", 1.2, 0, tag, 10)
    h.Line(tag, 1.0, true)
    h.Ring(-3.4, 0, 1.1, 1.1, 0, 2 * pi, 0.7)
    h.Line({ -4.4, -0.4, -6.2, -3.0, -7.6, -6.6 }, 0.6)
end)

-- A tunic hung up, its shoulders square and its sleeves out, a fold down
-- the front and a wash of slate: what was put on (25 Nov 2026). The plates'
-- own mark for an upgrade is a tunic too (Upgrades' tunic, solid ink in
-- the item's colour); this one is the sheet's: pen over a wash like its
-- neighbours, in a pigment no item quality has, so a sheet reads as one
-- hand and a quality is never hinted at by a stop's drawing.
Sketch.Register("cityTrips.tunic", function(h)
    local body = { -2.4, -6.0, -6.6, -4.4, -7.4, -0.6, -4.6, 0.2, -4.4, 6.4, 4.4, 6.4, 4.6, 0.2, 7.4, -0.6,
        6.6, -4.4, 2.4, -6.0, 0, -4.2 }
    h.Fill("slate", 0, 0.8, body, 10)
    h.Line(body, 1.0, true)
    h.Line({ 0, -4.0, 0.2, 5.6 }, 0.6)
    h.Line({ -4.5, 3.2, 4.5, 3.2 }, 0.55)
end)

-- A coin, its rim and a mark struck in it: the purse.
Sketch.Register("cityTrips.coin", function(h)
    h.Fill("amber", 0, 0, Ellipse(nil, 0, 0, 6.0, 6.0, 0, 2 * pi * 13 / 14, 13), 11)
    h.Ring(0, 0, 6.0, 6.0, 0, 2 * pi, 1.0)
    h.Ring(0, 0, 4.2, 4.2, 0.4, 2 * pi - 0.4, 0.5)
    h.Line({ -1.6, -1.8, 0, 1.8, 1.6, -1.8 }, 0.7)
end)

--------------------------------------------------------------------------
-- Measuring and splitting a line
--------------------------------------------------------------------------

-- A font string a leaf measures with, hidden, one a font.
local measures = setmetatable({}, { __mode = "k" })
local function Measure(leaf, font, text)
    local own = measures[leaf]
    if not own then
        own = {}
        measures[leaf] = own
    end
    local fs = own[font]
    if not fs then
        fs = Style.Text(leaf.sheet, font)
        fs:Hide()
        own[font] = fs
    end
    fs:SetText(text)
    return leaf.K.Width(fs)
end

local function Space(leaf, font)
    local w = Measure(leaf, font, "x x") - Measure(leaf, font, "xx")
    return w > 0 and w or SHEET.space
end

-- Whether s[i] is a letter or a digit (so a match there is inside a word).
local function Inside(s, i)
    if i < 1 or i > #s then return false end
    local c = s:sub(i, i)
    return c:match("[%w\128-\255]") ~= nil
end

-- `text` cut where its marks are (each found by a plain search, in the
-- order they were passed, a whole word preferred, never inside one found
-- before): { { text, mark }, ... } in reading order, the unmarked runs
-- with mark nil. A mark not found is left as ink.
local function Runs(text, marks)
    local taken = {}
    local function Free(a, b)
        for _, r in ipairs(taken) do
            if a <= r[2] and b >= r[1] then return false end
        end
        return true
    end
    for _, mark in ipairs(marks or {}) do
        local s = mark.s
        if s and s ~= "" then
            local best, init = nil, 1
            while true do
                local a, b = text:find(s, init, true)
                if not a then break end
                if Free(a, b) then
                    local whole = not Inside(text, a - 1) and not Inside(text, b + 1)
                    if whole then best = { a, b, mark } break end
                    best = best or { a, b, mark }
                end
                init = a + 1
            end
            if best then taken[#taken + 1] = best end
        end
    end
    table.sort(taken, function(x, y) return x[1] < y[1] end)
    local out, at = {}, 1
    for _, r in ipairs(taken) do
        if r[1] > at then out[#out + 1] = { text:sub(at, r[1] - 1) } end
        out[#out + 1] = { text:sub(r[1], r[2]), r[3] }
        at = r[2] + 1
    end
    if at <= #text then out[#out + 1] = { text:sub(at) } end
    return out
end
CityTrips.Runs = Runs

-- A mark's font: graphite for a tail, the line's hand for the rest.
local function FontOf(mark)
    if mark and mark.kind == "tail" then return INK.tail end
    return INK.line
end

-- A line as atoms: the words of its ink runs, each mark whole (a name, a
-- tail, a sum: never broken), each { text, w, font, mark, space (a space
-- before it) }; a rank line's name, figures and the arrow between.
local function Atoms(leaf, line)
    local atoms = {}
    if line.rank then
        local r = line.rank
        atoms[1] = { text = r.name, font = INK.line }
        atoms[2] = { text = tostring(r.from), font = INK.rank, space = true }
        atoms[3] = { arrow = true, w = 21, space = true }
        atoms[4] = { text = tostring(r.to), font = INK.rank, space = true }
    else
        local pending = false
        for _, run in ipairs(Runs(line.text, line.marks)) do
            local t, mark = run[1], run[2]
            if mark then
                atoms[#atoms + 1] = { text = t, font = FontOf(mark), mark = mark, space = pending }
                pending = false
            else
                local i = 1
                while i <= #t do
                    local a, b = t:find("^ +", i)
                    if a then
                        pending = true
                        i = b + 1
                    else
                        a, b = t:find("^[^ ]+", i)
                        atoms[#atoms + 1] = { text = t:sub(a, b), font = INK.line, space = pending }
                        pending = false
                        i = b + 1
                    end
                end
            end
        end
    end
    for _, atom in ipairs(atoms) do
        if not atom.w then atom.w = Measure(leaf, atom.font, atom.text) end
    end
    return atoms
end

-- Atoms into rows no wider than `width`: a break only where there was a
-- space (a name's comma stays with it). Sets each atom's `row` and `x`;
-- returns how many rows.
local function Flow(leaf, atoms, width)
    local space = Space(leaf, INK.line)
    local groups = {}
    for _, atom in ipairs(atoms) do
        if atom.space or not groups[1] then groups[#groups + 1] = { atom } else table.insert(groups[#groups], atom) end
    end
    local row, x = 1, 0
    for _, g in ipairs(groups) do
        local w = 0
        for _, atom in ipairs(g) do w = w + atom.w end
        if x > 0 and x + space + w > width then
            row, x = row + 1, 0
        elseif x > 0 then
            x = x + space
        end
        for _, atom in ipairs(g) do
            atom.row, atom.x = row, x
            x = x + atom.w
        end
    end
    return row
end

--------------------------------------------------------------------------
-- The plan: where every line goes, folded only if it must be
--------------------------------------------------------------------------

-- The stops laid down the two halves: { places = { { stop, line, col, y,
-- rows, atoms, first }, ... }, over = whether anything ran past the foot,
-- foot0 = the left half's last row's foot, cols = how many halves used }.
local function Lay(leaf, stops)
    local S = SHEET
    local places, col, y, over, foot0 = {}, 1, S.top, false, S.top
    for i, stop in ipairs(stops) do
        if i > 1 and y > S.top then y = y + S.gap end
        for j, line in ipairs(stop.lines) do
            local atoms = Atoms(leaf, line)
            local rows = Flow(leaf, atoms, S.width)
            local first = j == 1
            local need = rows * S.lead
            if first and stop.icon then need = math.max(need, S.drawing.room[2]) end
            if col == 1 and y + need > S.foot then
                col, y = 2, S.top
            end
            if col == 2 and y + need > S.foot then over = true end
            places[#places + 1] = { stop = stop, line = line, col = col, y = y, rows = rows, atoms = atoms,
                first = first, index = i }
            y = y + math.max(rows * S.lead, (first and stop.icon) and S.drawing.room[2] or 0)
            if col == 1 then foot0 = y end
        end
    end
    return { places = places, over = over, foot0 = foot0, cols = col }
end

-- Takes `stops`' last line that may go (not fixed, no name on it), for a
-- leaf that overflows with every step taken: true where one went.
local function DropOne(stops)
    for i = #stops, 1, -1 do
        local lines = stops[i].lines
        for k = #lines, 1, -1 do
            local line = lines[k]
            local named = false
            for _, m in ipairs(line.marks or {}) do named = named or m.kind == "name" end
            if not line.fixed and not named then
                table.remove(lines, k)
                if not lines[1] then table.remove(stops, i) end
                return true
            end
        end
    end
    return false
end

-- Trip `rec`'s plan on `leaf`: every line as it is while it fits; past
-- that, the copy's steps one by one (FOLDS) until it does. Returns the
-- laid plan, its stops and the steps taken ({ [step] = true, n = count }).
function CityTrips.Plan(leaf, rec, ctx)
    local folds = { n = 0 }
    local stops = CityTrips.Stops(rec, ctx, folds)
    local plan = Lay(leaf, stops)
    for _, step in ipairs(FOLDS) do
        if not plan.over then break end
        folds[step], folds.n = true, folds.n + 1
        stops = CityTrips.Stops(rec, ctx, folds)
        plan = Lay(leaf, stops)
    end
    -- (every step taken and still too long: a trip at every cap. The
    -- lines that may go go from the end, the purse and names never.)
    while plan.over and DropOne(stops) do
        folds.dropped = (folds.dropped or 0) + 1
        plan = Lay(leaf, stops)
    end
    return plan, stops, folds
end

--------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------

local function Colour(c) return { c[1], c[2], c[3], 1 } end

-- One laid line written and marked. `pen` counts the pen's quads; `seed`
-- its own (a string). Names through leaf:Name (a button, their tooltip, a
-- pad stop), a counted line's tooltip on its first words or its tail.
local function WriteLine(leaf, place, c, seed, counts)
    local S = SHEET
    local col = S.cols[place.col]
    local line = place.line
    local function Mid(row) return place.y + (row - 1) * S.lead + S.lead / 2 end
    local tipped = false
    local first
    local function Pen(paths, look)
        local n = leaf:Pen(paths, look)
        counts.pen = counts.pen + n
        return n
    end
    local k = 1
    local atoms = place.atoms
    while k <= #atoms do
        local atom = atoms[k]
        local x, y = col.tx + atom.x, Mid(atom.row)
        local mark = atom.mark
        if atom.arrow then
            Pen(Scribble.Arrow(seed .. ":arrow", x + 3, y, x + atom.w - 4, y - 0.5), Scribble.ARROW)
            k = k + 1
        elseif mark and mark.kind == "name" then
            local guid = mark.guid
            local _, left, w = leaf:Name(atom.text, atom.font, x, y, {
                colour = Colour(Style.INK_STRONG), key = ("name:%s:%s:%d"):format(guid, seed, k),
                tip = function() return CityTrips.NameTip(guid) end,
                click = function() c.ToPerson(guid) end,
            })
            Pen(Scribble.Underline(seed .. ":u" .. k, left + 1, left + w - 2, y + S.base), Scribble.UNDER)
            counts.names = counts.names + 1
            k = k + 1
        elseif mark and mark.kind == "tail" then
            if mark.tip then
                leaf:Name(atom.text, atom.font, x, y, { key = "tail:" .. seed .. ":" .. k,
                    tip = function() return mark.tip end })
                tipped = true
            else
                leaf:Write(atom.text, atom.font, x, y)
            end
            k = k + 1
        elseif mark and (mark.kind == "struck" or mark.kind == "ringed") then
            local text, left, w
            if line.purse and mark.kind == "ringed" then
                text, left, w = leaf:Name(atom.text, atom.font, x, y, { key = "purse",
                    tip = function() return line.purse end })
            else
                text, left, w = leaf:Write(atom.text, atom.font, x, y)
            end
            if mark.kind == "struck" then
                Pen(Scribble.Strike(seed .. ":s", left + 1, y, w - 2, 14), Scribble.STRIKE)
            else
                Pen(Scribble.Ring(seed .. ":o", left + w / 2, y + 0.5, w / 2 + S.ring.x, S.ring.y), Scribble.RING)
            end
            k = k + 1
        else
            -- Words of one ink on one row, written as one.
            local words, font, row = atom.text, atom.font, atom.row
            local j = k + 1
            while j <= #atoms and not atoms[j].mark and not atoms[j].arrow and atoms[j].row == row
                and atoms[j].font == font do
                words = words .. (atoms[j].space and " " or "") .. atoms[j].text
                j = j + 1
            end
            local text = leaf:Write(words, font, x, y, font == INK.rank and { colour = Colour(Style.INK) } or nil)
            first = first or { text = text, x = x, y = y }
            k = j
        end
    end
    -- A counted line with no tail of its own: its tooltip on its first words.
    if line.tip and not tipped and first then
        local box = first.text.leafBox
        local b = leaf:Button(box.x - 2, box.y - 1, box.w + 4, box.h + 2, { tip = function() return line.tip end })
        leaf:Stop({ key = "counted:" .. seed, x = box.x + box.w / 2, y = first.y, frame = b, words = first.text,
            tip = function() return line.tip end })
    end
end

-- The thread down each column, broken where a drawing or a cross sits on
-- it. It stays in its column: it ran from the foot of the left one over to
-- the top of the right once, an arrow across the leaf (the user, 25 Nov
-- 2026: "the arrow that connects the two cols is irritating"). So the
-- right column's thread starts at its top only where its first line goes
-- on with a stop broken across the columns (and the left one's runs on to
-- its foot for it); where the right column opens a new stop, both end and
-- start at a drawing, as a single column's do, with no stub past them.
local function Thread(leaf, plan, c, counts)
    local S = SHEET
    local things = { {}, {} }
    for _, p in ipairs(plan.places) do
        local X = things[p.col]
        if p.first and p.stop.icon then X[#X + 1] = { p.y + S.drawing.room[1], p.y + S.drawing.room[2] } end
        if p.line.cross then X[#X + 1] = { p.y + S.cross.room[1], p.y + S.cross.room[2] } end
    end
    local function Runs(col, lo, hi)
        local list = things[col]
        table.sort(list, function(a, b) return a[1] < b[1] end)
        local runs, y = {}, lo
        for _, t in ipairs(list) do
            if t[1] - 1.5 > y + 5 then runs[#runs + 1] = { y + 1.5, t[1] - 1.5 } end
            y = math.max(y, t[2])
        end
        if hi - 1.5 > y + 5 then runs[#runs + 1] = { y + 1.5, hi - 1.5 } end
        return runs
    end
    local first = things[1][1]
    local lo = first and first[1] or S.top
    local n = 0
    local X1, X2 = S.cols[1].X, S.cols[2].X
    if plan.cols == 2 then
        -- Whether the right column's first line goes on with a stop broken
        -- across the columns.
        local broken = false
        for _, p in ipairs(plan.places) do
            if p.col == 2 then
                broken = not p.first
                break
            end
        end
        local last1 = things[1][#things[1]]
        local hi1 = broken and plan.foot0 or (last1 and last1[1] or lo)
        for k, r in ipairs(Runs(1, lo, hi1)) do
            n = n + leaf:Pen(Scribble.Thread(c.Seed("thread", 1, k), { { X1, r[1], r[2] } }), Scribble.THREAD)
        end
        local first2, last = things[2][1], things[2][#things[2]]
        local lo2 = broken and S.top - 2 or (first2 and first2[1] or S.top)
        for k, r in ipairs(Runs(2, lo2, last and last[1] or lo2)) do
            n = n + leaf:Pen(Scribble.Thread(c.Seed("thread", 2, k), { { X2, r[1], r[2] } }), Scribble.THREAD)
        end
    else
        local last = things[1][#things[1]]
        for k, r in ipairs(Runs(1, lo, last and last[1] or lo)) do
            n = n + leaf:Pen(Scribble.Thread(c.Seed("thread", 1, k), { { X1, r[1], r[2] } }), Scribble.THREAD)
        end
    end
    counts.pen = counts.pen + n
end

-- The heading: the city and the day, the city underlined, how long in
-- graphite at the row's end where it does not meet them.
local function Heading(leaf, plate, c, rec, counts)
    local H = SHEET.heading
    local line, city = CityTrips.Heading(plate, c.now, c.before)
    local text, left, w = leaf:Write(line, INK.heading, H.x, H.y, { colour = Colour(Style.INK_STRONG) })
    leaf:Heading(text)
    local at = city and line:find(city, 1, true)
    if at then
        local x0 = left + 1 + (at > 1 and Measure(leaf, INK.heading, line:sub(1, at - 1)) or 0)
        local x1 = x0 + Measure(leaf, INK.heading, city)
        counts.pen = counts.pen + leaf:Pen(Scribble.Underline(c.Seed("city"), x0, x1 - 1, H.y + H.under), Scribble.UNDER)
    end
    local stay = CityTrips.Stay(rec)
    local right = leaf.w - H.right
    if left + w + H.apart <= right - Measure(leaf, INK.stay, stay) then
        leaf:Write(stay, INK.stay, right, H.y, { justify = "RIGHT" })
        counts.stay = true
    end
end

-- The sheet for trip moment `c.moment` on `leaf`.
local function Draw(leaf, plate, slot, c)
    local m = c.moment
    local rec = m and m.trip
    if not rec then return end
    local counts = { pen = 0, names = 0, drawings = 0 }
    Heading(leaf, plate, c, rec, counts)
    local me
    for guid, j in pairs(ns.db.journey or {}) do
        if j == c.j then me = guid end
    end
    local ctx = { named = c.named, people = CityTrips.Round(rec, me), errands = m.errands }
    local plan, stops, folds = CityTrips.Plan(leaf, rec, ctx)
    local kit = leaf:Kit()
    for k, place in ipairs(plan.places) do
        local col = SHEET.cols[place.col]
        if place.first and place.stop.icon then
            if Sketch.Draw(kit, place.stop.icon, col.X, place.y + SHEET.drawing.down, SHEET.drawing.size) then
                counts.drawings = counts.drawings + 1
            end
        end
        if place.line.cross then
            counts.pen = counts.pen + leaf:Pen(Scribble.Cross(c.Seed("cross", k), col.X, place.y + SHEET.cross.down,
                SHEET.cross.r), Scribble.CROSS)
        end
        WriteLine(leaf, place, c, c.Seed("line", place.index, k), counts)
    end
    Thread(leaf, plan, c, counts)
    counts.sketch = kit.ink.used + kit.inner.used + kit.halo.used
    -- What the tests and the plates' render read back.
    leaf.trip = { rec = rec, plan = plan, stops = stops, folds = folds, counts = counts }
end
CityTrips.Draw = Draw

ns.UI.JourneySheet.Register("trip", {
    draw = Draw,
    label = function(m) return CityTrips.Label(m) end,
    tip = function() return CityTrips.Tip() end,
})
