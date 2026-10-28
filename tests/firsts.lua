-- Your Diary's firsts (JRN-24): the first bag, shoulders, green, blue and
-- epic found, read off the bags; what was had before the diary looked is
-- never one; how each came; their moments, ranks and words.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY

-- The client's loot lines (enUS) and its mailbox, hooked as the client's
-- hooksecurefunc does. Set before the addon loads (the hooks are made at
-- load); taken away at the end.
_G.LOOT_ITEM_CREATED_SELF = "You create: %s."
_G.LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
local inbox = {}
_G.GetInboxItemLink = function(index, attachment) return inbox[index] and inbox[index][attachment] end
_G.TakeInboxItem = function() end
_G.AutoLootMailItem = function() end
_G.hooksecurefunc = function(name, fn)
    local before = _G[name]
    _G[name] = function(...)
        local r = before(...)
        fn(...)
        return r
    end
end

local ns = T.Boot()

local J, R, Text = ns.Journey, ns.JourneyRecap, ns.UI.JourneyText
local Firsts = ns.Firsts
local FC = Firsts.Card
local SELF = F.SELF
local MULGORE = 1412

local function Link(id, name, color)
    return ("|cff%s|Hitem:%d::::::::10:::::|h[%s]|h|r"):format(color or "ffffff", id, name)
end

local POUCH = Link(4496, "Small Brown Pouch")
local BRACERS = Link(6070, "Wolfskin Bracers", "1eff00")
local SPAULDERS = Link(4253, "Ragged Leather Spaulders")
local BLUE = Link(2059, "Pathfinder Footpads", "0070dd")
local GREEN_BAG = Link(5573, "Green Leather Bag", "1eff00")
mock.itemInfo[4496] = { classID = 1, subclassID = 0, equipLoc = "INVTYPE_BAG" }
mock.itemInfo[5573] = { classID = 1, subclassID = 0, equipLoc = "INVTYPE_BAG" }
mock.itemInfo[6070] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_WRIST" }
mock.itemInfo[4253] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_SHOULDER" }
mock.itemInfo[2059] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_FEET" }
mock.itemInfo[2512] = { classID = 11, subclassID = 2, equipLoc = "INVTYPE_BAG" }   -- a quiver

local function Put(slot, link, quality)
    mock.bags[0][slot] = link and { link = link, quality = quality or 1 } or nil
end

local function Bags()
    mock.fire("BAG_UPDATE_DELAYED")
end

--------------------------------------------------------------------------
Section("what an item is a first of")

local function Kinds(item)
    return table.concat(Firsts.Kinds(item), ",")
end
Eq(Kinds({ classID = 1, subclassID = 0, quality = 1 }), "bag", "a plain bag")
Eq(Kinds({ classID = 1, subclassID = 0, quality = 2 }), "bag,uncommon", "a green bag")
Eq(Kinds({ classID = 11, subclassID = 2, quality = 1 }), "", "a quiver")
Eq(Kinds({ classID = 1, subclassID = 1, quality = 1 }), "", "a soul bag")
Eq(Kinds({ classID = 4, equipLoc = "INVTYPE_SHOULDER", quality = 0 }), "shoulder", "grey shoulders")
Eq(Kinds({ classID = 4, equipLoc = "INVTYPE_FEET", quality = 3 }), "rare", "a blue")
Eq(Kinds({ classID = 2, equipLoc = "INVTYPE_2HWEAPON", quality = 4 }), "epic", "an epic")
Eq(Kinds({ classID = 2, quality = 5 }), "", "a legendary is none of them")

--------------------------------------------------------------------------
Section("what is held when the diary first looks is never a first")

mock.equipped[1] = { link = Link(6125, "Brawler's Harness"), quality = 1 }
Put(1, SPAULDERS)
mock.fire("PLAYER_ENTERING_WORLD")
local j = ns.db.journey[SELF.guid]
Check(j, "setup: no route")
Eq(j.firsts, nil, "the bags were read before they settled")
mock.RunTimers()
Check(j.firsts, "the bags were not read after entering the world")
Eq(j.firsts.shoulder, false, "shoulders held at the start became a first")
Eq(j.firsts.bag, nil, "a kind not held is not looked for")
Check(Firsts.Looking(j), "nothing looked for")

-- An empty backpack is not read: the bags have not loaded.
do
    local saved = mock.bags[0].size
    mock.bags[0].size = 0
    j.firsts = nil
    Bags()
    Eq(j.firsts, nil, "an unloaded backpack was read as empty")
    mock.bags[0].size = saved
    Bags()
    Eq(j.firsts.shoulder, false, "setup: the reading again")
end

--------------------------------------------------------------------------
Section("a first found, where and how it came")

mock.now = mock.now + 600
mock.position = { x = 0.5, y = 0.25 }
mock.fire("LOOT_OPENED")
Put(2, POUCH)
Bags()
local bag = j.firsts.bag
Check(bag, "the first bag was not found")
Eq(bag.t, mock.now, "when it was found")
Eq(bag.mapID, MULGORE, "the zone it was found in")
Eq(bag.x, 0.5, "where it was found")
Eq(bag.link, POUCH, "which bag")
Eq(bag.from, "loot", "how it came")
Check(bag.level, "the level it was found at")
Eq(bag.guid, nil, "a looted bag has a giver")
mock.fire("LOOT_CLOSED")

-- The bag put in a bag slot is the same bag, and a second is not a first.
Put(2, nil)
mock.bags[1] = { size = 6 }
mock.equipped[20] = { link = POUCH, quality = 1 }
mock.now = mock.now + 60
Put(3, GREEN_BAG, 2)
Bags()
Eq(j.firsts.bag, bag, "a second bag replaced the first")
Eq(j.firsts.uncommon and j.firsts.uncommon.link, GREEN_BAG, "a green bag is not the first green")
Eq(j.firsts.uncommon.from, nil, "a window closed a minute ago still says how it came")

-- A vendor's window, open.
mock.now = mock.now + 60
mock.fire("MERCHANT_SHOW")
Put(4, BLUE, 3)
Bags()
Eq(j.firsts.rare.from, "vendor", "a blue bought")
mock.fire("MERCHANT_CLOSED")

--------------------------------------------------------------------------
Section("a first given in a trade")

