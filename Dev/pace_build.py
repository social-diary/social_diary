#!/usr/bin/env python3
"""Builds a dungeon's pace data (Core/Pace/<LuaName>.lua) for Core/DungeonPace.lua
from the spawn table and the dungeon's config (Dev/pace/<slug>.json).

    python3 -I Dev/pace_build.py Dev/pace/ragefire_chasm.json
    python3 -I Dev/pace_build.py Dev/pace/*.json            (all of them)

    --csv PATH   the spawn table (default: ref/route-model-handover/pipeline/
                 data/dungeon_spawns_forever.csv, local and untracked: how to
                 make it is in .claude/skills/pace-data/SKILL.md)
    --check      write nothing; say what would change

Standard library only. The workflow, the config's fields and the checks that
follow are in .claude/skills/pace-data/SKILL.md; the design in
.claude/rules/pace.md.

What it writes, all in game yards (x north, y west):
  entrance   from the config, where given (an anchor for the fit)
  bosses     the dungeon's bosses as Dungeon Crawler Forever names them
             (Vendor/DungeonCrawlerForever/Data/Dungeons.lua), each where
             its one spawn stands; a boss with no spawn, or several, is left
             out (it is no anchor)
  packs      the trash, grouped as the handover's pipeline grouped it:
             formation links, then any two within PACK_LINK yards; each
             with its size, its elites, its names and NPC IDs, and the boss
             whose room it guards (within GUARD yards of one). Left out:
             the bosses, the config's `exclude` and `no_pull` creatures,
             and a pack of non-elites only (critters, swarms) unless one of
             them is in `normal_pulls`. In a dungeon drawn on several
             floors (DCF's Art.lua), each spawn is put on its floor first
             (`floor`, the uiMapID): the floor whose art bounds hold it;
             where two floors' pictures overlap, the config's `heights`
             ({ uiMapID: [zmin, zmax] }) decide by its height; a spawn no
             rule settles stops the build. Spawns link into packs only on
             one floor (Deadmines' foundry is a spiral: its top is drawn on
             the mines' floor, its bottom on the cove's, 30 yd below).
  summons    the config's: an NPC in no pack (a pet, an add) to the NPC
             that brings it
"""
import argparse
import csv
import json
import math
import os
import re
import sys

