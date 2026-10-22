-- The profile timeline (JNL-2) and its taxonomy (TLN-1 to TLN-10).
--
-- A busy evening leaves dozens of interaction rows, so the timeline is not a
-- list of rows. Every line belongs to one of four layers (prd.md, "JNL-2
-- Timeline taxonomy"):
--
--   diary event  "Added to the diary". Always top level, never inside an
--                episode and never the end of one.
--   episode      A stretch of time: a together session, an instance visit,
--                an exchange (a run of interactions outside any session),
--                seen around. A headline and a details line.
--   moment       One thing worth its own line inside its episode: a rare
--                killed, a trade with a green item or better, a death, a
--                level-up. Level-ups one after another are one line folded
--                (a "climb": low levels come minutes apart), each opened.
--   chatter      Counted on the episode's details line, listed only when the
--                episode is opened.
--
-- Notes the user wrote (TLN-10) sit outside the four: part of the run they
-- were written in, at the top of it, or a top-level line of their own.
--
-- This file decides the structure: which layer each thing is, which
-- activities an episode's headline names and so which moments are summed up
-- rather than given lines (TLN-6). The words are UI/Words/Timeline.lua's.
-- Everything is computed per read; nothing here is saved (TLN-1), so older
-- history follows any change to these rules.

local addonName, ns = ...

local Timeline = {}
ns.Timeline = Timeline

-- TLN-9: rows outside a session at most this far apart make one exchange,
-- once there are EXCHANGE_MIN of them. Fewer stay as single lines.
local EXCHANGE_GAP = 10 * 60
local EXCHANGE_MIN = 3
Timeline.EXCHANGE_GAP, Timeline.EXCHANGE_MIN = EXCHANGE_GAP, EXCHANGE_MIN

-- TLN-2: what an episode's headline may name, best first. Only rares rank
-- among fights; duels and PvP kills will be moments with no activity.
local RANK = { "quest", "rare", "group", "trade", "chat", "other" }
local RANK_OF = {}
for i, key in ipairs(RANK) do RANK_OF[key] = i end

local UNCOMMON = 2
Timeline.UNCOMMON = UNCOMMON

-- Where each row type sits is the kind's (Core/Rows.lua): `activity` is what
-- it adds to an episode's headline; `moment(row)` says whether this row
-- gets a line of its own; `hidden` keeps it off. A kind that says none of
-- them is chatter under "other", so a new capture path folds before anyone
-- gets round to placing it.
local OTHER = { activity = "other" }

local function TypeOf(row)
    local kind = ns.Rows.Get(row.type)
    if kind.activity or kind.moment or kind.hidden then return kind end
    return OTHER
end

--------------------------------------------------------------------------
-- Item quality (TLN-5)
--------------------------------------------------------------------------

-- Older clients colour links by quality instead of naming it.
local QUALITY_COLOUR = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}

-- From the stored link, so trades kept before this rule follow it too. Nil
-- when the link says nothing (a bare item name).
function Timeline.Quality(link)
    if type(link) ~= "string" then return nil end
    local quality = link:match("|cn[^:|]-IQ(%d+):")
    if quality then return tonumber(quality) end
    local colour = link:match("|c%x%x(%x%x%x%x%x%x)")
    return colour and QUALITY_COLOUR[colour:lower()] or nil
end

-- The best item on either side of a trade; -1 for gold or nothing.
function Timeline.TradeQuality(row)
    local best = -1
    local c = row.context or {}
    for _, side in ipairs({ c.given or {}, c.received or {} }) do
        for i = 1, #side do
            local quality = Timeline.Quality(side[i].link)
            if quality and quality > best then best = quality end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- Where an episode went
--------------------------------------------------------------------------