local KOKO = "Player-0000-KOKO0001"
ns.Characters.Observe(KOKO, { first = "Koko", surname = "Skybluff" })
ns.Diary.Add(KOKO, { source = "test" })
mock.now = mock.now + 300
local EPIC = Link(1263, "Brain Hacker", "a335ee")
mock.itemInfo[1263] = { classID = 2, subclassID = 1, equipLoc = "INVTYPE_2HWEAPON" }
-- The trade's capture says so as it stores the trade (SD_TRADE_COMPLETED),
-- two seconds before the bags change.
mock.now = mock.now - 2
ns.Fire("SD_TRADE_COMPLETED", KOKO, { { link = EPIC, count = 1 } })
mock.now = mock.now + 2
Put(5, EPIC, 4)
Bags()
Eq(j.firsts.epic.from, "trade", "an epic received in a trade")
Eq(j.firsts.epic.guid, KOKO, "who gave it")

-- Something received in a trade that is not the item is not a gift.
do
    local saved = j.firsts.shoulder
    j.firsts.shoulder = nil
    ns.Fire("SD_TRADE_COMPLETED", KOKO, { { link = POUCH, count = 1 } })
    Put(6, Link(4254, "Rough Shoulders"))
    mock.itemInfo[4254] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_SHOULDER" }
    Bags()
    Eq(j.firsts.shoulder.from, nil, "an item the trade did not hold was a gift")
    Eq(j.firsts.shoulder.guid, nil, "an item the trade did not hold has a giver")
    j.firsts.shoulder = saved
end
Eq(Firsts.Looking(j), false, "still looking with every kind found or had")

--------------------------------------------------------------------------
Section("how a first came: what was said about the item, not an open mailbox")

-- One kind looked for again, an item of it in the bags, what `say` does
-- before (or after) the bags change: how it came.
local GREEN = Link(6071, "Woolen Gloves", "1eff00")
mock.itemInfo[6071] = { classID = 4, subclassID = 1, equipLoc = "INVTYPE_HAND" }
local function Came(say, after)
    local saved = j.firsts.uncommon
    j.firsts.uncommon = nil
    mock.now = mock.now + 60
    Put(7, nil)
    Bags()
    if not after then say() end
    Put(7, GREEN, 2)
    Bags()
    if after then say() end
    local rec = j.firsts.uncommon
    j.firsts.uncommon = saved
    Put(7, nil)
    return rec and rec.from
end
local function Chat(text) mock.fire("CHAT_MSG_LOOT", text, "Me") end
-- The green bag found above is out of the bags meanwhile.
local greenBag = mock.bags[0][3]
Put(3, nil)

-- The reported bug: a mailbox open (or its close never heard) said
-- "came by mail" of a quest's reward and of something made.
mock.fire("MAIL_SHOW")
Eq(Came(function()
    mock.fire("QUEST_COMPLETE")
    mock.fire("QUEST_FINISHED")
    Chat("You receive item: " .. GREEN .. ".")
end), "quest", "a quest's reward beside an open mailbox")
Eq(Came(function() Chat("You create: " .. GREEN .. ".") end), "craft", "something made beside an open mailbox")
Eq(Came(function() end), nil, "an open mailbox alone said how it came")

-- A line after the bags changed still says how.
Eq(Came(function() Chat("You create: " .. GREEN .. ".") end, true), "craft", "a line after the bags changed")
Eq(Came(function() Chat("You create: " .. GREEN .. "x2.") end), "craft", "two made at once")
Eq(Came(function() Chat("You receive loot: " .. GREEN .. ".") end), "loot", "a looted green")
Eq(Came(function()
    mock.fire("MERCHANT_SHOW")
    Chat("You receive item: " .. GREEN .. ".")
end), "vendor", "a green bought")
mock.fire("MERCHANT_CLOSED")
-- A line about another item says nothing about this one.
mock.now = mock.now + 60
Eq(Came(function() Chat("You create: " .. BRACERS .. ".") end), nil, "a line about another item")

-- Taken out of a letter: one attachment, or all of them.
inbox[1] = { [2] = GREEN }
Eq(Came(function() TakeInboxItem(1, 2) end), "mail", "an attachment taken")
Eq(Came(function()
    AutoLootMailItem(1)
    Chat("You receive item: " .. GREEN .. ".")
end), "mail", "a letter opened, and a line after it")
Eq(Came(function() TakeInboxItem(1, 2) end, true), "mail", "the attachment's hook after the bags changed")
inbox[1] = nil
mock.fire("MAIL_CLOSED")
mock.bags[0][3] = greenBag
mock.now = mock.now + 60

--------------------------------------------------------------------------
Section("not watching: what came in meanwhile is had, not found")

local SECOND = "Player-0000-ALT00001"
ns.ownGUID = SECOND
mock.bags[0] = { size = 16 }
mock.bags[1], mock.equipped[20] = nil, nil
mock.fire("PLAYER_ENTERING_WORLD")
mock.RunTimers()
local alt = ns.db.journey[SECOND]
Check(alt and alt.firsts, "setup: the alt's bags were not read")
ns.JourneyCapture.SetEnabled(false)
Put(1, POUCH)
Bags()
ns.JourneyCapture.SetEnabled(true)
Put(2, BRACERS, 2)
Bags()
Eq(alt.firsts.bag, false, "a bag that came while the route was off became a first")
Eq(alt.firsts.uncommon, false, "the first reading after watching again found something")
mock.now = mock.now + 30
Put(3, BLUE, 3)
Bags()
Check(alt.firsts.rare, "a blue after that was not found")
ns.ownGUID = SELF.guid

--------------------------------------------------------------------------
Section("firsts on the plates: gifts outrank deaths (JRN-24)")

