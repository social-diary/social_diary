-- What came before a together session, for weighing it (experimental,
-- planner stage 2): the baselines of one relationship, read from the saved
-- sessions, rows and visits as they are. Nothing is saved.
--
-- Only what happened before the session counts, so a row's weight never
-- changes when later sessions are added. The diary in use decides whose
-- history it is: one character's own, or every character's when the
-- diary is shared (DAT-1's shareDiary), so firsts and records follow that
-- setting by themselves.
--
-- SessionProse.History(episode, guid) returns
--   prior            the sessions together before this one, newest first
--   recent           the last RECENT of them
--   gapDays          whole days since the last one ended (nil: none)
--   usualGapDays     the median of the gaps between the earlier ones
--   longestGapDays   the longest of those gaps
--   longestSeconds   our longest session together before
--   levelShare       the share of recent sessions in which they levelled
--   myDeathsPerHour  my deaths per hour together, before (nil: under an hour)
--   rows             counts of their rows before the session, by type
--   gaveBefore, gotBefore   I had given them something / they me
--   tradeShare       the share of recent sessions with a trade
--   raresBefore      rares we killed together before
--   lastZone, lastGrouped, lastWhen   how the last session ended
--   myLevelThen, theirLevelThen       our levels at its end
--   firstWhen, firstZone              our first session together
-- and SessionProse.RunsBefore(visit, guid): our runs together before this
-- one, at this instance and anywhere, and their wipes on average.

local addonName, ns = ...

local SessionProse = ns.UI.SessionProse or {}
ns.UI.SessionProse = SessionProse

local DAY = 86400
-- How many of the latest sessions are "recent" for the shares.
local RECENT = 10
SessionProse.RECENT = RECENT

local function Median(list)
    if #list == 0 then return nil end
    local sorted = {}
    for i = 1, #list do sorted[i] = list[i] end
    table.sort(sorted)
    local mid = math.floor((#sorted + 1) / 2)
    if #sorted % 2 == 1 then return sorted[mid] end
    return (sorted[mid] + sorted[mid + 1]) / 2
end

local function Ended(session)
    return session.endedAt or session.startedAt
end

local function Levelled(session, guid)
    local p = session.participants[guid]
    return p and p.levelStart and p.levelEnd and p.levelEnd > p.levelStart
end

function SessionProse.History(episode, guid)
    local session = episode.session
    local start = session.startedAt
    local h = { prior = {}, recent = {}, rows = {} }

    for _, other in ipairs(ns.Sessions.For(guid)) do
        if other ~= session and other.startedAt < start then h.prior[#h.prior + 1] = other end
    end
    for i = 1, math.min(RECENT, #h.prior) do h.recent[i] = h.prior[i] end

    local last = h.prior[1]
    if last then
        h.gapDays = math.max(0, math.floor((start - Ended(last)) / DAY))
        h.lastWhen, h.lastZone = Ended(last), last.zones and last.zones[#last.zones]
        h.lastGrouped = last.source == "group"
        h.myLevelThen = last.myLevelEnd
        local p = last.participants[guid]
        h.theirLevelThen = p and p.levelEnd
        local first = h.prior[#h.prior]
        h.firstWhen, h.firstZone = first.startedAt, first.zones and first.zones[1]
    end

    -- Gaps between the earlier sessions, oldest pair first.
    local gaps = {}
    for i = #h.prior, 2, -1 do
        gaps[#gaps + 1] = math.max(0, math.floor((h.prior[i - 1].startedAt - Ended(h.prior[i])) / DAY))
    end
    h.usualGapDays = Median(gaps)
    for _, g in ipairs(gaps) do h.longestGapDays = math.max(h.longestGapDays or 0, g) end

    local seconds, myDeaths, rares = 0, 0, 0
    for _, other in ipairs(h.prior) do
        local p = other.participants[guid]
        local s = p and p.seconds or 0
        seconds = seconds + s
        h.longestSeconds = math.max(h.longestSeconds or 0, s)
        myDeaths = myDeaths + (other.deaths and other.deaths[other.me] or 0)
        rares = rares + #(p and p.rares or {})
    end
    h.raresBefore = rares
    if seconds >= 3600 then h.myDeathsPerHour = myDeaths / (seconds / 3600) end

    local levelled = 0
    for _, other in ipairs(h.recent) do
        if Levelled(other, guid) then levelled = levelled + 1 end
    end
    h.levelShare = #h.recent > 0 and levelled / #h.recent or nil

    -- Their rows before the session: kinds counted, trades both ways, and
    -- which recent sessions had a trade.
    local recentIds, traded = {}, {}
    for _, other in ipairs(h.recent) do recentIds[other.id] = true end
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row.time < start then
            h.rows[row.type] = (h.rows[row.type] or 0) + 1
            if row.type == "trade" then
                local c = row.context or {}
                if (c.given and #c.given > 0) or (c.moneyGiven or 0) > 0 then h.gaveBefore = true end
                if (c.received and #c.received > 0) or (c.moneyReceived or 0) > 0 then h.gotBefore = true end
                if row.session and recentIds[row.session] then traded[row.session] = true end
            end
        end
    end
    local n = 0
    for _ in pairs(traded) do n = n + 1 end
    h.tradeShare = #h.recent > 0 and n / #h.recent or nil
    return h
end

-- Our runs together before `visit`: { here, anywhere, wipesPerRun }.
function SessionProse.RunsBefore(visit, guid)
    local here, anywhere, wipes = 0, 0, 0
    for _, other in ipairs(ns.Instances.For(guid)) do
        if other ~= visit and (other.startedAt or 0) < (visit.startedAt or 0) then
            anywhere = anywhere + 1
            wipes = wipes + ns.DungeonRun.Wipes(other)
            if other.instanceID == visit.instanceID then here = here + 1 end
        end
    end
    return { here = here, anywhere = anywhere, wipesPerRun = anywhere > 0 and wipes / anywhere or nil }
end
