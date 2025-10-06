#!/usr/bin/env python3
import csv
import io
import os
import subprocess
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

REFERENCE_ENV = os.getenv('LEVEL1_REFERENCE_CSV')
REFERENCE_CANDIDATES = [
    Path(REFERENCE_ENV) if REFERENCE_ENV else None,
    Path('data/inc_data/level1_reference.csv'),
    Path('data/inc_data/level1_formula_output.csv'),
    Path('data/inc_data/Sample Files((1) Formula & Output).csv'),
]

FIXTURE_CSV = Path('tests/fixtures/level1_expected.csv')


def resolve_reference_csv() -> Path:
    for candidate in REFERENCE_CANDIDATES:
        if candidate and candidate.exists():
            return candidate
    searched = [str(c) for c in REFERENCE_CANDIDATES if c]
    raise FileNotFoundError(
        'Level 1 reference CSV not found. Checked: ' + ', '.join(searched)
    )


def parse_decimal(value: str) -> Decimal:
    value = (value or '').strip().replace(',', '')
    if not value or value == '-':
        return Decimal('0')
    return Decimal(value)


def to_two_dec(value: Decimal) -> str:
    return str(value.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))


def build_expected_fixture(source_csv: Path) -> None:
    rows = []
    with source_csv.open(newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        data = list(reader)
    header_idx = next(i for i, row in enumerate(data) if 'SKU ID' in row and 'Account Number' in row)
    header = data[header_idx]
    col = {name: idx for idx, name in enumerate(header)}
    for row in data[header_idx + 1:]:
        sku = row[col['SKU ID']].strip()
        if not sku:
            continue
        account = row[col['Account Number']].strip()
        merchant = row[col['Merchant']].strip()
        amount_pulled = parse_decimal(row[col['Amount Pulled']])
        amount_received = parse_decimal(row[col['Amount Received']])
        sales_proceeds = parse_decimal(row[col['Sales Proceeds']])
        rows.append({
            'SKU ID': sku,
            'Account Number': account,
            'Merchant': merchant,
            'Amount Pulled': to_two_dec(amount_pulled),
            'Amount Received': to_two_dec(amount_received),
            'Sales Proceeds': to_two_dec(sales_proceeds),
        })
    rows.sort(key=lambda r: (r['SKU ID'], r['Account Number']))
    FIXTURE_CSV.parent.mkdir(parents=True, exist_ok=True)
    with FIXTURE_CSV.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['SKU ID', 'Account Number', 'Merchant', 'Amount Pulled', 'Amount Received', 'Sales Proceeds'])
        writer.writeheader()
        writer.writerows(rows)


def fetch_actual() -> list[dict[str, str]]:
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
    res = subprocess.run(['scripts/run_sql.sh', '-c', query], capture_output=True, text=True, check=True)
    reader = csv.DictReader(io.StringIO(res.stdout))
    return list(reader)


def compare(expected: list[dict[str, str]], actual: list[dict[str, str]]) -> None:
    exp_map = {(row['SKU ID'], row['Account Number']): row for row in expected}
    act_map = {(row['SKU ID'], row['Account Number']): row for row in actual}

    missing = sorted(set(exp_map) - set(act_map))
    extra = sorted(set(act_map) - set(exp_map))
    if missing or extra:
        raise SystemExit(f"Parity failure: missing={missing[:5]} extra={extra[:5]}")

    tolerance = Decimal('0.01')
    for key in exp_map:
        exp_row = exp_map[key]
        act_row = act_map[key]
        for field in ['Amount Pulled', 'Amount Received', 'Sales Proceeds']:
            exp_val = parse_decimal(exp_row[field])
            act_val = parse_decimal(act_row[field])
            if (act_val - exp_val).copy_abs() > tolerance:
                raise SystemExit(
                    f"Value mismatch for {key} field {field}: expected {exp_val}, actual {act_val}"
                )
        if exp_row['Merchant'] != act_row['Merchant']:
            raise SystemExit(f"Merchant mismatch for {key}: expected {exp_row['Merchant']}, actual {act_row['Merchant']}")


SOURCE_CSV = resolve_reference_csv()

if __name__ == '__main__':
    build_expected_fixture(SOURCE_CSV)
    expected_rows = list(csv.DictReader(FIXTURE_CSV.open()))
    actual_rows = fetch_actual()
    compare(expected_rows, actual_rows)
    print('Level 1 parity check passed.')
