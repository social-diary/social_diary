-- Custom cards: the hunts kind (.claude/features/custom-cards.md). One list
-- makes both `luck` and `fortune`, and luck is worked out when read: what is
-- proved here is that the player's words never move a card from one to the
-- other or off the page, that a typed item speaks for itself (no old icon, no
-- rate looked up), and that each card keeps its place: a slot of its own in the
-- margin at the table's orders, past the plate's one, or S on a light print.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Hunts, Recap, J = ns.Custom, ns.Hunts, ns.JourneyRecap, ns.Journey
local Text = ns.UI.JourneyText

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

-- Bad luck by the rates; good luck by them; neither.
local function Slow(t)
    return { t = t or t0 + 900, mapID = 1412, x = 0.42, y = 0.58, level = 10, questID = 7, title = "Meat Run",
        item = "Marsh Haunch", itemID = 4242, need = 5, shared = 2, kills = 40, expected = 12, npcID = 2955,
        name = "Marsh Strider", byKind = { [2955] = { n = 30, name = "Marsh Strider" }, [2956] = { n = 10, name = "Old Strider" } } }
end
local function Quick(t)
    return { t = t or t0 + 1000, mapID = 1412, x = 0.44, y = 0.56, level = 10, questID = 8, title = "Beak Run",
        item = "Marsh Beak", itemID = 4243, need = 2, kills = 2, expected = 20, npcID = 2957, name = "Marsh Heron" }
end
local function Usual(t)
    return { t = t or t0 + 1100, mapID = 1412, x = 0.46, y = 0.54, level = 10, questID = 9, title = "Plain Run",
        item = "Marsh Reed", need = 5, kills = 6, expected = 6, npcID = 2958, name = "Marsh Crab" }
end
mock.itemInfo[4242] = { icon = 134169, quality = 1 }

local function Gathered()
    return Recap.Gather(j, t0, now + 1, Recap.Context(ns.ownGUID, now))
end
local WHERE = { mapID = 1412, x = 0.48, y = 0.52, from = t0, to = now }

--------------------------------------------------------------------------
Section("an old-shaped route reads as it did")

