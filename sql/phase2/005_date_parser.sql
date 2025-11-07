-- sql/phase2/005_date_parser.sql - Flexible date parsing function
-- Handles multiple date formats from CSV files

SET search_path = public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS parse_csv_date(text);

-- Create flexible date parser that handles multiple formats
CREATE OR REPLACE FUNCTION parse_csv_date(date_str text)
RETURNS date AS $$
BEGIN
  -- Return NULL for empty/null strings
  IF date_str IS NULL OR date_str = '' THEN
    RETURN NULL;
  END IF;

  -- Try MM/DD/YYYY format (e.g., "9/29/2025")
  BEGIN
    RETURN TO_DATE(date_str, 'MM/DD/YYYY');
  EXCEPTION WHEN OTHERS THEN
    NULL; -- Continue to next format
  END;

  -- Try DD-MM-YY format (e.g., "29-09-25")
  BEGIN
    RETURN TO_DATE(date_str, 'DD-MM-YY');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Try YYYY-MM-DD format (ISO standard, e.g., "2025-09-29")
  BEGIN
    RETURN TO_DATE(date_str, 'YYYY-MM-DD');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Try DD/MM/YYYY format (e.g., "29/09/2025")
  BEGIN
    RETURN TO_DATE(date_str, 'DD/MM/YYYY');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Try MM-DD-YYYY format (e.g., "09-29-2025")
  BEGIN
    RETURN TO_DATE(date_str, 'MM-DD-YYYY');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- If all formats fail, raise error with helpful message
  RAISE EXCEPTION 'Unable to parse date: %. Supported formats: MM/DD/YYYY, DD-MM-YY, YYYY-MM-DD, DD/MM/YYYY, MM-DD-YYYY', date_str;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION parse_csv_date(text) IS
'Flexibly parse date strings from CSV files. Tries multiple common formats: MM/DD/YYYY, DD-MM-YY, YYYY-MM-DD, DD/MM/YYYY, MM-DD-YYYY';
