-- scripts/sql-tests/level1_pretty.sql
SELECT
  sku_id AS "SKU ID",
  account_number AS "Account Number",
  merchant AS "Merchant",
  amount_pulled AS "Amount Pulled",
  amount_received AS "Amount Received",
  (COALESCE(amount_pulled,0)-COALESCE(amount_received,0))   AS "Variance Pulled vs Received",
  sales_proceeds AS "Sales Proceeds",
  (COALESCE(sales_proceeds,0)-COALESCE(amount_received,0))  AS "Variance Received vs Sales"
FROM mart.v_level1
ORDER BY 1,2;
