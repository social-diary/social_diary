-- Custom cards: the free card, `noteCard` (.claude/features/note-card.md), and
-- the field types it brought into the base (people, item, icon, flag, a text
-- of several lines). "Someone you met" folded into it: its tests are here.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Recap, J, Note = ns.Custom, ns.JourneyRecap, ns.Journey, ns.Note
local Text = ns.UI.JourneyText
local KIND = "noteCard"

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
local MAP = 1412
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = { { kind = "stop", from = t0, to = t0 + 3000, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 3000,
    levelFrom = 10, levelTo = 10 } }
j.open = nil
j.levels[11] = { at = t0 + 3500, mapID = MAP, x = 0.40, y = 0.60 }
J.Touch()

local GUID = "Player-1-0AAAAAAA"
ns.db.characters[GUID] = { guid = GUID, names = { { first = "Brannoc", surname = "" } } }
ns.db.diary[GUID] = { tags = {}, addedAt = now }
local OTHER = "Player-1-0CCCCCCC"
ns.db.characters[OTHER] = { guid = OTHER, names = { { first = "Wenna", surname = "" } } }
ns.db.diary[OTHER] = { tags = {}, addedAt = now }
local STRANGER = "Player-1-0DDDDDDD"
ns.db.characters[STRANGER] = { guid = STRANGER, names = { { first = "Pell", surname = "" } } }

local WHERE = { mapID = MAP, x = 0.42, y = 0.58, from = t0, to = t0 + 3000 }

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

--------------------------------------------------------------------------
Section("the kind opts in, and only ever by hand")

