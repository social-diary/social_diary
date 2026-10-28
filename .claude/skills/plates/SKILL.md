---
name: plates
description: Work on Your Diary's map plates and everything written round them — slot layouts (LAYOUT, light/full weights, F+L), captions, margin notes and cards (paper strips, killer, close call, hunt, find, ...), leaders, marks, the full zone page. Load in a subagent (together with frontend-design) before changing or proposing anything on the right page of Your Diary; it maps the code, the rules the user has already decided, and the render/test tooling.
argument-hint: "[what to change on the plates]"
---

# Your Diary's plates

The right page of *Your Diary* (`/sd` → the green ribbon) shows the open
level's places as **plates**: windows of the zone map printed on photo
stock and glued in, each with a hand-written **caption** and **margin
notes** (taped paper strips and cards) with pencil **leaders** to marks on
the map. This skill is everything a fresh agent needs to work there
without rediscovering it.

**Plates are drawn per piece** (28 Oct, `.claude/sittings-plan.md`): a
level (a week past the cap) played over several sittings, or with a run
page, is read by sitting. `Recap.Pieces(j, e, ctx)` cuts it into
`e.pieces` (a piece is a full `Gather` entry over one sitting's part of
the level, so everything below draws it unchanged) and sets `e.spliced`
when there is one piece and no run. The right page shows the open piece
(`page.piece`, an index into `e.pieces`, kept with `page.pieceOf`;
`YourDiary.OpenPieceOf(e)`), or the entry whole where spliced. So
wherever this skill says "the open level" for the plates, read "the open
piece": `DrawPlates(piece)`, `PlatesOf(piece)` caches on the piece. The
full zone page stays level-wide (`DrawFull(e)`), and its way back returns
to the piece. The left page lists the open entry's sittings (and each
one's runs) under its rubric (`UI/Journey/Left.lua`, `SITTINGS` in
`Look.lua`); `OpenLevel(i)` opens the newest piece, `OpenPiece(i, k)` one,
`OpenRun(id, i)` the piece holding that run.

Also load `frontend-design` (UI work in this project always goes through
it). If you add or change words a player reads, hand the copy to the
`copywriter` skill (`.claude/skills/copywriter/`) and don't write it yourself.

## 0. Before touching anything

1. Read `AGENTS.md` and `.impeccable.md` (design context, brand voice).
2. **Other sessions may edit these files between your steps.** Re-read a
   file right before editing it, use Edit (never whole-file rewrites), and
   don't revert changes you didn't make. Never commit; don't touch
   `CHANGELOG.md` (releases own it).
3. Run the baseline: `luajit tests/run.lua` from the addon folder (all
   green is normal; note anything already failing so you don't chase it).
4. Run the render baseline: `.claude/skills/plates/tools/plates.sh` (see §6).
   It prints what every testdata page lays out today.
5. Comments in this codebase are long prose explaining *why*, with dated
   in-client notes ("(11 Oct, in the client: …)"). Match that. A constant
   table gets a comment saying what each field means and why its value.
   When you change a value because of a screenshot, add the dated note.

## 1. The pipeline (data → page)

```
Core/JourneyRecap.lua                       UI/Journey/*.lua (page)                   UI/Journey/Plate.lua
Recap.Build(j) → entries (levels, weeks)
Recap.Moments(j, e, ctx) → moments ───────► PlatesOf(e)
Recap.Plates(j, e, ctx, cover) → plates ◄──   groups at SMALLEST[1..3] windows,
  (≤3, each {mapID,x0..y1,cx,cy,t,rank,        accepts the first grouping LayoutFor
   moments, light})                            gives a page for → e.plates/e.layout/e.pattern
Recap.Holds(plate, w, h)  ◄────────────────  LayoutFor(plates) → layout, key ("FL", …)
                                             DrawPlates(e): per plate a slot
                                               Plated(ctx, slot, over) ───────────────► plate:SetSlot / plate:Draw
                                                 Heading / Text.PlateCaption              (art, trail, marks, crosses,
                                                 WriteMargin → MarginOrder → LayNotes      killer/foe/hunt/find picks:
                                                 leaders (Aim/Pencil/Follow)               plate.killer/.foe/.hunt,
                                             DrawFull(e): FULL page, zoom/pan             plate.where[m] = page xy)
```

The page is one module, `ns.UI.YourDiary`, a file per question (the
header of `UI/Journey/Look.lua` lists them and the state they share):
`Look.lua` the look tables (`LAYOUT`, `CAPTION`, `LEADER`, ...),
`Layouts.lua` `PlatesOf`/`LayoutFor`/`SMALLEST`, `Leaders.lua` the plates
and pools handed out and the leaders, `People.lua` `Tier`, `Margin.lua`
the margin registry and `WriteMargin`/`LayNotes`, `Caption.lua` `Heading`,
`Plated`, `DrawPlates` (F+L), `Full.lua` the full page, `Left.lua` the
left page, `Empty.lua` the empty page, `Page.lua` build and refresh. The
page singleton is `YourDiary.page` (`ns.UI.JourneyPage()` in tests).

- **Moment kinds** (all of them): `session fight note first find death
  close luck fortune finale skill arrive dungeon campfire stay road level`.
  `Recap.RANK` orders which open plates; a pin (`level`) never opens a
  plate alone unless nothing else exists. A campfire (`RANK.campfire =
  5.5`, 14 Oct, registered in `Features/Campfire/Kind.lua`) opens a plate,
  but last of all that do: after a dungeon's door, before a stay. Ranks are
  only compared, so fractions are fine.
- **Grouping**: a moment joins the first plate whose window it fits
  (`Fits`: the box spans ≤ `PLATES.inset` = 0.8 of the window). Windows are
  the slot's art box at **1 screen px per px of map art** (Decision 3;
  `Plate.Cover`), so a smaller slot = a smaller window = more plates.
