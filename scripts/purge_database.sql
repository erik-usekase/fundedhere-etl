-- ============================================================================
-- Complete Database Purge Script
-- Use this to completely wipe and reset the database on any PostgreSQL host
-- ============================================================================

-- STEP 1: Drop all schemas (CASCADE removes all tables, views, functions)
DROP SCHEMA IF EXISTS mart CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS ref CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;

-- STEP 2: Set datestyle FIRST (before creating any tables)
-- This is CRITICAL - CSV files use M/D/YYYY format (9/29/2025)
ALTER DATABASE appdb SET datestyle = 'ISO, MDY';

-- STEP 3: Verify datestyle setting
\echo 'Current datestyle setting:'
SHOW datestyle;

-- STEP 4: Recreate empty schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

\echo ''
\echo '=== Database Purged Successfully ==='
\echo ''
\echo 'Schemas dropped and recreated with correct datestyle.'
\echo 'Next steps:'
\echo '  1. Disconnect and reconnect to database'
\echo '  2. Run: \\i initdb/000_schemas.sql'
\echo '  3. Run: \\i initdb/010_extensions.sql'
\echo '  4. Run: \\i initdb/020_security.sql'
\echo '  5. Run: \\i initdb/100_raw_tables.sql'
\echo '  6. Load CSV data'
\echo '  7. Run view creation scripts'
\echo ''
