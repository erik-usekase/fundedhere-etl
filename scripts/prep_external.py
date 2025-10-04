#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys, csv, json

import re
def norm(s):
    s = (s or "").strip().lower()
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

CANON = [
  "beneficiary_bank_account_number",
  "buy_amount",
  "buy_currency",
  "created_date"
]
ALIASES = {
  "beneficiary_bank_account_number": [
    "beneficiary bank account number",
    "beneficiary bank account no",
    "beneficiary account number",
    "bank account number",
    "receiver bank account number",
    "receiver virtual account number",
    "receiver va number"
  ],
  "buy_amount": [
    "buy amount",
    "amount",
    "total amount",
    "pull amount"
  ],
  "buy_currency": [
    "buy currency",
    "currency",
    "buy ccy",
    "ccy"
  ],
  "created_date": [
    "created date",
    "transaction date",
    "completed date",
    "value date",
    "date"
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
    print(f"Wrote {out}")
if __name__ == "__main__":
    main()
