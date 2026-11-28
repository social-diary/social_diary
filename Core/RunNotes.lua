-- The player's own notes on a run's map (.claude/features/dungeon-notes.md):
-- the free card, laid on the Dungeon View's floor where the player put it.
-- Kept on the run, `visit.custom` in db.instances, oldest first, so it goes
-- with the run (a run deleted takes its notes with it) and nothing that reads
-- the route's cards (the zone plates, Choose, the left page) ever sees one:
--
--   visit.custom = { { kind, t, f, x, y, boss, level, <the kind's fields> } }
--
-- `f` is the floor's uiMapID and `x, y` the spot on that floor (0..1), as the
-- sheet's `At(floor, x, y)` takes them and ns.Dungeons.Unpoint gives them (the
-- pen's points are kept the same way, WAY-4), so a note shows on its own floor's
-- sheet only, or on a combined map holding it (the detected notes' rule).
-- `boss`, where the note is pinned to one, is the boss's name: its leader goes
-- to the face, wherever the face was moved. No `mapID` (nothing taking zone
-- cards can mistake one for its own) and no `caption`: the free card's
-- "Write it into the entry" is the left page's, which these never reach.
--
-- The fields are cleaned by the kind's spec, through Custom.Fill, exactly as
-- a zone card's are. Only the free card for now (the user, 28 Nov); a kind is
-- offered here where it is in KINDS. Only the character playing writes on a
-- run of their own (`visit.me`): it is their writing. The time is never asked
-- (TimeOf): it orders the notes and places a note on a timeline.

local addonName, ns = ...

local RunNotes = {}
ns.RunNotes = RunNotes

-- The kinds a run's map takes, and the fields each leaves out here.
local KINDS = { noteCard = { skip = { caption = true } } }
RunNotes.KINDS = KINDS

function RunNotes.Offered(kind)
    return KINDS[kind] ~= nil and ns.Custom.Offered(kind)
end

-- Whether the character playing may write on `visit`.
function RunNotes.Writable(visit)
    return type(visit) == "table" and (visit.me or ns.ownGUID) == ns.ownGUID and ns.ownGUID ~= nil
end

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

local function Copy(rec, visit)
    local copy = {}
    for key, value in pairs(rec) do copy[key] = value end
    copy.customOf, copy.inserted, copy.visit = rec, true, visit
    return copy
end

-- Every note on the run, as the sheet reads them (copies, `customOf` the
-- saved record), oldest first. A note of a kind no longer offered is left out.
function RunNotes.List(visit)
    local list = {}
    for _, rec in ipairs(type(visit) == "table" and type(visit.custom) == "table" and visit.custom or {}) do
        if type(rec) == "table" and KINDS[rec.kind] and type(rec.t) == "number" then
            list[#list + 1] = Copy(rec, visit)
        end
    end
    return list
end

-- The notes saved on floor `floorID` (its uiMapID). The sheet asks its `At`
-- for the rest (a combined map holds several floors): this is for a caller
-- with one floor in hand.
function RunNotes.On(visit, floorID)
    local list = {}
    for _, rec in ipairs(RunNotes.List(visit)) do
        if rec.f == floorID then list[#list + 1] = rec end
    end
    return list
end

local function Position(visit, saved)
    for i, other in ipairs(type(visit) == "table" and visit.custom or {}) do
        if other == saved then return i end
    end
    return nil
end

local function Saved(rec)
    return rec and (rec.customOf or rec)
end

--------------------------------------------------------------------------
-- When
--------------------------------------------------------------------------

local function Norm(name)
    return ns.Dungeons.Norm(name)
end

-- When the run met `b` (a Dungeons boss record): the kill's end, else its
-- last pull's start; nil where it was never pulled.
local function BossTime(visit, b)
    local key = Norm(b.name)
    local killed, pulled
    for _, p in ipairs(visit.pulls or {}) do
        local same = (b.id ~= nil and p.id == b.id) or (type(p.name) == "string" and Norm(p.name) == key)
        if same then
            if p.killed and p.stop then killed = p.stop end
            pulled = p.start or pulled
        end
    end
    return killed or pulled
end

-- The time a note on `visit` at `where` ({ f, x, y, boss }) stands for:
-- its boss's fight, where it is pinned to one; else the fight of the nearest
-- boss on its floor the run met; else the run's start. Within the run always.
function RunNotes.TimeOf(visit, where)
    local D = ns.Dungeons
    local from = visit.startedAt or ns.Now()
    local to = visit.endedAt or ns.Now()
    local t
    local pinned = where.boss and D.Boss(visit.instanceID, where.boss)
    if pinned then t = BossTime(visit, pinned) end
    if not t and where.f and where.x and where.y then
        local best
        for _, b in ipairs(D.Bosses(visit.instanceID, visit.difficultyID, visit.wing)) do
            if tonumber(b.floor) == where.f and b.x and b.y then
                local bt = BossTime(visit, b)
                if bt then
                    local far = (b.x - where.x) ^ 2 + (b.y - where.y) ^ 2
                    if not best or far < best then best, t = far, bt end
                end
            end
        end
    end
    t = t or from
    return math.floor(math.max(from, math.min(t, math.max(from, to))))
end

-- The character's level on the run at `t`: their own line among its members,
-- else what their route says then.
local function LevelOn(visit, t)
    for _, m in ipairs(visit.members or {}) do
        if m.guid == (visit.me or ns.ownGUID) and type(m.level) == "number" then return m.level end
    end
    local j = ns.Journey.Mine()
    return j and ns.JourneyRecap.LevelAt(j, t) or nil
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- The spot as a note keeps it: a floor, a spot on it in 0..1, a boss by name
-- or none. Nil where the spot is not one.
local function Spot(where)
    if type(where) ~= "table" then return nil end
    local f, x, y = tonumber(where.f), tonumber(where.x), tonumber(where.y)
    if not (f and x and y) then return nil end
    local boss = type(where.boss) == "string" and where.boss ~= "" and where.boss or nil
    return f, math.max(0, math.min(1, x)), math.max(0, math.min(1, y)), boss
end

local function Touched()
    if ns.Touch then ns.Touch() end
    if ns.Hints and ns.Hints.Retire then ns.Hints.Retire("custom-events") end
end

-- A note of `kind` the player put on `visit` at `where` = { f, x, y, boss }.
-- Returns the saved record, or nil where it cannot be (another character's
-- run, a kind not offered, no spot).
function RunNotes.Insert(visit, kind, fields, where)
    if not (RunNotes.Writable(visit) and RunNotes.Offered(kind)) then return nil end
    local f, x, y, boss = Spot(where)
    if not f then return nil end
    local t = RunNotes.TimeOf(visit, { f = f, x = x, y = y, boss = boss })
    local rec = { kind = kind, t = t, f = f, x = x, y = y, boss = boss, level = LevelOn(visit, t) }
    if not ns.Custom.Fill(rec, kind, fields, ns.Journey.Mine(), true, KINDS[kind].skip) then return nil end
    if type(visit.custom) ~= "table" then visit.custom = {} end
    local at = #visit.custom + 1
    while at > 1 and (visit.custom[at - 1].t or 0) > t do at = at - 1 end
    table.insert(visit.custom, at, rec)
    Touched()
    return rec
end

-- Fields changed on a note of the run's.
function RunNotes.Edit(visit, rec, fields)
    local saved = Saved(rec)
    if not (RunNotes.Writable(visit) and saved and Position(visit, saved) and KINDS[saved.kind]) then return false end
    ns.Custom.Fill(saved, saved.kind, fields, ns.Journey.Mine(), false, KINDS[saved.kind].skip)
    Touched()
    return true
end

-- A note moved on the map (another floor, a boss or off one). Its time
-- follows the new spot, and the list stays oldest first.
function RunNotes.Move(visit, rec, where)
    local saved = Saved(rec)
    local at = saved and Position(visit, saved)
    if not (RunNotes.Writable(visit) and at) then return false end
    local f, x, y, boss = Spot(where)
    if not f then return false end
    saved.f, saved.x, saved.y, saved.boss = f, x, y, boss
    saved.t = RunNotes.TimeOf(visit, { f = f, x = x, y = y, boss = boss })
    table.remove(visit.custom, at)
    local to = #visit.custom + 1
    while to > 1 and (visit.custom[to - 1].t or 0) > saved.t do to = to - 1 end
    table.insert(visit.custom, to, saved)
    Touched()
    return true
end

-- A note gone. The list goes with its last.
function RunNotes.Remove(visit, rec)
    local at = Position(visit, Saved(rec))
    if not (RunNotes.Writable(visit) and at) then return false end
    table.remove(visit.custom, at)
    if #visit.custom == 0 then visit.custom = nil end
    Touched()
    return true
end

--------------------------------------------------------------------------
-- Forgetting (PRV-3): Core/Instances.lua's Forget asks this
--------------------------------------------------------------------------

-- Someone forgotten leaves every note on the run that linked to them (nil:
-- everyone). The note and the name as written stay, as on the route's cards
-- (Core/Custom.lua's ForgetOn).
function RunNotes.Forget(visit, guid)
    for _, rec in ipairs(type(visit) == "table" and type(visit.custom) == "table" and visit.custom or {}) do
        local spec = type(rec) == "table" and ns.Custom.Spec(rec.kind)
        for _, field in ipairs(spec and spec.fields or {}) do
            if field.type == "person" then
                local key = ns.Custom.GuidKey(field)
                if rec[key] and (guid == nil or rec[key] == guid) then rec[key] = nil end
            elseif field.type == "people" and type(rec[field.key]) == "table" then
                for _, p in ipairs(rec[field.key]) do
                    if type(p) == "table" and p.guid and (guid == nil or p.guid == guid) then p.guid = nil end
                end
            end
        end
    end
end
