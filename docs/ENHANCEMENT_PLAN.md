# Enhancement Plan (Do Not Implement Yet)

## Orchestration & Idempotency
- Add a Make/Bash target (e.g., `make etl-all`) that chains `prep-all`, `load-all-fresh`, ref bootstrap SQL, `load-mapping`, and `refresh` with logging/row-count echoes. Keep it pure Bash + SQL; only wrap with Python if argument parsing becomes complex.
- Extend `scripts/prep_all.sh` to accept a period argument (defaulting to latest) instead of hard-coded `2025-09` filenames, and emit the derived source→output map for observability.
- Capture source filenames during load by passing `source_file` via `COPY ... WITH (FORMAT csv, HEADER)` using `
` sequences or `psql` variables so raw tables retain provenance.

## Data Transformations
- Enrich `core.mv_va_txn_flows` with unmapped VA diagnostics (e.g., companion view listing remarks/amounts missing from `ref.note_sku_va_map`) to tighten reconciliation coverage.
- Introduce a deterministic period filter parameter (or view) for Level-1/Level-2 to support time-sliced exports instead of aggregating all history.
- Consider a supplemental `core.v_flows_pivot_deltas` view that compares expected vs paid side-by-side to simplify downstream parity checks.

## Testing & Validation
- Author SQL-based assertions in `scripts/sql-tests` (e.g., raise exception when variance magnitudes exceed tolerance) and surface them via `run_test_suite.sh`.
- Build parity fixtures (CSV vs SQL results) and automate comparison using Bash+psql+`diff`; reserve Python (via `uvx`) only if CSV comparison requires richer tooling.
- Add an idempotency smoke script that reruns `make load-all` and ensures `raw.*` row counts remain stable (e.g., compare `pg_stat_all_tables.n_live_tup`).

## Reference Data & Coverage
- Formalize a mapping ingest for `ref.note_sku_va_map` (CSV or SQL) so all 99 SKUs gain coverage; document fallback behavior for unmatched SKUs.
- Expand `ref.remarks_category_map` seed data with regex priority guidance and add a check that every `category_code` is referenced by the waterfall logic.

## Observability
- Emit row-count notices within the SQL refresh scripts (`RAISE NOTICE`) and capture them in Make target output for troubleshooting.
- Log timing metrics per stage in Bash orchestrators (`SECONDS` variable) to highlight performance hotspots.

## Integrations
- Package a minimal Power Automate connector recipe: stand up the on-premises data gateway, register a read-only PostgreSQL connection (localhost:5433), and reuse the `make` variance queries in a templated flow. The aim is to give non-technical users a chat/alert surface without additional infrastructure—just SQL → AI summary via the existing mart views.
