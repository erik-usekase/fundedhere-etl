# Multi-Period Support Demonstration

## System Already Supports Multi-Period Data

The fundedhere-etl system is **already fully equipped** to handle not just the current month's files but any future month's CSV files.

## Quick Verification

### Current Setup (September 2025)

```bash
# Current files in data/inc_data/
external_accounts_2025-09.csv
va_txn_2025-09.csv
repmt_sku_2025-09.csv
repmt_sales_2025-09.csv
```

### Adding October 2025 Files

Simply drop the new month's files with the same naming pattern:

```bash
# Add new files
data/inc_data/
├── external_accounts_2025-10.csv  ← New
├── va_txn_2025-10.csv              ← New
├── repmt_sku_2025-10.csv           ← New
├── repmt_sales_2025-10.csv         ← New
├── external_accounts_2025-09.csv  ← Existing
├── va_txn_2025-09.csv              ← Existing
├── repmt_sku_2025-09.csv           ← Existing
└── repmt_sales_2025-09.csv         ← Existing
```

### Load New Period (Preserving September Data)

```bash
# Incremental load - keeps September data
make load-multi-append

# Or directly
scripts/load_multi_period.sh data/inc_data append
```

**Result:** Database now contains both September AND October data.

## Key Multi-Period Features

### 1. Automatic Period Detection

The system extracts period from filename:
- `external_accounts_2025-09.csv` → Period: `2025-09`
- `va_txn_2025-10.csv` → Period: `2025-10`
- `repmt_sku_2025-11.csv` → Period: `2025-11`

### 2. Period-Aware Queries

```sql
-- Show all available periods
SELECT * FROM mart.v_available_periods;

-- Latest period only
SELECT * FROM mart.v_latest_period;

-- Specific period
SELECT * FROM mart.v_level1_by_period
WHERE "Period" = '2025-10';

-- Compare two periods
SELECT * FROM mart.compare_periods('2025-09', '2025-10');
```

### 3. Loading Modes

**Replace Mode** (default):
```bash
# Fresh start - replaces all data
make load-multi-period
```

**Append Mode** (incremental):
```bash
# Add new period - keeps existing
make load-multi-append
```

## Monthly Update Workflow

### Step 1: Receive New Month's Files

Export from accounting system for October 2025:
- `external_accounts_2025-10.csv`
- `va_txn_2025-10.csv`
- `repmt_sku_2025-10.csv`
- `repmt_sales_2025-10.csv`

### Step 2: Place Files

```bash
# Copy to data directory
cp /path/to/exports/*2025-10.csv data/inc_data/
```

### Step 3: Load New Period

```bash
# Append new period (keeps September)
make load-multi-append
```

### Step 4: Verify

```bash
# Check loaded periods
make periods-list

# Output:
#  Period  | Source Count | Sources
# ---------+--------------+---------
#  2025-10 |            4 | {external_accounts,va_txn,repmt_sku,repmt_sales}
#  2025-09 |            4 | {external_accounts,va_txn,repmt_sku,repmt_sales}

# Query October data
make sql CMD="SELECT * FROM mart.v_latest_period LIMIT 5;"
```

## Remote Host Multi-Period Setup

For remote/dev hosts:

```bash
# 1. Update code
git pull origin usekase

# 2. Start database
make up-wait

# 3. Full cleanup (first time)
bash scripts/remote_cleanup.sh

# 4. After cleanup, place multiple period files
data/inc_data/
├── *_2025-09.csv  (4 files)
├── *_2025-10.csv  (4 files)
└── *_2025-11.csv  (4 files)

# 5. Load all periods
make load-multi-period

# 6. Verify
make periods-list
```

## Example Queries Across Periods

### Total Amount Received by SKU (All Periods)

```sql
SELECT
  "SKU ID",
  "Merchant",
  COUNT(DISTINCT "Period") AS "Periods with Data",
  SUM("Amount Received") AS "Total Amount Received",
  AVG("Amount Received") AS "Avg Per Period"
FROM mart.v_level1_by_period
GROUP BY "SKU ID", "Merchant"
ORDER BY "Total Amount Received" DESC
LIMIT 20;
```

### Month-over-Month Comparison

```sql
SELECT * FROM mart.compare_periods('2025-09', '2025-10')
WHERE ABS("Change in Amount Received") > 1000
ORDER BY "Change in Amount Received" DESC;
```

### Trend Analysis

```sql
SELECT
  "Period",
  COUNT(DISTINCT "SKU ID") AS "Active SKUs",
  SUM("Amount Received") AS "Total Amount Received",
  AVG("Variance") AS "Avg Variance"
FROM mart.v_level1_by_period
GROUP BY "Period"
ORDER BY "Period";
```

## File Naming Requirements

**Pattern:** `{table_type}_YYYY-MM.csv[.gz]`

**Valid Examples:**
- ✅ `external_accounts_2025-09.csv`
- ✅ `va_txn_2025-10.csv`
- ✅ `repmt_sku_2025-11.csv.gz` (compressed)
- ✅ `repmt_sales_2025-12.csv`

**Invalid Examples:**
- ❌ `external_accounts_september.csv` (no YYYY-MM)
- ❌ `va_txn_09-2025.csv` (wrong order)
- ❌ `repmt_sku_2025_09.csv` (underscore instead of dash)

## Existing Documentation

Full details available in:
- `docs/MULTI_PERIOD.md` - Complete multi-period guide (569 lines)
- `scripts/load_multi_period.sh` - Multi-period loader (246 lines)

## Summary

✅ **System already supports multiple periods**
✅ **Naming convention: `table_YYYY-MM.csv`**
✅ **Two loading modes: replace or append**
✅ **Period-aware views and queries**
✅ **Backward compatible with single-period workflow**

**Next month's files?** Just drop them in `data/inc_data/` with `YYYY-MM` in filename, run `make load-multi-append`, done.
