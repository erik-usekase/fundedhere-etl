-- sql/phase2/022_update_flows_pivot.sql
-- Purpose: Treat both direct merchant repayments and internal transfers to SKU as "amount_received".

SET search_path = core, public;

CREATE OR REPLACE VIEW core.v_flows_pivot AS
SELECT
  sku_id,
  merchant_id,
  -- Any inflow that lands in the SKU VA and is categorized as merchant_repayment or funds_to_sku
  SUM(CASE WHEN direction='inflow'
            AND category_code IN ('merchant_repayment','funds_to_sku')
           THEN signed_amount ELSE 0 END) AS amount_received,

  -- Outflow buckets (positive numbers; we flip signs here)
  SUM(CASE WHEN category_code='admin_fee'  AND direction='outflow' THEN -signed_amount ELSE 0 END) AS admin_fee_paid,
  SUM(CASE WHEN category_code='mgmt_fee'   AND direction='outflow' THEN -signed_amount ELSE 0 END) AS management_fee_paid,
  SUM(CASE WHEN category_code='int_diff'   AND direction='outflow' THEN -signed_amount ELSE 0 END) AS interest_difference_paid,
  SUM(CASE WHEN category_code='sr_prin'    AND direction='outflow' THEN -signed_amount ELSE 0 END) AS sr_principal_paid,
  SUM(CASE WHEN category_code='sr_int'     AND direction='outflow' THEN -signed_amount ELSE 0 END) AS sr_interest_paid,
  SUM(CASE WHEN category_code='jr_prin'    AND direction='outflow' THEN -signed_amount ELSE 0 END) AS jr_principal_paid,
  SUM(CASE WHEN category_code='jr_int'     AND direction='outflow' THEN -signed_amount ELSE 0 END) AS jr_interest_paid,
  SUM(CASE WHEN category_code='spar'       AND direction='outflow' THEN -signed_amount ELSE 0 END) AS spar_paid
FROM core.mv_va_txn_flows
GROUP BY 1,2;
