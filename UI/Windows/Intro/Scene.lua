-- The parcel at login (PRV-4): the diary has just arrived, and opening it
-- is the first moment of role-play. A few seconds after login, until the
-- book's introduction has been seen -- its tour on a loose sheet over Your
-- Diary (UI/Windows/Intro/Tour.lua) -- it lies near the top of the screen:
--
--   wrapped  the first time: a book-shaped parcel in brown paper, tied with
--            twine under a wax seal, the maker's name, an address, a stamp
--            and its postmark, and a label saying what is inside. "Tear it
--            open", or a click on the seal, tears it (parcelOpened)
--   torn     the paper ripped open, its flaps torn back and the twine
--            cut: the closed book inside, its ribbons
--            hanging out of the foot, and beside it the diary's own note in
--            pencil, with how many it has pencilled in already. "Open me"
--            opens the book on the introduction's tour
--   again    a later login, still unread: torn already, the note greeting
--            you again
--
-- The parcel is its maker's: gnomish for Alliance, goblin for Horde (seal,
-- stamp, postmark, sender, the goblins' address). The book and the note
-- are the diary's, the same for both. The label only names the diary; the
-- retention days are left to the tour and the settings.
--
-- It comes back at every login until the introduction has been seen
-- (introSeen): Later, and Escape, only put it away until then. It never
-- shows in a fight: it waits for the fight to end, and a fight that starts
-- while it is up puts it away until then.
--
-- The parcel and the book are plain frames lying straight (frames cannot
-- turn in the client): textures, gradients and font strings, torn edges as
-- rows of small triangles (Style.TornEdge), the closed book the journal's
-- own leather (Style.ClosedBook). Only the note is a loose sheet
-- (UI/Paper/Sheet.lua), so it turns and takes the light like the book's
-- sheets. Everything is built once, at its first showing; laying it again
-- only sets its words, its maker's marks and what shows. "Flat paper only"
-- (flatSheets) evens the tears and takes away the turns of what lies
-- loose and every shadow.
--
-- The reference is .claude/ui-proposal/parcel-mockup.html: the numbers
-- below (and in the sibling files) are its sizes and offsets.
--
-- This file is the scene's look and kit: the tuning tables, the makers and
-- what the note says, the parcel's fonts, and the helpers every piece
-- places with (Rad, Turn, Kit, Cover, LightLink, Cog, Day). Its siblings,
-- loaded after it in this order:
--   UI/Windows/Intro/Wrapped.lua  the wrapped parcel (BuildWrapped,
--                                 LayWrapped)
--   UI/Windows/Intro/Torn.lua     torn open: the paper, flaps, the closed
--                                 book and its ribbons, and the note
--                                 (BuildTorn, LayNote)
--   UI/Windows/Intro/Parcel.lua   the host frame and the entry points
--                                 (ns.UI.OfferSlip, HideSlip, ShowIntro,
--                                 Slip) and the events that offer it
--
-- What they share is on the module (ns.UI.Parcel): the tables and helpers
-- above under their own names (Parcel.SCENE, Parcel.PF, Parcel.Kit, ...),
-- each piece's builders, and the state:
--   .slip      the host frame (SocialDiaryIntroFrame), once built
--   .later     "Later" this login
--   .waiting   a fight it is waiting out
--   .tornNow   torn this session (so the note greets you for the first
--              time, not again)
--
-- The named fonts (SocialDiaryFontParcel*) are made as this file loads, in
-- the order below; keep it.

local addonName, ns = ...

local Style = ns.Style
local L, Fmt = ns.L, ns.Fmt

local Parcel = {
    slip = nil,
    later = false, waiting = false, tornNow = false,
}
ns.UI.Parcel = Parcel

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------
--
-- In the scene's own coordinates, x right and y down, the mockup's at scale
-- 1; inside a piece (the parcel, a flap, the book) from that piece's top
-- left. Turns are in degrees clockwise, as the mockup gives them.

-- The part of the mockup the scene covers (left, top, w, h), how far below
-- the screen's top it hangs, which x lies on the screen's middle in each
-- state, and one scale for the whole of it.
local SCENE = { left = 145, top = 30, w = 690, h = 470, y = -40, middle = { wrapped = 450, torn = 490 },
    scale = 1 }

