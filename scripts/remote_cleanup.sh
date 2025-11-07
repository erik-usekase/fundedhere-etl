#!/usr/bin/env bash
# Remote host cleanup script - run this on your dev/remote host
# Usage: bash scripts/remote_cleanup.sh

set -e

echo "=========================================="
echo "Remote Host Database Cleanup"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Check current datestyle"
echo "  2. Drop all schemas (CASCADE)"
echo "  3. Set datestyle to ISO, MDY"
echo "  4. Recreate schemas"
echo "  5. Reload all data"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Checking current datestyle..."
docker exec app-postgres psql -U appuser -d appdb -c "SHOW datestyle;"

echo ""
echo "Step 2: Dropping all schemas..."
docker exec app-postgres psql -U appuser -d appdb << 'SQL'
DROP SCHEMA IF EXISTS mart CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS ref CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
SQL

echo ""
echo "Step 3: Setting datestyle..."
docker exec app-postgres psql -U appuser -d appdb -c "ALTER DATABASE appdb SET datestyle = 'ISO, MDY';"

echo ""
echo "Step 4: Reconnecting and creating schemas..."
docker exec app-postgres psql -U appuser -d appdb << 'SQL'
-- Reconnect applies datestyle
SELECT set_config('datestyle', 'ISO, MDY', false);

-- Verify
SHOW datestyle;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

-- List schemas
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name IN ('raw', 'ref', 'core', 'mart')
ORDER BY schema_name;
SQL

echo ""
echo "Step 5: Running ETL pipeline..."
make container-etl-verify

echo ""
echo "Step 6: Loading data..."
make container-etl-load

echo ""
echo "=========================================="
echo "✓ Remote Host Cleanup Complete!"
echo "=========================================="
echo ""
echo "Verification:"
make counts

echo ""
echo "Datestyle verification:"
docker exec app-postgres psql -U appuser -d appdb -c "SHOW datestyle;"
