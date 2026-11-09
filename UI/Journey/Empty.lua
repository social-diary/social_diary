-- Your Diary with nothing on the road yet (JRN-13), in the style of the
-- empty People page (UI/Journal/Empty.lua): on the left why it is empty
-- (the setting off, with the way to keep it, or nothing walked yet) and an
-- entry as it will read, in pencil; on the right a plate sketched in
-- pencil with what each mark will be written in the margin, its caption,
-- and the promise. Built once (BuildEmpty); which of the two, at each
-- refresh (FillEmpty).
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local FONT = Style.FONT
local YourDiary = ns.UI.YourDiary

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, RIGHT_X, RIGHT_W = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X, BOOK.RIGHT_W

local ENTRY, LEDGER = YourDiary.ENTRY, YourDiary.LEDGER
local EMPTY, SKETCH, NOTES = YourDiary.EMPTY, YourDiary.SKETCH, YourDiary.NOTES

--------------------------------------------------------------------------
-- The empty page
--------------------------------------------------------------------------

local function Paragraph(parent, font, width)
    local text = Style.Text(parent, font)
    text:SetWidth(width)
    text:SetSpacing(2)
    return text
end

-- Pencil at x, y on the page (y down from its top).
local function Pencilled(parent, font, x, y, text)
    local t = Style.Text(parent, font)
    t:SetPoint("TOPLEFT", x, -y)
    t:SetText(text)
    return t
end

-- A point of the sketch (0..1 across and down it) on the page, turned with
-- it about its middle.
local function SketchAt(u, v)
    local S = SKETCH
    local a = math.rad(S.turn)
    local cx, cy = (u - 0.5) * S.w, (v - 0.5) * S.h
    return S.x + S.w / 2 + cx * math.cos(a) - cy * math.sin(a), S.y + S.h / 2 + cx * math.sin(a) + cy * math.cos(a)
end

-- A round pencil mark at a point of the sketch.
local function SketchDisc(parent, layer, sublevel, u, v, size, colour, alpha)
    local x, y = SketchAt(u, v)
    local disc = parent:CreateTexture(nil, layer, nil, sublevel)
    disc:SetSize(size, size)
    disc:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
    Style.Disc(disc, colour[1], colour[2], colour[3], alpha)
    return disc
end

