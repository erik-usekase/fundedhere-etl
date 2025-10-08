# Agent Handoff Log — FundedHere Reconciliation ETL

_Last updated: 2025-10-06T18:20:00Z_

## 1. Mission Snapshot
- **Objective**: Maintain the FundedHere reconciliation pipeline so CSV drops → Postgres mart refresh → parity/variance reporting are one-command operations.
- **Status**: September 2025 data loaded; Docker-based runner packaged; variance guard still acting as a warning until Finance sets tolerances.

## 2. Recent Work
- Simplified Windows Git Bash setup (documented Python/make/psql installs, PATH tweaks).
- Added Level-1 vs CSV reconciliation query so users see raw CSV totals alongside mart totals.
- Bundled the entire ETL toolchain (make + python + psql) into a single Docker image; README updated with “build once, run anywhere” instructions.
- README now explains how to connect pgAdmin/DBeaver to the containerized Postgres (`localhost:5433`, db `appdb`, user `appuser`, pw `changeme`).

## 3. Active State
| Layer | Tables/Views | Notes |
|-------|---------------|-------|
| raw   | external_accounts, va_txn, repmt_sku, repmt_sales | 2025‑09 sample loaded via `make etl-verify`. |
| ref   | note_sku_va_map, remarks_category_map | 366 SKU↔VA mappings from the Level‑1 reference CSV; `note_id` column remains blank. |
| core  | mv_external_accounts, mv_va_txn, mv_repmt_sku, mv_repmt_sales, v_flows_pivot, v_inter_sku_transfers | Views refresh successfully. `core.mv_va_txn` only labels ledger inflows tagged `merchant_repayment` as “received.” |
| mart  | v_level1, v_level2a, v_level2b | Present for all 366 SKUs. Variances still reflect unresolved business gaps; Level‑1 guard left in “warning” mode. |

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
1. **Variance policy** – Finance needs to define acceptable thresholds (e.g., ±$5 per SKU). Once set, update `scripts/sql-tests/check_level1_variance_tolerance.sql` and flip `FAIL_ON_LEVEL1_VARIANCE=1` in `.env` so the ETL fails when data is out of policy.
2. **Remark categorisation** – Investigate ledger categories such as `transfer-to-another-sku` and `loan-disbursement`; decide which should count toward “Amount Received” vs transfers.
3. **Level‑2 parity checks** – Add tests comparing `mart.v_level2a`/`v_level2b` with the respective reference CSVs (waterfall, UI vs cash).
4. **AI assistant integration (future)** – With the Docker runner in place, we can expose the mart via an API and let a GPT agent translate natural-language questions into SQL. No code yet; this is the intended next milestone.

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
