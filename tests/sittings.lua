-- Sittings (Core/Sittings.lua) and Your Diary's pieces, an entry by
-- sitting (Core/JourneyRecap.lua's Pieces; .claude/sittings-plan.md).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local J, R, S, Text = ns.Journey, ns.JourneyRecap, ns.Sittings, ns.UI.JourneyText
local SELF = F.SELF
local MULGORE, BARRENS = 1412, 1413
local H = 3600

local nextGuid = 0
local function Fresh(level, at)
    nextGuid = nextGuid + 1
    return J.Begin(("Player-0000-SIT%05d"):format(nextGuid), at or 1000000, level or 10, MULGORE)
end

local function Lines(j)
    local out = {}
    for _, s in ipairs(S.List(j)) do out[#out + 1] = (s.from) .. "-" .. (s.to) end
    return table.concat(out, " ")
end

--------------------------------------------------------------------------
Section("the heartbeat: one sitting until an hour away")

local j = Fresh(10, 1000)
Eq(j.sittings, nil, "a new route has no list before its first beat")
S.Note(j, 1000)
Eq(Lines(j), "1000-1000", "the first beat begins a sitting")
S.Note(j, 1005)
S.Note(j, 1000 + 40 * 60)
Eq(Lines(j), "1000-3400", "beats within the hour extend it")
S.Note(j, 3400 + H)
Eq(#S.List(j), 1, "an hour exactly is still the same sitting")
S.Note(j, 3400 + H + H + 1)
Eq(#S.List(j), 2, "more than an hour away begins another")
Eq(S.At(j, 2000).from, 1000, "At finds the sitting holding a time")
Eq(S.At(j, 3400 + H + 30 * 60), nil, "At: nothing between sittings")
S.Note(j, 10)
Eq(#S.List(j), 2, "a beat before the last changes nothing")

--------------------------------------------------------------------------
Section("on the client: AFK ends it, death and dungeons do not")

mock.SetUnit("player", F.Like(SELF, { level = 10 }))
local Tick = ns._test.JourneyTick
mock.mapID, mock.position, mock.world = MULGORE, { x = 0.2, y = 0.2 }, { x = 1000, y = 666, inst = 1 }
local function Step(seconds)
    mock.now = mock.now + seconds
    Tick()
end
Step(5)
local mine = ns.db.journey[SELF.guid]
Eq(#S.List(mine), 1, "the first tick begins a sitting")
mock.dead = true
for _ = 1, 30 do Step(5 * 60) end
mock.dead = false
Eq(#S.List(mine), 1, "two and a half hours dead is still at the game")
mock.inInstance = true
for _ = 1, 15 do Step(5 * 60) end
mock.inInstance = false
Eq(#S.List(mine), 1, "an hour and more in a dungeon is still at the game")
mock.afk = true
for _ = 1, 15 do Step(5 * 60) end
mock.afk = false
Step(5)
Eq(#S.List(mine), 2, "over an hour AFK ends the sitting")
-- A /reload or a relog inside the hour: no tick in between, same sitting.
Step(30 * 60)
Eq(#S.List(mine), 2, "back within the hour (a relog) carries on")
Step(2 * H)
Eq(#S.List(mine), 3, "a logout of two hours: a new sitting")

--------------------------------------------------------------------------
Section("schema 5 fills the list from the route's gaps")

local Migrate = ns._test.Migrate
local function Seg(kind, from, to)
    return { kind = kind, from = from, to = to, mapID = MULGORE, levelFrom = 10, levelTo = 10, x = 0.1, y = 0.1,
        r = 20, seconds = to - from, pts = { 0.1, 0.1, 0.2, 0.2 } }
end
local old = {
    schema = 4,
    journey = {
        a = { startedAt = 0, startLevel = 1, levels = {}, marks = {},
            segments = { Seg("stop", 0, 600), Seg("road", 700, 1200), Seg("stop", 1200 + H + 1, 9000) } },
        b = { startedAt = 0, startLevel = 1, levels = {}, marks = {}, segments = {} },
        c = { startedAt = 0, startLevel = 1, levels = {}, marks = {}, segments = {}, sittings = { "5;6" } },
    },
}
-- As lines too, as an older build saved them.
old.journey.a.segments[2] = "r;700;500;1412;10;;" .. "AAAB"
Migrate(old, 5, ns._test.DiarySteps)
Eq(old.schema, 5, "the diary is at 5")
Eq(table.concat(old.journey.a.sittings, " "), "0;1200 " .. (1200 + H + 1) .. ";9000",
    "two sittings, split at the gap of over an hour")
Eq(#old.journey.b.sittings, 0, "a route with nothing on it gets an empty list")
Eq(old.journey.c.sittings[1], "5;6", "a list already there is kept")

--------------------------------------------------------------------------
Section("pieces: a level by sitting, cut only where a sitting begins")

local t0 = 2000000000 - 2000000000 % 86400 + 19 * H   -- an evening, near enough: tested by part below
j = Fresh(10, t0)
local function Add(kind, from, to, level, extra)
    local seg = Seg(kind, from, to)
    seg.levelFrom, seg.levelTo = level, level
    for k, v in pairs(extra or {}) do seg[k] = v end
    j.segments[#j.segments + 1] = seg
end
-- Sitting 1: levels 10 and 11, an hour each.
Add("stop", t0, t0 + H, 10)
j.levels[11] = { at = t0 + H, mapID = MULGORE, x = 0.1, y = 0.1 }
Add("stop", t0 + H, t0 + 2 * H, 11)
-- Sitting 2, a day later: level 11 for an hour, a run in it, then 12 is
-- reached and the user logs out five minutes on (a sliver).
local d = t0 + 86400
Add("stop", d, d + H, 11)
Add("dungeon", d + H, d + 2 * H, 11, { instanceID = 36, name = "The Deadmines", instanceType = "party" })
j.levels[12] = { at = d + 2 * H, mapID = MULGORE, x = 0.1, y = 0.1 }
Add("stop", d + 2 * H, d + 2 * H + 300, 12)
-- Sitting 3, two days on: level 12, two hours.
local e3 = t0 + 2 * 86400
Add("stop", e3, e3 + 2 * H, 12)
j.sittings = S.Lines({ { from = t0, to = t0 + 2 * H }, { from = d, to = d + 2 * H + 300 },
    { from = e3, to = e3 + 2 * H } })

local killed = { id = 7, me = "x", instanceID = 36, name = "The Deadmines", startedAt = d + H + 10,
    endedAt = d + 2 * H, bossesKilled = { "Rhahk'Zor" } }
local peeked = { id = 8, me = "x", instanceID = 36, name = "The Deadmines", startedAt = d + H + 20,
    endedAt = d + H + 600, bossesKilled = {} }
local ctx = { now = e3 + 2 * H, level = 12, maxLevel = 60, visits = { killed, peeked }, diary = {} }
local recap = R.Build(j, ctx)
local by = {}
for _, e in ipairs(recap.entries) do by[e.level] = e end

local p10 = R.Pieces(j, by[10], ctx)
Eq(#p10, 1, "level 10: one sitting, one piece")
Eq(by[10].spliced, true, "level 10 is spliced: no list of pieces")

local p11 = R.Pieces(j, by[11], ctx)
Eq(#p11, 2, "level 11: two sittings, two pieces")
Eq(by[11].spliced, false, "level 11 lists its pieces")
Eq(p11[1].at, t0, "a piece's time is its sitting's start, not the ding")
Eq(p11[1].from, t0 + H, "the first piece begins at the ding")
Check(p11[1].reached ~= nil and p11[2].reached == nil, "the ding goes on the first piece only")
Eq(#p11[2].runs, 1, "the run with a kill is the second piece's")
Eq(p11[2].runs[1].id, 7, "a look inside without a kill earns no page")
Eq(R.Pieces(j, by[11], ctx), p11, "worked out once an entry")

local p12 = R.Pieces(j, by[12], ctx)
Eq(#p12, 1, "level 12: the five minutes before logging out are a sliver")
Eq(p12[1].at, e3, "the piece kept is the long sitting")
Eq(p12[1].current, true, "the piece being played is current")
Eq(by[12].spliced, true, "one piece left: spliced")

-- A sliver with something in it is kept: a death in those five minutes.
J.Segments(j)[5].act = { deaths = 1 }
recap = R.Build(j, ctx)
for _, e in ipairs(recap.entries) do
    if e.level == 12 then
        Eq(#R.Pieces(j, e, ctx), 2, "a short piece with a death in it is kept")
        Eq(e.spliced, false, "and the level lists both")
    end
end

-- Time no sitting touches joins the next piece: never a page of its own.
local g = Fresh(20, t0)
local gseg = Seg("stop", t0 + 3 * 86400, t0 + 3 * 86400 + H)
gseg.levelFrom, gseg.levelTo = 20, 20
g.segments[1] = gseg
g.sittings = S.Lines({ { from = t0 + 3 * 86400, to = t0 + 3 * 86400 + H } })
local gctx = { now = t0 + 3 * 86400 + H, level = 20, maxLevel = 60, visits = {}, diary = {} }
local ge = R.Build(g, gctx).entries[1]
ge.deaths[#ge.deaths + 1] = { from = t0 + 10 }
local gp = R.Pieces(g, ge, gctx)
Eq(#gp, 1, "the days before the first sitting are no piece of their own")
Eq(gp[1].from, t0, "they join the first sitting's piece")
Eq(gp[1].at, t0 + 3 * 86400, "which keeps its sitting's label")

--------------------------------------------------------------------------
Section("a run worth a page")

Eq(R.RunWorthy(killed), true, "a boss killed")
Eq(R.RunWorthy(peeked), false, "no kill")
Eq(R.RunWorthy({ bossesKilled = {}, inferred = { ["Rhahk'Zor"] = "loot" } }), true, "a kill told by the loot")
Eq(R.RunWorthy(nil), false, "nothing")

--------------------------------------------------------------------------
Section("the label: the day, and its part when it had more than one")

local function At(y, mo, dd, hh)
    return os.time({ year = y, month = mo, day = dd, hour = hh, min = 0 })
end
local now = At(2026, 10, 28, 12)
local Label = Text.SittingLabel
local function Plain(p, t) return (Label(p, t):gsub("\194\160", " ")) end
Text = { SittingLabel = Plain }
Eq(Text.SittingLabel({ at = At(2026, 10, 25, 19) }, now), "Oct 25th", "one that day: the day alone")
Eq(Text.SittingLabel({ at = At(2026, 10, 25, 19), many = true }, now), "Oct 25th, Evening", "with its part")
Eq(Text.SittingLabel({ at = At(2026, 10, 25, 12), many = true }, now), "Oct 25th, Noon", "noon")
Eq(Text.SittingLabel({ at = At(2026, 10, 26, 1), many = true }, now), "Oct 25th, Night",
    "past midnight is the night before")
Eq(Text.SittingLabel({ at = At(2026, 10, 1, 9) }, now), "Oct 1st", "1st")
Eq(Text.SittingLabel({ at = At(2026, 10, 2, 9) }, now), "Oct 2nd", "2nd")
Eq(Text.SittingLabel({ at = At(2026, 10, 3, 9) }, now), "Oct 3rd", "3rd")
Eq(Text.SittingLabel({ at = At(2026, 10, 11, 9) }, now), "Oct 11th", "11th")
Eq(Text.SittingLabel({ at = At(2026, 10, 22, 9) }, now), "Oct 22nd", "22nd")
Eq(Text.SittingLabel({ at = At(2025, 12, 30, 9) }, now), "Dec 30th 2025", "another year says it")
