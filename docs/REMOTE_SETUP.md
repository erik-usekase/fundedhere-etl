# Remote Host Setup Guide

Complete guide for setting up the ETL pipeline on a remote/dev host.

---

## Prerequisites

1. Docker and Docker Compose installed
2. Git repository cloned
3. CSV files in `data/inc_data/`

---

## Quick Setup (3 Commands)

```bash
# 1. Pull latest code
git pull origin usekase

# 2. Start database
make up-wait

# 3. Run cleanup and load
bash scripts/remote_cleanup.sh
```

---

## What the Cleanup Script Does

The `remote_cleanup.sh` script:

1. ✓ Checks current datestyle
2. ✓ Drops all schemas (CASCADE)
3. ✓ Sets `datestyle='ISO, MDY'`
4. ✓ Recreates schemas
5. ✓ Runs ETL pipeline
6. ✓ Loads all data
7. ✓ Verifies row counts

---

## Manual Setup (Step-by-Step)

If you prefer manual control:

### 1. Start Database
```bash
make up-wait
```

### 2. Set Datestyle
```bash
docker exec app-postgres psql -U appuser -d appdb -c \
  "ALTER DATABASE appdb SET datestyle = 'ISO, MDY';"
```

### 3. Drop and Recreate Schemas
```bash
docker exec app-postgres psql -U appuser -d appdb << 'SQL'
DROP SCHEMA IF EXISTS mart CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS ref CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;

CREATE SCHEMA raw;
CREATE SCHEMA ref;
CREATE SCHEMA core;
CREATE SCHEMA mart;
SQL
```

### 4. Bootstrap Database
```bash
make container-etl-verify
```

### 5. Load Data
```bash
make container-etl-load
```

### 6. Verify
```bash
make counts
docker exec app-postgres psql -U appuser -d appdb -c "SHOW datestyle;"
```

---

## Troubleshooting

### Date/Time Error

**Error:** `date/time field value out of range: "29-09-25"`

**Fix:**
```bash
# Run the cleanup script
bash scripts/remote_cleanup.sh
```

**Why:** The database has wrong datestyle cached in table schemas. Must drop and recreate with correct setting.

---

### No Data in Views

**Check if data exists:**
```bash
make counts
```

**Expected output:**
```
external_accounts: 2,718
va_txn: 28,599
repmt_sku: 366
repmt_sales: 366
```

**If zero rows:**
```bash
make container-etl-load
```

---

### Views Don't Exist

**Check if views exist:**
```bash
docker exec app-postgres psql -U appuser -d appdb -c \
  "SELECT table_name FROM information_schema.tables 
   WHERE table_schema='mart' ORDER BY table_name;"
```

**If missing:**
```bash
make container-etl-verify
```

---

### Docker Volume Issues

**Clean Docker completely:**
```bash
docker compose down
docker volume rm fundedhere-etl_postgres_data
make up-wait
bash scripts/remote_cleanup.sh
```

---

## Verification Queries

### Check Datestyle
```sql
SHOW datestyle;
-- Expected: ISO, MDY
```

### Check Data Loaded
```sql
SELECT 'external_accounts' as table, COUNT(*) FROM raw.external_accounts
UNION ALL SELECT 'va_txn', COUNT(*) FROM raw.va_txn
UNION ALL SELECT 'repmt_sku', COUNT(*) FROM raw.repmt_sku
UNION ALL SELECT 'repmt_sales', COUNT(*) FROM raw.repmt_sales;
```

### Check Views
```sql
SELECT 'v_level1' as view, COUNT(*) FROM mart.v_level1
UNION ALL SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;
-- Expected: 366 rows each
```

### Test Sample Query
```sql
SELECT "SKU ID", "Merchant", "Amount Pulled", "Amount Received"
FROM mart.v_level1
LIMIT 5;
```

---

## Complete Reset (Nuclear Option)

If everything is broken:

```bash
# Stop everything
docker compose down

# Remove volume
docker volume rm fundedhere-etl_postgres_data

# Remove images (optional)
docker compose down --rmi all

# Start fresh
make up-wait
bash scripts/remote_cleanup.sh
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `bash scripts/remote_cleanup.sh` | Complete cleanup + reload |
| `make up-wait` | Start database |
| `make container-etl-verify` | Bootstrap schema |
| `make container-etl-load` | Load CSV data |
| `make counts` | Check row counts |
| `docker compose down` | Stop database |

---

## Files Needed

Ensure these CSV files exist in `data/inc_data/`:
- `external_accounts_2025-09.csv` (or `_full.csv`)
- `va_txn_2025-09.csv` (or `_full.csv`)
- `repmt_sku_2025-09.csv` (or `_full.csv`)
- `repmt_sales_2025-09.csv` (or `_full.csv`)

---

## After Setup

1. **Connect with SQL Client:**
   - Host: localhost (or remote IP)
   - Port: 5433
   - Database: appdb
   - User: appuser
   - Password: changeme

2. **Run Queries:**
   ```sql
   SELECT * FROM mart.v_level1 LIMIT 10;
   SELECT * FROM mart.v_level2a LIMIT 10;
   SELECT * FROM mart.v_level2b LIMIT 10;
   ```

3. **Verify Structure:**
   ```sql
   -- Check column counts
   SELECT table_name, COUNT(*) as columns
   FROM information_schema.columns
   WHERE table_schema='mart' AND table_name LIKE 'v_level%'
   GROUP BY table_name;
   
   -- Expected: v_level1=8, v_level2a=49, v_level2b=32
   ```

---

## Support

For issues:
1. Check `docs/DATESTYLE_TROUBLESHOOTING.md`
2. Check `docs/COMPLETE_CLEANUP.md`
3. Run `bash scripts/remote_cleanup.sh`
