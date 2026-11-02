-- An empty diary's People page: how someone gets in, and where they will
-- be once they are.
--
-- The left page, in place of the search and the list, says the three ways
-- in, each drawn: the right-click menu with Remember this ringed in red; the
-- Remember this key, which ships unbound, so it can be bound right here; and
-- Recently nearby, with how many are pencilled in already. The right page,
-- in place of "Choose someone", is bare but for one paper strip taped on
-- it (UI/Paper/Strip.lua): where the diary's entries will show up.
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
-- The strip on the right page: what it says, how far down its top lies
-- (in the upper third, centred across the page), the turn it lies at
-- (degrees) and the seed it is cut by, the same every time.
local STRIP = { words = "This is where your diary entries will show up", top = 160, tilt = -1.1,
    seed = "welcome" }

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
-- The right page: a strip taped in
--------------------------------------------------------------------------

-- The page's one line is written as a strip's name, in the diary's hand
-- (FONT.noteWritten) and its strong ink, with nothing under it: a name
-- takes no wrap and no small hand, so it reads as one line written in.
-- It names no one, so like a stranger's slip it opens nothing and has no
-- hover. Laid on each refresh, as the strip reads Flat paper only as it
-- is laid.
local function LayRight(w)
    local strip = w.strip
    strip:SetNote({ name = STRIP.words, strong = true, seed = STRIP.seed, tilt = STRIP.tilt, light = true })
    -- Laid once to learn its width, then again centred on the page.
    local width = strip:Layout(0, STRIP.top, RIGHT_W)
    strip:Layout(RIGHT_X + math.floor((RIGHT_W - width) / 2), STRIP.top, RIGHT_W)
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
    LayRight(w)
end

function J.BuildWelcome(panel, parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetAllPoints(parent)
    w:Hide()
    welcome = w
    panel.welcome = w

    BuildLeft(w)
    w.strip = ns.UI.PaperStrip(w)

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
