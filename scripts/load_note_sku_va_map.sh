#!/usr/bin/env bash
set -euo pipefail

CSV_PATH="${1:-./data/inc_data/note_sku_va_map_prepped.csv}"
if [ ! -f "$CSV_PATH" ]; then
  echo "Mapping CSV not found: $CSV_PATH" >&2
  exit 2
fi

if [ "$(wc -l < "$CSV_PATH")" -le 1 ]; then
  echo "Mapping CSV has no data rows (header only). Skipping load." >&2
  exit 0
fi

# Ensure merchants and SKUs exist before loading
scripts/run_sql.sh -f scripts/sql-utils/upsert_merchants_from_sales.sql
scripts/run_sql.sh -f scripts/sql-utils/upsert_skus_from_sales.sql

# Load mappings from CSV into ref.note_sku_va_map
tmp_sql=$(mktemp)
trap 'rm -f "$tmp_sql"' EXIT
sed "s|__CSV_PATH__|$CSV_PATH|g" scripts/sql-utils/load_note_sku_va_map.sql > "$tmp_sql"
scripts/run_sql.sh -f "$tmp_sql"

# Report coverage
scripts/run_sql.sh -c "SELECT COUNT(DISTINCT sku_id) AS mapped_skus FROM ref.note_sku_va_map;"
