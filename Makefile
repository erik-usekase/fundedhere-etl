# ------------------------------------------------------------------------------
# Minimal Makefile - delegates logic to ./scripts/*
# ------------------------------------------------------------------------------

# Load .env if present
ifneq (,$(wildcard .env))
include .env
export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env)
endif

# Defaults
EFFECTIVE_DATA_DIR := $(if $(strip $(DATA_DIR)),$(DATA_DIR),./data)
INC_DIR := $(EFFECTIVE_DATA_DIR)/inc_data

.SILENT:

# ──────────────────────────────────────────────────────────────────────────────
# Default target - show help
# ──────────────────────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "FundedHere ETL - Common Make Targets"
	@echo ""
	@echo "Quick Start:"
	@echo "  make up                    - Start PostgreSQL database"
	@echo "  make up-wait               - Wait for database to be ready"
	@echo "  make container-etl-verify  - Run complete ETL pipeline (prep + load + test)"
	@echo "  make down                  - Stop database"
	@echo ""
	@echo "Database Management:"
	@echo "  make up                    - Start database container"
	@echo "  make up-wait               - Wait for database ready"
	@echo "  make down                  - Stop database container"
	@echo "  make logs                  - View database logs"
	@echo "  make psql-host             - Test database connection"
	@echo ""
	@echo "ETL Pipeline:"
	@echo "  make etl-prep              - Prepare CSV files for loading"
	@echo "  make etl-load              - Load data (prep + init + load + refresh)"
	@echo "  make etl-verify            - Full pipeline + tests"
	@echo "  make container-etl-verify  - Run etl-verify in Docker container"
	@echo ""
	@echo "Data Loading:"
	@echo "  make initdb                - Initialize database schema"
	@echo "  make load-all-fresh        - Load all CSV data (truncates existing)"
	@echo "  make refresh               - Refresh materialized views"
	@echo ""
	@echo "Queries:"
	@echo "  make sql CMD='SELECT...'   - Run SQL query"
	@echo "  make preview-level1        - Show Level 1 (Sheet 1) sample data"
	@echo ""
	@echo "Docker Helpers:"
	@echo "  make container-TARGET      - Run any target in Docker container"
	@echo "  make docker-clean          - Clean Docker build cache"
	@echo ""
	@echo "For detailed usage, see README.md or run: make container-etl-verify"

# ──────────────────────────────────────────────────────────────────────────────
# Lifecycle (compose or host/remote handled in scripts)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: prep-data up up-wait down logs env psql-host sql sqlf refresh counts initdb bootstrap

prep-data:
	mkdir -p "$(INC_DIR)"

up: prep-data
	scripts/db_up.sh

up-wait: up
	scripts/db_wait.sh

down:
	scripts/db_down.sh

logs:
	scripts/db_logs.sh

env:
	echo "DATA_DIR=$(DATA_DIR)  EFFECTIVE_DATA_DIR=$(EFFECTIVE_DATA_DIR)"
	echo "INC_DIR=$(INC_DIR)"
	echo "DB_MODE=${DB_MODE:-container-bind}"
	echo "PGHOST=$(PGHOST) PGPORT=$(PGPORT) PGDATABASE=$(PGDATABASE) PGUSER=$(PGUSER) PGSSLMODE=$(PGSSLMODE)"
	echo "REMOTE_PGHOST=$(REMOTE_PGHOST) REMOTE_PGPORT=$(REMOTE_PGPORT) REMOTE_PGDATABASE=$(REMOTE_PGDATABASE) REMOTE_PGUSER=$(REMOTE_PGUSER) REMOTE_PGSSLMODE=$(REMOTE_PGSSLMODE)"

psql-host:
	scripts/run_sql.sh -c "select now() as server_time, version();"

sql:
	test -n "$(CMD)" || { echo "Usage: make sql CMD='select 1'"; exit 2; }
	scripts/run_sql.sh -c "$(CMD)"

