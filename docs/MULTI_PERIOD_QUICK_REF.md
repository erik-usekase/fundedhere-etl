# Multi-Period Quick Reference

## File Naming

```bash
# Required pattern: {table}_YYYY-MM.csv[.gz]
data/inc_data/
├── external_accounts_2025-09.csv
├── va_txn_2025-09.csv.gz         # Compressed files supported
├── repmt_sku_2025-10.csv
└── repmt_sales_2025-11.csv
```

## Commands

```bash
# Load all periods (replace existing)
make load-multi-period

# Add new period (preserve existing)
make load-multi-append

# Full multi-period ETL
make etl-multi-period

# Incremental update
make etl-append-period

# List loaded periods
make periods-list

# Show coverage by period
make periods-coverage

# Deploy period views
make deploy-period-views
```

## Essential Queries

```sql
-- Available periods
SELECT * FROM mart.v_available_periods;

-- Latest period only
SELECT * FROM mart.v_latest_period;

-- Specific period
SELECT * FROM mart.v_level1_by_period WHERE "Period" = '2025-10';

-- Period range
SELECT * FROM mart.v_level1_by_period
WHERE "Period" BETWEEN '2025-09' AND '2025-11';

-- Compare two periods
SELECT * FROM mart.compare_periods('2025-09', '2025-10');

-- Period coverage
SELECT * FROM mart.v_period_coverage;

-- Load history
SELECT * FROM mart.v_load_history;
```

## Typical Workflows

### Initial Load (All Historical Data)

```bash
# 1. Place all CSV files
ls data/inc_data/*.csv

# 2. Load everything
make up-wait
make etl-multi-period

# 3. Verify
make periods-list
```

### Monthly Update (Add New Period)

```bash
# 1. Place new month's files
ls data/inc_data/*2025-11.csv

# 2. Append (keeps history)
make etl-append-period

# 3. Verify
make periods-coverage
```

### Period Comparison Analysis

```bash
# 1. Compare in SQL
make sql CMD="SELECT * FROM mart.compare_periods('2025-09', '2025-10') WHERE \"Change in Variance\" > 0.02;"

# 2. Or use web interface
make webapp-up
# Navigate to http://localhost:8080
# Select: Period Comparison queries
```

## Troubleshooting

```bash
# Missing period? Refresh materialized views
make refresh-optimized

# Check what's loaded
make sql CMD="SELECT * FROM mart.v_load_history;"

# Duplicate data? Reload in replace mode
make load-multi-period

# Wrong period in results? Check filename pattern
ls -1 data/inc_data/*.csv | grep -E '[0-9]{4}-[0-9]{2}'
```

## Performance Tips

- **Use indexed period column**: `WHERE "Period" = '2025-10'` (fast)
- **Avoid LIKE**: `WHERE "Period" LIKE '2025%'` (slow)
- **Refresh after loading**: Always run `make refresh-optimized` after loading new periods
- **Incremental for speed**: Use append mode for monthly updates (faster than full reload)

## Full Documentation

See **[MULTI_PERIOD.md](MULTI_PERIOD.md)** for complete guide including:
- Advanced queries (MoM growth, aggregations)
- Performance optimization
- Integration with web interface
- File organization best practices
