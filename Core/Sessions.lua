-- Together sessions (SES-1 to SES-5).
--
-- A session is continuous time with one or more diary entries. There is at
-- most one open session at a time, per the user's logged-in character, and
-- every diary entry the user is with joins it as a participant -- so several
-- entries in one group share one session (SES-6) without extra machinery.
-- Each participant keeps their own first/last/seconds, so a profile can still
-- say how long *they* were there when the session ran on without them.
--
-- SES-2 lifecycle, as built:
--
--   opens    when a diary entry is in the user's group, or on an interaction
--            that needs the two of them in the same place (trade, /say,
--            /yell). A whisper can come from anywhere, so it never opens one;
--            it only becomes a highlight of a session that is already open.
--   stays    while they are grouped, or seen nearby (target, focus, mouseover,
--            nameplates). Seen nearby with no session open is not a
--            together session at all, but "seen around" (SES-9, below).
--   closes   once every participant has been apart for the gap (20 minutes by
--            default). The end time is the last moment together, not the
--            moment the gap ran out.
--
-- Logout does not close a session outright, because /reload fires the same
-- event and SES-3 wants a reload to change nothing. Instead the open session
-- stays open on disk and Resume settles it at the next login: continued if the
-- gap has not run out on the same character, closed at the last moment
-- together otherwise. A real logout therefore closes with the right end time,
-- just one login later.
--
-- SES-5: interactions during a session are stamped with its id rather than
-- copied into it (Interactions.Add asks Note). The rows already live under the
-- participant's GUID and diary rows are never pruned, so the stamp is enough
-- for the journal to show them inside the session instead of beside it.

local addonName, ns = ...

local Sessions = {}
ns.Sessions = Sessions

local MAX_ZONES = 40
local MAX_QUESTS = 200
local MAX_RARES = 100
local MAX_DEATHS = 100

