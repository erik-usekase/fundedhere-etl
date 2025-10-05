DO $$
DECLARE
  raw_cnt int;
  lvl1_cnt int;
  lvl2_cnt int;
  lvl2b_cnt int;
BEGIN
  SELECT COUNT(DISTINCT sku_id) INTO raw_cnt FROM core.mv_repmt_sales;
  SELECT COUNT(DISTINCT "SKU ID") INTO lvl1_cnt FROM mart.v_level1;
  SELECT COUNT(DISTINCT "SKU ID") INTO lvl2_cnt FROM mart.v_level2a;
  SELECT COUNT(DISTINCT "SKU ID") INTO lvl2b_cnt FROM mart.v_level2b;

  IF lvl1_cnt <> raw_cnt THEN
    RAISE EXCEPTION 'Level 1 row count mismatch: mart=% raw=%', lvl1_cnt, raw_cnt;
  END IF;

  IF lvl2_cnt <> raw_cnt THEN
    RAISE EXCEPTION 'Level 2 row count mismatch: mart=% raw=%', lvl2_cnt, raw_cnt;
  END IF;

  IF lvl2b_cnt <> raw_cnt THEN
    RAISE EXCEPTION 'Level 2b row count mismatch: mart=% raw=%', lvl2b_cnt, raw_cnt;
  END IF;
END $$;
