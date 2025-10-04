-- sql/phase2/010_mart_views.sql
SET search_path = mart, public;

CREATE OR REPLACE VIEW mart.v_level1 AS
WITH ext AS (
  SELECT
    m.va_number,
    SUM(m.buy_amount) AS amount_pulled
  FROM core.mv_external_accounts m
  GROUP BY 1
),
inflow AS (
  SELECT
    v.va_number,
    v.sku_id,
    v.merchant_id,
    SUM(CASE WHEN v.category_code = 'merchant_repayment' THEN v.amount ELSE 0 END) AS amount_received
  FROM core.mv_va_txn v
  GROUP BY 1,2,3
),
sales AS (
  SELECT
    s.sku_id,
    MAX(s.sales_proceeds) AS sales_proceeds
  FROM core.mv_repmt_sales s
  GROUP BY 1
),
va_to_sku AS (
  SELECT DISTINCT n.va_number, n.sku_id, n.merchant_id
  FROM ref.note_sku_va_map n
)
SELECT
  COALESCE(i.sku_id, vs.sku_id)                AS sku_id,
  COALESCE(i.va_number, vs.va_number)          AS account_number,
  m.merchant_name                              AS merchant,
  e.amount_pulled                               AS amount_pulled,
  i.amount_received                             AS amount_received,
  (coalesce(e.amount_pulled,0) - coalesce(i.amount_received,0)) AS variance_pulled_vs_received,
  s.sales_proceeds                              AS sales_proceeds,
  (coalesce(s.sales_proceeds,0) - coalesce(i.amount_received,0)) AS variance_received_vs_sales
FROM va_to_sku vs
LEFT JOIN inflow i      ON i.va_number = vs.va_number
LEFT JOIN ext e         ON e.va_number = COALESCE(i.va_number, vs.va_number)
LEFT JOIN sales s       ON s.sku_id = COALESCE(i.sku_id, vs.sku_id)
LEFT JOIN ref.merchant m ON m.merchant_id = COALESCE(i.merchant_id, vs.merchant_id);
