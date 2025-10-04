-- sql/phase2/010_mart_level1.sql
SET search_path = mart, public;

DROP VIEW IF EXISTS mart.v_level1;

CREATE VIEW mart.v_level1 AS
WITH pulled AS (
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
    SUM(
      CASE
        WHEN f.direction = 'inflow'
         AND f.category_code IN ('merchant_repayment','funds_to_sku')
        THEN f.signed_amount
        ELSE 0
      END
    ) AS amount_received
  FROM core.mv_va_txn_flows f
  GROUP BY 1
),
sales AS (
  SELECT
    s.sku_id,
    SUM(s.sales_proceeds) AS sales_proceeds
  FROM core.mv_repmt_sales s
  GROUP BY 1
),
m AS (
  SELECT sk.sku_id, sk.merchant_id, me.merchant_name
  FROM ref.sku sk
  JOIN ref.merchant me ON me.merchant_id = sk.merchant_id
)
SELECT
  p.sku_id                                AS "SKU ID",
  p.account_number                         AS "Account Number",
  m.merchant_name                          AS "Merchant",
  p.amount_pulled                          AS "Amount Pulled",
  r.amount_received                        AS "Amount Received",
  (COALESCE(p.amount_pulled,0)-COALESCE(r.amount_received,0))  AS "Variance Pulled vs Received",
  s.sales_proceeds                         AS "Sales Proceeds",
  (COALESCE(s.sales_proceeds,0)-COALESCE(r.amount_received,0)) AS "Variance Received vs Sales"
FROM pulled p
LEFT JOIN received r ON r.sku_id = p.sku_id
LEFT JOIN sales s    ON s.sku_id = p.sku_id
LEFT JOIN m          ON m.sku_id = p.sku_id
ORDER BY 1,2;