sqlf:
	test -n "$(FILE)" || { echo "Usage: make sqlf FILE=path.sql"; exit 2; }
	scripts/run_sql.sh -f "$(FILE)"

refresh:
	uv run fundedhere-etl refresh

counts:
	scripts/run_sql.sh -f scripts/sql-utils/counts.sql

initdb bootstrap:
	uv run fundedhere-etl bootstrap

# ──────────────────────────────────────────────────────────────────────────────
# CSV prep (uses Python utilities under ./scripts/)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: preview-cols prep-external prep-vatxn prep-repmt-sku prep-repmt-sales prep-all prep-map etl-prep etl-load etl-verify

preview-cols:
	test -n "$(FILE)" || { echo "Usage: make preview-cols FILE=path.csv"; exit 2; }
	python3 scripts/preview_cols.py "$(FILE)"

prep-external:
	test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-external SRC=in.csv OUT=out.csv"; exit 2; }
	python3 scripts/prep_external.py "$(SRC)" "$(OUT)"

prep-vatxn:
	test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-vatxn SRC=in.csv OUT=out.csv"; exit 2; }
	python3 scripts/prep_vatxn.py "$(SRC)" "$(OUT)"

prep-repmt-sku:
	test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-repmt-sku SRC=in.csv OUT=out.csv"; exit 2; }
	python3 scripts/prep_repmt_sku.py "$(SRC)" "$(OUT)"

prep-repmt-sales:
	test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-repmt-sales SRC=in.csv OUT=out.csv"; exit 2; }
	python3 scripts/prep_repmt_sales.py "$(SRC)" "$(OUT)"

prep-all:
	uv run fundedhere-etl prep

prep-map:
	@echo "Skipping mapping generation (data format mismatch - note_id vs sku_id)"
	@echo "Views will work without mapping table populated"

etl-prep:
	$(MAKE) prep-all
	$(MAKE) prep-map

etl-load:
	$(MAKE) etl-prep
	uv run fundedhere-etl bootstrap
	uv run fundedhere-etl load --mode parallel --truncate
	uv run fundedhere-etl load-mapping
	uv run fundedhere-etl refresh

etl-verify:
	$(MAKE) etl-load
	bash scripts/run_test_suite.sh

# Verify only (assumes data already loaded)
etl-test-only:
	bash scripts/run_test_suite.sh

# Clear all loaded data (keeps schema)
etl-clear-data:
	@echo "Truncating all data tables..."
	@scripts/run_sql.sh -c "TRUNCATE TABLE raw.external_accounts CASCADE;"
	@scripts/run_sql.sh -c "TRUNCATE TABLE raw.va_txn CASCADE;"
	@scripts/run_sql.sh -c "TRUNCATE TABLE raw.repmt_sku CASCADE;"
	@scripts/run_sql.sh -c "TRUNCATE TABLE raw.repmt_sales CASCADE;"
	@scripts/run_sql.sh -c "TRUNCATE TABLE ref.note_sku_va_map CASCADE;"
	@echo "✓ All data tables cleared"

