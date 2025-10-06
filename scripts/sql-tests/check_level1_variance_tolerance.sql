DO $$
DECLARE
  outside_band int;
BEGIN
  SELECT COUNT(*) INTO outside_band
  FROM mart.v_level1
  WHERE (COALESCE(amount_pulled,0) - COALESCE(amount_received,0)) < -4.0
     OR (COALESCE(amount_pulled,0) - COALESCE(amount_received,0)) > 0.05
     OR (COALESCE(amount_pulled,0) - COALESCE(amount_received,0)) > -2.05;

  IF outside_band > 0 THEN
    RAISE EXCEPTION 'Level 1 variance outside tolerance for % row(s)', outside_band;
  END IF;
END $$;
