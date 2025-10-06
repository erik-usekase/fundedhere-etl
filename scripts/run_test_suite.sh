#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$PROJECT_ROOT/.env"
  set +a
fi

FAIL_ON_LEVEL1_VARIANCE="${FAIL_ON_LEVEL1_VARIANCE:-0}"

cd "$PROJECT_ROOT"

step() { echo -e "\n\033[1;34m== $* ==\033[0m"; }

step "Validate CSV headers"
tests/test_csv_headers.sh

step "Mapping coverage check"
if ! make sqlf FILE=scripts/sql-tests/check_mapping_coverage.sql; then
  echo "Mapping coverage check failed (expected until full mapping provided)" >&2
fi

step "Mart row count parity"
if ! make sqlf FILE=scripts/sql-tests/check_mart_row_counts.sql; then
  echo "Mart row count parity check failed" >&2
fi

step "Level 1 totals parity"
if ! make sqlf FILE=scripts/sql-tests/check_level1_totals.sql; then
  echo "Level 1 totals parity check failed" >&2
fi

step "Level 1 parity vs spreadsheet"
python3 tests/test_level1_parity.py

step "Level 1 variance tolerance"
if ! make sqlf FILE=scripts/sql-tests/check_level1_variance_tolerance.sql; then
  if [ "$FAIL_ON_LEVEL1_VARIANCE" = "1" ]; then
    echo "Level 1 variance tolerance check failed" >&2
    exit 1
  fi
  echo "Level 1 variance tolerance check warning (set FAIL_ON_LEVEL1_VARIANCE=1 in .env to fail)" >&2
fi

step "Counts BEFORE (may be zero after a clean reset)"
make counts || true

step "Bootstrap merchant"
make sqlf FILE=scripts/sql-tests/t10_bootstrap_merchant.sql

step "Bootstrap SKU + VA map"
echo "Skipping legacy bootstrap (mapping provided via CSV)."

step "Refresh typed/mart layers"
make sqlf FILE=scripts/sql-tests/refresh.sql

step "Level 1 preview (if view exists)"
make sqlf FILE=scripts/sql-tests/level1_count.sql || true
make sqlf FILE=scripts/sql-tests/level1_pretty.sql || true

step "Flows after Option-B (if installed)"
make sqlf FILE=scripts/sql-tests/flows_after_option_b.sql || true

step "Level 2 preview"
make sqlf FILE=scripts/sql-tests/level2a_preview.sql || true

step "Category audit"
make sqlf FILE=scripts/sql-tests/category_audit_top50.sql || true