# Verify data load and schema match target
verify-target:
	@echo "=== ROW COUNTS (Expected: 2718, 28599, 366, 366, 366, 366, 366) ==="
	@docker exec app-postgres psql -U appuser -d appdb -c "SELECT 'external_accounts' as table, COUNT(*) FROM raw.external_accounts UNION ALL SELECT 'va_txn', COUNT(*) FROM raw.va_txn UNION ALL SELECT 'repmt_sku', COUNT(*) FROM raw.repmt_sku UNION ALL SELECT 'repmt_sales', COUNT(*) FROM raw.repmt_sales UNION ALL SELECT 'v_level1', COUNT(*) FROM mart.v_level1 UNION ALL SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a UNION ALL SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;" | grep -E "table|external|va_txn|repmt|v_level"
	@echo ""
	@echo "=== SCHEMA STRUCTURE ==="
	@docker exec app-postgres psql -U appuser -d appdb -c "SELECT table_name, COUNT(*) as columns FROM information_schema.columns WHERE table_schema='mart' AND table_name IN ('v_level1', 'v_level2a', 'v_level2b') GROUP BY table_name ORDER BY table_name;"
	@echo "Expected: v_level1=8, v_level2a=16, v_level2b=12"
	@echo ""
	@echo "=== TEST SKU: 4 HOLE EGG PAN (Expected: Sheet1 variance=0, Sheet2a variance=0) ==="
	@docker exec app-postgres psql -U appuser -d appdb -c "SELECT 'Sheet 1' as view, \"Amount Pulled\", \"Amount Received\", \"Variance\" FROM mart.v_level1 WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';" | head -5
	@docker exec app-postgres psql -U appuser -d appdb -c "SELECT 'Sheet 2a' as view, \"Amount Received\", \"Variance\", \"Management Fee\", \"Senior Principal\" FROM mart.v_level2a WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';" | head -5
	@docker exec app-postgres psql -U appuser -d appdb -c "SELECT 'Sheet 2b' as view, \"Total Fund Inflow\", \"Management Fee Paid\", \"Senior Principal Paid\" FROM mart.v_level2b WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';" | head -5

# ──────────────────────────────────────────────────────────────────────────────
# CSV loaders — column lists handled by scripts/load_raw.sh
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: load-external load-vatxn load-repmt-sku load-repmt-sales load-all load-all-fresh load-mapping test-health test-level1

load-external:
	test -n "$(FILE)" || { echo "Usage: make load-external FILE=path.csv[.gz]"; exit 2; }
	scripts/load_raw.sh raw.external_accounts "beneficiary_bank_account_number,buy_amount,buy_currency,created_date" "$(FILE)"

load-vatxn:
	test -n "$(FILE)" || { echo "Usage: make load-vatxn FILE=path.csv[.gz]"; exit 2; }
	scripts/load_raw.sh raw.va_txn "sender_virtual_account_id,sender_virtual_account_number,sender_note_id,receiver_virtual_account_id,receiver_virtual_account_number,receiver_note_id,receiver_va_opening_balance,receiver_va_closing_balance,amount,date,remarks" "$(FILE)"

load-repmt-sku:
	test -n "$(FILE)" || { echo "Usage: make load-repmt-sku FILE=path.csv[.gz]"; exit 2; }
	scripts/load_raw.sh raw.repmt_sku "merchant,sku_id,acquirer_fees_expected,acquirer_fees_paid,fh_admin_fees_expected,fh_admin_fees_paid,int_difference_expected,int_difference_paid,sr_principal_expected,sr_principal_paid,sr_interest_expected,sr_interest_paid,jr_principal_expected,jr_principal_paid,jr_interest_expected,jr_interest_paid,spar_merchant,additional_interests_paid_to_fh" "$(FILE)"

load-repmt-sales:
	test -n "$(FILE)" || { echo "Usage: make load-repmt-sales FILE=path.csv[.gz]"; exit 2; }
	scripts/load_raw.sh raw.repmt_sales "merchant,sku_id,total_funds_inflow,sales_proceeds,l2e" "$(FILE)"

load-mapping:
	uv run fundedhere-etl load-mapping $(if $(strip $(FILE)),--mapping-file "$(FILE)")

