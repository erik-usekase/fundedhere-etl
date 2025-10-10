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
  "sender_virtual_account_id",
  "sender_virtual_account_number",
  "sender_note_id",
  "receiver_virtual_account_id",
  "receiver_virtual_account_number",
  "receiver_note_id",
  "receiver_va_opening_balance",
  "receiver_va_closing_balance",
  "amount",
  "date",
  "remarks"
]
ALIASES = {
  "sender_virtual_account_id": [
    "sender virtual account id",
    "sender va id"
  ],
  "sender_virtual_account_number": [
    "sender virtual account number",
    "sender va number",
    "sender bank account number",
    "sender account number"
  ],
  "sender_note_id": [
    "sender note id",
    "sender ref id",
    "sender reference id",
    "sender note"
  ],
  "receiver_virtual_account_id": [
    "receiver virtual account id",
    "receiver va id"
  ],
  "receiver_virtual_account_number": [
    "receiver virtual account number",
    "receiver va number",
    "beneficiary bank account number",
    "receiver bank account number",
    "receiver account number"
  ],
  "receiver_note_id": [
    "receiver note id",
    "receiver ref id",
    "receiver reference id",
    "receiver note"
  ],
  "receiver_va_opening_balance": [
    "receiver va opening balance",
    "opening balance receiver",
    "receiver opening balance"
  ],
  "receiver_va_closing_balance": [
    "receiver va closing balance",
    "closing balance receiver",
    "receiver closing balance"
  ],
  "amount": [
    "amount",
    "transaction amount",
    "amt"
  ],
  "date": [
    "date",
    "transaction date",
    "created date",
    "completed date",
    "value date"
  ],
  "remarks": [
    "remarks",
    "comment",
    "memo",
    "description"
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
