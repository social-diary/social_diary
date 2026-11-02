-- An empty diary's People page: how someone gets in, and what their page
-- will be once they are.
--
-- The left page, in place of the search and the list, says the three ways
-- in, each drawn: the right-click menu with Remember this ringed in red; the
-- Remember this key, which ships unbound, so it can be bound right here; and
-- Recently nearby, with how many are pencilled in already. The right page, in place of "Choose someone",
-- is a page drawn in pencil with notes in the margin, and what the diary
-- does when they come back.
--
-- The first person added takes it all away: nothing here has to be
-- dismissed.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, RIGHT_X, RIGHT_W = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X, BOOK.RIGHT_W

local REMEMBER = "SOCIALDIARY_REMEMBER"

-- The left page's rhythm: where the opening line starts, the gap before
-- each way in, and under its heading.
local WAYS = { top = 54, gap = 16, under = 6 }
-- The right-click menu, drawn in ink: its width, a line, the padding, how
-- far in its text starts, and its frame's ink. The red ring round
-- Remember this: its size, how far it overshoots where it began, how
-- unevenly it was drawn, and its ink.
local MENU = { w = 160, row = 17, pad = 5, indent = 12, edge = 0.65,
    ring = { w = 118, h = 21, overshoot = 0.12, wobble = 0.05, alpha = 0.85, steps = 28 } }
-- The page drawn in pencil, on the right, and its notes in the margin:
-- where each starts (y down), and the point its leader runs to.
local SAMPLE = { top = 56, w = 266, portrait = 46 }
-- The notes: where they stand, how wide, their leaders' ink, and how far
-- short of what it is about each leader stops. The leaders run to the
-- text as the client measures it, not as wide as it was guessed to be.
local NOTES = { x = RIGHT_X + 296, w = 166, leader = 0.55, gap = 8 }
-- The sample's timeline: the gap under the story, and each line's step.
local TIMELINE = { gap = 12, line = 20, day = 22 }

local welcome

--------------------------------------------------------------------------
-- The left page: three ways in
--------------------------------------------------------------------------

local function Paragraph(parent, font, width)
    local text = Style.Text(parent, font)
    text:SetWidth(width)
    text:SetSpacing(2)
    return text
end

