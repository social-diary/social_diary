-- The parcel torn open (PRV-4): what is left of the paper, its flaps torn
-- back, the twine cut and lying loose, the closed book with its ribbons out
-- of the foot, the label torn aside, and the diary's note beside the book,
-- a loose sheet. Built once (Parcel.BuildTorn); the label and the note laid
-- at each showing (Parcel.LayLabel, Parcel.LayNote). The look tables,
-- fonts and kit are UI/Windows/Intro/Scene.lua's, which lists the state
-- shared on ns.UI.Parcel; wrapped is Wrapped.lua; the host Parcel.lua.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Parcel = ns.UI.Parcel

local SCENE = Parcel.SCENE
local KRAFT = Parcel.KRAFT
local TWINE = Parcel.TWINE
local LABEL = Parcel.LABEL
local PAPER = Parcel.PAPER
local FLAPS = Parcel.FLAPS
local LOOSE = Parcel.LOOSE
local TORN_LABEL = Parcel.TORN_LABEL
local BOOK = Parcel.BOOK
local RIBBONS = Parcel.RIBBONS
local NOTE = Parcel.NOTE
local CREASE = Parcel.CREASE
local HELLO = Parcel.HELLO
local BODY = Parcel.BODY
local Pencilled = Parcel.Pencilled
local PF = Parcel.PF
local Rad = Parcel.Rad
local Turn = Parcel.Turn
local Cover = Parcel.Cover

--------------------------------------------------------------------------
-- Torn open
--------------------------------------------------------------------------

