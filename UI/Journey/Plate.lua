-- Your Diary's plates (JRN-14, JRN-21, JRN-22): one window of a zone's map,
-- printed on a card glued into the diary's right page (UI/Journey/Caption.lua
-- lays them out). A close-up shows the art at its own size, one screen
-- pixel to a pixel of the map's art (Decision 3), so every close-up agrees
-- in scale and none is blurred; the full page fits the zone's whole height.
--
-- The card is ns.UI.LooseSheet's, `glued`: one facet of flat card, turned as
-- its slot says, never fallen or put away. Everything on it is placed and
-- turned through the sheet's toolkit (K.Place, K.Quad, K.PlaceButton,
-- K.PlaceText, K.Pool), so it leans with the card. It is a physical print:
-- photo stock with a thickness (THICKNESS: its edges lit and shaded), casting a
-- shadow on the page from its height (SHADOW), the art toned as a print
-- (PLATE, VIGNETTE). What holds it in the book is drawn here (MOUNT, GLUE,
-- LIFT): folded kraft photo corners, glue squeezed out unevenly at its
-- edges, and a corner come unstuck, standing higher, darker and throwing a
-- wider, softer shadow. Laid flat ("Flat paper only"), no turn, shadow,
-- edges, vignette, glue or lift: the corners lie flat.
--
-- What is printed, from the bottom up (the zone sheet's, JRN-14, before
-- the plates replaced it):
--   the map    the window of the zone's art, with the explored areas over it
--              (UI/Map/Art.lua), in a neat line of ink at 65 % (FRAME)
--   the trail  the open level's road and stops as one trail of ink (only
--              the open level's: other levels' roads and marks are left off,
--              10 Oct, where they read as clutter)
--              (UI/Ink/Trail.lua has the arithmetic and its numbers): a road's
--              weight is your pace, a stop's footprint the ground covered,
--              its time the ink. Only roads that meet the window are fed in,
--              cut at its edges (Clip); a stop shows when its middle is in
--              it. A plate smaller than a page has a share of the trail's
--              caps by its area (SHARE). Each pool has a tooltip (no key on
--              the plates, Decision 7): "Quested here, 25 min"
--   deaths     a death's cross on paper at a pool's upper left (no kind's
--              glyph: the tint and the tooltip say what was done there)
--   flights    dashed, in red-brown, cut at the window's edge, from one
--              ring a flight master (DrawFlights)
--   marks      what put the plate there, in ink, at one size on the screen
--              however close the plate (MARK): a level's two ends, where it
--              began (ink round paper) and where the next was reached (a
--              rubric disc), each moved off a pool with a short leader
--              (10 Oct: the level's road from pin to pin), a ring for time
--              together, a crossed stroke for a fight, a slip for a note, a
--              doorway for a dungeon, a hollow lozenge for a first
--              sighting in hindsight (JRN-23), and whatever a feature
--              registers (Plate.RegisterMark)
--              Each has a tooltip (UI/Journey/Text/Tips.lua's, a registered
--              mark's its own `tip`)
-- The page writes the margin notes and draws their pencil leaders (they
-- cross the plate's edge, and the page does not turn): plate.where has each
-- person's mark on the page, through plate:OnPage's transform.
--
-- Drawn once, as the page opens or turns to a level, from pools of
-- textures; nothing per frame, nothing random: the same plate lies the same
-- way after a /reload. The page keeps three plates and hands them the
-- slots it needs (SetSlot), so their textures serve whichever plate is
-- shown, never a new set per plate.

local addonName, ns = ...

local Style = ns.Style
local Trail = ns.UI.InkTrail

-- The card above the page, below the leaders. The card is aged photo
-- stock (`stock`): a warm off-white gone a little yellow, clearly lighter
-- than the page so it reads as a print glued in, never as more page, but
-- never white. The art is printed on it, not shown
-- on a screen: its colour drawn part way to grey (`desaturate`, where the
-- client can: SetDesaturation) and warmed and darkened toward the page by
-- `tint`, or by `plain` where it cannot desaturate (a warmer, darker tint
-- does the work alone). A map's art size where the client will not say (a
-- classic zone).
-- (9 Oct: at { 1, .94, .82 } alone the art stayed sunlit yellow, a screen.
-- 10 Oct: a stock of { .915, .885, .80 } read as near-white, cool card
-- against the parchment, and with the light edge as a white bevel.)
local PLATE = { level = 5, stock = { 0.90, 0.85, 0.70 }, desaturate = 0.35, tint = { 0.97, 0.91, 0.78 },
    plain = { 0.93, 0.85, 0.70 } }
local ART = { w = 1002, h = 668 }
-- The neat line round the art: ink at `alpha`, `inner` px hugging it, then
-- a `gap` and an `outer` hairline, as the mockup's double rule.
local FRAME = { inner = 1.5, gap = 1.5, outer = 1, alpha = 0.65 }
-- The print's edges darken a little, as an old print does: a band `depth`
-- (a share of the art box's shorter side) inside each side of the neat
-- line, in `tint`, from `alpha` at the edge to nothing, each side's alpha
-- given or taken `uneven` of itself (seeded per plate). Darker toward the
-- bottom right, away from the light. Under the ink: the trail, the marks
-- and the pins lie over it, so they read as they did. None laid flat.
local VIGNETTE = { depth = 0.14, tint = { 0.30, 0.20, 0.08 }, uneven = 0.3,
    alpha = { top = 0.08, left = 0.09, bottom = 0.15, right = 0.13 } }

-- The card's thickness: lit from the top left, its top and left cut edges
-- catch the light (a `width` px line `at` px from the card's edge, -1 on
-- the cut itself, over the card's ink outline, in warm `light` at
-- `lightAlpha`: a catch-light, barely there), its bottom and right edges
-- fall away (a line inside them in ink at `darkAlpha`). None laid flat.
-- (10 Oct, in the client: a line inside the edge at .55 read as a white
-- bevel, a picture frame.)
local THICKNESS = { width = 1, at = -1, light = { 1, 0.95, 0.82 }, lightAlpha = 0.22, darkAlpha = 0.32 }
-- The card's shadow on the page, cast from its height as the loose sheet's
-- is (UI/Paper/Sheet.lua's LIFT): gradient bands along its right and bottom
-- edges, turned with the card, never discs or rings (9 Oct, in the
-- client: discs read as rings). Where the card is glued (height 0) it falls
-- `out` px down and to the right and fades out over `blur` px more, from
-- `alpha` under the card's edge; where it stands `h` px off the page (a
-- lifted corner, LIFT.height), `out` + `gain` * h and `blur` + `spread` *
-- h, so the lifted corner's shadow is further out, wider and softer. Over
-- it, a thin `core` where the card touches the page: `out` px of ink at
-- `alpha`, fading to nothing toward a lifted corner (it does not touch
-- there). The two bands meet on a mitre at the bottom right. Their ends
-- at the top right and bottom left start in a slant, soft. A lifted corner
-- reaches at most `out` + `blur` + (`gain` + `spread`) * LIFT.height px past
-- the card: 9.9, inside the page's 10 px margin (the full page's and the
-- three-plate layout's lifted corners lie 10 px from the page's edge).
-- Glued, a dark contact line about 1.5 px and a soft band about 4.5 px; the
-- lifted corner's band is about twice as wide at the same darkness under
-- the card, so it reads as standing off the page. None laid flat.
-- (10 Oct, in the client: at out 1.2, blur 3.4, .20, core .30, a plate
-- looked pasted on, with no thickness.)
local SHADOW = { out = 1.0, blur = 3.5, alpha = 0.28, gain = 0.30, spread = 0.60,
    core = { out = 1.5, alpha = 0.40 } }

-- Photo corners: folded pockets of dark brown kraft (black read as holes
-- in the page, 9 Oct), `out` px past the card's corner, `scale` of the
-- slot's `pc` (the page's LAYOUT), in `ink` at `alpha`, each a shade
-- lighter or darker by `uneven` (seeded). Their diagonal is a fold: lit
-- from the top left, the fold of a lower right corner faces the light and
-- catches it, an upper left one faces away: a `fold` px line along it in
-- `light` at `lo` (facing away) to `hi` (facing the light). Each throws a
-- small shadow `shadow` = { right, down, alpha } in `shade`, so it stands
-- on the page and its fold on the print. Laid flat: the pocket alone. Where
-- corners cannot move, an L of two strips `strip` px wide, no fold.
-- (10 Oct, in the client: at .12 to .75 in { .78, .64, .45 } the fold could
-- not be seen: an upper right or lower left corner, half facing the light,
-- got .44. Now those get .6 in a paler light.)
local MOUNT = { out = 3.5, scale = 0.7, ink = { 0.29, 0.19, 0.105 }, alpha = 0.95, uneven = 0.08,
    fold = 1, light = { 0.88, 0.76, 0.56 }, lo = 0.20, hi = 1.0,
    shadow = { 1.1, 1.4, 0.34 }, shade = { 0.08, 0.05, 0.02 }, strip = 3 }
-- Dried glue squeezed out at the edges, amber, a little darker than the
-- page and glossy: `count` beads (at least, at most) just past the card's
-- edge, on sides drawn from `sides` (mostly the bottom and the right,
-- where the thumb pressed), each `length` (a share of its side, within)
-- and `bead` px at its fattest (within), tapering to nothing at both ends,
-- in `tint` at `alpha` (within) at its middle. They lie over the card's
-- soft shadow and under its contact line, so the shadow does not swallow
-- them. Along its crest a `gloss` line, `width` px, `length` of the bead,
-- in `tint` at `alpha`, brightest at its end toward the light: the gloss
-- is what says glue, never dirt. All seeded per plate (its map and slot),
-- so it is glued the same way every time it opens. Laid flat, none.
-- (9 Oct, in the client: discs of glue read as smudges; a uniform 1.5 px
-- bead at .10 read as nothing. 10 Oct: beads up to 2.6 px at .32 under
-- the shadow, with a .7 px gloss, could not be seen at all.)
local GLUE = {
    tint = { 0.45, 0.31, 0.10 }, count = { 3, 5 }, length = { 0.05, 0.14 }, bead = { 2.0, 3.2 },
    alpha = { 0.32, 0.46 }, sides = { "bottom", "right", "bottom", "right", "top", "bottom", "right", "left" },
    gloss = { tint = { 1, 0.96, 0.82 }, alpha = 0.60, width = 1, length = 0.6 },
}
-- A corner come unstuck: it stands `height` px off the page at the
-- corner, falling to the glued card over `reach` px along both edges
-- (its shadow is SHADOW's, from that height). It slopes away from the
-- top-left light, so `box` of the card at it darkens toward the corner
-- (to about `shade`), enough to be seen as a slope at the book's size.
-- (10 Oct, in the client: at .16 over 40 by 34 px it was not.)
local LIFT = { height = 6, reach = 46, box = { 50, 42 }, shade = { br = 0.28, bl = 0.22 } }
-- Each plate's share of the trail's caps (InkTrail's CAP) by its area
-- against `area` (the one-plate slot), at least `least`: a small plate of
-- three about a third, a lone plate or the full page the whole.
local SHARE = { least = 0.35, area = 440 * 320 }
-- Under the mouse a plate that opens a zone's full page leans in: its
-- picture (the art, the ink and the marks) grows to `scale` about the
-- card's middle over `time` seconds, eased out, and back on leaving; the
-- card, its corners, glue and turn stay as they are. The picture is held
-- in a frame clipped to the box the turned art covers, and a mat of the
-- card's own stock lies over the card's margin (MAT), so what grows past
-- the turned neat line is under card, never over it. Laid flat as well:
-- it is a way of saying "this opens", not wear.
local ZOOM = { scale = 1.16, time = 0.2 }
-- A zone's full page looks closer under the wheel (JRN-14): each notch
-- `step` times as close, toward the point under the cursor, eased over
-- `time` seconds, from the fitted view (the whole height of the zone) to
-- the art's own size (`native`, 1 screen px a px of art: closer only
-- blurs). Each notch draws the picture at once for where the wheel is
-- going (it takes a few ms), its marks and lines at that zoom's size, and
-- eases the drawing in from where it was shown, scaled and shifted, so
-- the ink is right once it is there. A drag only shifts the picture;
-- `settle` seconds after it lets go the picture is drawn again for the
-- new window. Either way the rest of the zone is drawn round it (under the card's
-- margin, clipped) so a drag never runs off the art. No closer than
-- `native`, the whole zone is no more than its art's own size (a zone's
-- 1002 by 668 px), not much more than a window and a margin round it.
local FULLZOOM = { step = 1.25, time = 0.15, settle = 0.25, native = 1, overscan = math.huge }
-- Dragging a full page pans it, fitted too (the fit is the zone's whole
-- height, so most zones run past the card's sides); a press that moves
-- less than `threshold` px is a click, which goes back.
local DRAG = { threshold = 4 }
-- The mat over the card's margin: the card's stock and its grain (as
-- UI/Paper/Sheet.lua lays it), over the picture, under the neat line.
local MAT = { grain = 0.14 }

-- No kind's glyph beside a pool on a plate: at close-up scale the small
-- strokes read as letters (9 Oct, in the client). The ink's tint and the
-- pool's tooltip say what was done there.
-- A death's cross on its dot of paper: `gap` px out from the footprint's
-- edge toward the upper left, so the dot (`dot` across) just touches it.
local DEATH = { gap = 5, dot = 10 }
-- Hover squares over the pools: up to `most` of them, each as wide as its
-- footprint within `size`; a droplet's the least.
local HOVER = { most = 200, size = { 12, 28 } }
-- A level pin moved off a pool: `gap` past its edge, its leader `leader`
-- wide in the pin's colour at `leaderAlpha`. The pin where the level began
-- is paper inside a ring of ink `ring` px wide, its number in ink.
local PIN = { gap = 5, leader = 1.2, leaderAlpha = 0.8, ring = 1.5 }
-- A flight: dashes `dash` long, `gap` apart, `width` wide.
-- Its ends are rings `ring` px across, one a flight master: ends on one
-- map within `node` yards are one node. The take-off is the last spot seen
-- before the taxi (a capture tick is 5 s, so up to a mount's run short of
-- the master), the landing the first after, a little way off the master's
-- feet; two masters in one zone stand hundreds of yards apart.
local FLIGHT = { dash = 5, gap = 4, width = 1.5, alpha = 0.9, ring = 8, node = 50 }
-- The marks: their sizes in pixels on the screen, the paper halo round
-- them, the square that takes the mouse. `first` is the hollow lozenge
-- (wide, tall), its ink `line` px; a note a slip with a corner folded
-- (`fold` px); a door an arch. A level's pin is as wide as its number and
-- `pinPad` more.
-- Marks never touch (9 Oct, in the client: two marks side by side read as
-- letters, "O8", "ΠE"): each keeps `clear` px round itself; one landing on
-- another moves out to the first free place on rings `step` px apart
-- (`tries` rings of eight headings), with a graphite hairline back to
-- where it belongs (`tether`: width, alpha) once it moved past its size.
-- People met on one spot share one mark (`merge` px), the likeliest to
-- matter on top (`first` of PRIORITY), its tooltip telling the rest.
local MARK = { hover = 16, halo = 0.75, together = 11, hole = 5, fight = 10, note = { 8, 10 }, noteTurn = 0.14,
    fold = 3.5, door = 10, pin = 13, pinPad = 5, first = { 8.4, 10.4 }, line = 1.2, clear = 3, step = 7, tries = 4,
    merge = 8, tether = { 0.8, 0.5 } }
-- Two marks only a person's own page puts on its plate (UI/Journal/
-- PersonPlate.lua; the person-page proposal: "trades and /say as a dot",
-- "last seen as a rubric X"): `dot`, a trade or a word said there, an ink
-- dot `dot` px across; `seen`, where they were last seen, a cross of two
-- rubric strokes `seen` px long and `seenWidth` wide. No moment of Your
-- Diary's has either kind, so its plates never draw them.
MARK.dot, MARK.seen, MARK.seenWidth = 6, 9, 2
-- A moment of a kind it does not know (a feature's, joined to a person's
-- marks: a registered mark's `join`) is the least likely to matter.
local PRIORITY = { fight = 1, session = 2, note = 3, first = 4, seen = 5, dot = 6 }
-- A doorway's arch, as shares of its size (MARK.door on a plate; the
-- ledger's margin draws the same, LEDGER.door in UI/Journey/Look.lua):
-- a square `body` `w` wide, `h` tall, its middle `y` below the mark's
-- middle (y down), and a round `head` `size` across, its middle `y` off
-- it. The head's lower half lies in the body, so the two are one arch.
local DOOR = { body = { y = 0.18, w = 0.8, h = 0.62 }, head = { y = -0.1, size = 0.8 } }
-- What a plate marks at most; past it, the rest is left off. The trail's
-- own caps are InkTrail's; a registered mark's (Plate.RegisterMark) is
-- its `cap`, filled in here under its `count` as it registers.
local CAP = { meetings = 150, flights = 40, dashes = 600, dungeons = 30, pins = 80, firsts = 60 }
-- A point this far past the art's edge (px) is still on it; a piece of ink
-- may reach `SPILL` px past it (onto the neat line), and is left off past
-- that: the window cuts a pool its edge crosses, as the art is cut.
local EDGE, SPILL = 0.5, 2

-- No label on a plate: a dungeon's name is in its door's tooltip, as a
-- pool's place is in the pool's (9 Oct, in the client: a name beside its
-- door ran into the marks).

local Plate = {}

local function Clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

--------------------------------------------------------------------------
-- Marks by kind (Plate.RegisterMark)
--------------------------------------------------------------------------

-- A kind of moment with a mark of its own registers it here, so a
-- feature's file (Features/<Name>/, loaded after UI/) adds its mark to
-- every plate, the full zone page's too, without this file knowing of it
-- (.claude/registry-refactor.md, phase 3). The plate draws every
-- registered kind the same way (DrawMoments): the open entry's moments of
-- the kind in the window, those within MARK.merge of each other one mark
-- (its tooltip telling each), at most `cap` marks, each stepped clear of
-- the marks already down (Apart) and laid on a round halo of paper, then
-- the kind's own shape, a hover square, the marks kept for the margin and
-- the plate's one card of the kind chosen from them.
-- What stays bespoke in DrawMoments is what is not one mark a spot of one
-- kind: the doors, the levels' pins, the people's shared marks (PRIORITY
-- picks the one on top) and the death crosses (on a pool's edge, or on
-- the road).
--
-- `spec`:
--   order    a number, lowest drawn first. A mark down keeps its place and
--            the later ones step round it (Apart, with a tether), so the
--            order says which matter most where they crowd. Today's:
--            the deaths on the road (ROAD_DEATHS, 60, core); a kind registered
--            from Features/<Name>/ says its number there (filler goes after
--            the deaths on the road, last of all). Leave gaps; equal orders draw in the
--            order they registered. All of them after the doors, pins
--            and people (which are core and come first).
--   cap      how many marks of it a plate draws at most; past it the rest
--            is left off. Kept in CAP under `count` (Plate.CAP[count]).
--   count    its key in plate.counts (how many marks were drawn) and in
--            CAP. The plural names the tests know, never the kind's
--            (a feature's Mark.lua says its own).
--   radius   the room the mark claims (Apart's r, Radius(kind)): about
--            half its height, a px or two more.
--   halo     the size of the round paper laid under it (MARK.halo), so it
--            reads over the art; false where the shape lays its own paper
--            (on a dot of paper as a death's cross is: kit.halo).
--   hover    the size of its hover square (MARK.hover where nil).
--   draw     function(kit, x, y, arg): the mark round x, y on the card,
--            only through the kit (below), so it turns and is lit with
--            the card and its textures come from the plate's pools.
--   arg      optional function(list) → draw's `arg`, from the moments
--            merged on the spot (say, the best of their records, or the
--            ink it is drawn in); it may sort `list` (the order the kept
--            mark and the tooltip have).
--   tip      function(m, now) → title, lines: each moment's words under
--            the mouse (the feature's Text.lua's, looked up when asked:
--            it loads after this file).
--   keep     optional: the plate field its marks are kept in, a list of
--            { x, y (on the card), list (the moments on it), at = { px, py }
--            (on the page, for a margin card's leader), arg (draw's) }:
--            plate.<keep>.
--   join     optional function(m) → true where a moment on the mark is
--            someone's too (m.guid: something they gave you) and joins
--            their marks: kept in plate.where (its mark on the page) and
--            plate.people, as a person's own moments are, so it joins
--            their margin note (the moment's `person` says how: Core/
--            JourneyRecap.lua's RegisterMoment) and their note's leader
--            may come to this mark.
--   chosen, choose   optional: plate[chosen] = choose(marks, plate), the
--            plate's one card of the kind, chosen as soon as its marks are
--            down (plate[chosen]). A card chosen
--            with the killer's, after every mark, is a pass's instead
--            (Plate.RegisterPass).
--
-- The kit a `draw` gets, one a plate (built in New, as a pass's over-kit
-- is), closed over the card's toolkit:
--   ink, inner, halo   the marks' pools: the ink (OVERLAY 0), the paper
--                      inside it (OVERLAY 1), the paper under it (ARTWORK
--                      7, the halos')
--   Dot(pool, x, y, size, colour, alpha), Box(pool, x, y, w, h, colour,
--   alpha, turn), Stroke(pool, x1, y1, x2, y2, width, colour, alpha)
--                      a disc, a box, a stroke, lit where they lie; each
--                      returns its texture (Stroke nil for no length)
--   Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4)   flat ink with its
--                      corners on the card; false where the client cannot
--                      move corners, and the shape draws its fallback
--   Place(texture, x, y, w, h, turn), Fill(texture, r, g, b, a),
--   Light(x, y) (the card's light there, to multiply a colour by),
--   Clamp(v, lo, hi)
--   P, INK, INK_STRONG  the paper and the inks (Style's)
local ROAD_DEATHS = 60
local markKinds = ns.Registry.New({
    what = "Plate.RegisterMark(kind, { draw = function(kit, x, y, arg) ... })",
    key = "kind", order = "order", default = 100,
    check = function(kind, spec) return type(spec.draw) == "function" end,
})
-- The core's own turns among them (DrawMoments says what each draws):
-- the doors, the levels' pins and the people's marks before every kind,
-- and the deaths on the road at ROAD_DEATHS, after any kind that shares
-- the number (none should: tests/kinds.lua) and before the first past it.
markKinds:Core("core", { order = -math.huge }, -1)
markKinds:Core("roadDeaths", { order = ROAD_DEATHS }, 1)
local MARKS, MARK_ORDER, MARK_ALL = markKinds.specs, markKinds.list, markKinds:Ordered()

function Plate.RegisterMark(kind, spec)
    markKinds:Add(kind, spec)
    if spec.count and spec.cap then CAP[spec.count] = spec.cap end
    return spec
end
-- Takes a kind's marks off every plate again (a test's own kind), its cap
-- with it.
function Plate.RemoveMark(kind)
    local old = markKinds:Remove(kind)
    if old and old.count and CAP[old.count] == old.cap then CAP[old.count] = nil end
end
-- For the tests: the registered kinds, and their order.
Plate.MARKS, Plate.MARK_ORDER, Plate.ROAD_DEATHS = MARKS, MARK_ORDER, ROAD_DEATHS

--------------------------------------------------------------------------
-- Passes after the marks (Plate.RegisterPass)
--------------------------------------------------------------------------

-- What a feature does on a plate once every mark is down, that is not a
-- mark of its own: say, what it learns from the death crosses (the
-- route's, drawn here) and the plate's one card it chooses from that; or
-- something it lays over the picture, on the frame the mat and the photo
-- corners are on (a slip glued across a light plate's print). The crosses
-- stay the plate's: their shape, their place, the deaths each counts; a
-- pass only reads them, puts its own fields on them and on the plate, and
-- may hang a tooltip over a cross.
--
-- `spec`:
--   order    a number, lowest first; equal orders in the order they
--            registered. A later pass reads what an earlier one left on
--            the plate (and may clear it: a witness's card takes the place
--            of the card it replaces). Each feature says its number where
--            it registers. Leave gaps.
--   draw     function(plate, c): `c`, one a drawing:
--              crosses   the death crosses drawn (plate.crosses): { x, y
--                        (on the card), segs (the stops or the road it
--                        marks), count (the deaths it counts) }
--              mapID, entry, now, opts   as plate:Draw has them
--              At(x, y)      a map point (0..1) on the card, nil off the
--                            window
--              OnPage(x, y)  a card point on the page (a margin card's
--                            leader ends there)
--              Tip(title, lines)  a tooltip as Style.Tooltip takes it
--              HoverCross(cross, fn)  a hover square over a cross, the
--                            cross's own size, fn() → Tip's list
--   new      optional function(plate, kit): once for each plate made after
--            it registered, while the plate is made (in the passes'
--            order), for a pass that draws over the picture: it makes its
--            pools and buttons there and keeps them (on the plate, or its
--            own table by plate). `kit`:
--              over      the frame over the picture (the mat, the neat
--                        line, the lifted corner's shade at OVERLAY 5 and
--                        the photo corners over it: a pass's layers go
--                        between, ARTWORK 4 to OVERLAY 4, under the shade)
--              Pool(layer, sublevel)  a pool of textures on `over`
--                        (pool:Next()), begun and finished with every
--                        drawing and counted in plate.counts.textures
--              TextPool(font, layer, sublevel)  a pool of font strings
--                        on `over`, likewise
--              Button()  a button on `over`, hidden, a press on it the
--                        plate's (click, drag); square, as it cannot turn
--              Place, Quad, PlaceButton   the card's toolkit (K's): a
--                        texture or a button placed on the card, a quad
--                        with its corners on the card
--              Tip(title, lines)  a tooltip as Style.Tooltip takes it
--            Its `draw` then draws through what it kept, every drawing,
--            and hides what it does not use (the pools hide the rest).
local passKinds = ns.Registry.New({
    what = "Plate.RegisterPass(key, { order, draw = function(plate, c) ... })",
    key = "key", order = "order", default = 100,
    check = function(key, spec) return type(spec.draw) == "function" end,
})
local PASSES, PASS_ORDER = passKinds.specs, passKinds.list

function Plate.RegisterPass(key, spec)
    return passKinds:Add(key, spec)
end
-- Takes a pass out again (a test's own).
function Plate.RemovePass(key)
    passKinds:Remove(key)
end
-- For the tests: the registered passes, and their order.
Plate.PASSES, Plate.PASS_ORDER = PASSES, PASS_ORDER

--------------------------------------------------------------------------
-- Windows (Decision 3)
--------------------------------------------------------------------------

-- A map's art size in its own pixels, remembered (it never changes), and
-- whether the client said; ART where it did not.
local layers = {}
local function LayerSize(mapID)
    local hit = layers[mapID]
    if hit == nil then
        local list = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
        local layer = list and list[1]
        local LW, LH = layer and ns.Plain(layer.layerWidth), layer and ns.Plain(layer.layerHeight)
        hit = type(LW) == "number" and LW > 0 and type(LH) == "number" and LH > 0 and { LW, LH } or false
        layers[mapID] = hit
    end
    if hit then return hit[1], hit[2], true end
    return ART.w, ART.h, false
end
Plate.LayerSize = LayerSize

-- How much of `mapID`'s map (0..1 each way) a close-up of aw by ah pixels
-- covers: Recap.Plates's `cover`.
function Plate.Cover(mapID, aw, ah)
    local LW, LH = LayerSize(mapID)
    return aw / LW, ah / LH
end

-- The window { x0, y0, x1, y1 } (0..1 of the map) an aw by ah art box
-- shows, centred on cx, cy as far as the map's edges allow: at the art's
-- own size, or with `fit` the map's whole height (the full page).
function Plate.Window(mapID, cx, cy, aw, ah, fit)
    local LW, LH = LayerSize(mapID)
    local scale = fit and ah / LH or 1
    local w, h = aw / scale / LW, ah / scale / LH
    local x0 = w >= 1 and (1 - w) / 2 or Clamp((cx or 0.5) - w / 2, 0, 1 - w)
    local y0 = h >= 1 and (1 - h) / 2 or Clamp((cy or 0.5) - h / 2, 0, 1 - h)
    return { x0, y0, x0 + w, y0 + h }
end

-- The part of the line from (x1, y1) to (x2, y2) inside the box bx0..bx1
-- by by0..by1 (Liang-Barsky), and where along it that part starts and
-- ends (0..1); nil when none of it is.
local function Clip(x1, y1, x2, y2, bx0, by0, bx1, by1)
    local t0, t1 = 0, 1
    local dx, dy = x2 - x1, y2 - y1
    for _, edge in ipairs({ { -dx, x1 - bx0 }, { dx, bx1 - x1 }, { -dy, y1 - by0 }, { dy, by1 - y1 } }) do
        local p, q = edge[1], edge[2]
        if p == 0 then
            if q < 0 then return nil end
        else
            local r = q / p
            if p < 0 then
                if r > t1 then return nil end
                if r > t0 then t0 = r end
            else
                if r < t0 then return nil end
                if r < t1 then t1 = r end
            end
        end
    end
    return x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy, t0, t1
end
Plate.Clip = Clip

-- `road`'s pieces inside the window, onto `out`: the road itself when it
-- lies wholly inside, else one copy per stretch inside, its points cut at
-- the edge and its time shared out by length, so its pace stays its own
-- and only a piece that starts or ends where the road did joins a stop.
local function Pieces(road, w, out)
    local pts = ns.Journey.Points(road)
    local n = #pts / 2
    if n < 2 then return end
    local lx, hx, ly, hy = math.huge, -math.huge, math.huge, -math.huge
    for k = 1, #pts - 1, 2 do
        lx, hx = math.min(lx, pts[k]), math.max(hx, pts[k])
        ly, hy = math.min(ly, pts[k + 1]), math.max(hy, pts[k + 1])
    end
    if hx < w[1] or lx > w[3] or hy < w[2] or ly > w[4] then return end
    if lx >= w[1] and hx <= w[3] and ly >= w[2] and hy <= w[4] then
        out[#out + 1] = road
        return
    end
    local total = 0
    for k = 1, #pts - 3, 2 do total = total + math.sqrt((pts[k + 2] - pts[k]) ^ 2 + (pts[k + 3] - pts[k + 1]) ^ 2) end
    local from, to = road.from or 0, road.to or road.from or 0
    local function When(s) return total > 0 and from + (to - from) * s / total or from end
    local piece, start, s = nil, 0, 0
    local function Close(at)
        if piece and #piece >= 4 then
            out[#out + 1] = { kind = "road", mapID = road.mapID, from = When(start), to = When(at), act = road.act,
                levelFrom = road.levelFrom, levelTo = road.levelTo, pts = piece, of = road }
        end
        piece = nil
    end
    for k = 1, #pts - 3, 2 do
        local x1, y1, x2, y2 = pts[k], pts[k + 1], pts[k + 2], pts[k + 3]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local cx1, cy1, cx2, cy2, t0, t1 = Clip(x1, y1, x2, y2, w[1], w[2], w[3], w[4])
        if cx1 then
            if not piece then piece, start = { cx1, cy1 }, s + t0 * len end
            piece[#piece + 1], piece[#piece + 2] = cx2, cy2
            if t1 < 1 then Close(s + t1 * len) end
        else
            Close(s)
        end
        s = s + len
    end
    Close(s)
end
Plate.Pieces = Pieces

-- Whether a segment, a mark or a moment falls in the open entry's time:
-- drawn, or else left off.
local function During(from, to, entry)
    if not entry then return true end
    if to and to > from then return from < entry.to and to > entry.from end
    return from >= entry.from and from < entry.to
end

-- The tooltip a mark shows: a title and lines (JourneyText's), the way
-- Style.Tooltip takes them.
local function Tip(title, lines)
    if not title or title == "" then return nil end
    local list = { { title } }
    for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
    return list
end

--------------------------------------------------------------------------
-- A plate
--------------------------------------------------------------------------

-- `parent` is the frame the slots are measured on (the right page), `slot`
-- one of the page's LAYOUT entries: x, y (its top left), w, h, t (its turn
-- in degrees, clockwise), pad (the card's margin round the art), pc (the
-- corners' size), corners ({ "tl", ... }) and lift ("br", "bl" or nil).
local function New(parent, slot)
    -- The words, from UI/Journey/Text/, which loads after this file.
    local Text = ns.UI.JourneyText
    local P, INK, INK_STRONG = Style.PAPER, Style.INK, Style.INK_STRONG

    local view, K = ns.UI.LooseSheet(parent, slot.w, slot.h,
        { glued = true, level = PLATE.level, paper = PLATE.stock, shadows = {} })
    local plate = view
    local S = view.sheet
    local Place, PlaceButton, PlaceText, Width = K.Place, K.PlaceButton, K.PlaceText, K.Width
    local Pool, Split, Bend, Quad, Light = K.Pool, K.Split, K.Bend, K.Quad, K.Light
    plate.counts = {}

    -- The picture's frames (ZOOM): `clip` over the box the turned art
    -- covers, taking the mouse for the hover and the click; `content` in
    -- it, holding the art, the ink and the marks, scaled to zoom (they are
    -- anchored to the card's middle, so they grow about it). `over` lies
    -- above both: the mat, the neat line, the lifted corner's shade and the
    -- photo corners, which do not zoom.
    local clip = CreateFrame("Frame", nil, S)
    clip:SetPoint("CENTER", S, "CENTER")
    clip:SetClipsChildren(true)
    local content = CreateFrame("Frame", nil, clip)
    content:SetAllPoints(clip)
    -- What the picture is placed about: the card's middle, shifted to pan
    -- (FULLZOOM). Unscaled, in the clip.
    local pivot = CreateFrame("Frame", nil, clip)
    pivot:SetSize(1, 1)
    pivot:SetPoint("CENTER", S, "CENTER")
    content.anchorTo = pivot
    plate.pivot = pivot
    local over = CreateFrame("Frame", nil, S)
    over:SetAllPoints(S)
    over:SetFrameLevel(S:GetFrameLevel() + 6)
    plate.clip, plate.content, plate.over = clip, content, over

    ----------------------------------------------------------------------
    -- Pools, from under the card up

    -- On the page under the card (the card's paper is BACKGROUND -5, its
    -- ink edge -6): the card's soft shadow, the glue's beads over it (the
    -- shadow swallowed them), and the shadow's core where the card touches.
    -- The glue's gloss lies outside the card, so it is drawn on the frame
    -- over the card (under everything there), sure to be over the core.
    local shadowPool = Pool("BACKGROUND", -8)
    local gluePool = Pool("BACKGROUND", -7)
    local corePool = Pool("BACKGROUND", -6)
    local backgroundPool = Pool("BORDER", 1, nil, content)
    local tilePool = Pool("BORDER", 2, nil, content)
    local exploredPool = Pool("BORDER", 3, nil, content)
    -- The print's darkened edges, over the art and under all the ink;
    -- placed about the card's middle, not the picture's, so they stay at
    -- the neat line while a full page pans (VIGNETTE).
    local vignettePool = Pool("BORDER", 4, function(t) t.anchorTo = nil end, content)
    plate.vignettes = vignettePool
    -- The trail: a pool of quads and one of discs for each of its layers
    -- (InkTrail's LAYER), quads and discs apart, so a texture is always the
    -- one thing.
    local trailQuads, trailDiscs, trailPools = {}, {}, {}
    for _, name in ipairs({ "wash", "halo", "road", "dab", "rim", "spatter", "nib" }) do
        local sublevel = Trail.LAYER[name]
        trailQuads[sublevel], trailDiscs[sublevel] = Pool("ARTWORK", sublevel, nil, content),
            Pool("ARTWORK", sublevel, nil, content)
        trailPools[#trailPools + 1] = trailQuads[sublevel]
        trailPools[#trailPools + 1] = trailDiscs[sublevel]
    end
    local dashPool = Pool("ARTWORK", 2, nil, content)
    local washPool = Pool("ARTWORK", 5, nil, content)
    local pinPool = Pool("ARTWORK", 6, nil, content)
    local leaderPool = Pool("ARTWORK", 6, nil, content)
    local markHaloPool = Pool("ARTWORK", 7, nil, content)
    local markPool = Pool("OVERLAY", 0, nil, content)
    local markInnerPool = Pool("OVERLAY", 1, nil, content)
    -- Over the picture: the mat on the margin, the neat line, a lifted
    -- corner's shade, and the photo corners holding the card down. The
    -- shade lies over all that a pass lays over the picture (OVERLAY 4 and
    -- under: its `new`, below), so a slip glued on it slopes away from the
    -- light with it.
    local glossPool = Pool("BACKGROUND", -8, nil, over)
    local matPool = Pool("BACKGROUND", 0, nil, over)
    local matGrainPool = Pool("BORDER", 0, nil, over)
    local edgePool = Pool("ARTWORK", 1, nil, over)
    local framePool = Pool("ARTWORK", 3, nil, over)
    local liftShadePool = Pool("OVERLAY", 5, nil, over)
    local cornerShadowPool = Pool("OVERLAY", 6, nil, over)
    local cornerPool = Pool("OVERLAY", 7, nil, over)
    -- The light on the corners' folds, over the pockets: a frame of its
    -- own a level up, as the pockets take the top sublevel.
    local folds = CreateFrame("Frame", nil, S)
    folds:SetAllPoints(S)
    folds:SetFrameLevel(S:GetFrameLevel() + 7)
    local foldPool = Pool("OVERLAY", 0, nil, folds)
    plate.folds = folds

    -- Font strings and hover squares, handed out like the textures. On the
    -- picture (placed about its pivot) unless given a `frame`, a `layer` and
    -- `sublevel` on it.
    local function TextPool(font, frame, layer, sublevel)
        local pool = { used = 0 }
        function pool:Begin() self.used = 0 end
        function pool:Next()
            self.used = self.used + 1
            local text = self[self.used]
            if not text then
                text = Style.Text(frame or content, font, layer)
                if sublevel then text:SetDrawLayer(layer, sublevel) end
                if not frame then text.anchorTo = pivot end
                self[self.used] = text
            end
            text:Show()
            return text
        end
        function pool:Finish()
            for i = self.used + 1, #self do self[i]:Hide() end
        end
        return pool
    end
    local numberPool = TextPool(Style.FONT.tag)

    -- A hover square passes a click on to the plate: a mark is part of it.
    local hoverPool = { used = 0 }
    function hoverPool:Begin() self.used = 0 end
    function hoverPool:Next(x, y, tip, size)
        size = size or MARK.hover
        self.used = self.used + 1
        local button = self[self.used]
        if not button then
            button = CreateFrame("Button", nil, content)
            button.anchorTo = pivot
            button:EnableMouse(true)
            Style.Tooltip(button, function(b) return b.tip and b.tip() end)
            -- A press on a mark is a press on the plate: a click opens or
            -- goes back, a drag pans.
            button:SetScript("OnMouseDown", function(_, which) plate:Press(which) end)
            button:SetScript("OnMouseUp", function(_, which) plate:Release(which) end)
            -- Over a mark the plate stays leaned in (ZOOM).
            button:HookScript("OnEnter", function() plate:Lean() end)
            button:HookScript("OnLeave", function() plate:Lean() end)
            self[self.used] = button
        end
        button.tip = tip
        PlaceButton(button, x - size / 2, y - size / 2, size, size)
        button:Show()
        return button
    end
    function hoverPool:Finish()
        for i = self.used + 1, #self do
            self[i].tip = nil
            self[i]:Hide()
        end
    end

    -- For the tests: the hover squares and their tooltips.
    plate.hover = hoverPool

    -- What the passes lay over the picture (Plate.RegisterPass's `new`):
    -- their pools on the frame over it, between the neat line and the
    -- lifted corner's shade, begun, finished and counted with the plate's
    -- own; and buttons there that take the mouse without leaning in
    -- (square, as they cannot turn), a press on them a press on the plate.
    -- Each pass's `new` is asked here, in the passes' order, as the plate
    -- is made.
    local overPools, overTexts = {}, {}
    local overKit = { over = over, Place = Place, Quad = Quad, PlaceButton = PlaceButton, Tip = Tip }
    function overKit.Pool(layer, sublevel)
        local pool = Pool(layer, sublevel, nil, over)
        overPools[#overPools + 1] = pool
        return pool
    end
    function overKit.TextPool(font, layer, sublevel)
        local pool = TextPool(font, over, layer, sublevel)
        overTexts[#overTexts + 1] = pool
        return pool
    end
    function overKit.Button()
        local button = CreateFrame("Button", nil, over)
        button:EnableMouse(true)
        button:SetScript("OnMouseDown", function(_, which) plate:Press(which) end)
        button:SetScript("OnMouseUp", function(_, which) plate:Release(which) end)
        button:Hide()
        return button
    end
    for _, spec in ipairs(PASS_ORDER) do
        if spec.new then spec.new(plate, overKit) end
    end

    local TEXTURES = { gluePool, shadowPool, glossPool, corePool, backgroundPool, tilePool, exploredPool,
        vignettePool, dashPool, edgePool, framePool, liftShadePool, washPool, pinPool, leaderPool,
        markHaloPool, markPool, markInnerPool, cornerShadowPool, cornerPool, foldPool, matPool, matGrainPool }
    for _, pool in ipairs(trailPools) do TEXTURES[#TEXTURES + 1] = pool end
    for _, pool in ipairs(overPools) do TEXTURES[#TEXTURES + 1] = pool end
    local ALL = { numberPool, hoverPool }
    for _, pool in ipairs(TEXTURES) do ALL[#ALL + 1] = pool end
    for _, pool in ipairs(overTexts) do ALL[#ALL + 1] = pool end

    ----------------------------------------------------------------------
    -- Marking the card

    -- A flat colour; a reused texture may have been a disc, tinted.
    local function Fill(texture, r, g, b, a)
        texture:SetColorTexture(r, g, b, a)
        texture:SetVertexColor(1, 1, 1, 1)
    end

    -- A round mark of `size` at x, y, lit where it lies.
    local function Dot(pool, x, y, size, colour, alpha)
        local texture = pool:Next()
        local light = Light(x, y)
        -- Without the circle art a disc is a flat square, untinted.
        texture:SetVertexColor(1, 1, 1, 1)
        Style.Disc(texture, colour[1] * light, colour[2] * light, colour[3] * light, alpha)
        Place(texture, x - size / 2, y - size / 2, size, size)
        return texture
    end

    -- A box of w by h with its middle at x, y, turned `turn` more than
    -- the card.
    local function Box(pool, x, y, w, h, colour, alpha, turn)
        local texture = pool:Next()
        local light = Light(x, y)
        Fill(texture, colour[1] * light, colour[2] * light, colour[3] * light, alpha)
        Place(texture, x - w / 2, y - h / 2, w, h, turn)
        return texture
    end

    -- A straight stroke from one point of the card to another, `width`
    -- wide: a texture as long as the gap, turned to it. On the screen y runs
    -- up and SetRotation turns counter-clockwise, so the card's y (down) is
    -- negated. A hair longer than the gap, so strokes meet.
    local function Stroke(pool, x1, y1, x2, y2, width, colour, alpha)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.01 then return nil end
        local texture = pool:Next()
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        local light = Light(mx, my)
        Fill(texture, colour[1] * light, colour[2] * light, colour[3] * light, alpha)
        Place(texture, mx - (length + 0.6) / 2, my - width / 2, length + 0.6, width, math.atan2(-dy, dx))
        return texture
    end

    -- One of the trail's primitives (UI/Ink/Pen.lua) on `texture`. A quad
    -- is flat ink with its corners on the card (K.Quad), or, where the
    -- client cannot move corners, a turned rectangle along its middle line:
    -- false then. A disc is the circle art, turned with its footprint.
    local function DrawPrim(prim, texture)
        if prim.k == "q" then
            local light = Light((prim.x1 + prim.x2 + prim.x3 + prim.x4) / 4, (prim.y1 + prim.y2 + prim.y3 + prim.y4) / 4)
            Fill(texture, prim.r * light, prim.g * light, prim.b * light, prim.a)
            if Quad(texture, prim.x1, prim.y1, prim.x2, prim.y2, prim.x3, prim.y3, prim.x4, prim.y4) then return true end
            -- From the middle of its start (upper and lower left) to the
            -- middle of its end, as wide as it is on average.
            local sx, sy = (prim.x1 + prim.x4) / 2, (prim.y1 + prim.y4) / 2
            local ex, ey = (prim.x2 + prim.x3) / 2, (prim.y2 + prim.y3) / 2
            local dx, dy = ex - sx, ey - sy
            local length = math.sqrt(dx * dx + dy * dy)
            local width = (math.sqrt((prim.x1 - prim.x4) ^ 2 + (prim.y1 - prim.y4) ^ 2)
                + math.sqrt((prim.x2 - prim.x3) ^ 2 + (prim.y2 - prim.y3) ^ 2)) / 2
            local mx, my = (sx + ex) / 2, (sy + ey) / 2
            Place(texture, mx - length / 2, my - width / 2, length, width, math.atan2(-dy, dx))
            return false
        end
        local light = Light(prim.x, prim.y)
        -- Without the circle art a disc is a flat square, untinted.
        texture:SetVertexColor(1, 1, 1, 1)
        Style.Disc(texture, prim.r * light, prim.g * light, prim.b * light, prim.a)
        Place(texture, prim.x - prim.rx, prim.y - prim.ry, 2 * prim.rx, 2 * prim.ry, -prim.th)
        return true
    end

    -- The core marks, each drawn round x, y with the pools given (ink, and
    -- its paper inside). A registered kind's shape is its spec's `draw`,
    -- with its registration at the foot of this file (Plate.RegisterMark).
    local SHAPES = {}

    -- A death: a small cross on a dot of paper.
    function SHAPES.death(ink, _, x, y, halo)
        if halo then Dot(halo, x, y, DEATH.dot, P, 0.85) end
        Box(ink, x, y + 0.5, 1.8, 8, INK_STRONG, 1)
        Box(ink, x, y - 1.5, 5.5, 1.8, INK_STRONG, 1)
    end
    -- A dungeon: the dark arch of its doorway, a round head on a square
    -- foot (never the posts and lintel, which read as a letter), as DOOR.
    function SHAPES.dungeon(ink, _, x, y)
        local d, B, D = MARK.door, DOOR.body, DOOR.head
        Box(ink, x, y + d * B.y, d * B.w, d * B.h, INK_STRONG, 1)
        Dot(ink, x, y + d * D.y, d * D.size, INK_STRONG, 1)
    end
    function SHAPES.pin(ink, _, x, y, size)
        Dot(ink, x, y, size or MARK.pin, Style.RUBRIC, 0.92)
    end
    function SHAPES.session(ink, inner, x, y)
        Dot(ink, x, y, MARK.together, INK_STRONG, 0.95)
        Dot(inner, x, y, MARK.hole, P, 1)
    end
    function SHAPES.fight(ink, _, x, y)
        local f = MARK.fight
        Stroke(ink, x - f / 2, y - f / 2, x + f / 2, y + f / 2, 2, Style.ACCENT, 1)
        Stroke(ink, x - f / 2, y + f / 2, x + f / 2, y - f / 2, 2, Style.ACCENT, 1)
    end
    -- A note: a slip, a little turned, its upper right corner folded down
    -- in paper where corners can move (no lines on it: they read as "8").
    function SHAPES.note(ink, inner, x, y)
        local w, h, f, t = MARK.note[1], MARK.note[2], MARK.fold, MARK.noteTurn
        Box(ink, x, y, w, h, INK, 0.95, t)
        -- The slip's own turn on the card, y down (Place turns it the
        -- other way on the screen, where y runs up).
        local c, s = math.cos(t), math.sin(t)
        local function At(u, v) return x + u * c + v * s, y - u * s + v * c end
        local x1, y1 = At(w / 2 - f, -h / 2)
        local xc, yc = At(w / 2, -h / 2)
        local x2, y2 = At(w / 2, -h / 2 + f)
        local fold = inner:Next()
        Fill(fold, P[1], P[2], P[3], 0.95)
        if not Quad(fold, x1, y1, xc, yc, x2, y2, x2, y2) then fold:Hide() end
    end
    -- A first sighting (JRN-23): a hollow lozenge, ink round paper. Its
    -- corners on the card where they can move; else a square turned on its
    -- point, a little smaller.
    local function Lozenge(pool, x, y, hw, hh, colour, alpha)
        local texture = pool:Next()
        Fill(texture, colour[1], colour[2], colour[3], alpha)
        if not Quad(texture, x, y - hh, x + hw, y, x, y + hh, x - hw, y) then
            local side = (hw + hh) / math.sqrt(2)
            Place(texture, x - side / 2, y - side / 2, side, side, math.pi / 4)
        end
    end
    function SHAPES.first(ink, inner, x, y)
        local hw, hh, t = MARK.first[1] / 2, MARK.first[2] / 2, MARK.line
        Lozenge(ink, x, y, hw + t, hh + t * hh / hw, INK_STRONG, 1)
        Lozenge(inner, x, y, hw, hh, P, 0.95)
    end
    -- A person's page's own (MARK.dot, MARK.seen): a dot of ink, and the
    -- rubric cross of where they were last seen.
    function SHAPES.dot(ink, _, x, y)
        Dot(ink, x, y, MARK.dot, INK_STRONG, 0.95)
    end
    function SHAPES.seen(ink, _, x, y)
        local h = MARK.seen / 2
        Stroke(ink, x - h, y - h, x + h, y + h, MARK.seenWidth, Style.RUBRIC, 1)
        Stroke(ink, x - h, y + h, x + h, y - h, MARK.seenWidth, Style.RUBRIC, 1)
    end
    -- The paper round a mark, so it reads over the art.
    local function Halo(x, y, size, round)
        if round then
            Dot(markHaloPool, x, y, size, P, MARK.halo)
        else
            Box(markHaloPool, x, y, size, size, P, MARK.halo * 0.8)
        end
    end

    -- What a registered mark draws with (Plate.RegisterMark's kit): the
    -- marks' pools and the card's own strokes, so it turns and is lit with
    -- the card.
    local kit = { ink = markPool, inner = markInnerPool, halo = markHaloPool, Dot = Dot, Box = Box, Stroke = Stroke,
        Quad = Quad, Place = Place, Fill = Fill, Light = Light, Clamp = Clamp, P = P,
        INK_STRONG = INK_STRONG }

    ----------------------------------------------------------------------
    -- The mount: the card's thickness and shadow, glue, a lifted corner,
    -- photo corners

    local Noise = Style.Noise

    -- What a plate's unevenness grows from: its map and its slot, so the
    -- same plate is glued the same way every time it opens.
    local function Seed()
        local s = plate.slot
        return (plate.mapID or 0) * 0.618 + (s.x or 0) * 1.37 + (s.y or 0) * 2.11 + s.w * 0.07 + s.h * 0.13
    end

    -- A texture over four points of the card (K.Quad); where the client
    -- cannot move corners, the box x, y, w, h placed whole instead. Says
    -- which it was.
    local function QuadOr(texture, x1, y1, x2, y2, x3, y3, x4, y4, x, y, w, h)
        if Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4) then return true end
        Place(texture, x, y, w, h)
        return false
    end

    -- How high the card stands at a point of its edge: a lifted corner's
    -- LIFT.height, falling to nothing over LIFT.reach along either edge
    -- that meets there; 0 where it is glued.
    local function Height(x, y)
        local s = plate.slot
        if not s.lift then return 0 end
        local d = math.max(math.abs(x - (s.lift == "br" and s.w or 0)), math.abs(y - s.h))
        return LIFT.height * math.max(0, 1 - d / LIFT.reach)
    end

    -- How far out the shadow falls at a height, and how far it blurs.
    local function Fall(h)
        return SHADOW.out + SHADOW.gain * h, SHADOW.blur + SHADOW.spread * h
    end

    -- Where along an edge `length` long the card's height changes: its two
    -- ends, and where a lifted corner's reach ends (`at` the start or the
    -- end of the edge, or nil).
    local function Stations(length, at)
        local reach = math.min(LIFT.reach, length)
        if at == "end" then return { 0, length - reach, length } end
        if at == "start" then return { 0, reach, length } end
        return { 0, length }
    end

    -- The card's shadow on the page (SHADOW): a soft band and a core
    -- along its bottom and its right edge, in pieces between the stations,
    -- each piece's ends falling from their height. The bands meet on a
    -- mitre at the bottom right; their other ends start in a slant. A
    -- piece is a gradient across (soft) or along (core) and turns with the
    -- card. Returns how many pieces stand off the page (a lifted corner's).
    local function CastShadow(W, H)
        local lift, I, C = plate.slot.lift, INK, SHADOW.core
        local c = C.out
        local lifted = 0

        -- A point of an edge's soft band, from a station: its inner end
        -- (under the card) and its outer end, out and blurred.
        local function BottomSoft(x, first, last)
            local d, b = Fall(Height(x, H))
            if last then return W - 1, H - 1, W + d + b, H + d + b, d + b end
            if first then return d + b, H - 1, d, H + d + b, d + b end
            return x + d, H - 1, x + d, H + d + b, d + b
        end
        local function RightSoft(y, first, last)
            local d, b = Fall(Height(W, y))
            if last then return W - 1, H - 1, W + d + b, H + d + b, d + b end
            if first then return W - 1, d + b, W + d + b, d, d + b end
            return W - 1, y + d, W + d + b, y + d, d + b
        end
        -- The core where the card touches: as dark as it touches.
        local function Touch(x, y)
            return C.alpha * (1 - Height(x, y) / LIFT.height)
        end
        local function BottomCore(x, first, last)
            if last then return W - 1, H - 1, W + c, H + c end
            if first then return 0.5 + c, H - 1, 0.5, H + c end
            return x, H - 1, x, H + c
        end
        local function RightCore(y, first, last)
            if last then return W - 1, H - 1, W + c, H + c end
            if first then return W - 1, 0.5 + c, W + c, 0.5 end
            return W - 1, y, W + c, y
        end

        -- Along the bottom.
        local xs = Stations(W, lift == "br" and "end" or lift == "bl" and "start" or nil)
        for k = 1, #xs - 1 do
            local first, last = k == 1, k == #xs - 1
            local ix1, iy1, ox1, oy1, r1 = BottomSoft(xs[k], first, false)
            local ix2, iy2, ox2, oy2, r2 = BottomSoft(xs[k + 1], false, last)
            local soft = shadowPool:Next()
            -- VERTICAL runs from the bottom up: clear outside, dark inside.
            Style.Shade(soft, "VERTICAL", I[1], I[2], I[3], 0, SHADOW.alpha)
            QuadOr(soft, ix1, iy1, ix2, iy2, ox2, oy2, ox1, oy1,
                ox1, H - 1, (last and ox2 or ix2) - ox1, math.max(r1, r2) + 1)
            local a1, a2 = Touch(xs[k], H), Touch(xs[k + 1], H)
            local jx1, jy1, px1, py1 = BottomCore(xs[k], first, false)
            local jx2, jy2, px2, py2 = BottomCore(xs[k + 1], false, last)
            local core = corePool:Next()
            Style.Shade(core, "HORIZONTAL", I[1], I[2], I[3], a1, a2)
            QuadOr(core, jx1, jy1, jx2, jy2, px2, py2, px1, py1, px1, H - 1, px2 - px1, c + 1)
            if Height(xs[k], H) > 0 or Height(xs[k + 1], H) > 0 then lifted = lifted + 2 end
        end

        -- Down the right side.
        local ys = Stations(H, lift == "br" and "end" or nil)
        for k = 1, #ys - 1 do
            local first, last = k == 1, k == #ys - 1
            local ix1, iy1, ox1, oy1, r1 = RightSoft(ys[k], first, false)
            local ix2, iy2, ox2, oy2, r2 = RightSoft(ys[k + 1], false, last)
            local soft = shadowPool:Next()
            Style.Shade(soft, "HORIZONTAL", I[1], I[2], I[3], SHADOW.alpha, 0)
            QuadOr(soft, ix1, iy1, ox1, oy1, ox2, oy2, ix2, iy2,
                W - 1, oy1, math.max(r1, r2) + 1, (last and H - 1 or oy2) - oy1)
            local a1, a2 = Touch(W, ys[k]), Touch(W, ys[k + 1])
            local jx1, jy1, px1, py1 = RightCore(ys[k], first, false)
            local jx2, jy2, px2, py2 = RightCore(ys[k + 1], false, last)
            local core = corePool:Next()
            -- From the bottom (the later station) up.
            Style.Shade(core, "VERTICAL", I[1], I[2], I[3], a2, a1)
            QuadOr(core, jx1, jy1, px1, py1, px2, py2, jx2, jy2, W - 1, py1, c + 1, (last and H - 1 or jy2) - py1)
            if Height(W, ys[k]) > 0 or Height(W, ys[k + 1]) > 0 then lifted = lifted + 2 end
        end
        -- For the tests: how far past the card it reaches, glued and at a
        -- lifted corner.
        local d0, b0 = Fall(0)
        local d1, b1 = Fall(lift and LIFT.height or 0)
        plate.reach = { glued = d0 + b0, lifted = d1 + b1 }
        return lifted
    end

    -- The card's thickness (THICKNESS): its top and left cut edges catching
    -- the light, on the cut (`at`), its bottom and right edges in shade, a
    -- line inside each.
    local function Edges(W, H)
        local E = THICKNESS
        local w, L, a = E.width, E.light, E.at or 0
        for _, e in ipairs({ { a, a, W - a - w, w, true }, { a, a + w, w, H - 2 * w - a, true }, { 0, H - w, W, w },
            { W - w, w, w, H - 2 * w } }) do
            local texture = edgePool:Next()
            if e[5] then
                Fill(texture, L[1], L[2], L[3], E.lightAlpha)
            else
                Fill(texture, INK[1], INK[2], INK[3], E.darkAlpha)
            end
            Place(texture, e[1], e[2], e[3], e[4])
        end
    end

    -- A photo corner's triangle on the card, in K.Quad's order: two of its
    -- corners on one point.
    local function CornerAt(which, W, H, size)
        local o = MOUNT.out
        if which == "tl" then return -o, -o, size - o, -o, -o, size - o, -o, size - o end
        if which == "tr" then return W - size + o, -o, W + o, -o, W + o, size - o, W + o, size - o end
        if which == "bl" then return -o, H - size + o, -o, H - size + o, size - o, H + o, -o, H + o end
        return W + o, H - size + o, W + o, H - size + o, W + o, H + o, W - size + o, H + o
    end

    -- A corner's fold, its diagonal: the two ends, and which way it faces
    -- (toward the print's middle), as a unit vector, y down.
    local R2 = math.sqrt(0.5)
    local function FoldAt(which, W, H, size)
        local x1, y1, x2, y2, x3, y3, x4, y4 = CornerAt(which, W, H, size)
        if which == "tl" then return x2, y2, x3, y3, R2, R2 end
        if which == "tr" then return x1, y1, x3, y3, -R2, R2 end
        if which == "bl" then return x1, y1, x3, y3, R2, -R2 end
        return x1, y1, x4, y4, -R2, -R2
    end

    -- Where corners cannot move: an L of two strips along its outer edges.
    local function CornerStrips(which, W, H, size, dx, dy, colour, alpha, pool)
        local o, t = MOUNT.out, MOUNT.strip
        local left = (which == "tl" or which == "bl") and -o or W + o - size
        local top = (which == "tl" or which == "tr") and -o or H + o - size
        local hy = (which == "tl" or which == "tr") and -o or H + o - t
        local vx = (which == "tl" or which == "bl") and -o or W + o - t
        for _, strip in ipairs({ { left, hy, size, t }, { vx, top, t, size } }) do
            local texture = pool:Next()
            Fill(texture, colour[1], colour[2], colour[3], alpha)
            Place(texture, strip[1] + dx, strip[2] + dy, strip[3], strip[4])
        end
    end

    -- A photo corner (MOUNT): its shadow, the kraft pocket a shade of its
    -- own, and the light on its fold, by how the fold faces the top-left
    -- light. Laid flat, the pocket alone.
    local function Corner(which, W, H, pc, flat, seed)
        local size = pc * MOUNT.scale
        local x1, y1, x2, y2, x3, y3, x4, y4 = CornerAt(which, W, H, size)
        local sh, M = MOUNT.shadow, MOUNT.ink
        local tone = 1 + (Noise(seed) - 0.5) * 2 * MOUNT.uneven
        local layers = { { cornerPool, 0, 0, { M[1] * tone, M[2] * tone, M[3] * tone }, MOUNT.alpha } }
        if not flat then table.insert(layers, 1, { cornerShadowPool, sh[1], sh[2], MOUNT.shade, sh[3] }) end
        for _, l in ipairs(layers) do
            local pool, dx, dy, colour, alpha = l[1], l[2], l[3], l[4], l[5]
            if view.canBend then
                local texture = pool:Next()
                Fill(texture, colour[1], colour[2], colour[3], alpha)
                Quad(texture, x1 + dx, y1 + dy, x2 + dx, y2 + dy, x3 + dx, y3 + dy, x4 + dx, y4 + dy)
            else
                CornerStrips(which, W, H, size, dx, dy, colour, alpha, pool)
            end
        end
        if flat or not view.canBend then return end
        -- The fold: a line just inside the diagonal, its ends drawn in so
        -- it stays on the pocket as it narrows to its tips.
        local ax, ay, bx, by, nx, ny = FoldAt(which, W, H, size)
        local f = MOUNT.fold
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local ux, uy = (bx - ax) / len, (by - ay) / len
        ax, ay, bx, by = ax + ux * f * 1.5, ay + uy * f * 1.5, bx - ux * f * 1.5, by - uy * f * 1.5
        -- Facing the light at the top left (-1, -1): 1; away: -1.
        local facing = (-nx - ny) * R2
        local L = MOUNT.light
        local fold = foldPool:Next()
        Fill(fold, L[1], L[2], L[3], MOUNT.lo + (MOUNT.hi - MOUNT.lo) * (facing + 1) / 2)
        Quad(fold, ax - nx * f, ay - ny * f, bx - nx * f, by - ny * f, bx, by, ax, ay)
    end

    -- A lifted corner's shade on the card: two soft edges crossing at the
    -- corner, darkest where they meet.
    local function LiftShade(which, W, H)
        local bw, bh = LIFT.box[1], LIFT.box[2]
        local a = LIFT.shade[which] / 2
        local x = which == "br" and W - bw or 0
        local across = liftShadePool:Next()
        Style.Shade(across, "HORIZONTAL", INK[1], INK[2], INK[3], which == "br" and 0 or a, which == "br" and a or 0)
        Place(across, x, H - bh, bw, bh)
        local down = liftShadePool:Next()
        Style.Shade(down, "VERTICAL", INK[1], INK[2], INK[3], a, 0)
        Place(down, x, H - bh, bw, bh)
    end

    -- A point `u` along a side and `v` out from it (GLUE): the card's
    -- edge at v = 0, the page beyond.
    local function Out(side, u, v, W, H)
        if side == "top" then return u, -v end
        if side == "bottom" then return u, H + v end
        if side == "left" then return -v, u end
        return W + v, u
    end

    -- One bead of glue: two halves, each a taper from a hair at its end to
    -- `fat` px at its middle, fading in toward the middle; and a gloss
    -- down its middle, brightest toward the light (the left, or the top).
    -- Where corners cannot move, each half is a box half as fat.
    local function Bead(side, mid, length, fat, alpha, W, H)
        local T, across = GLUE.tint, side == "top" or side == "bottom"
        local half = length / 2
        for k = 0, 1 do
            local u0, u1 = mid - half + k * half, mid + k * half
            local t0, t1 = k == 0 and 0.3 or fat, k == 0 and fat or 0.3
            local bead = gluePool:Next()
            local from, to = k == 0 and 0 or alpha, k == 0 and alpha or 0
            local x1, y1 = Out(side, u0, -0.5, W, H)
            local x2, y2 = Out(side, u1, -0.5, W, H)
            local x3, y3 = Out(side, u1, t1, W, H)
            local x4, y4 = Out(side, u0, t0, W, H)
            if view.canBend then
                Style.Shade(bead, "HORIZONTAL", T[1], T[2], T[3], from, to)
                Quad(bead, x1, y1, x2, y2, x3, y3, x4, y4)
            elseif across then
                Style.Shade(bead, "HORIZONTAL", T[1], T[2], T[3], from, to)
                Place(bead, u0, side == "top" and -fat / 2 or H, half, fat / 2)
            else
                -- VERTICAL runs from the bottom up.
                Style.Shade(bead, "VERTICAL", T[1], T[2], T[3], to, from)
                Place(bead, side == "left" and -fat / 2 or W, u0, fat / 2, half)
            end
        end
        local G = GLUE.gloss
        local g = length * G.length
        local gloss = glossPool:Next()
        local gx, gy = Out(side, mid - g / 2, fat * 0.4 + G.width / 2, W, H)
        if across then
            Style.Shade(gloss, "HORIZONTAL", G.tint[1], G.tint[2], G.tint[3], G.alpha, 0)
            Place(gloss, gx, gy - G.width, g, G.width)
        else
            Style.Shade(gloss, "VERTICAL", G.tint[1], G.tint[2], G.tint[3], 0, G.alpha)
            Place(gloss, side == "left" and gx or gx - G.width, gy, G.width, g)
        end
    end

    -- Glue squeezed out from under the card (GLUE): a few beads, where and
    -- how long, fat and dark each by the plate's seed.
    local function Glue(W, H, seed)
        local G = GLUE
        local count = G.count[1] + math.floor(Noise(seed) * (G.count[2] - G.count[1] + 1))
        for k = 1, count do
            local r = seed + k * 7.31
            local side = G.sides[1 + math.floor(Noise(r) * #G.sides)]
            local L = (side == "top" or side == "bottom") and W or H
            local length = L * (G.length[1] + Noise(r + 1) * (G.length[2] - G.length[1]))
            local mid = length / 2 + Noise(r + 2) * (L - length)
            local fat = G.bead[1] + Noise(r + 3) * (G.bead[2] - G.bead[1])
            local alpha = G.alpha[1] + Noise(r + 4) * (G.alpha[2] - G.alpha[1])
            -- None where a corner came unstuck: it pulled its glue away.
            local x0, y0 = Out(side, mid - length / 2, 0, W, H)
            local x1, y1 = Out(side, mid + length / 2, 0, W, H)
            if Height(x0, y0) == 0 and Height(x1, y1) == 0 then Bead(side, mid, length, fat, alpha, W, H) end
        end
    end

    -- How it is held and how it stands: its shadow, its edges, glue, a
    -- corner come unstuck, photo corners. Laid flat, only the corners,
    -- lying flat on it.
    local function DrawMount()
        local s, flat = plate.slot, view.flat
        local W, H, seed = s.w, s.h, Seed()
        local counts = plate.counts
        local glue, corners, lifted = gluePool.used + glossPool.used, cornerPool.used, 0
        plate.reach = nil
        if not flat then
            lifted = CastShadow(W, H)
            Edges(W, H)
            Glue(W, H, seed)
            if s.lift then LiftShade(s.lift, W, H) end
        end
        for i, which in ipairs(s.corners or {}) do Corner(which, W, H, s.pc or 24, flat, seed + i * 3.7) end
        -- For the tests: what holds it and how it stands.
        counts.glue, counts.gloss = gluePool.used + glossPool.used - glue, glossPool.used
        counts.lift = lifted + liftShadePool.used
        counts.corners, counts.folds = cornerPool.used - corners, foldPool.used
        counts.shadow, counts.core, counts.edges = shadowPool.used, corePool.used, edgePool.used
    end

    ----------------------------------------------------------------------
    -- The map

    local function Ink(x0, y0, x1, y1)
        Split(x0, y0, x1, y1, function(a, b, c, d, light)
            local texture = framePool:Next()
            Fill(texture, INK_STRONG[1] * light, INK_STRONG[2] * light, INK_STRONG[3] * light, FRAME.alpha)
            Bend(texture, a, b, c, d)
        end)
    end

    -- The neat line: a rule hugging the art, a gap, a hairline.
    local function PrintFrame(x0, y0, x1, y1)
        for _, ring in ipairs({ { 0, FRAME.inner }, { FRAME.inner + FRAME.gap, FRAME.outer } }) do
            local d, w = ring[1], ring[2]
            Ink(x0 - d - w, y0 - d - w, x1 + d + w, y0 - d)
            Ink(x0 - d - w, y1 + d, x1 + d + w, y1 + d + w)
            Ink(x0 - d - w, y0 - d, x0 - d, y1 + d)
            Ink(x1 + d, y0 - d, x1 + d + w, y1 + d)
        end
    end

    -- The mat: the card's stock over its margin, round the art box, so the
    -- picture leaning in never shows past the neat line. And the clip
    -- round the box the turned art covers.
    local grainPath = Style.Art("grain")
    local function Mat(ax, ay, aw, ah)
        local s = plate.slot
        local W, H = s.w, s.h
        local C = view.paper or P
        for _, r in ipairs({ { 0, 0, W, ay }, { 0, ay + ah, W, H }, { 0, ay, ax, ay + ah }, { ax + aw, ay, W, ay + ah } }) do
            local mat = matPool:Next()
            Fill(mat, C[1], C[2], C[3], 1)
            Place(mat, r[1], r[2], r[3] - r[1], r[4] - r[2])
            if grainPath then
                local grain = matGrainPool:Next()
                grain:SetTexture(grainPath)
                grain:SetVertexColor(1, 1, 1, 1)
                grain:SetAlpha(MAT.grain)
                grain:SetTexCoord(r[1] / W, r[3] / W, r[2] / H, r[4] / H)
                Place(grain, r[1], r[2], r[3] - r[1], r[4] - r[2])
            end
        end
        local a = math.abs(view.turn or 0)
        local c, sn = math.cos(a), math.sin(a)
        clip:SetSize(aw * c + ah * sn, aw * sn + ah * c)
    end

    -- The window of art into the art box (plain paper where there is none),
    -- and how a point of the map lands on the card: At(x, y) is nil off the
    -- window, or `clamped` to its edge.
    -- The print's darkened edges (VIGNETTE): a band inside each side of
    -- the art box, each side's darkness a little its own (seeded).
    local function Vignette(ax, ay, aw, ah)
        local V, T = VIGNETTE, VIGNETTE.tint
        local d, seed = V.depth * math.min(aw, ah), Seed()
        local function A(side, n)
            return V.alpha[side] * (1 + (Style.Noise(seed * 0.71 + n) - 0.5) * 2 * V.uneven)
        end
        -- Where each band went, for Unscale to keep it there.
        local Place = function(t, x, y, w, h)
            Place(t, x, y, w, h)
            local sx, sy = K.Screen(x + w / 2, y + h / 2)
            t.home = { sx, sy, w, h }
        end
        -- VERTICAL runs from the bottom up.
        local top = vignettePool:Next()
        Style.Shade(top, "VERTICAL", T[1], T[2], T[3], 0, A("top", 1))
        Place(top, ax, ay, aw, d)
        local bottom = vignettePool:Next()
        Style.Shade(bottom, "VERTICAL", T[1], T[2], T[3], A("bottom", 2), 0)
        Place(bottom, ax, ay + ah - d, aw, d)
        local left = vignettePool:Next()
        Style.Shade(left, "HORIZONTAL", T[1], T[2], T[3], A("left", 3), 0)
        Place(left, ax, ay, d, ah)
        local right = vignettePool:Next()
        Style.Shade(right, "HORIZONTAL", T[1], T[2], T[3], 0, A("right", 4))
        Place(right, ax + aw - d, ay, d, ah)
    end

    -- Whether the client can draw a texture part way to grey (PLATE):
    -- asked under pcall, as a build without the method may raise on it.
    local probe = K.Texture("BORDER", 0)
    local asked, desaturate = pcall(function() return probe.SetDesaturation end)
    plate.canDesaturate = asked and type(desaturate) == "function"
    probe:Hide()

    local function DrawArt(mapID, window, box)
        local s = plate.slot
        local ax, ay, aw, ah = s.pad, s.pad, s.w - 2 * s.pad, s.h - 2 * s.pad
        PrintFrame(ax, ay, ax + aw, ay + ah)
        Mat(ax, ay, aw, ah)
        if not view.flat then Vignette(ax, ay, aw, ah) end
        -- The window's art may reach past the art box (`box`, a full page
        -- drawn with room to pan): under the card's margin, clipped.
        if box then ax, ay, aw, ah = box[1], box[2], box[3], box[4] end
        local layer, pieces = ns.UI.MapArt.For(mapID)
        local LW, LH = LayerSize(mapID)
        if layer then LW, LH = layer.layerWidth, layer.layerHeight end

        local B = Style.MAP_BACKGROUND
        Split(ax, ay, ax + aw, ay + ah, function(x0, y0, x1, y1, light)
            local texture = backgroundPool:Next()
            Fill(texture, B[1] * light, B[2] * light, B[3] * light, 1)
            Bend(texture, x0, y0, x1, y1, true)
        end, box ~= nil)

        local wx0, wy0, wx1, wy1 = window[1], window[2], window[3], window[4]
        local tiles, explored = 0, 0
        -- Printed, not shown: drawn part way to grey and toned, or toned
        -- harder where the client cannot desaturate (PLATE).
        local grey = plate.canDesaturate
        if layer then
            tiles, explored = ns.UI.MapArt.Print(layer, pieces, { wx0 * LW, wy0 * LH, wx1 * LW, wy1 * LH }, ax, ay, aw,
                grey and PLATE.tint or PLATE.plain, K, tilePool, exploredPool, box ~= nil)
            for _, pool in ipairs({ tilePool, exploredPool }) do
                for i = 1, pool.used do
                    local piece = pool[i]
                    if grey then piece:SetDesaturation(PLATE.desaturate) end
                end
            end
        end
        plate.toned = grey and "desaturated" or "tinted"
        plate.tileCount, plate.exploredCount = tiles, explored
        plate.hasArt = layer ~= nil

        local sx, sy = aw / (wx1 - wx0), ah / (wy1 - wy0)
        local function At(x, y, clamped)
            if not x or not y then return nil end
            local u, v = (x - wx0) * sx, (y - wy0) * sy
            if u < -EDGE or u > aw + EDGE or v < -EDGE or v > ah + EDGE then
                if not clamped then return nil end
                u, v = Clamp(u, 0, aw), Clamp(v, 0, ah)
            end
            return ax + u, ay + v
        end
        plate.At, plate.fullW, plate.fullH = At, sx, sy
        plate.box = { ax, ay, ax + aw, ay + ah }
        return At, sx, sy
    end

    ----------------------------------------------------------------------
    -- The road

    -- Marks never touch (MARK): each claims a disc, its radius `r` and
    -- MARK.clear round it. One landing on another steps out: along `ax`,
    -- `ay` (a unit vector) when given, so a mark beside a pool only ever
    -- moves further out from it; else to the first free place on rings
    -- round where it belongs, up and to the right first. Moved past its
    -- size, it is tethered back by a graphite hairline.
    local spots = {}
    local function Clear(x, y, r)
        for _, s in ipairs(spots) do
            local dx, dy = s[1] - x, s[2] - y
            local d = r + s[3] + MARK.clear
            if dx * dx + dy * dy < d * d then return false end
        end
        return true
    end

    local function Tether(x0, y0, x, y, r)
        local dx, dy = x - x0, y - y0
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= r + 1 then return end
        local G = Style.GRAPHITE
        Stroke(leaderPool, x0, y0, x - dx / d * r, y - dy / d * r, MARK.tether[1], G, MARK.tether[2])
    end

    local function Apart(x, y, r, ax, ay)
        r = r or MARK.together / 2
        local x0, y0 = x, y
        if not Clear(x, y, r) then
            local found
            for ring = 1, MARK.tries do
                if ax then
                    local tx, ty = x0 + ax * MARK.step * ring, y0 + ay * MARK.step * ring
                    if Clear(tx, ty, r) then found = { tx, ty } end
                else
                    for k = 0, 7 do
                        local a = -math.pi / 4 + k * math.pi / 4
                        local tx, ty = x0 + math.cos(a) * MARK.step * ring, y0 + math.sin(a) * MARK.step * ring
                        if Clear(tx, ty, r) then
                            found = { tx, ty }
                            break
                        end
                    end
                end
                if found then break end
            end
            if found then
                x, y = found[1], found[2]
                Tether(x0, y0, x, y, r)
            end
        end
        spots[#spots + 1] = { x, y, r }
        return x, y
    end
    -- For the tests: where the marks went, and how much room each took.
    plate.spots = spots
    -- The death crosses drawn: { x, y (on the card), segs (the stops or
    -- the road it marks), count }, read by the passes after the marks
    -- (Plate.RegisterPass), which may put the deaths kept with their
    -- killers on each (cross.deaths).
    local crosses = {}
    plate.crosses = crosses

    -- A stop's kind, for the trail.
    local function KindOf(seg)
        return Text.StopKind(seg) or "stayed"
    end

    -- The open entry's trail (UI/Ink/Trail.lua) from the stops in the window
    -- and the pieces of its roads, each primitive from its layer's pool;
    -- then a death's cross beside a pool, at its upper left, outside its
    -- footprint. Returns the pools, longest first.
    local function DrawTrail(sheet, entry, At, fullW, fullH, pxPerYard, opts)
        local window = plate.window
        local stops, roads = {}, {}
        for _, seg in ipairs(sheet.stops) do
            if During(seg.from, seg.to, entry) and At(seg.x, seg.y) then stops[#stops + 1] = seg end
        end
        for _, road in ipairs(sheet.roads) do
            if During(road.from, road.to, entry) then Pieces(road, window, roads) end
        end

        local box = { at = function(x, y) return At(x, y) end, fullW = fullW, fullH = fullH, pxPerYard = pxPerYard }
        local prims, built, pools = Trail.Build({ stops = stops, roads = roads }, box,
            { points = ns.Journey.Points, kind = KindOf, cap = opts.cap })
        -- Ink the window's edge would cut is left off (SPILL).
        local b = plate.box
        local function Inside(prim)
            local x0, y0, x1, y1
            if prim.k == "q" then
                x0, x1 = math.min(prim.x1, prim.x2, prim.x3, prim.x4), math.max(prim.x1, prim.x2, prim.x3, prim.x4)
                y0, y1 = math.min(prim.y1, prim.y2, prim.y3, prim.y4), math.max(prim.y1, prim.y2, prim.y3, prim.y4)
            else
                local r = math.max(prim.rx, prim.ry)
                x0, y0, x1, y1 = prim.x - r, prim.y - r, prim.x + r, prim.y + r
            end
            return x0 >= b[1] - SPILL and y0 >= b[2] - SPILL and x1 <= b[3] + SPILL and y1 <= b[4] + SPILL
        end
        local fallback, cut = 0, 0
        for _, prim in ipairs(prims) do
            if Inside(prim) then
                local pool = (prim.k == "q" and trailQuads or trailDiscs)[prim.layer]
                if not DrawPrim(prim, pool:Next()) then fallback = fallback + 1 end
            else
                cut = cut + 1
            end
        end

        local D = 0.7071
        for _, pool in ipairs(pools) do
            local e = pool.e
            if pool.drawn and pool.deaths > 0 then
                local d = Trail.Extent(e, -D, -D) + DEATH.gap
                pool.cx, pool.cy = Apart(e.x - d * D, e.y - d * D, DEATH.dot / 2, -D, -D)
                SHAPES.death(markInnerPool, nil, pool.cx, pool.cy, markHaloPool)
                crosses[#crosses + 1] = { x = pool.cx, y = pool.cy, segs = pool.segs or { pool.seg },
                    count = pool.deaths }
            end
        end

        local counts = plate.counts
        for _, key in ipairs({ "quads", "dots", "dabs", "pools", "droplets", "stops", "roads", "step" }) do
            counts[key] = built[key]
        end
        counts.areas, counts.fallback, counts.cut = #pools, fallback, cut
        -- For the tests: the pools and the primitives drawn.
        plate.pools, plate.areas, plate.prims = pools, pools, prims
        return pools
    end

    -- The flights: one small red-brown ring for each flight master in the
    -- window (a node: the ends on this map within FLIGHT.node yards of
    -- each other), placed through Apart once, its tooltip telling every
    -- flight that left or landed there; each flight's dashes from its
    -- ring toward its other end (a node's ring too when that end is on
    -- this map, else where the client can say: ns.ProjectMapPos), cut at
    -- the window's edge, in red-brown: the open entry's only. One route
    -- flown more than once is dashed once.
    -- (16 Oct, in the client: three flights out of one flight master drew
    -- three rings side by side, each pushed off the last by Apart, and
    -- three lines from where the rings should have been.)
    local function DrawFlights(flights, mapID, At, entry, now, fullW, fullH)
        local shown, dashes = 0, 0
        local step = FLIGHT.dash + FLIGHT.gap
        local w = plate.window
        -- Yards across and down the map, to measure a node in: the client's,
        -- else the trail's guess across and the art's shape down.
        local across, down = ns.Journey.MapYards(mapID)
        if type(across) ~= "number" or across <= 0 then across = Trail.FOOT.yards end
        if type(down) ~= "number" or down <= 0 then down = across * fullH / fullW end
        local near = FLIGHT.node * FLIGHT.node

        -- The node an end at x, y (this map's units) belongs to: the first
        -- whose first end lies within FLIGHT.node yards, else a new one.
        local nodes = {}
        local function Node(seg, x, y)
            local into
            for _, node in ipairs(nodes) do
                local dx, dy = (x - node.x0) * across, (y - node.y0) * down
                if dx * dx + dy * dy <= near then
                    into = node
                    break
                end
            end
            if not into then
                into = { x0 = x, y0 = y, sx = 0, sy = 0, n = 0, flights = {} }
                nodes[#nodes + 1] = into
            end
            into.sx, into.sy, into.n = into.sx + x, into.sy + y, into.n + 1
            if into.flights[#into.flights] ~= seg then into.flights[#into.flights + 1] = seg end
            return into
        end

        -- Each flight of the open entry with an end on this map: `a` the
        -- node of that end (the take-off's when both are here), `b` the
        -- other end's node when it is here too, else `other`, `ox`, `oy`.
        -- The sheet holds every flight ever on this map, oldest first, so
        -- only the entry's own count against the cap: taken before the
        -- check, a zone flown through forty times had none on its newer
        -- plates.
        local list, inEntry = {}, 0
        for _, seg in ipairs(flights) do
            if inEntry >= CAP.flights then break end
            if During(seg.from, seg.to, entry) then
                inEntry = inEntry + 1
                local here1 = seg.mapID1 == mapID and seg.x1 and seg.y1
                local here2 = seg.mapID2 == mapID and seg.x2 and seg.y2
                local f = { seg = seg }
                if here1 then
                    f.a = Node(seg, seg.x1, seg.y1)
                    if here2 then
                        f.b = Node(seg, seg.x2, seg.y2)
                    else
                        f.other, f.ox, f.oy = seg.mapID2, seg.x2, seg.y2
                    end
                elseif here2 then
                    f.a = Node(seg, seg.x2, seg.y2)
                    f.other, f.ox, f.oy = seg.mapID1, seg.x1, seg.y1
                end
                if f.a then list[#list + 1] = f end
            end
        end

        -- A ring per node in the window, at the middle of its ends, stepped
        -- aside once; one hover, telling each flight in time order.
        local rings = 0
        for _, node in ipairs(nodes) do
            node.mx, node.my = node.sx / node.n, node.sy / node.n
            local x, y = At(node.mx, node.my)
            if x then
                x, y = Apart(x, y, FLIGHT.ring / 2 + 1)
                node.x, node.y = x, y
                rings = rings + 1
                Halo(x, y, FLIGHT.ring + 4, true)
                Dot(markPool, x, y, FLIGHT.ring, Style.ACCENT, 0.95)
                Dot(markInnerPool, x, y, FLIGHT.ring - 4, P, 1)
                local segs = node.flights
                hoverPool:Next(x, y, function()
                    local tip = {}
                    for _, seg in ipairs(segs) do
                        local title, lines = Text.Flight(seg, mapID, now)
                        Style.TipList(title, lines, tip)
                    end
                    return tip
                end)
            end
        end

        -- The dashes: from the ring (the node's middle where it is out of
        -- the window) toward the other end, cut at the window's edge, and
        -- into the other ring where that end is a node here. A route
        -- already dashed (the same two nodes, or the same node toward the
        -- same far spot) is not dashed again.
        local lines, routes = {}, {}
        local function Dashed(f, tx, ty)
            for _, r in ipairs(routes) do
                if f.b then
                    if (r.a == f.a and r.b == f.b) or (r.a == f.b and r.b == f.a) then return true end
                elseif r.a == f.a and not r.b then
                    local dx, dy = (tx - r.tx) * across, (ty - r.ty) * down
                    if dx * dx + dy * dy <= near then return true end
                end
            end
            routes[#routes + 1] = { a = f.a, b = f.b, tx = tx, ty = ty }
            return false
        end
        for _, f in ipairs(list) do
            local a, b = f.a, f.b
            if a.x or (b and b.x) then shown = shown + 1 end
            local tx, ty
            if b then
                tx, ty = b.mx, b.my
            elseif f.ox and f.oy and f.other then
                tx, ty = ns.ProjectMapPos(f.other, mapID, f.ox, f.oy)
            end
            if tx and b ~= a then
                local cx1, cy1, cx2, cy2, t0, t1 = Clip(a.mx, a.my, tx, ty, w[1], w[2], w[3], w[4])
                if cx1 then
                    local ax, ay = At(cx1, cy1, true)
                    if t0 == 0 and a.x then ax, ay = a.x, a.y end
                    local bx, by = At(cx2, cy2, true)
                    if t1 == 1 and b and b.x then bx, by = b.x, b.y end
                    local line = { seg = f.seg, node = a, x1 = ax, y1 = ay, x2 = bx, y2 = by, dashes = 0 }
                    lines[#lines + 1] = line
                    if not Dashed(f, tx, ty) then
                        local dx, dy = bx - ax, by - ay
                        local length = math.sqrt(dx * dx + dy * dy)
                        local d = 0
                        while d < length and dashes < CAP.dashes do
                            local s1, s2 = d / length, math.min(d + FLIGHT.dash, length) / length
                            Stroke(dashPool, ax + dx * s1, ay + dy * s1, ax + dx * s2, ay + dy * s2,
                                FLIGHT.width, Style.ACCENT, FLIGHT.alpha)
                            dashes = dashes + 1
                            line.dashes = line.dashes + 1
                            d = d + step
                        end
                    end
                end
            end
        end
        -- For the tests: the nodes ({ x, y on the card (nil out of the
        -- window), mx, my in map units, flights }) and each flight's line ({ seg, node,
        -- x1, y1 (where its dashes start), x2, y2, dashes }).
        plate.flightNodes, plate.flightLines = nodes, lines
        -- `flights`: the flights with a ring on this plate; `flightNodes`:
        -- the rings.
        plate.counts.flights, plate.counts.flightNodes, plate.counts.dashes = shown, rings, dashes
    end

    -- A page point for a point of the card: through the card's turn, from
    -- its middle on the page.
    local function OnPage(x, y)
        local s = plate.slot
        local X, Y = K.Screen(x, y)
        return s.x + s.w / 2 + X, s.y + s.h / 2 - Y
    end
    plate.SheetToPage = function(_, x, y) return OnPage(x, y) end

    ----------------------------------------------------------------------
    -- Drawing

    -- How much room a mark of `kind` claims (Apart's radius): a registered
    -- mark's own `radius`, else the core marks' by their look.
    local function Radius(kind)
        local mark = MARKS[kind]
        if mark and mark.radius then return mark.radius end
        if kind == "fight" then return MARK.fight / 2 + 1 end
        if kind == "note" then return MARK.note[2] / 2 + 1 end
        if kind == "first" then return MARK.first[2] / 2 + 1 end
        if kind == "dungeon" then return MARK.door / 2 + 1 end
        if kind == "dot" then return MARK.dot / 2 + 1 end
        if kind == "seen" then return MARK.seen / 2 + 1 end
        return MARK.together / 2 + 1
    end

    -- A level's pin at x, y: a disc as wide as its number, the number on
    -- it, stepped clear of the marks already down, on a wash of paper. The
    -- level reached in rubric, its number light; where the level began
    -- (`start`) ink round paper, its number in ink. Returns where it went.
    local function Pin(pin, x, y, now, start)
        local number = numberPool:Next()
        number:SetText(tostring(pin.level))
        local size = math.max(MARK.pin, Width(number) + MARK.pinPad)
        x, y = Apart(x, y, size / 2)
        Dot(washPool, x, y, size + 4, P, MARK.halo)
        local text = Style.TAG_TEXT
        if start then
            Dot(pinPool, x, y, size, INK_STRONG, 0.92)
            Dot(markHaloPool, x, y, size - 2 * PIN.ring, P, 1)
            text = INK_STRONG
        else
            SHAPES.pin(pinPool, nil, x, y, size)
        end
        number:SetTextColor(text[1], text[2], text[3])
        PlaceText(number, x, y, "CENTER")
        hoverPool:Next(x, y, function() return Tip(Text.Pin(pin, now)) end)
        return x, y
    end

    -- A meeting's or a first sighting's tooltip: a title and its lines; a
    -- moment that brings its own words (`tip(m, now)`: a person's page's,
    -- UI/Journal/PersonPlate.lua) says them instead.
    local function MomentTip(m, entry, now, fights)
        if m.tip then return m.tip(m, now) end
        if m.kind == "first" then return Text.FirstSeen(m.first or m, now) end
        return Text.Meeting({ kind = m.kind, t = m.t, session = m.session, mark = m.mark, note = m.note,
            level = entry and entry.level }, now, fights)
    end

    -- The marks of what happened in the open entry (Recap.Moments), in
    -- ink: dungeons, the levels reached, then the people's marks. People
    -- met on one spot share one mark (MARK.merge), the likeliest to matter
    -- on top (PRIORITY) and its tooltip telling the rest. Each person's
    -- moment's mark is kept on the page (plate.where) for the margin
    -- notes' leaders.
    local PEOPLE = { session = true, fight = true, note = true, first = true, dot = true, seen = true }

    local function DrawMoments(sheet, moments, mapID, At, pools, entry, now, fights)
        local counts = plate.counts
        local where, people = {}, {}
        plate.where, plate.people = where, people
        local here = {}
        for _, m in ipairs(moments or {}) do
            if m.mapID == mapID and During(m.t, m.t, entry) then
                local x, y = At(m.x, m.y)
                if x then here[#here + 1] = { m = m, x = x, y = y } end
            end
        end

        -- The core's marks, first of all (the registry's "core" entry,
        -- Plate.RegisterMark): what they count, and the deaths on the road
        -- they find, are kept for the counts and RoadDeaths below.
        local doors, pins, moved, meetings, firsts, marks
        local deaths = {}
        local function CoreMarks()
            -- Dungeons: the arch of their door; their name is in its tooltip.
            doors = 0
            for _, h in ipairs(here) do
                if h.m.kind == "dungeon" and doors < CAP.dungeons then
                    doors = doors + 1
                    local seg = h.m.seg
                    local x, y = Apart(h.x, h.y, Radius("dungeon"))
                    Halo(x, y, MARK.door + 5, true)
                    SHAPES.dungeon(markPool, markInnerPool, x, y)
                    hoverPool:Next(x, y, function() return Tip(Text.Dungeon(seg, now)) end)
                end
            end

            -- The levels reached in its time (the entry's own, and in a week
            -- past the cap any other), and the next level reached, where a
            -- level's entry ends: the level's road from pin to pin. A level's
            -- own pin is where it began; the rubric marks a level reached.
            -- A pin on a pool moves out past its
            -- footprint (away from its middle, up and right from a pin right
            -- on it), with a short leader back, so it never hides the pool.
            pins, moved = 0, 0
            plate.pinMarks = {}
            for i = 1, #sheet.pins do
                local pin = sheet.pins[i]
                local x, y = At(pin.x, pin.y)
                local inside = During(pin.at, pin.at, entry)
                local out = entry and entry.out and entry.out.level == pin.level
                local start = inside and entry and entry.kind == "level"
                if x and (inside or out) and pins < CAP.pins then
                    pins = pins + 1
                    local host
                    for _, pool in ipairs(pools) do
                        local e = pool.e
                        local dx, dy = x - e.x, y - e.y
                        local d = math.sqrt(dx * dx + dy * dy)
                        local edge = d < 0.5 and e.a1 or Trail.Extent(e, dx / d, dy / d)
                        if pool.drawn and d < edge + MARK.pin / 2 + 2
                            and (not host or e.a1 * e.a2 > host.e.a1 * host.e.a2) then
                            host = pool
                        end
                    end
                    if host then
                        local e = host.e
                        local dx, dy = x - e.x, y - e.y
                        local d = math.sqrt(dx * dx + dy * dy)
                        if d < 1 then dx, dy, d = 1, -1, math.sqrt(2) end
                        dx, dy = dx / d, dy / d
                        local edge = Trail.Extent(e, dx, dy)
                        local reach = edge + PIN.gap + MARK.pin / 2
                        x, y = e.x + dx * reach, e.y + dy * reach
                        Stroke(leaderPool, e.x + dx * edge, e.y + dy * edge, x - dx * MARK.pin / 2,
                            y - dy * MARK.pin / 2, PIN.leader, start and INK_STRONG or Style.RUBRIC, PIN.leaderAlpha)
                        moved = moved + 1
                    end
                    x, y = Pin(pin, x, y, now, start)
                    plate.pinMarks[#plate.pinMarks + 1] = { pin = pin, x = x, y = y, host = host, start = start }
                end
            end

            -- The people's spots: moments within MARK.merge of each other are
            -- one spot.
            local spotsOf = {}
            for _, h in ipairs(here) do
                local m = h.m
                if PEOPLE[m.kind] then
                    local into
                    for _, c in ipairs(spotsOf) do
                        if math.abs(c.x - h.x) <= MARK.merge and math.abs(c.y - h.y) <= MARK.merge then
                            into = c
                            break
                        end
                    end
                    if not into and #spotsOf < CAP.meetings then
                        into = { x = h.x, y = h.y, list = {} }
                        spotsOf[#spotsOf + 1] = into
                    end
                    if into then into.list[#into.list + 1] = m end
                elseif m.kind == "death" and m.seg and m.seg.kind ~= "stop" then
                    deaths[#deaths + 1] = h
                end
            end

            meetings, firsts, marks = 0, 0, 0
            for _, c in ipairs(spotsOf) do
                -- What is on it, each once (a session's people share it), the
                -- likeliest to matter first.
                local seen, what = {}, {}
                for _, m in ipairs(c.list) do
                    local key = m.session or m.mark or m.note or m.first or m
                    if not seen[key] then
                        seen[key] = true
                        what[#what + 1] = m
                        if m.kind == "first" then firsts = firsts + 1 else meetings = meetings + 1 end
                    end
                end
                table.sort(what, function(a, b)
                    local pa, pb = PRIORITY[a.kind] or 9, PRIORITY[b.kind] or 9
                    if pa ~= pb then return pa < pb end
                    return a.t < b.t
                end)
                local top = what[1]
                local x, y = Apart(c.x, c.y, Radius(top.kind))
                marks = marks + 1
                if top.kind == "first" then
                    Halo(x, y, MARK.first[2] + 5, true)
                else
                    local size = top.kind == "note" and 14 or top.kind == "dot" and MARK.dot + 1
                        or top.kind == "seen" and MARK.seen or MARK.together
                    Halo(x, y, size + 4, true)
                end
                SHAPES[top.kind](markPool, markInnerPool, x, y)
                hoverPool:Next(x, y, function()
                    local list = Tip(MomentTip(top, entry, now, fights)) or {}
                    for k = 2, #what do
                        local title, lines = MomentTip(what[k], entry, now, fights)
                        if title and title ~= "" then list[#list + 1] = { title } end
                        for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
                    end
                    return #list > 0 and list or nil
                end)
                local px, py = OnPage(x, y)
                for _, m in ipairs(c.list) do
                    where[m] = { px, py, x = x, y = y }
                    people[#people + 1] = m
                end
            end
        end

        -- The registered marks (Plate.RegisterMark), whatever a feature
        -- adds: a mark where each was, those on one spot (MARK.merge) one mark,
        -- its tooltip telling each.
        local function Spots(kind, cap)
            local list = {}
            for _, h in ipairs(here) do
                if h.m.kind == kind then
                    local into
                    for _, c in ipairs(list) do
                        if math.abs(c.x - h.x) <= MARK.merge and math.abs(c.y - h.y) <= MARK.merge then
                            into = c
                            break
                        end
                    end
                    if not into and #list < cap then
                        into = { x = h.x, y = h.y, list = {} }
                        list[#list + 1] = into
                    end
                    if into then into.list[#into.list + 1] = h.m end
                end
            end
            return list
        end
        local function Tell(list, words)
            return function()
                local tip = {}
                for _, m in ipairs(list) do
                    local title, lines = words(m, now)
                    tip[#tip + 1] = { title }
                    for _, line in ipairs(lines or {}) do tip[#tip + 1] = { line, 1, 1, 1, true } end
                end
                return tip
            end
        end
        -- One kind's marks, all of them, then its count, its kept marks
        -- and its card: in that order, so a kind's card is chosen before
        -- the next kind is drawn, as it always was.
        local function DrawKind(spec)
            local marks, hover = {}, spec.hover or MARK.hover
            if spec.keep then plate[spec.keep] = marks end
            for _, c in ipairs(Spots(spec.kind, spec.count and CAP[spec.count] or spec.cap or math.huge)) do
                local x, y = Apart(c.x, c.y, Radius(spec.kind))
                if spec.halo then Halo(x, y, spec.halo, true) end
                local arg = spec.arg and spec.arg(c.list) or nil
                spec.draw(kit, x, y, arg)
                hoverPool:Next(x, y, spec.tip and Tell(c.list, spec.tip) or nil, hover)
                local px, py = OnPage(x, y)
                marks[#marks + 1] = { x = x, y = y, list = c.list, at = { px, py }, arg = arg }
                if spec.join then
                    for _, m in ipairs(c.list) do
                        if spec.join(m) then
                            where[m] = { px, py, x = x, y = y }
                            people[#people + 1] = m
                        end
                    end
                end
            end
            if spec.count then counts[spec.count] = #marks end
            if spec.chosen and spec.choose then plate[spec.chosen] = spec.choose(marks, plate) end
        end
        -- A death on the road has no pool to sit beside: its cross, in its
        -- fixed place among the registered marks (ROAD_DEATHS), after the
        -- features' own below 60 and before the filler.
        local function RoadDeaths()
            for _, h in ipairs(deaths) do
                local x, y = Apart(h.x, h.y, DEATH.dot / 2)
                SHAPES.death(markInnerPool, nil, x, y, markHaloPool)
                local seg = h.m.seg
                crosses[#crosses + 1] = { x = x, y = y, segs = { seg }, count = seg.act and seg.act.deaths or 1 }
            end
        end
        -- Every kind in its order, the core's two turns among them.
        local core = { core = CoreMarks, roadDeaths = RoadDeaths }
        for _, spec in ipairs(MARK_ALL) do
            local own = core[spec.kind]
            if own then own() else DrawKind(spec) end
        end
        counts.dungeons, counts.pins, counts.pinsMoved = doors, pins, moved
        counts.meetings, counts.firsts, counts.marks = meetings, firsts, marks
    end

    -- The passes after the marks (Plate.RegisterPass), in their order:
    -- what features learn from the death crosses and the plate's cards
    -- they choose from that, and what they lay over the picture.
    local function Passes(mapID, At, entry, now, opts)
        local c = { crosses = crosses, mapID = mapID, entry = entry, now = now, opts = opts, At = At,
            OnPage = OnPage, Tip = Tip,
            HoverCross = function(cross, fn) hoverPool:Next(cross.x, cross.y, fn, DEATH.dot + 4) end }
        for _, spec in ipairs(PASS_ORDER) do spec.draw(plate, c) end
    end

    -- Where it is glued: one of the page's slots.
    function plate:SetSlot(s)
        self.slot = s
        K.Mount(s.x, s.y, s.w, s.h, -math.rad(s.t or 0))
    end

    -- Draws `window` ({ x0, y0, x1, y1 }, 0..1 of the map, Plate.Window) of
    -- `sheet` (Recap.Sheet: one zone's road and meetings), the open
    -- `entry` (a level or a week: only its from..to is drawn). `opts`:
    -- moments (Recap.Moments of the entry: its marks), cap (the plate's
    -- share of the caps, Plate.Share), fights (Journey.FightIndex, built
    -- once), witnesses (Journey.WitnessIndex, built once), box (the full
    -- page's art box).
    function plate:Draw(sheet, entry, window, opts)
        opts = opts or {}
        local started = debugprofilestop and debugprofilestop()
        local now = opts.now or ns.Now()
        local fights = opts.fights or ns.Journey.FightIndex()
        local mapID = sheet.mapID
        self.mapID, self.entry, self.window, self.data = mapID, entry, window, sheet
        wipe(spots)
        wipe(crosses)
        self.counts = {}

        -- Drawn lying back, never leaned in.
        self.Settle()
        K.Lay()
        for _, pool in ipairs(ALL) do pool:Begin() end

        DrawMount()
        local At, fullW, fullH = DrawArt(mapID, window, opts.box)

        -- Yards serve only stops saved before shapes were kept.
        local yards = ns.Journey.MapYards(mapID)
        if type(yards) ~= "number" or yards <= 0 then yards = Trail.FOOT.yards end
        local pools = DrawTrail(sheet, entry, At, fullW, fullH, fullW / yards, opts)
        DrawFlights(sheet.flights, mapID, At, entry, now, fullW, fullH)

        -- Hover squares over the pools, as wide as their footprints (within
        -- reason), droplets too; the marks over them are placed after, so
        -- theirs lie on top. The pool's ink in words (no key, Decision 7).
        local HS = HOVER.size
        local hovered = 0
        for _, pool in ipairs(pools) do
            if hovered >= HOVER.most then break end
            if pool.drawn then
                hovered = hovered + 1
                local size = pool.droplet and HS[1] or math.max(HS[1], math.min(HS[2], 2 * pool.e.a1))
                hoverPool:Next(pool.e.x, pool.e.y, function()
                    local title, lines = Text.Stop(pool.seg, now, pool.more)
                    lines[1] = Text.Pool(pool.seg)
                    return Tip(title, lines)
                end, size)
            end
        end

        DrawMoments(sheet, opts.moments, mapID, At, pools, entry, now, fights)
        Passes(mapID, At, entry, now, opts)
        self.counts.labels = 0

        for _, pool in ipairs(ALL) do pool:Finish() end
        local textures = 0
        for _, pool in ipairs(TEXTURES) do textures = textures + pool.used end
        self.counts.textures = textures
        -- How long it took to draw (/sd journey reports it).
        if started then self.buildMs = debugprofilestop() - started end
    end

    -- Where a point of the map (0..1) lies on the page, through the card's
    -- window and turn: for a leader to it.
    function plate:OnPage(x, y)
        local px, py = self.At(x, y, true)
        return OnPage(px, py)
    end

    -- What a click on the card does (the full page); nil for nothing.
    -- What a click on the card does: `fn(plate)`, nil for nothing. With
    -- `lean` (the close-ups), it leans in under the mouse (ZOOM).
    function plate:SetClick(fn, lean)
        self.onClick, self.leans = fn, fn ~= nil and lean ~= false
        S:SetScript("OnMouseUp", fn and function() fn(plate) end or nil)
        clip:EnableMouse(fn ~= nil)
        self:Lean()
    end

    -- Leaning in (ZOOM): `zoom` from 0 to 1, eased out, run by a short
    -- OnUpdate that stops itself once it gets there; it follows the mouse
    -- over the picture, its marks included, so moving onto a mark never
    -- lets it go. plate.onZoom(plate, scale) hears each step (the page's
    -- leaders follow their marks).
    plate.zoom, plate.scale = 0, 1
    local function Want()
        return (plate.leans and clip:IsMouseOver()) and 1 or 0
    end
    local function Apply()
        local t = 1 - (1 - plate.zoom) ^ 4
        plate.scale = 1 + (ZOOM.scale - 1) * t
        content:SetScale(plate.scale)
        if plate.onZoom then plate.onZoom(plate, plate.scale) end
    end
    local function Step(_, elapsed)
        local target, step = Want(), (elapsed or 0) / ZOOM.time
        if target > plate.zoom then
            plate.zoom = math.min(target, plate.zoom + step)
        else
            plate.zoom = math.max(target, plate.zoom - step)
        end
        Apply()
        if plate.zoom == target then clip:SetScript("OnUpdate", nil) end
    end
    function plate:Lean()
        if Want() ~= self.zoom then clip:SetScript("OnUpdate", Step) end
    end

    ----------------------------------------------------------------------
    -- Looking closer (FULLZOOM, DRAG): a full page under the wheel

    -- `look`: the view shown, `f` (screen px a px of art), `cx`, `cy` (the
    -- map point at the card's middle, 0..1); `drawn`, the view the picture
    -- was drawn at; `goal`, where the wheel is taking it; `fit`, `c0` the
    -- fitted view; LW, LH the art's size; onSettle(f, cx, cy) draws again.
    local look

    -- The print's darkened edges are in the picture (under its ink) but
    -- stay at the neat line: scaled with it by `scale`, each band is put
    -- back where it was drawn, so the wheel does not take them with it.
    local function Unscale(scale)
        for i = 1, vignettePool.used do
            local t = vignettePool[i]
            local h = t.home
            if h then
                t:ClearAllPoints()
                t:SetPoint("CENTER", S, "CENTER", h[1] / scale, h[2] / scale)
                t:SetSize(h[3] / scale, h[4] / scale)
            end
        end
    end

    -- The picture placed for the view shown against the view drawn: scaled
    -- by their ratio about the card's middle and shifted, in the card's own
    -- turn, so the map point at the middle is the one wanted.
    local function Show()
        local d, f = look.drawn, look.f
        local lx, ly = (d.cx - look.cx) * f * look.LW, (d.cy - look.cy) * f * look.LH
        local a = view.turn or 0
        local c, sn = math.cos(a), math.sin(a)
        pivot:ClearAllPoints()
        pivot:SetPoint("CENTER", S, "CENTER", lx * c + ly * sn, lx * sn - ly * c)
        plate.scale = f / d.f
        content:SetScale(plate.scale)
        Unscale(plate.scale)
    end

    -- A view kept on the map: no further than the fit, the middle no
    -- nearer an edge than half the window.
    local function Hold(f, cx, cy)
        f = Clamp(f, look.fit, FULLZOOM.native)
        local s = plate.slot
        local hw, hh = (s.w - 2 * s.pad) / 2 / (f * look.LW), (s.h - 2 * s.pad) / 2 / (f * look.LH)
        cx = hw >= 0.5 and 0.5 or Clamp(cx, hw, 1 - hw)
        cy = hh >= 0.5 and 0.5 or Clamp(cy, hh, 1 - hh)
        return f, cx, cy
    end

    -- The wheel's easing, then the wait to draw sharp again: one short
    -- OnUpdate on the pivot, stopping itself once it has drawn. Held, only
    -- a new zoom is drawn (a drag draws again once let go); the press is
    -- carried on over the drawing.
    local Drag
    local function Redraw()
        local pressed = look.pressed
        look.redraws = (look.redraws or 0) + 1
        local g = look.goal
        look.onSettle(g.f, g.cx, g.cy)
        if pressed and look then
            look.pressed = pressed
            clip:SetScript("OnUpdate", Drag)
        end
    end
    local function Tick(_, elapsed)
        local m = look.move
        if m then
            m.t = m.t + (elapsed or 0)
            local p = math.min(1, m.t / FULLZOOM.time)
            local e = 1 - (1 - p) ^ 4
            look.f = m.f + (look.goal.f - m.f) * e
            look.cx = m.cx + (look.goal.cx - m.cx) * e
            look.cy = m.cy + (look.goal.cy - m.cy) * e
            if p >= 1 then
                look.f, look.cx, look.cy, look.move = look.goal.f, look.goal.cx, look.goal.cy, nil
            end
            Show()
            return
        end
        look.still = look.still + (elapsed or 0)
        if look.still >= FULLZOOM.settle then
            pivot:SetScript("OnUpdate", nil)
            local d, pressed = look.drawn, look.pressed
            look.goal = { f = look.f, cx = look.cx, cy = look.cy }
            if d.f ~= look.f or (not pressed and (d.cx ~= look.cx or d.cy ~= look.cy)) then
                Redraw()
            end
        end
    end
    local function Wait()
        look.still = 0
        pivot:SetScript("OnUpdate", Tick)
    end

    -- The point under the cursor: on the screen (UI units), and on the card
    -- from its middle, unturned, y down. Fields, so the tests can say.
    function plate.CursorScreen()
        local x, y = GetCursorPosition()
        local scale = clip:GetEffectiveScale() or 1
        return x / scale, y / scale
    end
    function plate.CursorLocal()
        local x, y = plate.CursorScreen()
        local mx, my = S:GetCenter()
        local X, Y = x - (mx or 0), y - (my or 0)
        local a = view.turn or 0
        local c, sn = math.cos(a), math.sin(a)
        return X * c + Y * sn, X * sn - Y * c
    end

    -- A notch of the wheel at qx, qy on the card: closer (up) or further,
    -- the map point there staying under it.
    function plate:Wheel(delta, qx, qy)
        if not look then return end
        if not qx then qx, qy = plate.CursorLocal() end
        local g = look.goal
        local mx, my = g.cx + qx / (g.f * look.LW), g.cy + qy / (g.f * look.LH)
        local f = Clamp(g.f * FULLZOOM.step ^ (delta or 0), look.fit, FULLZOOM.native)
        local cx, cy = mx - qx / (f * look.LW), my - qy / (f * look.LH)
        f, cx, cy = Hold(f, cx, cy)
        local shown = { f = look.f, cx = look.cx, cy = look.cy }
        look.goal = { f = f, cx = cx, cy = cy }
        -- Drawn now for where it is going, the whole zone round it, and
        -- eased in from where it was.
        local d = look.drawn
        if d.f ~= f or d.cx ~= cx or d.cy ~= cy then Redraw() end
        look.f, look.cx, look.cy = shown.f, shown.cx, shown.cy
        look.move = { t = 0, f = shown.f, cx = shown.cx, cy = shown.cy }
        Show()
        Wait()
    end
    clip:SetScript("OnMouseWheel", function(_, delta) plate:Wheel(delta) end)

    -- A press on the picture: a click, or a drag that pans.
    function Drag()
        local p = look and look.pressed
        if not p then
            clip:SetScript("OnUpdate", nil)
            return
        end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            plate:Release("LeftButton")
            return
        end
        local x, y = plate.CursorScreen()
        local X, Y = x - p.x, y - p.y
        if X * X + Y * Y > DRAG.threshold * DRAG.threshold then p.moved = true end
        if not p.moved then return end
        local a = view.turn or 0
        local c, sn = math.cos(a), math.sin(a)
        local lx, ly = X * c + Y * sn, X * sn - Y * c
        local f, cx, cy = Hold(look.f, p.cx - lx / (look.f * look.LW), p.cy - ly / (look.f * look.LH))
        look.f, look.cx, look.cy, look.move = f, cx, cy, nil
        look.goal = { f = f, cx = cx, cy = cy }
        Show()
    end
    plate.Drag = Drag

    function plate:Press(which)
        if which and which ~= "LeftButton" then return end
        if not look then return end
        local x, y = plate.CursorScreen()
        look.pressed = { x = x, y = y, cx = look.cx, cy = look.cy }
        clip:SetScript("OnUpdate", Drag)
    end

    function plate:Release(which)
        if which and which ~= "LeftButton" then return end
        if not look then
            if self.onClick then self.onClick(self) end
            return
        end
        local p = look.pressed
        look.pressed = nil
        clip:SetScript("OnUpdate", nil)
        if p and p.moved then
            Wait()
        elseif self.onClick then
            self.onClick(self)
        end
    end
    clip:SetScript("OnMouseDown", function(_, which) plate:Press(which) end)
    clip:SetScript("OnMouseUp", function(_, which) plate:Release(which) end)

    -- Looking closer at a full page drawn at `o` = { f, cx, cy, fit, c0 =
    -- { cx, cy }, LW, LH, onSettle }; nil for none (a close-up).
    function plate:Look(o)
        pivot:SetScript("OnUpdate", nil)
        look = o and { f = o.f, cx = o.cx, cy = o.cy, fit = o.fit, c0 = o.c0, LW = o.LW, LH = o.LH,
            onSettle = o.onSettle, drawn = { f = o.f, cx = o.cx, cy = o.cy },
            goal = { f = o.f, cx = o.cx, cy = o.cy }, still = 0, redraws = o.redraws } or nil
        self.look = look
        clip:EnableMouseWheel(look ~= nil)
        pivot:ClearAllPoints()
        pivot:SetPoint("CENTER", S, "CENTER")
    end

    -- As it was, at once: drawn again, or put away mid-lean, mid-wheel or
    -- mid-drag: nothing left running or held, the picture at its place.
    local function Settle()
        plate.zoom = 0
        clip:SetScript("OnUpdate", nil)
        pivot:SetScript("OnUpdate", nil)
        if look then look.pressed, look.move = nil, nil end
        pivot:ClearAllPoints()
        pivot:SetPoint("CENTER", S, "CENTER")
        Apply()
        if look then Unscale(plate.scale) end
    end
    plate.Settle = Settle
    clip:SetScript("OnEnter", function() plate:Lean() end)
    clip:SetScript("OnLeave", function() plate:Lean() end)
    view:HookScript("OnHide", function()
        Settle()
        plate:Look(nil)
    end)

    plate:SetSlot(slot)
    plate:Hide()
    return plate
end

-- A plate's share of the trail's caps, by its area (SHARE).
function Plate.Share(slot)
    return math.min(1, math.max(SHARE.least, slot.w * slot.h / SHARE.area))
end

Plate.MOUNT, Plate.GLUE, Plate.LIFT, Plate.SHARE, Plate.MARK = MOUNT, GLUE, LIFT, SHARE, MARK
Plate.PRIORITY, Plate.DOOR, Plate.FLIGHT = PRIORITY, DOOR, FLIGHT
Plate.CAP = CAP
Plate.ZOOM, Plate.FULLZOOM, Plate.DRAG = ZOOM, FULLZOOM, DRAG
Plate.PLATE, Plate.SHADOW, Plate.THICKNESS, Plate.VIGNETTE = PLATE, SHADOW, THICKNESS, VIGNETTE

-- The window a full page shows at `f` (screen px a px of art) round cx, cy
-- in an art box aw by ah, and, with `over`, the window drawn round it and
-- its box on the card (x, y, w, h, the card's margin `pad` in): the
-- window plus `over` of itself each side, within the map.
function Plate.Frame(mapID, f, cx, cy, aw, ah, pad, over)
    local LW, LH = LayerSize(mapID)
    local w, h = aw / (f * LW), ah / (f * LH)
    local x0, y0 = cx - w / 2, cy - h / 2
    local window = { x0, y0, x0 + w, y0 + h }
    if not over or over <= 0 then return window, nil end
    local d = { math.max(0, x0 - w * over), math.max(0, y0 - h * over), math.min(1, x0 + w + w * over),
        math.min(1, y0 + h + h * over) }
    local box = { pad + (d[1] - x0) * f * LW, pad + (d[2] - y0) * f * LH, (d[3] - d[1]) * f * LW, (d[4] - d[2]) * f * LH }
    return d, box
end

ns.UI.JourneyPlate = setmetatable(Plate, { __call = function(_, parent, slot) return New(parent, slot) end })
