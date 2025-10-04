INSERT INTO ref.remarks_category_map(raw_pattern,category_code,is_regex,priority)
VALUES ('merchant repayment','merchant_repayment',false,10)
ON CONFLICT DO NOTHING;
SELECT * FROM ref.remarks_category_map ORDER BY priority, raw_pattern;
