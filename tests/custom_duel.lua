-- Custom cards: the duel kind (.claude/features/custom-cards.md). A detected
-- series edited and hidden with capture counting on underneath; one inserted,
-- which capture never counts on to; forgetting; and each custom one a note of its
-- own, on the print or in the margin. Everyone here is invented.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Duels, Recap, J = ns.Custom, ns.Duels, ns.JourneyRecap, ns.Journey
local Slip = Duels.Slip
local Text = ns.UI.JourneyText

local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local BRAM = "Player-0000-7E57D001"
local WREN = "Player-0000-7E57D002"
ns.Characters.Observe(BRAM, { first = "Bram", surname = "Redfen", class = "WARRIOR", race = "Orc", level = 12,
    sex = 2, time = now })
ns.Characters.Observe(WREN, { first = "Wren", surname = "Ashby", class = "MAGE", race = "Troll", level = 12,
    sex = 3, time = now })
ns.Diary.Add(BRAM, { source = "test" })
ns.Diary.Add(WREN, { source = "test" })

local t0 = now - 7200
local j = J.Begin(ns.ownGUID, t0, 12, 1412)
j.segments, j.open = {}, nil
j.segments[1] = { kind = "stop", from = t0, to = t0 + 3600, mapID = 1412, x = 0.4, y = 0.6, r = 30, seconds = 3600,
    levelFrom = 12, levelTo = 12 }
J.Touch()
local WHERE = { mapID = 1412, x = 0.45, y = 0.55, from = t0, to = t0 + 3600 }
local PLACE = { mapID = 1412, x = 0.5, y = 0.5, subZone = "Razor Hill", zone = "Durotar" }

local function Series(counts)
    local rec = { t = t0 + 900, ended = t0 + 1000, guid = BRAM, mapID = 1412, x = 0.42, y = 0.58, subZone = "Razor Hill",
        zone = "Durotar" }
    for k, v in pairs(counts) do rec[k] = v end
    return rec
end
local function Read(a, b)
    local e = Recap.Gather(j, a or t0, b or now + 1, Recap.Context(ns.ownGUID, now))
    return e.duels, e
end

--------------------------------------------------------------------------
Section("the kind in the picker")

