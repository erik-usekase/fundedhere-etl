-- Verify view structure (column counts)
SELECT 
  'v_level1' as view_name,
  COUNT(*) as actual_columns,
  8 as expected_columns,
  CASE WHEN COUNT(*) = 8 THEN '✓ PASS' ELSE '✗ FAIL' END as status
FROM information_schema.columns 
WHERE table_schema = 'mart' AND table_name = 'v_level1'

UNION ALL

SELECT 
  'v_level2a',
  COUNT(*),
  16,
  CASE WHEN COUNT(*) = 16 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM information_schema.columns 
WHERE table_schema = 'mart' AND table_name = 'v_level2a'

UNION ALL

SELECT 
  'v_level2b',
  COUNT(*),
  12,
  CASE WHEN COUNT(*) = 12 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM information_schema.columns 
WHERE table_schema = 'mart' AND table_name = 'v_level2b';
