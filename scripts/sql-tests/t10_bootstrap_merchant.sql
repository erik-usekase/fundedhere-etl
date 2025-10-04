-- scripts/sql-tests/t10_bootstrap_merchant.sql
INSERT INTO ref.merchant(merchant_name)
VALUES ('ABC Sdn Bhd')
ON CONFLICT DO NOTHING;

-- show merchant_id (for reference)
SELECT merchant_id, merchant_name FROM ref.merchant WHERE merchant_name='ABC Sdn Bhd';
