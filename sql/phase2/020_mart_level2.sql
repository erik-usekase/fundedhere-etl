-- sql/phase2/020_mart_level2.sql
SET search_path = mart, public;

CREATE OR REPLACE VIEW mart.v_level2a AS
WITH paid_raw AS (
  SELECT
    sku_id,
    merchant_id,
    amount_received,
    management_fee_paid,
    admin_fee_paid,
    interest_difference_paid,
    sr_principal_paid,
    sr_interest_paid,
    jr_principal_paid,
    jr_interest_paid,
    spar_paid
  FROM core.v_flows_pivot
),
paid AS (
  SELECT
    sku_id,
    merchant_id,
    COALESCE(SUM(amount_received),0)           AS amount_received,
    COALESCE(SUM(management_fee_paid),0)       AS management_fee_paid,
    COALESCE(SUM(admin_fee_paid),0)            AS admin_fee_paid,
    COALESCE(SUM(interest_difference_paid),0)  AS interest_difference_paid,
    COALESCE(SUM(sr_principal_paid),0)         AS sr_principal_paid,
    COALESCE(SUM(sr_interest_paid),0)          AS sr_interest_paid,
    COALESCE(SUM(jr_principal_paid),0)         AS jr_principal_paid,
    COALESCE(SUM(jr_interest_paid),0)          AS jr_interest_paid,
    COALESCE(SUM(spar_paid),0)                 AS spar_paid
  FROM paid_raw
  GROUP BY 1,2
),
expected_raw AS (
  SELECT
    s.sku_id,
    k.merchant_id,
    s.acquirer_fees_expected       AS management_fee_expected,
    s.fh_admin_fees_expected       AS admin_fee_expected,
    s.int_difference_expected      AS interest_difference_expected,
    s.sr_principal_expected        AS sr_principal_expected,
    s.sr_interest_expected         AS sr_interest_expected,
    s.jr_principal_expected        AS jr_principal_expected,
    s.jr_interest_expected         AS jr_interest_expected,
    s.spar_merchant                AS spar_expected
  FROM core.mv_repmt_sku s
  JOIN ref.sku k ON k.sku_id = s.sku_id
),
expected AS (
  SELECT
    sku_id,
    merchant_id,
    COALESCE(SUM(management_fee_expected),0)      AS management_fee_expected,
    COALESCE(SUM(admin_fee_expected),0)           AS admin_fee_expected,
    COALESCE(SUM(interest_difference_expected),0) AS interest_difference_expected,
    COALESCE(SUM(sr_principal_expected),0)        AS sr_principal_expected,
    COALESCE(SUM(sr_interest_expected),0)         AS sr_interest_expected,
    COALESCE(SUM(jr_principal_expected),0)        AS jr_principal_expected,
    COALESCE(SUM(jr_interest_expected),0)         AS jr_interest_expected,
    COALESCE(SUM(spar_expected),0)                AS spar_expected
  FROM expected_raw
  GROUP BY 1,2
),
joined AS (
  SELECT
    COALESCE(p.sku_id, e.sku_id)       AS sku_id,
    COALESCE(p.merchant_id, e.merchant_id) AS merchant_id,
    p.amount_received,
    p.management_fee_paid, p.admin_fee_paid, p.interest_difference_paid,
    p.sr_principal_paid, p.sr_interest_paid, p.jr_principal_paid, p.jr_interest_paid, p.spar_paid,
    e.management_fee_expected, e.admin_fee_expected, e.interest_difference_expected,
    e.sr_principal_expected, e.sr_interest_expected, e.jr_principal_expected, e.jr_interest_expected, e.spar_expected
  FROM paid p
  FULL OUTER JOIN expected e ON e.sku_id = p.sku_id AND e.merchant_id = p.merchant_id
)
SELECT
  j.sku_id                                AS "SKU ID",
  mr.merchant_name                         AS "Merchant",
  COALESCE(j.amount_received,0)            AS "Amount Received",
  COALESCE(j.management_fee_paid,0)        AS "Management Fee Paid",
  COALESCE(j.admin_fee_paid,0)             AS "Administrative Fee Paid",
  COALESCE(j.interest_difference_paid,0)   AS "Interest Difference Paid",
  COALESCE(j.sr_principal_paid,0)          AS "Senior Principal Paid",
  COALESCE(j.sr_interest_paid,0)           AS "Senior Interest Paid",
  COALESCE(j.jr_principal_paid,0)          AS "Junior Principal Paid",
  COALESCE(j.jr_interest_paid,0)           AS "Junior Interest Paid",
  COALESCE(j.spar_paid,0)                  AS "SPAR Paid",
  COALESCE(j.management_fee_paid,0)
  + COALESCE(j.admin_fee_paid,0)
  + COALESCE(j.interest_difference_paid,0)
  + COALESCE(j.sr_principal_paid,0)
  + COALESCE(j.sr_interest_paid,0)
  + COALESCE(j.jr_principal_paid,0)
  + COALESCE(j.jr_interest_paid,0)
  + COALESCE(j.spar_paid,0)                AS "Amount Distributed Down the Repayment Waterfall",
  COALESCE(j.management_fee_expected,0)    AS "Management Fee Expected",
  COALESCE(j.admin_fee_expected,0)         AS "Administrative Fee Expected",
  COALESCE(j.interest_difference_expected,0) AS "Interest Difference Expected",
  COALESCE(j.sr_principal_expected,0)      AS "Senior Principal Expected",
  COALESCE(j.sr_interest_expected,0)       AS "Senior Interest Expected",
  COALESCE(j.jr_principal_expected,0)      AS "Junior Principal Expected",
  COALESCE(j.jr_interest_expected,0)       AS "Junior Interest Expected",
  COALESCE(j.spar_expected,0)              AS "SPAR Expected",
  COALESCE(j.management_fee_expected,0)  - COALESCE(j.management_fee_paid,0)      AS "Management Fee Outstanding",
  COALESCE(j.admin_fee_expected,0)       - COALESCE(j.admin_fee_paid,0)           AS "Administrative Fee Outstanding",
  COALESCE(j.interest_difference_expected,0) - COALESCE(j.interest_difference_paid,0) AS "Interest Difference Outstanding",
  COALESCE(j.sr_principal_expected,0)    - COALESCE(j.sr_principal_paid,0)        AS "Senior Principal Outstanding",
  COALESCE(j.sr_interest_expected,0)     - COALESCE(j.sr_interest_paid,0)         AS "Senior Interest Outstanding",
  COALESCE(j.jr_principal_expected,0)    - COALESCE(j.jr_principal_paid,0)        AS "Junior Principal Outstanding",
  COALESCE(j.jr_interest_expected,0)     - COALESCE(j.jr_interest_paid,0)         AS "Junior Interest Outstanding",
  COALESCE(tx.transfer_out_to_other_sku,0) AS "Fund Transferred to Other SKU",
  COALESCE(tx.transfer_in_from_other_sku,0) AS "Fund Transferred from Other SKU"
