# FundedHere Reconciliation ETL

A production-focused pipeline that converts FundedHere’s reconciliation CSV exports into a trustworthy Postgres data product. The goal is simple: ingest the four monthly extracts, preserve the business logic embedded in those files, and expose the Level‑1/Level‑2 views (and their tests) as fast, queryable database objects.

## Level Overview
- **Level 1 — Cash vs. Ledger**: aligns bank pulls, virtual-account inflows, and sales proceeds per SKU/VA pair so cash movement gaps surface immediately.
- **Level 2a — Waterfall Execution**: breaks each repayment into management fees, admin fees, interest, principal, and SPAR buckets using the repayment expectations CSV, then compares paid vs. expected amounts.
- **Level 2b — UI vs. Cashflow**: contrasts UI-facing repayment totals with the cash ledger to highlight category-level deltas for downstream consumers.

## Product Outcomes
- **✅ Full Excel Structure Match**: All views match Excel workbook structure:
  - `mart.v_level1`: 8 columns, 366 rows (Sheet 1)
  - `mart.v_level2a`: 49 columns, 366 rows (Sheet 2a - Expected/Paid/Outstanding breakdown)
  - `mart.v_level2b`: 32 columns, 366 rows (Sheet 2b - UI vs CF reconciliation)
- **✅ ISO Date Format**: Standardized on YYYY-MM-DD format matching Excel source
- **Reference parity**: Views fully implement business logic from Excel formulas
- **Explorable data model**: inputs land in `raw.*`, mappings live in `ref.*`, typed transforms sit in `core.*`, business consumers query `mart.*`
- **Cross-platform support**: Docker-based ETL works on Windows/WSL, Linux, macOS
- **Agent-ready**: every row carries `merchant`, `sku_id`, and `period_ym` for time-slice queries

### Key Differences Between Views

The three reconciliation views use different definitions of "Amount Received":

| View | Amount Received | Focus |
|------|----------------|-------|
| **v_level1** | ONLY `merchant-repayment` transactions | Cash received from merchants |
| **v_level2a** | ALL inflows EXCEPT `note-issued-transfer-to-sku` | Total fund flow including cross-SKU transfers |
| **v_level2b** | Same as v_level2a | Payment component breakdown |

This difference is intentional - Sheet 1 tracks cash from merchants, while Sheet 2a/2b track total fund movement including internal transfers.

## Documentation

### Quick Start
- [**QUICKSTART.md**](QUICKSTART.md) - Get running in 5 minutes (3 commands)

### User Guides
- [**docs/SAMPLE_QUERIES.md**](docs/SAMPLE_QUERIES.md) 📊 - SQL queries for all three views (Sheet 1, 2a, 2b)
- [**docs/REMOTE_DATABASE.md**](docs/REMOTE_DATABASE.md) 🌐 - Connect to external PostgreSQL (AWS RDS, Azure, GCP)
- [**docs/MULTI_PERIOD.md**](docs/MULTI_PERIOD.md) 📅 - Multi-period reconciliation support
- [**docs/MULTI_PERIOD_QUICK_REF.md**](docs/MULTI_PERIOD_QUICK_REF.md) - Quick reference for multi-period

### Technical Reference
- [**.build/VERIFICATION_COMPLETE.md**](.build/VERIFICATION_COMPLETE.md) ✅ - Complete verification summary (Nov 6, 2025)
- [**.build/agent_state.md**](.build/agent_state.md) 📝 - Current system state and recent changes

## Data Sources (CSV extracts)
1. **External Accounts (Merchant)** → `raw.external_accounts`
2. **VA Transaction Report (All)** → `raw.va_txn`
3. **Repmt-SKU (by Note)** → `raw.repmt_sku`
4. **Repmt-Sales Proceeds (by Note)** → `raw.repmt_sales`

### Multi-Period Support 📅

**The system fully supports multiple months of data**, not just the current period:

```bash
# Load multiple periods at once
data/inc_data/
├── external_accounts_2025-09.csv  ← September
├── va_txn_2025-09.csv
├── repmt_sku_2025-09.csv
├── repmt_sales_2025-09.csv
├── external_accounts_2025-10.csv  ← October
├── va_txn_2025-10.csv
└── ...

# Incremental load (preserves previous months)
make load-multi-append

# Query by period
SELECT * FROM mart.v_level1_by_period WHERE "Period" = '2025-10';

# Compare periods
SELECT * FROM mart.compare_periods('2025-09', '2025-10');
```

**See [docs/MULTI_PERIOD.md](docs/MULTI_PERIOD.md) for complete multi-period guide.**

### Fast Direct CSV Loading (Recommended)

Place the monthly CSV exports in `data/inc_data/` before running the ETL. The system automatically discovers files matching these patterns:

| Source | Pattern | Example |
|--------|---------|---------|
| External Accounts | `external_accounts_*.csv` | `external_accounts_2025-09.csv` |
| VA Transaction Report | `va_txn_*.csv` | `va_txn_2025-09.csv` |
| Repmt-SKU (by Note) | `repmt_sku_*.csv` | `repmt_sku_2025-09.csv` |
| Repmt-Sales Proceeds (by Note) | `repmt_sales_*.csv` | `repmt_sales_2025-09.csv` |

