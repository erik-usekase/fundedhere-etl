-- sql/phase2/001_core_types.sql
-- Helper conversion functions used across core views/MVs.

SET search_path = core, public;

-- Create schema if not already present
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'core') THEN
    EXECUTE 'CREATE SCHEMA core';
  END IF;
END$$;

-- Safe numeric cast: strips commas/whitespace/stray chars; returns NULL on failure.
CREATE OR REPLACE FUNCTION core.to_numeric_safe(in_text text)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v text;
  r numeric;
BEGIN
  IF in_text IS NULL THEN
    RETURN NULL;
  END IF;

  v := btrim(in_text);
  IF v = '' THEN
    RETURN NULL;
  END IF;

  -- remove commas, keep digits, minus, and dot
  v := regexp_replace(v, ',',      '', 'g');
  v := regexp_replace(v, '[^0-9\.-]', '', 'g');

  BEGIN
    r := v::numeric;
    RETURN r;
  EXCEPTION WHEN others THEN
    RETURN NULL;
  END;
END;
$$;

-- Safe timestamptz cast: tries several common date formats; returns NULL if none match.
CREATE OR REPLACE FUNCTION core.to_tstz_safe(in_text text)
RETURNS timestamptz
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v text;
  ts timestamptz;
BEGIN
  IF in_text IS NULL THEN
    RETURN NULL;
  END IF;

  v := btrim(in_text);
  IF v = '' THEN
    RETURN NULL;
  END IF;

  -- Try flexible M/D/YYYY
  BEGIN
    ts := to_timestamp(v, 'FMMM/FMDD/YYYY') AT TIME ZONE 'UTC';
    RETURN ts;
  EXCEPTION WHEN others THEN
    -- Try YYYY-MM-DD
    BEGIN
      ts := to_timestamp(v, 'YYYY-MM-DD') AT TIME ZONE 'UTC';
      RETURN ts;
    EXCEPTION WHEN others THEN
      -- Try YYYY/MM/DD
      BEGIN
        ts := to_timestamp(v, 'YYYY/MM/DD') AT TIME ZONE 'UTC';
        RETURN ts;
      EXCEPTION WHEN others THEN
        -- Try DD/MM/YYYY
        BEGIN
          ts := to_timestamp(v, 'DD/MM/YYYY') AT TIME ZONE 'UTC';
          RETURN ts;
        EXCEPTION WHEN others THEN
          RETURN NULL;
        END;
      END;
    END;
  END;
END;
$$;

-- Safe date cast built on to_tstz_safe; returns UTC date portion.
CREATE OR REPLACE FUNCTION core.to_date_safe(in_text text)
RETURNS date
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  ts timestamptz;
BEGIN
  ts := core.to_tstz_safe(in_text);
  IF ts IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN (ts AT TIME ZONE 'UTC')::date;
END;
$$;