-- Brown paper, its paler inside, and the ink printed on it.
local KRAFT = { paper = { 0.64, 0.47, 0.29 }, inside = { 0.77, 0.62, 0.44 }, ink = { 0.16, 0.08, 0.02 } }

-- The wrapped parcel: where, how big, and its shadows ({ right, down,
-- larger, dark }). The links lie `links` under it. Its edges: light top
-- and left, dark bottom and right (`edge` wide), then the paper folding
-- over the book's edges (`folds`: left, right, top, bottom: width and
-- dark, light at the top). `crease`: a fold across it, from x1, y1 to x2,
-- y2, its width and dark. `fibres`: the grain art's alpha on it.
local PARCEL = {
    x = 305, y = 70, w = 290, h = 370, links = 22,
    shadows = { { 4, 6, 0, 0.22 }, { 8, 12, 3, 0.10 } },
    edge = { 2, 0.25, 0.30 },
    folds = { left = { 10, 0.18 }, right = { 10, 0.22 }, top = { 10, 0.12 }, bottom = { 12, 0.24 } },
    crease = { 0, 108, 290, 262, 3, 0.10 },
    fibres = 0.22,
}

-- The twine round it both ways: the vertical's x and the horizontal's y
-- (on the parcel), its width, its light core's, and its shadow (right,
-- down, dark). The bow under the seal: its box's top left on the parcel,
-- the loops and tails as the mockup's curves (in that box), how finely
-- each curve is drawn, and its two widths.
local TWINE = { core = { 0.89, 0.81, 0.64 }, edge = { 0.71, 0.60, 0.41 }, bow = { 0.79, 0.69, 0.50 },
    x = 172, y = 150, width = 5, coreWidth = 3, shadow = { 1, 1.5, 0.35 } }
local BOW = {
    x = 146, y = 128, steps = 5, outer = 4, inner = 2,
    curves = {
        { 29, 24, 14, 6, 2, 14, 8, 24 }, { 8, 24, 14, 32, 24, 28, 29, 24 },
        { 29, 24, 34, 28, 44, 32, 50, 24 }, { 50, 24, 56, 14, 44, 6, 29, 24 },
    },
    tails = { { 27, 27, 20, 48 }, { 31, 27, 40, 47 } },
}

-- The wax seal on the knot: its box on the parcel, its rim, body and the
-- ring pressed into it, the light on it (x, y from its middle, w, h, turn,
-- alpha), its shadow, and how much brighter it is under the mouse. The
-- gnomes' cog (hub, hole, tooth, how far out the teeth stand) and the
-- goblins' milled coin (dots round a struck G).
local SEAL = {
    x = 151, y = 130, size = 46, rim = 43, body = 39, ring = 27, ringIn = 24,
    lit = { -6, -9, 14, 7, -30, 0.55 }, shadow = { 1, 1.5, 0.35 }, hover = 0.22,
    cog = { hub = 14, hole = 5, tooth = { 3, 4 }, reach = 8 },
    coin = { dots = 10, r = 8.5, dot = 1.8 },
}
-- The makers' wax: red for the gnomes, green for the goblins.
local WAX = {
    gnome = { wax = { 0.56, 0.12, 0.07 }, dark = { 0.35, 0.06, 0.04 }, lit = { 0.72, 0.25, 0.16 } },
    goblin = { wax = { 0.24, 0.42, 0.17 }, dark = { 0.13, 0.25, 0.10 }, lit = { 0.37, 0.56, 0.27 } },
}

