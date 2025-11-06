# Manual Setup Steps - FundedHere ETL

_Clean database setup with fixed views_

## Prerequisites

✅ Docker Desktop running
✅ CSV files in `data/inc_data/`:
  - `external_accounts_2025-09.csv`
  - `va_txn_2025-09.csv`
  - `repmt_sku_2025-09.csv`
  - `repmt_sales_2025-09.csv`

---

## Step-by-Step Instructions

### 1. Start PostgreSQL Database

```bash
make up-wait
```

**What it does:**
- Starts PostgreSQL container on port 5433
- Waits for database to be healthy
- Takes ~10 seconds

**Expected output:**
```
Container app-postgres  Started
Waiting for PostgreSQL to be ready...
PostgreSQL is ready!
```

---

### 2. Run Complete ETL Pipeline

**OPTION A: Using Python CLI (Recommended)**

```bash
uv run fundedhere-etl prep
uv run fundedhere-etl bootstrap
uv run fundedhere-etl load --mode parallel
uv run fundedhere-etl load-mapping
uv run fundedhere-etl refresh
```

**What it does:**
- Prepares CSV files (normalizes headers)
- Bootstraps database schema (13 SQL files)
- Loads 4 CSV files in parallel (~32k rows)
- Loads 366 SKU-VA mappings
- Refreshes materialized views

**Expected output:**
```
[prep] Preparing 4 CSV files...
[bootstrap] Executing 13 SQL files...
[load] Loading 4 CSV files in parallel...
[load] external_accounts: 2718 rows
[load] va_txn: 28599 rows
[load] repmt_sku: 366 rows
[load] repmt_sales: 366 rows
[mapping] Loaded 366 SKU-VA mappings
[refresh] Refreshed 4 materialized views
```

**OPTION B: If prepped files already exist**

```bash
uv run fundedhere-etl bootstrap
uv run fundedhere-etl load --mode parallel
uv run fundedhere-etl load-mapping
uv run fundedhere-etl refresh
```

**Time:** ~1-2 minutes

---

### 3. Verify Views Match Excel

#### Check Sample SKUs

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT 
  'v_level1' as view, 
  \"SKU ID\", 
  \"Amount Received\", 
  \"Variance\"
FROM mart.v_level1
WHERE \"SKU ID\" LIKE 'STANDFAN 16%'
LIMIT 3;
"
```

**Expected output:**
```
   view   |                  SKU ID                      | Amount Received | Variance
----------+---------------------------------------------+-----------------+----------
 v_level1 | STANDFAN 16'' 5BLADES-1288-636-0A4fLWeJhb   |         3114.40 | 0.180000
```

#### Check Row Counts

```bash
make counts
```

**Expected output:**
```
    schema_table           | row_count
---------------------------+-----------
 raw.external_accounts     |      2718
 raw.va_txn                |     28599
 raw.repmt_sku             |       366
 raw.repmt_sales           |       366
 mart.v_level1             |       366
 mart.v_level2a            |       366
 mart.v_level2b            |       366
```

---

### 4. Query the Views

#### Using psql (Quick Queries)

```bash
# Query v_level1
make sql CMD="SELECT * FROM mart.v_level1 LIMIT 5;"

# Query v_level2a
make sql CMD="SELECT * FROM mart.v_level2a LIMIT 5;"

# Query v_level2b
make sql CMD="SELECT * FROM mart.v_level2b LIMIT 5;"
```

#### Using Database Tools (pgAdmin, DBeaver, etc.)

**Connection details:**
- Host: `localhost`
- Port: `5433` (NOT 5432!)
- Database: `appdb`
- Username: `appuser`
- Password: `changeme`

See [docs/DATABASE_TOOLS.md](docs/DATABASE_TOOLS.md) for detailed setup.

---

### 5. Verify Excel Parity

Compare specific SKUs with Excel values:

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT 
  \"SKU ID\",
  \"Amount Received\",
  \"Amount Distributed Down the Repayment Waterfall\",
  \"Variance\"
FROM mart.v_level2a
WHERE \"SKU ID\" IN (
  '4 HOLE EGG PAN-1288-636-92rxuDoq6U',
  'KITCHEN WIPES 80PCS-1288-636-7yXAnTIbJu',
  'MINI FRIDGE-25L-1321-636-s7OiVNg82h'
)
ORDER BY \"SKU ID\";
"
```

**Compare with `pre_csv/full_wb.xlsx` Sheet 2a:**
- Should match exactly to 2 decimal places
- All variances should be ~0

---

### 6. Shutdown (When Done)

```bash
make down
```

**What it does:**
- Stops PostgreSQL container
- Removes network
- Data persists in Docker volume for next restart

---

## Troubleshooting

### Database Connection Refused

```bash
# Check if container is running
docker ps | grep postgres

# If not running, start it
make up-wait
```

### Port 5433 Already in Use

Edit `.env` file:
```bash
POSTGRES_PORT=5434
```

Then restart:
```bash
make down && make up-wait
```

### CSV Files Not Found

```bash
# Check files exist
ls -la data/inc_data/*.csv

# Should show 4 files:
# external_accounts_2025-09.csv
# va_txn_2025-09.csv
# repmt_sku_2025-09.csv
# repmt_sales_2025-09.csv
```

### Views Returning Zeros

```bash
# Check if data was loaded
make counts

# If raw tables are empty, reload:
make container-etl-verify
```

### Permission Errors (Git Bash Windows)

```bash
# Fix line endings (one-time)
bash scripts/setup_gitbash.sh
```

---

## Quick Reference

### Most Common Commands

```bash
# Start database
make up-wait

# Run ETL (Python CLI - Recommended)
uv run fundedhere-etl prep
uv run fundedhere-etl bootstrap
uv run fundedhere-etl load --mode parallel
uv run fundedhere-etl load-mapping
uv run fundedhere-etl refresh

# Query data
make sql CMD="SELECT COUNT(*) FROM mart.v_level1;"

# Check row counts
make counts

# Stop database
make down
```

### View Definitions

**v_level1 (Sheet 1):**
- Amount Received = ONLY `merchant-repayment` transactions
- Focus: Cash received from merchants

**v_level2a (Sheet 2a):**
- Amount Received = ALL inflows EXCEPT `note-issued-transfer-to-sku`
- Focus: Total fund flow including cross-SKU transfers

**v_level2b (Sheet 2b):**
- Same as v_level2a
- Shows payment component breakdown

---

## Expected Results

✅ 366 SKUs in all 3 views
✅ Values match `pre_csv/full_wb.xlsx` exactly
✅ All variances near zero (~0.00 to 1.20)
✅ No error messages during ETL
✅ Total processing time: 1-2 minutes

---

## Next Steps After Verification

1. Connect your SQL tool to explore data
2. Run custom queries for your analysis
3. Compare specific SKUs with Excel workbook
4. Build additional reports/dashboards

For detailed documentation, see:
- [README.md](README.md) - Complete project guide
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup
- [docs/AGENT_HANDOFF.md](docs/AGENT_HANDOFF.md) - Session log

---

_Database cleared and ready for fresh setup. Follow steps above to verify fixes._
