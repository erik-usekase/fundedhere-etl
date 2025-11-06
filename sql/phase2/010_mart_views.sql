-- sql/phase2/010_mart_views.sql - Level 1 View matching Excel formulas
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
inflow_metrics AS (
  -- Calculate inflows separately to avoid cartesian product
  SELECT
    u.sku_id,
    -- Sales Proceeds: remark = 'merchant-repayment'
    COALESCE(SUM(
      CASE WHEN v.remarks = 'merchant-repayment'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS sales_proceeds,

    -- Merchant Top Up: remark = '' (blank)
    COALESCE(SUM(
      CASE WHEN COALESCE(v.remarks, '') = ''
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS merchant_top_up,

    -- Disbursement Surplus
    COALESCE(SUM(
      CASE WHEN v.remarks IN ('disbursement-surplus', 'disbursement-delivered-shortfall')
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS disbursement_surplus,

    -- Fund Transferred from Other SKU
    COALESCE(SUM(
      CASE WHEN v.remarks = 'transfer-to-another-sku'
        AND COALESCE(v.receiver_va_closing_balance, '') <> ''
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS fund_transferred_from_other_sku
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.receiver_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
),
outflow_metrics AS (
  -- Calculate outflows separately to avoid cartesian product
  SELECT
    u.sku_id,
    -- Fund Transferred to Other SKU
    COALESCE(SUM(
      CASE WHEN v.remarks = 'transfer-to-another-sku'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS fund_transferred_to_other_sku,

    -- Paid amounts by category
    COALESCE(SUM(
      CASE WHEN v.remarks = 'acquirer-fee'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS management_fee_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'fh-admin-fee'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS admin_fee_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'fh-add-admin-fee'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS additional_admin_fee_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'int-diff'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS interest_difference_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'senior-investor-principal'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS senior_principal_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'senior-investor-interest'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS senior_interest_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'senior-add-investor-interest'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS senior_add_interest_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'junior-investor-principal'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS junior_principal_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'junior-investor-interest'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS junior_interest_paid,

    COALESCE(SUM(
      CASE WHEN v.remarks = 'junior-add-investor-interest'
        AND CAST(v.date AS DATE) >= (SELECT start_date FROM active_period)
        AND CAST(v.date AS DATE) <= (SELECT end_date FROM active_period)
      THEN CAST(NULLIF(v.amount, '') AS NUMERIC)
      ELSE 0 END
    ), 0.00) AS junior_add_interest_paid
  FROM sku_universe u
  LEFT JOIN raw.va_txn v ON v.sender_virtual_account_id = u.sku_id
  GROUP BY u.sku_id
),
expected_values AS (
  -- Get expected amounts from repmt_sku (XLOOKUP equivalent)
  SELECT
    sku_id,
    COALESCE(CAST(NULLIF(acquirer_fees_expected, '') AS NUMERIC), 0.00) AS management_fee_expected,
    COALESCE(CAST(NULLIF(fh_admin_fees_expected, '') AS NUMERIC), 0.00) AS admin_fee_expected,
    COALESCE(CAST(NULLIF(int_difference_expected, '') AS NUMERIC), 0.00) AS interest_difference_expected,
    COALESCE(CAST(NULLIF(sr_principal_expected, '') AS NUMERIC), 0.00) AS senior_principal_expected,
    COALESCE(CAST(NULLIF(sr_interest_expected, '') AS NUMERIC), 0.00) AS senior_interest_expected,
    COALESCE(CAST(NULLIF(jr_principal_expected, '') AS NUMERIC), 0.00) AS junior_principal_expected,
    COALESCE(CAST(NULLIF(jr_interest_expected, '') AS NUMERIC), 0.00) AS junior_interest_expected
  FROM raw.repmt_sku
  WHERE sku_id IS NOT NULL AND sku_id <> '' AND sku_id <> 'SKU ID'
)
SELECT
  u.sku_id AS "SKU ID",
  u.merchant AS "Merchant",
  inf.sales_proceeds AS "Amount Received",

  -- Amount Distributed Down the Repayment Waterfall
  (out.management_fee_paid + out.admin_fee_paid + out.additional_admin_fee_paid +
   out.interest_difference_paid + out.senior_principal_paid + out.senior_interest_paid +
   out.senior_add_interest_paid + out.junior_principal_paid + out.junior_interest_paid +
   out.junior_add_interest_paid) AS "Amount Distributed Down the Repayment Waterfall",

  out.fund_transferred_to_other_sku AS "Fund Transferred to Other SKU",

  -- Variance
  ROUND(inf.sales_proceeds -
    (out.management_fee_paid + out.admin_fee_paid + out.additional_admin_fee_paid +
     out.interest_difference_paid + out.senior_principal_paid + out.senior_interest_paid +
     out.senior_add_interest_paid + out.junior_principal_paid + out.junior_interest_paid +
     out.junior_add_interest_paid) -
    out.fund_transferred_to_other_sku, 6) AS "Variance",

  -- Outstanding flags
  CASE WHEN (COALESCE(e.management_fee_expected, 0) - out.management_fee_paid) < 0 THEN 'Yes' ELSE '-' END AS "Management Fee",
  CASE WHEN (COALESCE(e.admin_fee_expected, 0) - out.admin_fee_paid) < 0 THEN 'Yes' ELSE '-' END AS "Adminstrative Fee",
  CASE WHEN (COALESCE(e.interest_difference_expected, 0) - out.interest_difference_paid) < 0 THEN 'Yes' ELSE '-' END AS "Interest Difference",
  CASE WHEN (COALESCE(e.senior_principal_expected, 0) - out.senior_principal_paid) < 0 THEN 'Yes' ELSE '-' END AS "Senior Principal",
  CASE WHEN (COALESCE(e.senior_interest_expected, 0) - out.senior_interest_paid) < 0 THEN 'Yes' ELSE '-' END AS "Senior Interest",
  CASE WHEN (COALESCE(e.junior_principal_expected, 0) - out.junior_principal_paid) < 0 THEN 'Yes' ELSE '-' END AS "Junior Principal",
  CASE WHEN (COALESCE(e.junior_interest_expected, 0) - out.junior_interest_paid) < 0 THEN 'Yes' ELSE '-' END AS "Junior Interest",

  -- Settled flags
  CASE WHEN (COALESCE(e.management_fee_expected, 0) - out.management_fee_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Management Fee Settled",
  CASE WHEN (COALESCE(e.admin_fee_expected, 0) - out.admin_fee_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Adminstrative Fee Settled",
  CASE WHEN (COALESCE(e.interest_difference_expected, 0) - out.interest_difference_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Interest Difference Settled",
  CASE WHEN (COALESCE(e.senior_principal_expected, 0) - out.senior_principal_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Senior Principal Settled",
  CASE WHEN (COALESCE(e.senior_interest_expected, 0) - out.senior_interest_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Senior Interest Settled",
  CASE WHEN (COALESCE(e.junior_principal_expected, 0) - out.junior_principal_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Junior Principal Settled",
  CASE WHEN (COALESCE(e.junior_interest_expected, 0) - out.junior_interest_paid) <= 0 THEN 'Yes' ELSE '-' END AS "Junior Interest Settled",

  -- Amount Received Breakdown
  inf.sales_proceeds AS "Sales Proceeds",
  inf.merchant_top_up AS "Merchant Top Up",
  inf.disbursement_surplus AS "Disbursement Surplus",
  inf.fund_transferred_from_other_sku AS "Fund Transferred from Other SKU",
  ROUND(inf.sales_proceeds - inf.sales_proceeds, 6) AS "Other",

  -- Paid Amounts
  out.management_fee_paid AS "Management Fee Paid",
  out.admin_fee_paid AS "Administrative Fee Paid",
  out.additional_admin_fee_paid AS "Additional Administrative Fee Paid",
  out.interest_difference_paid AS "Interest Difference Paid",
  out.senior_principal_paid AS "Senior Principal Paid",
  out.senior_interest_paid AS "Senior Interest Paid",
  out.senior_add_interest_paid AS "Senior Additional Interest Paid",
  out.junior_principal_paid AS "Junior Principal Paid",
  out.junior_interest_paid AS "Junior Interest Paid",
  out.junior_add_interest_paid AS "Junior Additional Interest Paid",

  -- Expected Amounts
  COALESCE(e.management_fee_expected, 0.00) AS "Management Fee Expected",
  COALESCE(e.admin_fee_expected, 0.00) AS "Administrative Fee Expected",
  COALESCE(e.interest_difference_expected, 0.00) AS "Interest Difference Expected",
  COALESCE(e.senior_principal_expected, 0.00) AS "Senior Principal Expected",
  COALESCE(e.senior_interest_expected, 0.00) AS "Senior Interest Expected",
  COALESCE(e.junior_principal_expected, 0.00) AS "Junior Principal Expected",
  COALESCE(e.junior_interest_expected, 0.00) AS "Junior Interest Expected",

  -- Outstanding Amounts
  ROUND(COALESCE(e.management_fee_expected, 0.00) - out.management_fee_paid, 6) AS "Management Fee Outstanding",
  ROUND(COALESCE(e.admin_fee_expected, 0.00) - out.admin_fee_paid, 6) AS "Administrative Fee Outstanding",
  ROUND(COALESCE(e.interest_difference_expected, 0.00) - out.interest_difference_paid, 6) AS "Interest Difference Outstanding",
  ROUND(COALESCE(e.senior_principal_expected, 0.00) - out.senior_principal_paid, 6) AS "Senior Principal Outstanding",
  ROUND(COALESCE(e.senior_interest_expected, 0.00) - out.senior_interest_paid, 6) AS "Senior Interest Outstanding",
  ROUND(COALESCE(e.junior_principal_expected, 0.00) - out.junior_principal_paid, 6) AS "Junior Principal Outstanding",
  ROUND(COALESCE(e.junior_interest_expected, 0.00) - out.junior_interest_paid, 6) AS "Junior Interest Outstanding"

FROM sku_universe u
LEFT JOIN inflow_metrics inf ON inf.sku_id = u.sku_id
LEFT JOIN outflow_metrics out ON out.sku_id = u.sku_id
LEFT JOIN expected_values e ON e.sku_id = u.sku_id
ORDER BY u.sku_id;