- **Weight**: `plate.light` when every moment is in `Recap.LIGHT`
  (`arrive dungeon stay road level finale skill fortune campfire`). It's a whitelist,
  so a new kind counts as full until someone weighs it.

## 2. Layouts (`UI/Journey/Look.lua`, `LAYOUT` and the comment above it)

Right page: 466 × 534 px (`RIGHT_H`), coordinates from its top left, y down.
A slot is `{ x, y, w, h, t (turn °, clockwise), pad (card margin round the
art), pc (photo-corner size), corners, lift ("br"/"bl": the corner come
unstuck), cap = { x, y, w, limit, align }, notes = { x, y, w } }`. Variants:
`top` (caption over the plate, notes in a `row` of boxes), `tucked`.

| Key | When | Shape |
|---|---|---|
| `LAYOUT[1]` | one plate | 444×364 plate, caption under-left, notes column right |
| `LAYOUT[1][1].top` | one plate, caption short | caption across the top, plate 444×343 at y37, notes in a row of 3 (x 10/160/310, w142, y400) |
| `LAYOUT[2]` | 2 plates: FF, LL | 260×236 top-left + 300×236 bottom-right |
| `LAYOUT[3]` | 3 plates: FFF, FLL, LLF, LLL | 242×176 TL, tall 192×234 right, 228×126 BL |
| `FL`, `LF` | full + light | full 260 wide and tall with a 176 px caption column the page's height; light = snapshot |
| `F+L` (`LAYOUT.FL.tucked`) | FL, tried first | full plate under a top caption, a 2-box row, a 140×100 print tucked bottom right |
| `FLF`, `FFL`, `LFF`, `LFL` | 3 plates | full slots 260 wide with 176 px captions, snapshots for L |
| `FULL` | a plate clicked | 446×484, fitted to the zone's height, scroll zoom / drag pan (`Plate.FULLZOOM`), click = back |

- **Snapshot** = `SNAPSHOT` / `Snap(x, y, t, corners, lift, cap)`: 176×124,
  pad 7 (art 162×110), pc 18. `LayoutFor` calls a plate `L` only if it is
  light **and** a snapshot holds it (`Holds`); otherwise it's `F`.
- **Picking** (`LayoutFor`): key from the weights in time order →
  `LAYOUT[key] or LAYOUT[#plates]`; returns nil if any plate doesn't hold in
  its own slot, so `PlatesOf` regroups at the next smaller window.
- **F+L rule** (`DrawPlates`): only for an FL pattern. Both plates must hold
  in the tucked slots; then `Plated(ctx, tucked[1], true)` keeps it only if
  the caption is short (heading 1 line, words ≤ 1 line, the `top` test)
  **and** the margin is whole (`tucked[1].whole`: nothing left off the
  2-box row). Otherwise FL, decided once per draw and never flipped back.
- `page.layout` = plate count, `page.pattern` = key or `"F+L"`.
- `SMALLEST[n]` is the smallest art box of `LAYOUT[n]` and drives grouping.
  **Changing a numeric layout's sizes changes how moments group.** Check
  testdata summaries before and after.

**Geometry rules (each one came from a screenshot):**
- Nothing touches the page edge. A lifted corner's shadow reaches
  `out + blur + (gain + spread) × LIFT.height` ≈ 9.9 px, so keep lifted
  corners ≥ 10 px inside the page. Known exceptions, left as is: the `top`
  variant (~1.6 px past the right edge), `LAYOUT[3]`'s bl lift (~4 px past
  the foot).
- One lifted corner per page; turns between about ±1° and ±2.2°,
  alternating; photo corners `FOUR` or `LOST` (one missing at the lift).
- Keep the lowest plate and its caption clear of the **not-kept line**
  (`OFF`: x 246, y 512, shown when "Keep my own route" is off). Notes stop
  at `CAPTION.offLimit` (506) then, else `CAPTION.limit` (528).
