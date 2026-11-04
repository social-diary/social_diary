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
             them is in `normal_pulls`
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
SOURCE = ("Spawns: advocaite/TrinityCore, branch forever, release forever-tdb-2026-10-14 "
          "(the vanilla world converted from VMaNGOS), GPL-2.0-or-later")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def num(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def dcf(instance_id):
    """The dungeon's name and its bosses' names, as Dungeon Crawler Forever has them."""
    text = open(DCF_DUNGEONS, encoding="utf-8").read()
    m = re.search(r"^  \[%d\] = \{ name = \"([^\"]+)\".*?^  \} \},$" % instance_id, text, re.S | re.M)
    if not m:
        sys.exit("Dungeon Crawler Forever does not know instance %d" % instance_id)
    names = re.findall(r'\{ id = \d+, name = "([^"]+)"', m.group(0))
    return m.group(1), names


def packs_of(cfg, rows):
    """The dungeon's name, its anchoring bosses [(name, x, y)], its packs, how
    many non-elite packs were left out, and notes on bosses with no anchor."""
    mid = int(cfg["map_id"])
    name, dcf_bosses = dcf(mid)
    rows = [r for r in rows if int(r["map_id"]) == mid]
    if not rows:
        sys.exit("no spawns for map %d in the spawn table" % mid)
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
    parent = {r["spawn_guid"]: r["spawn_guid"] for r in trash}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for r in trash:
        lead = r["formation_leader_guid"]
        if lead and lead in parent:
            parent[find(r["spawn_guid"])] = find(lead)
    for i in range(len(trash)):
        xi, yi = float(trash[i]["x"]), float(trash[i]["y"])
        for j in range(i + 1, len(trash)):
            if math.hypot(xi - float(trash[j]["x"]), yi - float(trash[j]["y"])) <= PACK_LINK:
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
            if math.hypot(x - bx, y - by) <= GUARD:
                guard = b
        packs.append({"x": x, "y": y, "size": len(members), "elites": elites,
                      "names": sorted({m["name"] for m in members}),
                      "npcs": sorted({int(m["npc_id"]) for m in members}), "boss": guard})

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
        L.append("        { x = %s, y = %s, size = %d, elites = %d, names = { %s }, npcs = { %s }%s }," % (
            num(p["x"]), num(p["y"]), p["size"], p["elites"], names, ids, boss))
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
