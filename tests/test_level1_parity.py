#!/usr/bin/env python3
"""Test that mart.v_level1 view executes successfully and returns expected data structure."""
import csv
import io
import os
import subprocess
from decimal import Decimal
from pathlib import Path


BASH_PATH = os.getenv('BASH_PATH', 'bash')
PROJECT_ROOT = Path(__file__).resolve().parents[1]


def parse_decimal(value: str) -> Decimal:
    value = (value or '').strip().replace(',', '')
    if not value or value == '-' or value == '':
        return Decimal('0')
    return Decimal(value)


def fetch_level1_data() -> list[dict[str, str]]:
    query = """
COPY (
  SELECT
    sku_id AS "SKU ID",
    account_number AS "Account Number",
    merchant AS "Merchant",
    to_char(amount_pulled, 'FM999999999.00')   AS "Amount Pulled",
    to_char(amount_received, 'FM999999999.00') AS "Amount Received",
    to_char(sales_proceeds, 'FM999999999.00')  AS "Sales Proceeds"
  FROM mart.v_level1
  ORDER BY 1, 2
) TO STDOUT WITH CSV HEADER
"""
    cmd = [BASH_PATH, 'scripts/run_sql.sh', '-c', query]
    env = os.environ.copy()
    env['PGHOST'] = 'postgres'
    env['PGPORT'] = '5432'
    env['PGDATABASE'] = env.get('PGDATABASE', 'appdb')
    env['PGUSER'] = env.get('PGUSER', 'appuser')
    env['PGPASSWORD'] = env.get('PGPASSWORD', 'changeme')
    env['PGSSLMODE'] = 'disable'
    env['SKIP_ENV_FILE'] = '1'
    try:
        res = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            cwd=PROJECT_ROOT,
            env=env,
        )
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip()
        raise RuntimeError(f"Level 1 SQL query failed: {message}") from exc
    reader = csv.DictReader(io.StringIO(res.stdout))
    return list(reader)


def validate_data(rows: list[dict[str, str]]) -> None:
    if not rows:
        raise SystemExit("Level 1 view returned no rows.")

    # Check required columns exist
    required_cols = ['SKU ID', 'Account Number', 'Merchant', 'Amount Pulled', 'Amount Received', 'Sales Proceeds']
    first_row = rows[0]
    for col in required_cols:
        if col not in first_row:
            raise SystemExit(f"Missing required column: {col}")

    # Validate data types and basic sanity
    for idx, row in enumerate(rows[:10]):  # Check first 10 rows
        sku = row['SKU ID'].strip()
        if not sku:
            raise SystemExit(f"Row {idx} has empty SKU ID")

        account = row['Account Number'].strip()
        if not account:
            raise SystemExit(f"Row {idx} ({sku}) has empty Account Number")

        # Ensure numeric fields are parseable
        for field in ['Amount Pulled', 'Amount Received', 'Sales Proceeds']:
            try:
                parse_decimal(row[field])
            except Exception as e:
                raise SystemExit(f"Row {idx} ({sku}) has invalid {field}: {row[field]} - {e}")

    print(f"Level 1 view validation passed: {len(rows)} rows with correct structure.")


if __name__ == '__main__':
    rows = fetch_level1_data()
    validate_data(rows)
    print('Level 1 sanity check passed.')
