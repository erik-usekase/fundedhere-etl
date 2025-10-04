#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys, csv

import re
def norm(s):
    s = (s or "").strip().lower()
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

def main():
    if len(sys.argv) < 2:
        print("Usage: preview_cols.py <file.csv>", file=sys.stderr)
        sys.exit(2)
    fn = sys.argv[1]
    with open(fn, 'r', newline='', encoding='utf-8-sig') as f:
        r = csv.reader(f); hdr = next(r, [])
    print("Columns (raw):", hdr)
    print("Columns (normalized):", [norm(h) for h in hdr])
if __name__ == "__main__":
    main()
