-- The parcel wrapped (PRV-4): brown paper over the book, its grain, light
-- and folds, the sender and the address, the stamp and its postmark, the
-- twine and its bow, the label saying what is inside, the maker's wax seal
-- (a click on it tears the paper), and the links under it on the game
-- world. Built once (Parcel.BuildWrapped); laid for the maker at each
-- showing (Parcel.LayWrapped). The look tables, fonts and kit are
-- UI/Windows/Intro/Scene.lua's, which lists the state shared on
-- ns.UI.Parcel; torn open is Torn.lua; the host Parcel.lua.

local addonName, ns = ...
local L = ns.L

local Style = ns.Style
local FONT = Style.FONT
local Parcel = ns.UI.Parcel

local SCENE = Parcel.SCENE
local KRAFT = Parcel.KRAFT
local PARCEL = Parcel.PARCEL
local TWINE = Parcel.TWINE
local BOW = Parcel.BOW
local SEAL = Parcel.SEAL
local WAX = Parcel.WAX
local STAMP = Parcel.STAMP
local POSTMARK = Parcel.POSTMARK
local SENDER = Parcel.SENDER
local ADDRESS = Parcel.ADDRESS
local LABEL = Parcel.LABEL
local LINK = Parcel.LINK
local MAKERS = Parcel.MAKERS
local PF = Parcel.PF
local Rad = Parcel.Rad
local Turn = Parcel.Turn
local Cover = Parcel.Cover
local LightLink = Parcel.LightLink
local Cog = Parcel.Cog
local Day = Parcel.Day

--------------------------------------------------------------------------
-- Wrapped
--------------------------------------------------------------------------

