-- A Warsong told by time, laid out (.claude/ui-proposal/battleground-page-v2.md,
-- round 8, S1 approved by Jan; its mockup's drawing logic, battleground-page-
-- v2-mockup.html, is the spec this follows): where everything on the match's
-- v2 page goes, as a pure plan the page (UI/Journey/MatchStory.lua) draws and
-- the tests (tests/battleground_story_ui.lua) check offline, as
-- Core/MatchPage.lua is the board's and Core/RunPage.lua the run's.
--
-- The story is Core/MatchStory.lua's (Story.Build): carries with their
-- holds, lying and ends, fights tied to carries, phases, the zerg, two lines
-- and their strips. Here it is put on the page:
--
--   lines     the match in two at the capture nearest its middle, both at
--             one scale (the longer line fills the width); a line's strips in
--             a band under it, or no band and the next line moves up
--   branches  a pick-up forks a branch off the base line (ours over it,
--             theirs under it); a hold is a stroke at the branch's height, a
--             flag lying is a row of pencil dots, a drop the carrier's cross
--             at the hold's end; captured, the last hold rises into the
--             circled score (and the base line has a gap at the capture);
--             returned, from the dots it comes back down onto the base line,
--             forward in time; picked up again, it goes on after the dots
--   stains    the fights as the trail's rust (UI/Ink/Trail.lua's Ink.Stain)
--             along time: on their carry's branch, else on the base line;
--             fights close together are one stain; a zerg's run together
--             along the whole stretch, laid in pieces a blot can hold
--   crosses   every death in its fight's place, ours over the line, theirs
--             under it; yours a size larger
--   names     the phases' names in graphite over their stretches, and the
--             zerg's, by the proposal's rule
--   row       the band's strips: three a line at most, each as near its
--             moment as the one before lets it
--
-- Coordinates are the right page's px from its top left (466 x 534), y down;
-- times are the story's (seconds after the gates).

local addonName, ns = ...

local SP = {}
ns.MatchStoryPage = SP

local floor, min, max, abs, cos, log, pi = math.floor, math.min, math.max, math.abs, math.cos, math.log, math.pi

