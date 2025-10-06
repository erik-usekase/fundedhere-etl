#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_DIR_INIT="${ROOT_DIR}/initdb"
SQL_DIR_PHASE2="${ROOT_DIR}/sql/phase2"

declare -a INIT_FILES=(
  "${SQL_DIR_INIT}/000_schemas.sql"
  "${SQL_DIR_INIT}/010_extensions.sql"
  "${SQL_DIR_INIT}/020_security.sql"
  "${SQL_DIR_INIT}/100_raw_tables.sql"
  "${SQL_DIR_INIT}/200_ref_tables.sql"
)

declare -a PHASE2_FILES=(
  "${SQL_DIR_PHASE2}/001_core_types.sql"
  "${SQL_DIR_PHASE2}/002_core_basic_mviews.sql"
  "${SQL_DIR_PHASE2}/003_core_mviews_flows.sql"
  "${SQL_DIR_PHASE2}/004_core_inter_sku_transfers.sql"
  "${SQL_DIR_PHASE2}/010_mart_views.sql"
  "${SQL_DIR_PHASE2}/020_mart_level2.sql"
  "${SQL_DIR_PHASE2}/021_category_funds_to_sku.sql"
  "${SQL_DIR_PHASE2}/022_update_flows_pivot.sql"
  "${SQL_DIR_PHASE2}/023_update_remarks_map.sql"
)

run_sql_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Skipping missing SQL file: $file" >&2
    return
  fi
  echo "Executing: $file"
  scripts/run_sql.sh -f "$file"
}

echo "Bootstrapping schemas and core views"
for sql_file in "${INIT_FILES[@]}"; do
  run_sql_file "$sql_file"
done

for sql_file in "${PHASE2_FILES[@]}"; do
  run_sql_file "$sql_file"
done

echo "Bootstrap complete"
