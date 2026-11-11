-- A Warsong match told by time (.claude/ui-proposal/battleground-page-v2.md,
-- rounds 1-8, Jan's decisions in .claude/features/battlegrounds.md): the
-- record's flag lines and fights (Core/Matches.lua's story substrate) read
-- back as a story the page draws (UI/Journey/Match.lua) and the tests
-- (tests/match_story.lua) check offline. Pure: it reads the record and the
-- diary, never the client.
--
--   carries   a pick-up forks a branch: ours over the line (we carry their
--             flag), theirs under it. A carry is the flag's whole time out:
--             its holds (pick-up to drop or capture), the lying between them
--             (a drop, then picked up again), and its end: "captured" (the
--             branch rises into the circled score, the base line gaps),
--             "returned" (back down onto the base line), "reset" or "open"
--             (the match ended with it out).
--   fights    the user's fights from the meter, each tied to a carry by the
--             sociogram (Tie, below) or left on the base line.
--   phases    a capture ends each; named by what happened in it (`key`,
--             worded by the page).
--   zerg      the longest stretch with no flag out that is a zerg (ZERG).
--   lines     the match in two at the capture nearest its middle.
--   strips    the social moments, ranked by rarity (KINDS), three a line.
--
-- Every time here is seconds after the gates opened (the record's are after
-- startedAt; Start converts).

local addonName, ns = ...

local Story = {}
ns.MatchStory = Story

local Matches

-- The sociogram's numbers (round 8; proposals, open question 1): a fight
-- joins a carry's when it shares `shared` people besides you with one of
-- the carry's fights no more than `gap` seconds from it. `near`: a carry
-- whose carrier was near you for this many seconds (nameplate, target,
-- raid range; probe round 4, unproven) takes the fights inside it no other
-- carry claims, because you were with the carrier (Jan, 10 Nov).
Story.LINK = { shared = 2, gap = 60, near = 10 }

-- The zerg (rounds 7-8): a stretch with no flag out (neither carried nor
-- lying), at least `share` of the match and `floor` seconds, with at least
-- `fights` of your fights filling `fought` of it. The floor and density are
-- proposals (open question 2).
Story.ZERG = { share = 0.25, floor = 240, fights = 6, fought = 0.3 }

-- The strips' thresholds (round 5, accepted): a carry of yours counts past
-- `carry` seconds (or brought home); outnumbered is twice as many and at
-- least `more` more; one on one is `duel` seconds or longer; fell together
-- is two deaths `together` seconds apart; a nemesis killed you `nemesis`
-- times; across the evening from the sitting's `evening`th match.
Story.STRIP = { carry = 20, more = 2, duel = 10, together = 5, nemesis = 3, evening = 3, perLine = 3 }

-- A trailing stretch after the last capture is a phase of its own when it
-- is this long (the clock ran out on it); a stand-off is a phase this long
-- or a third of the match; both flags out counts past `both` seconds.
Story.PHASE = { tail = 30, standoff = 360, both = 30 }

-- The kinds, rarest first (round 5: the order by rarity until capture has
-- counted real matches; `est` is the estimate per Warsong). Fell together
-- is last whatever its number, and at most once a page.
Story.KINDS = {
    { kind = "friend", est = 0.05 },       -- a diary person killed you
    { kind = "nemesis", est = 0.1 },       -- one enemy, 3+ times, you never got them
    { kind = "zerg", est = 0.15 },         -- The Zerg
    { kind = "acquaintance", est = 0.2 },  -- a diary person beside you, from the world
    { kind = "evening", est = 0.2 },       -- a stranger, the third match tonight
    { kind = "duel", est = 0.3 },          -- you against one, 10 s or more
    { kind = "revenge", est = 0.3 },       -- one of ours killed who killed you
    { kind = "person", est = 0.4 },        -- a diary person, either side
    { kind = "carry", est = 0.4 },         -- you carried their flag
    { kind = "return", est = 0.6 },        -- you brought ours back
    { kind = "outnumbered", est = 0.9 },   -- two against four
    { kind = "escort", est = 1.2 },        -- you ran with our carrier
    { kind = "together", est = 9 },        -- you and someone fell together
}
local RANK = {}
for i, k in ipairs(Story.KINDS) do RANK[k.kind] = i end
Story.RANK = RANK

--------------------------------------------------------------------------
-- Reading the record
--------------------------------------------------------------------------

