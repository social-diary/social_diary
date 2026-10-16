-- Instance visits (INS-1), as prd.md's data model has them, and the one
-- visit open now (.claude/dungeon-visits-prd.md §4, §5, §18).
--
-- db.instances[visitId] = { id, me, instanceID, name, instanceType ("party"
-- or "raid"), difficulty, difficultyID, wing, startedAt, endedAt,
-- members = { { guid, first, surname, class, role, level, joined, left } },
-- bossesKilled = { name, ... }, bossTotal, deaths, wipes, sessionIds,
-- spans = { { from, to, ghost } }, pulls = { { id, name, start, stop,
-- killed, secret } }, deathLog = { { guid, time, killer, pull, fight } },
-- loot = { { guid, item, itemID, time } }, inferred = { [boss name] =
-- "loot" } (a kill only its loot told of) }.
--
-- Capture/Instances.lua tells this file what the client says (in, out, the
-- group, pulls, loot), and the deaths' capture tells it who died. The open
-- visit's id is meta.openVisit, so a /reload carries on with it. /sd
-- testdata writes visits through New, the timeline (TLN-4) reads them
-- through For, and Core/DungeonRun.lua places their moments on the map.

local addonName, ns = ...

local Instances = {}
ns.Instances = Instances

-- Out of the dungeon this long and the run is over (INS-7, INS-9): a ghost
-- run, a hearth to repair or a disconnect all come back sooner.
local GAP = 30 * 60
-- A run that is kept (INS-10): grouped with someone at some point, a boss
-- killed, or this long inside.
local KEEP_SECONDS = 10 * 60
-- Caps, so one long night cannot grow a record without end.
local MAX_DEATHS, MAX_LOOT, MAX_PULLS, MAX_SPANS = 60, 40, 60, 40

Instances.GAP = GAP

-- Stores a new visit under the next id and returns it. The caller's table is
-- kept, not copied: it is the record.
function Instances.New(visit)
    local meta = ns.db.meta
    local id = meta.nextVisitId or 1
    meta.nextVisitId = id + 1

    visit.id = id
    visit.me = visit.me or ns.ownGUID
    ns.db.instances[id] = visit
    return visit
end

