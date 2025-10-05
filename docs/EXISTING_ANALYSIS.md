# FundedHere ETL — Existing Workflow Analysis

## Makefile Targets
- **prep-data**: Ensures `${DATA_DIR}`/pgdata and `${DATA_DIR}`/inc_data exist before any DB action.
- **up / up-wait / down / logs**: Shell out to `scripts/db_*.sh` to manage Dockerized Postgres lifecycle and blocking readiness checks.
- **env / psql-host / sql / sqlf / refresh / counts**: Thin wrappers around `scripts/run_sql.sh`; `refresh` runs `scripts/sql-utils/refresh_core.sql`, `counts` prints raw table counts.
- **preview-cols / prep-* / prep-all**: Normalize incoming CSV headers via `scripts/preview_cols.py` or specific `prep_*.py` mappers; `prep-all` chains the four prep scripts against fixed `2025-09` filenames.
- **load-***: Call `scripts/load_raw.sh` with explicit column lists for each raw table; `load-all` cascades the individual loaders from `${INC_DIR}`; `load-all-fresh` truncates raw tables then calls `load-all`.
- **load-mapping**: Invokes `scripts/load_note_sku_va_map.sh` to (re)load `ref.note_sku_va_map` from a CSV, seeding `ref.merchant`/`ref.sku` on the fly. (Defaults to `${INC_DIR}/note_sku_va_map_prepped.csv`.)
- **test-health / test-level1**: Run canned SQL checks from `scripts/sql-tests` through `run_sql.sh`.

## Script Inventory
- **scripts/db_*.sh**: Docker Compose wrappers to start/stop (`db_up`, `db_down`), tail logs, and wait for readiness (`pg_isready` host-side first, then container fallback).
- **scripts/run_sql.sh**: Central psql runner honoring `.env` overrides and `DB_MODE`; used by Make targets and other scripts.
- **scripts/load_raw.sh**: Generates `\copy` statements (gzip-aware) and invokes `run_sql.sh`; expects canonical column lists matching the raw table definitions (minus metadata fields).
- **scripts/prep_*.py**: Header-normalizing CSV re-writers that look up aliases for each required column and emit canonical headers for the loaders.
- **scripts/prep_all.sh**: Convenience orchestrator that calls each prep script with hard-coded `*_2025-09.csv` sources, tolerating missing files.
- **scripts/preview_cols.py**: Prints raw and normalized column names for quick inspection.
- **scripts/load_note_sku_va_map.sh**: Drives the mapping load workflow—upserts merchants/SKUs from `core.mv_repmt_sales`, overlays `ref.note_sku_va_map` from a prepped CSV, and reports coverage (requires user-supplied data beyond the header-only template).
- **scripts/run_test_suite.sh**: Sequential demo harness that loads mappings, refreshes marts, and prints Level-1/Level-2 previews plus category audits.
- **scripts/run_outflow_demo.sh**: Inserts sample outflows, refreshes, and displays Level-2 results.

## Workflow Summary
1. **Infrastructure**: `make up-wait` → Docker Postgres + readiness.
2. **DDL Bootstrap**: `initdb/*.sql` (schemas, extensions, security, raw/ref tables) then `sql/phase2/*.sql` for core helpers/MVs/marts.
3. **Prep Inputs**: `make prep-all` (or individual `prep-*`) writes `*_prepped.csv` into `${INC_DIR}`.
4. **Load Raw**: `make load-all` or `load-all-fresh` copies prepped CSVs into `raw.*` using column lists aligned with `initdb/100_raw_tables.sql`.
5. **Transform**: `scripts/sql-utils/refresh_core.sql` → `core.refresh_all()` plus manual `REFRESH MATERIALIZED VIEW core.mv_va_txn_flows;` (Phase-2 scripts handle flow views, transfers, and mart views).
6. **Reconciliation Views**: `mart.v_level1` now anchors on `ref.note_sku_va_map` (all SKU/VA rows) with receipts limited to `merchant_repayment` inflows; `mart.v_level2a` continues to aggregate waterfall distributions off `core.v_flows_pivot`.
7. **Tests/Demos**: `scripts/run_test_suite.sh` and `run_outflow_demo.sh` orchestrate SQL scripts under `scripts/sql-tests/` for inspection.

## Intended Execution Order
- Bring up DB (`make up-wait`).
- Run DDL stack (initdb then `sql/phase2`).
- Prepare CSVs (`make prep-all`).
- Load raw tables (`make load-all-fresh`).
- Seed reference mappings (`scripts/sql-tests/t10_*.sql`, `t20_*.sql`).
- Refresh transforms (`make refresh` or `scripts/sql-tests/refresh.sql`).
- Inspect reconciliations (`scripts/sql-tests/level1_pretty.sql`, `level2a_preview.sql`) and optional demos/tests.
