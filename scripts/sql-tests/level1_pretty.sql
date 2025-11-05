-- scripts/sql-tests/level1_pretty.sql
-- Test query for mart.v_level1 (Sheet 1 output)
SELECT
  "SKU ID",
  "Merchant",
  "Amount Received",
  "Amount Distributed Down the Repayment Waterfall",
  "Fund Transferred to Other SKU",
  "Variance"
FROM mart.v_level1
ORDER BY "SKU ID"
LIMIT 10;
