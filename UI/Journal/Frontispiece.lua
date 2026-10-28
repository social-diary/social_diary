-- The frontispiece: the book's first leaf, in front of the front matter
-- (UI/Journal/Front.lua), without a ribbon of its own. It shows the one idea
-- the rest of the diary depends on: strangers are pencilled in by
-- themselves, and you ink them in.
--
-- The left page is the key: PENCIL AND INK, a scribble of each beside what
-- it means, the days read from the settings. The right page is the figure,
-- a plate pasted in like the bookplate: one stranger (Thex Theximus, the
-- same the empty People page and the front matter's cut-outs draw), their
-- entry filling up in graphite with margin notes in red-brown, then a fork.
-- Left alone, the same entry fades every third of the buffer's days and is
-- rubbed out, crumbs and all. Remembered ("Remember this", ringed in red as
-- on the empty People page), a nib blot turns the line to ink, the name is
-- inked over its pencil, which still shows where the pen missed, and the
-- same lines are in ink with a note in your own hand. Static: nothing moves.
--
-- Its lifted corner (UI/Journal/Corner.lua) turns to the front matter. The
-- book opens here until the front matter has been read (UI/Journal/Book.lua),
-- and the slip at login turns here (UI/Windows/Intro/Parcel.lua). The ribbons turn
-- the book from here too; a reader who leaves the introduction that way
-- finds a label tucked under the book, asking whether to go back
-- (UI/Journal/IntroLabel.lua).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, RIGHT_X, RIGHT_W = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X, BOOK.RIGHT_W

-- The key's rhythm: the title's top, the lede's, the gap before each
-- scribble, the scribble's height, under its rubric and between the key
-- and the aside.
local KEY = { title = 20, lede = 56, gap = 26, scribble = 22, under = 6, aside = 30 }
-- The scribbles: `loops` turns `step` px apart, `high` px tall, in pencil
-- (graphite at `alpha`, `width` px) and in ink, which ends in a blot.
local SCRIBBLE = { loops = 7, step = 11, high = 13,
    pencil = { alpha = 0.72, width = 1.2 }, ink = { alpha = 0.95, width = 1.9, blot = 6, drop = 2 } }
-- The figure: where the plate is pasted, its look (Style.PastedPlate), and
-- everything on it in its own coordinates (x right, y down).
local FIGURE = {
    x = RIGHT_X - 8, y = 22, w = RIGHT_W - 8, h = 488,
    paper = { 0.89, 0.82, 0.64 }, grain = 0.10,
    rules = { { inset = 9, width = 2, alpha = 0.65 }, { inset = 14, width = 1, alpha = 0.45 } },
    lozenge = 7, lozengeInset = 10,
    glue = { size = 24, alpha = 0.07 },
    shadows = { { drop = 1, alpha = 0.22 }, { drop = 3, alpha = 0.08 } },
}
-- The stranger in pencil: the name, the who line, the lines and the step
-- between them, how far in the words start after the date.
local ENTRY = { x = 34, name = 34, who = 60, lines = 86, step = 20, words = 44 }
-- The margin notes: where they stand, how wide, and their leaders' ink.
local MARGIN = { x = 296, w = 128, leader = 0.55, gap = 8, notes = { 38, 104 } }
-- The fork, in pencil: the stem from under the entry to the fork, the
-- branch left (an arrow that trails off) and the branch right, up to the
-- nib blot where the pen takes over; then the ink on to its heading.
local FORK = {
    stem = { { 150, 150 }, { 156, 174 }, { 214, 178 } },
    left = { from = { 214, 178 }, bend = { 120, 186 }, to = { 96, 226 }, head = 8, alpha = 0.72 },
    right = { { 214, 178 }, { 252, 182 }, { 272, 194 } },
    blot = { 274, 196, 5 },
    ink = { { 274, 196 }, { 282, 216 }, { 300, 228 } }, head = 8,
    remember = { x = 290, y = 186 },
    ring = { pad = 30, h = 24, overshoot = 0.08, wobble = 0.04, alpha = 0.85, steps = 28 },
}
-- The two endings: where their rubrics stand and how wide, then each.
local ENDINGS = { y = 236, w = 186, left = 34, right = 248 }
-- Left alone: a row per stage, `step` apart, the day beside it, the name
-- and what was done under it; how much of the pencil is left at each
-- stage; the smear where it was rubbed out, the crumbs, and the caption.
local FADE = { top = 262, step = 40, words = 46, under = 17, left = { 1, 0.6, 0.32, 0.10 },
    smear = { { 74, 383, 112, 15, 0.07 }, { 80, 388, 98, 5, 0.06 } },
    crumbs = { { 160, 401, 4, 2 }, { 170, 397, 3, 2 }, { 182, 403, 5, 2 }, { 176, 408, 2, 2 }, { 190, 396, 3, 2 } },
    crumbAlpha = 0.38, caption = 414 }
-- Remembered: the name inked over its pencil, the pencil `ghost` px up and
-- right of it at `alpha`; then the lines, the note and the caption.
local INKED = { name = 262, ghost = { 1.5, 1.5, 0.5 }, who = 288, lines = 310, step = 20, words = 44, note = 376,
    caption = 414 }
-- The figure's caption, across its foot.
local CAPTION = 452

local page

--------------------------------------------------------------------------
-- What it says
--------------------------------------------------------------------------

local LINES = {
    { "3 Oct", "Seen in the Barrens" },
    { "3 Oct", "Traded: 5x Linen Cloth" },
    { "4 Oct", "Grouped for 40 min" },
}

local Days = ns.UI.Journal.PencilDays

local function PencilText()
    return ("|cff%sThe diary pencils in strangers by itself:|r anyone you pass, trade with, group with or"
        .. " whisper. It fades, and after %s the player is forgotten again."):format(Style.HEX.graphite, Days())
end

local INK_TEXT = "Ink is yours to give. Add someone, and everything pencilled is now inked in, for good."

-- The fading stages: day 1, a third, two thirds, the last.
local function Stages()
    local d = math.max(3, ns.BufferDays())
    return { 1, math.floor(d / 3 + 0.5), math.floor(2 * d / 3 + 0.5), d }
end

-- "F I G .  I": letters spaced as the bookplate's EX LIBRIS.
local function Spaced(text)
    return (text:gsub("(.)", "%1 "):gsub(" $", ""):gsub("   ", "     "))
end

--------------------------------------------------------------------------
-- The key, on the left page
--------------------------------------------------------------------------

-- A scribble tried out at the top left of `box`, in `colour`: loops along a
-- line, as a pen or pencil is tried on a margin. Ink ends in a blot.
local function Scribble(parent, box, colour, look, blot)
    local S = SCRIBBLE
    local x, y = 3, KEY.scribble / 2 + 4
    for i = 1, S.loops do
        local high = S.high * (1 - 0.06 * i) * (i % 2 == 1 and -1 or 0.4)
        Style.Curve(parent, "ARTWORK", box.x + x, box.y + y, box.x + x + S.step * 0.4, box.y + y + high,
            box.x + x + S.step, box.y + y - (i % 2) * 2, colour, look.alpha, look.width, 6)
        x = x + S.step
    end
    if blot then
        local b = parent:CreateTexture(nil, "ARTWORK", nil, 1)
        b:SetSize(look.blot, look.blot)
        b:SetPoint("CENTER", parent, "TOPLEFT", box.x + x + 3, -(box.y + y - 2))
        Style.Disc(b, colour[1], colour[2], colour[3], 0.92)
        local drop = parent:CreateTexture(nil, "ARTWORK", nil, 1)
        drop:SetSize(look.drop, look.drop)
        drop:SetPoint("CENTER", parent, "TOPLEFT", box.x + x + 8, -(box.y + y + 2))
        Style.Disc(drop, colour[1], colour[2], colour[3], 0.8)
    end
end

-- A legend: the scribble, its rubric under it, and what it means. The
-- scribble is drawn on a frame of its own under `above`, so the key
-- follows its text however long it runs.
local function Legend(parent, above, gap, title, lapis, colour, look, blot)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(LEFT_W, KEY.scribble)
    holder:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
    Scribble(holder, { x = 0, y = 0 }, colour, look, blot)

    local rubric = Style.Rubric(parent, LEFT_W)
    rubric:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -KEY.under)
    rubric:SetText(title, lapis)

    local text = Style.Text(parent, FONT.body)
    text:SetPoint("TOPLEFT", rubric, "BOTTOMLEFT", 0, -KEY.under)
    text:SetWidth(LEFT_W)
    text:SetSpacing(3)
    return text, holder
