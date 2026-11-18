-- The ticklist's model (.claude/features/choose-page.md, Phase 2 and "Stable
-- list": Recap.Choices and Chosen.Tick in Core/Chosen.lua): every moment of a
-- piece by zone, each row's look, plate and reason, a zone's tri-state; the
-- list the same whatever is ticked; a tick leaving out and keeping, a row or
-- a zone, the bump and its "made room for", the block only where a keep
-- cannot fit; a custom card the player's; what the margin had no room for;
-- one row for a door's trips; a door whose run has its page; the keys of
-- kinds that read one record.

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

-- Five zones, one stop in each: each new to the road (an arrival, rank 4);
-- the three longest are stays too and hold the death, the fight and the
-- session, so they win the page. The first and the last, arrivals alone,
-- are cut: the first next in line (as busy, earlier), the last no room.
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
        Stop(t0 + 14000, 500, 1416),
    }
    j.open = nil
    j.marks = { { kind = "fight", outcome = "won", guid = FOE, t = t0 + 6000, mapID = 1413, x = 0.52, y = 0.5 } }
    j.chosen, j.closeCalls, j.levels[12] = nil, nil, nil
    Chosen.Forget()
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
-- A piece as the page would have it, fresh (a tick moves the recap on).
local function Piece()
    local ctx = Ctx()
    local e = Recap.Gather(j, t0, now + 1, ctx)
    return e, ctx
end
local function Choices()
    local e, ctx = Piece()
    return Recap.Choices(j, e, ctx, Cover), e, ctx
end
local function Tick(row)
    local e, ctx = Piece()
    return Chosen.Tick(j, e, ctx, Cover, row)
end
local function Zone(c, mapID)
    for _, zone in ipairs(c.zones) do
        if zone.mapID == mapID then return zone end
    end
    return nil
end
local function Row(zone, kind)
    for _, row in ipairs(zone and zone.rows or {}) do
        if row.kind == kind then return row end
    end
    return nil
end
local function Looks(c)
    local list = {}
    for _, zone in ipairs(c.zones) do
        list[#list + 1] = ("%d=%s/%s%s"):format(zone.mapID, zone.state, zone.look,
            zone.reason and ("/" .. zone.reason) or "")
    end
    return table.concat(list, " ")
