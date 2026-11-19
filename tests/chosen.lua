-- Choosing what's on a page of Your Diary (.claude/features/choose-page.md,
-- Core/Chosen.lua), the core: a moment's key, which holds while the piece
-- grows and a death's name is put right; a place left out, and the next one
-- in; a cut place kept, and the weakest bumped; a route from before `chosen`;
-- forgetting someone.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Chosen, Recap, J = ns.Chosen, ns.JourneyRecap, ns.Journey

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local FRIEND, FOE = "Player-1111-0000AAAA", "Player-1111-0000BBBB"

-- Four zones, one stop in each: each is new to the road (an arrival, rank 4)
-- and the three longest are stays too, so the busier three win the page and
-- the first, alone with its arrival, is cut.
local t0 = now - 20000
J.Begin(ns.ownGUID, t0, 12, 1411)
local j = J.Mine()
local function Stop(from, seconds, mapID, act)
    return { kind = "stop", from = from, to = from + seconds, mapID = mapID, x = 0.5, y = 0.5, r = 30,
        seconds = seconds, levelFrom = 12, levelTo = 12, act = act }
end
local function Route()
    j.segments = {
        Stop(t0, 1000, 1411),
        Stop(t0 + 2000, 2000, 1412, { deaths = 1 }),
        Stop(t0 + 5000, 3000, 1413),
        Stop(t0 + 9000, 4000, 1415),
    }
    j.open = nil
    j.marks = { { kind = "fight", outcome = "won", guid = FOE, t = t0 + 6000, mapID = 1413, x = 0.52, y = 0.5 } }
    J.Touch()
end
Route()

local function Ctx()
    local ctx = Recap.Context(ns.ownGUID, now)
    ctx.sessions = { { startedAt = t0 + 9500, participants = {
        [FRIEND] = { seconds = 1500, last = t0 + 11000 } } } }
    return ctx
end
local function Cover() return 0.2, 0.2 end
local function Plates(to)
    local ctx = Ctx()
    local e = Recap.Gather(j, t0, to or now + 1, ctx)
    return Recap.Plates(j, e, ctx, Cover), e
