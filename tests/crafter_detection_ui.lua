-- Crafter detection on Your Diary and the toast (Features/CrafterDetection/:
-- Mark.lua, Card.lua, Text.lua's registrations, Toast.lua; the signed
-- proposal, .claude/ui-proposal/crafter-detection.md): the needle and its
-- tooltip, the card at L and M (and none narrower), a card each and the
-- latest left off first, the upgrade card winning, the caption's tail only
-- where no card fits on a plate opened for it, the level's sentences, the
-- toast's kind (a stranger's card, its switch, the master), and the pad
-- finding the needles and cards and giving every colour back to the mouse.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

mock.RunTimers()
mock.now = 1792000000
ns._test.SettleGroup()

local CD = ns.CrafterDetection
local Card = CD.Card
local Link = ns.TestData.Link
local Toast = ns.UI.Toast

--------------------------------------------------------------------------
Section("the toast's kind: a stranger's card, its switch, the master")

local WREN = "Player-4395-0E1C0001"
ns.Characters.Observe(WREN, { first = "Wren", surname = "Halloway", level = 18, class = "DRUID" })
Eq(ns.Diary.Get(WREN), nil, "setup: a stranger")
local TUNIC = Link(2, 90431, "Stitched Wolfhide Tunic")
local BOOTS = Link(1, 2302, "Handstitched Leather Boots")

local spec = Toast.kinds.crafter
Check(spec ~= nil, "no crafter kind registered")
Eq(spec.setting, "crafterToasts", "the kind's switch")
Eq(spec.label, CD.WORDS.label, "the switch's words")
Eq(spec.more, nil, "a once-ever card folded into a count")
Eq(ns.Setting("crafterToasts"), true, "the switch on by default")

