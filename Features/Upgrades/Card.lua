-- Upgrades' notes in the plates' margin (Your Diary), as signed on 15 Nov
-- 2026 (.claude/ui-proposal/upgrades.md): the card of the entry's leading
-- upgrade, and the small note of the other pieces. Both are paper strips
-- (UI/Paper/Strip.lua) taped in the margin with a pencil leader to their
-- tunic (Mark.lua).
--
-- The card ("Replaced -> New item. no ilvl", the user): its heading in the
-- diary's hand says how the item came (Upgrades.Heading: "Looted", "From
-- Brannoc"; a gift always names its giver), and under it the new item
-- boxed as the game shows it, the paper's own box (ns.UI.ItemBox,
-- UI/Paper/ItemBox.lua, the first found card's): its quality's wash, its
-- icon edged in its quality's colour, its name in its quality's ink. What
-- it took the place of (always something: an upgrade is only measured
-- against the last item of its own kind worn in that slot, 16 Nov) is
-- shown one of two ways, by the column's width:
--   two  (a column of CARD.wide px and more)
--        the old item on a tag of its own, taped over the card's lower
--        right corner and reaching past it: its icon and its name printed
--        small in faded ink, struck by the hand. The card is CARD.over px
--        narrower than its column so the tag reaches past its edge.
--   one  (narrower) inside the one box, before the new icon: the old
--        icon struck with a stroke of the pen and a pen's arrow (the
--        box's `lead`).
-- A record with no old item can only be left from the feature's first
-- dev data; it gets the one box alone, with nothing before its icon, so
-- it never errors, and no look of its own.
-- The old item never has its quality's colour: no wash, no coloured edge,
-- no coloured name ("no rarity color for the old one", the user). No item
-- level is shown anywhere.
--
-- The family's rule: printed type is what the game says (the items'
-- names), the hand what happened (how it came, the strike, the arrow).
--
-- The small note (S): the piece's icon and one line in the hand naming
-- its slot ("new gloves", Upgrades.Slot); two pieces or more on a plate
-- are counted on one note with no icon ("two new pieces",
-- Upgrades.Pieces). Filler: the first but the campfire left off.
--
-- "A first found wins" (the user, 15 Nov): where the same item's first
-- found is on the plate, its card is the one shown and the upgrade gets
-- no card (nor a piece its place on the small note); its tunic stays.
-- That is read off the plate, never off the firsts' feature: the plate's
-- kept pouches (plate.findMarks, each { list = its moments }) and each
-- moment's record's `link` (m.find.link, or m.link), compared by
-- Upgrades.Key. One way, at laying time, and the only thing here that
-- looks at another feature's data. (Text.lua's caption words leave it out
-- the same way, off the caption's own list of the plate's finds.)
--
-- The strike through the old item's name on the tag is the lucky card's
-- pen (ns.Hunts.LuckyCard.Strike, .Pen and .STRIKE, read when drawn: the
-- hand's one strike, as the witness card borrows it); without it, a
-- straight stroke.
--
-- Under the mouse: the new item's own tooltip with how and when it came
-- under it (Upgrades.TipLine), the old item's with Upgrades.WasLine; the
-- slip itself tells the mark's
-- (Upgrades.Tip, Upgrades.Tips). Items are never clicked.
--
-- The controller finds both as it finds every strip (strip:Focus). The
-- card with its tag is more than its slip, so its `focus` hook gives the
-- pad the corners round both, and `nearest` lets a leader leave from the
-- tag where that is nearer. No pad code besides.
--
-- Laid flat ("Flat paper only") everything lies square, the box as its own
-- header says, the tag without its tilt.

local addonName, ns = ...

local Style = ns.Style

local Upgrades = ns.Upgrades
local UpgradeCard = {}
Upgrades.Card = UpgradeCard

-- The card: turned at most `turn` degrees (the other cards'); its heading
-- at the hand's own size (FONT.noteWritten), else `small`, the full words
-- before the short; `gap` px under it to the box, `after` under the box.
-- The box leans as the first found card's does (`lean`, degrees, seeded).
-- `wide`: the least column for the tag's arrangement (the L band, 150 px:
-- under it the old item goes into the box). There the card is `over` px
-- narrower than its column, keeps `foot` px of paper under its box for the
-- tag to lie on, and the tag starts `land` px above the card's foot, never
-- nearer than `show` px to the card's left.
local CARD = { turn = 1.2, small = 14, gap = 5, after = 3, lean = { least = 1.4, most = 2.6 },
    wide = 150, over = 12, foot = 9, land = 12, show = 16 }
-- The tag: its margins (left, top, right, bottom; the left clear of its
-- tape), the old item's icon `icon` px (edged 1 px in ink, at `alpha`:
-- dimmed), `gap` px to its name, printed in FONT.small (Friz 11, faded
-- ink), `lineH` px a line, `lines` at most. Its paper a little lighter
-- than the card's, turned against it (`turn`, degrees), its shadows, and
-- its tape across its left edge (`tape`: w, h, how far down, its slant),
-- the lucky card's tag's numbers: the family's second slip.
local TAG = { pad = { 10, 4, 7, 4 }, icon = 16, alpha = 0.55, gap = 4, lineH = 13, lines = 2,
    paper = { 0.97, 0.935, 0.84 }, turn = { 1.8, 3.0 }, shadow = { 0.6, 0.8, 0.40 },
    soft = { out = 0.6, blur = 2.0, alpha = 0.26 }, tape = { w = 22, h = 10, down = 0.36, most = 12, slant = 84 },
    stroke = 1.2 }
