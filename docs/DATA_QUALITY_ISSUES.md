# Data Quality Findings

## Coverage Gaps
- Only one SKU/VA pair exists in `ref.note_sku_va_map` (seeded via `t10/t20` demo scripts), leaving 98 SKUs from `core.mv_repmt_sku` and `core.mv_repmt_sales` unmapped. These SKUs never appear in Level-1/Level-2 outputs, obscuring reconciliation gaps.
- Three rows in `raw.va_txn` lack a `receiver_virtual_account_number`, preventing them from joining to `ref.note_sku_va_map` and therefore from contributing to inflow totals (`scripts/run_sql.sh` query revealed `missing_receiver_va = 3`).

## Variance Outliers
- `mart.v_level1` currently surfaces `Variance Pulled vs Received = -482.35` and `Variance Received vs Sales = -153.23`, violating the desired threshold band (greater than `-4.0`, up to `0.0x`, and at most `-2.05`). No logic exists to flag or adjust these variances.
- Level-2 outstanding columns mirror the same raw differences; without tolerances, minor rounding noise and major gaps are indistinguishable.

## Temporal Constraints
- `scripts/prep_all.sh` hard-codes the `2025-09` filenames; attempting to process other periods requires manual edits, risking accidental cross-period mixing.
- `period_ym` columns exist in core MVs but mart views aggregate across all periods, making it easy to combine multiple months inadvertently.

## Provenance & Metadata
- Raw loaders do not populate the `source_file` column, leaving no trace of which CSV (or run) produced a given row.
- No checksum/hash is recorded per load; duplicate loads of the same file will reinsert data without detection.

## Suggested Remediations (Non-Implemented)
- Require complete SKU/VA mapping before releasing reconciliation outputs (or surface missing mappings in a companion report).
- Enforce variance tolerance checks during refresh to catch out-of-band results early.
- Parameterize prep/load scripts by period and capture source filenames to maintain lineage.
