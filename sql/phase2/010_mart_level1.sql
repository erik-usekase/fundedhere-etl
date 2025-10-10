-- sql/phase2/010_mart_level1.sql
SET search_path = mart, public;

DROP VIEW IF EXISTS mart.v_level1;

CREATE VIEW mart.v_level1 AS
WITH universe AS (
  SELECT DISTINCT
    n.sku_id,
    n.va_number      AS account_number,
    m.merchant_name
  FROM ref.note_sku_va_map n
  JOIN ref.merchant m ON m.merchant_id = n.merchant_id
),
pulled AS (
  SELECT
    n.sku_id,
    n.va_number AS account_number,
    SUM(e.buy_amount) AS amount_pulled
  FROM core.mv_external_accounts e
  JOIN ref.note_sku_va_map n ON n.va_number = e.va_number
  GROUP BY 1,2
),
received AS (
  SELECT
    f.sku_id,
    f.va_number AS account_number,
    SUM(CASE WHEN f.direction = 'inflow'
               AND f.category_code = 'merchant_repayment'
             THEN f.signed_amount ELSE 0 END) AS amount_received
  FROM core.mv_va_txn_flows f
  GROUP BY 1,2
),
sales AS (
  SELECT
    s.sku_id,
    SUM(s.sales_proceeds) AS sales_proceeds
  FROM core.mv_repmt_sales s
  GROUP BY 1
)
SELECT
  u.sku_id                                 AS "SKU ID",
  u.account_number                         AS "Account Number",
  u.merchant_name                          AS "Merchant",
  COALESCE(p.amount_pulled, 0)             AS "Amount Pulled",
  COALESCE(r.amount_received, 0)           AS "Amount Received",
  (COALESCE(p.amount_pulled,0)-COALESCE(r.amount_received,0))  AS "Variance",
  COALESCE(s.sales_proceeds, 0)            AS "Sales Proceeds",
  (COALESCE(s.sales_proceeds,0)-COALESCE(r.amount_received,0)) AS "Variance"
FROM universe u
LEFT JOIN pulled p   ON p.sku_id = u.sku_id AND p.account_number = u.account_number
LEFT JOIN received r ON r.sku_id = u.sku_id AND r.account_number = u.account_number
LEFT JOIN sales s    ON s.sku_id = u.sku_id
ORDER BY 1,2;