-- When the gates opened, in seconds after startedAt.
local function Start(match)
    if match.t0 then return match.t0 end
    local ended = match.completeAt or match.endedAt
    if ended and match.duration and match.startedAt then
        return math.max(0, (ended - match.startedAt) - match.duration)
    end
    return 0
end

-- Does the record carry a story (a Warsong with flag lines or fights)?
function Story.Has(match)
    Matches = Matches or ns.Matches
    if not match or match.map ~= 489 then return false end
    return (match.flags and #match.flags > 0) or (match.fights and #match.fights > 0) or false
end

local function Member(list, ref)
    for _, r in ipairs(list) do if r == ref then return true end end
    return false
end

--------------------------------------------------------------------------
-- Carries
--------------------------------------------------------------------------

local function Carries(story, flags, us)
    local open, list, caps = {}, {}, {}
    local score = { us = 0, them = 0 }
    local n = 0
    local function Close(c, t, how, by)
        local h = c.holds[#c.holds]
        if h and not h.to then h.to = t end
        c.to, c.ends, c.by = t, how, by
        open[c.flag] = nil
    end
    for _, e in ipairs(flags) do
        local t = e.t
        if e.kind == "p" and e.flag then
            local c = open[e.flag]
            if c then
                local h = c.holds[#c.holds]
                if h and not h.to then h.to, h.dropped = t, true end   -- a drop line missed
                if h then c.lying[#c.lying + 1] = { from = h.to, to = t } end
            else
                n = n + 1
                -- Carrying the other side's flag: theirs is ours to carry.
                c = { n = n, flag = e.flag, side = (e.flag ~= us) and "us" or "them", from = t, holds = {}, lying = {} }
                open[e.flag] = c
                list[#list + 1] = c
            end
            c.holds[#c.holds + 1] = { from = t, who = e.who, near = e.near }
            if e.near then c.near = (c.near or 0) + e.near end
        elseif e.kind == "d" and e.flag and open[e.flag] then
            local h = open[e.flag].holds[#open[e.flag].holds]
            if h and not h.to then h.to, h.dropped = t, true end
        elseif e.kind == "r" and e.flag and open[e.flag] then
            local c = open[e.flag]
            local h = c.holds[#c.holds]
            if h and h.to then c.lying[#c.lying + 1] = { from = h.to, to = t } end
            Close(c, t, "returned", e.who)
        elseif e.kind == "c" and e.flag and open[e.flag] then
            local c = open[e.flag]
            Close(c, t, "captured", e.who)
            score[c.side] = score[c.side] + 1
            caps[#caps + 1] = { t = t, side = c.side, carry = c, by = e.who, us = score.us, them = score.them }
            c.score = { us = score.us, them = score.them }
        elseif e.kind == "x" then
            for _, c in pairs(open) do Close(c, t, "reset") end
        end
    end
    for _, c in pairs(open) do
        local h = c.holds[#c.holds]
        if h and h.to then c.lying[#c.lying + 1] = { from = h.to, to = story.T } end
        Close(c, story.T, "open")
    end
    -- Who carried it, and for how long, in all.
    for _, c in ipairs(list) do
        c.held = {}
        for _, h in ipairs(c.holds) do
            if h.who then c.held[h.who] = (c.held[h.who] or 0) + ((h.to or c.to) - h.from) end
        end
    end
    story.carries, story.caps, story.score = list, caps, score
end

-- The carry whose span holds second t (and, with `flagSide`, of that side).
local function CarryAt(story, t, side)
    for _, c in ipairs(story.carries) do
        if t >= c.from and t <= c.to and (side == nil or c.side == side) then return c end
    end
end

-- Was `ref` carrying c at some second inside [a, b]?
local function Carrying(c, ref, a, b)
    for _, h in ipairs(c.holds) do
        if h.who == ref and h.from <= b and (h.to or c.to) >= a then return true end
    end
    return false
end

--------------------------------------------------------------------------
-- Fights, and what belongs to a branch (the sociogram)
--------------------------------------------------------------------------

local function Fights(story, match, t0)
    local list = {}
    for _, f in ipairs(Matches.Fights(match)) do
        local x = { from = f.t - t0, to = f.t - t0 + f.dur, us = f.us, them = f.them, deaths = {} }
        x.n = #x.us + #x.them
        if not Member(x.us, "0") then x.us[#x.us + 1] = "0" x.n = x.n + 1 end   -- you were in it
        for _, d in ipairs(f.deaths) do
            x.deaths[#x.deaths + 1] = { who = d.who, t = d.at - t0, killer = d.killer,
                side = Member(x.them, d.who) and "them" or "us", fight = x }
        end
        list[#list + 1] = x
    end
    story.fights = list
end

local function Gap(x, y)
    return math.max(x.from - y.to, y.from - x.to, 0)
end

local function Shared(x, y)
    local n = 0
    for _, side in ipairs({ x.us, x.them }) do
        for _, r in ipairs(side) do
            if r ~= "0" and (Member(y.us, r) or Member(y.them, r)) then n = n + 1 end
        end
    end
    return n
end

-- Inside c's time out?
local function Within(x, c)
    return x.from < c.to and x.to > c.from
end

-- Round 8's rule, Jan's sociogram: (1) a fight overlapping a carry with
-- its carrier among the fight's people is the carry's (the carry whose
-- carrier fell in it first, then ours); (2) a fight inside the same carry
-- that shares LINK.shared people besides you with one of its fights within
-- LINK.gap seconds is the carry's too, fight to fight, both ways (one that
-- came before is a late move: `moved`); (3) a carry whose carrier was near
-- you takes the fights inside it no one claimed (`near`); (4) the rest
-- stays on the base line. Deaths follow their fight; a carrier's own death
-- at its drop is its carry's.
local function Tie(story)
    local L = Story.LINK
    for _, x in ipairs(story.fights) do
        local hits = {}
        for _, c in ipairs(story.carries) do
            if Within(x, c) then
                for _, h in ipairs(c.holds) do
                    if h.who and (Member(x.us, h.who) or Member(x.them, h.who))
                        and h.from <= x.to and (h.to or c.to) >= x.from then
                        hits[#hits + 1] = c
                        break
                    end
                end
            end
        end
        local pick
        for _, c in ipairs(hits) do
            for _, d in ipairs(x.deaths) do
                if Carrying(c, d.who, d.t - 2, d.t + 2) then pick = c end
            end
            if pick then break end
        end
        if not pick then
            for _, c in ipairs(hits) do if c.side == "us" then pick = c break end end
        end
        x.carry = pick or hits[1]
    end
    local again = true
    while again do
        again = false
        for _, x in ipairs(story.fights) do
            if not x.carry then
                for _, y in ipairs(story.fights) do
                    local c = y.carry
                    if c and y ~= x and Within(x, c) and Gap(x, y) <= L.gap and Shared(x, y) >= L.shared then
                        x.carry, x.moved, x.linked = c, x.from < y.from, true
                        again = true
                        break
                    end
                end
            end
        end
    end
    for _, x in ipairs(story.fights) do
        if not x.carry then
            for _, c in ipairs(story.carries) do
                if (c.near or 0) >= L.near and Within(x, c) then x.carry, x.near = c, true break end
            end
        end
    end
    for _, x in ipairs(story.fights) do
        for _, d in ipairs(x.deaths) do
            d.carry = x.carry
            for _, c in ipairs(story.carries) do
                for _, h in ipairs(c.holds) do
                    if h.dropped and h.who == d.who and math.abs((h.to or 0) - d.t) <= 2 then
                        d.carry, d.own = c, true
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------
-- The Zerg
--------------------------------------------------------------------------

local function Zerg(story)
    local Z, T = Story.ZERG, story.T
    if T <= 0 then return end
    -- The stretches with a flag out, merged; the rest is free.
    local out = {}
    for _, c in ipairs(story.carries) do out[#out + 1] = { from = c.from, to = c.to } end
    table.sort(out, function(a, b) return a.from < b.from end)
    local free, at = {}, 0
    for _, o in ipairs(out) do
        if o.from > at then free[#free + 1] = { from = at, to = o.from } end
        at = math.max(at, o.to)
    end
    if T > at then free[#free + 1] = { from = at, to = T } end
    local best
    for _, s in ipairs(free) do
        local len = s.to - s.from
        if len >= Z.share * T and len >= Z.floor then
            local n, secs = 0, 0
            for _, x in ipairs(story.fights) do
                if x.from >= s.from and x.to <= s.to then n, secs = n + 1, secs + (x.to - x.from) end
            end
            if n >= Z.fights and secs >= Z.fought * len and (not best or len > best.to - best.from) then
                best = { from = s.from, to = s.to, fights = n }
            end
        end
    end
    if best then
        best.ours, best.theirs = 0, 0
        for _, x in ipairs(story.fights) do
            if x.from >= best.from and x.to <= best.to then
                x.zerg = true
                for _, d in ipairs(x.deaths) do
                    if d.side == "them" then best.theirs = best.theirs + 1 else best.ours = best.ours + 1 end
                end
            end
        end
    end
    story.zerg = best
end

--------------------------------------------------------------------------
-- Phases and lines
--------------------------------------------------------------------------

local function Overlap(a1, a2, b1, b2)
    return math.max(0, math.min(a2, b2) - math.max(a1, b1))
end

local function Phases(story)
    local P, T = Story.PHASE, story.T
    local phases, from = {}, 0
    for _, cap in ipairs(story.caps) do
        phases[#phases + 1] = { from = from, to = cap.t, cap = cap }
        from = cap.t
    end
    if T - from >= P.tail or #phases == 0 then phases[#phases + 1] = { from = from, to = T } end
    local final = story.caps[#story.caps]
    for i, p in ipairs(phases) do
        local len = p.to - p.from
        -- Both flags out at once, for how long.
        local both = 0
        for _, a in ipairs(story.carries) do
            for _, b in ipairs(story.carries) do
                if a.side == "us" and b.side == "them" then
                    both = both + Overlap(math.max(a.from, p.from), math.min(a.to, p.to), b.from, b.to)
                end
            end
        end
        -- A carry of the scoring side broken (dropped and returned) in it.
        local broken = false
        for _, c in ipairs(story.carries) do
            if c.ends == "returned" and c.to > p.from and c.to <= p.to and #c.holds > 0 then broken = true end
        end
        local cap = p.cap
        if #phases == 1 then
            p.key = cap and "lastflag" or "nocap"
        elseif not cap then
            p.key = "clock"
        elseif cap == final and (cap.us == 3 or cap.them == 3) then
            p.key = "lastflag"
        elseif i == 1 then
            p.key = "opening"
        elseif len >= math.max(P.standoff, T / 3) then
            p.key = "standoff"
        elseif cap.us == cap.them then
            p.key = "level"
        elseif both >= P.both then
            p.key = "bothout"
        elseif broken then
            p.key = "broken"
        else
            p.key = cap.side == "us" and "ours" or "theirs"
        end
        p.index = i
    end
    story.phases = phases
end

-- In two at the capture nearest the middle (none: at the middle).
local function Lines(story)
    local T, cut = story.T, nil
    for _, cap in ipairs(story.caps) do
        if cap.t < T and (not cut or math.abs(cap.t - T / 2) < math.abs(cut - T / 2)) then cut = cap.t end
    end
    cut = cut or T / 2
    story.lines = { { from = 0, to = cut, strips = {} }, { from = cut, to = T, strips = {} } }
end

--------------------------------------------------------------------------
-- The strips
--------------------------------------------------------------------------

-- Each person's first moment on the page: a fight they were in, a flag
-- line of theirs.
local function FirstSeen(story, ref)
    local t
    for _, x in ipairs(story.fights) do
        if (Member(x.us, ref) or Member(x.them, ref)) and (not t or x.from < t) then t = x.from end
    end
    for _, c in ipairs(story.carries) do
        for _, h in ipairs(c.holds) do
            if h.who == ref and (not t or h.from < t) then t = h.from end
        end
    end
    return t
end

local function Candidates(story, match, ctx, opts)
    local S, out = Story.STRIP, {}
    -- A person is one key on the page: their diary GUID, else their name's.
    local function Add(s)
        s.rank = RANK[s.kind]
        if s.person and s.name and type(s.name) == "string" then s.person = ctx.Who(s.name) or s.person end
        out[#out + 1] = s
    end
    local Name = ctx.Name

    -- Your deaths and who dealt them: the record's own (PLAYER_DEAD's recap)
    -- and the meter's, one per death (the meter's within 3 s of a recorded
    -- one is the same death).
    local mine = {}
    for _, x in ipairs(story.fights) do
        for _, d in ipairs(x.deaths) do
            if d.who == "0" then mine[#mine + 1] = { t = d.t, killer = d.killer and Name(d.killer), carry = d.carry } end
        end
    end
    local t0 = story.t0
    for i, at in ipairs(match.deaths or {}) do
        local t = at - (match.startedAt or 0) - t0
        local dup
        for _, m in ipairs(mine) do if math.abs(m.t - t) <= 3 then dup = m end end
        local killer = match.killers and match.killers[i]
        if dup then dup.killer = dup.killer or killer
        else mine[#mine + 1] = { t = t, killer = killer, carry = CarryAt(story, t) } end
    end
    table.sort(mine, function(a, b) return a.t < b.t end)
    story.mine = mine

    -- Who you killed: an enemy's death whose recap names you.
    local got = {}
    for _, x in ipairs(story.fights) do
        for _, d in ipairs(x.deaths) do
            if d.killer == "0" and d.who ~= "0" then
                local n = Name(d.who)
                if n then got[Matches.Key(n)] = (got[Matches.Key(n)] or 0) + 1 end
            end
        end
    end
    story.kills = got

    local byKiller = {}
    for _, m in ipairs(mine) do
        if m.killer then
            local k = Matches.Key(m.killer)
            byKiller[k] = byKiller[k] or { name = m.killer, times = {} }
            local list = byKiller[k].times
            list[#list + 1] = m
        end
    end
    for k, b in pairs(byKiller) do
        local guid = ctx.Who(b.name)
        local last = b.times[#b.times]
        local times = {}
        for _, m in ipairs(b.times) do times[#times + 1] = m.t end
        if guid then
            Add({ kind = "friend", person = guid, guid = guid, name = b.name, times = times, t = last.t, carry = last.carry })
        elseif #b.times >= S.nemesis and not got[k] then
            Add({ kind = "nemesis", person = k, name = b.name, times = times, t = last.t, carry = last.carry })
        end
    end

    if story.zerg then
        local z = story.zerg
        Add({ kind = "zerg", t = (z.from + z.to) / 2, from = z.from, to = z.to, fights = z.fights,
            ours = z.ours, theirs = z.theirs })
    end

    -- Diary people, on either side: from the board's rows and the story's
    -- names.
    local seenPeople = {}
    local function Person(guid, name, side, ref)
        if not guid or guid == match.me or seenPeople[guid] then return end
        seenPeople[guid] = true
        local t = ref and FirstSeen(story, ref)
        if side == "with" and ctx.FromWorld(guid) then
            Add({ kind = "acquaintance", person = guid, guid = guid, name = name, t = t or 0, carry = t and CarryAt(story, t, "us") })
        end
        Add({ kind = "person", person = guid, guid = guid, name = name, side = side, t = t or 0, carry = t and CarryAt(story, t) })
    end
    for _, p in ipairs(Matches.Players(match)) do
        local guid = Matches.Who(p, ctx.names)
        if guid then Person(guid, p.name, Matches.Side(match, p), ctx.RefOf(p.name)) end
    end
    for i, n in ipairs(match.pool or {}) do
        if n ~= "" then
            local guid = ctx.Who(n)
            if guid then Person(guid, n, ctx.SideOf(tostring(i)), tostring(i)) end
        end
    end

    -- Across the evening: an enemy or stranger in this sitting's third
    -- match (or later) with them, never a diary person.
    if ctx.session and ctx.position and ctx.position >= S.evening then
        local counted = {}
        for _, p in ipairs(Matches.Players(match)) do
            local k = Matches.Key(p.name)
            if k and not counted[k] and p.guid ~= match.me and k ~= Matches.Key(opts.own)
                and not Matches.Who(p, ctx.names) then
                counted[k] = true
                local n = 0
                for _, m in ipairs(ctx.session.matches) do
                    if (m.startedAt or 0) <= (match.startedAt or 0) then
                        for _, s in ipairs(m.players) do
                            local q = Matches.Unpack(s)
                            if Matches.SameName(q.name, p.name) then n = n + 1 break end
                        end
                    end
                end
                if n >= S.evening then
                    local ref = ctx.RefOf(p.name)
                    local t = ref and FirstSeen(story, ref)
                    Add({ kind = "evening", person = k, name = p.name, count = n, side = Matches.Side(match, p),
                        t = t or story.T, carry = t and CarryAt(story, t) })
                end
            end
        end
    end

    for _, x in ipairs(story.fights) do
        local len = x.to - x.from
        -- One on one: only you and one enemy in the meter, 10 s or more.
        if len >= S.duel and #x.us == 1 and #x.them == 1 then
            local foe, won = x.them[1], nil
            for _, d in ipairs(x.deaths) do
                if d.who == foe then won = true elseif d.who == "0" then won = false end
            end
            Add({ kind = "duel", person = Name(foe) and Matches.Key(Name(foe)), name = Name(foe), t = (x.from + x.to) / 2,
                secs = len, won = won, fight = x, carry = x.carry })
        end
        -- Outnumbered: twice as many of them, and at least two more.
        if #x.them >= 2 * #x.us and #x.them >= #x.us + S.more then
            Add({ kind = "outnumbered", t = (x.from + x.to) / 2, us = #x.us, them = #x.them, secs = len,
                fight = x, carry = x.carry })
        end
    end

    -- Revenge: someone who killed you dies later, by one of ours.
    for _, x in ipairs(story.fights) do
        for _, d in ipairs(x.deaths) do
            local n = Name(d.who)
            local b = n and byKiller[Matches.Key(n)]
            if b and d.killer and d.side == "them" and b.times[1].t < d.t then
                local by = d.killer == "0" and true or Name(d.killer)
                if by then
                    -- No `person`: the one avenged has their own strip
                    -- beside it (round 5's "Halvard killed Feivel").
                    Add({ kind = "revenge", name = n, by = by, times = #b.times,
                        t = d.t, carry = d.carry })
                end
            end
        end
    end

    for _, c in ipairs(story.carries) do
        -- Carries: you carried their flag past 20 s, or brought it home.
        local yours = c.held["0"]
        if c.side == "us" and yours and (yours > S.carry or (c.ends == "captured" and c.by == "0")) then
            -- Pinned where your hold ended (a carry taken on by another ends later).
            local at = c.from
            for _, h in ipairs(c.holds) do if h.who == "0" then at = h.to or c.to end end
            Add({ kind = "carry", t = at, secs = yours, home = c.ends == "captured" and c.by == "0", carry = c })
        end
        -- Returns: you brought ours back; and whether you killed its carrier.
        if c.side == "them" and c.ends == "returned" and c.by == "0" then
            local last = c.holds[#c.holds]
            local killed
            for _, x in ipairs(story.fights) do
                for _, d in ipairs(x.deaths) do
                    if last and d.who == last.who and d.killer == "0" and math.abs(d.t - (last.to or c.to)) <= 5 then killed = true end
                end
            end
            local victim = last and last.who and Name(last.who)
            Add({ kind = "return", t = c.to, name = victim, killed = killed,
                person = killed and victim and Matches.Key(victim) or nil, carry = c })
        end
        -- Escort: you were with our carrier on their run (in a fight with
        -- them, or near them).
        if c.side == "us" then
            for who, secs in pairs(c.held) do
                if who ~= "0" then
                    local with = 0
                    for _, x in ipairs(story.fights) do
                        if Within(x, c) and Member(x.us, who) and Carrying(c, who, x.from, x.to) then
                            with = with + (x.to - x.from)
                        end
                    end
                    local near = 0
                    for _, h in ipairs(c.holds) do if h.who == who then near = near + (h.near or 0) end end
                    if with > 0 or near >= Story.LINK.near then
                        local n = Name(who)
                        Add({ kind = "escort", person = n and Matches.Key(n), name = n, secs = math.max(with, near),
                            home = c.ends == "captured" and c.by == who, t = c.to, carry = c })
                    end
                end
            end
        end
    end

    -- Fell together: you and one of ours within 5 s in one fight; only
    -- with a diary person or our carrier (or you carrying) in the carry's
    -- fight (round 5's limit).
    for _, x in ipairs(story.fights) do
        local me
        for _, d in ipairs(x.deaths) do if d.who == "0" then me = d end end
        if me then
            for _, d in ipairs(x.deaths) do
                if d.who ~= "0" and d.side == "us" and math.abs(d.t - me.t) <= S.together then
                    local n = Name(d.who)
                    local guid = n and ctx.Who(n)
                    local carrier = x.carry and x.carry.side == "us"
                        and (Carrying(x.carry, d.who, d.t - 2, d.t + 2) or Carrying(x.carry, "0", me.t - 2, me.t + 2))
                    if guid or carrier then
                        Add({ kind = "together", person = guid or (n and Matches.Key(n)), guid = guid, name = n,
                            apart = math.abs(d.t - me.t), t = math.max(d.t, me.t), carry = x.carry })
                    end
                end
            end
        end
    end
    return out
end

-- Round 5's crowded line: one person one strip a page (their rarest); fell
-- together once a page and only for someone with no other strip; a kind
-- once a line (the later); then by rank, three a line.
local function Choose(story, cands)
    table.sort(cands, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return (a.t or 0) > (b.t or 0)
    end)
    local person, together = {}, false
    local kept = {}
    for _, s in ipairs(cands) do
        local ok = true
        if s.person and person[s.person] then ok = false end
        if s.kind == "together" then
            if together then ok = false end
        end
        if ok then
            if s.person then person[s.person] = true end
            if s.kind == "together" then together = true end
            kept[#kept + 1] = s
        end
    end
    for _, line in ipairs(story.lines) do
        local kinds = {}
        for _, s in ipairs(kept) do
            local t = s.t or 0
            -- A line holds (from, to]: a moment at the capture it breaks
            -- on is the first line's, which that capture ends.
            local first, last = line == story.lines[1], line == story.lines[#story.lines]
            local inLine = (t > line.from or first) and (t <= line.to or last)
            if inLine and not kinds[s.kind] and #line.strips < Story.STRIP.perLine then
                kinds[s.kind] = true
                line.strips[#line.strips + 1] = s
            end
        end
        table.sort(line.strips, function(a, b) return (a.t or 0) < (b.t or 0) end)
    end
    story.candidates = cands
end

--------------------------------------------------------------------------
-- The story
--------------------------------------------------------------------------

-- The diary lookups the strips ask, built once per page.
local function Context(match, opts)
    local ctx = { names = Matches.DiaryNames() }
    local own = opts.own
    function ctx.Name(ref)
        if ref == "0" then return own end
        return Matches.RefName(match, ref)
    end
    local who = {}
    function ctx.Who(name)
        if not name then return nil end
        local k = Matches.Key(name)
        if who[k] == nil then who[k] = Matches.Who({ name = name }, ctx.names) or false end
        return who[k] or nil
    end
    function ctx.RefOf(name)
        local k = Matches.Key(name)
        for i, n in ipairs(match.pool or {}) do if Matches.Key(n) == k then return tostring(i) end end
    end
    function ctx.SideOf(ref)
        return ctx.sides[ref]
    end
    -- A diary person with a row from the world: grouped, traded, whispered
    -- (any exchange; Interactions.Count leaves out what was only seen).
    function ctx.FromWorld(guid)
        return guid and ns.Interactions and ns.Interactions.Count(guid) > 0 or false
    end
    ctx.session = opts.session or Matches.SessionOf(match)
    if ctx.session then
        for i, m in ipairs(ctx.session.matches) do if m == match then ctx.position = i end end
    end
    return ctx
end

-- The story of a match, or nil when it has none (Story.Has). opts.own is
-- the user's name ("you" in the strips); opts.session the sitting's
-- session (else looked up).
function Story.Build(match, opts)
    Matches = Matches or ns.Matches
    if not Story.Has(match) then return nil end
    opts = opts or {}
    local t0 = Start(match)
    local story = { match = match, t0 = t0 }
    local flags = Matches.Flags(match)
    for _, e in ipairs(flags) do e.t = math.max(0, e.t - t0) end
    local last = 0
    for _, e in ipairs(flags) do last = math.max(last, e.t) end
    story.T = math.max(match.duration or 0, last, 1)
    Carries(story, flags, match.faction)
    Fights(story, match, t0)
    for _, x in ipairs(story.fights) do
        story.T = math.max(story.T, x.to)
    end
    Tie(story)
    Zerg(story)
    Phases(story)
    Lines(story)
    local ctx = Context(match, opts)
    ctx.sides = {}
    for _, x in ipairs(story.fights) do
        for _, r in ipairs(x.us) do ctx.sides[r] = "with" end
        for _, r in ipairs(x.them) do ctx.sides[r] = "against" end
    end
    for _, c in ipairs(story.carries) do
        for _, h in ipairs(c.holds) do
            if h.who then ctx.sides[h.who] = c.side == "us" and "with" or "against" end
        end
    end
    story.Name = ctx.Name
    Choose(story, Candidates(story, match, ctx, opts))
    story.won = Matches.Won(match)
    return story
end
