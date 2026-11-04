---
name: pace-data
description: Add or update a dungeon's pace data (Core/Pace/<Name>.lua), so the Dungeon View places deaths, wipes and rolls between bosses by the trash on the way and what killed them. Covers the spawn table, the per-dungeon config (Dev/pace/<slug>.json), the build, the checks and the in-client round. Use for "add pace data for <dungeon>", or when a dungeon's marks land on the wrong pack.
argument-hint: "[dungeon name or instance ID]"
---

# Add a dungeon's pace data

How the placement works and why: `.claude/rules/pace.md`. This skill is the
workflow. A dungeon touches only:

- `Dev/pace/<slug>.json` (its config, tracked);
- `Core/Pace/<LuaName>.lua` (generated, never edited by hand);
- `social_diary.toc` (one line after `Core/Pace/RagefireChasm.lua`);
- nothing else: `tests/pace_data.lua` checks every data file by itself.

## 0. Which dungeons can have it

The runtime places the data with **the floors' art bounds** (DCF's
`Art.lua`), one fit per floor the bosses stand on, all in one frame of game
yards (the way runs on in yards where it goes down a floor). Check Dungeon
Crawler Forever's bosses by floor (`Vendor/DungeonCrawlerForever/Data/Dungeons.lua`,
the `floor =` of each boss) and that every such floor has `bounds` before
starting:

| Group | Dungeons | Pace data now? |
|---|---|---|
| One floor with bounds | Ragefire Chasm, Stormwind Stockade, Razorfen Kraul, Razorfen Downs (all shipped 4 Nov 2026); Zul'Farrak (held: its packs lie off DCF's way) | config only |
| Several floors, each with bounds | Deadmines (shipped 4 Nov 2026), Blackfathom Deeps, Uldaman, Stratholme, Maraudon, Blackrock Depths, Scholomance, Scarlet Monastery | config, plus `heights` where the floors' pictures overlap |
| Combined maps (floor IDs 80xxxx) | Shadowfang Keep, Wailing Caverns, Gnomeregan, Sunken Temple, Blackrock Spire | not yet: needs a fit per piece |
| No public spawns | the seven new Forever dungeons | no |

A file for a dungeon that cannot fit does no harm (the fit is refused and
the map keeps its own guess), but it should not ship: `tests/pace_data.lua`
fails it.

## 1. The spawn table (once per database release)

`ref/route-model-handover/pipeline/data/dungeon_spawns_forever.csv` (local,
untracked: `ref/` is gitignored). If it is missing, rebuild it:

```
curl -LO https://github.com/advocaite/TrinityCore/releases/download/forever-tdb-2026-10-14/TDB_full_forever_2026_10_14.7z
7z e TDB_full_forever_2026_10_14.7z TDB_full_world_forever_2026_10_14.sql
python3 -I Dev/pace/dump_tables.py TDB_full_world_forever_2026_10_14.sql csv creature creature_template creature_formations instance_template
python3 -I Dev/pace/make_spawns_csv.py csv ref/route-model-handover/pipeline/data/dungeon_spawns_forever.csv
```

Columns: `map_id, dungeon, spawn_guid, npc_id, name, classification
(normal / elite / rare elite / boss), x, y, z, formation_leader_guid,
verified_build (0 = converted from VMaNGOS, unchecked on Forever), source`.
Never run the fork's server or point a client at it.

## 2. The config, `Dev/pace/<slug>.json`

Start from `Dev/pace/ragefire_chasm.json`.

