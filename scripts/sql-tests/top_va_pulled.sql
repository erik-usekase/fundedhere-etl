SELECT va_number, SUM(buy_amount) AS pulled
FROM core.mv_external_accounts
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
