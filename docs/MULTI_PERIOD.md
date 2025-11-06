# Multi-Period Support Guide

## Overview

The fundedhere-etl system supports **loading and querying data across multiple date periods** (e.g., 2025-09, 2025-10, 2025-11). This enables:

✅ **Historical analysis** - Compare metrics across months
✅ **Incremental loading** - Add new periods without losing old data
✅ **Period-based queries** - Filter views by specific date ranges
✅ **Trend tracking** - Monitor SKU performance over time

## Quick Start

### 1. Organize CSV Files by Period

```bash
data/inc_data/
├── external_accounts_2025-09.csv
├── va_txn_2025-09.csv
├── repmt_sku_2025-09.csv
├── repmt_sales_2025-09.csv
├── external_accounts_2025-10.csv
├── va_txn_2025-10.csv
├── repmt_sku_2025-10.csv
├── repmt_sales_2025-10.csv
├── external_accounts_2025-11.csv
└── ...
```

**Naming Convention:**
- Pattern: `{table_type}_YYYY-MM.csv[.gz]`
- Examples: `va_txn_2025-09.csv`, `repmt_sku_2025-10.csv.gz`

### 2. Load All Periods

```bash
# Full multi-period workflow
make up-wait
make etl-multi-period

# Or step-by-step:
make up-wait
make bootstrap
make deploy-period-views
make load-multi-period       # Loads ALL CSV files
make prep-map
make load-mapping
make refresh-optimized
make periods-list            # Show loaded periods
```

### 3. Query by Period

```sql
-- Show all available periods
SELECT * FROM mart.v_available_periods;

-- Level 1 for latest period only
SELECT * FROM mart.v_latest_period;

-- Level 1 filtered to specific period
SELECT * FROM mart.v_level1_by_period
WHERE "Period" = '2025-10';

-- Compare two periods
SELECT * FROM mart.compare_periods('2025-09', '2025-10');
```

## Loading Modes

### Replace Mode (Default)

Truncates existing data before loading. Use for fresh starts or full reloads.

```bash
# Load all periods, replacing existing data
make load-multi-period

# Or directly
scripts/load_multi_period.sh data/inc_data replace
```

### Append Mode (Incremental)

Adds new period data without deleting existing. Use for monthly updates.

```bash
# Add new period to existing data
make load-multi-append

# Or directly
scripts/load_multi_period.sh data/inc_data append
```

**Example Workflow:**

```bash
# Initial load (September)
make load-multi-period  # Loads 2025-09

# Next month (October) - add without deleting September
make load-multi-append  # Adds 2025-10, keeps 2025-09

# Next month (November) - continue building history
make load-multi-append  # Adds 2025-11, keeps 2025-09, 2025-10
```

## Period-Aware Views

### Available Periods

```sql
SELECT * FROM mart.v_available_periods;
```

Output:
```
 Period  | Source Count |              Sources
---------+--------------+------------------------------------
 2025-11 |            4 | {external_accounts,repmt_sales,...}
 2025-10 |            4 | {external_accounts,repmt_sales,...}
 2025-09 |            4 | {external_accounts,repmt_sales,...}
```

### Period Coverage

```sql
SELECT * FROM mart.v_period_coverage;
```

Output:
```
 Period  | External Account VAs | VA Transaction VAs | VA Transaction SKUs | External Records | VA Txn Records
---------+----------------------+--------------------+---------------------+------------------+----------------
 2025-11 |                 2850 |               3120 |                 389 |             2850 |          30245
 2025-10 |                 2718 |               2998 |                 366 |             2718 |          28599
 2025-09 |                 2650 |               2890 |                 358 |             2650 |          27123
```

### Level 1 by Period

```sql
-- Latest period only
SELECT * FROM mart.v_latest_period;

-- Specific period
SELECT * FROM mart.v_level1_by_period
WHERE "Period" = '2025-10';

-- Multiple periods
SELECT * FROM mart.v_level1_by_period
WHERE "Period" IN ('2025-09', '2025-10', '2025-11')
ORDER BY "Period" DESC, "SKU ID";

-- Period range
SELECT * FROM mart.v_level1_by_period
WHERE "Period" >= '2025-09' AND "Period" <= '2025-11';
```

### Compare Periods

```sql
-- Compare September vs October
SELECT * FROM mart.compare_periods('2025-09', '2025-10');
```

Output columns:
- `SKU ID`, `Merchant`
- `Period 1`, `Period 1 Amount Received`, `Period 1 Variance`
- `Period 2`, `Period 2 Amount Received`, `Period 2 Variance`
- `Change in Amount Received`, `Change in Variance`

**Example Query:**

```sql
-- SKUs with increasing variance
SELECT *
FROM mart.compare_periods('2025-09', '2025-10')
WHERE "Change in Variance" > 0
ORDER BY "Change in Variance" DESC
LIMIT 20;
```

### Load History

```sql
SELECT * FROM mart.v_load_history;
```

Shows:
- Table name
- Source file path
- Rows loaded
- Load timestamp
- Load duration

