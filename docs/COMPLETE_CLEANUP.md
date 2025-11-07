# Complete Cleanup Guide

When you need to completely wipe everything and start fresh.

---

## Quick Commands

### Docker Nuclear Cleanup (Recommended)
```bash
bash scripts/docker_nuclear_clean.sh
```

### Manual Step-by-Step
```bash
# Stop everything
docker compose down

# Remove data volume
docker volume rm fundedhere-etl_postgres_data

# Start fresh
make up-wait
make container-etl-verify
make container-etl-load
```

---

## What Gets Cleaned

### 1. Docker Containers
```bash
# Stop and remove
docker compose down
docker compose rm -f

# Verify clean
docker ps -a | grep fundedhere
```

### 2. PostgreSQL Data Volume
```bash
# Remove named volume (data persists here)
docker volume rm fundedhere-etl_postgres_data

# List all volumes
docker volume ls | grep fundedhere
```

### 3. Docker Images (Optional)
```bash
# Remove project images
docker compose down --rmi all

# Clean dangling images
docker image prune -f

# See all images
docker images | grep fundedhere
```

### 4. Database Schema (Inside Container)
```bash
# Connect and purge
docker exec app-postgres psql -U appuser -d appdb -f /workspace/scripts/purge_database.sql
```

---

## Cleanup Scenarios

### Scenario 1: Date/Time Format Issues
**Problem**: Persistent "date/time field value out of range" errors

**Solution**:
```bash
# 1. Clean Docker volume
docker compose down
docker volume rm fundedhere-etl_postgres_data

# 2. Restart with correct datestyle
make up-wait
make container-etl-verify
make container-etl-load
```

**Why**: The PostgreSQL data volume caches table schemas with old datestyle settings. Must recreate volume.

---

### Scenario 2: Corrupted Data
**Problem**: Views show wrong values, row counts incorrect

**Solution**:
```bash
# Database-only purge (faster)
docker exec app-postgres psql -U appuser -d appdb -f /workspace/scripts/purge_database.sql

# Then reload
make container-etl-load
```

**Why**: Table data is corrupted but Docker/volume are fine. Just purge schemas.

---

### Scenario 3: Complete Reset
**Problem**: Everything is broken, want to start from scratch

**Solution**:
```bash
# Nuclear option
bash scripts/docker_nuclear_clean.sh

# Or manually:
docker compose down
docker volume rm fundedhere-etl_postgres_data
docker compose down --rmi all
docker image prune -f
make up-wait
make container-etl-verify
make container-etl-load
```

**Why**: Start completely fresh - no cached containers, images, or data.

---

## Verification After Cleanup

### Check Database Status
```bash
# Row counts
make counts

# Expected output:
# external_accounts: 2,718
# va_txn: 28,599
# repmt_sku: 366
# repmt_sales: 366
```

### Check Datestyle
```bash
docker exec app-postgres psql -U appuser -d appdb -c "SHOW datestyle;"

# Expected: ISO, MDY
```

### Check Views
```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT 'v_level1' as view, COUNT(*) as rows FROM mart.v_level1
UNION ALL
SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL
SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;"

# Expected: 366 rows each
```

### Test Sample Query
```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT \"SKU ID\", \"Amount Pulled\", \"Amount Received\" 
FROM mart.v_level1 
LIMIT 3;"

# Should return data without errors
```

---

## What Gets Preserved

These are NOT deleted unless you manually remove them:

- CSV source files in `data/inc_data/`
- SQL scripts in `sql/` and `initdb/`
- Git repository and history
- Docker network config

---

## Troubleshooting

### Volume won't delete
```bash
# Force stop all containers first
docker ps -a -q | xargs docker stop
docker ps -a -q | xargs docker rm

# Then delete volume
docker volume rm fundedhere-etl_postgres_data -f
```

### Port 5433 still in use
```bash
# Find process using port
lsof -i :5433  # macOS/Linux
netstat -ano | findstr :5433  # Windows

# Kill it or use different port
export POSTGRES_PORT=5434
make up-wait
```

### Images won't delete
```bash
# Stop containers using the image
docker ps -a | grep fundedhere-etl
docker stop <container-id>
docker rm <container-id>

# Delete image
docker rmi fundedhere-etl-etl:latest -f
```

---

## Scripts Reference

| Script | Purpose | Use When |
|--------|---------|----------|
| `scripts/docker_nuclear_clean.sh` | Complete Docker cleanup | Everything broken |
| `scripts/purge_and_reload.sh` | Database purge + ETL | Date format issues |
| `scripts/purge_database.sql` | Schema-only purge | Corrupted data |

---

## Quick Reference

```bash
# Nuclear option (everything)
bash scripts/docker_nuclear_clean.sh

# Just data volume
docker compose down && docker volume rm fundedhere-etl_postgres_data && make up-wait

# Just database schemas  
docker exec app-postgres psql -U appuser -d appdb -f /workspace/scripts/purge_database.sql

# Verify after cleanup
make counts
```
