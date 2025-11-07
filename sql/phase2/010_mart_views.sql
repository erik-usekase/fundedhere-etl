-- sql/phase2/010_mart_views.sql - Sheet 1 View (8 columns)
SET search_path = mart, public;

DROP VIEW IF EXISTS mart.v_level1 CASCADE;

CREATE VIEW mart.v_level1 AS
WITH active_period AS (
  -- Get date range from active reporting period
  SELECT start_date, end_date FROM ref.v_active_period
),
sku_universe AS (
  -- Get all unique SKUs from repmt_sku (like UNIQUE FILTER in Excel)
  SELECT DISTINCT
    s.sku_id,
    s.merchant
  FROM raw.repmt_sku s
  WHERE s.sku_id IS NOT NULL AND s.sku_id <> '' AND s.sku_id <> 'SKU ID'
),
sku_accounts AS (
  -- Get Account Number from mapping
  SELECT
    u.sku_id,
    u.merchant,
    m.va_number AS account_number
  FROM sku_universe u
  LEFT JOIN ref.note_sku_va_map m ON u.sku_id = m.sku_id
),
amount_pulled AS (
  -- Amount Pulled = SUM(buy_amount) from external_accounts by account number
  SELECT
    a.sku_id,
    COALESCE(SUM(CAST(REPLACE(NULLIF(e.buy_amount, ''), ',', '') AS NUMERIC)), 0.00) AS pulled
  FROM sku_accounts a
  LEFT JOIN raw.external_accounts e
    ON e.beneficiary_bank_account_number = a.account_number
    AND parse_csv_date(e.created_date) >= (SELECT start_date FROM active_period)
    AND parse_csv_date(e.created_date) <= (SELECT end_date FROM active_period)
  GROUP BY a.sku_id
),
amount_received AS (
  -- Amount Received = SUM(merchant-repayment) from va_txn
  SELECT
    a.sku_id,
    COALESCE(SUM(
      CASE WHEN v.remarks = 'merchant-repayment'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND parse_csv_date(v.date) >= (SELECT start_date FROM active_period)
        AND parse_csv_date(v.date) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS received
  FROM sku_accounts a
  LEFT JOIN raw.va_txn v ON v.receiver_virtual_account_id = a.sku_id
  GROUP BY a.sku_id
),
sales_data AS (
  -- Sales Proceeds from repmt_sales table (XLOOKUP)
  SELECT
    a.sku_id,
    COALESCE(CAST(REPLACE(NULLIF(s.sales_proceeds, ''), ',', '') AS NUMERIC), 0.00) AS sales_proceeds
  FROM sku_accounts a
  LEFT JOIN raw.repmt_sales s ON s.sku_id = a.sku_id
)
SELECT
  a.sku_id AS "SKU ID",
  a.account_number AS "Account Number",
  a.merchant AS "Merchant",
  ROUND(COALESCE(p.pulled, 0.00), 2) AS "Amount Pulled",
  ROUND(COALESCE(r.received, 0.00), 2) AS "Amount Received",
  ROUND(COALESCE(r.received, 0.00) - COALESCE(p.pulled, 0.00), 2) AS "Variance",
  ROUND(COALESCE(s.sales_proceeds, 0.00), 2) AS "Sales Proceeds",
  ROUND(COALESCE(s.sales_proceeds, 0.00) - COALESCE(p.pulled, 0.00), 2) AS "Variance (2)"
FROM sku_accounts a
LEFT JOIN amount_pulled p ON p.sku_id = a.sku_id
LEFT JOIN amount_received r ON r.sku_id = a.sku_id
LEFT JOIN sales_data s ON s.sku_id = a.sku_id
ORDER BY a.sku_id;
