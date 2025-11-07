-- Verify view structure matches Excel workbook (column counts)
-- Sheet 1: 8 columns
-- Sheet 2a: 49 columns (includes Expected, Paid, Outstanding breakdown)
-- Sheet 2b: 32 columns (includes UI vs CF reconciliation)

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
  49,
  CASE WHEN COUNT(*) = 49 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM information_schema.columns
WHERE table_schema = 'mart' AND table_name = 'v_level2a'

UNION ALL

SELECT
  'v_level2b',
  COUNT(*),
  32,
  CASE WHEN COUNT(*) = 32 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM information_schema.columns
WHERE table_schema = 'mart' AND table_name = 'v_level2b';
