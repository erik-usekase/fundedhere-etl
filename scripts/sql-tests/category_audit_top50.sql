-- scripts/sql-tests/category_audit_top50.sql
-- Purpose: Help you find unmapped or mis-mapped remark variants quickly.

SELECT lower(remarks) AS remark, COUNT(*) AS n
FROM raw.va_txn
GROUP BY 1
ORDER BY 2 DESC
LIMIT 50;
