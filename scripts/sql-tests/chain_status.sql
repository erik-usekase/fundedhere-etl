WITH
vs AS (SELECT COUNT(*) c FROM ref.note_sku_va_map),
ext AS (SELECT COUNT(*) c FROM core.mv_external_accounts),
sales AS (SELECT COUNT(*) c FROM core.mv_repmt_sales),
inflow AS (SELECT COUNT(*) c FROM core.mv_va_txn WHERE category_code='merchant_repayment')
SELECT 
 (SELECT c FROM vs)     AS map_rows,
 (SELECT c FROM ext)    AS external_rows,
 (SELECT c FROM sales)  AS sales_rows,
 (SELECT c FROM inflow) AS inflow_rows,
 (SELECT COUNT(*) FROM mart.v_level1) AS level1_rows;
