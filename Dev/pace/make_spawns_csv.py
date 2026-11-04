"""World database CSVs -> data/dungeon_spawns_forever.csv (one row per creature spawn in a 5-player dungeon).

usage:
  python3 -I dump_tables.py TDB_full_world_forever_2026_10_14.sql csv creature creature_template creature_formations instance_template
  python3 -I make_spawns_csv.py csv data/dungeon_spawns_forever.csv

Source rows with VerifiedBuild > 0 were recorded on the Forever beta; 0 means converted from VMaNGOS.
"""
import csv
import sys

src, out = sys.argv[1:3]
ct = {r["entry"]: r for r in csv.DictReader(open(f"{src}/creature_template.csv", encoding="utf-8"))}
leader = {r["memberGUID"]: r["leaderGUID"] for r in csv.DictReader(open(f"{src}/creature_formations.csv", encoding="utf-8"))}
inst = {r["map"]: r["script"].replace("classic_instance_", "")
        for r in csv.DictReader(open(f"{src}/instance_template.csv", encoding="utf-8"))}
RAIDS = ("onyxia", "molten", "blackwing", "naxx", "ahnqiraj", "zulgurub", "black_morass")
CLS = {"0": "normal", "1": "elite", "2": "rare elite", "3": "boss", "4": "rare", "5": "trivial", "6": "minus"}
n = 0
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["map_id", "dungeon", "spawn_guid", "npc_id", "name", "classification", "x", "y", "z",
                "formation_leader_guid", "verified_build", "source"])
    for r in csv.DictReader(open(f"{src}/creature.csv", encoding="utf-8")):
        d = inst.get(r["map"])
        if not d or any(s in d for s in RAIDS):
            continue
        t = ct.get(r["id"], {})
        vb = int(r["VerifiedBuild"] or 0)
        w.writerow([r["map"], d, r["guid"], r["id"], t.get("name", ""),
                    CLS.get(t.get("Classification", ""), t.get("Classification", "")),
                    r["position_x"], r["position_y"], r["position_z"], leader.get(r["guid"], ""), vb,
                    "Forever beta sniff" if vb > 0 else "VMaNGOS (vanilla 1.12)"])
        n += 1
print(out, n, "spawns")
