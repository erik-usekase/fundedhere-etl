# Testing Guide

This project ships a set of repeatable checks that keep the Postgres reproduction aligned with the reconciliation workbook. Every check runs locally (no external services) so the pipeline can be validated before finance provides updated data.

## 1. Primary Entry Point
Run the full harness after each load:

```bash
bash scripts/run_test_suite.sh
```

The script executes the steps below in order. Any failure stops the run so the issue can be addressed immediately.

## 2. Stage-by-Stage Checks
1. **CSV header validation** (`tests/test_csv_headers.sh`)
   - Confirms the prepped CSVs use the canonical column shapes expected by the loaders.
2. **Mapping coverage** (`scripts/sql-tests/check_mapping_coverage.sql`)
   - Verifies every SKU in `core.mv_repmt_sales` is mapped in `ref.note_sku_va_map`.
3. **Mart row-count parity** (`scripts/sql-tests/check_mart_row_counts.sql`)
   - Confirms Level‑1, Level‑2a, and Level‑2b each return the same SKU count as the raw sales feed.
4. **Level‑1 totals parity** (`scripts/sql-tests/check_level1_totals.sql`)
   - Ensures amounts pulled/received/sales in `mart.v_level1` match the source tables (after applying the SKU↔VA mapping).
5. **Level‑1 reference parity** (`tests/test_level1_parity.py`)
   - Reads the “Formula & Output” CSV export and diff-checks it against `mart.v_level1` within a 0.01 tolerance.
6. **Variance tolerance (warning by default)** (`scripts/sql-tests/check_level1_variance_tolerance.sql`)
   - Flags SKUs whose Pulled vs Received variances exceed the business-defined thresholds. The suite downgrades this to a warning until Finance signs off on policy; set `FAIL_ON_LEVEL1_VARIANCE=1` in `.env` to reinstate a hard failure.

## 3. Running Checks Individually
Each stage can be executed on its own; for example:

```bash
make sqlf FILE=scripts/sql-tests/check_mapping_coverage.sql
python3 tests/test_level1_parity.py
```

This is useful during development when investigating a single failure.

## 4. Fixture Strategy (Upcoming)
We plan to add:
- **Golden fixtures** drawn from the live sample, with expected Level‑1/Level‑2 outputs stored under `tests/fixtures/`.
- **Synthetic scenarios** (e.g., transfer-only SKUs, missing mappings) to stress-test edge cases.
- A `make test-fixtures` target that loads each fixture into a sandbox schema, runs the ETL, and uses the same parity scripts to diff against expectations.

Once finance provides updated exports, these fixtures will let us update expectations and rerun the suite without manual CSV comparisons.

## 5. When Tests Fail
- **Header or mapping failures** usually mean the input CSVs have new columns or the mapping file is stale.
- **Row-count parity** indicates mart views were not refreshed or a mapping is missing.
- **Totals/reference parity** highlight true data mismatches—re-run `make refresh` and re-check the source CSVs.
- **Variance tolerance** remains a known gap until the business defines acceptable ranges.

Keep this guide updated as new tests or fixtures are introduced.
