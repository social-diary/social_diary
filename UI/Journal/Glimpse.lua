-- A stranger's glimpse: their page, pencilled in (the stranger-glimpse
-- proposal, option (a), sections 1 to 4; the user's decisions of 5 Nov
-- 2026). On the People page's right page, in place of "Choose someone",
-- with nobody selected on the list.
--
-- A first sighting in hindsight puts a stranger on a Your Diary plate; a
-- witness card or a custom "met" strip can name one too. Their name is a
-- way to their page, as every name in the book is, but a stranger has no
-- inked page. So the book opens where it would be and shows what is
-- pencilled there: their name in the hand, a pencil ring where their
-- portrait will go, the map print lying loose (not glued), two pencilled
-- notes with leaders to the print (where you first saw them, and what
-- happened later that made them matter), the few things after that, how
-- often they were seen, and one thing in paper and ink: a strip taped at
-- the foot saying how long the pencil lasts, with the one link on the page,
-- to add them. Adding them inks the page where it lies: the profile is laid
-- on the same geometry (PersonHeader's name and portrait, the plate's slot,
-- the facts' column), so nothing moves; it becomes their page.
--
-- Restraint, as the map sheet's rule has it: everything but the strip is
-- one grey (Style.GRAPHITE), the faction where it is not yours is the
-- page's one colour, the link the only ink. No rubric, no lapis, no frame,
-- no button, no close cross.
--
-- What it shows is ns.Glimpse.Of's (Core/Glimpse.lua), read on every
-- refresh, its print ns.PersonPlate.Glimpse's (Core/PersonPlate.lua) drawn
-- loose (UI/Journal/PersonPlate.lua's NewLoose); its words are
-- UI/Words/Person.lua's (PersonText.GLIMPSE). The book keeps whose glimpse
-- is open (J.glimpse, UI/Journal/Book.lua) and the profile decides when it
-- shows (UI/Journal/Profile.lua's RefreshProfile).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal
local PersonText = ns.UI.PersonText
local Header = ns.UI.PersonHeader
local Width = ns.UI.Surface.Width

local BOOK = J.BOOK
local RIGHT_X, RIGHT_W, RIGHT_H, TOP = BOOK.RIGHT_X, BOOK.RIGHT_W, BOOK.RIGHT_H, BOOK.TOP

local Glimpse = {}
ns.UI.Glimpse = Glimpse

-- The page (466 x 534, x right and y down from the right page's frame, the
-- person page's own: so the ink lands on the pencil). Every size here:
local GLIMPSE = {
    -- The header band, on PersonHeader's geometry (UI/Journal/Header.lua):
    --   name     the hand, pencilled, straight (the arc is the inked
    --            heading's flourish, theirs once they are written in), from
    --            Header's NAME.x with its baseline on NAME.baseline, NAME.room
    --            px for it; too long, a size down (`sizes`, FONT keys), then
    --            cut ({ font, its size }, Style/Tokens.lua's). `mid`: how far over its baseline the middle of the
    --            hand's line lies, in ems (Neuton Italic's ascent and
    --            descent about its line)
    name = { sizes = { { "pencilName", 22 }, { "pencilNameSmall", 18 } }, mid = 0.32 },
    --   ring     the portrait's place: a hand-drawn ring in graphite, the
    --            size of Header's PORTRAIT, as the empty page draws round
    --            Remember this: how far it overshoots, how unevenly drawn,
    --            its alpha, its strokes
    ring = { overshoot = 0.10, wobble = 0.05, alpha = 0.55, steps = 28 },
    --   icon     their class in it, `size` px, greyed, at `alpha`; the ring
    --            alone where the class is unknown
    icon = { size = 28, alpha = 0.45 },
    -- The block under the header (the person page's top block, Clippings'
    -- BLOCK.pad down): the print lies in it at PersonPlate's LOOSE slot.
    block = { top = 81, width = 458 },
    -- The two notes, written straight on the page in pencil (not on strips:
    -- a strip is something taped in to keep, and nothing is kept yet):
    --   column   beside the print, from `x` to `right`, the first `top` px
    --            down the block, `gap` px between the two
    --   alone    without a print: from `x` to `right`, the two side by side,
    --            `gap` px apart
    --   lines    the hand's line, up to this many lines; `lineH` each (the
    --            hand at 16), the headings and sub lines `smallH` (Friz 11)
    --   under    px between a note's heading and its line, and its line and
    --            sub line
    --   lead     how far left of a note's edge its leader leaves, and how
    --            far into its height (from its top) it may leave at most
    column = { x = 284, right = 452, top = 18, gap = 22 },
    alone = { x = 16, right = 452, gap = 22 },
    note = { lines = 2, lineH = 19, smallH = 13, under = 2, lead = { out = 3, from = 6 } },
    -- After that: `gap` px under the lower of the print and the notes; its
    -- heading, then at most Glimpse.LOOK.after lines `step` px apart, each a
    -- day right-aligned to `dayRight` from `x` and the row's words from
    -- `words` to `right`, one line cut; "and n more" under them.
    ledger = { gap = 22, x = 16, dayRight = 92, words = 104, right = 452, headH = 16, step = 20 },
    -- The seen line: `gap` px under what is above it, from `x`, `w` wide,
    -- two lines at most, `lineH` a line (Friz 13).
    seen = { gap = 14, x = 16, w = 436, lines = 2, lineH = 16 },
    -- The foot strip: at most `w` wide, its right edge at `right`, its top
    -- `gap` px under the seen line and never above `least`; turned `tilt`
    -- degrees, seeded per person (`seed` .. their GUID), so the same
    -- stranger's strip lies the same way every time; its what-line `lines`
    -- lines at most. The ledger gives up a line before its foot would pass
    -- `foot` px down the page.
    strip = { w = 270, right = 452, gap = 24, least = 400, tilt = -1.1, seed = "glimpse:", lines = 2,
        foot = RIGHT_H - 6 },
}
Glimpse.GLIMPSE = GLIMPSE

--------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------

-- A font string in `font`, one line unless `wrap`.
local function Words(parent, font, wrap)
    local text = Style.Text(parent, font)
    text:SetWordWrap(wrap == true)
    return text
end

-- `text` placed with its top left at x, y of `frame` (y down), `w` wide.
local function At(text, frame, x, y, w, h)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    if w then text:SetWidth(w) end
    if h then text:SetHeight(h) end
end

-- How tall `text` is written, in lines of `lineH` px, `most` at most.
local function Tall(text, lineH, most)
    if (text:GetText() or "") == "" then return 0 end
    local lines = math.max(1, math.floor((text:GetStringHeight() or 0) / lineH + 0.5))
    return math.min(lines, most or lines) * lineH
end

-- A square over `text` (which cannot take the mouse) whose tooltip is
-- `tip()`'s: a line cut short keeps all of itself there.
local function Hover(parent)
    local button = CreateFrame("Button", nil, parent)
    Style.Tooltip(button, function(self) return self.tip and self.tip() end, "ANCHOR_RIGHT")
    button:Hide()
    function button:Over(text, w, h, tip)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", text, "TOPLEFT", 0, 0)
        self:SetSize(math.max(w, 1), math.max(h, 1))
        self.tip = tip
        self:SetShown(tip ~= nil)
    end
    return button
end

-- One pencilled note: a heading in Friz capitals, the line in the hand
-- (two lines at most), a sub line; and the edge its leader leaves from.
local function Note(parent)
    local N = GLIMPSE.note
    local note = { heading = Words(parent, FONT.pencilSmall), line = Words(parent, FONT.pencilHand, true),
        sub = Words(parent, FONT.pencilSmall) }
    if note.line.SetMaxLines then note.line:SetMaxLines(N.lines) end
    note.hover = Hover(parent)

    -- Written at x, y of the block, `w` wide; returns its height.
    function note:Lay(x, y, w, heading, line, sub, tip)
        self.heading:SetText((heading or ""):upper())
        self.line:SetText(line or "")
        self.sub:SetText(sub or "")
        At(self.heading, parent, x, y, w)
        local top = y + N.smallH + N.under
        At(self.line, parent, x, top, w)
        local lineH = Tall(self.line, N.lineH, N.lines)
        self.line:SetHeight(math.max(lineH, 1))
        self.hover:Over(self.line, w, lineH, tip)
        local subY = top + lineH + (sub and N.under or 0)
        At(self.sub, parent, x, subY, w)
        self.sub:SetShown(sub ~= nil)
        local h = subY - y + (sub and N.smallH or 0)
        self.box = { x, y, w, h }
        for _, piece in ipairs({ self.heading, self.line }) do piece:Show() end
        return h
    end

    -- The point of its edge nearest x, y of the block: its left edge, a
    -- little out, no lower than its writing, for the leader (PersonPlate's
    -- Aim asks this of what it leads from).
    function note:Nearest(_, my)
        local x, y, _, h = unpack(self.box)
        local L = N.lead
        return x - L.out, math.max(y + L.from, math.min(my, y + math.max(L.from, h - L.from)))
    end

    function note:Hide()
        for _, piece in ipairs({ self.heading, self.line, self.sub, self.hover }) do piece:Hide() end
    end

    return note
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

-- The glimpse page on `parent` (the People page's container), over the
-- right page. Hidden until Fill.
function Glimpse.New(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", RIGHT_X, -TOP)
    frame:SetSize(RIGHT_W, RIGHT_H)
    frame:Hide()
    local page = { frame = frame }

    -- The header band: the ring and the class in it, drawn once (the ring
    -- is the hand's, the same every time), the name, the who line.
    local P, NAME, WHO = Header.PORTRAIT, Header.NAME, Header.WHO
    local R = GLIMPSE.ring
    local cx, cy = P.x + P.size / 2, P.y + P.size / 2
    Style.HandRing(frame, "ARTWORK", cx, cy, { w = P.size, h = P.size, overshoot = R.overshoot, wobble = R.wobble,
        alpha = R.alpha, steps = R.steps, colour = Style.GRAPHITE })
    page.icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    local I = GLIMPSE.icon
    page.icon:SetSize(I.size, I.size)
    page.icon:SetPoint("CENTER", frame, "TOPLEFT", cx, -cy)
    page.name = Words(frame, FONT.pencilName)
    page.who = Words(frame, FONT.pencilSmall)

    -- The block: the loose print and the notes beside it, then the ledger.
    local B = GLIMPSE.block
    local block = CreateFrame("Frame", nil, frame)
    block:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -B.top)
    block:SetSize(B.width, RIGHT_H - B.top)
    page.block = block
    page.print = ns.UI.PersonPlate.NewLoose(block)
    page.first, page.hinge = Note(block), Note(block)

    page.ledgerHeading = Words(block, FONT.pencilSmall)
    page.rows = {}
    for i = 1, ns.Glimpse.LOOK.after do
        local row = { day = Words(block, FONT.pencilSmall), words = Words(block, FONT.pencil), hover = Hover(block) }
        row.day:SetJustifyH("RIGHT")
        page.rows[i] = row
    end
    page.more = Words(block, FONT.pencilSmall)
    page.seen = Words(block, FONT.pencil, true)
    if page.seen.SetMaxLines then page.seen:SetMaxLines(GLIMPSE.seen.lines) end

    -- The foot strip, taped on the page, over the rest.
    page.strip = ns.UI.PaperStrip(frame)
    page.strip:SetFrameLevel(block:GetFrameLevel() + 30)
    page.measure = Words(frame, FONT.noteWritten)
    page.measure:SetAlpha(0)

    -- The header: their name in pencil, a size down rather than lose its
    -- end, then cut at its room; the who line under it, the faction only
    -- where it is not yours.
    local function LayHeader(g)
        local name = page.name
        name:SetText(g.name or "")
        local size
        for _, step in ipairs(GLIMPSE.name.sizes) do
            name:SetFontObject(FONT[step[1]])
            page.nameFont, size = step[1], step[2]
            if Width(name) + 2 <= NAME.room then break end
        end
        local w = math.min(NAME.room, Width(name) + 2)
        name:ClearAllPoints()
        name:SetPoint("LEFT", frame, "TOPLEFT", NAME.x, -(NAME.baseline - GLIMPSE.name.mid * size))
        name:SetWidth(w)
        page.who:SetText(ns.UI.Format.WhoLine(g.record, nil, true))
        At(page.who, frame, WHO.x, WHO.y, Header.SHEET.right - WHO.x, WHO.h)
        local class = g.record and g.record.class
        if Style.SetClassIcon(page.icon, class) then
            if page.icon.SetDesaturated then page.icon:SetDesaturated(true) end
            page.icon:SetAlpha(I.alpha)
            page.icon:Show()
        else
            page.icon:Hide()
        end
    end

    -- The two notes: with a print, in the column beside it, each with its
    -- leader to its mark (a hinge on another map has none, and its sub line
    -- says where instead); without one, side by side across the page.
    -- Returns the lowest they and the print reach on the block.
    local function LayNotes(g, plated, now)
        local C, A = GLIMPSE.column, GLIMPSE.alone
        local onPrint = plated and page.print:MarkOf("hinge") ~= nil
        local pieces = {}
        if g.first then
            local heading, line, sub = PersonText.GlimpseFirst(g.first, now)
            pieces[#pieces + 1] = { note = page.first, which = "first", heading = heading, line = line, sub = sub }
        else
            page.first:Hide()
        end
        if g.hinge then
            local heading, line, sub, long = PersonText.GlimpseHinge(g.hinge, g.first, onPrint, now, g.guid)
            local whole = line
            pieces[#pieces + 1] = { note = page.hinge, which = "hinge", heading = heading, line = line, sub = sub,
                long = long, tip = function() return Style.TipList(whole) end }
        else
            page.hinge:Hide()
        end
        local bottom = plated and (ns.UI.PersonPlate.LOOSE.y + ns.UI.PersonPlate.LOOSE.h) or 0
        local y = C.top
        local alone = (A.right - A.x - A.gap) / 2
        for i, piece in ipairs(pieces) do
            local x, w
            if plated then
                x, w = C.x, C.right - C.x
            else
                x, w = A.x + (i - 1) * (alone + A.gap), alone
                y = C.top
            end
            -- The place with the levels joined on, where that is one line.
            local sub = piece.sub
            if piece.long then
                piece.note.sub:SetText(piece.long)
                if Width(piece.note.sub) <= w then sub = piece.long end
            end
            local h = piece.note:Lay(x, y, w, piece.heading, piece.line, sub, piece.tip)
            bottom = math.max(bottom, y + h)
            if plated then
                page.print:Lead(piece.which, piece.note)
                y = y + h + C.gap
            end
        end
        return bottom
    end

    -- After that, from `top` of the block: its heading and up to `most`
    -- lines; the rest counted. Returns where it ends (top where it is left
    -- out: nothing came after the hinge).
    local function LayLedger(g, top, most, now)
        local L = GLIMPSE.ledger
        local shown = math.min(#g.after, most)
        local more = g.more + (#g.after - shown)
        page.ledgerHeading:SetShown(#g.after > 0)
        page.more:SetShown(#g.after > 0 and more > 0)
        for i, row in ipairs(page.rows) do
            local on = i <= shown
            row.day:SetShown(on)
            row.words:SetShown(on)
            if not on then row.hover:Hide() end
        end
        if #g.after == 0 then return top end
        local y = top + L.gap
        page.ledgerHeading:SetText(PersonText.GLIMPSE.after:upper())
        At(page.ledgerHeading, block, L.x, y, L.right - L.x)
        y = y + L.headH
        for i = 1, shown do
            local row, r = page.rows[i], g.after[i]
            row.day:SetText(PersonText.GlimpseDay(r.time, now):upper())
            At(row.day, block, L.x, y + 2, L.dayRight - L.x)
            local words = PersonText.GlimpseRow(r, g.guid)
            row.words:SetText(words)
            At(row.words, block, L.words, y, L.right - L.words)
            row.hover:Over(row.words, L.right - L.words, L.step, function() return Style.TipList(words) end)
            y = y + L.step
        end
        if more > 0 then
            page.more:SetText(PersonText.GlimpseMore(more))
            At(page.more, block, L.words, y)
            y = y + L.step
        end
        return y
    end

    -- The foot strip at `top` of the page (never above GLIMPSE.strip.least),
    -- its right edge at GLIMPSE.strip.right. Returns its foot.
    local function LayStrip(g, top, now)
        local S = GLIMPSE.strip
        local short = ns.UI.JourneyText.Short(g.guid) or g.name
        local name, brief, words, link = PersonText.GlimpseFoot(g, short, J.PencilDays(), now)
        -- The year form where the long one would not fit the strip.
        page.measure:SetText(name)
        if brief and Width(page.measure) + 16 > S.w then name = brief end
        page.strip:SetNote({ name = name, strong = true, what = words, lines = S.lines, ink = Style.INK,
            seed = S.seed .. g.guid, tilt = S.tilt, light = true,
            foot = { text = link, font = FONT.strong, arrow = true, onClick = function() Glimpse.AddOpen() end } })
        local y = math.max(S.least, top)
        local w = page.strip:Layout(0, y, S.w)
        local _, h = page.strip:Layout(S.right - w, y, S.w)
        return y + h
    end

    -- Fills the page for the glimpse `g` (ns.Glimpse.Of's) and shows it.
    function page:Fill(g, now)
        now = now or ns.Now()
        self.g = g
        LayHeader(g)
        local pick = ns.PersonPlate.Glimpse(g.guid, g)
        local plated = self.print:DrawGlimpse(pick, g, now)
        self.plated = plated
        local bottom = LayNotes(g, plated, now)

        -- The ledger gives up a line at a time before the strip would run
        -- off the page's foot.
        local most = ns.Glimpse.LOOK.after
        local SE, S = GLIMPSE.seen, GLIMPSE.strip
        while true do
            local y = LayLedger(g, bottom, most, now)
            self.seen:SetText(PersonText.GlimpseSeen(g, now))
            At(self.seen, block, SE.x, y + SE.gap, SE.w)
            local seenH = Tall(self.seen, SE.lineH, SE.lines)
            self.seen:SetHeight(math.max(seenH, 1))
            local seenFoot = GLIMPSE.block.top + y + SE.gap + seenH
            local foot = LayStrip(g, seenFoot + S.gap, now)
            self.foot = foot
            if foot <= S.foot or most == 0 or #g.after == 0 then break end
            most = most - 1
        end
        self.shownAfter = math.min(#g.after, most)
        frame:Show()
    end

    function page:Hide()
        self.g = nil
        frame:Hide()
    end

    function page:IsShown() return frame:IsShown() end

    return page
end

-- The glimpse's one action (its foot strip's link): adds the open glimpse's
-- stranger to the diary at the place they were met (ns.Glimpse.Add), with
-- the sound of writing, and lays the book again: the profile finds them in
-- the diary and their page is laid where the pencil was
-- (UI/Journal/Profile.lua). Diary.Add fires nothing itself, so the refresh
-- is called here. It does not open writing mode: the player came to look.
function Glimpse.AddOpen()
    local guid = J.glimpse
    if not guid then return end
    local entry, added = ns.Glimpse.Add(guid)
    if not entry then return end
    if added then Style.PlaySound("write") end
    ns.UI.RefreshJournal()
end

-- Built on the People page beside the welcome (UI/Journal/People.lua).
function J.BuildGlimpse(panel, people)
    panel.glimpse = Glimpse.New(people)
    return panel.glimpse
end
