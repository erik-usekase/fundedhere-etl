#!/usr/bin/env python3
"""Test that all variance columns across all views are within acceptable thresholds."""
import csv
import io
import os
import subprocess
from decimal import Decimal
from pathlib import Path


BASH_PATH = os.getenv('BASH_PATH', 'bash')
PROJECT_ROOT = Path(__file__).resolve().parents[1]
VARIANCE_THRESHOLD = Decimal('0.02')


def parse_decimal(value: str) -> Decimal:
    value = (value or '').strip().replace(',', '')
    if not value or value == '-' or value == '':
        return Decimal('0')
    return Decimal(value)


def run_query(sql: str) -> list[dict[str, str]]:
    """Execute SQL query and return results."""
    cmd = [BASH_PATH, 'scripts/run_sql.sh', '-c', sql]
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
        raise RuntimeError(f"SQL query failed: {message}") from exc

    reader = csv.DictReader(io.StringIO(res.stdout))
    return list(reader)


def test_sheet1_variance():
    """Test Sheet1 (Level 1) Variance column."""
    sql = """
COPY (
  SELECT
    "SKU ID",
    "Merchant",
    "Variance"
  FROM mart.v_level1
  WHERE ABS("Variance") > 0.02
  ORDER BY ABS("Variance") DESC
) TO STDOUT WITH CSV HEADER
"""
    rows = run_query(sql)

    if rows:
        print(f"\n❌ Sheet1: Found {len(rows)} SKUs with variance > {VARIANCE_THRESHOLD}:")
        for row in rows[:10]:  # Show first 10
            variance = parse_decimal(row['Variance'])
            print(f"  {row['SKU ID']:20s} {row['Merchant']:30s} Variance: {variance:10.2f}")
        if len(rows) > 10:
            print(f"  ... and {len(rows) - 10} more")
        raise AssertionError(f"Sheet1 variance threshold exceeded for {len(rows)} SKUs")

    print(f"✓ Sheet1: All variances within {VARIANCE_THRESHOLD} threshold")


def test_sheet2a_variances():
    """Test Sheet2a (Level 2a) all variance columns."""
    variance_cols = [
        'Management Fee Outstanding',
        'Administrative Fee Outstanding',
        'Additional Administrative Fee Outstanding',
        'Interest Difference Outstanding',
        'Senior Principal Outstanding',
        'Senior Interest Outstanding',
        'Senior Additional Interest Outstanding',
        'Junior Principal Outstanding',
        'Junior Interest Outstanding',
        'Junior Additional Interest Outstanding',
        'SPAR Outstanding'
    ]

    sql = f"""
COPY (
  SELECT
    "SKU ID",
    "Merchant",
    "{variance_cols[0]}",
    "{variance_cols[1]}",
    "{variance_cols[2]}",
    "{variance_cols[3]}",
    "{variance_cols[4]}",
    "{variance_cols[5]}",
    "{variance_cols[6]}",
    "{variance_cols[7]}",
    "{variance_cols[8]}",
    "{variance_cols[9]}",
    "{variance_cols[10]}"
  FROM mart.v_level2a
  WHERE
    ABS("{variance_cols[0]}") > 0.02 OR
    ABS("{variance_cols[1]}") > 0.02 OR
    ABS("{variance_cols[2]}") > 0.02 OR
    ABS("{variance_cols[3]}") > 0.02 OR
    ABS("{variance_cols[4]}") > 0.02 OR
    ABS("{variance_cols[5]}") > 0.02 OR
    ABS("{variance_cols[6]}") > 0.02 OR
    ABS("{variance_cols[7]}") > 0.02 OR
    ABS("{variance_cols[8]}") > 0.02 OR
    ABS("{variance_cols[9]}") > 0.02 OR
    ABS("{variance_cols[10]}") > 0.02
  ORDER BY "SKU ID"
) TO STDOUT WITH CSV HEADER
"""
    rows = run_query(sql)

    if rows:
        print(f"\n❌ Sheet2a: Found {len(rows)} SKUs with outstanding variance > {VARIANCE_THRESHOLD}:")
        for row in rows[:10]:
            print(f"  {row['SKU ID']:20s} {row['Merchant']:30s}")
            for col in variance_cols:
                val = parse_decimal(row[col])
                if abs(val) > VARIANCE_THRESHOLD:
                    print(f"    {col}: {val:10.2f}")
        if len(rows) > 10:
            print(f"  ... and {len(rows) - 10} more")
        raise AssertionError(f"Sheet2a variance threshold exceeded for {len(rows)} SKUs")

    print(f"✓ Sheet2a: All outstanding variances within {VARIANCE_THRESHOLD} threshold")


def test_sheet2b_variances():
    """Test Sheet2b (Level 2b) UI vs CF variance columns."""
    variance_cols = [
        'Total Fund Inflow Variance',
        'Management Fee Paid Variance',
        'Administrative Fee Paid Variance',
        'Interest Difference Paid Variance',
        'Senior Principal Paid Variance',
        'Senior Interest Paid Variance',
        'Junior Principal Paid Variance',
        'Junior Interest Paid Variance',
        'SPAR Variance',
        'FH Platform Fee Variance'
    ]

    sql = f"""
COPY (
  SELECT
    "SKU ID",
    "Merchant",
    "{variance_cols[0]}",
    "{variance_cols[1]}",
    "{variance_cols[2]}",
    "{variance_cols[3]}",
    "{variance_cols[4]}",
    "{variance_cols[5]}",
    "{variance_cols[6]}",
    "{variance_cols[7]}",
    "{variance_cols[8]}",
    "{variance_cols[9]}"
  FROM mart.v_level2b
  WHERE
    ABS("{variance_cols[0]}") > 0.02 OR
    ABS("{variance_cols[1]}") > 0.02 OR
    ABS("{variance_cols[2]}") > 0.02 OR
    ABS("{variance_cols[3]}") > 0.02 OR
    ABS("{variance_cols[4]}") > 0.02 OR
    ABS("{variance_cols[5]}") > 0.02 OR
    ABS("{variance_cols[6]}") > 0.02 OR
    ABS("{variance_cols[7]}") > 0.02 OR
    ABS("{variance_cols[8]}") > 0.02 OR
    ABS("{variance_cols[9]}") > 0.02
  ORDER BY "SKU ID"
) TO STDOUT WITH CSV HEADER
"""
    rows = run_query(sql)

    if rows:
        print(f"\n❌ Sheet2b: Found {len(rows)} SKUs with UI vs CF variance > {VARIANCE_THRESHOLD}:")
        for row in rows[:10]:
            print(f"  {row['SKU ID']:20s} {row['Merchant']:30s}")
            for col in variance_cols:
                val = parse_decimal(row[col])
                if abs(val) > VARIANCE_THRESHOLD:
                    print(f"    {col}: {val:10.2f}")
        if len(rows) > 10:
            print(f"  ... and {len(rows) - 10} more")
        raise AssertionError(f"Sheet2b variance threshold exceeded for {len(rows)} SKUs")

    print(f"✓ Sheet2b: All UI vs CF variances within {VARIANCE_THRESHOLD} threshold")


if __name__ == '__main__':
    print(f"Testing variance thresholds (max allowed: ±{VARIANCE_THRESHOLD})...")
    print("=" * 80)

    try:
        test_sheet1_variance()
        test_sheet2a_variances()
        test_sheet2b_variances()
        print("\n" + "=" * 80)
        print("✓ All variance tests passed!")
    except AssertionError as e:
        print("\n" + "=" * 80)
        print(f"✗ Variance test failed: {e}")
        exit(1)
