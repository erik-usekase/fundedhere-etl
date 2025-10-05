# Validation Results

## Phase 1 & 2 Command Checks
- `make up-wait`: container profile `db-local-bind` already running; readiness confirmed via host `pg_isready`.
- `make prep-all`: normalised the four Google-exported CSVs into `./data/inc_data/*_prepped.csv`.
- `make load-all-fresh`: truncated `raw.external_accounts`, `raw.va_txn`, `raw.repmt_sku`, `raw.repmt_sales` then reloaded 2,718 / 28,599 / 366 / 366 rows respectively.
- `make load-mapping`: ingested the 366-row SKU↔VA map derived from the Level‑1 sheet; mapping coverage now equals the raw SKU universe.
- `make refresh`: executed `core.refresh_all()` and refreshed `core.mv_va_txn_flows` without error.
- `bash scripts/run_test_suite.sh`: full smoke now runs header validation, mapping coverage, mart row-count parity, then proceeds to the legacy SQL previews (variance check intentionally still failing pending business-approved tolerance).

## Script Behavior Notes
- `scripts/prep_all.sh` still expects the `*_2025-09.csv` naming pattern; update the helper before introducing new periods.
- `scripts/load_note_sku_va_map.sh` short-circuits when the mapping CSV is header-only, preventing accidental table wipes.
- `scripts/run_test_suite.sh` surfaces five guardrails up front (headers, mapping coverage, mart row counts, Level‑1 totals parity, Level‑1 spreadsheet parity) before continuing with the historical preview flow; only the variance tolerance step fails by design.

## Functional Observations
- `mart.v_level1` now lifts from the mapping universe, so all 366 SKUs surface even when pulls/receipts are zero. `Amount Received` restricts to `merchant_repayment` inflows per the Excel logic.
- `mart.v_level2a` already returned 366 SKUs; row-count parity guard confirms alignment with the raw sales feed.
- Variance columns remain large for many SKUs (matching the spreadsheet’s unresolved gaps); tolerance assertions are left failing until the business agrees on acceptable thresholds or fixes outstanding balances.

## Missing/Broken Links
- No orchestration target yet combines `prep-all`, `load-all-fresh`, `load-mapping`, ref bootstraps, and `refresh` into a single idempotent run.
- Variance tolerance script needs business-calibrated thresholds (current failure is expected and documents the outstanding reconciliation gaps).