local function Showing() return ns.UI.ReunionShowing() end
local function Clear()
    for _ = 1, 30 do mock.RunTimers() end
    Eq(Showing(), nil, "a toast left from before")
    Eq(#Toast.queue, 0, "a toast left in line")
end

ns.Fire("SD_TOAST", "crafter", WREN, { dir = CD.THEIRS, id = 90431, link = TUNIC, how = "trade" })
local snap = Showing()
Check(snap and snap.kind == "crafter", "the crafter card is not up for a stranger")
Eq(snap and snap.key, "theirs:90431", "the card's key: its direction and item")
local card = _G.SocialDiaryToastFrame
Eq(card.heading:GetText(), "WEARING WHAT YOU MADE", "the heading for theirs")
Eq(card.name:GetText(), "WREN HALLOWAY", "the stranger's name, from the characters")
local story = card.lines[1]:GetText() or ""
Check(story:find("Stitched Wolfhide Tunic", 1, true) ~= nil, "the story does not name the item: " .. story)
Check(story:find("|cff086b01Stitched Wolfhide Tunic|r", 1, true) ~= nil, "the item not in its quality's ink: " .. story)
-- The same connection again while it shows: not in line twice.
ns.Fire("SD_TOAST", "crafter", WREN, { dir = CD.THEIRS, id = 90431, link = TUNIC, how = "trade" })
Eq(#Toast.queue, 0, "the same connection queued twice")
Clear()

-- Yours: sold or gave; a white item plain.
Eq(Toast.kinds.crafter.text({ way = "sold", link = BOOTS, name = "x" }).heading, "Sold you what you wear",
    "the heading for an auction's")
Eq(Toast.kinds.crafter.text({ way = "gave", link = BOOTS, name = "x" }).stories[1],
    "The Handstitched Leather Boots you have on came from them.", "a white item's story, plain")

-- Its own switch off: no card. On again, the master off: no card.
ns.db.settings.crafterToasts = false
ns.Fire("SD_TOAST", "crafter", WREN, { dir = CD.YOURS, id = 2302, link = BOOTS, how = "auction" })
Eq(Showing(), nil, "a card with its switch off")
ns.db.settings.crafterToasts = true
ns.db.settings.showToasts = false
ns.Fire("SD_TOAST", "crafter", WREN, { dir = CD.YOURS, id = 2302, link = BOOTS, how = "auction" })
Eq(Showing(), nil, "a card with every toast off")
ns.db.settings.showToasts = true
ns.Fire("SD_TOAST", "crafter", WREN, { dir = CD.YOURS, id = 2302, link = BOOTS, how = "auction" })
Eq(Showing() and Showing().key, "yours:2302", "the card back with both on")
Eq(card.heading:GetText(), "SOLD YOU WHAT YOU WEAR", "the heading for yours, sold")
Clear()

--------------------------------------------------------------------------
Section("the card at L and M, and none narrower")

local now = mock.now
local GLOVES = Link(2, 90432, "Dustwalker Gloves")
local BRAM = "Player-4395-0E1C0002"
ns.Characters.Observe(BRAM, { first = "Bramwell", surname = "Pike", level = 20, class = "ROGUE" })
local rec = { t = now - 600, guid = BRAM, dir = CD.YOURS, id = 90432, link = GLOVES, how = "auction",
    mapID = 1413, x = 0.5, y = 0.5 }
local item = { meet = rec, m = { kind = "crafted", t = rec.t, meet = rec }, mark = { 0, 0 } }
local c = Card.New(UIParent)
local function Lay(width)
    c:SetMeet(item, "test", now)
    c:Show()
    return c:Layout(10, 10, width, 400)
end
Lay(176)
Check(not c.overfull, "the card left off at 176 px")
Eq(c.craftForm, "L", "at 176 px: L")
Eq(c:Handoff(), "Bramwell Pike > you", "the hand-off by full names, the giver first")
Eq(c:HandLine(), "you wore what Bramwell sold you", "L's hand line names them")
Check(c.craftGiver:IsShown() and c.craftArrow[1]:IsShown() and c.craftArrow[3]:IsShown(), "the giver or the arrow not drawn")
Check(c.craftBox.icon ~= nil and c.under ~= nil, "no box under the hand-off")
Lay(142)
Check(not c.overfull, "the card left off at 142 px")
Eq(c.craftForm, "M", "at 142 px: M")
Eq(c:HandLine(), "you wore what they sold you", "M's hand line says they")
Lay(121)
Check(c.overfull, "a card under M's band was laid (no S)")
-- On a crowded plate L gives up to M once, then nothing more.
Lay(176)
Check(c:Smaller(), "L had nothing to give up")
c:Layout(10, 10, 176, 400)
Eq(c.craftForm, "M", "given up to M")
Check(not c:Smaller(), "M gave up something more")
-- Theirs: you first; a name too long by its full form goes by the first.
local THESS = "Player-4395-0E1C0003"
ns.Characters.Observe(THESS, { first = "Thessalindra", surname = "Moonwhisper", level = 19, class = "PRIEST" })
rec.guid, rec.dir, rec.how = THESS, CD.THEIRS, "trade"
Lay(142)
Eq(c:Handoff(), "you > Thessalindra", "the first name where the full one will not go")
Eq(c:HandLine(), "you saw them wear what you made", "M's hand line for theirs")
Lay(122)
Check(c.overfull, "a hand-off that will not go on one line was laid")
-- The slip's tooltip is the needle's; the box's the item's with how and when.
local tip = c.tip()
Eq(tip[1][1], "Thessalindra Moonwhisper wore what you made", "the slip's tooltip title")
Eq(tip[2][1], "Dustwalker Gloves, given to them in a trade", "the slip's tooltip line")
Lay(176)
c.craftBox.button:GetScript("OnEnter")(c.craftBox.button)
Check(GameTooltip.shown, "the item's tooltip not shown")
local said = {}
for _, line in ipairs(GameTooltip.lines or {}) do said[#said + 1] = line[1] end
said = table.concat(said, "|")
Eq(GameTooltip.link, TUNIC == rec.link and TUNIC or GLOVES, "the item's own tooltip")
Check(said:find("Given to Thessalindra Moonwhisper in a trade", 1, true) ~= nil,
    "the item's line of how: " .. said)
c.craftBox.button:GetScript("OnLeave")(c.craftBox.button)
Check(c.craftBox.button:GetScript("OnClick") == nil, "the item takes a click")
c:Hide()

--------------------------------------------------------------------------
Section("the needle's words")

local one = { { kind = "crafted", t = now - 600, meet = { t = now - 600, guid = BRAM, dir = CD.YOURS, id = 90432,
    link = GLOVES, how = "auction" } } }
local title, lines = CD.Tips(one, now)
Eq(title, "You wore what Bramwell Pike sold you", "one connection's title")
Eq(lines[1], "Dustwalker Gloves, bought from them at auction", "one connection's line")
Check(lines[2] ~= nil, "no foot saying when")
local two = { one[1], { kind = "crafted", t = now - 300, meet = { t = now - 300, guid = THESS, dir = CD.THEIRS,
    id = 90431, link = TUNIC, how = "trade" } } }
title, lines = CD.Tips(two, now)
Eq(title, "Two pieces of gear that changed hands", "several under one needle: counted")
Eq(lines[1], "Dustwalker Gloves, bought from Bramwell Pike at auction", "the first's line, with whom")
Eq(lines[2], "Stitched Wolfhide Tunic, given to Thessalindra Moonwhisper in a trade", "the second's line")
-- Forgotten: nobody named.
title = CD.Tips({ { kind = "crafted", t = now, meet = { t = now, dir = CD.THEIRS, id = 1, link = BOOTS } } }, now)
Eq(title, "Someone wore what you made", "a forgotten person's needle")

--------------------------------------------------------------------------
Section("the level's sentences")

local e = { level = 12, craftMeets = {
    { t = now, guid = BRAM, dir = CD.YOURS, id = 90432, link = GLOVES, how = "trade", mapID = 1413 },
    { t = now + 1, guid = THESS, dir = CD.YOURS, id = 90433, link = GLOVES, how = "trade" },
    { t = now + 2, dir = CD.THEIRS, id = 1, link = BOOTS } } }
local prose = CD.Lines(e)
Check(prose ~= nil, "no sentences")
local first, second = prose:match("^(.-%.) (.-%.)$")
Check(first ~= nil, "not two sentences: " .. tostring(prose))
Check(first and first:find("Bramwell Pike", 1, true) and first:find("Dustwalker Gloves", 1, true)
    and first:find("The Barrens", 1, true), "the first sentence: " .. tostring(first))
Check(second and second:find("Thessalindra Moonwhisper", 1, true) and not second:find("met %s"),
    "the second, with no place: " .. tostring(second))
-- (the seed's pick: the two shapes of "gave" in turn)
Check(first and second and (first:find("^You met") ~= nil) ~= (second:find("^You met") ~= nil),
    "the two read alike: " .. tostring(prose))
local found = false
for _, p in ipairs(ns.UI.JourneyText.Paragraphs()) do found = found or (p.key == "crafted" and p.at == 37) end
Check(found, "the sentences are not a paragraph of the level's prose")

--------------------------------------------------------------------------
Section("/sd testdata: needles, cards, the upgrade card, the caption")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local NB = "\194\160"

local function Caption(plate)
    local words = {}
    for k = 1, page.captionPool.used do
        local w = page.captionPool[k]
        if w:IsShown() then words[#words + 1] = (w:GetText() or ""):gsub(NB, " ") end
    end
    return table.concat(words, " | ")
end
local function Cards(plate)
    local list = {}
    for _, it in ipairs(plate.margin or {}) do
        if it.kind == "crafted" then list[#list + 1] = it end
    end
    return list
end

-- Each case on its page: by who, what it shows.
local cases = {}
local pages = {}
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        if plate:IsShown() and plate.craftedMarks then
            for _, needle in ipairs(plate.craftedMarks) do
                for _, m in ipairs(needle.list) do
                    local who = m.meet.guid and ns.Characters.Name(m.meet.guid) or "?"
                    local shown
                    for _, it in ipairs(Cards(plate)) do
                        -- (read now: the pool's cards are written again on the next page)
                        if it.meet == m.meet then
                            shown = { overfull = it.note.overfull, form = it.note.craftForm, handoff = it.note:Handoff() }
                        end
                    end
                    cases[who] = { plate = plate, at = at, i = i, shown = shown, caption = Caption(plate),
                        items = #Card.Items(plate), opened = plate.plan.rank == ns.JourneyRecap.RANK.crafted }
                    pages[who] = at
                end
            end
        end
    end
end

-- Every connection keeps its needle (five, one each).
for _, who in ipairs({ "Kaelin", "Garrow", "Tester", "Bramwell", "Thessalindra" }) do
    Check(cases[who] ~= nil, "no needle for " .. who)
end

-- L: Kaelin's boots on level 12's first sitting, in the one plate's row.
local k = cases.Kaelin
Check(k and k.shown and not k.shown.overfull, "Kaelin's card not shown")
if k and k.shown then
    Eq(k.shown.form, "L", "Kaelin's card's size")
    Eq(k.shown.handoff, "you > Kaelin Ashby", "Kaelin's hand-off")
    Check(not k.caption:find("wear what you made", 1, true), "the caption names a connection its card shows: " .. k.caption)
end

-- The upgrade card wins: the Blood Ring on level 13 has its needle, no card.
local g = cases.Garrow
if g then
    T.OpenDiaryPage(page, g.at.i, g.at.k)
    local plate = page.plates[g.i]
    Check(plate.upgrade ~= nil and ns.Upgrades.Card.Lead(plate) ~= nil, "setup: no upgrade card on level 13")
    Check(Card.Upgraded(plate, g.plate.craftedMarks[1].list[1].meet), "the ring is not the upgrade card's")
    Eq(#Cards(plate), 0, "the crafter card shown beside the upgrade card for the same item")
    local upgradeShown = false
    for _, it in ipairs(plate.margin or {}) do upgradeShown = upgradeShown or it.kind == "upgrade" end
    Check(upgradeShown, "the upgrade card not shown")
    -- Without the upgrade's card (its lead taken off the plate), the
    -- connection would have its card: the rule reads the card, nothing else.
    local lead = plate.upgrade
    plate.upgrade = nil
    Eq(#Card.Items(plate), 1, "the connection not offered once the upgrade card is gone")
    plate.upgrade = lead
end

-- Several on one plate: the cap's Crossroads, a card each in time order,
-- the latest (Bramwell's) the first left off; Tester's at M in the row.
local t = cases.Tester
Check(t and cases.Bramwell and t.at == cases.Bramwell.at and t.i == cases.Bramwell.i,
    "Tester's and Bramwell's not on one plate")
if t then
    T.OpenDiaryPage(page, t.at.i, t.at.k)
    local plate = page.plates[t.i]
    local items = Card.Items(plate)
    Eq(#items, 2, "the plate's connections offered")
    Check(items[1].meet.t < items[2].meet.t, "not in time order")
    Eq(ns.Characters.Name(items[1].meet.guid), "Tester", "the earliest first")
    local cards = Cards(plate)
    Eq(#cards, 1, "the cards on the crowded plate")
    Eq(cards[1] and cards[1].meet, items[1].meet, "the latest was kept over the earliest")
    Eq(cards[1] and cards[1].note.craftForm, "M", "the card in the row's 142 px box")
    local off
    for _, it in ipairs(plate.leftOff or {}) do
        if it.kind == "crafted" then off = it end
    end
    Eq(off and off.meet, items[2].meet, "the latest not the one left off")
    Check(not t.caption:find("wear", 1, true), "a card shows, yet the caption names one: " .. t.caption)
    -- Tester is in the diary: the needle joined their note.
    -- (on their note's moments; their note says it as far as its lines go,
    -- after the gift they gave you there)
    local joined = false
    for _, it in ipairs(plate.margin or {}) do
        if it.kind == "person" then
            for _, m in ipairs(it.g.moments) do joined = joined or m.kind == "crafted" end
        end
    end
    Check(joined, "Tester's connection not on their note")
    Eq(CD.PERSON.tier, 1, "a connection is something done together")
end

-- No card fits on a plate opened for it: the caption's tail names her.
local th = cases.Thessalindra
Check(th and th.opened, "Thessalindra's plate not opened for her")
if th then
    Eq(th.shown, nil, "a card in the 122 px column for a name that will not go")
    Check(th.caption:find("saw Thessalindra wear what you made", 1, true) ~= nil,
        "the caption does not name her: " .. th.caption)
end
-- What the margin tells the words (its `say`): the lead connection only
-- where none of its cards showed on a plate opened for one.
do
    local say = ns.UI.JourneyMargin.KINDS.crafted.say
    local meet = { t = now, guid = BRAM, dir = CD.YOURS, id = 90432, link = GLOVES, how = "trade" }
    local fake = { plan = { rank = ns.JourneyRecap.RANK.crafted },
        craftedMarks = { { at = { 10, 20 }, list = { { kind = "crafted", t = now, meet = meet } } } } }
    local told = {}
    say(told, {}, fake)
    Eq(told.crafted.lead, meet, "no card on a plate opened for it: the words not told the lead")
    told = {}
    say(told, { { kind = "crafted", meet = meet } }, fake)
    Eq(told.crafted.lead, nil, "a card shown, and the words told a lead as well")
    fake.plan.rank = ns.JourneyRecap.RANK.death
    told = {}
    say(told, {}, fake)
    Eq(told.crafted.lead, nil, "a plate opened by something else, and the words told a lead")
end
-- Kaelin's plate was opened by the close call: its words never name him.
Check(k and not k.opened, "setup: Kaelin's plate opened for him")

-- The level's prose names every connection.
for _, entry in ipairs(page.recap.entries) do
    if entry.level == 12 then
        local all = table.concat(ns.UI.JourneyText.Lines(entry, mock.now, {}), "\n")
        Check(all:find("Kaelin Ashby", 1, true) and all:find("Handstitched Leather Boots", 1, true),
            "level 12's prose does not tell Kaelin's boots")
    end
end

--------------------------------------------------------------------------
Section("the pad: needles and cards found, both names red, given back")

local Pad = ns.UI.Pad
local book = ns.UI.JournalFrame()
local function Red(fs)
    local r, g2, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g2 - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
local function Open() T.OpenDiaryPage(page, pages.Kaelin.i, pages.Kaelin.k) end
Open()
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Open()
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group) return Scope().focus.groups[group].items end

Press("PAD1")
Eq(At().group, "page", "setup: the pad on the plates")
local cardItem
for _, it in ipairs(Items("page")) do
    if it.note and it.note.craftRec then cardItem = it end
end
Check(cardItem ~= nil, "the crafter card not found by the pad")
local giverColour, nameColour, arrowShown
if cardItem then
    local note = cardItem.note
    giverColour, nameColour = { note.craftGiver:GetTextColor() }, { note.name:GetTextColor() }
    Scope().focus:Set(cardItem)
    Check(Red(note.name) and Red(note.craftGiver), "both names not red on the pad")
    local parts = Pad.Look.parts[book]
    Check(parts and parts.outline and parts.outline.line:IsShown(), "the card not outlined")
    Check(GameTooltip.shown, "the card's tooltip not shown")
    arrowShown = note.craftArrow[1]:IsShown()
end

-- Its needle among the plate's marks.
local plateItem
for _, it in ipairs(Items("page")) do
    if it.plate then plateItem = plateItem or it end
end
Scope().focus:Set(plateItem)
Press("PAD1")
Eq(At().group, "marks", "A on the plate did not go into its marks")
local needle
for _, mk in ipairs(page.plates[plateItem.plate]:Marks()) do
    if mk.what == "crafted" then needle = mk end
end
Check(needle ~= nil, "no needle among the plate's marks")
local onNeedle
for _, it in ipairs(Items("marks")) do
    if needle and it.key == needle.key then onNeedle = it end
end
Check(onNeedle ~= nil, "the needle not reached by the pad")
if onNeedle then
    Scope().focus:Set(onNeedle)
    Check(Pad.Look.parts[book].pen:IsShown(), "the needle not ringed")
    Check(GameTooltip.shown, "the needle's tooltip not shown")
end
-- Back on the card, then the mouse: nothing stays red.
Press("PAD2")
if cardItem then
    Scope().focus:Set(cardItem)
    mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    Check(not Pad.Input.Active(), "setup: the mouse took over")
    local note = cardItem.note
    Check(not Red(note.name) and not Red(note.craftGiver), "a name left red with the mouse")
    Eq(table.concat({ note.craftGiver:GetTextColor() }, ","), table.concat(giverColour, ","), "the giver's ink not given back")
    Eq(table.concat({ note.name:GetTextColor() }, ","), table.concat(nameColour, ","), "the taker's ink not given back")
    Eq(note.craftArrow[1]:IsShown(), arrowShown, "the arrow changed with the pad")
end
for i = 1, page.layout or 0 do
    local plate = page.plates[i]
    if plate:IsShown() then Check(not Red(plate.heading), "a heading left red with the mouse") end
end
