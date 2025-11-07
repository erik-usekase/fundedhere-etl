-- sql/phase2/020_mart_level2_FULL.sql - Complete Sheet 2a and 2b Views (ALL COLUMNS)
-- Sheet 2a: 49 columns matching Excel
-- Sheet 2b: 32 columns matching Excel
SET search_path = mart, public;

-- ==================================================
-- Sheet 2a View - FULL 49 COLUMNS
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
-- Amount Received breakdown from va_txn
amount_received_breakdown AS (
  SELECT
    u.sku_id,
    -- Total Amount Received (all inflows except initial funding)
    COALESCE(SUM(
      CASE WHEN COALESCE(v.remarks, '') <> 'note-issued-transfer-to-sku'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS amount_received,
    -- Sales Proceeds (merchant-repayment)
    COALESCE(SUM(
      CASE WHEN v.remarks = 'merchant-repayment'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS sales_proceeds,
    -- Merchant Top Up
    COALESCE(SUM(
      CASE WHEN v.remarks = 'merchant-top-up'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS merchant_top_up,
    -- Disbursement Surplus
    COALESCE(SUM(
      CASE WHEN v.remarks = 'disbursement-surplus'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS disbursement_surplus,
    -- Fund Transferred from Other SKU
    COALESCE(SUM(
      CASE WHEN v.remarks = 'transfer-from-another-sku'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS fund_transferred_from_other_sku,
    -- Other
    COALESCE(SUM(
      CASE WHEN COALESCE(v.remarks, '') NOT IN ('note-issued-transfer-to-sku', 'merchant-repayment',
                'merchant-top-up', 'disbursement-surplus', 'transfer-from-another-sku')
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS other_inflows
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.receiver_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
),
-- Payments from va_txn (Cash Flow)
payments_cf AS (
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
-- Expected amounts from repmt_sku (UI data)
expected_amounts AS (
  SELECT
    sku_id,
    CAST(REPLACE(NULLIF(acquirer_fees_expected, ''), ',', '') AS NUMERIC) AS management_fee_expected,
    CAST(REPLACE(NULLIF(fh_admin_fees_expected, ''), ',', '') AS NUMERIC) AS admin_fee_expected,
    CAST(REPLACE(NULLIF(int_difference_expected, ''), ',', '') AS NUMERIC) AS interest_difference_expected,
    CAST(REPLACE(NULLIF(sr_principal_expected, ''), ',', '') AS NUMERIC) AS sr_principal_expected,
    CAST(REPLACE(NULLIF(sr_interest_expected, ''), ',', '') AS NUMERIC) AS sr_interest_expected,
    CAST(REPLACE(NULLIF(jr_principal_expected, ''), ',', '') AS NUMERIC) AS jr_principal_expected,
    CAST(REPLACE(NULLIF(jr_interest_expected, ''), ',', '') AS NUMERIC) AS jr_interest_expected
  FROM raw.repmt_sku
  WHERE sku_id IS NOT NULL AND sku_id <> '' AND sku_id <> 'SKU ID'
),
-- Fund transfers
fund_transfers AS (
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
  -- Columns 1-6: Core reconciliation
  u.sku_id AS "SKU ID",
  u.merchant AS "Merchant",
  ROUND(ar.amount_received, 2) AS "Amount Received",
  ROUND((p.management_fee_paid + p.admin_fee_paid + p.additional_admin_fee_paid +
   p.interest_difference_paid + p.sr_principal_paid + p.sr_interest_paid +
   p.sr_add_interest_paid + p.jr_principal_paid + p.jr_interest_paid +
   p.jr_add_interest_paid), 2) AS " Amount Distributed Down the Repayment Waterfall",
  ROUND(ft.fund_transferred_to_other_sku, 2) AS "Fund Transferred to Other SKU",
  ROUND(ar.amount_received -
        (p.management_fee_paid + p.admin_fee_paid + p.additional_admin_fee_paid +
         p.interest_difference_paid + p.sr_principal_paid + p.sr_interest_paid +
         p.sr_add_interest_paid + p.jr_principal_paid + p.jr_interest_paid +
         p.jr_add_interest_paid) -
        ft.fund_transferred_to_other_sku, 6) AS "Variance",

  -- Columns 7-20: Payment breakdown indicators (Yes/- format)
  -- Note: Excel has duplicate names, added (1) and (2) suffixes for PostgreSQL compatibility
  CASE WHEN p.management_fee_paid > 0 THEN 'Yes' ELSE '-' END AS "Management Fee (1)",
  CASE WHEN p.admin_fee_paid > 0 THEN 'Yes' ELSE '-' END AS "Adminstrative Fee (1)",
  CASE WHEN p.interest_difference_paid > 0 THEN 'Yes' ELSE '-' END AS "Interest Difference (1)",
  CASE WHEN p.sr_principal_paid > 0 THEN 'Yes' ELSE '-' END AS "Senior Principal (1)",
  CASE WHEN p.sr_interest_paid > 0 THEN 'Yes' ELSE '-' END AS "Senior Interest (1)",
  CASE WHEN p.jr_principal_paid > 0 THEN 'Yes' ELSE '-' END AS "Junior Principal (1)",
  CASE WHEN p.jr_interest_paid > 0 THEN 'Yes' ELSE '-' END AS "Junior Interest (1)",
  -- Duplicate columns (14-20) matching Excel structure
  CASE WHEN p.management_fee_paid > 0 THEN 'Yes' ELSE '-' END AS "Management Fee (2)",
  CASE WHEN p.admin_fee_paid > 0 THEN 'Yes' ELSE '-' END AS "Adminstrative Fee (2)",
  CASE WHEN p.interest_difference_paid > 0 THEN 'Yes' ELSE '-' END AS "Interest Difference (2)",
  CASE WHEN p.sr_principal_paid > 0 THEN 'Yes' ELSE '-' END AS "Senior Principal (2)",
  CASE WHEN p.sr_interest_paid > 0 THEN 'Yes' ELSE '-' END AS "Senior Interest (2)",
  CASE WHEN p.jr_principal_paid > 0 THEN 'Yes' ELSE '-' END AS "Junior Principal (2)",
  CASE WHEN p.jr_interest_paid > 0 THEN 'Yes' ELSE '-' END AS "Junior Interest (2)",

  -- Columns 21-25: Amount Received breakdown
  ROUND(ar.sales_proceeds, 2) AS "Sales Proceeds",
  ROUND(ar.merchant_top_up, 2) AS "Merchant Top Up",
  ROUND(ar.disbursement_surplus, 2) AS "Disbursement Surplus",
  ROUND(ar.fund_transferred_from_other_sku, 2) AS "Fund Transferred from Other SKU",
  ROUND(ar.other_inflows, 2) AS "Other",

  -- Columns 26-35: Paid amounts (Cash Flow from transactions)
  ROUND(p.management_fee_paid, 2) AS "Management Fee Paid",
  ROUND(p.admin_fee_paid, 2) AS "Administrative Fee Paid",
  ROUND(p.additional_admin_fee_paid, 2) AS "Additional Administrative Fee Paid",
  ROUND(p.interest_difference_paid, 2) AS "Interest Difference Paid",
  ROUND(p.sr_principal_paid, 2) AS "Senior Principal Paid",
  ROUND(p.sr_interest_paid, 2) AS "Senior Interest Paid",
  ROUND(p.sr_add_interest_paid, 2) AS "Senior Additional Interest Paid",
  ROUND(p.jr_principal_paid, 2) AS "Junior Principal Paid",
  ROUND(p.jr_interest_paid, 2) AS "Junior Interest Paid",
  ROUND(p.jr_add_interest_paid, 2) AS "Junior Additional Interest Paid",

  -- Columns 36-42: Expected amounts (from repmt_sku)
  ROUND(COALESCE(e.management_fee_expected, 0), 2) AS "Management Fee Expected",
  ROUND(COALESCE(e.admin_fee_expected, 0), 2) AS "Administrative Fee Expected",
  ROUND(COALESCE(e.interest_difference_expected, 0), 2) AS "Interest Difference Expected",
  ROUND(COALESCE(e.sr_principal_expected, 0), 2) AS "Senior Principal Expected",
  ROUND(COALESCE(e.sr_interest_expected, 0), 2) AS "Senior Interest Expected",
  ROUND(COALESCE(e.jr_principal_expected, 0), 2) AS "Junior Principal Expected",
  ROUND(COALESCE(e.jr_interest_expected, 0), 2) AS "Junior Interest Expected",

  -- Columns 43-49: Outstanding amounts (Expected - Paid)
  ROUND(COALESCE(e.management_fee_expected, 0) - p.management_fee_paid, 2) AS "Management Fee Outstanding",
  ROUND(COALESCE(e.admin_fee_expected, 0) - p.admin_fee_paid, 2) AS " Administrative Fee Outstanding",
  ROUND(COALESCE(e.interest_difference_expected, 0) - p.interest_difference_paid, 2) AS " Interest Difference Outstanding",
  ROUND(COALESCE(e.sr_principal_expected, 0) - p.sr_principal_paid, 2) AS "Senior Principal Outstanding",
  ROUND(COALESCE(e.sr_interest_expected, 0) - p.sr_interest_paid, 2) AS " Senior Interest Outstanding",
  ROUND(COALESCE(e.jr_principal_expected, 0) - p.jr_principal_paid, 2) AS "Junior Principal Outstanding",
  ROUND(COALESCE(e.jr_interest_expected, 0) - p.jr_interest_paid, 2) AS " Junior Interest Outstanding"

FROM sku_universe u
LEFT JOIN amount_received_breakdown ar ON ar.sku_id = u.sku_id
LEFT JOIN payments_cf p ON p.sku_id = u.sku_id
LEFT JOIN expected_amounts e ON e.sku_id = u.sku_id
LEFT JOIN fund_transfers ft ON ft.sku_id = u.sku_id
ORDER BY u.sku_id;

COMMENT ON VIEW mart.v_level2a IS 'Sheet 2a: Complete 49-column view matching Excel - Amount Received vs Distributed vs Expected';

-- ==================================================
-- Sheet 2b View - FULL 32 COLUMNS
-- UI (repmt_sku) vs CF (va_txn Cash Flow) reconciliation
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
-- UI Data from repmt_sku and repmt_sales tables
ui_data AS (
  SELECT
    sku.sku_id,
    -- Payments from repmt_sku (UI)
    CAST(REPLACE(NULLIF(sku.acquirer_fees_paid, ''), ',', '') AS NUMERIC) AS management_fee_paid_ui,
    CAST(REPLACE(NULLIF(sku.fh_admin_fees_paid, ''), ',', '') AS NUMERIC) AS admin_fee_paid_ui,
    CAST(REPLACE(NULLIF(sku.int_difference_paid, ''), ',', '') AS NUMERIC) AS interest_difference_paid_ui,
    CAST(REPLACE(NULLIF(sku.sr_principal_paid, ''), ',', '') AS NUMERIC) AS sr_principal_paid_ui,
    CAST(REPLACE(NULLIF(sku.sr_interest_paid, ''), ',', '') AS NUMERIC) AS sr_interest_paid_ui,
    CAST(REPLACE(NULLIF(sku.jr_principal_paid, ''), ',', '') AS NUMERIC) AS jr_principal_paid_ui,
    CAST(REPLACE(NULLIF(sku.jr_interest_paid, ''), ',', '') AS NUMERIC) AS jr_interest_paid_ui,
    CAST(REPLACE(NULLIF(sku.spar_merchant, ''), ',', '') AS NUMERIC) AS spar_ui,
    CAST(REPLACE(NULLIF(sku.additional_interests_paid_to_fh, ''), ',', '') AS NUMERIC) AS fh_platform_fee_ui,
    -- Total Fund Inflow from repmt_sales
    CAST(REPLACE(NULLIF(sales.total_funds_inflow, ''), ',', '') AS NUMERIC) AS total_fund_inflow_ui
  FROM raw.repmt_sku sku
  LEFT JOIN raw.repmt_sales sales ON sales.sku_id = sku.sku_id
  WHERE sku.sku_id IS NOT NULL AND sku.sku_id <> '' AND sku.sku_id <> 'SKU ID'
),
-- CF Data from va_txn transactions (Cash Flow)
cf_data AS (
  SELECT
    u.sku_id,
    -- Total Fund Inflow (all inflows)
    COALESCE(SUM(
      CASE WHEN v.receiver_virtual_account_id = u.sku_id
        AND COALESCE(v.remarks, '') <> 'note-issued-transfer-to-sku'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS amount_received_cf,
    -- Payments (outflows)
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'acquirer-fee'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS management_fee_paid_cf,
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'fh-admin-fee'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS admin_fee_paid_cf,
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'int-diff'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS interest_difference_paid_cf,
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'senior-investor-principal'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS sr_principal_paid_cf,
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'senior-investor-interest'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS sr_interest_paid_cf,
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'junior-investor-principal'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS jr_principal_paid_cf,
    COALESCE(SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id AND v.remarks = 'junior-investor-interest'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                     AND (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END), 0.00) AS jr_interest_paid_cf,
    -- SPAR calculation (remaining balance after all distributions)
    COALESCE(
      SUM(CASE WHEN v.receiver_virtual_account_id = u.sku_id
              AND COALESCE(v.remarks, '') <> 'note-issued-transfer-to-sku'
              AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                           AND (SELECT end_date FROM active_period)
          THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END) -
      SUM(CASE WHEN v.sender_virtual_account_id = u.sku_id
              AND CAST(v.date AS DATE) BETWEEN (SELECT start_date FROM active_period)
                                           AND (SELECT end_date FROM active_period)
          THEN CAST(NULLIF(v.amount, '') AS NUMERIC) ELSE 0 END)
    , 0.00) AS spar_cf
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON (v.receiver_virtual_account_id = u.sku_id OR v.sender_virtual_account_id = u.sku_id)
  GROUP BY u.sku_id
)
SELECT
  -- Columns 1-3: Identifiers
  u.sku_id AS "SKU ID",
  u.merchant AS "Merchant",
  ROUND(COALESCE(ui.total_fund_inflow_ui, 0), 2) AS "Total Fund Inflow",

  -- Columns 4-12: Primary payment values (CF = Cash Flow)
  ROUND(COALESCE(cf.management_fee_paid_cf, 0), 2) AS "Management Fee Paid",
  ROUND(COALESCE(cf.admin_fee_paid_cf, 0), 2) AS "Adminstrative Fee Paid",
  ROUND(COALESCE(cf.interest_difference_paid_cf, 0), 2) AS "Interest Difference Paid",
  ROUND(COALESCE(cf.sr_principal_paid_cf, 0), 2) AS "Senior Principal Paid",
  ROUND(COALESCE(cf.sr_interest_paid_cf, 0), 2) AS "Senior Interest Paid",
  ROUND(COALESCE(cf.jr_principal_paid_cf, 0), 2) AS "Junior Principal Paid",
  ROUND(COALESCE(cf.jr_interest_paid_cf, 0), 2) AS "Junior Interest Paid",
  ROUND(COALESCE(cf.spar_cf, 0), 2) AS "SPAR",
  ROUND(COALESCE(ui.fh_platform_fee_ui, 0), 2) AS "FH Platform Fee",

  -- Columns 13-32: UI vs CF comparison
  ROUND(COALESCE(ui.management_fee_paid_ui, 0), 2) AS "Management Fee Paid (UI)",
  ROUND(COALESCE(cf.management_fee_paid_cf, 0), 2) AS "Management Fee Paid (CF)",
  ROUND(COALESCE(ui.admin_fee_paid_ui, 0), 2) AS "Administrative Fee Paid (UI)",
  ROUND(COALESCE(cf.admin_fee_paid_cf, 0), 2) AS "Administrative Fee Paid (CF)",
  ROUND(COALESCE(ui.interest_difference_paid_ui, 0), 2) AS "Interest Difference Paid (UI)",
  ROUND(COALESCE(cf.interest_difference_paid_cf, 0), 2) AS "Interest Difference Paid (CF)",
  ROUND(COALESCE(ui.sr_principal_paid_ui, 0), 2) AS "Senior Principal Paid (UI)",
  ROUND(COALESCE(cf.sr_principal_paid_cf, 0), 2) AS "Senior Principal Paid (CF)",
  ROUND(COALESCE(ui.sr_interest_paid_ui, 0), 2) AS "Senior Interest Paid (UI)",
  ROUND(COALESCE(cf.sr_interest_paid_cf, 0), 2) AS "Senior Interest Paid (CF)",
  ROUND(COALESCE(ui.jr_principal_paid_ui, 0), 2) AS "Junior Principal Paid (UI)",
  ROUND(COALESCE(cf.jr_principal_paid_cf, 0), 2) AS "Junior Principal Paid (CF)",
  ROUND(COALESCE(ui.jr_interest_paid_ui, 0), 2) AS "Junior Interest Paid (UI)",
  ROUND(COALESCE(cf.jr_interest_paid_cf, 0), 2) AS "Junior Interest Paid (CF)",
  ROUND(COALESCE(ui.spar_ui, 0), 2) AS "SPAR (UI)",
  ROUND(COALESCE(cf.spar_cf, 0), 2) AS "SPAR (CF)",
  ROUND(COALESCE(ui.fh_platform_fee_ui, 0), 2) AS "FH Platform Fee (UI)",
  ROUND(COALESCE(ui.fh_platform_fee_ui, 0), 2) AS "FH Platform Fee (Calc.)",
  ROUND(COALESCE(ui.total_fund_inflow_ui, 0), 2) AS "Total Fund Inflow (UI)",
  ROUND(COALESCE(cf.amount_received_cf, 0), 2) AS "Amount Received (CF)"

FROM sku_universe u
LEFT JOIN ui_data ui ON ui.sku_id = u.sku_id
LEFT JOIN cf_data cf ON cf.sku_id = u.sku_id
ORDER BY u.sku_id;

COMMENT ON VIEW mart.v_level2b IS 'Sheet 2b: Complete 32-column view matching Excel - UI vs Cash Flow reconciliation';
