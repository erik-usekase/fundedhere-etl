# FundedHere ETL + Postgres (Docker Compose) — README

_Last updated: 2025-10-04 19:20 UTC_

This repository provides a reproducible, Docker‑Compose–based Postgres setup plus a thin Makefile and helper scripts to prepare/load CSVs and materialize marts for reconciliation (Level‑1 now; Level‑2 next).

---

## What you get

- **Dockerized Postgres** bound to host port **5433** (so it never collides with host 5432)
- **Schemas**: `raw`, `ref`, `core`, `mart`
- **Scripts** under `./scripts/` for DB lifecycle, SQL execution (pager‑free), CSV prep and loads
- **Phase‑2 SQL** under `sql/phase2/` (core functions + MVs + level‑1 mart)
- **SQL test scripts** under `scripts/sql-tests/` to avoid shell quoting issues

---

## Directory layout

```
./docker-compose.yml
./.env                      # environment (optional; Make/Scripts read it)
./data/
  pgdata/                   # postgres data (mounted volume)
  inc_data/                 # drop input CSVs here
./initdb/                   # base DDL (schemas, ref tables, raw tables,…)
./sql/phase2/               # core funcs/MVs + mart views (generated)
./scripts/
  db_up.sh / db_down.sh / db_wait.sh / db_logs.sh
  run_sql.sh                # psql wrapper (pager off, ignores ~/.psqlrc)
  load_raw.sh               # COPY loader (csv or csv.gz)
  prep_*.py / prep_all.sh   # CSV normalization
  sql-utils/
    counts.sql
    refresh_core.sql
  sql-tests/                # safe-to-run test SQL (no quoting headache)
```

---

## Environment configuration

Set in `.env` (optional—defaults shown):

```ini
# run the container and bind host:5433 -> container:5432
DB_MODE=container-bind

# image + credentials
POSTGRES_IMAGE=postgres:16
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=changeme

# host bind port (matches docker-compose.yml)
POSTGRES_PORT=5433

# client defaults (used by scripts/run_sql.sh and Make targets)
PGHOST=localhost
PGPORT=5433
PGDATABASE=appdb
PGUSER=appuser
PGPASSWORD=changeme
PGSSLMODE=disable

# optional; blank -> ./data
DATA_DIR=
TZ=UTC
```

> **Effect:** `DB_MODE=container-bind` means Make/scripts control the Compose service; SQL commands target `localhost:5433`.  
> For **host Postgres** (no container), set `DB_MODE=host` and `PGPORT=5432`. For **remote**, use `DB_MODE=remote` and `REMOTE_*` variables.

---

## Make targets (what they do & side‑effects)

- `make prep-data`  
  Creates: `./data/pgdata`, `./data/inc_data` (or `${DATA_DIR}/...`).

- `make up`  
  Starts the Postgres container (profile `db-local-bind`). **Side‑effect:** creates/uses the mounted volume at `data/pgdata`.

- `make up-wait`  
  `make up` + wait until Postgres is ready (checks host first, then inside container).

- `make down`  
  Stops Compose services (does **not** delete the volume).  
  To wipe data **completely**, run `docker compose down -v` and/or `rm -rf ./data/pgdata/*`.

- `make logs`  
  Follows the Postgres container logs.

- `make env`  
  Prints effective environment (Make’s view).

- `make psql-host`  
  Opens interactive psql to the configured DB.

- `make sql CMD='…'`  
  Executes a **single‑line** SQL command (no pager).  
  _Use single quotes around the entire SQL and double quotes for identifiers._

- `make sqlf FILE=path.sql`  
  Executes a SQL file. **Preferred** for multi‑line SQL (no quoting issues).

- `make refresh`  
  Runs `scripts/sql-utils/refresh_core.sql` (calls `core.refresh_all()`).

- `make counts`  
  Runs `scripts/sql-utils/counts.sql` (row counts for `raw.*`).

### CSV prep & load

- `make preview-cols FILE=path.csv`  
  Shows raw + normalized column names.

- `make prep-external SRC=... OUT=...`  
  Canonicalizes external accounts headers to:  
  `beneficiary_bank_account_number,buy_amount,buy_currency,created_date`

- `make prep-vatxn SRC=... OUT=...`  
  Canonicalizes VA txn headers to:  
  `sender_virtual_account_id,sender_virtual_account_number,sender_note_id,receiver_virtual_account_id,receiver_virtual_account_number,receiver_note_id,receiver_va_opening_balance,receiver_va_closing_balance,amount,date,remarks`

- `make prep-repmt-sku SRC=... OUT=...`  
  Canonicalizes Repmt‑SKU headers.

- `make prep-repmt-sales SRC=... OUT=...`  
  Canonicalizes Repmt‑Sales headers.

- `make prep-all`  
  Runs all preps (writes `*_prepped.csv` into `./data/inc_data`).

- `make load-external FILE=...`  
  Loads into `raw.external_accounts` via `COPY` (supports `.csv` or `.csv.gz`).

- `make load-vatxn FILE=...`  
  Loads into `raw.va_txn`.

