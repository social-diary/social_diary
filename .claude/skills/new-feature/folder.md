# A feature's folder

What goes where in `Features/<Name>/`, the registries it plugs into, where its
capture loads, its test data, and the patterns earlier features worked out.
The spec comments in the code are the truth for every field. This file
says where they are and what was learnt using them. Keep it current
(SKILL.md, phase 11).

## Files

Each file is optional: a feature has the ones its surface sheet needs.
Inside the folder they load in this order. Each file may use what the
earlier ones made at load time, and anything at call time.

| File | Holds | Registers |
|---|---|---|
| `Kind.lua` | The header: the folder's files, one line each, and **what stays core** (the diary's substrate the feature uses but doesn't own). Makes the namespace: `local X = {}; ns.X = X`, the only table the feature owns. The row kinds, the route list with its writers and readers, the recap moment (with the reasoning for its rank and lightness in a comment), its art. | `ns.Rows.Register`, `ns.Journey.RegisterList`, `ns.JourneyRecap.RegisterMoment`, `ns.Style.AddArt` |
| `Data.lua` | Static tables, with a comment saying where they came from (`ns.QuestFinales.CHAINS`). Read at call time only. | — |
| `Text.lua` | Words a player reads on the plates and the left page: `X.WORDS`, tooltips (`X.Tip`), caption words, the level's paragraph. Shared helpers are taken at load time from `ns.UI.JourneyText` / `ns.UI.TimelineText`. | `RegisterCaption`, `RegisterLines` |
| `Mark.lua` | The mark's look table (`X.MARK`, commented field by field, with dated render notes) and its shape, drawn only through the kit. | `ns.UI.JourneyPlate.RegisterMark` |
| `Slip.lua` / `Card.lua` (or named cards: `HuntCard.lua`) | The margin note's frame, and its margin registration at the file's foot. Or a face worn on another feature's card. Or a pass over the picture. | `ns.UI.JourneyMargin.Register`, `ns.UI.JourneyPlate.RegisterPass`, `ns.Deaths.Card.RegisterFace` |
| `Capture.lua` | Event listeners. Takes the namespace (`local X = ns.X`), never makes it. Writes through `X.Added(...)` (gated by `ns.Journey.Kept()`) and `ns.Interactions.Add(guid, kind, ...)`. Test hooks go on `ns._test.X`. | `ns.On(event or SD_*)` |
| `Dev.lua` | Its part of `/sd testdata` (never packaged). | `ns.TestData.Register(point, fn)` |

**Namespace rule.** The feature's names live on `ns.<Name>`, and nothing is
assigned onto a core or UI table (no `Journey.X`, `Text.X`, `Plate.X`).
Core reaches the feature only through what it registered, through flags,
and through `SD_*` messages. Tests read `ns.<Name>.*`. Another feature may
read a feature's exports **at call time** (Witnesses' card uses
`ns.Hunts.LuckyCard`'s pen). The dependency then goes one way only, and the
TOC order follows it.

**Groups.** Features of one kind may sit one level down in a group folder,
`Features/<Group>/<Name>/` (`Features/Classes/Hunter/`: one class's
moments). A group holds folders only and makes no namespace; each feature
in it makes `ns.<Name>` as any other, so names are unique across groups.
kinds.lua checks the nesting, the TOC and `.pkgmeta`'s `Features/*/*/Dev.lua`.
A group gets shared files only once a second feature in it shows what is
shared.

## Registries and where their specs are

