#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys, csv, json, os

import re
def norm(s):
    s = (s or "").strip().lower()
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

CANON = [
  "merchant",
  "sku_id",
  "total_funds_inflow",
  "sales_proceeds",
  "l2e"
]
ALIASES = {
  "merchant": [
    "merchant",
    "merchant name"
  ],
  "sku_id": [
    "sku id",
    "sku",
    "note id"
  ],
  "total_funds_inflow": [
    "total funds inflow",
    "total inflow",
    "fund inflow",
    "funds inflow"
  ],
  "sales_proceeds": [
    "sales proceeds",
    "sales proceed",
    "proceeds"
  ],
  "l2e": [
    "l2 e",
    "l2e",
    "l2+e",
    "l2_e"
  ]
}
def main():
    if len(sys.argv) < 3:
        print("Usage: prep_<name>.py <src.csv> <out.csv>", file=sys.stderr)
        sys.exit(2)
    src, out = sys.argv[1], sys.argv[2]
    with open(src, 'r', newline='', encoding='utf-8-sig') as f:
        r = csv.DictReader(f)
        hdr = {norm(h):h for h in (r.fieldnames or [])}
        colmap = {}; missing = []
        for c in CANON:
            found = None
            for a in ALIASES.get(c, []):
                if norm(a) in hdr: found = hdr[norm(a)]; break
            if not found and norm(c) in hdr: found = hdr[norm(c)]
            if not found: missing.append(c)
            colmap[c] = found
        if missing:
            print("ERROR: missing required columns:", missing, file=sys.stderr)
            print("Found headers:", r.fieldnames, file=sys.stderr)
            print("Found normalized:", [norm(h) for h in (r.fieldnames or [])], file=sys.stderr)
            sys.exit(3)
        with open(out, 'w', newline='', encoding='utf-8') as g:
            w = csv.writer(g); w.writerow(CANON)
            for row in r: w.writerow([row.get(colmap[c], "") for c in CANON])
    if os.getenv("QUIET", "1") == "0":
        print(f"Wrote {out}")
if __name__ == "__main__":
    main()
