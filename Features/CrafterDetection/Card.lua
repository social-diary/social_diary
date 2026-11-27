-- Crafter detection's card in the plates' margin (Your Diary), as signed
-- on 27 Nov 2026 (.claude/ui-proposal/crafter-detection.md, round 3: C,
-- the hand-off drawn, with hand line B). A paper strip (UI/Paper/
-- Strip.lua) taped in the margin with a pencil leader to its needle
-- (Mark.lua), a card each connection:
--   - the hand-off in the diary's hand: who gave, a pen's arrow, who took
--     ("you -> Kaelin Ashby", "Bramwell Pike -> you"); the full names, or
--     the first names where those will not go on one line;
--   - the item boxed as the game shows it, the paper's own box
--     (ns.UI.ItemBox, shared with the find and upgrade cards);
--   - under it the hand line, what the diary saw (WORDS.hand: "you saw
--     Kaelin wear what you made").
-- No graphite line, no "at auction", no dates (the user: "data noise"):
-- how and when are the tooltips'.
--
-- Sizes L (a column of CARD.L px and more) and M (CARD.M and more); no S
-- (the user: "unlegible"), so a narrower column gets no card, and nor does
-- one whose hand-off will not go on one line even by first names. At M the
-- hand line says "them" / "they" for the name (the heading's names fill
-- the row). On a crowded plate a card at L gives up to M first (its
-- `smaller` hook), and only then is left off, the latest first (the
-- margin's order: one item a connection, earliest first, `items`).
--
-- "The upgrade card wins" (the user, 27 Nov): on a plate where Upgrades'
-- card shows the same item, the crafter card for that item gives way; its
-- needle stays. Read off Upgrades' own choice of its card, at call time
-- and one way (ns.Upgrades.Card.Lead: the plate's leading upgrade, nil
-- where a first found of it took the card): Upgrades loads before this
-- feature. Upgrades' card comes first in the margin (22, this 55), so
-- where it is left off for room everything after it is too, and a
-- crafter card never stands in for it.
--
-- The heading is two names round a drawn arrow, not the strip's `name`
-- alone: the taker is the strip's name and the giver and the arrow lie in
-- the room kept before it (the strip's `lead`). So the card's `focus`
-- hook gives the pad both names to turn red (the arrow stays in ink).
--
-- Under the mouse: the item's own tooltip with how and when it changed
-- hands under it (CrafterDetection.ItemLine), the slip the needle's words
-- (CrafterDetection.Tips). Items are never clicked, by the mouse or the
-- pad, and the card opens nothing.
--
-- Laid flat ("Flat paper only") everything lies square, the box as its own
-- header says.

local addonName, ns = ...

local Style = ns.Style

local CrafterDetection = ns.CrafterDetection
local CraftCard = {}
CrafterDetection.Card = CraftCard

-- The card: turned at most `turn` degrees (the other cards'). Its least
-- column at L (`L`, the plates' L band) and at M (`M`, the M band). The
-- hand-off in the hand at FONT.noteWritten's own size, else `small`; the
-- arrow `gap` px from each name, `length` px long, a little bowed (its
-- middle `bow` px up), its head two strokes `head` px back at `spread`
-- radians either side, all `width` px, its line `drop` px under the
-- names' middle (on their x-height, not their capitals). `under` px from
-- the heading to the box, `after` from the box to the hand line; the box
-- leans as the find card's does (`lean`, degrees, seeded). The hand line
-- in the hand at `size` px, `line` px a line, at most `lines` lines.
-- (27 Nov 2026, the mockup at 176 and 142 px: "you -> Kaelin Ashby" on
-- one line at 16 px; at 142 the first names.)
local CARD = { turn = 1.2, L = 150, M = 122, small = 14,
    arrow = { gap = 4, length = 18, bow = 1, head = 3.6, spread = 0.65, width = 1.2, drop = 1 },
    under = 3, after = 3, lean = { least = 1.4, most = 2.6 }, size = 14, line = 17, lines = 2 }
-- A tooltip's line of how and when, in the game's flavour gold.
local TIP = { colour = { 1, 0.82, 0 } }
CraftCard.CARD = CARD

local HAND = Style.NEUTON_ITALIC
local Width = ns.UI.Surface.Width
local L = ns.L

--------------------------------------------------------------------------
-- Which, and "the upgrade card wins"
--------------------------------------------------------------------------

-- Whether Upgrades' card on `plate` shows the item of connection `rec`
-- (the header says what is read, and why).
function CraftCard.Upgraded(plate, rec)
    local cards = ns.Upgrades and ns.Upgrades.Card
    local lead = cards and cards.Lead and cards.Lead(plate)
    local link = lead and lead.rec and lead.rec.link
    return link ~= nil and CrafterDetection.ItemID(link) == rec.id
end

-- The connections on `plate` that may have a card, from its needles
-- (plate.craftedMarks, Mark.lua's `keep`): { meet (the record), m (its
-- moment), mark (its needle on the page), top, x }, earliest first, so the
-- latest is the first left off. Not one whose person was forgotten (no
-- name to write), nor one Upgrades' card tells.
function CraftCard.Items(plate)
    local list = {}
    for _, needle in ipairs(plate.craftedMarks or {}) do
        for _, m in ipairs(needle.list or {}) do
            local rec = m.meet
            if rec and rec.guid and not CraftCard.Upgraded(plate, rec) then
                local at = needle.at or { 0, 0 }
                list[#list + 1] = { meet = rec, m = m, mark = at, top = at[2], x = at[1] }
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.meet.t or 0) ~= (b.meet.t or 0) then return (a.meet.t or 0) < (b.meet.t or 0) end
        return (a.meet.id or 0) < (b.meet.id or 0)
    end)
    return list
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

local function Snapless(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
    return texture
end

-- The item's own tooltip on `owner` (its link; its name alone where the
-- client will not show the link), and `line` under it in flavour gold.
local function ShowItem(owner, rec, line)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = type(GameTooltip.SetHyperlink) == "function" and rec.link
        and pcall(GameTooltip.SetHyperlink, GameTooltip, rec.link)
    if not shown then GameTooltip:SetText(CrafterDetection.Item(rec) or "?") end
    local C = TIP.colour
    if line then GameTooltip:AddLine(line, C[1], C[2], C[3], true) end
    GameTooltip:Show()
end

-- A card on `parent` (the right page): card:SetMeet(item, seed, now) with
-- an item of CraftCard.Items, then laid as a strip. card.craftForm says
-- which size it took ("L" or "M"), card.overfull where it will not go in
-- its column (the page leaves it off). Laid through the strip's hooks,
-- `hooks`, below.
function CraftCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    local pad = { card:Pad() }

    -- The giver, written before the strip's name (the taker), and the
    -- arrow between them.
    card.craftGiver = Style.Text(card, Style.FONT.noteWritten)
    card.craftGiver:Hide()
    card.craftArrow = {}
    -- (the shaft in two strokes, the head in two)
    for i = 1, 4 do card.craftArrow[i] = Snapless(card:CreateTexture(nil, "ARTWORK", nil, 3)) end
    -- The hand line's lines, and a font string to measure them by.
    card.craftHand = {}
    local measure = Style.Text(card, Style.FONT.noteWritten)
    measure:SetFont(HAND, CARD.size, "")
    measure:Hide()

    -- The box, and what the mouse shows on it.
    local box = ns.UI.ItemBox.New(card, parent)
    card.craftBox = box
    function box.enter(button)
        box:Hot(true)
        ShowItem(button, card.craftRec, CrafterDetection.ItemLine(card.craftRec, card.craftNow))
    end
    function box.leave()
        box:Hot(false)
        GameTooltip:Hide()
    end

    -- Both names, for the pad's look (`focus`): turned red together, given
    -- back together. The arrow is ink, not words, and stays as it is.
    local both = {
        SetTextColor = function(_, ...)
            card.name:SetTextColor(...)
            card.craftGiver:SetTextColor(...)
        end,
        GetTextColor = function() return card.name:GetTextColor() end,
    }

    function card:SetMeet(item, seed, now)
        local rec = item.meet
        self.craftItem, self.craftRec, self.craftNow, self.craftSeed = item, rec, now, seed
        self.craftSmall = false
        local ItemBox = ns.UI.ItemBox
        self.craftQuality = ItemBox.Quality(rec.link) or 1
        self.craftIcon = ItemBox.Icon(rec.link)
        self.craftName = CrafterDetection.Item(rec) or "?"
        self:SetNote({ name = "", strong = true, seed = seed, turn = CARD.turn,
            tip = function() return Style.TipList(CrafterDetection.Tips({ item.m }, now)) end })
    end

    -- The heading in the hand at `size` (0: FONT.noteWritten's own).
    local function Hand(text, size)
        text:SetFontObject(Style.FONT.noteWritten)
        if size > 0 then text:SetFont(HAND, size, "") end
    end

    -- The hand-off at the first names and size that go in `room` on one
    -- line, the full names before the first names: the giver, the arrow
    -- and the taker. Whether any did, and the giver's width.
    local function Heading(room, note)
        local rec, A = card.craftRec, CARD.arrow
        local theirs = rec.dir == CrafterDetection.THEIRS
        local you = L["you"]
        local arrow = A.gap * 2 + A.length
        for _, name in ipairs({ CrafterDetection.Person(rec), CrafterDetection.First(rec) }) do
            local giver, taker = theirs and you or name, theirs and name or you
            for _, size in ipairs({ 0, CARD.small }) do
                Hand(card.name, size)
                Hand(card.craftGiver, size)
                card.name:SetText(taker)
                card.craftGiver:SetText(giver)
                local gw = Width(card.craftGiver) + 2
                if gw + arrow + Width(card.name) + 2 <= room then
                    note.name, note.lead = taker, math.ceil(gw + arrow)
                    return true, gw
                end
            end
        end
        return false, 0
    end

    -- The hand line for `form` in lines no wider than `room`, at most
    -- CARD.lines; the lines and the widest, or nil.
    local function HandLine(form, room)
        local rec = card.craftRec
        local words = CrafterDetection.WORDS.hand[form][CrafterDetection.Way(rec)]
        if form == "L" then words = ns.Fmt(words, CrafterDetection.First(rec) or "") end
        local lines, line = {}, ""
        for word in words:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            measure:SetText(try)
            if line ~= "" and Width(measure) + 2 > room then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        local widest = 0
        for _, words in ipairs(lines) do
            measure:SetText(words)
            widest = math.max(widest, Width(measure) + 2)
        end
        if #lines > CARD.lines or widest > room then return nil end
        return lines, widest
    end

    -- Laid as a strip: the size the column takes (L, or M where it is
    -- narrower or the card gave up to M), the hand-off on the name's line,
    -- the box and the hand line in the room under it.
    function hooks.plan(self, note, width)
        local plan = { form = (width >= CARD.L and not self.craftSmall) and "L" or "M" }
        self.craftForm = plan.form
        self.craftPlan = plan
        note.under, note.lead, note.what = nil, nil, nil
        local room = width - pad[1] - pad[3]
        local fits, gw = false, 0
        if width >= CARD.M then fits, gw = Heading(room, note) end
        plan.gw = gw
        if fits then
            plan.chip = box:Measure(self.craftName, room, { icon = self.craftIcon ~= nil, column = width,
                seed = self.craftSeed, lean = CARD.lean })
            plan.lines, plan.handW = HandLine(plan.form, room)
            -- (L's words a line too long: M's, which say "them")
            if not plan.lines and plan.form == "L" then
                plan.form = "M"
                self.craftForm = "M"
                plan.lines, plan.handW = HandLine("M", room)
            end
        end
        local ok = fits and plan.chip ~= nil and plan.chip.bw <= room and plan.lines ~= nil
        self.overfull = not ok
        if ok then
            note.under = { w = math.max(plan.chip.bw, plan.handW), h = plan.chip.bh + CARD.after + #plan.lines * CARD.line,
                gap = CARD.under, after = 0 }
        end
        return plan
    end

    -- A stroke of the pen from a to b on the slip (from its middle, y
    -- down), `w` px: its corners turned with the slip, or laid flat along
    -- its middle where they cannot be.
    local function Pen(texture, ax, ay, bx, by, w)
        local dx, dy = bx - ax, by - ay
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.01 then
            texture:Hide()
            return
        end
        local nx, ny = -dy / length * w / 2, dx / length * w / 2
        local S = Style.INK_STRONG
        texture:SetColorTexture(S[1], S[2], S[3], 0.92)
        if not card:Bend(texture, ax + nx, ay + ny, bx + nx, by + ny, bx - nx, by - ny, ax - nx, ay - ny) then
            card:Lay(texture, (ax + bx) / 2, (ay + by) / 2, length + 0.3, w, math.atan2(-dy, dx))
        end
        texture:Show()
    end

    function hooks.draw(self, plan)
        local lead, under = self.lead, self.under
        local shown = not self.overfull and lead ~= nil and under ~= nil and plan.chip ~= nil
        self.craftGiver:SetShown(shown)
        for _, t in ipairs(self.craftArrow) do t:SetShown(shown) end
        if not shown then
            box:Hide()
            for _, line in ipairs(self.craftHand) do line:Hide() end
            return
        end
        local S, INK = Style.INK_STRONG, Style.INK
        local lift = math.abs(math.sin(self.turn or 0))

        -- The giver at the start of the name's line, then the arrow.
        local left, gw = lead.lx - lead.w / 2, plan.gw
        self.craftGiver:SetTextColor(S[1], S[2], S[3])
        self:Lay(self.craftGiver, left + gw / 2, lead.ly, gw, lead.h + gw * lift + 4)
        local A = CARD.arrow
        local x0, y = left + gw + A.gap, lead.ly + A.drop
        local x1 = x0 + A.length
        local mid = (x0 + x1) / 2
        -- (two strokes, a little bowed, as a pen draws it in one)
        Pen(self.craftArrow[1], x0, y, mid, y - A.bow, A.width)
        Pen(self.craftArrow[2], mid, y - A.bow, x1, y, A.width)
        -- (its head: two strokes back from the tip)
        for k, side in ipairs({ -1, 1 }) do
            local a = math.pi + side * A.spread
            Pen(self.craftArrow[2 + k], x1, y, x1 + math.cos(a) * A.head, y - math.sin(a) * A.head, A.width)
        end

        -- The box at the top of the room under the name, the hand line
        -- under it.
        local chip = plan.chip
        local top, x = under.ly - under.h / 2, under.lx - under.w / 2
        box:Draw(chip, x + chip.bw / 2, top + chip.bh / 2, { quality = self.craftQuality, icon = self.craftIcon })
        local y0 = top + chip.bh + CARD.after
        for i, words in ipairs(plan.lines) do
            local line = self.craftHand[i]
            if not line then
                line = Style.Text(self, Style.FONT.noteWritten)
                line:SetFont(HAND, CARD.size, "")
                self.craftHand[i] = line
            end
            line:SetText(words)
            line:SetTextColor(INK[1], INK[2], INK[3])
            local lw = Width(line) + 2
            self:Lay(line, x + lw / 2, y0 + (i - 0.5) * CARD.line, lw, CARD.line + lw * lift + 4)
            line:Show()
        end
        for i = #plan.lines + 1, #self.craftHand do self.craftHand[i]:Hide() end
    end

    -- On a crowded plate an L card gives up to M once (its words "them"),
    -- before the margin leaves it off.
    function hooks.smaller(self)
        if self.craftForm ~= "L" or self.craftSmall then return false end
        self.craftSmall = true
        return true
    end

    -- What the pad stands on: both names red (the giver is not the
    -- strip's name), the slip outlined as every card's is.
    function hooks.focus(self, f)
        f.words = both
        return f
    end

    -- For the tests: the hand-off and the hand line as written.
    function card:Handoff()
        return (self.craftGiver:GetText() or "") .. " > " .. (self.name:GetText() or "")
    end
    function card:HandLine()
        local parts = {}
        for _, line in ipairs(self.craftHand) do
            if line:IsShown() then parts[#parts + 1] = line:GetText() end
        end
        return table.concat(parts, " ")
    end

    box:Hot(false)
    return card
end

--------------------------------------------------------------------------
-- In the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- A card each connection, after the close call's (50) and before good
-- luck's (60): the proposal's order, so a crowded plate leaves off the
-- campfire, a piece, a duel, the people only seen, the hunt and the lucky
-- card first, then these (the latest first), and the close call and the
-- killer last. Taken as shown until one is left off. Where none is shown
-- on a plate opened for a connection (its rank the crafted moment's), the
-- caption's tail names the earliest that could have had one
-- (said.crafted.lead, Text.lua's caption words); otherwise the words say
-- nothing of them, and no count: the needles tell it.
ns.UI.JourneyMargin.Register("crafted", {
    order = 55, pool = "craftedPool", count = "craftedWritten",
    new = function(parent) return CraftCard.New(parent) end,
    items = function(plate) return CraftCard.Items(plate) end,
    write = function(card, it, c)
        card:SetMeet(it, c.Seed("crafted", it.meet.t or 0, it.meet.id or 0), c.now)
    end,
    mark = function(it) return it.mark end,
    assume = function(said) said.crafted = {} end,
    say = function(said, shown, plate)
        said.crafted = { shown = #shown }
        if #shown > 0 then return end
        local rank = ns.JourneyRecap.RANK.crafted
        if not (plate.plan and plate.plan.rank == rank) then return end
        local first = CraftCard.Items(plate)[1]
        said.crafted.lead = first and first.meet or nil
    end,
})