-- Interactions that put both players in the same place open a session
-- (their kind's `opens`, Core/Rows.lua); anything else only joins one that
-- is already open. The session's own skeleton (`structural`) is stamped
-- with the session id like any other row, but not shown as highlights.
local Rows = ns.Rows

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

local function Gap()
    return ns.PositiveSetting("sessionGapMinutes") * 60
end

Sessions.Gap = Gap

-- The open session, if it belongs to the character that is logged in now.
function Sessions.Current()
    local id = ns.db.meta.openSession
    local session = id and ns.db.sessions[id]
    if not session or session.endedAt then return nil end
    if session.me ~= ns.ownGUID then return nil end
    return session
end

function Sessions.LastTogether(session)
    local last = session.startedAt
    for _, p in pairs(session.participants) do
        if p.last > last then last = p.last end
    end
    return last
end

function Sessions.Duration(session)
    return (session.endedAt or Sessions.LastTogether(session)) - session.startedAt
end

-- GUID -> session ids, in memory only. Derived from the participants, so it
-- is never saved: a second saved copy of membership would drift. Built on
-- first use, appended to as participants join, and dropped when something
-- removes one. Keyed on the sessions table too, so a replaced database (a
-- test, a future import) is never read through a stale index.
local byGuid, byGuidSource

local function ByGuid()
    if byGuid and byGuidSource == ns.db.sessions then return byGuid end

    byGuid, byGuidSource = {}, ns.db.sessions
    for id, session in pairs(ns.db.sessions) do
        for guid in pairs(session.participants) do
            local list = ns.ListFor(byGuid, guid)
            list[#list + 1] = id
        end
    end
    return byGuid
end

local function Indexed(guid, id)
    if not byGuid or byGuidSource ~= ns.db.sessions then return end
    local list = ns.ListFor(byGuid, guid)
    list[#list + 1] = id
end

-- Every session a character took part in, newest first.
function Sessions.For(guid)
    guid = ns.SafeGUID(guid)
    local list = {}
    if not guid then return list end

    local ids = ByGuid()[guid] or {}
    for i = 1, #ids do
        local session = ns.db.sessions[ids[i]]
        if session and session.participants[guid] then list[#list + 1] = session end
    end
    table.sort(list, function(a, b) return a.startedAt > b.startedAt end)
    return list
end

-- Every session on record, newest first: /sd sessions without a name.
function Sessions.All()
    local list = {}
    for _, session in pairs(ns.db.sessions) do list[#list + 1] = session end
    table.sort(list, function(a, b) return a.startedAt > b.startedAt end)
    return list
end

-- Deaths in the session, the user's and every participant's together.
function Sessions.DeathCount(session)
    local deaths = 0
    for _, n in pairs(session.deaths) do deaths = deaths + n end
    return deaths
end

-- SES-5: what happened inside the session, oldest first.
function Sessions.Highlights(session)
    local list = {}
    for guid in pairs(session.participants) do
        local rows = ns.Interactions.For(guid)
        if rows then
            for i = 1, #rows do
                local row = rows[i]
                if row.session == session.id and not Rows.Get(row.type).structural then
                    list[#list + 1] = row
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)
    return list
end

-- A participant still counts as present: not yet written off by the gap.
local function Live(p)
    return p and not p.done
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

local function TrackZone(session)
    local zone = ns.Where().zone
    if not zone or #session.zones >= MAX_ZONES then return end
    -- Each zone once: walking to and fro across a border (Stormwind City
    -- and the Deeprun Tram) is not another place (21 Oct, in the client).
    for i = 1, #session.zones do
        if session.zones[i] == zone then return end
    end
    session.zones[#session.zones + 1] = zone
    -- The People index reads the zones ("met in"), and Sessions.Zone
    -- gets here without going through Together's own check.
    ns.Touch()
end

-- A session record under the next id. `opts` may carry any of the record's
-- fields -- source, startedAt (now), endedAt, participants, others, zones,
-- deaths -- and /sd testdata's `test` mark. Without endedAt it is the open
-- session (SES-1) and starts at the user's current level; with one it is
-- written after the fact, when today's level would be wrong for it.
function Sessions.New(opts)
    local meta = ns.db.meta
    local id = meta.nextSessionId or 1
    meta.nextSessionId = id + 1

    local session = {
        id = id,
        me = ns.ownGUID,
        startedAt = ns.Now(),
        participants = {},
        others = 0,
        zones = {},
        deaths = {},
    }
    for key, value in pairs(opts or {}) do session[key] = value end
    session.id = id

    ns.db.sessions[id] = session
    for guid in pairs(session.participants) do Indexed(guid, id) end
    -- Written with its participants (/sd testdata): the People list counts it.
    -- An empty one changes nothing until Together adds someone.
    if next(session.participants) then ns.Touch() end

    if not session.endedAt then
        session.myLevelStart = session.myLevelStart or ns.Plain(UnitLevel("player"))
        meta.openSession = id
        ns.Debug("session %d opened (%s)", id, tostring(session.source))
    end
    return session
end

-- Closing drops the working flags, so a closed session holds only its record.
function Sessions.Close(session, at)
    if not session or session.endedAt then return end

    session.endedAt = at or Sessions.LastTogether(session)
    for _, p in pairs(session.participants) do
        p.done, p.noCredit = nil, nil
    end

    if ns.db.meta.openSession == session.id then
        ns.db.meta.openSession = nil
    end

    ns.Debug("session %d closed after %d min", session.id,
        math.floor(Sessions.Duration(session) / 60))
end

-- The one way a diary entry becomes, or stays, present. `how` is "group" or
-- "nearby"; `mayOpen` says whether this signal is allowed to start a session
-- (SES-2 step 1) or only to keep one going (step 2).
--
-- Time between two signals counts as together as long as it is within the
-- gap: that is what "stays open while together" means when the evidence
-- arrives in pulses.
function Sessions.Together(guid, how, mayOpen)
    guid = ns.SafeGUID(guid)
    if not guid or guid == ns.ownGUID or not ns.Diary.IsDiary(guid) then return nil end

    local now = ns.Now()
    local session = Sessions.Current()
    if not session then
        if not mayOpen then return nil end
        session = Sessions.New({ startedAt = now, source = how })
    end

    if how == "group" then session.source = "group" end

    local record = ns.Characters.Get(guid)
    local level = record and record.level

    local p = session.participants[guid]
    local last, seconds, zones = p and p.last, p and p.seconds, #session.zones
    if not p then
        p = { since = now, last = now, seconds = 0, levelStart = level }
        session.participants[guid] = p
        Indexed(guid, session.id)
    elseif p.done or p.noCredit then
        -- Back after the gap, or the first pulse after a login: the time in
        -- between was not spent together.
        p.done, p.noCredit = nil, nil
        p.last = now
    else
        local elapsed = now - p.last
        if elapsed > 0 and elapsed <= Gap() then
            p.seconds = p.seconds + elapsed
        end
        p.last = now
    end

    p.levelEnd = level or p.levelEnd
    session.myLevelEnd = ns.Plain(UnitLevel("player")) or session.myLevelEnd
    TrackZone(session)

    -- What the People index reads of a session (AddSession): the
    -- participant's since/last/seconds/levelStart, and the zones. Two pulses
    -- in the same second change none of it.
    if last == nil or p.last ~= last or p.seconds ~= seconds or #session.zones ~= zones then
        ns.Touch()
    end

    return session
end

-- Called by Interactions.Add for every row it stores; returns the session id
-- to stamp on the row, or nil. `live` is false for backfilled rows, which
-- describe the past and must not open anything now.
function Sessions.Note(guid, kind, live)
    guid = ns.SafeGUID(guid)
    if not guid or not ns.Diary.IsDiary(guid) then return nil end

    if live and Rows.Get(kind).opens then
        local session = Sessions.Together(guid, "nearby", true)
        return session and session.id
    end

    local session = Sessions.Current()
    if session and Live(session.participants[guid]) then return session.id end
    return nil
end

-- The group as a whole: every diary entry in it is together with the user,
-- and everyone else is counted (prd.md section 7: "other group members are
-- counted"). `members` is a set of GUIDs.
function Sessions.Roster(members)
    local others = 0
    for guid in pairs(members) do
        if not Sessions.Together(guid, "group", true) then
            others = others + 1
        end
    end

    local session = Sessions.Current()
    if session and others > session.others then
        session.others = others
    end
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

-- SES-2 step 3, run on a timer. `grouped(guid)` and `nearby(guid)` are the
-- two presence tests; Capture/ supplies them so this file stays free of unit
-- tokens.
function Sessions.Tick(grouped, nearby, now)
    local session = Sessions.Current()
    if not session then return end
    now = now or ns.Now()

    local gap = Gap()
    local anyLive = false

    for guid, p in pairs(session.participants) do
        if grouped(guid) then
            Sessions.Together(guid, "group")
        elseif nearby(guid) then
            Sessions.Together(guid, "nearby")
        elseif not p.done and now - p.last > gap then
            p.done = true
            ns.Debug("session %d: %s apart for the gap", session.id,
                ns.Characters.FullName(guid) or guid)
        end
        if not p.done then anyLive = true end
    end

    if not anyLive then Sessions.Close(session) end
end

-- SES-3, at login: settle a session left open by the last logout or reload.
function Sessions.Resume(now)
    local id = ns.db.meta.openSession
    local session = id and ns.db.sessions[id]
    if not session then
        ns.db.meta.openSession = nil
        return
    end
    now = now or ns.Now()

    if session.endedAt or session.me ~= ns.ownGUID
        or now - Sessions.LastTogether(session) > Gap() then
        Sessions.Close(session)
        ns.db.meta.openSession = nil
        return
    end

    -- Same character, back within the gap: a reload or a short disconnect.
    -- The session carries on, but the time offline is not together time.
    for _, p in pairs(session.participants) do
        p.noCredit = true
    end
    ns.Debug("session %d resumed", session.id)
end

--------------------------------------------------------------------------
-- What happens inside a session (SES-4)
--------------------------------------------------------------------------

function Sessions.Zone()
    local session = Sessions.Current()
    if session then TrackZone(session) end
end

-- Quests and kills count as together only for participants who are grouped
-- right now: "quests completed together" is a group fact (INT-1's "quests
-- turned in while grouped").
local function EachGrouped(session, grouped, fn)
    for guid, p in pairs(session.participants) do
        if Live(p) and grouped(guid) then fn(guid, p) end
    end
end

function Sessions.Quest(questID, grouped)
    local session = Sessions.Current()
    questID = ns.Plain(questID)
    if not session or type(questID) ~= "number" then return 0 end

    local n = 0
    EachGrouped(session, grouped, function(_, p)
        p.quests = p.quests or {}
        if #p.quests < MAX_QUESTS then p.quests[#p.quests + 1] = questID end
        n = n + 1
    end)
    return n
end

-- `rare` is { name, npcID, kind }, already plain.
function Sessions.Rare(rare, grouped)
    local session = Sessions.Current()
    if not session or not rare then return 0 end

    local n = 0
    local now = ns.Now()
    EachGrouped(session, grouped, function(_, p)
        p.rares = p.rares or {}
        if #p.rares < MAX_RARES then
            p.rares[#p.rares + 1] = {
                name = rare.name, npcID = rare.npcID, kind = rare.kind, time = now,
            }
        end
        n = n + 1
    end)
    return n
end

-- SES-4: the user's level at the end of the open session, on a level-up.
-- Together keeps it current too, but a level-up between two pulses would
-- otherwise wait for the next one.
function Sessions.MyLevel(level)
    local session = Sessions.Current()
    level = ns.Plain(level)
    if not session or type(level) ~= "number" then return false end
    session.myLevelEnd = level
    return true
end

-- Deaths of the user or of a participant who is present. Keyed by GUID so a
-- profile can say whose deaths they were.
--
-- Each death also gets a record in `session.deathLog` -- { guid, time, zone,
-- subZone, killer } -- which the timeline shows as a line. `killer` is
-- whatever the deaths' capture could tell at the moment of death; it may be
-- nil, and the death recap can replace it later (SetKiller). Returns the
-- record, or nil when the death did not count.
function Sessions.Death(guid, killer)
    local session = Sessions.Current()
    guid = ns.SafeGUID(guid)
    if not session or not guid then return nil end

    if guid ~= ns.ownGUID then
        if not Live(session.participants[guid]) then return false end
    else
        local anyLive = false
        for _, p in pairs(session.participants) do
            if Live(p) then anyLive = true break end
        end
        if not anyLive then return nil end
    end

    session.deaths[guid] = (session.deaths[guid] or 0) + 1

    session.deathLog = session.deathLog or {}
    if #session.deathLog >= MAX_DEATHS then return nil end
    local where = ns.Where()
    local death = { guid = guid, time = ns.Now(), zone = where.zone, subZone = where.subZone, killer = killer }
    session.deathLog[#session.deathLog + 1] = death
    ns.Touch()
    return death
end

-- A better answer than the one the death was recorded with.
function Sessions.SetKiller(death, killer)
    if not death or not killer then return end
    death.killer = killer
    ns.Touch()
end

--------------------------------------------------------------------------
-- Seen around (SES-9)
--------------------------------------------------------------------------
--
-- A diary entry you keep running into without grouping. Not a together
-- session: nothing was done together, so it never opens one, never counts as
-- meeting them, and the journal shows it with less weight.
--
-- Built from the sighting pipeline's pulses, which come at most once a minute
-- per character and stop in cities and instances (SIG-5, SIG-6). Pulses
-- within the session gap of each other make one stretch. A stretch needs
-- AROUND_MIN pulses to count as "repeatedly"; anything shorter was a glimpse,
-- and is overwritten by the next stretch rather than kept forever.
--
-- Stored apart from db.sessions, as db.around[guid] = { stretch, ... }:
-- { start, last, count, zones, me }. Kept permanently, like everything else about
-- a diary entry.

local AROUND_MIN = 3
local AROUND_ZONES = 10
Sessions.AROUND_MIN = AROUND_MIN

function Sessions.Around(guid, now, zone)
    guid = ns.SafeGUID(guid)
    if not guid or guid == ns.ownGUID or not ns.Diary.IsDiary(guid) then return nil end

    -- Already together: the open session is the record of this.
    local session = Sessions.Current()
    if session and Live(session.participants[guid]) then return nil end

    now = now or ns.Now()
    local list = ns.ListFor(ns.db.around, guid)

    local stretch = list[#list]
    -- One character's stretch, in a diary they share (DAT-1).
    if stretch and stretch.me == ns.ownGUID and now - stretch.last <= Gap() then
        stretch.last = math.max(stretch.last, now)
        stretch.count = stretch.count + 1
    else
        if stretch and stretch.count < AROUND_MIN then list[#list] = nil end
        stretch = { start = now, last = now, count = 1, zones = {}, me = ns.ownGUID }
        list[#list + 1] = stretch
    end

    local zones = stretch.zones
    if zone and zones[#zones] ~= zone and #zones < AROUND_ZONES then
        zones[#zones + 1] = zone
    end

    -- No ns.Touch: nothing derived reads db.around. The journal's timeline
    -- builds its seen-around lines fresh from it on every refresh.
    return stretch
end

-- Every stretch on record, glimpses included, oldest first: SES-9's in-game
-- check (/sd sightings around) wants to see what did not make the timeline.
function Sessions.AroundAll(guid)
    guid = ns.SafeGUID(guid)
    local list = {}
    for i, stretch in ipairs(guid and ns.db.around[guid] or {}) do list[i] = stretch end
    return list
end

-- The stretches that count, newest first.
function Sessions.AroundFor(guid)
    guid = ns.SafeGUID(guid)
    local list = {}
    local stored = guid and ns.db.around[guid]
    if not stored then return list end

    for i = #stored, 1, -1 do
        if stored[i].count >= AROUND_MIN then list[#list + 1] = stored[i] end
    end
    return list
end

-- DIA-7's "delete everything": the person leaves every session, and a session
-- left with nobody in it goes too. nil forgets everyone (PRV-3); checked
-- before SafeGUID, which turns an unreadable GUID into nil as well.
function Sessions.Forget(guid)
    if guid == nil then
        local dropped = ns.CountKeys(ns.db.sessions)
        wipe(ns.db.sessions)
        wipe(ns.db.around)
        ns.db.meta.openSession = nil
        byGuid = nil
        ns.Touch()
        return dropped
    end

    guid = ns.SafeGUID(guid)
    if not guid then return 0 end

    local dropped = 0
    for id, session in pairs(ns.db.sessions) do
        -- A forgotten player who killed somebody: the death stays, nameless.
        for _, death in ipairs(session.deathLog or {}) do
            if death.killer and death.killer.guid == guid then death.killer = nil end
        end

        if session.participants[guid] then
            session.participants[guid] = nil
            session.deaths[guid] = nil
            local log = session.deathLog or {}
            for i = #log, 1, -1 do
                if log[i].guid == guid then table.remove(log, i) end
            end

            if next(session.participants) == nil then
                ns.db.sessions[id] = nil
                if ns.db.meta.openSession == id then ns.db.meta.openSession = nil end
                dropped = dropped + 1
            end
        end
    end
    ns.db.around[guid] = nil
    byGuid = nil
    ns.Touch()
    return dropped
end
ns.RegisterStore("sessions", Sessions.Forget)

-- PLAYER_LOGOUT: credit the time up to now for everyone still grouped, so a
-- real logout closes at the right moment when Resume settles it.
function Sessions.Flush(grouped)
    local session = Sessions.Current()
    if not session then return end

    for guid, p in pairs(session.participants) do
        if Live(p) and grouped(guid) then Sessions.Together(guid, "group") end
    end
end