**Key Features:**
- ✅ **No preprocessing required** - loads CSVs directly to PostgreSQL
- ✅ **Auto-detects headers** - maps CSV columns to database columns automatically
- ✅ **Parallel loading** - loads all 4 files simultaneously for maximum speed
- ✅ **Large file optimized** - handles multi-GB CSVs efficiently
- ✅ **Gzip support** - automatically decompresses `.csv.gz` files
- ✅ **Optimized settings** - PostgreSQL tuned for bulk operations

**Quick Start:**
```bash
# 1. Validate CSV structure (optional but recommended)
make container-etl-verify || scripts/validate_csv_structure.sh data/inc_data

# 2. Fast parallel load (recommended)
make container-etl-verify-fast  # Full pipeline with fast loader

# Or step-by-step:
make up && make up-wait
make load-fast                   # Parallel load all CSVs
make prep-map && make load-mapping
make refresh
make validate-views
```

**Performance:**
- Old method (Python preprocessing): ~2-3 minutes for typical datasets
- New method (direct parallel): ~15-30 seconds for same datasets
- **5-10x faster** for large CSV files (>100k rows per file)

If a required file is missing, the loader exits with an explicit error so the pipeline never progresses with empty tables.

Mappings required by the CSV exports live in version control:
- `ref.note_sku_va_map` — SKU/VA alignment (generated from the Level‑1 reference export).
- `ref.remarks_category_map` — remark → waterfall category (admin fees, sr/jr principal, SPAR, etc.).

Architecture and lineage details: see `docs/EXISTING_ANALYSIS.md` and `docs/RECONCILIATION_ANALYSIS.md`.

For comprehensive loading documentation and troubleshooting: **[FAST_LOADING.md](docs/FAST_LOADING.md)**

### Optimized Views for Query Performance (10-100x Faster)

After loading data, deploy **optimized view definitions** for dramatically faster query performance:

**Quick Start:**
```bash
make enable-optimized-views  # Deploy optimized SQL
make refresh-optimized       # Parallel refresh with timing
```

**Key Features:**
- ✅ **10-100x faster queries** - uses indexed materialized views instead of raw tables
- ✅ **Pre-computed categories** - eliminates runtime pattern matching
- ✅ **Strategic indexes** - on sku_id, category_code, va_number
- ✅ **Timing metrics** - monitor refresh performance
- ✅ **Same results** - views produce identical output, just faster

**Performance:**
- Original v_level1 query: ~4-30 seconds (large datasets)
- Optimized v_level1 query: ~0.1-0.5 seconds (same datasets)
- **10-100x speedup** on typical queries

**How It Works:**
- Original views read from unindexed `raw.*` tables with runtime categorization
- Optimized views read from indexed `core.mv_*` materialized views with pre-computed categories
- Query planner uses index scans instead of sequential scans

For comprehensive optimization documentation: **[VIEW_OPTIMIZATION.md](docs/VIEW_OPTIMIZATION.md)**

### Multi-Period Support (Historical Data & Incremental Loading)

Load and query data across **multiple date periods** for historical analysis and trend tracking:

**Quick Start:**
```bash
# Organize CSV files by period: {table}_YYYY-MM.csv
# Example: va_txn_2025-09.csv, va_txn_2025-10.csv

# Load all periods
make etl-multi-period

# Or incrementally add new period
make etl-append-period

# Query by period
make sql CMD="SELECT * FROM mart.v_latest_period;"
make sql CMD="SELECT * FROM mart.compare_periods('2025-09', '2025-10');"
```

**Key Features:**
- ✅ **Multiple periods** - Load data from different months simultaneously
- ✅ **Incremental loading** - Append new periods without deleting history
- ✅ **Period filtering** - Query specific date ranges
- ✅ **Period comparison** - Compare SKU metrics across months
- ✅ **Load tracking** - Monitor which files were loaded and when

**Workflows:**
```bash
# Monthly update (preserves history)
make etl-append-period           # Adds new month, keeps old data
make periods-list                # Show loaded periods

# Full reload (fresh start)
make load-multi-period           # Replace all data
make periods-coverage            # Show coverage by period
```

For comprehensive multi-period documentation: **[MULTI_PERIOD.md](docs/MULTI_PERIOD.md)**

## Quick Start

### Docker-Only Setup (Recommended - No Local Installation)

**Requirements:** Docker Desktop only (no Python, uv, or other tools needed)

```bash
# 1. Start database
make up-wait

# 2. Load all data (runs in container)
make container-etl-load

# 3. Verify (using docker exec - works everywhere)
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT 'v_level1' as view, COUNT(*) as rows FROM mart.v_level1
UNION ALL SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;"
```

**Time:** ~2 minutes
**Result:** 366 SKUs loaded across all 3 reconciliation views