do
    local spec = Custom.Spec(KIND)
    Check(spec ~= nil, "the free card is a custom kind")
    Eq(spec.label, "Note", "the picker's title")
    Eq(spec.group, "other", "its type")
    local types = {}
    for _, field in ipairs(spec.fields) do types[field.key] = field end
    Eq(types.icon.type, "icon", "an icon")
    Eq(types.text.type, "text", "a text")
    Check(types.text.most > Custom.TEXT_MOST and (types.text.lines or 1) > 1, "longer than a line, on several")
    Eq(types.people.type, "people", "a list of people")
    Eq(types.mob.optional, true, "the mob behind a \"+ Add\"")
    Eq(types.item.type, "item", "an item")
    Eq(types.item.optional, true, "behind a \"+ Add\" too")
    Eq(types.caption.type, "flag", "the caption, a flag")
    Eq(types.caption.label, "Write it into the entry", "its words: what it does now")
    Eq(spec.creature, "mob", "the mob is a creature")
    Eq(Custom.Spec("met"), nil, "\"Someone you met\" left the picker")
    Eq(Recap.MOMENTS.met, nil, "and the moments")
    Eq(Recap.MOMENTS[KIND].order, 85, "its moment's order")
    Eq(ns.UI.JourneyPlate.MARKS[KIND].order, 36, "its mark's")
    Eq(ns.UI.JourneyMargin.KINDS[KIND].order, 2, "its place in the margin")
    Eq(Text.CAPTIONS[KIND].lead.at, 15, "its lead")
    Eq(Text.CAPTIONS[KIND].tail.at, 5, "its tail")
    Eq(Recap.RANK.note, 1, "a person's diary note keeps its own kind")

    local e = Recap.Gather(j, t0, now, Recap.Context(ns.ownGUID, now))
    Eq(#e.noteCard, 0, "nothing is ever detected")
    Eq(j.custom, nil, "and reading writes no list")
end

--------------------------------------------------------------------------
Section("the mark: the card's icon, and the first without a record")

do
    local Plate = ns.UI.JourneyPlate
    local kit = Plate.MarkKit(UIParent, function() end, function() end, { 1, 1, 1 })
    Check(ns.NoteIcons ~= nil, "the icons are loaded before the kind")
    local real, drawn = ns.NoteIcons.Draw, {}
    ns.NoteIcons.Draw = function(_, key, x, y) drawn[#drawn + 1] = { key = key, x = x, y = y } end
    Plate.MARKS[KIND].draw(kit, 10, 12)
    Eq(#drawn, 1, "the picker's: drawn without a record")
    Eq(drawn[1].key, nil, "the icons' own default")
    Plate.MARKS[KIND].draw(kit, 10, 12, nil, { icon = "tankard" })
    Eq(drawn[2].key, "tankard", "the chosen icon")
    Eq(drawn[2].x, 10, "where it is")
    ns.NoteIcons.Draw = real
    kit:Begin()
    Plate.MARKS[KIND].draw(kit, 10, 12, nil, { icon = "tankard" })
    Check(kit.ink.used + kit.inner.used > 0, "and the icons draw it")
    kit:Finish()
    local icons = ns.NoteIcons
    ns.NoteIcons = nil
    kit:Begin()
    Plate.MARKS[KIND].draw(kit, 10, 12)
    Eq(kit.ink.used, 1, "without the icons, the core's ring")
    kit:Finish()
    ns.NoteIcons = icons
end

--------------------------------------------------------------------------
Section("a card writes nothing but itself")

local typed
do
    local rows, sessions = Count(ns.db.interactions), Count(ns.db.sessions)
    local people, diary = Count(ns.db.characters), Count(ns.db.diary)
    local segments = #j.segments
    typed = Custom.Insert(KIND, { text = "fished off the pier", people = { { name = "Old Tom" } } }, WHERE)
    Eq(typed.kind, KIND, "its kind")
    Eq(typed.icon, ns.NoteIcons.KEYS[1], "the first icon, none chosen")
    Eq(typed.people[1].name, "Old Tom", "the name as written")
    Eq(typed.people[1].guid, nil, "no link")
    Eq(typed.text, "fished off the pier", "the text")
    Eq(typed.caption, nil, "not in the caption unless asked")
    Eq(typed.mob, nil, "no mob added")
    Eq(typed.item, nil, "no item added")
    Eq(j.custom[1], typed, "on the custom list")
    Eq(Count(ns.db.interactions), rows, "no People row")
    Eq(Count(ns.db.sessions), sessions, "no session")
    Eq(Count(ns.db.characters), people, "no character")
    Eq(Count(ns.db.diary), diary, "no diary entry")
    Eq(#j.segments, segments, "the route as it was")
    local e = Recap.Gather(j, t0, now, Recap.Context(ns.ownGUID, now))
    Eq(#e.noteCard, 1, "gathered")
    Eq(e.noteCard[1].customOf, typed, "knows its record")
    Eq(#Recap.Gather(j, t0 + 4000, now, Recap.Context(ns.ownGUID, now)).noteCard, 0, "not outside its time")
    Eq(Recap.Rank({ kind = KIND, noteCard = e.noteCard[1] }), 0.5, "above everything, as custom")
end

--------------------------------------------------------------------------
Section("the new fields, cleaned")

do
    local rec = Custom.Insert(KIND, {
        icon = "no such icon",
        text = "first line|cff00ff00 green|r\r\nsecond\tline\n\n\nthird\nfourth\nfifth",
        people = { { name = "Brannoc", guid = GUID }, { name = "Pell", guid = STRANGER }, { name = "  " },
            "Wenna", { name = "Brannoc", guid = GUID }, { name = "Old Tom" }, { name = "Fifth" } },
        caption = true,
    }, WHERE)
    Eq(rec.icon, ns.NoteIcons.KEYS[1], "an icon not among the keys is the first")
    Eq(rec.text, "first linecff00ff00 greenr\nsecond line\nthird fourth fifth",
        "no escape codes; three lines kept, the rest run on into the last")
    Eq(#rec.people, 4, "four people at most")
    Eq(rec.people[1].guid, GUID, "a diary entry is linked")
    Eq(rec.people[2].name, "Pell", "a stranger's name is kept")
    Eq(rec.people[2].guid, nil, "and not linked: only a diary entry")
    Eq(rec.people[3].name, "Wenna", "a plain name is a person too")
    Eq(rec.people[4].name, "Old Tom", "the nameless left out, one entry once")
    Eq(rec.caption, true, "in the caption when asked")
    Custom.Edit(KIND, rec, { caption = false, people = {}, icon = "tankard" })
    Eq(rec.caption, nil, "a flag off is absent")
    Eq(rec.people, nil, "an empty list is none")
    Eq(rec.icon, "tankard", "an icon among the keys")
    Custom.Edit(KIND, rec, { icon = "" })
    Eq(rec.icon, ns.NoteIcons.KEYS[1], "never without one")

    -- The mob: a creature's name, its picture where the records know it.
    Custom.Edit(KIND, rec, { mob = "Murloc Forager" })
    Eq(rec.mob, "Murloc Forager", "the mob as written")
    Eq(rec.npcID, nil, "an unknown creature has no id")

    -- The item: a link read for its name and ID, never kept.
    local link = "|cff1eff00|Hitem:2575:0:0:0:0:0:0:0:11|h[Red Linen Shirt]|h|r"
    Custom.Edit(KIND, rec, { item = link })
    Eq(rec.item, "Red Linen Shirt", "the name from the link")
    Eq(rec.itemID, 2575, "and its ID")
    Custom.Edit(KIND, rec, { item = "Thistle Sash", itemID = 1234 })
    Eq(rec.item, "Thistle Sash", "a name picked from the search")
    Eq(rec.itemID, 1234, "with its ID")
    Custom.Edit(KIND, rec, { item = "Thistle Sash", itemID = "x" })
    Eq(rec.itemID, nil, "an ID that is none goes")
    mock.itemInfo[4321] = { name = "Worn Dagger" }
    Custom.Edit(KIND, rec, { itemID = 4321 })
    Eq(rec.item, "Worn Dagger", "an ID alone takes the client's name")
    Custom.Edit(KIND, rec, { item = "", itemID = 4321 })
    Eq(rec.item, nil, "no name, no item")
    Eq(rec.itemID, nil, "and no ID")
    for key, value in pairs(rec) do
        Check(type(value) ~= "string" or not value:find("|", 1, true), "a `|` saved under " .. key)
    end
    Custom.Remove(rec)

    local long = Custom.Insert(KIND, { text = ("word "):rep(60) }, WHERE)
    Check(#long.text <= 150, "the text is held to its length")
    Custom.Remove(long)
end

--------------------------------------------------------------------------
Section("an item from a shift-click")

do
    local it = Custom.ItemOf("|cff0070dd|Hitem:6504:0:0:0:0:0:0:0:20|h[Wingblade]|h|r")
    Eq(it.itemID, 6504, "its ID")
    Eq(it.name, "Wingblade", "its name")
    Eq(Custom.ItemOf("|cff71d5ff|Hspell:133|h[Fireball]|h|r"), nil, "a spell is no item")
    Eq(Custom.ItemOf(nil), nil, "nothing is none")
    mock.itemInfo[777] = { name = "Cached Thing" }
    Eq(Custom.ItemOf("item:777").name, "Cached Thing", "a bare link takes the cache's name")
    Eq(Custom.ItemOf("item:778"), nil, "an item not known yet is none")
end

--------------------------------------------------------------------------
Section("the item search: the character's own")

do
    mock.bags[0] = { size = 16,
        [1] = { link = "|cff1eff00|Hitem:100:0:0:0:0:0:0:0:11|h[Thistle Sash]|h|r", quality = 2 },
        [2] = { link = "|cffffffff|Hitem:101:0:0:0:0:0:0:0:11|h[Linen Cloth]|h|r", quality = 1 },
        [3] = { link = "|cffffffff|Hitem:102:0:0:0:0:0:0:0:11|h[Sash of the Thistle]|h|r", quality = 1 },
    }
    mock.equipped[5] = { link = "|cff0070dd|Hitem:200:0:0:0:0:0:0:0:11|h[Thornmantle Robe]|h|r", quality = 3 }
    -- The diary's: a first found, an upgrade and what it replaced, a dungeon's loot.
    j.firsts = { uncommon = { t = t0, link = "|cff1eff00|Hitem:300:0:0:0:0:0:0:0:11|h[Sashimi Knife]|h|r" } }
    j.upgrades = { { t = t0, link = "|cff1eff00|Hitem:400:0:0:0:0:0:0:0:11|h[Thistlewood Bow]|h|r",
        was = { link = "|cffffffff|Hitem:401:0:0:0:0:0:0:0:11|h[Worn Shortbow]|h|r" } } }
    ns.db.instances.v1 = { me = ns.ownGUID, loot = {
        { guid = ns.ownGUID, item = "|cff0070dd|Hitem:500:0:0:0:0:0:0:0:11|h[Sash of Mine]|h|r", itemID = 500 },
        { guid = OTHER, item = "|cffa335ee|Hitem:501:0:0:0:0:0:0:0:11|h[Sash of Theirs]|h|r", itemID = 501 } } }
    mock.itemInfo[100] = { icon = 1001 }

    local found = Custom.FindItems("sash", 10)
    local names = {}
    for _, it in ipairs(found) do names[#names + 1] = it.name end
    Eq(table.concat(names, ", "), "Sash of Mine, Sashimi Knife, Sash of the Thistle, Thistle Sash",
        "the start of a name first, then a word's, the shorter first; nobody else's loot")
    local sash
    for _, it in ipairs(found) do if it.itemID == 100 then sash = it end end
    Eq(sash.quality, 2, "its quality")
    Eq(sash.icon, 1001, "its icon")
    Eq(found[1].quality, 3, "a quality from the link where the client has none")

    found = Custom.FindItems("thsash", 10)
    Eq(found[1] and found[1].name, "Thistle Sash", "letters in order find it")
    found = Custom.FindItems("robe", 10)
    Eq(found[1] and found[1].itemID, 200, "what is worn")
    found = Custom.FindItems("shortbow", 10)
    Eq(found[1] and found[1].itemID, 401, "what an upgrade replaced")
    found = Custom.FindItems("thistlewood", 10)
    Eq(found[1] and found[1].itemID, 400, "an upgrade")
    Eq(#Custom.FindItems("sash", 2), 2, "`most` of them")
    Eq(#Custom.FindItems("   ", 5), 0, "nothing typed, nothing offered")
    Eq(#Custom.FindItems("zzzz", 5), 0, "nothing that does not match")
    for _, it in ipairs(Custom.FindItems("a", 50)) do
        Check(it.score == nil and it.link == nil, "only { itemID, name, icon, quality }")
    end

    -- An item known only by its ID, whose name the client does not have yet:
    -- left out, and asked for.
    j.firsts.rare = { t = t0, link = "item:600" }
    local before = mock.itemAsked[600] or 0
    Eq(#Custom.FindItems("600", 5), 0, "an uncached name is not offered")
    Check((mock.itemAsked[600] or 0) > before, "and is asked for, never waited on")
    mock.itemInfo[600] = { name = "Mossy Sash" }
    found = Custom.FindItems("mossy", 5)
    Eq(found[1] and found[1].name, "Mossy Sash", "found once the client knows it")

    mock.bags[0] = { size = 16 }
    mock.equipped[5] = nil
    j.firsts, j.upgrades = nil, nil
    ns.db.instances.v1 = nil
end

--------------------------------------------------------------------------
Section("the caption: only when asked")

do
    local linked = { t = t0, people = { { guid = GUID, name = "Brannoc" } }, caption = true }
    local name = { t = t0, people = { { name = "Old Tom" } }, caption = true }
    local quiet = { t = t0, people = { { name = "Old Tom" } } }
    local function Plated(...)
        local p = { mapID = MAP, moments = {} }
        for _, rec in ipairs({ ... }) do p.moments[#p.moments + 1] = { kind = KIND, t = rec.t, noteCard = rec } end
        return p
    end
    Check(not (Text.PlateCaption(Plated(quiet), nil, { named = {}, noteCard = {} }) or ""):find("Old Tom"),
        "a card not asked for is never in the caption")
    Eq(Text.PlateCaption(Plated(name), nil, { named = {}, noteCard = {} }), "With Old Tom.", "left off, a typed name is said")
    Eq(Text.PlateCaption(Plated(linked), nil, { named = {}, noteCard = {} }), "With Brannoc.", "and a linked one")
    Eq(Text.PlateCaption(Plated(name), nil, { named = {}, noteCard = { [name] = true } }), "In good company.",
        "on a strip, never named: the words an automatic strip's plate has")
    Eq(Text.PlateCaption(Plated(linked), nil, { named = { [GUID] = true }, noteCard = {} }), "In good company.",
        "nor where another strip names them")
    local meeting = { t = t0, icon = "meeting", caption = true }
    Eq(Text.PlateCaption(Plated(meeting), nil, { named = {}, noteCard = {} }), "With someone.",
        "a meeting with nobody named, as \"Someone you met\" said")
    local alone = { t = t0, icon = "mountain", text = "the falls at dusk", caption = true }
    Check(not (Text.PlateCaption(Plated(alone), nil, { named = {}, noteCard = { [alone] = true } }) or ""):find("company"),
        "a card naming nobody is no company")

    local s = { t = t0, guid = OTHER }
    local p = Plated(name)
    p.moments[2] = { kind = "session", t = t0, guid = OTHER, session = s }
    Eq(Text.PlateCaption(p, nil, { named = {}, noteCard = {} }), "With Wenna, and with Old Tom.",
        "after the people's lead, first in the tail")
    p = Plated(linked)
    p.moments[2] = { kind = "session", t = t0, guid = GUID, session = s }
    Eq(Text.PlateCaption(p, nil, { named = {}, noteCard = {} }), "With Brannoc.", "never twice")

    -- What the margin tells the words.
    local spec = ns.UI.JourneyMargin.KINDS[KIND]
    local said = { named = {} }
    spec.say(said, { { rec = linked } }, {})
    Eq(said.named[GUID], true, "its strip names them")
    Eq(said.noteCard[linked], true, "and the card is told")
    said = { named = {} }
    spec.assume(said, { noteCardMarks = { { at = { 1, 2 }, list = { { noteCard = name } } } } })
    Eq(said.noteCard[name], true, "taken as shown until it is left off, typed or not")
end

--------------------------------------------------------------------------
Section("the entry: a card asked for is written into the level's words")

do
    local function Lines(...)
        return Note.Lines({ noteCard = { ... } })
    end
    local both = { t = t0, mapID = MAP, people = { { guid = GUID, name = "Brannoc" }, { name = "Old Tom" } },
        text = "Fished off the pier till dark.", caption = true }
    Eq(Lines(both), "With Brannoc and Old Tom in Mulgore: \226\128\156Fished off the pier till dark.\226\128\157",
        "who was there, where, and the player's words as written")
    Eq(Lines({ t = t0, mapID = MAP, people = { { name = "Old Tom" } }, text = "fished off the pier", caption = true }),
        "With Old Tom in Mulgore: \226\128\156fished off the pier\226\128\157.",
        "words without a stop as written, the sentence's stop after the quotes")
    Eq(Lines({ t = t0, mapID = MAP, people = { { name = "Old Tom" }, { name = "Wenna" } }, caption = true }),
        "With Old Tom and Wenna in Mulgore.", "people only")
    Eq(Lines({ t = t0, mapID = MAP, icon = "mountain", text = "The falls at dusk.", caption = true }),
        "Noted in Mulgore: \226\128\156The falls at dusk.\226\128\157", "words only")
    Eq(Lines({ t = t0, mapID = MAP, icon = "paw", mob = "Kobold Miner", item = "Linen Cloth", caption = true }),
        "Noted a Kobold Miner and Linen Cloth in Mulgore.", "neither: the creature and the item")
    Eq(Lines({ t = t0, mapID = MAP, people = { { name = "Old Tom" } }, mob = "Kobold Miner", caption = true }),
        "With Old Tom in Mulgore.", "with people, the card's creature is left to the card")
    Eq(Lines({ t = t0, mapID = MAP, icon = "quill", caption = true }), nil, "a card with nothing to tell says nothing")
    Eq(Lines({ t = t0, mapID = MAP, icon = "quill", people = {}, text = "", caption = true }), nil, "nor an emptied one")
    Eq(Lines({ t = t0, mapID = MAP, icon = "meeting", caption = true }), "With someone in Mulgore.",
        "a meeting with nobody named, as \"Someone you met\" said")
    Eq(Lines({ t = t0, mapID = MAP, icon = "meeting", text = "fished off the pier", caption = true }),
        "With someone in Mulgore: \226\128\156fished off the pier\226\128\157.", "and with its line")
    Eq(Lines({ t = t0, mapID = MAP, people = { { name = "Old Tom" } }, text = "fished" }), nil,
        "not asked for: nothing on the left page")
    Eq(Lines({ t = t0, people = { { name = "Old Tom" } }, text = "fished", caption = true }),
        "With Old Tom: \226\128\156fished\226\128\157.", "nowhere known, no place")
    Eq(Lines({ t = t0, mapID = MAP, text = "a |cffff0000red|r line", caption = true }),
        "Noted in Mulgore: \226\128\156a red line\226\128\157.", "the client's escapes never on the page")
    Eq(Lines({ t = t0, mapID = MAP, people = { { name = "Wenna" } }, caption = true },
            { t = t0 + 10, mapID = MAP, people = { { name = "Old Tom" } }, caption = false },
            { t = t0 + 20, mapID = 1413, text = "Rain.", caption = true }),
        "With Wenna in Mulgore. Noted in The Barrens: \226\128\156Rain.\226\128\157",
        "several, each told in their order; one not asked for left out")

    -- The entry as the page reads it: gathered, in its place among the lines.
    local before = j.custom
    j.custom = {
        { kind = KIND, t = t0 + 100, mapID = MAP, x = 0.4, y = 0.6, level = 10, icon = "meeting",
            people = { { name = "Brannoc", guid = GUID } }, text = "Helped me with the kobolds.", caption = true },
        { kind = KIND, t = t0 + 200, mapID = MAP, x = 0.4, y = 0.6, level = 10, icon = "quill",
            people = { { name = "Old Tom" } }, text = "Owes me a fish." },
        { kind = KIND, t = t0 + 300, mapID = MAP, x = 0.4, y = 0.6, level = 10, icon = "mountain", caption = true },
    }
    local e = Recap.Gather(j, t0, t0 + 3500, Recap.Context(ns.ownGUID, now))
    local all = table.concat(Text.Lines(e, now, {}), "\n")
    Check(all:find("With Brannoc in Mulgore: \226\128\156Helped me with the kobolds.\226\128\157", 1, true) ~= nil,
        "the entry's lines tell the card: its words and who was there")
    Check(not all:find("Owes me a fish", 1, true) and not all:find("Old Tom", 1, true),
        "a card not asked for is not on the left page")
    local guids = Text.LinkedGuids(e)
    Eq(#guids, 1, "one linked person for the page to link")
    Eq(guids[1], GUID, "the card's")
    local at
    for i, p in ipairs(Text.Paragraphs()) do if p.key == KIND then at = i end end
    Eq(Text.Paragraphs()[at].at, 35, "after the people, before the finds")

    -- The plate's caption keeps its own words: never the card's quote, and
    -- each name once.
    local p = { mapID = MAP, moments = {} }
    for _, rec in ipairs(e.noteCard) do p.moments[#p.moments + 1] = { kind = KIND, t = rec.t, noteCard = rec } end
    local caption = Text.PlateCaption(p, nil, { named = {}, noteCard = {} }) or ""
    Check(not caption:find("kobolds", 1, true), "the caption never quotes the card")
    local _, n = caption:gsub("Brannoc", "")
    Eq(n, 1, "and names them once")
    Check(not caption:find("Owes", 1, true), "nor says one not asked for")

    -- A migrated meeting with nobody named.
    j.custom = { { kind = "met", t = t0 + 100, mapID = MAP, x = 0.4, y = 0.6, level = 10 } }
    local old = { schema = 5, journey = { a = { custom = j.custom } } }
    ns._test.Migrate(old, 6, ns._test.DiarySteps)
    e = Recap.Gather(j, t0, t0 + 3500, Recap.Context(ns.ownGUID, now))
    Check(table.concat(Text.Lines(e, now, {}), "\n"):find("With someone in Mulgore.", 1, true) ~= nil,
        "a folded \"Someone you met\" with nobody named reads \"with someone\"")
    j.custom = before
end

--------------------------------------------------------------------------
Section("the mark's tooltip: every card on its spot, one account")

do
    local spec = ns.UI.JourneyPlate.MARKS[KIND]
    local function M(rec) return { kind = KIND, t = rec.t, noteCard = rec } end
    local function Clock(t) return date("%H:%M", t) end
    local tom = { t = now - 900, people = { { name = "Old Tom" } }, text = "fished off the pier", level = 10 }
    local title, lines = spec.tips({ M(tom) }, now)
    Eq(title, "With Old Tom", "a lone card: who")
    Eq(lines[1], "fished off the pier", "a lone card: what")
    Eq(lines[2], "Today at " .. Clock(tom.t) .. ", level 10", "a lone card: when, and the level")
    Eq(#lines, 2, "a lone card: nothing doubled")
    title, lines = Note.Tip({ t = now - 900, people = { { name = "Old Tom" } }, text = "" }, now)
    Eq(#lines, 1, "an empty text is no line")
    title = Note.Tip({ t = now - 900, mob = "Murloc Forager", text = "ran" }, now)
    Eq(title, "Murloc Forager", "no one named: the creature")
    title = Note.Tip({ t = now - 900 }, now)
    Eq(title, "A note", "nothing at all")
    title, lines = Note.Tip({ t = now - 900, icon = "chest", text = "behind the falls" }, now)
    Eq(title, "Treasure", "no one named, no creature: the icon's name")
    Eq(lines[1], "behind the falls", "and the words under it, not in the title too")
    -- A meeting with nobody named reads as "Someone you met" did.
    local nobody = { t = now - 900, icon = "meeting", text = "helped with the Nagas" }
    Eq(Note.Tip(nobody, now), "With someone", "a meeting, nobody named: with someone")
    Eq(Note.Who(nobody), "with someone", "its strip's line")
    Eq(Note.Label(nobody), "Someone you met", "its row on the ticklist")
    Eq(Note.Describe(nobody), "Someone you met, helped with the Nagas", "its menu line")
    Eq(Note.Label({ icon = "boot" }), "On the road", "an empty card: the icon's name")

    local again = { t = now - 300, people = { { name = "Old Tom" } }, text = "fished off the pier", level = 11 }
    title, lines = spec.tips({ M(tom), M(again) }, now)
    Eq(title, "With Old Tom", "twice: the name once")
    Eq(lines[1], "fished off the pier", "twice: the line once")
    Eq(lines[2], "Today at " .. Clock(tom.t) .. " and " .. Clock(again.t) .. ", levels 10 to 11",
        "twice: both times, the levels spanned")
end

--------------------------------------------------------------------------
Section("on the page, the free card")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YourDiary = ns.UI.YourDiary
local FREE = Note.Card.FREE

local function Open()
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, e in ipairs(page.recap.entries) do
        if e.level == 10 then T.OpenDiaryPage(page, i) end
    end
end
-- The free card on the page whose heading is `name` (any, where nil).
local function Card(name)
    for i = 1, page.killerPool.used do
        local card = page.killerPool[i]
        if card:IsShown() and card.freeRec and (not name or card.name:GetText() == name) then return card end
    end
end
local function Words()
    local all = {}
    for i = 1, page.captionPool.used do all[#all + 1] = page.captionPool[i]:GetText() or "" end
    return table.concat(all, " ")
end

do
    Open()
    Eq(page.state, "entries", "the page draws")
    Eq(page.noteCardsWritten, 1, "its card is counted")
    Eq(page.notesWritten, 0, "and is no automatic person")
    local card = Card("with Old Tom")
    Check(card ~= nil, "the killer card's, worn with the free card's face, the name as written")
    Eq(card.face and card.face.key, KIND, "its face")
    Eq(card:Quote(), "\226\128\156fished off the pier\226\128\157", "the player's words, quoted in their hand")
    Eq(card.guid, nil, "no link")
    Eq(card.freeIcon and card.freeIcon.key, "quill", "the icon over the name, the default")
    Check(card.picture == nil, "no creature, no picture")
    Eq(card.mode, "name", "and no model")
    local plate = page.plates[1]
    Eq(plate.counts.noteCards, 1, "its mark")
    Eq(plate.margin[1].kind, KIND, "first in the margin")
    Check(not Words():find("Old Tom"), "the words do not name them again")
    local title, lines = Note.Tip(plate.noteCardMarks[1].list[1].noteCard, now)
    Eq(title, "With Old Tom", "the mark's tooltip says who")
    Eq(lines[1], "fished off the pier", "and what")
    local tip = card.tip()
    Eq(tip[1][1], "With Old Tom", "the card's tooltip, the mark's")
end

local linked
do
    linked = Custom.Insert(KIND, { people = { { name = "Brannoc", guid = GUID }, { name = "Wenna", guid = OTHER } },
        text = "" }, WHERE)
    Eq(linked.people[1].guid, GUID, "a picked name keeps its entry")
    Open()
    -- (the mock's hand, ~6 px a letter, has room for the first alone in
    -- this margin: everyone is in its tooltip)
    local card = Card("with Brannoc")
    Check(card ~= nil, "who was there, as many as the column holds")
    Eq(card.tip()[1][1], "With Brannoc and Wenna", "everyone in its tooltip")
    Eq(card.guid, GUID, "linked, to the first")
    Eq(card:Quote(), "", "an empty text is no quote")
    Eq(page.noteCardsWritten, 2, "a card each")
    -- Two linked: a click asks whose page, the mouse's menu.
    mock.contextMenu = nil
    local opened
    local real = YourDiary.ToPerson
    card.freeOpen = function(guid) opened = guid end
    card.link:GetScript("OnClick")(card.link)
    Check(mock.contextMenu ~= nil, "two linked: a menu of whose page")
    Check(mock.MenuClick("Wenna"), "with each of them")
    Eq(opened, OTHER, "and the one picked opens")
    YourDiary.ToPerson = real

    ns.db.characters[GUID].names = { { first = "Brannock", surname = "" } }
    Open()
    Check(Card("with Brannock") ~= nil, "their current name, not the one written")
    Eq(linked.people[1].name, "Brannoc", "which stays as it was")
    ns.db.characters[GUID].names = { { first = "Brannoc", surname = "" } }
end

--------------------------------------------------------------------------
Section("the card at every size, and what it gives up")

do
    local mob = Custom.Insert(KIND, { icon = "fish", people = { { name = "Old Tom" } },
        text = "he swore it was the biggest he had ever seen, and then it got away from him", mob = "Murloc Forager",
        item = "Thistle Sash", itemID = 100 }, WHERE)
    mob.display = 4242
    local deaths = ns.Deaths.Card
    local card = deaths.New(UIParent)
    local function Lay(width, room)
        card:SetNoteCard(mob, { 300, 200 }, "size-test", now, function() end)
        return card:Layout(0, 0, width, room)
    end
    local function Bits() return card.freeBits end
    -- XL: icon 30, the creature's picture, the item boxed, three lines.
    Lay(220)
    Eq(card.freeSize, "xl", "220: XL")
    Eq(card.freeIcon.size, FREE.icon.xl, "XL: the icon at its size")
    Eq(card.freeIcon.key, "fish", "the chosen icon")
    Check(card.picture ~= nil and card.picture.w == FREE.picture.xl.w, "XL: the creature's picture beside it")
    Check(card.mode ~= "name", "drawn by the killer card's ladder")
    Check(Bits().box.button:IsShown(), "XL: the item boxed under the name")
    Check(card.under ~= nil, "in the room under the name")
    Check(not card.overfull, "XL: it fits")
    Eq(card.name:GetText(), "with Old Tom", "the heading: who")
    -- L
    Lay(176)
    Eq(card.freeSize, "l", "176: L")
    Eq(card.freeIcon.size, FREE.icon.l, "L: the icon smaller")
    Check(card.picture ~= nil and card.picture.w == FREE.picture.l.w, "L: the picture smaller")
    -- M: no picture, two lines.
    Lay(142)
    Eq(card.freeSize, "m", "142: M")
    Eq(card.freeIcon.size, FREE.icon.m, "M: the icon smaller still")
    Eq(card.picture, nil, "M: no picture")
    Check(card.quoteLines <= FREE.lines.m, "M: two lines of words at most")
    Check(not card.overfull, "M: it fits")
    Lay(122)
    Check(not card.overfull, "122: it fits")
    -- Short of height: it gives up, a thing at a time, down to its heading.
    Lay(220)
    local gave, n = {}, 0
    while card:Smaller() and n < 20 do
        n = n + 1
        card:Layout(0, 0, 220)
        gave[#gave + 1] = table.concat({ card.picture and "pic" or "-", tostring(card.quoteLines or 0),
            Bits().box.button:IsShown() and "item" or "-", Bits().mob:IsShown() and "mob" or "-",
            card.freeIcon and "icon" or "-" }, ",")
    end
    Eq(gave[1], "-,3,item,mob,icon", "the picture first")
    Eq(gave[2], "-,2,item,mob,icon", "then the words to two lines")
    Eq(gave[3], "-,2,-,mob,icon", "then the item")
    Eq(gave[4], "-,1,-,mob,icon", "then the words to one")
    Eq(gave[5], "-,1,-,-,icon", "then the creature's name")
    Eq(gave[6], "-,1,-,-,-", "then the band (S)")
    Eq(gave[7], "-,0,-,-,-", "then the words: the heading alone")
    Eq(#gave, 7, "and then nothing left to give")
    Eq(card.name:GetText(), "with Old Tom", "the heading is kept")
    -- The creature as the heading: never said twice.
    local only = { t = now, icon = "skull", mob = "Murloc Forager", text = "watch the bridge" }
    card:SetNoteCard(only, { 300, 200 }, "mob-test", now, function() end)
    card:Layout(0, 0, 220)
    Eq(card.name:GetText(), "Murloc Forager", "nobody named: the creature heads it")
    Check(not Bits().mob:IsShown(), "and is not in the band again")
    -- Nothing but an icon: its name heads it.
    card:SetNoteCard({ t = now, icon = "chest", text = "behind the falls" }, nil, "icon-test", now, function() end)
    card:Layout(0, 0, 176)
    Eq(card.name:GetText(), ns.NoteIcons.NAMES.chest, "the icon's name heads it")
    card:SetNoteCard({ t = now, text = "behind the falls" }, nil, "quill-test", now, function() end)
    card:Layout(0, 0, 176)
    Eq(card.name:GetText(), "A note", "the quill's, \"A note\"")
    -- Worn by a killer after: nothing of the free card's left on it.
    card:SetKiller({ name = "Kobold Miner", count = 1, last = now }, "k", now)
    card:Layout(0, 0, 176)
    Eq(card.freeIcon, nil, "a killer's card has no icon")
    Check(not Bits().box.button:IsShown(), "nor the item")
    Custom.Remove(mob)
end

--------------------------------------------------------------------------
Section("the right click: the form")

local FACES_SIZE = YourDiary.CardSheet.FACES.size
local function Rows()
    local rows = {}
    for _, row in ipairs(YourDiary.CardSheet.View().rows) do rows[row.field.key] = row end
    return rows
end

do
    Open()
    local card = Card("with Old Tom")
    local link = card.link
    link.scripts.OnMouseUp(link, "RightButton")
    local view = YourDiary.CardSheet.View()
    Eq(view.kind, KIND, "a right click on its card opens its form")
    Eq(view.rec.customOf or view.rec, typed, "for its card")
    local rows = Rows()
    Eq(rows.text.box:GetText(), "fished off the pier", "the text in its lines")
    Check(rows.text.scroll:IsShown(), "on a ruled area of several")
    Eq(rows.icon:Get(), "quill", "the icon chosen")
    Eq(#rows.icon.cells, 16, "the sixteen in sight")
    Eq(#rows.people.people, 1, "one person on it")
    Check(rows.people.faces[1]:IsShown(), "as a face")
    Eq(rows.people.faces[1].name:GetText(), "Old Tom", "their name under it")
    Eq(rows.people.box:GetText(), "", "the line under the faces empty")
    Check(not rows.mob.box:IsShown() and rows.mob.add:IsShown(), "the mob behind its strip")
    Check(not rows.item.box:IsShown() and rows.item.add:IsShown(), "the item too")
    Check(not rows.caption.flag:GetChecked(), "the caption off")
    rows.text.box:SetText("fished all evening")
    view.save.scripts.OnClick(view.save)
    Eq(typed.text, "fished all evening", "saved")
    Eq(typed.people[1].name, "Old Tom", "the people as they were")
    Eq(typed.icon, ns.NoteIcons.KEYS[1], "the icon as it was")
    Eq(typed.mob, nil, "no mob written")
    typed.text = "fished off the pier"

    -- Off this page, then a page with nothing of the kind: none keeps the click.
    local saved = j.custom
    j.custom = nil
    Open()
    Eq(page.noteCardsWritten, 0, "none written")
    for i = 1, page.killerPool.used do
        local s = page.killerPool[i]
        Check(not s:IsShown() or s.freeRec == nil, "no card of the pool keeps it")
    end
    j.custom = saved
end

--------------------------------------------------------------------------
Section("the form: the builder's controls")

do
    local CardSheet = YourDiary.CardSheet
    local function Gathered(rec)
        local e = Recap.Gather(j, t0, now, Recap.Context(ns.ownGUID, now))
        for _, c in ipairs(e.noteCard) do
            if c.customOf == rec then return c end
        end
    end
    local function Edit(rec)
        CardSheet.Edit(KIND, Gathered(rec))
        return CardSheet.View(), Rows()
    end
    local function Save(view) view.save.scripts.OnClick(view.save) end
    local function Click(button) button:GetScript("OnClick")(button) end
    local function Type(box, text)
        box:SetFocus()
        box:SetText(text)
        box:GetScript("OnTextChanged")(box, true)
    end
    local rec = Custom.Insert(KIND, { text = "at the pier" }, WHERE)

    -- A clean builder: icon, text, people; the mob and the item behind strips.
    local view, rows = Edit(rec)
    Check(rows.icon.cells[1]:IsShown() and rows.text.scroll:IsShown() and rows.people.box:IsShown(),
        "icon, text and people on the form")
    Check(rows.mob.add:IsShown() and rows.item.add:IsShown(), "the mob and the item each a strip")
    Check(not rows.mob.box:IsShown() and not rows.mob.label:IsShown() and not rows.mob.off:IsShown(),
        "and nothing else of them")
    Eq(rows.mob.add.words:GetText(), "+ A creature", "the mob's strip says so")
    Eq(rows.item.add.words:GetText(), "+ An item", "and the item's")
    Eq(rows.mob.add.padAt[2], rows.item.add.padAt[2], "side by side, on one row")
    Check(rows.item.add.padAt[1] > rows.mob.add.padAt[1], "the mob's first")
    Check(rows.caption.flag:IsShown() and not rows.caption.label:IsShown(), "the caption a box with its words")
    Check(rows.caption.flag.padAt[2] > rows.mob.add.padAt[2], "under the strips")
    Eq(#rows.people.people, 0, "nobody on it yet")
    Check(not rows.people.faces[1] or not rows.people.faces[1]:IsShown(), "no faces: the line alone")
    local alone = rows.people.box.padAt[2]

    -- Nothing touched, nothing written.
    local before = j.version
    local edits = 0
    local real = Custom.Edit
    Custom.Edit = function(...) edits = edits + 1 return real(...) end
    Save(view)
    Eq(edits, 0, "saved untouched: no edit")
    Custom.Edit = real

    -- The icon: one click, the wash on it alone.
    view, rows = Edit(rec)
    Eq(rows.icon:Get(), "quill", "the quill, the card's own")
    Check(rows.icon.cells[1].chosen:IsShown(), "washed")
    local tankard
    for _, cell in ipairs(rows.icon.cells) do if cell.iconKey == "tankard" then tankard = cell end end
    Click(tankard)
    Check(tankard.chosen:IsShown() and not rows.icon.cells[1].chosen:IsShown(), "the wash moves with the choice")
    Save(view)
    Eq(rec.icon, "tankard", "the icon saved")

    -- The text, on several lines.
    view, rows = Edit(rec)
    rows.text.box:SetText("at the pier\nall evening")
    Save(view)
    Eq(rec.text, "at the pier\nall evening", "its lines kept")

    -- People: round faces, one line under them to search on and add the next.
    view, rows = Edit(rec)
    local people = rows.people
    local line = people.box
    Type(line, "Old Tom")
    line:GetScript("OnEnterPressed")(line)
    Check(view:IsShown(), "Enter with a name on the line does not save the card")
    Eq(#people.people, 1, "it adds them")
    Eq(line:GetText(), "", "and clears the line")
    Check(line:HasFocus(), "which keeps the cursor for the next")
    local tom = people.faces[1]
    Check(tom:IsShown(), "their face")
    Check(tom.initial:IsShown() and tom.initial:GetText() == "O", "a name only typed: its initial on paper")
    Eq(tom.name:GetText(), "Old Tom", "the name under it")
    tom:GetScript("OnEnter")(tom)
    Eq(GameTooltip.text, "Old Tom", "the name its tooltip")
    tom:GetScript("OnLeave")(tom)
    Check(line.padAt[2] > tom.padAt[2] + FACES_SIZE / 2, "the line under the faces")
    Check(line.padAt[2] > alone, "the form laid again: the line moved down")
    Type(line, "bran")
    Check(people.found:IsShown(), "the search offers someone")
    Eq(people.rows[1].person.guid, GUID, "who it found")
    Click(people.rows[1])
    Eq(#people.people, 2, "picked: a second face")
    Eq(people.people[2].guid, GUID, "linked")
    Check(not people.faces[2].initial:IsShown(), "the diary's face, not an initial")
    Check(people.faces[2].padAt[1] > tom.padAt[1], "beside the first")
    Eq(people.faces[2].padAt[2], tom.padAt[2], "on one row")
    Type(line, "Old tom")
    line:GetScript("OnEnterPressed")(line)
    Eq(#people.people, 2, "the same name twice is once")
    line:SetText("")
    Save(view)
    Eq(#rec.people, 2, "both saved")
    Eq(rec.people[1].name, "Old Tom", "the typed one as written")
    Eq(rec.people[2].guid, GUID, "the picked one linked")
    -- A name left on the line when saved is not lost.
    view, rows = Edit(rec)
    people = rows.people
    Eq(#people.people, 2, "opened again: a face each")
    people.box:SetText("Wenna Hale")
    Save(view)
    Eq(#rec.people, 3, "a name left on the line is saved with them")
    Eq(rec.people[3].name, "Wenna Hale", "as written")
    -- Taken off by its cross.
    view, rows = Edit(rec)
    people = rows.people
    Click(people.faces[1].cross)
    Eq(#people.people, 2, "the cross takes them off")
    Eq(people.faces[1].person.guid, GUID, "the next moves up")
    Check(not people.faces[3]:IsShown(), "and the last face goes")
    Save(view)
    Eq(#rec.people, 2, "saved without them")
    Eq(rec.people[1].guid, GUID, "the other kept, linked")
    -- Four at most: then no line.
    view, rows = Edit(rec)
    people = rows.people
    for i = 1, 6 do
        Type(people.box, "Someone " .. i)
        people.box:GetScript("OnEnterPressed")(people.box)
    end
    Eq(#people.people, ns.Custom.PEOPLE_MOST, "as many as a card holds")
    Check(not people.box:IsShown(), "and then no line to add more")
    Click(people.faces[4].cross)
    Check(people.box:IsShown(), "one taken off: the line back")
    CardSheet.View():Hide()

    -- The mob: added from its strip, written, taken off again.
    view, rows = Edit(rec)
    local strip = rows.mob.add
    Click(strip.link)
    Check(rows.mob.on and rows.mob.box:IsShown() and rows.mob.label:IsShown(), "added: its line and label")
    Check(not strip:IsShown(), "its strip gone")
    Check(rows.mob.box:HasFocus(), "the cursor on it")
    Check(rows.mob.off:IsShown(), "and a way to take it off")
    Check(rows.item.add:IsShown(), "the item's strip still there")
    rows.mob.box:SetText("Murloc Forager")
    Save(view)
    Eq(rec.mob, "Murloc Forager", "the mob saved")
    view, rows = Edit(rec)
    Check(rows.mob.on and rows.mob.box:IsShown() and not rows.mob.add:IsShown(), "a card with a mob opens with it")
    Click(rows.mob.off)
    Check(not rows.mob.box:IsShown() and rows.mob.add:IsShown(), "taken off: its strip back")
    Eq(rows.mob:Get(), "", "and cleared")
    Save(view)
    Eq(rec.mob, nil, "the mob gone")

    -- The item: added, searched, picked.
    mock.bags[0] = { size = 16, [1] = { link = "|cff1eff00|Hitem:100:0:0:0:0:0:0:0:11|h[Thistle Sash]|h|r", quality = 2 } }
    mock.itemInfo[100] = { icon = 1001 }
    view, rows = Edit(rec)
    Click(rows.item.add.link)
    Check(rows.item.box:IsShown() and rows.item.box:HasFocus(), "the item's line, written on")
    Type(rows.item.box, "thsash")
    Check(rows.item.found:IsShown(), "the player's own items offered")
    local offered = rows.item.rows[1]
    Eq(offered.item.itemID, 100, "the item found")
    Eq(offered.text:GetText(), "Thistle Sash", "its name")
    Check(offered.picture:IsShown(), "its picture")
    -- The paper and its words inside the sheet, over everything on it.
    local sheetW = YourDiary.CardSheet.View().sheet:GetWidth()
    local left = rows.item.box.padAt[1] - rows.item.box:GetWidth() / 2
    Check(left - 4 + rows.item.found.width <= sheetW, "the paper stays inside the sheet")
    Check(offered.text.width + 18 <= rows.item.found.width, "a name is cut at the paper's width")
    Check(rows.item.found:GetFrameLevel() > rows.caption.flag:GetFrameLevel()
        and rows.item.found:GetFrameLevel() > view.cancel:GetFrameLevel()
        and rows.item.found:GetFrameLevel() > rows.mob.add:GetFrameLevel() + 3, "over everything on the sheet")
    -- Near the sheet's foot: it opens upward, with only the rows that fit.
    local H = view.H
    view.H = rows.item.box.padAt[2] + 30
    for i = 2, 6 do mock.bags[0][i] = { link = "|cff1eff00|Hitem:" .. (110 + i) .. ":0|h[Thistle Sash " .. i .. "]|h|r", quality = 2 } end
    rows.item.Offer()
    Check(rows.item.up == true, "no room under the line: it opens over it")
    Eq(rows.item.found.recorded.points[1].point, "BOTTOMLEFT", "hung by its foot")
    local shown = 0
    for _, r in ipairs(rows.item.rows) do if r:IsShown() then shown = shown + 1 end end
    Check(shown >= 1 and (shown * 18 + 2) <= rows.item.box.padAt[2] - 11 - 8, "as many rows as the room over it holds")
    view.H = H
    for i = 2, 6 do mock.bags[0][i] = nil end
    rows.item.Offer()
    offered = rows.item.rows[1]
    Click(offered)
    Eq(rows.item.box.recorded.calls.SetCursorPosition[1], 0, "picked: shown from its first letter")
    Eq(rows.item.id, 100, "picked: its ID")
    Eq(rows.item.box:GetText(), "Thistle Sash", "its name on the line")
    Check(rows.item.picture:IsShown(), "its picture at the line's start")
    Save(view)
    Eq(rec.item, "Thistle Sash", "the item saved")
    Eq(rec.itemID, 100, "with its ID")
    view, rows = Edit(rec)
    Check(rows.item.on and rows.item.box:IsShown(), "a card with an item opens with it")
    Eq(rows.item.id, 100, "its ID held")
    Type(rows.item.box, "Thistle Sas")
    Eq(rows.item.id, nil, "typing over it lets the item go")
    Check(not rows.item.picture:IsShown(), "and its picture")
    Click(rows.item.off)
    Save(view)
    Eq(rec.item, nil, "taken off: no item")
    Eq(rec.itemID, nil, "and no ID")

    -- A shift-click: into the item's field, added where it was not.
    view, rows = Edit(rec)
    Check(not rows.item.on, "setup: no item on the form")
    local link = "|cff0070dd|Hitem:6504:0:0:0:0:0:0:0:20|h[Wingblade]|h|r"
    local hooks = {}
    _G.hooksecurefunc = function(name, fn) hooks[name] = fn end
    _G.ChatEdit_InsertLink = function() return false end
    CardSheet.Hook()
    Check(hooks.ChatEdit_InsertLink ~= nil, "hooked after the client's own")
    hooks.ChatEdit_InsertLink(link)
    Check(rows.item.on and rows.item.box:IsShown(), "the item's field added")
    Eq(rows.item.box:GetText(), "Wingblade", "the item's name, not its link")
    Eq(rows.item.id, 6504, "its ID")
    Click(rows.item.off)
    _G.ChatEdit_GetActiveWindow = function() return {} end
    Eq(CardSheet.InsertLink(link), false, "a chat line being written keeps its link")
    Check(not rows.item.on, "and the form is left as it was")
    _G.ChatEdit_GetActiveWindow = nil
    Eq(CardSheet.InsertLink("|cff71d5ff|Hspell:133|h[Fireball]|h|r"), false, "a spell is no item")
    Eq(CardSheet.InsertLink(link), true, "taken")
    Save(view)
    Eq(rec.itemID, 6504, "saved by its ID")
    Eq(rec.item, "Wingblade", "and name")
    for key, value in pairs(rec) do
        Check(type(value) ~= "string" or not value:find("|", 1, true), "no `|` saved under " .. key)
    end
    _G.hooksecurefunc, _G.ChatEdit_InsertLink = nil, nil
    view:Hide()
    Eq(CardSheet.InsertLink(link), false, "the form put away: nothing taken")
    mock.bags[0] = { size = 16 }

    -- The caption: a box, off by default.
    view, rows = Edit(rec)
    Eq(rows.caption.flag:GetChecked(), false, "off")
    Click(rows.caption.flag)
    Save(view)
    Eq(rec.caption, true, "on, saved")
    view, rows = Edit(rec)
    Eq(rows.caption.flag:GetChecked(), true, "opened again: on")
    Click(rows.caption.flag)
    Save(view)
    Eq(rec.caption, nil, "off, absent")

    -- Everything, round the form and back, unchanged.
    view, rows = Edit(rec)
    local was = {}
    for key, value in pairs(rec) do was[key] = value end
    rows.text.box:SetText(rows.text.box:GetText())
    Save(view)
    for key, value in pairs(was) do Eq(rec[key], value, "kept: " .. key) end
    Custom.Remove(rec)
    j.version = before
end

--------------------------------------------------------------------------
Section("forgetting them: inside the list")

do
    ns.ForgetEverywhere(GUID)
    Eq(linked.people[1].guid, nil, "the link goes")
    Eq(linked.people[1].name, "Brannoc", "the name as written stays")
    Eq(linked.people[2].guid, OTHER, "and nobody else's")
    Open()
    local card = Card("with Brannoc")
    Check(card ~= nil, "on its card")
    Eq(card.guid, OTHER, "linked to who is left")
end

--------------------------------------------------------------------------
--------------------------------------------------------------------------
Section("schema 6: every saved \"Someone you met\" is a free card")

do
    local Migrate = ns._test.Migrate
    local old = {
        schema = 5,
        journey = {
            a = { custom = {
                { kind = "met", t = 10, mapID = MAP, x = 0.4, y = 0.6, level = 9, who = "Brannoc", whoGuid = GUID,
                    what = "fished off the pier" },
                { kind = "met", t = 20, mapID = MAP, x = 0.4, y = 0.6, level = 9, who = "Old Tom", what = "" },
                { kind = "met", t = 30, mapID = MAP, x = 0.4, y = 0.6, level = 9 },
                { kind = "close", t = 40, mapID = MAP, x = 0.4, y = 0.6, name = "Old Tom", pct = 3 },
            }, chosen = { ["met:10:"] = "out", ["close:40:"] = "keep" } },
            b = { segments = {} },
            c = "not a route",
        },
    }
    Migrate(old, 6, ns._test.DiarySteps)
    Eq(old.schema, 6, "the diary is at 6")
    local list = old.journey.a.custom
    local a = list[1]
    Eq(a.kind, "noteCard", "the kind")
    Eq(a.icon, "meeting", "the meeting's icon")
    Eq(a.text, "fished off the pier", "its line, the text")
    Eq(a.people[1].name, "Brannoc", "the name as written")
    Eq(a.people[1].guid, GUID, "the link kept")
    Eq(#a.people, 1, "one person")
    Check(a.who == nil and a.whoGuid == nil and a.what == nil, "the old keys gone")
    Eq(a.t, 10, "its time")
    Eq(a.mapID, MAP, "its place")
    Eq(a.level, 9, "its level")
    Eq(a.caption, true, "an old meeting keeps telling the caption")
    Eq(list[4].caption, nil, "another kind gets no caption flag")
    Eq(list[2].text, nil, "an empty line is no text")
    Eq(list[2].people[1].guid, nil, "a typed name has no link")
    Eq(list[3].people, nil, "nobody named, no people")
    Eq(list[3].icon, "meeting", "still a meeting")
    Eq(list[4].kind, "close", "another kind as it was")
    Eq(list[4].name, "Old Tom", "untouched")
    Eq(old.journey.a.chosen["noteCard:10:"], "out", "a choice follows it")
    Eq(old.journey.a.chosen["met:10:"], nil, "under the new kind only")
    Eq(old.journey.a.chosen["close:40:"], "keep", "another's stays")
    Eq(old.journey.b.custom, nil, "a route with none gets no list")

    -- And it reads: on a route, as the page reads it.
    local before = j.custom
    j.custom = list
    local e = Recap.Gather(j, 0, now, Recap.Context(ns.ownGUID, now))
    Eq(#e.noteCard, 3, "the folded cards are gathered")
    Eq(Recap.Key({ kind = KIND, t = 10, noteCard = e.noteCard[1] }), "noteCard:10:", "keyed as the choice is")
    Eq(Note.Label(e.noteCard[1]), "Brannoc", "and read")
    Eq(Note.Who(e.noteCard[1]), "with Brannoc", "its strip's line, as before")
    j.custom = before
end