end
-- The list as a reader sees it: every zone and row, in order, by key.
local function Shape(c)
    local list = {}
    for _, zone in ipairs(c.zones) do
        list[#list + 1] = zone.key
        for _, row in ipairs(zone.rows) do list[#list + 1] = "  " .. table.concat(row.keys, "+") end
    end
    return table.concat(list, "\n")
end
local function Copy(t)
    local copy = {}
    for k, v in pairs(t or {}) do copy[k] = v end
    return copy
end
local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end
local function Plates(c)
    local list = {}
    for i, p in ipairs(c.plates) do list[i] = p.mine and "mine" or "diary" end
    return table.concat(list, " ")
end

--------------------------------------------------------------------------
Section("the diary's choice: zones, rows, plates, reasons")

local SHAPE
do
    local c = Choices()
    Eq(Looks(c), "1411=none/diaryOff/next 1412=all/diary 1413=all/diary 1415=all/diary 1416=none/diaryOff/noRoom",
        "every zone, in time order")
    Eq(c.max, 3, "three maps fit")
    Eq(c.mine .. " " .. c.diary, "0 3", "the cap line: three of the diary's")
    Eq(Plates(c), "diary diary diary", "the plates, in order")
    Check(not c.full, "a keep is not blocked")
    local fight = Row(Zone(c, 1413), "fight")
    Check(fight and fight.look == "diary" and fight.on and fight.reason == nil, "a row on the page, the diary's")
    Eq(fight.plate, 2, "on the second map (time order)")
    Eq(fight.key, ("fight:%d:%s"):format(t0 + 6000, FOE), "by its moment's key")
    Eq(Row(Zone(c, 1412), "death").plate, 1, "the death on the first")
    Eq(Row(Zone(c, 1415), "session").plate, 3, "the session on the third")
    Eq(Zone(c, 1413).plates, nil, "a zone lists its maps' numbers (dropped, 18 Nov)")
    local arrive = Row(Zone(c, 1411), "arrive")
    Check(arrive and arrive.look == "diaryOff" and not arrive.on and arrive.reason == "next" and not arrive.plate,
        "a row off the page: no plate, its reason")
    Eq(Zone(c, 1412).lead.kind, "death", "a zone's lead: its best moment")
    Eq(Zone(c, 1412).key, "zone:1412", "a zone's key: its map")
    for _, zone in ipairs(c.zones) do
        for k = 2, #zone.rows do
            Check(zone.rows[k - 1].t <= zone.rows[k].t, "rows in time order in " .. zone.mapID)
        end
    end
    Eq(j.chosen, nil, "reading writes nothing")
    SHAPE = Shape(c)
end

--------------------------------------------------------------------------
Section("a moment that opens no plate: a zone of its own")

do
    -- This level's pin, where nothing else happened: no plate of its own.
    j.levels[12] = { at = t0 + 100, mapID = 1414, x = 0.5, y = 0.5 }
    local e, ctx = Piece()
    e.reached = { at = t0 + 100, mapID = 1414, x = 0.5, y = 0.5 }
    local c = Recap.Choices(j, e, ctx, Cover)
    local pin = Zone(c, 1414)
    Check(pin and pin.look == "diaryOff" and pin.reason == "minor" and #pin.rows == 1, "the pin's zone, minor")
    Eq(pin.rows[1].kind, "level", "holding the pin")
    -- Kept: it opens a plate (it has room to take: the weakest goes).
    local r = Chosen.Tick(j, e, ctx, Cover, pin)
    Eq(r.did, "keep", "kept")
    local after = Recap.Plates(j, e, ctx, Cover)
    local shown = false
    for _, p in ipairs(after) do shown = shown or p.mapID == 1414 end
    Check(shown, "the pin's zone is on the page")
    Route()
end

--------------------------------------------------------------------------
Section("leaving a zone out, and keeping it again: the bump")

do
    local c = Choices()
    local r = Tick(Zone(c, 1412))
    Eq(r.did, "out", "a zone on the page is left out")
    c = Choices()
    Eq(Shape(c), SHAPE, "the list as it was: every row where it stood")
    local gone = Zone(c, 1412)
    Eq(gone.look .. "/" .. gone.reason .. "/" .. gone.state, "out/byYou/none", "a red cross, left out by you")
    for _, row in ipairs(gone.rows) do
        Eq(row.look .. "/" .. row.reason, "out/byYou", row.kind .. " left out with it")
        Check(not row.on and not row.plate, row.kind .. " is off the page")
    end
    Eq(Looks(c), "1411=all/diary 1412=none/out/byYou 1413=all/diary 1415=all/diary 1416=none/diaryOff/next",
        "the next one came in")
    Eq(Row(Zone(c, 1413), "fight").plate, 2, "the maps renumbered: 1411 is the first now")
    -- Kept again: it is the player's, and the diary's weakest makes room.
    r = Tick(gone)
    Eq(r.did, "keep", "kept")
    Eq(r.bumped and r.bumped.mapID, 1411, "the weakest went")
    c = Choices()
    Eq(Shape(c), SHAPE, "the list as it was after a keep")
    local back = Zone(c, 1412)
    Eq(back.look .. "/" .. back.state, "keep/all", "a red tick")
    for _, row in ipairs(back.rows) do
        Check(row.look ~= "out", row.kind .. " came back with its zone")
    end
    Eq(j.chosen[("death:%d:"):format(t0 + 2000)], "keep", "keep on its lead")
    local bumped = Zone(c, 1411)
    Eq(bumped.look .. "/" .. bumped.reason, "diaryOff/madeRoom", "made room")
    Eq(bumped.madeRoomFor, 1412, "for the zone kept")
    Eq(Row(bumped, "arrive").reason, "madeRoom", "its rows say so too")
    Eq(Zone(c, 1416).reason, "next", "the next in line after it")
    Eq(c.mine .. " " .. c.diary, "1 2", "the cap line: one of the player's")
    Eq(Plates(c), "mine diary diary", "the first map the player's")
    -- Not saved: forgotten, it is only the next in line again.
    Chosen.Forget()
    Eq(Zone(Choices(), 1411).reason, "next", "a reload forgets what made room")
    Route()
end

--------------------------------------------------------------------------
Section("a row left out and kept: the zone's dash")

do
    local c = Choices()
    local stay = Row(Zone(c, 1413), "stay")
    Check(stay and stay.on, "setup: the stay on the page")
    Eq(Tick(stay).did, "out", "a row left out")
    c = Choices()
    Eq(Shape(c), SHAPE, "the list as it was")
    local zone = Zone(c, 1413)
    Eq(zone.state .. "/" .. zone.look, "some/keep", "some of it on the page, and the player's doing: a red dash")
    Eq(Row(zone, "stay").look, "out", "the row a red cross")
    Eq(Row(zone, "fight").look, "diary", "the rest the diary's")
    Eq(Tick(Row(zone, "stay")).did, "keep", "kept again")
    Eq(Row(Zone(Choices(), 1413), "stay").look, "keep", "a red tick")
    -- A zone's dash ticked: all of it left out, as a tick does.
    Eq(Tick(Zone(Choices(), 1413)).did, "out", "a zone showing some of it, left out")
    Eq(Zone(Choices(), 1413).look, "out", "all of it")
    Route()
end

--------------------------------------------------------------------------
Section("a card the player wrote is theirs; the block only where a keep cannot fit")

do
    -- A close call they changed on the fight's zone, a keep on the
    -- session's: two of the three maps are the player's.
    local call = { t = t0 + 5500, npcID = 3100, name = "Grimtusk", mapID = 1413, x = 0.5, y = 0.5,
        custom = { name = "Old Grimtusk" } }
    j.closeCalls = { call }
    J.Touch()
    local c = Choices()
    local shape = Shape(c)
    local close = Row(Zone(c, 1413), "close")
    Check(close and close.look == "keep" and close.on, "an edited card is the player's: a red tick")
    Eq(Zone(c, 1413).look, "keep", "and its zone red")
    Eq(Row(Zone(c, 1413), "fight").look, "diary", "the rest of it the diary's")
    Eq(Tick(Zone(c, 1415)).did, "out", "setup: the session's zone out")
    Eq(Tick(Zone(Choices(), 1415)).did, "keep", "and kept")
    c = Choices()
    Eq(c.mine .. " " .. c.diary, "2 1", "two of the player's")
    Check(not c.full, "room to keep one more")
    -- Keeping a third: the diary's last goes.
    local r = Tick(Zone(c, 1411))
    Eq(r.did .. " " .. tostring(r.bumped and r.bumped.mapID), "keep 1412", "the death's zone made room")
    c = Choices()
    Eq(c.mine .. " " .. c.diary, "3 0", "three of the player's")
    Check(c.full, "full")
    Eq(Zone(c, 1412).reason, "madeRoom", "made room")
    Eq(Zone(c, 1412).madeRoomFor, 1411, "for the zone kept")
    -- A fourth zone is blocked, and nothing is written.
    local before = Copy(j.chosen)
    r = Tick(Zone(c, 1416))
    Check(r.blocked, "blocked")
    Check(Same(before, j.chosen), "nothing written")
    Check(Tick(Row(Zone(c, 1416), "arrive")).blocked, "a row's keep blocked too")
    Eq(Shape(Choices()), shape, "the list as it was after a block")
    -- A row that fits a map of the player's is not blocked, full or not.
    Eq(Tick(Row(Zone(Choices(), 1413), "fight")).did, "out", "setup: the fight left out")
    c = Choices()
    Check(c.full, "setup: still full")
    r = Tick(Row(Zone(c, 1413), "fight"))
    Eq(r.did, "keep", "kept onto a full page: it fits on its map")
    Check(Row(Zone(Choices(), 1413), "fight").on, "on the page")
    -- Leaving one of them out is never blocked, and frees the room.
    Eq(Tick(Zone(Choices(), 1415)).did, "out", "left out")
    Check(not Choices().full, "room again")
    Route()
end

--------------------------------------------------------------------------
Section("cards: left out, kept, hidden through Custom")

do
    local call = { t = t0 + 5500, npcID = 3100, name = "Grimtusk", mapID = 1413, x = 0.5, y = 0.5 }
    j.closeCalls = { call }
    J.Touch()
    local c = Choices()
    local shape = Shape(c)
    local close = Row(Zone(c, 1413), "close")
    Eq(close.look, "diary", "a detected card, the diary's")
    Eq(Tick(close).did, "out", "left out")
    Check(call.custom and call.custom.hidden, "hidden as the menu hides it")
    c = Choices()
    Eq(Shape(c), shape, "the list as it was: a hidden card where it stood")
    close = Row(Zone(c, 1413), "close")
    Eq(close.look .. "/" .. close.reason, "out/byYou", "a red cross")
    Eq(Zone(c, 1413).state, "some", "its zone partly on the page")
    Eq(Tick(close).did, "keep", "kept")
    Eq(call.custom, nil, "shown again")
    Eq(Row(Zone(Choices(), 1413), "close").look, "keep", "a red tick")
    -- A card of a core kind, its own key.
    local fight = Row(Zone(Choices(), 1413), "fight")
    Eq(Tick(fight).did, "out", "a fight left out")
    Eq(j.chosen[fight.key], "out", "by its key")
    Eq(Row(Zone(Choices(), 1413), "fight").look, "out", "a red cross on it")
    Route()
end

--------------------------------------------------------------------------
Section("no room in the margin")

do
    local e, ctx = Piece()
    local plates = Recap.Plates(j, e, ctx, Cover)
    e.plates, e.cover = plates, Cover
    local place
    for _, p in ipairs(plates) do if p.mapID == 1415 then place = p end end
    local session
    for _, m in ipairs(place.moments) do if m.kind == "session" then session = m end end
    -- As UI/Journey/Margin.lua's WriteMargin leaves it: the items it had no
    -- room for, each with the moments it stands for.
    place.leftOff = { { kind = "person", moments = { session } } }
    local c = Recap.Choices(j, e, ctx)
    local row = Row(Zone(c, 1415), "session")
    Eq(row.look .. "/" .. row.reason, "diaryOff/marginRoom", "an empty box: no room in the margin")
    Check(not row.on and not row.plate, "off the page")
    Eq(Row(Zone(c, 1415), "stay").look, "diary", "the rest of the zone as it is")
    Eq(Zone(c, 1415).state, "some", "the zone partly on the page")

    -- Kept, and still no room (the user's, in the client, 18 Nov: "they
    -- are ticked, you would expect to untick them"): a red tick, off the
    -- page for room, and a click leaves it out, as on any red tick.
    Chosen.Keep(j, session)
    c = Recap.Choices(j, e, ctx)
    row = Row(Zone(c, 1415), "session")
    Eq(row.look .. "/" .. row.reason, "keep/marginRoom", "a red tick, no room in the margin")
    Check(not row.on, "still off the page")
    local did = Chosen.Tick(j, e, ctx, Cover, row)
    Eq(did and did.did, "out", "a kept card with no room unticked")
    Eq(j.chosen[row.key], "out", "left out by its key")
    j.chosen[row.key] = nil
    if next(j.chosen) == nil then j.chosen = nil end
end

--------------------------------------------------------------------------
Section("a door's trips: one row; a door whose run has its page")

do
    local e, ctx = Piece()
    local function Door(from, visit)
        return { seg = { kind = "stop", from = from, to = from + 300, mapID = 1415, x = 0.51, y = 0.5 },
            name = "Gnollwood Den", visit = visit }
    end
    e.dungeons = { Door(t0 + 9100), Door(t0 + 9900), Door(t0 + 10700) }
    local c = Recap.Choices(j, e, ctx, Cover)
    local doors = 0
    for _, row in ipairs(Zone(c, 1415).rows) do
        if row.kind == "dungeon" then doors = doors + 1 end
    end
    Eq(doors, 1, "three trips through one door: one row")
    local door = Row(Zone(c, 1415), "dungeon")
    Eq(#door.moments .. " " .. #door.keys, "3 3", "standing for every trip")
    Eq(door.t, t0 + 9100, "at the first")
    Check(door.on, "on the page")
    Eq(Chosen.Tick(j, e, ctx, Cover, door).did, "out", "left out")
    for _, key in ipairs(door.keys) do Eq(j.chosen[key], "out", "every trip left out: " .. key) end
    Route()

    -- A door alone in its zone whose run was recorded: the run has its page,
    -- so the plate is dropped; listed all the same, and kept it comes in.
    e, ctx = Piece()
    e.dungeons = { { seg = { kind = "stop", from = t0 + 14100, to = t0 + 14300, mapID = 1417, x = 0.5, y = 0.5 },
        name = "Gnollwood Den", visit = { id = 1 } } }
    c = Recap.Choices(j, e, ctx, Cover)
    local alone = Zone(c, 1417)
    Check(alone ~= nil, "a door whose run has its page is listed")
    Eq(alone.reason, "run", "its run has a page of its own")
    -- (a keep: the diary's weakest goes, the door comes in)
    Eq(Chosen.Tick(j, e, ctx, Cover, alone).did, "keep", "kept")
    local shown = false
    for _, p in ipairs(Recap.Plates(j, e, ctx, Cover)) do shown = shown or p.mapID == 1417 end
    Check(shown, "a door kept is on the page")
    Route()
end

--------------------------------------------------------------------------
Section("a death left out: its cross and its killer's card")

do
    local d = J.Append(j, "deaths", { t = t0 + 2100, name = "Grimtusk Smith", npcID = 3100 },
        { mapID = 1412, x = 0.5, y = 0.5 })
    J.Touch()
    local seg = j.segments[2]
    Check(not Chosen.DeathOut(j, d.t), "on the page")
    Eq(Chosen.DeathsShown(j, { seg }, 1), 1, "its cross counts it")
    Tick(Row(Zone(Choices(), 1412), "death"))
    Check(Chosen.DeathOut(j, d.t), "left out with its moment")
    Eq(Chosen.DeathsShown(j, { seg, j.segments[3] }, 1), 0, "no cross for it")
    Route()
    j.deaths = nil
end

--------------------------------------------------------------------------
Section("kinds that read one record share a key")

do
    local rec = { t = 500, itemID = 2000, mapID = 1412, x = 0.5, y = 0.5 }
    Eq(Recap.Key({ kind = "piece", t = 500, upgrade = rec }), Recap.Key({ kind = "upgrade", t = 500, upgrade = rec }),
        "an upgrade that turns into a piece")
    local hunt = { t = 600, npcID = 3100 }
    Eq(Recap.Key({ kind = "fortune", t = 600, hunt = hunt }), Recap.Key({ kind = "luck", t = 600, hunt = hunt }),
        "a hunt that turns from bad luck to good")
    Eq(Recap.Key({ kind = "luck", t = 600, hunt = hunt }), "luck:600:3100", "written as luck")
end
