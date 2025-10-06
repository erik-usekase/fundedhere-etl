INSERT INTO ref.merchant (merchant_name)
SELECT DISTINCT TRIM(merchant) AS merchant_name
FROM raw.repmt_sales
WHERE merchant IS NOT NULL AND TRIM(merchant) <> ''
ON CONFLICT (merchant_name) DO NOTHING;

SELECT COUNT(*) AS ref_merchants FROM ref.merchant;
