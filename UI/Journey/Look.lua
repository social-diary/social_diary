-- Your Diary's look (JRN-11, JRN-21): the numbers the page is laid out by,
-- each table's comment saying what its fields mean and why its values.
-- The left page's (HEAD, ENTRY, LEDGER, PARAPHS, FACES, SITTINGS); the
-- right page's slots for one to three plates and for a page keyed by its
-- plates' weights (LAYOUT, Snap, SNAPSHOT), the full page's (FULL); a caption's
-- (CAPTION), a leader's (LEADER), the frame levels over the plates
-- (LEADERS, STRIPS), the full page's foot (FOOT), what a level with nothing
-- kept and the setting off say (NOTHING, OFF), and the empty page's
-- (EMPTY, SKETCH, NOTES). What the page is and does: UI/Journey/Page.lua.
--
-- The page is one module, ns.UI.YourDiary (aliased `YourDiary` by its
-- files), in a file per question, each loaded after the one before it (the
-- TOC's order) and putting on the module what a later one takes from it:
--   UI/Journey/Look.lua     the module, and the look: the left page's
--                           measures, the plates' slots (LAYOUT), a
--                           caption's, a leader's, the full page's foot,
--                           the empty page's
--   UI/Journey/Left.lua     the left page: the character, the entries,
--                           their faces, the open one's sittings and runs
--                           and its ledger of zones; which piece is open
--                           (OpenPieceOf)
--   UI/Journey/Layouts.lua  a level's plates and the page their weights
--                           give (LayoutFor, PlatesOf), and what each draws
--                           from (SheetOf, MomentsOf)
--   UI/Journey/Leaders.lua  the right page's plates and pools handed out,
--                           and the pencil leaders from a note to its mark
--   UI/Journey/People.lua   the people on a plate, and how much each
--                           matters (Tier)
--   UI/Journey/Margin.lua   the margin: its registry (ns.UI.JourneyMargin)
--                           and how its notes are laid (WriteMargin)
--   UI/Journey/Caption.lua  a plate glued in its slot with its caption and
--                           margin (Plated), and the open level's plates
--                           (DrawPlates, F+L)
--   UI/Journey/Full.lua     a zone's whole map across the page
--   UI/Journey/Empty.lua    the page with nothing on the road yet
--   UI/Journey/Page.lua     the page built, refreshed and turned to, and
--                           its entry points (ns.UI.RefreshJourneyPage,
--                           RedrawJourneyPage, OpenZoneSheet, JourneyPage,
--                           JourneyLook)
--
-- Shared state, on the module:
--   .page       the page: its frames and pools, the open entry, what is
--               drawn (BuildPage, UI/Journey/Page.lua). Nil until the book
--               is built. Every function reads it as it runs (`local page
--               = YourDiary.page`), never as its file loads.
--   .OpenLevel  .OpenPiece, .OpenRun and .OpenFull: a level's newest
--               sitting, one sitting, a run's page, a zone's whole map
--               (Page.lua, the last to load), so the files before it look
--               them up as they call them.
-- Everything else on it, the look tables and the functions one file calls
-- in another, is set once as its file loads and taken by the later files
-- as they load (`local LAYOUT = YourDiary.LAYOUT`): the same tables, so a
-- test that changes one (LAYOUT.FL.tucked) changes it for every file.
-- The tests' handles stay as they were: ns.UI.JourneyPage() the page,
-- ns.UI.JourneyLook (made at the foot of Page.lua), ns.UI.JourneyMargin
-- (Margin.lua).

local addonName, ns = ...

local Style = ns.Style

local BOOK = ns.UI.Journal.BOOK
local RIGHT_X = BOOK.RIGHT_X

local YourDiary = { page = nil }
ns.UI.YourDiary = YourDiary

-- The character at the top of the left page, down from the page's top:
-- the name, who they are, the short rule under them, and where the
-- entries begin. The entries stop `bottom` short of the page's foot, clear
-- of the ribbons hanging there.
local HEAD = { name = 22, who = 54, rule = 76, ruleW = 60, list = 90, bottom = 34 }
-- An entry: the rubric's paraph hangs in the margin and text lines up with
-- the rubric's words (`indent`); `leading` between lines, `para` under a
-- paragraph, `later` under a line written in hindsight, `title` the open
-- rubric's row, `zone` a zone's row, `prologue` under the opening line.
-- Closed rubrics are a contents list, set close: each a `closed` row, its
-- words `closedBase` px up from its foot (`base` on the open rubric's),
-- one under another with no gap; the open entry stands apart, `open` px
-- above its rubric and `after` px under its last row. The rubric's rule is
-- red at `ruleAlpha`, `ruleHot` under the mouse. The list is built with
-- `rows` rows of `unit` height each, and shows as many as fit.
-- (10 Oct, in the client: at 8 + 22 a closed rubric, six of them filled
-- the page above the open entry. A rival's ring is 20 px across, so two
-- rivals' faces in rubrics one under the other just touch at 19.)
--
-- Paragraphs are set apart by a clear gap, as a printed diary does (no
-- first-line indent: WoW's font strings have none to give): `para` is
-- well over the `leading`, so a new paragraph never reads as a wrapped
-- line. `more` is the small gap under a quoted note to its "And one more
-- note."; `ledger` the gap over the zone rows.
local ENTRY = { indent = 13, leading = 3, para = 10, later = 6, more = 2, title = 22, base = 6, closed = 19,
    closedBase = 4, open = 12, after = 12, zone = 17, ledger = 6, prologue = 10, unit = 17, rows = 48, paraph = 6,
    rule = 6, ruleAlpha = 0.40, ruleHot = 0.70 }
-- The ledger under the open entry (JRN-15): each zone in small type in
-- ink, a run of `dot` leaders (a font string of them, as many as the gap
-- between the name and its time holds, measured, and set flush right so
-- the dots line up down the column) `gap` px clear of both, and the time
-- at the right in faded ink, `right` px in from the row's end. A name
-- never takes more than `nameMax` of the row. The dots are ink at
-- `dotAlpha`. A dungeon's row has a doorway in the margin where a
-- rubric's paraph hangs: the plates' arch (UI/Journey/Plate.lua's DOOR, a
-- round head on a square body), `size` px, in `ink` at `alpha`. In ink, not
-- rubric: small and red, it read as a level's pin.
-- (10 Oct, in the client: two posts and a lintel in red read as "⊓", a
-- missing glyph.)
-- Under the mouse a zone's row is marked as a reader marks a line, never
-- lit: its name inked darker (INK_STRONG) and a pencil line under it,
-- `mark`: graphite in `colour` at `alpha`, `width` px, `under` px below the
-- name, as long as the name; under the line a `lip` of light at
-- `lipAlpha`, the lower side of the groove the pencil pressed, which faces
-- the top-left light. While its map is the one on the right page the line
-- is in ink (INK_STRONG at `inkAlpha`) and stays. Laid flat, no lip.
-- (10 Oct, in the client: a flat tan rectangle under the mouse was the most
-- screen-like thing left on the page.)
local LEDGER = { dot = " .", gap = 4, right = 4, nameMax = 0.72, dotAlpha = 0.55,
    door = { size = 9, ink = Style.INK_STRONG, alpha = 0.85 },
    mark = { colour = Style.GRAPHITE, alpha = 0.60, width = 1, under = 0, lip = { 1, 0.97, 0.88 }, lipAlpha = 0.22,
        inkAlpha = 0.70 } }
local PARAPHS = { Style.LAPIS, Style.RUBRIC }
-- The faces at a rubric's end (JRN-22): at most `most` class circles
-- (UI-Classes-Circles) `size` px, `gap` apart, then "+n"; each on a dark
-- edge `edge` px wider, a rival's in a rubric ring `ring` px wider still.
local FACES = { most = 4, size = 13, gap = 4, edge = 2, ring = 5, ringAlpha = 0.85 }
-- The open entry's sittings (.claude/sittings-plan.md), straight under its
-- rubric and over its prose, where it was played in more than one or has
-- a run page: a contents list inside the contents list, so it is set as
-- the book sets one, never as buttons. Each sitting's date in body type,
-- `indent` px further in than the prose (a sub-entry hangs under its
-- heading), one `row` each; under a sitting, each of its runs in small
-- type `run` px further in again, the ledger's doorway hanging before it
-- (a dungeon is a doorway wherever the page names one), one `runRow`
-- each; `after` px under the last, before the prose. "so far" beside the
-- one being played, as the rubric has it, `aside` px clear. The rows are
-- marked as the ledger's are (LEDGER.mark): a pencil line under the mouse,
-- an ink line under what the right page shows. The sitting open is ticked
-- in the margin as a reader ticks their place: the paraph's lozenge in
-- rubric, `tick` px, `tickX` px left of the date, so it reads as this
-- level's own mark (it is the paraph, smaller) and stays while a run or a
-- zone of it is on the right page.
local SITTINGS = { indent = 12, run = 13, row = 18, runRow = 16, after = 8, aside = 7, tick = 5, tickX = 8 }

-- The right page, measured from its top left (RIGHT_X, TOP), as the
-- mockup's (.claude/ui-proposal/journey-moments-mockup.html): the plates'
-- slots for one, two and three places. Each: where (x, y), how big, its
-- turn in degrees (clockwise), the card's margin round the art (`pad`),
-- its photo corners' size (`pc`) and which corners, the corner come
-- unstuck (`lift`), its caption's box (and how far down its notes may
-- go, `limit`, where another plate lies below), and where its margin
-- notes go when not under the caption (`notes`). A caption to the left of
-- its plate is set flush right (`align`), its notes too, so both lean on
-- the plate they belong to instead of floating at the page's edge.
-- The plates take the whole page, as an album's photographs do: the top
-- one is glued a little above the right page's own top (the paper runs
-- 20 px higher, so its corners still stand clear of the book's edge),
-- and the lowest goes down to the foot, as far as the not-kept line in
-- the right column lets it (OFF). Of three, the second stands tall beside
-- the first, in the room under the first's caption, so that the column at
-- its left, under the first plate, is wide and runs from just under it
-- to just over the third: room for the caption, a strip and a close
-- call's card (11 Oct, in the client: at 136 by 206 px, Feivel's strip
-- took the last of it and the card for what nearly got you was left
-- off). That column is what the first and third plates gave height for,
-- and the first gave the second width: no less than 192 px, as the
-- narrowest art of a layout is the window its places are grouped by
-- (SMALLEST), and narrower lost a stay from a plate. Of two, the first
-- gives its caption 176 px: a close call's card names its creature on one
-- line in the hand (14 px at the smaller size) with its level's tag over
-- it, and a long name ("Razormane Battleguard", or longer, near 26
-- letters) needs that much (11 Oct: at 136 px the card was left off).
-- One plate whose caption is short (its heading and a line of words) has
-- the caption over it instead (`top`, the user's wish, 11 Oct), written
-- across the page, and the plate a little lower and shorter, so the page
-- under it holds its notes in a `row` of three, side by side, each with
-- room for a close call's card and its picture (about 125 px with its
-- heading and tag, the picture drawn small). Its leaders then go up into the plate and never through the
-- words. The plate's corner comes as near the words as a plate comes to
-- its caption elsewhere, about 9 px (12 Oct, in the client: at 48 the gap
-- was some 20 px, the words shorter than measured here). It is not one of
-- the layout's slots: the one plate's places are grouped by the taller
-- plate (SMALLEST), and the shorter still holds them, as a plate's moments
-- span at most PLATES.inset (0.8) of its window (Core/JourneyRecap.lua):
-- 275 px of 344, inside its 323.
local RIGHT_H = 534
local FOUR = { "tl", "tr", "bl", "br" }
local LOST = { "tl", "tr", "bl" }
local LAYOUT = {
    { { x = 10, y = 0, w = 444, h = 364, t = -1.2, pad = 10, pc = 28, corners = LOST, lift = "br",
        cap = { x = 16, y = 382, w = 260 }, notes = { x = 300, y = 378, w = 150 },
        top = { x = 10, y = 37, w = 444, h = 343, t = -1.2, pad = 10, pc = 28, corners = LOST, lift = "br",
            cap = { x = 16, y = -2, w = 434 },
            row = { { x = 10, y = 400, w = 142 }, { x = 160, y = 400, w = 142 }, { x = 310, y = 400, w = 142 } } } } },
    { { x = 8, y = -2, w = 260, h = 236, t = -1.4, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 240 } },
        { x = 150, y = 254, w = 300, h = 236, t = 1.8, pad = 8, pc = 24, corners = LOST, lift = "br",
            cap = { x = 12, y = 268, w = 122, align = "RIGHT" } } },
    { { x = 8, y = -2, w = 242, h = 176, t = -1.3, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 264, y = 16, w = 194, limit = 132 } },
        { x = 264, y = 150, w = 192, h = 234, t = 2.2, pad = 7, pc = 22, corners = LOST, lift = "br",
            cap = { x = 12, y = 184, w = 232, limit = 390, align = "RIGHT" } },
        { x = 8, y = 404, w = 228, h = 126, t = 1.6, pad = 7, pc = 20, corners = {}, lift = "bl",
            cap = { x = 252, y = 406, w = 204 } } },
}
-- Weighed pages (.claude/ui-proposal/plate-weight-proposal.md, 13 Oct): a
-- page is also keyed by its plates' weights in time order, F a full plate
-- and L a light one (Core/JourneyRecap.lua's LIGHT: a place and a line of
-- words, nothing for the margin), so a first visit with a level's pin no
-- longer takes the larger slot while the plate beside it, with people, a
-- close call and a hunt, loses its margin to a narrow column (13 Oct, in
-- the client: Stormwind in 300 by 236 for a first visit and a pin;
-- Elwynn's column 176 by 222, two of its three notes left off). A light
-- plate is a small print, a snapshot (Snap): 176 by 124, its art 162 by
-- 110, its caption beside it (flush right on its left) or under it. A full
-- plate's caption is 176 px wide, as a snapshot is, so a page has two
-- widths: a 260 px column of plates and a 176 px one of words or a print.
-- Plates stay in time order down the page, as a heading counts on from
-- the plate before ("Twenty minutes later"; the user's choice, 13 Oct).
-- The album's rules hold on each: every slot turns; one corner come
-- unstuck, `br`, on a lower print; FOUR on the others; nothing nearer the
-- page's edge than 8 px, or 10 on a lifted side; and a light caption right
-- of the not-kept line (OFF, x 246) ends above it. The proposal's
-- geometry, but where its pages, laid out with the plates' real shadows
-- and photo corners (13 Oct, rasterised from the mock), had prints
-- touching: FFL's print 6 px further left and 2 up, its second plate 4 px
-- narrower, so the two no longer meet at their corners and the print's
-- lifted shadow stays on the page; LFF's second plate 4 px lower and
-- shorter, clear of the print over it, and its third 2 px narrower, its
-- lifted corner 10 px in from the page's edge after its turn. And as the
-- lowest plate of three keeps clear of the not-kept line (OFF), FLF's
-- third plate is 156 px tall (the proposal's 180) and LFF's 154 (174),
-- so neither lies over it with the setting off; both still hold the
-- three-plate window (SMALLEST) with room (13 Oct, rasterised again).
-- Only FL, LF, FLF, FFL, LFF and LFL have a page of their own (the
-- user's choice, 13 Oct). Any other pattern (FF, LL, FFF, FLL, LLF,
-- LLL) is the page above for that many plates, as before, and so is one
-- plate alone, light or not (with its `top`).
local function Snap(x, y, t, corners, lift, cap)
    return { x = x, y = y, w = 176, h = 124, t = t, pad = 7, pc = 18, corners = corners, lift = lift, cap = cap,
        light = true }
end
-- The print a light plate must fit to be drawn light (LayoutFor).
local SNAPSHOT = Snap(0, 0, 0, {})
-- A light plate's filler note (a margin kind with `filler`) goes under
-- its print's caption where there is room (LF, LFF, LFL, FLF; FFL with
-- the route kept). Under FL's print (its caption from y 474) and often
-- F+L's tucked one there is none: the note is left off there and the
-- caption's words say it. The layouts stay as they are for filler, never
-- FL turned FF for it (the user's choice, 14 Oct).
LAYOUT.FL = { { x = 8, y = -2, w = 260, h = 318, t = -1.4, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 528 } },
    Snap(40, 336, 2.2, LOST, "br", { x = 42, y = 474, w = 200, limit = 528 }) }
LAYOUT.LF = { Snap(272, 4, 2.0, FOUR, nil, { x = 12, y = 28, w = 246, limit = 136, align = "RIGHT" }),
    { x = 8, y = 144, w = 260, h = 334, t = -1.2, pad = 8, pc = 24, corners = LOST, lift = "br",
        cap = { x = 282, y = 162, w = 176, limit = 528 } } }
LAYOUT.FFL = { { x = 8, y = -2, w = 260, h = 198, t = -1.3, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 250 } },
    { x = 200, y = 264, w = 256, h = 158, t = 1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 10, y = 214, w = 176, limit = 384, align = "RIGHT" } },
    Snap(8, 396, 1.6, LOST, "br", { x = 206, y = 432, w = 252, limit = 528 }) }
