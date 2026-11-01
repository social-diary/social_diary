-- The run's page in Your Diary, laid out (.claude/ui-proposal/super-plate.md,
-- B, the keepsake page, round 5, 28 Oct): where each thing pasted on the
-- right page goes, as a pure plan the page (UI/Journey/Run.lua) draws and
-- the tests check offline. Nothing searches: every piece has a fixed place
-- taken in rank order, a seeded jitter and turn, and the rules below keep
-- any two from meeting at every count of keepsakes (0 to 5 and more), with
-- a map or without, under a title of one line or two.
--
-- Coordinates are the right page's px from its top left (466 x 534), y
-- down; turns in degrees, as a paper strip's `tilt` takes them (the
-- client's SetRotation: anticlockwise on the screen). A box's x, y is its
-- top left as laid flat; it turns about its middle.

local addonName, ns = ...

local RunPage = {}
ns.RunPage = RunPage

-- The page's look (each field what it is, and why):
--   K       the keepsake slots, taken in rank order: top left, width, the
--           most lines its item's name takes, the most it turns either way.
--           The top row (K1 large in the middle, K2 left, K3 right) ends by
--           y 288 turned; the lower row (K4 right, K5 left of it) starts at
--           289. K5 ends at x 308 and K4 starts at 327: they never meet.
--   card    a keepsake's height: its icon (`icon`, the large one's `big`),
--           then `foot` px of room round it, the name's lines `lh` px each
--           (`bigLh` on K1), under the "whose" line a 12 px foot where the
--           slip is pinned; `jitter` px either way on x and y
--   more    the "and n more" slip, pinned under the last shown card's foot:
--           `dx` from that card's left by how many are shown, its top `up`
--           px up into the card's foot (paper, never the "whose" line),
--           `h` tall, `pad` px wider than its words, turned `turn`. Pinned
--           to K4 or K5, that card's name takes one line, so the slip ends
--           by y 414 turned, clear of the fallen note at 418
--   scrap   the map scrap: at `some` with keepsakes (lower left, under the
--           top row, left of K5), at `none` without (the middle); turned.
--           At 318, not the proposal's 312: the boss strip pasted over its
--           top then starts at 306, clear of the slip pinned under K2 (it
--           ends by 301 turned; tests/run_page.lua found them meeting)
--   bosses  the boss strip, pasted over the scrap's top edge (its top left
--           `dx`, `dy` from the scrap's, so half of it lies on the scrap);
--           with no map known, alone at `alone` (with keepsakes) or centred
--           at y `aloneNone` (without); `h` tall, `pad` wider than its words
--   quiet   "Nothing came up with us.": centred at x, its baseline at y
--   fallen  the fallen note's box: x, y, `w` wide, at most `lines` lines of
--           names, turned `turn`
--   sig     the signatures: the first at x, its baseline at y (each odd
--           one `drop` px lower), `gap` px between, none past `stop`;
--           sizes `size` to `size + grow`, turned up to `turn` either way;
--           a name's "+ Add" `add` px under its baseline. Everyone who does
--           not fit that one row goes on `roster` (RunPage.Signatures)
--   title   the dungeon's name: centred at `x` (the page's middle, 233, and
--           room for the seal at its left), baseline `base`, the first of
--           `sizes` at which it is no wider than `most`; past that two
--           lines at `two` (baselines `lines`), and the subtitle and top
--           row move down `shift`; the seal `seal` px across, its middle
--           `sealX` px left of the title's left, at `sealY` (or `sealTwo`)
--   sub     the subtitle's baseline, centred at x
local RUN = {
    K = {
        { x = 167, y = 140, w = 132, big = true, lines = 3, turn = 2.5 },
        { x = 34, y = 150, w = 104, lines = 3, turn = 3.5 },
        { x = 314, y = 146, w = 104, lines = 3, turn = 3.5 },
        { x = 330, y = 286, w = 104, lines = 2, turn = 3.5 },
        { x = 204, y = 292, w = 104, lines = 2, turn = 3.5 },
    },
    card = { icon = 34, big = 48, foot = 48, lh = 14, bigLh = 15, jitter = 3 },
    more = { dx = { 30, 10, 4, 4, 8 }, up = 6, h = 26, pad = 18, turn = 2 },
    scrap = { w = 170, h = 114, some = { 18, 318 }, none = { 148, 160 }, turn = -3.2 },
    bosses = { dx = 10, dy = -12, alone = { 28, 306 }, aloneNone = 216, h = 26, pad = 18, turn = -1.6 },
    quiet = { x = 233, y = 330 },
    fallen = { x = 250, y = 418, w = 190, lines = 3, turn = -4 },
    sig = { x = 26, y = 494, drop = 6, gap = 20, stop = 440, size = 19, grow = 4, turn = 4, add = 15,
        -- The full list, for a big party or a raid: names at `size`, `gap`
        -- px apart, `add` px over their "+ Add", on these rows (baselines),
        -- turned a share `turn` of a signature's so rows do not touch. The
        -- first row stops short of the fallen note (x 246), unless nobody
        -- fell and the note is one short line at the top; the scrap's foot
        -- (459) lies over it, and the last "+ Add" ends by 521.
        roster = { size = 14, gap = 12, add = 10, turn = 0.5, rows = { { y = 474, stop = 236 }, { y = 504, stop = 440 } } } },
    title = { x = 255, base = 76, sizes = { 46, 38, 32, 28 }, most = 360, two = 32, lines = { 64, 98 }, shift = 22,
        seal = 46, sealX = 30, sealY = 60, sealTwo = 70 },
    sub = { x = 233, y = 112 },
}
RunPage.RUN = RUN

