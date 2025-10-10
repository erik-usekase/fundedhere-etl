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
  "acquirer_fees_expected",
  "acquirer_fees_paid",
  "fh_admin_fees_expected",
  "fh_admin_fees_paid",
  "int_difference_expected",
  "int_difference_paid",
  "sr_principal_expected",
  "sr_principal_paid",
  "sr_interest_expected",
  "sr_interest_paid",
  "jr_principal_expected",
  "jr_principal_paid",
  "jr_interest_expected",
  "jr_interest_paid",
  "spar_merchant",
  "additional_interests_paid_to_fh"
]
ALIASES = {
  "merchant": [
    "merchant",
    "merchant name",
    "spar merchant"
  ],
  "sku_id": [
    "sku id",
    "sku",
    "note id"
  ],
  "acquirer_fees_expected": [
    "acquirer fees expected",
    "acquirer fee expected"
  ],
  "acquirer_fees_paid": [
    "acquirer fees paid",
    "acquirer fee paid"
  ],
  "fh_admin_fees_expected": [
    "fh admin fees expected",
    "administrative fees expected",
    "admin fees expected"
  ],
  "fh_admin_fees_paid": [
    "fh admin fees paid",
    "administrative fees paid",
    "admin fees paid"
  ],
  "int_difference_expected": [
    "int difference expected",
    "interest difference expected"
  ],
  "int_difference_paid": [
    "int difference paid",
    "interest difference paid"
  ],
  "sr_principal_expected": [
    "sr principal expected",
    "senior principal expected",
    "sr principal expected"
  ],
  "sr_principal_paid": [
    "sr principal paid",
    "senior principal paid",
    "sr principal paid"
  ],
  "sr_interest_expected": [
    "sr interest expected",
    "senior interest expected",
    "sr interest expected"
  ],
  "sr_interest_paid": [
    "sr interest paid",
    "senior interest paid",
    "sr interest paid"
  ],
  "jr_principal_expected": [
    "jr principal expected",
    "junior principal expected",
    "jr principal expected"
  ],
  "jr_principal_paid": [
    "jr principal paid",
    "junior principal paid",
    "jr principal paid"
  ],
  "jr_interest_expected": [
    "jr interest expected",
    "junior interest expected",
    "jr interest expected"
  ],
  "jr_interest_paid": [
    "jr interest paid",
    "junior interest paid",
    "jr interest paid"
  ],
  "spar_merchant": [
    "spar merchant",
    "spar"
  ],
  "additional_interests_paid_to_fh": [
    "additional interests paid to fh",
    "fh platform fee",
    "platform fee"
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