-- The ribbons out of the foot of the closed book, each turned a little:
-- cloth with darker edges, a sheen, and a notch cut in its end. Drawn on
-- the book, in its coordinates. Where corners cannot move, a plain strip.
-- book.ribbons: each one's cloth, by its page's key (for the tests).
local function Ribbons(S, book)
    local R = RIBBONS
    local half = R.width / 2
    book.ribbons = {}
    for _, page in ipairs(ns.UI.Journal.Ribbons()) do
        local ribbon = R.at[page.key]
        if ribbon then
            local look = Style.RIBBONS[page.colour]
            local x, hang, phi = ribbon[1], ribbon[2], math.rad(ribbon[3])
            local c, s = math.cos(phi), math.sin(phi)
            -- u across from its middle, v down from its top; turned clockwise.
            local function At(u, v) return x + half + u * c - v * s, R.top + u * s + v * c end
            local function Foot(u) return hang - R.notch * (1 - math.abs(u) / half) end
            local strips = {}
            local function Strip(sublevel, u1, u2, colour, alpha, dx, dy)
                S.made = S.made + 1
                local texture = book:CreateTexture(nil, "OVERLAY", nil, sublevel)
                texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
                local ax, ay = At(u1, 0)
                local bx, by = At(u2, 0)
                local cx, cy = At(u2, Foot(u2))
                local ex, ey = At(u1, Foot(u1))
                dx, dy = dx or 0, dy or 0
                texture.bent = Style.Quad(texture, book, ax + dx, ay + dy, bx + dx, by + dy, cx + dx, cy + dy, ex + dx, ey + dy)
                strips[#strips + 1] = texture
                return texture
            end
            local sh, sheen = R.shadow, look.sheen or { 1, 0.6, 0.55 }
            S.Shadow(Strip(-4, -half, 0, { 0, 0, 0 }, sh[3], sh[1], sh[2]))
            S.Shadow(Strip(-4, 0, half, { 0, 0, 0 }, sh[3], sh[1], sh[2]))
            local body = Strip(-3, -half, 0, look.cloth)
            Strip(-3, 0, half, look.cloth)
            Strip(-2, -half, -half + R.edge, look.edge)
            Strip(-2, half - R.edge, half, look.edge)
            Strip(-1, -half + R.sheen[1], -half + R.sheen[1] + R.sheen[2], sheen, R.sheen[3])
            if not body.bent then
                for _, strip in ipairs(strips) do
                    strip:Hide()
                    strip.never = true
                end
                body:Show()
                body.never = nil
                body:ClearAllPoints()
                body:SetPoint("TOPLEFT", book, "TOPLEFT", x, -R.top)
                body:SetSize(R.width, hang)
            end
            book.ribbons[page.key] = body
        end
    end
end

function Parcel.BuildTorn(host, S)
    local F = Cover(host)
    host.torn = F
    host.edges = {}
    local SHADE = KRAFT.ink

    -- What is left of the paper: a quad inside the tear, its shadow, the
    -- light on it, and the tear all round.
    local P = PAPER
    local corners = {}
    for i, c in ipairs(P.corners) do corners[i] = { P.x + c[1] * P.w, P.y + c[2] * P.h } end
    local function Over(texture, dx, dy, grow)
        local g = grow or 0
        local a, b, cc, d = corners[1], corners[2], corners[3], corners[4]
        return S.Quad(texture, a[1] + dx - g, a[2] + dy - g, b[1] + dx + g, b[2] + dy - g,
            cc[1] + dx + g, cc[2] + dy + g, d[1] + dx - g, d[2] + dy + g)
    end
    for i, s in ipairs(P.shadows) do
        Over(S.Shadow(S.Texture(F, "BACKGROUND", -9 + i, { 0, 0, 0, s[4] })), s[1], s[2], s[3])
    end
    Over(S.Texture(F, "BACKGROUND", -5, KRAFT.paper), 0, 0)
    local light = S.Texture(F, "BACKGROUND", -4)
    Style.Gradient(light, "HORIZONTAL", { 1, 0.92, 0.78, 0.14 }, { SHADE[1], SHADE[2], SHADE[3], 0.12 })
    Over(light, 0, 0)
    for i, side in ipairs(P.sides) do
        local a, b = corners[i], corners[i % 4 + 1]
        host.edges[#host.edges + 1] = S.Tear(F, "BACKGROUND", -5, a[1], a[2], b[1], b[2], side[1], P.depth, side[2],
            KRAFT.paper)
    end

    -- The flaps torn back, paler inside up, ragged along the tear.
    local FS = FLAPS.shadow
    for _, flap in ipairs(FLAPS) do
        local bx, by, bw, bh = flap.box[1], flap.box[2], flap.box[3], flap.box[4]
        local turn, ox, oy = Rad(flap.turn), bx + bw / 2, by + bh / 2
        local pts = {}
        for k, p in ipairs(flap.points) do pts[k] = { Turn(bx + p[1], by + p[2], turn, ox, oy) } end
        local function Over4(texture, dx, dy)
            return S.Quad(texture, pts[1][1] + dx, pts[1][2] + dy, pts[2][1] + dx, pts[2][2] + dy,
                pts[3][1] + dx, pts[3][2] + dy, pts[4][1] + dx, pts[4][2] + dy)
        end
        local shadow = S.Shadow(S.Texture(F, "BORDER", 0, { SHADE[1], SHADE[2], SHADE[3], FS[3] }))
        local inside = S.Texture(F, "BORDER", 1, KRAFT.inside)
        local sheen = S.Texture(F, "BORDER", 2)
        Style.Gradient(sheen, "HORIZONTAL", { 1, 0.94, 0.82, 0.22 }, { SHADE[1], SHADE[2], SHADE[3], 0.10 })
        Over4(shadow, FS[1], FS[2])
        Over4(sheen, 0, 0)
        -- A flap is no rectangle: where corners cannot move, there is none.
        if not Over4(inside, 0, 0) then
            for _, texture in ipairs({ shadow, inside, sheen }) do
                texture:Hide()
                texture.never = true
            end
        end
        local a, b = pts[flap.tear[1]], pts[flap.tear[2]]
        host.edges[#host.edges + 1] = S.Tear(F, "BORDER", 1, a[1], a[2], b[1], b[2], flap.teeth, flap.depth, flap.seed,
            KRAFT.inside)
    end

    -- The twine, cut, lying loose.
    for _, pass in ipairs({ { TWINE.edge, LOOSE.outer, 0 }, { TWINE.core, LOOSE.inner, 1 } }) do
        for _, curve in ipairs(LOOSE.curves) do
            S.Curve(F, "ARTWORK", pass[3], curve, LOOSE.x, LOOSE.y, LOOSE.steps, pass[1], pass[2])
        end
    end

    -- The closed book, and its ribbons.
    local book = Style.ClosedBook(F, BOOK.w, BOOK.h, BOOK.title)
    book:SetPoint("TOPLEFT", host, "TOPLEFT", BOOK.x - SCENE.left, -(BOOK.y - SCENE.top))
    S.made = S.made + book.count
    for _, shadow in ipairs(book.shadows) do S.Shadow(shadow) end
    host.book = book
    Ribbons(S, book)

    -- The label, torn aside with its paper, over the book's edge.
    local tag = Cover(host, F)
    tag:SetFrameLevel(book:GetFrameLevel() + 2)
    local A, Z = LABEL, TORN_LABEL
    local ink = { Style.INK[1], Style.INK[2], Style.INK[3], A.alpha }
    local o = A.outline
    local parts = {}
    local function Part(region, x, y, w, h)
        parts[#parts + 1] = { region, Z.x + x, Z.y + y, w, h }
        return region
    end
    for i, s in ipairs(A.shadows) do
        Part(S.Shadow(S.Texture(tag, "ARTWORK", i, { SHADE[1], SHADE[2], SHADE[3], s[4] })),
            s[1] - s[3], s[2] - s[3], Z.w + 2 * s[3], Z.h + 2 * s[3])
    end
    Part(S.Texture(tag, "ARTWORK", 3, A.paper), 0, 0, Z.w, Z.h)
    Part(S.Texture(tag, "ARTWORK", 4, ink), o, o, Z.w - 2 * o, 1)
    Part(S.Texture(tag, "ARTWORK", 4, ink), o, Z.h - o - 1, Z.w - 2 * o, 1)
    Part(S.Texture(tag, "ARTWORK", 4, ink), o, o, 1, Z.h - 2 * o)
    Part(S.Texture(tag, "ARTWORK", 4, ink), Z.w - o - 1, o, 1, Z.h - 2 * o)
    local title = Style.Text(tag, PF.tornTitle)
    title:SetText("SOCIAL DIARY")
    host.tornLabel = { title = title, parts = parts }

    -- The diary's note, beside the book: a loose sheet of its own.
    local N = NOTE
    local holder = CreateFrame("Frame", nil, F)
    holder:SetSize(N.w + 40, N.h + 40)
    holder:SetPoint("CENTER", host, "TOPLEFT", N.x + N.w / 2 - SCENE.left, -(N.y + N.h / 2 - SCENE.top))
    local note, K = ns.UI.LooseSheet(holder, N.w, N.h, { crease = CREASE, quiet = true })
    -- Only the note takes clicks, not the game round it.
    note:EnableMouse(false)
    local sheet = note.sheet
    note.hellos = { Style.Text(sheet, FONT.pencilLede), Style.Text(sheet, FONT.pencilLede) }
    note.hello = note.hellos[1]
    note.lines = {}
    for i = 1, N.most do note.lines[i] = Style.Text(sheet, FONT.pencil) end
    note.count = Style.Text(sheet, FONT.pencil)
    note.open = K.Link(FONT.strong, function() ns.UI.ShowIntro() end)
    note.open:SetText("Open me")
    note.later = K.Link(FONT.body, function()
        Parcel.later = true
        ns.UI.Parcel.HideSlip(false)
    end)
    note.later:SetText("Later")
    host.note, host.K = note, K
end

-- The torn label, turned as it lies (straight laid flat, or where text
-- cannot turn).
function Parcel.LayLabel(host, S, flat)
    local Z = TORN_LABEL
    local turn = (not flat and host.turnsText) and Rad(Z.turn) or 0
    local ox, oy = Z.x + Z.w / 2, Z.y + Z.h / 2
    for _, part in ipairs(host.tornLabel.parts) do
        S.Box(part[1], part[2], part[3], part[4], part[5], turn, ox, oy)
    end
    S.Line(host.tornLabel.title, ox, Z.y + Z.title, "CENTER", turn, ox, oy)
end

-- The note: how it lies, the first line (the first time, or again), the
-- body a line at a time, the live count (if anyone), and the links.
function Parcel.LayNote(host, flat, again)
    local note, K, N = host.note, host.K, NOTE
    K.Fall("parcel" .. (ns.ownGUID or ""), flat and 0 or Rad(N.turn))
    K.Lay()
    local M = N.margin
    local hello = K.Wrap(again and HELLO.again or HELLO.first, N.w - 2 * M, FONT.pencilLede)
    if #hello > #note.hellos then hello[#note.hellos] = table.concat(hello, " ", #note.hellos) end
    for i, text in ipairs(note.hellos) do
        text:SetText(hello[i] or "")
        text:SetShown(hello[i] ~= nil)
        if hello[i] then K.PlaceText(text, M, N.hello + (i - 1) * N.helloLine) end
    end
    local lines = K.Wrap(BODY, N.w - 2 * M, FONT.pencil)
    -- More lines than room: the last one takes the rest rather than lose
    -- words.
    if #lines > N.most then lines[N.most] = table.concat(lines, " ", N.most) end
    -- The body moves down by the greeting's second line, if any.
    local y = N.body + (math.min(#hello, #note.hellos) - 1) * N.helloLine
    for i, text in ipairs(note.lines) do
        local line = lines[i]
        text:SetText(line or "")
        text:SetShown(line ~= nil)
        if line then
            K.PlaceText(text, M, y)
            y = y + N.line
        end
    end
    -- Nobody pencilled in yet: no count at all.
    local count = Pencilled(ns.People.PencilledCount())
    note.count:SetText(count or "")
    note.count:SetShown(count ~= nil)
    if count then K.PlaceText(note.count, M, y - N.line + N.count) end
    local links = N.h - N.links
    note.open:PlaceAt(M, links)
    note.later:PlaceAt(M + K.Width(note.open.label) + 16, links)
    note:Show()
end
