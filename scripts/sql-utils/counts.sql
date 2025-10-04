select 'external_accounts' as tbl, count(*) as cnt from raw.external_accounts
union all
select 'repmt_sales', count(*) from raw.repmt_sales
union all
select 'repmt_sku', count(*) from raw.repmt_sku
union all
select 'va_txn', count(*) from raw.va_txn
order by tbl;
