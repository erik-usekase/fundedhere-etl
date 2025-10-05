DO $$
DECLARE
  expected_cnt int;
  mapped_cnt int;
BEGIN
  SELECT COUNT(DISTINCT sku_id) INTO expected_cnt FROM core.mv_repmt_sales;
  SELECT COUNT(DISTINCT sku_id) INTO mapped_cnt FROM ref.note_sku_va_map;

  IF mapped_cnt <> expected_cnt THEN
    RAISE EXCEPTION 'note_sku_va_map coverage mismatch: mapped=% missing=%', mapped_cnt, expected_cnt - mapped_cnt;
  END IF;
END $$;
