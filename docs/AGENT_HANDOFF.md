# Agent Handoff Log — FundedHere Reconciliation ETL

_Last updated: 2025-11-05_

## 1. Mission Snapshot
- **Objective**: Maintain the FundedHere reconciliation pipeline so CSV drops → Postgres mart refresh → parity/variance reporting are one-command operations.
- **Status**: ✅ All three views (v_level1, v_level2a, v_level2b) now match Excel formulas exactly. SQLAlchemy migration complete. 366 SKUs validated.

## 2. Recent Work (November 2025 Session)
### View Formula Fixes - Exact Excel Parity Achieved
- **Fixed v_level1 cartesian product bug**: Separated inflow/outflow aggregations into independent CTEs, eliminating 14x row multiplication. Amount Received now correctly sums only `merchant-repayment` transactions.
- **Fixed v_level2a inflow filter**: Changed from `merchant-repayment` only to ALL inflows EXCEPT `note-issued-transfer-to-sku`. This matches Excel's definition of total fund flow.
- **Fixed v_level2b inflow filter**: Applied same fix as v_level2a for consistency.
- **Verified Excel parity**: All values now match source Excel workbook (`pre_csv/full_wb.xlsx`) exactly.
- **Key insight discovered**: Sheet 1 vs Sheet 2a have different "Amount Received" definitions:
  - Sheet 1: ONLY merchant repayments (cash from merchants)
  - Sheet 2a/2b: ALL activity except initial note funding (total fund flow including transfers)

### Previous Work (October 2025)
- Simplified Windows Git Bash setup (documented Python/make/psql installs, PATH tweaks).
- Added Level-1 vs CSV reconciliation query so users see raw CSV totals alongside mart totals.
- Bundled the entire ETL toolchain (make + python + psql) into a single Docker image; README updated with "build once, run anywhere" instructions.
- README now explains how to connect pgAdmin/DBeaver to the containerized Postgres (`localhost:5433`, db `appdb`, user `appuser`, pw `changeme`).
- **SQLAlchemy 2.0+ migration**: Converted all bash scripts to Python using SQLAlchemy for database operations. 75% code reduction (404→100 lines).

## 3. Active State
| Layer | Tables/Views | Notes |
|-------|---------------|-------|
| raw   | external_accounts, va_txn, repmt_sku, repmt_sales | 2025‑09 data loaded (32,049 rows total). Loads via Python SQLAlchemy with COPY command. |
| ref   | note_sku_va_map, remarks_category_map, v_active_period | 366 SKU mappings loaded. Active period: 2025-01-01 to 2025-09-30. |
| core  | mv_external_accounts, mv_va_txn, mv_repmt_sku, mv_repmt_sales | Materialized views for performance. |
| mart  | v_level1, v_level2a, v_level2b | ✅ All 366 SKUs present with exact Excel parity. Views use separate CTEs to avoid cartesian products. |

## 4. Key Findings / Variance Snapshot
- Average `Amount Pulled vs Received` variance ≈ **$0.20** (cash mostly balanced).
- Average `Received vs Sales` variance ≈ **$7.38**; the top SKUs (grill pans, etc.) differ by $90–$320.
- Example drill-down (query ready in repo):
  ```sql
  SELECT
    l.sku_id,
    s.csv_total_funds_inflow,
    s.csv_sales_proceeds,
    l.amount_pulled,
    l.amount_received,
    l.sales_proceeds,
    a."Amount Received"      AS l2a_amount_received,
    (
      a."Management Fee Paid" + a."Administrative Fee Paid" + a."Interest Difference Paid" +
      a."Senior Principal Paid" + a."Senior Interest Paid" + a."Junior Principal Paid" +
      a."Junior Interest Paid" + a."SPAR Paid"
    ) AS l2a_total_paid,
    a."Fund Transferred to Other SKU",
    a."Fund Transferred from Other SKU"
  FROM mart.v_level1 l
  LEFT JOIN (
    SELECT sku_id,
           ROUND(SUM(total_funds_inflow), 2) AS csv_total_funds_inflow,
           ROUND(SUM(sales_proceeds), 2)     AS csv_sales_proceeds
    FROM core.mv_repmt_sales
    GROUP BY sku_id
  ) s ON s.sku_id = l.sku_id
  LEFT JOIN mart.v_level2a a ON a."SKU ID" = l.sku_id
  WHERE l.sku_id LIKE 'JUICE BLENDED-6BLADE%';
  ```
  This helps finance explain why the Level‑1 “Amount Received” is lower than the CSV total (the missing dollars are sitting in the waterfall categories or transfers).

## 5. Open Items / Next Steps
1. ✅ ~~**View parity with Excel**~~ – COMPLETED. All three views now match Excel formulas exactly.
2. ✅ ~~**Remark categorisation**~~ – RESOLVED. Sheet 1 uses only `merchant-repayment`, Sheet 2a/2b uses all inflows except `note-issued-transfer-to-sku`.
3. **Automated tests for v_level2a/v_level2b** – Add Python tests similar to `test_level1_parity.py` that validate Sheet 2a/2b values against Excel.
4. **Variance policy** – Finance needs to define acceptable thresholds (e.g., ±$5 per SKU). Once set, update `scripts/sql-tests/check_level1_variance_tolerance.sql`.
5. **Web API layer** – Consider exposing mart views via FastAPI for programmatic access.
6. **Multi-period support** – Current views use single active period (2025-01-01 to 2025-09-30). Extend to support historical period comparisons.

## 6. Quick Commands
- Docker runner (from repo root or after pulling image):
  ```bash
  docker run --rm -it \
    -v "$(pwd)/data/inc_data:/app/data/inc_data" \
    -v "$(pwd)/data/pgdata:/app/data/pgdata" \
    fundedhere-etl
  ```
- Traditional workflow (Git Bash / Linux):
  ```bash
  make up
  make etl-verify
  make down
  ```
- Variance overview:
  ```bash
  bash scripts/run_sql.sh -c "
    SELECT sku_id,
           ROUND(amount_pulled - amount_received, 2) AS variance_cash,
           ROUND(sales_proceeds - amount_received, 2) AS variance_ui,
           merchant
    FROM mart.v_level1
    ORDER BY ABS(sales_proceeds - amount_received) DESC
    LIMIT 10;
  "
  ```

## 7. Risks / Watchouts
- Mapping file (`note_sku_va_map_prepped.csv`) still lacks `note_id`; watch for new exports that include it.
- Level‑1 parity test (`tests/test_level1_parity.py`) needs Bash to execute the shell helper (`scripts/run_sql.sh`). On Windows, run the suite via `bash scripts/run_test_suite.sh` if `make etl-verify` stops there.
- Variance guard intentionally logs warnings until policy is defined; do not flip it to “fail” prematurely.

---
_Keep this log updated so the next agent can jump in without re-running old discovery._
