-- The journal's look: parchment, ink and the game's own fonts.
--
-- Built from textures and font objects the client already ships, and from
-- plain frames -- no Blizzard templates, for the reason at the top of
-- UI/Kit/Chrome.lua. Several art files are unverified in this build, so each
-- art key is a list of candidates and the first the client knows wins
-- (GetFileIDFromPath). Missing art degrades to flat colour, never to a broken
-- frame. `/sd art` (Dev/Art.lua) reports what resolved.
--
-- One Style table over eight files, in load order: this one (palette, fonts,
-- inking coloured text), UI/Style/Art.lua (art and its fallbacks),
-- UI/Style/Sound.lua (sounds), UI/Style/Draw.lua (gradients, shades, noise,
-- strokes and the other drawing), UI/Style/Book.lua (the open book, its
-- ribbons, the brass), UI/Style/Cover.lua (the cover, the loose sheet, the
-- book closed, a pasted plate), UI/Style/Widgets.lua (text and the small
-- pieces drawn on the pages) and UI/Style/Person.lua (portraits, headings,
-- medallions).

local addonName, ns = ...

local Style = {}
ns.Style = Style

--------------------------------------------------------------------------
-- Palette
--------------------------------------------------------------------------
--
-- Ink on parchment, the way quest text and books read. Pure white and the
-- GameFont gold are for the dark chrome only: on parchment they vanish.

Style.PAPER = { 0.86, 0.77, 0.58 }
Style.INK = { 0.24, 0.16, 0.07 }
Style.INK_STRONG = { 0.13, 0.08, 0.03 }
Style.INK_FADED = { 0.44, 0.35, 0.21 }
-- Red ink, for the entries a manuscript would rubricate: a dungeon run.
Style.RUBRIC = { 0.50, 0.10, 0.05 }
-- Red-brown, for what stands out in a line: the facts in a story, Remove.
Style.ACCENT = { 0.42, 0.14, 0.04 }
-- The factions' colours, darkened for parchment.
Style.HORDE = { 0.55, 0.10, 0.07 }
Style.ALLIANCE = { 0.08, 0.235, 0.525 }
-- Lapis, the illuminator's blue: for ornament only (a day's paraph), never
-- for text that means something, as blue on the page also reads Alliance.
Style.LAPIS = { 0.17, 0.23, 0.47 }
-- Pencil, for what is not written in ink yet: the people pencilled in for
-- the buffer's days, and the sample page drawn on an empty diary
-- (UI/Journal/Empty.lua). Grey, but dark enough to read on the page.
Style.GRAPHITE = { 0.31, 0.30, 0.28 }

