---
paths:
  - "Core/DungeonPace.lua"
  - "Core/Pace/**"
  - "Core/DungeonRun.lua"
  - "Core/Instances.lua"
  - "Capture/Instances.lua"
  - "UI/Dungeon/Print.lua"
  - "Dev/PaceDebug.lua"
  - "Dev/pace_build.py"
  - "Dev/pace/**"
  - "tests/pace*.lua"
---

# Placing moments on the way (the route model)

A death, a wipe, a roll or a level-up between bosses has a time and, for a
death, often a killer, but no position. The Dungeon View draws it on the
way through (the usual way, `Core/DungeonRoutes.lua` / Dungeon Crawler
Forever, or the player's own, `Core/DungeonWay.lua`). This is how it finds
the spot, strongest signal first. Built 3 Nov 2026 from a route-model
handover (`ref/route-model-handover/`, local) and four live test runs in
Ragefire Chasm on the dev machine.

## The chain, in the code

| Step | Where | What |
|---|---|---|
| Between which kills, how long into the leg | `Core/DungeonRun.lua` `Between` | `after`, `before`, `dt` (seconds getting on since the leg began), `known` (the leg's length when its boss fell), `open` (no kill after it) |
| The clock | `DungeonRun.Active` | time inside (`spans`) less, for each pause between fights (`visit.pauses`), what lies beyond `IDLE.most` (120 s) |
| The fights | `Core/Instances.lua` `Combat`, `Capture/Instances.lua` | `PLAYER_REGEN_*` inside a run; only pauses of `PAUSE.least` (30 s) or more are saved, `PAUSE.most` (200) a run |
| Wipes and near wipes | `DungeonRun.Notes` | half the group (near: half less one) dead to trash within `WIPE_WINDOW` (60 s) of the first death |
| The data on the map | `Core/DungeonPace.lua` `Fit` | each floor the bosses stand on by its **art bounds** (DCF `Art.lua`; for DCF's own art without them, the data's `bounds`, or its `pieces` for an overview, each piece a floor `uiMapID * 10 + n`; `{x1, y1, x2, y2}`: picture x from game y2→y1, picture y from game x2→x1), all in one frame of game yards (`fit.floors[uiMapID]`, `fit.order`, `fit.floor` the first); DCF's pins only compared (`worst`, `worstName`). Several floors with one lacking bounds: no fit. One floor without bounds: least squares through the pins and entrance, refused past `FIT.most` (12 yd) or under `FIT.least` (4) |
| The packs laid on the way | `DungeonPace.Course` | each pack a pull on the first stretch of its own floor (`pack.floor`, from the build; a stretch from one floor to the next takes either) passing within `PULL.radius` (15 yd); a boss's guard (`boss`) at that boss's stop |
| A leg as the model takes it | `DungeonPace.Leg` | from point i0 (or an anchor's yards) to the boss at i1; nil backwards, across a broken stretch, to a point that is no boss |
| Time → yards | `Core/Pace/Model.lua` (the handover's, unchanged) | effort profile (walk 5 yd/s, pull 20 s + 12 s an elite, boss 60 s), pace spread, deaths weighted to pulls; never past the boss |
| The killer | `DungeonPace.PlaceGroup` | candidates: the leg's pulls holding the killer's NPC (or its summoner, `summons`); the time weighs them exactly (`Weights`, spread `KILLER.spread` 0.35), summed over a wipe's deaths; along the way, the one where the weight passes half wins; none weighted: nearest the time's place |
| Sure places | `UI/Dungeon/Print.lua` `Anchors` | each moment placed by its killer is an anchor; later moments on that leg go from the last one before them, on the rest of the leg |
| After an anchor | `Print.lua` `PacePoint` | after a wipe the clock starts again where the pause after it ends (`AFTER_WIPE` 60 s); else, if the group went out between, the walk back (anchor yards ÷ 5 yd/s) comes off |
| On the sheet | `Print.lua` `LegPoint` | the spot kept `PACE_CLEAR` (12 yd) off both bosses; a wipe's crosses all at the wipe's spot (`Deaths`), its strip's target the same; a moment the model put on another floor is left off this floor's sheet (no Plan A for it), one on the stretch between floors goes with the nearer end |
| No pace data, or the model does not apply | `LegPoint` | Plan A: `frac` of the way between kills; on an open leg eased (`1 - 2^(-dt/240)`, `DungeonRun.OPEN`) toward the next boss still standing, at most `OPEN_MOST` (0.9) |

`LegPoint` returns x, y, how (`"killer"`, `"pace"`, `"eased"`, `"share"`,
`"past"`) and, for the model, `{ yd, key, anchor, shift }`.

## Decided, and why

- **The art bounds, not the pins** (4 Nov 2026). DCF draws boss pins where
  they read well: Zul'Farrak's 23–64 yd off their spawns, Roogug's 160,
  Glutton's 95. Fitted through them, maps came out stretched by up to a
  fifth (Stockade, though it "passed") and three dungeons were refused. The
  bounds are the map's own rectangle (Blizzard's, the one the client places
  the player with): exact, blind to the pins. Packs land nearer the drawn
  corridors with them in every dungeon checked (Ragefire median 10 → 5 yd,
  Razorfen Downs 11 → 3). Never drop or rename a boss to get a fit.
- **DCF's data can be wrong too**: bounds, pins and the usual way. The
  check that leans on none of the pins is how near the packs lie to the way
  drawn (`tests/pace_data.lua`, `ON_WAY`); a dungeon that fails it does not
  ship (Zul'Farrak, 4 Nov: 30 of 107 packs, its way through spread pins).
- **Laid on our way, not the data's.** The handover's legs were shortest
  paths on its own map; DCF's usual way clears the side rooms (Ragefire:
  520 yd to Oggleflint, not 265). A progress fraction would have put marks
  in the wrong corridor. The packs are laid on whatever way is drawn.
- **The killer beats the clock.** Two level 60s in a level 15 group made
  the time useless; the death recap's NPC ID is readable inside instances
  on Forever (8 of 10 deaths in run 1). The time only chooses among pulls
  holding the killer.
- **The middle of the weight, not the heaviest** (4 Nov 2026). Taking the
  heaviest candidate on the model's sampled grid flickered: on Ragefire's
  first leg a Trogg death moved 173 times in 1100 s, 75 of them back, once
  300 yd (a pull a few seconds long caught two grid samples or three as
  the time moved; with spread 1.0 the weights were near flat). Now the
  weights are exact (the normal's mass over each pull's stretch of pace
  factors) and the pick is where, along the way, they pass half: 12 moves,
  none back, one Trogg pull at a time. Spread 0.35 (the model's own), not
  1.0: tried in the explainer, 1.0 ran ahead of the time.
- **A fit per floor, one frame of yards** (4 Nov 2026, the Deadmines). A
  dungeon drawn on several floors is fitted on each by its own bounds; the
  bounds of one instance all give the same game yards, so the way stays one
  course and the step down to the cove is a 50 yd walk on it. Which floor a
  pack is drawn on is decided at build time (`Dev/pace_build.py`): the
  floor whose bounds hold it, and where the pictures overlap, the config's
  `heights` by its z. Spawns link into packs on one floor only: the
  Deadmines' foundry is a spiral, its upper ledge on the mines' floor and
  Gilnid 30 yd under it on the cove's at the same x and y; linked flat,
  the two would have been one pack and the ledge's Craftsmen a guard of
  Gilnid's. Heights are not enough on their own (the ship's deck lies at
  the mines' height), nor are bounds (the pictures overlap for 280 yd):
  bounds first, then height.
- **An overview's pieces are floors** (9 Nov 2026, Shadowfang Keep). DCF
  draws some dungeons as one picture of pieces at their own scales, the
  way jumping between them at linked steps. Each piece (`pieces[uiMapID]`:
  rectangles on the picture, an affine to game yards) becomes a floor of
  its own in the fit, keyed uiMapID * 10 + n with `sheet` the picture's;
  `Course` puts each point of the way on the piece holding it, and packs
  carry their piece (by height, then the piece's rectangles, at build
  time), so a pull lies only on its own piece's stretches, as on the
  Deadmines' floors. The pieces are not Blizzard's data: they were
  registered from the bosses and links, checked over the art.
- **No kill counts.** `PARTY_KILL` inside an instance comes with the victim
  and the killer secret (probe, 3 Nov: 30 of 31 hidden). Counting kills
  along the way was dropped; the dev probe (`/sd pace`) still counts them.
- **No killer-less deaths guessed.** Deaths without a killer were GM
  commands in testing; nothing infers their killer.
- **A wipe is one pull.** Its strip and all its crosses at one spot; before,
  each cross went by its own time.
- **Waits are not progress.** A second wipe at one pull minutes later went
  near the boss; long pauses and the recovery after a wipe come off.
- **Only pauses are saved**, not fights: the clock and the wipe restart
  need nothing else, and a run keeps a few dozen entries, not hundreds.

## Limits (known, accepted for now)

- **Flat within a floor.** Fit and packs ignore height on one floor: a pack
  on a level below the way counts as on it (a Shaman under Ragefire's east
  corridor took a wipe there). The spawn table has `z`; the way has none.
  Across floors the build's `heights` cure it where the floors are drawn
  apart.
- **Drawn floors only.** DCF's own art over one Blizzard floor takes that
  floor's rectangle from the data's `bounds` (Wailing Caverns, 9 Nov 2026:
  800431 over 279). An "all floors" overview takes the data's `pieces`
  (Shadowfang Keep, 9 Nov 2026), registered by hand; Gnomeregan, Sunken
  Temple and Blackrock Spire keep Plan A until theirs are. A moment on the walk between two floors
  is drawn at the nearer end.
- **The way through the pins.** A route stop is the boss's pin: where a pin
  is drawn away from the boss, the way bends to it, and packs by the real
  room may fall outside `PULL.radius` (Razorfen Downs' Glutton leg ends at
  his pin, 106 yd from him).
- **Same-name pulls.** Twelve Trogg pulls on one leg weigh nearly alike;
  the choice among them is a guess the anchors only steady.
- **Your combat, not the group's.** Pauses are the user's.
- **The model's numbers are the handover's guesses** (`Model.DEFAULTS`),
  untuned; runs now keep enough (pauses, kill and death times) to tune them.

## Saved data

New optional fields on a run (`db.instances[id]`), no migration (nothing
existing changes meaning): `pauses = { { from, to } }`, `fighting`, `calm`
(transient, cleared at the run's end). Older runs have no pauses: the clock
is their time inside. Anything else here is worked out when the map is drawn.

## Data and licence

`Core/Pace/<Name>.lua` is generated (`Dev/pace_build.py`, config in
`Dev/pace/<slug>.json`): entrance, bosses (DCF's names), packs with names,
NPC IDs and, on several floors, the floor each is drawn on; summons. Spawns: TrinityCore TDB + VMaNGOS via
advocaite/TrinityCore `forever` (release forever-tdb-2026-10-14),
GPL-2.0-or-later, credited in README and Settings → About. Never run that
server or point a client at it; only its database release is used.
Adding a dungeon: `.claude/skills/pace-data/`.

## Checking it

- `tests/pace_model.lua`: the model against the handover's 800 recorded answers.
- `tests/pace.lua`: fit, course, legs, the killer, wipes, pauses, the clock,
  anchors, the real sheet, `/sd pace`; real runs replayed with invented
  names; the Deadmines' two floors (the course down, pulls on their own
  floor, a death drawn on one floor's sheet only); Wailing Caverns' data
  bounds; Shadowfang Keep's pieces (each a floor, the way on them, the
  jumps short, guards on their boss's piece).
- `Dev/pace/overview.py`: the data over DCF's own art (a PNG, local).
- `tests/pace_data.lua`: every `ns.PaceData` file (`PACE_EXTRA`, `PACE_ONLY`,
  `PACE_SHOW` env vars): a fit, the bosses DCF's, packs whole, legs with
  pulls, and at least `ON_WAY` (40%) of the packs within 15 yd of the way.
- `.claude/pace-explainer.html` (local): the placement and the fit,
  interactive, from the production data; rebuild it with
  `.claude/pace-explainer/build.sh` after a data or rule change.
- In the client (debug on): `/sd pace` (fit, legs, each moment: how, yards,
  killer, anchor), `/sd pace map` (packs over the art), `/sd pace here`,
  `/sd pace at X Y` (a GM's `.gps`), `/sd pace clear`.
