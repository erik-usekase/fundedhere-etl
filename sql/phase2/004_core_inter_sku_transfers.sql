-- sql/phase2/004_core_inter_sku_transfers.sql
SET search_path = core, public;

CREATE OR REPLACE VIEW core.v_inter_sku_transfers AS
WITH t AS (
  SELECT
    v.sender_virtual_account_number   AS sender_va,
    v.receiver_virtual_account_number AS receiver_va,
    core.to_numeric_safe(v.amount)    AS amount,
    core.to_tstz_safe(v.date)         AS occurred_at_utc
  FROM raw.va_txn v
),
m AS (
  SELECT
    t.*,
    s.sku_id        AS from_sku_id,
    s.merchant_id   AS from_merchant_id,
    r.sku_id        AS to_sku_id,
    r.merchant_id   AS to_merchant_id
  FROM t
  LEFT JOIN ref.note_sku_va_map s ON s.va_number = t.sender_va
  LEFT JOIN ref.note_sku_va_map r ON r.va_number = t.receiver_va
)
SELECT
  m.*,
  to_char(m.occurred_at_utc::date,'YYYY-MM') AS period_ym
FROM m
WHERE from_sku_id IS NOT NULL
  AND to_sku_id   IS NOT NULL
  AND from_sku_id <> to_sku_id;

CREATE OR REPLACE VIEW core.v_inter_sku_transfers_agg AS
WITH base AS (SELECT * FROM core.v_inter_sku_transfers)
SELECT
  x.sku_id,
  x.merchant_id,
  SUM(x.out_amt) AS transfer_out_to_other_sku,
  SUM(x.in_amt)  AS transfer_in_from_other_sku
FROM (
  SELECT
    from_sku_id AS sku_id,
    from_merchant_id AS merchant_id,
    amount AS out_amt,
    0::numeric AS in_amt
  FROM base
  UNION ALL
  SELECT
    to_sku_id AS sku_id,
    to_merchant_id AS merchant_id,
    0::numeric AS out_amt,
    amount AS in_amt
  FROM base
) x
GROUP BY 1,2;