-- The page's look (each field what it is, and why; the numbers are the
-- mockup's, round 8, where Jan approved S1):
--   back     "Back to the battlegrounds": its left x and middle y (v1's)
--   stub     the corner stub of the board's clipping: top left x, y, w by h,
--            turned `turn` degrees; its word ("VICTORY", Friz `word` pt) at
--            `pad` px in and `wordY` down, the score's pennants after it at
--            `pennant` scale `step` px apart; "See the board" (Friz `link`
--            pt) at `linkY` down
--   lines    the first line's block from `top`: `up` px over the line for
--            the phases' names and the circled scores, `down` px under it
--            for their branches; the line from `x0`, `w` px for the longer
--            of the two (both at one scale). A branch lies `lift` px off the
--            line, a captured one rises to `rise` times that at its end; the
--            base line breaks `gap` px either side of a capture; it wobbles
--            `wobble` px a `seg` px piece. Names' middles sit `names` px over the
--            score's height, at least `room` px apart and never past `nameEnd`
--   branch   the fork's ramp: at most `ramp` px, or `rampShare` of its first
--            hold; a hold never shorter than `least` px; the flag lying: a
--            pencil dot every `dots` px; the return's run back down: at least
--            `back` px, or `backShare` of the lift; the ring round the score
--            `rx` by `ry` px, `ringOff` px past the branch's height
--   band     a line's strips: `gap` px under its block, `h` px tall at most,
--            from `x0` to `x1`, `apart` px between them, `most` a line;
--            widths `L` and `M` (the plates' bands); turns in degrees, by turn
--   sizes    the widest each kind is drawn (the mockup's: the friend who
--            killed you and the nemesis are L on a tag); the rest M
--   stain    the trail's STAIN laid along time (proposal, "Stains"): fights
--            `join` px apart are one stain (`zerg` px inside a zerg), no
--            longer than `span` px (none inside a zerg); darkness from
--            seconds plus `death` s a death on Ink.FightScore's curve with
--            knee `knee` and full `full` minutes (guesses, open question 4);
--            half-length its seconds' px plus `bleed` * F, at least
--            least[1] + least[2] * F; half-width across[1] + across[2] *
--            people, at least a fifth of its length (`aspect`), at most
--            `most` of the lift (and `mostLeast` px). A stain longer than
--            `piece` px is laid as overlapping pieces (`overlap` px): the
--            blot's grid holds a short one (InkBlot's cap), and a zerg
--            deepens at each of its fights, not at its middle
--   cross    a death's cross `off` px off its path (ours over, theirs
--            under), crosses closer than `apart` px stepped aside
--   foot     your line at the foot: the plane's x, y and turn (v1's FootNote)
--   moved    the faint dashed pencil outline where a fight moved onto its
--            branch sat on the base line (proposal, open question 1: "easy
--            to take out"): false leaves it out
local STORY = {
    back = { x = 24, y = 22 },
    stub = { x = 334, y = 8, w = 120, h = 38, turn = 2.2, pad = 8, wordY = 12, word = 11, pennant = 0.62,
        step = 8, linkY = 27, link = 11 },
    lines = { top = 118, up = 56, down = 38, x0 = 24, w = 404, lift = 12, rise = 1.55, gap = 3.5, wobble = 1.2,
        seg = 14, names = 27, room = 10, nameEnd = 452 },
    branch = { ramp = 8, rampShare = 0.45, least = 5, dots = 2.6, back = 9, backShare = 0.9, rx = 13.5, ry = 8.6,
        ringOff = 9.5 },
    band = { gap = 6, h = 92, x0 = 12, x1 = 454, apart = 8, most = 3, L = 176, M = 142,
        turns = { 0.9, -1.1, 0.7, -0.6, 1.2, -0.8 } },
    sizes = { friend = "L", nemesis = "L" },
    stain = { join = 8, zerg = 56, span = 64, death = 20, knee = 0.25, full = 4, least = { 4.2, 1.6 }, bleed = 4,
        across = { 2, 0.55 }, aspect = 5, most = 0.55, mostLeast = 6, piece = 48, overlap = 10 },
    cross = { off = 5, apart = 5 },
    foot = { x = 18, y = 508, turn = -1 },
    moved = true,
}
SP.STORY = STORY

local function Clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

--------------------------------------------------------------------------
-- The lines
--------------------------------------------------------------------------

-- The story's two lines laid down the page: each { i, from, to, strips,
-- top, Y (the base line), X0, pps, band (the band's top, nil with no
-- strips), bottom }, and :X(t), the line's x of second t (held to the
-- line). Both at one scale: the longer fills `w`.
function SP.Lines(story)
    local L, B = STORY.lines, STORY.band
    local longest = 1
    for _, ln in ipairs(story.lines) do longest = max(longest, ln.to - ln.from) end
    local pps = L.w / longest
    local out, y = {}, L.top
    for i, ln in ipairs(story.lines) do
        local o = { i = i, from = ln.from, to = ln.to, strips = ln.strips, top = y, Y = y + L.up, X0 = L.x0,
            pps = pps }
        function o.X(t) return o.X0 + (Clamp(t, o.from, o.to) - o.from) * pps end
        if #(ln.strips or {}) > 0 then
            o.band = o.Y + L.down + B.gap
            o.bottom = o.band + B.h
        else
            o.bottom = o.Y + L.down
        end
        y = o.bottom
        out[i] = o
    end
    return out
end

--------------------------------------------------------------------------
-- The branches
--------------------------------------------------------------------------