end

local function BuildKey(parent)
    local k = {}
    k.title = Style.Text(parent, FONT.page)
    k.title:SetPoint("TOPLEFT", LEFT_X, -KEY.title)
    k.title:SetText("PENCIL AND INK")

    k.lede = Style.Text(parent, FONT.lede)
    k.lede:SetPoint("TOPLEFT", LEFT_X, -KEY.lede)
    k.lede:SetWidth(LEFT_W)
    k.lede:SetSpacing(2)
    k.lede:SetText("Everyone you meet is written down, but you decide who goes into your diary.")

    k.pencil, k.pencilMark = Legend(parent, k.lede, KEY.gap, "Pencil", true, Style.GRAPHITE, SCRIBBLE.pencil)
    k.ink, k.inkMark = Legend(parent, k.pencil, KEY.gap, "Ink", false, Style.INK_STRONG, SCRIBBLE.ink, true)
    k.ink:SetText(INK_TEXT)

    k.aside = Style.Text(parent, FONT.faded)
    k.aside:SetPoint("TOPLEFT", k.ink, "BOTTOMLEFT", 0, -KEY.aside)
    k.aside:SetWidth(LEFT_W)
    k.aside:SetSpacing(3)
    k.aside:SetText("Only you decide who goes into your diary.")
    return k
