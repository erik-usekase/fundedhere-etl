#!/usr/bin/env bash
# Complete database purge and reload script
# Use this when you need to start completely fresh

set -e

echo "=== Complete Database Purge and Reload ==="
echo ""
echo "This will:"
echo "  1. Drop all schemas (raw, ref, core, mart)"
echo "  2. Recreate schemas from scratch"
echo "  3. Reload all CSV data"
echo "  4. Rebuild all views"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Dropping all schemas..."
docker exec app-postgres psql -U appuser -d appdb -c "
DROP SCHEMA IF EXISTS mart CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS ref CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
"

echo ""
echo "Step 2: Recreating schemas with correct datestyle..."
docker exec app-postgres psql -U appuser -d appdb -c "
-- CRITICAL: Set datestyle to match CSV format (M/D/YYYY)
ALTER DATABASE appdb SET datestyle = 'ISO, MDY';
"

echo "Reconnecting to apply datestyle..."
docker exec app-postgres psql -U appuser -d appdb -c "
-- Reconnect to apply database setting
SELECT set_config('datestyle', 'ISO, MDY', false);

-- Verify datestyle
SHOW datestyle;

-- Recreate schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;
"

echo ""
echo "Step 3: Running full bootstrap..."
make container-etl-verify

echo ""
echo "Step 4: Loading data..."
make container-etl-load

echo ""
echo "=== Purge Complete ==="
echo ""
echo "Verification:"
docker exec app-postgres psql -U appuser -d appdb -c "
SHOW datestyle;
SELECT 'raw.external_accounts' as table, COUNT(*) FROM raw.external_accounts
UNION ALL
SELECT 'raw.va_txn', COUNT(*) FROM raw.va_txn
UNION ALL
SELECT 'raw.repmt_sku', COUNT(*) FROM raw.repmt_sku
UNION ALL
SELECT 'raw.repmt_sales', COUNT(*) FROM raw.repmt_sales
UNION ALL
SELECT 'mart.v_level1', COUNT(*) FROM mart.v_level1
UNION ALL
SELECT 'mart.v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL
SELECT 'mart.v_level2b', COUNT(*) FROM mart.v_level2b;
"
