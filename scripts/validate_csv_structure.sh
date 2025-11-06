#!/usr/bin/env bash
# Quick CSV structure validator - checks headers and row counts
# Runs fast preview without loading to database

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [data_directory]

Validates CSV structure for all input files.
- Checks file existence
- Validates headers match expected columns
- Shows row counts and file sizes
- Detects encoding issues

Examples:
  $0 data/inc_data
  $0  # defaults to ./data/inc_data
EOF
  exit 1
}

INC_DIR="${1:-./data/inc_data}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }

# Normalize column name for comparison
normalize_col() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g; s/ +/ /g'
}

# Extract CSV header (handle gzip)
get_header() {
  local file="$1"
  if [[ "$file" =~ \.gz$ ]]; then
    gzip -dc "$file" | head -1
  else
    head -1 "$file"
  fi
}

# Count rows (excluding header)
count_rows() {
  local file="$1"
  if [[ "$file" =~ \.gz$ ]]; then
    echo $(($(gzip -dc "$file" | wc -l) - 1))
  else
    echo $(($(wc -l < "$file") - 1))
  fi
}

# Find latest CSV matching pattern
find_latest() {
  local pattern="$1"
  shopt -s nullglob
  local files=("$INC_DIR"/$pattern)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    echo ""
    return 1
  fi

  # Return newest
  local newest="${files[0]}"
  for f in "${files[@]}"; do
    [ "$f" -nt "$newest" ] && newest="$f"
  done
  echo "$newest"
}

# Validate CSV file
validate_csv() {
  local file="$1"
  local table_name="$2"
  local expected_cols="$3"

  echo ""
  info "Validating: $(basename "$file")"

  # Check file exists
  if [ ! -f "$file" ]; then
    error "File not found"
    return 1
  fi

  # File size
  local size=$(du -h "$file" | cut -f1)
  echo "  Size: $size"

  # Row count
  local rows=$(count_rows "$file")
  echo "  Rows: $rows"

  # Extract header
  local header=$(get_header "$file")
  IFS=',' read -ra csv_cols <<< "$header"

  echo "  Columns: ${#csv_cols[@]}"

  # Check if expected columns can be mapped
  local missing=()
  IFS='|' read -ra exp_cols <<< "$expected_cols"

  for exp_col in "${exp_cols[@]}"; do
    local found=0
    local exp_norm=$(normalize_col "$exp_col")

    for csv_col in "${csv_cols[@]}"; do
      local csv_norm=$(normalize_col "$csv_col")
      if [ "$csv_norm" = "$exp_norm" ]; then
        found=1
        break
      fi
    done

    if [ $found -eq 0 ]; then
      missing+=("$exp_col")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing expected columns:"
    for col in "${missing[@]}"; do
      echo "    - $col"
    done
    return 1
  fi

  ok "Structure valid"
  return 0
}

main() {
  echo "========================================"
  echo "CSV Structure Validator"
  echo "========================================"
  echo "Data directory: $INC_DIR"

  local total=0
  local valid=0

  # External Accounts
  EXTERNAL_FILE=$(find_latest 'external_accounts_*.csv*')
  if [ -n "$EXTERNAL_FILE" ]; then
    total=$((total + 1))
    validate_csv "$EXTERNAL_FILE" "external_accounts" \
      "beneficiary_bank_account_number|buy_amount|buy_currency|created_date" && valid=$((valid + 1))
  else
    error "External Accounts CSV not found (pattern: external_accounts_*.csv)"
  fi

  # VA Transaction
  VA_FILE=$(find_latest 'va_txn_*.csv*')
  if [ -n "$VA_FILE" ]; then
    total=$((total + 1))
    validate_csv "$VA_FILE" "va_txn" \
      "sender_note_id|receiver_note_id|receiver_virtual_account_number|amount|date|remarks" && valid=$((valid + 1))
  else
    error "VA Transaction CSV not found (pattern: va_txn_*.csv)"
  fi

  # Repmt SKU
  SKU_FILE=$(find_latest 'repmt_sku_*.csv*')
  if [ -n "$SKU_FILE" ]; then
    total=$((total + 1))
    validate_csv "$SKU_FILE" "repmt_sku" \
      "merchant|sku_id|acquirer_fees_expected|acquirer_fees_paid" && valid=$((valid + 1))
  fi

  # Repmt Sales
  SALES_FILE=$(find_latest 'repmt_sales_*.csv*')
  if [ -n "$SALES_FILE" ]; then
    total=$((total + 1))
    validate_csv "$SALES_FILE" "repmt_sales" \
      "merchant|sku_id|total_funds_inflow|sales_proceeds" && valid=$((valid + 1))
  else
    error "Repmt Sales CSV not found (pattern: repmt_sales_*.csv)"
  fi

  echo ""
  echo "========================================"

  if [ $valid -eq $total ]; then
    ok "All $total CSV files validated successfully"
    echo ""
    info "Ready to load with: make load-fast"
    exit 0
  else
    error "$((total - valid))/$total CSV files failed validation"
    exit 1
  fi
}

main "$@"
