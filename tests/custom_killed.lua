-- Custom cards: a death (.claude/features/custom-cards.md, Features/Deaths/). An
-- inserted one is a moment of its own with its own cross and a killer's card, and
-- never touches the route's count; a detected one's card is edited through the
-- killer's pass, which reads the list itself, and one hidden is listed by the
-- kind's gather. The caption counts both.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Recap, J, Deaths = ns.Custom, ns.JourneyRecap, ns.Journey, ns.Deaths
local Text = ns.UI.JourneyText

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
J.Begin(ns.ownGUID, t0, 10, 1412)
local j = J.Mine()
j.segments, j.open = {}, nil
local STOP = { kind = "stop", from = t0, to = t0 + 1200, mapID = 1412, x = 0.40, y = 0.60, r = 30, seconds = 1200,
    levelFrom = 10, levelTo = 10 }
j.segments[1] = STOP
j.segments[2] = { kind = "road", from = t0 + 1200, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 10,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } }
j.segments[3] = { kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30,
    seconds = 1800, levelFrom = 10, levelTo = 10 }
j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
J.Touch()

local WHERE = { mapID = 1412, x = 0.44, y = 0.56, from = t0, to = t0 + 4000 }

local function Gathered()
    return Recap.Gather(j, t0, t0 + 4000, Recap.Context(ns.ownGUID, now))
end

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

