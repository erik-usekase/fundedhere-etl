# CSV → SQL Formula Mapping

## Level 1 Reconciliation
| CSV Metric | Conceptual Expression | SQL Implementation | Notes |
|--------------------|-----------------------------------|--------------------|-------|
| Amount Pulled | Sum by VA number in bank pull export | `SUM(e.buy_amount)` from `core.mv_external_accounts` joined to `ref.note_sku_va_map` on `va_number` (`sql/phase2/010_mart_level1.sql`) | Uses `core.to_numeric_safe` to normalize text currency values. |
| Amount Received | Sum of merchant repayment inflows per SKU in VA ledger export | `SUM(CASE WHEN direction='inflow' AND category_code = 'merchant_repayment' THEN signed_amount END)` sourced from `core.mv_va_txn_flows` (`010_mart_level1.sql`) | Excludes internal top-ups (`funds_to_sku`) from cash receipts. |
| Sales Proceeds | Sum of sales proceeds per SKU in repayment sales export | `SUM(s.sales_proceeds)` from `core.mv_repmt_sales` (`010_mart_level1.sql`) | Sales table already keyed by SKU. |
| Variance Pulled vs Received | `=Amount Pulled - Amount Received` | `COALESCE(p.amount_pulled,0) - COALESCE(r.amount_received,0)` | No tolerance applied; negative numbers indicate receipts lagging pulls. |
| Variance Received vs Sales | `=Sales Proceeds - Amount Received` | `COALESCE(s.sales_proceeds,0) - COALESCE(r.amount_received,0)` | Mirrors the variance column in the reference export. |

## Level 2 Reconciliation (Waterfall)
| CSV Metric | Conceptual Expression | SQL Implementation | Notes |
|--------------------|----------------------|--------------------|-------|
| Amount Received | Level 1 amount received reused in waterfall output | `COALESCE(j.amount_received,0)` inherited from `core.v_flows_pivot` (`sql/phase2/020_mart_level2.sql`) | Should match Level-1 value once period filters match. |
| Management/Admin/Interest/Principal Paid | Sum of ledger outflows tagged by category | Aggregates in `core.v_flows_pivot` (`022_update_flows_pivot.sql`) for each category, exposed as paid columns in `mart.v_level2a`. | Outflows recorded as negative signed amounts; SQL flips sign. |
| SPAR Paid | Sum of ledger outflows tagged `spar` | `SUM(CASE WHEN category_code='spar' AND direction='outflow' THEN -signed_amount END)` | |
| Amount Distributed Down the Repayment Waterfall | Sum of paid buckets | Sum of paid columns in `mart.v_level2a`. | Mirrors waterfall total distribution. |
| Expected Buckets | Sum of expectation export values per SKU | Aggregates from `core.mv_repmt_sku`, renamed to expected columns (`020_mart_level2.sql`). | `acquirer_fees_expected` repurposed as management fee. |
| Outstanding Buckets | Expected minus paid per bucket | `COALESCE(expected,0) - COALESCE(paid,0)` per column. | No epsilon tolerance applied. |
| Transfers (to/from other SKU) | Totals for ledger movements between SKUs | `core.v_inter_sku_transfers_agg` synthesizes outflow/inflow totals and joins into `mart.v_level2a`. | CSV extracts do not track these explicitly, so SQL derives them from VA ledger.

## Level 2B (UI vs VA)
| CSV Metric | Conceptual Expression | SQL Implementation | Notes |
|--------------------|----------------------|--------------------|-------|
| Variance columns | UI value minus cashflow value for each bucket | Difference columns emitted in `mart.v_level2b`; e.g., `total_fund_inflow_ui - amount_received_cf`. | Highlights deltas between UI extracts and VA cashflows. |
| Management/Admin/Interest/Principal Paid (UI) | Paid amounts from repayment expectations export | Aggregated from `core.mv_repmt_sku` (`mart.v_level2b`). | Columns ending in `(UI)`. |
| Management/Admin/Interest/Principal Paid (CF) | Paid amounts from VA ledger categories | Aggregated from `core.v_flows_pivot` (`mart.v_level2b`). | Columns ending in `(CF)`. |
| SPAR / FH Platform Fee | UI sourced from `core.mv_repmt_sku` (`spar_merchant`, `additional_interests_paid_to_fh`); CF sourced from `core.v_flows_pivot.spar_paid` (platform currently placeholder 0). | Pending finer remark mappings for platform fees. |
| Total Fund Inflow (UI) | `total_funds_inflow` per SKU from sales export | `SUM(total_funds_inflow)` from `core.mv_repmt_sales`. | |
| Amount Received (CF) | Level 1 amount received reused here | `amount_received` from `core.v_flows_pivot`. | |

## Gaps & Divergences
- **Tolerance Handling**: Reference CSVs often round or zero variances within a tolerance (e.g., `ABS(diff)<0.01`). SQL views return raw differences without rounding.
- **Time Slice Filters**: Source exports are month-specific, while SQL views aggregate across all `period_ym` unless a `WHERE` clause is applied externally.
- **Mapping Coverage**: Reference exports can include hand-curated overrides when SKU/VAs are missing. SQL depends solely on `ref.note_sku_va_map`; unmapped rows drop out entirely.
- **Categorisation Fallback**: Legacy workflows may treat unknown remarks as “Other” but still include them in inflow totals. SQL classifies them as `uncategorized` and excludes them from paid buckets and receipts.
