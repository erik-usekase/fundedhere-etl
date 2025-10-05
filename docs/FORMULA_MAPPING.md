# Spreadsheet → SQL Formula Mapping

## Level 1 Reconciliation
| Spreadsheet Metric | Likely Sheet Formula (conceptual) | SQL Implementation | Notes |
|--------------------|-----------------------------------|--------------------|-------|
| Amount Pulled | `=SUMIFS(Bank!$D:$D,Bank!$B:$B,SKU_VA)` | `SUM(e.buy_amount)` from `core.mv_external_accounts` joined to `ref.note_sku_va_map` on `va_number` (`sql/phase2/010_mart_level1.sql`) | Uses `core.to_numeric_safe` to normalize text currency values. |
| Amount Received | `=SUMIFS(VA!Amount, VA!Category, "Merchant Repayment", VA!SKU, SKU_ID)` | `SUM(CASE WHEN direction='inflow' AND category_code = 'merchant_repayment' THEN signed_amount END)` sourced from `core.mv_va_txn_flows` (`010_mart_level1.sql`) | Aligns with Excel, which excludes internal top-ups (`funds_to_sku`) from cash receipts. |
| Sales Proceeds | `=SUMIFS(Sales!$H:$H, Sales!$B:$B, SKU_ID)` | `SUM(s.sales_proceeds)` from `core.mv_repmt_sales` (`010_mart_level1.sql`) | Sales table already keyed by SKU. |
| Variance Pulled vs Received | `=Amount Pulled - Amount Received` | `COALESCE(p.amount_pulled,0) - COALESCE(r.amount_received,0)` | No tolerance applied; negative numbers indicate receipts lagging pulls. |
| Variance Received vs Sales | `=Sales Proceeds - Amount Received` | `COALESCE(s.sales_proceeds,0) - COALESCE(r.amount_received,0)` | Should align with spreadsheet variance column. |

## Level 2 Reconciliation (Waterfall)
| Spreadsheet Metric | Likely Sheet Formula | SQL Implementation | Notes |
|--------------------|----------------------|--------------------|-------|
| Amount Received | `=Reference(Level1!Amount Received)` | `COALESCE(j.amount_received,0)` inherited from `core.v_flows_pivot` (`sql/phase2/020_mart_level2.sql`) | Should match Level-1 value once period filters match. |
| Management/Admin/Interest/Principal Paid | `=SUMIFS(VA!Amount, VA!Category, <bucket>, VA!SKU, SKU_ID)` | Aggregates in `core.v_flows_pivot` (`022_update_flows_pivot.sql`) for each category, exposed as paid columns in `mart.v_level2a`. | Outflows recorded as negative signed amounts; SQL flips sign. |
| SPAR Paid | `=SUMIFS(VA!Amount, VA!Category, "SPAR", VA!SKU, SKU_ID)` | `SUM(CASE WHEN category_code='spar' AND direction='outflow' THEN -signed_amount END)` | |
| Amount Distributed Down the Repayment Waterfall | `=SUM(Paid Buckets)` | Sum of paid columns in `mart.v_level2a`. | Mirrors spreadsheet total distribution. |
| Expected Buckets | `=SUMIFS(Expectations!value, Expectations!SKU, SKU_ID)` | Aggregates from `core.mv_repmt_sku`, renamed to expected columns (`020_mart_level2.sql`). | `acquirer_fees_expected` repurposed as management fee. |
| Outstanding Buckets | `=Expected - Paid` | `COALESCE(expected,0) - COALESCE(paid,0)` per column. | No epsilon tolerance; spreadsheet may wrap with `IF(ABS(diff)<0.01,0,diff)`. |
| Transfers (to/from other SKU) | `=SUMIFS(VA!Amount, SenderSKU, CurrentSKU, ReceiverSKU, <>CurrentSKU)` / `SUMIFS` inverse | `core.v_inter_sku_transfers_agg` synthesizes outflow/inflow totals and joins into `mart.v_level2a`. | Spreadsheet often tracks these separately; SQL replicates via view. |

## Gaps & Divergences
- **Tolerance Handling**: Spreadsheet typically rounds or zeroes variances within a tolerance (e.g., `ABS(diff)<0.01`). SQL views return raw differences without rounding.
- **Time Slice Filters**: Workbook tabs usually filter to a specific month; SQL views aggregate across all `period_ym` unless a `WHERE` clause is applied externally.
- **Mapping Coverage**: Spreadsheet lookups often default to manual overrides when SKU/VAs are missing. SQL depends solely on `ref.note_sku_va_map`; unmapped rows drop out entirely.
- **Categorisation Fallback**: Excel may treat unknown remarks as “Other” but still include them in inflow totals. SQL classifies them as `uncategorized` and excludes them from paid buckets and receipts.