-- A level with four places: a death, a note (where the level was reached),
-- a first green and a gift, each far from the others. Three plates: the
-- death's goes, and the level-up opens none but joins the note's.
local d0 = mock.now + DAY
local r = {
    startedAt = d0, startLevel = 5, levels = {}, marks = {}, deaths = {},
    segments = {
        { kind = "stop", from = d0, to = d0 + 600, mapID = MULGORE, x = 0.1, y = 0.1, seconds = 600,
            act = { deaths = 1 } },
    },
    firsts = {
        bag = { t = d0 + 100, mapID = MULGORE, x = 0.9, y = 0.9, level = 5, link = POUCH, from = "trade", guid = KOKO },
        uncommon = { t = d0 + 200, mapID = MULGORE, x = 0.5, y = 0.5, level = 5, link = BRACERS, from = "quest" },
    },
}
local e = R.Gather(r, d0, d0 + 1000, {})
Eq(#e.finds, 2, "the firsts in the stretch")
Eq(e.finds[1].kind, "bag", "the firsts are not oldest first")
e.level, e.reached = 6, { at = d0 + 300, mapID = MULGORE, x = 0.3, y = 0.8 }
e.notes = { { time = d0 + 400, mapID = MULGORE, x = 0.31, y = 0.8, about = { [KOKO] = true } } }
local moments = R.Moments(r, e, {})
local byKind = {}
for _, m in ipairs(moments) do byKind[m.what or m.kind] = m end
Check(byKind.bag and byKind.bag.kind == "find" and byKind.bag.gift, "the gift has no moment")
Eq(byKind.bag.guid, KOKO, "the gift's moment has no giver")
Check(byKind.death and byKind.level, "setup: no death or level-up moment")
Eq(R.Rank(byKind.bag), R.RANK.session, "a gift does not rank with the people")
Eq(R.Rank(byKind.uncommon), R.RANK.find, "a find does not rank as a find")
Check(R.Rank(byKind.uncommon) < R.Rank(byKind.level), "a find does not outrank a level-up")
Check(R.Rank(byKind.bag) < R.RANK.death and R.Rank(byKind.uncommon) < R.RANK.death, "a find ranks below a death")
local plates = R.Plates(r, e, {}, function() return 0.2, 0.2 end)
local kinds = {}
for _, p in ipairs(plates) do
    for _, m in ipairs(p.moments) do kinds[#kinds + 1] = m.what or m.kind end
end
table.sort(kinds)
Eq(table.concat(kinds, ","), "bag,level,note,uncommon", "the plates' moments")
-- A week past the cap with only a first in it still has an entry.
Eq(#R.Gather(r, d0 + 50, d0 + 150, {}).finds, 1, "a first not in its stretch")

--------------------------------------------------------------------------
Section("firsts in words")

-- A first's moment, as the recap makes it (Kind.lua's `moment`): a gift
-- carries how it stands on its giver's margin note (Firsts.PERSON).
local function Find(what, rec)
    local gift = rec.from == "trade" or nil
    return { kind = "find", what = what, t = rec.t, find = rec, gift = gift, guid = rec.guid,
        person = gift and Firsts.PERSON or nil }
end
local loot = { t = d0, mapID = MULGORE, link = BRACERS, from = "loot", level = 6 }
local gift = { t = d0, mapID = MULGORE, link = POUCH, from = "trade", guid = KOKO, level = 5 }
local stranger = { t = d0, mapID = MULGORE, link = POUCH, from = "trade", level = 5 }

Eq(Firsts.Sentence("uncommon", loot), "Found your first green in Mulgore: Wolfskin Bracers.", "a green found")
Eq(Firsts.Sentence("bag", gift), "Koko Skybluff gave you your first bag: Small Brown Pouch.", "a bag given")
Eq(Firsts.Sentence("bag", stranger), "Your first bag was a gift: Small Brown Pouch.", "a bag from someone gone")
Eq(Firsts.Sentence("rare", { t = d0, link = BLUE, from = "quest" }), "A quest gave you your first blue: Pathfinder Footpads.",
    "a quest's blue")
Eq(Firsts.Sentence("bag", { t = d0, mapID = MULGORE, link = POUCH, from = "vendor" }),
    "Bought your first bag in Mulgore: Small Brown Pouch.", "a bag bought")
Eq(Firsts.Sentence("shoulder", { t = d0, from = "mail" }), "Your first shoulders came by mail.", "shoulders by mail")
Eq(Firsts.Sentence("bag", { t = d0, mapID = MULGORE, link = POUCH, from = "craft" }),
    "Made your first bag in Mulgore: Small Brown Pouch.", "a bag made")
Eq(Firsts.Sentence("epic", { t = d0 }), "Found your first epic.", "an epic found nowhere known")

local plate = { mapID = MULGORE, t = d0, moments = { Find("uncommon", loot) } }
Eq(Text.PlateCaption(plate), "A first green: Wolfskin Bracers.", "a plate with a first alone")
plate.moments = { Find("bag", gift) }
Eq(Text.PlateCaption(plate), "A first bag from Koko.", "a plate with a gift")
Eq(Text.PlateCaption(plate, nil, { named = { [KOKO] = true } }), "A first bag.", "a gift Koko's note already tells")
plate.moments = { Find("bag", stranger) }
Eq(Text.PlateCaption(plate), "A first bag, a gift.", "a gift from someone gone")
plate.moments = { { kind = "level", level = 6, t = d0 }, Find("shoulder", loot) }
Eq(Text.PlateCaption(plate), "First shoulders: Wolfskin Bracers.", "a level-up and a first: the first leads")
plate.moments = { { kind = "level", level = 6, t = d0 }, Find("bag", loot), { kind = "death", t = d0 } }
Eq(Text.PlateCaption(plate), "A first bag, and a death.", "a level-up, a first and a death")
plate.moments = { Find("uncommon", loot), { kind = "death", t = d0 } }
Eq(Text.PlateCaption(plate), "A first green, and a death.", "a first and a death")
plate.moments = { Find("uncommon", loot), Find("bag", loot) }
Eq(Text.PlateCaption(plate), "A first green and a first bag.", "two firsts")
plate.moments = { { kind = "level", level = 5, t = d0 }, { kind = "death", t = d0 }, { kind = "death", t = d0 } }
Eq(Text.PlateCaption(plate), "Two deaths.", "a level-up plate's caption changed")

Eq(Text.MarginWhat({ Find("bag", gift) }), "gave you your\194\160first\194\160bag", "a giver's margin note")
Check(Text.MarginWhat({ { kind = "session", seconds = 2700 }, { kind = "note" }, Find("bag", gift) })
    :find("^gave you your\194\160first\194\160bag and "), "a gift is not first on a busy margin note")

local head, line = Firsts.Tip(Find("bag", gift), d0)
Eq(head, "Your first bag", "a first's tooltip heading")
Check(line:find("^Small Brown Pouch, from Koko Skybluff, at level 5, "), "a first's tooltip line: " .. line)
head, line = Firsts.Tip(Find("uncommon", loot), d0)
Check(line:find("^Wolfskin Bracers, looted, at level 6, "), "a looted first's tooltip line: " .. line)
head, line = Firsts.Tip(Find("bag", { t = d0, link = POUCH, from = "craft", level = 5 }), d0)
Check(line:find("^Small Brown Pouch, made by hand, at level 5, "), "a made first's tooltip line: " .. line)

-- The entry's prose ends with its firsts.
local lines = Text.Lines({ kind = "level", level = 5, from = d0, to = d0 + 600, seconds = 600, places = {},
    stops = {}, flights = {}, people = {}, fights = {}, notes = {}, deaths = {}, dungeons = {},
    finds = { { kind = "uncommon", rec = loot } } }, d0 + DAY)
Eq(lines[#lines], "Found your first green in Mulgore: Wolfskin Bracers.", "the prose's firsts")

--------------------------------------------------------------------------
Section("a gift's giver goes as a fight's does")

local rec = j.firsts.epic
Eq(rec.guid, KOKO, "setup: the giver")
ns.Diary.Remove(KOKO, true)
J.Prune(rec.t + 1)
Eq(rec.guid, KOKO, "a giver went while the buffer still holds them")
J.Prune(rec.t + 60 * DAY)
Eq(rec.guid, nil, "a giver outlived the buffer")
rec.guid = KOKO
ns.ForgetEverywhere(KOKO)
Eq(rec.guid, nil, "a forgotten giver stayed on a first")
Eq(rec.from, "trade", "forgetting the giver forgot the gift")

--------------------------------------------------------------------------
Section("a first on its plate: the pouch, its tooltip, a giver's margin note")

-- Level 5 in Mulgore: a bag looted, a blue given by Tika (in the diary)
-- and shoulders given by someone the diary does not know.
local TIKA = "Player-0000-TIKA0001"
ns.Characters.Observe(TIKA, { first = "Tika", surname = "Dawnhoof", level = 6, faction = "Horde" })
ns.Diary.Add(TIKA, { source = "test" })
SELF.level = 6
mock.SetUnit("player", SELF)
local p0 = mock.now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local route = J.Begin(SELF.guid, p0, 5, MULGORE)
local function Seg(seg) route.segments[#route.segments + 1] = seg end
Seg({ kind = "stop", from = p0, to = p0 + 1800, mapID = MULGORE, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, levelFrom = 5, levelTo = 5 })
Seg({ kind = "road", from = p0 + 1800, to = p0 + 2400, mapID = MULGORE, levelFrom = 5, levelTo = 5,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.47, 0.60, 0.45 } })
Seg({ kind = "stop", from = p0 + 2400, to = p0 + 3200, mapID = MULGORE, x = 0.60, y = 0.45, r = 30, seconds = 800,
    levelFrom = 5, levelTo = 6 })
route.levels[6] = { at = p0 + 3100, mapID = MULGORE, x = 0.60, y = 0.45 }
route.firsts = {
    bag = { t = p0 + 600, mapID = MULGORE, x = 0.43, y = 0.57, level = 5, link = POUCH, from = "loot" },
    rare = { t = p0 + 2600, mapID = MULGORE, x = 0.56, y = 0.50, level = 5, link = BLUE, from = "trade", guid = TIKA },
    shoulder = { t = p0 + 2000, mapID = MULGORE, x = 0.48, y = 0.53, level = 5, link = SPAULDERS, from = "trade" },
}
J.Touch()

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
Eq(page.state, "entries", "setup: the route is not shown")
for i, entry in ipairs(page.recap.entries) do
    if entry.level == 5 then page.open = i end
end
ns.UI.RedrawJourneyPage()
Check(page.layout >= 1, "level 5 has no plate")

-- Every pouch on the shown plates, and what each tooltip says.
local pouches, tips, plateOf = {}, {}, {}
for _, plate in ipairs(page.plates) do
    if plate:IsShown() then
        for _, mark in ipairs(plate.findMarks or {}) do
            pouches[#pouches + 1] = mark
            plateOf[mark] = plate
        end
        for i = 1, plate.hover.used do
            local list = plate.hover[i].tip and plate.hover[i].tip()
            if list then
                local parts = {}
                for _, line in ipairs(list) do parts[#parts + 1] = line[1] end
                tips[#tips + 1] = table.concat(parts, "|")
            end
        end
    end
end
Eq(#pouches, 3, "a pouch for each first found")
local byWhat = {}
for _, mark in ipairs(pouches) do byWhat[mark.list[1].what] = mark end
Check(byWhat.bag and byWhat.rare and byWhat.shoulder, "a first has no pouch of its own")
local function Tipped(pattern)
    for _, text in ipairs(tips) do
        if text:find(pattern) then return true end
    end
    return false
end
Check(Tipped("^Your first bag|Small Brown Pouch, looted, at level 5, "), "the bag's tooltip: " .. table.concat(tips, " / "))
Check(Tipped("^Your first blue|Pathfinder Footpads, from Tika Dawnhoof, at level 5, "), "the blue's tooltip")
Check(Tipped("^Your first shoulders|Ragged Leather Spaulders, a gift, at level 5, "), "the shoulders' tooltip")

-- The pouch is drawn: a body, a neck and a mouth, on its paper halo.
do
    local plate = plateOf[byWhat.bag]
    Check(plate.counts.finds >= 1, "the plate does not count its pouches")
    local spot
    for _, s in ipairs(plate.spots) do
        if s[1] == byWhat.bag.x and s[2] == byWhat.bag.y then spot = s end
    end
    Check(spot, "the pouch did not keep its room from the other marks")
end
-- Plain ink for a white bag; a blue's pouch leans to its colour, a little.
local INK = ns.Style.INK_STRONG
Eq(table.concat(byWhat.bag.arg, ","), table.concat(INK, ","), "a white bag's pouch is not in plain ink")
local blue = byWhat.rare.arg
Check(blue[3] > INK[3] + 0.1 and blue[3] < 0.5, "a blue's pouch is not a hint of blue: " .. table.concat(blue, ","))

-- Tika gave the blue: she has a margin note saying so, its leader on her
-- pouch, and the caption does not name her again. The stranger who gave
-- the shoulders has no note.
local notes, tikaNote = {}, nil
for i = 1, page.notePool.used do
    local note = page.notePool[i]
    if note:IsShown() then
        notes[#notes + 1] = note.name:GetText() .. ": " .. note:What()
        if note.name:GetText() == "with Tika" then tikaNote = note end
    end
end
Check(tikaNote, "the giver has no margin note: " .. table.concat(notes, "; "))
Eq(#notes, 1, "a gift from a stranger has a margin note: " .. table.concat(notes, "; "))
Check(tikaNote and tikaNote:What():find("gave you your\194\160first\194\160blue"), "the giver's note: "
    .. (tikaNote and tikaNote:What() or ""))
local led = false
for _, link in ipairs(page.links) do
    if link.strip == tikaNote and link.mark[1] and link.plate == plateOf[byWhat.rare] then
        local at = link.plate.where[byWhat.rare.list[1]]
        led = at ~= nil and link.mark == at
    end
end
Check(led, "the giver's leader does not go to her pouch")
-- Her gift is something done together (Firsts.PERSON's tier 1): her note
-- is laid with the people who did something with you, before the cards,
-- not with those only seen after them.
do
    local personAt, cardAt
    for i, it in ipairs(plateOf[byWhat.rare].margin or {}) do
        if it.kind == "person" and it.g.guid == TIKA then personAt = personAt or i end
        if it.kind == "find" then cardAt = cardAt or i end
    end
    Check(personAt and cardAt and personAt < cardAt, ("the giver's note is not before the cards: %s, %s")
        :format(tostring(personAt), tostring(cardAt)))
end
local captions = {}
for i = 1, page.captionPool.used do
    local caption = page.captionPool[i]
    if caption:IsShown() then captions[#captions + 1] = caption:GetText() end
end
Check(#captions >= 1, "the plates have no captions")
for _, text in ipairs(captions) do
    Check(not text:find("Tika"), "the caption names the giver her note names: " .. text)
end
Check(table.concat(captions, " "):find("first blue"), "no caption tells the blue: " .. table.concat(captions, " / "))

-- The zone's full page has the pouches too.
ns.UI.OpenZoneSheet(MULGORE)
Eq(page.mode, "full", "setup: the full page")
Eq(#(page.plates[1].findMarks or {}), 3, "the full page has no pouches")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a first found card's words")

Eq(Firsts.Heading("uncommon"), "Your first green item!", "a green's heading")
Eq(Firsts.Heading("rare"), "Your first blue item!", "a blue's heading")
Eq(Firsts.Heading("epic"), "Your first epic item!", "an epic's heading")
Eq(Firsts.Heading("bag"), "Your first bag!", "a bag's heading")
Eq(Firsts.Heading("shoulder"), "Your first shoulders!", "shoulders' heading")
Eq(Firsts.Heading({ "uncommon", "bag" }), "Your first bag and first green item!", "a green bag's heading")
Eq(Firsts.Heading("rare", true), "Your first blue!", "a blue's short heading")
local fromTika = { t = d0, mapID = MULGORE, link = POUCH, from = "trade", guid = TIKA, level = 5 }
Eq(Firsts.GiftLine(fromTika, {}), "from Tika", "a giver with no note of her own")
Eq(Firsts.GiftLine(fromTika, { [TIKA] = true }), nil, "a giver whose note says so already")
Eq(Firsts.GiftLine(stranger, {}), "a gift", "a gift from someone gone")
Eq(Firsts.GiftLine(loot, {}), nil, "a find looted is a gift")

-- The caption with the card shown names no item; without it, as before.
do
    local m = Find("uncommon", loot)
    local p = { mapID = MULGORE, t = d0, moments = { m } }
    Eq(Text.PlateCaption(p, nil, { find = { [m] = true } }), "A first green.", "a first with its card")
    Eq(Text.PlateCaption(p, nil, { find = {} }), "A first green: Wolfskin Bracers.", "a first with no card")
    local s = Find("bag", stranger)
    p.moments = { s }
    Eq(Text.PlateCaption(p, nil, { find = { [s] = true } }), "A first bag.", "a gift its card tells")
    local k = Find("bag", fromTika)
    p.moments = { k }
    Eq(Text.PlateCaption(p, nil, { find = { [k] = true } }), "A first bag.", "a giver its card names")
end

--------------------------------------------------------------------------
Section("a first found card on its plate")

-- Level 7 in Mulgore: two deaths to a Lashtail by a blue found, and level
-- 8 down the road. Level 8: a green found alone in Mulgore, then off to
-- Durotar, where level 9 comes.
local DUROTAR = 1411
mock.itemInfo[2059].icon = 132539
mock.itemInfo[6070].icon = 132602
SELF.level = 9
mock.SetUnit("player", SELF)
local q0 = mock.now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local run = J.Begin(SELF.guid, q0, 7, MULGORE)
local function Add(seg) run.segments[#run.segments + 1] = seg end
Add({ kind = "stop", from = q0, to = q0 + 1800, mapID = MULGORE, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900, deaths = 2 }, levelFrom = 7, levelTo = 7 })
Add({ kind = "road", from = q0 + 1800, to = q0 + 2400, mapID = MULGORE, levelFrom = 7, levelTo = 7,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Add({ kind = "stop", from = q0 + 2400, to = q0 + 4200, mapID = MULGORE, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    levelFrom = 7, levelTo = 8 })
run.levels[8] = { at = q0 + 4000, mapID = MULGORE, x = 0.60, y = 0.45 }
local q1 = q0 + DAY
Add({ kind = "stop", from = q1, to = q1 + 1800, mapID = MULGORE, x = 0.30, y = 0.30, r = 40, seconds = 1800,
    act = { combat = 600 }, levelFrom = 8, levelTo = 8 })
Add({ kind = "flight", from = q1 + 1800, to = q1 + 2400, x1 = 0.30, y1 = 0.30, mapID1 = MULGORE, x2 = 0.50,
    y2 = 0.20, mapID2 = DUROTAR, mapID = MULGORE, levelFrom = 8, levelTo = 8 })
Add({ kind = "stop", from = q1 + 2400, to = q1 + 3600, mapID = DUROTAR, x = 0.50, y = 0.20, r = 30, seconds = 1200,
    levelFrom = 8, levelTo = 9 })
run.levels[9] = { at = q1 + 3500, mapID = DUROTAR, x = 0.50, y = 0.20 }
run.firsts = {
    rare = { t = q0 + 900, mapID = MULGORE, x = 0.42, y = 0.58, level = 7, link = BLUE, from = "loot" },
    uncommon = { t = q1 + 900, mapID = MULGORE, x = 0.31, y = 0.31, level = 8, link = BRACERS, from = "loot" },
}
run.deaths = {
    { t = q0 + 600, mapID = MULGORE, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail", spell = "Bite",
        display = 1234 },
    { t = q0 + 1200, mapID = MULGORE, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail", spell = "Bite",
        display = 1234 },
}
J.Touch()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()
for i, entry in ipairs(page.recap.entries) do
    if entry.level == 7 then page.open = i end
end
ns.UI.RedrawJourneyPage()

local function Shown(pool)
    local list = {}
    for i = 1, pool.used do
        if pool[i]:IsShown() then list[#list + 1] = pool[i] end
    end
    return list
end
local function Captions()
    local list = {}
    for _, caption in ipairs(Shown(page.captionPool)) do list[#list + 1] = caption:GetText() end
    return table.concat(list, " / ")
end

local cards = Shown(page.findPool)
Eq(#cards, 1, "one card for the blue: " .. Captions())
Eq(page.findsWritten, 1, "the page's count of first found cards")
local card = cards[1]
-- The heading in the hand: the full words where they fit the column, the
-- short where they do not (the margin's columns: 122 and 136 px, too
-- narrow; the one plate's row, 142, and wider, not).
Eq(card.name:GetText(), Firsts.Heading("rare", card.column < 140), "the card's heading in a column of " .. card.column)
-- The icon, from the item's ID, its baked frame trimmed; edged in the
-- game's own blue, as the game edges it.
Eq(card.icon.recorded.calls.SetTexture[1], 132539, "the icon is not the item's")
Check(card.icon:IsShown(), "the icon is hidden")
Eq(card.icon.recorded.calls.SetTexCoord[1], FC.ICON.crop, "the icon keeps its baked frame")
local blueInk = ns.Style.QualityNameInk(3)
do
    local edge = card.iconEdge.recorded.calls.SetColorTexture
    Eq(("%02x%02x%02x"):format(edge[1] * 255 + 0.5, edge[2] * 255 + 0.5, edge[3] * 255 + 0.5), "0070dd",
        "the icon is not edged in the game's blue")
end
-- The name in blue ink, in the box, beside the icon.
-- (Two lines in a narrow column.)
local function ItemWords(c)
    local words = {}
    for _, line in ipairs(c.itemLines) do
        if line:IsShown() then words[#words + 1] = line:GetText() end
    end
    return table.concat(words, " ")
end
local nameLine = card.itemLines[1]
Eq(ItemWords(card), "Pathfinder Footpads", "the item's name")
Check(nameLine:IsShown(), "the item's name is hidden")
local colour = nameLine.recorded.calls.SetTextColor
Eq(table.concat({ colour[1], colour[2], colour[3] }, ","), table.concat(blueInk, ","), "the name is not in blue ink")

-- Its wash: the blue multiplied into the cream in two lengths, deep at the
-- left edge to `left` where the name starts, then paling to `right`; the
-- tide line where it dried is its edge, full on the bottom and right; no
-- grey pen rule and no heavier edge.
local function Hex(c)
    return ("%02x%02x%02x"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end
local function Stop(c) return Hex({ c.r, c.g, c.b }) .. (c.a == 1 and "" or "/" .. c.a) end
local function Washed(c, q, flat, what)
    local wash = ns.Style.QualityWash(q)
    Check(not c.boxRule:IsShown() and not c.boxWeight:IsShown(), what .. ": the grey rule is drawn round a wash")
    local ground = c.boxGround.recorded
    Eq(ground.width .. "x" .. ground.height, (c.chip.w + 2) .. "x" .. (c.chip.h + 2),
        what .. ": the ground does not reach the tide line")
    local stops = { { wash.deep, wash.left }, { wash.left, wash.right } }
    for i, part in ipairs(c.boxWash) do
        local calls = part.recorded.calls
        Check(part:IsShown(), what .. ": wash " .. i .. " is hidden")
        Eq(calls.SetBlendMode and calls.SetBlendMode[1], "MOD", what .. ": wash " .. i .. " is not multiplied in")
        local g = calls.SetGradient
        Eq(g and g[1], "HORIZONTAL", what .. ": wash " .. i .. " does not run along the name")
        Eq(g and (Stop(g[2]) .. ">" .. Stop(g[3])), Hex(stops[i][1]) .. ">" .. Hex(stops[i][2]),
            what .. ": wash " .. i .. "'s colours")
    end
    -- The two lengths meet where the name starts, and fill the box.
    local w1, w2 = c.boxWash[1].recorded.width, c.boxWash[2].recorded.width
    Eq(w1, 1 + FC.BOX.pad[1] + c.chip.textAt[1], what .. ": the deep length runs under the name")
    Eq(w1 + w2, c.chip.w + 2, what .. ": the wash does not fill the box")
    local sides = {}
    for i, tide in ipairs(c.boxTide) do
        Check(tide:IsShown(), what .. ": a tide line is hidden")
        Eq(tide.recorded.calls.SetBlendMode[1], "MOD", what .. ": a tide line is not multiplied in")
        sides[i] = Hex(tide.recorded.calls.SetColorTexture)
    end
    local full, light = Hex(wash.tide), flat and Hex(wash.tide) or Hex(wash.tideIn)
    Eq(table.concat(sides, ","), table.concat({ light, full, light, full }, ","),
        what .. ": the tide line's top, bottom, left, right")
    Eq(c.boxTide[2].recorded.width, c.chip.w + 2, what .. ": the bottom tide line is not across the box")
    Eq(c.boxTide[4].recorded.height, c.chip.h, what .. ": the right tide line overlaps a corner")
end
Washed(card, 3, false, "a blue")
-- Under the mouse its full tide goes to the name's ink, and back.
card.item.scripts.OnEnter(card.item)
Eq(Hex(card.boxTide[2].recorded.calls.SetColorTexture), "0059b1", "the tide line does not answer the mouse")
Eq(Hex(card.boxTide[1].recorded.calls.SetColorTexture), Hex(ns.Style.QualityWash(3).tideIn),
    "the light tide line answers the mouse")
card.item.scripts.OnLeave(card.item)
Washed(card, 3, false, "a blue, the mouse gone")
-- Its box under the heading, turned a little against the slip.
Check(card.under and card.under.Y < card.name.recorded.points[1].args[4], "the box is not under the heading")
Check(card.lean ~= 0 and math.abs(math.deg(card.lean)) <= FC.FIND.lean.most + 1e-9, "the box is not set askew")
Check(card.turn == 0 or (card.lean > 0) ~= (card.turn > 0), "the box leans with the slip")
-- Laid flat: square with the slip, no heavier edge.
ns.SetSetting("flatSheets", true)
ns.UI.RedrawJourneyPage()
card = Shown(page.findPool)[1]
Eq(card.lean, 0, "a box laid flat leans")
Check(not card.boxWeight:IsShown(), "a box laid flat has its heavier edge")
Check(not card.iconShadow:IsShown(), "a box laid flat has a shadow under its icon")
-- Its wash stays (pigment, not light); its tide line goes even.
Washed(card, 3, true, "a blue laid flat")
card.item.scripts.OnEnter(card.item)
Eq(Hex(card.boxTide[1].recorded.calls.SetColorTexture), "0059b1", "a flat box's tide is not even under the mouse")
card.item.scripts.OnLeave(card.item)
ns.SetSetting("flatSheets", false)
ns.UI.RedrawJourneyPage()
card = Shown(page.findPool)[1]

-- Under the mouse: the item's own tooltip, with how and when under it;
-- the box's rule darkens.
card.item.scripts.OnEnter(card.item)
Eq(GameTooltip.link, BLUE, "the box does not show the item's tooltip")
Check(GameTooltip.lines[1] and GameTooltip.lines[1][1]:find("^Your first blue, looted, at level 7, "),
    "the how and when under it: " .. tostring(GameTooltip.lines[1] and GameTooltip.lines[1][1]))
Check(card.hot, "the box does not answer the mouse")
card.item.scripts.OnLeave(card.item)
Check(not card.hot and not GameTooltip.shown, "the tooltip stays")
-- Where the client will not show the link: the name.
do
    local set = GameTooltip.SetHyperlink
    GameTooltip.SetHyperlink = nil
    card.item.scripts.OnEnter(card.item)
    Eq(GameTooltip.text, "Pathfinder Footpads", "no link to show and no name")
    GameTooltip.SetHyperlink = set
    card.item.scripts.OnLeave(card.item)
end

-- Its leader to its pouch.
local plateOfCard
for _, l in ipairs(page.links) do
    if l.strip == card then
        plateOfCard = l.plate
        Check(l.mark == l.plate.findMarks[1].at, "the card's leader does not go to its pouch")
    end
end
Check(plateOfCard, "the card has no leader")

-- Before the killer card: a first outranks a death. In a column it is
-- over the killer's; in the one plate's row under a short caption the two
-- lie side by side, as their marks lie across the plate.
local killers = Shown(page.killerPool)
Eq(#killers, 1, "setup: the Lashtail's card")
if plateOfCard.captionOver then
    local marks = {}
    for _, l in ipairs(page.links) do marks[l.strip] = l.mark end
    Check(marks[card] and marks[killers[1]], "the row's cards have no leaders")
    Check((card.box[1] < killers[1].box[1]) == (marks[card][1] < marks[killers[1]][1]),
        "the row's cards are not in the order of their marks")
else
    Check(card.box[2] < killers[1].box[2], "the killer card is over the first found card")
end
-- The caption names neither the item nor the killer.
local text = Captions()
Check(not text:find("Footpads") and not text:find("Lashtail"), "the caption repeats a card: " .. text)

-- The column runs out: the killer goes first, then the find.
local C = ns.UI.JourneyLook.CAPTION
local limit, offLimit = C.limit, C.offLimit
local bottom = card.box[2] + card.box[4] + 2
C.limit, C.offLimit = bottom, bottom
ns.UI.RedrawJourneyPage()
Eq(#Shown(page.findPool), 1, "the find is left off before the killer")
Eq(#Shown(page.killerPool), 0, "the killer stays with no room")
Check(Captions():find("to a Sunscale Lashtail"), "the left-off killer is not in the caption: " .. Captions())
C.limit, C.offLimit = card.box[2] + 2, card.box[2] + 2
ns.UI.RedrawJourneyPage()
Eq(#Shown(page.findPool), 0, "the find stays with no room")
Eq(page.findsWritten, 0, "a card left off is counted")
C.limit, C.offLimit = limit, offLimit

-- A green found alone on its plate: the card, and the caption without its
-- name; left off, the caption names it.
for i, entry in ipairs(page.recap.entries) do
    if entry.level == 8 then page.open = i end
end
ns.UI.RedrawJourneyPage()
cards = Shown(page.findPool)
Eq(#cards, 1, "no card for the green: " .. Captions())
Eq(ItemWords(cards[1]), "Wolfskin Bracers", "the green's name")
local greenInk = ns.Style.QualityNameInk(2)
Eq(cards[1].itemLines[1].recorded.calls.SetTextColor[2], greenInk[2], "the green's name is not in green ink")
Washed(cards[1], 2, false, "a green")
Eq(Hex(cards[1].iconEdge.recorded.calls.SetColorTexture), "1eff00", "the green's icon is not edged in the game's green")
Eq(cards[1].icon.recorded.calls.SetTexture[1], 132602, "the green's icon")
Check(Captions():find("A first green%.") and not Captions():find("Wolfskin"), "the caption names the card's item: "
    .. Captions())
local top = cards[1].box[2]
C.limit, C.offLimit = top + 2, top + 2
ns.UI.RedrawJourneyPage()
-- A page with a print tucked into the row (F+L) that loses the card there
-- is laid as FL instead, the card in its column higher up: no room there
-- either.
if #Shown(page.findPool) > 0 then
    top = Shown(page.findPool)[1].box[2]
    C.limit, C.offLimit = top + 2, top + 2
    ns.UI.RedrawJourneyPage()
end
Eq(#Shown(page.findPool), 0, "setup: the green's card with no room")
Check(Captions():find("A first green: Wolfskin Bracers%."), "the left-off item is not in the caption: " .. Captions())
C.limit, C.offLimit = limit, offLimit

-- A white item in plain ink; one the client has no icon for, its name
-- alone in the box.
do
    local white = FC.New(page.right)
    local m = Find("bag", loot)
    local item = { link = POUCH, whats = { "bag" }, moments = { m }, rec = m.find, mark = { 0, 0 } }
    mock.itemInfo[4496].icon = 0
    white:SetFind(item, "w", d0, nil)
    white:Layout(300, 10, 260)
    Eq(white.name:GetText(), "Your first bag!", "a bag's card heading")
    local INKS = ns.Style.INK_STRONG
    Eq(white.itemLines[1].recorded.calls.SetTextColor[1], INKS[1], "a white item's name is not in plain ink")
    Check(not white.icon:IsShown(), "an icon the client has not is drawn")
    Eq(white.overfull, false, "a card with no icon is left off")
    -- Its box as before: the grey pen rule and heavier edge round plain
    -- cream, no wash, no tide line.
    Check(white.boxRule:IsShown() and white.boxWeight:IsShown(), "a white item's box has lost its rule")
    Eq(white.boxGround.recorded.width, white.chip.w, "a white item's ground has grown over its rule")
    Eq(white.wash, nil, "a white item has a wash")
    for _, part in ipairs(white.boxWash) do Check(not part:IsShown(), "a white item's box is washed") end
    for _, part in ipairs(white.boxTide) do Check(not part:IsShown(), "a white item's box has a tide line") end
    local rule = white.boxRule.recorded.calls.SetColorTexture
    Eq(rule[4], FC.BOX.rule, "a white item's rule is not in ink")
    mock.itemInfo[4496].icon = 133639
    white:SetFind(item, "w", d0, nil)
    white:Layout(300, 10, 260)
    Eq(Hex(white.iconEdge.recorded.calls.SetColorTexture), Hex(INKS), "a white item's icon is not edged in ink")
    mock.itemInfo[4496].icon = 0
    -- A gift's line under the box, in ink.
    white:SetFind(item, "w", d0, "a gift")
    white:Layout(300, 10, 260)
    Eq(white:What(), "a gift", "a gift's line")
    Check(white.lines[1].recorded.calls.SetTextColor[1] == ns.Style.INK[1], "the gift's line is not in ink")
    -- A name too long for any column: left off.
    local long = Link(4496, "Exceedingly Long Name Of A Bag Nobody Could Ever Fit In A Margin Column")
    white:SetFind({ link = long, whats = { "bag" }, moments = { m }, rec = m.find, mark = { 0, 0 } }, "w", d0, nil)
    white:Layout(300, 10, 122)
    Eq(white.overfull, true, "a name that will not fit is drawn")
    white:Hide()
    mock.itemInfo[4496].icon = nil
end

-- An epic in a narrow column, its icon over its name: the wash's deep
-- length is the margin alone, so the name starts on `left`.
do
    mock.itemInfo[6070].icon = 132602
    local epic = FC.New(page.right)
    local m = Find("epic", loot)
    local link = Link(6070, "Rawhide Shoulderpads", "a335ee")
    epic:SetFind({ link = link, whats = { "epic" }, moments = { m }, rec = m.find, mark = { 0, 0 } }, "e", d0, nil)
    epic:Layout(300, 10, 122)
    Eq(epic.quality, 4, "setup: an epic")
    Check(epic.chip and epic.chip.stacked, "setup: the epic's icon is not over its name")
    Washed(epic, 4, false, "a stacked epic")
    Eq(epic.boxWash[1].recorded.width, 1 + FC.BOX.pad[1], "a stacked epic's deep length runs under its name")
    Eq(Hex(epic.itemLines[1].recorded.calls.SetTextColor), "880dce", "the epic's name ink")
    Eq(Hex(epic.iconEdge.recorded.calls.SetColorTexture), "a335ee", "the epic's icon edge")
    epic:Hide()
end

-- The card's inks are its own: the page's prose keeps the old, darker
-- ones (QUALITY_INK), which the new would fall under 4.5:1 on.
Eq(Hex(ns.Style.QualityInk(2)) .. Hex(ns.Style.QualityInk(3)) .. Hex(ns.Style.QualityInk(4)) .. Hex(ns.Style.QualityInk(5)),
    "1d5d120a3d8f5a1f8a8a4500", "the page's quality inks changed")
Check(ns.Style.Inkify("|cnIQ3:Boots|r"):find("|cff0a3d8f"), "the timeline's blue changed")
Eq(Hex(ns.Style.QualityNameInk(2)) .. Hex(ns.Style.QualityNameInk(3)) .. Hex(ns.Style.QualityNameInk(4))
    .. Hex(ns.Style.QualityNameInk(5)), "086b010059b1880dce8f4501", "the card's name inks")
Eq(ns.Style.QualityWash(1), nil, "a white item has a wash")
Eq(ns.Style.QualityWash(5), nil, "a legendary has a wash")
-- Every name reads at 4.5:1 or better wherever it can lie: on the wash
-- from `left` to `right` (WCAG 2, the wash multiplied into the cream).
do
    local function Lum(c)
        local function L(x) return x <= 0.04045 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * L(c[1]) + 0.7152 * L(c[2]) + 0.0722 * L(c[3])
    end
    local G = FC.BOX.ground
    for q = 2, 4 do
        local wash, ink = ns.Style.QualityWash(q), ns.Style.QualityNameInk(q)
        for _, key in ipairs({ "left", "right" }) do
            local m = wash[key]
            local under = { G[1] * m[1], G[2] * m[2], G[3] * m[3] }
            local ratio = (Lum(under) + 0.05) / (Lum(ink) + 0.05)
            Check(ratio >= 4.6, ("quality %d's name on its wash's %s: %.2f:1"):format(q, key, ratio))
        end
    end
end

-- Pooled: drawing again makes no new cards.
local made = #page.findPool
for _ = 1, 3 do ns.UI.RedrawJourneyPage() end
Eq(#page.findPool, made, "drawing again makes new cards")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("/sd testdata: the made-up firsts have their cards")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()
do
    local found, drawn, said, shoulders, narrow = 0, 0, {}, nil, nil
    for _, at in ipairs(T.DiaryPages(page)) do
        local entry = at.e
        T.OpenDiaryPage(page, at.i, at.k)
        for _, plate in ipairs(page.plates) do
            if plate:IsShown() then
                for _, pouch in ipairs(plate.findMarks or {}) do found = found + #pouch.list end
            end
        end
        for _, c in ipairs(Shown(page.findPool)) do
            drawn = drawn + #c.found.moments
            if c.found.whats[1] == "shoulder" then
                -- Laid again in the narrowest column (122 px), wherever this
                -- page put it (since 11 Oct level 13 is one plate, its
                -- column wide).
                c:Layout(12, 300, 122)
                shoulders = c.chip.stacked and c.headTail:IsShown() and c.icon:IsShown()
                narrow = c.name:GetText() .. (c.chip.tail and (" / " .. c.chip.tail) or "") .. " " .. ItemWords(c)
            end
            said[#said + 1] = (entry.level or "week") .. ": " .. c.name:GetText()
                .. (c.chip.tail and (" / " .. c.chip.tail) or "") .. " " .. ItemWords(c)
                .. (c:What() ~= "" and (" (" .. c:What() .. ")") or "")
        end
    end
    Eq(found, 5, "the made-up firsts' pouches")
    -- Every one: the blue, Tester's gift, was on the top plate of three,
    -- its column holding his strip and no more; since the pages go by
    -- sitting its plate is alone on its sitting's page, with room for both.
    Eq(drawn, 5, "the made-up firsts' cards: " .. table.concat(said, "; "))
    -- The shoulders in the narrowest column (122 px): the heading on two
    -- lines, and the icon over the name, as "Shoulderpads" will not go
    -- beside it.
    Check(narrow == "Your first / shoulders! Rawhide Shoulderpads",
        "the shoulders' heading did not take two lines in a narrow column: " .. tostring(narrow))
    Check(shoulders, "the narrow shoulders' card is not stacked under a two-line heading")
end
ns.UI.CloseJournal()

for _, name in ipairs({ "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "GetInboxItemLink",
    "TakeInboxItem", "AutoLootMailItem", "hooksecurefunc" }) do
    _G[name] = nil
end
