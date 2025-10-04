-- scripts/sql-tests/level1_pretty.sql
SELECT
  "SKU ID",
  "Account Number",
  "Merchant",
  "Amount Pulled",
  "Amount Received",
  (COALESCE("Amount Pulled",0)-COALESCE("Amount Received",0))   AS "Variance Pulled vs Received",
  "Sales Proceeds",
  (COALESCE("Sales Proceeds",0)-COALESCE("Amount Received",0))  AS "Variance Received vs Sales"
FROM mart.v_level1
ORDER BY 1,2;
