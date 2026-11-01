-- The creature that nearly got you, on Your Diary's plates (JRN-25): the
-- killer card (Features/Deaths/Card.lua, ns.Deaths.Card, "Cut in ink")
-- worn with a face of its own (Deaths' Card.RegisterFace), beside its
-- killer's card, if any: a close call and a death are two fights, even
-- with the same creature (the user's choice, 11 Oct). The same card under
-- a heading in the diary's hand, "A close call", its creature's level on a
-- pasted label over its name and the fight charted under it (VITALS), its
-- leader to the cross in outline (Mark.lua); in the margin after the
-- killer's, so it is left off first.
--
-- The card is Deaths': its slip, its picture ladder (the silhouette, the
-- print, the name alone), its name and tooltip, its pool in the margin
-- (page.killerPool), reached as ns.Deaths.Card at call time (New, KILLER,
-- RANK), so this folder loads after Deaths'. What is the close call's is
-- here: the face (its heading, tag and chart, drawn on the card; the
-- card's SetFoe and Deed, put on every card by Deaths' New), the plate's
-- one creature chosen (Choose), the pass that chooses it over the plate
-- and the note in the margin. The witnesses' card (Features/Witnesses/
-- Card.lua) charts a rescue with VITALS, read at call time as
-- ns.CloseCalls.Card.VITALS.

local addonName, ns = ...

local Style = ns.Style
local CloseCalls = ns.CloseCalls

local Card = {}
CloseCalls.Card = Card

