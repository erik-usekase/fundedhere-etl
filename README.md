# Reconciliation ETL → Postgres (L1/L2) — Dev README (Updated)

> **Purpose**: Stand-up a repeatable pipeline to load monthly CSVs, normalize into Postgres, and reproduce the Excel reconciliation outputs as SQL views — ready to serve time-sliced chunks to an LLM during user interaction.

This README captures **current state**, **how to run/demo**, and **what’s next** so you can present and evolve the system with confidence.

---

## 1) Architecture (quick view)

**Layers**
- `raw.*` — CSV-as-is staging (one table per input).
- `ref.*` — small mapping tables for keys and categories.
- `core.*` — typed/clean MVs, transaction **flows** & pivots, inter-SKU transfers.
- `mart.*` — business views for reconciliations (Level-1 and Level-2a).

**Key refs**
- `ref.note_sku_va_map` — joins Notes/SKU/VA/merchant across inconsistent inputs.
- `ref.remarks_category_map` — turns raw remarks into waterfall categories (admin/mgmt fees, sr/jr principal/interest, SPAR, funds_to_sku, etc.).

**LLM fit**
- Every core MV carries a `period_ym` (e.g., `2025-09`) to stream **time-chunked** slices to your LLM/API on-demand.

---

## 2) Current State (what works)

- **Infra**: Docker-based Postgres (or host/remote), controlled via **Makefile + scripts**.
- **Schemas**: `raw`, `ref`, `core`, `mart` created; `pgcrypto`, `pg_trgm` enabled.
- **Core helpers**: `core.to_numeric_safe(...)`, `core.to_tstz_safe(...)` (robust casts).
- **Core MVs**: 
  - `core.mv_external_accounts`, `core.mv_repmt_sku`, `core.mv_repmt_sales`
  - `core.mv_va_txn_flows` + `core.v_flows_pivot` (Option‑B applied to treat _funds_to_sku_ as inflow).
  - `core.v_inter_sku_transfers` (aggregates between-SKU moves).
- **Mart views**: 
  - `mart.v_level1` — Pulled vs Received vs Sales (per SKU + VA).
  - `mart.v_level2a` — Waterfall: Paid vs Expected (+ Transfers columns).
- **Refresh**: `scripts/sql-tests/refresh.sql` (and `core.refresh_all()` if installed).
- **Testing**: Ready-to-run scripts in `scripts/sql-tests/*` + runners to avoid shell quoting issues.

**Demo data results**
- Level‑1 displays rows for mapped SKU+VA, showing **Pulled**, **Received** (via `funds_to_sku` inflows or merchant repayments), **Sales Proceeds**, and variances.
- Level‑2 shows **Paid buckets** when outflow rows with mapped remarks are present; **Transfers** columns light up when cross‑SKU VA→VA rows are inserted.

> **Note**: Tests are cumulative; re-inserting demo outflows will double totals unless you clean them up first (see _Repeatable Testing_ below).

---

## 3) One-Command Paths (for demos)

### A) Fresh reset → bring-up → L1/L2 smoke
```bash
make down || true && rm -rf ./data/pgdata && make up-wait

make sqlf FILE=initdb/000_schemas.sql
make sqlf FILE=initdb/010_extensions.sql
make sqlf FILE=initdb/020_security.sql
make sqlf FILE=initdb/100_raw_tables.sql
make sqlf FILE=initdb/200_ref_tables.sql

make sqlf FILE=sql/phase2/001_core_types.sql
make sqlf FILE=sql/phase2/002_core_basic_mviews.sql

# flows (drop pivot first if present)
make sql CMD='DROP VIEW IF EXISTS core.v_flows_pivot; DROP MATERIALIZED VIEW IF EXISTS core.mv_va_txn_flows;'
make sqlf FILE=sql/phase2/003_core_mviews_flows.sql
make sqlf FILE=sql/phase2/021_category_funds_to_sku.sql
make sqlf FILE=sql/phase2/022_update_flows_pivot.sql
make sqlf FILE=sql/phase2/004_core_inter_sku_transfers.sql

# marts
make sql CMD='DROP VIEW IF EXISTS mart.v_level2a CASCADE;'
make sqlf FILE=sql/phase2/010_mart_level1.sql
make sqlf FILE=sql/phase2/020_mart_level2.sql

# load + map
make prep-all
make load-all-fresh
make sqlf FILE=scripts/sql-tests/t10_bootstrap_merchant.sql
make sqlf FILE=scripts/sql-tests/t20_bootstrap_sku_and_map.sql

# refresh + preview
make sqlf FILE=scripts/sql-tests/refresh.sql
make sqlf FILE=scripts/sql-tests/level1_pretty.sql
make sqlf FILE=scripts/sql-tests/level2a_preview.sql
```

