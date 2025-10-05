-- sql/phase2/023_update_remarks_map.sql
set search_path = ref, public;

INSERT INTO remarks_category_map(raw_pattern, category_code, is_regex, priority)
VALUES
  ('acquirer-fee',              'mgmt_fee', false, 25),
  ('int-diff',                  'int_diff', false, 35),
  ('senior-investor-principal', 'sr_prin',  false, 40),
  ('senior-investor-interest',  'sr_int',   false, 40),
  ('junior-investor-principal', 'jr_prin',  false, 50),
  ('junior-investor-interest',  'jr_int',   false, 50)
ON CONFLICT DO NOTHING;