The `container-etl-load` command runs everything inside Docker:
- Prepares CSV files
- Bootstraps schema (13 SQL files)
- Loads data in parallel (~32k rows)
- Loads mappings (366 SKUs)
- Refreshes views

### Alternative: Full Setup with Web Interface

**One command to run everything:**

```bash
make etl-complete
```

This single command will:
1. Start PostgreSQL database
2. Initialize schema
3. Deploy optimized views
4. Load CSV data
5. Generate mappings
6. Refresh views
7. Start web interface at **http://localhost:8080**

Takes ~3 minutes. See **[QUICKSTART.md](QUICKSTART.md)** for details.

### Git Bash on Windows?

Fix line endings first (one-time):

```bash
bash scripts/setup_gitbash.sh
```

See **[GITBASH_QUICKSTART.md](GITBASH_QUICKSTART.md)** for complete Git Bash guide.

### Prerequisites

1. **Docker Desktop** running
2. **CSV files** in `data/inc_data/`:
   ```
   external_accounts_2025-09.csv
   va_txn_2025-09.csv
   repmt_sku_2025-09.csv
   repmt_sales_2025-09.csv
   ```
3. **`.env` file** configured (see below if needed)

### .env Configuration (Usually Auto-Created)

If you get connection errors, verify `.env` exists:

```bash
cat .env
# Should show: PGHOST=localhost, PGPORT=5433
# Should NOT show: DB_MODE=host
```

If missing, create it:
```bash
cat > .env <<'EOF'
PGHOST=localhost
PGPORT=5433
PGDATABASE=appdb
PGUSER=appuser
PGPASSWORD=changeme
PGSSLMODE=disable
WEBAPP_PORT=8080
EOF
```

See **[CONNECTION_FIX.md](docs/CONNECTION_FIX.md)** for troubleshooting.

### Reload ETL (Add New Data)

**From web interface:**
1. Add new CSV files to `data/inc_data/`
2. Open http://localhost:8080
3. Click **"🔄 Reload ETL"** button
4. Wait 30-60 seconds

**From command line:**
```bash
make etl-reload
```

## Running Postgres for the ETL

### Option A — Docker (default)
1. Install Docker and Docker Compose.
2. Start the stack: `scripts/db_up.sh` (or `make up`).
3. Wait for readiness: `scripts/db_wait.sh` (or `make up-wait`).
4. Connect locally or from your desktop using `postgresql://appuser:changeme@localhost:5433/appdb` (credentials can be overridden in `.env`).
5. Stop the container when finished: `scripts/db_down.sh` (or `make down`).

The container binds host port `5433` → container `5432`. Database data stays in the container (ephemeral). CSV files are mounted from `./data/inc_data`.

#### Windows 10/11: beginner-friendly Docker Desktop setup
1. **Prepare Windows for Docker**
   - Make sure virtualization is enabled (Task Manager → Performance tab). If it is off, enable it in BIOS/UEFI first.
   - Follow Microsoft’s guide to install/upgrade to [WSL 2](https://learn.microsoft.com/windows/wsl/install). This installs the lightweight Linux layer Docker Desktop uses.
2. **Install Docker Desktop**
   - Download the official installer from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/).
   - Run the installer and leave “Use WSL 2 backend” checked. Accept the defaults; when prompted, log out/in to finish installation.
3. **Launch Docker Desktop**
   - Start Docker Desktop from the Start Menu. Wait until the whale icon in the system tray shows “Docker Desktop is running.” The first start can take a couple of minutes.
   - (Optional) Sign in with a Docker account if prompted, or choose “Skip for now.”
