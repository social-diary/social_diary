-- The ticklist's model (.claude/features/choose-page.md, Phase 2:
-- Recap.Choices and Chosen.Tick in Core/Chosen.lua): every place of a piece
-- with its moments, each row's look and reason; a tick leaving out and
-- keeping, the bump and its "made room for", the block; a custom card's
-- place the player's; a place left out still listed; what the margin had no
-- room for; the keys of kinds that read one record.

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
local function On(c, mapID)
    for _, place in ipairs(c.places) do
        if place.mapID == mapID then return place end
    end
    return nil
end
local function Card(place, kind)
    for _, card in ipairs(place and place.cards or {}) do
        if card.kind == kind then return card end
    end
    return nil
end
local function Looks(c)
    local list = {}
    for _, place in ipairs(c.places) do
        list[#list + 1] = ("%d=%s%s"):format(place.mapID, place.look, place.reason and ("/" .. place.reason) or "")
    end
    return table.concat(list, " ")
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

--------------------------------------------------------------------------
Section("the diary's choice: faded ticks, next in line, no room")

do
    local c = Choices()
    Eq(Looks(c), "1411=diaryOff/next 1412=diary 1413=diary 1415=diary 1416=diaryOff/noRoom",
        "every place, in time order")
    Eq(c.max, 3, "three places fit")
    Eq(c.mine .. " " .. c.diary, "0 3", "the cap line: three of the diary's")
    Check(not c.full, "a keep is not blocked")
    local fight = Card(On(c, 1413), "fight")
    Check(fight and fight.look == "diary" and fight.on and fight.reason == nil, "a card on the page, the diary's")
    Eq(fight.key, ("fight:%d:%s"):format(t0 + 6000, FOE), "by its moment's key")
    local arrive = Card(On(c, 1411), "arrive")
    Check(arrive and arrive.look == "diaryOff" and not arrive.on and arrive.reason == "next",
        "a card of a place off the page has its place's reason")
    Eq(On(c, 1412).lead.kind, "death", "a place's lead: its best moment")
    Eq(On(c, 1412).key, ("death:%d:"):format(t0 + 2000), "and its key the place's")
    Eq(j.chosen, nil, "reading writes nothing")
end

--------------------------------------------------------------------------
Section("a moment that opens no plate: a place of its own")

do
    -- This level's pin, where nothing else happened: no plate of its own.
    j.levels[12] = { at = t0 + 100, mapID = 1414, x = 0.5, y = 0.5 }
    local e, ctx = Piece()
    e.reached = { at = t0 + 100, mapID = 1414, x = 0.5, y = 0.5 }
    local c = Recap.Choices(j, e, ctx, Cover)
    local pin = On(c, 1414)
    Check(pin and pin.look == "diaryOff" and pin.reason == "minor" and #pin.cards == 1, "the pin's place, minor")
    Eq(pin.cards[1].kind, "level", "holding the pin")
    -- Kept: it opens a plate (it has room to take: the weakest goes).
    local r = Chosen.Tick(j, e, ctx, Cover, pin)
    Eq(r.did, "keep", "kept")
    local after = Recap.Plates(j, e, ctx, Cover)
    local shown = false
    for _, p in ipairs(after) do shown = shown or p.mapID == 1414 end
    Check(shown, "the pin's place is on the page")
    Route()
end

--------------------------------------------------------------------------
Section("leaving a place out, and keeping it again: the bump")

do
    local c = Choices()
    local r = Tick(On(c, 1412))
    Eq(r.did, "out", "a place on the page is left out")
    c = Choices()
    local gone = On(c, 1412)
    Check(gone ~= nil, "a place left out is still listed")
    Eq(gone.look .. "/" .. gone.reason, "out/byYou", "a red cross, left out by you")
    for _, card in ipairs(gone.cards) do
        Eq(card.look .. "/" .. card.reason, "out/byYou", card.kind .. " left out with it")
        Check(not card.on, card.kind .. " is off the page")
    end
    Eq(Looks(c), "1411=diary 1412=out/byYou 1413=diary 1415=diary 1416=diaryOff/next", "the next one came in")
    -- Kept again: it is the player's, and the diary's weakest makes room.
    r = Tick(gone)
    Eq(r.did, "keep", "kept")
    Eq(r.bumped and r.bumped.mapID, 1411, "the weakest went")
    c = Choices()
    local back = On(c, 1412)
    Eq(back.look, "keep", "a red tick")
    Check(back.on, "on the page")
    for _, card in ipairs(back.cards) do
        Check(card.look ~= "out", card.kind .. " came back with its place")
    end
    Eq(j.chosen[("death:%d:"):format(t0 + 2000)], "keep", "keep on its lead")
    local bumped = On(c, 1411)
    Eq(bumped.look .. "/" .. bumped.reason, "diaryOff/madeRoom", "made room")
    Check(bumped.madeRoomFor == back, "for the place kept")
    Eq(On(c, 1416).reason, "next", "the next in line after it")
    Eq(c.mine .. " " .. c.diary, "1 2", "the cap line: one of the player's")
    -- Not saved: forgotten, it is only the next in line again.
    Chosen.Forget()
    Eq(On(Choices(), 1411).reason, "next", "a reload forgets what made room")
    Route()
end

--------------------------------------------------------------------------
Section("a card the player wrote: its place is theirs; the block")

do
    -- A close call they changed on the fight's place, a keep on the
    -- session's: two of the three are the player's.
    local call = { t = t0 + 5500, npcID = 3100, name = "Grimtusk", mapID = 1413, x = 0.5, y = 0.5,
        custom = { name = "Old Grimtusk" } }
    j.closeCalls = { call }
    J.Touch()
    local c = Choices()
    local close = Card(On(c, 1413), "close")
    Check(close and close.look == "keep" and close.on, "an edited card is the player's: a red tick")
    Eq(On(c, 1413).look, "keep", "and so is its place")
    Eq(Card(On(c, 1413), "fight").look, "diary", "the rest of it the diary's")
    Chosen.KeepPlace(j, On(c, 1415).plate)
    c = Choices()
    Eq(c.mine .. " " .. c.diary, "2 1", "two of the player's")
    Check(not c.full, "room to keep one more")
    -- Keeping a third: the diary's last goes.
    local r = Tick(On(c, 1411))
    Eq(r.did .. " " .. tostring(r.bumped and r.bumped.mapID), "keep 1412", "the death's place made room")
    c = Choices()
    Eq(c.mine .. " " .. c.diary, "3 0", "three of the player's")
    Check(c.full, "full")
    Eq(On(c, 1412).reason, "madeRoom", "made room")
    Eq(On(c, 1412).madeRoomFor.mapID, 1411, "for the place kept")
    -- A fourth is blocked, and nothing is written.
    local before = Copy(j.chosen)
    r = Tick(On(c, 1416))
    Check(r.blocked, "blocked")
    Check(Same(before, j.chosen), "nothing written")
    -- A card on a place off the page is blocked as its place is.
    Check(Tick(Card(On(c, 1416), "arrive")).blocked, "a card's keep blocked too")
    -- Leaving one of them out is never blocked, and frees the room.
    r = Tick(On(c, 1415))
    Eq(r.did, "out", "left out")
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
    local close = Card(On(c, 1413), "close")
    Eq(close.look, "diary", "a detected card, the diary's")
    Eq(Tick(close).did, "out", "left out")
    Check(call.custom and call.custom.hidden, "hidden as the menu hides it")
    c = Choices()
    close = Card(On(c, 1413), "close")
    Check(close ~= nil, "listed on its place still")
    Eq(close.look .. "/" .. close.reason, "out/byYou", "a red cross")
    Eq(On(c, 1413).look, "diary", "its place the diary's still")
    Eq(Tick(close).did, "keep", "kept")
    Eq(call.custom, nil, "shown again")
    Eq(Card(On(Choices(), 1413), "close").look, "keep", "a red tick")
    -- A card of a core kind, its own key.
    local fight = Card(On(Choices(), 1413), "fight")
    Eq(Tick(fight).did, "out", "a fight left out")
    Eq(j.chosen[fight.key], "out", "by its key")
    Eq(Card(On(Choices(), 1413), "fight").look, "out", "a red cross on it")
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
    local card = Card(On(c, 1415), "session")
    Eq(card.look .. "/" .. card.reason, "diaryOff/marginRoom", "an empty box: no room in the margin")
    Check(not card.on, "off the page")
    Eq(Card(On(c, 1415), "stay").look, "diary", "the rest of the place as it is")
    Eq(On(c, 1415).look, "diary", "and the place on the page")
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
    Tick(Card(On(Choices(), 1412), "death"))
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
