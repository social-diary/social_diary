-- Upgrades on Your Diary's plates (.claude/ui-proposal/upgrades.md, signed
-- 15 Nov 2026): the tunic on the map for the leading upgrade and for every
-- other piece; the card (the old item on its tag in a wide column, in the
-- one box in a narrow one, the old item never in its quality's colour); the small note of the other pieces; "a
-- first found wins"; the caption's and the entry's words; the giver's row
-- and margin note; and the pad, which finds all of it with no code of the
-- feature's but the tag's corners.
--
-- The mock measures every string at 6 px a byte: the sizes asserted here are
-- the mock's, not the client's. Names are made up.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Upgrades, Plate, Margin, Text = ns.Upgrades, ns.UI.JourneyPlate, ns.UI.JourneyMargin, ns.UI.JourneyText
local Card, Style = Upgrades.Card, ns.Style
local Link = ns.TestData.Link

local now = mock.now
local NB = "\194\160"
local function Plain(s) return (s:gsub(NB, " ")) end
local function Hex(c) return ("%02x%02x%02x"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5) end
local function Painted(texture) return Hex(texture.recorded.calls.SetColorTexture) end

local GIVER = "Player-0000-BRANN001"
local BRACERS, OLD = Link(2, 6070, "Wolfskin Bracers"), Link(3, 1423, "Ragged Leather Bracers")
local function Rec(over)
    local rec = { t = now - 600, level = 14, link = BRACERS, key = Upgrades.Key(BRACERS), quality = 2, slot = 9,
        ilvl = 97, from = "loot", found = now - 700, was = { link = OLD, ilvl = 5 } }
    for k, v in pairs(over or {}) do rec[k] = v end
    return rec
end
local function Moment(rec, kind) return { kind = kind or "upgrade", t = rec.t, upgrade = rec, gift = rec.from == "trade" or nil,
    guid = rec.guid } end

--------------------------------------------------------------------------
Section("the tunic: registered twice, in the item's ink, its tooltip the upgrade's")

do
    local lead, piece = Plate.MARKS.upgrade, Plate.MARKS.piece
    Check(lead ~= nil and piece ~= nil, "no mark for an upgrade or a piece")
    Eq(lead.order, 7, "the leading upgrade's tunic comes right after the pouch")
    Check(lead.order > Plate.MARKS.find.order and lead.order < Plate.MARKS.finale.order, "the tunic's place")
    Eq(piece.order, 68, "a piece's tunic after the paw, before the campfire")
    Check(piece.order > Plate.ROAD_DEATHS and piece.order < Plate.MARKS.campfire.order, "a piece steps aside for all but the fire")
    Eq(lead.keep .. "/" .. lead.chosen, "upgradeMarks/upgrade", "kept for the card")
    Eq(piece.keep .. "/" .. piece.chosen, "pieceMarks/pieces", "kept for the small note")
    Eq(Plate.CAP.pieces, 10, "at most ten pieces a plate")
    Check(lead.draw == piece.draw, "one glyph for both")
    Check(Upgrades.MARK.height <= 12.4, "the tunic outweighs the star")

    -- In the item's ink, part way (the pouch's rule): never plain.
    local rec = Rec()
    local ink = lead.arg({ Moment(rec) })
    local own, strong = Style.QualityInk(2), Style.INK_STRONG
    Check(Hex(ink) ~= Hex(strong), "a green's tunic in plain ink")
    Eq(("%.4f"):format(ink[2]), ("%.4f"):format(strong[2] + (own[2] - strong[2]) * Upgrades.MARK.tint), "the tint")
    -- The best of a spot first.
    local list = { Moment(Rec({ t = now - 900 })), Moment(Rec({ quality = 3, t = now - 100 })) }
    lead.arg(list)
    Eq(list[1].upgrade.quality, 3, "the best item's ink")

    local title, lines = lead.tip(Moment(rec), now)
    local t2, line = Upgrades.Tip(Moment(rec), now)
    Eq(title, t2, "the tooltip's title")
    Eq(lines[1], line, "the tooltip's line")
    Check(not (title .. line):find("97") and not line:find("ilvl"), "an item level in the tooltip")
    title, lines = piece.tips({ Moment(rec, "piece"), Moment(Rec({ slot = 6 }), "piece") }, now)
    Eq(title, "Two new pieces", "two on a spot, counted")

    -- A gift joins its giver's marks, while they are in the diary.
    local giver = { guid = GIVER, name = "Brannoc" }
    Check(not lead.join(Moment(rec)), "a looted item joined someone")
    Check(not lead.join(Moment(Rec({ from = "trade", guid = "Player-1-0000FFFF" }))), "a stranger's gift joined")
    if giver then
        ns.Characters.Observe(GIVER, { first = "Brannoc", surname = "Hale" })
        ns.Diary.Add(GIVER, { source = "test" })
        Check(lead.join(Moment(Rec({ from = "trade", guid = giver.guid }))), "a gift does not join its giver")
        Check(piece.join(Moment(Rec({ from = "trade", guid = giver.guid }), "piece")), "a gifted piece does not join its giver")
    end
