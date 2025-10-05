BEGIN;
  CREATE TEMP TABLE tmp_note_sku_va_map (
    note_id   text,
    sku_id    text,
    va_number text
  ) ON COMMIT DROP;

  \copy tmp_note_sku_va_map(note_id, sku_id, va_number) FROM '__CSV_PATH__' WITH (FORMAT csv, HEADER true);

  WITH sku_source AS (
    SELECT DISTINCT s.sku_id, s.merchant_name
    FROM core.mv_repmt_sales s
    WHERE s.sku_id IS NOT NULL AND s.sku_id <> ''
  )
  INSERT INTO ref.sku (sku_id, merchant_id)
  SELECT t.sku_id, m.merchant_id
  FROM tmp_note_sku_va_map t
  JOIN sku_source src ON src.sku_id = t.sku_id
  JOIN ref.merchant m ON lower(m.merchant_name) = lower(src.merchant_name)
  ON CONFLICT (sku_id) DO NOTHING;

  -- Remove existing rows for these SKUs to avoid stale mappings before reload
  DELETE FROM ref.note_sku_va_map
  WHERE sku_id IN (SELECT sku_id FROM tmp_note_sku_va_map);

  INSERT INTO ref.note_sku_va_map (note_id, sku_id, va_number, merchant_id)
  SELECT
    NULLIF(t.note_id,''),
    t.sku_id,
    t.va_number,
    s.merchant_id
  FROM tmp_note_sku_va_map t
  JOIN ref.sku s ON s.sku_id = t.sku_id
  ON CONFLICT (coalesce(note_id,''), coalesce(va_number,''), coalesce(sku_id,''))
  DO UPDATE SET merchant_id = EXCLUDED.merchant_id;

  SELECT COUNT(*) AS mappings_loaded,
         COUNT(DISTINCT sku_id) AS distinct_skus
  FROM ref.note_sku_va_map;
COMMIT;