function Parcel.BuildWrapped(host, S)
    local F = Cover(host)
    host.wrapped = F
    local P = PARCEL
    local px, py, pw, ph = P.x, P.y, P.w, P.h
    local marks = { gnome = {}, goblin = {} }
    host.marks = marks
    local function Mark(maker, region) marks[maker][#marks[maker] + 1] = region end
    local SHADE = { KRAFT.ink[1], KRAFT.ink[2], KRAFT.ink[3] }

    -- Its shadow, the paper and its grain.
    for i, s in ipairs(P.shadows) do
        S.Shadow(S.Rect(F, "BACKGROUND", -9 + i, px + s[1] - s[3], py + s[2] - s[3], pw + 2 * s[3], ph + 2 * s[3],
            { 0, 0, 0, s[4] }))
    end
    S.Rect(F, "BACKGROUND", -5, px, py, pw, ph, KRAFT.paper)
    local grain = Style.Art("grain")
    if grain then
        local fibres = S.Rect(F, "BACKGROUND", -4, px, py, pw, ph)
        fibres:SetTexture(grain)
        fibres:SetTexCoord(0.05, 0.95, 0.10, 0.40)
        fibres:SetVertexColor(0.35, 0.22, 0.10)
        fibres:SetAlpha(P.fibres * Style.GrainStrength())
    end
    -- The light on it, from the top left.
    Style.Gradient(S.Rect(F, "BACKGROUND", -3, px, py, pw, ph), "HORIZONTAL",
        { 1, 0.92, 0.78, 0.16 }, { SHADE[1], SHADE[2], SHADE[3], 0.14 })
    Style.Gradient(S.Rect(F, "BACKGROUND", -3, px, py, pw, ph), "VERTICAL",
        { SHADE[1], SHADE[2], SHADE[3], 0.10 }, { 1, 0.92, 0.78, 0.08 })
    -- Folded over the book's edges, and the edges themselves.
    local D = P.folds
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px, py, D.left[1], ph), "HORIZONTAL", SHADE[1], SHADE[2], SHADE[3],
        D.left[2], 0)
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px + pw - D.right[1], py, D.right[1], ph), "HORIZONTAL",
        SHADE[1], SHADE[2], SHADE[3], 0, D.right[2])
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px, py, pw, D.top[1]), "VERTICAL", 1, 0.92, 0.78, 0, D.top[2])
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px, py + ph - D.bottom[1], pw, D.bottom[1]), "VERTICAL",
        SHADE[1], SHADE[2], SHADE[3], D.bottom[2], 0)
    local e = P.edge[1]
    local light, dark = { 1, 0.9, 0.75, P.edge[2] }, { SHADE[1], SHADE[2], SHADE[3], P.edge[3] }
    S.Rect(F, "BACKGROUND", -1, px, py, pw, e, light)
    S.Rect(F, "BACKGROUND", -1, px, py + e, e, ph - e, light)
    S.Rect(F, "BACKGROUND", -1, px + e, py + ph - e, pw - e, e, dark)
    S.Rect(F, "BACKGROUND", -1, px + pw - e, py + e, e, ph - 2 * e, dark)
    local c = P.crease
    S.Stroke(F, "BORDER", 0, px + c[1], py + c[2], px + c[3], py + c[4], SHADE, c[6], c[5])

    -- The sender, printed, and the address in the maker's hand (if the
    -- maker writes one).
    host.sender = { Style.Text(F, PF.print), Style.Text(F, PF.print) }
    for i, text in ipairs(host.sender) do text:SetAlpha(SENDER.alpha[i]) end
    host.address = { Style.Text(F, PF.hand), Style.Text(F, PF.hand) }

    -- The stamp, the maker's mark on it, and the postmark half over it.
    local M = STAMP
    local sx, sy = px + M.x, py + M.y
    local scx, scy = sx + M.w / 2, sy + M.h / 2
    local turn = Rad(M.turn)
    S.Shadow(S.Rect(F, "BORDER", 1, sx + M.shadow[1], sy + M.shadow[2], M.w, M.h,
        { SHADE[1], SHADE[2], SHADE[3], M.shadow[3] }, turn, scx, scy))
    S.Rect(F, "BORDER", 2, sx, sy, M.w, M.h, M.paper, turn, scx, scy)
    for _, y in ipairs({ sy, sy + M.h }) do
        for i = 1, M.bites do
            local bx, by = Turn(sx + (i - 0.5) * M.w / M.bites, y, turn, scx, scy)
            S.Disc(F, "BORDER", 3, bx, by, M.bite, KRAFT.paper)
        end
    end
    host.stampPicture = S.Rect(F, "BORDER", 4, sx + M.inset, sy + M.inset, M.w - 2 * M.inset, M.h - 2 * M.inset,
        WAX.gnome.dark, turn, scx, scy)
    host.stampCog = Cog(S, F, "BORDER", 5, scx, scy, M.cog, M.paper, WAX.gnome.dark, turn, scx, scy)
    for _, part in ipairs(host.stampCog) do Mark("gnome", part) end
    host.stampLetter = Style.Text(F, PF.stamp)
    host.stampLetter:SetText("G")
    Mark("goblin", host.stampLetter)

    local K = POSTMARK
    local kx, ky = px + K.x + K.size / 2, py + K.y + K.size / 2
    local kturn = Rad(K.turn)
    local r = K.size / 2 - 1
    for i = 1, K.strokes do
        local a, b = 2 * math.pi * (i - 1) / K.strokes, 2 * math.pi * i / K.strokes
        S.Stroke(F, "BORDER", 6, kx + r * math.cos(a), ky + r * math.sin(a), kx + r * math.cos(b),
            ky + r * math.sin(b), K.ink, K.ring, 1.5)
    end
    local C = K.cancel
    for i = 0, C.lines - 1 do
        local x1, y1 = Turn(px + K.x + C.x, py + K.y + C.y + i * C.step, kturn, kx, ky)
        local x2, y2 = Turn(px + K.x + C.x + C.w, py + K.y + C.y + i * C.step, kturn, kx, ky)
        S.Stroke(F, "BORDER", 6, x1, y1, x2, y2, K.ink, C.alpha, 1.2)
    end
    host.postmark = {}
    for i = 1, 3 do host.postmark[i] = Style.Text(F, PF.postmark) end

    -- The twine both ways, and the bow on the knot.
    local W = TWINE
    local tx, ty = px + W.x, py + W.y
    local inset = (W.width - W.coreWidth) / 2
    for _, strip in ipairs({ { tx, py - 2, W.width, ph + 4, true }, { px - 2, ty, pw + 4, W.width } }) do
        local x, y, w, h, upright = strip[1], strip[2], strip[3], strip[4], strip[5]
        S.Shadow(S.Rect(F, "ARTWORK", 0, x + W.shadow[1], y + W.shadow[2], w, h,
            { SHADE[1], SHADE[2], SHADE[3], W.shadow[3] }))
        S.Rect(F, "ARTWORK", 1, x, y, w, h, W.edge)
        if upright then
            S.Rect(F, "ARTWORK", 2, x + inset, y, W.coreWidth, h, W.core)
        else
            S.Rect(F, "ARTWORK", 2, x, y + inset, w, W.coreWidth, W.core)
        end
    end
    local B = BOW
    for _, pass in ipairs({ { W.bow, B.outer, 3 }, { W.core, B.inner, 4 } }) do
        local colour, width, sublevel = pass[1], pass[2], pass[3]
        for _, curve in ipairs(B.curves) do
            S.Curve(F, "ARTWORK", sublevel, curve, px + B.x, py + B.y, B.steps, colour, width)
        end
        for _, tail in ipairs(B.tails) do
            S.Stroke(F, "ARTWORK", sublevel, px + B.x + tail[1], py + B.y + tail[2], px + B.x + tail[3],
                py + B.y + tail[4], colour, 1, width)
        end
    end

    -- The label, pasted on: paper, an inked frame and the diary's name.
    local A = LABEL
    local lx, ly = px + (pw - A.w) / 2, py + A.y
    for i, s in ipairs(A.shadows) do
        S.Shadow(S.Rect(F, "ARTWORK", 5 + i, lx + s[1] - s[3], ly + s[2] - s[3], A.w + 2 * s[3], A.h + 2 * s[3],
            { SHADE[1], SHADE[2], SHADE[3], s[4] }))
    end
    S.Rect(F, "ARTWORK", 7, lx, ly, A.w, A.h, A.paper)
    local o, ink = A.outline, { Style.INK[1], Style.INK[2], Style.INK[3], A.alpha }
    S.Rect(F, "OVERLAY", -2, lx + o, ly + o, A.w - 2 * o, 1, ink)
    S.Rect(F, "OVERLAY", -2, lx + o, ly + A.h - o - 1, A.w - 2 * o, 1, ink)
    S.Rect(F, "OVERLAY", -2, lx + o, ly + o, 1, A.h - 2 * o, ink)
    S.Rect(F, "OVERLAY", -2, lx + A.w - o - 1, ly + o, 1, A.h - 2 * o, ink)
    local label = { title = Style.Text(F, FONT.page) }
    label.title:SetText("SOCIAL DIARY")
    S.Line(label.title, lx + A.w / 2, ly + A.title, "CENTER")
    host.label = label

    -- The seal on the knot: a button, as a click on it tears the paper.
    -- Its parts are coloured for the maker as it is laid.
    local E = SEAL
    local seal = CreateFrame("Button", nil, F)
    seal:SetSize(E.size, E.size)
    seal:SetPoint("TOPLEFT", host, "TOPLEFT", px + E.x - SCENE.left, -(py + E.y - SCENE.top))
    host.seal = seal
    local cx, cy = px + E.x + E.size / 2, py + E.y + E.size / 2
    local WHITE = { 1, 1, 1 }
    seal.shadow = S.Shadow(S.Disc(seal, "ARTWORK", 0, cx + E.shadow[1], cy + E.shadow[2], E.rim, { 0, 0, 0 },
        E.shadow[3]))
    seal.rim = S.Disc(seal, "ARTWORK", 1, cx, cy, E.rim, WHITE)
    seal.body = S.Disc(seal, "ARTWORK", 2, cx, cy, E.body, WHITE)
    seal.ring = S.Disc(seal, "ARTWORK", 3, cx, cy, E.ring, WHITE)
    seal.ringIn = S.Disc(seal, "ARTWORK", 4, cx, cy, E.ringIn, WHITE)
    local lit = E.lit
    seal.lit = S.Texture(seal, "ARTWORK", 5)
    seal.lit.round = Style.Disc(seal.lit, 1, 1, 1, lit[6])
    S.Box(seal.lit, cx + lit[1] - lit[3] / 2, cy + lit[2] - lit[4] / 2, lit[3], lit[4], Rad(lit[5]),
        cx + lit[1], cy + lit[2])
    seal.cog = Cog(S, seal, "OVERLAY", 0, cx, cy, E.cog, WHITE, WHITE)
    for _, part in ipairs(seal.cog) do Mark("gnome", part) end
    seal.dots = {}
    for i = 1, E.coin.dots do
        local a = 2 * math.pi * i / E.coin.dots
        seal.dots[i] = S.Disc(seal, "OVERLAY", 0, cx + E.coin.r * math.cos(a), cy + E.coin.r * math.sin(a),
            E.coin.dot, WHITE)
        Mark("goblin", seal.dots[i])
    end
    seal.letter = Style.Text(seal, PF.seal)
    seal.letter:SetText("G")
    S.Line(seal.letter, cx, cy, "CENTER")
    Mark("goblin", seal.letter)
    seal.hover = S.Disc(seal, "OVERLAY", 3, cx, cy, E.body, { 1, 0.95, 0.85 }, E.hover)
    seal.hover:Hide()
    seal:SetScript("OnEnter", function(self) self.hover:Show() end)
    seal:SetScript("OnLeave", function(self) self.hover:Hide() end)
    seal:SetScript("OnClick", function() host:Tear() end)

    -- The links under it, on the game world.
    local y = py + ph + P.links
    host.tear = LightLink(F, L["Tear it open"], LINK.hot, function() host:Tear() end)
    host.tear:SetPoint("LEFT", host, "TOPLEFT", px + 4 - SCENE.left, -(y - SCENE.top))
    host.later = LightLink(F, L["Later"], LINK.base, function()
        Parcel.later = true
        ns.UI.Parcel.HideSlip(false)
    end)
    host.later:SetPoint("LEFT", host.tear, "RIGHT", 14, 0)
