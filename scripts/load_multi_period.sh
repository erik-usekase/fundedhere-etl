#!/usr/bin/env bash
# Multi-period CSV loader - loads all CSV files for multiple date periods
# Supports incremental append mode to preserve historical data

set -euo pipefail

INC_DIR="${1:-./data/inc_data}"
MODE="${2:-replace}"  # replace | append
QUIET="${QUIET:-1}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { [ "$QUIET" = "0" ] && echo -e "${GREEN}[LOAD]${NC} $*" || true; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

usage() {
  cat <<EOF
Usage: $0 [data_dir] [mode]

Multi-period CSV loader for fundedhere-etl.

Arguments:
  data_dir    Directory containing CSV files (default: ./data/inc_data)
  mode        Loading mode (default: replace)
              - replace: Truncate tables before loading (fresh start)
              - append:  Add to existing data (incremental)

Examples:
  # Load all periods, replacing existing data
  $0 data/inc_data replace

  # Add new period to existing data
  $0 data/inc_data append

  # Load from specific directory
  $0 /path/to/csvs append

CSV Naming:
  external_accounts_YYYY-MM.csv[.gz]
  va_txn_YYYY-MM.csv[.gz]
  repmt_sku_YYYY-MM.csv[.gz]
  repmt_sales_YYYY-MM.csv[.gz]

  Example: external_accounts_2025-09.csv, va_txn_2025-10.csv.gz
EOF
  exit 1
}

# Find all CSV files matching pattern
find_all_csvs() {
  local pattern="$1"
  local description="$2"

  shopt -s nullglob
  local files=("$INC_DIR"/$pattern)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    warn "No $description CSV files found (pattern: $pattern)"
    return 1
  fi

  # Sort by filename (which includes date)
  IFS=$'\n' files=($(sort <<<"${files[*]}"))
  unset IFS

  echo "${files[@]}"
}

# Extract period from filename (YYYY-MM)
extract_period() {
  local filename="$1"
  # Match YYYY-MM pattern in filename
  if [[ "$filename" =~ ([0-9]{4}-[0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "unknown"
  fi
}

# Truncate all raw tables
truncate_tables() {
  log "Truncating existing data (replace mode)..."
  scripts/run_sql.sh -c "
    TRUNCATE TABLE raw.external_accounts, raw.va_txn, raw.repmt_sku, raw.repmt_sales CASCADE;
  "
}

# Load single CSV
load_csv_sync() {
  local table="$1"
  local file="$2"
  local period=$(extract_period "$(basename "$file")")

  info "  [$period] Loading $(basename "$file") → $table"

  if scripts/load_csv_direct.sh "$table" "$file" 2>&1 | grep -q "✓ Loaded"; then
    return 0
  else
    error "  [$period] Failed to load $(basename "$file")"
    return 1
  fi
}

# Group files by period
group_by_period() {
  local -n ext_files=$1
  local -n va_files=$2
  local -n sku_files=$3
  local -n sales_files=$4

  declare -A periods

  # Extract unique periods from all files
  for f in "${ext_files[@]}" "${va_files[@]}" "${sku_files[@]}" "${sales_files[@]}"; do
    local period=$(extract_period "$(basename "$f")")
    periods[$period]=1
  done

  echo "${!periods[@]}" | tr ' ' '\n' | sort
}

main() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
  fi

  log "Multi-period CSV loader for fundedhere-etl"
  log "Data directory: $INC_DIR"
  log "Loading mode: $MODE"
  echo

  # Validate mode
  if [ "$MODE" != "replace" ] && [ "$MODE" != "append" ]; then
    error "Invalid mode: $MODE (must be 'replace' or 'append')"
    exit 2
  fi

  # Find all CSV files by type
  log "Discovering CSV files..."

  EXTERNAL_FILES=($(find_all_csvs 'external_accounts_*.csv*' 'External Accounts'))
  VA_FILES=($(find_all_csvs 'va_txn_*.csv*' 'VA Transaction'))
  SKU_FILES=($(find_all_csvs 'repmt_sku_*.csv*' 'Repmt-SKU'))
  SALES_FILES=($(find_all_csvs 'repmt_sales_*.csv*' 'Repmt-Sales'))

  # Show discovered periods
  info "Discovered periods:"
  PERIODS=($(group_by_period EXTERNAL_FILES VA_FILES SKU_FILES SALES_FILES))
  for period in "${PERIODS[@]}"; do
    info "  • $period"
  done
  echo

  info "File counts:"
  info "  External Accounts: ${#EXTERNAL_FILES[@]} files"
  info "  VA Transactions:   ${#VA_FILES[@]} files"
  info "  Repmt-SKU:         ${#SKU_FILES[@]} files"
  info "  Repmt-Sales:       ${#SALES_FILES[@]} files"
  echo

  # Truncate if replace mode
  if [ "$MODE" = "replace" ]; then
    truncate_tables
    echo
  else
    info "Append mode: preserving existing data"
    echo
  fi

  # Load files sequentially by type (can be parallelized per type if needed)
  START_TIME=$(date +%s)
  local failed=0

  # External Accounts
  if [ ${#EXTERNAL_FILES[@]} -gt 0 ]; then
    info "Loading External Accounts files..."
    for file in "${EXTERNAL_FILES[@]}"; do
      load_csv_sync "raw.external_accounts" "$file" || failed=1
    done
    echo
  fi

  # VA Transactions
  if [ ${#VA_FILES[@]} -gt 0 ]; then
    info "Loading VA Transaction files..."
    for file in "${VA_FILES[@]}"; do
      load_csv_sync "raw.va_txn" "$file" || failed=1
    done
    echo
  fi

  # Repmt-SKU
  if [ ${#SKU_FILES[@]} -gt 0 ]; then
    info "Loading Repmt-SKU files..."
    for file in "${SKU_FILES[@]}"; do
      load_csv_sync "raw.repmt_sku" "$file" || failed=1
    done
    echo
  fi

  # Repmt-Sales
  if [ ${#SALES_FILES[@]} -gt 0 ]; then
    info "Loading Repmt-Sales files..."
    for file in "${SALES_FILES[@]}"; do
      load_csv_sync "raw.repmt_sales" "$file" || failed=1
    done
    echo
  fi

  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))

  if [ $failed -ne 0 ]; then
    error "Some loads failed. Check logs above."
    exit 1
  fi

  # Show row counts by period
  log "Verifying row counts by period..."
  scripts/run_sql.sh -c "
    SELECT
      'External Accounts' AS table_name,
      source_file,
      COUNT(*) AS row_count,
      MIN(load_at) AS loaded_at
    FROM raw.external_accounts
    GROUP BY source_file
    ORDER BY source_file;
  " 2>/dev/null || true

  echo
  log "✓ All CSV files loaded successfully in ${ELAPSED}s!"
  log "  Total periods loaded: ${#PERIODS[@]}"
  log "  Mode: $MODE"
}

main "$@"