-- Every visit, in no particular order.
function Instances.All()
    local list = {}
    for _, visit in pairs(ns.db.instances) do list[#list + 1] = visit end
    return list
end

-- The visits a character was a member of. Few enough to scan: a handful a
-- night, not a sighting stream.
function Instances.For(guid)
    guid = ns.SafeGUID(guid)
    local list = {}
    if not guid then return list end

    for _, visit in pairs(ns.db.instances) do
        for _, member in ipairs(visit.members or {}) do
            if member.guid == guid then
                list[#list + 1] = visit
                break
            end
        end
    end
    return list
end

-- One visit, by id. /sd testdata takes its made-up visits out this way.
function Instances.Remove(id)
    if ns.db.instances[id] == nil then return false end
    if ns.db.meta.openVisit == id then ns.db.meta.openVisit = nil end
    ns.db.instances[id] = nil
    return true
end

--------------------------------------------------------------------------
-- The open visit
--------------------------------------------------------------------------

-- The visit open now, or nil. One of the user's other characters' visit is
-- not this one's.
function Instances.Current()
    local id = ns.db.meta.openVisit
    local visit = id and ns.db.instances[id]
    if not visit or visit.me ~= ns.ownGUID then return nil end
    return visit
end

local function Span(visit)
    local spans = visit.spans
    return spans and spans[#spans]
end

-- Inside it now: the last span has no end.
function Instances.Inside()
    local visit = Instances.Current()
    local span = visit and Span(visit)
    return span ~= nil and span.to == nil, visit
end

local function Member(visit, guid)
    for _, m in ipairs(visit.members) do
        if m.guid == guid then return m end
    end
end

local function SecondsInside(visit, now)
    local n = 0
    for _, span in ipairs(visit.spans or {}) do
        n = n + math.max(0, (span.to or now) - span.from)
    end
    return n
end

-- Whether a run is worth keeping (INS-10).
local function Kept(visit, now)
    if #(visit.bossesKilled or {}) > 0 then return true end
    for _, m in ipairs(visit.members or {}) do
        if m.guid ~= visit.me then return true end
    end
    return SecondsInside(visit, now) >= KEEP_SECONDS
end
Instances.Kept = Kept

-- The run is over: it ends at the last time out, and a run not worth
-- keeping goes (the route keeps its dungeon segment either way).
function Instances.Close(now)
    local visit = Instances.Current()
    ns.db.meta.openVisit = nil
    if not visit then return nil end
    now = now or ns.Now()
    local span = Span(visit)
    if span and not span.to then span.to = now end
    visit.endedAt = span and span.to or now
    visit.pull = nil
    if not Kept(visit, now) then
        ns.db.instances[visit.id] = nil
        ns.Debug("visit %d to %s: not kept (alone, no kill, short)", visit.id, tostring(visit.name))
        return nil
    end
    ns.Touch()
    return visit
end

-- In a party or raid instance (INS-6). The same one within GAP of leaving
-- it carries on (INS-7); another one, or a later return, is a new run.
-- `info` is { instanceID, name, instanceType, difficultyID, difficulty }.
function Instances.Enter(info, now)
    now = now or ns.Now()
    local visit = Instances.Current()
    local span = visit and Span(visit)
    if visit and visit.instanceID == info.instanceID then
        if span and not span.to then return visit end
        if span and now - span.to <= GAP then
            if #visit.spans < MAX_SPANS then
                visit.spans[#visit.spans + 1] = { from = now }
            else
                span.to = nil
            end
            ns.Touch()
            return visit
        end
    end
    if visit then Instances.Close(now) end

    visit = Instances.New({
        instanceID = info.instanceID, name = info.name, instanceType = info.instanceType,
        difficultyID = info.difficultyID, difficulty = info.difficulty,
        startedAt = now, members = {}, bossesKilled = {}, deaths = 0, wipes = 0,
        spans = { { from = now } }, pulls = {}, deathLog = {}, loot = {}, sessionIds = {},
        bossTotal = ns.Dungeons and ns.Dungeons.BossTotal(info.instanceID, info.difficultyID) or nil,
    })
    ns.db.meta.openVisit = visit.id
    local session = ns.Sessions.Current and ns.Sessions.Current()
    if session then visit.sessionIds[1] = session.id end
    ns.Touch()
    return visit
end

-- Out of it (a loading screen, a hearth, released as a ghost). `ghost`: the
-- user left dead, so a corpse run follows (INS-32).
function Instances.Leave(now, ghost)
    local visit = Instances.Current()
    local span = visit and Span(visit)
    if not span or span.to then return end
    span.to = now or ns.Now()
    span.ghost = ghost or nil
    visit.endedAt = span.to
    ns.Touch()
end

-- Out longer than GAP, or at login: a run left open ends.
function Instances.Expire(now)
    now = now or ns.Now()
    local visit = Instances.Current()
    if not visit then
        ns.db.meta.openVisit = nil
        return
    end
    local span = Span(visit)
    if span and span.to and now - span.to > GAP then Instances.Close(span.to) end
end

-- The game reset the instance: the next time in is a new run (INS-8).
function Instances.Reset(now)
    local inside = Instances.Inside()
    if not inside then Instances.Close(now) end
end

-- Who is in the group now, inside (INS-12): `group` is { [guid] = true }
-- for every readable member but the user. New ones join; the missing ones
-- leave, only when the scan was `complete` (a secret GUID is not a leave).
function Instances.Roster(group, complete, now)
    local inside, visit = Instances.Inside()
    if not inside then return end
    now = now or ns.Now()
    for guid in pairs(group) do
        local m = Member(visit, guid)
        local first, surname = ns.Characters.Name(guid)
        local record = ns.Characters.Get(guid)
        if not m then
            m = { guid = guid, joined = now }
            visit.members[#visit.members + 1] = m
        end
        m.left = nil
        m.first, m.surname = first or m.first, surname or m.surname
        if record then m.class, m.level = record.class or m.class, m.level or record.level end
    end
    if complete then
        for _, m in ipairs(visit.members) do
            if m.guid ~= visit.me and not group[m.guid] and not m.left then m.left = now end
        end
    end
    -- The user is a member too, as in the data model. Their own character
    -- has no record among the characters observed, so read the unit.
    local me = Member(visit, visit.me)
    if not me then
        me = { guid = visit.me, joined = visit.startedAt }
        table.insert(visit.members, 1, me)
    end
    if not me.first then
        local first, surname = ns.Characters.Name(visit.me)
        if not first and UnitName then first = ns.Plain(UnitName("player")) end
        me.first, me.surname = first, surname
        if UnitClass then me.class = me.class or ns.Plain(select(2, UnitClass("player"))) end
        if UnitLevel then me.level = me.level or ns.Plain(UnitLevel("player")) end
    end
    ns.Touch()
end

-- Whether a death or a loot line is one of this run's: the user, or a
-- member who had not left.
local function InRun(visit, guid)
    if guid == ns.ownGUID then return true end
    local m = Member(visit, guid)
    return m ~= nil and not m.left
end

--------------------------------------------------------------------------
-- Pulls and kills (INS-28, INS-29)
--------------------------------------------------------------------------

local function BossName(visit, id, name)
    if name then return name end
    local boss = id and ns.Dungeons and ns.Dungeons.Boss(visit.instanceID, id)
    return boss and boss.name
end

-- A boss was pulled. `id` and `name` are nil when the client kept them
-- secret, and `secret` says so.
function Instances.Pull(id, name, secret, now)
    local inside, visit = Instances.Inside()
    if not inside then return nil end
    if #visit.pulls >= MAX_PULLS then return nil end
    local pull = { id = id, name = BossName(visit, id, name), start = now or ns.Now(), secret = secret or nil }
    visit.pulls[#visit.pulls + 1] = pull
    visit.pull = #visit.pulls
    ns.Touch()
    return pull
end

-- A kill is kept under the client's name: the card prints it. The data may
-- name the same encounter otherwise (3495 is "Infurnus" in the client and
-- "Magmatus" in the data, seen 2026-10-16), so anything that looks a kill
-- up in the data goes by the pull's id (ns.Dungeons.Killed). `dataName` is
-- the data's name, for the wing.
local function Killed(visit, name, now, dataName)
    if not name then return end
    for _, n in ipairs(visit.bossesKilled) do
        if n == name then return end
    end
    visit.bossesKilled[#visit.bossesKilled + 1] = name
    if #visit.bossesKilled == 1 and ns.Dungeons then
        visit.wing = visit.wing or ns.Dungeons.WingOf(visit.instanceID, dataName or name)
        if visit.wing then
            visit.bossTotal = ns.Dungeons.BossTotal(visit.instanceID, visit.difficultyID, visit.wing)
        end
    end
end

-- A pull that ended without a kill is a wipe when at least half the group
-- died in it (MAP-10; ns.DungeonRun.Half). Its deaths are already in.
local function Wiped(visit, pull)
    local index
    for i, p in ipairs(visit.pulls) do
        if p == pull then index = i end
    end
    local n = 0
    for _, d in ipairs(visit.deathLog or {}) do
        if d.pull == index then n = n + 1 end
    end
    return n > 0 and ns.DungeonRun and n >= ns.DungeonRun.Half(visit)
end

-- A pull ended: killed, or not (a wipe, a reset). Matches the open pull,
-- else the last one of that boss, else starts and ends one (a kill the
-- start of which was missed, BOSS_KILL alone).
function Instances.PullEnd(id, name, killed, secret, now)
    local inside, visit = Instances.Inside()
    if not inside then return nil end
    now = now or ns.Now()
    name = BossName(visit, id, name)
    local pull = visit.pull and visit.pulls[visit.pull]
    if pull and pull.stop then pull = nil end
    if not pull then
        for i = #visit.pulls, 1, -1 do
            local p = visit.pulls[i]
            if (id and p.id == id) or (name and p.name == name) then
                if p.stop and p.killed then return p end
                pull = p
                break
            end
        end
    end
    if not pull then
        pull = Instances.Pull(id, name, secret, now)
        if not pull then return nil end
    end
    pull.stop = now
    pull.killed = killed or nil
    pull.id, pull.name = pull.id or id, pull.name or name
    if secret then pull.secret = true end
    visit.pull = nil
    if killed then
        local boss = pull.id and ns.Dungeons and ns.Dungeons.Boss(visit.instanceID, pull.id)
        Killed(visit, pull.name, now, boss and boss.name)
    elseif Wiped(visit, pull) then
        visit.wipes = (visit.wipes or 0) + 1
    end
    ns.Touch()
    return pull
end

--------------------------------------------------------------------------
-- Deaths (INS-30) and loot (INS-31)
--------------------------------------------------------------------------

-- Whether a boss fight is going on, when the pull events are missing
-- (feasibility report C4: not secret).
local function Fighting()
    local enc = C_InstanceEncounter
    if not (enc and enc.IsEncounterInProgress) then return nil end
    local ok, on = pcall(enc.IsEncounterInProgress)
    return ok and ns.Plain(on) == true or nil
end

-- Someone in the run died. Returns the record, for the killer to be set
-- later, or nil when it is not this run's.
function Instances.Death(guid, killer, now)
    guid = ns.SafeGUID(guid)
    local visit = Instances.Current()
    if not visit or not guid then return nil end
    local span = Span(visit)
    if not span or span.to then return nil end
    if not InRun(visit, guid) then return nil end
    visit.deaths = (visit.deaths or 0) + 1
    if #visit.deathLog >= MAX_DEATHS then return nil end
    local open = visit.pull and visit.pulls[visit.pull]
    local death = { guid = guid, time = now or ns.Now(), killer = killer,
        pull = open and not open.stop and visit.pull or nil,
        fight = (not (open and not open.stop) and Fighting()) or nil }
    visit.deathLog[#visit.deathLog + 1] = death
    ns.Touch()
    return death
end

function Instances.SetKiller(death, killer)
    if not death or not killer then return end
    death.killer = killer
    ns.Touch()
end

-- Someone in the run got an item.
function Instances.Loot(guid, link, now)
    guid = ns.SafeGUID(guid)
    local inside, visit = Instances.Inside()
    if not inside or not guid or type(link) ~= "string" then return nil end
    if not InRun(visit, guid) or #visit.loot >= MAX_LOOT then return nil end
    local itemID = tonumber(link:match("item:(%d+)"))
    local entry = { guid = guid, item = link, itemID = itemID, time = now or ns.Now() }
    visit.loot[#visit.loot + 1] = entry
    -- Loot off a boss's table proves the kill, also one the pull events
    -- missed (a loading screen, a /reload in the fight): MAP-16.
    local boss = ns.Dungeons and ns.Dungeons.LootBoss(visit.instanceID, itemID)
    if boss and not ns.Dungeons.IsTrash(boss) then
        local known
        for _, n in ipairs(visit.bossesKilled) do
            if n == boss.name then known = true end
        end
        for _, p in ipairs(visit.pulls) do
            if p.killed and p.id == boss.id then known = true end
        end
        if not known then
            Killed(visit, boss.name, entry.time)
            visit.inferred = visit.inferred or {}
            visit.inferred[boss.name] = "loot"
        end
    end
    ns.Touch()
    return entry
end

--------------------------------------------------------------------------
-- Forgetting
--------------------------------------------------------------------------

-- PRV-3: a visit's member list holds names, so a forgotten person leaves
-- it, with their deaths and their loot. The visit itself stays: it is the
-- user's history, and the other members'. nil forgets every visit.
function Instances.Forget(guid)
    if guid == nil then
        wipe(ns.db.instances)
        ns.db.meta.openVisit = nil
        return
    end
    for _, visit in pairs(ns.db.instances) do
        for _, list in ipairs({ visit.members or {}, visit.deathLog or {}, visit.loot or {} }) do
            for i = #list, 1, -1 do
                if list[i].guid == guid then table.remove(list, i) end
            end
        end
    end
end
ns.RegisterStore("instances", Instances.Forget)
