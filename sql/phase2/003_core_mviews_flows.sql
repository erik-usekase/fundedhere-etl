-- sql/phase2/003_core_mviews_flows.sql
SET search_path = core, public;

-- Recreate flows MV and base pivot. (022_update_flows_pivot.sql will override the pivot.)
DROP MATERIALIZED VIEW IF EXISTS core.mv_va_txn_flows;
DROP VIEW IF EXISTS core.v_flows_pivot;

CREATE MATERIALIZED VIEW core.mv_va_txn_flows AS
WITH typed AS (
  SELECT
    r.sender_virtual_account_number   AS sender_va,
    NULLIF(r.sender_note_id,'')       AS sender_note_id,
    r.receiver_virtual_account_number AS receiver_va,
    NULLIF(r.receiver_note_id,'')     AS receiver_note_id,
    core.to_numeric_safe(r.amount)    AS amount,
    core.to_tstz_safe(r.date)         AS occurred_at_utc,
    lower(btrim(coalesce(r.remarks,''))) AS remarks
  FROM raw.va_txn r
),
categorized AS (
  SELECT
    t.*,
    COALESCE(
      (SELECT m.category_code
       FROM ref.remarks_category_map m
       WHERE (CASE WHEN m.is_regex THEN t.remarks ~* m.raw_pattern ELSE t.remarks = lower(m.raw_pattern) END)
       ORDER BY m.priority ASC
       LIMIT 1),
    'uncategorized') AS category_code
  FROM typed t
),
recv_match AS (
  SELECT
    c.receiver_va  AS va_number,
    n.sku_id,
    n.merchant_id,
    c.category_code,
    'inflow'::text AS direction,
    c.amount,
    c.occurred_at_utc,
    c.remarks
  FROM categorized c
  JOIN ref.note_sku_va_map n
    ON n.va_number = c.receiver_va
),
send_match AS (
  SELECT
    c.sender_va    AS va_number,
    n.sku_id,
    n.merchant_id,
    c.category_code,
    'outflow'::text AS direction,
    c.amount,
    c.occurred_at_utc,
    c.remarks
  FROM categorized c
  JOIN ref.note_sku_va_map n
    ON n.va_number = c.sender_va
)
SELECT
  va_number,
  sku_id,
  merchant_id,
  category_code,
  direction,
  amount AS raw_amount,
  CASE WHEN direction = 'inflow' THEN amount ELSE -amount END AS signed_amount,
  occurred_at_utc,
  to_char(occurred_at_utc::date, 'YYYY-MM') AS period_ym,
  remarks
FROM recv_match
UNION ALL
SELECT
  va_number,
  sku_id,
  merchant_id,
  category_code,
  direction,
  amount AS raw_amount,
  CASE WHEN direction = 'inflow' THEN amount ELSE -amount END AS signed_amount,
  occurred_at_utc,
  to_char(occurred_at_utc::date, 'YYYY-MM') AS period_ym,
  remarks
FROM send_match
;

CREATE INDEX IF NOT EXISTS ix_mv_flows_sku     ON core.mv_va_txn_flows(sku_id);
CREATE INDEX IF NOT EXISTS ix_mv_flows_va      ON core.mv_va_txn_flows(va_number);
CREATE INDEX IF NOT EXISTS ix_mv_flows_cat     ON core.mv_va_txn_flows(category_code);
CREATE INDEX IF NOT EXISTS ix_mv_flows_dir     ON core.mv_va_txn_flows(direction);
CREATE INDEX IF NOT EXISTS ix_mv_flows_period  ON core.mv_va_txn_flows(period_ym);

-- Baseline pivot (will be replaced by 022_update_flows_pivot.sql)
CREATE OR REPLACE VIEW core.v_flows_pivot AS
SELECT
  sku_id,
  merchant_id,
  SUM(CASE WHEN category_code='merchant_repayment' AND direction='inflow'  THEN signed_amount ELSE 0 END) AS amount_received,
  SUM(CASE WHEN category_code='admin_fee'         AND direction='outflow' THEN -signed_amount ELSE 0 END) AS admin_fee_paid,
  SUM(CASE WHEN category_code='mgmt_fee'          AND direction='outflow' THEN -signed_amount ELSE 0 END) AS management_fee_paid,
  SUM(CASE WHEN category_code='int_diff'          AND direction='outflow' THEN -signed_amount ELSE 0 END) AS interest_difference_paid,
  SUM(CASE WHEN category_code='sr_prin'           AND direction='outflow' THEN -signed_amount ELSE 0 END) AS sr_principal_paid,
  SUM(CASE WHEN category_code='sr_int'            AND direction='outflow' THEN -signed_amount ELSE 0 END) AS sr_interest_paid,
  SUM(CASE WHEN category_code='jr_prin'           AND direction='outflow' THEN -signed_amount ELSE 0 END) AS jr_principal_paid,
  SUM(CASE WHEN category_code='jr_int'            AND direction='outflow' THEN -signed_amount ELSE 0 END) AS jr_interest_paid,
  SUM(CASE WHEN category_code='spar'              AND direction='outflow' THEN -signed_amount ELSE 0 END) AS spar_paid
FROM core.mv_va_txn_flows
GROUP BY 1,2;
