#!/usr/bin/env bash
set -euo pipefail
INC_DIR="${1:-./data/inc_data}"
OUT_DIR="${INC_DIR}"
python3 scripts/prep_external.py     "${INC_DIR}/external_accounts_2025-09.csv" "${OUT_DIR}/external_accounts_prepped.csv" || true
python3 scripts/prep_vatxn.py        "${INC_DIR}/va_txn_2025-09.csv"            "${OUT_DIR}/va_txn_prepped.csv" || true
python3 scripts/prep_repmt_sku.py    "${INC_DIR}/repmt_sku_2025-09.csv"         "${OUT_DIR}/repmt_sku_prepped.csv" || true
python3 scripts/prep_repmt_sales.py  "${INC_DIR}/repmt_sales_2025-09.csv"       "${OUT_DIR}/repmt_sales_prepped.csv" || true
echo "Prep-all complete (see *_prepped.csv in ${OUT_DIR})"
