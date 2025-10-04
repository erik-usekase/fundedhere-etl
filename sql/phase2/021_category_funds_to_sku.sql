-- sql/phase2/021_category_funds_to_sku.sql
-- Purpose: Introduce a dedicated category for internal transfers that route funds into a SKU VA,
--          preserving semantic clarity vs. direct 'merchant_repayment'.

SET search_path = ref, public;

-- Exact + regex variants commonly seen; keep priority near merchant_repayment (10–15)
-- so this wins before generic fallbacks but after any strict business-specific match.
INSERT INTO remarks_category_map(raw_pattern, category_code, is_regex, priority)
VALUES
  ('note-issued-transfer-to-sku', 'funds_to_sku', false, 12),
  ('transfer-to-sku',             'funds_to_sku', false, 12),
  ('transfer\s*to\s*sku',       'funds_to_sku', true,  12),
  ('note\s*issued\s*transfer\s*to\s*sku', 'funds_to_sku', true, 12)
ON CONFLICT DO NOTHING;

-- Tip: add more site-specific variants here as they appear in data (keep priority ~12).