-- A session's zones, each once, in the order first reached, and without
-- the client's nameless "" (a loading screen). Older sessions kept a zone
-- every time it came round again (21 Oct, in the client: Stormwind City,
-- Deeprun Tram, Stormwind City, ... up to forty), so they are read through
-- this rather than changed.
function Timeline.Unique(zones)
    local out, seen = {}, {}
    for _, zone in ipairs(zones or {}) do
        if type(zone) == "string" and zone:find("%S") and not seen[zone] then
            seen[zone] = true
            out[#out + 1] = zone
        end
    end
    return out
end

local TRAVEL = { road = true, flight = true }

-- Where a session's time went, from the user's own road (Core/Journey.lua)
-- over its stretch: { zones = { { name, seconds, sub = { [subZone] =
-- seconds } } } in the order first reached, total, travel (seconds on the
-- road or in the air), first, last (names), timed = true }. Without a road
-- for that stretch, the session's own zones (or `zones`, read the same
-- way) in order and timed = false. Nothing is saved.
function Timeline.Zones(session, zones)
    local from, to = session.startedAt or 0, session.endedAt or ns.Now()
    local j = ns.db.journey and session.me and ns.db.journey[session.me]
    local out = { zones = {}, total = 0, travel = 0, timed = false }
    local byName = {}

    if j and ns.Journey and ns.Journey.All then
        for _, seg in ipairs(ns.Journey.All(j)) do
            local a, b = math.max(seg.from or 0, from), math.min(seg.to or seg.from or 0, to)
            local name = seg.kind ~= "dungeon" and ns.MapName(seg.mapID)
            if b > a and name then
                local seconds = b - a
                local zone = byName[name]
                if not zone then
                    zone = { name = name, seconds = 0, sub = {} }
                    byName[name] = zone
                    out.zones[#out.zones + 1] = zone
                end
                zone.seconds = zone.seconds + seconds
                if seg.subZone and seg.subZone ~= "" then
                    zone.sub[seg.subZone] = (zone.sub[seg.subZone] or 0) + seconds
                end
                out.total = out.total + seconds
                if TRAVEL[seg.kind] then out.travel = out.travel + seconds end
                out.first = out.first or name
                out.last = name
            end
        end
    end

    if out.total > 0 then
        out.timed = true
        return out
    end
    out.zones, out.first, out.last = {}, nil, nil
    for _, name in ipairs(Timeline.Unique(zones or session.zones)) do
        out.zones[#out.zones + 1] = { name = name, seconds = 0, sub = {} }
    end
    out.first = out.zones[1] and out.zones[1].name
    out.last = out.zones[#out.zones] and out.zones[#out.zones].name
    return out
end

--------------------------------------------------------------------------
-- How much an episode says (TLN-3)
--------------------------------------------------------------------------

-- Headline activities and details-line facts, by how long it lasted.
function Timeline.Budget(seconds)
    seconds = seconds or 0
    if seconds >= 2 * 60 * 60 then return 3, 6 end
    if seconds >= 30 * 60 then return 2, 4 end
    return 1, 3
end

local function AddItems(into, list)
    for i = 1, #(list or {}) do
        local item = list[i]
        local seen = into.byLink[item.link]
        if seen then
            seen.count = seen.count + (item.count or 1)
        else
            seen = { link = item.link, count = item.count or 1 }
            into.byLink[item.link] = seen
            into[#into + 1] = seen
        end
    end
end

-- What the episode's rows add up to, for its details line (UI/Words/Timeline.lua).
function Timeline.Tally(episode)
    local t = { chat = 0, trades = 0, chatterTrades = 0, other = 0,
        given = { byLink = {} }, received = { byLink = {} }, moneyGiven = 0, moneyReceived = 0 }

    for i = 1, #episode.all do
        local item = episode.all[i]
        if item.kind == "row" then
            if item.activity == "chat" then
                t.chat = t.chat + 1
            elseif item.activity == "trade" then
                local c = item.row.context or {}
                t.trades = t.trades + 1
                if not item.moment then t.chatterTrades = t.chatterTrades + 1 end
                AddItems(t.given, c.given)
                AddItems(t.received, c.received)
                t.moneyGiven = t.moneyGiven + (c.moneyGiven or 0)
                t.moneyReceived = t.moneyReceived + (c.moneyReceived or 0)
            elseif item.activity == "other" then
                t.other = t.other + 1
            end
        end
    end
    return t
end

--------------------------------------------------------------------------
-- Episodes
--------------------------------------------------------------------------

local function ByTime(a, b) return a.time < b.time end

-- Children are the episode's rows (and, for a session, its rares) as items.
-- Ranks what it did, takes the headline's share, and keeps a line only for
-- moments the headline does not already name.
-- A line of a kind that climbs (Core/Rows.lua's `climb`: the level-ups).
local function Climbing(item)
    return item.kind == "row" and ns.Rows.Get(item.row.type).climb == true
end

-- Folded, two or more level-ups in a row, with nothing between them, are
-- one line (a climb) at the first: at low levels they come minutes apart
-- and would fill the fold. Opened, each has its own line again.
local function Climbs(lines)
    local out, i = {}, 1
    while i <= #lines do
        local k = i
        while lines[k + 1] and Climbing(lines[i]) and Climbing(lines[k + 1]) do k = k + 1 end
        if k > i then
            local ups = {}
            for n = i, k do ups[#ups + 1] = lines[n] end
            out[#out + 1] = { kind = "climb", time = ups[1].time, ups = ups, depth = ups[1].depth, moment = true }
        else
            out[#out + 1] = lines[i]
        end
        i = k + 1
    end
    return out
end

-- Folded, an episode with DEATH_FOLD or more deaths shows them as one line
-- (a "rough patch") at the first, every death in its tooltip; opened, each
-- has its own line again. (15 Oct, in the client: seven death lines under
-- one long session.)
local DEATH_FOLD = 3

local function Deaths(lines)
    local deaths = {}
    for i = 1, #lines do
        if lines[i].kind == "death" then deaths[#deaths + 1] = lines[i] end
    end
    if #deaths < DEATH_FOLD then return lines end
    local out = {}
    for i = 1, #lines do
        local line = lines[i]
        if line == deaths[1] then
            out[#out + 1] = { kind = "deaths", time = line.time, deaths = deaths, depth = line.depth, moment = true }
        elseif line.kind ~= "death" then
            out[#out + 1] = line
        end
    end
    return out
end

local function Finish(episode, present, depth)
    -- Quests and rares only count while grouped (Sessions.Quest, .Rare), so
    -- naming either already says it.
    if present.quest or present.rare then present.group = nil end

    local activities = {}
    for key in pairs(present) do activities[#activities + 1] = key end
    table.sort(activities, function(a, b) return RANK_OF[a] < RANK_OF[b] end)

    local count = Timeline.Budget(episode.seconds)
    local headline, named = {}, {}
    for i = 1, math.min(count, #activities) do
        headline[i] = activities[i]
        named[activities[i]] = true
    end

    local all = episode.all
    table.sort(all, ByTime)

    local lines = {}
    for i = 1, #all do
        local child = all[i]
        child.depth = (depth or 0) + 1
        if child.moment and not named[child.activity] then lines[#lines + 1] = child end
    end
    lines = Deaths(Climbs(lines))

    episode.activities, episode.headline, episode.named = activities, headline, named
    episode.lines, episode.hidden = lines, #all - #lines
    episode.depth = depth
    return episode
end

local function RowItem(row)
    local t = TypeOf(row)
    return { kind = "row", time = row.time, row = row, activity = t.activity,
        moment = t.moment and t.moment(row) or false }
end

local function NewSession(session, guid)
    local p = session.participants[guid]
    local episode = { kind = "session", time = session.startedAt, session = session,
        participant = p, seconds = p and p.seconds or 0, zones = Timeline.Unique(session.zones), rows = {}, all = {},
        key = session }

    local present = {}
    if session.source == "group" then present.group = true end
    if p and p.quests and #p.quests > 0 then present.quest = true end
    for i = 1, #(p and p.rares or {}) do
        local rare = p.rares[i]
        present.rare = true
        episode.all[#episode.all + 1] = { kind = "rare", time = rare.time or session.startedAt,
            rare = rare, activity = "rare", moment = true }
    end
    -- Their deaths and the user's, as on the details line; always a line,
    -- and nothing a headline names.
    for _, death in ipairs(session.deathLog or {}) do
        if death.guid == guid or death.guid == session.me then
            episode.all[#episode.all + 1] = { kind = "death", time = death.time, death = death, moment = true }
        end
    end
    episode.present = present
    return episode
end

local function AddToSession(episode, row)
    -- The join that opened the session is the session's own line.
    if row.type == "group_join" then return end
    local item = RowItem(row)
    episode.rows[#episode.rows + 1] = row
    episode.all[#episode.all + 1] = item
    -- A level-up names nothing (its kind declares no activity), so it adds none.
    if item.activity then episode.present[item.activity] = true end
end

-- `run` is row items, newest first.
local function NewExchange(run)
    local episode = { kind = "exchange", time = run[#run].time, last = run[1].time,
        rows = {}, all = {}, zones = {}, key = run[#run].row }
    episode.seconds = episode.last - episode.time

    local present, seenZone = {}, {}
    for i = #run, 1, -1 do
        local item = run[i]
        episode.rows[#episode.rows + 1] = item.row
        episode.all[#episode.all + 1] = item
        if item.activity then present[item.activity] = true end
        local zone = item.row.zone
        if zone and not seenZone[zone] then
            seenZone[zone] = true
            episode.zones[#episode.zones + 1] = zone
        end
    end
    return Finish(episode, present)
end

-- TLN-8/9, over the top level newest first: runs of loose rows become
-- exchanges. "Added to the diary" inside a run neither ends it nor joins it;
-- it goes directly above the exchange, or below when it came before it.
local function Fold(items)
    local out, run, seq = {}, {}, {}

    -- Only rows that are something done together make an exchange: a run
    -- of level-ups seen in passing is not one, though a level-up inside a
    -- chat goes with it.
    local function Flush()
        local done = 0
        for i = 1, #run do
            if run[i].activity then done = done + 1 end
        end
        if done >= EXCHANGE_MIN then
            local oldest = run[#run].time
            local after = {}
            for i = 1, #seq do
                local item = seq[i]
                if item.kind ~= "row" then
                    if item.time >= oldest then out[#out + 1] = item else after[#after + 1] = item end
                end
            end
            out[#out + 1] = NewExchange(run)
            for i = 1, #after do out[#out + 1] = after[i] end
        else
            for i = 1, #seq do out[#out + 1] = seq[i] end
        end
        run, seq = {}, {}
    end

    for i = 1, #items do
        local item = items[i]
        local prev = run[#run]
        if item.kind == "row" then
            if not (prev and math.abs(prev.time - item.time) <= EXCHANGE_GAP) then Flush() end
            run[#run + 1] = item
            seq[#seq + 1] = item
        elseif item.kind == "added" and prev then
            seq[#seq + 1] = item
        else
            Flush()
            out[#out + 1] = item
        end
    end
    Flush()

    return out
end

--------------------------------------------------------------------------
-- Instance visits (TLN-4)
--------------------------------------------------------------------------
--
-- Visits come from Core/Instances.lua, which has the record's shape.
--
-- A visit is always an episode of its own. Inside a together session it is
-- one of the session's children that is always shown, and the session's rows
-- from while it lasted are the visit's; a session that was no more than the
-- visit gives way to it, and all its rows go with the visit.

-- How far a session may start before the visit, or end after it, and still
-- be no more than the visit.
local VISIT_SLACK = 10 * 60

local function NewVisit(visit)
    return { kind = "visit", time = visit.startedAt, visit = visit, key = visit,
        seconds = (visit.endedAt or ns.Now()) - visit.startedAt, all = {}, moment = true }
end

local function JustTheVisit(session, visit)
    return session.startedAt >= visit.startedAt - VISIT_SLACK
        and (session.endedAt or ns.Now()) <= (visit.endedAt or ns.Now()) + VISIT_SLACK
end

--------------------------------------------------------------------------
-- Notes (TLN-10)
--------------------------------------------------------------------------
--
-- What the user wrote (Core/Notes.lua) while a run was going on belongs to
-- the run's own description: `episode.notes`, oldest first, shown whether it
-- is open or folded (UI/Journal/Timeline.lua), and not among what it hides. Any
-- other note is a top-level line at its own time. Notes are placed after
-- Fold, so a loose one can never split or join an exchange.

-- When a run was going on: a session or a visit from start to end, or to
-- now while it lasts; an exchange until EXCHANGE_GAP after its last row,
-- the time in which another row would still have joined it. A visit that
-- took its session's place (JustTheVisit) covers the session's time too.
local function Span(episode)
    local from, to
    if episode.kind == "session" then
        from, to = episode.session.startedAt, episode.session.endedAt or ns.Now()
    elseif episode.kind == "visit" then
        from, to = episode.visit.startedAt, episode.visit.endedAt or ns.Now()
        local session = episode.replacing
        if session then
            from, to = math.min(from, session.startedAt), math.max(to, session.endedAt or ns.Now())
        end
    elseif episode.kind == "exchange" then
        from, to = episode.time, episode.last + EXCHANGE_GAP
    end
    return from, to
end

-- Every run on the page, and the visits inside sessions.
local function Runs(items, into)
    for i = 1, #items do
        local item = items[i]
        if Span(item) then into[#into + 1] = item end
        if item.kind == "session" then Runs(item.all, into) end
    end
    return into
end

-- The run going on at `time`: the innermost, which is the one that started
-- last, or the one further in when two started together.
local function RunAt(runs, time)
    local best, bestFrom
    for i = 1, #runs do
        local run = runs[i]
        local from, to = Span(run)
        if time >= from and time <= to then
            if not best or from > bestFrom
                or (from == bestFrom and (run.depth or 0) > (best.depth or 0)) then
                best, bestFrom = run, from
            end
        end
    end
    return best
end

-- `items` is the folded top level, newest first.
local function PlaceNotes(items, guid)
    local runs = Runs(items, {})
    for _, note in ipairs(ns.Notes.For(guid)) do
        local run = RunAt(runs, note.time)
        if run then
            run.notes = run.notes or {}
            run.notes[#run.notes + 1] = note
        else
            local at = #items + 1
            for i = 1, #items do
                if items[i].time < note.time then at = i break end
            end
            table.insert(items, at, { kind = "note", time = note.time, note = note })
        end
    end
end

--------------------------------------------------------------------------
-- The timeline
--------------------------------------------------------------------------

-- Top-level items, newest first. Episodes carry their children: `lines` are
-- shown folded, `all` when opened, oldest first and one level in.
function Timeline.For(guid)
    guid = ns.SafeGUID(guid)
    local entry = guid and ns.Diary.Get(guid)
    if not entry then return {} end

    local top, sessions, order = {}, {}, {}

    for _, session in ipairs(ns.Sessions.For(guid)) do
        local episode = NewSession(session, guid)
        sessions[session.id] = episode
        order[#order + 1] = episode
    end

    local rows = ns.Interactions.For(guid) or {}
    for i = 1, #rows do
        local row = rows[i]
        if not TypeOf(row).hidden then
            local episode = row.session and sessions[row.session]
            if episode then
                AddToSession(episode, row)
            else
                top[#top + 1] = RowItem(row)
            end
        end
    end

    for _, visit in ipairs(ns.Instances.For(guid)) do
        local episode = NewVisit(visit)
        local host
        for _, id in ipairs(visit.sessionIds or {}) do
            host = host or sessions[id]
        end

        if host and JustTheVisit(host.session, visit) then
            -- The session was the visit: the visit takes its place and rows.
            host.replaced = true
            episode.replacing = host.session
            for i = 1, #host.all do
                if host.all[i].kind == "row" then episode.all[#episode.all + 1] = host.all[i] end
            end
            top[#top + 1] = Finish(episode, {})
        elseif host then
            -- What happened during the run happened in the run. Its deaths
            -- are the visit's to count ("4 deaths" on its card), not lines
            -- beside it, nor the session's count again (TLN-11).
            local kept, ended = {}, visit.endedAt or ns.Now()
            for i = 1, #host.all do
                local child = host.all[i]
                local during = child.time >= visit.startedAt and child.time <= ended
                if child.kind == "row" and during then
                    episode.all[#episode.all + 1] = child
                elseif child.kind == "death" and during then
                    host.runDeaths = (host.runDeaths or 0) + 1
                else
                    kept[#kept + 1] = child
                end
            end
            host.all = kept
            host.all[#host.all + 1] = Finish(episode, {}, 1)
        else
            top[#top + 1] = Finish(episode, {})
        end
    end

    for _, episode in ipairs(order) do
        if not episode.replaced then top[#top + 1] = Finish(episode, episode.present) end
    end

    for _, stretch in ipairs(ns.Sessions.AroundFor(guid)) do
        top[#top + 1] = { kind = "around", time = stretch.start, around = stretch }
    end

    top[#top + 1] = { kind = "added", time = entry.addedAt, entry = entry }

    -- JRN-23: where they were first seen, from the user's own road, once
    -- they mattered. Worked out here like everything else; nothing saved.
    local first = ns.JourneyRecap and ns.JourneyRecap.FirstSightingOf(guid)
    if first then top[#top + 1] = { kind = "first", time = first.t, first = first } end

    table.sort(top, function(a, b) return a.time > b.time end)
    local out = Fold(top)
    PlaceNotes(out, guid)
    return out
end