- `make load-repmt-sku FILE=...`  
  Loads into `raw.repmt_sku`.

- `make load-repmt-sales FILE=...`  
  Loads into `raw.repmt_sales`.

- `make load-all`  
  Scans `./data/inc_data` for the above files (prefers `*_prepped.csv`) and loads each table.

> **Side‑effects:** load targets insert rows into `raw.*`. `refresh` rebuilds `core.mv_*` materialized views, which power `mart.*`.

---

## First‑time setup (from clean checkout)

```bash
# 1) Start DB and wait
make up-wait

# 2) Create base schemas/tables (skip any you don't have)
make sqlf FILE=initdb/000_schemas.sql
make sqlf FILE=initdb/010_extensions.sql
make sqlf FILE=initdb/020_security.sql
make sqlf FILE=initdb/100_raw_tables.sql
make sqlf FILE=initdb/200_ref_tables.sql

# 3) Phase‑2 objects (core funcs/MVs + marts)
make sqlf FILE=sql/phase2/001_core_types.sql
make sqlf FILE=sql/phase2/002_core_mviews.sql
make sqlf FILE=sql/phase2/010_mart_views.sql
```

---

## Load sample data

```bash
# 1) Normalize your CSVs
make prep-all

# 2) Load raw tables
make load-external    FILE=./data/inc_data/external_accounts_prepped.csv
make load-vatxn       FILE=./data/inc_data/va_txn_prepped.csv
make load-repmt-sku   FILE=./data/inc_data/repmt_sku_prepped.csv
make load-repmt-sales FILE=./data/inc_data/repmt_sales_prepped.csv

# 3) Seed mappings for your sample merchant / SKU / VAs
make sql CMD="insert into ref.merchant(merchant_name) values ('ABC Sdn Bhd') on conflict do nothing;"
make sql CMD="select merchant_id from ref.merchant where merchant_name='ABC Sdn Bhd';"
# copy the UUID returned and substitute into the next two commands

make sql CMD="insert into ref.sku(sku_id, merchant_id) values ('NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','<MERCH_UUID>') on conflict do nothing;"
make sql CMD="insert into ref.note_sku_va_map(note_id,sku_id,va_number,merchant_id) values ('44','NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','8850633926172','<MERCH_UUID>') on conflict do nothing;"
make sql CMD="insert into ref.note_sku_va_map(note_id,sku_id,va_number,merchant_id) values ('44','NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','8850633781134','<MERCH_UUID>') on conflict do nothing;"

# 4) Build typed layer / marts
make sqlf FILE=scripts/sql-tests/refresh.sql

# 5) Sanity checks
make counts
make sqlf FILE=scripts/sql-tests/level1_count.sql
make sqlf FILE=scripts/sql-tests/level1_pretty.sql
```

---

## Using the bundled SQL test scripts

All live under `scripts/sql-tests/` and run with `make sqlf FILE=...`:

- `refresh.sql` — rebuilds materialized views  
- `level1_pretty.sql` — Level‑1 with your target column names  
- `level1_count.sql`, `chain_status.sql` — quick health checks  
- `category_breakdown.sql` — how remarks were categorized  
- `mappings_check.sql` — verify VA→SKU mappings line up with external accounts  
- `top_va_pulled.sql` — VAs with highest pulled amounts  
- `v_level1_export_view.sql` + `v_level1_export_select.sql` — pretty export view & query

> **No pager:** `scripts/run_sql.sh` forces pager off, ignores `~/.psqlrc`, and prints directly to the shell.

---

## Troubleshooting

**Port collision on 5432**  
If you also run a host Postgres on 5432, the container must bind to 5433:
- Ensure `POSTGRES_PORT=5433` in `.env`
- Ensure `ports: - "${POSTGRES_PORT}:5432"` in `docker-compose.yml`
- Check mapping: `docker compose port postgres 5432`

**Compose up but wait times out**  
- `docker compose logs -f postgres` (look for “ready to accept connections”)  
- `ss -ltnp | grep 5433` — ensure something is listening  
- Old/invalid config in `./data/pgdata/postgresql.conf`: remove/rename or reset (fresh volume)

**“function core.refresh_all() does not exist”**  
Run the phase‑2 SQL files under `sql/phase2/` first.

**Multi‑line SQL or fancy quoting fails**  
Put SQL in a file and run `make sqlf FILE=...`.

---

## Large files & performance

- Loaders use `COPY` (fast). Also supports `.csv.gz` via `load_raw.sh`.  
- Add indexes to your `core.mv_*` and `mart.*` as needed (some are included).  
- Keep `ref.remarks_category_map` and `ref.note_sku_va_map` small and indexed; they’re looked up frequently.

---

## Next steps (Level‑2)

We’ll add:
- `mart.v_level2a` — Paid vs Expected by category (waterfall)
- `mart.v_level2b` — UI vs VA reconciliation (parity checks)

Those will build on `core.mv_va_txn` categorization and the Repmt‑SKU expectations.

---

## Safety / data reset

- **Stop container**: `make down`  
- **Remove data volume** (destructive): `docker compose down -v && rm -rf ./data/pgdata/*`
