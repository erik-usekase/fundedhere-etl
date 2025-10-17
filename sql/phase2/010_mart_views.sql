-- sql/phase2/010_mart_views.sql (FINAL CONSOLIDATED CODE)
SET search_path = mart, public;

DROP VIEW IF EXISTS mart.v_level1;

CREATE VIEW mart.v_level1 AS
WITH universe AS (
  -- The grain of the report is one row per unique SKU/VA mapping.
  -- We rank them to handle figures that are at the SKU- or VA-level without duplication.
  SELECT DISTINCT
    n.sku_id,
    n.va_number      AS account_number,
    m.merchant_name,
    ROW_NUMBER() OVER(PARTITION BY n.sku_id ORDER BY n.va_number) as sku_va_rank,
    ROW_NUMBER() OVER(PARTITION BY n.va_number ORDER BY n.sku_id) as va_sku_rank
  FROM ref.note_sku_va_map n
  JOIN ref.merchant m ON m.merchant_id = n.merchant_id
),
pulled AS (
  -- Aggregate "pulled" amounts at the VA level.
  SELECT
    va_number AS account_number,
    SUM(buy_amount) AS amount_pulled
  FROM core.mv_external_accounts
  GROUP BY 1
),
received AS (
  -- Aggregate "received" amounts at the SKU and VA level.
  SELECT
    f.sku_id,
    f.va_number AS account_number,
    SUM(CASE WHEN f.direction = 'inflow' AND f.category_code = 'merchant_repayment' THEN f.signed_amount ELSE 0 END) AS amount_received
  FROM core.mv_va_txn_flows f
  GROUP BY 1,2
),
sales AS (
  -- Sales are at the SKU level.
  SELECT
    s.sku_id,
    SUM(s.sales_proceeds) AS sales_proceeds
  FROM core.mv_repmt_sales s
  GROUP BY 1
)
-- Use lowercase, unquoted identifiers to match the test script's expectations.
SELECT
  u.sku_id,
  u.account_number,
  u.merchant_name                                                                                           AS merchant,
  CASE WHEN u.va_sku_rank = 1 THEN COALESCE(p.amount_pulled, 0) ELSE 0 END                                  AS amount_pulled,
  COALESCE(r.amount_received, 0)                                                                            AS amount_received,
  (CASE WHEN u.va_sku_rank = 1 THEN COALESCE(p.amount_pulled, 0) ELSE 0 END - COALESCE(r.amount_received,0)) AS variance_pulled_vs_received,
  CASE WHEN u.sku_va_rank = 1 THEN COALESCE(s.sales_proceeds, 0) ELSE 0 END                                 AS sales_proceeds,
  (CASE WHEN u.sku_va_rank = 1 THEN COALESCE(s.sales_proceeds, 0) ELSE 0 END - COALESCE(r.amount_received,0)) AS variance_received_vs_sales
FROM universe u
LEFT JOIN pulled p   ON p.account_number = u.account_number
LEFT JOIN received r ON r.sku_id = u.sku_id AND r.account_number = u.account_number
LEFT JOIN sales s    ON s.sku_id = u.sku_id;