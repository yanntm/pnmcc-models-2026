#!/usr/bin/env python3
"""Merge the vector oracles of the total examinations, position by position.

The published vectors (`<model>-QLA.out`, `-SMA.out`, `-UBA.out`: a header
line, the keyword, then one T/F/? per object or one integer/inf/? token per
place, wrapped at 80 columns) start as all `?`; a campaign run yields the same
vectors with the values it settled. Merging: a `?` on either side takes the
other side's value, equal values stay, two different values are a finding to
report and never overwritten: the published one is kept and the disagreement
printed. The merged vectors are written in the same format.

    merge_total_oracles.py PUBLISHED_DIR RUN_DIR OUT_DIR [--report merge.csv]

A vector filled this way from a single tool's runs is a regression oracle,
not a truth: the self certifying side (QLIVE T, STABLE F, a bound's lower end
reached by a walk) is witnessed, the other side rests on that tool's proofs.
"""

import argparse
import csv
import os
import sys

SUFFIXES = ("QLA", "SMA", "UBA")


def read(path):
    """(header, keyword, tokens): characters for QLA/SMA, whitespace tokens for UBA."""
    with open(path) as f:
        lines = f.read().split("\n")
    header, keyword = lines[0], lines[1]
    body = "".join(lines[2:]) if keyword != "BOUND" else " ".join(lines[2:])
    tokens = list(body.replace(" ", "")) if keyword != "BOUND" else body.split()
    return header, keyword, tokens


def write(path, header, keyword, tokens):
    with open(path, "w") as f:
        f.write(header + "\n" + keyword + "\n")
        if keyword == "BOUND":
            line = ""
            for t in tokens:
                if len(line) + len(t) + 1 > 80:
                    f.write(line + "\n")
                    line = t
                else:
                    line = t if not line else line + " " + t
            f.write(line + "\n")
        else:
            s = "".join(tokens)
            for i in range(0, len(s), 80):
                f.write(s[i:i + 80] + "\n")


def merge(pub, run):
    """The merged tokens, the count filled, and the positions that disagree."""
    out, filled, conflicts = [], 0, []
    for i, (p, r) in enumerate(zip(pub, run)):
        if p == "?" and r != "?":
            out.append(r)
            filled += 1
        elif p != "?" and r != "?" and p != r:
            out.append(p)
            conflicts.append((i, p, r))
        else:
            out.append(p)
    return out, filled, conflicts


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("published")
    ap.add_argument("run")
    ap.add_argument("out")
    ap.add_argument("--report", help="one row per vector: atoms, known before, filled, known after, conflicts")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rows = []
    totals = {s: [0, 0, 0, 0, 0] for s in SUFFIXES}   # vectors, atoms, known before, filled, conflicts
    for name in sorted(os.listdir(args.published)):
        suffix = name[-7:-4]
        if not name.endswith(".out") or suffix not in SUFFIXES:
            continue
        header, keyword, pub = read(os.path.join(args.published, name))
        runpath = os.path.join(args.run, name)
        if os.path.exists(runpath):
            h2, k2, run = read(runpath)
            if len(run) != len(pub):
                print(f"{name}: length mismatch, published {len(pub)} against run {len(run)}: run ignored", file=sys.stderr)
                run = ["?"] * len(pub)
        else:
            run = ["?"] * len(pub)
        merged, filled, conflicts = merge(pub, run)
        for i, p, r in conflicts:
            print(f"CONFLICT {name} position {i}: published {p}, run {r}")
        write(os.path.join(args.out, name), header, keyword, merged)
        before = sum(1 for t in pub if t != "?")
        rows.append({"vector": name, "atoms": len(pub), "known before": before, "filled": filled,
                     "known after": before + filled, "conflicts": len(conflicts)})
        t = totals[suffix]
        t[0] += 1; t[1] += len(pub); t[2] += before; t[3] += filled; t[4] += len(conflicts)
    for s, (n, atoms, before, filled, conf) in totals.items():
        share = f"{(before + filled) / atoms:.3f}" if atoms else "n/a"
        print(f"{s}: {n} vectors, {atoms} atoms, known {before} -> {before + filled} ({share}), conflicts {conf}", file=sys.stderr)
    if args.report:
        with open(args.report, "w", newline="") as f:
            w = csv.DictWriter(f, ["vector", "atoms", "known before", "filled", "known after", "conflicts"])
            w.writeheader()
            w.writerows(rows)


if __name__ == "__main__":
    main()
