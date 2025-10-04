-- scripts/sql-tests/t20_bootstrap_sku_and_map.sql
-- Insert SKU for the merchant (idempotent)
INSERT INTO ref.sku(sku_id, merchant_id)
SELECT 'NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR', m.merchant_id
FROM ref.merchant m
WHERE m.merchant_name='ABC Sdn Bhd'
ON CONFLICT DO NOTHING;

-- Map both VAs to that SKU (idempotent)
INSERT INTO ref.note_sku_va_map(note_id, sku_id, va_number, merchant_id)
SELECT v.note_id, v.sku_id, v.va_number, m.merchant_id
FROM (VALUES
  ('44','NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','8850633926172'),
  ('44','NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','8850633781134')
) AS v(note_id, sku_id, va_number)
CROSS JOIN (SELECT merchant_id FROM ref.merchant WHERE merchant_name='ABC Sdn Bhd') m
ON CONFLICT DO NOTHING;

-- Show mappings
SELECT * FROM ref.note_sku_va_map ORDER BY sku_id, va_number;
