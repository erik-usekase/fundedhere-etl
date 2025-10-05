DO $$
DECLARE
  lvl_pulled numeric;
  raw_pulled numeric;
  lvl_received numeric;
  raw_received numeric;
  lvl_sales numeric;
  raw_sales numeric;
BEGIN
  SELECT SUM("Amount Pulled") INTO lvl_pulled FROM mart.v_level1;

  SELECT SUM(e.buy_amount) INTO raw_pulled
  FROM core.mv_external_accounts e
  JOIN ref.note_sku_va_map n ON n.va_number = e.va_number;

  IF ABS(COALESCE(lvl_pulled,0) - COALESCE(raw_pulled,0)) > 0.01 THEN
    RAISE EXCEPTION 'Level 1 pulled total mismatch: mart=%, raw=%', lvl_pulled, raw_pulled;
  END IF;

  SELECT SUM("Amount Received") INTO lvl_received FROM mart.v_level1;

  SELECT SUM(CASE WHEN category_code = 'merchant_repayment' AND direction='inflow'
                  THEN signed_amount ELSE 0 END)
    INTO raw_received
  FROM core.mv_va_txn_flows;

  IF ABS(COALESCE(lvl_received,0) - COALESCE(raw_received,0)) > 0.01 THEN
    RAISE EXCEPTION 'Level 1 received total mismatch: mart=%, raw=%', lvl_received, raw_received;
  END IF;

  SELECT SUM(sales_per_sku) INTO lvl_sales
  FROM (
    SELECT "SKU ID", MAX("Sales Proceeds") AS sales_per_sku
    FROM mart.v_level1
    GROUP BY 1
  ) t;

  SELECT SUM(s.sales_proceeds) INTO raw_sales
  FROM core.mv_repmt_sales s;

  IF ABS(COALESCE(lvl_sales,0) - COALESCE(raw_sales,0)) > 0.01 THEN
    RAISE EXCEPTION 'Level 1 sales total mismatch: mart=%, raw=%', lvl_sales, raw_sales;
  END IF;
END $$;
