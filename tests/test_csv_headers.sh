#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$PROJECT_ROOT/data/inc_data"

# file -> expected header
declare -A expected
expected[external_accounts_prepped.csv]='beneficiary_bank_account_number,buy_amount,buy_currency,created_date'
expected[va_txn_prepped.csv]='sender_virtual_account_id,sender_virtual_account_number,sender_note_id,receiver_virtual_account_id,receiver_virtual_account_number,receiver_note_id,receiver_va_opening_balance,receiver_va_closing_balance,amount,date,remarks'
expected[repmt_sku_prepped.csv]='merchant,sku_id,acquirer_fees_expected,acquirer_fees_paid,fh_admin_fees_expected,fh_admin_fees_paid,int_difference_expected,int_difference_paid,sr_principal_expected,sr_principal_paid,sr_interest_expected,sr_interest_paid,jr_principal_expected,jr_principal_paid,jr_interest_expected,jr_interest_paid,spar_merchant,additional_interests_paid_to_fh'
expected[repmt_sales_prepped.csv]='merchant,sku_id,total_funds_inflow,sales_proceeds,l2e'
expected[note_sku_va_map_prepped.csv]='note_id,sku_id,va_number'

failures=0
for file in "${!expected[@]}"; do
  path="$DATA_DIR/$file"
  if [ ! -f "$path" ]; then
    echo "[FAIL] Missing expected file: $path" >&2
    failures=$((failures+1))
    continue
  fi
  header=$(head -n1 "$path" | tr -d '\r')
  if [ "$header" != "${expected[$file]}" ]; then
    echo "[FAIL] Header mismatch for $file" >&2
    echo "  expected: ${expected[$file]}" >&2
    echo "  actual  : $header" >&2
    failures=$((failures+1))
  else
    echo "[PASS] $file headers match"
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "Header validation failed for $failures file(s)" >&2
  exit 1
fi