4. **Install Git Bash (for shell commands)**
   - Download Git for Windows from [git-scm.com/download/win](https://git-scm.com/download/win) and install with the default options. This provides the Git Bash terminal used in the commands below.
5. **Verify Docker is ready**
   - Open Git Bash and run `docker version`. If both the *Client* and *Server* sections return without errors, you are ready to run the project containers.

**Run project commands inside Docker**
- Use `make container-<target>` (for example `make container-etl-verify`) to run any Make goal inside the tool container. The wrapper delegates to Docker, so the only host runtime you need is Docker + GNU Make; it auto-starts Postgres (equivalent to `make up && make up-wait`) when needed and leaves it running on `localhost:5433` so you can inspect results with pgAdmin or application services. Run `make down` when you are finished (set `AUTO_DB_SHUTDOWN=1` to restore the previous auto-stop behaviour).
- Alternatively, call `./scripts/etl_make.sh <target>` directly (e.g., `./scripts/etl_make.sh etl-verify`); both options mount the repo into the container and reuse the same image cache.
- Test previews are suppressed by default to keep output concise. Set `SHOW_PREVIEW=1` when invoking a target (e.g., `SHOW_PREVIEW=1 make container-etl-verify`) to print Level‑1/Level‑2 samples and audits.
- If Docker’s build cache becomes corrupt (common after Docker Desktop upgrades on Windows/macOS), run `make docker-clean` from Git Bash/Terminal. The helper calls `docker buildx prune`, `docker builder prune`, and `docker system prune --volumes` with force flags to wipe stale layers before rebuilding the tool image.
- To reset the workspace: `make down` (stop containers) followed by `make clean-reset`. This removes generated CSVs, test fixtures, `__pycache__`, and `.pytest_cache`. Note: Database data is ephemeral (stored in container), so stopping the container clears the database.
- **Fresh checkout / update commands** (run from the repository root after cloning or pulling):
  ```bash
  git pull                      # or git clone <repo-url>
  make clean-reset              # optional – clears *_prepped.csv and caches
  make docker-clean             # optional – only if Docker reports snapshot errors
  make up
  make up-wait
  SHOW_PREVIEW=1 QUIET=0 make container-etl-verify   # loads data + runs tests
  make down                     # stop Postgres when finished
  ```
  Ensure the four raw CSV exports (`external_accounts_*.csv`, `va_txn_*.csv`, `repmt_sku_*.csv`, `repmt_sales_*.csv`) are in `data/inc_data/` before running the verify target.

## Web Query Interface

A simple web application provides an interactive interface to query the ETL views (Sheet1/Level1, Sheet2a/Level2a, Sheet2b/Level2b) with automatic conditional formatting and query builder.

### Features
- **Predefined Queries**: 12+ curated queries organized by view (variance analysis, outstanding fees, UI vs CF comparison)
- **Custom SQL**: Execute ad-hoc SELECT queries against any table/view
- **Direct View Access**: Quick access to Sheet1, Sheet2a, Sheet2b views
- **Conditional Formatting**:
  - **Red background**: Negative values
  - **Yellow background**: Variance > 0.02 threshold
  - **Gray background**: Default/zero values
- **Interactive Grid**: AG-Grid powered spreadsheet with sorting, filtering, column search
- **Pagination**: Default 10 rows, expandable to 25/50/100/All
- **Query Builder**: Add additional WHERE clauses to current results and re-run

### Running the Web Interface

```bash
# Start database and web interface
make up && make up-wait
make webapp-up

# Access at http://localhost:8080
# Stop when finished
make webapp-down
```

The web app connects to the same Postgres instance on the Docker network. Localhost-only trust model (no authentication required).

### Available Predefined Queries

**Sheet1 (Level 1)**:
- SKUs with Variance > Threshold (0.02)
- Top 10 SKUs by Amount Received
- Negative Variance Records
- SKUs with Amount Received = 0
- SKUs with Merchant Top Up
- SKUs with Outstanding Fees

**Sheet2a (Level 2a)**:
- Outstanding Amounts > 0
- Inter-SKU Transfer Summary
- Expected vs Paid Variance by Category

**Sheet2b (Level 2b)**:
- UI vs CF Mismatches
- Platform Fee Discrepancies
- All Negative Variances
- SPAR Variance Analysis

Query definitions in `webapp/backend/queries.yaml`.

### Demo Queries

Once the database is loaded, you can query all three views (Sheet1/Level1, Sheet2a/Level2a, Sheet2b/Level2b). The queries below are formatted for direct use in **pgAdmin**, **HeidiSQL**, **DBeaver**, or any SQL client.

**Database Connection:**
- Host: `localhost`
- Port: `5433`
- Database: `appdb`
- Username: `appuser`
- Password: `changeme`

---

#### Sheet 1 (Level 1) — Cash vs Ledger

**Quick preview (first 10 SKUs):**
```sql
SELECT
  "SKU ID",
  "Account Number",
  "Merchant",
  ROUND("Amount Pulled", 2) AS amount_pulled,
  ROUND("Amount Received", 2) AS amount_received,
  ROUND("Variance", 2) AS variance,
  ROUND("Sales Proceeds", 2) AS sales_proceeds
FROM mart.v_level1
ORDER BY "SKU ID"
LIMIT 10;
```

**SKUs with non-zero variance:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Pulled", 2) AS amount_pulled,
  ROUND("Amount Received", 2) AS amount_received,
  ROUND("Variance", 2) AS variance
FROM mart.v_level1
WHERE "Variance" != 0
ORDER BY ABS("Variance") DESC;
```

**Test SKU verification:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Pulled", 2) AS amount_pulled,
  ROUND("Amount Received", 2) AS amount_received,
  ROUND("Variance", 2) AS variance
FROM mart.v_level1
WHERE "SKU ID" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';
```

**Top 10 SKUs by Amount Received:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received", 2) AS amount_received,
  ROUND("Sales Proceeds", 2) AS sales_proceeds,
  ROUND("Variance", 2) AS variance
FROM mart.v_level1
ORDER BY "Amount Received" DESC
LIMIT 10;
```

**Find SKUs by merchant:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received", 2) AS amount_received,
  ROUND("Variance", 2) AS variance
FROM mart.v_level1
WHERE "Merchant" = 'ABC Sdn Bhd'
ORDER BY "Amount Received" DESC
LIMIT 20;
```

---

#### Sheet 2a (Level 2a) — Investor Reconciliation

**Quick preview (first 10 SKUs with key columns):**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received", 2) AS amount_received,
  ROUND(" Amount Distributed Down the Repayment Waterfall", 2) AS waterfall,
  ROUND("Fund Transferred to Other SKU", 2) AS transfers,
  ROUND("Variance", 2) AS variance,
  ROUND("Management Fee", 2) AS mgmt_fee,
  ROUND("Senior Principal", 2) AS sr_principal
FROM mart.v_level2a
ORDER BY "SKU ID"
LIMIT 10;
```

**All columns for a specific SKU:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received", 2) AS amount_received,
  ROUND(" Amount Distributed Down the Repayment Waterfall", 2) AS waterfall,
  ROUND("Fund Transferred to Other SKU", 2) AS transfers,
  ROUND("Variance", 2) AS variance,
  ROUND("Management Fee", 2) AS mgmt_fee,
  ROUND("Adminstrative Fee", 2) AS admin_fee,
  ROUND("Additional Adminstrative Fee", 2) AS add_admin_fee,
  ROUND("Interest Difference", 2) AS interest_diff,
  ROUND("Senior Principal", 2) AS sr_principal,
  ROUND("Senior Interest", 2) AS sr_interest,
  ROUND("Senior Additional Interest", 2) AS sr_add_interest,
  ROUND("Junior Principal", 2) AS jr_principal,
  ROUND("Junior Interest", 2) AS jr_interest,
  ROUND("Junior Additional Interest", 2) AS jr_add_interest
FROM mart.v_level2a
WHERE "SKU ID" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';
```

**SKUs with variance > 0.01:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received", 2) AS amount_received,
  ROUND(" Amount Distributed Down the Repayment Waterfall", 2) AS waterfall,
  ROUND("Fund Transferred to Other SKU", 2) AS transfers,
  ROUND("Variance", 2) AS variance
FROM mart.v_level2a
WHERE ABS("Variance") > 0.01
ORDER BY ABS("Variance") DESC;
```

**SKUs with outstanding distributions:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received", 2) AS received,
  ROUND(" Amount Distributed Down the Repayment Waterfall", 2) AS distributed,
  ROUND(" Amount Distributed Down the Repayment Waterfall" - "Amount Received", 2) AS shortfall
FROM mart.v_level2a
WHERE " Amount Distributed Down the Repayment Waterfall" > "Amount Received"
ORDER BY (" Amount Distributed Down the Repayment Waterfall" - "Amount Received") DESC
LIMIT 20;
```

---

#### Sheet 2b (Level 2b) — Payment Details

**Quick preview (first 10 SKUs):**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Total Fund Inflow", 2) AS total_inflow,
  ROUND("Management Fee Paid", 2) AS mgmt_fee,
  ROUND("Senior Principal Paid", 2) AS sr_principal,
  ROUND("Senior Interest Paid", 2) AS sr_interest,
  ROUND("Junior Principal Paid", 2) AS jr_principal
FROM mart.v_level2b
ORDER BY "SKU ID"
LIMIT 10;
```

**All columns for a specific SKU:**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Total Fund Inflow", 2) AS total_inflow,
  ROUND("Management Fee Paid", 2) AS mgmt_fee,
  ROUND("Adminstrative Fee Paid", 2) AS admin_fee,
  ROUND("Interest Difference Paid", 2) AS interest_diff,
  ROUND("Senior Principal Paid", 2) AS sr_principal,
  ROUND("Senior Interest Paid", 2) AS sr_interest,
  ROUND("Junior Principal Paid", 2) AS jr_principal,
  ROUND("Junior Interest Paid", 2) AS jr_interest,
  ROUND("SPAR", 2) AS spar,
  ROUND("FH Platform Fee", 2) AS platform_fee
FROM mart.v_level2b
WHERE "SKU ID" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';
```

**SKUs with payments (top 20 by total inflow):**
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Total Fund Inflow", 2) AS total_inflow,
  ROUND("Management Fee Paid", 2) AS mgmt_fee,
  ROUND("Senior Principal Paid", 2) AS sr_principal,
  ROUND("SPAR", 2) AS spar
FROM mart.v_level2b
WHERE "Total Fund Inflow" > 0
ORDER BY "Total Fund Inflow" DESC
LIMIT 20;
```

---

#### Summary & Validation Queries

**Row counts (should all be 366):**
```sql
SELECT
  'v_level1' AS view,
  COUNT(*) AS rows
FROM mart.v_level1
UNION ALL
SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL
SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;
```

**Variance summary across all views:**
```sql
SELECT
  'v_level1' AS view,
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE "Variance" = 0) AS balanced_skus,
  COUNT(*) FILTER (WHERE "Variance" != 0) AS unbalanced_skus,
  ROUND(AVG(ABS("Variance"))::numeric, 2) AS avg_abs_variance
