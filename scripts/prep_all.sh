#!/usr/bin/env bash
set -euo pipefail
INC_DIR="${1:-./data/inc_data}"
OUT_DIR="${INC_DIR}"
QUIET_FLAG="${QUIET:-1}"
export QUIET="$QUIET_FLAG"

resolve_src() {
  local var="$1"
  local pattern="$2"
  local description="$3"
  local provided="${!var-}"
  local resolved=""

  if [ -n "$provided" ]; then
    if [ -f "$provided" ]; then
      resolved="$provided"
    elif [ -f "$INC_DIR/$provided" ]; then
      resolved="$INC_DIR/$provided"
    else
      echo "Missing $description CSV: '$provided' (set $var to a valid path or place a file matching '$pattern' in $INC_DIR)" >&2
      return 1
    fi
  else
    shopt -s nullglob
    local matches=("$INC_DIR"/$pattern)
    # Filter out already-prepped files and directories
    local filtered=()
    for candidate in "${matches[@]}"; do
      if [[ "$(basename "$candidate")" == *_prepped.csv ]]; then
        continue
      fi
      filtered+=("$candidate")
    done
    shopt -u nullglob
    if [ ${#filtered[@]} -eq 0 ]; then
      echo "Missing $description CSV. Place a file matching '$pattern' in $INC_DIR or set $var." >&2
      return 1
    fi
    resolved="${filtered[0]}"
  fi

  printf -v "$var" '%s' "$resolved"
  return 0
}

missing=0
resolve_src EXTERNAL_ACCOUNTS_SRC 'external_accounts_*.csv' 'External Accounts' || missing=1
resolve_src VA_TXN_SRC 'va_txn_*.csv' 'VA Transaction Report' || missing=1
resolve_src REPMT_SKU_SRC 'repmt_sku_*.csv' 'Repmt-SKU (by Note)' || missing=1
resolve_src REPMT_SALES_SRC 'repmt_sales_*.csv' 'Repmt-Sales Proceeds (by Note)' || missing=1

if [ "$missing" -ne 0 ]; then
  echo "Aborting prep-all due to missing source files." >&2
  exit 2
fi

python3 scripts/prep_external.py     "$EXTERNAL_ACCOUNTS_SRC" "$OUT_DIR/external_accounts_prepped.csv"
python3 scripts/prep_vatxn.py        "$VA_TXN_SRC"            "$OUT_DIR/va_txn_prepped.csv"
python3 scripts/prep_repmt_sku.py    "$REPMT_SKU_SRC"         "$OUT_DIR/repmt_sku_prepped.csv"
python3 scripts/prep_repmt_sales.py  "$REPMT_SALES_SRC"       "$OUT_DIR/repmt_sales_prepped.csv"

if [ "$QUIET_FLAG" = "0" ]; then
  echo "Prep-all complete (sources:"
  echo "  External Accounts → $EXTERNAL_ACCOUNTS_SRC"
  echo "  VA Transactions   → $VA_TXN_SRC"
  echo "  Repmt-SKU        → $REPMT_SKU_SRC"
  echo "  Repmt-Sales      → $REPMT_SALES_SRC"
  echo ")"
fi
