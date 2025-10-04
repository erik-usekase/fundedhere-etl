SELECT sku_id, category_code, direction, COUNT(*) AS n, SUM(signed_amount) AS sum_signed
FROM core.mv_va_txn_flows
GROUP BY 1,2,3
ORDER BY 1,2,3;