end

--------------------------------------------------------------------------
-- The figure, on the right page
--------------------------------------------------------------------------

local function At(fig, font, x, y, text, alpha)
    local t = Style.Text(fig, font)
    t:SetPoint("TOPLEFT", x, -y)
    t:SetText(text)
    if alpha then t:SetAlpha(alpha) end
    return t
end

-- A curve through three points.
local function Through(fig, layer, p, colour, alpha, width)
    return Style.Curve(fig, layer, p[1][1], p[1][2], p[2][1], p[2][2], p[3][1], p[3][2], colour, alpha, width, 10)
end

-- The stranger, pencilled in, with the margin notes and their leaders.
local function BuildStranger(fig)
    local E, M = ENTRY, MARGIN
    local f = {}
    f.name = At(fig, FONT.pencilTitle, E.x, E.name, "THEX THEXIMUS")
    f.who = At(fig, FONT.pencil, E.x, E.who, "Troll Hunter  \194\183  level 12")
    f.lines = {}
    for i, line in ipairs(LINES) do
        local y = E.lines + (i - 1) * E.step
        At(fig, FONT.pencilSmall, E.x, y + 2, line[1])
        f.lines[i] = At(fig, FONT.pencil, E.x + E.words, y, line[2])
    end

    f.notes = {}
    local words = { "Pencilled in automatically.", "Every meeting after that, too." }
    for i, y in ipairs(M.notes) do
        local note = Style.Text(fig, FONT.margin)
        note:SetPoint("TOPLEFT", M.x, -y)
        note:SetWidth(M.w)
        note:SetSpacing(1)
        note:SetText(words[i])
        f.notes[i] = note
    end
    return f
end

