# Test Coverage Gaps

## Existing Coverage
- `scripts/run_test_suite.sh`: Sequential smoke that runs bootstrap SQL, refreshes core/mart views, and prints Level-1/Level-2 snapshots. It now asserts CSV headers, mapping coverage, mart row-count parity, Level‑1 totals parity, and Level‑1 spreadsheet parity up front (variance tolerance still fails pending business alignment).
- `scripts/run_outflow_demo.sh`: Inserts canned outflow transactions and prints Level-2 results—useful for visual verification only.
- `scripts/sql-tests/*.sql`: Individual query snippets (counts, level1/level2 previews, category audits, mappings check) intended for manual inspection.

## Missing Tests
1. **Parity Assertions**
   - Level-1 spreadsheet parity is automated; Level‑2a/2b parity checks still need to be implemented.
   - Missing epsilon-based equality checks for floating point variances.
2. **Variance Thresholds**
   - No guardrails ensuring `Variance Pulled vs Received` or `Outstanding` columns stay within acceptable bounds (e.g., > -4.0).
3. **Mapping Completeness**
   - No test verifying every SKU present in `core.mv_repmt_sku` / `core.mv_repmt_sales` has a corresponding `ref.note_sku_va_map` entry.
4. **Categorisation Coverage**
   - No regression test to ensure every categorised remark funnels into exactly one waterfall bucket (preventing `uncategorized` leakage).
5. **Idempotency**
   - Loaders and refresh scripts are not exercised twice in succession to confirm stable row counts and absence of duplicate inserts.
6. **Inter-SKU Transfer Logic**
   - Lacks focused tests confirming both halves of a transfer (send/receive) are captured and that net zero is maintained across SKUs.
7. **Temporal Filters**
   - No test ensures period filters behave as expected (e.g., Level-1 for `2025-09` matches spreadsheet tab for the same period).

## Recommended Additions
- Bash + SQL assertion scripts that `RAISE EXCEPTION` when tolerances are exceeded.
- Lightweight Python (via `uvx`) harness for CSV parity comparisons, only if Bash/psql cannot express the checks cleanly.
- Golden dataset tests for remark categorisation to prevent regressions when expanding `ref.remarks_category_map`.
