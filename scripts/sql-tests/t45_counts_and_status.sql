-- scripts/sql-tests/t45_counts_and_status.sql
-- Raw counts and basic chain status
SELECT 'external_accounts' AS tbl, COUNT(*) AS cnt FROM raw.external_accounts
UNION ALL SELECT 'va_txn', COUNT(*) FROM raw.va_txn
UNION ALL SELECT 'repmt_sku', COUNT(*) FROM raw.repmt_sku
UNION ALL SELECT 'repmt_sales', COUNT(*) FROM raw.repmt_sales
ORDER BY tbl;

-- How many rows in Level1 (if view exists)
DO $$BEGIN
IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='mart' AND table_name='v_level1') THEN
  RAISE NOTICE 'Level1 rows: %', (SELECT COUNT(*) FROM mart.v_level1);
ELSE
  RAISE NOTICE 'Level1 view not found';
END IF;
END$$;
