# Quick Start Guide

## One Command Setup

Run the complete ETL pipeline with a single command:

```bash
make etl-complete
```

**What it does:**
1. ✅ Starts PostgreSQL database (Docker)
2. ✅ Initializes database schema
3. ✅ Deploys optimized views
4. ✅ Loads CSV data (parallel)
5. ✅ Generates SKU mappings
6. ✅ Refreshes materialized views
7. ✅ Starts web interface

**Time:** ~3 minutes

**Output:**
```
==========================================
Complete ETL Pipeline
==========================================

Step 1/7: Starting database...
Step 2/7: Initializing database schema...
Step 3/7: Deploying optimized views...
Step 4/7: Loading CSV data...
Step 5/7: Generating and loading mappings...
Step 6/7: Refreshing materialized views...
Step 7/7: Starting web interface...

==========================================
✓ ETL Pipeline Complete!
==========================================

Web Interface: http://localhost:8080
Database:      postgresql://appuser:changeme@localhost:5433/appdb

Quick commands:
  make counts           - View row counts
  make periods-list     - Show loaded periods
  make etl-reload       - Reload ETL (new data)
  make down             - Stop everything
```

## Prerequisites

### Windows (Git Bash)

1. **Fix line endings (one-time):**
```bash
bash scripts/setup_gitbash.sh
```

2. **Verify .env file:**
```bash
cat .env
# Should show: PGHOST=localhost, PGPORT=5433
# Should NOT have: DB_MODE=host
```

### CSV Files

Place your CSV files in `data/inc_data/`:

```bash
data/inc_data/
├── external_accounts_2025-09.csv
├── va_txn_2025-09.csv
├── repmt_sku_2025-09.csv
└── repmt_sales_2025-09.csv
```

**Naming pattern:** `{table}_YYYY-MM.csv` or `{table}_YYYY-MM.csv.gz`

## Run Everything

```bash
# Single command for complete setup
make etl-complete
```

Wait ~3 minutes, then open: **http://localhost:8080**

## Web Interface Features

### 🔄 Reload ETL Button

Click **"🔄 Reload ETL"** to reload data without restarting:
- Reloads CSV files
- Regenerates mappings
- Refreshes all views
- Takes 30-60 seconds

**Use when:**
- You add new CSV files
- You update existing CSV files
- You want to refresh data

### ℹ️ Status Button

Click **"ℹ️ Status"** to see:
- Row counts per table
- Available periods
- Last refresh time
- System timestamp

### Predefined Queries

Select from dropdowns:
- **Period Management** - View loaded periods
- **Sheet1** - Level 1 reconciliation
- **Sheet2a** - Waterfall execution
- **Sheet2b** - UI vs Cashflow

### Custom Queries

Write any SELECT query:
```sql
SELECT * FROM mart.v_level1
WHERE "Variance" > 0.02
ORDER BY "Variance" DESC
LIMIT 10
```

### Conditional Formatting

- **Red** - Negative values
- **Yellow** - Variance > 0.02
- **Gray** - Zero/default values

## Common Commands

```bash
# Complete pipeline
make etl-complete

# Reload data (keep database running)
make etl-reload

# View row counts
make counts

# Show loaded periods
make periods-list

# Stop everything
make down

# Restart everything
make down && make etl-complete

# View logs
make logs              # Database logs
make webapp-logs       # Web interface logs

# Run custom SQL
make sql CMD="SELECT COUNT(*) FROM mart.v_level1;"
```

## Reload ETL (Add New Data)

### From Command Line

```bash
# Add new CSV files to data/inc_data/
cp /path/to/new/*.csv data/inc_data/

# Reload ETL
make etl-reload
```

**Output:**
```
==========================================
Reloading ETL Data
==========================================

Step 1/4: Loading CSV data...
Step 2/4: Regenerating mappings...
Step 3/4: Refreshing views...
Step 4/4: Validating...

==========================================
✓ ETL Reload Complete!
==========================================
```

### From Web Interface

1. Add new CSV files to `data/inc_data/`
2. Open http://localhost:8080
3. Click **"🔄 Reload ETL"**
4. Confirm the action
5. Wait 30-60 seconds
6. Click **"ℹ️ Status"** to verify new data

## Multi-Period Support

Load multiple months of data:

```bash
# Place all periods
data/inc_data/
├── external_accounts_2025-09.csv
├── va_txn_2025-09.csv
├── ...
├── external_accounts_2025-10.csv
├── va_txn_2025-10.csv
└── ...

# Load all periods
make load-multi-period

# Or incremental (append new period)
make load-multi-append

# View periods
make periods-list
```

## Troubleshooting

### `: command not found`
```bash
# Fix line endings
bash scripts/setup_gitbash.sh
```

### `could not translate host name "postgres"`
```bash
# Check .env file
cat .env
# Should NOT have: DB_MODE=host
# Should have: PGHOST=localhost, PGPORT=5433

# Fix if needed:
sed -i '/DB_MODE=host/d' .env
```

### Database won't start
```bash
# Check Docker
docker ps

# Restart
make down
make up-wait
```

### Web interface not accessible
```bash
# Check if running
docker ps | grep webapp

# Restart
make webapp-down
make webapp-up

# View logs
make webapp-logs
```

### No data showing
```bash
# Check row counts
make counts

# Refresh views
make refresh-optimized

# Reload data
make etl-reload
```

## Development Workflow

### Daily Use

```bash
# Morning: Start everything
make etl-complete

# Work with data via web interface
# http://localhost:8080

# Evening: Stop everything
make down
```

### Add New Data

```bash
# Add new CSV file
cp new_data.csv data/inc_data/

# Option 1: Reload from command line
make etl-reload

# Option 2: Reload from web interface
# Click "🔄 Reload ETL" button
```

### Check Status

```bash
# Command line
make counts
make periods-list

# Web interface
# Click "ℹ️ Status" button
```

## Next Steps

- **Test it:** `make etl-complete`
- **Add data:** Place CSV files in `data/inc_data/`
- **Reload:** Click "🔄 Reload ETL" or run `make etl-reload`
- **Query:** Use predefined queries or write custom SQL
- **Compare periods:** Use period comparison queries
- **Export:** Download results as CSV

## Documentation

- **This file** - Quick start
- **README.md** - Full documentation
- **GITBASH_QUICKSTART.md** - Git Bash on Windows
- **docs/MULTI_PERIOD.md** - Multi-period guide
- **docs/VIEW_OPTIMIZATION.md** - Performance tuning
- **docs/CONNECTION_FIX.md** - Connection troubleshooting
- **docs/TEST_RUNS.md** - Test commands

## Summary

**Single command setup:**
```bash
make etl-complete
```

**Reload data (command line):**
```bash
make etl-reload
```

**Reload data (web interface):**
- Click "🔄 Reload ETL" at http://localhost:8080

**Stop everything:**
```bash
make down
```

**That's it!** 🎉
