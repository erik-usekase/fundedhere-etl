#!/usr/bin/env bash
# Nuclear option: Complete Docker cleanup for persistent issues
# This destroys EVERYTHING and starts completely fresh

set -e

echo "=============================================="
echo "DOCKER NUCLEAR CLEANUP"
echo "=============================================="
echo ""
echo "This will:"
echo "  1. Stop all containers"
echo "  2. Remove all containers"
echo "  3. Remove PostgreSQL data volume"
echo "  4. Remove Docker images (optional)"
echo "  5. Start fresh database"
echo "  6. Run complete ETL pipeline"
echo ""
echo "WARNING: This deletes ALL database data!"
echo ""
read -p "Are you absolutely sure? (type 'yes' to continue): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1/7: Stopping all containers..."
docker compose down

echo ""
echo "Step 2/7: Removing all project containers..."
docker compose rm -f

echo ""
echo "Step 3/7: Removing PostgreSQL data volume..."
docker volume rm fundedhere-etl_postgres_data 2>/dev/null || echo "Volume already removed"

echo ""
echo "Step 4/7: Checking for orphaned volumes..."
docker volume ls | grep fundedhere || echo "No orphaned volumes found"

echo ""
read -p "Remove Docker images too? (yes/no): " remove_images
if [ "$remove_images" = "yes" ]; then
    echo "Removing Docker images..."
    docker compose down --rmi all
    docker image prune -f
fi

echo ""
echo "Step 5/7: Starting fresh database..."
make up-wait

echo ""
echo "Step 6/7: Running complete ETL pipeline..."
make container-etl-verify

echo ""
echo "Step 7/7: Loading data..."
make container-etl-load

echo ""
echo "=============================================="
echo "✓ Nuclear Cleanup Complete!"
echo "=============================================="
echo ""
echo "Verification:"
make counts

echo ""
echo "All fresh data loaded with correct datestyle."
