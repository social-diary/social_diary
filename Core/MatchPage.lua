-- A battleground's pages in Your Diary, laid out
-- (.claude/ui-proposal/battleground-page.md, round 2, with Jan's changes in
-- .claude/battleground-plan.md): where everything on the two right pages
-- goes, as a pure plan the pages (UI/Journey/Match.lua) draw and the tests
-- (tests/battleground_page.lua) check offline, as Core/RunPage.lua is the
-- run's page's.
--
--   C, the match page: the game's final board cut out and pasted in (the
--      clipping), your side over theirs, every player a row; turned over
--      in faces where forty a side cannot fit; the strips of the stand-out
--      and the repeats in the margin, each with a pencil leader that runs
--      through the gutter only, never over a figure. A match whose board
--      never read has the diary's own slip of the names read during play
--      in its place.
--   B, the overview ("Battlegrounds"): the session's matches as tickets
--      across the top, then the roll of everyone who was there, the people
--      who matter by hand, everyone else in print; only the roll turns.
--
-- Coordinates are the right page's px from its top left (466 x 534), y
-- down, as RunPage's; turns in degrees, as a paper strip's `tilt`.
--
-- Also here, because the pages ask it of every row and the record's own
-- Matches.Meetings reads every saved match once per question: an index of
-- who was in which match (Index, Count), built once as a page is drawn.

local addonName, ns = ...

local MatchPage = {}
ns.MatchPage = MatchPage

-- The match page's look (each field what it is, and why):
--   board   the clipping: top left x, y, `w` wide, turned `turn`. Inside, from
--           its top: the masthead (`mast` px: "FINAL" and the map's touch,
--           then a rule), each side's heading (`head` px), its rows (`lh`
--           px each, Friz 11 as the game's own board prints), `gap` px
--           between the sides, `pad` px under the last row. One face where
--           everything fits by `foot`; else the board turns over and ends
--           by `turned`, the turn link under it. A rolled-up match's lost
--           records take `lost` px after the rows. Columns from the
--           clipping's left: the class icon's middle `icon`, the name's
--           left `name`, the figures' right ends `kills` and `deaths` (no
--           honour: Jan), the pencil tick at the row's end from `tick` to
--           `tickEnd`. At 12.5 px a Warsong's twenty rows end by y 456, and
--           Alterac's nine rows a side a face by 433.
--   slip    the "score went unwritten" slip in the clipping's place: the
--           same x, y, w, turn; its line at `say` px, the columns' headings
--           at `heads`, their left ends `cols`; names by hand from `first`,
--           `lh` px apart, `per` to a column a face
--   strips  the margin: strips `w` wide from `x`, at most `most`, `gap` px
--           apart, each as near its row as the one above lets it (its top
--           `up` px over its row's middle), none past `bottom`; turned up
--           to `turn` either way. The gutter between the clipping's right
--           edge (290) and `x` holds the leaders.
--   note    your note at the foot: its top at least `y`, `after` px under
--           the clipping (or the turn link), at most `most`; turned `turn`
--   back    "Back to the evening's battlegrounds": its middle's x, y
local MATCH = {
    board = { x = 18, y = 124, w = 272, turn = -0.8, mast = 32, head = 17, lh = 12.5, gap = 10, pad = 6,
        foot = 458, turned = 436, lost = 28,
        icon = 15, name = 26, kills = 200, deaths = 244, tick = 254, tickEnd = 262 },
    slip = { x = 18, y = 124, w = 272, turn = -1, say = 20, heads = 42, cols = { 14, 142 }, first = 62, lh = 15,
        per = 15, pad = 12 },
    strips = { x = 304, w = 144, most = 5, gap = 8, up = 14, bottom = 466, turn = 1.5 },
    note = { y = 466, after = 16, most = 476, turn = -1.5 },
    back = { x = 24, y = 22 },
}
MatchPage.MATCH = MATCH

-- The overview's look:
--   tickets  a ticket `w` by `h`, `gap` apart, `per` to a row centred on
--            `cx`, the first row's top at `y`, the next `row` px under; at
--            most `most` (two rows); turned up to `turn` either way
--   roll     under the tickets by `under` px: its first line holds the turn
--            link at `x` and the matches' numerals over their columns (the
--            first at `colX`, `colW` apart, narrower where many would pass
--            `colEnd`); the rows below it from `first` px down, to `bottom`.
--            By hand: a side's heading `headH` px, a person `rowH`, `gap`
--            between the sides, names at `nameX`. In print, after its
--            heading (`printHead` px): `cols` columns `colPW` wide, rows
--            `printH` px
--   note     your note: its baseline's middle y, from x, turned `turn`
local EVENING = {
    tickets = { w = 82, h = 64, gap = 6, per = 5, cx = 233, y = 128, row = 70, most = 10, turn = 2.5 },
    roll = { under = 22, x = 30, colX = 262, colW = 46, colEnd = 440, first = 20, bottom = 494,
        headH = 24, rowH = 18, gap = 2, nameX = 38, printHead = 24, cols = 3, colPW = 140, printH = 13 },
    note = { x = 30, y = 516, turn = -1 },
}
MatchPage.EVENING = EVENING