-- The same inks as colour codes, for text that carries its colour inline
-- (|cff...|r): each written out from its RGB above, so the two never drift.
local function Hex(color)
    local function Byte(x) return math.floor(x * 255 + 0.5) end
    return ("%02x%02x%02x"):format(Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

-- Any other colour the same way: a tag's, for a tag written inline.
Style.HexOf = Hex

Style.HEX = {
    strong = Hex(Style.INK_STRONG),
    faded = Hex(Style.INK_FADED),
    accent = Hex(Style.ACCENT),
    horde = Hex(Style.HORDE),
    alliance = Hex(Style.ALLIANCE),
    graphite = Hex(Style.GRAPHITE),
}

-- Marks the pages share. A row under the mouse is lit with ink at
-- HOVER_ALPHA; a selected one is shaded SELECTED. An ink hairline (a
-- link's underline, a writing line, a border) is drawn at HAIRLINE, and at
-- HAIRLINE_HOT while the mouse or the cursor is on it.
Style.HOVER_ALPHA = 0.10
Style.SELECTED = { 0.45, 0.28, 0.08, 0.22 }
Style.HAIRLINE, Style.HAIRLINE_HOT = 0.45, 0.9

-- A filled tag's lettering: paper-white on its colour.
Style.TAG_TEXT = { 0.98, 0.94, 0.83 }

-- Under the map art, and in its place where the art is missing.
Style.MAP_BACKGROUND = { 0.76, 0.66, 0.47 }

-- A list row: the People list, the days and the table on Recently nearby,
-- the picker.
Style.ROW_HEIGHT = 22

-- A page's list scrollbar in the book (ns.UI.Journal.List): its track, the
-- ink at a tenth, and its thumb, leather.
Style.LIST_BAR = { { Style.INK[1], Style.INK[2], Style.INK[3], 0.10 }, { 0.45, 0.31, 0.14, 0.75 } }

-- DIA-6 presets; custom tags get the neutral colour. Always drawn with their
-- text (NFR-7), so the colour is never the only signal.
Style.TAG_COLORS = {
    friend = { 0.18, 0.36, 0.16 },
    helper = { 0.16, 0.29, 0.47 },
    foe = { 0.55, 0.35, 0.07 },
    avoid = { 0.55, 0.14, 0.09 },
}
Style.TAG_DEFAULT = { 0.36, 0.28, 0.18 }

--------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------
--
-- Morpheus is the font of the game's books and quest titles; Friz Quadrata is
-- everything else. Both ship with every client. What the user wrote reads in
-- italic, which no client has: Neuton Italic comes with the addon
-- (Fonts/, OFL). No shadow on parchment: the default black drop shadow turns
-- ink into a smudge.

local MORPHEUS = "Fonts\\MORPHEUS.TTF"
local FRIZ = "Fonts\\FRIZQT__.TTF"
local NEUTON_ITALIC = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Neuton-Italic.ttf"

-- Goodmountain (Hermann S Designs, Fonts/Goodmountain-LICENSE.txt): shipped
-- as it came, never modified nor renamed (its licence forbids both). A
-- display face that reads in mixed case down to about 15 px, which Morpheus
-- cannot, so it is set in mixed case, never in capitals. For now on the
-- person's page alone (the person-page proposal, variant A, round 2): their
-- name on the clipped sheet, the timeline's day labels and a run card's
-- title. The user's client loads it (20 Oct: SetFont on it returns true).
local GOODMOUNTAIN = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Goodmountain.otf"

-- The files by name, for what sets a font by hand at a size of its own
-- (the margin cards' hand, the plates' heading, the parcel's fonts): the
-- same path every time, never a copy of the string.
Style.MORPHEUS, Style.FRIZ, Style.NEUTON_ITALIC = MORPHEUS, FRIZ, NEUTON_ITALIC
Style.GOODMOUNTAIN = GOODMOUNTAIN

local function Font(name, file, size, color)
    local font = CreateFont(name)
    font:SetFont(file, size, "")
    font:SetTextColor(color[1], color[2], color[3], 1)
    font:SetShadowOffset(0, 0)
    return font
end

Style.FONT = {
    title = Font("SocialDiaryFontTitle", MORPHEUS, 26, Style.INK_STRONG),
    titleSmall = Font("SocialDiaryFontTitleSmall", MORPHEUS, 20, Style.INK_STRONG),
    page = Font("SocialDiaryFontPage", MORPHEUS, 19, Style.INK_STRONG),
    rubric = Font("SocialDiaryFontRubric", MORPHEUS, 19, Style.RUBRIC),  -- capitals only
    -- Morpheus only at display sizes: its lowercase turns to glyphs ("Ɲot")
    -- below about 18 pt. Small headings are Friz capitals instead.
    heading = Font("SocialDiaryFontHeading", FRIZ, 11, Style.INK_FADED),
    -- A day on the timeline: a small heading rubricated.
    headingRubric = Font("SocialDiaryFontHeadingRubric", FRIZ, 11, Style.RUBRIC),
    note = Font("SocialDiaryFontNote", FRIZ, 14, Style.INK_STRONG),
    -- A note on the page, as written: on the timeline and the profile.
    noteWritten = Font("SocialDiaryFontNoteWritten", NEUTON_ITALIC, 16, Style.INK_STRONG),
    -- A note quoted under a name on a margin strip (UI/Paper/Strip.lua): the
    -- same hand a size down, so the name still leads.
    noteQuoted = Font("SocialDiaryFontNoteQuoted", NEUTON_ITALIC, 14, Style.INK),
    body = Font("SocialDiaryFontBody", FRIZ, 13, Style.INK),
    strong = Font("SocialDiaryFontStrong", FRIZ, 13, Style.INK_STRONG),
    small = Font("SocialDiaryFontSmall", FRIZ, 11, Style.INK_FADED),
    faded = Font("SocialDiaryFontFaded", FRIZ, 13, Style.INK_FADED),
    tag = Font("SocialDiaryFontTag", FRIZ, 11, Style.TAG_TEXT),
    -- The onboarding pages (UI/Journal/Front.lua, UI/Journal/Empty.lua): the
    -- preface's opening line, a page drawn in pencil, and the notes written
    -- beside it in red-brown ink.
    lede = Font("SocialDiaryFontLede", FRIZ, 14, Style.INK_STRONG),
    pencil = Font("SocialDiaryFontPencil", FRIZ, 13, Style.GRAPHITE),
    pencilSmall = Font("SocialDiaryFontPencilSmall", FRIZ, 11, Style.GRAPHITE),
    -- The first line of a note in pencil: the parcel's (UI/Windows/Intro/Torn.lua).
    pencilLede = Font("SocialDiaryFontPencilLede", FRIZ, 15, Style.GRAPHITE),
    pencilTitle = Font("SocialDiaryFontPencilTitle", MORPHEUS, 20, Style.GRAPHITE),
    margin = Font("SocialDiaryFontMargin", FRIZ, 12, Style.ACCENT),
    -- The person's page in Goodmountain (GOODMOUNTAIN, above), mixed case:
    -- their name on the clipped sheet (27, the 50 px sheet's line; a long
    -- name steps down to `personNameSmall`, and a very long one to
    -- `personNameLeast`, the smallest Goodmountain still reads at in mixed
    -- case), a day's label on its strip
    -- (15, rubric) and a dungeon run's title on its card (17, rubric).
    personName = Font("SocialDiaryFontPersonName", GOODMOUNTAIN, 27, Style.INK_STRONG),
    personNameSmall = Font("SocialDiaryFontPersonNameSmall", GOODMOUNTAIN, 22, Style.INK_STRONG),
    personNameLeast = Font("SocialDiaryFontPersonNameLeast", GOODMOUNTAIN, 17, Style.INK_STRONG),
    dayLabel = Font("SocialDiaryFontDayLabel", GOODMOUNTAIN, 15, Style.RUBRIC),
    runTitle = Font("SocialDiaryFontRunTitle", GOODMOUNTAIN, 17, Style.RUBRIC),
    -- The title tooled in gold on the closed book (Style.ClosedBook): GameFont
    -- gold on leather, pressed in, so its dark lip is up and to the left.
    cover = Font("SocialDiaryFontCover", MORPHEUS, 21, { 0.89, 0.73, 0.39 }),
}
Style.FONT.cover:SetShadowColor(0, 0, 0, 0.6)
Style.FONT.cover:SetShadowOffset(-1, 1)

--------------------------------------------------------------------------
-- Colour codes on parchment
--------------------------------------------------------------------------
--
-- Item links and other coloured text are coloured for dark backgrounds:
-- white and light green vanish on parchment. This darkens light colours and
-- maps item-quality codes (|cnIQ2:) to inks that keep their meaning.

local QUALITY_INK = {
    [0] = "6e6252", [1] = "211408", [2] = "1d5d12", [3] = "0a3d8f",
    [4] = "5a1f8a", [5] = "8a4500", [6] = "7a5a10", [7] = "0a5a7a",
}
local function RGB(hex)
    if not hex then return nil end
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- The same inks as RGB, for what is drawn in an item's colour rather than
-- written (a mark on a plate in the item's ink).
function Style.QualityInk(quality)
    return RGB(QUALITY_INK[tonumber(quality) or -1])
end

-- An item boxed on a card as the game shows it (an item chip on its own
-- light cream, f9f2dd, not the page's paper):
--   - NAME_INK: the item's name. Middle inks, the game colour's own hue
--     made as bright as still reads, about 6:1 on the cream and at least
--     4.66:1 on the wash's lightest-but-one stop. Card only: on the page's
--     darker paper they fall under 4.5:1, so prose keeps QUALITY_INK.
--   - GAME: the game's own quality colour, for the 1 px edge round the
--     icon (it lies against the dark icon, not the paper).
--   - WASH: watercolour multiplied (MOD) into the cream, each a multiplier
--     of it: `deep` at the box's left edge (round the icon, where no name
--     is), `left` where the name starts, `right` at the box's right edge;
--     the tide line where the wash dried, `tide` on the bottom and right
--     (all four laid flat), `tideIn` on the top and left. On the cream:
--       uncommon  deep 88bf7c  left c1e2a6 (name 4.72)  right e1ebc6 (5.42)
--       rare      deep 7baddd  left cbd7dd (name 4.66)  right e4e7dd (5.47)
--       epic      deep c697dd  left dccfdd (name 4.68)  right f0e2dd (5.55)
--     Blue can't be blue where the name is: multiplying cream can only
--     take blue away, and at the lightness 0059b1 needs (4.5:1) the best
--     blue left is slate. So the blue is put round the icon, at `deep`.
--   A white (common) item has none of them: its colour is the paper.
--   Legendary has a name ink and an edge but no wash (no card shows one
--   yet).
local QUALITY_NAME_INK = { [2] = "086b01", [3] = "0059b1", [4] = "880dce", [5] = "8f4501" }
local QUALITY_GAME = { [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
local QUALITY_WASH = {
    [2] = { deep = "8cc98f", left = "c6eec0", right = "e7f7e5", tide = "499c42", tideIn = "9dcd97" },
    [3] = { deep = "7eb6ff", left = "d0e2ff", right = "eaf3ff", tide = "4187de", tideIn = "97c1f7" },
    [4] = { deep = "cb9fff", left = "e2daff", right = "f6eeff", tide = "9e6bcc", tideIn = "cdafec" },
}

function Style.QualityNameInk(quality)
    return RGB(QUALITY_NAME_INK[tonumber(quality) or -1])
end

function Style.QualityGameColour(quality)
    return RGB(QUALITY_GAME[tonumber(quality) or -1])
end

-- The wash's stops as RGB ({ deep, left, right, tide, tideIn }), or nil
-- for a quality that has none. Shared: read, never written.
local WASH_RGB = {}
for quality, hexes in pairs(QUALITY_WASH) do
    WASH_RGB[quality] = {}
    for key, hex in pairs(hexes) do WASH_RGB[quality][key] = RGB(hex) end
end
function Style.QualityWash(quality)
    return WASH_RGB[tonumber(quality) or -1]
end

local function Darken(r, g, b)
    r, g, b = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
    local light = 0.3 * r + 0.59 * g + 0.11 * b
    if light <= 0.45 then return nil end
    local high, low = math.max(r, g, b), math.min(r, g, b)
    if high - low < 0.15 then return Style.HEX.strong end  -- white and greys
    local scale = 0.32 / light
    return ("%02x%02x%02x"):format(r * scale * 255, g * scale * 255, b * scale * 255)
end

function Style.Inkify(text)
    if type(text) ~= "string" then return text end
    text = text:gsub("|cn[^:|]-IQ(%d+):", function(quality)
        return "|cff" .. (QUALITY_INK[tonumber(quality)] or Style.HEX.strong)
    end)
    text = text:gsub("|cn[^:|]+:", "|cff" .. Style.HEX.strong)
    text = text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, r, g, b)
        local dark = Darken(r, g, b)
        return dark and ("|cff" .. dark) or nil
    end)
    return text
end
