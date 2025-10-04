SELECT category_code, COUNT(*) 
FROM core.mv_va_txn
GROUP BY 1
ORDER BY 2 DESC;
