# FundedHere Reconciliation ETL

A production-focused pipeline that converts FundedHere’s reconciliation CSV exports into a trustworthy Postgres data product. The goal is simple: ingest the four monthly extracts, preserve the business logic embedded in those files, and expose the Level‑1/Level‑2 views (and their tests) as fast, queryable database objects.

## Level Overview
- **Level 1 — Cash vs. Ledger**: aligns bank pulls, virtual-account inflows, and sales proceeds per SKU/VA pair so cash movement gaps surface immediately.
- **Level 2a — Waterfall Execution**: breaks each repayment into management fees, admin fees, interest, principal, and SPAR buckets using the repayment expectations CSV, then compares paid vs. expected amounts.
- **Level 2b — UI vs. Cashflow**: contrasts UI-facing repayment totals with the cash ledger to highlight category-level deltas for downstream consumers.

## Product Outcomes
- **Reference parity**: `mart.v_level1`, `mart.v_level2a`, and the new `mart.v_level2b` replicate the “Formula & Output” CSV exports (Level‑1 parity is fully automated; Level‑2 parity tests are next).
- **Explorable data model**: inputs land in `raw.*`, mappings live in `ref.*`, typed transforms sit in `core.*`, and business consumers query `mart.*`.
- **Automated verification**: header validation, SKU coverage, row-count parity, totals parity, and Level‑1 reference parity run in `scripts/run_test_suite.sh`.
- **Agent-ready**: every row carries `merchant`, `sku_id`, and `period_ym` so downstream automation can request time slices without reprocessing the workbook.

Further reading:
- [Architecture & workflow](docs/EXISTING_ANALYSIS.md)
- [Reconciliation logic](docs/RECONCILIATION_ANALYSIS.md)
- [CSV ↔ SQL mapping](docs/FORMULA_MAPPING.md)
- [Validation log](docs/VALIDATION_RESULTS.md)
- [Outstanding test gaps](docs/TEST_GAPS.md)
- [Testing guide](docs/TESTING.md)
- [Agent hand-off log](docs/AGENT_HANDOFF.md)

## Data Sources (CSV extracts)
1. **External Accounts (Merchant)** → `raw.external_accounts`
2. **VA Transaction Report (All)** → `raw.va_txn`
3. **Repmt-SKU (by Note)** → `raw.repmt_sku`
4. **Repmt-Sales Proceeds (by Note)** → `raw.repmt_sales`

Mappings required by the CSV exports live in version control:
- `ref.note_sku_va_map` — SKU/VA alignment (generated from the Level‑1 reference export).
- `ref.remarks_category_map` — remark → waterfall category (admin fees, sr/jr principal, SPAR, etc.).

Architecture and lineage details: see `docs/EXISTING_ANALYSIS.md` and `docs/RECONCILIATION_ANALYSIS.md`.

## Running Postgres for the ETL

### Option A — Docker (default)
1. Install Docker and Docker Compose.
2. Start the stack: `scripts/db_up.sh` (or `make up`).
3. Wait for readiness: `scripts/db_wait.sh` (or `make up-wait`).
4. Connect locally or from your desktop using `postgresql://appuser:changeme@localhost:5433/appdb` (credentials can be overridden in `.env`).
5. Stop the container when finished: `scripts/db_down.sh` (or `make down`).

The container binds host port `5433` → container `5432`, stores data in `./data/pgdata`, and exposes CSV drop space at `./data/inc_data`.

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

#### First project run on Windows (simple walkthrough)
1. Download the repository (either clone with Git Bash or use the green **Code → Download ZIP** button on GitHub and extract it to a convenient folder, e.g., `C:\Users\you\Documents\fundedhere-etl`).
2. Open Git Bash, change into the project folder (`cd /c/Users/you/Documents/fundedhere-etl`), and copy the environment template: `cp config/.env.example .env`.
3. Start Docker Desktop (if it is not already running), then in Git Bash execute `./scripts/db_up.sh`. The script will create the Postgres container the ETL uses.
4. Watch the terminal output. When `Database is ready` appears (or after running `./scripts/db_wait.sh`), you can connect from any SQL client using the connection string printed in the script.
5. When you are finished, stop the container with `./scripts/db_down.sh` or press “Stop” next to the container in Docker Desktop.

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
   - Drop the four source exports into `data/inc_data/` (`external_accounts_2025-09.csv`, `va_txn_2025-09.csv`, `repmt_sku_2025-09.csv`, `repmt_sales_2025-09.csv`). Copy the Level‑1 “Formula & Output” reference export alongside them as `level1_reference.csv` (the tooling still falls back to the original `Sample Files((1) Formula & Output).csv` name if present).
   - Run `make prep-all` to normalise headers/values into `*_prepped.csv` (CSV normalization helpers live in `scripts/prep_*.py`).
   - Run `make prep-map` to extract `note_sku_va_map_prepped.csv` from the Level‑1 reference export. Override with `make prep-map SOURCE=...` if the reference lives elsewhere.
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
- All 366 SKUs from the September 2025 sample are present in `mart.v_level1`/`mart.v_level2a` with totals matching the reference exports.
- `mart.v_level2b` surfaces UI vs cashflow variances per fee/principal bucket; `FH Platform Fee (CF)` is currently a placeholder until the relevant VA mappings are defined.
- Level‑1 variance guard is intentionally failing to surface unresolved business gaps (see `docs/AGENT_HANDOFF.md` for next steps).
- Level‑2b (UI vs VA) parity work remains outstanding.