end
local function MapsOf(plates)
    local maps = {}
    for _, p in ipairs(plates) do maps[#maps + 1] = p.mapID end
    table.sort(maps)
    return table.concat(maps, " ")
end
local function Keys(e)
    local keys = {}
    for _, m in ipairs(Recap.Moments(j, e, Ctx())) do keys[Recap.Key(m)] = m.kind end
    return keys
end
local function PlateOn(plates, mapID)
    for _, p in ipairs(plates) do if p.mapID == mapID then return p end end
    for _, p in ipairs(plates.spare or {}) do if p.mapID == mapID then return p end end
    return nil
end

--------------------------------------------------------------------------
Section("an old-shaped route reads as it did")

do
    Eq(j.chosen, nil, "no choices on a route from before them")
    local plates, e = Plates()
    Eq(#plates, 3, "three places fit")
    Eq(MapsOf(plates), "1412 1413 1415", "the busier three")
    Eq(#plates.spare, 1, "one cut, kept aside")
    Eq(plates.spare[1].mapID, 1411, "the quiet first zone")
    local spare = plates.spare[1]
    Check(spare.cx and spare.cy and spare.light ~= nil, "a spare place is finished as a shown one is")
    Eq(#e.hidden, 0, "nothing left out")
    Eq(e.leftOut, nil, "and nothing to list")
    Eq(j.chosen, nil, "reading writes nothing")
end

--------------------------------------------------------------------------
Section("a moment's key")

do
    local keys = Keys(select(2, Plates()))
    Eq(keys[("arrive:%d:"):format(t0)], "arrive", "an arrival, by its segment's start")
    Eq(keys[("stay:%d:"):format(t0 + 9000)], "stay", "a stay")
    Eq(keys[("death:%d:"):format(t0 + 2000)], "death", "a death, by its segment, no name")
    Eq(keys[("fight:%d:%s"):format(t0 + 6000, FOE)], "fight", "a fight, by its opponent")
    Eq(keys[("session:%d:%s"):format(t0 + 9500, FRIEND)], "session", "a session, by when it began here")
    Eq(Recap.Key({ kind = "level", t = 50, out = true }), "level:50:out", "the next level's pin")
    Eq(Recap.Key({ kind = "level", t = 50 }), "level:50:in", "this level's")
    Eq(Recap.Key({ kind = "close", t = 70, call = { t = 70, npcID = 3100, name = "Grimtusk" } }), "close:70:3100",
        "a feature's, by its creature")
    Eq(Recap.Key({ kind = "close", t = 70, call = { t = 70, npcID = 99, customOf = { t = 70, npcID = 3100 } } }),
        "close:70:3100", "a card the player changed keeps its detected creature")
    Eq(Recap.Key({ kind = "close", rec = { t = 70, npcID = 3100 } }), "close:70:3100",
        "a hidden card's entry, as its moment would be")
end

--------------------------------------------------------------------------
Section("keys hold while the piece grows and a death is named")

do
    local before = Keys(select(2, Plates(now - 8000)))
    -- The last stop goes on, the session with it, the killer is read.
    j.segments[4].to, j.segments[4].seconds = t0 + 15000, 6000
    local d = ns.Journey.Append(j, "deaths", { t = t0 + 2100, name = "Grimtusk Smith", npcID = 3100 },
        { mapID = 1412, x = 0.5, y = 0.5 })
    J.Touch()
    local mid = Keys(select(2, Plates()))
    ns.Deaths.Killer(d, { npcID = 3100, name = "Grimtusk" })
    local after = Keys(select(2, Plates()))
    for key, kind in pairs(before) do
        Eq(mid[key], kind, key .. " held as the stop grew")
        Eq(after[key], kind, key .. " held as the death was named")
    end
    Route()
    j.deaths = nil
end

--------------------------------------------------------------------------
Section("a place left out, and the next one in")

do
    local plates = Plates()
    local p = PlateOn(plates, 1412)
    Check(Chosen.LeavePlace(j, p), "left out")
    for _, m in ipairs(p.moments) do Eq(Chosen.Of(j, m), "out", m.kind .. " is out") end
    local after, e = Plates()
    Eq(MapsOf(after), "1411 1413 1415", "the cut place comes in")
    Eq(#after.spare, 0, "nothing cut")
    Eq(#e.hidden, #p.moments, "each moment listed")
    for _, h in ipairs(e.hidden) do
        Check(h.key and h.moment and not h.rec, "with its key, and no record for the map's menu")
    end
    -- Asked again, the same list.
    Recap.Moments(j, e, Ctx())
    Eq(#e.hidden, #p.moments, "listed once however often it is asked")
    Check(Chosen.Keep(j, p.moments[1]), "one kept again")
    Eq(Chosen.Of(j, p.moments[1]), "keep", "it is the player's")
    j.chosen = nil
end

--------------------------------------------------------------------------
Section("a cut place kept, and the weakest bumped")

do
    local plates = Plates()
    local cut = plates.spare[1]
    Eq(Chosen.Lead(cut).kind, "arrive", "its lead is its arrival")
    Check(Chosen.KeepPlace(j, cut), "kept")
    local after = Plates()
    -- (the fight's place and the session's rank 1; the death's, 3, is the weakest)
    Eq(MapsOf(after), "1411 1413 1415", "it comes in; the weakest goes")
    Eq(after.spare[1].mapID, 1412, "the bumped one waits as the spare")
    Eq(PlateOn(after, 1411).rank, Recap.Rank({ kind = "arrive", chosen = "keep" }), "at a custom card's rank")
    -- A kept level's pin opens a plate of its own.
    j.chosen = nil
    j.levels[12] = { at = t0 + 100, mapID = 1414, x = 0.5, y = 0.5 }
    local ctx = Ctx()
    local e = Recap.Gather(j, t0, now + 1, ctx)
    e.reached = { at = t0 + 100, mapID = 1414, x = 0.5, y = 0.5 }
    Chosen.Keep(j, { kind = "level", t = t0 + 100 })
    Check(PlateOn(Recap.Plates(j, e, ctx, Cover), 1414) ~= nil, "the pin's place is on the page")
    j.levels[12], j.chosen = nil, nil
end

--------------------------------------------------------------------------
Section("a card that may be custom keeps its own switch")

do
    local call = { t = t0 + 5500, npcID = 3100, name = "Grimtusk", mapID = 1413, x = 0.5, y = 0.5 }
    j.closeCalls = { call }
    J.Touch()
    local m = { kind = "close", t = call.t, call = call }
    Check(Chosen.Leave(j, m), "left out")
    Check(call.custom and call.custom.hidden, "hidden as the menu hides it")
    Eq(j.chosen, nil, "nothing in chosen")
    Eq(Chosen.Of(j, m), "out", "out all the same")
    local _, e = Plates()
    local listed
    for _, h in ipairs(e.hidden) do if h.rec == call then listed = h end end
    Check(listed ~= nil, "the map's menu still lists it")
    Check(Chosen.Keep(j, listed), "kept from its entry")
    Eq(call.custom, nil, "shown again")
    Eq(j.chosen[Recap.Key(m)], "keep", "and ranked as the player's")
    j.closeCalls, j.chosen = nil, nil
end

--------------------------------------------------------------------------
Section("forgetting someone")

do
    local plates = Plates()
    for _, p in ipairs(plates) do Chosen.LeavePlace(j, p) end
    Chosen.Keep(j, { kind = "fight", t = t0 + 6000, guid = FOE })
    local hadFriend, hadFoe = false, false
    for key in pairs(j.chosen) do
        hadFriend = hadFriend or key:find(FRIEND, 1, true) ~= nil
        hadFoe = hadFoe or key:find(FOE, 1, true) ~= nil
    end
    Check(hadFriend and hadFoe, "both are chosen")
    ns.ForgetEverywhere(FRIEND)
    for key in pairs(j.chosen) do Check(not key:find(FRIEND, 1, true), key .. " forgotten") end
    Eq(j.chosen[("fight:%d:%s"):format(t0 + 6000, FOE)], "keep", "the other stays")
    Eq(j.chosen[("arrive:%d:"):format(t0 + 9000)], "out", "and the places")
    ns.ForgetEverywhere(nil)
    for key in pairs(j.chosen or {}) do Check(not key:find("Player-", 1, true), key .. " forgotten with everyone") end
    Check(j.chosen and j.chosen[("arrive:%d:"):format(t0 + 9000)] == "out", "the places stay")
end

do
    Section("/sd chosen: list, then clear (Dev/JourneyDebug.lua)")
    Chosen.Leave(j, { kind = "arrive", t = t0 + 9000 })
    local said = {}
    local was = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(self, msg) said[#said + 1] = tostring(msg) end
    SlashCmdList.SOCIALDIARY("chosen")
    DEFAULT_CHAT_FRAME.AddMessage = was
    local listed = false
    for _, line in ipairs(said) do listed = listed or line:find(("arrive:%d:"):format(t0 + 9000), 1, true) ~= nil end
    Check(listed, "list prints the choice's key")
    SlashCmdList.SOCIALDIARY("chosen clear")
    Eq(j.chosen, nil, "clear takes every choice off")
end
