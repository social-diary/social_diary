-- The hunt card (Features/Hunts/HuntCard.lua, JRN-26): a quest's drops that took bad
-- luck, its tally written out in the plate's margin. Its words, its two
-- ways (with the drop rates: the strokes past a stop rule; without: each
-- against usually), the hunt it is for, its icon and the stand-ins for it,
-- its place in the margin (after the close call's card, the first left
-- off), its leader to the tally, its steps down, and the caption that
-- leaves its words to it.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF
local Card = ns.Hunts.HuntCard
local NB = "\194\160"

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)

local HORNS = { kills = 26, need = 5, item = "Intact Raptor Horn", itemID = 5055, name = "Sunscale Scytheclaw",
    npcID = 3256, questID = 865, title = "Raptor Horns", expected = 12, level = 15, t = now - 3600,
    byKind = { [3256] = { n = 17, name = "Sunscale Scytheclaw" }, [3254] = { n = 9, name = "Sunscale Lashtail" } } }
local BANDANAS = { kills = 37, need = 6, item = "Red Linen Bandana", itemID = 1019, name = "Defias Rogue Wizard",
    npcID = 474, questID = 153, title = "Red Linen Goods", level = 9, t = now - 7200 }

--------------------------------------------------------------------------
Section("the words")

Eq(ns.Hunts.Item(HORNS), "Intact Raptor Horns", "the heading: the items wanted")
Eq(ns.Hunts.Item({ need = 1, item = "Hezrul's Head" }), "Hezrul's Head", "one item is named as one")
Eq(ns.Hunts.Item({ need = 7, item = "Plainstrider Meat" }), "Plainstrider Meat", "what is not counted keeps its name")
Eq(ns.Hunts.ExpectedLabel(HORNS), "expected 12", "the stop rule's label")
Eq(ns.Hunts.ExpectedLabel({ expected = 12.5 }), "expected 13", "the label rounds as the words do")
Eq(ns.Hunts.KILLED, "killed", "the figure's word")
local lines = ns.Hunts.KillLines(HORNS)
Eq(#lines, 2, "a line a kind")
Eq(lines[1], "killed 17" .. NB .. "Sunscale Scytheclaws", "the kind killed most first")
Eq(lines[2], "killed 9" .. NB .. "Sunscale Lashtails", "then the other")
Eq(table.concat(ns.Hunts.KillLines(HORNS, true), "|"), "Sunscale Scytheclaws and others", "the short line")
for _, line in ipairs(ns.Hunts.KillLines(HORNS, true)) do Check(not line:find("&"), "an ampersand: " .. line) end
Eq(table.concat(ns.Hunts.KillLines({ kills = 26, need = 5, expected = 12, name = "Sunscale Scytheclaw" }), "|"),
    "Sunscale Scytheclaws", "one kind with the rates: its name, the figure counts them")
Eq(#ns.Hunts.KillLines({ kills = 26, need = 5, expected = 12 }), 0, "nothing to name with the rates")
Eq(table.concat(ns.Hunts.KillLines(BANDANAS), "|"), "killed 37" .. NB .. "Defias Rogue Wizards for" .. NB .. "6",
    "without the rates the line says the whole")
Eq(table.concat(ns.Hunts.KillLines({ kills = 37, need = 6 }), "|"), "killed 37 for" .. NB .. "6", "a nameless hunt")
local four = { kills = 30, need = 5, name = "A", byKind = { [1] = { n = 12, name = "Raptor" }, [2] = { n = 9,
    name = "Wolf" }, [3] = { n = 6, name = "Boar" }, [4] = { n = 3, name = "Bear" } } }
Eq(table.concat(ns.Hunts.KillLines(four), "|"), "killed 12" .. NB .. "Raptors|killed 9" .. NB .. "Wolves|killed 9"
    .. NB .. "others for" .. NB .. "5", "past three kinds the rest together, and without the rates what it was for")
Eq(table.concat(ns.Hunts.KillLines(four, true), "|"), "killed 30" .. NB .. "As and others for" .. NB .. "5",
    "without the rates the short line counts them all")
local title, tip = ns.Hunts.CardTip(BANDANAS, now, 2.2)
Eq(title, ns.Hunts.Line(BANDANAS), "the card's tooltip title")
Check(tip[1] == "For Red Linen Goods" and tip[2] == "Usually 2 each" and tip[3]:find(", level 9$"),
    "the card's tooltip without the rates: " .. table.concat(tip, "; "))
_, tip = ns.Hunts.CardTip(HORNS, now, 2.2)
for _, line in ipairs(tip) do Check(not line:find("^Usually"), "the rates' card says the usual") end

--------------------------------------------------------------------------
Section("the tally's tooltip: every hunt on it told once")

-- Hunts.Tips (the marks' `tips`). A lone hunt: what it was for, the kills
-- each with "Killed" (no figure bare), how far off the rates, the quest,
-- when and the level, each once.
local DOT = ", "
local function At(t) return (ns.UI.Format.At(t, now):gsub("^%l", string.upper)) end
title, tip = ns.Hunts.Tips({ HORNS }, now)
Eq(title, "5" .. NB .. "Intact Raptor Horns", "a lone hunt's title: what it was for")
Eq(tip[1], "Killed 17" .. NB .. "Sunscale Scytheclaws and 9" .. NB .. "Sunscale Lashtails", "its kills by kind")
Eq(tip[2], "14" .. NB .. "more kills than expected", "how far off the rates")
Eq(tip[3], "For \226\128\156Raptor Horns\226\128\157", "the quest, quoted")
Eq(tip[4], At(HORNS.t) .. DOT .. "level 15", "when and the level, once")
Eq(#tip, 4, "four lines")
title, tip = ns.Hunts.Tips({ BANDANAS }, now)
Eq(title, "6" .. NB .. "Red Linen Bandanas", "without the rates")
Eq(tip[1], "Killed 37" .. NB .. "Defias Rogue Wizards", "one kind")
Eq(tip[2], "For \226\128\156Red Linen Goods\226\128\157", "no rates, no line for them")
title, tip = ns.Hunts.Tips({ { kills = 12, need = 1, item = "Kobold Candle", t = now, level = 7 } }, now)
Eq(title, "Kobold Candle", "one item, named as one")
Eq(tip[1], "12" .. NB .. "kills", "kills of no named creature: never \"Killed 12 kills\"")

-- Two hunts on one spot: counted in the title, the kills summed by kind
-- across them, the items, how far off in all, one span and level range.
local SCYTHES = { kills = 20, need = 3, item = "Scytheclaw Talon", name = "Sunscale Scytheclaw", npcID = 3256,
    title = "Talons", expected = 8, level = 16, t = now - 1800 }
title, tip = ns.Hunts.Tips({ HORNS, SCYTHES }, now)
Eq(title, "Two slow hunts", "two on a spot: counted in the title")
Eq(tip[1], "Killed 37" .. NB .. "Sunscale Scytheclaws and 9" .. NB .. "Sunscale Lashtails",
    "the kills summed by kind, most first")
Eq(tip[2], "For 5" .. NB .. "Intact Raptor Horns and 3" .. NB .. "Scytheclaw Talons", "each item once")
Eq(tip[3], "26" .. NB .. "more kills than expected in all", "how far off, in all")
Eq(tip[4], At(HORNS.t):gsub(" at ", " from ") .. os.date(" to %H:%M", SCYTHES.t) .. DOT .. "levels 15 to 16",
    "a span and a level range, not a time each")
Eq(#tip, 4, "four lines")
for _, line in ipairs(tip) do Check(not line:find(" more [a-z]+ hunts?"), "no count of the rest: " .. line) end
-- One without the rates: no sum that would not be the whole.
title, tip = ns.Hunts.Tips({ HORNS, BANDANAS }, now)
Check(not table.concat(tip, "|"):find("expected"), "a sum over some is not told: " .. table.concat(tip, "|"))
Eq(#tip, 3, "the kills, the items, when")
-- Past three kinds, the rest together, every kill counted.
title, tip = ns.Hunts.Tips({ { kills = 30, need = 5, item = "Fang", name = "A", byKind = { [1] = { n = 12,
    name = "Raptor" }, [2] = { n = 9, name = "Wolf" }, [3] = { n = 6, name = "Boar" }, [4] = { n = 3,
    name = "Bear" } }, t = now }, HORNS }, now)
Eq(tip[1], "Killed 17" .. NB .. "Sunscale Scytheclaws, 12" .. NB .. "Raptors and 27" .. NB .. "others",
    "past three kinds, the rest together")
-- Good luck: the star's title says so.
title, tip = ns.Hunts.Tips({ { kills = 4, need = 7, expected = 58.3, name = "Plainstrider", item = "Plainstrider Meat",
    t = now, level = 6 }, { kills = 1, need = 1, expected = 10, name = "Sharptalon", item = "Sharptalon's Claw",
    t = now, level = 6 } }, now, true)
Eq(title, "Two lucky hunts", "two lucky hunts' title")
Eq(tip[1], "Killed 4" .. NB .. "Plainstriders and 1" .. NB .. "Sharptalon", "a kill of one beside others is counted")
Eq(tip[3], "63" .. NB .. "fewer kills than expected in all", "fewer in all")
Eq(tip[4], At(now) .. DOT .. "level 6", "one time, one level")
_, tip = ns.Hunts.Tips({ { kills = 1, need = 1, expected = 10, name = "Sharptalon", item = "Sharptalon's Claw", t = now } },
    now, true)
Eq(tip[1], "Dropped by the first Sharptalon", "one kill alone: no figure")

--------------------------------------------------------------------------
Section("which hunt")

local function Mark(list, x, y) return { list = list, at = { x, y } } end
local low = { kills = 20, need = 4, expected = 11, t = now - 100 }    -- 1.8 past
local high = { kills = 26, need = 5, expected = 12, t = now - 900 }   -- 2.2 past
local mine = { kills = 30, need = 3, t = now - 50 }                   -- 10 an item
local chosen = Card.Choose({ Mark({ { hunt = low } }, 1, 1), Mark({ { hunt = high } }, 2, 2) })
Eq(chosen.hunt, high, "the hunt furthest past what was expected")
Eq(chosen.mark[1], 2, "its tally is the leader's")
chosen = Card.Choose({ Mark({ { hunt = high }, { hunt = mine } }, 3, 3) }, 2)
Eq(chosen.hunt, mine, "ten an item where two is usual is further past than 26 for 12")
Eq(chosen.usual, 2, "the usual goes with it")
chosen = Card.Choose({ Mark({ { hunt = high }, { hunt = mine } }, 3, 3) }, 8)
Eq(chosen.hunt, high, "against a usual of eight, the rates' hunt")
local twin = { kills = 26, need = 5, expected = 12, t = now - 10 }
Eq(Card.Choose({ Mark({ { hunt = high }, { hunt = twin } }, 1, 1) }).hunt, twin, "the latest of equals")
Check(Card.Choose({}) == nil and Card.Choose({ Mark({ { kind = "luck" } }, 1, 1) }) == nil, "no hunt, no card")
Eq(Card.Past({ kills = 30, need = 5 }), 6 / ns.Hunts.T.luckRatio, "before the usual, against the least bad luck")

--------------------------------------------------------------------------
Section("its icon")

mock.itemInfo[5055] = { icon = 133706, quality = 1 }
local icon, id, from = Card.Icon(HORNS)
Check(icon == 133706 and id == 5055 and from == "record", "the hunt's own item: " .. tostring(from))
-- An old record: its name in the client's cache.
local realInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(what)
    if what == "Intact Raptor Horn" then return 5055 end
    return realInstant(what)
end
local old = { item = "Intact Raptor Horn", questID = 865, need = 5, kills = 26 }
icon, id, from = Card.Icon(old)
Check(icon == 133706 and from == "name", "an old record by its name: " .. tostring(from))
C_Item.GetItemInfoInstant = realInstant
-- Else QuestieDB's objectives.
local Bridge = ns.QuestieBridge
local realFor = Bridge.ItemFor
Bridge.ItemFor = function(questID, name) return questID == 865 and name == "Intact Raptor Horn" and 5055 or nil end
icon, id, from = Card.Icon(old)
Check(icon == 133706 and from == "questie", "an old record by its quest: " .. tostring(from))
-- An item the client knows nothing of draws the question mark: no icon.
mock.itemInfo[5055] = nil
icon, id, from = Card.Icon(old)
Check(icon == Card.SACK and id == 5055 and from == "sack", "the question mark is not the sack: " .. tostring(icon))
Bridge.ItemFor = realFor
-- Nothing at all: the sack, last.
icon, id, from = Card.Icon({ item = "Nothing Known", need = 2, kills = 20 })
Check(icon == Card.SACK and id == nil and from == "sack", "with nothing known, the sack")
-- A green item is edged in the game's green; a white one in ink.
mock.itemInfo[77] = { icon = 1, quality = 2 }
Eq(Card.Edge(77)[2], ns.Style.QualityGameColour(2)[2], "a green item's edge")
Eq(Card.Edge(5055), ns.Style.INK, "an uncached item's edge is ink")
mock.itemInfo[5055] = { icon = 133706, quality = 1 }
mock.itemInfo[1019] = { icon = 133693, quality = 1 }

--------------------------------------------------------------------------
Section("the card, two ways")

ns.UI.ShowJournal()
local page = ns.UI.JourneyPage()
local function New(hunt, width, usual)
    local c = Card.New(page.right)
    c:SetHunt({ hunt = hunt, mark = { 0, 0 }, usual = usual }, "t", now)
    c:Layout(10, 10, width or 150)
    return c
end
local function Strokes(c)
    local n = 0
    for _, s in ipairs(c.strokes) do if s:IsShown() then n = n + 1 end end
    return n
end
local function Ops(c, kind)
    local n = 0
    for _, op in ipairs(c.plan.block.ops) do if op.kind == kind then n = n + 1 end end
    return n
end

-- With the rates: every kill a stroke, the stop rule and its printed
-- label, the figure "26 killed", a line a kind.
local q = New(HORNS)
Check(q.rates, "the rates' hunt is not told by them")
Eq(q.name:GetText(), "Intact Raptor Horns", "the heading")
Eq(Strokes(q), 26, "a stroke a kill")
Check(q.rule:IsShown() and q.label:GetText() == "expected 12", "no stop rule where the rates said")
Eq(q.figure:GetText(), "26", "the figure")
Eq(q.figureWord:GetText(), "killed", "the figure's word")
Eq(q.count:GetText(), "5", "the stack count: the items wanted")
Eq(q.icon.recorded.calls.SetTexture[1], 133706, "the item's icon")
Eq(Ops(q, "rule"), 1, "one rule")
-- The rule stands after the twelfth stroke: twelve are before it.
local before = 0
local ruleX
for _, op in ipairs(q.plan.block.ops) do if op.kind == "rule" then ruleX = op.x end end
for _, op in ipairs(q.plan.block.ops) do
    if op.kind == "gate" and op.x < ruleX then before = before + op.k end
end
Eq(before, 12, "the strokes before the rule are those expected")
Eq(table.concat(q:Lines(), "|"), "killed 17" .. NB .. "Sunscale Scytheclaws|killed 9" .. NB .. "Sunscale Lashtails",
    "the card's lines")
Check(not q.overfull, "the rates' card is overfull at 150 px")
for _, row in ipairs(q.rowWords) do Check(not row:IsShown(), "the rates' card has rows") end

-- Without: this hunt's strokes an item and the usual's, in graphite.
local n = New(BANDANAS, 150, 2)
Check(not n.rates, "a hunt without rates is told by them")
Eq(Strokes(n), 6 + 2, "six an item and two usually")
Check(not n.rule:IsShown() and not n.figure:IsShown(), "the rows have a stop rule or figure")
Eq(n.rowWords[1]:GetText(), "each", "the first row's word")
Eq(n.rowWords[2]:GetText(), "usually", "the usual's word")
Check(n.rowWords[2]:IsShown(), "the usual's row is not written")
Eq(n.rowWords[2].recorded.calls.SetTextColor[1], ns.Style.GRAPHITE[1], "the usual is not in graphite")
Eq(table.concat(n:Lines(), "|"), "killed 37" .. NB .. "Defias Rogue Wizards for" .. NB .. "6", "the line under")
Eq(n.count:GetText(), "6", "the stack count")
-- Before five hunts are counted: the one row.
local n0 = New(BANDANAS, 150, nil)
Eq(Strokes(n0), 6, "with no usual, one row")
Check(n0.rowWords[1]:IsShown() and not n0.rowWords[2]:IsShown(), "with no usual, a usual's row")
Check(not n0.overfull and n0.box[4] < n.box[4], "the one row is not shorter")
-- Past ROWS.most strokes an item, the row is a figure.
local slow = New({ kills = 90, need = 3, item = "Gnoll Paw", name = "Gnoll" }, 150, 2)
Eq(slow.rowFigures[1]:GetText(), "30", "thirty an item is a figure")
Eq(Strokes(slow), 2, "only the usual's strokes")
-- One item: no count on the icon.
local one = New({ kills = 14, need = 1, item = "Hezrul's Head", itemID = 5025, name = "Hezrul Bloodmark",
    expected = 4 }, 150)
Check(not one.count:IsShown(), "one item has a stack count")
-- A hunt past TALLY.most: the expected part is the rule alone, the strokes
-- end in an ellipsis, the figure the count.
local long = New({ kills = 140, need = 10, item = "Bear Pelt", name = "Bear", expected = 40 }, 150)
Eq(Strokes(long), Card.TALLY.most, "a long hunt's strokes are capped")
Check(long.ellipsis:IsShown() and long.figure:GetText() == "140", "a long hunt's ellipsis and figure")
Eq(long.plan.block.ops[1].kind, "rule", "a long hunt's expected part is the rule alone")

-- The narrow column: the tally wraps, still a stroke a kill, still in it.
local narrow = New(HORNS, 122)
Eq(Strokes(narrow), 26, "the narrow card's strokes")
Check(not narrow.overfull, "the narrow card is overfull")
Check(narrow.box[3] <= 122, "the narrow card is wider than its column")
Check(narrow.plan.icon == Card.ICON.narrow, "the narrow card's icon is not the smaller")

-- Laid flat: no shadow under the icon; the strokes stay.
ns.SetSetting("flatSheets", true)
local flat = New(HORNS)
Check(not flat.iconShadow:IsShown() and Strokes(flat) == 26, "laid flat")
ns.SetSetting("flatSheets", false)

-- Its steps down: the lines one a kind, one line, none; then no more.
local s = New(HORNS)
local h0 = s.box[4]
Check(s:Smaller(), "no first step")
s:Layout(10, 10, 150)
Eq(table.concat(s:Lines(), "|"), "Sunscale Scytheclaws and others", "the first step's line")
local h1 = s.box[4]
Check(s:Smaller(), "no second step")
s:Layout(10, 10, 150)
Eq(#s:Lines(), 0, "the second step keeps lines")
Check(h1 < h0 and s.box[4] < h1, "the steps are not shorter: " .. h0 .. ", " .. h1 .. ", " .. s.box[4])
Check(not s:Smaller(), "a third step")
Eq(Strokes(s), 26, "the steps cost strokes")
s:SetHunt({ hunt = HORNS, mark = { 0, 0 } }, "t", now)
s:Layout(10, 10, 150)
Eq(#s:Lines(), 2, "a card set again is not whole again")

-- Under the mouse: the item's own tooltip, the card's lines under it.
GameTooltip.text, GameTooltip.link = nil, nil
q.item.scripts.OnEnter(q.item)
Eq(GameTooltip.link, "item:5055", "the icon's tooltip is not the item's")
local said = {}
for _, line in ipairs(GameTooltip.lines or {}) do said[#said + 1] = line[1] end
Check(said[1] == ns.Hunts.Line(HORNS) and said[2]:find("^17" .. NB) and said[3] == "For Raptor Horns",
    "the icon's tooltip lines: " .. table.concat(said, "; "))
q.item.scripts.OnLeave(q.item)
local sack = New({ kills = 30, need = 3, item = "Nothing Known", name = "Gnoll" }, 150, nil)
GameTooltip.text, GameTooltip.link = nil, nil
sack.item.scripts.OnEnter(sack.item)
Check(GameTooltip.link == nil and GameTooltip.text == "Nothing Known", "the sack's tooltip is not the item's name")
Eq(sack.icon.recorded.calls.SetTexture[1], Card.SACK, "the sack is not drawn")
sack.item.scripts.OnLeave(sack.item)

--------------------------------------------------------------------------
Section("on the plate")

local t0 = now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 10,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 10, levelTo = 11 })
j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
Seg({ kind = "stop", from = t0 + 5000, to = t0 + 6000, mapID = 1412, x = 0.62, y = 0.44, r = 20, seconds = 1000,
    levelFrom = 11, levelTo = 11 })
local CALL = { t = t0 + 900, mapID = 1412, x = 0.42, y = 0.58, level = 10, pct = 6, seconds = 42, npcID = 2955,
    foeLevel = 7, name = "Plainstrider", foes = 3 }
-- Two slow hunts: the meat (31 for 7, 4.4 an item) and the beaks (40 for
-- 4, 10 an item): the beaks are further past the least bad luck.
local MEAT = { t = t0 + 1500, mapID = 1412, x = 0.38, y = 0.62, level = 10, questID = 1, title = "Break Sharptusk!",
    item = "Plainstrider Meat", itemID = 4739, need = 7, kills = 31, npcID = 2955, name = "Plainstrider" }
local BEAKS = { t = t0 + 1700, mapID = 1412, x = 0.50, y = 0.50, level = 10, questID = 2, title = "Beaks",
    item = "Plainstrider Beak", itemID = 4740, need = 4, kills = 40, npcID = 2956, name = "Adult Plainstrider" }
j.closeCalls, j.hunts = { CALL }, { MEAT, BEAKS }
ns.Journey.Touch()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")

local function Open(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.entries:SetOffset(page.rubrics[i] - 1)
            for _, row in ipairs(page.entries.rows) do
                if row:IsShown() and row.item and row.item.title and row.item.entry == i then row:Click() end
            end
            return e
        end
    end
end
local function HuntCards()
    local list = {}
    for i = 1, page.huntPool.used do
        if page.huntPool[i]:IsShown() then list[#list + 1] = page.huntPool[i] end
    end
    return list
end
local function FoeCards()
    local list = {}
    for i = 1, page.killerPool.used do
        if page.killerPool[i]:IsShown() and page.killerPool[i].foe then list[#list + 1] = page.killerPool[i] end
    end
    return list
end
local function Caption() return page.captionPool[1]:GetText() end

local e = Open(10)
Eq(#e.hunts, 2, "the level's two slow hunts")
local plate = page.plates[1]
Eq(plate.counts.hunts, 2, "the two tallies")
Check(plate.hunt and plate.hunt.hunt == BEAKS, "the card is not for the worst hunt")
local cards = HuntCards()
Eq(#cards, 1, "one hunt card a plate")
local card = cards[1]
Eq(card.hunt, BEAKS, "the card's hunt")
Eq(card.name:GetText(), "Plainstrider Beaks", "the card's heading")
Eq(page.huntsWritten, 1, "the page's count of hunt cards")
-- Its leader to the beaks' tally, not the meat's.
local link
for _, l in ipairs(page.links) do if l.strip == card then link = l end end
Check(link and link.mark == plate.hunt.mark, "the card has no leader to its tally")
local beaksMark
for _, m in ipairs(plate.huntMarks) do
    for _, moment in ipairs(m.list) do if moment.hunt == BEAKS then beaksMark = m.at end end
end
Eq(plate.hunt.mark, beaksMark, "the leader's tally is the beaks'")
-- In the margin after the close call's card.
local kinds = {}
for _, it in ipairs(plate.margin) do kinds[#kinds + 1] = it.kind end
local ranks = {}
for _, it in ipairs(plate.margin) do ranks[it.kind] = it.rank end
Check(ranks.foe and ranks.hunt and ranks.foe < ranks.hunt, "the hunt does not rank after the close call: "
    .. table.concat(kinds, ","))
-- The words leave the card's hunt to it and say the other.
local words = Caption()
Check(not words:find("Plainstrider Beak"), "the caption says the card's hunt: " .. words)
Check(words:find("31" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat"),
    "the caption lost the other hunt: " .. words)
Check(words:find("close call"), "the caption lost the close call: " .. words)

-- Short of room the hunt card goes first, before the close call's sheds
-- anything, and its words come back to the caption (with the meat's, two
-- slow hunts).
local C = ns.UI.JourneyLook.CAPTION
local limit, offLimit = C.limit, C.offLimit
local huntOff, foeFirst = false, false
for L = 528, 380, -2 do
    C.limit, C.offLimit = L, L
    ns.UI.RedrawJourneyPage()
    local h, f = HuntCards()[1], FoeCards()[1]
    if h and not f then foeFirst = true end
    if f and h then Eq(f:Deed(), "fought against three", "the close call's card shed beside a hunt's at " .. L) end
    if not h then
        huntOff = true
        Check(Caption():find("two slow hunts"), "a left-off hunt is not in the words at " .. L .. ": " .. Caption())
    end
end
Check(huntOff, "the hunt card was never left off")
Check(not foeFirst, "the close call's card was left off before the hunt's")
C.limit, C.offLimit = limit, offLimit
ns.UI.RedrawJourneyPage()
Eq(#HuntCards(), 1, "the hunt card does not come back with room for it")

-- Somewhere on the way down it gave up its lines before it was left off:
-- alone, as beside the close call's card (its heading and tag make it the
-- taller) the hunt's goes for the close call's sake before it is short of
-- room itself.
j.closeCalls = {}
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)
local stepped = false
for L = 528, 380, -2 do
    C.limit, C.offLimit = L, L
    ns.UI.RedrawJourneyPage()
    local h = HuntCards()[1]
    if h and (h.step or 0) > 0 then stepped = true end
end
C.limit, C.offLimit = limit, offLimit
Check(stepped, "the hunt card never gave up a step before it was left off")
j.closeCalls = { CALL }
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)

-- Without the rates and with five hunts kept, the usual is the card's.
j.hunts = { MEAT, BEAKS,
    { t = t0 - 9000, mapID = 1412, x = 0.1, y = 0.1, level = 9, need = 4, kills = 6, item = "A", name = "B" },
    { t = t0 - 8000, mapID = 1412, x = 0.1, y = 0.1, level = 9, need = 4, kills = 7, item = "A", name = "B" },
    { t = t0 - 7000, mapID = 1412, x = 0.1, y = 0.1, level = 9, need = 4, kills = 8, item = "A", name = "B" } }
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)
card = HuntCards()[1]
Check(card and card.usual and card.rowWords[2]:IsShown(), "with five hunts kept, no usual on the card")
Eq(card.usual, ns.Hunts.UsualLuck(j), "the card's usual is the character's")

--------------------------------------------------------------------------
Section("the wide arrangement, and the one plate's row shared")

-- The card's own wish: the full icon with the whole count on one row
-- beside it, "26 killed" on the strokes' row. At that width it is drawn
-- so; a little narrower it wraps.
local Look = ns.UI.JourneyLook
local wide = New(HORNS, 150)
local want = wide:Preferred()
Eq(Card.Preferred({ hunt = HORNS }), want, "the card's wish measured apart is not its own")
Check(want > 150 and want <= Look.ROW.most, "the wide arrangement's width: " .. want)
wide:Layout(10, 10, want)
Eq(wide.plan.block.rows, 1, "at its wish the count is not on one row")
Eq(wide.plan.icon, Card.ICON.size, "at its wish the icon is not the full size")
local gateY, figureY
for _, op in ipairs(wide.plan.block.ops) do
    if op.kind == "gate" and not gateY then gateY = op.y end
    if op.kind == "figure" then figureY = op.y end
end
Eq(figureY, gateY, "\"26 killed\" is not on the strokes' row")
Check(not wide.overfull and wide.box[3] <= want, "the wide card is overfull or wider than its wish")
wide:Layout(10, 10, want - 10)
Check(wide.plan.block.rows > 1, "a little narrower the count does not wrap")
-- Without the rates the rows fit the row's own box: no wish past it.
Check(Card.Preferred({ hunt = BANDANAS, usual = 2 }) <= 142, "the rows wish for more than a row's box")

-- Shared out: two notes in a row of three get a box each, as wide as the
-- hunt card would like, under their marks, in order, inside the row.
local TOP = Look.LAYOUT[1][1].top
local function RowBoxes()
    local boxes = { row = true }
    for k, box in ipairs(TOP.row) do boxes[k] = box end
    return boxes
end
local chosenHorns = { hunt = HORNS, mark = { 0, 0 } }
local shared = Look.Shared({ { kind = "person", x = 330 }, { kind = "hunt", hunt = chosenHorns, x = 120 } }, RowBoxes())
Check(shared.shared and #shared == 2, "two notes do not share the row")
Eq(shared[1].w, math.min(want, Look.ROW.most), "the shared boxes are not the hunt card's wish")
local x0, x1 = TOP.row[1].x, TOP.row[3].x + TOP.row[3].w
Check(shared[1].x >= x0 and shared[2].x + shared[2].w <= x1 and shared[1].x + shared[1].w < shared[2].x,
    "the shared boxes leave the row or overlap")
Check(math.abs(shared[1].x + shared[1].w / 2 - 120) < 1 or shared[1].x == x0, "the first box is not under its mark")
Eq(shared.base, TOP.row[1].w, "the row's own width is not kept for the strips")
-- Three notes, or none wishing wider: the row as it is.
Check(not Look.Shared({ { kind = "person" }, { kind = "person" }, { kind = "hunt", hunt = chosenHorns } },
    RowBoxes()).shared, "three notes share the row")
Check(not Look.Shared({ { kind = "person" }, { kind = "foe" } }, RowBoxes()).shared, "no wish, but shared")
Check(not Look.Shared({ { kind = "hunt", hunt = { hunt = BANDANAS, usual = 2 } } }, RowBoxes()).shared,
    "the rows' card shares the row")
-- One note: never wider than the cap.
local alone = Look.Shared({ { kind = "hunt", hunt = { hunt = { kills = 90, need = 5, expected = 40, item = "Pelt",
    name = "Bear" } }, x = 200 } }, RowBoxes())
Eq(alone[1].w, Look.ROW.most, "a long hunt's box is not capped")

-- On the page: someone fought beside you and the raptors took their time,
-- two notes under a short caption. The hunt card is drawn wide; the
-- stranger's strip keeps the row's own width.
local RATED = { t = t0 + 1700, mapID = 1412, x = 0.50, y = 0.50, level = 10, questID = 865, title = "Raptor Horns",
    item = "Intact Raptor Horn", itemID = 5055, need = 5, kills = 26, expected = 12, npcID = 3256,
    name = "Sunscale Scytheclaw", byKind = HORNS.byKind }
j.closeCalls, j.hunts = {}, { RATED }
ns.Journey.Fight(j, "won", nil, t0 + 1000, { mapID = 1412, x = 0.41, y = 0.61 })
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)
plate = page.plates[1]
Check(plate.captionOver, "setup: the caption is not over the plate")
local kindsShown = {}
for _, it in ipairs(plate.margin) do kindsShown[#kindsShown + 1] = it.kind end
Eq(table.concat(kindsShown, ","), "person,hunt", "setup: the row's notes")
card = HuntCards()[1]
Check(card and card.plan.block.rows == 1 and card.plan.icon == Card.ICON.size,
    "the hunt card in a shared row is not wide: " .. tostring(card and card.plan.block.rows))
Check(card.box[3] > TOP.row[1].w, "the hunt card is no wider than a row's box: " .. card.box[3])
local strip
for i = 1, page.notePool.used do
    if page.notePool[i]:IsShown() then strip = page.notePool[i] end
end
Check(strip and strip.box[3] <= TOP.row[1].w, "the stranger's strip is wider than the row's box")
Check(strip.box[2] >= TOP.row[1].y and card.box[2] >= TOP.row[1].y, "a note of the row lies on the plate")
local a, b = strip.box, card.box
Check(a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1], "the row's notes overlap")
for _, l in ipairs(page.links) do
    if l.strip == card then Eq(l.mark, plate.hunt.mark, "the wide card's leader") end
end