### Level‑2 Roadmap
Level‑2a already reproduces the Waterfall tab (paid vs expected, plus transfer diagnostics). To finish parity work and enable automation:
1. **Categorise residual remarks** — ensure every VA outflow remark maps to a waterfall bucket or tolerated “other” category.
2. **Level‑2a parity tests** — add totals and reference CSV comparisons similar to the Level‑1 harness.
3. **Level‑2b view** — build a mart view that compares UI values (`raw.repmt_sales`, `raw.repmt_sku`) against VA-derived totals and flags mismatches; capture expectations in `docs/FORMULA_MAPPING.md` before coding.
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
3. **GNU Make**
   - Download `make-3.81-bin.zip` and `make-3.81-dep.zip` from https://gnuwin32.sourceforge.net/packages/make.htm.
   - Extract both archives into a folder such as `C:\Users\<user>\Documents\make-win\` so that `make.exe` is in `...\make-win\bin`.
   - Add that folder to **System → Environment Variables → Path** or export it per-session (`export PATH="$HOME/Documents/make-win/bin:$PATH"`).
4. **Python 3.x** – install from https://www.python.org/downloads/ with “Add python.exe to PATH” checked, then copy `python.exe` → `python3.exe` in the same directory so `python3` commands succeed.
5. **PostgreSQL CLI tools** – install the Command Line Tools (or full server) from https://www.postgresql.org/download/windows/ and add `...\PostgreSQL\<version>\bin` to PATH so `psql` is available.

1. Install Docker Desktop (WSL 2 backend) and keep it running.
2. Install Git for Windows (Git Bash), GNU make (e.g., `make-win` bundle), Python 3 (ensure PATH or copy `python.exe` to `python3.exe`), and PostgreSQL CLI tools (`psql`).
3. Open Git Bash and run:
   ```bash
   git clone git@github.com-usekase:erik-usekase/fundedhere-etl.git
   cd fundedhere-etl
   cp config/.env.example .env
   export PATH="$HOME/Documents/make-win/bin:$PATH"
   ../make-win/bin/make.exe up
   ../make-win/bin/make.exe etl-verify
   ```
   The command expects five input CSVs in `data/inc_data/` (`external_accounts_2025-09.csv`, `va_txn_2025-09.csv`, `repmt_sku_2025-09.csv`, `repmt_sales_2025-09.csv`, `level1_reference.csv`).
4. Inspect results with `bash scripts/run_sql.sh -c "SELECT * FROM mart.v_level1 LIMIT 10;"` and shut down the container via `../make-win/bin/make.exe down`.

### Connecting with pgAdmin or other SQL clients
- Host: `localhost`
- Port: `5433`
- Database: `appdb`
- Username: `appuser`
- Password: `changeme` (unless you changed it in `.env`)
- SSL: disabled (local connection)
Make sure Docker is running and the container is up (`make up`) before launching the client.

## Quick Start (Linux & macOS terminals)
### Prerequisites
- Docker (Engine + Compose)
- Python 3.9+ with pip
- GNU make
- PostgreSQL client tools (psql)
- Git

On Ubuntu/Debian, for example:
```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin python3 python3-pip make postgresql-client git
```
On macOS (Homebrew):
```bash
brew install --cask docker
brew install python make libpq git
brew link --force libpq
```
Ensure the Docker daemon is running before starting the ETL.

1. Install Docker, Python 3, GNU make, and PostgreSQL client tools via your package manager (e.g., `apt`, `brew`).
2. In your shell:
   ```bash
   git clone git@github.com-usekase:erik-usekase/fundedhere-etl.git
   cd fundedhere-etl
   cp config/.env.example .env
   make up
   make etl-verify
```
3. Validate with `bash scripts/run_sql.sh -c "SELECT * FROM mart.v_level1 LIMIT 10;"` and stop the stack with `make down`.

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
2. Provide the CSVs (four extracts + `level1_reference.csv`) under `$(pwd)/data/inc_data/`.
3. Run the ETL in the container:
   ```bash
   docker run --rm -it \
     -v "$(pwd)/data/inc_data:/app/data/inc_data" \
     -v "$(pwd)/data/pgdata:/app/data/pgdata" \
     fundedhere-etl
   ```
   On Windows (PowerShell/Git Bash), replace `$(pwd)` with `%cd%`:
   ```bash
   docker run --rm -it ^
     -v %cd%\data\inc_data:/app/data/inc_data ^
     -v %cd%\data\pgdata:/app/data/pgdata ^
     fundedhere-etl
   ```
The container bundles Python, make, and the Postgres client so you only need Docker. After the run, query the mart using `bash scripts/run_sql.sh ...` or connect to Postgres at `localhost:5433` (database `appdb`, user `appuser`, password `changeme`).
