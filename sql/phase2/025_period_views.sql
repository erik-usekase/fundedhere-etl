-- sql/phase2/025_period_views.sql - Period-aware views for multi-period support
-- Enables filtering Level 1/2 views by specific date ranges or periods

SET search_path = mart, public;

-- Helper function to filter by period range
CREATE OR REPLACE FUNCTION mart.period_range(start_period text, end_period text DEFAULT NULL)
RETURNS TABLE(period_ym text) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT p.period_ym
  FROM (
    SELECT period_ym FROM core.mv_va_txn
    UNION
    SELECT period_ym FROM core.mv_external_accounts
  ) p
  WHERE p.period_ym >= start_period
    AND (end_period IS NULL OR p.period_ym <= end_period)
  ORDER BY p.period_ym;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION mart.period_range(text, text) IS
'Returns list of periods within range. Usage: SELECT * FROM mart.period_range(''2025-09'', ''2025-11'')';

-- Available periods view
CREATE OR REPLACE VIEW mart.v_available_periods AS
WITH all_periods AS (
  SELECT DISTINCT period_ym, 'external_accounts' AS source FROM core.mv_external_accounts WHERE period_ym IS NOT NULL
  UNION
  SELECT DISTINCT period_ym, 'va_txn' FROM core.mv_va_txn WHERE period_ym IS NOT NULL
  UNION
  SELECT DISTINCT to_char(load_at, 'YYYY-MM'), 'repmt_sku' FROM raw.repmt_sku
  UNION
  SELECT DISTINCT to_char(load_at, 'YYYY-MM'), 'repmt_sales' FROM raw.repmt_sales
)
SELECT
  period_ym AS "Period",
  COUNT(DISTINCT source) AS "Source Count",
  ARRAY_AGG(DISTINCT source ORDER BY source) AS "Sources"
FROM all_periods
GROUP BY period_ym
ORDER BY period_ym DESC;

COMMENT ON VIEW mart.v_available_periods IS
'Shows all available periods across all data sources';

-- Period-filtered Level 1 view
CREATE OR REPLACE VIEW mart.v_level1_by_period AS
SELECT
  l1.*,
  v.period_ym AS "Period"
FROM mart.v_level1 l1
LEFT JOIN LATERAL (
  SELECT DISTINCT period_ym
  FROM core.mv_va_txn
  WHERE sku_id = l1."SKU ID"
  LIMIT 1
) v ON TRUE
WHERE v.period_ym IS NOT NULL
ORDER BY v.period_ym DESC, l1."SKU ID";

COMMENT ON VIEW mart.v_level1_by_period IS
'Level 1 view with period column for filtering. Use WHERE "Period" = ''2025-09'' to filter by month.';

-- Data coverage summary by period
CREATE OR REPLACE VIEW mart.v_period_coverage AS
SELECT
  p.period_ym AS "Period",
  COUNT(DISTINCT ea.va_number) AS "External Account VAs",
  COUNT(DISTINCT vt.va_number) AS "VA Transaction VAs",
  COUNT(DISTINCT vt.sku_id) AS "VA Transaction SKUs",
  SUM(CASE WHEN ea.va_number IS NOT NULL THEN 1 ELSE 0 END) AS "External Records",
  SUM(CASE WHEN vt.va_number IS NOT NULL THEN 1 ELSE 0 END) AS "VA Txn Records"
FROM (
  SELECT DISTINCT period_ym FROM core.mv_external_accounts
  UNION
  SELECT DISTINCT period_ym FROM core.mv_va_txn
) p
LEFT JOIN core.mv_external_accounts ea ON ea.period_ym = p.period_ym
LEFT JOIN core.mv_va_txn vt ON vt.period_ym = p.period_ym
GROUP BY p.period_ym
ORDER BY p.period_ym DESC;

COMMENT ON VIEW mart.v_period_coverage IS
'Shows data coverage and record counts by period';

-- Latest period summary (most recent month)
CREATE OR REPLACE VIEW mart.v_latest_period AS
WITH latest AS (
  SELECT MAX(period_ym) AS period_ym FROM core.mv_va_txn
)
SELECT
  l1.*,
  v.period_ym AS "Period"