-- The small note: the hand at `size` px, the most it turns, its icon
-- `icon` px (edged 1 px in its quality's colour), `gap` px to the words,
-- and its tape over its corner (the duel's and the campfire's slips').
local PIECE = { size = 14, turn = 1.4, icon = 16, gap = 4, line = 17,
    tape = { x = 1, y = 1, w = 22, h = 10, slant = { 39, 51 } } }
-- A tooltip's line of how and when, in the game's flavour gold.
local TIP = { colour = { 1, 0.82, 0 } }
UpgradeCard.CARD, UpgradeCard.TAG, UpgradeCard.PIECE = CARD, TAG, PIECE

local HAND = Style.NEUTON_ITALIC
local Surface = ns.UI.Surface
local Seed, Width = Surface.Seed, Surface.Width

--------------------------------------------------------------------------
-- Which, and "a first found wins"
--------------------------------------------------------------------------

-- Whether the item of `rec` has a first found on `plate`: read off the
-- plate's kept pouches (the header says what is read, and why here).
function UpgradeCard.Found(plate, rec)
    for _, pouch in ipairs(plate.findMarks or {}) do
        for _, m in ipairs(pouch.list or {}) do
            local link = (m.find or m).link
            if link and Upgrades.Key(link) == rec.key then return true end
        end
    end
    return false
end

-- The plate's leading upgrade for its card (plate.upgrade, Mark.lua's
-- choice: { m, rec, mark }), or nil: none, or its first found is there.
function UpgradeCard.Lead(plate)
    local u = plate.upgrade
    if not u or UpgradeCard.Found(plate, u.rec) then return nil end
    return u
end

-- The plate's pieces for its small note (plate.pieces, Mark.lua's: every
-- piece and its mark), less those a first found tells: { list, mark (the
-- first one's, where the leader goes) }, or nil.
function UpgradeCard.Pieces(plate)
    local all = plate.pieces
    if not all then return nil end
    local list = {}
    for _, piece in ipairs(all.list) do
        if not UpgradeCard.Found(plate, piece.rec) then list[#list + 1] = piece end
    end
    if #list == 0 then return nil end
    return { list = list, mark = list[1].mark }
end

--------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------

-- An item's own tooltip on `owner` (its link; its name alone where the
-- client will not show the link), and `line` under it in flavour gold.
function UpgradeCard.ShowItem(owner, link, name, line)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = type(GameTooltip.SetHyperlink) == "function" and link
        and pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if not shown then GameTooltip:SetText(name or "?") end
    local C = TIP.colour
    if line then GameTooltip:AddLine(line, C[1], C[2], C[3], true) end
    GameTooltip:Show()
end

-- What the item took the place of, on `owner`: the old item's tooltip.
-- Only shown where there is an old item (the tag, or the box's lead).
local function ShowWas(owner, rec, now)
    if not rec.was then return end
    UpgradeCard.ShowItem(owner, rec.was.link, Upgrades.WasName(rec), Upgrades.WasLine(rec, now))
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

-- A piece of the pen laid flat where corners cannot move: from the middle
-- of its start to the middle of its end (the lucky card's).
local function Flat(q)
    local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
    local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
    local dx, dy = ex - sx, ey - sy
    local width = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
        + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
    return (sx + ex) / 2, (sy + ey) / 2, math.sqrt(dx * dx + dy * dy) + 0.3, math.max(width, 0.4), math.atan2(-dy, dx)
end

-- A card on `parent` (the right page): card:SetUpgrade(chosen, seed, now)
-- with Lead's choice ({ m, rec, mark }), then card:Layout(x, y, width) as
-- a strip's. card.form says which arrangement it took ("two" or "one"),
-- card.overfull where its heading or its box will not fit `width` (the
-- page leaves it off). Laid through the strip's hooks, `hooks`, below.
function UpgradeCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    local pad = { card:Pad() }

    -- The box, and what the mouse shows on it.
    local box = ns.UI.ItemBox.New(card, parent)
    card.itemBox = box
    function box.enter(button)
        box:Hot(true)
        UpgradeCard.ShowItem(button, card.rec.link, Upgrades.Name(card.rec), Upgrades.TipLine(card.rec, card.now))
    end
    function box.leave()
        box:Hot(false)
        GameTooltip:Hide()
    end
    function box.wasEnter(button) ShowWas(button, card.rec, card.now) end
    function box.wasLeave() GameTooltip:Hide() end

    -- The tag: a blank slip of its own on the card, the old item on it.
    local tag = ns.UI.PaperStrip(card)
    card.tag = tag
    tag.oldEdge = Snapless(tag:CreateTexture(nil, "ARTWORK", nil, 5))
    tag.oldIcon = Snapless(tag:CreateTexture(nil, "ARTWORK", nil, 6))
    tag.words, tag.ink = {}, {}
    tag.item = CreateFrame("Button", nil, tag)
    tag.item:SetScript("OnEnter", function(self) ShowWas(self, card.rec, card.now) end)
    tag.item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tag:Hide()
    local measure = Style.Text(card, Style.FONT.small)
    measure:Hide()

    function card:SetUpgrade(chosen, seed, now)
        local rec = chosen.rec
        self.chosen, self.rec, self.now, self.seedKey = chosen, rec, now, seed
        local ItemBox = ns.UI.ItemBox
        self.quality = rec.quality or ItemBox.Quality(rec.link) or 2
        self.iconFile = ItemBox.Icon(rec.link)
        self.wasIcon = rec.was and ItemBox.Icon(rec.was.link) or nil
        self.itemName = Upgrades.Name(rec) or "?"
        self:SetNote({ name = Upgrades.Heading(rec), strong = true, seed = seed, turn = CARD.turn,
            tip = function()
                local title, line = Upgrades.Tip(chosen.m or rec, now)
                return Style.TipList(title, { line })
            end })
    end

    -- The heading in the hand at `size` (0: FONT.noteWritten's own).
    local function Hand(size)
        card.name:SetFontObject(Style.FONT.noteWritten)
        if size > 0 then card.name:SetFont(HAND, size, "") end
    end

    -- The heading at the first words and size that fit `room` on one line,
    -- the full words before the short; whether any did.
    local function Heading(room, note)
        for _, short in ipairs({ false, true }) do
            local words = Upgrades.Heading(card.rec, short)
            for _, size in ipairs({ 0, CARD.small }) do
                Hand(size)
                card.name:SetText(words)
                if Width(card.name) <= room then
                    note.name = words
                    return true
                end
            end
        end
        return false
    end

    -- The old item's name on the tag: in TAG.lines lines at most, none
    -- wider than `room`; the lines and the widest, or nil.
    local function OldName(room)
        local lines, line = {}, ""
        for word in (Upgrades.WasName(card.rec) or "?"):gmatch("%S+") do
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
        if #lines > TAG.lines then return nil end
        local widest = 0
        for _, words in ipairs(lines) do
            measure:SetText(words)
            widest = math.max(widest, Width(measure) + 2)
        end
        if widest > room then return nil end
        return lines, widest
    end

    -- One arrangement in `width` px: its plan, or nil where it does not go.
    -- "two": the card `over` px narrower, the tag planned (its size; where
    -- it lies is known once the slip is laid). "one": the old item in the
    -- box's lead.
    local function Try(form, width, note)
        local two = form == "two"
        local Wb = two and width - CARD.over or width
        local room = Wb - pad[1] - pad[3]
        local plan = { form = form, Wb = Wb }
        if two then
            local T = TAG
            local lines, widest = OldName(width - CARD.show - T.pad[1] - T.icon - 2 - T.gap - T.pad[3])
            if not lines then return nil end
            plan.tag = { lines = lines, w = math.ceil(T.pad[1] + T.icon + 2 + T.gap + widest + T.pad[3]),
                h = T.pad[2] + math.max(T.icon + 2, #lines * T.lineH) + T.pad[4] }
        end
        plan.fits = Heading(room, note)
        plan.chip = box:Measure(card.itemName, room, { icon = card.iconFile ~= nil, column = Wb,
            seed = card.seedKey, lean = CARD.lean, lead = not two and card.rec.was ~= nil })
        if not (plan.fits and plan.chip and plan.chip.bw <= room) then return nil, plan end
        return plan
    end

    -- Laid as a strip: the tag's arrangement where the column is wide
    -- enough and something was replaced, else the one box; the box's room
    -- under the heading.
    function hooks.plan(self, note, width)
        local plan, tried
        if self.rec.was and width >= CARD.wide then plan = Try("two", width, note) end
        if not plan then plan, tried = Try("one", width, note) end
        self.overfull = plan == nil
        plan = plan or tried
        self.form = plan.form
        note.under = nil
        if plan.chip then
            note.under = { w = plan.chip.bw, h = plan.chip.bh + (plan.tag and CARD.foot or 0), gap = CARD.gap,
                after = CARD.after }
        end
        self.plan = plan
        return plan, plan.Wb
    end

    -- The tag, laid over the card's lower right corner (the card as laid,
    -- W by H), and the old item on it. Returns the two together, w by h.
    local function Tag(plan, W, H)
        local t, T, rec = plan.tag, TAG, card.rec
        local seed = card.seedKey or "upgrade"
        local rand = ns.UI.Pen.Random(Seed(seed .. ":tag"))
        local function U(a, b) return a + (b - a) * rand() end
        local x = math.max(CARD.show, W + CARD.over - t.w)
        local y = H - CARD.land
        local sign = (card.turn or 0) < 0 and 1 or ((card.turn or 0) > 0 and -1 or (U(0, 1) < 0.5 and -1 or 1))
        tag:SetNote({ name = "", strong = true, seed = seed .. ":tag", size = { t.w, t.h }, paper = T.paper,
            tilt = sign * U(T.turn[1], T.turn[2]), shadow = T.shadow, soft = T.soft,
            tapeAt = { x = 0, y = math.min(t.h * T.tape.down, T.tape.most), slant = T.tape.slant, w = T.tape.w,
                h = T.tape.h } })
        tag:SetFrameLevel(card:GetFrameLevel() + 2)
        tag:Layout(x, y, t.w)
        tag:Show()

        -- From the tag's middle: its icon, then its name's lines.
        local INK, FADED = Style.INK, Style.INK_FADED
        local left = -t.w / 2 + T.pad[1]
        local ix = left + T.icon / 2 + 1
        tag.oldEdge:SetColorTexture(INK[1], INK[2], INK[3], T.alpha)
        tag:Lay(tag.oldEdge, ix, 0, T.icon + 2, T.icon + 2)
        tag.oldEdge:Show()
        tag.oldIcon:SetTexture(card.wasIcon)
        local k = ns.UI.ItemBox.ICON.crop
        tag.oldIcon:SetTexCoord(k, 1 - k, k, 1 - k)
        tag.oldIcon:SetAlpha(T.alpha)
        tag:Lay(tag.oldIcon, ix, 0, T.icon, T.icon)
        tag.oldIcon:SetShown(card.wasIcon ~= nil)

        local Lucky = ns.Hunts and ns.Hunts.LuckyCard
        local tx = left + T.icon + 2 + T.gap
        local top = -(#t.lines * T.lineH) / 2
        local prims = {}
        for i, words in ipairs(t.lines) do
            local line = tag.words[i]
            if not line then
                line = Style.Text(tag, Style.FONT.small)
                tag.words[i] = line
            end
            line:SetText(words)
            line:SetTextColor(FADED[1], FADED[2], FADED[3])
            line:SetSize(0, 0)
            local lw = Width(line) + 2
            local mid = top + (i - 0.5) * T.lineH
            tag:Lay(line, tx + lw / 2, mid, lw, T.lineH)
            line:Show()
            -- Struck by the hand.
            if Lucky then
                for _, q in ipairs(Lucky.Pen(Lucky.Strike(seed .. ":s" .. i, tx, mid, lw - 2, 11), Lucky.STRIKE)) do
                    prims[#prims + 1] = q
                end
            else
                local S = Style.INK_STRONG
                prims[#prims + 1] = { x1 = tx - 2, y1 = mid, x2 = tx + lw, y2 = mid, x3 = tx + lw, y3 = mid + T.stroke,
                    x4 = tx - 2, y4 = mid + T.stroke, r = S[1], g = S[2], b = S[3], a = 0.92 }
            end
        end
        for i = #t.lines + 1, #tag.words do tag.words[i]:Hide() end
        for n, q in ipairs(prims) do
            local stroke = tag.ink[n]
            if not stroke then
                stroke = Snapless(tag:CreateTexture(nil, "ARTWORK", nil, 7))
                tag.ink[n] = stroke
            end
            stroke:SetColorTexture(q.r, q.g, q.b, q.a)
            if not tag:Bend(stroke, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local mx, my, length, w, angle = Flat(q)
                tag:Lay(stroke, mx, my, length, w, angle)
            end
            stroke:Show()
        end
        for n = #prims + 1, #tag.ink do tag.ink[n]:Hide() end
        tag.struck = #prims

        -- The mouse over the tag as drawn: one square button round it.
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local px, py = tag:Out(corner[1] * t.w / 2, corner[2] * t.h / 2)
            x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
        end
        tag.item:SetFrameLevel(tag:GetFrameLevel() + 2)
        tag.item:ClearAllPoints()
        tag.item:SetPoint("TOPLEFT", card, "TOPLEFT", x0, -y0)
        tag.item:SetSize(x1 - x0, y1 - y0)
        tag.item:Show()
        -- For the tests and the pad: the tag on the card, from its top left.
        card.tagAt = { x, y, t.w, t.h }
        return math.max(W, x + t.w), math.max(H, y + t.h)
    end

    function hooks.draw(self, plan, W, H)
        local chip, room = plan.chip, self.under
        self.tagAt = nil
        tag:Hide()
        if not (chip and room) then
            box:Hide()
            return
        end
        local top = room.ly - room.h / 2
        local mx, my = room.lx - room.w / 2 + chip.bw / 2, top + chip.bh / 2
        local was
        if not plan.tag and self.rec.was then was = { icon = self.wasIcon } end
        box:Draw(chip, mx, my, { quality = self.quality, icon = self.iconFile, was = was })
        if plan.tag then return Tag(plan, W, H) end
    end

    -- The point of either slip's edge nearest x, y of the page: a leader
    -- leaves the card there, so it never crosses the tag.
    function hooks.nearest(self, x, y, bx, by)
        local at = self.box
        if not (at and self.tagAt and tag.box) then return bx, by end
        local tx, ty = tag:Nearest(x - at[1], y - at[2])
        tx, ty = tx + at[1], ty + at[2]
        if (tx - x) ^ 2 + (ty - y) ^ 2 < (bx - x) ^ 2 + (by - y) ^ 2 then return tx, ty end
        return bx, by
    end

    -- What the pad stands on: with its tag, the corners round both.
    function hooks.focus(self, f)
        local at, t = self.box, self.tagAt
        if not (at and t) then return f end
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        local function Take(px, py)
            x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
        end
        for _, c in ipairs(f.corners) do Take(c[1], c[2]) end
        for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local px, py = tag:Out(corner[1] * t[3] / 2, corner[2] * t[4] / 2)
            Take(px + at[1], py + at[2])
        end
        f.corners = { { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }
        f.x, f.y = (x0 + x1) / 2, (y0 + y1) / 2
        return f
    end

    -- For the tests: the old item's name as printed on the tag.
    function card:Old()
        local parts = {}
        for i, line in ipairs(tag.words) do
            if tag:IsShown() and line:IsShown() then parts[#parts + 1] = line:GetText() end
        end
        return table.concat(parts, " ")
    end

    box:Hot(false)
    return card
end

--------------------------------------------------------------------------
-- The small note
--------------------------------------------------------------------------

-- A small note on `parent`: slip:SetPieces(chosen, seed, now) with Pieces'
-- choice ({ list, mark }), then slip:Layout(x, y, width) as a strip's. One
-- piece: its icon and its slot's phrase; more: how many, no icon.
-- `overfull` where the words will not go in `width` (it does not wrap).
function UpgradeCard.NewPiece(parent)
    local hooks = {}
    local slip = ns.UI.PaperStrip(parent, hooks)
    local pad = { slip:Pad() }
    slip.name:SetFont(HAND, PIECE.size, "")
    -- The piece's icon: the paper's small icon (ns.UI.ItemBox.NewSmall,
    -- moved there from here on 19 Nov for the free card's narrow sizes).
    local small = ns.UI.ItemBox.NewSmall(slip, parent)
    slip.small = small
    slip.iconEdge, slip.icon, slip.item = small.edge, small.icon, small.button
    function small.enter(button)
        local rec = slip.rec
        if rec then UpgradeCard.ShowItem(button, rec.link, Upgrades.Name(rec), Upgrades.TipLine(rec, slip.now)) end
    end
    function small.leave() GameTooltip:Hide() end

    local function Words()
        local list = slip.pieces.list
        return #list == 1 and Upgrades.Slot(list[1].rec) or Upgrades.Pieces(#list)
    end

    function slip:SetPieces(chosen, seed, now)
        self.pieces, self.now = chosen, now
        local list = chosen.list
        self.rec = #list == 1 and list[1].rec or nil
        self.iconFile = self.rec and ns.UI.ItemBox.Icon(self.rec.link) or nil
        local rand = ns.UI.Pen.Random(Seed(seed .. ":tape"))
        local T = PIECE.tape
        self:SetNote({ name = Words(), strong = true, seed = seed, turn = PIECE.turn,
            tip = function()
                local moments = {}
                for _, piece in ipairs(list) do moments[#moments + 1] = piece.m or piece.rec end
                local title, lines = Upgrades.Tips(moments, now)
                return Style.TipList(title, lines)
            end,
            tapeAt = { x = T.x, y = T.y, w = T.w, h = T.h, slant = T.slant[1] + (T.slant[2] - T.slant[1]) * rand() } })
    end

    function hooks.plan(self, note, width)
        local words = Words()
        self.name:SetText(words)
        note.name = words
        local nameW = Width(self.name) + 2
        local lead = self.iconFile and PIECE.icon + 2 + PIECE.gap or 0
        note.under = lead > 0 and { w = lead + nameW, h = 0, gap = 0, after = 0 } or nil
        self.overfull = pad[1] + lead + nameW + pad[3] > width
        return { lead = lead, nameW = nameW }
    end

    -- The icon at the left, and the words (the strip laid them at the
    -- left) moved past it.
    function hooks.draw(self, plan, W, H)
        if plan.lead <= 0 then
            small:Hide()
            return
        end
        local left, mid = -W / 2 + pad[1], -H / 2 + pad[2] + PIECE.line / 2
        local ix = left + PIECE.icon / 2 + 1
        small:Draw(ix, mid, PIECE.icon, self.rec.quality, self.iconFile)
        self:Lay(self.name, left + plan.lead + plan.nameW / 2, mid, plan.nameW,
            PIECE.line + plan.nameW * math.abs(math.sin(self.turn or 0)) + 4)
    end

    -- The words as written (for the tests).
    function slip:Words() return self.name:GetText() end

    return slip
end

--------------------------------------------------------------------------
-- In the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- The leading upgrade's card, straight after a first found's (20) and
-- before someone there when you died (30) and the killer (40): the user's
-- ruling of 15 Nov ("Yes, it should be top prio"), an upgrade ranking
-- with a first found. Taken as shown until it is left off: the caption
-- then names the item (`said.upgrade`, the records whose card is beside
-- the plate; Text.lua's caption words). None where a first found of the
-- same item is on the plate (Lead).
ns.UI.JourneyMargin.Register("upgrade", {
    order = 22, pool = "upgradePool", count = "upgradesWritten",
    new = function(parent) return UpgradeCard.New(parent) end,
    item = function(plate)
        local u = UpgradeCard.Lead(plate)
        return u and { upgrade = u, top = u.mark[2], x = u.mark[1] } or nil
    end,
    write = function(card, it, c)
        card:SetUpgrade(it.upgrade, c.Seed("upgrade", it.upgrade.rec.t or 0), c.now)
    end,
    mark = function(it) return it.upgrade.mark end,
    assume = function(said, plate, slot, plan)
        local all = {}
        for _, m in ipairs(plan.moments or {}) do
            if m.kind == "upgrade" then all[m.upgrade or m] = true end
        end
        said.upgrade = all
    end,
    say = function(said, shown)
        local told = {}
        for _, it in ipairs(shown) do told[it.upgrade.rec] = true end
        said.upgrade = told
    end,
})

-- The other pieces' small note: one a plate, filler (the user: "let others
-- fill an existing open plate low prio"), after the duel's note (85) and
-- before the campfire's (90), so it is the second left off. The caption
-- counts them then (`said.piece`), unless that would cost the caption its
-- place or run it past its foot (plate.pieceTold false: the tunics alone
-- tell them).
ns.UI.JourneyMargin.Register("piece", {
    order = 87, pool = "piecePool", count = "piecesWritten", filler = true, flag = "pieceTold",
    new = function(parent) return UpgradeCard.NewPiece(parent) end,
    item = function(plate)
        local p = UpgradeCard.Pieces(plate)
        return p and { pieces = p, top = p.mark[2], x = p.mark[1] } or nil
    end,
    write = function(slip, it, c)
        slip:SetPieces(it.pieces, c.Seed("piece", it.pieces.list[1].rec.t or 0), c.now)
    end,
    mark = function(it) return it.pieces.mark end,
    say = function(said, shown, plate)
        if UpgradeCard.Pieces(plate) and not shown[1] then said.piece = true end
    end,
})
