INSERT INTO ref.merchant (merchant_name)
SELECT DISTINCT merchant_name
FROM core.mv_repmt_sales
WHERE merchant_name IS NOT NULL AND merchant_name <> ''
ON CONFLICT (merchant_name) DO NOTHING;

SELECT COUNT(*) AS ref_merchants FROM ref.merchant;