| Field | What |
|---|---|
| `map_id` | the instance ID (`GetInstanceInfo`'s 8th, the key in DCF's data) |
| `slug`, `lua_name` | file names: `dev/pace/<slug>.json`, `Core/Pace/<lua_name>.lua` |
| `entrance` | `[x, y]` game yards of the way in, where known (an extra anchor); leave it out rather than guess |
| `boss_names` | `{ "DCF's name": "the table's name" }` where they really differ (the same creature, spelt otherwise). **Never** to drop a boss whose pin is off: the pins do not decide the fit any more, and a renamed boss becomes trash |
| `exclude` | creatures never pulls: event NPCs, quest givers, prisoners |
| `no_pull` | elite creatures that are not a pull of their own (a swarm, a pet that stands in a pack) |
| `normal_pulls` | non-elite creatures that are a real pull (by default a pack of non-elites only, mostly critters, is left out) |
| `summons` | `{ "npc": { "by": npc, "name", "note" } }`: an NPC in no pack (a pet, a summoned add) to the NPC that brings it, so a death to it goes to its summoner's pull |
| `heights` | several floors only: `{ "<uiMapID>": [zmin, zmax] }`. Each spawn goes on the floor whose art bounds hold it; where two floors' pictures overlap, the floor whose height range holds its `z` (zmin inclusive, zmax not). A spawn no rule settles stops the build and is listed: widen or add a range. Spawns link into packs only on one floor, and a guard is only a guard on its boss's floor (Deadmines: the foundry is a spiral, its ledge on the mines' floor and Gilnid 30 yd under it on the cove's, at the same x and y) |
| `notes` | what was decided and checked, with the date |

To look at a dungeon's spawns: `awk -F, '$1==<map_id>' <csv> | cut -d, -f4-7 | sort | uniq -c -f1` (npc,
name, classification), or read the rows near a boss. Things to look for:
creatures that only appear by event or script (not in the table: their
deaths fall back to time; add a `summons` entry if a known pack brings
them), friendly NPCs (exclude), and non-elite trash that is a real pull.

Several floors: find the heights first. Sort the spawns by `z` and, for the
ones inside both floors' bounds, look for the gap (Deadmines: nothing between
41 and 47 yd; the ship's deck at 40 lies on the cove's picture only, so the
bounds settle it, not the height). A pack's floor is written into the data
(`floor = <uiMapID>`); in the client, `/sd pace map` draws each pack on its
own floor's sheet.

## 3. Build and check

```
python3 -I Dev/pace_build.py Dev/pace/<slug>.json          # writes Core/Pace/<LuaName>.lua
PACE_EXTRA=Core/Pace/<LuaName>.lua PACE_ONLY=<map_id> PACE_SHOW=1 luajit tests/run.lua pace_data
```

`PACE_EXTRA` loads the file before it is in the TOC. What to read in the
output, and what is wrong when it fails:

- **fit … by bounds**: the floors' art bounds were used (several floors
  are listed). "by anchors" means the one floor has none (the pins decide,
  12 yd limit); several floors with one lacking bounds: no fit.
- **DCF's pins: worst …**: how far DCF drew each pin from its boss's
  spawn. Only a note (Roogug 160 yd, Glutton 106): a large one says the way
  bends to a drawn pin there; it never fails the check.
- **packs near it / median**: the check that leans on no pin. At least 40%
  of the packs within 15 yd of the usual way, on their own floor (Ragefire
  50 of 68, median 5 yd; Deadmines 42 of 64, median 7.6). Failing it means the bounds, the spawns or DCF's way are off: look
  before shipping (Zul'Farrak: 30 of 107, median 38 yd: its way runs
  through spread pins). Any of DCF's data can be wrong.
- **each leg**: yards and pulls plausible; the model's time for the whole
  run roughly what a levelling group takes.

Then add the TOC line (after `Core/Pace/RagefireChasm.lua`, before
`Core/DungeonPace.lua`) and run the whole suite: `luajit tests/run.lua`.

## 4. In the client (dev machine, debug on)

1. `/reload` in and outside the dungeon: no Lua errors.
2. Open a run's map, `/sd pace map`: red packs in the drawn corridors,
   blue rings (the data's way in and bosses) on the map's own. Several
   floors: turn the sheet to each floor; a pack shows on its own floor only,
   and a death the model placed is drawn on one floor's sheet, not both.
3. Die to trash a few times (killers recorded), wipe once: `/sd pace` shows
   `killer` for them, the crosses at a pack of that creature.
4. A spot that looks wrong: stand there, `.gps`, `/sd pace at X Y`; it gives
   yards along the way to compare with where the mark went.

## 5. Finish

- `CHANGELOG.md` (through /copywriter): which dungeons now have it.
- The config's `notes`: what was checked, and when.
- What this run taught (a new kind of mismatch, a field that was needed):
  back into this skill and `.claude/rules/pace.md`.
