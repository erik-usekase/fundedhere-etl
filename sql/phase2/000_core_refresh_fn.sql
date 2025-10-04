-- sql/phase2/000_core_refresh_fn.sql
SET search_path = core, public;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'core') THEN
    EXECUTE 'CREATE SCHEMA core';
  END IF;
END$$;

CREATE OR REPLACE FUNCTION core.refresh_all()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Rebuild typed/business materialized views in a safe order.
  -- (No CONCURRENTLY since we haven't defined unique indexes on the MVs.)

  -- Basic inputs
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_external_accounts') THEN
    REFRESH MATERIALIZED VIEW core.mv_external_accounts;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_repmt_sku') THEN
    REFRESH MATERIALIZED VIEW core.mv_repmt_sku;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_repmt_sales') THEN
    REFRESH MATERIALIZED VIEW core.mv_repmt_sales;
  END IF;

  -- Flows (depends on ref.note_sku_va_map and remark mappings)
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='core' AND matviewname='mv_va_txn_flows') THEN
    REFRESH MATERIALIZED VIEW core.mv_va_txn_flows;
  END IF;
END;
$$;
