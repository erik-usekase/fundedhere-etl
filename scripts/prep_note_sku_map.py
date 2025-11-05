#!/usr/bin/env python3
"""Generate note_sku_va_map_prepped.csv from the repmt_sku data."""
from __future__ import annotations

import argparse
import csv
import io
import os
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default="data/inc_data/note_sku_va_map_prepped.csv",
        help="Path to write the SKU<->VA mapping CSV.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress informational messages.",
    )
    return parser.parse_args()


def fetch_sku_va_pairs() -> list[tuple[str, str]]:
    """Query database for unique SKU ID + VA number pairs from raw data."""
    query = """
COPY (
  SELECT DISTINCT
    s.sku_id,
    v.receiver_virtual_account_number AS va_number
  FROM raw.repmt_sku s
  CROSS JOIN raw.va_txn v
  WHERE v.sender_note_id = s.sku_id
    AND v.receiver_virtual_account_number IS NOT NULL
    AND v.receiver_virtual_account_number <> ''
  ORDER BY s.sku_id, va_number
) TO STDOUT WITH CSV
"""
    bash_path = os.getenv('BASH_PATH', 'bash')
    project_root = Path(__file__).resolve().parents[1]
    cmd = [bash_path, 'scripts/run_sql.sh', '-c', query]
    env = os.environ.copy()
    # Don't override PGHOST/PGPORT if already set (respects .env file)
    # run_sql.sh will auto-detect the correct connection settings
    env['PGSSLMODE'] = 'disable'

    try:
        res = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            cwd=project_root,
            env=env,
        )
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip()
        raise SystemExit(f"SKU-VA mapping query failed: {message}") from exc

    reader = csv.reader(io.StringIO(res.stdout))
    pairs = [(sku, va) for sku, va in reader if sku and va]

    if not pairs:
        raise SystemExit("No SKU/VA pairs found in database.")

    return pairs


def write_output(path: Path, pairs: list[tuple[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["note_id", "sku_id", "va_number"])
        # note_id left blank until provided in future exports.
        for sku, va in pairs:
            writer.writerow(["", sku, va])


def main() -> None:
    args = parse_args()
    env_quiet = os.getenv("QUIET", "1") != "0"
    quiet = args.quiet or env_quiet
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    pairs = fetch_sku_va_pairs()
    write_output(output_path, pairs)

    if not quiet:
        print(f"Wrote {len(pairs)} SKU<->VA mappings to {output_path}")


if __name__ == "__main__":
    try:
        main()
    except SystemExit as err:
        print(err, file=sys.stderr)
        raise
