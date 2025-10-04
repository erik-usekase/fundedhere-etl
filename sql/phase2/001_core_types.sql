-- sql/phase2/001_core_types.sql
SET search_path = core, public;

CREATE OR REPLACE FUNCTION core.to_numeric_safe(txt text)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT NULLIF(regexp_replace(coalesce(txt,''), '[^0-9\.-]', '', 'g'), '')::numeric;
$$;

CREATE OR REPLACE FUNCTION core.to_date_safe(txt text)
RETURNS date LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  s text := coalesce(txt,'');
  d date;
BEGIN
  BEGIN
    d := to_date(s, 'MM/DD/YYYY');
    RETURN d;
  EXCEPTION WHEN others THEN
    BEGIN
      d := to_date(s, 'YYYY-MM-DD');
      RETURN d;
    EXCEPTION WHEN others THEN
      RETURN NULL;
    END;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION core.to_tstz_safe(txt text)
RETURNS timestamptz LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  s text := coalesce(txt,'');
  ts timestamptz;
BEGIN
  BEGIN
    ts := (to_timestamp(s, 'MM/DD/YYYY HH24:MI:SS') at time zone 'UTC');
    RETURN ts;
  EXCEPTION WHEN others THEN
    BEGIN
      ts := make_timestamptz(extract(year from core.to_date_safe(s))::int
                             ,extract(month from core.to_date_safe(s))::int
                             ,extract(day from core.to_date_safe(s))::int
                             ,0,0,0,'UTC');
      RETURN ts;
    EXCEPTION WHEN others THEN
      RETURN NULL;
    END;
  END;
END;
$$;

CREATE OR REPLACE VIEW core.v_va_txn_categorized AS
SELECT
  t.*,
  COALESCE(
    (SELECT m.category_code
     FROM ref.remarks_category_map m
     WHERE (CASE WHEN m.is_regex THEN t.remarks ~* m.raw_pattern ELSE lower(t.remarks) = lower(m.raw_pattern) END)
     ORDER BY m.priority ASC
     LIMIT 1),
  'uncategorized') AS category_code
FROM raw.va_txn t;

CREATE OR REPLACE FUNCTION core.refresh_all()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW core.mv_external_accounts;
  REFRESH MATERIALIZED VIEW core.mv_va_txn;
  REFRESH MATERIALIZED VIEW core.mv_repmt_sku;
  REFRESH MATERIALIZED VIEW core.mv_repmt_sales;
  ANALYZE core.mv_external_accounts;
  ANALYZE core.mv_va_txn;
  ANALYZE core.mv_repmt_sku;
  ANALYZE core.mv_repmt_sales;
END;
$$;