### B) Insert demo outflows (to light up Level‑2 “Paid”)
```bash
make sqlf FILE=scripts/sql-tests/t80_insert_outflow_sample.sql
make sqlf FILE=scripts/sql-tests/refresh.sql
make sqlf FILE=scripts/sql-tests/level2a_preview.sql
```

### C) End-to-end demo runners
```bash
bash scripts/run_test_suite.sh
bash scripts/run_outflow_demo.sh
```

---

## 4) Repeatable Testing (no surprises)

- **Clean slate**: `make load-all-fresh` truncates `raw.*`. For demo outflows, delete the prior rows first:
```sql
delete from raw.va_txn
where sender_virtual_account_number='8850633926172'
  and date='9/30/2025'
  and remarks in ('fh-admin-fee','management fee','sr principal');
```
- **Idempotent demo** (optional): guard demo inserts with `NOT EXISTS` on a composite key (e.g., `(va, date, remarks, amount)`).
- **Quoting hygiene**: prefer `make sqlf FILE=...` over multiline `CMD=...` to avoid shell parsing errors.
- **Re-applying flows**: if you re-run `003_core_mviews_flows.sql`, re-apply `021` + `022`, then refresh.

---

## 5) Presenter Notes (what to say)

### 90‑second story
1. **Problem**: monthly reconciliations lived in Excel — slow, opaque, hard to automate.
2. **Solution**: schema‑first ETL → Postgres (`raw`→`ref`→`core`→`mart`), with mappings that normalize notes, SKUs, and remarks to business categories.
3. **Outputs**: 
   - Level‑1: Pulled vs Received vs Sales per SKU/VA, highlighting variances.
   - Level‑2: Waterfall Paid vs Expected (+ inter‑SKU transfers), ready to troubleshoot gaps.
4. **LLM‑ready**: each row is keyed by `(merchant, sku_id, period_ym)`, so we can **stream month‑sized chunks** directly to an agent API during user interaction.

### 5‑minute deep‑dive
- Show **Make targets** (infra up, prep/load, refresh).
- Open `ref.note_sku_va_map` to explain **how joins work** across inputs.
- Open `ref.remarks_category_map` to show **how a free‑form remark becomes a category**.
- Run Level‑1 and Level‑2 queries; insert demo outflows and refresh to reveal **Paid buckets**.
- Point out `core.v_inter_sku_transfers` driving the **“Fund Transferred to/from Other SKU”** columns.
- Close with **period_ym slicing** and how the agent would request chunks (e.g., “give me 2025‑09 for merchant X, SKU Y”).

---

## 6) What’s Next (roadmap)

1. **Level‑2b (UI vs VA parity)**: Build `mart.v_level2b` to compare UI totals vs VA-derived amounts and surface variances (inflow + each paid category).
2. **Idempotent loaders**: add simple uniqueness/dedupe per period (e.g., row hash) to resist double loads.
3. **Parametric time slicing**: a tiny SQL function or parameterized view to emit `(merchant, sku, period_ym)` slices for the agent.
4. **Performance**: confirm indexes on `(period_ym)`, `(merchant_id, sku_id)`, and add where most queried; consider CONCURRENT refresh with unique indexes.
5. **Governance**: version `ref.*` mappings, add **parity checks** (totals vs Excel) in CI, and a small dashboard for mapping gaps.
6. **Prod readiness**: connection secrets via env, backups, remote Postgres (e.g., Azure), and a migration story (versioned SQL files).

---

## 7) Command Cheat‑Sheet

```bash
# Infra
make up-wait           # start Postgres and wait
make down              # stop Postgres
make env               # show effective configuration

# Data
make prep-all          # write *_prepped.csv into ./data/inc_data
make load-all-fresh    # truncate raw.* and load prepped files
make counts            # raw table counts

# SQL (safe)
make sqlf FILE=...     # run a .sql file
make sql CMD="select 1"   # single-line only (avoid multiline)

# Tests
make sqlf FILE=scripts/sql-tests/level1_pretty.sql
make sqlf FILE=scripts/sql-tests/level2a_preview.sql
make sqlf FILE=scripts/sql-tests/category_audit_top50.sql
bash scripts/run_test_suite.sh
bash scripts/run_outflow_demo.sh
```

---

## 8) File Map (where things live)

```
initdb/                 # schemas, extensions, raw/ref DDL
sql/phase2/             # core helpers, MVs, marts
scripts/sql-tests/      # curated test SQL (no quoting issues)
scripts/*.sh            # compose & psql helpers (db_up, run_sql, loaders)
data/inc_data/          # input CSVs & *_prepped.csv
```

---

### Appendix: Why Option‑B?
For our sample partner, funds commonly arrive into SKU VAs as “**note-issued-transfer-to-sku**”. Option‑B maps these to a business concept of **Amount Received** so Level‑1/L2 reconcile correctly against UI totals. This is configurable via `ref.remarks_category_map` and can evolve merchant-by-merchant.
