-- scripts/sql-tests/t85_refresh_and_level2.sql
-- Refresh all MVs (robust)
-- This file assumes scripts/sql-tests/refresh.sql already exists in your repo.
-- Run via: make sqlf FILE=scripts/sql-tests/refresh.sql
-- Then preview Level2
SELECT * FROM mart.v_level2a ORDER BY 1 LIMIT 50;