-- The stamp, top right on the parcel: its box, turn, paper and shadow, the
-- bites of its perforation along the top and bottom (how many, how big),
-- the picture inset, and the cog drawn smaller on it.
local STAMP = {
    x = 226, y = 16, w = 46, h = 56, turn = 4, paper = { 0.94, 0.89, 0.75 }, shadow = { 0.6, 0.8, 0.35 },
    bites = 7, bite = 4, inset = 4,
    cog = { hub = 11, hole = 4, tooth = { 2.4, 3.2 }, reach = 6.5 },
}
-- The postmark struck half over it: its box and turn, its ink, the ring's
-- alpha and strokes, the words' line step, and the cancelling lines (on
-- its box: x, first y, length, how many, the step, alpha).
local POSTMARK = {
    x = 184, y = 34, size = 62, turn = -12, ink = { 0.10, 0.05, 0.02 }, ring = 0.48, strokes = 16, step = 12,
    cancel = { x = 54, y = 20, w = 46, lines = 3, step = 6, alpha = 0.40 },
}
-- The sender, printed top left (its two lines' y), and the address in the
-- maker's hand.
local SENDER = { x = 18, y = 24, step = 15, alpha = { 0.78, 0.70 } }
local ADDRESS = { x = 18, y = 84, step = 20, ink = { 0.11, 0.06, 0.02 } }

-- The label: what is inside, before anything else. Its top on the parcel,
-- size, paper, the inked frame `outline` in, and its title's middle.
local LABEL = { y = 245, w = 200, h = 46, paper = { 0.92, 0.85, 0.69 }, outline = 5, alpha = 0.55,
    title = 23, shadows = { { 0.6, 0.8, 0, 0.40 }, { 1, 1.5, 0.5, 0.25 } } }

-- The links on the game world, light, under the wrapped parcel.
local LINK = { base = { 0.95, 0.90, 0.78 }, hot = { 1, 0.95, 0.81 } }

-- Torn open. What is left of the paper: its box, its corners (as fractions
-- of it, clockwise from the top left), each side's teeth and seed, how
-- deep they tear, and its shadow.
local PAPER = {
    x = 200, y = 62, w = 330, h = 410, depth = 8,
    corners = { { 0.01, 0.03 }, { 0.99, 0.01 }, { 0.98, 0.99 }, { 0.02, 0.97 } },
    sides = { { 20, 11 }, { 24, 47 }, { 20, 83 }, { 24, 131 } },
    shadows = { { 6, 8, 0, 0.22 }, { 9, 12, 3, 0.10 } },
}
-- The flaps torn back, paler inside up: each a box, its turn, its corners
-- in the box (upper left, upper right, lower right, lower left), which two
-- the tear runs between (going clockwise), its teeth, depth and seed.
local FLAPS = {
    shadow = { 1.5, 2, 0.30 },
    { box = { 170, 40, 140, 110 }, turn = -10, points = { { 0, 0 }, { 140, 4.4 }, { 8.4, 110 }, { 8.4, 110 } },
        tear = { 2, 3 }, teeth = 16, depth = 7, seed = 201 },
    { box = { 450, 276, 120, 170 }, turn = 7, points = { { 112.8, 0 }, { 120, 0 }, { 120, 170 }, { 0, 170 } },
        tear = { 4, 1 }, teeth = 18, depth = 8, seed = 307 },
}
-- The twine, cut, lying loose: its box, the mockup's two curves in it.
local LOOSE = { x = 160, y = 442, steps = 6, outer = 4, inner = 2,
    curves = { { 4, 40, 40, 20, 70, 54, 110, 34 }, { 110, 34, 150, 14, 170, 18, 196, 30 } } }

-- The closed book (Style.ClosedBook), and its ribbons out of the foot, one
-- per ribbon page of the journal (ns.UI.Journal.Ribbons, UI/Journal/
-- Pages.lua), in their order and their cloth (Style.RIBBONS): where they
-- start (y on the book), how wide, the notch cut in their end, their dark
-- edges, the sheen (x in, width, alpha), their shadow, and each page's, by
-- its key: x on the book, how far it hangs and its turn. A ribbon page
-- placed nowhere here fails tests/pages.lua.
local BOOK = { x = 238, y = 96, w = 250, h = 330, title = "SOCIAL\nDIARY" }
local RIBBONS = {
    top = 322, width = 16, notch = 6, edge = 2, sheen = { 4, 3, 0.14 }, shadow = { 1, 1, 0.30 },
    at = { journey = { 40, 64, 4 }, people = { 62, 52, -2 }, nearby = { 84, 70, 6 }, settings = { 106, 46, 1 } },
}

-- The diary's note, beside the book: its top left and size, its margin and
-- turn, the middles of the first line and the step to its second (the
-- greeting wraps: "again" is longer than the note is wide), of the body's
-- first and the step to the next (at most `most`), the count's after the
-- body, and the links from the bottom.
local NOTE = { x = 520, y = 150, w = 300, h = 225, margin = 20, turn = 2.4,
    hello = 28, helloLine = 20, body = 57, line = 19, most = 5, count = 28, links = 30 }
-- Hardly crumpled, its corners curling a little, no folds: it was written
-- and laid in the parcel flat.
local CREASE = {
    columns = { 0, 0.5, 1 },
    rows = { 0, 0.5, 1 },
    folds = { columns = {}, rows = {} },
    crumple = 0.6, drift = 0.4, edge = 0.6, wander = 0,
    curl = { lift = 4, pull = 2 },
}

-- The makers. Placeholders until checked against real NPCs.
local MAKERS = {
    gnome = { sender = { L["WIZZLEBOLT & DAUGHTER"], L["Diarywrights, Tinker Town"] },
        address = {}, postmark = { L["TINKER"], L["TOWN"] } },
    goblin = { sender = { L["GRIZZIK'S DIARIES"], L["Ratchet, no refunds"] },
        address = { L["To the new owner"], L["(paid in full)"] }, aside = true, postmark = { L["RATCHET"] } },
}

-- What the note says.
local HELLO = { first = L["Oh \226\128\148 hello. I'm your new diary."],
    again = L["Your diary, still here whenever you're ready."] }
local BODY = L["I write down the people you meet, all by myself, so that months from now you still know who they were. It's only pencil, until you ink someone in."]

local function Pencilled(n)
    -- Nobody yet: nothing to say.
    if n == 0 then return nil end
    return ns.Plural(n, L["I've pencilled in one already.|I've pencilled in %d already.##plural"])
end

--------------------------------------------------------------------------
-- Type
--------------------------------------------------------------------------
--
-- The parcel's own: print and the maker's hand on the paper, the label,
-- the stamp's and seal's letters, and links on the game world (light, with
-- a shadow, as they lie on whatever is behind).

local MORPHEUS, FRIZ, NEUTON = Style.MORPHEUS, Style.FRIZ, Style.NEUTON_ITALIC

local function Font(name, file, size, colour, shadow)
    local font = CreateFont(name)
    font:SetFont(file, size, "")
    font:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1)
    if shadow then
        font:SetShadowColor(0, 0, 0, shadow)
        font:SetShadowOffset(1, -1)
    else
        font:SetShadowOffset(0, 0)
    end
    return font