FROM mart.v_level1 l1
LEFT JOIN LATERAL (
  SELECT DISTINCT vt.period_ym
  FROM core.mv_va_txn vt, latest lat
  WHERE vt.sku_id = l1."SKU ID"
    AND vt.period_ym = lat.period_ym
  LIMIT 1
) v ON TRUE
WHERE v.period_ym IS NOT NULL
ORDER BY l1."SKU ID";

COMMENT ON VIEW mart.v_latest_period IS
'Level 1 view filtered to only the most recent period';

-- Period comparison view (compare two periods)
CREATE OR REPLACE FUNCTION mart.compare_periods(
  period1 text,
  period2 text
)
RETURNS TABLE(
  "SKU ID" text,
  "Merchant" text,
  "Period 1" text,
  "Period 1 Amount Received" numeric,
  "Period 1 Variance" numeric,
  "Period 2" text,
  "Period 2 Amount Received" numeric,
  "Period 2 Variance" numeric,
  "Change in Amount Received" numeric,
  "Change in Variance" numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH p1 AS (
    SELECT
      l1."SKU ID",
      l1."Merchant",
      l1."Amount Received",
      l1."Variance"
    FROM mart.v_level1 l1
    JOIN LATERAL (
      SELECT DISTINCT vt.period_ym
      FROM core.mv_va_txn vt
      WHERE vt.sku_id = l1."SKU ID"
        AND vt.period_ym = period1
      LIMIT 1
    ) v ON TRUE
  ),
  p2 AS (
    SELECT
      l1."SKU ID",
      l1."Merchant",
      l1."Amount Received",
      l1."Variance"
    FROM mart.v_level1 l1
    JOIN LATERAL (
      SELECT DISTINCT vt.period_ym
      FROM core.mv_va_txn vt
      WHERE vt.sku_id = l1."SKU ID"
        AND vt.period_ym = period2
      LIMIT 1
    ) v ON TRUE
  )
  SELECT
    COALESCE(p1."SKU ID", p2."SKU ID"),
    COALESCE(p1."Merchant", p2."Merchant"),
    period1,
    COALESCE(p1."Amount Received", 0),
    COALESCE(p1."Variance", 0),
    period2,
    COALESCE(p2."Amount Received", 0),
    COALESCE(p2."Variance", 0),
    COALESCE(p2."Amount Received", 0) - COALESCE(p1."Amount Received", 0),
    COALESCE(p2."Variance", 0) - COALESCE(p1."Variance", 0)
  FROM p1
  FULL OUTER JOIN p2 ON p1."SKU ID" = p2."SKU ID"
  ORDER BY COALESCE(p1."SKU ID", p2."SKU ID");
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION mart.compare_periods(text, text) IS
'Compare Level 1 metrics between two periods. Usage: SELECT * FROM mart.compare_periods(''2025-09'', ''2025-10'')';

-- Load tracking view
CREATE OR REPLACE VIEW mart.v_load_history AS
SELECT
  'external_accounts' AS "Table",
  source_file AS "Source File",
  COUNT(*) AS "Rows Loaded",
  MIN(load_at) AS "Load Time",
  MAX(load_at) - MIN(load_at) AS "Load Duration"
FROM raw.external_accounts
GROUP BY source_file
UNION ALL
SELECT
  'va_txn',
  source_file,
  COUNT(*),
  MIN(load_at),
  MAX(load_at) - MIN(load_at)
FROM raw.va_txn
GROUP BY source_file
UNION ALL
SELECT
  'repmt_sku',
  source_file,
  COUNT(*),
  MIN(load_at),
  MAX(load_at) - MIN(load_at)
FROM raw.repmt_sku
GROUP BY source_file
UNION ALL
SELECT
  'repmt_sales',
  source_file,
  COUNT(*),
  MIN(load_at),
  MAX(load_at) - MIN(load_at)
FROM raw.repmt_sales
GROUP BY source_file
ORDER BY "Load Time" DESC;

COMMENT ON VIEW mart.v_load_history IS
'Shows loading history with file names, row counts, and load times';
