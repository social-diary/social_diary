-- A together session's candidate beats (experimental, planner stage 1):
-- one for each thing the diary could say about it on a person's page,
-- before anything is weighed.
--
-- The planner's design ("Session planner: deciding what the story is", 28
-- Oct 2026) works in five stages; this is the first. A session becomes
-- episodes (one moment, once: a dungeon visit is one episode of four parts)
-- and the episodes become candidates. Each candidate is
--
--   id           "time", "visit:12/run", "row:3/saved", ...
--   angle, move  where its words are (UI/Words/Pages/Angles/), and
--   facts        what that angle takes (WRITING.md's fact contract)
--   involvement  how much it belongs to this relationship: "between" (one
--                of us did something to or for the other), "together" (we
--                did it as a pair or a group), "company" (it happened to
--                one of us with the other there), "around" (nothing to do
--                with them)
--   episode      the episode it belongs to ("session", "visit:12"), and
--   opens        it may open that episode (a visit's run does, its parts
--                don't)
--   time         when it happened, for ties (the later reads better)
--   state        a standing state, not an event (the time together, our
--                levels side by side): loses ties to an event
--   probable     a fact the data isn't sure of: may be said, hedged, but
--                never be the point
--   sensitive    it shows them in a poor light on their own page
--   said         the timeline's `said` key the details line leaves out
--                when the beat is told (rare, deaths, level, quest,
--                dungeon, trade)
--   notes        what the weighing will need, in words, for the trace
--   visit        a dungeon visit's record, for its run and trouble
--
-- Nothing here is saved and nothing is weighed yet: stage 2 adds the
-- baselines and the tiers. The trace (SessionProse.Trace) lists them, one
-- line each, on the row's tooltip while /sd prose is on with debug.

local addonName, ns = ...

local TimelineText = ns.UI.TimelineText

local SessionProse = ns.UI.SessionProse or {}
ns.UI.SessionProse = SessionProse

--------------------------------------------------------------------------
-- People
--------------------------------------------------------------------------

-- The client's names for a race and a class, as the stored tokens
-- ("NightElf", "HUNTER") would read badly in a sentence.
local function RaceName(c)
    local info = c.raceID and C_CreatureInfo and C_CreatureInfo.GetRaceInfo
        and C_CreatureInfo.GetRaceInfo(c.raceID)
    if info and info.raceName then return info.raceName end
    return c.race and (c.race:gsub("(%l)(%u)", "%1 %2")) or nil
end

local function ClassName(c)
    local info = c.classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo
        and C_CreatureInfo.GetClassInfo(c.classID)
    if info and info.className then return info.className end
    local names = LOCALIZED_CLASS_NAMES_MALE
    return c.class and (names and names[c.class] or c.class:sub(1, 1) .. c.class:sub(2):lower()) or nil
end

-- A person as the page writer takes one (WRITING.md: "A person").
local function Person(guid)
    local c = ns.Characters.Get(guid) or {}
    local entry = ns.Diary.Get(guid)
    local tags = {}
    for _, tag in ipairs(entry and entry.tags or {}) do tags[tag:lower()] = true end
    local sex = c.sex
    local name = ns.Characters.Name(guid)
    return {
        id = guid,
        name = name,
        sex = (sex == 2 or sex == 3) and sex or nil,
        race = RaceName(c),
        class = ClassName(c),
        level = c.level,
        relationship = entry and entry.relationship,
        diary = entry ~= nil,
        named = name ~= nil,
        tags = tags,
    }
end
SessionProse.Person = Person

--------------------------------------------------------------------------
-- Readings
--------------------------------------------------------------------------

local function Grouped(episode)
    local present = episode.present or {}
    return episode.session.source == "group" or present.quest or present.rare or false
end

-- The zones the session's time went to, most first.
local function ZonesByTime(where)
    local list = {}
    for _, zone in ipairs(where.zones and where.zones.zones or {}) do list[#list + 1] = zone end
    table.sort(list, function(a, b) return (a.seconds or 0) > (b.seconds or 0) end)
    local names = {}
    for i = 1, #list do names[i] = list[i].name end
    return names
end

-- Everyone else the user was with: the session's other diary entries by
-- name (up to three), else a count of them and the strangers together.
local function Others(session, guid)
    local people = {}
    for other in pairs(session.participants) do
        if other ~= guid and other ~= session.me then people[#people + 1] = other end
    end
    table.sort(people)
    local strangers = session.others or 0
    if #people == 0 then return strangers > 0 and strangers or nil end
    if strangers == 0 and #people <= 3 then
        local list = {}
        for i = 1, #people do list[i] = Person(people[i]) end
        return list
    end
    return #people + strangers
end

-- Items as the page writer takes them ({ link, count }), the same item
-- summed, or nil for none.
local function Items(list)
    local out, at = {}, {}
    for _, item in ipairs(list) do
        if item.link then
            if at[item.link] then
                at[item.link].count = at[item.link].count + (item.count or 1)
            else
                at[item.link] = { link = item.link, count = item.count or 1 }
                out[#out + 1] = at[item.link]
            end
        end
    end
    return #out > 0 and out or nil
end

--------------------------------------------------------------------------
-- The session's own candidates: time, rares, deaths, levels
--------------------------------------------------------------------------

local function SessionCandidates(episode, guid, who, add, h)
    local session, p = episode.session, episode.participant
    local grouped = Grouped(episode)
    local where = TimelineText.Where(episode)
    local zones = ZonesByTime(where)

    add({ id = "time", angle = "together", move = "time", involvement = grouped and "together" or "company",
        episode = "session", opens = true, state = true, time = session.endedAt or session.startedAt, said = "quest",
        facts = {
            who = who,
            seconds = episode.seconds > 0 and episode.seconds or nil,
            grouped = grouped,
            zones = #zones > 0 and zones or nil,
            zone = where.top,
            quests = grouped and p and p.quests and #p.quests > 0 and #p.quests or nil,
            others = grouped and Others(session, guid) or nil,
        } })

    local rares = p and p.rares or {}
    if #rares > 0 then
        add({ id = "rares", angle = "together", move = "rares", involvement = "together",
            episode = "session", time = rares[#rares].time, said = "rare",
            facts = { who = who, rare = rares[1].name, rareCount = #rares, rareKilled = true } })
    end

    local mine, theirs = TimelineText.DeathsOf(episode, guid)
    if mine + theirs > 0 then
        add({ id = "deaths", angle = "together", move = "deaths", involvement = "company",
            episode = "session", sensitive = theirs > 0 or nil, said = "deaths",
            facts = { who = who, myDeaths = mine, theirDeaths = theirs } })
    end

    if p and p.levelStart and p.levelEnd and p.levelEnd > p.levelStart then
        local cap = ns.Journey.MaxLevel()
        local alsoMe = session.myLevelStart and session.myLevelEnd and session.myLevelEnd > session.myLevelStart
        add({ id = "their-level", angle = "ding", move = "level", involvement = "company",
            episode = "session", said = "level",
            facts = { who = who, level = p.levelEnd, from = p.levelStart, levels = p.levelEnd - p.levelStart,
                together = grouped, round = p.levelEnd % 10 == 0, cap = p.levelEnd >= cap },
            notes = alsoMe and { "I levelled this session too (not known: within minutes)" } or nil })
    end

    -- Our levels side by side, and how the gap moved since last time.
    local myLevel, theirLevel = session.myLevelEnd, p and p.levelEnd
    if myLevel and theirLevel then
        local diff = myLevel - theirLevel
        local f = { who = who, myLevel = myLevel, theirLevel = theirLevel, levelDiff = diff,
            absLevelDiff = math.abs(diff), sameLevel = diff == 0 or nil,
            aheadMe = diff > 0 or nil, aheadThem = diff < 0 or nil }
        if h.myLevelThen and h.theirLevelThen then
            local was = h.myLevelThen - h.theirLevelThen
            f.diffThen = was
            f.crossed = (was > 0 and diff < 0) or (was < 0 and diff > 0) or nil
            if not f.crossed then
                f.closed = math.abs(diff) < math.abs(was) or nil
                f.widened = math.abs(diff) > math.abs(was) or nil
            end
        end
        -- Not something we did as a pair: a state of the two of us.
        add({ id = "parity", angle = "parity", move = "levels", involvement = "company",
            episode = "session", state = true, facts = f })
    end

    if session.myLevelStart and session.myLevelEnd and session.myLevelEnd > session.myLevelStart then
        local level, cap = session.myLevelEnd, ns.Journey.MaxLevel()
        local milestone
        for l = session.myLevelStart + 1, level do
            if l % 10 == 0 then milestone = l end
        end
        add({ id = "my-level", angle = "open", move = "climb", involvement = "around",
            episode = "session", said = "level",
            facts = { milestone = milestone, reachedCap = level >= cap or nil, levelsToCap = math.max(0, cap - level) },
            notes = { "mine: " .. session.myLevelStart .. " to " .. level } })
    end
end

--------------------------------------------------------------------------
-- What only history knows: back after a gap, or the first time at all
--------------------------------------------------------------------------

-- A gap this long (days) is worth telling at all; whether it leads is the
-- weighing's (SessionWeights.lua).
local REUNION_DAYS = 7
SessionProse.REUNION_DAYS = REUNION_DAYS

-- How a first meeting happened, from the strongest row: the new_face
-- angle's `how`, or nil for a session that was only nearby.
local HOW = { { "saved_you", "rescue" }, { "trade", "trade" }, { "campfire", "campfire" },
    { "whisper_in", "chat" }, { "whisper_out", "chat" }, { "say", "say" } }

local VIA = { group = "viaGroup", trade = "viaTrade", duel = "viaDuel", campfire = "viaCampfire",
    chat = "viaChat", rescue = "viaRescue", say = "viaSay" }

local function HistoryCandidates(episode, guid, who, add, h)
    local session, p = episode.session, episode.participant
    local where = TimelineText.Where(episode)

    if h.gapDays and h.gapDays >= REUNION_DAYS then
        local usual = h.usualGapDays
        add({ id = "reunion", angle = "reunion", move = "gap", involvement = "between",
            episode = "session", opens = true, time = session.startedAt,
            facts = { who = who, gapDays = h.gapDays, usualGapDays = usual and math.floor(usual + 0.5) or nil,
                longAbsence = usual and usual > 0 and h.gapDays >= 3 * usual or nil,
                isRecordGap = h.longestGapDays and h.gapDays > h.longestGapDays or nil,
                prevRecordDays = h.longestGapDays and h.gapDays > h.longestGapDays and h.longestGapDays or nil,
                lastWhen = h.lastWhen, lastZone = h.lastZone, lastGrouped = h.lastGrouped or nil,
                sameZoneAsLast = h.lastZone ~= nil and h.lastZone == where.top or nil,
                zone = where.top, timesMet = #h.prior + 1, firstZone = h.firstZone,
                firstMetDays = h.firstWhen and math.floor((session.startedAt - h.firstWhen) / 86400) or nil } })
    end

    if #h.prior == 0 then
        local grouped = Grouped(episode)
        local how = grouped and "group" or nil
        if not how then
            for _, pair in ipairs(HOW) do
                for _, row in ipairs(episode.rows) do
                    if not how and row.type == pair[1] then how = pair[2] end
                end
            end
        end
        if how then
            local f = { who = who, how = how, zone = where.top, theirLevel = p and p.levelEnd }
            f[VIA[how]] = true
            if how == "group" then
                f.seconds = episode.seconds > 0 and episode.seconds or nil
                f.quests = p and p.quests and #p.quests or 0
            end
            add({ id = "first/meet", angle = "new_face", move = "meet", involvement = "between",
                episode = "session", opens = true, time = session.startedAt, facts = f })
        end

        local entry = ns.Diary.Get(guid)
        local added = entry and entry.addedAt
        if added and added >= session.startedAt and added <= (session.endedAt or ns.Now()) then
            add({ id = "first/added", angle = "new_face", move = "added", involvement = "between",
                episode = "session", time = added,
                facts = { who = who, addedToday = true, tag = entry.tags and entry.tags[1] } })
        end
    end
end

--------------------------------------------------------------------------
-- A dungeon visit: one episode, four parts
--------------------------------------------------------------------------

-- The user's visits to this instance before this one: how many, and
-- whether one of them was a full clear. The diary in use decides whose
-- they are (one character's, or every character's when it is shared).
local function History(visit)
    local before, cleared = 0, false
    for _, other in pairs(ns.db.instances or {}) do
        if other ~= visit and other.instanceID == visit.instanceID
            and (other.startedAt or 0) < (visit.startedAt or 0) then
            before = before + 1
            if other.bossTotal and #(other.bossesKilled or {}) >= other.bossTotal then cleared = true end
        end
    end
    return before, cleared
end

local function VisitCandidates(child, guid, who, add)
    local visit = child.visit
    local me = visit.me or ns.ownGUID
    local key = "visit:" .. tostring(visit.id or child.time)
    local bosses = #(visit.bossesKilled or {})
    local full = visit.bossTotal and bosses >= visit.bossTotal or nil
    local before, cleared = History(visit)

    local strangers, friends = 0, 0
    for _, m in ipairs(visit.members or {}) do
        if m.guid ~= me then
            if ns.Diary.IsDiary(m.guid) then friends = friends + 1 else strangers = strangers + 1 end
        end
    end
    local seconds = (visit.endedAt or visit.lastSeen or child.time) - (visit.startedAt or child.time)

    -- The how-manyth run of ours this was (DungeonRun.Person's `together`).
    local runsTogether = 1
    for _, fact in ipairs(ns.DungeonRun.Person(visit, guid)) do
        if fact.kind == "together" then runsTogether = fact.n end
    end
    add({ id = key .. "/run", angle = "dungeon", move = "run", involvement = "together", visit = visit,
        episode = key, opens = true, time = visit.endedAt or child.time, said = "dungeon",
        facts = { instance = visit.name, difficulty = visit.difficulty and visit.difficulty:lower() or nil,
            groupSize = #(visit.members or {}) + 1, friend = who, friendCount = math.max(1, friends),
            strangers = strangers, seconds = seconds > 0 and seconds or nil, bossesKilled = bosses,
            bossesTotal = visit.bossTotal, fullClear = full,
            firstClear = full and not cleared or nil, firstVisit = before == 0 or nil },
        notes = { ("run %d together; my visit %d there"):format(runsTogether, before + 1) } })

    local wipes = ns.DungeonRun.Wipes(visit)
    local myDeaths, counts = 0, {}
    for _, d in ipairs(visit.deathLog or {}) do
        if d.guid == me then myDeaths = myDeaths + 1 else counts[d.guid] = (counts[d.guid] or 0) + 1 end
    end
    local deadliest, most = nil, 0
    for g, n in pairs(counts) do
        if n > most or (n == most and deadliest and g < deadliest) then deadliest, most = g, n end
    end
    -- A wipe is deaths, whatever the count says: never "nobody died" then.
    local deaths = math.max(visit.deaths or 0, #(visit.deathLog or {}))
    add({ id = key .. "/trouble", angle = "dungeon", move = "trouble", involvement = "together", visit = visit,
        episode = key, sensitive = (deadliest == guid) or nil,
        facts = { wipes = wipes, deaths = deaths, myDeaths = myDeaths,
            noDeaths = (deaths == 0 and wipes == 0) or nil,
            deadliest = deadliest and Person(deadliest) or nil, deadliestCount = most > 0 and most or nil } })

    local myLoot, theirLoot = {}, {}
    for _, l in ipairs(visit.loot or {}) do
        if l.guid == me then myLoot[#myLoot + 1] = { link = l.item, count = 1 }
        elseif l.guid == guid then theirLoot[#theirLoot + 1] = { link = l.item, count = 1 } end
    end
    if #myLoot + #theirLoot > 0 then
        add({ id = key .. "/loot", angle = "dungeon", move = "loot", involvement = #theirLoot > 0 and "together" or "around",
            episode = key, facts = { myLoot = #myLoot > 0 and myLoot or nil, friend = who,
                friendLoot = #theirLoot > 0 and theirLoot or nil } })
    end

    -- Rolls the two of us both needed on.
    for i, drop in ipairs(visit.rolls or {}) do
        local need = drop.need or {}
        local mine, theirs = need[me], need[guid]
        if type(mine) == "number" and type(theirs) == "number" and drop.winner then
            local iWon = drop.winner == me
            add({ id = key .. "/roll:" .. i, angle = "dungeon", move = "roll", involvement = "between",
                episode = key, time = drop.time,
                facts = { rollItem = { { link = drop.item, count = 1 } }, iWon = iWon or nil,
                    winner = not iWon and drop.winner == guid and who or nil, myRoll = mine,
                    winRoll = iWon and theirs or drop.winRoll, close = math.abs(mine - theirs) <= 3 or nil } })
        end
    end
end

--------------------------------------------------------------------------
-- The session's rows: rescues and watching, trade, chat, campfire
--------------------------------------------------------------------------

local function Foe(row)
    local c = row.context or {}
    return c.name and { name = c.name, rank = c.rank, npcID = c.npcID } or nil
end

local function RowCandidates(episode, guid, who, add, h)
    local grouped = Grouped(episode)
    local whispersIn, whispersOut, chatTime, saved = 0, 0, nil, 0
    for i, row in ipairs(episode.rows) do
        local c, id = row.context or {}, "row:" .. i
        if row.type == "saved_you" then
            saved = saved + 1
            local before = (h.rows.saved_you or 0) + saved - 1
            add({ id = id .. "/saved", angle = "rescue", move = "saved", involvement = "between",
                episode = id, opens = true, time = row.time,
                facts = { who = who, pct = c.pct, foe = Foe(row), grouped = grouped,
                    firstByThem = before == 0 or nil, timesSaved = before + 1 } })
        elseif row.type == "tried_to_help" then
            add({ id = id .. "/helped", angle = "rescue", move = "helped", involvement = "between",
                episode = id, opens = true, time = row.time,
                facts = { who = who, foe = Foe(row), died = true, grouped = grouped } })
        elseif row.type == "watched_death" then
            add({ id = id .. "/watched", angle = "witness", move = "watched", involvement = "company",
                episode = id, opens = true, time = row.time, sensitive = true,
                facts = { who = who, watched = c.watched, foe = Foe(row), zone = row.zone, subZone = c.subZone } })
        elseif row.type == "campfire" then
            add({ id = id .. "/sat", angle = "campfire", move = "sat", involvement = "between",
                episode = id, opens = true, time = row.time,
                facts = { who = who, zone = row.zone, subZone = c.subZone,
                    firstTime = (h.rows.campfire or 0) == 0 or nil } })
        elseif row.type == "whisper_in" then
            whispersIn, chatTime = whispersIn + 1, row.time
        elseif row.type == "whisper_out" then
            whispersOut, chatTime = whispersOut + 1, row.time
        end
    end

    -- Every trade in the session, the run's included (episode.rows keeps
    -- them all; a visit takes its own out of episode.all), summed.
    local trades, received, given, gotMoney, gaveMoney = 0, {}, {}, 0, 0
    for _, row in ipairs(episode.rows) do
        if row.type == "trade" then
            local c = row.context or {}
            trades = trades + 1
            for _, item in ipairs(c.received or {}) do received[#received + 1] = item end
            for _, item in ipairs(c.given or {}) do given[#given + 1] = item end
            gotMoney, gaveMoney = gotMoney + (c.moneyReceived or 0), gaveMoney + (c.moneyGiven or 0)
        end
    end
    if trades > 0 then
        received, given = Items(received), Items(given)
        local gotSome, gaveSome = received or gotMoney > 0, given or gaveMoney > 0
        local move = (gotSome and gaveSome and "swap") or (gotSome and "gift") or (gaveSome and "given")
        if move then
            add({ id = "trade/" .. move, angle = "trade", move = move, involvement = "between",
                episode = "trade", opens = true, said = "trade",
                facts = { who = who, received = received, given = given,
                    moneyReceived = gotMoney > 0 and gotMoney or nil,
                    moneyGiven = gaveMoney > 0 and gaveMoney or nil,
                    first = (h.rows.trade or 0) == 0 or nil,
                    -- A favour returned: they give after I gave, or I after they did.
                    returned = (move == "gift" and h.gaveBefore) or (move == "given" and h.gotBefore) or nil },
                notes = { trades .. " trade(s)" } })
        end
    end

    if whispersIn + whispersOut > 0 then
        add({ id = "chat/heard", angle = "chat", move = "heard", involvement = "between",
            episode = "chat", opens = true, time = chatTime,
            facts = { who = who, whispersIn = whispersIn > 0 and whispersIn or nil,
                whispersOut = whispersOut > 0 and whispersOut or nil,
                firstWhisper = ((h.rows.whisper_in or 0) + (h.rows.whisper_out or 0)) == 0 or nil } })
    end
end

--------------------------------------------------------------------------
-- All of them
--------------------------------------------------------------------------

-- The session's candidates on `guid`'s page, in the order they were found,
-- and its history (UI/Words/SessionHistory.lua).
-- A dungeon that fills most of the session covers the time together (it is
-- said through the run, not beside it): the time candidate notes it.
function SessionProse.Candidates(episode, guid)
    local list = {}
    local function add(c) c.guid = guid; list[#list + 1] = c end
    local who = Person(guid)
    local h = SessionProse.History(episode, guid)

    HistoryCandidates(episode, guid, who, add, h)
    SessionCandidates(episode, guid, who, add, h)

    local visitSeconds = 0
    for _, child in ipairs(episode.all or {}) do
        if child.kind == "visit" and child.visit then
            VisitCandidates(child, guid, who, add)
            local v = child.visit
            visitSeconds = visitSeconds + math.max(0, (v.endedAt or v.lastSeen or child.time) - (v.startedAt or child.time))
        end
    end
    for _, c in ipairs(list) do
        if c.id == "time" and episode.seconds > 0 and visitSeconds / episode.seconds >= 0.5 then
            c.coveredBy = "dungeon"
        end
    end

    RowCandidates(episode, guid, who, add, h)
    return list, h
end

--------------------------------------------------------------------------
-- The trace
--------------------------------------------------------------------------

local function Value(v)
    if type(v) == "table" then
        if v.name then return v.name end
        if v[1] and type(v[1]) == "table" then return #v .. " item(s)" end
        if v[1] then return table.concat(v, "/") end
        return "{...}"
    end
    return tostring(v)
end

-- The point, then one line per candidate, strongest first:
--   "visit:77/run  Notable -> Headline (+our first run there, +my first clear)
--    together  dungeon/run  bossesKilled=6 ..."
function SessionProse.Trace(episode, guid)
    local list, h = SessionProse.Candidates(episode, guid)
    local ledger = SessionProse.LedgerBefore(episode, guid)
    SessionProse.Weigh(list, h, ledger)
    local point = SessionProse.Point(list)
    local sorted = {}
    for i = 1, #list do sorted[i] = list[i] end
    table.sort(sorted, SessionProse.Better)

    local Name = SessionProse.TierName
    local lines = { point and ("point: %s (%s)"):format(point.id, Name(point.tier))
        or "point: none, a quiet row" }
    local beats = SessionProse.Choice and SessionProse.Choice(episode, guid)
    local chosen = {}
    for _, entry in ipairs(beats or {}) do
        chosen[#chosen + 1] = entry.role .. " " .. entry.c.id .. (entry.rel and (" (" .. entry.rel .. ")") or "")
            .. (entry.short and ", short" or "")
    end
    lines[#lines + 1] = "plan: " .. (#chosen > 0 and table.concat(chosen, "; ") or "the old headline")
    lines[#lines + 1] = ("history: %d sessions before%s"):format(#h.prior,
        h.gapDays and (", %d days since the last"):format(h.gapDays) or "")
    local led = {}
    for i, r in ipairs(ledger.recent) do led[i] = r.kind end
    lines[#lines + 1] = "led recently: " .. (#led > 0 and table.concat(led, ", ") or "nothing")
    for _, c in ipairs(sorted) do
        local keys = {}
        for k, v in pairs(c.facts) do
            if k ~= "who" and k ~= "friend" and v ~= nil and v ~= false then keys[#keys + 1] = k end
        end
        table.sort(keys)
        local facts = {}
        for i, k in ipairs(keys) do facts[i] = k .. "=" .. Value(c.facts[k]) end
        local flags = {}
        if c.opens then flags[#flags + 1] = "opens" end
        if c.sensitive then flags[#flags + 1] = "sensitive" end
        if c.probable then flags[#flags + 1] = "probable" end
        if c.noLead then flags[#flags + 1] = "can't lead" end
        if c.coveredBy then flags[#flags + 1] = "covered by " .. c.coveredBy end
        local tier = c.startTier == c.tier and Name(c.tier) or (Name(c.startTier) .. " -> " .. Name(c.tier))
        if #c.reasons > 0 then tier = tier .. " (" .. table.concat(c.reasons, ", ") .. ")" end
        local line = ("%s  %s  %s  %s/%s  %s"):format(c.id, tier, c.involvement, c.angle, c.move,
            table.concat(facts, " "))
        if #flags > 0 then line = line .. "  [" .. table.concat(flags, ", ") .. "]" end
        for _, note in ipairs(c.notes or {}) do line = line .. "  (" .. note .. ")" end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end
