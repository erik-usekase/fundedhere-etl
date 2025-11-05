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
| Amount Received | Sum of merchant-repayment transactions only | `SUM(CASE WHEN v.remarks = 'merchant-repayment' THEN amount END)` from `raw.va_txn` where `receiver_virtual_account_id = SKU` (`sql/phase2/020_mart_level2.sql`) | **Different from Level 1**: Uses direct SKU matching, merchant-repayment ONLY (not all inflows). Original test requirements confirmed this is the correct formula. |
| Management/Admin/Interest/Principal Paid | Sum of ledger outflows tagged by category | Aggregates in `core.v_flows_pivot` (`022_update_flows_pivot.sql`) for each category, exposed as paid columns in `mart.v_level2a`. | Outflows recorded as negative signed amounts; SQL flips sign. |
| SPAR Paid | Sum of ledger outflows tagged `spar` | `SUM(CASE WHEN category_code='spar' AND direction='outflow' THEN -signed_amount END)` | |
| Amount Distributed Down the Repayment Waterfall | Sum of paid buckets | Sum of paid columns in `mart.v_level2a`. | Mirrors waterfall total distribution. |
| Expected Buckets | Sum of expectation export values per SKU | Aggregates from `core.mv_repmt_sku`, renamed to expected columns (`020_mart_level2.sql`). | `acquirer_fees_expected` repurposed as management fee. |
| Outstanding Buckets | Expected minus paid per bucket | `COALESCE(expected,0) - COALESCE(paid,0)` per column. | No epsilon tolerance applied. |
| Transfers (to/from other SKU) | Totals for ledger movements between SKUs | `core.v_inter_sku_transfers_agg` synthesizes outflow/inflow totals and joins into `mart.v_level2a`. | CSV extracts do not track these explicitly, so SQL derives them from VA ledger.

## Level 2B (Actual Transaction Values)
| CSV Metric | Conceptual Expression | SQL Implementation | Notes |
|--------------------|----------------------|--------------------|-------|
| Total Fund Inflow | Same as Sheet 2a Amount Received | `SUM(CASE WHEN v.remarks = 'merchant-repayment' THEN amount END)` | Shows actual merchant-repayment inflows. **Note**: Original test files show actual values, not variances. |
| Management Fee Paid | Sum of acquirer-fee transactions | `SUM(CASE WHEN v.remarks = 'acquirer-fee' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| Administrative Fee Paid | Sum of fh-admin-fee transactions | `SUM(CASE WHEN v.remarks = 'fh-admin-fee' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| Interest Difference Paid | Sum of int-diff transactions | `SUM(CASE WHEN v.remarks = 'int-diff' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| Senior Principal Paid | Sum of senior-investor-principal transactions | `SUM(CASE WHEN v.remarks = 'senior-investor-principal' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| Senior Interest Paid | Sum of senior-investor-interest transactions | `SUM(CASE WHEN v.remarks = 'senior-investor-interest' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| Junior Principal Paid | Sum of junior-investor-principal transactions | `SUM(CASE WHEN v.remarks = 'junior-investor-principal' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| Junior Interest Paid | Sum of junior-investor-interest transactions | `SUM(CASE WHEN v.remarks = 'junior-investor-interest' THEN amount END)` | Shows actual paid amounts from VA transactions. |
| SPAR | Sum of Disbursement Transaction Fee + Cross-Note transfers | `SUM(CASE WHEN v.remarks IN ('Disbursement Transaction Fee', 'Transfer-to-another-sku (Cross Note) Same Merchant') THEN amount END)` | Shows actual SPAR payments from VA transactions. |
| FH Platform Fee | Placeholder | `0.00` | Pending finer remark mappings for platform fees. |

## Gaps & Divergences
- **⚠️ Formula Documentation Mismatch**: The `.txt` files in `pre_csv/` (1.txt, 2a.txt, 2b.txt) contain NEWER Excel formulas that DO NOT match the original test requirements. For Sheet 2a, the .txt documentation shows Amount Received excluding only 'note-issued-transfer-to-sku', but the actual implementation (validated against original test files) uses ONLY 'merchant-repayment' transactions. **Always validate against original test output files in `pre_csv/` comparison workbooks, not the .txt documentation.** See `pre_csv/README.md` for details.
- **Sheet 2b Structure Difference**: Original test files show Sheet 2b contains actual transaction values (Total Fund Inflow, Management Fee Paid, etc.), not variance calculations (UI - CF). The SQL implementation matches this actual values model.
- **Tolerance Handling**: Reference CSVs often round or zero variances within a tolerance (e.g., `ABS(diff)<0.01`). SQL views return raw differences without rounding.
- **Time Slice Filters**: Source exports are month-specific, while SQL views aggregate across all `period_ym` unless a `WHERE` clause is applied externally.
- **Mapping Coverage**: Reference exports can include hand-curated overrides when SKU/VAs are missing. SQL depends solely on `ref.note_sku_va_map`; unmapped rows drop out entirely.
- **Categorisation Fallback**: Legacy workflows may treat unknown remarks as "Other" but still include them in inflow totals. SQL classifies them as `uncategorized` and excludes them from paid buckets and receipts.