# Load only PREPPED CSVs (explicit; avoids picking up raw files)
load-all:
	echo "Loading PREPPED CSVs from $(INC_DIR)"
	test -f "$(INC_DIR)/external_accounts_prepped.csv" || { echo "Missing external_accounts_prepped.csv"; exit 2; }
	test -f "$(INC_DIR)/va_txn_prepped.csv"          || { echo "Missing va_txn_prepped.csv"; exit 2; }
	test -f "$(INC_DIR)/repmt_sku_prepped.csv"       || { echo "Missing repmt_sku_prepped.csv"; exit 2; }
	test -f "$(INC_DIR)/repmt_sales_prepped.csv"     || { echo "Missing repmt_sales_prepped.csv"; exit 2; }
	$(MAKE) load-external    FILE="$(INC_DIR)/external_accounts_prepped.csv"
	$(MAKE) load-vatxn       FILE="$(INC_DIR)/va_txn_prepped.csv"
	$(MAKE) load-repmt-sku   FILE="$(INC_DIR)/repmt_sku_prepped.csv"
	$(MAKE) load-repmt-sales FILE="$(INC_DIR)/repmt_sales_prepped.csv"

# Truncate then load-all (clean reload) - uses Python CLI
load-all-fresh:
	uv run fundedhere-etl load --mode parallel --truncate

# Quick health checks
test-health:
	scripts/run_sql.sh -f scripts/sql-tests/chain_status.sql

test-level1:
	scripts/run_sql.sh -f scripts/sql-tests/level1_pretty.sql

# ──────────────────────────────────────────────────────────────────────────────
# Container wrappers (ensure zero local Python/psql dependency)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: container-% docker-clean clean-cache clean-reset

container-%:
	./scripts/etl_make.sh $*

docker-clean:
	echo "Pruning Docker caches (buildx, builder, system)..."
	docker buildx prune --all --force || true
	docker builder prune --all --force || true
	docker system prune --volumes --force || true

