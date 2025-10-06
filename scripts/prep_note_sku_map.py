#!/usr/bin/env python3
"""Generate note_sku_va_map_prepped.csv from the Level-1 reference export."""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path
from typing import Iterable, List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        default="data/inc_data/Sample Files((1) Formula & Output).csv",
        help="Path to the Level-1 reference CSV.",
    )
    parser.add_argument(
        "--output",
        default="data/inc_data/note_sku_va_map_prepped.csv",
        help="Path to write the SKU<->VA mapping CSV.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress informational messages about fallback source detection.",
    )
    return parser.parse_args()


def read_rows(path: Path) -> List[List[str]]:
    try:
        with path.open(newline="", encoding="utf-8-sig") as handle:
            return [row for row in csv.reader(handle)]
    except FileNotFoundError as exc:
        raise SystemExit(f"Source file not found: {path}") from exc


def resolve_source(explicit: Path, out_dir: Path, quiet: bool) -> Path:
    if explicit.exists():
        return explicit

    # Candidate flat filenames users may prefer.
    flat_names = [
        "level1_formula_output.csv",
        "level1_formula.csv",
        "formula_output_level1.csv",
    ]
    for name in flat_names:
        candidate = out_dir / name
        if candidate.exists():
            if not quiet:
                print(f"Source {explicit} not found; using {candidate}")
            return candidate

    # Fall back to legacy Sample Files naming or other Formula & Output CSVs.
    formula_files = [
        p
        for p in out_dir.glob("*.csv")
        if "formula" in p.name.lower() and "output" in p.name.lower()
    ]
    if formula_files:
        # Prefer ones that look like Level 1 (contain '1' or 'level1').
        def score(path: Path) -> tuple[int, str]:
            name = path.name.lower()
            has_level1 = int("level1" in name or "(1" in name or "_1" in name)
            return (has_level1, name)

        chosen = sorted(formula_files, key=score, reverse=True)[0]
        if not quiet:
            print(f"Source {explicit} not found; using {chosen}")
        return chosen

    raise SystemExit(
        "Could not locate a Level-1 reference CSV. Provide --source or place the file in data/inc_data/."
    )


def find_header_index(rows: Iterable[List[str]]) -> int:
    for idx, row in enumerate(rows):
        if len(row) >= 2 and row[0].strip().lower() == "sku id" and row[1].strip().lower() in {"account number", "virtual account"}:
            return idx
    raise SystemExit("Could not locate 'SKU ID' header in reference export.")


def extract_pairs(rows: List[List[str]], start_idx: int) -> List[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for row in rows[start_idx + 1 :]:
        if len(row) < 2:
            break
        sku = row[0].strip()
        va = row[1].strip()
        if not sku or not va:
            break
        if sku.lower().startswith("total"):
            break
        pairs.append((sku, va))
    if not pairs:
        raise SystemExit("No SKU/VA pairs found beneath header row.")
    return pairs


def write_output(path: Path, pairs: List[tuple[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["note_id", "sku_id", "va_number"])
        # note_id left blank until provided in future exports.
        for sku, va in pairs:
            writer.writerow(["", sku, va])


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    source_path = resolve_source(Path(args.source), output_path.parent, args.quiet)

    rows = read_rows(source_path)
    header_idx = find_header_index(rows)
    pairs = extract_pairs(rows, header_idx)

    write_output(output_path, pairs)
    if not args.quiet:
        print(f"Wrote {len(pairs)} SKU<->VA mappings to {output_path}")


if __name__ == "__main__":
    try:
        main()
    except SystemExit as err:
        print(err, file=sys.stderr)
        raise
