WITH m AS (
  SELECT * FROM ref.note_sku_va_map ORDER BY va_number
),
ext AS (
  SELECT DISTINCT va_number FROM core.mv_external_accounts
),
hit AS (
  SELECT m.*, (m.va_number IN (SELECT va_number FROM ext)) AS exists_in_external
  FROM m
)
SELECT * FROM hit ORDER BY va_number;
