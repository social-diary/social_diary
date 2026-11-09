#!/usr/bin/env python3
"""Draws a dungeon's pace data over Dungeon Crawler Forever's own art (the
custom pictures in Vendor/DungeonCrawlerForever/Art, ArtCustom.lua: BLP2,
DXT1), to check a config's `pieces` or `bounds` by eye before the client.

    python3 -I Dev/pace/overview.py Dev/pace/shadowfang_keep.json out.png
    python3 -I Dev/pace/overview.py Dev/pace/shadowfang_keep.json out.png --spawns

White: DCF's usual way (a jump between linked steps left out). Red: the
built packs (Core/Pace/<LuaName>.lua), bigger for more elites. Yellow: the
bosses' spawns. With --spawns, every spawn in the table as well, small and
black. Points go through the piece their pack is on (`floor`), or through
`bounds`. PNGs stay local (.gitignore). Standard library only.
"""
import argparse
import csv
import json
import os
import re
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DCF = os.path.join(ROOT, "Vendor/DungeonCrawlerForever")
CSV_DEFAULT = os.path.join(ROOT, "ref/route-model-handover/pipeline/data/dungeon_spawns_forever.csv")


def dxt1(data, w, h):
    px = bytearray(w * h * 3)
    o = 0
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            c0, c1, bits = struct.unpack("<HHI", data[o:o + 8])
            o += 8

            def rgb(v):
                return ((v >> 11) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31)
            p0, p1 = rgb(c0), rgb(c1)
            if c0 > c1:
                p2 = tuple((2 * a + b) // 3 for a, b in zip(p0, p1))
                p3 = tuple((a + 2 * b) // 3 for a, b in zip(p0, p1))
            else:
                p2, p3 = tuple((a + b) // 2 for a, b in zip(p0, p1)), (0, 0, 0)
            pal = (p0, p1, p2, p3)
            for i in range(16):
                x, y = bx + i % 4, by + i // 4
                if x < w and y < h:
                    q = (y * w + x) * 3
                    px[q:q + 3] = bytes(pal[(bits >> (2 * i)) & 3])
    return px


def blp(path):
    d = open(path, "rb").read()
    if d[:4] != b"BLP2" or d[8] != 2 or d[9] != 0:
        sys.exit("%s: only BLP2 DXT1 without alpha is read here" % path)
    w, h = struct.unpack("<II", d[12:20])
    off, size = struct.unpack("<I", d[20:24])[0], struct.unpack("<I", d[84:88])[0]
    return w, h, dxt1(d[off:off + size], w, h)


def png(path, w, h, px):
    raw = b"".join(b"\0" + bytes(px[y * w * 3:(y + 1) * w * 3]) for y in range(h))

    def chunk(t, b):
        return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def art(mid, ui_map):
    text = open(os.path.join(DCF, "Data/ArtCustom.lua"), encoding="utf-8").read()
    m = re.search(r"uiMapID = %d,.*?w = (\d+), h = (\d+), tile = (\d+), tiles = \{\{\"[^\"]*\\\\(\d+_\d+)_1_1\"" % ui_map, text)
    if not m:
        sys.exit("no custom art %d for instance %d" % (ui_map, mid))
    W, H, T, prefix = int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)
    big = bytearray(W * H * 3)
    for r in range(H // T):
        for c in range(W // T):
            w, h, px = blp(os.path.join(DCF, "Art/%s_%d_%d.blp" % (prefix, r + 1, c + 1)))
            for y in range(T):
                q = ((r * T + y) * W + c * T) * 3
                big[q:q + T * 3] = px[y * w * 3:y * w * 3 + T * 3]
    return W, H, big


def route(mid):
    text = open(os.path.join(DCF, "Data/Routes.lua"), encoding="utf-8").read()
    m = re.search(r"\[%d\] = \{\n\s*\[0\] = (\{.*?\}) \},\n" % mid, text, re.S)
    return [(int(f), float(x), float(y)) for f, x, y in
            re.findall(r"\{ f = (\d+), x = ([\d.]+), y = ([\d.]+)", m.group(1))] if m else []


def links(mid):
    text = open(os.path.join(DCF, "Data/Markers.lua"), encoding="utf-8").read()
    m = re.search(r"ns\.MarkerLinks = \{.*?\[%d\] = \{(.*?)\n  \}," % mid, text, re.S)
    out = set()
    for xa, ya, xb, yb in re.findall(r"xa = ([\d.]+), ya = ([\d.]+), fb = \d+, xb = ([\d.]+), yb = ([\d.]+)", m.group(1) if m else ""):
        out.add(((float(xa), float(ya)), (float(xb), float(yb))))
        out.add(((float(xb), float(yb)), (float(xa), float(ya))))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("config")
    ap.add_argument("out")
    ap.add_argument("--spawns", action="store_true")
    ap.add_argument("--csv", default=CSV_DEFAULT)
    a = ap.parse_args()
    cfg = json.load(open(a.config, encoding="utf-8"))
    mid = int(cfg["map_id"])
    way = route(mid)
    sheet = way[0][0] if way else None
    pieces = cfg.get("pieces", {}).get(str(sheet), [])
    bounds = cfg.get("bounds", {}).get(str(sheet))
    if not (pieces or bounds):
        sys.exit("%s: neither pieces nor bounds for floor %s" % (cfg["slug"], sheet))
    W, H, px = art(mid, sheet)

    def dot(x, y, col, r):
        cx, cy = int(x * W), int(y * H)
        for yy in range(cy - r, cy + r + 1):
            for xx in range(cx - r, cx + r + 1):
                if 0 <= xx < W and 0 <= yy < H and (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r:
                    q = (yy * W + xx) * 3
                    px[q:q + 3] = bytes(col)

    def picture(gx, gy, floor=None):
        if bounds:
            x1, y1, x2, y2 = bounds
            return (y2 - gy) / (y2 - y1), (x2 - gx) / (x2 - x1)
        g = pieces[floor % 10 - 1]["game"]
        det = g[1] * g[5] - g[2] * g[4]
        dx, dy = gx - g[0], gy - g[3]
        return (g[5] * dx - g[2] * dy) / det, (g[1] * dy - g[4] * dx) / det

    jumps = links(mid)
    for (f0, x0, y0), (f1, x1, y1) in zip(way, way[1:]):
        if ((x0, y0), (x1, y1)) in jumps:
            continue
        n = int(max(abs(x1 - x0) * W, abs(y1 - y0) * H)) + 1
        for i in range(n + 1):
            dot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, (255, 255, 255), 1)
    if a.spawns:
        sys.path.insert(0, HERE)
        import importlib.util
        spec = importlib.util.spec_from_file_location("pace_build", os.path.join(os.path.dirname(HERE), "pace_build.py"))
        pb = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pb)
        plist = pb.pieces_of(cfg)
        for r in csv.DictReader(open(a.csv, encoding="utf-8")):
            if int(r["map_id"]) != mid:
                continue
            key = pb.piece_of(r, plist) if plist else None
            if plist and key is None:
                continue
            dot(*picture(float(r["x"]), float(r["y"]), key), (0, 0, 0), 3)
    data = open(os.path.join(ROOT, "Core/Pace/%s.lua" % cfg["lua_name"]), encoding="utf-8").read()
    for x, y, elites, rest in re.findall(r"\{ x = ([-\d.]+), y = ([-\d.]+), size = \d+, elites = (\d+)(.*?) \},\n", data):
        f = re.search(r"floor = (\d+)", rest)
        dot(*picture(float(x), float(y), int(f.group(1)) if f else None), (220, 0, 0), 5 + 2 * min(int(elites), 5))
    # The bosses' spawns: through `bounds`, or the first piece that holds them.
    for _, x, y in re.findall(r'\{ name = "([^"]+)", x = ([-\d.]+), y = ([-\d.]+) \}', data):
        at = picture(float(x), float(y)) if bounds else None
        for n, pc in enumerate(pieces, 1):
            cx, cy = picture(float(x), float(y), int(sheet) * 10 + n)
            if at is None and any(r[0] <= cx <= r[2] and r[1] <= cy <= r[3] for r in pc["rects"]):
                at = (cx, cy)
        if at:
            dot(at[0], at[1], (255, 220, 0), 8)
    png(a.out, W, H, px)
    print("%s: %dx%d -> %s" % (cfg["slug"], W, H, a.out))


if __name__ == "__main__":
    main()