end

--------------------------------------------------------------------------
Section("the card, wide: the new item's box, the old item struck on its tag")

local parent = CreateFrame("Frame")
do
    local card = Card.New(parent)
    local rec = Rec()
    card:SetUpgrade({ m = Moment(rec), rec = rec, mark = { 0, 0 } }, "seed", now)
    local w, h = card:Layout(250, 90, 176)
    Eq(card.form, "two", "a wide column: the card and its tag")
    Check(not card.overfull, "the card does not fit 176 px")
    Eq(card.name:GetText(), "Looted", "the heading says how it came")
    Check(w <= 176, "the card and its tag wider than the column: " .. w)
    local box, tag = card.itemBox, card.tag
    Eq(box.quality, 2, "the new item in its quality")
    Check(box.wash[1]:IsShown(), "the new item's wash")
    Eq(Painted(box.iconEdge), "1eff00", "the new icon edged in the game's green")
    Eq(box.lines[1]:GetText(), "Wolfskin Bracers", "the new item's name")
    Eq(box.wasShown, nil, "the old item in the box as well as on the tag")
    Check(tag:IsShown(), "no tag")
    Eq(card:Old(), "Ragged Leather Bracers", "the old item's name on the tag")
    Check(tag.oldEdge:IsShown(), "the old item's icon has no edge")
    Eq(Painted(tag.oldEdge), Hex(Style.INK), "the old icon edged in its quality's colour (it was a blue)")
    local r, g, b = tag.words[1]:GetTextColor()
    Eq(Hex({ r, g, b }), Hex(Style.INK_FADED), "the old name in its quality's ink")
    Check((tag.struck or 0) > 0, "the old name is not struck")
    -- The tag reaches past the card's right edge, over its lower corner.
    local at = card.tagAt
    Check(at[1] + at[3] > card.plan.Wb - 1 and at[1] >= Card.CARD.show, "the tag not past the card's edge")
    Check(at[2] < h and at[2] + at[4] >= h - 1, "the tag not over the card's foot")
    -- No item level anywhere.
    for _, text in ipairs({ card.name:GetText(), card:Old(), box.lines[1]:GetText() }) do
        Check(not text:find("%d"), "a number on the card: " .. text)
    end

    -- Under the mouse: each item's own tooltip, how it came under the new one's.
    box.button.scripts.OnEnter(box.button)
    Eq(GameTooltip.link, BRACERS, "the new item's tooltip")
    box.button.scripts.OnLeave(box.button)
    tag.item.scripts.OnEnter(tag.item)
    Eq(GameTooltip.link, OLD, "the old item's tooltip")
    tag.item.scripts.OnLeave(tag.item)
    Check(not GameTooltip.shown, "the tooltip stays")
    Check(tag.item:GetScript("OnClick") == nil and box.button:GetScript("OnClick") == nil, "an item takes a click")

    -- The pad's corners take in the tag; a leader may leave from it.
    local f = card:Focus()
    local right, foot = -math.huge, -math.huge
    for _, c in ipairs(f.corners) do right, foot = math.max(right, c[1]), math.max(foot, c[2]) end
    Check(right >= 250 + at[1] + at[3] - 4, "the pad's corners leave the tag out: " .. right)
    Check(foot >= 90 + at[2] + at[4] - 4, "the pad's corners stop at the card's foot")
    Eq(f.words, card.name, "the pad's words are the heading")
    local nx, ny = card:Nearest(250 + at[1] + at[3] + 40, 90 + at[2] + at[4] + 40)
    Check(nx > 250 + card.plan.Wb - 2 or ny > 90 + at[2], "a leader from below right does not leave from the tag")

    ----------------------------------------------------------------------
    Section("the card, narrow: both icons in the one box")

    w, h = card:Layout(250, 90, 142)
    Eq(card.form, "one", "a narrow column: one box")
    Check(not card.overfull, "the card does not fit 142 px")
    Check(not tag:IsShown(), "the tag in a narrow column")
    Eq(box.wasShown, "item", "the old icon not in the box")
    Check(box.was.icon:IsShown() or box.was.edge:IsShown(), "the old icon not drawn")
    Eq(Painted(box.was.edge), Hex(Style.INK), "the old icon edged in its quality's colour")
    Check(card.plan.chip.lead > 0, "no room kept before the new icon")
    Check(card.plan.chip.iconAt[1] > card.plan.chip.lead, "the new icon not after the old one and the arrow")
    box.wasButton.scripts.OnEnter(box.wasButton)
    Eq(GameTooltip.link, OLD, "the old icon's tooltip")
    box.wasButton.scripts.OnLeave(box.wasButton)
    Eq(card:Focus().words, card.name, "the pad's words in a narrow column")

    -- Too narrow for its box: left off.
    card:Layout(250, 90, 60)
    Check(card.overfull, "a card in 60 px")

    ----------------------------------------------------------------------
    Section("the card: nothing said of how it came, no old item, a gift")

    rec = Rec({ from = false })
    rec.from = nil
    card:SetUpgrade({ m = Moment(rec), rec = rec, mark = { 0, 0 } }, "seed", now)
    card:Layout(250, 90, 176)
    Eq(card.name:GetText(), "Newly worn", "the heading where nothing said how it came")

    -- A record with no old item is no upgrade since 16 Nov (only the
    -- feature's first dev data has one): drawn as the one box alone, with
    -- nothing before its icon, and no error.
    rec = Rec({ was = false })
    rec.was = nil
    card:SetUpgrade({ m = Moment(rec), rec = rec, mark = { 0, 0 } }, "seed", now)
    card:Layout(250, 90, 176)
    Eq(card.form, "one", "a record with no old item has a tag")
    Check(not tag:IsShown(), "a tag with no old item")
    Eq(box.wasShown, nil, "something drawn before the icon with no old item")

    local giver = { guid = GIVER, name = "Brannoc" }
    if giver then
        rec = Rec({ from = "trade", guid = giver.guid })
        card:SetUpgrade({ m = Moment(rec), rec = rec, mark = { 0, 0 } }, "seed", now)
        card:Layout(250, 90, 176)
        Eq(Plain(card.name:GetText()), Plain(Upgrades.Heading(rec)), "a gift's heading")
        Check(card.name:GetText():find(giver.name, 1, true), "a gift's card does not name its giver: " .. card.name:GetText())
    end
    -- A giver the diary no longer knows.
    rec = Rec({ from = "trade", guid = "Player-1-0000FFFF" })
    card:SetUpgrade({ m = Moment(rec), rec = rec, mark = { 0, 0 } }, "seed", now)
    card:Layout(250, 90, 176)
    Eq(card.name:GetText(), "A gift", "a forgotten giver's gift")

    -- Laid flat: no lean, no tilt.
    ns.SetSetting("flatSheets", true)
    rec = Rec()
    card:SetUpgrade({ m = Moment(rec), rec = rec, mark = { 0, 0 } }, "seed", now)
    card:Layout(250, 90, 176)
    Eq(box.lean, 0, "a box laid flat leans")
    ns.SetSetting("flatSheets", false)
end

--------------------------------------------------------------------------
Section("the small note: one piece its icon and slot, more counted")

do
    local slip = Card.NewPiece(parent)
    local belt = Rec({ slot = 6, link = Link(2, 4697, "Burnished Girdle") })
    slip:SetPieces({ list = { { m = Moment(belt, "piece"), rec = belt, mark = { 0, 0 } } }, mark = { 0, 0 } }, "seed", now)
    local w = slip:Layout(250, 90, 122)
    Eq(slip:Words(), "a new belt", "one piece: its slot")
    Check(not slip.overfull and w <= 122, "the small note does not fit 122 px")
    Check(slip.icon:IsShown() and slip.item:IsShown(), "one piece has no icon")
    Eq(Painted(slip.iconEdge), "1eff00", "the piece's icon edged in its quality's colour")
    slip.item.scripts.OnEnter(slip.item)
    Eq(GameTooltip.link, belt.link, "the piece's own tooltip")
    slip.item.scripts.OnLeave(slip.item)
    local gloves = Rec({ slot = 10 })
    slip:SetPieces({ list = { { rec = belt, mark = { 0, 0 } }, { rec = gloves, mark = { 0, 0 } } }, mark = { 0, 0 } },
        "seed", now)
    slip:Layout(250, 90, 122)
    Eq(slip:Words(), "two new pieces", "two pieces: counted")
    Check(not slip.icon:IsShown() and not slip.item:IsShown(), "an icon on a counted note")
    slip:Layout(250, 90, 40)
    Check(slip.overfull, "a small note in 40 px")
end

--------------------------------------------------------------------------
Section("a first found wins: read off the plate's pouches")

do
    local rec = Rec()
    local with = { findMarks = { { list = { { kind = "find", find = { link = BRACERS } } } } },
        upgrade = { rec = rec, mark = { 1, 2 } },
        pieces = { list = { { rec = rec, mark = { 1, 2 } }, { rec = Rec({ link = OLD, key = Upgrades.Key(OLD) }), mark = { 3, 4 } } },
            mark = { 1, 2 } } }
    Check(Card.Found(with, rec), "the same item's first found not seen")
    Eq(Card.Lead(with), nil, "an upgrade's card beside its first found's")
    Eq(#Card.Pieces(with).list, 1, "a piece counted beside its first found's card")
    local without = { findMarks = { { list = { { kind = "find", find = { link = OLD } } } } }, upgrade = with.upgrade }
    Check(Card.Lead(without) == with.upgrade, "another item's first found takes the card")
    Eq(Card.Lead({}), nil, "a card with no upgrade")
    -- The margin's kinds, in their places.
    Eq(Margin.KINDS and Margin.KINDS.upgrade and Margin.KINDS.upgrade.order or 22, 22, "the card's order")
end

--------------------------------------------------------------------------
Section("the caption's words")

do
    local lead, tail = Text.CAPTIONS.upgrade.lead, Text.CAPTIONS.upgrade.tail
    local rec = Rec()
    local m = Moment(rec)
    local function C(said, finds) return { said = said, named = {}, lists = { find = finds or {} }, of = {}, plate = {} } end
    Eq(lead.at, 25, "it leads straight after a first found")
    Eq(tail.at, 15, "second in the tail")
    Eq(lead.say({ m }, C({ upgrade = { [rec] = true } })), "New bracers", "its card beside the plate: the slot alone")
    Eq(lead.say({ m }, C({})), "New bracers: Wolfskin Bracers", "its card left off: the item named")
    Eq(lead.say({ m }, C({}, { { kind = "find", find = { link = BRACERS } } })), nil, "led beside its own first found")
    Eq(tail.say({ m }, C({}, { { kind = "find", find = { link = BRACERS } } })), nil, "in the tail beside its first found")
    Eq(tail.say({ m }, C({ upgrade = { [rec] = true } }))[1], "new bracers", "the tail's words")
    local pieces = Text.CAPTIONS.piece
    Check(pieces.lead == nil, "the pieces lead a caption")
    Eq(pieces.tail.at, 87, "the pieces after a duel, before a campfire")
    local p = Moment(Rec({ slot = 6 }), "piece")
    Eq(pieces.tail.say({ p }, C({})), nil, "the pieces said beside their note")
    Eq(pieces.tail.say({ p }, C({ piece = true })), "a new piece of gear", "the pieces counted where the note is left off")
    Eq(pieces.tail.say({ p, p }, C({ piece = true })), "two new pieces of gear", "two counted")
end

--------------------------------------------------------------------------
Section("/sd testdata: the pages")

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local book = ns.UI.JournalFrame()
local page = ns.UI.JourneyPage()
local function Shown(pool)
    local list = {}
    for i = 1, pool and pool.used or 0 do
        if pool[i]:IsShown() then list[#list + 1] = pool[i] end
    end
    return list
end

local seen, ring, ringAt, giftAt = {}, nil, nil, nil
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    local label = at.e.kind == "level" and tostring(at.e.level) or "week"
    local marks, cards, slips, captions = 0, {}, {}, {}
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        if plate:IsShown() then
            marks = marks + #(plate.upgradeMarks or {}) + #(plate.pieceMarks or {})
            if plate.upgrade and plate.upgrade.rec.from == "trade" then giftAt = giftAt or at end
            -- A first found on the plate: no card, no word of the upgrade; the tunic stays.
            if plate.upgrade and Card.Found(plate, plate.upgrade.rec) then
                Eq(Card.Lead(plate), nil, label .. ": a card beside the item's first found")
                Check(#plate.upgradeMarks > 0, label .. ": the tunic left with the card")
                for _, it in ipairs(plate.margin or {}) do
                    Check(it.kind ~= "upgrade", label .. ": an upgrade's card in the margin beside its first found's")
                end
            end
        end
    end
    for _, card in ipairs(Shown(page.upgradePool)) do cards[#cards + 1] = card.name:GetText() .. "/" .. card.form end
    for _, slip in ipairs(Shown(page.piecePool)) do slips[#slips + 1] = slip:Words() end
    for _, caption in ipairs(Shown(page.captionPool)) do captions[#captions + 1] = Plain(caption:GetText() or "") end
    if marks > 0 then
        seen[#seen + 1] = ("%s: %d tunic(s), cards [%s], notes [%s]"):format(label, marks, table.concat(cards, ","),
            table.concat(slips, ","))
    end
    -- Level 13's ring (level 10 has a card too: the gloves, over white ones).
    local first = Shown(page.upgradePool)[1]
    if first and first.rec.slot == 11 and not ring then
        ring, ringAt = first, at
        Eq(ring.rec.slot, 11, "setup: level 13's ring")
        Eq(ring.name:GetText(), "Newly worn", "the ring's heading")
        Check(ring.form == "two" or ring.itemBox.wasShown == "item", "the ring's card does not show the band it replaced")
        Eq(page.upgradesWritten, 1, "the page's count of upgrade cards")
        Check(not table.concat(captions, " "):find("Blood Ring", 1, true), "the caption names the item its card shows")
    end
    for _, caption in ipairs(captions) do
        Check(not caption:find("%d+ item level") and not caption:find("ilvl"), "an item level in a caption: " .. caption)
    end
end
local all = table.concat(seen, "; ")
Check(all:find("11: 2 tunic(s), cards [], notes [a new belt]", 1, true), "level 11: the first green's tunic, the belt's note: " .. all)
Check(all:find("10: 1 tunic(s), cards [Bought/", 1, true), "level 10: the gloves' card, over the white ones: " .. all)
Check(all:find("13: 1 tunic(s), cards [Newly worn/", 1, true), "level 13: the ring's card: " .. all)
Check(all:find("15: 1 tunic(s), cards [], notes []", 1, true), "level 15: the first epic's tunic alone: " .. all)
Check(giftAt ~= nil, "the gift's tunic on no page: " .. all)

-- The entry's words on the left page: what was found, then what was put on.
do
    local by = {}
    for _, e in ipairs(page.recap.entries) do
        if e.kind == "level" then by[e.level] = Plain(table.concat(Text.Lines(e, now, {}), " / ")) end
    end
    Check(by[11]:find("Your Worn Leather Bracers made way for it. One more piece of gear went on besides.", 1, true),
        "level 11's sentence: " .. by[11])
    Check(not by[11]:find("made way for Wolfskin Bracers", 1, true), "level 11 names its first green twice")
    Check(by[13]:find("Your Tarnished Copper Band made way for Blood Ring.", 1, true), "level 13's sentence: " .. by[13])
    Check(by[15]:find("Your Hatchet made way for it.", 1, true), "level 15's sentence: " .. by[15])
    for level, text in pairs(by) do Check(not text:find("item level"), "an item level in level " .. level .. "'s entry") end
end

-- The gift: its row on Tester's timeline, with the trade's art; on the plate,
-- Tester's own margin note says it.
do
    local row
    for _, r in ipairs(ns.db.interactions[ns.TestData.GUID] or {}) do
        if r.type == "gift_worn" then row = r end
    end
    Check(row ~= nil, "no gift_worn row on Tester")
    Eq(ns.Rows.Get("gift_worn").icon, "trade", "the row's art")
    if row then
        local words = ns.Rows.Get("gift_worn").text(row)
        Check(words:find("Glowing Lizardscale Cloak", 1, true), "the row does not name the cloak: " .. words)
    end
    T.OpenDiaryPage(page, giftAt.i, giftAt.k)
    local said
    for _, strip in ipairs(Shown(page.notePool)) do
        local what = Plain(strip:What())
        if what:find("gave you", 1, true) then said = what end
    end
    Check(said ~= nil, "Tester's margin note says nothing of the gift")
end

--------------------------------------------------------------------------
Section("with the pad: the card, the note and the tunics are found; the look is given back")

do
    local Pad = ns.UI.Pad
    local Look = Pad.Look
    local function Red(fs)
        local r, g, b = fs:GetTextColor()
        local R = Style.RUBRIC
        return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
    end
    Check(not Pad.Input.Active(), "setup: the mouse")
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
    mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
    local catcher = Pad.Catcher(book)
    local function Press(key)
        mock.PadPress(catcher, key, true)
        return mock.PadPress(catcher, key, false)
    end
    local function Scope() return Pad.Top() end
    local function At() return Scope().focus:Current() end
    local function Items(group) return Scope().focus.groups[group].items end
    local function Find(part)
        for _, item in ipairs(Items("page")) do
            if item.key:find(part, 1, true) then return item end
        end
    end

    -- Level 13: the ring's card.
    T.OpenDiaryPage(page, ringAt.i, ringAt.k)
    Press("PAD1")
    Eq(At().group, "page", "setup: on the plates")
    local card = Find(":upgrade:")
    Check(card ~= nil, "the upgrade's card not found by the pad")
    Scope().focus:Set(card)
    local heading = card.heading
    Eq(heading:GetText(), "Newly worn", "the pad's heading is the card's")
    Check(Red(heading), "the card's heading not red")
    local outline = Look.parts[book].outline
    Check(outline.line:IsShown(), "the card not outlined")
    Check(GameTooltip.shown, "the card's tooltip not shown")
    Check(GameTooltip.link == nil, "the pad clicked or linked an item")
    -- Its tunic, among the plate's marks.
    local plateItem
    for _, item in ipairs(Items("page")) do
        if item.plate and page.plates[item.plate].upgrade then plateItem = item end
    end
    Scope().focus:Set(plateItem)
    Press("PAD1")
    Eq(At().group, "marks", "A on the plate did not go into its marks")
    local tunic
    for _, item in ipairs(Items("marks")) do
        if item.key:find("upgrade", 1, true) then tunic = item end
    end
    Check(tunic ~= nil, "the tunic not found by the pad")
    Scope().focus:Set(tunic)
    Check(tunic.ring and Look.parts[book].pen:IsShown(), "the tunic not ringed")
    Press("PAD2")
    Eq(At().group, "page", "B did not come back from the marks")

    -- Level 11: the belt's small note and its tunic.
    for _, at in ipairs(T.DiaryPages(page)) do
        if at.e.kind == "level" and at.e.level == 11 then T.OpenDiaryPage(page, at.i, at.k) end
    end
    Scope().focus:EnterGroup("page")
    local note = Find(":piece:")
    Check(note ~= nil, "the small note not found by the pad")
    Scope().focus:Set(note)
    Eq(note.heading:GetText(), "a new belt", "the pad's words are the note's")
    Check(Red(note.heading), "the small note's words not red")

    -- The mouse takes over: every colour given back, nothing passed on.
    mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    Check(not Pad.Input.Active(), "setup: the mouse took over")
    Check(not Red(note.heading), "the small note left red with the mouse")
    Check(not outline.line:IsShown() and not outline.shadow:IsShown(), "the outline left with the mouse")
    Check(not Look.parts[book].pen:IsShown(), "the ring left with the mouse")
    T.OpenDiaryPage(page, ringAt.i, ringAt.k)
    Check(not Red(Shown(page.upgradePool)[1].name), "the card's heading left red with the mouse")
    -- In combat the pad is the game's.
    mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
    Check(not catcher:IsGamePadButtonEnabled(), "the catcher on in combat")
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    mock.pad.ui, mock.pad.enabled, mock.pad.devices = nil, nil, nil
end