PACK_LINK = 12.0  # yards: two spawns this close are one pack (the handover's)
GUARD = 12.0      # yards: a pack this close to a boss is pulled with the boss
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CSV_DEFAULT = os.path.join(ROOT, "ref/route-model-handover/pipeline/data/dungeon_spawns_forever.csv")
DCF_DUNGEONS = os.path.join(ROOT, "Vendor/DungeonCrawlerForever/Data/Dungeons.lua")
DCF_ART = os.path.join(ROOT, "Vendor/DungeonCrawlerForever/Data/Art.lua")
SOURCE = ("Spawns: advocaite/TrinityCore, branch forever, release forever-tdb-2026-10-14 "
          "(the vanilla world converted from VMaNGOS), GPL-2.0-or-later")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def num(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def dcf(instance_id):
    """The dungeon's name, its bosses' names and each boss's floor (uiMapID, or
    None), as Dungeon Crawler Forever has them."""
    text = open(DCF_DUNGEONS, encoding="utf-8").read()
    m = re.search(r"^  \[%d\] = \{ name = \"([^\"]+)\".*?^  \} \},$" % instance_id, text, re.S | re.M)
    if not m:
        sys.exit("Dungeon Crawler Forever does not know instance %d" % instance_id)
    names, floors = [], {}
    for b in re.finditer(r'\{ id = \d+, name = "([^"]+)"([^}]*)\}', m.group(0)):
        names.append(b.group(1))
        f = re.search(r"floor = (\d+)", b.group(2))
        floors.setdefault(b.group(1), int(f.group(1)) if f else None)
    return m.group(1), names, floors


def floors_of(instance_id):
    """The dungeon's drawn floors, as Dungeon Crawler Forever has them:
    { uiMapID: (name, [x1, y1, x2, y2]) }, the art bounds in game yards."""
    text = open(DCF_ART, encoding="utf-8").read()
    m = re.search(r"^  \[%d\] = \{.*?^  \},$" % instance_id, text, re.S | re.M)
    out = {}
    for f in re.finditer(r'uiMapID = (\d+), name = "([^"]+)", bounds = \{([^}]*)\}', m.group(0) if m else ""):
        out[int(f.group(1))] = (f.group(2), [float(v) for v in f.group(3).split(",")])
    return out


def floor_of(r, floors, heights):
    """The floor spawn `r` is drawn on: the one whose bounds hold it; several,
    the one whose height range (the config's `heights`) holds its z. None
    where no rule settles it."""
    x, y, z = float(r["x"]), float(r["y"]), float(r["z"])
    held = [f for f, (_, b) in floors.items() if b[0] <= x <= b[2] and b[1] <= y <= b[3]]
    if len(held) == 1:
        return held[0]
    by_height = [f for f in held if f in heights and heights[f][0] <= z < heights[f][1]]
    return by_height[0] if len(by_height) == 1 else None


def packs_of(cfg, rows):
    """The dungeon's name, its anchoring bosses [(name, x, y)], its packs, how
    many non-elite packs were left out, and notes on bosses with no anchor."""
    mid = int(cfg["map_id"])
    name, dcf_bosses, boss_floor = dcf(mid)
    rows = [r for r in rows if int(r["map_id"]) == mid]
    if not rows:
        sys.exit("no spawns for map %d in the spawn table" % mid)
    floors = floors_of(mid)
    several = len(floors) > 1
    heights = {int(k): v for k, v in cfg.get("heights", {}).items()}
    for f in heights:
        if f not in floors:
            sys.exit("%s: heights for floor %d, which the map does not draw" % (name, f))
    db_name = cfg.get("boss_names", {})          # Dungeon Crawler Forever's name -> the table's
    boss_db = {db_name.get(b, b): b for b in dcf_bosses}
    exclude = set(cfg.get("exclude", [])) | set(cfg.get("no_pull", []))
    keep_normal = set(cfg.get("normal_pulls", []))

    bosses, notes = [], []
    for b in dcf_bosses:
        spawns = [r for r in rows if r["name"] == db_name.get(b, b)]
        if len(spawns) == 1:
            bosses.append((b, float(spawns[0]["x"]), float(spawns[0]["y"])))
        else:
            notes.append("%s: %d spawns, no anchor" % (b, len(spawns)))

    trash = [r for r in rows if r["name"] not in boss_db and r["name"] not in exclude]
    floor = {}
    if several:
        lost = []
        for r in trash:
            floor[r["spawn_guid"]] = floor_of(r, floors, heights)
            if floor[r["spawn_guid"]] is None:
                lost.append("%s at %s, %s, z %s" % (r["name"], r["x"], r["y"], r["z"]))
        if lost:
            sys.exit("%s: no floor for %d spawns (the bounds overlap there: add `heights`):\n  %s"
                     % (name, len(lost), "\n  ".join(lost)))
    parent = {r["spawn_guid"]: r["spawn_guid"] for r in trash}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def same_floor(a, b):
        return floor.get(a["spawn_guid"]) == floor.get(b["spawn_guid"])

    by_guid = {r["spawn_guid"]: r for r in trash}
    for r in trash:
        lead = r["formation_leader_guid"]
        if lead and lead in parent and same_floor(r, by_guid[lead]):
            parent[find(r["spawn_guid"])] = find(lead)
    for i in range(len(trash)):
        xi, yi = float(trash[i]["x"]), float(trash[i]["y"])
        for j in range(i + 1, len(trash)):
            if same_floor(trash[i], trash[j]) and \
                    math.hypot(xi - float(trash[j]["x"]), yi - float(trash[j]["y"])) <= PACK_LINK:
                parent[find(trash[i]["spawn_guid"])] = find(trash[j]["spawn_guid"])
    groups = {}
    for r in trash:
        groups.setdefault(find(r["spawn_guid"]), []).append(r)

    packs, dropped = [], 0
    for _, members in sorted(groups.items(), key=lambda g: -float(g[1][0]["x"])):
        elites = sum(1 for m in members if "elite" in m["classification"] or m["classification"] == "boss")
        if elites == 0 and not any(m["name"] in keep_normal for m in members):
            dropped += 1
            continue
        x = sum(float(m["x"]) for m in members) / len(members)
        y = sum(float(m["y"]) for m in members) / len(members)
        guard = None
        for b, bx, by in bosses:
            # On its boss's floor: the foundry's upper ledge is 12 yd from
            # Gilnid in x and y, and 30 yd above him.
            if math.hypot(x - bx, y - by) <= GUARD and \
                    (not several or boss_floor.get(b) == floor.get(members[0]["spawn_guid"])):
                guard = b
        packs.append({"x": x, "y": y, "size": len(members), "elites": elites,
                      "names": sorted({m["name"] for m in members}),
                      "npcs": sorted({int(m["npc_id"]) for m in members}), "boss": guard,
                      "floor": floor.get(members[0]["spawn_guid"])})

    return name, bosses, packs, dropped, notes


def build(cfg, rows):
    mid = int(cfg["map_id"])
    name, bosses, packs, dropped, notes = packs_of(cfg, rows)
    exclude = set(cfg.get("exclude", [])) | set(cfg.get("no_pull", []))
    npcs_in_packs = {n for p in packs for n in p["npcs"]}
    summons = cfg.get("summons", {})
    for npc, s in summons.items():
        if int(s["by"]) not in npcs_in_packs:
            sys.exit("%s: summon %s's summoner %s is in no pack" % (name, npc, s["by"]))

    L = []
    L.append("-- %s's pace data (instance %d), for Core/DungeonPace.lua. Generated by" % (name, mid))
    L.append("-- Dev/pace_build.py from Dev/pace/%s.json; do not edit by hand." % cfg["slug"])
    L.append("-- " + SOURCE + ".")
    L.append("-- Game yards (x north, y west): the entrance and the bosses, which the")
    L.append("-- addon fits its own map to, and every trash pack (where it stands, its")
    L.append("-- size and elites, who is in it by name and NPC ID, `boss` the boss whose")
    L.append("-- room it guards); `summons`: an NPC in no pack (a pet, an add) to the NPC")
    L.append("-- that brings it, so a death to it is a death at its summoner's pull.")
    if any(p["floor"] for p in packs):
        L.append("-- Drawn on several floors: `floor` is the uiMapID each pack is drawn on")
        L.append("-- (its art bounds; where two overlap, its height), the floor its pulls are")
        L.append("-- laid on.")
    left = sorted(exclude)
    L.append("-- Left out: %s; %d packs of non-elites only." % (", ".join(left) if left else "no creature by name", dropped))
    for n in notes:
        L.append("-- " + n + ".")
    L.append("")
    L.append("local addonName, ns = ...")
    L.append("")
    L.append("local data = {")
    L.append("    name = %s, instanceID = %d," % (lua_str(name), mid))
    L.append("    source = %s," % lua_str(SOURCE))
    if cfg.get("entrance"):
        L.append("    entrance = { x = %s, y = %s }," % (num(float(cfg["entrance"][0])), num(float(cfg["entrance"][1]))))
    L.append("    bosses = {")
    for b, bx, by in bosses:
        L.append("        { name = %s, x = %s, y = %s }," % (lua_str(b), num(bx), num(by)))
    L.append("    },")
    L.append("    packs = {")
    for p in packs:
        names = ", ".join(lua_str(n) for n in p["names"])
        ids = ", ".join(str(i) for i in p["npcs"])
        boss = (", boss = " + lua_str(p["boss"])) if p["boss"] else ""
        floor = (", floor = %d" % p["floor"]) if p["floor"] else ""
        L.append("        { x = %s, y = %s, size = %d, elites = %d, names = { %s }, npcs = { %s }%s%s }," % (
            num(p["x"]), num(p["y"]), p["size"], p["elites"], names, ids, boss, floor))
    L.append("    },")
    L.append("    summons = {")
    for npc, s in sorted(summons.items(), key=lambda kv: int(kv[0])):
        L.append("        [%d] = %d, -- %s: %s" % (int(npc), int(s["by"]), s.get("name", ""), s.get("note", "")))
    L.append("    },")
    L.append("}")
    L.append("")
    L.append("ns.PaceData = ns.PaceData or {}")
    L.append("ns.PaceData[data.instanceID] = data")
    L.append("return data")
    return name, "\n".join(L) + "\n", len(bosses), len(packs), dropped, notes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("configs", nargs="+")
    ap.add_argument("--csv", default=CSV_DEFAULT)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if not os.path.exists(a.csv):
        sys.exit("no spawn table at %s (see .claude/skills/pace-data/SKILL.md)" % a.csv)
    rows = list(csv.DictReader(open(a.csv, encoding="utf-8")))
    for path in a.configs:
        cfg = json.load(open(path, encoding="utf-8"))
        name, text, nb, npk, dropped, notes = build(cfg, rows)
        out = os.path.join(ROOT, "Core/Pace/%s.lua" % cfg["lua_name"])
        old = open(out, encoding="utf-8").read() if os.path.exists(out) else None
        state = "unchanged" if old == text else ("new" if old is None else "changed")
        print("%s: %d bosses as anchors, %d packs (%d of non-elites only left out) -> %s, %s"
              % (name, nb, npk, dropped, os.path.relpath(out, ROOT), state))
        for n in notes:
            print("  " + n)
        if not a.check and state != "unchanged":
            open(out, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
