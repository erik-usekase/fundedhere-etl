-- scripts/sql-tests/flows_after_option_b.sql
-- Purpose: Summarize the impact of Option B (should see funds_to_sku inflows counted).

SELECT sku_id, category_code, direction, COUNT(*) AS n, SUM(signed_amount) AS sum_signed
FROM core.mv_va_txn_flows
GROUP BY 1,2,3
ORDER BY 1,2,3;
