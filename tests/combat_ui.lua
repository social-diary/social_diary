-- Your Diary's close calls (JRN-25) and bad luck with a quest's drops
-- (JRN-26) on the page: their words (the prose, the plates' captions, the
-- marks' tooltips), their marks on a plate (a cross in outline, a tally),
-- and the card of the creature that nearly got you, in the margin only
-- where no killer's card is (one creature a plate).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local Close = ns.CloseCalls
local NB = "\194\160"

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)

local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern) then return true end
    end
    return false
end

--------------------------------------------------------------------------
Section("the words")

Eq(Text.Plural("Plainstrider"), "Plainstriders", "a plain plural")
Eq(Text.Plural("Timber Wolf"), "Timber Wolves", "a wolf's plural")
Eq(Text.Plural("Defias Highwayman"), "Defias Highwaymen", "a -man's plural")
Eq(Text.Plural("Bristleback Shaman"), "Bristleback Shamans", "a shaman is no -man")
Eq(Text.Plural("Witchwing Harpy"), "Witchwing Harpies", "a -y's plural")
Eq(Text.Plural("Servant of Grol"), "Servants of Grol", "a name with an of")
Eq(Text.Plural("Kolkar Marauder"), "Kolkar Marauders", "only the last word changes")

local STRIDER = { name = "Plainstrider", pct = 6, seconds = 42, level = 6, t = now - 3600 }
Eq(Close.Sentence(STRIDER), "Got away from a Plainstrider with 6%" .. NB .. "health.", "a close call")
Eq(Close.Sentence({ name = "Plainstrider", pct = 6, foes = 3 }),
    "Got away from a Plainstrider and two others with 6%" .. NB .. "health.", "a close call against three")
Eq(Close.Sentence({ name = "Plainstrider", pct = 6, foes = 2 }),
    "Got away from a Plainstrider and another with 6%" .. NB .. "health.", "a close call against two")
Eq(Close.Sentence({ name = "Hogger", rank = "rare", pct = 3 }), "Got away from Hogger with 3%" .. NB .. "health.",
    "a rare is named bare")
Eq(Close.Sentence({ pct = 9 }), "Got out of a fight with 9%" .. NB .. "health.", "a close call with no creature")
Eq(Close.Deed(STRIDER), "", "one foe has a deed")
Eq(Close.Deed({ seconds = 95, foes = 3 }), "fought against three", "the foe card's deed against three")
Eq(Close.Deed({ seconds = 120, foes = 2 }), "fought against two", "the foe card's deed against two")
Eq(Close.Deed({}), "", "a deed with nothing kept")
-- The tag: the level and the rank, a skull's level as "??".
Eq(Close.Tag({ foeLevel = 45, rank = "elite" }), "Lv 45 (Elite)", "an elite's tag")
Eq(Close.Tag({ foeLevel = 30, rank = "rare" }), "Lv 30 (Rare)", "a rare's tag")
Eq(Close.Tag({ foeLevel = 31, rank = "rareelite" }), "Lv 31 (Rare Elite)", "a rare elite's tag")
Eq(Close.Tag({ foeLevel = -1, rank = "worldboss" }), "Lv ?? (Boss)", "a skull boss's tag")
Eq(Close.Tag({ foeLevel = 12 }), "Lv 12", "a common creature's tag")
Eq(Close.Tag({ rank = "elite" }), "Elite", "a rank with no level kept")
Check(Close.Tag({ name = "Plainstrider" }) == nil, "an old record with neither has a tag")

local title, lines = Close.Tip({ name = "Kolkar Stormer", rank = "elite", foeLevel = 14, pct = 4, seconds = 75,
    foes = 2, level = 12, t = now - 3600 }, now)