- A full plate's caption column is **≥ 176 px**: a close-call card names a
  long creature ("Razormane Battleguard") on one line with its level tag.
  At 136 px it was dropped (11 Oct). The 3-plate left column was widened for
  a strip plus a close-call card for the same reason.
- A caption left of its plate is `align = "RIGHT"` (it leans on its plate).
- The top plate may sit at y −2 (the paper runs 20 px above the page top).

## 3. Captions and the margin

- **Heading** (`Heading`): "The Barrens, yesterday" by hand
  (`FONT.noteWritten`, sizes `CAPTION.hand` 16 then 14, Neuton Italic). If
  it doesn't fit one line, the zone alone, and the day moves into the words.
  A plate on the same day as the one before counts on ("Twenty minutes
  later").
- **Words** (`Text.PlateCaption(p, began, said)`): `FONT.body`. They name
  what the margin had no room for, so `Plated` writes the words, lays the
  margin, rewrites the words and lays again until they agree (`Mark`/`Undo`
  roll the pools back). Anyone a strip names is not named again in the
  words. `said` is what the margin shows: `said.named` (who the strips
  name, `someone` = strangers' strips) and one key per caption kind
  (`find` the firsts on cards, `death` the killer's name when its card is
  left off, `close` true with a close call's card, `luck` the hunt on its
  card, `fortune` `{ hunt, print }`, `witness` a witness left off,
  `campfire` true when the slip is left off).
- **Caption registry** (`Text.RegisterCaption(key, spec)`, spec comment above
  `PlateCaption` in `UI/Journey/Text/Caption.lua`; every kind registered from its feature's folder:
  find's in `Features/Firsts/Text.lua`, campfire's in `Features/Campfire/Text.lua`,
  skill's in `Features/ProfessionCaps/Text.lua`, finale's in
  `Features/QuestFinales/Text.lua`, death's in `Features/Deaths/Text.lua`,
  close's in `Features/CloseCalls/Text.lua`,
  witness's in `Features/Witnesses/Text.lua`, luck's and fortune's in
  `Features/Hunts/Text.lua`): the words are a **lead** (first in `at`
  order with something to say), a **tail** (", a, b, and c": every kind's
  words in tail `at` order, less the lead's own kind) and **codas**
  (sentences after the full stop). `spec`: `moment` (the plate.moments kind
  it gathers), `take(m, said)` (what it keeps, nil drops), `lead = { at,
  say(list, c) → text, rest }`, `tail = { at, say(list, c) → words }`,
  `coda = { at, say(c) → sentence }`; `c` = plate, began, said, named, of,
  lists, lead (the key that led). Core leads (hand-written `LEADS`): people
  10, fights (strangers) 45, arrive 100, dungeon 110, stay 120, company 130,
  level 150, then "On the road". Kinds today: lead find 20, finale 30,
  skill 40, death 50, close 60, luck 70, fortune 80, campfire 140; tail find
  10, finale 20, skill 30, death 40 (silent after the "fights" lead), close
  50, luck 60, fortune 70 (a fortune lead puts its `rest` here), campfire
  90; coda witness 10 (Witnesses'). Shared helpers are exported on `Text` (`When`,
  `Capital`, `MapName`, `Who`, `Day`, `Times`, `NUMBER`, `WORDS`, `Count`,
  `ItemWord`, `Items`, `Health`,
  `List`, `Glue`, plus the older `Short`, `Plural`, ...; each file of
  `UI/Journey/Text/` exports its own at its foot), the timeline's row helpers on `ns.UI.TimelineText`
  (`Items`, `Quote`, `Place`, `Foe`).
- **Entry prose registry** (`Text.RegisterLines(key, { at, run, lines =
  function(e, now, index) → paragraph or nil })`, spec comment above
  `Text.Lines` in `UI/Journey/Text/Prose.lua`; `Text.Paragraphs()` / `Text.RemoveLines(key)`): the left
  page's paragraphs for a level. Core (hand-written `PARAGRAPHS`): opening
  10, time (stops + flights) 20, people (+ fights) 30; kinds: find 40 in
  `Features/Firsts/Text.lua`, finale 50 in `Features/QuestFinales/Text.lua`,
  skill 60 in `Features/ProfessionCaps/Text.lua`, close 70 in
  `Features/CloseCalls/Text.lua`, hunts (bad and good luck,
  `ns.Hunts.Lines`) 75 in `Features/Hunts/Text.lua`; the
  quiet line after all, where there is only the opening. Kinds sharing a
  `run` write one paragraph: close 70 and hunts 75 are the run "combat",
  the second running on after the first (after a space), or starting it.
- **Margin registry** (`ns.UI.JourneyMargin.Register(kind, spec)`, spec
  comment above `MarginOrder` in UI/Journey/Margin.lua; every kind from its
  feature's folder: find's in `Features/Firsts/Card.lua`, campfire's in
  `Features/Campfire/Slip.lua`, killer's in `Features/Deaths/Card.lua`,
  foe's in `Features/CloseCalls/Card.lua`, witness's in
  `Features/Witnesses/Card.lua`): `order`, `item(plate)` or
  `items(plate)` (→ `{ top, x, <own fields> }`; `kind`/`rank` set by core),
  `pool` (page key; killer and foe share `killerPool`), `new(parent)`,
  `write(note, it, c)` (`c.Seed(...)`, `c.now`, `c.named`, `c.ToPerson`),
  `mark(it, note)`, optional `wants(it)` (row width, `Shared`), `assume(said,
  plate, slot, plan)` (words before laying: as if all shown), `say(said,
  shown, plate)` (words after: asked in `order`, so a witness's creature is
  overruled by a killer card left off), `count` + `counted(shown, plate)`
  (page.*Written, reset in `DrawPlates`), `filler` + `flag` (campfire:
  plate.camped), `fits(plan, slot)` (F+L veto: S on the tucked print),
  `after(plate, c)` (`c.Leader`: S's leader). People stay core at
  `JourneyMargin.PEOPLE` close 10 / seen 80 (people first at equal order).
  `JourneyMargin.Remove(kind)` / `Text.RemoveCaption(key)` take a kind out
  (tests/margin_caption.lua registers and removes a throwaway one).
- **Margin order** (`MarginOrder`): tier-1 people (session, fight, note,
  added; a feature's moment joined to theirs by its `person.tier`: a first
  someone gave, `ns.Firsts.PERSON`) → firsts found (`Features/Firsts/Card.lua`,
  `ns.Firsts.Card`, `Card.Items`) → witness (`Features/Witnesses/Card.lua`, `ns.Witnesses.Card`:
  someone who watched you die, tried to save you or saved you; it replaces the
  killer card, or a rescue the close call's) → killer → close call
  (`foe`) → lucky (good luck, `Features/Hunts/LuckyCard.lua`,
  `ns.Hunts.LuckyCard`; on a light plate's print it is the print's S
  instead, never in the margin) → hunt (bad luck, the mildest card,
  `Features/Hunts/HuntCard.lua`, `ns.Hunts.HuntCard`) → tier-2/3 people (first
  sightings, crossed) → campfire (`Features/Campfire/Slip.lua`: one slip a plate,
  exactly "sat by a campfire", no count however many fires; filler, last
  of all, so the first left off; it goes in a light plate's margin under
  its caption too, never on the print). `WriteMargin` tries quoted notes at 3/2/1 lines
  (`QUOTES`) before dropping items; in a row, notes are re-sorted by their
  mark's x.
- **Notes** are laid by `LayNotes` into `boxes` (column under the caption,
  or `row` boxes, shared by `Shared`/`ROW.most`). Pools: `notePool`
  (`UI/Paper/Strip.lua`), `findPool` (`Features/Firsts/Card.lua`), `killerPool`
  (`Features/Deaths/Card.lua`, `ns.Deaths.Card`, also the close-call card:
  the card wears a face of the close calls' (`Card.RegisterFace`,
  `Features/CloseCalls/Card.lua`: `card:SetFoe`, `card:Deed`, the chart
  `ns.CloseCalls.Card.VITALS`; the creature chosen by
  `ns.CloseCalls.Card.Choose`)),
  `huntPool` (`Features/Hunts/HuntCard.lua`), `witnessPool` (`Features/Witnesses/Card.lua`), `luckyPool` (`Features/Hunts/LuckyCard.lua`: a card
  and its tag, a second slip, `card.tag`), `campfirePool` (`Features/Campfire/Slip.lua`),
  `leaderPool`, `dotPool`. Every registered kind's pool is made by
  `EnsurePools` (`page.marginPools` for `Mark`/`Undo`, `page.rightPools`).
  Each is a `YourDiary.Handout`, which is `ns.UI.Pool.New(make)`
  (`UI/Kit/Pool.lua`, a loose sheet's `K.Pool` too): `Begin`/`Next`/`Finish`,
  `pool.used`, the same one handed out again for the same place.
- **Campfire slip left off** (Rule B, the user's choice 14 Oct): where it
  has no room (always under FL's print, whose caption starts at y 474; often
  under F+L's tucked print; first to go in a full margin), the caption's
  words say it (`said.campfire`: ", and a campfire", or "By
  a campfire in Lushwater Oasis." as the lead). FL is never turned FF for
  it. Filler never runs the words past their foot: where saying it would,
  `Plated` leaves it out of the words too and the mark alone tells it
  (`plate.camped` false then).
- **S, good luck on a light print** (`LuckyCard.Print`, drawn by the
  `print` pass, 90, at the foot of `Features/Hunts/LuckyCard.lua`, through
  its own toolkit: `PRINT_LAYERS`/`PRINT_TEXTS` pools made by the pass's
  `new` on the plate's `over` frame, under the lift's shade; buttons
  `plate.printHit`/`plate.printItem`): `plate.print` (form, polys, leader).
  F+L is not kept where S will not go on the tucked print
  (`LuckyCard.PrintFits`, the lucky kind's `fits`).
- **Leaders** (`LEADER`, `Aim`, `Pencil`, `Follow`): one per strip, graphite
  pen (not ink), leave the strip's nearest edge, enter over the plate edge
  nearest the strip, bow down slightly, end `stop` px short in a dot.
  `plate.where[m]` gives a mark's page position (through `plate:OnPage`).
- Copy lives in `UI/Journey/Text/` (`Caption.lua`: `PlateHeading`,
  `PlateCaption`; `Margin.lua`: `MarginWhat`; `Notes.lua`: `MarginQuote`;
  `Grammar.lua`: `KillerName`; `Zones.lua`: `ZoneFoot`; `Tips.lua`:
  tooltips), and a moved feature's in its own
  `Features/<Name>/Text.lua` (firsts found: `ns.Firsts.Words`, `ItemName`,
  `Heading`, `GiftLine`, `Giver`, `Sentence`, `Lines`, `Tip`, `PERSON`;
  campfire: `ns.Campfire.WORDS`, `At`, `Tip`;
  profession caps: `ns.ProfessionCaps.Words`, `Sentence`, `Lines`, `Tip`;
  quest chain finales: `ns.QuestFinales.Words`, `Sentence`, `Lines`, `Tip`;
  deaths: `ns.Deaths.Killed`, `KillerTip`, `DeathCross`; close calls:
  `ns.CloseCalls.Sentence`, `Tag`, `Heading`, `Deed`, `Tip`,
  `FoeTip`, `Lines`; hunts: `ns.Hunts.Words`, `Line`, `ExpectedWords`,
  `Tip`, `Item`, `KillLines`, `CardTip`, `ExpectedLabel`, `KILLED`, `EACH`,
  `USUALLY`, `Fortune`, `LuckyTag`, `LuckyKind`, `LuckyCaption`, `Lines`,
  `Kinds`; witnesses:
  `ns.Witnesses.Name`, `Others`, `Look`, `Deed`, `Foe`, `Caption`, `Tip`).
  Changes there go through the copywriter skill.

## 4. The plate itself (`UI/Journey/Plate.lua`, header comment = spec)

The card is `ns.UI.LooseSheet(..., glued)`: everything is placed through its
toolkit (`K.Place`, `K.Quad`, `K.PlaceText`, `K.Pool`) so it turns with the
card. Look tables: `PLATE` (stock, desaturate, tint), `FRAME`, `VIGNETTE`,
`THICKNESS`, `SHADOW`, `MOUNT` (kraft photo corners), `GLUE`, `LIFT`,
`SHARE` (a smaller plate gets a share of the trail caps by area). Core
marks: `MARK`, `PRIORITY`, `DOOR`, `DEATH`, `PIN`,
`FLIGHT`; `SHAPES[kind]` draws them, bespoke in `DrawMoments` (doors, pins,
people's shared marks, death crosses). `Radius`/`Apart` keep all
marks apart.

**Registered marks** (`Plate.RegisterMark(kind, spec)`, the comment above
it is the spec): one mark per merged spot of one moment kind. A feature
file loaded after `UI/` registers its own; `DrawMoments` draws every kind
in `order` through one loop (Spots → Apart(radius) → halo → `draw(kit, x,
y, arg)` → hover with `tip` → kept in `plate[keep]` → `plate.counts[count]`
→ `plate[chosen] = choose(marks)`; a kept mark keeps its `arg`; `join(m)`
puts a moment that is someone's too with their marks, `plate.where` and
`plate.people`, so it joins their margin note), with the deaths on the
road in a fixed slot (`ROAD_DEATHS` = 60). Today's, all from their
features' folders: `find` 5 (`Features/Firsts/Mark.lua`, `ns.Firsts.POUCH`
drawstring pouch in the best item's ink part way (`arg`), `plate.findMarks`
for the cards, a gift from someone in the diary `join`ed to their marks),
`luck` 40 and `fortune` 50 (`Features/Hunts/Mark.lua`: `ns.Hunts.TALLY`,
`plate.huntMarks` → `plate.hunt`; `FORTUNE` star,
`plate.fortuneMarks` → `plate.lucky`), `finale` 10
(`Features/QuestFinales/Mark.lua`, `ns.QuestFinales.MARK` tailpiece), `skill` 20
(`Features/ProfessionCaps/Mark.lua`, `ns.ProfessionCaps.MARK` stairs, `arg` =
best rank), `close` 30 (`Features/CloseCalls/Mark.lua`, `ns.CloseCalls.MARK`,
no halo: lays its own dot on `kit.halo`; `plate.closeMarks`, its card
chosen in the `foe` pass) and (`Features/Campfire/Mark.lua`) `campfire`
70 (`ns.Campfire.MARK`, ink only: a flame with a paper tongue on two
crossed logs, filler, last, so it steps aside with a tether;
`plate.campfireMarks` → `plate.campfire`). `cap` fills `Plate.CAP[count]`.
The kit: pools `ink`/`inner`/`halo`, `Dot`, `Box`, `Stroke`, `Quad`,
`Place`, `Fill`, `Light`, `Clamp`, `P`, `INK`, `INK_STRONG`. Order changes
which mark steps aside, so a new kind's `order` is a design decision.

**Passes after the marks** (`Plate.RegisterPass(key, { order, new(plate,
kit), draw(plate, c) })`, spec above it): run in `order` once every mark
is down. `new` (optional) is asked once as each plate is made, with the
over-kit (`over`, `Pool`, `TextPool`, `Button`, `Place`, `Quad`,
`PlaceButton`, `Tip`): what a pass lays over the picture, its pools begun,
finished and counted with the plate's. `c` = `crosses` (the death crosses, `plate.crosses`), `mapID`,
`entry`, `now`, `opts`, `At`, `OnPage`, `Tip`, `HoverCross(cross, fn)`.
The crosses stay core (shape, place, `count`); passes put their own
fields on them and on the plate. Today's: in `Features/Deaths/Card.lua`
`killer` 10 (Deaths: `cross.deaths` matched, the crosses' tooltips,
`plate.killer`); in `Features/CloseCalls/Card.lua` `foe` 20
(`plate.foe`); in
`Features/Witnesses/Card.lua` `witness` 30 (`plate.witness`, chosen by
`ns.Witnesses.Card.Choose` from `cross.deaths` and the close calls' marks,
clearing the killer or foe it replaces); in
`Features/Hunts/LuckyCard.lua` `print` 90 (S on a light plate's print,
`plate.print`, the only pass with a `new` today).
The ink trail is `UI/Ink/Trail.lua` (its pen, the stroke kit the leaders
share, is `UI/Ink/Pen.lua`); map art and explored overlays are
`UI/Map/Art.lua`. "Flat paper only" lays everything flat (no
turn, shadow, lift, glue, vignette). Drawing is pooled, deterministic
(seeded), once per open/turn, and nothing runs per frame.
The strip and the cards share the turned plane, `UI/Paper/Surface.lua`
(`ns.UI.Surface`): `New(owner)` (the strip's Out/Screen/In/Place/Quad),
`Corners`/`Unbend` (a loose sheet's too), `Turned` (a point turned about
another), `Width` (unbounded) and `Seed` (a string to a number: what a slip
turns, tears and is scribbled by). Use them, don't copy them; the plate's
own kit stays inside `Plate.lua`'s `New` for now. `Clamp` is the pen's
(`ns.UI.Pen.Clamp`); the leaders keep their own (it differs where
`lo` passes `hi`).

## 4b. A run's page (the keepsake page, 28 Oct)

A run that earned a page (`Recap.RunWorthy`: a boss killed, or a kill its
loot told of) is a page of the piece it began in (`piece.runs`;
`YourDiary.RunsOf(x)` is `x.runs` for a piece, the worthy visits of
`x.dungeons` for an entry drawn whole). Its line, indented under its
sitting's on the left page, or its ledger row opens it (`OpenRun`,
`page.mode = "run"`, `page.runVisit`); a level never opens on a run, but a
piece with no plates and a run opens on its first run (`ViewOf` in
`Page.lua`). The interim stepping through runs (`NextView`) is gone. The page
is `UI/Journey/Run.lua` (`DrawRun`, blank `PaperStrip`s written on through
`strip:Lay`); where everything goes is the pure plan `Core/RunPage.lua`
(`RUN`, `Plan`, `Most`, `TitleSize`), and `tests/run_page.lua` checks no two
pieces meet at 0–5+ keepsakes, with and without a map, one- and two-line
titles, many seeds (it found the boss strip meeting K2's slip once: keep
that test running after any change to `RUN`). Its words are
`UI/Journey/Text/Run.lua` (the user's own, no copywriter pass). A plate
that is only a recorded run's door is dropped in `Recap.Plates`
(`Recap.DOOR_ONLY`). The spec: `.claude/ui-proposal/super-plate.md`.

## 5. Decisions already made (don't reopen without asking the user)

- **Only the open level** is drawn on plates and the full page (on plates,
  only its open piece, 28 Oct). Other levels' roads and marks in pencil
  were removed as "graphic spam" (10 Oct).
- **No key/legend** on plates; tooltips explain ink and marks (Decision 7).
- **A first sighting shows only in hindsight**, and a person "matters" only
  through a diary add or an interaction row (group_join, trade, whisper,
  say), not by being seen again (11 Oct).
- **Killer card and close-call card both show** whenever possible, even for
  the same creature (12 Oct).
- **Light kinds** include finale, skill and fortune. A light plate a
  snapshot can't hold is drawn full. Plates are in strict time order, top
  to bottom (13 Oct).
- **Paper is the product**: depth, wear, shadows and material are wanted.
  When something reads badly, fix its shape, not its alpha. Never trade
  away text contrast.
- **Fixed scale** of 1 screen px per px of map art on close-ups. No
  stretching a window to fill a slot.
- A session gets one spot (`Recap.Settle`, the longest overlap). Per-stop
  session moments are an open proposal; don't build them unasked.
- No SavedVariables changes without asking. Plates are computed at view
  time.

## 6. Tooling

**Tests** (offline, against `tests/wowmock.lua`):
- `luajit tests/run.lua` (all) · `luajit tests/run.lua journey_ui` (one file)
  · `-v` (sections + addon output).
- Plate tests: `tests/journey_ui.lua` (sections "the open level's plates",
  "a zone's full page", "a page by its plates' weights …"),
  `tests/journey.lua` (Recap: grouping, weights, Holds),
  `tests/killer_card.lua`, `tests/combat_ui.lua` (close-call/foe cards on
  testdata pages), `tests/witness_card.lua` and `tests/witnesses.lua`
  (the witness card; capture, rows, the plate's choice), `tests/hunt_card.lua`, `tests/lucky_card.lua`,
  `tests/firsts.lua`, `tests/campfire_ui.lua` (the People row, the
  caption's campfire words, the slip and its testdata pages),
  `tests/margin_caption.lua` (the margin, caption and prose registries:
  today's orders, a throwaway kind registered, placed, counted, told,
  removed), `tests/skills.lua` / `tests/skills_ui.lua` (profession caps:
  capture, moments, words, stairs), `tests/questie.lua` (section "chain
  finales (JRN-28)": capture through the quest events, words, tooltip;
  then finales as moments).
- Useful handles: `ns.UI.JourneyPage()` (page: `.plates`, `.links`,
  `.recap.entries`, `.layout`, `.pattern`, pools), `ns.UI.RedrawJourneyPage()`,
  `ns.UI.JourneyLook` (LAYOUT, CAPTION, LEADER, ROW, FOOT, SNAPSHOT,
  LayoutFor…), `ns.UI.JourneyPlate` (Cover, Window, SHADOW, LIFT…). On a
  plate: `.slot`, `.window`, `.captionOver`, `.margin`, `.counts`,
  `.killer/.foe/.hunt`, `.where`.
- To open a page in a test: `T.OpenDiaryPage(page, i, k)` (`k` the piece,
  nil for an entry drawn whole); every page a reader can open:
  `T.DiaryPages(page)` (`tests/harness.lua`), which the testdata loops in
  the plate tests walk. Or click the level's rubric row (see `Open` in
  journey_ui), or `YourDiary.OpenPiece(i, k)`. Setting `page.open = i`
  alone draws a non-spliced entry's newest piece. The section "a level by
  sitting" in journey_ui checks the sittings' lines, the tick, OpenPiece,
  the full page's way back and runs only where worthy.
- **The mock measures every string at 14 px and ~6 px per character.** To
  test wrapping, patch `GetStringHeight` on the heading/caption pools'
  font strings (as the `top`/F+L tests and `plate_dump.lua` do).
- Use `luajit` only to run things. **Never `luajit -bl a b`**: the second
  argument is the output file and gets overwritten.
- Prove a new condition matters: break it in the source, watch its test
  fail, restore byte for byte.

**Geometry render** (no client needed): `.claude/skills/plates/tools/`
- `plates.sh [out-dir] [label-or-pattern …]` (default `/tmp/sd-plates`):
  - prints a `SUMMARY` per `/sd testdata` entry (pattern, each plate's
    weight and moment kinds, what made each margin);
  - forces every string key in `LAYOUT` (plus F+L) onto an entry with that
    many plates;
  - writes PNGs (plates, shadows, photo corners, caption and note boxes,
    leaders, the not-kept line in red, S on a print as `PRINTSLIP` slip/tag/
    icon) and prints checks (overlaps, shadows past the page, text past the
    foot or over the not-kept line, S's icon on its tag or off its print).
  - Look at the PNGs with Read. `SD_PLATES_FORCE=0` skips the forced pages.
- `plate_dump.lua` (runs in a symlink farm next to the real harness, so
  nothing is written in the addon), `plate_render.py` (pure Python +
  `pngio.py`; run with `python3 -I`).
- A clean render is not proof: text widths are estimates, there's no art,
  and real fonts differ. It catches overlaps and off-page geometry before
  you ask for screenshots.
- Testdata today (13 Oct): lv10 F+L, lv11 FL (lucky card L in the column),
  lv12 FF (light plate too wide → full; lucky card M2 in the 122 px column),
  lv13 FL (S on the print; F+L given up for it), lv14 one plate (lucky card
  XL in the row, L in the mock), lv15–16 one plate; the weeks are read by
  sitting (28 Oct, from the route's gaps): week 1's two sittings L
  (Orgrimmar's print alone, on the one-plate slot) and F (the oasis with
  Tester), week 2's three FF, F, F; its LF and FFF are only drawn whole
  now (`plates.sh` forces the 3-plate keys onto it, `_whole`; the LF test
  in campfire_ui empties `j.sittings` so the week is spliced)
  (the hunts written by `Features/Hunts/Dev.lua`, at "route"). Witness cards (14 Oct): lv10 tried
  (M, F+L row), lv11 saved (L), lv13 watched (L), lv14 saw + two others (M),
  the cap's oasis mercilessly watched (XL on lv16's page, smaller on a week's),
  the crag on the last week tried (XL); the weeks fall by the calendar
  (written by `Features/Witnesses/Dev.lua`, at "route"; forgotten at
  "remove"). Close calls (written by `Features/CloseCalls/Dev.lua`, at
  "route"): lv11 no creature (cross only), lv12 Razormane Battleguard
  (elite, three), lv14 Murloc Streamrunner (ink), lv15 Sunscale Scytheclaw
  (old record, no tag), the cap's oasis Humar (rare, 1%), the crag Lord
  Kazzak (skull boss).
  Campfires (14 Oct; written by `Features/Campfire/Dev.lua`): lv11's FL print (no room: "First Aid at 75, and a
  campfire."), lv12's 122 px column (slip after the lucky card), lv13's FL
  print (its words long already: left to the mark), lv15 two fires, one
  sat by twice (two marks; margin full, so the words say it), and on the
  mock's day the oasis week LF: Orgrimmar's print with its slip under the
  caption, and the oasis fire stepped aside from Tester's ring (slip after
  the person). The glyph's render: `.claude/ui-proposal/render_plate_marks.py`
  (local). None of FLF/FFL/LFF/LFL
  occur naturally; they're only seen forced. If a change needs them for
  real, add a testdata entry in `Dev/TestData.lua` (`TestData.WriteJourney`),
  or, for a moved feature, in its `Features/<Name>/Dev.lua`
  (`TestData.Register("route" | "tester", fn)`, spec above it in
  TestData.lua).

**Proposals** (margin notes and cards): two files, `.claude/skills/plates/tools/proposal-template.html`
(well under 100 lines) and `proposal-kit.js` (the library: the kit `K`, the board, the review; never edited for a proposal).
- `cp .claude/skills/plates/tools/proposal-template.html .claude/ui-proposal/<name>-mockup.html`, then write
  **exactly three variants (A, B, C)** in its DESIGN block (its comment is the API) in place of the example.
- Each variant's sizes are shown at one real width each: **XL 220 · L 176 · M 142 · S 122** (bands: XL ≥190,
  L 150–189, M 122–149, S one line in the hand at 14 px), plus its mark at 2×. Toggles: flat paper, zoom 1×/2×.
- **Handover**: the user picks variants and sizes and comments (saved in localStorage per proposal name);
  "Copy handover" gives short Markdown: title, `## Picks` (`- B · L`), `## Comments` (each with what it is on).
  Act on it; record each round in `<name>-proposal.md`.
- **Keep it lean**: no extra boards, no layout code, no render scripts in or beside the mockup. Reasoning goes
  in a short .md (decisions and open questions). Placement on real plates is checked with `plates.sh` and tests.
- Don't read the older, large mockups in `.claude/ui-proposal/` for a
  proposal: the kit already carries their look. Specs, only where a decision
  needs them: `.claude/journey-goal.md` (decisions D1–D11), `.claude/prd.md`
  (JRN-*), `.claude/journey-revamp-plan.md`.

## 7. In the client

The user tests in WoW and sends screenshots. You can't see the client.
- `/sd testdata` writes the made-up diary and route (the real route is
  parked). `/sd journey stats | segments [n] | raw` (dev) shows the route.
  `/sd pen` tweaks the ink live.
- Stray or oversized textures don't show in the mock (it doesn't compute
  layout). To find them, the user runs a region-width scan: see the memory
  note `in-client-layout-diagnosis`.
- For data rather than looks, log to SavedVariables and read the file after
  a `/reload`. Don't ask for screenshots of long text output.

## 8. Finish with

1. `luajit tests/run.lua`: every file green (state any failure and whether
   it was there before you started).
2. `plates.sh`: summaries as intended, no new `!!` lines, and the PNGs
   looked at.
3. A report: files changed; behaviour and geometry changes with their
   reasons; any test expectation you changed and why; and a **numbered
   in-client checklist** (which `/sd testdata` level or week shows each
   change, and what to look for).