clean-cache:
	echo "Removing Python caches..."
	find . -type d -name '__pycache__' -prune -exec rm -rf {} + || true
	rm -rf .pytest_cache || true
	echo "Removing generated test fixtures and prepped CSVs..."
	rm -f data/inc_data/*_prepped.csv data/inc_data/note_sku_va_map_prepped.csv || true
	rm -f tests/fixtures/level1_expected.csv || true

clean-reset: clean-cache
	echo "Workspace cache cleaned. Database files in $(EFFECTIVE_DATA_DIR) remain intact."

.PHONY: preview-level1 preview-level1-sku

preview-level1:
	scripts/run_sql.sh -c "SELECT \"SKU ID\", \"Account Number\", \"Merchant\", ROUND(\"Amount Pulled\",2) AS amount_pulled, ROUND(\"Amount Received\",2) AS amount_received, ROUND(\"Sales Proceeds\",2) AS sales_proceeds FROM mart.v_level1 ORDER BY ABS(\"Amount Received\" - \"Sales Proceeds\") DESC LIMIT 20;"

preview-level1-sku:
	test -n "$(SKU)" || { echo "Usage: make preview-level1-sku SKU='SKU ID'"; exit 2; }
	scripts/run_sql.sh -c "SELECT * FROM mart.v_level1 WHERE \"SKU ID\" = '$(SKU)';"

# ──────────────────────────────────────────────────────────────────────────────
# Web Application Interface
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: webapp-up webapp-down webapp-logs webapp-restart validate-views export-level1

webapp-up: up-wait
	echo "Starting web query interface..."
	docker compose --profile webapp up -d
	echo "Web interface available at http://localhost:8080"

webapp-down:
	echo "Stopping web query interface..."
	docker compose --profile webapp down

webapp-logs:
	docker compose --profile webapp logs -f webapp

webapp-restart: webapp-down webapp-up

validate-views:
	echo "Validating view calculations..."
	scripts/run_sql.sh -c "SELECT COUNT(*) AS sheet1_rows FROM mart.v_level1;"
	scripts/run_sql.sh -c "SELECT COUNT(*) AS sheet2a_rows FROM mart.v_level2a;"
	scripts/run_sql.sh -c "SELECT COUNT(*) AS sheet2b_rows FROM mart.v_level2b;"
	python3 tests/test_level1_parity.py

export-level1:
	scripts/run_sql.sh -c "COPY (SELECT * FROM mart.v_level1 ORDER BY \"SKU ID\") TO STDOUT WITH CSV HEADER" > data/inc_data/level1_export.csv
	echo "Exported to data/inc_data/level1_export.csv"

# ──────────────────────────────────────────────────────────────────────────────
# FAST Direct CSV Loading (No Python preprocessing)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: load-fast load-fast-single etl-load-fast etl-verify-fast

# Load all CSVs in parallel (fastest option for large files)
load-fast:
	echo "Fast parallel CSV loading from $(INC_DIR)..."
	$(PYTHON) -m fundedhere_etl load --mode parallel

# Load single CSV directly without preprocessing
load-fast-single:
	test -n "$(TABLE)" -a -n "$(FILE)" || { echo "Usage: make load-fast-single TABLE=raw.va_txn FILE=path.csv"; exit 2; }
	scripts/load_csv_direct.sh "$(TABLE)" "$(FILE)"

# Fast ETL workflow (direct load + mapping + refresh)
etl-load-fast:
	$(MAKE) initdb
	$(MAKE) load-fast
	$(MAKE) prep-map
	$(MAKE) load-mapping
	$(MAKE) refresh

# Fast ETL with verification (recommended for production)
etl-verify-fast:
	$(MAKE) etl-load-fast
	bash scripts/run_test_suite.sh

# ──────────────────────────────────────────────────────────────────────────────
# Multi-Period Support (load and query data across multiple date periods)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: load-multi-period load-multi-append periods-list periods-coverage deploy-period-views

# Load all CSV files for all periods (replaces existing data)
load-multi-period:
	echo "Loading all periods (replace mode)..."
	chmod +x scripts/load_multi_period.sh
	scripts/load_multi_period.sh "$(INC_DIR)" replace

# Append new period data without deleting existing
load-multi-append:
	echo "Loading new period (append mode)..."
	chmod +x scripts/load_multi_period.sh
	scripts/load_multi_period.sh "$(INC_DIR)" append

# Deploy period-aware views and functions
deploy-period-views:
	echo "Deploying period-aware views..."
	scripts/run_sql.sh -f sql/phase2/025_period_views.sql
	echo "✓ Period views deployed"

# Show available periods
periods-list:
	scripts/run_sql.sh -c "SELECT * FROM mart.v_available_periods;"

# Show period coverage summary
periods-coverage:
	scripts/run_sql.sh -c "SELECT * FROM mart.v_period_coverage;"

# Full multi-period ETL workflow
etl-multi-period:
	$(MAKE) initdb
	$(MAKE) deploy-period-views
	$(MAKE) load-multi-period
	$(MAKE) prep-map
	$(MAKE) load-mapping
	$(MAKE) refresh-optimized
	$(MAKE) periods-coverage

# Incremental load workflow (add new period to existing data)
etl-append-period:
	$(MAKE) load-multi-append
	$(MAKE) prep-map
	$(MAKE) load-mapping
	$(MAKE) refresh-optimized
	$(MAKE) periods-coverage

# Benchmark comparison: old vs new loader
benchmark-load:
	echo "Benchmark: Testing old (preprocessed) vs new (direct) loader..."
	echo "Old method (with preprocessing):"
	time $(MAKE) etl-load
	echo ""
	echo "New method (direct parallel):"
	$(MAKE) down
	$(MAKE) up-wait
	time $(MAKE) etl-load-fast

# ──────────────────────────────────────────────────────────────────────────────
# Optimized Views and Refresh (10-100x faster query performance)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: enable-optimized-views refresh-optimized benchmark-views disable-optimized-views

# Deploy optimized view definitions (uses materialized views instead of raw tables)
enable-optimized-views:
	echo "Deploying optimized view definitions..."
	scripts/run_sql.sh -f sql/phase2/000_optimized_refresh.sql
	echo "✓ Optimized views deployed. Use 'make refresh-optimized' for parallel refresh."

# Parallel refresh with timing metrics
refresh-optimized:
	echo "Running optimized parallel refresh..."
	scripts/run_sql.sh -c "SELECT * FROM core.refresh_all_parallel();"

# Benchmark old vs optimized view performance
benchmark-views:
	echo "Benchmarking view query performance..."
	echo ""
	echo "=== Testing OLD v_level1 (reads raw.va_txn) ==="
	scripts/run_sql.sh -c "\timing on" -c "SELECT COUNT(*) FROM mart.v_level1;"
	echo ""
	echo "=== Deploying OPTIMIZED v_level1 (reads core.mv_va_txn) ==="
	$(MAKE) enable-optimized-views
	$(MAKE) refresh-optimized
	echo ""
	echo "=== Testing OPTIMIZED v_level1 ==="
	scripts/run_sql.sh -c "\timing on" -c "SELECT COUNT(*) FROM mart.v_level1;"
	echo ""
	echo "Expected speedup: 10-100x on large datasets"

# Restore original (non-optimized) views
disable-optimized-views:
	echo "Restoring original view definitions..."
	scripts/run_sql.sh -f sql/phase2/000_core_refresh_fn.sql
	scripts/run_sql.sh -f sql/phase2/004_core_inter_sku_transfers.sql
	scripts/run_sql.sh -f sql/phase2/010_mart_views.sql
	echo "✓ Original views restored."

# ──────────────────────────────────────────────────────────────────────────────
# Complete ETL Pipeline (One Command)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: etl-complete etl-reload

# Complete pipeline: Database + ETL + Optimizations + Web Interface
etl-complete:
	@echo "=========================================="
	@echo "Complete ETL Pipeline"
	@echo "=========================================="
	@echo ""
	@echo "Step 1/7: Starting database..."
	$(MAKE) up-wait
	@echo ""
	@echo "Step 2/7: Initializing database schema..."
	$(MAKE) bootstrap
	@echo ""
	@echo "Step 3/7: Deploying optimized views..."
	$(MAKE) enable-optimized-views
	$(MAKE) deploy-period-views
	@echo ""
	@echo "Step 4/7: Loading CSV data..."
	$(MAKE) load-fast
	@echo ""
	@echo "Step 5/7: Generating and loading mappings..."
	$(MAKE) prep-map
	$(MAKE) load-mapping
	@echo ""
	@echo "Step 6/7: Refreshing materialized views..."
	$(MAKE) refresh-optimized
	@echo ""
	@echo "Step 7/7: Starting web interface..."
	$(MAKE) webapp-up
	@echo ""
	@echo "=========================================="
	@echo "✓ ETL Pipeline Complete!"
	@echo "=========================================="
	@echo ""
	@echo "Web Interface: http://localhost:8080"
	@echo "Database:      postgresql://appuser:changeme@localhost:5433/appdb"
	@echo ""
	@echo "Quick commands:"
	@echo "  make counts           - View row counts"
	@echo "  make periods-list     - Show loaded periods"
	@echo "  make etl-reload       - Reload ETL (new data)"
	@echo "  make down             - Stop everything"
	@echo ""

# Reload ETL (keep database running, reload data)
etl-reload:
	@echo "=========================================="
	@echo "Reloading ETL Data"
	@echo "=========================================="
	@echo ""
	@echo "Step 1/4: Loading CSV data..."
	$(MAKE) load-fast
	@echo ""
	@echo "Step 2/4: Regenerating mappings..."
	$(MAKE) prep-map
	$(MAKE) load-mapping
	@echo ""
	@echo "Step 3/4: Refreshing views..."
	$(MAKE) refresh-optimized
	@echo ""
	@echo "Step 4/4: Validating..."
	$(MAKE) validate-views
	@echo ""
	@echo "=========================================="
	@echo "✓ ETL Reload Complete!"
	@echo "=========================================="
	@echo ""
	$(MAKE) periods-list
