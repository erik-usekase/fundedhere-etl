#!/usr/bin/env bash
set -euo pipefail

# Verification script to confirm data load and schema match target
# Expected targets from full_wb.xlsx Excel workbook

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FundedHere ETL - Target Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -z "${SKIP_ENV_FILE:-}" ] && [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  . "$PROJECT_ROOT/.env"
  set +a
fi

PSQL="docker exec app-postgres psql -U appuser -d appdb -t -A"

echo ""
echo "1. ROW COUNTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

$PSQL -c "
SELECT
  table_name,
  row_count,
  expected,
  CASE
    WHEN row_count = expected THEN '✓'
    ELSE '✗ MISMATCH'
  END as status
FROM (
  VALUES
    ('raw.external_accounts', (SELECT COUNT(*) FROM raw.external_accounts), 2718),
    ('raw.va_txn', (SELECT COUNT(*) FROM raw.va_txn), 28599),
    ('raw.repmt_sku', (SELECT COUNT(*) FROM raw.repmt_sku), 366),
    ('raw.repmt_sales', (SELECT COUNT(*) FROM raw.repmt_sales), 366),
    ('mart.v_level1', (SELECT COUNT(*) FROM mart.v_level1), 366),
    ('mart.v_level2a', (SELECT COUNT(*) FROM mart.v_level2a), 366),
    ('mart.v_level2b', (SELECT COUNT(*) FROM mart.v_level2b), 366)
) AS t(table_name, row_count, expected);
" | column -t -s '|'

echo ""
echo "2. SCHEMA STRUCTURE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sheet1_cols=$($PSQL -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='mart' AND table_name='v_level1';")
sheet2a_cols=$($PSQL -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='mart' AND table_name='v_level2a';")
sheet2b_cols=$($PSQL -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='mart' AND table_name='v_level2b';")

printf "%-20s %10s %10s %8s\n" "View" "Columns" "Expected" "Status"
printf "%-20s %10s %10s %8s\n" "--------------------" "----------" "----------" "--------"
printf "%-20s %10d %10d %8s\n" "mart.v_level1" "$sheet1_cols" "8" "$([ $sheet1_cols -eq 8 ] && echo '✓' || echo '✗')"
printf "%-20s %10d %10d %8s\n" "mart.v_level2a" "$sheet2a_cols" "16" "$([ $sheet2a_cols -eq 16 ] && echo '✓' || echo '✗')"
printf "%-20s %10d %10d %8s\n" "mart.v_level2b" "$sheet2b_cols" "12" "$([ $sheet2b_cols -eq 12 ] && echo '✓' || echo '✗')"

echo ""
echo "3. TEST SKU VERIFICATION (4 HOLE EGG PAN-1288-636-92rxuDoq6U)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Sheet 1 (Cash Flow Reconciliation):"
$PSQL -c "
SELECT
  'Amount Pulled' as metric, \"Amount Pulled\"::text as value, '1012.48' as expected,
  CASE WHEN \"Amount Pulled\" = 1012.48 THEN '✓' ELSE '✗' END as status
FROM mart.v_level1 WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Amount Received', \"Amount Received\"::text, '1012.48',
  CASE WHEN \"Amount Received\" = 1012.48 THEN '✓' ELSE '✗' END
FROM mart.v_level1 WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Variance', \"Variance\"::text, '0.00',
  CASE WHEN \"Variance\" = 0 THEN '✓' ELSE '✗' END
FROM mart.v_level1 WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';
" | column -t -s '|'

echo ""
echo "Sheet 2a (Investor Reconciliation):"
$PSQL -c "
SELECT
  'Amount Received' as metric, \"Amount Received\"::text as value, '15284.44' as expected,
  CASE WHEN \"Amount Received\" = 15284.44 THEN '✓' ELSE '✗' END as status
FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Waterfall', \" Amount Distributed Down the Repayment Waterfall\"::text, '1186.43',
  CASE WHEN \" Amount Distributed Down the Repayment Waterfall\" = 1186.43 THEN '✓' ELSE '✗' END
FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Transfers', \"Fund Transferred to Other SKU\"::text, '14098.01',
  CASE WHEN \"Fund Transferred to Other SKU\" = 14098.01 THEN '✓' ELSE '✗' END
FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Variance', \"Variance\"::text, '0.00',
  CASE WHEN \"Variance\" < 0.01 THEN '✓' ELSE '✗' END
FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Management Fee', \"Management Fee\"::text, '27.76',
  CASE WHEN \"Management Fee\" = 27.76 THEN '✓' ELSE '✗' END
FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Senior Principal', \"Senior Principal\"::text, '1000.00',
  CASE WHEN \"Senior Principal\" = 1000.00 THEN '✓' ELSE '✗' END
FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';
" | column -t -s '|'

echo ""
echo "Sheet 2b (Payment Details):"
$PSQL -c "
SELECT
  'Total Fund Inflow' as metric, \"Total Fund Inflow\"::text as value, '15284.44' as expected,
  CASE WHEN \"Total Fund Inflow\" = 15284.44 THEN '✓' ELSE '✗' END as status
FROM mart.v_level2b WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Management Fee', \"Management Fee Paid\"::text, '27.76',
  CASE WHEN \"Management Fee Paid\" = 27.76 THEN '✓' ELSE '✗' END
FROM mart.v_level2b WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
UNION ALL
SELECT
  'Senior Principal', \"Senior Principal Paid\"::text, '1000.00',
  CASE WHEN \"Senior Principal Paid\" = 1000.00 THEN '✓' ELSE '✗' END
FROM mart.v_level2b WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';
" | column -t -s '|'

echo ""
echo "4. VARIANCE CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

variance_count=$($PSQL -c "SELECT COUNT(*) FROM mart.v_level1 WHERE \"Variance\" = 0;")
total_skus=$($PSQL -c "SELECT COUNT(*) FROM mart.v_level1;")

echo "SKUs with Variance = 0: $variance_count / $total_skus"

if [ "$variance_count" -ge 363 ]; then
  echo "Status: ✓ PASS (${variance_count} SKUs balanced, ${total_skus} total)"
else
  echo "Status: ✗ FAIL (Expected ≥363 SKUs with zero variance)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verification Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
