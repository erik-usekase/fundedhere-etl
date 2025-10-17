-- sql/phase2/020_mart_level2.sql (DEFINITIVE FINAL VERSION)
SET search_path = mart, public;

-- START of v_level2a definition
CREATE OR REPLACE VIEW mart.v_level2a AS
WITH paid AS (
  SELECT
    sku_id,
    merchant_id,
    COALESCE(amount_received, 0) AS amount_received,
    COALESCE(management_fee_paid, 0) AS management_fee_paid,
    COALESCE(admin_fee_paid, 0) AS admin_fee_paid,
    COALESCE(additional_admin_fee_paid, 0) AS additional_admin_fee_paid,
    COALESCE(interest_difference_paid, 0) AS interest_difference_paid,
    COALESCE(sr_principal_paid, 0) AS sr_principal_paid,
    COALESCE(sr_interest_paid, 0) AS sr_interest_paid,
    COALESCE(sr_add_interest_paid, 0) AS sr_add_interest_paid,
    COALESCE(jr_principal_paid, 0) AS jr_principal_paid,
    COALESCE(jr_interest_paid, 0) AS jr_interest_paid,
    COALESCE(jr_add_interest_paid, 0) AS jr_add_interest_paid,
    COALESCE(spar_paid, 0) AS spar_paid
  FROM core.v_flows_pivot
),
expected_raw AS (
  SELECT
    s.sku_id,
    k.merchant_id,
    s.acquirer_fees_expected AS management_fee_expected,
    s.fh_admin_fees_expected AS admin_fee_expected,
    s.additional_admin_fee_expected,
    s.int_difference_expected AS interest_difference_expected,
    s.sr_principal_expected AS sr_principal_expected,
    s.sr_interest_expected AS sr_interest_expected,
    s.sr_add_interest_expected,
    s.jr_principal_expected AS jr_principal_expected,
    s.jr_interest_expected AS jr_interest_expected,
    s.jr_add_interest_expected,
    s.spar_merchant AS spar_expected
  FROM core.mv_repmt_sku s
  JOIN ref.sku k ON k.sku_id = s.sku_id
),
expected AS (
  SELECT
    sku_id,
    merchant_id,
    COALESCE(SUM(management_fee_expected),0) AS management_fee_expected,
    COALESCE(SUM(admin_fee_expected),0) AS admin_fee_expected,
    COALESCE(SUM(additional_admin_fee_expected),0) AS additional_admin_fee_expected,
    COALESCE(SUM(interest_difference_expected),0) AS interest_difference_expected,
    COALESCE(SUM(sr_principal_expected),0) AS sr_principal_expected,
    COALESCE(SUM(sr_interest_expected),0) AS sr_interest_expected,
    COALESCE(SUM(sr_add_interest_expected),0) AS sr_add_interest_expected,
    COALESCE(SUM(jr_principal_expected),0) AS jr_principal_expected,
    COALESCE(SUM(jr_interest_expected),0) AS jr_interest_expected,
    COALESCE(SUM(jr_add_interest_expected),0) AS jr_add_interest_expected,
    COALESCE(SUM(spar_expected),0) AS spar_expected
  FROM expected_raw
  GROUP BY 1,2
),
inflow_sources AS (
    SELECT
        s.sku_id,
        COALESCE(SUM(s.sales_proceeds), 0) AS sales_proceeds,
        COALESCE(SUM(s.merchant_top_up), 0) AS merchant_top_up,
        COALESCE(SUM(s.disbursement_surplus), 0) AS disbursement_surplus
    FROM core.mv_repmt_sales s
    GROUP BY 1
),
joined AS (
  SELECT
    COALESCE(p.sku_id, e.sku_id) AS sku_id,
    COALESCE(p.merchant_id, e.merchant_id) AS merchant_id,
    p.amount_received,
    p.management_fee_paid, p.admin_fee_paid, p.additional_admin_fee_paid, p.interest_difference_paid,
    p.sr_principal_paid, p.sr_interest_paid, p.sr_add_interest_paid, p.jr_principal_paid, p.jr_interest_paid, p.jr_add_interest_paid, p.spar_paid,
    e.management_fee_expected, e.admin_fee_expected, e.additional_admin_fee_expected, e.interest_difference_expected,
    e.sr_principal_expected, e.sr_interest_expected, e.sr_add_interest_expected, e.jr_principal_expected, e.jr_interest_expected, e.jr_add_interest_expected, e.spar_expected,
    COALESCE(i.sales_proceeds, 0) as sales_proceeds,
    COALESCE(i.merchant_top_up, 0) as merchant_top_up,
    COALESCE(i.disbursement_surplus, 0) as disbursement_surplus
  FROM paid p
  FULL OUTER JOIN expected e ON e.sku_id = p.sku_id AND e.merchant_id = p.merchant_id
  LEFT JOIN inflow_sources i ON i.sku_id = COALESCE(p.sku_id, e.sku_id)
),
final_calcs AS (
    SELECT
        j.*,
        (j.management_fee_paid + j.admin_fee_paid + j.additional_admin_fee_paid + j.interest_difference_paid + j.sr_principal_paid + j.sr_interest_paid + j.sr_add_interest_paid + j.jr_principal_paid + j.jr_interest_paid + j.jr_add_interest_paid + j.spar_paid) AS amount_distributed,
        COALESCE(tx.transfer_out_to_other_sku,0) AS fund_transferred_to_other_sku,
        COALESCE(tx.transfer_in_from_other_sku,0) AS fund_transferred_from_other_sku
    FROM joined j
    LEFT JOIN core.v_inter_sku_transfers_agg tx
      ON tx.sku_id = j.sku_id AND tx.merchant_id = j.merchant_id
)
SELECT
  fc.sku_id AS "SKU ID",
  mr.merchant_name AS "Merchant",
  fc.amount_received AS "Amount Received",
  fc.amount_distributed AS "Amount Distributed Down the Repayment Waterfall",
  fc.fund_transferred_to_other_sku AS "Fund Transferred to Other SKU",
  (fc.amount_received + fc.fund_transferred_from_other_sku - fc.amount_distributed - fc.fund_transferred_to_other_sku) AS "Variance",

  -- Amount Paid > Amount Expected Flags
  CASE WHEN fc.management_fee_paid > fc.management_fee_expected THEN 'Yes' ELSE 'No' END AS "Mgmt Fee Paid > Expected?",
  CASE WHEN fc.admin_fee_paid > fc.admin_fee_expected THEN 'Yes' ELSE 'No' END AS "Admin Fee Paid > Expected?",
  CASE WHEN fc.interest_difference_paid > fc.interest_difference_expected THEN 'Yes' ELSE 'No' END AS "Int Diff Paid > Expected?",
  CASE WHEN fc.sr_principal_paid > fc.sr_principal_expected THEN 'Yes' ELSE 'No' END AS "Sr Principal Paid > Expected?",
  CASE WHEN fc.sr_interest_paid > fc.sr_interest_expected THEN 'Yes' ELSE 'No' END AS "Sr Interest Paid > Expected?",
  CASE WHEN fc.jr_principal_paid > fc.jr_principal_expected THEN 'Yes' ELSE 'No' END AS "Jr Principal Paid > Expected?",
  CASE WHEN fc.jr_interest_paid > fc.jr_interest_expected THEN 'Yes' ELSE 'No' END AS "Jr Interest Paid > Expected?",

  -- Fully Settled Flags
  CASE WHEN (fc.management_fee_expected - fc.management_fee_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Mgmt Fee Settled?",
  CASE WHEN (fc.admin_fee_expected - fc.admin_fee_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Admin Fee Settled?",
  CASE WHEN (fc.interest_difference_expected - fc.interest_difference_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Int Diff Settled?",
  CASE WHEN (fc.sr_principal_expected - fc.sr_principal_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Sr Principal Settled?",
  CASE WHEN (fc.sr_interest_expected - fc.sr_interest_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Sr Interest Settled?",
  CASE WHEN (fc.jr_principal_expected - fc.jr_principal_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Jr Principal Settled?",
  CASE WHEN (fc.jr_interest_expected - fc.jr_interest_paid) <= 0 THEN 'Yes' ELSE 'No' END AS "Jr Interest Settled?",

  -- Amount Received Breakdown
  fc.sales_proceeds AS "Sales Proceeds",
  fc.merchant_top_up AS "Merchant Top Up",
  fc.disbursement_surplus AS "Disbursement Surplus",
  fc.fund_transferred_from_other_sku AS "Fund Transferred from Other SKU",
  (fc.amount_received - fc.sales_proceeds - fc.merchant_top_up - fc.disbursement_surplus) AS "Other",

  -- Paid Amounts
  fc.management_fee_paid AS "Management Fee Paid",
  fc.admin_fee_paid AS "Administrative Fee Paid",
  fc.additional_admin_fee_paid AS "Additional Administrative Fee Paid",
  fc.interest_difference_paid AS "Interest Difference Paid",
  fc.sr_principal_paid AS "Senior Principal Paid",
  fc.sr_interest_paid AS "Senior Interest Paid",
  fc.sr_add_interest_paid AS "Senior Additional Interest Paid",
  fc.jr_principal_paid AS "Junior Principal Paid",
  fc.jr_interest_paid AS "Junior Interest Paid",
  fc.jr_add_interest_paid AS "Junior Additional Interest Paid",
  fc.spar_paid AS "SPAR Paid",

  -- Expected Amounts
  fc.management_fee_expected AS "Management Fee Expected",
  fc.admin_fee_expected AS "Administrative Fee Expected",
  fc.additional_admin_fee_expected AS "Additional Administrative Fee Expected",
  fc.interest_difference_expected AS "Interest Difference Expected",
  fc.sr_principal_expected AS "Senior Principal Expected",
  fc.sr_interest_expected AS "Senior Interest Expected",
  fc.sr_add_interest_expected AS "Senior Additional Interest Expected",
  fc.jr_principal_expected AS "Junior Principal Expected",
  fc.jr_interest_expected AS "Junior Interest Expected",
  fc.jr_add_interest_expected AS "Junior Additional Interest Expected",
  fc.spar_expected AS "SPAR Expected",

  -- Outstanding Amounts
  (fc.management_fee_expected - fc.management_fee_paid) AS "Management Fee Outstanding",
  (fc.admin_fee_expected - fc.admin_fee_paid) AS "Administrative Fee Outstanding",
  (fc.additional_admin_fee_expected - fc.additional_admin_fee_paid) AS "Additional Administrative Fee Outstanding",
  (fc.interest_difference_expected - fc.interest_difference_paid) AS "Interest Difference Outstanding",
  (fc.sr_principal_expected - fc.sr_principal_paid) AS "Senior Principal Outstanding",
  (fc.sr_interest_expected - fc.sr_interest_paid) AS "Senior Interest Outstanding",
  (fc.sr_add_interest_expected - fc.sr_add_interest_paid) AS "Senior Additional Interest Outstanding",
  (fc.jr_principal_expected - fc.jr_principal_paid) AS "Junior Principal Outstanding",
  (fc.jr_interest_expected - fc.jr_interest_paid) AS "Junior Interest Outstanding",
  (fc.jr_add_interest_expected - fc.jr_add_interest_paid) AS "Junior Additional Interest Outstanding",
  (fc.spar_expected - fc.spar_paid) AS "SPAR Outstanding"

FROM final_calcs fc
LEFT JOIN ref.merchant mr ON mr.merchant_id = fc.merchant_id
ORDER BY fc.sku_id;
-- END of v_level2a definition


-- START of v_level2b definition
CREATE OR REPLACE VIEW mart.v_level2b AS
WITH ui_sales AS (
  SELECT
    s.sku_id,
    COALESCE(SUM(s.total_funds_inflow), 0::numeric) AS total_fund_inflow_ui
  FROM core.mv_repmt_sales s
  GROUP BY 1
),
ui_paid AS (
  SELECT
    s.sku_id,
    COALESCE(SUM(s.acquirer_fees_paid), 0::numeric) AS management_fee_ui,
    COALESCE(SUM(s.fh_admin_fees_paid), 0::numeric) AS admin_fee_ui,
    COALESCE(SUM(s.int_difference_paid), 0::numeric) AS interest_difference_ui,
    COALESCE(SUM(s.sr_principal_paid), 0::numeric) AS sr_principal_ui,
    COALESCE(SUM(s.sr_interest_paid), 0::numeric) AS sr_interest_ui,
    COALESCE(SUM(s.jr_principal_paid), 0::numeric) AS jr_principal_ui,
    COALESCE(SUM(s.jr_interest_paid), 0::numeric) AS jr_interest_ui,
    COALESCE(SUM(s.spar_merchant), 0::numeric) AS spar_ui,
    COALESCE(SUM(s.additional_interests_paid_to_fh), 0::numeric) AS fh_platform_ui
  FROM core.mv_repmt_sku s
  GROUP BY 1
),
cf_paid AS (
  SELECT
    sku_id,
    COALESCE(amount_received, 0::numeric) AS amount_received_cf,
    COALESCE(management_fee_paid, 0::numeric) AS management_fee_cf,
    COALESCE(admin_fee_paid, 0::numeric) AS admin_fee_cf,
    COALESCE(interest_difference_paid, 0::numeric) AS interest_difference_cf,
    COALESCE(sr_principal_paid, 0::numeric) AS sr_principal_cf,
    COALESCE(sr_interest_paid, 0::numeric) AS sr_interest_cf,
    COALESCE(jr_principal_paid, 0::numeric) AS jr_principal_cf,
    COALESCE(jr_interest_paid, 0::numeric) AS jr_interest_cf,
    COALESCE(spar_paid, 0::numeric) AS spar_cf
  FROM core.v_flows_pivot
),
base AS (
  SELECT
    sku.sku_id,
    sku.merchant_id,
    m.merchant_name,
    COALESCE(us.total_fund_inflow_ui, 0::numeric) AS total_fund_inflow_ui,
    COALESCE(cf.amount_received_cf, 0::numeric) AS amount_received_cf,
    COALESCE(up.management_fee_ui, 0::numeric) AS management_fee_ui,
    COALESCE(cf.management_fee_cf, 0::numeric) AS management_fee_cf,
    COALESCE(up.admin_fee_ui, 0::numeric) AS admin_fee_ui,
    COALESCE(cf.admin_fee_cf, 0::numeric) AS admin_fee_cf,
    COALESCE(up.interest_difference_ui, 0::numeric) AS interest_difference_ui,
    COALESCE(cf.interest_difference_cf, 0::numeric) AS interest_difference_cf,
    COALESCE(up.sr_principal_ui, 0::numeric) AS sr_principal_ui,
    COALESCE(cf.sr_principal_cf, 0::numeric) AS sr_principal_cf,
    COALESCE(up.sr_interest_ui, 0::numeric) AS sr_interest_ui,
    COALESCE(cf.sr_interest_cf, 0::numeric) AS sr_interest_cf,
    COALESCE(up.jr_principal_ui, 0::numeric) AS jr_principal_ui,
    COALESCE(cf.jr_principal_cf, 0::numeric) AS jr_principal_cf,
    COALESCE(up.jr_interest_ui, 0::numeric) AS jr_interest_ui,
    COALESCE(cf.jr_interest_cf, 0::numeric) AS jr_interest_cf,
    COALESCE(up.spar_ui, 0::numeric) AS spar_ui,
    COALESCE(cf.spar_cf, 0::numeric) AS spar_cf,
    COALESCE(up.fh_platform_ui, 0::numeric) AS fh_platform_ui,
    (COALESCE(cf.sr_interest_cf, 0) + COALESCE(cf.jr_interest_cf, 0)) * 0.10 AS fh_platform_cf_calc
  FROM ref.sku sku
  JOIN ref.merchant m ON m.merchant_id = sku.merchant_id
  LEFT JOIN ui_sales us ON us.sku_id = sku.sku_id
  LEFT JOIN ui_paid up ON up.sku_id = sku.sku_id
  LEFT JOIN cf_paid cf ON cf.sku_id = sku.sku_id
)
SELECT
  b.sku_id AS "SKU ID",
  b.merchant_name AS "Merchant",
  b.amount_received_cf AS "Total Fund Inflow",
  b.management_fee_cf AS "Management Fee Paid",
  b.admin_fee_cf AS "Adminstrative Fee Paid",
  b.interest_difference_cf AS "Interest Difference Paid",
  b.sr_principal_cf AS "Senior Principal Paid",
  b.sr_interest_cf AS "Senior Interest Paid",
  b.jr_principal_cf AS "Junior Principal Paid",
  b.jr_interest_cf AS "Junior Interest Paid",
  b.spar_cf AS "SPAR",
  b.fh_platform_cf_calc AS "FH Platform Fee",

  -- Variance Columns
  (b.total_fund_inflow_ui - b.amount_received_cf) AS "Total Fund Inflow Variance",
  (b.management_fee_ui - b.management_fee_cf) AS "Management Fee Paid Variance",
  (b.admin_fee_ui - b.admin_fee_cf) AS "Administrative Fee Paid Variance",
  (b.interest_difference_ui - b.interest_difference_cf) AS "Interest Difference Paid Variance",
  (b.sr_principal_ui - b.sr_principal_cf) AS "Senior Principal Paid Variance",
  (b.sr_interest_ui - b.sr_interest_cf) AS "Senior Interest Paid Variance",
  (b.jr_principal_ui - b.jr_principal_cf) AS "Junior Principal Paid Variance",
  (b.jr_interest_ui - b.jr_interest_cf) AS "Junior Interest Paid Variance",
  (b.spar_ui - b.spar_cf) AS "SPAR Variance",
  (b.fh_platform_ui - b.fh_platform_cf_calc) AS "FH Platform Fee Variance",

  -- Comparison Columns
  b.management_fee_ui AS "Management Fee Paid (UI)",
  b.management_fee_cf AS "Management Fee Paid (CF)",
  b.admin_fee_ui AS "Administrative Fee Paid (UI)",
  b.admin_fee_cf AS "Administrative Fee Paid (CF)",
  b.interest_difference_ui AS "Interest Difference Paid (UI)",
  b.interest_difference_cf AS "Interest Difference Paid (CF)",
  b.sr_principal_ui AS "Senior Principal Paid (UI)",
  b.sr_principal_cf AS "Senior Principal Paid (CF)",
  b.sr_interest_ui AS "Senior Interest Paid (UI)",
  b.sr_interest_cf AS "Senior Interest Paid (CF)",
  b.jr_principal_ui AS "Junior Principal Paid (UI)",
  b.jr_principal_cf AS "Junior Principal Paid (CF)",
  b.jr_interest_ui AS "Junior Interest Paid (UI)",
  b.jr_interest_cf AS "Junior Interest Paid (CF)",
  b.spar_ui AS "SPAR (UI)",
  b.spar_cf AS "SPAR (CF)",
  b.fh_platform_ui AS "FH Platform Fee (UI)",
  b.fh_platform_cf_calc AS "FH Platform Fee (Calc.)",
  b.total_fund_inflow_ui AS "Total Fund Inflow (UI)",
  b.amount_received_cf AS "Amount Received (CF)"
FROM base b
ORDER BY b.sku_id;
-- END of v_level2b definition