local function BuildMenu(parent)
    local M, INK = MENU, Style.INK
    local items = { "Whisper", "Invite", "Remember this\226\128\166" }
    local menu = CreateFrame("Frame", nil, parent)
    menu:SetSize(M.w, M.pad * 2 + M.row * (#items + 1) + 3)
    local wash = menu:CreateTexture(nil, "BACKGROUND")
    wash:SetAllPoints()
    wash:SetColorTexture(INK[1], INK[2], INK[3], 0.05)
    Style.Hairline(menu, "BORDER", 0, M.edge)

    local name = Style.Text(menu, FONT.strong)
    name:SetPoint("TOPLEFT", M.indent, -M.pad - 1)
    name:SetText("Thex Theximus")
    local rule = menu:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 4, -M.pad - M.row)
    rule:SetPoint("TOPRIGHT", -4, -M.pad - M.row)
    rule:SetColorTexture(INK[1], INK[2], INK[3], 0.25)

    for i, label in ipairs(items) do
        local item = Style.Text(menu, i == #items and FONT.strong or FONT.faded)
        item:SetPoint("TOPLEFT", M.indent, -M.pad - 3 - M.row * i - 1)
        item:SetText(label)
    end
    -- The ring round the last, drawn on the menu.
    local y = M.pad + 3 + M.row * #items + M.row / 2 - 1
    Style.HandRing(menu, "OVERLAY", M.indent + M.ring.w / 2 - 8, y, M.ring)
    return menu
end

local function BuildLeft(w)
    w.intro = Paragraph(w, FONT.body, LEFT_W)
    w.intro:SetPoint("TOPLEFT", LEFT_X, -WAYS.top)
    w.intro:SetText("Nobody is in the diary yet. There are three ways in.")

    -- 1. The right-click menu.
    w.menuHeading = Style.Rubric(w, LEFT_W)
    w.menuHeading:SetPoint("TOPLEFT", w.intro, "BOTTOMLEFT", 0, -WAYS.gap)
    w.menuHeading:SetText("Right-click them", false)
    w.menu = BuildMenu(w)
    w.menu:SetPoint("TOPLEFT", w.menuHeading, "BOTTOMLEFT", 6, -WAYS.under - 2)
    w.menuWhere = Paragraph(w, FONT.faded, LEFT_W)
    w.menuWhere:SetPoint("TOPLEFT", w.menu, "BOTTOMLEFT", -6, -WAYS.under)
    w.menuWhere:SetText("In the world, in chat, or in your group.")

    -- 2. The key.
    w.keyHeading = Style.Rubric(w, LEFT_W)
    w.keyHeading:SetPoint("TOPLEFT", w.menuWhere, "BOTTOMLEFT", 0, -WAYS.gap)
    w.keyHeading:SetText("Or press a key", true)
    w.keyText = Paragraph(w, FONT.body, LEFT_W)
    w.keyText:SetPoint("TOPLEFT", w.keyHeading, "BOTTOMLEFT", 0, -WAYS.under)
    w.keyText:SetText("Target them first.")
    -- The keycap, its link and the listening are UI/Kit/Keys.lua's, as
    -- Settings binds both keys the same way.
    w.keyStatus = Paragraph(w, FONT.small, LEFT_W)
    w.key = ns.UI.Keys.Setter(w, REMEMBER, w.keyStatus)
    w.key:SetPoint("TOPLEFT", w.keyText, "BOTTOMLEFT", 0, -WAYS.under)
    w.key:SetWidth(LEFT_W)
    w.keyStatus:SetPoint("TOPLEFT", w.key, "BOTTOMLEFT", 0, -4)

    -- 3. Later, from Recently nearby.
    w.laterHeading = Style.Rubric(w, LEFT_W)
    w.laterHeading:SetPoint("TOPLEFT", w.keyStatus, "BOTTOMLEFT", 0, -WAYS.gap + 4)
    w.laterHeading:SetText("Or add them later", false)
    w.laterText = Paragraph(w, FONT.body, LEFT_W)
    w.laterText:SetPoint("TOPLEFT", w.laterHeading, "BOTTOMLEFT", 0, -WAYS.under)
    w.nearby = Style.Link(w, FONT.body, function() J.TurnTo("nearby") end)
    w.nearby:SetText(J.Page("nearby").ribbon.label)
    w.nearby:SetPoint("TOPLEFT", w.laterText, "BOTTOMLEFT", 0, -WAYS.under)
end

--------------------------------------------------------------------------
-- The right page: a page drawn in pencil
--------------------------------------------------------------------------

-- Pencil text at x, y on the page (y down).
local function Pencilled(w, font, x, y, text, width)
    local t = Style.Text(w, font)
    t:SetPoint("TOPLEFT", RIGHT_X + x, -SAMPLE.top - y)
    if width then
        t:SetWidth(width)
        t:SetSpacing(3)
    end
    t:SetText(text)
    return t
end

local function BuildRight(w)
    local G, P = Style.GRAPHITE, Style.PAPER
    w.sampleLede = Style.Text(w, FONT.faded)
    w.sampleLede:SetPoint("TOPLEFT", RIGHT_X, -22)
    w.sampleLede:SetText("Each person gets a page, and it fills itself in:")

    -- The portrait, a ring in pencil.
    local size = SAMPLE.portrait
    local ring = w:CreateTexture(nil, "ARTWORK", nil, 0)
    ring:SetSize(size, size)
    ring:SetPoint("TOPLEFT", RIGHT_X, -SAMPLE.top)
    Style.Disc(ring, G[1], G[2], G[3], 0.75)
    local hollow = w:CreateTexture(nil, "ARTWORK", nil, 1)
    hollow:SetSize(size - 3, size - 3)
    hollow:SetPoint("CENTER", ring)
    Style.Disc(hollow, P[1], P[2], P[3], 1)

    local x = size + 12
    Pencilled(w, FONT.pencilTitle, x, 2, "THEX THEXIMUS")
    Pencilled(w, FONT.pencil, x, 28, "Level 12 Troll Hunter")
    local tagX = x
    for _, tag in ipairs({ "helper", "friend" }) do
        local box = CreateFrame("Frame", nil, w)
        local label = Style.Text(box, FONT.pencilSmall)
        label:SetPoint("CENTER", 0, 0)
        label:SetText(tag)
        local width = (label:GetUnboundedStringWidth() or 0) + 14
        box:SetSize(width, 18)
        box:SetPoint("TOPLEFT", RIGHT_X + tagX, -SAMPLE.top - 50)
        Style.Hairline(box, "ARTWORK", 0, 0.7)
        tagX = tagX + width + 6
    end
    w.sampleTagsEnd = tagX

    -- How far right a pencilled line ends, as the client sets it, capped
    -- at `width` for one that wraps.
    local function RightOf(text, x, width)
        local measured = text:GetUnboundedStringWidth() or 0
        return x + (width and math.min(measured, width) or measured)
    end

    local note = Pencilled(w, FONT.pencil, 0, 88, "Helped me with the Nagas at the lake.")
    local rule = w:CreateTexture(nil, "ARTWORK")
    rule:SetSize(SAMPLE.w, 1)
    rule:SetPoint("TOPLEFT", RIGHT_X, -SAMPLE.top - 112)
    Style.Gradient(rule, "HORIZONTAL", { G[1], G[2], G[3], 0.5 }, { G[1], G[2], G[3], 0 })
    local story = Pencilled(w, FONT.pencil, 0, 122, "You first met Thex in the Barrens on 3 October,"
        .. " when they were level 12. You\226\128\153ve crossed paths 4 times and spent 3 hours together.",
        SAMPLE.w)

    -- The timeline starts under the story, however many lines it took.
    local y = 122 + (story:GetStringHeight() or 0) + TIMELINE.gap
    local lines = {
        { nil, "TODAY" },
        { "21:40", "Quested together for 1h 05m" },
        { "21:12", "They resurrected you" },
        { nil, "SATURDAY, 3 OCTOBER" },
        { "18:02", "Traded: 5x Linen Cloth" },
    }
    local firstLine, firstY
    for _, line in ipairs(lines) do
        if line[1] then
            Pencilled(w, FONT.pencilSmall, 0, y + 2, line[1])
            local text = Pencilled(w, FONT.pencil, 40, y, line[2])
            if not firstLine then firstLine, firstY = RightOf(text, 40), y end
            y = y + TIMELINE.line
        else
            Pencilled(w, FONT.pencilSmall, 0, y, line[2])
            y = y + TIMELINE.day
        end
    end

    -- The notes in the margin, each with its leader to what it is about:
    -- { y of the note, where on the page what it is about ends (x, the
    -- middle of its line y) }.
    local notes = {
        { 48, "Their tags show on their tooltip.", w.sampleTagsEnd - 6, 59 },
        { 86, "Your note, in your own words.", RightOf(note, 0), 95 },
        { 128, "The story so far, written for you.", RightOf(story, 0, SAMPLE.w), 130 },
        { firstY, "Every meeting, day by day.", firstLine, firstY + 7 },
    }
    local A = Style.ACCENT
    for _, n in ipairs(notes) do
        local text = Style.Text(w, FONT.margin)
        text:SetPoint("TOPLEFT", NOTES.x, -SAMPLE.top - n[1])
        text:SetWidth(NOTES.w)
        text:SetText(n[2])
        local fx, fy = NOTES.x - 4, SAMPLE.top + n[1] + 7
        local tx, ty = RIGHT_X + n[3] + NOTES.gap, SAMPLE.top + n[4]
        Style.Curve(w, "ARTWORK", fx, fy, (fx + tx) / 2, fy, tx, ty, A, NOTES.leader, 1, 4)
    end

    -- What the diary does when they come back: the payoff.
    local promiseRule = w:CreateTexture(nil, "ARTWORK")
    promiseRule:SetSize(60, 1)
    promiseRule:SetPoint("TOPLEFT", RIGHT_X, -470)
    local INK = Style.INK
    promiseRule:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
    w.promise = Paragraph(w, FONT.body, RIGHT_W)
    w.promise:SetPoint("TOPLEFT", RIGHT_X, -482)
    w.promise:SetText("When they join your group or come into view again, the diary will tell you"
        .. " who they are.")
end

--------------------------------------------------------------------------
-- Construction and refresh
--------------------------------------------------------------------------

local function Refresh()
    local w = welcome
    local days = J.PencilDays()
    local n = ns.People.PencilledCount()
    local already = n == 0 and "" or (n == 1 and " One is there already." or (" %d are there already."):format(n))
    w.laterText:SetText(("Everyone you cross paths with is saved for %s.%s"):format(days, already))
    w.key:Refresh()
end

function J.BuildWelcome(panel, parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetAllPoints(parent)
    w:Hide()
    welcome = w
    panel.welcome = w

    BuildLeft(w)
    BuildRight(w)

    -- The key stops listening when the page or the book goes; a fight and
    -- the bindings changing elsewhere are the setter's own to hear.
    w:SetScript("OnHide", function(self) self.key:Stop() end)
    panel:HookScript("OnHide", function() w.key:Stop() end)
    return w
end

-- Shown while the diary is `empty`, hidden once someone is in it. The
-- list's own controls are the caller's to hide (UI/Journal/People.lua).
function J.RefreshWelcome(empty)
    if not welcome then return end
    welcome:SetShown(empty)
    if empty then Refresh() end
end
