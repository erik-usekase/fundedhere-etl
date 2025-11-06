# Quick Start Guide

Get the FundedHere ETL pipeline running in under 5 minutes.

## Prerequisites

1. **Docker Desktop** - Running and accessible
2. **Git Bash** (Windows) or terminal (Mac/Linux)
3. **CSV Data Files** - Place in `data/inc_data/` directory

### Required CSV Files

```bash
data/inc_data/
├── external_accounts_2025-09.csv
├── va_txn_2025-09.csv
├── repmt_sku_2025-09.csv
└── repmt_sales_2025-09.csv
```

**Naming pattern:** `{table}_YYYY-MM.csv` or `{table}_full.csv`

## Quick Start (3 Commands)

**No local installation required - everything runs in Docker!**

```bash
# 1. Start database
make up-wait

# 2. Load data (in Docker container)
make container-etl-load

# 3. Query the data (using docker exec - works everywhere)
docker exec app-postgres psql -U appuser -d appdb -c "SELECT COUNT(*) FROM mart.v_level1;"
```

**Note:** Data persists in a Docker named volume. You can run `make down` and `make up-wait` without losing data!

**Time:** ~2 minutes total

**Result:** Database loaded with 366 SKUs across 3 reconciliation views.

## What Just Happened?

1. **`make up-wait`** - Started PostgreSQL database in Docker, waited for it to be healthy
2. **`make container-etl-verify`** - Ran full ETL pipeline:
   - Prepared CSV files (normalized headers)
   - Initialized database schema (5 initdb + 8 phase2 SQL files)
   - Loaded 32,049 rows across 4 tables (parallel)
   - Loaded 366 SKU-VA mappings
   - Refreshed materialized views
   - Validated all 3 sheets have 366 rows

3. **`make sql`** - Queried the final view

## Host Machine ETL (Alternative)

Run ETL commands directly on your machine (requires uv):

```bash
# Install dependencies (one-time)
uv sync

# Run ETL pipeline step-by-step
uv run fundedhere-etl prep              # Prepare CSVs
uv run fundedhere-etl bootstrap         # Initialize schema
uv run fundedhere-etl load              # Load data (parallel)
uv run fundedhere-etl load-mapping      # Load mappings
uv run fundedhere-etl refresh           # Refresh views
```

## Available Commands

### Python CLI (Host)

```bash
uv run fundedhere-etl --help            # Show all commands
uv run fundedhere-etl prep              # Prepare CSV files
uv run fundedhere-etl load              # Load CSVs (parallel)
uv run fundedhere-etl bootstrap         # Initialize schema
uv run fundedhere-etl refresh           # Refresh materialized views
uv run fundedhere-etl load-mapping      # Load SKU-VA mappings
uv run fundedhere-etl pipeline          # Complete ETL workflow
```

### Docker Commands (Work Everywhere - Recommended)

```bash
# Database management
make up-wait               # Start database and wait until ready ✅
make down                  # Stop database ✅
make logs                  # View database logs ✅

# ETL pipeline (runs in Docker container)
make container-etl-verify  # Full ETL + tests ✅ RECOMMENDED
make container-etl-load    # Load data only (skip tests) ✅

# Queries (using docker exec)
docker exec app-postgres psql -U appuser -d appdb -c "SELECT COUNT(*) FROM mart.v_level1;"
docker exec -it app-postgres psql -U appuser -d appdb  # Interactive session
```

### Make Targets (Require Local psql/Python/uv)

**⚠️ These commands require local tools and may fail if not installed:**

```bash
make sql CMD="SELECT..."   # Run custom SQL (needs psql)
make counts                # Show row counts (needs psql)
make etl-prep              # Prepare CSV files (needs uv/Python)
make etl-load              # Load data (needs uv/Python + psql)
make help                  # Show all targets
```

**Use `docker exec` commands above instead for guaranteed compatibility!**

## Query the Data

### Using docker exec (Recommended - Works Everywhere)

```bash
# Quick query - Row counts
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT 'v_level1' as view, COUNT(*) as rows FROM mart.v_level1
UNION ALL SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;"

# Quick query - Sample data
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT * FROM mart.v_level1 LIMIT 5;"

# Interactive session
docker exec -it app-postgres psql -U appuser -d appdb
```

