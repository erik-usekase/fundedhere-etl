DO $$
DECLARE
  raw_cnt int;
  lvl1_cnt int;
  lvl2_cnt int;
  lvl2b_cnt int;
BEGIN
  SELECT COUNT(DISTINCT sku_id) INTO raw_cnt FROM core.mv_repmt_sales;
  SELECT COUNT(DISTINCT sku_id) INTO lvl1_cnt FROM mart.v_level1;

  PERFORM 1 FROM information_schema.columns
  WHERE table_schema = 'mart' AND table_name = 'v_level2a' AND column_name = 'sku_id';
  IF FOUND THEN
    EXECUTE 'SELECT COUNT(DISTINCT sku_id) FROM mart.v_level2a' INTO lvl2_cnt;
  ELSE
    EXECUTE 'SELECT COUNT(DISTINCT "SKU ID") FROM mart.v_level2a' INTO lvl2_cnt;
  END IF;

  PERFORM 1 FROM information_schema.columns
  WHERE table_schema = 'mart' AND table_name = 'v_level2b' AND column_name = 'sku_id';
  IF FOUND THEN
    EXECUTE 'SELECT COUNT(DISTINCT sku_id) FROM mart.v_level2b' INTO lvl2b_cnt;
  ELSE
    EXECUTE 'SELECT COUNT(DISTINCT "SKU ID") FROM mart.v_level2b' INTO lvl2b_cnt;
  END IF;

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