-- Noise in [0, 1), the same every time for the same number.
local function Noise(n)
    local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)
end

-- The title's size: the first of RUN.title.sizes at which `width(size)`
-- (the name measured in that size) is no wider than RUN.title.most; else
-- RUN.title.two on two lines. Returns size, twoLines.
function RunPage.TitleSize(width)
    local T = RUN.title
    for _, size in ipairs(T.sizes) do
        if width(size) <= T.most then return size, false end
    end
    return T.two, true
end

-- The most lines keepsake `i` of `n` shown may give its name: its slot's;
-- under a two-line title K1 one and K2, K3 two; the card the slip is
-- pinned to (K4 or K5, with `more` items not shown) one.
function RunPage.Most(i, n, more, twoLines)
    local slot = RUN.K[i]
    if i <= 3 then
        if twoLines then return i == 1 and 1 or 2 end
        return slot.lines
    end
    if (more or 0) > 0 and i == n then return 1 end
    return slot.lines
end

-- A keepsake's height with `lines` lines of name.
function RunPage.CardHeight(i, lines)
    local C, big = RUN.card, RUN.K[i].big
    return (big and C.big or C.icon) + C.foot + lines * (big and C.bigLh or C.lh)
end

-- The plan for a page. `input`:
--   n         keepsakes shown (0 to 5)
--   more      items not shown ("and n more")
--   lines     each shown card's lines of name (as wrapped, at most Most's)
--   map       a floor is known (the scrap)
--   total     a boss total is known (the strip)
--   twoLines  the title takes two lines
--   bossW     the boss strip's words' width; moreW the slip's
--   seed      a number: the visit's (each piece's jitter and turn)
-- Returns { shift, cards = { { x, y, w, h, turn, big, lines, icon, lh } },
-- slip, scrap, boss (each { x, y, w, h, turn } or nil), quiet ({ x, y } or
-- nil), fallen, sig, sub ({ x, y }) }.
function RunPage.Plan(input)
    local n = math.min(input.n or 0, #RUN.K)
    local more = input.more or 0
    local seed = input.seed or 0
    local shift = input.twoLines and RUN.title.shift or 0
    local C = RUN.card
    local plan = { shift = shift, cards = {}, fallen = RUN.fallen, sig = RUN.sig,
        sub = { x = RUN.sub.x, y = RUN.sub.y + shift } }

    for i = 1, n do
        local slot = RUN.K[i]
        local s = seed + i * 7
        local lines = math.max(1, math.min(input.lines and input.lines[i] or 1, RunPage.Most(i, n, more, input.twoLines)))
        local jx, jy = (Noise(s + 1) - 0.5) * 2 * C.jitter, (Noise(s + 2) - 0.5) * 2 * C.jitter
        plan.cards[i] = { x = slot.x + jx, y = slot.y + jy + (i <= 3 and shift or 0), w = slot.w,
            h = RunPage.CardHeight(i, lines), turn = (Noise(s + 3) - 0.5) * 2 * slot.turn, big = slot.big == true,
            lines = lines, icon = slot.big and C.big or C.icon, lh = slot.big and C.bigLh or C.lh }
    end

    local last = plan.cards[n]
    if more > 0 and last then
        local M = RUN.more
        plan.slip = { x = last.x + M.dx[n], y = last.y + last.h - M.up, w = (input.moreW or 80) + M.pad, h = M.h,
            turn = M.turn }
    end

    local S = RUN.scrap
    if input.map then
        local at = n > 0 and S.some or S.none
        -- Under a two-line title it moves down with the top row (its foot
        -- still ends by 459, over the signatures).
        plan.scrap = { x = at[1], y = at[2] + shift, w = S.w, h = S.h, turn = S.turn }
    end

    if input.total then
        local B = RUN.bosses
        local w = (input.bossW or 120) + B.pad
        local x, y
        if plan.scrap then
            x, y = plan.scrap.x + B.dx, plan.scrap.y + B.dy
        elseif n > 0 then
            x, y = B.alone[1], B.alone[2] + shift
        else
            x, y = RUN.quiet.x - w / 2, B.aloneNone + shift
        end
        plan.boss = { x = x, y = y, w = w, h = B.h, turn = B.turn }
    end

    if n == 0 then plan.quiet = { x = RUN.quiet.x, y = RUN.quiet.y } end
    return plan
end

-- Where everyone's name goes, along the foot (`RUN.sig`). `input`:
--   people  in order, each { big, small }: the name's width at its own
--           signature size and at the roster's (the same for a line of words
--           that is not a name)
--   addW    "+ Add"'s width: every name's place is at least this wide, whether
--           it has one or not, so nobody moves as one is added
--   moreW   the widest "and n others"
--   open    nobody fell: the first row may run the page's width
-- Everyone on one row at their signature size where they fit (`roster`
-- false). Else the roster, turned over in `pages`: a raid does not fit the
-- foot of a page at any size a name can be read at, and nothing else on the
-- page can give way. Returns { roster, pages = { { { i, x, y, w, row }, ... ,
-- more = { x, y } } } }: person `people[i]` in the place x, w with its
-- baseline at y; `more` where "and n others" goes, on a page with others.
function RunPage.Signatures(input)
    local S, people, addW = RUN.sig, input.people or {}, input.addW or 0
    local page, x = {}, S.x
    for i, p in ipairs(people) do
        local w = math.max(p.big or 0, addW)
        if x + w > S.stop then
            page = nil
            break
        end
        page[i] = { i = i, x = x, y = S.y + ((i % 2 == 0) and S.drop or 0), w = w, row = 1 }
        x = x + w + S.gap
    end
    if page then return { roster = false, pages = { page } } end

    local R = S.roster
    local function Lay(reserve)
        local pages, row, at = { {} }, 1, S.x
        for i, p in ipairs(people) do
            local w = math.max(p.small or 0, addW)
            while true do
                local last = row == #R.rows
                local stop = (row == 1 and input.open) and S.stop or R.rows[row].stop
                if last and (reserve or i < #people) then stop = stop - (input.moreW or 0) - R.gap end
                local here = pages[#pages]
                -- A name too wide for any row still goes on one.
                if at + w <= stop or (at == S.x and last and #here == 0) then
                    here[#here + 1] = { i = i, x = at, y = R.rows[row].y, w = w, row = row }
                    at = at + w + R.gap
                    break
                end
                if last then pages[#pages + 1] = {} end
                row, at = last and 1 or row + 1, S.x
            end
        end
        return pages
    end
    local pages = Lay(false)
    if #pages > 1 then
        pages = Lay(true)
        for _, here in ipairs(pages) do
            local last, y = here[#here], R.rows[#R.rows].y
            here.more = { x = last.row == #R.rows and last.x + last.w + R.gap or S.x, y = y }
        end
    end
    return { roster = true, pages = pages }
end

-- The four corners of box `b` ({ x, y, w, h, turn }) as laid, turned about
-- its middle as a strip turns (UI/Paper/Surface.lua's Turned): for the
-- tests.
function RunPage.Corners(b)
    local a = math.rad(b.turn or 0)
    local c, s = math.cos(a), math.sin(a)
    local cx, cy = b.x + b.w / 2, b.y + b.h / 2
    local out = {}
    for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local u, v = p[1] * b.w / 2, p[2] * b.h / 2
        out[#out + 1] = { cx + u * c + v * s, cy - u * s + v * c }
    end
    return out
end