LAYOUT.FLF = { { x = 8, y = -2, w = 260, h = 196, t = -1.3, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 204 } },
    Snap(280, 212, 2.0, LOST, "br", { x = 12, y = 232, w = 252, limit = 330, align = "RIGHT" }),
    { x = 8, y = 344, w = 260, h = 156, t = 1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 354, w = 176, limit = 528 } } }
LAYOUT.LFF = { Snap(14, 4, -2.0, FOUR, nil, { x = 206, y = 26, w = 252, limit = 132 }),
    { x = 8, y = 144, w = 260, h = 188, t = 1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 160, w = 176, limit = 340 } },
    { x = 196, y = 346, w = 258, h = 154, t = -1.0, pad = 8, pc = 24, corners = LOST, lift = "br",
        cap = { x = 10, y = 362, w = 176, limit = 528, align = "RIGHT" } } }
LAYOUT.LFL = { Snap(272, 4, 2.0, FOUR, nil, { x = 12, y = 26, w = 248, limit = 132, align = "RIGHT" }),
    { x = 8, y = 140, w = 260, h = 226, t = -1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 156, w = 176, limit = 392 } },
    Snap(22, 392, 1.6, LOST, "br", { x = 214, y = 412, w = 244, limit = 528 }) }
-- FL may instead be the one plate's page with the light plate's print
-- tucked in (`tucked`, F+L, the proposal mockup's TUCKED, which it turned
-- down as the default; the user wants it as an option, 13 Oct): the full
-- plate under its caption written across the page, as `top`, its notes in
-- a `row` of two, and in the row's third place the print, smaller (140 by
-- 100, its art 128 by 88), its caption under it. It is tried first and
-- kept only where nothing is lost by it (DrawPlates): its caption short,
-- as `top`'s; all of its margin in the row (`whole`); and both plates
-- held by their windows here. The full plate is as high as `top`'s, its
-- corner as near the words (12 Oct, in the client), and 278 px tall (the
-- mockup's 292 less 14), so the row and the print sit 31 px higher than the
-- mockup's: the print's caption, 148 px wide, has room for three lines of
-- words (a zone's name alone over them, the day moved into the words)
-- and ends above the not-kept line, as every caption right of it does
-- (at 284 px three lines ran down onto it; 13 Oct, rasterised from the
-- mock), and its lifted corner lies 14 px
-- in from the page's edge, its shadow (9.9 px at most,
-- UI/Journey/Plate.lua's SHADOW) inside the page's margin and clear of the
-- caption under it.
LAYOUT["F+L"] = { { x = 10, y = 37, w = 444, h = 278, t = -1.2, pad = 10, pc = 28, corners = FOUR,
        cap = { x = 16, y = -2, w = 434 }, row = { { x = 10, y = 333, w = 142 }, { x = 160, y = 333, w = 142 } },
        whole = true },
    { x = 314, y = 329, w = 140, h = 100, t = 2.0, pad = 6, pc = 16, corners = LOST, lift = "br",
        cap = { x = 312, y = 442, w = 148 }, light = true } }
LAYOUT.FL.tucked = LAYOUT["F+L"]
-- The full page: one plate, the zone's whole height (JRN-14).
local FULL = { x = 10, y = 8, w = 446, h = 484, t = 1.0, pad = 10, pc = 28, corners = LOST, lift = "br" }
-- A caption, as under a photograph in an album: one line by hand in ink,
-- "The Barrens, yesterday" (FONT.noteWritten), at the first of the `hand`
-- sizes that fits its column on one line (`handFile`, the font
-- FONT.noteWritten is cut from, for the smaller sizes); where none does,
-- the zone alone and the day moved into the words. `under` it the words; the margin
-- notes' strips (UI/Paper/Strip.lua) `notes` under those and `gap` apart,
-- room for the tape over each; nothing written past `limit` (the page's
-- foot), or `offLimit` while the not-kept line stands there.
local CAPTION = { hand = { 16, 14 }, handFile = Style.NEUTON_ITALIC,
    under = 1, notes = 16, gap = 12, limit = 528, offLimit = 506 }
-- A margin note's pencil leader (JRN-22), short and drawn by hand:
-- graphite at `alpha`, `width` px. It leaves its strip at the edge nearest
-- its mark and comes onto the plate over the plate's edge nearest the
-- strip, so it crosses as little of the map as it can: where on that edge
-- is `lean` of the way from level with the mark toward the strip, kept
-- `inset` px in from the corners, clear of the photo corners there. It bows a little, `bow` of its length
-- toward the page's foot, as a hand's line sags, and ends `stop` px short
-- of the mark in a pencil dot `dot` px across at `dotAlpha`.
-- It is drawn with the route's pen (UI/Ink/Pen.lua: the curve resampled,
-- mitred and stroked into flat pieces that share their edges, so it bends
-- smoothly and never gaps), but as a pencil, so it never reads as a road
-- across the map (`pen`): graphite at `alpha`, `width` px, a nib whose
-- thick and thin differ little (`nib`, against the route's .55 to 1.25),
-- lighter where it leaves its strip (`taper`: `from` of its width there,
-- full `over` px on), and none of the route's flow, beads or sprinkles.
-- A piece every `step` px of the curve, longer where that would pass
-- `most` pieces. Where the client cannot move a texture's corners, each
-- piece is a straight stroke, turned.
-- (10 Oct, in the client: a hairline of .9 px at .62 vanished against the
-- map art, and four turned flat strokes showed their elbows and stair-
-- stepped edges; the user wants the pen's line, with no fading edges.)
local LEADER = { colour = { 0.27, 0.26, 0.24 }, alpha = 0.85, stop = 9, lean = 0.3, inset = 30, bow = 0.06,
    dot = 3.6, dotAlpha = 0.9,
    pen = { width = 1.7, nib = { angle = 40, thin = 0.85, thick = 1.1 }, taper = { from = 0.55, over = 18 },
        step = 4, most = 24, curve = 24 } }
-- Frame levels over the right page: the leaders over the plates (PLATE's
-- 5, UI/Journey/Plate.lua), the strips over both.
local LEADERS, STRIPS = { level = 20 }, { level = 25 }
-- The line under the full page: its top, the gap between its parts, the
-- second line's gap when it wraps, and under it all the hint, which says
-- how to look closer and how to go back. There is no back link: a click on
-- the map is the way back (FULLZOOM's DRAG), so the hint is what tells it.
local FOOT = { y = 506, gap = 10, under = 3, hint = 3, words = "Scroll to look closer; click the map to go back." }
-- A level with nothing kept: its faded line, `y` down the page. The
-- setting off: its line and link in the right column at the foot (`x`,
-- `y`), or on the full page's last line (`fullY`).
local NOTHING = { x = 12, y = 40, w = 440 }
local OFF = { x = 246, y = 512, fullX = 12, fullY = 552 }

-- The empty page: where its words begin, the gaps between them, and the
-- pencilled plate on the right (top left, size, the turn it lies at, in
-- degrees, its corners' size and how far past the card) with its margin
-- notes (where they stand, how wide, the ink of their leaders, how far
-- short of what they point to).
local EMPTY = { top = 92, gap = 14, under = 6 }
local SKETCH = { x = RIGHT_X + 8, y = 58, w = 270, h = 190, turn = -1.3, alpha = 0.75, pc = 22, out = 4 }
local NOTES = { x = RIGHT_X + 296, w = 166, leader = 0.55, gap = 6 }

YourDiary.HEAD, YourDiary.ENTRY, YourDiary.LEDGER, YourDiary.PARAPHS, YourDiary.FACES = HEAD, ENTRY, LEDGER, PARAPHS, FACES
YourDiary.SITTINGS = SITTINGS
YourDiary.RIGHT_H, YourDiary.LAYOUT, YourDiary.SNAPSHOT, YourDiary.FULL = RIGHT_H, LAYOUT, SNAPSHOT, FULL
YourDiary.CAPTION, YourDiary.LEADER, YourDiary.LEADERS, YourDiary.STRIPS = CAPTION, LEADER, LEADERS, STRIPS
YourDiary.FOOT, YourDiary.NOTHING, YourDiary.OFF = FOOT, NOTHING, OFF
YourDiary.EMPTY, YourDiary.SKETCH, YourDiary.NOTES = EMPTY, SKETCH, NOTES