FROM mart.v_level1

UNION ALL

SELECT
  'v_level2a',
  COUNT(*),
  COUNT(*) FILTER (WHERE ABS("Variance") < 0.01),
  COUNT(*) FILTER (WHERE ABS("Variance") >= 0.01),
  ROUND(AVG(ABS("Variance"))::numeric, 2)
FROM mart.v_level2a;
```

**Expected results:**
- All three views: **366 rows**
- Sheet 1 (v_level1): **363+ SKUs** with Variance = 0
- Sheet 2a (v_level2a): **366 SKUs** with Variance < 0.01

---

#### Command Line Queries (for testing/troubleshooting)

If you prefer command-line access, use `docker exec`:

```bash
# Sheet 1 sample
docker exec app-postgres psql -U appuser -d appdb -c \
  'SELECT "SKU ID", "Merchant", ROUND("Amount Received", 2) FROM mart.v_level1 LIMIT 5;'

# Sheet 2a sample
docker exec app-postgres psql -U appuser -d appdb -c \
  'SELECT "SKU ID", ROUND("Amount Received", 2) FROM mart.v_level2a LIMIT 5;'

# Row counts
docker exec app-postgres psql -U appuser -d appdb -c \
  'SELECT COUNT(*) FROM mart.v_level1;'
```

### Level‑1 query cheat sheet

Additional queries for verifying Level‑1 results in pgAdmin/psql:

```sql
-- Top SKUs by sales vs received variance
SELECT
    "SKU ID",
    "Merchant",
    ROUND("Amount Received", 2) AS amount_received,
    ROUND("Sales Proceeds", 2)  AS sales_proceeds,
    ROUND("Variance", 2) AS variance