-- The leaders, once the client has measured the text they run to: to the
-- end of the name, and to the end of the longest line.
local function DrawLeaders(fig, f)
    local M, E, A = MARGIN, ENTRY, Style.ACCENT
    local nameEnd = E.x + (f.name:GetUnboundedStringWidth() or 0) + M.gap
    local lineEnd = 0
    for _, line in ipairs(f.lines) do
        lineEnd = math.max(lineEnd, E.x + E.words + (line:GetUnboundedStringWidth() or 0))
    end
    lineEnd = lineEnd + M.gap
    local y1, y2 = M.notes[1] + 8, M.notes[2] + 8
    Style.Curve(fig, "ARTWORK", M.x - 4, y1, (M.x + nameEnd) / 2, y1, nameEnd, E.name + 12, A, M.leader, 1, 6)
    Style.Curve(fig, "ARTWORK", M.x - 4, y2, (M.x + lineEnd) / 2, y2, lineEnd, E.lines + E.step + 8, A, M.leader,
        1, 6)
end

-- The fork: pencil to the left, pencil then ink to the right, and
-- Remember this ringed where the pen takes over.
local function BuildFork(fig)
    local F, G, INK = FORK, Style.GRAPHITE, Style.INK_STRONG
    Through(fig, "ARTWORK", F.stem, G, F.left.alpha, 1.2)
    Style.Arrow(fig, "ARTWORK", F.left.from, F.left.bend, F.left.to, F.left.alpha, F.left.head)
    Through(fig, "ARTWORK", F.right, G, F.left.alpha, 1.2)

    local blot = fig:CreateTexture(nil, "ARTWORK", nil, 2)
    blot:SetSize(F.blot[3], F.blot[3])
    blot:SetPoint("CENTER", fig, "TOPLEFT", F.blot[1], -F.blot[2])
    Style.Disc(blot, INK[1], INK[2], INK[3], 0.9)
    Through(fig, "ARTWORK", F.ink, INK, 0.95, 2)
    local to, from = F.ink[3], F.ink[2]
    local back = math.atan2(from[2] - to[2], from[1] - to[1])
    for _, side in ipairs({ -0.5, 0.5 }) do
        local t = back + side
        Style.Stroke(fig, "ARTWORK", to[1], to[2], to[1] + F.head * math.cos(t), to[2] + F.head * math.sin(t), INK,
            0.95, 1.6)
    end

    local remember = At(fig, FONT.body, F.remember.x, F.remember.y, "Add to Diary")
    return remember
end

local function DrawRing(fig, remember)
    local F = FORK
    local w = (remember:GetUnboundedStringWidth() or 90) + F.ring.pad
    local R = { w = w, h = F.ring.h, overshoot = F.ring.overshoot, wobble = F.ring.wobble, alpha = F.ring.alpha,
        steps = F.ring.steps }
    Style.HandRing(fig, "OVERLAY", F.remember.x + (w - F.ring.pad) / 2, F.remember.y + 8, R)
end

-- Left alone: the same entry at each stage, fainter, then rubbed out.
local function BuildFaded(fig)
    local D, G = FADE, Style.GRAPHITE
    local rub = {}
    rub.days, rub.names = {}, {}
    for i = 1, 4 do
        local y = D.top + (i - 1) * D.step
        rub.days[i] = At(fig, FONT.small, ENDINGS.left, y + 2, "")
        rub.names[i] = At(fig, FONT.pencil, ENDINGS.left + D.words, y, "Thex Theximus", D.left[i])
        if i < 4 then
            At(fig, FONT.pencilSmall, ENDINGS.left + D.words, y + D.under, "seen, traded, grouped", D.left[i])
        end
    end
    for _, s in ipairs(D.smear) do
        local smear = fig:CreateTexture(nil, "ARTWORK", nil, 3)
        smear:SetSize(s[3], s[4])
        smear:SetPoint("TOPLEFT", s[1], -s[2])
        smear:SetColorTexture(G[1], G[2], G[3], s[5])
        if smear.SetRotation then smear:SetRotation(math.rad(2)) end
    end
    for i, c in ipairs(D.crumbs) do
        local crumb = fig:CreateTexture(nil, "ARTWORK", nil, 3)
        crumb:SetSize(c[3], c[4])
        crumb:SetPoint("TOPLEFT", c[1], -c[2])
        crumb:SetColorTexture(G[1], G[2], G[3], D.crumbAlpha)
        if crumb.SetRotation then crumb:SetRotation(math.rad(Style.Noise(i) * 120 - 60)) end
    end
    rub.caption = At(fig, FONT.small, ENDINGS.left, D.caption, "Rubbed out, and deleted.")
    return rub
