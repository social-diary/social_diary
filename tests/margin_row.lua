-- The one plate's row under its caption shared out (UI/Journey/Margin.lua's
-- ROW, Rows, RowAt, Shows; 19 Nov, the user: "make space for as much margin
-- content as possible. It would be wasteful to display a single M card
-- within a single plate layout"): fewer cards than boxes take the row's
-- spare width, as much as shows the most, every kind and not only those
-- that ask (`wants`); each as near its mark as the row lets it, inside the
-- row and never over another; with "Keep my own route" off the shorter
-- foot is respected; three cards, and a row of only people's strips, as
-- they were.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Custom, J = ns.Custom, ns.Journey
local YourDiary = ns.UI.YourDiary
local ROW = YourDiary.ROW

mock.now = 1791000000
local now = mock.now
F.SELF.level = 11
mock.SetUnit("player", F.SELF)
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
mock.itemInfo[4242] = { icon = 5005, quality = 3 }

-- The user's two cards (19 Nov), and a third.
local CARDS = {
    { icon = "skull", text = "OMG!!!!!", people = { { name = "Fuling" } }, item = "Linen Cloth", itemID = 4242, x = 0.47 },
    { icon = "chest", text = "Cool thing looted!", item = "Dark Leather Boots", itemID = 4242, x = 0.43 },
    { icon = "fish", text = "he swore it was the biggest he had ever seen, and then it got away", mob = "Murloc Forager",
        x = 0.38 },
}

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local TOP = ns.UI.JourneyLook.LAYOUT[1][1].top
local ROWBOX = TOP.row
local X0, X1 = ROWBOX[1].x, ROWBOX[#ROWBOX].x + ROWBOX[#ROWBOX].w
local GAP = ROWBOX[2].x - ROWBOX[1].x - ROWBOX[1].w

local function Draw(n)
    j.custom = nil
    for i = 1, n do
        local c = {}
        for k, v in pairs(CARDS[i]) do c[k] = v end
        local x = c.x
        c.x = nil
        Custom.Insert("noteCard", c, { mapID = MAP, x = x, y = 0.62, from = t0, to = t0 + 3000 })
    end
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, e in ipairs(page.recap.entries) do if e.level == 10 then T.OpenDiaryPage(page, i) end end
    local cards = {}
    for i = 1, page.killerPool.used do
        local c = page.killerPool[i]
        if c:IsShown() and c.freeRec then cards[#cards + 1] = c end
    end
    table.sort(cards, function(a, b) return a.box[1] < b.box[1] end)
    return page.plates[1], cards
end

-- Inside the row, one after another, each leader's end near its card.
local function Tidy(label, plate, cards)
    for i, c in ipairs(cards) do
        Check(c.box[1] >= X0 - 0.5 and c.box[1] + c.box[3] <= X1 + 0.5, label .. ": card " .. i .. " off the row")
        if cards[i + 1] then
            Check(c.box[1] + c.box[3] + GAP <= cards[i + 1].box[1] + 0.5, label .. ": cards " .. i .. " and " .. (i + 1) .. " meet")
        end
    end
end

-- How far each card's mark is from the card across the page (0 under it).
local function Off(plate, c)
    local mark
    for _, it in ipairs(plate.margin or {}) do
        if it.note == c then mark = it.x end
    end
    if not mark then return math.huge end
    if mark < c.box[1] then return c.box[1] - mark end
    if mark > c.box[1] + c.box[3] then return mark - (c.box[1] + c.box[3]) end
    return 0
end

--------------------------------------------------------------------------
Section("two cards under one plate: the row's room, XL, the item boxed")

ns.SetSetting("keepRoute", true)
do
    local plate, cards = Draw(2)
    Check(plate.captionOver, "setup: the caption over the plate, the row under it")
    Eq(#cards, 2, "both shown")
    local share = math.floor(math.min(ROW.most, (X1 - X0 - GAP) / 2))
    Eq(plate.marginRow, share, "the row's share for each")
    for i, c in ipairs(cards) do
        Eq(c.freeSize, "xl", "card " .. i .. " at XL")
        Check(c.freeBits.box.button:IsShown(), "card " .. i .. ": its item boxed")
        Check(not c.overfull, "card " .. i .. " fits")
        Eq(Off(plate, c), 0, "card " .. i .. " under its mark")
    end
    Tidy("two", plate, cards)
end

--------------------------------------------------------------------------
Section("one card: at most ROW.most, under its mark")

do
    local plate, cards = Draw(1)
    Eq(#cards, 1, "shown")
    Eq(plate.marginRow, ROW.most, "as wide as a card in a row goes")
    Eq(cards[1].freeSize, "xl", "at XL")
    Eq(Off(plate, cards[1]), 0, "under its mark")
    Tidy("one", plate, cards)
end

--------------------------------------------------------------------------
Section("three cards: the row as it was")

do
    local plate, cards = Draw(3)
    Eq(#cards, 3, "all three")
    Eq(plate.marginRow, nil, "not shared out")
    for i, c in ipairs(cards) do
        Eq(c.freeSize, "m", "card " .. i .. " at M, its box's 142")
        Eq(c.box[1], ROWBOX[i].x, "card " .. i .. " in the row's own box")
    end
end

--------------------------------------------------------------------------
Section("\"Keep my own route\" off: the shorter foot, and the band that shows the most")

do
    ns.SetSetting("keepRoute", false)
    local foot = ns.UI.JourneyLook.CAPTION.offLimit
    for _, n in ipairs({ 1, 2 }) do
        local plate, cards = Draw(n)
        Eq(#cards, n, n .. ": all shown")
        for i, c in ipairs(cards) do
            Check(c.box[2] + c.box[4] <= foot + 0.5, n .. ": card " .. i .. " past the foot")
            -- (wider, each would give up its item's box and the icon over
            -- its name for that foot: at M it gives up nothing)
            Eq(c.freeSize, "m", n .. ": card " .. i .. " at the band that gives up least")
            Check(c.freeBits.small.icon:IsShown(), n .. ": card " .. i .. "'s item kept, its icon")
            Check(c.freeIcon ~= nil, n .. ": card " .. i .. "'s icon over its name kept")
            Eq(Off(plate, c), 0, n .. ": card " .. i .. " under its mark")
        end
        Tidy("route off " .. n, plate, cards)
    end
    ns.SetSetting("keepRoute", true)
end

--------------------------------------------------------------------------
Section("the rows tried, and their boxes")

do
    local function Boxes()
        local boxes = { row = true }
        for k, box in ipairs(ROWBOX) do boxes[k] = box end
        return boxes
    end
    -- Only people's strips: the row as it is, nothing else tried.
    local people = { { kind = "person", x = 100 }, { kind = "person", x = 300 } }
    local tries = YourDiary.Rows(people, Boxes())
    Eq(#tries, 1, "people alone: one way")
    Check(not tries[1].shared, "and the row as it is")
    -- Three notes: as it is.
    local three = { { kind = "foe", x = 50 }, { kind = "find", x = 200 }, { kind = "person", x = 400 } }
    tries = YourDiary.Rows(three, Boxes())
    Eq(#tries, 1, "three notes: one way")
    Check(not tries[1].shared, "and the row as it is")
    -- A card beside a strip: widest first, down to the row's own width.
    local two = { { kind = "person", x = 100 }, { kind = "foe", x = 300 } }
    tries = YourDiary.Rows(two, Boxes())
    local share = math.floor(math.min(ROW.most, (X1 - X0 - GAP) / 2))
    Eq(tries[1].w, share, "the share first")
    Eq(tries[#tries].w, ROWBOX[1].w, "the row's own width last")
    for k = 2, #tries do Check(tries[k].w < tries[k - 1].w, "widest first") end
    for _, tried in ipairs(tries) do
        for i = 1, 2 do
            local box = tried[i]
            Check(box.x >= X0 and box.x + box.span <= X1, "a box off the row at " .. tried.w)
        end
        Check(tried[1].x + tried[1].span + GAP <= tried[2].x + 1e-6, "two boxes meet at " .. tried.w)
        Eq(tried.keyed[two[1]], tried[1], "each note its own box, by its mark")
    end
    -- Two marks close together, cards narrower than their boxes (spans):
    -- laid together, the run as near both marks as can be.
    local near = { { kind = "foe", x = 245 }, { kind = "find", x = 265 } }
    local spans = { [near[1]] = 180, [near[2]] = 131 }
    local at = YourDiary.RowAt(near, Boxes(), 217, 142, spans)
    local a, b = at.keyed[near[1]], at.keyed[near[2]]
    Eq(a.span, 180, "the first's span")
    Eq(a.w, 217, "laid at the row's width")
    Check(math.abs(b.x - (a.x + a.span) - GAP) < 1e-6, "laid together, a gap apart")
    Check(math.abs((a.x + a.span / 2 - 245) + (b.x + b.span / 2 - 265)) < 1, "the run not centred on its marks")
    Check(a.x <= 245 and a.x + a.span >= 245 and b.x <= 265 + 131, "the leaders not short")
    -- Spread marks: each box under its mark.
    local far = { { kind = "foe", x = 80 }, { kind = "find", x = 380 } }
    at = YourDiary.RowAt(far, Boxes(), 217, 142, { [far[1]] = 120, [far[2]] = 120 })
    for _, it in ipairs(far) do
        local box = at.keyed[it]
        Eq(box.x + box.span / 2, it.x, "a box not centred under its mark")
    end
    -- Near the row's end: kept inside it.
    local edge = { { kind = "foe", x = 5 }, { kind = "find", x = 460 } }
    at = YourDiary.RowAt(edge, Boxes(), 217, 142, { [edge[1]] = 150, [edge[2]] = 150 })
    Eq(at.keyed[edge[1]].x, X0, "the first inside the row's left end")
    Eq(at.keyed[edge[2]].x + 150, X1, "the last inside its right end")
end
