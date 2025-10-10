#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${SKIP_ENV_FILE:-}" ] && [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$PROJECT_ROOT/.env"
  set +a
fi

FAIL_ON_LEVEL1_VARIANCE="${FAIL_ON_LEVEL1_VARIANCE:-0}"
SHOW_PREVIEW="${SHOW_PREVIEW:-0}"

cd "$PROJECT_ROOT"

# Default connection info (overridden when running inside container wrapper)
export PGHOST="postgres"
export PGPORT="5432"
export PGDATABASE="appdb"
export PGUSER="appuser"
export PGPASSWORD="${PGPASSWORD:-changeme}"
export PGSSLMODE="disable"

step() { echo -e "\n\033[1;34m== $* ==\033[0m"; }

failures=()
warnings=()
migrations_applied=0

ensure_bootstrapped() {
  local count
  count=$(scripts/run_sql.sh -c "select count(*) from information_schema.tables where table_schema='raw';" | tail -n +3 | head -n 1 | tr -d ' ') || count="0"
  if [ "$count" = "0" ]; then
    echo "No raw tables detected; running full bootstrap (initdb + refresh)" >&2
    migrations_applied=1
    scripts/bootstrap_db.sh
    scripts/run_sql.sh -f scripts/sql-tests/refresh.sql
  fi
}

validate_raw_data() {
  local totals
  totals=$(scripts/run_sql.sh -c "select sum(cnt) from (select count(*) as cnt from raw.external_accounts union all select count(*) from raw.va_txn union all select count(*) from raw.repmt_sku union all select count(*) from raw.repmt_sales) t;" | tail -n +3 | head -n 1 | tr -d ' ')
  if [ "${totals:-0}" = "0" ]; then
    cat <<'MSG'
No rows found in raw tables.
  • Drop the monthly CSV exports into data/inc_data/ (or set EXTERNAL_ACCOUNTS_SRC, VA_TXN_SRC, REPMT_SKU_SRC, REPMT_SALES_SRC).
  • Re-run make container-etl-verify to load data and rebuild marts.
MSG
    return 1
  fi
  return 0
}

run_step() {
  local desc="$1"
  shift
  local severity="fail"
  if [ "$1" = "warn" ] || [ "$1" = "fail" ]; then
    severity="$1"
    shift
  fi
  step "$desc"
  local tmp
  tmp=$(mktemp)
  if "$@" >"$tmp" 2>&1; then
    echo "   PASS"
  else
    if [ "$SHOW_PREVIEW" = "1" ]; then
      cat "$tmp"
    else
      if [ "$severity" = "warn" ]; then
        echo "   WARN (re-run with SHOW_PREVIEW=1 for details)"
      else
        echo "   FAIL (re-run with SHOW_PREVIEW=1 for details)"
      fi
    fi
    if [ "$severity" = "warn" ]; then
      warnings+=("$desc")
    else
      failures+=("$desc")
      rm -f "$tmp"
      return 1
    fi
  fi
  rm -f "$tmp"
  return 0
}

run_step "Validate CSV headers" fail tests/test_csv_headers.sh

echo "\nChecking database bootstrap state..."
ensure_bootstrapped
if ! validate_raw_data; then
  exit 1
fi

run_step "Refresh typed/mart layers" fail scripts/run_sql.sh -f scripts/sql-tests/refresh.sql || true

run_step "Mapping coverage check" warn scripts/run_sql.sh -f scripts/sql-tests/check_mapping_coverage.sql || true

run_step "Mart row count parity" fail scripts/run_sql.sh -f scripts/sql-tests/check_mart_row_counts.sql || true

run_step "Level 1 totals parity" fail scripts/run_sql.sh -f scripts/sql-tests/check_level1_totals.sql || true

step "Level 1 parity vs spreadsheet"
python3 tests/test_level1_parity.py

if [ "$FAIL_ON_LEVEL1_VARIANCE" = "1" ]; then
  run_step "Level 1 variance tolerance" fail scripts/run_sql.sh -f scripts/sql-tests/check_level1_variance_tolerance.sql || true
else
  run_step "Level 1 variance tolerance" warn scripts/run_sql.sh -f scripts/sql-tests/check_level1_variance_tolerance.sql || true
fi

step "Counts BEFORE (may be zero after a clean reset)"
if [ "$SHOW_PREVIEW" = "1" ]; then
  scripts/run_sql.sh -f scripts/sql-utils/counts.sql || true
else
  echo "Preview suppressed (set SHOW_PREVIEW=1 to view counts)."
fi

run_step "Bootstrap merchant" fail scripts/run_sql.sh -f scripts/sql-tests/t10_bootstrap_merchant.sql || true

step "Bootstrap SKU + VA map"
echo "Skipping legacy bootstrap (mapping provided via CSV)."

step "Level 1 preview (if view exists)"
if [ "$SHOW_PREVIEW" = "1" ]; then
  scripts/run_sql.sh -f scripts/sql-tests/level1_count.sql || true
  scripts/run_sql.sh -f scripts/sql-tests/level1_pretty.sql || true
else
  echo "Preview suppressed (set SHOW_PREVIEW=1 to enable sample output)."
fi

step "Flows after Option-B (if installed)"
if [ "$SHOW_PREVIEW" = "1" ]; then
  scripts/run_sql.sh -f scripts/sql-tests/flows_after_option_b.sql || true
else
  echo "Preview suppressed (set SHOW_PREVIEW=1 to enable sample output)."
fi

step "Level 2 preview"
if [ "$SHOW_PREVIEW" = "1" ]; then
  scripts/run_sql.sh -f scripts/sql-tests/level2a_preview.sql || true
else
  echo "Preview suppressed (set SHOW_PREVIEW=1 to enable sample output)."
fi

step "Category audit"
if [ "$SHOW_PREVIEW" = "1" ]; then
  scripts/run_sql.sh -f scripts/sql-tests/category_audit_top50.sql || true
else
  echo "Preview suppressed (set SHOW_PREVIEW=1 to enable sample output)."
fi

echo
if [ ${#failures[@]} -eq 0 ]; then
  if [ "$migrations_applied" = "1" ]; then
    echo "ETL verification completed successfully (raw/core/mart schemas were bootstrapped)."
  else
    echo "ETL verification completed successfully."
  fi
else
  echo "ETL verification FAILED for:"
  for item in "${failures[@]}"; do
    echo " - $item"
  done
  exit 1
fi

if [ ${#warnings[@]} -gt 0 ]; then
  echo "Warnings:"  
  for item in "${warnings[@]}"; do
    echo " - $item"
  done
  echo "Re-run with SHOW_PREVIEW=1 for detailed output."
fi