FROM mart.v_level1
ORDER BY ABS("Variance") DESC
LIMIT 20;

-- Merchant roll-up
SELECT
    "Merchant",
    ROUND(SUM("Amount Received"), 2) AS total_received,
    ROUND(SUM("Sales Proceeds"), 2)  AS total_sales,
    ROUND(SUM("Variance"), 2) AS total_variance
FROM mart.v_level1
GROUP BY 1
ORDER BY ABS(SUM("Variance")) DESC;
```

Shortcuts:
- `make preview-level1` – runs the first query above from the CLI.
- `make preview-level1-sku SKU='BONE CUTTER-1288-636-hXKMZMU5NF'` – shows the Level‑1 row(s) for that SKU.
- **Fresh install or new database**: drop the four source CSVs into `data/inc_data/`, then run:
  ```bash
  make up
  make up-wait
  make container-etl-verify
  ```
  The verify target expands to `etl-prep` → `initdb` → `load-all-fresh` → `load-mapping` → `refresh` → tests, so the database is rebuilt from scratch and parity checks re-run every time. If the database is already loaded and you just want the tests, use `SHOW_PREVIEW=1 make container-etl-verify` for a detailed report without reloading.

#### First project run on Windows (simple walkthrough)
1. Download the repository (either clone with Git Bash or use the green **Code → Download ZIP** button on GitHub and extract it to a convenient folder, e.g., `C:\Users\you\Documents\fundedhere-etl`).
2. Open Git Bash, change into the project folder (`cd /c/Users/you/Documents/fundedhere-etl`), and copy the environment template: `cp config/.env.example .env` (optional if you stick to defaults).
3. Start Docker Desktop (if it is not already running), then in Git Bash execute `make up` to provision the Postgres container that stores all ETL results.
4. Run `make up-wait` to wait for Postgres to turn healthy, followed by `make container-etl-verify` to prep inputs, load them, refresh the marts, and execute the regression tests—everything runs inside Docker. (If you skip steps 3–4, `make container-etl-verify` will automatically start and wait for Postgres before running, and it leaves the database up afterward so you can inspect it.)
5. Inspect results with `make container-sql CMD="select * from mart.v_level1 limit 5;"` or connect via pgAdmin/DB client.
6. When you are finished, stop the container with `make down` (or run with `AUTO_DB_SHUTDOWN=1 make container-etl-verify` to have the wrapper clean up automatically).

**TIP:** to load new monthly data, replace the four source CSVs in `data/inc_data/` (and the Level‑1 reference export) and rerun `make container-etl-verify`. The pipeline is idempotent: it truncates and reloads `raw.*`, refreshes all downstream objects, and replays the parity tests.

Tip: if Git Bash reports `permission denied` on the `.sh` scripts, run `git config core.autocrlf false` before cloning so Windows line endings do not interfere. Alternatively, execute the same operations with `make up`, `make up-wait`, and `make down` (GNU Make instructions below).

### Option B — Existing Postgres (no Docker)
1. Install Postgres 16 (or compatible) on your server/desktop.
2. Create the role and database:
   ```bash
   createuser appuser --pwprompt
   createdb appdb --owner appuser
   ```
3. Copy `.env.example` to `.env`, set `DB_MODE=host` (or `remote`), and fill in `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, and `PGSSLMODE` as appropriate.
4. Run the bootstrap SQL against the target instance in order:
   ```bash
   psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -f initdb/000_schemas.sql
   psql ... -f initdb/010_extensions.sql
   psql ... -f initdb/020_security.sql
   psql ... -f initdb/100_raw_tables.sql
   psql ... -f initdb/200_ref_tables.sql
   psql ... -f sql/phase2/001_core_types.sql
   psql ... -f sql/phase2/002_core_basic_mviews.sql
   psql ... -f sql/phase2/003_core_mviews_flows.sql
   psql ... -f sql/phase2/004_core_inter_sku_transfers.sql
   psql ... -f sql/phase2/010_mart_views.sql
   psql ... -f sql/phase2/020_mart_level2.sql
   psql ... -f sql/phase2/021_category_funds_to_sku.sql
   psql ... -f sql/phase2/022_update_flows_pivot.sql
   psql ... -f sql/phase2/023_update_remarks_map.sql
   ```
