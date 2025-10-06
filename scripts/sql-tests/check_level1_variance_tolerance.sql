DO $$
DECLARE
  outside_band int;
  fail_on_level1_variance boolean := 
    CASE coalesce(current_setting('etlsuite.fail_on_level1_variance', true), '0')
      WHEN '1' THEN true
      ELSE false
    END;
BEGIN
  SELECT COUNT(*) INTO outside_band
  FROM mart.v_level1
  WHERE (COALESCE(amount_pulled,0) - COALESCE(amount_received,0)) < -4.0
     OR (COALESCE(amount_pulled,0) - COALESCE(amount_received,0)) > 0.05
     OR (COALESCE(amount_pulled,0) - COALESCE(amount_received,0)) > -2.05;

  IF outside_band > 0 THEN
    IF fail_on_level1_variance THEN
      RAISE EXCEPTION 'Level 1 variance outside tolerance for % row(s)', outside_band;
    ELSE
      RAISE NOTICE 'Level 1 variance outside tolerance for % row(s)', outside_band;
    END IF;
  END IF;
END $$;
