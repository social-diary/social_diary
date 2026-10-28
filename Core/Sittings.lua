-- Sittings: the user's own play sessions, a character's evenings at the
-- game (.claude/sittings-plan.md). Not Core/Sessions.lua's together
-- sessions, which are time spent with someone from the diary.
--
-- A sitting is present time with no gap of an hour or more (GAP) in it.
-- Present means in the world and not AFK: dead, in a battleground or on a
-- loading screen is still at the game, so a long one never splits an
-- evening. A /reload, a relog or a disconnect inside the hour carries on.
-- An AFK night with the client open, or a logout, ends it.
--
-- The route capture's tick is the heartbeat (Capture/Journey.lua calls
-- Note after its AFK check), so sittings are kept while the route is.
--
-- db.journey[charGUID].sittings = { "from;to", ... }, epoch seconds, oldest
-- first, one line a sitting like the route's segments (JRN-19's storage
-- reasoning). The last line is the one being played or the one that ended
-- last; a tick more than GAP after its `to` starts a new line, so there is
-- no open flag to settle. Diary schema 5 (Core/DB.lua) filled the list once
-- from the route's gaps for a road kept before (FromRoute); a route with no
-- list (/sd testdata's, an older test's) is read the same way.

local addonName, ns = ...

local Sittings = {}
ns.Sittings = Sittings

Sittings.GAP = 60 * 60

local function Pack(from, to)
    return ("%d;%d"):format(from, to)
end

local function Unpack(line)
    local from, to = line:match("^(%d+);(%d+)$")
    from, to = tonumber(from), tonumber(to)
    if not from then return nil end
    return from, to
end

-- The sittings the route shows: segments no further than GAP apart are
-- one sitting. Pauses inside (AFK, death, a battleground) leave the same
-- gap as a logout, so a past sitting may split where a present one would
-- not; nothing better is known of the time before the list was kept.
function Sittings.FromRoute(j)
    local list = {}
    local segments = j and ns.Journey and ns.Journey.All(j) or {}
    local cur
    for _, seg in ipairs(segments) do
        local from, to = seg.from, math.max(seg.to or seg.from, seg.from)
        if cur and from - cur.to <= Sittings.GAP then
            if to > cur.to then cur.to = to end
        else
            cur = { from = from, to = to }
            list[#list + 1] = cur
        end
    end
    return list
end

-- The lines FromRoute's list is saved as.
function Sittings.Lines(list)
    local lines = {}
    for i, s in ipairs(list) do lines[i] = Pack(s.from, s.to) end
    return lines
end

-- Decoded once and kept (weakly, by record) while the saved list is the
-- same, as Journey.Segments keeps the segments.
local decoded = setmetatable({}, { __mode = "k" })

-- Every sitting of route `j`, oldest first: { { from, to, id } }, `id` its
-- place in the list.
function Sittings.List(j)
    if not j then return {} end
    local raw = j.sittings
    if not raw then
        local list = Sittings.FromRoute(j)
        for i, s in ipairs(list) do s.id = i end
        return list
    end
    local hit = decoded[j]
    if hit and hit.raw == raw and hit.n == #raw and hit.last == raw[#raw] then return hit.list end
    local list = {}
    for i = 1, #raw do
        local from, to = Unpack(raw[i])
        if from then list[#list + 1] = { from = from, to = to, id = #list + 1 } end
    end
    decoded[j] = { raw = raw, n = #raw, last = raw[#raw], list = list }
    return list
end

-- The sitting holding `t`, or nil.
function Sittings.At(j, t)
    for _, s in ipairs(Sittings.List(j)) do
        if s.from <= t and t <= s.to then return s end
    end
    return nil
end

-- The heartbeat: the user is at the game at `now`. Extends the last
-- sitting, or starts one after the gap. A route without the list (kept
-- before it, if the migration has not met it) is filled from the route
-- first.
function Sittings.Note(j, now)
    if not j then return end
    if not j.sittings then j.sittings = Sittings.Lines(Sittings.FromRoute(j)) end
    local raw = j.sittings
    local from, to = nil, nil
    if raw[#raw] then from, to = Unpack(raw[#raw]) end
    if from and now >= to and now - to <= Sittings.GAP then
        raw[#raw] = Pack(from, now)
    elseif not from or now > to then
        raw[#raw + 1] = Pack(now, now)
        ns.Journey.Touch()
    end
end
