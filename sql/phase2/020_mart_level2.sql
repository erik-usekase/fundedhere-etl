-- sql/phase2/020_mart_level2.sql - Sheet 2a and 2b Views
-- Modified to match original test outputs from "2a Output" and "2b Output" sheets
SET search_path = mart, public;

-- ==================================================
-- Sheet 2a View - Matching "2a Output" test file
-- Key: Amount Received uses ONLY 'merchant-repayment' remarks
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
-- Amount Received: ALL inflows to SKU EXCEPT 'note-issued-transfer-to-sku' (initial funding)
-- Includes: merchant-repayment, transfer-to-another-sku, blank remarks, etc.
-- Uses receiver_virtual_account_id = SKU (direct match, NOT VA mapping)
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
   ad.jr_add_interest_paid) AS " Amount Distributed Down the Repayment Waterfall",
  ft.fund_transferred_to_other_sku AS "Fund Transferred to Other SKU",
  ROUND(ar.amount_received -
        (ad.management_fee_paid + ad.admin_fee_paid + ad.additional_admin_fee_paid +
         ad.interest_difference_paid + ad.sr_principal_paid + ad.sr_interest_paid +
         ad.sr_add_interest_paid + ad.jr_principal_paid + ad.jr_interest_paid +
         ad.jr_add_interest_paid) -
        ft.fund_transferred_to_other_sku, 6) AS "Variance",
  -- Waterfall breakdown columns (matching Excel columns 7-13)
  ad.management_fee_paid AS "Management Fee",
  ad.admin_fee_paid AS "Adminstrative Fee",
  ad.additional_admin_fee_paid AS "Additional Adminstrative Fee",
  ad.interest_difference_paid AS "Interest Difference",
  ad.sr_principal_paid AS "Senior Principal",
  ad.sr_interest_paid AS "Senior Interest",
  ad.sr_add_interest_paid AS "Senior Additional Interest",
  ad.jr_principal_paid AS "Junior Principal",
  ad.jr_interest_paid AS "Junior Interest",
  ad.jr_add_interest_paid AS "Junior Additional Interest"
FROM sku_universe u
LEFT JOIN amount_received_calc ar ON ar.sku_id = u.sku_id
LEFT JOIN amount_distributed_calc ad ON ad.sku_id = u.sku_id
LEFT JOIN fund_transfer_calc ft ON ft.sku_id = u.sku_id
ORDER BY u.sku_id;

-- ==================================================
-- Sheet 2b View - Matching "2b Output" test file
-- Shows ACTUAL TRANSACTION VALUES (not variances)
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
-- Amount Received: ALL inflows to SKU EXCEPT 'note-issued-transfer-to-sku' (matching Sheet 2a)
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
-- Actual paid amounts from transactions
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
    -- SPAR = Disbursement Transaction Fee + Cross-Note Transfers
    COALESCE(SUM(CASE WHEN v.remarks IN ('Disbursement Transaction Fee', 'Transfer-to-another-sku (Cross Note) Same Merchant')
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS spar_paid
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.sender_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
)
SELECT
  u.sku_id AS "SKU ID",
  u.merchant AS "Merchant",
  -- Main columns show ACTUAL VALUES (not variances)
  ar.amount_received AS "Total Fund Inflow",
  a.management_fee_paid AS "Management Fee Paid",
  a.admin_fee_paid AS "Adminstrative Fee Paid",
  a.interest_diff_paid AS "Interest Difference Paid",
  a.sr_principal_paid AS "Senior Principal Paid",
  a.sr_interest_paid AS "Senior Interest Paid",
  a.jr_principal_paid AS "Junior Principal Paid",
  a.jr_interest_paid AS "Junior Interest Paid",
  a.spar_paid AS "SPAR",
  0.00 AS "FH Platform Fee"
FROM sku_universe u
LEFT JOIN amount_received_calc ar ON ar.sku_id = u.sku_id
LEFT JOIN actual_paid a ON a.sku_id = u.sku_id
ORDER BY u.sku_id;