-- The right page, empty: a plate sketched in pencil, glued in at three
-- corners, what each mark will be written beside it, its caption under
-- it, and the promise.
local function BuildEmptyRight(e)
    local G, P, A = Style.GRAPHITE, Style.PAPER, Style.ACCENT
    local lede = Style.Text(e, FONT.faded)
    lede:SetPoint("TOPLEFT", RIGHT_X, -22)
    lede:SetText(L["Each level's places are glued in here:"])

    -- The card's edge, a little askew, and the art's frame inside it.
    local function Edge(u1, v1, u2, v2, alpha)
        local x1, y1 = SketchAt(u1, v1)
        local x2, y2 = SketchAt(u2, v2)
        Style.Stroke(e, "ARTWORK", x1, y1, x2, y2, G, alpha, 1)
    end
    for _, box in ipairs({ { 0, 1, SKETCH.alpha }, { 0.04, 0.96, 0.45 } }) do
        local a, b = box[1], box[2]
        local c, d = a == 0 and 0 or 0.055, b == 1 and 1 or 0.945
        Edge(a, c, b, c, box[3])
        Edge(b, c, b, d, box[3])
        Edge(b, d, a, d, box[3])
        Edge(a, d, a, c, box[3])
    end
    -- Photo corners, outlined, at three corners; the fourth come unstuck.
    local pu, pv = SKETCH.pc / SKETCH.w, SKETCH.pc / SKETCH.h
    local ou, ov = SKETCH.out / SKETCH.w, SKETCH.out / SKETCH.h
    for _, c in ipairs({ { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 } }) do
        local u0, v0 = c[1] - c[3] * ou, c[2] - c[4] * ov
        local u1, v1 = u0 + c[3] * pu, v0 + c[4] * pv
        Edge(u0, v0, u1, v0, 0.8)
        Edge(u0, v0, u0, v1, 0.8)
        Edge(u1, v0, u0, v1, 0.8)
    end

    -- A road through three stops, a flight off the edge, a dungeon's door.
    local road = { { 0.12, 0.78 }, { 0.22, 0.70 }, { 0.30, 0.58 }, { 0.42, 0.52 }, { 0.55, 0.50 },
        { 0.62, 0.40 }, { 0.70, 0.30 }, { 0.80, 0.26 } }
    for i = 2, #road do
        local x1, y1 = SketchAt(road[i - 1][1], road[i - 1][2])
        local x2, y2 = SketchAt(road[i][1], road[i][2])
        Style.Stroke(e, "ARTWORK", x1, y1, x2, y2, G, 0.85, 1.3)
    end
    SketchDisc(e, "ARTWORK", 0, 0.30, 0.58, 30, G, 0.18)
    SketchDisc(e, "ARTWORK", 1, 0.30, 0.58, 16, G, 0.45)
    SketchDisc(e, "ARTWORK", 0, 0.70, 0.30, 20, G, 0.14)
    SketchDisc(e, "ARTWORK", 1, 0.70, 0.30, 10, G, 0.35)
    -- The flight, dashed, from the last stop off to the right edge.
    local fx1, fy1 = SketchAt(0.80, 0.26)
    local fx2, fy2 = SketchAt(0.94, 0.12)
    local dx, dy = fx2 - fx1, fy2 - fy1
    local length = math.sqrt(dx * dx + dy * dy)
    for d = 0, length - 3, 7 do
        local t1, t2 = d / length, math.min(d + 4, length) / length
        Style.Stroke(e, "ARTWORK", fx1 + dx * t1, fy1 + dy * t1, fx1 + dx * t2, fy1 + dy * t2, A, 0.75, 1.2)
    end
    -- The dungeon's door: two posts and a lintel.
    local gx, gy = SketchAt(0.55, 0.72)
    Style.Stroke(e, "OVERLAY", gx - 4, gy - 4, gx - 4, gy + 4, G, 0.9, 1.6)
    Style.Stroke(e, "OVERLAY", gx + 4, gy - 4, gx + 4, gy + 4, G, 0.9, 1.6)
    Style.Stroke(e, "OVERLAY", gx - 5, gy - 4.5, gx + 5, gy - 4.5, G, 0.9, 1.6)
    local road2 = { { 0.55, 0.50 }, { 0.56, 0.60 }, { 0.55, 0.68 } }
    for i = 2, #road2 do
        local x1, y1 = SketchAt(road2[i - 1][1], road2[i - 1][2])
        local x2, y2 = SketchAt(road2[i][1], road2[i][2])
        Style.Stroke(e, "ARTWORK", x1, y1, x2, y2, G, 0.6, 1)
    end
    -- Who you were with: a ring at the first stop. A level reached: a
    -- numbered mark on the road.
    SketchDisc(e, "OVERLAY", 0, 0.36, 0.62, 11, G, 0.9)
    SketchDisc(e, "OVERLAY", 1, 0.36, 0.62, 5, P, 1)
    SketchDisc(e, "OVERLAY", 0, 0.47, 0.51, 15, G, 0.85)
    local px, py = SketchAt(0.47, 0.51)
    local pin = Style.Text(e, FONT.tag)
    pin:SetPoint("CENTER", e, "TOPLEFT", px, -py)
    pin:SetText("12")

    -- The notes in the margin: { y of the note, what it points to (u, v) }.
    local notes = {
        { 4, L["Where you stayed a while, darker the longer."], 0.30, 0.58 },
        { 44, L["The roads between."], 0.22, 0.70 },
        { 80, L["Flights, dashed. Dungeons, where you went in."], 0.87, 0.19 },
        { 122, L["Who you met there, written in the margin."], 0.36, 0.62 },
        { 160, L["Where the level came."], 0.47, 0.51 },
    }
    for _, n in ipairs(notes) do
        local text = Style.Text(e, FONT.margin)
        text:SetPoint("TOPLEFT", NOTES.x, -SKETCH.y - n[1])
        text:SetWidth(NOTES.w)
        text:SetText(n[2])
        local fx, fy = NOTES.x - 4, SKETCH.y + n[1] + 7
        local tx, ty = SketchAt(n[3], n[4])
        tx = tx + NOTES.gap
        Style.Curve(e, "ARTWORK", fx, fy, (fx + tx) / 2, fy, tx, ty, A, NOTES.leader, 1, 4)
    end

    -- Its caption, pencilled under it, and what a caption is.
    local y = SKETCH.y + SKETCH.h + 26
    Pencilled(e, FONT.pencil, RIGHT_X + 8, y, L["The Barrens, Tuesday"])
    Pencilled(e, FONT.pencil, RIGHT_X + 8, y + 18, L["Level 12, and a death by the oasis."])
    local note = Style.Text(e, FONT.margin)
    note:SetPoint("TOPLEFT", NOTES.x, -y - 4)
    note:SetWidth(NOTES.w)
    note:SetText(L["A few words for each place, up to three a level."])
    Style.Curve(e, "ARTWORK", NOTES.x - 4, y + 11, NOTES.x - 20, y + 11, RIGHT_X + 8 + 250, y + 25, A,
        NOTES.leader, 1, 3)

    local INK = Style.INK
    local rule = e:CreateTexture(nil, "ARTWORK")
    rule:SetSize(60, 1)
    rule:SetPoint("TOPLEFT", RIGHT_X, -470)
    rule:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
    local promise = Paragraph(e, FONT.body, RIGHT_W)
    promise:SetPoint("TOPLEFT", RIGHT_X, -482)
    promise:SetText(L["A recap of where you went and who you were with. It counts no quests and keeps no score."])
