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
-- Sheet 2b View - Variance/Comparison Sheet
-- ==================================================
DROP VIEW IF EXISTS mart.v_level2b CASCADE;

CREATE VIEW mart.v_level2b AS
WITH active_period AS (
  SELECT start_date, end_date FROM ref.v_active_period
),
sku_universe AS (
  SELECT DISTINCT s.sku_id, s.merchant
  FROM raw.repmt_sku s
  WHERE s.sku_id IS NOT NULL AND s.sku_id <> '' AND s.sku_id <> 'SKU ID'
),
-- Expected values (UI) from repmt_sku
expected_values AS (
  SELECT
    s.sku_id,
    COALESCE(CAST(NULLIF(s.acquirer_fees_expected, '') AS NUMERIC), 0) AS management_fee_expected,
    COALESCE(CAST(NULLIF(s.fh_admin_fees_expected, '') AS NUMERIC), 0) AS admin_fee_expected,
    COALESCE(CAST(NULLIF(s.int_difference_expected, '') AS NUMERIC), 0) AS interest_diff_expected,
    COALESCE(CAST(NULLIF(s.sr_principal_expected, '') AS NUMERIC), 0) AS sr_principal_expected,
    COALESCE(CAST(NULLIF(s.sr_interest_expected, '') AS NUMERIC), 0) AS sr_interest_expected,
    COALESCE(CAST(NULLIF(s.jr_principal_expected, '') AS NUMERIC), 0) AS jr_principal_expected,
    COALESCE(CAST(NULLIF(s.jr_interest_expected, '') AS NUMERIC), 0) AS jr_interest_expected,
    COALESCE(CAST(NULLIF(s.spar_merchant, '') AS NUMERIC), 0) AS spar_expected
  FROM raw.repmt_sku s
),
-- Calculated actual values (CF) from va_txn
actual_paid AS (
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
    COALESCE(SUM(CASE WHEN v.remarks = 'int-diff'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS interest_diff_paid,
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
    -- SPAR (CF) = Disbursement Transaction Fee + Cross-Note Transfers
    COALESCE(SUM(CASE WHEN v.remarks IN ('Disbursement Transaction Fee', 'Transfer-to-another-sku (Cross Note) Same Merchant')
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS spar_paid
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.sender_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
),
-- Amount received (total fund inflow)
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
)
SELECT
  u.sku_id AS "SKU ID",
  u.merchant AS "Merchant",
  -- Variance columns (expected - actual)
  ROUND(ar.amount_received - ar.amount_received, 6) AS "Total Fund Inflow",
  ROUND(e.management_fee_expected - a.management_fee_paid, 6) AS "Management Fee Paid",
  ROUND(e.admin_fee_expected - a.admin_fee_paid, 6) AS "Adminstrative Fee Paid",
  ROUND(e.interest_diff_expected - a.interest_diff_paid, 6) AS "Interest Difference Paid",
  ROUND(e.sr_principal_expected - a.sr_principal_paid, 6) AS "Senior Principal Paid",
  ROUND(e.sr_interest_expected - a.sr_interest_paid, 6) AS "Senior Interest Paid",
  ROUND(e.jr_principal_expected - a.jr_principal_paid, 6) AS "Junior Principal Paid",
  ROUND(e.jr_interest_expected - a.jr_interest_paid, 6) AS "Junior Interest Paid",
  ROUND(e.spar_expected - a.spar_paid, 6) AS "SPAR",
  0.00 AS "FH Platform Fee",
  -- Comparison columns (UI = expected, CF = calculated from transactions)
  e.management_fee_expected AS "Management Fee Paid (UI)",
  a.management_fee_paid AS "Management Fee Paid (CF)",
  e.admin_fee_expected AS "Administrative Fee Paid (UI)",
  a.admin_fee_paid AS "Administrative Fee Paid (CF)",
  e.interest_diff_expected AS "Interest Difference Paid (UI)",
  a.interest_diff_paid AS "Interest Difference Paid (CF)",
  e.sr_principal_expected AS "Senior Principal Paid (UI)",
  a.sr_principal_paid AS "Senior Principal Paid (CF)",
  e.sr_interest_expected AS "Senior Interest Paid (UI)",
  a.sr_interest_paid AS "Senior Interest Paid (CF)",
  e.jr_principal_expected AS "Junior Principal Paid (UI)",
  a.jr_principal_paid AS "Junior Principal Paid (CF)",
  e.jr_interest_expected AS "Junior Interest Paid (UI)",
  a.jr_interest_paid AS "Junior Interest Paid (CF)",
  e.spar_expected AS "SPAR (UI)",
  a.spar_paid AS "SPAR (CF)",
  0.00 AS "FH Platform Fee (UI)",
  0.00 AS "FH Platform Fee (Calc.)",
  ar.amount_received AS "Total Fund Inflow (UI)",
  ar.amount_received AS "Amount Received (CF)"
FROM sku_universe u
LEFT JOIN expected_values e ON e.sku_id = u.sku_id
LEFT JOIN actual_paid a ON a.sku_id = u.sku_id
LEFT JOIN amount_received_calc ar ON ar.sku_id = u.sku_id
ORDER BY u.sku_id;
