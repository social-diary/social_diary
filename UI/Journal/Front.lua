-- The book's front matter (PRV-4, with PRV-1 and PRV-7 said out loud): the
-- second leaf, after the frontispiece (UI/Journal/Frontispiece.lua), in
-- front of Your Diary, without a ribbon of its own.
--
-- The left page has the bookplate, pasted in: whose diary this is, where
-- and when they began it and at what level. Under it, what is kept and
-- where: on this computer only, whether chat and your own road are kept
-- (read from the settings, and switched from here), and what it cannot
-- see. The frontispiece has told how strangers become entries; this page
-- does not say it again.
--
-- The right page is the contents, IN THIS BOOK: each of the three pages
-- shown by a cut-out of it at its own size, beside its ribbon's colour,
-- its name and a line about it. Your Diary by a close-up plate glued in as
-- its own are (UI/Journey/Plate.lua), on the map of where you stand, with a
-- sample road in ink and a margin note; People by the top of a person's
-- page; Recently nearby by three of its rows. They are samples, the same
-- Thex Theximus the frontispiece and the empty People page draw. A cut-out
-- or a name turns to its page, and so do the ribbons. Its own lifted
-- corner (UI/Journal/Corner.lua) turns to Your Diary (JRN-16), the end of
-- the introduction.
--
-- Shown, it has been read: the slip at login stops asking
-- (UI/Windows/Intro/Parcel.lua).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local BOOK = ns.UI.Journal.BOOK
local LEFT_X, LEFT_W, RIGHT_X = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X

-- The bookplate: where it is pasted and how big; its paper, a shade lighter
-- than the page; the engraved frame, a heavy rule and a light one inside it
-- (`inset` in, `alpha` ink); the lozenges in its corners; the glue that
-- soaked through at the corners; its shadow, `drop` down and right.
local PLATE = {
    x = LEFT_X + 15, y = 34, w = 206, h = 268,
    paper = { 0.90, 0.83, 0.66 }, grain = 0.10,
    rules = { { inset = 9, width = 2, alpha = 0.65 }, { inset = 14, width = 1, alpha = 0.45 } },
    lozenge = 7, lozengeInset = 10,
    glue = { size = 22, alpha = 0.07 },
    shadows = { { drop = 1, alpha = 0.22 }, { drop = 3, alpha = 0.08 } },
    -- What is printed on it, down from its top.
    exLibris = 36, flourish = 54, name = 72, nameW = 162, gap = 6, rule = 60,
}
-- What is kept, under the bookplate: where its rubric starts, the gap
-- under it, between its lines, and before the small print.
local KEPT = { y = 322, under = 6, row = 8, small = 14 }
-- The contents: the title's top; each page's cut-out (x, y, w, h in the
-- book, y down) and its entry beside it (x, y, w); the ribbon's swatch,
-- its size and the notch cut in its end, and how far right of it the words
-- start. The cut-outs are placed by hand, by the page's key; the page's
-- ribbon colour and name are its own (ns.UI.Journal.Ribbons, UI/Journal/
-- Pages.lua), and a ribbon page with no cut-out here fails tests/pages.lua
-- unless it says contents = false (the settings).
local CONTENTS = { title = 20, swatch = { 10, 30 }, notch = 7, indent = 20, about = 22 }
local CUTS = {
    journey = { x = RIGHT_X, y = 52, w = 192, h = 126, entry = { x = RIGHT_X + 318, y = 56, w = 140 } },
    people = { x = RIGHT_X + 152, y = 206, w = 300, h = 128, entry = { x = RIGHT_X, y = 214, w = 140 } },
    nearby = { x = RIGHT_X, y = 362, w = 300, h = 118, entry = { x = RIGHT_X + 318, y = 368, w = 140 } },
}
-- Your Diary's cut-out is one of its plates, mounted as its plates are: a
-- slot of UI/Journey/Plate.lua's, with four photo corners, turned a little.
-- On it, a sample road in ink through the art box (0..1 of it, x right, y
-- down), a pool where it lingered, a ring where it met someone and the pin
-- of a level reached; the margin note beside it, and its pencil leader
-- stopping `short` of the ring.
local JOURNEY = {
    slot = { t = -1.4, pad = 7, pc = 16, corners = { "tl", "tr", "bl", "br" } },
    road = { { 0.13, 0.81 }, { 0.32, 0.65 }, { 0.55, 0.45 }, { 0.76, 0.47 }, { 0.90, 0.24 } },
    ink = { 0.27, 0.16, 0.05 }, inkAlpha = 0.88, width = 1.6,
    pool = { at = 3, w = 18, h = 12, colour = { 0.68, 0.49, 0.10 }, alpha = 0.45 },
    ring = { at = 4, size = 7 },
    pin = { at = 5, size = 13 },
    note = { x = RIGHT_X + 208, y = 104, short = 9, alpha = 0.72 },
    -- Where it stands when the client does not say: Mulgore.
    fallbackMap = 1412,
}
-- A cut-out on its card: the card's stock, a shade lighter than the page;
-- its shadow, steps { right, down, alpha }; the photo corners, `size`
-- across, `out` past the card's corner, in `ink`, and strips `strip` wide
-- where corners cannot be cut; the glue at its edges, discs { x, y (0..1
-- of the card), size, alpha } in `tint`.
local CARD = {
    stock = { 0.894, 0.827, 0.663 },
    shadows = { { 0.6, 0.8, 0.45 }, { 1, 1.5, 0.22 } },
    corner = { size = 16, out = 5, ink = { 0.165, 0.114, 0.071 }, strip = 3 },
    glue = { tint = { 0.55, 0.38, 0.12 }, dabs = { { 0.18, 0, 26, 0.14 }, { 0.72, 1, 24, 0.10 }, { 0, 0.4, 22, 0.10 } } },
}
-- The People cut-out: the portrait, how far in the name and who line
-- start, the tags' line, the day's heading and its line.
local PERSON = { pad = 12, portrait = 44, indent = 68, who = 26, tags = 50, day = 82, line = 98, time = 44 }
-- The Recently nearby cut-out: its heading, the first row and the step to
-- the next; the columns in the page's order (class circle, level's right
-- edge, name, zone, Add). A 300 px card has no room for the subzone too.
local NEARBY = { pad = 12, first = 32, row = 22, circle = 12, level = 42, name = 50, zone = 168 }