## Period Helper Functions

### Period Range

```sql
-- Get all periods between dates
SELECT * FROM mart.period_range('2025-09', '2025-11');
```

Output:
```
 period_ym
-----------
 2025-09
 2025-10
 2025-11
```

**Use in queries:**

```sql
-- Level 1 for specific period range
SELECT l1.*
FROM mart.v_level1_by_period l1
WHERE l1."Period" IN (
  SELECT period_ym FROM mart.period_range('2025-09', '2025-10')
);
```

## Web Interface Integration

The web query interface automatically includes period queries:

**New Predefined Queries:**
- "Available Periods" - List all loaded periods
- "Period Coverage Summary" - Show data coverage by period
- "Latest Period Only" - Filter to most recent month
- "Load History" - Show file loading timestamps

**Custom Queries:**

```sql
-- In web interface query box
SELECT * FROM mart.v_level1_by_period
WHERE "Period" = '2025-10'
  AND "Variance" > 0.02
ORDER BY "Variance" DESC;
```

## Common Workflows

### Monthly Update Workflow

```bash
# 1. Place new month's CSV files
ls data/inc_data/*2025-11.csv
# external_accounts_2025-11.csv
# va_txn_2025-11.csv
# repmt_sku_2025-11.csv
# repmt_sales_2025-11.csv

# 2. Append new period (keeps previous months)
make etl-append-period

# 3. Verify periods loaded
make periods-list
#  Period  | Source Count | Sources
# ---------+--------------+---------
#  2025-11 |            4 | ...
#  2025-10 |            4 | ...
#  2025-09 |            4 | ...

# 4. Query latest period
make sql CMD="SELECT * FROM mart.v_latest_period LIMIT 10;"
```

### Historical Analysis Workflow

```bash
# 1. Load multiple historical periods
# Place all CSV files in data/inc_data/

# 2. Load all periods at once
make load-multi-period

# 3. Check coverage
make periods-coverage

# 4. Compare periods in web interface
# Navigate to http://localhost:8080
# Run: SELECT * FROM mart.compare_periods('2025-09', '2025-11')

# 5. Export period comparison
make sqlf FILE=<(cat <<'EOF'
\copy (
  SELECT * FROM mart.compare_periods('2025-09', '2025-11')
  WHERE ABS("Change in Variance") > 0.02
) TO '/tmp/period_variance_changes.csv' CSV HEADER
EOF
)
```

### Period Cleanup Workflow

```bash
# Remove old periods (PostgreSQL doesn't have built-in period deletion)
# Option 1: Delete specific period data
make sql CMD="
DELETE FROM raw.external_accounts WHERE source_file LIKE '%2025-08%';
DELETE FROM raw.va_txn WHERE source_file LIKE '%2025-08%';
DELETE FROM raw.repmt_sku WHERE source_file LIKE '%2025-08%';
DELETE FROM raw.repmt_sales WHERE source_file LIKE '%2025-08%';
"

# Option 2: Full reload (replace mode)
# Remove old CSV files
rm data/inc_data/*2025-08.csv

# Reload all remaining periods
make load-multi-period  # Replace mode
```

## Advanced Usage

### Aggregate Across All Periods

```sql
-- Total amount received by SKU across all periods
SELECT
  "SKU ID",
  "Merchant",
  COUNT(DISTINCT "Period") AS "Periods with Data",
  SUM("Amount Received") AS "Total Amount Received All Periods",
  SUM("Variance") AS "Total Variance All Periods",
  AVG("Amount Received") AS "Avg Amount Received Per Period"
FROM mart.v_level1_by_period
GROUP BY "SKU ID", "Merchant"
ORDER BY "Total Amount Received All Periods" DESC;
```

### Month-over-Month Growth

```sql
WITH monthly AS (
  SELECT
    "SKU ID",
    "Merchant",
    "Period",
    "Amount Received",
    LAG("Amount Received") OVER (
      PARTITION BY "SKU ID" ORDER BY "Period"
    ) AS prev_amount
  FROM mart.v_level1_by_period
)
SELECT
  "SKU ID",
  "Merchant",
  "Period",
  "Amount Received",
  prev_amount AS "Previous Month Amount",
  ("Amount Received" - prev_amount) AS "MoM Change",
  CASE
    WHEN prev_amount > 0 THEN
      ROUND((("Amount Received" - prev_amount) / prev_amount * 100), 2)
    ELSE NULL
  END AS "MoM % Change"
FROM monthly
WHERE prev_amount IS NOT NULL
ORDER BY "Period" DESC, "MoM % Change" DESC;
```

### Period-Based Partitioning (Future Enhancement)

For very large datasets, consider partitioning raw tables by period:

```sql
-- Create monthly partitions (future optimization)
CREATE TABLE raw.va_txn_2025_09 PARTITION OF raw.va_txn
  FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

CREATE TABLE raw.va_txn_2025_10 PARTITION OF raw.va_txn
  FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
```

