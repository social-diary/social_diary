-- Custom cards: the find kind (.claude/features/custom-cards.md). A detected
-- first edited, hidden and reset; one inserted beside j.firsts, which capture
-- alone writes; a typed name with no link on the card's own fallbacks; and the
-- custom rank and right click, which only find the record through the moment's
-- `field`.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Firsts, Recap, J = ns.Custom, ns.Firsts, ns.JourneyRecap, ns.Journey
local FC = Firsts.Card

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local MAP = 1412
local t0 = now - 7200
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments, j.open = {}, nil
j.segments[1] = { kind = "stop", from = t0, to = t0 + 1200, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 1200,
    levelFrom = 10, levelTo = 10 }
j.segments[2] = { kind = "road", from = t0 + 1200, to = t0 + 2400, mapID = MAP, levelFrom = 10, levelTo = 10,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } }
j.segments[3] = { kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = MAP, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    levelFrom = 10, levelTo = 10 }
J.Touch()

local LINK = "|cff1eff00|Hitem:7001::::::::10:::::|h[Mossy Wrappings]|h|r"
local function Fresh()
    j.custom = nil
    j.firsts = {
        uncommon = { t = t0 + 300, mapID = MAP, x = 0.42, y = 0.58, level = 10, link = LINK, from = "loot" },
        shoulder = false,
    }
    J.Touch()
    return j.firsts.uncommon
end
local rec = Fresh()

local function Finds(a, b)
    local e = Recap.Gather(j, a or t0, b or now + 1, Recap.Context(ns.ownGUID, now))
    return e.finds, e
end
local WHERE = { mapID = MAP, x = 0.60, y = 0.45, from = t0, to = t0 + 5000 }

--------------------------------------------------------------------------
Section("an old-shaped route reads as it did")