-- Noise in [0, 1), the same every time for the same number.
local function Noise(n)
    local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)
end
MatchPage.Noise = Noise

--------------------------------------------------------------------------
-- Who was where: an index of the saved matches
--------------------------------------------------------------------------

-- A person's key across matches: their GUID, else their name (a row read
-- only during play has none).
function MatchPage.KeyOf(p)
    if p.guid then return p.guid end
    local key = ns.Matches.Key(p.name)
    return key and ("n:" .. key) or nil
end

-- Every row of `matches` (a character's, Matches.All), by key: { [key] =
-- { { match, side, t }, ... } } oldest first; the rows that never had a
-- GUID also by name ("n:" .. key), so a guid's count can take them in as
-- Matches.For does. Built once as a page is drawn: Meetings asked of
-- every row of an Alterac reads every saved match eighty times.
function MatchPage.Index(matches)
    local index = {}
    for _, m in ipairs(matches) do
        for _, p in ipairs(ns.Matches.Players(m)) do
            local key = MatchPage.KeyOf(p)
            if key then
                local list = index[key] or {}
                index[key] = list
                list[#list + 1] = { match = m, side = ns.Matches.Side(m, p), t = m.startedAt or 0 }
            end
        end
    end
    return index
end

-- How many matches up to and including `match` row `p` was in on `side`
-- ("against", "with", or nil for either): Matches.Meetings from the index.
-- A GUID's count takes in the rows of their name that never had one, as
-- Matches.For does, once per match.
function MatchPage.Count(index, p, match, side)
    local t = match and match.startedAt or math.huge
    local seen, n = {}, 0
    local function Take(list)
        for _, hit in ipairs(list or {}) do
            if not seen[hit.match] and hit.t <= t and (side == nil or hit.side == side) then
                seen[hit.match] = true
                n = n + 1
            end
        end
    end
    Take(index[MatchPage.KeyOf(p) or ""])
    if p.guid then
        local key = ns.Matches.Key(p.name)
        if key then Take(index["n:" .. key]) end
    end
    return n
end

--------------------------------------------------------------------------
-- The match page
--------------------------------------------------------------------------

-- The order on the board (Jan, 9 Nov; proposal §2): within each side, the
-- people in your diary, then you, then the repeats (most meetings first),
-- then the stand-out, then everyone else in the game's order. `rows`: each
-- { side ("with", "against" or nil), diary, me, meets, standout, index }.
-- Returns { with = { rows }, against = { rows } }: a row whose side went
-- unread is put with theirs, last.
local function Rank(r)
    if r.diary then return 1 end
    if r.me then return 2 end
    if (r.meets or 0) >= 2 then return 3 end
    if r.standout then return 4 end
    return 5
end
function MatchPage.Order(rows)
    local out = { with = {}, against = {} }
    for _, r in ipairs(rows) do
        local list = r.side == "with" and out.with or out.against
        list[#list + 1] = r
    end
    for _, list in pairs(out) do
        table.sort(list, function(a, b)
            local ra, rb = Rank(a), Rank(b)
            if ra ~= rb then return ra < rb end
            if (a.side == nil) ~= (b.side == nil) then return b.side == nil end
            if ra == 3 and (a.meets or 0) ~= (b.meets or 0) then return (a.meets or 0) > (b.meets or 0) end
            return (a.index or 0) < (b.index or 0)
        end)
    end
    return out
end

-- The board's faces: `nWith` and `nAgainst` rows, a rolled-up match's
-- lost records (`lost` true; its sides with no row left are left off, as
-- nobody of them is kept). Everything on one face where it fits by
-- MATCH.board.foot; else `per` rows a side a face, as many faces as the
-- longer side needs. Returns { faces, per, turns }.
local function Sides(nWith, nAgainst, lost)
    local out = {}
    for _, side in ipairs({ "with", "against" }) do
        local n = side == "with" and nWith or nAgainst
        if not (lost and n == 0) then out[#out + 1] = side end
    end
    return out
end
function MatchPage.BoardFaces(nWith, nAgainst, lost)
    local B = MATCH.board
    local sides = #Sides(nWith, nAgainst, lost)
    local fixed = B.mast + sides * B.head + math.max(0, sides - 1) * B.gap + B.pad + (lost and B.lost or 0)
    if fixed + (nWith + nAgainst) * B.lh <= B.foot - B.y then
        return { faces = 1, per = math.max(nWith, nAgainst, 1), turns = false }
    end
    local per = math.max(1, math.floor((B.turned - B.y - fixed) / (2 * B.lh)))
    return { faces = math.max(1, math.ceil(math.max(nWith, nAgainst) / per)), per = per, turns = true }
end

-- One face of the board laid: the rows of each side shown on face `face`
-- (`with`, `against`: { from, to } into each side's list, empty where the
-- side has run out), each row's middle y from the clipping's top (`rows`:
-- { side, i, y }), the side headings' baselines (`heads`), where the lost
-- records go (`lost`) and the clipping's height `h`.
function MatchPage.Board(nWith, nAgainst, face, lost)
    local B = MATCH.board
    local f = MatchPage.BoardFaces(nWith, nAgainst, lost)
    face = math.max(1, math.min(face or 1, f.faces))
    local plan = { faces = f.faces, turns = f.turns, face = face, rows = {}, heads = {} }
    local y = B.mast
    for k, side in ipairs(Sides(nWith, nAgainst, lost)) do
        local n = side == "with" and nWith or nAgainst
        local from = (face - 1) * f.per + 1
        local to = math.min(n, face * f.per)
        plan[side] = { from = from, to = to }
        if k > 1 then y = y + B.gap end
        -- (the heading's middle; its rule 7 px under it, clear of the
        -- first row's words)
        plan.heads[side] = y + B.head / 2 - 1
        y = y + B.head
        for i = from, to do
            plan.rows[#plan.rows + 1] = { side = side, i = i, y = y + B.lh / 2 }
            y = y + B.lh
        end
    end
    if lost then
        plan.lost = y + B.lost / 2
        y = y + B.lost
    end
    plan.h = y + B.pad
    return plan
end

-- The slip of names when the board never read: each side a column, `per`
-- names a column a face. Returns { faces, face, with/against = { from, to
-- }, rows = { { side, i, y, col } } (each name's middle from the slip's
-- top), h }.
function MatchPage.Slip(nWith, nAgainst, face)
    local S = MATCH.slip
    local faces = math.max(1, math.ceil(math.max(nWith, nAgainst) / S.per))
    face = math.max(1, math.min(face or 1, faces))
    local plan = { faces = faces, face = face, turns = faces > 1, rows = {} }
    local most = 0
    for c, side in ipairs({ "with", "against" }) do
        local n = side == "with" and nWith or nAgainst
        local from, to = (face - 1) * S.per + 1, math.min(n, face * S.per)
        plan[side] = { from = from, to = to }
        most = math.max(most, to - from + 1)
        for i = from, to do
            plan.rows[#plan.rows + 1] = { side = side, i = i, y = S.first + (i - from) * S.lh, col = c }
        end
    end
    plan.h = S.first + math.max(most, 1) * S.lh + S.pad - S.lh / 2
    return plan
end

-- The margin's strips, in the order of their rows (`marks`: each { y, h },
-- y its row's middle on the page): each as near its row as the strip
-- above lets it, none past MATCH.strips.bottom, at most `most`. Returns {
-- { x, y, w, h, i } } (i: the mark it is for); a mark with no room is left
-- out (its row's tooltip still tells its story).
function MatchPage.Strips(marks)
    local S = MATCH.strips
    local out, below = {}, -math.huge
    for i, mk in ipairs(marks) do
        if #out >= S.most then break end
        local y = math.max(below, mk.y - S.up)
        if y + mk.h > S.bottom then break end
        out[#out + 1] = { x = S.x, y = y, w = S.w, h = mk.h, i = i }
        below = y + mk.h + S.gap
    end
    return out
end

-- Which of the rows with a note get a strip (`notes`: each { y, h, rank },
-- y its row's middle on the page, rank lower first: the stand-out, then
-- the repeats met most): the best ranked that the margin holds, laid in
-- their rows' order. Returns the chosen notes in row order and their
-- strips (Strips' boxes, `i` into the chosen).
function MatchPage.Choose(notes)
    local pool = {}
    for _, n in ipairs(notes) do pool[#pool + 1] = n end
    table.sort(pool, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.y < b.y
    end)
    for i = #pool, MATCH.strips.most + 1, -1 do pool[i] = nil end
    while #pool > 0 do
        local chosen = {}
        for _, n in ipairs(pool) do chosen[#chosen + 1] = n end
        table.sort(chosen, function(a, b) return a.y < b.y end)
        local placed = MatchPage.Strips(chosen)
        if #placed == #chosen then return chosen, placed end
        pool[#pool] = nil
    end
    return {}, {}
end

-- Where your note goes, under a clipping that ends at `bottom` (the turn
-- link's line where it turns over).
function MatchPage.NoteY(bottom)
    local N = MATCH.note
    return math.min(N.most, math.max(N.y, bottom + N.after))
end

--------------------------------------------------------------------------
-- The overview
--------------------------------------------------------------------------

-- The tickets for `n` matches: { { x, y, w, h, turn }, ... } (at most
-- EVENING.tickets.most; past that the last is "and n more") and the roll's
-- top, under the last row of them. `seed` turns each its own way.
function MatchPage.Tickets(n, seed)
    local T = EVENING.tickets
    n = math.min(n, T.most)
    local out = {}
    local rows = math.max(1, math.ceil(n / T.per))
    for i = 1, n do
        local r = math.floor((i - 1) / T.per)
        local inRow = math.min(T.per, n - r * T.per)
        local width = inRow * T.w + (inRow - 1) * T.gap
        local k = (i - 1) % T.per
        local s = (seed or 0) + i * 7
        out[i] = { x = T.cx - width / 2 + k * (T.w + T.gap), y = T.y + r * T.row + (Noise(s) - 0.5) * 4,
            w = T.w, h = T.h, turn = (Noise(s + 1) - 0.5) * 2 * T.turn }
    end
    return out, T.y + (rows - 1) * T.row + T.h + EVENING.roll.under
end

-- The roll's columns: the numeral's middle x of each of `n` matches.
function MatchPage.Columns(n)
    local R = EVENING.roll
    local w = math.min(R.colW, (R.colEnd - R.colX) / math.max(1, n - 1 + 0.5))
    local out = {}
    for i = 1, n do out[i] = R.colX + (i - 1) * w end
    return out
end

-- The roll laid into faces from `top` (its first line's top; Tickets).
-- `hand`: the lines by hand in order, each { h } (a side's heading, a
-- person, the gap between the sides); `print`: how many are in print,
-- after their heading. Every face keeps its first line for the turn link
-- and the numerals; a line by hand that does not fit begins the next face;
-- print fills what is left of a face in `cols` columns, then whole faces.
-- Returns { { hand = { { i, y } }, head = y or nil, print = { from, to, y,
-- rows } or nil }, ... }, each y a line's top.
function MatchPage.Roll(top, hand, print)
    local R = EVENING.roll
    local first = top + R.first
    local faces = { { hand = {} } }
    local face, y = faces[1], first
    local function Turn()
        face = { hand = {} }
        faces[#faces + 1] = face
        y = first
    end
    for i, line in ipairs(hand or {}) do
        if y + line.h > R.bottom and y > first then Turn() end
        face.hand[#face.hand + 1] = { i = i, y = y }
        y = y + line.h
    end
    local left = print or 0
    if left > 0 then
        if y + R.printHead + R.printH > R.bottom then Turn() end
        face.head = y
        y = y + R.printHead
        local from = 1
        while left > 0 do
            local rows = math.max(1, math.floor((R.bottom - y) / R.printH))
            local take = math.min(left, rows * R.cols)
            face.print = { from = from, to = from + take - 1, y = y, rows = rows }
            from, left = from + take, left - take
            if left > 0 then Turn() end
        end
    end
    return faces
end

-- Print entry `k` (1-based within its face) of a face's print block: its
-- left x and top y.
function MatchPage.PrintAt(block, k)
    local R = EVENING.roll
    local c = math.floor((k - 1) / block.rows)
    local r = (k - 1) % block.rows
    return R.x + c * R.colPW, block.y + r * R.printH
end

-- The four corners of box `b` as laid, turned about its middle: for the
-- tests (RunPage's).
function MatchPage.Corners(b)
    return ns.RunPage.Corners(b)
end