-- The close call's card (SetFoe) writes the fight down under the
-- creature's name, as a nurse's chart would, so no two read alike. Down
-- the slip:
--   the heading what the card is, "A close call" (Text.lua's Heading), as
--               the margin's other cards have theirs: in the hand
--               (FONT.noteWritten) at the slip's top left, at KILLER.small
--               where the column is too narrow for it at that size. The
--               slip's tape keeps clear of it, `tapeAt` of the way along
--               (further right than a killer's, so a narrow slip still
--               holds both)
--   the picture `head.gap` px under it, as a killer's; where the margin
--               has too little height left for the card, drawn `compact`
--               (`w` by `h`), and where even that is too tall, given up
--   the tag     the creature's level and rank, "Lv 45 (Elite)", "Lv ??
--               (Boss)", "Lv 12", or the rank alone where no level was
--               kept (Text.lua's Tag): a small label of `paper` pasted on the
--               slip `gap` px under the picture and `under` px over the
--               name, at its left, as a specimen's label under its
--               drawing; its words in small ink `pad` px in, an ink `edge`,
--               turned `turn` degrees (within, seeded by its words), with a
--               hair of `shadow`. Where the column is too narrow for it on
--               one line, the rank on a line under the level
--   the bar     the health you came out with: a box ruled in ink at
--               `edge`, `w` by `h` (`narrow` under KILLER.narrow.below),
--               filled from the left in rubric to the health left (at least
--               `least` px, so 1 % still shows), the rest the slip's paper;
--               a graphite `tick` at a tenth, where a close call begins,
--               `over` px past the box above and below, so how far under
--               it you were reads at a glance
--   the figure  the health left, "4%", large in the hand (`size`), in
--               rubric, `gap` px right of the bar, its foot on the bar's
--   the deed    in small ink, how many it was against ("fought against
--               three"), only when more than one: on the same row,
--               `gap` px past the figure, its foot on the bar's, where the
--               column has room; else the line under them. Kept short so
--               the card stands no taller than it must (a three-plate
--               margin has little room)
-- (11 Oct, in the client: "nearly got you" under the name alone was flat;
-- then the fight's time said nothing, and wax seals with a rank's initial
-- were not clear enough. 12 Oct, the user: a heading saying what the card
-- is, over everything, and the tag off the corner, over the name.)
local VITALS = {
    head = { gap = 0 }, tapeAt = 0.9, compact = { w = 62, h = 32 },
    bar = { w = 70, h = 7, edge = 0.8, least = 1.5, tick = { at = 0.10, over = 2, width = 1, alpha = 0.55 } },
    narrow = 56, figure = { size = 22, gap = 5 }, deed = { gap = 7 }, room = { gap = 2, after = 2 },
    tag = { paper = { 0.97, 0.94, 0.84 }, pad = { 4, 1 }, gap = 2, under = 1, turn = { 1, 2.5 }, edge = 0.30,
        shadow = { 0.6, 0.8, 0.16 } },
}
Card.VITALS = VITALS

local HAND = Style.NEUTON_ITALIC

--------------------------------------------------------------------------
-- Which creature
--------------------------------------------------------------------------

-- The creature that nearly got you on a plate, from its close calls'
-- marks (plate.closeMarks: { at (on the page), list of moments }), or
-- nil: only a close call with a creature named has one. The highest rank
-- (the killer card's RANK), then the least health left, then the latest.
-- { npcID, name, rank, display, call (its record), mark (where its cross
-- is on the page) }. A close call the player changed or wrote is not among
-- them: it has a card of its own (Card.Customs).
local function Foe(call, mark)
    local display = ns.Plain(call.display)
    return { npcID = call.npcID, name = call.name, rank = call.rank, call = call, mark = mark,
        display = type(display) == "number" and display > 0 and display or nil }
end

-- The close calls on a plate the player changed or wrote (Core/Custom.lua),
-- each with its creature named, a card each and the newest first, so that
-- where the margin runs out the oldest are the ones left to their marks.
function Card.Customs(marks)
    local list = {}
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local call = m.call
            if call and call.customOf and type(call.name) == "string" and call.name ~= "" then
                list[#list + 1] = Foe(call, mark.at)
            end
        end
    end
    table.sort(list, function(a, b) return (a.call.t or 0) > (b.call.t or 0) end)
    return list
end

function Card.Choose(marks)
    local RANK = ns.Deaths.Card.RANK
    local best
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local call = m.call
            if call and not call.customOf and type(call.name) == "string" and call.name ~= "" then
                local better = not best
                if best then
                    local ra, rb = RANK[call.rank] or 0, RANK[best.call.rank] or 0
                    if ra ~= rb then
                        better = ra > rb
                    elseif (call.pct or 0) ~= (best.call.pct or 0) then
                        better = (call.pct or 0) < (best.call.pct or 0)
                    else
                        better = (call.t or 0) > (best.call.t or 0)
                    end
                end
                if better then best = { call = call, mark = mark.at } end
            end
        end
    end
    if not best then return nil end
    return Foe(best.call, best.mark)
end

--------------------------------------------------------------------------
-- The face on the killer card
--------------------------------------------------------------------------

-- The heading, chart and tag (VITALS) on `card`: made when first wanted,
-- drawn on the slip (card.vitals).
local function Vitals(card)
    if card.vitals then return card.vitals end
    local vitals = {
        heading = Style.Text(card, Style.FONT.noteWritten),
        edge = card:CreateTexture(nil, "ARTWORK", nil, 1),
        paper = card:CreateTexture(nil, "ARTWORK", nil, 2),
        fill = card:CreateTexture(nil, "ARTWORK", nil, 3),
        tick = card:CreateTexture(nil, "ARTWORK", nil, 4),
        figure = Style.Text(card, Style.FONT.noteWritten),
        deed = Style.Text(card, Style.FONT.small),
        tagShadow = card:CreateTexture(nil, "ARTWORK", nil, 1),
        tagEdge = card:CreateTexture(nil, "ARTWORK", nil, 2),
        tagPaper = card:CreateTexture(nil, "ARTWORK", nil, 3),
        tagText = Style.Text(card, Style.FONT.small),
    }
    for _, texture in ipairs({ vitals.edge, vitals.paper, vitals.fill, vitals.tick, vitals.tagShadow,
        vitals.tagEdge, vitals.tagPaper }) do
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
    end
    card.vitals = vitals
    return vitals
end

local function Width(text)
    text:SetSize(0, 0)
    return math.ceil(text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth() or 0)
end

-- The heading's words in the hand, at FONT.noteWritten's own size or
-- at `size`; its width and height.
local function Heading(card, size)
    local v = Vitals(card)
    v.heading:SetFontObject(Style.FONT.noteWritten)
    if size then v.heading:SetFont(HAND, size, "") end
    v.heading:SetText(CloseCalls.Heading())
    return Width(v.heading) + 2, math.max(math.ceil(v.heading:GetStringHeight() or 0), 14)
end

-- The figure's words and its width, at the hand's large size.
local function Figure(card, f)
    local v = Vitals(card)
    v.figure:SetFontObject(Style.FONT.noteWritten)
    v.figure:SetFont(HAND, VITALS.figure.size, "")
    v.figure:SetText(((f.call and f.call.pct) or 0) .. "%")
    return Width(v.figure) + 2, math.max(math.ceil(v.figure:GetStringHeight() or 0), VITALS.figure.size)
end

-- The tag's words (Text.lua's Tag), and its size, or nil without one;
-- `split`, its rank on a line of its own under its level.
local function Tag(card, f, split)
    local words = CloseCalls.Tag(f.call or f)
    if not words then return nil end
    local lines = { words }
    if split then
        local level, rank = words:match("^(.-) (%(.+%))$")
        if level then lines = { level, rank } end
    end
    -- Each line measured on its own, the widest kept.
    local v, G = Vitals(card), VITALS.tag
    local w, h = 0, 0
    for _, line in ipairs(lines) do
        v.tagText:SetText(line)
        w = math.max(w, Width(v.tagText))
        h = h + math.max(math.ceil(v.tagText:GetStringHeight() or 0), 10)
    end
    words = table.concat(lines, "\n")
    v.tagText:SetText(words)
    return words, w + 2 * G.pad[1] + 1, h + 2 * G.pad[2]
end

-- The deed's words and width, for the row.
local function Deed(card, f)
    local v = Vitals(card)
    v.deed:SetText(CloseCalls.Deed(f.call or {}))
    return Width(v.deed) + 2, math.max(math.ceil(v.deed:GetStringHeight() or 0), 11)
end

-- The chart in the room the strip kept under the name (card.under).
-- `inline`: the deed on the row.
local function DrawVitals(card, barW, inline)
    local f, room = card.foe, card.under
    if not (f and room) then return end
    local v, B, R, INK = Vitals(card), VITALS.bar, Style.RUBRIC, Style.INK
    -- The bar's empty part is the slip's own stock.
    local P = card:Paper()
    local pct = math.max(0, math.min(100, (f.call and f.call.pct) or 0))
    -- The bar at the room's left, its foot on the room's.
    local left, foot = room.lx - room.w / 2, room.ly + room.h / 2
    local bx, by = left + barW / 2, foot - B.h / 2 - 1
    v.edge:SetColorTexture(INK[1], INK[2], INK[3], B.edge)
    card:Lay(v.edge, bx, by, barW + 2, B.h + 2)
    v.paper:SetColorTexture(P[1], P[2], P[3], 1)
    card:Lay(v.paper, bx, by, barW, B.h)
    local fw = math.max(B.least, barW * pct / 100)
    v.fill:SetColorTexture(R[1], R[2], R[3], 0.95)
    card:Lay(v.fill, left + fw / 2, by, fw, B.h)
    local G, T = Style.GRAPHITE, B.tick
    v.tick:SetColorTexture(G[1], G[2], G[3], T.alpha)
    card:Lay(v.tick, left + barW * T.at, by, T.width, B.h + 2 + 2 * T.over)
    -- The figure beside it, its foot on the bar's.
    local fW, fH = Figure(card, f)
    v.figure:SetTextColor(R[1], R[2], R[3])
    card:Lay(v.figure, left + barW + VITALS.figure.gap + fW / 2, foot - fH / 2 + 2, fW, fH)
    for _, key in ipairs({ "edge", "paper", "fill", "tick", "figure" }) do v[key]:Show() end
    if inline then
        local dW, dH = Deed(card, f)
        v.deed:SetTextColor(INK[1], INK[2], INK[3])
        card:Lay(v.deed, left + barW + VITALS.figure.gap + fW + VITALS.deed.gap + dW / 2, foot - dH / 2, dW, dH)
        v.deed:Show()
    else
        v.deed:Hide()
    end
end

-- Over the name, in the room the strip kept there (card.picture, as
-- laid): the heading at its top, the picture under it, the tag at its
-- foot (`top`, the face's plan). The picture's own room is then
-- card.picture, nil without one.
local function DrawTop(card, top)
    local v, room = Vitals(card), card.picture
    if not room then return end
    local left, at = room.lx - room.w / 2, room.ly - room.h / 2
    local S = Style.INK_STRONG
    v.heading:SetTextColor(S[1], S[2], S[3])
    card:Lay(v.heading, left + top.hw / 2, at + top.hh / 2, top.hw, top.hh)
    v.heading:Show()
    -- For the tests: the heading's box on the slip, as laid flat (x0,
    -- y0, x1, y1, from the slip's middle).
    card.heading = { left, at, left + top.hw, at + top.hh }
    at = at + top.hh
    card.picture = nil
    if top.pic then
        local lx, ly = left + top.pic.w / 2, at + VITALS.head.gap + top.pic.h / 2
        local X, Y = card:Screen(lx, ly)
        local px, py = card:Out(lx, ly)
        card.picture = { lx = lx, ly = ly, w = top.pic.w, h = top.pic.h, X = X, Y = Y, x = px, y = py }
        at = at + VITALS.head.gap + top.pic.h
    end
    -- The tag, pasted at the left over the name, for a level or a rank
    -- kept.
    for _, key in ipairs({ "tagShadow", "tagEdge", "tagPaper", "tagText" }) do v[key]:SetShown(top.tag ~= nil) end
    card.tag = nil
    if not top.tag then return end
    local G, INK = VITALS.tag, Style.INK
    local tw, th = top.tw, top.th
    local tx, ty = left + tw / 2, at + G.gap + th / 2
    local seed = 0
    for i = 1, #top.tag do seed = seed + top.tag:byte(i) * i end
    local more = card.flat and 0 or math.rad(G.turn[1] + (G.turn[2] - G.turn[1]) * Style.Noise(seed))
    local D = G.shadow
    v.tagShadow:SetColorTexture(INK[1], INK[2], INK[3], card.flat and 0 or D[3])
    card:Lay(v.tagShadow, tx + D[1], ty + D[2], tw, th, more)
    v.tagEdge:SetColorTexture(INK[1], INK[2], INK[3], G.edge)
    card:Lay(v.tagEdge, tx, ty, tw + 1, th + 1, more)
    v.tagPaper:SetColorTexture(G.paper[1], G.paper[2], G.paper[3], 1)
    card:Lay(v.tagPaper, tx, ty, tw - 1, th - 1, more)
    v.tagText:SetTextColor(S[1], S[2], S[3])
    card:Lay(v.tagText, tx, ty, tw - 2 * G.pad[1], th - 2 * G.pad[2], more)
    -- For the tests: the tag's box on the slip, as the heading's.
    card.tag = { text = top.tag, box = { tx - tw / 2, ty - th / 2, tx + tw / 2, ty + th / 2 } }
end

-- The face (Deaths' Card.RegisterFace): the card worn for the creature
-- that nearly got you (card.foe, Choose's), with its heading and tag round
-- the picture and its chart (VITALS) under the name, its picture drawn
-- small (VITALS.compact, card.compact) where it would stand taller than
-- the margin's room.
local FACE
FACE = ns.Deaths.Card.RegisterFace("foe", {
    methods = {
        -- The card for the creature that nearly got you (Choose's): its
        -- heading, its name with its tag over it, the fight under it
        -- (VITALS), the close call's tooltip; its leader to the cross in
        -- outline.
        SetFoe = function(card, f, seed, now)
            local KILLER = ns.Deaths.Card.KILLER
            card.foe, card.bare = f, nil
            card:Wear(FACE, f, { name = f.name, what = CloseCalls.Deed(f.call), strong = true, seed = seed,
                tapeAt = KILLER.tapeAt, turn = KILLER.turn,
                tip = function()
                    local title, lines = CloseCalls.FoeTip(f.call, now)
                    return Style.TipList(title, lines)
                end })
        end,
        -- The close call's deed as written, on the row or under it (for
        -- the tests).
        Deed = function(card)
            local vitals = card.vitals
            if vitals and vitals.deed:IsShown() then return vitals.deed:GetText() end
            return card:What()
        end,
    },
    -- The room over the name (the heading, at the smaller hand where the
    -- slip would be too wide for it and its tape; the picture; the tag,
    -- its rank under its level where it is too wide) and under it (the
    -- chart, and the deed on its row where the column has room, else
    -- under it as the note's words).
    plan = function(card, note, width, room, pic, Least)
        local KILLER = ns.Deaths.Card.KILLER
        local f = card.foe
        local barW = width < KILLER.narrow.below and VITALS.narrow or VITALS.bar.w
        local fW, fH = Figure(card, f)
        local dW = Deed(card, f)
        local row = barW + VITALS.figure.gap + fW
        local deed = not card.bare and CloseCalls.Deed(f.call or {}) or ""
        local inline = deed ~= "" and row + VITALS.deed.gap + dW <= room
        if inline then row = row + VITALS.deed.gap + dW end
        note.what = not inline and deed or ""
        note.under = { w = row, h = math.max(fH, VITALS.bar.h + 2), gap = VITALS.room.gap,
            after = VITALS.room.after }
        if pic and card.compact then pic = VITALS.compact end
        local hw, hh = Heading(card)
        if Least(hw, VITALS.tapeAt) > width then hw, hh = Heading(card, KILLER.small) end
        local tag, tw, th = Tag(card, f)
        if tag and tw > room then tag, tw, th = Tag(card, f, true) end
        local top = { hw = hw, hh = hh, pic = pic, tag = tag, tw = tw, th = th }
        note.picture = { w = math.max(hw, pic and pic.w or 0, tw or 0),
            h = hh + (pic and VITALS.head.gap + pic.h or 0) + (tag and VITALS.tag.gap + th or 0),
            gap = tag and VITALS.tag.under or KILLER.picture.gap }
        note.tapeAt = VITALS.tapeAt
        note.least = Least(hw, VITALS.tapeAt)
        return { barW = barW, inline = inline, top = top }
    end,
    top = function(card, plan) DrawTop(card, plan.top) end,
    under = function(card, plan) DrawVitals(card, plan.barW, plan.inline) end,
    hide = function(card)
        local vitals = card.vitals
        if vitals then
            for _, region in pairs(vitals) do region:Hide() end
        end
        card.tag, card.heading = nil, nil
    end,
    off = function(card)
        card.foe, card.bare = nil, nil
    end,
    -- Where the margin has too little room for it, it gives up its
    -- picture first (drawn small and still too tall: Layout's `room`),
    -- then its deed (the tooltip still says it): the chart is what it is
    -- kept for.
    smaller = function(card)
        if card.mode ~= "name" then
            card.mode = "name"
            return true
        end
        if not card.bare and CloseCalls.Deed(card.foe.call or {}) ~= "" then
            card.bare = true
            return true
        end
        return false
    end,
})

--------------------------------------------------------------------------
-- On the plates: the pass over the crosses, and the margin's note
--------------------------------------------------------------------------

-- The creature that nearly got you, from the close calls' marks
-- (plate.closeMarks, kept by Mark.lua's mark): its card goes in the
-- margin beside the killer's, if there is one (a close call and a death
-- are two fights, even with the same creature). After the killer's pass
-- (Deaths', 10), before the witness's (30), which may take its place.
ns.UI.JourneyPlate.RegisterPass("foe", {
    order = 20,
    draw = function(plate)
        plate.foe = Card.Choose(plate.closeMarks)
        plate.customFoes = Card.Customs(plate.closeMarks)
    end,
})

-- What nearly got you (a close call's creature): a fight of its own, so
-- its card is beside the killer's, the same creature or not (the user's
-- choice, 11 Oct), the same card charted (SetFoe, so the same pool, the
-- killer's, page.killerPool). After the killer's (40). Shown, the words
-- only say there was a close call.
ns.UI.JourneyMargin.Register("foe", {
    order = 50, pool = "killerPool", count = "foesWritten",
    new = function(parent) return ns.Deaths.Card.New(parent) end,
    item = function(plate)
        local f = plate.foe
        return f and { foe = f, top = f.mark[2], x = f.mark[1] } or nil
    end,
    write = function(card, it, c)
        card:SetFoe(it.foe, c.Seed("foe", it.foe.npcID or it.foe.name), c.now)
    end,
    mark = function(it) return it.foe.mark end,
    custom = function(it) return "close", it.foe.call end,
    assume = function(said, plate)
        if plate.foe then said.close = true end
    end,
    say = function(said, shown)
        if shown[1] then said.close = true end
    end,
})

-- The close calls the player changed or wrote, each its own card, past the
-- plate's one (Card.Choose) and never replaced by a witness's: first of all
-- in the margin, before the people (10), so they are the last left off
-- (.claude/features/custom-cards.md). The same card, the same pool.
ns.UI.JourneyMargin.Register("foeCustom", {
    order = 5, pool = "killerPool", count = "customFoesWritten",
    new = function(parent) return ns.Deaths.Card.New(parent) end,
    items = function(plate)
        local items = {}
        for _, f in ipairs(plate.customFoes or {}) do
            items[#items + 1] = { foe = f, top = f.mark[2], x = f.mark[1] }
        end
        return items
    end,
    write = function(card, it, c)
        card:SetFoe(it.foe, c.Seed("foe", it.foe.call.t or it.foe.name), c.now)
    end,
    mark = function(it) return it.foe.mark end,
    custom = function(it) return "close", it.foe.call end,
    assume = function(said, plate)
        if plate.customFoes and plate.customFoes[1] then said.close = true end
    end,
    say = function(said, shown)
        if shown[1] then said.close = true end
    end,
})
