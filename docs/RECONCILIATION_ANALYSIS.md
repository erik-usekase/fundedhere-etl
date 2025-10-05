# Reconciliation ETL Analysis

## 1. Schema & Data Flow
- **raw.external_accounts → Bank pulls**: Mirror of bank export (`beneficiary_bank_account_number`, `buy_amount`, `buy_currency`, `created_date`). Loaded via `scripts/load_raw.sh` and transformed into `core.mv_external_accounts` (see `sql/phase2/002_core_basic_mviews.sql`) where amounts are cast with `core.to_numeric_safe` and a `period_ym` tag is derived.
- **raw.va_txn → Virtual account receipts**: Bank/VA ledger (`sender_*`, `receiver_*`, `amount`, `date`, `remarks`). `core.mv_va_txn_flows` (from `sql/phase2/003_core_mviews_flows.sql` + `022_update_flows_pivot.sql`) casts numerics, categorizes remarks using `ref.remarks_category_map`, and doubles each transaction into inflow/outflow rows keyed by VA/SKU.
- **raw.repmt_sales → Sales proceeds**: UI extract with totals by merchant/SKU. `core.mv_repmt_sales` normalizes and casts values, preserving `total_funds_inflow`, `sales_proceeds`, and `l2e` metrics.
- **raw.repmt_sku → Expected waterfall**: UI expectations for fees/principal/interest/ SPAR per SKU. `core.mv_repmt_sku` casts each measure for comparison.

**Pipeline progression**
1. **Raw layer** populated via COPY.
2. **Core layer** materialized views:
   - `core.mv_external_accounts`, `core.mv_repmt_sales`, `core.mv_repmt_sku` (typed, with `period_ym`).
   - `core.mv_va_txn_flows` (categorised inflow/outflow ledger).
   - `core.v_flows_pivot` (per-SKU aggregation of receipt + waterfall categories).
   - `core.v_inter_sku_transfers` / `_agg` (detect cross-SKU movements).
3. **Mart layer**:
   - `mart.v_level1` (bank pull vs VA receipt vs sales).
   - `mart.v_level2a` (VA receipts vs expected waterfall, including transfers).

Level-1 reconciliation occurs entirely in `mart.v_level1` by joining the three core MVs on SKU + VA mapping (`ref.note_sku_va_map`). Level-2 reconciliation happens in `mart.v_level2a`, combining `core.v_flows_pivot`, `core.mv_repmt_sku`, and `core.v_inter_sku_transfers_agg`.

## 2. Business Logic Inventory
- **Casting helpers (`sql/phase2/001_core_types.sql`)**: `core.to_numeric_safe`, `core.to_tstz_safe`, and related utility functions ensure non-numeric strings coerce to NULL rather than erroring. All downstream calculations rely on these sanitized numerics.
- **Receipt categorisation (`sql/phase2/003_core_mviews_flows.sql`)**:
  - Remarks matched against `ref.remarks_category_map` (priority-ordered exact/regex). Default category `uncategorized` if no hit.
  - Each raw transaction yields two rows: receiver-as-inflow and sender-as-outflow, both with signed amounts for easy aggregation.
- **Waterfall pivot (`sql/phase2/022_update_flows_pivot.sql`)**:
  - `amount_received`: inflows tagged `merchant_repayment` or `funds_to_sku`.
  - Paid buckets: sums of negative signed amounts per category (`admin_fee`, `mgmt_fee`, `int_diff`, `sr_prin`, `sr_int`, `jr_prin`, `jr_int`, `spar`).
- **Expected waterfall (`sql/phase2/002_core_basic_mviews.sql`)**:
  - `acquirer_fees_expected` is re-exposed as management fee expectations.
  - Additional expected columns map 1:1 from raw UI data (admin, interest diff, sr/jr principal/interest, SPAR).
- **Variance/outstanding logic (`sql/phase2/020_mart_level2.sql`)**:
  - `Amount Distributed Down the Repayment Waterfall` = sum of all paid categories.
  - Outstanding = expected minus paid for each category (simple subtraction, no tolerance applied).
- **Inter-SKU transfers (`sql/phase2/004_core_inter_sku_transfers.sql`)**:
  - Filters VA transactions where sender and receiver map to different SKUs; aggregates to per-SKU totals for funds moved out/in.
- **Refresh orchestration (`sql/phase2/000_core_refresh_fn.sql` & `scripts/sql-utils/refresh_core.sql`)**:
  - `core.refresh_all()` refreshes all core materialized views and defers to `core.mv_va_txn_flows` after the base MVs are up to date.

## 3. Level-1 vs Level-2
- **Level-1 (`sql/phase2/010_mart_level1.sql`)**:
  - Universe comes from `ref.note_sku_va_map` (one row per SKU/VA pair), ensuring all 366 SKUs emit even when values are zero.
  - `Amount Pulled` = sum of `core.mv_external_accounts.buy_amount` keyed by VA number and SKU.
  - `Amount Received` = inflow sum where `category_code = 'merchant_repayment'` (top-ups such as `funds_to_sku` are broken out separately in `core.v_flows_pivot`).
  - `Sales Proceeds` = sum of UI sales from `core.mv_repmt_sales` (joined by SKU, replicated across VA rows).
  - Variances derive from straight subtraction (Pulled − Received, Sales − Received), mirroring spreadsheet outputs (no tolerance yet enforced).
- **Level-2a (`sql/phase2/020_mart_level2.sql`)**:
  - `Amount Received` reused from the pivot.
  - Paid buckets from `core.v_flows_pivot` appear separately and feed the all-in distributed total.
  - Expected buckets from `core.mv_repmt_sku` (joined via `ref.sku`) provide baselines.
  - Outstanding columns subtract paid from expected per bucket.
  - Transfer columns append the aggregated results of `core.v_inter_sku_transfers_agg`.
- **Level-2b (`sql/phase2/020_mart_level2.sql`)**:
  - One row per SKU compares UI paid amounts (`core.mv_repmt_sku` / `core.mv_repmt_sales`) with cashflow-derived values from `core.v_flows_pivot`.
  - Variance columns expose `UI − CF` deltas for each fee/interest/principal bucket, plus total fund inflow vs amount received.
  - `FH Platform Fee (CF)` is currently a placeholder (0) until remark mappings cover the relevant VA transactions.

## 4. Notable Behaviour
- **Dependency on mappings**: All mart views rely on `ref.note_sku_va_map` and `ref.merchant` records. `scripts/load_note_sku_va_map.sh` ingests the mapping CSV before transforms run.
- **Categorisation coverage**: Only categories present in `ref.remarks_category_map` contribute to Level-2 paid buckets. New mappings (e.g., `senior-investor-principal`, `junior-investor-interest`) were added via `sql/phase2/023_update_remarks_map.sql`; any unmapped remark lands in `uncategorized` and will skew variances until addressed.
- **Temporal context**: `period_ym` is stored in every core MV but the mart views aggregate across all periods. Time slicing must be applied via external `WHERE period_ym = ...` filters or by creating derived views.
- **Tolerance enforcement**: No SQL enforces variance thresholds; large negative variances (e.g., `-482.35`) currently pass through unflagged.