do
    local spec = Custom.Spec("duel")
    Eq(spec.label, "Duel", "its title")
    Eq(spec.group, "social", "its type")
    local person = spec.fields[1]
    Eq(person.type, "person", "the opponent is a person's line")
    Eq(person.guid, "guid", "linked by the record's own guid")
    Eq(Custom.GuidKey(person), "guid", "the base keeps it there")
    local found
    for _, k in ipairs(ns.UI.YourDiary.CardSheet.Kinds()) do found = found or k.kind == "duel" end
    Check(found, "listed in the picker")
    Eq(spec.defaults, nil, "a new card claims no result of its own")
    for _, field in ipairs(spec.fields) do
        if field.values then
            -- The form's toggles are 70 px each from x 118 on a 320 px sheet.
            Check(#field.values <= 2, "a choice wider than the form: " .. field.key)
        end
    end
end

--------------------------------------------------------------------------
Section("a detected series edited")

j.duels = { Series({ lost = 1, last = "lost" }) }
local rec = j.duels[1]
do
    Eq(Read()[1], rec, "nothing custom is read as it is, no copy")
    Eq(Duels.Note(rec, true), "lost a duel to Bram", "named from the diary, the record holding no name")

    Custom.Edit("duel", rec, { won = 1, lost = "" })
    local read = Read()[1]
    Eq(read.customOf, rec, "the copy knows its record")
    Eq(Duels.Note(read, true), "beat Bram in a duel", "the note says what the counts say")
    Eq(Duels.Phrase({ read }), "a duel won", "the caption's words too")
    local _, lines = Duels.Tip(read, now)
    Eq(lines[1], "You won", "and the tooltip")
    Eq(rec.last, "lost", "the detected result stays")
    Eq(rec.lost, 1, "the detected count stays")

    Custom.Edit("duel", read, { name = "Old Tom", guid = nil })
    read = Read()[1]
    Eq(read.name, "Old Tom", "a name as typed")
    Eq(read.guid, nil, "a typed name lets the diary's entry go")
    Eq(rec.guid, BRAM, "the record keeps who was really there")
    Eq(rec.name, nil, "no typed name goes on the record")
    Eq(Duels.Note(read, true), "beat Old Tom in a duel", "the typed name is what the card shows")
    Eq((Duels.Tip(read, now)), "Duelled Old Tom", "the tooltip's title too")

    Custom.Edit("duel", read, { name = "Wren", guid = WREN })
    Eq(Read()[1].guid, WREN, "someone picked is linked")

    Custom.Edit("duel", Read()[1], { won = 3, lost = 1 })
    read = Read()[1]
    Eq(Duels.Note(read, true), "beat Wren 3 to 1", "a series' figures")
    local _, l2 = Duels.Tip(read, now)
    Eq(l2[1], "Won 3, lost 1", "in the tooltip")

    Custom.Reset(read)
    Eq(rec.custom, nil, "Reset takes the changes off")
    Eq(Read()[1], rec, "exactly the detected card")
end

--------------------------------------------------------------------------
Section("a detected flight, changed by its counts")

do
    local flight = Series({ theyFled = 1, last = "they_fled" })
    j.duels = { flight }
    Custom.Edit("duel", flight, { name = "Old Tom" })
    Eq(Duels.Note(Read()[1], true), "Old Tom fled the duel", "a change elsewhere leaves the flight told")
    Custom.Edit("duel", Read()[1], { lost = 1, theyFled = "" })
    Eq(Duels.Note(Read()[1], true), "lost a duel to Old Tom", "new counts say so, its old result no longer believed")
    Custom.Reset(flight)
    Eq(Duels.Note(flight, false), "they fled the duel", "and Undo gives it back")
end

--------------------------------------------------------------------------
Section("capture carries on underneath")

do
    local series = Series({ lost = 1, last = "lost", ended = now - 60 })
    j.duels = { series }
    Custom.Edit("duel", series, { name = "Old Tom", won = 1, lost = "" })

    local _, added = Duels.Added(BRAM, "lost", now - 30, now - 10, PLACE)
    Eq(added, series, "a rematch with the one really there finds the edited record")
    Eq(#j.duels, 1, "...and makes no new one")
    Eq(series.lost, 2, "its count goes on under the changes")
    Eq(series.ended, now - 10, "its end too")
    Eq(series.custom.won, 1, "the player's word is left alone")
    Eq(series.custom.name, "Old Tom", "and the name they wrote")
    Eq(Read()[1].name, "Old Tom", "the page reads their word over it")
    Custom.Reset(series)
    Eq(Duels.Note(Read()[1], true), "lost to Bram twice", "Undo gives back the true series, rematch and all")

    -- Picked over: someone written on a card did not fight this duel.
    series = Series({ lost = 1, last = "lost", ended = now - 60 })
    j.duels = { series }
    Custom.Edit("duel", series, { name = "Wren", guid = WREN })
    local _, other = Duels.Added(WREN, "won", now - 30, now - 10, PLACE)
    Check(other ~= series, "a rematch never counts on to the name typed over a record")
    Eq(#j.duels, 2, "it is a series of its own")
    Eq(series.won, nil, "the edited one is not touched")

    -- A hidden one goes on counting too, so bringing it back is true.
    series = Series({ lost = 1, last = "lost", ended = now - 60 })
    j.duels = { series }
    Custom.Hide(series)
    Duels.Added(BRAM, "won", now - 30, now - 10, PLACE)
    Eq(#j.duels, 1, "a hidden record is still the one going on")
    Eq(series.won, 1, "counted")
end

--------------------------------------------------------------------------
Section("an inserted card, which capture never finds")

do
    j.duels, j.custom = {}, nil
    local rows = ns.db.interactions[BRAM] and #ns.db.interactions[BRAM] or 0
    local card = Custom.Insert("duel", { name = "Bram", guid = BRAM, won = 1, lost = "", theyFled = "",
        fled = "" }, WHERE)
    Check(card, "inserted")
    Eq(card.guid, BRAM, "linked")
    Eq(card.ended, nil, "no end, which only capture knows")
    local read = Read()[1]
    Check(read.inserted and read.customOf == card, "read as inserted")
    Eq(Duels.Note(read, true), "beat Bram in a duel", "one duel, by its count")
    Eq(Duels.Phrase({ read }), "a duel won", "its caption")
    Eq(Slip.Choose({ { at = { 1, 1 }, list = { { kind = "duel", duel = read } } } }), nil,
        "not among those the plate's one note is chosen from")

    local rowsNow = ns.db.interactions[BRAM] and #ns.db.interactions[BRAM] or 0
    Eq(rowsNow, rows, "writes no People row")
    Eq(#j.duels, 0, "nothing goes in the detected list")

    local _, added = Duels.Added(BRAM, "lost", now - 30, now - 10, PLACE)
    Check(added and added ~= card, "a duel with the same person starts its own series")
    Eq(card.lost, nil, "the card the player wrote is not counted on")
    Eq(#j.custom, 1, "still their one card")
    Eq(#j.duels, 1, "the real duel is in the list")
    -- Not only because a card has no end to run on from: the list itself is
    -- never read, should a card ever come to have one.
    j.duels = {}
    card.ended = now - 30
    local _, again = Duels.Added(BRAM, "lost", now - 20, now - 5, PLACE)
    Check(again and again ~= card, "a card with an end is still not found")
    Eq(card.lost, nil, "nor counted on")
    card.ended = nil
    rows = ns.db.interactions[BRAM] and #ns.db.interactions[BRAM] or 0
    Custom.Edit("duel", read, { won = "", lost = 1 })
    Eq(card.lost, 1, "an inserted card takes changes outright")
    Eq(card.custom, nil, "with no list of changes")
    Eq(#(ns.db.interactions[BRAM] or {}), rows, "an edit writes no People row either")
    Custom.Remove(card)
    Eq(#j.custom, 0, "removed")

    -- Left blank: it is not for the diary to say who won.
    local blank = Custom.Insert("duel", { name = "" }, WHERE)
    Eq(Duels.Note(blank, true), "a duel", "nothing said, nothing claimed")
    Eq(Duels.Phrase({ blank }), "a duel", "in the caption")
    local title, lines = Duels.Tip(blank, now)
    Eq(title, "A duel", "the tooltip's title")
    Check(lines[1] ~= "You lost", "no loss made up in the tooltip")
    local named = Custom.Insert("duel", { name = "Old Tom" }, WHERE)
    Eq(Duels.Note(named, true), "duelled Old Tom", "a name and no result")
    local fled = Custom.Insert("duel", { name = "Old Tom", theyFled = 1 }, WHERE)
    Eq(Duels.Note(fled, true), "Old Tom fled the duel", "a flight is written by its count")
    Eq(Duels.Describe(fled), "Old Tom fled the duel", "the menu's line")
    Custom.Remove(blank) Custom.Remove(named) Custom.Remove(fled)
end

--------------------------------------------------------------------------
Section("hidden, the cap, and forgetting")

do
    j.duels, j.custom = { Series({ won = 1, last = "won" }) }, nil
    local series = j.duels[1]
    Custom.Hide(series)
    local duels, e = Read()
    Eq(#duels, 0, "off the page")
    Eq(e.hidden[1].kind, "duel", "listed by kind to bring back")
    Eq(e.hidden[1].rec, series, "with its record")
    Custom.Show(series)
    Eq(series.custom, nil, "shown again, nothing behind")

    Custom.Edit("duel", series, { name = "Wren", guid = WREN })
    local card = Custom.Insert("duel", { name = "Wren", guid = WREN, won = 1 }, WHERE)
    local plain = Series({ won = 1, last = "won", t = t0 + 1500 })
    j.duels[2] = plain
    ns.ForgetEverywhere(WREN)
    Eq(series.custom.guid, nil, "forgotten: the edit lets them go")
    Eq(series.custom.name, "Wren", "the name as written stays")
    Eq(card.guid, nil, "an inserted card lets them go")
    Eq(card.name, "Wren", "and keeps the name")
    Eq(Duels.Note(card, true), "beat Wren in a duel", "its words stay the player's")
    ns.ForgetEverywhere(BRAM)
    Eq(series.guid, nil, "the record lets the real opponent go")
    Eq(plain.guid, nil, "any record does")
    Eq(Duels.Note(plain, true), "won a duel", "an unedited one goes nameless, the route keeping no names")
    ns.Characters.Observe(BRAM, { first = "Bram", surname = "Redfen", class = "WARRIOR", race = "Orc", level = 12,
        sex = 2, time = now })
    ns.Characters.Observe(WREN, { first = "Wren", surname = "Ashby", class = "MAGE", race = "Troll", level = 12,
        sex = 3, time = now })
    ns.Diary.Add(BRAM, { source = "test" })
    ns.Diary.Add(WREN, { source = "test" })

    j.custom = nil
    local list = {}
    for i = 1, 5 do list[i] = Series({ t = t0 + i, won = 1, last = "won" }) end
    j.duels = list
    list[1].custom = { lost = 1 }
    local cap = J.T.duels
    J.T.duels = 5
    J.Append(j, "duels", Series({ t = t0 + 6, won = 1, last = "won" }), PLACE)
    J.Append(j, "duels", Series({ t = t0 + 7, won = 1, last = "won" }), PLACE)
    Eq(list[1].t, t0 + 1, "the cap passes over an edited series")
    J.T.duels = cap
end

--------------------------------------------------------------------------
Section("the plate's one note, and the player's own")

do
    local mine = Series({ won = 1, last = "won", t = 300 })
    local read = { t = 300, won = 1, last = "won", customOf = mine }
    local older = { t = 100, won = 1, last = "won", customOf = mine }
    local big = Series({ won = 3, lost = 2, last = "won", t = 200 })
    local marks = { { x = 1, y = 2, at = { 10, 20 }, list = { { kind = "duel", duel = read }, { kind = "duel", duel = big } } },
        { x = 3, y = 4, at = { 30, 40 }, list = { { kind = "duel", duel = older } } } }
    Eq(Slip.Choose(marks).rec, big, "the plate's one is still chosen, past the custom")
    local customs = Slip.Customs(marks)
    Eq(#customs, 2, "a note each")
    Eq(customs[1].rec, read, "the newest first")
    Eq(customs[2].mark[2], 40, "each to its own flag")
    Eq(customs[1].x, 1, "its flag on the card, which the print's slip steps round")
    Eq(ns.UI.JourneyMargin.KINDS.duelCustom.order, 8.5, "the order it was given")
    Eq(ns.UI.JourneyMargin.KINDS.duelCustom.filler, nil, "and it is no filler")
end

--------------------------------------------------------------------------
Section("on the page")

local page
local function Open(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.open = i
            page.mode = "plates"
            ns.UI.RedrawJourneyPage()
            return e
        end
    end
end
local function Shown(pool)
    local list = {}
    for i = 1, (page[pool] and page[pool].used or 0) do
        if page[pool][i]:IsShown() then list[#list + 1] = page[pool][i] end
    end
    return list
end
local function Words()
    local list = {}
    for _, slip in ipairs(Shown("duelPool")) do list[#list + 1] = slip:Words() end
    table.sort(list)
    return table.concat(list, " / ")
end

-- Mulgore with Bram, then a light plate on Zephras Isle, where the duels are.
-- Good luck there takes the print, where `luck`.
local LUCK = { mapID = 2665, x = 0.5, y = 0.5, level = 12, questID = 9, title = "Isle Eggs", item = "Isle Egg",
    need = 2, kills = 2, expected = 20, npcID = 7, name = "Isle Raptor" }
local t5
local function Road(detected, inserted, luck)
    t5 = now - 50000
    ns.db.journey[SELF.guid] = nil
    j = J.Begin(SELF.guid, t5, 12, 1412)
    local function Seg(seg)
        seg.levelFrom, seg.levelTo = 12, 12
        j.segments[#j.segments + 1] = seg
    end
    Seg({ kind = "stop", from = t5, to = t5 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 30, seconds = 1800 })
    ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t5 + 600, endedAt = t5 + 1500,
        participants = { [BRAM] = { since = t5 + 600, last = t5 + 1500, seconds = 900, levelStart = 12 } } })
    Seg({ kind = "flight", from = t5 + 1800, to = t5 + 2100, mapID1 = 1412, x1 = 0.5, y1 = 0.5, mapID2 = 2665,
        x2 = 0.5, y2 = 0.5 })
    Seg({ kind = "stop", from = t5 + 2100, to = t5 + 3900, mapID = 2665, x = 0.5, y = 0.5, r = 30, seconds = 1800 })
    j.duels, j.hunts = {}, {}
    if detected then
        detected.t, detected.ended, detected.mapID, detected.x, detected.y = t5 + 2700, t5 + 2900, 2665, 0.5, 0.5
        j.duels[1] = detected
    end
    if luck then
        luck.t = t5 + 3000
        j.hunts = { luck }
    end
    for i, fields in ipairs(inserted or {}) do
        Custom.Insert("duel", fields, { mapID = 2665, x = 0.5 + i * 0.02, y = 0.5, from = t5 + 2100, to = t5 + 3900 })
    end
    J.Touch()
    ns.UI.RefreshJourneyPage(false)
    return Open(12)
end
local function Isle()
    for _, p in ipairs(page.plates) do
        if p:IsShown() and p.mapID == 2665 then return p end
    end
end

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()

do
    -- An automatic one alone: as it was.
    Road({ won = 1, last = "won", guid = BRAM, subZone = "Zephras Isle" })
    local p = Isle()
    Check(p and p.slot.light, "setup: a light plate")
    -- The mock's 6 px a byte leaves these names too long for a tucked print, so
    -- the words are nameless here; the note's own tests above have them named.
    Eq(p.duelPrint and p.duelPrint.words, "won a duel", "the automatic one on the print")
    Eq(page.duelsWritten, 1, "counted")
    Eq(page.customDuelsWritten, 0, "and no custom one")

    -- One of the player's, alone: on the print, as an automatic one is.
    Road(nil, { { name = "Wren", guid = WREN, lost = 1 } })
    p = Isle()
    Check(p and p.slot.light, "setup: a card of theirs keeps the plate light")
    Check(p.duelPrint and p.duelPrint.rec.customOf, "the card is on the print")
    Eq(p.duelPrint.words, "lost a duel", "in its words")
    Eq(p.duelPrint.rec.name, "Wren", "the card's own series")
    Eq(page.customDuelsWritten, 1, "counted as written")
    Eq(page.duelsWritten, 0, "not as the automatic one")
    Eq(Words(), "", "not in the margin as well")

    -- The right button on the slip opens its form, not the map's menu.
    local hit = p.duelHit
    hit.scripts.OnMouseUp(hit, "RightButton")
    local view = ns.UI.YourDiary.CardSheet.View()
    Check(view and view.kind == "duel", "the form for a duel")
    Eq(view.rec, p.duelPrint.rec, "for the slip's series")
    view:Hide(true)

    -- Both: the player's on the print, the automatic one moved to the margin.
    Road({ won = 1, last = "won", guid = BRAM, subZone = "Zephras Isle" }, { { name = "Wren", guid = WREN, lost = 1 } })
    p = Isle()
    Check(p.duelPrint.rec.customOf, "the player's takes the print")
    Eq(p.duel.rec.customOf, nil, "the plate's one is the automatic")
    Eq(page.customDuelsWritten, 1, "the card counted")
    -- The automatic one has only the margin now, or, filler, the words.
    local moved
    for _, slip in ipairs(Shown("duelPool")) do moved = moved or slip.series.rec == p.duel.rec end
    Check(moved or p.duelTold == true, "the automatic one is not lost to the print")
    Eq(page.duelsWritten, moved and 1 or 0, "and counted only where it shows")

    -- Good luck keeps the print, as it does from an automatic duel.
    local luck = {}
    for k, v in pairs(LUCK) do luck[k] = v end
    Road(nil, { { name = "Wren", guid = WREN, lost = 1 } }, luck)
    p = Isle()
    Check(p.print, "setup: good luck on the print")
    Eq(p.duelPrint, nil, "a card does not take it from good luck")
    Eq(#p.customDuels, 1, "the card is still wanted in the margin")

    -- Two of theirs: the newest on the print, the other its own note.
    Road(nil, { { name = "Old Tom", won = 1 }, { name = "Wren", guid = WREN, lost = 1 } })
    p = Isle()
    Eq(#p.customDuels, 2, "two cards on the plate")
    Check(p.duelPrint, "one on the print")
    Eq(p.duelPrint.rec, p.customDuels[1].rec, "the newest")
end

do
    -- A full plate: a note each, and the plate's one beside them, at most. A
    -- close call there makes it full.
    local function FullRoad(detected, inserted)
        Road(detected, inserted)
        j.closeCalls = { { t = t5 + 2600, mapID = 2665, x = 0.3, y = 0.3, level = 12, pct = 5, name = "Isle Raptor" } }
        J.Touch()
        ns.UI.RefreshJourneyPage(false)
        return Open(12)
    end
    FullRoad({ won = 1, last = "won", guid = BRAM, subZone = "Zephras Isle" },
        { { name = "Wren", guid = WREN, lost = 1 }, { name = "Old Tom", won = 1 } })
    local p = Isle()
    Check(p and not p.slot.light, "setup: a full plate")
    Eq(p.duelPrint, nil, "no print to go on")
    Eq(#p.customDuels, 2, "both cards wanted")
    Eq(page.customDuelsWritten, 2, "both written, whatever the filler does")
    -- By their series: the mock's widths leave these slips nameless.
    local function Slips(name)
        for _, slip in ipairs(Shown("duelPool")) do
            if slip.series.rec.name == name then return slip end
        end
    end
    Check(Slips("Wren"), "the card for Wren")
    Check(Slips("Old Tom"), "the card for Old Tom")
    -- Their leaders go to their own flags, and a right click opens the card's own.
    local opened
    Slips("Old Tom").onRight()
    opened = ns.UI.YourDiary.CardSheet.View()
    Eq(opened.kind, "duel", "the slip's right click opens a form")
    Eq(opened.rec.name, "Old Tom", "its own card's")
    opened:Hide(true)

    -- An edited automatic one is the player's too: out of the choice, a note of
    -- its own, even with a bigger one to choose.
    local edited = { won = 1, last = "won", guid = BRAM, subZone = "Zephras Isle",
        custom = { name = "Old Tom" } }
    FullRoad(edited)
    p = Isle()
    Eq(p.duel, nil, "not the plate's one")
    Eq(page.customDuelsWritten, 1, "its own note")
    Eq(Slips("Old Tom").series.rec.customOf, edited, "in the name the player gave")

    -- With more cards than the margin holds, the words say there were duels: the
    -- mock's short boxes run out, and a card left off must not go untold.
    local spec, said = ns.UI.JourneyMargin.KINDS.duelCustom, {}
    local plate = { customDuels = Slip.Customs({ { x = 1, y = 2, at = { 10, 20 },
        list = { { kind = "duel", duel = { t = 1, customOf = {} } } } } }) }
    spec.say(said, {}, plate)
    Eq(said.duel, true, "one left off goes in the caption")
    said = {}
    spec.say(said, { {} }, plate)
    Eq(said.duel, nil, "one shown does not")
end

--------------------------------------------------------------------------
Section("with \"Keep my own route\" off")

do
    Road()
    ns.SetSetting("keepRoute", false)
    Eq(J.Kept(), nil, "setup: capture is off")
    local card = Custom.Insert("duel", { name = "Old Tom", won = 1 }, { mapID = 2665, x = 0.5, y = 0.5,
        from = t5 + 2100, to = t5 + 3900 })
    Check(card, "a card can still be written")
    Check(Custom.Edit("duel", card, { lost = 1 }), "and changed")
    ns.SetSetting("keepRoute", true)
end

--------------------------------------------------------------------------
Section("the form has no result of its own: the counts say it")

do
    local fields = {}
    for _, field in ipairs(Custom.Spec("duel").fields) do fields[field.key] = true end
    Eq(fields.last, nil, "no Last duel on the form")
    -- An edit elsewhere leaves a detected duel's result, and a tie reads as one.
    local one = Series({ lost = 1, last = "lost" })
    j.duels = { one }
    Custom.Edit("duel", one, { name = "Old Tom" })
    Eq(Duels.Note(Read()[1], true), "lost a duel to Old Tom", "its result stays where its count bears it out")
    Custom.Edit("duel", Read()[1], { lost = "" })
    Eq(Duels.Note(Read()[1], true), "duelled Old Tom", "no count left, no result claimed")
    Eq(one.last, "lost", "the detected value stays underneath")
    Custom.Reset(one)
    Eq(Duels.Note(one, true), "lost a duel to Bram", "Undo gives it back")
    local tied = Custom.Insert("duel", { name = "Wren", won = 1, lost = 1 }, WHERE)
    Eq(Duels.Note(tied, true), "1 each with Wren", "a tie, plainly")
    Custom.Remove(tied)
end
