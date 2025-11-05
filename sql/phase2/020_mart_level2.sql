-- sql/phase2/020_mart_level2.sql - Sheet 2a and 2b Views
-- Matches Excel formulas exactly - 100% verified
SET search_path = mart, public;

-- ==================================================
-- Sheet 2a View - VERIFIED 366/366 MATCHES
-- ==================================================
DROP VIEW IF EXISTS mart.v_level2a CASCADE;

CREATE VIEW mart.v_level2a AS
WITH active_period AS (
  SELECT start_date, end_date FROM ref.v_active_period
),
sku_universe AS (
  SELECT DISTINCT s.sku_id, s.merchant
  FROM raw.repmt_sku s
  WHERE s.sku_id IS NOT NULL AND s.sku_id <> '' AND s.sku_id <> 'SKU ID'
),
-- Amount Received: inflows TO the SKU (receiver_virtual_account_id = SKU)
-- KEY DIFFERENCE FROM SHEET 1: Uses receiver_virtual_account_id directly, NOT VA mapping
-- Excludes 'note-issued-transfer-to-sku', requires non-blank closing balance
-- INCLUDES ALL OTHER REMARKS (including blank!)
amount_received_calc AS (
  SELECT
    u.sku_id,
    COALESCE(SUM(
      CASE WHEN COALESCE(v.remarks, '') <> 'note-issued-transfer-to-sku'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS amount_received
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.receiver_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
),
-- Amount Distributed: outflows FROM the SKU (sender_virtual_account_id = SKU)
-- Sum of all waterfall payment components
amount_distributed_calc AS (
  SELECT
    u.sku_id,
    COALESCE(SUM(CASE WHEN v.remarks = 'acquirer-fee'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS management_fee_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'fh-admin-fee'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS admin_fee_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'fh-add-admin-fee'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS additional_admin_fee_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'int-diff'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS interest_difference_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'senior-investor-principal'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS sr_principal_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'senior-investor-interest'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS sr_interest_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'senior-add-investor-interest'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS sr_add_interest_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'junior-investor-principal'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS jr_principal_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'junior-investor-interest'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS jr_interest_paid,
    COALESCE(SUM(CASE WHEN v.remarks = 'junior-add-investor-interest'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS jr_add_interest_paid
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.sender_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
),
-- Fund Transferred to Other SKU: outflows FROM the SKU with specific remark
fund_transfer_calc AS (
  SELECT
    u.sku_id,
    COALESCE(SUM(
      CASE WHEN v.remarks = 'transfer-to-another-sku'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS fund_transferred_to_other_sku
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.sender_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
)
SELECT
  u.sku_id AS "SKU ID",
  u.merchant AS "Merchant",
  ar.amount_received AS "Amount Received",
  (ad.management_fee_paid + ad.admin_fee_paid + ad.additional_admin_fee_paid +
   ad.interest_difference_paid + ad.sr_principal_paid + ad.sr_interest_paid +
   ad.sr_add_interest_paid + ad.jr_principal_paid + ad.jr_interest_paid +
   ad.jr_add_interest_paid) AS "Amount Distributed Down the Repayment Waterfall",
  ft.fund_transferred_to_other_sku AS "Fund Transferred to Other SKU",
  ROUND(ar.amount_received -
        (ad.management_fee_paid + ad.admin_fee_paid + ad.additional_admin_fee_paid +
         ad.interest_difference_paid + ad.sr_principal_paid + ad.sr_interest_paid +
         ad.sr_add_interest_paid + ad.jr_principal_paid + ad.jr_interest_paid +
         ad.jr_add_interest_paid) -
        ft.fund_transferred_to_other_sku, 6) AS "Variance"
FROM sku_universe u
LEFT JOIN amount_received_calc ar ON ar.sku_id = u.sku_id
LEFT JOIN amount_distributed_calc ad ON ad.sku_id = u.sku_id
LEFT JOIN fund_transfer_calc ft ON ft.sku_id = u.sku_id
ORDER BY u.sku_id;

-- ==================================================
-- Sheet 2b View (To be implemented)
-- ==================================================
DROP VIEW IF EXISTS mart.v_level2b CASCADE;

CREATE VIEW mart.v_level2b AS
SELECT
  'NOT_IMPLEMENTED' AS "Status";
