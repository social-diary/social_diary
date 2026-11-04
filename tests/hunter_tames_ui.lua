-- A hunter's tames on Your Diary's plates (.claude/ui-proposal/hunter-tames.md,
-- card A signed 4 Nov): the paw on the map, its tooltip Hunter.Tip's lines as
-- they are; the card in the margin (the pet's portrait where it has a display,
-- the name in the hand, the kind printed, the pet's level on its label; never
-- the hunter's level nor the tries), its sizes by the column, its place after
-- the people and before firsts found; and the player's own card.
--
-- The mock measures every string at 6 px a byte: the sizes asserted here are
-- the mock's, not the client's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Hunter, Plate, Margin = ns.Hunter, ns.UI.JourneyPlate, ns.UI.JourneyMargin
local Card = Hunter.Card

local now = mock.now
SELF.level = 14
mock.SetUnit("player", SELF)

local NAMED = { t = now - 600, npcID = 3099, beast = "Dire Mottled Boar", family = "Boar", petLevel = 9,
    name = "Bristlemane", level = 10, n = 3 }
local PLAIN = { t = now - 300, npcID = 3425, beast = "Savannah Prowler", family = "Cat", petLevel = 13, level = 14,
    n = 1 }

-- Every string the card writes, joined.
local function Written(card)
    local parts = { card.name:GetText() or "" }
    if card.headTail:IsShown() then parts[#parts + 1] = card.headTail:GetText() end
    parts[#parts + 1] = card:Kind()
    if card.tagText:IsShown() then parts[#parts + 1] = card.tagText:GetText() end
    return table.concat(parts, " | ")
end

--------------------------------------------------------------------------
Section("the paw: registered, quiet, its tooltip the tame's")

do
    local spec = Plate.MARKS.tame
    Check(spec ~= nil, "no mark for a tame")
    Eq(spec.order, 67, "after the duel's flag, before the campfire")
    Check(spec.order > Plate.ROAD_DEATHS and spec.order < Plate.MARKS.campfire.order, "steps aside for all but the fire")
    Eq(spec.keep, "tameMarks", "kept for the card")
    Eq(spec.chosen, "tame", "its card chosen")
    Check(Hunter.MARK.height < 12.4, "the paw outweighs the star")
    local title, lines = spec.tip({ kind = "tame", t = NAMED.t, tame = NAMED }, now)
    local tip = Hunter.Tip(NAMED, now)
    Eq(title, tip[1], "the tooltip's title is the tame's first line")
    Eq(#lines, #tip - 1, "the rest as they are, no line added")
    for i, line in ipairs(lines) do Eq(line, tip[i + 1], "the tooltip's line " .. i) end
    for _, line in ipairs(tip) do
        Check(not line:find("evel 10"), "the hunter's level in the tooltip: " .. line)
        Check(not line:find("three") and not line:find("tamed 3"), "the tries in the tooltip: " .. line)
    end
end

--------------------------------------------------------------------------
Section("which tame: the newest, the player's own apart")

do
    local custom = { t = now - 100, beast = "Plainstrider", customOf = {} }
    local marks = { { at = { 100, 50 }, list = { { kind = "tame", tame = NAMED } } },
        { at = { 200, 80 }, list = { { kind = "tame", tame = PLAIN }, { kind = "tame", tame = custom } } } }
    local chosen = Card.Choose(marks)
    Eq(chosen.rec, PLAIN, "the newest detected tame")
    Eq(chosen.mark[1], 200, "its paw for the leader")
    Eq(Card.Choose({}), nil, "no tame, no card")
    local own = Card.Customs(marks)
    Eq(#own, 1, "the player's tame a card of its own")
    Eq(own[1].rec, custom, "and never the plate's one")
    Eq(#Card.Customs({ { at = { 1, 1 }, list = { { kind = "tame", tame = { t = 1, customOf = {} } } } } }), 0,
        "a card of the player's saying nothing has none")
end

--------------------------------------------------------------------------
Section("the card: its words, its sizes, its portrait")

do
    local parent = CreateFrame("Frame")
    local card = Card.New(parent)
    card:SetTame(NAMED, "seed", now)

    local w, h = card:Layout(250, 90, 220)
    Eq(card.form, "XL", "a 220 px box")
    Check(not card.overfull and w <= 220 and h > 0, "XL does not fit its box")
    Eq(card.name:GetText(), "Bristlemane", "the given name in the hand")
    Eq(card:Kind(), "Boar · Dire Mottled Boar", "the kind printed under it")
    Eq(card.tagText:GetText(), "Lv 9", "the pet's level on its label")
    Check(card.tag ~= nil and card.tagText:IsShown(), "the label is not shown")
    Eq(card.picture, nil, "no display, no portrait")
    Eq(card.writingAt, 0, "no portrait: the writing at the left")
    local all = Written(card)
    Check(not all:find("10"), "the hunter's level on the card: " .. all)
    Check(not all:find("3"), "the tries on the card: " .. all)

    card:Layout(250, 90, 176)
    Eq(card.form, "L", "a 176 px column")
    card:Layout(250, 90, 142)
    Eq(card.form, "M", "a 142 px box")
    Check(not card.overfull, "M does not fit 142 px")
    Eq(card:Kind(), "Boar Dire Mottled Boar", "the kind split onto its family and its beast where it is narrow")
    card:Layout(250, 90, 60)
    Check(card.overfull, "too narrow, and not left off")

    -- With a display: the portrait pasted in at the left, the writing beside.
    local shown = {}
    for k, v in pairs(NAMED) do shown[k] = v end
    shown.display = 4567
    card:SetTame(shown, "seed", now)
    card:Layout(250, 90, 220)
    Eq(card.form, "XL", "with its portrait, XL")
    Check(card.picture ~= nil, "a display and no portrait")
    Eq(card.print.portrait, 4567, "the beast's display drawn")
    Eq(card.picture.w, Card.FORMS.XL.picture.w, "XL's portrait")
    Eq(card.writingAt, Card.FORMS.XL.picture.w + Card.PICTURE.gap, "the writing beside the portrait")
    Check(card.print:IsShown() and card.printEdge:IsShown(), "the portrait and its edge")
    card:Layout(250, 90, 176)
    Eq(card.picture.w, Card.FORMS.L.picture.w, "L's portrait, smaller")
    card:Layout(250, 90, 142)
    Eq(card.picture.w, Card.FORMS.M.picture.w, "M's, smaller still")

    -- With no portrait the client can draw, none, and the text at the left.
    local prints = _G.SetPortraitTextureFromCreatureDisplayID
    _G.SetPortraitTextureFromCreatureDisplayID = nil
    card:Layout(250, 90, 220)
    Eq(card.picture, nil, "no portrait the client can draw")
    Eq(card.writingAt, 0, "and the writing at the left")
    _G.SetPortraitTextureFromCreatureDisplayID = prints

    -- No given name: the beast in the hand, the family alone printed.
    card:SetTame(PLAIN, "seed", now)
    card:Layout(250, 90, 176)
    Eq(card.name:GetText(), "Savannah Prowler", "the beast's own name in the hand")
    Eq(card:Kind(), "Cat", "the family alone")
    Eq(card.tagText:GetText(), "Lv 13", "its level")
    local tip = card.tip and card.tip() or card.note.tip()
    Eq(tip[1][1], Hunter.Tip(PLAIN, now)[1], "the card's tooltip, the tame's")

    -- Laid flat, square.
    ns.SetSetting("flatSheets", true)
    card:Layout(250, 90, 176)
    Eq(card.turn, 0, "laid flat, it turns")
    Check(not card.tagShadow:IsShown(), "laid flat, the label throws a shadow")
    ns.SetSetting("flatSheets", false)
end

--------------------------------------------------------------------------
Section("in the margin: after the people, before firsts found")

do
    Eq(Margin.KINDS.tame.order, 15, "the tame's place")
    Check(Margin.KINDS.tame.order > Margin.PEOPLE.close, "before the people")
    Check(Margin.KINDS.tame.order < Margin.KINDS.find.order, "after firsts found")
    Eq(Margin.KINDS.tameCustom.order, 2.5, "the player's own, after the acquaintance's strip")
    Eq(Margin.KINDS.tame.assume, nil, "no caption words")
    Eq(Margin.KINDS.tame.say, nil, "no caption words when left off")
    local kind = Margin.KINDS.tame.custom({ tame = { rec = NAMED } })
    Eq(kind, "tame", "a right click opens the tame's form")
end

--------------------------------------------------------------------------
Section("/sd testdata: the two tames on their pages")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function Cards()
    local list = {}
    for k = 1, (page.tamePool and page.tamePool.used or 0) do
        local c = page.tamePool[k]
        if c:IsShown() then list[#list + 1] = c end
    end
    return list
end
local function Leader(card)
    for _, link in ipairs(page.links) do
        if link.strip == card then return link end
    end
end

-- Wherever a card shows: its leader to a paw of its plate.
local seen = {}
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    for _, c in ipairs(Cards()) do
        seen[c.name:GetText()] = true
        local link = Leader(c)
        Check(link ~= nil, "a tame's card has no leader")
        local on = false
        for _, p in ipairs(page.plates) do
            for _, mark in ipairs(p:IsShown() and p.tameMarks or {}) do on = on or (link and link.mark == mark.at) end
        end
        Check(on, "a tame card's leader goes elsewhere than a paw")
    end
end
Check(seen.Bristlemane, "level 10's Bristlemane has no card")
Check(seen["Savannah Prowler"], "level 14's Savannah Prowler has no card")

local function Level(level)
    for _, at in ipairs(T.DiaryPages(page)) do
        local e = page.recap.entries[at.i]
        if e.level == level then
            T.OpenDiaryPage(page, at.i, at.k)
            for _, p in ipairs(page.plates) do
                if p:IsShown() and p.tame then return p end
            end
        end
    end
end

do
    local p = Level(10)
    Check(p ~= nil, "level 10: no plate with the tame")
    Eq(p.counts.tames, 1, "level 10's paw")
    Eq(p.tame.rec.name, "Bristlemane", "level 10's tame")
    Eq(page.tamesWritten, 1, "level 10's card")
    local card = Cards()[1]
    Eq(card:Kind():gsub(" ·", ""), "Boar Dire Mottled Boar", "level 10's kind")
    Eq(card.picture, nil, "testdata keeps no display")
    local kinds = {}
    for _, it in ipairs(p.margin or {}) do kinds[#kinds + 1] = it.kind end
    Eq(table.concat(kinds, ","), "tame,find,witness", "level 10's margin: the tame before the find and the witness")

    p = Level(14)
    Check(p ~= nil, "level 14: no plate with the tame")
    Eq(p.tame.rec.beast, "Savannah Prowler", "level 14's tame")
    Eq(Cards()[1].name:GetText(), "Savannah Prowler", "level 14's card, no given name")
    kinds = {}
    for _, it in ipairs(p.margin or {}) do kinds[#kinds + 1] = it.kind end
    Eq(table.concat(kinds, ","), "tame,witness,foe,lucky", "level 14's margin: the tame first, nothing left off for it")
end

--------------------------------------------------------------------------
Section("the player's own tame: a card of its own, first of the cards")

do
    local j = ns.Journey.For(ns.ownGUID)
    local bristle = j.tames[1]
    j.custom = j.custom or {}
    j.custom[#j.custom + 1] = { kind = "tame", t = bristle.t + 60, mapID = bristle.mapID, x = bristle.x + 0.02,
        y = bristle.y, level = 10, beast = "Mottled Boar", name = "Tusker", family = "Boar", petLevel = 6 }
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(true)
    local p = Level(10)
    Eq(page.customTamesWritten, 1, "the player's tame has its card")
    Eq(page.tamesWritten, 1, "and the detected one its own")
    local names = {}
    for _, c in ipairs(Cards()) do names[#names + 1] = c.name:GetText() end
    table.sort(names)
    Eq(table.concat(names, ","), "Bristlemane,Tusker", "both shown")
    Eq(p.margin[1].kind, "tameCustom", "the player's card first")
    j.custom[#j.custom] = nil
    ns.Journey.Touch()
end
