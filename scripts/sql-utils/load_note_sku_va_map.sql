  BEGIN;
    CREATE TEMP TABLE tmp_note_sku_va_map (
      note_id   text,
      sku_id    text,
      va_number text
    ) ON COMMIT DROP;

    \copy tmp_note_sku_va_map(note_id, sku_id, va_number) FROM '__CSV_PATH__' WITH (FORMAT csv, HEADER true);

    CREATE TEMP TABLE tmp_validated ON COMMIT DROP AS
    SELECT
      NULLIF(TRIM(t.note_id),'') AS note_id,
      TRIM(t.sku_id)             AS sku_id,
      TRIM(t.va_number)          AS va_number,
      m.merchant_id
    FROM tmp_note_sku_va_map t
    LEFT JOIN (
      SELECT DISTINCT TRIM(sku_id) AS sku_id, TRIM(merchant) AS merchant_name
      FROM raw.repmt_sales
      WHERE sku_id IS NOT NULL AND TRIM(sku_id) <> ''
    ) src ON src.sku_id = TRIM(t.sku_id)
    LEFT JOIN ref.merchant m ON lower(m.merchant_name) = lower(src.merchant_name)
    WHERE TRIM(t.sku_id) IS NOT NULL AND TRIM(t.sku_id) <> ''
      AND TRIM(t.va_number) IS NOT NULL AND TRIM(t.va_number) <> '';

    INSERT INTO ref.sku (sku_id, merchant_id)
    SELECT sku_id, merchant_id
    FROM (
      SELECT DISTINCT sku_id, merchant_id FROM tmp_validated
      WHERE merchant_id IS NOT NULL
    ) s
    ON CONFLICT (sku_id) DO UPDATE SET merchant_id = EXCLUDED.merchant_id;

    DELETE FROM ref.note_sku_va_map
    WHERE sku_id IN (SELECT sku_id FROM tmp_validated);

    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM tmp_validated WHERE merchant_id IS NULL) THEN
        RAISE EXCEPTION 'Missing merchant mapping for one or more SKUs in note_sku_va_map_prepped.csv';
      END IF;
    END $$;

    INSERT INTO ref.note_sku_va_map (note_id, sku_id, va_number, merchant_id)
    SELECT
      note_id,
      sku_id,
      va_number,
      merchant_id
    FROM tmp_validated
    ON CONFLICT (coalesce(note_id,''), coalesce(va_number,''), coalesce(sku_id,''))
    DO UPDATE SET merchant_id = EXCLUDED.merchant_id;

    SELECT COUNT(*) AS mappings_loaded,
           COUNT(DISTINCT sku_id) AS distinct_skus
    FROM ref.note_sku_va_map;
  COMMIT;