do
    local finds, e = Finds()
    Eq(#finds, 1, "the false kind is not a first")
    Eq(finds[1].rec, rec, "a record with nothing custom is read as it is, no copy")
    Eq(finds[1].kind, "uncommon", "its kind is its key")
    Eq(#e.hidden, 0, "nothing hidden")
    Eq(j.custom, nil, "reading writes no list")
    Eq(rec.name, nil, "nor any field on the record")
    Eq(rec.what, nil, "...of either sort")
end

--------------------------------------------------------------------------
Section("what the kind offers")

do
    local spec = Custom.Spec("find")
    Eq(spec.label, "First Found", "the picker's title")
    Eq(spec.group, "other", "its type")
    Eq(Recap.MOMENTS.find.field, "find", "the core finds the record by this")
    Eq(#spec.fields, 2, "the item and which first: a giver is not offered")
    Eq(spec.fields[1].key, "name", "the item's name")
    Eq(spec.fields[1].type, "text", "as text")
    local what = spec.fields[2]
    Eq(table.concat(what.values, " "), "uncommon rare epic bag shoulder", "j.firsts' own keys")
    local words = {}
    for i, value in ipairs(what.values) do words[i] = what.names[value] end
    Eq(table.concat(words, " "), "Green Blue Purple Bag Shoulders", "each with a word")
    for _, kind in ipairs(Firsts.KINDS) do
        Check(what.names[kind], "every first can be chosen: " .. kind)
    end
end

--------------------------------------------------------------------------
Section("a detected first edited")

do
    Check(Custom.Edit("find", rec, { name = "Old Tom's Boots", what = "epic" }), "the edit")
    local f = Finds()[1]
    Eq(f.kind, "epic", "which first is read from the edit")
    Eq(f.rec.name, "Old Tom's Boots", "the name is read")
    Eq(f.rec.customOf, rec, "the copy knows its record")
    Eq(f.rec.link, nil, "a typed name lets the link go, on the copy")
    Eq(f.rec.from, "loot", "how it came stays")
    Eq(rec.link, LINK, "the detected link stays")
    Eq(rec.name, nil, "the detected record is not written on")
    Eq(j.firsts.epic, nil, "the first of its new kind is still to be found: capture is untouched")

    Custom.Reset(f.rec)
    Eq(rec.custom, nil, "Reset takes the changes off")
    Eq(Finds()[1].rec, rec, "exactly the detected card")

    Custom.Edit("find", rec, { what = "rare" })
    Eq(Finds()[1].rec.link, LINK, "only which first changed: the item is still the item")
    Eq(Finds()[1].kind, "rare", "...as another first")
    Custom.Reset(rec)

    Custom.Edit("find", rec, { name = "Mossy Wrappings" })
    Eq(Finds()[1].rec.link, LINK, "its own name typed out keeps the link")
    Custom.Reset(rec)

    Custom.Edit("find", rec, { name = "x", what = "nonsense" })
    Eq(Finds()[1].kind, "uncommon", "a first not on the list is no change")
    Custom.Reset(rec)
    Custom.Edit("find", rec, { name = "" })
    Eq(rec.custom, nil, "an empty line on a detected card is no change")
end

--------------------------------------------------------------------------
Section("a detected first hidden and brought back")

do
    Custom.Edit("find", rec, { name = "Old Tom's Boots" })
    Custom.Hide(Finds()[1].rec)
    local finds, e = Finds()
    Eq(#finds, 0, "off the page")
    Eq(#e.hidden, 1, "listed to bring back")
    Eq(e.hidden[1].kind, "find", "its kind")
    Eq(e.hidden[1].rec, rec, "its record")
    Eq(j.firsts.uncommon, rec, "kept")
    Eq(Custom.Spec("find").describe(Custom.Values(rec)), "Old Tom's Boots", "the menu's line, with the changes")
    Custom.Show(rec)
    Eq(Finds()[1].rec.name, "Old Tom's Boots", "back with its changes")
    Custom.Reset(rec)
    Eq(Custom.Spec("find").describe(Custom.Values(rec)), "Mossy Wrappings", "a detected one's line, from its link")
    Custom.Hide(rec)
    local _, outside = Finds(t0 + 1000, t0 + 2000)
    Eq(#outside.hidden, 0, "not listed on a page outside its time")
    Custom.Show(rec)
    Eq(rec.custom, nil, "hidden and shown leaves nothing behind")
end

--------------------------------------------------------------------------
Section("a first inserted")

local made
do
    local firsts = j.firsts
    local before = rec
    made = Custom.Insert("find", { name = "Young Tom's Hat", what = "rare" }, WHERE)
    Eq(j.custom[1], made, "on its own list")
    Eq(j.firsts, firsts, "j.firsts is the same table")
    Eq(j.firsts.rare, nil, "and has no blue")
    Eq(j.firsts.uncommon, before, "and its green as it was")
    Eq(made.link, nil, "no link")

    local finds = Finds()
    Eq(#finds, 2, "gathered with the detected")
    Eq(finds[1].rec, rec, "in time order")
    Eq(finds[2].kind, "rare", "wrapped as an entry, by which first")
    Eq(finds[2].rec.customOf, made, "knows its record")
    Eq(finds[2].rec.inserted, true, "and that it was inserted")
    Eq(#Finds(t0, t0 + 2000), 1, "not on a page outside its time")

    local second = Custom.Insert("find", { name = "Second Green", what = "uncommon" },
        { mapID = MAP, x = 0.41, y = 0.59, from = t0, to = t0 + 200 })
    finds = Finds()
    Eq(#finds, 3, "a second green is the player's decision")
    Eq(finds[1].rec.customOf, second, "sorted in by its time, through timeOf")
    Eq(j.firsts.uncommon, before, "the detected one stands")
    Custom.Remove(second)

    -- Capture goes on for a kind only the player has written.
    Eq(Firsts.Looking(j), true, "a blue is still looked for")
    local found = Firsts.Found(j, "rare", { t = t0 + 5, level = 10, link = LINK })
    Check(found, "the real first blue is still captured")
    Eq(#Finds(), 3, "beside the inserted one")
    j.firsts.rare = nil

    local plain = Custom.Insert("find", {}, WHERE)
    Eq(plain.what, "uncommon", "a new card starts as a green")
    Check(Custom.Edit("find", plain, { what = "" }), "the box unticked")
    Eq(plain.what, nil, "no first at all")
    local bare
    for _, f in ipairs(Finds()) do
        if f.rec.customOf == plain then bare = f end
    end
    Eq(bare.kind, "find", "the entry's fallback")
    Eq(Firsts.Heading(bare.kind), "Your first find!", "a heading that still reads")
    Eq(Custom.Spec("find").describe(Custom.Values(plain)), "A first found", "and a menu's line")
    Custom.Remove(plain)
end

--------------------------------------------------------------------------
Section("custom firsts outrank everything")

do
    local function M(rec) return { kind = "find", what = "uncommon", t = t0, find = rec } end
    Eq(Recap.Rank(M({ t = t0 })), 2, "a detected first's own rank")
    Eq(Recap.Rank(M({ t = t0, customOf = {} })), 0.5, "a custom one's")
    Eq(Recap.Rank({ kind = "find", t = t0, gift = true, find = { t = t0 } }), Recap.RANK.session, "a gift ranks as before")
    Eq(Recap.Rank({ kind = "find", t = t0, gift = true, find = { t = t0, customOf = {} } }), 0.5, "a custom gift outranks that")
end

--------------------------------------------------------------------------
Section("the words, with a typed name")

do
    local typed = { t = t0, mapID = MAP, name = "Young Tom's Hat", customOf = {} }
    Check(Firsts.Sentence("rare", typed):find(": Young Tom's Hat.", 1, true), "the prose names it")
    local title, line = Firsts.Tip({ what = "rare", find = typed }, now)
    Eq(title, "Your first blue", "the tooltip's heading")
    Check(line:find("^Young Tom's Hat, found"), "the tooltip's line")
    Eq(Firsts.Name({ link = LINK }), "Mossy Wrappings", "a link's name")
    Eq(Firsts.Name({ link = LINK, name = "Typed" }), "Typed", "a typed name first")
    Eq(Firsts.Name({}), nil, "neither")
    Eq(Firsts.Name(nil), nil, "nothing")
    local words = Firsts.Lines({ finds = { { kind = "rare", rec = typed } } })
    Check(words:find("Young Tom's Hat", 1, true), "the level's paragraph")
end

--------------------------------------------------------------------------
Section("the cards: one each, past what joins the rest")

do
    local function Moment(what, rec) return { kind = "find", what = what, t = rec.t, find = rec } end
    local a = { t = 1, link = LINK }
    local b = { t = 1, link = LINK }
    local mine = { t = 2, link = LINK, customOf = {} }
    local older = { t = 1, name = "Older", customOf = {} }
    local empty = { t = 3, customOf = {} }
    local plate = { findMarks = {
        { at = { 10, 20 }, list = { Moment("bag", a), Moment("uncommon", b), Moment("rare", mine) } },
        { at = { 30, 40 }, list = { Moment("epic", older), Moment("uncommon", empty) } },
    } }
    local items = FC.Items(plate)
    Eq(#items, 1, "the detected green bag is still one card")
    Eq(#items[1].whats, 2, "of two firsts")
    local customs = FC.Customs(plate)
    Eq(#customs, 2, "a card each, not joined by a shared link")
    Eq(customs[1].rec, mine, "the newest first")
    Eq(customs[2].rec, older, "then the older")
    Eq(customs[1].mark[2], 20, "its leader goes to its pouch")
    Eq(customs[1].whats[1], "rare", "which first it is")
    Eq(FC.Quality(nil, { "epic" }), 4, "a typed name's ink comes of which first it is")
    Eq(FC.Quality(nil, { "bag" }), 1, "a bag's is plain")
    Eq(FC.Icon(nil), nil, "no link, no icon")
end

--------------------------------------------------------------------------
Section("what the margin tells the words")

do
    local M = ns.UI.JourneyMargin.KINDS
    Eq(M.findCustom.order, 6, "the order on the contract")
    Check(M.findCustom.order < M.find.order and M.findCustom.order < ns.UI.JourneyMargin.PEOPLE.close,
        "before the people, so the last left off")
    Eq(M.findCustom.pool, M.find.pool, "the same card's pool")

    -- Both kinds fill one word, asked in the margin's order.
    local mine, other = { t = 1 }, { t = 2 }
    local said = {}
    M.findCustom.say(said, { { item = { moments = { { find = mine } } } } })
    M.find.say(said, { { item = { moments = { { find = other } } } } })
    Check(said.find[mine], "the custom card's stays told")
    Check(said.find[other], "beside the detected card's")
    said = {}
    M.findCustom.say(said, {})
    M.find.say(said, {})
    Eq(next(said.find), nil, "neither shown: the words have the item")
end

--------------------------------------------------------------------------
Section("on the page, a custom first is a first like any other")

do
    ns.UI.ShowJournal()
    ns.UI.SetJournalView("journey")
    local page = ns.UI.JourneyPage()
    local CardSheet = ns.UI.YourDiary.CardSheet
    j.levels[11] = { at = t0 + 4000, mapID = MAP, x = 0.60, y = 0.45 }
    J.Touch()
    Custom.Edit("find", rec, { what = "rare" })
    ns.UI.RefreshJourneyPage(true)
    Eq(page.state, "entries", "the page draws")
    local open
    for i, entry in ipairs(page.recap.entries) do
        if entry.level == 10 then open = i end
    end
    T.OpenDiaryPage(page, open)

    Eq(page.customFindsWritten, 2, "a card each, the edited and the inserted")
    Eq(page.findsWritten, 0, "none left to the detected kind")
    local byName, typedCard = {}, nil
    for i = 1, page.findPool.used do
        local card = page.findPool[i]
        if card:IsShown() then
            byName[card.itemName] = card
            if card.found.rec.inserted then typedCard = card end
        end
    end
    Check(byName["Mossy Wrappings"], "the edited card keeps its link's name")
    Check(byName["Young Tom's Hat"], "the inserted card shows the typed name")
    Eq(typedCard.iconFile, nil, "with no icon")
    Eq(typedCard.quality, 3, "in a blue's ink")
    Eq(typedCard.chip.icon, 0, "laid with the box's name alone")
    Eq(typedCard.overfull, false, "and it fits")
    Check(typedCard.chip.lines[1] ~= nil, "the name's on the box")

    -- The box's tooltip, which has no link to show.
    local said
    local SetText = GameTooltip.SetText
    GameTooltip.SetText = function(_, text) said = text end
    FC.ShowTip(typedCard.item, typedCard.found, now)
    GameTooltip.SetText = SetText
    Eq(said, "Young Tom's Hat", "the box's tooltip says the typed name, having no link")

    -- A right click, on the card and on its pouch, opens this record's form.
    local function Rights(card)
        local before = CardSheet.Edit
        local kind, opened
        CardSheet.Edit = function(k, r) kind, opened = k, r end
        card.onRight()
        CardSheet.Edit = before
        return kind, opened
    end
    local kind, opened = Rights(typedCard)
    Eq(kind, "find", "the card's right click asks for this kind")
    Eq(opened.customOf, made, "and this card")

    local plate = page.plates[1]
    local pouch
    for i = 1, plate.hover.used do
        local b = plate.hover[i]
        if b.spot and b.spot.kind == "find" and b.spot.list[1].find.customOf == made then pouch = b end
    end
    Check(pouch, "its pouch is drawn")
    CardSheet.Right(plate, pouch.spot)
    local view = CardSheet.View()
    Eq(view.kind, "find", "the pouch's right click opens the form")
    Eq(view.rec.customOf, made, "on this card")
    Eq(view.rows[1]:Get(), "Young Tom's Hat", "with the name typed")
    Eq(view.rows[2]:Get(), "rare", "and the first ticked")
    view:Hide()

    -- The caption does not name what the card shows, and with no card it does.
    local Text = ns.UI.JourneyText
    local words = {}
    for i = 1, page.captionPool.used do words[#words + 1] = page.captionPool[i]:GetText() or "" end
    words = table.concat(words, " ")
    Check(words:find("first blue", 1, true), "the words tell a first: " .. words)
    Check(not words:find("Young Tom", 1, true), "and leave its name to the card: " .. words)
    local moment = pouch.spot.list[1]
    local alone = { moments = { moment }, mapID = MAP, t = moment.t }
    local left = Text.PlateCaption(alone, nil, { named = {}, find = {} })
    Check(left:find("Young Tom's Hat", 1, true), "left off, the words name it: " .. left)
    Custom.Reset(rec)
end

--------------------------------------------------------------------------
Section("the picker draws its pouch with no arg")

do
    local mark = ns.UI.JourneyPlate.MARKS and ns.UI.JourneyPlate.MARKS.find
    if mark then
        local drew = 0
        local kit = setmetatable({ INK_STRONG = ns.Style.INK_STRONG }, { __index = function() return function() drew = drew + 1 end end })
        kit.ink = { Next = function() return {} end }
        kit.inner = { Next = function() return {} end }
        kit.P = { 1, 1, 1 }
        kit.Light = function() return 1 end
        kit.Quad = function() return false end
        mark.draw(kit, 0, 0)
        Check(drew > 0, "the pouch is drawn in plain ink")
    end
end