Currently not needed for datasets <1M rows per period.

## Troubleshooting

### Issue: Missing Period in Views

**Cause:** Materialized views not refreshed after loading

**Solution:**
```bash
make refresh-optimized
make periods-list
```

### Issue: Duplicate Data in Period

**Cause:** Loaded same CSV files multiple times in append mode

**Solution:**
```bash
# Check load history
make sql CMD="SELECT * FROM mart.v_load_history ORDER BY \"Load Time\" DESC;"

# If duplicates confirmed, reload in replace mode
make load-multi-period
```

### Issue: Period Comparison Returns Empty

**Cause:** One or both periods not actually loaded

**Solution:**
```bash
# Verify periods exist
make periods-list

# Check specific period
make sql CMD="SELECT * FROM mart.v_level1_by_period WHERE \"Period\" = '2025-10' LIMIT 1;"
```

### Issue: Wrong Period Extracted from Filename

**Cause:** Filename doesn't match YYYY-MM pattern

**Solution:**
```bash
# Verify filenames follow pattern
ls -1 data/inc_data/*.csv
# Should show: {table}_YYYY-MM.csv

# Rename files if needed
mv data/inc_data/va_txn_september.csv data/inc_data/va_txn_2025-09.csv
```

## Performance Considerations

### Incremental vs Full Reload

**Append Mode (Incremental):**
- ✅ Faster (only loads new files)
- ✅ Preserves history
- ⚠️ Can accumulate duplicates if not careful
- Use for: Monthly updates

**Replace Mode (Full):**
- ✅ Clean slate, no duplicates
- ✅ Ensures consistency
- ⚠️ Slower (reloads everything)
- Use for: Initial load, cleanup, fixing errors

### Query Performance by Period

**Materialized views already include `period_ym` column:**
- Indexed for fast filtering
- Use `WHERE period_ym = '2025-10'` for best performance
- Avoid `LIKE` patterns on period column

**Optimized Period Query:**
```sql
-- Fast (uses index)
SELECT * FROM mart.v_level1_by_period
WHERE "Period" = '2025-10';

-- Slow (sequential scan)
SELECT * FROM mart.v_level1_by_period
WHERE "Period" LIKE '2025%';
```

### Refresh Strategy

After loading new periods, always refresh materialized views:

```bash
# Standard refresh
make refresh

# Optimized refresh with metrics
make refresh-optimized
```

Refresh performance scales with data volume:
- 1 period: ~2-3 seconds
- 3 periods: ~4-6 seconds
- 12 periods: ~15-25 seconds

## Integration with Existing Workflows

### Single-Period Workflow (Backward Compatible)

Existing workflows continue to work - they just use the latest period:

```bash
# Standard ETL (loads latest files only)
make etl-verify-fast

# Queries default to all periods or latest
SELECT * FROM mart.v_level1;           # All periods
SELECT * FROM mart.v_latest_period;    # Latest only
```

### Multi-Period Workflow (New)

```bash
# Multi-period ETL
make etl-multi-period    # Full load
make etl-append-period   # Incremental

# Period-aware queries
SELECT * FROM mart.v_level1_by_period WHERE "Period" = '2025-10';
SELECT * FROM mart.compare_periods('2025-09', '2025-10');
```

## Commands Reference

```bash
# Loading
make load-multi-period          # Load all periods (replace)
make load-multi-append          # Add new periods (append)
make etl-multi-period           # Full multi-period ETL
make etl-append-period          # Incremental period append

# Period Management
make deploy-period-views        # Deploy period views/functions
make periods-list               # Show available periods
make periods-coverage           # Show period coverage summary

# Queries
make sql CMD="SELECT * FROM mart.v_available_periods;"
make sql CMD="SELECT * FROM mart.v_latest_period LIMIT 10;"
make sql CMD="SELECT * FROM mart.compare_periods('2025-09', '2025-10');"

# Refresh
make refresh-optimized          # Refresh materialized views
```

## File Organization Best Practices

```bash
# Recommended structure
data/inc_data/
├── 2025-09/
│   ├── external_accounts_2025-09.csv
│   ├── va_txn_2025-09.csv
│   ├── repmt_sku_2025-09.csv
│   └── repmt_sales_2025-09.csv
├── 2025-10/
│   ├── external_accounts_2025-10.csv
│   ├── va_txn_2025-10.csv
│   ├── repmt_sku_2025-10.csv
│   └── repmt_sales_2025-10.csv
└── 2025-11/
    ├── external_accounts_2025-11.csv
    ├── va_txn_2025-11.csv
    ├── repmt_sku_2025-11.csv
    └── repmt_sales_2025-11.csv

# Or flat structure (also supported)
data/inc_data/
├── external_accounts_2025-09.csv
├── va_txn_2025-09.csv
├── repmt_sku_2025-09.csv
├── repmt_sales_2025-09.csv
├── external_accounts_2025-10.csv
├── va_txn_2025-10.csv
└── ...
```

Both structures work - the loader finds all files matching the pattern.
