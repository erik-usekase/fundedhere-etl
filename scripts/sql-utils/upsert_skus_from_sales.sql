-- Ensure ref.sku covers all SKUs present in the sales extract
INSERT INTO ref.sku (sku_id, merchant_id)
SELECT s.sku_id, m.merchant_id
FROM (
  SELECT DISTINCT sku_id, merchant_name
  FROM core.mv_repmt_sales
  WHERE sku_id IS NOT NULL AND sku_id <> ''
) s
JOIN ref.merchant m ON lower(m.merchant_name) = lower(s.merchant_name)
ON CONFLICT (sku_id) DO NOTHING;

-- Surface counts for observability
SELECT
  (SELECT COUNT(*) FROM ref.sku)    AS ref_sku_count,
  (SELECT COUNT(DISTINCT sku_id) FROM core.mv_repmt_sales) AS sales_sku_count;