end

-- The left page, empty: why, and an entry as it will read, in pencil.
local function BuildEmptyLeft(e)
    e.heading = Style.Rubric(e, LEFT_W)
    e.heading:SetPoint("TOPLEFT", LEFT_X, -EMPTY.top)
    e.why = Paragraph(e, FONT.body, LEFT_W)
    e.why:SetPoint("TOPLEFT", e.heading, "BOTTOMLEFT", 0, -EMPTY.under)

    -- With the setting off: the way to keep it, and what it keeps.
    e.keep = Style.Link(e, FONT.body, function()
        ns.JourneyCapture.SetEnabled(true)
        ns.UI.RefreshJourneyPage(true)
    end)
    e.keep:SetText(L["Keep my own route"])
    e.keep:SetPoint("TOPLEFT", e.why, "BOTTOMLEFT", 0, -EMPTY.under)
    e.only = Paragraph(e, FONT.small, LEFT_W)
    e.only:SetPoint("TOPLEFT", e.keep, "BOTTOMLEFT", 0, -4)
    e.only:SetText(L["Only your own position, never anyone else's."])

    -- The sample entry, under whichever of the two ends lower.
    e.sampleLede = Paragraph(e, FONT.faded, LEFT_W)
    e.sampleLede:SetText(L["Each level gets an entry, like this:"])

    local G = Style.GRAPHITE
    e.sampleTitle = Style.Text(e, FONT.pencilSmall)
    e.sampleTitle:SetPoint("TOPLEFT", e.sampleLede, "BOTTOMLEFT", ENTRY.indent, -EMPTY.gap)
    e.sampleTitle:SetText(ns.UI.JourneyText.Upper(Fmt(L["Level %d"], 12)))
    local paraph = e:CreateTexture(nil, "ARTWORK")
    paraph:SetSize(ENTRY.paraph, ENTRY.paraph)
    paraph:SetRotation(math.pi / 4)
    paraph:SetPoint("CENTER", e.sampleTitle, "LEFT", -ENTRY.indent / 2 - 1, 0)
    paraph:SetColorTexture(G[1], G[2], G[3], 0.8)
    local rule = e:CreateTexture(nil, "ARTWORK")
    rule:SetSize(LEFT_W - ENTRY.indent - 70, 1)
    rule:SetPoint("LEFT", e.sampleTitle, "RIGHT", ENTRY.rule, 0)
    Style.Shade(rule, "HORIZONTAL", G[1], G[2], G[3], 0.45, 0)

    local previous = e.sampleTitle
    for i, line in ipairs({
        L["Reached on 6 October at the Crossroads, The Barrens."],
        L["An hour of quests round the Crossroads. Then Lushwater Oasis."],
        L["With Thex Theximus for forty minutes."],
    }) do
        local t = Paragraph(e, i == 1 and FONT.pencilSmall or FONT.pencil, LEFT_W - ENTRY.indent)
        t:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(i == 1 and 8 or ENTRY.para))
        t:SetText(line)
        previous = t
    end
    -- And its ledger: the zones it was spent in, each a way to its map,
    -- with dot leaders out to their times, as the entries have it.
    local right = LEFT_X + LEFT_W - LEDGER.right
    for i, zone in ipairs({ { L["The Barrens"], L["1 h 20"] }, { L["Stonetalon Mountains"], L["40 min"] } }) do
        local name = Style.Text(e, FONT.pencilSmall)
        name:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(i == 1 and ENTRY.para or 4))
        name:SetText(zone[1])
        local time = Style.Text(e, FONT.pencilSmall)
        time:SetPoint("RIGHT", e, "TOPLEFT", right, 0)
        time:SetPoint("TOP", name, "TOP", 0, 0)
        time:SetText(zone[2])
        local dots = Style.Text(e, FONT.pencilSmall)
        dots:SetPoint("TOPRIGHT", time, "TOPLEFT", -LEDGER.gap, 0)
        dots:SetJustifyH("RIGHT")
        dots:SetWordWrap(false)
        dots:SetAlpha(LEDGER.dotAlpha)
        dots:SetText(LEDGER.dot:rep(20))
        local dotW = (dots:GetUnboundedStringWidth() or 0) / 20
        local room = LEFT_W - ENTRY.indent - LEDGER.right - 2 * LEDGER.gap
            - (name:GetUnboundedStringWidth() or 0) - (time:GetUnboundedStringWidth() or 0)
        dots:SetText(dotW > 0 and room > dotW and LEDGER.dot:rep(math.floor(room / dotW)) or "")
        previous = name
    end
end

local function BuildEmpty(parent)
    local e = CreateFrame("Frame", nil, parent)
    e:SetAllPoints(parent)
    e:Hide()
    BuildEmptyLeft(e)
    BuildEmptyRight(e)
    return e
end

-- Which of the two empty pages: the setting off, or nothing walked yet.
local function FillEmpty(e, on)
    e.heading:SetText(on and L["Your road starts here"] or L["Not keeping your road"], not on)
    e.why:SetText(on and L["Nothing is on it yet. From now on the diary keeps where this character goes: the places you stay a while, the roads between, flights and dungeons, and who you were with."]
        or L["The diary is not keeping this character's road just now, so there is nothing to tell here yet."])
    e.keep:SetShown(not on)
    e.only:SetShown(not on)
    e.sampleLede:ClearAllPoints()
    e.sampleLede:SetPoint("TOPLEFT", on and e.why or e.only, "BOTTOMLEFT", 0, -EMPTY.gap - 4)
end

YourDiary.BuildEmpty, YourDiary.FillEmpty = BuildEmpty, FillEmpty
