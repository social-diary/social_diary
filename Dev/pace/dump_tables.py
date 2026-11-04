"""Stream a mysqldump file and write selected tables to CSV (no MySQL server needed).

usage: python3 -I dump_tables.py <dump.sql> <out_dir> table1 [table2 ...]
"""
import csv
import os
import re
import sys


def parse_values(s, i):
    """Parse ('a',1,NULL),(...) starting at index i; yield row lists."""
    n = len(s)
    while i < n:
        while i < n and s[i] in " ,\n":
            i += 1
        if i >= n or s[i] == ";":
            return
        assert s[i] == "(", s[i : i + 50]
        i += 1
        row = []
        while True:
            c = s[i]
            if c == "'":
                i += 1
                buf = []
                while True:
                    c = s[i]
                    if c == "\\":
                        nxt = s[i + 1]
                        buf.append({"n": "\n", "t": "\t", "r": "\r", "0": "\0"}.get(nxt, nxt))
                        i += 2
                    elif c == "'":
                        i += 1
                        break
                    else:
                        buf.append(c)
                        i += 1
                row.append("".join(buf))
            else:
                j = i
                while s[j] not in ",)":
                    j += 1
                tok = s[i:j]
                row.append(None if tok == "NULL" else tok)
                i = j
            if s[i] == ",":
                i += 1
                continue
            if s[i] == ")":
                i += 1
                yield row
                break


def main():
    dump, out_dir, tables = sys.argv[1], sys.argv[2], set(sys.argv[3:])
    os.makedirs(out_dir, exist_ok=True)
    cols, cur_create = {}, None
    writers, files = {}, {}
    create_re = re.compile(r"^CREATE TABLE `([^`]+)` \(")
    col_re = re.compile(r"^  `([^`]+)`")
    with open(dump, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = create_re.match(line)
            if m:
                cur_create = m.group(1) if m.group(1) in tables else None
                if cur_create:
                    cols[cur_create] = []
                continue
            if cur_create:
                m = col_re.match(line)
                if m:
                    cols[cur_create].append(m.group(1))
                elif line.startswith(")"):
                    cur_create = None
                continue
            if line.startswith("INSERT INTO `"):
                t = line[13 : line.index("`", 13)]
                if t not in tables:
                    continue
                if t not in writers:
                    files[t] = open(os.path.join(out_dir, t + ".csv"), "w", newline="", encoding="utf-8")
                    writers[t] = csv.writer(files[t])
                    writers[t].writerow(cols[t])
                start = line.index("VALUES ") + 7
                for row in parse_values(line, start):
                    writers[t].writerow(row)
    for t, fh in files.items():
        fh.close()
        print(t, "written")


if __name__ == "__main__":
    main()