5. Use the existing Make targets with `DB_MODE=host`/`remote` to load data and run tests (e.g., `make load-all-fresh`, `bash scripts/run_test_suite.sh`).

When working against a managed Postgres service, ensure the IP running the ETL is allowlisted and that SSL settings in `.env` match your provider.

## Workflow Overview
1. **Prepare inputs**
   - Drop the four source exports into `data/inc_data/` (`external_accounts_2025-09.csv`, `va_txn_2025-09.csv`, `repmt_sku_2025-09.csv`, `repmt_sales_2025-09.csv`).
   - Run `make prep-all` to normalise headers/values into `*_prepped.csv` (CSV normalization helpers live in `scripts/prep_*.py`).
   - Note: `make prep-map` is a no-op - mapping extraction is no longer required. Views now work directly from raw data using SKU IDs.
2. **Bootstrap database (first run per environment)**
   - Run `make initdb` (alias `make bootstrap`) to create schemas, tables, and core/mart SQL objects.
3. **Load raw tables**
   - Run `make load-all-fresh` to truncate `raw.*` and COPY the prepped CSVs.
   - Run `make load-mapping` to upsert the SKU↔VA map from `note_sku_va_map_prepped.csv` (auto-creates merchants/SKUs as needed).
4. **Materialise transforms**
   - Run `make refresh` (or `scripts/sql-tests/refresh.sql`) to rebuild `core.*` materialised views and `mart.*` views.
5. **Verify parity**
   - Run `bash scripts/run_test_suite.sh`; it checks CSV headers, mapping coverage, mart row counts, Level‑1 totals, Level‑1 reference parity, and finally variance tolerances. All steps except the last must pass before data is considered publishable.

Shortcut targets:
- `make etl-prep` → runs `prep-all` + `prep-map` in order.
- `make etl-load` → runs the full pipeline (`etl-prep`, `initdb`, `load-all-fresh`, `load-mapping`, `refresh`).
- `make etl-verify` → executes `etl-load` and then `bash scripts/run_test_suite.sh`.


Need more detail? See [architecture](docs/EXISTING_ANALYSIS.md), [reconciliation analysis](docs/RECONCILIATION_ANALYSIS.md), and the [formula mapping](docs/FORMULA_MAPPING.md) for field-by-field logic.

## Quality Gates
Run the full suite after each data load:
```bash
bash scripts/run_test_suite.sh
```
The harness executes:
1. CSV header validation (`tests/test_csv_headers.sh`)
2. Mapping coverage (`scripts/sql-tests/check_mapping_coverage.sql`)
3. Mart row-count parity (`scripts/sql-tests/check_mart_row_counts.sql`)
4. Level‑1 totals parity (`scripts/sql-tests/check_level1_totals.sql`)
5. Level‑1 reference parity (`tests/test_level1_parity.py`)
6. Variance tolerance check (`scripts/sql-tests/check_level1_variance_tolerance.sql`) — currently logged as a warning until finance defines acceptable deltas. Set `FAIL_ON_LEVEL1_VARIANCE=1` in `.env` to make the suite fail on this step.

Full details on each check (and upcoming fixture work) live in the [Testing Guide](docs/TESTING.md).

## Current Status
- **Pipeline Complete**: The `make container-etl-verify` command now runs successfully, passing all data validation and parity checks.
- **Level-1 Verified**: All Level-1 parity tests are passing. The logic correctly handles complex cases like shared Virtual Accounts to prevent data duplication.
- **Level-2 Implemented**: `mart.v_level2a` and `mart.v_level2b` are complete and include all required columns from the target spreadsheets, such as additional fees, interest, and inflow sources.
- `FH Platform Fee (CF)` in `mart.v_level2b` remains a calculated placeholder, as specified in the original scope.

### Level‑2 Roadmap
Level‑2a already reproduces the Waterfall tab (paid vs expected, plus transfer diagnostics). To finish parity work and enable automation:
1. **Categorise residual remarks** — ensure every VA outflow remark maps to a waterfall bucket or tolerated “other” category.
2. **Level‑2a parity tests** — add totals and reference CSV comparisons similar to the Level‑1 harness.
3. **(Completed) Level‑2b view** — The `mart.v_level2b` view is now implemented and surfaces the required UI vs. Cash Flow variances.
4. **Automation hooks** — extend `scripts/run_test_suite.sh` with parity checks for Level‑2a/2b once the SQL is in place.

