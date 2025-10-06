# Data Quality Findings (September 2025 Sample)

## Coverage & Completeness
- `ref.note_sku_va_map` contains all 366 SKU↔VA pairs supplied in the mapping CSV. Any new SKU introduced in future periods must extend this file before the marts are refreshed.
- Three virtual-account ledger rows arrive without a `receiver_virtual_account_number`. They currently fall outside Level 1 inflow totals because they cannot join to the mapping; investigate whether these rows should be attributed manually.

## Variance Outliers
- `mart.v_level1` shows `Variance Pulled vs Received` as high as **65.20** and `Variance Received vs Sales` as low as **-120.62**. These differences mirror the gaps in the reference exports and drive the variance tolerance warning in the test suite.
- Level 2 outstanding columns inherit the same raw differences. Without tolerances or business rules, minor rounding noise and large mismatches remain indistinguishable.

## Categorisation Gaps
- `core.mv_va_txn_flows` still surfaces **724** rows with a blank remark plus several thousand transactions mapped to generic categories such as `transfer-to-another-sku` or `loan-disbursement`. These categories do not feed the Level 2 waterfall buckets and should be reviewed with Finance.
- `FH Platform Fee (CF)` remains a placeholder zero in `mart.v_level2b` because no VA ledger remarks have been mapped to that bucket yet.

## Temporal Controls
- `scripts/prep_all.sh` assumes the `*_2025-09.csv` naming convention. Loading another period currently requires manual filename overrides.
- All mart views aggregate across every loaded `period_ym`. Analysts must filter on `period_ym` when they expect month-specific answers.

## Provenance & Lineage
- Raw loaders omit the optional `source_file` column, so individual rows lack provenance. Capturing filenames during COPY would make audits simpler.
- No row-level checksum exists to detect if a CSV is reloaded twice. Downstream processes rely on operators to avoid duplicate ingest.

Addressing these items will help the CSV pipeline stay aligned with business reality as new periods or merchants are introduced.