### Using Database Tools

Connect pgAdmin, HeidiSQL, DBeaver, etc.:

- **Host:** localhost
- **Port:** 5433 (not 5432!)
- **Database:** appdb
- **Username:** appuser
- **Password:** changeme

See [docs/DATABASE_TOOLS.md](docs/DATABASE_TOOLS.md) for detailed setup.

## View the Results

### Three Reconciliation Views

```sql
-- Level 1: Cash vs. Ledger (366 SKUs)
SELECT * FROM mart.v_level1 LIMIT 10;

-- Level 2a: Transaction Waterfall (366 SKUs)
SELECT * FROM mart.v_level2a LIMIT 10;

-- Level 2b: Payment Component Summary (366 SKUs)
SELECT * FROM mart.v_level2b LIMIT 10;
```

### Check Row Counts

```bash
make counts
```

**Expected output:**
```
 schema_table          | row_count
-----------------------+-----------
 raw.external_accounts |      2718
 raw.va_txn            |     28599
 raw.repmt_sku         |       366
 raw.repmt_sales       |       366
 mart.v_level1         |       366
 mart.v_level2a        |       366
 mart.v_level2b        |       366
```

## Reload New Data

```bash
# 1. Add new CSV files to data/inc_data/
cp /path/to/new/*.csv data/inc_data/

# 2. Reload ETL
make container-etl-verify

# Or step-by-step on host:
uv run fundedhere-etl prep
uv run fundedhere-etl load --mode parallel --truncate
uv run fundedhere-etl refresh
```

## Development Workflow

### Morning: Start Up

```bash
make up-wait                  # Start database
make container-etl-verify     # Load data
```

### During Day: Work with Data

```bash
# Query via SQL tools (port 5433)
# Or command line:
make sql CMD="SELECT * FROM mart.v_level1 WHERE \"Variance\" > 0.02;"
```

### Evening: Shutdown

```bash
make down                     # Stop database
```

## Troubleshooting

### Database Connection Refused

```bash
# Check if database is running
docker ps | grep postgres

# If not running:
make up-wait
```

### No Data in Views

```bash
# Check CSV files exist
ls -la data/inc_data/*.csv

# Check row counts
make counts

# Reload data
make container-etl-verify
```

### Windows Git Bash Issues

```bash
# Fix line endings (one-time)
bash scripts/setup_gitbash.sh

# Verify .env file
cat .env
# Should show: PGHOST=localhost, PGPORT=5433
```

### Port 5433 Already in Use

Change port in `.env`:
```bash
POSTGRES_PORT=5434
```

Then restart:
```bash
make down && make up-wait
```

## Next Steps

### Explore the Data

- **Connect database tool** - See [docs/DATABASE_TOOLS.md](docs/DATABASE_TOOLS.md)
- **Run example queries** - See README.md Demo Queries section
- **Review schemas** - Explore `raw.*`, `ref.*`, `core.*`, `mart.*`

### Understand the Architecture

- **Architecture overview** - [docs/EXISTING_ANALYSIS.md](docs/EXISTING_ANALYSIS.md)
- **Reconciliation logic** - [docs/RECONCILIATION_ANALYSIS.md](docs/RECONCILIATION_ANALYSIS.md)
- **CSV mappings** - [docs/FORMULA_MAPPING.md](docs/FORMULA_MAPPING.md)

### Advanced Features

- **Performance tuning** - [docs/VIEW_OPTIMIZATION.md](docs/VIEW_OPTIMIZATION.md)
- **Multi-period loading** - [docs/MULTI_PERIOD.md](docs/MULTI_PERIOD.md)
- **Testing guide** - [docs/TESTING.md](docs/TESTING.md)

## Summary

**Fastest path:**
```bash
make up-wait && make container-etl-verify
```

**Query data:**
```bash
make sql CMD="SELECT * FROM mart.v_level1 LIMIT 10;"
```

**Database tools:**
- Host: localhost
- Port: 5433
- DB: appdb / User: appuser / Pass: changeme

**Shutdown:**
```bash
make down
```

That's it! 🎉

For detailed documentation, see [README.md](README.md).