| Registry | Spec comment above it in | Notes |
|---|---|---|
| `ns.Rows.Register(kind, spec)` | `Core/Rows.lua` (header) | Flags core reads instead of naming kinds: `climb`, `fight`, `witness`, `dealt` (from `Rows.DEALT` only). Words (`text`), `icon`, `reason`, `moment` in the same call. A `text` that says "you" goes through `ns.UI.Format.You(row.me, "{You} killed ")`, so a shared diary names the alt that wrote it (`UI/Words/Format.lua`). |
| `ns.Journey.RegisterList(name, spec)` | `Core/Journey.lua` | `cap` (goes into `Journey.T`), `named`, `readNames` (`true` or a function: the list reads its own creature names), `prune(j, now)`, `forget(j, guid)`. A keyed table registers with no `cap`, for `prune` / `forget` alone (Firsts). Write with `Journey.Append(j, name, rec, where)`, read with `Journey.List(j, name)`. |
| `ns.JourneyRecap.RegisterMoment(kind, spec)` | `Core/JourneyRecap.lua` | `order`, `list` or `gather`, `entry`, `field`, `rank`, `light`, `rankAs`, `moment`, `person` (a moment that is also someone's: a gift), `custom` (a card the player may edit or insert: its spec in `Core/Custom.lua`'s header; `custom.offer()` keeps a class's card off other classes' pickers). Needs a mark of the same kind (kinds.lua). |
| `ns.UI.JourneyPlate.RegisterMark(kind, spec)` | `UI/Journey/Plate.lua` | `order` (not the road deaths' turn), `cap` + `count` (in `Plate.CAP`), `radius`, `halo`, `hover`, `draw(kit, x, y, arg)`, `arg`, `tip`, `keep`, `join`, `chosen`, `choose`. |
| `ns.UI.JourneyPlate.RegisterPass(key, spec)` | `UI/Journey/Plate.lua` | After every mark: `order` (killer 10, foe 20, witness 30, print 90), `draw(plate, c)`, `new(plate, kit)` for its own layers on the `over` frame. |
| `ns.UI.JourneyMargin.Register(kind, spec)` | `UI/Journey/Margin.lua` | `order`, `pool`, `count`, `item`/`items`, `new`, `write`, `mark`, `assume`, `say`, `filler`, `flag`, `wants`, `fits`, `after`. |
| `ns.Deaths.Card.RegisterFace(key, face)` | `Features/Deaths/Card.lua` | Wear the killer card (Close calls). |
| `ns.UI.JourneyText.RegisterCaption(key, spec)` | `UI/Journey/Text/Caption.lua` | `lead` / `tail` / `coda`, each `{ at, say }`, with the `said` table shared between kinds. |
| `ns.UI.JourneyText.RegisterLines(key, spec)` | `UI/Journey/Text/Prose.lua` | `at`, `lines(e, now, index)`, `run` (several kinds share one paragraph: "combat"). Reads `e[entry]`, never another feature's. |
| `ns.Style.AddArt(key, paths, tint)` | `UI/Style/Art.lua` | The feature's own art. Art shared with a core activity stays core. |
| `ns.TestData.Register(point, fn)` | `Dev/TestData.lua` | See "Test data" below. |
| `ns.UI.Journal.RegisterPage`, `ns.UI.Settings.RegisterSection`, `Slash.Register` | `UI/Journal/Pages.lua`, `UI/Settings/Page.lua`, `Core/Slash.lua` | Rarely a feature's. A setting follows `.claude/rules/settings.md`. |

Cards on a paper strip: the contract is in the header above
`ns.UI.PaperStrip` (`UI/Paper/Strip.lua`), and `.claude/rules/ui.md` has the
rest of the UI's rules.

## Messages a feature can listen to

`Core/Events.lua`'s header lists them, with their arguments and when they
fire. Dispatch is synchronous. A listener runs inside the dispatcher's
pcall, so its error is logged and doesn't unwind the sender.

| Message | Fired |
|---|---|
| `SD_WORLD_SETTLED` | a few seconds after entering the world. Take a first reading here (Firsts, then Profession caps). |
| `SD_QUEST_ACCEPTED (questID)`, `SD_QUEST_TURNED_IN (questID)` | after the route counted the quest |
| `SD_LEVEL_ROSE (guid, from, level)` | a character read at a higher level, the user's own included |
| `SD_YOU_DIED (death)`, `SD_DEATH_RECAP (death, killer)` | the user died; the recap named who did it |
| `SD_TRADE_COMPLETED (guid, received)` | a trade completed |
| `SD_FIGHT_SURVIVED (started, ended, taken, max, foe)` | every fight the close-call judge read (never a duel's) |
| `SD_DUEL_STARTED (guid)`, `SD_DUEL_FINISHED (guid, outcome)` | a duel's countdown began / it ended (outcome nil: no winner); fired by Duels. Kept by core as `ns.Duelling(guid, grace)`, which Close calls' judge, the route (no fighting) and the sightings (not hostile) read: a flight's end can come long after combat |
| `SD_REUNION`, `SD_DIARY_CHANGED`, `SD_PAPER_CHANGED` | core's own; rarely a feature's |

Core helpers a feature calls:
- `ns.Journey.Kept()`: the character's route while it is kept, else nil.
  Write only while it gives one.
- `ns.Interactions.Add`;
- `ns.CreatureNames` (a creature's name read off units);
- `ns.QuestieBridge.*`, at call time and guarded;
- `ns.Deaths.LookUp`, guarded.

A one-line client read (`ns.Plain(UnitLevel("player"))`) is written in
place. Anything longer is a core helper.

## Where capture loads

The TOC is the load order, and the load order is the **event-handler
order**. This is a decision, not a default:

1. List every client event the capture listens to.
2. For each one, find every other `ns.On` for it in `Core/`, `Capture/`,
   `Features/` and `UI/`, and write down what each handler reads and
   writes.
3. If no other handler shares state with the feature's, put `Capture.lua`
   in the **features block** (it then runs *before* `Capture/`). This is
   the usual case.
4. If a core handler on the same event changes something the feature
   reads, or the other way round, either:
   - listen to an `SD_*` message fired at the right point (a core hook,
     phase 4b), or
   - list `Capture.lua` **after `Capture/`**, as Witnesses and Hunts do,
     so every order is the old one by construction.
5. Write the reasoning in the TOC comment and the header of `Capture.lua`.
   Where the order matters, add a test that fails if the file moves.

The case that bit us: Witnesses reading a unit in a fight filled in a
diary entry's surname before Nearby's reunion toast took its snapshot. The
toast said "Bram Redfen" where it should have said "Bram"
(`tests/witnesses.lua`, "after the reunion toast").

## TOC

```
# Features: … (the block's comment says why each feature sits where it does)
Features/<Name>/Kind.lua
Features/<Name>/Data.lua
Features/<Name>/Text.lua
Features/<Name>/Mark.lua
Features/<Name>/Slip.lua
Features/<Name>/Capture.lua      (or after Capture/, see above)

Capture/Menus.lua
…
#@do-not-package@
…
Dev/TestData.lua
Features/<Name>/Dev.lua
#@end-do-not-package@
```

- A feature that reads another at load time comes after it.
- Features whose Dev.lua write at the same point come in the order their
  rows should land.
- `.pkgmeta` already leaves out every `Features/*/Dev.lua`.

## Test data (Dev.lua)

`TestData.Register(point, fn)` runs `fn(c)` at the point, after what the
script itself writes there, in TOC order:

| Point | When | `c` |
|---|---|---|
| `"tester"` | after each of Tester's four sessions' rows | `n`, `session`, `now`, `GUID`, `Row(kind, time, zone, data, session)` |
| `"beat"` | between the script's own moments: `c.at` is "met", "traded", "began" or "now" | `t`, plus the same fields as "tester" |
| `"route"` | after the made-up route is written | `j`, `now`, `start`, `Stop(level, subZone)` → `{ from, to, level, subZone, mapID, x, y }` |
| `"remove"` | `/sd testdata remove`, for what is neither on the route nor on Tester | empty |

- Time records **off stops** (`c.Stop(11, "Valley of Strength").to - 500`),
  never as copied absolute times.
- On the route, write the list as capture keeps it (`j.<list> = {}` then
  the records), not through `X.Add`.
- Made-up strangers are forgotten at `"remove"` (`Characters.Forget`).

## Tests

- `tests/<name>.lua` covers capture and data. Fake what the client sends
  (`_G.C_UnitAuras = …`), drive events with `mock.fire` and timers with
  `mock.RunTimers` / `mock.now`, use the fixtures' invented players
  (`T.F`), and check what was stored. `tests/campfire.lua` is a compact
  example.
- `tests/<name>_ui.lua` covers the UI: the mark, the note, the words on the
  testdata pages (`tests/lucky_card.lua`, `tests/hunt_card.lua`).
- Add both to `FILES` in `tests/run.lua`. `tests/kinds.lua` checks the
  feature's registrations by itself, with nothing to add.
- **Break every new hook once:** break it, watch a test fail, restore the
  file byte for byte.
- Mind the luajit pitfall: `luajit -bl a.lua b.lua` writes into `b.lua`.

## Patterns by example

Start from the nearest one. Its `Kind.lua` header explains the folder.

| Shape | Folder | What it shows |
|---|---|---|
| People rows only | `Chat`, `Trade`, `LevelUps` | `Kind` + `Capture` + `Dev`; a row's words and icon in one `Rows.Register`; a core function's tail as an `SD_*` message (LevelUps) |
| A detection with no row of its own | `Rares` | writes into core session data (`Sessions.Rare`); no Dev.lua |
| Rows that core counts | `WorldPvP` | a Rows flag (`fight`) plus a small core read keyed by the flag (`Interactions.Fights`), never core reading `ns.WorldPvP`; route marks written through `Journey.Fight` |
| An aura in the world: list, light moment, mark, small slip | `Campfire` | the first folder made; a minute-by-minute aura watch; a slip with locked words |
| **Cards, two moments from one list, a pass: the UI model** | `Hunts` | one list registered once with two moments (`gather` fills both); two marks, two cards on the strip, the lucky print as a pass with `new`; capture after `Capture/` |
| A shared card and a pass | `Deaths` | the killer card other features wear; death crosses stay core, what is layered on them is the feature's |
| A face on another feature's card | `CloseCalls` | `RegisterFace`; split out of shared files; `readNames` |
| Units a core capture also reads | `Witnesses` | capture after `Capture/`; a page-wide index by a flag stays core, the feature's reading of it moves; strangers forgotten at `"remove"` |
| A keyed table, a gift, a bespoke mark | `Firsts` | `forget`/`prune` without a cap; `person` on a moment; `join` on a mark; a hand-off from Trade by `SD_TRADE_COMPLETED` |
| Static data | `QuestFinales` | `Data.lua`; `SD_QUEST_*` |
| A reading against the last one | `ProfessionCaps` | first reading on `SD_WORLD_SETTLED` |

## Learnt the hard way

- **Event order is invisible to the tests that dump output.** Only a
  handler-by-handler check, written down, catches it. See "Where capture
  loads".
- A direct call turned into an `SD_*` message now runs in the dispatcher's
  pcall: an error is logged instead of unwinding the sender. Say so where
  it matters.
- Prefer a kind flag or an `SD_*` message over core naming a feature, and
  core counting rows by a flag over core UI reaching into a feature.
- Read a feature's `Kind.lua` header before calling something in core
  "left over": many core pieces are declared substrate on purpose.
- A local named like a Blizzard global (`Settings`) shadows the client's
  API.
- Ask the user scope questions about what a player sees, never about the
  code's internals.
