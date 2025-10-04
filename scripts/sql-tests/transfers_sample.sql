-- scripts/sql-tests/transfers_sample.sql
SELECT
  from_sku_id      AS sku_from,
  to_sku_id        AS sku_to,
  amount,
  occurred_at_utc,
  period_ym
FROM core.v_inter_sku_transfers
ORDER BY occurred_at_utc DESC
LIMIT 50;
