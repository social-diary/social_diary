-- The tame card (Your Diary's plates): a pet the hunter tamed, as card A,
-- "Snapshot", of .claude/ui-proposal/hunter-tames.md (signed 4 Nov). A
-- paper strip (UI/Paper/Strip.lua) taped in the plate's margin with a
-- pencil leader to its paw (Mark.lua), and on it:
--
--   the picture  the beast's own portrait pasted in at the slip's top left,
--                the killer card's print (Features/Deaths/Card.lua's second
--                rung: SetPortraitTextureFromCreatureDisplayID, desaturated,
--                warmed, an ink edge, kraft photo corners), never its ink
--                silhouette, which is how the diary shows what killed you.
--                Only where the tame has a `display` (filled by
--                ns.Deaths.LookUp from its npcID a moment after the tame,
--                Capture.lua) and the client can draw a portrait; else
--                none, and the writing moves left into its place
--   the name     beside it, in the diary's hand: the name the hunter gave
--                the pet, else the beast's own (Hunter.Hand)
--   the kind     under the name, printed (small Friz in ink): what the game
--                calls it, "Boar · Dire Mottled Boar" under a given name,
--                the family alone under the beast's (Hunter.Kind)
--   the level    the pet's, on a small printed label pasted under them,
--                the close call's tag (Features/CloseCalls/Card.lua's
--                VITALS.tag, read at call time): "Lv 9" (Hunter.Level)
--
-- The family's rule: the hand is what happened (you tamed it, and named
-- it), printed type what the game says. Neither the hunter's level nor
-- the tames merged (`n`) shows anywhere (the user's sign-off, 4 Nov).
--
-- Its size is not picked by name: card:Layout(x, y, width) tries FORMS in
-- turn and keeps the first that fits the width (XL, L, M: the picture
-- smaller each step). Narrower than M holds, it is left off, and the mark
-- alone tells the tame: there are no caption words for it (the scope).
--
-- Which and where (its margin notes, at the foot of this file): one card a
-- plate, the newest tame on it (Choose); after the people who did
-- something with you (10) and before everything else, firsts found (20)
-- first, so it is the last card but theirs left off (order 15, the user's,
-- 4 Nov). A tame the player changed or wrote is a card of its own
-- (Customs), earlier still (2.5), as every kind's custom card is.
--
-- Laid flat ("Flat paper only") the slip and its label lie square, the
-- label throws no shadow; the portrait and its corners are paper and
-- stay. Where text cannot turn, the slip lies straight.

local addonName, ns = ...

local Style = ns.Style

local Hunter = ns.Hunter
local TameCard = {}
Hunter.Card = TameCard

-- The slip: turned at most `turn` degrees (the other cards'). The name at
-- the hand's own size (FONT.noteWritten), else `small`, else on two lines
-- at `small`; `gap` px under it to the kind's lines, each `lineH` px
-- (Friz 11's line); `row` px under them to the level's label.
local TAME = { turn = 1.2, small = 14, gap = 1, lineH = 13, row = 2 }
-- The arrangements, tried in turn: the least column each takes (`least`:
-- XL only where a row or a caption column is 190 px and more, L the 150 to
-- 189 px columns, M the 122 px column and the 142 px boxes of a row), and
-- the portrait's size there, `w` by `h` (the signed mockup's).
local FORMS = {
    XL = { least = 190, picture = { w = 54, h = 44 } },
    L = { least = 150, picture = { w = 44, h = 36 } },
    M = { least = 0, picture = { w = 36, h = 30 } },
}
local ORDER = { "XL", "L", "M" }
-- The portrait: `down` px below the slip's top margin (its corners clear
-- of the tape), the writing `gap` px to its right.
local PICTURE = { down = 3, gap = 7 }
-- Turned writing is drawn in a box tall enough for its turn: a line w px
-- long turned t lifts its ends w * sin t, and `room` px more (the strip's
-- own rule for its lines, UI/Paper/Strip.lua's TURNED).
local TURNED = { room = 4 }

local HAND = Style.NEUTON_ITALIC

--------------------------------------------------------------------------
-- Which tame
--------------------------------------------------------------------------

-- A tame's display, where it has one to draw.
local function Display(tame)
    local display = ns.Plain(tame.display)
    return type(display) == "number" and display > 0 and display or nil
end

-- The plate's one tame for its card, from its paws (plate.tameMarks:
-- { at (on the page), list of moments }): the newest, a tie to the later
-- paw. { rec, mark } or nil. A tame the player changed or wrote is not
-- among them: it has a card of its own (Customs).
function TameCard.Choose(marks)
    local best
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local rec = m.tame
            if rec and not rec.customOf and (not best or (rec.t or 0) >= (best.rec.t or 0)) then
                best = { rec = rec, mark = mark.at }
            end
        end
    end
    return best
end

-- The tames on a plate the player changed or wrote (Core/Custom.lua), a
-- card each, the newest first, so where the margin runs out the oldest are
-- the ones left to their paws. One saying neither name nor beast has no
-- card: a slip with nothing in the hand would say less than its paw does.
function TameCard.Customs(marks)
    local list = {}
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local rec = m.tame
            if rec and rec.customOf and Hunter.Hand(rec) then list[#list + 1] = { rec = rec, mark = mark.at } end
        end
    end
    table.sort(list, function(a, b) return (a.rec.t or 0) > (b.rec.t or 0) end)
    return list
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

local Width = ns.UI.Surface.Width

-- Whether the client can draw the print.
local function Prints()
    return type(SetPortraitTextureFromCreatureDisplayID) == "function"
end

-- A card on `parent` (the right page): a paper strip. card:SetTame(tame,
-- seed, now), then card:Layout(x, y, width) as a strip's; card.form says
-- which arrangement it took, card.picture whether the portrait shows;
-- card.overfull where not even M fits `width` (the page leaves it off).
-- Laid through the strip's hooks (UI/Paper/Strip.lua), `hooks`, filled in
-- below.
function TameCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    local pad = { card:Pad() }

    local function Texture(sublevel)
        local texture = card:CreateTexture(nil, "ARTWORK", nil, sublevel)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        texture:Hide()
        return texture
    end
    -- The portrait's window: its ink edge, the portrait, its photo
    -- corners (the killer card's print). The label: its shadow, edge,
    -- paper and words.
    card.printEdge, card.print = Texture(2), Texture(3)
    card.corners = {}
    for i = 1, 4 do card.corners[i] = Texture(4) end
    card.tagShadow, card.tagEdge, card.tagPaper = Texture(1), Texture(2), Texture(3)
    card.tagText = Style.Text(card, Style.FONT.small)
    card.tagText:Hide()
    -- The name's second line, where it takes two; the kind's lines.
    card.headTail = Style.Text(card, Style.FONT.noteWritten)
    card.headTail:Hide()
    card.kinds = {}
    local measure = Style.Text(card, Style.FONT.small)
    measure:Hide()

    function card:SetTame(tame, seed, now)
        self.tame, self.now = tame, now
        local lines = Hunter.Tip(tame, now)
        self:SetNote({ name = Hunter.Hand(tame) or "", strong = true, seed = seed, turn = TAME.turn,
            tip = function() return Style.TipList(lines[1], { unpack(lines, 2) }) end })
    end

    -- The hand at `size` (0: FONT.noteWritten's own) on `text`.
    local function Hand(text, size)
        text:SetFontObject(Style.FONT.noteWritten)
        if size > 0 then text:SetFont(HAND, size, "") end
    end
    local function Height(text, least)
        return math.max(math.ceil(text:GetStringHeight() or 0), least)
    end

    -- The name in `room`: on one line at the hand's size, else the smaller;
    -- else on two lines at the smaller. { size, first, rest, w, h } (h both
    -- lines'), or nil where none holds it.
    local function Heading(words, room)
        for _, size in ipairs({ 0, TAME.small }) do
            Hand(card.name, size)
            card.name:SetText(words)
            local w = Width(card.name) + 2
            if w <= room then return { size = size, first = words, w = w, h = Height(card.name, 14) } end
        end
        Hand(card.name, TAME.small)
        Hand(card.headTail, TAME.small)
        local first, rest = "", nil
        for word in words:gmatch("%S+") do
            if rest then
                rest = rest .. " " .. word
            else
                local try = first == "" and word or (first .. " " .. word)
                card.name:SetText(try)
                if first ~= "" and Width(card.name) + 2 > room then rest = word else first = try end
            end
        end
        if not rest then return nil end
        card.name:SetText(first)
        card.headTail:SetText(rest)
        local w = math.max(Width(card.name), Width(card.headTail)) + 2
        if w > room then return nil end
        local h = Height(card.name, 14)
        return { size = TAME.small, first = first, rest = rest, w = w, h = h, tailH = Height(card.headTail, 14) }
    end

    -- `text` in lines no wider than `room`, nil where a word alone is wider.
    local function Wrap(text, room, most)
        local lines, line = {}, ""
        for word in text:gmatch("%S+") do
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
        if #lines > most then return nil end
        for _, l in ipairs(lines) do
            measure:SetText(l)
            if Width(measure) + 2 > room then return nil end
        end
        return lines
    end

    -- The kind's lines in `room`: "Boar · Dire Mottled Boar" on one line;
    -- where it will not go, the family and the beast each on their own (the
    -- beast on two at most). Nil where they will not hold.
    local function Kind(room)
        local tame = card.tame
        local words = Hunter.Kind(tame)
        if not words then return {} end
        local one = Wrap(words, room, 1)
        if one then return one end
        if not (tame.name and tame.family and tame.beast) then return Wrap(words, room, 2) end
        local family = Wrap(tame.family, room, 1)
        local beast = Wrap(tame.beast, room, 2)
        if not (family and beast) then return nil end
        table.insert(beast, 1, family[1])
        return beast
    end

    -- The label's words and size, or nil without a level.
    local function Tag()
        local words = Hunter.Level(card.tame)
        if not words then return nil end
        local G = ns.CloseCalls.Card.VITALS.tag
        card.tagText:SetText(words)
        return words, Width(card.tagText) + 2 * G.pad[1] + 1, Height(card.tagText, 10) + 2 * G.pad[2]
    end

    -- One arrangement (FORMS[form]) in `width` px: its plan, or nil where it
    -- does not fit (`force`: planned all the same, for the page to measure
    -- and leave off).
    local function Try(form, width, force)
        local F = FORMS[form]
        local fail = width < F.least
        local pic = card.display and Prints() and F.picture or nil
        local inside = width - pad[1] - pad[3]
        local room = inside - (pic and pic.w + PICTURE.gap or 0)
        local head = Heading(Hunter.Hand(card.tame) or "", room)
        if not head then
            fail = true
            head = { size = TAME.small, first = Hunter.Hand(card.tame) or "", w = room, h = 14 }
        end
        local kinds = Kind(room)
        if not kinds then
            fail = true
            kinds = { Hunter.Kind(card.tame) }
        end
        local widest = head.w
        for _, line in ipairs(kinds) do
            measure:SetText(line)
            widest = math.max(widest, Width(measure) + 2)
        end
        local tag, tw, th = Tag()
        if tag then
            widest = math.max(widest, tw)
            if tw > room then fail = true end
        end
        if fail and not force then return nil end
        -- From the top of the writing: the name (and its second line), the
        -- kind's lines, the label.
        local kindTop = head.h + (head.tailH or 0) + TAME.gap
        local tagTop = kindTop + #kinds * TAME.lineH + TAME.row
        local textH = tag and (tagTop + th) or (kindTop + #kinds * TAME.lineH)
        local h = math.max(textH, pic and PICTURE.down + pic.h or 0)
        local left = pic and pic.w + PICTURE.gap or 0
        return { form = form, pic = pic, head = head, kinds = kinds, tag = tag, tw = tw, th = th, kindTop = kindTop,
            tagTop = tagTop, left = left, w = math.ceil(left + widest), h = math.ceil(h) }
    end

    -- Laid as a strip, the first arrangement that fits `width` (FORMS, in
    -- ORDER). The strip lays the name at its top left and keeps the room
    -- under it (note.under) as tall as the rest needs, as wide as the
    -- portrait and the writing beside it; draw then moves the name beside
    -- the portrait, where there is one.
    function hooks.plan(self, note, width)
        self.display = Display(self.tame or {})
        local plan
        for _, form in ipairs(ORDER) do
            plan = Try(form, width)
            if plan then break end
        end
        self.overfull = plan == nil
        plan = plan or Try(ORDER[#ORDER], width, true)
        Hand(self.name, plan.head.size)
        self.name:SetText(plan.head.first)
        note.name, note.what, note.least = plan.head.first, nil, nil
        note.under = { w = plan.w, h = math.max(0, plan.h - plan.head.h), gap = 0, after = 0 }
        self.form = plan.form
        return plan
    end

    -- A line of writing `w` by `h`, its left at lx and its middle at ly
    -- (from the slip's middle, y down), in a box tall enough for its turn.
    local function Write(text, lx, ly, w, h)
        card:Lay(text, lx + w / 2, ly, w, h + w * math.abs(math.sin(card.turn or 0)) + TURNED.room)
        text:Show()
    end

    -- The portrait in its window (the killer card's print, KILLER.print's
    -- look): a square portrait shown through the window's shape, its full
    -- width and a band of its height a little above the middle (the head).
    -- False where it would not draw.
    local function Portrait(pic, lx, ly)
        local texture = card.print
        if not (Prints() and pcall(SetPortraitTextureFromCreatureDisplayID, texture, card.display)) then return false end
        local P, INK = ns.Deaths.Card.KILLER.print, Style.INK
        texture:SetDesaturated(true)
        texture:SetVertexColor(P.tint[1], P.tint[2], P.tint[3], 1)
        local share = math.min(1, pic.h / pic.w)
        local v0 = math.max(0, 0.45 - share / 2)
        texture:SetTexCoord(0, 1, v0, v0 + share)
        card:Lay(texture, lx, ly, pic.w, pic.h)
        card.printEdge:SetColorTexture(INK[1], INK[2], INK[3], P.edge)
        card:Lay(card.printEdge, lx, ly, pic.w + 2, pic.h + 2)
        texture:Show()
        card.printEdge:Show()
        -- Its photo corners: a small pocket over each, a triangle where
        -- corners can move, none where they cannot.
        local c, x0, y0 = P.corner, lx - pic.w / 2 - 1, ly - pic.h / 2 - 1
        local x1, y1 = x0 + pic.w + 2, y0 + pic.h + 2
        local tri = {
            { x0, y0, x0 + c, y0, x0, y0 + c, x0, y0 + c },
            { x1 - c, y0, x1, y0, x1, y0 + c, x1, y0 + c },
            { x1, y1 - c, x1, y1 - c, x1, y1, x1 - c, y1 },
            { x0, y1 - c, x0, y1 - c, x0 + c, y1, x0, y1 },
        }
        for i, corner in ipairs(card.corners) do
            corner:SetColorTexture(P.ink[1], P.ink[2], P.ink[3], P.alpha)
            corner:SetShown(card:Bend(corner, unpack(tri[i])) == true)
        end
        return true
    end

    -- The label, pasted at the writing's left under the kind, as the close
    -- call's is (VITALS.tag: its paper, edge, shadow, turned by its words).
    local function Label(plan, left, top)
        local G, INK, S = ns.CloseCalls.Card.VITALS.tag, Style.INK, Style.INK_STRONG
        local tw, th = plan.tw, plan.th
        local tx, ty = left + tw / 2, top + th / 2
        local seed = 0
        for i = 1, #plan.tag do seed = seed + plan.tag:byte(i) * i end
        local more = card.flat and 0 or math.rad(G.turn[1] + (G.turn[2] - G.turn[1]) * Style.Noise(seed))
        local D = G.shadow
        card.tagShadow:SetColorTexture(INK[1], INK[2], INK[3], D[3])
        card:Lay(card.tagShadow, tx + D[1], ty + D[2], tw, th, more)
        card.tagShadow:SetShown(not card.flat)
        card.tagEdge:SetColorTexture(INK[1], INK[2], INK[3], G.edge)
        card:Lay(card.tagEdge, tx, ty, tw + 1, th + 1, more)
        card.tagPaper:SetColorTexture(G.paper[1], G.paper[2], G.paper[3], 1)
        card:Lay(card.tagPaper, tx, ty, tw - 1, th - 1, more)
        card.tagText:SetTextColor(S[1], S[2], S[3])
        card:Lay(card.tagText, tx, ty, tw - 2 * G.pad[1], th - 2 * G.pad[2], more)
        card.tagEdge:Show()
        card.tagPaper:Show()
        card.tagText:Show()
        -- For the tests: the label's box on the slip, from its middle.
        card.tag = { text = plan.tag, box = { tx - tw / 2, ty - th / 2, tx + tw / 2, ty + th / 2 } }
    end

    function hooks.draw(self, plan, W, H)
        for _, part in ipairs({ self.print, self.printEdge, self.tagShadow, self.tagEdge, self.tagPaper,
            self.tagText, self.headTail, unpack(self.corners) }) do
            part:Hide()
        end
        for _, line in ipairs(self.kinds) do line:Hide() end
        self.tag, self.picture = nil, nil
        local left, top = -W / 2 + pad[1], -H / 2 + pad[2]
        -- The portrait at the top left; where it will not draw, the writing
        -- keeps the left (the room planned for it stays empty).
        local at = left
        local pic = plan.pic
        if pic then
            local lx, ly = left + pic.w / 2, top + PICTURE.down + pic.h / 2
            if Portrait(pic, lx, ly) then
                local X, Y = self:Screen(lx, ly)
                local px, py = self:Out(lx, ly)
                self.picture = { lx = lx, ly = ly, w = pic.w, h = pic.h, X = X, Y = Y, x = px, y = py }
                at = left + plan.left
            end
        end
        -- The name, beside it: the strip laid it at the left.
        local head = plan.head
        Hand(self.name, head.size)
        self.name:SetText(head.first)
        Write(self.name, at, top + head.h / 2, Width(self.name) + 2, head.h)
        if head.rest then
            Hand(self.headTail, head.size)
            self.headTail:SetText(head.rest)
            Write(self.headTail, at, top + head.h + head.tailH / 2, Width(self.headTail) + 2, head.tailH)
        end
        -- The kind's lines, printed in ink.
        local INK = Style.INK
        for i, words in ipairs(plan.kinds) do
            local line = self.kinds[i]
            if not line then
                line = Style.Text(self, Style.FONT.small)
                self.kinds[i] = line
            end
            line:SetText(words)
            line:SetTextColor(INK[1], INK[2], INK[3])
            line:SetSize(0, 0)
            Write(line, at, top + plan.kindTop + (i - 0.5) * TAME.lineH, Width(line) + 2, TAME.lineH)
        end
        if plan.tag then Label(plan, at, top + plan.tagTop) end
        -- For the tests: where the writing starts, from the slip's left.
        self.writingAt = at - left
    end

    -- For the tests: the kind as printed, its lines joined.
    function card:Kind()
        local parts = {}
        for _, line in ipairs(self.kinds) do
            if line:IsShown() then parts[#parts + 1] = line:GetText() end
        end
        return table.concat(parts, " ")
    end

    return card
end

TameCard.TAME, TameCard.FORMS, TameCard.PICTURE = TAME, FORMS, PICTURE

--------------------------------------------------------------------------
-- The card in the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- The plate's one tame (Choose's, plate.tame), right after the people who
-- did something with you (10) and before firsts found (20): a pet is a
-- companion for the levels after, ranked with the people (the user's
-- "top weight", 4 Nov), so every other card is left off before it. No
-- caption words either way: left off, the paw alone tells it.
ns.UI.JourneyMargin.Register("tame", {
    order = 15, pool = "tamePool", count = "tamesWritten",
    new = function(parent) return TameCard.New(parent) end,
    item = function(plate)
        local tame = plate.tame
        return tame and { tame = tame, top = tame.mark[2], x = tame.mark[1] } or nil
    end,
    write = function(card, it, c)
        card:SetTame(it.tame.rec, c.Seed("tame", it.tame.rec.t or 0), c.now)
    end,
    mark = function(it) return it.tame.mark end,
    custom = function(it) return "tame", it.tame.rec end,
})

-- The tames the player changed or wrote, a card each past the plate's one:
-- before the people (10) and after the acquaintance's strip (2), so they
-- are among the last left off, as every kind's custom card is
-- (.claude/features/custom-cards.md; 2.5, the user's, 4 Nov). The same
-- card, the same pool.
ns.UI.JourneyMargin.Register("tameCustom", {
    order = 2.5, pool = "tamePool", count = "customTamesWritten",
    new = function(parent) return TameCard.New(parent) end,
    items = function(plate)
        local items = {}
        for _, tame in ipairs(TameCard.Customs(plate.tameMarks)) do
            items[#items + 1] = { tame = tame, top = tame.mark[2], x = tame.mark[1] }
        end
        return items
    end,
    write = function(card, it, c)
        card:SetTame(it.tame.rec, c.Seed("tame", it.tame.rec.t or 0, Hunter.Hand(it.tame.rec)), c.now)
    end,
    mark = function(it) return it.tame.mark end,
    custom = function(it) return "tame", it.tame.rec end,
})
