# Agent Handoff Log — FundedHere Reconciliation ETL

_Last updated: 2025-10-05T23:11:37Z_

## 1. Mission Snapshot
- **Objective**: Reproduce the FundedHere Level-1 and Level-2 repayment reconciliations in Postgres using the provided CSV exports as the source of truth.
- **Key Outputs**: `mart.v_level1` (Pulled vs Received vs Sales), `mart.v_level2a` (Received vs Waterfall distribution), and `mart.v_level2b` (UI vs VA parity) aligned with the latest reference CSV logic.
- **Data Vintage**: September 2025 sample (366 SKUs, ~28.6k VA ledger rows).

## 2. What’s in the Repo
- `data/inc_data/` now holds:
  - Raw CSV exports (`Sample Files(...).csv`) for bank pulls, VA ledger, SKU expectations, sales proceeds, plus reference "Data List / Formula & Output" outputs.
  - Harmonised copies (`*_2025-09.csv`) and prepped loader inputs (`*_prepped.csv`).
  - `note_sku_va_map_prepped.csv` (366 SKU→VA mappings parsed from the Level-1 reference export; `note_id` currently blank).
- `scripts/load_note_sku_va_map.sh` + supporting SQL utils handle ingest of the mapping CSV.
- Test harness additions: `tests/test_csv_headers.sh`, `tests/test_level1_parity.py`, and SQL checks for mapping coverage, row counts, totals, and variance tolerance.

## 3. Current State (2025-09 Data)
- `make load-all-fresh` + `make load-mapping` hydrate 2,718 pulls / 28,599 VA ledger rows / 366 SKUs and populate `ref.note_sku_va_map`; coverage assertion passes.
- `mart.v_level1` now outputs all 366 SKU/VA rows (derived from the mapping universe) with receipts restricted to `merchant_repayment` inflows. `mart.v_level2a` and `mart.v_level2b` both return 366 SKUs as well.
- Test harness enforces CSV headers, mapping coverage, mart row counts, Level‑1 totals parity, Level‑1 reference parity, and then stops at the variance tolerance guard (expected failure until policy is defined).
- Level-1 variance tolerance script still fails (all 366 rows) because the reference dataset carries large outstanding gaps; leave this failure in place until business clarifies acceptable thresholds.

## 4. Active Work Items
1. **Variance Interpretation & Categorisation**
   - Investigate high-volume remarks still tagged `uncategorized` (e.g., `transfer-to-another-sku`, `loan-disbursement`) and document how they should affect Level‑1/Level‑2 variance columns.
   - Define acceptable variance tolerances with finance, then update `scripts/sql-tests/check_level1_variance_tolerance.sql` accordingly (it currently fails on all SKUs to highlight the gap).
2. **Level-2 Parity & Reporting**
   - Add automated parity checks for `mart.v_level2a` (waterfall paid vs expected) and `mart.v_level2b` (UI vs VA).
   - Address FH Platform Fee logic once finance clarifies how those transactions present in the VA ledger.
3. **Automation Enhancements**
   - Consider a composite Make target (`etl-all`) chaining prep, load, mapping, refresh, and tests for one-click reruns.

## 5. Immediate Next Steps for Incoming Agent
- Profile the largest residual variances to understand whether they stem from legitimate business gaps or missing remark mappings:
  - `select sku_id, "Amount Pulled", "Amount Received", "Variance Pulled vs Received" from mart.v_level1 order by abs("Variance Pulled vs Received") desc limit 20;`
  - `select remarks, sum(signed_amount) from core.mv_va_txn_flows where sku_id = '<sku>' group by remarks order by 2 desc;`
- Draft an updated `ref.remarks_category_map` (or complementary logic) that classifies `transfer-to-another-sku`, `loan-disbursement`, etc., per finance guidance and decide how they should influence Level‑1/Level‑2 variances.
- Design Level‑2b parity tests (totals + reference CSV comparison) once Finance signs off on CF bucket definitions.
- Once a tolerance policy is agreed, update `scripts/sql-tests/check_level1_variance_tolerance.sql` so the test suite reflects the new rules (and passes when reconciliations are within bounds).

## 6. Helpful Commands
```
make load-all-fresh
make load-mapping
make refresh
make counts
make sqlf FILE=scripts/sql-tests/level1_pretty.sql
make sqlf FILE=scripts/sql-tests/level2a_preview.sql
```

## 7. Known Risks / Open Questions
- `note_id` is blank in the mapping CSV; if future exports carry note identifiers we should plumb them through for traceability.
- Transfers between SKUs (or top-ups) may require special handling to avoid double counting in Level-1/Level-2.
- Ensure CSV exports remain in sync; if a new period is introduced, update filenames and re-run prep/load.

---
_Keep this log updated whenever new work begins or ends so the next agent can resume without guesswork._
