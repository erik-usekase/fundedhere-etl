# Documentation Overview

## Level Summary
- **Level 1 — Cash vs. Ledger**: Compares funds pulled from bank accounts (`raw.external_accounts`) with inflows recorded in the virtual-account ledger (`raw.va_txn`) and the sales proceeds extract (`raw.repmt_sales`). The mart view `mart.v_level1` surfaces the three measures per SKU/VA pair and exposes gap columns so variances stay visible.
- **Level 2a — Waterfall Execution**: Breaks each merchant repayment into the fee, interest, and principal buckets defined in the repayment expectations CSV (`raw.repmt_sku`). The view `mart.v_level2a` contrasts the cash movement categories from `core.v_flows_pivot` with the expected amounts and highlights any outstanding balances or inter-SKU transfers.
- **Level 2b — UI vs. Cashflow Cross-Check**: Aligns UI-facing totals (from the repayment expectations and sales CSVs) with the cash ledger aggregates. `mart.v_level2b` shows UI metrics, cashflow metrics, and a set of delta columns so downstream tools can explain discrepancies quickly.

## How the Docs Are Organised
- **`EXISTING_ANALYSIS.md`** — inventory of Make targets, scripts, and the current end-to-end workflow.
- **`RECONCILIATION_ANALYSIS.md`** — deep dive into schemas, materialised views, and reconciliation logic behind the Level views.
- **`FORMULA_MAPPING.md`** — side-by-side reference of CSV metrics and their SQL implementations.
- **`DATA_QUALITY_ISSUES.md`**, **`VALIDATION_RESULTS.md`**, **`TEST_GAPS.md`**, **`TESTING.md`** — quality, validation, and testing notes for the current data vintage.
- **`AGENT_HANDOFF.md`** — day-one orientation for the next team member.
- Supporting plans and roadmap notes live in **`ENHANCEMENT_PLAN.md`**.

## Bringing Up Postgres
- **Docker path**: run `scripts/db_up.sh` (or `make up`) to start Postgres on `localhost:5433`, `scripts/db_wait.sh` to block until ready, and `scripts/db_down.sh` to stop it. Data persists under `./data/pgdata`.
- **Existing server**: install Postgres, create the `appuser/appdb` pair, set `DB_MODE=host` or `remote` in `.env`, and execute the SQL files in `initdb/` followed by `sql/phase2/` to install schemas and views before loading CSVs.

Each document assumes the four source CSV extracts live in `data/inc_data/` and that they remain the authoritative view of the business logic. When a new period arrives, refresh the CSVs, rerun the prep/load pipeline, and update these docs with any schema or logic deltas.
