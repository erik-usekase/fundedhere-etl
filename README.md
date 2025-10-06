# FundedHere Reconciliation ETL

A production-focused pipeline that converts FundedHere’s reconciliation workbook into a trustworthy Postgres data product. The goal is simple: ingest the four monthly extracts, preserve the spreadsheet’s business logic, and expose the Level‑1/Level‑2 views (and their tests) as fast, queryable database objects.

## Product Outcomes
- **Spreadsheet parity**: `mart.v_level1`, `mart.v_level2a`, and the new `mart.v_level2b` replicate the Excel “Formula & Output” tabs (Level‑1 parity is fully automated; Level‑2 parity tests are next).
- **Explorable data model**: inputs land in `raw.*`, mappings live in `ref.*`, typed transforms sit in `core.*`, and business consumers query `mart.*`.
- **Automated verification**: header validation, SKU coverage, row-count parity, totals parity, and Level‑1 spreadsheet parity run in `scripts/run_test_suite.sh`.
- **Agent-ready**: every row carries `merchant`, `sku_id`, and `period_ym` so downstream automation can request time slices without reprocessing the workbook.

Further reading:
- [Architecture & workflow](docs/EXISTING_ANALYSIS.md)
- [Reconciliation logic](docs/RECONCILIATION_ANALYSIS.md)
- [Spreadsheet ↔ SQL mapping](docs/FORMULA_MAPPING.md)
- [Validation log](docs/VALIDATION_RESULTS.md)
- [Outstanding test gaps](docs/TEST_GAPS.md)
- [Testing guide](docs/TESTING.md)
- [Agent hand-off log](docs/AGENT_HANDOFF.md)

## Data Sources (CSV extracts)
1. **External Accounts (Merchant)** → `raw.external_accounts`
2. **VA Transaction Report (All)** → `raw.va_txn`
3. **Repmt-SKU (by Note)** → `raw.repmt_sku`
4. **Repmt-Sales Proceeds (by Note)** → `raw.repmt_sales`

Mappings required by the spreadsheet live in version control:
- `ref.note_sku_va_map` — SKU/VA alignment (generated from the Level‑1 sheet).
- `ref.remarks_category_map` — remark → waterfall category (admin fees, sr/jr principal, SPAR, etc.).

Architecture and lineage details: see `docs/EXISTING_ANALYSIS.md` and `docs/RECONCILIATION_ANALYSIS.md`.

## Workflow Overview
1. **Prepare inputs**
   - Drop the four exports into `data/inc_data/` (`Sample Files(…)` or `*_2025-09.csv`).
   - Run `make prep-all` to normalise headers/values into `*_prepped.csv` (CSV normalization helpers live in `scripts/prep_*.py`).
2. **Load raw tables**
   - Run `make load-all-fresh` to truncate `raw.*` and COPY the prepped CSVs.
   - Run `make load-mapping` to upsert the SKU↔VA map from `note_sku_va_map_prepped.csv` (auto-creates merchants/SKUs as needed).
3. **Materialise transforms**
   - Run `make refresh` (or `scripts/sql-tests/refresh.sql`) to rebuild `core.*` materialised views and `mart.*` views.
4. **Verify parity**
   - Run `bash scripts/run_test_suite.sh`; it checks CSV headers, mapping coverage, mart row counts, Level‑1 totals, Level‑1 spreadsheet parity, and finally variance tolerances. All steps except the last must pass before data is considered publishable.


Need more detail? See [architecture](docs/EXISTING_ANALYSIS.md), [reconciliation analysis](docs/RECONCILIATION_ANALYSIS.md), and the [formula mapping](docs/FORMULA_MAPPING.md) for field-by-field logic.

## Quality Gates
Run the full suite after each data load:
```bash
bash scripts/run_test_suite.sh
```
The harness executes:
1. CSV header validation (`tests/test_csv_headers.sh`)
2. Mapping coverage (`scripts/sql-tests/check_mapping_coverage.sql`)
3. Mart row-count parity (`scripts/sql-tests/check_mart_row_counts.sql`)
4. Level‑1 totals parity (`scripts/sql-tests/check_level1_totals.sql`)
5. Level‑1 spreadsheet parity (`tests/test_level1_parity.py`)
6. Variance tolerance check (`scripts/sql-tests/check_level1_variance_tolerance.sql`) — currently logged as a warning until finance defines acceptable deltas. Set `FAIL_ON_LEVEL1_VARIANCE=1` in `.env` to make the suite fail on this step.

Full details on each check (and upcoming fixture work) live in the [Testing Guide](docs/TESTING.md).

## Current Status
- All 366 SKUs from the September 2025 sample are present in `mart.v_level1`/`mart.v_level2a` with totals matching the spreadsheet.
- `mart.v_level2b` surfaces UI vs cashflow variances per fee/principal bucket; `FH Platform Fee (CF)` is currently a placeholder until the relevant VA mappings are defined.
- Level‑1 variance guard is intentionally failing to surface unresolved business gaps (see `docs/AGENT_HANDOFF.md` for next steps).
- Level‑2b (UI vs VA) parity work remains outstanding.

### Level‑2 Roadmap
Level‑2a already reproduces the Waterfall tab (paid vs expected, plus transfer diagnostics). To finish parity work and enable automation:
1. **Categorise residual remarks** — ensure every VA outflow remark maps to a waterfall bucket or tolerated “other” category.
2. **Level‑2a parity tests** — add totals and spreadsheet comparisons similar to the Level‑1 harness.
3. **Level‑2b view** — build a mart view that compares UI values (`raw.repmt_sales`, `raw.repmt_sku`) against VA-derived totals and flags mismatches; capture expectations in `docs/FORMULA_MAPPING.md` before coding.
4. **Automation hooks** — extend `scripts/run_test_suite.sh` with parity checks for Level‑2a/2b once the SQL is in place.

## What’s Next
1. Align variance tolerances with finance and update `scripts/sql-tests/check_level1_variance_tolerance.sql` once the policy is set.
2. Extend parity automation to Level‑2/Level‑2b outputs.
3. Package an `etl-all` target for idempotent end-to-end runs (prep → load → mapping → refresh → tests).
4. Harden mappings and remark categories as new merchants/periods are onboarded.
5. Build golden fixtures and synthetic scenarios (see below) so the pipeline can be tested without fresh finance input:
   - Curate representative SKUs from the live sample and store the expected Level‑1/Level‑2 outputs alongside their raw source slices.
   - Generate synthetic CSVs for edge cases (only repayments, heavy transfers, duplicate inflows, missing mappings) with paired expected outputs.
   - Add a `make test-fixtures` target that loads each fixture into a sandbox schema, runs the ETL, and diff-checks the results using the parity scripts.

For a daily operations hand-off, refer to `docs/AGENT_HANDOFF.md`.