end

-- Remembered: inked over the pencil, with your note.
local function BuildInked(fig)
    local I, x = INKED, ENDINGS.right
    local inked = {}
    local ghost = At(fig, FONT.pencilTitle, x + I.ghost[1], I.name - I.ghost[2], "THEX THEXIMUS", I.ghost[3])
    inked.ghost = ghost
    inked.name = At(fig, FONT.titleSmall, x, I.name, "THEX THEXIMUS")
    inked.who = At(fig, FONT.faded, x, I.who, "Troll Hunter  \194\183  level 12")
    for i, line in ipairs(LINES) do
        local y = I.lines + (i - 1) * I.step
        At(fig, FONT.small, x, y + 2, line[1])
        At(fig, FONT.body, x + I.words, y, line[2])
    end
    inked.note = At(fig, FONT.noteWritten, x, I.note, "Saved me from the Nagas.")
    inked.caption = At(fig, FONT.small, x, I.caption, "Saved indefinitely.")
    return inked
end

local function BuildFigure(parent)
    local P = FIGURE
    local fig = Style.PastedPlate(parent, P.x, P.y, P.w, P.h, P)
    fig.stranger = BuildStranger(fig)
    fig.remember = BuildFork(fig)

    local leave = Style.Rubric(fig, ENDINGS.w)
    leave:SetPoint("TOPLEFT", ENDINGS.left, -ENDINGS.y)
    leave:SetText("Strangers lose their data", true)
    local add = Style.Rubric(fig, ENDINGS.w)
    add:SetPoint("TOPLEFT", ENDINGS.right, -ENDINGS.y)
    add:SetText("Diary entries are kept", false)

    fig.faded = BuildFaded(fig)
    fig.inked = BuildInked(fig)

    fig.caption = Style.Text(fig, FONT.heading)
    fig.caption:SetPoint("TOP", 0, -CAPTION)
    fig.caption:SetText(Spaced("FIG. I") .. "     \194\183     " .. Spaced("Strangers vs. Entries"))
    return fig
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

local function BuildPage(parent)
    page = { parent = parent }
    page.key = BuildKey(parent)
    page.figure = BuildFigure(parent)
    page.corner = ns.UI.Journal.PageCorner(parent, function() ns.UI.Journal.TurnTo("front") end)
    return page
end

-- Fills in the days, and draws what waits on the client's measures: the
-- leaders to the text and the ring round it. Open here, the slip has done
-- what it asked for this login; it asks again at the next until the front
-- matter has been read.
local function Refresh()
    if not page then return end
    if ns.UI.JournalShowing("frontispiece") and ns.UI.Parcel and ns.UI.Parcel.HideSlip then ns.UI.Parcel.HideSlip() end
    page.key.pencil:SetText(PencilText())
    local stages = Stages()
    for i, d in ipairs(stages) do page.figure.faded.days[i]:SetText("day " .. d) end

    if not page.drawn then
        DrawLeaders(page.figure, page.figure.stranger)
        DrawRing(page.figure, page.figure.remember)
        page.drawn = true
    end
end

-- Test hook: the frontispiece's page.
function ns.UI.Frontispiece()
    return page
end

-- The book's first leaf, without a ribbon (UI/Journal/Pages.lua).
ns.UI.Journal.RegisterPage("frontispiece", {
    flyleaf = 0, buildOrder = 20,
    build = function(container) BuildPage(container) end,
    refresh = function() Refresh() end,
})