Eq(title, "A close call", "a close call's tooltip title")
Eq(lines[1], "4% health left, against a Kolkar Stormer and another", "the close call's line")
Eq(lines[2], "Lv 14 (Elite)", "the close call's level and rank")
Check(lines[3]:find("at level 12$") and #lines == 3, "the close call's when, last: " .. tostring(lines[3]))
title, lines = Close.Tip({ pct = 8, seconds = 20, level = 3, t = now }, now)
Eq(lines[1], "8% health left", "a nameless close call's line")
Eq(#lines, 2, "the fight's length is told")
title, lines = Close.FoeTip({ name = "Plainstrider", pct = 6, seconds = 42, foes = 3, level = 6, t = now }, now)
Eq(title, "Plainstrider", "the foe card's tooltip title")
Eq(lines[1], "Left you with 6% health", "the foe card's line")
Eq(lines[2], "Two more were in the fight", "the foe card's others")
Eq(#lines, 3, "the foe card's tooltip tells the fight's length")
for _, line in ipairs(lines) do Check(not line:find("[Ff]ought for"), "the time is in the tooltip: " .. line) end

local MEAT = { kills = 31, need = 7, item = "Plainstrider Meat", name = "Plainstrider", npcID = 2955,
    title = "Break Sharptusk!", level = 6, t = now - 1800, questID = 1 }
Eq(ns.Hunts.Words(MEAT), "31" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat", "a hunt in a few words")
Eq(ns.Hunts.Words({ kills = 26, need = 5, item = "Intact Raptor Horn", name = "Sunscale Scytheclaw" }),
    "26" .. NB .. "Sunscale Scytheclaws for 5" .. NB .. "Intact Raptor Horns", "an item counted is plural")
Eq(ns.Hunts.Words({ kills = 20, need = 4, item = "Zhevra Hooves", name = "Zhevra Runner" }),
    "20" .. NB .. "Zhevra Runners for 4" .. NB .. "Zhevra Hooves", "an item already plural")
Eq(ns.Hunts.Words({ kills = 12, need = 1, item = "Kobold Candle" }), "12" .. NB .. "kills for one" .. NB .. "Kobold Candle",
    "a hunt with no creature named, for one")
title, lines = ns.Hunts.Tip(MEAT, now)
Eq(title, ns.Hunts.Words(MEAT), "the tally's tooltip title")
Eq(lines[1], "For Break Sharptusk!", "the tally names the quest")
Check(lines[2]:find("at level 6$"), "the tally's when: " .. tostring(lines[2]))

-- The level's prose: each close call, then each hunt, in one paragraph
-- (the two kinds' `run`, "combat"); past two, counted.
Eq(Close.Lines({ closeCalls = { STRIDER } }), "Got away from a Plainstrider with 6%" .. NB .. "health.",
    "the close calls' prose")
Eq(ns.Hunts.Lines({ hunts = { MEAT } }), "It took 31" .. NB .. "Plainstriders to get 7" .. NB
    .. "Plainstrider Meat.", "the hunts' prose")
Eq(Close.Lines({ closeCalls = { STRIDER, STRIDER, STRIDER, STRIDER } }):match("And .-%.$"),
    "And two more close calls.", "close calls past two are counted")
Check(Close.Lines({ closeCalls = {} }) == nil and ns.Hunts.Lines({ hunts = {} }) == nil,
    "nothing to say says something")

-- The captions: after the deaths, or leading where nothing else does.
local function Caption(moments, foe)
    return Text.PlateCaption({ moments = moments }, nil, { close = foe })
end
local CLOSE = { kind = "close", call = STRIDER }
local LUCK = { kind = "luck", hunt = MEAT }
-- With its creature's card beside the plate the words only say there was
-- a close call; without it they name the creature, as a killer's is.
Eq(Caption({ { kind = "level", level = 6 }, CLOSE }, true), "A close call.", "the level and a close call")
Eq(Caption({ { kind = "level", level = 6 }, CLOSE }), Caption({ CLOSE }),
    "the level and a close call with no card")
Eq(Caption({ { kind = "level", level = 6 }, LUCK }),
    "31" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat.", "the level and bad luck")
Eq(Caption({ { kind = "level", level = 6 }, { kind = "death" }, CLOSE, LUCK }, true),
    "A death, a close call, and 31" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat.",
    "the level, a death, a close call and bad luck")
Eq(Caption({ { kind = "death" }, CLOSE }, true), "A death, and a close call.", "a death and a close call")
Eq(Caption({ { kind = "death" }, CLOSE }), "A death, and a close call with a Plainstrider.",
    "a death and a close call with no card")
Eq(Caption({ { kind = "death" }, { kind = "death" } }), "Two deaths.", "deaths alone as before")
Eq(Caption({ CLOSE }), "Got away from a Plainstrider with 6%" .. NB .. "health.", "a close call alone")
Eq(Caption({ CLOSE }, true), "A close call.", "a close call beside its card")
Eq(Caption({ CLOSE, { kind = "close", call = STRIDER } }), "Two close calls.", "two close calls")
Eq(Caption({ CLOSE, LUCK }), "Got away from a Plainstrider with 6%" .. NB .. "health, and 31" .. NB
    .. "Plainstriders for 7" .. NB .. "Plainstrider Meat.", "a close call and bad luck")
Eq(Caption({ LUCK }), "31" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat.", "bad luck alone")

--------------------------------------------------------------------------
Section("on the plate")

ns.UI.ShowJournal()
local page = ns.UI.JourneyPage()
local t0 = now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
local STOP = Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 10,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 10, levelTo = 11 })
j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
Seg({ kind = "stop", from = t0 + 5000, to = t0 + 6000, mapID = 1412, x = 0.62, y = 0.44, r = 20, seconds = 1000,
    levelFrom = 11, levelTo = 11 })
local CALL = { t = t0 + 900, mapID = 1412, x = 0.42, y = 0.58, level = 10, pct = 6, seconds = 42, npcID = 2955,
    foeLevel = 7, name = "Plainstrider", foes = 3, display = 1961 }
local HUNT = { t = t0 + 1500, mapID = 1412, x = 0.38, y = 0.62, level = 10, questID = 1, title = "Break Sharptusk!",
    item = "Plainstrider Meat", need = 7, kills = 31, npcID = 2955, name = "Plainstrider" }
j.closeCalls, j.hunts = { CALL }, { HUNT }
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
local function Cards()
    local list = {}
    for i = 1, page.killerPool.used do
        if page.killerPool[i]:IsShown() then list[#list + 1] = page.killerPool[i] end
    end
    return list
end
local function Tips(plate)
    local said = {}
    for i = 1, plate.hover.used do
        local list = plate.hover[i].tip and plate.hover[i].tip()
        if list then
            local parts = {}
            for _, line in ipairs(list) do parts[#parts + 1] = line[1] end
            said[#said + 1] = table.concat(parts, "|")
        end
    end
    return said
end

local e = Open(10)
Eq(#e.closeCalls, 1, "the level's close call")
Eq(#e.hunts, 1, "the level's bad luck")
Eq(page.layout, 1, "level 10 is not one plate")
local plate = page.plates[1]
Eq(plate.counts.closeCalls, 1, "the close call's cross is not drawn")
Eq(plate.counts.hunts, 1, "the tally is not drawn")
-- Each mark claims its room, apart from the others.
local spots = 0
for _, spot in ipairs(plate.spots) do
    if spot[3] > 6 then spots = spots + 1 end
end
Check(spots >= 2, "the marks claimed no room")
local tips = Tips(plate)
Check(Any(tips, "^A close call|6%% health left, against a Plainstrider and two others|Lv 7|"),
    "the cross's tooltip: " .. table.concat(tips, "; "))
Check(Any(tips, "^31" .. NB .. "Plainstriders for 7" .. NB .. "Plainstrider Meat|For Break Sharptusk!|"),
    "the tally's tooltip: " .. table.concat(tips, "; "))

-- The prose says both.
local said = {}
for _, item in ipairs(page.items) do
    if item.text then said[#said + 1] = item.text end
end
Check(Any(said, "Got away from a Plainstrider and two others with 6%%"), "the prose has no close call")
Check(Any(said, "It took 31" .. NB .. "Plainstriders to get 7" .. NB .. "Plainstrider Meat%."),
    "the prose has no bad luck")

-- No killer here: the creature that nearly got you has the card, cut in
-- ink from its display, with a leader to its cross in outline.
local cards = Cards()
Eq(#cards, 1, "no card for what nearly got you")
Eq(page.foesWritten, 1, "the page's count of foe cards")
Eq(page.killersWritten, 0, "the foe card is counted as a killer's")
local card = cards[1]
Eq(card.name:GetText(), "Plainstrider", "the card's creature")
Eq(card:Deed(), "fought against three", "the card's deed")
Eq(card.mode, "ink", "the card is not cut in ink")
Eq(card.model.model.SetDisplayInfo[1], 1961, "the model is not drawn from the close call's display")
local link
for _, l in ipairs(page.links) do if l.strip == card then link = l end end
Check(link and link.mark == plate.foe.mark, "the card has no leader to the close call's cross")
GameTooltip.text = nil
card.link.scripts.OnEnter(card.link)
Eq(GameTooltip.text, "Plainstrider", "the card has no tooltip")
card.link.scripts.OnLeave(card.link)
-- The chart under the name (VITALS): the bar ruled in ink, filled in
-- rubric to the health left, the tick at a tenth, the figure large beside
-- it; the tag over its top left corner.
local Card = ns.Deaths.Card
local V, v = Close.Card.VITALS, card.vitals
Check(v and v.edge:IsShown() and v.fill:IsShown() and v.tick:IsShown(), "the card has no bar")
Eq(v.figure:GetText(), "6%", "the card's figure")
Eq(v.figure.recorded.calls.SetTextColor[1], ns.Style.RUBRIC[1], "the figure is not in rubric")
local function Width(region) return region.recorded.width end
local barW = Width(v.paper)
Eq(barW, V.bar.w, "the bar's width")
Check(math.abs(Width(v.fill) - barW * 0.06) < 1e-6, "the fill is not the health left: " .. Width(v.fill))
Check(v.tagPaper:IsShown() and v.tagText:GetText() == "Lv 7", "a common creature with a level has no tag")
-- The heading over everything, in the hand, as the margin's other cards
-- have theirs; clear of the slip's tape.
local B = card.box
local pad = { card:Pad() }
Check(v.heading:IsShown(), "the card has no heading")
Eq(v.heading:GetText(), "A close call", "the card's heading")
Eq(v.heading.recorded.calls.SetFontObject[1], ns.Style.FONT.noteWritten, "the heading is not in the hand")
local head = card.heading
Eq(head[2], -B[4] / 2 + pad[2], "the heading is not at the slip's top")
Eq(head[1], -B[3] / 2 + pad[1], "the heading is not at the slip's left")
local tapeLeft = card.tapeRect[1] - B[1] - B[3] / 2
Check(head[3] < tapeLeft, "the heading runs into the slip's tape")
-- The tag: inside the slip, under the picture and over the name, at the
-- name's left; nothing over the slip's corner.
local tag = card.tag
local pic = card.picture
Check(tag.box[1] >= -B[3] / 2 and tag.box[2] >= -B[4] / 2, "the tag is not on the slip")
Check(head[4] <= pic.ly - pic.h / 2, "the picture is not under the heading")
Check(pic.ly + pic.h / 2 < tag.box[2], "the tag is not under the picture")
local over = card.note.picture
Check(tag.box[4] <= -B[4] / 2 + pad[2] + over.h and over.gap > 0, "the tag runs into the name")
Check(math.abs(tag.box[1] - (-B[3] / 2 + pad[1])) < 1e-6, "the tag is not at the name's left")
Check(v.figure:IsShown(), "the chart is gone with the tag")
Check(card.under and card.under.h >= V.figure.size, "the strip kept no room for the chart")
Check(#card.name:GetText() > 0 and card.box[4] > 60, "the card did not grow for its chart")
-- The words name the plate's moments but not the card's creature again.
-- The hunt has its own card (Features/Hunts/HuntCard.lua, tests/hunt_card.lua), so
-- its words are on the card, not in the caption.
local caption = page.captionPool[1]:GetText()
Eq(page.huntsWritten, 1, "the hunt has no card beside the close call's")
Check(caption:find("close call") and not caption:find("Plainstrider Meat"), "the caption: " .. caption)

-- With no room for it, it is left off, and the caption still says it.
local C = ns.UI.JourneyLook.CAPTION
local limit, offLimit = C.limit, C.offLimit
C.limit, C.offLimit = 380, 380
ns.UI.RedrawJourneyPage()
Eq(#Cards(), 0, "the foe card is drawn with no room for it")
Eq(page.foesWritten, 0, "a foe card left off is counted")
Check(page.captionPool[1]:GetText():find("^Got away from a Plainstrider"),
    "the caption lost the close call: " .. page.captionPool[1]:GetText())
C.limit, C.offLimit = limit, offLimit
ns.UI.RedrawJourneyPage()
Eq(#Cards(), 1, "the foe card does not come back with room for it")

-- A death on the plate with its killer kept: the killer's card, and the
-- close call's beside it, each with its leader to its own cross (a death
-- and a close call are two fights; the user's choice, 11 Oct). The words
-- name neither creature.
STOP.act.deaths = 1
j.deaths = { { t = t0 + 600, mapID = 1412, x = 0.40, y = 0.60, npcID = 3255, name = "Sunscale Lashtail",
    spell = "Bite", display = 1234 } }
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)
plate = page.plates[1]
local function Creatures()
    local killer, foe
    for _, c in ipairs(Cards()) do
        if c.foe then foe = c else killer = c end
    end
    return killer, foe
end
local function LinkOf(c)
    for _, l in ipairs(page.links) do if l.strip == c then return l end end
end
local killerCard, foeCard = Creatures()
Eq(#Cards(), 2, "a killer's and a close call's cards on one plate")
Eq(killerCard and killerCard.name:GetText(), "Sunscale Lashtail", "the killer's card")
Eq(foeCard and foeCard.name:GetText(), "Plainstrider", "the close call's card beside the killer's")
Eq(page.killersWritten, 1, "the page's count of killer cards")
Eq(page.foesWritten, 1, "the page's count of foe cards beside a killer's")
Check(not (killerCard.vitals and killerCard.vitals.fill:IsShown()), "the killer's card kept a close call's chart")
Check(foeCard.vitals and foeCard.vitals.fill:IsShown(), "the close call's card has no chart")
Check(LinkOf(killerCard) and LinkOf(killerCard).mark == plate.killer.mark, "the killer's leader is not to its cross")
Check(LinkOf(foeCard) and LinkOf(foeCard).mark == plate.foe.mark, "the close call's leader is not to its cross")
Check(plate.killer.mark ~= plate.foe.mark, "setup: the death and the close call share a cross")
caption = page.captionPool[1]:GetText()
Check(not caption:find("Lashtail") and not caption:find("close call with"), "the words name a card's creature: "
    .. caption)

-- Short of room, the close call's card goes first (after its picture and
-- deed), then the killer's, never the other way; with its card left off,
-- the close call's creature is named in the words. In the row under a short
-- caption the two lie side by side, so this is tried with the caption
-- under the plate too (a long one, wrapped as the client wraps).
local function Sweep(where)
    local foeFirst = false
    for L = 528, 380, -2 do
        C.limit, C.offLimit = L, L
        ns.UI.RedrawJourneyPage()
        local k, f = Creatures()
        Check(not f or k, "the killer's card was left off before the close call's, " .. where .. ", at " .. L)
        if k and not f then
            foeFirst = true
            local words = page.captionPool[1]:GetText()
            Check(words:find("close call with a Plainstrider"), "a left-off close call is not named, " .. where
                .. ": " .. words)
            Check(not words:find("Lashtail"), "the shown killer is named, " .. where .. ": " .. words)
        end
    end
    C.limit, C.offLimit = limit, offLimit
    return foeFirst
end
Sweep("in the row")
do
    local real = Text.PlateCaption
    Text.PlateCaption = function(...)
        return real(...) .. " And then the road went on a long way, past the mill and over the hill and home."
    end
    local heights = {}
    for i = 1, page.captionPool.used do
        heights[i] = page.captionPool[i].GetStringHeight
        page.captionPool[i].GetStringHeight = function(self)
            local width = (self.width or 0) > 0 and self.width or 1e9
            return self.text ~= "" and 14 * math.ceil(#self.text * 6 / width) or 0
        end
    end
    ns.UI.RedrawJourneyPage()
    Check(not page.plates[1].captionOver, "setup: the long caption is over the plate")
    Check(Sweep("in the column"), "no room was found where the close call's card was left off and the killer's kept")
    Text.PlateCaption = real
    for i = 1, #heights do page.captionPool[i].GetStringHeight = heights[i] end
end
ns.UI.RedrawJourneyPage()
Eq(#Cards(), 2, "the two cards do not come back with room for them")

-- The same creature that killed you and nearly did: still two cards, two
-- fights.
j.deaths[1].npcID, j.deaths[1].name, j.deaths[1].display = 2955, "Plainstrider", 1961
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)
killerCard, foeCard = Creatures()
Check(killerCard and foeCard, "one creature's death and close call do not have a card each")
Eq(killerCard.name:GetText(), "Plainstrider", "the same creature's killer card")
Eq(foeCard.name:GetText(), "Plainstrider", "the same creature's close call card")
Check(killerCard.note.seed ~= foeCard.note.seed,
    "the same creature's two cards share a seed")
Check(LinkOf(killerCard).mark == page.plates[1].killer.mark and LinkOf(foeCard).mark == page.plates[1].foe.mark,
    "the same creature's leaders do not go to their own crosses")
j.deaths[1].npcID, j.deaths[1].name, j.deaths[1].display = 3255, "Sunscale Lashtail", 1234
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)

-- Each close call charts its own: 1% still shows, a rank on its tag, a
-- narrow column a shorter bar.
local function Foe(call, width)
    local c = Card.New(page.right)
    c:SetFoe({ name = call.name, rank = call.rank, call = call, mark = { 0, 0 } }, "t", now)
    c:Layout(10, 10, width or 150)
    return c
end
local one = Foe({ name = "Death Flayer", rank = "rare", foeLevel = 12, pct = 1, seconds = 38, foes = 2 })
Eq(Width(one.vitals.fill), V.bar.least, "1% does not show")
Eq(one.vitals.figure:GetText(), "1%", "the 1% figure")
Eq(one.tag and one.tag.text, "Lv 12 (Rare)", "a rare's tag")
Eq(one:Deed(), "fought against two", "the rare's deed")
local elite = Foe({ name = "Battleguard", rank = "elite", foeLevel = 29, pct = 9, seconds = 95, foes = 3 }, 122)
Eq(elite.tag and elite.tag.text, "Lv 29 (Elite)", "an elite's tag in a narrow column")
local narrowTape = elite.tapeRect[1] - elite.box[1] - elite.box[3] / 2
Check(elite.heading[3] < narrowTape, "the narrow card's heading runs into its tape")
-- Too narrow for the tag on one line: the rank under the level.
local rareElite = Foe({ name = "Battleguard", rank = "rareelite", foeLevel = 31, pct = 9 }, 122)
Eq(rareElite.tag and rareElite.tag.text, "Lv 31\n(Rare Elite)", "a rare elite's tag in a narrow column")
Check(rareElite.tag.box[3] - rareElite.tag.box[1] <= 122 - pad[1] - pad[3], "the split tag is wider than the column")
rareElite:Layout(10, 10, 200)
Eq(rareElite.tag.text, "Lv 31 (Rare Elite)", "a rare elite's tag in a wide column")
rareElite:Hide()
-- The tag has a line of its own over the name: the card as much taller,
-- laid where it was put (nothing stands over its edge any more).
local untagged = Foe({ name = "Battleguard", pct = 9, foes = 3 }, 122)
Check(untagged.tag == nil and not untagged.vitals.tagPaper:IsShown(), "an old record has a tag")
Check(untagged.vitals.heading:IsShown(), "an old record's card has no heading")
local _, hTag = elite:Layout(10, 10, 122)
local _, hBare = untagged:Layout(10, 10, 122)
Check(hTag > hBare, "the tag has no line of its own")
Eq(elite.box[2], 10, "the card is laid lower than it was put")
Eq(hTag, elite.box[4], "the card is not as tall as its slip")
untagged:Hide()
local boss = Foe({ name = "Lord Kazzak", rank = "worldboss", foeLevel = -1, pct = 3 })
Eq(boss.tag and boss.tag.text, "Lv ?? (Boss)", "a skull boss's tag")
Eq(boss:Deed(), "", "one foe has a deed line")
boss:Hide()
Eq(Width(elite.vitals.paper), V.narrow, "the narrow column's bar")
Check(math.abs(Width(elite.vitals.fill) - V.narrow * 0.09) < 1e-6, "the 9% fill")
Check(elite.note.under.w <= 122 - pad[1] - pad[3], "the chart does not fit the narrow column")
Check(Width(elite.vitals.fill) > Width(one.vitals.fill), "9% and 1% look alike")
-- Laid flat, the same chart.
ns.SetSetting("flatSheets", true)
elite:Layout(10, 10, 122)
Check(elite.vitals.fill:IsShown() and elite.turn == 0, "laid flat, the chart is gone or turned")
ns.SetSetting("flatSheets", false)
-- Short of room, it gives up its picture, then its deed, never its chart.
local pictured = Card.New(page.right)
pictured:SetFoe({ name = "Plainstrider", call = { pct = 5, seconds = 30, foes = 2, foeLevel = 8 }, display = 77,
    mark = { 0, 0 } }, "t", now)
local _, tall = pictured:Layout(10, 10, 150)
Eq(pictured.mode, "ink", "the foe card with a display is not cut in ink")
Eq(pictured.picture.h, Card.KILLER.picture.h, "the picture is not at its full size")
-- Where the margin says it has less room, the picture drawn small first,
-- the tag still between it and the name; with the room, at full size.
local _, small = pictured:Layout(10, 10, 150, tall - 1)
Check(pictured.compact and pictured.picture.h == V.compact.h and small < tall,
    "short of room, the picture is not drawn small")
Check(pictured.picture.ly + pictured.picture.h / 2 < pictured.tag.box[2], "the small picture runs into the tag")
Check(pictured.heading[4] <= pictured.picture.ly - pictured.picture.h / 2, "the small picture runs into the heading")
pictured:Layout(10, 10, 150, tall)
Check(not pictured.compact and pictured.picture.h == Card.KILLER.picture.h, "with room, the picture stays small")
pictured:Layout(10, 10, 150)
Check(pictured:Smaller() and pictured.mode == "name", "short of room, the picture stays")
local _, shorter = pictured:Layout(10, 10, 150)
Check(shorter < tall, "without its picture the card is no shorter")
Check(pictured:Smaller(), "short of room, the deed is not given up")
pictured:Layout(10, 10, 150)
Eq(pictured:Deed(), "", "short of room, the deed stays")
Check(not pictured:Smaller(), "the card gives up more than its picture and its deed")
Check(pictured.vitals.fill:IsShown() and pictured.vitals.figure:GetText() == "5%", "the chart was given up")
pictured:SetFoe({ name = "Plainstrider", call = { pct = 5, seconds = 30 }, display = 77, mark = { 0, 0 } }, "t", now)
Eq(pictured.mode, "ink", "drawn again, the card stays without its picture")
pictured:Hide()
one:Hide()
elite:Hide()
Eq(page.plates[1].counts.closeCalls, 1, "the close call's cross went with its card")

-- A close call with no creature: its cross, and no card.
STOP.act.deaths, j.deaths = nil, nil
CALL.name, CALL.npcID, CALL.display, CALL.foes, CALL.foeLevel = nil, nil, nil, nil, nil
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(10)
Eq(#Cards(), 0, "a close call with no creature has a card")
Eq(page.plates[1].counts.closeCalls, 1, "a close call with no creature has no cross")
tips = Tips(page.plates[1])
Check(Any(tips, "^A close call|6%% health left|[^|]*at level 10$"), "the nameless cross's tooltip: "
    .. table.concat(tips, "; "))

-- Another level's are not on this one's plate (only the open level).
Open(11)
Eq(page.plates[1].counts.closeCalls or 0, 0, "level 10's close call is on level 11's plate")
Eq(page.plates[1].counts.hunts or 0, 0, "level 10's tally is on level 11's plate")

--------------------------------------------------------------------------
Section("/sd testdata: the made-up close calls, bad and good luck and finales show")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()
do
    local crosses, tallies, foes, words, hunts = 0, 0, {}, {}, {}
    -- The good luck's stars and the chains' tailpieces, by level, and what
    -- their marks say under the mouse.
    local stars, tailpieces, marked = {}, {}, {}
    for _, at in ipairs(T.DiaryPages(page)) do
        local entry = at.e
        T.OpenDiaryPage(page, at.i, at.k)
        for _, p in ipairs(page.plates) do
            if p:IsShown() then
                crosses = crosses + (p.counts.closeCalls or 0)
                tallies = tallies + (p.counts.hunts or 0)
                local level = entry.level or "week"
                if (p.counts.fortunes or 0) > 0 then stars[#stars + 1] = level .. "x" .. p.counts.fortunes end
                if (p.counts.finales or 0) > 0 then tailpieces[#tailpieces + 1] = level .. "x" .. p.counts.finales end
                for _, tip in ipairs(Tips(p)) do marked[#marked + 1] = level .. ": " .. tip end
            end
        end
        for _, c in ipairs(Cards()) do
            if c.foe then
                local v = c.vitals
                foes[#foes + 1] = (entry.level or "week") .. ":" .. c.name:GetText() .. ":" .. c.mode .. ":"
                    .. v.figure:GetText() .. ":" .. (c.tag and c.tag.text or "-") .. ":" .. c:Deed()
            end
        end
        for k = 1, page.huntPool.used do
            local c = page.huntPool[k]
            if c:IsShown() then
                hunts[#hunts + 1] = (entry.level or "week") .. ":" .. c.name:GetText() .. ":" .. table.concat(c:Lines(), "|")
            end
        end
        for k = 1, page.captionPool.used do
            local w = page.captionPool[k]
            if w:IsShown() then words[#words + 1] = (entry.level or "week") .. ": " .. (w:GetText() or "") end
        end
    end
    Eq(crosses, 6, "the made-up close calls' crosses")
    Eq(tallies, 1, "only the bad luck has a tally")
    -- Good luck (EXT-3): a star for each of level 14's two lucky hunts,
    -- its tooltip the hunt's; never a tally. Levels 11, 12 and 13 have one
    -- each, for the lucky card's sizes (Features/Hunts/LuckyCard.lua, 13 Oct).
    Eq(table.concat(stars, ","), "11x1,12x1,13x1,14x2", "the good luck's stars")
    Check(Any(marked, "^14: 4" .. NB .. "Kolkar Marauders for 7" .. NB .. "Kolkar Booty Keys, 54" .. NB
        .. "fewer than expected|For Counterattack!|"), "the star's tooltip: " .. table.concat(marked, "; "))
    Check(Any(marked, "^14: 1" .. NB .. "Hezrul Bloodmark for one" .. NB .. "Hezrul's Head, 9" .. NB
        .. "fewer than expected|For Hezrul's Head|"), "the first-kill star's tooltip: " .. table.concat(marked, "; "))
    -- A chain's end (JRN-28): a tailpiece at levels 10 and 13, its tooltip
    -- the chain's, where it began when the diary saw it.
    Eq(table.concat(tailpieces, ","), "10x1,13x1", "the chains' tailpieces")
    Check(Any(marked, "^10: The end of \226\128\156The Demon Seed\226\128\157|A chain of 7 quests|On "),
        "the tailpiece's tooltip: " .. table.concat(marked, "; "))
    Check(Any(marked, "^13: The end of \226\128\156Samophlange Manual\226\128\157|A chain of 8 quests|Begun in The "
        .. "Barrens, "), "the begun chain's tailpiece: " .. table.concat(marked, "; "))
    -- (Humar's week is a full plate and a light one, laid as F+L: the
    -- full plate under its caption, its notes in a row under it, the
    -- light plate's print beside them (UI/Journey/Look.lua's LAYOUT).
    -- In the row Humar's card has room for its deed; on the two-plate
    -- page before (LAYOUT[2], its column 176 by 222) it gave the deed up.)
    table.sort(foes)
    Eq(table.concat(foes, ", "),
        "12:Razormane Battleguard:name:4%:Lv 29 (Elite):fought against three, 14:Murloc Streamrunner:ink:6%:Lv 13:, "
        .. "15:Sunscale Scytheclaw:name:7%:-:fought against two, week:Humar the Pridelord:name:1%:Lv 23 (Rare):fought "
        .. "against two, week:Lord Kazzak:name:3%:Lv ?? (Boss):",
        "the made-up foe cards")
    -- The bad luck has its card (Features/Hunts/HuntCard.lua), the two kinds of raptor
    -- a line each (or, short of room, the one killed most and others), so
    -- the words leave it off.
    Eq(#hunts, 1, "the made-up bad luck's card: " .. table.concat(hunts, "; "))
    Check(hunts[1] == "15:Intact Raptor Horns:killed 17" .. NB .. "Sunscale Scytheclaws|killed 9" .. NB
        .. "Sunscale Lashtails" or hunts[1] == "15:Intact Raptor Horns:Sunscale Scytheclaws and others"
        or hunts[1] == "15:Intact Raptor Horns:", "the made-up bad luck's card: " .. tostring(hunts[1]))
    Check(not Any(words, "^15: .*Intact Raptor Horns"), "the bad luck is in level 15's words beside its card: "
        .. table.concat(words, "; "))
    -- Good luck: level 14's luckier hunt on its card (Features/Hunts/LuckyCard.lua),
    -- the other counted in the caption (13 Oct); a finale, in the caption
    -- (JRN-28).
    Check(Any(words, "^14: .*another lucky hunt"), "the good luck is not in level 14's words")
    Check(Any(words, "^13: .*the end of \226\128\156Samophlange Manual\226\128\157"),
        "the finale is not in level 13's words")
end
ns.TestData.Remove()