local page

--------------------------------------------------------------------------
-- What it says
--------------------------------------------------------------------------

local WHERE_TEXT = "All data is kept local. Nothing is sent to anyone."

-- PRV-7 and what it cannot see, as it is: whose position the road is, and
-- the client's limits.
local function LimitsText()
    local road = ns.Setting("keepRoute")
        and "Your road is only your own position, kept for good."
        or "No road of yours is kept just now; what was kept stays until you delete it in the settings."
    return road .. " Who passes by is only seen with nameplates on."
end

-- "Begun in Mulgore / on 8 October 2026, / at level 6.", as far as it is
-- known.
local function BegunText(begun)
    if not begun or not begun.time then return "" end
    local zone = begun.zone ~= "" and begun.zone or nil
    local lines = {}
    if zone then lines[#lines + 1] = "Begun in " .. zone end
    local day = tonumber(date("%d", begun.time)) .. date(" %B %Y", begun.time)
    lines[#lines + 1] = (zone and "on " or "Begun on ") .. day .. (begun.level and "," or ".")
    if begun.level then lines[#lines + 1] = ("at level %d."):format(begun.level) end
    return table.concat(lines, "\n")
end

-- A card, link or plate that leads to another page (J.TurnTo).
local TurnTo = ns.UI.Journal.TurnTo

--------------------------------------------------------------------------
-- The bookplate
--------------------------------------------------------------------------

local function BuildPlate(parent)
    local P, INK = PLATE, Style.INK
    local plate = Style.PastedPlate(parent, P.x, P.y, P.w, P.h, P)

    plate.exLibris = Style.Text(plate, FONT.heading)
    plate.exLibris:SetPoint("TOP", 0, -P.exLibris)
    plate.exLibris:SetText("E X   L I B R I S")

    -- A flourish: a hairline either side of a red lozenge, lapis at its ends.
    local half = 44
    for _, side in ipairs({ -1, 1 }) do
        local line = plate:CreateTexture(nil, "ARTWORK")
        line:SetSize(half, 1)
        line:SetPoint("CENTER", plate, "TOP", side * (half / 2 + 8), -P.flourish)
        line:SetColorTexture(INK[1], INK[2], INK[3], 0.55)
        local dot = Style.Lozenge(plate, "ARTWORK", 3, Style.LAPIS)
        dot:SetPoint("CENTER", plate, "TOP", side * 8, -P.flourish)
    end
    Style.Lozenge(plate, "ARTWORK", 7, Style.RUBRIC):SetPoint("CENTER", plate, "TOP", 0, -P.flourish)

    plate.name = Style.Text(plate, FONT.title)
    plate.name:SetPoint("TOP", 0, -P.name)
    plate.name:SetWidth(P.nameW)
    plate.name:SetJustifyH("CENTER")

    plate.who = Style.Text(plate, FONT.faded)
    plate.who:SetPoint("TOP", plate.name, "BOTTOM", 0, -P.gap)
    plate.who:SetJustifyH("CENTER")

    plate.rule = plate:CreateTexture(nil, "ARTWORK")
    plate.rule:SetSize(P.rule, 1)
    plate.rule:SetPoint("TOP", plate.who, "BOTTOM", 0, -14)
    plate.rule:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)

    plate.begun = Style.Text(plate, FONT.body)
    plate.begun:SetPoint("TOP", plate.rule, "BOTTOM", 0, -12)
    plate.begun:SetJustifyH("CENTER")
    plate.begun:SetSpacing(3)

    return plate
end

-- Whose diary: the character logged in, as the client names them now, and
-- when they began it (Core/DB.lua's TouchOwnCharacter).
local function FillPlate(plate)
    local own = ns.ownGUID and ns.OwnCharacters()[ns.ownGUID] or {}
    local name = table.concat({ own.first or UnitName("player") or "", own.surname or "" }, " "):gsub("%s+$", "")
    plate.name:SetFontObject(FONT.title)
    plate.name:SetText(name:upper())
    if (plate.name:GetUnboundedStringWidth() or 0) > PLATE.nameW then
        plate.name:SetFontObject(FONT.titleSmall)
    end
    local race, class = ns.Plain(UnitRace("player")), ns.Plain(UnitClass("player"))
    local who = table.concat({ race or "", class or "" }, " "):gsub("^%s+", ""):gsub("%s+$", "")
    plate.who:SetText(who)
    plate.begun:SetText(BegunText(ns.ownGUID and ns.db.meta.begun[ns.ownGUID]))
end

--------------------------------------------------------------------------
-- What is kept, and where
--------------------------------------------------------------------------

-- A setting said as a row: its name on the left, and two links on the
-- right, the current one in plain ink.
local function Choice(parent, above, label, onSet)
    local row = {}
    row.label = Style.Text(parent, FONT.faded)
    row.label:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -KEPT.row)
    row.label:SetText(label)
    row.no = Style.Link(parent, FONT.body, function() onSet(false) end)
    row.no:SetText("Don\226\128\153t")
    row.no:SetPoint("RIGHT", parent, "TOPLEFT", LEFT_X + LEFT_W, 0)
    row.no:SetPoint("TOP", row.label, "TOP", 0, 2)
    local dot = Style.Text(parent, FONT.faded)
    dot:SetPoint("RIGHT", row.no, "LEFT", -5, 0)
    dot:SetText("\194\183")
    row.yes = Style.Link(parent, FONT.body, function() onSet(true) end)
    row.yes:SetText("Keep")
    row.yes:SetPoint("RIGHT", dot, "LEFT", -5, 0)
    return row
end

local function BuildKept(parent)
    local k = {}
    k.rubric = Style.Rubric(parent, LEFT_W)
    k.rubric:SetPoint("TOPLEFT", LEFT_X, -KEPT.y)
    k.rubric:SetText("Data retention settings", true)

    k.where = Style.Text(parent, FONT.body)
    k.where:SetPoint("TOPLEFT", k.rubric, "BOTTOMLEFT", 0, -KEPT.under)
    k.where:SetWidth(LEFT_W)
    k.where:SetSpacing(2)
    k.where:SetText(WHERE_TEXT)

    local function Refresh()
        ns.UI.RefreshFrontMatter()
        if ns.UI.Settings then ns.UI.Settings.Refresh() end
    end
    k.chat = Choice(parent, k.where, "Chat with them", function(on)
        if ns.Setting("storeChat") == on then return end
        ns.SetSetting("storeChat", on)
        Refresh()
    end)
    -- Your own road (PRV-7, JRN-17).
    k.route = Choice(parent, k.chat.label, "Your own road", function(on)
        if ns.Setting("keepRoute") == on then return end
        ns.JourneyCapture.SetEnabled(on)
        Refresh()
    end)

    k.limits = Style.Text(parent, FONT.small)
    k.limits:SetPoint("TOPLEFT", k.route.label, "BOTTOMLEFT", 0, -KEPT.small)
    k.limits:SetWidth(LEFT_W)
    k.limits:SetSpacing(2)
    return k
end

--------------------------------------------------------------------------
-- The cut-outs
--------------------------------------------------------------------------

-- A card glued into the book at x, y (book coordinates, y down), `w` by
-- `h`, held by photo corners (`corners`: "tl", "tr", "bl", "br"), or by
-- glue alone. It lies straight: what
-- is printed on it is text, which the client cannot always turn. A click
-- anywhere on it turns to `key`'s page.
local function Card(parent, x, y, w, h, corners, key)
    local C, INK = CARD, Style.INK
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(w, h)
    card:SetPoint("TOPLEFT", x, -y)
    card:SetFrameLevel(parent:GetFrameLevel() + 5)
    card:SetScript("OnClick", function() TurnTo(key) end)

    for i, s in ipairs(C.shadows) do
        local shadow = card:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
        shadow:SetPoint("TOPLEFT", s[1], -s[2])
        shadow:SetPoint("BOTTOMRIGHT", s[1], -s[2])
        shadow:SetColorTexture(INK[1], INK[2], INK[3], s[3])
    end
    local G = C.glue
    for _, dab in ipairs(G.dabs) do
        local g = card:CreateTexture(nil, "BACKGROUND", nil, -8)
        g:SetSize(dab[3], dab[3] * 0.5)
        g:SetPoint("CENTER", card, "TOPLEFT", dab[1] * w, -dab[2] * h)
        Style.Disc(g, G.tint[1], G.tint[2], G.tint[3], dab[4])
    end
    local stock = card:CreateTexture(nil, "BACKGROUND", nil, -4)
    stock:SetAllPoints()
    stock:SetColorTexture(C.stock[1], C.stock[2], C.stock[3], 1)
    -- Under the mouse its edge darkens, as a plate's does.
    card.hot = CreateFrame("Frame", nil, card)
    card.hot:SetAllPoints()
    Style.Hairline(card.hot, "BORDER", 0, 0.35)
    card.hot:Hide()
    card:SetScript("OnEnter", function() card.hot:Show() end)
    card:SetScript("OnLeave", function() card.hot:Hide() end)

    -- The photo corners: a square cut along its diagonal by moving one of
    -- its corners onto the next; two strips where the client cannot.
    local K = C.corner
    local VERTEX = Enum and Enum.VertexIndex or {}
    local UL, LL, UR, LR = VERTEX.UpperLeft or 1, VERTEX.LowerLeft or 2, VERTEX.UpperRight or 3, VERTEX.LowerRight or 4
    local CUT = { tl = { LR, -1 }, tr = { LL, 1 }, bl = { UR, -1 }, br = { UL, 1 } }
    local ANCHOR = { tl = "TOPLEFT", tr = "TOPRIGHT", bl = "BOTTOMLEFT", br = "BOTTOMRIGHT" }
    card.corners = 0
    for _, which in ipairs(corners) do
        local anchor = ANCHOR[which]
        local dx = which:find("l") == 2 and -K.out or K.out
        local dy = which:find("t") == 1 and K.out or -K.out
        local square = card:CreateTexture(nil, "OVERLAY", nil, 7)
        square:SetSize(K.size, K.size)
        square:SetPoint(anchor, dx, dy)
        square:SetColorTexture(K.ink[1], K.ink[2], K.ink[3], 1)
        if square.SetVertexOffset then
            local cut = CUT[which]
            square:SetVertexOffset(cut[1], cut[2] * K.size, 0)
        else
            square:SetSize(K.size, K.strip)
            local other = card:CreateTexture(nil, "OVERLAY", nil, 7)
            other:SetSize(K.strip, K.size)
            other:SetPoint(anchor, dx, dy)
            other:SetColorTexture(K.ink[1], K.ink[2], K.ink[3], 1)
        end
        card.corners = card.corners + 1
    end
    return card
end

-- Text on a card at x, y of it (y down).
local function Print(card, font, x, y, text)
    local t = Style.Text(card, font)
    t:SetPoint("TOPLEFT", x, -y)
    t:SetText(text)
    return t
end

-- People: the top of Thex's page, as it reads once they are in ink.
local function BuildPeopleCut(parent, cut)
    local P = PERSON
    local card = Card(parent, cut.x, cut.y, cut.w, cut.h, { "tl", "tr", "bl" }, "people")
    card.portrait = Style.Portrait(card, P.portrait)
    card.portrait:SetPoint("TOPLEFT", P.pad, -P.pad)
    card.portrait:SetCharacter({ race = "Troll", sex = 2, class = "HUNTER" })
    card.name = Print(card, FONT.titleSmall, P.indent, P.pad, "THEX THEXIMUS")
    card.who = Print(card, FONT.body, P.indent, P.pad + P.who,
        "Level 12 Troll Hunter  \194\183  |cff" .. Style.HEX.horde .. "Horde|r")
    local x = P.indent
    for _, tag in ipairs({ "helper", "friend" }) do
        local chip = Style.TagChip(card)
        chip:SetTag(tag)
        chip:SetPoint("TOPLEFT", x, -P.pad - P.tags)
        x = x + chip:GetWidth() + 5
    end
    card.day = Print(card, FONT.heading, P.pad, P.day, "TODAY")
    Print(card, FONT.small, P.pad, P.line + 2, "21:40")
    card.line = Print(card, FONT.body, P.pad + P.time, P.line, "Quested together for 1h 05m")
    return card
end

-- Recently nearby: three of a day's rows, Add beside each.
local function BuildNearbyCut(parent, cut)
    local N = NEARBY
    local card = Card(parent, cut.x, cut.y, cut.w, cut.h, {}, "nearby")
    card.day = Print(card, FONT.heading, N.pad, N.pad, "TODAY")
    local count = Style.Text(card, FONT.small)
    count:SetPoint("TOPRIGHT", -N.pad, -N.pad)
    count:SetText("48 people")
    card.rows = {}
    local rows = {
        { "Bram Redfen", 9, "The Barrens", "WARRIOR" },
        { "Fenwick Hale", 15, "The Barrens", "PRIEST" },
        { "Sage Thornhoof", 11, "The Barrens", "SHAMAN" },
    }
    for i, r in ipairs(rows) do
        local y = N.first + (i - 1) * N.row
        local circle = card:CreateTexture(nil, "ARTWORK")
        circle:SetSize(N.circle, N.circle)
        circle:SetPoint("TOPLEFT", N.pad, -y - 3)
        Style.ClassIconOrInk(circle, r[4])
        local level = Style.Text(card, FONT.small)
        level:SetPoint("TOPRIGHT", card, "TOPLEFT", N.level, -y - 2)
        level:SetText(tostring(r[2]))
        local name = Print(card, FONT.body, N.name, y, r[1])
        Print(card, FONT.small, N.zone, y + 2, r[3])
        local add = Style.Link(card, FONT.body, function() TurnTo("nearby") end)
        add:SetText("+ Add")
        add:SetPoint("TOPRIGHT", -N.pad, -y + 1)
        card.rows[i] = name
    end
    return card
end

-- Your Diary: a close-up plate, as its own are glued in, on the map of
-- where you stand, with the sample road drawn over it on the page through
-- the plate's own transform, so it turns with the card.
local function BuildJourneyCut(parent, cut)
    if not ns.UI.JourneyPlate then return nil end
    local J = JOURNEY
    local slot = { x = cut.x, y = cut.y, w = cut.w, h = cut.h }
    for k, v in pairs(J.slot) do slot[k] = v end
    local plate = ns.UI.JourneyPlate(parent, slot)
    plate:SetClick(function() TurnTo("journey") end)

    -- Over the card: the road, its marks, the leader.
    local over = CreateFrame("Frame", nil, parent)
    over:SetAllPoints(parent)
    over:SetFrameLevel(parent:GetFrameLevel() + 20)
    plate.over = over

    plate.note = Style.Text(parent, FONT.noteWritten)
    plate.note:SetPoint("TOPLEFT", J.note.x, -J.note.y)
    plate.note:SetTextColor(Style.ACCENT[1], Style.ACCENT[2], Style.ACCENT[3])
    plate.note:SetText("Thex")
    plate.noteWhat = Style.Text(parent, FONT.small)
    plate.noteWhat:SetPoint("TOPLEFT", plate.note, "BOTTOMLEFT", 0, -2)
    plate.noteWhat:SetText("40 min together")
    return plate
end

-- Draws it, once: where you stand now, or the fallback's middle.
local function DrawJourneyCut(plate)
    if not plate or plate.drawn then return end
    local J = JOURNEY
    local where = ns.Where()
    local mapID = where.mapID or J.fallbackMap
    local s = plate.slot
    local aw, ah = s.w - 2 * s.pad, s.h - 2 * s.pad
    local Plate = ns.UI.JourneyPlate
    local window = Plate.Window(mapID, where.mapID and where.x or 0.5, where.mapID and where.y or 0.5, aw, ah)
    plate:Draw(ns.JourneyRecap.Sheet(nil, mapID), { kind = "level", level = 4, from = 0, to = 0 }, window,
        { moments = {}, fights = {}, cap = Plate.Share(s) })
    plate:Show()

    -- The art box's 0..1 to the page, through the plate's window and turn.
    local wx0, wy0, wx1, wy1 = window[1], window[2], window[3], window[4]
    local function At(u, v) return plate:OnPage(wx0 + u * (wx1 - wx0), wy0 + v * (wy1 - wy0)) end
    local pts = {}
    for i, p in ipairs(J.road) do pts[i] = { At(p[1], p[2]) } end
    if #pts == 0 or not pts[1][1] then return end

    -- The road: smoothed through the midpoints, as a pen would go.
    local over = plate.over
    local px, py = pts[1][1], pts[1][2]
    for i = 2, #pts - 1 do
        local mx, my = (pts[i][1] + pts[i + 1][1]) / 2, (pts[i][2] + pts[i + 1][2]) / 2
        Style.Curve(over, "ARTWORK", px, py, pts[i][1], pts[i][2], mx, my, J.ink, J.inkAlpha, J.width, 8)
        px, py = mx, my
    end
    local last = pts[#pts]
    Style.Stroke(over, "ARTWORK", px, py, last[1], last[2], J.ink, J.inkAlpha, J.width)

    local P = J.pool
    local pool = over:CreateTexture(nil, "BORDER")
    pool:SetSize(P.w, P.h)
    pool:SetPoint("CENTER", over, "TOPLEFT", pts[P.at][1], -pts[P.at][2])
    Style.Disc(pool, P.colour[1], P.colour[2], P.colour[3], P.alpha)

    local R = J.ring
    local rx, ry = pts[R.at][1], pts[R.at][2]
    -- In ink, as a plate marks time together.
    Style.HandRing(over, "OVERLAY", rx, ry, { w = R.size, h = R.size, overshoot = 0, wobble = 0, alpha = 0.9,
        steps = 12, colour = Style.INK_STRONG })
    local N = J.note
    local nx, ny = N.x - 4, N.y + 8
    local dx, dy = rx - nx, ry - ny
    local d = math.sqrt(dx * dx + dy * dy)
    if d > N.short then
        local G = Style.GRAPHITE
        Style.Stroke(over, "ARTWORK", nx, ny, rx - dx / d * N.short, ry - dy / d * N.short, G, N.alpha, 1)
    end

    local pin = over:CreateTexture(nil, "OVERLAY")
    local size = J.pin.size
    pin:SetSize(size, size)
    pin:SetPoint("CENTER", over, "TOPLEFT", pts[J.pin.at][1], -pts[J.pin.at][2])
    Style.Disc(pin, Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3], 1)
    local four = Style.Text(over, FONT.tag)
    four:SetPoint("CENTER", pin, "CENTER", 0, 0)
    four:SetText("4")
    plate.drawn = true
end

-- An entry of the contents: the ribbon's swatch with its notch, the page's
-- name as a link, and a line about it.
local function Entry(parent, at, colour, label, key)
    local C, P = CONTENTS, Style.PAPER
    local e = {}
    local cloth = Style.RIBBONS[colour].cloth
    local swatch = parent:CreateTexture(nil, "ARTWORK", nil, 0)
    swatch:SetSize(C.swatch[1], C.swatch[2])
    swatch:SetPoint("TOPLEFT", at.x, -at.y)
    swatch:SetColorTexture(cloth[1], cloth[2], cloth[3], 1)
    local notch = Style.Lozenge(parent, "ARTWORK", C.notch, P, 1)
    notch:SetPoint("CENTER", swatch, "BOTTOM", 0, -1)

    e.link = Style.Link(parent, FONT.body, function() TurnTo(key) end)
    e.link:SetText(label)
    e.link:SetPoint("TOPLEFT", at.x + C.indent, -at.y + 2)
    e.about = Style.Text(parent, FONT.faded)
    e.about:SetPoint("TOPLEFT", at.x + C.indent, -at.y - C.about)
    e.about:SetWidth(at.w - C.indent)
    e.about:SetSpacing(2)
    return e
end

-- Each cut-out's maker, and the line about its page (Recently nearby's is
-- written as the page refreshes: how many are pencilled in).
local CUT_BUILDERS = { journey = BuildJourneyCut, people = BuildPeopleCut, nearby = BuildNearbyCut }
local ABOUT = {
    journey = "Your own road, level by level, and who you met on it.",
    people = "Everyone you ink in, with your notes and every meeting.",
}

-- The ribbon pages in their order, each with a cut-out here: its entry,
-- the line about it, then the cut-out.
local function BuildContents(parent)
    local c = {}
    c.title = Style.Text(parent, FONT.page)
    c.title:SetPoint("TOPLEFT", RIGHT_X, -CONTENTS.title)
    c.title:SetText("IN THIS BOOK")

    for _, ribbon in ipairs(ns.UI.Journal.Ribbons()) do
        local key, cut = ribbon.key, CUTS[ribbon.key]
        if cut then
            local e = Entry(parent, cut.entry, ribbon.colour, ribbon.label, key)
            if ABOUT[key] then e.about:SetText(ABOUT[key]) end
            e.cut = CUT_BUILDERS[key](parent, cut)
            c[key] = e
        end
    end
    return c
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

local function BuildPage(parent)
    page = { parent = parent }
    page.plate = BuildPlate(parent)
    page.kept = BuildKept(parent)
    page.contents = BuildContents(parent)
    -- The end of the introduction: on to Your Diary.
    page.corner = ns.UI.Journal.PageCorner(parent, function()
        ns.SetSetting("introDone", true)
        TurnTo("journey")
    end)
    return page
end

-- Fills it in from the settings and the character logged in. Shown, it
-- has been read: the slip stops asking.
function ns.UI.RefreshFrontMatter()
    if not page then return end
    FillPlate(page.plate)

    local k = page.kept
    local chat = ns.Setting("storeChat") == true
    k.chat.yes:SetCurrent(chat)
    k.chat.no:SetCurrent(not chat)
    local route = ns.Setting("keepRoute") == true
    k.route.yes:SetCurrent(route)
    k.route.no:SetCurrent(not route)
    k.limits:SetText(LimitsText())

    local c = page.contents
    c.nearby.about:SetText(("Everyone still in pencil from the last %s. Ink them in from here.")
        :format(ns.UI.Journal.PencilDays()))

    if ns.UI.JournalShowing("front") then
        DrawJourneyCut(c.journey.cut)
        ns.SetSetting("frontRead", true)
        if ns.UI.Parcel and ns.UI.Parcel.HideSlip then ns.UI.Parcel.HideSlip() end
    end
end

-- Test hook: the front matter's page.
function ns.UI.FrontMatter()
    return page
end

-- The second leaf, without a ribbon (UI/Journal/Pages.lua).
ns.UI.Journal.RegisterPage("front", {
    flyleaf = 1, buildOrder = 30,
    build = function(container) BuildPage(container) end,
    refresh = function() ns.UI.RefreshFrontMatter() end,
})