local slow, quick, usual = Slow(), Quick(), Usual()
j.hunts = { slow, quick, usual }
do
    local e = Gathered()
    Eq(#e.hunts, 1, "one bad luck")
    Eq(e.hunts[1], slow, "a record with nothing custom is read as it is, no copy")
    Eq(#e.fortunes, 1, "one good luck")
    Eq(e.fortunes[1], quick, "the same")
    Eq(#e.hidden, 0, "nothing hidden")
    Eq(j.custom, nil, "reading writes no list")
end

--------------------------------------------------------------------------
Section("an edit never moves a card to the other kind, or off the page")

do
    Custom.Edit("luck", slow, { kills = 2, expected = 500 })
    local e = Gathered()
    Eq(#e.hunts, 1, "bad luck typed to look like good stays bad luck")
    Eq(e.hunts[1].customOf, slow, "the copy knows its record")
    Eq(e.hunts[1].kills, 2, "and reads as typed")
    Eq(#e.fortunes, 1, "nothing joined good luck")
    Eq(slow.kills, 40, "the detected value stays")

    Custom.Edit("fortune", quick, { kills = 900, expected = 3 })
    e = Gathered()
    Eq(#e.fortunes, 1, "good luck typed to look like bad stays good luck")
    Eq(e.fortunes[1].customOf, quick, "its copy")
    Eq(#e.hunts, 1, "nothing joined bad luck")

    Custom.Edit("fortune", quick, { expected = "" })
    Eq(#Gathered().fortunes, 1, "good luck with its expected emptied stays too: GoodLuck needs one")
    Custom.Edit("luck", slow, { kills = "" })
    Eq(#Gathered().hunts, 1, "bad luck with its kills emptied stays")
    Eq(Gathered().hunts[1].kills, slow.need, "and counts the fewest that could give it")

    Check(Custom.Reset(Gathered().hunts[1]), "the reset")
    Custom.Reset(quick)
    e = Gathered()
    Eq(e.hunts[1], slow, "exactly the detected card")
    Eq(e.fortunes[1], quick, "exactly the detected card")
end

--------------------------------------------------------------------------
Section("hidden, listed under the kind it would have shown under")

do
    Custom.Edit("luck", slow, { kills = 2 })
    Custom.Hide(Gathered().hunts[1])
    Custom.Hide(quick)
    local e = Gathered()
    Eq(#e.hunts + #e.fortunes, 0, "both off the page")
    Eq(#e.hidden, 2, "both listed to bring back")
    Eq(e.hidden[1].kind, "luck", "bad luck's kind, its typed kills notwithstanding")
    Eq(e.hidden[1].rec, slow, "its record")
    Eq(e.hidden[2].kind, "fortune", "good luck's kind")
    Eq(e.hidden[2].rec, quick, "its record")
    Custom.Hide(usual)
    Eq(#Gathered().hidden, 2, "a hunt of neither kind never had a card to bring back")
    Custom.Reset(usual)
    Custom.Show(slow)
    Eq(Gathered().hunts[1].kills, 2, "back with its changes")
    Custom.Reset(slow)
    Custom.Show(quick)
    Eq(quick.custom, nil, "hidden and shown leaves nothing behind")
end

--------------------------------------------------------------------------
Section("what a retyped card no longer takes from the detected record")

do
    Custom.Edit("luck", slow, { kills = 41 })
    local read = Gathered().hunts[1]
    Eq(read.byKind, nil, "typed kills: the kinds would list the detected ones on the card")
    Eq(read.itemID, 4242, "the item is untouched, so its icon stays")
    Eq(read.shared, 2, "and the group's copies")
    Custom.Reset(slow)

    Custom.Edit("luck", slow, { name = "Old Tom" })
    read = Gathered().hunts[1]
    Eq(read.byKind, nil, "a typed creature: nor the kinds")
    Eq(read.npcID, nil, "nor its id")
    Eq(ns.CreatureNames.Of(j, 2955), "Marsh Strider", "the typed name renames no creature")
    Custom.Reset(slow)

    Custom.Edit("luck", slow, { need = 9 })
    Eq(Gathered().hunts[1].shared, nil, "typed items: the group's copies would change the kills an item")
    Custom.Reset(slow)

    Custom.Edit("luck", slow, { item = "Wooden Spoon" })
    read = Gathered().hunts[1]
    Eq(read.item, "Wooden Spoon", "the typed item")
    Eq(read.itemID, nil, "the old item's id does not come with it")
    Eq(read.questID, nil, "nor the quest that would find it again")
    local icon, id, from = Hunts.HuntCard.Icon(read)
    Eq(icon, Hunts.HuntCard.SACK, "the cards' stand-in")
    Eq(from, "sack", "from the sack")
    Eq(id, nil, "with no item behind it")
    Eq(slow.itemID, 4242, "the record keeps its own")
    Custom.Edit("luck", read, { item = "Marsh Haunch" })
    Eq(slow.custom, nil, "the detected item typed back is no change")
    Eq(Hunts.HuntCard.Icon(Gathered().hunts[1]), 134169, "and its icon is back")
end

--------------------------------------------------------------------------
Section("a rate is looked up for a detected hunt only")

do
    local Q = ns.QuestieBridge
    local saved = { On = Q.On, ItemFor = Q.ItemFor, DropRate = Q.DropRate, WowheadRate = Q.WowheadRate }
    local asked = 0
    Q.On = function() return true end
    Q.ItemFor = function() asked = asked + 1; return 4242 end
    Q.DropRate = function() asked = asked + 1; return 50 end
    Q.WowheadRate = function() asked = asked + 1; return 50 end

    local copy = { customOf = slow, questID = 7, need = 5, kills = 40, npcID = 2955, item = "Wooden Spoon" }
    Eq(Hunts.Rated(copy), false, "a copy with no expected has no rate")
    Eq(copy.expected, nil, "and is given none")
    Eq(asked, 0, "the bridge is not asked")

    local inserted = Custom.Insert("luck", { item = "Wooden Spoon", kills = 30, need = 5 }, WHERE)
    asked = 0
    local read
    for _, hunt in ipairs(Gathered().hunts) do
        if hunt.customOf == inserted then read = hunt end
    end
    Check(read ~= nil, "the inserted card is read")
    Eq(read.expected, nil, "and rated by nobody")
    Eq(inserted.expected, nil, "nor is its record written to")
    Custom.Remove(inserted)

    for key, fn in pairs(saved) do Q[key] = fn end
end

--------------------------------------------------------------------------
Section("inserted cards go straight in, by their kind")

do
    local bad = Custom.Insert("luck", { item = "Wooden Spoon", kills = 1, need = 1, expected = 900 }, WHERE)
    local good = Custom.Insert("fortune", { item = "Golden Spoon", kills = 900, need = 1, expected = 1 }, WHERE)
    Eq(j.custom[1].kind == "luck" or j.custom[2].kind == "luck", true, "kept with its kind")
    local e = Gathered()
    Eq(#e.hunts, 2, "bad luck, whatever its numbers say")
    Eq(#e.fortunes, 2, "good luck, whatever its numbers say")
    local function Has(list, rec)
        for _, hunt in ipairs(list) do
            if hunt.customOf == rec then return hunt end
        end
    end
    Check(Has(e.hunts, bad) and Has(e.fortunes, good), "each in its own")
    Check(not Has(e.fortunes, bad) and not Has(e.hunts, good), "neither in the other")
    Check(e.fortunes[1].t <= e.fortunes[2].t, "in time among the rest")
    Eq(#j.hunts, 3, "the detected list is not touched")
    Eq(Hunts.UsualLuck(j), nil, "and neither is the character's usual")
    Custom.Remove(bad)
    Custom.Remove(good)

    local plain = Custom.Insert("luck", {}, WHERE)
    Eq(plain.need, 5, "starts from the kind's defaults")
    Eq(plain.kills, 30, "both")
    Custom.Edit("luck", plain, { need = "", kills = "" })
    local read = Has(Gathered().hunts, plain)
    Eq(read.need, 1, "emptied, it still counts one item")
    Eq(read.kills, 1, "and a kill for it")
    Eq(plain.need, nil, "on the page's copy only")
    Custom.Remove(plain)
    Eq(Custom.Spec("fortune").defaults.expected, 20, "good luck starts with something to strike through")
end

--------------------------------------------------------------------------
Section("the cap passes over what the player changed")

do
    local list = {}
    for i = 1, 5 do list[i] = Usual(t0 + i) end
    j.hunts = list
    list[1].custom = { kills = 9 }
    local cap = J.T.hunts
    J.T.hunts = 5
    local function Finish(n)
        j.hunting = { ["1:" .. n] = { questID = 1, index = n, item = "Reed", need = 1, kills = { [5] = 2 }, from = { [5] = true },
            names = { [5] = "Crab" }, since = t0 } }
        Hunts.Done(j, 1, n, { t = t0 + 100 + n }, { mapID = 1412, x = 0.5, y = 0.5 })
    end
    Finish(1)
    Eq(#list, 6, "a changed one does not count against the cap")
    Finish(2)
    Eq(#list, 6, "the unchanged stay at the cap")
    Eq(list[1].t, t0 + 1, "the changed one stays")
    Eq(list[1].custom.kills, 9, "with its changes")
    Eq(list[2].t, t0 + 3, "the oldest unchanged went")
    J.T.hunts = cap
end

--------------------------------------------------------------------------
Section("the words, where a card gives no figure or no item")

do
    Eq(Hunts.ExpectedLabel({ kills = 2 }), "expected more", "nothing made up to strike through")
    Eq(Hunts.ExpectedLabel({ kills = 2, expected = 11.6 }), "expected 12", "a figure as before")
    Eq(Hunts.Fortune({ kills = 1, need = 1, name = "Old Tom", item = "Spoon" }), "The first Old Tom gave up its Spoon.",
        "the first kill, no figure")
    Check(Hunts.Fortune({ kills = 1, need = 1, name = "Old Tom", item = "Spoon", expected = 10 }):find("where 10", 1, true),
        "with one, as before")
    Check(Hunts.Words({ kills = 30, need = 5 }):find("drops", 1, true), "no item: drops, " .. Hunts.Words({ kills = 30, need = 5 }))
    Eq(Custom.Spec("luck").describe({ item = "Spoon", kills = 30 }), "Spoon, 30 killed", "a menu's line")
    Eq(Custom.Spec("fortune").describe({}), "A lucky hunt, 0 killed", "with nothing to name")
end

--------------------------------------------------------------------------
Section("what the picker reads")

do
    local bad, good = Custom.Spec("luck"), Custom.Spec("fortune")
    Eq(bad.label, "Bad Luck", "its title")
    Eq(good.label, "Good Luck", "its title")
    Eq(bad.group, "lore", "Quests and Lore")
    Eq(good.group, "lore", "Quests and Lore")
    Check(bad.at < good.at, "bad luck first")
    Eq(bad.heading, "A slow hunt", "the form's heading, the caption's word")
    Eq(good.heading, "A lucky hunt", "the form's heading, the caption's word")
    local keys = {}
    for _, field in ipairs(good.fields) do keys[#keys + 1] = field.key end
    Eq(table.concat(keys, " "), "item need name kills expected", "all the cards show")
end

--------------------------------------------------------------------------
Section("on the page, a card each, at their slots")

local Margin = ns.UI.JourneyMargin
Eq(Margin.KINDS.huntCustom.order, 7, "bad luck's slot, as the table says")
Eq(Margin.KINDS.luckyCustom.order, 8, "good luck's")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function Shown(pool)
    local list = {}
    for i = 1, page[pool].used do
        if page[pool][i]:IsShown() then list[#list + 1] = page[pool][i] end
    end
    return list
end
local function OpenLevel(level)
    ns.UI.RefreshJourneyPage(true)
    for i, entry in ipairs(page.recap.entries) do
        if entry.level == level then
            T.OpenDiaryPage(page, i)
            return entry
        end
    end
end
local function Caption() return page.captionPool[1]:GetText() or "" end

do
    j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
    slow, quick = Slow(), Quick()
    j.hunts = { slow, quick }
    Custom.Edit("luck", slow, { kills = 50 })
    local typed = Custom.Insert("luck", { item = "Wooden Spoon", kills = 33, need = 3, name = "Old Tom" }, WHERE)
    OpenLevel(10)
    Eq(page.state, "entries", "the page draws")
    local plate = page.plates[1]
    Eq(plate.hunt, nil, "the plate's one takes no custom card")
    Eq(page.customHuntsWritten, 2, "a slow hunt's card each")
    Eq(page.huntsWritten, 0, "no detected card beside them")
    local items = {}
    for _, card in ipairs(Shown("huntPool")) do items[card.hunt.item] = card end
    Check(items["Wooden Spoon"] and items["Marsh Haunch"], "both in the margin")
    Eq(items["Wooden Spoon"].iconFile, Hunts.HuntCard.SACK, "the typed item in the sack")
    Eq(items["Marsh Haunch"].iconFile, 134169, "the edited one keeps its icon")
    Check(items["Wooden Spoon"].onRight, "a right click opens the form")
    Check(not Caption():find("Spoon", 1, true) and not Caption():find("slow hunt", 1, true),
        "the cards say their own words, not the caption: " .. Caption())
    Custom.Remove(typed)
    Custom.Reset(slow)

    j.hunts = { quick }
    Custom.Edit("fortune", quick, { kills = 1 })
    local lucky = Custom.Insert("fortune", { item = "Golden Spoon", kills = 3, need = 1, expected = 30 }, WHERE)
    OpenLevel(10)
    plate = page.plates[1]
    Eq(plate.lucky, nil, "the plate's one takes no custom lucky card")
    Eq(page.customLuckyWritten, 2, "a lucky card each")
    Eq(page.luckyWritten, 0, "no detected card beside them")
    local cards = {}
    for _, card in ipairs(Shown("luckyPool")) do cards[card.hunt.item] = card end
    Check(cards["Golden Spoon"] and cards["Marsh Beak"], "both lucky ones in the margin")
    Check(cards["Golden Spoon"].onRight, "a right click opens the form")
    Check(not Caption():find("Spoon", 1, true) and not Caption():find("lucky hunt", 1, true),
        "the words leave them to their cards: " .. Caption())
    Custom.Remove(lucky)
    Custom.Reset(quick)

    -- Where the margin runs out, the bad-luck slot comes before the good: 7, 8.
    local h = Custom.Insert("luck", { item = "Slot Spoon", kills = 33, need = 3 }, WHERE)
    local g = Custom.Insert("fortune", { item = "Slot Egg", kills = 3, need = 1, expected = 30 }, WHERE)
    OpenLevel(10)
    local at = {}
    for i, it in ipairs(page.plates[1].margin or {}) do at[it.kind] = at[it.kind] or i end
    Check(at.huntCustom and (not at.luckyCustom or at.huntCustom < at.luckyCustom), "bad luck's card first")
    Custom.Remove(h)
    Custom.Remove(g)

    j.hunts = { slow, quick }
    local typed2 = Custom.Insert("luck", { item = "Wooden Spoon", kills = 33, need = 3, name = "Old Tom" }, WHERE)

    -- A plate's detected card keeps its place beside the player's.
    local plain = Slow(t0 + 1300)
    plain.item = "Marsh Hide"
    j.hunts[#j.hunts + 1] = plain
    table.sort(j.hunts, function(a, b) return a.t < b.t end)
    OpenLevel(10)
    Eq(page.plates[1].hunt.hunt, plain, "the detected one is still the plate's one")
    Eq(page.huntsWritten, 1, "and has its card")
    for i, h in ipairs(j.hunts) do
        if h == plain then table.remove(j.hunts, i) end
    end

    -- With no item there is nothing to head a card: the mark and words tell it.
    Custom.Remove(typed2)
    local noItem = Custom.Insert("luck", { kills = 33, need = 3 }, WHERE)
    OpenLevel(10)
    Eq(page.customHuntsWritten, 0, "no item, nothing to head a card with")
    Eq(page.plates[1].counts.hunts >= 1, true, "its tally is there")
    Check(Caption():find("drops", 1, true), "and the words tell it: " .. Caption())
    Custom.Remove(noItem)

    -- The picker, as a player reaches it: each kind's card, with its own mark
    -- drawn with no `arg`, and the form its heading names.
    j.hunts = { Slow() }
    OpenLevel(10)
    plate = page.plates[1]
    local w = plate.window
    plate.sheet.GetCenter = function() return 500, 400 end
    local px, py = plate:OnPage(w[1] * 0.3 + w[3] * 0.7, w[2] * 0.3 + w[4] * 0.7)
    mock.pointer = { 500 + px - (plate.slot.x + plate.slot.w / 2), 400 + plate.slot.y + plate.slot.h / 2 - py }
    mock.contextMenu = nil
    plate.clip.scripts.OnMouseUp(plate.clip, "RightButton")
    Check(mock.MenuClick("Add custom event..."), "offered")
    local Sheet = ns.UI.YourDiary.CardSheet
    local view, found = Sheet.View(), {}
    for _, row in ipairs(view.list.rows) do
        if row.item then
            for _, cell in ipairs(row.cells) do
                if cell.kind then found[cell.kind] = cell end
            end
        end
    end
    for kind, title in pairs({ luck = "Bad Luck", fortune = "Good Luck" }) do
        local cell = found[kind]
        Check(cell ~= nil, title .. " is on the picker")
        Eq(cell.title:GetText(), title, "its title")
        Eq(cell.eyebrow:GetText(), "QUESTS AND LORE", "its type")
        Check(cell.kit.ink.used > 0, title .. "'s mark, from its own draw")
    end
    found.fortune.strip.link.scripts.OnClick(found.fortune.strip.link)
    Eq(view.title:GetText(), "A lucky hunt", "the form's heading")
    view.cancel.scripts.OnClick(view.cancel)
end

--------------------------------------------------------------------------
Section("a card that stays laid out, whatever was typed")

do
    j.hunts = {}
    local Laid = {
        { item = "Spoon", kills = 3, need = 5, expected = 40 },  -- far under what it expected, on a bad-luck card
        { item = "Spoon", kills = 3, need = 5 },                 -- no rates, under the character's usual
        { item = "A Very Long Spoon Of The Southern Barrens Indeed", kills = 999, need = 99, expected = 1 },
        { item = "Spoon", kills = 1, need = 99 },
        { item = "Spoon" },
    }
    for i, fields in ipairs(Laid) do
        local rec = Custom.Insert("luck", fields, WHERE)
        local rec2 = Custom.Insert("fortune", fields, WHERE)
        Custom.Edit("luck", rec, { expected = fields.expected or "" })
        Custom.Edit("fortune", rec2, { expected = fields.expected or "" })
        local ok, err = pcall(OpenLevel, 10)
        Check(ok, "typed values " .. i .. " draw: " .. tostring(err))
        Eq(page.customHuntsWritten, 1, "its bad-luck card " .. i)
        Custom.Remove(rec)
        Custom.Remove(rec2)
    end
end

--------------------------------------------------------------------------
Section("S on a light plate's print is the custom card's card")

do
    local A = F.GUID and F.GUID(1) or "Player-1-0000AAAA"
    ns.Characters.Observe(A, { first = "Bram", surname = "Redfen", level = 11, faction = "Horde" })
    ns.Diary.Add(A, { source = "test" })
    local t5 = now - 50000
    local function Road()
        ns.db.journey[SELF.guid] = nil
        j = J.Begin(SELF.guid, t5, 12, 1412)
        j.hunts = {}
        Seg({ kind = "stop", from = t5, to = t5 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 30, seconds = 1800,
            levelFrom = 12, levelTo = 12 })
        ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t5 + 600, endedAt = t5 + 1500,
            participants = { [A] = { since = t5 + 600, last = t5 + 1500, seconds = 900, levelStart = 12 } } })
        Seg({ kind = "flight", from = t5 + 1800, to = t5 + 2100, mapID1 = 1412, x1 = 0.5, y1 = 0.5, mapID2 = 2665,
            x2 = 0.5, y2 = 0.5, levelFrom = 12, levelTo = 12 })
        Seg({ kind = "stop", from = t5 + 2100, to = t5 + 3900, mapID = 2665, x = 0.5, y = 0.5, r = 30, seconds = 1800,
            levelFrom = 12, levelTo = 12 })
        J.Touch()
    end
    local ISLE = { mapID = 2665, x = 0.5, y = 0.5, from = t5 + 2100, to = t5 + 3900 }

    Road()
    local one = Custom.Insert("fortune", { item = "Isle Egg", need = 2, kills = 2, expected = 20, name = "Isle Raptor" }, ISLE)
    local e = OpenLevel(12)
    Eq(page.pattern, "FL", "the tucked print given up for S, as for a detected one")
    local onPrint = page.plates[2]
    Check(onPrint.slot.light, "a light plate")
    Check(onPrint.print, "S is on the print")
    Eq(onPrint.print.hunt.customOf, one, "and tells the player's card")
    Eq(#Shown("luckyPool"), 0, "so no card beside it")
    Eq(page.luckyWritten, 1, "S counts as its card")
    Eq(page.customLuckyWritten, 0, "and not as a margin's")
    Check(page.captionPool[2]:GetText():find("Isle Egg", 1, true), "the words name it: " .. tostring(page.captionPool[2]:GetText()))
    Check(not page.captionPool[2]:GetText():find("lucky", 1, true), "and no more")

    -- A right click on S opens its form, not the map's menu.
    local spot
    local onRight = onPrint.onRight
    onPrint.onRight = function(_, s) spot = s end
    for _, button in ipairs({ onPrint.printHit, onPrint.printItem }) do
        spot = nil
        button.scripts.OnMouseUp(button, "RightButton")
        Eq(spot and spot.kind, "fortune", "its kind")
        Eq(spot and spot.list[1].hunt, onPrint.print.hunt, "its hunt")
    end
    onPrint.onRight = onRight

    -- Its form, with no figure: the print strikes the words instead.
    Custom.Edit("fortune", one, { expected = "" })
    OpenLevel(12)
    Check(page.plates[2].print, "S with no figure still goes")

    -- A second one has no print left: it goes in the margin under the caption.
    Road()
    local older = Custom.Insert("fortune", { item = "Old Egg", need = 1, kills = 2, expected = 20 }, ISLE)
    local newer = Custom.Insert("fortune", { item = "New Egg", need = 1, kills = 2, expected = 20 }, ISLE)
    older.t, newer.t = t5 + 2500, t5 + 3000
    table.sort(j.custom, function(a, b) return a.t < b.t end)
    OpenLevel(12)
    onPrint = page.plates[2]
    Eq(onPrint.print.hunt.customOf, newer, "the newest is on the print")
    -- Under FL's print there is no room for a card, so it is left to its mark,
    -- as the rule says of any left off, and its words come back. It is offered:
    -- with more room (a print's margin is a matter of the layout) it is laid.
    Eq(page.customLuckyWritten, #Shown("luckyPool"), "counted as laid")
    local offered = ns.UI.JourneyMargin.KINDS.luckyCustom.items(onPrint)
    Eq(#offered, 1, "the other is offered to the margin")
    Eq(offered[1].lucky.hunt.customOf, older, "the older")
    if #Shown("luckyPool") == 0 then
        Check(page.captionPool[2]:GetText():find("another lucky hunt", 1, true),
            "left off, the words count it: " .. tostring(page.captionPool[2]:GetText()))
    end

    -- Beside a detected one on the print, the player's is told.
    Road()
    local Detected = { t = t5 + 2600, mapID = 2665, x = 0.5, y = 0.5, level = 12, questID = 9, title = "Isle Eggs",
        item = "Isle Egg", need = 2, kills = 2, expected = 20, npcID = 7, name = "Isle Raptor" }
    j.hunts = { Detected }
    local mine = Custom.Insert("fortune", { item = "Mine Egg", need = 1, kills = 2, expected = 20 }, ISLE)
    OpenLevel(12)
    onPrint = page.plates[2]
    Eq(onPrint.print.hunt.customOf, mine, "the player's on the print")
    Eq(onPrint.lucky.hunt, Detected, "the detected one is still the plate's one")
    Check(page.captionPool[2]:GetText():find("another lucky hunt", 1, true), "and is counted in the words: "
        .. tostring(page.captionPool[2]:GetText()))
end
