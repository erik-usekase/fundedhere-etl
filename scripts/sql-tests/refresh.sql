-- scripts/sql-tests/refresh.sql
SET datestyle = 'ISO, MDY';

DO $$
BEGIN
  -- Call core.refresh_all() if present; otherwise refresh MVs directly.
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='core' AND p.proname='refresh_all'
  ) THEN
    PERFORM core.refresh_all();
  ELSE
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_external_accounts') THEN
      REFRESH MATERIALIZED VIEW core.mv_external_accounts;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_repmt_sku') THEN
      REFRESH MATERIALIZED VIEW core.mv_repmt_sku;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_repmt_sales') THEN
      REFRESH MATERIALIZED VIEW core.mv_repmt_sales;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_va_txn_flows') THEN
      REFRESH MATERIALIZED VIEW core.mv_va_txn_flows;
    END IF;
  END IF;
END$$;
