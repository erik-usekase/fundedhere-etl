DO $$
DECLARE
  outside_band int;
BEGIN
  SELECT COUNT(*) INTO outside_band
  FROM mart.v_level1
  WHERE "Variance Pulled vs Received" < -4.0
     OR "Variance Pulled vs Received" > 0.05
     OR "Variance Pulled vs Received" > -2.05; -- ensure variance stays at or below -2.05 (closer to zero)

  IF outside_band > 0 THEN
    RAISE EXCEPTION 'Level 1 variance outside tolerance for % row(s)', outside_band;
  END IF;
END $$;