end

-- The maker's marks and words, today's postmark, the seal's wax.
function Parcel.LayWrapped(host, S, maker)
    local m, wax = MAKERS[maker], WAX[maker]
    for key, list in pairs(host.marks) do
        for _, region in ipairs(list) do region:SetShown(key == maker) end
    end
    local px, py = PARCEL.x, PARCEL.y
    local textTurn = host.turnsText

    for i, text in ipairs(host.sender) do
        text:SetText(m.sender[i])
        S.Line(text, px + SENDER.x, py + SENDER.y + (i - 1) * SENDER.step, "LEFT")
    end
    host.address[2]:SetFontObject(m.aside and PF.handSmall or PF.hand)
    for i, text in ipairs(host.address) do
        text:SetText(m.address[i] or "")
        text:SetShown(m.address[i] ~= nil)
        if m.address[i] then S.Line(text, px + ADDRESS.x, py + ADDRESS.y + (i - 1) * ADDRESS.step, "LEFT") end
    end

    local seal = host.seal
    S.Paint(seal.rim, wax.dark)
    S.Paint(seal.body, wax.wax)
    S.Paint(seal.ring, wax.dark)
    S.Paint(seal.ringIn, wax.wax)
    S.Paint(seal.lit, wax.lit, SEAL.lit[6])
    for i, part in ipairs(seal.cog) do S.Paint(part, i == #seal.cog and wax.wax or wax.dark) end
    for _, dot in ipairs(seal.dots) do S.Paint(dot, wax.dark) end
    seal.letter:SetTextColor(wax.dark[1], wax.dark[2], wax.dark[3])

    local M = STAMP
    local scx, scy = px + M.x + M.w / 2, py + M.y + M.h / 2
    S.Paint(host.stampPicture, wax.dark)
    S.Paint(host.stampCog[#host.stampCog], wax.dark)
    S.Line(host.stampLetter, scx, scy, "CENTER", textTurn and Rad(M.turn), scx, scy)

    local K = POSTMARK
    local kx, ky = px + K.x + K.size / 2, py + K.y + K.size / 2
    local lines = {}
    for i, line in ipairs(m.postmark) do lines[i] = line end
    lines[#lines + 1] = Day()
    for i, text in ipairs(host.postmark) do
        text:SetText(lines[i] or "")
        text:SetShown(lines[i] ~= nil)
        if lines[i] then
            S.Line(text, kx, ky + (i - (#lines + 1) / 2) * K.step, "CENTER", textTurn and Rad(K.turn), kx, ky)
        end
    end
end
