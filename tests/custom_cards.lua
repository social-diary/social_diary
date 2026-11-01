-- Custom cards (.claude/features/custom-cards.md, Core/Custom.lua): a detected
-- close call edited, hidden and reset, one inserted, and what keeps them on
-- the page looking as automatic ones do.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, CloseCalls, Recap, J = ns.Custom, ns.CloseCalls, ns.JourneyRecap, ns.Journey

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
J.Begin(ns.ownGUID, t0, 10, 1412)
local j = J.Mine()
j.segments = {}
j.open = nil
local function Seg(s)
    s.levelFrom, s.levelTo = s.levelFrom or 10, s.levelTo or 10
    j.segments[#j.segments + 1] = s
end
Seg({ kind = "stop", from = t0, to = t0 + 1200, mapID = 1412, x = 0.40, y = 0.60, r = 30, seconds = 1200 })
Seg({ kind = "road", from = t0 + 1200, to = t0 + 2400, mapID = 1412,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800 })
J.Touch()

local function Call(t, name)
    return { t = t, mapID = 1412, x = 0.42, y = 0.58, level = 10, pct = 6, seconds = 42, took = 94,
        npcID = 2955, name = name or "Plainstrider", foeLevel = 7, foes = 3, display = 1961 }
end

local function Calls(a, b)
    local e = Recap.Gather(j, a or t0, b or now + 1, Recap.Context(ns.ownGUID, now))
    return e.closeCalls, e
end

--------------------------------------------------------------------------
Section("an old-shaped route reads as it did")

j.closeCalls = { Call(t0 + 900) }
do
    local calls, e = Calls()
    Eq(calls[1], j.closeCalls[1], "a record with nothing custom is read as it is, no copy")
    Eq(#e.hidden, 0, "nothing hidden")
    Eq(j.custom, nil, "reading writes no list")
end

--------------------------------------------------------------------------
Section("a detected close call edited")

local rec = j.closeCalls[1]
do
    Check(Custom.Edit("close", rec, { pct = 2, name = "Old Tom", rank = "rare", foes = "" }), "the edit")
    local read = Calls()[1]
    Eq(read.pct, 2, "the edit is read")
    Eq(read.name, "Old Tom", "the name is read")
    Eq(read.rank, "rare", "the rank is read")
    Eq(read.foes, nil, "a field left empty is cleared")
    Eq(read.npcID, nil, "a name no record knows lends no creature")
    Eq(read.display, nil, "...nor its picture")
    Eq(read.customOf, rec, "the copy knows its record")
    Eq(read.custom, nil, "the copy carries no changes")
    Eq(rec.pct, 6, "the detected value stays")
    Eq(rec.name, "Plainstrider", "the detected name stays")
    Eq(rec.foes, 3, "the detected count stays")
    Eq(ns.CreatureNames.Of(j, 2955), "Plainstrider", "the typed name renames no creature")

    Custom.Edit("close", read, { name = "Plainstrider", pct = 6, rank = "", foes = 3 })
    Eq(rec.custom, nil, "every value back at what was detected is no change")
    Eq(rec.npcID, 2955, "its creature stays")

    Custom.Edit("close", rec, { pct = 500 })
    Eq(Calls()[1].pct, 100, "a number held to its field's range")
    Custom.Edit("close", rec, { name = "|cffff0000Old\nTom|r" })
    Eq(Calls()[1].name, "cffff0000Old Tomr", "no escape sequence, one line")
    Custom.Edit("close", rec, { rank = "nonsense", junk = 1 })
    Eq(Calls()[1].rank, nil, "a choice not on the list is cleared")
    Custom.Edit("close", rec, { rank = "worldboss" })
    Eq(Calls()[1].rank, nil, "a boss cannot be chosen")
    Custom.Edit("close", rec, { rank = "rareelite" })
    Eq(Calls()[1].rank, nil, "nor a rare elite")
    Eq(rec.custom.junk, nil, "a field the kind does not list is left out")

    Check(Custom.Reset(Calls()[1]), "the reset")
    Eq(rec.custom, nil, "Reset takes the changes off")
    local again = Calls()[1]
    Eq(again, rec, "exactly the detected card")
end

--------------------------------------------------------------------------
Section("a detected close call hidden and brought back")

do
    Custom.Edit("close", rec, { pct = 3 })
    Custom.Hide(Calls()[1])
    local calls, e = Calls()
    Eq(#calls, 0, "off the page")
    Eq(#e.hidden, 1, "listed to bring back")
    Eq(e.hidden[1].kind, "close", "its kind")
    Eq(e.hidden[1].rec, rec, "its record")
    Eq(#j.closeCalls, 1, "its record is kept")
    Custom.Show(e.hidden[1].rec)
    Eq(Calls()[1].pct, 3, "back with its changes")
    Custom.Reset(rec)
    Custom.Hide(rec)
    Custom.Show(rec)
    Eq(rec.custom, nil, "hidden and shown leaves nothing behind")
end

--------------------------------------------------------------------------
Section("the cap passes over what the player changed")

do
    local list = {}
    for i = 1, 5 do list[i] = Call(t0 + i) end
    j.closeCalls = list
    list[1].custom = { pct = 1 }
    local cap = J.T.closeCalls
    J.T.closeCalls = 5
    J.Append(j, "closeCalls", Call(t0 + 6), { mapID = 1412, x = 0.5, y = 0.5 })
    Eq(#list, 6, "a changed one does not count against the cap")
    J.Append(j, "closeCalls", Call(t0 + 7), { mapID = 1412, x = 0.5, y = 0.5 })
    Eq(#list, 6, "the unchanged stay at the cap")
    Eq(list[1].t, t0 + 1, "the changed one stays")
    Eq(list[2].t, t0 + 3, "the oldest unchanged goes")
    Eq(list[6].t, t0 + 7, "the new one is kept")
    for _, r in ipairs(list) do r.custom = { pct = 1 } end
    J.Append(j, "closeCalls", Call(t0 + 8), { mapID = 1412, x = 0.5, y = 0.5 })
    Eq(#list, 7, "with all changed, the new one is still kept")
    Eq(list[7].t, t0 + 8, "at the end")
    J.T.closeCalls = cap
    j.closeCalls = { rec }
end

--------------------------------------------------------------------------
Section("a close call inserted")

local made
do
    Eq(Custom.Insert("nonsense", {}, { mapID = 1412, x = 0.5, y = 0.5, from = t0, to = now }), nil,
        "a kind that cannot be")
    Eq(Custom.Insert("close", {}, { mapID = 1412, from = t0, to = now }), nil, "with no spot")

    made = Custom.Insert("close", { name = "Old Tom", rank = "rare", foeLevel = -1 },
        { mapID = 1412, x = 0.60, y = 0.45, from = t0, to = t0 + 5000 })
    Eq(j.custom[1], made, "on its own list")
    Eq(#j.closeCalls, 1, "not on the feature's")
    Eq(made.kind, "close", "its kind")
    Eq(made.t, t0 + 2400, "the first time the route came to that spot")
    Eq(made.pct, 5, "the kind's default")
    Eq(made.level, 10, "the level then")
    Eq(made.customOf, nil, "nothing of the reading is saved")

    local nearRoad = Custom.TimeNear(j, 1412, 0.50, 0.50, t0 + 1200, t0 + 2400)
    Eq(nearRoad, t0 + 1800, "a road's nearest point in time")
    Eq(Custom.TimeNear(j, 1413, 0.5, 0.5, t0, t0 + 1000), t0 + 500, "a map the route never saw: the middle")
    local bounded = Custom.TimeNear(j, 1412, 0.60, 0.45, t0, t0 + 600)
    Check(bounded >= t0 and bounded < t0 + 600, "the time stays on the page")

    local calls = Calls()
    Eq(#calls, 2, "gathered with the detected")
    Eq(calls[1], rec, "in time order")
    Eq(calls[2].name, "Old Tom", "the inserted")
    Eq(calls[2].customOf, made, "knows its record")
    Eq(calls[2].inserted, true, "and that it was inserted")
    Eq(#Calls(t0, t0 + 2000), 1, "not on a page outside its time")

    -- A name this character's records know brings its creature.
    local known = Custom.Insert("close", { name = "plainstrider" },
        { mapID = 1412, x = 0.41, y = 0.59, from = t0, to = t0 + 1000 })
    Eq(known.npcID, 2955, "a known creature's id")
    Eq(known.display, 1961, "a known creature's picture")
    Eq(ns.CreatureNames.Of(j, 2955), "Plainstrider", "and renames nothing")
    Eq(j.custom[1], known, "the list stays in time order")
    Check(Custom.Edit("close", Calls()[1], { pct = 9, name = "Someone Else" }), "an inserted card edited")
    Eq(known.pct, 9, "takes the edit outright")
    Eq(known.custom, nil, "with no changes kept apart")
    Eq(known.npcID, nil, "a new name gives up the old creature")
    Check(Custom.Remove(known), "removed")
    Eq(j.custom[1], made, "gone from the list")
    Check(not Custom.Remove(rec), "a detected card is never removed")
end

--------------------------------------------------------------------------
Section("it needs no route being kept")

do
    ns.SetSetting("keepRoute", false)
    Check(Custom.Edit("close", rec, { pct = 4 }), "an edit with the route off")
    local off = Custom.Insert("close", { name = "Old Tom" }, { mapID = 1412, x = 0.5, y = 0.5, from = t0, to = now })
    Check(off ~= nil, "an insert with the route off")
    Custom.Remove(off)
    Custom.Reset(rec)
    ns.SetSetting("keepRoute", true)
end

--------------------------------------------------------------------------
Section("what writes to a record later runs underneath")

do
    local death = { t = t0 + 10, npcID = 77, name = "Murloc Forager Olwynne", mapID = 1412, x = 0.4, y = 0.6 }
    j.deaths = { death }
    death.custom = { name = "Old Tom" }
    j.names = { [77] = { "Murloc Forager", now } }
    ns.CreatureNames.Prune(j, now)
    Eq(death.name, "Murloc Forager", "the surname comes off the record")
    Eq(death.custom.name, "Old Tom", "the player's name is left alone")
    Eq(ns.Custom.Read(death).name, "Old Tom", "and is what is read")
    j.deaths, j.names = nil, nil
end

--------------------------------------------------------------------------
Section("custom cards outrank everything, and stay")

do
    local function M(kind, field, value, x)
        return { kind = kind, [field] = value, mapID = 1412, x = x, y = 0.5, t = t0 }
    end
    Eq(Recap.Rank(M("close", "call", { t = t0 }, 0.5)), 3, "a detected close call's own rank")
    Eq(Recap.Rank(M("close", "call", { t = t0, customOf = {} }, 0.5)), 0.5, "a custom one's")
    Check(Recap.Rank(M("close", "call", { t = t0, customOf = {} }, 0.5)) < Recap.RANK.session, "above the people")

    -- Four far apart, with the last made the player's: it still wins a plate.
    j.closeCalls, j.custom = {}, {}
    for i = 1, 4 do
        j.closeCalls[i] = Call(t0 + i * 100)
        j.closeCalls[i].x, j.closeCalls[i].y = 0.1 + i * 0.2, 0.2
    end
    j.marks = { { kind = "fight", outcome = "won", t = t0 + 900, mapID = 1412, x = 0.5, y = 0.9 } }
    local own = Custom.Insert("close", { name = "Old Tom" }, { mapID = 1412, x = 0.05, y = 0.95, from = t0, to = now })
    local e = Recap.Gather(j, t0, now + 1, Recap.Context(ns.ownGUID, now))
    local plates = Recap.Plates(j, e, Recap.Context(ns.ownGUID, now), function() return 0.1, 0.1 end)
    Eq(#plates, 3, "three plates at most")
    local found = false
    for _, plate in ipairs(plates) do
        for _, m in ipairs(plate.moments) do found = found or (m.call and m.call.customOf == own) end
    end
    Check(found, "the player's card is on one of them")
    j.marks = {}
    Custom.Remove(own)
    Custom.Reset(rec)
    j.closeCalls = { rec }
end

--------------------------------------------------------------------------
Section("the card's choice and the witnesses leave it alone")

do
    local Card = CloseCalls.Card
    local plain, edited, inserted = Call(t0 + 1), Call(t0 + 2, "Old Tom"), Call(t0 + 3, "Young Tom")
    edited.customOf, inserted.customOf = {}, {}
    edited.pct = 1
    local marks = { { at = { 10, 20 }, list = { { call = plain }, { call = edited }, { call = inserted } } } }
    local chosen = Card.Choose(marks)
    Eq(chosen.call, plain, "the plate's one card is from the detected")
    local customs = Card.Customs(marks)
    Eq(#customs, 2, "each custom one has its own card")
    Eq(customs[1].name, "Young Tom", "the newest first")
    Eq(customs[1].mark[2], 20, "its leader goes to its mark")
    Eq(#Card.Customs({ { at = { 1, 1 }, list = { { call = { customOf = {}, t = 1 } } } } }), 0,
        "with no creature named it is a cross and no card, as a detected one is")

    -- A rescue at the same moment takes the detected card, not the custom one.
    local W = ns.Witnesses
    local at = W.At
    W.At = function() return { { t = t0, guid = "Player-1-AAAAAAAA", row = { type = W.SAVED } } } end
    local witness = W.Card.Choose({}, { { at = { 1, 1 }, list = { { call = edited } } } }, {}, function() end)
    Eq(witness, nil, "no witness to a custom card")
    witness = W.Card.Choose({}, { { at = { 1, 1 }, list = { { call = plain } } } }, {}, function() end)
    Eq(witness and witness.call, plain, "a witness to a detected one, as before")
    W.At = at
end

--------------------------------------------------------------------------
Section("on the page, a custom card is a card like any other")

do
    ns.UI.ShowJournal()
    ns.UI.SetJournalView("journey")
    local page = ns.UI.JourneyPage()
    local function Shown()
        local list = {}
        for i = 1, page.killerPool.used do
            if page.killerPool[i]:IsShown() then list[#list + 1] = page.killerPool[i] end
        end
        return list
    end
    j.closeCalls = { Call(t0 + 900) }
    rec = j.closeCalls[1]
    Custom.Edit("close", rec, { pct = 2 })
    Custom.Insert("close", { name = "Young Tom", pct = 3 }, { mapID = 1412, x = 0.44, y = 0.56, from = t0, to = now })
    j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    Eq(page.state, "entries", "the page draws")
    local open
    for i, entry in ipairs(page.recap.entries) do
        if entry.level == 10 then open = i end
    end
    T.OpenDiaryPage(page, open)
    Eq(page.customFoesWritten, 2, "a card each")
    local cards = Shown()
    Eq(#cards, 2, "both in the margin")
    local names = {}
    for _, card in ipairs(cards) do
        Check(card.foe ~= nil, "wears the close call's face")
        names[card.foe.name] = true
    end
    Check(names["Young Tom"] and names["Plainstrider"], "the two creatures")
    Check(cards[1].foe.display == 1961 or cards[2].foe.display == 1961, "the edited one keeps its picture")
    local plate = page.plates[1]
    Eq(plate.counts.closeCalls >= 1, true, "its cross is drawn")
    Check(plate.customFoes[1] ~= nil and plate.foe == nil, "no detected card beside them")
    Eq(page.killersWritten, 0, "no killer's card")
end

--------------------------------------------------------------------------
Section("a kind's person field, its wrapped entries, and forgetting")

do
    local R, M = ns.JourneyRecap, ns.JourneyRecap.MOMENTS
    M.scrap = { kind = "scrap", entry = "scraps", gather = function() end, field = "s", order = 999,
        custom = { label = "Scrap", fields = { { key = "who", type = "person" }, { key = "note", type = "text" } },
            wrap = function(rec) return { rec = rec } end, timeOf = function(entry) return entry.rec.t end } }
    local list = R.MOMENTS
    local guid = "Player-1-0AAAAAAA"
    ns.db.characters[guid] = { guid = guid, names = { { first = "Brannoc", surname = "" } } }
    ns.db.diary[guid] = { tags = {}, addedAt = now }
    local where = { mapID = 1412, x = 0.5, y = 0.5, from = t0, to = now }
    local typed = Custom.Insert("scrap", { who = "Someone", whoGuid = "Player-1-0BBBBBBB" }, where)
    Eq(typed.who, "Someone", "a typed name is kept")
    Eq(typed.whoGuid, nil, "and links to nobody outside the diary")
    local linked = Custom.Insert("scrap", { who = "Brannoc", whoGuid = guid }, where)
    Eq(linked.whoGuid, guid, "a picked name links")
    Custom.Edit("scrap", linked, { who = "Brannoc the Second" })
    Eq(linked.whoGuid, nil, "typing over a picked name lets the entry go")
    Custom.Edit("scrap", linked, { who = "Brannoc", whoGuid = guid })
    Eq(linked.whoGuid, guid, "picked again")

    ns.ForgetEverywhere(guid)
    Eq(linked.whoGuid, nil, "forgotten: the link goes")
    Eq(linked.who, "Brannoc", "the name as written stays")
    Custom.Remove(typed)
    Custom.Remove(linked)
    M.scrap = nil
    Eq(#Custom.FindPeople("", 4), 0, "nothing typed finds nobody")
end