-- Level 10's page drawn afresh, with the cards in the margin.
local function Draw()
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, entry in ipairs(page.recap.entries) do
        if entry.level == 10 then T.OpenDiaryPage(page, i) end
    end
    local cards = {}
    for i = 1, page.killerPool.used do
        if page.killerPool[i]:IsShown() then cards[#cards + 1] = page.killerPool[i] end
    end
    return cards, page.plates[1]
end

local function Words(plate, said)
    return Text.PlateCaption(plate, nil, said or { named = {} })
end

-- A throwaway plate's moments, for the caption's counts alone.
local function Moments(...)
    local list = {}
    for _, kind in ipairs({ ... }) do
        list[#list + 1] = kind == "killedBy" and { kind = kind, killedBy = { name = "Old Tom" }, t = t0 } or { kind = kind, t = t0 }
    end
    return { moments = list, mapID = 1412, t = t0 }
end

--------------------------------------------------------------------------
Section("what the form offers")

do
    local spec = Custom.Spec("killedBy")
    Eq(spec.label, "Death", "the picker's title")
    Eq(spec.group, "combat", "its type")
    Eq(spec.creature, "name", "a known name brings its creature")
    local keys = {}
    for i, field in ipairs(spec.fields) do keys[i] = field.key end
    Eq(table.concat(keys, " "), "name rank spell", "what the card shows, and nothing else")
    Eq(spec.describe({ name = "Old Tom", spell = "Bite" }), "Old Tom, with Bite", "a menu's line")
    Eq(spec.describe({}), "A death", "one with no creature")
    local kit = ns.UI.JourneyPlate.MARKS.killedBy
    Check(kit.order == 32 and kit.keep == "killedMarks", "its mark takes its turn")
end

--------------------------------------------------------------------------
Section("an old-shaped route reads as it did")

do
    local plain = { t = t0 + 600, mapID = 1412, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail",
        spell = "Bite", display = 1234, probable = true }
    j.deaths = { plain }
    STOP.act = { deaths = 1 }
    local e = Gathered()
    Eq(#e.killedBy, 0, "no inserted cards")
    Eq(#e.hidden, 0, "nothing hidden")
    Eq(j.custom, nil, "reading writes no list")
    Eq(Deaths.Read(plain), plain, "read as it is, no copy")
    local cards, plate = Draw()
    Eq(#cards, 1, "the killer's card")
    Eq(page.killersWritten, 1, "as the plate's one")
    Eq(page.customKillersWritten, 0, "and no custom one")
    Eq(plate.killer.death, plain, "it knows its record")
    Eq(plate.killer.probable, true, "the diary's doubt stays")
    Eq(#plate.crosses[1].deaths, 1, "the death on its cross")
    Check(rawget(cards[1], "onRight") ~= nil, "a right click on the card opens the form")
end

--------------------------------------------------------------------------
Section("a death inserted")

local made
do
    j.deaths, STOP.act = nil, nil
    local before = 0
    for _, seg in ipairs(j.segments) do before = before + ((seg.act and seg.act.deaths) or 0) end
    made = Custom.Insert("killedBy", { name = "Old Tom", rank = "rare", spell = "Bite" }, WHERE)
    Eq(j.custom[1], made, "on the custom list")
    Eq(j.deaths, nil, "not on the deaths'")
    local after = 0
    for _, seg in ipairs(j.segments) do after = after + ((seg.act and seg.act.deaths) or 0) end
    Eq(after, before, "the route's count of deaths is as it was")
    Eq(J.CountedOn(j, made.t), nil, "no segment counted it")
    local e = Gathered()
    Eq(#e.deaths, 0, "the entry's route deaths: none")
    Eq(#e.killedBy, 1, "gathered as its own kind")
    Eq(e.killedBy[1].customOf, made, "knows its record")

    local shape, crossed = ns.UI.JourneyPlate.SHAPE.death, 0
    ns.UI.JourneyPlate.SHAPE.death = function(...)
        crossed = crossed + 1
        return shape(...)
    end
    local cards, plate = Draw()
    ns.UI.JourneyPlate.SHAPE.death = shape
    Check(crossed >= 1, "drawn in the route's cross's shape")
    Eq(plate.counts.insertedDeaths, 1, "its own cross")
    Eq(#plate.crosses, 0, "not one of the route's")
    Eq(#cards, 1, "a card")
    Eq(page.customKillersWritten, 1, "custom")
    Eq(page.killersWritten, 0, "not the plate's one")
    local card = cards[1]
    Eq(card.face, nil, "the killer's card: no other face")
    Eq(card.killer.name, "Old Tom", "its creature")
    Eq(card.killer.count, 1, "one death")
    Check(rawget(card, "onRight") ~= nil, "a right click opens the form")
    Eq(card.killer.mark[2], plate.killedMarks[1].at[2], "its leader goes to its cross")

    local title, lines = ns.Deaths.KillerTip(card.killer, now)
    Eq(title, "Old Tom", "the tooltip's title")
    Eq(lines[1], "Rare", "its type")
    Check(lines[2]:find("with Bite", 1, true) ~= nil, "what it killed you with")

    local tip, told = ns.UI.JourneyPlate.MARKS.killedBy.tip(plate.killedMarks[1].list[1])
    Eq(tip, "Died here", "its cross is told as the route's is")
    Eq(told[1], "Old Tom, with Bite", "and what did it")

    -- A name the records know brings its picture, and renames nothing.
    j.deaths = { { t = t0 - 100, mapID = 1412, x = 0.1, y = 0.1, npcID = 3255, name = "Sunscale Lashtail", display = 1234 } }
    local known = Custom.Insert("killedBy", { name = "sunscale lashtail" }, WHERE)
    Eq(known.npcID, 3255, "a known creature's id")
    Eq(known.display, 1234, "a known creature's picture")
    Custom.Remove(known)
    j.deaths = nil

    local bare = Custom.Insert("killedBy", {}, WHERE)
    cards, plate = Draw()
    Eq(plate.counts.insertedDeaths >= 1, true, "with no creature, still its cross")
    Eq(page.customKillersWritten, 1, "and no card")
    Custom.Remove(bare)

    ns.SetSetting("keepRoute", false)
    local off = Custom.Insert("killedBy", { name = "Old Tom" }, WHERE)
    Check(off ~= nil, "it needs no route being kept")
    Custom.Remove(off)
    ns.SetSetting("keepRoute", true)
end

--------------------------------------------------------------------------
Section("the words count it")

do
    Eq(Words(Moments("killedBy")), "A death.", "alone")
    Eq(Words(Moments("killedBy", "killedBy")), "Two deaths.", "two inserted")
    Eq(Words(Moments("death", "killedBy")), "Two deaths.", "beside the route's, one count")
    Eq(Words(Moments("death", "death", "killedBy")), "Three deaths.", "three")
    Eq(Words(Moments("death", "killedBy"), { named = {}, death = "a Plainstrider" }), "Two deaths, to a Plainstrider.",
        "a card left off names its creature")
    Eq(Words(Moments("death")), "A death.", "the route's alone as it was")

    local close = Moments("killedBy", "close")
    close.moments[2].call = { name = "Boar", pct = 5, t = t0 }
    Eq(Words(close, { named = {}, close = true }), "A death, and a close call.", "leading a close call")

    -- A fight lost to strangers says how that fight went, and only that.
    local fought = Moments("death", "killedBy", "fight")
    fought.moments[3].fight = { outcome = "lost" }
    fought.moments[3].outcome = "lost"
    fought.moments[3].guid = "Player-1-0CCCCCCC"
    local words = Words(fought)
    Eq(words:find("A fight, lost", 1, true), 1, "the fight leads")
    Check(words:find("a death", 1, true) ~= nil, "the inserted one is still told")
    Check(words:find("two deaths", 1, true) == nil, "and the route's is not added to it")
end

--------------------------------------------------------------------------
Section("left off, its creature is in the words")

do
    local spec = ns.UI.JourneyMargin.KINDS.killerCustom
    local one, two = { name = "Old Tom", rank = "rare" }, { name = "Plainstrider" }
    local plate = { customKillers = { one, two } }
    local said = {}
    spec.say(said, { { killer = one } }, plate)
    Eq(said.death, "a Plainstrider", "the one with no room")
    said = {}
    spec.say(said, { { killer = one }, { killer = two } }, plate)
    Eq(said.death, nil, "with room for both, nothing")
    Eq(ns.UI.JourneyMargin.KINDS.killerCustom.order, 4, "before the people")
end

Custom.Remove(made)

--------------------------------------------------------------------------
Section("a detected death's card edited")

local rec
do
    rec = { t = t0 + 600, mapID = 1412, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail", spell = "Bite",
        display = 1234, probable = true }
    local other = { t = t0 + 700, mapID = 1412, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail",
        display = 1234 }
    j.deaths = { rec, other }
    STOP.act = { deaths = 2 }
    local cards, plate = Draw()
    Eq(page.killersWritten, 1, "one card for two deaths")
    Eq(plate.killer.count, 2, "killed you twice")

    Check(Custom.Edit("killedBy", rec, { name = "Old Tom", rank = "elite", spell = "Rend" }), "the edit")
    Eq(rec.name, "Sunscale Lashtail", "the detected name stays")
    Eq(ns.CreatureNames.Find(j, "Old Tom"), nil, "the typed name is on no creature")
    Eq(ns.CreatureNames.Find(j, "Sunscale Lashtail"), 3255, "and the creature keeps its own")
    cards, plate = Draw()
    Eq(page.customKillersWritten, 1, "its own card")
    Eq(page.killersWritten, 1, "beside the plate's one")
    Eq(plate.killer.count, 1, "which no longer counts it")
    Eq(plate.customKillers[1].name, "Old Tom", "its creature")
    Eq(plate.customKillers[1].spell, "Rend", "its spell")
    Eq(plate.customKillers[1].display, nil, "a name no record knows has no picture")
    Eq(plate.customKillers[1].probable, nil, "and no doubt: the player has said")
    Eq(plate.customKillers[1].death.customOf, rec, "its record, for the form")
    Eq(plate.counts.insertedDeaths or 0, 0, "no inserted cross")
    Eq(STOP.act.deaths, 2, "the route's count stays")
    Eq(#Gathered().killedBy, 0, "not in the inserted kind's words too")

    local plateCross = plate.crosses[1]
    Eq(#plateCross.deaths, 1, "off the cross's list for the choice")

    -- Nobody takes its place: only the detected death has a witness to be.
    local W = ns.Witnesses
    local at = W.At
    W.At = function() return { { t = t0, guid = "Player-1-AAAAAAAA", row = { type = W.WATCHED } } } end
    local onPage = function() return 1, 1 end
    local witness = W.Card.Choose({ { x = 1, y = 1, deaths = { other } } }, {}, {}, onPage)
    Check(witness ~= nil, "a witness to a detected death, as before")
    witness = W.Card.Choose({ plateCross }, {}, {}, onPage)
    Eq(witness and witness.death, other, "the edited death is not among those it can take")
    W.At = at

    -- Emptied, the creature is the detected one again: the card is the only way
    -- back to a detected death's form.
    Custom.Edit("killedBy", plate.customKillers[1].death, { name = "" })
    cards, plate = Draw()
    Eq(plate.customKillers[1] and plate.customKillers[1].name, "Sunscale Lashtail", "a name emptied is the detected one")
    Eq(plate.customKillers[1].display, 1234, "with its picture")

    Custom.Reset(rec)
    Eq(rec.custom, nil, "Reset takes the changes off")
    cards, plate = Draw()
    Eq(plate.killer.count, 2, "exactly the detected card again")
    Eq(page.customKillersWritten, 0, "and no custom one")
end

--------------------------------------------------------------------------
Section("a detected death hidden and brought back")

do
    Custom.Hide(rec)
    local e = Gathered()
    Eq(#e.hidden, 1, "listed to bring back")
    Eq(e.hidden[1].kind, "killedBy", "its kind")
    Eq(e.hidden[1].rec, rec, "its record")
    Eq(#j.deaths, 2, "its record is kept")
    Eq(#e.deaths, 1, "the route's death stays")
    local _, plate = Draw()
    Eq(#plate.crosses, 1, "its cross stays, the route's")
    Eq(plate.killer.count, 1, "the card is the other death's alone")
    Eq(#Recap.Gather(j, t0 + 800, t0 + 4000, Recap.Context(ns.ownGUID, now)).hidden, 0, "not on a page outside its time")
    Custom.Show(rec)
    Eq(#Gathered().hidden, 0, "back")
    Eq(rec.custom, nil, "hidden and shown leaves nothing behind")
end