FROM joined j
LEFT JOIN ref.merchant mr ON mr.merchant_id = j.merchant_id
LEFT JOIN core.v_inter_sku_transfers_agg tx
  ON tx.sku_id = j.sku_id AND tx.merchant_id = j.merchant_id
ORDER BY 1;

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
    COALESCE(SUM(s.acquirer_fees_paid), 0::numeric)      AS management_fee_ui,
    COALESCE(SUM(s.fh_admin_fees_paid), 0::numeric)      AS admin_fee_ui,
    COALESCE(SUM(s.int_difference_paid), 0::numeric)     AS interest_difference_ui,
    COALESCE(SUM(s.sr_principal_paid), 0::numeric)       AS sr_principal_ui,
    COALESCE(SUM(s.sr_interest_paid), 0::numeric)        AS sr_interest_ui,
    COALESCE(SUM(s.jr_principal_paid), 0::numeric)       AS jr_principal_ui,
    COALESCE(SUM(s.jr_interest_paid), 0::numeric)        AS jr_interest_ui,
    COALESCE(SUM(s.spar_merchant), 0::numeric)           AS spar_ui,
    COALESCE(SUM(s.additional_interests_paid_to_fh), 0::numeric) AS fh_platform_ui
  FROM core.mv_repmt_sku s
  GROUP BY 1
),
cf_paid AS (
  SELECT
    f.sku_id,
    COALESCE(SUM(f.amount_received), 0::numeric)           AS amount_received_cf,
    COALESCE(SUM(f.management_fee_paid), 0::numeric)       AS management_fee_cf,
    COALESCE(SUM(f.admin_fee_paid), 0::numeric)            AS admin_fee_cf,
    COALESCE(SUM(f.interest_difference_paid), 0::numeric)  AS interest_difference_cf,
    COALESCE(SUM(f.sr_principal_paid), 0::numeric)         AS sr_principal_cf,
    COALESCE(SUM(f.sr_interest_paid), 0::numeric)          AS sr_interest_cf,
    COALESCE(SUM(f.jr_principal_paid), 0::numeric)         AS jr_principal_cf,
    COALESCE(SUM(f.jr_interest_paid), 0::numeric)          AS jr_interest_cf,
    COALESCE(SUM(f.spar_paid), 0::numeric)                 AS spar_cf
  FROM core.v_flows_pivot f
  GROUP BY 1
),
base AS (
  SELECT
    sku.sku_id,
    sku.merchant_id,
    m.merchant_name,
    COALESCE(us.total_fund_inflow_ui, 0::numeric)   AS total_fund_inflow_ui,
    COALESCE(cf.amount_received_cf, 0::numeric)     AS amount_received_cf,
    COALESCE(up.management_fee_ui, 0::numeric)      AS management_fee_ui,
    COALESCE(cf.management_fee_cf, 0::numeric)      AS management_fee_cf,
    COALESCE(up.admin_fee_ui, 0::numeric)           AS admin_fee_ui,
    COALESCE(cf.admin_fee_cf, 0::numeric)           AS admin_fee_cf,
    COALESCE(up.interest_difference_ui, 0::numeric) AS interest_difference_ui,
    COALESCE(cf.interest_difference_cf, 0::numeric) AS interest_difference_cf,
    COALESCE(up.sr_principal_ui, 0::numeric)        AS sr_principal_ui,
    COALESCE(cf.sr_principal_cf, 0::numeric)        AS sr_principal_cf,
    COALESCE(up.sr_interest_ui, 0::numeric)         AS sr_interest_ui,
    COALESCE(cf.sr_interest_cf, 0::numeric)         AS sr_interest_cf,
    COALESCE(up.jr_principal_ui, 0::numeric)        AS jr_principal_ui,
    COALESCE(cf.jr_principal_cf, 0::numeric)        AS jr_principal_cf,
    COALESCE(up.jr_interest_ui, 0::numeric)         AS jr_interest_ui,
    COALESCE(cf.jr_interest_cf, 0::numeric)         AS jr_interest_cf,
    COALESCE(up.spar_ui, 0::numeric)                AS spar_ui,
    COALESCE(cf.spar_cf, 0::numeric)                AS spar_cf,
    COALESCE(up.fh_platform_ui, 0::numeric)         AS fh_platform_ui,
    0::numeric                                      AS fh_platform_cf
  FROM ref.sku sku
  JOIN ref.merchant m ON m.merchant_id = sku.merchant_id
  LEFT JOIN ui_sales us ON us.sku_id = sku.sku_id
  LEFT JOIN ui_paid up  ON up.sku_id = sku.sku_id
  LEFT JOIN cf_paid cf  ON cf.sku_id = sku.sku_id
)
SELECT
  b.sku_id                                      AS "SKU ID",
  b.merchant_name                               AS "Merchant",
  (b.total_fund_inflow_ui - b.amount_received_cf)              AS "Total Fund Inflow Variance",
  (b.management_fee_ui - b.management_fee_cf)                  AS "Management Fee Paid Variance",
  (b.admin_fee_ui - b.admin_fee_cf)                            AS "Administrative Fee Paid Variance",
  (b.interest_difference_ui - b.interest_difference_cf)        AS "Interest Difference Paid Variance",
  (b.sr_principal_ui - b.sr_principal_cf)                      AS "Senior Principal Paid Variance",
  (b.sr_interest_ui - b.sr_interest_cf)                        AS "Senior Interest Paid Variance",
  (b.jr_principal_ui - b.jr_principal_cf)                      AS "Junior Principal Paid Variance",
  (b.jr_interest_ui - b.jr_interest_cf)                        AS "Junior Interest Paid Variance",
  (b.spar_ui - b.spar_cf)                                      AS "SPAR Variance",
  (b.fh_platform_ui - b.fh_platform_cf)                        AS "FH Platform Fee Variance",
  b.management_fee_ui                                          AS "Management Fee Paid (UI)",
  b.management_fee_cf                                          AS "Management Fee Paid (CF)",
  b.admin_fee_ui                                               AS "Administrative Fee Paid (UI)",
  b.admin_fee_cf                                               AS "Administrative Fee Paid (CF)",
  b.interest_difference_ui                                     AS "Interest Difference Paid (UI)",
  b.interest_difference_cf                                     AS "Interest Difference Paid (CF)",
  b.sr_principal_ui                                            AS "Senior Principal Paid (UI)",
  b.sr_principal_cf                                            AS "Senior Principal Paid (CF)",
  b.sr_interest_ui                                             AS "Senior Interest Paid (UI)",
  b.sr_interest_cf                                             AS "Senior Interest Paid (CF)",
  b.jr_principal_ui                                            AS "Junior Principal Paid (UI)",
  b.jr_principal_cf                                            AS "Junior Principal Paid (CF)",
  b.jr_interest_ui                                             AS "Junior Interest Paid (UI)",
  b.jr_interest_cf                                             AS "Junior Interest Paid (CF)",
  b.spar_ui                                                    AS "SPAR (UI)",
  b.spar_cf                                                    AS "SPAR (CF)",
  b.fh_platform_ui                                             AS "FH Platform Fee (UI)",
  b.fh_platform_cf                                             AS "FH Platform Fee (CF)",
  b.total_fund_inflow_ui                                       AS "Total Fund Inflow (UI)",
  b.amount_received_cf                                         AS "Amount Received (CF)"
FROM base b
ORDER BY 1;