## What’s Next
1. Align variance tolerances with finance and update `scripts/sql-tests/check_level1_variance_tolerance.sql` once the policy is set.
2. Extend parity automation to Level‑2/Level‑2b outputs.
3. Package an `etl-all` target for idempotent end-to-end runs (prep → load → mapping → refresh → tests).
4. Harden mappings and remark categories as new merchants/periods are onboarded.
5. Build golden fixtures and synthetic scenarios (see below) so the pipeline can be tested without fresh finance input:
   - Curate representative SKUs from the live sample and store the expected Level‑1/Level‑2 outputs alongside their raw source slices.
   - Generate synthetic CSVs for edge cases (only repayments, heavy transfers, duplicate inflows, missing mappings) with paired expected outputs.
   - Add a `make test-fixtures` target that loads each fixture into a sandbox schema, runs the ETL, and diff-checks the results using the parity scripts.

For a daily operations hand-off, refer to `docs/AGENT_HANDOFF.md`.

## Quick Start (Git Bash on Windows 11)
### Prerequisites
1. **Docker Desktop** – install from https://www.docker.com/products/docker-desktop/ (enable WSL 2 backend). Launch it before running the ETL.
2. **Git for Windows** – install from https://git-scm.com/download/win (Git Bash is included).
3. (Optional) **Editor/IDE** – VS Code or similar for exploring the project.

1. Install Docker Desktop (WSL 2 backend) and keep it running.
2. Install Git for Windows (Git Bash) and clone the repository:
   ```bash
   git clone https://github.com/usekase/fundedhere-etl.git
   cd fundedhere-etl
   cp config/.env.example .env   # optional – defaults already match compose
   ```
3. Start the database and run the end-to-end pipeline fully inside Docker:
   ```bash
   make up
   make up-wait
   make container-etl-verify
   ```
   Place the four CSV inputs in `data/inc_data/` before running `etl-verify` (`external_accounts_2025-09.csv`, `va_txn_2025-09.csv`, `repmt_sku_2025-09.csv`, `repmt_sales_2025-09.csv`).
   Tip: You can jump straight to `make container-etl-verify`—it will spin up and wait for Postgres automatically—but keeping the database up separately is handy when you plan to run multiple commands in a row.
4. Inspect results with `make container-sql CMD="select * from mart.v_level1 limit 10;"` or connect via pgAdmin using the settings below.
5. Shut down the stack when finished: `make down`.

### Connecting with pgAdmin or other SQL clients
- Host: `localhost`
- Port: `5433`
- Database: `appdb`
- Username: `appuser`
- Password: `changeme` (unless you changed it in `.env`)
- SSL: disabled (local connection)
Make sure Docker is running and the container is up (`make up`) before launching the client.

### Host data directory
- By default the project stores incoming CSVs in `./data/inc_data` (see `DATA_DIR` in `.env`). The folder is created automatically the first time you run `make up` or `make container-...` and is bind-mounted into the containers.
- Database data stays in the container (ephemeral - cleared when container is removed).
- To use a different location for CSV files, set `DATA_DIR=/path/to/storage` in your environment or `.env` before invoking the commands. All helper scripts respect the setting and will create the necessary `inc_data` subdirectory if it does not already exist.

## Quick Start (Linux & macOS terminals)
### Prerequisites
- Docker (Engine + Compose)
- Git

Ensure the Docker daemon is running before starting the ETL.

1. Clone the repository and prepare environment defaults:
   ```bash
   git clone https://github.com/usekase/fundedhere-etl.git
   cd fundedhere-etl
   cp config/.env.example .env
   ```
2. Start Postgres and run the pipeline in the tool container:
   ```bash
   make up
   make up-wait
   make container-etl-verify
   ```
3. Issue ad-hoc SQL with `make container-sql CMD="select * from mart.v_level1 limit 10;"` or use your preferred client.
4. Stop the stack: `make down`.

### Connecting with pgAdmin / DBeaver / psql
- Host: `localhost`
- Port: `5433`
- Database: `appdb`
- Username: `appuser`
- Password: `changeme` (update `.env` if desired)
- SSL: disabled (local dev)
You can also bind a different port via `.env` if necessary (update `PGPORT` before `make up`).

### Alternatively: Run the bundled Docker image (no local tooling)
1. Build the image once:
   ```bash
   docker build -t fundedhere-etl .
   ```
2. Provide the four CSV extracts under `$(pwd)/data/inc_data/`.
3. Run the ETL in the container:
   ```bash
   docker run --rm -it \
     -v "$(pwd)/data/inc_data:/app/data/inc_data" \
     fundedhere-etl
   ```
   On Windows (PowerShell/Git Bash), replace `$(pwd)` with `%cd%`:
   ```bash
   docker run --rm -it ^
     -v %cd%\data\inc_data:/app/data/inc_data ^
     fundedhere-etl
   ```
The container bundles Python, make, and the Postgres client so you only need Docker. Database data is stored in the container (ephemeral). After the run, query the mart using `bash scripts/run_sql.sh ...` or connect to Postgres at `localhost:5433` (database `appdb`, user `appuser`, password `changeme`).