end

local PF = {
    print = Font("SocialDiaryFontParcelPrint", FRIZ, 11, KRAFT.ink),
    hand = Font("SocialDiaryFontParcelHand", NEUTON, 17, ADDRESS.ink),
    handSmall = Font("SocialDiaryFontParcelHandSmall", NEUTON, 14, ADDRESS.ink),
    postmark = Font("SocialDiaryFontParcelPostmark", FRIZ, 11, { POSTMARK.ink[1], POSTMARK.ink[2], POSTMARK.ink[3], 0.62 }),
    stamp = Font("SocialDiaryFontParcelStamp", MORPHEUS, 18, STAMP.paper),
    seal = Font("SocialDiaryFontParcelSeal", MORPHEUS, 13, WAX.goblin.dark),
    link = Font("SocialDiaryFontParcelLink", FRIZ, 13, LINK.base, 0.9),
}

--------------------------------------------------------------------------
-- Placing
--------------------------------------------------------------------------

-- Degrees clockwise (the mockup's) as SetRotation's radians.
local function Rad(degrees) return -math.rad(degrees or 0) end

-- x, y turned `turn` (SetRotation's) about ox, oy; y down.
local function Turn(x, y, turn, ox, oy)
    if not turn or turn == 0 then return x, y end
    local c, s = math.cos(turn), math.sin(turn)
    local dx, dy = x - ox, oy - y
    return ox + dx * c - dy * s, oy - (dx * s + dy * c)
end

-- The scene's kit: placing in its coordinates on `root` (the host: every
-- frame of the scene covers it), and counting the textures it takes.
-- `owner` is the frame a texture is made on, for its level; a stroke or a
-- tear is placed on its owner, which has to cover the root.
local function Kit(root)
    local L, T = SCENE.left, SCENE.top
    local S = { made = 0, teeth = 0, shadows = {} }

    function S.Texture(owner, layer, sublevel, colour)
        S.made = S.made + 1
        local texture = owner:CreateTexture(nil, layer, nil, sublevel)
        if colour then texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1) end
        return texture
    end

    -- Colours a texture again: a round one through its tint.
    function S.Paint(texture, colour, alpha)
        if texture.round then
            texture:SetVertexColor(colour[1], colour[2], colour[3], alpha or 1)
        else
            texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
        end
    end

    -- `region` over x, y, w by h, turned `turn` about ox, oy, and turning
    -- itself where it can.
    function S.Box(region, x, y, w, h, turn, ox, oy)
        local cx, cy = Turn(x + w / 2, y + h / 2, turn, ox, oy)
        region:ClearAllPoints()
        region:SetPoint("CENTER", root, "TOPLEFT", cx - L, -(cy - T))
        region:SetSize(w, h)
        if region.SetRotation and (turn or region.turned) then
            region:SetRotation(turn or 0)
            region.turned = (turn or 0) ~= 0
            if region.turned and region.SetSnapToPixelGrid then
                region:SetSnapToPixelGrid(false)
                region:SetTexelSnappingBias(0)
            end
        end
    end

    function S.Rect(owner, layer, sublevel, x, y, w, h, colour, turn, ox, oy)
        local texture = S.Texture(owner, layer, sublevel, colour)
        S.Box(texture, x, y, w, h, turn, ox, oy)
        return texture
    end

    -- A spot of colour centred on x, y: round where the art allows.
    function S.Disc(owner, layer, sublevel, x, y, size, colour, alpha, turn, ox, oy)
        local texture = S.Texture(owner, layer, sublevel)
        texture.round = Style.Disc(texture, colour[1], colour[2], colour[3], alpha or 1)
        S.Box(texture, x - size / 2, y - size / 2, size, size, turn, ox, oy)
        return texture
    end

    -- A line of text, its middle at height y, starting at x ("LEFT"),
    -- ending there ("RIGHT") or centred on it; measured unbounded, so it is
    -- never cut short.
    function S.Line(text, x, y, justify, turn, ox, oy)
        text:SetSize(0, 0)
        local w = (text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth() or 0) + 2
        local h = (text:GetStringHeight() or 0) + 2
        if justify == "RIGHT" then x = x - w elseif justify == "CENTER" then x = x - w / 2 end
        S.Box(text, x, y - h / 2, w, h, turn, ox, oy)
    end

    -- Over any four points: upper left, upper right, lower right, lower
    -- left. False where corners cannot move.
    function S.Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4)
        return Style.Quad(texture, root, x1 - L, y1 - T, x2 - L, y2 - T, x3 - L, y3 - T, x4 - L, y4 - T)
    end

    function S.Stroke(owner, layer, sublevel, x1, y1, x2, y2, colour, alpha, width)
        S.made = S.made + 1
        return Style.Stroke(owner, layer, x1 - L, y1 - T, x2 - L, y2 - T, colour, alpha, width, sublevel)
    end

    -- One of the mockup's cubic curves (x1, y1, two controls, x2, y2),
    -- offset by ox, oy, as `steps` strokes.
    function S.Curve(owner, layer, sublevel, c, ox, oy, steps, colour, width)
        local function At(t)
            local u = 1 - t
            local a, b, d, e = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
            return ox + a * c[1] + b * c[3] + d * c[5] + e * c[7], oy + a * c[2] + b * c[4] + d * c[6] + e * c[8]
        end
        local px, py = At(0)
        for i = 1, steps do
            local x, y = At(i / steps)
            S.Stroke(owner, layer, sublevel, px, py, x, y, colour, 1, width)
            px, py = x, y
        end
    end

    function S.Tear(owner, layer, sublevel, x1, y1, x2, y2, teeth, depth, seed, colour)
        S.teeth, S.made = S.teeth + teeth, S.made + teeth
        return Style.TornEdge(owner, layer, sublevel, x1 - L, y1 - T, x2 - L, y2 - T, teeth, depth, seed, colour)
    end

    -- A shadow, taken away laid flat.
    function S.Shadow(texture)
        S.shadows[#S.shadows + 1] = texture
        return texture
    end

    return S
end

-- A frame covering the host, for one part of the scene.
local function Cover(host, parent)
    local frame = CreateFrame("Frame", nil, parent or host)
    frame:SetAllPoints(host)
    return frame
end

-- A link on the game world: light, brighter under the mouse.
local function LightLink(parent, text, colour, onClick)
    local link = Style.Link(parent, PF.link, onClick)
    link:SetText(text)
    link:SetColor(colour[1], colour[2], colour[3])
    link:SetScript("OnEnter", function(self)
        self.label:SetTextColor(LINK.hot[1], LINK.hot[2], LINK.hot[3])
        self.line:SetColorTexture(LINK.hot[1], LINK.hot[2], LINK.hot[3], Style.HAIRLINE_HOT)
    end)
    link:SetScript("OnLeave", function(self)
        self.label:SetTextColor(colour[1], colour[2], colour[3])
        self.line:SetColorTexture(colour[1], colour[2], colour[3], Style.HAIRLINE)
    end)
    return link
end

-- A cog about cx, cy, turned `turn` about ox, oy: a hub and eight teeth in
-- `colour`, a hole in `hole`'s. Returns its textures, the hole last.
local function Cog(S, owner, layer, sublevel, cx, cy, C, colour, hole, turn, ox, oy)
    local parts = {}
    local hx, hy = Turn(cx, cy, turn, ox, oy)
    parts[1] = S.Disc(owner, layer, sublevel, hx, hy, C.hub, colour)
    for k = 0, 7 do
        local a = math.rad(k * 45)
        local x, y = Turn(cx + C.reach * math.sin(a), cy - C.reach * math.cos(a), turn, ox, oy)
        local tw, th = C.tooth[1], C.tooth[2]
        parts[#parts + 1] = S.Rect(owner, layer, sublevel, x - tw / 2, y - th / 2, tw, th, colour, -a + (turn or 0), x, y)
    end
    parts[#parts + 1] = S.Disc(owner, layer, sublevel + 1, hx, hy, C.hole, hole)
    return parts
end

-- Today, as the postmark strikes it: "9 OCT".
local function Day()
    -- (no time given: date() reads now)
    return Fmt(L["%1$s %2$s##short date"], ns.UI.Format.Day(tonumber(date("%d")) or 1), Style.Upper(ns.UI.Format.MonthShort(nil) or ""))
end

-- For the pieces after this file.
Parcel.SCENE = SCENE
Parcel.KRAFT = KRAFT
Parcel.PARCEL = PARCEL
Parcel.TWINE = TWINE
Parcel.BOW = BOW
Parcel.SEAL = SEAL
Parcel.WAX = WAX
Parcel.STAMP = STAMP
Parcel.POSTMARK = POSTMARK
Parcel.SENDER = SENDER
Parcel.ADDRESS = ADDRESS
Parcel.LABEL = LABEL
Parcel.LINK = LINK
Parcel.PAPER = PAPER
Parcel.FLAPS = FLAPS
Parcel.LOOSE = LOOSE
Parcel.BOOK = BOOK
Parcel.RIBBONS = RIBBONS
Parcel.NOTE = NOTE
Parcel.CREASE = CREASE
Parcel.MAKERS = MAKERS
Parcel.HELLO = HELLO
Parcel.BODY = BODY
Parcel.Pencilled = Pencilled
Parcel.PF = PF
Parcel.Rad = Rad
Parcel.Turn = Turn
Parcel.Kit = Kit
Parcel.Cover = Cover
Parcel.LightLink = LightLink
Parcel.Cog = Cog
Parcel.Day = Day