-- The carries on line `ln`, each a branch: { c, s (-1 over the line, ours;
-- 1 under it, theirs), xa (the fork), ramp, holds { { xa, xb, who, dropped
-- } }, lying { { xa, xb } }, xb (the last hold's end), xl (the branch's last
-- x at its height: the dots' end), cap (the ring's middle { x, y }, captured
-- only), back (the return's run { x0, y0, x1, y1 }, returned only), drops
-- (the carriers' crosses { x, y, who }), :H(x) (its height, 0..rise), :At(t)
-- (x, y on it) }. A carry out across the line's end is clipped to it; one
-- out over its start comes in at its height, no fork.
function SP.Branches(story, ln)
    local L, R = STORY.lines, STORY.branch
    local out, by = {}, {}
    for _, c in ipairs(story.carries or {}) do
        if c.from < ln.to and c.to > ln.from then
            local X = ln.X
            local g = { c = c, s = c.side == "us" and -1 or 1, holds = {}, lying = {}, drops = {} }
            local here = c.from >= ln.from
            g.xa = X(c.from)
            for _, h in ipairs(c.holds) do
                local to = h.to or c.to
                if to >= ln.from and h.from <= ln.to then
                    local xa = X(h.from)
                    local xb = X(to)
                    g.holds[#g.holds + 1] = { xa = xa, xb = xb, who = h.who, dropped = h.dropped }
                    if h.dropped and to <= ln.to then
                        g.drops[#g.drops + 1] = { x = xb + 1.5, who = h.who, t = to }
                    end
                end
            end
            if #g.holds == 0 then g.holds[1] = { xa = g.xa, xb = X(c.to) } end
            local first, last = g.holds[1], g.holds[#g.holds]
            -- (a hold too short to see is drawn `least` px)
            last.xb = max(last.xb, (#g.holds == 1 and g.xa or last.xa) + R.least)
            g.xb = last.xb
            g.ramp = here and min(R.ramp, (first.xb - first.xa) * R.rampShare) or 0
            for _, l in ipairs(c.lying or {}) do
                if l.to >= ln.from and l.from <= ln.to then
                    g.lying[#g.lying + 1] = { xa = X(l.from), xb = X(l.to) }
                end
            end
            -- The branch's last x at its height: past the dots, at least a
            -- little past a drop so the dots show.
            g.xl = g.xb
            for _, l in ipairs(g.lying) do g.xl = max(g.xl, l.xb) end
            if c.ends == "returned" and c.to <= ln.to then
                g.xl = max(g.xl, g.xb + 4)
                local run = max(R.back, L.lift * R.backShare)
                g.back = { x0 = g.xl, y0 = ln.Y + g.s * L.lift, x1 = g.xl + run, y1 = ln.Y }
            end
            local captured = c.ends == "captured" and c.to <= ln.to
            function g.H(x)
                local h
                if x <= g.xa then h = here and 0 or 1
                elseif g.ramp > 0 and x < g.xa + g.ramp then h = 0.5 - 0.5 * cos(pi * (x - g.xa) / g.ramp)
                else h = 1 end
                if captured and x > g.xb - 9 then h = h + (L.rise - 1) * min(1, (x - (g.xb - 9)) / 9) ^ 1.5 end
                return h
            end
            function g.At(t)
                local x = X(t)
                return x, ln.Y + g.s * L.lift * g.H(min(x, g.xl))
            end
            if captured then
                g.cap = { x = g.xb + 3, y = ln.Y + g.s * (L.lift * L.rise + R.ringOff) }
            end
            for _, d in ipairs(g.drops) do d.y = ln.Y + g.s * L.lift end
            out[#out + 1] = g
            by[c] = g
        end
    end
    return out, by
end

-- Where second t of `carry` lies on line `ln`: on its branch while the
-- carry is out (a second either side), else on the base line.
function SP.Where(ln, by, t, carry)
    local g = carry and by[carry]
    if g and t >= carry.from - 1 and t <= carry.to + 3 then return g.At(min(t, carry.to)) end
    return ln.X(t), ln.Y
end

-- The base line's pieces: from the line's start to its end, broken `gap` px
-- either side of each capture inside it (the circled score's gap). Returns
-- { { xa, xb } } and the captures' x.
function SP.Base(story, ln)
    local G = STORY.lines.gap
    local cuts = {}
    for _, cap in ipairs(story.caps or {}) do
        if cap.t > ln.from and cap.t < ln.to then cuts[#cuts + 1] = ln.X(cap.t) end
    end
    table.sort(cuts)
    local out, x = {}, ln.X(ln.from)
    for _, cx in ipairs(cuts) do
        out[#out + 1] = { xa = x, xb = cx - G }
        x = cx + G
    end
    -- (the match ended on its last capture where what follows it is
    -- shorter than a phase of its own, Story.PHASE.tail: the board's few
    -- seconds; the line ends at the capture's gap then)
    local last = story.caps and story.caps[#story.caps]
    local tail = ns.MatchStory and ns.MatchStory.PHASE.tail or 30
    if last and last.t > ln.from and last.t <= ln.to and ln.to - last.t < tail then
        local cx = ln.X(last.t) - G
        if #cuts > 0 and abs(cuts[#cuts] - ln.X(last.t)) < 0.5 then
            out[#out].xb = cx
            return out
        end
        out[#out + 1] = { xa = x, xb = cx }
        return out
    end
    out[#out + 1] = { xa = x, xb = ln.X(ln.to) }
    return out
end

--------------------------------------------------------------------------
-- The stains
--------------------------------------------------------------------------

-- A fight's darkness, 0..1: Ink.FightScore's curve (the trail's) with the
-- page's knee and full (STORY.stain), over seconds plus `death` a death.
function SP.Score(seconds, deaths)
    local S = STORY.stain
    local m = ((seconds or 0) + S.death * (deaths or 0)) / 60
    return Clamp(log(1 + m / S.knee) / log(1 + S.full / S.knee), 0, 1)
end

-- The fights of line `ln` merged into stains: { a, b (seconds), secs, n
-- (most people in one of its fights), carry, zerg, fights, deaths, F,
-- pieces = { { x, y, a1, a2, F, deaths = { { x, y } } } } } in time order.
-- A fight is the line's where it starts in it.
function SP.Stains(story, ln, by)
    local S, L = STORY.stain, STORY.lines
    local fights = {}
    for _, x in ipairs(story.fights or {}) do
        if x.from >= ln.from - 1 and x.from < ln.to then fights[#fights + 1] = x end
    end
    table.sort(fights, function(a, b) return a.from < b.from end)
    local pps, groups = ln.pps, {}
    for _, x in ipairs(fights) do
        local b = min(x.to, ln.to)
        local z = (x.zerg and not x.carry) and true or false
        local g
        for _, q in ipairs(groups) do
            if q.carry == x.carry and q.zerg == z then
                local near = (x.from - q.b) * pps <= (z and S.zerg or S.join)
                if near and (z or (b - q.a) * pps <= S.span) then g = q end
            end
        end
        if g then
            g.b = max(g.b, b)
            g.secs = g.secs + (x.to - x.from)
            g.n = max(g.n, x.n or (#x.us + #x.them))
            g.fights[#g.fights + 1] = x
        else
            g = { a = x.from, b = b, secs = x.to - x.from, n = x.n or (#x.us + #x.them), carry = x.carry, zerg = z,
                fights = { x } }
            groups[#groups + 1] = g
        end
    end
    local most = max(S.mostLeast, L.lift * S.most)
    for _, g in ipairs(groups) do
        g.deaths = {}
        for _, x in ipairs(g.fights) do
            for _, d in ipairs(x.deaths or {}) do g.deaths[#g.deaths + 1] = d end
        end
        g.F = SP.Score(g.secs, #g.deaths)
        -- Laid in pieces no longer than `piece`: each its own blot, with the
        -- F of the fights in it (a zerg deepens at each fight).
        local xa, xb = ln.X(g.a), ln.X(g.b)
        local len = max(xb - xa, 0)
        local n = max(1, math.ceil(len / S.piece))
        local step = len / n
        g.pieces = {}
        for k = 1, n do
            local pa, pb = xa + (k - 1) * step, xa + k * step
            local ta, tb = g.a + (pa - xa) / pps, g.a + (pb - xa) / pps
            local secs, dead, people = 0, {}, 0
            for _, x in ipairs(g.fights) do
                local o = max(0, min(x.to, tb) - max(x.from, ta))
                if o > 0 or (n == 1) then
                    secs = secs + (n == 1 and (x.to - x.from) or o)
                    people = max(people, x.n or (#x.us + #x.them))
                end
            end
            for _, d in ipairs(g.deaths) do
                if (d.t >= ta - 1 and d.t < tb + 1) or n == 1 then dead[#dead + 1] = d end
            end
            -- (a stretch of a zerg with no fight in it is the run between
            -- fights: the faintest rust)
            local F = n == 1 and g.F or SP.Score(secs * n, #dead)
            local least = S.least[1] + S.least[2] * F
            local half = (pb - pa) / 2 + (n > 1 and S.overlap or 0)
            local a1 = max(half + (n == 1 and S.bleed * F or 0), least)
            local a2 = max(least, min(most, max(S.across[1] + S.across[2] * max(people, g.n * 0.5), a1 / S.aspect)))
            local tm = (ta + tb) / 2
            local x, y = SP.Where(ln, by, tm, g.carry)
            local p = { x = (pa + pb) / 2, y = y, a1 = a1, a2 = a2, F = F, deaths = {} }
            for _, d in ipairs(dead) do
                local dx, dy = SP.Where(ln, by, d.t, g.carry)
                p.deaths[#p.deaths + 1] = { x = Clamp(dx, p.x - a1 + 1, p.x + a1 - 1), y = dy }
            end
            g.pieces[k] = p
        end
        g.x, g.y = SP.Where(ln, by, (g.a + g.b) / 2, g.carry)
        g.w = max(len, 6)
    end
    return groups
end

--------------------------------------------------------------------------
-- The crosses
--------------------------------------------------------------------------

-- Every death on line `ln`: { x, y, t, who (a reference; "0" you), side
-- ("us", "them"), you, killer, carrier (a carrier's own at its drop) }.
-- A fight's deaths in its place (ours `off` px over the path, theirs under
-- it); a carrier's at their hold's end, on the branch; your deaths the
-- record has outside any fight on your path then. Stepped aside where two
-- would meet.
function SP.Crosses(story, ln, branches, by)
    local C = STORY.cross
    local out = {}
    local function Add(d)
        for _, o in ipairs(out) do
            if abs(o.x - d.x) < C.apart and abs(o.y - d.y) < C.apart then d.x = o.x + C.apart + 1 end
        end
        out[#out + 1] = d
    end
    local dropped = {}
    for _, g in ipairs(branches) do
        for _, d in ipairs(g.drops) do
            dropped[#dropped + 1] = d
            Add({ x = d.x, y = d.y, t = d.t, who = d.who, side = g.c.side, you = d.who == "0", carrier = true })
        end
    end
    local function Dropped(d)
        for _, q in ipairs(dropped) do
            if q.who == d.who and abs(q.t - d.t) <= 3 then return true end
        end
        return false
    end
    local yours = {}
    for _, x in ipairs(story.fights or {}) do
        for _, d in ipairs(x.deaths or {}) do
            if d.who == "0" then yours[#yours + 1] = d.t end
            if d.t >= ln.from and (d.t < ln.to or (ln.i == 2 and d.t <= ln.to)) and not Dropped(d) then
                local px, py = SP.Where(ln, by, d.t, d.carry)
                local up = d.side == "us"
                Add({ x = px, y = py + (up and -C.off or C.off), t = d.t, who = d.who, side = d.side, you = d.who == "0",
                    killer = d.killer })
            end
        end
    end
    -- Yours the record has from PLAYER_DEAD with no fight of the meter's.
    for _, m in ipairs(story.mine or {}) do
        local seen = false
        for _, t in ipairs(yours) do if abs(t - m.t) <= 3 then seen = true end end
        if not seen and m.t >= ln.from and m.t < ln.to then
            local px, py = SP.Where(ln, by, m.t, m.carry)
            Add({ x = px, y = py - C.off, t = m.t, who = "0", side = "us", you = true, killerName = m.killer })
        end
    end
    table.sort(out, function(a, b) return a.t < b.t end)
    return out
end

--------------------------------------------------------------------------
-- The names over the line
--------------------------------------------------------------------------

-- The phases' names and the zerg's over line `ln`, by the proposal's rule:
-- a phase's name at its stretch's start; where a zerg is part of it, the
-- zerg's name over the zerg's start, and the phase's keeps its place only
-- with room before the zerg, else moves to where the zerg ends, else is
-- left out (the zerg's stands). A name never starts past its stretch's end
-- nor runs past `nameEnd`; two that would meet keep the zerg's, else the
-- earlier. `widthOf(key)` measures a name ("zerg" the zerg's). Returns { {
-- key, x (its left), y (its middle) } }.
function SP.Names(story, ln, widthOf)
    local L = STORY.lines
    local y = ln.Y - L.lift * L.rise - L.names
    local cands = {}
    local z = story.zerg
    for _, p in ipairs(story.phases or {}) do
        if p.from < ln.to and p.to > ln.from then
            local xa = ln.X(max(p.from, ln.from)) + (p.from > ln.from and L.gap or 0) + 2
            local xb = ln.X(min(p.to, ln.to))
            local w = widthOf(p.key)
            local nx = xa
            if z and z.from >= p.from and z.to <= p.to and z.from >= ln.from and z.from < ln.to then
                local zx, zw = ln.X(z.from) + 2, widthOf("zerg")
                cands[#cands + 1] = { key = "zerg", x = min(zx, L.nameEnd - zw), w = zw, keep = 1, xb = ln.X(z.to) }
                if zx - xa < w + L.room then
                    local after = ln.X(z.to) + 2
                    nx = (after >= zx + zw + L.room and after < xb) and after or nil
                end
            end
            if nx then cands[#cands + 1] = { key = p.key, x = min(nx, L.nameEnd - w), w = w, keep = 2, xb = xb } end
        end
    end
    table.sort(cands, function(a, b) return a.x < b.x end)
    local out = {}
    for _, c in ipairs(cands) do
        local prev = out[#out]
        if c.x > c.xb then
            -- (it would start past its own stretch)
        elseif prev and c.x < prev.x + prev.w + L.room then
            if c.keep < prev.keep then out[#out] = c end
        else
            out[#out + 1] = c
        end
    end
    for _, c in ipairs(out) do c.y = y end
    return out
end

--------------------------------------------------------------------------
-- The band of strips
--------------------------------------------------------------------------

-- The band's size of strip `s`: "L" or "M".
function SP.Size(s)
    return STORY.sizes[s.kind] or "M"
end

-- Line `ln`'s strips in a row (round 5's S1): in time order, at their own
-- sizes while they fit `x0`..`x1` `apart` px apart (an L drawn M first, then
-- the commonest left out), each centred on its moment's x (`xOf(s)`) as
-- far as the one before lets it, then pushed back from the right. Returns
-- { { s, band, w, x } }.
function SP.Row(strips, xOf)
    local B = STORY.band
    local row = {}
    for _, s in ipairs(strips or {}) do row[#row + 1] = { s = s, band = SP.Size(s) } end
    table.sort(row, function(a, b) return (a.s.t or 0) < (b.s.t or 0) end)
    local function Fits()
        local total = 0
        for _, r in ipairs(row) do r.w = B[r.band]; total = total + r.w end
        return #row <= B.most and total + max(0, #row - 1) * B.apart <= B.x1 - B.x0
    end
    while #row > 0 and not Fits() do
        local big
        for _, r in ipairs(row) do if r.band == "L" then big = big or r end end
        if big and #row <= B.most then
            big.band = "M"
        else
            local worst, at = nil, nil
            for k, r in ipairs(row) do
                if not worst or (r.s.rank or 99) > (worst.s.rank or 99)
                    or ((r.s.rank or 99) == (worst.s.rank or 99) and (r.s.t or 0) > (worst.s.t or 0)) then
                    worst, at = r, k
                end
            end
            table.remove(row, at)
        end
    end
    local x = B.x0
    for _, r in ipairs(row) do
        r.x = max(x, min(B.x1 - r.w, xOf(r.s) - r.w / 2))
        x = r.x + r.w + B.apart
    end
    local lim = B.x1
    for k = #row, 1, -1 do
        local r = row[k]
        r.x = min(r.x, lim - r.w)
        lim = r.x - B.apart
    end
    return row
end

-- The leader from a strip at box `b` ({ x, y, w, h }) to the point x, y:
-- out of the strip's nearest edge (its top, held `inset` px in from its
-- ends; its foot where the point is under it), a little short of the point.
-- Returns the flat points of its bow (x, y, ...) and its end.
function SP.Leader(b, x, y, stop, n)
    local inset = 10
    local fx = Clamp(x, b.x + inset, b.x + b.w - inset)
    local fy = y < b.y and b.y or b.y + b.h
    local d = math.sqrt((x - fx) ^ 2 + (y - fy) ^ 2)
    if d < 1 then d = 1 end
    local ex, ey = x - (x - fx) / d * stop, y - (y - fy) / d * stop
    local pts = {}
    n = n or 12
    local bend = (ex - fx) * 0.05
    for i = 0, n do
        local t = i / n
        pts[#pts + 1] = fx + (ex - fx) * t
        pts[#pts + 1] = fy + (ey - fy) * t - math.sin(t * pi) * bend
    end
    return pts, ex, ey
end
